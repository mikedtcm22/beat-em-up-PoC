"""Step 3 of the static-prop path: the GLB (M6 package PROPS).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/blender_export_prop.py -- <pipeline.json>

Reads work/05_palette.blend (the Body, every face on one palette swatch, UV1 "palette") and writes
<paths.export_dir>/<paths.export_name>.glb: one or more named meshes, UV1 on the atlas, no skin, no armature, no
materials, the smooth hull normal in the COLOR attribute "hull_normal" (blender_export.write_hull_normals: the same
glTF-Y-up encoding the characters use, so toon_outline.gdshader's mode 4 reads it).

Config (all optional):
	export.mesh_name       the Body's name in the file (default: the asset id), "Lock", "Pipe" ...
	export.smooth_angle_deg  the shading: a Smooth-by-Angle at this crease angle (default 35), so a crate stays a crate and a
	                       tank stays round; the vertices split at a sharp edge on export, the hull normal stays smooth
	export.parts           extra scripted meshes added after the palette (tools/pipeline/prop_models.py): a list of
	                       {"name", "builder", "args", "offset_m": [Godot x, y, z], "yaw_deg"}; their faces are already on slots
The frame is the file's: Blender +Z up becomes the glTF/Godot +Y the exporter writes (export_yup), so a weapon built along +Z has
its long axis on +Y, as weapon.gd's art frame wants. The read-back checks the file the way test_static_art.gd will: the meshes
and their names, UV1 on swatch centres, triangles, the bounding box, folded triangles.
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
import gen_palette as gp  # noqa: E402
import prop_models  # noqa: E402
import blender_export as be  # noqa: E402

SLOT_ATTR = "pipe_slot"


def add_parts(parts):
	"""Build the scripted parts, put each on its slots' UVs, and return their objects."""
	out = []
	for part in parts:
		obj = prop_models.build(part["builder"], part.get("args", {}), part["name"])
		bm = bmesh.new()
		bm.from_mesh(obj.data)
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
		bm.to_mesh(obj.data)
		bm.free()
		yaw = float(part.get("yaw_deg", 0.0))
		off = pc.g2b(part.get("offset_m", [0.0, 0.0, 0.0]))
		obj.data.transform(Matrix.Translation(off) @ Matrix.Rotation(math.radians(yaw), 4, "Z"))
		set_palette_uv(obj)
		out.append(obj)
	return out


def set_palette_uv(obj):
	"""UV1 "palette" from the faces' pipe_slot (slot + 1): every loop of a face at its swatch's centre."""
	me = obj.data
	slots = np.zeros(len(me.polygons), dtype=np.int32)
	me.attributes[SLOT_ATTR].data.foreach_get("value", slots)
	if (slots == 0).any():
		pc.fail("%s: %d faces have no palette slot" % (obj.name, int((slots == 0).sum())))
	start, total, _lv = pb.poly_arrays(me)
	layer = me.uv_layers[0] if me.uv_layers else me.uv_layers.new(name="palette")
	layer.name = "palette"
	uv = np.zeros((len(me.loops), 2), dtype=np.float32)
	for f in range(len(me.polygons)):
		u, v = gp.uv_of_slot(int(slots[f]) - 1)
		uv[start[f]:start[f] + total[f]] = (u, 1.0 - v)
	layer.data.foreach_set("uv", uv.ravel())
	me.attributes.remove(me.attributes[SLOT_ATTR])
	for p in me.polygons:
		p.use_smooth = True


def export_glb(path, meshes):
	bpy.ops.object.select_all(action="DESELECT")
	for o in meshes:
		o.select_set(True)
	bpy.context.view_layer.objects.active = meshes[0]
	props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
	opts = dict(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_skins=False, export_animations=False,
		export_apply=False, export_materials="NONE", export_image_format="NONE", export_vertex_color="ACTIVE", export_texcoords=True,
		export_normals=True, export_tangents=False, export_cameras=False, export_lights=False, export_draco_mesh_compression_enable=False,
		export_meshopt_compression_enable=False, export_use_gltfpack=False, export_extras=False)
	bpy.ops.export_scene.gltf(**{k: v for k, v in opts.items() if k in props})


def run(cfg, extra):
	pb.open_blend(pc.work_path(cfg, "05_palette.blend"))
	export_dir = pc.cfg_dir(cfg, "export_dir")
	name = cfg["paths"]["export_name"]
	ex = cfg.get("export", {})
	body = bpy.data.objects[pb.BODY]
	body.name = ex.get("mesh_name", cfg["id"])
	body.data.name = body.name
	set_palette_name_ok = body.data.uv_layers and body.data.uv_layers[0].name == "palette"
	if not set_palette_name_ok:
		pc.fail("the Body has no UV1 'palette' (run the palette step first)")
	parts = add_parts(ex.get("parts", []))
	meshes = [body] + parts
	be.write_hull_normals(meshes, int(ex.get("hull_normal_digits", 5)))
	angle = math.radians(float(ex.get("smooth_angle_deg", 35.0)))
	for m in meshes:
		pb.activate(m)
		bpy.ops.object.shade_smooth_by_angle(angle=angle)
	os.makedirs(export_dir, exist_ok=True)
	path = os.path.join(export_dir, name + ".glb")
	blend_dir = pc.repo_path(cfg["paths"].get("blend_dir", cfg["paths"]["work"]))
	pb.save_blend(os.path.join(blend_dir, name + ".blend"))
	export_glb(path, meshes)
	tris, folds = be.folded_triangles(path)
	infos = []
	lo = np.full(3, 1e9)
	hi = np.full(3, -1e9)
	for m in meshes:
		co = pb.verts(m.data)
		mlo, mhi = co.min(axis=0), co.max(axis=0)
		lo, hi = np.minimum(lo, mlo), np.maximum(hi, mhi)
		infos.append({"name": m.name, "triangles": pb.triangle_count(m.data), "vertices": len(m.data.vertices),
			"bbox_godot": {"min": list(pc.b2g(tuple(mlo))), "max": list(pc.b2g(tuple(mhi)))}})
	# the Godot-frame box: Blender (x, y, z) -> (x, z, -y), so the y extent swaps with z and the z range negates
	glo = (lo[0], lo[2], -hi[1])
	ghi = (hi[0], hi[2], -lo[1])
	info = {"file": pc.repo_rel(path), "sha256": pc.sha256_file(path), "bytes": os.path.getsize(path), "triangles": tris,
		"folded_triangles": folds, "meshes": infos,
		"bbox_godot": {"min": list(glo), "max": list(ghi), "size": [ghi[i] - glo[i] for i in range(3)]}}
	return {"variants": {"prop": info}}


if __name__ == "__main__":
	pb.run_step("export", run)
