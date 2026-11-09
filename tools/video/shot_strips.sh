#!/usr/bin/env bash
# One image of several shots for the blocking look: a row of evenly spaced frames a shot, the rows stacked.
# Usage: tools/video/shot_strips.sh <out.png> <tiles a row> <tile width> <shot.mkv>...
set -euo pipefail
OUT="${1:?out png}"; TILES="${2:?tiles}"; WIDTH="${3:?width}"; shift 3
TMP="$(mktemp -d)"
i=0
for mkv in "$@"; do
	frames="$(ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 "$mkv")"
	step=$(( frames / TILES ))
	[ "$step" -ge 1 ] || step=1
	ffmpeg -loglevel error -y -i "$mkv" -vf "select='not(mod(n\,$step))',scale=$WIDTH:-1,tile=${TILES}x1:padding=2:color=black" -frames:v 1 "$TMP/row$i.png"
	i=$((i + 1))
done
ffmpeg -loglevel error -y $(for n in $(seq 0 $((i - 1))); do printf -- "-i %s " "$TMP/row$n.png"; done) -filter_complex "vstack=inputs=$i" "$OUT"
rm -rf "$TMP"
