#!/usr/bin/env bash
# Render the Gate 1 stills at 2560x1440 with the still stage (video/stage/still_bot.gd), from any worktree.
# Usage: tools/video/shoot_still.sh "<act filter>" <out dir>
#   tools/video/shoot_still.sh "Still:" captures/video/stills        every still
#   tools/video/shoot_still.sh "fp_punk|ox_low" captures/video/work  two of them
# Output: <out dir>/<key>.png and <out dir>/shoot.log (the bot's printed log). The window is a normal 1280x720
# one (rendering needs the GPU, so never --headless); the stills are rendered by a 2560x1440 SubViewport.
# It takes the machine-wide capture lock that tools/capture_bot.sh uses (CAPTURE_SLOTS, CAPTURE_LOCK_DIR), so
# the game session's recordings and this one never run more than a few windows at once. Set GODOT to use
# another binary, SHOOT_MAX_FRAMES for the frame cap (default 3000: a still run that hangs must quit).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
FILTER="${1:?usage: tools/video/shoot_still.sh <act filter> <out dir>}"
OUT_ARG="${2:?usage: tools/video/shoot_still.sh <act filter> <out dir>}"
LEVEL="${SHOOT_LEVEL:-res://game/level/mission1/mission1.tscn}"
SLOTS="${CAPTURE_SLOTS:-2}"
LOCK_DIR="${CAPTURE_LOCK_DIR:-$HOME/.cache/beat-em-up-capture}"

mkdir -p "$OUT_ARG"
OUT="$(cd "$OUT_ARG" && pwd)"
touch "$OUT/.gdignore"

# --- The machine-wide slot lock (mkdir is atomic), as in tools/capture_bot.sh ---
mkdir -p "$LOCK_DIR"
SLOT=""
release() {
	if [ -n "$SLOT" ]; then
		rm -rf "$SLOT"
		SLOT=""
	fi
}
trap release EXIT
trap 'exit 130' INT TERM

stale() {
	local dir="$1" pid
	if [ -f "$dir/pid" ]; then
		pid="$(cat "$dir/pid" 2>/dev/null || true)"
		[ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null
	else
		[ -n "$(find "$dir" -maxdepth 0 -mmin +1 2>/dev/null)" ]
	fi
}

waited=0
while [ -z "$SLOT" ]; do
	for i in $(seq 1 "$SLOTS"); do
		dir="$LOCK_DIR/slot$i"
		if [ -d "$dir" ] && stale "$dir"; then
			rm -rf "$dir"
		fi
		if mkdir "$dir" 2>/dev/null; then
			SLOT="$dir"
			echo "$$" > "$dir/pid"
			break
		fi
	done
	if [ -z "$SLOT" ]; then
		[ "$waited" -eq 0 ] && echo "shoot_still: waiting for a free slot (all $SLOTS taken)..."
		waited=1
		sleep 3
	fi
done

status=0
"$GODOT" --path "$ROOT" --fixed-fps 60 --resolution 1280x720 \
	--quit-after "${SHOOT_MAX_FRAMES:-3000}" \
	res://video/stage/still_bot.tscn -- "--level=$LEVEL" "--act=$FILTER" "--still-out=$OUT" \
	> "$OUT/shoot.log" 2>&1 || status=$?
release

problems="$(grep -c -E 'SCRIPT ERROR|SHADER ERROR|^ERROR' "$OUT/shoot.log" || true)"
echo "shoot_still: godot exit $status, $(ls "$OUT"/*.png 2>/dev/null | wc -l | tr -d ' ') PNGs in $OUT ($problems error lines in shoot.log)"
exit "$status"
