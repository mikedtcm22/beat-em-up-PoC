#!/usr/bin/env bash
# Make the video art of one or more characters (LD-ASSET, docs/video/P1.md): the Blender bake and the GLB with the face normals
# from an ellipsoid proxy (tools/video/blender_asset.py), then the painted albedo and the ink mask (tools/video/art_paint.py), into
# assets/video/characters/<name>/. One Blender process at a time, never the Blender MCP.
# Usage: tools/video/make_art.sh punk boss player        (all three when no name is given)
#        ART_WORK=<dir> sets the scratch directory (default assets/source/_cache/video_art, git-ignored)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
WORK="${ART_WORK:-assets/source/_cache/video_art}"
PY="${HOME}/.venvs/beat-em-up-video/bin/python"
names=("$@")
[ ${#names[@]} -eq 0 ] && names=(punk boss player)
for name in "${names[@]}"; do
	mkdir -p "$WORK/$name" "assets/video/characters/$name"
	if [ -z "${ART_SKIP_BLENDER:-}" ]; then
		blender --background --factory-startup --python-exit-code 1 --python tools/video/blender_asset.py -- "$name" "$WORK/$name" ${ART_BLENDER_ARGS:-} \
			| grep -E "LD-ASSET|Error|Traceback" || true
		# A character whose mesh is unchanged (the player's) ships no GLB: the game's own is used.
		rm -f "assets/video/characters/$name/${name}_video.glb"
		if ! cmp -s "$WORK/$name/${name}_video.glb" "assets/export/characters/$name/$name.glb"; then
			cp "$WORK/$name/${name}_video.glb" "assets/video/characters/$name/${name}_video.glb"
		fi
	fi
	"$PY" -I tools/video/art_paint.py bake "$name" "$WORK/$name" "assets/video/characters/$name"
done
