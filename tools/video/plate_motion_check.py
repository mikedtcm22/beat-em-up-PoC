"""The plate projection's motion check (round 5, R5-PAINT; docs/video/P1.md, item 6): does a projected plate stay on the world while the camera moves?

An UNPAINTED capture of one frame (tools/video/plate_capture.sh <shot> <dir> --frame N --flat: the world's own look, no people) is installed as the shot's
plate (VIDEO_PLATE_DIR) and the shot's neighbouring frames are rendered twice, with the plate quad on and with `--shot-skip=ink.tres,plate.tres` (the world's
own look). A projection that holds gives the same picture twice but for disocclusions, the plate's resampling and what a character casts on the world.
This reads both videos and the character mask, and reports per frame, over the world's pixels (the mask grown by `--grow` px is left out):
  mean   the mean absolute difference, 0..255;
  tear   the share of pixels that differ by more than `--tear` levels;
  static the same two numbers if the capture frame's own picture were pasted on the screen (what "sliding" looks like), as the yardstick.
Writes <out dir>/motion_report.json and a sheet of the difference (the on/off difference at x4) for some frames, and prints a table.

Usage: ~/.venvs/beat-em-up-video/bin/python -I tools/video/plate_motion_check.py <on.mkv> <off.mkv> <mask.mkv> <capture frame index in the video> <out dir>
	[--grow 6] [--tear 24] [--max-mean 4] [--max-tear 0.03]
Exit 3 when a frame's mean or tear exceeds the limits (the capture frame excluded).
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile

import cv2
import numpy as np


def frames(video: str, directory: str, tag: str, scale: int) -> list[str]:
	pattern = os.path.join(directory, tag + "_%03d.png")
	vf = "scale=%d:-1" % scale if scale else "null"
	subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", video, "-vf", vf, "-start_number", "0", pattern], check=True)
	out = []
	index = 0
	while os.path.exists(pattern % index):
		out.append(pattern % index)
		index += 1
	return out


def main(argv: list[str]) -> int:
	grow, tear_level, max_mean, max_tear = 6, 24, 4.0, 0.03
	args = []
	i = 0
	while i < len(argv):
		if argv[i] == "--grow":
			grow = int(argv[i + 1]); i += 2
		elif argv[i] == "--tear":
			tear_level = int(argv[i + 1]); i += 2
		elif argv[i] == "--max-mean":
			max_mean = float(argv[i + 1]); i += 2
		elif argv[i] == "--max-tear":
			max_tear = float(argv[i + 1]); i += 2
		else:
			args.append(argv[i]); i += 1
	if len(args) != 5:
		sys.exit(__doc__)
	on_video, off_video, mask_video, ref_index, out_dir = args[0], args[1], args[2], int(args[3]), args[4]
	os.makedirs(out_dir, exist_ok=True)
	work = tempfile.mkdtemp(prefix="platemotion_", dir=out_dir)
	on = frames(on_video, work, "on", 1280)
	off = frames(off_video, work, "off", 1280)
	mask = frames(mask_video, work, "mask", 1280)
	count = min(len(on), len(off), len(mask))
	still = cv2.imread(off[ref_index]).astype(np.int16)
	rows = []
	worst_mean = worst_tear = 0.0
	sheet = []
	kernel = np.ones((2 * grow + 1, 2 * grow + 1), np.uint8)
	for k in range(count):
		a = cv2.imread(on[k]).astype(np.int16)
		b = cv2.imread(off[k]).astype(np.int16)
		m = cv2.imread(mask[k], cv2.IMREAD_GRAYSCALE)
		world = cv2.dilate((m > 8).astype(np.uint8), kernel) == 0
		d = np.abs(a - b).max(axis=2)
		s = np.abs(still - b).max(axis=2)
		row = {"frame": k, "mean": float(d[world].mean()), "tear": float((d[world] > tear_level).mean()),
			"static_mean": float(s[world].mean()), "static_tear": float((s[world] > tear_level).mean())}
		rows.append(row)
		if k != ref_index:
			worst_mean = max(worst_mean, row["mean"])
			worst_tear = max(worst_tear, row["tear"])
		if k in (0, ref_index, count - 1):
			heat = np.clip(d * 4, 0, 255).astype(np.uint8)
			heat[~world] = 0
			sheet.append(cv2.cvtColor(heat, cv2.COLOR_GRAY2BGR))
	print("frame   mean   tear   | static: mean   tear")
	for row in rows:
		print("%5d %6.2f %6.3f   |        %6.2f %6.3f" % (row["frame"], row["mean"], row["tear"], row["static_mean"], row["static_tear"]))
	print("worst (capture frame excluded): mean %.2f, tear %.3f; limits %.1f, %.3f" % (worst_mean, worst_tear, max_mean, max_tear))
	cv2.imwrite(os.path.join(out_dir, "motion_diff.png"), np.hstack(sheet))
	with open(os.path.join(out_dir, "motion_report.json"), "w") as f:
		json.dump({"rows": rows, "worst_mean": worst_mean, "worst_tear": worst_tear}, f, indent="\t")
	for name in os.listdir(work):
		os.remove(os.path.join(work, name))
	os.rmdir(work)
	return 3 if worst_mean > max_mean or worst_tear > max_tear else 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
