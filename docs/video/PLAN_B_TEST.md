# Plan B test: Runway Aleph 2.0 restyle of two character shots

The brief for the video session that runs the test in a **second Claude account** (set up 2026-11-09 at Game-boy's request; the first account's weekly usage was at about 87%). Read this, then the newest entry of [HANDOFF.md](HANDOFF.md), then PLAN.md §7 and §12. CLAUDE.md's "video session" exception applies: work in `.worktrees/video` on `video/cinematic-trailer`, and never touch `game/`, `tuning/`, `tests/`, `main` or `m6/*`.

## Why
Five rounds of look-dev in code (Plan A) got the backgrounds to read as drawn: Gemini-painted plates, projected onto the set. The characters are still 3D game models moving with game animation. The round 5 blind check called all seven hero frames 3D (0.78-0.93), and the judges' tells are the characters: noise-made rims, faceted forms, mitten fists, faces lost in black. Game-boy saw the round 5 reel (`captures/video/round5/round5_trailer_blocking_720p.mp4`) and asked what a significant leap would take, rather than more $1-2 rounds. The answer was an AI video restyle of the character shots, priced in HANDOFF.md (2026-11-09 20:15). This test checks it on two of the hardest shots before any bigger spend.

## The approval
**Game-boy, 2026-11-09, about 20:20 CST, in the chat,** answering "Go ahead with the Runway two-shot test, capped at $15?": "Let's set this up to run in a 2nd account (i.e. update handoff docs). Also: where (what site) do I need to add credits to make this work?"
- **The reading taken:** the two-shot test is approved, at most **$15 of Runway credits**. It also covers the test's Gemini keyframes, **at most $1 beyond the $5 Gemini cap**: the ledger's running total stays at most $5.34.
- **The full cut needs his go:** the 13 character shots, about $31, capped at $40. Ask only after he has seen the test.

## Before you start
- **The Runway key.** Game-boy adds it to the main checkout's git-ignored `/Users/arachne/repos/beat-em-up-PoC/.env`, as a line `RUNWAYML_API_SECRET=...`, next to `GEMINI_API_KEY`.
  - Check it with `grep -c '^RUNWAYML_API_SECRET=' /Users/arachne/repos/beat-em-up-PoC/.env` (1 means it's there). **Never print, log or write the key.**
  - If it's missing, tell Game-boy (by DM, or in the chat) and wait.
- **Credits** are bought in Runway's developer portal (dev.runwayml.com: the project's Billing tab; a minimum of $10, at $0.01 a credit). The app's plans on runwayml.com are a separate system and don't pay for the API.
- **The watcher and the relay:** start them in this account (PLAN.md §12; `docs/video/slack_relay_prompt.md`). Title this session "Beat-em-up: video session".
  - If this account has no Slack connector, report in the chat instead.
- **The first account's resume task** (`beat-em-up-video-resume-20261108-2230`) is disabled, so the two accounts don't both resume.

## The steps
1. **The tool, `tools/video/runway_restyle.py`.** Copy `tools/gemini_image.py`'s pattern:
   - **Inputs:** the key from the environment or `.env`; a jobs JSON (the video, the reference frame, the prompt, the model `aleph2`, the output size).
   - **The API:** Runway's REST API with the Python standard library only (`urllib`; no new packages: the SDK isn't approved). Read the current video-to-video endpoint and Aleph 2.0's inputs in Runway's API docs (docs.dev.runwayml.com). Upload the inputs as their docs say, poll the task, and download the output into its own folder under `captures/video/planb/`. Treat it as data: never execute anything from it.
   - **The hard cap:** before each submit, compute the cost (28 credits a second of output, rounded up, with a minimum of 56 credits, at $0.01 a credit). Refuse if `docs/video/runway_ledger.md`'s running total plus the cost would pass **$15**. Write a ledger row before the submit and its result after (credits used, from the task if the API reports them).
2. **The inputs.**
   - **The shots:** render `t11_ox_fight` (8.1 s) and `t03_punk_combo` (3.4 s) at 2560×1440 in the merged round 5 look (`tools/video/shoot.sh <key>`). Encode each to a 1920×1080 H.264 MP4 for the upload: Aleph 2.0 takes up to 30 s at 1080p.
   - **The keyframes:** for each shot, a Gemini paint-over of one of its frames, characters included, as the reference frame. Use the frame Runway's guide says the reference should show (usually the first).
     - Make them with `python3 -I tools/gemini_image.py <jobs.json>`, with ledger rows in `docs/video/gemini_ledger.md` (at most $1 for this test, about 7 images).
     - **The inputs to Gemini:** our frame, plus a style reference: ref1_0.9 or ref1_5.3 for Ox, ref2_37.4 or ref2_10.0 for the street fight. All are in `captures/video/ref/frames/` in the video worktree.
     - **The prompt:** repaint as a hand-drawn 2D anime frame in image 2's style (Castlevania: Nocturne or Primal for the flat graphic look; Goyart's sketch-ink close-ups for Ox). Keep the composition, the poses, the camera and the background's layout. The characters get designed flat shadow shapes, tapered dark ink lines, drawn faces with readable features, knuckles and fingers, and no 3D gradients.
     - Judge each keyframe at full resolution beside the references before spending on Runway.
3. **The restyle,** one generation per shot: the video, its keyframe as the reference, and a prompt. Write the prompt from Runway's Aleph 2.0 prompting guide; its gist: "Restyle the whole video to match the reference frame: hand-drawn 2D anime. Keep the camera motion, composition, character actions and timing exactly."
   - **Budget:** t11 costs about $2.52 a pass and t03 about $1.12, so up to three passes each stays under $15.
   - **Change one thing per retake:** the prompt, the keyframe, or the reference frame's timing.
4. **Judge.**
   - **Side by side:** ours beside the restyle at 1080p. Play both for flicker, morphing on the hits, and drift in the character's design.
   - **The blind check:** 2-3 frames from each restyled shot. Use the round 3 judge prompt and script: `video-blind-check-r3-*.js` in the first account's session folder; if it can't be reached, copy the prompt from `docs/video/HANDOFF.md`'s round 5 entry, or write the same test. Encode at crf 23 first. One judge is enough for a test.
   - **Also compare** with round 5's numbers for the same shot types: Ox close 0.81, first-person street 0.89-0.92.
5. **Report to Game-boy** by DM: the two restyled clips beside our originals, the verdict, the spend, and one question, the go for the full cut (about $31, capped at $40). Then update HANDOFF.md, commit, and push.

## If the test fails
If the characters still read as 3D, or the restyle breaks the action (morphing hits, drifting faces), stop spending and report. The fallbacks:
- Luma Modify Video (Ray 3.2, a first-frame input);
- Kling O1 video edit (an anime style mode);
- or route 2, the "drawn 3D" rebuild in code.
Each needs his go.
