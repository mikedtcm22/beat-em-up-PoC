# LD-WORLD2: judgement calls

Each call: the decision, an alternative not taken, why.

1. **The drawn detail is procedural, in the paint shader's own metres, not read from the trim sheet.** Brick courses and joints, flagstones, window frames, plank and rib patterns are drawn from face or world coordinates (`draw_brick`, `dline`, `draw_crack`). Alternative: ink from the sheet's albedo or normal at a middle mip. The sheet is nearly blank at that mip (its alpha holds only a few mortar lines, cracks and the manhole tile), so the sheet's alpha ink is kept as well (`draw_sheet_ink`, mip 2) and the rest is drawn.
2. **Every line is a distance in metres, at least about a pixel wide (`dline`), wobbled by value noise, with a per-course hash for weight and drop-outs, and faded where its cell is under a few pixels (`dfade`).** Alternative: screen-space ink from depth and normals (LD-INK's pass; it would swim and cannot be weighted per material). Cost: a far wall loses its courses by about 40 m; that is the "far = simplified" rule.
3. **Windows are framed from the sheet's own glass mask.** The mask is sampled at offsets (frame, lintel, sill) in the strip's UV, so the frame, the lighter surround and the sill follow each window without knowing its position. Alternative: a hash grid of drawn windows (it would not agree with the sheet's windows). Round 1's window blanking is off (`window_blank_p` 0): a blanked window was the mosaic.
4. **Pool normalisation is split:** `pool_norm` only for the ground, `pool_norm_wall` 0 for the walls (a lamp on a wall no longer paints it a flat salmon), `pool_hue_norm` makes a pool the lamp's colour whatever the paint, and `pool_cancel` takes the moon's contribution out of a pool. Alternative: a plain lower pool gain. It was tried: a lower gain left the pink (moon blue plus lamp orange). `pool_norm` reads `base_rgb` (the value before the lines), so a line stays dark inside a pool.
5. **The pool's hue fix needed the light()'s own normal** (`INV_VIEW_MATRIX * NORMAL`); the shader's `world_normal` varying is also read there, so both work; the up-facing test uses the light's.
6. **The haze is cut to 0.03-0.14 alpha, the halo cards to 0.55 m, the lamp cones to 120 degrees and 6.5 m, the street's sun raised to 0.65.** Alternative: keep round 1's haze and raise the wall contrast; the haze was the wash (a flat tint over every wall past 12 m). Kept: the haze quad itself, the sky and its banded halo, the single shadow caster.
7. **The props are found at run time by mesh node name** (`props` in each look: AcUnit, Car, Dumpster, WaterTank) and given the prop paint as a `material_override`, with the hull they carried as `next_pass` (kept in meta, so a second look does not stack). Alternative: edit the game's prop scripts (not allowed) or swap the toon shader globally (it would repaint the characters). Cost: the car, dumpster, AC unit and tank take a flat colour from the look, not their atlas.
8. **Prop patterns use world coordinates** (tangent distance along a box face; arc length round a tank from its node position), so they never swim. Alternative: the props' own UVs (atlas UVs, not metres).
9. **Fire from below is a painted band in the wall paint** (`fire_top_m`, `fire_color`, `fire_mix`: a hard, wobbling-edged warm band on the lower walls, with a second lower band), in section metres (moved into world space at apply). Alternative: a second fire light (the spot pool is a round shape on a wall). The band is the painted look of fire light and needs no second shadow caster.
10. **The boss roof's smoke bank and fire matte are cut back** (energy 0.6 and 1.1), the buildings are lifted (`paint_value_gain` 2.0) so they read. The fire matte's spikes are still regular: noted below.
11. **The game's edge pass stays on in round 2's act** (`--world-no-edges` hides it). Detail wins over the blind check's ruler-line tell here (Game-boy's eye outranks it); the finished shot's ink is LD-INK's.
12. **`World2Dump` is an act that prints every mesh with a material that is not the trim's** (how the props were found). Left in the act file; it renders nothing.
13. **Mattes and sky are unchanged** (round 1's). **No new assets, no Tripo, no Gemini.**

## The numbers (2560x1440, `tools/video/style_meter.py`, L* mean, game edge pass on)
| Shot | L* mean | style_meter | Out of range |
| --- | ---: | --- | --- |
| street_wide | 18.4 | 0.72, 7/11 | key hue 33 (lamp, under 40); edge density 0.14, ink share 0.078, local std (all above the column on purpose) |
| fp_punk | 22.9 | 0.78, 8/11 | key hue 14 (orange-red lamp); edge density 0.086, ink share 0.048 |
| fp_kicker_lamp | 24.1 | 0.77, 6/11 | dark share 0.47 (wants 0.55+), key hue 37, edge 0.10, ink 0.054, local std 0.47 |
| roof_silhouette | 35.1 | 0.74, 6/10 | light share 0.117 (wants 0.15+), dark hue 34, edge 0.024, ink 0.007 |
| ox_low | 18.9 | 0.99, 7/10 | L* 19.2 just under 20; dark share 0.685; light share 0.0056 |
| ox_closeup | 14.2 | 0.90, 7/10 | L* 14.7 just under 15; dark share 0.86; local std 0.65 |

Edge density is 3 to 6 times round 1's (0.015-0.034 then, 0.09-0.14 now on the street): intended (detail wins). The meter's edge column is for the sparse look; record these as round 2's values.

## How to run it
- `tools/video/shoot_still.sh "World2:" captures/video/w2/<run>` (all six, about 70 s); `"World2Motion: street_wide"` writes 12 frames. Motion check: mean luminance rises smoothly 45.9 to 48.0 over the 12 frames, the mean frame difference is flat (12.4 to 12.8), and the brick, windows and fence hold still in the world at native size (frames 0, 6, 11 looked at).
- Video tests: `tools/run_tests.sh -gdir=res://video/tests` (47, all pass); `git diff --quiet origin/video/cinematic-trailer -- game tuning tests` exits 0.

## Where it falls short (honest list)
- The first-person arm's stair-step edge is the character's (LD-ASSET and LD-INK), not the world's.
- The boss roof's flames are still a regular matte of spikes; the buildings are purple-violet rather than the maroon of ref 1, with only a warm lower band.
- Steam is still a cotton puff at 2560 (a two-tone puff, hard-edged, but soft in character).
- Far walls (past about 40 m) lose their courses and read as flat tinted planes; this is the fade, by design.
- The roof's big wall reads as a single warm plane with faint courses (low contrast against the sun), and the roof deck has no drawn paving beyond the sheet's seams.
- Cars and the dumpster are one flat colour each with simple patterns: the car has no window band.
