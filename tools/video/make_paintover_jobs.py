"""Write the Gemini paint-over jobs for the Gate 1 targets (docs/video/PLAN.md §4 and §6, Phase 0).

Each of our six stills is repainted in the style of its matching reference frame: our frame first,
then two reference frames from the same video as style references, with PLAN.md §6's prompt. The
targets are look-dev bars only: never in the video.

Usage:
  ~/.venvs/beat-em-up-video/bin/python -I tools/video/make_paintover_jobs.py <stills dir> <ref frames dir> <out dir> [still ...]
Writes <out dir>/jobs.json and JPEG inputs (1920 px wide, so a request stays well under the API's
size limit), for `python3 -I tools/gemini_image.py <out dir>/jobs.json`. Append the batch to
docs/video/gemini_ledger.md before running it.
"""
from __future__ import annotations

import json
import os
import sys

from PIL import Image

INPUT_WIDTH = 1920
JPEG_QUALITY = 92

REF1 = ("sketch-ink anime with painted fire. Warm brown-black ink lines, never pure black. In close-ups the "
	"lines are sketchy: several overlapping strokes, construction lines that overshoot corners, and short "
	"hatching strokes for form (brow, cheekbones, beard, cloth folds); in mid and wide shots the lines thin "
	"out and figures read as rim-lit silhouettes. Hard-edged shadow shapes, two or three values to a "
	"material, with painted texture inside them; no 3D gradients and no plastic highlights. Saturated "
	"violet-maroon darks, never grey. Strong rim light in the key colour. Haze in every shot, smoke painted "
	"in large soft shapes, drifting embers and sparks, and heavy bloom on light sources")
REF2_NIGHT = ("flat, graphic TV anime at night. Bold, clean dark outlines with little hatching. Flat colour "
	"fields with hard, angular shadow shapes; painted matte backgrounds with graphic shapes and texture. A "
	"night palette of navy and indigo with cold moonlight, and warm orange light on faces and walls")
REF2_SUNSET = ("flat, graphic TV anime at sunset. Bold, clean dark outlines with little hatching. Flat colour "
	"fields with hard, angular shadow shapes. A dusky gold, rose and violet sky with a huge sun disc and "
	"halo, soft gradients, long shadows, and the figure as a dark silhouette against the sun")

LIGHT_STREET = ("Light it as a city street at night: orange sodium street lamps as the key light, cold blue "
	"moonlight and night sky as the fill, navy shadows")
LIGHT_ROOF = ("Light it as a rooftop at dusk: a low sun behind the figure with a big disc and halo, a gold, rose "
	"and violet sky, long shadows")
LIGHT_BOSS = ("Light it as a rooftop at night lit by fire from below: a violet-black sky, orange firelight and "
	"an orange rim light on the big man, embers and smoke drifting")

# still -> (style, light, [the matching reference frame, a second frame of the same video])
JOBS = {
	"fp_punk": (REF1, LIGHT_STREET, ["ref1_7.2.png", "ref1_0.9.png"]),
	"fp_kicker_lamp": (REF2_NIGHT, LIGHT_STREET, ["ref2_37.4.png", "ref2_42.0.png"]),
	"ox_closeup": (REF1, LIGHT_BOSS, ["ref1_0.9.png", "ref1_27.3.png"]),
	"ox_low": (REF1, LIGHT_BOSS, ["ref1_5.3.png", "ref1_24.4.png"]),
	"street_wide": (REF2_NIGHT, LIGHT_STREET, ["ref2_42.0.png", "ref2_37.4.png"]),
	"roof_silhouette": (REF2_SUNSET, LIGHT_ROOF, ["ref2_50.5.png", "ref2_12.9.png"]),
}

PROMPT = ("Repaint the first image in the exact art style of the other images: {style}. {light}. Keep the "
	"first image's composition, camera, characters, poses, clothes and every object; change only how it is "
	"drawn, painted and lit. Add only atmosphere (haze, smoke or steam, embers, glow); no new objects or "
	"characters. No text, no logos, nothing from Star Wars.")


def to_jpeg(src: str, dst: str) -> None:
	im = Image.open(src).convert("RGB")
	if im.width > INPUT_WIDTH:
		im = im.resize((INPUT_WIDTH, int(round(im.height * INPUT_WIDTH / im.width))), Image.LANCZOS)
	im.save(dst, quality=JPEG_QUALITY)


def main() -> None:
	stills, refs, out = sys.argv[1], sys.argv[2], sys.argv[3]
	only = set(sys.argv[4:])
	os.makedirs(os.path.join(out, "in"), exist_ok=True)
	jobs = []
	for name, (style, light, ref_names) in JOBS.items():
		if only and name not in only:
			continue
		ours = os.path.join("in", f"{name}.jpg")
		to_jpeg(os.path.join(stills, f"{name}.png"), os.path.join(out, ours))
		ref_paths = []
		for r in ref_names:
			rp = os.path.join("in", os.path.splitext(r)[0] + ".jpg")
			if not os.path.exists(os.path.join(out, rp)):
				to_jpeg(os.path.join(refs, r), os.path.join(out, rp))
			ref_paths.append(rp)
		jobs.append({"out": f"target_{name}.png", "prompt": PROMPT.format(style=style, light=light),
			"model": "gemini-3-pro-image", "aspect": "16:9", "size": "2K", "refs": [ours] + ref_paths})
	with open(os.path.join(out, "jobs.json"), "w") as f:
		json.dump(jobs, f, indent=1)
	print(f"wrote {len(jobs)} jobs to {os.path.join(out, 'jobs.json')}")


if __name__ == "__main__":
	main()
