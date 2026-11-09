"""R4-ART's shade map (round 4, docs/video/P1.md "R4-ART"): the designed shadow shape and the form-following hatching of one character.

Round 3's judges read the shading as computed: a noise-threshold terminator, and a triplanar crosshatch of one density over faces and gloves
whatever the form. This makes the two things a drawn figure has instead, as a map in the UV2 layout (`<name>_shade.png`, RGB8):

	R  the shadow hint, 0..1: where an anime artist always puts shadow whatever the light does (under the brow and the cheekbone, under
	   the chin and the nose, the underside of a forearm, the hollows). cine_toon.gdshader subtracts `shade_hint_gain * R` from the light
	   term, so the hard terminator follows the big form and the designed shape, not the polygons.
	G  the hatch strokes' coverage, 0..1: short tapering strokes laid on planes parallel to a direction (a limb's bone axis, or a vertical
	   for a face), cut from the 3D position of each texel, so they run ALONG the form and are continuous over the UV seams.
	B  the stroke's threshold, 0..1: a stroke is drawn only where the shadow is deeper than this, so strokes come in as the shadow deepens
	   and never cross a lit face; the density grows with the depth.

The values live in assets/source/video_art/<name>/paint.json "shade":
	{"hint": [{"bones": [...], "light": [x, y, z], "from": 0.2, "to": -0.4, "amount": 1.0}, ...],   (hint = smoothstep(from, to, n . light))
	 "cavity": 0.5, "blur_px": 12,                                         (the concave form's share, the blur in texels of a 2048 map)
	 "hatch": [{"bones": [...], "cells": [7], "axis": "bone:LeftLowerArm" | [x, y, z], "toward": [x, y, z] (the shadow side),
	            "spacing_mm": 4.0, "width_mm": 1.1, "seg_mm": [18, 60], "min_hint": 0.25, "gap": 0.35}, ...]}
Pure numpy / scipy / opencv (the venv); Blender is not needed here.
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


def marks(maps, meta, ids, cfg, albedo, ink, seed, pxs):
	"""R4-ART: marks that make two copies of one part differ (Ox's two gloves: tell 5, mirrored copies), from paint.json "marks":
	  {"type": "tape", "bone": "RightHand", "cell": 54, "t": [0.0, 0.5], "bands": 3, "band_mm": 7, "gap_mm": 5, "colour": [r, g, b], "slant": 0.15}
	      cloth tape wound round the part: bands across the bone's axis (painted over the albedo, an ink line on each edge).
	  {"type": "scuffs", "bone": "LeftHand", "cell": 54, "amount": 0.5, "colour": [r, g, b], "length_px": 26, "angle_deg": 20}
	      worn, scraped streaks of a lighter colour.
	  {"type": "patch", "bone": "RightHand", "cell": 54, "dir": [x, y, z], "half_mm": [20, 14], "colour": [r, g, b]}
	      a stitched patch at the part's extreme point in `dir`: a flat shape with an ink border and a dashed stitch.
	Returns the new (albedo, ink)."""
	from art_paint import smooth_noise, strokes_noise
	cover = maps["cover"]
	size = cover.shape[0]
	pos = maps["pos"]
	for mi, mk in enumerate(cfg.get("marks", [])):
		bone_i = meta["bones"].index(mk["bone"])
		m = (maps["bone"] == bone_i) & cover
		if mk.get("cell") is not None:
			m &= (ids == mk["cell"])
		if not m.any():
			continue
		colour = np.array(mk.get("colour", [0.7, 0.65, 0.55]), np.float32)
		sd = seed + 1301 + 17 * mi
		kind = mk["type"]
		alpha = np.zeros((size, size), np.float32)
		line = np.zeros((size, size), np.float32)
		if kind == "tape":
			head = np.array(meta["bone_heads"][mk["bone"]], np.float64)
			tail = np.array(meta["bone_tails"][mk["bone"]], np.float64)
			axis = tail - head
			length = float(np.linalg.norm(axis))
			axis /= length
			band, gap = mk.get("band_mm", 7.0), mk.get("gap_mm", 5.0)
			pitch = band + gap
			wobble = (smooth_noise((size, size), 40 * pxs, sd) - 0.5) * mk.get("wobble_mm", 3.0)
			for r0 in range(0, size, 256):
				sl = slice(r0, min(r0 + 256, size))
				v = pos[sl].astype(np.float64) - head
				t = v @ axis
				e1 = np.cross(axis, [0.0, 1.0, 0.0])
				e1 /= np.linalg.norm(e1)
				around = (v - t[..., None] * axis) @ e1
				sm = t * 1000.0 + around * 1000.0 * mk.get("slant", 0.15) + wobble[sl]
				lo, hi = mk["t"][0] * length * 1000.0, mk["t"][1] * length * 1000.0
				within = (sm >= lo) & (sm <= lo + mk.get("bands", 3) * pitch)
				ph = (sm - lo) % pitch
				mm = 0.5 / max(pxs, 0.01)
				inside = np.clip(np.minimum(ph, band - ph) / mm, 0.0, 1.0)
				alpha[sl] = np.where(within & (ph < band), inside, 0.0)
				edge = np.clip(1.0 - np.abs(np.minimum(ph, np.abs(band - ph)) - 0.0) / 1.4, 0.0, 1.0)
				line[sl] = np.where(within & ((ph < 1.4) | (np.abs(ph - band) < 1.4)), 0.85, 0.0)
		elif kind == "scuffs":
			a = strokes_noise((size, size), mk.get("length_px", 26) * pxs, max(int(2 * pxs), 1), mk.get("angle_deg", 20), sd)
			b = smooth_noise((size, size), 70 * pxs, sd + 3)
			alpha = np.clip((a - 0.62) * 9.0, 0.0, 1.0) * np.clip((b - 0.45) * 6.0, 0.0, 1.0) * mk.get("amount", 0.5)
		elif kind == "patch":
			d = np.array(mk["dir"], np.float64)
			d /= np.linalg.norm(d)
			ys, xs = np.nonzero(m)
			proj = pos[ys, xs].astype(np.float64) @ d
			top = np.argsort(proj)[-max(len(proj) // 400, 1):]
			centre = pos[ys[top], xs[top]].astype(np.float64).mean(axis=0)
			head = np.array(meta["bone_heads"][mk["bone"]], np.float64)
			tail = np.array(meta["bone_tails"][mk["bone"]], np.float64)
			u = tail - head
			u -= d * (u @ d)
			u /= np.linalg.norm(u)
			w = np.cross(d, u)
			hx, hy = mk.get("half_mm", [20.0, 14.0])
			for r0 in range(0, size, 256):
				sl = slice(r0, min(r0 + 256, size))
				v = pos[sl].astype(np.float64) - centre
				x = (v @ u) * 1000.0
				y = (v @ w) * 1000.0
				far = (v @ d) * 1000.0 > -25.0
				# a rounded-rectangle patch (a superellipse), the box a little off-square
				r = (np.abs(x / hx) ** 3.0 + np.abs(y / hy) ** 3.0) ** (1.0 / 3.0)
				mm = 0.5 / max(pxs, 0.01)
				alpha[sl] = np.clip((1.0 - r) * hx / mm, 0.0, 1.0) * far
				border = np.clip(1.0 - np.abs(r - 1.0) * hx / 1.6, 0.0, 1.0) * far
				stitch = np.clip(1.0 - np.abs(r - 0.78) * hx / 0.9, 0.0, 1.0) * far * (np.sin(x / 2.2 + y / 2.2) > 0.1)
				line[sl] = np.maximum(border * 0.95, stitch * 0.6)
		alpha *= m
		line *= m
		albedo = albedo * (1.0 - alpha[..., None]) + colour * alpha[..., None]
		ink = np.maximum(ink, line)
	return albedo, ink
