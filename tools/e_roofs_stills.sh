#!/usr/bin/env bash
# M7 e-roofs: record the roofs' six stills under a profile (1600x900) and cut the frame at the end of each station.
# Usage: tools/e_roofs_stills.sh <out dir> [bot args, e.g. --enemies=thug,kicker or --profile=m6]
# Waits while another Movie Maker recording runs (8 GB machine).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$1"; shift
ARGS="${*:---profile=trailer}"
mkdir -p "$OUT/raw"; touch "$OUT/raw/.gdignore"
while pgrep -f write-movie >/dev/null; do sleep 5; done
# shellcheck disable=SC2086
godot --path "$ROOT" --write-movie "$OUT/raw/bot.avi" --fixed-fps 60 --resolution 1600x900 --quit-after 1200 \
	res://tests/bot/e_roofs_bot.tscn -- $ARGS > "$OUT/raw/bot.log" 2>&1 || true
rm -rf "$OUT/stills" && mkdir -p "$OUT/stills"
ffmpeg -loglevel error -y -i "$OUT/raw/bot.avi" -vf "select='eq(mod(n\,90)\,85)'" -fps_mode vfr "$OUT/stills/roofs_%02d.png"
echo "errors: $(grep -c -E 'SCRIPT ERROR|SHADER ERROR' "$OUT/raw/bot.log" || true)"
ls "$OUT/stills"
