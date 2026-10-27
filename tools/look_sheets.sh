#!/usr/bin/env bash
# Cut the review sheets of a look-act recording (tests/bot/acts/look_acts.gd) out of its video, from
# the LOOK-MARK and LOOK-RECT lines the acts print (tests/bot/look_rect.gd).
# Usage: tools/look_sheets.sh <avi> <out dir> [--log <bot.log>] [--offset <frames>] [--slug <slug>]...
#   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/look "Look:" 6
#   tools/look_sheets.sh captures/look/bot.avi captures/look/sheets
#   tools/look_sheets.sh captures/look/bot.avi captures/look/sheets --slug c1 --slug c2
# For every act (a slug, c1 ... c13) it writes, under <out dir>/<slug>/:
#   overview_NN.png                     the act at 6 fps, 5 x 4 tiles of 480 px a page
#   stills/<slug>_f<frame>_<label>.png  a full-resolution still at every LOOK-MARK (`start` and `end`
#                                       only delimit the act, so they get none)
#   crops/<slug>_f<frame>_<region>.png  every LOOK-RECT (head, hands, body) cut out of that frame and
#                                       scaled 2x
# and <out dir>/index.txt, one line a file: slug, frame, label or region, path.
# The log is the bot's: <avi's folder>/bot.log (capture_bot.sh writes it there) unless --log says
# otherwise. The bot prints every line twice (live and in its summary); the copies are dropped.
# A rectangle is in 1600x900 pixels; it is scaled when the video has another size.
#
# Frames: a log line's f<frame> is the video frame (counting from 0) of the state it describes
# (look_rect.gd, video_frame()), so the video frame is f<frame> + FRAME_OFFSET with FRAME_OFFSET 0;
# --offset shifts every frame (a recording that is not Movie Maker's, or a log written by an older
# look_rect.gd, which counted physics ticks: offset -2). A still is cut with a seek to just before
# its frame, which an all-intra MJPEG video answers exactly.
set -euo pipefail

FRAME_OFFSET=0
REF_W=1600
FFMPEG="${FFMPEG:-ffmpeg}"
FFPROBE="${FFPROBE:-ffprobe}"
# ffmpeg reads commands from the terminal: inside a `while read` loop it would eat the loop's input.
ffm() { "$FFMPEG" -nostdin "$@"; }

AVI=""
OUT=""
LOG=""
SLUGS=()
while [ $# -gt 0 ]; do
	case "$1" in
		--log) LOG="$2"; shift 2 ;;
		--offset) FRAME_OFFSET="$2"; shift 2 ;;
		--slug) SLUGS+=("$2"); shift 2 ;;
		-h|--help) sed -n '2,/^set -e/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
		*)
			if [ -z "$AVI" ]; then AVI="$1"; elif [ -z "$OUT" ]; then OUT="$1"; else echo "look_sheets: unexpected argument $1" >&2; exit 2; fi
			shift ;;
	esac
done
[ -n "$AVI" ] && [ -n "$OUT" ] || { echo "usage: tools/look_sheets.sh <avi> <out dir> [--log <bot.log>] [--offset <frames>] [--slug <slug>]..." >&2; exit 2; }
[ -f "$AVI" ] || { echo "look_sheets: no such video: $AVI" >&2; exit 2; }
[ -n "$LOG" ] || LOG="$(dirname "$AVI")/bot.log"
[ -f "$LOG" ] || { echo "look_sheets: no log at $LOG (pass --log)" >&2; exit 2; }

mkdir -p "$OUT"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/look_sheets.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# --- The video: size and frame rate ---
IFS=',' read -r VW VH VRATE < <("$FFPROBE" -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate -of csv=p=0 "$AVI")
FPS="$(awk -v r="$VRATE" 'BEGIN { split(r, a, "/"); printf "%.6f", a[1] / (a[2] > 0 ? a[2] : 1) }')"

# --- The log: marks and rectangles, each once ---
awk '!seen[$0]++' "$LOG" | grep -E '^LOOK-(MARK|RECT) ' > "$TMP/look.txt" || true
awk '$1 == "LOOK-MARK" { print $2, substr($3, 2), $4 }' "$TMP/look.txt" > "$TMP/marks.txt"
awk '$1 == "LOOK-RECT" { print $2, substr($3, 2), $4, $5, $6, $7, $8 }' "$TMP/look.txt" > "$TMP/rects.txt"
if [ ! -s "$TMP/marks.txt" ]; then
	echo "look_sheets: no LOOK-MARK lines in $LOG: record the acts first (capture_bot.sh ... \"Look:\")" >&2
	exit 1
fi
awk '!s[$1]++ { print $1 }' "$TMP/marks.txt" > "$TMP/slugs.txt"

wanted() {
	[ ${#SLUGS[@]} -eq 0 ] && return 0
	local s
	for s in "${SLUGS[@]}"; do [ "$s" = "$1" ] && return 0; done
	return 1
}

# The seek time (s) for video frame `$1` (a log frame, before the offset). ffmpeg's -ss gives the first
# frame whose time is at or after it, and frame n is at n / fps: a quarter of a frame early is frame n.
frame_time() {
	awk -v f="$1" -v o="$FRAME_OFFSET" -v r="$FPS" 'BEGIN { t = (f + o - 0.25) / r; printf "%.5f", (t < 0 ? 0 : t) }'
}

: > "$OUT/index.txt"
made_stills=0
made_crops=0
while read -r slug; do
	wanted "$slug" || continue
	dir="$OUT/$slug"
	rm -rf "$dir"
	mkdir -p "$dir/stills" "$dir/crops"
	awk -v s="$slug" '$1 == s' "$TMP/marks.txt" > "$TMP/m.txt"
	awk -v s="$slug" '$1 == s' "$TMP/rects.txt" > "$TMP/r.txt"
	first="$(awk '$3 == "start" { print $2; exit }' "$TMP/m.txt")"
	last="$(awk '$3 == "end" { print $2 }' "$TMP/m.txt" | tail -1)"
	[ -n "$first" ] || first="$(awk 'NR == 1 || $2 < m { m = $2 } END { print m }' "$TMP/m.txt")"
	[ -n "$last" ] || last="$(awk '$2 > m { m = $2 } END { print m }' "$TMP/m.txt")"

	# The overview: the act at 6 fps, five tiles by four a page.
	t0="$(frame_time "$first")"
	len="$(awk -v a="$first" -v b="$last" -v r="$FPS" 'BEGIN { printf "%.4f", (b - a + 1) / r }')"
	ffm -loglevel error -y -ss "$t0" -t "$len" -i "$AVI" -vf "fps=6,scale=480:-1,tile=5x4" -fps_mode vfr "$dir/overview_%02d.png"

	# Every frame that gets a still or a crop is cut once; a still is a copy for its label.
	awk '$3 != "start" && $3 != "end" { print $2 }' "$TMP/m.txt" > "$TMP/frames.txt"
	awk '{ print $2 }' "$TMP/r.txt" >> "$TMP/frames.txt"
	sort -un "$TMP/frames.txt" > "$TMP/frames_u.txt"
	while read -r frame; do
		ffm -loglevel error -y -ss "$(frame_time "$frame")" -i "$AVI" -frames:v 1 -fps_mode vfr "$TMP/f$frame.png"
	done < "$TMP/frames_u.txt"
	while read -r _ frame label; do
		[ "$label" = "start" ] || [ "$label" = "end" ] && continue
		file="$dir/stills/${slug}_f${frame}_${label}.png"
		cp "$TMP/f$frame.png" "$file"
		echo "$slug $frame $label $file" >> "$OUT/index.txt"
		made_stills=$((made_stills + 1))
	done < "$TMP/m.txt"

	# The crops: the rectangle in video pixels, clipped to the video, then twice the size.
	while read -r _ frame region x y w h; do
		spec="$(awk -v x="$x" -v y="$y" -v w="$w" -v h="$h" -v vw="$VW" -v vh="$VH" -v rw="$REF_W" 'BEGIN {
			k = vw / rw
			x = int(x * k); y = int(y * k); w = int(w * k + 0.5); h = int(h * k + 0.5)
			if (x + w > vw) w = vw - x
			if (y + h > vh) h = vh - y
			if (w < 2 || h < 2) exit
			printf "%d:%d:%d:%d", w, h, x, y
		}')"
		[ -n "$spec" ] || continue
		file="$dir/crops/${slug}_f${frame}_${region}.png"
		ffm -loglevel error -y -i "$TMP/f$frame.png" -vf "crop=$spec,scale=iw*2:ih*2:flags=lanczos" -frames:v 1 "$file"
		echo "$slug $frame $region $file" >> "$OUT/index.txt"
		made_crops=$((made_crops + 1))
	done < "$TMP/r.txt"
	rm -f "$TMP"/f*.png
	echo "look_sheets: $slug: frames $first-$last, $(ls "$dir"/overview_*.png | wc -l | tr -d ' ') overview pages, $(ls "$dir/stills" | wc -l | tr -d ' ') stills, $(ls "$dir/crops" | wc -l | tr -d ' ') crops"
done < "$TMP/slugs.txt"
echo "look_sheets: $made_stills stills, $made_crops crops in $OUT (video ${VW}x${VH} at ${FPS} fps, frame offset $FRAME_OFFSET); index $OUT/index.txt"
