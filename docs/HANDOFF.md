# Handoff: live status

Update this file at every phase boundary and before every usage limit (see CLAUDE.md, "Handoff protocol"). The newest state goes at the top of "Status".

## Status (newest first)

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
- **Process:** at each usage limit, hand off to Game-boy's second Claude account. Never assume the same session resumes.

## Usage watcher
A separate low-cost Claude Code session, "Beat-em-up: usage watcher". Start it from the working session with `start_session`: initiation `user_asked`, `model` claude-haiku-5-5, `effort` low, `use_worktree` false, and the prompt below verbatim.

It paces itself (`/loop` with no interval), on Game-boy's cadence from 2026-10-23:

| Usage (the higher of the 5-hour and weekly windows) | Next check |
| --- | --- |
| below 70% | in 20 minutes |
| 70% up to 85% | in 10 minutes |
| 85% and up | in 5 minutes |

At 90% of either window it tells the working session to halt work and hand off. On a fast burn it checks sooner, and it warns early if it would cross 90% before its next check.

Its prompt:

```
/loop Usage watcher for the beat-em-up repo. You pace yourself. On each check:
1. Call mcp__ccd_session_mgmt__get_usage (load it with ToolSearch the first time). Read plan.windows: the "5-hour limit" window and the window whose label starts with "Weekly". Let U be the higher of their percentUsed values.
2. Handoff. If either window is at 90% or more, and you haven't already warned for that window's resetsAt, send a message to the session titled "Beat-em-up: working session" (find it with ListAgents). The message: "Usage at N% (window W, resets R). Halt work and do the handoff now per CLAUDE.md: stop new work, commit and push WIP on every branch and worktree, update and push docs/HANDOFF.md, then tell Game-boy." Remember that you warned for that resetsAt.
3. Snapshot. If either window is at 95% or more, write HANDOFF-SNAPSHOT.md at the repo root (untracked; never commit it). It holds:
   - the time and the usage numbers;
   - git status, git branch -vv and git worktree list;
   - for each worktree under .worktrees/, its git status --short and git log --oneline -3.
4. Next check, from U:
   - below 70: in 20 minutes (1200 s);
   - 70 up to 85: in 10 minutes (600 s);
   - 85 or more: in 5 minutes (300 s).
5. Fast burn. Estimate the rate from your previous check. If at that rate either window would reach 90% before that next check, check again in 5 minutes instead. If it would reach 90% within those 5 minutes, send the step 2 warning now (once per resetsAt).
6. Schedule the next check with ScheduleWakeup, passing this same prompt back.
Otherwise say nothing beyond one short line: the two percentages and the next check time. Never edit tracked files, run builds or start other work.
```

**Usage rules for the working session** (measured on account C, 2026-10-23):
- One heavy agent that both reviews and fixes costs about 25% of a 5-hour window, and a review-only agent about 13%.
- Run at most two heavy agents at once.
- Call `mcp__ccd_session_mgmt__get_usage` before every launch, and launch nothing new at 65% or more. An agent started at 65% ends near the 90% handoff.

If no watcher is running, for example after an account switch, start one with that prompt. A new account's watcher reports that account's usage.

**The working session must be titled "Beat-em-up: working session"** so the watcher can find it. A new account's working session renames itself to that first, with `mcp__ccd_session_mgmt__set_session_title`.

**At an account switch, the old working session:**
- renames itself "Beat-em-up: account X session (handed off)", which frees the title;
- tells its watcher to end its loop: "End your loop now: call ScheduleWakeup with stop: true, or CronDelete your job if you run on a fixed interval."

## Takeover prompt
Game-boy pastes this into a new account's session. Keep the "Next steps" list current at every handoff; the rest changes rarely.

```
You're taking over an in-progress Godot 4.7.2 project: a first-person beat-em-up proof of concept at /Users/arachne/repos/beat-em-up-PoC (GitHub: mikedtcm22/beat-em-up-PoC). I'm Game-boy, the project owner. Other Claude accounts did the work so far and handed off at their usage limits. We switch accounts at every usage limit, so treat the repo as the only source of truth. Work happens on branch m2/hit-feel and the worktrees under .worktrees/.

Start by doing these, in order:
1. Rename this session to "Beat-em-up: working session" (mcp__ccd_session_mgmt__set_session_title). The usage watcher finds you by that title.
2. Read CLAUDE.md, then docs/HANDOFF.md (live status and exact resume steps; the newest entry is at the top). Then read the milestone docs and review files it points to: docs/milestones/M2-plan.md, docs/milestones/M2-WP4-brief.md, docs/reviews/M2-phase1-review-findings.json and docs/reviews/M2-phase1-fix-results.json. Read docs/ARCHITECTURE.md and docs/SPEC.md §6, §10 and §11 before touching code.
3. Start a usage watcher exactly as docs/HANDOFF.md describes under "Usage watcher" (Haiku, low effort, self-paced /loop, shares this checkout, its prompt verbatim). Confirm it's running.
4. Check usage (mcp__ccd_session_mgmt__get_usage) before launching any workflow or agent.

USAGE RULES:
- A heavy agent that both reviews and fixes costs about 25% of a 5-hour window; a review-only agent about 13%.
- Run at most TWO heavy agents at once.
- Check get_usage before each launch, and launch nothing new at 65% or more.
- Prefer one agent per work package doing review, then fix, over many reviewers per package.
- The watcher checks every 20 minutes below 70%, every 10 minutes up to 85% and every 5 minutes above that. It tells you to halt and hand off at 90%.

Next steps (Milestone 2; details are in docs/HANDOFF.md):
- Phase 1 (WP1 tuning panel, WP2 comic VFX, WP3 audio) is done and merged into m2/hit-feel, and 400/400 tests pass. The 8 phase 1 spec questions are answered (all defaults kept), and README notes the two WP1 departures. WP3's audio was judged by analysis only, so I'll listen to it.
- Phase 2, WP4 (partial and full ragdoll), per docs/milestones/M2-WP4-brief.md. The worktree is ready: .worktrees/m2-ragdoll, branch m2/ragdoll, up to date with m2/hit-feel and imported. The player default is confirmed: enemies and dummies ragdoll, and the player keeps animated reactions, with a toggle. Run it as one workflow:
  - one builder: implements the brief, tests, ragdoll bot acts, captures in first person and side view; commits wip: often and ends with "M2 WP4: partial and full ragdoll";
  - then two reviewers at once: mechanics, and feel judged from the captures;
  - then one agent that verifies each finding adversarially, fixes the ones that hold, and commits "M2 WP4: review fixes (...)";
  - a get_usage gate before each launch, and nothing new at 65% or more;
  - tell each agent the absolute worktree path and to cd there (Workflow's isolation: 'worktree' fails here).
- Then merge m2/ragdoll into m2/hit-feel, run tools/run_tests.sh (everything must pass, no SCRIPT ERROR), push, and update docs/HANDOFF.md.
- Then phase 3 for my playtest: integrate, record every act and review it from captures (include M1's white hit flash, which fills much of the first-person view at close range), update README and ARCHITECTURE, and open the Milestone 2 PR.

Ground rules:
- Never merge a milestone PR into main until I've played it and signed it off.
- Any change to the spec needs my approval. Ask me with a short proposal and defaults.
- Commit early on branches (prefix "wip:" for unfinished work), push often, and update docs/HANDOFF.md at every phase boundary.
- When the watcher warns, do the handoff in CLAUDE.md immediately. Stop running workflows and agents, commit and push everything, save any unfinished agents' findings into the repo, and update HANDOFF.md, including this prompt's "Next steps". Then tell me.
- Judge visual and feel work from recorded captures (Movie Maker via tools/capture_combos.sh or tests/bot/vfx_bot.tscn), not just tests, and show me what you saw.
- Keep me posted briefly: what's done, what's running, what you need from me.
```
