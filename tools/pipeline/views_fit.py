"""Fit generated orthographic views to the mannequin's frame (M6 HEAVIES; standard library and ffmpeg only).

	python3 -I tools/pipeline/views_fit.py <views_dir>

Gemini draws a heavy a few percent taller than the mannequin (a hood or a helmet adds height, the feet land a few rows low),
which fails views_check.py's height and feet-row bars. This reads <views_dir>/views_report.json (views_check.py's report: the subject's
bounding box per view and the mannequin's), crops each view to its subject, scales the crop so its height is the mannequin's and
puts it back with the soles on the mannequin's feet row and the centre where it was, padded with the view's own ground colour.
The raw view is kept as raw/<name>. Nothing is redrawn: the pixels are only moved and scaled, so no Gemini image is spent.
Run views_check.py again afterwards; the report then says ok.
"""
import json
import os
import shutil
import subprocess
import sys


def ground_at(path: str, x: int, y: int) -> tuple:
	"""The ground colour next to the subject: the mean of an 8 x 8 patch (the report's border estimate can differ from the interior)."""
	raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-vf", "crop=8:8:%d:%d,scale=1:1,format=rgb24" % (x, y),
		"-f", "rawvideo", "-"], check=True, capture_output=True).stdout
	return (raw[0], raw[1], raw[2])


def main(views_dir: str) -> int:
	report = json.load(open(os.path.join(views_dir, "views_report.json")))
	check = json.load(open(os.path.join(views_dir, "views_check.json")))
	raw_dir = os.path.join(views_dir, "raw")
	os.makedirs(raw_dir, exist_ok=True)
	for name, row in report["views"].items():
		image = check["views"][name]["image"]
		src = os.path.join(raw_dir, image)
		if not os.path.exists(src):
			shutil.copy(os.path.join(views_dir, image), src)
		w, h = row["size"]
		mw, mh = row["mannequin_size"]
		box = row["bbox"]
		man = row["mannequin_bbox"]
		scale = (man["height"] / mh * h) / box["height"]
		new_h = round(box["height"] * scale)
		new_w = round(box["width"] * scale)
		bottom = round(man["bottom"] / mh * h)
		top = bottom - new_h
		cx = round((box["left"] + box["right"]) / 2.0)
		left = cx - new_w // 2
		ground = "0x%02x%02x%02x" % ground_at(src, max(0, box["left"] - 16), max(0, box["top"] - 16))
		vf = "crop=%d:%d:%d:%d,scale=%d:%d:flags=lanczos,pad=%d:%d:%d:%d:color=%s" % (
			box["width"], box["height"], box["left"], box["top"], new_w, new_h, w, h, left, top, ground)
		out = os.path.join(views_dir, image)
		subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", src, "-vf", vf, "-q:v", "2", out], check=True)
		print(name, "scale %.4f" % scale, "box", (left, top, new_w, new_h))
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1]))
