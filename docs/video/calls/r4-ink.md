# R4-INK: judgement calls (round 4: the brush pass, the delivery and the line)

Each call: the decision, an alternative not taken, why. Numbers are at 2560x1440; "px at 1080p" is the looks' unit.

## Calls
1. **The brush pass is a full-screen quad in the transparent queue, not a CompositorEffect.** I built the compute version first (a structure tensor, a smoothed
   tensor, an anisotropic Kuwahara and a copy-back, `EFFECT_CALLBACK_TYPE_PRE_TRANSPARENT`, as the brief suggested). With the writer's MSAA viewport the
   effect ran (a debug fill proved it) and its writes to the resolved colour were lost: POST_OPAQUE, POST_SKY and PRE_TRANSPARENT all showed nothing, only POST_TRANSPARENT
   (after the haze, which the brief forbids) stuck. So `video/shaders/brush_screen.gdshader` is a spatial shader on a quad (`video/ink/brush_quad.gd`,
   `CineBrushQuad`, added by the rig), reading the screen, depth and normal-roughness textures like `ink_screen`. Alternative: turn MSAA off for the writer.
   Not taken: it is not my file and it would change every edge of every shot. The structure tensor is read from the blurred screen mip (`brush_tensor_lod`
   1.0, a 5x5 grid) instead of its own dispatch.
2. **Ordering: the quad sorts before the haze.** The haze planes are at `Material.RENDER_PRIORITY_MIN` (LD-WORLD), and the quad has to draw before them (the
   haze, steam, flames and shafts stay as painted) and before the ink quad (MIN+2). Transparent objects of one priority draw far to near, so the quad is moved 3000 m
   down the view axis every frame (`SORT_DISTANCE`; a huge `extra_cull_margin` keeps it from being culled). Alternative: a negative `sorting_offset`. Not taken:
   I could not confirm its sign without a probe and the distance works (the tag debug view showed the shafts and steam drawn over the quad). Risk: a node that
   R4-WORLD puts at MIN priority AND wants brushed would draw after the brush; see the requests.
3. **The brush leaves a pixel alone when its tag says character or it has no depth.** The tag is the one `ink_screen` uses (`normal_roughness.a < 0.5` with
   a normal): characters (roughness 0) and the sky (depth 0) are `discard`ed, and a tap that lands on one, or across a relative depth step over `brush_depth_reject`
   (0.12), is replaced by the pixel's own colour, so a character never bleeds into the wall as a halo and a pole's edge stays hard. Alternative: skip such taps from
   the weights. Not taken: dropping samples changes the sector weights and made the strokes jump at a depth edge.
4. **The Kuwahara keeps strong thin lines, so a thin-line fill runs first** (`brush_fill*`). The tiling tell (P1 tell 1) is made of bold, thin, repeated dark lines
   (brick courses, plank seams, mullions), and an edge-preserving filter keeps exactly those (the anisotropic one even follows them). A pixel that is darker than both
   sides at +-w px along four orientations is a valley and takes the darker side's colour (w 1.5 px near to 3 px far at 1080p, so a line up to about twice that wide goes);
   a plane's edge is monotonic and a big dark shape is not a valley within w, so both stay. It runs on every tap. Alternative: a morphological closing as a
   separate pass. Not taken: it needs a second screen-sized buffer, which a quad cannot have in one pass. Cost: windows with thin frames lose a little of their frame;
   fill_far_px 3.0 keeps the street's window stacks.
5. **The posterize is in stops of luminance, with a world-anchored noise on the edges.** Bands of 0.7 stop (`brush_post_step`), soft by 0.15 of a band, the band
   edges moved by a 3D value noise of the world position (`brush_post_noise` 0.25 of a band, cells of 2.0 m) so the edges are cut by hand. "Three or four values per hue region" is
   a consequence: a wall spanning 2 stops gets 3. Alternative: a posterize per hue region (a k-means of the frame). Not taken: it changes with the camera and
   boils; the stop bands are a function of the pixel's own value and the world.
6. **Radii (px at 1080p): 2.5 at the lens to 9 from 14 m, plus up to 2.5 far from the shot's focus and 2 toward the frame's edge, at most 12.** The focus is the
   nearest figure (the rig's `_focus_point`), written every frame. The taps are an 11x11 window whose stride grows with the radius (so the cost does not). Measured:
   `moving_punk` at 0.56 s a frame with the brush on (the whole writer, 2560x1440), no slower than round 3's.
7. **The ellipse is rounder (`brush_aniso_alpha` 2.5 from 1.0).** Kyprianidis' alpha. At 1.0 the strokes ran along the walls' vertical grain and read as dry-brush streaks
   (an oil-paint filter, which the brief rules out); 2.5 gives angular facets. Alternative: no anisotropy (an isotropic generalized Kuwahara). Not taken: the
   orientation still does its job on the long edges of the roof and the window rows.
8. **The hand wobble is 3.5 px at 1080p over 2.2 m cells of the world position** (`brush_wobble_*`), from the depth buffer (not a screen noise), so it holds on the
   world. It never samples a character or the sky (it falls back to the pixel itself). Alternative: a larger wobble. Not taken: past about 4 px the windows' edges
   tear against the ink's lines, which are not wobbled by it.
9. **The delivery re-scale is in the finish pass, before the grade** (`deliver_scale` 0.65): the picture box-filtered (area average) to 1664x936 and Catmull-Rom
   bicubic back, in two new dispatches (0 and 1) of `post_finish.glsl` and a `small_image` binding; the soften comes down from 0.45 to 0.4 and the grain stays.
   Measured (`tools/video/r4_delivery_meter.py`, the radial spectrum and the 10-90% edge width of the 1500 strongest horizontal edges):

   | frame | edge 10-90% (px) | spectrum slope above 0.125 c/px |
   | --- | --- | --- |
   | ref 2 at 42.0 / 4.5 / 3.5 / 50.5 | 3.6 / 3.4 / 2.5 / 4.8 | -3.6 / -4.4 / -3.7 / -4.3 |
   | ref 1 at 5.3 / 24.4 | 3.2 / 3.5 | -4.7 / -4.3 |
   | round 3: street_wide / roof / ox_low | 2.4 / 1.8 / 2.1 | -4.1 / -3.8 / -4.0 |
   | round 4: street_wide / fp_punk / roof / ox_low / ox_closeup / fp_kicker | 2.9 / 2.9 / 2.8 / 2.9 / 3.1 / 3.4 | -4.8 / -4.7 / -4.1 / -4.4 / -5.1 / -4.6 |

   The edges are inside the references' 2.5-4.8 range (the round 3 roof and Ox were under it); the spectral slope is within it on the roof and Ox and a little steeper than
   it on the street and the close-up (the brush flattens the fine content: the slope is steeper because there is less fine detail, not because the edges are softer).
   At 0.75 the edges were 2.8 on the street and at 0.65 they are 2.7-3.0, so I took 0.65 as the compromise between the two numbers. Alternative: a stronger soften at
   0.75. Not taken: it blurs lines; the re-scale softens an edge by a fixed width and keeps a 4 px line a line. `delivery_on = false` switches the re-scale and the soften and
   the grain off together; the grade stays (a test).
10. **The line hierarchy.** (a) The hull is heavier near: `line_near_mult` 1.7 at the lens, gone by 6 m (`cine_outline` `near_mult`), so a near figure's line is wider in pixels than
   a far one's; the first-person arm is excluded (its weight is `fp_weight` 1.7 alone). (b) The shadow side against the lit side: `heavy_mult` 2.4, `thin_mult` 0.1 (24x), the lit side's
   lift (`break_amount`) 0.85. (c) The screen ink's character width: 1.5x at 1.5 m or nearer, 1x at 5 m, 0.6x from 18 m (`ink_near_gain`, `ink_far_gain`). (d) Where a near form overlaps a far one
   (a depth step over 0.5 in 1/z), the line draws as wide as `ink_overlap_mult` 1.8 times the base. (e) Inner (crease and terminator) lines are 0.6 as wide and
   0.4 as strong as the silhouette (from 0.6), because round 3's inner lines read as part of the even outline. (f) The environment's screen ink is 0.3 (from 0.45) and
   only the big shapes: `ink_env_major_m` 4 m (from 6). Alternative for (d): widen the hull on the near side. Not taken: the hull cannot know what is behind it. At first (d) was 0.35-0.8 at 0.9 and
   drew a black smear under Ox's headband (the overlap of the brim over the eyes); 0.5-1.0 at 0.8 and 1.8 x keep the eyes.
11. **Hatching is R4-ART's:** the `hatch_*` values are as they were.
12. **Tests:** none weakened. New: `video/tests/test_r4_ink_data.gd` (9). The existing `compositor_effects[0]` tests still hold (the brush is not a compositor effect).

## The blind check's eight tells, by shot
Judged at full resolution beside the references (ref 2 at 3.5, 4.5, 42.0, 50.5; ref 1 at 24.4 and 5.3) and the round 3 render, from `captures/video/r4ink/` (untracked: the six finals, `sheet_final_six.png`, the A/B sheets `ab_*.png` with
ref | round 3 | brush off | final | delivery off, `mp_on`/`mp_off`, the work crops). "Removed" means in the frames I looked at; the world's own look (the kit, the pools and the cones) is R4-WORLD's and the characters' shading and the arm are R4-ART's.

| shot | removed or reduced | still there | read by a viewer who was not told |
| --- | --- | --- | --- |
| street_wide | 1 (the brick courses and window kits flatten to painted planes past about 6 m), 8 in part (the walls are flat dark masses with hand-cut edges), 6 (the Punks' lines vary), 7 | 1 near the camera (the left wall's kit), 2 (elliptical pools, constant cones), 3 (round puffs), 5 (the three Punks are one model) | 3D, less: the walls read as paint, the lights and figures do not |
| fp_punk | 1 and 8 on the right wall, 6 (the arm and the Punk have a heavy, broken outline), 7 | 4 and 5 (the arm: one smooth shape, no hatching of mine; mitten fist), 2 (the cone) | 3D: the arm is a third of the frame |
| fp_kicker_lamp | 6, 7, the wall | 2 (the lamp cone), 4, 5 (the arm, mirrored gloves) | 3D |
| roof_silhouette | 1 on the brick wall (a painted shadow shape across it), 8 (flat masses), 7 | 5 (the tanks: exact cylinders with straight planks), 2 (the sun's halo is the world's) | leans drawn in the sky and the walls, 3D in the tanks: a toss-up |
| ox_low | 6 (a heavy contour that varies), 1 on the buildings (the windows are painted blocks), 7, 8 | 5 (the symmetric pose), 4 | leans drawn: the fire, the buildings and the heavy line carry it |
| ox_closeup | 6, 7, the buildings | 4 (the face's shading is the hatch plus the toon, R4-ART's), 5 (the mitten gloves) | leans drawn, less than ox_low |
| moving_punk (frames 30-33) | the wall's planes hold still on the world | the street kit when close | 3D in the street, as street_wide |

## Honest pillar scores (PLAN.md section 6 rubric, 0-3), what I built, judged at full resolution beside the references
- **P1 line: 2** (round 3: 2; the street's figures 1.5-2, the arm 1.5, Ox 2). The weight now varies along a contour, between the shadow and lit sides, with the distance and at overlaps; the environment lines are sparse. The arm's inner lines are still two faint curves.
- **P2 fill: 2** (round 3: 1.5): the world's walls and buildings read as painted planes with hand-cut edges; the characters' shading is R4-ART's (still a computed look on the arm and the Punk's vest).
- **P5 atmosphere: 2** (unchanged: not mine; the brush leaves the haze, steam, flames and shafts as drawn, and the haze still draws over it).
- **P8 coherence: 2.5** (round 3: 2.5): no swimming (the second temporal difference on world pixels is 0.89-0.99 of the brush-off render's over three 12-frame windows of moving_punk, and four frames cropped at full resolution show the planes holding on the world); the risk of "a filter over a game" (P8 in the plan) is real in the street's far walls, where the strokes are still slightly streaked: I turned the filter down for it (alpha 2.5), and say so.

## Style meter, before (round 3) -> after (this package)
street_wide 0.97 (9/11) -> 1.00 (11/11: edge density 0.0413 -> in range, local_std_p50 0.514 -> in range); fp_punk 0.97 -> 0.97 (cool_share 0.323 -> 0.345); fp_kicker_lamp 0.99 -> 0.99 (cool_share 0.442 -> 0.459);
roof_silhouette 0.72 (4/10) -> 0.91 (6/10: edge density 0.027 -> 0.0173, ink_frac and local_std now in range); ox_low 0.88 -> 0.95 (edge density 0.0393 -> 0.0327, ink_frac in range); ox_closeup 0.88 -> 0.91 (local_std_p50 0.657 -> 0.535).

## Requests
- **R4-WORLD:** anything at `Material.RENDER_PRIORITY_MIN` draws AFTER the brush (that is what the haze wants). A world surface that is alpha-blended and should look painted (a decal of brick, a wet-street plane) escapes the brush: keep such things opaque, or tell me and I will move them.
- **R4-WORLD:** the walls' rain-streak and plank grain are vertical hairlines; the brush turns them into streaks at the far end. If the grain's contrast comes down in the world material, the street's far walls read flatter.
- **Lead:** the frame writer's SubViewport is MSAA 4x. That is why the brush is a quad. If the writer ever goes to FXAA or none, a compute version could move into the compositor as a CompositorEffect, but nothing needs it.
- **Lead:** the sharpness numbers (call 9) are the thing to re-check on the 8-bit encode (crf 23): I measured on the PNGs.

## Not shown or not proven
- The brush on the boss roof in motion (t10) and on the roofs in motion (t07) was not rendered.
- The thin-line fill and the near/overlap line values were tuned on the stills; a close-up with a fast figure (t03) was not looked at.
- The per-frame cost: `moving_punk` seconds a frame 0.56 (the whole writer); the brush's own share was not isolated.
