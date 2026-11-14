"""Paints the trailer look profile's kit sheets (Milestone 7, T15).

Usage: python3 tools/gen_trailer_kit.py [--check]   (Pillow; not -I, which hides a user-site install)
Writes (from the project folder):
	assets/export/kit/trailer_trim_sheet.png     2048 x 2048 RGBA, the trim sheet of the "trailer" look profile
	assets/export/kit/trailer_ground_sheet.png   2048 x 2048 RGBA, the street's ground tile (8 m a side)
	assets/export/kit/trailer_fence_card.png     2048 x 1024 RGBA, the loose hand-drawn fence card (alpha = the strokes), 8 m x 4 m
	assets/export/kit/trailer_trim_strips.json   the strip table the game reads (TrimSheet)
`--check` repaints in memory and compares with the committed files (exit 1 when they differ).

The M6 sheets (trim_sheet.png, ground_sheet.png, trim_strips.json) and tools/gen_trim.gd are not touched: this is
a second sheet the look profile selects. Same 16 strips under the same names and rows as M6's (so KitMesh's strip
indices hold under both profiles), but laid out for the trailer's painting: flat wall planes with sparse hand-drawn
brick hints, cracks and drainpipes, a row of eight different window panes (lit, dark, boarded, curtained), a facade of irregular
windows, and a ground of crack lines and puddles, no noise anywhere. The RGB is the surface
(an albedo at mid values: the profile's lights make the night); the ALPHA is the ink mask (cut by the trim shader),
and on the fence card the boards' coverage.

A strip is 2048 px wide, `u_m` metres of U (so px per metre differs per strip: the table says), and `rows` px high
for `period_m` metres of V. KitMesh reads `u_m` (it scales a face's U so one repeat covers `u_m` instead of
Tuning's kit_trim_m_per_tile), `u_snap_m` (the U offset a variant takes is a multiple of it: one window pane),
`flip` (a variant may mirror U), `vary_v` (a variant may shift V) and `vary_tint` (a variant may nudge the tint): see TrimSheet.variation().

Painting (M7 G3, C4): the walls and the ground tile are Gemini paintings in the trailer's style
(assets/source/trailer_art/kit/src/, made by that folder's make_jobs.py from the trailer frames), turned into sheet cells
here with Pillow alone: the ink mask is the dark lines (grown a little so a line survives the mips), the colour layer under it
is the painting with the lines filled in, tones are flattened a little and matched to the profile's albedo, bays and tiles are
joined with soft blends so no seam shows, and the facade's floors are cut from several paintings so no two windows line up.
The facade (C4: irregular lit, dark, curtained and boarded windows, no wash) and the fence card (C4: uneven boards, two rails and posts, no lattice) are drawn here from shapes. The small flat strips (kerb, concrete, tar, crate, metal)
stay drawn here, with irregular joints. Everything is deterministic: a repaint is identical.
"""
import json
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageMath, ImageStat

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "export", "kit")
SHEET = os.path.join(OUT, "trailer_trim_sheet.png")
GROUND = os.path.join(OUT, "trailer_ground_sheet.png")
FENCE = os.path.join(OUT, "trailer_fence_card.png")
KIT_SRC = os.path.join(ROOT, "assets", "source", "trailer_art", "kit", "src")
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
	{"name": "brick", "px": 512, "period_m": 3.0, "u_m": 12.0, "flip": True, "vary_v": True, "vary_tint": True},
	{"name": "plaster", "px": 32, "period_m": 0.5, "u_m": 8.0, "flip": True, "vary_v": False, "vary_tint": True},
	{"name": "concrete", "px": 64, "period_m": 1.0, "u_m": 8.0, "flip": True, "vary_v": False, "vary_tint": True},
	{"name": "asphalt", "px": 32, "period_m": 1.0, "u_m": 4.0, "flip": False, "vary_v": False, "ground": True, "vary_tint": False},
	{"name": "kerb", "px": 64, "period_m": 0.5, "u_m": 8.0, "flip": True, "vary_v": False, "vary_tint": True},
	{"name": "roof_tar", "px": 64, "period_m": 1.0, "u_m": 8.0, "flip": True, "vary_v": False, "vary_tint": True},
	{"name": "gravel", "px": 32, "period_m": 0.5, "u_m": 4.0, "flip": True, "vary_v": False, "vary_tint": True},
	{"name": "metal", "px": 64, "period_m": 0.5, "u_m": 4.0, "flip": True, "vary_v": False, "vary_tint": False},
	{"name": "shutter", "px": 64, "period_m": 0.5, "u_m": 4.0, "flip": True, "vary_v": False, "vary_tint": False},
	{"name": "chainlink", "px": 160, "period_m": 0.5, "u_m": 4.0, "flip": False, "vary_v": False, "scissor": True, "vary_tint": False},
	{"name": "crate", "px": 64, "period_m": 0.5, "u_m": 8.0, "flip": True, "vary_v": False, "vary_tint": True},
	{"name": "trim", "px": 64, "period_m": 0.25, "u_m": 4.0, "flip": True, "vary_v": False, "vary_tint": False},
	{"name": "ink", "px": 32, "period_m": 1.0, "u_m": 4.0, "flip": False, "vary_v": False, "ink_only": True, "vary_tint": False},
	{"name": "glass", "px": 384, "period_m": 1.6, "u_m": 8.0, "u_snap_m": 1.0, "flip": False, "vary_v": False, "vary_tint": False},
	{"name": "dark", "px": 32, "period_m": 1.0, "u_m": 4.0, "flip": False, "vary_v": False, "vary_tint": False},
	{"name": "facade", "px": 384, "period_m": 5.0, "u_m": 24.0, "flip": True, "vary_v": True, "vary_tint": True},
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


# --- Gemini paintings into sheet cells (M7 G3) ----------------------------------------------------


def source(name: str, box=(0.0, 0.0, 1.0, 1.0), width: int = 0) -> Image.Image:
	"""A Gemini painting from assets/source/trailer_art/kit/src/, cropped to `box` (fractions of its size) and, with `width`, resized to it."""
	im = Image.open(os.path.join(KIT_SRC, name + ".jpg")).convert("RGB")
	w, h = im.size
	im = im.crop((round(box[0] * w), round(box[1] * h), round(box[2] * w), round(box[3] * h)))
	if width:
		im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
	return im


def ink_of(img: Image.Image, solid: int, none: int, grow: int = 3, soften: float = 0.0) -> Image.Image:
	"""The ink mask of a painting: full where a pixel is darker than `solid`, none above `none`, grown by `grow` px (odd) so a line survives the mips."""
	table = [255 if v <= solid else 0 if v >= none else int(255 * (none - v) / float(none - solid)) for v in range(256)]
	mask = img.convert("L").point(table)
	if grow > 1:
		mask = mask.filter(ImageFilter.MaxFilter(grow))
	if soften > 0:
		mask = mask.filter(ImageFilter.GaussianBlur(soften))
	return mask


def under_ink(img: Image.Image, ink: Image.Image) -> Image.Image:
	"""The colour layer: the painting with the inked pixels filled from their bright neighbours (the shader draws the ink over it)."""
	cover = ink.point(lambda v: 255 if v > 20 else 0).filter(ImageFilter.MaxFilter(5))
	fill = img.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(3))
	return Image.composite(fill, img, cover)


def flatten(img: Image.Image, keep: float, radius: float) -> Image.Image:
	"""Less of the big soft tonal patches (the trailer's walls and ground are flatter than a painter's wash): the low frequencies scaled to `keep` about the mean."""
	low = img.filter(ImageFilter.GaussianBlur(radius))
	mean = ImageStat.Stat(img).mean
	out = []
	for c in range(3):
		a = img.getchannel(c).convert("F")
		b = low.getchannel(c).convert("F")
		m = mean[c]
		out.append(ImageMath.lambda_eval(lambda args, m=m: args["a"] - (args["b"] - m) * (1.0 - keep), a=a, b=b).convert("L"))
	return Image.merge("RGB", out)


def match_luma(img: Image.Image, target: float) -> Image.Image:
	"""The whole painting scaled (hue kept) to a mean luminance of `target`."""
	mean = ImageStat.Stat(img.convert("L")).mean[0]
	gain = target / max(mean, 1.0)
	return img.point(lambda v: min(255, int(v * gain + 0.5)))


def luma(rgb) -> float:
	return 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]


def smooth(t: float) -> float:
	t = max(0.0, min(1.0, t))
	return t * t * (3.0 - 2.0 * t)


def edge_ramp(length: int, lo: float, hi: float) -> Image.Image:
	"""A 1 px column (or row) of `length` levels, 255 in the middle and 0 at both ends: e = |2i/length - 1| runs 0 to 1, the ramp from `lo` to `hi`."""
	vals = []
	for i in range(length):
		e = abs((i + 0.5) * 2.0 / length - 1.0)
		vals.append(int(255 * (1.0 - smooth((e - lo) / (hi - lo)))))
	return vals


def seamless(rgb: Image.Image, ink: Image.Image, x: bool, y: bool, lo: float = 0.86, hi: float = 1.0) -> tuple:
	"""Makes the colour layer tile along the chosen axes (the middle of the painting rolled to the edges and blended in over the
	last stretch next to them) and fades the ink out at those edges (a line that crosses a seam would be cut)."""
	w, h = rgb.size
	if x:
		rolled = ImageChops.offset(rgb, w // 2, 0)
		mask = Image.new("L", (w, 1))
		mask.putdata(edge_ramp(w, lo, hi))
		rgb = Image.composite(rgb, rolled, mask.resize((w, h)))
		ink = ImageChops.multiply(ink, mask.resize((w, h)).point(lambda v: 255 if v > 250 else v * 255 // 250))
	if y:
		rolled = ImageChops.offset(rgb, 0, h // 2)
		mask = Image.new("L", (1, h))
		mask.putdata(edge_ramp(h, lo, hi))
		rgb = Image.composite(rgb, rolled, mask.resize((w, h)))
		ink = ImageChops.multiply(ink, mask.resize((w, h)).point(lambda v: 255 if v > 250 else v * 255 // 250))
	return rgb, ink


def blend_junction(rgb: Image.Image, ink: Image.Image, at: int, zone: int) -> tuple:
	"""Dissolves the colour layers of two neighbouring cells over 2 x `zone` px about column `at` (each side mirrored past the join, so
	both are continuous at it) and rubs the ink out there. The strip wraps, so `at` may be its width."""
	w, h = rgb.size
	dx = w // 2 - at
	rgb = ImageChops.offset(rgb, dx, 0)
	ink = ImageChops.offset(ink, dx, 0)
	mid = w // 2
	left = rgb.crop((mid - zone, 0, mid, h))
	right = rgb.crop((mid, 0, mid + zone, h))
	a_zone = Image.new("RGB", (2 * zone, h))
	a_zone.paste(left, (0, 0))
	a_zone.paste(left.transpose(Image.FLIP_LEFT_RIGHT), (zone, 0))
	b_zone = Image.new("RGB", (2 * zone, h))
	b_zone.paste(right.transpose(Image.FLIP_LEFT_RIGHT), (0, 0))
	b_zone.paste(right, (zone, 0))
	ramp = Image.new("L", (2 * zone, 1))
	ramp.putdata([int(255 * smooth((i + 0.5) / (2.0 * zone))) for i in range(2 * zone)])
	rgb.paste(Image.composite(b_zone, a_zone, ramp.resize((2 * zone, h))), (mid - zone, 0))
	clear = Image.new("L", (2 * zone, 1))
	clear.putdata([int(255 * smooth(abs((i + 0.5) / zone - 1.0) * 1.6 - 0.2)) for i in range(2 * zone)])
	ink.paste(ImageChops.multiply(ink.crop((mid - zone, 0, mid + zone, h)), clear.resize((2 * zone, h))), (mid - zone, 0))
	return ImageChops.offset(rgb, -dx, 0), ImageChops.offset(ink, -dx, 0)


def finish_cell(rgb: Image.Image, ink: Image.Image) -> Image.Image:
	out = rgb.convert("RGBA")
	out.putalpha(ink)
	return out


# Which paintings make the wall strip's four 3 m bays, how much of each to keep (the border Gemini sometimes draws is cropped
# off), and the albedo each is matched to: one flat wall colour, a few drawn brick patches, cracks, a pipe, a bracket.
WALL_BAYS = [("wall_b", 0.06, WALL_A), ("wall_c", 0.012, WALL_C), ("wall_e", 0.012, WALL_B), ("wall_f", 0.012, WALL_D)]


def paint_brick() -> Image.Image:
	"""The wall strip: four 3 m bays painted by Gemini, 512 px square each (170 px/m), dissolved into each other, tiling both ways."""
	h = 512
	work = 1024
	rgb = Image.new("RGB", (W, h))
	ink = Image.new("L", (W, h), 0)
	for k, (name, crop, target) in enumerate(WALL_BAYS):
		im = source(name, (crop, crop, 1.0 - crop, 1.0 - crop), work)
		bay_ink = ink_of(im, 52, 92, grow=5, soften=0.8)
		bay = under_ink(im, bay_ink)
		bay = match_luma(flatten(bay, 0.5, work / 10.0), luma(target))
		rgb.paste(bay.resize((512, h), Image.LANCZOS), (k * 512, 0))
		ink.paste(bay_ink.resize((512, h), Image.LANCZOS), (k * 512, 0))
	for k in range(len(WALL_BAYS)):
		rgb, ink = blend_junction(rgb, ink, (k + 1) * 512, 40)
	rgb, ink = seamless(rgb, ink, False, True, 0.88, 1.0)
	return finish_cell(rgb, ink)


def tilt(rng: random.Random, pts, amount: float):
	"""A drawn shape's corners pushed about a little: no window or board is a true rectangle."""
	return [(x + (rng.random() - 0.5) * amount, y + (rng.random() - 0.5) * amount) for x, y in pts]


def paint_facade() -> Image.Image:
	"""A far facade, 24 m x 5 m (two floors), drawn here as flat wall with windows that never make a row: each floor is its own run of
	windows, every one of its own width, height and place on the wall, with a gap of its own before it, and one of lit, dark, curtained
	or boarded (a few are bricked up and left out). Flat fills and a bold ink outline, no noise and no painted wash: at any distance
	the windows read as a street's windows, never as a grid. The strip tiles both ways (the windows wrap round its edges)."""
	h = 384
	rng = random.Random(1303)
	c = Canvas(W, h, FACADE)
	# a drainpipe or two: the wall's only other mark
	for px in (rng.randint(150, 700), rng.randint(1100, 1900)):
		c.tapered([(px, 0), (px + 3, h * 0.5), (px - 2, h)], 7.0, 7.0, ink=False, rgb=PIPE)
	# two bands of unequal height (a tall floor of tall windows, a low floor of small ones): the strip's 5 m period then never reads as a
	# row of equal floors
	bands = [(0, 236, 1.2), (236, 148, 0.8)]
	for top, band_h, size in bands:
		x = rng.random() * 120.0
		while x < W - 40:
			w = (0.55 + rng.random() * 0.8) * size * 85.0
			if rng.random() < 0.12:
				w *= 1.9  # a wide shop-style pane
			wh = (0.7 + rng.random() * 0.9) * size * 77.0
			wh = min(wh, band_h - 24)
			y = top + 12 + rng.random() * (band_h - wh - 24)
			kind = rng.choices(["lit", "dark", "curtain", "boarded", "gone"], [0.36, 0.26, 0.16, 0.12, 0.10])[0]
			gap = (0.2 + rng.random() * 0.5) * 85.0 if rng.random() < 0.7 else (0.9 + rng.random() * 1.3) * 85.0
			if kind == "gone":
				x += w + gap
				continue
			quad = tilt(rng, [(x, y), (x + w, y), (x + w, y + wh), (x, y + wh)], 3.0)
			if kind == "lit":
				c.poly(quad, fill=LIT if rng.random() < 0.6 else (190, 130, 70))
				cut = y + wh * (0.35 + rng.random() * 0.4)  # a deeper lower part, the split anywhere
				c.poly([(x + 2, cut), (x + w - 2, cut + rng.uniform(-5, 5)), (x + w - 2, y + wh - 2), (x + 2, y + wh - 2)], fill=LIT_DEEP)
			elif kind in ("dark", "boarded"):
				c.poly(quad, fill=DARK_PANE if rng.random() < 0.6 else DARK_DEEP)
				if kind == "dark":  # a pale streak
					sx = x + w * (0.2 + rng.random() * 0.4)
					c.poly([(sx, y + 3), (sx + w * 0.22, y + 3), (sx + w * 0.05, y + wh * 0.6), (sx - w * 0.1, y + wh * 0.6)], fill=STREAK)
			else:  # curtained: a flat curtain across a side or the top of a lit or dark pane
				lit = rng.random() < 0.5
				c.poly(quad, fill=LIT_DEEP if lit else DARK_PANE)
				cur = (150, 80, 70) if lit else (84, 78, 120)
				if rng.random() < 0.5:
					c.poly([(x + 2, y + 2), (x + w * (0.4 + rng.random() * 0.4), y + 2), (x + w * 0.3, y + wh - 2), (x + 2, y + wh - 2)], fill=cur)
				else:
					c.poly([(x + 2, y + 2), (x + w - 2, y + 2), (x + w - 2, y + wh * (0.35 + rng.random() * 0.35)), (x + 2, y + wh * 0.4)], fill=cur)
			c.line(quad + [quad[0]], 4.0)
			if kind != "boarded" and rng.random() < 0.4:  # a mullion off the middle
				mx = x + w * (0.35 + rng.random() * 0.3)
				c.line([(mx, y), (mx + rng.uniform(-3, 3), y + wh)], 3.0)
			if kind == "boarded":  # three planks at their own slants
				for k in range(3):
					py = y + wh * (0.1 + 0.3 * k + rng.random() * 0.08)
					slant = rng.uniform(-14, 14)
					plank = tilt(rng, [(x - 6, py), (x + w + 6, py + slant), (x + w + 6, py + slant + 13), (x - 6, py + 13)], 2.0)
					c.poly(plank, fill=(112, 92, 82))
					c.line(plank + [plank[0]], 3.0)
			x += w + gap
	return c.done()


def paint_ground() -> Image.Image:
	"""The street's ground, 8 m a side (256 px/m): a Gemini painting of flat asphalt tones, tapering ink cracks, puddle shapes with a
	highlight, a manhole, a patched square and a grate; the tones flattened, matched to the asphalt albedo and tiled along x (z is
	mirrored by the shader, so its edges meet themselves)."""
	im = source("ground_a")
	ink = ink_of(im, 56, 98, grow=5, soften=0.8)
	rgb = match_luma(flatten(under_ink(im, ink), 0.7, 200.0), luma(ASPHALT))
	rgb, ink = seamless(rgb, ink, True, False, 0.8, 1.0)
	return finish_cell(rgb, ink)


FENCE_W = 2048
FENCE_H = 1024
# The fence's boards, rails and posts: three flat dark fills and one bold ink, so it reads as drawn against the lit street behind it.
FENCE_FILLS = [(62, 70, 98), (54, 62, 90), (72, 78, 108)]
FENCE_INK = (16, 18, 32)
FENCE_LINE = 9  # the outline's width in card px (256 px a metre)


def paint_fence() -> Image.Image:
	"""The hand-drawn fence card, 8 m x 4 m (256 px/m), the trailer profile's fence: a run of uneven vertical boards (each of its own width,
	some pointed, some tilted, a few gone, two snapped off short) behind two rails, with three posts at uneven spacing, every shape a flat
	dark fill inside a bold ink outline. No lattice and no repeating pattern: board widths and gaps are drawn at random, so no two
	neighbours match. The alpha is the shapes' coverage (opaque boards, open gaps); the card tiles along x (the first post straddles the
	wrap and the boards stop short of it)."""
	rng = random.Random(4409)
	rgb = Image.new("RGB", (FENCE_W * SS, FENCE_H * SS), FENCE_INK)
	alpha = Image.new("L", (FENCE_W * SS, FENCE_H * SS), 0)
	dr = ImageDraw.Draw(rgb)
	da = ImageDraw.Draw(alpha)

	def shape(pts, fill) -> None:
		for off in (-FENCE_W, 0, FENCE_W):
			p = [((x + off) * SS, y * SS) for x, y in pts]
			dr.polygon(p, fill=fill, outline=FENCE_INK, width=FENCE_LINE * SS)
			da.polygon(p, fill=255)

	posts = [0.0, 700.0, 1405.0]
	# boards: from just past the first post to just before the wrap, widths and gaps at random
	x = 44.0
	index = 0
	snapped = {7, 19}
	while True:
		w = 36.0 + rng.random() * 46.0
		if x + w > FENCE_W - 44:
			break
		gap = 2.0 + rng.random() * 6.0 if rng.random() < 0.78 else 24.0 + rng.random() * 60.0
		top = 6.0 + rng.random() * 44.0
		lean = (rng.random() - 0.5) * 14.0
		bottom = FENCE_H
		missing = rng.random() < 0.07
		if not missing:
			if index in snapped:  # snapped off: a jagged break, the board gone above it
				top = 250.0 + rng.random() * 300.0
				pts = [(x, top + 30), (x + w * 0.3, top), (x + w * 0.55, top + 40), (x + w * 0.8, top + 6), (x + w, top + 34), (x + w, bottom), (x, bottom)]
			elif rng.random() < 0.3:  # a picket: pointed top
				pts = [(x + lean, top + 26), (x + w * 0.5 + lean, top - 8), (x + w + lean, top + 26), (x + w, bottom), (x, bottom)]
			else:
				pts = [(x + lean, top), (x + w + lean, top + (rng.random() - 0.5) * 8), (x + w, bottom), (x, bottom)]
			shape(pts, FENCE_FILLS[rng.randrange(3)])
		x += w + gap
		index += 1
	# two rails across the boards: slightly sagging, drawn over them
	for y0, sag in ((190.0, 9.0), (716.0, -7.0)):
		pts = [(0.0, y0), (FENCE_W * 0.33, y0 + sag), (FENCE_W * 0.7, y0 + sag * 0.3), (float(FENCE_W), y0)]
		top_edge = pts
		bottom_edge = [(px, py + 50.0) for px, py in reversed(pts)]
		shape(top_edge + bottom_edge, (86, 94, 124))
	# a board hung by one nail across the lower rail
	hang = tilt(rng, [(1010, 560), (1062, 540), (1190, 840), (1138, 858)], 4.0)
	shape(hang, FENCE_FILLS[1])
	for px in posts:
		shape([(px - 30, 0), (px + 30, 0), (px + 28, FENCE_H), (px - 28, FENCE_H)], (96, 104, 134))
	rgb = rgb.resize((FENCE_W, FENCE_H), Image.LANCZOS)
	alpha = alpha.resize((FENCE_W, FENCE_H), Image.LANCZOS)
	out = rgb.convert("RGBA")
	out.putalpha(alpha)
	return out


def pane(c: Canvas, x0: int, h: int, kind: int) -> None:
	"""One 1 m x 1.6 m window pane (256 x h px), the bottom of the cell at the bottom of the row. The eight differ in what they show and
	where: lit with a blind part-drawn, lit and mullioned off the middle, lit with a lamp, dark and streaked, boarded, curtained, a narrow
	lit slot beside a curtain, and a dark one with a lit lower sash."""
	w = 256
	y0 = 0
	cell_bg = {0: LIT, 1: LIT, 2: LIT, 3: DARK_PANE, 4: DARK_PANE, 5: DARK_PANE, 6: DARK_PANE, 7: DARK_DEEP}[kind]
	c.rect(x0, y0, x0 + w, y0 + h, fill=cell_bg, wrap=False)
	# a 7 px frame of dark (the kit's own frame boards cover the border on a window piece)
	for rect in [(x0, 0, x0 + 7, h), (x0 + w - 7, 0, x0 + w, h), (x0, 0, x0 + w, 7), (x0, h - 7, x0 + w, h)]:
		c.rect(*rect, fill=DARK_DEEP, wrap=False)
	if kind == 0:  # lit, a blind drawn down from the top to an uneven edge, a deeper lower part
		c.poly([(x0 + 7, h * 0.52), (x0 + w - 7, h * 0.58), (x0 + w - 7, h - 7), (x0 + 7, h - 7)], fill=LIT_DEEP, wrap=False)
		c.poly([(x0 + 7, 7), (x0 + w - 7, 7), (x0 + w - 7, 118), (x0 + 130, 138), (x0 + 7, 112)], fill=(150, 90, 56), wrap=False)
		c.line([(x0 + 7, 112), (x0 + 130, 138), (x0 + w - 7, 118)], 3.0, wrap=False)
	elif kind == 1:  # lit, a mullion cross well off the middle
		c.poly([(x0 + 7, 250), (x0 + w - 7, 236), (x0 + w - 7, h - 7), (x0 + 7, h - 7)], fill=LIT_DEEP, wrap=False)
		c.line([(x0 + 92, 7), (x0 + 98, h - 7)], 6.0, wrap=False)
		c.line([(x0 + 7, 150), (x0 + w - 7, 160)], 6.0, wrap=False)
	elif kind == 2:  # lit, a lamp's silhouette on the sill
		c.ellipse(x0 + 128, 150, 80, 110, LIT_HOT)
		c.poly([(x0 + 100, 40), (x0 + 156, 40), (x0 + 170, 110), (x0 + 86, 110)], fill=(118, 72, 44), wrap=False)
		c.rect(x0 + 122, 110, x0 + 134, 200, fill=(118, 72, 44), wrap=False)
		c.rect(x0 + 100, 200, x0 + 156, 214, fill=(118, 72, 44), wrap=False)
	elif kind == 3:  # dark, two pale reflection streaks
		c.poly([(x0 + 40, 14), (x0 + 90, 14), (x0 + 30, 200), (x0 + 12, 200)], fill=STREAK, wrap=False)
		c.poly([(x0 + 110, 14), (x0 + 130, 14), (x0 + 70, 200), (x0 + 56, 200)], fill=STREAK, wrap=False)
	elif kind == 4:  # boarded: three planks at their own slants across a dark pane
		for top, slant, thick in ((40, 30, 52), (150, -26, 56), (262, 20, 50)):
			plank = [(x0 + 2, top), (x0 + w - 2, top + slant), (x0 + w - 2, top + slant + thick), (x0 + 2, top + thick)]
			c.poly(plank, fill=(112, 92, 82), wrap=False)
			c.line(plank + [plank[0]], 5.0, wrap=False)
	elif kind == 5:  # dark, a flat curtain drawn across
		c.poly([(x0 + 7, 7), (x0 + w - 7, 7), (x0 + w - 7, 230), (x0 + 130, 250), (x0 + 7, 220)], fill=(84, 78, 120), wrap=False)
		c.line([(x0 + 70, 10), (x0 + 60, 230)], 3.0, ink=False, rgb=(60, 56, 92), wrap=False)
		c.line([(x0 + 150, 10), (x0 + 156, 245)], 3.0, ink=False, rgb=(60, 56, 92), wrap=False)
	elif kind == 6:  # a narrow lit slot on the right beside a flat curtain that fills the rest
		c.poly([(x0 + 150, 7), (x0 + w - 7, 7), (x0 + w - 7, h - 7), (x0 + 140, h - 7)], fill=LIT, wrap=False)
		c.poly([(x0 + 7, 7), (x0 + 150, 7), (x0 + 140, h - 7), (x0 + 7, h - 7)], fill=(150, 80, 70), wrap=False)
		c.line([(x0 + 150, 7), (x0 + 140, h - 7)], 4.0, wrap=False)
	else:  # dark above, the lower sash raised and lit at an uneven height
		c.poly([(x0 + 7, 190), (x0 + w - 7, 206), (x0 + w - 7, h - 7), (x0 + 7, h - 7)], fill=LIT, wrap=False)
		c.line([(x0 + 7, 190), (x0 + w - 7, 206)], 5.0, wrap=False)


def paint_glass() -> Image.Image:
	h = 384
	c = Canvas(W, h, DARK_DEEP)
	for k in range(8):
		pane(c, k * 256, h, k)
	return c.done()


def paint_chainlink() -> Image.Image:
	"""The sheet's scissor row. The trailer profile draws its fence from the card (paint_fence), never from this row, and a drawn lattice
	is what that profile no longer has: the row is a plain opaque fill of the fence's board colour."""
	return Image.new("RGBA", (W, 160), FENCE_FILLS[0] + (255,))


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
	def scatter(count: int, min_gap: float) -> list:
		"""`count` x positions on the strip, at least `min_gap` px apart, wrapped: joints that fall where they fall, never on a pitch."""
		xs = []
		while len(xs) < count:
			x = rng.random() * W
			if all(min(abs(x - o), W - abs(x - o)) >= min_gap for o in xs):
				xs.append(x)
		return sorted(xs)

	def joint(x: float, y0: float, y1: float, w0: float = 6.0, w1: float = 4.5) -> None:
		"""A hand-drawn joint: a tapered, slightly kinked stroke."""
		mid = (y0 + y1) * 0.5
		c.tapered([(x, y0), (x + (rng.random() - 0.5) * 14, mid), (x + (rng.random() - 0.5) * 10, y1)], w0, w1)

	if name == "concrete":
		for x in scatter(3, 420):
			joint(x, 14, h - 14)
	elif name == "kerb":
		c.rect(0, 0, W, 14, fill=KERB_TOP)
		for x in scatter(3, 480):
			joint(x, 18, h - 6)
	elif name == "roof_tar":
		for x in scatter(3, 420):
			joint(x, 8, h - 8, 5.5, 4.5)
		c.tapered([(0, h // 2), (W * 0.31, h // 2 + 5), (W * 0.62, h // 2 - 4), (W, h // 2)], 5.5, 5.5)
	elif name == "metal":
		for x in scatter(5, 220):
			c.ellipse(x, h // 2 + (rng.random() - 0.5) * 8, 6, 6, (84, 92, 110), 0)
		c.line([(0, 6), (W, 6)], 5.5)
	elif name == "shutter":
		for k in range(4):
			y = 8 + k * 16
			c.line([(0, y), (W, y)], 5.0)
	elif name == "crate":
		c.line([(0, h // 2), (W, h // 2)], 6.0)
		for x in scatter(3, 480):
			joint(x, 4, h - 4)
	elif name == "trim":
		c.line([(0, h // 2), (W, h // 2)], 5.0, ink=False, rgb=(98, 94, 96))
	elif name == "plaster":
		for x in scatter(2, 600):
			joint(x, 8, h - 8, 5.0, 4.5)
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


def encode(img: Image.Image, path: str) -> bytes:
	import io
	buf = io.BytesIO()
	img.save(buf, "PNG", compress_level=9, optimize=False)
	return buf.getvalue()


def main() -> int:
	check = "--check" in sys.argv[1:]
	sheet, table = assemble()
	ground = paint_ground()
	fence = paint_fence()
	files = {
		SHEET: encode(sheet, SHEET),
		GROUND: encode(ground, GROUND),
		FENCE: encode(fence, FENCE),
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
