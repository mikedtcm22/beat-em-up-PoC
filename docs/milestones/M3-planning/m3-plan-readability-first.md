# Milestone 3 plan: enemy AI and the rear warning (readability first)

From SPEC §12: "All archetypes in graybox, the director, flanking, the rear-attack warning, and a 6-enemy crowd test room." **Done when:** a 6-enemy fight is readable, and the warning fires correctly behind-left, behind-right and directly behind.

Branch `m3/enemy-ai` (from `main` after M2). One PR into `main` at the end, **never merged without Game-boy's sign-off**. Read SPEC §5, §6, §7, §8, §11 and §12, the six codemaps in `docs/milestones/M3-codemap/`, and CLAUDE.md's rules.

**How this plan is built.** It starts from the done-when and works backwards:
1. what a first-person player must be able to see and hear for a 6-enemy fight to be readable, and for the warning to be "correct";
2. the numbers, bots and captures that prove each of those;
3. the review lenses that will judge them;
4. only then the build packages, each of which owns a slice of that evidence.

The first commit of M3 encodes the warning's rule as a hand-written truth-table test, and the readability measurements exist before the second archetype does.

**Game-boy's M3 answers and the defaults taken** (HANDOFF 2026-10-25 17:05) are requirements here: graybox boss (300 HP, two phases, shoulder charge, grab slam, ground pound; at 50% it turns faster and calls two Street Punks); enemy grabs on the player (telegraphed wind-up that a dodge or a heavy hit escapes; mash P/K to break free; unbroken, the hit lands); a 12 × 30 m street-lane crowd room as the main scene with doorway and alley spawns (some behind the player), repeating mixed waves of up to 6, and a key back to the M2 training room; the KO'd player auto-revives; enemies don't block; the Pipe Thug drops a pipe the player can take; the full director; NavigationAgent3D with avoidance; the rear warning per §8 with tunables in F1; spawns in F4; AI state and tokens in F3. Fine grey-block look/feel questions are not put to Game-boy: take the default and log it in `docs/milestones/M3-judgement-calls.md`. Only first-person looks count; side view and free fly are debug views.

---

## 1. The done-when, made checkable

### 1.1 What a first-person player must see and hear

"Readable" means a player looking through the 90° lens can always answer four questions: *who is about to hit me, from where, with what, and when*. Every item below is something a package builds and something a bot or test measures.

| # | The player must... | How the game provides it | Owner | Proved by |
| --- | --- | --- | --- | --- |
| P1 | see every in-view attack coming | A wind-up on every enemy hit: a **held**, exaggerated, archetype-specific pose (`MovePoses.windup_hold_at`), at least 18 frames for grunts and 30 for the Bruiser and boss (SPEC §7), never scaled below that floor | WP0-sim (hold, floor), every archetype WP (poses) | `test_enemy_move_rules.gd`; per-archetype lens telegraph tests; tell acts |
| P2 | hear every attack coming, and from where | The wind-up's effort grunt and whoosh, positional and rear-muffled (exists, `audio_director.gd:257-279`); a heavier effort pool for the Bruiser and boss; wind-up voices never stolen by the voice pool | WP-W | `test_rear_warning_audio.gd`; probe metric `windup_voices_stolen` |
| P3 | know about an attack from outside the view | The corner burst (SPEC §8), exactly per §1.2 | WP-W | the truth table; the warning sweep test; `warning_oracle_agreement` |
| P4 | never face more than a few attacks at once, and never two starting on the same frame | Attack tokens (cap 3), a minimum gap between grants, a short grace after the player is hit | WP-D | `test_director.gd`; probe `max_concurrent_attackers`, `min_windup_start_gap_frames` |
| P5 | see who is coming next before the wind-up | A token holder **commits** visibly: it stops strafing, squares up for `commit_pause_frames`, then steps in from the ring; afterwards it backs off to the ring | WP-E | `test_enemy_core.gd`; tell acts; probe `ring_adherence` |
| P6 | see the crowd, not a wall of bodies | Posture ring 2.5-4 m; slots spread evenly around the player; avoidance keeps capsules apart; in-view wind-ups not hidden behind other enemies | WP-D (slots), WP-E (ring, avoidance) | probe `front_wedge_crowding`, `fp_enemy_coverage`, `occluded_windup_share`, `capsule_overlap_frames` |
| P7 | tell the archetypes apart at a glance, 2-10 m | Distinct palette per archetype (no red: SPEC §10 reserves it), height (Bruiser 2.05 m, boss 2.3 m), the Thug's pipe, distinct wind-up silhouettes (punch cocked, pipe raised, crouched sweep, arms-wide grab, both-arms-overhead smash or pound, dropped-shoulder charge) | each archetype WP | `test_enemy_identity.gd` (palette distance); tell acts |
| P8 | tell posturing from threatening | Posture walks and taunts never resemble a wind-up: taunts are open-handed gestures, the guard stays at the chin while strafing | WP-E and archetype WPs | tell acts (taunt next to wind-up, same frame size); lens review |
| P9 | see that a hit registered, even on armor | Absorbed hits still fire `hit_landed` with `armor_absorbed`: hit flash, a distinct "clank" spark and sound, "ARMOR" in the combat log, no flinch | WP-E (rule), WP-B (presentation) | `test_enemy_bruiser.gd`; "Bruiser: armor reads" act |
| P10 | stay oriented while held | The player is held upright at arm's length, the look locks toward the grabber, a MASH prompt with progress shows, the release doesn't pop the lens | WP-G | `test_enemy_grab.gd` (lens clearance, eye jump at release); grab acts |
| P11 | see the boss's state | Boss bar bottom centre; phase 2 announced by a roar and two Punks walking in from spawn points | P0-ui (bar hookup), WP-X | `test_enemy_boss.gd`; boss acts |
| P12 | not be ganged up on unfairly | No single knockdown over 15 HP except the boss (SPEC §4); a passive player survives a while; burst damage bounded | WP0-sim (rule test), every archetype WP (data), WP-D (pacing) | `test_enemy_move_rules.gd`; probe `max_knockdown_hit_damage_non_boss`, `passive_time_to_ko_s`, `max_damage_2s` |
| P13 | keep a smooth frame | 60 fps with six enemies, no spawn hitch | WP-D (staggered spawns), Phase 3 perf | perf act; lens L6 |

### 1.2 The warning rule, exactly (SPEC §8)

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

### 1.3 Readability metrics and thresholds

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

### 1.4 The evidence pack (Phase 3 records it; the PR and the Slack digest quote it)

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

### 1.5 Review lenses (Phase 4) and the readability rubric

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

## 2. The shape that serves readability (decisions every package builds on)

- **AI is an overlay on `CombatActor`.** `EnemyActor extends CombatActor` (new) holds the brain in `_tick_control()`. It acts only in `FREE`; every other `ActorState` belongs to `CombatActor`. Its own states are `AiState` (new, WP0-sim): `ENTER, APPROACH, POSTURE, TAUNT, COMMIT, WINDUP, ATTACK, RECOVER, REACT, DOWN, HOLD, KO`. `TrainingDummy` is untouched.
- **The director grants; the enemy acts.** `EnemyDirector` runs before the actors (`process_physics_priority` −10) and only flags tokens and pushes posture slots. The enemy starts its attack from its own `_tick_control()`, so frame 0 is applied (codemap actors-combat §3.3).
- **One attack, one telegraph, one token.** A token covers one attack string. Each **hit** in it gets its own `WINDUP` of at least the move's `windup_floor` (18 grunts, 30 heavy). Follow-ups chain only if the previous hit landed or was blocked. The token is released when the string ends, is interrupted, or the holder is hit.
- **Visible commitment.** Token → `COMMIT`: stop, face, square up (`commit_pause_frames`), step in to `reach_m − reach_slack_m`, then wind up. The wind-up tracks the player for `windup_track_share` of its length, then locks (a sidestep or dodge beats it). After the attack, `RECOVER` backs off to the ring.
- **Spread in world space.** Slots sit on the ring around the player, evenly spaced (at least `spread_min_gap_deg` apart), and are reassigned at most every `slot_reassign_s`. An enemy's `slot_preference()` (−1 in front … +1 blind side) only decides which enemy gets which angle: Punk −0.5, Thug −0.3, Bruiser −0.5, Kicker +1, boss 0. Slots don't rotate with the look; the Kicker re-circles to the blind side itself.
- **"Outside the view" has one definition**: `ViewGeometry.is_outside_view(player, point, rear_warning_angle_deg)` from `look_yaw`. The director's blind-spot priority and the warning both use it.
- **Light hits:** grunts' wind-ups are interrupted by any accepted hit (today's behaviour). The Bruiser absorbs light hits always; the boss absorbs light hits during its wind-ups. Heavy hits stagger both; finishers and `breaks_armor` keep their reaction. All through one `CombatActor._apply_armor(hit)` hook (WP0-sim) and an `armor_mode` on `EnemyActor` (WP-E).
- **Enemy grabs** use a shared holder component (WP-G): the grab move has no hitboxes; it connects in code at its strike frame if `player.can_be_grabbed()` and the player is within range and angle. The hold time is the mash window. Breaking free staggers the holder. The final hit releases the player first, then lands as a code-applied hit (CA's GRABBED rule would otherwise swallow it).
- **Enemies are freed** after they blink off (M2's approved departure): leave the groups, drop the token, then `queue_free()`.
- **Spawns are staggered** one per `wave_spawn_interval_s` (a rig build costs about 10 ms).
- **Navmesh per room**, baked synchronously with the codemap's recipe (godot-navigation §0); single-thread avoidance for determinism; the player is a `NavigationObstacle3D` added by the room.

---

## 3. Phases, sequencing and usage

| Phase | Packages | Runs | Est. cost (premium seat, % of a 5-hour window) |
| --- | --- | --- | --- |
| **0. Contracts** | WP0-sim, WP0-ui | in parallel, two worktrees; lead merges | 5-8 |
| **1. Foundations** | WP-E enemy core + Street Punk; WP-D director, crowd room, waves; WP-W rear warning; WP-G enemy grabs; WP-I instruments | at most 3 builders at once on this 8 GB machine: start WP-E, WP-D, WP-W; WP-G and WP-I as slots free | 35-45 |
| **1R. Early readability check** | one Opus reviewer (lenses L1 + L2 on Punks only, real director), then at most one Sonnet fix package | after the Phase 1 merge | 6-10 |
| **2. Archetypes** | WP-K Kicker; WP-T Pipe Thug; WP-B Bruiser; WP-X Boss | 3 at once, then the fourth | 25-35 |
| **3. Integration and evidence** | lead | main scene switch, wave table, evidence pack | 2-4 |
| **4. Adversarial review** | lenses L1-L6, skeptics, critic, partition, fixers; up to 3 rounds | M2 workflow scripts copied to `docs/reviews/M3/` | 30-50 (round 1), 15-25 (later) |
| **5. Docs, PR, export, release, Slack** | lead | | 2-3 |

Rules:
- `get_usage` before every launch; launch only what fits below 90% (HANDOFF "Usage rules"). Re-measure costs and update HANDOFF's table after Phase 1.
- Update HANDOFF.md at every phase boundary, and `M3-judgement-calls.md` whenever a call is made.
- **One Godot process per agent at a time.** Movie Maker runs only under the global lock in `tools/capture_bot.sh`, so two agents never record at once.
- Phase 1R exists because the crowd-level problems (director pacing, posture noise, spread, warning wiring with real AI) are cheapest to find and fix with one archetype, before four more copy the pattern.

---

## 4. Contract hot spots and how this plan avoids conflicts

**Principle: every edit to a shared file that two packages would want lands in Phase 0, before any parallel build.** Phase 1 and 2 packages only create new files, fill their own pre-made stubs, or edit a file no other package in the same phase owns. A builder that needs a contract change doesn't make it: it reports it in its final output (`contract_requests`), and the lead lands it between phases.

| File | Phase 0 | Phase 1 owner | Phase 2 owner | How conflicts are avoided |
| --- | --- | --- | --- | --- |
| `game/actors/combat_actor.gd` | WP0-sim: every M3 hook | none | none | All hooks land at once; packages override, never edit |
| `game/autoload/combat_events.gd` | WP0-sim: every M3 signal | none | none | Same |
| `game/combat/move_data.gd` | WP0-sim: `reach_m`, `windup_floor` | none | none | Same |
| `game/autoload/tuning_data.gd` + `tuning/default.json` | WP0-sim declares **every** M3 tunable (Appendix A), in one subgroup per package | each package may append only at the end of its own subgroup block | same | Blocks are separated by other subgroups' lines, so appended hunks never touch. Each branch regenerates `default.json` for its own tests; **the lead regenerates it after every merge** and never hand-merges it |
| `tests/test_tuning_panel.gd` (`:390`, the "Enemies" headings) | WP0-sim updates it to the final subgroup list | none | none | The list is fixed in Phase 0 |
| `game/actors/placeholder_poses.gd`, `placeholder_anims.gd` | WP0-sim: `windup_hold_at`; a dispatcher to per-archetype pose files; placeholder named ids | none (each WP owns its own `game/actors/poses/enemy_poses_<x>.gd`) | same | The shared files gain one dispatch line each; content lives in disjoint files |
| `tools/gen_moves.gd` | WP0-sim: `_build_enemy_moves()` calling `_punk_moves()`, `_kicker_moves()`, `_thug_moves()`, `_bruiser_moves()`, `_boss_moves()` (each `pass`, separated by doc comments and blank lines); `dummy_jab.reach_m` | WP-E fills `_punk_moves()` only | each fills its own stub | Non-adjacent hunks; generated `.tres` files are per id; regeneration is deterministic and keeps UIDs |
| `tests/test_move_data.gd` | WP0-sim: whole-folder and blocking rules skip ids with enemy prefixes; new `test_enemy_move_rules.gd` applies the universal enemy rules | none | none | Per-archetype data tests go in per-archetype files |
| `game/ui/hud.gd`, `hud.tscn` | WP0-ui: `RearWarning` and `GrabPrompt` nodes with stub scripts, the boss-bar hookup | WP-W owns `rear_warning.gd`; WP-G owns `grab_prompt.gd` | none | Nobody edits hud files after Phase 0 |
| `game/autoload/game_input.gd`, `game/ui/help_overlay.gd`, `tests/test_ui.gd` | WP0-ui: `switch_room` on F6, its help row, the help test | none | none | Fixed in Phase 0 |
| `tests/bot/combo_bot.gd` | WP0-ui: `_room_scene()` hook | none | none | Bots extend it in their own files |
| `project.godot` | WP0-sim: the `[navigation]` block | none | none | Lead switches the main scene in Phase 3 |
| `game/player/player.gd` | none (the look helpers go in the new `ViewGeometry`) | WP-G only | none | One owner |
| `game/ui/debug_draw.gd`, `cheat_menu.gd` | none | WP-I only | none | One owner |
| `game/audio/audio_director.gd`, `tools/gen_sfx.gd`, `ASSETS.md` (audio rows) | none | WP-W only | WP-B only (armor clank) | One owner per phase |
| `game/fx/vfx_director.gd`, `game/ui/combat_log_overlay.gd` | none | none | WP-B only (armor spark, "ARMOR" tag) | One owner |
| `game/weapons/weapon.gd` | none | none | WP-T only (`drop()`) | One owner |
| `game/level/test_room.gd` | none | WP-D only: **append** a `RoomKit.add_ai_support(self)` call at the end of `_ready()` and the F6 handler; no geometry or child-order change | none | One owner; existing children keep their indices |
| `game/enemies/enemy_actor.gd` (+ `game/enemies/core/*`) | none | WP-E | none: archetypes **extend** it | Extension points are designed in (WP-E); base changes go through `contract_requests` |
| `docs/ARCHITECTURE.md` | WP0-sim writes a "Milestone 3 contracts" section | each WP appends its own section | same | Separate sections, append only |
| `docs/milestones/M3-judgement-calls.md` | lead | builders report calls in their output; the lead writes them | same | One writer |

Parallel compile trap: `test_scripts_compile.gd` loads every script under `res://game`. Code that crosses package boundaries (debug draw reading the director, the warning reading `heavy`, F4 reading the catalog) is **duck-typed** (`has_method()`, `get()`, groups), never typed to a `class_name` from another package's worktree.

---

## 5. Common builder rules (the lead pastes this block into every brief)

- Work only in your worktree, `cd` there for every command: `/Users/arachne/repos/beat-em-up-PoC/.worktrees/<name>`. The lead created it with `git worktree add .worktrees/<name> -b <branch> m3/enemy-ai`. Run `godot --headless --import --quit` there first.
- Read CLAUDE.md, this plan's §1, §2, §4, your package section and Appendix A/B/C, the codemaps your section names, and ARCHITECTURE's "Milestone 3 contracts".
- **Code rules:** static types, tabs, `##` doc comments on public API; no feel or attack numbers in game scripts (attack numbers in `tools/gen_moves.gd`; feel numbers in `TuningData`, already declared for you in Appendix A; layout data as `@export`s on rooms); simulation never reads a camera; presentation subscribes and reads, never writes game state.
- **Own only your files.** Never edit a file outside your list. If you need a contract change (a `CombatActor` hook, a signal, a field, a tunable outside your subgroup), stop that part, work around it if you can, and list it under `contract_requests` in your final output.
- Move data: edit only your stub in `tools/gen_moves.gd`, then run `godot --headless --import --quit && godot --headless -s tools/gen_moves.gd && godot --headless --import --quit` and check for the "gen_moves: wrote" line. Never hand-edit a `.tres`.
- New tunables (only if Appendix A lacks one you need): append at the end of your own subgroup, then `godot --headless -s tools/gen_default_preset.gd`.
- Tests: during work, `tools/run_tests.sh -gselect=<your file>`; before every non-wip commit, the full `tools/run_tests.sh` (about 1.5-2 minutes). Read the whole output: all pass, no `SCRIPT ERROR`, no `ERROR`.
- Captures: `tools/capture_bot.sh res://tests/bot/<bot>.tscn captures/<your-name>/ "<act filter>" 6`. It waits for the global Movie Maker lock. Then **look** at the sheets with the Read tool; judge first person. Never commit `captures/`.
- Commit `wip:` every 15-20 minutes and push. Final commit subject: `M3 <WP key>: <summary>`, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Push.
- If told to halt (usage limit): finish the current edit, commit `wip:`, push, and stop.
- Final output: what you built, test count, the sheets you judged and what you saw, the judgement calls you made (each with the alternative you rejected and why), `contract_requests`, and known gaps.

---

## 6. Work packages

### WP0-sim: simulation contracts (Phase 0)
- **Goal:** land every shared simulation contract and the warning's truth table, with zero behaviour change. After it, Phase 1 packages never touch a hot spot.
- **Worktree / branch:** `.worktrees/m3-contracts-sim`, `m3/contracts-sim`.
- **Owned files:** `game/actors/combat_actor.gd` (hooks only), `game/autoload/combat_events.gd`, `game/combat/move_data.gd`, `game/combat/view_geometry.gd` (new), `game/enemies/ai_state.gd` (new), `game/enemies/enemy_catalog.gd` (new), `game/autoload/tuning_data.gd`, `tuning/default.json`, `tests/test_tuning_panel.gd` (the `:390` headings assert only), `game/actors/placeholder_poses.gd`, `game/actors/placeholder_anims.gd`, `game/actors/poses/*` (new: dispatcher plus empty per-archetype files), `tools/gen_moves.gd`, `game/combat/moves/dummy_jab.tres` (regenerated), `tests/test_move_data.gd` (scoping only), `tests/test_enemy_move_rules.gd` (new), `tests/test_view_geometry.gd` (new), `tests/test_m3_contracts.gd` (new), `tests/helpers/stub_ai_enemy.gd`, `tests/helpers/stub_director.gd` (new), `project.godot` (`[navigation]` only), `docs/ARCHITECTURE.md` ("Milestone 3 contracts" section).
- **What to build:**
  1. **`CombatActor` hooks** (defaults keep today's behaviour exactly; 537/537 stays green):
     - `func _apply_armor(hit: HitInfo) -> void` (default no-op), called in `receive_hit()` after damage, `killed` and the flash, **before** `_cancel_move()`. If afterwards `hit.armor_absorbed and not hit.killed`: emit nothing new (HD still emits `hit_landed`), call `_on_hit_absorbed(hit)` (new hook, no-op) and return true, skipping the cancel, `_on_hit_received()` and `_apply_reaction()`.
     - `func _on_grabbed(by: CombatActor) -> void` (no-op), called at the end of `start_grabbed()`.
     - `func _held_anim() -> StringName` returning `&"held"`, used at `start_grabbed()` and the knee jolt instead of the literal.
     - `func _keeps_strike_pose() -> bool` returning false; `_pull_strike`'s snap to idle is skipped while it returns true.
     - `func abort_move() -> void` (public): if a move runs, `_cancel_move()` then `_return_to_neutral()`.
     - `func break_free(push: Vector3) -> void` (public, victim side): if GRABBED with a valid holder: call the holder's `_on_hold_broken(self)` if it has it, emit `CombatEvents.grab_escaped(holder, self)`, then `release_from_grab(push, false)`.
     - In `_pin_to_holder()`: also release (`release_from_grab(Vector3.ZERO, false)`) when the holder is KO, gone, flying or downed (today only a freed holder releases).
     - Tests in `tests/test_m3_contracts.gd`: a subclass absorbing hits keeps its wind-up and takes the damage; `break_free` emits and releases; the pin releases from a KO'd holder; `_held_anim()` override is played; `abort_move()`.
  2. **`CombatEvents`** (all with `##` docs): `ai_state_changed(enemy, old_state: int, new_state: int)`, `attack_token_changed(enemy, has_token: bool, blind: bool)`, `grab_escaped(holder, victim)`, `boss_phase_changed(boss, phase: int)`, `enemy_spawned(enemy, spawn_tag: StringName)`, `wave_started(index: int, count: int)`, `wave_cleared(index: int)`, `weapon_dropped(actor, weapon)`.
  3. **`MoveData`:** `@export_range(0.0, 8.0, 0.01) var reach_m: float = 0.0` ("Enemy moves: flat origin-to-origin distance at which the strike connects with a standing 1.8 m player. The AI steps in to it; the rear warning fires within it plus `rear_warning_range_margin_m`. 0 for player moves.") and `@export_range(0, 120, 1) var windup_floor: int = 0` ("Enemy moves: the least startup `windup_mult` may scale this move to. SPEC §7: 18 for grunts, 30 for the Bruiser and the boss."). In `gen_moves.gd` set `dummy_jab.reach_m = 1.05` (its measured reach) and regenerate.
  4. **`ViewGeometry`** (`class_name ViewGeometry extends RefCounted`, static only): `look_forward(look_yaw) -> Vector3`; `bearing_deg(origin, look_yaw, point) -> float` (signed, + left, ±180 behind, wrapped); `player_bearing_deg(player: Node3D, point) -> float` (reads `look_yaw` duck-typed, origin `global_position`); `is_outside_view(player, point, half_angle_deg) -> bool`; `flat_distance(a, b) -> float`; `enum Corner { NONE, LEFT, RIGHT, BOTH }`; `warning_corner(bearing_deg, distance_m, reach_m, view_half_angle_deg, behind_half_angle_deg, range_margin_m) -> int` (§1.2 rules 1-2). Yaw convention as `player.gd:662` (`atan2(-x, -z)`). `tests/test_view_geometry.gd` holds §1.2's table as literal rows, plus bearing tests (0, ±90, 180, wrap at ±π).
  5. **`AiState`** (`class_name AiState`): the enum of §2 and `static func name_of(state: int) -> String`.
  6. **`EnemyCatalog`** (`class_name EnemyCatalog`): `const ENTRIES` of `{id, label, scene}` for `dummy` (`training_dummy.tscn`), `punk` (`res://game/enemies/punk/street_punk.tscn`), `kicker` (`.../kicker/kicker.tscn`), `thug` (`.../thug/pipe_thug.tscn`), `bruiser` (`.../bruiser/bruiser.tscn`), `boss` (`.../boss/boss.tscn`); `available() -> Array` (filters with `ResourceLoader.exists`), `scene_of(id)`, `label_of(id)`.
  7. **Tunables:** every entry of Appendix A, in the listed groups and subgroups, with ranges, defaults and `##` docs. The "Enemies" group keeps its three top properties first, then the subgroups. Update `test_tuning_panel.gd:390` to the new headings list. Regenerate `tuning/default.json`.
  8. **Rig scaffold** (codemap rig-anims-moves §15.2, §16):
     - `MovePoses.windup_hold_at: float = -1.0`; `build_move()` adds a second wind-up key at `windup_hold_at × startup` when ≥ 0 (and in `mirrored()`). Test: a recipe with hold 0.85 keeps the wind-up pose from `windup_at` to 0.85 of startup.
     - `game/actors/poses/enemy_poses.gd` (`class_name PlaceholderEnemyPoses`): `recipe(id, g, wg) -> PlaceholderPoses.MovePoses` asks each archetype file in turn; `has_recipe(id)`; `named_keys(id, g, scale) -> Array` (`[length_s, keys, loops]` or empty) asks each file; `NAMED_IDS`, `LOOPING_IDS`.
     - One file per owner, each with `const MOVE_IDS: Array[StringName] = []`, `const NAMED_IDS`, `const LOOPING_IDS`, `static func recipe(...) -> MovePoses: return null` and `static func named_keys(...) -> Array: return []`: `enemy_poses_punk.gd` (named `taunt_punk`), `enemy_poses_kicker.gd` (`taunt_kicker`), `enemy_poses_thug.gd` (`taunt_thug`), `enemy_poses_bruiser.gd` (`taunt_bruiser`, `brace`), `enemy_poses_boss.gd` (`taunt_boss`, `summon`, `run_forward`), `grab_poses.gd` (`hold_collar`, `held_collar`, `held_lift`).
     - `PlaceholderPoses._recipe()` ends with `return PlaceholderEnemyPoses.recipe(id, g, wg)`; `PlaceholderAnims.build_named()`'s default branch and `HumanoidRig.has_anim()` ask the dispatcher. Until a file fills an id, its named anim holds the stance (no warning).
  9. **Generator scaffold:** `_build_enemy_moves()` at the end of `_build_moves()`; the five stubs; a helper `_enemy(id, name, frames: Vector3i, damage, tier, reaction, knockback, hitboxes, reach_m, windup_floor) -> MoveData` that also sets `magnetism = false` and leaves camera fields at 0. Regenerate: only `dummy_jab.tres` changes.
  10. **Move tests:** `test_move_data.gd` keeps every player assertion but skips ids starting with `punk_`, `kicker_`, `thug_`, `bruiser_`, `boss_` in `test_moves_folder_holds_only_table_moves`, `test_blocking_fields` and `test_finisher_tier_matches_branch_graph`. New `tests/test_enemy_move_rules.gd` applies to every enemy-prefixed move: `magnetism` false; no branches, repeats or `auto_next`; camera fields 0; `get_anim() == id` and the rig has its anim; `windup_floor ≥ 18` (≥ 30 for `bruiser_`/`boss_`) and `startup ≥ windup_floor`; `reach_m > 0` when it has hitboxes; `blocked_recoil_frames == 0` for `bruiser_`/`boss_`; **damage ≤ 15 for any KNOCKDOWN, LAUNCH or THROWN reaction unless `boss_`** (SPEC §4). It passes vacuously until moves exist.
  11. **Test doubles** (in `tests/helpers/`, never shipped): `stub_ai_enemy.gd` (`extends TrainingDummy`, joins `"ai_enemy"`, implements the AI-enemy contract of Appendix C with direct steering: walk to its slot; on a token, walk to 0.9 m and `start_jab()`; release the token when the jab ends or it is hit; exports `heavy`, `slot_pref`; sparring and walk-home off) and `stub_director.gd` (joins `"enemy_director"`, implements the read API with settable values).
  12. **`project.godot`:** the `[navigation]` block from godot-navigation §0 (`3d/default_cell_height=0.1`, single-thread avoidance, both async iterations off).
  13. **ARCHITECTURE:** a "Milestone 3 contracts" section with every name above and Appendix C's interfaces.
- **Provides:** everything in Appendix C marked P0-sim.
- **Tests:** `test_view_geometry.gd`, `test_m3_contracts.gd`, `test_enemy_move_rules.gd`, the rig scaffold test (in `test_m3_contracts.gd`), the updated tuning test; the full suite at 537 + new, no errors.
- **Captures:** none (no visible change). Run the combo bot's "Jab" act once to confirm nothing moved.
- **Acceptance:** all existing tests unchanged and green; new tests green; `default.json` regenerated; the lead reviews the diff for behaviour neutrality.
- **Size:** about phase 3's B, ~0.7 of WP4 (4-6%).

### WP0-ui: UI and tooling scaffold (Phase 0, parallel with WP0-sim)
- **Goal:** pre-wire the HUD, input and capture tooling so no Phase 1 package edits them.
- **Worktree / branch:** `.worktrees/m3-contracts-ui`, `m3/contracts-ui`.
- **Owned files:** `game/ui/hud.gd`, `game/ui/hud.tscn`, `game/ui/hud_style.gd` (one constant), `game/ui/rear_warning.gd` (stub), `game/ui/grab_prompt.gd` (stub), `game/autoload/game_input.gd`, `game/ui/help_overlay.gd`, `tests/test_ui.gd` (help test only), `tests/test_hud_m3.gd` (new), `tests/bot/combo_bot.gd` (the hook only), `tools/capture_bot.sh` (new), `tests/test_bot_scripts_compile.gd` (new).
- **What to build:**
  1. `RearWarning extends Control` stub: `signal shown(corner: int, count: int, heavy: bool)`, `signal cleared(corner: int)`, `func advance(delta: float) -> void`, `func corner_state(corner: int) -> Dictionary` (returns `{visible = false}`). `GrabPrompt extends Control` stub with `advance()`. Both added to `hud.tscn` full-rect with `mouse_filter = IGNORE`, `@onready` in `hud.gd`, stepped with `game_delta` in `advance()`. `HudStyle.REAR_CORNER_SHARE := Vector2(0.2, 0.2)`, used by the existing corner test's numbers.
  2. **Boss bar hookup** in `hud.gd`: each `advance()`, when no boss is shown, the first node in group `"boss"` with health above 0 gets `show_boss()`; hide once it is gone or freed. Test with a fake actor in the group.
  3. **`switch_room`** in `BINDINGS` on F6; a `HelpOverlay.DEBUG_ROWS` row "Training room / crowd room"; the help test expects "F6". Check that `test_hud_stays_out_of_the_top_corners` still passes with the new row.
  4. `combo_bot.gd`: `func _room_scene() -> PackedScene: return ROOM`, used in `_ready()`.
  5. **`tools/capture_bot.sh <scene res path> <out dir> [act filter] [stills fps] [--corners]`:** takes a machine-wide lock (`mkdir "$(git rev-parse --git-common-dir)/movie.lock"`, waits, removes on exit and on error), `touch captures/.gdignore`, runs `godot --path . --write-movie <dir>/rec.avi --fixed-fps 60 --resolution 1280x720 <scene> -- --act=<filter>` with `--quit-after` as a guard, writes `<dir>/bot.log`, then ffmpeg stills and a 5 × 4 sheet per act (from the `=== title (fN)` lines), and with `--corners` also corner-crop sheets (`crop=iw*0.3:ih*0.3:0:0` and the right-hand twin).
  6. `test_bot_scripts_compile.gd`: loads every `res://tests/bot/*.gd` and `res://tests/helpers/*.gd`.
- **Acceptance:** full suite green; `capture_bot.sh` records combo_bot's "Jab" act into a scratch folder and produces a sheet; two concurrent invocations serialize.
- **Size:** small, ~0.3 of WP4 (2-3%).

**After Phase 0:** the lead merges both into `m3/enemy-ai`, regenerates `default.json`, runs the full suite, pushes, updates HANDOFF, then creates the Phase 1 worktrees from the new head.

---

### WP-E: enemy core and the Street Punk (Phase 1)
- **Goal:** one `EnemyActor` base every archetype extends, with the readable behaviour loop (enter, approach, posture, commit, wind-up, attack, recover, react, KO), navigation with avoidance, armor modes, and the Street Punk as the first complete archetype.
- **Worktree / branch:** `.worktrees/m3-enemy-core`, `m3/enemy-core`.
- **Owned files:** `game/enemies/enemy_actor.gd` (`class_name EnemyActor`), `game/enemies/core/*` (helpers you split out), `game/enemies/punk/street_punk.gd` + `.tscn`, `game/actors/poses/enemy_poses_punk.gd`, `tools/gen_moves.gd` (`_punk_moves()` body only), `game/combat/moves/punk_*.tres`, Appendix A subgroups "Posture", "Navigation", "Street Punk" (append only), `tests/test_enemy_core.gd`, `tests/test_enemy_punk.gd`, `tests/test_enemy_identity.gd`, `tests/bot/enemy_bot.gd` + `.tscn`, ARCHITECTURE section "Enemy actor".
- **Must not touch:** `combat_actor.gd`, `training_dummy.gd`, `test_room.gd`, the director or room files (WP-D), `player.gd`.
- **Consumes:** the WP0-sim hooks, `AiState`, `ViewGeometry`, `CombatEvents.ai_state_changed`, the AI-enemy contract and the director read API (Appendix C), `stub_director.gd`.
- **Provides (for WP-D, WP-I and Phase 2):** the Appendix C AI-enemy contract implemented, plus these extension points for archetypes (document each with `##`):
  - `func _health_tunable() -> float`, `func _speed_mult() -> float`
  - `func _choose_attack() -> MoveData` (the first move of the next string)
  - `func _next_in_chain(previous: MoveData, landed: bool) -> MoveData` (null ends the string)
  - `func _on_attack_frame(move: MoveData, frame: int) -> void` (lunges at chosen frames via `set_lunge()`, code-applied hits)
  - `func _posture_tick() -> bool` (return true to replace the default posture motion for this tick; the Kicker uses it)
  - `var armor_mode: int` (`ArmorMode.NONE`, `WINDUP_LIGHT`, `ALWAYS_LIGHT`)
  - `func windup_move(move: MoveData) -> MoveData`, `func start_attack(move: MoveData) -> void`, `func force_attack(move_id: StringName = &"") -> bool` (bots)
  - `func place(pos: Vector3, yaw: float) -> void` (ghost-for-one-step teleport after `add_child`, as `TrainingDummy.set_post()` does; also `set_velocity_forced(ZERO)` on the agent)
  - `func warning_reach_m(move) -> float` (default `move.reach_m`)
- **Behaviour:**
  1. `_ready()`: `team = 1`, groups `"enemy"` and `"ai_enemy"`, `max_health = _health_tunable()` **before** `super._ready()`; RNG seeded from `name`; a `NavigationAgent3D` child set up from "Navigation" tunables (`avoidance_enabled`, `radius`, `height = body_height`, `max_speed`, the reach distances, neighbour distance, time horizon); the latched movement pattern (godot-navigation §5.2): `velocity_computed` only stores the safe velocity; `_tick_control()` writes `sim_velocity` from it. Re-apply agent settings on `Tuning.changed`.
  2. **States** (emit `ai_state_changed` on every change):
     - `ENTER`: walk to `entry_target` (set by the spawner before `add_child`), then `APPROACH`. None set: straight to `APPROACH`.
     - `APPROACH`: navigate to the slot (from the director; without one, its own point on the ring at its current bearing). Within the ring: `POSTURE`.
     - `POSTURE`: face the player (turn at `enemy_turn_rate`); pick a sub-mode every `strafe_switch_min_s`..`max_s`: orbit (slow, one direction), strafe (short side-steps), hold (stand in guard), or taunt (`taunt_chance_per_s`, `taunt_cooldown_s`; plays `taunt_<archetype>` and stays `FREE`, so hits interrupt it). Stay within a third of the slot spacing of the slot. Walk animation from `play_locomotion()` with the **local** direction, so strafes play `walk_left/right`. `ai_frozen` (Debug) holds every enemy here, facing the player.
     - `COMMIT` (token granted): stop, face, hold `commit_pause_frames`, then step in at `step_in_speed_mps` until the flat distance ≤ `reach_m − reach_slack_m` of `_choose_attack()`; give the token back after `token_hold_max_s` without reaching.
     - `WINDUP`/`ATTACK`: zero horizontal `sim_velocity`, `start_attack()`. Track the player's position for the first `windup_track_share` of the wind-up, then lock facing. No `free_lunge`: `_plan_lunge()` is overridden to do nothing; lunges come from `_on_attack_frame()`.
     - `RECOVER`: when a move finishes, `_next_in_chain(move, landed)`; a follow-up starts with its own wind-up (`start_attack`). Otherwise release the token, back off at `retreat_speed_mps` until the ring's inner edge, then `POSTURE`.
     - `REACT`: any reaction state (hitstun, stagger, launched, thrown, grabbed): do nothing but report the real velocity to the agent; release the token if held. Back in `FREE`: `APPROACH`.
     - `DOWN` (downed, getting up), `HOLD` (archetypes that grab; WP-G's component), `KO`.
     - `KO`: release the token; once `is_gone()`, leave `"enemy"`, `"ai_enemy"` and `"actor"`, then `queue_free()`.
  3. **Tokens:** with a node in `"enemy_director"`, `wants_token()` is true in `POSTURE` after `token_cooldown_s`; the director calls `grant_token()`/`revoke_token()`. **Without a director** (tests, worktrees): self-grant in `POSTURE` with a seeded chance per second, at most one self-granted attacker per 1 s per enemy. Document it as a fallback, not a design.
  4. **Wind-up helper:** `windup_move(move)` returns a cached duplicate with `startup = max(move.windup_floor if Tuning.data.windup_respect_floors else 1, roundi(move.startup × windup_mult))`, cached per `move.id` and mult, dropped on `Tuning.changed` for `&""`, `windup_mult` and `moves/<id>/…`.
  5. **Armor** (`_apply_armor` override, by `armor_mode`): a hit is *light* when `tier == LIGHT and not move.breaks_armor`. `WINDUP_LIGHT`: light hits during `WINDUP` are absorbed. `ALWAYS_LIGHT`: light hits are always absorbed, and heavy hits that would knock down become `STAGGER`. Absorbed: `hit.armor_absorbed = true`, `reaction = NONE`, `knockback = ZERO`, damage still applies; killing hits are never absorbed. Finishers and `breaks_armor` keep their reaction.
  6. **No-navmesh fallback:** if `NavigationServer3D.map_get_iteration_id(map) == 0` or the map has no regions, steer straight at the target. Never query the map before the sync (no `ERROR` lines).
  7. **Debug text:** `debug_state_text()` = super + `"\nAI <STATE>"` + `" TOKEN"` while held + `" blind"` when the director says so. Keep it short.
  8. `debug_nav_path() -> PackedVector3Array` (the agent's current path) for F3.
- **Street Punk** (`archetype = &"punk"`, `slot_preference()` −0.5, `heavy = false`, body 1.8 m, colours as `.tscn` exports; proposed teal body (0.1, 0.62, 0.6) with a white accent, adjusted to pass `test_enemy_identity.gd`):
  - Moves (Appendix B): `punk_jab` → `punk_cross` (follow-up only if the jab landed or was blocked), or `punk_shove` (chance `punk_shove_chance`).
  - Poses in `enemy_poses_punk.gd`: `punk_jab` reuses `_dummy_jab`'s strike with a held wind-up (`windup_at` 0.5, `windup_hold_at` 0.85); `punk_cross` reuses `_jab_2`'s strike with a cocked-rear-hand wind-up; `punk_shove` reuses `_shove`'s strike with hands drawn to the chest; `taunt_punk`: a palm-up beckon (open hands, never a cocked fist). Keep upper-arm raises ≤ 140° (ragdoll limits, codemap G7).
- **Tests** (`tests/test_enemy_core.gd`, `with_presentation = false`, the test room plus `stub_director.gd`, all seeded):
  - a Punk spawned 6 m away reaches `POSTURE` inside the ring in ≤ 4 s, and stays 2.5-4 m while posturing;
  - with `windup_mult` 0.25 the wind-up stays at the floor; with `windup_respect_floors` off it scales;
  - a light hit interrupts a Punk's wind-up (`windup_ended(true)`); with `armor_mode = WINDUP_LIGHT` it doesn't, and a heavy hit does; `ALWAYS_LIGHT` absorbs a light hit outside the wind-up (damage taken, `armor_absorbed`, `hit_landed` emitted, no flinch) and turns a heavy knockdown into a stagger;
  - horizontal displacement during `WINDUP` is only the planned lunge (no slide through the telegraph);
  - a player sidestepping 1 m after `windup_track_share` makes the jab whiff; before it, the jab tracks;
  - after an attack the Punk backs off past the ring's inner edge within 2 s;
  - the token is released on: hit out of `COMMIT`, hit out of the wind-up, the string ending, KO; a KO'd Punk leaves its groups and is freed after it vanishes;
  - without a navmesh it still reaches its slot; with a small navmesh baked in the test it follows the path; no `ERROR` lines;
  - `ai_frozen` holds it in `POSTURE`; `debug_state_text()` shows the state and TOKEN;
  - **R3 for the Punk:** every hit on the player is preceded by a wind-up ≥ 18 frames.
  - `tests/test_enemy_punk.gd`: each move's `reach_m` within ±0.1 m of the strike point measured on a Punk rig against a 1.8 m standing player rig (codemap rig §15.4 pattern); the telegraph seen from the player's lens at 1.0 m and 3.0 m (`FPView.hits`, like `test_dummy_jab_telegraphs_its_wind_up`: the cocked limb visibly displaced during the hold); key poses within the ragdoll joint limits; `punk_cross` only after a landed or blocked jab; the shove staggers the player.
  - `tests/test_enemy_identity.gd`: every archetype scene that exists has 4-6 rig colours, none of them red-dominant, and body colours at least 0.25 apart (RGB distance) from each other and from the player's. (Phase 2 scenes are picked up automatically through `EnemyCatalog.available()`.)
- **Captures** (`tests/bot/enemy_bot.gd` extends `combo_bot.gd`; test room; `enemy_bot` acts take an archetype id so Phase 2 bots can reuse them):
  - "Punk: tells at 3 m" and "Punk: tells at 1 m" (player still, one Punk forced to attack with `force_attack()`, each move twice);
  - "Punk: taunt beside a wind-up" (two Punks, one taunting while the other winds up, both in view);
  - "Punk: posture" (three Punks, `ai_frozen` off, no player action, 10 s);
  - "Punk: hit out of the wind-up".
  - **Judge:** the wind-up pose holds and reads at both distances; taunt never looks like a wind-up; no sliding during telegraphs; strafes play side-steps, not moonwalks; backing off is visible.
- **Acceptance:** tests green; sheets judged and described; ARCHITECTURE "Enemy actor" section.
- **Size:** the largest Phase 1 package, ~1.3 × WP4 (9-13%).

### WP-D: director, crowd room, navmesh and waves (Phase 1)
- **Goal:** the director rules of SPEC §7 with readability pacing; the 12 × 30 m crowd room with doorway, alley and vehicle spawn points, some behind the player; repeating waves of up to 6; navmesh and avoidance plumbing in both rooms; the F6 room switch.
- **Worktree / branch:** `.worktrees/m3-director`, `m3/director`.
- **Owned files:** `game/enemies/director/enemy_director.gd` (`class_name EnemyDirector`), `game/level/nav_baker.gd` (`class_name NavBaker`), `game/level/room_kit.gd` (`class_name RoomKit`, static helpers: presentation build, player spawn, AI support, room switch), `game/level/crowd_room.gd` + `.tscn`, `game/level/wave_spawner.gd` (`class_name WaveSpawner`), `game/level/test_room.gd` (append-only, see §4), Appendix A subgroups "Director" and "Waves", `tests/test_director.gd`, `tests/test_crowd_room.gd`, `tests/test_nav_baker.gd`, `tests/bot/director_bot.gd` + `.tscn`, ARCHITECTURE sections "Director", "Crowd room".
- **Must not touch:** `enemy_actor.gd` (WP-E), `player.gd`, hud files, `cheat_menu.gd`, `debug_draw.gd`.
- **Consumes:** the AI-enemy contract (tested with `stub_ai_enemy.gd`), `ViewGeometry`, `EnemyCatalog`, the WP0-sim events.
- **Provides:** the director read API (Appendix C), `WaveSpawner.spawn()`, the room contract (Appendix C), `NavBaker.bake_room()`.
- **Director:**
  - Group `"enemy_director"`, `process_physics_priority = -10`; timers on `delta × TimeController.sim_scale()`; seeded RNG (`rng_seed` export).
  - Candidates: group `"ai_enemy"` with `is_director_alive()`.
  - **Slots:** n alive enemies get n angles on a circle around the player, evenly spaced and at least `spread_min_gap_deg` apart, radius between the ring's bounds (per-enemy seeded jitter). Assignment: sort enemies by bearing, rotate the even spacing to minimise total angular travel, then swap pairs to honour `slot_preference()` (blind-side preferences get the angles outside the view, front preferences the angles nearest the look). Reassign at most every `slot_reassign_s` or when the count changes. After the map sync, snap each slot to the navmesh; if the snap moves it more than `slot_max_snap_m`, try ±15° steps. Re-pick a slot when its enemy makes no progress for `slot_stuck_s`.
  - **Tokens:** holders ≤ `attacker_cap` (0 = unlimited). A new grant needs: at least `token_grant_gap_frames` since the last grant; the player hittable (not KO, downed, flying, invulnerable, or grabbed by someone); at least `player_hit_grace_frames` since a hit landed on the player; at least `revive_grace_s` since the player revived. Score = seconds waiting + `blind_spot_priority × token_blind_bonus_s` if `ViewGeometry.is_outside_view(player, enemy, rear_warning_angle_deg)`. Highest wins. Revoke when the holder dies, is gone, reports `REACT`, or the player goes down. Emit `attack_token_changed`.
  - `alive_count()`, `can_spawn()` (alive < `alive_cap`).
- **Crowd room** (`crowd_room.tscn` = a `Node3D` with `crowd_room.gd`; everything built in code like the test room, street axis +X, near side +Z low for the side view):
  - Lane x −15..15, z −6..6. North (−Z): building fronts with two recessed doorways 2 m wide (x −8 and +6). East and west ends: 3 m alley mouths into 4 m stubs. South: the low curb with a 3 m gap into a short alley at x +4. A parked van (4.2 × 1.4 × 1.9 m) at (−9, 0, 4) with a spawn spot behind it. Two crates. All static geometry under a `Geometry` node on `LAYER_WORLD`.
  - Spawn points as an exported array of `{position, yaw, tag}` (`doorway`, `alley`, `vehicle`), each on the navmesh and at least `agent_radius` from walls.
  - Build order in `_ready()`: environment, geometry, `NavBaker.bake_room(geometry)` (synchronous, `STATIC_COLLIDERS`, world mask, `cell_height` 0.1, `agent_radius` 0.5, the roof post-filter; numbers as `@export`s on the baker), the region, the director, the spawner, the player (`auto_revive = true`, `rotation.y` set before `add_child`, a `NavigationObstacle3D` child of radius `player_obstacle_radius_m`), then presentation through `RoomKit.build_presentation(self)` (identical to the test room's; `TuningOverlay` a direct child).
  - Exposes the room contract: `player`, `player_start`, `player_yaw_deg`, `with_presentation`, `waves_enabled`, `rng_seed`, `director`, `spawner`, `spawn_enemy(id, local_offset := Vector3.INF, yaw := NAN) -> Node3D` (a local offset is relative to the player: x right, −z ahead).
- **WaveSpawner** (group `"wave_spawner"`):
  - `waves: Array[PackedStringArray]` export, default: `[punk, punk]`, `[punk, kicker, thug]`, `[punk, punk, kicker, thug]`, `[bruiser, punk, kicker]`, `[punk, kicker, thug, bruiser, punk, kicker]`, `[boss]`, repeating. Ids whose scene doesn't exist yet are skipped (`EnemyCatalog.available()`), so the table is final from day one.
  - One spawn per `wave_spawn_interval_s` while `director.can_spawn()`. Picks spawn points so about `wave_behind_share` of a wave comes from points outside the player's view at spawn time, never nearer than `spawn_min_player_distance_m`, never into an occupied capsule. Sets `entry_target` (the nearest lane navmesh point) and `name` (archetype + counter, for the RNG seed and the combat log) before `add_child`.
  - Emits `enemy_spawned`, `wave_started`, `wave_cleared` (all of a wave's enemies dead: `health <= 0`, not `is_ko()`); waits `wave_rest_s`, then the next wave.
  - `spawn(id, at := Vector3.INF, yaw := NAN, tag := &"") -> Node3D` for F4, the boss's call-in and bots; `set_waves_enabled(on)`.
- **Training room:** append to `test_room.gd`'s `_ready()` one call, `RoomKit.add_ai_support(self)`: a navmesh baked from its static geometry (filter AABB to the street interior on X and Z only; godot-navigation §8), a director, a `WaveSpawner` with waves off, the player obstacle. Add a `spawn_enemy()` that delegates to the spawner. No geometry or existing child order changes; all 537 existing tests stay green.
- **F6:** `RoomKit` handles `switch_room` in both rooms: `TimeController.clear()`, unpause, `change_scene_to_file()` to the other room.
- **Tests** (`test_director.gd` with `stub_ai_enemy.gd` in the test room; `test_crowd_room.gd`; `test_nav_baker.gd`; all seeded and ≤ 900 frames each):
  - **R1:** with 6 stubs and cap 3, never more than 3 holders; cap 0 lets all 6; cap 1 one;
  - **R2:** grants are at least `token_grant_gap_frames` apart;
  - **R9:** one in-view and one out-of-view stub waiting equally: priority 1.0 grants the blind one (≥ 0.9 over 20 trials with seeds); priority 0 grants the longer waiter;
  - no grants while the player is KO, downed, grabbed or in get-up invulnerability, or within the hit and revive graces;
  - spread: after 3 s, 6 stubs' slots are at least `spread_min_gap_deg` apart and no 90° wedge holds more than 2 slots; a blind-preferring stub gets an out-of-view slot;
  - tokens revoked on holder hit, KO, freed;
  - `alive_cap` holds for waves and `spawn()`;
  - the crowd room: loads with no `ERROR`; every spawn point has a navmesh path to the player start; no roof polygons; doorways connected; at least one of the first three waves spawns an enemy outside the player's view; waves repeat; two runs with the same seed give the same positions (hash);
  - F6 switches both ways; the training room still passes every existing test.
- **Captures** (`tests/bot/director_bot.gd` overriding `_room_scene()` to the crowd room, with stub enemies until WP-E merges; free fly and first person):
  - "Director: six from above" (free fly over the player, F3 labels on);
  - "Director: six, first person 360" (god mode, slow turn);
  - "Waves: spawns behind".
  - **Judge:** even spread, no bunching in front, staggered attacks, stubs walking out of doorways and alleys.
- **Acceptance:** tests green; sheets judged; ARCHITECTURE sections.
- **Size:** ~1.0 × WP4 (7-10%).

### WP-W: the rear warning (Phase 1)
- **Goal:** SPEC §8 exactly as §1.2, proven against training dummies in the training room, with no dependency on AI.
- **Worktree / branch:** `.worktrees/m3-warning`, `m3/rear-warning`.
- **Owned files:** `game/ui/rear_warning.gd` (replaces the stub), `game/audio/audio_director.gd` (voice protection, heavy effort), `tools/gen_sfx.gd` and `assets/export/sfx/effort_heavy_*.wav` (+ `.import`), `ASSETS.md` (audio rows), the "Rear warning" group (append only), `tests/test_rear_warning.gd`, `tests/test_rear_warning_audio.gd`, `tests/helpers/heavy_dummy.gd` (a `TrainingDummy` with `heavy = true`), `tests/bot/warning_bot.gd` + `.tscn`, ARCHITECTURE section "Rear warning".
- **Must not touch:** `hud.gd`, `hud.tscn` (pre-wired), `combat_actor.gd`, `ViewGeometry` (request changes instead).
- **Consumes:** `ViewGeometry.warning_corner()`, `MoveData.reach_m`, `attacker.warning_reach_m()` and `attacker.heavy` (duck-typed), `VfxArt.texture(&"rear_warning")`, the events in §1.2.
- **Provides:** `RearWarning.shown`/`cleared` signals and `corner_state(corner) -> {visible, count, heavy, size_px, alpha, brightness, entries}` for tests and the probe; `active_entries()`.
- **Behaviour:** §1.2 rules 1-9, exactly. Details:
  - The player from group `"player"`; missing player or camera: no-op (HUD tests run with no player).
  - Entries keyed by attacker instance id; the side fixed at start (unless `rear_warning_follow_turn`).
  - Draw with `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`; texture loaded in `_ready()`; centre inset `rear_warning_inset_px` from the corner; size clamped to the reserved corner rect (`HudStyle.REAR_CORNER_SHARE`) at any `rear_warning_size`; anchored so wider screens keep it in the corner.
  - Pulse: `rear_warning_pulses` pulses of `rear_warning_pulse_s` (scale bump `rear_warning_pulse_scale`), then steady; re-pulse when a corner's count rises. Brightness raises the modulate toward white-yellow, capped at 1.6 × base.
  - Time: `game_delta × TimeController.sim_scale()`, so it holds on pause and stretches at 0.25×.
  - Red-orange stays the only red-family colour it uses (SPEC §10).
- **Audio:**
  - `_take_voice()` steals the oldest voice that is **not** a wind-up voice still in its attacker's wind-up or attack; only if every voice is one, the oldest of those.
  - Heavy attackers (`heavy == true`) play the effort from a new `effort_heavy` pool (lower, longer) generated in `gen_sfx.gd`; log it in `ASSETS.md` as procedurally generated.
- **Tests:**
  - `test_rear_warning.gd`, on the `test_ui.gd` fakes pattern (a fake player looking along −Z, fake enemies, a bare camera, `advance()` stepped by hand): every §1.2 table row through the real widget; the end on each listed event and **not** on `windup_ended(false)`, nor on another attacker's hit; the poll ends a freed attacker's entry; two on the left → one burst, count 2, brighter; left, right and behind at once → both corners with counts 2 and 2; heavy → larger; size clamped inside the corner at `rear_warning_size` 3.0 on 1920 × 1080 and 2560 × 1080; tunables read live; pause holds; 0.25× stretches; KO hides; the widget writes no game state (`test_vfx.gd:891` pattern).
  - **Integration** (training room with presentation, real `TrainingDummy`, god mode): a dummy posted at 0.9 m at 135° left, 135° right and 180°, `start_jab()`: the right corner(s) from the wind-up's first frame until the frame the jab lands; measured warning time equals the scaled startup (24 frames, ±1); blocked → ends on the block; hit out of the wind-up → ends; `heavy_dummy` → larger.
  - **`test_warning_sweep_every_5_degrees`:** for each bearing −180..175 in 5° steps, re-post one dummy at 1.0 m, `start_jab()`, step one HUD frame, compare `corner_state()` against a hand-written expectation in the test, `abort_move()`. 72 of 72 agree.
  - `test_rear_warning_audio.gd`: under a saturated 32-voice pool a wind-up voice survives until its strike; a heavy attacker's effort comes from `effort_heavy`.
- **Captures** (`tests/bot/warning_bot.gd` extends `combo_bot.gd`, training room, god mode, help and combat log hidden, short titles so the caption clears the top-right corner; run with `--corners`): "Warn: behind-left", "Warn: behind-right", "Warn: directly behind", "Warn: edge of behind" (161° and 159°), "Warn: in view" (50° and 0°), "Warn: out of range", "Warn: two on the left", "Warn: left, right and behind", "Warn: heavy", "Warn: blocked ends it", "Warn: hit out of the wind-up ends it", "Warn: sweep" (every 15°). The bot logs `WARN-CHECK ok|FAIL bearing=… expected=… shown=… f=…` at each wind-up from the widget's `shown` signal and a hand-written expectation.
  - **Judge:** the burst is readable at 1280 × 720 without being loud; sits in the corner; heavy is clearly larger; two-on-a-side is clearly brighter; nothing flickers at the end.
- **Acceptance:** all tests green; every `WARN-CHECK` ok; corner sheets judged.
- **Size:** ~0.7 × WP4 (5-7%).

### WP-G: enemy grabs on the player, and magnetism in a crowd (Phase 1)
- **Goal:** Game-boy's grab rule end to end with a reusable holder component; the player's held view readable in first person; plus two crowd fixes to magnetism.
- **Worktree / branch:** `.worktrees/m3-grabs`, `m3/enemy-grabs`.
- **Owned files:** `game/player/player.gd` (a new "Held by an enemy" section, the `_on_grabbed`, `_held_anim` and `_pin_spot` overrides, the GRABBED arm, the `_process` look gate, the magnetism changes), `game/enemies/grab/enemy_grab_holder.gd` (`class_name EnemyGrabHolder`), `game/actors/poses/grab_poses.gd`, `game/ui/grab_prompt.gd` (replaces the stub), Appendix A subgroup "Grabs on the player" and the Magnetism entry `magnet_skip_invulnerable`, `tests/test_enemy_grab.gd`, `tests/test_magnetism_crowd.gd`, `tests/helpers/stub_grabber.gd`, `tests/bot/grab_bot.gd` + `.tscn`, ARCHITECTURE section "Enemy grabs".
- **Must not touch:** `combat_actor.gd`, `first_person_camera.gd` (express the held view through the player's existing camera getters), enemy archetype files.
- **Consumes:** the WP0-sim hooks (`_on_grabbed`, `_held_anim`, `_keeps_strike_pose`, `break_free`, the pin safety net), `CombatEvents.grab_escaped`.
- **Provides:** `EnemyGrabHolder` (Appendix C) for WP-B and WP-X; `PlayerCharacter.grab_break_progress() -> float`; the named anims `hold_collar`, `held_collar`, `held_lift`.
- **Holder component** (`RefCounted`, owned by an enemy; driven from its `_tick_control()`):
  - `try_connect(victim)` at the grab move's strike frame: true when `victim.can_be_grabbed()`, within `grab_connect_range_m` and `grab_connect_half_angle_deg` of the owner's facing; then `victim.start_grabbed(owner)`, the owner enters `GRABBING`, plays `hold_collar`, and `_keeps_strike_pose()` is true while holding. False: the move plays out as a whiff (emit `attack_whiffed` so the log and audio hear it).
  - `tick() -> int`: `HOLDING`, `ESCAPED` (the victim broke free), `TIME_UP` (after `grab_hold_s`), `LOST` (the victim is no longer held by the owner: KO, reset, revived). Validity checked every tick (the player-side `_holding_valid()` pattern).
  - `_on_hold_broken(victim)` on the owner: if `grab_break_holder_stagger`, the owner staggers (a punish window).
  - `land_final_hit(move, reaction, knockback)`: **release first** (`release_from_grab`), then a code-applied `HitInfo` (the `PC._throw_held()` template: `receive_hit`, `TimeController.hitstop`, `hit_landed`). A KNOCKDOWN, STAGGER or THROWN reaction then works normally.
  - The owner releases on its own `_on_hit_received()` (a flying body can hit a Bruiser holding the player).
- **Player side** (`player.gd`):
  - A `GRABBED` arm `_control_grabbed()`: drain P and K presses from the parser into a mash count that decays at `grab_break_decay_per_s`; at `grab_break_presses`, `break_free(away_from_holder × grab_break_push_mps)` and `grab_break_invuln_frames` of invulnerability. Safety net: release if the holder isn't holding.
  - `_on_grabbed(by)`: reset `_cam_offset`, the chain, the buffer, `_held_attack`, `_air_attack`, `_turn_frames`, `_quick_turn_frames` and the mash count; turn the look toward the holder over `grabbed_turn_frames` (`_turn_left`/`_turn_frames`); raise `process_physics_priority` above the enemies' so the pin reads the holder's current pose (restore on release).
  - Look lock: no mouse or stick look while `GRABBED` (extend the `_process` gate).
  - `_held_anim()` → `held_collar` (upright, hands on the holder's wrists, **no hips nudge**, so release doesn't move the origin under the lens). `_pin_spot()` → `grab_held_pin_m × holder rig scale` in front of the holder, on the floor. The held view pitches by `grab_held_view_pitch_deg` (eased) through `get_camera_move_offset()`.
  - `grab_break_progress()`.
  - **Magnetism:** with `magnet_skip_invulnerable` on, `_find_magnet_target()` skips invulnerable bodies (getting up). `_stop_distance()` adds `target.body_radius − body_radius` (the player's own radius as the reference, so no new literal), so a lunge at a Bruiser or the boss stops outside its capsule. Keep `test_ko_blink.gd`'s pins.
- **`GrabPrompt`:** while the player is GRABBED by a team-1 holder: "MASH P / K" under the centre with progress pips from `grab_break_progress()`; HUD colours (not red); game time; no-op without a player.
- **Poses** (`grab_poses.gd`): `hold_collar` (holder upright, both fists at the victim's collar at HoldPoint distance), `held_collar` (loop; a struggle sway), `held_lift` (the victim raised for the boss's slam wind-up: `HIPS_POS` up).
- **Tests** (`test_enemy_grab.gd`, with `stub_grabber.gd`, a `CombatActor` that winds up a test-made grab move, uses the component and lands a 15-damage KNOCKDOWN at `TIME_UP`):
  - N presses (`push_press(&"P", 1)` × N, decay 0) break free before the hit; N − 1 doesn't and the hit lands;
  - a dodge through the wind-up, or a jump, is never grabbed; a blocking player is grabbed;
  - the look faces the holder and doesn't turn with mouse input while held; no stale kick camera offset after a grab during a kick's recovery;
  - the holder hit by a flying enemy body releases the player; a KO'd holder releases;
  - the final hit leaves the player DOWNED (or staggered), not still GRABBED; its damage is 15;
  - first person while held (`fp_view.gd`): the grabber's head and hands stay at least 0.25 m from the lens, the player's own body covers at most a third of the view; the eye moves less than 0.05 m on the release tick;
  - the prompt shows only while held by an enemy; progress rises and decays;
  - `test_magnetism_crowd.gd`: a getting-up enemy dead centre is skipped for a hittable one; a 0.55 m-radius target's lunge stops outside its capsule.
- **Captures** (`tests/bot/grab_bot.gd`, training room, `stub_grabber`): "Grab: wind-up from the front", "Grab: held view", "Grab: mash free", "Grab: unbroken hit", "Grab: dodge the wind-up". **Judge:** the grabber reads as holding you; nothing fills the lens; the prompt is readable; the release doesn't pop; the unbroken hit reads.
- **Acceptance:** tests green; sheets judged.
- **Size:** ~1.0 × WP4 (7-10%).

### WP-I: instruments: F3 AI overlay, F4 spawn any, crowd bot, readability probe, autopilot (Phase 1)
- **Goal:** everything needed to *see* and *measure* the crowd: the debugging views SPEC §11 asks for and the bot side of §1.3 and §1.4.
- **Worktree / branch:** `.worktrees/m3-instruments`, `m3/instruments`.
- **Owned files:** `game/ui/debug_draw.gd` (an AI layer), `game/ui/cheat_menu.gd`, `tests/test_ai_debug_draw.gd`, `tests/test_cheat_spawn.gd`, `tests/test_readability_probe.gd`, `tests/bot/crowd_bot.gd` + `.tscn`, `tests/bot/readability_probe.gd`, `tests/bot/autopilot.gd`, ARCHITECTURE sections on F3 and F4.
- **Must not touch:** hud files, the director, enemy files.
- **Consumes (duck-typed):** the director read API (group `"enemy_director"`), the AI-enemy contract (group `"ai_enemy"`), `debug_nav_path()`, `EnemyCatalog`, the room contract and `WaveSpawner.spawn()` (group `"wave_spawner"`), `RearWarning.corner_state()`, `ViewGeometry`.
- **F3 AI layer** (drawn only when a director or an `"ai_enemy"` exists, so `test_ui.gd`'s exact line counts hold; new distinct `@export` colours): each token holder, a ring at its feet and a line from its chest to the player's chest; each posturing enemy, a small circle at its slot and a dim line to it; the posture ring (two circles at the ring's bounds); the view boundary at `rear_warning_angle_deg` and the ±`rear_warning_behind_deg` behind sector, as floor lines from the player; each enemy's nav path as a polyline. The AI state text comes from `debug_state_text()` (WP-E); labels stack as today.
- **F4:** an `OptionButton` of `EnemyCatalog.available()` and a "Spawn at crosshair" button (`spawn_point()` generalised with a body size per scene, cached per scene path; spawns through the room's spawner when one exists, else instantiates; names "Punk 3" and so on); "Remove all enemies" (groups left before `queue_free()`); "AI frozen" (the Debug `ai_frozen`); "Waves on / off" (the spawner). `spawn_dummy()`, `reset_dummies()`, `remove_spawned_dummies()` and every widget the existing tests read stay.
- **Readability probe** (`tests/bot/readability_probe.gd`, a `Node` a bot adds): subscribes to `CombatEvents` and the widget's signals; computes R1-R14 (§1.3) per physics frame, the lens metrics every 10th frame (`FPView.hits()` from `player.get_eye_transform()` and `get_look_basis()`; occlusion by a ray from the lens to each in-view attacker's chest against other enemies' meshes); the **warning oracle**: at each `windup_started`, the expected corner from `ViewGeometry.warning_corner()` and positions, compared with `corner_state()` on the next HUD frame; `start_act(title)` / `end_act()`; writes `readability.json` (per act and total) and prints the summary. R15 (frame times) is sampled with `Time.get_ticks_usec()` deltas.
- **Autopilot** (`tests/bot/autopilot.gd`, drives `player.input` scripted): turns to the nearest in-view wind-up; blocks (B held) when an in-view wind-up's strike is ≤ 6 frames away within reach; sidesteps heavy wind-ups; quick-turns when the warning shows both corners; otherwise targets the enemy nearest the centre within 2.5 m and chains P P P P or K K K; mashes when grabbed. Skill knobs are bot exports (bot thresholds, not game tunables).
- **`crowd_bot.gd`** (extends `combo_bot.gd`; `_room_scene()` returns the crowd room when it exists, else the training room; enemies spawned through `spawn_enemy()`; waves off unless the act turns them on; probe on): "Crowd: observe 360", "Crowd: autopilot", "Crowd: passive", "Crowd: blind spot", "Crowd: director view" (free fly, F3), "Crowd: waves". An `--mix=<ids>` user arg picks the six (default `punk,punk,kicker,thug,bruiser,punk`, falling back to available ids).
- **Tests:** F3 draws the new colours only with a stub director, and today's counts without one; token rings follow `attack_token_changed`; F4 spawns every available archetype (`stub` ids in this worktree), refuses with "No room", removes all, toggles AI and waves; the probe's metrics on scripted fixtures (6 stubs placed by hand give known `front_wedge_crowding` and `ring_adherence`; two forced wind-ups 5 frames apart give `min_windup_start_gap_frames` 5; a mismatched fake widget gives oracle agreement < 100%).
- **Captures:** in this worktree only stubs exist, so record "Crowd: director view" and "Crowd: observe 360" with stubs to prove the pipeline; the real evidence is Phase 3's.
- **Acceptance:** tests green; the crowd bot runs every act to `quit()` without errors; the JSON is written.
- **Size:** ~0.9 × WP4 (6-9%).

### Phase 1 merge and Phase 1R (lead, then one reviewer and at most one fixer)
1. Merge WP-E, WP-D, WP-W, WP-G and WP-I into `m3/enemy-ai`; land any `contract_requests` the lead accepts; regenerate `default.json`; full suite; push; HANDOFF.
2. Temporarily (not committed) switch the main scene, or run `crowd_bot` with `--mix=punk,punk,punk,punk,punk,punk`: record "Crowd: observe 360", "Crowd: blind spot" and "Crowd: autopilot" with **six real Punks, the real director and navmesh**, and read `readability.json`.
3. **Phase 1R review:** one Opus reviewer, lenses L1 and L2 only, on those captures and metrics (detached worktree `.worktrees/m3-review-1r`). Findings go through the usual skeptics; survivors become **one** Sonnet fix package (`.worktrees/m3-fix-1r`, branch `m3/fix-1r`) owning the files they touch (typically `enemy_director.gd`, `enemy_actor.gd`, `rear_warning.gd`). Merge, full suite, HANDOFF.
4. Re-measure the Phase 1 costs and update HANDOFF's cost table.

---

### WP-K: the Kicker (Phase 2)
- **Goal:** the fast flanker: actively circles to the blind side; jump kick and low sweep (8 each).
- **Worktree / branch:** `.worktrees/m3-kicker`, `m3/kicker`.
- **Owned files:** `game/enemies/kicker/kicker.gd` + `.tscn`, `game/actors/poses/enemy_poses_kicker.gd`, `_kicker_moves()` in `gen_moves.gd`, `game/combat/moves/kicker_*.tres`, subgroup "Kicker", `tests/test_enemy_kicker.gd`, `tests/bot/kicker_bot.gd` + `.tscn`, ARCHITECTURE "Kicker" paragraph.
- **Behaviour:** `extends EnemyActor`; `slot_preference()` +1; `_posture_tick()`: when its position is inside the player's view (`ViewGeometry`), orbit toward the nearer blind bearing at `strafe_speed_mps × kicker_circle_speed_mult`; else posture as usual. `_choose_attack()`: sweep with `kicker_sweep_chance`, else jump kick. The jump kick lunges `kicker_jump_lunge_m` over the last 6 startup frames plus the active frames (`set_lunge()` from `_on_attack_frame()`). Health `kicker_health`, speed `kicker_speed_mult`. Proposed colours: violet tracksuit (0.5, 0.25, 0.8) with a lime accent.
- **Poses:** `kicker_jump_kick` (crouch with arms back as the held wind-up; strike a front-kick leg with `HIPS_POS` raised 0.3-0.4 m so the body leaves the ground; landing crouch follow); `kicker_sweep` (crouched turn, the right leg out low, `HIPS_POS` set explicitly: codemap G9); `taunt_kicker` (a bounce on the toes, fists down).
- **Tests:** with the director and the player still, the Kicker's slot is outside the view ≥ 80% of posture time; when the player turns to face it, it is out of view again within 2 s; the jump kick's travel; the sweep hits the legs and knocks down (damage 8 ≤ 15); `reach_m` measured (the jump kick's includes its lunge); lens telegraph tests at 1 m and 3 m; joint limits.
- **Captures:** "Kicker: circles to the blind side" (first person: the player turns toward it repeatedly; the warning fires when it attacks from behind), "Kicker: jump kick tell", "Kicker: sweep tell". **Judge:** the flanking reads as deliberate; the sweep crouch is distinct from every other wind-up.
- **Size:** ~0.6 × WP4 (4-6%).

### WP-T: the Pipe Thug and the dropped pipe (Phase 2)
- **Goal:** the weapon carrier: three-swing pipe combo (10 each); drops the pipe on knockdown for the player to take.
- **Worktree / branch:** `.worktrees/m3-thug`, `m3/pipe-thug`.
- **Owned files:** `game/enemies/thug/pipe_thug.gd` + `.tscn`, `game/actors/poses/enemy_poses_thug.gd`, `_thug_moves()`, `game/combat/moves/thug_*.tres`, `game/weapons/weapon.gd` (`drop()` only), subgroup "Pipe Thug", `tests/test_enemy_thug.gd`, `tests/bot/thug_bot.gd` + `.tscn`, ARCHITECTURE "Pipe Thug" and the `Weapon.drop()` interface.
- **Behaviour:** spawns holding a pipe (`Weapon.attach_to(self)`); `slot_preference()` −0.3; `_choose_attack()` → `thug_pipe_1`, chain to `_2` and `_3` only while the previous swing landed or was blocked, each with its own wind-up. On any `KNOCKDOWN`, `LAUNCH` or `THROWN` reaction, or a KO: `weapon.drop(velocity)` (up `pipe_drop_up_mps`, out `pipe_drop_out_mps` along the hit) and emit `weapon_dropped`. Unarmed afterwards: its attacks are `punk_jab` → `punk_cross` (reusing the Punk's MoveData). Health `thug_health`. Proposed colours: brown leather (0.45, 0.3, 0.18) with grey; the pipe is its silhouette.
- **`Weapon.drop(velocity: Vector3)`:** reparent to the world at the grip's transform, unfreeze, ground physics (pickup layer, group `"weapon"`, available to the player's LB), full durability kept.
- **Poses:** `thug_pipe_1..3` reuse `_pipe_swing_1..3(wg)` strikes and follow-throughs with new held wind-ups (pipe cocked back and high, upper-arm ≤ 140°); `taunt_thug` (pipe tapped in the palm).
- **Tests:** drops on knockdown and KO, not on a flinch or stagger; the dropped pipe lies on the floor and the player picks it up and swings it; existing weapon tests green; the chain stops on a whiff; damage 10 each, swing 3 STAGGER (§10 judgement call); guard drain from `guard_damage_mult`; reach and telegraphs; joint limits.
- **Captures:** "Thug: three-swing tells", "Thug: knocked down, drops the pipe", "Thug: the player takes the pipe". **Judge:** the pipe reads in the wind-up; the drop is visible; the pickup works in first person.
- **Size:** ~0.7 × WP4 (5-7%).

### WP-B: the Bruiser (Phase 2)
- **Goal:** the armored heavy: ignores light hits, staggers on heavy hits and the haymaker; grab and headbutt, overhead smash (15).
- **Worktree / branch:** `.worktrees/m3-bruiser`, `m3/bruiser`.
- **Owned files:** `game/enemies/bruiser/bruiser.gd` + `.tscn`, `game/actors/poses/enemy_poses_bruiser.gd`, `_bruiser_moves()`, `game/combat/moves/bruiser_*.tres`, subgroup "Bruiser", **armor presentation**: `game/fx/vfx_director.gd` (an absorbed-hit branch only), `game/ui/combat_log_overlay.gd` (an "ARMOR" tag), `game/audio/audio_director.gd` and `tools/gen_sfx.gd` (a `clank` pool, routing absorbed hits to it), `assets/export/sfx/clank_*.wav`, `ASSETS.md` rows, `tests/test_enemy_bruiser.gd`, `tests/bot/bruiser_bot.gd` + `.tscn`, ARCHITECTURE "Bruiser" and "Armor".
- **Behaviour:** `extends EnemyActor`; `armor_mode = ALWAYS_LIGHT`; `heavy = true`; `body_height = bruiser_height_m`, `body_radius = bruiser_radius_m` (set before `super._ready()`); `slot_preference()` −0.5; `_choose_attack()`: grab with `bruiser_grab_chance`, else smash. Grab: `bruiser_grab` wind-up, `EnemyGrabHolder.try_connect()` at the strike frame; `HOLD` until `TIME_UP` → `bruiser_headbutt` (no wind-up state needed: the hold is the telegraph) and `land_final_hit()`; `ESCAPED` → the component staggers it. A parry staggers it (`react_to_block` has no armor check; §10 judgement call). Proposed colours: olive (0.35, 0.42, 0.2) with tan.
- **Strike heights:** author strikes for a 2.05 m rig hitting a 1.8 m player (codemap rig §11: aim down, or target the torso).
- **Armor presentation:** an absorbed hit (`hit.armor_absorbed`) shows a small grey-white spark instead of the tier burst and no lettering, plays `clank` with the thud, and the combat log line ends with "ARMOR". The flash still shows. `brace`: a tiny stiffening pose, played on absorb.
- **Tests:** jabs absorbed (damage taken, no flinch, `armor_absorbed`), heavy hits stagger, the haymaker and finishers keep their reaction; a light hit never interrupts its wind-up, a heavy hit does (and cancels a grab wind-up); the grab misses a dodging or jumping player; mash-out staggers it; the headbutt lands for 15 and knocks down; smash 15, unblockable no, recoil 0; reach at 2.05 m; telegraphs from the lens; joint limits; the warning burst for it is larger (integration).
- **Captures:** "Bruiser: armor reads" (P P P P on it), "Bruiser: haymaker staggers it", "Bruiser: grab, mash free", "Bruiser: grab, unbroken", "Bruiser: smash tell", "Bruiser: warning from behind". **Judge:** absorbed hits clearly register; arms-wide grab wind-up unmistakable; the larger burst.
- **Size:** ~0.8 × WP4 (6-8%).

### WP-X: the boss (Phase 2)
- **Goal:** the graybox boss (placeholder name "The Foreman"): 300 HP, two phases, shoulder charge, grab slam, ground pound (15-25); at 50% it turns faster and calls two Street Punks.
- **Worktree / branch:** `.worktrees/m3-boss`, `m3/boss`.
- **Owned files:** `game/enemies/boss/boss.gd` + `.tscn`, `game/actors/poses/enemy_poses_boss.gd`, `_boss_moves()`, `game/combat/moves/boss_*.tres`, subgroup "Boss", `tests/test_enemy_boss.gd`, `tests/bot/boss_bot.gd` + `.tscn`, ARCHITECTURE "Boss".
- **Behaviour:** `extends EnemyActor`; group `"boss"` (the HUD shows its bar); `armor_mode = WINDUP_LIGHT`; `heavy = true`; `body_height = boss_height_m`, `body_radius = boss_radius_m`; `slot_preference()` 0. Attacks: `boss_charge` (a long active window; `set_lunge()` over the active frames for `boss_charge_distance_m`; stops at walls; `warning_reach_m()` adds the charge distance), `boss_grab` → `HOLD` with `held_lift` on the victim near the end → `boss_slam` via `land_final_hit()` (THROWN downward-forward; every launch lifts at least `min_launch_up`, accepted), `boss_pound` (unblockable ring arc). Choice weights by `boss_pound_chance` and `boss_grab_chance`; the charge only when the player is beyond grab reach and the lane between them is clear (a ray against world geometry).
- **Phase 2** at `health ≤ boss_phase2_ratio × max_health`, once: emit `boss_phase_changed(self, 2)`; play `summon` with the heavy effort; turn rate × `boss_phase2_turn_mult`, speeds × `boss_phase2_speed_mult`; call `boss_adds` Punks through the room's spawner (`spawn(&"punk")` at spawn points; if the alive cap is full, they come as room frees). No spawner (bare tests): instantiate beside the boss.
- Proposed colours: near-black (0.12, 0.12, 0.14) with gold.
- **Tests:** phase 2 fires exactly once at 150 HP; two Punks spawn and the alive cap holds; turn rate measurably faster after; each attack's damage 15-25 (the boss is exempt from the 15 rule); the pound hits a blocking player; the charge stops at a wall; the grab slam with mash-out and unbroken; the boss bar shows and hides; boss KO clears its wave; telegraphs from the lens at the boss's scale.
- **Captures:** "Boss: charge tell", "Boss: pound tell", "Boss: grab slam, mash free", "Boss: grab slam, unbroken", "Boss: phase 2 call-in", "Boss: bar". **Judge:** each tell readable at the boss's height from 2-4 m; the phase change is noticed; the adds walk in.
- **Size:** ~1.2 × WP4 (8-12%).

---

### Phase 3: integration and the evidence pack (lead)
1. Merge WP-K, WP-T, WP-B and WP-X; land accepted `contract_requests`; regenerate `default.json`; full suite; push.
2. `project.godot`: `run/main_scene` → `res://game/level/crowd_room.tscn`. README "Play it" points at the crowd room, F6 and H.
3. Record the §1.4 evidence pack with `tools/capture_bot.sh`, one recording at a time: `warning_bot` (all acts, `--corners`), `crowd_bot` (all acts, default mix and the boss wave), every archetype bot's tell acts, `grab_bot`. Look at every sheet; read every `readability.json`.
4. Fill a table of R1-R15 results into HANDOFF. Any red hard metric is fixed before Phase 4 (lead-written fix brief, one Sonnet fixer). Soft misses go to Phase 4 as lead-written findings.
5. Smoke-test a release export (Phase 5 step 4) now, so packaging problems surface early.
6. HANDOFF at the phase boundary.

### Phase 4: adversarial review rounds
- Copy `docs/reviews/M2-phase3/workflow*.js` to `docs/reviews/M3/` and change: `MILESTONE='m3'`, `BASE_BRANCH='m3/enemy-ai'`, `NOTES_BRANCH='m3/review'`, `REVIEWS='docs/reviews/M3'`, worktree prefixes `m3-review-` and `m3-fix-`, branch prefix `m3/fix-`, the fix commit subject `"M3: review fixes (<key>"` (the loader matches it), `COST` constants divided by 5, the test time (~2 minutes), and `COMMON` rewritten (Game-boy's M3 answers and defaults; no open questions: take defaults and log them; §1.2 and §1.3 of this plan as the acceptance contract). Save the launch args as `args-*.json`.
- **Round 1:** lenses L1-L6 (§1.5), Opus reviewers in detached worktrees, each with its bot acts and the §1.3 table; three Sonnet skeptics per finding (reproduce / spec / code), a finding survives with two; a completeness critic; partition into at most 4 fix packages with disjoint files (the §4 rules apply: one owner per file per round); Sonnet fixers who add a failing test first, re-record the affected acts and judge them.
- **Later rounds** with `workflow-r2-close.js` from lead-written briefs, until no high or medium finding survives, at most three rounds. Each round's merged result re-runs the evidence pack's affected acts.
- Every launch is gated by usage; at most about 6 heavy agents while under 60%, 2 above; Godot-bound agents at most 2 at once.

### Phase 5: docs, PR, export, release, Slack (lead)
1. **README:** "Milestone 3 status"; controls (F4 spawn any enemy, F6 room switch, mashing P/K when grabbed, H); **"Where M3 departs from the spec"**, one entry per default or departure (each marked "default taken, Game-boy to confirm"): one telegraph per enemy hit with wind-up floors that `windup_mult` can't cross; token pacing (grant gap, hit grace, revive grace) on top of the attacker cap; the Thug's third swing staggers; the damage rule read per knockdown hit; enemies get up on the shared timers; the Kicker re-circles outside the director's slots; parries stagger the Bruiser and boss; breaking a grab staggers the grabber; the warning's side fixed at the wind-up start; warnings hidden in the KO view; `rear_warning_audio` gates all wind-up audio; magnetism skips getting-up bodies; the boss slam is a throw; KO'd enemies blink off (M2) and are freed; the crowd room's wave cycle ends with the boss.
2. **ARCHITECTURE:** retitle to cover M3; confirm every package's section against the code; update "Ownership".
3. **`M3-judgement-calls.md`** complete (it feeds the Slack digest).
4. **Export:** `godot --headless --export-release "macOS" "builds/macos/Beat-em-Up PoC.zip"` (templates 4.7.2 are installed). Smoke test: unzip into the scratchpad, launch the app with `--quit-after 900` and a log file; check the log for `ERROR`; check the crowd room loads, enemies path and the warning shows (one short windowed run). `builds/` is not committed.
5. **PR** `m3/enemy-ai` → `main`: summary, the R-table results, the evidence list, the departures and defaults, test count; ends with the Claude Code line. **Never merge it.**
6. **Release:** `gh release create m3-playtest-1 "builds/macos/Beat-em-Up PoC.zip" --repo mikedtcm22/beat-em-up-PoC --target m3/enemy-ai --prerelease --title "Milestone 3 playtest" --notes <how to open: right-click → Open on first launch; controls; F6>`.
7. **Slack DM** to Michael (`U0AQMKKBL93`, Arachne Finance): a quick ping with (1) the release link, (2) the digest of key judgement calls, each with at least one alternative not taken and why (from `M3-judgement-calls.md`).
8. HANDOFF: M3 waiting on Game-boy's sign-off.

---

## Appendix A: tunables (all declared by WP0-sim)

Format: `name` (type, range, default): meaning. Every one gets a `##` doc comment in `tuning_data.gd`. "Owner" may append more to its own block only.

**Group "Enemies"** (the existing three first, no subgroup):
- `attacker_cap` (int, 0-6, 3), `blind_spot_priority` (0-1, 1.0), `windup_mult` (0.25-3, 1.0) — existing.
- `windup_respect_floors` (bool, true): `windup_mult` never scales a move below its `windup_floor`.

Subgroup **"Director"** (owner WP-D):
- `alive_cap` (int, 1-12, 6): at most this many AI enemies alive (SPEC §7).
- `token_grant_gap_frames` (int, 0-60, 12): least sim frames between two grants; staggers wind-up starts.
- `token_cooldown_s` (0-6, 1.2): an enemy that just attacked waits this long before wanting a token.
- `token_hold_max_s` (1-10, 4): a holder that hasn't started its attack by then gives it back.
- `token_blind_bonus_s` (0-10, 3): an out-of-view enemy counts as having waited this much longer, times `blind_spot_priority`.
- `player_hit_grace_frames` (int, 0-60, 10): no new grant this soon after a hit lands on the player.
- `revive_grace_s` (0-5, 1.5): no grant this soon after the player revives.
- `spread_min_gap_deg` (10-120, 40): least angle between two posture slots.
- `slot_reassign_s` (0.25-5, 1.5): slots are rebalanced at most this often.
- `slot_max_snap_m` (0.1-2, 0.6): a slot whose navmesh snap moves it further is rejected.
- `slot_stuck_s` (0.5-5, 2): no progress toward a slot for this long re-picks it.

Subgroup **"Posture"** (owner WP-E):
- `posture_ring_min_m` (1.5-6, 2.5), `posture_ring_max_m` (2-8, 4.0) (SPEC §7).
- `approach_speed_mps` (0.5-6, 2.6), `strafe_speed_mps` (0.2-4, 1.3), `retreat_speed_mps` (0.5-5, 2.2), `step_in_speed_mps` (0.5-6, 3.0).
- `strafe_switch_min_s` (0.3-5, 1.0), `strafe_switch_max_s` (0.5-8, 2.6).
- `taunt_chance_per_s` (0-1, 0.08), `taunt_cooldown_s` (0-15, 5).
- `commit_pause_frames` (int, 0-40, 8): a token holder squares up this long before stepping in.
- `windup_track_share` (0-1, 0.5): the share of a wind-up during which the attacker still turns toward the player.
- `reach_slack_m` (0-0.5, 0.1): the attacker steps in to its move's reach minus this.
- `enemy_turn_rate` (1-20 rad/s, 7).

Subgroup **"Navigation"** (owner WP-E; `player_obstacle_radius_m` read by WP-D):
- `nav_agent_radius_m` (0.2-1, 0.45), `nav_neighbor_m` (1-20, 6), `nav_horizon_s` (0.1-3, 0.75), `nav_waypoint_reach_m` (0.2-1.5, 0.5), `nav_slot_reach_m` (0.1-1, 0.3), `nav_retarget_frames` (int, 1-30, 6), `nav_max_speed_mps` (1-15, 8), `player_obstacle_radius_m` (0.2-1.5, 0.5).

Subgroup **"Street Punk"** (WP-E): `punk_health` (5-200, 30), `punk_speed_mult` (0.5-2, 1.0), `punk_shove_chance` (0-1, 0.3).

Subgroup **"Kicker"** (WP-K): `kicker_health` (5-200, 25), `kicker_speed_mult` (0.5-2.5, 1.35), `kicker_circle_speed_mult` (0.5-3, 1.5), `kicker_sweep_chance` (0-1, 0.4), `kicker_jump_lunge_m` (0-3, 1.4).

Subgroup **"Pipe Thug"** (WP-T): `thug_health` (5-200, 35), `thug_speed_mult` (0.5-2, 0.9), `pipe_drop_up_mps` (0-6, 2.5), `pipe_drop_out_mps` (0-6, 1.5).

Subgroup **"Bruiser"** (WP-B): `bruiser_health` (10-400, 80), `bruiser_height_m` (1.8-2.6, 2.05), `bruiser_radius_m` (0.3-0.8, 0.45), `bruiser_speed_mult` (0.3-1.5, 0.8), `bruiser_grab_chance` (0-1, 0.4).

Subgroup **"Boss"** (WP-X): `boss_health` (50-1000, 300), `boss_height_m` (1.8-3, 2.3), `boss_radius_m` (0.3-1, 0.55), `boss_speed_mult` (0.3-2, 0.9), `boss_phase2_ratio` (0-1, 0.5), `boss_phase2_turn_mult` (1-3, 1.6), `boss_phase2_speed_mult` (1-2, 1.25), `boss_adds` (int, 0-4, 2), `boss_charge_distance_m` (0-12, 6), `boss_pound_chance` (0-1, 0.3), `boss_grab_chance` (0-1, 0.3).

Subgroup **"Grabs on the player"** (WP-G): `grab_hold_s` (0.5-4, 1.5): held this long before the hit (the mash window); `grab_break_presses` (int, 1-40, 8); `grab_break_decay_per_s` (0-10, 2); `grab_break_invuln_frames` (int, 0-60, 20); `grab_break_push_mps` (0-8, 3); `grab_break_holder_stagger` (bool, true); `grabbed_turn_frames` (int, 1-30, 8); `grab_held_pin_m` (0.4-1.5, 0.75); `grab_held_view_pitch_deg` (−20-30, 6); `grab_connect_range_m` (0.5-2.5, 1.4); `grab_connect_half_angle_deg` (10-90, 50).

Subgroup **"Waves"** (WP-D): `wave_spawn_interval_s` (0.1-3, 0.6), `wave_rest_s` (0-15, 3), `wave_behind_share` (0-1, 0.34), `spawn_min_player_distance_m` (1-15, 5).

**Group "Rear warning"** (owner WP-W; the four existing first): `rear_warning_angle_deg` (20-120, 55), `rear_warning_size` (0.25-3, 1.0), `rear_warning_opacity` (0-1, 0.9), `rear_warning_audio` (bool, true); new: `rear_warning_behind_deg` (0-60, 20), `rear_warning_range_margin_m` (0-5, 1.0), `rear_warning_base_px` (40-400, 170), `rear_warning_inset_px` (0-200, 40), `rear_warning_heavy_scale` (1-3, 1.4), `rear_warning_pulses` (int, 0-6, 2), `rear_warning_pulse_s` (0.05-1, 0.14), `rear_warning_pulse_scale` (0-1, 0.25), `rear_warning_brightness_step` (0-1, 0.35), `rear_warning_follow_turn` (bool, false), `rear_warning_hide_in_ko` (bool, true).

**Group "Magnetism"** (owner WP-G): `magnet_skip_invulnerable` (bool, true).

**Group "Debug"** (presets skip it): `ai_frozen` (bool, false).

`test_tuning_panel.gd:390` expects the "Enemies" headings `["Director", "Posture", "Navigation", "Street Punk", "Kicker", "Pipe Thug", "Bruiser", "Boss", "Grabs on the player", "Waves"]`. All new groups stay before "Audio" (`test_audio.gd:175`). No name starts with `vfx_` (`test_vfx.gd:1049`).

## Appendix B: enemy moves (starting values; each owner adds them in its own generator stub)

Frames are startup/active/recovery at 60 Hz. All: `magnetism = false`, camera fields 0, `windup_floor` as listed, `reach_m` **measured** by the owner's test (the value here is a first guess).

| Id | Owner | Frames | Dmg | Tier | Reaction | Hitbox | Floor | Reach | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `punk_jab` | WP-E | 22/3/14 | 6 | LIGHT | FLINCH | RightFist r0.14 | 18 | 1.05 | recoil 16 |
| `punk_cross` | WP-E | 18/3/16 | 6 | LIGHT | FLINCH | LeftFist r0.14 | 18 | 1.0 | only after a landed or blocked jab |
| `punk_shove` | WP-E | 20/3/18 | 6 | HEAVY | STAGGER | both fists r0.16 | 18 | 0.95 | knockback pushes the player ~1.5 m |
| `kicker_jump_kick` | WP-K | 22/6/18 | 8 | HEAVY | KNOCKDOWN | RightFoot r0.2 | 18 | 2.4 | lunge 1.4 m at the end of startup and active |
| `kicker_sweep` | WP-K | 20/5/22 | 8 | HEAVY | KNOCKDOWN | arc r1.3, ±80°, y 0-0.5 | 18 | 1.2 | hits the legs |
| `thug_pipe_1` | WP-T | 22/3/14 | 10 | LIGHT | FLINCH | WeaponTip r0.2 | 18 | 1.5 | guard mult 1.5 |
| `thug_pipe_2` | WP-T | 18/3/14 | 10 | LIGHT | FLINCH | WeaponTip r0.2 | 18 | 1.5 | only after a landed or blocked swing |
| `thug_pipe_3` | WP-T | 20/4/22 | 10 | HEAVY | STAGGER | WeaponTip r0.2 | 18 | 1.5 | not a knockdown (§10) |
| `bruiser_grab` | WP-B | 32/6/24 | 0 | HEAVY | NONE | none (code connect) | 30 | 1.4 | unblockable; recoil 0 |
| `bruiser_headbutt` | WP-B | 12/3/24 | 15 | HEAVY | KNOCKDOWN | none (code hit) | 0 | 0 | from the hold; started without a wind-up |
| `bruiser_smash` | WP-B | 34/4/26 | 15 | HEAVY | KNOCKDOWN | both fists r0.22 | 30 | 1.25 | recoil 0 |
| `boss_charge` | WP-X | 32/24/30 | 20 | HEAVY | KNOCKDOWN | arc r1.1, ±35°, y 0.5-1.9 | 30 | 1.1 (+ charge distance) | recoil 0 |
| `boss_grab` | WP-X | 34/6/26 | 0 | HEAVY | NONE | none | 30 | 1.5 | unblockable; recoil 0 |
| `boss_slam` | WP-X | 14/3/30 | 25 | FINISHER | THROWN | none (code hit) | 0 | 0 | from the hold |
| `boss_pound` | WP-X | 36/4/30 | 15 | HEAVY | KNOCKDOWN | arc r2.5, ±180°, y 0-0.6 | 30 | 2.5 | unblockable; recoil 0 |

Rule test exemptions: `windup_floor` 0 is allowed only for moves started from a hold (`bruiser_headbutt`, `boss_slam`); `test_enemy_move_rules.gd` lists them by id. A FINISHER-tier enemy hit (`boss_slam`) brings the finisher hit-feel stack onto the player (slow-mo, impact frame); the WP-X builder judges it in captures and drops to HEAVY if it reads wrong.

## Appendix C: interfaces

**P0-sim (`CombatActor`, public and virtual):** `_apply_armor(hit)`, `_on_hit_absorbed(hit)`, `_on_grabbed(by)`, `_held_anim() -> StringName`, `_keeps_strike_pose() -> bool`, `abort_move()`, `break_free(push)`; the holder hook `_on_hold_broken(victim)` (called if present).

**AI-enemy contract** (group `"ai_enemy"`; implemented by `EnemyActor` and `stub_ai_enemy.gd`):
```gdscript
var archetype: StringName
var heavy: bool
var ai_state: int            # AiState
var has_token: bool
var entry_target: Vector3    # set by a spawner before add_child; Vector3.INF = none
func is_director_alive() -> bool          # health > 0 and not gone
func wants_token() -> bool
func grant_token() -> void
func revoke_token() -> void
func set_posture_slot(point: Vector3) -> void
func get_posture_slot() -> Vector3       # Vector3.INF = none
func slot_preference() -> float          # -1 in front .. +1 blind side
func warning_reach_m(move: MoveData) -> float
func debug_nav_path() -> PackedVector3Array
func place(pos: Vector3, yaw: float) -> void
func force_attack(move_id: StringName = &"") -> bool   # bots and tests
```

**Director read API** (group `"enemy_director"`; `EnemyDirector` and `stub_director.gd`): `attacker_cap() -> int`, `token_holders() -> Array`, `slot_of(enemy) -> Vector3`, `ring() -> Vector2`, `is_blind(enemy) -> bool`, `alive_count() -> int`, `can_spawn() -> bool`.

**Room contract** (crowd room; the training room gains `director`, `spawner`, `spawn_enemy`): `player`, `player_start`, `player_yaw_deg`, `with_presentation`, `waves_enabled`, `rng_seed`, `director`, `spawner`, `spawn_enemy(id: StringName, local_offset := Vector3.INF, yaw := NAN) -> Node3D`.

**`WaveSpawner`** (group `"wave_spawner"`): `spawn(id, at := Vector3.INF, yaw := NAN, tag := &"") -> Node3D`, `spawn_points() -> Array[Dictionary]`, `set_waves_enabled(on: bool)`, `wave_index: int`.

**`EnemyGrabHolder`** (WP-G):
```gdscript
enum Result { HOLDING, ESCAPED, TIME_UP, LOST }
func _init(owner: CombatActor) -> void
func try_connect(victim: CombatActor) -> bool
func is_holding() -> bool
func victim() -> CombatActor
func tick() -> int
func release(push: Vector3, stagger: bool) -> void
func land_final_hit(move: MoveData, reaction: int, knockback: Vector3) -> void
```

**`RearWarning`** (WP-W): `signal shown(corner: int, count: int, heavy: bool)`, `signal cleared(corner: int)`, `advance(delta)`, `corner_state(corner) -> Dictionary`, `active_entries() -> Array`.

**`PlayerCharacter`** (WP-G): `grab_break_progress() -> float`.

**`Weapon`** (WP-T): `drop(velocity: Vector3) -> void`.

---

## 7. Key judgement calls

Each is logged in `M3-judgement-calls.md` when made.

1. **Encode the done-when as tests before building anything.** The warning rule is a pure function with a hand-written truth table in the first commit; the readability metrics and thresholds exist before the second archetype. *Alternative:* build the AI, then judge readability from captures alone (M2 style). *Why not:* "readable" and "fires correctly" become arguable after the fact; numbers plus captures keep builders, reviewers and Game-boy's digest on one definition.
2. **A Phase 0 that lands every shared-file edit up front** (all hooks, signals, fields, about 90 tunables, rig and generator stubs, HUD nodes, the F6 action, the test doubles). *Alternative:* let each package edit hot spots and resolve conflicts at merge, as in M2. *Why not:* nine packages want the same eight files; pre-declaring turns merges into mechanical ones and costs one small serial step.
3. **The rear warning is built and proven against training dummies in Phase 1**, independent of the AI, then re-proven with real AI in Phase 3. *Alternative:* build it after the archetypes. *Why not:* it is half the done-when and needs nothing but `windup_started` and a posted dummy.
4. **One definition of "outside the view"** (`rear_warning_angle_deg` from `look_yaw`) for both the director's blind-spot priority and the warning. *Alternative:* a separate `blind_spot_angle_deg`, or the camera's forward. *Why not:* SPEC §8 defines the view once; two numbers would let the warning disagree with who gets priority; the camera is wrong in spins, the KO view and the debug cameras.
5. **Every enemy hit gets its own wind-up of at least the SPEC floor; `windup_mult` can't scale below it** (floor stored per move, a toggle in F1). *Alternative:* short 12-14-frame wind-ups for chain follow-ups, or an unclamped multiplier. *Why not:* each wind-up fires the warning and the vocal cue; a hit without one is the least readable thing a crowd can do.
6. **Token pacing on top of the cap:** a grant gap (0.2 s), a grace after the player is hit, a grace after a revive. *Alternative:* the cap alone, spec-literal. *Why not:* three wind-ups starting on the same frame are within the cap and unreadable; each pacing tunable at 0 restores the literal rule.
7. **Visible commitment and retreat:** a token holder stops, squares up, steps in from the ring, attacks, then backs off to the ring. *Alternative:* attack from the ring with a long lunge, or stay at close range after attacking. *Why not:* "who is next" must be visible before the wind-up, and lingering attackers wall off the view.
8. **Wind-ups track the player for half their length, then lock.** *Alternative:* full tracking, or none. *Why not:* full tracking makes dodges and sidesteps pointless; none makes enemies whiff at a walking player; half matches the dummy jab's no-magnetism precedent while keeping hits honest.
9. **World-space slots, evenly spread; preferences only choose who gets which angle; the Kicker re-circles itself.** *Alternative:* slots that rotate with the look. *Why not:* look-relative slots make the whole ring swirl every time the player turns, which reads as chaos.
10. **The damage rule is read per knockdown hit (≤ 15, boss exempt), and the Thug's third swing staggers instead of knocking down.** *Alternative:* a knockdown on swing 3. *Why not:* three 10-damage swings ending in a knockdown would break a per-sequence reading of SPEC §4; the stagger satisfies both readings.
11. **Bruiser armor:** light hits absorbed (damage still lands, with a flash, a clank and "ARMOR" in the log), heavy knockdowns downgraded to staggers, finishers and the haymaker keep their reaction. The boss has wind-up armor against light hits only. *Alternative:* armor that also ignores light damage, or a fully armored boss. *Why not:* the spec text; and an absorbed hit must still read as registered or players think the game dropped it.
12. **A parry still staggers the Bruiser and the boss.** *Alternative:* armor ignores perfect blocks. *Why not:* it rewards the skill the M1 block was built for, and one rule for every attacker is easier to read.
13. **Enemy grabs: the hold is the mash window; breaking free staggers the grabber; the final hit releases the player first.** *Alternative:* no reward for breaking free; keep the player held through the hit. *Why not:* the mash needs a visible payoff; and `CombatActor`'s GRABBED rule would swallow a non-throw hit from the holder.
14. **The player is held upright at arm's length (`held_collar`), look locked toward the grabber.** *Alternative:* reuse the bent-over `held` pose. *Why not:* it sinks the first-person lens into the grabber's chest.
15. **Phase 1 tests the director, warning, probe and F3 with test doubles** (`stub_ai_enemy.gd`, a `TrainingDummy` subclass implementing the AI contract). *Alternative:* serialize everything behind the enemy core. *Why not:* it would cut Phase 1's parallelism to one; the doubles stay as regression fixtures.
16. **An early readability review (Phase 1R) with six real Punks** before the other archetypes. *Alternative:* review only at the end. *Why not:* crowd-level problems are cheapest to fix with one archetype, before four more copy the pattern.
17. **The warning's side is fixed at the wind-up start** (a tunable re-evaluates it). *Alternative:* follow the player's turn every frame. *Why not:* SPEC says it appears at wind-up start, and a corner that jumps during a quick turn reads as a second attacker.
18. **The crowd room's wave cycle ends with the boss, then repeats.** *Alternative:* the boss only through F4. *Why not:* Game-boy should meet the boss without knowing the cheat menu.
19. **Staggered spawns** (one per 0.6 s) instead of caching the animation library. *Alternative:* a static library cache in `HumanoidRig`. *Why not:* zero risk to the rig tests now; the perf lens decides whether the cache is needed.
20. **Readability thresholds are test and bot constants, not tunables.** *Alternative:* put them in `TuningData`. *Why not:* they are acceptance criteria, not feel; moving them is a review decision, not a slider.
21. **No extra off-screen cue when enemies enter behind the player** (no door bang, no spawn bark). *Alternative:* a positional entry sound. *Why not:* SPEC §8 makes the warning the only off-screen aid; the wind-up cue already covers the danger.

## 8. Risks and mitigations
- **The warning is wired right but reads wrong in a real crowd** (several attackers per side, quick turns): Phase 1R's L1 on six real Punks; the oracle in every crowd act.
- **Posture motion becomes visual noise:** HOLD and taunt sub-modes, low strafe speed, R5/R8 metrics, L2.
- **Navmesh first-sync errors in tests:** guarded queries; WP-E and WP-D tests assert no `ERROR` lines.
- **Merge drift in `default.json`:** only the lead regenerates after merges.
- **Test time growth** (~90 s now): crowd tests capped at 900 frames and seeded; builders use `-gselect` during work.
- **Machine limits** (8 GB): at most 3 builders and 1 recording at a time (the lock).
- **Big rigs miss the player's head:** reach measured per archetype at its own height; strike poses aim down.
- **The boss slam's FINISHER tier puts player-finisher slow-mo on an enemy hit:** judged in captures; HEAVY fallback.
- **Usage cut-offs mid-phase:** `wip:` commits every 15-20 minutes, HANDOFF at every phase boundary, the resume task per HANDOFF.
