"""Plan B's full cut (docs/video/HANDOFF.md, 2026-11-10): the keyframe and restyle jobs for the trailer's character shots.

Each shot gets one Gemini paint-over of one of its frames (the keyframe, "traced" so it registers with the frame), made in its
location's reference style, with the keyframes already chosen for the same characters as references so their designs match
across shots. Runway Aleph 2.0 then carries the keyframe through the shot (tools/video/runway_restyle.py).

Usage (from the video worktree):
  python3 -I tools/video/make_planb_jobs.py frames [shot ...]    extract each shot's keyframe frame from its 1080p input
  python3 -I tools/video/make_planb_jobs.py sheet [shot ...]     a sheet of those frames, to check the picks
  python3 -I tools/video/make_planb_jobs.py gemini [shot ...] [--take b]   write keyframes/jobs_cut_<take>.json (gemini_image.py)
  python3 -I tools/video/make_planb_jobs.py pick <shot> <take>   install keyframes/<take> as the shot's 1080p keyframe
  python3 -I tools/video/make_planb_jobs.py restyle [shot ...]   add the shots' jobs to restyle/jobs.json (named <short>_r1)
Paths are under captures/video/planb/: inputs/<key>_1080.mp4 (the encoded render), keyframes/, restyle/.
"""
import json
import os
import shutil
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PLANB = os.path.join(REPO, "captures", "video", "planb")
REFS = os.path.join(REPO, "captures", "video", "ref", "frames")
FPS = 24
SEED = 11

# The location's style reference (image 2) and the words for it, and the light.
LOCATIONS = {
	"street": ("ref2_37.4.png",
		"a flat, graphic TV-anime night scene with big designed flat shadow shapes, a limited navy-and-orange palette, tapered "
		"dark ink lines and painted grain inside the flat fills",
		"Light it as a city street at night: orange sodium street lamps as the key light, cold blue moonlight as the fill, navy "
		"shadows, white steam drawn as flat cel shapes."),
	"roof": ("ref2_50.5.png",
		"a flat, graphic TV-anime dusk scene: a big low sun with flat halo bands, a broad painted sky, simplified planes with "
		"drawn edges, tapered dark ink lines",
		"Light it as a rooftop at dusk with the sun low behind: a warm peach sky, cool violet shadows, the figures back-lit with "
		"one clean warm rim on their lit side and their features drawn and readable in the shadow."),
	"boss": ("ref1_5.3.png",
		"sketchy, tapered ink linework with loose construction strokes and hatching in the darks, flat designed shadow shapes, "
		"and fire and smoke painted in big soft shapes",
		"Light it as a rooftop at night lit by a big fire: a violet-black sky, orange firelight, embers and smoke drifting."),
}

# Character references: keyframes already chosen, and how the prompt names them. The image numbers follow the order given.
CHARACTERS = {
	"punk": ("t03_key_b.jpg", "the street punk (his cap, his face, the vest over a dark tank top, his gloves)"),
	"ox": ("t11_key_d.jpg", "Ox, the huge boss (his hood, the padded armour with a round chest plate, his huge gloves, his face)"),
	"kicker": ("t04_key_pick.jpg", "the kicker (his cap, his goggles, his hoodie, his gloves)"),
	"player": ("t12_key_pick.jpg", "the player, a street fighter with dark hair in a dark vest"),
}

# key: (keyframe frame, location, what the frame shows, character references). t04 sets the kicker's drawn design and t12 the
# player's. The first take of t07 with those picks as references redrew the wide shot as a close two-shot, so t07 has none.
# t09 has no keyframe (the Gemini budget ran out; its first take drew in a second figure): it's restyled from the prompt alone.
SHOTS = {
	"t01_crane_street": (70, "street", "A high view down onto a night street: a chain fence, a lamp post, a steam column, a fire "
		"barrel and the small figures of the player and street punks fighting below.", []),
	"t02_guard_up": (27, "street", "First person: the street punk faces the camera in an alley at night, his fists up by his "
		"face, with steam columns and a chain fence behind him.", ["punk"]),
	"t04_block_spin": (0, "street", "First person: the kicker, a street fighter in a cap with goggles and a hoodie, faces the "
		"camera with his fists up in an alley at night, with steam and a fire barrel behind him.", []),
	"t05_grab_throw": (36, "street", "First person: a big thug is grabbed and thrown over the player's shoulder in an alley at "
		"night.", []),
	"t06_pipe_chain": (0, "street", "The bruiser, a bulky street fighter, stands in an alley at night beside a big steam cloud, "
		"behind a chain fence.", []),
	"t07_roof_knockoff": (34, "roof", "A wide rooftop at dusk against the low sun: the kicker and the player fight by the "
		"parapet on the left, a water tower on the right, the city skyline behind.", []),
	"t08_chain_whip": (0, "roof", "First person on a rooftop at dusk: two street punks in caps face the camera with their "
		"fists up, with stairs and a brick wall behind them.", ["punk"]),
	"t09_back_elbow": (0, "roof", "First person on a rooftop at dusk: the kicker stands facing the camera at a distance, his "
		"fists up, in front of wide stairs and a brick wall.", ["kicker"]),
	"t10_ox_reveal": (38, "boss", "Ox, the huge boss, stands at the left before a giant wall of fire on a rooftop at night, "
		"one arm out.", ["ox"]),
	"t12_haymaker": (0, "boss", "Ox, the huge boss (left), swings a haymaker at the player, a fighter in a vest seen from "
		"behind (right), before a giant wall of fire.", ["ox"]),
	"t13_ox_falls": (16, "boss", "Ox, the huge boss, close and towering before the fire on a rooftop at night, his gloves "
		"raised.", ["ox"]),
}

# Retakes (take "b"): one sentence each, for what the first take changed. Batch A's character references pulled whole figures
# and poses from the reference image into the frame (t10, t12, t13), and t05's thug grew.
RETAKE_NOTES = {
	"t05_grab_throw": "Trace the big man's back, the strap with its buckle and the fist exactly at their size and place in image 1; "
		"do not enlarge him.",
	"t10_ox_reveal": "Ox stays small at the far left edge of the frame exactly where he is in image 1, one arm out toward the fire; "
		"the fire fills the rest of the frame.",
	"t12_haymaker": "Ox's two huge gloves are raised in front of him mid-swing exactly as in image 1; his arms are not crossed.",
	"t07_roof_knockoff": "The two fighters stay small at the left by the parapet exactly as in image 1; most of the frame is the "
		"rooftop, the water tower and the sky.",
	"t13_ox_falls": "This is a close-up: Ox's head, shoulders and huge gloves fill the frame exactly as in image 1, his face near "
		"the top centre; do not show his whole body.",
}

PROMPT = ("Trace image 1 and ink and paint it as a hand-drawn 2D anime frame in the art style of image 2 ({style}). This is a "
	"paint-over: every shape stays where it is in image 1, at the same size and in the same place: the camera, the framing, "
	"the composition, the characters' poses and the background's layout. {scene} {chars}Draw the characters with designed "
	"flat cel shadow shapes, tapered ink lines (heavier on the shadow side), drawn faces with readable features wherever a "
	"face shows, gloves with drawn knuckles and finger breaks, and fold lines in the clothes; no 3D gradients, no plastic "
	"highlights, no noisy rim. {light} No new objects or characters, no text, no subtitles, no watermark{extra}.")


def short(key: str) -> str:
	return key.split("_")[0]


def frame_path(key: str) -> str:
	return os.path.join(PLANB, "keyframes", f"{key}_f{SHOTS[key][0]:03d}.jpg")


def cmd_frames(keys: list) -> None:
	for key in keys:
		src = os.path.join(PLANB, "inputs", f"{key}_1080.mp4")
		n = SHOTS[key][0]
		subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", src, "-vf", f"select=eq(n\\,{n})", "-fps_mode", "vfr",
			"-frames:v", "1", "-q:v", "2", frame_path(key)], check=True)
		print(f"{key}: frame {n} -> {os.path.relpath(frame_path(key), REPO)}")


def cmd_sheet(keys: list) -> None:
	out = os.path.join(PLANB, "sheets", "cut_keyframe_frames.jpg")
	inputs = []
	for key in keys:
		inputs += ["-i", frame_path(key)]
	cols = 4
	filt = "".join(f"[{i}]scale=640:360[s{i}];" for i in range(len(keys)))
	filt += "".join(f"[s{i}]" for i in range(len(keys))) + f"xstack=inputs={len(keys)}:layout="
	filt += "|".join(f"{(i % cols) * 640}_{(i // cols) * 360}" for i in range(len(keys))) + ":fill=white"
	subprocess.run(["ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", filt, "-frames:v", "1", "-q:v", "3", out],
		check=True)
	print(f"wrote {os.path.relpath(out, REPO)} ({cols} a row, in the order {', '.join(short(k) for k in keys)})")


def cmd_gemini(keys: list, take: str = "a") -> None:
	kdir = os.path.join(PLANB, "keyframes")
	jobs = []
	for key in keys:
		n, loc, scene, chars = SHOTS[key]
		ref, style, light = LOCATIONS[loc]
		if not os.path.isfile(os.path.join(kdir, ref)):
			shutil.copy(os.path.join(REFS, ref), kdir)
		refs = [os.path.basename(frame_path(key)), ref]
		named = []
		for c in chars:
			image, words = CHARACTERS[c]
			refs.append(image)
			named.append(f"Image {len(refs)} shows {words}, already drawn in this style: it is only for how he looks. Take "
				"his pose, size, place and framing from image 1 alone.")
		note = RETAKE_NOTES.get(key, "") + " " if take != "a" else ""
		prompt = PROMPT.format(style=style, scene=scene + (" " + note.strip() if note else ""),
			chars=" ".join(named) + (" " if named else ""), light=light, extra=", nothing from Star Wars" if loc == "boss" else "")
		jobs.append({"out": f"{short(key)}_key_{take}.png", "model": "gemini-3-pro-image", "aspect": "16:9", "size": "2K",
			"refs": refs, "prompt": prompt})
	path = os.path.join(kdir, f"jobs_cut_{take}.json")
	with open(path, "w") as f:
		json.dump(jobs, f, indent=1)
	print(f"wrote {len(jobs)} jobs to {os.path.relpath(path, REPO)}")


def cmd_pick(key: str, take: str) -> None:
	kdir = os.path.join(PLANB, "keyframes")
	out = os.path.join(kdir, f"{short(key)}_key_1080.jpg")
	subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", os.path.join(kdir, take), "-vf", "scale=1920:1080:flags=lanczos",
		"-q:v", "1", out], check=True)
	# The full-size pick is the character reference for later shots (CHARACTERS).
	shutil.copy(os.path.join(kdir, take), os.path.join(kdir, f"{short(key)}_key_pick.jpg"))
	print(f"{key}: {take} -> {os.path.relpath(out, REPO)}")


def cmd_restyle(keys: list) -> None:
	path = os.path.join(PLANB, "restyle", "jobs.json")
	with open(path) as f:
		jobs = json.load(f)
	for key in keys:
		n, loc, _scene, _chars = SHOTS[key]
		name = f"{short(key)}_r1"
		keyframe = os.path.join(PLANB, "keyframes", f"{short(key)}_key_1080.jpg")
		ink = {"street": "a navy night palette with orange street-lamp light", "roof": "a warm dusk palette with the low sun "
			"behind", "boss": "sketchy ink with hatching in the darks, orange firelight and painted smoke"}[loc]
		target = "to match the keyframe" if os.path.isfile(keyframe) else "as"
		job = {"name": name, "video": f"../inputs/{key}_1080.mp4", "out": name, "seed": SEED,
			"prompt": f"Restyle the whole video {target}: hand-drawn 2D anime, flat cel shadow shapes, tapered "
				f"dark ink outlines, {ink}, drawn faces and gloves. Keep the camera motion, composition, character actions "
				"and timing exactly."}
		if os.path.isfile(keyframe):
			job["keyframes"] = [{"image": f"../keyframes/{short(key)}_key_1080.jpg", "seconds": round(n / FPS, 3)}]
		jobs = [j for j in jobs if j["name"] != name] + [job]
		print(f"{name}: " + (f"keyframe at {job['keyframes'][0]['seconds']} s" if "keyframes" in job else "the prompt alone"))
	with open(path, "w") as f:
		json.dump(jobs, f, indent=1)


def main() -> None:
	if len(sys.argv) < 2:
		sys.exit(__doc__)
	cmd, rest = sys.argv[1], sys.argv[2:]
	take = "a"
	if "--take" in rest:
		i = rest.index("--take")
		take = rest[i + 1]
		rest = rest[:i] + rest[i + 2:]
	if cmd == "pick":
		cmd_pick(rest[0], rest[1])
		return
	keys = [k for k in SHOTS if not rest or k in rest or short(k) in rest]
	if cmd == "gemini":
		cmd_gemini(keys, take)
		return
	{"frames": cmd_frames, "sheet": cmd_sheet, "restyle": cmd_restyle}[cmd](keys)


if __name__ == "__main__":
	main()
