"""M7 T12's paint step (the video session's tools/video/art_paint.py, rewritten to the painted material's contract): paint.png and ink.png of one character.

	~/.venvs/beat-em-up-video/bin/python -I tools/pipeline/trailer_paint.py bake  <name> <workdir> <outdir> [variant]
	~/.venvs/beat-em-up-video/bin/python -I tools/pipeline/trailer_paint.py sheet <name> <workdir> <png> <view> <origin_r_m> <origin_u_m> <half_w_mm> <half_h_mm> <px_per_mm>
	~/.venvs/beat-em-up-video/bin/python -I tools/pipeline/trailer_paint.py regions <name> <workdir> <png> <view> [x0 x1 z0 z1]

`workdir` is what tools/pipeline/trailer_asset.py wrote (maps.npz, meta.json). `bake` writes <name>_paint.png and <name>_ink.png into `outdir`,
2048 px on UV2, to the channel contract of docs/ARCHITECTURE.md "The painted material (M7)":
	paint  RGB   flat local colour per region (assets/source/trailer_art/<name>/paint.json "regions") with the designed shadow shapes drawn in
	ink    R     the line: seams on the borders of regions, fold lines on the cloth, the drawn face (features.svg)
	       G     damage class bytes (clothes 255, skin 204, none 128)
	       B     gloss (255 on glossy regions, none for the Punk)
	       A     hull weight hint, a smooth function of the rest-pose 3D position (so it is equal on both sides of a UV seam)
Pure numpy / scipy / opencv / pillow (the venv); Blender is not needed here.
"""
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
ATLAS = os.path.join(ROOT, "assets", "export", "palette", "palette_atlas.png")
CONFIG_DIR = os.path.join(ROOT, "assets", "source", "trailer_art")
GRID = (32, 2)
CELL_PX = 8
PAD_TEXELS = 16
## The line and noise sizes are in texels of a 2048 map; multiplied by size / 2048 for the map being baked.
PXS = 1.0


def load_config(name):
	with open(os.path.join(CONFIG_DIR, name, "paint.json")) as f:
		return json.load(f)


def srgb_to_lin(c):
	c = np.asarray(c, np.float32)
	return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_to_srgb(c):
	c = np.clip(np.asarray(c, np.float32), 0.0, 1.0)
	return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def load_maps(workdir):
	m = np.load(os.path.join(workdir, "maps.npz"))
	meta = json.load(open(os.path.join(workdir, "meta.json")))
	return {k: m[k] for k in m.files}, meta


def cell_ids(maps):
	"""The palette cell (0..63) of every texel, -1 where nothing is mapped."""
	uv = maps["uv1"].astype(np.float32)
	cx = np.clip(np.floor(uv[..., 0] * GRID[0]).astype(int), 0, GRID[0] - 1)
	cy = np.clip(np.floor((1.0 - uv[..., 1]) * GRID[1]).astype(int), 0, GRID[1] - 1)
	ids = cy * GRID[0] + cx
	return np.where(maps["cover"], ids, -1)


def atlas_colours():
	"""(64, 4) the swatch colours (sRGB 0..1) and gloss alpha of the game's palette atlas."""
	atlas = np.asarray(Image.open(ATLAS).convert("RGBA"), np.float32) / 255.0
	out = np.zeros((GRID[0] * GRID[1], 4), np.float32)
	for cy in range(GRID[1]):
		for cx in range(GRID[0]):
			out[cy * GRID[0] + cx] = atlas[cy * CELL_PX + CELL_PX // 2, cx * CELL_PX + CELL_PX // 2]
	return out


def smooth_noise(shape, scale_px, seed, octaves=2):
	"""Low-frequency value noise in 0..1 (gaussian-filtered white noise, normalised), `scale_px` the feature size."""
	rng = np.random.default_rng(seed)
	out = np.zeros(shape, np.float32)
	amp, total = 1.0, 0.0
	for o in range(octaves):
		n = rng.standard_normal(shape).astype(np.float32)
		n = ndimage.gaussian_filter(n, max(scale_px / (2 ** o), 0.6) / 2.0, mode="wrap")
		n /= max(float(n.std()), 1e-6)
		out += n * amp
		total += amp
		amp *= 0.5
	out /= total
	return np.clip(out * 0.25 + 0.5, 0.0, 1.0)


def strokes_noise(shape, length_px, width_px, angle_deg, seed):
	"""Brush-stroke grain: white noise smeared along one direction, normalised to roughly 0..1 around 0.5."""
	rng = np.random.default_rng(seed)
	n = rng.standard_normal(shape).astype(np.float32)
	k = int(length_px * 2) | 1
	kernel = np.zeros((k, k), np.float32)
	cv2.line(kernel, (0, k // 2), (k - 1, k // 2), 1.0, max(int(width_px), 1))
	rot = cv2.getRotationMatrix2D((k / 2, k / 2), angle_deg, 1.0)
	kernel = cv2.warpAffine(kernel, rot, (k, k))
	kernel /= max(float(kernel.sum()), 1e-6)
	n = cv2.filter2D(n, -1, kernel, borderType=cv2.BORDER_WRAP)
	n /= max(float(n.std()), 1e-6)
	return np.clip(n * 0.25 + 0.5, 0.0, 1.0)


def warp(img, amp_px, scale_px, seed):
	"""Displace `img` by a smooth noise field (the hand-wobble that keeps an edge from being ruler-clean)."""
	h, w = img.shape[:2]
	dx = (smooth_noise((h, w), scale_px, seed) - 0.5) * 2.0 * amp_px * 2.0
	dy = (smooth_noise((h, w), scale_px, seed + 1) - 0.5) * 2.0 * amp_px * 2.0
	gx, gy = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
	return cv2.remap(img, gx + dx, gy + dy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)


def luminance(rgb_lin):
	return rgb_lin @ np.array([0.2126, 0.7152, 0.0722], np.float32)


def form_curvature(maps, sigma):
	"""A smooth signed curvature (convex positive) from the baked shading normals: along each texel axis the normal's change over the
	position's change (the divergence of the normal), averaged over both axes, then blurred. The mesh's own dihedral curvature
	(maps["curv"]) is constant over a triangle and straight at its edges, and a threshold of it draws ruler-straight shapes; the
	normals are smooth across the triangles, so this one thresholds to rounded, wandering shapes. Done in bands of rows (a 4096
	map's float32 position and normal arrays are 200 MB each)."""
	pos = maps["pos"]
	nrm = maps["nrm"]
	cover = maps["cover"]
	size = cover.shape[0]
	out = np.zeros(cover.shape, np.float32)
	valid = np.zeros(cover.shape, np.float32)
	band = 256
	for r0 in range(0, size, band):
		r1 = min(r0 + band, size)
		a0, a1 = max(r0 - 2, 0), min(r1 + 2, size)
		bp = pos[a0:a1].astype(np.float32)
		bn = nrm[a0:a1].astype(np.float32)
		bc = cover[a0:a1]
		bo = np.zeros(bc.shape, np.float32)
		bv = np.zeros(bc.shape, np.float32)
		for axis in (0, 1):
			dp = np.roll(bp, -1, axis) - np.roll(bp, 1, axis)
			dn = np.roll(bn, -1, axis) - np.roll(bn, 1, axis)
			ok = bc & np.roll(bc, -1, axis) & np.roll(bc, 1, axis)
			length = np.linalg.norm(dp, axis=2)
			ok &= (length < 0.012) & (length > 1e-6)
			k = (dn * dp).sum(axis=2) / np.maximum((dp * dp).sum(axis=2), 1e-12)
			bo += np.where(ok, k, 0.0)
			bv += ok
		out[r0:r1] = bo[r0 - a0:r1 - a0]
		valid[r0:r1] = bv[r0 - a0:r1 - a0]
	out = out / np.maximum(valid, 1.0)
	weight = cv2.GaussianBlur((valid > 0).astype(np.float32), (0, 0), sigma)
	blur = cv2.GaussianBlur(out * (valid > 0), (0, 0), sigma)
	return np.where(weight > 1e-3, blur / np.maximum(weight, 1e-3), 0.0).astype(np.float32)


def line_from_valleys(curv, cover, cfg, seed):
	"""A thin line along the valleys of the curvature: the valley score, kept only near its local maximum, then softened."""
	size = curv.shape[0]
	score = np.clip(-cv2.GaussianBlur(curv, (0, 0), cfg.get("crease_blur", 1.0) * PXS), 0.0, None)
	local = ndimage.maximum_filter(score, size=max(int(round(cfg.get("crease_nms", 5) * PXS)) | 1, 3))
	keep = (score >= local * cfg.get("crease_keep", 0.78)) & (score > cfg.get("crease_min", 7.0))
	line = keep.astype(np.float32) * np.clip((score - cfg.get("crease_min", 7.0)) / cfg.get("crease_full", 10.0), 0.15, 1.0)
	line = cv2.dilate(line, np.ones((max(int(round(2 * PXS)), 2),) * 2, np.uint8))
	line = cv2.GaussianBlur(line, (0, 0), 0.7 * PXS)
	# Hand-drawn: the weight comes and goes along the line, and short bits are lost.
	fade = smooth_noise((size, size), cfg.get("fade_px", 40) * PXS, seed + 21)
	line *= np.clip((fade - cfg.get("fade_cut", 0.38)) * 5.0, 0.0, 1.0)
	return line * cover


def line_from_borders(ids, cfg, seed):
	"""Ink on the border between two materials (the shape of a glove, a mask, a cap), a line of about `border_px` texels."""
	size = ids.shape[0]
	a = ids.astype(np.int32)
	edge = np.zeros(a.shape, bool)
	edge[:, :-1] |= (a[:, :-1] != a[:, 1:]) & (a[:, :-1] >= 0) & (a[:, 1:] >= 0)
	edge[:-1, :] |= (a[:-1, :] != a[1:, :]) & (a[:-1, :] >= 0) & (a[1:, :] >= 0)
	edge = edge.astype(np.float32)
	width = max(int(round(cfg.get("border_px", 2) * PXS)), 1)
	edge = cv2.dilate(edge, np.ones((width, width), np.uint8))
	edge = cv2.GaussianBlur(edge, (0, 0), 0.7 * PXS)
	fade = smooth_noise((size, size), cfg.get("fade_px", 40) * PXS, seed + 31)
	edge *= np.clip((fade - cfg.get("border_fade_cut", 0.3)) * 4.0, 0.0, 1.0)
	return edge * cfg.get("border_strength", 0.8)


def pad_and_fill(img, cover, texels, info=None):
	"""Pad every island by `texels` from its nearest covered texel, fill the rest with the mean colour of the covered texels, and
	return (image, alpha) with alpha 1 on the islands and their padding and 0 elsewhere. `info` is ndimage's (distance, indices)."""
	if info is None:
		info = ndimage.distance_transform_edt(~cover, return_indices=True)
	dist, idx = info
	grow = (~cover) & (dist <= texels)
	padded_img = img.copy()
	padded_img[grow] = img[idx[0], idx[1]][grow]
	padded = cover | grow
	mean = padded_img[cover].mean(axis=0)
	out = np.where(padded[..., None], padded_img, mean[None, None, :]).astype(np.float32)
	return out, padded


def fold_lines(pos, bone, idx, ids, spec, axis, head, e1, e2, seed, cover):
	"""A cloth's fold lines on the texels of a material around a limb: `count` strokes, each a short curve in the limb's (along, around) plane,
	slanted by `angle_deg` (+- a spread) and `length_mm` long, heavy at its start and tapering to a point, placed at random (seeded)
	so no two are alike and none are evenly spaced; not stripes round the limb, but the few creases where the cloth turns."""
	size = ids.shape[0]
	mask = np.isin(bone, idx) & (ids == spec["cell"])
	ys, xs = np.nonzero(mask)
	out = np.zeros((size, size), np.float32)
	if len(ys) < 50:
		return out
	v = pos[ys, xs] - head
	t = v @ axis
	radial = v - t[:, None] * axis
	r_ref = float(np.median(np.linalg.norm(radial, axis=1)))
	phi = np.arctan2(radial @ e2, radial @ e1)
	circ = 2.0 * np.pi * r_ref
	s_coord = phi * r_ref
	t_lo, t_hi = np.percentile(t, [3, 97])
	mm_per_texel = 1000.0 * float(np.median(np.linalg.norm(np.roll(pos, -1, 1) - pos, axis=2)[cover]))
	rng = np.random.default_rng(seed)
	acc = np.zeros(len(ys), np.float32)
	l0, l1 = spec.get("length_mm", [30.0, 70.0])
	w0 = spec.get("width_mm", 2.6) / 1000.0
	for k in range(int(spec.get("count", 8))):
		tc = rng.uniform(t_lo, t_hi)
		sc = rng.uniform(-circ / 2, circ / 2)
		length = rng.uniform(l0, l1) / 1000.0
		th = np.radians(spec.get("angle_deg", 28.0) + rng.normal(0.0, spec.get("angle_spread_deg", 16.0))) * rng.choice([-1.0, 1.0])
		bend = rng.normal(0.0, 0.18) * length
		u = np.linspace(0.0, 1.0, 9)
		pa = np.stack([tc + np.cos(th) * length * (u - 0.5) - np.sin(th) * bend * np.sin(np.pi * u),
			np.sin(th) * length * (u - 0.5) + np.cos(th) * bend * np.sin(np.pi * u)], axis=1)
		ds = (s_coord - sc + circ / 2) % circ - circ / 2
		near = (np.abs(t - tc) < length + 0.02) & (np.abs(ds) < length + 0.02)
		if not near.any():
			continue
		q = np.stack([t[near], ds[near]], axis=1)
		best = np.full(len(q), 9.0)
		best_u = np.zeros(len(q))
		for a, b, ua, ub in zip(pa[:-1], pa[1:], u[:-1], u[1:]):
			ab = b - a
			h = np.clip(((q - a) @ ab) / max(float(ab @ ab), 1e-12), 0.0, 1.0)
			d = np.linalg.norm(q - (a + h[:, None] * ab), axis=1)
			better = d < best
			best = np.where(better, d, best)
			best_u = np.where(better, ua + h * (ub - ua), best_u)
		width = w0 * (1.0 - best_u) ** 0.9 * np.clip(best_u / 0.1 + 0.25, 0.25, 1.0)
		line = np.clip((width / 2.0 - best) * 1000.0 / max(mm_per_texel, 0.05) + 0.5, 0.0, 1.0)
		acc[near] = np.maximum(acc[near], line * rng.uniform(0.65, 1.0))
	out[ys, xs] = acc * spec.get("strength", 0.8)
	return out


def splat_view(maps, rgb, view, window, px_per_mm):
	"""Orthographic splat of the texels: returns (image, index) where index[y, x] is the flat texel index (or -1) of the
	nearest texel to the viewer at that pixel. `window` is (x0, x1, z0, z1) in metres of the view's right and up axes."""
	right, up, toward = VIEWS[view]
	pos = maps["pos"].reshape(-1, 3)
	nrm = maps["nrm"].reshape(-1, 3).astype(np.float32)
	cov = maps["cover"].reshape(-1)
	facing = (nrm @ toward) > -0.05
	sel = np.nonzero(cov & facing)[0]
	p = pos[sel]
	x = p @ right
	z = p @ up
	d = p @ toward
	w = int(round((window[1] - window[0]) * 1000 * px_per_mm))
	h = int(round((window[3] - window[2]) * 1000 * px_per_mm))
	px = ((x - window[0]) * 1000 * px_per_mm).astype(int)
	py = ((window[3] - z) * 1000 * px_per_mm).astype(int)
	ok = (px >= 0) & (px < w) & (py >= 0) & (py < h)
	sel, px, py, d = sel[ok], px[ok], py[ok], d[ok]
	order = np.argsort(d)  # far first, so near texels land last
	flat = py[order] * w + px[order]
	index = np.full(w * h, -1, np.int64)
	index[flat] = sel[order]
	index = index.reshape(h, w)
	# fill the splat's holes (a texel is smaller than a pixel here, but never exactly): nearest filled neighbour within 2 px
	empty = index < 0
	if empty.any():
		dist, idx = ndimage.distance_transform_edt(empty, return_indices=True)
		near = index[idx[0], idx[1]]
		index = np.where(empty & (dist <= max(2.0, px_per_mm * 1.7)) & (near >= 0), near, index)
	img = np.zeros((h, w, 3), np.float32)
	have = index >= 0
	img[have] = rgb.reshape(-1, 3)[index[have]]
	return img, index




# A view is (screen right, screen up, toward the viewer) in the character's space (+Y is its front, +Z up). "front" is what a
# viewer in front of the character sees: his left hand on the viewer's right, so the viewer's right is -X.
VIEWS = {
	"front": (np.array([-1.0, 0.0, 0.0]), np.array([0.0, 0.0, 1.0]), np.array([0.0, 1.0, 0.0])),
	"back": (np.array([1.0, 0.0, 0.0]), np.array([0.0, 0.0, 1.0]), np.array([0.0, -1.0, 0.0])),
	"left": (np.array([0.0, -1.0, 0.0]), np.array([0.0, 0.0, 1.0]), np.array([1.0, 0.0, 0.0])),
	"right": (np.array([0.0, 1.0, 0.0]), np.array([0.0, 0.0, 1.0]), np.array([-1.0, 0.0, 0.0])),
	"top": (np.array([-1.0, 0.0, 0.0]), np.array([0.0, 1.0, 0.0]), np.array([0.0, 0.0, 1.0])),
	# the forearm's outer face (the A-pose arm slants 45 degrees down and out): looking along its normal from above and outside
	"arm_r": (np.array([0.0, 1.0, 0.0]), np.array([-0.70710678, 0.0, 0.70710678]), np.array([0.70710678, 0.0, 0.70710678])),
	"arm_l": (np.array([0.0, -1.0, 0.0]), np.array([0.70710678, 0.0, 0.70710678]), np.array([-0.70710678, 0.0, 0.70710678])),
}




def lit(maps, rgb):
	"""The colours lit by a fixed soft light from the upper left front, so a preview shows the form."""
	n = maps["nrm"].astype(np.float32)
	light = np.array([-0.4, 0.55, 0.7], np.float32)
	light /= np.linalg.norm(light)
	lam = np.clip(n @ light, 0.0, 1.0)
	return rgb * (0.45 + 0.65 * lam[..., None])


def save_view(maps, rgb, png, view, window, px_per_mm, grid=None):
	"""Orthographic splat of `rgb` (size x size x 3, 0..1) in `view`, saved as a png; `grid` = (origin_r, origin_u, half_w_mm, half_h_mm)
	draws the millimetre grid the features.svg groups use (x right, y DOWN, 0 at the origin, a line every 10 mm)."""
	img, _ = splat_view(maps, lit(maps, rgb), view, window, px_per_mm)
	img = np.ascontiguousarray((np.clip(img, 0, 1) * 255.0 + 0.5).astype(np.uint8))
	if grid is not None:
		half_w, half_h = grid[2], grid[3]
		h, w = img.shape[:2]
		for gx in range(-int(half_w) // 10 * 10, int(half_w) + 1, 10):
			x = int((gx + half_w) * px_per_mm)
			major = gx % 50 == 0
			cv2.line(img, (x, 0), (x, h), (255, 255, 255) if major else (110, 110, 110), 1)
			if major:
				cv2.putText(img, str(gx), (x + 2, 12), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (255, 255, 0), 1, cv2.LINE_AA)
		for gy in range(-int(half_h) // 10 * 10, int(half_h) + 1, 10):
			y = int((gy + half_h) * px_per_mm)
			major = gy % 50 == 0
			cv2.line(img, (0, y), (w, y), (255, 255, 255) if major else (110, 110, 110), 1)
			if major:
				cv2.putText(img, str(gy), (2, y - 2), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (255, 255, 0), 1, cv2.LINE_AA)
	Image.fromarray(img).save(png)


def cell_colours(maps):
	"""The game's palette swatch colours per texel (the placeholder look, for a preview of what the mesh's materials are)."""
	ids = cell_ids(maps)
	return np.where((ids >= 0)[..., None], atlas_colours()[np.maximum(ids, 0)][..., :3], 0.0).astype(np.float32)


def region_map(maps, meta, cfg):
	"""(region index per texel, -1 where nothing is mapped; the region names). paint.json "regions" names them with their colours and "rules" assigns
	them: the rules run in order, each sets the region of the texels that match ALL of its keys, so a later rule overrides an earlier one:
	  "cells": palette cells of the game's atlas (the mesh's own material labels), "bones": dominant bone names, "box": [[x0, x1], [y0, y1], [z0, z1]]
	  (metres, rest pose, any axis may be null), "region": the name it sets."""
	ids = cell_ids(maps)
	names = list(cfg["regions"].keys())
	out = np.full(ids.shape, -1, np.int32)
	cover = maps["cover"]
	pos = maps["pos"]
	for rule in cfg["rules"]:
		m = cover.copy()
		if "cells" in rule:
			m &= np.isin(ids, rule["cells"])
		if "bones" in rule:
			m &= np.isin(maps["bone"], [meta["bones"].index(b) for b in rule["bones"]])
		for axis, span in enumerate(rule.get("box", [])):
			if span is None:
				continue
			m &= (pos[..., axis] >= span[0]) & (pos[..., axis] <= span[1])
		out[m] = names.index(rule["region"])
	return out, names


def value_noise3(p, scale, seed):
	"""Smooth 3D value noise of positions p (..., 3), 0..1, lattice `scale` metres: a smooth function of the position alone."""
	q = p.astype(np.float64) / scale
	i = np.floor(q)
	f = q - i
	f = f * f * (3.0 - 2.0 * f)
	acc = np.zeros(p.shape[:-1])
	for dx in (0, 1):
		for dy in (0, 1):
			for dz in (0, 1):
				c = i + np.array([dx, dy, dz])
				h = np.sin(c[..., 0] * 127.1 + c[..., 1] * 311.7 + c[..., 2] * 74.7 + seed * 19.19) * 43758.5453
				h = h - np.floor(h)
				w = (f[..., 0] if dx else 1 - f[..., 0]) * (f[..., 1] if dy else 1 - f[..., 1]) * (f[..., 2] if dz else 1 - f[..., 2])
				acc += h * w
	return acc.astype(np.float32)


def hull_weight(maps, meta, cfg, seed):
	"""The ink map's A: the hull's line weight hint, a smooth function of the rest-pose position alone (a seam's two sides are one point, so they
	read the same value, which the hull needs). A base with a slow 3D noise (the line changes weight along a form), the extremities
	(`taper_ends`: the hands' and feet's bone tails) thinned so the line tapers toward them."""
	spec = cfg.get("hull", {})
	pos = maps["pos"]
	base = float(spec.get("base", 0.62))
	var = float(spec.get("variation", 0.32))
	n = value_noise3(pos, float(spec.get("noise_m", 0.18)), seed + 5)
	w = base + var * (n * 2.0 - 1.0)
	for name in spec.get("taper_ends", []):
		tail = np.array(meta["bone_tails"][name], np.float64)
		d = np.linalg.norm(pos.astype(np.float64) - tail, axis=-1)
		w = w * (1.0 - float(spec.get("taper", 0.55)) * np.exp(-((d / float(spec.get("taper_m", 0.07))) ** 2)))
	return np.clip(w, 0.0, 1.0).astype(np.float32)


def shadow_shapes(maps, meta, cfg, ids, seed, size):
	"""The designed shadow shapes (0/1 with a soft one-texel edge): the hint map (trailer_shade.hint_map: the surfaces that turn from a designed
	light per form, and the concave forms) thresholded hard, its edge wandering by noise, plus the curvature's deepest valleys (a fold's shadow)."""
	import trailer_shade as ts
	curv_s = form_curvature(maps, cfg.get("form_sigma", 3.0) * size / 2048.0)
	cover = maps["cover"]
	hint = ts.hint_map(maps, meta, cfg, curv_s, PXS)
	wob = smooth_noise((size, size), cfg.get("wobble_px", 26) * PXS, seed + 3) - 0.5
	h = hint + wob * cfg.get("wobble_gain", 0.5)
	cut = cfg.get("shadow_cut", 0.5)
	shape = np.clip((h - cut) / max(cfg.get("edge", 0.05), 1e-3) + 0.5, 0.0, 1.0)
	lo = np.percentile(curv_s[cover], cfg.get("fold_pct", 6.0))
	spread = max(float(np.percentile(curv_s[cover], 75) - np.percentile(curv_s[cover], 25)) / 1.35, 1e-3)
	fold = np.clip((lo - (curv_s + wob * spread * 0.6)) / spread * 4.0 + 0.5, 0.0, 1.0) * cfg.get("fold_amount", 0.8)
	return np.maximum(shape, fold) * cover, hint


def fold_set(maps, meta, cfg, ids, names, seed):
	"""paint.json "folds": [{"bones": [...], "region": name, "count": n, ...}]: trailer_paint.fold_lines on each (cloth creases, tapering strokes)."""
	size = ids.shape[0]
	out = np.zeros((size, size), np.float32)
	pos = maps["pos"].astype(np.float64)
	for k, spec in enumerate(cfg.get("folds", [])):
		bn = spec["bones"]
		head = np.array(meta["bone_heads"][bn[0]], np.float64)
		tail = np.array(meta["bone_tails"][bn[-1]], np.float64)
		axis = tail - head
		axis /= np.linalg.norm(axis)
		e1 = np.cross(axis, [0.0, 1.0, 0.0])
		if np.linalg.norm(e1) < 1e-3:
			e1 = np.cross(axis, [1.0, 0.0, 0.0])
		e1 /= np.linalg.norm(e1)
		e2 = np.cross(axis, e1)
		idx = [meta["bones"].index(n) for n in spec.get("match_bones", bn)]
		sp = dict(spec)
		sp["cell"] = names.index(spec["region"])
		out = np.maximum(out, fold_lines(pos, maps["bone"], idx, ids, sp, axis, head, e1, e2, seed + 91 + k, maps["cover"]))
	return out


def class_bytes(ids, names, cfg):
	"""The ink map's G: the damage class of every region (paint.json "regions" -> "class": 255 clothes, 204 skin, 128 none)."""
	table = np.array([float(cfg["regions"][n].get("class", 255)) for n in names] + [128.0], np.float32)
	return table[ids] / 255.0


def bake(name, workdir, outdir, variant=None):
	"""Bake <name>_paint.png and <name>_ink.png into `outdir`. With `variant` (a key of paint.json "variants": {"veteran": {"regions": {name:
	{"base": .., "shade": ..}}}}): the same maps recoloured, only <name>_<variant>_paint.png is written (the ink is the same file)."""
	global PXS
	maps, meta = load_maps(workdir)
	cfg = load_config(name)
	if variant:
		for region, colours in cfg["variants"][variant]["regions"].items():
			cfg["regions"][region].update(colours)
	seed = cfg.get("seed", 7)
	cover = maps["cover"]
	size = cover.shape[0]
	PXS = size / 2048.0
	ids, names = region_map(maps, meta, cfg)
	reg = cfg["regions"]
	base_t = np.array([reg[n]["base"] for n in names] + [[0.5, 0.5, 0.5]], np.float32) / 255.0
	shade_t = np.array([reg[n]["shade"] for n in names] + [[0.4, 0.4, 0.4]], np.float32) / 255.0
	shadow, _hint = shadow_shapes(maps, meta, cfg.get("shadows", {}), ids, seed, size)
	gate = np.array([float(reg[n].get("shadow", 1.0)) for n in names] + [0.0], np.float32)[ids]
	shadow = np.clip(shadow * gate, 0.0, 1.0)
	paint = base_t[ids] * (1.0 - shadow[..., None]) + shade_t[ids] * shadow[..., None]
	# the grain of a brush in the fill: a faint value change inside a flat region, never a gradient
	grain = strokes_noise((size, size), 14 * PXS, max(int(2 * PXS), 1), 62, seed + 5) - 0.5
	paint = paint * (1.0 + grain[..., None] * cfg.get("grain", 0.06))
	# the lines
	ink_cfg = cfg.get("ink", {})
	curv = maps["curv"].astype(np.float32)
	valleys = line_from_valleys(curv, cover, ink_cfg, seed)
	skip = [meta["bones"].index(n) for n in ink_cfg.get("crease_skip_bones", []) if n in meta["bones"]]
	valleys = valleys * (~np.isin(maps["bone"], skip)) * ink_cfg.get("crease_strength", 0.8)
	ink = np.maximum(valleys, line_from_borders(ids, ink_cfg, seed))
	ink = np.maximum(ink, fold_set(maps, meta, cfg, ids, names, seed))
	ink = np.clip(warp(ink, ink_cfg.get("warp_px", 1.2) * PXS, ink_cfg.get("warp_scale_px", 22) * PXS, seed + 41), 0.0, 1.0)
	features = os.path.join(CONFIG_DIR, name, "features.svg")
	if os.path.exists(features):
		import trailer_features
		drawn = trailer_features.render(features, maps, meta, size, seed, os.path.join(CONFIG_DIR, name, "features_uv.svg"))
		ink = np.maximum(ink, drawn["ink"])
		a = drawn["paint_alpha"][..., None]
		paint = paint * (1.0 - a) + drawn["paint"] * a
	klass = class_bytes(ids, names, cfg)
	gloss = np.zeros((size, size), np.float32)
	for n in cfg.get("glossy", []):
		gloss = np.maximum(gloss, (ids == names.index(n)).astype(np.float32))
	hull = hull_weight(maps, meta, cfg, seed)
	os.makedirs(outdir, exist_ok=True)
	info = ndimage.distance_transform_edt(~cover, return_indices=True)
	paint_p, padded = pad_and_fill(np.clip(paint, 0, 1), cover, PAD_TEXELS, info)
	Image.fromarray((paint_p * 255.0 + 0.5).astype(np.uint8)).save(os.path.join(outdir, name + ("_%s" % variant if variant else "") + "_paint.png"), optimize=True)
	if variant:
		print("T12-PAINT %s %s: recoloured" % (name, variant))
		return
	chans = []
	for ch, outside in ((ink, 0.0), (klass, 128.0 / 255.0), (gloss, 0.0), (hull, 0.5)):
		filled, pad = pad_and_fill(ch[..., None], cover, PAD_TEXELS, info)
		chans.append(np.where(pad, filled[..., 0], outside))
	rgba = np.stack(chans, axis=2)
	Image.fromarray((np.clip(rgba, 0, 1) * 255.0 + 0.5).astype(np.uint8)).save(os.path.join(outdir, name + "_ink.png"), optimize=True)
	stats = {"size": size, "covered_texels": int(cover.sum()), "coverage_share": round(float(cover.mean()), 4),
		"regions": {n: int((ids == i).sum()) for i, n in enumerate(names)}}
	with open(os.path.join(workdir, name + "_stats.json"), "w") as f:
		json.dump(stats, f, indent=1)
	print("T12-PAINT %s: %dx%d coverage %.3f" % (name, size, size, cover.mean()))


def regions_preview(name, workdir, png, view, window, px_per_mm, grid=None, paint_png=None):
	"""A preview in a view: the regions' base colours (or, with `paint_png`, the baked paint.png sampled through the UV2 layout), lit."""
	maps, meta = load_maps(workdir)
	if paint_png:
		rgb = np.asarray(Image.open(paint_png).convert("RGB"), np.float32) / 255.0
		ink_png = paint_png.replace("_paint.png", "_ink.png")
		if os.path.exists(ink_png):
			line = np.asarray(Image.open(ink_png).convert("RGBA"), np.float32)[..., 0:1] / 255.0
			rgb = rgb * (1.0 - np.clip((line - 0.3) * 2.0, 0.0, 1.0) * 0.92)
	else:
		cfg = load_config(name)
		ids, names = region_map(maps, meta, cfg)
		table = np.array([cfg["regions"][n]["base"] for n in names] + [[0, 0, 0]], np.float32) / 255.0
		rgb = table[ids]
	save_view(maps, rgb, png, view, window, px_per_mm, grid)


if __name__ == "__main__":
	cmd = sys.argv[1]
	if cmd == "bake":
		bake(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5] if len(sys.argv) > 5 else None)
	elif cmd == "cells":
		# cells <name> <workdir> <png> <view> [x0 x1 z0 z1]  (the game's own palette cells, lit)
		maps, _meta = load_maps(sys.argv[3])
		win = tuple(float(a) for a in sys.argv[6:10]) if len(sys.argv) >= 10 else (-0.5, 0.5, 0.0, 1.85)
		save_view(maps, cell_colours(maps), sys.argv[4], sys.argv[5], win, float(os.environ.get("PX_PER_MM", "3.0")))
	elif cmd in ("regions", "painted"):
		# regions|painted <name> <workdir> <png> <view> [x0 x1 z0 z1]  (painted: the baked <name>_paint.png in <PAINT_DIR>)
		win = tuple(float(a) for a in sys.argv[6:10]) if len(sys.argv) >= 10 else (-0.5, 0.5, 0.0, 1.85)
		paint = os.path.join(os.environ["PAINT_DIR"], sys.argv[2] + "_paint.png") if cmd == "painted" else None
		regions_preview(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], win, float(os.environ.get("PX_PER_MM", "3.0")), None, paint)
	elif cmd == "sheet":
		# sheet <name> <workdir> <png> <view> <origin_r_m> <origin_u_m> <half_w_mm> <half_h_mm> <px_per_mm>: the millimetre grid features.svg uses
		r, u, hw, hh, ppm = (float(a) for a in sys.argv[6:11])
		win = (r - hw / 1000.0, r + hw / 1000.0, u - hh / 1000.0, u + hh / 1000.0)
		regions_preview(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], win, ppm, (r, u, hw, hh), os.environ.get("PAINT_PNG"))
