"""Builds the M6 concept pick sheets in assets/source/concepts/m6/sheets/ (Pillow)."""
import os
import textwrap
from PIL import Image, ImageDraw, ImageFont

BASE = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "assets/source/concepts/m6")
try:
	FONT = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 30)
	SMALL = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 22)
except OSError:
	FONT = SMALL = ImageFont.load_default()

def sheet(name, stems, cols, w, notes=None, note_h=0):
	imgs = [Image.open(os.path.join(BASE, s + ".jpg")).convert("RGB") for s in stems]
	cw = w // cols
	ch = int(cw * imgs[0].height / imgs[0].width)
	out = Image.new("RGB", (cols * cw, ((len(imgs) + cols - 1) // cols) * (ch + note_h)), (40, 40, 44))
	d = ImageDraw.Draw(out)
	for i, im in enumerate(imgs):
		x, y = (i % cols) * cw, (i // cols) * (ch + note_h)
		out.paste(im.resize((cw, ch)), (x, y))
		d.rectangle([x, y, x + 46, y + 46], fill=(20, 20, 20))
		d.text((x + 12, y + 6), "ABCD"[i % cols if cols > 1 and len(imgs) <= cols else i % 4], fill=(255, 255, 255), font=FONT)
		if notes:
			ty = y + ch + 6
			for line in textwrap.wrap(notes[i], 52):
				d.text((x + 10, ty), line, fill=(235, 235, 235), font=SMALL)
				ty += 28
	out.save(os.path.join(BASE, "sheets", name))

for t in ("kicker", "thug", "bruiser"):
	sheet(t + ".png", [t + "_a", t + "_b", t + "_c"], 3, 1600)
sheet("boss.png", ["boss_a", "boss_b", "boss_c"], 3, 1600,
	["A: Gravel Haskin, biker-gang chief", "B: Hollis Gantry, dockyard enforcer", "C: Ox Pellerin, underground-fight champion"], 40)
sheet("weapon.png", ["weapon_a", "weapon_b", "weapon_c"], 3, 1600,
	["A: bike chain and padlock. Short whip: a fast sideways arc, the padlock lands last, medium reach.",
	 "B: tow chain and hook. Slow overhead swing: long reach, a late heavy hit with a wide arc.",
	 "C: wrench-bar. Compact diagonal chop: short reach, quick, closest to the pipe."], 120)
sheet("moods.png", ["mood_street_a", "mood_street_b", "mood_roof_a", "mood_roof_b"], 2, 1600)
