"""Measure frames with style_metrics and write the numbers (docs/video/PLAN.md §6, Phase 0 step 5).

Usage:
  ~/.venvs/beat-em-up-video/bin/python -I tools/video/measure_refs.py --out <metrics.json> \
      [--frames <png> ...] [--set <name>=<folder of pngs> ...]
--frames measures single frames (the gates' reference frames, or ours); --set measures every PNG
in a folder (frames sampled from a whole video) and also writes the median and quartiles of each
number across the set. The JSON holds no pixels. Frames from downloads are only read, as paths.
"""
from __future__ import annotations

import argparse
import glob
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402

import style_metrics  # noqa: E402

SCALARS = ("L_mean", "L_std", "L_p05", "L_p25", "L_p50", "L_p75", "L_p95", "frac_dark", "frac_shadow",
	"frac_mid", "frac_light", "C_mean", "dark_C_mean", "dark_frac_grey", "dark_hue", "key_C_mean", "key_hue",
	"warm_share", "cool_share", "violet_share", "edge_density", "ink_frac", "ink_L_mean", "ink_C_mean",
	"local_std_p50", "local_std_p75", "flat_frac")
HUES = ("dark_hue", "key_hue")


def summarize(rows: list) -> dict:
	"""Median and quartiles of every scalar across rows (hues as circular medians around their mean)."""
	out = {}
	for k in SCALARS:
		vals = np.array([r[k] for r in rows if r.get(k) is not None and not (isinstance(r[k], float) and math.isnan(r[k]))], dtype=np.float64)
		if vals.size == 0:
			continue
		if k in HUES:
			mean = style_metrics.circular_mean_deg(vals, np.ones_like(vals))
			# Unwrap around the circular mean so the quartiles don't straddle 0/360.
			d = (vals - mean + 180.0) % 360.0 - 180.0
			q = np.percentile(d, [25, 50, 75]) + mean
			out[k] = {"p25": round(float(q[0] % 360.0), 1), "p50": round(float(q[1] % 360.0), 1), "p75": round(float(q[2] % 360.0), 1)}
		else:
			q = np.percentile(vals, [25, 50, 75])
			out[k] = {"p25": round(float(q[0]), 4), "p50": round(float(q[1]), 4), "p75": round(float(q[2]), 4)}
	out["n"] = len(rows)
	return out


def main() -> None:
	ap = argparse.ArgumentParser()
	ap.add_argument("--out", required=True)
	ap.add_argument("--frames", nargs="*", default=[])
	ap.add_argument("--set", nargs="*", default=[], dest="sets")
	args = ap.parse_args()
	result = {"frames": {}, "sets": {}}
	for path in args.frames:
		m = style_metrics.measure(style_metrics.load_rgb(path))
		result["frames"][os.path.basename(path)] = style_metrics.round_metrics(m)
		print(f"measured {os.path.basename(path)}", flush=True)
	for spec in args.sets:
		name, folder = spec.split("=", 1)
		rows = []
		for path in sorted(glob.glob(os.path.join(folder, "*.png"))):
			rows.append(style_metrics.measure(style_metrics.load_rgb(path), with_palette=False))
		result["sets"][name] = summarize(rows)
		print(f"measured set {name}: {len(rows)} frames", flush=True)
	with open(args.out, "w") as f:
		json.dump(result, f, indent=1)
	print(f"wrote {args.out}")


if __name__ == "__main__":
	main()
