#!/usr/bin/env bash
# Compare two renders of one shot, frame by frame (the determinism check of the cine stage).
# Usage: tools/video/compare_shots.sh <dir A> <dir B> [shot]
#   tools/video/shoot.sh moving_punk captures/video/work/a; tools/video/shoot.sh moving_punk captures/video/work/b
#   tools/video/compare_shots.sh captures/video/work/a captures/video/work/b moving_punk
# Reports, from the frames' SHA-256 files (<shot>.sha256: the pixels as the writer read them, picture then mask):
#   how many frames are bit-identical, and the first frame that is not; and, from the mezzanines, the PSNR of every frame pair
#   (the lowest and the mean, in dB; 50 dB and up is not visible), through ffmpeg. Exits 0 when every picture and mask frame is
#   bit-identical, 1 when not (the PSNR line says how far), 2 on a usage error.
set -euo pipefail

A="${1:?usage: tools/video/compare_shots.sh <dir A> <dir B> [shot]}"
B="${2:?usage: tools/video/compare_shots.sh <dir A> <dir B> [shot]}"
SHOT="${3:-$(basename "$(ls "$A"/*.sha256 | head -1)" .sha256)}"
FFMPEG="${FFMPEG:-ffmpeg}"

for dir in "$A" "$B"; do
	[ -f "$dir/$SHOT.sha256" ] || { echo "compare: no $dir/$SHOT.sha256" >&2; exit 2; }
done

total="$(wc -l < "$A/$SHOT.sha256" | tr -d ' ')"
totalb="$(wc -l < "$B/$SHOT.sha256" | tr -d ' ')"
if [ "$total" != "$totalb" ]; then
	echo "compare: the renders have different frame counts ($total and $totalb)"
	exit 1
fi
pic=0; mask=0; first=""
while IFS= read -r line_a && IFS= read -r line_b <&3; do
	set -- $line_a; ia="$1"; pa="${2:-}"; ma="${3:-}"
	set -- $line_b; pb="${2:-}"; mb="${3:-}"
	[ "$pa" = "$pb" ] && pic=$((pic + 1)) || { [ -n "$first" ] || first="$ia"; }
	[ "$ma" = "$mb" ] && mask=$((mask + 1)) || { [ -n "$first" ] || first="$ia"; }
done < "$A/$SHOT.sha256" 3< "$B/$SHOT.sha256"
echo "compare $SHOT: $pic of $total picture frames and $mask of $total mask frames are bit-identical${first:+ (first difference: frame $first)}"

if [ -f "$A/$SHOT.mkv" ] && [ -f "$B/$SHOT.mkv" ]; then
	stats="$(mktemp)"
	"$FFMPEG" -loglevel error -i "$A/$SHOT.mkv" -i "$B/$SHOT.mkv" -lavfi "psnr=stats_file=$stats" -f null - || true
	if [ -s "$stats" ]; then
		awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^psnr_avg:/) { split($i, p, ":"); v = (p[2] == "inf") ? 99 : p[2]; n++; s += v; if (n == 1 || v < m) m = v } }
			END { if (n) printf "compare %s: PSNR over %d frames: lowest %.1f dB, mean %.1f dB\n", "'"$SHOT"'", n, m, s / n }' "$stats"
	fi
	rm -f "$stats"
fi
[ "$pic" = "$total" ] && [ "$mask" = "$total" ]
