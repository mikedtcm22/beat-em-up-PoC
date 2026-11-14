"""M7 spike S1: drawn sprite characters (offline composite). Not shippable; quick and honest.

Layers per moment come from deterministic bot recordings that differ only in which rigs are drawn:
  orig  = the normal trailer-profile frame        (captures/m7-slice/merged3/trailer/stills)
  plate = the same frame with every HumanoidRig hidden  (--hide_rigs)
  nop   = (arms only) the frame with just the player's rig hidden (--hide_rigs=player): the Punk without the arms in front
Sprite pixels = (frame with the layer, masked by the diff to the frame without it). The cut goes to Gemini on flat chroma green
with the trailer frames as style reference; the drawn result is keyed back out and composited over the plate.

  python3 tools/spikes/s1_sprites.py cut  <with.png> <without.png> <out_prefix>     -> _mask.png, _cut.png (green), _bbox.json
  python3 tools/spikes/s1_sprites.py key  <drawn.png> <out_prefix>                  -> _drawn_rgba.png (placed in the bbox)
  python3 tools/spikes/s1_sprites.py comp <plate.png> <out.png> <layer_rgba.png>... (+ optional --shadow x,y,w,h per layer)
"""
import json
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

GREEN = (0, 255, 0)
SIZE = (1600, 900)
# Ratios Gemini takes, as (w, h) of the padded crop.
RATIOS = {"1:1": 1.0, "3:4": 0.75, "4:3": 4 / 3, "2:3": 2 / 3, "3:2": 1.5, "9:16": 9 / 16, "16:9": 16 / 9, "4:5": 0.8, "5:4": 1.25}
HUD = (0, 740, 450, 900)  # the game's HP panel stays as drawn: never part of a cut


def diff_mask(a: Image.Image, b: Image.Image, thresh: int = 10) -> Image.Image:
	d = ImageChops.difference(a.convert("RGB"), b.convert("RGB"))
	r, g, bl = d.split()
	m = ImageChops.lighter(ImageChops.lighter(r, g), bl)
	m = m.point(lambda v: 255 if v > thresh else 0)
	m = m.filter(ImageFilter.MedianFilter(5))
	m = m.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.MinFilter(7))  # close small gaps
	# fill interior holes
	padded = Image.new("L", (m.width + 2, m.height + 2), 0)  # a black frame, so the fill starts outside any limb touching the edge
	padded.paste(m, (1, 1))
	inv = ImageChops.invert(padded)
	ImageDraw.floodfill(inv, (0, 0), 128)
	m = inv.point(lambda v: 0 if v == 128 else 255).crop((1, 1, m.width + 1, m.height + 1))
	m = m.filter(ImageFilter.MaxFilter(3))
	ImageDraw.Draw(m).rectangle(HUD, fill=0)
	return m


def cut(with_png: str, without_png: str, prefix: str, xrange_: str = "", zero: str = "") -> None:
	a = Image.open(with_png).convert("RGB")
	b = Image.open(without_png).convert("RGB")
	m = diff_mask(a, b, int(os.environ.get("S1_THRESH", "10")))
	if zero:  # blank a rectangle (an effect that is not part of the layer): "x0,y0,x1,y1"
		ImageDraw.Draw(m).rectangle(tuple(int(v) for v in zero.split(",")), fill=0)
	if xrange_ and xrange_ != "-":  # keep one character of several: "x0,x1"
		x0_, x1_ = (int(v) for v in xrange_.split(","))
		if x0_ > 0:
			ImageDraw.Draw(m).rectangle((0, 0, x0_ - 1, SIZE[1]), fill=0)
		ImageDraw.Draw(m).rectangle((x1_, 0, SIZE[0], SIZE[1]), fill=0)
	m.save(prefix + "_mask.png")
	box = m.getbbox()
	if box is None:
		sys.exit("empty mask")
	x0, y0, x1, y1 = box
	pad = 24
	x0, y0, x1, y1 = max(0, x0 - pad), max(0, y0 - pad), min(SIZE[0], x1 + pad), min(SIZE[1], y1 + pad)
	w, h = x1 - x0, y1 - y0
	# pad the crop to the nearest ratio Gemini offers (green fill), growing outward, kept inside nothing: the canvas may extend off-frame.
	ratio_name, ratio = min(RATIOS.items(), key=lambda kv: abs(kv[1] - w / h))
	if w / h < ratio:
		nw, nh = round(h * ratio), h
	else:
		nw, nh = w, round(w / ratio)
	cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
	cx0, cy0 = round(cx - nw / 2), round(cy - nh / 2)
	canvas = Image.new("RGB", (nw, nh), GREEN)
	flat = Image.new("RGB", SIZE, GREEN)
	flat.paste(a, (0, 0), m)
	canvas.paste(flat, (-cx0, -cy0))
	canvas.save(prefix + "_cut.png")
	json.dump({"canvas": [cx0, cy0, nw, nh], "ratio": ratio_name, "bbox": [x0, y0, x1, y1]}, open(prefix + "_bbox.json", "w"))
	print(prefix, "bbox", box, "canvas", (cx0, cy0, nw, nh), ratio_name)


def key_green(img: Image.Image) -> Image.Image:
	"""Chroma key: pixels whose green dominates both other channels are background; soft edge by distance."""
	rgb = img.convert("RGB")
	r, g, b = rgb.split()
	# dominance = g - max(r, b)
	dom = ImageChops.subtract(g, ImageChops.lighter(r, b))
	alpha = dom.point(lambda v: 255 if v < 40 else (0 if v > 110 else int(255 * (110 - v) / 70)))
	alpha = alpha.filter(ImageFilter.MedianFilter(3))
	# despill: clamp green to max(r, b) along the edge
	g2 = ImageChops.darker(g, ImageChops.lighter(r, b).point(lambda v: min(255, v + 18)))
	out = Image.merge("RGB", (r, g2, b))
	out.putalpha(alpha)
	return out


def key(drawn_png: str, prefix: str) -> None:
	info = json.load(open(prefix + "_bbox.json"))
	cx0, cy0, nw, nh = info["canvas"]
	d = Image.open(drawn_png).convert("RGB").resize((nw, nh), Image.LANCZOS)
	rgba = key_green(d)
	if os.environ.get("S1_CLIP"):  # hold the old silhouette (grown a little): the drawing may not spill past the 3D shape
		sil = Image.open(prefix + "_mask.png").crop((cx0, cy0, cx0 + nw, cy0 + nh)) if cx0 >= 0 and cy0 >= 0 else None
		if sil is None:
			full = Image.new("L", (max(nw + cx0, SIZE[0]) + abs(cx0), max(nh + cy0, SIZE[1]) + abs(cy0)), 0)
			full.paste(Image.open(prefix + "_mask.png"), (max(0, -cx0), max(0, -cy0)))
			sil = full.crop((max(0, -cx0) + cx0, max(0, -cy0) + cy0, max(0, -cx0) + cx0 + nw, max(0, -cy0) + cy0 + nh))
		sil = sil.filter(ImageFilter.MaxFilter(int(os.environ["S1_CLIP"]) | 1)).filter(ImageFilter.GaussianBlur(1.5))
		rgba.putalpha(ImageChops.multiply(rgba.getchannel("A"), sil))
	full = Image.new("RGBA", SIZE, (0, 0, 0, 0))
	full.paste(rgba, (cx0, cy0))
	full.save(prefix + "_drawn_rgba.png")


def blob_shadow(size, box) -> Image.Image:
	"""A simple drawn contact blob: dark ellipse at the feet, hard-ish edge, flat tone."""
	x, y, w, h = box
	layer = Image.new("RGBA", size, (0, 0, 0, 0))
	ImageDraw.Draw(layer).ellipse((x - w / 2, y - h / 2, x + w / 2, y + h / 2), fill=(14, 12, 40, 150))
	return layer.filter(ImageFilter.GaussianBlur(3))


def comp(plate: str, out: str, rest: list) -> None:
	base = Image.open(plate).convert("RGBA")
	plate_rgb = base.copy()
	i = 0
	while i < len(rest):
		layer = rest[i]
		i += 1
		if i < len(rest) and rest[i] == "--shadow":
			box = [float(v) for v in rest[i + 1].split(",")]
			base = Image.alpha_composite(base, blob_shadow(base.size, box))
			i += 2
		base = Image.alpha_composite(base, Image.open(layer).convert("RGBA"))
	panel = Image.new("L", SIZE, 0)  # the HP panel's parallelogram: the game draws it, so it goes back on top as drawn
	ImageDraw.Draw(panel).polygon([(52, 756), (441, 756), (428, 864), (36, 862)], fill=255)
	base.paste(plate_rgb, (0, 0), panel)
	base.convert("RGB").save(out)


if __name__ == "__main__":
	cmd = sys.argv[1]
	if cmd == "cut":
		cut(*sys.argv[2:7])
	elif cmd == "key":
		key(*sys.argv[2:4])
	elif cmd == "comp":
		comp(sys.argv[2], sys.argv[3], sys.argv[4:])
