"""LD-ASSET's paint step (Phase 1, docs/video/P1.md): the painted albedo and the ink (crease) mask of one character.

	~/.venvs/beat-em-up-video/bin/python -I tools/video/art_paint.py bake    <name> <workdir> <outdir>
	~/.venvs/beat-em-up-video/bin/python -I tools/video/art_paint.py preview <name> <workdir> <png> [view] [x0 x1 z0 z1]

`workdir` is what tools/video/blender_asset.py wrote (maps.npz, meta.json). `bake` writes into `outdir`:
	<name>_paint.png   the painted albedo, RGBA, in the UV2 layout (the shader's paint_tex; the alpha is 1 inside the islands and their
	                   16 px padding, 0 elsewhere, where the rest is the mean colour: the shader falls back to the swatch where the
	                   alpha is 0): each palette swatch of the game
	                   becomes a material with 2-3 values (base, shade in the creases, light on the ridges) as hard-edged
	                   shapes with a wobbling edge and a quiet brush grain inside; the darks are lifted to saturated violet.
	<name>_ink.png     the ink map, 8-bit RGBA (the shader's ink_tex): R = ink, G = the glints' mask (the metal), B = the face zone
	                   (the shader lifts the face out of the shadow band there), A = the catchlights; R is: the creases of the surface (the valleys of the
	                   curvature, thinned to a line), the borders between two materials, and the features drawn by Claude as
	                   SVG (assets/source/video_art/<name>/features.svg, see art_features.py), every line warped by a smooth
	                   noise so no edge is ruler-clean and faded in and out by another so no line has one weight.
The values live in assets/source/video_art/<name>/paint.json. Pure numpy / scipy / opencv / pillow (the venv); Blender is not needed here.
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
CONFIG_DIR = os.path.join(ROOT, "assets", "source", "video_art")
GRID = (32, 2)
CELL_PX = 8
PAD_TEXELS = 16
## The line and noise sizes of paint.json are in texels of a 2048 map; multiplied by size / 2048 for the map being baked.
PXS = 1.0


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


def smoothed_ids(maps, meta, cfg):
	"""The palette cell of every texel with the material borders smoothed (paint.json "cell_smooth_mm": {"dense": mm, "other": mm}). A decimated
	mesh's faces are labelled one by one, so the border between two materials (a glove's plate and the skin) follows the triangles'
	edges in teeth; here each material's mask is blurred (normalised over the island, so an island's edge does not bias it) and the
	strongest wins, which turns the teeth into one drawn curve. The blur is in millimetres: the sigma in texels follows the local
	texel size (the dense bones of the layout's weights have small texels, the rest big ones)."""
	ids = cell_ids(maps)
	if "field" in maps and meta is not None and meta.get("field_cells"):
		# the vertex fields' shares (blender_asset.vertex_fields), interpolated over the triangles: the border is a smooth curve
		cells = np.array(meta["field_cells"])
		field = maps["field"]
		pick = np.zeros(ids.shape, np.int32)
		best = np.full(ids.shape, -1.0, np.float32)
		for j, c in enumerate(cells):
			v = field[..., j].astype(np.float32)
			better = v > best
			best = np.where(better, v, best)
			pick = np.where(better, c, pick)
		ids = np.where((field[..., -1] > 0.5) & (ids >= 0), pick, ids)
	spec = cfg.get("cell_smooth_mm")
	if not spec or meta is None:
		return ids
	cover = maps["cover"]
	size = cover.shape[0]
	pos = maps["pos"]
	step = np.linalg.norm(np.roll(pos, -1, 1).astype(np.float32) - pos.astype(np.float32), axis=2)
	both = cover & np.roll(cover, -1, 1) & (step < 0.01)
	mm_per_texel = {}
	weights = cfg.get("layout", {}).get("weights", {})
	dense = [meta["bones"].index(b) for b, w in weights.items() if float(w) >= 1.2 and b in meta["bones"]]
	is_dense = np.isin(maps["bone"], dense)
	for key, sel in (("dense", is_dense), ("other", ~is_dense)):
		m = both & sel
		mm_per_texel[key] = 1000.0 * float(np.median(step[m])) if m.any() else 1.0
	out = ids.copy()
	for key, sel in (("dense", is_dense), ("other", ~is_dense)):
		sigma = max(float(spec.get(key, 0.0)) / max(mm_per_texel[key], 0.05), 0.0)
		if sigma < 0.8:
			continue
		area = cv2.GaussianBlur(cover.astype(np.float32), (0, 0), sigma)
		best = np.full(cover.shape, -1.0, np.float32)
		pick = out.copy()
		for cell in np.unique(ids[(ids >= 0) & sel]):
			v = cv2.GaussianBlur((ids == cell).astype(np.float32), (0, 0), sigma) / np.maximum(area, 1e-4)
			better = v > best
			best = np.where(better, v, best)
			pick = np.where(better, cell, pick)
		out = np.where(sel & (ids >= 0), pick, out)
	return out


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


def dilate_nearest(img, cover, texels):
	"""Fill the texels outside `cover` (within `texels` of it) from the nearest covered texel: padding for the seams."""
	dist, idx = ndimage.distance_transform_edt(~cover, return_indices=True)
	filled = img[idx[0], idx[1]]
	grow = (~cover) & (dist <= texels)
	out = img.copy()
	out[grow] = filled[grow]
	return out, cover | grow


def luminance(rgb_lin):
	return rgb_lin @ np.array([0.2126, 0.7152, 0.0722], np.float32)


def lift_dark(rgb, lift_to, tint, tint_amount):
	"""Lift a very dark swatch (sRGB 0..1) toward `lift_to` luminance (a flat near-black takes no key and no rim) and tint it."""
	lin = srgb_to_lin(rgb)
	y = float(luminance(lin))
	if y < lift_to:
		lin = lin * (lift_to / max(y, 1e-4)) ** 0.8
	lin = lin * (1.0 - tint_amount) + srgb_to_lin(np.array(tint, np.float32)) * tint_amount * max(luminance(lin), 0.01) / max(
		float(luminance(srgb_to_lin(np.array(tint, np.float32)))), 1e-4)
	return lin_to_srgb(lin)


def load_config(name):
	with open(os.path.join(CONFIG_DIR, name, "paint.json")) as f:
		return json.load(f)


def material_rgb(spec, base_rgb):
	"""(base, shade, light) sRGB for a material from its config row (explicit colours win, else made from the swatch)."""
	base = np.array(spec.get("base", base_rgb), np.float32)
	if "lift" in spec:
		base = lift_dark(base, spec["lift"], spec.get("tint", [0.35, 0.18, 0.4]), spec.get("tint_amount", 0.3))
	shade = np.array(spec["shade"], np.float32) if "shade" in spec else lin_to_srgb(srgb_to_lin(base) * np.array(spec.get("shade_mul", [0.55, 0.5, 0.75])))
	light = np.array(spec["light"], np.float32) if "light" in spec else lin_to_srgb(srgb_to_lin(base) * np.array(spec.get("light_mul", [1.35, 1.25, 1.05])))
	return base, shade, light


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


def paint_albedo(maps, cfg, seed, meta=None):
	"""The painted albedo (sRGB float, size x size x 3) and the cell map. Evaluated in bands of rows from per-cell tables."""
	ids = smoothed_ids(maps, meta, cfg)
	size = ids.shape[0]
	colours = atlas_colours()
	curv_s = form_curvature(maps, cfg.get("form_sigma", 3.0) * size / 2048.0)
	cov = maps["cover"]
	lo, hi = np.percentile(curv_s[cov], [cfg.get("shade_pct", 8.0), cfg.get("light_pct", 88.0)])
	q1, q3 = np.percentile(curv_s[cov], [25, 75])
	spread = max(float(q3 - q1) / 1.35, 1e-3)
	scale = size / 2048.0
	wob = smooth_noise((size, size), cfg.get("wobble_px", 18) * scale, seed) - 0.5
	grain = strokes_noise((size, size), cfg.get("brush_len_px", 14) * scale, max(int(2 * scale), 1), cfg.get("brush_angle_deg", 62), seed + 5) - 0.5
	flow = smooth_noise((size, size), cfg.get("blotch_px", 60) * scale, seed + 9) - 0.5
	materials = cfg["materials"]
	default = cfg.get("default", {})
	n = GRID[0] * GRID[1]
	base_t = np.zeros((n, 3), np.float32)
	shade_t = np.zeros((n, 3), np.float32)
	light_t = np.zeros((n, 3), np.float32)
	par = {k: np.zeros(n, np.float32) for k in ("shade_hard", "light_hard", "shade_amount", "light_amount", "blotch_bias", "blotch_hard", "blotch_amount", "grain")}
	present = np.unique(ids[ids >= 0])
	for cell in range(n):
		spec = dict(default)
		spec.update(materials.get(str(cell), {}))
		base_t[cell], shade_t[cell], light_t[cell] = material_rgb(spec, colours[cell][:3])
		for k, dv in (("shade_hard", 4.0), ("light_hard", 4.0), ("shade_amount", 1.0), ("light_amount", 1.0), ("blotch_bias", 0.0),
				("blotch_hard", 1.0), ("blotch_amount", 0.0), ("grain", 0.12)):
			par[k][cell] = spec.get(k, dv)
	wobble_gain = cfg.get("wobble_gain", 1.0) * spread
	out = np.zeros((size, size, 3), np.float32)
	band = 256
	for r0 in range(0, size, band):
		sl = slice(r0, min(r0 + band, size))
		cid = ids[sl]
		ok = cid >= 0
		ci = np.where(ok, cid, 0)
		c = curv_s[sl] + wob[sl] * wobble_gain
		t_shade = np.clip((lo - c) / spread * par["shade_hard"][ci] + 0.5, 0.0, 1.0) * par["shade_amount"][ci]
		t_light = np.clip((c - hi) / spread * par["light_hard"][ci] + 0.5, 0.0, 1.0) * par["light_amount"][ci]
		blotch = np.clip((flow[sl] + par["blotch_bias"][ci]) * 40.0 * par["blotch_hard"][ci] + 0.5, 0.0, 1.0) * par["blotch_amount"][ci]
		rgb = base_t[ci]
		rgb = rgb * (1.0 - t_shade[..., None]) + shade_t[ci] * t_shade[..., None]
		rgb = rgb * (1.0 - t_light[..., None]) + light_t[ci] * t_light[..., None]
		rgb = rgb * (1.0 - blotch[..., None]) + shade_t[ci] * blotch[..., None]
		rgb = rgb * (1.0 + grain[sl][..., None] * par["grain"][ci][..., None])
		out[sl] = np.where(ok[..., None], rgb, 0.0)
	return np.clip(out, 0.0, 1.0), ids


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


def wrap_lines(maps, meta, cfg, ids, seed):
	"""Bandage wraps as ink: on the texels of a material (a wrap's cream) near a limb's bones, spiral lines around the limb's axis
	(the bones' chain), `pitch_mm` apart along the axis and turning `turns` times round per pitch, wandering by noise, fading in
	and out. Procedural, in the surface's own space, so the strips follow the limb wherever the layout puts them."""
	size = ids.shape[0]
	out = np.zeros((size, size), np.float32)
	pos = maps["pos"].astype(np.float64)
	bone = maps["bone"]
	for w, spec in enumerate(cfg.get("wraps", [])):
		names = spec["bones"]
		head = np.array(meta["bone_heads"][names[0]], np.float64)
		tail = np.array(meta["bone_tails"][names[-1]], np.float64)
		axis = tail - head
		length = float(np.linalg.norm(axis))
		axis /= length
		e1 = np.cross(axis, [0.0, 1.0, 0.0])
		e1 /= np.linalg.norm(e1)
		e2 = np.cross(axis, e1)
		idx = [meta["bones"].index(n) for n in names]
		mask = np.isin(bone, idx) & (ids == spec["cell"])
		v = pos - head
		t = v @ axis
		radial = v - t[..., None] * axis
		phi = np.arctan2(radial @ e2, radial @ e1)
		if spec.get("kind") == "folds":
			out = np.maximum(out, fold_lines(pos, bone, idx, ids, spec, axis, head, e1, e2, seed + 91 + w, maps["cover"]))
			continue
		pitch = spec.get("pitch_mm", 24.0) / 1000.0
		noise = (smooth_noise((size, size), spec.get("wobble_px", 30) * PXS, seed + 61 + w) - 0.5) * spec.get("wobble", 0.35)
		if spec.get("kind", "spiral") == "meridians":
			# `count` lines along the limb (the fibres of a muscle, the run of a tendon), drifting by `slant` turns per metre.
			circumference = 2.0 * np.pi * np.maximum(np.linalg.norm(radial, axis=2), 0.02)
			s_param = phi / (2.0 * np.pi) * spec.get("count", 5) + t * spec.get("slant", 0.0) + noise
			d_mm = np.abs((s_param + 0.5) % 1.0 - 0.5) * circumference * 1000.0 / spec.get("count", 5)
		else:
			s_param = t / pitch + phi / (2.0 * np.pi) * spec.get("turns", 0.6) + noise
			d_mm = np.abs((s_param + 0.5) % 1.0 - 0.5) * spec.get("pitch_mm", 24.0)
		half = spec.get("width_mm", 2.4) / 2.0
		mm_per_texel = 1000.0 * float(np.median(np.linalg.norm(np.roll(pos, -1, 1) - pos, axis=2)[maps["cover"]]))
		line = np.clip((half - d_mm) / max(mm_per_texel, 0.1) + 0.5, 0.0, 1.0)
		fade = smooth_noise((size, size), spec.get("fade_px", 50) * PXS, seed + 71 + w)
		line *= np.clip((fade - spec.get("fade_cut", 0.3)) * 4.0, 0.0, 1.0)
		out = np.maximum(out, line * mask * spec.get("strength", 0.85))
	return out


def face_zone(maps, meta, cfg):
	"""The face zone (0..1, the ink map's B): the head's texels that look forward and sit between the chin and `top` of the head's box
	(paint.json "face"), feathered; the shader lifts the face out of the shadow band there. Zero for a character with no head."""
	spec = cfg.get("face")
	size = maps["cover"].shape[0]
	out = np.zeros((size, size), np.float32)
	fill = cfg.get("fill")
	if fill:
		# paint.json "fill": {"cells": {"7": 0.55}, "bones": ["LeftLowerArm", ...]}: a constant zone value on those materials of those bones
		# (the first-person arm's skin and wraps: lifted out of the shadow band into a warm, painted tone)
		ids = cell_ids(maps)
		bones = [meta["bones"].index(b) for b in fill["bones"]]
		on = np.isin(maps["bone"], bones)
		for cell, value in fill["cells"].items():
			out = np.maximum(out, np.where(on & (ids == int(cell)), float(value), 0.0).astype(np.float32))
	if spec is None or "head" not in meta:
		return cv2.GaussianBlur(out, (0, 0), 6.0 * PXS) if fill else out
	centre = np.array(meta["head"]["centre"], np.float32)
	radii = np.array(meta["head"]["radii"], np.float32)
	pos = maps["pos"]
	nrm = maps["nrm"]
	head_out = np.zeros((size, size), np.float32)
	head = meta["bones"].index("Head")
	band = 256
	front = np.array(meta["front"], np.float32)
	for r0 in range(0, size, band):
		sl = slice(r0, min(r0 + band, size))
		p = (pos[sl].astype(np.float32) - centre) / np.maximum(radii, 1e-6)
		facing = nrm[sl].astype(np.float32) @ front
		m = maps["cover"][sl] & (maps["bone"][sl] == head)
		z0, z1 = spec.get("z_from", -0.95), spec.get("z_to", 0.35)
		zone = np.clip((p[..., 2] - z0) / 0.12, 0, 1) * np.clip((z1 - p[..., 2]) / 0.12, 0, 1)
		zone *= np.clip((facing - spec.get("facing", 0.15)) / 0.3, 0, 1) * np.clip((p[..., 1] + 0.2) / 0.5, 0, 1)
		zone *= np.clip((spec.get("half_width", 0.95) - np.abs(p[..., 0])) / 0.2, 0, 1)
		head_out[sl] = zone * m
	return np.maximum(cv2.GaussianBlur(head_out, (0, 0), 6.0 * PXS), cv2.GaussianBlur(out, (0, 0), 6.0 * PXS) if fill else out)


def metal_mask(ids, cfg):
	"""The ink map's G: 1 on the palette cells that are metal (paint.json "metal"), where the shader may put a glint."""
	cells = cfg.get("metal", [])
	if not cells:
		return np.zeros(ids.shape, np.float32)
	return np.isin(ids, cells).astype(np.float32)


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


def bake(name, workdir, outdir):
	global PXS
	maps, meta = load_maps(workdir)
	cfg = load_config(name)
	seed = cfg.get("seed", 7)
	cover = maps["cover"]
	size = cover.shape[0]
	PXS = size / 2048.0
	albedo, ids = paint_albedo(maps, cfg, seed, meta)
	ink_size = size
	curv = maps["curv"].astype(np.float32)
	ink = np.maximum(line_from_valleys(curv, cover, cfg, seed), line_from_borders(ids, cfg, seed))
	ink = np.maximum(ink, wrap_lines(maps, meta, cfg, ids, seed))
	ink = warp(ink, cfg.get("warp_px", 1.4) * PXS, cfg.get("warp_scale_px", 22) * PXS, seed + 41)
	ink = np.clip(ink, 0.0, 1.0)
	glint = metal_mask(ids, cfg)
	catch = np.zeros((size, size), np.float32)
	face = face_zone(maps, meta, cfg)
	features = os.path.join(CONFIG_DIR, name, "features.svg")
	if os.path.exists(features):
		import art_features
		drawn = art_features.render(features, maps, meta, ink_size, seed, os.path.join(CONFIG_DIR, name, "features_uv.svg"))
		ink = np.maximum(ink, drawn["ink"])
		catch = np.maximum(catch, drawn["catch"])
		# the features' own paint (an eye's white, an iris, a lens): painted over the albedo where it has alpha
		a = drawn["paint_alpha"][..., None]
		albedo = albedo * (1.0 - a) + drawn["paint"] * a
	os.makedirs(outdir, exist_ok=True)
	info = ndimage.distance_transform_edt(~cover, return_indices=True)
	paint, padded = pad_and_fill(albedo, cover, PAD_TEXELS, info)
	rgba = np.concatenate([paint, padded[..., None].astype(np.float32)], axis=2)
	Image.fromarray((np.clip(rgba, 0, 1) * 255.0 + 0.5).astype(np.uint8)).save(os.path.join(outdir, name + "_paint.png"), optimize=True)
	chans = []
	for ch in (ink, glint, face, catch):
		filled, _ = pad_and_fill(ch[..., None], cover, PAD_TEXELS, info)
		chans.append(filled[..., 0])
	rgb = np.stack(chans, axis=2)  # R ink, G metal, B face zone, A catchlights
	Image.fromarray((np.clip(rgb, 0, 1) * 255.0 + 0.5).astype(np.uint8)).save(os.path.join(outdir, name + "_ink.png"), optimize=True)
	# The measure the tests and the review use: texels of the islands with no paint, and pure black inside them.
	covered_px = int(cover.sum())
	black = int(((paint[cover] * 255.0 + 0.5).astype(np.uint8).max(axis=1) == 0).sum())
	stats = {"size": size, "islands_covered_texels": covered_px, "empty_texels_in_islands": int(cover.sum() - (cover & padded).sum()),
		"pure_black_texels_in_islands": black, "coverage_share": round(float(cover.mean()), 4)}
	with open(os.path.join(CONFIG_DIR, name, "coverage.json"), "w") as f:
		json.dump(stats, f, indent=1)
	print("LD-ASSET paint %s: %dx%d coverage %.3f black %d" % (name, size, size, cover.mean(), black))


# --- the front view: the canvas for the drawn features and the look at the result ---


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


def shade_rgb(maps, rgb):
	"""The albedo lit by a fixed soft light from the upper left front, so a preview shows the form."""
	n = maps["nrm"].astype(np.float32)
	light = np.array([-0.4, 0.55, 0.7], np.float32)
	light /= np.linalg.norm(light)
	lam = np.clip(n @ light, 0.0, 1.0)
	return rgb * (0.45 + 0.65 * lam[..., None])


def preview(name, workdir, png, view="front", window=None, px_per_mm=3.0):
	maps, meta = load_maps(workdir)
	cfg = load_config(name)
	albedo, _ids = paint_albedo(maps, cfg, cfg.get("seed", 7))
	if window is None:
		window = (-0.5, 0.5, 0.0, 1.85)
	img, _ = splat_view(maps, shade_rgb(maps, albedo), view, window, px_per_mm)
	Image.fromarray((np.clip(img, 0, 1) * 255.0 + 0.5).astype(np.uint8)).save(png)


def sheet(name, workdir, png, view, origin, half_mm, px_per_mm, grid_mm=10):
	"""A canvas to draw features on: the painted character in `view` around `origin` (metres on the view's right and up axes),
	`half_mm` = (half width, half height) in millimetres, with a labelled grid in the millimetres the features.svg groups use
	(x to the right, y DOWN, 0 at the origin)."""
	maps, meta = load_maps(workdir)
	cfg = load_config(name)
	albedo, _ids = paint_albedo(maps, cfg, cfg.get("seed", 7))
	window = (origin[0] - half_mm[0] / 1000.0, origin[0] + half_mm[0] / 1000.0, origin[1] - half_mm[1] / 1000.0, origin[1] + half_mm[1] / 1000.0)
	img, _ = splat_view(maps, shade_rgb(maps, albedo), view, window, px_per_mm)
	img = (np.clip(img, 0, 1) * 255.0 + 0.5).astype(np.uint8)
	img = np.ascontiguousarray(img)
	h, w = img.shape[:2]
	for gx in range(-int(half_mm[0]) // grid_mm * grid_mm, int(half_mm[0]) + 1, grid_mm):
		x = int((gx + half_mm[0]) * px_per_mm)
		major = gx % (grid_mm * 5) == 0
		cv2.line(img, (x, 0), (x, h), (255, 255, 255) if major else (110, 110, 110), 1)
		if major:
			cv2.putText(img, str(gx), (x + 2, 12), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (255, 255, 0), 1, cv2.LINE_AA)
	for gy in range(-int(half_mm[1]) // grid_mm * grid_mm, int(half_mm[1]) + 1, grid_mm):
		y = int((gy + half_mm[1]) * px_per_mm)
		major = gy % (grid_mm * 5) == 0
		cv2.line(img, (0, y), (w, y), (255, 255, 255) if major else (110, 110, 110), 1)
		if major:
			cv2.putText(img, str(gy), (2, y - 2), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (255, 255, 0), 1, cv2.LINE_AA)
	Image.fromarray(img).save(png)


def grid_overlay(png_in, png_out, half_w, half_h, px_per_mm, grid_mm=10):
	"""Draw the features.svg millimetre grid (x right, y down, 0 at the picture's centre) over a tools/video/blender_view.py render."""
	img = np.ascontiguousarray(np.asarray(Image.open(png_in).convert("RGB")).copy())
	h, w = img.shape[:2]
	for gx in range(-int(half_w) // grid_mm * grid_mm, int(half_w) + 1, grid_mm):
		x = int(round((gx + half_w) * px_per_mm))
		major = gx % (grid_mm * 5) == 0
		cv2.line(img, (x, 0), (x, h), (255, 255, 255) if major else (120, 120, 160), 1)
		if major:
			cv2.putText(img, str(gx), (x + 2, 12), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 220, 0), 1, cv2.LINE_AA)
	for gy in range(-int(half_h) // grid_mm * grid_mm, int(half_h) + 1, grid_mm):
		y = int(round((gy + half_h) * px_per_mm))
		major = gy % (grid_mm * 5) == 0
		cv2.line(img, (0, y), (w, y), (255, 255, 255) if major else (120, 120, 160), 1)
		if major:
			cv2.putText(img, str(gy), (2, y - 2), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 220, 0), 1, cv2.LINE_AA)
	Image.fromarray(img).save(png_out)


if __name__ == "__main__":
	cmd = sys.argv[1]
	if cmd == "bake":
		bake(sys.argv[2], sys.argv[3], sys.argv[4])
	elif cmd == "sheet":
		# sheet <name> <workdir> <png> <view> <origin_r_m> <origin_u_m> <half_w_mm> <half_h_mm> <px_per_mm>
		sheet(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], (float(sys.argv[6]), float(sys.argv[7])),
			(float(sys.argv[8]), float(sys.argv[9])), float(sys.argv[10]))
	elif cmd == "grid":
		# grid <png_in> <png_out> <half_w_mm> <half_h_mm> <px_per_mm>
		grid_overlay(sys.argv[2], sys.argv[3], float(sys.argv[4]), float(sys.argv[5]), float(sys.argv[6]))
	elif cmd == "preview":
		win = tuple(float(a) for a in sys.argv[6:10]) if len(sys.argv) >= 10 else None
		preview(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5] if len(sys.argv) > 5 else "front", win,
			float(os.environ.get("PX_PER_MM", "3.0")))
