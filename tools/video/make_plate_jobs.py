"""Write the Gemini job for one plate (round 5, R5-PAINT; docs/video/P1.md): a paint-over of a blockout capture.

The blockout is tools/video/plate_capture.sh's `<name>_blockout.png`: the world as flat masses from the shot's own camera, with no people, steam or
lens effects. Gemini (gemini-3-pro-image, image to image, 2K, 16:9) repaints it as the finished hand-painted background of a 2D TV anime, tracing the
blockout's camera, horizon and masses; the second input is one style swatch (a reference frame, or the location's approved plate).

Usage:
  ~/.venvs/beat-em-up-video/bin/python -I tools/video/make_plate_jobs.py <shot key> <blockout png> <swatch png> <location> <out dir> [--name plate_0] [--take N]
    location: street | dusk | boss
Writes <out dir>/jobs.json, <name>_blockout.jpg and <name>_swatch.jpg (1920 px wide: a request stays well under the API's size limit) and prompt.txt, for
`python3 -I tools/gemini_image.py <out dir>/jobs.json`; the painting lands at <out dir>/<name>_gemini<take>.<ext>. Append the batch to
docs/video/gemini_ledger.md BEFORE running it and its result after. tools/video/make_plate.sh does all of it.
"""
from __future__ import annotations

import json
import os
import sys

from PIL import Image

INPUT_WIDTH = 1920
JPEG_QUALITY = 92

CORE = ("Paint-over. Repaint image 1 as the finished hand-painted background of a 2D TV anime (Castlevania: Nocturne, Primal). "
	"Image 2 is a style swatch: copy its brushwork, edges and value handling, not its content. "
	"Trace, don't redesign: keep the camera, horizon, vanishing points and the outline of every large mass at the same pixel positions; "
	"add, remove or move nothing large. No people, text, steam or lens effects. "
	"Big flat shapes cut with a flat brush, freehand straight edges, no rendered gradients, specular highlights or shadow-map shadows; "
	"shadows are designed flat shapes. "
	"Detail as hand-placed clusters where light falls (some brick near a lamp, varied windows, pipes, cracks), one flat colour per plane elsewhere; "
	"never a grid or a repeated unit. "
	"Darks are deep coloured values (blue-violet, plum), never black. "
	"The distance is lighter, cooler, lower in contrast, simpler and softer-edged. "
	"A soft glow at each lamp head and no light cones.")

LOCATIONS = {
	"street": ("At most three to five grouped, different windows on a facade; every window differs in size, shape and light. "
		"One ground plane with a few cracks and two or three puddles reflecting the lamps. "
		"Soft warm pools of lamp light that climb the wall bases. Moonlight only on up-facing edges. "
		"The far end of the street in blue-grey haze. The fence is drawn as a few sagging strokes, never a lattice."),
	"dusk": ("One large pale sun with a single smooth glow (no rings or bands). A peach-to-lavender sky with two or three long thin clouds. "
		"The far city as two or three flat layered silhouettes. The towers backlit plum with a hot rim. "
		"The roof's walls and parapet as a few large flat planes with sparse hand-placed brick."),
	"boss": ("Keep the fire sky. The buildings as warm near-black silhouettes rimmed orange toward the fire; low smoke. "
		"The roof's wall as a few large flat planes with sparse hand-placed brick, lit orange from below."),
}


def jpeg(src: str, dst: str) -> None:
	image = Image.open(src).convert("RGB")
	if image.width != INPUT_WIDTH:
		image = image.resize((INPUT_WIDTH, round(image.height * INPUT_WIDTH / image.width)), Image.LANCZOS)
	image.save(dst, "JPEG", quality=JPEG_QUALITY)


def main(argv: list[str]) -> int:
	name = "plate_0"
	take = 1
	args = []
	i = 0
	while i < len(argv):
		if argv[i] == "--name":
			name = argv[i + 1]
			i += 2
		elif argv[i] == "--take":
			take = int(argv[i + 1])
			i += 2
		else:
			args.append(argv[i])
			i += 1
	if len(args) != 5:
		sys.exit(__doc__)
	shot, blockout, swatch, location, out_dir = args
	if location not in LOCATIONS:
		sys.exit("location must be one of %s" % ", ".join(LOCATIONS))
	os.makedirs(out_dir, exist_ok=True)
	jpeg(blockout, os.path.join(out_dir, "%s_blockout.jpg" % name))
	jpeg(swatch, os.path.join(out_dir, "%s_swatch.jpg" % name))
	prompt = "%s %s" % (CORE, LOCATIONS[location])
	jobs_path = os.path.join(out_dir, "jobs.json")
	jobs = []
	if os.path.exists(jobs_path):
		with open(jobs_path) as f:
			jobs = [job for job in json.load(f) if job["out"] != "%s_gemini%d.png" % (name, take)]
	jobs.append({
		"out": "%s_gemini%d.png" % (name, take),
		"prompt": prompt,
		"model": "gemini-3-pro-image",
		"aspect": "16:9",
		"size": "2K",
		"refs": ["%s_blockout.jpg" % name, "%s_swatch.jpg" % name],
	})
	with open(jobs_path, "w") as f:
		json.dump(jobs, f, indent="\t")
	with open(os.path.join(out_dir, "prompt_%s_take%d.txt" % (name, take)), "w") as f:
		f.write("shot %s, %s, location %s, take %d\n\n%s\n" % (shot, name, location, take, prompt))
	print("wrote %s (%d job(s)); run: python3 -I tools/gemini_image.py %s %s_gemini%d" % (jobs_path, len(jobs), jobs_path, name, take))
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
