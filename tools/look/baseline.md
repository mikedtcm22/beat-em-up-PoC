# Look baseline (M7 P0, 2026-11-11)

Protocol: judge_protocol.md. Judge: one Sonnet agent, three passes on three shuffles (seeds 101, 202, 303), 42 stills in 7 contact sheets of 6 per pass (21 sheet reads); it never read key.json. Style meter: `group_meter.py` (best-fitting of the four locations per frame).

## Bar (blind p_3d, 0 drawn to 1 3D)
| Group | n | median | spread (min-max of per-image medians) |
| --- | --- | --- | --- |
| **Trailer frames (the bar)** | 25 | **0.09** | 0.05-0.14 |
| Reference stills | 8 | 0.07 | 0.04-0.12 |
| M6 game tiles | 9 | **0.93** | 0.71-0.93 |

M6 splits: the 5 street tiles all 0.93; the 4 boss (Ox) tiles 0.71-0.75. Gate: a candidate's median at or below about 0.15 matches the trailer (its max); anything above 0.5 reads 3D.
Tells cited most often for M6: exact-perspective brick, chain-link and plank repetition; flat texture-mapped surfaces; ruler-clean straight outlines; the dumpster and crate geometry; the flat posterised Ox face and cuffs with no line hierarchy; the HUD text.

## Style meter (mean over group)
| Group | best score | rules in range | L_mean | frac_dark | edge_density | ink_frac | cool/warm share |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Trailer | 0.909 | 0.74 | 27.4 | 0.45 | 0.039 | 0.018 | 0.36 / 0.52 |
| Refs | 0.976 | 0.89 | 26.1 | 0.56 | 0.024 | 0.006 | 0.19 / 0.69 |
| M6 | 0.840 | 0.61 | 37.6 | 0.12 | 0.039 | 0.011 | 0.22 / 0.71 |

The meter separates M6 from the trailer far less than the judge does (0.84 vs 0.91): M6 is too light (L 38 vs 27, frac_dark 0.12 vs 0.45) but its edge density matches. The meter is a guard rail; the judge is the gate.

## Caveats
- The judge knew which "look" family each frame belonged to by content (it can see the Ox and the alley), so the test is blind to the key, not to the subject. All M6 frames carry the "Run: held back" debug text in the street tiles; that is an extra tell, and it makes the street score (0.93) a ceiling-like number. M7 gate captures must be clean.
- M6 tiles are crops (348x196) from the 2400x1080 overview sheets (the only M6 stills in captures/m6-look), upscaled to 960x540, so they are softer than native frames; the trailer frames are 1920x1080 downscaled. Re-capture M6 at native size for a fair re-run if the gap matters.
- Sources: assets/source/trailer_ref/{frames,ref}, assets/source/m6_baseline (9 crops, committed).
- Venv: style scripts need numpy, opencv-python-headless (cv2) and imageio: `~/.venvs/beat-em-up-video/bin/python -I`. judge_sheets.py needs PIL (system python3 had it; else use the venv). make_judge_set.sh needs ffmpeg.
