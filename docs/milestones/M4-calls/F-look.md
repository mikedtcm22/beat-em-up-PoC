# M4 calls: F-look

Package F-look (phase 2, M4-plan Part C section 7 with Part A A9 and A11, Part B's L1-L3 and the slice gate's locks and ranked gaps 2, 6 and 11): tune the look on the smoke Punk (concept A; every Street Punk wears it, F-punk replaces the GLB later, so the look is tuned, not the asset) and make the placeholders, the street and the VFX read beside it. Each call is the decision, an alternative not taken, and why. Part 2 lists every assertion that changed (old to new, with its twin), part 3 the numbers, part 4 what the first-person sheets show. The machine was shared (load 4 to 7), so no frame time was measured; the lead measures perf.

The gate's locks are untouched: 4x MSAA is the default with FXAA as `look_aa_mode` 1, `look_outline_px` 3.75, the placeholder hulls on, the dilated edge mask, the A-pose route and the Tripo weights, halftone off, no move clip and no game state changed.

## 1. Calls

**C1. Gap 2 (a front that is one violet band): the sun is moved, the bands are lowered, and the characters get a camera-fixed fill. The root cause was the sun's azimuth, not only the band break.**
- *What was found.* The room's sun was `rotation (-52, 32)`: the player's default view (looking +X in both rooms) has the sun behind the Punk, so the Punk's front had `dot(N, L) = -0.33`, below `look_band_1`, the shadow band, with the violet tint the whole way: the "one violet band" (skin hue 337 degrees against 27, teal 207 against 185). Turned half a circle, the front reached 0.52, a flat mid band, because `look_band_2` (0.62) sat above `cos(elevation)` (0.616): no vertical surface could ever be lit. About half of all enemies face away from the sun whatever its azimuth, so the sun alone cannot give them bands.
- *Decision.*
  - The sun: `look_sun_elevation_deg` 45 (cos 0.707), `look_sun_yaw_deg` -50 (the player's default view is lit from behind his shoulder, so the fights down the street are front-lit), `look_sun_energy` 1.2 and `look_sun_shadow_blur` 0.25 (see C6). They are Tuning values now (they were literals in `RoomKit.build_environment`), applied by `RoomKit.apply_sun()` at build and by `LookPost` on every `look_*` change, so the F1 panel moves the sun live in both rooms.
  - The bands: `look_band_1` 0.22 and `look_band_2` 0.52, under cos(elevation) (a front facing the sun within about 40 degrees is lit, up to 70 degrees mid, beyond shadow).
  - The fill (characters only): `light()` takes the stronger of the sun's term and `look_fill_strength * dot(N, fill_dir)`, `fill_dir` a camera-fixed direction (view space; `look_fill_yaw_deg` -35, `look_fill_pitch_deg` 40, strength 0.8), only on the directional light's pass and only on materials that have a fill (`ToonMaterials.apply_look()` gives it to the character and art kinds; the room, the pipe and the floor stay on the sun alone). A contre-jour front now has a lit patch up and to the left, a big mid area and a violet shadow low and to the right, so three bands from curvature alone; a front-lit one has the sun's lit band as well.
- *Alternatives not taken.*
  - Only lowering `look_band_2`: front-lit fronts get a lit band but contre-jour ones stay one flat shadow (tried; the lead named the case).
  - A second Godot light for the fill: the shader's `light()` runs per light and adds, so two lights would stack their mid levels (1.44) and double the shadow level; a `cull_mask` for characters is also awkward with the first-person layers.
  - Wrap lighting (`(ndl + w) / (1 + w)`): the shadow map's term is 0 on a self-shadowed front, so it still gives no bands there.
  - Turning the sun with the player's yaw: the room's walls would flip between lit and shadow as he turns.
- *Why.* One shader, no new light, no change to the room, and the shadows on the floor still come from the sun. The fill is the SPEC's "rim light, tinted shadows" look made camera-proof; it is not a spec departure.
- *Measured (part 3).* 3 jacket bands in both lights, front-lit and back-lit, in both rooms; shadow/lit luma 0.66; the lit and mid teal 0 to 1 degree from the swatch's hue, the shadow band 22 degrees toward violet (that is the bible's 45% tint); skin mid and lit bands 0 to 1 degree from the swatch's 27, the shadow band 337 (violet, only on the lower-right of a surface).

**C2. The tonemapper is linear (`look_tonemap` 0), with filmic one slider away.**
- *What was found.* Filmic pulled colours toward grey and lifted the blacks: the lit skin's mid band came out 10 to 40 degrees off its hue, and the ink read 10 to 16 levels lighter than the HUD's ((27, 24, 31) for an edge line). Switching it off isolated it: with the shadow tint at 0 the skin was 28 degrees, teal 186.
- *Decision.* `Environment.tonemap_mode` is linear in both rooms (`LookPost.tonemap_mode(look_tonemap)`: 0 linear, 1 filmic (M3's), 2 Reinhard, 3 ACES; applied live, and by `RoomKit.build_environment()` at build). A flat colour shows as authored, so the palette atlas, the ink and the VFX sprites show their authored colours.
- *Alternative.* Keep filmic and pre-compensate the palette or the grade. Rejected: the palette is the atlas's and the grade has a ΔE bar to keep; the tonemapper is the one thing between them that moves every hue.
- *Cost.* The street read darker and greyer under linear (no filmic lift), so its colours were retuned (C8). The sky shows as authored.

**C3. One ink: the hull has no fog, and the on-screen ink is the HUD's within 2 levels.**
- *Decision.* `toon_outline.gdshader` is `unshaded, cull_front, fog_disabled`. The fog (density 0.008, light colour (0.6, 0.56, 0.55)) added 7 to 13 levels to the hull's ink at 2.5 to 5 m and made it a grey ring at 10 m while the body stayed solid. With it off and the tonemapper linear the hull reads (16-17, 14-15, 22-25) at every distance and the edge pass's lines (16, 14, 22), against `HudStyle.INK` (18, 15, 23): measured by T3 and T7.
- *Alternative.* Raise the hull's ink to cancel the fog. Rejected: the line would then be wrong at 1 m.

**C4. L1: the cap crown "0.1-0.3 px under the floor" was the fog, not near/far or px.** The ring the gate measured at 2.5 to 10 m was a fogged, lighter ink, so its half-maximum width read short. With the fog off the crown reads 3.5, 3.5 and 3.3 px at 2.5, 5 and 10 m (1080p), the sides 3.2 to 3.5, 3.0 at 10 m, and nothing needed `look_outline_near_m`, `look_outline_far_m` or `look_outline_px` (all unchanged; `near_m` was tried at 0.2 and put back: it moved nothing, and a sample inside the lens fade broke a pinned assertion).
- *The measure.* The gate's scan took the half-maximum width of the first dark line met on a straight scan; on the busy backgrounds of the street it read the building's own lines. `LookProbe.outer_ring_px()` measures instead what the hull adds: the same frame with `look_outline_px` set to 0 is the reference, a pixel's coverage is how far the frame with the hull has moved toward the ink, and the ring's width is the sum of the coverage along the first run from the outside (the shorter of the row's and the column's), so it is sub-pixel and blind to the background. `LookProbe.ring_width_px()` does the same for every run (the median).
- *The ink-dark wedge across the near glove in C4's jab.* It is not the hull: the same frame with the hull's width 0 is identical (`captures/exp/wedge.png`). It is the glove's own shadow band on a near-black swatch (`near_black` #2b2833 times 42% tinted), which at 0.35 m fills a third of the frame and reads as a flat dark wedge. The glove swatch is F-punk's brief line (gate gap 3: a value of about 0.3 or more).
- *Open.* The glove's silhouette ring reads 3.6 px at 720p (5.3 at 1080p) at 1 m, about 1.4 times the line elsewhere, over the dumpster in the crowd room (the crowd room's left-side figure of 5.17 in part 3; the training room, over a plain wall, reads 3.8). The cuff's ragged mesh makes the smooth normals there lean; it is the asset's, and the bar of 4.5 is met everywhere else.

**C5. The player's own body: x0.8 holds; the guard's box-corner reads 4.7 px.** T8 (view 20 degrees down, the block guard: his forearms in the frame's top corners, 0.25 to 0.4 m from the lens) reads 4.2 to 4.7 px at 1080p. The player's body is still primitives (F-player-art's GLB replaces them), whose box hull moves every face plane out by exactly w, so at a corner the ring is 1.41 w: 3.0 x 1.41 = 4.2. The width formula (x `look_outline_fp_scale` 0.8 of the character's, tested for 0.3 to 0.6 m in `test_the_hull_meets_the_look_bible_at_1_to_10_m`) is unchanged; the figure is a placeholder's, and F-player-art should re-run T8 on the art.

**C6. Gap 11 (the stippled 10-20 px edge on the forearm): the dither is gone with the new bands; `look_band_soft` and the shadow filter are unchanged except the sun's blur.**
- *What was found.* The skeptic's reading was right: a band edge laid over the renderer's dithered penumbra at a grazing angle. With the new bands the forearm's three bands have 1 px edges (a luma scan across the right forearm at 1 m: 0.72 to 0.83 in one pixel, one half step in between, at 720p, so 1.5 px at 1080p), and the stipple survives only as a few specks at a grazing edge.
- *Decision.* `look_sun_shadow_blur` (the sun's `shadow_blur`) 0.25 (Godot's 1.0): a toon shadow wants a crisp edge, and the blur only widens the penumbra the dither lives in. `look_band_soft` stays 1.2 (about 0.8 px at the 720p window, 1.2 at 1080p, inside the bible's 2).
- *Alternative.* A harder fix in the shader (binarise `ATTENUATION`). Not needed once the stipple was a few specks, and it would give a hard step to the shadow map's own resolution limits.

**C7. The rim is visible, gated by the combined light, and the highlight is small.** `look_rim_cut` 0.4 and `look_rim_power` 2 (were 0.7 and 3): the old rim was about 1 px wide (a sphere's grazing ring, 6 degrees), now about 7 to 10 px at 1 m. `light()` gates it by the combined light (`smoothstep(0, 0.3, lit)`), so a character that faces away from the sun is rimmed on the fill's side, not nowhere. Strength stays 0.35 (+35% value). The one hard highlight (`look_spec_*` unchanged) is 0.14% of the Punk's pixels front-lit and 0 back-lit (the bible: under 3%), on the cap, the lenses and the glove knobs.
- *Alternative.* Rim all round the silhouette regardless of light. It would be a flat halo that fights the hull.
- *A side effect, and how L2 reads it.* The rim is a fourth luma level on the jacket in a back-lit shot (4% of the vest's pixels: the grazing folds inside the silhouette as well as the edge). L2's "2-3 luma clusters on the jacket" is therefore read from a frame with the rim off (`jacket_bands`, 3 in both lights); the picture as drawn is reported beside it (`jacket_bands_with_rim`: 3 front-lit, 4 back-lit). The rim is J5's separate "readable rim".

**C8. The street: muted, 0.30 saturation at most, deeper windows.**
- *Decision.* `crowd_room.gd` and `test_room.gd` colours (S, V before to after): the crates (0.55, 0.46, 0.30) (S 0.45, V 0.55) to (0.50, 0.44, 0.35) (0.30, 0.50); the dumpster (0.20, 0.42, 0.30) (S 0.52) to (0.28, 0.40, 0.34) (0.30, 0.40); the windows (0.16, 0.20, 0.28) (S 0.43, V 0.28) to (0.20, 0.22, 0.28) (0.29, 0.28); the doorways' dark (0.12, 0.10, 0.13) (V 0.13) to (0.26, 0.24, 0.27) (V 0.27); the road paint (0.82, 0.80, 0.72) (V 0.82) to (0.60, 0.58, 0.52) (V 0.60). The walls, the accent, the ground and the car were already inside the bible's S at most 0.30 and V 0.25 to 0.6. The sky and the fog are unchanged. `test_every_street_surface_is_inside_the_bibles_saturation_and_value` holds every street box's colour in both rooms to it.
- *Windows.* The window boxes were 3 cm deep and 1.5 cm proud; their side faces were under a pixel tall at a distance, so the edge pass's crease lines on them flickered as dashes. `window_depth_m` 0.12 and `window_proud_m` 0.09 (new exports of `crowd_room.gd`) give a steady outline. `look_edge_normal_threshold` is unchanged.
- *Edge lines* measure 1.5 px at 1080p (E1: `edge_line_px_1080` 1.5; the bible's 1 to 1.5), the HUD plate 0.0% changed.
- *The grade* (street_dusk) is unchanged and `test_the_grade_keeps_the_enemies_and_the_blood_within_delta_e_6` passes: the LUT keeps the saturated colours within ΔE76 4 (the bar is 6).
- *Alternative.* Keep the saturated dumpster and crates as "props". The lead named them; a muted street is what lets the Punk's teal and yellow carry.

**C9. Gap 6, my half: the damage tiles are redrawn, no wash.** `tools/gen_fx.gd`'s `_damage_tile()` only; every other effect PNG and SVG is byte-identical (the generator run changed exactly the four damage files; `test_fx_m4` reproduces them).
- *Skin.* The bruised and bloodied skin tiles had a whole-tile purple-grey wash (`BRUISE_WASH` at 30%) over the skin, which is what made the skin read lilac and glassy at 65% and 30%; the skin kept 94% of its saturation but lost its warmth. No wash now: the comic bruises (an olive-brown rim at 35%, a purple or blue body with an ink edge) sit on the skin as it is. Measured: the skin's single band at 65% is 26 degrees (the swatch's 27) and at 30% 24 degrees, against 22 and 18 before the redraw.
- *Clothes.* The scuffed and blood tiles had a dirt wash and nine big dark blobs that read as camouflage on the teal denim. Now pale dust smears (elongated along one grain), a few dark grease smears, ink tears and scratches, with no wash. On the vest they read as faded wear.
- *Not mine.* The cap and the lenses share the `punk_yellow` swatch and so take clothes-density blood (F-punk's: a lens swatch with `marks: false`, thinner marks on the cap).
- *Alternative.* Keep the wash and lower its opacity. The wash tints every swatch it lands on, and a bruise reads from its own colour.

**C10. J13 (one game): the placeholders are retuned through the same tunables only.** Kicker, Thug, Bruiser, the boss, the dummies and the pipe have no per-character change: they are the same toon material and hull, so the new bands, fill, rim, sun, linear tonemap and ink apply to them as to the Punk (C7 and C9 sheets, part 4). Their colours (the Kicker's lime, the Bruiser's purple) are the enemies' own and stay saturated (the bible: at least 0.5).

**C11. Instruments: `tests/bot/acts/look_tune_acts.gd` (T1-T8) and `tests/bot/look_tune_bot.gd`.**
- *Decision.* Eight acts titled "Look: tune ..." (none inside another's, and none inside any other act file's; `test_look_tune` checks all of them): T1 the Punk at 1 m front-lit then back-lit (the sun turned half a circle), T2 at 3 and 8 m, T3 the hull's ring at 1, 2.5, 5 and 10 m, T4 the three health looks, T5 the jab's flash, T6 the lineup in both lights, T7 the street's four views in both lights (and the edge ink), T8 the player's own hull. The crowd bot loads them by name; the training room's bot (`look_tune_bot.tscn`, the combo bot with the helpers the acts use) runs the same ones, so both rooms are judged from one script. Metrics are `LOOK-METRIC` lines and `look.json` (one entry per slug).
- *Probe additions* (`look_probe.gd`, covered in `test_look_post`): `hue_gap`, `bands` (the brightness bands of one swatch family with each band's colour), `line_width_scan`, `ring_width_px`, `outer_ring_px`, `dump`.
- *The recordings are 1280x720 renders upscaled to 1600x900.* The movie is 1600x900 but the window renders at 1280x720 (project.godot's override is overridden by the capture script's `--resolution`): the viewport grab is 1280x720 and `PSNR` of a downscaled still against it is 37 dB. The probe reports at 1080p whatever the frame's size; the stills are 1.25 times soft along edges.
- *Alternative.* Add the acts to `look_acts.gd` (L0-bench's, SL-int's). Not mine to edit.

## 2. Assertions that changed (old to new, and the twin)

- `tests/test_toon.gd::test_a_character_has_three_bands_and_a_shadow_that_is_never_black` and `::test_the_room_has_two_bands`: the sweep of light started at -0.2 and went in steps of 0.035, so a sample landed exactly on the new `look_band_1` (0.22) and read half way, a fourth colour. It starts at `SWEEP_FROM` (-0.2007), off the grid of every default break. The intent (three bands on a smooth sweep, two in the room) is unchanged. Twin: `test_a_band_edge_is_half_way_at_its_break_and_steps_nowhere_else` still pins the half-way value at the break itself.
- `tests/test_toon.gd::test_materials_take_the_look_values_now_and_on_every_change`: after a whole-set change `band_1` was asserted equal to the literal 0.25; now to `TuningData.new().look_band_1`, the default whatever it is (the test is about the preset load, not the number). Twin: the new `test_the_bands_leave_room_for_a_lit_front_below_the_suns_height` pins the numbers' relation to the sun (band 2 under cos(elevation), shadow level at least 40%).
- Nothing was weakened; no other existing assertion changed. New tests: `test_toon` (the fill is the characters' and follows its tunables, the fill's direction is a unit vector in view space, the fill lights a front the sun does not and only for the directional light, the hull is not fogged, the bands leave a lit front), `test_look_post` (the tonemap tunable, the sun follows its tunables in both rooms, the new tunables' group and preset rule, every street surface inside the bible's saturation and value, the probe's `hue_gap`, `bands`, `line_width_scan`, `ring_width_px` and `outer_ring_px` on synthetic frames), `test_look_tune` (the act file, the title collisions across every acts file, T1 in both rooms, the sun turned, the lineup act in the training room).

## 3. The numbers (windowed, M1, `captures/f-look/probe/{crowd,training}/look.json`, never committed)

**L2, T1 (the Punk at 1 m, view 6 degrees down).** Jacket (the teal vest), both rooms identical to the shown digits:

| | front-lit | back-lit |
| --- | --- | --- |
| luma clusters, the shading's bands (rim off) | 3 | 3 |
| the picture as drawn (rim on) | 3 | 4 |
| shadow / lit luma | 0.66 | 0.66 |
| lit band hue gap to the swatch's 185 degrees | 0 | 0 |
| shadow band hue gap | 22 (toward violet) | 22 |
| skin mid / lit band hue gap to 27 degrees | 0 / 1 | 0 / 1 |
| skin shadow band | 337 degrees (50 from the swatch; the 45% violet tint) | 337 |
| white share of the Punk (the highlight) | 0.14% | 0% |

Before (M3 and the gate's reading): one band; skin 337 and teal 207 over the whole front when the sun is behind it.

**L1, T3 (the hull's ring, 1080p px; the target 3.75 within 1, never above 4.5).** Crown / left / right:

| distance | crowd room | training room | ink on screen (HUD: 18, 15, 23) |
| --- | --- | --- | --- |
| 1 m | 3.5 / 5.2 (glove over the dumpster, C4) / 3.5 | 3.5 / 3.8 / 3.7 | 17, 15, 25 |
| 2.5 m | 3.5 / 3.5 / 3.2 | 3.5 / 3.4 / 3.3 | 16, 14, 22 |
| 5 m | 3.5 / 3.3 / 3.5 | 3.5 / 3.3 / 3.4 | 16, 14, 22 |
| 10 m | 3.3 / 3.0 / 3.0 | 3.2 / 3.2 / 3.0 | 16, 14, 22 |

Before the fog fix (the same frames, first measure): the crown 3.6, 1.7 and 1.1 and the sides 2.8, 2.5, 1.2 at 2.5, 5 and 10 m, the ink (23, 21, 28), (27, 26, 32) and a grey ring at 10 m. The edge pass's lines read (16, 14, 22) in all eight street views of T7.

**L3, T5 (the player's jab on the Punk at 1 m).** The white share of the frame the contact flash is first drawn in: 3.9% by the probe (viewport grab), 3.7% on the recording's still; the before pack's same hit (C5 frames 44 and 45, M2's localised flash on the M3 look) 4.1% and 4.3%, and its other jabs 3.9 to 4.1%. So the flash is no larger than M2's (the bar: M2's + 2 points). Two frames, as `hit_flash_frames` says (the third is 0.7%).

**T4 (the skin's single band at each health, hue gap to the swatch's 27 degrees):** 100% bands of 28 / 27 / 337, 65% 26 degrees (one band), 30% 24 degrees; before the redraw 22 and 18.

**T8 (the player's guard, 1080p):** 4.2 to 4.7 px at the corners (C5).

**Edge lines (E1):** 1.5 px at 1080p, 1.4% of the frame's pixels change with the pass, the HUD's 0.0%; the grade's mean ΔE 3.0.

## 4. What the first-person sheets show

Looked at, one act per process against the before pack (`captures/f-look/`, `captures/exp/`): C1, C2, C4, C5, C6, C7, C9, T1 to T8 in the crowd room and T1 to T3 in the training room, full resolution and at 6 fps.

- **C2 (the Punk at 1 m).** Before (M3): a teal block with a black bar for a face, one soft shade. After: the smoke Punk in three crisp bands, a lit patch on the cap, the nose, the shoulders and the forearms' tops, a big mid area and a violet shadow on the lower and right sides; the skin warm, the vest teal, no lilac front. Front-lit and back-lit differ in how much is lit (the sun's lit band is on a front-lit one) and not in how many bands there are. The ink line is even all round, the rim a pale strip inside it on the key side. The street behind is a muted violet-grey with ink on its edges.
- **C1 (the face shot).** The cap crown, brim and the shades carry a continuous ink line; one small hard white highlight on the crown, one on the lens and the nose.
- **C5 (reacts).** The flash is localised and the same size as before; the hook's stagger, the uppercut's launch, the get-up and the KO read in three bands; at 100/65/30% the skin goes from clean peach to purple comic bruises to bruises and red splats (the face and both forearms), the vest to pale wear marks to wear marks and blood; no grey, no lilac skin, no camouflage. The KO's blink-off is clean.
- **C4 (attacks).** The jab and cross strikes fill the frame with a near-black glove whose shadow band is a flat dark wedge, not the hull; the shove's arm shows the three bands.
- **C6 and T2 (distances).** The Punk reads at 3, 5 and 8 m in both lights (a saturated teal and yellow figure against a muted street, an ink line 3 px wide at every distance); at 10 m the figure is 150 px tall and the asset's dark texture fringe makes the interior busy (a hull of 3 px does not fix that; F-punk).
- **C7 (lineup) and T6.** The Kicker, Thug and Bruiser have the same bands, rim, ink and sun as the Punk: they read as one game with him in the placeholders' flat boxes against his painted detail, which is the gap between a placeholder and an asset, not a look difference. The Kicker's lime and the Bruiser's purple stay saturated. In the back-lit lineup the whole street is in violet shadow and the characters still have bands.
- **C9 (street tour).** Walls two-banded and muted, crates, dumpster and car inked, the road paint a pale strip, ink lines 1.5 px on the buildings and floor edges, windows with steady outlines (no dashes). The street is darker and flatter than M3's soft filmic one, which is the look the bible asks for.
- **Honest verdict.** C2, C5, C7 and C9 read as one game: one ink, one band structure, one sun, a muted street and saturated characters. What does not yet read as one is the placeholders' detail against the Punk's; that is the assets', and the lime Kicker is a very bright colour beside everything. The back-lit street is almost all shadow (the sun turned half a circle is the extreme case; the default is front-lit).

## 5. Requests, departures, risks

- **Requests.** (1) F-punk: a glove swatch with value about 0.3 or more (the wedge and the "canister"), a lens swatch with `marks: false` and a thinner cap mark (the blood on the cap), the cuff's ragged claws (the thick glove ring). (2) F-player-art: re-run T8 on the art (the box-corner reading is the primitives'). (3) The lead: `tuning/default.json` is regenerated with this branch's values (500); `look_tonemap`, the sun and the fill are saved in presets; a preset saved before this branch has the old band values and no fill, and loads them. (4) ARCHITECTURE: the heading "Tuning the look (F-look)" is filled.
- **Departures.** None from the spec. Two choices the lead should know are mine: the linear tonemapper and the camera-fixed fill (both behind a tunable: `look_tonemap` 1 gives M3's filmic, `look_fill_strength` 0 no fill).
- **Open risks.** (1) The sun's yaw is tuned for the default view (+X): enemies behind the player are back-lit in his default turn, and rely on the fill. (2) The linear tonemapper moves every unshaded VFX sprite to its authored colours (brighter than under filmic); the VFX sheets (vfx_bot) were not re-recorded here. (3) The hull's thick glove ring and the box-corner overshoot of the placeholders are not under 4.5 px everywhere (C4, C5). (4) The measured L1 sides at 10 m (3.0 px) rely on a ring that is 2 px at the 720p the window renders; at a real 1080p window it is 3 px of 3 px wide pixels. (5) Perf is unmeasured (the fill adds one dot product and a `max` per character fragment; the hull lost the fog lookup).
