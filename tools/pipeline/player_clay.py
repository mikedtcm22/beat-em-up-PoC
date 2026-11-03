"""A model's SHAPE, without its colours: studio-lit clay renders from several sides as one sheet (M4 package F-player-art).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/player_clay.py -- <in.glb> <out.png> [tile_px] [views]

Headless Blender, never the Blender MCP; the input is untrusted data. `views` is a comma list of camera sides in glTF space
(+Z,+X,-Z,-X,+Y,-Y; default +Z,+X,-Z,-X): the textured sheets of blender_views.py hide the geometry of a flat-coloured
model, this one shows it (a fist's fingers, a wrap's thickness, a fold). Orthographic, Workbench Studio lighting, one flat
grey material on a #d9d9d9 ground, object outline on; tiles left to right in the order given. Writes only <out.png>.
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

GLTF_TO_BLENDER = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
SIDES = {"+Z": (0, 0, 1), "+X": (1, 0, 0), "-Z": (0, 0, -1), "-X": (-1, 0, 0), "+Y": (0, 1, 0), "-Y": (0, -1, 0)}
GROUND_BYTES = (217, 217, 217)
MARGIN = 1.15


def srgb_to_linear(byte):
	c = byte / 255.0
	return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def bounds():
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
	if len(argv) < 2:
		raise SystemExit("usage: ... -- <in.glb> <out.png> [tile_px] [views]")
	src, out = argv[0], argv[1]
	tile = int(argv[2]) if len(argv) > 2 else 512
	views = (argv[3] if len(argv) > 3 else "+Z,+X,-Z,-X").split(",")
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=os.path.abspath(src), import_shading="NORMALS", bone_heuristic="BLENDER", disable_bone_shape=True)
	scene = bpy.context.scene
	lo, hi = bounds()
	centre = (lo + hi) * 0.5
	extent = max(hi - lo) * MARGIN
	scene.render.engine = "BLENDER_WORKBENCH"
	scene.render.resolution_x = scene.render.resolution_y = tile
	scene.render.resolution_percentage = 100
	scene.render.image_settings.file_format = "PNG"
	scene.render.image_settings.color_mode = "RGB"
	scene.render.dither_intensity = 0.0
	scene.view_settings.view_transform = "Standard"
	scene.display.render_aa = "8"
	shading = scene.display.shading
	shading.light = "STUDIO"
	shading.color_type = "SINGLE"
	shading.single_color = (0.72, 0.72, 0.72)
	shading.show_object_outline = True
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
	for name in views:
		toward = (GLTF_TO_BLENDER @ Vector(SIDES[name])).normalized()
		cam.location = centre + toward * (10.0 * extent)
		up = "Y" if abs(toward.z) < 0.9 else "X"
		cam.rotation_euler = (-toward).to_track_quat("-Z", up).to_euler()
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
	print("wrote %s: tiles left to right camera at %s" % (out, " ".join(views)))


if __name__ == "__main__":
	main()
