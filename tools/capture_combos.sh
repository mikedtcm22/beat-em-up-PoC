#!/usr/bin/env bash
# Record the combo bot with Movie Maker, then pull review stills with ffmpeg.
# Usage: tools/capture_combos.sh [act filter text] [stills per second]
# Output: captures/combos.avi and captures/stills/*.png (captures/ is git-ignored).
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
FILTER="${1:-}"
FPS_STILLS="${2:-4}"
mkdir -p captures && touch captures/.gdignore
rm -rf captures/stills && mkdir -p captures/stills

ARGS=()
if [ -n "$FILTER" ]; then ARGS=(-- "--act=$FILTER"); fi

"$GODOT" --path . --write-movie captures/combos.avi --fixed-fps 60 --resolution 1280x720 \
	res://tests/bot/combo_bot.tscn "${ARGS[@]}"

ffmpeg -loglevel error -y -i captures/combos.avi -vf "fps=${FPS_STILLS},scale=960:-1" captures/stills/%04d.png
echo "Stills: $(ls captures/stills | wc -l | tr -d ' ') in captures/stills"
