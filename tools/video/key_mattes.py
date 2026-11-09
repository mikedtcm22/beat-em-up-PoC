"""Cut the Gemini backdrops of LD-WORLD3 into the matte cards' PNGs (assets/video/mattes/).

A skyline plate has a flat pure-green sky (tools/video/make_matte_jobs.py asks for it): this keys the green to alpha with a soft edge
and despills the green out of the fringe. A full painting (the boss roof's fire and smoke) is kept opaque. Both are resized to the
card's texture width.

Usage:
  ~/.venvs/beat-em-up-video/bin/python -I tools/video/key_mattes.py key <in image> <out png> [width]
  ~/.venvs/beat-em-up-video/bin/python -I tools/video/key_mattes.py opaque <in image> <out png> [width]
"""
from __future__ import annotations

import sys

import numpy as np
from PIL import Image

KEY_LO = 0.18
KEY_HI = 0.42


def key(im: Image.Image) -> Image.Image:
	a = np.asarray(im.convert("RGB"), dtype=np.float32) / 255.0
	r, g, b = a[..., 0], a[..., 1], a[..., 2]
	# How green a pixel is: green over the larger of red and blue (pure key is 1.0, a navy or rose building is 0 or negative).
	greenness = g - np.maximum(r, b)
	alpha = 1.0 - np.clip((greenness - KEY_LO) / (KEY_HI - KEY_LO), 0.0, 1.0)
	# Despill: green never exceeds the mean of red and blue in the kept paint.
	limit = np.maximum(r, b)
	g2 = np.minimum(g, limit)
	out = np.stack([r, g2, b, alpha], axis=-1)
	# A pixel that is almost key keeps no colour of its own: take the neighbour's so the edge filters clean.
	return Image.fromarray((np.clip(out, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8))


def main() -> None:
	mode, src, dst = sys.argv[1], sys.argv[2], sys.argv[3]
	width = int(sys.argv[4]) if len(sys.argv) > 4 else 2048
	im = Image.open(src).convert("RGB")
	if im.width != width:
		im = im.resize((width, int(round(im.height * width / im.width))), Image.LANCZOS)
	out = key(im) if mode == "key" else im.convert("RGBA")
	out.save(dst, optimize=True)
	print(f"{dst}: {out.size}, {mode}")


if __name__ == "__main__":
	main()
