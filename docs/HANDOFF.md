# Handoff: live status

Update this file at every phase boundary and before every usage limit (see CLAUDE.md, "Handoff protocol"). The newest state goes at the top of "Status".

## Status (newest first)

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
- **Process:** at each usage limit, hand off to Game-boy's second Claude account. Never assume the same session resumes.

## Usage watcher
A separate low-cost Claude Code session (the cheapest model, Haiku, low effort), started from the working session with `start_session` (initiation user_asked, `model` claude-haiku-5-5, `use_worktree` false, prompt starting "/loop 5m"). Its standing instructions:

> Every 5 minutes (use the `loop` skill: `/loop 5m ...`), call `mcp__ccd_session_mgmt__get_usage` (load it with ToolSearch first) and read `plan.windows`.
> - If the "5-hour limit" window is at 70% or more, OR it rose 15 points or more since your previous check (fast burn), OR the "Weekly" window is at 85% or more, and you haven't already warned for that window's `resetsAt` (fast-burn warnings may repeat once per 30 minutes), send a message to the working session on this repo (find it with ListAgents: the session titled "Beat-em-up: working session"). The message says: "Usage at N% (window W, resets R). Do the handoff now per CLAUDE.md: stop new work, commit and push WIP on every branch and worktree, update and push docs/HANDOFF.md, then tell Game-boy." Remember that you warned for that `resetsAt`.
> - If a window is at 95% or more, also write `HANDOFF-SNAPSHOT.md` at the repo root (untracked; don't commit). It holds the time, the usage numbers, `git status`, `git branch -vv`, `git worktree list`, and for each worktree under `.worktrees/` its `git status --short` and `git log --oneline -3`.
> - Otherwise do nothing and say nothing beyond one short line.
> - Never edit tracked files, run builds or start other work.

If no watcher is running (for example after an account switch), start one with that prompt. A new account's watcher reports that account's usage.

**The working session must be titled "Beat-em-up: working session"** so the watcher can find it. A new account's working session renames itself to that first, with `mcp__ccd_session_mgmt__set_session_title`, and the previous holder of the title should already be idle or archived.
