"""LD-ASSET's paint step (Phase 1, docs/video/P1.md): the painted albedo and the ink (crease) mask of one character.

	~/.venvs/beat-em-up-video/bin/python -I tools/video/art_paint.py bake    <name> <workdir> <outdir>
	~/.venvs/beat-em-up-video/bin/python -I tools/video/art_paint.py preview <name> <workdir> <png> [view] [x0 x1 z0 z1]

`workdir` is what tools/video/blender_asset.py wrote (maps.npz, meta.json). `bake` writes into `outdir`:
	<name>_paint.png   the painted albedo, RGB, in the UV2 layout (the shader's paint_tex): each palette swatch of the game
	                   becomes a material with 2-3 values (base, shade in the creases, light on the ridges) as hard-edged
	                   shapes with a wobbling edge and a quiet brush grain inside; the darks are lifted to saturated violet.
	<name>_ink.png     the ink mask, 8-bit grey, R = ink (the shader's ink_tex): the creases of the surface (the valleys of the
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
PAD_TEXELS = 12


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
	normals are smooth across the triangles, so this one thresholds to rounded, wandering shapes."""
	pos = maps["pos"].astype(np.float32)
	nrm = maps["nrm"].astype(np.float32)
	cover = maps["cover"]
	out = np.zeros(cover.shape, np.float32)
	valid = np.zeros(cover.shape, np.float32)
	for axis in (0, 1):
		dp = np.roll(pos, -1, axis) - np.roll(pos, 1, axis)
		dn = np.roll(nrm, -1, axis) - np.roll(nrm, 1, axis)
		ok = cover & np.roll(cover, -1, axis) & np.roll(cover, 1, axis)
		length = np.linalg.norm(dp, axis=2)
		ok &= (length < 0.012) & (length > 1e-6)
		k = (dn * dp).sum(axis=2) / np.maximum((dp * dp).sum(axis=2), 1e-12)
		out += np.where(ok, k, 0.0)
		valid += ok
	out = out / np.maximum(valid, 1.0)
	weight = cv2.GaussianBlur((valid > 0).astype(np.float32), (0, 0), sigma)
	blur = cv2.GaussianBlur(out * (valid > 0), (0, 0), sigma)
	return np.where(weight > 1e-3, blur / np.maximum(weight, 1e-3), 0.0).astype(np.float32)


def paint_albedo(maps, cfg, seed):
	"""The painted albedo (sRGB float, size x size x 3) and the cell map."""
	ids = cell_ids(maps)
	size = ids.shape[0]
	colours = atlas_colours()
	curv_s = form_curvature(maps, cfg.get("form_sigma", 3.0))
	cov = maps["cover"]
	lo, hi = np.percentile(curv_s[cov], [cfg.get("shade_pct", 8.0), cfg.get("light_pct", 88.0)])
	q1, q3 = np.percentile(curv_s[cov], [25, 75])
	spread = max(float(q3 - q1) / 1.35, 1e-3)
	wob = smooth_noise((size, size), cfg.get("wobble_px", 18), seed) - 0.5
	grain = strokes_noise((size, size), cfg.get("brush_len_px", 14), 2, cfg.get("brush_angle_deg", 62), seed + 5) - 0.5
	flow = smooth_noise((size, size), cfg.get("blotch_px", 60), seed + 9) - 0.5
	out = np.zeros((size, size, 3), np.float32)
	materials = cfg["materials"]
	default = cfg.get("default", {})
	shade_cut = float(lo)
	light_cut = float(hi)
	wobble_gain = cfg.get("wobble_gain", 1.0) * spread
	for cell in np.unique(ids[ids >= 0]):
		spec = dict(default)
		spec.update(materials.get(str(int(cell)), {}))
		base, shade, light = material_rgb(spec, colours[cell][:3])
		mask = ids == cell
		c = curv_s + wob * wobble_gain
		t_shade = np.clip((shade_cut - c) / spread * spec.get("shade_hard", 4.0) + 0.5, 0.0, 1.0)
		t_light = np.clip((c - light_cut) / spread * spec.get("light_hard", 4.0) + 0.5, 0.0, 1.0)
		t_shade = t_shade * spec.get("shade_amount", 1.0)
		t_light = t_light * spec.get("light_amount", 1.0)
		blotch = np.clip((flow + spec.get("blotch_bias", 0.0)) * 40.0 * spec.get("blotch_hard", 1.0) + 0.5, 0.0, 1.0) * spec.get("blotch_amount", 0.0)
		rgb = base[None, None, :] * np.ones((size, size, 1), np.float32)
		rgb = rgb * (1.0 - t_shade[..., None]) + shade[None, None, :] * t_shade[..., None]
		rgb = rgb * (1.0 - t_light[..., None]) + light[None, None, :] * t_light[..., None]
		rgb = rgb * (1.0 - blotch[..., None]) + shade[None, None, :] * blotch[..., None]
		rgb = rgb * (1.0 + grain[..., None] * spec.get("grain", 0.12))
		out[mask] = rgb[mask]
	out = np.clip(out, 0.0, 1.0)
	return out, ids


def line_from_valleys(curv, cover, cfg, seed):
	"""A thin line along the valleys of the curvature: the valley score, kept only near its local maximum, then softened."""
	size = curv.shape[0]
	score = np.clip(-cv2.GaussianBlur(curv, (0, 0), cfg.get("crease_blur", 1.0)), 0.0, None)
	local = ndimage.maximum_filter(score, size=cfg.get("crease_nms", 5))
	keep = (score >= local * cfg.get("crease_keep", 0.78)) & (score > cfg.get("crease_min", 7.0))
	line = keep.astype(np.float32) * np.clip((score - cfg.get("crease_min", 7.0)) / cfg.get("crease_full", 10.0), 0.15, 1.0)
	line = cv2.dilate(line, np.ones((2, 2), np.uint8))
	line = cv2.GaussianBlur(line, (0, 0), 0.7)
	# Hand-drawn: the weight comes and goes along the line, and short bits are lost.
	fade = smooth_noise((size, size), cfg.get("fade_px", 40), seed + 21)
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
	width = cfg.get("border_px", 2)
	edge = cv2.dilate(edge, np.ones((width, width), np.uint8))
	edge = cv2.GaussianBlur(edge, (0, 0), 0.7)
	fade = smooth_noise((size, size), cfg.get("fade_px", 40), seed + 31)
	edge *= np.clip((fade - cfg.get("border_fade_cut", 0.3)) * 4.0, 0.0, 1.0)
	return edge * cfg.get("border_strength", 0.8)


def bake(name, workdir, outdir):
	maps, meta = load_maps(workdir)
	cfg = load_config(name)
	seed = cfg.get("seed", 7)
	cover = maps["cover"]
	size = cover.shape[0]
	albedo, ids = paint_albedo(maps, cfg, seed)
	albedo, padded = dilate_nearest(albedo, cover, PAD_TEXELS)
	os.makedirs(outdir, exist_ok=True)
	Image.fromarray((albedo * 255.0 + 0.5).astype(np.uint8)).save(os.path.join(outdir, name + "_paint.png"), optimize=True)
	curv = maps["curv"].astype(np.float32)
	ink = np.maximum(line_from_valleys(curv, cover, cfg, seed), line_from_borders(ids, cfg, seed))
	ink = warp(ink, cfg.get("warp_px", 1.4), cfg.get("warp_scale_px", 22), seed + 41)
	ink_size = cfg.get("ink_size", 4096)
	ink_big = cv2.resize(ink, (ink_size, ink_size), interpolation=cv2.INTER_CUBIC)
	ink_big = np.clip(ink_big, 0.0, 1.0)
	features = os.path.join(CONFIG_DIR, name, "features.svg")
	if os.path.exists(features):
		import art_features
		strokes = art_features.render(features, maps, meta, ink_size, seed, os.path.join(CONFIG_DIR, name, "features_uv.svg"))
		ink_big = np.maximum(ink_big, strokes)
	cover_big = cv2.resize(cover.astype(np.uint8), (ink_size, ink_size), interpolation=cv2.INTER_NEAREST).astype(bool)
	ink_big, _ = dilate_nearest(ink_big, cover_big, PAD_TEXELS * ink_size // size)
	Image.fromarray((np.clip(ink_big, 0, 1) * 255.0 + 0.5).astype(np.uint8)).save(os.path.join(outdir, name + "_ink.png"), optimize=True)
	print("LD-ASSET paint %s: paint %dx%d ink %dx%d coverage %.3f" % (name, size, size, ink_size, ink_size, cover.mean()))


# --- the front view: the canvas for the drawn features and the look at the result ---


# A view is (screen right, screen up, toward the viewer) in the character's space (+Y is its front, +Z up). "front" is what a
# viewer in front of the character sees: his left hand on the viewer's right, so the viewer's right is -X.
VIEWS = {
	"front": (np.array([-1.0, 0.0, 0.0]), np.array([0.0, 0.0, 1.0]), np.array([0.0, 1.0, 0.0])),
	"back": (np.array([1.0, 0.0, 0.0]), np.array([0.0, 0.0, 1.0]), np.array([0.0, -1.0, 0.0])),
	"left": (np.array([0.0, -1.0, 0.0]), np.array([0.0, 0.0, 1.0]), np.array([1.0, 0.0, 0.0])),
	"right": (np.array([0.0, 1.0, 0.0]), np.array([0.0, 0.0, 1.0]), np.array([-1.0, 0.0, 0.0])),
	"top": (np.array([-1.0, 0.0, 0.0]), np.array([0.0, 1.0, 0.0]), np.array([0.0, 0.0, 1.0])),
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
