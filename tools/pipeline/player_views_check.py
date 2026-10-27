"""The hero's generated views, checked before any Tripo credit is spent (M4 package F-player-art, M4-plan Part C section 7).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/player_views_check.py -- <views dir> <report.json>

Reads hero_front/back/left/right (.png or .jpg) in the folder, and for each: the size, the subject's bounding box (the
pixels that differ from the flat #d9d9d9 ground by more than a threshold), its height, the row of its feet, the share of
ground pixels that are exactly the ground colour, and the colours that dominate the subject (each channel rounded to 32
levels). The checks (M4-plan section 7: same size, subject height within 3%, feet on one row) are written as
`checks`; the script exits 1 when one fails. Only reads the folder; the images are untrusted data opened as pixels.
"""
import json
import os
import sys

import bpy
import numpy as np

GROUND = np.array([217, 217, 217], dtype=np.float64)
DIFF = 24.0  # a pixel is the subject when any channel is this far from the ground (0..255)
HEIGHT_TOLERANCE = 0.03
FEET_TOLERANCE = 0.01  # of the image height
NAMES = ["front", "back", "left", "right"]


def load(path):
	img = bpy.data.images.load(path)
	w, h = img.size
	px = np.empty(w * h * 4, dtype=np.float32)
	img.pixels.foreach_get(px)
	px = px.reshape(h, w, 4)[::-1, :, :3]  # top row first
	# Blender hands back linear values for an sRGB image: convert to 8-bit sRGB
	lin = np.clip(px, 0.0, 1.0)
	srgb = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)
	return np.round(srgb * 255.0), (w, h)


def analyse(path):
	rgb, (w, h) = load(path)
	subject = (np.abs(rgb - GROUND).max(axis=2) > DIFF)
	rows = np.nonzero(subject.any(axis=1))[0]
	cols = np.nonzero(subject.any(axis=0))[0]
	top, bottom, left, right = int(rows.min()), int(rows.max()), int(cols.min()), int(cols.max())
	ground = ~subject
	exact = float((np.abs(rgb[ground] - GROUND).max(axis=1) <= 2).mean())
	pix = (rgb[subject] // 32).astype(np.int64)
	key = pix[:, 0] * 64 + pix[:, 1] * 8 + pix[:, 2]
	vals, counts = np.unique(key, return_counts=True)
	order = np.argsort(-counts)[:8]
	dominant = [{"rgb": [int(v // 64) * 32 + 16, int((v // 8) % 8) * 32 + 16, int(v % 8) * 32 + 16], "share": float(counts[i] / key.size)}
		for i, v in ((i, vals[i]) for i in order)]
	red = ((rgb[..., 0] > 150) & (rgb[..., 0] > rgb[..., 1] * 1.6) & (rgb[..., 0] > rgb[..., 2] * 1.6) & subject)
	return {"size": [w, h], "bbox": [left, top, right, bottom], "height_px": bottom - top + 1, "width_px": right - left + 1,
		"feet_row_px": bottom, "ground_exact_share": exact, "subject_share": float(subject.mean()), "dominant": dominant,
		"red_pixels": int(red.sum())}


def find(folder, name):
	for ext in (".png", ".jpg", ".jpeg"):
		p = os.path.join(folder, "hero_%s%s" % (name, ext))
		if os.path.exists(p):
			return p
	return None


def main():
	argv = sys.argv[sys.argv.index("--") + 1:]
	folder, out = argv[0], argv[1]
	report = {"views": {}, "checks": {}}
	for name in NAMES:
		p = find(folder, name)
		if p is None:
			report["checks"]["has_" + name] = False
			continue
		report["views"][name] = analyse(p)
	views = report["views"]
	ok = True
	if views:
		sizes = {tuple(v["size"]) for v in views.values()}
		report["checks"]["same_size"] = len(sizes) == 1
		heights = [v["height_px"] for v in views.values()]
		spread = (max(heights) - min(heights)) / float(max(heights))
		report["checks"]["height_spread"] = spread
		report["checks"]["height_within_3pct"] = spread <= HEIGHT_TOLERANCE
		feet = [v["feet_row_px"] for v in views.values()]
		h = next(iter(views.values()))["size"][1]
		report["checks"]["feet_spread_px"] = max(feet) - min(feet)
		report["checks"]["feet_on_one_row"] = (max(feet) - min(feet)) <= FEET_TOLERANCE * h
		report["checks"]["no_red"] = all(v["red_pixels"] < 50 for v in views.values())
	for k, v in report["checks"].items():
		if v is False:
			ok = False
	with open(out, "w") as f:
		json.dump(report, f, indent="\t")
		f.write("\n")
	print(json.dumps(report["checks"]))
	for name, v in views.items():
		print("%-6s %dx%d  subject %d px tall, feet row %d, bbox %s, ground exact %.3f, red px %d" % (name, v["size"][0], v["size"][1], v["height_px"], v["feet_row_px"], v["bbox"], v["ground_exact_share"], v["red_pixels"]))
	sys.exit(0 if ok else 1)


main()
