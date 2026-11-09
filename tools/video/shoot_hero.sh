#!/usr/bin/env bash
# Render the blind set's hero frames (video/shots/hero_frames.json, round 5) at 2560x1440, one PNG each, through tools/video/shoot.sh.
# Usage: tools/video/shoot_hero.sh [out dir] [shot keys...]
#   tools/video/shoot_hero.sh captures/video/r5shots/hero                 all seven
#   tools/video/shoot_hero.sh captures/video/r5shots/hero t07_roof_knockoff   just that one
# Environment: HERO_SIZE (default 2560x1440), SHOOT_ARGS (more arguments for the cine bot, e.g. --shot-skip=ink.tres).
# A frame is the shot played from its start with only the pick of the output frame written: the window opens at frame/24 s and is three ticks long.
# Output: <out dir>/<key>.png and <out dir>/<key>/ (the run's folder: the mezzanine of the frame, its log and its cue sheet).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/captures/video/r5shots/hero}"
shift || true
SIZE="${HERO_SIZE:-2560x1440}"
mkdir -p "$OUT"
entries="$(python3 -I - "$ROOT/video/shots/hero_frames.json" "$@" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
want = set(sys.argv[2:])
for e in data["frames"]:
    if not want or e["key"] in want:
        print(e["key"], e["frame"])
PY
)"
failed=0
while read -r key frame; do
	[ -n "$key" ] || continue
	from="$(python3 -c "print('%.6f' % ($frame / 24.0))")"
	to="$(python3 -c "print('%.6f' % ($frame / 24.0 + 0.05))")"
	if SHOOT_ARGS="--shot-size=$SIZE --shot-mask=0 --shot-from=$from --shot-to=$to ${SHOOT_ARGS:-}" "$ROOT/tools/video/shoot.sh" "$key" "$OUT/$key" < /dev/null; then
		ffmpeg -nostdin -loglevel error -y -i "$OUT/$key/$key.mkv" -frames:v 1 "$OUT/$key.png" || failed=1
	else
		echo "hero: $key FAILED"
		failed=1
	fi
done <<< "$entries"
exit "$failed"
