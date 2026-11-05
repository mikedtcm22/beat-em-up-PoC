"""Scale and place a character's Gemini views onto the mannequin's frame (M6 CREW; plain Python with Pillow, no Blender).

	python3 -I tools/pipeline/views_normalize.py <views_dir> [--only front,back,left]

Gemini draws a figure 5-10% taller than the mannequin and with its soles a little low in the frame, so views_check.py
fails the height and feet rows. The figures are flat colour blocks on a flat ground, so the fix is an image edit and no
new generation: the subject (the pixels that differ from the ground by more than the check's tolerance) is scaled uniformly
until its height is the mannequin's, its soles put on the mannequin's feet row and its centre on the image's centre (the
mannequin's own centre for a side view), and the rest is the ground colour. The originals are kept as `<view>_raw.jpg`
beside the result. Reads <views_dir>/views_check.json.
"""
import json
import os
import sys

from PIL import Image, ImageChops


def subject_box(img, ground, tol):
	"""Bounding box (l, t, r, b) of the pixels more than `tol` (summed over channels / 3) from `ground`."""
	diff = ImageChops.difference(img.convert("RGB"), Image.new("RGB", img.size, tuple(ground))).convert("L")
	return diff.point(lambda v: 255 if v > tol else 0).getbbox()


def main(argv):
	vdir = argv[0]
	only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else None
	chk = json.load(open(os.path.join(vdir, "views_check.json")))
	ground = chk["ground_rgb"]
	tol = chk["limits"]["ground_tolerance"]
	for name, spec in chk["views"].items():
		if only and name not in only:
			continue
		path = os.path.join(vdir, spec["image"])
		raw = path.replace(".jpg", "_raw.jpg")
		if not os.path.exists(raw):
			os.replace(path, raw)
		img = Image.open(raw).convert("RGB")
		man = Image.open(os.path.normpath(os.path.join(vdir, spec["mannequin"]))).convert("RGB")
		w, h = img.size
		bm = subject_box(man, [man.getpixel((3, 3))[i] for i in range(3)], tol)
		bi = subject_box(img, ground, tol)
		m_h = (bm[3] - bm[1]) / man.size[1]
		s = m_h * h / (bi[3] - bi[1])
		fig = img.crop(bi)
		fig = fig.resize((max(1, round(fig.size[0] * s)), max(1, round(fig.size[1] * s))), Image.LANCZOS)
		canvas = Image.new("RGB", (w, h), tuple(ground))
		feet = round(bm[3] / man.size[1] * h)
		cx = w / 2 if name in ("front", "back") else (bm[0] + bm[2]) / 2 / man.size[0] * w
		canvas.paste(fig, (round(cx - fig.size[0] / 2), feet - fig.size[1]))
		canvas.save(path, quality=95)
		print("%s: scale %.3f, feet row %d" % (name, s, feet))


if __name__ == "__main__":
	main(sys.argv[1:])
