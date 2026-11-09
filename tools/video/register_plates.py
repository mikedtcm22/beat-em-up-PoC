"""Register a Gemini plate to its capture (round 5, R5-PAINT; docs/video/P1.md).

The painting comes back at about 2K and was traced, not copied: its masses sit a few pixels off the blockout's. This resizes it to the capture's size, fits an
affine transform (OpenCV's ECC) of its edges to the blockout's depth edges, warps it, and measures how far the blockout's strong depth edges then sit from the
nearest painted edge. A plate whose strong edges sit more than --max-px off at the 75th percentile is rejected (exit 3) and nothing is installed.

Usage:
  ~/.venvs/beat-em-up-video/bin/python -I tools/video/register_plates.py <painting> <capture dir> <name> <dest dir> <index> [--max-px 8] [--check]
    <capture dir> holds <name>_depth.png and <name>.json (tools/video/plate_capture.sh's); the <name>_blockout.png is only read for the overlay.
    --check: measure and write the overlay, install nothing.
Installs <dest dir>/plate_<index>.png (the registered painting), depth_<index>.png (the capture's depth) and plate_<index>.json (the camera, with the registration's
numbers added). Writes <capture dir>/<name>_register.png: the blockout's depth edges (red) over the registered painting's edges (green).
"""
from __future__ import annotations

import json
import os
import shutil
import sys

import cv2
import numpy as np

STRONG_STEP = 0.15
WORK_SCALE = 0.25


def read_depth_m(path: str, depth_far_m: float) -> np.ndarray:
	rgb = cv2.imread(path, cv2.IMREAD_COLOR)[:, :, ::-1].astype(np.int64)
	value = rgb[:, :, 0] * 256 + rgb[:, :, 1]
	z = value.astype(np.float64) / 65534.0 * depth_far_m
	z[value >= 65535] = depth_far_m * 4.0
	return z


def depth_edges(z: np.ndarray, step: float) -> np.ndarray:
	"""A mask of the pixels on the nearer side of a relative depth step of `step` or more."""
	edge = np.zeros(z.shape, dtype=bool)
	for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
		shifted = np.roll(np.roll(z, dy, axis=0), dx, axis=1)
		edge |= shifted > z * (1.0 + step)
	edge[0, :] = edge[-1, :] = False
	edge[:, 0] = edge[:, -1] = False
	return edge


def painted_edges(image: np.ndarray) -> np.ndarray:
	gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
	gray = cv2.GaussianBlur(gray, (0, 0), 1.6)
	return cv2.Canny(gray, 30, 90) > 0


def blur_map(mask: np.ndarray, sigma: float) -> np.ndarray:
	return cv2.GaussianBlur(mask.astype(np.float32), (0, 0), sigma)


def fit_affine(template: np.ndarray, moving: np.ndarray) -> tuple[np.ndarray, float]:
	"""ECC at a quarter size on blurred edge maps; the warp's translation scaled back. Returns (2x3 warp at full size, the correlation)."""
	small = (int(template.shape[1] * WORK_SCALE), int(template.shape[0] * WORK_SCALE))
	t = cv2.resize(blur_map(template, 3.0), small, interpolation=cv2.INTER_AREA)
	m = cv2.resize(blur_map(moving, 3.0), small, interpolation=cv2.INTER_AREA)
	warp = np.eye(2, 3, dtype=np.float32)
	criteria = (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 200, 1e-6)
	try:
		cc, warp = cv2.findTransformECC(t, m, warp, cv2.MOTION_AFFINE, criteria, None, 5)
	except cv2.error as error:
		print("register: ECC did not converge (%s); identity kept" % str(error).splitlines()[0])
		return np.eye(2, 3, dtype=np.float32), 0.0
	warp = warp.copy()
	warp[:, 2] /= WORK_SCALE
	return warp, float(cc)


def residuals(strong: np.ndarray, painted: np.ndarray) -> np.ndarray:
	"""For each strong blockout edge pixel, the distance in pixels to the nearest painted edge."""
	distance = cv2.distanceTransform((~painted).astype(np.uint8), cv2.DIST_L2, 3)
	return distance[strong]


def main(argv: list[str]) -> int:
	max_px = 8.0
	check = False
	args = []
	i = 0
	while i < len(argv):
		if argv[i] == "--max-px":
			max_px = float(argv[i + 1])
			i += 2
		elif argv[i] == "--check":
			check = True
			i += 1
		else:
			args.append(argv[i])
			i += 1
	if len(args) != 5:
		sys.exit(__doc__)
	painting_path, capture_dir, name, dest, index = args
	with open(os.path.join(capture_dir, "%s.json" % name)) as f:
		camera = json.load(f)
	width, height = camera["size"]
	painting = cv2.imread(painting_path, cv2.IMREAD_COLOR)
	if painting is None:
		sys.exit("register: cannot read %s" % painting_path)
	painting = cv2.resize(painting, (width, height), interpolation=cv2.INTER_LANCZOS4)
	z = read_depth_m(os.path.join(capture_dir, "%s_depth.png" % name), camera["depth_far_m"])
	strong = depth_edges(z, STRONG_STEP)
	template = depth_edges(z, STRONG_STEP / 3.0)
	before = residuals(strong, painted_edges(painting))
	warp, cc = fit_affine(template, painted_edges(painting))
	registered = cv2.warpAffine(painting, warp, (width, height), flags=cv2.INTER_LANCZOS4 | cv2.WARP_INVERSE_MAP, borderMode=cv2.BORDER_REPLICATE)
	after = residuals(strong, painted_edges(registered))
	keep = registered if np.percentile(after, 75) <= np.percentile(before, 75) else painting
	if keep is painting:
		warp = np.eye(2, 3, dtype=np.float32)
		after = before
	p50, p75, p95 = (float(np.percentile(after, q)) for q in (50, 75, 95))
	print("register: %d strong edge pixels; distance to the painted edge, before p50 %.1f p75 %.1f; after p50 %.1f p75 %.1f p95 %.1f px; ECC %.3f"
		% (strong.sum(), np.percentile(before, 50), np.percentile(before, 75), p50, p75, p95, cc))
	overlay = np.zeros((height, width, 3), dtype=np.uint8)
	overlay[:, :, 2] = (cv2.dilate(strong.astype(np.uint8), np.ones((3, 3), np.uint8)) * 255)
	overlay[:, :, 1] = painted_edges(keep).astype(np.uint8) * 255
	cv2.imwrite(os.path.join(capture_dir, "%s_register.png" % name), overlay)
	if p75 > max_px:
		print("register: REJECTED, the strong edges sit %.1f px off at the 75th percentile (limit %.1f)" % (p75, max_px))
		return 3
	if check:
		return 0
	os.makedirs(dest, exist_ok=True)
	cv2.imwrite(os.path.join(dest, "plate_%s.png" % index), keep)
	shutil.copyfile(os.path.join(capture_dir, "%s_depth.png" % name), os.path.join(dest, "depth_%s.png" % index))
	camera["registration"] = {"affine": warp.tolist(), "edge_px_p50": p50, "edge_px_p75": p75, "edge_px_p95": p95, "ecc": cc}
	with open(os.path.join(dest, "plate_%s.json" % index), "w") as f:
		json.dump(camera, f, indent="\t")
	print("register: installed plate_%s in %s" % (index, dest))
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
