#!/usr/bin/env python3
"""Check a crowd-bot log against the Milestone 3 rules (M3-plan A7.1 and Part B).

Usage: tools/check_m3_log.py [--cap N] [--strict] <bot.log> [<bot.log> ...]

Reads the log `tools/capture_bot.sh` writes beside a recording (or the output of a headless
`godot --path . res://tests/bot/crowd_bot.tscn -- --act=...` run) and checks:

  1. every `WARN-CHECK` line says `ok` (the warning oracle's verdict on each wind-up: the HUD's
     corners against the rule of SPEC section 8);
  2. every wind-up from beyond the view's 55 degrees and within range was warned within 1 frame:
     each `WARN-CHECK` line whose corner is left, right or both has `lat=0` or `lat=1`, and the
     HUD's own `W+` line for that side (both sides for "both") is in the log at the wind-up's
     frame or the next; a wind-up the rule leaves dark (`none`) has no `W+` line at its frame;
  3. token holders never exceed the attacker cap: from the `TOK+` / `TOK-` lines, per act
     (an act's header `=== <title>` forgets the holders: the room is emptied between acts);
  4. no hard metric failed (`FAIL (hard)` in a READABILITY block), and the log has no
     `SCRIPT ERROR` or `ERROR:` line (a parse error still exits 0).

The cap is `attacker_cap` from tuning/default.json beside this script's repo unless `--cap` says
otherwise. The bot prints its event lines twice (live, then the whole log again at the end), so a
repeated line is read once. A log with no `WARN-CHECK` line has nothing to say about the warning:
that is a note, and a failure with `--strict`.

Exits 0 when every check passes, 1 when any fails, 2 on a usage error.
"""

import argparse
import json
import os
import re
import sys
from collections import defaultdict

# `WARN-CHECK ok|FAIL <act> <corner> f<frame> [lat=<n|->] [end=<n|->] [why=<reason>]`. The act's
# title has spaces and commas in it, so the corner and the frame are taken from the right.
WARN_CHECK = re.compile(
    r"^WARN-CHECK (?P<verdict>ok|FAIL) (?P<act>.*?) (?P<corner>left|right|both|none) f(?P<frame>\d+)"
    r"(?: lat=(?P<lat>\S+))?(?: end=(?P<end>\S+))?(?: why=(?P<why>\S+))?\s*$"
)
WIDGET_ON = re.compile(r"^W\+ f(?P<frame>\d+) side=(?P<side>left|right)\b")
WINDUP_START = re.compile(r"^WU\+ f(?P<frame>\d+) (?P<who>\S+) (?P<move>\S+)")
TOKEN = re.compile(r"^TOK(?P<sign>[+-]) f(?P<frame>\d+) (?P<who>\S+)")
ACT_HEADER = re.compile(r"^=== (?P<act>.*?)\s+\(f(?P<frame>\d+)\)\s*$")
HARD_FAIL = re.compile(r"^\s+(R\d+)\b.*FAIL \(hard\)")
ERROR_LINE = re.compile(r"SCRIPT ERROR|^ERROR:|^\s*ERROR:")

SIDES_OF = {"left": ("left",), "right": ("right",), "both": ("left", "right")}


def default_cap():
    """attacker_cap from tuning/default.json in the repo this script lives in, else 3."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tuning", "default.json")
    try:
        with open(path, encoding="utf-8") as handle:
            return int(json.load(handle)["tuning"]["attacker_cap"])
    except (OSError, ValueError, KeyError, TypeError):
        return 3


def read_lines(path):
    """The log's lines with the bot's second printing of its event lines dropped."""
    seen = set()
    out = []
    with open(path, encoding="utf-8", errors="replace") as handle:
        for raw in handle:
            line = raw.rstrip("\n")
            # Only the bot's own event lines are printed twice; a READABILITY block, the oracle's
            # and the engine's lines are not, and a blank or repeated engine line must stay.
            if WIDGET_ON.match(line) or line.startswith(("W- ", "WU+ ", "WU- ", "TOK", "AI f")):
                if line in seen:
                    continue
                seen.add(line)
            out.append(line)
    return out


def check_log(path, cap):
    """Run every check on one log. Returns (problems, notes, summary dict)."""
    lines = read_lines(path)
    problems = []
    notes = []
    act = ""
    holders = set()
    most_holders = 0
    most_at = ""
    checks = []
    widget_on = defaultdict(set)  # frame -> sides lit by a W+ line at that frame
    windups = []
    hard_fails = []
    errors = []

    for number, line in enumerate(lines, 1):
        header = ACT_HEADER.match(line)
        if header:
            act = header.group("act")
            holders = set()
            continue
        match = WARN_CHECK.match(line)
        if match:
            checks.append((number, match))
            continue
        match = WIDGET_ON.match(line)
        if match:
            widget_on[int(match.group("frame"))].add(match.group("side"))
            continue
        match = WINDUP_START.match(line)
        if match:
            windups.append((number, int(match.group("frame")), match.group("who"), match.group("move")))
            continue
        match = TOKEN.match(line)
        if match:
            key = match.group("who")
            if match.group("sign") == "+":
                holders.add(key)
            else:
                holders.discard(key)
            if len(holders) > most_holders:
                most_holders = len(holders)
                most_at = "%s, f%s, holders %s" % (act or "?", match.group("frame"), ", ".join(sorted(holders)))
            if cap > 0 and len(holders) > cap:
                problems.append(
                    "line %d: %d token holders (%s) over the cap of %d, in %s at f%s"
                    % (number, len(holders), ", ".join(sorted(holders)), cap, act or "?", match.group("frame")))
            continue
        match = HARD_FAIL.match(line)
        if match:
            hard_fails.append("line %d: %s" % (number, line.strip()))
            continue
        if ERROR_LINE.search(line):
            errors.append("line %d: %s" % (number, line.strip()))

    # 1. and 2. The warning.
    warned = 0
    for number, match in checks:
        frame = int(match.group("frame"))
        corner = match.group("corner")
        where = "line %d (%s, f%d, %s)" % (number, match.group("act"), frame, corner)
        if match.group("verdict") != "ok":
            problems.append("%s: WARN-CHECK FAIL%s" % (where, " why=" + match.group("why") if match.group("why") else ""))
        lit = widget_on.get(frame, set()) | widget_on.get(frame + 1, set())
        if corner == "none":
            if lit:
                problems.append("%s: the rule leaves the corners dark but W+ lit %s" % (where, "+".join(sorted(lit))))
            continue
        warned += 1
        latency = match.group("lat")
        if latency in (None, "-"):
            if latency == "-":
                problems.append("%s: the corner never lit (lat=-)" % where)
        elif int(latency) > 1:
            problems.append("%s: lit %s frames after the wind-up (over 1)" % (where, latency))
        missing = [side for side in SIDES_OF[corner] if side not in lit]
        if missing:
            problems.append("%s: no W+ line for %s within 1 frame of the wind-up" % (where, "+".join(missing)))
        end = match.group("end")
        if end not in (None, "-") and int(end) > 1:
            problems.append("%s: dropped %s frames after the rule ended it (over 1)" % (where, end))

    # A wind-up the oracle never judged (not a failure by itself: the oracle skips one that lived
    # a single tick, and an act's last wind-up can be cut by the act's end).
    judged = {int(match.group("frame")) for _, match in checks}
    unjudged = [w for w in windups if w[1] not in judged]
    if unjudged:
        notes.append("%d of %d wind-ups have no WARN-CHECK line (the first: %s f%d)"
                     % (len(unjudged), len(windups), unjudged[0][2], unjudged[0][1]))

    for text in hard_fails:
        problems.append("a hard metric failed, " + text)
    for text in errors:
        problems.append("engine error, " + text)

    summary = {
        "lines": len(lines),
        "warn_checks": len(checks),
        "warned": warned,
        "windups": len(windups),
        "most_holders": most_holders,
        "most_holders_at": most_at,
        "cap": cap,
    }
    return problems, notes, summary


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("logs", nargs="+", help="a crowd-bot log (bot.log)")
    parser.add_argument("--cap", type=int, default=None, help="the attacker cap (default: attacker_cap of tuning/default.json)")
    parser.add_argument("--strict", action="store_true", help="a log with no WARN-CHECK line fails")
    args = parser.parse_args(argv)
    cap = args.cap if args.cap is not None else default_cap()
    failed = False
    for path in args.logs:
        try:
            problems, notes, summary = check_log(path, cap)
        except OSError as error:
            print("check_m3_log: cannot read %s: %s" % (path, error), file=sys.stderr)
            return 2
        if summary["warn_checks"] == 0:
            notes.append("no WARN-CHECK line in this log: nothing to say about the warning")
            if args.strict:
                problems.append("no WARN-CHECK line (--strict)")
        status = "FAIL" if problems else "ok"
        print("%s %s: %d WARN-CHECK (%d warned), %d wind-ups, token holders at most %d of %d, %d lines"
              % (status, path, summary["warn_checks"], summary["warned"], summary["windups"],
                 summary["most_holders"], summary["cap"], summary["lines"]))
        if summary["most_holders_at"]:
            print("  most holders: %s" % summary["most_holders_at"])
        for note in notes:
            print("  note: " + note)
        for problem in problems:
            print("  FAIL: " + problem)
        failed = failed or bool(problems)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
