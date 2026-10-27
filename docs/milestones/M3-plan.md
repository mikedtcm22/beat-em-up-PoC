# Milestone 3 plan: enemy AI and the rear warning

Branch `m3/enemy-ai`. The lead (Opus) wrote this on 2026-10-25 from three independent plans and a judge's verdict, all kept in [M3-planning/](M3-planning/). Codemaps of the code M3 builds on are in [M3-codemap/](M3-codemap/); read the ones your package touches.

**How to read this file:**
- **Part A, amendments.** These bind. Each one overrides the part of Part C it names.
- **Part B, the done-when made checkable.** The warning's truth table, the readability metrics, the evidence pack and the review lenses.
- **Part C, the base plan.** The vertical-slice plan, verbatim: contracts (§2), hot spots (§3), packages (§4-§8), sequencing (§9), coverage (§10), judgement calls (§11), risks (§12).

Where Part A and Part C disagree, Part A wins.

---

# Part A: amendments (binding)

## A1. Process
1. **M2 worktrees pruned** (done, 2026-10-25 18:05). Every M2 branch is kept.
2. **`tuning/default.json` never needs a hand merge.**
   - `.gitattributes` gets `tuning/default.json merge=keep-ours` (S0), and the lead has run `git config merge.keep-ours.driver true` in the repo.
   - After every merge, the lead regenerates the preset (`godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd`) and reruns the generator if `gen_moves.gd` changed: only intended `.tres` files may change.
3. **Builds run through a resumable runner,** `docs/reviews/M3/workflow-build.js` (the lead writes it after S0, on the pattern of M2's `workflow-fix.js`).
   - Its args name the packages, and are saved as `docs/reviews/M3/args-<phase>.json`.
   - A package's state:
     - **done:** its branch has a commit whose subject starts `M3 <key>:`;
     - **wip:** the branch exists without one; the builder reuses it and goes on from its newest `wip:` commit;
     - **new:** no branch yet.
   - So a run that's cut off resumes by rerunning the same args.
   - Builders run on Sonnet, at most 4 Godot-bound builders at once (8 GB of RAM), and every launch is usage-gated.
4. **The watcher can't reach agents inside a running workflow.**
   - On the watcher's 90% message, the lead stops the workflow (TaskStop). The builders' `wip:` commits, every 15-20 minutes and pushed, bound what is lost.
   - The lead then writes HANDOFF, which names the runner and its args file, and creates the resume task.
   - At every phase boundary, the lead checks that the watcher is still looping and that no stale `beat-em-up-resume-*` task is waiting.
5. **Judgement calls:** each builder writes its own to `docs/milestones/M3-calls/<key>.md`. The lead folds them into [M3-judgement-calls.md](M3-judgement-calls.md), which feeds the final Slack digest.
6. **Lead fixes CLAUDE.md:** the test run now takes about 90 s, not 6 s.

## A2. S0 changes (override Part C §2 and §4)
1. **One geometry helper for "where is it from the look": `game/combat/view_geometry.gd`** (`class_name ViewGeometry`, static functions only, simulation-safe, no camera):
   - `bearing_deg(look_yaw: float, from: Vector3, point: Vector3) -> float`: signed flat degrees, 0 ahead, positive left, ±180 behind;
   - `is_outside_view(look_yaw: float, from: Vector3, point: Vector3, half_angle_deg: float) -> bool`;
   - `warning_corner(bearing: float, distance_m: float, reach_m: float, angle_deg: float, behind_deg: float, margin_m: float) -> StringName`: returns `&""`, `&"left"`, `&"right"` or `&"both"`, per Part B §B1.

   The player's look API (§2.1: `get_look_forward()`, `look_bearing_deg()`, `is_outside_view()`) wraps it. The director, the warning and the bots' oracle all call it. **`tests/test_view_geometry.gd` holds the hand-written truth table of Part B §B1**, row for row; never derive it from the function.
2. **The fight holds while F1 or F4 is open.**
   - `GameInput` gains `var menu_open: bool` (an input-layer state, like the player's scripted input). `TuningOverlay` sets it on open and clears it on close: one line each in `tuning_overlay.gd`, owned by S0.
   - While it is true:
     - the director grants no tokens and takes back any token whose wind-up hasn't started;
     - an enemy with no move running stands, faces the player and asks for nothing;
     - waves start no spawns.
   - An attack already winding up finishes.
   - Today the overlay only freezes the player's input, so a crowd would beat Game-boy up while he tunes (SPEC §11 tuning is live).
3. **`break_free(invuln_frames: int) -> void`** replaces §2.2's `break_free(push)`. `release_from_grab(push, false)` ignores `push` in its non-stagger branch, and the player's own control would overwrite a velocity next tick anyway.
   - The visible shove is the holder's: `_on_hold_broken(victim)` (EnemyHold, P2-grab) staggers the holder away from the victim at `grab_break_push_mps`.
   - The victim stays where it stands, invulnerable for `invuln_frames`.
4. **Drop `_keeps_pose_after_strike()`.** Code-applied hits never set `_pull_strike` (`combat_actor.gd:200`).
5. **Add `_parry_staggers() -> bool`** (virtual, default true). `react_to_block()` staggers a parried attacker only when it returns true; otherwise the attacker takes the ordinary recoil.
6. **Armored hits don't stretch wind-ups.** In `hit_detector.gd`, a hit with `hit.armor_absorbed` puts only the attacker in hitstop (the strike still feels solid), never the armored victim. Otherwise every jab would lengthen a Bruiser's or boss's wind-up, and its warning with it. Test it in `test_m3_contracts.gd`. S0 owns `hit_detector.gd` for this line.
7. **`MoveData.reach_m`** (S0):
   - its range is `0.0, 10.0`, and it **includes the move's travel** (its `lunge` or `free_lunge`), so a boss charge or a Kicker's jump kick from 4-6 m behind still warns;
   - `lunge`'s range widens to `0.0, 8.0`;
   - `reach_m` joins the "Movement" group of `Tuning.MOVE_GROUPS` (`tuning.gd:45`), so F1 edits it per move and presets save it.
8. **`dummy_jab.reach_m = 1.05`** in `gen_moves.gd`. `dummy_jab.tres` is the one shipped move file allowed to change, and there is no `rear_warning_fallback_reach_m`.
9. **`HitInfo.describe()`** appends `" ARMOR"` when `armor_absorbed` (the combat log shows it).
10. **The director skeleton also has `may_start_windup(enemy: EnemyActor) -> bool`.** An enemy with a token calls it right before winding up. True means "go now", and the director records that wind-up start. The skeleton returns true; P1-director enforces `director_min_windup_gap_s` there (this replaces `director_min_attack_gap_s`). Readability metric R2, no two wind-ups starting together, is thereby guaranteed at the wind-up, not hoped for from the grant.
11. **S0 declares every tunable named anywhere in this plan**, with the plan's defaults, in its owner's subgroup. Owners may add more inside their own subgroup only, so later appends are rare. `rear_warning_follow_turn` (false) and `rear_warning_hide_in_ko` (true) join "Rear warning".
12. **Test fixtures:**
    - `tests/fixtures/stub_enemy.gd`/`.tscn`: an EnemyActor that stands still, with `wants_token()` driven by a test flag and `force_attack()` working;
    - `tests/fixtures/stub_director.gd`: an EnemyDirector whose holders, slots and waiting lists tests can set.

    P1-director, P1-hud and P1-instruments test against them, so no phase 1 package waits on another.
13. **No FINISHER-tier enemy moves**, enforced by `tests/test_move_data.gd`'s enemy rules: the finisher tier fires the global slow-mo and impact frame. `boss_slam` is HEAVY, THROWN.
14. **One telegraph per attack, with a condition:** a chain link (the Punk's cross, the Thug's second and third swings) starts with no wind-up of its own, and **only if the previous hit landed or was blocked**. A whiffed opener ends the attack.

## A3. Phase 1 changes
1. **P1-ai**, besides Part C:
   - **COMMIT:** on a token, the enemy stops strafing and squares up for `commit_pause_frames` (a visible "I'm next"), then steps in to `attack_range_m() - engage_margin_m`, calls `may_start_windup()`, and winds up.
   - **Track, then lock:** the wind-up turns toward the player for the first `windup_track_share` of its length, then holds its facing, so a late sidestep or dodge makes it miss.
   - **RECOVER backs off:** after the attack, it walks back out to its slot on the ring before posturing again; the token is released when RECOVER starts.
   - **Taunts are open-handed** (beckoning, arms out, chin up). They never look like a wind-up.
   - Honours `GameInput.menu_open` (A2.2) and A2.14's chain condition.
2. **P1-director:** `may_start_windup()` with `director_min_windup_gap_s`, and the `menu_open` hold. Add RF's R9 test: at `blind_spot_priority` 1.0, at least 90% of grants go to out-of-view waiters when both kinds wait.
3. **P1-room:**
   - a `vehicle` spawn tag, a spawn point on the far side of the parked car (SPEC §7 lists vehicles);
   - waves hold while `menu_open`;
   - the crowd bot skeleton stays P1-room's, and the act files stay one per package.
4. **P1-hud:**
   - **The trigger and side** follow Part B §B1 exactly, through `ViewGeometry.warning_corner()`. The reach comes from `attacker.warning_reach_m(move)` if the attacker has that method, else `move.reach_m`.
   - **Tunables:** `rear_warning_follow_turn` (default off) re-evaluates the side each frame; `rear_warning_hide_in_ko` (on) hides it while the player's health is 0.
   - **Sweep test:** `test_warning_sweep_every_5_degrees` runs in the real training room with real dummies and the real HUD: 72 bearings, all agreeing with the rule.
   - **Logging:** `warning_bot` prints a `WARN-CHECK ok|FAIL <act> <corner> f<frame>` line per act.
   - **Health bars:** enemy over-head bars skip group `"boss"` (`enemy_health_bars.gd`, which P1-hud owns in phase 1), and the boss bar hides on `vanished`.
5. **New fifth package, P1-instruments** (`.worktrees/m3-instruments`, `m3/instruments`, Sonnet; about 5-6% of a window).
   - **Owned files:**
     - `tests/bot/readability_probe.gd`: computes Part B §B2's metrics R1-R15 and writes `readability.json` plus a one-screen summary per act;
     - `tests/bot/autopilot.gd`: a scripted player that faces the nearest posturing enemy, throws P P P P, blocks when a wind-up starts in view, and dodges sideways when two wind up at once;
     - `tests/bot/warning_oracle.gd`: at every `windup_started`, compares the HUD's `RearWarning` corner state with `ViewGeometry.warning_corner()` and prints `WARN-CHECK`;
     - `tests/test_readability_probe.gd`, `tests/test_autopilot.gd` and `tests/test_warning_oracle.gd`: tested in the training room or a tiny code-built arena, against S0's stub enemies and stub director, duck-typed where P1-hud's widget isn't merged yet;
     - `docs/milestones/M3-calls/P1-instruments.md`.
   - **Thresholds are acceptance criteria:** they live in the probe and the tests, never in TuningData.
   - P1-int wires the probe, autopilot and oracle into the crowd bot's acts.
6. **P1-int** also asserts the hard metrics in `test_slice_crowd.gd`: R1, R2 (enforced at the wind-up, A2.10), R3, R10 and R11. It records the slice acts with the probe on and quotes `readability.json` in the gate file.

## A4. The slice gate (overrides Part C "The slice gate")
- The hard metrics (R1, R2, R3, R10, R11) must pass.
- The soft ones (R4-R9, R12-R15) are judged and either met or argued in `M3-slice-gate.md`.
- The L2 rubric (Part B §B4) is answered yes, with frame references.
- The review lenses at the gate are L1 (warning), L2 (crowd readability) and L4 (code and layers) from Part B §B4.

## A5. Phase 2 changes
1. **P2-grab:**
   - break free per A2.3; `_on_hold_broken()` staggers the holder away;
   - a first-person lens-clearance test of the held view, and a test that the release doesn't move the lens more than 2 cm;
   - **magnetism in a crowd** (P2-grab owns `player.gd`): skip bodies in get-up invulnerability; the stop distance adds the target's radius over the default; a flat cone, so tall bodies are found by their chest height; the stomp only when no standing enemy is in the cone.
2. **P2-kicker:** the jump kick's `reach_m` includes its travel.

## A6. Phase 3 changes
1. **P3-bruiser** also owns `game/fx/vfx_director.gd`, `game/ui/combat_log_overlay.gd` and `game/audio/audio_director.gd` in phase 3, for **armor that reads**:
   - a grey spark instead of the burst on an absorbed hit;
   - a clank from the existing pools (a block clack pitched down);
   - "ARMOR" in the log.

   P3-boss touches none of them.
2. **P3-boss:**
   - the charge's `reach_m` includes the charge distance, so it warns from behind at its real range;
   - `boss_slam` is HEAVY, THROWN;
   - `_parry_staggers()` is false: a parry gives the boss a recoil, not a stagger.
3. **Both:** a first-person lens-clearance test for each of their strikes landing on the player from a 2.05 m and a 2.3 m rig. The M1/M2 rule that a landed strike snaps to the stance after the hitstop (`_pull_strike`) stays: it keeps big fists from sweeping back through the lens.

## A7. Phase 4 changes
1. **P4-int** adds `tests/test_m3_done_when.gd`:
   - a real Punk, Kicker and Bruiser placed at 135° left, 135° right and 180° wind up, and the corners are asserted;
   - negative controls at 50° and out of range;
   - a 1500-frame mixed soak with the hard metrics.

   It also adds `tools/check_m3_log.py`, which parses a crowd log: the `WARN-CHECK` lines all say `ok`, token holders never exceed the cap, and every wind-up from beyond 55° and within range has its warning within 1 frame.
2. **The review round** uses Part B §B4's lenses L1-L6 and the L2 rubric. The crowd lens judges the non-KO knockdown view too (the "belly slab" Game-boy left at its default in M2). It is more frequent in a crowd; flag it if it is severe, and don't change it without his call.
3. **The PR and the Slack digest** quote the evidence pack (Part B §B3) and `readability.json`.
4. **Release:**
   - smoke the exported binary headless (`--quit-after 900`, grep for SCRIPT ERROR/ERROR), then run it windowed once and look;
   - `gh release create m3-playtest-1 ... --prerelease`.

## A8. Usage, measured
The mapping and planning workflow (10 Opus agents, about 3.4M tokens, 59 minutes) took the 5-hour window from 2% to 34% and weekly from 21% to 26%. That is about 3 window points per heavy Opus agent, consistent with the old costs divided by 5, and one window point still costs about 0.16 weekly points. Re-measure the Sonnet builders in phase 1 and update HANDOFF's table.

---

# Part B: the done-when, made checkable

Taken from the readability-first plan (`M3-planning/m3-plan-readability-first.md` §1.2-1.5). Where a row names a package or a tunable, read it through Part A. For example, `token_grant_gap_frames` is A2.10's `director_min_windup_gap_s`, and WP-I is P1-instruments.

## B1. The warning rule, exactly (SPEC §8)

The rule is one pure function, `ViewGeometry.warning_corner()` (WP0-sim), used by the HUD widget and by the bots' oracle. Its truth is pinned by a **hand-written** table in `tests/test_view_geometry.gd`, not derived from the function.

Inputs at the frame `CombatEvents.windup_started(attacker, move)` fires:
- `b` = the signed flat bearing from the player's **look** (`look_yaw`, never a camera) to the attacker's origin, in degrees: 0 dead ahead, positive to the left, ±180 directly behind. Measured from the player's origin.
- `d` = the flat distance between the origins.
- `reach` = `attacker.warning_reach_m(move)` if the attacker has that method, else `move.reach_m` (new MoveData field).

Rule:
1. **Fires** when `|b| > rear_warning_angle_deg` (55) **and** `d <= reach + rear_warning_range_margin_m` (1.0).
2. **Side:** `b > 0` (behind-left) → top-left; `b < 0` → top-right; **`|b| >= 180 - rear_warning_behind_deg`** (20, so within ±20° of directly behind) → both corners.
3. **Timing:** shows on the wind-up's first frame, so the warning time equals the wind-up length. **Ends** on the first of: `hit_landed` with that attacker (blocked hits included); `attack_whiffed(attacker)`; `windup_ended(attacker, true)`; `grabbed(attacker, _)`; `ko(attacker, _)` or `vanished(attacker)`; or, polled every HUD frame, the attacker freed, out of WINDUP and ATTACK, or running a different move. **Never** on `windup_ended(attacker, false)`, which is the strike coming out.
4. **Side fixed at the wind-up start** (spec: "appears at wind-up start"). A tunable `rear_warning_follow_turn` (default off) re-evaluates the side every frame.
5. **Several attackers:** one burst per corner; its brightness is `1 + rear_warning_brightness_step × (n − 1)` for `n` live entries on that side (a "both" entry counts on both sides), and it re-pulses when `n` rises.
6. **Heavy attackers** (`attacker.heavy == true`, read duck-typed; Bruiser and boss) make that corner's burst `rear_warning_heavy_scale` times larger.
7. **Look:** `VfxArt.texture(&"rear_warning")` (exists), base size `rear_warning_base_px × rear_warning_size`, alpha `rear_warning_opacity`, two pulses of `rear_warning_pulse_s`, then steady until the end. Clamped inside the reserved 20% × 20% corner.
8. **Audio:** the wind-up's own effort and whoosh, positional (exists). `rear_warning_audio` keeps gating all wind-up audio (SPEC §8 "audio on/off", literal).
9. **Suppressed** only while the player's health is 0 (the KO view; `rear_warning_hide_in_ko`, default on).

Truth-table rows the test must hold (look along −Z, reach 1.0, margin 1.0, angle 55, behind 20):

| Bearing (°) | Distance (m) | Expected |
| --- | --- | --- |
| 0, ±30, ±54.9 | 1.5 | NONE (in view) |
| +55.1, +90, +135, +159.9 | 1.5 | LEFT |
| −55.1, −90, −135, −159.9 | 1.5 | RIGHT |
| +160, −160, +170, ±180 | 1.5 | BOTH |
| +135 | 1.99 | LEFT |
| +135 | 2.01 | NONE (out of range) |
| −179.9 with `look_yaw` = 3.1 rad, and again with −3.1 rad | 1.0 | BOTH (wrap-around) |
| +100 with the player looking along +X (`look_yaw` = −π/2) and the attacker placed at that bearing | 1.0 | LEFT (frame independence) |

## B2. Readability metrics and thresholds

`tests/bot/readability_probe.gd` (WP-I) computes these every physics frame (the cheap ones) or every 10th frame (lens coverage and occlusion, using `tests/fp_view.gd`), writes `<capture dir>/readability.json`, and prints a one-screen summary at the end of each act. **Hard** thresholds are also asserted in headless GUT tests (short seeded runs). **Soft** ones are judged by the reviewers; a miss is a finding, not a failed build. Thresholds are acceptance criteria, so they live in tests and bots, never in `TuningData`.

| ID | Metric (`readability.json` key) | Definition | Threshold |
| --- | --- | --- | --- |
| R1 | `max_concurrent_attackers` | most enemies in WINDUP or ATTACK at once (a held grab counts) | ≤ `attacker_cap` (hard) |
| R2 | `min_windup_start_gap_frames` | least gap between wind-up starts of two **different** enemies | ≥ `token_grant_gap_frames` (hard) |
| R3 | `unwarned_hits` | hits on the player whose attacker had no WINDUP of at least its move's `windup_floor` in that attack (the grab's final hit is exempt: the hold is its telegraph) | 0 (hard) |
| R4 | `occluded_windup_share` | in-view wind-ups whose attacker's chest is hidden from the lens by another enemy's body for over half the wind-up | ≤ 10% (soft) |
| R5 | `front_wedge_crowding` | share of frames with more than 3 posturing enemies within ±45° of the look | ≤ 5% (soft) |
| R6 | `ring_adherence` | posturing enemies' flat distance to the player: median, 10th percentile | median 2.5-4.0 m; p10 ≥ 2.2 m (soft) |
| R7 | `capsule_overlap_frames` | frames with two standing enemy capsules overlapping | ≤ 0.5% (get-up pops only) (soft) |
| R8 | `fp_enemy_coverage` | share of the lens covered by enemy meshes | p50 ≤ 25%, p95 ≤ 50% (soft) |
| R9 | `blind_grant_share` | grants that went to an out-of-view enemy when in-view and out-of-view enemies were both waiting | ≥ 0.9 in `test_director.gd` at priority 1.0 (hard); ≥ 0.6 in a crowd act (soft) |
| R10 | `warning_oracle_agreement`, `warning_false_positives`, `warning_latency_frames`, `warning_end_lag_frames` | the widget's corner state against the rule, at every wind-up | 100%, 0, ≤ 1, ≤ 1 (hard) |
| R11 | `max_knockdown_hit_damage_non_boss` | damage of any non-boss hit that knocks the player down | ≤ 15 (hard) |
| R12 | `passive_time_to_ko_s`, `max_damage_2s` | a player who never acts, against 6 grunts; worst 2 s of damage | ≥ 12 s; ≤ 30 (soft) |
| R13 | `stuck_events`, `waves_cleared_90s` | an enemy with no progress toward its slot for 3 s; waves the autopilot clears in 90 s | 0; ≥ 2 (soft) |
| R14 | `windup_voices_stolen` | wind-up voices stolen by the voice pool before their wind-up ended | 0 (soft) |
| R15 | `frame_ms_p95`, `spawn_hitch_ms` | windowed frame time with 6 enemies; worst frame within 0.5 s of a spawn | ≤ 16.7; ≤ 33 (soft; this Mac, not the SPEC §10 target machine) |

## B3. The evidence pack (recorded in phase 4; the PR and the Slack digest quote it)

All recorded with `tools/capture_bot.sh` (WP0-ui) into `captures/m3_evidence/` (never committed). Sheets are first person unless marked.

| Done-when clause | Evidence | Pass |
| --- | --- | --- |
| "fires correctly behind-left" | `warning_bot` act "Warn: behind-left" (training dummy at 135° left, 0.9 m); corner-crop sheet; log line `WARN-CHECK ok` | top-left burst from the wind-up's first frame to the hit; top-right empty |
| "...behind-right" | "Warn: behind-right" | mirror |
| "...directly behind" | "Warn: directly behind" (180°) and "Warn: edge of behind" (161° and 159°) | both corners at 180 and 161; one corner at 159 |
| (negative controls) | "Warn: in view" (50°, 0°), "Warn: out of range" | no burst |
| (several, heavy, ends) | "Warn: two on the left", "Warn: left, right and behind", "Warn: heavy", "Warn: blocked ends it", "Warn: hit out of the wind-up ends it" | brighter, both, larger, ends on contact or interrupt |
| (sweep) | GUT `test_warning_sweep_every_5_degrees` (headless, real dummy and HUD) and the slower recorded act "Warn: sweep" (every 15°) | 72 of 72 bearings agree with the table |
| (with real AI) | `crowd_bot` "Crowd: blind spot" (player faces the north wall, 6 real enemies); probe R10 | 100% agreement, 0 false positives |
| "a 6-enemy fight is readable" | `crowd_bot` "Crowd: observe 360" (god mode, the player turns slowly through 360° twice), "Crowd: autopilot" (60 s fight), "Crowd: passive", "Crowd: waves" (90 s); `readability.json` for each; full-res sheets at 6 fps | every hard R-metric met; soft ones met or argued in the review; the L2 rubric (§1.5) answered yes |
| per-archetype tells | each archetype bot's tell acts at 3 m and 1 m | the wind-up reads from the lens; distinct silhouettes |
| grabs | `grab_bot` and the Bruiser and boss grab acts | upright held view, prompt, mash-out, unbroken hit, no pop |
| boss | boss acts | bar, charge, pound, grab slam, phase 2 and the call-in |
| performance | "Crowd: autopilot" windowed, probe R15 | p95 ≤ 16.7 ms |

## B4. Review lenses and the readability rubric

| Lens | Judges | Inputs |
| --- | --- | --- |
| **L1 Warning correctness** | every clause of §1.2: sides, ±20° both, ±55° edge, range, timing equals the wind-up, end on land / whiff / interrupt / grab / KO / despawn, never on the strike coming out, several attackers, heavy, F4's 0.25×, pause, KO view, the finisher's impact frame over the HUD, positional audio direction | `warning_bot`, "Crowd: blind spot", `test_rear_warning*.gd`, corner crops |
| **L2 Crowd readability (first person)** | the rubric below, from full-res sheets and the probe | `crowd_bot` acts, `readability.json` |
| **L3 Archetype tells and identity** | each wind-up from the lens at 3 m and 1 m; taunt vs wind-up; identity at a glance; armor reads; grabs; the pipe drop and pickup; boss phases | archetype bots |
| **L4 Code and layers** | simulation never reads a camera; presentation never writes; no feel numbers in scripts; tokens released on every exit path (hit, KO, despawn, F4 removal, room switch); no `ERROR` from navigation queries before the map sync; determinism; groups left before `queue_free()` | the M3 diff |
| **L5 Fairness and pacing** | R3, R11, R12, R13; flinch-locks; the boss fight is winnable by the autopilot with revives; waves repeat | probe, `crowd_bot` "Crowd: passive" and "Crowd: waves", boss acts |
| **L6 Performance** | R15, spawn hitch, first-knockdown ragdoll hitch, voice budget | windowed crowd act |

**L2 rubric** (yes/no per sheet, with frame references):
1. For every in-view wind-up, can you see the attacker's wind-up pose for most of its length?
2. For every warning, does the corner match where the attacker is?
3. Can you tell each enemy's archetype in every frame it is fully in view?
4. Is there ever a frame where two wind-ups start together?
5. Is the posture ring readable: enemies around you at a distance, not a wall in front?
6. Does any frame show more than half the view covered by enemies outside an attack?
7. Do attackers back off after attacking?
8. Do taunts and strafing ever read as threats?
9. Do armor hits look registered?
10. Would a new player know why they took damage in each hit?

---

---

# Part C: the base plan (vertical slice first, risk first; Part A overrides it)

Written 2026-10-25 for branch `m3/enemy-ai` (cut from `main` at `2847863`, now `0d6f8cd`). Read with: SPEC §5, §6, §7, §8, §11, §12; ARCHITECTURE; the six codemaps in `docs/milestones/M3-codemap/`; CLAUDE.md.

**SPEC §12, M3:** "All archetypes in graybox, the director, flanking, the rear-attack warning, and a 6-enemy crowd test room. **Done when:** a 6-enemy fight is readable, and the warning fires correctly behind-left, behind-right and directly behind."

**Game-boy's M3 answers (2026-10-25), binding on every package:**
- A graybox boss is in M3 (placeholder name; 300 HP, two phases, shoulder charge, grab slam, ground pound; at 50% it turns faster and calls in two Street Punks).
- Enemy grabs on the player (Bruiser grab and headbutt, boss grab slam): a telegraphed wind-up (a dodge or a heavy hit gets out of it); once held, mashing P/K breaks free before the hit; unbroken, the hit lands.
- Defaults taken: a new ~12 x 30 m street-lane crowd room becomes the main scene, with doorway and alley spawn points (some behind the player) and repeating mixed waves of up to 6 enemies, plus a key back to the M2 training room; the KO'd player auto-revives there; enemies don't block; the Pipe Thug drops a pipe the player can take; the full director (attack tokens, blind-spot priority, spread); NavigationAgent3D on a navmesh with avoidance; the rear warning per SPEC §8 with tunables in F1; enemy spawns in the F4 cheat menu; AI state and attack tokens in F3.
- Game-boy can't judge fine grey-block look/feel before the art: take defaults, log them. **Only first-person looks count** (side view is debug-only).
- Opus plans and reviews; Sonnet codes and executes.

---

## 0. The approach in one page

M2 built breadth in parallel and found feel problems in three review rounds afterwards. M3's risks are systemic: every archetype inherits the enemy base, the director and the warning. If wind-ups don't read at 1-4 m in first person, if six bodies bunch or flinch-lock the player, or if the warning ends at the wrong moment, five archetypes built on that base all need rework. So:

1. **Phase 0, contract scaffold (`S0`).** One small package lands every shared hook, signal, field, tuning subgroup, dispatch point and API skeleton on `m3/enemy-ai` before anything branches. After S0, each hot-spot file has exactly one owner per phase (section 3).
2. **Phase 1, the vertical slice.** One archetype, the **Street Punk**, goes end to end: navmesh and avoidance in the new crowd room, enter, approach, the 2.5-4 m posture ring (circle, strafe, taunt), director tokens with the cap, blind-spot priority and spread, a readable held wind-up with its vocal cue, the attack, recover, hit reactions, KO and free, the rear warning, F3 and F4. Four builders in parallel (enemy base + Punk, director, crowd room + waves + F4, HUD rear warning + F3 overlay), then one integration builder.
3. **The slice gate.** The lead and an adversarial review judge 1, 3 and 6 Punks **from first-person captures** (plus corner crops and logs), fix what fails, and lock the feel defaults (ring radius, circle speed, cadence, cap, gap) **before any breadth is built**. The second half of the done-when (the warning behind-left, behind-right and directly behind) is proved here.
4. **Phase 2, widen with the next-riskiest first:** the enemy grab on the player (its own mini-slice: first-person held view and mash), the Kicker (flanker), the Pipe Thug (weapon and drop). Three builders.
5. **Phase 3, the heavies:** the Bruiser (armor, smash, grab and headbutt) and the Boss (two phases, charge, grab slam, pound, adds). Two builders, consuming the merged grab.
6. **Phase 4, the whole fight:** integration, mixed waves, a full adversarial review round (five lenses), fixes, docs, the macOS export to a GitHub Release, the PR, and the Slack DM to Game-boy.

Usage: roughly 1.5 premium 5-hour windows in total (section 9). Every launch is sized to the headroom below the 90% handoff; HANDOFF.md is updated at every phase boundary.

---

## 1. Rules every package follows (copy into every builder prompt)

- **Worktree.** You work only in your absolute worktree path, `cd`-ing there for every command. First run `godot --headless --import --quit` there. Never touch the main checkout or another worktree.
- **Code rules (CLAUDE.md).** Static types everywhere, tabs, `##` doc comments on public API, comment density like the surrounding code. **No numbers in scripts:** attack numbers go in move `.tres` files via `tools/gen_moves.gd` (never only the `.tres`); global tunables go in `game/autoload/tuning_data.gd` as `@export_range` values **in your own subgroup only**; feel numbers are never script constants (a level layout's geometry may be room `@export`s, as `test_room.gd` does). Simulation never reads a camera; presentation only subscribes to `CombatEvents` and reads state.
- **Own only your files** (your section's list). If you need a change elsewhere, stop and report it as a request in your final message; don't make it.
- **Tuning.** Append inside your subgroup, never reformat others. Regenerate `tuning/default.json` for your own tests with `godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd` (the lead regenerates again after every merge; on a merge conflict in that file, take either side and regenerate).
- **Moves.** Regenerate with `godot --headless --import --quit && godot --headless -s tools/gen_moves.gd && godot --headless --import --quit` and check for the line `gen_moves: wrote N moves`. A parse error still exits 0.
- **Tests.** `tools/run_tests.sh -gselect=<file>` while developing; the full `tools/run_tests.sh` before your final commit (about 90 s today; CLAUDE.md's "6 s" is stale). Read the whole output for `SCRIPT ERROR` and `ERROR`. All pass. Keep new crowd tests short (seeded, a few hundred ticks; waves off unless the test is about waves). Wait 5 physics frames after a room's `_ready()` before asserting anything that paths (navigation map sync).
- **Look at it.** Record with `tools/capture_bot.sh <bot.tscn> <your worktree>/captures/<key> "<act filter>" <stills fps>` (S0 adds it; it takes a machine-wide lock so at most two Movie Maker windows run at once). Make sheets with `ffmpeg -loglevel error -y -ss <t> -t <d> -i <avi> -vf "fps=12,scale=480:-1,tile=5x4" -frames:v 1 <sheet>.png`, corner crops with `crop=iw*0.3:ih*0.3:0:0` (top left) and `crop=iw*0.3:ih*0.3:iw*0.7:0` (top right). **Read the sheets.** Judge first person only; side view and F3 are for mechanics. Never commit `captures/`.
- **Commits.** `wip: <key> ...` every 15-20 minutes, pushed. Final commit `M3 <key>: <summary>`, pushed. Every message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Judgement calls.** Write each call you make (decision, at least one alternative not taken, why) to `docs/milestones/M3-calls/<key>.md` (your own file). The lead folds them into `docs/milestones/M3-judgement-calls.md`. Don't ask Game-boy anything; take the default that changes least.
- **Spec departures:** don't implement one. Report it to the lead.
- **Hardware:** 8 CPUs, 8 GB. One Godot process at a time per agent; never leave one running.
- **Your final message:** what you built, test count and result, the sheets you looked at and what they show, requests for files you don't own, open risks.

---

## 2. Pinned contracts (S0 lands these; everyone else consumes them)

These names and semantics are fixed for the whole milestone. A package that needs a different contract asks the lead, who changes it on `m3/enemy-ai` between phases.

### 2.1 Player look (`game/player/player.gd`, S0)
```gdscript
## Flat unit vector of the look (look_yaw only). Simulation-safe: never the camera.
func get_look_forward() -> Vector3
## Signed flat angle in degrees from the look to `point`: 0 ahead, positive left, +-180 behind.
## Measured from global_position (the pose never moves it).
func look_bearing_deg(point: Vector3) -> float
## True when `point` is more than `half_angle_deg` (flat) off the look.
func is_outside_view(point: Vector3, half_angle_deg: float) -> bool
## The holder hook (see 2.2); the player's override: _held == victim and _holding_valid().
func is_holding(victim: CombatActor) -> bool
```
**"Outside the player's view" means `is_outside_view(p, Tuning.data.rear_warning_angle_deg)` everywhere** (the director's blind spot and the warning).

### 2.2 CombatActor hooks (`game/actors/combat_actor.gd`, S0 only; nobody else edits this file in M3)
| Addition | Semantics |
| --- | --- |
| `func _apply_armor(hit: HitInfo) -> void` (virtual, no-op) | Called in `receive_hit()` after damage, `killed`, `health_changed` and the flash, **before** `_cancel_move()`. May set `hit.armor_absorbed = true` (and must then set `hit.reaction = NONE`, `hit.knockback = ZERO`) or change `hit.reaction`/`knockback`. If `hit.armor_absorbed and not hit.killed`: call `_on_armor_absorbed(hit)` (virtual, no-op) and `return true`, skipping the cancel, `_on_hit_received()` and `_apply_reaction()`. |
| `func _on_grabbed(by: CombatActor) -> void` (virtual) | Called at the end of `start_grabbed()`. |
| `func _held_anim() -> StringName` (virtual, returns `&"held"`) | Used by `start_grabbed()` and the held jolt in `_apply_reaction()`. |
| `func is_holding(victim: CombatActor) -> bool` (virtual, returns false) | The holder side's "I still hold this victim". |
| `func break_free(push: Vector3) -> void` | Victim side: `by := holder`; if `by` valid, `by._on_hold_broken(self)`; `release_from_grab(push, false)`; `_invuln_frames = Tuning.data.grab_break_invuln_frames`; emit `CombatEvents.grab_escaped(self, by)`. |
| `func _on_hold_broken(victim: CombatActor) -> void` (virtual, no-op) | Holder side: its victim broke free. |
| `func _keeps_pose_after_strike() -> bool` (virtual, false) | When true, the `_pull_strike` snap to idle (CA:636-640) is skipped (an enemy holder's headbutt). |
| `func abort_move() -> void` | Public: `_cancel_move()` then `_return_to_neutral()`. |
| Pin order | `start_grabbed(by)` sets `process_physics_priority = by.process_physics_priority + 1` (the victim pins after its holder's rig advanced: no one-tick lag); restored to its saved value on release, launch, KO and `reset_state()`. |
| Pin safety | `_pin_to_holder()` also releases (`release_from_grab(Vector3.ZERO, false)`) when the holder `is_gone()`. |

### 2.3 Events (`game/autoload/combat_events.gd`, S0 only)
- `signal grab_escaped(victim: Node3D, holder: Node3D)`: a held victim broke free by mashing.
- `signal boss_phase_changed(boss: Node3D, phase: int)`: 1 at spawn is implicit; emitted on entering phase 2.
No other signal is added in M3. Tokens, AI states and slots are **read** by presentation through the director's read API (2.6) and `debug_state_text()`.

### 2.4 Move data (`game/combat/move_data.gd`, S0)
- `@export_range(0.0, 6.0, 0.01) var reach_m: float = 0.0`: "Flat distance from the attacker's origin to a standing 1.8 m target's origin at which this move's strike connects (0 = not an AI attack). The AI closes to it before winding up, and the rear warning fires within reach_m + rear_warning_range_margin_m." Set per enemy move in the generator and checked by each archetype's rig test against the measured strike (tolerance 0.15 m). The default 0 is omitted by ResourceSaver, so no shipped `.tres` changes.
- Enemy move rules (enforced by `tests/test_move_data.gd` after S0): own id per move (`get_anim() == id`); `magnetism = false`; no `branches`/`auto_next` (G3); startup ≥ the archetype's wind-up floor; `blocked_recoil_frames` 0 for Bruiser and boss moves; grabs and the ground pound `unblockable`; **the 15% rule** (section 2.10).

### 2.5 Enemy base API (`game/enemies/enemy_actor.gd`, skeleton by S0, implemented by P1-ai, owned by P2-grab in phase 2)
`class_name EnemyActor extends CombatActor`. Every AI enemy extends it; `TrainingDummy` does **not** (it stays as it is).
```gdscript
enum AiState { ENTER, APPROACH, POSTURE, ENGAGE, WINDUP, ATTACK, RECOVER, REACT, KO }
@export var archetype: StringName            # &"punk", &"kicker", &"thug", &"bruiser", &"boss"
@export var heavy: bool = false              # Bruiser and boss: larger rear-warning burst, heavy wind-up floor
@export var prefers_blind_side: bool = false # Kicker: the director gives it slots in the blind arc first
@export var voice_pitch_mult: float = 1.0    # AudioDirector reads it duck-typed (deeper heavies)
var ai_state: AiState                         # read-only outside
var has_token: bool                           # read-only outside; set by the director
var blind_priority_granted: bool              # the last grant came from blind-spot priority (F3)
var posture_slot: Vector3                     # Vector3.INF = none
func ai_state_name() -> StringName
func wants_token() -> bool                    # POSTURE, attack cooldown over, ENTER done, FREE
func grant_token(blind: bool) -> void         # director only
func revoke_token() -> void                   # director only (player became unhittable, timeout)
func set_slot(pos: Vector3) -> void           # director only
func attack_range_m() -> float                # reach_m of the attack it will throw next
func force_attack(index: int = 0) -> void     # bots/tests: skip the token and wind up now (from FREE)
func enter_from(spawn_pos: Vector3, lane_point: Vector3) -> void  # spawner: walk in from a spawn point
static func windup_move(move: MoveData, heavy: bool) -> MoveData   # wind-up mult and floors, cached per id
```
Groups: every EnemyActor joins `"actor"` (base), `"enemy"` and `"ai_enemy"`; the boss also `"boss"`. A dead enemy is `health <= 0` (not `is_ko()`); once `is_gone()`, it leaves all groups **then** `queue_free()`s. Behaviour runs only in `ActorState.FREE` (plus turning during WINDUP); every other state is CombatActor's.

### 2.6 Director API (`game/enemies/enemy_director.gd`, skeleton by S0, implemented by P1-director)
`class_name EnemyDirector extends Node`, in group `"enemy_director"`.
```gdscript
static func find(tree: SceneTree) -> EnemyDirector
static func ensure(host: Node) -> EnemyDirector   # find, or add one under host (an enemy spawned by F4 in the training room)
func release_token(enemy: EnemyActor) -> void      # the enemy's attack ended, was interrupted, or timed out
func slot_for(enemy: EnemyActor) -> Vector3
# Read API for F3 and tests (presentation reads, never writes):
func debug_token_holders() -> Array[EnemyActor]
func debug_slot_of(enemy: EnemyActor) -> Vector3    # Vector3.INF if none
func debug_ring() -> Vector2                        # posture ring min, max (m)
func attacker_cap() -> int                          # 0 = unlimited
func debug_waiting() -> Array[EnemyActor]
```
It runs its own `_physics_process` on `delta * TimeController.sim_scale()` (it isn't an actor, so it keeps running through hitstop), seeded RNG (`rng_seed` export).

### 2.7 Spawner API (`game/level/encounter_spawner.gd`, P1-room)
`class_name EncounterSpawner extends Node3D`, group `"encounter_spawner"`.
```gdscript
func spawn_enemy(id: StringName, at: Vector3, yaw: float, from_wave := false) -> EnemyActor
func spawn_adds(id: StringName, count: int, near: Vector3) -> Array[EnemyActor]  # boss phase 2: nearest free spawn points
func alive_count() -> int                 # ai_enemy members with health > 0
func set_waves_enabled(on: bool) -> void
var spawn_points: Array[Dictionary]       # {position, yaw, tag (&"doorway"|&"alley"), lane_point}
var scene_override: Dictionary            # tests: id -> PackedScene
```

### 2.8 Enemy catalog (`game/enemies/enemy_catalog.gd`, S0)
`class_name EnemyCatalog`. `const ENTRIES: Array[Dictionary]` with `{id, label, scene}` for `dummy` (the training dummy), `punk`, `kicker`, `thug`, `bruiser`, `boss` (paths `res://game/enemies/<id>/<file>.tscn`). `static func available() -> Array[Dictionary]` (only scenes that `ResourceLoader.exists()`), `static func scene(id) -> PackedScene`, `static func body_size(id) -> Vector2` (radius, height; read once from an instance and cached). The cheat menu and the spawner read it; nothing hard-codes enemy paths elsewhere.

### 2.9 Rear warning (`game/ui/rear_warning.gd`, P1-hud)
`class_name RearWarning extends Control`; `signal shown(side: StringName, count: int, heavy: bool)` (`&"left"`, `&"right"`); `signal hidden(side: StringName)`; `func corner_state(side) -> Dictionary` (`{active, count, heavy, alpha, size_px}`), `func advance(delta)`. Bots print the signals as `W+`/`W-` log lines.

### 2.10 The 15% rule (SPEC §4: "a single knockdown should never take more than 15% of [the player's 100 health], except from the boss")
Interpreted as: for every enemy **attack** (the chain of moves one token buys), if any move in it has reaction KNOCKDOWN, LAUNCH or THROWN, the chain's total damage is at most 15. The boss is exempt. Enforced by a data test over the per-archetype tables (each table lists its attack chains). So the Pipe Thug's third swing staggers (its 3 x 10 chain would otherwise be a 30% knockdown), and the Bruiser's headbutt and smash are 15 each with nothing before them.

### 2.11 Tuning layout (S0 creates every subgroup with a seed tunable; one owner per subgroup)
Group **"Enemies"** (existing `attacker_cap`, `blind_spot_priority`, `windup_mult` stay first, now with `##` docs), then subgroups in this order:

| Subgroup | Owner | Seed (S0) |
| --- | --- | --- |
| Wind-up | P1-ai | `windup_min_frames_grunt` 18, `windup_min_frames_heavy` 30 |
| Posture | P1-ai | `posture_ring_min_m` 2.5, `posture_ring_max_m` 4.0 |
| Navigation | P1-ai | `enemy_avoid_radius_m` 0.45 |
| Director | P1-director | `director_min_attack_gap_s` 0.35 |
| Waves | P1-room | `waves_enabled` true, `wave_max_alive` 6 |
| Street Punk | P1-ai | `punk_health` 30 |
| Kicker | P2-kicker | `kicker_health` 25 |
| Pipe Thug | P2-thug | `thug_health` 35 |
| Enemy grabs | P2-grab | `grab_break_presses` 8, `grab_break_invuln_frames` 20 |
| Bruiser | P3-bruiser | `bruiser_health` 80 |
| Boss | P3-boss | `boss_health` 300 |

Group **"Rear warning"** (P1-hud appends): S0 adds `rear_warning_behind_deg` 20 and `rear_warning_range_margin_m` 1.0, and `##` docs on the four existing ones. Group **"Debug"**: S0 adds `ai_frozen` (bool, false). `tests/test_tuning_panel.gd:390` asserts the exact Enemies subgroup list above (S0 edits it).

### 2.12 Rooms and keys
- `test_room.gd`/`.tscn` is **frozen** for M3 (11 test files and 3 bots pin it).
- F6 = `switch_room` (S0, in `GameInput`): `TimeController.clear()`, unpause, then `change_scene_to_file()` to the other of `GameInput.ROOM_SCENES = ["res://game/level/crowd_room.tscn", "res://game/level/test_room.tscn"]` (does nothing if the target doesn't exist yet). A help row "Switch room: crowd street / training".
- Room contract for bots and tests (the crowd room): direct-child HUD, directors and TuningOverlay; properties `player`, `player_start`, `player_yaw_deg`, `with_presentation`, `waves_enabled_on_start`, `rng_seed`, `spawner`, `director`; `func enemies() -> Array[EnemyActor]`.

### 2.13 Placeholder poses and animation dispatch (S0)
- `MovePoses.windup_hold_at: float = -1.0` (and optional `windup_hold: Dictionary` delta): `build_move` adds a second wind-up key at `windup_hold_at * startup` (the held telegraph); `mirrored()` mirrors it. Enemy moves use `windup_at` 0.4-0.6 and `windup_hold_at` about 0.8.
- `PlaceholderPoses._recipe()` ends with `return PlaceholderEnemyPoses.recipe(id, g, wg)` instead of `return null`; `HumanoidRig.has_anim()` also asks `PlaceholderEnemyPoses.has_recipe(id)`.
- `PlaceholderEnemyPoses` (`game/actors/poses/placeholder_enemy_poses.gd`) tries, in order, `EnemyPosesPunk`, `EnemyPosesKicker`, `EnemyPosesThug`, `GrabPoses`, `EnemyPosesBruiser`, `EnemyPosesBoss`, each in its own file under `game/actors/poses/` with `const MOVE_IDS: Array[StringName] = []` and `static func recipe(id, g, wg) -> PlaceholderPoses.MovePoses` returning null (stubs). Shared enemy pose helpers (telegraph deltas) live in the dispatcher file, written by S0.
- New named animation ids in `PlaceholderAnims.ANIM_IDS`: `taunt` (non-looping), `brace` (non-looping), `run_forward` (looping), `hold_collar`, `held_collar`, `held_lift` (looping). Their `build_named` cases delegate to `EnemyNamedPoses.named(id, g)` (taunt), `EnemyPosesBruiser.named(id, g)` (brace), `EnemyPosesBoss.named(id, g)` (run_forward) and `GrabPoses.named(id, g)` (the three grab poses), each returning `{length, keys}`; the stubs hold the stance.
- Generator: `_build_moves()` ends by calling `_build_enemy_moves()`, which calls `_punk_moves()`, `_kicker_moves()`, `_thug_moves()`, `_grab_moves()`, `_bruiser_moves()`, `_boss_moves()`, each a stub with a doc line between them, plus a helper `_enemy(move, reach_m, recoil_frames, unblockable := false) -> MoveData` (sets `magnetism = false` too).

---

## 3. Hot spots: who owns what, when

| File | S0 | Phase 1 | Phase 2 | Phase 3 | Phase 4 |
| --- | --- | --- | --- | --- | --- |
| `game/actors/combat_actor.gd` | S0 (all hooks, 2.2) | nobody | nobody | nobody | lead-approved fixers only |
| `game/player/player.gd` | S0 (look API, `is_holding`) | nobody (slice fixers if the gate asks) | **P2-grab** | nobody | fixers |
| `game/enemies/enemy_actor.gd` | S0 (skeleton) | **P1-ai** | **P2-grab** (grab attack kind) | nobody (archetypes override in their own class) | fixers |
| `game/enemies/enemy_director.gd` | S0 (skeleton) | **P1-director** | nobody | nobody | fixers |
| `game/autoload/tuning_data.gd` + `tuning/default.json` | S0 (layout 2.11) | append in own subgroup | same | same | lead regenerates the preset after every merge |
| `game/autoload/combat_events.gd` | S0 | frozen | frozen | frozen | frozen |
| `game/combat/move_data.gd`, `hit_info.gd`, `combat_types.gd` | S0 (`reach_m`) | frozen | frozen | frozen | frozen |
| `tools/gen_moves.gd` | S0 (stubs) | P1-ai: `_punk_moves()` only | `_kicker_moves()`, `_thug_moves()`, `_grab_moves()` by their owners | `_bruiser_moves()`, `_boss_moves()` | lead reruns after merges (byte-identical) |
| `game/actors/placeholder_poses.gd`, `placeholder_anims.gd`, `humanoid_rig.gd` | S0 | frozen (recipes go in per-area pose files) | frozen | frozen | perf fixer only (library cache) |
| `game/actors/poses/*.gd` | S0 stubs | P1-ai: punk + named | kicker, thug, grab files | bruiser, boss files | |
| `tests/test_move_data.gd`, `test_humanoid_rig.gd` | S0 (table discovery) | frozen: each package owns `tests/enemy_moves/<arch>_table.gd` and `tests/test_enemy_moves_<arch>.gd` | same | same | |
| `tests/test_tuning_panel.gd` | S0 (`:390`) | frozen | frozen | frozen | |
| `game/autoload/game_input.gd`, `help_overlay.gd`, `tests/test_ui.gd` (F-keys) | S0 | test_ui.gd: P1-hud appends only | frozen | frozen | |
| `game/ui/hud.gd`, `hud.tscn` | | **P1-hud** | **P2-grab** (MASH prompt) | nobody | fixers |
| `game/ui/debug_draw.gd` | | **P1-hud** | nobody | nobody | fixers |
| `game/ui/cheat_menu.gd` | | **P1-room** | nobody | nobody | fixers |
| `game/audio/audio_director.gd` | | **P1-hud** (voice budget, pitch mult) | **P2-grab** (escape sound) | nobody | fixers |
| `game/weapons/weapon.gd` | | nobody | **P2-thug** (`drop()`) | nobody | |
| `game/level/test_room.*` | frozen | frozen | frozen | frozen | frozen |
| `game/level/crowd_room.*`, `encounter_*`, `room_kit.gd`, `nav_baker.gd` | | **P1-room** | nobody | nobody | fixers |
| `tests/bot/combo_bot.gd` | S0 (`_room_scene()` hook) | frozen | frozen | frozen | |
| `tests/bot/crowd_bot.gd` | | P1-room (skeleton + act-file loader) | frozen; acts live in `tests/bot/acts/<key>_acts.gd`, one file per package | same | |
| `project.godot` | S0 (`[navigation]`) | lead: main scene at the slice merge | | | lead: export version |
| `docs/ARCHITECTURE.md` | S0: new section with one stub heading per package | each package fills **only its own heading** | same | same | lead: title, Ownership |
| `docs/milestones/M3-judgement-calls.md`, `README.md`, `docs/HANDOFF.md` | lead | lead | lead | lead | lead |

**Why this can't conflict textually:** after S0, parallel packages touch only (a) files nobody else in their phase owns, (b) their own `@export_subgroup` region in `tuning_data.gd`, which S0 separated by other subgroups' header and seed lines, (c) their own stub function in `gen_moves.gd`, separated by doc lines, (d) their own pre-made heading in ARCHITECTURE.md. Generated `.tres` files are per move id. `tuning/default.json` is regenerated by the lead after every merge, never hand-merged.

---

## 4. Phase 0: the contract scaffold

### S0-scaffold
- **Phase:** 0. Worktree `.worktrees/m3-scaffold`, branch `m3/scaffold` from `m3/enemy-ai`. The lead reviews the diff and merges before any phase 1 branch is cut.
- **Goal:** land every contract in section 2, mechanically, with no behaviour change to the M2 game. 537/537 tests still pass plus the new ones.
- **Owned files:**
  - `project.godot` (add `[navigation]`: `3d/default_cell_height=0.1`, `avoidance/thread_model/avoidance_use_multiple_threads=false`, `world/map_use_async_iterations=false`, `world/region_use_async_iterations=false`; no main-scene change);
  - `game/actors/combat_actor.gd` (2.2 only);
  - `game/player/player.gd` (2.1 only);
  - `game/autoload/combat_events.gd` (2.3), `game/combat/move_data.gd` (2.4), `game/autoload/tuning_data.gd` + `tuning/default.json` (2.11), `game/autoload/game_input.gd` + `game/ui/help_overlay.gd` (2.12);
  - `game/actors/placeholder_poses.gd`, `placeholder_anims.gd`, `humanoid_rig.gd` (2.13 only), new `game/actors/poses/{placeholder_enemy_poses,enemy_poses_punk,enemy_poses_kicker,enemy_poses_thug,grab_poses,enemy_poses_bruiser,enemy_poses_boss,enemy_named_poses}.gd` (stubs);
  - `tools/gen_moves.gd` (stubs and `_enemy()`), `tools/capture_bot.sh` (new);
  - `game/enemies/enemy_catalog.gd`, `game/enemies/enemy_actor.gd` (skeleton: the 2.5 API with doc comments, exports, enum, `_ready()` that sets `team = 1`, joins `"enemy"` and `"ai_enemy"` before `super._ready()`, and stub bodies that keep it standing idle), `game/enemies/enemy_director.gd` (skeleton: 2.6 signatures, `find`/`ensure` working, everything else inert);
  - tests: `tests/test_move_data.gd` (table discovery), `tests/enemy_moves/{punk,kicker,thug,grab,bruiser,boss}_table.gd` (empty `const MOVES := {}` and `const ATTACKS := []`), `tests/enemy_move_checks.gd` (shared static helpers, below), `tests/test_m3_contracts.gd` (new), `tests/test_tuning_panel.gd` (`:390` only), `tests/test_ui.gd` (the F-key help assertion: add "F6"), `tests/test_bot_scripts_compile.gd` (new: loads every `res://tests/bot/**/*.gd`);
  - `tests/bot/combo_bot.gd` (`_room_scene() -> PackedScene` returning `ROOM`; `_ready()` instantiates `_room_scene()`);
  - `docs/ARCHITECTURE.md`: a new section "## Enemy AI and the rear warning (Milestone 3)" holding section 2 of this plan as the contract, then stub headings, each with the line "(Filled by <key>.)": "### Enemy base and the Street Punk" (P1-ai), "### Director" (P1-director), "### Crowd room, navigation and waves" (P1-room), "### Rear warning and the F3 AI overlay" (P1-hud), "### Enemy grabs on the player" (P2-grab), "### Kicker" (P2-kicker), "### Pipe Thug and the dropped pipe" (P2-thug), "### Bruiser" (P3-bruiser), "### Boss" (P3-boss);
  - `docs/milestones/M3-calls/S0-scaffold.md`.
- **Details:**
  - `tests/test_move_data.gd`: discover `tests/enemy_moves/*_table.gd` with DirAccess. Each table file has `const MOVES := {id: {damage, tier, reaction, hitbox (&"sphere:<Point>"|&"arc"|&"none"), unblockable, recoil, guard_mult, reach_m, min_startup}}` and `const ATTACKS := [{name, moves: [ids], boss: bool}]`. `test_moves_folder_holds_only_table_moves` accepts TABLE ∪ every enemy table; `test_blocking_fields` checks enemy ids from their table fields (and keeps the player rules for player ids); `test_finisher_tier_matches_branch_graph` iterates player ids only; new `test_enemy_moves_follow_the_enemy_rules` (2.4: magnetism off, no branches/auto_next, startup ≥ min_startup, `reach_m > 0`) and `test_no_enemy_knockdown_costs_more_than_15_percent` (2.10; the 15 is a test literal citing SPEC §4). With empty tables both pass vacuously.
  - `tests/enemy_move_checks.gd` (static, preload it): `check_clip(t, rig, move)` (length = total frames, a wind-up key in 40-60% of startup, the held key at `windup_hold_at`, returns to guard); `check_joint_limits(t, pose)` against `PlaceholderBody.ragdoll_specs()` (G7: upper-arm forward raise ≤ about 140°, knees -130..0, elbows 0..150); `measure_reach(rig_height, move) -> float` (flat distance from the attacker's origin at which the strike point first touches a standing 1.8 m `_place_target` rig's hurtboxes, as `test_humanoid_rig.gd` measures Strike reach); `check_reach(t, move, rig_height)` (|measured - move.reach_m| ≤ 0.15); `check_fp_telegraph(t, move, rig_height, distance_m)` (adapted from `test_dummy_jab_telegraphs_its_wind_up`, `test_humanoid_rig.gd:2069`: the wind-up pose seen from the defender's first-person lens at `distance_m` shows the striking hand or foot in view and the attacker's head visible).
  - `tools/capture_bot.sh <res bot scene> <out dir> "<act filter>" [stills fps]`: `mkdir`-based lock with two slots under `$HOME/.cache/beat-em-up-capture/` (wait, then take a free slot; release with `trap`), `touch <out dir>/.gdignore`, then `godot --path <repo of the script> --write-movie <out>/bot.avi --fixed-fps 60 --resolution 1280x720 <scene> -- --act=<filter> > <out>/bot.log 2>&1`, then stills with ffmpeg if fps given. The path to the project is the script's own worktree (`$(dirname "$0")/..`), so it works from any worktree.
  - `GameInput.BINDINGS[&"switch_room"] = [KEY_F6]` and the handler (2.12). `HelpOverlay.DEBUG_ROWS` gets `["Switch room: crowd street / training", &"switch_room"]` after the sparring row. Check `test_ui.gd:201-216` (corners) still passes with the extra row.
  - `tests/test_m3_contracts.gd`: the look API (bearing signs: a point at 135° left gives +135, right -135, behind ±180; `is_outside_view` at 54/56°); `_apply_armor` absorbing a hit keeps a WINDUP running and emits no `windup_ended` (a test subclass of CombatActor defined in the test file); `break_free` releases, gives invulnerability, calls the holder hook and emits `grab_escaped`; the pin priority is set and restored; `_held_anim()` is played; `abort_move()`; `EnemyCatalog.available()` returns only existing scenes; `EnemyActor` skeleton instantiates in a bare scene and joins its groups; `EnemyDirector.ensure()` is idempotent; `windup_hold_at` keys a clip.
  - Run the generator: the 26 shipped `.tres` must be byte-identical (prove with `git status`).
- **Interfaces provided:** all of section 2. **Consumed:** none.
- **Tunables added:** section 2.11 seeds, the two rear-warning seeds, `ai_frozen`, `grab_break_invuln_frames` (read by `break_free`).
- **Captures:** none (no visible change). Run `tests/bot/combo_bot.tscn` once with the act "Jab" through `capture_bot.sh` to prove the wrapper and lock work, and look at one sheet.
- **Acceptance:** full suite green (537 + new), no SCRIPT ERROR/ERROR; the generator reproduces every shipped `.tres` byte for byte; `tuning/default.json` regenerated; the training room plays exactly as M2 (combo bot "Jab" sheet unchanged); F6 does nothing harmful while the crowd room doesn't exist.
- **Size:** phase-3-A-sized builder (about 6-8% of a 5-hour window). Mechanical; the lead reviews every hunk of `combat_actor.gd` against 2.2.

---

## 5. Phase 1: the vertical slice (four builders in parallel, then integration)

Cut four worktrees from `m3/enemy-ai` after S0 merges: `git worktree add .worktrees/m3-<key> -b m3/<key> m3/enemy-ai`, then import in each. At most four builders at once; recordings serialize through the capture lock.

### P1-ai: the enemy base and the Street Punk
- **Goal:** one archetype that does everything SPEC §7 asks of a grunt, in any room: walks in, paths to its posture slot, circles/strafes/taunts facing the player, takes a token, closes to reach, winds up with a held, readable telegraph and the vocal cue (free from `start_move(..., windup = true)`), strikes, recovers, gives the token back, reacts to hits (light hits interrupt its wind-up), gets up with invulnerability, KOs, blinks off and frees itself. Also the shared armor rule the heavies will use.
- **Owned files:** `game/enemies/enemy_actor.gd`, `game/enemies/enemy_attack.gd` (new: `class_name EnemyAttack extends RefCounted`: `moves: Array[MoveData]`, `kind: StringName` (`&"strike"`; `&"grab"` reserved for P2), `weight_property: StringName` (a Tuning name for its pick weight), `heavy: bool`), `game/enemies/punk/street_punk.gd` + `street_punk.tscn`, `game/actors/poses/enemy_poses_punk.gd`, `game/actors/poses/enemy_named_poses.gd`, `tools/gen_moves.gd` (`_punk_moves()` body), `game/combat/moves/punk_*.tres`, `tests/enemy_moves/punk_table.gd`, `tests/test_enemy_moves_punk.gd`, `tests/test_enemy_actor.gd`, `tests/bot/punk_bot.gd` + `.tscn` (extends `combo_bot.gd`, the training room), tuning subgroups Wind-up, Posture, Navigation, Street Punk, ARCHITECTURE heading "Enemy base and the Street Punk", `docs/milestones/M3-calls/P1-ai.md`.
- **The base, step by step:**
  1. **Setup** (`_ready()`): health from the archetype's tunable before `super._ready()` (subclass hook `_health_tunable() -> StringName`), `_rng.seed = hash(String(name))`, a `NavigationAgent3D` child configured from "Navigation" (avoidance on, `radius`, `height = body_height`, `max_speed` ≥ every desired speed, `path_desired_distance` 0.5, `target_desired_distance` 0.3, `neighbor_distance`, `time_horizon_agents`), `velocity_computed` only stores `_safe_velocity` (the **latched** pattern, godot-navigation codemap §5.2). Re-apply agent settings on `Tuning.changed`. Live `max_health` re-read keeping the share left (as `TrainingDummy`).
  2. **Moving** (FREE only): every sim tick, `_nav.velocity = desired`; `sim_velocity.x/z = _safe_velocity.x/z` (last tick's answer); never call `move_and_slide()`. With no navmesh (`NavigationServer3D.map_get_iteration_id(map) == 0` or an empty path, e.g. the training room) steer straight at the target. Retarget every `enemy_retarget_ticks`, staggered by name hash. Flat XZ distances only. In non-FREE states submit the real `sim_velocity` so neighbours steer around it. Locomotion: `rig.play_locomotion(local, speed/ratio)` with the local (x right, y forward) direction, so strafing reads as `walk_left/right`. Stall detection: no progress for `enemy_stuck_s` asks the director for a new slot.
  3. **Facing:** turn toward the player at `enemy_turn_rate`, in POSTURE, ENGAGE and WINDUP (WINDUP at `windup_track_deg_per_s`, so a late sidestep makes it miss). Never during ATTACK active frames.
  4. **AI states** (an overlay on ActorState, never written into it): ENTER (walk from the spawn to `lane_point`; no token), APPROACH (path to `posture_slot`), POSTURE (at the slot: circle along the ring tangent at `posture_circle_speed_mps`, switch direction every `posture_strafe_switch_s` ± jitter, pause, sometimes `taunt` with `posture_taunt_chance`, never closer than `posture_ring_min_m`), ENGAGE (has a token: close to `attack_range_m() - engage_margin_m` at `engage_speed_mps`; give the token back after `engage_timeout_s`), WINDUP/ATTACK (mirrors the move), RECOVER (hold `recover_hold_s`, then release the token, start the attack cooldown, back to APPROACH), REACT (any state CombatActor put it in: hitstun, stagger, launched, downed, get-up, grabbed; the token is released at once), KO.
  5. **Attacking:** zero horizontal `sim_velocity` (the self-propelled slide trap), then `start_move(windup_move(chain[0], heavy), 1, &"root", true)` from `_tick_control()`. Follow-up links of the chain start from `_on_move_finished()` with `windup = false` (one telegraph per attack). The base `_plan_lunge()` does nothing at start; `_on_move_frame(move, move.startup)` applies `set_lunge(forward, move.free_lunge, move.active)` (a step-in during the strike, never a slide through the telegraph).
  6. **`windup_move(move, heavy)`:** a duplicate with `startup = max(floor, round(startup * windup_mult))` where floor is `windup_min_frames_heavy` or `_grunt`; cached in a static dictionary keyed by `move.id` + mult + floor; cleared on `Tuning.changed` for `""`, `windup_mult`, the floors and `moves/<id>/*`. Compare moves by `move.id` everywhere (`hit.move` is the duplicate).
  7. **Armor** (data-driven, used by the Bruiser and the boss): `@export var armor_light: bool`, `armor_heavy_to_stagger: bool`, `armor_finisher_to_stagger: bool`. `_apply_armor(hit)`: never on a killing hit; LIGHT tier and not `breaks_armor` with `armor_light` → absorbed (`hit.armor_absorbed`, reaction NONE, knockback zero: the damage lands, the wind-up keeps going, no flinch); HEAVY with `armor_heavy_to_stagger` → STAGGER; FINISHER with `armor_finisher_to_stagger` → STAGGER. `_on_armor_absorbed()` plays `brace` additively (or nothing) and keeps the move running. Grunts leave all flags off, so **light hits interrupt grunt wind-ups** (CombatActor's default cancel).
  8. **Death:** at `health <= 0` release the token and stop asking; on `is_gone()` (from `_tick_ko()`): disable avoidance, `remove_from_group` for `"ai_enemy"`, `"enemy"`, `"actor"` (and `"boss"`), then `queue_free()`.
  9. **Debug:** `debug_state_text()` = base text + a third line `"AI <STATE>  slot <n>"` + `"  TOKEN"` while holding one + `" (blind)"` when `blind_priority_granted`. Keep it short (six labels stack).
  10. `ai_frozen` (Debug tunable): stand idle, face the player, request nothing.
  11. With no director in the tree, `EnemyDirector.ensure(get_parent())` once in `_ready()` (deferred), so an F4 spawn in the training room behaves the same.
- **The Street Punk:** `archetype = &"punk"`, `max_health` from `punk_health` (30), colors distinct from the dummy (pick a saturated jacket color; 4-6 rig colors), attacks: the **two-hit punch** (chain `punk_jab` → `punk_cross`) and the **shove** (`punk_shove`), picked by `punk_shove_chance`. Moves in `_punk_moves()` (starting values; reach_m measured by your rig test):
  | id | frames (S/A/R) | dmg | tier | reaction | hitbox | notes |
  | --- | --- | --- | --- | --- | --- | --- |
  | `punk_jab` | 22/3/14 | 6 | LIGHT | FLINCH | sphere RightFistPoint 0.14 | recipe: `PlaceholderPoses._dummy_jab(g)`'s strike, a fresh cocked wind-up, `windup_at` 0.5, `windup_hold_at` 0.8; recoil 20 |
  | `punk_cross` | 8/3/16 | 6 | LIGHT | FLINCH | sphere LeftFistPoint 0.14 | follow-up, no wind-up of its own; strike from `_jab_1(g)`; recoil 14 |
  | `punk_shove` | 20/3/18 | 6 | LIGHT | STAGGER | spheres both FistPoints 0.16 | strike from `_shove(g)`; wind-up: hands drawn to the chest, torso back; knockback z 3.5; recoil 14 |
  The Punk table lists `ATTACKS := [{name "two-hit punch", moves [punk_jab, punk_cross], boss false}, {name "shove", moves [punk_shove], boss false}]`. `named(&"taunt", g)`: about 1.1 s, guard → a beckoning chin-up pose → guard (non-looping).
- **Interfaces provided:** 2.5 implemented; the armor rule; `EnemyAttack`. **Consumed:** 2.2, 2.4, 2.6 (calls `release_token`, receives `grant_token`/`set_slot`; with the S0 skeleton director, test with `force_attack()` and a test-local stub director), catalog id `punk`.
- **Tunables (append):** Wind-up: `windup_track_deg_per_s`. Posture: `posture_circle_speed_mps` 1.1, `posture_strafe_switch_s` 1.6, `posture_strafe_jitter_s` 0.6, `posture_pause_s` 0.5, `posture_taunt_chance` 0.12, `approach_speed_mps` 2.6, `engage_speed_mps` 3.0, `engage_margin_m` 0.1, `engage_timeout_s` 2.0, `recover_hold_s` 0.35, `enemy_turn_rate` 6.0. Navigation: `enemy_avoid_horizon_s` 0.75, `enemy_avoid_neighbor_m` 6.0, `enemy_waypoint_reach_m` 0.5, `enemy_slot_reach_m` 0.3, `enemy_retarget_ticks` 6, `enemy_max_speed_mps` 6.0, `enemy_stuck_s` 1.0. Street Punk: `punk_shove_chance` 0.3, `punk_attack_cooldown_s` 1.4, `punk_speed_mult` 1.0. (Numbers are defaults; ranges wide enough for F1.)
- **Tests:** `test_enemy_moves_punk.gd` (every helper in `enemy_move_checks.gd` on each Punk move: clip timing, held wind-up, joint limits, reach, FP telegraph at 1.0 m and 2.5 m); `test_enemy_actor.gd` in the training room and in a tiny code-built navmesh arena inside the test: spawn → ENTER → APPROACH → POSTURE within N frames; never closer than the ring while posturing; `force_attack()` → WINDUP lasting exactly the floored, scaled startup; `windup_mult` 0.25 is floored at 18; the wind-up does not slide (position change ≤ 1 cm during WINDUP); a light hit in WINDUP cancels it (`windup_ended(true)`) and releases the token; armor flags (a test subclass): light absorbed keeps WINDUP and lands damage, heavy staggers; death releases the token at the killing blow; vanish removes groups before free (same-frame group scan sees it gone); `ai_frozen`; deterministic positions across two identical runs (hash).
- **Captures (judge first person):** `punk_bot` acts in the training room (no navmesh: straight steering): "Punk walks in and postures" (player turns slowly to keep it in view), "Punk wind-up at 1 m" (`force_attack`, player still, F3 off), "Punk two-hit punch lands", "Punk shove", "Punk jab hit out of the wind-up", "Punk knocked down, gets up, KO and blink-off", "Three Punks posture" (spawned around the player). Sheets at 12 fps around each wind-up.
- **Acceptance:** all tests green; in the sheets the cocked fist and the hold read clearly in first person at 1 m (the striking hand inside the view during the hold) and the enemy's head stays visible; no sliding through a telegraph; posture reads as circling, not jittering; the token-free `force_attack` path and the token path both end in RECOVER then POSTURE.
- **Size:** larger than WP4 (about 10-12%). The biggest slice package.

### P1-director: tokens, blind-spot priority, spread
- **Goal:** SPEC §7 director rules for any number of EnemyActors: at most `attacker_cap` attack at once (0 = unlimited), blind-spot enemies get token priority, posturing enemies spread all the way around the player on the 2.5-4 m ring, no flinch-lock.
- **Owned files:** `game/enemies/enemy_director.gd`, `tests/test_enemy_director.gd`, tuning subgroup Director, ARCHITECTURE heading "Director", `docs/milestones/M3-calls/P1-director.md`.
- **Behaviour:**
  1. **Discovery:** each tick, members of `"ai_enemy"` with `health > 0` and not `is_gone()`. Freed or dead holders are pruned.
  2. **Player open?** No grants while the player is missing, `health <= 0`, `is_downed()`, `is_flying()`, `is_invulnerable()`, or GRABBED (only its holder may hit it), or within `director_revive_grace_s` after `CombatEvents.revived` for the player. If the player becomes closed while an enemy holds a token but hasn't started its wind-up, `revoke_token()`.
  3. **Grants:** candidates = `wants_token()`. Order: first the blind ones (`player.is_outside_view(e.global_position, Tuning.data.rear_warning_angle_deg)`) that win a roll `rng.randf() < blind_spot_priority` (so 1.0 always jumps the queue, 0 ignores the blind spot), then the longest waiting. Grant while holders < cap (cap 0 = no limit) and at least `director_min_attack_gap_s` since the last grant (the anti-flinch-lock pacing). Mark `blind_priority_granted`.
  4. **Timeout:** a holder still holding after `director_token_timeout_s` is revoked.
  5. **Slots (spread):** the posturing set (POSTURE/APPROACH/ENGAGE-less) gets target angles evenly spaced over 360° around the player (`360 / n`, plus a per-enemy jitter of `director_spread_jitter_deg` from its name hash), keeping the current rotation of the arrangement (assign by the smallest total angular change, greedy is fine for n ≤ 6). Enemies with `prefers_blind_side` take the slots nearest directly behind the look first. Radius per enemy: between `posture_ring_min_m` and `posture_ring_max_m` by hash. Recompute every `director_reslot_s`, or when the player moved more than `director_reslot_move_m`, or when an enemy reports stalling. Snap each slot onto the navmesh (`map_get_closest_point`, only after `map_get_iteration_id > 0`); if the snap moved it more than `director_slot_snap_tolerance_m`, try the next angle step (`director_slot_retry_deg`) both ways. Push with `set_slot()`.
  6. Timers on `delta * TimeController.sim_scale()`; seeded RNG.
- **Interfaces provided:** 2.6 implemented, including the read API. **Consumed:** 2.1, 2.5 (test against **stub enemies defined in the test file**, `extends EnemyActor`, overriding `_tick_control()` to do nothing and `wants_token()` to a test flag, so P1-ai's behaviour can't affect these tests after the merge).
- **Tunables (append to Director):** `director_reslot_s` 1.5, `director_reslot_move_m` 1.0, `director_spread_jitter_deg` 12, `director_slot_snap_tolerance_m` 0.5, `director_slot_retry_deg` 15, `director_revive_grace_s` 1.5, `director_token_timeout_s` 4.0.
- **Tests:** cap 3 with six wanting → exactly 3 holders, the fourth only after a release and the gap; cap 0 → all, still paced by the gap; blind priority 1.0: a blind waiter beats an older in-view waiter every time; 0.0: age order; the roll is deterministic per seed; no grants while the player is KO, downed, in get-up invulnerability, grabbed, or in the revive grace; revoke when the player closes before a wind-up; timeout; slots: n = 1..6 evenly spread (max angular gap ≤ 360/n + 2 × jitter), stable when the player stands still (no reassignment churn), blind-side preference takes the rear slot; slot snapping rejects a slot inside a crate (a small code-built navmesh in the test); dead and freed holders pruned.
- **Captures:** none required in isolation (mechanics are headless); the slice integration records it. Optional: a side-view F3 sheet once P1-hud's overlay is merged.
- **Acceptance:** tests green; read API exact; zero dependence on presentation.
- **Size:** WP1-sized builder (about 6-8%).

### P1-room: the crowd room, navigation, waves and F4 spawns
- **Goal:** the ~12 x 30 m street lane with doorway and alley spawn points, a baked navmesh, repeating mixed waves of up to 6 (Punks only until phase 2 merges, then mixed from the catalog), the player with an avoidance obstacle and auto-revive, the full presentation stack, F4 "spawn any enemy at the crosshair", and the crowd bot skeleton.
- **Owned files:** `game/level/crowd_room.gd` + `crowd_room.tscn`, `game/level/room_kit.gd` (static: environment, `add_box(parent, pos, size, material)`, visual boxes, flat materials, `spawn_player(room, pos, yaw)` with `auto_revive = true` and a `NavigationObstacle3D` child of radius `player_avoid_radius_m`, `build_presentation(room)` adding camera director, HUD, debug draw (if none), TuningOverlay and the VFX/Audio/Rumble directors **as direct children**), `game/level/nav_baker.gd` (static `bake(geometry_root, settings) -> NavigationRegion3D`: parse with `PARSED_GEOMETRY_STATIC_COLLIDERS`, mask = world bit, synchronous bake, roof post-filter `drop_roof_polygons(max_floor_y)`, region navmesh set before `add_child`), `game/level/spawn_room_check.gd` (static `has_room(space, radius, height, spot, exclude) -> bool`, adapted from `TrainingDummy._has_room()`), `game/level/encounter_spawner.gd`, `game/level/encounter_table.gd` (`class_name EncounterTable extends Resource`, `@export var waves: Array[PackedStringArray]`), `game/level/encounters/crowd_waves.tres`, `game/ui/cheat_menu.gd`, `tests/test_crowd_room.gd`, `tests/test_encounter_spawner.gd`, `tests/test_cheat_spawns.gd`, `tests/bot/crowd_bot.gd` + `crowd_bot.tscn`, `tests/bot/acts/room_acts.gd`, `tests/fixtures/stub_enemy.gd` + `.tscn` (a test-only EnemyActor that stands still), tuning subgroup Waves, ARCHITECTURE heading "Crowd room, navigation and waves", `docs/milestones/M3-calls/P1-room.md`.
- **Geometry** (street axis +X, building fronts on -Z, low near side on +Z, as the test room, so the side-view camera behaves; all numbers are room `@export`s):
  - lane floor x -15..15, z -6..6 (top at y 0), plus floor boxes for every recess and alley; **no wide floor margins** (they make nav islands);
  - north (-Z) building fronts, inner face z -6, heights 6-9 m, with **three doorway recesses** 2.0 m wide, 1.5 m deep at x -9, 0, 9 (spawn points at the back of each recess);
  - east and west end walls at x ±15 with **alley mouths** 3 m wide (z -1.5..1.5) into 5 m alleys (spawn points at x ±19.5);
  - a south (+Z) low curb (0.6 m) with one **side alley** gap 2.5 m wide at x 4 into a 3 x 5 m alley (spawn at z 10.5);
  - a parked car 4.2 x 1.4 x 1.9 at (-5, 0, 3.5), two crates near (7, 0, -4.5), a dumpster at (11, 0, -5) (cover and nav obstacles);
  - player start (0, 0, 0), yaw -90° (facing +X). So with the default look, the west alley and two doorways are behind or beside the player.
  - All static bodies under one `Geometry` node; bake from it in `_ready()` **before** spawning actors; then `RoomKit.spawn_player()`, an `EnemyDirector`, the `EncounterSpawner`, then presentation (`with_presentation`).
- **Waves:** `EncounterSpawner` reads `crowd_waves.tres` (starting table: `[punk, punk]`, `[punk, punk, punk, punk]`, `[punk, kicker, punk, thug, punk, punk]`, `[bruiser, punk, kicker, punk]`, `[thug, kicker, punk, punk, kicker, punk]`, then `boss` every `boss_wave_every` waves; ids not in `EnemyCatalog.available()` are replaced by `punk`). A wave starts `wave_gap_s` after the previous one is cleared (every `from_wave` enemy has `health <= 0`), spawns one enemy every `wave_spawn_interval_s` (spreads the 10 ms rig builds), never exceeds `wave_max_alive` live AI enemies (cheat spawns count toward alive but the cap only gates waves), and repeats the table forever. Spawn point choice: at spawn time, classify points by `player.is_outside_view(point, rear_warning_angle_deg)`; aim for `wave_behind_share` of each wave from behind points; skip points within `spawn_min_player_distance_m` of the player or failing `SpawnRoomCheck.has_room()`; seeded RNG. Each enemy is named `"<Archetype><n>"` (`display_name` "Punk 3"), positioned before `add_child`, then `enter_from(point, lane_point)`.
- **F4 (cheat menu):** an `OptionButton` of `EnemyCatalog.available()` plus "Spawn at crosshair" (reusing `spawn_point()`, generalized to the archetype's `body_size`), "Remove all enemies" (groups first, then `queue_free`), "Waves on/off" (calls the spawner if present, disabled otherwise), "Freeze AI" (toggles `Tuning.data.ai_frozen` through `Tuning.set_value`). Keep `spawn_dummy()`, `reset_dummies()`, `record_posts()`, `god_mode_toggle`, `one_hit_toggle`, `time_scale_buttons`, `skip_arena_button` (still disabled) and `focus_first()` exactly as the tests expect; `spawned` becomes `Array[CombatActor]`. A spawned AI enemy is named and colored per archetype and starts in ENTER from where it stands.
- **Crowd bot skeleton:** `crowd_bot.gd` extends `combo_bot.gd`, overrides `_room_scene()` (the crowd room) and `_run()`: collects acts from every `tests/bot/acts/*_acts.gd` (sorted by file name; each file `static func acts(bot: Node) -> Array[Dictionary]` of `{title, cam, fn}`). Bot helpers for act files: `spawn(id, rel: Vector2, face_player := true) -> EnemyActor` (x right, y ahead of the player), `clear_enemies()`, `set_waves(on)`, `freeze_ai(on)`, `log_line(text)`, plus combo_bot's `_press`, `_ticks`, `_wait_until`, `_turn_by`, `_look_to`, `_hud()`. It logs `W+`/`W-` from `RearWarning` signals (duck-typed, if the HUD has one), `AI f<frame> <name> <old>-><new>` from polling `ai_state`, `TOK+`/`TOK-` from polling `has_token`, and `WU+`/`WU-` from `windup_started/ended`. `room_acts.gd`: "Room tour" (the player turns 360° at the start, then walks the lane; F3 on in free fly for one pass).
- **Interfaces provided:** 2.7, 2.12's room contract, `RoomKit`, `NavBaker`, `SpawnRoomCheck`, the act-file contract. **Consumed:** 2.5 (spawn, `enter_from`), 2.6 (`EnemyDirector` instance), 2.8, 2.1.
- **Tunables (append to Waves):** `wave_gap_s` 3.0, `wave_spawn_interval_s` 0.6, `wave_behind_share` 0.35, `boss_wave_every` 4, `spawn_min_player_distance_m` 4.0, `player_avoid_radius_m` 0.5.
- **Tests:** the room builds headless with no `SCRIPT ERROR`/`ERROR` (guard every map query until sync); the navmesh has polygons and no polygon above 0.5 m; every spawn point snaps within 0.3 m and has a path to the lane centre; the player has an obstacle and `auto_revive`; the TuningOverlay is a direct child; waves with `stub_enemy` via `scene_override`: wave 1 spawns 2, the next wave waits for clears, never more than `wave_max_alive` live, about `wave_behind_share` come from behind across a seeded run, repeat after the table end, unknown ids fall back to punk; F4: every available archetype spawns at the crosshair, `spawn_dummy()` still returns a `TrainingDummy`, "Remove all" leaves no group members in the same frame.
- **Captures:** `crowd_bot` "Room tour" in first person (the lane reads as a street; doorways and alleys visible) and once with F3 in free fly; 900 frames headless soak with 6 `stub_enemy`s isn't visual: assert in tests instead.
- **Acceptance:** tests green; the room bakes in under 5 ms and syncs by physics frame 3; first-person tour sheet shows no floating geometry, no z-fighting in the lane, doorways readable as spawn points; F6 switches both ways (manual check, logged in the final message).
- **Size:** WP4-sized builder (about 8-10%).

### P1-hud: the rear warning, the F3 AI overlay, the boss bar hookup, the wind-up voices
- **Goal:** SPEC §8 in full, proved on training dummies before any AI exists (risk first: the second half of the done-when is independent of the AI), plus the F3 drawing of tokens and slots, the boss bar showing for any actor in group `"boss"`, and the crowd's audio voice budget.
- **Owned files:** `game/ui/rear_warning.gd` (new), `game/ui/hud.gd`, `game/ui/hud.tscn`, `game/ui/debug_draw.gd`, `game/audio/audio_director.gd`, `tests/test_rear_warning.gd`, `tests/test_debug_draw_ai.gd`, `tests/test_audio_crowd.gd`, `tests/test_ui.gd` (append only: the warning lies **inside** the reserved corners at every size), `tests/bot/warning_bot.gd` + `.tscn` (extends `combo_bot.gd`, the training room), tuning group Rear warning (append), ARCHITECTURE heading "Rear warning and the F3 AI overlay", `docs/milestones/M3-calls/P1-hud.md`.
- **The warning:**
  1. `RearWarning` is a full-rect, `mouse_filter = IGNORE` child of the HUD drawing up to two bursts of `VfxArt.texture(&"rear_warning")` (preloaded in `_ready()`, `texture_filter = LINEAR_WITH_MIPMAPS`) centred `rear_warning_inset_px` in from each top corner, at `rear_warning_base_px * rear_warning_size` (× `rear_warning_heavy_scale` while any heavy attacker is on that side), clamped to stay inside the 384 x 216 corner rect at 1920 x 1080 (anchored to the corners on wider screens).
  2. **Trigger** on `windup_started(attacker, move)`: attacker is not team 0; the player exists (group `"player"`) and `health > 0`; `b := player.look_bearing_deg(attacker.global_position)`; fire when `absf(b) > rear_warning_angle_deg` and the flat distance ≤ `move.reach_m + rear_warning_range_margin_m` (if `reach_m` is 0, the dummy jab: use `rear_warning_fallback_reach_m`). **Side** at the start: `b > 0` → left, `b < 0` → right, `absf(b) >= 180 - rear_warning_behind_deg` → both. The side stays fixed until the end (logged judgement call).
  3. **End** on any of: `hit_landed` with `hit.attacker == attacker` (blocked hits too), `attack_whiffed(attacker, _)`, `windup_ended(attacker, true)`, `grabbed(attacker, _)`, `ko(attacker, _)`, `vanished(attacker)`; and, polled every `advance()`, the attacker freed, or not in WINDUP/ATTACK/GRABBING, or `current_move` no longer the same move id. **Never** on `windup_ended(attacker, false)` (the strike coming out).
  4. **Several attackers:** one burst per corner; alpha = `rear_warning_opacity` × min(1, `rear_warning_min_alpha` + `rear_warning_brightness_step` × (count - 1)).
  5. **Look:** pops in, pulses `rear_warning_pulses` times over `rear_warning_pulse_s` each (scale and alpha), then holds; a new attacker on a lit side re-pulses. Timed on the HUD's `game_delta` × `TimeController.sim_scale()` (held while paused; slowed by slow-mo and the 0.25x cheat).
  6. Suppressed while the player's `health <= 0` (the KO view); emits `shown`/`hidden`.
  7. Audio already plays (SPEC §8's positional cue); `rear_warning_audio` keeps gating it.
- **F3 overlay** (`debug_draw.gd`, drawn only when `EnemyDirector.find()` returns one with enemies, so `test_ui.gd`'s exact line counts don't change): new distinct `@export` colors; token holders: a magenta ring at the feet and a line chest to chest to the player; posturing enemies: a small circle at their slot and a dim line to it; the posture ring (two circles at the ankles); the view boundary at `rear_warning_angle_deg` and the ±`rear_warning_behind_deg` behind sector as floor lines from the player; each enemy's current nav path as a polyline. AI text comes from `debug_state_text()` (P1-ai), no change here. Duck-typed calls only (`has_method`), so it compiles with any director.
- **Boss bar:** `GameHud` calls `show_boss(actor)` when a live member of group `"boss"` exists and `hide_boss()` when none (polled in `advance()`); the HUD never writes state.
- **Audio** (`audio_director.gd`): `_take_voice()` steals the oldest voice that is **not** a live wind-up cue first (a wind-up cue may be the only warning); `voice_pitch(actor)` multiplies by `actor.get("voice_pitch_mult")` when present. Measure the six-enemy voice peak in `test_audio_crowd.gd` and raise `voice_count` only if the test shows starvation.
- **Tunables (append to Rear warning):** `rear_warning_base_px` 170, `rear_warning_inset_px` 48, `rear_warning_pulses` 2, `rear_warning_pulse_s` 0.12, `rear_warning_heavy_scale` 1.4, `rear_warning_min_alpha` 0.65, `rear_warning_brightness_step` 0.2, `rear_warning_fallback_reach_m` 1.1.
- **Tests** (`test_rear_warning.gd` on the `test_ui.gd` fakes: a FakePlayer looking down -Z, FakeEnemies with a move whose `reach_m` is set): behind-left (135°) lights top-left only; behind-right (-135°) top-right only; directly behind (180°, and 165°) both; 170° vs 155° around the ±20° edge; 50° (in view) none; beyond range none; the end on hit (blocked too), whiff, interrupt, grab, KO, vanish, free, and a polled move change, and **not** on `windup_ended(false)`; two attackers on one side are brighter than one; a heavy attacker is larger; live tunables (angle, size, opacity, behind, margin) take effect; pause holds it; suppressed at player health 0; writes no game state (copy `test_vfx.gd:891`); integration in the real training room with presentation on: post a `TrainingDummy` behind-left, behind-right and behind the player and `start_jab()` each, assert the corner, then the end when the jab lands or is blocked. `test_debug_draw_ai.gd`: with a stub director in the group, the new colors appear with the expected counts; without one, `test_ui.gd`'s counts are unchanged. `test_audio_crowd.gd`: six simultaneous wind-ups plus hits never steal a live wind-up cue before other voices.
- **Captures:** `warning_bot` acts in the training room, first person, help and combat log hidden, the player still: "Warning behind-left", "Warning behind-right", "Warning directly behind", "No warning at 50°", "Two on the left", "Warning ends on a block". Corner-crop sheets at 12 fps for each, plus one full-frame sheet to check that the bursts don't cover the action. Log lines `W+ side=… count=…` with frames.
- **Acceptance:** tests green; in the crops each corner lights exactly as the act says, pulses twice, holds, and goes when the jab lands; the burst is readable but small (inside its corner, nothing in the centre of the view); log frames: `W+` on the wind-up's first frame, `W-` on the contact frame.
- **Size:** WP2-sized builder (about 6-8%).

### P1-int: slice integration (after the four merge)
- **Phase:** 1b. The lead merges P1-ai, P1-director, P1-room, P1-hud into `m3/enemy-ai` (in that order; regenerate `tuning/default.json`; full suite; push), sets `run/main_scene` to the crowd room in `project.godot`, then cuts `.worktrees/m3-slice-int` (`m3/slice-int`).
- **Goal:** make the slice play end to end in the crowd room, and record the slice evidence.
- **Owned files:** `tests/bot/acts/slice_acts.gd`, `tests/test_slice_crowd.gd`, plus **integration fixes in any file**, each listed in the final message with a one-line reason (the builder is alone on the branch, so there's no conflict; the lead reviews the diff).
- **Acts** (first person unless marked; titles short so the caption clears the top-right corner):
  1. "Punk 1v1": one Punk enters from a doorway, postures, attacks; the bot blocks the first jab, then punches it out of its second wind-up, then P P P P.
  2. "Three Punks": three Punks; the bot turns slowly 360° twice, then fights (autopilot: face the nearest posturing enemy, P P P P; block when a wind-up starts in view; dodge sideways when two wind up at once).
  3. "Six Punks, observed": six Punks, god mode, the bot turns 360° slowly for 10 s, then stands still facing +X for 10 s.
  4. "Six Punks, fight": autopilot for 25 s (god mode).
  5. "Warn L/R/behind": `ai_frozen`, three Punks placed at -135°, +135° and 180° at 1.5 m; `force_attack()` each in turn; then two on the left at once; a fourth at 50° as the control.
  6. "Director, F3" (free fly and side view, debug): the six-Punk fight with F3 on.
  7. "Waves": waves on from the start, 60 s, god mode, autopilot.
- **Headless test `test_slice_crowd.gd`** (seeded, about 900 frames, god mode, six Punks, waves off): never more than `attacker_cap` enemies in WINDUP or ATTACK at once; minimum enemy-enemy distance after frame 240 ≥ 0.7 m; no enemy without progress for over 2 s while APPROACHing; at frame 600 with ≥ 4 posturing, the largest empty arc around the player ≤ 360/n + 30°; at least one blind-spot grant happened; deterministic (two runs, same position hash).
- **Acceptance:** all acts run to the end and quit; the slice gate checklist (next section) can be judged from the sheets and logs.
- **Size:** about one fixer (about 5%).

### The slice gate (phase 1c: the lead plus a review workflow)
1. **The lead looks** at the sheets of every slice act (first person; the corner crops for act 5) and the logs, and writes `docs/milestones/M3-slice-gate.md` (the evidence, the verdicts, the feel defaults chosen).
2. **Gate checklist** (each a yes with evidence, or a finding):
   - Wind-ups read in first person at strike range (the cocked fist visible and held, the head visible) and the shove is distinct from the punch.
   - Posture reads: enemies circle and strafe on the ring, don't jitter, don't bunch in front; with six, the player sees about two at a time and the rest are genuinely around and behind.
   - Never more than the cap attacking (log); attacks are paced (no stretch where the player is flinch-locked for more than about 1.5 s with god mode's view of it).
   - The warning: act 5's crops show top-left only for the Punk at +135° (behind-left; bearings are positive to the left), top-right only for -135° (behind-right), both corners for 180°, nothing at 50°, and a brighter burst for two on one side; `W+` frame = `WU+` frame, `W-` frame = the hit or whiff frame. **This is the SPEC §12 warning criterion, judged here.**
   - Hit reactions in a crowd: knockdown, get-up (no overlap pops that read as teleports in first person), KO blink-off, no stuck or orbiting corpses.
   - Navigation: no enemy stuck at a doorway, crate corner or the car; walk-ins look purposeful.
   - Performance, windowed: median frame time with six Punks fighting (physics plus process) and the worst spawn frame (sample `Performance.TIME_PROCESS` and `TIME_PHYSICS_PROCESS` in a bot act; median of three runs; note the machine load).
3. **Review workflow** (`docs/reviews/M3/workflow.js`, copied from `docs/reviews/M2-phase3/workflow.js` with every M2 path, branch, prefix and commit subject made a constant: `MILESTONE='m3'`, `BASE_BRANCH='m3/enemy-ai'`, `NOTES_BRANCH='m3/review'`, `REVIEWS='docs/reviews/M3'`, the subject `"M3 slice: review fixes (<key>"`, and `COST` divided by 5). Lenses: (a) **first-person crowd readability** (the slice sheets, plus its own recordings), (b) **rear warning correctness** (acts 5 and the warning bot, logs, code path of the end conditions), (c) **code and determinism** (layer rules, no feel numbers, the latched nav pattern, groups-before-free, the director under hitstop and slow-mo, test flakiness). Three Sonnet skeptics per finding (reproduce, spec, code); a finding survives with two confirmations. Partition into at most three fix packages with disjoint files; Sonnet fixers in `.worktrees/m3-fix-<key>`.
4. The lead merges the fixes, re-records acts 1-5, and **locks the feel defaults** (ring radius, circle speed, cadence, cap, attack gap, wind-up length) in `M3-slice-gate.md` and the judgement-call log. Update HANDOFF. **Phase 2 starts only when the gate checklist is all yes.**
5. **Re-measure the costs** of each phase 1 package (window points before and after) and update HANDOFF's cost table for the premium seat.

---

## 6. Phase 2: widen (three builders in parallel)

Cut from `m3/enemy-ai` after the slice gate's fixes merge.

### P2-grab: enemy grabs on the player (a mini-slice of its own)
- **Goal:** Game-boy's grab rule end to end: a telegraphed grab wind-up (a dodge, a jump or a heavy hit gets out of it); a connect only if `player.can_be_grabbed()` at the connect frame; once held, the player sees the grabber from an upright first-person view, the look locks and eases to the grabber, and mashing P/K `grab_break_presses` times before the follow-up's strike breaks free; unbroken, the hit lands (headbutt: knockdown; slam: thrown). Delivered as a reusable "grab attack" that the Bruiser and the boss will list in phase 3, proved here with a test grabber.
- **Owned files:** `game/player/player.gd`, `game/enemies/enemy_actor.gd`, `game/enemies/enemy_hold.gd` (new), `game/actors/poses/grab_poses.gd`, `tools/gen_moves.gd` (`_grab_moves()` body), `game/combat/moves/{bruiser_grab,bruiser_headbutt,boss_grab,boss_slam}.tres`, `game/ui/grab_prompt.gd` (new) + `hud.gd`/`hud.tscn` (one child and its `advance()` call), `game/audio/audio_director.gd` (a break-free sound on `grab_escaped`, existing pools), `tests/enemy_moves/grab_table.gd`, `tests/test_enemy_moves_grab.gd`, `tests/test_enemy_grab.gd`, `tests/test_player_grabbed.gd`, `tests/fixtures/grab_test_enemy.gd` + `.tscn` (an EnemyActor whose only attack is the grab, `bruiser_grab` → `bruiser_headbutt`), `tests/bot/acts/grab_acts.gd`, tuning subgroup Enemy grabs, ARCHITECTURE heading "Enemy grabs on the player", `docs/milestones/M3-calls/P2-grab.md`.
- **The moves** (`_grab_moves()`, starting values; all `unblockable`, recoil 0, magnetism off; no hitboxes, so no `hit_landed` VFX for the grab itself):
  | id | frames | dmg | reaction | notes |
  | --- | --- | --- | --- | --- |
  | `bruiser_grab` | 32/6/24 | 0 | NONE | wind-up: arms spread wide, crouched forward; strike = `grab_reach(g)`; `reach_m` ≈ 1.3 |
  | `bruiser_headbutt` | 60/3/24 | 15 | KNOCKDOWN | starts from `hold_collar`; its startup **is the mash window** (head and spine tip back, held); applied by code |
  | `boss_grab` | 32/6/24 | 0 | NONE | as the Bruiser's, at boss scale |
  | `boss_slam` | 54/4/30 | 25 | THROWN | starts from `hold_collar`; wind-up lifts the victim (`held_lift` on the victim); applied by code; boss table `boss: true` |
- **Enemy side** (`enemy_hold.gd`, `class_name EnemyHold extends RefCounted`, one per holder; `enemy_actor.gd` wires `kind == &"grab"` attacks to it):
  1. At `_on_move_frame(grab_move, startup)`: the target is the player; connect if the flat distance ≤ `enemy_grab_range_m` (scaled by the holder's rig scale), within `enemy_grab_half_angle_deg` of the holder's facing, and `player.can_be_grabbed()`. Otherwise it whiffs: emit `CombatEvents.attack_whiffed(self, move)` yourself (the audio and log hear it; the warning ends on it).
  2. On connect: `player.start_grabbed(holder)`; the holder enters GRABBING and plays `hold_collar`; `is_holding()` true; then immediately `start_move(windup_move(follow_up, heavy), 1, &"root", true)` (the follow-up's wind-up runs while held; its WINDUP plays the audio cue; the warning won't fire, the grabber is in front).
  3. At the follow-up's `startup` frame: if the victim is still held by us, `release_from_grab(Vector3.ZERO, false)` it first (the CA:952 trap), then apply a code-built `HitInfo` from the move (the `_throw_held()` template: `receive_hit`, `TimeController.hitstop`, `CombatEvents.hit_landed`; `thrown` for the slam). `_keeps_pose_after_strike()` is true while GRABBING.
  4. Ends: `_on_hold_broken(victim)` → the holder staggers (`stagger_frames`, push away), token released; the holder is hit (not possible while it holds, but a flying body or thrown weapon could) → release the victim with no hit; the holder's own death or vanish → release; the holder in any state but GRABBING/WINDUP/ATTACK of the follow-up → release.
  5. Armor matters for "a heavy hit gets out of the wind-up": with the grunt default, any hit cancels the grab wind-up; the heavies' armor (phase 3) absorbs light hits but staggers on heavy ones, which cancels the wind-up. Test both with the test grabber's armor flags.
- **Player side** (`player.gd`):
  1. A `CombatTypes.ActorState.GRABBED:` arm in `_tick_control()` calling `_control_grabbed()`: feed the parser, count every `consume(IN_PUNCH)` and `consume(IN_KICK)` into `_mash`, clear the buffer; at `grab_break_presses`, `break_free(push away from the holder × grab_break_push_mps)`; optional decay `grab_break_decay_per_s`. Safety net: if the holder is invalid, not `is_holding(self)`, KO or gone, `release_from_grab(Vector3.ZERO, false)`.
  2. `_on_grabbed(by)`: reset `_cam_offset`, the parser chain and buffer, `_held_attack`, `_air_attack`, `_turn_frames`, `_quick_turn_frames`, `_mash`; start a look turn toward the holder over `grabbed_turn_frames` (the existing `_turn_left`/`_turn_frames` mechanism).
  3. The `_process()` look gate also blocks look input while GRABBED.
  4. `_held_anim()` → `&"held_collar"` (upright, leaning toward the holder, hands at its wrists; no hips nudge, so a release doesn't pop the lens); `_pin_spot()` override: the holder's HoldPoint dropped to the floor and pushed out to `grabbed_pin_distance_m` from the holder's origin, so the lens is at least about 0.3 m from the grabber's head and hands.
  5. The held view: express any nudge through the existing getters (`get_camera_move_offset()` etc., `grabbed_view_pitch_deg` up toward the grabber's face); `first_person_camera.gd` stays untouched.
  6. `grab_break_progress() -> float` (0..1) for the HUD; `reset_state()` resets the new state.
  7. Magnetism for big bodies (needed by phase 3; this package owns `player.gd`): the stop distance adds `(target.body_radius - Tuning default radius)`, so the lunge doesn't drive into a Bruiser's or boss's capsule.
- **Grab poses** (`grab_poses.gd`): `named(&"hold_collar")` (holder upright, both fists at the victim's collar at HoldPoint distance), `named(&"held_collar")` (looping struggle), `named(&"held_lift")` (`held_collar` with `HIPS_POS` raised), and the recipes for the four moves. All key poses pass `check_joint_limits` (arms ≤ about 140°).
- **HUD:** `grab_prompt.gd`: a "MASH P / K!" comic panel below centre (not in the top corners) with a fill bar from `grab_break_progress()`, shown only while the player is GRABBED; presentation only.
- **Tunables (append to Enemy grabs):** `grab_break_decay_per_s` 0.0, `grab_break_push_mps` 3.0, `grabbed_turn_frames` 8, `grabbed_pin_distance_m` 0.75, `grabbed_view_pitch_deg` 5.0, `enemy_grab_range_m` 1.3, `enemy_grab_half_angle_deg` 50.
- **Tests:** `test_enemy_moves_grab.gd` (the move checks; the headbutt and slam start and end in `hold_collar`); `test_enemy_grab.gd` with `grab_test_enemy`: a dodge through the grab wind-up is never grabbed; a jump through it neither; a heavy hit on an armored grabber cancels the wind-up, a light hit doesn't; a connect puts the player in GRABBED and the holder in GRABBING; a scripted mash of exactly `grab_break_presses` breaks free before the headbutt's strike frame and `grab_break_presses - 1` doesn't; unbroken, the player ends DOWNED with 15 damage (the hit isn't swallowed); the slam (a boss-table test grabber) launches the player THROWN; the holder knocked down by a flying body releases the player; a killing headbutt starts the player's KO view and the player revives; the warning ends on the grab (`grabbed`) and on a whiffed grab; the director grants no tokens to others while the player is held. `test_player_grabbed.gd`: no look turn from the mouse while held (the `test_ko_view.gd:606` pattern); the look faces the holder within `grabbed_turn_frames`; no stale kick `_cam_offset` after a grab during a kick's recovery; `tests/fp_view.gd` checks in the held pose: the own body covers at most a third of the view, nothing nearer the lens than 0.25 m; the held view after the release doesn't jump more than 2 cm.
- **Captures (first person):** grab acts with the test grabber spawned in the crowd room: "Grab: dodge out", "Grab: held, mash free", "Grab: held, headbutt lands", "Grab: slam" (the slam test grabber at boss scale). Sheets at 12 fps across the hold and the release.
- **Acceptance:** tests green; in first person, the held view shows the grabber's head and arms at arm's length, the MASH prompt reads, breaking free pushes the grabber back visibly, the headbutt reads as a hit to the face, and nothing clips the lens.
- **Size:** WP4-sized builder (about 9-11%). Do this first in phase 2 if the headroom only fits one builder.

### P2-kicker: the fast flanker
- **Goal:** the Kicker (25 HP): circles to the player's blind side (fast posture movement, `prefers_blind_side`), attacks with a jump kick (8) and a low sweep (8, knockdown).
- **Owned files:** `game/enemies/kicker/kicker.gd` + `kicker.tscn`, `game/actors/poses/enemy_poses_kicker.gd`, `tools/gen_moves.gd` (`_kicker_moves()` body), `game/combat/moves/kicker_*.tres`, `tests/enemy_moves/kicker_table.gd`, `tests/test_enemy_moves_kicker.gd`, `tests/test_kicker.gd`, `tests/bot/acts/kicker_acts.gd`, tuning subgroup Kicker, ARCHITECTURE heading "Kicker", `docs/milestones/M3-calls/P2-kicker.md`. **Never edits `enemy_actor.gd`**: override in `kicker.gd` only.
- **Moves:** `kicker_jump_kick` 22/6/18, 8 dmg, LIGHT, FLINCH, sphere RightFootPoint 0.2, `free_lunge` about 1.6 m (applied over the active frames by the base); recipe: wind-up = `crouch(g)` with arms back (planted, held); strike = a front-kick leg from `_front_kick` with `HIPS_POS` (0, 0.35, 0.05) so the body visibly leaves the floor (the capsule stays grounded); follow = landing crouch. **Don't start from `_air_guard`.** `kicker_sweep` 20/5/22, 8 dmg, LIGHT, KNOCKDOWN, `_arc(1.3, 80, 0, Vector2(0.0, 0.5))` (the LEGS capsules); recipe modelled on `_spinning_heel`, crouched, with explicit `HIPS_POS` on every crouched key (G9). Table `ATTACKS`: jump kick; sweep.
- **Behaviour:** `prefers_blind_side = true`; posture speed × `kicker_circle_mult`; while posturing in view, it drifts toward the edge of the view (the director's slot already puts it behind; it walks there visibly at the edge of the view rather than through the player).
- **Tunables (append):** `kicker_circle_mult` 1.6, `kicker_speed_mult` 1.3, `kicker_sweep_chance` 0.4, `kicker_attack_cooldown_s` 1.2.
- **Tests:** the move checks (reach at 1.8 m, FP telegraph from the side and from behind is not required; in front it is); `test_kicker.gd`: with a Punk and a Kicker posturing, the Kicker takes the slot nearest directly behind; the sweep knocks a standing player down for 8 and passes over a jumping player; the jump kick's lunge happens only in the active frames (no slide in the wind-up); the 15% rule passes.
- **Captures (first person):** "Kicker flanks" (the player stands still: the Kicker leaves the view toward the back; the warning fires when it winds up behind), "Kicker jump kick in front", "Kicker sweep in front", "Kicker sweep jumped over".
- **Acceptance:** tests green; the jump kick's wind-up crouch reads at 1-2 m; the sweep's wind-up reads as low; flanking reads as deliberate.
- **Size:** phase-3-B-sized builder (about 5-6%).

### P2-thug: the Pipe Thug and the dropped pipe
- **Goal:** the Pipe Thug (35 HP) carries a pipe, swings a three-hit pipe combo (10 each), drops the pipe on knockdown (or KO), and the player can pick it up and use it as any pipe.
- **Owned files:** `game/enemies/thug/pipe_thug.gd` + `pipe_thug.tscn`, `game/actors/poses/enemy_poses_thug.gd`, `tools/gen_moves.gd` (`_thug_moves()` body), `game/combat/moves/thug_pipe_*.tres`, `game/weapons/weapon.gd` (a public `drop(velocity: Vector3)` that reparents to the world root, unfreezes and restores ground physics and group `"weapon"`, and `held_by: CombatActor` if useful), `tests/enemy_moves/thug_table.gd`, `tests/test_enemy_moves_thug.gd`, `tests/test_pipe_thug.gd`, `tests/bot/acts/thug_acts.gd`, tuning subgroup Pipe Thug, ARCHITECTURE heading "Pipe Thug and the dropped pipe", `docs/milestones/M3-calls/P2-thug.md`. **Never edits `enemy_actor.gd`.**
- **Moves:** `thug_pipe_1` 22/3/14, `thug_pipe_2` 12/3/14, `thug_pipe_3` 14/4/20, 10 dmg each, LIGHT, FLINCH, FLINCH, **STAGGER** (the 15% rule), sphere WeaponTip 0.19, `guard_damage_mult = PIPE_GUARD_MULT`; recipes reuse `_pipe_swing_1/2/3(wg)` strikes and follow-throughs with new, bigger wind-ups (the first one held; upper-arm raises ≤ about 140°, G7). Dispatch with `wg`. Table `ATTACKS`: `[thug_pipe_1, thug_pipe_2, thug_pipe_3]`; unarmed: the Punk's two attacks (by move id).
- **Behaviour:** spawns its own pipe (`pipe.tscn`) and `attach_to(self)` after `_ready()`; on `_on_hit_received(hit)` with a reaction of KNOCKDOWN, LAUNCH or THROWN, or a killing hit: `weapon.drop(flat push along the hit)`; from then on it uses the unarmed attacks (it never re-arms: logged call). A dropped pipe is a normal pickup (LB), with its own durability.
- **Tunables (append):** `thug_attack_cooldown_s` 1.8, `thug_speed_mult` 0.95, `thug_drop_speed_mps` 2.0.
- **Tests:** the move checks; `test_pipe_thug.gd`: it spawns holding a pipe; a knockdown drops it to the floor (in group `"weapon"`, pickable, the player picks it up with LB and swings it); a flinch doesn't drop it; a KO drops it; after the drop it attacks with punk moves; the chain's third hit staggers; the player can block the swings with the 1.5 guard drain.
- **Captures (first person):** "Thug three swings", "Thug drops the pipe", "Take the Thug's pipe" (pick up and three swings on a Punk).
- **Acceptance:** tests green; the pipe wind-up reads (the pipe cocked high and held); the drop is visible and the pipe lies where it can be reached.
- **Size:** phase-3-B-sized builder (about 5-7%).

### Phase 2 merge
The lead merges P2-grab, P2-kicker, P2-thug (regenerate the preset and the moves; full suite), records the grab acts, the kicker and thug acts and the slice act "Six Punks, fight" with waves now mixed (`crowd_waves.tres` already lists kickers and thugs), and checks nothing in the slice regressed. Update HANDOFF.

---

## 7. Phase 3: the heavies (two builders in parallel)

### P3-bruiser
- **Goal:** the Bruiser (80 HP): armored (ignores light hits, staggers on heavy hits and finishers), the haymaker breaks its armor, an overhead smash (15) and the grab and headbutt (15) through `EnemyHold`.
- **Owned files:** `game/enemies/bruiser/bruiser.gd` + `bruiser.tscn`, `game/actors/poses/enemy_poses_bruiser.gd` (the smash recipe; `named(&"brace")`), `tools/gen_moves.gd` (`_bruiser_moves()` body), `game/combat/moves/bruiser_smash.tres`, `tests/enemy_moves/bruiser_table.gd`, `tests/test_enemy_moves_bruiser.gd`, `tests/test_bruiser.gd`, `tests/bot/acts/bruiser_acts.gd`, tuning subgroup Bruiser, ARCHITECTURE heading "Bruiser", `docs/milestones/M3-calls/P3-bruiser.md`.
- **Body:** `body_height` 2.05, `body_radius` 0.45 (scene data), `heavy = true`, `voice_pitch_mult` about 0.8, saturated colors distinct from the Punk.
- **Armor:** `armor_light = true`, `armor_heavy_to_stagger = true`, `armor_finisher_to_stagger = true`; a hit with `breaks_armor` (the haymaker) keeps its own reaction (knockdown) and turns the armor off for `bruiser_armor_break_s` (light hits flinch it then). `can_be_grabbed()` override: only while STAGGER or armor broken (a heavy hit, then LB and throw). A perfect block still staggers it (CombatActor's default; logged).
- **Moves:** `bruiser_smash` 34/4/26, 15 dmg, HEAVY, KNOCKDOWN, spheres both FistPoints 0.2, recoil 0; wind-up both arms overhead (≤ 140°), spine back, held; strike both fists down to head and shoulder height of a 1.8 m player (aims down at its scale; check reach at 2.05 m). Attacks table: `[bruiser_smash]` and the grab `[bruiser_grab, bruiser_headbutt]` (`kind &"grab"`, from P2-grab's moves).
- **Tunables (append):** `bruiser_armor_break_s` 2.0, `bruiser_grab_chance` 0.4, `bruiser_attack_cooldown_s` 2.2, `bruiser_speed_mult` 0.8.
- **Tests:** the move checks at 2.05 m (reach and FP telegraph from 1.8 m eyes); armor: a jab during its wind-up lands damage and doesn't interrupt (the warning keeps going); a hook (heavy) staggers it out of the wind-up; the uppercut (finisher) staggers; the haymaker knocks it down and opens the window; grabbable only when staggered or broken; the smash on a blocking player drains 60 guard and recoils nothing; the grab attack works through EnemyHold (mash free, headbutt lands); the 15% rule; the wind-up floor 30.
- **Captures (first person):** "Bruiser shrugs off jabs", "Hook staggers the Bruiser", "Haymaker breaks the armor", "Bruiser smash", "Bruiser grab: mash free", "Bruiser headbutt", plus the rear warning's larger burst when it winds up behind (corner crop).
- **Acceptance:** tests green; armor reads in first person (no flinch, a flash and maybe `brace`, the wind-up keeps going); the smash reads as overhead from 1-3 m; the larger warning burst is visibly larger and still inside its corner.
- **Size:** phase-3-A-sized builder (about 6-8%).

### P3-boss
- **Goal:** the graybox boss (placeholder name "Boss"; 300 HP, two phases): shoulder charge, grab slam, ground pound; at 50% it turns faster and calls in two Street Punks; the boss bar shows.
- **Owned files:** `game/enemies/boss/boss.gd` + `boss.tscn`, `game/actors/poses/enemy_poses_boss.gd` (charge and pound recipes; `named(&"run_forward")`), `tools/gen_moves.gd` (`_boss_moves()` body), `game/combat/moves/{boss_charge,boss_pound}.tres`, `tests/enemy_moves/boss_table.gd`, `tests/test_enemy_moves_boss.gd`, `tests/test_boss.gd`, `tests/bot/acts/boss_acts.gd`, tuning subgroup Boss, ARCHITECTURE heading "Boss", `docs/milestones/M3-calls/P3-boss.md`.
- **Body:** `body_height` 2.3, `body_radius` 0.5 (the navmesh's agent radius), `heavy = true`, `voice_pitch_mult` about 0.7, group `"boss"` (the HUD bar), `display_name` "Boss".
- **Armor:** `armor_light = true`, `armor_heavy_to_stagger = true`, `armor_finisher_to_stagger = false` (finishers knock it down: the punish window); never grabbable.
- **Moves** (boss table rows `boss: true`, exempt from the 15% rule):
  | id | frames | dmg | tier | reaction | hitbox | notes |
  | --- | --- | --- | --- | --- | --- | --- |
  | `boss_charge` | 32/24/30 | 20 | HEAVY | KNOCKDOWN | `_arc(1.1, 35, 0, Vector2(0.5, 1.9))` | `free_lunge` 4.0 over the active frames (the base); plays `run_forward` look via the recipe's held strike; stops on walls |
  | `boss_pound` | 36/4/30 | 15 | HEAVY | KNOCKDOWN | `_arc(2.5, 180, 0, Vector2(0.0, 0.6))` | `unblockable`; a jump clears it |
  | grab: `boss_grab` → `boss_slam` (P2-grab's moves) | | 25 | | THROWN | none | the victim is lifted (`held_lift`) |
- **Behaviour:** attack choice by range: charge when the player is beyond `boss_charge_min_m`, pound when two or more enemies or the player is close, grab otherwise (weights tunable). **Phase 2** at `health <= boss_phase2_at × max_health` (once): emit `boss_phase_changed(self, 2)`, multiply its turn rate by `boss_phase2_turn_mult`, and call in `boss_adds_count` Street Punks through `EncounterSpawner.spawn_adds(&"punk", n, global_position)` (group `"encounter_spawner"`; in a room with none, spawn the catalog Punk at the nearest navmesh points `boss_add_ring_m` from the boss). Adds count toward alive and take tokens like anyone.
- **Tunables (append):** `boss_phase2_at` 0.5, `boss_turn_rate` 2.5, `boss_phase2_turn_mult` 1.8, `boss_adds_count` 2, `boss_add_ring_m` 5.0, `boss_charge_min_m` 4.0, `boss_charge_chance`, `boss_pound_chance`, `boss_grab_chance`, `boss_attack_cooldown_s` 1.8, `boss_speed_mult` 0.85.
- **Tests:** the move checks at 2.3 m; jabs never interrupt its wind-ups; a heavy hit staggers it out of the grab wind-up (Game-boy's rule); a finisher knocks it down; the pound hits a standing player and misses a jumping one, and is unblockable; the charge travels only in its active frames and stops at a wall; phase 2 at 150 HP exactly once: the event, the turn rate, two Punks spawned (with a spawner and without one); the boss bar shows while it lives (presentation test with the HUD) and hides after its vanish; the boss is never grabbable.
- **Captures (first person):** "Boss charge", "Boss pound jumped", "Boss grab slam", "Boss phase 2 adds", and the boss bar visible bottom centre.
- **Acceptance:** tests green; each attack's wind-up reads at its own range in first person; phase 2 is visible (the turn, the Punks walking in from doorways); the boss's size doesn't fill the view at its posture distance.
- **Size:** WP4-sized builder (about 9-11%).

### Phase 3 merge
The lead merges both, regenerates, runs the suite, spot-records each act, updates HANDOFF. The boss now appears in the crowd room every `boss_wave_every` waves.

---

## 8. Phase 4: the whole fight, review, docs, release

### P4-int: whole-fight integration
- **Owned files:** `tests/bot/acts/crowd_acts.gd`, `tests/test_crowd_full.gd`, integration fixes in any file (listed with reasons; alone on its branch).
- **Acts (first person):** "Mixed six, observed" (Punk, Kicker, Thug, Bruiser, Punk, Kicker; turn 360° then stand); "Mixed six, fight" (autopilot, god mode, 30 s); "Waves to the boss" (waves on, god mode, 120 s, reaching a boss wave via `boss_wave_every` tuned to 2 for the act); "Rear warning, every archetype" (frozen, each archetype winds up at 135° L, 135° R and 180°; heavy bursts larger); "Perf, six with ragdolls" (windowed timing samples logged).
- **`test_crowd_full.gd`** (seeded, short): mixed six with the full director: cap respected, no overlap, no stuck enemies, alive ≤ 6 from waves.
- **Size:** about one fixer (5%).

### Review round (the M3 copy of the M2 workflow)
Five lenses, each an Opus reviewer in a detached worktree at the `m3/enemy-ai` head:
1. **Code:** the M3 diff from `0d6f8cd`: layer rules (simulation reads no camera; presentation writes no state; the director uses the look helper), no feel numbers, groups before free, tokens on every exit path (death, vanish, grab, freeze, room switch), determinism, events on despawn, the 15% rule and wind-up floors, presets that predate the new tunables.
2. **First-person crowd readability:** all archetypes' acts and the mixed fights: tells, spread, cadence, armor reads, nothing fills the view, KO and get-up in a crowd, the big bodies at 1 m.
3. **Rear warning:** every archetype at L, R and behind; several per side; heavies; the end on land, whiff, interrupt and grab; the KO suppression; pause; slow-mo; audio direction.
4. **Enemy grabs and the boss:** the held view, mash, release, headbutt, slam, phase 2, adds, the boss bar.
5. **Performance:** six enemies with navigation, ragdolls and VFX, windowed; wave spawn hitches; the first knockdown's ragdoll build.
Then skeptics (three Sonnet per finding; two confirmations survive), the completeness critic, partition into at most four disjoint fix packages, Sonnet fixers, and a Haiku scribe on `m3/review` (`docs/reviews/M3/*.json`, launch args saved as `args-*.json`). Run a second, lead-briefed round (the `workflow-r2-close.js` copy) only if the first leaves high-severity findings. The usage gates of the M2 workflow apply, with premium-seat costs.

### Docs
- **README:** "Milestone 3 status" (what's in, how to play it: the crowd room is the main scene, F6 to the training room, F4 spawns, waves, the boss); controls table (F6; F4's new entries); **"Where M3 departs from the spec"** with each approved-by-default departure (candidates: the Bruiser's finishers stagger; the warning's side fixed at wind-up start and hidden during the player's KO; the 15% rule read per attack chain; enemy grab mash; the Pipe Thug fights unarmed after the drop; the boss's placeholder name; F4 spawns can exceed six). Mark each "decided by default (Game-boy, 2026-10-25: no grey-block feel questions)".
- **ARCHITECTURE:** the title becomes "Milestones 1-3"; the lead checks each package's section against the code; Ownership gains the M3 rows.
- **`docs/milestones/M3-judgement-calls.md`:** every package's calls folded in, deduplicated, each with its alternative and why. The Slack digest comes from here.
- **HANDOFF:** the final state, the PR and release links.

### Export and release
1. `godot --headless --import --quit` then `godot --headless --export-release "macOS" "builds/macos/Beat-em-Up PoC.zip"` (templates 4.7.2.stable are installed; `builds/` is git-ignored). Bump `application/short_version` and `version` to 0.3 / 0.3.0 if not already (they are).
2. Smoke the export: unzip into the scratchpad, run the app's binary headless with `--quit-after 900`, and grep its output for `SCRIPT ERROR`/`ERROR` (the crowd room loads, the navmesh syncs, waves spawn). Then run it windowed once for about 20 s and screenshot (the lead looks).
3. `gh release create m3-playtest-1 "builds/macos/Beat-em-Up PoC.zip" --repo mikedtcm22/beat-em-up-PoC --target m3/enemy-ai --prerelease --title "Milestone 3 playtest: enemy AI and the rear warning" --notes-file <notes>`. The notes: first launch needs right-click → Open (ad-hoc signed, not notarized); controls; F6, F4, F1; what to try (six-enemy fight, warning corners, grabs, boss wave).
4. The release page URL is the playable link.

### The PR and the DM
- Open the M3 PR from `m3/enemy-ai` into `main`; the description lists the done-when evidence (the slice gate file, the corner crops, the test counts), the defaults taken, and ends with "🤖 Generated with [Claude Code](https://claude.com/claude-code)". **Never merge it.**
- DM Game-boy on Slack (Arachne Finance, Michael, `U0AQMKKBL93`): (1) the release link (and the PR link), (2) the digest of key judgement calls, each with at least one alternative not taken and a short why, from `M3-judgement-calls.md`.

---

## 9. Sequencing, usage and handoffs

| Step | Runs | Est. cost (premium 5-hour %) | Handoff point |
| --- | --- | --- | --- |
| S0-scaffold | 1 builder | 6-8 | after merge |
| P1-ai, P1-director, P1-room, P1-hud | 4 builders in parallel | 30-38 | after merge |
| P1-int | 1 builder | about 5 | |
| Slice gate review: 3 reviewers, skeptics, critic, up to 3 fixers | workflow | 20-25 | after the gate file |
| P2-grab, P2-kicker, P2-thug | 3 builders | 19-24 | after merge |
| P3-bruiser, P3-boss | 2 builders | 15-19 | after merge |
| P4-int | 1 builder | about 5 | |
| Review round: 5 reviewers, skeptics, critic, up to 4 fixers | workflow | 35-45 | after the fixes merge |
| Docs, export, release, PR, DM | lead | 2-3 | final |
| **Total** | | **about 135-170** | |

- Check `mcp__ccd_session_mgmt__get_usage` before every launch; launch only what fits below 90%. If a phase doesn't fit, split it (in phase 1, P1-ai and P1-hud are the risk-first pair; in phase 2, P2-grab first).
- Concurrency: up to about six heavy agents while the window is under 60%, two above it; Godot recordings at most two (the capture lock); never more than four builders in phase 1 on this 8 GB machine.
- Every builder commits `wip:` every 15-20 minutes and pushes; at the watcher's 90% message the lead stops launches, has agents commit and push, updates HANDOFF (each package's state, running agents, resume steps), creates the resume task, and tells Game-boy only if blocked.
- Re-measure each package's cost and update HANDOFF's table after phase 1.

---

## 10. Coverage map (requirement → where it is built, tested and seen)

| Requirement | Package | Test | Capture |
| --- | --- | --- | --- |
| Street Punk: 30 HP, two-hit punch, shove (6), head-on | P1-ai | `test_enemy_moves_punk`, `test_enemy_actor` | punk_bot, slice acts 1-4 |
| Kicker: 25 HP, jump kick, sweep (8), circles to the blind side | P2-kicker | `test_kicker` | kicker acts |
| Pipe Thug: 35 HP, three swings (10), drops the pipe for the player | P2-thug | `test_pipe_thug` | thug acts |
| Bruiser: 80 HP, grab and headbutt, smash (15), armor | P3-bruiser (+P2-grab) | `test_bruiser`, `test_enemy_grab` | bruiser acts |
| Boss: 300 HP, two phases, charge, grab slam, pound (15-25), faster turn and two Punks at 50% | P3-boss (+P2-grab) | `test_boss` | boss acts |
| States: enter, approach to 2.5-4 m, posture (circle, strafe, taunt), wind-up (pose, vocal cue, ≥ 18 / ≥ 30 frames), attack, recover, reactions, get-up with invulnerability, KO | P1-ai (+CombatActor) | `test_enemy_actor` | slice acts |
| Light hits interrupt grunt wind-ups, not Bruiser or boss | P1-ai (armor), P3 | `test_enemy_actor`, `test_bruiser`, `test_boss` | "Bruiser shrugs off jabs" |
| Director: tokens, cap 3 (0 = unlimited), blind-spot priority, spread, at most 6 alive, spawns incl. behind | P1-director, P1-room | `test_enemy_director`, `test_encounter_spawner`, `test_slice_crowd` | slice acts 3-7 |
| NavigationAgent3D with avoidance | P1-ai, P1-room | `test_crowd_room`, `test_slice_crowd` | room tour, slice acts |
| Rear warning: trigger, sides, ±20° both, timing = wind-up, look, several, heavies larger, audio, tunables | P1-hud (+P3 heavies) | `test_rear_warning` | warning_bot, slice act 5, "Rear warning, every archetype" |
| Enemy grab on the player, mash to break | P2-grab | `test_enemy_grab`, `test_player_grabbed` | grab acts |
| The 15% rule | S0 (test), each table | `test_move_data` | |
| F1 groups Enemies and Rear warning | S0 + all | `test_tuning_panel` | |
| F3 AI state and tokens | P1-ai (labels), P1-hud (drawing) | `test_debug_draw_ai` | slice act 6 |
| F4 spawn any enemy | P1-room | `test_cheat_spawns` | |
| Crowd room, waves, F6 back to training, auto-revive | P1-room, S0 | `test_crowd_room` | room tour, "Waves" |
| Done-when: readable 6-enemy fight | slice gate, review round | `test_slice_crowd`, `test_crowd_full` | "Six Punks", "Mixed six" |
| Done-when: warning L, R, behind | P1-hud, slice gate | `test_rear_warning` | corner crops |
| README departures, ARCHITECTURE, PR, release, DM | lead | | |

---

## 11. Key judgement calls in this plan

Each is logged in `docs/milestones/M3-judgement-calls.md` when it lands.

1. **One Street Punk end to end, judged in first person, before any other archetype.** *Alternative:* M2's pattern, all archetypes in parallel from the start. *Why not:* every archetype inherits the base, the director and the warning; readability problems (telegraphs at strike range, bunching, flinch-lock, the warning's end) found after five archetypes cost five times the rework.
2. **A contract scaffold (S0) with API skeletons, every hook, signal, field, subgroup and dispatch point, before any branch.** *Alternative:* a "core hooks" package that grows as packages ask, or each package editing shared files. *Why not:* M2's merges collided in the hub files; skeletons let parallel packages compile against real class names (`test_scripts_compile.gd` loads every script).
3. **Attack range is a new `MoveData.reach_m`, generated per move and checked against the measured strike.** *Alternative:* a per-archetype tunable, or reach derived from the hitboxes at runtime. *Why not:* attack numbers belong in the move data; one number then feeds both the AI's spacing and the warning's "range + 1 m", is F1-tunable per move, and a scaled rig's reach is caught by a test.
4. **"Outside the view" is one look-based helper on the player, and the director's blind spot uses the warning's 55° angle.** *Alternative:* the active camera's basis, or a separate blind-spot angle. *Why not:* simulation can't read a camera, spins and the KO view would flip corners, and two numbers could disagree.
5. **The warning's side is decided at wind-up start and kept until the attack lands, whiffs or is interrupted (polled as well as event-driven); it's hidden while the player is KO'd.** *Alternative:* re-evaluate the side every frame as the player turns. *Why not:* the spec fires it "at wind-up start"; a fixed side is deterministic to test and doesn't flicker during spins; turning to face it is the intended response.
6. **Wind-up floors (18 / 30 frames) are tunables that clamp `windup_mult`.** *Alternative:* let the multiplier go below the spec's minimums. *Why not:* the minimums are design rules, but every number stays tunable.
7. **One telegraph per attack: chain follow-ups (the Punk's cross, the Thug's swings 2-3) start without a new wind-up.** *Alternative:* every hit gets its own wind-up and warning. *Why not:* a readable rhythm and one warning per attack; a re-telegraph per hit doubles the warning noise in a crowd.
8. **Tokens cover the whole attack (wind-up to recovery), plus a minimum gap between grants.** *Alternative:* tokens for the wind-up only; no gap. *Why not:* the spec caps how many "attack at once"; the gap prevents three holders flinch-locking the player.
9. **Spread is even over 360°; the Kicker prefers the blind arc; blind-spot priority is the chance a blind waiter jumps the queue.** *Alternative:* a front-biased arc and a score weight. *Why not:* the spec wants enemies around, not in front, and "letting enemies behind you must be genuinely dangerous"; a 0-1 chance maps directly onto the slider.
10. **Navigation: latched NavigationAgent3D, single-thread avoidance, synchronous bake with a roof filter, a player NavigationObstacle3D added by the room; enemies stay physically solid.** *Alternative:* the Godot-docs callback pattern, async bakes, ghosted enemy-enemy collision. *Why not:* the spike measured nondeterminism, lost navmeshes and walk-through-player failures with those.
11. **The training room is frozen; F6 lives in `GameInput`; enemies spawned there steer straight and create a director lazily.** *Alternative:* extract a shared room base from `test_room.gd`, or bake it a navmesh. *Why not:* eleven test files and three bots pin its geometry and child order.
12. **Enemy grabs are hitbox-less, unblockable moves that connect by code at the strike frame (whiff if the player can't be grabbed); the final hit releases first, then applies a code-built hit; the player sees an upright held pose pinned farther out, with the look locked.** *Alternative:* a damage-0 hitbox; reusing the bent-over `held` pose. *Why not:* a grab shouldn't fire hit VFX and hitstop; CombatActor's GRABBED rule would swallow the headbutt; the bent pose buries the lens in the grabber's chest.
13. **Bruiser armor: light hits absorbed (damage lands, no flinch, no interrupt); heavy hits and finishers stagger; the haymaker knocks it down and breaks the armor for a window; grabbable only while staggered or broken.** *Alternative:* the strictest reading (it only ever staggers, even from the haymaker). *Why not:* SPEC §4 says the haymaker "breaks Bruiser armor", which needs a visible payoff.
14. **Boss: light hits absorbed, heavy hits stagger (and get you out of its grab wind-up), finishers knock it down, never grabbable.** *Alternative:* armor only during wind-ups. *Why not:* a 300 HP boss that flinches from every jab can be jab-locked.
15. **The 15% rule is checked per attack chain, so the Thug's third swing staggers.** *Alternative:* per hit only. *Why not:* a 30-damage chain ending in a knockdown is "a knockdown that costs 30%", against the spec's intent.
16. **The Pipe Thug never re-arms; it fights with the Punk's punches after the drop.** *Alternative:* it walks back to pick its pipe up. *Why not:* simpler AI, and the pipe is the player's prize.
17. **KO'd enemies are freed after the blink-off (groups first); waves spawn one at a time.** *Alternative:* pooling and recycling bodies. *Why not:* simpler; staggered spawns spread the 10 ms rig builds; pool only if the perf review asks.
18. **Spawn-any in F4 can exceed six alive; only waves respect the cap.** *Alternative:* F4 refuses past six. *Why not:* it's a debug tool for testing crowds.

---

## 12. Risks the slice exists to surface (and what the gate does if they show)

| Risk | Where it shows | If it fails at the gate |
| --- | --- | --- |
| Telegraphs don't read at strike range in first person (the fist out of frame at 1 m) | punk_bot and act 1 sheets; `check_fp_telegraph` | re-author the Punk wind-ups (P1 fixer) and the shared telegraph helpers **before** any other archetype copies them |
| Six bodies bunch in front, or orbit visibly in jitter | acts 3, 6; `test_slice_crowd` arc check | tune the director's slot logic and posture movement; lock the defaults |
| Flinch-lock with three token holders | act 4 log | raise the attack gap or shorten Punk chains |
| The warning ends early (at `windup_ended(false)`) or lingers | act 5 log frames | fix the end conditions in P1-hud's fixer |
| Navigation stalls at doorways, the car or crates; get-up teleport pops | room tour, acts 2-4, 7 | slot validation, stall re-slot, spawn point positions |
| Frame time or spawn hitches with six rigs and ragdolls | perf sample in act 4 or 7 | stagger spawns more, or the static named-library cache (the rig's one allowed perf change) |
| Test runtime balloons | the suite time after phase 1 | shorten crowd tests, seed them, cap their frames |
