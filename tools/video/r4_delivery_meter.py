"""R4-INK: how sharp is a frame? Measures the delivery's two numbers on 2560x1440 frames, to match ours to the references'.

  radial_hf   the share of the luminance's spectral energy above a quarter of Nyquist (0.125 cycles/pixel), over the energy above the
              lowest bands (0.02 cycles/pixel and up): a sharp render has more of it, an upscaled stream less;
  slope       the log-log slope of the radially averaged power spectrum between 0.125 and 0.4 cycles/pixel (steeper = softer);
  edge_1090   the median 10-90% width, in pixels, of the strongest horizontal edges (the rise of a dark line or a plane's edge).

Run: ~/.venvs/beat-em-up-video/bin/python -I tools/video/r4_delivery_meter.py <png> [<png> ...]
(PIL and numpy only; the frames are untrusted data, passed as paths.)
"""
import sys

import numpy as np
from PIL import Image


def luminance(path):
    img = np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255.0
    lin = np.where(img <= 0.04045, img / 12.92, ((img + 0.055) / 1.055) ** 2.4)
    y = lin @ np.array([0.2126, 0.7152, 0.0722])
    # Perceptual (gamma) luminance: the spectrum of what the eye sees, so dark frames are not all noise floor.
    return y ** (1.0 / 2.2)


def spectrum(y):
    h, w = y.shape
    win = np.outer(np.hanning(h), np.hanning(w))
    f = np.fft.fftshift(np.fft.fft2((y - y.mean()) * win))
    p = np.abs(f) ** 2
    fy = np.fft.fftshift(np.fft.fftfreq(h))[:, None]
    fx = np.fft.fftshift(np.fft.fftfreq(w))[None, :]
    r = np.sqrt(fx ** 2 + fy ** 2)
    bins = np.linspace(0.0, 0.5, 101)
    idx = np.digitize(r.ravel(), bins) - 1
    sums = np.bincount(idx, weights=p.ravel(), minlength=len(bins))[: len(bins) - 1]
    counts = np.bincount(idx, minlength=len(bins))[: len(bins) - 1]
    return bins[:-1] + 0.0025, sums / np.maximum(counts, 1)


def radial_metrics(y):
    f, p = spectrum(y)
    total_hf = p[f >= 0.02].sum()
    hf = p[f >= 0.125].sum()
    sel = (f >= 0.125) & (f <= 0.4) & (p > 0)
    slope = np.polyfit(np.log10(f[sel]), np.log10(p[sel]), 1)[0]
    return hf / total_hf, slope


def edge_width(y, count=1500):
    gx = np.abs(np.diff(y, axis=1))
    h, w = gx.shape
    # Local maxima of the horizontal gradient, strongest first, away from the border.
    peaks = (gx[:, 1:-1] > gx[:, :-2]) & (gx[:, 1:-1] >= gx[:, 2:])
    ys, xs = np.nonzero(peaks)
    xs = xs + 1
    ok = (xs > 10) & (xs < w - 11)
    ys, xs = ys[ok], xs[ok]
    strength = gx[ys, xs]
    order = np.argsort(-strength)[: count * 4]
    widths = []
    for k in order:
        yy, xx = ys[k], xs[k]
        prof = y[yy, xx - 8: xx + 10]
        lo, hi = prof[:3].mean(), prof[-3:].mean()
        amp = hi - lo
        if abs(amp) < 0.06:
            continue
        t = (prof - lo) / amp
        if (t < -0.15).any() or (t > 1.15).any():
            continue
        up = np.nonzero(t >= 0.1)[0]
        top = np.nonzero(t >= 0.9)[0]
        if len(up) == 0 or len(top) == 0:
            continue
        # linear interpolation of the 10% and 90% crossings
        def cross(level):
            i = np.nonzero(t >= level)[0][0]
            if i == 0:
                return 0.0
            return i - 1 + (level - t[i - 1]) / max(t[i] - t[i - 1], 1e-6)
        widths.append(cross(0.9) - cross(0.1))
        if len(widths) >= count:
            break
    return float(np.median(widths)) if widths else float("nan"), len(widths)


def main():
    print("%-44s %9s %7s %10s" % ("frame", "radial_hf", "slope", "edge_1090"))
    for path in sys.argv[1:]:
        y = luminance(path)
        hf, slope = radial_metrics(y)
        ew, n = edge_width(y)
        print("%-44s %9.5f %7.2f %7.2f px (n=%d)" % (path.split("/")[-1][:44], hf, slope, ew, n))


if __name__ == "__main__":
    main()
