"""Paints the trailer look profile's kit sheets (Milestone 7, T15).

Usage: python3 tools/gen_trailer_kit.py [--check]   (Pillow; not -I, which hides a user-site install)
Writes (from the project folder):
	assets/export/kit/trailer_trim_sheet.png     2048 x 2048 RGBA, the trim sheet of the "trailer" look profile
	assets/export/kit/trailer_ground_sheet.png   2048 x 2048 RGBA, the street's ground tile (8 m a side)
	assets/export/kit/trailer_trim_strips.json   the strip table the game reads (TrimSheet)
`--check` repaints in memory and compares with the committed files (exit 1 when they differ).

The M6 sheets (trim_sheet.png, ground_sheet.png, trim_strips.json) and tools/gen_trim.gd are not touched: this is
a second sheet the look profile selects. Same 16 strips under the same names and rows as M6's (so KitMesh's strip
indices hold under both profiles), but laid out for the trailer's painting: flat wall planes with sparse hand-drawn
brick hints, cracks and drainpipes, a row of eight different window panes (lit and dark), a facade of irregularly
lit windows, a bold chain-link, and a ground of crack lines and puddles, no noise anywhere. The RGB is the surface
(an albedo at mid values: the profile's lights make the night); the ALPHA is the ink mask (cut by the trim shader),
and on the chain-link the wire's coverage.

A strip is 2048 px wide, `u_m` metres of U (so px per metre differs per strip: the table says), and `rows` px high
for `period_m` metres of V. KitMesh reads `u_m` (it scales a face's U so one repeat covers `u_m` instead of
Tuning's kit_trim_m_per_tile), `u_snap_m` (the U offset a variant takes is a multiple of it: one window pane),
`flip` (a variant may mirror U), `vary_v` (a variant may shift V) and `vary_tint` (a variant may nudge the tint): see TrimSheet.variation().

Painting: Gemini was out of credit when this was made (HTTP 402, no image generated), so every tile is drawn here,
by hand-written shapes (Pillow only, at 2x and filtered down, all from fixed seeds: a repaint is identical). Where
a Gemini tile exists in assets/source/trailer_kit/ the same layout would take it instead; none does yet.
"""
import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "export", "kit")
SHEET = os.path.join(OUT, "trailer_trim_sheet.png")
GROUND = os.path.join(OUT, "trailer_ground_sheet.png")
TABLE = os.path.join(OUT, "trailer_trim_strips.json")

W = 2048
SS = 2  # supersampling for the drawing

# Albedo palette (RGB 0-255), mid values and muted: the profile's night light and tinted shadow do the rest.
WALL_A = (112, 124, 148)
WALL_B = (124, 130, 150)
WALL_C = (100, 119, 130)
WALL_D = (114, 117, 140)
BRICK_FILL = (146, 98, 84)
BRICK_FILL_ALT = (132, 88, 78)
PIPE = (128, 136, 152)
OCHRE = (150, 134, 104)
INK_RGB = (28, 30, 48)
LIT = (222, 156, 72)
LIT_DEEP = (190, 118, 56)
LIT_HOT = (240, 196, 112)
DARK_PANE = (52, 66, 100)
DARK_DEEP = (34, 42, 70)
STREAK = (96, 114, 150)
CONCRETE = (124, 130, 146)
CONCRETE_ALT = (110, 116, 134)
PLASTER = (158, 146, 128)
KERB = (132, 136, 150)
KERB_TOP = (156, 152, 150)
TAR = (86, 90, 110)
TAR_ALT = (98, 100, 120)
GRAVEL = (116, 108, 104)
METAL = (104, 114, 134)
METAL_LIGHT = (136, 146, 164)
SHUTTER = (118, 124, 142)
CRATE = (150, 112, 74)
CRATE_ALT = (136, 100, 68)
TRIM = (150, 142, 132)
TRIM_MID = (128, 122, 118)
DARK = (44, 40, 62)
FACADE = (92, 86, 118)
FACADE_ALT = (84, 80, 108)
WIRE = (150, 162, 184)
ASPHALT = (92, 100, 122)
ASPHALT_B = (84, 92, 114)
ASPHALT_C = (102, 108, 128)
PUDDLE = (126, 148, 178)
PUDDLE_HI = (160, 182, 206)

# The sheet's rows, top to bottom: (name, rows px, period_m, u_m, flags). 2048 px in all.
# The M6 rows' order is kept; `u_snap_m`, `flip`, `vary_v` say how a variant may move a face on the strip.
STRIPS = [
	{"name": "brick", "px": 576, "period_m": 3.0, "u_m": 8.0, "flip": True, "vary_v": True, "vary_tint": True},
	{"name": "plaster", "px": 32, "period_m": 0.5, "u_m": 4.0, "flip": True, "vary_v": False, "vary_tint": True},
	{"name": "concrete", "px": 64, "period_m": 1.0, "u_m": 4.0, "flip": True, "vary_v": False, "vary_tint": True},
	{"name": "asphalt", "px": 32, "period_m": 1.0, "u_m": 4.0, "flip": False, "vary_v": False, "ground": True, "vary_tint": False},
	{"name": "kerb", "px": 64, "period_m": 0.5, "u_m": 4.0, "flip": True, "vary_v": False, "vary_tint": True},
	{"name": "roof_tar", "px": 64, "period_m": 1.0, "u_m": 4.0, "flip": True, "vary_v": False, "vary_tint": True},
	{"name": "gravel", "px": 32, "period_m": 0.5, "u_m": 4.0, "flip": True, "vary_v": False, "vary_tint": True},
	{"name": "metal", "px": 64, "period_m": 0.5, "u_m": 4.0, "flip": True, "vary_v": False, "vary_tint": False},
	{"name": "shutter", "px": 64, "period_m": 0.5, "u_m": 4.0, "flip": True, "vary_v": False, "vary_tint": False},
	{"name": "chainlink", "px": 160, "period_m": 0.5, "u_m": 4.0, "flip": False, "vary_v": False, "scissor": True, "vary_tint": False},
	{"name": "crate", "px": 64, "period_m": 0.5, "u_m": 4.0, "flip": True, "vary_v": False, "vary_tint": True},
	{"name": "trim", "px": 64, "period_m": 0.25, "u_m": 4.0, "flip": True, "vary_v": False, "vary_tint": False},
	{"name": "ink", "px": 32, "period_m": 1.0, "u_m": 4.0, "flip": False, "vary_v": False, "ink_only": True, "vary_tint": False},
	{"name": "glass", "px": 384, "period_m": 1.6, "u_m": 8.0, "u_snap_m": 1.0, "flip": False, "vary_v": False, "vary_tint": False},
	{"name": "dark", "px": 32, "period_m": 1.0, "u_m": 4.0, "flip": False, "vary_v": False, "vary_tint": False},
	{"name": "facade", "px": 320, "period_m": 5.0, "u_m": 16.0, "flip": True, "vary_v": True, "vary_tint": True},
]


class Canvas:
	"""A drawing at SS x its size: `rgb` (the surface) and `ink` (the mask), both wrap-drawn so a tile is seamless."""

	def __init__(self, w: int, h: int, base) -> None:
		self.w = w
		self.h = h
		self.rgb = Image.new("RGB", (w * SS, h * SS), base)
		self.ink = Image.new("L", (w * SS, h * SS), 0)
		self.d = ImageDraw.Draw(self.rgb)
		self.i = ImageDraw.Draw(self.ink)

	def wrapped(self, fn, wrap_x: bool = True, wrap_y: bool = True) -> None:
		"""Calls fn(dx, dy) for every wrap offset (in 1x px) so a shape crossing an edge reappears on the far side."""
		for oy in ((-1, 0, 1) if wrap_y else (0,)):
			for ox in ((-1, 0, 1) if wrap_x else (0,)):
				fn(ox * self.w, oy * self.h)

	def poly(self, pts, fill=None, ink: int = 0, wrap: bool = True) -> None:
		def go(dx: float, dy: float) -> None:
			p = [((x + dx) * SS, (y + dy) * SS) for x, y in pts]
			if fill is not None:
				self.d.polygon(p, fill=fill)
			if ink:
				self.i.polygon(p, fill=255)
		self.wrapped(go) if wrap else go(0, 0)

	def rect(self, x0, y0, x1, y1, fill=None, wrap: bool = True) -> None:
		self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], fill=fill, wrap=wrap)

	def ellipse(self, cx, cy, rx, ry, fill, ink_width: float = 0.0, ink_rgb=None) -> None:
		def go(dx: float, dy: float) -> None:
			box = ((cx + dx - rx) * SS, (cy + dy - ry) * SS, (cx + dx + rx) * SS, (cy + dy + ry) * SS)
			self.d.ellipse(box, fill=fill)
			if ink_width > 0:
				self.i.ellipse(box, outline=255, width=int(ink_width * SS))
		self.wrapped(go)

	def line(self, pts, width: float, ink: bool = True, rgb=None, wrap: bool = True) -> None:
		"""A polyline of constant `width` (1x px): into the ink mask, or into the surface when `rgb` is given."""
		def go(dx: float, dy: float) -> None:
			p = [((x + dx) * SS, (y + dy) * SS) for x, y in pts]
			if ink:
				self.i.line(p, fill=255, width=int(width * SS), joint="curve")
			if rgb is not None:
				self.d.line(p, fill=rgb, width=int(width * SS), joint="curve")
		self.wrapped(go) if wrap else go(0, 0)

	def tapered(self, pts, w0: float, w1: float, ink: bool = True, rgb=None, wrap: bool = True) -> None:
		"""A line whose width runs from w0 to w1 along it (the trailer's tapered ink)."""
		n = len(pts) - 1
		for k in range(n):
			a = pts[k]
			b = pts[k + 1]
			wa = w0 + (w1 - w0) * k / n
			wb = w0 + (w1 - w0) * (k + 1) / n
			dx = b[0] - a[0]
			dy = b[1] - a[1]
			ln = math.hypot(dx, dy) or 1.0
			nx = -dy / ln
			ny = dx / ln
			quad = [(a[0] + nx * wa * 0.5, a[1] + ny * wa * 0.5), (b[0] + nx * wb * 0.5, b[1] + ny * wb * 0.5),
				(b[0] - nx * wb * 0.5, b[1] - ny * wb * 0.5), (a[0] - nx * wa * 0.5, a[1] - ny * wa * 0.5)]
			def go(ox: float, oy: float, quad=quad, a=a, b=b, wa=wa, wb=wb) -> None:
				p = [((x + ox) * SS, (y + oy) * SS) for x, y in quad]
				if ink:
					self.i.polygon(p, fill=255)
					self.i.ellipse(((a[0] + ox - wa * 0.5) * SS, (a[1] + oy - wa * 0.5) * SS, (a[0] + ox + wa * 0.5) * SS, (a[1] + oy + wa * 0.5) * SS), fill=255)
				if rgb is not None:
					self.d.polygon(p, fill=rgb)
			self.wrapped(go) if wrap else go(0, 0)

	def done(self) -> Image.Image:
		rgb = self.rgb.resize((self.w, self.h), Image.LANCZOS)
		ink = self.ink.resize((self.w, self.h), Image.LANCZOS)
		out = rgb.convert("RGBA")
		out.putalpha(ink)
		return out


def wobble(rng: random.Random, pts, amount: float):
	"""Hand-drawn: each point nudged a little, deterministic."""
	return [(x + (rng.random() - 0.5) * amount, y + (rng.random() - 0.5) * amount) for x, y in pts]


def crack(rng: random.Random, c: Canvas, x: float, y: float, angle: float, length: float, w0: float, w1: float, branches: int, depth: int = 0) -> None:
	"""A tapered, kinked crack, with `branches` thinner children."""
	pts = [(x, y)]
	steps = max(int(length / 22), 3)
	px, py, a = x, y, angle
	for _ in range(steps):
		a += (rng.random() - 0.5) * 0.7
		px += math.cos(a) * length / steps
		py += math.sin(a) * length / steps
		pts.append((px, py))
	c.tapered(pts, w0, w1)
	for k in range(branches):
		j = 1 + int(rng.random() * (len(pts) - 2))
		side = 1.0 if rng.random() < 0.5 else -1.0
		if depth < 1:
			crack(rng, c, pts[j][0], pts[j][1], a + side * (0.6 + rng.random() * 0.5), length * (0.25 + rng.random() * 0.2), max(w1 * 1.2, 5.0), 5.0, 0, depth + 1)


def brick_patch(rng: random.Random, c: Canvas, cx: float, cy: float, cols: int, rows: int, bw: float, bh: float, fill, fill_alt, fill_ratio: float = 0.55) -> None:
	"""Sparse brick hints: an irregular patch of courses, about half its bricks filled, every one outlined."""
	for r in range(rows):
		off = (bw * 0.5) if r % 2 else 0.0
		for k in range(cols):
			# a ragged edge: some bricks of a course are missing at either end
			if (k == 0 and rng.random() < 0.5) or (k == cols - 1 and rng.random() < 0.5):
				continue
			x0 = cx - cols * bw * 0.5 + k * bw + off + (rng.random() - 0.5) * 3
			y0 = cy - rows * bh * 0.5 + r * bh + (rng.random() - 0.5) * 2
			if rng.random() < fill_ratio:
				c.rect(x0, y0, x0 + bw - 3, y0 + bh - 3, fill=(fill if rng.random() < 0.6 else fill_alt), wrap=False)
			outline = [(x0, y0), (x0 + bw - 3, y0 + (rng.random() - 0.5) * 2), (x0 + bw - 3, y0 + bh - 3), (x0 + (rng.random() - 0.5) * 2, y0 + bh - 3), (x0, y0)]
			c.line(outline, 5.5, wrap=False)


def pipe(c: Canvas, x: float, y0: float, y1: float, width: float, clamps) -> None:
	"""A vertical drainpipe: a lit body, a darker side, ink outline, bracket clamps."""
	c.rect(x - width / 2, y0, x + width / 2, y1, fill=PIPE, wrap=False)
	c.rect(x + width * 0.12, y0, x + width / 2, y1, fill=(104, 112, 130), wrap=False)
	c.line([(x - width / 2, y0), (x - width / 2, y1)], 6.0, wrap=False)
	c.line([(x + width / 2, y0), (x + width / 2, y1)], 6.0, wrap=False)
	for cy in clamps:
		c.rect(x - width * 0.72, cy - 9, x + width * 0.72, cy + 9, fill=(118, 126, 144), wrap=False)
		c.line([(x - width * 0.72, cy - 9), (x + width * 0.72, cy - 9)], 5.0, wrap=False)
		c.line([(x - width * 0.72, cy + 9), (x + width * 0.72, cy + 9)], 5.0, wrap=False)


def paint_brick() -> Image.Image:
	"""Four bays of wall, each 512 px (2 m) of an 8 m strip, in related tones, joined by soft blends."""
	h = 576
	rng = random.Random(1101)
	c = Canvas(W, h, WALL_A)
	bays = [WALL_A, WALL_B, WALL_C, WALL_D]
	for k, col in enumerate(bays):
		x0 = k * 512
		c.rect(x0, 0, x0 + 512, h, fill=col)
	# soft joins between bays (and the wrap): 36 px ramps of stepped tones, painted flat, not a gradient
	for k in range(4):
		a = bays[k]
		b = bays[(k + 1) % 4]
		x = (k + 1) * 512
		for s in range(6):
			t = (s + 0.5) / 6.0
			col = tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))
			c.rect(x - 18 + s * 6, 0, x - 18 + (s + 1) * 6, h, fill=col)
	# flat tone patches (damp, repaint), no outline
	for k in range(7):
		x = 40 + rng.random() * (W - 80)
		y = 60 + rng.random() * (h - 120)
		rx = 60 + rng.random() * 110
		ry = 30 + rng.random() * 60
		base = bays[int(x // 512) % 4]
		shade = tuple(max(0, min(255, int(v * (0.93 if rng.random() < 0.6 else 1.06)))) for v in base)
		c.poly(wobble(rng, [(x - rx, y), (x - rx * 0.4, y - ry), (x + rx * 0.5, y - ry * 0.8), (x + rx, y + ry * 0.2), (x + rx * 0.2, y + ry), (x - rx * 0.6, y + ry * 0.7)], 14), fill=shade, wrap=False)
	# bay 0: brick patch where the plaster fell, a downpipe, a hairline crack
	brick_patch(rng, c, 190, 400, 5, 6, 56, 26, BRICK_FILL, BRICK_FILL_ALT)
	pipe(c, 452, 0, h, 34, [100, 290, 470])
	crack(rng, c, 110, 90, 0.9, 150, 5.5, 5.0, 1)
	# bay 1: a big fallen patch low on the wall, a long diagonal crack
	c.poly(wobble(rng, [(560, 470), (640, 380), (760, 360), (870, 410), (900, 520), (700, 540)], 10), fill=(140, 124, 112), wrap=False)
	brick_patch(rng, c, 730, 450, 6, 5, 52, 24, BRICK_FILL_ALT, BRICK_FILL, 0.4)
	crack(rng, c, 800, 70, 1.5, 260, 6.5, 5.0, 2)
	# bay 2: a rusty bracket with a cable looping from it, two corner brick hints
	c.rect(1130, 150, 1190, 176, fill=(120, 84, 64), wrap=False)
	c.line([(1130, 150), (1190, 150), (1190, 176), (1130, 176), (1130, 150)], 5.5, wrap=False)
	c.line([(1190, 163), (1240, 200), (1262, 300), (1230, 400), (1250, 470)], 5.5, wrap=False)
	brick_patch(rng, c, 1100, 470, 4, 3, 52, 24, BRICK_FILL, BRICK_FILL_ALT, 0.35)
	brick_patch(rng, c, 1400, 90, 3, 3, 52, 24, BRICK_FILL_ALT, BRICK_FILL, 0.3)
	# bay 3: a few courses of brick drawn in an otherwise flat wall, a bent pipe, a vertical crack
	for r in range(3):
		y0 = 250 + r * 28
		x = 1600 + (r % 2) * 22
		while x < 1900:
			if rng.random() < 0.8:
				c.line([(x, y0), (x + 52, y0 + (rng.random() - 0.5) * 2), (x + 52, y0 + 25), (x, y0 + 25), (x, y0)], 5.5, wrap=False)
				if rng.random() < 0.5:
					c.rect(x, y0, x + 52, y0 + 25, fill=BRICK_FILL_ALT, wrap=False)
			x += 56 + rng.random() * 8
	c.line([(1960, 0), (1960, 330), (1930, 360)], 6.0, rgb=PIPE, wrap=False)
	c.line([(1960, 330), (1930, 360), (1850, 360)], 8.0, rgb=PIPE, wrap=False)
	c.line([(1960, 0), (1960, 330), (1930, 360), (1850, 360)], 14.0, wrap=False)
	c.line([(1960, 0), (1960, 330), (1930, 360), (1850, 360)], 8.0, ink=False, rgb=PIPE, wrap=False)
	crack(rng, c, 1700, 480, -1.7, 150, 6.0, 5.0, 1)
	return c.done()


def pane(c: Canvas, x0: int, h: int, kind: int) -> None:
	"""One 1 m x 1.6 m window pane (256 x h px), the bottom of the cell at the bottom of the row."""
	w = 256
	y0 = 0
	cell_bg = {0: LIT, 1: LIT, 2: LIT, 3: DARK_PANE, 4: DARK_PANE, 5: DARK_PANE, 6: (170, 130, 76), 7: DARK_DEEP}[kind]
	c.rect(x0, y0, x0 + w, y0 + h, fill=cell_bg, wrap=False)
	# a 7 px frame of dark (the kit's own frame boards cover the border on a window piece)
	for rect in [(x0, 0, x0 + 7, h), (x0 + w - 7, 0, x0 + w, h), (x0, 0, x0 + w, 7), (x0, h - 7, x0 + w, h)]:
		c.rect(*rect, fill=DARK_DEEP, wrap=False)
	if kind == 0:  # lit, the curtain's edge down one side and a hot centre
		c.poly([(x0 + 20, 14), (x0 + 120, 14), (x0 + 100, 260), (x0 + 20, 330)], fill=LIT_DEEP, wrap=False)
		c.ellipse(x0 + 168, 160, 52, 90, LIT_HOT)
		c.line([(x0 + 120, 14), (x0 + 100, 260)], 3.0, ink=False, rgb=(120, 70, 40), wrap=False)
	elif kind == 1:  # lit with the blinds half drawn
		for k in range(9):
			y = 14 + k * 22
			c.rect(x0 + 10, y, x0 + w - 10, y + 12, fill=LIT_DEEP, wrap=False)
		c.rect(x0 + 10, 190, x0 + w - 10, h - 10, fill=LIT_HOT, wrap=False)
	elif kind == 2:  # lit, a lamp's silhouette on the sill
		c.ellipse(x0 + 128, 150, 80, 110, LIT_HOT)
		c.poly([(x0 + 100, 40), (x0 + 156, 40), (x0 + 170, 110), (x0 + 86, 110)], fill=(118, 72, 44), wrap=False)
		c.rect(x0 + 122, 110, x0 + 134, 200, fill=(118, 72, 44), wrap=False)
		c.rect(x0 + 100, 200, x0 + 156, 214, fill=(118, 72, 44), wrap=False)
	elif kind == 3:  # dark, two pale reflection streaks
		c.poly([(x0 + 40, 14), (x0 + 90, 14), (x0 + 30, 200), (x0 + 12, 200)], fill=STREAK, wrap=False)
		c.poly([(x0 + 110, 14), (x0 + 130, 14), (x0 + 70, 200), (x0 + 56, 200)], fill=STREAK, wrap=False)
	elif kind == 4:  # dark, a cracked corner
		c.poly([(x0 + 7, 7), (x0 + 120, 7), (x0 + 7, 150)], fill=(66, 80, 116), wrap=False)
		c.tapered([(x0 + 140, 8), (x0 + 120, 80), (x0 + 150, 140), (x0 + 110, 220), (x0 + 90, 300)], 4.0, 1.5, ink=False, rgb=(150, 164, 196), wrap=False)
	elif kind == 5:  # dark, a flat curtain drawn across
		c.poly([(x0 + 7, 7), (x0 + w - 7, 7), (x0 + w - 7, 230), (x0 + 130, 250), (x0 + 7, 220)], fill=(84, 78, 120), wrap=False)
		c.line([(x0 + 70, 10), (x0 + 60, 230)], 3.0, ink=False, rgb=(60, 56, 92), wrap=False)
		c.line([(x0 + 150, 10), (x0 + 156, 245)], 3.0, ink=False, rgb=(60, 56, 92), wrap=False)
	elif kind == 6:  # dim lit, plants on the sill
		c.ellipse(x0 + 128, 130, 90, 120, (196, 150, 90))
		for px, ph in [(60, 90), (96, 60), (160, 100), (196, 70)]:
			c.poly([(x0 + px - 14, 10), (x0 + px, 10 + ph), (x0 + px + 14, 10)], fill=(70, 100, 78), wrap=False)
	else:  # black, a faint streak
		c.poly([(x0 + 150, 14), (x0 + 180, 14), (x0 + 110, 210), (x0 + 92, 210)], fill=(52, 60, 92), wrap=False)


def paint_glass() -> Image.Image:
	h = 384
	c = Canvas(W, h, DARK_DEEP)
	for k in range(8):
		pane(c, k * 256, h, k)
	return c.done()


def paint_facade() -> Image.Image:
	h = 320
	rng = random.Random(1303)
	c = Canvas(W, h, FACADE)
	for k in range(9):
		x = rng.random() * W
		c.rect(x, 0, x + 120 + rng.random() * 200, h, fill=(FACADE_ALT if k % 2 == 0 else (96, 90, 122)))
	for floor in range(2):
		top = floor * 160
		x = 24.0
		while x < W - 90:
			wpx = 84 + rng.random() * 18
			hpx = 92 + rng.random() * 12
			y = top + 30 + rng.random() * 8
			roll = rng.random()
			if roll < 0.34:
				fill = LIT if rng.random() < 0.6 else (200, 138, 66)
			elif roll < 0.48:
				fill = (150, 112, 68)
			else:
				fill = DARK_PANE if rng.random() < 0.7 else DARK_DEEP
			c.rect(x, y, x + wpx, y + hpx, fill=fill, wrap=False)
			if roll < 0.48 and rng.random() < 0.6:
				c.rect(x, y, x + wpx, y + hpx * (0.25 + rng.random() * 0.3), fill=LIT_DEEP, wrap=False)
			c.line([(x, y), (x + wpx, y), (x + wpx, y + hpx), (x, y + hpx), (x, y)], 5.5, wrap=False)
			c.line([(x + wpx / 2, y), (x + wpx / 2, y + hpx)], 3.0, ink=False, rgb=DARK_DEEP, wrap=False)
			c.rect(x - 6, y + hpx, x + wpx + 6, y + hpx + 9, fill=(120, 112, 136), wrap=False)
			x += wpx + 34 + rng.random() * 56
	for k in range(5):
		cx = 80 + rng.random() * (W - 160)
		cy = 40 + rng.random() * 240
		brick_patch(rng, c, cx, cy, 3, 2, 44, 20, (118, 84, 82), (106, 78, 80), 0.4)
	return c.done()


def paint_chainlink() -> Image.Image:
	"""Bold wire: a rhombic lattice, 128 x 80 px a diamond, 8 px wires, the alpha is the wire's coverage."""
	h = 160
	c = Canvas(W, h, WIRE)
	for row in range(3):
		for k in range(-1, 18):
			cx = 128 * k + (64 if row % 2 else 0)
			cy = 40 + 80 * row - 80
			pts = [(cx, cy - 40), (cx + 64, cy), (cx, cy + 40), (cx - 64, cy), (cx, cy - 40)]
			c.line(pts, 9.0)
	img = c.done()
	# the wire's RGB is a lit grey with a darker underside: the same lattice drawn once more, offset, into the RGB
	return img


def paint_flat(name: str, h: int) -> Image.Image:
	"""The strips that are flat tones with a few bold joints and stains: no grain."""
	rng = random.Random(2000 + sum(map(ord, name)))
	spec = {
		"plaster": (PLASTER, (146, 134, 118)),
		"concrete": (CONCRETE, CONCRETE_ALT),
		"asphalt": (ASPHALT, ASPHALT_B),
		"kerb": (KERB, KERB_TOP),
		"roof_tar": (TAR, TAR_ALT),
		"gravel": (GRAVEL, (104, 98, 96)),
		"metal": (METAL, METAL_LIGHT),
		"shutter": (SHUTTER, (104, 110, 128)),
		"crate": (CRATE, CRATE_ALT),
		"trim": (TRIM, TRIM_MID),
		"dark": (DARK, (38, 34, 54)),
	}
	base, alt = spec[name]
	c = Canvas(W, h, base)
	for k in range(5):
		x = rng.random() * W
		w = 140 + rng.random() * 380
		c.rect(x, 0, x + w, h, fill=alt)
	if name == "concrete":
		for k in range(4):
			x = 100 + k * 500 + rng.random() * 120
			c.line([(x, 14), (x + (rng.random() - 0.5) * 8, h - 14)], 6.0)
	elif name == "kerb":
		c.rect(0, 0, W, 14, fill=KERB_TOP)
		for k in range(3):
			x = 180 + k * 640 + rng.random() * 100
			c.line([(x, 18), (x, h - 6)], 6.0)
	elif name == "roof_tar":
		for k in range(4):
			x = 80 + k * 500 + rng.random() * 100
			c.line([(x, 8), (x, h - 8)], 5.5)
		c.line([(0, h // 2), (W, h // 2)], 5.5)
	elif name == "metal":
		for k in range(8):
			x = 128 + k * 256
			c.ellipse(x, h // 2, 6, 6, (84, 92, 110), 0)
		c.line([(0, 6), (W, 6)], 5.5)
	elif name == "shutter":
		for k in range(4):
			y = 8 + k * 16
			c.line([(0, y), (W, y)], 5.0)
	elif name == "crate":
		c.line([(0, h // 2), (W, h // 2)], 6.0)
		for k in range(4):
			x = 200 + k * 512
			c.line([(x, 4), (x, h - 4)], 6.0)
	elif name == "trim":
		c.line([(0, h // 2), (W, h // 2)], 5.0, ink=False, rgb=(98, 94, 96))
	elif name == "plaster":
		for k in range(3):
			x = 200 + k * 700 + rng.random() * 100
			c.line([(x, 8), (x + 30, h - 8)], 5.0)
	return c.done()


def paint_ink() -> Image.Image:
	img = Image.new("RGBA", (W, 32), INK_RGB + (255,))
	return img


def assemble() -> tuple:
	"""Returns (the sheet image, the strip table)."""
	sheet = Image.new("RGBA", (W, W), (0, 0, 0, 0))
	y = 0
	strips = []
	for index, spec in enumerate(STRIPS):
		name = spec["name"]
		h = spec["px"]
		if name == "brick":
			img = paint_brick()
		elif name == "glass":
			img = paint_glass()
		elif name == "facade":
			img = paint_facade()
		elif name == "chainlink":
			img = paint_chainlink()
		elif name == "ink":
			img = paint_ink()
		else:
			img = paint_flat(name, h)
		assert img.size == (W, h), (name, img.size)
		sheet.paste(img, (0, y))
		strips.append({
			"name": name,
			"index": index,
			"v0": y / float(W),
			"vh": h / float(W),
			"period_m": spec["period_m"],
			"scissor": bool(spec.get("scissor", False)),
			"ink_only": bool(spec.get("ink_only", False)),
			"ground": bool(spec.get("ground", False)),
			"u_m": spec["u_m"],
			"u_snap_m": spec.get("u_snap_m", 0.0),
			"flip": bool(spec["flip"]),
			"vary_v": bool(spec["vary_v"]),
			"vary_tint": bool(spec["vary_tint"]),
		})
		y += h
	assert y == W, "the strips must fill the sheet: %d" % y
	table = {"sheet_px": W, "ground": {"px": W, "tile_m": 8.0}, "strips": strips}
	return sheet, table


def paint_ground() -> Image.Image:
	"""The street's ground, 8 m a side: flat tone patches, patched squares, puddles and tapered cracks, no grain."""
	rng = random.Random(3307)
	c = Canvas(W, W, ASPHALT)
	# broad flat tone patches (worn and repaired asphalt)
	for k in range(9):
		x = rng.random() * W
		y = rng.random() * W
		rx = 160 + rng.random() * 360
		ry = 120 + rng.random() * 260
		col = ASPHALT_B if k % 3 else ASPHALT_C
		pts = []
		for s in range(10):
			a = s / 10.0 * math.tau
			r = 0.75 + rng.random() * 0.5
			pts.append((x + math.cos(a) * rx * r, y + math.sin(a) * ry * r))
		c.poly(pts, fill=col)
	# patched squares: a flat tone and a bold outline
	for k in range(4):
		x = 100 + rng.random() * (W - 500)
		y = 100 + rng.random() * (W - 500)
		w = 220 + rng.random() * 220
		h = 180 + rng.random() * 200
		c.rect(x, y, x + w, y + h, fill=ASPHALT_C if k % 2 else ASPHALT_B)
		c.line(wobble(rng, [(x, y), (x + w, y), (x + w, y + h), (x, y + h), (x, y)], 6), 7.0)
	# tapered, branching cracks (the trailer's ground line), six of them crossing the tile
	for k in range(6):
		crack(rng, c, rng.random() * W, rng.random() * W, rng.random() * math.tau, 420 + rng.random() * 520, 12.0, 5.0, 2)
	# a manhole
	c.ellipse(1480, 520, 120, 120, (74, 80, 100), 8.0)
	c.ellipse(1480, 520, 78, 78, (84, 90, 112), 6.0)
	for k in range(-2, 3):
		c.line([(1480 - 58, 520 + k * 22), (1480 + 58, 520 + k * 22)], 6.0)
	# puddles: a flat pale fill, a thin ink outline, one lighter shape inside
	for cx, cy, rx, ry in [(560, 1260, 270, 130), (1560, 1500, 190, 100), (1100, 300, 150, 70)]:
		pts = []
		for s in range(14):
			a = s / 14.0 * math.tau
			r = 0.78 + rng.random() * 0.42
			pts.append((cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r))
		c.poly(pts, fill=PUDDLE, ink=0)
		c.line(pts + [pts[0]], 6.0)
		c.poly([(cx - rx * 0.4, cy - ry * 0.2), (cx + rx * 0.1, cy - ry * 0.45), (cx + rx * 0.35, cy - ry * 0.1), (cx - rx * 0.1, cy + ry * 0.05)], fill=PUDDLE_HI)
	# two drain grates
	for gx, gy in [(300, 640), (1700, 1100)]:
		c.rect(gx, gy, gx + 150, gy + 90, fill=(70, 76, 96))
		c.line([(gx, gy), (gx + 150, gy), (gx + 150, gy + 90), (gx, gy + 90), (gx, gy)], 7.0)
		for k in range(1, 5):
			c.line([(gx + k * 30, gy + 8), (gx + k * 30, gy + 82)], 6.0)
	return c.done()


def encode(img: Image.Image, path: str) -> bytes:
	import io
	buf = io.BytesIO()
	img.save(buf, "PNG", compress_level=9, optimize=False)
	return buf.getvalue()


def main() -> int:
	check = "--check" in sys.argv[1:]
	sheet, table = assemble()
	ground = paint_ground()
	files = {
		SHEET: encode(sheet, SHEET),
		GROUND: encode(ground, GROUND),
		TABLE: (json.dumps(table, indent="\t", sort_keys=True) + "\n").encode(),
	}
	bad = 0
	for path, data in files.items():
		if check:
			have = open(path, "rb").read() if os.path.isfile(path) else None
			if have != data:
				print("gen_trailer_kit --check: %s differs from a repaint" % os.path.relpath(path, ROOT), file=sys.stderr)
				bad += 1
		else:
			os.makedirs(os.path.dirname(path), exist_ok=True)
			with open(path, "wb") as f:
				f.write(data)
			print("wrote %s (%d bytes)" % (os.path.relpath(path, ROOT), len(data)))
	if check and not bad:
		print("gen_trailer_kit --check: the sheets and the strip table match a repaint")
	return 1 if bad else 0


if __name__ == "__main__":
	sys.exit(main())
