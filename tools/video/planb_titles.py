"""Plan B trailer title cards: the boss's name card and the end title, as RGBA 1920x1080 overlays plus previews on real frames.

Usage: planb_titles.py
Writes captures/video/planb/titles/ox_name_card.png (over t10), end_title.png (over t14), and preview_ox.jpg /
preview_end.jpg (the cards composited over frame 60 of the t10 restyle and frame 48 of the t14 render).
Font: Anton (SIL OFL) from ~/.cache/beat-em-up-video/fonts/anton/ (not in the repo; download steps are in the HANDOFF).
Run with ~/.venvs/beat-em-up-video/bin/python -I (Pillow only).
"""
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
P = ROOT / "captures/video/planb"
OUT = P / "titles"
FONT = Path.home() / ".cache/beat-em-up-video/fonts/anton/Anton-Regular.ttf"
W, H = 1920, 1080
ORANGE = (255, 84, 24)


def load_font(size: int) -> ImageFont.FreeTypeFont:
	if not FONT.is_file() or FONT.read_bytes()[:4] != b"\x00\x01\x00\x00":
		sys.exit(f"titles: {FONT} missing or not a TrueType file")
	return ImageFont.truetype(str(FONT), size)


def spaced_width(font: ImageFont.FreeTypeFont, text: str, track: float) -> float:
	return sum(font.getlength(c) for c in text) + track * (len(text) - 1)


def draw_spaced(d: ImageDraw.ImageDraw, x: float, y: float, text: str, font, track: float, **kw) -> None:
	for c in text:
		d.text((x, y), c, font=font, **kw)
		x += font.getlength(c) + track


def text_layer(x: float, y: float, text: str, font, track: float, fill, stroke: int = 0, stroke_fill=None) -> Image.Image:
	"""Tracked text on its own transparent layer (anchor: left, top of the em box)."""
	layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	draw_spaced(ImageDraw.Draw(layer), x, y, text, font, track, fill=fill, stroke_width=stroke, stroke_fill=stroke_fill)
	return layer


def shadow_of(layer: Image.Image, blur: float, color, opacity: float, offset=(0, 0)) -> Image.Image:
	"""A blurred coloured silhouette of a layer's alpha."""
	a = layer.getchannel("A").filter(ImageFilter.GaussianBlur(blur))
	a = a.point(lambda v: min(255, int(v * opacity)))
	a = ImageChops.offset(a, *offset)
	out = Image.new("RGBA", layer.size, color + (0,))
	out.putalpha(a)
	return out


def slanted_bar(x0: float, y0: float, x1: float, y1: float, skew: float, color) -> Image.Image:
	"""A parallelogram leaning right: the top edge is shifted by skew pixels."""
	layer = Image.new("RGBA", (W * 2, H * 2), (0, 0, 0, 0))
	pts = [(x0 + skew, y0), (x1 + skew, y0), (x1, y1), (x0, y1)]
	ImageDraw.Draw(layer).polygon([(px * 2, py * 2) for px, py in pts], fill=color + (255,))
	return layer.resize((W, H), Image.LANCZOS)  # 2x supersample for clean slanted edges


def ox_card() -> Image.Image:
	card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	track = 5
	text = "OX PELLERIN"
	# Largest size whose name fits the right half (x from 1000 to 1830); Ox stands at the left.
	size = 250
	while spaced_width(load_font(size), text, track) > 830:
		size -= 4
	font = load_font(size)
	tw = spaced_width(font, text, track)
	x = 1830 - tw
	y = 560
	bbox = font.getbbox("O")
	cap_top, cap_bot = y + bbox[1], y + bbox[3]
	# Hot slanted bar under the name, running a little past its left edge, plus a short thin tick above it.
	card.alpha_composite(shadow_of(slanted_bar(x - 50, cap_bot + 22, 1830, cap_bot + 46, 36, ORANGE), 14, (255, 60, 10), 0.55))
	card.alpha_composite(slanted_bar(x - 50, cap_bot + 22, 1830, cap_bot + 46, 36, ORANGE))
	card.alpha_composite(slanted_bar(x - 50, cap_top - 40, x + 210, cap_top - 28, 36, (255, 150, 60)))
	# The name: soft dark shadow, then the outlined white capitals.
	name = text_layer(x, y, text, font, track, (255, 255, 255, 255), stroke=5, stroke_fill=(18, 8, 6, 255))
	card.alpha_composite(shadow_of(name, 22, (0, 0, 0), 0.85, (0, 10)))
	card.alpha_composite(name)
	return card


def end_card() -> Image.Image:
	card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	font = load_font(150)
	track = 8
	text = "FIRST-PERSON BEAT-EM-UP"
	tw = spaced_width(font, text, track)
	x = (W - tw) / 2
	y = 400
	title = text_layer(x, y, text, font, track, (255, 255, 255, 255))
	# Faint warm glow (two blurs: wide and tight) and a dark shadow so the white holds over the lit chimney.
	card.alpha_composite(shadow_of(title, 6, (0, 0, 0), 0.7, (0, 5)))
	card.alpha_composite(shadow_of(title, 38, (255, 120, 40), 0.55))
	card.alpha_composite(shadow_of(title, 12, (255, 170, 90), 0.35))
	card.alpha_composite(title)
	sub_font = load_font(34)
	sub = "Proof of concept · In-engine gameplay, AI-restyled"
	stw = spaced_width(sub_font, sub, 3)
	sy = y + font.getbbox("F")[3] + 56
	subl = text_layer((W - stw) / 2, sy, sub, sub_font, 3, (236, 226, 214, 235))
	card.alpha_composite(shadow_of(subl, 5, (0, 0, 0), 0.9, (0, 2)))
	card.alpha_composite(subl)
	return card


def frame(src: Path, n: int, dest: Path) -> Image.Image:
	subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(src), "-vf", f"select=eq(n\\,{n}),scale={W}:{H}", "-fps_mode", "vfr",
		"-frames:v", "1", str(dest)], check=True)
	return Image.open(dest).convert("RGBA")


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	ox, end = ox_card(), end_card()
	ox.save(OUT / "ox_name_card.png")
	end.save(OUT / "end_title.png")
	tmp = OUT / "_frame.png"
	for card, src, n, name in (
		(ox, P / "restyle/t10_r1/t10_r1.mp4", 60, "preview_ox.jpg"),
		(end, P / "inputs/t14_title_embers_1080.mp4", 48, "preview_end.jpg"),
	):
		bg = frame(src, n, tmp)
		bg.alpha_composite(card)
		bg.convert("RGB").save(OUT / name, quality=92)
	tmp.unlink()
	print("wrote", *sorted(p.name for p in OUT.iterdir()))


if __name__ == "__main__":
	main()
