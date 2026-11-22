"""M7 T14's paint step for the hero: tools/pipeline/trailer_paint.py (T12's, the Punk's) with one more region rule, for the arms.

	~/.venvs/beat-em-up-video/bin/python -I tools/pipeline/trailer_player_paint.py bake    player <workdir> <outdir> [variant]
	~/.venvs/beat-em-up-video/bin/python -I tools/pipeline/trailer_player_paint.py regions player <workdir> <png> <view> [x0 x1 z0 z1]
	~/.venvs/beat-em-up-video/bin/python -I tools/pipeline/trailer_player_paint.py sheet   player <workdir> <png> <view> <origin_r_m> <origin_u_m> <half_w_mm> <half_h_mm> <px_per_mm>
	~/.venvs/beat-em-up-video/bin/python -I tools/pipeline/trailer_player_paint.py painted player <workdir> <png> <view> [x0 x1 z0 z1]   (PAINT_DIR=<outdir>)

The extra rule key, in assets/source/trailer_art/player/paint.json "rules":
	"along": {"bone": "LeftLowerArm", "t": [0.7, 9.0]}   the texels whose rest-pose position lies between t0 and t1 of that bone's head-to-tail axis
	(t = 0 at the head, 1 at the tail; it runs past 1 onto the hand), so a cuff, a strap and a wrist band are cut by the geometry, one smooth curve,
	not by the staircase of the dominant bone. It combines with "cells", "bones" and "box" like the others (all keys must match).
The rest (shadows, folds, ink, hull, the drawn features.svg) is trailer_paint's, unchanged. Pure numpy (the video session's venv).
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import trailer_paint as tp  # noqa: E402


def region_map(maps, meta, cfg):
	"""trailer_paint.region_map plus the "along" key (see the module doc)."""
	ids = tp.cell_ids(maps)
	names = list(cfg["regions"].keys())
	out = np.full(ids.shape, -1, np.int32)
	cover = maps["cover"]
	pos = maps["pos"].astype(np.float64)
	for rule in cfg["rules"]:
		m = cover.copy()
		if "cells" in rule:
			m &= np.isin(ids, rule["cells"])
		if "bones" in rule:
			m &= np.isin(maps["bone"], [meta["bones"].index(b) for b in rule["bones"]])
		for axis, span in enumerate(rule.get("box", [])):
			if span is None:
				continue
			m &= (pos[..., axis] >= span[0]) & (pos[..., axis] <= span[1])
		for axis, key in enumerate(("nx", "ny", "nz")):
			if key in rule:
				m &= (maps["nrm"][..., axis] >= rule[key][0]) & (maps["nrm"][..., axis] <= rule[key][1])
		if "along" in rule:
			head = np.array(meta["bone_heads"][rule["along"]["bone"]], np.float64)
			tail = np.array(meta["bone_tails"][rule["along"]["bone"]], np.float64)
			axis = tail - head
			length = float(np.linalg.norm(axis))
			t = ((pos - head) @ (axis / length)) / length
			lo, hi = rule["along"]["t"]
			m &= (t >= lo) & (t <= hi)
		out[m] = names.index(rule["region"])
	return out, names


tp.region_map = region_map

if __name__ == "__main__":
	cmd = sys.argv[1]
	if cmd == "bake":
		tp.bake(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5] if len(sys.argv) > 5 else None)
	elif cmd in ("regions", "painted"):
		win = tuple(float(a) for a in sys.argv[6:10]) if len(sys.argv) >= 10 else (-0.5, 0.5, 0.0, 1.85)
		paint = os.path.join(os.environ["PAINT_DIR"], sys.argv[2] + "_paint.png") if cmd == "painted" else None
		tp.regions_preview(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], win, float(os.environ.get("PX_PER_MM", "3.0")), None, paint)
	elif cmd == "sheet":
		# sheet player <workdir> <png> <view> <origin_r_m> <origin_u_m> <half_w_mm> <half_h_mm> <px_per_mm>: the millimetre grid features.svg is drawn on
		# (PAINT_PNG=<paint.png> shows the baked paint and ink under it)
		r, u, hw, hh, ppm = (float(a) for a in sys.argv[6:11])
		win = (r - hw / 1000.0, r + hw / 1000.0, u - hh / 1000.0, u + hh / 1000.0)
		tp.regions_preview(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], win, ppm, (r, u, hw, hh), os.environ.get("PAINT_PNG"))
	else:
		raise SystemExit("unknown command " + cmd)
