"""Style metrics for the cinematic video (docs/video/PLAN.md §6, Phase 0 step 5 and the style meter).

One function, `measure(rgb)`, turns a frame into the numbers docs/video/STYLE.md records for the
reference frames, so our frames can be scored against the same numbers. Every frame is first
resized to MEASURE_WIDTH and its bottom SUBTITLE_BAND cropped off (the references' subtitles and
watermarks live there), so the numbers compare across resolutions and ignore text.

Colour is measured in CIE L*a*b* (D65): L* is the value (0 black, 100 white), C* = hypot(a*, b*)
the chroma, and h = atan2(b*, a*) the hue angle in degrees (about 40 red, 70-90 orange to yellow,
135-180 green, 200-260 cyan to blue, 290-330 violet to magenta).

Run with the video venv (numpy, scipy, opencv-python-headless, imageio):
  ~/.venvs/beat-em-up-video/bin/python -I tools/video/measure_refs.py ...
"""
from __future__ import annotations

import math

import cv2
import numpy as np

MEASURE_WIDTH = 1280
SUBTITLE_BAND = 0.10
# Value bands of L*: dark < 20 <= shadow < 40 <= mid < 65 <= light.
VALUE_BANDS = (20.0, 40.0, 65.0)
# "Ink": dark thin strokes, found as the black-hat (closing minus image) of L* above this many
# L* units, with a kernel of INK_KERNEL px at MEASURE_WIDTH.
INK_THRESHOLD = 12.0
INK_KERNEL = 7
# Canny thresholds on the 8-bit L* channel, after a 3x3 blur.
CANNY_LOW = 40
CANNY_HIGH = 120
# Warm hues (degrees of h): red to yellow; cool: cyan to blue-violet.
WARM_HUES = (0.0, 100.0)
COOL_HUES = (180.0, 300.0)
# Pixels below this chroma count as grey for the hue measures.
GREY_CHROMA = 6.0
PALETTE_K = 6
PALETTE_SAMPLES = 20000


def load_rgb(path: str) -> np.ndarray:
	"""An image file as float32 RGB in [0, 1]."""
	bgr = cv2.imread(path, cv2.IMREAD_COLOR)
	if bgr is None:
		raise ValueError(f"cannot read {path}")
	return cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0


def prepare(rgb: np.ndarray) -> np.ndarray:
	"""Resize to MEASURE_WIDTH (area filter) and crop the bottom SUBTITLE_BAND."""
	h, w = rgb.shape[:2]
	nh = int(round(h * MEASURE_WIDTH / w))
	small = cv2.resize(rgb, (MEASURE_WIDTH, nh), interpolation=cv2.INTER_AREA) if w != MEASURE_WIDTH else rgb
	keep = int(round(nh * (1.0 - SUBTITLE_BAND)))
	return np.ascontiguousarray(small[:keep])


def to_lab(rgb: np.ndarray) -> np.ndarray:
	"""float32 RGB in [0, 1] (sRGB) -> L*a*b* with L* in [0, 100]."""
	return cv2.cvtColor(rgb, cv2.COLOR_RGB2Lab)


def circular_mean_deg(angles_deg: np.ndarray, weights: np.ndarray) -> float:
	"""Weighted circular mean of angles in degrees, in [0, 360), or nan when undefined."""
	if angles_deg.size == 0 or float(weights.sum()) <= 0.0:
		return float("nan")
	r = np.radians(angles_deg)
	s = float((np.sin(r) * weights).sum())
	c = float((np.cos(r) * weights).sum())
	if abs(s) < 1e-9 and abs(c) < 1e-9:
		return float("nan")
	return math.degrees(math.atan2(s, c)) % 360.0


def hue_in(h: np.ndarray, lo: float, hi: float) -> np.ndarray:
	return (h >= lo) & (h < hi)


def palette(lab: np.ndarray, k: int = PALETTE_K, seed: int = 7) -> list:
	"""The k main colours (k-means in Lab on a fixed sample), largest first, as hex and weight."""
	flat = lab.reshape(-1, 3)
	rng = np.random.default_rng(seed)
	idx = rng.choice(flat.shape[0], size=min(PALETTE_SAMPLES, flat.shape[0]), replace=False)
	sample = np.ascontiguousarray(flat[idx], dtype=np.float32)
	criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 50, 0.2)
	cv2.setRNGSeed(seed)
	_, labels, centers = cv2.kmeans(sample, k, None, criteria, 3, cv2.KMEANS_PP_CENTERS)
	counts = np.bincount(labels.ravel(), minlength=k).astype(np.float64)
	order = np.argsort(-counts)
	rgb = cv2.cvtColor(centers.reshape(1, -1, 3).astype(np.float32), cv2.COLOR_Lab2RGB).reshape(-1, 3)
	out = []
	for i in order:
		r, g, b = (np.clip(rgb[i], 0.0, 1.0) * 255.0 + 0.5).astype(int)
		out.append({"hex": f"#{r:02x}{g:02x}{b:02x}", "weight": round(float(counts[i] / counts.sum()), 3),
			"L": round(float(centers[i][0]), 1)})
	return out


def measure(rgb: np.ndarray, with_palette: bool = True) -> dict:
	"""The style numbers of one frame (float32 RGB in [0, 1], any size). See the module doc."""
	img = prepare(rgb)
	lab = to_lab(img)
	L = lab[..., 0]
	a = lab[..., 1]
	b = lab[..., 2]
	C = np.hypot(a, b)
	H = np.degrees(np.arctan2(b, a)) % 360.0
	Lf = L.ravel()
	p = np.percentile(Lf, [5, 25, 50, 75, 95])
	d1, d2, d3 = VALUE_BANDS
	n = float(Lf.size)
	m: dict = {
		"L_mean": float(Lf.mean()),
		"L_std": float(Lf.std()),
		"L_p05": float(p[0]), "L_p25": float(p[1]), "L_p50": float(p[2]), "L_p75": float(p[3]), "L_p95": float(p[4]),
		"frac_dark": float((Lf < d1).sum() / n),
		"frac_shadow": float(((Lf >= d1) & (Lf < d2)).sum() / n),
		"frac_mid": float(((Lf >= d2) & (Lf < d3)).sum() / n),
		"frac_light": float((Lf >= d3).sum() / n),
		"L_hist16": [round(float(x), 4) for x in np.histogram(Lf, bins=16, range=(0.0, 100.0))[0] / n],
		"C_mean": float(C.mean()),
	}
	# The darkest third: how saturated the darks are, and their hue.
	t33 = np.percentile(Lf, 33.3)
	dark = L <= t33
	cd = C[dark]
	hd = H[dark]
	m["dark_C_mean"] = float(cd.mean())
	m["dark_frac_grey"] = float((cd < GREY_CHROMA).mean())
	m["dark_hue"] = circular_mean_deg(hd[cd >= GREY_CHROMA], cd[cd >= GREY_CHROMA])
	# The key: the brightest 5%, chroma-weighted hue.
	t95 = p[4]
	bright = L >= t95
	cb = C[bright]
	hb = H[bright]
	m["key_C_mean"] = float(cb.mean())
	m["key_hue"] = circular_mean_deg(hb[cb >= GREY_CHROMA], cb[cb >= GREY_CHROMA])
	# Warm and cool shares of the coloured pixels, weighted by chroma.
	col = C >= GREY_CHROMA
	wsum = float(C[col].sum()) or 1.0
	m["warm_share"] = float(C[col & hue_in(H, *WARM_HUES)].sum() / wsum)
	m["cool_share"] = float(C[col & hue_in(H, *COOL_HUES)].sum() / wsum)
	m["violet_share"] = float(C[col & hue_in(H, 300.0, 360.0)].sum() / wsum)
	# Hue histogram of coloured pixels (12 bins of 30 degrees), weighted by chroma.
	hh = np.histogram(H[col], bins=12, range=(0.0, 360.0), weights=C[col])[0]
	m["hue_hist12"] = [round(float(x), 4) for x in hh / (hh.sum() or 1.0)]
	# Edges and ink.
	L8 = np.clip(L * 2.55, 0, 255).astype(np.uint8)
	edges = cv2.Canny(cv2.GaussianBlur(L8, (3, 3), 0), CANNY_LOW, CANNY_HIGH)
	m["edge_density"] = float((edges > 0).mean())
	kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (INK_KERNEL, INK_KERNEL))
	blackhat = cv2.morphologyEx(L, cv2.MORPH_BLACKHAT, kernel)
	ink = blackhat > INK_THRESHOLD
	m["ink_frac"] = float(ink.mean())
	m["ink_L_mean"] = float(L[ink].mean()) if ink.any() else float("nan")
	m["ink_C_mean"] = float(C[ink].mean()) if ink.any() else float("nan")
	# Flatness: the local standard deviation of L* in 5x5 windows, off the edges.
	mean5 = cv2.blur(L, (5, 5))
	sq5 = cv2.blur(L * L, (5, 5))
	lstd = np.sqrt(np.maximum(sq5 - mean5 * mean5, 0.0))
	off_edge = cv2.dilate(edges, np.ones((3, 3), np.uint8)) == 0
	vals = lstd[off_edge]
	m["local_std_p50"] = float(np.median(vals)) if vals.size else float("nan")
	m["local_std_p75"] = float(np.percentile(vals, 75)) if vals.size else float("nan")
	m["flat_frac"] = float((vals < 1.5).mean()) if vals.size else float("nan")
	if with_palette:
		m["palette"] = palette(lab)
	return m


def round_metrics(m: dict, digits: int = 3) -> dict:
	out = {}
	for k, v in m.items():
		if isinstance(v, float):
			out[k] = None if math.isnan(v) else round(v, digits)
		else:
			out[k] = v
	return out
