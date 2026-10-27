"""Step 6 of the chain: smooth hull normals, bind-route variants, GLB export (M4-plan 2.6, Part A A3).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/blender_export.py -- <pipeline.json>

Reads work/06_split.blend (the visible Body, Body__fp_hidden when the player split is on, the Armature), and for each of
config rig.variants writes a GLB into paths.export_dir:
	"apose": <name>.glb      the default (A3): the armature's rest is the A-pose, every joint the table chained through the
	                         arms' measured swing, the GLB's own binds agree with that rest;
	"rest":  <name>_rest.glb the arms-down bake: each arm chain is rotated back about its upper-arm joint (linear blend with
	                         the weights, so the mesh and the armature agree) and the armature is rebuilt on the plain table;
	                         SkinnedArt's one code path gives R = identity for it.
The COLOR attribute "hull_normal" holds the position-averaged smooth normal (n * 0.5 + 0.5) so inverted-hull outlines never
crack at a hard edge or at the cut between the two parts; it is computed after the variant's final positions, from every face
except the first-person caps, across both meshes. It is stored in glTF Y-up axes, the frame of the file's POSITION and NORMAL:
the exporter turns those two from Blender's Z-up but passes a colour attribute through untouched, so write_hull_normals turns it
(x, y, z) -> (x, z, -y) itself, and toon_outline.gdshader reads COLOR as a model-space Y-up direction.
UV1 "palette", UV2 "detail" (when present) are written by the earlier steps.
Export options are Part C 2.6's: GLB, Y up, skins, 4 influences, no animations, deform bones only, no materials or images, the
active vertex colour, no compression. Afterwards each file is read back with blender_dump_rig and checked: 23 bones, joints
against the chained table, unweighted vertices, influences, triangles, facing, soles. <paths.blend_dir (default work)>/<name>.blend keeps the A-pose file.
"""
import json
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipe_blender as pb  # noqa: E402
import pipe_common as pc  # noqa: E402
import blender_dump_rig as dump  # noqa: E402
from blender_fit import rotation_between  # noqa: E402

NAMES = pc.bone_names()
CAP_ATTR = "pipe_cap"


def rebuild_armature(segs):
	old = bpy.data.objects[pb.ARMATURE]
	meshes = pb.body_objects()
	for m in meshes:
		for mod in [m for m in m.modifiers if m.type == "ARMATURE"]:
			m.modifiers.remove(mod)
		m.parent = None
	bpy.data.objects.remove(old)
	arm = pb.make_armature(pb.ARMATURE, segs, NAMES, pc.bone_parent())
	for m in meshes:
		pb.attach_armature(m, arm)
	return arm


def bake_rest(meshes, dirs, targets):
	"""Rotate each arm chain back to hanging about its upper-arm joint, blended by the arm weights."""
	for m in meshes:
		co = pb.verts(m.data)
		w = pb.weights_matrix(m, NAMES)
		out = co.copy()
		for side in pc.SIDES:
			p = np.array(targets[side + "UpperArm"]["head"])
			R = rotation_between(np.array(pc.HANGING), np.array(dirs[side]))
			arm_w = w[:, NAMES.index(side + "UpperArm")] + w[:, NAMES.index(side + "LowerArm")] + w[:, NAMES.index(side + "Hand")]
			moved = p + (co - p) @ R  # R^T applied to each row: the arm turned back to hanging
			out += arm_w[:, None] * (moved - co)
		pb.set_verts(m.data, out)


def to_gltf_axes(n):
	"""Blender Z-up rows turned to glTF Y-up, the exporter's own mapping for POSITION and NORMAL: (x, y, z) -> (x, z, -y)."""
	return np.stack([n[:, 0], n[:, 2], -n[:, 1]], axis=1)


def write_hull_normals(meshes, digits):
	"""Bake the smooth normal into the COLOR attribute "hull_normal" (n * 0.5 + 0.5), in glTF Y-up axes (see the module doc)."""
	cos, tris, keeps, lvs = [], [], [], []
	for m in meshes:
		me = m.data
		co = pb.verts(me)
		tv, tp = pb.tri_arrays(me)
		cap = np.zeros(len(me.polygons), dtype=np.int32)
		if CAP_ATTR in me.attributes:
			me.attributes[CAP_ATTR].data.foreach_get("value", cap)
		cos.append(co)
		tris.append(tv)
		keeps.append((cap[tp] == 0).astype(np.float64))
		lvs.append(pb.poly_arrays(me)[2])
	normals = pb.smooth_vertex_normals(cos, tris, keep=keeps, digits=digits)
	for m, n, lv in zip(meshes, normals, lvs):
		me = m.data
		for attr in list(me.color_attributes):
			me.color_attributes.remove(attr)
		attr = me.color_attributes.new("hull_normal", "FLOAT_COLOR", "CORNER")
		rgba = np.ones((len(lv), 4), dtype=np.float32)
		rgba[:, :3] = (to_gltf_axes(n[lv]) * 0.5 + 0.5).astype(np.float32)
		attr.data.foreach_set("color", rgba.ravel())
		me.color_attributes.active_color = attr
		me.color_attributes.render_color_index = list(me.color_attributes).index(attr)
		me.update()


def export_glb(path, meshes, arm):
	bpy.ops.object.select_all(action="DESELECT")
	for o in meshes + [arm]:
		o.select_set(True)
	bpy.context.view_layer.objects.active = arm
	props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
	opts = dict(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_skins=True, export_influence_nb=4,
		export_all_influences=False, export_animations=False, export_def_bones=True, export_leaf_bone=False, export_apply=False,
		export_materials="NONE", export_image_format="NONE", export_vertex_color="ACTIVE", export_texcoords=True, export_normals=True,
		export_tangents=False, export_cameras=False, export_lights=False, export_draco_mesh_compression_enable=False,
		export_meshopt_compression_enable=False, export_use_gltfpack=False, export_extras=False, export_rest_position_armature=True)
	bpy.ops.export_scene.gltf(**{k: v for k, v in opts.items() if k in props})


COMPONENT_DTYPES = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
COMPONENT_COUNTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_accessor(js, blob, index):
	"""One glTF accessor of a GLB's binary chunk as an (count, components) array (tightly packed or strided, never sparse)."""
	acc = js["accessors"][index]
	view = js["bufferViews"][acc["bufferView"]]
	dtype = np.dtype(COMPONENT_DTYPES[acc["componentType"]])
	n = COMPONENT_COUNTS[acc["type"]]
	stride = view.get("byteStride", dtype.itemsize * n)
	start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
	rows = np.frombuffer(blob, dtype=np.uint8, count=stride * (acc["count"] - 1) + dtype.itemsize * n, offset=start)
	return np.lib.stride_tricks.as_strided(rows, shape=(acc["count"], dtype.itemsize * n), strides=(stride, 1)).copy().view(dtype).reshape(acc["count"], n)


def folded_triangles(path):
	"""How many triangles of a written GLB have a winding that opposes the mean of their three vertex NORMALs (a fold: the
	face turns away from the surface the shading says it is on). (Triangle count, folded count) over every mesh primitive;
	glTF winding is counter-clockwise, so a front-facing triangle has cross(b - a, c - a) along its normals."""
	data = open(path, "rb").read()
	js, blob, off = None, b"", 12
	while off < len(data):
		length, kind = int.from_bytes(data[off:off + 4], "little"), data[off + 4:off + 8]
		if kind == b"JSON":
			js = json.loads(data[off + 8:off + 8 + length].decode("utf-8"))
		elif kind == b"BIN\x00":
			blob = data[off + 8:off + 8 + length]
		off += 8 + length
	total = folded = 0
	for mesh in js["meshes"]:
		for prim in mesh["primitives"]:
			pos = read_accessor(js, blob, prim["attributes"]["POSITION"]).astype(np.float64)
			nrm = read_accessor(js, blob, prim["attributes"]["NORMAL"]).astype(np.float64)
			tri = read_accessor(js, blob, prim["indices"]).astype(np.int64).reshape(-1, 3)
			face = np.cross(pos[tri[:, 1]] - pos[tri[:, 0]], pos[tri[:, 2]] - pos[tri[:, 0]])
			total += len(tri)
			folded += int(np.count_nonzero(np.einsum("ij,ij->i", face, nrm[tri[:, 0]] + nrm[tri[:, 1]] + nrm[tri[:, 2]]) < 0.0))
	return total, folded


def check_glb(path, expect_dirs):
	"""Read a written GLB back and compare it with the contract (returns a dict of measurements)."""
	d = dump.dump(path)
	tris, folds = folded_triangles(path)
	bones = {b["name"]: b for a in d["armatures"] for b in a["bones"]}
	chain = pc.chain_joints(expect_dirs)
	worst, worst_bone = 0.0, ""
	for n in NAMES:
		if n not in bones:
			continue
		want = pc.b2g(chain[n])
		got = bones[n]["head"]
		err = pc.vlen(pc.vsub(tuple(got), want))
		if err > worst:
			worst, worst_bone = err, n
	s = d["summary"]
	return {
		"bones": s["bones"], "bone_names_exact": sorted(bones) == sorted(NAMES), "neutral_bone": s["neutral_bone"]["present"],
		"unweighted": s["unweighted"], "max_influences": s["max_influences"], "over_four": s["over_four"],
		"triangles": s["triangles"], "height_m": s["height_m"], "feet_y": s["feet_y"],
		"folded_triangles": folds, "folded_share": folds / max(tris, 1),
		"facing": {"axis": d["facing"]["axis"], "yaw": d["facing"]["yaw_deg_to_minus_z"], "confidence": d["facing"]["confidence"]},
		"sides_consistent": d["sides"]["consistent"],
		"worst_joint_error_mm": worst * 1000.0, "worst_joint": worst_bone,
		"meshes": [{"name": m["name"], "triangles": m["triangles"], "vertices": m["vertices"], "uv_layers": m["uv_layers"],
			"color_attributes": m["color_attributes"]} for m in d["meshes"]],
		"bbox": s["bbox"],
	}


def run(cfg, extra):
	blend = pc.work_path(cfg, "06_split.blend")
	export_dir = pc.cfg_dir(cfg, "export_dir")
	name = cfg["paths"]["export_name"]
	variants = cfg.get("rig", {}).get("variants", ["apose"])
	digits = int(cfg.get("export", {}).get("hull_normal_digits", 5))
	os.makedirs(export_dir, exist_ok=True)
	written = {}
	for variant in variants:
		pb.open_blend(blend)
		targets = pb.scene_prop("pipe_targets")
		dirs = {s: tuple(v) for s, v in pb.scene_prop("pipe_dirs").items()}
		head_top = pb.scene_prop("pipe_head_top", 1.82)
		meshes = pb.body_objects()
		arm = bpy.data.objects[pb.ARMATURE]
		out_dirs = dirs
		if variant == "rest":
			bake_rest(meshes, dirs, targets)
			hang = {s: pc.HANGING for s in pc.SIDES}
			arm = rebuild_armature({k: (tuple(h), tuple(t)) for k, (h, t) in
				dict(pc.segments(pc.chain_joints(hang), head_top, hang), Root=((0.0, 0.0, 0.0), pc.table_joints()["Hips"])).items()})
			out_dirs = hang
		write_hull_normals(meshes, digits)
		for m in meshes:
			for p in m.data.polygons:
				p.use_smooth = True
		suffix = "" if variant == "apose" else "_" + variant
		path = os.path.join(export_dir, name + suffix + ".glb")
		if variant == "apose":
			blend_dir = pc.repo_path(cfg["paths"].get("blend_dir", cfg["paths"]["work"]))
			pb.save_blend(os.path.join(blend_dir, name + ".blend"))
		export_glb(path, meshes, arm)
		written[variant] = (path, out_dirs)
	report = {"variants": {}}
	for variant, (path, out_dirs) in written.items():
		info = check_glb(path, out_dirs)
		info["file"] = pc.repo_rel(path)
		info["sha256"] = pc.sha256_file(path)
		info["bytes"] = os.path.getsize(path)
		report["variants"][variant] = info
	return report


if __name__ == "__main__":
	pb.run_step("export", run)
