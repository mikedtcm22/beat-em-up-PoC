#!/usr/bin/env bash
# Render the spike's stills: a windowed Godot (a still needs the GPU) under the machine-wide capture lock that
# tools/capture_bot.sh uses (copied, so the game session's captures and this one share the 2 slots).
# Usage: video/spike/run_spike.sh <out dir> [stages, default abcde] [extra bot args, e.g. --check=1]
#   video/spike/run_spike.sh captures/video/p0-spike abcd
# Output: <out dir>/<stage>.png (2560x1440), <out dir>/run.log. Never --headless; always capped by --quit-after.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
OUT_ARG="${1:?usage: video/spike/run_spike.sh <out dir> [stages] [extra args]}"
STAGES="${2:-abcde}"
shift || true
shift || true
SLOTS="${CAPTURE_SLOTS:-2}"
LOCK_DIR="${CAPTURE_LOCK_DIR:-$HOME/.cache/beat-em-up-capture}"

mkdir -p "$OUT_ARG"
OUT="$(cd "$OUT_ARG" && pwd)"
touch "$OUT/.gdignore"

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
		[ "$waited" -eq 0 ] && echo "run_spike: waiting for a free recording slot (all $SLOTS taken)..."
		waited=1
		sleep 3
	fi
done

status=0
"$GODOT" --path "$ROOT" --fixed-fps 60 --resolution 1280x720 --quit-after "${SPIKE_MAX_FRAMES:-3000}" \
	res://video/spike/spike_bot.tscn -- --level=res://game/level/mission1/mission1.tscn \
	"--act=Spike: street punk" "--out=$OUT" "--stages=$STAGES" "$@" > "$OUT/run.log" 2>&1 || status=$?
release
problems="$(grep -c -E 'SCRIPT ERROR|SHADER ERROR|^ERROR' "$OUT/run.log" || true)"
echo "run_spike: godot exit $status, $OUT, $problems SCRIPT ERROR/SHADER ERROR/ERROR lines"
exit "$status"
