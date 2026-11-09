"""R4-INK: does the brush pass boil? Compares two renders of one moving shot (the brush on, the brush off) frame by frame.

For 12 consecutive frames it measures, on WORLD pixels only (the shot's character mask is 0), the mean absolute SECOND temporal difference of the
luminance, |Y(t+1) - 2 Y(t) + Y(t-1)|: smooth camera motion keeps it small and a flickering or swimming texture raises it. It prints the mean for each
render and their ratio (on / off); a brush that does not boil keeps the ratio near 1 (the posterize's band edges move with the world, so a little more
is expected where a band crosses a surface).

Run: ~/.venvs/beat-em-up-video/bin/python -I tools/video/r4_motion_check.py <on.mkv> <on_mask.mkv> <off.mkv> <off_mask.mkv> [first_frame]
(numpy only; ffmpeg decodes the frames at 1280x720 to keep the memory down.)
"""
import subprocess
import sys

import numpy as np

W, H = 1280, 720
COUNT = 12


def frames(path, first, gray):
    pix = "gray" if gray else "gray"
    cmd = ["ffmpeg", "-loglevel", "error", "-i", path, "-vf", "select='between(n,%d,%d)',scale=%d:%d" % (first, first + COUNT - 1, W, H),
           "-fps_mode", "passthrough", "-f", "rawvideo", "-pix_fmt", pix, "-"]
    raw = subprocess.run(cmd, check=True, stdout=subprocess.PIPE).stdout
    arr = np.frombuffer(raw, dtype=np.uint8).reshape(-1, H, W)
    return arr.astype(np.float64) / 255.0


def second_diff(video, mask):
    y = frames(video, FIRST, True)
    m = frames(mask, FIRST, True)
    world = (m[1:-1] < 0.1) & (m[:-2] < 0.1) & (m[2:] < 0.1)
    d2 = np.abs(y[2:] - 2.0 * y[1:-1] + y[:-2])
    return float(d2[world].mean()), d2.shape[0]


FIRST = 20

if __name__ == "__main__":
    if len(sys.argv) < 5:
        print(__doc__)
        sys.exit(2)
    if len(sys.argv) > 5:
        FIRST = int(sys.argv[5])
    on, n = second_diff(sys.argv[1], sys.argv[2])
    off, _ = second_diff(sys.argv[3], sys.argv[4])
    print("frames %d..%d: second difference on world pixels: brush on %.5f, brush off %.5f, ratio %.2f" % (FIRST, FIRST + COUNT - 1, on, off, on / max(off, 1e-9)))
