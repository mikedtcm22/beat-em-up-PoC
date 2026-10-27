"""Render a textured model from the four sides, as one contact sheet (headless Blender; M4 plan P1-tools).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/blender_views.py -- <in.glb|.gltf|.blend> <out.png> [tile_px]

Never the Blender MCP. The input is untrusted and is only opened as data; the only file written is <out.png>. It shows
which way a generated model faces and how it is posed, with the texture, before any step is run on it. Orthographic,
Workbench, flat lighting, the file's own texture (or its base colour) on a flat #d9d9d9 ground; one tile per side, left to
right, named by where the CAMERA stands in glTF space (x right, y up, a standard model faces +Z): +Z, +X, -Z, -X. The
sheet is [tile_px * 4] wide (default tile 512). Also prints the model's bounding box in glTF space.
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

# glTF (y up) to Blender (z up): (x, y, z) -> (x, -z, y).
GLTF_TO_BLENDER = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
SIDES = (("+Z", (0, 0, 1)), ("+X", (1, 0, 0)), ("-Z", (0, 0, -1)), ("-X", (-1, 0, 0)))
GROUND_BYTES = (217, 217, 217)
MARGIN = 1.15


def srgb_to_linear(byte):
	c = byte / 255.0
	return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def load(path):
	ext = os.path.splitext(path)[1].lower()
	if ext in (".glb", ".gltf"):
		bpy.ops.import_scene.gltf(filepath=path, import_shading="NORMALS", bone_heuristic="BLENDER", disable_bone_shape=True)
	elif ext == ".blend":
		with bpy.data.libraries.load(path) as (src, dst):
			dst.objects = src.objects
		for obj in dst.objects:
			if obj is not None:
				bpy.context.scene.collection.objects.link(obj)
	else:
		raise SystemExit("unsupported input %s" % ext)


def mesh_bounds():
	lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
	for obj in bpy.context.scene.objects:
		if obj.type != "MESH":
			continue
		for corner in obj.bound_box:
			p = obj.matrix_world @ Vector(corner)
			lo = Vector(map(min, lo, p))
			hi = Vector(map(max, hi, p))
	return lo, hi


def main():
	argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	if len(argv) not in (2, 3):
		raise SystemExit("usage: ... -- <in.glb> <out.png> [tile_px]")
	src, out = argv[0], argv[1]
	tile = int(argv[2]) if len(argv) == 3 else 512
	bpy.ops.wm.read_factory_settings(use_empty=True)
	load(os.path.abspath(src))
	scene = bpy.context.scene
	lo, hi = mesh_bounds()
	centre = (lo + hi) * 0.5
	extent = max(hi - lo) * MARGIN
	to_gltf = GLTF_TO_BLENDER.inverted()
	glo, ghi = to_gltf @ lo, to_gltf @ hi
	print("bbox glTF space min %s max %s" % (tuple(round(min(a, b), 4) for a, b in zip(glo, ghi)), tuple(round(max(a, b), 4) for a, b in zip(glo, ghi))))
	scene.render.engine = "BLENDER_WORKBENCH"
	scene.render.resolution_x = scene.render.resolution_y = tile
	scene.render.resolution_percentage = 100
	scene.render.image_settings.file_format = "PNG"
	scene.render.image_settings.color_mode = "RGB"
	scene.render.dither_intensity = 0.0
	scene.view_settings.view_transform = "Standard"
	scene.display.render_aa = "8"
	shading = scene.display.shading
	shading.light = "FLAT"
	shading.color_type = "TEXTURE"
	shading.show_object_outline = False
	world = bpy.data.worlds.new("flat")
	world.color = tuple(srgb_to_linear(c + 0.5) for c in GROUND_BYTES)
	scene.world = world
	cam_data = bpy.data.cameras.new("cam")
	cam_data.type = "ORTHO"
	cam_data.ortho_scale = extent
	cam_data.clip_start = 0.01
	cam_data.clip_end = 100.0 * extent
	cam = bpy.data.objects.new("cam", cam_data)
	scene.collection.objects.link(cam)
	scene.camera = cam
	tiles = []
	tmp = out + ".tmp.png"
	for _name, direction in SIDES:
		toward = (GLTF_TO_BLENDER @ Vector(direction)).normalized()
		cam.location = centre + toward * (10.0 * extent)
		cam.rotation_euler = (-toward).to_track_quat("-Z", "Y").to_euler()
		bpy.context.view_layer.update()
		scene.render.filepath = tmp
		bpy.ops.render.render(write_still=True)
		image = bpy.data.images.load(tmp)
		image.colorspace_settings.name = "Non-Color"
		pixels = np.array(image.pixels[:], dtype=np.float32).reshape(tile, tile, 4)[:, :, :3]
		bpy.data.images.remove(image)
		tiles.append(np.rint(pixels * 255.0).astype(np.uint8))
	os.remove(tmp)
	sheet = np.concatenate(tiles, axis=1)
	rgba = np.ones((tile, tile * len(tiles), 4), dtype=np.float32)
	rgba[:, :, :3] = sheet.astype(np.float32) / 255.0
	image = bpy.data.images.new("sheet", tile * len(tiles), tile, alpha=False)
	image.colorspace_settings.name = "Non-Color"
	image.pixels = rgba.ravel()
	image.filepath_raw = out
	image.file_format = "PNG"
	image.save()
	print("wrote %s: tiles left to right camera at %s" % (out, " ".join(name for name, _d in SIDES)))


if __name__ == "__main__":
	main()
