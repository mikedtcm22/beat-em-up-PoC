#!/usr/bin/env bash
# The weights x bind-route A/B sheet (M4-plan A2 step 3): one row per pose, four columns = <report A> A-pose route, <report A>
# arms-down bake, <report B> A-pose route, <report B> bake, three-quarter view. Needs ffmpeg and the stills run.py wrote.
#   tools/pipeline/ab_sheet.sh assets/source/characters/punk/report assets/source/characters/punk/report_auto out.png [pose ...]
set -euo pipefail
cd "$(dirname "$0")/../.."
a="$1"; b="$2"; out="$3"; shift 3
poses=("$@")
[ ${#poses[@]} -gt 0 ] || poses=(guard elbow_150 arm_raise_140 knee_m130 spine_twist)
tmp="$(mktemp -d)"
rows=()
for pose in "${poses[@]}"; do
	ffmpeg -loglevel error -y -i "$a/stills/apose_${pose}_three_quarter.png" -i "$a/stills/rest_${pose}_three_quarter.png" \
		-i "$b/stills/apose_${pose}_three_quarter.png" -i "$b/stills/rest_${pose}_three_quarter.png" -filter_complex "hstack=4" "$tmp/$pose.png"
	rows+=(-i "$tmp/$pose.png")
done
ffmpeg -loglevel error -y "${rows[@]}" -filter_complex "vstack=${#poses[@]},scale=1440:-1" "$out"
rm -rf "$tmp"
echo "wrote $out"
