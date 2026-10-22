#!/usr/bin/env bash
# Run the GUT unit test suite headless. Exit code is non-zero on any failure.
# Usage: tools/run_tests.sh [extra GUT args, e.g. -gselect=test_combo_parser]
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"

# Make sure the import cache (.godot/) exists and is current before running tests.
"$GODOT" --headless --import --quit >/dev/null 2>&1 || true

# --fixed-fps 60 steps exactly one 1/60 s physics tick per frame without waiting for
# real time, so frame-timed combat tests run many times faster and deterministically.
"$GODOT" --headless --fixed-fps 60 -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json "$@"
