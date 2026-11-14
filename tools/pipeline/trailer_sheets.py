"""M7 G2: align Gemini drawings (a face sheet from the front and from three-quarters) to the mesh, so trailer_paint.py can project them.

	~/.venvs/beat-em-up-video/bin/python -I tools/pipeline/trailer_sheets.py render <name> <workdir> <sheets.json> <outdir>   # the mesh renders the drawings are made over (Gemini's input)
	~/.venvs/beat-em-up-video/bin/python -I tools/pipeline/trailer_sheets.py align  <name> <workdir> <sheets.json> <outdir> [--debug]

assets/source/trailer_art/<name>/sheets.json:
  "landmarks_mm": {name: [x, y]}   points of the mesh in features.svg's front-view millimetres (origin `origin`, x right, y down); each is lifted to 3D on the
                                   surface the front view sees there, then projected into every sheet's view
  "sheets": [{"name", "src" (a Gemini output, relative to assets/source/trailer_art/<name>/), "yaw" (the camera round the head, 0 front), "mirror" (flip the
              drawing first: a three-quarter drawn once serves both sides), "identity" (the drawing was made over the sheet's own render and kept its
              silhouette: resized, not warped), "bones" (the render's mask, "all" or a list, default the file's), "window": [r0, r1, z0, z1] m, "ppm", "points": {landmark: [x, y]} in the
              drawing's 0..1 image coordinates (of the unflipped file)}]
`align` writes <outdir>/sheet_<name>.png: the drawing thin-plate warped into the sheet's view (the pixel grid of `window` at `ppm`), the pixels the warp
takes from outside the drawing filled with the border colour. Pure numpy / scipy / opencv.
"""
import json
import os
import sys

import cv2
import numpy as np
from scipy.interpolate import RBFInterpolator

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import trailer_paint as ap  # noqa: E402
import trailer_project as tp  # noqa: E402

SWAP = {"_l": "_r", "_r": "_l"}


def head_mask(maps, meta, bones):
	return np.isin(maps["bone"], [meta["bones"].index(b) for b in bones])


def lift(maps, mask, origin, ppm, win, pts_mm, view="front"):
	"""3D positions of front-view mm points (lifted through the splat of the view)."""
	dummy = np.zeros(maps["cover"].shape + (3,), np.float32)
	_img, index = tp.render_view(maps, dummy, 0, win, ppm, mask)
	size = maps["cover"].shape[0]
	out = {}
	for k, (x, y) in pts_mm.items():
		px = int((x / 1000.0 + origin[0] - win[0]) * 1000 * ppm)
		py = int((win[3] - (origin[1] - y / 1000.0)) * 1000 * ppm)
		# the nearest surface in a small neighbourhood (a hole in the splat can show a surface far behind it)
		rad = 6
		while True:
			cand = index[max(py - rad, 0):py + rad + 1, max(px - rad, 0):px + rad + 1].ravel()
			cand = cand[cand >= 0]
			if len(cand) or rad > 80:
				break
			rad *= 2
		cr, cc = np.divmod(cand, size)
		best = np.argmax(maps["pos"][cr, cc, 1])
		r, c = int(cr[best]), int(cc[best])
		out[k] = maps["pos"][r, c].astype(np.float64)
	return out


def sheet_window(sheet):
	return tuple(sheet["window"])


def align_sheet(sheet, lm3d, base_dir, debug=None):
	src = cv2.imread(os.path.join(base_dir, sheet["src"]))
	if src is None:
		raise SystemExit("missing " + sheet["src"])
	h, w = src.shape[:2]
	pts = dict(sheet["points"])
	if sheet.get("mirror"):
		src = src[:, ::-1].copy()
		swapped = {}
		for k, (x, y) in pts.items():
			nk = k
			for a, b in SWAP.items():
				if k.endswith(a):
					nk = k[:-2] + b
					break
			swapped[nk] = [1.0 - x, y]
		pts = swapped
	right, up, _t = tp.view_basis(sheet["yaw"])
	win = sheet_window(sheet)
	ppm = sheet["ppm"]
	out_w = int(round((win[1] - win[0]) * 1000 * ppm))
	out_h = int(round((win[3] - win[2]) * 1000 * ppm))
	if sheet.get("identity"):
		# the drawing was made over this very render and kept its silhouette: no warp, just the pixel grid
		return cv2.resize(src, (out_w, out_h), interpolation=cv2.INTER_CUBIC)
	names = [k for k in pts if k in lm3d]
	mesh_px = np.array([[((lm3d[k] @ right) - win[0]) * 1000 * ppm, (win[3] - lm3d[k] @ up) * 1000 * ppm] for k in names])
	draw_px = np.array([[pts[k][0] * w, pts[k][1] * h] for k in names])
	# an affine fit gives the far field; the thin plate does the rest
	A = np.c_[mesh_px, np.ones(len(names))]
	coef, *_ = np.linalg.lstsq(A, draw_px, rcond=None)
	corners = np.array([[0, 0], [out_w, 0], [out_w, out_h], [0, out_h], [out_w / 2, 0], [out_w / 2, out_h], [0, out_h / 2], [out_w, out_h / 2]], float)
	anchor_draw = np.c_[corners, np.ones(len(corners))] @ coef
	X = np.vstack([mesh_px, corners])
	Y = np.vstack([draw_px, anchor_draw])
	tps = RBFInterpolator(X, Y, kernel="thin_plate_spline", smoothing=float(sheet.get("smoothing", 20.0)))
	gx, gy = np.meshgrid(np.arange(out_w, dtype=np.float64) + 0.5, np.arange(out_h, dtype=np.float64) + 0.5)
	m = tps(np.c_[gx.ravel(), gy.ravel()]).reshape(out_h, out_w, 2).astype(np.float32)
	mapx = np.ascontiguousarray(m[..., 0] - 0.5)
	mapy = np.ascontiguousarray(m[..., 1] - 0.5)
	bg = np.median(np.concatenate([src[:20].reshape(-1, 3), src[-20:].reshape(-1, 3)]), axis=0)
	out = cv2.remap(src, mapx, mapy, cv2.INTER_CUBIC, borderMode=cv2.BORDER_CONSTANT, borderValue=[float(v) for v in bg])
	if debug is not None:
		for (x, y), k in zip(mesh_px, names):
			cv2.circle(out, (int(x), int(y)), 6, (0, 0, 255), -1)
			cv2.putText(out, k, (int(x) + 8, int(y) - 8), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 1)
	return out


def landmarks3d(name, maps, meta, spec):
	mask = head_mask(maps, meta, ["Head", "Neck"])
	origin = spec.get("origin", [-0.016, 1.68])
	win = (origin[0] - 0.2, origin[0] + 0.2, origin[1] - 0.25, origin[1] + 0.25)
	return lift(maps, mask, origin, 4.0, win, spec["landmarks_mm"])


def main():
	cmd, name, workdir, sheets_json, outdir = sys.argv[1:6]
	debug = "--debug" in sys.argv
	maps, meta = ap.load_maps(workdir)
	spec = json.load(open(sheets_json))
	base = os.path.dirname(sheets_json)
	os.makedirs(outdir, exist_ok=True)
	if cmd == "render":
		cfg = ap.prepare_config(ap.load_config(name), maps)
		ids, names = ap.region_map(maps, meta, cfg)
		tab = np.array([cfg["regions"][n]["base"] for n in names] + [[0, 0, 0]], np.float32) / 255.0
		lit = ap.lit(maps, tab[ids])
		for s in spec["sheets"]:
			sb = s.get("bones", spec.get("bones", ["Head", "Neck"]))
			mask = maps["cover"] if sb == "all" else head_mask(maps, meta, sb)
			img, _ = tp.render_view(maps, lit, s["yaw"], sheet_window(s), s["ppm"], mask)
			bgm = img.sum(axis=2) == 0
			img8 = (np.clip(img, 0, 1) * 255).astype(np.uint8)
			img8 = cv2.medianBlur(img8[..., ::-1].copy(), 7)
			img8[bgm] = 128
			cv2.imwrite(os.path.join(outdir, "in_%s.png" % s["name"]), img8)
	elif cmd == "align":
		lm = landmarks3d(name, maps, meta, spec)
		for s in spec["sheets"]:
			out = align_sheet(s, lm, base, debug=True if debug else None)
			cv2.imwrite(os.path.join(outdir, "sheet_%s.png" % s["name"]), out)
			print("T-SHEETS aligned", s["name"], out.shape)


if __name__ == "__main__":
	main()
