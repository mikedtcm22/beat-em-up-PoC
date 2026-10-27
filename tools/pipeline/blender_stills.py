"""Step 7 of the chain: Workbench stills and strain numbers at the probe poses (M4-plan Part C section 5 steps 4 and 6).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/blender_stills.py -- <pipeline.json>

Reads work/06_split.blend and, for each of config rig.variants (the A-pose bind route and the arms-down bake) and each pose of
config stills.poses (rest, the guard, elbow 150, arm raise 140, knee -130, spine twist: Euler degrees in Godot's YXZ order, the
rig's own numbers), skins the body with pose_lib (the numpy mirror of SkinnedArt: the verified bind formula of Part A A3) and
renders orthographic Workbench stills into <report>/stills/<variant>_<pose>_<view>.png, one sheet per variant
(<report>/stills/<variant>_sheet.png: a row per pose, the config's views across). Each pose also gets strain numbers (edge
length and triangle area), the same statistics the slice gate's strain test uses, against two references: vs_glb_rest, the
GLB's own mesh (what A19 literally says), and vs_rig_rest, the same mesh skinned at the rig's rest pose (arms down). For the
A-pose route the first is ~2 at the armpit even AT rest (the arm swings down), the second is 1.000 at rest by definition.
Colours are the palette swatches (Workbench 'Material' colouring from each face's UV), the ink outline is Workbench's.
Same weights: the two routes differ only where the shoulder and elbow blend bones with different bind rotations; that is the A/B.
"""
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipe_blender as pb  # noqa: E402
import pipe_common as pc  # noqa: E402
import gen_palette as gp  # noqa: E402
import pose_lib  # noqa: E402
from blender_export import bake_rest  # noqa: E402

NAMES = pc.bone_names()


def face_slots(me):
	start, total, lv = pb.poly_arrays(me)
	uv = np.empty(len(me.loops) * 2, dtype=np.float32)
	me.uv_layers[0].data.foreach_get("uv", uv)
	uv = uv.reshape(-1, 2)[start]
	return np.array([gp.slot_of_uv(float(u), 1.0 - float(v)) for u, v in uv], dtype=np.int32)


def tile(paths, cols, out_path, res):
	imgs = []
	for p in paths:
		im = bpy.data.images.load(p)
		px = np.empty(im.size[0] * im.size[1] * 4, dtype=np.float32)
		im.pixels.foreach_get(px)
		imgs.append(px.reshape(im.size[1], im.size[0], 4))
		bpy.data.images.remove(im)
	rows = (len(imgs) + cols - 1) // cols
	h, w = res[1], res[0]
	sheet = np.ones((rows * h, cols * w, 4), dtype=np.float32)
	for i, a in enumerate(imgs):
		r, c = divmod(i, cols)
		y0 = (rows - 1 - r) * h  # images are stored bottom row first
		sheet[y0:y0 + h, c * w:(c + 1) * w] = a
	out = bpy.data.images.new("sheet", cols * w, rows * h, alpha=False)
	out.pixels.foreach_set(sheet.ravel())
	out.filepath_raw = out_path
	out.file_format = "PNG"
	out.save()
	bpy.data.images.remove(out)


def run(cfg, extra):
	sc = cfg.get("stills", {})
	views = sc.get("views", ["front", "three_quarter"])
	poses = sc.get("poses", {"rest": {}})
	res = tuple(sc.get("resolution", [480, 640]))
	variants = cfg.get("rig", {}).get("variants", ["apose"])
	outdir = os.path.join(pc.cfg_dir(cfg, "report"), "stills")
	os.makedirs(outdir, exist_ok=True)
	swatch_table = gp.swatches()
	report = {"variants": {}}
	made = {}
	for variant in variants:
		pb.open_blend(pc.work_path(cfg, "06_split.blend"))
		targets = pb.scene_prop("pipe_targets")
		dirs = {s: tuple(v) for s, v in pb.scene_prop("pipe_dirs").items()}
		meshes = pb.body_objects()
		if variant == "rest":
			bake_rest(meshes, dirs, targets)
			joints_b = pc.table_joints()
		else:
			joints_b = pc.chain_joints(dirs)
		joints_g = {n: np.array(pc.b2g(joints_b[n])) for n in NAMES}
		data = []
		for m in meshes:
			me = m.data
			co_b = pb.verts(me)
			tv, _ = pb.tri_arrays(me)
			data.append({"name": m.name, "co_b": co_b, "co_g": np.stack([co_b[:, 0], co_b[:, 2], -co_b[:, 1]], axis=1), "w": pb.weights_matrix(m, NAMES),
				"tris": tv, "slots": face_slots(me), "me": me})
		slots_used = sorted({int(s) for d in data for s in d["slots"]})
		mats = pb.preview_materials(slots_used, swatch_table)
		stats = {}
		for m in meshes:  # the rest-pose originals must not draw under the posed copies
			m.hide_render = True
			m.hide_viewport = True
		for pose_name, pose in poses.items():
			blank = {"edge_p999": 0.0, "edge_max": 0.0, "edge_min": 9.0, "area_under_15pct": 0.0}
			per = {"nan": False, "vs_glb_rest": dict(blank), "vs_rig_rest": dict(blank)}
			objs = []
			for d in data:
				posed_g = pose_lib.skin(d["co_g"], d["w"], joints_g, {k: tuple(v) for k, v in pose.items()})
				rig_rest_g = pose_lib.skin(d["co_g"], d["w"], joints_g, {})
				for key, ref in (("vs_glb_rest", d["co_g"]), ("vs_rig_rest", rig_rest_g)):
					st = pose_lib.strain(ref, posed_g, d["tris"])
					per[key]["edge_p999"] = max(per[key]["edge_p999"], st["edge_p999"])
					per[key]["edge_max"] = max(per[key]["edge_max"], st["edge_max"])
					per[key]["edge_min"] = min(per[key]["edge_min"], st["edge_min"])
					per[key]["area_under_15pct"] = max(per[key]["area_under_15pct"], st["area_under_15pct"])
					per["nan"] = per["nan"] or st["nan"]
				posed_b = np.stack([posed_g[:, 0], -posed_g[:, 2], posed_g[:, 1]], axis=1)
				me2 = d["me"].copy()
				pb.set_verts(me2, posed_b)
				idx = {s: i for i, s in enumerate(slots_used)}
				me2.materials.clear()
				for s in slots_used:
					me2.materials.append(mats[s])
				me2.polygons.foreach_set("material_index", np.array([idx.get(int(s), 0) for s in d["slots"]], dtype=np.int32))
				ob = bpy.data.objects.new("pv_" + d["name"], me2)
				pb.link(ob)
				objs.append(ob)
			stats[pose_name] = per
			for view in views:
				eye, target = pb.STANDARD_VIEWS[view]
				path = os.path.join(outdir, "%s_%s_%s.png" % (variant, pose_name, view))
				pb.render_view(path, eye, target, ortho_scale=sc.get("ortho_scale", 2.3), res=res)
				made.setdefault(variant, []).append(path)
			for ob in objs:
				me2 = ob.data
				bpy.data.objects.remove(ob)
				bpy.data.meshes.remove(me2)
		report["variants"][variant] = {"strain": stats, "stills": [pc.repo_rel(p) for p in made[variant]]}
		tile(made[variant], len(views), os.path.join(outdir, "%s_sheet.png" % variant), res)
	return report


if __name__ == "__main__":
	pb.run_step("stills", run)
