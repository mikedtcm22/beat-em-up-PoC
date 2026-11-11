"""Step 1 of the static-prop path: import (or script) the model and put it in the prop frame (M6 package PROPS).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/blender_prop_inspect.py -- <pipeline.json>

The prop path (run.py --kind prop) is inspect, palette, export: no fit, rig, parts or armature. This step is the inspect and the
fit in one, since a rigid model has no joints to warp:
	- source.mesh (a GLB or GLTF, untrusted, only ever opened as data) is flattened to world space, its parents and modifiers
	  dropped, the meshes joined into one object named Body and welded by position (glTF import splits a vertex wherever its UV or
	  normal differs); or source.builder (a name in prop_models.py, with source.builder_args) makes the model from primitives;
	- orient: rotate_x_deg then yaw_deg (about Blender Z) turn the model so its front faces -Z in Godot (+Y in Blender);
	- target: {"axis": "x" | "y" | "z" (the GODOT axis), "size_m"} scales it uniformly to that bounding-box extent, or
	  {"dims_m": {"x": .., "y": .., "z": ..}} per axis (a stretch to a pinned box), and
	  target.origin puts the origin: "base_center" (the bbox centre in x and z, the bottom at y 0), "center" (the bbox centre) or
	  "keep" (as built); target.offset_m (Godot x, y, z) is added after;
and it writes work/04_parts.blend, the file the palette step reads (the character chain's parts step writes the same name).
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipe_blender as pb  # noqa: E402
import pipe_common as pc  # noqa: E402
import prop_models  # noqa: E402

WELD_M = 1e-5
GODOT_TO_BLENDER_AXIS = {"x": 0, "y": 2, "z": 1}


def import_mesh(path):
	"""Import a GLB or GLTF and join its meshes into one object in world space. Returns the object."""
	bpy.ops.import_scene.gltf(filepath=path)
	meshes = [o for o in bpy.data.objects if o.type == "MESH"]
	if not meshes:
		pc.fail("no mesh in " + path)
	for o in meshes:
		world = o.matrix_world.copy()
		for mod in list(o.modifiers):
			o.modifiers.remove(mod)
		o.parent = None
		o.matrix_basis = Matrix.Identity(4)
		o.data.transform(world)
		o.data.update()
	for o in [o for o in bpy.data.objects if o.type != "MESH"]:
		bpy.data.objects.remove(o)
	pb.activate(meshes[0])
	for o in meshes:
		o.select_set(True)
	if len(meshes) > 1:
		bpy.ops.object.join()
	return bpy.context.view_layer.objects.active


def run(cfg, extra):
	src = cfg["source"]
	pb.reset_scene()
	report = {"source": {}}
	if src.get("mesh"):
		path = pc.repo_path(src["mesh"])
		report["source"] = {"mesh": src["mesh"], "sha256": pc.sha256_file(path)}
		body = import_mesh(path)
		bm = bmesh.new()
		bm.from_mesh(body.data)
		before = len(bm.verts)
		bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=WELD_M)
		bm.to_mesh(body.data)
		bm.free()
		body.data.update()
		report["source"]["vertices_before_weld"] = before
	elif src.get("builder"):
		body = prop_models.build(src["builder"], src.get("builder_args", {}), pb.BODY)
		report["source"] = {"builder": src["builder"]}
	else:
		pc.fail("the prop config has neither source.mesh nor source.builder")
	body.name = pb.BODY
	body.data.name = pb.BODY
	report["source"]["triangles"] = pb.triangle_count(body.data)

	orient = cfg.get("orient", {})
	rot = Matrix.Rotation(math.radians(float(orient.get("yaw_deg", 0.0))), 4, "Z") @ Matrix.Rotation(math.radians(float(orient.get("rotate_x_deg", 0.0))), 4, "X")
	body.data.transform(rot)
	body.data.update()

	co = pb.verts(body.data)
	lo, hi = co.min(axis=0), co.max(axis=0)
	target = cfg.get("target", {})
	scale = np.ones(3)
	extent_b = hi - lo
	if target.get("dims_m"):
		# per-axis sizes (Godot axes): a prop whose generated proportions differ from its box (SPEC-pinned fallback) is stretched to it
		given = {GODOT_TO_BLENDER_AXIS[k]: float(v) / max(float(extent_b[GODOT_TO_BLENDER_AXIS[k]]), 1e-9) for k, v in target["dims_m"].items()}
		mean = float(np.mean(list(given.values())))
		scale = np.array([given.get(i, mean) for i in range(3)])
	elif target.get("size_m"):
		axis = GODOT_TO_BLENDER_AXIS[target.get("axis", "y")]
		scale = np.full(3, float(target["size_m"]) / max(float(extent_b[axis]), 1e-9))
	co = co * scale
	lo, hi = lo * scale, hi * scale
	origin = target.get("origin", "keep")
	if origin == "base_center":
		shift = np.array([-(lo[0] + hi[0]) / 2.0, -(lo[1] + hi[1]) / 2.0, -lo[2]])
	elif origin == "center":
		shift = -(lo + hi) / 2.0
	else:
		shift = np.zeros(3)
	off = target.get("offset_m", [0.0, 0.0, 0.0])
	shift = shift + np.array(pc.g2b(off))
	co = co + shift
	pb.set_verts(body.data, co)
	for p in body.data.polygons:
		p.use_smooth = True
	pb.save_blend(pc.work_path(cfg, "01_inspect.blend"))
	pb.save_blend(pc.work_path(cfg, "04_parts.blend"))
	report["scale"] = scale.tolist()
	report["bbox_m"] = {"min": (lo + shift).tolist(), "max": (hi + shift).tolist(), "size": (hi - lo).tolist()}
	report["orient"] = orient
	report["target"] = target
	report["triangles"] = pb.triangle_count(body.data)
	return report


if __name__ == "__main__":
	pb.run_step("inspect", run)
