#!/usr/bin/env bash
# Plan B's trailer (docs/video/HANDOFF.md, the full cut): the 14 trailer shots in order, each the newest Runway restyle where there
# is one (captures/video/planb/restyle/<tNN>_r<N>/<tNN>_r<N>.mp4, the highest N), else our 1080p render (inputs/<key>_1080.mp4).
# Usage: tools/video/planb_trailer.sh [name]   (default planb_trailer)
# Writes captures/video/planb/<name>_1080p.mp4 (clean, no labels), <name>_side_by_side.mp4 (our render left, the cut right, 1920x540)
# and <name>_720p_labelled.mp4 (each shot labelled with its key and
# its source, for notes), and a contact strip <name>_contact.jpg. No sound.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/captures/video/planb"
NAME="${1:-planb_trailer}"
PARTS="$P/trailer_parts"
rm -rf "$PARTS"; mkdir -p "$PARTS"
: > "$PARTS/list_1080.txt"; : > "$PARTS/list_720.txt"; : > "$PARTS/list_sbs.txt"
for f in "$ROOT"/video/shots/t[0-9][0-9]_*.tscn; do
	key="$(basename "$f" .tscn)"; k="${key%%_*}"
	src="$P/inputs/${key}_1080.mp4"; what="our render (not restyled)"
	for d in $(ls -d "$P"/restyle/${k}_r* 2>/dev/null | sort -V); do
		[ -s "$d/$(basename "$d").mp4" ] && { src="$d/$(basename "$d").mp4"; what="Runway restyle $(basename "$d")"; }
	done
	[ -s "$src" ] || { echo "trailer: no source for $key" >&2; exit 2; }
	ffmpeg -v error -y -i "$src" -vf "scale=1920:1080:flags=lanczos,fps=24,format=yuv420p" -c:v libx264 -crf 16 -preset medium -an \
		"$PARTS/$key.mp4"
	echo "file '$PARTS/$key.mp4'" >> "$PARTS/list_1080.txt"
	"$HOME/.venvs/beat-em-up-video/bin/python" -I - "$PARTS/${k}_label.png" "$k  ·  $what" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont
font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 22)
text = sys.argv[2]
im = Image.new("RGBA", (int(font.getlength(text)) + 24, 36), (0, 0, 0, 150))
ImageDraw.Draw(im).text((12, 6), text, font=font, fill=(255, 255, 255, 235))
im.save(sys.argv[1])
PY
	ffmpeg -v error -y -i "$PARTS/$key.mp4" -i "$PARTS/${k}_label.png" -filter_complex "[0]scale=1280:720[v];[v][1]overlay=16:main_h-overlay_h-12" \
		-c:v libx264 -crf 20 -preset medium -pix_fmt yuv420p -an "$PARTS/${key}_720.mp4"
	echo "file '$PARTS/${key}_720.mp4'" >> "$PARTS/list_720.txt"
	# Side by side: our 1080p render (round 5's look) left, this cut right, each 960x540.
	ffmpeg -v error -y -i "$P/inputs/${key}_1080.mp4" -i "$PARTS/$key.mp4" -filter_complex \
		"[0]scale=960:540:flags=lanczos,fps=24[a];[1]scale=960:540:flags=lanczos[b];[a][b]hstack,format=yuv420p" \
		-c:v libx264 -crf 18 -preset medium -an "$PARTS/${key}_sbs.mp4"
	echo "file '$PARTS/${key}_sbs.mp4'" >> "$PARTS/list_sbs.txt"
	echo "$key: $what"
done
ffmpeg -v error -y -f concat -safe 0 -i "$PARTS/list_1080.txt" -c copy -movflags +faststart "$P/${NAME}_1080p.mp4"
ffmpeg -v error -y -f concat -safe 0 -i "$PARTS/list_720.txt" -c copy -movflags +faststart "$P/${NAME}_720p_labelled.mp4"
ffmpeg -v error -y -f concat -safe 0 -i "$PARTS/list_sbs.txt" -c copy -movflags +faststart "$P/${NAME}_side_by_side.mp4"
ffmpeg -v error -y -i "$P/${NAME}_720p_labelled.mp4" -vf "fps=1,scale=320:-1,tile=7x7" -frames:v 1 "$P/${NAME}_contact.jpg"
echo "trailer: $P/${NAME}_1080p.mp4 ($(ffprobe -v error -show_entries format=duration -of csv=p=0 "$P/${NAME}_1080p.mp4") s)"
