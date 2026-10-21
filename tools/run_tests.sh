#!/usr/bin/env bash
# Run the GUT unit test suite headless. Exit code is non-zero on any failure.
# Usage: tools/run_tests.sh [extra GUT args, e.g. -gselect=test_combo_parser]
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"

# Make sure the import cache (.godot/) exists and is current before running tests.
"$GODOT" --headless --import --quit >/dev/null 2>&1 || true

"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json "$@"
