"""Build the shared palette atlas from assets/source/palette/*.json (M4-plan 2.6; the lead reruns it after merges).

	python3 -I tools/pipeline/gen_palette.py            write assets/export/palette/palette_atlas.png
	python3 -I tools/pipeline/gen_palette.py --check    exit 1 when the committed atlas differs from the JSON
	python3 -I tools/pipeline/gen_palette.py --list     print the slots

The atlas is 256x16 RGBA8, 8 px swatches, slot s at column s % 32, row s // 32 (64 slots: 0-15 shared, 16-31 punk,
32-47 player, 48-63 reserved). rgb = the sRGB colour; alpha is the swatch's damage class, read by game/fx/toon.gdshader:
255 (1.0) takes the clothes' marks (scuffs, then blood), 204 (0.8) takes the skin's marks (bruises, then blood), 128 (0.5)
takes none (today's DARK). A glossy swatch (`"gloss": true`, the shades' lens) is one step lower in the same class: 254, 203
or 127, so the classes' thresholds (0.9, 0.75) read it as before and toon.gdshader reads the glint from the step. A swatch
without the flag is matte: the art's hard highlight lands on glossy swatches only (the look bible: shades, leather, studs;
the final review's gloss finding: a highlight on denim and cotton was a pale blob). Unused slots are magenta at alpha 128, so a stray lookup is loud. Nearest filter, no mipmaps (the
material and the .import say so). The PNG is written with the standard library (zlib), byte for byte reproducible.

Each palette file: {"id", "slot_range": [lo, hi], "swatches": [{"slot", "name", "srgb": "#rrggbb", "marks": bool, "skin": bool, "gloss": bool}]}.
marks defaults to true, skin to false, gloss to false; a skin swatch must take marks and a skin swatch is never glossy. Slots must lie in the file's range and no slot may be
defined twice across files.
"""
import glob
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipe_common as pc  # noqa: E402

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
	"""{slot: {"rgba": (r, g, b, a), "name", "palette", "marks", "skin", "gloss"}} over every palette file; raises ValueError on a bad file."""
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
			alpha = NO_MARKS_ALPHA if not marks else SKIN_MARKS_ALPHA if skin else MARKS_ALPHA
			if gloss:
				alpha -= GLOSS_ALPHA_STEP
			out[slot] = {"rgba": (r, g, b, alpha), "name": sw["name"], "palette": pal["id"], "marks": marks, "skin": skin, "gloss": gloss}
	return out


def atlas_pixels(palette_dir=None):
	"""Rows of RGBA bytes, top row first."""
	sw = swatches(palette_dir)
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


def build(palette_dir=None):
	return png_bytes(atlas_pixels(palette_dir), WIDTH, HEIGHT)


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
			print("%2d  %-12s  #%02x%02x%02x  alpha %d%s  (%s)" % (slot, s["name"], s["rgba"][0], s["rgba"][1], s["rgba"][2], s["rgba"][3], "  glossy" if s["gloss"] else "", s["palette"]))
		return 0
	if "--check" in argv:
		have = open(pc.ATLAS_PATH, "rb").read() if os.path.exists(pc.ATLAS_PATH) else b""
		print("palette atlas %s" % ("is current" if have == data else "is STALE: run python3 -I tools/pipeline/gen_palette.py"))
		return 0 if have == data else 1
	os.makedirs(os.path.dirname(pc.ATLAS_PATH), exist_ok=True)
	with open(pc.ATLAS_PATH, "wb") as f:
		f.write(data)
	print("wrote %s (%d swatches, %d bytes)" % (pc.repo_rel(pc.ATLAS_PATH), len(swatches()), len(data)))
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
