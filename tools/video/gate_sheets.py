"""Gate sheets for the cinematic video (docs/video/PLAN.md §6): side-by-side pairs, and the blind set.

  pairs: one PNG per row, with the row's images side by side at one height and a caption over each,
         plus an overview of all rows stacked.
    ~/.venvs/beat-em-up-video/bin/python -I tools/video/gate_sheets.py pairs --out <dir> --height 720 \
        --row "<name>|<caption>=<png>|<caption>=<png>..." ...
  blind: the blind check's set. Every image gets the same crop (the bottom band, where subtitles
         and watermarks live, is cut off) and size, then the set is shuffled with a fixed seed and
         written as img01.png, img02.png, ... The key (which file is which) goes to a separate file,
         which the blind checker must never be given.
    ~/.venvs/beat-em-up-video/bin/python -I tools/video/gate_sheets.py blind --out <dir> --key <key.json> \
        --seed 11 --size 1600x788 <png> ...

Downloaded frames are only read, as paths.
"""
from __future__ import annotations

import argparse
import json
import os
import random

from PIL import Image, ImageDraw, ImageFont

CAPTION_PX = 34
GAP_PX = 8
BAND = 0.10
BACKGROUND = (12, 12, 14)
TEXT = (235, 235, 235)


def font(size: int) -> ImageFont.ImageFont:
	try:
		return ImageFont.load_default(size=size)
	except TypeError:
		return ImageFont.load_default()


def fit_height(im: Image.Image, height: int) -> Image.Image:
	w = int(round(im.width * height / im.height))
	return im.resize((w, height), Image.LANCZOS)


def row_image(items: list, height: int) -> Image.Image:
	"""items: [(caption, path)]. The images side by side at `height`, each captioned."""
	ims = [fit_height(Image.open(p).convert("RGB"), height) for _, p in items]
	width = sum(im.width for im in ims) + GAP_PX * (len(ims) - 1)
	out = Image.new("RGB", (width, height + CAPTION_PX), BACKGROUND)
	draw = ImageDraw.Draw(out)
	f = font(int(CAPTION_PX * 0.7))
	x = 0
	for (caption, _), im in zip(items, ims):
		draw.text((x + 6, 4), caption, fill=TEXT, font=f)
		out.paste(im, (x, CAPTION_PX))
		x += im.width + GAP_PX
	return out


def cmd_pairs(args: argparse.Namespace) -> None:
	os.makedirs(args.out, exist_ok=True)
	rows = []
	for spec in args.row:
		parts = spec.split("|")
		name = parts[0]
		items = []
		for part in parts[1:]:
			caption, path = part.split("=", 1)
			items.append((caption, path))
		im = row_image(items, args.height)
		path = os.path.join(args.out, f"{name}.png")
		im.save(path)
		rows.append(im)
		print(f"wrote {path} ({im.width}x{im.height})")
	if rows:
		scale = args.overview_width / max(r.width for r in rows)
		small = [r.resize((int(r.width * scale), int(r.height * scale)), Image.LANCZOS) for r in rows]
		over = Image.new("RGB", (max(s.width for s in small), sum(s.height for s in small) + GAP_PX * (len(small) - 1)), BACKGROUND)
		y = 0
		for s in small:
			over.paste(s, (0, y))
			y += s.height + GAP_PX
		path = os.path.join(args.out, "overview.png")
		over.save(path)
		print(f"wrote {path} ({over.width}x{over.height})")


def cmd_blind(args: argparse.Namespace) -> None:
	os.makedirs(args.out, exist_ok=True)
	w, h = (int(v) for v in args.size.lower().split("x"))
	paths = list(args.images)
	order = list(range(len(paths)))
	random.Random(args.seed).shuffle(order)
	key = {}
	for n, i in enumerate(order, start=1):
		im = Image.open(paths[i]).convert("RGB")
		# Crop to 16:9 first (centre), then cut the bottom band off, then resize.
		target = 16 / 9
		if im.width / im.height > target:
			cw = int(round(im.height * target))
			x0 = (im.width - cw) // 2
			im = im.crop((x0, 0, x0 + cw, im.height))
		elif im.width / im.height < target:
			ch = int(round(im.width / target))
			y0 = (im.height - ch) // 2
			im = im.crop((0, y0, im.width, y0 + ch))
		im = im.crop((0, 0, im.width, int(round(im.height * (1.0 - BAND)))))
		im = im.resize((w, h), Image.LANCZOS)
		name = f"img{n:02d}.png"
		im.save(os.path.join(args.out, name))
		key[name] = paths[i]
	with open(args.key, "w") as f:
		json.dump(key, f, indent=1)
	print(f"wrote {len(paths)} images to {args.out}; key in {args.key}")


def main() -> None:
	ap = argparse.ArgumentParser()
	sub = ap.add_subparsers(dest="cmd", required=True)
	p = sub.add_parser("pairs")
	p.add_argument("--out", required=True)
	p.add_argument("--height", type=int, default=720)
	p.add_argument("--overview-width", type=int, default=2400)
	p.add_argument("--row", action="append", default=[])
	b = sub.add_parser("blind")
	b.add_argument("--out", required=True)
	b.add_argument("--key", required=True)
	b.add_argument("--seed", type=int, default=11)
	b.add_argument("--size", default="1600x788")
	b.add_argument("images", nargs="+")
	args = ap.parse_args()
	if args.cmd == "pairs":
		cmd_pairs(args)
	else:
		cmd_blind(args)


if __name__ == "__main__":
	main()
