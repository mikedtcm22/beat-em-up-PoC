# The style meter's targets: the reference frames, measured

Phase 0, step 5 of [PLAN.md](PLAN.md) §6. These are the numbers of the two reference videos (PLAN.md §1-2), measured by code so our frames can be scored against the same numbers. The images themselves are never committed: they live in `captures/video/ref/` (git-ignored), and the times below say which frames were used.

## How it's measured
- **The code:** `tools/video/style_metrics.py` (the numbers) and `tools/video/measure_refs.py` (frames and sets in, JSON out). Run them with the video venv:
  `~/.venvs/beat-em-up-video/bin/python -I tools/video/measure_refs.py --out <json> --frames <png> ... --set <name>=<folder>`.
- **The frame.** Every frame is resized to 1280 px wide, and its bottom 10% is cropped off, because the subtitles and the watermarks live there. So the numbers compare across 2560×1440, 1280×720 and our captures.
- **Colour** is CIE L\*a\*b\*: L\* is the value (0 black, 100 white), chroma C\* = √(a\*² + b\*²), and hue h = atan2(b\*, a\*) in degrees. That's about 40 red, 60-90 orange to yellow, 135-180 green, 200-260 cyan to blue, and 290-340 violet to magenta.
- **What each number means:**
  - **Value:** the mean, spread and percentiles of L\*, and the share of the frame in four bands: dark (<20), shadow (20-40), mid (40-65) and light (>65).
  - **The darks:** the darkest third of the pixels, with their mean chroma, the share of them that is grey (C\* < 6), and the chroma-weighted mean hue of the rest.
  - **The key:** the brightest 5% of the pixels, with their chroma and hue.
  - **Warm, cool and violet shares:** the chroma-weighted share of coloured pixels with hue 0-100, 180-300 and 300-360.
  - **Edge density:** the share of Canny edge pixels on L\*.
  - **Ink:** the share of dark thin strokes (black-hat of L\* > 12 with a 7 px kernel), and their mean L\*.
  - **Flatness:** the median local L\* standard deviation in 5×5 windows off the edges, and the share of those windows below 1.5.
- **Two caveats.**
  - The references are H.264 web encodes, which smooth fine texture, so their flatness numbers flatter them a little. Score our frames after the same kind of encode (the mezzanine, or a CRF-23 H.264 copy), not from raw PNGs.
  - The sets sample both whole videos at 2 fps: ref 1 from 0 to 28 s (56 frames), and ref 2 from 3 to 55 s (104 frames), which leaves out the title and end cards. They give the typical range; the gate frames give the target for each matching shot.

## The videos
| | Ref 1 (Goyart) | Ref 2 (pt5films) |
| --- | --- | --- |
| Size and rate | 2560×1440 at **30 fps** (840 frames), H.264 at 9.4 Mbit/s | 1280×720 at 24 fps (1404 frames), H.264 at 1.1 Mbit/s |
| Length | 28.05 s | 58.50 s |
| Audio | AAC, 44.1 kHz stereo | AAC, 44.1 kHz stereo |

Ref 1 runs at 30 fps, not 24. Our video stays at 24 fps (ref 2's rate, and the rate the "characters on twos" cue assumes), as PLAN.md §5 says.

## What the numbers say
1. **Most of the frame is dark.** Typical frames have a median L\* of 13-18, more than half the frame below L\* 20, and under 3% above L\* 65. Only the fire wall (ref 1 at 24.4 s) and the sunset (ref 2 at 50.5 s) are light frames, and even those keep their figures as dark silhouettes.
2. **The two refs treat the darks differently.**
   - Ref 1's darks are a saturated violet-maroon: hue about 316 (302-346), chroma about 9, and only a third of them grey.
   - Ref 2's darkest pixels are near-black ink and shadow shapes (about 75% grey). The colour sits just above them: navy and indigo at night (hue 270-290), brown-maroon indoors.
   - So the rule for us: the shadow band (L\* 20-40) carries the hue; the deepest blacks can be ink.
3. **One warm key, one cool accent.** The keys are orange (hue 40-55, chroma 40-75), and the accents are cyan-white (hue 210-235) where the sabers are. Typical frames are 60-75% warm by chroma, with a 10-15% cool accent.
4. **Lines.**
   - Ref 2 has about 1.6 times ref 1's edge density (0.032 against 0.019) and five times its ink share (0.012 against 0.002). That's its bold outlines, against ref 1's thin sketch lines that thin out in wide shots.
   - Close-ups carry the most ink: 0.013 for ref 1 at 0.9 s, and 0.017 for ref 2 at 12.9 s.
5. **Flat fills.** The median local L\* standard deviation is about 0.2-0.26 at 1280 px, and about 90% of the windows are flat. The fills are flat colour with painted texture only at large scale.

## Targets for our locations (the style meter's defaults)
Ranges are inclusive. "Matching frame" is the gate frame each shot is judged against, in PLAN.md §6, Phase 0, step 6.

| Number | Street at night (ref 2 at 37.4 and 42.0 s, ref 1 at 15.6 s) | Roofs at dusk (ref 2 at 50.5 s) | Boss roof (ref 1 at 5.3 and 24.4 s) | FP and close-ups (ref 1 at 0.9 and 7.2 s, ref 2 at 12.9 s) |
| --- | --- | --- | --- | --- |
| L\* mean | 8-25 | 35-55 | 20-55 | 15-30 |
| Dark share (L\*<20) | 0.55-0.95 | 0.15-0.40 | 0.15-0.65 | 0.45-0.75 |
| Light share (>65) | ≤ 0.07 | 0.15-0.35 | 0.01-0.55 (the fire) | ≤ 0.08 |
| Darks' hue (where coloured) | 255-330 (navy, indigo, violet) | 300-340 (dusky violet) | 300-30, through 0 (violet-maroon to maroon) | 290-20, through 0 |
| Darks' grey share | ≤ 0.9 | ≤ 0.3 | ≤ 0.4 | ≤ 0.6 for ref 1's look; ref 2's close-ups use near-black ink darks (0.98) |
| Key hue | 40-70 by design (sodium #ff9a3c is about 64); the refs' night keys are cool moonlight, 250-320 | 60-100 (sun gold) | 30-90 (fire, to its yellow-white core) | 35-60, or a cool key at 200-240 |
| Warm share / cool share | a cool frame with warm accents: cool ≥ 0.5, warm ≥ 0.05 | warm ≥ 0.7 | warm ≥ 0.75 | warm ≥ 0.4, or a cool accent ≥ 0.3 |
| Edge density | 0.01-0.04 | 0.003-0.015 | 0.008-0.025 | 0.012-0.06 |
| Ink share | 0.001-0.02 | ≤ 0.004 | 0.001-0.006 | 0.002-0.03 (0.01 or more in true close-ups) |
| Local L\* std, median | ≤ 0.4 | ≤ 0.3 | ≤ 0.6 | ≤ 0.4 |

## The gate frames
| Number | ref1 @ 0.9 s | ref1 @ 5.3 s | ref1 @ 7.2 s | ref1 @ 15.6 s | ref1 @ 24.4 s | ref1 @ 27.3 s | ref2 @ 1.2 s | ref2 @ 12.9 s | ref2 @ 37.4 s | ref2 @ 42.0 s | ref2 @ 50.5 s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| L* mean | 18.8 | 27.9 | 23.6 | 13.8 | 53.9 | 33.3 | 16.5 | 15.1 | 9.0 | 8.2 | 45.8 |
| L* std (contrast) | 9.7 | 13.7 | 23.3 | 18.6 | 27.1 | 28.6 | 24.6 | 16.7 | 10.2 | 7.5 | 25.6 |
| L* p05 | 7.5 | 5.1 | 3.4 | 2.2 | 5.5 | 3.0 | 0.0 | 0.0 | 0.1 | 0.0 | 14.4 |
| L* median | 15.9 | 24.8 | 13.9 | 7.5 | 66.0 | 25.8 | 9.6 | 9.7 | 5.4 | 6.7 | 51.3 |
| L* p95 | 37.3 | 53.9 | 90.3 | 49.1 | 83.3 | 97.5 | 80.1 | 51.5 | 26.0 | 20.3 | 85.2 |
| dark share (L*<20) | 0.65 | 0.23 | 0.63 | 0.84 | 0.18 | 0.43 | 0.77 | 0.68 | 0.91 | 0.94 | 0.30 |
| shadow share (20-40) | 0.31 | 0.59 | 0.18 | 0.10 | 0.16 | 0.24 | 0.09 | 0.20 | 0.07 | 0.05 | 0.10 |
| mid share (40-65) | 0.03 | 0.17 | 0.12 | 0.02 | 0.15 | 0.19 | 0.03 | 0.11 | 0.01 | 0.00 | 0.34 |
| light share (>65) | 0.00 | 0.01 | 0.06 | 0.04 | 0.51 | 0.14 | 0.11 | 0.01 | 0.01 | 0.00 | 0.26 |
| chroma mean | 16.9 | 27.5 | 19.2 | 10.9 | 54.3 | 18.4 | 8.1 | 13.4 | 11.8 | 9.7 | 17.1 |
| darkest third: chroma | 9.7 | 10.1 | 9.4 | 5.6 | 27.9 | 5.9 | 0.1 | 1.8 | 3.4 | 3.0 | 7.6 |
| darkest third: grey share | 0.17 | 0.36 | 0.20 | 0.56 | 0.02 | 0.62 | 1.00 | 0.98 | 0.89 | 0.74 | 0.12 |
| darkest third: hue | 346 | 350 | 295 | 324 | 23 | 271 | 290 | 19 | 281 | 268 | 328 |
| key (top 5%): chroma | 51.1 | 73.0 | 1.8 | 13.4 | 40.7 | 1.9 | 34.2 | 39.2 | 40.7 | 21.1 | 10.3 |
| key (top 5%): hue | 39 | 54 | 211 | 235 | 83 | 209 | 219 | 42 | 315 | 286 | 101 |
| warm share | 0.70 | 0.85 | 0.39 | 0.05 | 0.98 | 0.32 | 0.00 | 0.97 | 0.13 | 0.01 | 0.81 |
| cool share | 0.00 | 0.00 | 0.37 | 0.33 | 0.00 | 0.52 | 0.93 | 0.03 | 0.74 | 0.91 | 0.05 |
| violet share | 0.30 | 0.14 | 0.23 | 0.62 | 0.02 | 0.17 | 0.07 | 0.00 | 0.13 | 0.08 | 0.12 |
| edge density | 0.039 | 0.010 | 0.014 | 0.010 | 0.019 | 0.056 | 0.021 | 0.040 | 0.018 | 0.035 | 0.005 |
| ink share | 0.0130 | 0.0020 | 0.0020 | 0.0010 | 0.0030 | 0.0230 | 0.0050 | 0.0170 | 0.0020 | 0.0050 | 0.0010 |
| ink L* | 12.4 | 16.5 | 18.9 | 15.5 | 37.2 | 21.4 | 27.3 | 10.4 | 15.4 | 7.9 | 30.7 |
| local L* std, median | 0.20 | 0.23 | 0.34 | 0.20 | 0.56 | 0.49 | 0.04 | 0.15 | 0.30 | 0.34 | 0.19 |
| flat share | 0.89 | 0.95 | 0.89 | 0.94 | 0.83 | 0.79 | 0.93 | 0.89 | 0.88 | 0.82 | 0.97 |

| Number | Ref 1, whole video (56 frames): median [p25-p75] | Ref 2, 3-55 s (104 frames): median [p25-p75] |
| --- | --- | --- |
| L* mean | 22.2 [18.6-27.2] | 17.9 [13.3-27.7] |
| L* std (contrast) | 16.6 [13.7-21.1] | 19.3 [13.7-22.4] |
| L* p05 | 4.7 [3.2-6.5] | 0.1 [0.0-2.4] |
| L* median | 17.9 [14.6-21.9] | 12.9 [8.1-24.5] |
| L* p95 | 54.5 [42.7-72.6] | 57.4 [39.1-71.2] |
| dark share (L*<20) | 0.57 [0.45-0.67] | 0.66 [0.43-0.79] |
| shadow share (20-40) | 0.29 [0.22-0.39] | 0.17 [0.10-0.22] |
| mid share (40-65) | 0.09 [0.04-0.12] | 0.09 [0.03-0.22] |
| light share (>65) | 0.03 [0.01-0.06] | 0.01 [0.00-0.07] |
| chroma mean | 19.8 [15.6-24.1] | 13.0 [11.6-16.6] |
| darkest third: chroma | 9.0 [6.8-9.7] | 3.9 [2.7-6.5] |
| darkest third: grey share | 0.35 [0.16-0.47] | 0.75 [0.50-0.85] |
| darkest third: hue | 316 [302-346] | 5 [289-28] |
| key (top 5%): chroma | 34.8 [9.3-53.0] | 28.5 [22.2-31.0] |
| key (top 5%): hue | 54 [40-184] | 45 [350-75] |
| warm share | 0.63 [0.38-0.79] | 0.74 [0.12-0.99] |
| cool share | 0.12 [0.00-0.27] | 0.14 [0.01-0.78] |
| violet share | 0.25 [0.13-0.31] | 0.01 [0.00-0.06] |
| edge density | 0.019 [0.014-0.026] | 0.032 [0.016-0.041] |
| ink share | 0.0022 [0.0016-0.0052] | 0.0119 [0.0025-0.0204] |
| ink L* | 17.9 [13.6-27.2] | 13.0 [10.4-16.7] |
| local L* std, median | 0.26 [0.24-0.37] | 0.21 [0.15-0.24] |
| flat share | 0.90 [0.88-0.93] | 0.90 [0.88-0.93] |

| Frame | Main colours (k-means in Lab, largest first, with share) |
| --- | --- |
| ref1 @ 0.9 s | `#2f1c26` 0.33 `#47282d` 0.26 `#26191a` 0.20 `#683537` 0.13 `#8f3934` 0.06 `#c65a33` 0.02 |
| ref1 @ 5.3 s | `#492b36` 0.40 `#6c3438` 0.18 `#1b1619` 0.14 `#943c33` 0.12 `#bc492d` 0.10 `#e26726` 0.07 |
| ref1 @ 7.2 s | `#0e1c28` 0.41 `#321929` 0.26 `#37628a` 0.10 `#81383f` 0.10 `#c25a3d` 0.07 `#ecf5f6` 0.06 |
| ref1 @ 15.6 s | `#180f15` 0.49 `#1a1727` 0.23 `#3b283a` 0.17 `#0a3c61` 0.05 `#f2f8f6` 0.04 `#2c99c2` 0.02 |
| ref1 @ 24.4 s | `#f8bd55` 0.25 `#f69e1e` 0.23 `#38161e` 0.21 `#8a3326` 0.16 `#e6600d` 0.12 `#f8c9ad` 0.03 |
| ref1 @ 27.3 s | `#1b1a22` 0.45 `#294965` 0.20 `#479cb8` 0.11 `#ebf4f6` 0.10 `#b74036` 0.08 `#a95f8c` 0.05 |
| ref2 @ 1.2 s | `#231d22` 0.42 `#030203` 0.40 `#20d7f3` 0.08 `#3d5079` 0.07 `#8bb6f5` 0.02 `#eaeaef` 0.01 |
| ref2 @ 12.9 s | `#0e0505` 0.48 `#572d22` 0.22 `#371e1c` 0.14 `#b16551` 0.11 `#28323b` 0.04 `#88e0e8` 0.00 |
| ref2 @ 37.4 s | `#0b0b10` 0.50 `#121828` 0.28 `#1f294f` 0.12 `#4b232f` 0.06 `#3363b4` 0.02 `#ca707b` 0.01 |
| ref2 @ 42.0 s | `#091420` 0.34 `#050406` 0.27 `#142237` 0.20 `#241b26` 0.11 `#223352` 0.09 `#aedfe7` 0.00 |
| ref2 @ 50.5 s | `#32272e` 0.39 `#d5b07b` 0.18 `#b28c78` 0.18 `#85737b` 0.16 `#f4f1dd` 0.05 `#b2643a` 0.04 |

## Our frames
The style meter (Phase 1) adds our frames' numbers beside these. The Gate 1 stills and the spike are measured in [HANDOFF.md](HANDOFF.md)'s Gate 1 entry.
