"""Style meter over groups of frames: ~/.venvs/beat-em-up-video/bin/python -I tools/look/group_meter.py <dir> [<dir> ...]
Per frame, scores against all four locations (style_targets.json) and keeps the best-fitting one
(a frame only has to match one of the trailer's looks). Prints per group: mean best score, mean
in-range rules, and a count of best locations; plus the mean of each metric."""
import glob, json, os, statistics, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import style_meter, style_metrics
targets = {k: v for k, v in json.load(open(style_meter.TARGETS)).items() if not k.startswith("_")}
for d in sys.argv[1:]:
	res, mets, locs = [], {}, {}
	for p in sorted(glob.glob(os.path.join(d, "*.png")) + glob.glob(os.path.join(d, "*.jpg"))):
		m = style_metrics.measure(style_metrics.load_rgb(p), with_palette=False)
		for k, v in m.items():
			if isinstance(v, (int, float)):
				mets.setdefault(k, []).append(float(v))
		best = max(((style_meter.score_frame(m, r), loc) for loc, r in targets.items()), key=lambda t: t[0]["score"])
		res.append(best[0]); locs[best[1]] = locs.get(best[1], 0) + 1
	print(f"{os.path.basename(d.rstrip('/'))}: n={len(res)} best_score_mean={statistics.mean(r['score'] for r in res):.3f} "
		f"rules_in_range_mean={statistics.mean(r['passed'] / r['rules'] for r in res):.2f} locations={locs}")
	print("   " + " ".join(f"{k}={statistics.mean(v):.3f}" for k, v in mets.items() if k in ("L_mean", "frac_dark", "frac_light", "edge_density", "ink_frac", "local_std_p50", "cool_share", "warm_share")))
