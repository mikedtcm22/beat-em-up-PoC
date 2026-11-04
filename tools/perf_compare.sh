#!/usr/bin/env bash
# Compare frame times of a perf act across git refs, windowed with vsync off, on a quiet machine.
# Usage: tools/perf_compare.sh [--bot <res:// bot scene>] [--act "<title text>"]... [--runs N] [--vsync on|off] [--force] [--keep] [--out DIR] <ref> [<ref>...]
#   tools/perf_compare.sh afdb39e m4/art-pipeline
#   tools/perf_compare.sh --act "Perf, six with ragdolls" --act "Look: Perf, six art Punks" --runs 3 afdb39e HEAD
#   tools/perf_compare.sh --force --runs 1 HEAD        # one ref: a smoke run of the tool, no delta
#   tools/perf_compare.sh --bot res://tests/bot/perf_level_bot.tscn --act "Perf: level walk" 92c90e2 HEAD   # the level walk (M6 D29)
# --bot picks the bench's bot scene (default res://tests/bot/perf_bot.tscn, the crowd room). The level
#   walk's is tests/bot/perf_level_bot.tscn with the act "Perf: level walk" (level_acts/perf_acts.gd);
#   with --bot and no --act that act is the default. The bench's files (tests/bot/perf_*, and the level
#   bot and its acts for a level bot) are copied from this checkout into each ref's worktree, so a ref
#   from before the act existed can still be measured.
# What it does:
#   1. Refuses to start while the 1-minute load average is above PERF_MAX_LOAD (default 2.0), unless
#      --force. A load above that says the numbers mean nothing (the codemap's contaminated run had 7.45).
#   2. Checks each ref out into a temporary worktree of its own, .worktrees/perf-<sha> in the main
#      checkout (removed on exit; --keep leaves them), puts the bench's bot (tests/bot/perf_bot.gd and
#      .tscn, from this checkout) in it, and imports the project there (`godot --headless --import`).
#   3. Runs each --act (default "Perf, six with ragdolls") windowed, vsync off (`--vsync on` leaves it on;
#      see below), RUNS times per
#      ref (default 3), the refs back to back in turn (ref a, ref b, ref a, ref b, ...), so the machine's
#      drift falls on both. The bot is tests/bot/perf_bot.gd: it records the wall time between process
#      frames over the act and prints one PERF-BENCH line (see its header). An act a ref does not
#      have gives no line: the table says so.
#   4. Prints, per act, a table: mean, p95 and worst frame time, the spawn hitch (worst frame within
#      0.5 s of any enemy appearing), and the first spawn's, first hit's and first finisher's hitch
#      (the same window), each as the mean over the runs with its min..max; with two or more refs a
#      delta column (the last ref minus the first). The M4 soft bars (plan Part A A16) are checked on the
#      last ref: p95 <= 16.7 ms, spawn hitch <= 33 ms, first hit and first spawn <= the first ref + 2 ms.
# Vsync: the plan asks for it off. On this Mac an unvsynced window that is not being presented (an
# unattended session, the window behind others) stalls for 1.0 s every few seconds (a Metal drawable
# that is not released), which makes every number meaningless; with vsync on it does not. The report
# counts frames of 0.5 s or more per run ("stalls") and says so when a run has more than two (the one
# or two are the first frames of a process): then run again with `--vsync on` (the frame times follow
# the display's refresh) or with the window in front.
# The logs of every run, the import logs and results.tsv are in --out (default captures/perf_compare/
# <time> of this checkout; never committed). GODOT picks another binary; PERF_MAX_FRAMES caps a run
# (default 60000 frames) so a stuck bot cannot go on for ever.
# It opens a window and needs the Mac to itself: no Blender, no other Godot, nothing else busy.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
MAX_LOAD="${PERF_MAX_LOAD:-2.0}"
MAX_FRAMES="${PERF_MAX_FRAMES:-60000}"
# The soft bars of plan Part A A16 (ms), for the report only.
P95_MAX_MS=16.7
SPAWN_MAX_MS=33
FIRST_DELTA_MS=2
DEFAULT_ACT="Perf, six with ragdolls"
BOT="res://tests/bot/perf_bot.tscn"

RUNS=3
BOT_GIVEN=0
VSYNC=off
FORCE=0
KEEP=0
OUT=""
ACTS=()
REFS=()
while [ $# -gt 0 ]; do
	case "$1" in
		--bot) BOT="$2"; BOT_GIVEN=1; shift 2 ;;
		--act) ACTS+=("$2"); shift 2 ;;
		--runs) RUNS="$2"; shift 2 ;;
		--vsync) VSYNC="$2"; shift 2 ;;
		--force) FORCE=1; shift ;;
		--keep) KEEP=1; shift ;;
		--out) OUT="$2"; shift 2 ;;
		-h|--help) sed -n '2,/^set -e/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
		-*) echo "perf_compare: unknown option $1" >&2; exit 2 ;;
		*) REFS+=("$1"); shift ;;
	esac
done
[ ${#REFS[@]} -ge 1 ] || { echo "usage: tools/perf_compare.sh [--bot <scene>] [--act \"<title text>\"]... [--runs N] [--vsync on|off] [--force] [--keep] [--out DIR] <ref> [<ref>...]" >&2; exit 2; }
[ "$BOT_GIVEN" -eq 0 ] || DEFAULT_ACT="Perf: level walk"
[ ${#ACTS[@]} -ge 1 ] || ACTS=("$DEFAULT_ACT")
case "$BOT" in res://*.tscn) ;; *) echo "perf_compare: --bot wants a res:// scene path" >&2; exit 2 ;; esac
case "$VSYNC" in on|off) ;; *) echo "perf_compare: --vsync wants on or off" >&2; exit 2 ;; esac
case "$RUNS" in ''|*[!0-9]*|0) echo "perf_compare: --runs wants a positive number" >&2; exit 2 ;; esac

load1() {
	if [ -r /proc/loadavg ]; then cut -d' ' -f1 /proc/loadavg; else sysctl -n vm.loadavg | awk '{ print $2 }'; fi
}
above() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a + 0 > b + 0) }'; }

LOAD="$(load1)"
if above "$LOAD" "$MAX_LOAD"; then
	if [ "$FORCE" -eq 1 ]; then
		echo "perf_compare: WARNING: 1-minute load average $LOAD is above $MAX_LOAD; going on because of --force. The numbers are not a baseline." >&2
	else
		echo "perf_compare: refusing to run: 1-minute load average $LOAD is above $MAX_LOAD (quit Blender, other Godot windows and builders, or pass --force)." >&2
		exit 3
	fi
fi

COMMON="$(cd "$ROOT" && cd "$(git rev-parse --git-common-dir)" && pwd)"
MAIN="$(dirname "$COMMON")"
[ -n "$OUT" ] || OUT="$ROOT/captures/perf_compare/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
touch "$OUT/.gdignore"

DIRS=()
SHORTS=()
cleanup() {
	if [ "$KEEP" -eq 0 ]; then
		local dir
		for dir in ${DIRS[@]+"${DIRS[@]}"}; do
			git -C "$MAIN" worktree remove --force "$dir" >/dev/null 2>&1 || rm -rf "$dir"
		done
		git -C "$MAIN" worktree prune
	fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# --- A worktree per ref, the bench's bot in it, imported ---
for ref in "${REFS[@]}"; do
	sha="$(git -C "$ROOT" rev-parse --verify --quiet "$ref^{commit}")" || { echo "perf_compare: no such ref: $ref" >&2; exit 2; }
	short="${sha:0:7}"
	dir="$MAIN/.worktrees/perf-$short"
	n=1
	while [ -e "$dir" ]; do n=$((n + 1)); dir="$MAIN/.worktrees/perf-$short-$n"; done
	echo "perf_compare: $ref = $short, worktree $dir"
	git -C "$MAIN" worktree add --detach "$dir" "$sha" >"$OUT/checkout-$short.log" 2>&1 || { cat "$OUT/checkout-$short.log" >&2; exit 2; }
	DIRS+=("$dir")
	[ "$n" -eq 1 ] && SHORTS+=("$short") || SHORTS+=("$short-$n")
	for f in "$ROOT"/tests/bot/perf_*.gd "$ROOT"/tests/bot/perf_*.tscn; do cp "$f" "$dir/tests/bot/"; done
	if [ "$BOT_GIVEN" -eq 1 ]; then
		# The level bot, its acts and the bot bases are the ref's own; only the bench's files go in.
		mkdir -p "$dir/tests/bot/level_acts"
		cp "$ROOT/tests/bot/level_acts/perf_acts.gd" "$dir/tests/bot/level_acts/"
	fi
	echo "perf_compare: importing $short (the first import of a checkout takes a minute or two)"
	( cd "$dir" && "$GODOT" --headless --import --quit ) >"$OUT/import-${SHORTS[$((${#SHORTS[@]} - 1))]}.log" 2>&1 || true
done

# --- The runs: round by round, ref by ref, act by act ---
: > "$OUT/results.tsv"
act_index=0
for act in "${ACTS[@]}"; do
	act_index=$((act_index + 1))
	for round in $(seq 1 "$RUNS"); do
		for i in "${!REFS[@]}"; do
			short="${SHORTS[$i]}"
			log="$OUT/act${act_index}-${short}-run${round}.log"
			echo "perf_compare: act $act_index \"$act\", run $round of $RUNS, ${REFS[$i]} ($short), load $(load1)"
			status=0
			vsync_args=(--disable-vsync)
			[ "$VSYNC" = on ] && vsync_args=()
			"$GODOT" --path "${DIRS[$i]}" ${vsync_args[@]+"${vsync_args[@]}"} --quit-after "$MAX_FRAMES" "$BOT" -- "--act=$act" "--vsync=$VSYNC" >"$log" 2>&1 || status=$?
			problems="$(grep -c -E 'SCRIPT ERROR|SHADER ERROR|^ERROR' "$log" || true)"
			line="$(grep '^PERF-BENCH ' "$log" | tail -1 | sed 's/^PERF-BENCH //' || true)"
			if [ -n "$line" ]; then
				printf '%s\t%s\t%s\t%s\n' "$act" "${REFS[$i]} ($short)" "$round" "$line" >> "$OUT/results.tsv"
				echo "$line" | python3 -I -c 'import json,sys; r=json.load(sys.stdin); print("    %d frames, mean %.2f, p95 %.2f, worst %.2f, spawn hitch %.1f, first hit %.1f, first finisher %.1f ms, %d stalls" % (r["frames"], r["mean_ms"], r["p95_ms"], r["worst_ms"], r["spawn_hitch_ms"], r["first_hit_ms"], r["first_finisher_ms"], r.get("stalls", 0)))'
			else
				echo "    no PERF-BENCH line (godot exit $status: the act is not in this ref, or the run failed)"
			fi
			[ "$problems" -eq 0 ] || echo "    $problems SCRIPT ERROR / SHADER ERROR / ERROR lines in $log"
		done
	done
done

# --- The report ---
python3 -I - "$OUT/results.tsv" "$RUNS" "$P95_MAX_MS" "$SPAWN_MAX_MS" "$FIRST_DELTA_MS" "$LOAD" "$VSYNC" "${REFS[@]}" <<'PY' | tee "$OUT/report.txt"
import json, sys
path, runs, p95_max, spawn_max, first_delta, load0, vsync = sys.argv[1:8]
refs = sys.argv[8:]
runs = int(runs)
p95_max, spawn_max, first_delta = float(p95_max), float(spawn_max), float(first_delta)
rows = {}
order = []
labels = []
for line in open(path):
    act, ref, rnd, blob = line.rstrip("\n").split("\t", 3)
    if act not in order:
        order.append(act)
    if ref not in labels:
        labels.append(ref)
    rows.setdefault((act, ref), []).append(json.loads(blob))
METRICS = [
    ("frames", "frames", 0), ("mean_ms", "mean ms", 2), ("p95_ms", "p95 ms", 2), ("worst_ms", "worst ms", 1),
    ("spawn_hitch_ms", "spawn hitch ms", 1), ("first_spawn_ms", "first spawn ms", 1),
    ("first_hit_ms", "first hit ms", 1), ("first_finisher_ms", "first finisher ms", 1),
    ("stalls", "stalls (>= 0.5 s)", 0),
]
def mean(values):
    return sum(values) / len(values)
def fmt(value, digits):
    return ("%." + str(digits) + "f") % value
print()
print("perf_compare: windowed, vsync %s, %d run(s) per ref, load average %s when it started" % (vsync, runs, load0))
for act in order:
    print()
    print('== "%s" ==' % act)
    cols = [r for r in labels if (act, r) in rows]
    if not cols:
        print("  no run printed a PERF-BENCH line")
        continue
    head = ["%-18s" % "metric"] + ["%-26s" % r for r in cols]
    if len(cols) > 1:
        head.append("delta (last - first)")
    print("".join(head))
    means = {}
    for key, name, digits in METRICS:
        cells = ["%-18s" % name]
        for r in cols:
            # A hitch of -1 is an event that did not happen in that run: left out of the mean.
            values = [x[key] for x in rows[(act, r)] if x[key] >= 0]
            if not values:
                means[(r, key)] = None
                cells.append("%-26s" % "n/a (no event)")
                continue
            means[(r, key)] = mean(values)
            cell = fmt(mean(values), digits)
            if len(values) > 1:
                cell += " (%s..%s)" % (fmt(min(values), digits), fmt(max(values), digits))
            if len(values) < len(rows[(act, r)]):
                cell += " %d/%d runs" % (len(values), len(rows[(act, r)]))
            cells.append("%-26s" % cell)
        if len(cols) > 1:
            a, b = means[(cols[0], key)], means[(cols[-1], key)]
            cells.append("n/a" if a is None or b is None else ("%+." + str(digits) + "f") % (b - a))
        print("".join(cells))
    for r in cols:
        n = len(rows[(act, r)])
        if n < runs:
            print("  note: %s has %d of %d runs" % (r, n, runs))
    stalled = [r for r in cols if any(x.get("stalls", 0) > 2 for x in rows[(act, r)])]
    if stalled:
        print("  WARNING: %s had runs with more than two frames of 0.5 s or more. Those are stalls of the window (a Metal drawable that is not released, about 1.0 s each), not the game: the numbers above mean nothing. Run again with --vsync on, or with the window in front." % ", ".join(stalled))
    last = cols[-1]
    def bar(value, limit):
        return "n/a" if value is None else ("ok" if value <= limit else "MISS")
    def num(value):
        return "n/a" if value is None else "%.2f" % value
    checks = [
        "p95 <= %.1f: %s (%s)" % (p95_max, bar(means[(last, "p95_ms")], p95_max), num(means[(last, "p95_ms")])),
        "spawn hitch <= %.0f: %s (%s)" % (spawn_max, bar(means[(last, "spawn_hitch_ms")], spawn_max), num(means[(last, "spawn_hitch_ms")])),
    ]
    if len(cols) > 1:
        for key, name in (("first_hit_ms", "first hit"), ("first_spawn_ms", "first spawn")):
            base = means[(cols[0], key)]
            now = means[(last, key)]
            limit = None if base is None else base + first_delta
            checks.append("%s <= first ref + %.0f: %s (%s vs %s)" % (name, first_delta, "n/a" if limit is None else bar(now, limit), num(now), num(base)))
    print("  soft bars (A16) for %s: %s" % (last, "; ".join(checks)))
PY
echo "perf_compare: logs, results.tsv and report.txt in $OUT"
