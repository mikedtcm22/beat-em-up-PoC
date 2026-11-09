#!/usr/bin/env bash
# Render the trailer's shots (video/shots/t*.tscn, PLAN.md section 5) one after the other through tools/video/shoot.sh.
# Usage: tools/video/shoot_trailer.sh [out dir] [shot keys...]
#   tools/video/shoot_trailer.sh                                  the blocking pass: every shot at 1280x720, no mask, into captures/video/shots_blocking/
#   tools/video/shoot_trailer.sh captures/video/shots_blocking t03_punk_combo t07_roof_knockoff     just those
# Environment: TRAILER_SIZE (default 1280x720; the final renders say 2560x1440), TRAILER_MASK (default 0: no character mask in the blocking pass).
# Each shot is a folder <out dir>/<key>/ with the mezzanine, the cue sheet <key>_events.log and shoot.log; one summary line a shot, and a non-zero
# exit when any shot failed (the shots after a failure still render).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/captures/video/shots_blocking}"
shift || true
if [ "$#" -gt 0 ]; then
	KEYS=("$@")
else
	KEYS=()
	for f in "$ROOT"/video/shots/t[0-9][0-9]_*.tscn; do
		KEYS+=("$(basename "$f" .tscn)")
	done
fi
SIZE="${TRAILER_SIZE:-1280x720}"
MASK="${TRAILER_MASK:-0}"
failed=0
for key in "${KEYS[@]}"; do
	if ! SHOOT_ARGS="--shot-size=$SIZE --shot-mask=$MASK ${SHOOT_ARGS:-}" "$ROOT/tools/video/shoot.sh" "$key" "$OUT/$key"; then
		echo "trailer: $key FAILED"
		failed=1
	fi
done
exit "$failed"
