"""Set the import flags of the video art textures (LD-ART2): no alpha-border fix (the ink map's A is data, and the paint's RGB under an alpha of 0 is
the mean colour), mipmaps on (the maps are minified a lot at 2-3 m and would shimmer), no compression (a drawn line is two texels wide).
	~/.venvs/beat-em-up-video/bin/python -I tools/video/art_import_flags.py assets/video/characters/<name>/<name>_paint.png ...
Edits each <png>.import in place (run `godot --headless --import --quit` first so the files exist, and again after).
"""
import re
import sys

FLAGS = {"process/fix_alpha_border": "false", "mipmaps/generate": "true", "compress/mode": "0", "process/premult_alpha": "false"}

for png in sys.argv[1:]:
	path = png + ".import"
	text = open(path).read()
	for key, value in FLAGS.items():
		text = re.sub(r"^%s=.*$" % re.escape(key), "%s=%s" % (key, value), text, flags=re.M)
	open(path, "w").write(text)
	print("import flags", path)
