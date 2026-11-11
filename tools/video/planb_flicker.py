"""Temporal flicker of two clips of the same shot: per frame, the mean |2 f_i - f_(i-1) - f_(i+1)| (the second difference: smooth motion
gives little, frame-to-frame boiling gives a lot) and the mean |f_i - f_(i-1)|, on 480x270 grey frames (0-255).
Usage: python -I flicker.py <ours.mp4> <restyle.mp4> [segments like 0-30,60-81]"""
import sys
import cv2
import numpy as np

def frames(p):
	cap = cv2.VideoCapture(p)
	out = []
	while True:
		ok, f = cap.read()
		if not ok:
			break
		out.append(cv2.resize(cv2.cvtColor(f, cv2.COLOR_BGR2GRAY), (480, 270), interpolation=cv2.INTER_AREA).astype(np.float32))
	return out

a, b = frames(sys.argv[1]), frames(sys.argv[2])
n = min(len(a), len(b))
def second(fs, i):
	return float(np.mean(np.abs(2 * fs[i] - fs[i - 1] - fs[i + 1])))
def first(fs, i):
	return float(np.mean(np.abs(fs[i] - fs[i - 1])))
segs = [(1, n - 2)]
if len(sys.argv) > 3:
	segs += [tuple(int(x) for x in s.split("-")) for s in sys.argv[3].split(",")]
print(f"frames {len(a)} / {len(b)}")
for lo, hi in segs:
	lo = max(1, lo); hi = min(n - 2, hi)
	sa = [second(a, i) for i in range(lo, hi + 1)]; sb = [second(b, i) for i in range(lo, hi + 1)]
	fa = [first(a, i) for i in range(lo, hi + 1)]; fb = [first(b, i) for i in range(lo, hi + 1)]
	print(f"frames {lo}-{hi}: second diff ours median {np.median(sa):.2f} p90 {np.percentile(sa, 90):.2f} | restyle median {np.median(sb):.2f} p90 {np.percentile(sb, 90):.2f}; "
		f"first diff ours {np.median(fa):.2f} | restyle {np.median(fb):.2f}")
worst = sorted(range(1, n - 1), key=lambda i: second(b, i) - second(a, i), reverse=True)[:6]
print("restyle's worst frames (second diff minus ours):", ", ".join(f"{i} (+{second(b, i) - second(a, i):.1f})" for i in worst))
