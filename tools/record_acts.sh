#!/usr/bin/env bash
# Record a list of crowd-bot acts, one act per process, and cut each one's sheets, into one shared
# folder that every reviewer and builder of a round reads (docs/HANDOFF.md, "Usage rules": record
# once). Usage:
#   tools/record_acts.sh <out dir> "<slug>|<act title>" ["<slug>|<act title>" ...]
# Each act lands in <out dir>/<slug>/ (bot.avi, bot.log, sheets/), and the script prints one line per
# act with the error-line count of its bot.log. Acts without LOOK-MARK lines (crowd, level) get plain
# overview pages, sheets/overview_NN.png, at SHEET_FPS stills a second (default 2). Extra bot
# arguments go in CAPTURE_ARGS, as for tools/capture_bot.sh. Run it in the background: Movie Maker
# records at about half real time.
set -u
out="$1"; shift
mkdir -p "$out"
for spec in "$@"; do
	slug="${spec%%|*}"
	title="${spec#*|}"
	tools/capture_bot.sh res://tests/bot/crowd_bot.tscn "$out/$slug" "$title" 6 > "$out/$slug.capture.out" 2>&1
	code=$?
	if ! tools/look_sheets.sh "$out/$slug/bot.avi" "$out/$slug/sheets" > "$out/$slug.sheets.out" 2>&1; then
		# Not a look act (no LOOK-MARK lines): plain overview pages instead, 5 x 4 tiles of 480 px
		# at SHEET_FPS stills a second (default 2), one page per 20 tiles.
		mkdir -p "$out/$slug/sheets"
		ffmpeg -loglevel error -y -i "$out/$slug/bot.avi" -vf "fps=${SHEET_FPS:-2},scale=480:-1,tile=5x4" \
			"$out/$slug/sheets/overview_%02d.png" < /dev/null >> "$out/$slug.sheets.out" 2>&1
	fi
	errors=$(grep -cE 'SCRIPT ERROR|SHADER ERROR|^ERROR' "$out/$slug/bot.log" 2>/dev/null || echo "?")
	echo "$slug exit=$code errors=$errors"
done
