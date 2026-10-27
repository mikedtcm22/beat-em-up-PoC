"""Step 1 of the chain: import the source, normalise it, find its landmarks (M4-plan Part C section 5 step 4).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/blender_inspect.py -- <pipeline.json>

Reads config source.mesh (a GLB, GLTF, FBX or .blend; untrusted, only ever opened as data) and optional source.rig (the
rigged file, default the same one). Writes work/01_inspect.blend and work/inspect.report.json, and report/bones.json
(P1-tools' blender_dump_rig.py on the rig file).

What it does:
	- the facing: blender_dump_rig's toe/head heuristic, or source.facing_yaw_deg; the model is turned to face +Y (Blender),
	  which is -Z in Godot, and the result is verified by dumping the turned model again;
	- every mesh is flattened to world space (a Tripo file may carry a scale or a rotation on its armature), parents and
	  armature modifiers dropped, and the meshes joined into one object named Body;
	- the rig's vertex groups are mapped onto the project's 23 bone names (fit.bone_map overrides the identity map; an
	  unmapped bone, a finger, the jaw, an eye, folds into its nearest mapped ancestor) and kept as groups "tw_<Bone>"
	  (the source's own weights, used for the warp and for weights = "tripo");
	- the side labels: when the bones called Left sit on the character's right the labels are swapped (source.sides "auto",
	  "keep" or "swap");
	- the landmarks: the head of every directly mapped bone, in the turned frame, stored on the scene as pipe_landmarks.
Scale and position are NOT changed here: blender_fit.py does that.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipe_blender as pb  # noqa: E402
import pipe_common as pc  # noqa: E402
import blender_dump_rig as dump  # noqa: E402

NAMES = pc.bone_names()
pc_weld_m = 1e-5


def swap_side(name):
	if name.startswith("Left"):
		return "Right" + name[4:]
	if name.startswith("Right"):
		return "Left" + name[5:]
	return name


def map_bones(arm_objs, bone_map):
	"""{source bone name: (our bone name or None)} folding unmapped bones into their nearest mapped ancestor."""
	parent = {}
	for a in arm_objs:
		for b in a.data.bones:
			parent[b.name] = b.parent.name if b.parent else None
	direct = {}
	for name in parent:
		target = bone_map.get(name, name if name in NAMES else None)
		if target in NAMES:
			direct[name] = target
	folded = {}
	for name in parent:
		cur = name
		while cur is not None and cur not in direct:
			cur = parent.get(cur)
		folded[name] = direct.get(cur) if cur is not None else None
	return direct, folded


def run(cfg, extra):
	src = cfg["source"]
	mesh_path = pc.repo_path(src["mesh"])
	rig_path = pc.repo_path(src["rig"]) if src.get("rig") not in (None, "same") else mesh_path
	report_dir = pc.cfg_dir(cfg, "report")
	raw = dump.dump(rig_path)
	dump.write_json(raw, os.path.join(report_dir, "bones.json"))
	facing = raw["facing"]
	yaw = src.get("facing_yaw_deg")
	yaw_source = "config"
	if yaw is None:
		yaw = facing["yaw_deg_to_minus_z"]
		yaw_source = "heuristic"
	bone_map = dict(cfg.get("fit", {}).get("bone_map", {}))

	pb.reset_scene()
	dump.load(rig_path)
	meshes = [o for o in bpy.data.objects if o.type == "MESH"]
	arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
	if not meshes:
		pc.fail("no mesh in " + src["mesh"])
	direct, folded = map_bones(arms, bone_map)

	# bone heads in world space before anything moves
	heads = {}
	for a in arms:
		m = a.matrix_world
		for b in a.data.bones:
			if b.name in direct:
				heads[direct[b.name]] = tuple(m @ b.head_local)

	# flatten the meshes to world space and drop their rig links
	for o in meshes:
		world = o.matrix_world.copy()
		for mod in [m for m in o.modifiers if m.type == "ARMATURE"]:
			o.modifiers.remove(mod)
		o.parent = None
		o.matrix_basis = Matrix.Identity(4)
		o.data.transform(world)
		o.data.update()
	for a in arms:
		bpy.data.objects.remove(a)
	for o in meshes[1:]:
		o.select_set(True)
	pb.activate(meshes[0])
	for o in meshes:
		o.select_set(True)
	if len(meshes) > 1:
		bpy.ops.object.join()
	body = bpy.context.view_layer.objects.active
	body.name = pb.BODY
	body.data.name = pb.BODY
	# glTF import splits a vertex wherever its UV or normal differs: weld them back by position (UVs live on the loops)
	verts_before = len(body.data.vertices)
	bm = bmesh.new()
	bm.from_mesh(body.data)
	bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=pc_weld_m)
	bm.to_mesh(body.data)
	bm.free()
	body.data.update()

	# sides: Left bones must sit at -X once the model faces +Y
	rot = Matrix.Rotation(math.radians(yaw), 4, "Z")
	landmarks = {n: tuple(rot @ Vector(p)) for n, p in heads.items()}
	swapped = False
	mode = src.get("sides", "auto")
	if "LeftUpperArm" in landmarks and "RightUpperArm" in landmarks:
		wrong = landmarks["LeftUpperArm"][0] > landmarks["RightUpperArm"][0]
		swapped = wrong if mode == "auto" else (mode == "swap")
	elif mode == "swap":
		swapped = True
	if swapped:
		landmarks = {swap_side(n): p for n, p in landmarks.items()}

	# the source's own weights, merged onto the 23 names and renamed tw_<Name>
	groups = {vg.index: vg.name for vg in body.vertex_groups}
	target_cols = {}
	tw_names = []
	for n in NAMES:
		tw_names.append("tw_" + n)
	w = np.zeros((len(body.data.vertices), len(NAMES)))
	index_of = {n: i for i, n in enumerate(NAMES)}
	dropped = {}
	for v in body.data.vertices:
		for g in v.groups:
			name = groups.get(g.group)
			target = folded.get(name)
			if target is None:
				dropped[name] = dropped.get(name, 0) + 1
				continue
			if swapped:
				target = swap_side(target)
			w[v.index, index_of[target]] += g.weight
	for vg in list(body.vertex_groups):
		body.vertex_groups.remove(vg)
	has_weights = bool((w.sum(axis=1) > 1e-6).any())
	if has_weights:
		pb.write_weights(body, tw_names, w)

	# turn the model to face +Y
	body.data.transform(rot)
	body.data.update()
	pb.set_scene_prop("pipe_landmarks", {n: list(p) for n, p in landmarks.items()})
	pb.set_scene_prop("pipe_source", {"has_tw": has_weights, "sides_swapped": swapped, "yaw_deg": yaw})
	for p in body.data.polygons:
		p.use_smooth = True
	blend = pc.work_path(cfg, "01_inspect.blend")
	pb.save_blend(blend)

	# verify the turn: the model must now face -Z in Godot space (yaw ~ 0)
	check = dump.dump(blend)["facing"]
	pb.open_blend(blend)
	co = pb.verts(bpy.data.objects[pb.BODY].data)
	return {
		"source": {"mesh": src["mesh"], "rig": src.get("rig", "same"), "sha256": raw["source"]["sha256"]},
		"triangles": raw["summary"]["triangles"],
		"vertices": raw["summary"]["vertices"],
		"vertices_after_weld": len(co),
		"height_m": raw["summary"]["height_m"],
		"bbox_size_before": raw["summary"]["bbox"]["size"] if "size" in raw["summary"].get("bbox", {}) else None,
		"bones": raw["summary"]["bones"],
		"facing": {"yaw_deg_to_minus_z": facing["yaw_deg_to_minus_z"], "axis": facing["axis"], "confidence": facing["confidence"],
			"yaw_used": yaw, "yaw_source": yaw_source, "after_turn_yaw": check["yaw_deg_to_minus_z"], "after_turn_axis": check["axis"]},
		"sides": {"consistent_in_file": raw["sides"]["consistent"], "swapped": swapped, "mode": mode},
		"names": {"missing_of_23": raw["names"]["rig_table_missing"], "profile_matched": raw["names"]["profile_matched"]},
		"mapped_directly": sorted(landmarks),
		"folded_into_parent": sorted(n for n, t in folded.items() if t and n not in direct),
		"dropped_groups": dropped,
		"source_weights": has_weights,
		"unweighted_in_source": raw["summary"]["unweighted"],
		"bbox_after_turn": {"min": co.min(axis=0).tolist(), "max": co.max(axis=0).tolist()},
		"turn_verified": abs(check["yaw_deg_to_minus_z"]) < 15.0,
	}


if __name__ == "__main__":
	pb.run_step("inspect", run)
