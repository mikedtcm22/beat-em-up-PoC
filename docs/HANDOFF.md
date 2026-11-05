# Handoff: live status

Update this file at every phase boundary and before every usage limit (see CLAUDE.md, "Handoff protocol"). The newest state goes at the top of "Status".

## Status (newest first)

### 2026-11-05 14:35 CST: the fix wave merged (2027/2027); frame time running; a verification round next
- **Merged into `m6/full-art-audio`** (head `d582d21`, pushed), with no conflicts:
  - FIX-FEEL (`f32acc8`);
  - FIX-WORLD (`33ca985`);
  - FIX-ART-A (`f837a44`);
  - FIX-ART-B (`0c1c1ac`).
  - The preset is unchanged after the regeneration (FIX-FEEL wrote its 15 values). The atlas is current; every `run.py --check`, `player_run.py --asset player --check` and `gen_trim --check` is YES.
  - Suite 2027/2027 in 414 s with `ART_PUNK_VARIANT_STRAIN=1`, 0 error lines, the same 3 expected warnings.
  - No paid service spent in the wave.
- **What each did** (calls in `docs/milestones/M6-calls/FIX-*.md`):
  - **FIX-FEEL:**
    - the hurt bearing comes from the attacker's position, with `-hit.direction` as the fallback;
    - 15 shape numbers moved into Hit feel > Hurt;
    - six real-hit tests; with the old bearing put back, five fail;
    - `look_hurt_acts.gd` hits from four sides, plus the acts "finishers" (a synthetic FINISHER-tier hit, since no enemy move is FINISHER), "blocked" and "burst".
  - **FIX-WORLD:**
    - the BossRoof Ground's top is at -0.25, clear of the skyline strips at -0.5;
    - `tests/m6_coplanar_scan.gd` found 85 more wall-top and corner pairs, fixed by `InsetBlock` (the drawn mesh 2 cm in, the collider unchanged) on 41 blocks;
    - a calmer, paler ground tile, mirrored to a 16 m repeat;
    - the strip ink fade by the mean footprint.
    - Its A1 drift rose a little (still 0.0165 -> 0.0291), against M6's 5.1.
  - **FIX-ART-A:**
    - the Thug's `face_right` and `bandana_right` regions (only from slot 40), a `hood_neck` zone (creases only above z 1.35) and a plain waist;
    - the Kicker's `eyes` region and plain eyes and mask zones;
    - `_rolled_out` needs `detail_bake.crease`.
  - **FIX-ART-B:**
    - Ox's `face_lock` region (slots 7 and 53; 50 turned the hood lining tan) and `face_skin` at ink 0.012 / 0.03. The mauve patches are the toon shadow band, not slot 53: answered, not fixed.
    - The Bruiser's `visor` zone and `under_visor` region, and slot 47 `bruiser_helmet` (purple, blood false).
    - The Punk's vest valleys: `min_chain_m` 0.45 -> 0.6 (the brief said 0.55), `valley_deg` 18.
    - The Bruiser's strain fixture regenerated (held clip min 0.1489 -> 0.088).
- **The lead's look** (the fixers' stills):
  - the hurt edge matches the side for the Bruiser smash from all four sides;
  - the ground is calmer and opener;
  - the Thug's half-face and the Bruiser's cream wedge are gone;
  - Ox has a nose, a mouth corner and a jaw line;
  - the Kicker's eyes are a plain skin band, calmer but no longer shades.
- **README:** "After Game-boy's playtest (2026-11-05)" is under the M6 status (uncommitted until the verification round).
- **Running:** `tools/perf_compare.sh --force --vsync on --runs 4 --bot res://tests/bot/perf_level_bot.tscn --act "Perf: level walk" --act "Perf: counters" --out captures/m6-feedback-fix/perf 910448e 663cafc HEAD`.
  - It runs at load 3.5-4, from Game-boy's own apps (App Store agent, ChatGPT), so it has to be forced, as M6's numbers were.
  - **If cut off:** rerun it.
- **Next:**
  1. Record the verification acts on `d582d21`, after perf so the machine stays quiet: `bash <scratchpad>/record_verify.sh`, the review round's 18 acts into `captures/m6-feedback-verify/` (the script is `record_feedback.sh` with the folder changed and dp2/dp3 dropped).
  2. A verification round: `review.js` with `docs/reviews/M6/args-review-verify.json` (chars and world on Opus, code on Sonnet, skeptics on highs and mediums, `partition` false). Independent reviewers check each finding the wave took, against before (`captures/m6-feedback-review/`) and after.
  3. If anything survives, one small fix pass; then README's frame-time lines, PR #6's body, and the DM with the stills and the run command. Merge only on his word.

### 2026-11-05 13:15 CST: the FEEDBACK review done (2 high, 5 medium survive); the fix wave running (FIX-FEEL, FIX-WORLD, FIX-ART-A, FIX-ART-B)
- **The review** (run `wf_17f7b1df-712`; every finding with detail, fix and verdict in `docs/reviews/M6/findings-feedback.json`):
  - **Passes:**
    - all five enemies are closer to their concepts than M6 at 2.5-3 m;
    - no crawl in motion: the fight with the per-texel swatches on against off, with identical logs, gave the same change, 557,975,304 against 557,975,210 pixels;
    - one line weight across the roster;
    - the veteran reads at 5 m;
    - the street ground holds still (the lead's drift: 0.017 / 0.039 against M6's 5.1).
  - **Highs (confirmed by the lead in the code):**
    - **world-01:** the hurt cue's bearing comes from the contact point on the player's own hurtbox, so its edge and roll are near random;
    - **world-02:** FB-GROUND's lowered boss-roof Ground (top -0.5) is coplanar with the roofs' skyline walk strips, a new z-fight in the gap view.
  - **Mediums:**
    - **chars-01:** the Thug's black half-face (slot 40, no blood);
    - **chars-02:** the Thug's chest valley scribble;
    - **chars-03:** Ox's grey slot-53 face blotches, which take cloth damage;
    - **world-03:** no recording of a finisher, a blocked hit or a burst landing;
    - **code-01:** the hurt shape numbers are script literals.
  - **Lows the lead took:**
    - the Kicker's eyes and mask slashes;
    - the Bruiser's visor stripes, and his purple helmet now bleeding (a new blood-false swatch);
    - the Thug's waistband dashes;
    - the hurt constants;
    - the ground's camo-like busy-ness and its 8 m repeat (keep only if clearly closer to the mood);
    - the strip ink fading early on grazing surfaces;
    - the ASSETS rows;
    - the vacuous detail guards.
  - **Left:** the Punk's cap logo blot (as in M6), the Bruiser's cuff ovals, and Ox's sawtooth sleeve (in the texture).
- **Running:** build.js run `wf_b1184dc7-5fe` (task `wzbuqd3p9`), with `docs/reviews/M6/args-FEEDBACK-FIX.json` and brief `docs/reviews/M6/fix-feedback-final.md`. Four Sonnet fixers at once, the art pair on the two Blender slots:
  - **FIX-FEEL:** the bearing from the attacker's position, real-hit tests per side, the shape numbers into Hit feel > Hurt, and the hurt act extended with a finisher, a block, a burst, and hits from the right and behind.
  - **FIX-WORLD:** the boss Ground clear of every drawn plane, the coplanar guard over every drawn block of the level and both rooms, the ground calmer with its repeat broken, and the strip ink fade.
  - **FIX-ART-A:** the Thug and the Kicker, plus the guards' `_rolled_out` requiring the recipe key.
  - **FIX-ART-B:** Ox's face region and texture face lines, the Bruiser's visor and helmet swatch, and the Punk's vest valleys.
  - Branches `m6/fix-feel`, `m6/fix-world`, `m6/fix-art-a`, `m6/fix-art-b`. **If cut off:** rerun build.js with the same args.
- **Next:**
  1. Merge all four (the preset, `gen_palette.py` since FIX-ART-B adds a swatch, every `--check`, and the suite with `ART_PUNK_VARIANT_STRAIN=1`).
  2. The lead's look at each package's stills; re-record the boss roof gap and the hurt act if needed.
  3. Perf against `663cafc` on a quiet machine (`tools/perf_compare.sh --vsync on --runs 4 --bot res://tests/bot/perf_level_bot.tscn --act "Perf: level walk" --act "Perf: counters" 663cafc HEAD`).
  4. README's M6 status, PR #6's body, and the DM with the stills and the run command. Merge only on his word.
- **Usage at launch:** 5-hour 16%, weekly 39%.

### 2026-11-05 12:40 CST: FEEDBACK phase 2b merged (2006/2006); the review round's recordings running
- **Merged into `m6/full-art-audio`:** ROLL-KICKER (`40e03ba`), ROLL-THUG (`45f9ac0`), ROLL-PUNK (`fdb9ee0`) and OX-2 (`5d21aa3`); merge head `82bab12`, pushed.
  - **Conflicts:**
    - ARCHITECTURE.md, with every heading kept;
    - ASSETS.md, where the Thug's builder had overwritten the **Kicker's** mask row with Thug text; the lead kept the Kicker's own row.
  - Preset 631 values (unchanged), atlas current, every `run.py --check`, `player_run.py --asset player --check` and `gen_trim --check` YES.
  - Suite 2006/2006 in 407 s with `ART_PUNK_VARIANT_STRAIN=1`, 0 error lines.
  - No Tripo or Gemini spent in phase 2b: every raw model held its detail.
- **What each did** (calls in `docs/milestones/M6-calls/<KEY>.md`; A/B sheets copied to `captures/m6-feedback-3/ab/`):
  - **Kicker:** relax 0, island 0.0015, crease 60°, valleys on the vest and shorts, texel swatches, seven zones. The hood, drawstrings, zip, pocket and hem are inked now. Strain `min_min` moved 0.0367 -> 0.0183 (one edge in walk clips).
  - **Thug:** relax 0, island 0.0015, crease 60°, hoodie valleys 15° (none on the trousers, which scribbled), texel swatches, `hoodie` and `trousers` zones.
  - **Punk:** crease and valley ink, plus texel swatches. He has no island merge (it broke the cap's strap arch) and keeps relax 3 and M4's seven zones. The mesh is byte-identical and the veteran swap recolours unchanged. Shared tests loosened for his blue channel: `test_art_contract.gd` (B <= 20/255, `STROKE_PIECES_MAX` 600 -> 800) and `test_toon_glint.gd`.
  - **OX-2:** texel swatches, lines 0.0035/0.0025, robe valleys 12°, and the region `legs_not_skin`, which repaints the tan streak down his tights. `test_art_heavies.gd`'s region filter is narrowed to glove regions.
- **The lead's look:**
  - **The Kicker** is a clear win.
  - **The Thug** has two regressions:
    - a hard black patch over the right half of his face and bandana at 1 m (a dark texture patch the texel borders now show sharply);
    - valley scribbles across his chest.
  - **The Punk** changed only a little.
  - **Ox** is modest: cleaner trim, the leg streak gone, but his face is still a flat tan shape at 1 m.
- **Recorded** (all 20 acts `exit=0 errors=0`) into `captures/m6-feedback-review/`. The lead's look: the ground's still-view change is 0.017 / 0.039 grey levels at A1 / A2 (M6 5.1), and the walk reads as one steady comic street.
- **Running:** review.js run `wf_17f7b1df-712` (task `wnmelu5xp`) with `docs/reviews/M6/args-review-feedback.json`. **If cut off:** rerun it with `resumeFromRunId`, or with `reviews`/`verdicts` from the journal.
- **The recordings** (for reference; the script was `<scratchpad>/record_feedback.sh`):
  - **crowd lane:** r_kicker, r_thug, r_bruiser, r_boss, lineup, heavies, dj, dk, dt, dp1, dp2, dp3, dox, damage, hurt, fight;
  - **level lane:** drift, tour, walk (perf_level_bot), run_street (arenas 0-2).
  - **If cut off:** the script is lost with the scratchpad. Rerun the same `tools/record_acts.sh` lines (the act list is in `args-review-feedback.json`'s common note).
- **Next:**
  1. When the recordings are done (check each `exit=0 errors=0` line), run `tools/workflows/review.js` with `docs/reviews/M6/args-review-feedback.json`: lenses chars and world (Opus), code (Sonnet), skeptics on highs and mediums, `partition: false`.
  2. The lead partitions the survivors, plus the Thug's face and chest, the Punk's vest valleys and Ox's face, into at most 3 fix packages. One fix wave.
  3. The suite, and perf against `663cafc` on a quiet machine.
  4. README's M6 status (the ground, the detail), PR #6's body, and the DM with the stills and the run command. Merge only on his word.
- **Usage:** 5-hour 9%, weekly 38%. Phase 2b's four builders took 55 min.

### 2026-11-05 11:25 CST: FEEDBACK phase 2a merged (1983/1983); stills sent; phase 2b building (Kicker, Thug, Punk, Ox opt-in)
- **Merged into `m6/full-art-audio`:**
  - DETAIL-2 (branch `m6/detail-2`, `dff8d47`) and ROLL-OX (`m6/roll-ox`, `426e820`); merge head `8bf750f`.
  - The only conflict was ARCHITECTURE.md, with both headings kept.
  - Preset 631 values, atlas current, every character's `run.py --check` and `player_run.py --asset player --check` YES.
  - Suite 1983/1983 in 389 s, 0 error lines.
  - Then `b454424`: the detail guards in `tests/test_m6_feedback_detail.gd` now skip any character that has its own `tests/test_m6_feedback_detail_<id>.gd` (`_rolled_out()`), so rollouts don't edit shared lists. 13/13 alone.
- **DETAIL-2:**
  - **Texel swatches:** the mask's B carries a palette slot per texel (RGBA, alpha 128/255 is the marker); `toon.gdshader` does a `texelFetch` and fades back to the face swatch from 1 to 3 texels per pixel (Look > Toon `look_texel_swatch_fade_near/far`; Debug `look_texel_swatch`).
  - **Valley ink** on the cloth (`crease.valley`, zone `valley_deg`); lines 7.8 mm; the helmet painted purple by regions.
  - **20k bought nothing visible**, so 15k ships and there's no ruling to ask.
  - **The quilting is folds only:** the mesh has no stitching.
  - **Not checked:** the texel fade in motion at 5-10 m, and perf on a quiet machine (+0.11 ms mean on a loaded one).
  - The recipe's part 2 is in DETAIL-2.md.
- **ROLL-OX:**
  - config only: relax 0, island 0.0004 (0.002 ate the laces), crease 70°, and seven ink zones;
  - no Tripo (the raw model holds the detail);
  - two ratchets moved (strain `min_min` 0.028 -> 0.016 in one floored-pose edge, A6 legs 0.95 -> 0.949).
- **The lead's look:**
  - **The Bruiser** at 2.5 m reads as armour with clean borders.
  - **Ox** is cleaner but modest. His orange trim still steps until OX-2.
  - **The A/B sheet `ab_bruiser_2.png` is mislabelled** (the builder didn't read it back), so the 20k sheet went to Game-boy instead.
  - Captures are copied to `captures/m6-feedback-2/{detail-2,roll-ox}/`.
- **Sent to Game-boy:** `bruiser_15k_20k.jpg` and `ox_ab.jpg`, the plan for phase 2b, and the run command. Nothing is waiting on him from this round. Still unanswered from M6: the near-arm keep/off and the frame-time accept-or-lever.
- **Running:** build.js run `wf_11fac342-cd2` (task `w1b8z5qea`), with `docs/reviews/M6/args-FEEDBACK-3.json` and brief `docs/reviews/M6/fix-feedback-3.md`.
  - Four builders on the two Blender slots, so two waves: ROLL-KICKER and ROLL-THUG (Tripo 85 each, only if the model is flat), then ROLL-PUNK (veteran swap and the M4 variants guarded; no Tripo) and OX-2 (texel swatches, line weight, robe valleys).
  - The chain and `toon.gdshader` are frozen this round.
  - Branches `m6/roll-kicker`, `m6/roll-thug`, `m6/roll-punk`, `m6/ox-2`.
  - **If cut off:** rerun build.js with the same args.
- **Next:**
  1. Merge all four (preset, atlas, every `--check`, the suite).
  2. The lead's look at each `ab_<id>.png` and the lineup.
  3. One review round (chars and world/feel on Opus, code on Sonnet), one fix wave, the suite, and perf against `663cafc` on a quiet machine.
  4. README's M6 status (the ground, the detail), PR #6's body, and the DM with stills and the run command. Merge only on his word.
- **Usage at launch:** 5-hour 3% (just reset), weekly 37%. Phase 2a's two builders took 57 min.

### 2026-11-05 10:20 CST: FEEDBACK phase 1 merged (1970/1970); stills sent; phase 2a building (DETAIL-2, ROLL-OX)
- **Merged into `m6/full-art-audio`:** FB-FEEL (`a40ede2`), FB-GROUND (`3967fc9`) and FB-DETAIL (`4f2e0f3`). The only conflicts were in ARCHITECTURE.md, where all three headings were kept.
  - The preset is regenerated (629 values), the atlas is current, and `gen_trim --check` passes.
  - Suite: 1970/1970 in 391 s, with 0 error lines.
  - Pushed at `aca0c10`, which adds README's "ruled by Game-boy at his playtest (2026-11-05)" section (the hurt feel, no GO sting) and the phase 2a brief.
- **What each found and built** (calls in `docs/milestones/M6-calls/FB-*.md`; captures copied to `captures/m6-feedback/fb-*/`):
  - **FB-GROUND:** the flashing was a **z-fight**: `boss_roof.tscn`'s drawn-only 200 m Ground had its top at world y 0, the street Floor's plane. Ink, the mip cap, shadows and the section light each changed the drift metric by 0.0.
    - The Ground is now 0.5 m lower, and roofs' PenthouseFrontFloorShutter no longer draws. Both colliders are unchanged.
    - New: a comic `ground_sheet.png` (8 m world-space tile), bold ink on the strips, the "Level > Ground" tunables and `tools/ground_flicker.py`.
    - Open: it's a little busy (camo-like patches), and the manhole repeats every 8 m.
  - **FB-FEEL:**
    - `audio_sting_go` (default off);
    - the "Hit feel > Hurt" stack on the player as victim (shake ×2.5 with a 0.3 floor, punch ×2.5, a roll of 2/4/7°);
    - `HurtOverlay` (ink, with paper strokes, on the struck edge) and the HP panel jolt;
    - `hurt_feel_enabled` gives M6 back.
  - **FB-DETAIL:** the loss was the palette's border relax smearing the plate borders, plus a flat delit Tripo texture with no lines to find. It added three opt-in keys and tuned them on the Bruiser (15k kept):
    - crease ink (`detail_bake.crease`, per-zone `crease_deg`);
    - the island merge (`palette.min_island_area_m2`);
    - border relax 0.

    The rollout recipe is in FB-DETAIL.md.
- **The lead's look:** the ground and the hurt feel are good. The Bruiser is a clear step (visor frame, plate seams, buckle, guard straps) but still short of concept A:
  - the quilting reads as flat purple;
  - the colour borders are ragged face steps, with purple blotches on the steel and knee pads;
  - the lines are about 1 cm at 1 m, heavier than the Punk's.
- **Sent to Game-boy** (Slack DM, 3 files): the ground A/B, the hurt vignette, and the Bruiser A/B with the plan and the run command. He's told a 20k-versus-15k ruling for the Bruiser is coming. No ruling is pending from him yet on this round. The near-arm keep/off and the frame-time accept-or-lever are still unanswered from M6.
- **Running:** build.js run `wf_2522a6a1-11d` (task `wb0g2enm8`), with `docs/reviews/M6/args-FEEDBACK-2.json` and brief `docs/reviews/M6/fix-feedback-2.md`. Each builder holds one of the two Blender slots:
  - **`DETAIL-2`** (branch `m6/detail-2`):
    - quilt and soft-seam ink from the dense mesh's valleys;
    - colour borders that follow the texture, opt-in per art, with the damage marks following them;
    - the Punk's line weight;
    - a 20k variant's stills for Game-boy's ruling (15k ships);
    - a "Rollout recipe, part 2". No paid services.
  - **`ROLL-OX`** (branch `m6/roll-ox`): the pilot's recipe on Ox, plus the Punk's kind of texture ink zones (he has none). Tripo ceiling 85.
  - **If cut off:** rerun build.js with the same args.
- **Next:**
  1. Merge both, regenerating the preset, the atlas and the ratchet, then the suite.
  2. The lead's look. Send Game-boy `ab_bruiser_2.png`, `ab_boss.png` and the 20k question.
  3. **Phase 2b:** the Kicker, the Pipe Thug and the Punk on recipe parts 1+2, one builder each (2 Blender slots, so 2 then 1), plus Ox opting into DETAIL-2's keys. Tripo left: 355 within the stop.
  4. One review round (chars and world/feel on Opus, code on Sonnet), one fix wave, the suite and perf against `663cafc`.
  5. README's M6 status for the ground and detail, PR #6's body, and the DM. Merge only on his word.
- **Usage at launch:** 5-hour 14%, weekly 36%. Phase 1's three builders took about 10% of the 5-hour window in 70 min.

### 2026-11-05 09:30 CST: Game-boy played M6; four fixes from him; phase 1 of FEEDBACK building (FB-FEEL, FB-GROUND, FB-DETAIL)
- **His four items**, word for word in `docs/reviews/M6/fix-feedback.md`:
  1. The street's ground has no clear texture and blinks or flashes constantly. Make it a comic-book texture.
  2. Lose the victory sound on the GO sections.
  3. The player's view should react more when he's hit ("knocked down to almost half-health without even realizing").
  4. Upscale every enemy's detail toward its concept: too blobby, the Bruiser worst.
- **The lead's diagnosis:**
  - **Item 1:** the asphalt strip is a soft mottle with ink cracks one texel wide, and the trim shader caps the mip level at 4 (`lod_cap`). That's the lead suspect. The before recording is `captures/m6-feedback/before/walk/` (0 error lines).
  - **Item 2:** `sting_go` plays on `arena_cleared`.
  - **Item 3:** the player gets the same SPEC §6 shake and punch whether he lands a hit or takes it (a light hit is 0.1 trauma), and there is no overlay.
  - **Item 4:** the Bruiser's raw Tripo model already holds concept A's detail (quilting, separate plates, visor, guards). The loss is in our chain:
    - per-face swatches with ragged borders;
    - few interior ink lines (the Punk has 7 ink zones, the Bruiser 1 and Ox 0);
    - 12 iterations of normal smoothing;
    - 15k triangles (from 20k).
- **Running:** `tools/workflows/build.js`, run `wf_36bffae8-16c` (task `wwlmg4jui`), with `docs/reviews/M6/args-FEEDBACK.json`. Three Sonnet builders:
  - `FB-FEEL`: items 2 and 3, plus the act "Look: player hurt";
  - `FB-GROUND`: item 1, find the cause with numbers, then a comic ground, plus the act "Look: ground drift";
  - `FB-DETAIL`: item 4's pilot on the Bruiser, stage-by-stage attribution, the levers, and a "Rollout recipe" in its calls file. Tripo ceiling 85, Gemini 4.
  - Their worktrees are `.worktrees/m6-fb-<key>`, on branches `m6/fb-<key>`.
  - **If cut off:** rerun build.js with the same args (each builder resumes from its newest `wip:` commit).
- **Next:**
  1. Merge each package as it lands (the preset, the atlas and the ratchet), then the lead's look at its captures.
  2. Send Game-boy the Bruiser's A/B stills.
  3. Phase 2: roll the recipe out to the Kicker, the Thug, Ox and the Punk, one builder each, owning only its own character's files.
  4. One review round (chars and world/feel on Opus, code on Sonnet), one fix wave, the suite and perf.
  5. README's "ruled by Game-boy at his M6 playtest", update PR #6, and the DM with the run command.
  6. Merge only on his word.
- **Usage at launch:** 5-hour 0%, weekly 34%. The watcher `local_a81a721f` is alive.

### 2026-11-05 03:05 CST: Milestone 6 delivered; PR #6 open; waiting on Game-boy's play and sign-off
- **The perf fix is merged** (`c2b68c1`, branch `m6/fix-final-perf`). The cause was the trim shader writing `ALPHA_SCISSOR_THRESHOLD` on one branch, which made all 330 kit meshes alpha-clip: no depth prepass, and the full fragment in every shadow cascade.
  - It is now split: an opaque `trim()`, and `trim_scissor()` for the chain-link's wire alone.
  - The car, the tank and the dumpster cast their shadow from a coarser shadow-only copy (new group Level > Draw cost).
  - The bench gains renderer counters and the acts "Perf: counters" and "Perf: inventory".
  - The tour stills before and after are pixel-identical at 15 of 20 poses. The lead's look at the chain-link fence and the car confirms it.
  - The calls are in `docs/milestones/M6-calls/fix-final-perf.md`.
- **Suite:** 1936/1936 in 366 s, with 0 error lines and every ratchet key at 0. The preset is regenerated (603 values), and the atlas is current.
- **Frame time** (interleaved, vsync on, load 3-4; reports in `captures/perf_compare/20261105-022216` and `-024739`):
  - **The level walk** against 910448e: 9.43 to 10.87 ms, **+15.3%**, 0.3 points over the plan's 15% line. p95 14.16, and every soft bar is ok.
  - **"Perf: counters"**: +15.4%.
  - **Six with ragdolls** against main: +12.3%.
  - **For Game-boy:** accept it, or pick a visible lever (the costs are in the calls doc).
- **A fact-check** of README, the PR body and ARCHITECTURE (workflow `wf_d59b1d6d-d29`, 16 Sonnet agents) checked 162 claims and found 13 errors; the skeptics refuted none. All are corrected (`30191a8`):
  - the boss is 29,298 triangles, and his gloves are slot 54;
  - the arena clear times are 131/174/108 s (the "132/175/111" in the 19:15 entry are the movie lengths);
  - the voices' picks file;
  - the placeholder allow list;
  - the chain swings on the pipe's poses;
  - the held weapon is out of view in first person;
  - Gemini used 55 images in all (19 of them concepts).
- **PR #6** (https://github.com/mikedtcm22/beat-em-up-PoC/pull/6) is open, mergeable, with no CI. **Never merge it without Game-boy's sign-off.**
- **The worktrees are pruned** (all 23). Their local captures are in `captures/m6-worktrees/<name>/` (3.4 GB, never committed). Every branch is on origin.
- **Sent to Game-boy** (Slack, about 03:10): the run command, the audition keys, the PR, the judgement calls, and two open questions: keep the near arm, and accept the frame time.
- **Usage at this point:** 5-hour 7%, weekly 33%. The watcher `local_a81a721f` is alive (last active 07:49Z).
- **Next:** wait for Game-boy's play. Then act on his rulings (a FEEDBACK package as in M5, if needed), and merge only on his word.

### 2026-11-04 20:55 CST: the fix wave merged (1931/1931); perf over the bar, its fixer running; README written
- **The fix wave is merged** (`752de4e`): 1931/1931 in 376 s, 0 error lines, and the GUT warning is gone. The only conflict was the atlas, which was regenerated.
  - **art:**
    - Ox's gloves are now round, from a redrawn front view (2 Gemini images, 1 Tripo glove of 50 credits), in their own near-black slot 54 with the orange wrap.
    - The Bruiser's steel is `#7a839e`, with a plate ink zone. This one is *partial*: his chest has fewer plate edges than the concept. His strain ratchet moved slightly (logged B-1r).
    - The 1 m acts frame each head by height (`LookActs.framed_pitch_deg`).
    - The heavies test frees its director.
  - **world:**
    - The roofs' drop floors are dressed: asphalt, sidewalks, lane dashes and 11 car spots.
    - `section_fog_sky_affect` is 0.3, so the dusk sky shows.
    - The props are inside the environment band (the car is `car_wine #765a62`).
    - CratesTop's `draw_box` is off.
    - The acts settle the light before their first mark.
    - Sun yaw: street -50, roofs -60, boss -70. Elevation: 38, 36, 35.
    - LevelSection's defaults come from RoomKit.
  - **arm:**
    - The lifted arm gets its own band copy (`look_near_arm_band_1/_2/_mid_level`, Debug).
    - The hull normals bend at the cut.
    - The upper arm's stray navy and hair patches are repainted as skin.
    - Hygiene: `test_damage_look` resets Tuning; ChainSim's and AuditionRoom's numbers are tunables; the ledger test's checks are one shared helper.
  - **The lead's re-check** from the fixers' captures: the gloves read as gloves, the faces are framed, the sky shows, the drop reads as a street, and the arm is one tan limb.
  - The paid services in all: Tripo 545 of 900 (balance 1160); ElevenLabs 4,843 of 30,000; Gemini 36 images.
- **Perf** (§4 step 8; the machine was busy throughout with other apps, at load 3.4-9.2, but every comparison was interleaved):
  - **The level walk** against `910448e`: mean 12.23 to 14.61 ms (**+19.5%**), p95 16.14 to 18.82, first hit 18.3 to 23.1 ms. Over the 15% line, so it's fix item `final-perf-01`.
  - **"Perf, six with ragdolls"** against `main`: mean 14.73 to 16.60 ms (+12.7%). Within the line.
  - The reports are in `captures/perf_compare/20261104-203356` and `20261104-205011`.
- **Running:** the perf fixer, `review.js` run `wf_21d1d394-f48` (package `perf`, branch `m6/fix-final-perf`). It measures render counters first, takes back draw cost with no visible change, and warms whatever the first hit uses.
  - **If cut off:** rerun with the same args (`docs/reviews/M6/findings-final.json` now holds only the `perf` package).
- **README:** the M6 status section and its departures are written (`329b9de`). Its "Frame time" line reads `FRAME_TIME_PENDING`, to fill once perf lands. CLAUDE.md quotes M6's suite numbers.
- **Sent to Game-boy** (Slack, 21:15): the fixes, plus stills of Ox, the near arm A/B and the world. The near-arm keep/off question is still open: the arm is on by default, and `look_near_arm` gives M5's view.
- **Next:**
  1. Merge perf, then the suite and an interleaved perf run.
  2. Fill README's frame-time line.
  3. Open the PR (never merge it without sign-off).
  4. Send the DM with the run command and the audition keys.
  5. Rewrite HANDOFF's takeover prompt for M6, and prune the worktrees.

### 2026-11-04 19:45 CST: the final review done (8 survive); the fix wave running
- **The review** (`wf_9935c9e9-811`, about 25 minutes, 28 agents). The findings, verdicts and the lead's rulings are in `docs/reviews/M6/findings-final.json` (`2ec1110`).
  - **Survived:**
    - chars-01 (high): Ox's gloves read as black J-hooks curling outward. The source front view was a stretched J.
    - world-01 (high): the roofs' drop floors are undressed slabs.
    - chars-02: the 1 m acts cut off the heavies' heads.
    - chars-03: the Bruiser's steel lights to a pale "bare belly", and his plates have no ink edges.
    - chars-04: the near arm.
    - world-02: `fog_sky_affect` defaults to 1, so the dusk sky never shows.
    - world-03: the props' palette breaks the environment band, and the car's orange shares the enemies' orange.
    - world-04: a crate is drawn on the dumpster's lid.
  - **Refuted:** code-01 (the Tuning leak breaks no test), code-02 (the hero's strain ratchet is a percentile effect of the split) and code-03 (the Bruiser's bulk is the logged call H-10).
  - **Promoted by the lead from the lows:** world-05 (the acts record mid-blend; the "pale plane" was this), world-07 (the sun's yaw sweeps), world-08 (the player's shadow at a low sun), code-01, code-04 (the heavies test leaks an EnemyDirector), code-05 items 1-4 (script numbers) and code-07 (the ledger test's teeth).
  - **Left as they are:**
    - chars-05: the Thug's pipe is end-on at 1 m (M5's carry, polish).
    - chars-06: the boss's legs.
    - chars-07: ragged swatch borders.
    - world-06: the rails are straight; it's perspective.
  - **Confirmed fine:** the Thug's pipe in hand, the chain, the glint at 10 m, the OX PELLERIN bar, D6 on every no-blood swatch, the veteran at 5 m, the budgets, every `--check` rebuild, the ledgers (Tripo 495/900, ElevenLabs about 4.9k/30k), no key anywhere, and LFS.
- **Running:** the fix wave, `review.js` run `wf_6670133f-d3e` (no lenses; `findings_path` plus three packages, `fix_concurrency` 3):
  - `art`: chars-01, -02, -03, code-04 (Tripo at most 120, Gemini 8, Blender);
  - `world`: world-01, -02, -03, -04, -05, -07, -08, code-05 item 4;
  - `arm`: chars-04, code-01, code-05 items 1-3, code-07 (the hero's Blender rebuild).
  - Their worktrees are `.worktrees/m6-fix-final-<key>`, on branches `m6/fix-final-<key>`.
  - **If cut off:** rerun with the same args (each fixer resumes from its newest `wip:` commit).
- **The near arm:** Game-boy hasn't answered. The fix keeps it on by default, and the `look_near_arm` switch still gives M5's view.
- **Next:** merge the three fixes (the atlas, the preset, the ratchet, the suite). Then the re-check of the changed items (send the art and arm A/B stills), perf on a quiet machine, README, the PR, and the DM.

### 2026-11-04 19:15 CST: phase 3 recorded (19 acts, 0 errors); the final review running
- **Recorded** into `captures/m6-final/` (git-ignored): all 19 acts, with 0 error lines. The held-back runs cleared every arena: street 132 s, roofs 175 s and boss 111 s (M5: 136, 183 and 108).
- **The lead's look:**
  - The Thug holds his pipe (`props_weapons/sheets/p3/stills/p3_f284_thug_pipe.png`).
  - The chain reads, and the boss's bar reads OX PELLERIN.
  - The seams are clean.
  - One roof drop still shows a pale flat plane, and the catwalk drop is a featureless dark floor.
  - The roofs' edge-guard stanchions lean.
- **The lead's fix** `e8ebdad`: the help overlay names the sound room's keys as they read (`] [`, `1-9, 0 =`, `-`), and the long row is shortened.
- **Running:** the final review, `tools/workflows/review.js` run `wf_9935c9e9-811` with `docs/reviews/M6/args-review-final.json` (base `e8ebdad`). It has three lenses, `chars` (Opus), `world` (Opus) and `code` (Sonnet), plus skeptics for high and medium findings. With `partition: false`, it returns the survivors, and the lead partitions them.
  - **If cut off:** rerun with `resumeFromRunId` (same session) or with the same args (a new session).
- **Next:**
  1. Partition the survivors into at most 3 fix packages, and add the open items not raised (the unfreed children, Game-boy's near-arm answer).
  2. Run the fix wave (`review.js` with `findings_path` and packages), then re-check the changed items.
  3. Perf on a quiet machine: `tools/perf_compare.sh --bot res://tests/bot/level_bot.tscn --act "Perf: level walk" --runs 3 910448e HEAD`, and "Perf, six with ragdolls" against `main`.
  4. README's M6 departures, the PR, and the DM.

### 2026-11-04 18:50 CST: phase 2 merged (1919/1919); every inventory key is 0; stills sent; phase 3 recording
- **Phase 2 is merged** into `m6/full-art-audio` and pushed (`28b1be0`): 1919/1919 in 364 s, 0 error lines. One GUT warning: `test_art_heavies.gd` leaves 2 unfreed children (a phase 3 fix item).
  - The merge order was SFX, WEAPONS, then A6's floor weapon (`7f7c7cb`: the pickup is now `Pickups/ChainBigShutter` with `weapon_scene` = `bike_chain.tscn`); a suite there passed 1892/1892. Then HEAVIES, CREW, ARM and DRESS, merged in a scratch worktree while that suite ran, fast-forwarded, and one suite on all of it.
  - The conflicts, all kept both sides:
    - `tuning_data.gd`'s Debug tail;
    - `roofs.tscn`'s ext_resources (the chain and DRESS's scripts);
    - `blender_fit.py`: HEAVIES's sole flatten is step 5e, CREW's sole lift 5f;
    - the ratchet: the lower numbers, then re-measured;
    - the veteran atlas: regenerated.
  - **The ratchet:** every key is 0 in mission1, crowd_room and test_room, and globally (generated_sfx 0, empty_slots 0). Done-when row 1 holds.
  - **The paid services:**
    - Tripo: M6 has spent 495 of its 900 stop (PROPS 150, HEAVIES 180, CREW 165), and the balance is 1210 (floor 700).
    - ElevenLabs: 4843 credits on the ledger, of the 30,000 stop.
    - Gemini: 34 images.
  - Phase 2 cost about 22 points of the 5-hour window (21% to 43%), against its estimate of 71.
- **Sent to Game-boy** (Slack DM, 18:48):
  - stills: the four characters beside their concepts, two lineups, the near-arm A/B, and the street and roof tours;
  - the audition room's keys and the run command.
  - **He is asked one thing: the near arm.** Keep it and fix the shading (the lead leans this way), or turn it off for M5's view (`look_near_arm`). The arm sits in the shadow band: violet, with an ink step at the cut, and a navy shoulder shard in the uppercut.
- **The lead's look** (from the packages' stills):
  - The Kicker and the Thug read as their concepts.
  - The Bruiser's steel and purple blotch at 1 m, and his head is out of frame at 1 m.
  - Ox Pellerin reads, but his gloves are smaller than the concept's. The 1 m act's bar read "BOSS", recorded before the rename; the lineup reads "OX PELLERIN", and every spawn path goes through `make_enemy`.
  - The four silhouettes are distinct in the lineups.
  - The tours read as a dusk street and copper roofs; the tanks' rust is blotchy.
  - The near arm: as above.
- **Items for phase 3's review and fix wave** (from the builders and the lead):
  - the help overlay's "BracketRight"/"Minus" and its overflowing line;
  - the Bruiser's blotches; the boss's small gloves;
  - the held weapon is out of view in first-person swings (as the pipe always was), so the chain's whip is unseen in hand;
  - DRESS:
    - the rooms keep Tuning's grey sun;
    - the facade has no lit windows;
    - the boss deck reads flat;
    - the roofs have no AC units;
    - the section-light blend in motion is unjudged;
  - frame time: +16.5% mean (10.04 to 11.70 ms) against `910448e`, on a loaded machine, so re-measure quietly;
  - `test_art_heavies.gd`'s unfreed children.
- **Running:** the phase 3 recording (§4 step 5), `bash <scratchpad>/record_final.sh`, into `captures/m6-final/`.
  - Two lanes: the crowd bot's acts (the six "Look: <label> at 1 m", lineup, heavies, weapons, props, props weapons, own limbs, rooms tour) and the level bot's acts (tour, drops, seams, and "Run: held back" 0-2, 3-5, 6).
  - The lanes log to `captures/m6-final/lane_*.log`.
  - **If cut off:** rerun the missing slugs with `tools/record_acts.sh` (the script's lines are in this entry's commit message).
- **Next** (§4 steps 6-9):
  1. The lead's look at `captures/m6-final`.
  2. Write `docs/reviews/M6/args-review-final.json` (lenses `chars`, `world`, `code`; the items above in `common_note`) and run `tools/workflows/review.js`.
  3. One fix wave and a re-check.
  4. Perf on a quiet machine.
  5. README's M6 departures, the PR, and the DM.
- **Usage now:** 5-hour 44% (it resets at 19:50 CST), weekly 22%.

### 2026-11-04 16:40 CST: phase 1 merged (1872/1872); stills and the audition room sent; phase 2 running
- **Phase 1 is merged** into `m6/full-art-audio` and pushed (`56b960c`): 1872/1872 in 324 s, 0 error lines.
  - The merge order was LOOKS, CHAIN (`5e8e757`), PROPS (`a337809`), KIT (`d342e02`) and AUDIO (`56b960c`). After each merge: the atlas, the preset, the ratchet and the full suite.
  - The lead's fixes at merge:
    - `test_m6_no_placeholders.gd` skips a hidden proxy cylinder, so `cylinder_weapons` fell to 0.
    - `test_kit.gd` sees PROPS's art: the trim-material count skips StaticArt, and the fallback test uses an id with no scene.
    - `.gitattributes` gives the ElevenLabs ledger a union merge.
  - The ratchet now: mission1 primitive_bodies 4, tints 1, boxes 0 (was 489), cylinder_weapons 0, second_weapon 1; crowd_room 4, 0, 74, 0, 0; test_room 4, 1, 27, 0, 0; global generated_sfx 9, empty_slots 16 (AUDIO declared the slots, and SFX takes them to 0).
  - The paid services: Tripo 150 credits (PROPS; the balance is 1555, and M6 has spent 150 of its 900 stop); ElevenLabs 1649 of 40,000. **The ElevenLabs rate is measured at 10 credits a second, not 40.** Gemini: 5 images.
  - The phase 1 worktrees `.worktrees/m6-{chain,kit,props,audio,looks}` still hold their captures; prune them after M6.
- **Sent to Game-boy** (Slack DM, 16:35): the cap's blood A/B, the veteran, street A1's kit and the props, weapons and dummy; the audition room's keys (training room: `]`/`[` page the banks, `1`-`9` play a take, `=` plays the bank, `-` swaps old and new) and the run command. Nothing waits on him.
- **The lead's look** (from the packages' stills):
  - The cap keeps its yellow, and the blood is hard-edged.
  - The veteran reads at 1 m and 5 m.
  - A1's brick, windows, cornices and chain-link read as a street; the bricks are chunky.
  - The car and the tank read at 5 m, but are faceted at 1 m. The AC unit is pale.
  - The Thug's pipe in hand isn't confirmed in any capture (end-on only).
  - For the phase 3 review: the audition rows in the help overlay show "BracketRight" and "Minus", and one line runs past the panel's edge.
- **Running:** phase 2, `tools/workflows/build.js` run `wf_6b1bdf77-3ee` with `docs/reviews/M6/args-P2.json` (SFX, HEAVIES, CREW, DRESS, WEAPONS, ARM; 3 Godot slots, and HEAVIES, CREW and ARM take the Blender slots).
  - The args now carry phase 1's handover: each package's requests from the calls files, the alpha classes and the measured ElevenLabs rate.
  - **If cut off:** rerun build.js with the same args (the file). Each builder resumes from its newest `wip:` commit, and a finished package is skipped.
- **Next** (the plan's §4 step 4):
  1. Merge each P2 package as it finishes; after each, the atlas, the preset, the ratchet and the full suite.
  2. After WEAPONS: set `Pickups/PipeBigShutter`'s `weapon_scene` to `bike_chain.tscn` (`roofs.tscn:1117-1119`), rerun `test_m5_roofs.gd`, and lower `second_weapon`.
  3. After ARM, send its stills. After SFX, send the audition room again. After HEAVIES and CREW, send the four characters at 1 m beside their concepts.
  4. One post-merge fixer (Sonnet) if needed; HANDOFF; then phase 3 (§4 steps 5-9).
- **Usage at launch:** 5-hour 21% (it resets at 19:50 CST), weekly 18%. Phase 1 cost about 16 points of the 5-hour window, against its estimate of 44.

### 2026-11-04 15:15 CST: step 0 merged (1766/1766); phase 1 running
- **Step 0** (`b995e56`): 1766/1766 in 321 s, 0 error lines. `8ef8b28` is the ElevenLabs-only plan change.
- **Running:** phase 1, `tools/workflows/build.js` run `wf_fa4aea82-d60` with `docs/reviews/M6/args-P1.json` (CHAIN, KIT, PROPS, AUDIO, LOOKS; 3 Godot slots, and CHAIN and PROPS share the 2 Blender slots).
  - The worktrees are `.worktrees/m6-<key>`, on branches `m6/<key>`.
  - **If cut off:** rerun build.js with the same args. Each builder resumes from its newest `wip:` commit, and a finished package (its "M6 <KEY>:" commit) is skipped.
- **Next** (the plan's §4 step 2):
  1. Merge each package, in any order. After each: `godot --headless -s tools/gen_default_preset.gd`, `python3 -I tools/pipeline/gen_palette.py`, re-measure the placeholder ratchet, and run the full suite.
  2. Send LOOKS's A/B stills.
  3. Play the audition room after AUDIO, and send its run command.
  4. Then phase 2 (`args-P2.json`: SFX, HEAVIES, CREW, DRESS, WEAPONS, ARM).
- **Usage at launch:** 5-hour 3% (it resets at 19:50 CST), weekly 15%.

### 2026-11-04 15:00 CST: the M6 plan is written; step 0 done (suite running); phase 1 launches next
- **The plan:** [milestones/M6-plan.md](milestones/M6-plan.md) (649 lines), committed `49914b4` with its four codemaps (`docs/milestones/M6-codemap/`) and the args `docs/reviews/M6/args-P1.json`, `args-P2.json` and `args-P2b.json`.
  - It came from workflow `wf_8346b955-f3c`: four Sonnet readers, an Opus planner, an Opus critic (17 issues, 4 high) and an Opus xhigh synthesis that applied them all. About 1.65M sub-agent tokens.
  - The lead read the whole plan, and it stands as written.
- **The packages** (their estimate in % of a 5-hour window):
  - **Phase 1:** CHAIN 10 (the roster: M4's tests and chain per character; the dummy), KIT 10, PROPS 9 (the static-prop path; the pipe, the bike chain's parts, the car, dumpster, AC unit and water tank; Tripo at most 270), AUDIO 8 (ingest, manifest, ElevenLabs voices at most 6000 credits, the audition room), LOOKS 7 (D6 blood per swatch, D4 the veteran's palette, `test_m6_no_placeholders.gd`).
  - **Phase 2:** HEAVIES 13 (Tripo at most 350), CREW 12 (250), DRESS 12, WEAPONS 8, ARM 6.
  - **SFX 6** (phase 2, after AUDIO): every sound effect that isn't a voice, from ElevenLabs (ceiling 20,000; Game-boy's call at 15:05).
  - **All of M6:** about 175% of a 5-hour window (three windows), 17-21 weekly points.
- **Changes from the approved proposal** (method, not spec):
  - D2: the kit modules are Godot-procedural `ArrayMesh`es, not Blender-scripted;
  - new packages PROPS and ARM;
  - D7 (the near arm) moved to phase 2's ARM.
  - Game-boy is told.
- **Step 0** (the lead), not yet committed: the full suite runs first, into `captures/m6-step0/suite.out`.
  - The signals `section_entered`, `barrier_moving` (emitted only when a barrier's state changes) and `weapon_landed`.
  - `LevelSection.ambience`, `MoveData.impact_sfx`.
  - `punk.json` narrowed to 16-21 and `player.json` to 32-37 (`gen_palette.py --check` says the atlas is current).
  - The ARCHITECTURE.md section "Full art and audio (Milestone 6)" with every package's heading, and the ASSETS.md headings.
- **Next:**
  1. The suite green: commit step 0 and push.
  2. `get_usage`.
  3. Launch P1: `tools/workflows/build.js` with `docs/reviews/M6/args-P1.json` (3 Godot slots; CHAIN and PROPS take the Blender slots).
  4. Merge each package as it finishes (the plan's §4 step 2).
- **Usage:** a new 5-hour window, 2% (it resets at 19:50 CST); weekly 15%.

### 2026-11-04 14:25 CST: CONCEPTS merged; the pick sent; the plan workflow still running
- **CONCEPTS** (`448496f`, merge `c24da33`, about 0.21M sub-agent tokens) made 19 Gemini images with no retries.
  - The sheets are in `assets/source/concepts/m6/sheets/`: kicker, thug, bruiser, boss (with the names), weapon, moods.
  - Its calls are in `docs/milestones/M6-calls/CONCEPTS.md`. The flaws it kept:
    - Kicker A's eyes show skin;
    - the boss's charcoal reads as light slate in all three;
    - boss A reads as a puffy suit.
- **The lead's look:** the frames, A-poses and colour identities hold, and there's no red. No boss copies the reference's masked, bare-chested heavy.
- **The pick went out** at 14:25 CST, in the session chat (the six sheets) and on Slack (DM `D0AQUKX5DB6`, one stacked image, file `F0CEWQPH38E`). It asks for:
  1. a design per type;
  2. the boss's name;
  3. the weapon;
  4. a street mood (A/B) and a roof mood (C/D).
  - Also asked: the prune and the Tripo account type.
  - **Never pick for him.**
- **Still running:** the plan workflow `wf_8346b955-f3c`.

### 2026-11-04 14:05 CST: Game-boy said go; CONCEPTS and the plan workflow are running
- **Game-boy's answers** (session chat):
  - "OK we're ready to begin": the proposal is approved.
  - **Audio option (a):** Sonniss for the hit stack and the world sounds, ElevenLabs for the voices.
  - **ElevenLabs Starter** ($1, a commercial licence, 30,000 credits a month). The key is `ELEVEN_LABS_API_KEY`, and it works.
  - **Tripo** is topped up to 1,705.
  - **Ultracode** is on.
- **Committed** (`ddb0a06`):
  - `tripo_prices.json`'s policy is now M6: start 1705, floor 700, stop 900;
  - README's key row and `.env.example`;
  - `docs/reviews/M6/brief-CONCEPTS.md` and `args-P0.json`.
- **Running:**
  1. **CONCEPTS:** `build.js` run `wf_29312051-0d8` with `args-P0.json`, worktree `.worktrees/m6-concepts`, branch `m6/concepts`, Gemini images only (at most 30). It makes:
     - 3 concepts each for the Kicker, Thug, Bruiser and boss;
     - 3 boss names;
     - 3 weapons;
     - 2 street moods and 2 roof moods;
     - the sheets and a DM draft.
     - **If cut off:** rerun build.js with the same args.
  2. **The plan workflow** `wf_8346b955-f3c` (script `m6-plan`):
     - four Sonnet readers write `docs/milestones/M6-codemap/` (art-chain, audio, level-env, weapons-looks);
     - an Opus planner writes `docs/milestones/M6-plan.md` and `docs/reviews/M6/args-P1.json`/`args-P2.json`;
     - then an Opus critic, then the Opus xhigh synthesis.
     - **If cut off:** in this session, rerun its script with `resumeFromRunId`. In a new session, finish the plan from whatever codemaps exist.
- **The lead's correction for the plan:** the Sonniss bundle (tens of GB) must live **outside the repo** (say `~/sfx-library/sonniss/`, the path read from an env var or an argument). Inside it, Godot would import every WAV and git would see it. Only the picked, trimmed files are committed.
- **Asked of Game-boy:**
  - prune the 90 M3-M5 worktrees (62 GB). All their HEADs are on origin, and the only uncommitted files are reviewer scratch, a stray log, M4's chain report stills and M4's throwaway act edit;
  - download the Sonniss bundle (28 GB free before the prune);
  - the Tripo account type (it gates phase 2's Tripo tasks).
- **Next:**
  1. CONCEPTS done: look at the sheets, then send the DM (Slack D0AQUKX5DB6, and in the session chat).
  2. The plan done: review it, commit, and launch phase 1 with `args-P1.json`.
  3. Rewrite the takeover prompt for M6.

### 2026-11-04 13:30 CST: M6 working session started; the proposal is written; waiting on Game-boy's sign-off and four answers
- **This session** is titled "Beat-em-up: working session". The M5 session is "Beat-em-up: M5 (signed off)". The watcher [Beat-em-up: usage watcher](#local_5fa6c438-0fb3-4c35-b5b8-9f561074267b) is still running.
- **Branch:** `m6/full-art-audio`, cut from `main` at `78223dc`.
- **The proposal:** [milestones/M6-proposal.md](milestones/M6-proposal.md).
  - What's still placeholder.
  - The phases:
    - 0: concepts and one DM;
    - 1: KIT, AUDIO and LOOKS, which need no picks;
    - 2: CREW, HEAVIES, DRESS and WEAPONS, after the picks;
    - 3: the review round.
  - Decisions D1-D9, and the checkable done-when.
- **Waiting on Game-boy:**
  1. sign-off;
  2. the audio source (Sonniss plus ElevenLabs for the voices is recommended);
  3. Tripo: about 700-900 credits. The live balance is 1,205, and M4's floor of 700 leaves only 505, so he either lowers the floor to 250 or tops up. The licence (account type) is still open;
  4. Ultracode on.
- **Next on his yes:**
  1. The lead writes `docs/milestones/M6-plan.md` (self-contained briefs), and one Opus critic at medium reviews it.
  2. Args go in `docs/reviews/M6/`.
  3. Launch CONCEPTS, then phase 1.
  4. Rewrite the takeover prompt for M6.
- **Usage at start:** 2% of the 5-hour window (it resets at 14:50 CST) and 12% weekly (it resets 11-09 04:00 CST).

### 2026-11-04 13:45 CST: Game-boy signed off Milestone 5; PR #5 merged; M6 waits for his go
- **Game-boy (session chat):** "Signed off". He played the build with his two playtest changes in.
- **README:** M5's "decided by default" departures now read "accepted by Game-boy with M5's sign-off, 2026-11-04". His two playtest rulings (the Kicker's opportunistic flank, and behind spawns that don't wait) are in their own section.
- **PR #5 is merged into `main`.** Every `m5/*` branch is pushed, and the `.worktrees/m5-*` worktrees can be pruned.
- **Next: Milestone 6 (SPEC §12): art for the level and the second weapon.** Also carried forward from M4 are the damage marks and the near upper arm.
  - **Before starting:** tell Game-boy, then wait for his go.
  - **Then:**
    1. Branch `m6/<topic>` from `main`.
    2. Plan with a workflow, under the M5 usage and process rules.
    3. Start it in a fresh session, which reads this file first.

### 2026-11-04 10:15 CST: Game-boy's playtest feedback done (1766/1766); PR #5 updated; waiting on his play and sign-off again
- **Merged on `m5/level-blockout`:**
  - FEEDBACK (`b417ba0`);
  - the fix `fix-feedback-faced` (merge `2e8a4a4`): a Kicker he faces fights; busy counts only the enemy nearer the middle of his view; `kicker_flank_faced_off_s` 0; the "Kicker left alone" act; the leak in a test_kicker.gd single-file run; the holder test;
  - the comment polish (`26134ef`, `8a2bf73`).
- **The targeted re-check** (one Sonnet agent, read-only) confirmed every item and found no highs or mediums. Its two lows: one was comment polish, now done. The other is that a Kicker already winding up when he turns away can still hit from the side. That's the holder rule, and it's kept.
- **Suite:** 1766/1766 in 299 s, 0 error lines. The done-when plays 7 arenas and 34 enemies.
- **Recordings** are in `captures/m5-feedback/`: before/, after/, and fix/ with alone, opportunist, oneonone and a4.
- **Waiting on Game-boy:** play again, sign off, and rule on README's "decided by default" M5 departures. His two playtest rulings are recorded as his, in README's new "ruled by Game-boy at his playtest" section.
- **Next after sign-off:** as before. Record his rulings in README, merge PR #5, then plan M6.
- **Usage:** about 9% of the 5-hour window and 12% weekly. This round used about 1.2M sub-agent tokens: the builder 0.32M, the review 0.54M, the fixer 0.21M and the re-check 0.1M.

### 2026-11-04 09:40 CST: FEEDBACK merged (1761/1761); reviewed (one medium); fixer `faced` running
- **FEEDBACK** is merged into `m5/level-blockout` (`b417ba0`, fast-forward). README has Game-boy's two rulings (`e8fc568`). The suite on the merged branch: 1761/1761, 327 s under load, 0 error lines.
- **Recordings** are in `captures/m5-feedback/`: before/a4, plus after/{oneonone, opportunist, flanks, a4, a6}. One-on-one, the Kicker fights from in view; in A6 it gets behind while the Punk is busy with him.
- **The review** (run `wf_a5f90cf4-699`; `feel` on Opus, `code` on Sonnet; about 0.54M tokens) found one medium, confirmed by its skeptic, and three lows. The medium is `feedback-feel-01`: a Kicker he has turned on keeps flanking while a Punk is in view. The lead's rulings are in `docs/reviews/M5/findings-feedback.json`:
  - busy counts only the enemy he faces, the one nearer the middle of the view;
  - a faced Kicker stops at once (`kicker_flank_faced_off_s` 0);
  - a "Kicker left alone" act;
  - the single-file leak in test_kicker.gd fixed;
  - the holder reseat kept and tested.
- **Fixer `faced`** (review.js run `wf_67a4b1ab-53a`, fixers only; the first launch, `wf_d92b342d-e0c`, failed on the args shape: `packages` must be `{packages: [...]}`) is on branch `m5/fix-feedback-faced`. **Resume:** if it was cut off, rerun review.js with the same args. Then:
  1. merge it;
  2. look at its recordings;
  3. run the suite;
  4. update CLAUDE.md's suite figures;
  5. push, update PR #5, and post the run command to Game-boy.

### 2026-11-04 08:35 CST: Game-boy played M5 ("mostly good"); two changes from him; package FEEDBACK building
- **His two rulings** (word for word in `docs/reviews/M5/fix-feedback.md`):
  1. Kickers get behind you only *opportunistically*, while you're fighting someone else. One-on-one they must not keep running round you, which caused a lot of whiffs.
  2. Spawns don't wait for your back to be turned. The `out_of_view` hold made long lulls and then a hit from behind.
- **Package FEEDBACK** (one Sonnet builder, `tools/workflows/build.js` with `docs/reviews/M5/args-FEEDBACK.json`) is on branch `m5/feedback` in `.worktrees/m5-feedback`. The brief is `docs/reviews/M5/fix-feedback.md`.
  - Item 1: the director flanks a Kicker only while another engaged enemy is in view within 4.5 m, with on and off hysteresis and the switch `kicker_flank_opportunistic`. Otherwise it's seated by its 360° arc and holds where it stands. The new hook is `set_flanking()` and `is_flanking()`.
  - Item 2: the switch `spawn_behind_waits_out_of_view`, default off.
- **The lead's "before"** recording of A4 held back is in `captures/m5-feedback/before/a4/`.
- **Resume:** if the builder was cut off, rerun build.js with the same args (it resumes from the branch). Then:
  1. merge `m5/feedback` into `m5/level-blockout`;
  2. look at its recordings against the before;
  3. run the full suite;
  4. write README's rulings (two M5 departures change: the Kicker's flank and "behind spawns out of view");
  5. push, update PR #5, and post the run command to Game-boy.
- **The PR** stays unmerged until he signs off. The rest of the build is "mostly good" by his word, and there are no rulings yet on the other departures.

### 2026-11-04 00:00 CST: M5 built and reviewed; PR #5 open; waiting on Game-boy's play and sign-off
- **The fix wave merged** (`c2ddebc`, `2f7e269`, `7229ce9`; run `wf_2178beaf-dba`, about 0.67M sub-agent tokens). The lead also:
  - moved roofs Skyline Block5 out of the boss roof's gap view (`96fa4a9`) and regenerated the preset (556 values);
  - added `##` docs on the new tunables (`5feaa2d`).
- **Suite:** 1748/1748, 293 s, 0 error lines. `test_m5_done_when` covers 3 sections, 7 arenas and 34 enemies. `test_m5_seams.gd` walks the real seams.
- **The targeted re-check** (run `wf_1122fe50-342`, about 0.29M tokens): every fixed item is confirmed. The one partial is `sees-06` (the parapet outline shows only from the unreachable seams pose 11). It found no regressions; its one new low (missing tunable docs) is fixed.
- **Re-recordings** are in `captures/m5-recheck/`: roofs/held (178.4 s), drops and seams.
- **PR:** [mikedtcm22/beat-em-up-PoC#5](https://github.com/mikedtcm22/beat-em-up-PoC/pull/5), `m5/level-blockout` into `main`. It's mergeable, and there's no CI on the repo. **Never merge it before Game-boy signs it off.**
- **Waiting on Game-boy:**
  1. He plays the level (`godot --path /Users/arachne/repos/beat-em-up-PoC`).
  2. He rules on README's "Where M5 departs from the spec" (decided by default).
  3. He signs off.
  - The judgement-call digest was sent with the run command, in the session chat and in a Slack DM.
- **Next after sign-off:** record his rulings in README (change the heading to "accepted"), merge PR #5, then plan M6 (art for the level and the second weapon, per SPEC §12).
- **Usage:** 0% of the new 5-hour window (it reset at 23:30 CST), 11% weekly. The previous window ended at 24%. M5 in all: about 6M sub-agent tokens.

### 2026-11-03 23:00 CST: final review done (no highs, 5 mediums); the fix wave running (3 Sonnet fixers)
- **The review** (`review.js` run `wf_35fbfae3-70f`, about 1.45M sub-agent tokens, about 7% of the 5-hour window): lenses `sees` and `feel` (Opus) and `code` (Sonnet), on `captures/m5-final/`.
  - 16 findings: 5 medium survived their skeptics, and 11 lows came to the lead.
  - The mediums:
    - `sees-01`: behind spawns pop into view (A4's RoofDoorBehind lies ahead; named spawns skip the view rule);
    - `sees-02`: A6's pipe is hard to find;
    - `sees-03`: the boss roof's rail gap reads as a ledge;
    - `code-01`: the done-when's totals are asserted only conditionally;
    - `code-02`: no test crosses the seams.
  - Promoted lows: `feel-02` (a long-range token gives a 4-5 s lull), `code-04` (the probe's total() double-counts two keys), `code-05` (script numbers), `sees-05` (the GO cue holds until faced), `sees-06` (the parapet outline) and `code-06` (an orphan uid).
  - The lead takes `code-07` (README). He notes in README `sees-04`/`feel-01` (A7's R6/R8 misses are the boss alone), `feel-03` (the pilot never jumps) and `code-03`.
  - Everything is in `docs/reviews/M5/findings-final.json`, with the lead's rulings (`lead_overrides`) and the three packages.
- **Running:** the fix wave, `review.js` run `wf_2178beaf-dba` (`findings_path` mode, fix_concurrency 3). Packages:
  - `spawns` (branch `m5/fix-final-spawns`);
  - `level-tests` (`m5/fix-final-level-tests`);
  - `arcs` (`m5/fix-final-arcs`).
  - Worktrees are `.worktrees/m5-fix-final-<key>`. If it's cut off, rerun the same args: each fixer resumes from its newest `wip:` commit.
- **Next:**
  1. Merge the three fix branches and regenerate `tuning/default.json` (`godot --headless -s tools/gen_default_preset.gd`). Run the full suite.
  2. The targeted re-check: re-record roofs/held, boss/held and arc-quick/arc-punks. `sees` re-judges sees-01/02/03/06, `feel` re-judges feel-02, and `code` (Sonnet) re-judges code-01/02/04/05.
  3. Open the PR, then send Game-boy the run command and the digest.
- **README:** M5 status (a draft), the level's tests and bot, and the boss arena's soft misses are in. CLAUDE.md has M5's suite figures.
- **Usage:** 20% of the 5-hour window before the fix wave (it resets at 23:30 CST), 10% weekly.

### 2026-11-03 22:10 CST: FIX2 merged (1729/1729); phase 3 recording for the review
- **FIX2 merged** (`c97fa09`, merge `2e4455e`; run `wf_a1a41ce1-d8a`, about 0.39M sub-agent tokens). Its calls are in `M5-calls/FIX2.md`. It fixed all seven items:
  1. Roofs R0 moved past A4's lock inset, and the done-when walks the player into A1.
  2. The z -83 seam has one owner, the boss roof's fence.
  3. The z -53 seam was looked at and is clean.
  4. The GO arrow is drawn as triangles, with `tests/test_go_cue.gd`.
  5. A named spawn falls back to any free point after `spawn_named_wait_s` + `spawn_named_any_wait_s` (new, 3.0 s; the preset now has 542 values).
  6. `knock_off(from)` picks the hazard of the named arena.
  7. R13 doesn't apply to a one-wave table. There's a new act, "Look: seams".
- **Suite** (alone on the machine): 1729/1729, 294 s, 0 error lines. `test_m5_done_when` covers 7 arenas and 34 enemies, in a 9.3 s wall.
- **Also on the branch:** README "Play it", CLAUDE.md "Play" and the H help say the level is the main scene and F6 cycles three rooms (`6a98ae4`). Game-boy was told the level is playable, with the run command.
- **Running:** the recordings for the final review into `captures/m5-final/`.
  - The arc acts (`arc-punks`, `arc-turn`, `arc-mixed`, `arc-quick`), `seams` and `knock-catwalk` (`--from=4`).
  - `street/held` (0-2), `roofs/held` (3-5) and `boss/held` (6).
- **Next:** run the timing log into `captures/m5-final/timing.log`. Then fill `docs/reviews/M5/args-review-final.json`'s `base` (`2e4455e`) and `common_note`, and run `tools/workflows/review.js` with it: lenses `sees`, `feel` (Opus) and `code` (Sonnet); skeptics on medium and high; `partition: false`, so the lead partitions inline into at most 3 fixers.
- **Usage:** 11% of the 5-hour window (it resets at 23:30 CST), 8% weekly.

### 2026-11-03 21:05 CST: phase 2 merged; the level plays start to boss; suite and recording running
- **Built and merged** (`build.js` run `wf_ccbf580f-37d`, about 0.96M sub-agent tokens, about 8% of the 5-hour window). Merges `34fc4a6`, `5d60ac1` and `3db7d07` into `m5/level-blockout`. The only conflicts were in ARCHITECTURE.md's Mission 1 headings; all three sections are kept.
  - **STREET** (`3ecb56a`): `game/level/mission1/street.tscn`, A1-A3, tables `a1-a3.tres` (13 enemies), `tests/test_m5_street.gd` (17 tests). Calls are in `M5-calls/STREET.md`.
  - **ROOF** (`4054f3e`): `roofs.tscn`, A4-A6, `a4-a6.tres` (18 enemies), three drop edges with guards and hazards, and the pipe pickup. `tests/test_m5_roofs.gd` has 13 tests.
  - **FINALE** (`6d3d08b`): `boss_roof.tscn` (A7, 20 x 20 m) and `a7.tres` (the boss; his adds come from the boss's own call-in), plus `mission1.tscn` (the `LevelRoot`). The level is **the main scene now**, and F6 cycles level, crowd room, training room. `tests/test_m5_done_when.gd` has 8 tests.
  - No tunables were added, so the preset is unchanged.
- **Whole-level timing** (god mode, full speed, headless): all 7 arenas in order, no STALL or BLOCKED, `LEVEL 194.8` s. Per arena: A1 8.6, A2 22.2, A3 24.1, A4 16.6, A5 24.7, A6 29.2, A7 37.7 s.
- **Running:** the full suite (into `captures/m5-p2/suite.out`) and the held-back recording of the whole level (`captures/m5-p2/rec/held/`).
- **The post-merge fixer list so far:**
  - `go_cue.gd:191`'s triangulation ERROR (a degenerate arrow polygon).
  - The knock-off act always picks A4's drop.
  - A unique-tag named spawn waits forever while the player stands within 4 m of it. It needs a fallback to any free point after a wait.
  - The STREET/ROOF seam: the 6 m shutter against the terrace's wall.
  - Plus anything the suite, the done-when or the recording shows.

### 2026-11-03 20:25 CST: Game-boy approved the table; phase 2 (STREET, ROOF, FINALE) building
- **Game-boy's words** (session chat, 20:20): "OK, enemy arcs are good. Let's continue with the rest of M5 now."
  - He played the arcs in the crowd room before saying it. Before that he asked for the run command to be posted with every playable update; a memory now says so.
  - So `reference/encounters.md` is approved as drafted, with no changes.
  - The rear-warning question takes its default (no: Punks never come round behind on their own). It's in README's M5 list as decided by default, and in M5-inputs.md.
  - The three overrulable defaults (stairs, no falls, the arc slide) stand, for his ruling at sign-off.
- **Running:** `tools/workflows/build.js` with `docs/reviews/M5/args-P2.json` (`only: ["STREET", "ROOF", "FINALE"]`, concurrency 3). Worktrees `.worktrees/m5-street`, `m5-roof` and `m5-finale`, on branches `m5/street`, `m5/roof` and `m5/finale`. If it's cut off, rerun the same args: the loader resumes from each branch's newest `wip:` commit.
- **Next:**
  1. Merge STREET, then ROOF, then FINALE. Regenerate the preset, then run the full suite and `test_m5_done_when.gd`.
  2. Record "Run: timing" on the whole level, and take the lead's look.
  3. Run one post-merge Sonnet fixer for what only the whole level shows.
  4. Phase 3: the review round (plan §5).
- **Usage at launch:** 0% of the 5-hour window (it resets at 23:30 CST), 6% weekly. Plan §7 estimates phase 2 at about 32%.

### 2026-11-03 11:20 CST: phase 1 done (BOT merged); waiting on Game-boy's table for phase 2
- **BOT merged** (`35156c4`, merge `2b3fa5f`, pushed; 1683/1683 on its branch, and nothing but docs changed under it):
  - `tests/bot/level_bot.{gd,tscn}` plays any `LevelRoot` or a lone section, with `--level`, `--from` and `--to`.
  - The acts are "Run: held back", "Run: knock-off" and "Run: timing".
  - `record_acts.sh` takes `BOT_SCENE`.
  - Strip times: 32.7 s at full speed in god mode, 103 s held back. The calls are in `M5-calls/BOT.md`.
  - **Routes must be straight walkable lines between route markers**, and the last route point must reach past each arena's lock inset. This matters to STREET, ROOF and FINALE.
- **The lead's look:** the held-back run on the strip shows the plain first-person view. The walk eases to each route point, and the GO arrow shows as the shutter opens. The stairs and the chain-link gate read.
- **Phase 2 is ready to launch** with `docs/reviews/M5/args-P2.json` (STREET, ROOF, FINALE; concurrency 3; KIT's notes on each package). First fill in Game-boy's approval words in the `note`, and apply any change he asks for to `reference/encounters.md`.
- **Slack replies:** the watcher now also reads the DM thread on every check and relays Game-boy's replies to this session.
- **Still waiting on Game-boy:** the table and the rear-warning question. No reply at 11:20.

### 2026-11-03 10:50 CST: ARC and KIT merged (1678/1678); BOT building; still waiting on Game-boy's table
- **Merged into `m5/level-blockout` and pushed** (`5d3548e`):
  - **ARC** (`7cb70bc`): the attack arcs, `EnemyVariant` and `punk_veteran`, the wait ring, the arc slide, F3 arc lines, and R5/R5w, R6/R6w and R9 re-measured. The calls and the before/after numbers are in `docs/milestones/M5-calls/ARC.md`.
  - **KIT** (`58f3429`): the level kit in `game/level/kit/`, the "Level" tuning group, layer 9, the spawner's finite mode, the GO cue and the test strip `tests/fixtures/level_strip.tscn`. 24 calls are in `M5-calls/KIT.md`.
  - The one conflict was ARCHITECTURE.md's M5 heading; both sections are kept. The preset is regenerated (541 values). The full suite: 1678/1678, 286 s, 0 error lines.
- **The lead's look:**
  - "Arcs: six Punks": three Punks square up in front and the rest stand back on the wait ring. Nobody circles.
  - The strip: the shutter, the gate, the stairs and the GO/CLEAR! panels read.
  - KIT's scratch recording shows the controls help and the combat log over the view. BOT is told to record the plain view.
- **Running:** `build.js` run `wf_65b663bc-bcc`, args `docs/reviews/M5/args-P1b.json` (`only: ["BOT"]`). Worktree `.worktrees/m5-bot`, branch `m5/bot`.
- **README:** a draft of "Where M5 departs from the spec" (M5-1 arcs, M5-2 blind spot, M5-3 stairs, the spec-silent edges/KO/clear, the graybox stand-ins).
- **Waiting on Game-boy:** the encounter table and the rear-warning question (Slack DM, ts `1793721201.659339`). No reply yet at 10:50.
- **Next:** merge BOT and run the full suite. On his yes, launch phase 2 (STREET, ROOF, FINALE). Args: as P1, with `only` those three and `base` `m5/level-blockout`. Each package's `read` list is in the synthesis output, saved in the plan's §3.
- **Usage:** 20% of the 5-hour window and 6% weekly at BOT's launch. ARC and KIT together cost about 8% (0.9M sub-agent tokens).

### 2026-11-03 09:55 CST: the M5 plan written; phase 1 (ARC and KIT) building; the encounter plan DM'd to Game-boy
- **The plan:** [milestones/M5-plan.md](milestones/M5-plan.md), 275 lines. An Opus planner wrote it, an Opus critic reviewed it (4 high, 10 medium and 4 low issues), and an extra-effort synthesis applied most of the critique. It cost about 0.6M tokens, about 7% of the 5-hour window.
  - Packages: ARC (8%) and KIT (8%) in phase 1, then BOT (4%) after KIT merges. STREET, ROOF and FINALE in phase 2, after Game-boy's yes.
  - Decisions D1-D15 are in the plan's §1. README departures M5-1 (the arcs and the slide), M5-2 (blind-spot priority) and M5-3 (stairs for ladders); the spec-silent D8 and D13; the D12 stand-in.
- **The encounter table:** [reference/encounters.md](../reference/encounters.md): 7 arenas, 34 enemies, about 9-10 minutes. [reference/dd2-nes-mission1/notes.md](../reference/dd2-nes-mission1/notes.md) is filled in, and the screen order checks out against the fan map.
- **The DM to Game-boy** (Slack DM `D0AQUKX5DB6`, ts `1793721201.659339`, with the full table in two thread replies) asks:
  1. to approve the table;
  2. the rear-warning question (default: Punks never come round behind on their own).
  - Also three defaults he can overrule: stairs for ladders, the player can't fall, and an arc blocked by a wall slides.
  - **Waiting on him.** Phase 2 (the level) starts only on his yes. Apply any change he asks for to encounters.md first.
- **Running:** `tools/workflows/build.js`, run `wf_91b0b6e1-2cb`, with args `docs/reviews/M5/args-P1.json` (`only: ["ARC", "KIT"]`, concurrency 2). Worktrees `.worktrees/m5-arc` and `.worktrees/m5-kit`, branches `m5/arc` and `m5/kit`.
  - If it's cut off, rerun the same args: the loader resumes from each branch's newest `wip:` commit.
- **Next:**
  1. Merge ARC, then KIT. Regenerate the default preset and run the full suite.
  2. Look at "Arcs: six Punks" and "Arcs: turn your back", and play the strip.
  3. Launch BOT: the same args with `only: ["BOT"]`.
- **Also:** `captures/m5-baseline/` holds the pre-arc crowd recordings ("Mixed six, observed" and "Mixed six, fight"). `tools/record_acts.sh` now cuts overview sheets for acts without LOOK-MARK lines.
- **Usage:** 12% of the 5-hour window and 5% weekly before phase 1 launched.

### 2026-11-03 09:18 CST: M5 working session started; the plan workflow running
- **This session** is titled "Beat-em-up: working session" and runs M5 on `m5/level-blockout`, with Ultracode on. The old M4 session is renamed "(done)".
- **Usage watcher:** a new one started from this session, [Beat-em-up: usage watcher](#local_5fa6c438-0fb3-4c35-b5b8-9f561074267b) (`local_5fa6c438-0fb3-4c35-b5b8-9f561074267b`, Haiku low). The old watcher (`local_618146a1-...`) had stopped on 10-29.
- **Usage at start:** 5-hour 5%, weekly 4%.
- **Running:** workflow `wf_f5a98b47-0fc` (script `m5-plan`). An Opus planner (high) writes `docs/milestones/M5-plan.md`, the draft `reference/encounters.md` and the per-screen `reference/dd2-nes-mission1/notes.md`. Then an Opus critic (medium), then an Opus synthesis (xhigh), which also drafts the encounter-plan DM. Nothing is committed yet. If it's cut off, resume it with the same script and `resumeFromRunId`.
- **The lead's framing for the plan:**
  - Phase 1: ARC (the attack-arc director change), plus the level-kit mechanics built in a test strip. They don't depend on the encounter table: locks and barriers, the GO cue, drop-offs, climbs, the arena controller, pickups and a level bot.
  - The pause: the encounter plan and the rear-warning question go to Game-boy.
  - Phase 2, after his approval: the level itself.
  - Phase 3: the lead's look, 3 lenses, one fix wave, a re-check, then the PR.
  - Budget: about 1.25 five-hour windows for all of M5, so M6 and M7 fit the week.
- **The resume prompt** below now says Milestone 5.
- **`.worktrees/`** holds 51 GB of M3 and M4 worktrees. All are clean and pushed, except `m4-fix-final-punk-spawn-cache-before-recut`, which has an uncommitted `look_acts.gd` experiment. They're left in place; 52 GB of disk is free.

### 2026-11-03 09:30 CDT: the usage rules for M5 on, the new runners, and branch m5/level-blockout; M5 starts in a fresh session
- **Game-boy asked** for usage advice for the coming milestones ("get as far through milestones with this week's usage limit as we can ... while maintaining the current quality"), approved it, and asked for it written in. It's also in a fresh-session prompt, so M5 starts in a new chat.
- **Written in:**
  - the section "Model, effort and process rules from Milestone 5 on" (below the old usage rules), with M4's measured costs;
  - CLAUDE.md's "Parallel work" pointer to it;
  - the takeover prompt, rewritten for M5.
- **New tools:**
  - `tools/workflows/build.js`: Sonnet builders at high effort, an image budget, self-contained reading lists, and milestone-neutral `milestone` and `summary` args.
  - `tools/workflows/review.js`: Opus visual lenses at high, `model: "sonnet"` code lenses, one Sonnet medium skeptic per medium or high finding (lows to `for_lead_triage`), an optional lead partition (`partition: false`), at most 3 fix packages, and `captures_dir`.
  - `tools/record_acts.sh`: record a round's acts once for every agent.
- **Branch:** `m5/level-blockout`, cut from `main` at `eb08e26`. Its first commit is this setup, and the working checkout is on it.
- **Next:** Game-boy pastes the takeover prompt (below, "Takeover prompt") into a new session, with Ultracode on if he wants it. That session plans M5 with the new structure. This old session should then be renamed (for example "Beat-em-up: M4 session (done)") so the watcher reaches the new one.

### 2026-11-03 08:55 CDT: Game-boy signed off Milestone 4; PR #4 merged; M5 waits for his go (he'll turn on Ultracode first)
- **Game-boy (session chat):** "I think with those notes, you can also go ahead and merge PR 4 now so we can move on. Let me know before you're going to get fully started with the next milestone, though: I'll want to turn on Ultracode so you can use sub-agents."
  - **PR #4 merged into `main`.** README's M4 departures now read "accepted by Game-boy with M4's sign-off", and the two looks are carried forward to M6.
- **His answers on the attack arcs** (in `docs/milestones/M5-inputs.md`):
  - **The center line is fixed when the enemy engages,** with a grace period of about 0.5 s so a quick turn can't stun-lock a low-level enemy.
  - **Variants may widen a type's arc** (a "veteran Punk").
  - **Progression:** easy narrow-arc grunts early, mostly all-angle enemies later.
- **Next: Milestone 5 (SPEC §12), the level blockout.**
  - **Before starting:** tell Game-boy, then wait for his go. He'll turn on Ultracode so the work can use sub-agents and workflows.
  - **Then:**
    1. Branch `m5/<topic>` from `main`.
    2. Plan with a workflow, folding in `M5-inputs.md`. The attack-arc director change is the first package, before the encounter plan.
    3. The encounter plan goes to Game-boy for approval: SPEC §12's "approved encounter plan", one pause.
  - The `.worktrees/m4-*` worktrees can be pruned; every M4 branch is pushed.

### 2026-11-03: Game-boy passed M4's done-when ("punks look good - let's say passes at 1m"); merging PR #4 waits on his word; an AI change queued
- **Game-boy (2026-11-03, session chat), after playing the build with both hand fixes:** "punks look good - let's say passes at 1m."
  - That is the done-when's yes (SPEC §12 M4; Part B's pause 2).
  - **PR #4 is not merged yet.** The lead asked him whether to merge it now, with the M4 departures and calls approved and the open items carried forward. At M3 his sign-off also approved the departures.
- **His AI note, for a future pass (not art):** "I don't think we need to have *EVERY* enemy's strategy be trying to get behind you before they attack. The player should see the basic street-punks (for example) try to just square up with the player and attack head-on...or maybe from a slight angle (I think circling to attack from behind is a bit higher-level enemy tactic — maybe just one sneaky enemy-type in particular who does that)."
  - **What it changes:** SPEC §7 already says the Street Punk "approaches head-on" and the Kicker "actively circles to the player's blind side". What sends every type behind is M3's director:
    - its "Spread" rule (posture slots evenly all round);
    - `blind_spot_priority` 1.0 (out-of-view enemies jump the token queue);
    - each grunt taking any slot.
  - **So it's a change to SPEC §7's director rules, by his word:**
    - the grunts (Punk, Pipe Thug, Bruiser) posture in a front arc and attack head-on or from a slight angle;
    - the Kicker stays the one sneaky type that circles behind;
    - the boss keeps its own logic.
  - **Effects to re-measure:** M3's readability numbers and the rear warning's tests, since fewer attacks come from behind.
  - **Proposed timing:** a first, small package of Milestone 5, before the encounter plan, because the plan's arenas depend on how crowds stand.
  - **Refined by Game-boy the same day: per-archetype attack arcs.** The written-up design, his words, a proposed mapping (Punk 90°, Pipe Thug 140°, Bruiser 180°, boss 270°, Kicker 360°) and three open questions for the M5 plan are in `docs/milestones/M5-inputs.md`.
- **Next on the roadmap (SPEC §12):**
  - **M5, level blockout:** first an encounter plan for Game-boy's approval (a pause). Then the graybox level from `reference/dd2-nes-mission1/`, with arena locks, spawns, pickups, hazards and the boss arena. Done when the level plays start to boss.
  - **M6, full art and audio:** every enemy and the boss, environment modules, set dressing, final SFX. Done when no placeholder assets remain.
  - **M7, polish and playtest build:** the perf target on an RTX 3060, bugs, the Windows export. Done when Game-boy plays start to finish and answers SPEC §1's four questions.
- **Carried forward from M4:**
  - the four FP feel switches (defaults off);
  - the Tripo licence: the account type must be known before M6 generates many models;
  - per-swatch damage-mark strength and the orange-on-cap blood (M6);
  - the hero's arm knob (call 19);
  - the hero-select menu;
  - the quiet-machine perf A/B and the RTX 3060 measurement (M7).

### 2026-11-02 22:00 CDT: both hand fixes merged (1615/1615, 0 errors); waiting on Game-boy again
- **The Punk's fists** (`m4/f-fist-turn`, `694ddb0`, call 27):
  - The T9 generated fist is a right-hand fist, and the first build mirrored it as if it were a left, so both hands hung palm outward. `pipe_fist.make_side` now honours `parts.fists.generated.source_side` ("Right" for the Punk).
  - The four Punk GLBs are rebuilt, and new palm and thumb tests cover rest and the guard. No clip moved.
  - The jab's lens-share ratchet went from 0.051 to 0.056.
  - The chain checks print YES: Punk `445edd69`, heat-map `14dfa420`.
- **The player's straight punches** (`m4/f-punch-turn`, `d6ccdf6`, call 28, Game-boy's request):
  - `_jab_1` and `_jab_2` roll the fist about 90 degrees: 27 degrees in the lower arm and 63 in the hand. It lands palm-down, 34-36 degrees from level because the forearm rises.
  - FistPoint moves 7 mm. The Punk's and dummy's punches aren't turned (`turn_fist` false).
  - New `tests/test_punch_turn.gd`, and the clip hashes are regenerated with a note.
- **After the merges:** regenerating the clip hashes and the M3 deformation table changed nothing. Regenerating the strain table loosened some limits (ratchets only tighten), so the committed table was kept; it passes. README's departures list the punch change as approved.
- **Next:** show Game-boy the crops and the run command. Still open from the DM: the four feel switches, the departures, the damage-mark and arm-knob calls, and the Tripo account type. PR #4 stays unmerged until his sign-off.

### 2026-11-02 21:20 CDT: Game-boy's second note (the player's straight punches land palm-down); F-punch-turn running beside F-fist-turn
- **Game-boy's words** (session chat): "Another fix to hand positioning: this time for the player-character. When the player throws a straight punch, the fist should turn 90 degrees so that the curled fingers angle down toward the ground (rather than inward toward each other)."
  - The lead logs it as call 28: his own request, and a departure from A20's frozen active-frame poses.
- **Running since 21:20 CDT:** F-punch-turn (`wf_f7031a7b-dac`, `workflow-build.js` with `docs/reviews/M4/args-F-punch-turn.json`, worktree `.worktrees/m4-f-punch-turn`, branch `m4/f-punch-turn`).
  - **Scope:** re-roll the forearm and hand in `_jab_1` and `_jab_2`'s strike so the fists turn 90 degrees and land palm-down. The twist is split between LowerArm and Hand. FistPoint stays within 1 cm, and a new `tests/test_punch_turn.gd` covers it.
  - **Beside it:** F-fist-turn (the Punk's guard, `wf_172ba303-da5`) is still running.
  - **If cut off:** rerun each with its args.
- **Merge note:** both builders may regenerate `tests/fixtures/motion/move_clip_hashes.json` and the strain and M3-deformation fixtures. Merge F-fist-turn first, then F-punch-turn. On a conflict in those generated files, take either side, then regenerate with `gen_clip_hashes.tscn`, `gen_strain_ratchet.tscn` and `gen_m3_deformation.tscn` on the merged head. Then run the full suite and the chain checks.

### 2026-11-02 20:50 CDT: Game-boy played M4: the Punk's hands turn the wrong way in the guard; the rest of the art "looks pretty good"; F-fist-turn running
- **Game-boy's words** (in the session chat, after running `godot --path /Users/arachne/repos/beat-em-up-PoC`; the PR's GitHub files 404 for him, so the run command is his route): "main problem I see with the punk's art is that his hands don't turn the right way — his curled fingers are facing outward instead of inward when he has his hands up to fight. The rest of the art looks pretty good, though."
  - **The lead's look:** in the C2 guard the viewer sees each fist's palm side, curled fingers outward and thumbs on the outside.
  - **Likely cause:** the fist piece meets A5 (palm to the midline at rest), and the guard pose's forearm/hand roll turns it palm-forward. M3's symmetric box fists never showed this. The builder confirms which before fixing.
- **Also fixed (`3c463df`):** his run printed `ERROR: Invalid polygon data, triangulation failed` from `hud_style.gd` `_draw_fill` via `enemy_health_bars.gd`.
  - **Cause:** a head just in front of the camera plane projects millions of pixels off screen, the bar was still drawn there, and float precision collapsed its fill. A probe confirmed it: the fill fails from about 1e5 px off-canvas.
  - **Fix:** `EnemyHealthBars.is_drawn()` now skips a bar whose gauge doesn't overlap the canvas. There's a new test in `test_health_bars.gd`, and the full suite is running.
- **Running since 20:50 CDT:** F-fist-turn (`wf_172ba303-da5`, `workflow-build.js` with `docs/reviews/M4/args-F-fist-turn.json`, worktree `.worktrees/m4-f-fist-turn`, branch `m4/f-fist-turn`). It diagnoses the piece against the pose, fixes the root cause with a test, re-records C2, C4 and C11 with before/after crops, and checks the hero's fists. **If cut off:** rerun it with the same args.
- **Next:**
  1. Merge it with A22 and the chain checks; check the guard crops.
  2. Copy its call 27 into `M4-judgement-calls.md` if it re-rolled a clip.
  3. Show Game-boy the before/after in this chat (or the DM), with the run command again.
  4. He hasn't yet answered the other open items (the feel switches, the departures, the damage-mark and arm-knob calls, the Tripo account type); ask once more after the hands are fixed. PR #4 stays unmerged until his sign-off.

### 2026-10-29 02:55 CDT: handoff at the weekly limit (90%); nothing running; still waiting on Game-boy's M4 judgement
- **Why:** the usage watcher's message. The weekly window is at 90% and resets 2026-11-02 10:00 UTC; the 5-hour window is at 55%.
- **State:** unchanged since the 18:35 entry below.
  - Milestone 4 is delivered on `m4/art-pipeline` (`ff5976a`, pushed; nothing uncommitted).
  - PR [#4](https://github.com/mikedtcm22/beat-em-up-PoC/pull/4) is open into `main` and **not merged**.
  - The final DM went out 2026-10-27 18:33-18:35 CDT.
  - No workflow, agent or builder is running.
- **Game-boy:** no reply yet, and no thread reply, as of 02:50 CDT on 2026-10-29. He's waiting for nothing from us; we're waiting on:
  - his yes, or the failing item numbers;
  - the four FP feel switches;
  - the departures;
  - the damage-mark and arm-knob calls;
  - the Tripo account type.
- **Worktrees:** every `.worktrees/m4-*` worktree is clean, except `m4-fix-final-punk-spawn-cache-before-recut`. That one is detached at `aa6b5cd` and holds the throwaway, uncommitted act edits that re-cut M3's before side for C5, C9 and C13. Remove it with `git worktree remove --force` once the DM's media are no longer needed.
- **Resume steps** (the resume task `beat-em-up-resume-20261102-1000` fires 2026-11-02 04:10 CST):
  1. Read Game-boy's DM (D0AQUKX5DB6) for a reply after message `1793144123.040919`, including threads.
  2. **No reply:** nothing to build. Leave the PR open, don't merge, and don't DM him again unless something needs him.
  3. **A reply with failing items or changes:** plan them as fix packages with the same runners (see the 18:35 entry's "When he answers"), then re-record and reply in the DM.
  4. **Sign-off:** merge PR #4 on his word only. Record his approved departures in README's "Where M4 departs from the spec" (turn "for Game-boy to rule on" into "approved by Game-boy"). Remove the M4 worktrees, and start Milestone 5 per SPEC §12.

### 2026-10-27 18:35 CDT: Milestone 4 delivered; PR #4 open; the final DM sent; waiting on Game-boy (pause 2)
- **The DM to Game-boy** (Slack D0AQUKX5DB6, from 18:30 CDT), in order:
  1. The main message: the run command as a bash block, the A23 question word for word, the 14 numbered rubric items with the re-score (mean 1.50), and the post-re-score fixes.
  2. The M3/M4 pair at 1 m and three concept stills (Punk at 1 m, Punk full figure, hero C against his first-person limbs).
  3. Three clips: the long take (5.4 MB), the six-Punk fight (8.0 MB), his arms and legs (1.6 MB).
  4. The five-line metrics and the unmet plan bars.
  5. The four feel questions with their A/B stills.
  6. The departures, his two look calls (the damage marks; the arm knob), the Tripo licence question and the hero-menu note.
  7. The judgement-call digest.
- **The DM media:** `captures/m4/dm/out/`, re-recorded on `e78c156`; the hero concept pair and the feel stills come from `.worktrees/m4-p3-evidence/captures/m4/evidence/`. Keep both until sign-off.
- **PR [#4](https://github.com/mikedtcm22/beat-em-up-PoC/pull/4)** into `main` is open, with no CI. **Never merge it until Game-boy signs off.**
- **Waiting on Game-boy:**
  - his yes, or which numbered items fail;
  - the four feel switches;
  - the departures;
  - the damage-mark and arm-knob calls;
  - the Tripo account type.
- **When he answers:** turn each failed item or change into a fix package with the same runners (`workflow-build.js` for builds, `workflow-review.js` with `findings_path` for fix-only runs). Merge with A22 and the chain checks, re-record what changed, and reply in the DM thread. When he signs off, merge PR #4 (only on his word), record his approved departures in README, and start M5 per the spec.
- **Worktrees** from this round can be removed after sign-off: `.worktrees/m4-*`. Keep `m4-p3-evidence` until the DM's media are no longer needed.

### 2026-10-27 18:25 CDT: the re-score's fixes merged (1599/1599); PR #4 open; the DM media re-recording
- **Merged:** `m4/fix-rescore-punk-art-chain` (`16f96e2`) and `m4/fix-rescore-placeholder-matte` (`a04bfb0`).
  - The lens glint is gated by two authored streaks per eye (the mask's G channel), so a tipped-back head no longer whites out the shades. `look_glint_cut` is now 0.81.
  - Normal smoothing is now 12 rounds, so the face falls into two clean bands.
  - Strokes are cleaned at 1k (dots joined and dropped).
  - The glove and cuff carry authored ink lines.
  - Placeholder matte paints take no highlight.
  - The suite on `e78c156` is 1599/1599 with 0 error lines. The Punk, probe, hero and heat-map `--check` all print YES (Punk `c4a510ff`, heat-map `6709a408`). README carries the scores.
- **PR [#4](https://github.com/mikedtcm22/beat-em-up-PoC/pull/4)** is open into `main`. Never merge it before Game-boy signs off.
- **Running:** the lead's re-record of the DM media on the final head, in `captures/m4/dm/` (c1, c2, c10, c14, pa1, six), one act per process. Then the pairs (M3 left from `captures/m4_before/`), the concept pairs, and clips 1-3 (1280x720 H.264, AAC 96k, at most 10 MB). The feel A/B stills from P3-evidence stay valid: the switches didn't change.
- **Next:** the final DM to Game-boy (D0AQUKX5DB6), per A23 and the task:
  - the run command as a code block;
  - the ask, word for word;
  - the numbered rubric with the scores;
  - the pair, the concept stills and the three clips;
  - the five-line metrics;
  - the four feel questions with their A/B stills;
  - the departures;
  - the digest of judgement calls;
  - credits;
  - the Tripo licence question;
  - the hero-menu note.

### 2026-10-27 17:30 CDT: P3-evidence merged (the index and JSON files); the re-score's fixers still running
- **Merged:** `m4/p3-evidence` (`47251d3`): `docs/reviews/M4/evidence/index.md` and five JSON files, all docs.
  - **Recordings:** 26, every bot.log with 0 error lines. The media is local in `.worktrees/m4-p3-evidence/captures/m4/evidence/` (keep that worktree until the DM is sent).
  - **The DM pair:** `pairs/c2/stills/c2_f109_idle_t060_m3_left_m4_right.png`.
  - **The concept pairs:** in `concept_pairs/`.
  - **The clips:** `clips/long_take_1m_c14.mp4` (5.2 MB), `six_punk_fight_2_to_10m.mp4` (7.7 MB) and `own_limbs_pa1.mp4` (1.6 MB).
  - **The four feel A/B pairs:** in `feel_ab/`. Exact commands and calls are in `docs/milestones/M4-calls/P3-evidence.md`.
  - **Caveat:** it was recorded on `6e2a2e1`, before the re-score's fixes. After those merge, re-record the DM pair, the concept pairs and clips 1 and 3 (the long take shows the lens whiteout the fix removes), using the commands in that calls file.

### 2026-10-27 17:20 CDT: the re-score passes at the bar (mean 1.50); its two fix packages running beside P3-evidence
- **The re-score on `f4064a4`:** J1 2, J2 1, J3 1, J4 1, J5 2, J6 2, J7 2, J8 2, J9 1, J10 2, J11 1, J12 2, J13 1, J14 1.
  - That is a mean of 1.50, with no 0 and every critical item at 1 or more, so Part B's rule passes with zero margin. J1, J5 and J7 moved up from 1.
  - **Findings:** five, all confirmed. They're in `docs/reviews/M4/rescore-findings.json` with the lead's order (call 26).
    - The lens glint whites out the shades whenever the head tips back (a regression from the gloss fix).
    - The striking glove's back is a featureless dome.
    - The 1k ink strokes are sawtooth and dotted.
    - The face's bands are faceted (normal smoothing stopped at 6 rounds).
    - The placeholders keep a hard highlight beside the matte Punk.
  - **Per-item suggestions:** the re-scorer's "one change per item still at 1" is in its summary in that file.
- **Running since 17:15 CDT:** `wf_c36f16ac-f73`, round `rescore`, base `de24472`, two fixers: punk-art-chain (rs-01, -04, -03, -02 in that order) and placeholder-matte (rs-05). The worktrees are `.worktrees/m4-fix-rescore-<key>`. P3-evidence (`wf_7aae052c-809`) is still recording on `f4064a4`. **If cut off:** rerun with the same args.
- **Next:**
  1. Merge the two fixers with A22, including the chain checks.
  2. Check the lens, glove, strokes and face from stills.
  3. Merge P3-evidence.
  4. Re-record only the DM's clips, pairs and concept stills on the fixed art: a small builder, or the lead.
  5. README's scores line, the PR (not merged) and the final DM.

### 2026-10-27 16:35 CDT: both fix waves merged (1593/1593, 0 errors); the re-score and the evidence pack running
- **Merged:**
  - **`m4/fix-final-toon-gloss-and-turntable`** (`405d223`):
    - Per-swatch gloss: a glossy swatch is one step below its damage-class alpha. Only the Punk's lens is glossy, and it gets a camera glint (`look_glint_cut` 0.88, `look_glint_strength` 1.0). The matte vest, arms and cap lost their highlight blobs (about 3,840 pixels down to 8).
    - The C10 turntable hides the hero and films the Punk's front.
  - **`m4/fix-final-done-when-ratchets-and-suite-time`** (`c86a279`):
    - A7's ratchet can fail now: per art, plus a per-clip table in `tests/fixtures/strain/strain_ratchet.json`.
    - The done-when ratchets are set on the final art.
    - `PlaceholderAnims.Life` reads TuningData.
    - The suite takes 267 s of test time, down from 335 s.
    - stagger_back is re-posed with bent elbows (call 24; the four clip hashes regenerated with a reason note).
  - A22: the preset (519 values) and the atlas matched what's committed. The suite on `f4064a4` is 1593/1593 with 0 SCRIPT, SHADER or ERROR lines.
- **The lead's look:** the stagger reads as a body knocked back with a broken guard. The Punk's cloth is clean and matte, with one white glint on the lens.
- **Running since 16:35 CDT:**
  - **The re-score:** one Opus reviewer scores J1-J14 on `f4064a4` (`wf_b65f3d05-528`, round `rescore`, args in `docs/reviews/M4/args-review-rescore.json`, worktree `.worktrees/m4-review-rescore-rs`).
  - **P3-evidence:** a Sonnet builder records the evidence pack, the clips, the DM pair, the feel A/B stills and `docs/reviews/M4/evidence/` (`wf_7aae052c-809`, `workflow-build.js` with `docs/reviews/M4/args-P3-evidence.json`, worktree `.worktrees/m4-p3-evidence`, branch `m4/p3-evidence`).
  - **If cut off:** rerun each with the same args.
- **Next:**
  1. Merge P3-evidence.
  2. Put the re-score's figures in README (the scores line) and the PR.
  3. If the re-score's mean is under 1.5, say so honestly in the DM, with the re-scorer's "one change per item".
  4. Open the PR (never merged).
  5. The final DM per A23 and §9.2.

### 2026-10-27 15:25 CDT: punk-detail merged (1580/1580 on its branch); toon-gloss launches after the 15:50 reset
- **Merged:** `m4/fix-final-punk-detail-zones-and-strap` (`bb3f1f4`). The merged tree is its tested tree plus the lead's docs; the preset and palette are unchanged.
  - The Punk wears the sharp mask cut (`punk_art.tres` `metadata/detail_sharp`).
  - The cap's strap slot is an authored dark arch on edge loops, with no ink on the cap.
  - The laces and ankles carry no ink (laces 33.7% to 0%).
  - The face ink is 1.62% (a 1.75% margin test, 2.0% ceiling), with a nose zone.
  - **The lead's look:** a crisp mouth bar, a hooked nose stroke and a clean cap. The cap's highlight still washes over the arch: that's per-swatch gloss, toon-gloss's job.
  - **Left open:** black dashes on the jeans in the C5 landing (not mask ink); the arch is two stepped boxes.
- **Chain checks:** running now (the Punk, the probe, the hero and the heat-map build).
- **Next:** the 16:00 resume task wakes this session. Then launch toon-gloss-and-turntable (`packages_wave2` in `final-findings.json`), merge it, run the ratchets fixer, the re-score, the docs, the PR and the DM.

### 2026-10-27 14:55 CDT: art-chain-records merged (1578/1578); wave 2's punk-detail running; a resume task at 16:00
- **Merged:** `m4/fix-final-art-chain-records` (`3d2e00d`).
  - The probe report is regenerated (`--check` YES), with a Blender-free guard on the step report keys.
  - The hero's mask has two contract tests.
  - The ASSETS ledger, provenance and date rows are fixed, and the orphan `tests/scratch_measure.gd.uid` is removed.
  - The merged tree is its tested tree plus two doc files. The A22 chain checks are now in the plan's A22.
- **Running since 14:50 CDT:** wave 2's **punk-detail-zones-and-strap**, alone in the last headroom (`wf_a7ddd5a8-aff`, base `d82b195`, worktree `.worktrees/m4-fix-final-punk-detail-zones-and-strap`). It turns the sharp mask cut on for the Punk and tunes his mask, then the cap strap slot, the laces and the face ink. **If cut off:** rerun it with the same args (in the run's args); it continues from its newest `wip:` commit.
- **After the 15:50 reset:**
  1. Launch **toon-gloss-and-turntable**: `workflow-review.js`, `lenses` [], `packages` = the `packages_wave2` entry with that key (notes pointing at `final-findings.json`, `packages_wave2`), `findings_path` the same file, base = the head, and a `common_note` stating the merged state.
  2. Merge both wave-2 branches with A22, including the chain checks. ASSETS's Punk rows may conflict with art-chain-records' dates: refresh the dates.
  3. Run **done-when-ratchets-and-suite-time** (in `packages.packages`; includes the stagger_back re-pose, call 24).
  4. Then one Opus re-score of J1-J14 on fresh recordings.
  5. Then README, the evidence index, the PR and the final DM.
- **Resume task:** `beat-em-up-resume-20261027-1550` fires at 16:00 CDT, so the work continues even if nothing else wakes the session.

### 2026-10-27 14:40 CDT: wave 1's two fixers merged (1575/1575); art-chain-records running; then wave 2, then the ratchets
- **Merged:** both branches went in with no conflicts, then A22: the preset (517 values) and the palette. The suite on `3aa6f9a` is 1575/1575 with 0 SCRIPT, SHADER or ERROR lines.
  - **`m4/fix-final-toon-light-and-ink`** (`30f88f3`):
    - `look_fill_strength` 0.8 to 0.4: front-lit characters keep the sun's bands, and L2 is now MET.
    - The hero's mask ink is cut sharp: `look_detail_cut` 0.15, through `player_art.tres` `metadata/detail_sharp`, so the Punk's art is still the soft mix until wave 2 turns it on. The hero's mask was also cleaned of blots.
    - The own-body hull now measures 3.85/3.74/4.05 px (top is 0.05 over its bar, a soft row).
    - `player_parts.py`'s literals moved into `pipeline.json`.
    - Call 14's reason is corrected.
  - **`m4/fix-final-punk-spawn-cache-and-evidence-acts`** (`8e211dc`):
    - `RoomKit.warm_art()` holds `punk_art.tres` in a static, so a wave's first Punk no longer re-reads its GLB (about 19 ms down to 1-4 ms, headless).
    - C5 and C13 tip the view to -35 degrees for the KO.
    - C9's cast stands off the tour's path.
    - The M3 before side was re-cut for those three acts into `captures/m4_before_recut/` (use these as the A23 before pairs). Its worktree `.worktrees/m4-fix-final-punk-spawn-cache-before-recut` can be removed.
- **The lead's look:** fill 0.4 gives the Punk's vest and face real violet shadow shapes (comic cel), and the hero's wraps are solid black strands where they were grey smears.
- **Running since 14:40 CDT:** art-chain-records, alone (`wf_de024c6a-d0d`, base `3aa6f9a`): the probe report's `--check`, a contract test for the hero's mask, the ASSETS rows and the orphan `.uid`. **If cut off:** rerun it with the same args (in the run's args; its worktree is `.worktrees/m4-fix-final-art-chain-records`).
- **Next, in this order** (the files overlap):
  1. Merge art-chain-records.
  2. Wave 2 (`packages_wave2` in `final-findings.json`), two fixers at once: toon-gloss-and-turntable (per-swatch gloss; turn the sharp ink on for the Punk and check his lines; the C10 front) and punk-detail-zones-and-strap.
  3. done-when-ratchets-and-suite-time last, so the ratchets are set on the final art (plus the stagger_back re-pose, call 24).
  4. Then one Opus re-score of J1-J14.
- **Usage:** 82% of the 5-hour window at 14:35 (reset at 15:50 CDT). Expect the watcher's 90% message. Wave 2 waits for the reset.

### 2026-10-27 14:10 CDT: V1 reviewed; every J item scored, mean 1.29 (bar 1.5); wave 1 fixing, wave 2 planned
- **V1's scores:** J1 1, J2 1, J3 1, J4 1, J5 1, J6 2, J7 1.
  - **All 14 items:** J1 1, J2 1, J3 1, J4 1, J5 1, J6 2, J7 1, J8 2, J9 1, J10 2, J11 1, J12 2, J13 1, J14 1.
  - That is a mean of 1.29 against Part B's 1.5. There are no 0s, and every critical item is at least 1.
  - The fixes aim at the 1s. After both waves merge, one Opus re-score of J1-J14 from fresh recordings decides the pass, and it is reported honestly to Game-boy either way.
- **V1's findings:** 7, of which 6 survive. All of them, with the lead's rulings, are in `docs/reviews/M4/final-findings.json` (V1's entries plus `packages_wave2`).
  - **The biggest:** the 1k detail mask is mixed raw and bilinear, so every interior ink line is a soft, dotted smear (final-v1-01). It's the same root cause as the hero's final-v3-01, which wave 1's toon-light-and-ink is fixing.
  - Per-swatch gloss: the highlight lands on matte cloth and never on the shades (v1-04).
  - The cap's strap slot is ragged (v1-03), the laces carry black speckle (v1-05), and the face ink sits one sample under its ceiling (v1-06).
  - The C10 turntable never films the Punk's front (v1-07).
  - The small-hands finding (v1-02) is refuted, and the lead agrees: it matches the concept and A5's box.
- **Wave 1** (`wf_e45d9467-fd5`, running since 13:45 CDT, two at a time): toon-light-and-ink and punk-spawn-cache-and-evidence-acts are running. done-when-ratchets-and-suite-time and art-chain-records come next if the gate has room. Otherwise rerun the same args (`docs/reviews/M4/args-review-final-fix.json` plus the run's `common_note`) after the 15:50 CDT reset. The finished packages replay from their branches.
- **Wave 2 waits for wave 1's merge:** both its packages share files with wave 1.
  - **toon-gloss-and-turntable:** v1-04, v1-01 checked on the Punk, and v1-07.
  - **punk-detail-zones-and-strap:** v1-03, v1-05, v1-06.
  - **Launch:** `workflow-review.js` with `lenses` [], `packages` = `packages_wave2` (compact notes pointing at the file, as in `args-review-final-fix.json`), `findings_path` the same file, base = the merged head, and a `common_note` stating the merged state.
- **Usage:** 78% of the 5-hour window at 14:03 (reset at 15:50 CDT), 45% weekly. The watcher (`local_618146a1`) is alive. Expect its 90% message during wave 1.

### 2026-10-27 13:50 CDT: V2-V6 reviewed (16 of 24 findings survive); four fixers running; V1 still reviewing
- **Scores:** V2: J8 2, J9 1, J10 2, J11 1, J12 2. V3: J14 1. V4: J13 1, plus second opinions J4 1 and J5 1. No item scores 0. V1 (J1-J7) is still running.
  - The findings, the verdicts, the partition and the lead's overrides are in `docs/reviews/M4/final-findings.json`.
  - **Overrides:** final-v2-01 (stagger_back's straight arms) is IN as call 24. final-v2-02 (whole-body damage marks) and final-v3-03 (the hero's arm knob, call 19) go to Game-boy (call 25).
- **Running since 13:45 CDT:** the fixers only. Workflow `wf_e45d9467-fd5`, `workflow-review.js` with `docs/reviews/M4/args-review-final-fix.json` (its `common_note` is in the run's args). It runs two at a time, each gated on usage. The worktrees are `.worktrees/m4-fix-final-<key>` and the branches `m4/fix-final-<key>`.
  - **toon-light-and-ink:** the camera fill flattens front-lit bands (L2/J5); the hero's mask ink is soft; the own-body hull's L1 figures; the hero chain's literals.
  - **punk-spawn-cache-and-evidence-acts:** the warm-up's art cache dies, so each wave's first Punk re-reads its GLB (about 19 ms); C5's KO framing; the C9 tour walks into its cast.
  - **done-when-ratchets-and-suite-time:** ratchets that can't fail; Life's copied defaults; the suite's skinning cost; the stagger_back re-pose.
  - **art-chain-records:** the probe report's `--check` NO; a contract test for the hero's mask; stale ASSETS rows; an orphan `.uid`.
  - **If cut off:** rerun with the same args. A package whose branch has a `wip:` commit continues from it, and a skipped package runs once there's room.
- **Usage:** the 5-hour window was at 67% at 13:40 and resets at 15:50 CDT. The gate skips any fixer that doesn't fit; rerun the same args after the reset.
- **Next:** when V1 finishes, partition and fix its findings as a second wave (lenses [], its packages, the findings file extended). Then merge every fix branch with A22.

### 2026-10-27 13:35 CDT: F-cuff merged (`44b1a7e`); V1 running beside V2-V6
- **Merged:** `m4/f-cuff` (`682ebbc`, 1561/1561 on its branch). It merged cleanly onto its own base plus two doc files, so the tested tree is the merged tree. The preset and palette were regenerated (`--check` passes).
  - **The cuff:** each glove's cuff is now a band that follows the forearm, 7.1 cm long and at most 5.8 cm from the arm's axis (8.6 before). The flange is gone.
  - **A9:** the lens-share bar now misses in the jab and the cross at +8 degrees (4.7-5.1 points against 4). Those poses are ratcheted per pose and print the plan's bar (call 22).
  - **The lens:** back to the cap's yellow (#e8bd2e) in the dark frame. The A/B showed the cream reading as a khaki visor. The shades test now asserts the frame instead of a colour distance.
  - **Probe fixture:** F-cuff found that its `--check` reports NO (hash `b61973f6` against `c8a83e6a`) on the merged base, before F-cuff's changes. That's for V5 or the fixers.
- **The lead's look:** the guard at 1 m reads as fingerless gloves on wrist cuffs, and the yellow shades in their frame read as the concept's goggles.
- **Running since 13:35 CDT:** V1 (the Punk standing at 1 m, J1-J7): workflow `wf_febf38e3-d3b`, round `final`, base `44b1a7e`, worktree `.worktrees/m4-review-final-v1`. V2-V6 (`wf_f116f808-22a`) are still running on `3eea29a`.
- **Next:** when both are done, rerun `workflow-review.js` with all six lenses, `reviews` and `verdicts` from both journals, `no_fix` false and base `44b1a7e`, so the fixers run.

### 2026-10-27 12:38 CDT: the fix round merged (1561 tests, all passing); F-cuff and the final review (V2-V6) running
- **Merged:** `m4/f-punk-fix` (`891b7b1`), `m4/f-player-fix` (`7faf7ce`) and `m4/p3-int` (`60d35c1`), with no conflicts. Then the A22 routine: the preset, the palette atlas (23 swatches, `--check` passes) and the import. The full suite was 1560/1561 with 0 SCRIPT, SHADER or ERROR lines. The one failure was `test_m4_done_when`'s A1 mesh list, which P3-int wrote before F-player-fix added `Body__fp_torso`. It's fixed in `3eea29a`, and the done-when file passes 18/18. Also in `3eea29a`: two stray `.uid` files F-punk-fix committed in `tests/` are removed, and the F-player-int paragraph "The hull" is updated, since P3-int moved that code.
  - **F-punk-fix:**
    - a clean dark glove collar (no yellow, no slivers);
    - a cream lens (#e6dcc4) in a dark frame;
    - smoothed shading normals (`pipe_normals.py`; the blotches);
    - the face's own ink thresholds (the speckle);
    - 14,299 triangles.
  - **F-player-fix:**
    - The legs and shoes were inside out: `player_parts` recalculated every normal at the split. That, not the swatch, made the front kick's shoe black.
    - convex 4 cm domes at the arm cut and the belly top;
    - 4,000-triangle fists with clean label borders;
    - `Body__fp_torso` (the knockdown slab is 43% of the view off and 19% on);
    - the hero's A9 as a ratchet;
    - 29,320 triangles; no Tripo retry.
  - **P3-int:**
    - `ToonMaterials.outline(first_person)` (T8 byte-identical);
    - A19 on both shipped GLBs (Punk p99.9 4.12, hero 8.67, printed as GATE lines);
    - `tests/test_m4_done_when.gd`: PASS on A1, A2, A3, A5, A8, A10, A12, A13 and A14; GATE with a ratchet on A4 (the hero's walks), A6 (the hero's legs, 89.4%), A7, A9 and A11;
    - the act 'Look: final probe' (L1 and L2 missed, L3 and L5 met, on the pre-merge art).
  - **Tripo:** still 295 credits; the fix round spent none.
- **The lead's look** (full-resolution before and after stills beside the concepts):
  - The hero's fixes all read: a convex arm end with no ink fan, a lit charcoal shoe with a cream sole in the front kick, clean fingers in the look-down.
  - The Punk's head now reads as a cap, a pale visor and a face, and the yellow and slivers are gone.
  - Two Punk items are left:
    - The collar is a wide flat flange under each fist (a "plunger base"). A9's 4-point lens-share bar forced it, because the art is slimmer than the proxies' fist box.
    - The lens is cream, where the concept's is gold.
  - Judgement call 22: the cuff follows the concept, and a pose that misses the share bar becomes a ratchet. Call 23: the review runs beside F-cuff, with V1 held.
- **Running since 12:40 CDT:**
  - **F-cuff:** workflow `wf_990bebea-f76`, `workflow-build.js` with `docs/reviews/M4/args-F-cuff.json`; worktree `.worktrees/m4-f-cuff`, branch `m4/f-cuff`. It reshapes the cuff into the concept's wrist band and A/Bs the lens (the cap's yellow inside the dark frame, against the cream). **If cut off:** rerun it with the same args; it resumes from the branch.
  - **The final review, V2-V6:** workflow `wf_f116f808-22a`, `workflow-review.js` with `docs/reviews/M4/args-review-final.json` (round `final`, base `3eea29a`, `no_fix` true, one skeptic per finding). The worktrees are `.worktrees/m4-review-final-<lens>`. **If cut off:** rerun it with the same args, plus `reviews` and `verdicts` from the journal (`subagents/workflows/wf_f116f808-22a/journal.jsonl`) for the agents that finished.
- **Next:**
  1. Merge F-cuff (A22) and look at its stills.
  2. Run V1 (the Punk standing at 1 m, J1-J7) as round `final` with base = the merged head.
  3. Run the fixers: rerun `workflow-review.js` with all six lenses, `reviews` and `verdicts` from both runs, and `no_fix` false.
  4. Then README's M4 sections, the evidence pack index, the PR (not merged) and the final DM.
- **The review's scores:** `workflow-review.js` gained a required `scores` field (J1-J14, each 0, 1 or 2 with evidence) for Part B's pass rule. The rule: no 0s, every critical item at least 1, and a mean of at least 1.5.

### 2026-10-27 11:30 CDT: F-punk and F-player-art merged (1533/1534, the hero's A9 the one red test); the fix round running
- **Merged:** F-punk (`08ddacf`) and F-player-art (`159eefb`), then the A22 routine on the combined head: the preset regenerated (516 values), the palette atlas regenerated (23 swatches, `--check` passes), the ARCHITECTURE add/add resolved by keeping both headings, and the full suite 1533/1534 with 0 SCRIPT, SHADER or ERROR lines. The one failure is `test_art_player`'s hero A9 against FPView's proxies (10 poses), which F-player-fix turns into a ratchet (call 20).
  - **F-punk:** Street Punk A from T4 (front, left and back views), T8 rig and T9 glove fist; 14,984 triangles, 7 slots and 6 colours, with A18's 1k detail mask wired in `punk_art.tres`. A6 is asserted at 95% (torso 100, legs 95.3, head 99.9). Still missed and ratcheted: visible stretch 8.4 cm (the waist hem in the cross's twist), A9's cells 6.6%, and A11's torso anchor 6.0 cm. 135 credits.
  - **F-player-art:** Hero C from T11 body, T12 rig and T13 wrapped fist; Body plus Body__fp_hidden, 26,418 triangles; `player_detail.png`. The game wears it now. No Body__fp_torso, since the shared exporter and the contract allow only two meshes. The one red test was the hero's A9 against FPView's proxies (1529/1530 on its branch). 105 credits.
  - **Tripo:** the ledger stands at 295 of the 750 stop; the balance is 1205.
- **The lead's look** (full-resolution stills beside the concepts):
  - The Punk reads as concept A: the backwards cap, the shades, the teal vest over a dark tank, pale jeans, the taped left forearm and the fingerless gloves.
  - The Punk's faults: yellow gauntlet cuffs that aren't in the concept (our brief asked for "an accent strap"), the cap and lens sharing one yellow, face speckle, and blotchy bands on the vest and forearms.
  - The hero's look-down, guard and haymaker read as wrapped, gloved fists.
  - The hero's faults: his jab, cross and hook show the bare elbow half of the upper arm as a stump ending in the flat cut cap (the probe frames the same way; it is M3's rule), lumpy fingers, and a near-black shin and shoe in the front kick.
  - Judgement calls 18-21 record these choices.
- **Running since 11:45 CDT:** workflow `wf_c5861a1d-df2`, `workflow-build.js` with `docs/reviews/M4/args-F-fix.json`; the worktrees are `.worktrees/m4-f-punk-fix`, `m4-f-player-fix` and `m4-p3-int`, on branches `m4/<key lower-case>`. **If cut off:** rerun it with the same args (`resumeFromRunId` in this session); the runner resumes each package from its branch. The three builders run at once:
  - F-punk-fix (Blender): the cuffs, the shades, the speckle and the blotches.
  - F-player-fix (Blender): a rounded cap at the cut, the fists, the shoe value, Body__fp_torso, and the hero's A9 as a ratchet (call 20).
  - P3-int (Godot): `ToonMaterials.outline(first_person)`, the real GLBs in A19, `test_m4_done_when.gd` and `look_probe` final.
  - Then the six-lens review round, its fixes, README's M4 section, the PR (not merged) and the final DM.

### 2026-10-27 09:05 CDT: Game-boy picked Street Punk A and Hero C; F-punk and F-player-art running
- **The pick** (09:00 CDT, in the working session's chat, not the DM): Street Punk A (`punk_a_denim_vest.jpg`, the concept the smoke stand-in was built from) and Hero C (`hero_c_martial.jpg`, whole, no mix and match). His words are in the decisions log and in each brief. He also wants a menu of hero options later; that is not M4, but F-player-art keeps the hero in files so a second hero needs no code change.
- **Running since 09:04 CDT:** workflow `wf_63ca3032-218`, `workflow-build.js` with `docs/reviews/M4/args-F-art.json` (both packages, two Sonnet builders, one Blender slot each):
  - F-punk: `.worktrees/m4-f-punk`, branch `m4/f-punk`. Views, T4-T10, about 145 credits; replaces `punk.glb` in place.
  - F-player-art: `.worktrees/m4-f-player-art`, branch `m4/f-player-art`. Views, T11-T14, about 185 credits; writes `assets/export/characters/player/player.glb`.
  - They share the 750-credit stop (the ledger stands at 55) and each reads the ledger before a paid call.
  - **If cut off:** `Workflow({scriptPath: "/Users/arachne/repos/beat-em-up-PoC/docs/reviews/M4/workflow-build.js", resumeFromRunId: "wf_63ca3032-218", args: <args-F-art.json>})` in this session, or relaunch it fresh with the same args; the runner resumes each package from its branch.
- **The watcher** was told the pick arrived and no longer reads the DM for it.
- **Next:** merge each with the A22 routine as it lands, then P3-int proper, the final six-lens review, fixes, README's M4 section, the PR (not merged) and the final DM.
- **Usage at launch:** 5-hour 12% (resets 15:50Z), weekly 29%.

### 2026-10-27 07:00 CDT: P3-flash merged (1530/1530); all pick-independent work is done; waiting on the pick
- **Merged:** P3-flash (`bf7b0ab`, suite 1530/1530, 0 SCRIPT, SHADER or ERROR lines; the ARCHITECTURE add/add resolved by keeping both headings). The preset is at 516 values.
  - Feel question 1: `hit_flash_fp_max_share` (0 = off) stretches the flash's on-screen disc to a cap. Suggested 0.12: the hold's knee goes from 20.8% to about 5% of the view, but an ordinary jab's flash shrinks by about 40%.
  - Feel question 2: `hit_flash_finisher_radius_mult` (1.0 = off). Suggested 2.0: the haymaker goes from 0.3% to 7.3%.
  - `RoomKit.warm_up_libraries()` warms the Bruiser and boss libraries: a first spawn is 3-4 ms, against about 30 ms cold.
  - The VFX need no change under the linear tonemapper.
  - The left-over list's warm-up and VFX items are done.
- **The judgement calls log** has 17 entries, including the four feel toggles with their measured suggestions.
- **Pick watch:** the usage watcher was asked (06:55) to read the DM on each check and message this session "Game-boy replied in the DM at <time>" when he replies. The one reminder went at 04:37, and no other DM goes to him.
- **The lead's perf A/B** (07:20; M3 `afdb39e` against `bf7b0ab`; vsync on; load 2.4-4.6 from other apps, so noisy in absolute terms, with the refs interleaved; logs in `captures/perf_compare/a16-int/`):
  - "Perf, six with ragdolls": mean 12.17 against 14.73 ms (+2.6), p95 +4.2, spawn hitch +3.3.
  - First spawn is -0.6 (ok; the gate run had +1.0 before the warm-up fixes).
  - First hit is +3.2, missing A16's soft +2 bar. The gate run had +1.4, so this is within this load's noise; P3-int's quiet run decides it.
  - "Look: Perf, six art Punks": 14.89 ms mean, and 11.85 with FXAA (about M3's level; one FXAA run had a 278 ms first-hit spike).
  - M3 itself misses the 16.7 ms p95 bar on this machine with vsync on.
- **On the pick:** `docs/reviews/M4/args-F-art.json` is ready (both packages, `blender: true`). Replace `<PICK_PUNK>` and `<PICK_HERO>` with his exact words, record the pick in the decisions log, and launch it through `workflow-build.js` (both run at once). They share the 750-credit stop, and each checks the ledger before a paid call.
- **Left for after the pick:**
  1. F-punk: views, T4-T10, about 145 credits. Its brief carries gate gaps 3, 4, 5, 7, 9 and 13, the lens and cap swatch marks, a glove swatch value of 0.3 or more, a cuff radius from the wrist, and A18's detail mask, which goes to README for Game-boy's ruling.
  2. F-player-art: views, T11-T14, about 185 credits. The GLB goes to `assets/export/characters/player/player.glb`, optionally with `Body__fp_torso`.
  3. P3-int proper:
     - `test_m4_done_when`, `look_probe` final, and re-recording c14, c15, l5, ff1-3, pa1-2 and C1-C13 on the real art;
     - `ToonMaterials.outline(first_person)`, so player.gd stops calling `_hull`;
     - the real GLBs added to the A19 strain run;
     - the final perf A/B.
  4. Then the final review round (six lenses), fixes, the README M4 section, the PR (not merged) and the final DM.

### 2026-10-27 06:40 CDT: F-player-int merged (1507/1507); P3-flash running; then only pick work is left
- **Merged:** F-player-int (`f2f987c`, suite 1507/1507, 0 SCRIPT, SHADER or ERROR lines).
  - The player wears CharacterArt through CombatActor.art. `player_art.tres` names `assets/export/characters/player/player.glb` in metadata, and a missing file means M3's primitives with no warning.
  - The probe body is worn behind the Debug switch `look_player_art_probe`. `Body__fp_hidden` is on layer 2.
  - `test_art_player`: the lens rules on the skinned probe. A hold's nearest forearm or hand is 0.320 m, the own body at most 25.1% of the view, and the KO view's nearest vertex 0.344 m.
  - Feel question 3 (`fp_knockdown_hide_torso`) is wired, default off: 74% to 15% on primitives, 37% to 0% on the probe. On art it hides the whole visible body unless the hero GLB adds a `Body__fp_torso` mesh.
  - New acts: 'Look: my arms and legs' (pa1) and 'Look: my knockdown' (pa2). Record them with `CAPTURE_ARGS=--tune=look_player_art_probe=1`.
- **Requests carried:**
  - `ToonMaterials.outline(first_person)` plus RigPaint, so player.gd stops calling `ToonMaterials._hull` (P3-int).
  - F-player-art: put the hero GLB at the path above; it is worn with no edit. Optionally add `Body__fp_torso`.
  - The lead adds the hero and the real Punk to `test_skinned_art`'s A19 strain run.
- **Running:** P3-flash (`wf_d718820d-4e0`).
- **Concept pick:** none (DM read at 06:35).
- **Usage:** 5-hour 9%, weekly 29%.

### 2026-10-27 05:55 CDT: P3-early and F-look merged (1491/1491); F-player-int running on the probe body; still no pick
- **Merged:**
  - P3-early (`c5878fa`, suite 1472/1472):
    - the long take c14 and the F4 showcase on one script;
    - the L key log toggle and `combat_log_hide_while_holding` (feel question 4);
    - Motion libraries rebuilt live, and a per-rig idle phase for the crowd;
    - the ragdoll write-back test on a real StreetPunk;
    - the face-down evidence, and the L5 act. With the art drawn, R8 is within 0.3-2.8 pp of the proxies, and R4 matches.
  - F-look (`1cffe88`, suite 1491/1491; an ARCHITECTURE add/add conflict at the end of the M4 section, resolved by keeping all three headings in order):
    - the sun as tunables, a camera-fixed character fill (`look_fill_*`) and the linear tonemapper (`look_tonemap`; 1 = filmic);
    - bands 0.22/0.52 and an unfogged hull, so the ink matches the HUD's;
    - the street within 0.30 saturation, 12 cm window boxes, and redrawn damage tiles;
    - L1, L2 and L3 in range. The preset is at 514 values.
- **The lead's look:** in the F-look pairs, the C2 Punk at 1 m has 3 crisp bands, warm skin, teal that reads teal and an even ink line. The C7 lineup shares the ink and bands. The lime Kicker is very bright.
- **Left over from these packages:**
  - re-record the vfx_bot sheets under the linear tonemapper (P3-int);
  - ARCHITECTURE's P1-toon and P1-post headings still quote the old defaults (F-look's heading lists what moved);
  - the Bruiser and boss library warm-up in `RoomKit.warm_up_art` (P3-int);
  - the player box-hull corners at 4.2-4.7 px (F-player-art).
- **Running:** F-player-int, launched 05:50 as `wf_bf4c7d7f-773` (args `docs/reviews/M4/args-F-player-int.json` plus `"only": ["F-player-int"]`; worktree `.worktrees/m4-f-player-int`, branch `m4/f-player-int`). It wires the player's art on the probe body, merge-safe: the game keeps M3's primitives until `player.glb` exists, and the probe is worn behind the Debug switch `look_player_art_probe`. It also does test_art_player, the lens rules on the skinned art, 'Look: my arms and legs', and feel question 3 (`fp_knockdown_hide_torso`).
- **Also running:** P3-flash, launched 05:55 as `wf_d718820d-4e0` (args `docs/reviews/M4/args-P3-flash.json` plus `"only": ["P3-flash"]`; worktree `.worktrees/m4-p3-flash`, branch `m4/p3-flash`). It covers:
  - feel questions 1 and 2 as toggles defaulting to today (`hit_flash_fp_max_share` 0, `hit_flash_finisher_radius_mult` 1.0);
  - the Bruiser and boss library warm-up;
  - the VFX checked under the linear tonemapper.
  It and F-player-int both add to Look > FP feel; the lead merges that.
- **The judgement calls log** (`docs/milestones/M4-judgement-calls.md`) has 15 entries.
- **Concept pick:** none (DM read at 05:50; the one reminder went at 04:37).
- **Usage:** the 5-hour window reset at 05:50 (60% before it); weekly 27%.
- **Next:**
  1. Merge F-player-int.
  2. On the pick: F-punk and F-player-art (Tripo spend: about 145 + 185 credits expected, inside the 750 stop), then F-player-int's switch to the real GLB.
  3. Without the pick, everything else is done except P3-int proper: the flash toggles 1-2, `test_m4_done_when`, the quiet perf A/B, and re-recording on the real art. It waits on the art.

### 2026-10-27 05:00 CDT: F-motion merged (1414/1414); P3-early launching beside F-look
- **Merged:** F-motion (`9ae7166`). The merge was clean, the preset is at 505 values, and the suite is 1414/1414 with 0 SCRIPT, SHADER or ERROR lines.
  - No move clip changed: 41 move files were hashed key for key first, and `test_motion_m4` holds them.
  - The 17 `POLISHED_IDS` breathe, bounce and shift weight. MotionLegs IK plants the soles, and idle hurtboxes move under 1 cm.
  - Boxer walks are stride-matched, so the soles slide at most 1.5 cm a step (M3: 0.9 m).
  - Flinches have head lag and overshoot, and get-ups are eased.
  - New: Look > Motion tunables and the Debug switch `look_motion_polish`.
- **The lead's look:** the walk-in sheet has the feet planted and no pops.
- **Feel calls for the final DM:**
  - The enemies' stride-matched step rate is brisk ("a scurry at the approach pace"; `look_motion_stride_m`).
  - The idle life is subtle at 1 m (bounded by A20's 1 cm hurtbox limit; the guard sway and head drift are the dials).
- **Open risks from F-motion:**
  - Three tests sit with no margin on ragdoll start poses (test_ragdoll face down, uppercut in a corner, test_ko_view revive).
  - The first Bruiser or boss spawn pays about 17 ms more for its library build. Its request to `RoomKit.warm_up_art` is F-look's file, and P3-int takes it later.
  - The player's relaxed walks still slide (F-player or P3-int).
- **Running:** P3-early, launched 05:00 as `wf_e158b574-662` (args `docs/reviews/M4/args-P3-early.json` plus `"only": ["P3-early"]`; worktree `.worktrees/m4-p3-early`, branch `m4/p3-early`). This is the part of P3-int that needs neither the pick nor F-look's files:
  - the long take and the F4 showcase;
  - the combat-log toggle (feel question 4);
  - F-motion's two HumanoidRig requests (libraries rebuilt on Tuning.changed; a per-rig idle phase);
  - gate gaps 10 and 12, and G1's gap 1 (the L5 act).
- **P3-int proper keeps:**
  - the flash toggles (1 and 2), which wait for F-look's rig_paint and toon files;
  - `fp_knockdown_hide_torso` (3), which waits for the player art;
  - `test_m4_done_when`, `look_probe` final, re-recording on the picked Punk, and the quiet-machine perf A/B.
- **Concept pick:** none (DM read at 04:50).

### 2026-10-27 04:40 CDT: the gate's fixes merged (1385/1385); F-look and F-motion running; the one pick reminder sent
- **Merged:**
  - `m4/fix-slice-chain-contract` (`85a24dd`): the hull normals in glTF axes, re-export proven to change only COLOR_0; the skin damage class; run.py step checks.
  - `m4/fix-slice-drawn-art-instruments` (`ef38dba`): R4 on art, SkinnedView's drawn pose, A7's flips against the skinned rest, the warm-up in the lens (act W1).
  - The atlas check passes, the preset is at 492 values, and the suite is 1385/1385 with 0 SCRIPT, SHADER or ERROR lines.
  - SG-instruments' ARCHITECTURE sentences are pasted, and the gate doc's "Fixes made" is filled.
- **The lead's look:** C1 at 1 m now has the ink line over the cap crown and forearms. At C5 30% health, the skin takes bruises and blood, but still reads lilac and glassy, and the cap and lenses wear too much blood. Those are brief lines for F-look (in its brief) and F-punk.
- **Running:**
  - F-look, launched 04:35 as `wf_a9c179b1-77a` (args `docs/reviews/M4/args-F-look.json` plus `"only": ["F-look"]`; worktree `.worktrees/m4-f-look`, branch `m4/f-look`). It has the gate's gaps 2, 6 and 11 and the phase-1 look requests.
  - F-motion (`wf_d130ab18-851`), still running.
- **Not re-measured:** first spawn and first hit after the warm-up fix, because two builders share the machine. That moves to P3-int's quiet-machine perf A/B.
- **Pick reminder (A21's one reminder)** sent at 04:37 in the DM (ts `1793093835.705379`): only pick-dependent work is left (F-punk, F-player-art, F-player-int). Never send another and never pick for him.
- **Usage:** 5-hour 44% at 04:35 (resets 05:50); weekly 25%.
- **Next:**
  1. Merge F-motion and F-look as they land (A22 order: F-motion first), with the suite after each.
  2. Read the DM at each boundary.
  3. On the pick: F-punk (views, T4-T10) and F-player-art (views, T11-T14), then F-player-int. Their briefs carry the gate's F-punk gap lines (3, 4, 5, 7, 9, 13, plus the lens and cap swatch marks).
  4. Without a pick: P3-int's parts that don't need the real Punk.

### 2026-10-27 04:10 CDT: the slice gate's verdict is (b), proven with a contingency; its two fixers and F-motion running
- **The gate** (`wf_36e8400a-165`): two Opus lenses, 16 findings, 10 survive one Sonnet skeptic each. Both lenses gave verdict **(b)**. The lead wrote `docs/milestones/M4-slice-gate.md`: the pass items with evidence, the locks, 13 ranked gaps with owners, and the refuted findings. The full output is in `docs/reviews/M4/slice-result.json`.
- **Locked:**
  - the A-pose bind route (`punk.glb`) and Tripo weights;
  - the landmark-warp fit, keeping the bulk, and border-protected decimation;
  - `look_outline_px` 3.75 (after the axis fix);
  - placeholder hulls on, and the dilated edge mask;
  - 4x MSAA, with FXAA as the switch offered in the final DM;
  - proxies accepted for crowd readability, plus art-drawn guards for the close-range lens rules.
- **Contingencies** for phase 2: the hull-normal axis fix before any F-punk or F-player-art export; A18's detail mask (a README departure for Game-boy's ruling); a girth clamp only if A6 misses on the real Punk; weight smoothing only if F-punk's visible-stretch test fails.
- **The worst gap:** the hull normals are baked in Blender's Z-up axes, so no ink shows on top and bottom silhouettes. SL-int's "even 3 px hull" claim was wrong.
- **Running:** the gate's fixers, resumed into the same run `wf_36e8400a-165` (args `docs/reviews/M4/args-review-slice-fix.json`):
  - `chain-contract`: hull normals, the skin damage class, run.py step validation. Worktree `.worktrees/m4-fix-slice-chain-contract`, branch `m4/fix-slice-chain-contract`.
  - `drawn-art-instruments`: R4 on art, the SkinnedView pose source, the strain flip rule, warm-up placement. Worktree `.worktrees/m4-fix-slice-drawn-art-instruments`, branch `m4/fix-slice-drawn-art-instruments`.
  - F-motion (`wf_d130ab18-851`) is still running.
- **To resume after a stop:** `Workflow({scriptPath: "docs/reviews/M4/workflow-review.js", resumeFromRunId: "wf_36e8400a-165", args: <args-review-slice-fix.json>})`. The reviewers and skeptics replay from cache, and the fixers continue from their `wip:` commits.
- **Usage:** 5-hour 37% at 03:05 (the gate cost about 25%, double its estimate); weekly 24%.
- **Concept pick:** none (DM read at 03:05).
- **Next:**
  1. Merge the two fixers and F-motion, then the suite.
  2. Re-measure first spawn and first hit.
  3. Paste SG-instruments' replacement sentences into ARCHITECTURE, and fill the gate doc's "Fixes made".
  4. Launch F-look with gate gaps 2, 6 and 11 in its brief.
  5. Once only pick work is left, send A21's one reminder.

### 2026-10-27 02:55 CDT: SL-int merged (1378/1378); the A16 perf baseline, then the slice gate
- **Merged:** SL-int (`59a0adf`). The merge was clean, the preset is unchanged at 492 values, and the merge is green at 1378/1378 with 0 SCRIPT, SHADER or ERROR lines.
- **What SL-int built:**
  - Every Street Punk wears the smoke Punk: `game/actors/art/punk_art.tres` on `punk.glb`. `check()` passes for all four GLBs.
  - The A/B variants (`punk_rest`, `punk_auto`, `punk_auto_rest`) sit behind the Debug tunable `look_punk_art_variant`, or `CAPTURE_ARGS="--tune=look_punk_art_variant=N"`.
  - Prop hulls on the crates, dumpster and car (`RoomKit.prop_material`), and the art warm-up at room load.
  - `tests/test_art_punk.gd` prints A6, A9, A10, A11 and A19 for all four GLBs.
  - The act "Look: Perf, six art Punks" (slug p1).
  - Re-recorded C1-C11, C13, E1, E2, the A/B and the autopilot crowd acts. `check_m3_log` is ok, and R1-R3, R10 and R11 are met.
  - Its captures are in `.worktrees/m4-sl-int/captures/sl-int/`. Keep that worktree until the gate is done.
- **The lead's look:** C2 at 1 m reads as a cartoon character: cap, shades, vest, crisp bands, violet shadows and an even hull. At the jab, the four GLBs are indistinguishable and the glove fills half the view.
- **For the gate (SL-int's numbers, in `M4-calls/SL-int.md` §3):**
  - A19: no GLB passes; the shoulder is worst, then the foot seam face down. The bind routes and weight sources differ by under 15%.
  - A9: the art's arms are bulkier than the proxies (6.1% of cells differ at the jab, against a 3% bar).
  - A11: the flash anchor sits 4-5 cm off the skin.
  - A6: the legs are at 89-91%.
  - J3: the gloves read as canisters. J13: the placeholders look like another game.
- **Runner changes:** `workflow-review.js` takes `skeptics` (1 or 3) and `max_packages`, and its findings schema has `locks`, `gaps` and `verdict` for the gate.
- **Gate args:** `docs/reviews/M4/args-review-slice.json` has G1 (mechanics and contract) and G2 (deformation and look at 1 m), with `no_fix` true. The lead reads the findings before choosing at most 2 fix packages.
- **The lead's A16 perf run (03:05, vsync on, load 2.4-4.6 from other apps; logs in `captures/perf_compare/a16/`):** on "Perf, six with ragdolls", M3 mean 12.10 ms against M4 14.53 (+2.4), p95 +3.4, spawn hitch +2.9. First spawn and first hit are within +2 ms (ok). M3 itself misses the p95 bar on this machine. On "Look: Perf, six art Punks": FXAA saves 2.3 ms, depth-only edges save 1.0, edges off save 3.5, and the placeholder hulls cost nothing measurable (A7 stays on).
- **Running:** the slice gate, Workflow run `wf_36e8400a-165` (script `docs/reviews/M4/workflow-review.js`, args `docs/reviews/M4/args-review-slice.json`; reviewer worktrees `.worktrees/m4-review-slice-g1` and `-g2`, detached at `59a0adf`). It stops after the partition (`no_fix`). To resume after a stop: `Workflow({scriptPath, resumeFromRunId: "wf_36e8400a-165", args: <the file>})`.
- **Also running:** F-motion, launched at 03:15 as Workflow run `wf_d130ab18-851` (args `docs/reviews/M4/args-F-motion.json` plus `"only": ["F-motion"]`; worktree `.worktrees/m4-f-motion`, branch `m4/f-motion`). It started alongside the gate because its files (the poses and anims) are disjoint from anything the gate locks, A20 bounds it to non-move clips, and it spends no credits. The plan's rule is "If the pick is still out: start F-motion and F-look on the smoke Punk". F-look waits for the gate's locks (AA mode, outline px, edge mask).
- **Then:** read the locks, gaps and verdicts, write `docs/milestones/M4-slice-gate.md`, and resume the run with the chosen packages (at most 2) and `no_fix` false.
- **Done before the gate:**
  1. The lead's A16 perf baseline, on a quiet machine with vsync on. The script is in the scratchpad; to rerun it: `tools/perf_compare.sh --vsync on --runs 3 --act "Perf, six with ragdolls" --act "Look: Perf, six art Punks" afdb39e 59a0adf`, then FXAA, depth-only, hulls off and edges off on the head through a `GODOT=` wrapper that appends `--tune=...` after `--`.
  2. Paste the numbers into the gate args' `PERF_PLACEHOLDER`.
  3. Launch the gate, then write `docs/milestones/M4-slice-gate.md`.

### 2026-10-27 01:35 CDT: P1-post merged; phase 1 is complete; SL-int next
- **Merged:**
  - The P1-fx merge was green at 1325/1325.
  - P1-post (`8afcf7b`; its own branch passed 1266/1266, built on a base without P1-toon). The merge was clean. The preset is at 492 values. The merge is green at 1363/1363.
- **What P1-post built:**
  - The edge pass (`game/fx/edge_pass.gdshader`): near-side depth lines and normal creases. A dilated 8-tap character mask (`look_edge_mask_px`) keeps the lines off tag-0 surfaces, so the hull carries those silhouettes.
  - The `street_dusk` LUT (`tools/gen_lut.gd` from `assets/source/look/grade.json`).
  - The AA mode (`look_aa_mode`).
  - LookPost, added by `RoomKit.build_presentation`. The training room now builds through RoomKit.
  - The car is a muted blue-grey (A13).
  - A8's probe answers are in `docs/milestones/M4-calls/P1-post.md`.
- **The lead's look:** in C2 before and after, and E1 at 1 m, the street, crates, curb and the primitive Punk get 1 px ink lines; the HUD is untouched and the car is no longer red. Known weaknesses: dashed creases on the 1.5 cm window boxes (F-look), and 1 px lines stepping on curves, since MSAA doesn't smooth post lines.
- **Perf (NOISY, the edge pass alone):** about +3.1 ms at 4x MSAA and +2.0 ms with FXAA on the M1. A16's soft bar may need FXAA once six art Punks are in.
- **Open requests, all handed to SL-int:**
  - prop hulls through `ToonMaterials.environment(color, true)` (the `next_pass` route);
  - re-record E1 and E2 with the real hulls, and check for doubled lines;
  - the edge pass has not yet run over the real toon materials.
- **Concept pick:** none yet (DM read at 01:30).
- **Running:** SL-int, launched at 01:40 as Workflow run `wf_9934521a-9bf` (script `docs/reviews/M4/workflow-build.js`, args `docs/reviews/M4/args-SL.json` plus `"only": ["SL-int"]`; worktree `.worktrees/m4-sl-int`, branch `m4/sl-int`). To resume after a stop: `Workflow({scriptPath: "docs/reviews/M4/workflow-build.js", resumeFromRunId: "wf_9934521a-9bf", args: <the same>})`, or relaunch it fresh; the runner resumes from the branch state.
- **Next:** when SL-int lands, merge it, then the slice gate (`docs/reviews/M4/workflow-review.js`, round "slice").

### 2026-10-27 00:25 CDT: P1-fx merged; only P1-post is still running in phase 1
- **Merged:**
  - The P1-skin merge was green at 1313/1313.
  - P1-fx (`657ca31`; its own branch passed 1269/1269). The preset is at 484 values. The suite on the merge is running.
- **What P1-fx built:**
  - Every effect is redrawn by `tools/gen_fx.gd` in `HudStyle.INK`, with stroke weights from `INK_TABLE`: 7.5 px at 1 m, about 2× the hull.
  - Ben-Day dots on the bursts and on the lettering faces.
  - A second variant per burst tier (`burst_*_2`), never repeated twice running.
  - Every word is drawn at one cap height, with an inner highlight.
  - Lying splats are unshaded (`vfx_splat_shade`), and blood is ink-outlined.
  - Output is byte-stable, and a test reruns the generator to check it.
- **The lead's look:** in C5's hook frame before and after, the effects read as one ink style with the toon Punk. The lettering is now the heaviest line on screen; it reads bold, not heavy. The contact flash's white blob still covers a big share of the view: that is a deferred feel question for P3-int's toggle.
- **The look bible's VFX row** now names `INK_TABLE` instead of a tunable. `test_fx_m4` ties it to `look_outline_px`, so a hull change means a re-run of `gen_fx`.
- **Next:** P1-post. Then SL-int, then the slice gate.

### 2026-10-27 00:10 CDT: P1-skin merged; P1-post and P1-fx still running
5-hour 69% (resets 00:50 CDT), weekly 17%.
- **Merged:**
  - P1-chain's merge was green at 1272/1272.
  - P1-skin (`4f4c650`; its own branch with P1-toon passed 1298/1298). The lead dropped a stray `tests/test_zz_scratch.gd.uid`. The preset is unchanged at 482 values. The suite on the merge is running.
- **What P1-skin built:**
  - `SkinnedArt.attach()` and `check()`: the A3 chained bind route, in the GLB's bind order, by name. Each surface is rebuilt with CUSTOM0/1. FP-hidden GLB meshes go on the head layer.
  - The ragdoll write-back on art rigs only (A5). `look_show_art` works live. `_head_clear_of` skips the art.
  - `FPView.is_drawn()` and `depths()`.
  - `tests/skinned_view.gd`: CPU skinning, TriangleMesh rays, strain, hurtbox fit and surface gap.
  - `tests/test_skinned_art.gd` (41 tests) and `skin_acts.gd`.
  - A/B check: the art and the primitives draw pixel-identical silhouettes through stagger, launch and lying. The lead saw the toon sheet: the probe Punk follows every pose and the KO blink-off.
- **For SL-int and the gate:**
  - The A19 strain reference: P1-skin measures against the skinned rest (`strain(mi, rig, globals)`). Check that this is the reference P1-chain asked for (C13).
  - P1-chain's `probe_body` GLBs fail A19: p99.9 2.08, with shoulder candy-wrap from the auto weights. They are reported only, not asserted.
  - FPView's analytic proxies are looser than the drawn primitives, so real art can read up to 7 cm nearer. The GLB tests use 2 cm and may need a ruling.
  - `check()` is strict. A GLB that fails it attaches nothing, the rig keeps its primitives, and it warns once.
  - The 15 ms cost test is wall-clock and could flap under heavy load.
- **Next:** when P1-post lands, merge it and launch SL-int, which wires `punk_art.tres` into StreetPunk, runs the 1 m acts on the art, and records the perf act. Then the slice gate. P1-fx merges whenever it is done.

### 2026-10-27 00:20 CDT: P1-chain merged; the smoke Punk is a GLB
- **Merged** (`c69214f`; its own branch passed 1243/1243). The suite on the merge is running.
  - The Blender chain: `tools/pipeline/run.py` with the `blender_*` steps, `gen_palette.py` and `ab_sheet.sh`.
  - Four Punk GLBs in `assets/export/characters/punk/`: `punk.glb` (Tripo weights, A-pose, the default), `punk_rest.glb` (arms-down bake), `punk_auto.glb` and `punk_auto_rest.glb` (heat-map weights).
  - The palette atlas plus `shared.json` and `punk.json`; `pipeline.json`, `report/`, `report_auto/` and `work/punk.blend`.
  - `tests/test_art_contract.gd`: 15 tests, 1655 assertions.
  - The lead ignored the per-run stills. `gen_palette.py --check` says the atlas is current.
- **The Punk:** 14,999 triangles, 6 swatches, 23 named binds and no `neutral_bone`. Its joints are within 0.001 mm of the table chained through the swing, and the fist is in the fist box. It reads as concept A (the lead looked at `punk_apose_poses.png`): the guard, elbow 150 and knee −130 hold their volume, the arm raise 140 pinches at the armpit, and the face is soft.
- **For the slice gate** (nothing is fixed yet):
  1. **A3's 1 cm landmark residual is 2.35 cm on the Punk** (1.4 mm on the probe). Tripo's torso bones tilt 8-17°. Rule on the bar (calls C6).
  2. **A7 strain misses:** p99.9 is about 2.0 at the guard, 2.9-4.3 at the arm raise and about 1.9 at the spine twist. The worst edges are the armpit, the vest collar (Neck to RightShoulder) and the jeans hem. Heat-map weights score lower than Tripo's everywhere. Naive weight smoothing made it worse. The A-pose route is no worse than the bake.
  3. **The strain reference:** P1-chain asks that A19 measure against the *skinned rest pose*. For the A-pose route the GLB's own mesh already reads 1.7 at idle (C13). P1-skin was already running when this came in, so SL-int or the gate checks which reference P1-skin used.
  4. Pick the weights source and the bind route from `report/stills/ab_weights_x_route.png` and the numbers.
  5. Smaller points: the wide glove cuff can read as a bracelet; the soles sit at −4.3 mm (inside 5 mm); palette ΔE averages 9.4, so thin seams may be lost.
- **Running:** P1-skin, P1-post and P1-fx. After them: SL-int (the smoke Punk in the crowd room), then the slice gate.

### 2026-10-27 00:00 CDT: P1-toon and P1-chain's probe body merged; P1-fx running
5-hour 65% (resets 00:50 CDT), weekly 16%.
- **Merged:**
  - P1-chain's `probe_body.glb` wip (`d0b07d3`, 1228/1228). It brings the Blender chain scripts, the probe body in both variants (A-pose and rest) and the palette atlas.
  - P1-toon (`60a9d64`; its own branch passed 1245/1245). The preset regenerates at 482 values. The lead updated S0's ARCHITECTURE text to follow the retype. The suite on the merge is running.
- **What P1-toon built:**
  - One toon shader for every lit surface (`game/fx/toon.gdshader` plus `toon_light.gdshaderinc`, and the grid) and ink hulls on `material_overlay` (`toon_outline.gdshader`, modes 0-4). The flash keeps `next_pass`.
  - Width is in pixels between near and far, faded at the lens; the player's own body draws at ×0.8.
  - A shadow-map guard: without it the hull fattened shadows by 50%.
  - RigPaint and DamageLook now use ShaderMaterial, and a UV2 detail mask was tested on a fixture.
  - The lead looked at its first-person stills. The forearm and wraps read cel-shaded with an even line. The street is strongly violet, which is for P1-post and F-look to mute.
- **P1-toon's requests still open** (P1-post was already running without them; SL-int or a P1-post fix picks them up):
  1. Crates, the dumpster and the car should use `ToonMaterials.environment(color, true)`, which gives them a hull.
  2. The edge pass reads `edge_tag`: 0 on every hulled surface (the art and, by default, the primitive characters, dummies, the pipe and hulled boxes), 1 on walls, floor and grid.
  3. P1-skin's `attach()` must keep COLOR and add CUSTOM0 and CUSTOM1 (rest position and rest normal), and should use `paint.art_material()` and `paint.outline_material()`.
  4. SL-int calls `ToonMaterials.warm_up(room, <art Punk>)`.
  5. F-look: the sun sits behind the enemies, so their fronts fall in the mid and shadow bands. The violet is strong, and skin reads pinkish.
- **Running:**
  - P1-fx: `wf_461db2b0-0b9` (task `w5qjeow6a`, [args-P1-fx.json](reviews/M4/args-P1-fx.json));
  - P1-skin, P1-chain and P1-post, as above.

### 2026-10-26 23:45 CDT: L0-bench merged; P1-post running
5-hour 58% (resets 00:50 CDT), weekly 15%.
- **L0-bench merged** (`f49e30c`). On its own base it passed 1210/1210; the suite on the merge is running.
  - **Look acts:** C1-C11 and C13 are in `tests/bot/acts/look_acts.gd` (slugs c1..c13).
  - **Tools:** `look_rect.gd` prints the LOOK-MARK and LOOK-RECT lines, and `tools/look_sheets.sh` turns them into stills and 2× crops. `tools/perf_compare.sh` runs `tests/bot/perf_bot.tscn` in temporary worktrees per ref. `CAPTURE_ARGS` now reaches the bot through `capture_bot.sh`.
  - **The before pack:** `captures/m4_before/<slug>/` (778 MB, local, never committed). It was recorded one act per process, so re-record the same way to pair before and after stills by label.
- **Perf note for the lead's real run (A16):** unattended windowed runs with vsync off stall for 1.0 s every few seconds on this M1 (about 15 frames in 1700). Vsync-on runs don't stall. Read the report's stalls row first. If it warns, run with the window in front, or use `--vsync on` and rule on the p95 bar.
- **Running since 23:45:** P1-post, `wf_89f245d9-23a` (task `why16ktxx`), with [args-P1-post.json](reviews/M4/args-P1-post.json). Its steps:
  - A8's probe first;
  - then the edge quad, the LUT and the training room through RoomKit;
  - the car recoloured;
  - `look_probe.gd`;
  - NOISY perf numbers only.
- **Still running:** P1-skin, P1-toon and P1-chain. P1-fx takes the next free Godot slot.

### 2026-10-26 23:40 CDT: P1-tools done and merged; the smoke Punk is through Tripo (55 credits)
- **Merged:** `50b42d4`.
  - The `--spend` guard on every paid Tripo call.
  - The mannequin: `assets/source/mannequin/`, made by `blender_mannequin.py` from `joints.json`.
  - `blender_views.py`: four-side textured stills of any GLB.
  - The smoke sources in `assets/source/characters/punk/smoke/`: a Gemini flat front view of Punk A; the T1 generation `cb4af11c_gen.glb` (19,510 triangles, faithful to the concept); the T3 rig `0366578f_rig.glb`; their dumps; and `source.json`.
- **Ledger:** T1 30.00 (texture v3.5 costs the same as standard), T2 0, T3 25.00. M4 has spent **55** credits; the balance is **1445**.
- **What the smoke taught us** (for P1-chain, all in `source.json`):
  - Tripo's model faces +X (`facing_yaw_deg` 89.33), and `Left_*` means the character's own left.
  - The model is 1.000 m tall, so it scales by 1.8.
  - Tripo's rig has 67 bones and roots at Hips with no Root. Its names map by dropping the underscore (`Left_UpperArm` becomes `LeftUpperArm`).
  - Its arms sit 38-42° from vertical and its legs splay about 10°.
  - It is broader and more muscular than the rig table: the shoulders sit 6-9 cm low.
  - Gemini's flat view didn't follow the mannequin's stance. For F-punk, tighten that with the mannequin's numbers or an edit round.
- **Left as is:** P1-tools asked to drop the price table's two settled "unverified" entries. Its own self-test pins that flag, so the table stays unchanged; it only prints a warning.
- **Still running:** P1-skin, P1-toon, P1-chain (which will find the smoke on its check) and L0-bench. A background watch merges P1-chain's `probe_body.glb` commit once it is pushed.
- **Game-boy's pick:** none yet (read 23:38).

### 2026-10-26 23:15 CDT: S0 and P1-tools part 1 merged (1216/1216); phase 1 running
5-hour 43% (resets 00:50 CDT), weekly 12%. Phase 0 cost about 9%, much less than its estimate.
- **Merged into `m4/art-pipeline`:**
  - P1-tools part 1 (`584c6b0`): `tripo.py`, `tripo_prices.json`, `blender_dump_rig.py`, the empty ledger and the Concepts rows. No credits; the balance is 1500.
  - S0-contract (`4d8c391`): 1216/1216 headless, with 0 SCRIPT, SHADER or ERROR lines. The preset regenerates unchanged (462 values). A seeded combo_bot recording is bit-identical to M3 on all 1815 frames. The lead reviewed the hunks in humanoid_rig, combat_actor, weapon and room_kit.
- **Lead fixes:**
  - `tools/gemini_image.py` finds the key from a worktree (the environment, then the repo's `.env`, then the main checkout's).
  - The Tripo ledger merges by union.
- **A near miss in P1-tools part 1:** a command without `--dry-run` would have started a real 30-credit T1, and the permission check blocked it. Part 2's first step makes paid calls also require `--spend <expected>`.
- **S0's calls worth knowing:**
  - C1: `test_audio`'s group-order test now expects Look, then Debug.
  - C3: `look_outline_px` seeds at 3.75.
  - C4: the primitives are hidden only when `SkinnedArt.attach()` returns meshes.
  - C5: `art_material()` is a plain StandardMaterial3D stub.
- **Running since 23:10** ([args-P1.json](reviews/M4/args-P1.json)):
  - P1-skin: `wf_9bd1db5f-395` (task `wkq826175`);
  - P1-toon: `wf_fad395f7-7df` (task `wgv9cp8g1`);
  - P1-chain: `wf_b2b8f7d8-4aa` (task `wxc5qcvcb`). It proves the chain on `probe_body.glb` (pushed early for P1-skin). Then it waits for the smoke, or returns `wip` and gets relaunched.
  - P1-tools part 2: `wf_09fa509f-1ab` (task `wk0fwaqxa`). Steps: the `--spend` guard, the mannequin renders, a Gemini flat view of Punk A, then T1-T3 (55 credits expected, 85 ceiling).
  - L0-bench is still `wf_cc211798-6b5`.
- **Lead, as each lands:**
  1. Merge P1-chain's `probe_body.glb` wip as soon as it is pushed (P1-skin uses it).
  2. Merge P1-tools on its final commit, then relaunch P1-chain if it returned `wip`.
  3. When L0-bench is done, merge it, then launch P1-post (A8's probe first), then P1-fx.
  4. Run the full suite after every merge.
- **Game-boy's pick:** none yet (read 22:35).

### 2026-10-26 22:40 CDT: M4 plan written; phase 0 (S0-contract, L0-bench, P1-tools) launching
5-hour 34% (resets 2026-10-27 00:50 CDT), weekly 11%. The plan workflow cost about 29% of the window (8 agents, 3.0M tokens).
- **The plan:** [M4-plan.md](milestones/M4-plan.md).
  - The judge picked vertical-slice as the base and added 23 binding amendments (Part A). The main ones:
    - A2: P1-pipe splits into P1-tools and P1-chain.
    - A3: the A-pose bind route by default, with the arms-down bake as the slice gate's A/B.
    - A4: the proxies stay, and the drawn art is measured with native TriangleMesh rays.
    - A7: the hull goes on every character and prop.
    - A8: the edge pass never reads the screen texture, and a first-hour roughness probe comes before building on it.
    - A9: A/B switches go in "Debug", and every `vfx_*` tunable goes in "VFX".
    - A10: Tripo has a 700 balance floor and a 750 ledger stop.
    - A12: L0-bench and the C1-C13 look acts.
    - A13: the red car gets recoloured, and no logos (concept D's sneakers).
    - A14: F-player splits into art and integration.
  - Part B is the done-when made checkable: the A1-A14 and L1-L5 rows, plus the J1-J14 rubric with critical items.
  - Part C is vertical-slice, verbatim.
  - The look targets are in [M4-look-bible.md](milestones/M4-look-bible.md).
  - The three plans, `judge.json`, the codemaps and `reads.json` are committed.
- **Lead pre-cuts done:**
  - ASSETS.md sections: Concepts; Characters, with › Punk and › Player; Look.
  - ARCHITECTURE "Art pipeline and look (Milestone 4)", with one heading per phase-0 and phase-1 package.
  - `docs/milestones/M4-calls/`.
  - `assets/source/_cache/` ignored, and the palette atlas set to keep-ours.
  - The runner: [docs/reviews/M4/workflow-build.js](reviews/M4/workflow-build.js), with Godot slots (4) and Blender slots (2), and a Tripo credit report in each result.
- **Phase 0** ([args-P0.json](reviews/M4/args-P0.json)). Each package runs as its own Workflow run (`only: [key]`), so each merge can happen as soon as its builder is done:
  - **S0-contract:** the seams, RigPaint, the call-site stubs, `joints.json`, the test move, and the Look group.
  - **L0-bench:** the look acts, `look_sheets.sh`, `perf_compare.sh`, and the before pack into `captures/m4_before/`.
  - **P1-tools, steps 1-2 only:** `tripo.py`, `blender_dump_rig.py` and the Concepts ASSETS rows. No credits. It ends on a `wip:` commit, and a second launch after S0's merge does the mannequin and the smoke Punk T1-T3.
- **Running since 22:45:**
  - S0-contract: `wf_24684a15-5d9` (task `wsy3wzufe`);
  - L0-bench: `wf_cc211798-6b5` (task `wnphun6a9`);
  - P1-tools: `wf_c1309863-fd9` (task `wbqn4zcx7`).
  - Worktrees: `.worktrees/m4-<key>`. Branches: `m4/<key>`.
- **Game-boy's pick:** none yet. The DM thread was read at 22:35.
- **Next:**
  1. Merge S0.
  2. Then launch P1-skin, P1-toon and P1-chain, plus P1-tools' second launch (args-P1.json, still to write).
  3. When L0-bench is done, launch P1-post (A8's probe first), then P1-fx.
- **If cut off:** rerun each package with `Workflow({scriptPath: "docs/reviews/M4/workflow-build.js"})` and the args file, using `only: [key]`. The runner resumes each package from its branch.

### 2026-10-26 21:45 CDT: concepts sent; waiting on Game-boy's pick
- Game-boy enabled billing on the Gemini project (21:40). Concept round 1 is in `assets/source/concepts/` (`concept_jobs.json`, `tools/gemini_image.py`, model `gemini-3-pro-image`, 2K): Street Punks A-D and hero sheets A-C. Both sheets were DMed at 21:42 CDT, asking for one Punk and one hero, mix-and-match allowed.
- **Next, on his pick:** generate the orthographic front, side and back views of the picks (Gemini, with the picked image as a reference) for Tripo. The plan workflow is still running.

### 2026-10-26 21:30 CDT: M4 working session started; the plan workflow running; Gemini images blocked on Game-boy
5-hour 5% (resets 2026-10-27 00:50 CDT), weekly 6%.
- **Sessions:** the M3 session is renamed "Beat-em-up: M3 session (done)". This session is "Beat-em-up: working session". The old watcher session (`local_618146a1`, Haiku) was told to restart its `/loop` with the "Usage watcher" prompt; a session started from another session can't start a new one.
- **Running:** the plan workflow `wf_74e77973-52c` (task `w283e2yn1`):
  - four Sonnet readers write `docs/milestones/M4-codemap/` (rig-render, fx-env-tooling, toolchain-tripo-gemini, toolchain-blender-godot);
  - three Opus planners (rig-risk-first, look-first, vertical-slice) write `docs/milestones/M4-planning/m4-plan-*.md`;
  - an Opus judge scores them and returns the amendments.
  - **If cut off:** within this session, rerun the script with `resumeFromRunId: "wf_74e77973-52c"`. In a new session, write the plan from whatever codemaps and planning files exist.
  - **Then:** the lead writes `docs/milestones/M4-plan.md` (Part A amendments, Part B the done-when made checkable, Part C the base plan), as in M3.
- **Blocked on Game-boy (DMed 21:28 CDT):** the Gemini key is valid, but its project is on Google's free tier, which allows 0 image generations on every image model (`gemini-3-pro-image`, `gemini-3.1-flash-image`, `gemini-2.5-flash-image`, `gemini-3.1-flash-lite-image` all return 429 "limit: 0, Free Tier"). He's asked to set up billing on the key's project (AI Studio, Tier 1). The key's earlier "works" check only listed models. `gemini-2.5-flash` text is retired for new users; text calls would use `gemini-3.8-flash`.
  - The concept prompts are ready (4 Street Punks, teal with a yellow accent as in M3, front A-pose; 3 hero design sheets with hand, fist and shoe callouts). The generator and its job file move into `tools/` with the plan.
- **Next:** write the plan; launch the toolchain-free packages (toon shader, outlines, post, the VFX set); send the concepts as soon as images work.

### 2026-10-26 21:10 CDT: the M4 toolchain is ready; M4 starts in a fresh session
5-hour 5% (resets 2026-10-27 00:50 CDT), weekly 6% (resets Mon 2026-11-02 05:00 CDT). No watcher is running; the M4 session starts one.
- **Ready, verified by the lead:**
  - **Blender 5.2.2 LTS** on PATH.
  - **The Blender MCP** (`mcp-for-blender`, user scope in Claude Code) is connected to Game-boy's open Blender: add-on 1.8, up to date, telemetry off. Its Tripo generator is Premium-only, so call Tripo's own API with our key instead.
  - **`.env`:**
    - `TRIPO_API_KEY` works: `GET https://api.tripo3d.ai/v2/openapi/user/balance` returns 1500, with 0 frozen.
    - `GEMINI_API_KEY` works (send it in the `x-goog-api-key` header, never in a URL). The image models are `gemini-3-pro-image`, `gemini-3.1-flash-image` and `gemini-2.5-flash-image`.
    - Never print either key.
  - Mixamo is skipped (try Tripo's auto-rig first).
- **How M4 runs** (the lead's defaults, for Game-boy to change):
  - **Like M3:** a plan workflow, parallel builders in worktrees, adversarial review in first person, fixes, and no pauses for grey-block feel questions.
  - **Pauses on purpose:**
    1. **The concept pick** (SPEC §10: 2-4 concepts, Game-boy picks one) for the Street Punk and for the player's arms and legs. DM him the images on Slack (Michael, `U0AQMKKBL93`; upload them to the DM) and carry on with the toolchain-free work meanwhile.
    2. **The done-when:** the Punk at 1 m, standing and in motion, judged by him.
  - **Tripo credits:** spend at most 800 of the 1500 without asking; log each generation's cost.
  - **The playable link:** the GitHub release page 404'd for Game-boy (private repo; his browser isn't signed in as `mikedtcm22`). He asked for a link that opens the game in Godot, so give him the run command (`godot --path /Users/arachne/repos/beat-em-up-PoC`) as a Run-button code block, and a release only as a second option.
  - The deferred "until the art is in" feel questions come due once the Punk is in: the flash's first-person size, the haymaker's flash, the knockdown view, and grab-03's combat log.
- **Branch:** `m4/art-pipeline` (from `main` at `afdb39e`).

### 2026-10-26 20:50 CDT: Milestone 4 toolchain set-up started (branch `m4/art-pipeline`)
- **Game-boy's toolchain calls (2026-10-26):**
  - **Mixamo:** skipped for now; whether it's needed is assessed later. Tripo's auto-rigging is tried first.
  - **3D generation:** Tripo.
  - **Image generation:** Google Gemini.
  - **Blender:** OK to install from the command line.
- **Done:**
  - Blender 5.2.2 LTS is installed with Homebrew (`brew install --cask blender@lts`). `blender` is on PATH and headless Python works (Python 3.13). No 4.x cask exists any more; the spec's "4.x" predates 5.x.
  - `.env` is created (git-ignored) with empty `GEMINI_API_KEY=` and `TRIPO_API_KEY=` for Game-boy to fill in. `.env.example` and README's API keys and toolchain tables are updated.
- **The lead's assessment of the Tripo MCP tutorial** (tripo3d.ai, "cursor-tripo-mcp-tutorial"):
  - That route is Tripo's own Blender add-on (`VAST-AI-Research/tripo-3d-for-blender`, last release v0.7.7, 2025-11, before Blender 5.2) with its "Start MCP Server" button, plus `uvx tripo-mcp` in the MCP client.
  - `tripo-mcp` is "alpha", untouched since 2025-04, and makes models from a text prompt into an open Blender.
  - **Recommended instead:**
    - call Tripo's REST API directly from a script with `TRIPO_API_KEY` (image-to-3D from the chosen concept in a T-pose, and Tripo's auto-rig), reproducible and with no Blender window needed;
    - process in Blender headless (`blender --background --python`, SPEC §10);
    - optionally add the general Blender MCP (`mcp-for-blender`, formerly `blender-mcp`, active, sets up Claude Code itself, also lists Tripo) for interactive look-and-fix work.
- **Waiting on Game-boy:**
  - the two keys in `.env`;
  - optionally the Blender MCP setup (steps given in chat: `brew install uv`, `uvx mcp-for-blender setup`, restart the Claude app, open Blender; consider turning its telemetry off).
- **Next:** plan M4 (`docs/milestones/M4-plan.md`). The toolchain-free parts (toon shader, outlines, post-processing, the comic VFX set) can start before the keys arrive.

### 2026-10-26: Game-boy signed off Milestone 3; PR #3 merged
- **Game-boy (2026-10-26):** "happy with the enemy AI", M3 is complete as-is, and every judgement call and spec departure made in M3 is approved. README's "Where M3 departs from the spec" and `docs/milestones/M3-judgement-calls.md` now say so. The boss keeps the spec's 300 HP.
- **PR #3 merged into `main`.** The `.worktrees/m3-*` worktrees can be pruned; every branch is pushed.
- **Next: Milestone 4 (SPEC §12), the art pipeline proof:**
  - the toon shader and outlines;
  - the final player arms and legs;
  - one Street Punk taken through the full pipeline (concept, 3D generation, Blender cleanup, rig, animation, export);
  - the comic VFX set.

  Done when the Punk looks production-quality at 1 m, standing and in motion (Game-boy judges).
  - It needs Game-boy's toolchain first (SPEC §2): Blender and its MCP, a 3D generation service and its key, an image API key, and Mixamo access. The lead sent him the list on 2026-10-26.

### 2026-10-26 08:30 CDT: Milestone 3 done; the release, the PR and Game-boy's DM are out
- **M3 is complete to SPEC §12, and waiting on Game-boy's play-through and sign-off.** Never merge PR #3 without that.
  - **Playable build:** https://github.com/mikedtcm22/beat-em-up-PoC/releases/tag/m3-playtest-1 (pre-release, `Beat-em-Up.PoC.zip`, universal macOS, ad-hoc signed, from `fd36854`). It was smoke-tested headless and windowed.
  - **The PR:** https://github.com/mikedtcm22/beat-em-up-PoC/pull/3 (`m3/enemy-ai` into `main`).
  - **1198/1198 tests pass in 143 s with no SCRIPT ERROR or ERROR.**
- **Since the last entry:**
  - An independent verifier confirmed the final review's high fixes hold (`docs/reviews/M3/final-verify.md`); the boss stun-lock was only partial.
  - **F-boss-poise** fixed it: after it gets up (or after two reactions in 8 s), heavy hits and non-haymaker finishers are absorbed for 4 s or until its next attack. Time in reactions went from 48% to 21%, and it lands 4.6 hits a fight; the autopilot still wins 12 of 12. It steps back before a too-close charge or pound. Its cooldown is 1.5 s.
  - **The lead:** an absorbed finisher starts no slow-mo and waits out no impact frame (with a test).
  - README, the calls log and ARCHITECTURE were updated.
- **Game-boy was DMed on Slack** with the link and the digest (from `docs/milestones/M3-judgement-calls.md`).
- **Waiting on Game-boy:**
  - play the release and sign off, then merge PR #3;
  - rule on README's 19 "Where M3 departs from the spec" bullets;
  - judge the boss's difficulty (`boss_health` 300 by the spec), the attacks in turns, the 55° warning angle, and the frequent non-KO knockdown view.
- **Next after sign-off:** merge PR #3, then plan Milestone 4 (SPEC §12: the art pipeline proof). The `.worktrees/m3-*` worktrees can be pruned once the PR merges; every branch is pushed.

### 2026-10-26 06:15 CDT: the final review's fixes merged (1177/1177); verification, docs and the release next
5-hour 73% (resets 07:50 CDT); **weekly reset to 3%** (resets Mon 2026-11-02 05:00 CDT). The final review (177 agents, 18M tokens, about 3 h) cost about 70 window points across the 02:50 reset.
- **The final review** (`wf_488b3250-97f`; records in `docs/reviews/M3/final-*.json`) ran six Opus lenses. 26 findings, 20 survived the skeptics, in four fix packages, all merged (`f12e607`). **1177/1177 tests pass in 134 s with no SCRIPT ERROR or ERROR.** The preset has 450 values.
  - The warning lens found **no high or medium defect**: every archetype lights the right corners behind-left, behind-right and directly behind.
  - **Fixed:**
    - a face-down knockdown put the lens under the street (floor clearance);
    - the boss pound's cap went through the lens (a squat pose);
    - the dropped pipe rolled out of reach (rest damping);
    - approaching enemies walked through the player and walled the lens (every archetype orbits the ring now);
    - Kickers kept the whole ring turning (they take their own seats behind);
    - the slam read as the headbutt (a heave);
    - the phase 2 beckon was cut;
    - an armored Bruiser jammed at the nose;
    - the knees on a held Bruiser read as armor;
    - the boss's adds spawned while F1 was open;
    - a heavy burst wasn't larger above size 1.35;
    - the instruments' flake and drift.
  - **Partial:** the boss is no longer stun-locked to death (it wakes in place and attacks), but a scripted player still beats it in about 41-43 s. The open call for Game-boy: the proposal not taken is wake-up armor; `boss_health` is the knob.
- **Running:**
  - a Sonnet agent folding the fixers' doc wording into ARCHITECTURE, README and the calls log;
  - an Opus verifier re-checking the high fixes in first person in `.worktrees/m3-verify-final`;
  - the lead's recordings of "Mixed waves" and "Boss wave, held back" in `captures/m3_evidence/`.
- **Then:**
  1. Commit the docs.
  2. The export (`godot --headless --export-release "macOS" "builds/macos/Beat-em-Up PoC.zip"`): smoke it headless with `--quit-after 900`, then run it windowed once.
  3. `gh release create m3-playtest-1 "builds/macos/Beat-em-Up PoC.zip" --prerelease --target m3/enemy-ai`.
  4. The M3 PR (never merge it).
  5. The Slack DM to Michael (`U0AQMKKBL93`): the release link and the digest from `M3-judgement-calls.md`.

### 2026-10-26 03:15 CDT: P4-int merged (1130/1130): the done-when proved; the final review running
5-hour 2% (resets 07:50 CDT), weekly 44% (resets Mon 2026-10-26 05:00 CDT).
- **P4-int merged** (`7a015cc`). **1130/1130 tests pass in 108 s with no SCRIPT ERROR or ERROR.** The preset has 443 values.
  - **`tests/test_m3_done_when.gd`:** a real Punk, Kicker, Bruiser, Thug and boss at 135° left, 135° right and 180° light left only, right only and both, from the wind-up's first frame to the contact. There are negative controls, and a 1500-frame mixed-six soak asserts the hard metrics.
  - **`tools/check_m3_log.py`:** ok on all 17 runs.
  - **The five evidence acts** are in `tests/bot/acts/crowd_acts.gd`, with sheets (local) in `.worktrees/m3-p4-int/captures/m3_p4/`.
  - **The LB pick-up cue** (`game/ui/pickup_cue.gd`).
  - **A static named-AnimationLibrary cache** in HumanoidRig: the spawn hitch's median went from 28.8 ms to 25 ms (limit 33), and the frame p95 is 13.1 ms.
  - **Measured:** R10 100% over 112 checks, and the L2 rubric is yes except Q6. R8 p95 is 53-65% while the autopilot punches what's in front of it (a soft miss).
- **Flagged for the final review:**
  - the non-KO knockdown view ("belly slab", M2's default) is frequent in a mixed crowd;
  - the boss is too easy for the autopilot, since P P P P keeps it staggered or down;
  - the LB cue is small.
- **The curated judgement-call log** is `docs/milestones/M3-judgement-calls.md` (`51e38cb`): 63 entries, 18 of them possible spec departures for Game-boy's ruling. The Slack digest comes from it.
- **Running since 03:13 CDT:** workflow `wf_488b3250-97f`, `docs/reviews/M3/workflow-review.js` with `args-review-final.json` (round "final", base `7a015cc`, six Opus lenses: warn, crowd, tells, code, fair, perf), then Sonnet skeptics, the partition and Sonnet fixers on `m3/fix-final-<pkg>`.
  - **If cut off:** within this session, use `resumeFromRunId: "wf_488b3250-97f"`. In a new session, rerun the same args, and pass `packages` from the journal if `m3/fix-final-*` branches exist.
- **Also running:** a Sonnet agent drafting README's M3 status, controls and departures, and ARCHITECTURE's title and Ownership (lead reviews, then commits).
- **Then:**
  1. Merge the fixes, regenerate, run the tests.
  2. Save `docs/reviews/M3/final-*.json`.
  3. The export: `godot --headless --export-release "macOS" "builds/macos/Beat-em-Up PoC.zip"`. Smoke it headless and windowed.
  4. `gh release create m3-playtest-1 --prerelease --target m3/enemy-ai`.
  5. The M3 PR (never merge it).
  6. The Slack DM to Michael (`U0AQMKKBL93`) with the release link and the digest.

### 2026-10-26 02:15 CDT: phase 3 merged (1110/1110): every archetype is in; P4-int running
5-hour about 60% (resets 02:50 CDT), weekly about 44% (resets Mon 2026-10-26 05:00 CDT). Phase 3 (two Sonnet builders, 1.35M tokens, 51 minutes) cost about 10 window points.
- **Merged:** P3-bruiser and P3-boss, with no conflicts. The lead fixed the boss bar to read "BOSS" (`encounter_spawner.gd`). The preset was regenerated (439 values) and the moves too (41). **1110/1110 tests pass in 125 s with no SCRIPT ERROR or ERROR** (`89b5509`).
  - **The Bruiser:** purple, 2.05 m, 80 HP.
    - Armor: jabs are absorbed with a grey spark, a low clank and ARMOR in the log. A hook or uppercut staggers it. The haymaker knocks it down and opens its armor for 2 s from its get-up.
    - It's grabbable only while staggered or open, and held 0.3 m further out. A parry still staggers it.
    - The overhead smash (15), plus the grab and headbutt. Cooldown 4.0.
  - **The boss:** charcoal and orange, 2.3 m, 300 HP, never grabbable.
    - Armor: light hits are absorbed; heavy hits stagger except during its charge and pound wind-ups (only the grab's wind-up is cut). Finishers knock it down.
    - The charge (4 m, reach 5.3 so it warns from behind), the pound (unblockable, jumpable) and the grab slam.
    - Phase 2 at 50%: it turns 1.8x faster and calls 2 Punks one at a time. A parry gives a 36-frame recoil.
    - The autopilot kills it in about 38 s (the L5 lens should judge).
- **The lead's look** (`.worktrees/m3-p3-boss/captures/final_charge/charge_windup.png`, local): the charge's crouch, the run-in and the hit read, and the boss bar shows at bottom centre.
- **Running since 02:13 CDT:** workflow `wf_1aa8a3fc-8e7`, `workflow-build.js` with `docs/reviews/M3/args-P4-int.json`:
  - `test_m3_done_when.gd` and `check_m3_log.py`;
  - the mixed-six, waves-to-the-boss, every-archetype warning and perf acts;
  - crowd-bot housekeeping and an LB pick-up cue;
  - a perf fix if R15 fails.

  **If cut off:** rerun the same args. Within this session, use `resumeFromRunId: "wf_1aa8a3fc-8e7"`.
- **Also running:** a Sonnet subagent folding every `M3-calls/*.md` into `docs/milestones/M3-judgement-calls.md` (that file only; the lead commits it).
- **Then:**
  1. Merge P4-int.
  2. The final review round: `workflow-review.js` with round "final", base the merge commit, and lenses L1 warning, L2 crowd readability, L3 archetype tells and identity, L4 code and layers, L5 fairness and pacing (the boss's difficulty, R12 with Thugs), L6 performance (Part B §B4). It needs about 40-50 window points, so launch it after a reset.
  3. Merge the fixes.
  4. The docs (README M3 status and departures, ARCHITECTURE title and ownership), the export, `gh release create m3-playtest-1 --prerelease`, the PR, and the Slack DM.

### 2026-10-26 01:20 CDT: phase 2 merged (1007/1007); phase 3 running
5-hour 45% (resets 02:50 CDT), weekly 41% (resets Mon 2026-10-26 05:00 CDT). Phase 2 (four Sonnet builders, 2.5M tokens, 79 minutes) cost about 24 window points.
- **Merged into `m3/enemy-ai`**, with no conflicts (`enemy_actor.gd` auto-merged). The preset was regenerated (431 values) and the moves too (38). **1007/1007 tests pass in 113 s with no SCRIPT ERROR or ERROR** (`9e3b9e9`).
  - **P1-engage:** token holders wait squared up on the ring until the go is near (`EnemyDirector.windup_eta_s()`), so nothing waits at the nose. A lone Punk on the player's axis aims 0.1 m off-centre. The Punk's jacket is deep teal, since SPEC §10 reserves red.
    - Side effect: with a player who takes every hit, the crowd attacks strictly in turns (R1 1, was 2), because the hit grace holds the next wind-up. It goes in the digest.
  - **P2-grab:** enemy grabs on the player end to end.
    - `EnemyHold`: the grab moves `bruiser_grab`, `bruiser_headbutt`, `boss_grab` and `boss_slam`.
    - The upright held view, look locked toward the grabber, a MASH P/K prompt with a gauge, and break-free that staggers the holder.
    - Magnetism in a crowd.
    - The holder covers about 63-71% of the lens while it holds.
  - **P2-kicker:** lime, a 3.0 s cooldown. It orbits the ring to the blind side and strafes toward the view edge; a jump kick (reach 2.75 m including the leap) and a low sweep (knockdown, jumpable).
  - **P2-thug:** olive with a yellow pipe, three 10-damage swings (the third staggers), and an 8.0 s cooldown. It drops the pipe toward the attacker, within LB reach, and fights with the Punk's moves after.
    - R12 (worst 2 s of damage at most 30) can't hold with a Thug, since its combo is 30 by the spec.
    - The dropped pipe lies below the forward lens, so a pick-up cue would help (phase 4 candidate).
- **The lead's look** (`.worktrees/m3-p2-grab/captures/final/s_mash.png`, `.worktrees/m3-p2-kicker/captures/p2-kicker/flanks/flank_fp.png`, `.worktrees/m3-p2-thug/captures/onev1/sheet.png`, local): the grab, the held view and the break-free read; the Kicker slides out of view to the flank; the Thug's cocked pipe reads.
  - **Palette watch:** the Kicker's lime and the Thug's olive are both green. Their caps (black, white) and the pipe tell them apart. The Bruiser gets purple and the boss charcoal with orange.
- **Running since 01:20 CDT:** workflow `wf_29001c6b-9d9`, `workflow-build.js` with `docs/reviews/M3/args-P3.json`: P3-bruiser and P3-boss, two Sonnet builders.
  - **If cut off:** rerun the same args. Within this session, use `resumeFromRunId: "wf_29001c6b-9d9"`.
  - **Then:**
    1. Merge both, regenerate, run the tests, look at the sheets.
    2. Phase 4: P4-int (Part C §8 as amended by A7: `test_m3_done_when.gd`, `tools/check_m3_log.py`, mixed-six acts, perf), then the final review round (`workflow-review.js`, round "final", lenses L1-L6 per Part B §B4).
    3. Then the docs (README M3 status and departures, ARCHITECTURE, judgement calls folded), the export and GitHub release, the PR, and the Slack DM.

### 2026-10-26 00:00 CDT: the slice gate passed (869/869); phase 2 running
5-hour 20% (resets 02:50 CDT), weekly 37% (resets Mon 2026-10-26 05:00 CDT). The slice review (64 agents, 6.7M tokens, about 2.4 h) cost about 25 window points across the 21:50 reset, and 5 weekly points.
- **The slice gate passed.** Its verdicts, evidence and the **feel defaults it locked** are in [M3-slice-gate.md](milestones/M3-slice-gate.md); the records are in `docs/reviews/M3/slice-*.json`.
  - The hard metrics pass everywhere.
  - **The rear warning passes clause by clause** (the done-when's second half) with dummies and real Punks.
  - Three crowd findings survived and were fixed (`m3/fix-slice-punk-crowd-pressure`, merged):
    - backing-off Punks running the wrong way;
    - too little posturing (`punk_attack_cooldown_s` 1.4 → 5.0);
    - the lens wall, mostly fixed.
  - **869/869 tests.**
  - **Call:** the off-screen band at 46-55° keeps the spec's 55°, for the digest.
- **Running since 23:59 CDT:** workflow `wf_de359dcf-2ee`, `workflow-build.js` with `docs/reviews/M3/args-P2.json`. Four Sonnet builders at once:
  - **P1-engage:** token holders wait on the ring for their go instead of at the player's nose; the lone on-axis Punk; the Punk's red jacket recoloured (SPEC §10 reserves red);
  - **P2-grab:** enemy grabs on the player, the mash, the held view, magnetism in a crowd;
  - **P2-kicker;**
  - **P2-thug.**

  P1-engage and P2-grab both edit `enemy_actor.gd`, in separate functions; the lead merges them.
  - **If cut off:** rerun the same args. Within this session, use `resumeFromRunId: "wf_de359dcf-2ee"`.
  - **Then:** merge P1-engage, P2-grab, P2-kicker and P2-thug, regenerate the preset and moves, run the suite, and look at the grab, kicker and thug sheets. Then phase 3 (P3-bruiser, P3-boss; `args-P3.json`).

### 2026-10-25 21:30 CDT: P1-int merged (866/866); the slice gate's review running
5-hour 71% (resets 21:50 CDT), weekly 32% (resets Mon 2026-10-26 05:00 CDT). P1-int (one Sonnet builder, 760k tokens, 92 minutes) cost about 9 window points.
- **P1-int merged** (`4470830`, with `356fccf` for CLAUDE.md's main scene and cadence). **866/866 tests pass in 99 s with no SCRIPT ERROR or ERROR.** The preset has 424 values.
  - The slice plays end to end in the crowd room, with the probe, autopilot and oracle wired into ten crowd-bot acts (`tests/bot/acts/slice_acts.gd`).
  - **The hard metrics R1, R2, R3, R10 and R11 pass in every act**, and the headless run of all acts has 192 `WARN-CHECK ok` and 0 FAIL.
  - **Flinch-lock fixed:** no wind-up starts while the player is in hitstun or stagger, or within `director_hit_grace_s` (0.5) of an unblocked hit. The longest chain of hits went from 4.8 s to 1.15 s, and a passive player's KO from 11 s to 12-15 s.
  - `engage_margin_m` 0.05.
  - The exit "resources still in use" was the audio mixer; the bot now stops voices before quitting.
  - **Soft misses:** R8 (lens coverage) p95 is 52-58% in the six-Punk acts, against at most 50%; the step-in jab is the lever left untried. R9 in the waves act is a sample of 1.
  - All measurements are in `docs/milestones/M3-calls/P1-int.md`. Its sheets (local) are in `.worktrees/m3-p1-int/captures/p1-int/`.
- **The lead's look** (`fight/sheets/overview_3_13.png`, `warn/sheets/corners.png`, `observed/sheets/turn360.png`):
  - the corner bursts sit inside their corners, left, right and both;
  - Punks spread around on the ring;
  - at strike range a Punk fills much of the lens, its head sometimes cut by the top edge.
- **Running since 21:30 CDT:** workflow `wf_10d57668-722`, `docs/reviews/M3/workflow-review.js` with `args-review-slice.json` (round "slice", base `356fccf`).
  - It runs three Opus reviewers, one per lens (warn, crowd, code), in `.worktrees/m3-review-slice-<lens>`, then three Sonnet skeptics per finding, a partition and Sonnet fixers in `.worktrees/m3-fix-slice-<pkg>` on branches `m3/fix-slice-<pkg>`.
  - **If cut off:** within this session, resume with `resumeFromRunId: "wf_10d57668-722"`.
  - In a new session:
    - reviewers that finished saved nothing to the repo, so rerun the same args;
    - if `m3/fix-slice-*` branches exist, pass the partition (from the journal) as `packages`;
    - the fixers reuse `wip` branches.
- **Then:**
  1. Merge the fix branches, regenerate, run the tests and push.
  2. Save the review records as `docs/reviews/M3/slice-*.json`.
  3. Write `docs/milestones/M3-slice-gate.md` (evidence, verdicts, the feel defaults locked).
  4. Fold the calls into `M3-judgement-calls.md`.
  5. Phase 2 (`args-P2.json`: P2-grab, P2-kicker, P2-thug).

### 2026-10-25 20:00 CDT: phase 1 merged (858/858); P1-int running
5-hour 61% (resets 21:50 CDT), weekly 31% (resets Mon 2026-10-26 05:00 CDT). Phase 1's five Sonnet builders (2.6M tokens, 63 minutes) cost 21 window points, about 4 each.
- **Merged into `m3/enemy-ai`,** in order, with no conflicts: P1-ai (EnemyActor and the Street Punk), P1-director (tokens, blind-spot priority, spread, `may_start_windup`, `report_stalled`), P1-room (the crowd room, navmesh, waves, F4 spawns, the crowd bot), P1-hud (the rear warning, the F3 AI overlay, the boss bar hookup, wind-up voices) and P1-instruments (the readability probe R1-R15, autopilot and warning oracle).
- **The lead's fixes** (`17d3fb9`):
  - three of P1-ai's tests now use the stub director, since the real one grants tokens;
  - the 15% test reports how many chains it checked;
  - the contract says RearWarning's `cleared(side)` (a Control can't redefine `hidden`);
  - **the crowd room is the main scene**;
  - `capture_bot.sh` caps a recording at `CAPTURE_MAX_FRAMES` (54000);
  - the preset was regenerated (423 values).

  **858/858 tests pass in 93 s with no SCRIPT ERROR or ERROR.**
- **The builders' notes for the gate:**
  - **Lens coverage:** at strike range (about 0.95 m) the Punk covers about half the lens.
  - **Flinch-lock:** the director paces wind-up starts (0.35 s) but grants three tokens at once.
  - **Warning time:** a 0.4 s wind-up behind the player is short.
  - **Resource leak at exit:** bot runs with real enemies end with "resources still in use at exit".
  - **Autopilot:** it was tuned on stubs.
  - **Player avoidance:** P1-room cut `player_avoid_radius_m` to 0.3; at 0.5, Punks hovered and never attacked.
  - **Rear-warning defaults:** P1-hud retuned them (base 160 px, inset 96 px, heavy ×1.3) so every burst stays inside its corner.
- **Running since 20:00 CDT:** workflow `wf_a5124e9b-25f`, `workflow-build.js` with `docs/reviews/M3/args-P1-int.json` (P1-int, `.worktrees/m3-p1-int`, branch `m3/p1-int`). It is settling the five items above and recording every slice act with the probe.
  - **If cut off:** rerun the same args. Within this session, use `resumeFromRunId: "wf_a5124e9b-25f"`.
  - **Then:**
    1. Merge P1-int, regenerate, run the tests and push.
    2. The lead looks at the slice sheets and the `readability.json` files.
    3. **The slice gate:** `docs/reviews/M3/workflow-review.js` with round "slice", `base` the merge commit, lenses L1 (warning), L2 (crowd readability) and L4 (code and layers), with briefs written from Part B §B4. Save the args as `args-review-slice.json`.
    4. Merge the fixes, then write `docs/milestones/M3-slice-gate.md` (evidence, verdicts, the feel defaults locked).
    5. Phase 2.

### 2026-10-25 18:55 CDT: S0 merged (587/587); phase 1 (five builders) running
5-hour 40% (resets 21:50 CDT), weekly 27% (resets Mon 2026-10-26 05:00 CDT). S0, one Sonnet builder (690k tokens, 31 minutes), cost about 5 window points.
- **S0 merged** into `m3/enemy-ai` at `4a5341d`. **587/587 tests pass with no SCRIPT ERROR or ERROR.** The preset regenerated unchanged at 419 values.
  - The lead reviewed every hunk of `combat_actor.gd`, `hit_detector.gd`, `player.gd`, `tuning_overlay.gd` and `game_input.gd` against Part A and §2.2: they match.
  - `d393a7b`: `test_m3_contracts.gd` no longer pins tunable defaults (owners retune their own), only their subgroups.
  - S0's calls are in `docs/milestones/M3-calls/S0-scaffold.md`.
- **S0's notes for later phases:**
  - P3 must decide the parried boss: `_parry_staggers()` false plus recoil 0 means a parry only blocks.
  - The pin order changed M2's player grabs slightly (a held victim now processes right after its holder): watch the grab acts at the slice gate.
- **Running since 18:50 CDT:** workflow `wf_ed4bf1ae-4e9`, `workflow-build.js` with `docs/reviews/M3/args-P1.json`. Five Sonnet builders, four at a time, each in `.worktrees/m3-p1-<key>` on branch `m3/p1-<key>`: P1-ai, P1-director, P1-room, P1-hud, P1-instruments. The watcher checks every 15 minutes during the run.
  - **If cut off:** rerun the same args (the loader reuses `wip` branches, skips done ones). Within this session, use `resumeFromRunId: "wf_ed4bf1ae-4e9"`.
  - **Then:**
    1. Merge P1-ai, P1-director, P1-room, P1-hud and P1-instruments, in that order. Regenerate the preset and the moves (only `punk_*.tres` may be new), run the full suite and push.
    2. Set `run/main_scene` to `res://game/level/crowd_room.tscn`.
    3. Run P1-int as a one-package `workflow-build.js` run (Part C §5 "P1-int", as amended by A3.6).
    4. The slice gate: `docs/reviews/M3/workflow-review.js`, round "slice", lenses L1, L2 and L4.

### 2026-10-25 18:20 CDT: M3 plan written; S0 (the contract scaffold) building
5-hour 34% (resets 21:49 CDT), weekly 26% (resets Mon 2026-10-26 05:00 CDT). The planning workflow (10 Opus agents, 3.4M tokens) cost 32 window points and 5 weekly points, which is the old costs divided by 5.
- **The plan is [docs/milestones/M3-plan.md](milestones/M3-plan.md).**
  - It started as three independent plans (contracts-first, vertical-slice, readability-first) and a judge, all in `docs/milestones/M3-planning/`.
  - The vertical-slice plan won (Part C, verbatim). The judge's grafts and fixes are binding amendments (Part A), and the done-when is made checkable in Part B: the warning's truth table, readability metrics R1-R15, the evidence pack and the review lenses.
  - Codemaps of everything M3 builds on are in `docs/milestones/M3-codemap/`.
- **Phases:**
  - **S0**, the contract scaffold: hooks, look API and ViewGeometry, MoveData `reach_m`, signals, every tunable, skeletons for EnemyActor, EnemyDirector and EnemyCatalog, pose and generator dispatch, fixtures and `capture_bot.sh`.
  - **Phase 1**, the Street Punk vertical slice, five builders in parallel: P1-ai, P1-director, P1-room, P1-hud and P1-instruments. Then P1-int, then **the slice gate**, a review in first person on hard metrics.
  - **Phase 2:** P2-grab, P2-kicker and P2-thug.
  - **Phase 3:** P3-bruiser and P3-boss.
  - **Phase 4:** integration, the review round, docs, the export and release, the PR, and the Slack DM.
- **Builds run through `docs/reviews/M3/workflow-build.js`** with args saved as `docs/reviews/M3/args-<phase>.json`. It is resumable: a package is done when its branch `m3/<key>` has a commit `M3 <key>: ...`, wip when the branch exists without one, and new otherwise.
- **Running since 18:15 CDT:** workflow `wf_6f2443d3-3fd`, `workflow-build.js` with `args-S0.json` (one Sonnet builder, `.worktrees/m3-s0-scaffold`, branch `m3/s0-scaffold`).
  - **If cut off:** rerun `Workflow({scriptPath: "<repo>/docs/reviews/M3/workflow-build.js", args: <args-S0.json>})`. Within this session, use `resumeFromRunId: "wf_6f2443d3-3fd"`.
  - **Then:** the lead reviews every hunk of `combat_actor.gd`, `hit_detector.gd`, `player.gd` and `tuning_overlay.gd`, merges `m3/s0-scaffold` into `m3/enemy-ai`, regenerates the preset, runs the full suite and pushes, then launches phase 1 with `args-P1.json`.
- **Done meanwhile:**
  - M2 worktrees pruned (every branch kept);
  - `git config merge.keep-ours.driver true`;
  - CLAUDE.md's test time is now about 90 s (baseline 537/537 in 73 s);
  - the export templates are installed and a test macOS export works (63 MB, universal, ad-hoc signed, runs headless clean).

### 2026-10-25 17:05 CDT: M2 merged; Milestone 3 started on `m3/enemy-ai`
Account: premium seat (5 times the old limits). 5-hour 0% (resets 21:49 CDT), weekly 21% (resets Mon 2026-10-26 05:00 CDT).
- **Game-boy signed off M2.** PR #2 is merged into `main` (`2847863`). The old `.worktrees/m2-*` can be pruned.
- **Milestone 3 (SPEC §12): enemy AI and the rear warning**, on branch `m3/enemy-ai` from `main`. Game-boy asked (2026-10-25 16:50) for the work to run without his input until M3 is done to spec. When it is, the lead DMs him on Slack (Arachne Finance, Michael, `U0AQMKKBL93`) with:
  1. a link to a playable build;
  2. a digest of the key judgement calls, each with at least one alternative not taken and why.
- **Game-boy's answers (also in the Decisions log):**
  - **Playable link:** a GitHub Release on the private repo with a zipped macOS export. Downloading Godot's official 4.7.2 export templates is approved.
  - **Boss:** a graybox boss in M3, with a placeholder name. Its name and look wait for the art milestones.
  - **Enemy grabs on the player** (the Bruiser's grab and headbutt, the boss's grab slam): mash P/K to break free. A dodge or a heavy hit gets out of the wind-up. Unbroken, the hit lands.
- **Defaults the lead took** (Game-boy saw them and didn't object):
  - a new 12 × 30 m street-lane crowd room becomes the main scene, with doorway and alley spawns (some behind the player) and repeating mixed waves of up to 6 enemies, with a key back to the M2 training room;
  - a KO'd player auto-revives there, as in the test room;
  - enemies don't block;
  - the Pipe Thug drops a pipe the player can take;
  - the full director (tokens, blind-spot priority, spread), a navmesh with avoidance;
  - the rear warning per SPEC §8, with its tunables in F1;
  - enemy spawns in F4, and the AI state and tokens in F3.
- **Blocked on Game-boy? DM him on Slack at once** (Game-boy, 17:35): anything only he can unblock (a permission or authorization prompt, a login, a decision) goes to a Slack DM to Michael (`U0AQMKKBL93`), with what is blocked and what you do meanwhile. His aim is to keep the work running without stalls, not to keep messages few.
- **Usage watcher:** new cadence and the resume task for the premium seat (see "Usage watcher" and "Resume after a limit"). Started from this session.
- **Next:** map the codebase for M3, write `docs/milestones/M3-plan.md`, then build in parallel worktrees.

### 2026-10-25 15:20 CDT: leg 2 done (round 3 merged, 537/537); leg 3 done; the M2 PR is open for Game-boy
Account E: 5-hour about 30% (resets 19:09 CDT), weekly 83% (resets Tue 2026-10-27 17:00 CDT). The two r3 fixers (`wf_27da4731-a29`, 46 minutes) took the window from 0% to 29% and weekly from 78% to 83%.
- **Leg 2 done.** `m2/phase3-fix-r3-ko-view-return` (`846f3ae`) and `m2/phase3-fix-r3-dummy-room` (`d1a2073`) are merged into `m2/hit-feel` with `m2/phase3-review` (`fix-r3-*.json`). The merges were clean. **537/537 tests pass with no SCRIPT ERROR or ERROR.** The preset regenerated unchanged at 327 values.
  - **r3look-01 and -02, fixed:**
    - The head layer hides again on the way back as soon as the lens is near the head.
    - The look is dropped from the killing blow until the revive and put on the body there (`player.gd` `_process()`, `_revive()`, `_tick_ko()`). Non-KO knockdowns keep a free look.
    - The look turns ahead of the lens on the return (`ko_view_look_lead` 1.5).
    - The fallbacks: across the body, then along it past the feet, then over the hips (2.6 m up, 85°).
    - `ko_view_min_reach` went from 0.4 to 0.8, and now means the least room a pose needs.
    - The lens is sphere-checked.
    - In first person: the own body covers at most 21%, and nothing comes nearer the lens than 0.274 m.
  - **r3code-02, r3look-04 and r3code-04, fixed:**
    - The walk home casts the capsule ahead against actor bodies and stops short of anyone in the way. A walk given up against the world isn't retried until the dummy is hit, re-posted or moved.
    - The comeback's tie-break picks the spot nearest 50° off the player's facing (`dummy_respawn_off_axis_deg`): 19% of the view against 55%.
    - `grab_hold_blend_s`, `grab_pin_ease_s` and `stagger_snap_blend_s` are now tunables.
  - The lead looked at `ko13_after.png`, `ko7_after.png` and `k4_comeback.png` (local, in the two fix worktrees' `captures/fix/`). They read right. A merged-build recording (`captures/lead_final/merged_fp.png`, local: the hook, the uppercut and the knee KO in first person) shows nothing broken by the merges.
- **Leg 3 done:**
  - README: Milestone 2 status; the departures for the out-of-body KO view (with its over-the-hips fallback and locked look) and the finisher's flash after the impact frame; the comeback to one side; the hook's 0.33 m; the test count.
  - ARCHITECTURE: all of r3code-06's items; the fixers updated the KO-view and comeback sections.
  - **The M2 PR is open:** https://github.com/mikedtcm22/beat-em-up-PoC/pull/2 (`m2/hit-feel` into `main`). It lists every default taken. **Never merge it** without Game-boy's sign-off.
- **Waiting on Game-boy:** play the PR build, tune each tier live in F1 and save a preset (M2's done-when), listen to WP3's audio, and sign off. The open questions all took their defaults (14:15 decision) and are listed in the PR, for when the art is in.
- **Next (after sign-off):** merge PR #2, then plan Milestone 3. No M2 work is left on any branch. The old `.worktrees/` can be pruned once the PR merges.

### 2026-10-25 14:20 CDT: account E claims leg 2's rest and leg 3; r3-ragdoll-kick-body merged (523/523)
Account E: 5-hour 0% (resets 19:09 CDT), **weekly 78%** (resets Tue 2026-10-27 17:00 CDT). Weekly is the limit: 12 points below 90% is about 70 points of a 5-hour window (one window point costs about 0.16 weekly points). Its watcher is "Beat-em-up: usage watcher" (`usage-watcher`, Haiku).
- **Leg 2's rest and leg 3 claimed by account E at 14:20 CDT.**
- **Merged:** `m2/phase3-fix-r3-ragdoll-kick-body` and `m2/phase3-review` into `m2/hit-feel` at `b01e35d`. **523/523 tests pass with no SCRIPT ERROR or ERROR.** The preset regenerated unchanged (318 values). Pushed.
- **Game-boy (14:15 CDT):** for the rest of M2, every open question takes its default. Game-boy can't tell the grey-block feel differences apart until the art goes in, so this milestone puts no new questions to Game-boy: each default is recorded, and art-dependent feel polish waits for the art. (Also in the Decisions log.)
- **Running since 14:22 CDT:** workflow `wf_27da4731-a29`, `workflow-fix.js` with `packages_file` "packages-r3.json", `only` ["r3-ko-view-return", "r3-dummy-room"], `fixer_model` "sonnet", `concurrency` 2, and `fixer_cost` 5 (the gate compares one window point with weekly's 12 points of headroom, so 15 would skip both). Its `note` is the args file's `fix_note`, plus the 14:15 decision: raise no new questions, take the default that changes least, and list it as "decided by default". The worktrees are `.worktrees/m2-fix-r3-ko-view-return` and `.worktrees/m2-fix-r3-dummy-room`. **If cut off:** rerun the same args (the loader reuses `wip:` branches). Within this session, use `resumeFromRunId: "wf_27da4731-a29"`.
- **Leg 3, started by the lead meanwhile** (`ffbb881`):
  - README: a "Milestone 2 status" section; the stagger figure is now 0.33 m (measured after the merge: 0.329-0.333 m on every hook, against 0.220 m at 0.6); two new departures, the out-of-body KO view and the finisher's flash after the impact frame; the dummy's comeback beside the player.
  - ARCHITECTURE: r3code-06's Hit flash "Frames", the hold view's builder (`_view_with()`) and the Interfaces list (`is_flying()`, `is_gone()`, `is_blinking_in()`, `impact_frame_ticks()`).
  - **Left for after the merge:** the "Get-up" bullet's "one of two places" (three, or more if r3-dummy-room's path check reads the ragdoll); the README's test count and time, and the KO view's mouse-look decision; then a few first-person sheets and the PR.

### 2026-10-25 14:05 CDT: handoff, account F's 5-hour window at 92%; round 3 reviewed (11 of 11 survive), 1 of 3 r3 packages fixed
Account F: 5-hour **92%** (resets 17:09 CDT), weekly 58% (resets Wed 2026-10-28 10:59 CDT). The round 3 run (`wf_4ff561cb-f25`, 52 agents, 111 minutes) took the window from 0% to 92% and weekly from 43% to 58%. Nothing is running. Every branch is pushed. No worktree has uncommitted tracked changes. **Game-boy switched to another account at 14:13 CDT.** This session is renamed "Beat-em-up: account F session (handed off)", and its watcher has stopped its loop. The new account starts its own watcher and claims the rest of leg 2 here first.
- **Round 3 review** (records on `m2/phase3-review` @ `6a0208e`: `review-r3code.json`, `verify-r3code.json`, `review-r3look.json`, `verify-r3look.json`, `packages-r3.json`, `fix-r3-ragdoll-kick-body.json`). Two Opus reviewers worked at `72a1066`, with three Sonnet skeptics per finding. **All 11 findings survive.** r3look-05 is a spec question.
  - **r3code** (the first code review of the fix diffs since `c27afaf`):
    - 01 (high): the kicked ragdoll body depended on a left-over pose cache. The hook's approved give swung from 0.22 m to 0.41 m with the dummy's history, and gap-07's seed silently moved the hook's lean kick. **The lead's 0.85 test threshold hid it.**
    - 02 (medium): gap-05's "wait, don't walk in" covers only the post. A player standing between a displaced dummy and its post is walked into every 1.25 s, with the fists filling the view.
    - 03 (low): an at-once take-over out of a running stagger jumps the head and arms in one frame.
    - 04 (low): feel numbers left in scripts: `_HELD_BLEND_S`, `_GRAB_EASE_S` and the stagger's 0.04 s blend.
    - 05 (low): stale code comments.
    - 06 (low): ARCHITECTURE mismatches, for leg 3.
  - **r3look** (the merged build in first person):
    - 01 (high): the KO view's return follows the mouse look and keeps the head layer drawn. It dives through the player's own face and chest (up to 75% of the view), then pops at 66%.
    - 02 (medium): a KO in a corner puts the lens 0.13 m inside the building front, with the shirt over 52-68% of the view. Between two fighters, the lens hovers 0.32 m over a dummy's head.
    - 03 (low): the hook's re-posed far fist swings at the attacker's lens: 0.200 m on open floor, 0.145 m at a building front.
    - 04 (low): the comeback beside an occupied post blinks in dead centre 0.8 m ahead, covering 56-58% of the view.
    - 05 (low, **spec question**): in first person the haymaker's delayed flash changes only 0.06-0.2% of the screen, against 2.2-9.4% for the other finishers. Its contact is above the view and under the burst.
  - The look reviewer's sheets for Game-boy (local) are in `.worktrees/m2-review-r3look/captures/review_r3look/`: `ko1_all.png`, `ko13_return.png`, `ko7_all.png`, `walls_fp.png`, `fin_flash_frames.png` and `k4_fp.png`. Its verdict on the KO view: it reads as a short out-of-body moment (about 3.3 s), and the distance looks right. The attacker is cut at the hips by the top edge, so you can't see who KO'd you.
- **Packages** (`packages-r3.json`):

  | Package | Findings | State |
  | --- | --- | --- |
  | `r3-ragdoll-kick-body` | r3code-01, -03, -05, r3look-03 | **fixed, not merged**: `m2/phase3-fix-r3-ragdoll-kick-body` @ `c2e1995`, 523/523 |
  | `r3-ko-view-return` | r3look-01, -02 | **skipped by the gate** (needed 15, had 14), no branch |
  | `r3-dummy-room` | r3code-02, r3look-04, r3code-04 | **skipped by the gate**, no branch |

  The unassigned items: r3look-05 (spec question) and r3code-06 (docs, for leg 3; the list is in `r3-ragdoll-kick-body`'s notes and in `fix-r3-ragdoll-kick-body.json`'s `remaining`).
  - **r3-ragdoll-kick-body's fix:**
    - the kick's body no longer depends on the cache. The hook strikes Head or UpperChest every time, which gives 0.32-0.35 m on every hook;
    - ARMS strikes the nearer shoulder, and LEGS the leg body nearest the contact;
    - head and arms ease in on an at-once launch out of a stagger (1.8°, hands 0.08 m);
    - the hook's far fist is raised beside the shoulder: nothing at the lens, and the corner lens test passes at 0.301 m (a thin margin);
    - comments fixed.
    - Sheets (local): `.worktrees/m2-fix-r3-ragdoll-kick-body/captures/fix/hook_after_sheet.png`, `uppercut_after.png`, `guardbreak_after.png` and `parry_after.png`.
- **Resume (leg 2's rest, then leg 3):**
  1. `get_usage`. Merge `m2/phase3-fix-r3-ragdoll-kick-body` and `m2/phase3-review` into `m2/hit-feel` first. The other two packages also list `player.gd` and `combat_actor.gd`, so they should branch from a base that already has it. Regenerate the preset (`godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd`), run `tools/run_tests.sh` (all pass, no SCRIPT ERROR or ERROR) and push.
  2. `Workflow({scriptPath: "<repo>/docs/reviews/M2-phase3/workflow-fix.js", args: {packages_file: "packages-r3.json", only: ["r3-ko-view-return", "r3-dummy-room"], fixer_model: "sonnet", concurrency: 2, fixer_cost: 15, note: <fix_note from args-r3-review.json>}})`. Today's Sonnet fixers cost about 13 points of the 5-hour window each, so 30 points of headroom fit both.
  3. Merge both branches and `m2/phase3-review`, regenerate the preset, run the tests and push. Look at the first-person after-sheets: the KO return with the look turned, the corner KO, the comeback off-centre.
  4. Leg 3 (D): the README (the Milestone 2 status; the hook figure, now about 0.33 m at 0.9 against 0.22 m at 0.6, to re-measure after merging; the departure for the out-of-body KO view; side view debug-only), ARCHITECTURE (r3code-06's list plus the KO-view and VFX sections), then the M2 PR. **Never merge it.**
  - `r3-ko-view-return` may decide to ignore mouse look while the player is KO'd and getting up (a control change in `player.gd`). The lead should check that call and tell Game-boy.
- **New for Game-boy** (defaults as built):
  - **The push's body, reframed** (replaces the 12:05 entry's question): today's code gave the milder 0.22 m on the first hook after a KO or a comeback, and 0.34-0.41 m otherwise. The fix makes the approved 0.32-0.35 m the give on every hook. Should the push land on the body nearest the contact instead (neck and chest, about 0.22 m on every hook)? Default: no.
  - **r3look-05:** the haymaker's flash barely shows in first person. Options: flash the nearest visible part (the chest), or offset the finisher burst. Default: as is. It joins grab-05 and hit-01.
  - Still open from 12:05: the non-KO knockdown view (the reviewer measured the belly slab at up to 74% of the view, over 50% for 63 frames); the HUD dot and HP bar in the KO view; the wall reaction.

### 2026-10-25 12:05 CDT: leg 1 done (round 2 merged, 518/518); leg 2 claimed by account F
Account F: 5-hour 73% (resets 12:10 CDT), weekly 42% (resets Wed 2026-10-28 10:59 CDT). Leg 1's four fixers took the window from 18% to about 70% and weekly from 33% to 42% in 55 minutes.
- **Leg 1 done.** Every r2 package is fixed and merged into `m2/hit-feel` with `m2/phase3-review` (the fix-r2-*.json records). **Head `72a1066`, 518/518 tests pass with no SCRIPT ERROR or ERROR.** The preset regenerated unchanged at 318 values (+18 tunables).
  - `r2-launch-into-walls` (gap-01, gap-03, gap-07, gap-08 d), at `2db5e4f`: a launch blocked by a wall, crate or curb hands over to the full ragdoll at once, from the pose on screen. The hips pull loosens while the capsule is stopped (`ragdoll_wall_reach_m` 0.5, `ragdoll_hips_blocked_hz` 1.5). A launch from behind takes over at once too. `Ragdoll.start()` seeds the drawn pose. New tunables: `grab_release_blend_s` and `reaction_snap_blend_s`. In first person the lens keeps at least 0.30 m away and the body covers at most 41% of the view.
  - `r2-vfx-first-use` (perf-01, perf-02, gap-08 e), at `e643e1c`. A windowed-only warm-up at load. The first hit in real time drops from 39/32 ms to 23.5/19.9 ms, and the first heavy hit, the first finisher and the first bruise compile no pipeline. The damage look's detail layer is always on (CLEAN is a transparent texture). A 2-3 ms residue on the first hit comes from something else (maybe the contact flash's first next_pass).
  - `r2-player-ko-view` (gap-02), at `4f7f706`: the out-of-body KO view, with seven tunables in Camera > "KO view" (1.7 m out, 1.6 m up, 40°, 0.8 s out, 0.5 s in, plus clearance). `test_tuning_panel.gd` was edited for the new subgroup.
  - `r2-dummy-comeback` (gap-05, gap-04, gap-08 a-c), at `45c70b2`. The dummy comes back 0.8 m in front of the player, in view, and stays put. The hook's far arm is bent near the guard. New tunables: `ko_blink_duty`, `dummy_respawn_gap_m` and five `dummy_return_*`/`dummy_face_*` values.
  - **Lead's merge fix** (`72a1066`): `test_ragdoll.gd`'s hook arm-trail check went from 0.8 to 0.85 of the trunk's trail. With gap-04's re-posed arm, the drawn far hand sags about 0.22 m under its raised pose at 0.45 arm influence (0.233 m against 0.280 m). Each branch passed alone. The lead recorded the merged hook (`captures/lead_r2merge/hook_fp.png`, local): the arm comes up bent and folds back into the guard, with no flail. Leg 2's code review is asked to judge this call.
  - **KO view, the lead's look** (the fixer's sheets, `.worktrees/m2-fix-r2-player-ko-view/captures/fix/ko1_out.png`, `ko1_in.png`, `ko3_out.png`): it reads as an out-of-body moment. The lens leaves at the killing blow, sweeps over the falling legs, settles beside the lying body with room around it, and comes back as the body sits up, with no pop. Weak spots: the lens passes the player's own head for a frame or two on the return, and the first 0.1-0.2 s show floor and legs before the body. ko1_out.png was shown to Game-boy.
- **New questions for Game-boy** (from the fixers; defaults as built):
  - the player's non-KO knockdowns get no KO view: the belly slab covers the view for about 1.3 s (`kd1.png` in the KO-view worktree). Proposal: the same view, shorter. Default: KO only, as he said;
  - the HUD centre dot and HP bar stay up during the KO view. Default: leave;
  - the wall reaction: a blocked launch loses its horizontal knockback, rises and drops at the wall's foot, and never goes onto or over the curb. Options: deflect, splat, bounce. Default: leave;
  - the push's part-body choice: `Ragdoll._queue_impulse()` picks the nearest part from a stale cache, which on a first ragdoll nearly always means the head, upper chest or foot. Choosing by the real contact would cut the hook's give from 0.32 m to 0.22 m. Default: keep;
  - `ragdoll_hips_blocked_hz` 1.5 is a trade-off between wall depth and the corner lens. He can tune it.
- **Leg 2 claimed by account F at 12:05 CDT.** The reviewer worktrees `.worktrees/m2-review-r3code` and `m2-review-r3look` are detached at `72a1066` and imported. The launch args are in [reviews/M2-phase3/args-r3-review.json](reviews/M2-phase3/args-r3-review.json): round 3, two Opus reviewers (code; the first-person look), Sonnet skeptics, the partition into `packages-r3.json`, then Sonnet fixers. Each step is gated. It launches after the 12:10 reset.
  - **Running since 12:11 CDT:** workflow `wf_4ff561cb-f25` with these args, launched at 5-hour 0% and weekly 43%. The watcher checks every 10 minutes during the run. Within this session, resume with `resumeFromRunId: "wf_4ff561cb-f25"`.
  - **If cut off:** `Workflow({scriptPath: "<repo>/docs/reviews/M2-phase3/workflow-r2-close.js", args: <args-r3-review.json>})`. If `review-r3code.json` or `review-r3look.json` is already on `m2/phase3-review`, drop that lens from `review_briefs`. If `packages-r3.json` is there, run `workflow-fix.js` with `packages_file` "packages-r3.json" instead.

### 2026-10-25 11:03 CDT: account F on leg 1; round 2 fixers running; gap-09 and leg 2's tooling done
Account F (the account that ran package C's reviews on 10-24) took the working session at 10:56: 5-hour 16% (resets 12:09 CDT), weekly 33% (resets Wed 2026-10-28 10:59 CDT). Its watcher is "Beat-em-up: usage watcher" (`usage-watcher`, Haiku). Account F has most of a week's headroom left, so it plans to take leg 2 after leg 1 and will claim it here first.
- **Running:** workflow `wf_a3f3d825-230`, `workflow-fix.js` with `args-r2-fix.json`, unchanged. Its first two fixers (Sonnet) work in `.worktrees/m2-fix-r2-launch-into-walls` and `.worktrees/m2-fix-r2-vfx-first-use`, branched at `f44f6b7`. `r2-player-ko-view` and `r2-dummy-comeback` follow as slots free, each gated.
- **If cut off:** rerun the same args. The loader skips a package whose branch has its final "review fixes" commit and reuses a `wip:` branch. Within this session, use `resumeFromRunId: "wf_a3f3d825-230"`.
- **Done by the lead while the fixers run** (on `m2/hit-feel`, pushed):
  - **gap-09, fixed** (`7a089bf`), after the lead confirmed it in the code. ragdoll_bot and vfx_bot now use the inherited `_matches()`, so `--act=a|b` works in every bot. combo_bot parks unused dummies on the floor behind the east end wall (`PARK`, x 24+, z 0) instead of at z −30, where they fell forever. A headless `a|b` run played both acts, and 486/486 tests pass. The exit-time "resources still in use" message was already there before.
  - **Leg 2's tooling** (`b6ac118`): `workflow-r2-close.js` takes `round` (files and keys carry `r<n>`), `review_brief` or `review_briefs` (`{lens: brief}`; lead-written briefs skip the critic; two reviewers at once, each in `.worktrees/m2-review-<lens>`; lens names have no `-`, e.g. `r3code`, `r3look`), `common_note`, `partition_lenses`, `partition_note`, `reviewer_model` (default opus) and `fixer_model` (default sonnet). Skeptics run on Sonnet. The shared context carries Game-boy's 2026-10-25 verdicts. It was dry-run with mocked agents (both paths).
- **Next (leg 1):** when the four fixers end, merge the `m2/phase3-fix-r2-*` branches and `m2/phase3-review` into `m2/hit-feel`, regenerate the preset, run the tests, push, then judge the KO-view sheets and show Game-boy one.

### 2026-10-25 10:53 CDT: Game-boy's verdicts; today's plan in legs, across accounts
Account E is at 91% of its 5-hour window (resets 12:30 CDT) and 78% weekly (resets Tue 2026-10-27 17:00 CDT). Game-boy played the build and gave his verdicts. **Another account starts leg 1 now.** Account E's session is renamed "Beat-em-up: account E session (paused)", and its watcher is stopped. After 12:30 it picks up the next leg nobody has claimed.
- **Decisions (Game-boy, 2026-10-25; also in the Decisions log):**
  - **Side view is a debug view**, not a player mode, so its looks don't matter now. Only first person counts; it may matter later for a 2-player mode. So:
    - hit-05 (side-view burst sizes) and gap-06 (the stomp's shins) are **dropped**;
    - the side-view flash's minimum size is answered: **leave it**;
    - hit-03 (the log in side view) is moot; grab-03, the log over the knee in first person, stays open.
  - **The player's KO: an "out of body" view.** The camera pans away from the body a bit and shows the player fully lying on the floor. It's the only time the camera leaves the player's eyes, and it needs a README departure in D.
  - **Every other proposed fix is approved as is:**
    - gap-01: the body hits the wall and crumples (full ragdoll from the pose on screen);
    - gap-03: a launch from behind pitches forward, away from the attacker;
    - gap-05: a dummy comes back in front of or beside the player, with room, and waits instead of walking into him;
    - gap-04: the hook's far arm stays bent near the guard;
    - gap-07: the ragdoll's first tick is seeded from the animation pose;
    - gap-08: the leftover numbers become tunables;
    - perf-01 and perf-02: warm-ups at load, and no shader-variant switch.
  - **Models: Opus plans and reviews; Sonnet codes and executes.** `workflow-fix.js` and `workflow-r2-close.js` have a new `fixer_model` arg. Skeptics already run on Sonnet; gates and scribes on Haiku.
  - **Passing between accounts today is fine**, to finish the fixes today.
- **Packages** (`packages-r2.json` on `m2/phase3-review` @ `ac0cfe9`, rewritten per the above, with notes that tell each fixer what changed):

  | Package | Findings |
  | --- | --- |
  | `r2-launch-into-walls` | gap-01, gap-03, gap-07, part of gap-08 |
  | `r2-vfx-first-use` | perf-01, perf-02, part of gap-08 |
  | `r2-player-ko-view` | gap-02, the out-of-body KO view |
  | `r2-dummy-comeback` | gap-05, gap-04, part of gap-08 |

- **Legs.** Each leg's owner writes "Leg N claimed by account X at HH:MM" here before starting and "Leg N done" when finished, so two accounts never work at once on the same files.
  - **Leg 1 done (account F, 12:05).** **Leg 1 claimed by account F at 10:58 CDT** (5-hour 16%, resets 12:09 CDT; weekly 33%, resets Wed 2026-10-28 10:59 CDT). Its watcher is "Beat-em-up: usage watcher" (`usage-watcher`).
  - **Leg 1, the round 2 fixes** (the account starting now):
    1. Start-up as in the takeover prompt: the session title, a watcher, `get_usage`.
    2. `Workflow({scriptPath: "<repo>/docs/reviews/M2-phase3/workflow-fix.js", args: <the contents of docs/reviews/M2-phase3/args-r2-fix.json>})`. It runs four Sonnet fixers, two at once, each usage-gated. If a gate skips a package, rerun later with `only`.
    3. Merge the four `m2/phase3-fix-r2-*` branches and `m2/phase3-review` into `m2/hit-feel`, regenerate the preset (`godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd`), run `tools/run_tests.sh` (all pass, no SCRIPT ERROR or ERROR), and push.
    4. Look at the KO-view sheets yourself (first person). It's new design, so show Game-boy one sheet.
  - **Leg 2, a final Opus review of the fixes, in first person:**
    - **Code review** of `c27afaf..m2/hit-feel`, the critic's high gap: the fixes were never code-reviewed. Check the layer rules, no feel numbers, static types and `##` docs, live `Tuning.changed` re-reads, and interactions between fixes built on separate branches (the from-hold launch against grab-02's release, the delayed flash against `_vanish`, `_turn_solid` against the respawn queries).
    - **First-person look** at the merged build: ragdoll_bot's acts, the finishers after hit-04, the KO view, the respawn.
    - **Tooling:** give `workflow-r2-close.js` a `review_brief` arg that skips the critic, and a `round` suffix for the file names (`review-r3.json`, `packages-r3.json`). Reviewers run on Opus, skeptics and fixers on Sonnet.
  - **Leg 3, D and the PR:**
    - Final first-person sheets for Game-boy.
    - README: the Milestone 2 status; the hook figure (0.346 m at 0.9 against 0.217 m at 0.6); new departures for the out-of-body KO view and the delayed finisher flash if it counts as one; side view noted as debug-only.
    - ARCHITECTURE's VFX, Audio, Ragdoll, Hit flash, hold-view and KO-view sections checked against the code.
    - Open the M2 PR from `m2/hit-feel` into `main`. **Never merge it** without Game-boy's sign-off.
  - gap-09 (bot harness: ragdoll_bot's `--act` ignores `a|b`, and parked dummies fall) is unverified and low. Fold it into leg 2 if cheap.
- **Still open with Game-boy** (each keeps its default, as now):
  - grab-03, the combat log over the knee in first person;
  - grab-05 and hit-01, the flash's first-person size and the flurry strobe;
  - hit-02, a hit on the player in first person;
  - grab-06's dead band;
  - the new look;
  - `ragdoll_partial_head_influence`;
  - more contortion on the contact push;
  - WP3's audio.

### 2026-10-25 09:12 CDT: round 2 reviewed (gap review: 8 of 8 verified survive); four r2 packages wait; weekly at 76%
The 5-hour window is at 83% (resets 12:30 CDT); **weekly is at 76%** (resets Tue 2026-10-27 17:00 CDT). Nothing is running. Every branch is pushed. `m2/hit-feel` @ `ed36d1b` has every C record (486/486 tests; no code changed since `8f5519f`).
- **The round 2 close** (`wf_e4327a11-eae`, 40 agents) took the window from 22% to 83% and weekly from 66% to 76%. The gap reviewer and its skeptics alone cost about 44 points of the window.
  - **The critic** (`critic-r2.json`): 16 gaps, 4 high:
    - hit-04's delayed flash judged only on the uppercut;
    - the merged build's first-person ragdoll acts never judged independently;
    - the player's own KO never probed;
    - the fix diffs never code-reviewed.
  - **The gap review** (`review-gap.json`, `verify-gap.json`): 9 findings. 8 are verified and survive, with no spec question; gap-09 is unverified.
    - gap-01 (medium): a body launched into a wall or the curb sinks its head up to 0.38 m into it.
    - gap-02 (medium): on the player's own KO, the first-person lens lies 7 cm above the floor behind the player's navy belly (41% of the view).
    - gap-03 (medium): an uppercut from behind snaps the body into the "launched" pose and throws its head into the attacker's lens (0.098 m).
    - gap-04 (low): the hook stagger's far arm still swings out dead straight (the stagger animation itself).
    - gap-05 (low): a dummy that comes back beside its occupied post arrives touching the player and walks in place against him.
    - gap-06 (low): on the stomp, the player's shins sink into the lying body's hips.
    - gap-07 (low): the respawn check reads the drawn ragdoll, which is wrong on a new ragdoll's first tick.
    - gap-08 (low): feel numbers left in scripts by the fixes.
- **Round 2's packages** (`packages-r2.json`, ordered by the partition):

  | Package | Findings |
  | --- | --- |
  | `r2-launch-into-walls` | gap-01, gap-03, gap-07, part of gap-08 |
  | `r2-vfx-first-use` | perf-01, perf-02, hit-05, part of gap-08 |
  | `r2-player-ko-view` | gap-02, gap-06 |
  | `r2-dummy-comeback` | gap-05, gap-04, part of gap-08 |

  All four fixers were skipped by the gate (7 points of headroom). None has a branch yet.
- **Weekly budget:** a 5-hour point costs about 0.16 weekly points here, so a fixer at 15-25 window points costs about 3-4 weekly points. The four fixers plus D (README, ARCHITECTURE, the PR) and the final sheets come to about 14-18 weekly points, against 14 left below 90% before Tuesday 17:00. **Game-boy's call:**
  - (a) D and the M2 PR first, so he can play, then the r2 fixers in priority order as the weekly allows;
  - (b) all four fixers first, then D and the PR, likely after the weekly reset.
- **Resume:**
  - the fixers: `workflow-fix.js` with `packages_file` "packages-r2.json", `concurrency` 1, `fixer_cost` 15 (or 20), and `only` for the order Game-boy picks. Use a `note` like the round 2 close's `fix_note` (merge head `ed36d1b`).
  - Then merge, regenerate the preset, run the tests.
  - D: README's Milestone 2 status, and the hook figure (0.346 m at 0.9 against 0.217 m at 0.6); ARCHITECTURE's VFX, Audio, Ragdoll, Hit flash and hold-view sections checked against the code; the PR, never merged without his sign-off.
  - gap-09 still needs its three skeptics.
- **Questions from the gap findings** (no spec change; the defaults are the fixers' proposals):
  - gap-01: wall-splat or bounce, or deflect along the wall?
  - gap-02: what the first-person view should show while the player is KO'd and getting up;
  - gap-03: whether the near-lens head for about 5 frames is acceptable;
  - gap-05: whether the dummy should come back in front of the player or beside him;
  - gap-06: whether the shin overlap is acceptable on a placeholder body.
- **Also open with Game-boy:**
  - grab-03 and hit-03, the combat log;
  - grab-05 and hit-01, the flash size and the flurry strobe;
  - hit-02, a hit on the player in first person;
  - the side-view flash;
  - grab-06's dead band;
  - bars on bodies that aren't upright;
  - the new look;
  - `ragdoll_partial_head_influence`;
  - the 12:40 entry's items.

### 2026-10-25 08:10 CDT: perf review done (2 of 2 survive); round 2 close running; weekly is now the limit
The 5-hour window is at 22% (resets 12:30 CDT); **weekly is at 66%** (resets Tue 2026-10-27 17:00 CDT). Weekly's 90% stop leaves 24 points until Tuesday, about two windows of heavy work, so round 2 runs lean: fixers one at a time, at a 15-point estimate each.
- **Perf review** (`review-perf.json`, `verify-perf.json`; both findings have 3 of 3 confirmations). Phase 3's code is cheap and doesn't leak:
  - six full ragdolls cost 1.35-1.41 ms a tick with the contact push on or off (partial: 1.12-1.22 ms), and they sleep 1.73 s after the hit;
  - 21 KO cycles of six dummies leave the node, object, resource, joint and body counts flat;
  - `hurt_point()` costs 4.9 µs, `flash_at()` 13 µs, `screen_anchor_of()` 19 µs a bar, `_respawn_spot()` 8-169 µs;
  - the hold view is negligible;
  - the flash warm-up works in both views (the first flash costs 0.15-0.88 ms with it, 3.3-8.7 ms without);
  - six rigs flashing cost about 0.24 ms of GPU;
  - known item (c), the first finisher's dropped frame, no longer reproduces (6 real-time runs).
  - **To fix:**
    - **perf-01:** the first hit of every fresh run drops a frame. The first comic sprite builds its material on the hit frame: 7-20 ms of main-thread CPU, and 24-38 ms real-time frames.
    - **perf-02:** a clean-to-bruised switch rebuilds the damage-look shader variant whenever no body shows a look: 3-5 ms, and 12-16 ms the first time.
  - Both are pre-phase-3 VFX code; the fix is a load-time warm-up or a constant material variant. Perf note on hit-02's option (c), a HUD vignette: it would need the same warm-up.
- **Running:** workflow `wf_e4327a11-eae`: `workflow-r2-close.js` with `base` `bba8633`, `concurrency` 1, `fixer_cost` 15 and a `fix_note`. It runs:
  - the critic (`critic-r2.json`);
  - a gap review only if the critic names high gaps (worktree `.worktrees/m2-review-gap` at `bba8633`, imported);
  - the partition of hit-05, perf-01, perf-02 and any gap survivors into `packages-r2.json`;
  - then the fixers through `workflow-fix.js`.
- **If cut off:**
  - with no `critic-r2.json`, rerun the same args;
  - with `packages-r2.json` there, run `workflow-fix.js` with `packages_file` "packages-r2.json", `concurrency` 1 and `fixer_cost` 15;
  - within this session, use `resumeFromRunId: "wf_e4327a11-eae"`.
- **Then:** merge the fix branches and `m2/phase3-review`, regenerate the preset, run the tests, record the final sheets for Game-boy, then D (README's Milestone 2 status and hook figures, ARCHITECTURE checked against the code, the M2 PR, never merged without his sign-off).

### 2026-10-25 07:25 CDT: account E resumed (Game-boy's call); round 2's perf review running
The 02:30 reset passed. At 07:15 the window was at 6% (it resets at 07:30 CDT); weekly was at 60% (resets Tue 2026-10-27 17:00 CDT).
- **Running:** workflow `wf_bd40aeb8-b63`: `workflow.js` with [reviews/M2-phase3/args-r2-perf.json](reviews/M2-phase3/args-r2-perf.json). It runs the perf review in `.worktrees/m2-review-perf` at `8f5519f`, then three skeptics per finding. The scribe writes `review-perf.json` and `verify-perf.json`.
- **New:** [reviews/M2-phase3/workflow-r2-close.js](reviews/M2-phase3/workflow-r2-close.js) (`b0f045b`) closes round 2 in one launch. Every agent reads the review files itself. In order:
  - the completeness critic over every review (`critic-r2.json`);
  - one gap reviewer if the critic names high gaps, with three skeptics per finding (`review-gap.json`, `verify-gap.json`);
  - the partition of hit-05 and the perf and gap survivors into `packages-r2.json` (keys `r2-`);
  - then `workflow-fix.js` as a child workflow.
  - Args: `base` (required), plus optional `no_gap_round`, `no_fix`, `fix_note` and `concurrency`.
  - First: `git worktree add --detach .worktrees/m2-review-gap <base>` and import it.
- **If cut off:**
  - If `review-perf.json` is missing on `m2/phase3-review`, rerun the perf args.
  - If it's there but `verify-perf.json` is missing, verify it the way the hit lens was verified.
  - Then run `workflow-r2-close.js`.

### 2026-10-24 23:23 CDT: hit-04 fixed and merged (486/486); 7 points left, so the lead stops here
The 5-hour window is at 83% (resets 02:30 CDT on 10-25); weekly is at 59% (resets Tue 2026-10-27 17:00 CDT). Nothing is running. Every branch is pushed. The worktrees have no uncommitted tracked changes.
- **Merged into `m2/hit-feel`:**
  - `m2/phase3-fix-r2-finisher-flash` (`9698617`). A finisher's contact flash now starts on the first rendered frame after the impact frame, and still lasts `hit_flash_frames`. With the toggle off it starts on the hit tick, as before. In first person: 2 frames of ink, then 2 frames of white on the struck chin. In side view the burst and its word still cover it (hit-05, and the open side-view flash question). Sheets (local): `.worktrees/m2-fix-r2-finisher-flash/captures/fix/s_*.png`.
  - `m2/phase3-review` again (the hit records, `packages-r2a.json`, `fix-r2-finisher-flash.json`).
  - **Head `8f5519f`. 486/486 tests pass with no SCRIPT ERROR or ERROR.** The preset regenerated unchanged (300 values).
- **Ready for the next window:** `.worktrees/m2-review-perf` is detached at `8f5519f` and imported. [reviews/M2-phase3/args-r2-perf.json](reviews/M2-phase3/args-r2-perf.json) holds the perf run's exact args.
- **Resume:**
  1. `Workflow({scriptPath: "<repo>/docs/reviews/M2-phase3/workflow.js", args: <the contents of args-r2-perf.json>})`. This runs the perf review (about 18%) and its skeptics.
  2. The round 2 critic. Run `workflow.js` with `lenses: []` (none to run), `suffix` "-r2" and a `common_note` that lists all the lenses run so far. Its critic prompt then gets an empty coverage list, so tell it in the note to read `review-*.json` and `verify-*.json`. Or do this step as lead work.
  3. The partition of hit-05 and the perf survivors into `packages-r2.json` (keys prefixed `r2-`). Use `workflow-verify-partition.js`'s pattern, or a lead-written file as with `packages-r2a.json`.
  4. `workflow-fix.js` with `packages_file` "packages-r2.json".
  5. Merge, then the final sheets for Game-boy, then D.
- **Waiting on Game-boy** (each has a default; none blocks the work):
  - the combat log: grab-03 and hit-03;
  - the flash's first-person size and the flurry strobe: grab-05 and hit-01;
  - a hit on the player in first person: hit-02;
  - the side-view flash: a minimum size alone won't show it;
  - the hold's look dead band (grab-06);
  - bars over the middle of a body that isn't upright;
  - the new look: gray trousers and dark hair;
  - the FYI on `ragdoll_partial_head_influence`;
  - the 12:40 entry's items.

### 2026-10-24 23:09 CDT: round 2 hit review done (5 of 5 survive, 3 are spec questions); hit-04's fixer running
The 5-hour window is at 74% (resets 02:30 CDT on 10-25); weekly is at 57%. The hit review and its 15 skeptics took the window from 46% to 66% in about 35 minutes.
- **Hit-feel review** (`review-hit.json`, `verify-hit.json` on `m2/phase3-review`, `d38b199`). It used five recordings at `f1e2d0f`: every vfx_bot act, 36 combo_bot acts, and every side-view ragdoll_bot act with and without the effects. Each of the five findings has 3 of 3 confirmations.
  - **To fix:**
    - **hit-04** (medium): no finisher ever shows its white flash. The flash's 2 frames are exactly the impact frame's 2 frames.
    - **hit-05** (low): in side view, the view-share floor grows the heavy word, the guard-break burst and the finisher burst to 2-2.5 times their size. They cover the struck body through the start of its reaction.
  - **Spec questions for Game-boy** (defaults: as now):
    - **hit-01**, which joins grab-05: the flurry strobes a white patch over 14-18% of the first-person view at 8.6 Hz, 7 times in a row, and the photosensitivity toggle doesn't cover it. Options:
      - (a) the impact-frame toggle becomes a general "reduce flashing" switch that also softens the contact flash;
      - (b) cap the flash's on-screen share in first person;
      - (c) soften repeat flashes on the same victim within N frames.
    - **hit-02**: a hit on the player in first person shows no flash. The only on-screen effect is a small white burst at screen centre, like the player's own jab, plus about 3 px of shake and the HP bar. Options:
      - (a) flash the player's first-person arms at a reduced strength;
      - (b) a distinct "taken" burst;
      - (c) a short HUD edge vignette from the hit's side.
    - **hit-03**, which joins grab-03: the always-on combat log hides where every side-view knockdown lands. Round 1's proposal, the log moved to the upper right under the rear-warning corner (with a toggle key), clears both views.
  - **The side-view flash** (the open question): about 30 px across, always under the light burst (64 px at the 4% floor) or the word. A minimum size alone wouldn't show it; it would have to be larger than the burst or start after it pops. With the effects off, it reads on the contact for every ragdoll case.
  - **Verdicts on the 10:55 known items:**
    - (a) a hit on the player reads weakly (hit-02);
    - (b) the side-view flash is under the burst: confirmed;
    - (c) the first finisher's dropped frame doesn't show in Movie Maker captures (a perf-lens job);
    - (d) the light burst is 10.3% of the view width;
    - (e) the bruised look is still subtle in side view;
    - (f) the log covers the side view: confirmed (hit-03);
    - (g) the speed lines repeat exactly in vfx_bot, and vary in combo_bot and in play.
  - **Also noticed** (minor):
    - in side-view piles, a lying body's bar crosses the standing body in front of it (after ragdoll-03);
    - when a jab breaks the hold, the released victim's dark hair rises through the first-person view at about 0.4 m, about 25% of the width for 6 frames (within grab-02's tested bounds);
    - the blood splash slides down a launched body;
    - hits on the player put sparks at screen centre over the attacker's face.
- **Running:** workflow `wf_9d7bfb9c-048`: `workflow-fix.js` with `packages_file: "packages-r2a.json"` (one package, `r2-finisher-flash`: hit-04, written by the lead) and `fixer_cost` 12. The fixer works in `.worktrees/m2-fix-r2-finisher-flash` on branch `m2/phase3-fix-r2-finisher-flash`. Only it fit the 16 points of headroom.
- **Next, in the next window:**
  1. The perf lens: `workflow.js` with `lenses: ["perf"]`, `base` at the merge head, `skip_critic`, `skip_fix`, `suffix` "-r2", and a `common_note` like the hit run's (see the run args in this session, or rewrite them from the 22:33 entry).
  2. The critic (round 2).
  3. The partition of hit-05 plus the perf survivors into `packages-r2.json`, with keys prefixed `r2-`.
  4. `workflow-fix.js` with `packages_file` "packages-r2.json".
  5. Merge, then the final sheets for Game-boy, then D.
- **If cut off:** rerun `workflow-fix.js` with the same args. The loader reuses a `wip:`-only branch.

### 2026-10-24 22:33 CDT: package C round 1 done and merged (484/484); round 2's hit review running
The 5-hour window is at about 47% (resets 02:30 CDT on 10-25); weekly is at 53% (resets Tue 2026-10-27 17:00 CDT). hold-view's finish and ko-respawn-bars ran one after another, at about 22% of the window together.
- **Merged into `m2/hit-feel`** (pushed; head `b22e08e`): `m2/phase3-fix-hold-view` (`acea488`), `m2/phase3-fix-ko-respawn-bars` (`a4c9bee`) and `m2/phase3-review` (`f1e2d0f`, all of C's JSON records). All three merged cleanly, and the preset regenerated unchanged (300 values). **484/484 tests pass with no SCRIPT ERROR or ERROR.** All 17 round 1 findings are fixed.
  - **hold-view** (471/471 in its worktree):
    - code-03: the lens moves on an eased path, and the walking-bob clamp scales with the hold's weight;
    - grab-06: a new tunable `grab_view_target_pitch_deg` 22, so the hold pitch reaches a target total;
    - grab-07: the throw's right arm is out wide, so there's no elbow ball. The ramps still hold through hitstop, so B's design is unchanged;
    - grab-02: a hit breaks the hold into a stagger;
    - code-06: its grab-view half.
    - Sheets (local): `.worktrees/m2-fix-hold-view/captures/fix/a_*.png`.
  - **ko-respawn-bars** (480/480):
    - code-02: the respawn spot checks lying bodies, walls and floor;
    - code-04: a dummy stays a ghost through its blink-in, and magnetism skips it;
    - code-05: `PRESET_FORMAT` 2 migrates an old preset's `dummy_revive_s`;
    - ragdoll-03: bars sit just above the drawn body when it isn't upright;
    - ragdoll-04: KO bars fade before the blink.
    - The pile test now sets up its pile with scripted knockdowns and passes in any order.
    - Sheets (local): `.worktrees/m2-fix-ko-respawn-bars/captures/fix/`.
- **New notes for Game-boy** (each has a default):
  - grab-06's formula leaves a look dead band while holding. Looking between 6° and 22° down, the view stays at 22°, so about 16° of mouse travel gets no response; the bots never show it. A softer mapping is possible. Default: as built.
  - SPEC §5's bar "over its head": a body that isn't upright (lying, flying, held) now has its bar over the middle of its drawn body. Treated as within the spec. Default: as built.
- **Round 2** (the 14:15 entry's step 3) uses `workflow.js`'s new options (`b22e08e`): `base`, `common_note`, `lenses`, `skip_critic`, `suffix`. The reviewer worktrees `m2-review-hit` and `m2-review-perf` are moved to `f1e2d0f` and imported.
  - **Running:** workflow `wf_29d8de46-ea9`, with `lenses: ["hit"]`, `base` `f1e2d0f`, `skip_critic`, `skip_fix`, `suffix` "-r2" and a `common_note`. The note lists round 1's changes and the critic's gap (the flash on a ragdoll in side view). It runs the hit-feel review, then three skeptics per finding, gated. The scribe writes `review-hit.json` and `verify-hit.json` to `m2/phase3-review`.
  - The window fits only one reviewer: the rule's headroom was 37, and a reviewer that's cut off saves nothing.
  - **Next:** the perf lens the same way (`lenses: ["perf"]`). Then the critic, a gap lens for its medium gaps if needed, and the partition into `packages-r2.json` (keys prefixed `r2-`). Then the fixers: `workflow-fix.js` needs a `packages_file` arg first. Then merge, the final sheets, and D.
- **If cut off:** check `m2/phase3-review` for `review-hit.json` and `verify-hit.json`. If the review is missing, rerun the same args. If it's there, pass it in `reviews.hit`, and the verdicts in `verdicts`.

### 2026-10-24 21:35 CDT: account E after its 21:30 reset; hold-view and ko-respawn-bars running, one after another
The 5-hour window is at 0% (resets 02:30 CDT on 10-25); weekly is at 45%. The usage rule's headroom (90 minus the higher window, here weekly) is 45, which fits one fixer. So the run is sequential: `workflow-fix.js` gained `concurrency` (`80c39ea`), and the second fixer's gate runs when the first ends.
- **Running:** workflow `wf_17408a9e-962`: `workflow-fix.js` with `only: ["hold-view", "ko-respawn-bars"]`, `concurrency` 1 and a lead's note:
  - hold-view continues from `06733a3`;
  - ko-respawn-bars also takes over `test_ragdoll.gd`'s pile test and sets up its pile without the chaotic flight.
  - The watcher checks every 10 minutes.
- **If cut off:** rerun the same way (the loader skips a package whose branch has its final commit). Within this session, use `resumeFromRunId: "wf_17408a9e-962"`.
- **Then:** merge both into `m2/hit-feel`, regenerate the preset, run the tests (all 467+ pass, no SCRIPT ERROR), push; then round 2 (the 14:15 entry's step 3).

### 2026-10-24 18:10 CDT: handoff, account E's 5-hour window at 91%
The watcher called the handoff at 91% of the 5-hour window (resets 21:30 CDT); weekly is at about 45% (resets Tue 2026-10-27 17:00 CDT). The hold-view fixer alone took the window from about 62% to 91% in about 40 minutes, more than the 25% estimate. The workflow `wf_5656a5ef-18c` is stopped, and nothing else is running. Every branch is pushed. The worktrees have no uncommitted tracked changes.
- **`hold-view`: cut off with two `wip:` commits**, pushed on `m2/phase3-fix-hold-view` (worktree `.worktrees/m2-fix-hold-view`, off `m2/hit-feel` at `0905690`, which has the two merged packages).
  - `d50348c`, in `player.gd`, `first_person_camera.gd` and `tuning_data.gd`:
    - the hold-view lens moves on an eased path (code-03);
    - the hold pitch has a target total (grab-06);
    - a hit breaks the hold into a stagger (grab-02).
  - `06733a3`, in `placeholder_poses.gd` and `test_grab_view.gd`:
    - the throw strike's right arm is out wide (grab-07);
    - the ease-in is front-loaded;
    - the tests follow the lens (code-06's grab-view half).
  - **Unknown:** whether the full suite passes on it, whether the after-sheets were recorded and judged, and whether `ARCHITECTURE`'s "First-person hold view" and the preset are updated. There's no `fix-hold-view.json`.
- **Decision (Game-boy, 19:21):** stay on this account. The working session waits for the 21:30 CDT reset, with the watcher still running, and then resumes here with the steps below.
- **Resume (next account or after 21:30):**
  1. Run `workflow-fix.js` with `only: ["hold-view", "ko-respawn-bars"]` and a `note`. The loader sees hold-view as `wip`, and its fixer reuses the worktree and goes on from `06733a3`. The note should say:
     - the merge state (as in the 17:25 entry's run);
     - the known pile-test failure;
     - for ko-respawn-bars: also make `test_ragdoll.gd`'s pile test set up its pile without a chaotic flight. launch-from-hold, which owned that file, is done.
  2. Merge both branches into `m2/hit-feel`, regenerate the preset, run the tests (all pass, no SCRIPT ERROR), push.
  3. Round 2, review: the hit-feel and performance lenses on the merged build, plus the critic's medium gaps (the 14:15 entry's step 3). Then round 2's fixes, the final sheets for Game-boy, and D. D also updates README's hook figures (17:25 entry).
- **Waiting on Game-boy:**
  - grab-03 and grab-05 (13:55 entry);
  - the new look (17:25 entry, `side_looks.png`);
  - the FYI on `ragdoll_partial_head_influence`;
  - the 12:40 entry's items.
  - Each has a default.

### 2026-10-24 17:25 CDT: two fix packages merged; hold-view running; ko-respawn-bars left
The 5-hour window is at about 62% (resets about 21:30 CDT); weekly is at 40%. The first fix run (`wf_3e329695-5fc`) took the window from 10% to 58% in 35 minutes: two fixers at about 24% each.
- **Merged into `m2/hit-feel`** (`4683f81`, `4cc2f56`, pushed). Both merged cleanly, and the preset regenerated unchanged (299 values).
  - **`launch-from-hold`** (`999d565`, 461/461 in its worktree). All four findings are fixed:
    - grab-01 and ragdoll-01: a launch out of the hold starts from the drawn pose, with `carry_fade`. The throw now arcs about 0.6 m up and lands about 3 m away. A knee KO stays 0.30 m from the lens and fills at most 39% of the view; before, it was 0.12 m and 47%.
    - ragdoll-02: new tunables `ragdoll_partial_head_influence` 0.45, `ragdoll_partial_arm_influence` 0.45 and `ragdoll_stagger_back_share` 0.5. The hook stagger now rocks back from the side.
    - code-06: its `test_ragdoll.gd` half.
    - A new ragdoll_bot act, "knee KOs the held dummy".
    - Sheets (local): `.worktrees/m2-fix-launch-from-hold/captures/fix/after/`.
  - **`flash-and-looks`** (`50af435`, 463/463). All four findings are fixed:
    - code-01: `flash_at()` clamps the contact onto the nearest hurtbox and rides the drawn bone (new `hurt_point()`).
    - grab-04: the player wears gray trousers (new `HumanoidRig.pants_color`).
    - grab-08: every rig has a dark "Hair" part on the back of its head.
    - ragdoll-05: the stomp's strike foot lands on top of the lying torso.
    - Sheets (local): `.worktrees/m2-fix-flash-and-looks/captures/fix/`.
- **Tests at the merge: 466/467, no SCRIPT ERROR.** `test_ragdoll.gd`'s `test_two_bodies_that_fell_on_each_other_get_up_beside_each_other` fails in the full suite ("the kicked body lies on the other"; the one underneath moves 0.211 m against a 0.2 m limit).
  - The cause is an **old order dependence**. At `c27afaf`, before any fix, it already fails whenever `test_grab_view.gd` or `test_humanoid_rig.gd` runs before `test_ragdoll.gd`. The kick's flight lands differently after other tests have created and freed bodies, probably through Jolt's body order. The new suite order exposed it.
  - **To do:** make the pile test set up its pile without depending on a chaotic flight. Do it in the `ko-respawn-bars` run (pass it in `note`) or as lead work.
  - To reproduce in about 30 s: a GUT config without `dirs`, run with `-gtest=res://tests/test_grab_view.gd,res://tests/test_ragdoll.gd`.
- **For Game-boy to see:** the player's new gray trousers and the dark hair on every head change the side view: `.worktrees/m2-fix-flash-and-looks/captures/fix/side_looks.png`. On dummies with a dark accent colour, the cap and hair read as one dark helmet.
- **FYI for Game-boy** (no spec change): `ragdoll_partial_head_influence` 0.45 halves how much of the simulated head turn shows in a stagger, including the contact twist on a struck head. Raising it toward 0.9 brings back the old head look without touching the spin caps. This sits next to the open "more contortion" question.
- **README note (not edited yet):** the approved stagger departure quotes the hook at about 0.32 m against 0.22 m. It now measures 0.346 m at 0.9 against 0.217 m at 0.6. Update the number in D.
- **Running:** workflow `wf_5656a5ef-18c`, `workflow-fix.js` with `only: ["hold-view"]`, `max_fixers` 1 and a lead's note (the merge state, and the known failure). `workflow-fix.js` gained the `note` arg.
- **Left:** `ko-respawn-bars` (code-02, code-04, code-05, ragdoll-03, ragdoll-04). Both gates found 7 points of headroom while flash-and-looks still ran, so it waits for the next window. Then come the merge, the pile test, and round 2 (the 14:15 entry's step 3).
- **If cut off:** rerun `workflow-fix.js` (no args, or `only` with the keys left). Within this session, use `resumeFromRunId: "wf_5656a5ef-18c"`.

### 2026-10-24 16:45 CDT: account E after its reset; partition done, fix round running
The 5-hour window reset at 16:30 (next reset about 21:30 CDT); weekly is at 30%. This session resumed as Game-boy decided at 14:29. The watcher `usage-watcher-h` still runs, asked to check every 10 minutes during the heavy run.
- **Partition done:** `packages.json` on `m2/phase3-review` (`e7c3255`) holds four packages with all 17 survivors. Where two packages share a hub file, each package's notes say which functions it may touch.

  | Package | Findings | Main files |
  | --- | --- | --- |
  | `launch-from-hold` | grab-01, ragdoll-01, ragdoll-02, code-06 (ragdoll half) | owns `combat_actor.gd`, `ragdoll.gd`, `gen_moves.gd` (throw, hook) |
  | `flash-and-looks` | code-01, grab-04, grab-08, ragdoll-05 | `humanoid_rig.gd` (except `ragdoll_start()`, `carry_fade()`), `weapon.gd`, `placeholder_body.gd`, `placeholder_poses.gd` (except `_throw()`) |
  | `hold-view` | code-03, grab-07, grab-06, grab-02, code-06 (grab-view half) | owns `player.gd` (except `_configure_rig()`, `_find_magnet_target()`), `first_person_camera.gd`, `_throw()` |
  | `ko-respawn-bars` | code-02, code-04, code-05, ragdoll-03, ragdoll-04 | `training_dummy.gd`, `enemy_health_bars.gd`, `tuning.gd` (preset migration) |

- **Running:** workflow `m2-phase3-fix` (run `wf_3e329695-5fc`, [reviews/M2-phase3/workflow-fix.js](reviews/M2-phase3/workflow-fix.js), no args). Fixers run in that order, two at once, each usage-gated (about 25%):
  - each works in `.worktrees/m2-fix-<key>` on branch `m2/phase3-fix-<key>` off `m2/hit-feel`;
  - each commits `wip:` and pushes every 15-20 minutes, and ends with "M2 phase 3: review fixes (<key>: ...)";
  - a scribe commits `fix-<key>.json` to `m2/phase3-review`.
  - A package the gate skips stays for a later run.
- **Things to watch at the merge:**
  - hold-view's grab-07 fix may ease the hold view out during the throw's hitstop, a change to B's design ("still through hitstop"), which its fixer flags;
  - launch-from-hold re-measures the hook's side-view stagger quoted in README's departure, and reports any change rather than editing README;
  - `tuning_data.gd`, `tuning/default.json` and `docs/ARCHITECTURE.md` get additions from several packages (regenerate the preset after merging).
- **If cut off:** rerun `workflow-fix.js` (no args). Its loader skips a package whose branch has the final commit and reuses a `wip:`-only branch. Within this session, use `resumeFromRunId: "wf_3e329695-5fc"`.
- **Then:** merge the four fix branches and `m2/phase3-review` into `m2/hit-feel`, regenerate the preset, run the tests, push. Then round 2 (the 14:15 entry's step 3).

### 2026-10-24 14:25 CDT: handoff, account E's 5-hour window at 89%
The watcher called the handoff at 89% of the 5-hour window (resets 16:30 CDT); weekly is at 28% (resets Tue 2026-10-27 17:00 CDT). The first task took the window from 76% to 89% in about 25 minutes: nine Sonnet skeptics cost about 6 points, and the lead's reading about 4. The workflow `wf_338da5ae-007` is stopped mid-partition, and nothing else is running. Every branch is pushed. The reviewer worktrees have no tracked changes.
- **Done:** grab-06, -07 and -08 are verified. All three survive with 3 of 3 confirmations, with no spec question. They're merged into `verify-grab.json` on `m2/phase3-review` (`5b77fcd`), and its `pending` is now empty.
  - grab-06: the hold pitch adds to the look pitch with no limit. Looking down 25°, the player's own body fills 52-62% of the view at the knee's peak.
  - grab-07: the hold view's ease is advanced per sim tick, so it stands still through the throw's hitstop. The lens stays back and up while the right upper arm swings out, which leaves the elbow as a blue ball mid-view.
  - grab-08: the placeholder head has no hair or back-of-head part.
- **Not done:** the partition. It was stopped before it returned, so there's no `packages.json` yet.
- **Survivors to fix:** 17 findings with no spec question, from code-01 to -06, ragdoll-01 to -05, and grab-01, -02, -04, -06, -07 and -08. The spec questions grab-03 and grab-05 are Game-boy's.
- **Decision (Game-boy, 14:29):** stay on this account. The working session waits for the 16:30 CDT reset, with the watcher `usage-watcher-h` still running, and then resumes here with the steps below.
- **Resume (next account or after the 16:30 reset):**
  1. Run [reviews/M2-phase3/workflow-verify-partition.js](reviews/M2-phase3/workflow-verify-partition.js) inline (`scriptPath`) with `args: {"skip_verify": true}`. Only the usage gate and the partition run (about 4%). A scribe commits `packages.json`.
  2. Then follow steps 1-4 of "C's order from here" in the 14:15 entry below. Start with `workflow-fix.js`, two fixers at once.
- **Waiting on Game-boy:** grab-03 and grab-05 (13:55 entry), plus the 12:40 entry's items. Each has a default.

### 2026-10-24 14:15 CDT: account E back at 74%; first task: verify grab-06 to -08, partition the survivors
The account Game-boy switched to at 14:10 has account E's reset times. It was at 74% of its 5-hour window (resets 16:30 CDT) and 27% weekly (resets Tue 2026-10-27 17:00 CDT). That left 16 points below 90%, less than one reviewer (18). Per the usage rules, this session split off a first task that fits. Its watcher runs: "Beat-em-up: usage watcher", name `usage-watcher-h` (Haiku, low effort, self-paced).
- **Running:** workflow `m2-phase3-c-verify-partition` (run `wf_338da5ae-007`), a copy in [reviews/M2-phase3/workflow-verify-partition.js](reviews/M2-phase3/workflow-verify-partition.js). It does two things, each usage-gated:
  - three Sonnet skeptics each for grab-06, -07 and -08, merged into `verify-grab.json`;
  - a partition agent that groups every survivor without a spec question into at most four fix packages with disjoint files, saved as `packages.json`.
  - A Haiku scribe commits both to `m2/phase3-review`.
- **New for the next window:** [reviews/M2-phase3/workflow-fix.js](reviews/M2-phase3/workflow-fix.js), the fix round. It needs no args. A Haiku loader reads `packages.json` and skips a package whose branch has its final "review fixes" commit; a `wip:`-only branch is reused. Each fixer reads its findings and verdicts from the review files by id, so the lead no longer pastes about 170 KB of JSON as args. Optional args: `only` (package keys) and `max_fixers`. `workflow.js` now has `COST.reviewer` 18 and `perFinding` 2.
- **C's order from here** (the lead's call):
  1. **Round 1, fix:** run `workflow-fix.js` inline (`scriptPath`). Two fixers at once at about 25% each, so a full window covers about three packages.
  2. **Merge** the fix branches and `m2/phase3-review` into `m2/hit-feel`, regenerate the preset (`godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd`), run the tests, push.
  3. **Round 2, review on the merged build,** so it doesn't re-find what round 1 fixed: the hit-feel and performance lenses, plus the critic's medium gaps (the flash on a ragdoll in side view, the player's KO while holding, bodies against a wall or the curb). `workflow.js` can run them. First make fresh detached reviewer worktrees at the merge commit, change `c27afaf` in its `COMMON` and `reviewRules`, and pass `reviews` code, ragdoll and grab as `{"lens": "<lens>", "skipped": true}`.
  4. Round 2's fixes, then the final sheets for Game-boy, then D.
- **If cut off:** on `m2/phase3-review`, an empty `pending` in `verify-grab.json` means grab-06 to -08 are verified, and `packages.json` means the partition is done. Rerun whatever is missing with `workflow-verify-partition.js`. Within this session, use `resumeFromRunId: "wf_338da5ae-007"`.
- **Waiting on Game-boy:** grab-03 and grab-05 (13:55 entry), plus the 12:40 entry's items. Each has a default.

### 2026-10-24 13:55 CDT: handoff, account F's 5-hour window at 90%
The watcher called the handoff at 90% of the 5-hour window (resets 17:39 CDT); weekly is at 28% (resets Wed 2026-10-28 10:59 CDT). **Game-boy switched to a fresh account at 14:10.** This session is renamed "Beat-em-up: account F session (handed off)", which frees the working-session title, and its watcher `usage-watcher-g` is told to end its loop. The new account starts its own watcher. The workflow `wf_f6697464-ea0` is stopped, and nothing else is running. Every branch is pushed. The reviewer worktrees have no tracked changes (only untracked `captures/`).
- **Package C state.** Everything below is committed as JSON on `m2/phase3-review` (`a39ba62`), in `docs/reviews/M2-phase3/`.

  | Lens | Findings | Verified (3 skeptics each) |
  | --- | --- | --- |
  | code | 6 | 6 of 6 survive |
  | ragdoll feel | 5 | 5 of 5 survive |
  | grab feel | 8 | 5 of 5 survive; grab-06, -07 and -08 (low) are unverified |
  | hit feel | not run (usage) | |
  | performance | not run (usage) | |

  `critic.json` holds the completeness critic: 13 gaps. The high ones are the two lenses not run and no verdicts on the 10:55 known items. Medium: the flash on a ragdoll in side view, the player's KO while holding, bodies against a wall or the curb. Its `gap_review_brief` merges hit feel and performance into one reviewer. Run them as the two planned lenses instead. The partition agent was stopped mid-run, so no packages exist yet, and no fixer ran.
- **The surviving findings** (no fix is needed from Game-boy):
  - code-01 (high): the contact flash misses the struck body. A thrown pipe shows none, body impacts a faint one, and a staggering body flashes on the wrong part.
  - code-02: a respawning dummy can blink in inside a body lying on its post.
  - code-03: the hold view bobs the lens 5-7 cm on every grab and release, and pops 3.5 cm on a release while walking.
  - code-04: a dummy blinking in still attracts magnetism and blocks a thrown pipe.
  - code-05: `dummy_revive_s` changed meaning under the same preset key, so older presets give a 5.5 s comeback.
  - code-06: two tests would pass with what they guard broken: the per-part spin caps and the lens rules on an LB release.
  - ragdoll-01: the throw pops the held victim upright in one frame, then it skates away on its feet and trips onto its face.
  - ragdoll-02: the hook stagger at 0.9 flops like a rag in first person but still doesn't read from the side.
  - ragdoll-03: the side-view health bar sits on the head or body when the head isn't on top.
  - ragdoll-04: a KO'd body's empty health bar hangs through its first blink-offs.
  - ragdoll-05: the stomping foot sinks into the lying body.
  - grab-01 (high): a body launched out of the hold, by a knee that KOs it or by the throw, pops into the holder and fills the view.
  - grab-02: a hit that breaks the hold lets the victim stand up through the holder's frozen view.
  - grab-04: in first person the knee is the same navy as the shaded right sleeve, a blue lump.
- **New spec questions for Game-boy:**
  - grab-03, the combat log over the knee contact (the open question). Proposal: a key that toggles the combat log, shown in the help overlay, and the log moved to the upper right below the rear-warning zone, narrower or with fewer lines; optionally faded while holding in first person. Default: as it is until Game-boy answers.
  - grab-05: the knee's localized flash whitens about 16% of the first-person view, three times per hold. Proposal: cap the flash's on-screen size in first person, for example by scaling `hit_flash_radius_m` with the contact's distance from the camera. Default: leave it.
- **On the open contact-push question:** both the code and the ragdoll reviewer found the contact push near frame-for-frame the same as the central kick. Their evidence is the hook A/B in `.worktrees/m2-review-ragdoll/captures/review_ragdoll/ab_hook_*.png` and a probe in which the head reaches 41-47 rad/s either way. The joint limits and pose springs decide the contortion, not the twist. More contortion would need wider joint limits or softer stagger springs. Default: as it is.
- **Sheets for Game-boy** (local): `review_ragdoll/throw_side60.png`, `throw_fp60.png`, `hook_fp60.png`, `bar_overlap_side.png`; `review_grab/p6_knee_ko_fp_f1340-1359.png`, `p5_hit_while_holding_fp.png`; `review_code/pipe_throw_zoom.png`, `grab_release_moment.png`. Each is under `captures/` in its reviewer's worktree.
- **Measured cost (correct the estimates):** the window went from 5% to 90% in about 58 minutes. That was three reviewers, 16 findings verified (48 Sonnet skeptics), the critic and part of the partition. A reviewer costs about **17-20%**, not 13%. Verifying a finding costs about **1.5-2%**. In `workflow.js`, set `COST.reviewer` to 18 before the next run.
- **Resume (next account):**
  1. Load `docs/reviews/M2-phase3/*.json` from `m2/phase3-review`. Run `docs/reviews/M2-phase3/workflow.js` inline (with `COST.reviewer` 18) with `args`:
     - `reviews`: {code, ragdoll, grab: the three `review-<lens>.json` objects};
     - `verdicts`: {each id in the three `verify-<lens>.json` files: its verdict object}.
  2. It then runs, all usage-gated:
     - the hit and performance reviews;
     - verification of their findings and of grab-06 to -08;
     - the critic again, and a gap round (it should cover the critic's medium gaps);
     - the partition and the fixers.
  3. The reviewer worktrees `.worktrees/m2-review-*` must stay; they're at `c27afaf`, imported.
  - A whole window covers about the two reviews, their verification, the critic and the partition. The fixers (about 25% each) likely need the window after that.
  - To fix the 14 survivors first instead (the lead's call), also pass:
    - `reviews.hit` and `reviews.perf` as `{"lens": "<lens>", "skipped": true}`;
    - `no_gap_round: true`.

    The script then goes straight to the critic, the partition and the fixers. Run hit and perf in a later run.
- **Waiting on Game-boy:** grab-03 and grab-05 above, plus the 12:40 entry's items (each has a default).

### 2026-10-24 12:52 CDT: account F took over; package C workflow running
A fresh account's working session took over at 2% of its 5-hour window (resets 17:39 CDT) and 13% weekly (resets Wed 2026-10-28 10:59 CDT). Its watcher runs: "Beat-em-up: usage watcher", name `usage-watcher-g` (Haiku, low effort, self-paced), asked to check every 10 minutes during the heavy run.
- **Running:** workflow `m2-phase3-review-fix` (run `wf_f6697464-ea0`, started from this session). A copy of the script is in the repo: [docs/reviews/M2-phase3/workflow.js](reviews/M2-phase3/workflow.js).
  - **Review:** five lenses (code, ragdoll feel, grab feel, hit feel, performance), two heavy agents at once. Each works in its own detached worktree at `c27afaf`, `.worktrees/m2-review-<lens>` (imported), and records into `captures/review_<lens>/` there.
  - **Verify:** as each review ends, three Sonnet skeptics per finding (reproduce, spec, code). A finding survives with two confirmations. Survivors whose fix changes the spec, or that touch a question open with Game-boy, become spec questions.
  - **Critic:** a completeness critic, then one gap reviewer if it names high-priority gaps.
  - **Fix:** a partition agent groups the survivors into at most four packages with disjoint files. Fixers run two at once. Each makes `.worktrees/m2-fix-<key>` on branch `m2/phase3-fix-<key>` off `m2/hit-feel`, commits `wip:` and pushes, and ends with "M2 phase 3: review fixes (<key>: ...)".
  - **Record:** a Haiku scribe commits each result as JSON to `docs/reviews/M2-phase3/` on branch `m2/phase3-review` (worktree `.worktrees/m2-review-notes`) and pushes it: `review-<lens>.json`, `verify-<lens>.json`, `critic.json`, `packages.json`, `fix-<key>.json`.
  - **Usage gates:** a Haiku gate before every launch. A launch goes ahead only if its estimate fits 90% minus the usage minus what's still in flight: a reviewer 13%, 2.5% per verified finding, the critic and the partition 4% each, a fixer 25%. Skipped work is logged and left for the next account.
- **Expect** the reviews and verification to fill most of this window; the fixers probably start on the next account.
- **If cut off (another account):**
  1. Read `docs/reviews/M2-phase3/*.json` on `m2/phase3-review`.
  2. Run `docs/reviews/M2-phase3/workflow.js` inline as a Workflow with `args`:
     - `reviews`: {lens: that lens's `review-<lens>.json` object};
     - `verdicts`: {finding id: its verdict object from `verify-<lens>.json`};
     - `packages`: `packages.json`'s `packages`;
     - `done_packages`: the keys whose fix branch has its final "review fixes" commit.
  3. Finished work is skipped, and only the rest runs. A fixer whose branch has only `wip:` commits reuses the worktree and goes on from there. The reviewer worktrees must stay, since skeptics read them.
  - Within this session, resume with `resumeFromRunId: "wf_f6697464-ea0"`.
- **Waiting on Game-boy:** unchanged from the 12:40 entry. Each item has a default, and none blocks C.

### 2026-10-24 12:40 CDT: new usage rule, work up to the 90% handoff
Game-boy finds stopping launches at 65-70% too conservative. From now on, work runs up to the watcher's 90% handoff, and each launch is sized to the headroom left below 90%. When a new phase or milestone doesn't fit, split off a first task that does, run it, and hand off at 90%. The rules are under "Usage rules for the working session"; the takeover prompt, CLAUDE.md and the phase 3 plan match. Nothing else changed since the 12:40 handoff entry below.

### 2026-10-24 12:40 CDT: handoff to a fresh account for package C (Game-boy's call)
Account E is at 70% of its 5-hour window (resets 16:30 CDT) and 26% weekly (resets Tue 2026-10-27 17:00 CDT), past the 65% launch line. Game-boy chose to switch accounts now rather than wait for the reset. This session is renamed "Beat-em-up: account E session (handed off)", which frees the working-session title. Its watcher `usage-watcher-f` is told to end its loop.
- **State:** `m2/hit-feel` @ the commit after `c9ec777` (this entry) has phases 1-2, the flash, and phase 3's A and B merged. **457/457 tests pass with no SCRIPT ERROR or ERROR.** **No agents or workflows are running.** Every branch is pushed. The worktrees are clean apart from untracked `captures/`. `m2/ragdoll-tune` and `m2/grab-view` are merged; their worktrees hold the A/B, KO and grab sheets (local only).
- **Next: package C as a Workflow.** Follow [M2-phase3-plan.md](milestones/M2-phase3-plan.md), "C", step 2: reviewer worktrees, five review lenses, three skeptics per finding, fixers in worktrees with disjoint files, a completeness critic, and usage gates. Then D: check ARCHITECTURE's VFX, Audio, Ragdoll, Hit flash and hold-view sections against the code, add README's Milestone 2 status and the test count, then the M2 PR (never merged without Game-boy's sign-off). D's README controls, the three departures and ARCHITECTURE's title are done.
- **Usage this account (E):** A and B, run together, took the window from 1% to 68% in about 50 minutes: A about 417k tokens, B about 464k. Plan on about 30-35% of a 5-hour window per builder of that size.
- **Waiting on Game-boy** (each has a default; none blocks C):
  - A: more contortion on the contact push? It would mean wider joint limits or softer stagger pose springs. Default: as it is.
  - B: is the lens pull-back while holding acceptable, and is the bend deep enough? Default: as it is.
  - The combat log sits over the knee contact. Default: C's review proposes a fix.
  - The flash's minimum on-screen size in side view. Default: leave it.
  - A listen to WP3's audio.

### 2026-10-24 12:25 CDT: A and B merged (457/457); C waits for usage
- **A done:** `m2/ragdoll-tune` @ `7010250` (448/448 in its worktree, re-run by the lead). Tunables:
  - `ragdoll_partial_influence` 0.6 -> 0.9 (`ragdoll_partial_impulse` stays 7.0: the hook and guard-break kicks already reach `ragdoll_max_kick` 14);
  - "Kick at the contact point": `ragdoll_kick_at_contact` on, `ragdoll_contact_lever_m` 0.15, `ragdoll_contact_twist` 1.0, `ragdoll_contact_chain` 2, spin caps head 14, trunk 8, limb 14 rad/s;
  - "KO and blink-off": `ko_linger_s` 1.5, `ko_blink_s` 1.0, `ko_blink_start_hz` 4, `ko_blink_end_hz` 12, `ko_blink_in_s` 0.5, `ko_blink_in_hz` 8; `dummy_revive_s` 2.5 -> 1.0, counted from the blink-off (4.0 s from KO to back).
  - New: `CombatEvents.vanished`, `HumanoidRig.set_shown()`, `tests/test_ko_blink.gd`; bot switches `--central-kick` and `--set=<tunable>=<value>`.
  - Departures: a dummy whose post is occupied comes back at the nearest free spot beside it; it can't be hit or grabbed during its blink-in.
- **The lead's judgement of A's sheets** (local, `.worktrees/m2-ragdoll2/captures/ab_contact/`, `ab_stagger/`, `ko/`): the contact push is stable (no tearing, spin or jitter; 60 hits in a row stay in the caps) but looks almost the same as the central kick, since the joint limits and pose springs already hold the head and neck at their limits. More contortion would need wider joint limits or softer stagger pose springs. Staggers at 0.9 bend a little further from the side; the hook pushes along the side camera's depth axis. The KO cycle reads well.
- **A's known items:** in side view the enemy health bar sits on the head when a stagger bends it toward the camera; the central kick alone already spins the neck and head at the 40 rad/s cap in staggers; blood splats stay on the floor after a body vanishes.
- **Merged:** `2543cc6` (A) and `f98bb21` (B) into `m2/hit-feel`, no conflicts. The preset regenerated unchanged (296 values). **457/457 tests pass with no SCRIPT ERROR or ERROR.** Pushed. README has the three approved departures (heavy knockdowns full ragdoll, staggers at 0.9, KO blink-off); the central kick isn't kept, so it has no entry.
- **Usage:** 68% of the 5-hour window at 12:22 (resets 16:30 CDT), 26% weekly. Past the 65% launch line, so package C's workflow waits for the reset or a fresh account (Game-boy's call). The watcher checks every 10 minutes.
- **Waiting on Game-boy:** A's sheets (more contortion, or as it is?), B's questions (the lens pull-back, the bend's depth), the combat log over the knee contact, the flash's minimum size in side view, WP3's audio, and when to run C.

### 2026-10-24 11:34 CDT: account E took over; phase 3 packages A and B running
A fresh account's working session took over at 1% of its 5-hour window (resets 16:29 CDT) and 15% weekly (resets Tue 2026-10-27 16:59 CDT). Its watcher runs: "Beat-em-up: usage watcher", name `usage-watcher-f` (Haiku, low effort, self-paced).
- **Running:** two background agents (Agent tool, started from this session), per [M2-phase3-plan.md](milestones/M2-phase3-plan.md):
  - **A, ragdoll:** `.worktrees/m2-ragdoll2`, branch `m2/ragdoll-tune` (off `f43ab9a`, imported, pushed). Contact push behind `ragdoll_kick_at_contact` (default on) with spin caps, A/B sheets central vs contact in `captures/ab_contact/`; KO blink-off (`ko_linger_s`, `ko_blink_s`, blink rates), dummies respawn at home after `dummy_revive_s` with a blink-in, sheets in `captures/ko/`; stronger staggers with A/B sheets in `captures/ab_stagger/`. Ends with a commit "M2 phase 3: ragdoll contact push, KO blink-off, stronger staggers (...)".
  - **B, grab:** `.worktrees/m2-grab`, branch `m2/grab-view` (off `f43ab9a`, imported, pushed). `grab_view_pitch_deg` eased in and out, the waist bend in `hold()` and the knee, before/after sheets in `captures/grab/`. Ends with a commit "M2 phase 3: grab view and waist bend (...)".
  - Both commit `wip:` every 15-20 minutes and push. Both regenerate `tuning/default.json` on their branch; expect a conflict there and in `tuning_data.gd` (different groups) at the merge, and regenerate the preset after it.
- **If cut off:** check each branch for its final commit. Without one, rerun that package from its newest `wip:` commit with the brief in the plan (package A or B).
- **Then:** show Game-boy A's contact-vs-central and stagger sheets, merge A and B into `m2/hit-feel`, and go on with package C.
- **Package C runs as a Workflow (Game-boy turned ultracode on at 11:38).** Plan:
  - per-reviewer worktrees detached at the merge commit (the Workflow tool's `isolation: 'worktree'` fails here);
  - review lenses: the phase 3 code (mechanics), ragdoll feel, grab feel, hit feel across all tiers and both views (including HANDOFF 10:55's known items), and performance;
  - three skeptics per finding, then fixers in their own worktrees with disjoint files;
  - a completeness critic at the end;
  - a Haiku usage gate before each launch: nothing new at 65%, and at most two heavy agents at once.
- **B done (12:25):** `m2/grab-view` @ `329b67f`, 445/445 tests in its worktree (the lead re-ran them; no SCRIPT ERROR or ERROR). Tunables in "Grab and weapons" > "Hold view": `grab_view_pitch_deg` 16, `grab_view_back_m` 0.24, `grab_view_rise_m` 0.10, `grab_view_in_s` 0.2, `grab_view_out_s` 0.45; knee `camera_pitch_deg` -12, `camera_drop_m` 0.05. Departures from the plan: the lens moves back and up while holding (the bend put the eyes over the victim: a wall of shirt), the knee rises a little to the right (the victim's head hid it), the throw ends in the stance (a forearm came within 0.28 m of the lens), no walking-bob clamp while holding, the victim stands 6 cm closer. Sheets (local): `.worktrees/m2-grab/captures/grab/compare_*.png`. Open: the combat log (SPEC's debug overlay, always on) sits over the knee contact; the player's blue sleeves match the knee's blue; the head reads as a skin dome from behind.
- **Done meanwhile on `m2/hit-feel`:** `ac58377` (speed lines seeded, F1 help label, flash test comment) and `dbf0dcc` (README F1/F4 controls, ARCHITECTURE title). 438/438 tests.

### 2026-10-24 11:05 CDT: Game-boy answered the ragdoll questions; phase 3 plan written
Account D, already handed off, wrote [docs/milestones/M2-phase3-plan.md](milestones/M2-phase3-plan.md) from Game-boy's answers (see the Decisions log) and his new grab fix. The takeover prompt's "Next steps" now point to that plan. Nothing else changed: `m2/hit-feel` code is still at `33fcc98`, 437/437 tests pass, and nothing is running. Only the flash's side-view question and WP3's audio are still open with Game-boy.

### 2026-10-24 10:55 CDT: handoff to a fresh account for phase 3 (account D's weekly at 66%)
Game-boy chose to hand phase 3 to a fresh account once the flash merged. Account D is at 59% of its 5-hour window (resets 13:40 CDT) and **66% weekly** (resets Tue 2026-10-27 12:00 CDT), past the 65% launch line. This session is renamed "Beat-em-up: account D session (handed off)", which frees the working-session title. Its watcher `usage-watcher-e` is told to end its loop. **No agents or workflows are running.** Every branch is pushed, and the worktrees are clean apart from untracked `captures/`.
- **State:** `m2/hit-feel` @ `33fcc98` has phases 1 and 2 plus the localized flash. **437/437 tests pass with no SCRIPT ERROR or ERROR.** The preset has 278 values.
  - WP4: `398a2ad` merged `m2/ragdoll` @ `4181f53` (see the 10:45 entry).
  - Flash: `33fcc98` merged `m2/hit-flash` @ `dfc56e8`:
    - `game/fx/hit_flash.gdshader` is a per-rig overlay, `next_pass` only while flashing, and warmed up at load;
    - `HumanoidRig.flash_at()` and `follow_flash()`; `set_flash()` stays whole-body for the cyan parry flash;
    - a "Hit flash" subgroup in "Hit feel": `hit_flash_radius_m` 0.25, `hit_flash_strength` 1.0, `hit_flash_core` 0.5, and `hit_flash_frames`, which moved there;
    - it lasts exactly `hit_flash_frames` rendered frames: before, the player's own hits showed one, because of the tick order;
    - first-person white on a jab at 1 m fell from 27.5% to 3.8%; a 4 m radius gives the old whole-body look;
    - sheets (local) in `.worktrees/m2-flash/captures/flash/`.
- **Known items for phase 3** (judge from captures; fix or ask Game-boy):
  - Flash: in side view the 0.25 m flash hides under the comic burst (the burst has a minimum view share). A minimum on-screen size for the flash would be new design: ask Game-boy.
  - Flash: when the player is hit, the contact is behind the lens, so the flash no longer shows in first person; before, the player's arms flashed white. Judge whether a hit on the player still reads (shake, HUD).
  - Flash: `tests/test_vfx.gd`, `test_hit_flash_still_covers_the_damage_look`, has a doc comment that still says emission.
  - WP4 leftovers:
    - joint-limit transients on impact (probes only);
    - staggers subtle from the side (influence is at the spec's 0.6);
    - lying poses close to M1's;
    - six ragdolls cost about 1.2-1.5 ms a frame.
  - WP2 leftovers:
    - the first finisher of a run drops about one frame;
    - light bursts are about 10% of the view at jab range;
    - the bruised look is subtle in side view;
    - the combat log covers the side view in combo_bot captures.
  - The speed lines use an unseeded random generator, so captures differ after a finisher.
  - WP1 notes: the F1/F4 overlay takes all keys while open, and the help overlay still labels F1 "Tuning panel (Milestone 2)".
  - The flash and the ragdoll have not been recorded together yet.
- **Resume:** start from the takeover prompt below. Its "Next steps" are current.
- **Waiting on Game-boy:** the four open questions in the takeover prompt, and a listen to WP3's audio.
- **Usage this account (D):**
  - WP4's builder cost about 52% of a window; its two reviewers about 22% each.
  - The WP4 fix pass cost about 40% and was cut off; its finish took about a third of a window, run alongside the flash agent.
  - Plan on about a whole 5-hour window for phase 3's review and fix.

### 2026-10-24 10:45 CDT: WP4 merged into `m2/hit-feel` (429/429); flash agent running; weekly at 65%
- **WP4 done:** `m2/ragdoll` @ `4181f53`, "M2 WP4: review fixes (...)".
  - Of the 18 findings, 15 are fixed and 3 partly (mech-F4 joint-limit transients on impact, feel-F3 staggers still subtle from the side, feel-F4 lying poses close to M1's). mech-F13 is a spec question.
  - The verdicts are in [docs/reviews/M2-WP4-fix-results.json](reviews/M2-WP4-fix-results.json). The A/B after-sheets (local) are in `.worktrees/m2-ragdoll/captures/review_after/sheets_after/`.
  - The lead judged the haymaker, face-down and hook A/B sheets, and they read as reported.
  - The lead accepts two changes:
    - `get_head_top_position()` now follows the visible head; only the health bars and debug draw read it;
    - a pile's top body gets up about 0.8 m aside (brief decision 3).
- **Merged:** `398a2ad`. The preset regenerated unchanged (275 values). **429/429 tests pass with no SCRIPT ERROR or ERROR.** Pushed.
- **Running:** the localized-flash agent in `.worktrees/m2-flash` (see the 10:38 entry). Merge `m2/hit-flash` next; its `tuning_data.gd`, `combat_actor.gd` and `humanoid_rig.gd` edits sit beside WP4's.
- **Usage:** 53% of the 5-hour window (resets 13:40 CDT). **Weekly is at 65%** (resets Tue 2026-10-27 12:00 CDT), the "launch nothing new" line. This account launches no new heavy agent; that is Game-boy's call.
- **Waiting on Game-boy:**
  - mech-F13: approve the capped central kick on the struck part instead of SPEC §6's "impulse at the contact point", with a README entry;
  - the builder's three questions (KO bodies sleep until the arena clears; KO bodies take no hits; heavy-tier knockdowns get the full ragdoll);
  - whether staggers may go above the spec's 0.6 influence to read better from the side.
  - All are left as they are until he answers.

### 2026-10-24 10:38 CDT: two agents running (WP4 fixes, localized hit flash)
Usage is at 14% of the 5-hour window (resets 13:40 CDT) and 58% weekly.
- **Running (agent 1):** the WP4 verify-and-fix finish in `.worktrees/m2-ragdoll` (see the 10:08 entry).
- **Running (agent 2):** the localized white hit flash (Game-boy approved it at 10:40) in a new worktree `.worktrees/m2-flash`, branch `m2/hit-flash` (off `m2/hit-feel` @ `d99eecf`, imported and pushed). It builds:
  - a per-rig overlay ShaderMaterial, used as `next_pass` only while flashing; the parry flash stays whole-body;
  - `hit_flash_radius_m` (0.25), `hit_flash_strength` (1.0) and `hit_flash_core` (0.5) in "Hit feel";
  - a fix so the flash shows for `hit_flash_frames` rendered frames (the captures show one);
  - `tests/test_hit_flash.gd`, and captures in `captures/flash/`.
  - It ends with a commit "M2 phase 3: localized white hit flash (...)".
- **Merge plan:** merge `m2/ragdoll` and `m2/hit-flash` into `m2/hit-feel`. Both touch `combat_actor.gd`, `humanoid_rig.gd` and `tuning_data.gd` in different places. Then regenerate `tuning/default.json` (`godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd`), run the tests and push.
- **If cut off:** check each branch for its final commit. Without one, rerun that agent's step from its newest `wip:` commit.

### 2026-10-24 10:08 CDT: account D resumed after its reset; WP4 verify-and-fix finishing
Game-boy stayed on account D. The 5-hour window is at 4% (resets 13:40 CDT), and weekly is at 56% (resets Tue 2026-10-27 12:00 CDT). Extra usage now shows as enabled ($0 spent). The watcher `usage-watcher-e` is still running.
- **Running:** one background agent, started from this session, finishes the WP4 verify-and-fix pass in `.worktrees/m2-ragdoll`, as in the 23:50 entry's resume step 1. It will:
  - give a verdict for each of the 18 findings;
  - finish or revert `5be9500`'s half-done edits;
  - re-record into `captures/review_after/`;
  - write `docs/reviews/M2-WP4-fix-results.json`;
  - commit "M2 WP4: review fixes (...)" and push, with `wip:` commits every 15-20 minutes.
- **If cut off:** check `m2/ragdoll` for the "review fixes" commit. Without one, rerun the same step from the newest `wip:` commit.
- **Still open with Game-boy:** the builder's three ragdoll spec questions. The agent leaves all three ragdoll behaviours as they are. (The white hit flash was decided at 10:40: localize it; see the Decisions log.)

### 2026-10-23 23:50 CDT: handoff, account D's 5-hour window at 84%
The watcher warned at 84% of the 5-hour window (resets 03:30 CDT on 10-24), climbing about 1.2 points a minute. Weekly is at about 47%. The workflow `wf_6868f11f-7bd` is stopped, and nothing else is running. Every branch is committed and pushed, and the worktrees are clean apart from the untracked `captures/` folders.
- **WP4 state** (`m2/ragdoll`, `.worktrees/m2-ragdoll`):
  - **Build:** done at `96defb9` (see the 21:55 entry).
  - **Reviews:** done. 18 findings (13 mechanics, 5 feel) are committed in [docs/reviews/M2-WP4-review-findings.json](reviews/M2-WP4-review-findings.json) on `m2/ragdoll` (`f51cc42`).
    - High: mechanics F1 (the get-up fade drops the relocation, a pop), F2 (a player standing over the body moves the get-up spot about 0.7 m after a stomp) and F3 (face-down landings lie twisted, up to 1.42 m from the hurtboxes). Feel F1 (a parried jab's forearm swings into the lens) and F2 (finisher launches stay upright through the hitstop exit and the slow-mo).
    - Mechanics F13 is a spec question (the README departure for heavy-tier knockdowns).
  - **Verify and fix: cut off mid-pass.**
    - Its `wip:` commits are `47758b4`, `a599de1` and `73fb051`, plus the lead's `5be9500`, which commits the agent's uncommitted `combat_actor.gd`, `tuning_data.gd` and `default.json` edits. Those edits may be half done.
    - Going by the commit messages, the pass touched almost every finding:
      - the get-up fade, no ring jump, re-anchored and limit-clamped pose springs, a whole-body turn, landing aim, influence rise, kick hold and rest from real motion;
      - new tests (kick held, forced relocation, stomp get-up, face-down, joint limits, re-stagger, calm sleep, idle bodies, re-entered tree, parry, launch snap, CCD), and the arms tracking a stagger.
    - It recorded **no verdicts**, no after-captures and no final commit.
    - **`5be9500` passes 425/425 tests**, with no SCRIPT ERROR.
- **Resume steps:**
  1. Run **one** agent in `.worktrees/m2-ragdoll` (absolute path; `cd` there for every command). Give it each of the 18 findings in `docs/reviews/M2-WP4-review-findings.json`, and have it:
     - check each against `96defb9..5be9500` and give a verdict (confirmed, partial or refuted; fixed or not);
     - finish any gaps;
     - re-record `tests/bot/ragdoll_bot.tscn` in both views into `captures/review_after/` and judge the frames;
     - run `tools/run_tests.sh`;
     - write the verdicts to `docs/reviews/M2-WP4-fix-results.json`;
     - commit "M2 WP4: review fixes (...)" and push.
  2. Merge `m2/ragdoll` into `m2/hit-feel`, run the tests (all pass, no SCRIPT ERROR), push and update this file.
  3. Phase 3 (see the takeover prompt).
- **Usage this window:** the two reviewers together took the window from 0% to 44%, about 22% each. The verify-and-fix agent then took it from 44% to 84% in about 35 minutes and wasn't finished. Plan on a full window for a WP4-sized build, and about half a window for its fix pass.
- **Waiting on Game-boy:** the white hit flash (localize it, or keep it as the spec says), and the builder's three ragdoll spec questions (in the 21:55 entry).

### 2026-10-23 21:55 CDT: WP4 built; reviews wait for the 22:30 reset
- **Builder done:** `m2/ragdoll` @ `96defb9`, "M2 WP4: partial and full ragdoll". **412/412 tests pass** with no SCRIPT ERROR, and the branch is pushed.
  - Core: `game/actors/ragdoll.gd`, a SkeletonModifier3D after the PhysicalBoneSimulator3D.
  - Layer 8 "ragdoll", a "Ragdoll" tuning group (34 values in 6 subgroups), and `tuning/default.json` regenerated (265 values).
  - Tests in `tests/test_ragdoll.gd` (12), and `tests/bot/ragdoll_bot.tscn` with 10 acts × 2 views.
  - Captures (local) in `.worktrees/m2-ragdoll/captures/ragdoll/`: `ragdoll_acts.avi` and 20 sheets in `sheets/`.
- **Builder's departures from the brief:**
  - joints are made on the physics server;
  - time scaling uses velocity changes, not a custom integrator;
  - per-body pose springs, besides the hips spring;
  - central kicks on the struck body part, chosen by hurtbox region;
  - no gravity on the partial ragdoll;
  - ragdolls collide with each other.
- **Builder's known issues:**
  - the visible body is up to 0.96 m from the hurtboxes for about 0.05 s just after a finisher's hitstop, 0.13 m lying;
  - the get-up position now depends on Jolt;
  - lying bodies sleep, so the downed breathing stops.
- **Stopped:** the workflow `wf_6868f11f-7bd` ended at the review gate at 68% of the 5-hour window. The builder alone took the window from 16% to 68%, about 52% (twice the estimate). Weekly is at 40%.
- **Resume (this session, after 22:30 CDT):** `Workflow({scriptPath: "<session>/workflows/scripts/m2-wp4-ragdoll-wf_6868f11f-7bd.js", resumeFromRunId: "wf_6868f11f-7bd", args: {review_gate_attempt: 2}})`. The builder comes back from cache; the reviewers and then the verify-and-fix agent run live.
- **Resume (another account):** run the two reviews (mechanics; feel from re-recorded captures) and then the verify-and-fix pass on `m2/ragdoll`, as in the 20:38 entry.
- **Waiting on Game-boy:**
  - phase 3's white hit flash (localize it, or keep it as the spec says);
  - the builder's three spec questions:
    - KO bodies sleep where they lie until the arena clears (Milestone 3);
    - KO bodies take no hits;
    - heavy-tier knockdowns get the full ragdoll, because the reaction decides, not the tier.

### 2026-10-23 20:38 CDT: account D took over; WP4 workflow running
A fresh account's working session took over at 15% of its 5-hour window (resets 22:30 CDT) and 31% weekly (resets Tue 2026-10-27 17:00 CDT). Its watcher runs: "Beat-em-up: usage watcher", name `usage-watcher-e` (Haiku, low effort, self-paced).
- **Running:** workflow `m2-wp4-ragdoll` (run `wf_6868f11f-7bd`, started from this session), all in `.worktrees/m2-ragdoll`:
  1. A usage gate, then **one builder**. It implements M2-WP4-brief.md, writes `tests/test_ragdoll.gd` and `tests/bot/ragdoll_bot.*`, records into `captures/ragdoll/` and ends with a commit "M2 WP4: partial and full ragdoll".
  2. A usage gate, then **two reviewers at once**, both review-only: mechanics (scratch in `captures/review_mech/`) and feel from re-recorded captures (`captures/review_feel/`).
  3. A usage gate, then **one verify-and-fix agent**. Its first step writes the reviewers' findings to `docs/reviews/M2-WP4-review-findings.json` and commits them. It then verifies each finding, fixes those that hold, records `captures/review_after/` and ends with a commit "M2 WP4: review fixes (...)".
  - Every gate stops new launches at 65% of either window. The verify-and-fix gate will probably land before the 22:30 reset. If it stops there, resume after the reset in this session: `Workflow({scriptPath, resumeFromRunId: "wf_6868f11f-7bd", args: {fix_gate_attempt: 2}})`. The script is under this session's `workflows/scripts/`. The finished stages come back from cache.
- **If cut off (another account):**
  - check `m2/ragdoll` for its "M2 WP4" commits;
  - with no "partial and full ragdoll" commit, rerun the builder from its last `wip:` commit, using the brief;
  - with no findings file, run the two reviews;
  - with no "review fixes" commit, run the verify-and-fix pass on `docs/reviews/M2-WP4-review-findings.json`.
- **Then:** merge `m2/ragdoll` into `m2/hit-feel`, run `tools/run_tests.sh` (all pass, no SCRIPT ERROR), push, then phase 3 (see the takeover prompt's "Next steps").

### 2026-10-23 20:33 CDT: Game-boy switches to a fresh account now
This account is at 86% of its 5-hour window, which resets at 21:39 CDT; weekly is at 15%. Game-boy chose a fresh account over waiting for that reset. This session stopped its 21:41 WP4 launch timer, so nothing launches here. It told its watcher (`usage-watcher-d`) to end its loop and renamed itself "Beat-em-up: 20:20 takeover session (handed off)", which frees the working-session title.
- **State:** everything is committed and pushed, and the worktrees are clean. No workflows or agents are running.
  - `m2/hit-feel` @ `584be65` (this entry follows): phase 1 merged, 400/400 tests.
  - `m2/ragdoll` @ `584be65`, `.worktrees/m2-ragdoll`: up to date and imported, with no WP4 work yet.
- **Decisions since the last entry:** Game-boy kept all eight phase 1 spec defaults (see "Decisions log"). README now has "Where M2 departs from the spec" with the two WP1 items.
- **Resume steps:**
  1. Start from the takeover prompt under "Takeover prompt". Its "Next steps" are current.
  2. Run WP4 as a workflow in `.worktrees/m2-ragdoll`: one builder, then two reviewers at once, then one verify-and-fix agent, with a usage gate before each launch. Tell each agent the absolute worktree path, since the Workflow tool's `isolation: 'worktree'` fails here.

### 2026-10-23 20:25 CDT: phase 1 merged into `m2/hit-feel`; spec questions with Game-boy
A new working session took over at 79% of its 5-hour window (resets 21:39 CDT) and 14% weekly (resets Tue 2026-10-27 17:00 CDT). These are account B's reset times. Its watcher runs: "Beat-em-up: usage watcher", name `usage-watcher-d`. It launched no agents (over the 65% gate) and did the rest itself.
- **WP1 done:** the lead checked all 17 findings against `a9f2aca` and `77455ed`; every one is fixed. Marker commit `99ff984`, "M2 WP1: review fixes (...)", pushed. Per-finding verdicts are in [docs/reviews/M2-phase1-fix-results.json](reviews/M2-phase1-fix-results.json) under `WP1-tuning`. The panel capture is `.worktrees/m2-tuning/captures/panel_after.avi` (local): pad focus walks a subgrouped page.
- **WP2 judged from its after-sheets** (and shown to Game-boy):
  - The speed lines are now crisp, tapered ink with a clear middle, in both views.
  - The three tier sizes read distinctly. The jab step has no lunge lines and the flying kick does.
  - Words stay with their dummies.
  - Damage looks read at 1 m in first person. In the full side view the bruised step is near invisible and bloodied faint, and the bloodied splats tile evenly over the shirt, like a print.
  - Phase 3 item, out of WP2's scope: M1's white hit flash fills about 40% of the first-person view on a jab at contact, and a wide band on knees.
- **Merged** `m2/tuning`, `m2/vfx` and `m2/audio` into `m2/hit-feel` (`361b4ec`, `4fbfef6`, `a3579fd`), keeping all four presentation lines and both ASSETS.md sections. The default preset is regenerated (231 values, `8a00724`). **400/400 tests pass with no SCRIPT ERROR.** Pushed.
- **Answered at 20:30 CDT: keep all eight defaults** (see "Decisions log"). Before that, the session was waiting on Game-boy for answers to the 8 spec questions below (WP3 ×4, WP2 ×2, and WP1 ×2, which are already implemented with the reviewers' defaults). Nothing acts on them until he answers.
  - WP1, debug time scale: 0.25x also stretches hitstop and the slow-mo timers, while camera punch and shake stay real time. Default: keep.
  - WP1, cheats out of presets: Save, Load and Reset skip the Debug group. Default: keep, and note it in README's Milestone 2 departures.
- **Next:** WP4 starts only after the 21:39 CDT reset (a heavy agent costs about 25%), per [docs/milestones/M2-WP4-brief.md](milestones/M2-WP4-brief.md), in a new worktree off `m2/hit-feel`.
- **WP4 setup (20:26 CDT):** worktree `.worktrees/m2-ragdoll` on branch `m2/ragdoll` (from `8f0b5f7`, imported, pushed). WP4 is to run as a workflow:
  - one builder;
  - then two reviewers at once, one on mechanics and one on feel from captures;
  - then one agent that verifies each finding adversarially and fixes the ones that hold.
  - A Haiku usage gate runs before each launch.
  - If cut off: check `m2/ragdoll` for its "M2 WP4" commits and resume from the last finished stage.

### 2026-10-23 20:20 CDT: Game-boy switches to a fresh account
Account C stopped work at 76% of its 5-hour window and 13% weekly. Both of its watchers are told to stop and are being archived. This session is renamed "Beat-em-up: account C session (handed off)", which frees the working-session title.
- **The next account:** start from the takeover prompt under "Takeover prompt". Its "Next steps" are current.
- **State:** everything is committed and pushed, and the worktrees are clean. The resume steps are those of the 19:15 entry.

### 2026-10-23 20:13 CDT: watcher relaxed; takeover prompt drafted
Account C sits idle at 74% of its 5-hour window (resets 23:00 CDT) and 13% weekly, after the 19:15 handoff below.
- **New watcher cadence**, set by Game-boy: every 20 minutes below 70%, every 10 minutes up to 85%, every 5 minutes above that. Halt and hand off at 90%. "Usage watcher" has the full rules and the prompt.
- **Takeover prompt:** the prompt for the next account is under "Takeover prompt".
- **Resume steps** are unchanged from the 19:15 entry.

### 2026-10-23 19:15 CDT: handoff, account C's 5-hour window at 71%
The watcher warned at 71% of account C's 5-hour window, which resets at 23:00 CDT; C's weekly is at about 10%. The workflow `m2-phase1-verify-fix` (run `wf_3d9df549-bac`) is stopped. Every branch is committed and pushed, and the worktrees are clean. The agents' full results are in [docs/reviews/M2-phase1-fix-results.json](reviews/M2-phase1-fix-results.json): verdicts, test counts, capture paths, spec questions and remaining items.

| WP | Branch / worktree | State |
| --- | --- | --- |
| WP2 VFX | `m2/vfx` @ `0d9a8a3`, `.worktrees/m2-vfx` | **Done.** "M2 WP2: review fixes". 16 findings (the 13 reviewed plus the lead's 3): 14 confirmed and 2 partial, all fixed. 341/341 tests pass with no errors. Fixes: speed lines are now crisp tapered ink (FX textures are held and preloaded), lunge lines need a ≥1.0 m lunge (`vfx_lunge_lines_min_m`), damage looks read at 1 m (bruised skin plus scuffed clothes, new `damage_scuffed.png`), VFX run after the cameras, tier size ratios, word and burst clamp rules, no flicker without the photosensitivity toggle, VFX subgroups. After-sheets (local, untracked) are in `.worktrees/m2-vfx/captures/review/after_*.png`. **Not yet judged by the lead.** |
| WP3 audio | `m2/audio` @ `73f0a39`, `.worktrees/m2-audio` | **Done.** "M2 WP3: review fixes". Its own review found 27 items: 13 confirmed, 5 partial and 9 refuted; 18 fixed. 329/329 tests pass. Fixes: front-loaded whooshes, tier loudness order, blocks louder, one swing through several bodies layers once, wind-up cut on interrupt, hits on the player placed from the attacker's side, limiter pre-gain, oldest-voice stealing (32 voices), rumble merge and pause handling. Spectrograms are in `.worktrees/m2-audio/captures/review/`. |
| WP1 tuning | `m2/tuning` @ `77455ed`, `.worktrees/m2-tuning` | **Cut off near the end.** The agent reproduced all 17 findings and implemented the fixes: gamepad A/B and D-pad focus links, free fly held while the panel is open, preset range and enum checks and backups, cheats left out of presets, "default" export and shadowing, spawn clear of walls, the debug scale stretching hitstop (TimeController), subgroup headings, cheaper change markers, and tests in a scratch preset folder. The `wip:` commit passes **324/324 tests with no SCRIPT ERROR**. It was recording its panel capture. |

**Resume steps:**
1. **Finish WP1** with one agent in `.worktrees/m2-tuning`:
   - check each of the 17 findings in `docs/reviews/M2-phase1-review-findings.json` (keys `review:wp1:*`) against the `wip:` commits `a9f2aca` and `77455ed`, and fix any gap;
   - record a short panel capture (gamepad focus, a subgrouped category);
   - run the tests, commit "M2 WP1: review fixes (...)" and push.
2. **The lead judges the WP2 after-sheets** in `.worktrees/m2-vfx/captures/review/` and shows them to Game-boy.
3. **Merge** `m2/tuning`, `m2/vfx` and `m2/audio` into `m2/hit-feel`:
   - keep all four `_build_presentation()` lines in `test_room.gd` and both ASSETS.md sections;
   - WP2's ARCHITECTURE "VFX" paragraph sits after CameraDirector, WP3's "Audio and rumble" after "Input";
   - WP2 changed `vfx_min_view_share` to 0.04 and `vfx_lunge_lines_min_m` to 1.0;
   - WP2 added a `##` doc comment above `impact_frame_enabled` in "Hit feel".
4. **After merging:** `godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd`, then `tools/run_tests.sh`. Everything must pass with no SCRIPT ERROR. Push and update this file.
5. **WP4:** the player-ragdoll default is confirmed.

**Spec questions for Game-boy (defaults keep the spec as written; none implemented):**
- **WP3, body fall:** the body-fall layer plays at contact, but the body lands 0.5-1 s later. Proposal: play it on ground contact (needs a new sim event).
- **WP3, swing whoosh:** `attack_whiffed` fires when the active frames end, so whiffs sound 1-3 frames late. Proposal: a new `attack_active` event, and one swing whoosh per attack at its first active frame.
- **WP3, wind-up whoosh:** it plays at wind-up start. Proposal: keep only the effort grunt as the cue.
- **WP3, slow-mo audio:** an optional pitch-down or low-pass of the SFX during the finisher slow-mo, a tunable that defaults off.
- **WP2, bruised look:** "bruised" now also scuffs the clothes, because the skin barely shows at 1 m or in side view. If Game-boy wants skin only, it's a one-line revert.
- **WP2, flashing toggle:** the photosensitivity toggle (`impact_frame_enabled`) also stops the speed-line flicker. A separate "reduce flashing" toggle would be a spec change.

**Usage this window:** WP2 and WP3 ran together and took account C from 3% to 55% in about 40 minutes, about 26% each for a combined review and fix. WP1 launched at 55%, and the window reached 71% by 19:11. **Plan on roughly 25% of a 5-hour window per combined review-and-fix agent.**

### 2026-10-23 18:10 CDT: account C took over; phase 1 verify-and-fix running
A third account's working session took over at 0% of its 5-hour window (resets 23:00 CDT) and 0% weekly (resets Wed 2026-10-28 11:00 CDT). Its usage watcher runs (Haiku, low effort, `/loop 5m`, session "Beat-em-up: usage watcher").
- **Running:** workflow `m2-phase1-verify-fix` (run `wf_3d9df549-bac`, started from this session). It runs one heavy agent per WP and at most two at once: WP2 and WP3 first, then WP1. A Haiku usage gate runs before each launch and stops new launches at 65% (5-hour) or 85% (weekly).
  - **WP2:** verifies the 13 findings and fixes them in `.worktrees/m2-vfx`. It also fixes the speed-line texture lifetime (the lines must end as crisp tapered ink), lunge lines on plain jabs, and the bruised look at 1 m. It leaves after-sheets in `.worktrees/m2-vfx/captures/review/`.
  - **WP3:** reviews from scratch (mechanics, plus feel by WAV and capture-audio analysis), then verifies and fixes in `.worktrees/m2-audio`.
  - **WP1:** verifies the 17 findings and fixes them in `.worktrees/m2-tuning`, including the panel showing `@export_subgroup` headings. WP2 and WP3 put their own groups into subgroups.
  - Each agent commits "M2 WPn: review fixes (...)" and pushes its branch, committing `wip:` along the way.
- **If cut off:** check each WP branch for a "review fixes" commit. A WP without one needs its pass redone. Copy that WP's prompt from the workflow script in this session's transcript, or rewrite it from this entry. Within the same session, resume with `resumeFromRunId`.
- **Then:** merge into `m2/hit-feel` as the trial did, regenerate the preset, run the tests, push. Then WP4: Game-boy confirmed the player-ragdoll default at 18:20 CDT (enemies and dummies ragdoll; the player keeps animated reactions, with a toggle).

### 2026-10-23 17:25 CDT: handoff, account B's 5-hour window at 72% (switched accounts 17:55)
The watcher warned at 72% of account B's 5-hour window, which resets at 21:40 CDT; B's weekly is at 12%. Account A's weekly is still at 95% until Mon 2026-10-26 01:00 CDT. Everything is committed and pushed; the worktrees are clean.
- **Burn rate.** In about 20 minutes, four parallel review agents took the window from 7% to 62%. Each heavy reviewer costs about 13% of a 5-hour window here, so run at most 2 at once and gate every launch on `get_usage`.
- **Stopped:** workflow `m2-phase1-review-fix` (run `wf_18e38241-91a`). Four of its six reviewers finished.
  - Their 30 findings are saved in [docs/reviews/M2-phase1-review-findings.json](reviews/M2-phase1-review-findings.json) (WP1 mechanics and feel, WP2 mechanics and feel).
  - None are verified or fixed yet.
  - The two WP3 reviewers were cut off with no result. Their scratch probes sit in `.worktrees/m2-audio/captures/scratch_probes/` and `.worktrees/m2-trial/captures/scratch_probes/` (untracked, ignored).
- **Headline findings, unverified:**
  - WP2: the speed-line defect has a root cause. `VfxArt` keeps no texture alive, so `speed_lines.png` is freed after every `_draw` and reloads from disk, and every FX texture loads at the moment of the hit.
  - WP2: a per-sprite view clamp makes the light, heavy and finisher bursts the same size.
  - WP2: effects are placed against the previous frame's camera.
  - WP2: words are forced into view even for hits behind the camera.
  - WP2: the speed lines flicker at 30 Hz regardless of the photosensitivity toggle.
  - WP1: the gamepad can't reach the sliders, and A/B do nothing (`ui_accept`/`ui_cancel` have no joypad buttons in 4.7).
  - WP1: spawn-at-crosshair can place dummies in walls or bodies.
  - WP1: presets aren't range-checked.
  - WP1: the 0.25x cheat doesn't slow hitstop or slow-mo.
- **Resume steps:**
  1. Run a verify-then-fix pass per WP from the JSON, at most 2 heavy agents at once: one skeptic per WP, then one fixer per worktree that commits "M2 WPn: review fixes" and pushes.
  2. WP3 still needs its two reviews (mechanics; feel by audio analysis of the WAVs and a capture's audio track).
  3. Then merge into `m2/hit-feel`. The trial merge at `.worktrees/m2-trial` (local only) shows how: keep all four `_build_presentation()` lines and both ASSETS.md sections, then `godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd`, then `tools/run_tests.sh` (371 pass).
  4. Then WP4.
- **WP4 brief:** the lead's design decisions for the ragdoll are drafted in [docs/milestones/M2-WP4-brief.md](milestones/M2-WP4-brief.md). The player keeps animation-only reactions by default, with a toggle (asked of Game-boy, no answer yet). Staggers get a partial ragdoll on the upper body. Every off-feet reaction gets a full ragdoll held to the simulation's body by a soft spring. The ragdoll follows each actor's hitstop and slow-mo scale. A "Ragdoll" tuning group.
- **17:55 CDT: Game-boy switched accounts.** Account B's watcher has been told to end its loop, and B's working session was renamed "Beat-em-up: account B session (handed off)", which frees the title. The new account's session renames itself "Beat-em-up: working session" and starts its own watcher. The player-ragdoll default is still unanswered; ask Game-boy before WP4 starts.

### 2026-10-23 17:05 CDT: account B took over; phase 1 review and fix running
Account B's working session took over at 1% of its 5-hour window (resets 21:39 CDT) and 0% weekly (resets Tue 2026-10-27 17:00 CDT). Its usage watcher runs (Haiku, `/loop 5m`, session "Beat-em-up: usage watcher").
- **WP2 tests:** all 332 pass in `.worktrees/m2-vfx`. The lead recorded the whole `vfx_bot` (13 acts, first person and side view) and judged it. Bursts, words, the 2-frame impact frame and its toggle, blood, spit and tooth, and the block, parry and guard-break sparks all read well. Three defects:
  - the speed lines render as wide gray translucent rectangles instead of tapered ink streaks (about 40% of the screen in side view on finishers);
  - lunge lines fire on ordinary jab steps;
  - the bruised look barely reads at 1 m.
- **Trial merge:** `.worktrees/m2-trial` (branch `m2/trial-merge`, local scratch, never merge it) has all three WPs merged, with only the expected conflicts (the `test_room.gd` presentation lines, keep all four; `ASSETS.md` Effects and Audio sections, keep both; `tuning_data.gd` merged cleanly). With `tools/gen_default_preset.gd` re-run, **all 371 tests pass**.
- **Running:** workflow `m2-phase1-review-fix` (run `wf_18e38241-91a`). Per WP, a mechanics reviewer and a feel reviewer (from captures) feed one adversarial verifier, then a fixer in that WP's worktree that commits "M2 WPn: review fixes ..." and pushes its branch. A usage gate drops to 2 agents at once past 50% of the 5-hour window and stops at 75%.
- **If cut off:** check each WP branch for a "review fixes" commit. Any WP without one needs its review/fix redone, or resume the workflow in the same session with `resumeFromRunId`. Then merge into `m2/hit-feel` as the trial did, regenerate the preset, run the tests and push.

### 2026-10-23 13:05 CDT: handoff to the second account (account A's weekly limit is at 95%)
Account A's weekly limit is at 95% and resets Mon 2026-10-26 about 01:00 CDT. Its 5-hour window has just reset. Everything is committed and pushed. Milestone 2, phase 1:

| WP | Worktree / branch | State | Next |
| --- | --- | --- | --- |
| WP1 tuning panel, presets, cheats | `.worktrees/m2-tuning` / `m2/tuning` | **Built**: `bb4b3c1`, 313 tests pass. F1 panel auto-built from TuningData plus a Moves page; JSON presets; F4 cheat menu; ARCHITECTURE section. | Adversarial review, then fix. |
| WP2 comic VFX, damage looks | `.worktrees/m2-vfx` / `m2/vfx` | **Builder cut off mid-build.** Five `wip:` commits: the SVG art set (`tools/gen_fx.gd`, PNGs), VfxDirector, damage looks, the VFX tuning group, bot acts, `tests/test_vfx.gd`, ASSETS.md. Unknown whether the tests pass. | Run `tools/run_tests.sh` in the worktree. Finish the brief (M2-plan.md WP2): judge captures from first person and side view. Commit, then review and fix. |
| WP3 audio, rumble | `.worktrees/m2-audio` / `m2/audio` | **Built**: `2d562d7`. `tools/gen_sfx.gd`, `.wav` set, AudioDirector, RumbleDirector, Audio tuning group, `tests/test_audio.gd`. | Adversarial review, then fix. |

**On a new machine:** `git fetch` and create the worktrees from the pushed branches, for example `git worktree add .worktrees/m2-vfx m2/vfx`.

**Then merge into `m2/hit-feel`.** Expect trivial conflicts in:
- `game/level/test_room.gd` `_build_presentation()`, where each WP added one marked line;
- `ASSETS.md`, where WP2 and WP3 each added a section;
- maybe `game/autoload/tuning_data.gd` (WP2 put "VFX" after "Hit feel"; WP3 put "Audio" before "Debug").

**After merging:** regenerate the default preset with `godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd` (WP1's test fails by design until you do). Run all tests, push, and update this file.

**Phases 2 and 3 after that:** see [docs/milestones/M2-plan.md](milestones/M2-plan.md).

**Notes from WP1's builder:**
- The F1/F4 overlay takes all keys while open, so F2, F3, F5 and H work only after closing it.
- The help overlay still labels F1 "Tuning panel (Milestone 2)".
- README controls are phase 3's job.

**Lesson (usage).** Three parallel builders burned about 70% of a 5-hour window in roughly 30 minutes, inside one 15-minute watcher interval, so the window ran out with no warning. Before launching a workflow, check `mcp__ccd_session_mgmt__get_usage`. Run at most two heavy agents at once when the window is past 50%. The watcher now checks every 5 minutes and also warns on fast burn (see below).

### Earlier: Milestone 2 phase 1 started
- Milestone 1 is done: Game-boy signed it off after three playtest rounds, and it's merged into `main` (PR #1, merge `c3e6a98`). Milestone 2 is on branch `m2/hit-feel`, from `main`.

## Decisions log (Game-boy)
Every approved spec change so far is in README.md, "Where M1 departs from the spec". In short:
- **Camera and stance:** throat-height lens; relaxed player stance; smaller wrapped hands; enemy gloves and guard pulled in.
- **Block and grab:** a held block on neutral B (guard meter, perfect block, guard break, sparring dummy); grab anytime except against a mid-strike enemy; dodges kept, with a late-stick fix.
- **Moves and camera:**
  - the view follows the spin of the spin kick, the heel kick and the spinning backfist;
  - the spinning backfist is on P P · P and the flurry on P · P;
  - the back elbow turns the view 150° (Game-boy is to confirm whether 110° is preferred).
- **Ragdoll (M2 WP4, 2026-10-23):** enemies and training dummies ragdoll. The player keeps animated reactions by default, with a toggle in the "Ragdoll" tuning group.
- **Usage watcher cadence (20:13 CDT):** checks every 20 minutes below 70%, every 10 minutes up to 85%, every 5 minutes above that. It halts work and hands off at 90% (it was 70% before). See "Usage watcher".
- **Phase 1 spec questions (20:30 CDT): all eight defaults kept.**
  - WP3: the body fall stays at contact, there's no new `attack_active` event, the wind-up whoosh stays, and there's no slow-mo audio filter.
  - WP2: bruised still scuffs the clothes, and there's no separate "reduce flashing" toggle.
  - WP1: the 0.25x cheat also stretches hitstop and slow-mo, and cheats stay out of presets. Both are recorded in README, "Where M2 departs from the spec".
- **White hit flash (2026-10-24 10:40 CDT): localized.** Full white at the contact point, fading out by a tunable radius (default about 0.25 m), with a tunable strength, both in "Hit feel". A large radius gives the old whole-body look. Recorded in README's M2 departures. It's implemented in phase 3, after WP4 merges: `combat_actor.gd` and `humanoid_rig.gd` overlap WP4. Also check that it really shows `hit_flash_frames` (2) frames, since the WP2 captures show one white frame per hit.
- **WP4 ragdoll questions (2026-10-24 11:05 CDT):**
  - the hit's push at the exact contact point is preferred, since comic contortions are fine; phase 3 builds it with spin caps and shows A/B captures first;
  - KO bodies lie briefly, then blink off (a departure from SPEC §6's "stay until the arena clears");
  - KO bodies take no hits;
  - heavy-tier knockdowns get the full ragdoll (a departure);
  - staggers may exceed SPEC §6's 0.6 influence (a departure).
- **Grab view (2026-10-24 11:05 CDT):** while holding, the first-person view pans down so the knees show landing on the held enemy, and the player bends at the waist for the hold and the knees. The spec doesn't cover it, so it's not a departure. Details: [milestones/M2-phase3-plan.md](milestones/M2-phase3-plan.md).
- **Ultracode (2026-10-24 11:38 CDT):** Game-boy turned ultracode on. Substantive work runs as Workflow scripts (multi-lens review, adversarial verification, completeness critic), with the usage rules still in force.
- **Handoff for package C (2026-10-24 12:38 CDT):** switch accounts now rather than wait for account E's 16:30 reset.
- **Usage thresholds (2026-10-24 12:40 CDT):** work up to the 90% handoff instead of stopping new launches at 65%. Size each launch to the headroom left below 90%. When a new phase or milestone doesn't fit, split off a first task that does, run it, and hand off at 90%. See "Usage rules for the working session".
- **Side view is debug-only (2026-10-25):** only first-person looks and feel count; side view only checks mechanics (it may matter later for a 2-player mode). hit-05 and gap-06 are dropped, and the side-view flash's minimum size stays as it is.
- **The player's KO, an "out of body" view (2026-10-25):** the camera pans away from the body and shows the player lying on the floor, the only time it leaves the player's eyes. It's a README departure.
- **Round 2's proposed fixes are approved as written (2026-10-25)**, with the KO view as above.
- **Models (2026-10-25):** Opus for planning and review, Sonnet for coding and execution. Fixers run with `fixer_model: "sonnet"`.
- **Defaults for the rest of M2 (2026-10-25 14:15 CDT):** every open question takes its default for the rest of this milestone. Without the final art, Game-boy can't tell the grey-block feel issues apart. So don't put fine look or feel questions to him in M2. Record each default taken, and leave art-dependent feel polish for when the art is in.
- **Milestone 3 setup (2026-10-25 16:50 CDT):** M2 signed off and merged. M3 runs without Game-boy's input until it's done to spec, then a Slack DM with a playable link and a digest of judgement calls (each with an alternative not taken). The playable link is a GitHub Release with a zipped macOS export (downloading the official export templates is approved). The boss is in M3 as graybox with a placeholder name. Enemy grabs on the player can be broken by mashing P/K. The account is now a premium seat (5 times the limits): the watcher checks less often, and at a limit a scheduled task resumes the work after the reset.
- **Comms (2026-10-25 17:35 CDT):** whenever work is blocked on Game-boy (an authorization, a permission prompt, a login, a decision), DM him on Slack (Michael, `U0AQMKKBL93`) at once, then carry on with anything not blocked.
- **Milestone 3 signed off (2026-10-26):** Game-boy played the build, called M3 complete as-is and approved every M3 judgement call and spec departure (README, `docs/milestones/M3-judgement-calls.md`). The boss keeps 300 HP.
- **Milestone 4 toolchain (2026-10-26):** skip Mixamo for now and assess later (Tripo auto-rig first); Tripo for 3D generation; Google Gemini for images; Blender installed from the command line (5.2.2 LTS).
- **M4 concept pick (2026-10-27 09:00 CDT, in the session chat):** Street Punk A and Hero C. His words: "Eventually, I'll want to allow for selecting from a menu of hero options, but for this demo, let's go with Hero C. I like Street Punk A, as well." The hero menu is a later milestone's feature; M4 builds Hero C only, with everything hero-specific in files.
- **Process:** at each usage limit, hand off to Game-boy's second Claude account. Never assume the same session resumes.
- **Milestone 6 go (2026-11-04 14:00 CST, session chat):** "OK we're ready to begin". Approved: `docs/milestones/M6-proposal.md`, and his answers:
  - **Audio option (a):** the Sonniss GDC bundle for the hit stack and the world sounds; ElevenLabs for the voices.
  - **ElevenLabs:** upgraded to Starter, "if for nothing else than not having to deal with re-doing sounds not licensed for commercial use". Key `ELEVEN_LABS_API_KEY`.
  - **Tripo** topped up to 1,705 credits.
  - **Ultracode** on.
- **M6 picks (2026-11-04 14:35 CST, session chat), word for word:** "Kicker: C / Pipe-Thug: B / Bruiser: A / Boss: C / Boss Name: C / Second Weapon: A / Moods: A and C". That is (sheets in `assets/source/concepts/m6/sheets/`):
  - **Kicker C** (`kicker_c.jpg`): a hooded lime vest, a lime bandana, a black cap, a ponytail, wrapped forearms, black cargo shorts over lime leggings, black boots.
  - **Pipe Thug B** (`thug_b.jpg`): a black beanie, a yellow-patterned bandana, a sleeveless olive hoodie with a black chest strap and a yellow buckle, yellow wrist wraps, olive trousers with yellow bands, black boots.
  - **Bruiser A** (`bruiser_a.jpg`): a purple hood with a steel visor and a purple mask, a padded purple jacket over steel chest plates, steel forearm guards and knee pads, a cream belt, black trousers, steel-capped boots.
  - **Boss C** (`boss_c.jpg`), named **Ox Pellerin**, the underground-fight champion: a hooded charcoal robe with orange trim, an orange champion's belt, boxing gloves with orange wraps, shorts over black tights, laced boots. Darken the charcoal: it rendered as light slate. A web check found no game or film character of that name.
  - **Second weapon A** (`weapon_a.jpg`): a bike chain and padlock. A short sideways whip, the padlock landing last, medium reach.
  - **Moods:** street **A** (`mood_street_a.jpg`: warm brick, sodium street lamps, rust, wooden crates) and roof **C** (`mood_roof_a.jpg`, since the sheet relabels the roofs C/D: warm brick parapets, orange dusk, water tanks, ducts, skylights, AC units).
- **The Tripo licence (2026-11-04 14:45 CST, session chat):** the key is on Tripo's **paid API platform**, with credits he bought ("Yes, paid API"). Tripo's help page gives paid users full rights to their outputs, including commercial use, and keeps rights only to free users' outputs. So ASSETS.md records each Tripo model as "Tripo API (paid credits): owned by the project, commercial use". The phase 2 gate is cleared.
- **The prune (2026-11-04 14:50 CST):** "Yes, prune them". All 90 M3-M5 worktrees are removed, and 89 GB is free.
- **Every sound from ElevenLabs (2026-11-04 15:05 CST, session chat):** "Why don't we just use ElevenLabs for all sound instead? Would the 40k credits I have be enough to cover that?" This replaces option (a)'s Sonniss half.
  - The account is Starter with 40,000 credits (none used; it renews about Dec 3).
  - **The lead's estimate:**
    - every pool comes to about 160 s of audio per take (the voices about 46 s, the hit stack and blocks about 16 s, the weapons about 11 s, the barriers about 24 s, the stings about 3 s, the two beds about 60 s);
    - at 40 credits a second that's about 6,400 credits a take, about 19,000 with 3 candidates per clip, and about 24,000 with a redo round after his audition.
  - **The plan:** SONNISS became SFX (phase 2, ceiling 20,000). D19 is rewritten, and the M6 ElevenLabs stop is 30,000 (`max_call` 1200). AUDIO's tools are made general. `args-P2b.json` is gone.
- **Still open:** nothing.

## Usage watcher
A separate low-cost Claude Code session, "Beat-em-up: usage watcher". Start it from the working session with `start_session`: initiation `user_asked`, `model` claude-haiku-5-5, `effort` low, `use_worktree` false, and the prompt below verbatim.

**Since 2026-10-25 17:00 CDT the account is a premium seat, 5 times the old standard seat's limits** (Game-boy). The same work therefore costs about a fifth of the percentages measured in M1 and M2 (the cost table below is already divided). The watcher checks less often, but still at 90% of either window, and still early on a fast burn: a big workflow (up to 10 agents at once) can burn as fast as two heavy agents did before.

| Usage (the higher of the 5-hour and weekly windows) | Next check |
| --- | --- |
| below 70% | in 30 minutes |
| 70% up to 85% | in 15 minutes |
| 85% and up | in 5 minutes |

At 90% of either window it tells the working session to halt and hand off, then makes sure a one-time scheduled task will resume the work after that window resets (see "Resume after a limit").

Its prompt:

```
/loop Usage watcher for the beat-em-up repo at /Users/arachne/repos/beat-em-up-PoC. You pace yourself. On each check:
1. Call mcp__ccd_session_mgmt__get_usage (load it with ToolSearch the first time). Read plan.windows: the "5-hour limit" window and the window labelled "Weekly · all models". Let U be the higher of their two percentUsed values.
2. Handoff. If either window is at 90% or more, and you haven't already warned for that window's resetsAt, send a message to the session titled "Beat-em-up: working session" (find it with ListAgents, or mcp__ccd_session_mgmt__list_sessions). The message: "Usage at N% (window W, resets R). Halt work and do the handoff now per CLAUDE.md: tell running agents and workflows to stop at a stopping point, commit and push WIP on every branch and worktree, update and push docs/HANDOFF.md, then create the resume task (docs/HANDOFF.md, 'Resume after a limit')." Remember that you warned for that resetsAt, and when.
3. Resume task. On the first check 20 minutes or more after a warning, call mcp__scheduled-tasks__list_scheduled_tasks (load it with ToolSearch). If no enabled task whose taskId starts with "beat-em-up-resume" has a nextRunAt after now, create one with mcp__scheduled-tasks__create_scheduled_task: taskId "beat-em-up-resume-" plus the reset's local date and time as yyyymmdd-hhmm, fireAt the warned window's resetsAt plus 10 minutes (ISO 8601 with an offset), description "Resume beat-em-up work after the usage reset", title "Beat-em-up: resume after usage reset", and as the prompt the exact text between the lines "RESUME-PROMPT-START" and "RESUME-PROMPT-END" in docs/HANDOFF.md (read the file). Do this once per resetsAt.
4. Snapshot. If either window is at 95% or more, write HANDOFF-SNAPSHOT.md at the repo root (untracked; never commit it). It holds:
   - the time and the usage numbers;
   - git status, git branch -vv and git worktree list;
   - for each worktree under .worktrees/, its git status --short and git log --oneline -3.
5. Next check, from U:
   - below 70: in 30 minutes (1800 s);
   - 70 up to 85: in 15 minutes (900 s);
   - 85 or more: in 5 minutes (300 s).
6. Fast burn. Estimate the rate from your previous check. If at that rate either window would reach 90% before that next check, check again in 5 minutes instead. If it would reach 90% within those 5 minutes, send the step 2 warning now (once per resetsAt).
7. Once a window you warned for has reset (its percentUsed is below 50 again), forget that warning.
8. Schedule the next check with ScheduleWakeup, passing this same prompt back.
Otherwise say nothing beyond one short line: the two percentages and the next check time. Never edit tracked files, run builds or start other work. If the working session tells you to end your loop, call ScheduleWakeup with stop: true.
```

**Resume after a limit.** The working session creates the resume task itself as the last step of a handoff (the watcher's step 3 is the fallback when it was cut off first): `mcp__scheduled-tasks__create_scheduled_task` with the fields in the watcher's step 3, firing 10 minutes after the window that stopped work resets. The task wakes the working session if it still exists, which keeps its context, or else starts a takeover. Its prompt, verbatim:

RESUME-PROMPT-START
Resume the beat-em-up Milestone 6 work after a usage reset. The project is /Users/arachne/repos/beat-em-up-PoC (Godot 4.7.2, GitHub mikedtcm22/beat-em-up-PoC). Game-boy (the owner) asked for the work to continue across usage limits without waiting for him, until Milestone 6 is done.
1. Call mcp__ccd_session_mgmt__get_usage (load it with ToolSearch). If either the "5-hour limit" or the "Weekly · all models" window is still at 90% or more, create a copy of this task with mcp__scheduled-tasks__create_scheduled_task (a new taskId starting "beat-em-up-resume-", fireAt that window's resetsAt plus 10 minutes, the same prompt) and stop.
2. Call mcp__ccd_session_mgmt__list_sessions (load it with ToolSearch). If a session titled exactly "Beat-em-up: working session" is listed and not archived, send it with mcp__ccd_session_mgmt__send_message: "Scheduled resume: the usage window has reset. Check get_usage, make sure a usage watcher is running (docs/HANDOFF.md, 'Usage watcher'), then resume Milestone 6 from the newest entry in docs/HANDOFF.md." If the result says "delivered" or "queued", you're done: say so in one line and stop.
3. Otherwise you are the new working session: follow the takeover prompt in docs/HANDOFF.md (the "Takeover prompt" section) exactly, starting with renaming this session "Beat-em-up: working session".
RESUME-PROMPT-END

**Usage rules for the working session** (Game-boy, 2026-10-24 12:40 CDT; costs rescaled for the premium seat on 2026-10-25):
- **Work up to the 90% handoff.** The watcher's 90% message is the only stop. Don't stop, idle or hand off early because a big piece won't fit.
- **Size each launch to the headroom.** Call `mcp__ccd_session_mgmt__get_usage` before every launch. The headroom is 90% minus the higher of the 5-hour and weekly `percentUsed`. Launch work whose estimated cost fits it. Measured costs on the old standard seat, divided by 5 (re-measure and update this table during M3):

  | Work | Cost (% of a 5-hour window) |
  | --- | --- |
  | A builder the size of WP4, or phase 3's A or B | 6-10% |
  | A heavy agent that both reviews and fixes | about 5% |
  | A fixer | about 5% |
  | A review-only agent | about 3% |
  | Lead work (merging, judging sheets, docs) | under 1% |
  | Two heavy agents at once | about 0.25-0.3 points a minute |

  Weekly points: on the old seat one 5-hour point cost about 0.16 weekly points; re-measure.
- **When the next phase or milestone doesn't fit:** spend a little of the headroom splitting it into a first task that fits the rest, and run that task. Commit `wip:` as it goes, and hand off at 90%. Write the split into the milestone plan and HANDOFF, so the next session starts at the next task.
- **Keep the 90% cut cheap:** agents commit `wip:` and push every 15-20 minutes, so a halt loses little.
- **Concurrency:** with the premium seat, a workflow may run up to about 6 heavy agents at once while the window is under 60%, and at most two above that.
- **The handoff's last step** is the resume task (above), so the work restarts by itself after the reset.

**Model, effort and process rules from Milestone 5 on** (Game-boy, 2026-11-03: get as far through the milestones on one week's limit as possible, at M4's quality). The runners `tools/workflows/build.js` and `tools/workflows/review.js` have these as their defaults; copy their args pattern into `docs/reviews/M<N>/`.

| Role | Model and effort | Note |
| --- | --- | --- |
| Lead (the working session) | Opus, high | A fresh session at each milestone start: HANDOFF carries everything, and a long lead context is re-read every turn. |
| Milestone plan | One Opus planner at high, then one Opus critic at medium | Extra or max effort only for the plan's final synthesis. No planner panel. |
| Visual review lenses (art, motion, feel, judged from images) | Opus, high | Where Opus clearly beats Sonnet. At most 3 lenses a round. |
| Code, test and pipeline review lenses | Sonnet, high | Set `model: "sonnet"` on the lens. |
| Builders and fixers | Sonnet, high | As in M4. They found the inside-out legs and the right-hand fist. |
| Skeptics | Sonnet, medium | Only for medium and high findings. Lows come back in `for_lead_triage`, and the lead promotes any with `verdicts`. |
| Partition | The lead inline (`partition: false`), or Sonnet medium | |
| Evidence, clips, docs | Sonnet, medium, or the lead's own scripted commands | |
| Usage gates and the watcher | Haiku, low | |

Extra or max effort is for two things only: the plan's synthesis, and a diagnosis two agents have already failed on.

**Process rules:**
1. **The lead's look comes first.** Before any review round, the lead looks at full-resolution stills of what changed, beside the concept or the spec. In M4 that caught the cuffs and the shades at almost no cost.
2. **One review round, then one fix wave, then a targeted re-check** of only the changed items, not a full re-score. Use 3 lenses (for example: what the player sees; motion and feel; code, tests and pipeline), not 6.
3. **Record once.** The lead runs `tools/record_acts.sh <dir> "<slug>|<act title>" ...` once per round and passes the folder as `captures_dir`. Reviewers and builders judge from it and record only what's missing.
4. **Image budget** (`image_budget`, default 25 for builders and 30 for reviewers). Scan contact sheets at about 1000 px wide; read a full-resolution crop only for the item being judged.
5. **Self-contained briefs.** Each package names its own reading list (`read`, plus the round's short `read_first`). Agents search rather than read whole documents. Keep the milestone plan short, with each package's brief in one place.
6. **Batch small fixes into one fixer.** Every parallel fixer re-reads the same documents. Use at most 3 fix packages a round.
7. **Ultracode** (when Game-boy turns it on for sub-agents) doesn't lift these caps: workflows stay inside them unless he says otherwise.
8. **The weekly limit is account-wide.** Between 2026-10-27 evening and 10-29 it went from about 50% to 90% while no M4 agent ran. Check `get_usage` before each launch, not only at milestone start.

**Measured in M4** (sub-agent tokens; the 5-hour window on this seat):

| Work | Tokens | 5-hour window |
| --- | --- | --- |
| A Sonnet builder or fixer | 0.25-0.9M (most 0.5-0.7M) | about 4-7% |
| An Opus visual reviewer, recording and reading full-resolution stills | about 0.8-1.2M | about 5-7% |
| The six-lens round (5 Opus reviewers, 21 Sonnet skeptics, a partition) | 6.3M | about 36% |
| The one-reviewer re-score (13 skeptics) | 1.6M | about 9% |

If no watcher is running, for example after an account switch, start one with that prompt. A new account's watcher reports that account's usage.

**The working session must be titled "Beat-em-up: working session"** so the watcher and the resume task can find it. A new working session renames itself to that first, with `mcp__ccd_session_mgmt__set_session_title`.

**At an account switch, the old working session:**
- renames itself "Beat-em-up: account X session (handed off)", which frees the title;
- tells its watcher to end its loop: "End your loop now: call ScheduleWakeup with stop: true, or CronDelete your job if you run on a fixed interval."

## Takeover prompt
Game-boy pastes this into a new account's session. Keep the "Next steps" list current at every handoff; the rest changes rarely.

```
You're the new working session for a Godot 4.7.2 project: a first-person beat-em-up proof of concept at /Users/arachne/repos/beat-em-up-PoC (GitHub: mikedtcm22/beat-em-up-PoC). I'm Game-boy, the owner. Milestones 1-5 are signed off and merged into main. Earlier sessions did that work and handed off; the repo is the source of truth. This session continues Milestone 6 (SPEC §12): full art and audio, done when no placeholder assets remain.

Start by doing these, in order:
1. Rename this session to "Beat-em-up: working session" (mcp__ccd_session_mgmt__set_session_title); the usage watcher finds you by that title.
2. Read CLAUDE.md, then the newest entries of docs/HANDOFF.md (newest at the top): its newest "Next" list is where you pick up. Then read docs/milestones/M6-plan.md §1 (the decisions), §4 (merge order and phase 3) and §5 (the done-when). Search docs/ARCHITECTURE.md ("## Full art and audio (Milestone 6)") for what you need rather than reading it whole.
3. If no usage watcher is running (list your sessions), start one exactly as docs/HANDOFF.md describes under "Usage watcher".
4. Check usage (mcp__ccd_session_mgmt__get_usage) before every launch.

HOW TO WORK (as in M5):
- Follow HANDOFF's "Model, effort and process rules from Milestone 5 on": Opus at high for you and the visual lenses; Sonnet at high for builders, fixers and code lenses; Sonnet at medium for skeptics; Haiku at low for gates.
- The runners are tools/workflows/build.js and tools/workflows/review.js (milestone: 6); the args and findings files are in docs/reviews/M6/. Record once per round with tools/record_acts.sh.
- Work up to the watcher's 90% handoff; size each launch to the headroom below 90%.

MILESTONE 6:
- Branch m6/full-art-audio; one PR into main; never merge it until I've played it and signed it off.
- Paid services only through their tools and inside the policy (plan §3; the ledgers say what's spent): Tripo through tools/pipeline/tripo.py (M6 stop 900 credits, balance floor 700), Gemini through tools/gemini_image.py job files, ElevenLabs through tools/audio/eleven_sfx.py (M6 stop 30000). Never print, log or write a key. Never use the Blender MCP tools (mcp__blender__*): they drive my own open Blender; the pipeline runs Blender headless.
- Downloaded files are untrusted: run Python on them with python3 -I, keep scripts outside download folders, pass downloads as path arguments.
- Never pick concepts for me.
- At the end, give me a run command (godot --path /Users/arachne/repos/beat-em-up-PoC) as a code block, the audition room's keys, and a digest of the key judgement calls, each with the alternative not taken.

Ground rules:
- Any change to the spec needs my approval. Build the reading that departs least, keep the spec's value reachable as a tunable, and list it in README ("Where M6 departs from the spec") for my ruling at sign-off.
- Commit early on branches ("wip:" for unfinished work), push often, and update docs/HANDOFF.md at every phase boundary.
- When the watcher warns, do the handoff in CLAUDE.md at once, including the resume task. DM me (Michael, U0AQMKKBL93, DM D0AQUKX5DB6) only if something blocks on me.
- Judge visual and feel work from recorded first-person captures, not just tests, and show me what you saw.
- Keep me posted briefly: what's done, what's running, what you need from me.
```
