#!/usr/bin/env bash
# The plate capture (round 5, R5-PAINT; docs/video/P1.md): the inputs of a Gemini plate from one shot's frame, at that frame's exact camera position.
# Usage: tools/video/plate_capture.sh <shot key> <out dir> [--frame N | --from SEC --to SEC] [--name plate_0] [--flat] [--fov DEG] [--size WxH]
#   tools/video/plate_capture.sh street_wide captures/video/plates/street_wide                (a still: its one frame)
#   tools/video/plate_capture.sh moving_punk captures/video/plates/moving_punk --frame 42     (output frame 42 of a 24 fps shot)
# Writes into the out dir: <name>_blockout.png (the world as flat masses with a thin line on its depth edges; humanoids, pickups, steam, embers, flames,
# contact shadows, lamp shafts and cues hidden), <name>_depth.png (the 16-bit view depth in red and green), <name>.json (the camera) and shoot.log.
# --flat writes <name>_flat.png instead: the world's own look without the blockout and without the line (the unpainted capture of the motion check).
# The shot runs without its ink piece and without any plate (--shot-skip=ink.tres,plate.tres): nothing the post does is in the picture.
# Environment: GODOT, SHOOT_LEVEL, SHOOT_WINDOW, CAPTURE_SLOTS and CAPTURE_LOCK_DIR as tools/video/shoot.sh (the capture lock is shared with it).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
KEY="${1:?usage: tools/video/plate_capture.sh <shot key> <out dir> [--frame N | --from SEC --to SEC] [--name plate_0] [--flat] [--fov DEG] [--size WxH]}"
OUT_ARG="${2:?usage: tools/video/plate_capture.sh <shot key> <out dir> ...}"
shift 2
LEVEL="${SHOOT_LEVEL:-res://game/level/mission1/mission1.tscn}"
WINDOW="${SHOOT_WINDOW:-480x270}"
SLOTS="${CAPTURE_SLOTS:-2}"
LOCK_DIR="${CAPTURE_LOCK_DIR:-$HOME/.cache/beat-em-up-capture}"
NAME="plate_0"
FLAT=0
EXTRA=()
SET="world.tres.blockout=true"
FROM=""
TO=""
FPS=24
while [ $# -gt 0 ]; do
	case "$1" in
		--frame) FROM="$(awk -v n="$2" -v f="$FPS" 'BEGIN{printf "%.6f", n/f}')"; TO="$(awk -v n="$2" -v f="$FPS" 'BEGIN{printf "%.6f", (n+1)/f}')"; shift 2 ;;
		--from) FROM="$2"; shift 2 ;;
		--to) TO="$2"; shift 2 ;;
		--name) NAME="$2"; shift 2 ;;
		--flat) FLAT=1; SET=""; shift ;;
		--fov) EXTRA+=("--plate-fov=$2"); shift 2 ;;
		--size) EXTRA+=("--plate-size=$2"); shift 2 ;;
		*) echo "plate_capture: unknown argument $1" >&2; exit 2 ;;
	esac
done
[ -n "$FROM" ] && EXTRA+=("--shot-from=$FROM")
[ -n "$TO" ] && EXTRA+=("--shot-to=$TO")
[ -n "$SET" ] && EXTRA+=("--shot-set=$SET")
[ "$FLAT" = 1 ] && EXTRA+=("--plate-flat=1")

if [ ! -f "$ROOT/video/stills/$KEY.tres" ] && [ ! -f "$ROOT/video/shots/$KEY.tres" ]; then
	echo "plate_capture: no shot resource for $KEY (video/stills/ or video/shots/)" >&2
	exit 2
fi
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
		[ "$waited" -eq 0 ] && echo "plate_capture: waiting for a free slot (all $SLOTS taken)..."
		waited=1
		sleep 3
	fi
done

status=0
"$GODOT" --path "$ROOT" --fixed-fps 60 --resolution "$WINDOW" --quit-after "${SHOOT_MAX_FRAMES:-6000}" \
	res://video/paint/plate_bot.tscn -- "--level=$LEVEL" "--still-out=$OUT" "--plate-shot=$KEY" "--plate-name=$NAME" \
	--shot-skip=ink.tres,plate.tres --shot-mask=0 --shot-store=png ${EXTRA[@]+"${EXTRA[@]}"} \
	> "$OUT/shoot.log" 2>&1 || status=$?
release

problems="$(grep -E 'SCRIPT ERROR|SHADER ERROR|^ERROR|Parse Error' "$OUT/shoot.log" | grep -v -E 'leaked at exit|never freed|still in use|Pages in use' | wc -l | tr -d ' ' || true)"
echo "plate_capture: godot exit $status ($problems error lines in shoot.log)"
grep -h '^PLATE ' "$OUT/shoot.log" || true
fail=0
[ "$status" -eq 0 ] || fail="$status"
[ "$problems" -eq 0 ] || fail=7
SUFFIX="blockout"
[ "$FLAT" = 1 ] && SUFFIX="flat"
for f in "${NAME}_${SUFFIX}.png" "${NAME}_depth.png" "${NAME}.json"; do
	if [ ! -s "$OUT/$f" ]; then
		echo "plate_capture: FAILED, no $f in $OUT" >&2
		fail=5
	fi
done
exit "$fail"
