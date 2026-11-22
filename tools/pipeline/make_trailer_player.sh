#!/usr/bin/env bash
# Make the trailer art of the hero (M7 T14): the Blender step (tools/pipeline/trailer_player_asset.py: the arms' relax, the forearm and glove shape,
# smoothed shading normals, the fresh UV2 with no slivers, the bake and the GLB), then paint.png and ink.png (tools/pipeline/trailer_player_paint.py,
# trailer_paint with the "along" rule, to the painted material's contract) into assets/export/characters/player/trailer/. The data is
# assets/source/trailer_art/player/ (paint.json, features.svg). One Blender process at a time, never the Blender MCP.
# Usage: tools/pipeline/make_trailer_player.sh   (ART_WORK=<dir> sets the scratch directory; ART_SKIP_BLENDER=1 repaints the last bake)
#        Run `godot --headless --import --quit` afterwards. Python: ~/.venvs/beat-em-up-video/bin/python (numpy, scipy, opencv, pillow).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
name=player
WORK="${ART_WORK:-assets/source/_cache/trailer_art}/$name"
PY="${HOME}/.venvs/beat-em-up-video/bin/python"
out="assets/export/characters/$name/trailer"
mkdir -p "$WORK" "$out"
if [ -z "${ART_SKIP_BLENDER:-}" ]; then
	blender --background --factory-startup --python-exit-code 1 --python tools/pipeline/trailer_player_asset.py -- "$name" "$WORK" --size 2048 \
		| grep -E "T14-ASSET|Error|Traceback" || true
	cp "$WORK/${name}_trailer.glb" "$out/${name}_trailer.glb"
fi
# the drawn glove sheets (Gemini, assets/source/trailer_art/<name>/sheets.json) warped onto the mesh's views, for the bake to project
if [ -f "assets/source/trailer_art/$name/sheets.json" ]; then
	"$PY" -I tools/pipeline/trailer_sheets.py align "$name" "$WORK" "assets/source/trailer_art/$name/sheets.json" "$WORK/sheets" | tail -1
fi
"$PY" -I tools/pipeline/trailer_player_paint.py bake "$name" "$WORK" "$out"
# the ink map is read as data: lossless, mipmaps on, no 3D compression, no alpha border bleed (docs/ARCHITECTURE.md "The painted material (M7)")
for f in "$out/${name}_ink.png" "$out/${name}_paint.png"; do
	[ -f "$f.import" ] || sed -e "s#tests/fixtures/m7/painted_ink.png#${f#./}#g" -e '/^uid=/d' -e '/^path=/d' -e '/^dest_files=/d' tests/fixtures/m7/painted_ink.png.import > "$f.import"
done
echo "make_trailer_player: run 'godot --headless --import --quit' now"
