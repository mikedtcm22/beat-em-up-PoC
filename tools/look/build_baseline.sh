#!/bin/bash
# Usage: tools/look/build_baseline.sh <work_dir>   Builds the baseline judge sets (3 shuffles) in <work_dir>/run{1,2,3}.
# Groups: trailer (25 frames, titles and black skipped), refs (8 reference stills), m6 (9 cropped game tiles).
set -euo pipefail
cd "$(dirname "$0")/../.."
w="$1"; src=assets/source
rm -rf "$w/in"; mkdir -p "$w/in/trailer" "$w/in/refs" "$w/in/m6"
for n in 01 02 03 04 05 06 07 08 09 10 11 13 14 15 16 17 18 22 23 24 25 26 27 28 29; do cp $src/trailer_ref/frames/t_$n.jpg "$w/in/trailer/"; done
for r in ref1_0.9 ref1_5.3 ref1_7.2 ref1_24.4 ref2_3.5 ref2_12.9 ref2_50.5 ref2_6.5; do cp $src/trailer_ref/ref/$r.png "$w/in/refs/"; done
cp $src/m6_baseline/*.png "$w/in/m6/"
for s in 1 2 3; do SEED=$((s * 101)) tools/look/make_judge_set.sh "$w/run$s" "$w/in/trailer" "$w/in/refs" "$w/in/m6"; python3 -I tools/look/judge_sheets.py "$w/run$s" 6 2>/dev/null || ~/.venvs/beat-em-up-video/bin/python -I tools/look/judge_sheets.py "$w/run$s" 6; done
