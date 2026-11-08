#!/usr/bin/env python3
"""Render one still under a sweep of VideoInkLook values and rank the renders with the style meter
(docs/video/P1.md, LD-INK 5; PLAN.md section 6, "Tuning by measurement"). The lead then looks only at the best few.

    ~/.venvs/beat-em-up-video/bin/python -I tools/video/look_sweep.py --shot fp_punk --location street_night \
        --sweep hull_px=1.6,2.4,3.2 --sweep rim_strength=0.6,0.9,1.2 [--variant look] [--grid] [--max-runs 12] \
        [--out captures/video/ink/sweep] [--top 3] [--dry-run]

A sweep is `property=v1,v2,...` for a property of VideoInkLook (video/ink/video_ink_look.gd); values are GDScript
literals (numbers, true/false, Color(0.1, 0.2, 0.3), Vector3(1, 2, 3); quote nothing, separate values with ';'
if one contains commas, e.g. --sweep "shadow_color=Color(0.2,0.2,0.5);Color(0.3,0.2,0.4)").
Default is one at a time: every other property stays at the .tres's value (plus the unchanged baseline run).
--grid renders the product (capped by --max-runs). Each run is one process of tools/video/shoot_still.sh (about
10 s, under the machine-wide capture lock), through the act "Ink: <shot> <variant>" (video/acts/ld_ink_acts.gd),
which reads INK_LOOK (the location), INK_SET (the overrides) and INK_TAG (the PNG's tag). The frames are scored by
tools/video/style_meter.py against the location's ranges ("closeup" for a close-up shot). The result is printed
ranked (score, rules passed, the numbers outside their range) and written to <out>/sweep.json. Nothing is installed:
the video venv's numpy and OpenCV only.
"""
from __future__ import annotations

import argparse
import itertools
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

CLOSEUP_SHOTS = ("ox_closeup", "fp_punk")


def parse_sweep(text: str) -> tuple:
	name, _, values = text.partition("=")
	if not name or not values:
		raise SystemExit(f"bad --sweep {text!r}: want property=v1,v2")
	sep = ";" if ";" in values else ","
	if sep == "," and "(" in values:
		raise SystemExit(f"--sweep {name}: values with parentheses need ';' between them")
	return name.strip(), [v.strip() for v in values.split(sep) if v.strip()]


def plan_runs(sweeps: list, grid: bool, max_runs: int) -> list:
	"""A list of override dicts: the baseline first, then one-at-a-time or the grid."""
	runs: list = [{}]
	if grid:
		names = [n for n, _ in sweeps]
		for combo in itertools.product(*[v for _, v in sweeps]):
			runs.append(dict(zip(names, combo)))
	else:
		for name, values in sweeps:
			for v in values:
				runs.append({name: v})
	return runs[:max_runs]


def tag_of(overrides: dict) -> str:
	if not overrides:
		return "base"
	safe = []
	for k, v in overrides.items():
		s = "".join(c if c.isalnum() or c in ".-" else "_" for c in v)
		safe.append(f"{k}-{s}")
	return "_".join(safe)[:80]


def main() -> None:
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument("--shot", required=True, help="a still key: fp_punk, ox_closeup, ...")
	ap.add_argument("--location", default="street_night", help="street_night, roofs_dusk or boss_fire (the .tres to start from)")
	ap.add_argument("--variant", default="look", choices=["look", "sketch", "plain"])
	ap.add_argument("--meter-location", default=None, help="the style meter's column (default: closeup for a close-up shot, else --location)")
	ap.add_argument("--sweep", action="append", default=[], help="property=v1,v2,...")
	ap.add_argument("--grid", action="store_true")
	ap.add_argument("--max-runs", type=int, default=12)
	ap.add_argument("--out", default=os.path.join(ROOT, "captures", "video", "ink", "sweep"))
	ap.add_argument("--top", type=int, default=3)
	ap.add_argument("--dry-run", action="store_true", help="print the runs and stop")
	args = ap.parse_args()

	sweeps = [parse_sweep(s) for s in args.sweep]
	runs = plan_runs(sweeps, args.grid, args.max_runs)
	out = os.path.abspath(args.out)
	os.makedirs(out, exist_ok=True)
	if args.dry_run:
		for r in runs:
			print(tag_of(r), r)
		return

	import style_meter  # noqa: E402  (after sys.path)
	import style_metrics  # noqa: E402

	with open(style_meter.TARGETS) as f:
		targets = json.load(f)
	meter_loc = args.meter_location or ("closeup" if args.shot in CLOSEUP_SHOTS and "closeup" in targets else args.location)
	rules = targets[meter_loc]

	results = []
	for overrides in runs:
		tag = tag_of(overrides)
		env = dict(os.environ, INK_LOOK=args.location, INK_TAG=tag, INK_SET=";".join(f"{k}={v}" for k, v in overrides.items()))
		subprocess.run([os.path.join(ROOT, "tools", "video", "shoot_still.sh"), f"Ink: {args.shot} {args.variant}", out],
			env=env, cwd=ROOT, check=False, stdout=subprocess.DEVNULL)
		png = os.path.join(out, f"{args.shot}_{args.variant}_{tag}.png")
		if not os.path.exists(png):
			print(f"{tag}: no frame written (see {out}/shoot.log)")
			continue
		m = style_metrics.measure(style_metrics.load_rgb(png), with_palette=False)
		s = style_meter.score_frame(m, rules)
		misses = {r["key"]: r["value"] for r in s["detail"] if not r["pass"]}
		results.append({"tag": tag, "overrides": overrides, "png": png, "score": s["score"], "passed": s["passed"],
			"rules": s["rules"], "misses": misses})
	results.sort(key=lambda r: -r["score"])
	for i, r in enumerate(results):
		print(f"{i + 1:2d}. {r['score']:.3f}  {r['passed']}/{r['rules']}  {r['tag']}  out: {r['misses']}")
	with open(os.path.join(out, "sweep.json"), "w") as f:
		json.dump({"shot": args.shot, "location": args.location, "meter": meter_loc, "results": results}, f, indent=1)
	print(f"best {args.top}: " + ", ".join(r["png"] for r in results[: args.top]))


if __name__ == "__main__":
	main()
