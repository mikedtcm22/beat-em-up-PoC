"""Build the shared palette atlas from assets/source/palette/*.json (M4-plan 2.6; the lead reruns it after merges).

	python3 -I tools/pipeline/gen_palette.py            write assets/export/palette/palette_atlas.png
	python3 -I tools/pipeline/gen_palette.py --check    exit 1 when the committed atlas differs from the JSON
	python3 -I tools/pipeline/gen_palette.py --list     print the slots

The atlas is 256x16 RGBA8, 8 px swatches, slot s at column s % 32, row s // 32 (64 slots: 0-15 shared, 16-31 punk,
32-47 player, 48-63 reserved). rgb = the sRGB colour; alpha is the swatch's damage class, read by game/fx/toon.gdshader:
255 (1.0) takes the clothes' marks (scuffs, then blood), 230 (0.9) takes the clothes' scuffs and never blood (`"blood": false`,
M6 D6: the Punk's cap, laces and strap, so a hard-edged red never lands on the yellow), 204 (0.8) takes the skin's marks (bruises,
then blood), 128 (0.5) takes none (today's DARK). The classes' thresholds in toon.gdshader and ToonMaterials.swatch_glossy():
alpha >= 0.95 clothes, >= 0.85 scuffs only, >= 0.75 skin, below it none. A glossy swatch (`"gloss": true`, the shades' lens) is one
step lower in the same class: 254, 229, 203 or 127, so the thresholds read it as before and toon.gdshader reads the glint from the step. A swatch
without the flag is matte: the art's hard highlight lands on glossy swatches only (the look bible: shades, leather, studs;
the final review's gloss finding: a highlight on denim and cotton was a pale blob). Unused slots are magenta at alpha 128, so a stray lookup is loud. Nearest filter, no mipmaps (the
material and the .import say so). The PNG is written with the standard library (zlib), byte for byte reproducible.

Each palette file: {"id", "slot_range": [lo, hi], "swatches": [{"slot", "name", "srgb": "#rrggbb", "marks": bool, "skin": bool, "gloss": bool}]}.
marks defaults to true, blood to true, skin to false, gloss to false; a skin swatch must take marks and a skin swatch is never glossy;
`"blood": false` is for a clothes swatch (it needs marks, and a skin swatch always takes blood). Slots must lie in the file's range and no slot may be
defined twice across files.

Variant atlases (M6 D4): assets/source/palette/variants/<id>.json, {"id", "base": "<palette id>", "swatches": [{"slot", "name", "srgb"}]},
write assets/export/palette/<id>_atlas.png: the shared atlas with those slots recoloured. The rgb changes and the alpha never does (a
variant keeps every swatch's damage class and gloss), a slot must already exist in the shared atlas and lie in a palette the variant's
base names or in the shared one, and the file says how many colours it changes. `--check` covers them too.
"""
import glob
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipe_common as pc  # noqa: E402

## Variant atlases (M6 D4): the sources and the outputs, beside the shared atlas.
VARIANT_DIR = os.path.join(pc.PALETTE_DIR, "variants")
ATLAS_DIR = os.path.dirname(pc.ATLAS_PATH)

COLUMNS = 32
ROWS = 2
SWATCH_PX = 8
SLOTS = COLUMNS * ROWS
WIDTH = COLUMNS * SWATCH_PX
HEIGHT = ROWS * SWATCH_PX
UNUSED = (255, 0, 255, 128)
MARKS_ALPHA = 255
SKIN_MARKS_ALPHA = 204
NO_MARKS_ALPHA = 128
## The clothes that take scuffs and never blood ("blood": false), between the clothes' class and the skin's.
NO_BLOOD_ALPHA = 230
## A glossy swatch's alpha is its class's minus this (one 8-bit step: inside the 0.01 the class tests allow).
GLOSS_ALPHA_STEP = 1


def parse_hex(s):
	s = s.lstrip("#")
	if len(s) != 6:
		raise ValueError("colour must be #rrggbb: %r" % s)
	return int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16)


def load_palettes(palette_dir=None):
	"""[(path, parsed json)] sorted by file name."""
	paths = sorted(glob.glob(os.path.join(palette_dir or pc.PALETTE_DIR, "*.json")))
	return [(p, pc.load_json(p)) for p in paths]


def swatches(palette_dir=None):
	"""{slot: {"rgba": (r, g, b, a), "name", "palette", "marks", "skin", "gloss", "blood"}} over every palette file; raises ValueError on a bad file."""
	out = {}
	for path, pal in load_palettes(palette_dir):
		lo, hi = pal["slot_range"]
		for sw in pal["swatches"]:
			slot = int(sw["slot"])
			if not lo <= slot <= hi:
				raise ValueError("%s: slot %d is outside the file's range %d-%d" % (os.path.basename(path), slot, lo, hi))
			if not 0 <= slot < SLOTS:
				raise ValueError("%s: slot %d is outside the atlas" % (os.path.basename(path), slot))
			if slot in out:
				raise ValueError("%s: slot %d is already defined by %s" % (os.path.basename(path), slot, out[slot]["palette"]))
			r, g, b = parse_hex(sw["srgb"])
			marks = bool(sw.get("marks", True))
			skin = bool(sw.get("skin", False))
			if skin and not marks:
				raise ValueError("%s: slot %d is skin but takes no marks" % (os.path.basename(path), slot))
			gloss = bool(sw.get("gloss", False))
			if skin and gloss:
				raise ValueError("%s: slot %d is skin and glossy (skin takes no hard highlight)" % (os.path.basename(path), slot))
			blood = bool(sw.get("blood", True))
			if not blood and not marks:
				raise ValueError("%s: slot %d says blood: false but takes no marks at all" % (os.path.basename(path), slot))
			if not blood and skin:
				raise ValueError("%s: slot %d is skin and says blood: false (skin always takes blood)" % (os.path.basename(path), slot))
			alpha = NO_MARKS_ALPHA if not marks else SKIN_MARKS_ALPHA if skin else MARKS_ALPHA if blood else NO_BLOOD_ALPHA
			if gloss:
				alpha -= GLOSS_ALPHA_STEP
			out[slot] = {"rgba": (r, g, b, alpha), "name": sw["name"], "palette": pal["id"], "marks": marks, "skin": skin, "gloss": gloss, "blood": blood}
	return out


def atlas_pixels(palette_dir=None, recolour=None):
	"""Rows of RGBA bytes, top row first. `recolour` {slot: (r, g, b)} replaces those swatches' rgb and keeps their alpha."""
	sw = swatches(palette_dir)
	for slot, rgb in (recolour or {}).items():
		sw[slot] = dict(sw[slot], rgba=(rgb[0], rgb[1], rgb[2], sw[slot]["rgba"][3]))
	rows = []
	for y in range(HEIGHT):
		row = bytearray()
		for x in range(WIDTH):
			slot = (y // SWATCH_PX) * COLUMNS + (x // SWATCH_PX)
			row += bytes(sw[slot]["rgba"] if slot in sw else UNUSED)
		rows.append(bytes(row))
	return rows


def png_bytes(rows, width, height):
	raw = b"".join(b"\x00" + row for row in rows)

	def chunk(tag, data):
		body = tag + data
		return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

	return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
		+ chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def build(palette_dir=None, recolour=None):
	return png_bytes(atlas_pixels(palette_dir, recolour), WIDTH, HEIGHT)


def variant_paths(variant_dir=None):
	"""The variant files, sorted by name."""
	return sorted(glob.glob(os.path.join(variant_dir or VARIANT_DIR, "*.json")))


def variant_atlas_path(variant_id):
	return os.path.join(ATLAS_DIR, "%s_atlas.png" % variant_id)


def variant_recolour(variant, palette_dir=None):
	"""{slot: (r, g, b)} of a parsed variant file; raises ValueError when it touches a slot it may not."""
	base = swatches(palette_dir)
	allowed = {s for s, v in base.items() if v["palette"] in (variant["base"], "shared")}
	out = {}
	for sw in variant["swatches"]:
		slot = int(sw["slot"])
		if slot not in allowed:
			raise ValueError("variant %s: slot %d is not in the shared palette or %s" % (variant["id"], slot, variant["base"]))
		if slot in out:
			raise ValueError("variant %s: slot %d is listed twice" % (variant["id"], slot))
		for key in ("marks", "skin", "gloss", "blood"):
			if key in sw:
				raise ValueError("variant %s: slot %d sets %s, but a variant keeps its swatch's damage class" % (variant["id"], slot, key))
		out[slot] = parse_hex(sw["srgb"])
	return out


def variants(palette_dir=None, variant_dir=None):
	"""[(id, png bytes)] for every variant file."""
	out = []
	for path in variant_paths(variant_dir):
		v = pc.load_json(path)
		out.append((v["id"], build(palette_dir, variant_recolour(v, palette_dir))))
	return out


def uv_of_slot(slot):
	"""(u, v) of a swatch centre in glTF/Godot UV space (v down from the top of the image)."""
	return ((slot % COLUMNS + 0.5) / COLUMNS, (slot // COLUMNS + 0.5) / ROWS)


def slot_of_uv(u, v):
	"""Inverse of uv_of_slot (glTF UV space)."""
	return int(v * ROWS) * COLUMNS + int(u * COLUMNS)


def main(argv):
	data = build()
	if "--list" in argv:
		for slot, s in sorted(swatches().items()):
			print("%2d  %-12s  #%02x%02x%02x  alpha %d%s  (%s)" % (slot, s["name"], s["rgba"][0], s["rgba"][1], s["rgba"][2], s["rgba"][3], ("  glossy" if s["gloss"] else "") + ("  no blood" if not s["blood"] else ""), s["palette"]))
		return 0
	outputs = [(pc.ATLAS_PATH, data)] + [(variant_atlas_path(i), d) for i, d in variants()]
	if "--check" in argv:
		stale = []
		for path, want in outputs:
			have = open(path, "rb").read() if os.path.exists(path) else b""
			if have != want:
				stale.append(pc.repo_rel(path))
		print("palette atlas %s" % ("is current" if not stale else "is STALE (%s): run python3 -I tools/pipeline/gen_palette.py" % ", ".join(stale)))
		return 0 if not stale else 1
	os.makedirs(os.path.dirname(pc.ATLAS_PATH), exist_ok=True)
	for path, want in outputs:
		with open(path, "wb") as f:
			f.write(want)
		print("wrote %s (%d bytes)" % (pc.repo_rel(path), len(want)))
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
