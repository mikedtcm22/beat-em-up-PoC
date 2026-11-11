"""M7 T12 shade map (ported from the video session, R4-ART): the designed shadow shape of one character, as a map in the UV2 layout.

	R  the shadow hint, 0..1: where an artist always puts shadow whatever the light does (under the brow and the cheekbone, under the chin
	   and the nose, the underside of a forearm, the hollows). trailer_paint.py thresholds it into the shadow shapes drawn into paint.png.
	G, B  hatch strokes (unused by the Punk: paint.json "shade" "hatch" is empty).
The values live in assets/source/trailer_art/<name>/paint.json "shade" (hint specs, cavity, blur_px). Pure numpy / scipy / opencv.
"""
import numpy as np
import cv2
from scipy import ndimage


def hash2(a, b):
	"""A cheap float hash of two integer-valued float arrays, in 0..1."""
	x = np.sin(a * 127.1 + b * 311.7) * 43758.5453
	return x - np.floor(x)


def smoothstep(e0, e1, x):
	t = np.clip((x - e0) / (e1 - e0 if abs(e1 - e0) > 1e-9 else 1e-9), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def masked_blur(img, mask, sigma):
	m = mask.astype(np.float32)
	num = cv2.GaussianBlur(img * m, (0, 0), sigma)
	den = cv2.GaussianBlur(m, (0, 0), sigma)
	return np.where(den > 1e-3, num / np.maximum(den, 1e-3), 0.0).astype(np.float32)


def bone_mask(maps, meta, names):
	return np.isin(maps["bone"], [meta["bones"].index(n) for n in names])


def hint_map(maps, meta, cfg, curv_s, pxs):
	"""The shadow hint (R): per spec, smoothstep over the surface's alignment with a designed light, plus the concave form's share, blurred."""
	spec = cfg.get("shade", {})
	cover = maps["cover"]
	nrm = maps["nrm"].astype(np.float32)
	out = np.zeros(cover.shape, np.float32)
	for s in spec.get("hint", []):
		light = np.array(s["light"], np.float32)
		light /= np.linalg.norm(light)
		m = bone_mask(maps, meta, s["bones"]) & cover
		aligned = nrm @ light
		h = smoothstep(s.get("from", 0.2), s.get("to", -0.4), aligned) * s.get("amount", 1.0)
		out = np.maximum(out, h * m)
	cavity = spec.get("cavity", 0.0)
	if cavity > 0.0:
		scale = max(float(np.percentile(np.abs(curv_s[cover]), 90)), 1e-3)
		cav = np.clip(-curv_s / scale, 0.0, 1.0) * cavity
		heads = np.zeros(cover.shape, bool)
		for s in spec.get("hint", []):
			heads |= bone_mask(maps, meta, s["bones"])
		out = np.maximum(out, cav * heads * cover)
	out = masked_blur(out, cover, spec.get("blur_px", 12) * pxs)
	return np.clip(out * cover, 0.0, 1.0)


def strokes(maps, meta, ids, cfg, hint, seed, pxs):
	"""The hatch strokes (G) and their thresholds (B) of paint.json "shade" "hatch". Evaluated in bands of rows (a 4096 map's float64
	position array is 400 MB)."""
	spec = cfg.get("shade", {})
	cover = maps["cover"]
	size = cover.shape[0]
	pos_all = maps["pos"]
	g = np.zeros((size, size), np.float32)
	b = np.zeros((size, size), np.float32)
	# the texel's size in mm, for the stroke's anti-aliasing
	sample = pos_all[::8, ::8].astype(np.float64)
	cs = cover[::8, ::8] & np.roll(cover[::8, ::8], -1, 1)
	step = np.linalg.norm(np.roll(sample, -1, 1) - sample, axis=2)[cs] * 1000.0 / 8.0
	mm = max(float(np.median(step)) if step.size else 0.6, 0.15)
	band = 256
	for si, h in enumerate(spec.get("hatch", [])):
		ax = h["axis"]
		if isinstance(ax, str) and ax.startswith("bone:"):
			name = ax.split(":")[1]
			axis = np.array(meta["bone_tails"][name], np.float64) - np.array(meta["bone_heads"][name], np.float64)
		else:
			axis = np.array(ax, np.float64)
		axis /= np.linalg.norm(axis)
		toward = np.array(h["toward"], np.float64)
		# the planes' normal: perpendicular to the axis and to the shadow side, so on the shadow side the planes cut the surface along the axis
		perp = np.cross(toward, axis)
		perp /= np.linalg.norm(perp)
		spacing = h.get("spacing_mm", 4.0)
		width = h.get("width_mm", 1.1)
		seg0, seg1 = h.get("seg_mm", [18.0, 60.0])
		gap = h.get("gap", 0.35)
		min_hint = h.get("min_hint", 0.25)
		sd = seed + 101 * (si + 1)
		bones = [meta["bones"].index(n) for n in h["bones"]]
		for r0 in range(0, size, band):
			sl = slice(r0, min(r0 + band, size))
			m = np.isin(maps["bone"][sl], bones) & cover[sl]
			if h.get("cells") is not None:
				m &= np.isin(ids[sl], h["cells"])
			zone = smoothstep(min_hint, min_hint + 0.25, hint[sl]) * m
			if not zone.any():
				continue
			pos = pos_all[sl].astype(np.float64)
			q = (pos @ perp) * 1000.0 / spacing
			s_mm = (pos @ axis) * 1000.0
			# a stroke's wander: a slow shift of the plane coordinate along the axis, so no stroke is ruler-straight
			wob = np.sin(s_mm / 37.0 + hash2(np.round(q), np.full_like(q, 5.0 + sd)) * 6.28) * 0.18 + np.sin(s_mm / 13.0 + q * 2.1) * 0.06
			qk = q + wob
			k = np.round(qk)
			d_mm = np.abs(qk - k) * spacing
			length = seg0 + (seg1 - seg0) * hash2(k, np.full_like(k, 1.0 + sd))
			offset = hash2(k, np.full_like(k, 2.0 + sd)) * length * 2.0
			u = (s_mm - offset) / (length * 1.5)
			cell = np.floor(u)
			frac = u - cell
			present = hash2(k + cell * 0.37, cell + sd) > gap
			taper = np.sin(np.pi * frac) ** 0.7
			half = 0.5 * width * taper * (0.75 + 0.5 * hash2(k, cell + 3.0 + sd))
			cov = np.clip((half - d_mm) / mm + 0.5, 0.0, 1.0) * present * zone
			thr = 0.12 + 0.8 * hash2(k * 1.7 + cell, cell * 0.61 + 9.0 + sd)
			better = cov > g[sl]
			g[sl] = np.where(better, cov, g[sl])
			b[sl] = np.where(better, thr, b[sl])
	return g, b


def shade_rgb(maps, meta, ids, cfg, curv_s, seed, pxs):
	"""The shade map's three channels, size x size float32 (not padded)."""
	hint = hint_map(maps, meta, cfg, curv_s, pxs)
	g, b = strokes(maps, meta, ids, cfg, hint, seed, pxs)
	return hint, g, b
