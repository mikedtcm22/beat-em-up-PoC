"""Step 2 of the chain: fit the mesh to the table (M4-plan Part C section 5 step 4 and Part A A3).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/blender_fit.py -- <pipeline.json>

Reads work/01_inspect.blend, writes work/02_fit.blend. The mesh is moved onto the project's skeleton, never the other way
round (hurtboxes, rig points, reaches and first-person framing all derive from the table):

	1. a uniform scale and a translation (least squares over the landmarks that are not on the arms) bring the source
	   landmarks to the table's size and place;
	2. the soles go to z = 0: the ankle landmarks are put 0.085 / 0.035 m above the source's lowest foot vertices;
	3. the arms' swing is MEASURED (Hand - UpperArm, per side), and the targets are the table joints chained through it
	   (pipe_common.chain_joints): the exported armature's rest is the A-pose;
	4. the proportion warp: every bone maps its own source segment (head, tail) onto the target segment, rotating and
	   stretching ALONG the bone only (never girth), blended by the vertex weights (the source rig's own, or Blender's heat
	   weights on a temporary armature); the topology is untouched, so the source's weights stay valid;
	5. the landmark residual is reported: a joint's source point, warped with the weights of its nearest vertex, against
	   its target.
Missing landmarks (no rig, or a bone the rig lacks) fall back to the table scaled to the mesh, so a bare mesh drawn on
the mannequin goes through as a near-identity fit.
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector, kdtree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipe_blender as pb  # noqa: E402
import pipe_common as pc  # noqa: E402

NAMES = pc.bone_names()
WARP_BONES = [n for n in NAMES if n != "Root"]
NON_ARM = [n for n in WARP_BONES if "LowerArm" not in n and not n.endswith("Hand")]


def rotation_between(a, b):
	"""3x3 rotation taking unit vector a to unit vector b (shortest arc)."""
	a = np.asarray(a, dtype=np.float64)
	b = np.asarray(b, dtype=np.float64)
	v = np.cross(a, b)
	c = float(a @ b)
	s = float(np.linalg.norm(v))
	if s < 1e-12:
		if c > 0:
			return np.eye(3)
		axis = np.cross(a, [1.0, 0.0, 0.0])
		if np.linalg.norm(axis) < 1e-6:
			axis = np.cross(a, [0.0, 1.0, 0.0])
		axis /= np.linalg.norm(axis)
		return 2.0 * np.outer(axis, axis) - np.eye(3)
	k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
	return np.eye(3) + k + k @ k * ((1.0 - c) / (s * s))


def similarity(src, dst):
	"""Uniform scale s and translation t with dst ~ s * src + t (least squares)."""
	src = np.asarray(src)
	dst = np.asarray(dst)
	sm, dm = src.mean(axis=0), dst.mean(axis=0)
	p, q = src - sm, dst - dm
	s = float((p * q).sum() / max((p * p).sum(), 1e-12))
	return s, dm - s * sm


def bone_transforms(src_segs, dst_segs, order):
	"""{bone: (Sh, Th, M)} with A_b(p) = Th + M (p - Sh), M = R (I + (stretch - 1) u u^T) and u the source direction."""
	out = {}
	for n in order:
		sh, st = np.array(src_segs[n][0]), np.array(src_segs[n][1])
		th, tt = np.array(dst_segs[n][0]), np.array(dst_segs[n][1])
		su, tu = st - sh, tt - th
		sl, tl = np.linalg.norm(su), np.linalg.norm(tu)
		u = su / max(sl, 1e-9)
		R = rotation_between(u, tu / max(tl, 1e-9))
		stretch = tl / max(sl, 1e-9)
		out[n] = (sh, th, R @ (np.eye(3) + (stretch - 1.0) * np.outer(u, u)), stretch, math.degrees(math.acos(float(np.clip(u @ (tu / max(tl, 1e-9)), -1, 1)))))
	return out


def warp_points(points, w, transforms, order):
	"""Linear blend of the per-bone affine maps; points (n, 3), w (n, len(order))."""
	out = np.zeros_like(points)
	for c, n in enumerate(order):
		sh, th, M, _, _ = transforms[n]
		out += w[:, c:c + 1] * (th + (points - sh) @ M.T)
	return out


def dominant_mask(w, names, wanted):
	cols = [NAMES.index(n) for n in wanted if n in NAMES]
	return (w[:, cols].sum(axis=1) > 0.5 * np.maximum(w.sum(axis=1), 1e-9)) & (w.sum(axis=1) > 1e-6)


def run(cfg, extra):
	fit = cfg.get("fit", {})
	head_top = float(cfg.get("target", {}).get("head_top_m", 1.82))
	pb.open_blend(pc.work_path(cfg, "01_inspect.blend"))
	body = bpy.data.objects[pb.BODY]
	me = body.data
	co = pb.verts(me)
	n = len(co)
	meta = pb.scene_prop("pipe_source", {})
	L = {k: np.array(v) for k, v in pb.scene_prop("pipe_landmarks", {}).items()}
	mode = fit.get("landmarks", "rig")
	if mode != "rig":
		L = {}
	for k, v in fit.get("landmark_overrides", {}).items():
		L[k] = np.array(v)
	has_tw = bool(meta.get("has_tw"))
	tw = pb.weights_matrix(body, ["tw_" + b for b in NAMES]) if has_tw else None
	T0 = {k: np.array(v) for k, v in pc.table_joints().items()}
	notes = []

	# ----- 1. scale and place
	pairs = [k for k in NON_ARM if k in L]
	if len(pairs) >= 4:
		s, t = similarity([L[k] for k in pairs], [T0[k] for k in pairs])
		how = "landmarks"
	else:
		height = float(co[:, 2].max() - co[:, 2].min())
		s = head_top / max(height, 1e-6)
		t = np.array([-(co[:, 0].max() + co[:, 0].min()) * 0.5 * s, -(co[:, 1].max() + co[:, 1].min()) * 0.5 * s, -co[:, 2].min() * s])
		how = "bounding box (fewer than 4 landmarks)"
		notes.append("table mode: scale from the mesh height, no rig landmarks")
	co = co * s + t
	L = {k: v * s + t for k, v in L.items()}

	# ----- 2. soles to z = 0
	if has_tw:
		foot_mask = dominant_mask(tw, NAMES, ["LeftFoot", "RightFoot", "LeftToes", "RightToes"])
	else:
		foot_mask = (co[:, 2] < 0.15)
	if not foot_mask.any():
		foot_mask = co[:, 2] < 0.15
	sole_z = float(np.percentile(co[foot_mask, 2], fit.get("sole_percentile", 0.5)))
	for side in pc.SIDES:
		for bone, h in (("Foot", T0[side + "Foot"][2]), ("Toes", T0[side + "Toes"][2])):
			cur = L.get(side + bone)
			if cur is None:
				cur = T0[side + bone].copy()
			L[side + bone] = np.array([cur[0], cur[1], sole_z + h])

	# ----- 3. the swing, measured
	dirs = {}
	swing_cfg = fit.get("swing", "measure")
	swing_source = {}
	for side in pc.SIDES:
		ua, hd = L.get(side + "UpperArm"), L.get(side + "Hand")
		if isinstance(swing_cfg, dict):
			deg = float(swing_cfg[side])
			dirs[side] = pc.swing_dir(side, deg)
			swing_source[side] = "config"
		elif ua is not None and hd is not None and swing_cfg == "measure":
			d = pc.vnorm(tuple(hd - ua))
			dirs[side] = d
			swing_source[side] = "measured"
		else:
			dirs[side] = pc.swing_dir(side, float(fit.get("default_swing_deg", 45.0)))
			swing_source[side] = "default"
	targets = pc.chain_joints(dirs)
	T = {k: np.array(v) for k, v in targets.items()}

	# ----- fill missing landmarks from the table (arms from the target chain)
	missing = []
	for k in NAMES:
		if k not in L:
			L[k] = T[k].copy() if ("LowerArm" in k or k.endswith("Hand")) else T0[k].copy()
			missing.append(k)
	L["Root"] = np.array([0.0, 0.0, 0.0])

	# ----- source and target segments
	kids = pc.bone_children()
	src_segs = {}
	hand_len = pc.leaf_lengths()["Hand"]
	for k in WARP_BONES:
		head = L[k]
		if kids[k]:
			tail = L[kids[k][0]]
		elif k == "Head":
			if has_tw:
				mask = dominant_mask(tw, NAMES, ["Head"])
				top = float(co[mask, 2].max()) if mask.any() else float(co[:, 2].max())
			else:
				top = float(co[:, 2].max())
			tail = np.array([head[0], head[1], max(top, head[2] + 0.05)])
		elif k.endswith("Hand"):
			d = np.array(dirs[k[:-4]])
			reach = hand_len
			if has_tw:
				mask = dominant_mask(tw, NAMES, [k])
				if mask.any():
					reach = max(float(((co[mask] - head) @ d).max()), 0.05)
			tail = head + d * reach
		elif k.endswith("Toes"):
			if has_tw:
				mask = dominant_mask(tw, NAMES, [k, k.replace("Toes", "Foot")])
				tip_y = float(co[mask, 1].max()) if mask.any() else head[1] + 0.12
			else:
				tip_y = head[1] + 0.12
			tail = np.array([head[0], tip_y, sole_z])
		else:
			tail = head + np.array([0.0, 0.0, -0.05])
		src_segs[k] = (head, tail)
	dst_segs = {k: (np.array(h), np.array(tl)) for k, (h, tl) in pc.segments(targets, head_top, dirs).items()}

	# ----- warp weights
	order = WARP_BONES
	if fit.get("warp_weights", "tripo") == "tripo" and has_tw:
		w = tw[:, [NAMES.index(b) for b in order]].copy()
		w[:, order.index("Hips")] += tw[:, NAMES.index("Root")]
		warp_weight_source = "source rig weights"
	else:
		pb.set_verts(me, co)
		arm = pb.make_armature("WarpArmature", {k: (tuple(h), tuple(tl)) for k, (h, tl) in src_segs.items()}, order, pc.bone_parent())
		pb.attach_armature(body, arm)
		pb.auto_weights(body, arm, skip=())
		w = pb.weights_matrix(body, order)
		for m in [m for m in body.modifiers if m.type == "ARMATURE"]:
			body.modifiers.remove(m)
		body.parent = None
		for b in order:
			vg = body.vertex_groups.get(b)
			if vg is not None:
				body.vertex_groups.remove(vg)
		bpy.data.objects.remove(arm)
		warp_weight_source = "heat weights on a temporary armature"
	w, filled = pb.fill_unweighted(co, w)
	w = pb.limit_and_normalize(w, 6)
	transforms = bone_transforms(src_segs, dst_segs, order)

	# ----- warp, residual, distortion
	new_co = warp_points(co, w, transforms, order)
	kd = kdtree.KDTree(n)
	for i in range(n):
		kd.insert(Vector(co[i]), i)
	kd.balance()
	residual = {}
	for k in WARP_BONES:
		_, i, _ = kd.find(Vector(src_segs[k][0]))
		p = warp_points(src_segs[k][0][None, :], w[i:i + 1], transforms, order)[0]
		residual[k] = float(np.linalg.norm(p - dst_segs[k][0]))
	worst_joint = max(residual, key=residual.get)
	pb.set_verts(me, new_co)
	for p in me.polygons:
		p.use_smooth = True

	pb.set_scene_prop("pipe_targets", {k: {"head": list(dst_segs[k][0]), "tail": list(dst_segs[k][1])} for k in WARP_BONES})
	pb.set_scene_prop("pipe_dirs", {s: list(d) for s, d in dirs.items()})
	pb.set_scene_prop("pipe_head_top", head_top)
	pb.save_blend(pc.work_path(cfg, "02_fit.blend"))

	limit = float(fit.get("residual_limit_m", 0.01))
	return {
		"normalise": {"how": how, "scale": float(s), "translation": t.tolist(), "landmark_pairs": len(pairs)},
		"sole_z_source_after_scale": sole_z,
		"swing": {side: {"deg": pc.swing_deg_of(side, dirs[side]), "from": swing_source[side], "dir": list(dirs[side])} for side in pc.SIDES},
		"landmarks_missing_filled_from_table": missing,
		"warp_weights": warp_weight_source,
		"unweighted_filled": filled,
		"stretch": {k: transforms[k][3] for k in order},
		"rotation_deg": {k: transforms[k][4] for k in order},
		"worst_stretch": max(((k, transforms[k][3]) for k in order), key=lambda kv: abs(math.log(kv[1])))[0],
		"landmark_residual_m": residual,
		"worst_joint_residual": {"bone": worst_joint, "m": residual[worst_joint]},
		"residual_limit_m": limit,
		"residual_ok": residual[worst_joint] <= limit,
		"bbox_after": {"min": new_co.min(axis=0).tolist(), "max": new_co.max(axis=0).tolist()},
		"notes": notes,
	}


if __name__ == "__main__":
	pb.run_step("fit", run)
