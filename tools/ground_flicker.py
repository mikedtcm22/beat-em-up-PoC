#!/usr/bin/env python3
"""Measure the street floor's temporal stability in a "Look: ground drift" recording (M6 FB-GROUND).

Usage: tools/ground_flicker.py <bot.avi> [<bot.log>] [--roi x,y,w,h]

The region of interest (default 480,560 620x320 in the 1600x900 frame: floor only, clear of the HUD) is cut to
grey and two numbers are taken per frame with ffmpeg's own filters (no image library needed):
  d1  the mean |I(t) - I(t-1)|: on the `still` phase the view does not move, so anything above 0 is the picture
      changing by itself (a shadow or an edge line that flickers, two faces fighting for depth);
  d2  the mean |(I(t) - I(t-1)) - (I(t-1) - I(t-2))|, the second temporal difference: a texture sliding at a steady
      speed changes little from one frame's step to the next, a texture that aliases (a thin line or a grain that
      crosses a pixel centre) jumps. It is the flicker a player sees on a slow drift.
It prints the mean of each per phase of the log's `GROUND <variant> <spot> <phase> f<first> f<last>` lines
(the three first frames of a phase are dropped: they hold the previous phase's last step), and the ratio d2 / d1
(0 for a smooth slide; near 1 or more for noise).
"""
import re
import subprocess
import sys
import tempfile
import os


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    roi = "480,560,620,320"
    if "--roi" in sys.argv:
        roi = sys.argv[sys.argv.index("--roi") + 1]
        args = [a for a in args if a != roi]
    avi = args[0]
    log = args[1] if len(args) > 1 else os.path.join(os.path.dirname(avi), "bot.log")
    x, y, w, h = [int(v) for v in roi.split(",")]
    stats = {}
    for name, chain in (
        ("d1", "tblend=all_mode=difference"),
        ("d2", "tblend=all_expr='clip(A-B+128,0,255)',tblend=all_mode=difference"),
    ):
        with tempfile.NamedTemporaryFile(suffix=".txt", delete=False) as handle:
            out = handle.name
        graph = "crop=%d:%d:%d:%d,format=gray,%s,signalstats,metadata=mode=print:key=lavfi.signalstats.YAVG:file=%s" % (w, h, x, y, chain, out)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", avi, "-vf", graph, "-f", "null", "-"], check=True)
        values = []
        for line in open(out):
            m = re.search(r"YAVG=([0-9.]+)", line)
            if m:
                values.append(float(m.group(1)))
        os.unlink(out)
        stats[name] = values
    phases = []
    seen = set()
    for line in open(log):
        m = re.match(r"GROUND (\S+) (\S+) (\S+) f(\d+) f(\d+)", line)
        if m and m.group(0) not in seen:
            seen.add(m.group(0))
            phases.append((m.group(1), m.group(2), m.group(3), int(m.group(4)), int(m.group(5))))
    print("%-12s %-3s %-6s %9s %9s %7s" % ("variant", "at", "phase", "d1", "d2", "d2/d1"))
    for variant, spot, phase, first, last in phases:
        lo, hi = first + 3, last
        d1 = stats["d1"][lo:hi]
        d2 = stats["d2"][lo:hi]
        if not d1:
            continue
        m1 = sum(d1) / len(d1)
        m2 = sum(d2) / len(d2)
        print("%-12s %-3s %-6s %9.4f %9.4f %7.2f" % (variant, spot, phase, m1, m2, m2 / m1 if m1 > 1e-6 else 0.0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
