"""M7 r0: wire a character's trailer maps into the game's art resources, from the files the bake wrote. Pure text; run by tools/pipeline/make_trailer_art.sh.

	python3 tools/pipeline/trailer_wire.py <name>

Reads game/actors/art/<name>_art.tres (the character's M6 art: its id, scene and triangle budget stay as they are) and
assets/export/characters/<name>/trailer/ (<name>_trailer.glb, <name>_paint.png, <name>_ink.png and, when paint.json has "marks", <name>_marks.png), then
  - writes game/actors/art/<name>_trailer_art.tres: a CharacterArt of its own (id <name>_trailer) with the trailer GLB, the shared palette atlas, the triangle budget of
    the M6 art, and metadata/paint_tex, metadata/ink_tex (and metadata/marks_tex) naming the maps (the painted material's contract, docs/ARCHITECTURE.md);
  - adds `metadata/trailer` to <name>_art.tres once, pointing at it (CharacterArt.variant() then gives the trailer art under look_profile 1 and the M6 art under 0).
Running it again rewrites the trailer art and leaves <name>_art.tres alone. No code is touched: a new character is a data folder and this call.
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
ART_DIR = os.path.join(ROOT, "game", "actors", "art")
EXPORT = "assets/export/characters"
TRAILER_ID = "9_trailer"


def trailer_art_text(name, budget):
	d = "res://%s/%s/trailer/" % (EXPORT, name)
	has_marks = os.path.exists(os.path.join(ROOT, EXPORT, name, "trailer", name + "_marks.png"))
	lines = ['[gd_resource type="Resource" script_class="CharacterArt" format=3]', "",
		'[ext_resource type="Script" path="res://game/actors/character_art.gd" id="1_art"]',
		'[ext_resource type="PackedScene" path="%s%s_trailer.glb" id="2_scene"]' % (d, name),
		'[ext_resource type="Texture2D" path="res://assets/export/palette/palette_atlas.png" id="3_atlas"]',
		'[ext_resource type="Texture2D" path="%s%s_paint.png" id="4_paint"]' % (d, name),
		'[ext_resource type="Texture2D" path="%s%s_ink.png" id="5_ink"]' % (d, name)]
	if has_marks:
		lines.append('[ext_resource type="Texture2D" path="%s%s_marks.png" id="6_marks"]' % (d, name))
	lines += ["", "[resource]", 'script = ExtResource("1_art")', "id = &\"%s_trailer\"" % name, 'scene = ExtResource("2_scene")',
		'palette = ExtResource("3_atlas")', "triangle_budget = %d" % budget, 'metadata/paint_tex = ExtResource("4_paint")',
		'metadata/ink_tex = ExtResource("5_ink")']
	if has_marks:
		lines.append('metadata/marks_tex = ExtResource("6_marks")')
	return "\n".join(lines) + "\n"


def wire(name):
	base_path = os.path.join(ART_DIR, name + "_art.tres")
	with open(base_path) as f:
		base = f.read()
	m = re.search(r"^triangle_budget = (\d+)", base, re.M)
	budget = int(m.group(1)) if m else 15000
	with open(os.path.join(ART_DIR, name + "_trailer_art.tres"), "w") as f:
		f.write(trailer_art_text(name, budget))
	if "metadata/trailer" in base:
		print("trailer_wire %s: %s_trailer_art.tres rewritten (%s_art.tres already names it)" % (name, name, name))
		return
	ext = '[ext_resource type="Resource" path="res://game/actors/art/%s_trailer_art.tres" id="%s"]\n' % (name, TRAILER_ID)
	base = base.replace("\n[resource]", ext + "\n[resource]", 1)
	base = base.rstrip("\n") + '\nmetadata/trailer = ExtResource("%s")\n' % TRAILER_ID
	with open(base_path, "w") as f:
		f.write(base)
	print("trailer_wire %s: wrote %s_trailer_art.tres and added metadata/trailer to %s_art.tres" % (name, name, name))


if __name__ == "__main__":
	for n in sys.argv[1:]:
		wire(n)
