"""LD-ASSET's drawn features (Phase 1, docs/video/P1.md): Claude's SVG of a character's face and hands, baked into the ink texture.

The drawing is assets/source/video_art/<name>/features.svg, written by hand over a flat-shaded orthographic render of the mesh
(tools/video/blender_view.py, then `art_paint.py grid` for the millimetre grid). Each `<g data-view="front" data-origin="R U">` is
a view of the character: its coordinates are millimetres on that view's screen, x to the right and y DOWN, 0 at the point (R, U)
metres of the view's right and up axes (art_paint.VIEWS; the character faces +Y, front: right = -X). What a group draws is
PROJECTED onto the surface the viewer sees there and laid down in the UV2 layout the textures are in: each stroke is sampled every
fraction of a millimetre, every sample is mapped to a texel of the baked surface (with the sub-texel offset solved from the
neighbouring texels), and the line is drawn between the samples in UV space, its width in millimetres turned into texels where it
falls, so a line is as wide on the face as it was drawn wherever the layout stretches it. The UV-space result is written out as
features_uv.svg beside it (the drawing as it sits in the layout).

Elements (inherited from the groups): `<path d="M L C Q Z">` with `stroke-width` (mm), `opacity` (the ink's strength, 0..1),
`data-taper="a,b"` (the shares of the length the line thins over at its start and its end), `data-wobble` (mm, the hand's wander,
a smooth noise seeded per stroke), `fill="ink"` with `fill-opacity` for a shape (an eye's pupil, a shadow under a brow).
"""
import re
import xml.etree.ElementTree as ET
import zlib

import cv2
import numpy as np

import art_paint as ap

SAMPLE_MM = 0.3
SUPERSAMPLE = 2
JUMP_TEXELS = 3.5
PX_PER_MM = 4.0
SVG_NS = "{http://www.w3.org/2000/svg}"
DEFAULTS = {"stroke-width": 1.0, "opacity": 1.0, "data-taper": "0.15,0.25", "data-wobble": 0.25, "fill": "none", "fill-opacity": 1.0}


def parse_path(d):
	"""A path's `d` (M L C Q Z, absolute or relative) as a list of subpaths, each a list of (x, y) points, curves flattened."""
	tokens = re.findall(r"[MmLlCcQqZzHhVv]|-?\d*\.?\d+(?:[eE][-+]?\d+)?", d)
	subs, cur, pos, start, i, cmd = [], [], (0.0, 0.0), (0.0, 0.0), 0, None

	def nums(n):
		nonlocal i
		out = [float(t) for t in tokens[i:i + n]]
		i += n
		return out

	while i < len(tokens):
		t = tokens[i]
		if re.match(r"[A-Za-z]", t):
			cmd = t
			i += 1
			if cmd in "Zz":
				if cur:
					cur.append(start)
					subs.append(cur)
					cur = []
				pos = start
				continue
		rel = cmd.islower()
		c = cmd.upper()
		if c == "M":
			x, y = nums(2)
			if rel:
				x, y = pos[0] + x, pos[1] + y
			if cur:
				subs.append(cur)
			cur, pos, start = [(x, y)], (x, y), (x, y)
			cmd = "l" if rel else "L"
		elif c == "L":
			x, y = nums(2)
			if rel:
				x, y = pos[0] + x, pos[1] + y
			cur.append((x, y))
			pos = (x, y)
		elif c == "H":
			(x,) = nums(1)
			pos = (pos[0] + x if rel else x, pos[1])
			cur.append(pos)
		elif c == "V":
			(y,) = nums(1)
			pos = (pos[0], pos[1] + y if rel else y)
			cur.append(pos)
		elif c == "C":
			v = nums(6)
			p = [(v[0], v[1]), (v[2], v[3]), (v[4], v[5])]
			if rel:
				p = [(pos[0] + a, pos[1] + b) for a, b in p]
			cur.extend(bezier([pos] + p))
			pos = p[2]
		elif c == "Q":
			v = nums(4)
			p = [(v[0], v[1]), (v[2], v[3])]
			if rel:
				p = [(pos[0] + a, pos[1] + b) for a, b in p]
			cur.extend(bezier([pos] + p))
			pos = p[1]
		else:
			i += 1
	if cur:
		subs.append(cur)
	return subs


def bezier(pts, steps=24):
	p = np.array(pts, float)
	out = []
	for k in range(1, steps + 1):
		t = k / steps
		q = p.copy()
		while len(q) > 1:
			q = q[:-1] * (1 - t) + q[1:] * t
		out.append((q[0][0], q[0][1]))
	return out


def resample(points, step):
	"""The polyline resampled every `step` (same units), with the arc length parameter 0..1 of each sample."""
	p = np.array(points, float)
	if len(p) < 2:
		return p, np.zeros(len(p))
	seg = np.linalg.norm(np.diff(p, axis=0), axis=1)
	total = seg.sum()
	if total < 1e-9:
		return p[:1], np.zeros(1)
	cum = np.concatenate([[0.0], np.cumsum(seg)])
	n = max(int(total / step), 2)
	s = np.linspace(0.0, total, n + 1)
	x = np.interp(s, cum, p[:, 0])
	y = np.interp(s, cum, p[:, 1])
	return np.stack([x, y], axis=1), s / total


def collect(elem, inherited, out, view):
	"""Walk the svg: (view, attributes, subpaths) for every path, the groups' attributes inherited."""
	attrs = dict(inherited)
	for key in DEFAULTS:
		if key in elem.attrib:
			attrs[key] = elem.attrib[key]
	if "style" in elem.attrib:
		for part in elem.attrib["style"].split(";"):
			if ":" in part:
				k, v = part.split(":", 1)
				if k.strip() in DEFAULTS:
					attrs[k.strip()] = v.strip()
	if "stroke-width" in elem.attrib:
		attrs["stroke-width"] = elem.attrib["stroke-width"]
	tag = elem.tag.replace(SVG_NS, "")
	if tag == "g" and "data-view" in elem.attrib:
		origin = [float(v) for v in elem.attrib["data-origin"].split()]
		view = {"name": elem.attrib["data-view"], "origin": origin, "paths": [], "ppm": float(elem.attrib.get("data-px", PX_PER_MM))}
		out.append(view)
	if tag == "path" and view is not None:
		view["paths"].append((attrs, parse_path(elem.attrib["d"]), elem.attrib.get("id", "")))
	for child in elem:
		collect(child, attrs, out, view)


def noise1d(n, scale_samples, seed):
	rng = np.random.default_rng(seed)
	knots = rng.standard_normal(max(int(n / scale_samples) + 3, 3))
	x = np.linspace(0, len(knots) - 1.001, n)
	i = x.astype(int)
	f = x - i
	f = f * f * (3 - 2 * f)
	return knots[i] * (1 - f) + knots[i + 1] * f


class Projector:
	"""Maps a point of a view's screen (mm) to a UV-layout position (in map texels) and the local size of a texel (mm)."""

	def __init__(self, maps, view):
		self.maps = maps
		self.size = maps["cover"].shape[0]
		right, up, _toward = ap.VIEWS[view["name"]]
		self.right, self.up = right, up
		self.origin = view["origin"]
		self.ppm = view["ppm"]
		pts = [p for _a, subs, _i in view["paths"] for sub in subs for p in sub]
		xs = [p[0] for p in pts]
		ys = [p[1] for p in pts]
		pad = 6.0
		self.x0, self.x1 = min(xs) - pad, max(xs) + pad
		self.y0, self.y1 = min(ys) - pad, max(ys) + pad
		window = (self.origin[0] + self.x0 / 1000.0, self.origin[0] + self.x1 / 1000.0,
			self.origin[1] - self.y1 / 1000.0, self.origin[1] - self.y0 / 1000.0)
		dummy = np.zeros((self.size, self.size, 3), np.float32)
		_img, self.index = ap.splat_view(maps, dummy, view["name"], window, self.ppm)
		self.pos = maps["pos"]
		self.cover = maps["cover"]

	def project(self, x_mm, y_mm):
		"""(u_texels, v_texels, mm_per_texel) or None where the view sees nothing."""
		px = (x_mm - self.x0) * self.ppm
		py = (y_mm - self.y0) * self.ppm
		ix, iy = int(px), int(py)
		if ix < 0 or iy < 0 or iy >= self.index.shape[0] or ix >= self.index.shape[1]:
			return None
		flat = self.index[iy, ix]
		if flat < 0:
			return None
		r, c = divmod(int(flat), self.size)
		if r < 1 or c < 1 or r >= self.size - 1 or c >= self.size - 1:
			return None
		p0 = self.pos[r, c].astype(np.float64)
		dc = (self.pos[r, c + 1].astype(np.float64) - self.pos[r, c - 1]) / 2.0 if self.cover[r, c + 1] and self.cover[r, c - 1] else None
		dr = (self.pos[r + 1, c].astype(np.float64) - self.pos[r - 1, c]) / 2.0 if self.cover[r + 1, c] and self.cover[r - 1, c] else None
		if dc is None or dr is None:
			return None
		target_r = self.origin[0] + x_mm / 1000.0
		target_u = self.origin[1] - y_mm / 1000.0
		d = np.array([target_r - p0 @ self.right, target_u - p0 @ self.up])
		m = np.array([[dc @ self.right, dr @ self.right], [dc @ self.up, dr @ self.up]])
		if abs(np.linalg.det(m)) < 1e-12:
			off = np.zeros(2)
		else:
			off = np.linalg.solve(m, d)
		off = np.clip(off, -2.0, 2.0)
		mm = 1000.0 * (np.linalg.norm(dc) + np.linalg.norm(dr)) / 2.0
		return c + 0.5 + off[0], r + 0.5 + off[1], max(mm, 0.05)


def render(svg_path, maps, meta, ink_size, seed, uv_svg=None):
	"""The features as a float image (ink_size x ink_size, 0..1): see the module doc."""
	tree = ET.parse(svg_path)
	views = []
	collect(tree.getroot(), dict(DEFAULTS), views, None)
	size = maps["cover"].shape[0]
	big = ink_size * SUPERSAMPLE
	k = big / size
	canvas = np.zeros((big, big), np.uint8)
	strokes = []
	uv_lines = []
	for view in views:
		if not view["paths"]:
			continue
		proj = Projector(maps, view)
		for n, (attrs, subs, ident) in enumerate(view["paths"]):
			for si, sub in enumerate(subs):
				width = float(attrs["stroke-width"])
				opacity = float(attrs["opacity"])
				wobble = float(attrs["data-wobble"])
				taper = [float(t) for t in str(attrs["data-taper"]).split(",")]
				fill = attrs["fill"] == "ink"
				pts, t = resample(sub, SAMPLE_MM)
				if len(pts) < 2:
					continue
				rng_seed = seed * 1009 + (zlib.crc32((ident or ("%d_%d" % (n, si))).encode()) & 0xFFFF)
				if wobble > 0:
					pts = pts + np.stack([noise1d(len(pts), 18, rng_seed), noise1d(len(pts), 18, rng_seed + 1)], axis=1) * wobble
				samples = []
				for (x, y), tt in zip(pts, t):
					hit = proj.project(x, y)
					samples.append(None if hit is None else (hit[0] * k, hit[1] * k, hit[2], tt))
				strokes.append((opacity, width, taper, fill, float(attrs["fill-opacity"]), samples, ident))
	strokes.sort(key=lambda s: s[0] if not s[3] else s[0] * s[4])
	for opacity, width, taper, fill, fill_opacity, samples, ident in strokes:
		run = []
		runs = []
		prev = None
		for s in samples:
			if s is None or (prev is not None and np.hypot(s[0] - prev[0], s[1] - prev[1]) > JUMP_TEXELS * k):
				if len(run) > 1:
					runs.append(run)
				run = []
			if s is not None:
				run.append(s)
			prev = s
		if len(run) > 1:
			runs.append(run)
		for run in runs:
			if fill:
				poly = np.array([[s[0], s[1]] for s in run], np.float64)
				cv2.fillPoly(canvas, [np.round(poly * 16).astype(np.int32)], int(round(255 * opacity * fill_opacity)), cv2.LINE_AA, 4)
				uv_lines.append((poly, 0.0, opacity * fill_opacity, True, ident))
				continue
			color = int(round(255 * opacity))
			for a, b in zip(run[:-1], run[1:]):
				tt = (a[3] + b[3]) / 2.0
				thin = 1.0
				if taper[0] > 0:
					thin = min(thin, 0.2 + 0.8 * min(tt / taper[0], 1.0))
				if taper[1] > 0:
					thin = min(thin, 0.2 + 0.8 * min((1.0 - tt) / taper[1], 1.0))
				px_w = max(width * thin / a[2] * k, 1.0)
				cv2.line(canvas, (int(round(a[0] * 16)), int(round(a[1] * 16))), (int(round(b[0] * 16)), int(round(b[1] * 16))),
					color, max(int(round(px_w)), 1), cv2.LINE_AA, 4)
			poly = np.array([[s[0], s[1]] for s in run], np.float64)
			uv_lines.append((poly, float(np.mean([width / s[2] * k for s in run])), opacity, False, ident))
	out = cv2.resize(canvas, (ink_size, ink_size), interpolation=cv2.INTER_AREA).astype(np.float32) / 255.0
	if uv_svg:
		write_uv_svg(uv_svg, uv_lines, ink_size, k)
	return out


def write_uv_svg(path, lines, ink_size, k):
	"""The drawing as it sits in the layout: one polyline (a closed polygon for a fill) per stroke, in ink-texture pixels."""
	scale = ink_size / (ink_size * SUPERSAMPLE)
	with open(path, "w") as f:
		f.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d">\n' % (ink_size, ink_size))
		f.write('<!-- features.svg projected into the UV2 layout by tools/video/art_features.py (generated: edit features.svg) -->\n')
		for poly, width, opacity, fill, ident in lines:
			pts = " ".join("%.1f,%.1f" % (x * scale, y * scale) for x, y in poly[::4])
			if fill:
				f.write('<polygon points="%s" fill="#150e0d" fill-opacity="%.2f"/>\n' % (pts, opacity))
			else:
				f.write('<polyline points="%s" fill="none" stroke="#150e0d" stroke-opacity="%.2f" stroke-width="%.1f" stroke-linecap="round"/>\n'
					% (pts, opacity, max(width * scale, 0.5)))
		f.write("</svg>\n")
