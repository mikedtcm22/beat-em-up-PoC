#!/usr/bin/env bash
# The cine frame writer: render one shot of video/shots/ at 2560x1440 to a mezzanine (24 fps picks of the 60 Hz simulation).
# Usage: tools/video/shoot.sh <shot> [out dir]
#   tools/video/shoot.sh moving_punk                          -> captures/video/shots/moving_punk/
#   tools/video/shoot.sh fp_punk captures/video/work/fp_punk   a Gate 1 still (a one-frame shot: a PNG and its mask)
# Output in the out dir: <shot>.mkv (the mezzanine: libx264 -crf 8 -preset slow, yuv444p), <shot>_mask.mkv (the character
# mask, lossless gray), <shot>.sha256 (the SHA-256 of every frame's pixels, for the determinism check), <shot>_stats.json
# (seconds and MB a frame) and shoot.log; a still keeps <shot>.png and <shot>_mask.png instead of the videos.
# Environment: GODOT (the binary), SHOOT_LEVEL (the level scene), SHOOT_WINDOW (the main window's size, default 480x270: it only
# hosts the 2560x1440 SubViewports), SHOOT_MAX_FRAMES (the frame cap, default 6000: a run that hangs must quit), SHOOT_ARGS (more
# arguments for the cine bot: --shot-skip=ink.tres, --shot-to=<seconds>, --shot-from=<seconds>, --shot-mask=0, --shot-tag=<text>),
# FFMPEG (the encoder), CAPTURE_SLOTS and CAPTURE_LOCK_DIR (the machine-wide capture lock, as tools/capture_bot.sh).
# It takes the capture lock (the game session's recordings take it too) and never runs headless: rendering needs the GPU.
# One shot, one process: a shot starts from the level's own state through the bot's reset, the effect and audio rngs seeded, so
# two runs of one shot give the same frames (tools/video/compare_shots.sh checks it).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
SHOT="${1:?usage: tools/video/shoot.sh <shot> [out dir]}"
OUT_ARG="${2:-$ROOT/captures/video/shots/$SHOT}"
LEVEL="${SHOOT_LEVEL:-res://game/level/mission1/mission1.tscn}"
WINDOW="${SHOOT_WINDOW:-480x270}"
SLOTS="${CAPTURE_SLOTS:-2}"
LOCK_DIR="${CAPTURE_LOCK_DIR:-$HOME/.cache/beat-em-up-capture}"
SCENE="res://video/shots/$SHOT.tscn"

if [ ! -f "$ROOT/video/shots/$SHOT.tscn" ]; then
	echo "shoot: no shot scene $SCENE (the shots: $(ls "$ROOT/video/shots" | sed -n 's/\.tscn$//p' | tr '\n' ' '))" >&2
	exit 2
fi

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
		[ "$waited" -eq 0 ] && echo "shoot: waiting for a free slot (all $SLOTS taken)..."
		waited=1
		sleep 3
	fi
done

status=0
# shellcheck disable=SC2086
"$GODOT" --path "$ROOT" --fixed-fps 60 --resolution "$WINDOW" \
	--quit-after "${SHOOT_MAX_FRAMES:-6000}" \
	"$SCENE" -- "--level=$LEVEL" "--still-out=$OUT" ${SHOOT_ARGS:-} \
	> "$OUT/shoot.log" 2>&1 || status=$?
release

# Godot's exit-time leak report ("... leaked at exit", "never freed", "still in use") is not a problem of the shot.
problems="$(grep -E 'SCRIPT ERROR|SHADER ERROR|^ERROR' "$OUT/shoot.log" | grep -v -E 'leaked at exit|never freed|still in use|Pages in use' | wc -l | tr -d ' ' || true)"
echo "shoot: godot exit $status, $(grep -h '^SHOT ' "$OUT/shoot.log" | tail -1 || true) ($problems error lines in shoot.log)"
exit "$status"
