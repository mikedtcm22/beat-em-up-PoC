# M6 playtest feedback: packages FB-FEEL, FB-GROUND and FB-DETAIL

Game-boy played the M6 build (PR #6, `m6/full-art-audio` at `663cafc`) on 2026-11-05 and said this, word for word:

> Things to fix:
>
> * the ground in the first few areas doesn't seem to have a clear texture and blinks/flashes constantly.  I don't know it that's trying & failing to create shadows or what, but try to get it it so it looks like a comic book texture of some kind instead of a glitchy computer-scape
> * Lose the victory-sound on the "go" sections.
> * Player PoV should shake/react a bit more when he's being hit.  I got knocked down to almost half-health without even realizing anything was happening to my character.
> * I'd like you to take a pass at upscaling the detail of each of the enemy characters, so that they look closer to the concept art you originally provided for each.  These ones look a bit too "blobby."  Probably the worst offender is the "Bruiser" character, but all of them need an upscale in the detail department.

All four are his rulings. Build them as the packages below say. Where one departs from SPEC, keep the spec's value reachable (a switch or a config) and list it in your departures: the lead writes README's "ruled by Game-boy at his M6 playtest" section.

This round is phase 1: three builders at once. FB-DETAIL is a **pilot on the Bruiser**. Its recipe then rolls out to the Kicker, the Pipe Thug, Ox Pellerin and the Punk in phase 2, each by its own builder, so it must say exactly what each rollout changes.

The lead's "before" recording of the street (the "Perf: level walk" act, god mode, autopilot through street A1-A3 and the roofs) is in `captures/m6-feedback/before/walk/` (bot.avi, bot.log, sheets/). The lead's look at the M6 lineup is `captures/m6-final/lineup/sheets/c7/stills/c7_f49_lineup_t000.png` (Punk, Kicker, Thug, Bruiser at 2.5 m) and `captures/m6-final/heavies/sheets/h1/stills/h1_f109_d2_5_m.png` (Punk, Bruiser, Ox).

## File ownership

| Package | Owns |
| --- | --- |
| FB-FEEL | `game/camera/first_person_camera.gd`; `game/audio/audio_director.gd` (the `arena_cleared` sting only); `game/audio/rumble_director.gd` (only if you change the hurt rumble); `game/ui/` (a new hurt overlay; `hud.gd`, `hud.tscn` and `player_health_panel.gd` for wiring it and a panel jolt); a new `tests/test_m6_feedback_feel.gd`; a new hurt act in `tests/bot/acts/` (its own file); Tuning's new "Hit feel > Hurt" subgroup and Debug lines |
| FB-GROUND | `tools/gen_trim.gd` and the trim sheet it writes (and its ASSETS.md row); `game/fx/trim_body.gdshaderinc`, `trim.gdshader`, `trim_scissor.gdshader`; `game/fx/toon_materials.gd` (the trim functions only); `game/level/kit/art/kit_mesh.gd` and `trim_sheet.gd`; `game/level/room_kit.gd` (the sun's shadow settings, only if the cause is there); the kit's tests; a new `tests/test_m6_feedback_ground.gd`; a new act in `tests/bot/level_acts/` (its own file); Tuning's new "Level > Ground" subgroup and Debug lines. The mission scenes only if a geometry overlap is the cause, and then only the overlapping nodes |
| FB-DETAIL | `tools/pipeline/*` (new behaviour behind config keys, see below); `assets/source/characters/bruiser/**`, `assets/export/characters/bruiser/**`, the Bruiser's palette JSON and roster entry; the Bruiser's parts of `tests/test_art_heavies.gd` and his ratchet rows; the Bruiser's ASSETS.md row; a new `tests/test_m6_feedback_detail.gd` |

- **Shared files:**
  - In `tuning_data.gd`, each package uses its own subgroup, and Debug lines are appended.
  - In `tuning/default.json`, the palette atlas and the ratchet JSON, the lead regenerates on merge, so conflicts there are fine.
- **ARCHITECTURE.md:** fill only your own heading, `### Playtest feedback: <your key>`, at the end of "## Full art and audio (Milestone 6)".
- **Calls:** write them to `docs/milestones/M6-calls/<your key>.md`.

## FB-FEEL: the GO sting, and feeling the hits you take

### Item 1: no sting on GO
- **What happens now.** `AudioDirector._on_arena_cleared()` plays `sting_go` (`Tuning.data.sting_go_db`) whenever an arena's table finishes and the GO cue shows. Game-boy calls it the "victory sound" on the go sections. Remove it.
- **What to build:**
  - A Debug switch `audio_sting_go` (bool, default **false**) gates that one call. On gives M6's sting back.
  - The `sting_clear` on `level_cleared` (the "CLEAR!" after the boss) stays as it is.
  - The audition room still lists and plays `sting_go`, so it can be auditioned.
  - The pool and its files stay. Check the M6 placeholder inventory still counts it as final art, not as unused.
- **Test:** clearing an arena plays no sting by default and plays `sting_go` with the switch on, and the level clear still plays `sting_clear`.

### Item 2: the player feels each hit
- **What happens now** (`game/camera/first_person_camera.gd`, `_on_hit_landed`): the player gets the same trauma (`Tuning.data.shake(tier)`, SPEC §6: 0.1 / 0.25 / 0.5) and the same camera punch (`cam_punch_deg(tier)`: 0.5° / 1.5° / 3°) whether he lands the hit or takes it. The view only kicks the way the push goes (`_away`).
  - A Punk's jab is a light hit: 0.1 trauma, which shakes at 0.01 (trauma squared), and a 0.5° kick.
  - So taking several hits reads like nothing.
  - The HP bar's ghost and flash (`health_gauge.gd`) and the player's grunt are all there is.
- **What to build.** It's presentation only: subscribe to `CombatEvents` and read state, never write game state. Work through the stack below while the player is the victim, judging from first-person recordings, until a light hit is unmistakable and a finisher rocks the view. It must never be nauseating, and it must never hide the enemy who hit you.
  1. **Shake and punch scales while the victim:**
     - `hurt_shake_mult` (start about 2.5) and `hurt_punch_mult` (start about 2.5) multiply the tier's values.
     - A floor, `hurt_shake_min`, makes a light hit add at least about 0.3 trauma.
     - SPEC §6's table still holds for the hits he lands.
  2. **A head snap with roll:**
     - The view rolls away from the hit's side, by `hurt_roll_deg` per tier (start about 2 / 4 / 7°).
     - It uses the same snap-and-settle envelope as the punch.
     - A hit from straight ahead tips the head back (pitch up).
  3. **A hurt overlay** (a new `game/ui/` node, drawn under the HUD's panels):
     - an edge vignette that pulses on each hit taken, strongest on the side the hit came from (the contact point against the view);
     - its size scales with the damage (a tunable), and it fades over about 0.3-0.5 s.
     - **Its colour is not red by default:** SPEC's style rule reserves red for blood, the rear-attack warning and finisher accents. Start from the ink colour, near-black and translucent, or a white comic "impact" rim; pick from the recordings and log the call.
     - Keep a colour tunable, so red is one change away for Game-boy's ruling.
     - Optionally, a few comic impact strokes at that edge.
  4. **An HP panel jolt:** the panel shakes for about 0.2 s on damage, in proportion to the damage (in `player_health_panel.gd`, a tunable).
  5. **Blocked hits:** keep today's `blocked_feel_scale`. No vignette, or a much lighter one, so blocking still reads as safe.
- **Switches:** `hurt_feel_enabled` (Debug, default true) turns items 1-4 off together and gives M6's view back.
- **Tuning:** put every number in a "Hit feel > Hurt" subgroup, with `##` docs and `@export_range`.
- **Recording:**
  - Add an act "Look: player hurt": god mode, a Punk, a Kicker and a Bruiser each land a light, a heavy and a finisher on the standing player, from the front, the left and behind. Use the existing combo or crowd bot hooks.
  - Record it before (switch off) and after.
  - Contact sheets at 12 fps around each hit show the shake, the roll and the overlay.
- **Tests:**
  - victim and attacker get different trauma;
  - the roll's sign follows the hit's side;
  - the overlay's strength follows the damage, and its side follows the contact;
  - blocked hits stay light;
  - the switch restores M6.
- **Departure:** SPEC §6 gives one camera stack for every hit. The victim's larger stack is Game-boy's ruling, so list it.

## FB-GROUND: a comic-book ground that holds still

- **What happens now.** The street's floor blocks (`look = &"floor"` in `game/level/mission1/street.tscn`: Floor, DoorFloor*, WarehouseFloor, AlleyFloor*, LotFloor*, BeyondFloor) draw the trim sheet's `asphalt` strip on top (`KitMesh`, `kind = &"floor"`).
  - `tools/gen_trim.gd`'s `_strip_asphalt()` paints a soft mottle (`_mottled(..., 32, 0.5, 0.07)`) with three cracks of **single-texel ink pixels** (`_ink_px`).
  - The sheet is 2048 px over `kit_trim_m_per_tile` (4 m), so one texel is about 2 mm.
  - The trim shader inks wherever the sheet's alpha passes `ink_cut`, with a `fwidth` edge.
  - It caps the mip level at `lod_cap` (4: at most 16 texels a pixel) by shrinking the gradients past it.
  - In the lead's recording the floor reads as a smeared grey-blue noise with no shapes, and faint lines cross it.
  - Game-boy, playing live on this Mac (Metal, M1, MSAA 2x), sees it blink and flash constantly in the first areas, and asks whether it's shadows.
- **Find the cause first, with evidence, before repainting.** Candidates, in the lead's order of suspicion:
  1. the ink cracks one texel wide plus the capped mip: they alias and crawl as the view moves;
  2. the mip cap on the mottle itself;
  3. the edge pass (`game/fx/edge_pass.gdshader`) drawing false depth or crease lines on the flat floor at grazing angles;
  4. directional-shadow shimmer or acne on the floor (sun at 35-38° elevation, `directional_shadow_max_distance` 40, `look_sun_shadow_blur`), or the section light re-applying the sun while you walk;
  5. two coplanar faces z-fighting (a floor block, a dressing piece or a decal).
- **The method:**
  - Make a short level act, "Look: ground drift": the player stands in street A1 and then A2, and the view pans and pitches slowly (about 10°/s) over the floor, and walks forward slowly.
  - Record it at 1600x900 with each suspect switched off in turn, and with `kit_draw_graybox` as the control.
  - Measure the flicker in numbers. For example: on a still view, the frame-to-frame difference of the floor's pixels; on a sub-pixel drift, the high-frequency energy that changes from frame to frame. Don't judge it by eye alone.
  - Also look at a 4-6 frame strip at full resolution.
  - The calls file gets a table of suspect, metric and verdict.
  - If Movie Maker can't reproduce what he describes, say so, and fix every candidate that shows any temporal instability.
- **Fix the cause** at its root (the shader, the sheet, the shadow settings or the geometry), behind a Debug switch that gives M6's behaviour back where that's practical.
- **Then make the ground read as a comic-book street** in the warm-dusk palette of the street mood (`assets/source/concepts/m6/mood_street_a.jpg`, Game-boy's pick):
  - a few broad, flat tonal shapes (2-3 values of the asphalt colour: worn patches, tar-sealed repairs, oil stains as flat dark shapes) instead of noise;
  - bold, tapered ink linework:
    - cracks that branch;
    - the outlines of patched squares;
    - manhole covers and drain grates as inked shapes (a ring, a bar grate), at a sensible spacing for 12 m of street;
  - every feature at least about 4-6 texels wide, so it survives the mips;
  - optional: a large-scale stipple or hatch that stays legible at 10 m and fades out before it can alias.
  - The `concrete`, `kerb` and `slab` strips that sidewalks and lots use get the same treatment, so the street reads as one drawn place.
  - The roofs' drop floors reuse the asphalt, so check the roofs too.
  - The ink must not shimmer at any distance: let the mips run, or fade the ink by footprint, and log which.
- **Constraints:**
  - `KitMesh.MAX_TRIANGLES`, the colliders (M5's values; `tests/test_m6_colliders.gd`) and the frame time: the level walk must not get slower.
  - Run `tools/perf_compare.sh --force --vsync on --bot res://tests/bot/perf_level_bot.tscn --act "Perf: level walk" --runs 2 663cafc HEAD` once at the end, and report it.
  - `gen_trim.gd --check` must rebuild the sheet to its new hash.
- **Recording:** before and after of "Look: ground drift" and of the arena tour ("Look: arena tour") street poses, plus a 6-frame strip of the drift at full resolution, before and after.
- **Tests:** the sheet's features have at least the minimum width (scan the alpha), the trim material's mip behaviour, the switch, and the colliders unchanged.

## FB-DETAIL: the Bruiser pilot (the recipe for every enemy)

- **What happens now:**
  - The raw Tripo model holds most of concept A's detail (`assets/source/characters/bruiser/tripo/89f460d0_preview.webp`): the quilted jacket, separate chest plates, the visor and mask, the belt, forearm guards, knee pads and boot caps.
  - In game (the lead's stills above) the Bruiser is a blob: pale steel blotches with purple bleeding onto the plates, almost no interior ink, a visor that reads as a black bar, and no quilting or plate edges.
  - The Kicker and the Thug have the same problem (flat lime and olive with few interior lines). The M4 Punk reads best of all, and his pipeline config has 7 hand-tuned ink zones, against the Bruiser's 1 and Ox's 0.
  - The chain (`assets/source/characters/bruiser/pipeline.json`, `tools/pipeline/run.py`): Tripo multiview at v3.1 (`texture_quality` standard, `face_limit` 20000) and the auto-rig, the headless Blender fit (girth clamps), then the palette (`mode` fixed, per-face swatches, majority passes, border relax, `budget_tris` 15000).
  - Then `detail_bake`: ink from the Tripo texture's edges, `ink_low` 0.04 / `ink_high` 0.11, one plates zone. Then `export.smooth_normals` (12 iterations, crease 50°).
- **Step 1: attribute the loss.**
  - Render the Bruiser at the same front and three-quarter camera at each stage: the raw Tripo GLB, after the fit, after decimation, after the palette, after the detail bake, after the normals, and in game.
  - Use the headless Blender scripts (`blender_stills.py`, `blender_closeup.py`), then a Godot still.
  - Lay them out beside the concept (`assets/source/concepts/m6/bruiser_a.jpg`) in one sheet.
  - Write in the calls file which stage loses which detail.
- **Step 2: the levers.** Take them roughly cheapest first, and judge each from 1 m, 2.5 m and 5 m first-person stills beside the concept:
  1. **Swatch borders that follow the model:** assign the palette from the Tripo texture at texel level (the detail UV is already there, `detail_uv` true), or straighten face-swatch borders along the texture's colour edges, so steel is steel and purple stops at the plate's edge.
  2. **Interior ink:**
     - more lines from the Tripo texture's edges and from geometric creases (plate edges, the visor slit, the jacket's quilting seams, the belt, the guards' straps), per zone, as the Punk's 7 zones do;
     - tuned so the lines read at 2.5 m and don't speckle at 5 m.
  3. **Normals:** keep hard creases on the plates, the visor and the guards (less smoothing, or a lower crease angle per zone), so the toon bands break at their edges.
  4. **Triangles:**
     - first get more out of 15k: decimate preserving the palette and crease borders (planar dissolve on the plates, weighted to silhouettes);
     - only if 15k still visibly blurs the shapes, raise the Bruiser to at most 25k.
     - SPEC §10's enemy row says 15k, so that's a departure for Game-boy's ruling. Keep the 15k build one config value away, and measure the crowd room ("Perf, six with ragdolls") before and after.
  5. **Tripo only if the raw model is the limit.** One regeneration with `geometry_quality` detailed (and `texture_quality` detailed), then its rig, costs about 85 credits.
     - Your ceiling is 85. The M6 stop is 900, of which 545 are spent; the floor is 700.
     - Go through `tools/pipeline/tripo.py` with `--label FB-DETAIL-...` and `--spend`.
     - Expect not to need it.
  - **Gemini:** at most 4 images, only if a view must be redrawn.
- **Rules for the pipeline code:**
  - Every new behaviour sits behind a pipeline-config key whose default is today's behaviour. Every other character's `run.py --check` must still rebuild to its committed hash (run them all).
  - The Bruiser's own `--check` rebuilds to his new hash.
  - His fit, hit shapes and hurtboxes don't change: the girth clamps and `tests/test_m6_colliders.gd` hold.
  - His strain and A6 ratchets may move only with a logged old → new.
- **Hand over the recipe.** The calls file ends with a section "Rollout recipe":
  - each config key changed, with the Bruiser's value and how to choose it for another character;
  - each new script step, the order to run them in, and what to look at;
  - the per-character time it took;
  - what to expect for a character whose raw Tripo model is thinner.
  - The phase 2 builders for the Kicker, the Thug, Ox and the Punk follow it and touch only their own character's files.
- **Recording:**
  - The heavies look act ("Look: heavies beside a Punk", `tests/bot/acts/heavies_acts.gd`) and the lineup act ("Look: lineup") before and after.
  - Plus the stage sheet, and an A/B still at 1 m, 2.5 m and 5 m beside the concept, in `captures/fb-detail/` in your worktree.
  - The lead sends Game-boy that A/B still.
- **Tests:**
  - the Bruiser's triangle count against his budget;
  - his swatch set is unchanged (6, 14, 44, 45, 46 plus anything you add, logged);
  - the steel swatch's share of the chest plates' faces (a mask from the concept zones);
  - his interior ink texels in the plate and jacket zones, above a floor that the old export fails;
  - every other character's `--check`.

## Done when (each package)
- **Built and checked:**
  - the package is built as above, with before and after first-person recordings you looked at;
  - `tools/run_tests.sh` passes in full, with no SCRIPT ERROR, SHADER ERROR or ERROR lines;
  - after any Tuning change, `tuning/default.json` is regenerated.
- **Written up:**
  - the calls file, with each call and an alternative not taken;
  - your ARCHITECTURE heading;
  - your departures listed in the result.
- **Committed:** the final commit is `M6 <KEY>: ...`, and the branch is pushed. The lead merges into `m6/full-art-audio`.
