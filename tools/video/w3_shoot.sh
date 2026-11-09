#!/usr/bin/env bash
# LD-WORLD3 look-dev helper: shoot several shots one after another: tools/video/w3_shoot.sh <run dir> <shot> [<shot> ...]
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUN="$1"; shift
for k in "$@"; do
	"$ROOT/tools/video/shoot.sh" "$k" "$RUN/$k" > "$RUN.$k.log" 2>&1 || echo "FAILED $k"
	tail -1 "$RUN.$k.log"
	grep -h "SHADER ERROR\|SCRIPT ERROR\|^ERROR: [^0-9]*[Ss]hader\|Parse Error" "$RUN/$k/shoot.log" | head -5
done
echo ALLDONE
