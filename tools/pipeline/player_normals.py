"""Step 7b of the player's chain: the shading normals of the limbs the lens meets closest (M4 package F-player-fix).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/player_normals.py -- <pipeline.json>

Reads work/06_split.blend (after player_detail.py) and writes it back with CUSTOM split normals on every mesh, which the glTF
exporter writes as the NORMAL attribute. The generated body is a dense, bumpy surface (muscle, cloth folds): its face-by-face normals
are what the toon bands read, so the visible upper arm in a straight punch, which fills a third of the view at 0.2 m, broke into
blotches whose edges follow the triangles. For the vertices a bone owns (config normals.smooth: bones, passes, lam, max_turn_deg) the normal is
relaxed over the mesh's edges (each pass blends it with the mean of its neighbours' by lam, then renormalised), weighted by the
bone's weight so the blend fades out at the ends; every other vertex keeps the normal Blender computes. The hull normal
(COLOR) is computed later from the geometry and is not touched; the geometry is not touched.
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipe_blender as pb  # noqa: E402
import pipe_common as pc  # noqa: E402

NAMES = pc.bone_names()
CAP_ATTR = "pipe_cap"


def relax_normals(me, normals, weight, passes, lam):
	"""`normals` (n, 3) relaxed over the mesh's edges `passes` times and blended in by `weight` (n,)."""
	ev = np.empty(len(me.edges) * 2, dtype=np.int32)
	me.edges.foreach_get("vertices", ev)
	ev = ev.reshape(-1, 2)
	n = len(normals)
	deg = np.bincount(ev.ravel(), minlength=n).astype(np.float64)
	smooth = normals.copy()
	for _ in range(passes):
		acc = np.zeros_like(smooth)
		np.add.at(acc, ev[:, 0], smooth[ev[:, 1]])
		np.add.at(acc, ev[:, 1], smooth[ev[:, 0]])
		mean = acc / np.maximum(deg, 1.0)[:, None]
		smooth = (1.0 - lam) * smooth + lam * mean
		smooth /= np.maximum(np.linalg.norm(smooth, axis=1), 1e-9)[:, None]
	out = (1.0 - weight[:, None]) * normals + weight[:, None] * smooth
	return out / np.maximum(np.linalg.norm(out, axis=1), 1e-9)[:, None]


def base_normals(me):
	"""Blender's vertex normals, except where a cap that nobody sees touches (CAP_ATTR 2, parts.split_fp.caps[...].wall_normals: the
	pelvis cut inside the legs and the belly): a vertex on its ring takes the normal of the faces that are not the cap's (the wall it
	sits on; the cap's tilt would bend the shading along the whole ring, and the hull's smooth normal ignores the cap the same way),
	the cap's inner vertices their own. The caps the lens can see keep Blender's blend, which is right for them.
	Returns (n, 3), the vertices touched by a cap's ring marked in the second result."""
	n = len(me.vertices)
	raw = np.empty(n * 3, dtype=np.float32)
	me.vertex_normals.foreach_get("vector", raw)
	normals = raw.reshape(-1, 3).astype(np.float64)
	touched = np.zeros(n, dtype=bool)
	if CAP_ATTR not in me.attributes:
		return normals, touched
	cap = np.zeros(len(me.polygons), dtype=np.int32)
	me.attributes[CAP_ATTR].data.foreach_get("value", cap)
	cap = (cap == 2).astype(np.int32)  # only the caps whose spec says wall_normals (internal ones); the others keep Blender's blend
	fn = np.empty(len(me.polygons) * 3, dtype=np.float32)
	me.polygons.foreach_get("normal", fn)
	fn = fn.reshape(-1, 3).astype(np.float64)
	area = np.empty(len(me.polygons), dtype=np.float32)
	me.polygons.foreach_get("area", area)
	start, total, lv = pb.poly_arrays(me)
	owner = np.repeat(np.arange(len(start)), total)
	wall = np.zeros((n, 3))
	has_wall = np.zeros(n, dtype=bool)
	is_wall_corner = cap[owner] == 0
	np.add.at(wall, lv[is_wall_corner], fn[owner[is_wall_corner]] * area[owner[is_wall_corner]][:, None])
	has_wall[lv[is_wall_corner]] = True
	on_cap = np.zeros(n, dtype=bool)
	on_cap[lv[~is_wall_corner]] = True
	touched = has_wall & on_cap
	length = np.linalg.norm(wall, axis=1)
	use = touched & (length > 1e-12)
	normals[use] = wall[use] / length[use][:, None]
	return normals, use


def run(cfg, extra):
	sc = cfg.get("normals", {}).get("smooth")
	blend = pc.work_path(cfg, "06_split.blend")
	pb.open_blend(blend)
	report = {"smoothed": {}}
	if not sc:
		pb.save_blend(blend)
		return {"enabled": False}
	cols = [NAMES.index(b) for b in sc["bones"]]
	for ob in pb.body_objects():
		me = ob.data
		normals, _on_ring = base_normals(me)
		w = pb.weights_matrix(ob, NAMES)
		weight = np.clip(w[:, cols].sum(axis=1), 0.0, 1.0)
		weight = weight * weight * (3.0 - 2.0 * weight)  # a smoothstep: the blend fades out where the bone's weight does
		new = relax_normals(me, normals, weight, int(sc.get("passes", 12)), float(sc.get("lam", 0.5)))
		moved = np.degrees(np.arccos(np.clip(np.einsum("ij,ij->i", normals, new), -1.0, 1.0)))
		# no normal turns further than max_turn_deg (a crease such as the armpit is a real edge): past it the blend is cut back
		limit = float(sc.get("max_turn_deg", 180.0))
		over = moved > limit
		if over.any():
			t = (limit / np.maximum(moved, 1e-6))[:, None]
			new = np.where(over[:, None], (1.0 - t) * normals + t * new, new)
			new /= np.maximum(np.linalg.norm(new, axis=1), 1e-9)[:, None]
			moved = np.degrees(np.arccos(np.clip(np.einsum("ij,ij->i", normals, new), -1.0, 1.0)))
		me.normals_split_custom_set_from_vertices([Vector(v) for v in new])
		for p in me.polygons:
			p.use_smooth = True
		report["smoothed"][ob.name] = {"vertices": int((weight > 0.01).sum()), "normal_turned_deg_p95": float(np.percentile(moved[weight > 0.01], 95)) if (weight > 0.01).any() else 0.0,
			"normal_turned_deg_max": float(moved.max())}
	pb.save_blend(blend)
	return report


if __name__ == "__main__":
	pb.run_step("normals", run)
