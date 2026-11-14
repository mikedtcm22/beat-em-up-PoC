"""M7 spike S1: draw the 8 walk poses in order through tools/gemini_image.py (pose 0 is the character sheet)."""
import glob
import json
import os
import subprocess
import sys

D = sys.argv[1]
STYLE = ("Redraw the 3D render (green background) as a hand-drawn 2D animation cel in the art style of the style-reference frame "
	"(confident dark ink outline of varied weight, flat cel-shaded colour in two or three tones, warm orange rim light on one edge, drawn face, drawn fabric folds, no 3D or photographic texture, no noise). "
	"Keep the pose EXACTLY as the render: the same leg positions, foot placement, arm and fist positions, head angle, and the same framing and scale, nothing moved, mirrored, cropped or resized. "
	"The man: grey baseball cap, dark navy puffer vest over a black tank top, grey jeans, dark gloves, dark boots, hard tired face. Front view, guard stance, walking. "
	"Background stays perfectly flat pure green #00FF00, no ground, no shadow, no gradient. Output only the drawing.")
CONT = ("IMAGE 1 is the 3D render of this animation frame (green background): redraw it as a 2D cel. IMAGE 2 is the fixed CHARACTER SHEET: the man's face, cap, vest, clothes, proportions, colours and line style must match it exactly, as if the same animator drew every frame. "
	"IMAGE 3 is the previously drawn frame of this same walk cycle: keep the drawing identical to it except where the pose changed. "
	"Keep the pose EXACTLY as the render in image 1: leg positions, foot placement, arm and fist positions, framing and scale; nothing moved, mirrored, cropped or resized. "
	"Background stays perfectly flat pure green #00FF00, no ground, no shadow, no gradient. Output only the drawing.")


def drawn(i):
	g = glob.glob(os.path.join(D, f"drawn{i}.*"))
	return os.path.basename(g[0]) if g else None


for i in range(8):
	if drawn(i):
		continue
	if i == 0:
		job = {"out": "drawn0.png", "prompt": STYLE, "aspect": "3:4", "size": "1K", "refs": ["cut0.png", "ref_punk.jpg"]}
	else:
		job = {"out": f"drawn{i}.png", "prompt": CONT, "aspect": "3:4", "size": "1K", "refs": [f"cut{i}.png", drawn(0), drawn(i - 1)]}
	path = os.path.join(D, f"job{i}.json")
	json.dump([job], open(path, "w"))
	out = subprocess.run([sys.executable, "-I", "tools/gemini_image.py", path], capture_output=True, text=True)
	print(i, out.stdout.strip()[-120:], out.stderr.strip()[-200:], flush=True)
	if not drawn(i):
		sys.exit("pose %d failed" % i)
