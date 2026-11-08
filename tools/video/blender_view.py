"""LD-ASSET's drawing canvas (Phase 1): an orthographic Workbench render of a character's mesh from one side, flat-shaded so the relief
reads (a nose, a brow, the fold of a glove), at a known scale, for drawing the features SVG over.

	blender --background --factory-startup --python-exit-code 1 --python tools/video/blender_view.py -- <name> <png> <view> <right_m> <up_m> <width_mm> <height_mm> <px_per_mm>

`view` is front, back, left, right or top (the character faces +Y in the work file, +Z is up); (right_m, up_m) is the centre of the picture in
metres on the view's right and up axes, which tools/video/art_paint.py uses the same way (front: right = -X). Headless Blender only.
"""
import math
import os
import sys

import bpy

name, png, view, right_m, up_m, width_mm, height_mm, px_per_mm = sys.argv[sys.argv.index("--") + 1:][:8]
right_m, up_m, width_mm, height_mm, px_per_mm = float(right_m), float(up_m), float(width_mm), float(height_mm), float(px_per_mm)
bpy.ops.wm.open_mainfile(filepath=os.path.join("assets", "source", "characters", name, "work", name + ".blend"))
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.render.resolution_x = int(width_mm * px_per_mm)
sc.render.resolution_y = int(height_mm * px_per_mm)
sc.render.film_transparent = False
sh = sc.display.shading
sh.light = "STUDIO"
sh.color_type = "SINGLE"
sh.single_color = (0.85, 0.85, 0.85)
sh.show_cavity = True
sh.cavity_type = "BOTH"
sc.display.render_aa = "8"
for o in bpy.data.objects:
	if o.type == "ARMATURE":
		o.hide_render = True
	if o.type == "MESH":
		for p in o.data.polygons:
			p.use_smooth = False
# camera: looking along the view's "away" axis; right/up vectors as in art_paint.VIEWS
AXES = {
	"front": ((-1, 0, 0), (0, 0, 1), (0, 1, 0)),
	"back": ((1, 0, 0), (0, 0, 1), (0, -1, 0)),
	"left": ((0, -1, 0), (0, 0, 1), (1, 0, 0)),
	"right": ((0, 1, 0), (0, 0, 1), (-1, 0, 0)),
	"top": ((-1, 0, 0), (0, 1, 0), (0, 0, 1)),
}
r, u, t = (bpy.mathutils_vec if False else None, None, None)
from mathutils import Vector  # noqa: E402
r, u, t = [Vector(v) for v in AXES[view]]
centre = r * right_m + u * up_m
cam = bpy.data.cameras.new("c")
cam.type = "ORTHO"
cam.ortho_scale = width_mm / 1000.0
cam.clip_start = 0.01
cam.clip_end = 20.0
obj = bpy.data.objects.new("c", cam)
sc.collection.objects.link(obj)
obj.location = centre + t * 5.0
# the camera looks down its -Z; its +X is the picture's right and its +Y the picture's up
from mathutils import Matrix  # noqa: E402
m = Matrix(((r.x, u.x, t.x), (r.y, u.y, t.y), (r.z, u.z, t.z)))
obj.rotation_euler = m.to_euler()
sc.camera = obj
sc.render.filepath = png
bpy.ops.render.render(write_still=True)
