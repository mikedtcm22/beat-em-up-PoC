"""Step 7a of the player's chain: the 1k ink mask on UV2 (M4 package F-player-art, M4-plan Part C section 7 step 3).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/player_detail.py -- <pipeline.json>

Reads work/06_split.blend (the final meshes and their UV2 "detail" layout), work/04_parts.blend (the dense, textured body) and
work/04a_fists_dense.blend (the dense, textured fist pieces), and writes <export_dir>/<detail.name> (default player_detail.png): a
size x size image whose R channel is ink (G and B repeat it). The toon shader mixes the surface toward the ink by it,
`color = mix(color, ink, mask.r)`; it is only ever lines, never shading (SPEC section 10).

The ink, per texel of the final surface:
	border  where two palette swatches meet: the wrap's edge, the glove plate's edge, the strap, the belt, the sleeve hole, the
	        shoe's sole. Analytic: a texel is ink when it lies within detail.border_px of a triangle edge whose neighbour wears
	        another swatch (so an island's own edge in UV space is never a line);
	stroke  the thin dark lines of the generated texture (the diagonal strands of the wraps, the glove's stitching, the folds of
	        the trousers and the top, the creases of the fingers; not on the body's bare skin, detail.stroke.skip_slots): a ridge detector on the dense source's texture, at the
	        point of the dense surface nearest to the texel. A ridge is darker than both sides along one of four directions
	        (detail.stroke.radius_px apart), so a step between two colours is not a ridge and the borders are not drawn twice.
The strokes are then made to be cut, not mixed: the toon shader thresholds the hero's mask at look_detail_cut with a pixel-wide
antialiased edge (game/fx/toon.gdshader, `detail_sharp`), so any partial value or blot of the mask shows as hard ink. Therefore:
	fist_skip_slots  the fist piece's glove (a dark swatch) takes no stroke or crease ink: the generated texture's mottling of a dark
	        glove is not a line, and cut at look_detail_cut it was a black patch the size of the fingers;
	harden  the stroke and crease terms are pushed toward 0 and 1 (smoothstep lo..hi), so a line is as wide wherever the ridge is
	        strong or weak, and a faint ridge is no ink;
	clean   morphological opening of the stroke terms (blob_radius_texels: a patch thicker than 2 r + 1 texels is a blot, not a
	        strand, and goes with blob_grow_texels round it) and connected pieces under speck_min_texels (a speck is dirt, not a line).
	        The borders are analytic and never cleaned.
The mask is then grown by detail.dilate_px into the empty space round the UV islands, so a filtered lookup at an island's edge
reads ink, not nothing. Deterministic: no random numbers, no time in the report.
"""
import hashlib
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipe_blender as pb  # noqa: E402
import pipe_common as pc  # noqa: E402
import gen_palette as gp  # noqa: E402
from player_parts import image_pixels, smoothstep  # noqa: E402

SLOT_ATTR = "pipe_slot"
CAP_ATTR = "pipe_cap"


def luminance(pix):
	return (0.299 * pix[..., 0] + 0.587 * pix[..., 1] + 0.114 * pix[..., 2]).astype(np.float32)


def ridge_map(lum, radius):
	"""How much darker each pixel is than the lighter of its two sides, over the best of four directions (0 on a step edge)."""
	h, w = lum.shape
	pad = np.pad(lum, radius, mode="edge")
	best = np.zeros_like(lum)
	for dx, dy in ((1, 0), (0, 1), (1, 1), (1, -1)):
		a = pad[radius + dy * radius:radius + dy * radius + h, radius + dx * radius:radius + dx * radius + w]
		b = pad[radius - dy * radius:radius - dy * radius + h, radius - dx * radius:radius - dx * radius + w]
		best = np.maximum(best, np.minimum(a, b) - lum)
	return best


def max3(a):
	p = np.pad(a, 1, mode="edge")
	h, w = a.shape
	out = a.copy()
	for dy in (0, 1, 2):
		for dx in (0, 1, 2):
			out = np.maximum(out, p[dy:dy + h, dx:dx + w])
	return out


def shifted(a, dy, dx, fill):
	"""`a` moved by (dy, dx) texels, the texels that come from outside the image `fill`."""
	h, w = a.shape
	out = np.full_like(a, fill)
	ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
	xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
	out[yd, xd] = a[ys, xs]
	return out


def square_filter(a, radius, take_max):
	"""A (2 r + 1) square maximum (take_max) or minimum filter; the outside of the image is the empty value."""
	fill = 0.0 if take_max else 1.0
	out = a.copy()
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			moved = shifted(a, dy, dx, fill)
			out = np.maximum(out, moved) if take_max else np.minimum(out, moved)
	return out


def clean_lines(lines, cc):
	"""The stroke terms of the mask (an image, 0..1) without its blots and specks, and what was removed.
	cc: blob_radius_texels (0 = no opening), blob_grow_texels, speck_min_texels (0 = none)."""
	ink = lines > 0.5
	removed_blob = 0
	r = int(cc.get("blob_radius_texels", 0))
	if r > 0:
		core = square_filter(square_filter(ink.astype(np.float32), r, False), r, True) > 0.5  # the opening: what survives an erosion
		blot = square_filter(core.astype(np.float32), int(cc.get("blob_grow_texels", 1)), True) > 0.5
		removed_blob = int((ink & blot).sum())
		lines = np.where(blot, 0.0, lines)
		ink = lines > 0.5
	removed_specks = 0
	smallest = int(cc.get("speck_min_texels", 0))
	if smallest > 0:
		h, w = ink.shape
		seen = np.zeros_like(ink)
		for y0, x0 in zip(*np.nonzero(ink)):
			if seen[y0, x0]:
				continue
			seen[y0, x0] = True
			piece, todo = [(y0, x0)], [(y0, x0)]
			while todo:
				y, x = todo.pop()
				for dy in (-1, 0, 1):
					for dx in (-1, 0, 1):
						yy, xx = y + dy, x + dx
						if 0 <= yy < h and 0 <= xx < w and ink[yy, xx] and not seen[yy, xx]:
							seen[yy, xx] = True
							piece.append((yy, xx))
							todo.append((yy, xx))
			if len(piece) < smallest:
				for y, x in piece:
					lines[y, x] = 0.0
				removed_specks += 1
	return lines, {"blob_texels_removed": removed_blob, "speck_pieces_removed": removed_specks}


def vertex_cavity(verts, polys):
	"""How deep each vertex sits in a groove, scale-free: the mean of its neighbours lies this many edge lengths above it along its
	normal (positive in a crease or a fold, negative on a ridge, about 0 on a plane). The dense mesh holds the strands of the
	wraps, the stitching of the glove, the folds of the cloth as real grooves; the 1k mask carries them as lines."""
	a, b, c = verts[polys[:, 0]], verts[polys[:, 1]], verts[polys[:, 2]]
	fn = np.cross(b - a, c - a)
	vn = np.zeros_like(verts)
	for k in range(3):
		np.add.at(vn, polys[:, k], fn)
	vn /= np.maximum(np.linalg.norm(vn, axis=1, keepdims=True), 1e-12)
	acc = np.zeros_like(verts)
	cnt = np.zeros(len(verts))
	elen = np.zeros(len(verts))
	for i, j in ((0, 1), (1, 2), (2, 0)):
		u, v = polys[:, i], polys[:, j]
		d = verts[v] - verts[u]
		L = np.linalg.norm(d, axis=1)
		np.add.at(acc, u, verts[v])
		np.add.at(acc, v, verts[u])
		np.add.at(cnt, u, 1.0)
		np.add.at(cnt, v, 1.0)
		np.add.at(elen, u, L)
		np.add.at(elen, v, L)
	cnt = np.maximum(cnt, 1.0)
	mean = acc / cnt[:, None]
	height = ((mean - verts) * vn).sum(axis=1)
	return height / np.maximum(elen / cnt, 1e-9)


class Dense:
	"""A dense, textured source: its triangles, their UVs and a BVH, with the ridge map of its texture."""

	def __init__(self, name, objs, pix, keep_slot_zero, radius):
		verts, polys, uvs = [], [], []
		base = 0
		for o in objs:
			me = o.data
			co = pb.verts(me)
			me.calc_loop_triangles()
			slot = None
			if keep_slot_zero and SLOT_ATTR in me.attributes:
				slot = np.empty(len(me.polygons), dtype=np.int32)
				me.attributes[SLOT_ATTR].data.foreach_get("value", slot)
			uvl = np.empty(len(me.loops) * 2, dtype=np.float32)
			me.uv_layers[0].data.foreach_get("uv", uvl)
			uvl = uvl.reshape(-1, 2)
			for lt in me.loop_triangles:
				if slot is not None and slot[lt.polygon_index] != 0:
					continue
				polys.append(tuple(base + i for i in lt.vertices))
				uvs.append(uvl[list(lt.loops)])
			verts += [tuple(v) for v in co]
			base += len(co)
		self.name = name
		self.verts = np.array(verts)
		self.polys = np.array(polys, dtype=np.int64)
		self.uvs = np.array(uvs)
		self.cavity = vertex_cavity(self.verts, self.polys)
		self.bvh = BVHTree.FromPolygons([tuple(v) for v in verts], [tuple(int(i) for i in p) for p in polys])
		lum = luminance(pix)
		self.ridge = max3(ridge_map(lum, radius))
		self.h, self.w = lum.shape

	def nearest(self, points):
		"""(distance, uv) of the dense surface nearest to each point."""
		n = len(points)
		dist = np.full(n, np.inf)
		tri = np.zeros(n, dtype=np.int64)
		loc = np.zeros((n, 3))
		find = self.bvh.find_nearest
		for i in range(n):
			l, _nrm, idx, d = find(Vector(points[i]))
			if idx is not None:
				dist[i], tri[i], loc[i] = d, idx, l
		a, b, c = (self.verts[self.polys[tri, k]] for k in range(3))
		v0, v1, v2 = b - a, c - a, loc - a
		d00, d01, d11 = (v0 * v0).sum(1), (v0 * v1).sum(1), (v1 * v1).sum(1)
		d20, d21 = (v2 * v0).sum(1), (v2 * v1).sum(1)
		den = d00 * d11 - d01 * d01
		den = np.where(np.abs(den) < 1e-18, 1.0, den)
		v = (d11 * d20 - d01 * d21) / den
		u = (d00 * d21 - d01 * d20) / den
		bary = np.stack([1.0 - u - v, v, u], axis=1)
		uv = np.einsum("nk,nkc->nc", bary, self.uvs[tri])
		cav = np.einsum("nk,nk->n", bary, self.cavity[self.polys[tri]])
		return dist, uv, cav

	def ridge_at(self, uv):
		x = np.clip((uv[:, 0] * self.w).astype(np.int64), 0, self.w - 1)
		y = np.clip((uv[:, 1] * self.h).astype(np.int64), 0, self.h - 1)
		return self.ridge[y, x]


def relayout_uv2(cfg, dc):
	"""Re-unwrap UV2 of the final meshes so the mask's texels go where the player looks: the palette step's layout spends texels by
	area, and half the body is hidden in first person. Every island is scaled by dc.layout.weights (the hidden mesh small, the
	forearms, hands, legs and shoes large) and all islands of all meshes are packed together. Cap faces stay at (0, 0).
	Saves work/06_split.blend (the exporter reads it) and returns a report."""
	lc = dc["layout"]
	pb.open_blend(pc.work_path(cfg, "06_split.blend"))
	objs = pb.body_objects()
	col = {n: i for i, n in enumerate(pc.bone_names())}
	weights = lc["weights"]
	for o in objs:
		me = o.data
		cap = np.zeros(len(me.polygons), dtype=np.int32)
		if CAP_ATTR in me.attributes:
			me.attributes[CAP_ATTR].data.foreach_get("value", cap)
		me.uv_layers.active = me.uv_layers["detail"]
		for p2 in me.polygons:
			p2.select = bool(cap[p2.index] == 0)
	pb.activate(objs[0])
	for o in objs:
		o.select_set(True)
	import bpy as _bpy
	_bpy.ops.object.mode_set(mode="EDIT")
	_bpy.ops.mesh.select_mode(type="FACE")
	_bpy.ops.uv.smart_project(angle_limit=math.radians(float(lc.get("angle_deg", 66.0))), island_margin=float(lc.get("margin", 0.002)), correct_aspect=True, scale_to_bounds=False)
	_bpy.ops.object.mode_set(mode="OBJECT")
	report = {"islands": {}, "scaled": {}}
	for o in objs:
		me = o.data
		w = pb.weights_matrix(o, pc.bone_names())
		start, total, lv = pb.poly_arrays(me)
		acc = np.zeros((len(start), w.shape[1]))
		for k in range(int(total.max())):
			mask = total > k
			acc[mask] += w[lv[start[mask] + k]]
		dom = np.argmax(acc, axis=1)
		names = pc.bone_names()
		face_factor = np.array([weights["part:" + o.name] if ("part:" + o.name) in weights else weights.get(names[d], weights["default"]) for d in dom])
		cap = np.zeros(len(me.polygons), dtype=np.int32)
		if CAP_ATTR in me.attributes:
			me.attributes[CAP_ATTR].data.foreach_get("value", cap)
		bm = bmesh.new()
		bm.from_mesh(me)
		bm.faces.ensure_lookup_table()
		uvl = bm.loops.layers.uv["detail"]
		parent = list(range(len(bm.faces)))

		def find(x):
			while parent[x] != x:
				parent[x] = parent[parent[x]]
				x = parent[x]
			return x
		for e in bm.edges:
			if len(e.link_loops) != 2:
				continue
			l1, l2 = e.link_loops
			f1, f2 = l1.face.index, l2.face.index
			if cap[f1] or cap[f2]:
				continue
			# the two loops run the edge in opposite directions: l1 a->b matches l2's b->a
			a1, b1 = l1[uvl].uv, l1.link_loop_next[uvl].uv
			if l2.vert == l1.vert:
				a2, b2 = l2[uvl].uv, l2.link_loop_next[uvl].uv
			else:
				b2, a2 = l2[uvl].uv, l2.link_loop_next[uvl].uv
			if (a1 - a2).length < 1e-6 and (b1 - b2).length < 1e-6:
				parent[find(f1)] = find(f2)
		groups = {}
		for f in range(len(bm.faces)):
			if not cap[f]:
				groups.setdefault(find(f), []).append(f)
		for faces in groups.values():
			uvs = np.array([tuple(lp[uvl].uv) for f in faces for lp in bm.faces[f].loops])
			c = uvs.mean(axis=0)
			fct = float(np.mean(face_factor[faces]))
			for f in faces:
				for lp in bm.faces[f].loops:
					lp[uvl].uv = (c[0] + (lp[uvl].uv[0] - c[0]) * fct, c[1] + (lp[uvl].uv[1] - c[1]) * fct)
		bm.to_mesh(me)
		bm.free()
		report["islands"][o.name] = len(groups)
	for o in objs:
		o.data.uv_layers.active = o.data.uv_layers["detail"]
	pb.activate(objs[0])
	for o in objs:
		o.select_set(True)
		for p2 in o.data.polygons:
			p2.select = True
	_bpy.ops.object.mode_set(mode="EDIT")
	_bpy.ops.mesh.select_mode(type="FACE")
	for o in objs:  # the caps do not take part in the packing
		pass
	_bpy.ops.uv.pack_islands(rotate=True, margin=float(lc.get("margin", 0.002)), margin_method="SCALED", shape_method="CONCAVE")
	_bpy.ops.object.mode_set(mode="OBJECT")
	for o in objs:
		me = o.data
		cap = np.zeros(len(me.polygons), dtype=np.int32)
		if CAP_ATTR in me.attributes:
			me.attributes[CAP_ATTR].data.foreach_get("value", cap)
		uvl = me.uv_layers["detail"]
		start, total, lv = pb.poly_arrays(me)
		uv = np.empty(len(me.loops) * 2, dtype=np.float32)
		uvl.data.foreach_get("uv", uv)
		uv = uv.reshape(-1, 2)
		for f in np.nonzero(cap)[0]:
			uv[start[f]:start[f] + total[f]] = (0.0, 0.0)
		uvl.data.foreach_set("uv", uv.ravel())
		me.uv_layers.active = me.uv_layers["palette"]
	pb.save_blend(pc.work_path(cfg, "06_split.blend"))
	return report


def load_final(cfg):
	"""The final meshes' triangles: (positions (n, 3, 3), uv2 (n, 3, 2), slot (n,), border flags (n, 3), mesh name per triangle)."""
	pb.open_blend(pc.work_path(cfg, "06_split.blend"))
	pos, uv2, slot, flags, owner = [], [], [], [], []
	for ob in pb.body_objects():
		me = ob.data
		co = pb.verts(me)
		start, total, lv = pb.poly_arrays(me)
		cap = np.zeros(len(me.polygons), dtype=np.int32)
		if CAP_ATTR in me.attributes:
			me.attributes[CAP_ATTR].data.foreach_get("value", cap)
		p_uv = np.empty(len(me.loops) * 2, dtype=np.float32)
		me.uv_layers["palette"].data.foreach_get("uv", p_uv)
		p_uv = p_uv.reshape(-1, 2)
		d_uv = np.empty(len(me.loops) * 2, dtype=np.float32)
		me.uv_layers["detail"].data.foreach_get("uv", d_uv)
		d_uv = d_uv.reshape(-1, 2)
		face_slot = np.array([gp.slot_of_uv(float(u), 1.0 - float(v)) for u, v in p_uv[start]], dtype=np.int32)
		nbr = {}
		for f in range(len(start)):
			if total[f] != 3:
				continue
			a, b, c = (int(i) for i in lv[start[f]:start[f] + 3])
			for k, (x, y) in enumerate(((b, c), (c, a), (a, b))):
				nbr.setdefault((min(x, y), max(x, y)), []).append((f, k))
		fl = np.zeros((len(start), 3), dtype=bool)
		for key, lst in nbr.items():
			if len(lst) == 2 and cap[lst[0][0]] == 0 and cap[lst[1][0]] == 0 and face_slot[lst[0][0]] != face_slot[lst[1][0]]:
				for f, k in lst:
					fl[f, k] = True
		for f in range(len(start)):
			if total[f] != 3 or cap[f]:
				continue
			idx = lv[start[f]:start[f] + 3]
			pos.append(co[idx])
			uv2.append(d_uv[start[f]:start[f] + 3])
			slot.append(face_slot[f])
			flags.append(fl[f])
			owner.append(ob.name)
	return np.array(pos), np.array(uv2), np.array(slot), np.array(flags), owner


def rasterise(uv2, size):
	"""Texel -> (triangle, barycentric) for the final surface, in UV2 space (Blender UV, origin bottom left)."""
	tri_of = np.full(size * size, -1, dtype=np.int64)
	lam_of = np.zeros((size * size, 3))
	for t in range(len(uv2)):
		p = uv2[t] * size
		x0, x1 = int(np.floor(p[:, 0].min() - 0.5)), int(np.ceil(p[:, 0].max() + 0.5))
		y0, y1 = int(np.floor(p[:, 1].min() - 0.5)), int(np.ceil(p[:, 1].max() + 0.5))
		x0, y0 = max(x0, 0), max(y0, 0)
		x1, y1 = min(x1, size - 1), min(y1, size - 1)
		if x1 < x0 or y1 < y0:
			continue
		den = (p[1, 1] - p[2, 1]) * (p[0, 0] - p[2, 0]) + (p[2, 0] - p[1, 0]) * (p[0, 1] - p[2, 1])
		if abs(den) < 1e-9:
			continue
		xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
		l0 = ((p[1, 1] - p[2, 1]) * (xs - p[2, 0]) + (p[2, 0] - p[1, 0]) * (ys - p[2, 1])) / den
		l1 = ((p[2, 1] - p[0, 1]) * (xs - p[2, 0]) + (p[0, 0] - p[2, 0]) * (ys - p[2, 1])) / den
		l2 = 1.0 - l0 - l1
		eps = -0.02
		inside = (l0 >= eps) & (l1 >= eps) & (l2 >= eps)
		if not inside.any():
			continue
		idx = (ys[inside].astype(np.int64)) * size + xs[inside].astype(np.int64)
		tri_of[idx] = t
		lam_of[idx] = np.stack([l0[inside], l1[inside], l2[inside]], axis=1)
	return tri_of, lam_of


def run(cfg, extra):
	dc = cfg["detail"]
	size = int(dc["size"])
	layout = relayout_uv2(cfg, dc) if dc.get("layout") else None
	pos, uv2, slot, flags, owner = load_final(cfg)
	tri_of, lam_of = rasterise(uv2, size)
	covered = tri_of >= 0
	idx = np.nonzero(covered)[0]
	tri = tri_of[idx]
	lam = np.clip(lam_of[idx], 0.0, 1.0)
	points = np.einsum("nk,nkc->nc", lam, pos[tri])

	# ----- borders: the distance to a flagged triangle edge, in texels (the altitude of the triangle's UV corner times lambda)
	uvp = uv2 * size
	alt = np.zeros((len(uvp), 3))
	for k in range(3):
		a, b = uvp[:, (k + 1) % 3], uvp[:, (k + 2) % 3]
		e = b - a
		area2 = np.abs(e[:, 0] * (uvp[:, k, 1] - a[:, 1]) - e[:, 1] * (uvp[:, k, 0] - a[:, 0]))
		alt[:, k] = area2 / np.maximum(np.linalg.norm(e, axis=1), 1e-9)
	dist_edge = lam * alt[tri]
	border = np.zeros(len(idx))
	half = float(dc["border_px"]) / 2.0
	for k in range(3):
		on = flags[tri, k]
		border = np.maximum(border, np.where(on, 1.0 - smoothstep(dist_edge[:, k], half, half + float(dc.get("border_soft_px", 0.75))), 0.0))

	# ----- strokes: the dense sources' ridge maps at the nearest dense point
	body_objs = None
	pb.open_blend(pc.work_path(cfg, "04_parts.blend"))
	body = bpy.data.objects[pb.BODY]
	image = None
	for mat in body.data.materials:
		if mat and mat.use_nodes:
			for n in mat.node_tree.nodes:
				if n.type == "TEX_IMAGE" and n.image is not None:
					image = n.image
	if image is None:
		pc.fail("the dense body has no texture")
	radius = int(dc["stroke"]["radius_px"])
	dense_body = Dense("body", [body], image_pixels(image), True, radius)
	fist_path = pc.work_path(cfg, "04a_fists_dense.blend")
	dense_fist = None
	if os.path.exists(fist_path):
		bpy.ops.wm.read_factory_settings(use_empty=True)
		with bpy.data.libraries.load(fist_path, link=False) as (src, dst):
			dst.objects = list(src.objects)
			dst.images = list(src.images)
		objs = [o for o in dst.objects if o is not None]
		img = next(i for i in dst.images if i is not None)
		dense_fist = Dense("fist", objs, image_pixels(img), False, radius)
	db, ub, cb = dense_body.nearest(points)
	if dense_fist is not None:
		df, uf, cf = dense_fist.nearest(points)
	else:
		df, uf, cf = np.full(len(points), np.inf), np.zeros((len(points), 2)), np.zeros(len(points))
	use_fist = df < db
	ridge = np.where(use_fist, dense_fist.ridge_at(uf) if dense_fist is not None else 0.0, dense_body.ridge_at(ub))
	cav = np.where(use_fist, cf, cb)
	t0, t1 = float(dc["stroke"]["lo"]), float(dc["stroke"]["hi"])
	stroke = smoothstep(ridge, t0, t1) * float(dc["stroke"]["gain"])
	cc = dc["crease"]
	crease = smoothstep(cav, float(cc["lo"]), float(cc["hi"])) * float(cc["gain"])
	# bare muscle takes no crease ink (a groove 2 mm wide is 9 px at the 0.2 m the lead arm passes the lens); the fingers' creases
	# on the fist piece do, and the cloth, wraps and glove everywhere
	skin_slots = [int(x) for x in cc.get("skip_slots", [])]
	crease = np.where(use_fist, crease * float(cc.get("fist_gain", 1.0)), np.where(np.isin(slot[tri], skin_slots), 0.0, crease))
	# a dark speck of the generated texture on bare skin (a mole, a pore) is not a line either: the bare body's skin takes no stroke ink
	# (detail.stroke.skip_slots), the fingers on the fist piece keep theirs
	stroke_skip = [int(x) for x in dc["stroke"].get("skip_slots", [])]
	stroke = np.where(use_fist, stroke, np.where(np.isin(slot[tri], stroke_skip), 0.0, stroke))
	stroke = np.maximum(stroke, crease)
	# the toon shader cuts this mask (look_detail_cut): the glove's mottling would be black patches, a partial value a line of its own
	glove = use_fist & np.isin(slot[tri], [int(x) for x in dc.get("fist_skip_slots", [])])
	stroke = np.where(glove, 0.0, stroke)
	hd = dc.get("harden")
	if hd:
		stroke = smoothstep(stroke, float(hd["lo"]), float(hd["hi"]))
	lines = np.zeros(size * size)
	lines[idx] = stroke
	lines, cleaned = clean_lines(lines.reshape(size, size), dc.get("clean", {}))
	borders = np.zeros(size * size)
	borders[idx] = border
	img2 = np.clip(np.maximum(borders.reshape(size, size), lines), 0.0, 1.0)
	ink = img2.ravel()[idx]
	stroke_kept = lines.ravel()[idx]
	cov = covered.reshape(size, size)
	# grow into the empty space so a filtered lookup at an island's edge reads ink, not nothing
	for _ in range(int(dc.get("dilate_px", 2))):
		p = np.pad(img2, 1, mode="constant")
		cp = np.pad(cov, 1, mode="constant")
		grown = np.zeros_like(img2)
		have = np.zeros_like(cov)
		for dy in (0, 1, 2):
			for dx in (0, 1, 2):
				nb = p[dy:dy + size, dx:dx + size]
				nc = cp[dy:dy + size, dx:dx + size]
				grown = np.where(nc & ~cov & ~have, nb, np.where(nc & ~cov, np.maximum(grown, nb), grown))
				have |= nc & ~cov
		img2 = np.where(cov, img2, grown)
		cov = cov | have
	rgba = np.ones((size, size, 4), dtype=np.float32)
	rgba[..., 0] = img2
	rgba[..., 1] = img2
	rgba[..., 2] = img2
	out_dir = pc.cfg_dir(cfg, "export_dir")
	os.makedirs(out_dir, exist_ok=True)
	out_path = os.path.join(out_dir, dc.get("name", "player_detail.png"))
	image_out = bpy.data.images.new("detail", size, size, alpha=False)
	image_out.colorspace_settings.name = "Non-Color"
	image_out.pixels.foreach_set(rgba.ravel())
	image_out.filepath_raw = out_path
	image_out.file_format = "PNG"
	image_out.save()
	# texel size on the surface: the area ratio of each triangle, in millimetres
	a3 = 0.5 * np.linalg.norm(np.cross(pos[:, 1] - pos[:, 0], pos[:, 2] - pos[:, 0]), axis=1)
	auv = 0.5 * np.abs((uvp[:, 1, 0] - uvp[:, 0, 0]) * (uvp[:, 2, 1] - uvp[:, 0, 1]) - (uvp[:, 2, 0] - uvp[:, 0, 0]) * (uvp[:, 1, 1] - uvp[:, 0, 1]))
	ok = auv > 1e-6
	texel_mm = np.sqrt(a3[ok] / auv[ok]) * 1000.0
	return {
		"file": os.path.basename(out_path), "sha256": pc.sha256_file(out_path), "size": size,
		"triangles": int(len(pos)), "covered_texels": int(covered.sum()), "covered_share": float(covered.mean()),
		"ink_share_of_covered": float((ink > 0.5).mean()), "border_texels": int((border > 0.5).sum()), "stroke_texels": int((stroke_kept > 0.5).sum()), "crease_texels": int((crease > 0.5).sum()),
		"ink_mean": float(img2.mean()), "ink_texels": int((img2 > 0.5).sum()), "cleaned": cleaned,
		"texel_mm_p50": float(np.percentile(texel_mm, 50)), "texel_mm_p10": float(np.percentile(texel_mm, 10)), "texel_mm_p90": float(np.percentile(texel_mm, 90)),
		"from_fist_share": float(use_fist.mean()), "layout": layout,
	}


if __name__ == "__main__":
	pb.run_step("detail", run)
