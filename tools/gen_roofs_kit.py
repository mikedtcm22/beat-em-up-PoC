"""Paints the dusk roofs' skyline plates (Milestone 7, e-roofs): the far city of Mission 1's roofs as flat stepped silhouettes.

Usage: python3 tools/gen_roofs_kit.py [--check]   (Pillow; not -I, which hides a user-site install)
Writes (from the project folder):
	assets/export/kit/trailer_roofs_skyline_a.png   2048 x 640 RGBA, the plate behind the roofs' far end
	assets/export/kit/trailer_roofs_skyline_b.png   2048 x 640 RGBA, the plate on the +x side
	assets/export/kit/trailer_roofs_skyline_c.png   2048 x 640 RGBA, the plate on the -x side
`--check` repaints in memory and compares with the committed files (exit 1 when they differ).

Three depth layers of blocks, each a flat fill (a paler mauve at the back, near the horizon's glow, a deep plum in front), stepped
tops, an occasional water tank, chimney or antenna, one shade edge down the right of each block (the key comes from the low sun
on the left), and a few lit windows scattered unevenly: every window has its own size, offset and chance, whole floors go dark, and
some panes are boarded (dark). The sky is alpha 0: the painted sky shows through. No noise, no gradients. Deterministic (fixed seeds).
Separate from tools/gen_trailer_kit.py, whose sheets are not touched.
"""
import os
import random
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "export", "kit")
W, H = 2048, 640
SS = 2  # supersampling

LAYERS = [
	# fill, shade, base height share, height range (px), block width range (px), lit chance
	{"fill": (118, 70, 110), "shade": (98, 58, 98), "base": 0.30, "hmin": 70, "hmax": 190, "wmin": 90, "wmax": 230, "lit": 0.05},
	{"fill": (84, 52, 98), "shade": (66, 42, 84), "base": 0.15, "hmin": 90, "hmax": 280, "wmin": 110, "wmax": 260, "lit": 0.09},
	{"fill": (54, 38, 76), "shade": (40, 30, 62), "base": 0.0, "hmin": 120, "hmax": 360, "wmin": 130, "wmax": 300, "lit": 0.14},
]
LIT = (255, 178, 88)
LIT_DEEP = (236, 132, 64)
BOARD = (30, 24, 50)
RIM = (214, 120, 110)


def block(draw: ImageDraw.ImageDraw, rng: random.Random, layer: dict, x0: int, x1: int, top: int, bottom: int) -> None:
	fill, shade = layer["fill"], layer["shade"]
	draw.rectangle([x0, top, x1, bottom], fill=fill)
	# One shade edge: the right part of the block, a hard step.
	edge = int((x1 - x0) * rng.uniform(0.16, 0.26))
	draw.rectangle([x1 - edge, top, x1, bottom], fill=shade)
	# A pale line along the lit top-left edge on the nearest layers is left out: the rim is the sky's.
	# Steps: one or two setbacks on the roof line.
	for _ in range(rng.choice([0, 1, 1, 2])):
		sw = int((x1 - x0) * rng.uniform(0.25, 0.5))
		sx = rng.randint(x0, x1 - sw)
		sh = rng.randint(14, 46) * SS
		draw.rectangle([sx, top - sh, sx + sw, top], fill=fill)
		draw.rectangle([max(sx, sx + sw - int(sw * 0.3)), top - sh, sx + sw, top], fill=shade)
	roll = rng.random()
	if roll < 0.18:  # a water tank on legs
		tw, th = rng.randint(24, 40) * SS, rng.randint(26, 40) * SS
		tx = rng.randint(x0 + 6, max(x0 + 8, x1 - tw - 6))
		draw.rectangle([tx + 4, top - th - 14 * SS, tx + tw - 4, top], fill=shade)
		draw.rectangle([tx, top - th - 14 * SS, tx + tw, top - 14 * SS], fill=fill)
		draw.polygon([(tx - 2, top - th - 14 * SS), (tx + tw // 2, top - th - 26 * SS), (tx + tw + 2, top - th - 14 * SS)], fill=shade)
	elif roll < 0.34:  # a chimney
		cw = rng.randint(10, 16) * SS
		cx = rng.randint(x0 + 6, max(x0 + 8, x1 - cw - 6))
		draw.rectangle([cx, top - rng.randint(26, 52) * SS, cx + cw, top], fill=shade)
	elif roll < 0.5:  # an antenna
		ax = rng.randint(x0 + 10, max(x0 + 12, x1 - 10))
		ah = rng.randint(40, 90) * SS
		draw.rectangle([ax, top - ah, ax + 2 * SS, top], fill=shade)
		draw.rectangle([ax - 8 * SS, top - ah + 10 * SS, ax + 10 * SS, top - ah + 12 * SS], fill=shade)


def windows(draw: ImageDraw.ImageDraw, rng: random.Random, layer: dict, x0: int, x1: int, top: int, bottom: int) -> None:
	"""A few lit windows, never a grid: each has its own size and offset, whole floors go dark, some panes are boarded."""
	step_x = rng.randint(30, 46) * SS
	step_y = rng.randint(34, 52) * SS
	y = top + rng.randint(14, 30) * SS
	while y < bottom - 24 * SS:
		floor_dark = rng.random() < 0.42
		x = x0 + rng.randint(12, 26) * SS
		while x < x1 - 26 * SS:
			ww = int(rng.uniform(10, 17) * SS)
			wh = int(rng.uniform(14, 22) * SS)
			ox, oy = rng.randint(-5, 5) * SS, rng.randint(-4, 4) * SS
			roll = rng.random()
			if not floor_dark and roll < layer["lit"] * 3.4:
				col = LIT if rng.random() < 0.7 else LIT_DEEP
				draw.rectangle([x + ox, y + oy, x + ox + ww, y + oy + wh], fill=col)
			elif roll < 0.32:
				draw.rectangle([x + ox, y + oy, x + ox + ww, y + oy + wh], fill=BOARD)
			x += step_x + rng.randint(-6, 14) * SS
		y += step_y + rng.randint(-4, 8) * SS


def paint(seed: int) -> Image.Image:
	rng = random.Random(seed)
	img = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
	draw = ImageDraw.Draw(img)
	for layer in LAYERS:
		x = -rng.randint(0, 80) * SS
		floor = int(H * SS * (1.0 - layer["base"]))
		while x < W * SS:
			bw = rng.randint(layer["wmin"], layer["wmax"]) * SS
			bh = rng.randint(layer["hmin"], layer["hmax"]) * SS
			top = floor - bh
			block(draw, rng, layer, x, x + bw, top, H * SS)
			if layer["lit"] > 0.0:
				windows(draw, rng, layer, x, x + bw, top, H * SS)
			x += bw + rng.choice([0, 0, 0, rng.randint(6, 30) * SS])
	return img.resize((W, H), Image.LANCZOS)


def encode(img: Image.Image) -> bytes:
	import io
	buf = io.BytesIO()
	img.save(buf, "PNG", compress_level=9, optimize=False)
	return buf.getvalue()


def main() -> int:
	check = "--check" in sys.argv[1:]
	files = {}
	for name, seed in (("a", 5101), ("b", 5207), ("c", 5303)):
		path = os.path.join(OUT, "trailer_roofs_skyline_%s.png" % name)
		files[path] = encode(paint(seed))
	bad = 0
	for path, data in files.items():
		if check:
			have = open(path, "rb").read() if os.path.isfile(path) else None
			if have != data:
				print("gen_roofs_kit --check: %s differs from a repaint" % os.path.relpath(path, ROOT), file=sys.stderr)
				bad += 1
		else:
			os.makedirs(os.path.dirname(path), exist_ok=True)
			with open(path, "wb") as f:
				f.write(data)
			print("wrote %s (%d bytes)" % (os.path.relpath(path, ROOT), len(data)))
	if check and not bad:
		print("gen_roofs_kit --check: the plates match a repaint")
	return 1 if bad else 0


if __name__ == "__main__":
	sys.exit(main())
