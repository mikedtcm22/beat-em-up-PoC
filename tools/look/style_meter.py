"""The style meter (docs/video/PLAN.md §6): scores our frames against docs/video/STYLE.md's ranges.

A guard rail between looks, not the gate: it says which numbers sit outside the references' range
for a location, and by how much. Gates are judged by eye beside the reference frames.

Usage:
  ~/.venvs/beat-em-up-video/bin/python -I tools/look/style_meter.py --location street_night <png> ...
  ~/.venvs/beat-em-up-video/bin/python -I tools/look/style_meter.py --location boss_fire --sequence <folder of pngs>
Locations: street_night, roofs_dusk, boss_fire, closeup (STYLE.md's four target columns; their ranges
are in style_targets.json beside this file). --json <path> also writes the full result.
With --sequence the frames are also checked for flicker: the mean absolute change of L* (whole
frame, 1/8 scale) and of the edge map between consecutive frames. A moving camera raises both; a
still camera with a high edge change means swimming or boiling lines.
"""
from __future__ import annotations

import argparse
import glob
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cv2  # noqa: E402
import numpy as np  # noqa: E402

import style_metrics  # noqa: E402

TARGETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "style_targets.json")
HUE_KEYS = ("dark_hue", "key_hue")


def in_range(key: str, value: float, lo: float, hi: float) -> tuple:
	"""(inside, distance outside in the metric's units). Hue ranges with lo > hi wrap through 0."""
	if key in HUE_KEYS:
		v = value % 360.0
		if lo <= hi:
			inside = lo <= v <= hi
		else:
			inside = v >= lo or v <= hi
		if inside:
			return True, 0.0
		d = min(abs((v - lo + 180.0) % 360.0 - 180.0), abs((v - hi + 180.0) % 360.0 - 180.0))
		return False, d
	if lo <= value <= hi:
		return True, 0.0
	return False, (lo - value) if value < lo else (value - hi)


def score_rule(m: dict, key: str, ranges: list) -> dict:
	"""A rule passes if the value is inside any of its ranges. Its score falls off with the distance
	outside the nearest range, relative to that range's width (hues: relative to 60 degrees)."""
	value = m.get(key)
	if value is None or (isinstance(value, float) and math.isnan(value)):
		return {"key": key, "value": None, "pass": False, "score": 0.0, "ranges": ranges}
	best = (False, float("inf"), ranges[0])
	for lo, hi in ranges:
		inside, d = in_range(key, value, lo, hi)
		if inside:
			best = (True, 0.0, [lo, hi])
			break
		if d < best[1]:
			best = (False, d, [lo, hi])
	inside, d, nearest = best
	width = 60.0 if key in HUE_KEYS else max(abs(nearest[1] - nearest[0]), 1e-6)
	score = 1.0 if inside else max(0.0, 1.0 - d / width)
	return {"key": key, "value": round(float(value), 4), "pass": inside, "score": round(score, 3), "ranges": ranges}


def score_frame(m: dict, rules: dict) -> dict:
	results = []
	for key, ranges in rules.items():
		if key == "any_of":
			# Each entry is {metric: ranges}; the best-scoring alternative counts.
			alts = [score_rule(m, k, r) for alt in ranges for k, r in alt.items()]
			best = max(alts, key=lambda r: r["score"])
			best = dict(best, key="any_of:" + best["key"])
			results.append(best)
		else:
			results.append(score_rule(m, key, ranges))
	total = sum(r["score"] for r in results) / max(len(results), 1)
	return {"score": round(total, 3), "passed": sum(1 for r in results if r["pass"]), "rules": len(results), "detail": results}


def flicker(paths: list) -> dict:
	prev_l = prev_e = None
	dl, de = [], []
	for p in paths:
		img = style_metrics.prepare(style_metrics.load_rgb(p))
		lab = style_metrics.to_lab(img)
		small = cv2.resize(lab[..., 0], (img.shape[1] // 8, img.shape[0] // 8), interpolation=cv2.INTER_AREA)
		l8 = np.clip(lab[..., 0] * 2.55, 0, 255).astype(np.uint8)
		edges = cv2.Canny(cv2.GaussianBlur(l8, (3, 3), 0), style_metrics.CANNY_LOW, style_metrics.CANNY_HIGH) > 0
		if prev_l is not None:
			dl.append(float(np.abs(small - prev_l).mean()))
			de.append(float((edges ^ prev_e).mean()))
		prev_l, prev_e = small, edges
	if not dl:
		return {}
	return {"frames": len(paths), "L_change_mean": round(float(np.mean(dl)), 3), "L_change_max": round(float(np.max(dl)), 3),
		"edge_change_mean": round(float(np.mean(de)), 4), "edge_change_max": round(float(np.max(de)), 4)}


def main() -> None:
	ap = argparse.ArgumentParser()
	ap.add_argument("--location", required=True)
	ap.add_argument("--sequence")
	ap.add_argument("--json")
	ap.add_argument("frames", nargs="*")
	args = ap.parse_args()
	with open(TARGETS) as f:
		targets = json.load(f)
	if args.location not in targets:
		sys.exit(f"unknown location {args.location}; one of {', '.join(k for k in targets if not k.startswith('_'))}")
	rules = targets[args.location]
	paths = list(args.frames)
	if args.sequence:
		paths += sorted(glob.glob(os.path.join(args.sequence, "*.png")))
	out = {"location": args.location, "frames": {}}
	for p in (paths if not args.sequence else paths[:: max(1, len(paths) // 6)]):
		m = style_metrics.measure(style_metrics.load_rgb(p), with_palette=False)
		s = score_frame(m, rules)
		out["frames"][os.path.basename(p)] = s
		misses = ", ".join(f"{r['key']}={r['value']} (want {r['ranges']})" for r in s["detail"] if not r["pass"])
		print(f"{os.path.basename(p)}: score {s['score']:.2f}, {s['passed']}/{s['rules']} in range" + (f"; out: {misses}" if misses else ""))
	if args.sequence:
		out["flicker"] = flicker(paths)
		print(f"flicker: {out['flicker']}")
	if args.json:
		with open(args.json, "w") as f:
			json.dump(out, f, indent=1)


if __name__ == "__main__":
	main()
