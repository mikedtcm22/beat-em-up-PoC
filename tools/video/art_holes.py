"""LD-ART2's hole measure: the share of pure #000000 pixels inside the character mask of a rendered still (the Gate 2 finding was 8-10% of the
first-person frames). A pixel counts when all three channels are 0 (the toon's ink and the dark navy are never exactly 0 at 8 bits).
	~/.venvs/beat-em-up-video/bin/python -I tools/video/art_holes.py <frame.png> <mask.png|-> [<frame.png> <mask.png|-> ...]
Prints one line a pair: the share, the character's pixel count, and the pure-black count; exits 1 when any share is 0.1% or more.
"""
import sys

import numpy as np
from PIL import Image

LIMIT = 0.001


def measure(frame_path, mask_path):
	frame = np.asarray(Image.open(frame_path).convert("RGB"))
	# "-" for the mask: the whole frame (the first-person arm is not on the character mask's layer, so the frames are measured whole as well)
	mask = np.ones(frame.shape[:2], bool) if mask_path == "-" else np.asarray(Image.open(mask_path).convert("L")) > 127
	black = (frame.max(axis=2) == 0) & mask
	return float(black.sum()) / max(int(mask.sum()), 1), int(mask.sum()), int(black.sum())


if __name__ == "__main__":
	args = sys.argv[1:]
	bad = False
	for frame, mask in zip(args[0::2], args[1::2]):
		share, n, k = measure(frame, mask)
		print("%s: pure black %.4f%% of %d character pixels (%d)" % (frame, share * 100.0, n, k))
		bad |= share >= LIMIT
	sys.exit(1 if bad else 0)
