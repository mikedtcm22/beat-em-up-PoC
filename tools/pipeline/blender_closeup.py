"""A close-up Workbench still of a chain work file, in palette colours (M4 package F-punk; a review tool).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/blender_closeup.py -- <work.blend> <out.png> <view> <cx> <cy> <cz> <ortho_m> [px]

<work.blend> is a chain work file from 05_palette on (faces carry pipe_face_slots). view is front, side, back, three_quarter, top or dir:x,y,z (the direction from the look-at point to the camera, e.g. along
the arm to see a fist end-on); (cx, cy, cz) the look-at point in the Blender frame (+Y forward, +Z up) and ortho_m the width of the view in
metres. Meant for the head, the hands and the vest of a character the stills' overview cannot show. Never the Blender MCP.
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipe_blender as pb  # noqa: E402
import gen_palette as gp  # noqa: E402

VIEWS = {"front": (0, 5, 0), "side": (5, 0, 0), "back": (0, -5, 0), "three_quarter": (3.5, 3.5, 0.4), "top": (0, 0.2, 5)}


def main():
	argv = sys.argv[sys.argv.index("--") + 1:]
	blend, out, view = argv[0], argv[1], argv[2]
	centre = Vector((float(argv[3]), float(argv[4]), float(argv[5])))
	ortho = float(argv[6])
	px = int(argv[7]) if len(argv) > 7 else 800
	pb.open_blend(os.path.abspath(blend))
	body = bpy.data.objects[pb.BODY]
	me = body.data
	slots = pb.scene_prop("pipe_face_slots")
	table = gp.swatches()
	mats = pb.preview_materials(set(int(s) for s in slots), table)
	order = sorted(mats)
	me.materials.clear()
	for s in order:
		me.materials.append(mats[s])
	idx = np.array([order.index(int(s)) for s in slots], dtype=np.int32)
	me.polygons.foreach_set("material_index", idx)
	for o in list(bpy.data.objects):
		if o.type == "ARMATURE":
			o.hide_render = True
	for m in list(body.modifiers):
		body.modifiers.remove(m)
	direction = Vector([float(c) for c in view[4:].split(",")]) if view.startswith("dir:") else Vector(VIEWS[view])
	eye = centre + direction.normalized() * 6.0
	pb.render_view(os.path.abspath(out), tuple(eye), tuple(centre), ortho_scale=ortho, res=(px, px))


if __name__ == "__main__":
	main()
