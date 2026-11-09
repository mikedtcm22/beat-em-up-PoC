#!/usr/bin/env bash
# One plate, from the capture to the installed files (round 5, R5-PAINT; docs/video/P1.md).
# Usage: tools/video/make_plate.sh <shot key> <output frame | still> [--location street|dusk|boss] [--swatch <png>] [--index 0|1] [--take N] [--install] [--fov DEG]
#   tools/video/make_plate.sh street_wide still --location street          the capture, the job and (after the ledger row) the Gemini run
#   tools/video/make_plate.sh moving_punk 42 --location street --install   also registers the result and installs it as the shot's plate
# Steps (each can be repeated; the work is in captures/video/plates/<shot key>/ and assets/source/video_plates/<shot key>/):
#   1. tools/video/plate_capture.sh: the blockout, the depth and the camera of the frame (skipped when they are there and --recapture is not given);
#   2. tools/video/make_plate_jobs.py: the job (the blockout and one swatch: the location's reference frame, or the approved plate of the location);
#   3. WITHOUT --install and WITHOUT --run: it stops here and prints the Gemini command. Add the batch to docs/video/gemini_ledger.md first;
#   4. --run: python3 -I tools/gemini_image.py (one image, about $0.14);
#   5. --install: tools/video/register_plates.py on the newest take: registers it (an affine fit to the depth edges; rejected above 8 px) and installs
#      assets/video/plates/<shot key>/plate_<index>.png, depth_<index>.png and plate_<index>.json.
# The hero plates of R5-SHOTS's hero frames are made with it after the merge, within the rest of the round's Gemini budget.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PY="${PLATE_PY:-$HOME/.venvs/beat-em-up-video/bin/python}"
KEY="${1:?usage: tools/video/make_plate.sh <shot key> <output frame | still> [options]}"
FRAME="${2:?usage: tools/video/make_plate.sh <shot key> <output frame | still> [options]}"
shift 2
LOCATION=""
SWATCH=""
INDEX=0
TAKE=1
INSTALL=0
RUN=0
RECAPTURE=0
FOV=""
REFS="${PLATE_REFS:-/Users/arachne/repos/beat-em-up-PoC/.worktrees/video/captures/video/ref/frames}"
while [ $# -gt 0 ]; do
	case "$1" in
		--location) LOCATION="$2"; shift 2 ;;
		--swatch) SWATCH="$2"; shift 2 ;;
		--index) INDEX="$2"; shift 2 ;;
		--take) TAKE="$2"; shift 2 ;;
		--install) INSTALL=1; shift ;;
		--run) RUN=1; shift ;;
		--recapture) RECAPTURE=1; shift ;;
		--fov) FOV="$2"; shift 2 ;;
		*) echo "make_plate: unknown argument $1" >&2; exit 2 ;;
	esac
done
case "$LOCATION" in
	street) DEFAULT_SWATCH="$REFS/ref2_42.0.png" ;;
	dusk) DEFAULT_SWATCH="$REFS/ref2_50.5.png" ;;
	boss) DEFAULT_SWATCH="$REFS/ref1_5.3.png" ;;
	*) echo "make_plate: --location street|dusk|boss is required" >&2; exit 2 ;;
esac
SWATCH="${SWATCH:-$DEFAULT_SWATCH}"
NAME="plate_$INDEX"
WORK="$ROOT/captures/video/plates/$KEY"
GEM="$WORK/gemini"
SRC="$ROOT/assets/source/video_plates/$KEY"
DEST="$ROOT/assets/video/plates/$KEY"

if [ "$RECAPTURE" = 1 ] || [ ! -s "$WORK/${NAME}_blockout.png" ] || [ ! -s "$WORK/${NAME}_depth.png" ]; then
	ARGS=(--name "$NAME")
	[ "$FRAME" = "still" ] || ARGS+=(--frame "$FRAME")
	[ -z "$FOV" ] || ARGS+=(--fov "$FOV")
	"$ROOT/tools/video/plate_capture.sh" "$KEY" "$WORK" "${ARGS[@]}"
fi
"$PY" -I "$ROOT/tools/video/make_plate_jobs.py" "$KEY" "$WORK/${NAME}_blockout.png" "$SWATCH" "$LOCATION" "$GEM" --name "$NAME" --take "$TAKE"
mkdir -p "$SRC"
cp "$GEM/jobs.json" "$SRC/jobs.json"
cp "$GEM/prompt_${NAME}_take${TAKE}.txt" "$SRC/"
cp "$GEM/${NAME}_blockout.jpg" "$SRC/"
if [ "$RUN" = 1 ]; then
	python3 -I "$ROOT/tools/gemini_image.py" "$GEM/jobs.json" "${NAME}_gemini${TAKE}"
fi
if [ "$INSTALL" = 1 ]; then
	PAINTING="$(ls "$GEM/${NAME}_gemini${TAKE}".* | head -1)"
	"$PY" -I "$ROOT/tools/video/register_plates.py" "$PAINTING" "$WORK" "$NAME" "$DEST" "$INDEX"
fi
if [ "$RUN" = 0 ] && [ "$INSTALL" = 0 ]; then
	echo "make_plate: the job is ready. Add the ledger row, then: python3 -I tools/gemini_image.py $GEM/jobs.json ${NAME}_gemini${TAKE}"
fi
