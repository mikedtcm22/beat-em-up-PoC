"""One still of a chain stage, for the stage sheet (M6 FB-DETAIL; a review tool, outside the report hash).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/blender_stage_still.py -- <work.blend> <out.png> <mode> <view> [px] [cx cy cz ortho_m]

<work.blend> is a chain work file. mode is `tex` (the source texture, flat lit: 01_inspect to 04_parts keep it) or `swatch` (each face's
palette colour: 05_palette on, as blender_closeup.py) or `solid` (one grey material, studio light: the mesh's shape alone). view is front, side, back or three_quarter (the character faces +Y after the
inspect step). The default frame is the whole body (3.0 m wide ortho, centred at z 0.9); the optional centre and width
frame a close-up. Never the Blender MCP.
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipe_blender as pb  # noqa: E402
import gen_palette as gp  # noqa: E402

VIEWS = {"front": (0, 5, 0), "side": (5, 0, 0), "back": (0, -5, 0), "three_quarter": (3.5, 3.5, 0.4)}


def main():
	argv = sys.argv[sys.argv.index("--") + 1:]
	blend, out, mode, view = argv[0], argv[1], argv[2], argv[3]
	px = int(argv[4]) if len(argv) > 4 else 900
	centre = Vector((float(argv[5]), float(argv[6]), float(argv[7]))) if len(argv) > 7 else Vector((0.0, 0.0, 0.9))
	ortho = float(argv[8]) if len(argv) > 8 else 2.3
	pb.open_blend(os.path.abspath(blend))
	body = bpy.data.objects[pb.BODY]
	me = body.data
	for o in list(bpy.data.objects):
		if o.type == "ARMATURE":
			o.hide_render = True
	for m in list(body.modifiers):
		body.modifiers.remove(m)
	if mode == "swatch":
		slots = pb.scene_prop("pipe_face_slots")
		mats = pb.preview_materials(set(int(s) for s in slots), gp.swatches())
		order = sorted(mats)
		me.materials.clear()
		for s in order:
			me.materials.append(mats[s])
		me.polygons.foreach_set("material_index", np.array([order.index(int(s)) for s in slots], dtype=np.int32))
	if mode == "solid":
		mat = bpy.data.materials.new("solid")
		mat.diffuse_color = (0.6, 0.6, 0.65, 1.0)
		me.materials.clear()
		me.materials.append(mat)
		me.polygons.foreach_set("material_index", np.zeros(len(me.polygons), dtype=np.int32))
	eye = centre + Vector(VIEWS[view]).normalized() * 6.0
	if mode == "tex":
		base = pb.setup_preview_scene

		def tex_scene(res=(480, 640)):
			scene = base(res)
			scene.display.shading.color_type = "TEXTURE"
			scene.display.shading.light = "FLAT"
			return scene
		pb.setup_preview_scene = tex_scene
	pb.render_view(os.path.abspath(out), tuple(eye), tuple(centre), ortho_scale=ortho, res=(px, px))


if __name__ == "__main__":
	main()
