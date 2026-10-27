# M4 calls: P3-evidence

Package P3-evidence: the evidence pack (M4-plan Part B section B3, A17, A23) recorded and measured on `m4/p3-evidence`, which is the merged head of `m4/art-pipeline` (`6e2a2e1`, both fix waves in). It changes no game file, no test and no tool: the committed part is `docs/reviews/M4/evidence/` (`index.md` and five JSON files) and this file. Every recording, still, crop, clip and montage is in `captures/m4/evidence/` of the worktree (`/Users/arachne/repos/beat-em-up-PoC/.worktrees/m4-p3-evidence/captures/m4/evidence/`, git-ignored, never committed); the index names each by its path under that folder.

Each call is the decision, an alternative not taken, and why. Part 2 is what changed in the repo (nothing but docs), part 3 the numbers the pack stands on, part 4 what the sheets show, part 5 requests, departures and risks. The machine was shared and loaded (load average 5 to 13 during the recordings), so no wall-clock figure here is a measurement of the game; the only timings are the recordings' own.

## 1. Calls

**C1. The feel A/B stills for questions 1 and 2 come from the flash acts' own passes, not from `CAPTURE_ARGS="--tune=..."`.**
- *Decision.* `tests/bot/acts/flash_fp_acts.gd` sets `hit_flash_fp_max_share` and `hit_flash_finisher_radius_mult` itself, once per pass (`bot.tune(...)` at the start of each pass), the first pass always "today" (0 and 1.0). So one recording of 'Look: flash share, hold knees' holds today and every cap, and one of 'Look: flash share, haymaker and finishers' holds today and every multiple, each pass resetting the room and seeding the effects the same way (`VFX_SEED`). The A/B pair is the same hit in two passes: hold knee n1/n2/n3 at today against `cap12` (0.12), haymaker n2 and uppercut n4 at today against `mult20` (2.0). The suggested values are the brief's (0.12, 2.0); the passes also have 0.04, 0.06, 0.08 and 1.5, 3.0 if Game-boy wants another.
- *Alternative.* Two recordings per act with `--tune=hit_flash_fp_max_share=0.12`. Not taken: the act overwrites the value at the start of every pass, so the "tuned" recording would show the first pass at today's value again and nothing else.
- *Why.* It is the only way to get a true A/B (same frames, same hit) from these acts, and the figures printed with each flash (`FLASH-FP` lines) come with it.

**C2. Question 4's A/B is recorded with an untracked scratch bot that leaves the combat log on.**
- *Decision.* The crowd bot hides the combat log in `_run()` ("the bot logs the hits itself", `crowd_bot.gd:149`), so C11 as the stock bot records it never shows the log: `combat_log_hide_while_holding` false and true would be the same picture. I made `tests/bot/scratch_evidence_log_bot.gd` and `.tscn` (a four-line subclass: `_connect_logs()` calls `super()`, then shows the log again, which is how the game shows it), recorded C11 twice with it (`c11_log_show`, and `c11_log_hide` with `--tune=combat_log_hide_while_holding=1`), and **deleted both files, and the `.uid`, before the full suite ran**. They were never committed (`git status` at the commit shows only `docs/`).
- *Alternative.* Record C11 with the stock bot. Not taken (no difference to show). Or change `crowd_bot.gd` to leave the log on for an act: not mine, and the bot's other acts want it off.
- *Why.* The only difference between the two stills is the tunable. The log is a panel with the hit line over the knee's burst and the player's glove, as grab-03 said.

**C3. Question 3's A/B is the stock 'Look: my knockdown' with `--tune=fp_knockdown_hide_torso=1`.** Its log prints `LOOK-PLAYER fp_knockdown_hide_torso true` (the main recording, `pa2`, prints `false`), so the tunable reached the run. *Alternative:* none needed; the act's header names this exact use.

**C4. The DM pair is C2's frame 109 (`idle_t060`), with C1's frame 109 as the face-shot twin.**
- *Decision.* The M3 pack and this one were cut at the same frames (`c2_f49`, `f109`, `f169`, `f229`), the acts being deterministic. I picked `f109` (1 s in: both Punks settled, the placeholder's cap fully in the frame) at the default -6 degrees, 1 m ahead; the face-shot twin is C1 `f109` at +8 degrees. Side by side, M3 left and M4 right.
- *Alternative.* `f49`, the first frame after the spawn (the placeholder's cap is cut off by the top of the view there). Not taken.

**C5. The before side.** C1, C2 and C7 use `captures/m4_before/<slug>/`; C5, C9 and C13 use `captures/m4_before_recut/<slug>/` (re-cut after the act framing changed: C5 and C13 tip the view for the KO, C9's cast stands off the tour's path). Every frame name in the after pack has a twin in the before pack (30 of 30 stills for C5 and C13, 7 of 7 for C9, 4 of 4 for C1, C2 and C7); the crops are paired too where the rectangle exists. C13 is not in the brief's list (C1, C2, C5, C7, C9) but is in B3's "C1-C13", and its recut was there, so its pairs are made.

**C6. The side-by-sides carry no text labels.** This machine's ffmpeg has no `drawtext` and there is no Pillow or ImageMagick; a Godot script to draw labels would be another process on a loaded machine for a caption. The left half is always M3 and the right half M4, and the file names say so (`..._m3_left_m4_right.png`; the feel pairs say `today_left`/`value_right`). *Alternative:* a labelling script. Not taken.

**C7. Recordings are 1600x900 (the movie size); "full-resolution stills" are 1600x900.** `tools/capture_bot.sh` passes `--resolution 1280x720`, and the movie is 1600x900 (F-look's call: the window renders 1280x720 and the grab is upscaled, so the stills are about 1.25 times soft along edges; the probe reports at 1080p whatever the frame's size). The M3 pack is also 1600x900, so a pair is like for like. The clips are the 1600x900 recordings scaled to 1280x720 (lanczos), H.264, 60 fps, AAC at 96 kb/s (the game's own sound is in them).

**C8. The "60 s autopilot crowd act" is `Waves to the boss` (56.4 s), with `Six Punks, fight` (27.4 s) beside it.**
- *Decision.* SL-int's call 48 names the crowd bot's 60 s autopilot acts: `Waves to the boss` (56 s), `Mixed waves` and `Waves` (90 s each; all three took about 1.2 GB recorded). I recorded the one nearest 60 s, plus `Six Punks, fight` (all Punks, the six-Punk clip's source), and read the hard rows (R1-R3, R10, R11) and check_m3_log on both. R4 and R8 with the art drawn are from `Look: readability with the art drawn` and from the final probe's own run.
- *Alternative.* All three waves acts, recorded in full. Not taken: about 1.2 GB for the three on a loaded 8 GB machine, and the hard rows were already read on the same acts at the smoke Punk (SL-int); `Mixed waves` and `Waves` are not re-measured on the final art (part 5, risks).

**C9. The six-Punk clip is the whole act (28.6 s), crf 29.** At crf 26 it came to 10.69 MB, over the 10 MB bar; crf 29 is 8.03 MB. It is not trimmed: the Punks walk in from the surround points (2-10 m) in the first seconds and the fight is the rest. In the twelve wind-ups I cut out of it (8 frames in, `montages/six_windups_f339_to_f1206.png`) the attacker is within about 1.5 m, so no 2.5 m wind-up is shown in this clip (index, J12).

**C10. The player's-limbs clip is `Look: my arms and legs` from 1.7 s to 12.3 s (frames 100-735, 10.6 s).** It runs from looking 45 degrees down through the chain at -20 degrees (jab, cross, hook, uppercut), the front kick, the block's guard, the spin kick, a jab, the haymaker's charge and swing, the hold and the knee. It leaves out the idle at level and the KO (frames 811-1053), which are not the limbs. *Alternative:* C8 (which looks 45 degrees down throughout): the brief names pa1.

**C11. L4 (perf) is quoted from the lead's earlier interleaved runs, marked loaded, and not re-run.** The lead's note forbids `tools/perf_compare.sh` on this machine. Both runs are on earlier heads (`59a0adf` at the slice gate, `bf7b0ab` after P3-int), before F-punk, F-player, the fixes and the final art; the final head's perf is unmeasured. Both read "loaded machine, not quiet": load 2.4-4.6 from other apps, vsync on (A16 asks for a quiet machine and vsync off), the refs interleaved, so the deltas are the figures to read.

**C12. One full suite run is the source of `art_metrics.json` and `strain_worst10.json`.** The brief asked for `-gselect=test_m4_done_when.gd` and the A19 print from `test_skinned_art`; the full `tools/run_tests.sh` was needed anyway before the final commit and prints both (the `DONE-WHEN` table at the end of `test_m4_done_when`, and the `A19 strain of ...punk.glb` / `player.glb` blocks), so the JSON is read from that one log: 74 scripts, 1593 of 1593 tests, 301 s, 0 `SCRIPT ERROR` / `SHADER ERROR` / `ERROR` lines. *Alternative:* two `-gselect` runs and then the full one. Not taken: three Godot runs on a loaded machine for the same numbers.

**C13. The JSON files are generated from the logs by scripts that are not committed.** The scripts are in my scratchpad; what is committed is the data, each file with its `source` line. The values are copied from the logs, never rounded, and each GATE row keeps the plan's bar next to the figure.

**C14. `ledger.json`'s Gemini count is the job files' image count (23).** There is no Gemini ledger, so a job run twice would not show; ASSETS.md names every job. The count is the floor, not a bill. The plan's "about 40 images" was an estimate. Hero `view_right` is an ffmpeg mirror (no call), so the hero's views are three images.

**C15. check_m3_log on the `Look: readability with the art drawn` log fails, and that is the checker's reading, not a cap breach.** That act runs two fights in one act (header), clearing the room between them; Punk4 and Punk9 end the first fight holding tokens with no `TOK-` line, and the checker counts them against the cap in the second fight (4 and 5 holders over 3). It is not a probed act (no `WARN-CHECK` lines). The two probed acts, `Six Punks, fight` and `Waves to the boss`, are `ok` (token holders at most 3 of 3 and 2 of 3), and R1 is max 1 in both. I did not change the checker (not my file); the note is in `readability.json`.

**C16. 12 fps sheets for C3, C4, C5 and C11; 6 fps overviews for the rest.** B2 asks for the "in motion" items at 12 fps. C3, C4, C5 and C11 are 5-13 s each (2-7 pages); C12 is 54 s (30 pages at 12 fps), so it keeps `look_sheets`' 6 fps overviews and the 44 full-resolution stills of its marks.

**C17. A seam scan for J9.** A still cannot show a pop, so I ran ffmpeg's frame-difference score over the whole of C14 and looked at the frames around the four biggest seams (f950, f1731, f1873, f2161, 640 px wide). The typical frame-to-frame score is 0.0016; the seams step by 0.03-0.04 (f950 0.033, f1731 0.039, f1874 0.037, f1933 0.029, f2161 0.037, f2221 0.030); the biggest scores of the take are the fists coming into the lens (0.07-0.13) and the KO blink-off (0.07 at f2451). I could not tell a one-frame blend start from a small pop at 640 px; the four seams show no visible snap. The index says exactly that.

**C18. No ARCHITECTURE.md heading.** "Art pipeline and look (Milestone 4)" has a heading per package up to P3-int and none for P3-evidence, and the lead's note gives me only `docs/reviews/M4/evidence/` and this file. So no heading is added; the pack's contract is in `docs/reviews/M4/evidence/index.md`. If the lead wants one, a "### The evidence pack (P3-evidence)" pointing at it is one paragraph (part 5, requests).

## 2. Assertions and files that changed

None. The branch adds `docs/reviews/M4/evidence/{index.md, art_metrics.json, look.json, readability.json, ledger.json, strain_worst10.json}` and this file. No game, test or tool file, no tunable (so no preset regeneration), no asset (no ASSETS.md row). The scratch bot of C2 was removed before the full run.

## 3. Numbers

- **Recordings.** 26 windowed recordings, one act per process, 0 `SCRIPT ERROR`, `SHADER ERROR` or `ERROR` lines in any `bot.log` (table in the index). One `rec.sh` driver (not committed) ran `tools/capture_bot.sh` then `tools/look_sheets.sh`; I edited the driver while C5 ran, which cut that run's sheet step short, so C5's sheets were cut again by hand from the same recording (the recording and its log were whole).
- **Full suite.** 1593 of 1593, 74 scripts, 113,837 asserts, 301.1 s, 0 error lines.
- **Done-when rows.** 9 PASS (A1, A2, A3, A5, A8, A10, A12, A13, A14) and 5 GATE with the ratchet held (A4 the hero's walk slide, A6 the hero's legs, A7 deformation on both arts, A9 first-person framing, A11 flash anchor): the plan's bar is not met on those five. Nothing in the pack rounds them up.
- **Windowed rows (final probe).** L1 MISSED (10 m left 2.61 px and right 2.04 px against 3.75 +-1; the own-body top 4.05 px; the 1 m left edge is 4.50 against the 4.5 cap), L2 MET (3 bands front-lit, shadow/lit 0.66), L3 MET (3.6% white share against 6.3%), L5 MET (R8 within 2.1 points, R4 no wind-up hidden by another enemy, art or proxies). L4 is the earlier perf figures (C11).
- **Readability with the art.** `Waves to the boss` (56.4 s): R1 max 1, R2 80 f, R3 0 of 4, R10 100% of 7, R11 0: hard rows met; soft misses R6 (posture ring median 1.02 m) and R7 (capsule overlap 1.16%). `Six Punks, fight` (27.4 s): hard rows met (R1 max 1, R2 56 f, R3 0 of 8, R10 100% of 16, R11 0); soft miss R8 (lens covered p50 29%, bar 25%).
- **Money.** 12 Tripo tasks, 295 credits, balance 1205 of 1500 (the stop is 750); 23 Gemini images by the job files.
- **Clips.** Long take 5.2 MB (40.2 s), own limbs 1.6 MB (10.6 s), six-Punk fight 7.7 MB (28.6 s); H.264 1280x720, 60 fps.
- **Feel questions.** In the index.
- **Credits spent by this package.** 0 (no Tripo task, no Gemini image).

## 4. What the sheets show (all first person; `captures/m4/evidence/`, never committed)

The index has the per-item reading. The short version, honestly:

- **The Punk reads as the pick at 1 m.** Cap, teal vest, black tank, fingerless gloves and the taped right forearm are all there, with a continuous ink hull and three tinted bands on the vest. It is a large improvement on the M3 placeholder beside it in every pair.
- **Where it is weakest.** The strikes: at the jab's and cross's landing a dark glove fills the top of the lens as one flat shape (no strap or knuckles at that moment). Interior ink lines are ragged and dashed on the vest and the tape. The cap's crown carries small dark specks seen from behind. The placeholders (Kicker, Thug, Bruiser) are louder than the Punk (saturated lime, olive and purple) and read as another level of detail, though under the same ink and bands.
- **The player's limbs.** Wraps, fingerless gloves, a grey trouser leg with ink folds and a shoe with a cream toe cap read well when they are in the view (the front kick, the hook, the hold's knee, the walk at 65 degrees down). They are often not in the view: at 45 degrees down the idle and the guard show only the street and their shadow, and in strikes the forearm is a large flat skin-tone slab.
- **The A/Bs.** All four show a clear difference (index); the knockdown's torso hide shrinks the navy slab from about a third of the frame to about a ninth, not to nothing.

## 5. Requests, departures, risks

- **Requests.**
  1. The lead: copy the DM files (the index lists every absolute path) into the Slack DM; none is in the repo (A17).
  2. The lead, optional: an ARCHITECTURE.md heading "### The evidence pack (P3-evidence)" pointing at `docs/reviews/M4/evidence/index.md` (C18).
  3. The lead: if `Look: readability with the art drawn` should pass `check_m3_log.py`, the checker would need to forget token holders when the act clears the room between its two fights (or the act should not share a header across them): `tools/check_m3_log.py` and `tests/bot/acts/look_acts.gd` are not mine (C15).
  4. The lead: `tests/bot/acts/look_player_acts.gd`'s header still says the hero's GLB "does not exist yet" and that `look_player_art_probe` is needed; the act's own log prints `LOOK-PLAYER art hero 19868`, i.e. the shipped art. A comment fix.
- **Departures from the spec.** None. Nothing was implemented.
- **Open risks.**
  1. **A7 and A9 are not met on the shipped art** (art_metrics.json): the strain bars on both GLBs (the Punk's worst p99.9 4.03 against 1.6, 1.65% of triangles folded or squashed at the worst peak flex against 0.5%) and the first-person framing (the hero's art 8.1 cm nearer the lens than its proxies in the front kick). The ratchets hold them from getting worse; the pack reports them as misses. J8 is a critical item; the re-scorer's J8 is the judgement, and the stills I looked at (extremes, strafe, hook stagger, the knockdown) show no candy-wrap or collapse.
  2. **L1 is missed** at 10 m (2.0-2.6 px of hull against 3.75 +-1) and on the player's own top edge (4.05); soft rows.
  3. **Perf is unmeasured on the final head** and the earlier figures are from a loaded machine (C11). The RTX 3060 is unmeasured. M3 itself misses the p95 and spawn-hitch bars on this machine, so the misses are not M4's alone: M4's delta is +2.4 ms mean and +3.4 ms p95 at the slice gate.
  4. **`Mixed waves` and `Waves` (90 s) were not re-recorded** on the final art (C8); the hard rows hold on the two acts that were.
  5. **J12's 2.5 m part has no still**: in the twelve wind-ups looked at the Punk's wind-up starts inside about 1.5 m, so the 2.5 m reading rests on the probe's rows (R2, R3, R10), not on a frame.
  6. **The M3 pairs are cut at 1600x900 from a 1280x720 render** on both sides, so both are soft in the same way.
  7. **The Gemini count is a floor** (C14).
