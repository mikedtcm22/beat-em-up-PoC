#!/usr/bin/env bash
# The whole A/B strip in two renders and a LUT, into <out dir>: a.png b.png c.png d.png e.png (2560x1440),
# lut.png (the palette LUT), lut_report.json, and the contact sheet strip.png.
#   1. render a-d (the game's look, + light, + flat paint, + ink)
#   2. tools/video/palette_lut.py: measure the reference and d.png, write the LUT (PRE_LUT=<strip> composes it on the
#      game's grade, for a run that keeps that grade on)
#   3. render a-e again with the LUT (a-d come out the same; they are re-saved)
# Usage: video/spike/make_strip.sh <out dir> <reference png> [extra bot args, e.g. --set=paint_lod=4.5]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_ARG="${1:?usage: video/spike/make_strip.sh <out dir> <reference png> [bot args]}"
REF="${2:?reference png}"
shift 2
PY="${PY:-$HOME/.venvs/beat-em-up-video/bin/python}"
mkdir -p "$OUT_ARG"
OUT="$(cd "$OUT_ARG" && pwd)"
LUT_DIR="$ROOT/captures/video/p0-spike/lut"
mkdir -p "$LUT_DIR"
"$ROOT/video/spike/run_spike.sh" "$OUT/pass1" abcd "$@"
"$PY" -I "$ROOT/tools/video/palette_lut.py" "$REF" "$OUT/pass1/d.png" "$LUT_DIR/lut.png" \
	${PRE_LUT:+--pre-lut "$PRE_LUT"} --report "$OUT/lut_report.json" ${LUT_ARGS:-} > "$OUT/lut_stdout.json"
cp "$LUT_DIR/lut.png" "$OUT/lut.png"
"$ROOT/video/spike/run_spike.sh" "$OUT" abcde "$@"
ffmpeg -loglevel error -y -i "$OUT/a.png" -i "$OUT/b.png" -i "$OUT/c.png" -i "$OUT/d.png" -i "$OUT/e.png" \
	-filter_complex "[0]scale=640:-1[a];[1]scale=640:-1[b];[2]scale=640:-1[c];[3]scale=640:-1[d];[4]scale=640:-1[e];color=c=black:s=640x360[k];[a][b][c][d][e][k]xstack=inputs=6:layout=0_0|640_0|1280_0|0_360|640_360|1280_360" \
	-frames:v 1 "$OUT/strip.png"
echo "make_strip: $OUT/strip.png"
