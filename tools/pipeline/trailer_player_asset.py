"""M7 T14's Blender step for the hero's first-person arms (the video session's tools/video/blender_asset.py player route, ported and trimmed):

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/trailer_player_asset.py -- player <workdir> [--size 2048]

It is tools/pipeline/trailer_asset.py (the Punk's step: the fresh UV2 with no slivers, the maps.npz bake, the export) with the arm work of the
video session's player route added in front of it, all driven by assets/source/trailer_art/player/paint.json:
	"smooth"   a Laplacian relax of the arm and hand vertices (the decimated mesh's lumps and dents go; open cut boundaries are held, so the
	           shoulder cut of Body__fp_arm still meets Body);
	"shape"    the forearm's silhouette (a swell near the elbow, a taper to the wrist) and "gloves" the fist's (a cuff, a padded front, a dome, a
	           thumb lobe, a knuckle ridge): only vertices move, the weights, UV1 and hull normals stay;
	"normals"  smoothed per-vertex shading normals (tools/pipeline/pipe_normals.py), where the shipped ones read as facets on a near arm;
	"layout"   the UV2 weights: the hands and forearms get the texels.
The mesh topology and the triangle count are not changed. Writes maps.npz, meta.json and player_trailer.glb into <workdir>. Never the Blender MCP.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
_SRC = open(os.path.join(HERE, "trailer_asset.py")).read()
# the Punk's step, as a library: everything above its main() call
exec(compile(_SRC[:_SRC.rindex("\nmain()")], os.path.join(HERE, "trailer_asset.py"), "exec"), globals())

def relax(objs, bone_names, cfg, meta_heads=None, meta_tails=None):
	"""Laplacian smoothing of the positions of the vertices weighted to `bones` (paint.json "smooth": {"bones": [...], "iterations", "factor"}, or a
	list of such specs run in order, so the upper arm can take more than the forearm and the hand none): the decimated mesh's lumps and dents go,
	the limb becomes one round form ("fade_t": [from, to] leaves the limb past that fraction of its bone as it is). Applied before the normals; the open boundary of a cut mesh is held (the shoulder cut of Body__fp_arm still
	meets Body). The weights and UVs are untouched."""
	specs = cfg.get("smooth")
	if not specs:
		return {}
	if isinstance(specs, dict):
		specs = [specs]
	for spec in specs:
		for o in objs:
			bw = bone_weights(o, bone_names)
			co = pb.verts(o.data)
			w = np.zeros(len(co))
			for b in spec["bones"]:
				gate = np.ones(len(co))
				if "fade_t" in spec:
					# the part of the limb past t_to (the wrist, where the hand's cuff meets it) is left as it is, fading in from t_from
					head = np.array(meta_heads[b], np.float64)
					axis = np.array(meta_tails[b], np.float64) - head
					t = ((co - head) @ axis) / float(axis @ axis)
					x = np.clip((t - spec["fade_t"][0]) / max(spec["fade_t"][1] - spec["fade_t"][0], 1e-6), 0.0, 1.0)
					gate = 1.0 - x * x * (3.0 - 2.0 * x)
				w += bw[:, bone_names.index(b)] * gate
			w = np.clip(w, 0.0, 1.0)
			tv, _tp = pb.tri_arrays(o.data)
			edges = np.concatenate([tv[:, [0, 1]], tv[:, [1, 2]], tv[:, [2, 0]]], axis=0)
			edges = np.concatenate([edges, edges[:, ::-1]], axis=0)
			count = np.bincount(edges[:, 0], minlength=len(co)).astype(np.float64)
			key = np.sort(np.concatenate([tv[:, [0, 1]], tv[:, [1, 2]], tv[:, [2, 0]]], axis=0), axis=1)
			_u, inv, cnt = np.unique(key, axis=0, return_inverse=True, return_counts=True)
			boundary = np.zeros(len(co), bool)
			for e in _u[cnt == 1]:
				boundary[e] = True
			hold = np.where(boundary, 0.0, 1.0)
			for _ in range(int(spec.get("iterations", 6))):
				acc = np.zeros_like(co)
				np.add.at(acc, edges[:, 0], co[edges[:, 1]])
				avg = acc / np.maximum(count, 1.0)[:, None]
				co = co + (float(spec.get("factor", 0.5)) * w * hold)[:, None] * (avg - co)
				if spec.get("taubin"):
					# the inverse step (Taubin's mu): the limb keeps its girth instead of shrinking under the smoothing
					acc = np.zeros_like(co)
					np.add.at(acc, edges[:, 0], co[edges[:, 1]])
					avg = acc / np.maximum(count, 1.0)[:, None]
					co = co - (float(spec.get("factor", 0.5)) * 1.06 * w * hold)[:, None] * (avg - co)
			pb.set_verts(o.data, co)
	return {"specs": len(specs)}


def shape_limbs(objs, bone_names, meta, cfg):
	"""R4-ART: the forearm's silhouette (paint.json "shape": {"lower": [..bones..], "hand": [..], "swell", "swell_at", "swell_width",
	"wrist", "wrist_from", "fist_at"}). A radial scale about each forearm's bone axis, by the vertex's position along it (t = 0 at the
	elbow, 1 at the wrist): a swell near the elbow end, then a taper to the wrist, and the hand's vertices ease back from the wrist's
	scale to 1 by `fist_at` (the fist is wider than the wrist). Gated by the arm bones' weights so the torso is untouched. Applied after
	the relaxation and before the subdivision, so the Catmull-Clark rounds it."""
	spec = cfg.get("shape")
	if not spec:
		return {}
	out = {}
	for o in objs:
		bw = bone_weights(o, bone_names)
		co = pb.verts(o.data).astype(np.float64)
		for lower, hand in zip(spec["lower"], spec["hand"]):
			head = np.array(meta["bone_heads"][lower], np.float64)
			tail = np.array(meta["bone_tails"][lower], np.float64)
			axis = tail - head
			length = float(np.linalg.norm(axis))
			axis /= length
			w_arm = np.clip(bw[:, bone_names.index(lower)] + bw[:, bone_names.index(hand)], 0.0, 1.0)
			rel = co - head
			along = rel @ axis
			t = along / length
			radial = rel - np.outer(along, axis)
			swell = 1.0 + spec["swell"] * np.exp(-(((t - spec["swell_at"]) / spec["swell_width"]) ** 2))
			sm = np.clip((t - spec["wrist_from"]) / max(1.0 - spec["wrist_from"], 1e-6), 0.0, 1.0)
			sm = sm * sm * (3.0 - 2.0 * sm)
			f = swell * (1.0 + (spec["wrist"] - 1.0) * sm)
			wrist_f = spec["wrist"]
			ease = np.clip((t - 1.0) / max(spec["fist_at"] - 1.0, 1e-6), 0.0, 1.0)
			ease = ease * ease * (3.0 - 2.0 * ease)
			f = np.where(t > 1.0, wrist_f + (1.0 - wrist_f) * ease, f)
			gate = w_arm * np.clip((t + 0.15) / 0.15, 0.0, 1.0)
			scale = 1.0 + (f - 1.0) * gate
			co = head + np.outer(along, axis) + radial * scale[:, None]
		pb.set_verts(o.data, co)
		out[o.name] = True
	return out


def _ease(x):
	x = np.clip(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


def glove_profile(t, pts):
	"""Eased piecewise interpolation of control points [[t, value], ...] (t ascending), held flat outside them."""
	t = np.asarray(t, np.float64)
	out = np.full(t.shape, float(pts[0][1]))
	for (t0, v0), (t1, v1) in zip(pts[:-1], pts[1:]):
		inside = (t >= t0) & (t < t1)
		out[inside] = v0 + (v1 - v0) * _ease((t[inside] - t0) / max(t1 - t0, 1e-9))
	out[t >= pts[-1][0]] = float(pts[-1][1])
	return out


def shape_gloves(objs, bone_names, meta, cfg):
	"""R5-ART: gloves that are not cylinders (paint.json "gloves": {"hands": [..bones..], "profile": [[t, scale], ..], "stretch_from", "stretch",
	"dome", "dome_r", "thumb": {"dir", "t", "t_width", "angle_deg", "lift_mm"}, "ridge": {"t", "t_width", "lift_mm"}}). Each hand bone's vertices (t = 0 at the
	wrist end of the bone, 1 at its tail) get a radial scale about the bone axis from the eased profile (the laced cuff tapering into the forearm, the
	padded front wider than the wrist), the pad lengthened from `stretch_from` by `stretch`, the flat cap domed by `dome` (a share of the bone's length,
	over radial distances up to `dome_r`), a thumb lobe (an outward bump toward `dir`, a world-space vector in the rest pose, around `t`) and a ridge
	(a ring bump: the knuckles). Only vertices move: the UVs, and so the UV2 layout, are untouched. Applied after the arm's shape and before any subdivision."""
	spec = cfg.get("gloves")
	if not spec:
		return {}
	out = {}
	for o in objs:
		bw = bone_weights(o, bone_names)
		co = pb.verts(o.data).astype(np.float64)
		for hand in spec["hands"]:
			head = np.array(meta["bone_heads"][hand], np.float64)
			tail = np.array(meta["bone_tails"][hand], np.float64)
			axis = tail - head
			length = float(np.linalg.norm(axis))
			axis /= length
			gate = _ease((bw[:, bone_names.index(hand)] - 0.15) / 0.6)
			rel = co - head
			along = rel @ axis
			t = along / length
			radial = rel - np.outer(along, axis)
			r = np.linalg.norm(radial, axis=1)
			rdir = radial / np.maximum(r, 1e-9)[:, None]
			scale = glove_profile(t, spec["profile"])
			new_radial = radial * scale[:, None]
			new_along = along.copy()
			if spec.get("stretch", 1.0) != 1.0:
				t0 = spec["stretch_from"] * length
				new_along = np.where(along > t0, t0 + (along - t0) * spec["stretch"], along)
			if spec.get("dome", 0.0) > 0.0:
				dome_r = spec["dome_r"]
				cap = _ease((t - 0.8) / 0.2)
				new_along = new_along + spec["dome"] * length * cap * (1.0 - np.clip(r * scale / (dome_r * float(np.max(scale))), 0.0, 1.0) ** 2)
			bump = np.zeros(len(co))
			th = spec.get("thumb")
			if th:
				d = np.array(th["dir"], np.float64)
				d -= axis * (d @ axis)
				d /= np.linalg.norm(d)
				cosang = rdir @ d
				w_ang = _ease((cosang - math.cos(math.radians(th["angle_deg"]))) / (1.0 - math.cos(math.radians(th["angle_deg"]))))
				w_t = np.exp(-(((t - th["t"]) / th["t_width"]) ** 2))
				bump += th["lift_mm"] / 1000.0 * w_ang * w_t
			rg = spec.get("ridge")
			if rg:
				bump += rg["lift_mm"] / 1000.0 * np.exp(-(((t - rg["t"]) / rg["t_width"]) ** 2))
			moved = head + np.outer(new_along, axis) + new_radial + rdir * bump[:, None]
			co = co + (moved - co) * gate[:, None]
		pb.set_verts(o.data, co)
		out[o.name] = True
	return out



def smooth_player_normals(objs, cfg, bone_names, meta_heads, meta_tails):
	"""Smoothed per-vertex shading normals (tools/pipeline/pipe_normals.py, the Punk's recipe) in two strengths: paint.json "normals" (heavy: the
	arms and the body, where the shipped normals read as facets on a near arm) and "hand_normals" (light: the fist keeps its knuckles and fingers),
	blended by a vertex's Hand weight (an eased ramp from 0.2 to 0.8)."""
	import pipe_normals
	heavy = cfg["normals"]
	light = cfg.get("hand_normals", heavy)
	hands = [bone_names.index(b) for b in cfg.get("hand_bones", ["LeftHand", "RightHand"])]
	out = {}
	for m in objs:
		me = m.data
		co = pb.verts(me)
		tv, _tp = pb.tri_arrays(me)
		before = pipe_normals.vertex_normals(co, tv)
		n_heavy = pipe_normals.smooth_normals(co, tv, int(heavy["iterations"]), float(heavy["crease_deg"]), float(heavy["falloff"]), float(heavy["self_weight"]))
		n_light = pipe_normals.smooth_normals(co, tv, int(light["iterations"]), float(light["crease_deg"]), float(light["falloff"]), float(light["self_weight"]))
		w = np.clip(bone_weights(m, bone_names)[:, hands].sum(axis=1), 0.0, 1.0)
		x = np.clip((w - 0.2) / 0.6, 0.0, 1.0)
		x = x * x * (3.0 - 2.0 * x)
		# the forearm's end (the rolled cuff, "cuff_t": [from, to] of the lower arm bone) keeps the light smoothing too
		if "cuff_t" in cfg:
			for b in cfg.get("cuff_bones", ["LeftLowerArm", "RightLowerArm"]):
				head = np.array(meta_heads[b], np.float64)
				axis = np.array(meta_tails[b], np.float64) - head
				t = ((co - head) @ axis) / float(axis @ axis)
				y = np.clip((t - cfg["cuff_t"][0]) / max(cfg["cuff_t"][1] - cfg["cuff_t"][0], 1e-6), 0.0, 1.0)
				x = np.maximum(x, bone_weights(m, bone_names)[:, bone_names.index(b)] * y * y * (3.0 - 2.0 * y))
		x = x[:, None]
		n = n_heavy * (1.0 - x) + n_light * x
		n = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
		for p in me.polygons:
			p.use_smooth = True
		me.normals_split_custom_set_from_vertices([tuple(float(c) for c in v) for v in n])
		out[m.name] = {k: round(v, 4) for k, v in pipe_normals.report(before, n).items()}
	return out


def player_main():
	name, workdir, opts = arguments()
	os.makedirs(workdir, exist_ok=True)
	pb.open_blend(os.path.join("assets", "source", "characters", name, "work", name + ".blend"))
	objs = pb.body_objects()
	arm = bpy.data.objects[pb.ARMATURE]
	bone_names = [b.name for b in arm.data.bones]
	meta = {"name": name, "front": FRONT.tolist(), "bones": bone_names, "meshes": [o.name for o in objs],
		"bone_heads": {b.name: [round(float(x), 5) for x in b.head_local] for b in arm.data.bones},
		"bone_tails": {b.name: [round(float(x), 5) for x in b.tail_local] for b in arm.data.bones}}
	cfg = load_config(name)
	meta["smooth"] = relax(objs, bone_names, cfg, meta["bone_heads"], meta["bone_tails"])
	meta["shape"] = shape_limbs(objs, bone_names, meta, cfg)
	meta["gloves"] = shape_gloves(objs, bone_names, meta, cfg)
	if cfg.get("normals") and not opts["no_normals"]:
		meta["normals"] = smooth_player_normals(objs, cfg, bone_names, meta["bone_heads"], meta["bone_tails"])
	if not opts["keep_uv2"]:
		meta["layout"] = relayout_uv2(objs, bone_names, cfg, opts["size"])
	meta["uv2_slivers"] = uv2_slivers(objs, opts["size"])
	maps = bake_maps(objs, bone_names, opts["size"])
	np.savez_compressed(os.path.join(workdir, "maps.npz"), **maps)
	meta["coverage"] = float(maps["cover"].mean())
	with open(os.path.join(workdir, "meta.json"), "w") as f:
		json.dump(meta, f, indent=1)
	if not opts["only_maps"]:
		for m in objs:
			for p in m.data.polygons:
				p.use_smooth = True
		be.export_glb(os.path.join(workdir, name + "_trailer.glb"), objs, arm)
	print("T14-ASSET %s: coverage %.3f meshes %s slivers %s" % (name, meta["coverage"], meta["meshes"], meta["uv2_slivers"]))


player_main()
