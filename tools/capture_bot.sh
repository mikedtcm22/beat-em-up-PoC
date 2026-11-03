#!/usr/bin/env bash
# Record a bot scene with Movie Maker, from any worktree, and optionally pull review stills.
# Usage: tools/capture_bot.sh <res:// bot scene> <out dir> ["<act filter>"] [stills per second]
#   tools/capture_bot.sh res://tests/bot/combo_bot.tscn captures/jab "Jab" 6
# Output: <out dir>/bot.avi, <out dir>/bot.log (the bot's printed log, hits and warning lines)
# and, with a stills rate, <out dir>/stills/%04d.png. Keep <out dir> out of git (captures/ is
# ignored); a .gdignore is dropped into it so Godot never imports the recording.
# The project recorded is the one this script lives in (its own worktree), so every builder
# records its own checkout. Only a few Movie Maker windows may run on this 8 GB machine: a
# machine-wide lock of CAPTURE_SLOTS slots (default 2) under CAPTURE_LOCK_DIR (default
# ~/.cache/beat-em-up-capture) makes a second recording wait for a free slot, and a slot whose
# recorder died is taken over. Set GODOT to use another binary.
# CAPTURE_ARGS="<args>" forwards more arguments to the bot after --act= (split on spaces, so no
# argument holds one): `--seed=2` (a crowd bot's name offset), `--tune=<property>=<number>` (a
# TuningData value for the run, for A/B sheets), `--probe-out=<dir>`:
#   CAPTURE_ARGS="--tune=impact_frame_enabled=0" tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/c13 "Look: Punk reacts" 6
# Then make sheets, for example:
#   ffmpeg -loglevel error -y -ss <t> -t <d> -i <out dir>/bot.avi -vf "fps=12,scale=480:-1,tile=5x4" -frames:v 1 sheet.png
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
SCENE="${1:?usage: tools/capture_bot.sh <res:// bot scene> <out dir> [act filter] [stills fps]}"
OUT_ARG="${2:?usage: tools/capture_bot.sh <res:// bot scene> <out dir> [act filter] [stills fps]}"
FILTER="${3:-}"
FPS_STILLS="${4:-}"
SLOTS="${CAPTURE_SLOTS:-2}"
LOCK_DIR="${CAPTURE_LOCK_DIR:-$HOME/.cache/beat-em-up-capture}"

mkdir -p "$OUT_ARG"
OUT="$(cd "$OUT_ARG" && pwd)"
touch "$OUT/.gdignore"

# --- The machine-wide slot lock (mkdir is atomic) ---
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

# A slot is stale when its recorder's pid is gone (or it never wrote one for over a minute).
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
		[ "$waited" -eq 0 ] && echo "capture_bot: waiting for a free recording slot (all $SLOTS taken)..."
		waited=1
		sleep 3
	fi
done

# --- Record ---
ARGS=()
if [ -n "$FILTER" ]; then ARGS=(-- "--act=$FILTER"); fi
if [ -n "${CAPTURE_ARGS:-}" ]; then
	[ ${#ARGS[@]} -eq 0 ] && ARGS=(--)
	read -r -a EXTRA_ARGS <<< "$CAPTURE_ARGS"
	ARGS+=("${EXTRA_ARGS[@]}")
fi
status=0
# A bot whose script fails to parse never quits: cap the recording (CAPTURE_MAX_FRAMES, default
# 15 minutes of game time at 60 fps) so Movie Maker can't fill the disk.
"$GODOT" --path "$ROOT" --write-movie "$OUT/bot.avi" --fixed-fps 60 --resolution 1280x720 \
	--quit-after "${CAPTURE_MAX_FRAMES:-54000}" \
	"$SCENE" ${ARGS[@]+"${ARGS[@]}"} > "$OUT/bot.log" 2>&1 || status=$?
release

problems="$(grep -c -E 'SCRIPT ERROR|^ERROR' "$OUT/bot.log" || true)"
echo "capture_bot: godot exit $status, $OUT/bot.avi, $OUT/bot.log ($problems SCRIPT ERROR/ERROR lines)"

if [ -n "$FPS_STILLS" ] && [ -f "$OUT/bot.avi" ]; then
	rm -rf "$OUT/stills" && mkdir -p "$OUT/stills"
	ffmpeg -loglevel error -y -i "$OUT/bot.avi" -vf "fps=${FPS_STILLS},scale=960:-1" "$OUT/stills/%04d.png"
	echo "capture_bot: stills: $(ls "$OUT/stills" | wc -l | tr -d ' ') in $OUT/stills"
fi
exit "$status"
