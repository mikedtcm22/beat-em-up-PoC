"""Paint the video's matte cards (LD-WORLD; docs/video/PLAN.md section 4 part 4 and 7): far skylines and smoke and fire banks.

The "painting as code": every matte is made of a few flat value bands whose edges are bent by domain-warped noise (brush
bands), a silhouette alpha with a painted edge, and sparse lit windows. A generalized (four-sector) Kuwahara filter is
allowed on these layers ONLY (it would swim under a moving camera on the 3D environment); here it only flattens the grain.

Usage (the video venv; numpy, scipy and OpenCV only):
  ~/.venvs/beat-em-up-video/bin/python -I tools/video/paint_mattes.py --out assets/video/mattes [--only skyline_night]
Writes RGBA PNGs (2048 px wide) and prints their sizes. Deterministic: the same seed gives the same bytes.
"""
from __future__ import annotations

import argparse
import os
import sys

import cv2
import numpy as np
from scipy import ndimage

WIDTH = 2048

# Palettes: sRGB 0-255. Layers run far to near; a far layer is nearer the horizon colour (the air).
PALETTES = {
	"night": {
		"layers": [(46, 52, 98), (30, 34, 72), (18, 20, 46)],
		"rim": (74, 82, 140),
		"window_warm": (255, 168, 72),
		"window_cool": (150, 190, 255),
		"windows": 0.045,
		"cool_share": 0.25,
	},
	"dusk": {
		"layers": [(196, 130, 120), (140, 88, 112), (84, 54, 84)],
		"rim": (236, 176, 128),
		"window_warm": (255, 200, 110),
		"window_cool": (255, 200, 110),
		"windows": 0.03,
		"cool_share": 0.0,
	},
}
SMOKE = {
	"fire": {
		"bands": [(24, 14, 30), (52, 24, 40), (98, 38, 44)],
		"rim": (214, 96, 40),
		"glow": (255, 150, 50),
	},
}


def fbm(shape, scale, seed, octaves=4, stretch=(1.0, 1.0)):
	"""Value noise in 0..1: `scale` is the cells across the width; `stretch` (x, y) the cell aspect."""
	h, w = shape
	rng = np.random.default_rng(seed)
	out = np.zeros(shape, dtype=np.float32)
	amp = 1.0
	total = 0.0
	for i in range(octaves):
		cells_x = max(2, int(scale * (2 ** i) * stretch[0]))
		cells_y = max(2, int(scale * (2 ** i) * stretch[1] * h / w))
		grid = rng.random((cells_y + 1, cells_x + 1)).astype(np.float32)
		out += amp * cv2.resize(grid, (w, h), interpolation=cv2.INTER_CUBIC)
		total += amp
		amp *= 0.5
	return np.clip(out / total, 0.0, 1.0)


def warp_coords(shape, strength, scale, seed):
	"""Per-pixel (dx, dy) offsets from low-frequency noise, in pixels."""
	h, w = shape
	dx = (fbm(shape, scale, seed, 3) - 0.5) * 2.0 * strength
	dy = (fbm(shape, scale, seed + 1, 3) - 0.5) * 2.0 * strength
	return dx, dy


def warp_image(img, dx, dy):
	h, w = img.shape[:2]
	xs, ys = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
	return cv2.remap(img, xs + dx, ys + dy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)


def kuwahara(rgb, radius=4):
	"""A generalized Kuwahara filter, four overlapping sectors (box means and variances); flattens grain into brush patches."""
	f = rgb.astype(np.float32)
	k = radius + 1
	means, vars_ = [], []
	for (ox, oy) in ((-radius // 2, -radius // 2), (radius // 2, -radius // 2), (-radius // 2, radius // 2), (radius // 2, radius // 2)):
		m = np.stack([ndimage.uniform_filter(f[..., c], size=k, mode="nearest") for c in range(3)], -1)
		m2 = np.stack([ndimage.uniform_filter(f[..., c] ** 2, size=k, mode="nearest") for c in range(3)], -1)
		v = (m2 - m * m).sum(-1)
		m = np.roll(m, (oy, ox), axis=(0, 1))
		v = np.roll(v, (oy, ox), axis=(0, 1))
		means.append(m)
		vars_.append(v)
	means = np.stack(means, 0)
	vars_ = np.stack(vars_, 0)
	pick = np.argmin(vars_, axis=0)
	out = np.take_along_axis(means, pick[None, ..., None], axis=0)[0]
	return np.clip(out, 0, 255).astype(np.uint8)


def building_profile(width, base_h, seed, block=(24, 90), tall=0.12, max_h=1.0):
	"""A skyline's height (px) for every column: blocks of random width and height, a few towers, a setback now and then."""
	rng = np.random.default_rng(seed)
	heights = np.zeros(width, dtype=np.float32)
	x = 0
	while x < width:
		w = int(rng.integers(block[0], block[1]))
		h = base_h * float(rng.uniform(0.35, 0.8))
		if rng.random() < tall:
			h = base_h * float(rng.uniform(0.9, max_h))
		heights[x:x + w] = h
		if rng.random() < 0.35 and w > 40:
			inset = int(w * rng.uniform(0.2, 0.35))
			heights[x + inset:x + w - inset] += base_h * float(rng.uniform(0.06, 0.16))
		if rng.random() < 0.15:
			cx = x + w // 2
			heights[cx:cx + 3] += base_h * 0.2
		x += w
	return heights


def skyline(name, palette, height, seed):
	pal = PALETTES[palette]
	h, w = height, WIDTH
	rgb = np.zeros((h, w, 3), dtype=np.float32)
	alpha = np.zeros((h, w), dtype=np.float32)
	rng = np.random.default_rng(seed)
	ys = np.arange(h, dtype=np.float32)[:, None]
	for li, col in enumerate(pal["layers"]):
		base = h * (0.55 + 0.12 * li)
		prof = building_profile(w, base, seed * 7 + li, block=(30 + 10 * li, 100 + 30 * li), tall=0.14 - 0.02 * li)
		top = (h - prof)[None, :]
		mask = (ys >= top).astype(np.float32)
		# The painted edge: the top is bent by noise, then kept hard.
		dx, dy = warp_coords((h, w), 5.0 + 2 * li, 14, seed + 31 * li)
		mask = warp_image(mask, dx * 0.2, dy)
		mask = (mask > 0.5).astype(np.float32)
		# Value bands: a rim along the top, a body, a foot; the band edges wobble with a noise.
		depth = (ys - top) / np.maximum(base, 1.0)
		wob = (fbm((h, w), 10, seed + 5 * li, 3) - 0.5) * 0.25
		band = np.digitize(depth + wob, [0.025, 0.55])
		layer = np.zeros((h, w, 3), dtype=np.float32)
		base_col = np.array(col, dtype=np.float32)
		rim = np.array(pal["rim"], dtype=np.float32) * (1.0 - 0.25 * li)
		layer[band == 0] = rim
		layer[band == 1] = base_col
		layer[band == 2] = base_col * 0.72
		# Windows: small lit rectangles in sparse clusters, only on the nearer layers' bodies.
		if li >= 1:
			cell = 11 + 3 * li
			gx, gy = np.meshgrid(np.arange(w), np.arange(h))
			cx, cy = gx // cell, gy // cell
			rr = np.random.default_rng(seed + 100 + li)
			table = rr.random((h // cell + 2, w // cell + 2))
			cluster = fbm((h, w), 18, seed + 200 + li, 2)
			lit = (table[cy, cx] < pal["windows"] * (0.4 + cluster * 1.6)) & ((gx % cell) < cell - 5) & ((gy % cell) < cell - 6) & (band == 1)
			cool = rr.random((h // cell + 2, w // cell + 2)) < pal["cool_share"]
			layer[lit & ~cool[cy, cx]] = pal["window_warm"]
			layer[lit & cool[cy, cx]] = pal["window_cool"]
		m3 = mask[..., None]
		rgb = rgb * (1 - m3) + layer * m3
		alpha = np.maximum(alpha, mask)
	out = np.clip(rgb, 0, 255).astype(np.uint8)
	out = kuwahara(out, 3)
	rgba = np.dstack([out, (alpha * 255).astype(np.uint8)])
	return rgba


def smoke_bank(name, scheme, height, seed):
	"""A floating bank of smoke: billows in three dark values, the underside of each lit by the fire below it."""
	pal = SMOKE[scheme]
	h, w = height, WIDTH
	dx, dy = warp_coords((h, w), 36.0, 5, seed)
	n = fbm((h, w), 3.0, seed + 3, 5, stretch=(1.0, 1.7))
	n = warp_image(n, dx, dy)
	ys = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None]
	layer = 0.5 * (1.0 - np.abs(2.0 * ys - 1.0))  # a layer in the middle of the card
	field = n * 0.75 + layer * 0.9
	thr = 0.62
	mask = (field > thr).astype(np.float32)
	body = np.digitize(field, [thr, thr + 0.07, thr + 0.15])
	rgb = np.zeros((h, w, 3), dtype=np.float32)
	rgb[:] = np.array(pal["bands"][0], dtype=np.float32)
	rgb[body >= 2] = np.array(pal["bands"][1], dtype=np.float32)
	rgb[body >= 3] = np.array(pal["bands"][2], dtype=np.float32)
	# The underlit rim: where the billow ends within 18 px below, the fire lights it.
	below = np.roll(field, -10, axis=0)
	rim = (mask > 0) & (below <= thr + 0.02)
	rgb[rim] = np.array(pal["rim"], dtype=np.float32)
	out = kuwahara(np.clip(rgb, 0, 255).astype(np.uint8), 4)
	alpha = cv2.GaussianBlur(mask, (0, 0), 1.2)
	return np.dstack([out, (alpha * 255).astype(np.uint8)])


def fire_wall(name, height, seed):
	"""A wall of fire: flame tongues in three nested values (red, orange, yellow), the base solid, the tops licking up."""
	h, w = height, WIDTH
	rng = np.random.default_rng(seed)
	xs = np.arange(w, dtype=np.float32)
	prof = np.zeros(w, dtype=np.float32)
	count = 70
	for _ in range(count):
		c = rng.uniform(0, w)
		half = rng.uniform(14, 60)
		hh = rng.uniform(0.35, 1.0) ** 1.3
		lean = rng.uniform(-0.6, 0.6)
		t = (xs - c) / half
		shape = np.clip(1.0 - np.abs(t + lean * np.clip(1 - np.abs(t), 0, 1)), 0.0, 1.0) ** 1.35
		prof = np.maximum(prof, hh * shape)
	prof = np.maximum(prof, 0.18)
	ys = np.linspace(1.0, 0.0, h, dtype=np.float32)[:, None]  # 1 at the bottom, 0 at the top
	dx, dy = warp_coords((h, w), 5.0, 22, seed + 4)
	height_map = np.tile(prof[None, :], (h, 1))
	cover = warp_image((ys <= height_map * 0.96).astype(np.float32), dx, dy)
	core = warp_image((ys <= height_map * 0.72 - 0.04).astype(np.float32), dx * 0.8, dy * 0.8)
	hot = warp_image((ys <= height_map * 0.42 - 0.05).astype(np.float32), dx * 0.6, dy * 0.6)
	rgb = np.zeros((h, w, 3), dtype=np.float32)
	rgb[cover > 0.5] = (196, 52, 26)
	rgb[core > 0.5] = (240, 118, 28)
	rgb[hot > 0.5] = (255, 208, 96)
	out = kuwahara(np.clip(rgb, 0, 255).astype(np.uint8), 3)
	alpha = (cover > 0.5).astype(np.float32)
	return np.dstack([out, (cv2.GaussianBlur(alpha, (0, 0), 1.0) * 255).astype(np.uint8)])


MATTES = {
	"matte_skyline_night": lambda: skyline("night", "night", 384, 11),
	"matte_skyline_dusk": lambda: skyline("dusk", "dusk", 384, 23),
	"matte_smoke_bank": lambda: smoke_bank("smoke", "fire", 512, 5),
	"matte_fire_wall": lambda: fire_wall("fire", 384, 9),
}


def main() -> int:
	ap = argparse.ArgumentParser()
	ap.add_argument("--out", required=True)
	ap.add_argument("--only", default="")
	args = ap.parse_args()
	os.makedirs(args.out, exist_ok=True)
	for name, make in MATTES.items():
		if args.only and args.only not in name:
			continue
		rgba = make()
		bgra = cv2.cvtColor(rgba, cv2.COLOR_RGBA2BGRA)
		path = os.path.join(args.out, name + ".png")
		cv2.imwrite(path, bgra, [cv2.IMWRITE_PNG_COMPRESSION, 9])
		print(f"{path}: {rgba.shape[1]}x{rgba.shape[0]}, {os.path.getsize(path) // 1024} KB")
	return 0


if __name__ == "__main__":
	sys.exit(main())
