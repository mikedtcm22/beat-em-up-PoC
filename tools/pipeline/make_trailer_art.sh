#!/usr/bin/env bash
# Make the trailer art of the Punk (M7 T12): the Blender bake and the GLB with the fresh UV2 (tools/pipeline/trailer_asset.py), then paint.png and
# ink.png (tools/pipeline/trailer_paint.py, to the painted material's contract), then the veteran's recolour, into assets/export/characters/<name>/trailer/.
# One Blender process at a time, never the Blender MCP. Per character and data-driven (M7 r0): a character is the folder assets/source/trailer_art/<name>/
# (paint.json, and optionally sheets.json + gemini/, features.svg) on top of assets/source/characters/<name>/work/<name>.blend; this one command builds its maps,
# the optional mark map, the import files and the art resources (tools/pipeline/trailer_wire.py), and imports. No shared code is edited (docs/milestones/M7-calls/recipe.md).
# Usage: tools/pipeline/make_trailer_art.sh [name ...]   (default: punk)
#        ART_WORK=<dir> sets the scratch directory; ART_SKIP_BLENDER=1 repaints the last bake; ART_NO_IMPORT=1 skips the final `godot --headless --import --quit`.
#        Python: ~/.venvs/beat-em-up-video/bin/python (numpy, scipy, opencv, pillow).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
WORK="${ART_WORK:-assets/source/_cache/trailer_art}"
PY="${HOME}/.venvs/beat-em-up-video/bin/python"
names=("$@")
[ ${#names[@]} -eq 0 ] && names=(punk)
for name in "${names[@]}"; do
	[ -f "assets/source/trailer_art/$name/paint.json" ] || { echo "make_trailer_art: assets/source/trailer_art/$name/paint.json is missing (see docs/milestones/M7-calls/recipe.md)" >&2; exit 1; }
	[ -f "assets/source/characters/$name/work/$name.blend" ] || [ -n "${ART_SKIP_BLENDER:-}" ] || { echo "make_trailer_art: assets/source/characters/$name/work/$name.blend is missing" >&2; exit 1; }
	out="assets/export/characters/$name/trailer"
	mkdir -p "$WORK/$name" "$out"
	if [ -z "${ART_SKIP_BLENDER:-}" ]; then
		blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/trailer_asset.py -- "$name" "$WORK/$name" --size 2048 \
			| grep -E "T12-ASSET|Error|Traceback" || true
		cp "$WORK/$name/${name}_trailer.glb" "$out/${name}_trailer.glb"
	fi
	# the drawn sheets (Gemini, assets/source/trailer_art/<name>/sheets.json) warped onto the mesh's views, for the bake to project
	if [ -f "assets/source/trailer_art/$name/sheets.json" ]; then
		"$PY" -I tools/pipeline/trailer_sheets.py align "$name" "$WORK/$name" "assets/source/trailer_art/$name/sheets.json" "$WORK/$name/sheets" | tail -1
	fi
	"$PY" -I tools/pipeline/trailer_paint.py bake "$name" "$WORK/$name" "$out"
	for variant in $("$PY" -I -c "import json,sys;print(' '.join(json.load(open('assets/source/trailer_art/$name/paint.json')).get('variants',{})))"); do
		"$PY" -I tools/pipeline/trailer_paint.py bake "$name" "$WORK/$name" "$out" "$variant"
	done
	# the ink map is read as data: lossless, mipmaps on, no 3D compression, no alpha border bleed (docs/ARCHITECTURE.md "The painted material (M7)")
	for f in "$out/${name}_ink.png" "$out/${name}_paint.png" $(ls "$out"/${name}_*_paint.png "$out/${name}_marks.png" 2>/dev/null); do
		[ -f "$f.import" ] || sed -e "s#tests/fixtures/m7/painted_ink.png#${f#./}#g" -e '/^uid=/d' -e '/^path=/d' -e '/^dest_files=/d' tests/fixtures/m7/painted_ink.png.import > "$f.import"
	done
done
python3 tools/pipeline/trailer_wire.py "${names[@]}"
if [ -z "${ART_NO_IMPORT:-}" ]; then
	godot --headless --import --quit 2>&1 | grep -E "ERROR|SCRIPT" || true
fi
echo "make_trailer_art: done (${names[*]})"
