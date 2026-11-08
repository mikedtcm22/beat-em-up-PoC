# Video handoff: live status

The cinematic gameplay video's live status, kept by the video session ("Beat-em-up: video session", in `.worktrees/video` on `video/cinematic-trailer`), the way docs/HANDOFF.md is kept for the game. Newest entry first. The brief is [PLAN.md](PLAN.md). A takeover session resumes from the newest entry, and takes Game-boy's approvals from the first one (at the bottom).

**Paid services spent so far:** Gemini $0.00 of the $5 cap (ledger: [gemini_ledger.md](gemini_ledger.md)) · Tripo 0 credits (not approved) · ElevenLabs 0 (not approved).

## Status (newest first)

### 2026-11-08 17:35 CST: resumed after the reset; Phase 1b running (LD-WORLD2, LD-ASSET, LD-STAGE)
- **Resumed** by the Auto-mode resume task at 17:30. Usage: the 5-hour window at 0%, weekly at 18%. The game session was idle (no Godot running).
- **Running:** the Workflow `build.js` with [args-p1b.json](args-p1b.json) (run `wf_8e7892ff-d01`, task `w887co1c3`), with LD-WORLD2, LD-ASSET (Blender) and LD-STAGE, two at a time.
- **The app blocks sessions from automated turns.** A turn started by a scheduled task or another session's message can't start a session: "Start sessions only on the user's own words". So the watcher and the relay were proposed as cards (`task_779886cc` for the watcher, `task_03fcbe0f` for the relay), and Game-boy was told by DM to press Start on each.
  - **Until they run,** the lead checks `get_usage` and the DM (`D0AQUKX5DB6`, messages from `U0AQMKKBL93` newer than the relay's `last_ts`) itself, at every wake.
  - **For future resumes:** the resumed session can't restart the loops alone. Keep them alive across pauses (a pause doesn't need them stopped), or propose cards again.
- **Also:** the relay prompt now skips any message whose ts isn't newer than `last_ts` (Slack's `oldest` can include it).

### 2026-11-08 16:05 CST: Slack works; the resume task re-set in Auto mode; Game-boy told by DM
- **Slack.** Game-boy fixed the connector, so this session has the Slack tools.
  - The connector posts as **Arachne Dev** (`dev@arachnefinance.com`, `U0AQP0N7RC6`).
  - Game-boy is **mchristopher** (`U0AQMKKBL93`), and the DM is `D0AQUKX5DB6`.
  - Sent: "good to restart at the next 5-hour reset" (`p1794175491105829`, ts 1794175491.105829). Questions go there from now on. **His DM replies are his answers** (the relay forwards them).
- **The resume task, re-set:** `beat-em-up-video-resume-20261108-1730`, firing at 17:30 CST, **saved in Auto mode**, so it won't stall on approvals. The old default-mode task `...-1720` is deleted.
- **The relay** is stopped until the resume, because Game-boy wants it running only while work is. Its prompt in [slack_relay_prompt.md](slack_relay_prompt.md) now uses the verified identities. Its state file is seeded at the DM above, so no reply is lost before it starts.
- **At the resume:**
  1. Start a new usage watcher (PLAN.md §12).
  2. Start the relay ([slack_relay_prompt.md](slack_relay_prompt.md)).
  3. Run `build.js` with [args-p1b.json](args-p1b.json) (LD-WORLD2, LD-ASSET, LD-STAGE).
  4. Then Gate 2, by Slack DM.

### 2026-11-08 15:58 CST: paused for Game-boy's app restart
- **Game-boy:** "pause working tasks so I can restart". Nothing was running. The usage watcher and the Slack relay were told to end their loops.
- **After the restart:**
  1. Start a new watcher (PLAN.md §12).
  2. Start a new relay ([slack_relay_prompt.md](slack_relay_prompt.md)).
  3. Check whether this session now sees a Slack connector. If so, send Game-boy a short test DM.
  4. The resume task `beat-em-up-video-resume-20261108-1720` still fires at 17:30 CST for the next wave (the 15:40 entry's steps).

### 2026-11-08 15:52 CST: handoff at the watcher's warning (86%, 90% within minutes); nothing running
- **Game-boy (chat, 15:50):** "I've connected you to Slack. In the future please DM me (@michael) with open questions." He also asked for a heartbeat that forwards his DM replies into this session as answers to the open questions, every 20 minutes or so, only while the work runs and never while it's paused for usage. He wants to work through Slack rather than this chat window.
  - **Started:** "Beat-em-up: video Slack relay" (`local_0b0e0465-5036-4848-813f-e4877d8332c2`), Haiku at low effort, a /loop every 1200 s.
    - It checks usage first and sleeps until the reset at 90% or more.
    - It reads DM `D0AQUKX5DB6` for messages from `U0AQMKKBL93` newer than `last_ts` in `captures/video/slack_relay_state.json` (untracked), and sends them verbatim to "Beat-em-up: video session".
    - It never posts to Slack. Its prompt is in this session's transcript; re-create it the same way if it isn't running.
  - **Treat a relayed reply** as Game-boy's answer to the open question it answers. Confirm anything outside that question's scope (a deletion, a spend, a merge) here first.
  - **Open issue:** this session's connector list has **no Slack connector** (checked 15:50). Lovable, Claude Docs, Google Drive, the vaults and Open Brain are there. Game-boy was asked to check that Slack is connected and enabled for this account. Until it's visible, questions go in the chat. The relay reports whether a new session sees the Slack tools.
- **The state at the handoff:**
  - Nothing is running: no workflow, and no builder.
  - `video/cinematic-trailer` is pushed, at the commit holding this entry.
  - The builders' branches `mv/p0-stills`, `mv/p0-spike`, `mv/ld-world` and `mv/ld-ink` are pushed and merged.
  - **The resume task** `beat-em-up-video-resume-20261108-1720` fires at 17:30 CST. The resume steps are in the 15:40 entry: run `build.js` with `args-p1b.json` (LD-WORLD2, LD-ASSET, LD-STAGE).
- **Waiting on Game-boy:** the Slack connector, to be visible to this account's sessions.

### 2026-11-08 15:46 CST: Game-boy approved round 2 as the environment look
- **Game-boy, word for word:** "Yes, round 2". The round 2 targets (`captures/video/p0/gemini_env/target_*.jpg`) are now the environment bar. Environments carry drawn detail (brick courses, frames, pipes, fire escapes, paving, puddles), are crisp, and have small, contained lights with no glare.
- It supersedes PLAN.md §4's "the environment as flat paint ... dropping the brick and grime detail", and the blind check's call to break regularity by removing detail. The note is in PLAN.md §4, part 7.
- LD-WORLD2's brief (P1.md) already follows it. The post-reset wave (args-p1b.json) is unchanged. Resume steps are as in the 15:40 entry.

### 2026-11-08 15:40 CST: Game-boy answered Gate 1; wave 1 merged; paused near 90% until the 17:20 reset
- **Game-boy at Gate 1, word for word:** "The characters look pretty good, but I think the environments are maybe a bit too washed out by lighting/glare in places. I'd like there to be more detail in the environments - so that people can discern how the player is moving through the game. Can you try to render the environments with some more detail? Use the first 10-15 sec or the 'pt5' video as a reference."
  - **Done in answer:** paint-over round 2 (`make_paintover_jobs.py --env`). Five stills were repainted with drawn environment detail and no glare, with ref 2 at 3.5 s and 4.5 s (the camp and the tent) as the references, for $0.70. The Gemini total is $1.54 of $5.
  - The targets are in `captures/video/p0/gemini_env/target_*.jpg`. The comparison sheet, our still | round 1 | round 2, is `captures/video/p0/gate1/env/overview.png`. It was sent to Game-boy.
  - **The decision:** his eye outranks the blind check. Environments carry drawn detail (brick courses, frames, pipes, fire escapes, paving, puddles), are crisp, and have small, contained lights.
- **Wave 1 is merged:** `mv/ld-world` (`7d89ce4`) and `mv/ld-ink` (`af5a179`), at `1f0c7e4`. ASSETS.md had both packages' sections in conflict; both were kept. The video tests pass 39/39, and there is no diff under `game/`, `tuning/` or `tests/`.
  - **LD-WORLD:** `VideoWorldLook` for street_night, roofs_dusk and boss_fire. It has the light rig with one shadow caster and the hard sodium pools, flat paint v2, the painted sky with a banded halo, haze bands, matte cards, embers and steam.
    - It flattened the brick and hash-blanked windows to beat the blind check. That's the opposite of Game-boy's direction, so LD-WORLD2 undoes it.
    - Its renders are in `.worktrees/mv-ld-world/captures/video/world/r13`.
  - **LD-INK:** `VideoInkLook`, with cine_toon and cine_outline (width follows the key), screen ink, rim lights, the 2D cues as switches (on twos, smears, hidden comic words, flash frames and speed lines inside the render), a compositor post pass, three LUTs and `look_sweep.py`.
    - Its builder scored P1 1.3, P2 1.8, P7 1.0 and P8 2.0. The gaps are drawn faces (LD-ASSET) and lit fills.
    - Its renders are in `.worktrees/mv-ld-ink/captures/video/ink/`.
  - **Requests to carry into wave 2:**
    - LD-STAGE: set `CineInkRig.frame_source` to the 24 fps frame index; assign the rig's compositor to the SubViewport camera; hide the LookPost edge quad in every shot.
    - LD-WORLD2: the props' materials (flat_paint_prop is ready).
    - LD-WORLD: `shadow_blur` of 2.5 or more on the key.
- **Wave 2 was skipped** by the usage gate (5-hour window at 81% after wave 1). It is LD-STAGE and LD-ASSET, now joined by LD-WORLD2 (the brief is P1.md's last section).
- **Resume steps (after the 17:20 CST reset):**
  1. `get_usage`. Make sure the watcher is running.
  2. If Game-boy answered about round 2 since this entry, follow him. A "no" changes LD-WORLD2's brief before the launch.
  3. Run the Workflow `scriptPath: tools/workflows/build.js` with [args-p1b.json](args-p1b.json): LD-WORLD2, LD-ASSET (Blender) and LD-STAGE, concurrency 2. It resumes from the branches' state.
  4. When they're done, merge them. Render the Gate 2 set through LD-STAGE's `shoot.sh`: the six shots plus the 5 s moving shot.
  5. The lead's look, then one review round (one Opus visual lens and one Sonnet code lens), and the blind check again.
  6. Gate 2 to Game-boy, here in the chat.
- **Usage:** the wave-1 builders cost 1.03M tokens and about 35 points of the 5-hour window, which went from 46% to 81%. Weekly is at 16%.

### 2026-11-08 15:20 CST: Gate 1 sent (here in the chat); Phase 1's wave 1 running (LD-WORLD, LD-INK)
- **Phase 0 is done.** The builds were `mv/p0-stills` (`5fd3701`) and `mv/p0-spike` (`623459b`), merged at `4f8e1fd`. The video tests pass (10/10), and there is no diff under `game/`, `tuning/` or `tests/`.
  - **The six stills** frame well against their reference frames. They're in `.worktrees/mv-p0-stills/captures/video/p0-stills/`.
  - **The spike** is in `.worktrees/mv-p0-spike/captures/video/p0-spike/r7/`, renders a-e.
    - The builder scored it about 1.6, and the lead about 1.2-1.4 (bar 2.4).
    - The flat-paint environment was the big step. The ink was invisible at night. The Gaussian bloom and fog read as 3D.
    - The style meter scores it 0.94 by the numbers anyway: the numbers are not the style.
  - **The Gemini targets** are in `captures/video/p0/gemini/target_*.jpg`: 6 images, about $0.84. They make strong bars.
  - **The sheets** for Game-boy:
    - `captures/video/p0/gate1/targets/overview.png`: reference | our still | target, six rows;
    - `captures/video/p0/gate1/spike.png`: the game today | the spike | ref 2 at 37.4 s.
- **The blind check** (one Opus agent; the key is in this session's scratchpad, `blind_key_gate1.json`):
  - It called the six reference frames drawn, and our two plain stills 3D.
  - It called the spike 3D (0.92).
  - **It called two of the three Gemini targets 3D** (`fp_kicker_lamp` 0.85, `roof_silhouette` 0.6). Only `ox_closeup` passed, at 0.55.
  - The tells were our geometry: tiled brick in exact perspective, repeated window grids, chain-link, ruler-clean outlines, two parallel shadows from a multi-light rig, identical enemy copies, and exact depth fog.
  - So Phase 1 must break mechanical regularity, not only repaint the shading (P1.md, "What Phase 0 found").
- **Running:** the Workflow `build.js` with [args-p1.json](args-p1.json) (run `wf_6251c28d-453`, task `wupkpur9n`). The briefs are in [P1.md](P1.md).
  - **Wave 1** is running: LD-WORLD (`mv/ld-world`) and LD-INK (`mv/ld-ink`).
  - **Wave 2**, LD-STAGE (`mv/ld-stage`) and LD-ASSET (`mv/ld-asset`, Blender), waits for a Godot slot. Its usage gate will probably skip it until the 17:20 CST reset. Then rerun the Workflow with the same args: done packages are skipped by the Load phase.
- **Also new:**
  - `tools/video/style_meter.py`, with `style_targets.json` (STYLE.md's ranges);
  - `video/look/look_piece.gd`, the look-piece interface.
- **Decisions (the lead's):**
  - **Phase 1 is four packages in two waves**, not PLAN.md §6's three: the world, the characters' ink, the stage, the assets. The spike showed the environment and the characters are separate big jobs.
  - **The lead merges the builders' `mv/*` branches into `video/cinematic-trailer`,** as PLAN.md §6-7 describe. The approvals' "merging anything" is read as the final PR and anything into `main` or `m6/*`. That reading was put to Game-boy in the Gate 1 message.
- **Usage, measured on this Team seat:**
  - A Sonnet builder of about 350k tokens costs about 10 points of the 5-hour window. That's 3-4 times the premium seat's rate.
  - One 5-hour point costs about 0.15 weekly points.
  - At launch: 46% of the 5-hour window, 10% weekly.
- **Waiting on Game-boy:** Gate 1. "Is this the style?", about the targets; his answer on the blind check's fallbacks (A2 and A+); and the merge reading.

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
