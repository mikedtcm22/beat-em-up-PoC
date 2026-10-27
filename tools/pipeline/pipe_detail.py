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
The glint gate (rescore-rs-01, config `detail_bake.glint`): the shades' lens is the one glossy swatch, and its glint is a cap on an angle,
which whites the whole lens out when the head tips back. G holds the AUTHORED streaks of concept A, two diagonal bands per eye, as a
signed-distance ramp (0.5 on a band's edge, so the shader's cut at 0.5 draws the edge sharp from a 1k texel) on the lens's texels only;
the shader multiplies the glint by it, so the glint can only ever light a streak. Every other texel's G is 0.
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


def bake(me, layer_name, image, dense_bvh, dense_verts, dense_tris, dense_uv, cfg, out_png, source_png=None, face_gain=None,
		face_low=None, face_high=None, face_zone=None, zone_names=(), glint=None, face_glint=None):
	"""Bake the mask of `me` (UV layer `layer_name`) from `image` (the dense mesh's texture) into out_png. dense_verts
	(n, 3), dense_tris (m, 3) vertex indices, dense_uv (m, 3, 2) per-corner UVs; face_gain (one float per face of `me`, 1 = full ink, 0 = none: the lens
	takes none) is optional. face_low / face_high (one float per face) override the smoothstep that turns the raw top-hat into ink
	(`ink_low`, `ink_high` of the config by default): the face's skin takes a higher pair so the texture's speckle drops out and
	the mouth and the nose line stay (config `zones`, built by blender_palette). face_zone (an int per face, 0 = none, k = zone_names[k-1])
	only labels the report's percentiles of the raw top-hat per zone, the numbers the pairs are calibrated on. glint (the config's `glint`
	dict) and face_glint (one bool per face of `me`: the lens's) write the glint gate into G, see the module doc. Returns a report dict."""
	size = int(cfg.get("size", 1024))
	w, h = image.size
	pix = np.empty(w * h * 4, dtype=np.float32)
	image.pixels.foreach_get(pix)
	pix = pix.reshape(h, w, 4)[:, :, :3]
	ink = ink_raw(pix, int(cfg.get("radius_px", 5)))
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
	_write_gray(mask, out_png, "punk_detail", gate)
	return {"size": size, "texels": int(len(pos)), "ink_texels_share": float((value > 0.5).mean()), "mean_ink": float(value.mean()),
		"png": out_png, "zones": zone_report, "glint": glint_report}


def _write_gray(a, path, name, g=None):
	"""a (h, w) 0..1 (row 0 the bottom) -> an 8-bit PNG with R = a, G = g (the glint gate; 0 when there is none), B = 0 (the mask), or
	all three = a for a source picture."""
	h, w = a.shape
	rgba = np.ones((h, w, 4), dtype=np.float32)
	rgba[:, :, 0] = a
	rgba[:, :, 1] = a if name == "detail_source" else (0.0 if g is None else g)
	rgba[:, :, 2] = a if name == "detail_source" else 0.0
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
