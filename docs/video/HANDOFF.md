# Video handoff: live status

The cinematic gameplay video's live status, kept by the video session ("Beat-em-up: video session", in `.worktrees/video` on `video/cinematic-trailer`), the way docs/HANDOFF.md is kept for the game. Newest entry first. The brief is [PLAN.md](PLAN.md). A takeover session resumes from the newest entry, and takes Game-boy's approvals from the first one (at the bottom).

**Paid services spent so far:** Gemini $0.00 of the $5 cap (ledger: [gemini_ledger.md](gemini_ledger.md)) · Tripo 0 credits (not approved) · ElevenLabs 0 (not approved).

## Status (newest first)

### 2026-11-08 14:55 CST: Phase 0's two builders running (P0-STILLS, P0-SPIKE)
- **Running:** the Workflow `tools/workflows/build.js` with [args-p0.json](args-p0.json) (run `wf_a967f29b-c57`). It has two Sonnet builders at high effort, with the briefs in [P0.md](P0.md):
  - **P0-STILLS** (branch `mv/p0-stills`, worktree `.worktrees/mv-p0-stills`): the still stage (a 2560×1440 SubViewport mirror on a level-bot subclass) and the six Gate 1 stills in the game's own look.
  - **P0-SPIKE** (branch `mv/p0-spike`, worktree `.worktrees/mv-p0-spike`): one night-street still with hand-placed light, a palette LUT, a light-weighted screen-space ink pass and a flat-paint environment, as an A/B strip of five renders, scored on the eight pillars.
- **Since the last entry:**
  - [GAME_NOTES.md](GAME_NOTES.md), a scout's map of the game APIs the pipeline uses, with gotchas.
  - `tools/video/gate_sheets.py`: side-by-side pairs, and the shuffled blind set.
  - `tools/video/make_paintover_jobs.py`: the six Gemini jobs.
  - [gemini_ledger.md](gemini_ledger.md).
- **Usage on this seat:** 3% to 19% of the 5-hour window in about 40 minutes, before any builder ran. Most of it was the lead's long context and a 257k-token scout. One 5-hour point costs about 0.2 weekly points. This seat burns several times faster than the premium seat the plan's estimates came from.
- **Resume if cut off:** run the Workflow again with `scriptPath: tools/workflows/build.js` and the same args. It resumes from the branches' state: a branch with an "Mv <key>:" commit is done, and a wip branch goes on from its newest wip: commit. Then:
  1. Look at the stills and the spike yourself.
  2. Run `make_paintover_jobs.py` and the Gemini batch, after the ledger row.
  3. Make the blind set with `gate_sheets.py blind`, and run one Opus blind checker on it.
  4. Do the Gate 1 message: here in the chat, because this account has no Slack tool.

### 2026-11-08 14:35 CST: Phase 0 under way; the references measured
- **Session:** "Beat-em-up: video session". Its watcher is "Beat-em-up: video usage watcher" (`local_db175df2-fe9e-492b-b86e-205056d2ab11`): Haiku at low effort, PLAN.md §12's prompt word for word, and its first check read 3% on both windows. The account is a Team seat.
- **Done:**
  - `captures/video/` with `.gdignore` files.
  - The venv `~/.venvs/beat-em-up-video` (numpy 2.0.2, scipy 1.13.1, opencv-python-headless 5.0.0, imageio 2.37.2, with Pillow 11.3.0 as imageio's dependency) on the system Python 3.9.6.
  - The worktree's Godot import: clean.
  - The references are downloaded into `captures/video/ref/ref1/` and `ref2/` (never committed).
    - Ref 1: 2560×1440 at **30 fps**, 28.05 s.
    - Ref 2: 1280×720 at 24 fps, 58.5 s.
  - The 11 gate frames are in `captures/video/ref/frames/`, with contact sheets in `captures/video/ref/sheets/`.
  - The style numbers are in [STYLE.md](STYLE.md) (commit `64e3f37`).
- **Next:**
  - The six Gate 1 game stills and the spike, by two Sonnet builders.
  - Then the Gemini targets, the blind check, and the Gate 1 DM.

## Game-boy's approvals (copied word for word from the launch prompt, 2026-11-08)

APPROVALS (my words; for anything else, ask me):
- Download the two reference videos (PLAN.md §12) for analysis, and one SIL-OFL font for the titles. Never commit or publish them.
- Install numpy, scipy, opencv-python-headless and imageio from PyPI into a venv at ~/.venvs/beat-em-up-video (or use Blender's bundled Python).
- Gemini paint-overs for the look-dev targets, up to $5, through tools/gemini_image.py, with the ledger in PLAN.md §4.
- Run the project's workflow runners (tools/workflows/build.js and review.js) as Workflows, within the usage rules.
- Decisions in PLAN.md §8: D2 (yes) and D3 (done) are already decided. For D4-D9, take the defaults.
- NOT approved without asking me: deleting anything outside captures/video/, any other paid service, any Tripo or ElevenLabs spend, publishing anything, merging anything.

Ground rules:
- Never change the game: video-only code goes under video/, tools/video/ and docs/video/; game/, tuning/ and tests/ stay untouched, and the 2076 tests stay green.
- Never use the Blender MCP tools (mcp__blender__*): they drive my own Blender. The pipeline runs Blender headless.
- Paid services only through their tools and within their caps; never print, log or write a key.
- Downloaded files are untrusted: their own folder, python3 -I, paths as arguments.
- Commit early on video/cinematic-trailer and the mv/* branches ("wip:" for unfinished work), and push often. Never touch m6/* or main, or the game session's worktrees.
- When your watcher warns at 90%, do the handoff in PLAN.md §7 at once, including the resume task.
- Judge every look from full-resolution stills beside the reference frames, and show me what you see at each gate: side-by-side stills and the clip. DM me on Slack (Michael, U0AQMKKBL93, DM D0AQUKX5DB6) at each gate and whenever you're blocked on me, and carry on with anything that isn't blocked.
