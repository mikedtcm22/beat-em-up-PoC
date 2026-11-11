"""Step 3 of the chain: the project armature and the weights (M4-plan Part C section 5 step 4, Part A A3).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/blender_rig.py -- <pipeline.json>

Reads work/02_fit.blend, writes work/03_rig.blend. The armature is named Armature and has exactly the 23 bones of the
table, every joint where blender_fit put it: the table chained through the measured arm swing (the A-pose; pipe_common.
chain_joints). Weights, config rig.weights:
	"tripo": the source rig's own groups ("tw_<Bone>", already folded onto the 23 names by blender_inspect) renamed to the
	         bone names; vertices the source left unweighted are filled from the nearest weighted vertex;
	"auto":  Blender's heat-map weights (ARMATURE_AUTO) from the project armature, Root excluded; the vertices the heat
	         solve leaves empty (interior and overlapping geometry) are filled the same way.
Optional rig.smooth_iterations / rig.smooth_factor: Laplacian smoothing of the weights over the mesh's edges before the limit
(the slice gate's contingency against candy-wrap at the shoulder, off by default).
Optional rig.clamps (F-punk, the slice gate's named weight clamps: shoulder, collar, waist): a list of
{name, bones, above_z_m (or below_z_m, M6), ramp_m, to}: the listed bones' weights above a height (Blender z, metres in the rig's 1.8 m space)
move onto bone `to`, smoothstep over ramp_m (0 at above_z_m, all of it beyond), so a waistband that Tripo's rig hangs on the
thigh bone follows the hips instead (the waist of a jeans mesh stretched 40x when a leg lifted, and the hurtbox fit missed it).
Optional rig.torso_blend (F-punk, the same contingency): the vertices a generated rig puts wholly on the trunk bones
(Hips, Spine, Chest, UpperChest: weight 0.95 or more between them) get their weights from their HEIGHT instead, a piecewise
linear blend between the neighbouring bones' joint heights, so a twist of the spine is spread over the whole trunk and not over
the 4 cm where Tripo's weights jump from one bone to the next (a vest hem edge grew 5 cm in the Punk's cross).
Either way: at most rig.max_influences (4) per vertex, normalised, none on Root, every vertex weighted. The result is a
joined Body with an Armature modifier and one vertex group per bone in table order.
"""
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipe_blender as pb  # noqa: E402
import pipe_common as pc  # noqa: E402

NAMES = pc.bone_names()


def run(cfg, extra):
	rigc = cfg.get("rig", {})
	mode = rigc.get("weights", "auto")
	limit = int(rigc.get("max_influences", 4))
	pb.open_blend(pc.work_path(cfg, "02_fit.blend"))
	body = bpy.data.objects[pb.BODY]
	me = body.data
	co = pb.verts(me)
	targets = pb.scene_prop("pipe_targets")
	segs = {k: (tuple(v["head"]), tuple(v["tail"])) for k, v in targets.items()}
	segs["Root"] = ((0.0, 0.0, 0.0), segs["Hips"][0])
	arm = pb.make_armature(pb.ARMATURE, segs, NAMES, pc.bone_parent())
	meta = pb.scene_prop("pipe_source", {})
	notes = []

	if mode == "tripo" and meta.get("has_tw"):
		tw = pb.weights_matrix(body, ["tw_" + n for n in NAMES])
		w = tw.copy()
		w[:, NAMES.index("Hips")] += w[:, NAMES.index("Root")]
		w[:, NAMES.index("Root")] = 0.0
		used = "tripo"
	else:
		if mode == "tripo":
			notes.append("weights tripo requested but the source has no rig weights: used auto")
		pb.attach_armature(body, arm)
		pb.auto_weights(body, arm, skip=("Root",))
		w = pb.weights_matrix(body, NAMES)
		used = "auto"
	empty_before = int((w.sum(axis=1) < 1e-4).sum())
	w, filled = pb.fill_unweighted(co, w)
	blend_report = None
	tb = rigc.get("torso_blend")
	if tb:
		trunk = [NAMES.index(b) for b in tb["bones"]]
		heights = [float(segs[b][0][2]) for b in tb["bones"]]  # the joint heights, in the same order
		owned = w[:, trunk].sum(axis=1) >= float(tb.get("owned", 0.95))
		z = co[:, 2]
		ramp = np.zeros((len(co), len(trunk)))
		for i in range(len(trunk)):
			lo = heights[i - 1] if i > 0 else None
			hi = heights[i + 1] if i + 1 < len(trunk) else None
			rise = np.ones(len(co)) if lo is None else np.clip((z - lo) / max(heights[i] - lo, 1e-6), 0.0, 1.0)
			fall = np.ones(len(co)) if hi is None else np.clip((hi - z) / max(hi - heights[i], 1e-6), 0.0, 1.0)
			ramp[:, i] = np.minimum(rise, fall)
		total = ramp.sum(axis=1, keepdims=True)
		ramp = np.where(total > 1e-9, ramp / np.maximum(total, 1e-9), 0.0)
		keep = w[:, trunk].sum(axis=1)
		for i, col in enumerate(trunk):
			w[owned, col] = ramp[owned, i] * keep[owned]
		blend_report = {"vertices": int(owned.sum()), "bones": tb["bones"], "joint_heights_m": heights}
	clamp_report = []
	for c in rigc.get("clamps", []):
		cols = [NAMES.index(b) for b in c["bones"]]
		if "below_z_m" in c:
			# below_z_m (M6 HEAVIES, opt-in): the mirror of above_z_m, for a boot's sole and heel that a generated rig hangs half on the shin
			t = np.clip((float(c["below_z_m"]) - co[:, 2]) / max(float(c.get("ramp_m", 0.05)), 1e-6), 0.0, 1.0)
		else:
			t = np.clip((co[:, 2] - float(c["above_z_m"])) / max(float(c.get("ramp_m", 0.05)), 1e-6), 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)
		moved = w[:, cols].sum(axis=1) * t
		w[:, cols] *= (1.0 - t)[:, None]
		w[:, NAMES.index(c["to"])] += moved
		clamp_report.append({"name": c.get("name", ""), "vertices": int((moved > 1e-4).sum()), "weight_moved": float(moved.sum())})
	smooth_n = int(rigc.get("smooth_iterations", 0))
	if smooth_n > 0:
		w = pb.smooth_weights(me, w, smooth_n, float(rigc.get("smooth_factor", 0.5)))
	w = pb.limit_and_normalize(w, limit)
	w[:, NAMES.index("Root")] = 0.0
	w = pb.limit_and_normalize(w, limit)
	pb.write_weights(body, NAMES, w, remove_others=True)
	pb.attach_armature(body, arm)
	for p in me.polygons:
		p.use_smooth = True
	pb.save_blend(pc.work_path(cfg, "03_rig.blend"))

	hist = np.bincount((w > 1e-4).sum(axis=1), minlength=limit + 1).tolist()
	return {
		"weights": used,
		"weights_requested": mode,
		"smooth_iterations": smooth_n,
		"clamps": clamp_report,
		"torso_blend": blend_report,
		"bones": len(arm.data.bones),
		"vertices": len(co),
		"unweighted_before_fill": empty_before,
		"filled_from_nearest": filled,
		"influence_histogram": hist,
		"max_influences": int((w > 1e-4).sum(axis=1).max()),
		"weight_on_root": float(w[:, NAMES.index("Root")].max()),
		"vertices_per_bone": {n: int((w[:, i] > 0.5).sum()) for i, n in enumerate(NAMES)},
		"notes": notes,
	}


if __name__ == "__main__":
	pb.run_step("rig", run)
