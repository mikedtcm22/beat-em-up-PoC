"""Check a set of orthographic character views before they go to Tripo (M4 package F-punk, plan Part C section 7 step 1).

	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/views_check.py -- <check.json> <report.json>

Never the Blender MCP; the images are only read as pixels. <check.json> names the views and the mannequin renders they were
drawn on:
	{"ground_rgb": [217, 217, 217], "limits": {...}, "views": {"front": {"image": "view_front.jpg", "mannequin": "<png>"}, ...}}
with paths relative to check.json (the mannequin may be an absolute repo path through ../..). The subject is every pixel
that differs from the ground (estimated from the image's border) by more than limits.ground_tolerance; the report holds,
per view and per mannequin, the subject's bounding box, and the checks:
	- same_size: every view has the same pixel size (the set's; a view and its mannequin may differ, so ratios are in fractions of the image height);
	- height: the subject's height is within limits.height_rel of the mannequin's and of the set's median (3%);
	- feet_row: the subject's lowest row is within limits.feet_row_px of the mannequin's, and the set's within the same band;
	- centred: the subject's horizontal centre is within limits.centre_px of the image's (front and back only);
	- advisory numbers (never failing): the width of the subject at the shoulder, hip and ankle rows and the widest row
	  against the mannequin's (front and back), and the foot gap, so a stance that is wider than the mannequin's is seen.
The exit code is 0 and the verdict is in report.json ("ok" per view and overall), so a caller regenerates the failures.
"""
import json
import os
import sys

import bpy
import numpy as np


def load_rgb(path):
	img = bpy.data.images.load(path, check_existing=False)
	w, h = img.size
	px = np.empty(w * h * 4, dtype=np.float32)
	img.pixels.foreach_get(px)
	px = px.reshape(h, w, 4)[:, :, :3][::-1]  # top row first
	bpy.data.images.remove(img)
	srgb = np.where(px <= 0.0031308, px * 12.92, 1.055 * np.power(np.maximum(px, 0.0), 1 / 2.4) - 0.055)
	return (np.clip(srgb, 0, 1) * 255.0).astype(np.float32)


def subject_mask(rgb, ground, tol):
	"""Subject = differs from the ground by more than tol; the ground is the median of the 12 px border."""
	h, w, _ = rgb.shape
	border = np.concatenate([rgb[:12].reshape(-1, 3), rgb[-12:].reshape(-1, 3), rgb[:, :12].reshape(-1, 3), rgb[:, -12:].reshape(-1, 3)])
	bg = np.median(border, axis=0)
	mask = np.abs(rgb - bg).max(axis=2) > tol
	# drop specks: a row or column needs at least 3 subject pixels to count
	return mask, bg


def bbox(mask):
	rows = np.nonzero(mask.sum(axis=1) >= 3)[0]
	cols = np.nonzero(mask.sum(axis=0) >= 3)[0]
	if len(rows) == 0:
		return None
	return {"top": int(rows[0]), "bottom": int(rows[-1]), "left": int(cols[0]), "right": int(cols[-1]),
		"height": int(rows[-1] - rows[0] + 1), "width": int(cols[-1] - cols[0] + 1)}


def row_span(mask, y):
	xs = np.nonzero(mask[max(0, min(mask.shape[0] - 1, y))])[0]
	return (int(xs[0]), int(xs[-1])) if len(xs) else (0, 0)


def profile(mask, bb):
	"""Subject width at fractions of the subject's height (0 = top), and the widest row."""
	out = {}
	h = bb["height"]
	for name, frac in (("shoulder", 0.19), ("hip", 0.5), ("knee", 0.72), ("ankle", 0.95)):
		y = bb["top"] + int(frac * h)
		a, b = row_span(mask, y)
		out[name] = int(b - a + 1)
	widths = mask.sum(axis=1)
	out["widest"] = int(widths.max())
	# the foot gap: at the ankle row, the longest run of ground between the two legs
	y = bb["top"] + int(0.95 * h)
	row = mask[y]
	xs = np.nonzero(row)[0]
	gap = 0
	if len(xs) > 1:
		d = np.diff(xs)
		gap = int(d.max() - 1)
	out["ankle_gap"] = gap
	return out


def run(check_path, report_path):
	base = os.path.dirname(os.path.abspath(check_path))
	cfg = json.load(open(check_path))
	lim = cfg.get("limits", {})
	tol = float(lim.get("ground_tolerance", 18))
	report = {"limits": lim, "views": {}}
	sizes = set()
	heights, feet = [], []  # fractions of the image height
	for name, spec in cfg["views"].items():
		img_path = os.path.normpath(os.path.join(base, spec["image"]))
		man_path = os.path.normpath(os.path.join(base, spec["mannequin"]))
		img = load_rgb(img_path)
		man = load_rgb(man_path)
		m_mask, bg = subject_mask(img, None, tol)
		mm_mask, mbg = subject_mask(man, None, tol)
		vb, mb = bbox(m_mask), bbox(mm_mask)
		entry = {"size": [int(img.shape[1]), int(img.shape[0])], "mannequin_size": [int(man.shape[1]), int(man.shape[0])],
			"ground_rgb": [int(round(float(c))) for c in bg], "bbox": vb, "mannequin_bbox": mb}
		sizes.add(tuple(entry["size"]))
		# a view and its mannequin may differ in pixel size (Gemini answers 1792x2400, the mannequin is 1536x2048), so every
		# ratio is in fractions of the image's own height
		hv, hm = float(img.shape[0]), float(man.shape[0])
		entry["height_ratio_to_mannequin"] = (vb["height"] / hv) / (mb["height"] / hm)
		entry["feet_row_vs_mannequin_px"] = int(round((vb["bottom"] / hv - mb["bottom"] / hm) * 2048))
		entry["top_row_vs_mannequin_px"] = int(round((vb["top"] / hv - mb["top"] / hm) * 2048))
		entry["centre_offset_px"] = ((vb["left"] + vb["right"]) / 2.0 - img.shape[1] / 2.0) / hv * 2048
		entry["height_frac"] = vb["height"] / hv
		entry["bottom_frac"] = vb["bottom"] / hv
		entry["profile"] = profile(m_mask, vb)
		entry["mannequin_profile"] = profile(mm_mask, mb)
		entry["width_ratio_to_mannequin"] = vb["width"] / mb["width"]
		report["views"][name] = entry
		heights.append(entry["height_frac"])
		feet.append(entry["bottom_frac"])
	med = float(np.median(heights))
	same_size = len(sizes) == 1
	report["same_size"] = same_size
	report["measures_in"] = "pixels of a 2048 px tall image (fractions of the image height times 2048)"
	band = float(lim.get("feet_row_px", 24))
	worst = []
	for name, e in report["views"].items():
		problems = []
		if abs(e["height_ratio_to_mannequin"] - 1.0) > float(lim.get("height_rel", 0.03)):
			problems.append("height %.3f of the mannequin's" % e["height_ratio_to_mannequin"])
		if abs(e["height_frac"] / med - 1.0) > float(lim.get("height_rel", 0.03)):
			problems.append("height %.3f of the set's median" % (e["height_frac"] / med))
		if abs(e["feet_row_vs_mannequin_px"]) > band:
			problems.append("feet %+d px from the mannequin's row" % e["feet_row_vs_mannequin_px"])
		if abs(e["bottom_frac"] - float(np.median(feet))) * 2048 > band:
			problems.append("feet %+d px from the set's median row" % int(round((e["bottom_frac"] - float(np.median(feet))) * 2048)))
		if name in ("front", "back") and abs(e["centre_offset_px"]) > float(lim.get("centre_px", 60)):
			problems.append("off centre by %d px" % e["centre_offset_px"])
		if e["size"] != list(next(iter(sizes))):
			problems.append("size %s is not the set's %s" % (e["size"], next(iter(sizes))))
		e["problems"] = problems
		e["ok"] = not problems
		if problems:
			worst.append(name)
	report["ok"] = same_size and not worst
	report["failed_views"] = worst
	with open(report_path, "w") as f:
		json.dump(report, f, indent="\t")
		f.write("\n")
	for name, e in report["views"].items():
		print("VIEWS %-6s ok=%s height %.3f feet %+dpx width %.2f profile %s | mannequin %s | %s" % (
			name, e["ok"], e["height_ratio_to_mannequin"], e["feet_row_vs_mannequin_px"], e["width_ratio_to_mannequin"],
			e["profile"], e["mannequin_profile"], "; ".join(e["problems"])))
	print("VIEWS overall ok=%s same_size=%s" % (report["ok"], same_size))


if __name__ == "__main__":
	argv = sys.argv[sys.argv.index("--") + 1:]
	run(argv[0], argv[1])
