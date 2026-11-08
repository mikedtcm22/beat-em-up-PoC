#!/usr/bin/env python3
"""Palette transfer: measure a reference frame and one of ours, write a 32-cube LUT that moves our colours
toward theirs (Phase 0 spike, PLAN.md section 4, Plan A part 5).

    ~/.venvs/beat-em-up-video/bin/python -I tools/video/palette_lut.py <reference png> <our png> <out lut png> \
        [--pre-lut <strip png>] [--strength 0.85] [--l-blend 0.5] [--keep-below 5] [--max-hue-shift 14] [--size 32] \
        [--preview <png>] [--report <json>]

The output is a strip of N slices of N x N pixels (RGB8), the format of tools/gen_lut.gd and
game/fx/look_post.gd: slice b = the blue node, x = the red node, y = the green node, node i of n sits at
(i + 0.5) / n (the first and last at 0 and 1). Godot applies it after tonemapping, in sRGB.

The transfer is done in CIE L*a*b* and has two smooth parts, so there is no banding and no posterisation:
  1. A gentle L* curve: the histogram match of our L* onto theirs (quantile to quantile, smoothed, forced
     monotone), blended with the identity by --l-blend, so our values move toward their darkness without
     being crushed.
  2. Reinhard's mean and spread of a* and b*, per L* band AND per temperature cluster (warm: orange-red-yellow,
     cool: cyan-blue-violet; a soft, smooth membership by hue that falls to an even half at zero chroma, so the
     neutral axis never jumps): the mean a*, b* of our warm pixels in an L* band becomes the mean of their warm
     pixels at the matched L*, our cool ones go to their cool ones, and the spreads are scaled the same way (the
     ratio clamped to 0.4-1.8). One mean for both would turn a warm-and-cool frame's orange magenta. Where their
     cluster holds no hue (chroma below --keep-below) or too few pixels, the transfer fades out and our hues
     are kept. The parameters are interpolated between band centres, never stepped.
  3. A cap on how far a colour's hue may turn (--max-hue-shift degrees, applied smoothly as a tanh), because the
     references' warm pixels are redder than a sodium lamp (#ff9a3c, hue about 64) and an uncapped transfer turns
     the key pink. The palette moves toward theirs; the key stays the key.
--pre-lut composes a LUT the frame already went through (the game's own grade, which Environment
.adjustment_color_correction replaces): the output is transfer(pre_lut(node)), so a frame rendered WITH that
grade is the right input for the statistics.

Both frames are cropped like tools/video/style_metrics.py (the bottom 10% off, subtitles) and resized to
640 px wide. The numpy/scipy/Pillow of the video venv only; nothing is installed.
"""
import argparse
import json
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

D65 = np.array([0.95047, 1.0, 1.08883])
M_RGB2XYZ = np.array([[0.4124564, 0.3575761, 0.1804375],
                      [0.2126729, 0.7151522, 0.0721750],
                      [0.0193339, 0.1191920, 0.9503041]])
M_XYZ2RGB = np.linalg.inv(M_RGB2XYZ)
BAND_CENTRES = np.array([2.0, 7.0, 13.0, 21.0, 31.0, 43.0, 57.0, 74.0, 92.0])


def srgb_to_lin(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1.0 / 2.4) - 0.055)


def _f(t):
    d = 6.0 / 29.0
    return np.where(t > d ** 3, np.cbrt(t), t / (3 * d * d) + 4.0 / 29.0)


def _finv(t):
    d = 6.0 / 29.0
    return np.where(t > d, t ** 3, 3 * d * d * (t - 4.0 / 29.0))


def srgb_to_lab(rgb):
    xyz = srgb_to_lin(rgb) @ M_RGB2XYZ.T / D65
    fx, fy, fz = _f(xyz[..., 0]), _f(xyz[..., 1]), _f(xyz[..., 2])
    return np.stack([116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)], axis=-1)


def lab_to_lin(lab):
    fy = (lab[..., 0] + 16) / 116
    fx = fy + lab[..., 1] / 500
    fz = fy - lab[..., 2] / 200
    xyz = np.stack([_finv(fx), _finv(fy), _finv(fz)], axis=-1) * D65
    return xyz @ M_XYZ2RGB.T


def lab_to_srgb_clipped(lab):
    """Lab -> sRGB, pulling chroma in (keeping L* and hue) until the colour is in gamut, so the clip never shifts hue."""
    lab = np.array(lab, dtype=np.float64)
    out = lab_to_lin(lab)
    bad = np.any((out < -1e-4) | (out > 1.0 + 1e-4), axis=-1)
    if bad.any():
        lo = np.zeros(lab.shape[:-1])
        hi = np.ones(lab.shape[:-1])
        for _ in range(14):
            mid = (lo + hi) / 2
            trial = lab.copy()
            trial[..., 1] *= mid
            trial[..., 2] *= mid
            lin = lab_to_lin(trial)
            ok = np.all((lin >= -1e-4) & (lin <= 1.0 + 1e-4), axis=-1)
            lo = np.where(ok, mid, lo)
            hi = np.where(ok, hi, mid)
        scale = np.where(bad, lo, 1.0)
        lab[..., 1] *= scale
        lab[..., 2] *= scale
        out = lab_to_lin(lab)
    return lin_to_srgb(np.clip(out, 0.0, 1.0))


def load_frame(path):
    img = Image.open(path).convert("RGB")
    w, h = img.size
    img = img.crop((0, 0, w, int(h * 0.9)))
    img = img.resize((640, int(round(640 * img.size[1] / img.size[0]))), Image.LANCZOS)
    return np.asarray(img, dtype=np.float64) / 255.0


WARM_HUE_DEG = 55.0
CHROMA_FULL = 8.0


def warm_membership(a, b):
    """0..1, how warm a colour is: a smooth function of hue (cos of the angle from orange), pulled to an even 0.5
    as chroma falls to zero so the neutral axis, where hue is undefined, belongs to both clusters equally."""
    hue = np.arctan2(b, a)
    u = np.cos(hue - np.deg2rad(WARM_HUE_DEG))
    t = np.clip((u + 0.35) / 0.8, 0.0, 1.0)
    warm = t * t * (3.0 - 2.0 * t)
    c = np.clip(np.hypot(a, b) / CHROMA_FULL, 0.0, 1.0)
    c = c * c * (3.0 - 2.0 * c)
    return 0.5 + (warm - 0.5) * c


def band_stats(lab, centres=BAND_CENTRES):
    """Soft-membership (triangular in L*) mean and std of a*, b*, the population share and the mean chroma, per L*
    band and temperature cluster. Shapes: mu (bands, 2 clusters, 2), sd the same, pop and chroma (bands, 2);
    cluster 0 is warm, 1 cool."""
    L = lab[..., 0].ravel()
    a = lab[..., 1].ravel()
    b = lab[..., 2].ravel()
    warm = warm_membership(a, b)
    members = (warm, 1.0 - warm)
    n = len(centres)
    mu = np.zeros((n, 2, 2))
    sd = np.zeros((n, 2, 2))
    pop = np.zeros((n, 2))
    chroma = np.zeros((n, 2))
    for i, c in enumerate(centres):
        left = centres[i - 1] if i > 0 else c - (centres[1] - c)
        right = centres[i + 1] if i < n - 1 else c + (c - centres[i - 1])
        wl = np.clip(np.where(L < c, (L - left) / (c - left), (right - L) / (right - c)), 0.0, 1.0)
        for k in range(2):
            w = wl * members[k]
            s = w.sum()
            pop[i, k] = s / L.size
            if s < 1e-6:
                continue
            ma, mb = (w * a).sum() / s, (w * b).sum() / s
            mu[i, k] = (ma, mb)
            sd[i, k] = (np.sqrt((w * (a - ma) ** 2).sum() / s), np.sqrt((w * (b - mb) ** 2).sum() / s))
            chroma[i, k] = (w * np.hypot(a, b)).sum() / s
    return mu, sd, pop, chroma


def smooth_curve(x):
    return ndimage.gaussian_filter1d(x, 1.2, mode="nearest")


def l_curve(ours_L, ref_L, blend):
    """A monotone L* -> L* map: ours' quantiles onto theirs', smoothed, blended with the identity."""
    q = np.linspace(0, 100, 201)
    qo = np.percentile(ours_L, q)
    qr = np.percentile(ref_L, q)
    # Anchor the ends so black stays black and white stays white, then smooth and force monotone.
    xo = np.concatenate([[0.0], qo, [100.0]])
    yr = np.concatenate([[0.0], qr, [100.0]])
    order = np.argsort(xo)
    xo, yr = xo[order], yr[order]
    xs = np.linspace(0, 100, 401)
    ys = np.interp(xs, xo, yr)
    ys = smooth_curve(ys)
    ys = np.maximum.accumulate(ys)
    # The pull fades out toward white (smoothstep 55 -> 100), so the top of the curve rejoins the identity gently:
    # a hard rejoin is a cliff in the highlights, and the bloom's halo would posterise on it.
    t = np.clip((xs - 55.0) / 45.0, 0.0, 1.0)
    fade = 1.0 - t * t * (3.0 - 2.0 * t)
    ys = xs + (ys - xs) * blend * fade
    ys = np.maximum.accumulate(ys)
    return xs, ys


class Transfer:
    def __init__(self, ref_rgb, our_rgb, strength, l_blend, keep_below, max_hue_shift=14.0):
        ref_lab = srgb_to_lab(ref_rgb)
        our_lab = srgb_to_lab(our_rgb)
        self.strength = strength
        self.xs, self.ys = l_curve(our_lab[..., 0].ravel(), ref_lab[..., 0].ravel(), l_blend)
        self.o_mu, self.o_sd, self.o_pop, self.o_chroma = band_stats(our_lab)
        self.r_mu, self.r_sd, self.r_pop, self.r_chroma = band_stats(ref_lab)
        self.keep_below = keep_below
        self.max_hue_shift = np.deg2rad(max_hue_shift)
        self.centres = BAND_CENTRES

    def _interp(self, table, L):
        """Interpolate a per-band table (bands, ...) at L*, smoothing across bands; the trailing axes stay."""
        flat = table.reshape(table.shape[0], -1)
        cols = [np.interp(L, self.centres, smooth_curve(flat[:, k])) for k in range(flat.shape[1])]
        return np.stack(cols, axis=-1).reshape(L.shape + table.shape[1:])

    def l_map(self, L):
        return np.interp(L, self.xs, self.ys)

    def weight(self, L, Lp):
        """How far the a*, b* transfer applies, per cluster (..., 2): fades where the reference cluster holds no hue
        or too few pixels (and where ours does not)."""
        pop = np.minimum(self._interp(self.o_pop, L), self._interp(self.r_pop, Lp))
        w_pop = np.clip(pop / 0.003, 0.0, 1.0)
        c_ref = self._interp(self.r_chroma, Lp)
        w_hue = np.clip((c_ref - 1.0) / max(self.keep_below - 1.0, 0.5), 0.0, 1.0)
        return self.strength * w_pop * (0.35 + 0.65 * w_hue)

    def apply_lab(self, lab):
        L = lab[..., 0]
        Lp = self.l_map(L)
        o_mu = self._interp(self.o_mu, L)      # (..., 2 clusters, 2)
        o_sd = self._interp(self.o_sd, L)
        r_mu = self._interp(self.r_mu, Lp)
        r_sd = self._interp(self.r_sd, Lp)
        ratio = np.clip(r_sd / np.maximum(o_sd, 1e-3), 0.4, 1.8)
        ab = lab[..., None, 1:3]               # (..., 1, 2)
        target = (ab - o_mu) * ratio + r_mu    # (..., 2 clusters, 2)
        w = self.weight(L, Lp)[..., None]      # (..., 2, 1)
        shifted = ab + (target - ab) * w       # per cluster
        warm = warm_membership(lab[..., 1], lab[..., 2])[..., None]
        out = np.empty_like(lab)
        out[..., 0] = Lp
        mixed = warm * shifted[..., 0, :] + (1.0 - warm) * shifted[..., 1, :]
        out[..., 1:3] = self._cap_hue(lab[..., 1:3], mixed)
        return out

    def _cap_hue(self, ab_in, ab_out):
        """Limit the hue turn from ab_in to ab_out to a smooth +-max_hue_shift (tanh), keeping the new chroma."""
        h_in = np.arctan2(ab_in[..., 1], ab_in[..., 0])
        h_out = np.arctan2(ab_out[..., 1], ab_out[..., 0])
        d = (h_out - h_in + np.pi) % (2 * np.pi) - np.pi
        m = max(self.max_hue_shift, 1e-3)
        d_cap = m * np.tanh(d / m)
        # Pixels with almost no chroma have no hue to keep: fade the cap out below chroma 3.
        c = np.hypot(ab_in[..., 0], ab_in[..., 1])
        k = np.clip(c / 3.0, 0.0, 1.0)
        d_use = d + (d_cap - d) * k
        h = h_in + d_use
        c_out = np.hypot(ab_out[..., 0], ab_out[..., 1])
        return np.stack([c_out * np.cos(h), c_out * np.sin(h)], axis=-1)

    def apply_rgb(self, rgb):
        return lab_to_srgb_clipped(self.apply_lab(srgb_to_lab(rgb)))


def node_value(i, n):
    if i <= 0:
        return 0.0
    if i >= n - 1:
        return 1.0
    return (i + 0.5) / n


def identity_cube(n):
    v = np.array([node_value(i, n) for i in range(n)])
    # cube[b, g, r] = (r, g, b) node values
    b, g, r = np.meshgrid(v, v, v, indexing="ij")
    return np.stack([r, g, b], axis=-1)


def read_strip(path):
    img = np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255.0
    n = img.shape[0]
    if img.shape[1] != n * n:
        sys.exit("%s is not a strip of N slices of N x N pixels" % path)
    cube = np.stack([img[:, b * n:(b + 1) * n, :] for b in range(n)], axis=0)  # [b, g, r, 3]
    return cube


def sample_cube(cube, rgb):
    """Trilinear lookup of colours rgb (..., 3 in 0-1) in a cube[b, g, r], the way the GPU samples a node texture."""
    n = cube.shape[0]
    # A colour value c sits at texel coordinate c * n - 0.5 (nodes at (i + 0.5) / n), clamped to the edge.
    coord = np.clip(rgb * n - 0.5, 0.0, n - 1.0)
    flat = coord.reshape(-1, 3)
    out = np.empty((flat.shape[0], 3))
    for k in range(3):
        out[:, k] = ndimage.map_coordinates(cube[..., k], [flat[:, 2], flat[:, 1], flat[:, 0]], order=1, mode="nearest")
    return out.reshape(rgb.shape)


def write_strip(cube, path):
    n = cube.shape[0]
    strip = np.zeros((n, n * n, 3))
    for b in range(n):
        strip[:, b * n:(b + 1) * n, :] = cube[b]
    Image.fromarray(np.clip(np.round(strip * 255.0), 0, 255).astype(np.uint8)).save(path)


def banding_report(cube):
    """Push smooth ramps through the (8-bit quantised) cube and report the worst step: no posterisation means every
    ramp stays monotone in L* with small, even steps."""
    n = cube.shape[0]
    q = np.round(cube * 255.0) / 255.0
    ramp = np.linspace(0, 1, 1024)
    report = {}
    for name, col in (("grey", np.stack([ramp] * 3, -1)),
                      ("navy", np.stack([ramp * 0.35, ramp * 0.45, ramp * 0.9], -1)),
                      ("warm", np.stack([ramp, ramp * 0.6, ramp * 0.25], -1))):
        out = sample_cube(q, col)
        L = srgb_to_lab(out)[..., 0]
        steps = np.diff(L)
        report[name] = {"L_monotone": bool(np.all(steps >= -0.15)), "max_L_step": float(steps.max()), "min_L_step": float(steps.min())}
    return report


def stats(rgb):
    lab = srgb_to_lab(rgb)
    L = lab[..., 0]
    return {"L_mean": float(L.mean()), "L_p50": float(np.median(L)), "L_p95": float(np.percentile(L, 95)),
            "dark_share": float((L < 20).mean()), "chroma_mean": float(np.hypot(lab[..., 1], lab[..., 2]).mean())}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("reference")
    ap.add_argument("ours")
    ap.add_argument("out")
    ap.add_argument("--pre-lut", default=None, help="a strip the frame already went through (composed first)")
    ap.add_argument("--strength", type=float, default=0.85)
    ap.add_argument("--l-blend", type=float, default=0.5)
    ap.add_argument("--keep-below", type=float, default=5.0)
    ap.add_argument("--max-hue-shift", type=float, default=14.0, help="degrees a hue may turn (smooth cap)")
    ap.add_argument("--size", type=int, default=32)
    ap.add_argument("--preview", default=None, help="write our frame through the LUT here (full frame, no crop)")
    ap.add_argument("--report", default=None)
    args = ap.parse_args()

    ref = load_frame(args.reference)
    ours = load_frame(args.ours)
    tf = Transfer(ref, ours, args.strength, args.l_blend, args.keep_below, args.max_hue_shift)

    n = args.size
    cube = identity_cube(n)
    if args.pre_lut:
        cube = sample_cube(read_strip(args.pre_lut), cube)
    out_cube = tf.apply_rgb(cube)
    write_strip(out_cube, args.out)

    # Self-check: our frame through the LUT as the GPU would (the 8-bit quantised cube, trilinear).
    q = np.round(out_cube * 255.0) / 255.0
    transferred = sample_cube(q, ours)
    report = {
        "reference": stats(ref), "ours": stats(ours), "ours_after": stats(transferred),
        "banding": banding_report(out_cube),
        "l_curve": {"at": [float(x) for x in (5, 10, 20, 30, 50, 70)], "to": [float(np.interp(x, tf.xs, tf.ys)) for x in (5, 10, 20, 30, 50, 70)]},
        "band_centres": BAND_CENTRES.tolist(),
        "our_band_chroma_warm_cool": tf.o_chroma.round(2).tolist(), "ref_band_chroma_warm_cool": tf.r_chroma.round(2).tolist(),
        "our_band_pop_warm_cool": tf.o_pop.round(4).tolist(), "ref_band_pop_warm_cool": tf.r_pop.round(4).tolist(),
    }
    if args.preview:
        full = np.asarray(Image.open(args.ours).convert("RGB"), dtype=np.float64) / 255.0
        small = full if full.shape[1] <= 1280 else np.asarray(Image.open(args.ours).convert("RGB").resize((1280, int(1280 * full.shape[0] / full.shape[1])), Image.LANCZOS), dtype=np.float64) / 255.0
        out_img = sample_cube(q, small)
        Image.fromarray(np.clip(np.round(out_img * 255), 0, 255).astype(np.uint8)).save(args.preview)
    if args.report:
        with open(args.report, "w") as f:
            json.dump(report, f, indent=1)
    print(json.dumps({k: report[k] for k in ("reference", "ours", "ours_after", "l_curve", "banding")}, indent=1))


if __name__ == "__main__":
    main()
