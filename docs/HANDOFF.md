# Handoff: live status

Update this file at every phase boundary and before every usage limit (see CLAUDE.md, "Handoff protocol"). The newest state goes at the top of "Status".

## Status (newest first)

### Milestone 2 phase 1 started
- **Milestone 1:** done. Game-boy signed it off after three playtest rounds, and it's merged into `main` (PR #1, merge `c3e6a98`).
- **Milestone 2 (hit feel):** branch `m2/hit-feel`, from `main`. The plan, with self-contained work-package briefs, is [docs/milestones/M2-plan.md](milestones/M2-plan.md).
- **Phase 1:** WP1 (tuning panel, presets, cheats), WP2 (comic VFX, damage looks) and WP3 (audio, rumble) are being built in parallel. Each is in its own worktree under `.worktrees/` (`m2-tuning`, `m2-vfx`, `m2-audio`) on branches `m2/tuning`, `m2/vfx` and `m2/audio`, each with build, review and fix. They run as one Workflow from the original session (run `wf_0bfbae1d-6d1`; script at `~/.claude/projects/-Users-arachne-repos-beat-em-up-PoC/51b08ae0-62e1-4065-87dc-6d4672de274b/workflows/scripts/m2-phase1-wf_0bfbae1d-6d1.js`). Another account can't resume that run, so use the per-worktree steps below.
- **Usage watcher:** running as the session "Beat-em-up: usage watcher" (Haiku, every 15 min).
- **If the session stops mid-phase:**
  1. Run `git -C .worktrees/<wp> log --oneline main..` and `git -C .worktrees/<wp> status` for each WP.
  2. A WP with a build commit but no review: run a review, then a fix (the patterns are in CLAUDE.md).
  3. A WP with uncommitted work: read the diff, finish it from the brief in M2-plan.md, test and commit.
  4. A WP with nothing: start it from its brief.
- **Next:** merge the three WP branches into `m2/hit-feel`, then phase 2 (WP4, ragdoll), then phase 3 (integrate, review, PR, Game-boy's playtest).

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
A separate low-cost Claude Code session (the cheapest model, Haiku), started from the working session with `start_session`. Its standing instructions:

> Every 15 minutes (use the `loop` skill: `/loop 15m ...`), call `mcp__ccd_session_mgmt__get_usage` (load it with ToolSearch first) and read `plan.windows`.
> - If the "5-hour limit" or "Weekly" window is at 85% or more, and you haven't already warned for that window's `resetsAt`, send a message to the working session on this repo (find it with ListAgents: the session titled "Beat-em-up: working session"). The message says: "Usage at N% (window W, resets R). Do the handoff now per CLAUDE.md: stop new work, commit and push WIP on every branch and worktree, update and push docs/HANDOFF.md, then tell Game-boy." Remember that you warned for that `resetsAt`.
> - If a window is at 95% or more, also write `HANDOFF-SNAPSHOT.md` at the repo root (untracked; don't commit). It holds the time, the usage numbers, `git status`, `git branch -vv`, `git worktree list`, and for each worktree under `.worktrees/` its `git status --short` and `git log --oneline -3`.
> - Otherwise do nothing and say nothing beyond one short line.
> - Never edit tracked files, run builds or start other work.

If no watcher is running (for example after an account switch), start one with that prompt. A new account's watcher reports that account's usage.

**The working session must be titled "Beat-em-up: working session"** so the watcher can find it. A new account's working session renames itself to that first, with `mcp__ccd_session_mgmt__set_session_title`, and the previous holder of the title should already be idle or archived.
