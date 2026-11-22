#!/bin/bash
# Usage: tools/look/make_judge_set.sh <out_dir> <dir> [<dir> ...]   (env SEED=<int>, default 1)
# Re-encodes every png/jpg in the input dirs to 960x540 JPEG (ffmpeg q:v 5), shuffles with a fixed
# seed and writes j_NN.jpg plus key.json (id -> source, group = input dir name). A judge must not read key.json.
set -euo pipefail
out="$1"; shift
seed="${SEED:-1}"
mkdir -p "$out"
list=$(mktemp)
for d in "$@"; do
	find "$d" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' \) | sort | sed "s|^|$(basename "$d")\t|" >> "$list"
done
python3 -I - "$list" "$seed" "$out" <<'PY'
import json, random, subprocess, sys
rows = [l.rstrip("\n").split("\t") for l in open(sys.argv[1])]
random.Random(int(sys.argv[2])).shuffle(rows)
out = sys.argv[3]
key = {}
for i, (grp, src) in enumerate(rows, 1):
	jid = f"j_{i:02d}"
	subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", src, "-vf", "scale=960:540:flags=lanczos",
		"-q:v", "5", f"{out}/{jid}.jpg"], check=True)
	key[jid] = {"group": grp, "src": src}
json.dump(key, open(f"{out}/key.json", "w"), indent=1)
print(f"{len(rows)} images -> {out}")
PY
rm -f "$list"
