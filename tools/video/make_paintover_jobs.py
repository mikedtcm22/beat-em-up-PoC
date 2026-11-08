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

# Round 2 (Game-boy at Gate 1, 2026-11-08: "the environments are maybe a bit too washed out by
# lighting/glare in places. I'd like there to be more detail in the environments - so that people can
# discern how the player is moving through the game... Use the first 10-15 sec of the pt5 video as a
# reference."): the environment drawn in detail like ref 2's camp (3.5 s) and tent (4.5 s), crisp, no glare.
ENV_STYLE = ("flat, graphic TV anime, like the reference frames. Bold, clean dark ink lines on every structure "
	"and edge. The environment is drawn in rich detail as graphic shapes: brick courses, window frames, doors, "
	"pipes, fire escapes, signs, cracks, puddles and paving are each drawn with ink lines and hard-edged, "
	"angular shadow shapes, with a few painted texture strokes; flat colour fields; crisp and clear, so the "
	"space and the path through it read at a glance. The characters are drawn the same way, with clean ink "
	"lines and hard shadow shapes")
ENV_LIGHT_STREET = ("Light it as a city street at night: a few orange sodium street lamps as small, contained "
	"light sources that make hard-edged pools on the ground, cold blue moonlight as the fill, navy shadows. No "
	"glare, no haze and no bloom: every wall, window, door, pipe, fence and paving slab stays clearly visible "
	"and drawn")
ENV_LIGHT_ROOF = ("Light it as a rooftop at dusk: a low sun behind the figure with a big disc and a banded halo, "
	"a gold, rose and violet sky. The rooftop, parapet, water tanks and the buildings around stay clearly drawn, "
	"with ink lines and hard shadow shapes, not lost in glare")
ENV_LIGHT_BOSS = ("Light it as a rooftop at night: orange firelight from below and an orange rim light on the big "
	"man, a violet-black sky, a few embers. No glare and no smoke wall: the rooftop, the buildings and the skyline "
	"stay clearly drawn in detail")

# still -> (style, light, style references), for --env
ENV_JOBS = {
	"fp_punk": (ENV_STYLE, ENV_LIGHT_STREET, ["ref2_4.5.png", "ref2_3.5.png"]),
	"fp_kicker_lamp": (ENV_STYLE, ENV_LIGHT_STREET, ["ref2_4.5.png", "ref2_3.5.png"]),
	"street_wide": (ENV_STYLE, ENV_LIGHT_STREET, ["ref2_3.5.png", "ref2_4.5.png"]),
	"roof_silhouette": (ENV_STYLE, ENV_LIGHT_ROOF, ["ref2_4.5.png", "ref2_50.5.png"]),
	"ox_low": (ENV_STYLE, ENV_LIGHT_BOSS, ["ref2_4.5.png", "ref2_8.0.png"]),
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
	argv = [a for a in sys.argv[1:] if a != "--env"]
	table = ENV_JOBS if "--env" in sys.argv else JOBS
	stills, refs, out = argv[0], argv[1], argv[2]
	only = set(argv[3:])
	os.makedirs(os.path.join(out, "in"), exist_ok=True)
	jobs = []
	for name, (style, light, ref_names) in table.items():
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
