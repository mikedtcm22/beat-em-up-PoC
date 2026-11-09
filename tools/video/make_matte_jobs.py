"""Write the Gemini jobs for the video's painted backdrops (LD-WORLD3, docs/video/P1.md, "A+ is approved").

The far buildings of the street and the roofs, and the boss roof's sky, fire and smoke, are painted as matte backdrops that the world
look hangs as cards behind the playfield (video/world/matte_card.gd). Each job gives Gemini the style references (frames of the two
reference videos: look-dev inputs, never committed) and a prompt for a flat, graphic, hand-painted plate: no characters, no text, no
logos, and a sky that is a flat key colour where the card must be cut out (tools/video/key_mattes.py).

Usage:
  ~/.venvs/beat-em-up-video/bin/python -I tools/video/make_matte_jobs.py <ref frames dir> <run dir> [--record <dir>] [job ...]
Writes <run dir>/jobs.json and JPEG reference copies in <run dir>/in/, for `python3 -I tools/gemini_image.py <run dir>/jobs.json`.
--record also writes the jobs file and the prompts, without the images, to <dir> (assets/source/video_mattes/), the committed source.
Append the batch to docs/video/gemini_ledger.md before running it.
"""
from __future__ import annotations

import json
import os
import sys

from PIL import Image

INPUT_WIDTH = 1600
JPEG_QUALITY = 90

STYLE = ("A hand-painted 2D background plate for a flat, graphic TV anime, in the exact art style of the reference "
	"frames (like Castlevania Nocturne or Primal): flat colour fields, hard angular shadow shapes with a few painted "
	"brush strokes inside them, bold dark ink only on the big structures and none on small detail, and simplified "
	"into the distance. It is a matte painting seen straight on, like a theatre backdrop. No characters, no people, no "
	"vehicles, no text, no letters, no logos, no signs with writing, and nothing from Star Wars.")

KEY_SKY = ("Everything above the skyline, the whole sky, is one perfectly flat, solid, pure green (#00FF00) with nothing "
	"in it: no gradient, no clouds, no stars, no glow, no haze, no lines, and it must touch the skyline cleanly so it can "
	"be keyed out.")

STREET_FAR = ("The far end of a city street at night, as a skyline strip of distant tall brick apartment blocks and "
	"warehouses side by side, seen from far away. Deep navy and indigo with a cold moonlit edge on the roofs; the "
	"windows are mostly dark flat shapes with a few lit warm orange and some blinds, no window frames and no brick "
	"drawn, only big simple shapes with a few water towers, chimneys and antenna masts on the roofs. The blocks vary a "
	"lot in height and width, with no repeated building. Their lower part sinks into dark haze at the bottom edge of "
	"the image.")

ROOF_FAR = ("A far city skyline at dusk, seen from a rooftop: layered silhouettes of apartment blocks, water towers, "
	"chimneys and antenna masts in three planes, the nearest plane the darkest violet-maroon and each farther plane "
	"lighter and warmer, rose and amber, fading into the sunset haze at the horizon; a few windows catch the sun. The "
	"buildings vary a lot in height and width, with no repeated building and no drawn brick or window frames, only big "
	"simple shapes.")

BOSS_SKY = ("A wall of fire and smoke behind a city at night, in the style of the reference frames' painted fire: a "
	"violet-black sky at the top; billowing smoke masses painted in large hard-edged, layered shapes, lit orange and "
	"red from below, their upper sides dark violet-maroon; a glowing lava-orange and amber fire wall along the horizon "
	"with huge rolling flames and a few yellow-white hot cores; sparks and embers drifting in the air, varied in size. "
	"The fire is made of big overlapping curved shapes, never a regular row of spikes. Along the bottom edge there is "
	"a strip of dark far rooftops in silhouette. Nothing is drawn as a figure.")

# job name -> (prompt, aspect, reference frames (in the ref dir))
JOBS = {
	"street_far_a": (STREET_FAR + " " + KEY_SKY, "21:9", ["ref2_42.0.png", "ref2_3.5.png"]),
	"street_far_b": (STREET_FAR + " The blocks are lower and wider than in a tower district. " + KEY_SKY, "21:9",
		["ref2_3.5.png", "ref2_42.0.png"]),
	"roof_far_a": (ROOF_FAR + " " + KEY_SKY, "21:9", ["ref2_50.5.png", "ref2_42.0.png"]),
	"roof_far_b": (ROOF_FAR + " Fewer, larger blocks, with the sun's glare on their edges. " + KEY_SKY, "21:9",
		["ref2_50.5.png", "ref2_3.5.png"]),
	"boss_sky_a": (BOSS_SKY, "16:9", ["ref1_5.3.png", "ref1_24.4.png"]),
	"boss_sky_b": (BOSS_SKY + " The fire is lower and the smoke fills most of the frame.", "16:9",
		["ref1_24.4.png", "ref1_5.3.png"]),
	"boss_sky_c": (BOSS_SKY + " Make it darker overall: the fire is a narrow glow under heavy smoke.", "16:9",
		["ref1_5.3.png", "ref1_7.2.png"]),
}


def to_jpeg(src: str, dst: str) -> None:
	im = Image.open(src).convert("RGB")
	if im.width > INPUT_WIDTH:
		im = im.resize((INPUT_WIDTH, int(round(im.height * INPUT_WIDTH / im.width))), Image.LANCZOS)
	im.save(dst, quality=JPEG_QUALITY)


def main() -> None:
	argv = sys.argv[1:]
	record = ""
	if "--record" in argv:
		i = argv.index("--record")
		record = argv[i + 1]
		del argv[i:i + 2]
	refs, out = argv[0], argv[1]
	only = set(argv[2:])
	os.makedirs(os.path.join(out, "in"), exist_ok=True)
	jobs = []
	for name, (prompt, aspect, ref_names) in JOBS.items():
		if only and name not in only:
			continue
		ref_paths = []
		for r in ref_names:
			rp = os.path.join("in", os.path.splitext(r)[0] + ".jpg")
			if not os.path.exists(os.path.join(out, rp)):
				to_jpeg(os.path.join(refs, r), os.path.join(out, rp))
			ref_paths.append(rp)
		jobs.append({"out": f"{name}.png", "prompt": prompt, "model": "gemini-3-pro-image", "aspect": aspect,
			"size": "2K", "refs": ref_paths})
	with open(os.path.join(out, "jobs.json"), "w") as f:
		json.dump(jobs, f, indent=1)
	print(f"wrote {len(jobs)} jobs to {os.path.join(out, 'jobs.json')}")
	if record:
		os.makedirs(record, exist_ok=True)
		with open(os.path.join(record, "jobs.json"), "w") as f:
			json.dump(jobs, f, indent=1)
		print(f"recorded the jobs in {record}/jobs.json (its refs/in/ are not committed)")


if __name__ == "__main__":
	main()
