"""R5-ART probe: for each character, print every hand bone's head/tail and the extents of the vertices it owns along and across its axis.
Usage: blender --background --factory-startup --python tools/video/blender_glove_probe.py -- <name>  (read-only: nothing is written)."""
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "pipeline"))
import pipe_blender as pb  # noqa: E402

name = sys.argv[sys.argv.index("--") + 1]
pb.open_blend(os.path.join("assets", "source", "characters", name, "work", name + ".blend"))
objs = pb.body_objects()
arm = bpy.data.objects[pb.ARMATURE]
bones = {b.name: b for b in arm.data.bones}
for o in objs:
	co = pb.verts(o.data).astype(np.float64)
	groups = {g.index: g.name for g in o.vertex_groups}
	owner = {}
	for v in o.data.vertices:
		if v.groups:
			g = max(v.groups, key=lambda x: x.weight)
			owner[v.index] = groups.get(g.group)
	print("MESH", o.name, len(co))
	for bn in sorted(bones):
		if "Hand" not in bn and "Thumb" not in bn and "Index" not in bn and "Middle" not in bn and "Ring" not in bn and "Little" not in bn and "LowerArm" not in bn:
			continue
		idx = [i for i, g in owner.items() if g == bn]
		if not idx:
			continue
		b = bones[bn]
		head = np.array(b.head_local)
		tail = np.array(b.tail_local)
		axis = tail - head
		length = float(np.linalg.norm(axis))
		axis /= length
		rel = co[idx] - head
		along = rel @ axis / length
		rad = np.linalg.norm(rel - np.outer(rel @ axis, axis), axis=1)
		print("BONE", bn, "len %.3f" % length, "head", np.round(head, 3), "tail", np.round(tail, 3), "n", len(idx), "t %.2f..%.2f" % (along.min(), along.max()), "radial max %.3f mean %.3f" % (rad.max(), rad.mean()))
