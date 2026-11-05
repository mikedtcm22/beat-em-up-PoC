"""The Punk's detail mask (M4 package F-punk, plan Part A A18): a 1k ink-only mask on UV2 baked from the dense texture.

Imported by blender_palette.py (Blender 5.x headless; never the Blender MCP) when `palette.detail_bake` is set. The slice
gate found the interior detail of the concept (mouth, pocket flaps, buttons, stitching, laces, tape edges) lost at 1 m
because every face is one flat swatch. The mask is the thin dark lines of the source texture and nothing else:

	1. ink in texture space (and no ink within edge_margin_px of the border of a UV island, where the generator's padding
	   would draw the texture's seams): the BLACK TOP-HAT of each colour channel (the grey-scale closing of the image minus the image,
	   with a (2 r + 1)-pixel square window): a line narrower than the window that is darker than both its sides lights up,
	   while a flat area, a soft gradient (shading) and the edge between two flat colours do not. The largest channel wins,
	   then a smoothstep between `ink_low` and `ink_high` turns it into 0..1;
	2. bake: every texel of the mask (size x size, the UV2 layout of the final mesh) is the final mesh's surface point of
	   that texel (barycentric on its UV2 triangle), looked up on the DENSE mesh (nearest face, BVH), whose UV reads the
	   texture-space ink (bilinear). So the mask holds the lines of the generated texture and no shading, whatever the
	   decimation did to the mesh;
	3. written as an 8-bit PNG, R = ink (the toon shader mixes toward ink by `.r`), G = the glint gate (below), B 0.
The stroke cleanup (rescore-rs-03, config `detail_bake.clean`): the bake takes one bilinear tap per 2.6 mm texel from a source whose
lines are about 1 to 3 mm wide, so a strand came out as dots and short dashes (886 of 1,144 pieces were 6 texels or fewer, the median 2)
and the shader's cut drew each as a dot, with a texel staircase for an edge. Before the file is written the gaps inside a stroke (up to
`bridge_px` texels) are bridged, every piece shorter than `min_extent_texels` (its bounding box's long side) or smaller than
`min_texels` is dropped, so a strand is one continuous line whose end thins out and a speck is gone, and the cleaned
mask may be blurred a little (`smooth_sigma`, `smooth_gain`) so the shader's cut draws a smooth contour, not a staircase. See clean_strokes().
The glove's line (rescore-rs-02, config `detail_bake.glove_lines`): the generated glove is a smooth dark dome whose texture has no line
to extract, and at a strike's contact it fills a fifth of the view as two flat tones. Its back gets AUTHORED lines in the hand's own
frame (the hand bone's axis, the outward side the back of the hand faces): a ring round the glove where the cuff meets it (the strap's
edge) and an outline of the dorsal plate with its knuckle edge, written as a distance ramp (the 0.15 contour of the shader's cut lies
`width_m` / 2 from the line, so the edge is smooth from a 1k texel) and merged over the cleaned strokes. See glove_lines_field().
The glint gate (rescore-rs-01, config `detail_bake.glint`): the shades' lens is the one glossy swatch, and its glint is a cap on an angle,
which whites the whole lens out when the head tips back. G holds the AUTHORED streaks of concept A, two diagonal bands per eye, as a
signed-distance ramp (0.5 on a band's edge, so the shader's cut at 0.5 draws the edge sharp from a 1k texel) on the lens's texels only;
the shader multiplies the glint by it, so the glint can only ever light a streak. Every other texel's G is 0.
The crease ink (M6 FB-DETAIL, config `detail_bake.crease`): a Tripo texture is delit and flat, so the edges of a plate, a visor or a guard
are in its GEOMETRY and never in its colours, and the top-hat finds only the texture's scribbles. `crease` draws the sharp edges of the dense mesh
(the dihedral angle between two faces over `angle_deg`) as a distance ramp of `width_m` on the baked texels near them, merged with the texture's
ink before the cleanup; a zone's `crease_deg` replaces the angle on its faces (a number over 180 turns it off). See crease_edges().
Every number is in pipeline.json palette.detail_bake; the lines' look is calibrated on the picture the step writes beside the
mask (<report>/detail_source.png: the ink in texture space).
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipe_blender as pb  # noqa: E402


def _shift_max(a, r, axis):
	out = a.copy()
	for k in range(1, r + 1):
		for sign in (k, -k):
			sh = np.roll(a, sign, axis=axis)
			if sign > 0:
				if axis == 0:
					sh[:sign] = a[:1]
				else:
					sh[:, :sign] = a[:, :1]
			else:
				if axis == 0:
					sh[sign:] = a[-1:]
				else:
					sh[:, sign:] = a[:, -1:]
			np.maximum(out, sh, out=out)
	return out


def dilate(a, r):
	return _shift_max(_shift_max(a, r, 0), r, 1)


def erode(a, r):
	return -dilate(-a, r)


def ink_raw(pix, radius_px):
	"""pix (h, w, 3) floats 0..1 -> the black top-hat of each channel, the largest channel's (h, w), unshaped."""
	best = np.zeros(pix.shape[:2], dtype=np.float32)
	for c in range(3):
		ch = pix[:, :, c].astype(np.float32)
		closing = erode(dilate(ch, radius_px), radius_px)
		best = np.maximum(best, closing - ch)
	return best


def shape(x, low, high):
	"""A smoothstep from `low` to `high` (scalars or arrays): the raw top-hat becomes 0..1 ink."""
	t = np.clip((x - low) / np.maximum(high - low, 1e-6), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def ink_in_texture_space(pix, radius_px, low, high):
	"""pix (h, w, 3) floats 0..1 -> ink (h, w) 0..1 by the black top-hat of each channel."""
	return shape(ink_raw(pix, radius_px), low, high)


def coverage(corner_uv, w, h):
	"""(h, w) 1.0 where a triangle of the dense mesh covers the texel (corner_uv (m, 3, 2) in 0..1), else 0."""
	cov = np.zeros((h, w), dtype=np.float32)
	px = corner_uv * np.array([w, h])
	for t in range(len(px)):
		a, b, c = px[t]
		x0, x1 = int(np.floor(min(a[0], b[0], c[0]))), int(np.ceil(max(a[0], b[0], c[0])))
		y0, y1 = int(np.floor(min(a[1], b[1], c[1]))), int(np.ceil(max(a[1], b[1], c[1])))
		x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, w - 1), min(y1, h - 1)
		if x1 < x0 or y1 < y0:
			continue
		xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
		d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
		if abs(d) < 1e-12:
			continue
		l0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / d
		l1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / d
		inside = (l0 >= 0) & (l1 >= 0) & (l0 + l1 <= 1)
		cov[y0:y1 + 1, x0:x1 + 1][inside] = 1.0
	return cov


def bilinear(img, uv):
	"""img (h, w) sampled at uv (n, 2) in 0..1 (v up, row 0 the bottom: Blender's pixel order)."""
	h, w = img.shape
	x = np.clip(uv[:, 0] * w - 0.5, 0, w - 1.001)
	y = np.clip(uv[:, 1] * h - 0.5, 0, h - 1.001)
	x0, y0 = np.floor(x).astype(np.int64), np.floor(y).astype(np.int64)
	fx, fy = x - x0, y - y0
	a = img[y0, x0] * (1 - fx) + img[y0, x0 + 1] * fx
	b = img[y0 + 1, x0] * (1 - fx) + img[y0 + 1, x0 + 1] * fx
	return a * (1 - fy) + b * fy


def rasterize(me, layer_name, size):
	"""For every texel centre covered by a triangle of `me`'s UV layer: its position on the mesh. Returns (texel index
	(n, 2) as (row, col), position (n, 3)). The last triangle wins an overlap."""
	co = pb.verts(me)
	start, total, lv = pb.poly_arrays(me)
	layer = me.uv_layers[layer_name]
	uv = np.empty(len(me.loops) * 2, dtype=np.float32)
	layer.data.foreach_get("uv", uv)
	uv = uv.reshape(-1, 2).astype(np.float64)
	n = len(start)
	owner = np.full((size, size), -1, dtype=np.int64)
	bary = np.zeros((size, size, 3), dtype=np.float32)
	for f in range(n):
		a, b, c = uv[start[f]] * size, uv[start[f] + 1] * size, uv[start[f] + 2] * size
		x0, x1 = int(np.floor(min(a[0], b[0], c[0]))), int(np.ceil(max(a[0], b[0], c[0])))
		y0, y1 = int(np.floor(min(a[1], b[1], c[1]))), int(np.ceil(max(a[1], b[1], c[1])))
		x0, y0 = max(x0, 0), max(y0, 0)
		x1, y1 = min(x1, size - 1), min(y1, size - 1)
		if x1 < x0 or y1 < y0:
			continue
		xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
		d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
		if abs(d) < 1e-12:
			continue
		l0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / d
		l1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / d
		l2 = 1.0 - l0 - l1
		inside = (l0 >= -1e-6) & (l1 >= -1e-6) & (l2 >= -1e-6)
		if not inside.any():
			continue
		iy, ix = np.nonzero(inside)
		owner[y0 + iy, x0 + ix] = f
		bary[y0 + iy, x0 + ix, 0] = l0[iy, ix]
		bary[y0 + iy, x0 + ix, 1] = l1[iy, ix]
		bary[y0 + iy, x0 + ix, 2] = l2[iy, ix]
	rows, cols = np.nonzero(owner >= 0)
	f = owner[rows, cols]
	face_of_texel = f.copy()
	bw = bary[rows, cols]
	v0, v1, v2 = lv[start[f]], lv[start[f] + 1], lv[start[f] + 2]
	pos = co[v0] * bw[:, 0:1] + co[v1] * bw[:, 1:2] + co[v2] * bw[:, 2:3]
	return np.stack([rows, cols], axis=1), pos, face_of_texel


def pieces_of(ink):
	"""The 8-connected pieces of a boolean image (h, w): a list of (rows, cols) index arrays."""
	h, w = ink.shape
	seen = np.zeros_like(ink)
	out = []
	for y0, x0 in zip(*np.nonzero(ink)):
		if seen[y0, x0]:
			continue
		seen[y0, x0] = True
		stack, rows, cols = [(y0, x0)], [], []
		while stack:
			y, x = stack.pop()
			rows.append(y)
			cols.append(x)
			for dy in (-1, 0, 1):
				for dx in (-1, 0, 1):
					yy, xx = y + dy, x + dx
					if 0 <= yy < h and 0 <= xx < w and ink[yy, xx] and not seen[yy, xx]:
						seen[yy, xx] = True
						stack.append((yy, xx))
		out.append((np.array(rows), np.array(cols)))
	return out


def piece_stats(pieces):
	"""How fragmented a stroke layer is: the number of pieces, of 6 texels or fewer (and their share of the ink texels), the median
	piece and the pieces over 20 texels."""
	sizes = np.array([len(p[0]) for p in pieces]) if pieces else np.zeros(0, dtype=np.int64)
	total = max(int(sizes.sum()), 1)
	return {"pieces": int(len(sizes)), "texels": int(sizes.sum()), "pieces_le6": int((sizes <= 6).sum()),
		"texels_in_le6_share": round(float(sizes[sizes <= 6].sum()) / total, 4), "median": float(np.median(sizes)) if len(sizes) else 0.0,
		"pieces_over20": int((sizes > 20).sum())}


def shifted(a, dy, dx):
	"""`a` (h, w) moved by (dy, dx) texels (out[y, x] = a[y - dy, x - dx]); what comes from outside the image is the array's zero."""
	h, w = a.shape
	out = np.zeros_like(a)
	ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
	xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
	out[yd, xd] = a[ys, xs]
	return out


def orientation_at(ink, ys, xs, radius):
	"""The direction a stroke runs at each ink texel (ys, xs): the principal axis of the ink texels within `radius` of it, as a unit
	vector (dy, dx) and the share of the variance on it (1 = a straight line, 0.5 = a blob). Nothing is assumed of a texel alone: a
	single texel takes the direction of whatever ink is near it."""
	h, w = ink.shape
	out = np.zeros((len(ys), 2))
	straight = np.zeros(len(ys))
	for i, (y, x) in enumerate(zip(ys, xs)):
		win = ink[max(y - radius, 0):min(y + radius + 1, h), max(x - radius, 0):min(x + radius + 1, w)]
		wy, wx = np.nonzero(win)
		if len(wy) < 2:
			continue
		pts = np.stack([wy, wx], axis=1).astype(np.float64)
		pts -= pts.mean(axis=0)
		vals, vecs = np.linalg.eigh(pts.T @ pts)
		out[i] = vecs[:, 1]
		straight[i] = vals[1] / max(vals.sum(), 1e-9)
	return out, straight


def bridge_gaps(ink, covered, gap, radius=3, align_deg=35.0, min_straight=0.0):
	"""Fill the gaps along a stroke: for two ink texels with up to `gap` empty texels between them in a straight run (a row, a column or
	a diagonal), the gap is filled when that direction is within `align_deg` of the way the stroke runs at BOTH ends (orientation_at over
	`radius`) and the ink round both ends is straight enough (`min_straight`, the share of its variance on the axis). So a strand that broke into dots or dashes is one line again, while two parallel strands a texel or two apart (the pair
	runs across them) are not joined, which a closing would do, and a blot is not made. Only texels a triangle covers are filled."""
	out = ink.copy()
	ys, xs = np.nonzero(ink)
	index = -np.ones(ink.shape, dtype=np.int64)
	index[ys, xs] = np.arange(len(ys))
	direction, straight = orientation_at(ink, ys, xs, radius)
	cos_min = np.cos(np.radians(align_deg))
	h, w = ink.shape
	for i, (y, x) in enumerate(zip(ys, xs)):
		for dy, dx in ((0, 1), (1, 0), (1, 1), (1, -1), (0, -1), (-1, 0), (-1, -1), (-1, 1)):
			unit = np.array([dy, dx], dtype=np.float64)
			unit /= np.linalg.norm(unit)
			if straight[i] < min_straight or abs(float(direction[i] @ unit)) < cos_min:
				continue
			for k in range(2, gap + 2):
				yy, xx = y + dy * k, x + dx * k
				if not (0 <= yy < h and 0 <= xx < w):
					break
				if not ink[yy, xx]:
					continue
				j = index[yy, xx]
				if straight[j] >= min_straight and abs(float(direction[j] @ unit)) >= cos_min and all(not ink[y + dy * m, x + dx * m] for m in range(1, k)):
					for m in range(1, k):
						if covered[y + dy * m, x + dx * m]:
							out[y + dy * m, x + dx * m] = True
				break
	return out


def blur(a, sigma):
	"""A separable Gaussian blur (sigma in texels) of a float image, zero outside it."""
	r = max(int(np.ceil(3.0 * sigma)), 1)
	k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
	k /= k.sum()
	out = np.zeros_like(a)
	for i, wgt in enumerate(k):
		out += wgt * shifted(a, i - r, 0)
	res = np.zeros_like(a)
	for i, wgt in enumerate(k):
		res += wgt * shifted(out, 0, i - r)
	return res


def clean_strokes(mask, covered, cc):
	"""`mask` (h, w) 0..1 with the strokes in it, `covered` (h, w) bool: the texels a triangle of the mesh covers. The strokes are
	the texels over `cut` (the shader's cut); gaps of up to `bridge_px` texels along a stroke are bridged (bridge_gaps), every piece whose bounding
	box's long side is under `min_extent_texels` or that has fewer than `min_texels` texels is dropped (a speck, a dot of a faded strand's
	end), and with `smooth_sigma` > 0 the cleaned mask is blurred (`smooth_gain` times a Gaussian of that sigma in texels), so the shader's
	cut draws a smooth contour, not the texel staircase of a diagonal strand. The kept strokes keep their values and a bridged
	texel takes `close_value`. Returns (the cleaned mask, a report with the pieces before and after)."""
	cut = float(cc.get("cut", 0.15))
	ink = mask > cut
	before = piece_stats(pieces_of(ink))
	joined = bridge_gaps(ink, covered, int(cc.get("bridge_px", 1)), int(cc.get("orient_radius_px", 3)), float(cc.get("align_deg", 35.0)), float(cc.get("min_straight", 0.0))) \
		if int(cc.get("bridge_px", 1)) > 0 else ink
	keep = np.zeros_like(ink)
	for rows, cols in pieces_of(joined):
		extent = max(int(rows.max() - rows.min()), int(cols.max() - cols.min())) + 1
		if extent >= int(cc.get("min_extent_texels", 4)) and len(rows) >= int(cc.get("min_texels", 5)):
			keep[rows, cols] = True
	dropped = joined & ~keep
	out = mask.copy()
	fill = keep & ~ink
	out[fill] = np.maximum(out[fill], float(cc.get("close_value", 0.6)))
	# the dropped pieces and their faint flanks (values under the cut that are not a kept stroke's own) go
	zone = (dilate(dropped.astype(np.float32), 1) > 0.5) & ~(dilate(keep.astype(np.float32), 1) > 0.5)
	out[dropped | zone] = 0.0
	sigma = float(cc.get("smooth_sigma", 0.0))
	if sigma > 0.0:
		out = np.clip(float(cc.get("smooth_gain", 1.0)) * blur(out, sigma), 0.0, 1.0)
	after = piece_stats(pieces_of(out > cut))
	return out, {"before": before, "after": after, "bridged_texels": int((joined & ~ink).sum()), "pieces_dropped": int(len(pieces_of(dropped))),
		"texels_dropped": int(dropped.sum())}


def crease_edges(verts, tris, min_deg, spacing_m, min_chain_m=0.0, concave=None):
	"""The sharp edges of a triangle mesh as points: verts (n, 3), tris (m, 3) vertex indices -> (points (k, 3), angles (k,) in degrees),
	one point every `spacing_m` along every interior edge whose two faces meet at more than `min_deg` degrees (0 = flat). The sculpt's
	bumps make short crease fragments and a plate's edge a long run, so a run of connected crease edges (at the lowest angle asked for)
	shorter than `min_chain_m` in all is dropped. `concave` None keeps every edge (a ridge or a valley: M6 FB-DETAIL), True only the
	valleys (the far corner of one face lies in front of the other's plane: a fold, a quilt seam), False only the ridges (M6 DETAIL-2)."""
	a, b, c = verts[tris[:, 0]], verts[tris[:, 1]], verts[tris[:, 2]]
	nrm = np.cross(b - a, c - a)
	nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-12)
	e = np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]])
	face = np.tile(np.arange(len(tris)), 3)
	far = np.concatenate([tris[:, 2], tris[:, 0], tris[:, 1]])  # the corner of each face opposite the edge
	key = np.sort(e, axis=1)
	order = np.lexsort((key[:, 1], key[:, 0]))
	key, face, far = key[order], face[order], far[order]
	same = np.all(key[1:] == key[:-1], axis=1)
	first = np.nonzero(same)[0]
	f0, f1 = face[first], face[first + 1]
	ang = np.degrees(np.arccos(np.clip((nrm[f0] * nrm[f1]).sum(1), -1.0, 1.0)))
	keep = ang > min_deg
	if concave is not None:
		valley = ((verts[far[first + 1]] - verts[key[first, 0]]) * nrm[f0]).sum(1) > 0.0
		keep &= valley if concave else ~valley
	ea, eb = key[first[keep], 0], key[first[keep], 1]
	p0, p1 = verts[ea], verts[eb]
	ang = ang[keep]
	if min_chain_m > 0.0 and len(ang):
		parent = {}

		def find(x):
			while parent.setdefault(x, x) != x:
				parent[x] = parent[parent[x]]
				x = parent[x]
			return x
		for u, v in zip(ea.tolist(), eb.tolist()):
			parent[find(u)] = find(v)
		root = np.array([find(u) for u in ea.tolist()])
		length = np.linalg.norm(p1 - p0, axis=1)
		total = {}
		for r, l in zip(root.tolist(), length.tolist()):
			total[r] = total.get(r, 0.0) + l
		long_run = np.array([total[r] >= min_chain_m for r in root.tolist()])
		p0, p1, ang = p0[long_run], p1[long_run], ang[long_run]
	steps = np.maximum(np.ceil(np.linalg.norm(p1 - p0, axis=1) / max(spacing_m, 1e-4)).astype(np.int64), 1)
	pts, angs = [], []
	for k in range(int(steps.max()) + 1 if len(steps) else 0):
		sel = steps >= k
		t = (k / steps[sel])[:, None]
		pts.append(p0[sel] * (1 - t) + p1[sel] * t)
		angs.append(ang[sel])
	if not pts:
		return np.zeros((0, 3)), np.zeros(0)
	return np.concatenate(pts), np.concatenate(angs)


def _field_near(pos, sel, pts, width, ramp, field):
	"""Raise `field` at the texels `sel` (indices into pos) to the ramp of their distance to the nearest of `pts`: 1 within width / 2,
	0 at width / 2 + ramp."""
	from mathutils import kdtree
	if not len(pts) or not len(sel):
		return
	kd = kdtree.KDTree(len(pts))
	for i, q in enumerate(pts):
		kd.insert(Vector(q), i)
	kd.balance()
	reach = width / 2.0 + ramp
	for i in sel:
		d = kd.find(Vector(pos[i]))[2]
		if d < reach:
			field[i] = max(field[i], np.clip((reach - d) / max(ramp, 1e-6), 0.0, 1.0))


def crease_field(pos, face_deg, verts, tris, cfg, face_valley=None):
	"""The crease ink at each texel: pos (n, 3) the texels' surface points, face_deg (n,) the angle each texel's zone asks for. 1 on an
	edge, falling to 0 at `width_m` / 2 + `ramp_m`; 0 where no crease edge lies within that reach. face_valley (n,), with the config's `valley`
	({angle_deg, min_chain_m, width_m, ramp_m, spacing_m}, M6 DETAIL-2), is the angle at which each texel's zone draws the VALLEYS (concave
	edges: the quilting, a fold, a plate's foot) on their own, lower, angle and chain length; over 180 = none."""
	width, ramp = float(cfg.get("width_m", 0.006)), float(cfg.get("ramp_m", 0.003))
	field = np.zeros(len(pos))
	pts, angs = crease_edges(verts, tris, float(np.min(face_deg)), float(cfg.get("spacing_m", 0.003)), float(cfg.get("min_chain_m", 0.0)))
	for deg in np.unique(face_deg):
		if deg > 180.0:
			continue
		_field_near(pos, np.nonzero(face_deg == deg)[0], pts[angs >= deg] if len(pts) else pts, width, ramp, field)
	vc = cfg.get("valley")
	if vc and face_valley is not None and float(np.min(face_valley)) <= 180.0:
		vw, vr = float(vc.get("width_m", width)), float(vc.get("ramp_m", ramp))
		vpts, vangs = crease_edges(verts, tris, float(np.min(face_valley)), float(vc.get("spacing_m", cfg.get("spacing_m", 0.003))),
			float(vc.get("min_chain_m", cfg.get("min_chain_m", 0.0))), concave=True)
		for deg in np.unique(face_valley):
			if deg > 180.0:
				continue
			_field_near(pos, np.nonzero(face_valley == deg)[0], vpts[vangs >= deg] if len(vpts) else vpts, vw, vr, field)
	return field


def glove_lines_field(s, t, h, cfg):
	"""The ink of the glove's authored lines at points given in a hand's frame: s metres along the hand bone from the wrist toward the
	knuckles, t across the hand, h out of the back of the hand (all (n,)). `cfg`: width_m (a line's width, where the shader's cut lies),
	ramp_m (the distance over which the ink goes 0.15 to 1, about a texel), features: {"type": "ring", "s_m", "min_h_m"} (a line all
	round the glove at s_m, only where h is over min_h_m: -1 for all round, 0 for the back half) and {"type": "outline", "s_min_m",
	"s_max_m", "half_width_m", "corner_m", "min_h_m"} (the outline of a rounded rectangle in (s, t), on the back) and {"type": "segment",
	"s_min_m", "s_max_m", "t_m", "min_h_m"} (a line along the hand at t_m: a knuckle's edge). Returns 0..1 per
	point: 0.15 on a line's edge, 1 within ramp_m of its middle, 0 away from it."""
	width, ramp = float(cfg.get("width_m", 0.0035)), float(cfg.get("ramp_m", 0.0022))
	best = np.full(len(s), 1e9)
	for f in cfg.get("features", []):
		if f["type"] == "ring":
			d = np.abs(s - float(f["s_m"]))
		elif f["type"] == "outline":
			centre = 0.5 * (float(f["s_min_m"]) + float(f["s_max_m"]))
			half_s, half_t, r = 0.5 * (float(f["s_max_m"]) - float(f["s_min_m"])), float(f["half_width_m"]), float(f["corner_m"])
			qs, qt = np.abs(s - centre) - (half_s - r), np.abs(t) - (half_t - r)
			d = np.abs(np.hypot(np.maximum(qs, 0.0), np.maximum(qt, 0.0)) + np.minimum(np.maximum(qs, qt), 0.0) - r)
		elif f["type"] == "segment":
			centre, half_s = 0.5 * (float(f["s_min_m"]) + float(f["s_max_m"])), 0.5 * (float(f["s_max_m"]) - float(f["s_min_m"]))
			d = np.hypot(np.maximum(np.abs(s - centre) - half_s, 0.0), t - float(f["t_m"]))
		else:
			raise ValueError("unknown glove line feature %r" % f["type"])
		d = np.where(h >= float(f.get("min_h_m", -1.0)), d, 1e9)
		best = np.minimum(best, d)
	return np.clip(0.15 + (0.5 * width - best) / ramp, 0.0, 1.0)


def glint_field(pos, cfg):
	"""The streak gate at surface points pos (n, 3) of a Blender Z-up character facing +Y: 0..1, 0.5 on a band's edge. `cfg`:
	slant_deg (a band leans to the viewer's right going up, as concept A's streaks do), z_mid_m (the lens's mid height, where a band's
	`x_m` is read), ramp_m (the width over which the field goes 0 to 1, a few millimetres: a texel is 2.6 mm), bands [{x_m, width_m}]
	(x_m is the band's centre, in metres to the VIEWER's right of the head's middle: the viewer sees the character's +X on his left,
	so x_m is -x). A band is the points within width_m / 2 of its line (measured across the band), and the field is their union."""
	k = np.tan(np.radians(float(cfg.get("slant_deg", 0.0))))
	cos_a = float(np.cos(np.radians(float(cfg.get("slant_deg", 0.0)))))
	s = -pos[:, 0] - (pos[:, 2] - float(cfg.get("z_mid_m", 0.0))) * k  # constant along a band
	depth = np.full(len(pos), -1e9)
	for band in cfg.get("bands", []):
		depth = np.maximum(depth, (float(band["width_m"]) * 0.5 - np.abs(s - float(band["x_m"]))) * cos_a)
	return np.clip(0.5 + depth / max(float(cfg.get("ramp_m", 0.004)), 1e-6), 0.0, 1.0)


def fill_border(values, covered, px):
	"""values (h, w) holding a field on the texels `covered` marks: the field copied `px` texels outward onto texels nothing covers
	(the bilinear sample at an island's edge reads them), nearest covered texel winning. Covered texels are kept."""
	out = values.copy()
	have = covered.copy()
	for _ in range(px):
		grown = out.copy()
		taken = have.copy()
		for axis in (0, 1):
			for sign in (1, -1):
				sh_v = np.roll(out, sign, axis=axis)
				sh_h = np.roll(have, sign, axis=axis)
				new = sh_h & ~taken
				grown[new] = sh_v[new]
				taken |= new
		out, have = grown, taken
	return out


def texel_labels(colour, idx, texel, texel_face, size, sw):
	"""The palette slot of every baked texel (M6 DETAIL-2: the colour border follows the texture's texels, not the faces). colour (n, 3)
	the dense texture's sRGB at each texel (blurred a little), idx (n,) the dense face each texel was baked from, texel (n, 2) its (row, col),
	texel_face (n,) its face of the final mesh. `sw`: lab_fn (sRGB -> Lab), slots (K,), cand_lab (K, 3), dense_ok (m,) bool (the dense faces the
	texture decides: not a fixed part, not a region), ring (m, K) bool (the slots a dense face and its neighbours carry: a texel may take
	only one of those, so a stray patch the island merge removed stays removed), face_slot (the final mesh's slot per face), passes (the 3 x 3
	majority passes), fill_px. Each texel takes the Lab-nearest allowed slot of its colour; a texel the texture does not decide takes its
	face's slot. Returns ((size, size) int array: slot + 1, 0 = no code) and a report."""
	slots = np.asarray(sw["slots"], dtype=np.int64)
	cand_lab = np.asarray(sw["cand_lab"], dtype=np.float64)
	lab = sw["lab_fn"](colour)
	dist = np.linalg.norm(lab[:, None, :] - cand_lab[None, :, :], axis=2)
	dist = np.where(np.asarray(sw["ring"])[idx], dist, np.inf)
	dense_ok = np.asarray(sw["dense_ok"])[idx]
	pick = slots[np.argmin(dist, axis=1)]
	face_slot = np.asarray(sw["face_slot"], dtype=np.int64)[texel_face]
	slot = np.where(dense_ok & np.isfinite(dist.min(axis=1)), pick, face_slot)
	img = np.zeros((size, size), dtype=np.int32)
	img[texel[:, 0], texel[:, 1]] = slot + 1
	covered = np.zeros((size, size), dtype=bool)
	covered[texel[:, 0], texel[:, 1]] = True
	free = np.zeros((size, size), dtype=bool)  # the texels the texture decides: the majority filter moves only those
	free[texel[dense_ok, 0], texel[dense_ok, 1]] = True
	before = img.copy()
	codes = [int(k) + 1 for k in slots]
	for _ in range(int(sw.get("passes", 2))):
		counts = np.stack([sum(shifted((img == k).astype(np.int32), dy, dx) for dy in (-1, 0, 1) for dx in (-1, 0, 1)) for k in codes])
		total = counts.sum(axis=0)
		top = np.argmax(counts, axis=0)
		cur = np.zeros_like(img)
		for i, k in enumerate(codes):
			cur = np.where(img == k, counts[i], cur)
		best = np.take_along_axis(counts, top[None], axis=0)[0]
		move = free & covered & (best > cur) & (best * 2 > total)
		img = np.where(move, np.asarray(codes)[top], img)
	img = fill_border(img, covered, int(sw.get("fill_px", 3)))
	face_img = np.zeros((size, size), dtype=np.int32)
	face_img[texel[:, 0], texel[:, 1]] = face_slot + 1
	report = {"texels": int(len(texel)), "texture_decided": int(dense_ok.sum()),
		"differ_from_face_share": round(float((img[texel[:, 0], texel[:, 1]] != face_img[texel[:, 0], texel[:, 1]]).mean()), 5),
		"majority_moved": int(((img != before) & covered).sum()),
		"share": {str(int(k)): round(float((img[covered] == k + 1).mean()), 5) for k in slots}}
	return img, report


def bake(me, layer_name, image, dense_bvh, dense_verts, dense_tris, dense_uv, cfg, out_png, source_png=None, face_gain=None,
		face_low=None, face_high=None, face_zone=None, zone_names=(), glint=None, face_glint=None, glove=None, hand_frames=None, face_slot=None, face_crease=None, face_valley=None, swatch=None):
	"""Bake the mask of `me` (UV layer `layer_name`) from `image` (the dense mesh's texture) into out_png. dense_verts
	(n, 3), dense_tris (m, 3) vertex indices, dense_uv (m, 3, 2) per-corner UVs; face_gain (one float per face of `me`, 1 = full ink, 0 = none: the lens
	takes none) is optional. face_low / face_high (one float per face) override the smoothstep that turns the raw top-hat into ink
	(`ink_low`, `ink_high` of the config by default): the face's skin takes a higher pair so the texture's speckle drops out and
	the mouth and the nose line stay (config `zones`, built by blender_palette). face_zone (an int per face, 0 = none, k = zone_names[k-1])
	only labels the report's percentiles of the raw top-hat per zone, the numbers the pairs are calibrated on. glint (the config's `glint`
	dict) and face_glint (one bool per face of `me`: the lens's) write the glint gate into G, see the module doc. glove (the config's
	`glove_lines`), hand_frames ({side: {sign, head, a, b, c}} in the mesh's frame) and face_slot (the palette slot per face) add the glove's
	authored lines into R. face_crease (one angle per face of `me`, only with the config's `crease`) is each face's crease threshold in degrees,
	face_valley (with the crease's `valley`) the angle at which its zone draws valleys. swatch (M6 DETAIL-2; the config's `texel_swatch` and the
	keys texel_labels() reads) writes each texel's palette slot + 1 into B, so the shader takes a texel's colour from the texture's border, not
	from the face's.
	Returns a report dict."""
	size = int(cfg.get("size", 1024))
	w, h = image.size
	pix = np.empty(w * h * 4, dtype=np.float32)
	image.pixels.foreach_get(pix)
	pix = pix.reshape(h, w, 4)[:, :, :3]
	ink = ink_raw(pix, int(cfg.get("radius_px", 5)))
	if swatch:
		sigma = float(cfg.get("texel_swatch", {}).get("blur_px", 1.0))
		colour_img = np.stack([blur(pix[:, :, c].astype(np.float32), sigma) if sigma > 0.0 else pix[:, :, c] for c in range(3)], axis=-1)
	del pix
	# no ink within edge_margin_px of an island's border: a seam of the generated texture is not a line of the character
	margin = int(cfg.get("edge_margin_px", 6))
	if margin > 0:
		ink *= erode(coverage(dense_uv, w, h), margin)
	low_default, high_default = float(cfg.get("ink_low", 0.04)), float(cfg.get("ink_high", 0.12))
	if source_png:
		_write_gray(shape(ink, low_default, high_default), source_png, "detail_source")
	texel, pos, texel_face = rasterize(me, layer_name, size)
	idx = np.empty(len(pos), dtype=np.int64)
	loc = np.empty((len(pos), 3))
	for i in range(len(pos)):
		hit = dense_bvh.find_nearest(Vector(pos[i]))
		loc[i] = hit[0]
		idx[i] = hit[2]
	a, b, c = dense_verts[dense_tris[idx, 0]], dense_verts[dense_tris[idx, 1]], dense_verts[dense_tris[idx, 2]]
	v0, v1, vp = b - a, c - a, loc - a
	d00, d01, d11 = (v0 * v0).sum(1), (v0 * v1).sum(1), (v1 * v1).sum(1)
	d20, d21 = (vp * v0).sum(1), (vp * v1).sum(1)
	den = np.maximum(d00 * d11 - d01 * d01, 1e-18)
	l1 = (d11 * d20 - d01 * d21) / den
	l2 = (d00 * d21 - d01 * d20) / den
	l0 = 1.0 - l1 - l2
	uvs = dense_uv[idx]
	uv = uvs[:, 0] * l0[:, None] + uvs[:, 1] * l1[:, None] + uvs[:, 2] * l2[:, None]
	raw = bilinear(ink, uv)
	# the smoothstep is applied in TEXTURE space, before the sample (a thin line keeps its strength through the bilinear sample): once
	# per distinct (low, high) pair of the faces, each texel taking its face's pair
	if face_low is None:
		value = bilinear(shape(ink, low_default, high_default), uv)
	else:
		lo_f = np.asarray(face_low, dtype=np.float64)
		hi_f = np.asarray(face_high, dtype=np.float64) if face_high is not None else np.full(len(lo_f), high_default)
		pairs = np.unique(np.stack([lo_f, hi_f], axis=1), axis=0)
		value = np.zeros(len(raw))
		face_pair = np.asarray(texel_face)
		for lo, hi in pairs:
			sel = (lo_f[face_pair] == lo) & (hi_f[face_pair] == hi)
			if sel.any():
				value[sel] = bilinear(shape(ink, lo, hi), uv[sel])
	crease_report = None
	if cfg.get("crease") and face_crease is not None:
		field = crease_field(pos, np.asarray(face_crease, dtype=np.float64)[texel_face], dense_verts, dense_tris, cfg["crease"],
			None if face_valley is None else np.asarray(face_valley, dtype=np.float64)[texel_face])
		before = float((value > 0.5).mean())
		value = np.maximum(value, field)
		crease_report = {"texels_on_a_crease": int((field > 0.5).sum()), "ink_share_before": round(before, 5), "ink_share_after": round(float((value > 0.5).mean()), 5)}
	if face_gain is not None:
		value = value * np.asarray(face_gain)[texel_face]
	zone_report = {}
	if face_zone is not None:
		zt = np.asarray(face_zone)[texel_face]
		for k, name in enumerate(zone_names, start=1):
			m = zt == k
			if m.any():
				zone_report[name] = {"texels": int(m.sum()), "raw_percentiles": {str(q): round(float(np.percentile(raw[m], q)), 4) for q in (50, 80, 90, 95, 97, 98, 99, 99.5)},
					"ink_texels_share": float((value[m] > 0.5).mean())}
	mask = np.zeros((size, size), dtype=np.float32)
	mask[texel[:, 0], texel[:, 1]] = value
	clean_report = None
	if cfg.get("clean"):
		on_surface = np.zeros((size, size), dtype=bool)
		on_surface[texel[:, 0], texel[:, 1]] = True
		mask, clean_report = clean_strokes(mask, on_surface, cfg["clean"])
	glove_report = None
	if glove and hand_frames and face_slot is not None:
		on_glove = np.isin(np.asarray(face_slot)[texel_face], glove.get("slots", []))
		field = np.zeros(len(pos))
		for side, fr in hand_frames.items():
			sel = on_glove & (np.sign(pos[:, 0]) == fr["sign"]) & (np.abs(pos[:, 0]) >= float(glove.get("min_abs_x_m", 0.4)))
			rel = pos[sel] - np.asarray(fr["head"])
			field[sel] = glove_lines_field(rel @ np.asarray(fr["a"]), rel @ np.asarray(fr["c"]), rel @ np.asarray(fr["b"]), glove)
		lines = np.zeros((size, size), dtype=np.float32)
		lines[texel[:, 0], texel[:, 1]] = field
		covered = np.zeros((size, size), dtype=bool)
		covered[texel[on_glove, 0], texel[on_glove, 1]] = True
		mask = np.maximum(mask, fill_border(lines, covered, int(glove.get("fill_px", 2))))
		glove_report = {"texels": int(on_glove.sum()), "line_texels_over_cut": int((field > float(cfg.get("clean", {}).get("cut", 0.15))).sum())}
	grow = int(cfg.get("grow_px", 0))
	if grow > 0:
		mask = dilate(mask, grow)
	gate = None
	glint_report = None
	if glint and face_glint is not None:
		lens = np.asarray(face_glint)[texel_face]
		field = np.zeros(len(pos))
		field[lens] = glint_field(pos[lens], glint)
		gate = np.zeros((size, size), dtype=np.float32)
		gate[texel[:, 0], texel[:, 1]] = field
		covered = np.zeros((size, size), dtype=bool)
		covered[texel[lens, 0], texel[lens, 1]] = True
		gate = fill_border(gate, covered, int(glint.get("fill_px", 2)))
		glint_report = {"texels": int(lens.sum()), "gate_share": round(float((field[lens] > 0.5).mean()), 4) if lens.any() else 0.0}
	code = None
	swatch_report = None
	if swatch:
		code, swatch_report = texel_labels(np.stack([bilinear(colour_img[:, :, c], uv) for c in range(3)], axis=1), idx, texel, texel_face, size,
			{**swatch, **{k: v for k, v in cfg.get("texel_swatch", {}).items() if k in ("passes", "fill_px")}})
	_write_gray(mask, out_png, "punk_detail", gate, code)
	return {"size": size, "texels": int(len(pos)), "ink_texels_share": float((value > 0.5).mean()), "mean_ink": float(value.mean()),
		"png": out_png, "zones": zone_report, "glint": glint_report, "clean": clean_report, "glove_lines": glove_report,
		**({"crease": crease_report} if crease_report is not None else {}), **({"texel_swatch": swatch_report} if swatch_report is not None else {})}


def _write_gray(a, path, name, g=None, code=None):
	"""a (h, w) 0..1 (row 0 the bottom) -> an 8-bit PNG with R = a, G = g (the glint gate; 0 when there is none), B = code / 255 (the palette
	slot + 1 of each texel, M6 DETAIL-2; 0 = no code, the face's swatch) or all three = a for a source picture."""
	h, w = a.shape
	rgba = np.ones((h, w, 4), dtype=np.float32)
	rgba[:, :, 0] = a
	rgba[:, :, 1] = a if name == "detail_source" else (0.0 if g is None else g)
	rgba[:, :, 2] = a if name == "detail_source" else (0.0 if code is None else code.astype(np.float32) / 255.0)
	if name == "detail_source" and max(h, w) > 2048:
		pass
	img = bpy.data.images.new(name, w, h, alpha=False)
	img.colorspace_settings.name = "Non-Color"
	img.pixels.foreach_set(rgba.ravel())
	img.filepath_raw = path
	img.file_format = "PNG"
	os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
	img.save()
	bpy.data.images.remove(img)
