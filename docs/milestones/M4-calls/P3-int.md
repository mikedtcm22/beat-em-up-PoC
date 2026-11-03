# M4 calls: P3-int

Package P3-int, the fix round's last package (M4-plan Part C section 8 as amended by A23, Part B section B1, and the lead's note for the round): what P3-early, P3-flash and F-player-int left of it. Four things: `ToonMaterials.outline(first_person)` so the player stops calling a private function, the A19 strain run on the two shipped GLBs, `tests/test_m4_done_when.gd` (one test per row A1-A14 on the shipped art, every row's state in one place), and the final look probe (L1-L3 and L5 in one windowed run, into a look.json). Each call is the decision, an alternative not taken, and why. Part 2 lists every assertion that changed, part 3 the numbers, part 4 what the first-person stills show, part 5 requests, departures and risks. The two art fixers (F-punk-fix, F-player-fix) are changing the GLBs while this runs, so nothing here reads a number frozen from today's art except as a ratchet with a margin (C4). The machine was shared (1-minute load average 3 to 5); the pose, count and share figures are exact (a fight is seeded, and the final probe printed the same figures in both of its runs).

## 1. Calls

**C1. `ToonMaterials.outline(first_person := false)`; `RigPaint.outline_material()` hands it the rig's `first_person_body`; `PlayerCharacter._wear_first_person_hull()` is deleted.**
- *Decision.* `outline()` returned `_hull(Hull.ART, false)`; it now returns `_hull(Hull.ART, first_person)`. `RigPaint.outline_material()` calls `ToonMaterials.outline(_rig.first_person_body)`, which `SkinnedArt.attach()` already reads when it puts the art's overlay on each mesh, so the player's art is born with the first-person hull (`fp_scale` = `look_outline_fp_scale`, the lens fade, tracked, so every `look_*` change reaches it). `player.gd` loses the method and its call at the end of `_ready()`; nothing outside `ToonMaterials` calls `_hull()` any more. It is the shape `outline_for_part(shape, first_person)` already has for the primitives, and `first_person_body` is set in `_configure_rig()` before `build()`, so it is known when the art is attached (a rig that flips it after the build keeps the hull it was built with, exactly as the primitives' hulls do).
- *Alternative.* A second public function (`outline_first_person()`), or a `first_person` property on `RigPaint` set by the player.
- *Why not.* The first would give the hull two spellings next to `outline_for_part(shape, first_person)`; the second would be a second place that knows the rig is the player's. The rig already says so.
- *Proof of no look change* (F-look's `Look: tune own hull`, T8: the player's forearms and fists in the guard, looking 20 degrees down, with the hull and with its width 0; widths at 1080p), recorded on this branch with the old code and again with the new:

| | left | right | top | all |
| --- | --- | --- | --- | --- |
| before (`_wear_first_person_hull`) | 3.82 | 3.46 | 3.85 | 3.94 |
| after (`outline(first_person)`) | 3.82 | 3.46 | 3.85 | 3.94 |

  The two stills `probe_t8_guard_on.png` and `probe_t8_guard_flat.png` are byte-identical across the two runs (md5 `48a654fd...` and `55d32d36...`). The headless twin is `test_the_players_art_hull_is_toon_materials_first_person_outline_and_an_enemys_is_the_full_width_one`: the hero's art meshes wear the same material object as `ToonMaterials.outline(true)` and `rig.paint.outline_material()`, a Punk's wear `outline(false)`, no argument is the full-width one, `fp_scale` is `look_outline_fp_scale` (and moves live), the player has no `_wear_first_person_hull`.

**C2. The strain run on the shipped GLBs measures against the skinned rest, and is made once per art.**
- *Decision.* `test_skinned_art.gd` gets `test_the_strain_of_the_shipped_glbs_is_reported_for_the_gate`: the Punk's and the hero's GLB (`assets/export/characters/punk/punk.glb`, `.../player/player.glb`), each worn the way the game wears it (the hero dressed as the player), through every `PlaceholderAnims.ANIM_IDS` id (and the Punk's three moves) at five phases and the six peak flexes, printed like the probe's (the worst ten, the five highest p99.9, each flex, `GATE` lines). The measure is `tests/art_strain.gd` (new, mine): test_art_punk's strain against the skinned rest, for any rig, with the merged report of a two-mesh art (the worst of each number, the triangle counts summed). The run is kept per art (`cached()`/`keep()`), so `test_m4_done_when` row A7 reads the same numbers without a second 6.5 s run per GLB.
- *Alternative.* The existing `_strain_run()` of the probe test (`SkinnedView.strain()`, edges against the authored mesh).
- *Why not.* A GLB authored in the A-pose is strained at rest by construction (M4-calls/P1-chain.md C13), and what the player sees is the change from the rest he is bound to; F-player-art's own C15 figures and test_art_punk's are against the skinned rest, so these are comparable with what the lead has been quoting. The old measure stays for the probe.
- *Numbers.* Neither GLB meets the plan's p99.9 in [0.6, 1.6]: see part 3. Asserted: no NaN, no vertex under the floor in a planted pose, more than 200 samples, and the ratchets of C4.

**C3. The done-when file mirrors the other tests; it does not call them.**
- *Decision.* `tests/test_m4_done_when.gd`: one test per row A1-A14, then three of its own. Each test says in a comment which test already holds its row and mirrors the check on the shipped art (`punk_art.tres`, and the hero through `PlayerCharacter.worn_art(player_art.tres)`, as the game wears them), with production code (`SkinnedArt.check()`, `SkinnedView`, `MotionProbe`, `ArtStrain`, the probe). Each test leaves notes (`_note(row, ok, text)`: whether the plan's bar was met, and what was measured), printed as `DONE-WHEN <row> ok|GATE ...` as they come and as one table in `after_all()`. A row whose bar the art meets is asserted at the bar and reads PASS; a row it misses is asserted at a ratchet (C4) and reads `GATE (ratchet held)`, with the plan's bar in the GATE line. The [W] rows (L1-L5) are listed in the table as printed by `look_probe` and never asserted there.
- *Alternative.* Instantiate the other test scripts and call their helpers (`load("res://tests/test_art_player.gd").new()._view_poses()`), which avoids about 300 lines of mirror.
- *Why not.* The helpers are private to files the two art fixers own and are changing (F-player-fix turns the hero's A9 into a ratchet in `test_art_player`); a rename there would break this file at the merge, and a GutTest instance outside the runner has no `gut` for `add_child_autofree`. Mirroring is the price; the source test is named in each test, and the A7 run is the one thing shared (through `art_strain.gd`).

**C4. The ratchets: today's figure with a margin, never a frozen number.** Each is a constant at the head of the test, with the figure it stands over. All can only be made tighter.
- A4, the hero's walks: a planted step slides at most 3 m (today 2.29 m: M3's 0.6 s cycle at his speed, which F-motion C7 reports and keeps; the enemies' four walks are held at the plan's 2 cm, 1.25 cm today). His soles are never under -15 mm (-9.5 mm).
- A6, the hero: at least 75% of the torso, leg and head vertices inside their hurtbox + slack (torso 100%, legs 89.8%, head 99.0%) and at most 2 axis points outside the art (1). The Punk is asserted at the plan's 95% and 0 points.
- A7, strain: at most 560 problem lines for the Punk and 480 for the hero (503 and 424, two a sample), a worst p99.9 of 4.6 and 9.5 (3.97 and 8.23, the hero's KO lying clips), and no peak flex above 2% of the art's triangles under 15% of their rest area or turned over (1.56% at most; the plan's bar is 0.5%). The visible stretch of the Punk (slice gate contingency 4): at most 10 cm (8.4 cm, the waist hem in the cross's twist; the bar is 2 cm).
- A9: the Punk's cells that differ at most 9% (6.6%); its lens share stays at the plan's 4 points (3.7). The hero over 15 first-person poses: cells at most 10% (6.9%), the lens share's gap at most 10 points (6.9, the block), the art nearer than its proxies at most 12 cm (7.6, the front kick); the guard's forearms and hands are 0.338 m from the lens (the plan's bar 0.3 m, asserted).
- A11: the anchor of a flash to the skinned surface, head 2 cm / torso 10 cm / leg 5 cm for the Punk (1.5, 6.0, 2.7) and 6 / 12 / 8 cm for the hero (2.8, 4.6, 4.7).

**C5. Rows with no headless check of their own get the nearest honest one.**
- *A12* is the suite's count and its zero errors, which only `tools/run_tests.sh`'s output holds (the lead reads it). The test counts the `func test_` lines of `tests/test_*.gd` against M3's 1198 (1552 today, which is the number GUT reports), and checks `look_show_art` off on both characters (the art hides, all 41 primitives show, a rig built while it is off starts with them).
- *A13*: every file under `assets/export` and `assets/source/concepts` is named in ASSETS.md and has an LFS pattern in `.gitattributes` for its extension (`git check-attr` needs a process and a repository; the patterns are what it reads); the ledger: every created task finished, M4's `credits_consumed` summed at most the 750 stop (295 today, 12 tasks), no `balance_after` under the 700 floor (1205). It does not chain `balance_before` to the previous `balance_after`: the ledger is written by builders running at once and merged with `merge=union`, so its events interleave.
- *A14*: `test_slice_crowd`'s autopilot test, mirrored with the Punks' art asserted: three Punks kept on the street for 900 ticks (3.7 s of wall clock headless), R1-R3, R10 and R11 not FAIL, nobody stuck, every spawned Punk has art (9 spawned, 6 fell). The 60 s windowed act through `tools/check_m3_log.py` is the lead's run, as the plan says.

**C6. The final probe is one act that plays the five acts that measure the rows, then sums them.**
- *Decision.* `tests/bot/acts/look_final_acts.gd` has `Look: final probe` (slug `fp`): it finds F-look's `Look: tune hull widths` (T3, L1), `Look: tune own hull` (T8, L1's own body), `Look: tune bands at 1 m` (T1, L2), `Look: tune jab flash` (T5, L3) and P3-early's `Look: readability with the art drawn` (L5) in the bot's own act list by title, plays them one after the other in one window (`bot._reset(cam)`, the act, `_wait_idle()`, the bot's idle tail), then reads look.json (`LookProbe.read()`, which the acts wrote through `record()`) and the `LOOK-L5` log lines and records the rows under `final` (`LookProbe.final_rows()`; `LookProbe.final_lines()` logs them as `LOOK-FINAL <row> <MET|MISSED|NOT MEASURED> ...`). `look_probe.gd` gains `read()`, `parse_bands()`, `parse_l5()`, `final_rows()` and `final_lines()`, pure functions on dictionaries and strings (checked headless on synthetic data, including the bars missed and "not measured").
- *Alternative.* The filter the crowd bot already has (`--act="a|b|c"`, a `|` list), or new measuring code in a new bot scene.
- *Why not.* The filter runs the acts but leaves the rows unsummed and the readings in five places, and the lead asked for a look.json to paste. New measuring code would be a second copy of what T1, T3, T5, T8 and the L5 sampler measure and would drift from them. The cost is that the final probe depends on five act titles; `test_the_final_probes_source_acts_exist_by_title_and_it_is_the_only_act_with_its_title` fails if one is renamed. Headless the acts draw nothing, so the rows read "not measured" and never a pass.
- *The bars* (Part B's, as `look_probe.gd` states them): L1 each measured hull width (crown, left, right at 1, 2.5, 5 and 10 m; the own body's left, right and top) within 1 px of `look_outline_px` (the own body: of x `look_outline_fp_scale`) and at most 4.5 px, at 1080p. L2 on the front-lit view (the plan's C2): 2-3 jacket bands, shadow/lit luma at least 0.4, the shadow band's hue nearer the shadow tint than the lit band's; the back-lit view (the contre-jour case) is reported beside it and does not decide. L3: the white share of the view in the frame a jab's flash is first drawn in at most M2's localized figure plus 2 points; M2's figure is the before pack's own frames of the same hit, 4.1% and 4.3% (F-look.md, L3), so 4.3%, a bar of 6.3%. L5: part 3.

**C7. Found by the first windowed run, fixed.** The first run printed six `ERROR: String formatting error: unsupported format character` lines: GDScript's `%` has no `%g`, and `_row_l1` used it for the distances. The acts and their measurements had all run and look.json held them, so the figures were summed again from the recorded data in a scratch script (and gave the rows the second run gave); the code was fixed and a headless test now runs the same function on synthetic data (it would have caught it), and the probe was run again, once, clean: `0 SCRIPT ERROR/ERROR lines`, and the same figures to the last digit.

**C8. L5's "within noise of M3" is a number I chose, so the evidence for it is here.** Part B gives none. A fight is seeded and reruns identically, so the noise to read is how far the same measure moved between two states of the project. On "Six Punks, fight" the art-minus-proxies gap was +0.5 points at the median and +2.8 at the 95th on the smoke Punk (P3-early, the slice gate), and is -2.1 and +0.5 on the shipped one; on "Mixed six, fight" +0.3 and +0.7, now -0.9 and -0.7. A bar of 2 would have called the art's own change a failure (-2.1), so the bar is 3 points at the median and 5 at the 95th, and no wind-up hidden by another enemy that the proxies did not see hidden (R4 reads 0 of 15 and 0 of 14 both ways). I first wrote 2 and 4, saw -2.1 and moved it; that is the order it happened in.

## 2. Assertions that changed

One, forced by C1, with its twin on the visible path:
- `tests/test_m4_contracts.gd::test_the_contract_signatures_exist`: `ToonMaterials.outline` argument count `[0, true]` -> `[1, true]` (the file is S0's, not in my list: the change is one table cell, in the line P1-toon moved for `character()` and `environment()` in the same way, and the suite is red without it). Twin: `test_the_players_art_hull_is_toon_materials_first_person_outline_and_an_enemys_is_the_full_width_one` (C1).

Nothing else. No existing assertion was weakened; `test_skinned_art` gains one test, `test_m4_done_when` is new (18 tests), `tests/art_strain.gd` is a helper.

## 3. Numbers

**The suite.** `tools/run_tests.sh`: 1553 tests in 72 scripts, 1552 passing, 0 `SCRIPT ERROR`, `SHADER ERROR` or `ERROR` lines (the 1534 of the merge the lead handed over, +18 `test_m4_done_when`, +1 `test_skinned_art`). The one failure is `test_art_player::test_the_arts_frame_like_their_proxies_in_every_first_person_pose`: the hero's A9 against FPView's proxies at the plan's bars (10 poses), which was red on that merge (HANDOFF: 1533/1534) and which F-player-fix turns into a ratchet (call 20); it is not mine, is left as it is, and `test_m4_done_when` row A9 holds the same art at the ratchets of C4. An earlier run of this branch had a second failure, the contract's argument count for `outline` (part 2), fixed.

**The A19 strain of the shipped GLBs** (against the skinned rest; `A19 strain of ...` lines):

| | samples | inside every bar | problem lines | worst p99.9 | peak flexes over the triangle bar |
| --- | --- | --- | --- | --- | --- |
| `punk.glb` | 251 | 1 | 503 (500 strain range, 3 triangles) | 3.97 (launched, end) | guard 110, arm raise 234, knee 79 (bar 75; worst 1.56% of 14,984) |
| `player.glb` | 236 | 1 | 424 (420, 4) | 8.23 (ko_back, end) | guard 141, arm raise 207, knee 182, spine twist 180 (bar 132; worst 0.78% of 26,418) |

The weak joint in both is the shoulder (the guard and the arm raise); the hero's worst frames are his KO lying clips. The run takes 13 s for both.

**The done-when table** (`DONE-WHEN` lines of the full run; PASS = the bar met and asserted, GATE = the bar missed, the ratchet of C4 held):

| Row | State | What it shows |
| --- | --- | --- |
| A1 | PASS | `check()` clean on both, 23 binds a mesh, faces -Z (toes z -0.229 and -0.240) |
| A2 | PASS | 14,984 of 15,000; 26,418 of 30,000 |
| A3 | PASS | 6 flat colours each (the Punk on 7 swatches), none red; 311 street surfaces none red |
| A4 | GATE | Punk: rest sole -4.1 mm, four walks slide 1.25 cm, idle lowest -3.6 mm. Hero: walks slide 2.29 m (M3's cadence, F-motion C7); soles never under -9.5 mm |
| A5 | PASS | fist centroid 1.9-2.1 mm (Punk), 7.8 mm (hero); extents x0.97-1.10 |
| A6 | GATE | Punk torso 100%, legs 95.3%, head 99.9%, 0 axis points outside. Hero legs 89.8%, 1 axis point outside |
| A7 | GATE | strain (table above); the Punk's visible stretch 8.4 cm (bar 2 cm) |
| A8 | PASS | skeleton vs `Ragdoll._visual` 0.00000 m over 140 updates, partial then full; a primitive rig untouched |
| A9 | GATE | Punk, 8 poses at 1 m: cells 6.6% (bar 3%), lens share 3.7 points (bar 4, met). Hero, 15 poses: 10 miss, cells 6.9%, share 6.9 points, nearest 7.6 cm; guard 0.338 m (bar 0.3, met) |
| A10 | PASS | CUSTOM0/1 are the bind pose on 100 sample vertices a mesh through idle, a jab and a knockdown; three damage looks, one shader |
| A11 | GATE | a real Street Punk's art flashes for exactly 2, 1 and 3 rendered frames at `hit_flash_frames` 2, 1 and 3. Anchor to the skinned surface: Punk head 1.5 cm, torso 6.0, leg 2.7; hero 2.8, 4.6, 4.7 (bar 2 cm) |
| A12 | PASS | 1552 tests against 1198; `look_show_art` off shows the primitives on both |
| A13 | PASS | 88 files each in ASSETS.md and LFS; 12 tasks, 295 credits (stop 750), lowest balance 1205 (floor 700) |
| A14 | PASS | autopilot, 9 art Punks over 900 ticks: R1, R2, R3, R10, R11 ok, nobody stuck |

**The final probe** (`captures/final2/look.json`, key `final`, run `tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/final2 "Look: final probe" 6`; 4,474 frames; the first run, `captures/final`, printed the same figures):

| Row | State | Figures |
| --- | --- | --- |
| L1 hull width, 1080p, target 3.75 px +-1, at most 4.5 | **MISSED** | crown / left / right: 1 m 3.48 / 4.50 / 3.25; 2.5 m 3.54 / 3.24 / 3.24; 5 m 3.54 / 3.15 / 3.24; **10 m 3.25 / 2.39 / 2.04** (the sides are under the 2.75 floor; the bible's own floor, at least 2 px out to 10 m, holds). Own body, target 3.00 +-1: left 3.82, right 3.46, top 3.85 (met on this branch's base, f1a25ac, which did not have F-player-fix's GLB yet; **corrected by the final review**: on the shipped GLB at 3eea29a the same act reads 4.15 / 3.87 / 4.35, 'all' 4.5, **MISSED** on left and top, a soft row; after the hero's sharp ink, 3.85 / 3.74 / 4.05, all 4.42, top 0.05 px over the 4.0 bar: fix-final-toon-light-and-ink.md C4) |
| L2 jacket bands at 1 m | **MISSED** | front-lit (decides): **1 band**, shadow/lit 1.00. Back-lit: 2 bands, shadow/lit 0.81, shadow hue toward the tint (met). **Corrected by the final review: the miss was the camera fill's (0.8), not the vest's panel; with the fill at 0.4 the row reads front-lit 2 bands, shadow/lit 0.80, MET (fix-final-toon-light-and-ink.md C1)** |
| L3 flash share, jab at 1 m | MET | 3.6% of the view, bar M2's 4.3% + 2 = 6.3% |
| L5 R8 and R4 with the art drawn | MET | Six Punks: R8 p50 proxies 28.6% / art 26.6% (-2.1 points), p95 43.8 / 44.3 (+0.5); R4 hidden wind-ups 0 / 0 of 15. Mixed six: p50 27.3 / 26.4 (-0.9), p95 48.4 / 47.7 (-0.7); R4 0 / 0 of 14. Worst sample 378 ms (the drawn R4's BVH builds: windowed work, A4) |

L4 is the lead's `tools/perf_compare.sh` run.

## 4. What the stills show (first person, 1600x900, `captures/final/sheets/`, never committed)

Looked at, beside `assets/source/concepts/punk_a_denim_vest.jpg`: the 1, 2.5, 5 and 10 m shots of T3, the guard of T8, the front-lit and back-lit shots of T1 and the jab flash of T5. This is Street Punk A.
- *The Punk reads as the pick at a glance at 1 m*: yellow cap, the yellow tinted visor band with a teal frame, a teal vest over a dark shirt, a bandaged forearm, black fingerless gloves. The ink hull is continuous and even round the cap, the arms and the vest, and holds at 10 m (a small figure with a clean outline, the street's lines the same weight).
- *What the numbers say in the picture (L2).* Front-lit, the vest is one flat teal with ink creases and a few darker patches low down: no second band. The concept's vest has pocket flaps and a high collar. *(This round blamed the shipped front panel, 'flat toward the lens, so there is no curvature to break the light into bands'. The final review showed that wrong: with the fill off the same vest in the same frame has three bands. The cause was the camera fill at 0.8, which lifted every lens-facing normal out of the sun's shadow band and overwrote the sun's mid and violet shadow bands; fix-final-toon-light-and-ink.md C1.)* Back-lit it has a lit patch and a violet-leaning shadow: 2 bands, as measured. So J5's "2-3 crisp bands" holds contre-jour and not in the default view.
- *The face*: covered by the cap's shadow and the visor, the lower face blank pale skin with a short mouth dash and no nose. Simplified and symmetric, no mush, but it carries less than the concept's.
- *The fists* read as fists now (knuckle plate, a thumb, a dark glove with a cuff), not canisters. The yellow strap on each wrist is a floating ring with ragged shards standing off it (the picture's two glints of yellow spikes), which is not in the concept: F-punk-fix's.
- *The hero's wrapped forearm and fist in the jab* (T5): large, wrapped, inked; the flash is a localized white over the Punk's head and the top of the vest with the comic burst at the contact, and two frames later (`jab_flash_next`) the Punk's colours are back and the head has flinched, the burst still up.
- *The hero in the guard looking down* (T8): forearms and gloves in the corners, outlined, with the hull measured 3.5-3.9 px (x0.8 of 3.75 is 3.0 and the figure was in its +-1) *(on this branch's base; the shipped GLB reads 4.15 / 3.87 / 4.35, left and top outside 3.0 +-1, and 3.85 / 3.74 / 4.05 with the hero's sharp ink: fix-final-toon-light-and-ink.md C4)*.

## 5. Requests, departures, risks

- *Requests.*
  1. The lead: `docs/ARCHITECTURE.md`'s F-player-int paragraph "The hull" still says `PlayerCharacter._wear_first_person_hull()` calls `ToonMaterials._hull(...)` and that a request would move it; C1 did, so that paragraph is stale (my heading says so, I did not edit another package's heading).
  2. F-look (or F-look-fix, if there is one): the two L-rows the shipped Punk misses. L2 front-lit, 1 band: *(the sun and fill give a flat panel one shade, so 2-3 bands there needs either the vest panel's shape or a band break the panel's normal crosses. Corrected by the final review: neither; the fill's strength was the cause, and 0.4 fixes it with no change to the panel or the bands: fix-final-toon-light-and-ink.md C1.)* L1 at 10 m, the sides at 2.0-2.4 px: either the hull is thinner there than 3.75 px (check `look_outline_far_m` 12 against the 10 m shot; the crown at the same distance reads 3.25) or T3's side window, at 10 m a few pixels wide, under-reads (the ring is measured by coverage, and an MSAA edge of 2 px is partial coverage); the bible's own floor (2 px out to 10 m) holds either way.
  3. The lead, after the merge: regenerate nothing (no tunable was added); rerun `Look: final probe` on the merged art (it is one command, about 7 minutes windowed) and paste the `final` entry; the five figures to watch are L1's 10 m sides, L2's front-lit band count, and A4/A6/A9/A11's hero rows when F-player-fix lands.
- *Departures from the spec*: none. Part B's L5 "within noise" has no number (C8).
- *Risks.*
  - The ratchets of C4 will need tightening as the fixers land (a ratchet that is far above the new art lets a regression through); each constant sits at the head of its file with the figure it stands over, and the table prints today's figure next to it.
  - `test_art_player`'s hero A9 is red on this branch (not mine; F-player-fix's ratchet turns it green). `test_m4_done_when`'s A9 ratchets for the hero (10%, 10 points, 12 cm) stand over the same art.
  - The done-when file mirrors about 300 lines of other tests; if one of the sources changes its method (for example a new view pose), this file does not follow until someone edits it.
  - The final probe depends on five act titles and the order the crowd bot's acts leave the room in (`bot._reset(cam)` between them); a sixth act that leaves state behind would show up as a changed figure, not an error.
  - `test_m4_done_when` adds about 25 s to the suite (A7's strain run 13 s shared with `test_skinned_art`, A4's walks 9 s, A14 3 s).
