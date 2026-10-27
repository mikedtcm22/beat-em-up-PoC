# P1-post: judgement calls

Package P1-post (phase 1): the edge pass, the grade, both rooms through RoomKit, the look probe. Each call: the decision, an alternative not taken, and why. Measurements are marked NOISY when the machine was busy (the load average is given).

## A8 probe: the character mask in the normal-roughness buffer

**How it was run.** A scratch scene (not committed), Metal / Forward+ on the M1, 4x MSAA as the project sets it, windowed 1024x576: a floor and a box whose shader writes `ROUGHNESS = 1`, a sphere whose shader (`render_mode ambient_light_disabled`, standing in for P1-toon's art tag) writes `ROUGHNESS = 0`, the same sphere with an unshaded `cull_front` hull on `material_overlay` (`VERTEX += NORMAL * w`), a second sphere with a lit hull (`ALBEDO = 0`, `ROUGHNESS = 0`, `SPECULAR = 0`, `EMISSION = ink`), a third without a hull, a `StandardMaterial3D` box (rough 0.9) and an unshaded `StandardMaterial3D` box. A quad at priority -127 showed the buffers through a debug view (`hint_normal_roughness_texture` alpha as grey, rgb as colour, the depth, the lines). The same views are in the shipped edge pass as the Debug tunable `look_edge_debug_view`.

**The three answers.**
1. **Does the toon fragment's `ROUGHNESS` reach `hint_normal_roughness_texture`? Yes.** Read back from the alpha channel: the tagged sphere 0.000, the `ROUGHNESS = 1` box and floor 1.000, the `StandardMaterial3D` box 0.896 (its own 0.9). `ambient_light_disabled` makes no difference to it. The sky and every pixel with no geometry read 0.000 too: a character tag and the background look the same in this buffer, so the pass must find the sky from the depth (raw depth 0 in the reversed-Z buffer) and treat it as roughness 1. Without that a tag-0 test would switch off every skyline line.
2. **What does the unshaded hull write there? Roughness 1.0** (the default of an unshaded material), so a ring of "environment" roughness sits outside the tagged body. Its depth is written too (it is an opaque overlay). The lit hull of fallback 1 writes 0.0, so its ring joins the body in the mask.
3. **Does a depth line appear just outside the hull? Yes, with the unshaded hull (and with the lit one too until a mask is applied).** The depth jump is hull-to-background, and the hull's own pixels are ordinary depth, so an unmasked depth line draws a second ring outside the hull and a third inside it where the body meets the hull. The plan's mask ("skip any pixel with a tap below roughness 0.5", taps 1-2 px away) fixes the lit hull but **not** the unshaded one: the hull is wider than the taps, so the outer ring's taps see only hull (1.0) and background. The ring stays.

**What was chosen (A8's fallback order, adapted).** The tag does reach the buffer, so the mask is kept, and the doubled line is removed in the edge pass itself, so it works whichever hull P1-toon lands:
- **A dilated character mask.** A pixel is "near a character" when it, or any of 8 taps on a ring of `look_edge_mask_px` (at 1080p, scaled with the viewport height; default 6, the hull's 4.5 px bound plus air), reads roughness below 0.5, the sky counting as 1. No depth line is drawn there, and no crease just outside a character. In the first probe (symmetric 4-tap lines) the mask took the doubled rings away for both hulls and the hull-less sphere; with the pass as built (near-side lines, C1) the hull is already one run either way (see the E2 numbers below) and the mask's job is the character without a hull and the creases at its border.
- **Normal creases never cross a roughness class** (a character pixel against an environment pixel is a silhouette or a hull edge, not a crease), and are suppressed on depth discontinuities (the silhouette is the depth line's job). Inside a character (roughness below 0.5) creases are drawn: collars, brims, soles. Measured with both hulls (E2): the hull's width is the same with or without the mask. The cleaner contract, asked of P1-toon in the requests: the hull writes `ROUGHNESS` of about 0.25, a third class between the body (0) and the world (1), which the pass could then skip; today the pass works without it.
- **Fallback 2 stays reachable** as the Debug switch `look_edge_character_mask` (off = depth lines with no character skip, for a thinner hull). The slice gate locks the choice.
- **Alternative not taken: fallback 1 alone** (the hull as a lit shader writing `ROUGHNESS = 0`, `ALBEDO = 0`, `EMISSION = ink`). It needs a change in P1-toon's file, so the edge pass would be wrong until the merge; the dilated mask is mine and works with either hull, today's (no hull at all) included. The lit hull is also heavier (a lit pass per hull).

**Two more findings for P1-toon.** (1) An `ink` written as a literal inside a shader is linear: the probe's `vec3(0.07, 0.06, 0.09)` drew as a visible grey-violet (about 74/70/83 in sRGB), not near black. `HudStyle.INK` is an sRGB `Color`, so the hull and the edge pass need `uniform vec3 ink : source_color`. (2) A hull on a prop (A7: crates, car, dumpster, pipe) should be tagged like a character (the prop's own surface `ROUGHNESS` 0): a tag 1 prop wearing a hull still gets the edge pass's lines on its edges, beside the hull, which is a thicker outline there. A surface with no hull should be tagged 1, or it has no outline at all.

## C1. Depth lines draw on the nearer side, from the second difference of 1/z
- **Decision.** A pixel gets a depth line when it is nearer than the mean of its two neighbours along x or y (taps `look_edge_px` away), measured as `(w0 - (w- + w+) / 2) / w0` with `w = 1 / distance`, above `look_edge_depth_threshold`. The line is on the occluder's side of the step, `look_edge_px` wide, and a plane (the street at a grazing angle) has a zero second difference of 1/z, so it never draws.
- **Alternative not taken.** The codemap's prototype: the sum of `|depth difference| / depth` over 4 symmetric taps. It draws a band on both sides of every step (twice the width), and its threshold has to be tuned against the floor's far rows, where the depth changes by several per cent a pixel.
- **Why.** One line per silhouette, the width the tunable says, and no threshold that depends on the angle of the ground. The price: a line is on the near object's edge pixels, so it eats 1 px of the occluder.

## C2. Creases use forward differences, are gated by the depth, and never cross a roughness class
- **Decision.** `1 - dot(n, n_(+x))` and `(+y)` of the view-space normal, weighted by `1 - (the depth step's smoothstep)` so a silhouette is the depth line's alone, skipped when a tap is the sky or has no normal, and skipped when the two pixels' roughness differs by 0.5 or more.
- **Alternative not taken.** Symmetric taps (a crease line 2 px wide at 1 px taps), or normals everywhere including across a character's border. A 1 px line needs forward differences; the class rule stops the hull's inner border from getting a line (with the unshaded hull the body is 0 and the hull 1).

## C3. Integer pixel widths, `texelFetch`
- **Decision.** Taps are integer offsets (`max(1, round(look_edge_px * VIEWPORT_SIZE.y / 1080))`) read with `texelFetch`.
- **Alternative not taken.** Fractional UV offsets with a nearest sampler: a width of 1.25 lands on the same or the next texel depending on the pixel, and the line flickers along an edge. The cost is that `look_edge_px` is quantized (1.0 to 1.4 draws 1 px at 1080p; the slider is for a bigger screen and for the A/B).

## C4. The grade is a recipe, a strip PNG and a runtime strength
- **Decision.** `assets/source/look/grade.json` (the recipe) -> `tools/gen_lut.gd` -> `grade_lut.png` (32 slices), a `ImageTexture3D` built by `LookPost`; `look_grade_strength` rebuilds the texture from the identity and the graded bytes (about 100 k byte operations, only when the slider moves).
- **Alternatives not taken.** (a) A 1D `Texture1D` curve per channel: it cannot desaturate by the color's own saturation, which is what keeps the enemies and the blood and mutes the street. (b) A 64-slice LUT: the strength rebuild would take 8 times longer for a 1.5 per cent gain in precision. (c) A `adjustment_saturation` slider on the Environment for the muting: it desaturates the enemies too.
- **Measured and fixed.** The LUT is applied after tonemapping, in sRGB (an identity-ish probe in a linear-tonemap scene: the picture's colors matched the CPU recipe, dE76 under 1 after the fix). The renderer samples the 3D texture at the picture's color itself, so a node at `i / (N - 1)` made the picture contrastier by up to 1.5%; nodes at `(i + 0.5) / N` with black and white pinned at the ends make it exact in the middle (`node_value()`).
- **Numbers.** dE76 of the grade on the saturated palette: blood #d0141f 3.7, #e8302a 3.0, #ff4a2e 2.1, the Punk's teal 1.4, yellow 1.7, the others under 1.5; the street's wall 2.4, the road paint 4.0; white and black 0. A test holds the saturated enemy and player paints and the blood colors to `keep_delta_e` (6).

## C5. AA mode on the viewport, restored on exit
- **Decision.** `look_aa_mode` sets `msaa_3d` and `screen_space_aa` of the viewport the LookPost is in, and gives them back when it leaves the tree if nobody changed them since.
- **Alternative not taken.** Writing project.godot (A8: untouched) or never restoring (a test that picks FXAA would leave the root viewport on it).

## C6. The depth-only fallback is a `#define` on the same source
- **Decision.** `LookPost.depth_only_shader()` prepends `#define EDGE_DEPTH_ONLY` to `edge_pass.gdshader`'s text; the shader wraps the normal-roughness uniform and every use in `#ifndef`, so the variant has no `hint_normal_roughness_texture` and the renderer makes no normal buffer.
- **Alternative not taken.** A second `.gdshader` file (two copies of the depth math to keep equal).

## C7. The training room keeps its own actor spawn
- **Decision.** `test_room.gd` calls RoomKit for the environment, boxes, materials and presentation, but not `RoomKit.spawn_player`, which adds an avoidance obstacle the training room never had; its dummies do not steer, but the sparring one and a spawned enemy would.
- **Alternative not taken.** Move the spawn too, for one less copy: it changes the training room's navigation behavior, and the M1 tests pin it.

## C8. The car, and only the car
- **Decision.** The car at `crowd_room.gd:326` is `Color(0.34, 0.38, 0.45)` (hue 217 degrees, saturation 0.24, value 0.45: a muted blue-grey inside the bible's street saturation of 0.30 and value 0.25 to 0.6). `test_look_post` asserts the car's saturation too.
- **Alternatives not taken.** (a) Mute the dumpster (0.2, 0.42, 0.3; saturation 0.52) and the crates (0.45) to the bible's 0.30 as well: A13 names the car, they are not red, and the toon environment materials F-look tunes will choose the street's saturation anyway. (b) A new export for the car's color: "colors only" for this file, and no new numbers in a room's exports.
- **Note for F-look.** The bible's environment saturation (at most 0.30) is still broken by the dumpster and the crates.

## C9. `RoomKit` boxes take an optional overlay
- **Decision.** `box_mesh`, `add_box` and `add_visual_box` take `overlay: Material = null` for the mesh's `material_overlay`. Nothing passes one yet.
- **Why.** A7 puts hulls on the crate, car and dumpster, and those boxes are made here; `crowd_room.gd` is mine for colors only, so the call site (`_build_props`) belongs to whoever lands the hull (P1-toon's outline factory, SL-int's wiring): one line there, no RoomKit edit. See the requests.

## C10. The probe's thresholds are measured
- **Decision.** `look_probe.gd` counts a pixel as ink below a luma of 0.2: the edge line renders as (27, 24, 31) of 255 and a fogged hull as about (34, 29, 33), through the tonemapper, the fog and the grade, against the HUD's own (18, 15, 23); the darkest wall is 0.28.
- **Open.** The 3D ink is lighter than the HUD's by about 10 to 16 levels (filmic tonemap's toe, fog on an unshaded hull, the cool shadow tint of the grade). The edge pass has `fog_disabled`; the hull's fog and the tonemap are P1-toon's and F-look's to judge.

## Measurements of this package's own frames (recorded 1600x900, M1)
E1 (`captures/e1`, not committed): edge line width 1.5 px at 1080p (1 px of the recording), 1.5% of the frame's pixels change with the edge pass, 0.0% of the HUD plate's pixels do, the grade moves the frame by a mean dE76 of 2.9, FXAA changes 3.2% of the pixels and AA off 3.0% (against the 4x MSAA picture).
E2 (the mask probe, `captures/e2`; scratch spheres tagged 0 with a hull of `look_outline_px` 3.75 at 3.2 m; widths are the dark run at the sphere's body, in 1080p pixels, the second line `edges off / mask on / mask off`):
- lit hull: 4.5 / 4.5 / 4.5. Unshaded hull: 4.5 / 4.5 / 4.5. No hull: 0.0 / 0.0 / 1.5.
- **So, with near-side depth lines, the doubled silhouette A8 feared does not appear** (the hull is 4.5 px with the mask on or off): a depth line of this pass falls on the nearer surface, and at the hull's outer edge that is the hull itself (ink on ink), at its inner edge the depths are the same. The probe's symmetric-tap lines did double (the rings of the first probe). **The mask is still what keeps a tagged character with no hull from getting a line** (0.0 with the mask, a 1.5 px line without) and keeps creases out of the ring round a character; it is cheap (it looks at its ring only for a pixel that has a line to lose) and stays the default. A hull-less placeholder that should be inked by the pass must not be tagged 0 (P1-toon's `edge_tag` rule, requests).
- The first run of this act read 3.0 / 0.0 / 4.5 for the hulls because the probe's dark threshold (0.12) was below what a fogged ink renders as: see C10.

## Perf (NOISY: the machine was shared with other builders, 1-minute load average 2.7 to 7.7)

**1. `tools/perf_compare.sh --force --runs 1 --act "Perf, six with ragdolls"` (windowed, vsync off), the commit `b639c1e` (this package before the last shader changes), one run each: the numbers mean nothing.** Every run had 61 to 112 frames of about 1.0 s (the Metal-drawable stalls of an unattended window, L0-bench's finding; the tool says so itself), which is 5 to 10% of the frames, so the means and p95 are the stalls'. The tunables went in through `--tune=` appended to the bot's arguments by a wrapper binary (`GODOT=`), since the tool has no passthrough.

| run | load at start | frames | mean ms | p95 ms | stalls | mean ms with the stalls taken out (1.03 s each, an estimate) |
| --- | --- | --- | --- | --- | --- | --- |
| main afdb39e | 7.7 | 1603 | 70.9 | 998.8 | 93 | 11.9 |
| M4 head, default look (edges, 4x MSAA, grade) | 3.8 | 1100 | 101.7 | 1023.4 | 92 | 16.9 |
| edges off | 3.6 | 1861 | 46.1 | 30.8 | 61 | 12.7 |
| FXAA | 4.1 | 1393 | 77.7 | 1015.9 | 87 | 14.2 |
| AA off | 4.6 | 1414 | 78.8 | 1014.3 | 91 | 13.4 |
| depth-only edges | 5.4 | 1135 | 114.5 | 1024.8 | 112 | 14.2 |

The last column is the only one worth a glance, and it is an estimate on top of a contaminated run (the stall length varies by a few per cent, which is a second or two of the 17). **The lead's quiet-machine run is the one that counts**; it should use `--vsync on` or a window in front if the stalls come back.

**2. A better instrument, for the same question: one process, the six configurations interleaved (240 frames each, three cycles, a 30-frame warm-up after every switch), frames of 100 ms or more dropped (527 of about 3,700: the stalls).** The crowd room, 1600x900, six frozen primitive Punks 2 to 4 m ahead, vsync off (`--disable-vsync`), the M1, load average 2.7 to 3.1, the head with the lazy mask. Scratch script, not committed.

| configuration | mean ms | p95 ms |
| --- | --- | --- |
| all on (4x MSAA, edges, the mask, the grade) | 13.96 | 19.34 |
| edges off (4x MSAA) | 10.83 | 14.88 |
| edges on, character mask off | 13.70 | 19.47 |
| edges on, depth-only | 13.30 | 18.56 |
| FXAA, edges on | 11.17 | 15.22 |
| FXAA, edges off | 9.15 | 13.93 |

- **The edge pass costs about 3.1 ms at 4x MSAA and about 2.0 ms with FXAA**; most of it is the renderer making and resolving the depth and normal-roughness buffers (the codemap's finding), not the shader's taps. The mask is about 0.3 ms, the depth-only variant saves about 0.7 ms, and **FXAA instead of 4x MSAA saves about 2.8 ms with the edges on** (1.7 with them off): the Mac fallback that keeps the lines.
- An earlier run of the same script, before the mask was made lazy, read all on 14.72, edges off 11.00, FXAA 11.83, AA off 11.06, depth-only 13.52, no mask 13.65 and grade-and-edges-off 10.75: the grade costs about 0.25 ms.
- With the placeholder hulls and the toon shader not in this tree the numbers are the edge pass's alone; the hulls and toon materials add to them (P1-toon, the lead's A16 run).
- The RTX 3060 is not measured.

## Requests (files I do not own)
See the package's final message; they are repeated in HANDOFF by the lead. In short: (1) P1-toon: the tag and ink rules of the A8 section above and "Measurements"; (2) SL-int or P1-toon: pass the prop hull to `RoomKit.add_box(..., overlay)` for the crowd room's crates, car and dumpster (`crowd_room.gd:_build_props`, which I may edit for colors only) and the training room's three crates; (3) SL-int: rerun e2 (`Look: edge mask probe`) after P1-toon merges, with the real hulls; (4) the lead: rerun `tools/gen_lut.gd` after any recipe change, regenerate the preset, and run `perf_compare.sh` on a quiet machine.

## Evidence and tests (final)
- **Suite:** `tools/run_tests.sh`, 57 scripts, 1266 tests, 1266 passing, 0 `SCRIPT ERROR` / `SHADER ERROR` / `ERROR` (the base was 1216; `tests/test_look_post.gd` adds 38, L0-bench's and the others the rest). The one existing assertion that needed attention was M4-contracts' "every Look tunable is documented": `look_edge_fade_end_m` got its own `##` line; no assertion was changed or weakened.
- **Recordings read** (`captures/`, not committed; before pack `captures/m4_before/` of the main checkout):
  - C2 `Look: Punk body at 1 m`, C7 `Look: lineup`, C9 `Look: street tour`, each re-recorded one act per process and paired with the before still at the same label: ink lines on the buildings' silhouettes and corners, the crates, the dumpster, the curb and floor edges, the road paint, and every primitive character's silhouette, arms, wraps and cap in first person; the street a little cooler and greyer, the Punk teal and yellow, the Thug and Kicker greens and the Bruiser purple unchanged; the HP plate, the crosshair untouched; no errors in any log.
  - E1 `Look: edge pass and grade` (everything on, edges off, grade off, both off, FXAA, AA off, depth-only, the car) and E2 `Look: edge mask probe` (the hull and the mask states, the four debug views): the numbers above; the car reads as a muted blue-grey with ink on its edges, no red anywhere in the street.
  - The training room through `combo_bot` ("P P P P"): lines on its buildings, the dummy and the player's own arms; the KAPOW burst, the speed lines and the blood splat draw over the lines (the quad is at -127), the HUD is untouched.
- **What the sheets show, honestly:** thin geometry (the street's windows, 1.5 cm boxes) draws dashed creases; 1 px lines step on the curved silhouettes of the primitive Punk (4x MSAA does not smooth post lines; FXAA smooths them and fades them). Both are in the "Known artefacts" of ARCHITECTURE for F-look.
