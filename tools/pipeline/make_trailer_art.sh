#!/usr/bin/env bash
# Make the trailer art of the Punk (M7 T12): the Blender bake and the GLB with the fresh UV2 (tools/pipeline/trailer_asset.py), then paint.png and
# ink.png (tools/pipeline/trailer_paint.py, to the painted material's contract), then the veteran's recolour, into assets/export/characters/<name>/trailer/.
# One Blender process at a time, never the Blender MCP. T13 and T14 reuse it with their own assets/source/trailer_art/<name>/ files.
# Usage: tools/pipeline/make_trailer_art.sh [name ...]   (default: punk; ART_WORK=<dir> sets the scratch directory)
#        Run `godot --headless --import --quit` afterwards. Python: ~/.venvs/beat-em-up-video/bin/python (numpy, scipy, opencv, pillow).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
WORK="${ART_WORK:-assets/source/_cache/trailer_art}"
PY="${HOME}/.venvs/beat-em-up-video/bin/python"
names=("$@")
[ ${#names[@]} -eq 0 ] && names=(punk)
for name in "${names[@]}"; do
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
	for f in "$out/${name}_ink.png" "$out/${name}_paint.png" $(ls "$out"/${name}_*_paint.png 2>/dev/null); do
		[ -f "$f.import" ] || sed -e "s#tests/fixtures/m7/painted_ink.png#${f#./}#g" -e '/^uid=/d' -e '/^path=/d' -e '/^dest_files=/d' tests/fixtures/m7/painted_ink.png.import > "$f.import"
	done
done
echo "make_trailer_art: run 'godot --headless --import --quit' now"
