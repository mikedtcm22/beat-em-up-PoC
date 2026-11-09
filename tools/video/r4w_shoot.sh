#!/usr/bin/env bash
# R4-WORLD: shoot several stills in a row (one process each) into captures/video/r4w/<tag>/<shot>/, and write a 1280-wide copy.
# Usage: tools/video/r4w_shoot.sh <tag> <shot> [<shot>...]     (SHOOT_ARGS selects pieces, as shoot.sh)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TAG="$1"; shift
for shot in "$@"; do
	out="$ROOT/captures/video/r4w/$TAG/$shot"
	"$ROOT/tools/video/shoot.sh" "$shot" "$out" | tail -1
	ffmpeg -loglevel error -y -i "$out/$shot.png" -vf scale=1280:-1 "$ROOT/captures/video/r4w/$TAG/${shot}_1280.png"
done
