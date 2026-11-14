"""M7 G2: project a painted raster (a Gemini drawing, cleaned) onto the UV2 paint and ink maps of a baked character.

The mesh's rest-pose position, normal and bone maps (`maps.npz`, from trailer_asset.py) say where every texel of the UV2 layout sits on the body. A raster
drawn over an orthographic render of the body (see `render_view`) is projected back: each texel the view sees (nearest at its pixel, facing the lens) samples the
raster at the pixel its position falls on. Several views blend by how squarely each faces its texels, so a face drawn from the front and from two
three-quarter angles meets without a seam (the drawings are the same face; the blend is a smooth, wide, facing-weighted one).

Also: `flatten_sheet` (turn a Gemini drawing into flat colour classes plus a separate ink layer), and `view_basis` for any yaw.
Pure numpy / scipy / opencv / pillow (the venv). Used by trailer_paint.py's `bake` (paint.json "sheets") and by tools/pipeline/make_trailer_art.sh.
"""
import math
import os
import sys

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import trailer_paint as ap  # noqa: E402


def view_basis(yaw_deg):
	"""(right, up, toward) of a camera `yaw_deg` round the character from the front (0), + toward the character's -X side (the viewer's right)."""
	a = math.radians(yaw_deg)
	toward = np.array([-math.sin(a), math.cos(a), 0.0])
	up = np.array([0.0, 0.0, 1.0])
	right = np.cross(up, toward)
	return right, up, toward


def register_view(name, yaw_deg):
	ap.VIEWS[name] = view_basis(yaw_deg)


def masked_maps(maps, mask):
	"""The maps with `cover` cut to `mask` (so only those texels are splatted and can occlude)."""
	m = dict(maps)
	m["cover"] = maps["cover"] & mask
	return m


def render_view(maps, rgb, yaw_deg, window, ppm, mask=None):
	"""(image, index): the texels' `rgb` splatted in the view of `yaw_deg`; index = flat texel index per pixel (-1 none)."""
	name = "yaw%+d" % int(round(yaw_deg))
	register_view(name, yaw_deg)
	mm = maps if mask is None else masked_maps(maps, mask)
	return ap.splat_view(mm, rgb, name, window, ppm)


def project_views(maps, views, mask, size, winner_k=0.0, vis_ppm=1.5):
	"""views: list of dicts {yaw, window, ppm, image (h, w, C float 0..1), power}. Returns (value (size, size, C), weight (size, size), best facing (size, size)): per texel the
	facing-weighted average of every view that sees it (visible = nearest at its pixel, facing the lens). With `winner_k` > 0 the views do not average: a texel takes the view
	that faces it most squarely, the others weighing exp(k * (their facing - the best facing)), so two drawings of one face never ghost into each other (a narrow seam, not a
	double image). The visibility splat runs at `vis_ppm` at most (a texel is larger than a pixel of a finer splat, and the surface behind then shows through the gaps of the
	front one: the stipple bands of the first bake)."""
	cover = maps["cover"] & mask
	pos = maps["pos"]
	nrm = maps["nrm"].astype(np.float32)
	channels = views[0]["image"].shape[2]
	dummy = np.zeros((size, size, 3), np.float32)
	samples = []
	fmax = np.zeros((size, size), np.float32)
	for v in views:
		right, up, toward = view_basis(v["yaw"])
		vis_win = v["window"]
		vp = min(v["ppm"], vis_ppm)
		_img, index = render_view(maps, dummy, v["yaw"], vis_win, vp, mask)
		visible = np.zeros(size * size, bool)
		idx = index[index >= 0]
		visible[idx] = True
		visible = visible.reshape(size, size) & cover
		facing = np.clip(nrm @ toward.astype(np.float32), 0.0, 1.0)
		ok = visible & (facing > 0.12)
		if v.get("allow") is not None:
			ok &= v["allow"]
		ys, xs = np.nonzero(ok)
		p = pos[ys, xs]
		w0, w1, z0, z1 = v["window"]
		px = ((p @ right - w0) * 1000.0 * v["ppm"])
		py = ((z1 - p @ up) * 1000.0 * v["ppm"])
		img = v["image"]
		h, w = img.shape[:2]
		inside = (px >= 0) & (px < w - 1) & (py >= 0) & (py < h - 1)
		ys, xs, px, py = ys[inside], xs[inside], px[inside], py[inside]
		samp = np.stack([ndimage.map_coordinates(img[..., c], [py - 0.5, px - 0.5], order=1, mode='nearest') for c in range(channels)], axis=1)
		f = facing[ys, xs]
		if "edge" in v:
			f = f * np.clip((f - v["edge"][0]) / max(v["edge"][1] - v["edge"][0], 1e-3), 0.0, 1.0) if winner_k > 0 else f
		samples.append((ys, xs, samp, f, v))
		fmax[ys, xs] = np.maximum(fmax[ys, xs], f)
	acc = np.zeros((size, size, channels), np.float32)
	wsum = np.zeros((size, size), np.float32)
	best = np.zeros((size, size), np.float32)
	for ys, xs, samp, f, v in samples:
		if winner_k > 0:
			wt = np.exp(winner_k * (f - fmax[ys, xs])) * (f > 0.12)
		else:
			wt = (f ** v.get("power", 2.0)) * v.get("gain", 1.0)
			if "edge" in v:
				# fade out toward the view's silhouette: a drawing's contour is not the surface's
				wt = wt * np.clip((f - v["edge"][0]) / max(v["edge"][1] - v["edge"][0], 1e-3), 0.0, 1.0)
		acc[ys, xs] += samp * wt[:, None]
		wsum[ys, xs] += wt
		best[ys, xs] = np.maximum(best[ys, xs], f)
	value = acc / np.maximum(wsum[..., None], 1e-6)
	return value, wsum, best


def planar_island(maps, meta, bones, min_ny, grow_px=3):
	"""The texels of trailer_asset.planar_front's island (the front-facing polygons of `bones` got one planar UV2 island, u = -x, v = z): the largest connected piece
	of those bones' texels whose normal faces the front (`min_ny`), closed and grown by `grow_px`. A drawing made from the front can be laid on it with no stretch."""
	sel = maps["cover"] & np.isin(maps["bone"], [meta["bones"].index(b) for b in bones]) & (maps["nrm"][..., 1] > min_ny)
	sel = ndimage.binary_closing(sel, iterations=2)
	lab, n = ndimage.label(sel)
	if n == 0:
		return np.zeros_like(sel)
	sizes = ndimage.sum(sel, lab, range(1, n + 1))
	island = lab == (1 + int(np.argmax(sizes)))
	if grow_px > 0:
		island = ndimage.binary_dilation(island, iterations=int(grow_px)) & maps["cover"]
	return island


def load_rgb(path, size=None):
	im = Image.open(path).convert("RGB")
	if size is not None:
		im = im.resize(size, Image.LANCZOS)
	return np.asarray(im, np.float32) / 255.0


def flatten_sheet(rgb, ink_cut=0.42, ink_soft=0.10, ink_grow=1, both=False, light_cut=1.45, abs_dark_lum=0.30):
	"""Split a drawn sheet (float RGB 0..1) into (ink 0..1, flat rgb): ink = pixels much darker than the local flat colour (a line is darker than its
	surroundings; a shadow shape is a broad dark area and not a line), the flat image = the sheet with the ink removed (filled from the nearest non-ink pixel)."""
	lum = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
	local = cv2.GaussianBlur(lum, (0, 0), 7.0)
	local = np.maximum(local, cv2.dilate(cv2.GaussianBlur(lum, (0, 0), 3.0), np.ones((15, 15), np.uint8)) * 0.72)
	rel = lum / np.maximum(local, 1e-3)
	abs_dark = np.clip((abs_dark_lum - lum) / 0.12, 0.0, 1.0) if abs_dark_lum > 0 else np.zeros_like(lum)
	ink = np.clip((ink_cut - rel) / ink_soft, 0.0, 1.0)
	if both:
		# lines on a dark ground are drawn lighter than it (a glove's creases): a line is a thin deviation either way from the median of its neighbourhood
		med = cv2.medianBlur(np.clip(lum * 255.0, 0, 255).astype(np.uint8), 31).astype(np.float32) / 255.0
		light = np.clip((lum / np.maximum(med, 0.02) - light_cut) / 0.25, 0.0, 1.0) * np.clip((lum - med) / 0.05, 0.0, 1.0)
		dark = np.clip((0.78 - lum / np.maximum(med, 0.02)) / 0.2, 0.0, 1.0)
		ink = np.maximum(light, dark)
	ink = np.maximum(ink, abs_dark)
	if ink_grow:
		ink = cv2.dilate(ink, np.ones((2 * ink_grow + 1,) * 2, np.uint8))
	hard = ink > 0.5
	dist, idx = ndimage.distance_transform_edt(hard, return_indices=True)
	flat = rgb[idx[0], idx[1]]
	flat = np.where(hard[..., None], flat, rgb)
	return ink.astype(np.float32), flat.astype(np.float32)


def posterize(rgb, mask, k, seed=1):
	"""k-means colours of the masked pixels; returns (label image (-1 outside), centres (k, 3))."""
	pts = rgb[mask].reshape(-1, 3).astype(np.float32)
	if len(pts) > 60000:
		pts = pts[np.random.default_rng(seed).choice(len(pts), 60000, replace=False)]
	crit = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 0.5)
	cv2.setRNGSeed(seed)
	_c, _l, centres = cv2.kmeans(pts, k, None, crit, 3, cv2.KMEANS_PP_CENTERS)
	d = ((rgb[..., None, :] - centres[None, None]) ** 2).sum(-1)
	lab = np.where(mask, d.argmin(-1), -1)
	return lab, centres


def sheet_layers(maps, meta, spec, sheets_json, sheet_dir, size, group=None):
	"""The drawn sheets as texel layers (see trailer_sheets.py): (ink 0..1, flat rgb 0..1, best facing 0..1), best the facing of the view that sees the texel most squarely
	(0 where no view sees it: those texels keep the procedural paint). `spec` is paint.json "sheets"."""
	import json
	sj = json.load(open(sheets_json))
	bones = spec.get("bones", ["Head", "Neck"])
	mask = maps["cover"].copy() if bones == "all" else np.isin(maps["bone"], [meta["bones"].index(b) for b in bones])
	if spec.get("z_range"):
		# only the texels between these heights (rest pose, metres): a drawing's jaw and neck do not sit where the mesh's do, so they are left to the flat paint
		z = maps["pos"][..., 2]
		mask &= (z >= spec["z_range"][0]) & (z <= spec["z_range"][1])
	if spec.get("not_bones"):
		mask &= ~np.isin(maps["bone"], [meta["bones"].index(b) for b in spec["not_bones"]])
	views = []
	island = None
	if spec.get("island"):
		isl = spec["island"]
		island = planar_island(maps, meta, isl.get("bones", ["Head"]), float(isl.get("min_ny", 0.45)), int(isl.get("grow_px", 3)))
	grow_mm = float(spec.get("ink_grow_mm", 1.6))
	for s in sj["sheets"]:
		if spec.get("views") and s["name"] not in spec["views"]:
			continue
		im = cv2.imread(os.path.join(sheet_dir, "sheet_%s.png" % s["name"]))
		if im is None:
			raise SystemExit("missing aligned sheet %s: run trailer_sheets.py align" % s["name"])
		rgb = im[..., ::-1].astype(np.float32) / 255.0
		ink, flat = flatten_sheet(rgb, ink_cut=float(spec.get("ink_cut", 0.42)), ink_grow=int(spec.get("ink_grow_px", 1)), both=bool(spec.get("ink_both", False)), abs_dark_lum=float(spec.get("abs_dark_lum", 0.30)))
		# the drawing's own outer contour is the hull's job (and sits elsewhere on the mesh): drop ink within `edge_cut_mm` of the figure's edge
		bg = np.median(np.concatenate([rgb[:3].reshape(-1, 3), rgb[-3:].reshape(-1, 3), rgb[:, :3].reshape(-1, 3), rgb[:, -3:].reshape(-1, 3)]), axis=0)
		fg = (np.abs(rgb - bg).max(axis=2) > 0.05).astype(np.uint8)
		fg = cv2.morphologyEx(fg, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
		rc = int(round(float(spec.get("edge_cut_mm", 5.0)) * s["ppm"]))
		if rc > 0:
			inner = cv2.erode(fg, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * rc + 1, 2 * rc + 1)), borderValue=0)
			ink = ink * cv2.GaussianBlur(inner.astype(np.float32), (0, 0), 2.0)
		# a hand-drawn face is a few long confident lines: drop the specks and short dashes the threshold leaves of a faint wrinkle
		min_px = int(float(spec.get("min_line_mm2", 40.0)) * s["ppm"] ** 2)
		if min_px > 0:
			n, lab, stats, _c = cv2.connectedComponentsWithStats((ink > 0.5).astype(np.uint8), connectivity=8)
			keep = np.zeros(n, bool)
			keep[1:] = stats[1:, cv2.CC_STAT_AREA] >= min_px
			ink = ink * cv2.dilate(keep[lab].astype(np.float32), np.ones((5, 5), np.uint8))
		r = int(round(grow_mm * s["ppm"]))
		if r > 0:
			k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))
			ink = cv2.dilate(ink, k)
			ink = cv2.GaussianBlur(ink, (0, 0), 0.8)
		img = np.concatenate([ink[..., None], flat], axis=2)
		allow = None
		if island is not None:
			if s["name"] in spec["island"].get("views_in", []):
				allow = island
			elif s["name"] in spec["island"].get("views_out", []):
				allow = ~island
		views.append({"yaw": s["yaw"], "window": tuple(s["window"]), "ppm": s["ppm"], "image": img, "power": float(spec.get("power", 6.0)), "allow": allow})
	value, _w, best = project_views(maps, views, mask, size, float(spec.get("winner_k", 0.0)), float(spec.get("vis_ppm", 1.5)))
	return value[..., 0], value[..., 1:4], (best * (maps["cover"] & mask)).astype(np.float32)
