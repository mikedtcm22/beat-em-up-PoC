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
brick hints, cracks and drainpipes, a row of eight different window panes (lit and dark), a facade of irregularly
lit windows, a bold chain-link, and a ground of crack lines and puddles, no noise anywhere. The RGB is the surface
(an albedo at mid values: the profile's lights make the night); the ALPHA is the ink mask (cut by the trim shader),
and on the chain-link the wire's coverage.

A strip is 2048 px wide, `u_m` metres of U (so px per metre differs per strip: the table says), and `rows` px high
for `period_m` metres of V. KitMesh reads `u_m` (it scales a face's U so one repeat covers `u_m` instead of
Tuning's kit_trim_m_per_tile), `u_snap_m` (the U offset a variant takes is a multiple of it: one window pane),
`flip` (a variant may mirror U), `vary_v` (a variant may shift V) and `vary_tint` (a variant may nudge the tint): see TrimSheet.variation().

Painting (M7 G3): the walls, the facade, the ground tile and the fence card are Gemini paintings in the trailer's style
(assets/source/trailer_art/kit/src/, made by that folder's make_jobs.py from the trailer frames), turned into sheet cells
here with Pillow alone: the ink mask is the dark lines (grown a little so a line survives the mips), the colour layer under it
is the painting with the lines filled in, tones are flattened a little and matched to the profile's albedo, bays and tiles are
joined with soft blends so no seam shows, and the facade's floors are cut from several paintings so no two windows line up.
The fence is a Gemini lattice warped and torn by hand-written shapes. The small flat strips (kerb, concrete, tar, crate, metal)
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


def paint_facade() -> Image.Image:
	"""A far facade, 24 m x 5 m (two floors): each floor is three whole bands cut from two Gemini facades, joined with dissolves, the
	second floor rolled sideways and every band nudged up or down, so no window lines up with the next."""
	h = 384
	floor_h = 192
	edges = [0, 683, 1366, W]
	rng = random.Random(1303)
	# (painting, left, right, top, bottom) of one floor's band in it, fractions: the windows sit inside the building's edge lines
	cuts = [("facade_a", 0.095, 0.905, 0.00, 0.47), ("facade_a", 0.095, 0.905, 0.47, 0.94), ("facade_b", 0.075, 0.935, 0.00, 0.47), ("facade_b", 0.075, 0.935, 0.47, 0.94)]
	rgb = Image.new("RGB", (W, h))
	ink = Image.new("L", (W, h), 0)
	order = [[0, 3, 2], [1, 0, 3]]
	for floor in range(2):
		row_rgb = Image.new("RGB", (W, floor_h))
		row_ink = Image.new("L", (W, floor_h), 0)
		for k, which in enumerate(order[floor]):
			name, x0, x1, y0, y1 = cuts[which]
			bw = edges[k + 1] - edges[k]
			im = source(name, (x0, y0, x1, y1)).resize((bw, floor_h), Image.LANCZOS)
			if rng.random() < 0.5:
				im = im.transpose(Image.FLIP_LEFT_RIGHT)
			band_ink = ink_of(im, 34, 66, grow=3, soften=0.6)
			# up or down a little: the wall colour above and below is a flat field, so the band's rows are shifted and wrapped
			shift = rng.randint(-14, 14)
			im = ImageChops.offset(im, 0, shift)
			band_ink = ImageChops.offset(band_ink, 0, shift)
			row_rgb.paste(under_ink(im, band_ink), (edges[k], 0))
			row_ink.paste(band_ink, (edges[k], 0))
		for k in range(3):
			row_rgb, row_ink = blend_junction(row_rgb, row_ink, edges[k + 1], 22)
		roll = rng.randint(200, 900) * floor
		row_rgb = ImageChops.offset(row_rgb, roll, 0)
		row_ink = ImageChops.offset(row_ink, roll, 0)
		# a third of the windows are gone (bricked up, painted over): found by the ink along the columns, covered with the wall's colour
		profile = list(row_ink.resize((W, 1), Image.BOX).getdata())
		x = 0
		while x < W:
			if profile[x] > 30:
				x1 = x
				gap = 0
				while x1 < W and gap < 18:
					gap = 0 if profile[x1] > 30 else gap + 1
					x1 += 1
				x1 -= gap
				if x1 - x > 40 and rng.random() < 0.34:
					wall = row_rgb.getpixel(((x + x1) // 2, 3))
					row_rgb.paste(wall, (max(x - 8, 0), 14, min(x1 + 8, W), floor_h - 6))
					row_ink.paste(0, (max(x - 8, 0), 14, min(x1 + 8, W), floor_h - 6))
				x = x1 + 1
			else:
				x += 1
		rgb.paste(row_rgb, (0, floor * floor_h))
		ink.paste(row_ink, (0, floor * floor_h))
	rgb = match_luma(rgb, 100.0)
	rgb, ink = seamless(rgb, ink, False, True, 0.9, 1.0)
	return finish_cell(rgb, ink)


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
# The fence card's ink and wire colour: a dark blue-grey, so a line reads as drawn ink against the lit street behind it.
FENCE_RGB = (58, 66, 92)


def ragged(rng: random.Random, cx: float, cy: float, rx: float, ry: float, n: int = 16):
	"""A torn-edged blob: `n` points round an ellipse, each pushed out or in."""
	pts = []
	for s in range(n):
		a = s / float(n) * math.tau
		r = 0.7 + rng.random() * 0.6
		pts.append((cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r))
	return pts


def paint_fence() -> Image.Image:
	"""The loose hand-drawn fence card, 8 m x 4 m (256 px/m), the trailer profile's chain-link: a Gemini drawing of a lattice, enlarged
	(a diamond about 0.9 m, so it does not moire), its lines pushed off parallel by a coarse warp, torn open in places (one tear straddles
	the wrap, so the card tiles along x), under a thick sagging top line drawn here. The alpha is the strokes; the RGB one dark colour."""
	rng = random.Random(4409)
	im = source("fence_a", (300 / 2048.0, 130 / 1143.0, 1580 / 2048.0, 770 / 1143.0)).resize((FENCE_W, FENCE_H), Image.LANCZOS)
	ink = ImageChops.invert(im.convert("L")).point(lambda v: 0 if v < 70 else 255 if v > 150 else int(255 * (v - 70) / 80.0))
	# a coarse mesh warp: the inner nodes of an 8 x 4 grid move by up to 22 px, so no two diagonals are parallel
	cols = 8
	rows = 4
	nodes = {}
	for j in range(rows + 1):
		for i in range(cols + 1):
			edge = i in (0, cols) or j in (0, rows)
			nodes[(i, j)] = (i * FENCE_W / cols + (0 if edge else (rng.random() - 0.5) * 44), j * FENCE_H / rows + (0 if edge else (rng.random() - 0.5) * 44))
	mesh = []
	for j in range(rows):
		for i in range(cols):
			box = (round(i * FENCE_W / cols), round(j * FENCE_H / rows), round((i + 1) * FENCE_W / cols), round((j + 1) * FENCE_H / rows))
			a, b, c, d = nodes[(i, j)], nodes[(i, j + 1)], nodes[(i + 1, j + 1)], nodes[(i + 1, j)]
			mesh.append((box, (a[0], a[1], b[0], b[1], c[0], c[1], d[0], d[1])))
	ink = ink.transform((FENCE_W, FENCE_H), Image.MESH, mesh, Image.BICUBIC)
	# torn open: the first blob straddles the wrap (drawn at both ends), the others sit about the card
	tears = Image.new("L", (FENCE_W, FENCE_H), 0)
	td = ImageDraw.Draw(tears)
	blobs = [(0, 520, 230, 360), (760, 800, 150, 200), (1330, 270, 210, 140), (1710, 900, 170, 130), (1090, 560, 120, 170)]
	for cx, cy, rx, ry in blobs:
		pts = ragged(rng, cx, cy, rx, ry)
		for off in (-FENCE_W, 0, FENCE_W):
			td.polygon([(x + off, y) for x, y in pts], fill=255)
	ink = ImageChops.multiply(ink, ImageChops.invert(tears))
	# the sagging top line: a thick stroke whose width and height wander (periodic along x), and a thinner second pass that drops out
	def top_y(x: float) -> float:
		return 46 + 20 * math.sin(math.tau * x / FENCE_W + 0.6) + 9 * math.sin(math.tau * 3 * x / FENCE_W + 2.0)
	def top_w(x: float) -> float:
		return 22 + 7 * math.sin(math.tau * 2 * x / FENCE_W + 1.0)
	above = Image.new("L", (FENCE_W, FENCE_H), 0)
	ad = ImageDraw.Draw(above)
	ad.polygon([(0, 0)] + [(x, top_y(x)) for x in range(0, FENCE_W + 1, 16)] + [(FENCE_W, 0)], fill=255)
	ink = ImageChops.multiply(ink, ImageChops.invert(above))
	idraw = ImageDraw.Draw(ink)
	step = 8
	for x in range(0, FENCE_W, step):
		x1 = x + step
		y0, y1 = top_y(x), top_y(x1)
		w = (top_w(x) + top_w(x1)) * 0.5
		idraw.polygon([(x, y0 - w / 2), (x1, y1 - w / 2), (x1, y1 + w / 2), (x, y0 + w / 2)], fill=255)
		if 0.18 < (x / FENCE_W) < 0.46 or 0.62 < (x / FENCE_W) < 0.9:
			idraw.polygon([(x, y0 + w / 2 + 10), (x1, y1 + w / 2 + 10), (x1, y1 + w / 2 + 19), (x, y0 + w / 2 + 19)], fill=255)
	ink = ink.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.9))
	out = Image.new("RGBA", (FENCE_W, FENCE_H), FENCE_RGB + (0,))
	out.putalpha(ink)
	return out


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
