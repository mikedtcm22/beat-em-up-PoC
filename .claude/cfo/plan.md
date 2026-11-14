# CFO plan: beat-em-up-PoC · the trailer's look, playable (Milestone 7, proposed)

plan `trailer-art-m7` · created 2026-11-10 · session: Fable at medium (design and gate rows only) · Ultracode off except for the two workflow rows

Design, gates and owner questions: [docs/milestones/M7-trailer-look-plan.md](../../docs/milestones/M7-trailer-look-plan.md). **Approved by Game-boy 2026-11-11** (Ox keeps his M6 colouring; spend approved).

## Execute

Follow this for every row, in order, respecting Depends.

1. **Start.** Run `python3 ~/.claude/cfo/cfo.py start <ID> <class> <mode> <model> <effort>` (use `session` as the model for inline and fork rows).
2. **Run it in its mode.**
   - **inline:** do it yourself. If the row's effort is above the session's, first invoke the `effort-high` or `effort-xhigh` skill.
   - **fork:** Agent tool with `subagent_type: "fork"` and the row's effort.
   - **delegate:** Agent tool with `cfo-worker` (`cfo-scout` for read-only), using the row's model and effort.
   - **packet:** one `cfo-worker` for every row sharing the packet letter.
   - **parallel:** one Agent call per piece, all in the same message.
   - **workflow:** don't start it. Tell the user: "Next up is <ID>, a workflow task. To run it, send: ultracode run <ID> from .claude/cfo/plan.md".
3. **Brief subagents.** Every brief opens with its tag on line 1, `[cfo task=<ID or IDs> class=<class> model=<model> effort=<effort>]`, then follows the template in the cfo-plan skill's classes reference. Point to files instead of pasting them.
4. **Verify, then close.** Run `python3 ~/.claude/cfo/cfo.py done <ID> pass|fail|user [short note]`. Use `user` when only the user can judge the result (feel, visuals, audio). Usage is metered automatically.
5. **If it fails,** retry once at the same level with a sharper brief. If it fails again, go one level up and add a line to the Log. Never skip levels, and never use max without asking.
6. **Tick ✓** in the table. When the session's work stops, list any `user` rows so the user can check them.

Project rules that apply to every row: worktrees made by hand under `.worktrees/` (one per parallel builder, each with its own import); disjoint files per builder; read the video branch with `git show video/cinematic-trailer:<path>`, never write in `.worktrees/video` or `.worktrees/mv-*`; check `get_usage` before each launch and the capture lock before recording; HANDOFF.md updated at each phase boundary.

## Tasks

Owned files are exclusive within a phase. **T11 is the only row that edits `game/fx/toon*.gdshader`, `toon_light.gdshaderinc`, `trim*.gdshader` and `toon_materials.gd`;** other builders hand it a list of uniforms they need. Rows that spend Gemini or Tripo also depend on Game-boy's yes to the milestone plan §5 question 4, and their done-when includes the ledger row (credits and dollars).

### Phase 0: lock the target

| ID | Task | Class | Mode | Model | Effort | Pkt | Depends | Done when | ✓ |
|---|---|---|---|---|---|---|---|---|---|
| T00 | Check the usage watcher is running; create `m7/trailer-look` from the agreed base; add README's "Where M7 departs from the spec" section with the approved departures | mechanical | delegate | haiku | medium | | go | branch pushed; README section lists each departure with Game-boy's words |✓ |
| T01 | Look target sheet: canonical frames per character and place, palette per area, do-not-copy list (`docs/milestones/M7-look-target.md` + one contact sheet) | design | inline | session | high | | go | user: approves the one-page sheet |✓ |
| T02 | Copy trailer frames, keyframes and plates into `assets/source/trailer_ref/`; ASSETS rows | mechanical | delegate | haiku | medium | | go | files listed in ASSETS.md; nothing under `.worktrees/video` changed |✓ |
| T03 | Port the blind-judge protocol and `style_meter.py` to `tools/look/`: a fixed prompt, a fixed frame set (at least 20 trailer frames, 8 references, M6 frames), all at the same encode, 3 runs. Score the trailer and M6 to set the bar | media | delegate | sonnet | medium | | T02 | the bar and its spread are in the Log; if the spread is over 0.10, T16 sets the threshold |✓ |
| T04 | List the tests, fixtures and warm-cache paths that pin M6's look, with the pinned value each | scout | delegate | haiku | low | | go | the list, by file |✓ |
| T05a | `look_profile` tunable (`m6`/`trailer`) and debug key; lights, sky, fog, post and effects resolved through it; `m6` unchanged | integration | delegate | sonnet | high | | T04 | suite 2076/2076 under `m6`; the key switches profile in play with no errors |✓ |
| T05b | Art swap by profile through `skinned_art`/`character_art`: a second GLB and material set per character (new UV2, optional new mesh and skeleton binding), `warm_up` covering both profiles | integration | delegate | sonnet | high | | T05a | a fixture character swaps mesh and materials on the key with no hitch frame over the M6 spawn bar; suite green |✓ |

### Phase 1: the slice (the Punk and the player's arms, one stretch of night street)

| ID | Task | Class | Mode | Model | Effort | Pkt | Depends | Done when | ✓ |
|---|---|---|---|---|---|---|---|---|---|
| T10 | Night-street light: colour script, painted sky and skyline cards, lamp pools and halos, contact shadows, haze band (ported from the video branch's `video/look/street_night`, `sky_painted`, `contact_shadow`, `haze_band`). Owns `game/level/` light and sky files only | feature | parallel | sonnet | high | | T05a | stills sit inside the style meter's bands for the street; figures keep a readable mid tone; tests pass |✓ |
| T11 | Shader owner: the `painted` path in the toon shader (paint and ink maps, ported from `cine_toon`), damage class and gloss kept through a mask channel, no light added in the shadow band at night, hull ink with painted weight and taper, one-sided designed rim, grain on fills | feature | parallel | sonnet | high | | T05a | a painted fixture shows damage marks and glint as M6 does; outline width varies along a limb; no shader variant compiles mid-fight; tests pass |✓ |
| T12 | Punk arm A, assets only: port `blender_asset.py` (fresh UV2 with texel-density weights, face normals) and `art_paint.py` from the video branch; Gemini supplies the palette, material swatches, face and fold reference for the canonical Punk (at most 12 images); the face stays on the drawn-SVG route; projection only on the torso front and back | media | parallel | sonnet | high | | T01, T05b | the Punk loads in the `trailer` profile with a drawn face; 8 turnaround stills and a 2 s moving clip show no seams or sliding paint | |
| T13 | Punk arm B: a new Tripo Punk from the canonical design (55 credits) with articulated fists, rigged through the existing chain, painted as T12 | media | parallel | sonnet | high | | T01, T05b | as T12 on the new mesh; Tripo ledger updated | |
| T14 | Player arms and gloves in first person: new UV2 (the current one has sliver islands), painted sleeves and stitched gloves, smoothed near forms. Owns player art files only | media | parallel | sonnet | high | | T01, T05b | first-person stills at guard, jab and hook show no black holes, facets or slivers | |
| T15 | Street stretch surfaces: Gemini-painted trim and ground sheets (at most 20 images), module variation to break exact repeats. Owns the kit's sheets and generators | content | parallel | sonnet | high | | T05a | the stretch shows no M6 texture in the `trailer` profile; colliders fixture unchanged |✓ |
| T16a | Street effects: outlined steam flipbook, burn barrel with flipbook flame, embers | content | parallel | sonnet | medium | | T05a | effects play in the stretch; overdraw measured |✓ |
| T17 | Merge the branches (T11 first); suite under both profiles; record the slice acts once with `tools/record_acts.sh`. Handoff point: update HANDOFF here | integration | delegate | opus | high | | T10-T16a | suite green under both profiles; `captures/m7-slice/` holds both arms | |
| T18 | Lead's look at full-size stills; pick arm A or B; set the judge threshold if T03 left it open; fix list of at most 3 packages | design | inline | session | medium | | T17 | the pick and the list in the Log | |
| T19 | Blind judge by T03's protocol on third-person and first-person stills and 2 s clips; frame time by the M6 method (interleaved, 4 runs, vsync on, load recorded) | verify | parallel | opus | medium | | T17 | p_3d within the threshold for both views; frame time at most +10% over M6 | |
| T20 | One fix wave from T18 and T19 | feature | parallel | sonnet | high | | T18, T19 | each finding re-checked in a new still; suite green | |
| T21 | Gate 1: side-by-side reel and the run command to Game-boy. If arm B won, ask for the Tripo top-up here | verify | inline | session | medium | | T20 | user: plays the slice; go, adjust or stop | |

### Phase 1b: the adjust round (Game-boy, 2026-11-11: "Adjust: one more round")

| ID | Task | Class | Mode | Model | Effort | Pkt | Depends | Done when | ✓ |
|---|---|---|---|---|---|---|---|---|---|
| T22 | Four packages in their own worktrees: G1 shader owner (damage-blotch bug, hand-drawn line and rim, post wobble and softness), G2 character paint with Gemini (faces, folds; arm A), G3 street surfaces with Gemini (sheets, brick, chain-link), G4 light shapes (pools, windows, wisp) and the arms acts moved to the street | feature | workflow | sonnet | high | | T21 | each finding re-checked in a new still beside the trailer frame; Gemini ledger rows |✓ |
| T23 | Merge G1-G4; full suite under m6 | integration | workflow | opus | high | | T22 | suite green; pushed |✓ |
| T24 | Frame-time pass on the merged branch: measure per feature, cut to at most +10% over M6 | feature | workflow | sonnet | high | | T23 | interleaved 4-run medians within +10%; touched tests pass |✓ |
| T25 | Re-record the slice into `captures/m7-slice/merged3/`, final frame time, three blind judge sets, HANDOFF | integration | workflow | sonnet | high | | T24 | stills, clips, INDEX, `judge3/run1..3`, keys moved out |✓ |
| T26 | Blind judge x3 and scoring | verify | workflow | opus | medium | | T25 | per-group medians and tells | |
| T27 | Gate 1b: reel and numbers to Game-boy; if the judge is still near M6, propose stopping the painted route | verify | inline | session | medium | | T26 | user: go or stop | |
| T28 | Route spikes after Game-boy's "Propose a new route" (2026-11-13): S0 full-frame Gemini repaint (the trailer's own method, the ceiling), S1 drawn sprite characters and arms, S2 camera-projected painted street, S3 = S1 + S2; same four moments each; branches `m7/spike-s1`, `m7/spike-s2`, not merged | media | workflow | sonnet | high | | T27 | four stills per route in `captures/m7-slice/spikes/`, a walk-cycle clip for S1, an off-vantage still for S2 | |
| T29 | Blind judge x3 on the spikes and scoring; the lead's route proposal with samples | verify | workflow | opus | medium | | T28 | per-route medians; user: picks a route or stops | |

### Phase 2: the roll-out (after Gate 1) — SUPERSEDED 2026-11-13, not run; replaced by Phase 3

Run through `tools/workflows/build.js` with `concurrency: 4`. Check `get_usage` before each wave; each wave ends in wip commits and a HANDOFF update.

| ID | Task | Class | Mode | Model | Effort | Pkt | Depends | Done when | ✓ |
|---|---|---|---|---|---|---|---|---|---|
| T30 | Wave 1, 4 pieces: (a) Thug and Bruiser, (b) Kicker, (c) Ox with hatching and face, (d) rest of the street and its props | media | workflow | sonnet | high | | T21 | each piece loads in the `trailer` profile, its tests pass, stills attached, ledgers updated | |
| T31 | Wave 2, 4 pieces: (e) dusk roofs with sun-disc sky, (f) boss roof with fire wall and embers, (g) effects: speed lines, impact frames, smears on twos, (h) HUD, titles, Ox name card, debug line removed | media | workflow | sonnet | high | | T30 | as T30 | |
| T32 | Crowd and training rooms adopt the profile | mechanical | delegate | haiku | medium | | T31 | both rooms load in the `trailer` profile with no M6 material | |
| T33 | Merge the waves; suite under both profiles; record the round's acts once | integration | delegate | opus | high | | T31, T32 | suite green; `captures/m7-final/` recorded | |
| T34 | Lead's look at full-size stills | verify | inline | session | medium | | T33 | notes in the Log | |
| T35 | Review round through `tools/workflows/review.js`: 3 Opus visual lenses (characters and arms; world and light; effects and motion), 1 Sonnet code lens, Sonnet skeptics on medium and high only; lows go to the lead's triage; image budget 30 | verify | workflow | opus | high | | T33 | findings file in `docs/reviews/M7/` | |
| T36 | One fix wave, at most 3 packages | feature | parallel | sonnet | high | | T34, T35 | each finding re-checked in a new still; suite green | |
| T37 | Re-check of the changed items only; blind judge and frame time for the three areas | verify | parallel | opus | medium | | T36 | no medium or high left; T19's gates hold | |
| T38 | README departures completed, ASSETS rows, look bible addendum | content | delegate | sonnet | medium | | T37 | `--check` rebuilds pass; every new asset has its row | |
| T39 | HANDOFF, PR, Gate 2: reel and run command to Game-boy | verify | inline | session | medium | | T38 | user: plays Mission 1 in the trailer look and signs off | |

### Phase 3: comic-book 3D (replan 2026-11-13; approved by Game-boy 2026-11-13, "Approve, start")

The bar changes. Not "a still can't be told from the trailer", which nothing playable reached, but: a clean cel-shaded 3D brawler with the trailer's night mood, and real drawn art at the moments where the camera is fixed. The gate is Game-boy's eye on a side-by-side reel and a play session; the blind judge is retired (it could not rank any route). Characters stay 3D (ragdoll, 60 Hz animation, damage marks kept). Ox keeps his M6 colours. No Tripo. Gemini at most $24 of the about $26 left. Builders work in hand-made worktrees `.worktrees/m7-c<N>` on `m7/c<N>`, disjoint files, one godot recording at a time.

#### 3a: the clean slice (the Punk, the player's arms, Mission 1's first street arena)

| ID | Task | Class | Mode | Model | Effort | Pkt | Depends | Done when | ✓ |
|---|---|---|---|---|---|---|---|---|---|
| T40 | Target note `docs/milestones/M7-comic-3d.md` (one page): the character recipe (flat fills, one hard shadow shape per form, bold face, thin warm rim on the key side, no grain on figures), the list of drawn-card moments, the fence and window choice; README "Where M7 departs from the spec" updated with what Game-boy approved | design | inline | session | high | | go | the note and README section exist; each departure quotes his approval |✓ |
| T41 | Find why Punks' faces show a purple blotch under the trailer profile (ruled out: the damage look, the key light's cast shadow). Fix it and pin it with a test | debug | delegate | opus | high | | go | cause named; `street_05` and `punk_turn_01` re-recorded with no blotch; test added | |
| T42 | Shader cleanup, sole owner of `toon_painted*`, `paint_grain`, `edge_finish`, `toon_materials.gd`: drop grain and line breaks on figures, quantise the shade term to one hard edge, keep swelling line weight, thin warm rim on the key side only, blob contact shadow in place of the crisp cast shadow on figures | feature | parallel | sonnet | high | | T41 | stills at `street_05`, `arms_03`, `punk_turn_01..08` show flat clean fills and one shadow edge; M6 profile pixel-identical; touched tests pass | |
| T43 | Punk and player-arm maps repainted clean: flat local colour, the face taken from the S1 spike's drawings (`captures/m7-slice/spikes/s1/work/gem`) projected front and three-quarter, scribble shadow patches and sleeve dashes removed, gloves with clear finger lines. Gemini at most $4 | media | parallel | sonnet | high | | go | face readable at fight distance and at 45 degrees; `test_trailer_punk`, `test_trailer_player` pass; ASSETS ledger row | |
| T44 | Street tells: the chain-link lattice swapped (trailer profile only) for a simple drawn fence of bars or boards with a few painted gaps; window rows broken up in the trim sheet itself (lit, dark, boarded, offset); lamp halos stepped. Gemini at most $3 | content | parallel | sonnet | high | | go | `street_01..08` show no regular lattice and no even window row; colliders fixture passes; `gen_trailer_kit --check` ok | |
| T45 | Cut-in system (presentation layer only): a `CutIn` node that shows a full-screen drawn card for a tunable hold on four events: mission title, enemy type's first entrance, arena-clearing knockout, mission end. Reads `CombatEvents`, uses `TimeController` for the hold, skippable, off under the M6 profile; placeholder images | feature | parallel | sonnet | high | | go | each card fires once at its event in a bot act; no game state written; tests for trigger, hold, skip and the M6-off case pass | |
| T46 | The slice's drawn cards by Gemini repaint of game stills (the method that worked on single frames): mission title card, Punk entrance card, two knockout panels. 1600x900, HUD-free. At most $3 | media | delegate | sonnet | medium | | T45 | four cards load through T45; ASSETS ledger row; a sheet of the four for the lead | |
| T47 | Merge c-branches (T42 first); full suite under M6; frame time by the perf3 method; record the slice once as a three-way reel: M6, the old trailer look (`merged3`), the new look; HANDOFF updated | integration | delegate | opus | high | | T42-T46 | suite green; trailer profile within +10% of M6; `captures/m7-comic/slice/` holds stills, clips, reel | |
| T48 | Lead's look at full-size stills and the reel; fix list of at most 3 packages | design | inline | session | medium | | T47 | list in the Log | |
| T49 | One fix wave from T48 | feature | parallel | sonnet | high | | T48 | each item re-checked in a new still; suite green; reel re-cut | |
| T50 | Gate 3: the reel and the run command to Game-boy | verify | inline | session | medium | | T49 | user: plays the slice with F7; go, adjust or stop | |

#### 3b: the roll-out (after Gate 3)

One workflow row, run in two waves of five so the 8 GB machine records one at a time. Check `get_usage` before each wave; each wave ends in pushed commits and a HANDOFF update.

| ID | Task | Class | Mode | Model | Effort | Pkt | Depends | Done when | ✓ |
|---|---|---|---|---|---|---|---|---|---|
| T51 | Ten pieces. Wave 1: (a) Thug, (b) Bruiser, (c) Kicker, each through the T43 recipe; (d) Ox, cleanup and bold face only, M6 colours kept; (e) the rest of the street and its props. Wave 2: (f) dusk roofs, light and painted sky; (g) boss roof with fire wall and embers; (h) crowd room, training room and dummy; (i) the full card set: entrance cards for Thug, Bruiser, Kicker, Ox's name card, knockout panels per type, mission end card; (j) HUD restyled to match, debug line removed. Gemini at most $14 in all | media | workflow | sonnet | high | | T50 | each piece loads under the trailer profile, its tests pass, stills attached, ledger rows added | |
| T52 | Merge both waves; full suite under M6; frame time on street, roofs and boss roof; record Mission 1 end to end once | integration | delegate | opus | high | | T51 | suite green; each area within +10% of M6; `captures/m7-comic/final/` recorded | |
| T53 | Make the new look the default and keep M6 on F7: fix the tests that assume an M6 start (41 failed when last tried) without weakening them | integration | delegate | sonnet | high | | T52 | suite green starting in either profile | |
| T54 | Review through `tools/workflows/review.js`: 2 Opus visual lenses (characters and cards; world, light and effects), 1 Sonnet code lens, Sonnet skeptics on medium and high findings only; image budget 24 | verify | workflow | opus | high | | T53 | findings file in `docs/reviews/M7/` | |
| T55 | Lead's triage and one fix wave, at most 3 packages | feature | parallel | sonnet | high | | T54 | no medium or high finding left; each re-checked in a new still; suite green | |
| T56 | README departures, ASSETS rows, ARCHITECTURE notes for the cut-in system and the look default | content | delegate | sonnet | medium | | T55 | every new asset has its row; `--check` rebuilds pass | |
| T57 | Gate 4: HANDOFF, PR, the Mission 1 reel and the run command to Game-boy | verify | inline | session | medium | | T56 | user: plays Mission 1 and signs off | |

## Probes

Rows running one level below their class's usual effort to test whether it can get cheaper.

- Phase 3: T48 (design, inline) runs at medium, the probe level the rates table offers for design; T46 (media) runs at medium against the class's graded history at high, because repainting stills is the one media step that already worked first time.

## Budget notes

- 31 rows: 6 inline on Fable (two design calls, four looks and gates), 4 Opus rows (two merges, two judge runs) plus the review workflow, 3 workflow rows, the rest Sonnet builders and Haiku scouts. Fable writes no code.
- The merges (T17, T33) go to an Opus delegate, not inline: the branches and checks are fully named in the plan, and keeping them off Fable follows the owner's rule. If one fails twice it comes inline.
- Estimates, in % of a 5-hour window, from HANDOFF's measured 4 to 7% per Sonnet builder and 5 to 7% per Opus reviewer: Phase 0 about 15%; Phase 1 50 to 70% (seven builders 30 to 45%, merge and judges 15 to 20%, fix wave up to 15%), with a planned handoff point at T17; Phase 2 two to three windows (each wave 20 to 28%, the review round 25 to 35%, fixes and re-check 20%).
- Outside spend: Gemini at most $35 (slice at most $8); Tripo 55 credits in the slice, about 500 more than the 355 left if arm B wins (asked at Gate 1); Runway none.
- Waiting on Game-boy's judgment: T01 (target sheet), T21 (Gate 1), T39 (Gate 2), plus the five questions in the milestone plan §5.

- **Phase 3 (replan 2026-11-13).** 18 rows: 4 inline on Fable (the target note, the lead's look, two gates), 3 Opus rows (the blotch debug, two merges) plus the review workflow, 2 workflow rows, the rest Sonnet. Fable writes no code.
- Phase 3 cost, from what the last two rounds measured (the eleven-agent adjust round moved the weekly meter about 3 points, the eight-agent spikes about 1): 3a about 4 to 5 points of the week, 3b about 8 to 10. The dear rows are T51 (ten builders) and T54 (the review); T53 is the one with unknown size.
- Phase 3 outside spend: Gemini at most $24 (3a $10, 3b $14) of the about $26 left; no Tripo; nothing else.
- Phase 3 waits on Game-boy at: this plan's approval and its three questions, T50 (Gate 3), T57 (Gate 4).

## Log

- 2026-11-10: plan created from five read-only scouts (video pipeline, game art state, handoff rules, visual gap, techniques).
- 2026-11-10: revised after two critics (feasibility, budget and process): the player's arms moved into the slice; the video branch's paint tools named and ported instead of a new projector; the profile switch split into light and art swap; one shader owner; contact shadows and the night light fix added; the judge protocol fixed; the roll-out cut into waves of four; spend rows tied to approval. Awaiting Game-boy's review.
- 2026-11-11: Game-boy approved by Slack DM. PR #6 merged; `m7/trailer-look` cut from main. Ox keeps M6 colour. A Haiku Slack relay and a usage watcher are running. T00 done inline (three commands and a README section; not worth a delegate).
- 2026-11-11: Phase 0 merged (e2da1b7; 2095/2095 on the profile branch). The bar: trailer median p_3d 0.09 (0.05-0.14), references 0.07, M6 0.93 (Ox 0.71-0.75). Gate threshold: median at or below 0.19 (bar + 0.10), spread within 0.10 so no reset needed. Phase 1 order changed to respect the shader contract: T10, T11, T15, T16a in parallel; then T12 on T11's branch; then T13 and T14 on T12's branch.
- 2026-11-11: Phase 1 merged with one fix wave (F1 colour, F2 paint, F3 light shapes). Gate 1 measures FAIL: blind judge cand_street 0.80, cand_arms 0.92, cand_punk 0.88; in the same shuffle trailer 0.35 (0.12-0.55), refs 0.12, m6 0.94. Frame time +22.6% (m6 11.05 ms, trailer 13.55 ms; gate +10%). Arm B built on m7/t13 (55 Tripo credits, $0.42 Gemini), not merged; pick open. Gemini topped up by $35 at 15:53. Top tells: flat mapped faces, ruler-clean outlines, exact chain-link, constant-width rim, tiled brick and windows. Known bug: translucent damage blotches on full-health Punks. Sent to Game-boy for go, adjust or stop.
- 2026-11-12: adjust round (T22-T26) merged, 2172/2172. Frame time now passes: m6 10.90 ms, trailer 10.15 ms (-6.9%). Blind judge still FAILS: cand_street 0.80 (was 0.80), cand_arms 0.80 (was 0.92), cand_punk 0.95 (was 0.88); trailer 0.35, m6 0.90. Top tells: exact chain-link 48, flat mapped faces 43, window rows 30, ruler-clean outlines 20, shadow-map terminators 16. The purple face blotch survives (not damage, not the key's cast shadow). Gemini spend this round about $3.50. Lead's recommendation at T27: stop the painted-asset route.
- 2026-11-13: route spikes (T28, T29). Blind judge: now 0.78, S0 full repaint 0.72, S1 sprites 0.73, S2 projected street 0.75, S3 both 0.73; trailer 0.40, m6 0.90. Even the trailer's own method on our frames fails, so the judge is reading something every game frame shares (HUD panel, first-person framing, street layout) and cannot rank routes. By eye S1 and S3 characters read as drawn. Gemini about $4.6 this step (about $8.5 of $35 so far). Lead's proposal: a playable drawn-sprite Punk slice; waiting on Game-boy.
- 2026-11-13: Game-boy asked what the best trade of art quality and feasibility is if the exact trailer style is relaxed, then asked to see the plan. Phase 2 superseded by Phase 3, comic-book 3D: keep the night street and 3D characters, clean the figures, drawn cards at fixed-camera moments, gate by his eye. Not started; awaiting approval and three answers (the bar, the cut-in cards, the default look).
- 2026-11-13: Game-boy approved Phase 3 as written ("Approve, start"): the bar, the cut-in cards and the default look. T40 done. T41 to T47 run as one workflow instead of separate Agent calls because Ultracode is on in this session; models and efforts are the rows'.
