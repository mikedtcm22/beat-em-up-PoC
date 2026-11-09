#!/usr/bin/env bash
# A contact sheet of a rendered shot, for the look: tools/video/shot_sheet.sh <shot.mkv> <out.png> [frames per second of the sheet] [columns] [rows] [tile width]
# The defaults: 6 frames a second (every 4th frame of a 24 fps shot), 5 x 4 tiles of 360 px (an 1800 px sheet is too wide to judge a 1000 px view, so
# the default is 3 columns of 340 px... set the columns and the tile width to taste).
set -euo pipefail
IN="${1:?usage: shot_sheet.sh <shot.mkv> <out.png> [fps] [cols] [rows] [tile width]}"
OUT="${2:?out png}"
FPS="${3:-6}"
COLS="${4:-4}"
ROWS="${5:-3}"
WIDTH="${6:-250}"
ffmpeg -loglevel error -y -i "$IN" -vf "fps=$FPS,scale=$WIDTH:-1,tile=${COLS}x${ROWS}:padding=2:color=black" -frames:v 1 "$OUT"
