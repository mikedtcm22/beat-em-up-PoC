# Handoff: live status

Update this file at every phase boundary and before every usage limit (see CLAUDE.md, "Handoff protocol"). The newest state goes at the top of "Status".

## Status (newest first)

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
