#!/usr/bin/env bash
# Record a list of crowd-bot acts, one act per process, and cut each one's sheets, into one shared
# folder that every reviewer and builder of a round reads (docs/HANDOFF.md, "Usage rules": record
# once). Usage:
#   tools/record_acts.sh <out dir> "<slug>|<act title>" ["<slug>|<act title>" ...]
# Each act lands in <out dir>/<slug>/ (bot.avi, bot.log, sheets/), and the script prints one line per
# act with the error-line count of its bot.log. Extra bot arguments go in CAPTURE_ARGS, as for
# tools/capture_bot.sh. Run it in the background: Movie Maker records at about half real time.
set -u
out="$1"; shift
mkdir -p "$out"
for spec in "$@"; do
	slug="${spec%%|*}"
	title="${spec#*|}"
	tools/capture_bot.sh res://tests/bot/crowd_bot.tscn "$out/$slug" "$title" 6 > "$out/$slug.capture.out" 2>&1
	code=$?
	tools/look_sheets.sh "$out/$slug/bot.avi" "$out/$slug/sheets" > "$out/$slug.sheets.out" 2>&1
	errors=$(grep -cE 'SCRIPT ERROR|SHADER ERROR|^ERROR' "$out/$slug/bot.log" 2>/dev/null || echo "?")
	echo "$slug exit=$code errors=$errors"
done
