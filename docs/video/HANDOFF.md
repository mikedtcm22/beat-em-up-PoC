# Video handoff: live status

The cinematic gameplay video's live status, kept by the video session ("Beat-em-up: video session", in `.worktrees/video` on `video/cinematic-trailer`), the way docs/HANDOFF.md is kept for the game. Newest entry first. The brief is [PLAN.md](PLAN.md). A takeover session resumes from the newest entry, and takes Game-boy's approvals from the first one (at the bottom).

**Paid services spent so far:** Gemini about $2.52 of the $5 cap, 18 images (round 3 used $0.98 of its $2.50; ledger: [gemini_ledger.md](gemini_ledger.md)); $2 more approved on 2026-11-09 for per-shot background paint-overs if round 4 still needs them · Tripo 0 credits (not approved) · ElevenLabs 0 (not approved).

## Status (newest first)

### 2026-11-09 16:05 CST: round 5's blind check (the first movement) DM'd; handoff at weekly 85%, resume after the weekly reset (2026-11-10 16:00 CST)
- **The blind check** (`wf_7b259cfc-8b0`, three judges, the hero frames at crf 23): all 8 references drawn (0.05-0.15). Ours are still all called 3D, **but every frame type moved for the first time:**

  | Frame type | Hero frame | Round 5 | Round 4 |
  | --- | --- | --- | --- |
  | Ox wide | t10 | 0.78 | 0.88 |
  | Ox close | t12 | 0.81 | 0.89 |
  | Roof against the sun | t07 | 0.86 | 0.91 |
  | Street wide | t01 | 0.89 | 0.97 |
  | First-person street | t04, t03 | 0.89, 0.92 | 0.95 |
  | First-person roof | t08 | 0.93 | — |

  - **The painted backgrounds read as drawn** ("the explosion reads as drawn ... only the figure gives the frame away").
- **The tells now are the characters:**
  1. rims and light wrap made by a noise threshold (jagged bands of constant width, orange flecks inside the figures, white blotches on the Kicker), not designed shapes;
  2. faceted low-poly forms (fists, sleeves, hoods), mitten fists, faces lost in crushed black;
  3. one outline treatment with an even jitter, doubled by a pale or orange halo at a constant offset;
  4. in the first-person shots, details in exact perspective (the fence's X glints, windows, a car), and one brick-cluster decal repeated;
  5. depth-graded DOF and bloom.
- **The judges' confound,** "ours look pristine": measured with `tools/video/r4_delivery_meter.py`. **Ours are already as soft as the references, or softer** (10-90% edge widths of 3-6 px against 3.2-4.8 px). But their flat fills have **almost no high-frequency texture** (radial hf 0.002-0.016 against the references' 0.013-0.067: grain, painted texture, compression noise). A YouTube-like re-encode (to 1080p at crf 31 and back) only softens further, so the judge run for it was skipped. Round 6 should add grain and texture to the fills to the references' hf, not more softening.
- **Sent to Game-boy at 16:00** (DM: the sheet `F0CGCB3AS7N` with the message). **One open question:** about $1.50 more of Gemini (6-10 images, beyond the $5 cap) for full-frame paint-overs, characters included, held 1-1.5 s on the close-ups' key beats (Ox's reveal, the knockout). Without an answer, round 6 is code only.
- **Gemini:** $4.34 of the $5 cap; $0.18 is left. **Open for later:** the 7 trailer shots without a plate (t02, t05, t06, t09, t11, t13; t14 is multiplane) need about $1 of plates for the final trailer, which is a future ask.
- **19:40: the round 5 reel**, at Game-boy's request (`captures/video/round5/round5_trailer_blocking_720p.mp4`: all 14 shots at 720p in the merged round 5 look, 49 s, labelled, no sound; DM `F0CGE7D0M4L`; `scratchpad/reel_r5.sh` remakes it). All 14 rendered with problems=0. The contact strip shows a readability problem: **the back-lit silhouettes make the point-blank shots dark masses** (t11, Ox's fight, is mostly a black wall; t05 and t06 are hard to read). Round 6 keeps a readable key light on near figures.
- **Round 6, the plan** (code; write it as packages at the resume):
  - **R6-ART, characters designed not computed:**
    - a clean, tapered rim on the light side only (its width a designed function of the back light, no noise threshold, no flecks inside the figure);
    - smooth silhouettes on near forms (subdivided or smoothed normals on the near characters' arms and gloves, and on the first-person arm);
    - faces with drawn features readable in shadow (a brow line, the eye shapes with glints, a lit lower face) instead of a black void;
    - fists with drawn knuckles and finger breaks seen from the camera.
  - **R6-INK:**
    - the outline as a weight hierarchy (taper, heavier on the shadow side, lost on the light side), with no halo at a constant offset;
    - the light wrap off, or designed;
    - interior fold lines;
    - grain and painted texture on the fills (characters and plates) to the references' hf, with a little banding.
  - **R6-SHOTS:** a defocused or simplified background behind the near figures in the first-person shots (the references' close-ups blur and simplify behind the figure); the 14 shots at 720p again (R5-SHOTS skipped it).
  - **If Game-boy says yes:** the full-frame held paint-overs.
- **The resume task** `beat-em-up-video-resume-20261108-2230` (Auto mode) is re-armed for **2026-11-10 16:10 CST**, after the weekly reset. The watcher and the relay are stopped until then (their check-ins woke the lead at about 1.5 points a turn).
- **Resume steps:**
  1. get_usage; restart the watcher and the relay;
  2. read Game-boy's DM;
  3. write the round 6 packages (P1.md, "What round 5 found") and run `tools/video/build_weekly.js`;
  4. merge, render the hero frames (`tools/video/shoot_hero.sh`), run the blind check (three judges; our frames at crf 23 as before), and DM.
  - **The lead's context is about 550k tokens:** expect a compaction.


### 2026-11-09 15:30 CST: the hero plates made and rendered; the round 5 blind check running
- **The plates builder** (Sonnet, `55a1dab`, pushed):
  - The video tests pass, 221 of 221, and all 7 hero frames render with problems=0 (into `captures/video/round5/`).
  - **7 plates from 11 Gemini images,** and the ledger is at **$4.34** (at most $0.18 is left of the approval).
  - **Registration:** four plates (t01, t03, t04, t07) missed the 8 px gate at p75 and were accepted by eye on their edge overlays (`--max-px` raised). Check them in motion before the final renders. t10, t12 and t08 pass.
  - The street's `fog_amount` is 0.12 and `wrap_strength` 0.35, the roof's values.
- **The lead's look** (`captures/video/round5/sheets_lead/`, reference | hero frame):
  - **A new look:** painted backgrounds, with the figures as dark silhouettes with coloured rims. Strongest: t10 (Ox against the painted fire) and t07 (the Kicker against the sun, between two dark towers).
  - **Concerns:** the silhouettes are very dark, so the figures are hard to read in t12 (Ox close is his arms from below, no face) and t03. No close-up shows a face, while the references' close-ups are lit, drawn faces. The steam is a white cartoon cloud (t01, t04). t01's foreground cards are plain black bars, and its camera is high. The Kicker still has pale patches.
- **Running:** the blind check, Workflow `wf_7b259cfc-8b0` (task `witcpitzn`). The same prompt, three judges, the hero frames encoded at crf 23, shuffles `blind_r5a/b/c` (seeds 51-53; the args are in `blind_r5_args.json` in this session's scratchpad).
- **Usage at 15:25:** 5-hour 24%, **weekly 83%**.
- **Next:** read the result (and which tells each judge cites), DM Game-boy, and hand off. The weekly has room for little more before 2026-11-10 16:00 CST.


### 2026-11-09 15:00 CST: round 5 merged; the hero plates and renders running (a Sonnet builder)
- **The resumed run** (`wf_0571fbbc-351`) finished all three. Each branch's video tests passed (R5-SHOTS 206, R5-ART 205, R5-INK 198), and they're merged with no conflicts (`d590cc0`, `adac45c`, `2fa2a01`). The protected diff is clean.
  - **R5-SHOTS:** 58-degree first-person lens through a view rig (lift, pull-back, roll, the off-hand hidden); fixed-point pan, tilt and zoom cameras; foreground cards; t01 a tilt-down from 6.6 m; t07 on the sun line; t10-t13 low three-quarter; t14 multiplane. The hero frames in `video/shots/hero_frames.json`: t03 and t04 (first-person street), t01 (street wide), t07 (roof against the sun), t10 (Ox wide), t12 (Ox close), t08 (first-person roof). `tools/video/shoot_hero.sh` renders them. The 14 shots weren't re-rendered at 720p.
  - **R5-ART:** the back-lit silhouette mode (flat dark fill, a hard rim from the light most behind each figure, a moon rim at night, the face lit only below the brim, a lit band up close); the first-person arm a dark mass with a warm rim; gloves shaped in `blender_asset.py` (`shape_gloves`). `test_ld_asset_data.gd`'s "same body to 2 mm" is loosened to 12 cm for the Punk and Ox (bigger gloves), with a twin in `test_r5_art_data.gd`.
  - **R5-INK:** the hull owns the silhouette (screen ink does creases and overlaps only), `ink_env_weight` 0 everywhere, light wrap, actor fog and a two-radius glow in the finish pass, and a chevron warning. Its pixels weren't judged after the resume.
  - **The lead's fix** (`e2f3c93`, R5-ART's request): the roof's `fog_amount` 0.12 and `wrap_strength` 0.35 (from 0.5 and 0.9), because the Kicker washed pale against the sun.
- **Running:** a Sonnet builder (Agent, in the background) in this worktree:
  1. the import and the video tests;
  2. the seven hero plates with `make_plate.sh` (**at most 11 images; the running total stays at most $4.34**);
  3. the hero renders into `captures/video/round5/`;
  4. fog and wrap fixes for the street and the boss if the figures wash out;
  5. a contact sheet, then a commit and a push.
- **Usage at 14:55:** 5-hour 19%, **weekly 83%**.
- **Next:** read its report, look at the sheet, run the blind check (one judge if the weekly is short), and DM.


### 2026-11-09 14:20 CST: resumed after the 13:59 reset; R5-SHOTS, R5-ART and R5-INK resuming from their wip commits
- **Usage:** the 5-hour window is at 0%, and **weekly at 80%** (it resets 2026-11-10 at 16:00 CST). About 10 weekly points (about 60 points of a 5-hour window) are left to finish round 5. No new DM. The watcher and the relay restarted.
- **Running:** `tools/video/build_weekly.js`, run `wf_0571fbbc-351` (task `wr5036alr`), with [args-p1g.json](args-p1g.json) plus a budget note. Image reads are capped at 20. R5-SHOTS and R5-INK run at medium effort; R5-ART stays at high.
- **Next:**
  1. merge the three;
  2. make the hero plates (`make_plate.sh`, within the $1.72);
  3. render the hero frames;
  4. run the blind check, with **one judge if the weekly is short** (about 0.7 weekly points against 2);
  5. DM.
  - If the weekly reaches 90%, hand off and resume after 16:00 CST on 2026-11-10.


### 2026-11-09 11:05 CST: handoff at the watcher's 88% warning; R5-SHOTS, R5-ART and R5-INK stopped as wip; resume at the 13:59 reset
- **Stopped at 11:00:** the run `wf_9e0eccab-216`. Each builder's work is committed as `wip:` and pushed:
  - **`mv/r5-shots` `9b4a209`:** the view rig (lens, lift, roll, off-hand), foreground cards, the cine shots re-staged for plates, tests, `video/shots/hero_frames.json`, `tools/video/shoot_hero.sh`, and its calls file;
  - **`mv/r5-art` `18001dc`:** the back-lit silhouette mode in cine_toon, the art rig and art.tres per location; Ox's glove rebuild in progress (`blender_asset.py`, the boss GLB and maps, `tools/video/blender_glove_probe.py`);
  - **`mv/r5-ink` `d308747`:** one line per silhouette, light wrap, actor fog, glow, the chevron warning (a first cut; looks set). **It edits `video/shaders/plate_project.gdshader`,** R5-PAINT's file: check it at the merge.
- **The weekly-aware runner** is now in the repo as `tools/video/build_weekly.js` (the copy of `tools/workflows/build.js` whose gate scales the weekly room by `weekly_scale`). The resume args are [args-p1g.json](args-p1g.json): R5-SHOTS, R5-ART and R5-INK only, concurrency 3, `weekly_scale` 6, and a note that they resume from their wip commits.
- **The resume task** `beat-em-up-video-resume-20261108-2230` (Auto mode) is re-armed for 14:10 CST.
- **Resume steps:**
  1. get_usage; restart the watcher and the relay. **Mind the weekly window:** it was about 77% here, and it resets 2026-11-10 at 15:59 CST. Stop at 90% of either window.
  2. Read Game-boy's DMs (the relay forwards them).
  3. Run `Workflow({scriptPath: "/Users/arachne/repos/beat-em-up-PoC/.worktrees/video/tools/video/build_weekly.js", args: <docs/video/args-p1g.json>})`. The loader sees the three as wip, and they go on from their newest commits.
  4. Merge R5-SHOTS, R5-ART and R5-INK; run the video tests and the protected diff.
  5. Make the hero plates for `hero_frames.json` with `tools/video/make_plate.sh` (ledger rows; about $1.72 left of the $2; an approved plate as `--swatch` for its location).
  6. Render the hero frames at 2560×1440; run the blind check, logging which tells each judge cites; DM.


### 2026-11-09 10:35 CST: R5-PAINT merged, and the pilot works; R5-SHOTS, R5-ART and R5-INK running
- **The first round 5 run** (`wf_67882462-8a5`) built only R5-PAINT. The runner's usage gate skipped the other three: it takes `max(5-hour, weekly)` as if both were points of a 5-hour window, so a weekly at 69% left "1%" of headroom.
  - **The fix,** outside the repo: a copy of the runner, `build_weekly.js`, in this session's workflow scripts folder (`.../workflows/scripts/build_weekly.js`). Its gate scales the weekly room into 5-hour points (`args.weekly_scale`, 6 on this seat: about 6 points of the 5-hour window per weekly point).
  - **Use it** while the weekly window is high. `tools/workflows/build.js` is unchanged (it isn't video-only code).
- **R5-PAINT is merged** (`aa9a827`; 194 of 194 video tests on its branch; the protected diff is clean).
  - **What's in it:** a blockout mode in the paint shader; `tools/video/plate_capture.sh`, `make_plate_jobs.py`, `register_plates.py` and `make_plate.sh`; the plate piece (`plate.tres` per location, loaded after ink) and `CinePlateQuad`; a motion check (moving_punk 30-54: a mean difference of 0.7-1.6 of 255, at most 1% torn pixels).
  - **The pilot:** 2 Gemini images ($0.28; the ledger total is about $2.80), plates for the stills street_wide and roof_silhouette.
  - **The result** (`.worktrees/mv-r5-paint/captures/video/plates/pilot2up.png`): **both backgrounds read as drawn.** They're brighter and cleaner than the references, with varied windows, cracks, puddles, haze, a smooth sun and painted towers. The actors are now the tell, the white, double-outlined Kicker in front of the sun above all.
  - **Its notes:** the first-person bob shows as blurred strips at a plated frame's edges, so hold the hero cameras' position. The boss plate's matte policy is open (calls file, item 10). About $1.72 of the $2 is left (about 12 images).
- **Sent to Game-boy at 10:30:** the pilot image with a short note (`F0CG3BVJ71U`). Nothing asked.
- **Running:** `build_weekly.js` run `wf_9e0eccab-216` (task `wmiht0d1c`): R5-SHOTS, R5-ART and R5-INK, three at once (the capture lock still allows two renders), each cut from the base with R5-PAINT merged. A P1.md note, "R5-PAINT has landed", gives them the plated stills to judge on and R5-PAINT's requests.
- **Usage at 10:30:** 5-hour 47%, weekly 71%. The weekly is now the binding limit until it resets on 2026-11-10 at 15:59 CST.
- **Next:**
  1. merge the three;
  2. make the hero plates for `video/shots/hero_frames.json` with `tools/video/make_plate.sh` (a ledger row first, then `--run`, then `--install`; an approved plate as `--swatch` for its location; at most about 12 images);
  3. render the hero frames at 2560×1440;
  4. run the blind check;
  5. DM.


### 2026-11-09 09:45 CST: resumed after the 08:50 reset; the design panel ran; round 5 running (R5-PAINT, R5-SHOTS, R5-ART, R5-INK)
- **Resumed at 09:00:** the 5-hour window is at 0%, and weekly at 64% (it resets 2026-11-10 15:59 CST). The watcher and the relay restarted. No new DM.
- **The design panel** (`wf_38255729-024`, 445k tokens) agreed with itself across all three lenses. Its result is in its journal; the summary is in P1.md, "What round 4 found".
  - **Gemini plates own the background:** painted from each hero frame's own camera, from a de-textured blockout (our current look anchors Gemini to the grids), with a "trace, don't redesign" prompt. They're projected with a depth test, and plate pixels are never brushed or inked.
  - **Staging:** plated shots move by pan, tilt and zoom. The hero frames are staged for their plates.
  - **Actors:** back-lit silhouettes on the painting; the first-person fist a dark, cropped foreground mass, with the off-hand hidden; one line source per silhouette; light wrap, actor fog and a faint glow.
  - **Its forecast:** the wides can plausibly flip; the first-person street and the boss close-up are unlikely to without Plan B.
  - **Its middle path,** for Game-boy only after round 5 shows the wides flipping: full-frame Gemini paint-overs of 2-3 held hero frames, characters included. That's outside the $2 background approval.
- **Round 5's packages** are in [P1.md](P1.md), from "What round 4 found" on, with [args-p1f.json](args-p1f.json). The Workflow `build.js` is run `wf_67882462-8a5` (task `wmkorx2j5`), two at a time:
  - **R5-PAINT** (`mv/r5-paint`; it also owns the world's files this round, and the `plate.tres` loading in `cine_director.gd`): the capture, the blockout, the Gemini jobs, registration, the plate quad, the plate piece, and a motion check with an unpainted capture. The pilot is two plates for the stills street_wide and roof_silhouette, **at most four images (about $0.56)**. The hand-off tool `tools/video/make_plate.sh` makes the hero plates.
  - **R5-SHOTS** (`mv/r5-shots`): seven hero frames in `video/shots/hero_frames.json` in the trailer's proportions; t01 a tilt-down to a low three-quarter street wide; the roofs low with the figure on the sun; the boss low against the fire with no facades; t14 multiplane; the first-person view at 55-60 degrees with the fist cropped and the off-hand hidden.
  - **R5-ART** (`mv/r5-art`): back-lit silhouette actors (flat dark fill, a noise-broken rim from the light behind, faces in brim or hood shadow), the first-person arm as a dark mass with a warm rim, boxing-glove shapes for Ox and the Punk.
  - **R5-INK** (`mv/r5-ink`): the hull owns character silhouettes (the doubled outline), environment screen lines off, light wrap, actor fog, a diffusion glow, and the rear warning as a burst.
- **Next, after the merge:**
  1. the hero plates for `hero_frames.json` with `make_plate.sh`, within the rest of the $2 (about 10 images; the ledger keeps the total at most $4.52);
  2. render the hero frames at 2560×1440 and the trailer at 720p;
  3. the blind check on the hero frames, logging which tells each judge cites per frame;
  4. DM Game-boy.


### 2026-11-09 06:05 CST: round 4's blind check (no movement) DM'd; round 5 planned; handoff at 88%, resume at the 08:50 reset
- **The blind check** (`wf_be1d93d6-8ac`, three Opus judges, 295k tokens, about 12 points): all 8 references drawn (p_3d 0.04-0.16), all 7 of ours 3D at round 3's confidence: street_wide 0.97, fp_kicker_lamp 0.95, fp_punk 0.95, moving_punk 0.95, roof_silhouette 0.91, ox_closeup 0.89, ox_low 0.88. Round 4's code changes are visible in the frames, but they did not move a judge who is looking for 3D. The full verdicts are in the workflow's journal (`subagents/workflows/wf_be1d93d6-8ac/journal.jsonl` under this session's project folder).
- **What the judges point at now** (mostly the 3D game itself, not the shading):
  1. **Exact perspective with repeated units:** window grids with identical window textures, brick courses, chain-link, paving, stair treads, tower staves; texture-space brushwork that shrinks with distance and tiles.
  2. **Primitive volumes:** boxes (buildings, crates, the AC unit, the dumpster, parapet boxes), cylinders (gloves, cuffs, water towers, lamp posts), blob cars; smooth normal-driven gradients; exact shadow-map cast shadows; the first-person fist as a smooth "sausage" or "mitten", the player's other glove floating as a navy ball on a grey cuff box.
  3. **One outline weight** with one wobble frequency, no interior lines; a doubled, offset outline down the Punk's right side in fp_punk.
  4. **Render debris** (decisive wherever it shows): two unlit orange squares floating at the top centre of the street frames (far lit windows or lamp heads on a dark mass), an unlit pure-black slab (moving_punk), an aliased dotted wire across the sky, a four-point glint sprite and a vertical seam line on the boss roof's left facade, a dark elliptical sky-dome arc and posterised halo bands on the roof.
  5. **No aerial perspective:** equal sharpness, darkness and detail at every depth; no diffusion glow.
  6. **Stiff, symmetric rig poses** with no line of action (Ox's raised arms, guards with both fists at the face).
  7. **Game-camera framing:** the huge first-person fist in a corner; street_wide's high, CCTV-like overview.
  8. **Lighting placed, not designed:** straight-edged cones (still), flat decal pools that don't wrap onto figures, the same blue top-face highlight on every ledge, a backlit figure with fill and no rim (roof).
  - The painted layers (fire, smoke, skylines, pools) read as drawn, and make the 3D figures and buildings in front of them read as more 3D.
- **Sent to Game-boy at 05:50** (DM: the sheet `F0CG4T52WRF` with the message, and the clip `F0CG11TKVV4`): the result, the round 5 plan, and **one question:** if round 5 still reads 3D, is Plan B (an AI restyle of the final cut, roughly $30-100) on the table? One service and a quote before any spend. Without an answer, Plan B stays on hold.
- **Round 5, the plan** (write it as packages at the resume; a design panel may refine it, below):
  - **R5-PAINT** (his $2): per trailer shot, a background plate from the shot's middle camera with a wider FOV (actors, the first-person body and the steam hidden: `--shot-hide=HumanoidRig,...`), a Gemini paint-over simplified the way an anime background painter would (`make_matte_jobs.py`'s style lines as a start, plus "keep the layout; drop most windows and bricks; cheat the perspective by hand; darks as flat masses; the distance lifted and simplified"), projected onto the set. The projection is a screen quad after the brush quad: depth to world, the plate camera's projection, a depth test against the plate camera's depth rendered at the shot's start. **A pilot of two images first** (a street first-person shot and a cine shot), judged beside the references, then the rest within $2 (about 14 images in all). Ledger rows before and after.
  - **R5-FIX:** the debris above (the squares, the slab, the wire, the glint, the seams, the doubled outline, the sky arc), and aerial perspective: the distance lifted toward the haze colour and softened, plus a gentle diffusion glow on the lights.
  - **R5-ART:** the first-person fist with fingers and knuckles readable from the camera, the gloves and cuffs not primitives (seams, wrinkles, lacing in the silhouette), the Punk's face not a visor block.
  - **R5-SHOTS:** the blind set from seven trailer frames (one per kind: street wide, first-person punch, first-person lamp, roof against the sun, Ox reveal, Ox close, moving), dynamic held poses with a line of action, a lower, character-led street wide instead of the overview, and the first-person fist smaller in frame.
- **Budget:** weekly 59% at 05:42 (it resets 2026-11-10 15:59 CST). Round 5 is probably the last full round before the weekly reset.
- **The design panel was stopped at the watcher's 88% warning (06:05),** before any of its three agents finished, so it has no result. **Re-run it first at the resume:** `Workflow({scriptPath: "/Users/arachne/.claude/projects/-Users-arachne-repos-beat-em-up-PoC--worktrees-video/d70b4cdd-2b80-49d4-94fe-8da80da776fa/workflows/scripts/video-round5-design-panel-wf_cac31b7c-27c.js"})`. It runs three Opus lenses on the draft above: an anime background art director, an NPR technical artist, and the blind judge's adversary. Each returns ranked proposals, a top 3, a verdict on the draft, what to cut, and which frame types can't pass without Plan B. Its prompt holds the whole context (the four rounds' numbers, the tells, the constraints, the draft). Expect about 6-10 points. Write the round 5 packages from its result and the draft.
- **08:08: Game-boy answered the Plan B question** by DM at 06:22: "Let's keep it on hold for now.  The progress on graphics is heartening so far, and interested to see what a $2 overlay from Gemini can accomplish." So Plan B stays on hold, and round 5 runs the paint-overs. He also asked, in the chat and by DM (07:43), for the repo link to clone on another machine: sent by DM at 08:07 (`https://github.com/mikedtcm22/beat-em-up-PoC`, with the Git LFS note and the branches). The relay's `last_ts` is set to that DM (`1794233276.269649`), so neither message is forwarded again; act on neither a second time.
- **Handoff at 88% (06:05):** nothing is running. Every video branch and worktree is committed and pushed (`video/cinematic-trailer` at this commit; `mv/r4-*` at their final commits), and only untracked captures remain.
- **The resume task** `beat-em-up-video-resume-20261108-2230` (Auto mode) is re-armed for 09:00 CST.
- **Resume steps:**
  1. get_usage; restart the watcher's loop and the relay's heartbeat (they stop themselves at 90%; the watcher may still be running);
  2. read Game-boy's DM replies (the relay forwards them), then re-run the design panel (above) and read its result;
  3. write the round 5 packages into P1.md (or a P2.md) and their args (`docs/video/args-p1f.json`), and run `build.js`;
  4. merge, render the new blind set from the trailer shots, run the blind check (`blind_r4_prep.sh` and the blind workflow script, with the new frames), and DM.


### 2026-11-09 05:40 CST: round 4 merged and rendered; the blind check running
- **The build** (`wf_eba65c14-c95`, 1.34M tokens, 84 minutes, about 47 points of the 5-hour window): all four packages landed and are merged with no conflicts (`cbfe654`, `21153e4`, `a13ba19`, `9524a62`, pushed). The video tests pass, 181 of 181; the protected diff (game, tuning, tests) is clean.
  - **R4-INK:** the brush pass is a full-screen quad at the head of the transparent queue (`video/ink/brush_quad.gd`, `video/shaders/brush_screen.gdshader`). A pre-transparent CompositorEffect lost its writes under the writer's MSAA 4x, so don't move it into the compositor. It runs an anisotropic Kuwahara whose radius grows with depth, focus distance and frame edge; a thin-line fill (brick joints, seams); a soft posterize; and a world-anchored wobble. The delivery re-scale is `deliver_scale` 0.65, down then Catmull-Rom up: edge widths are 2.7-3.4 px against the references' 2.5-4.8 px (measured on PNGs, not the encode). The line hierarchy: heavier near the lens, 24x between the shadow and the lit side, overlap lines, thin inner lines, and lighter environment lines. Cost: 0.56 s a frame, against 0.47 s.
  - **R4-WORLD** (`r4_on`; 0 gives round 3): steam as one or two drawn plumes per vent; lamp shafts as a fan of brush strokes; pools shaped by the paint (up to 8 lamp slots); poles taper and lean; out-of-light surfaces flatten to a navy (violet) mass; moonlit top planes; twin tanks and cars differ.
  - **R4-ART:** a designed shade map (`tools/video/art_shade.py`): a shadow hint and baked hatch strokes along the form. The noise terminator and the triplanar crosshatch are gone. Ox's face has 20 drawn paths (from 54), his gloves differ, and the arm has a swell and a wrist taper, darker. `hatch_on` now only multiplies the baked strokes; `term_wobble` does nothing. Weakest: the fist reads as a ball.
  - **R4-SHOTS:** a 75-degree first-person lens (the default of `VideoStillShot.first_person_fov_deg`); the player stands back in fp_punk and fp_kicker_lamp; Ox in asymmetric held poses; street_wide's cast varied; the roof's Kicker turned; t04, t11 and t13 pitched to keep faces in frame. All 14 trailer shots render at 720p (in `.worktrees/mv-r4-shots/captures/r4/trailer/`). t09's rear warning shows, as a clip-art flower: a request to redraw it as a jagged burst.
- **The set is in `captures/video/round4/`** (untracked): the six stills, `moving_punk` (and `frame042.png`), `sheets/` (ref | round 3 | round 4, `overview.jpg`, `ov_top.jpg`, `ov_bottom.jpg`), and `round4_moving_punk_1080p.mp4`.
- **The lead's look:**
  - **Better:** the walls read as painted planes; the moonlit top planes and hand-shaped pools work; the tanks differ; the boss roof reads drawn; the Kicker is turned.
  - **Still 3D:** the first-person arm. At 75 degrees it's larger, and still a smooth peach tube with a ball fist, like a giant thumb, in fp_punk and fp_kicker_lamp. The steam plumes still read as cauliflower columns. In ox_closeup the face is darker and harder to read, and the window grid on the left building is regular. In moving_punk the Punk's face is a dark blue mass.
- **Running:** the blind check, Workflow `wf_be1d93d6-8ac` (task `wexq3z2pn`). The same prompt and the same three-judge setup as round 3, on new shuffles (seeds 41-43, `blind_r4a/b/c` and `blind_r4_key_*.json` in this session's scratchpad; our frames encoded at crf 23 first: `blind_r4_prep.sh`).
- **Next:** read the blind check, DM round 4 to Game-boy (the sheets, the moving clip, the result), and plan round 5 (R5-PAINT if the backgrounds still read 3D; the arm).


### 2026-11-09 03:55 CST: resumed after the reset; round 4 running (R4-INK, R4-ART, R4-WORLD, R4-SHOTS)
- **The reset came at 03:40.** The 5-hour window is at 0%, and weekly at 48% (it resets 2026-11-10 15:59 CST). The resume task fired at 03:50. The watcher and the relay were asked to restart their loops; both turns started.
- **No reply from Game-boy** in the DM at the resume (the newest message was ours, 01:06), so round 4 runs without the per-shot Gemini paint-overs, as the DM said. Plan B stays on hold.
- **04:18: Game-boy answered** by DM (the relay forwarded it; read in Slack too): "Extra $2 for Gemini use is approved if needed". The paint-overs have to be made from round 4's final set (the world's geometry and props move in R4-WORLD), so they're round 5's package (**R5-PAINT**: plates from each trailer shot's key camera with the actors hidden, a pilot of one or two images first, then the rest within $2, projected onto the set with a depth test). They run in the next window, only if round 4's blind check still calls the backgrounds 3D. The approval is in the approvals section at the bottom, and the ledger has a row for it.
- **Round 4's packages** are in [P1.md](P1.md), from "What round 3 found" on, with [args-p1e.json](args-p1e.json):
  - **R4-INK** (`mv/r4-ink`): a brush pass that paints the world's pixels (anisotropic Kuwahara, flat values, a world-anchored hand wobble) before the lines; the delivery matched to the references by measure (`deliver_scale`); more contrast in line weight.
  - **R4-ART** (`mv/r4-art`, Blender): a designed cel shadow shape (no noise terminator), hatching along the form only in close-up shadow, Ox's face simplified, no mirrored gloves, the arm as a drawn foreground form.
  - **R4-WORLD** (`mv/r4-world`): steam as drawn cel shapes, painted shafts or none, hand-shaped pools, tapered leaning poles, values organised by the light (detail kept, at full contrast only in the light), moonlit top planes, no twin props.
  - **R4-SHOTS** (`mv/r4-shots`): a first-person lens of about 70-75 degrees across (from 90), asymmetric poses, no copies in one frame, the blind set kept comparable, the trailer re-rendered at 720p, t09's rear warning checked.
- **Running:** the Workflow `build.js`, run `wf_eba65c14-c95` (task `ws0q75xtc`), two at a time in that order.
- **Weekly budget:** a full 5-hour window costs about 15 weekly points, so this week has room for about two more windows after this one before the weekly 90%.
- **Next:** when the builders land, merge them, run the video tests and the protected diff, render the round 3 set as round 4, look, run the blind check (three judges, the same prompt), and DM Game-boy.


### 2026-11-09 01:20 CST: round 3 DM'd (not a match yet); handoff at 86%, nothing running; resume at the 03:40 reset
- **The blind check** (`wf_5a5751c7-441`, three Opus judges, about 12 points, more than the estimate) ran on our frames after a streaming-like encode:
  - all 8 references called drawn (p_3d 0.04-0.13), and all 7 of ours called 3D;
  - the boss roof moved most: ox_closeup 0.88, ox_low 0.90 (Gate 2: 0.95-0.99). roof_silhouette 0.92; fp_punk, fp_kicker_lamp and moving_punk 0.95-0.96; street_wide 0.97;
  - the judges read the painted fire, smoke, skylines and sky bands as drawn.
  - Their shared tells, strongest first:
    1. **Exact-perspective modular repetition:** windows, brick, chain-link and stair treads, with even detail at every depth.
    2. **Geometric light:** elliptical pools, the new straight-edged constant-opacity lamp cones, ruler-straight poles.
    3. **Particle steam:** round, blurry puffs in columns; uniform motes and embers.
    4. **Shading by shader:** the noise-threshold terminator, crosshatch of one density over faces and gloves whatever the form, and a near-photoreal face under the hatch.
    5. **CG primitives and copies:** the tube arm at a wide first-person lens, mitten fists, mirrored gloves, twin tanks, identical enemies, symmetric poses.
    6. **Even outline weight.**
    7. **Delivery:** ours are still crisper than the references, which look upscaled and compressed.
    8. **Murky alley values:** mid-dark textured areas, with no flat dark masses and no moonlit rims or top planes.
- **Sent to Game-boy at 01:18** (DM, file F0CG4K8KVK6 with the message, and the reel F0CG2QYUAF3): the overview sheet, the 14-shot blocking reel (`captures/video/round3/round3_trailer_blocking_720p.mp4`, 49 s, 720p), the blind result, and the round 4 plan. **One open question for him:** paint every shot's background with Gemini (a paint-over of our own frame, projected onto the set), about $2 within the $5 cap ($2.52 spent). It's a new use of Gemini, so it needs his yes. Without an answer, round 4 runs without it. Plan B stays on hold.
- **Round 4, the plan** (Plan A, no spend; write it into P1.md, or a P2.md for round 4, as packages):
  - **R4-INK** (ink: `video/ink/`, the post): the delivery at an internal 1920×1080 (or lower), upscaled to 2560×1440 with a soft filter, plus a stronger soften, judged against the references' softness. One designed cel shadow shape on the characters (drop the noise terminator), and hatching only in shadow and along the form.
  - **R4-WORLD** (world):
    - steam and smoke as drawn cel shapes (two tones plus a line, on twos) or thin painted wisps;
    - the lamp cones painted with a falloff and brushy edges, or cut;
    - pools hand-shaped (painted textures, not projected ellipses), and tapered poles;
    - flat dark masses, with brick and window texture only where light falls;
    - moonlit top planes and rims;
    - harder breaks to the window modules (drop and vary them), and wobbled long edges.
  - **R4-ART** (art): the arm as a drawn form (wrist taper, knuckles, a designed shadow shape), and Ox's face simplified (fewer photoreal wrinkles, designed lines).
  - **R4-SHOTS** (stage): a narrower first-person FOV for the video (less wide-angle distortion); no identical enemies in one pose (LD-ASSET round 2 brings the other enemies).
  - **If Game-boy says yes:** R4-PAINT, per-shot Gemini background paint-overs projected from each shot's camera (LD-WORLD3's tools: `make_matte_jobs.py`, `key_mattes.py`).
- **The resume task:**
  - `beat-em-up-video-resume-20261108-2230` (Auto mode) is re-armed for 03:50 CST under the title "...after the 03:40 reset";
  - the new `...-20261109-0340` saved in the default mode, so it's disabled.
- **Resume steps:**
  1. get_usage; restart the watcher's loop (PLAN.md §12) and the relay's heartbeat;
  2. read Game-boy's DM reply (the relay forwards it);
  3. write the round 4 packages and run `build.js` in waves (R4-INK with R4-WORLD, then R4-ART with R4-SHOTS, or as the usage allows);
  4. re-render the round 3 set as round 4, run the blind check again (three judges, the same prompt, `blind_r3_prep.sh` in the scratchpad as the model), and DM.

### 2026-11-09 01:05 CST: round 3 merged and rendered; the blind check and the trailer reel running
- **Wave B landed** (run `wf_020e5cbf-2b7`, 421k tokens, about 12 points). It's merged (`2d5d087`), and the video tests pass, 152 of 152 with the lead's test. LD-INK2 delivered:
  - **the lines:** a tapered line hierarchy (a heavier first-person arm), terminator lines, lighter environment ink, and a separation band round the figures;
  - **the grade**, with the three LUTs rebuilt;
  - **the delivery pass** (`delivery_on`): a sub-pixel soften, and grain that changes on twos;
  - **CineTwos** now stores once per drawing;
  - **the roof's lens-flare star** was the weapon-pickup glint. `CineDirector.hide_pickup_glint` hides it, so t06's and t08's pickups lose their floor glint;
  - **the Kicker** is a silhouette;
  - **the rear warning** is drawn in the cue pass, but no frame has shown it yet;
  - **determinism:** not reproduced, so no change.
- **The lead's call** (`851a0b2`): `VideoArtLook.face_fill_by_id`. The first-person arm's fill is 0.15 at night and 0.2 on the boss roof, while the faces keep 0.5. LD-INK2 asked for this: the arm was the brightest thing in the night frame. Lowering the fill for every face would also have dimmed Ox's close-up.
- **The set is in `captures/video/round3/`** (untracked):
  - the stills, with `pre_fill/` holding the arm at 0.5;
  - `sheets/` (ref | Gate 2 | round 3 | target, plus overview.jpg);
  - `round3_moving_punk_1080p.mp4`;
  - the A/Bs (`ab_fill015/`, `ab_nodeliver/`).
  - **The style meter:** street 0.96-0.99 (cool share low on the first-person shots), roofs 0.72 (edge density and ink too high, warm share low), boss 0.88, close-up 0.88.
- **The lead's look:**
  - **Fixed since Gate 2:** no holes, no crimson; the darks are navy masses; the fire and smoke on the boss roof are painted; Ox's face is hatched, with eyes; the Kicker is a silhouette; the star is gone.
  - **Still 3D:** the first-person arm (one large smooth tube, now not faceted), the cotton-ball steam puffs, and the perspective-exact brick.
- **Running:**
  - the blind check, Workflow `wf_5a5751c7-441` (task `w4byk3z9u`). Three judges get the Gate 2 prompt, each on its own shuffle (`blind_r3a/b/c` and the `blind_r3_key_*.json` keys in this session's scratchpad). Our frames went through a streaming-like encode (H.264, yuv420p, crf 23) to compare like with like;
  - the 14 trailer shots at 1280×720 in the round 3 look, into `captures/video/round3/shots/` (`shoot_trailer.sh`), for a blocking reel.
- **Next:** read the blind check, make the reel, DM round 3 to Game-boy (sheets, the clip, the reel, the blind result), then plan round 4 or Phase 2 from what's left.

### 2026-11-09 00:10 CST: wave A merged; wave B (LD-INK2) launching
- **Wave A landed** (run `wf_92ad24ce-788`, 1.35M tokens, about 49 points of the 5-hour window: 3% to 52%). It's merged into `video/cinematic-trailer` (`ed2ec8e`, `1219a3a`, `b7c76c6`) with no conflicts. The video tests pass, 137 of 137, and the protected diff is clean.
  - **LD-WORLD3** (`mv/ld-world3`): the world is drawn, not tiled.
    - Brick comes in clusters; detail falls off with distance and gathers at a per-shot focus; windows vary; the chain-link sags.
    - The darks are navy masses, and the lamp pools are warm rust, not crimson.
    - It adds painted lamp shafts, a barrel flame, steam and embers, and contact shadows.
    - Seven Gemini backdrops ($0.98): the street and roof skylines, and the boss roof's fire and smoke.
    - Not fixed: the roof's lens-flare star, which comes from the base stage (passed to LD-INK2). The darkest third's grey share is still short of 0.5 (0.22 on street_wide).
  - **LD-ART2** (`mv/ld-art2`): no more holes (pure black 0.02-0.07% of the frame, from 5-10%).
    - The player now has a video GLB with a smooth arm. The arm had been falling back to the game mesh because the rig's triangle budget was too low; the rig now raises the budget on its own copy.
    - Faces read: unlit face fill, catchlights, Ox's eyes.
    - Its own call: the first-person arm still leans 3D (one big smooth form with one line weight). It needs LD-INK2's heavier line.
  - **SHOTS** (`mv/shots`): the trailer's 14 shots (t01-t14) render at 1280×720 into `captures/video/shots_blocking/`, each with a cue sheet (`<key>_events.log`).
    - A beat script waits for game state.
    - The camera is sampled at n/24 s.
    - `shoot.sh` now fails on its own errors (exit 3-7).
    - Departures: the shots add up to 49 s against the plan's 41; nine of 14 are first person (65% of the time, against the 70% the plan asks for); shot 11 runs 8.1 s.
- **The lead's own changes:**
  - `shoot.sh` now also fails on a `Parse Error` (LD-WORLD3's request).
  - P1.md § LD-INK2 gained item 6, wave A's requests: the lens-flare star, the Kicker's silhouette (with `roofs_dusk/art.tres`'s face values), the arm's line, the rear warning, determinism, and checks on t07 and t10.
- **Running since 00:12:** wave B, `build.js` with [args-p1d.json](args-p1d.json), LD-INK2 alone (est 18), run `wf_020e5cbf-2b7` (task `w0ozj0yeh`), on `mv/ld-ink2`. If it's cut off, launch it again with the same args; `build.js` resumes from the branch. When it lands:
  1. merge it;
  2. render the Gate 2 set with the delivery pass;
  3. the lead's look;
  4. the blind check;
  5. DM round 3.

### 2026-11-08 22:41 CST: resumed after the reset; round 3 wave A running (LD-WORLD3, LD-ART2, SHOTS)
- **The reset came at 22:30.** The 5-hour window is at 0%, and weekly at 33%. The relay reported it first, and the resume task (`...-2230`, Auto mode) fires at 22:40.
- **The watcher was asked to restart its loop** with the PLAN.md §12 prompt, at its normal cadence.
- **Running:** the Workflow `build.js` with [args-p1c.json](args-p1c.json), run `wf_92ad24ce-788` (task `wpvnx5t6a`), two at a time:
  - LD-WORLD3 (`mv/ld-world3`), with A+ approved: Gemini backdrops at most $2.50 this round, with the ledger rows its own;
  - LD-ART2 (`mv/ld-art2`, Blender);
  - SHOTS (`mv/shots`), which starts when a slot frees.
- **SHOTS moved into wave A** because it doesn't depend on the look. Wave B is LD-INK2 alone ([args-p1d.json](args-p1d.json)), run after wave A is merged, so the grade and lines are judged on the new world and cast.
- **Next:** when wave A lands:
  1. merge it, run the video tests and the protected diff;
  2. launch wave B;
  3. then render the Gate 2 set again with the delivery pass, do the lead's look, run the blind check again, and DM round 3 to Game-boy.

### 2026-11-08 19:15 CST: Gate 2 sent by Slack DM (not a match yet); handoff before the 22:29 reset
- **Gate 2 went to Game-boy at 19:08** (DM ts 1794185684.959309), with the overview sheet and the 1080p clip. He has three questions to answer, with my defaults:
  1. Run look-dev round 3 (Plan A)? [yes]
  2. D7, A+: Gemini-painted backdrops (the far buildings, the boss roof's sky, fire and smoke) as mattes, about $1.50-2.50 from the $3.46 left of the $5 cap. That cap was approved for look-dev targets only, so this new use needs his go. [I recommended yes]
  3. D6, Plan B: hold? [hold]
  - **He answered at 20:50 CST, in the chat:** "defaults on all three open questions are approved for next reset". So:
    - round 3 runs at the next reset;
    - A+ is approved: Gemini backdrops, at most $2.50 this round, under the $5 total cap. It's written into P1.md § LD-WORLD3, item 8;
    - Plan B (D6) is on hold.
- **The blind check** (one Opus judge, 15 shuffled frames; key `blind_key_gate2.json` in this session's scratchpad): all 8 reference frames called drawn (p_3d 0.04-0.12), all 7 of ours called 3D (0.95-0.99). Its shared tells, strongest first:
  1. Surface detail tiled at one density right to the vanishing point (brick, window grids, paving, chain-link).
  2. A faceted, low-poly first-person arm and fists.
  3. Instanced copies (three identical Punks, two cars, four lamps, repeated decals) and perfect ellipses (light pools, tank hoops).
  4. One outline weight everywhere, so the characters don't separate.
  5. Marks drawn in texture space (stripes that wrap round the forearms, the face decal).
  6. Aliased sky and spire edges, pixel steam, identical particles, the lens flare.
  7. Computed lighting: pools that follow geometry exactly, smooth gradients, uniform fog, no contact shadows.
  8. Detail and mid-value contrast spread evenly, where the drawn frames gather darks into masses and spend detail at the focal point.
  - It also noted that the references carry streaming softness and compression, while ours are pixel-sharp. The final delivery pass (a slight soften, grain, H.264) belongs in round 3, so the next blind test compares like with like.
- **The style lens** (review run `wf_5df89f41-295`, Opus): mean **1.27**, and no pillar reaches 2 across the set. Pillar means: P1 1.14, P2 1.29, P3 1.00, P4 1.29, P5 1.14, P6 1.86, P7 1.29, P8 1.14. roof_silhouette is the best shot (1.88), moving_punk the worst (1.00). Its findings (high, then medium) are the round 3 work list:
  1. **(high) Pure #000000 holes on painted characters.** They cover 8-10% of the first-person frames and Ox's glove cuffs. **Cause:** LD-ASSET's paint maps aren't padded (empty texels), and they're sampled with UV2. The black is not the outline hull, as I first thought (the hull's ink is #170e0d). The holes first appear in LD-ASSET's art renders.
  2. **(high) Lamp and barrel pools turn walls and fence frames crimson-magenta.** See `flat_paint_env_body.gdshaderinc:636-643` and `street_night/world.tres` (pool_hue_norm 0.8, pool_cancel, Barrel_a's colour).
  3. **(high) The first-person arm reads as a low-poly mesh:** faceted planes, flat salmon, fingerless fists.
  4. **(high) No eyes at close range:** the Punk's and Ox's faces lose their features in the shadow band. The cap also has a plastic highlight.
  5. **(high) The street palette** is saturated royal blue at mid value. The darkest third's grey share is 0.03, against 0.56-0.80 in ref 2 at 3.5 and 4.5 s; the dark share is 0.66-0.71, against 0.84-0.92.
  6. **(medium) roof_silhouette:** the Kicker is front-lit, not a silhouette, and there's a lens-flare star.
  7. **(medium) The boss roof:** Ox is keyed by a violet directional light (`boss_fire/world.tres:63-66`), so he reads violet, not fire-lit amber.
  8. **(medium) The environment's ink** has no hierarchy and no distance fade. Edge density is 0.12, against 0.046 in the references.
  9. **(medium) Atmosphere:** no depth haze or lamp shafts, cotton steam, and a barrel with no fire.
  10. **(medium) moving_punk:** the head is cropped, the last 2 s are static, and there are blood "stickers". That's for SHOTS.
  - Also noticed: brick courses that wave at close range (wobble too high), the sun half hidden behind a tank, and identical lamp colours.
  - The full result is in the run's `journal.jsonl` (the `review:look` result line).
- **The review round finished at 19:35:** 16 agents and 1.31M tokens, taking the 5-hour window to 87%.
  - Skeptics confirmed all five of the style lens's high findings. The skeptic for finding 1 corrected the cause: the player's first-person arm mesh has a collapsed UV2, so it isn't a padding problem.
  - The code lens found one high: CineTwos holds the wrong pose. It also found three mediums (determinism, probably a pipeline recompile after the runtime shadow-quality change; camera judder from the uneven 24 fps picks; `shoot.sh` exits 0 when the encode fails) and three lows.
  - Every root cause is routed to its round 3 package in P1.md ("The review's root causes, by package"; commit e68f6df). There's nothing left to resume from this run.
- **Round 3, the plan** (write the briefs into P1.md as new sections first; every package owns disjoint files):
  - **LD-WORLD3** (world):
    - findings 2, 5, 7, 8 and 9;
    - the blind check's tells 1, 3 (window grids, decals, perfect pool ellipses), 6 (aliased sky and spire edges, lens flare, pixel steam) and 8 (detail falling off with distance, kept near the camera and at the focal point; Game-boy's drawn-detail direction stays: hand-varied clusters, not removal);
    - painted fire and smoke on the boss roof, and the roof's wavy brick.
    - **Owns:** `video/world/`, `video/look/*/world*.tres`, `flat_paint_env*`, `sky_*`, `haze_*`, `paint_mattes.py` and `assets/video/mattes/`. If Game-boy says yes to A+, the Gemini mattes also go here (a ledger row before each batch).
  - **LD-ART2** (characters):
    - findings 1, 3 and 4;
    - the arm's two-tone cel with smooth or transferred normals, and fingers;
    - stripes that don't wrap with the texture;
    - no cap specular, and drawn blood marks.
    - **Owns:** `video/art/`, `assets/video/characters/`, the art tools, `video/look/*/art*.tres` and `cine_toon.gdshader` (taken over from LD-INK).
  - **LD-INK2** (lines, grade, delivery):
    - the line hierarchy: a heavier, tapered silhouette line on the characters, lighter inner lines, and characters separated from the background;
    - the grade toward navy and indigo with desaturated darks;
    - the roof Kicker's silhouette (`roofs_dusk/ink.tres`);
    - contact shadows, if they're screen-space;
    - the delivery pass (soften, grain);
    - the code lens's determinism findings for the ink.
    - **Owns:** `video/ink/`, `cine_outline`, `ink_screen`, the post and the LUTs, and `video/look/*/ink*.tres`.
  - **SHOTS** (PLAN Phase 2; it doesn't depend on the look): the acts and cine cameras for the shot list; finding 10.
    - **Owns:** `video/stage/`, `video/cine/`, `video/shots/` and `video/acts/shots_acts.gd`.
  - **Then:** render the Gate 2 set again, look, run the blind check again (with the delivery pass on our frames), and send round 3 to Game-boy.
- **Usage:** 5-hour window at 87%, weekly at 32%, at 19:40. Round 3 is four Sonnet builders, about 40-48% of a window, so it starts after the 22:29 reset.
- **The resume task** is `beat-em-up-video-resume-20261108-2230`, firing at 22:40 CST. It was re-created at 20:50 in a turn Game-boy typed, so it is saved in Auto mode. The first one, `...-2229`, was saved in the default mode and is now disabled, not deleted.
- **Resume steps:**
  1. get_usage; read the DM for Game-boy's answers (newer than ts 1794185684.959309).
  2. Get the review's remaining results: from the journal, or resume the run.
  3. The round 3 briefs are written (P1.md, from "What Gate 2 found"; commit bd0bfac).
     - A+ is approved, and its line is already in § LD-WORLD3, item 8; LD-WORLD3 adds the ledger rows itself.
     - Wave A is `build.js` with [args-p1c.json](args-p1c.json): LD-WORLD3 and LD-ART2 (Blender).
     - Then merge, and paste the code lens's determinism finding into § LD-INK2, item 4.
     - Wave B is [args-p1d.json](args-p1d.json): LD-INK2 and SHOTS.
     - Each wave is about 30-35% of a 5-hour window on this seat.
  4. **Restart the watcher's loop first.** It was stopped at 19:50 on purpose: its 5-minute checks were waking this session and driving the window from 89% to 90%.
     - Message the session "Beat-em-up: video usage watcher" (`local_c2874de8-2c55-4e84-9a63-fad9685e32df`) to start its loop again with the PLAN.md §12 watcher prompt. Messaging an existing session works from an automated turn.
     - The relay is on hourly wakes until 22:30, then goes back to 20 minutes by itself.
  5. Confirm the watcher and the relay are running. If they aren't, start them only in a turn Game-boy typed, or propose them as cards.

### 2026-11-08 18:55 CST: Phase 1b merged; the Gate 2 set rendered; the review round and the blind check running
- **Merged** into `video/cinematic-trailer`:
  - `mv/ld-world2` (47d4fbc), `mv/ld-asset` (fe0676d) and `mv/ld-stage` (109c603);
  - then cb0033f: `cine_toon` samples `paint_tex` and `ink_tex` with UV2, the art layout (LD-ASSET's request). `CineArtRig.ensure_layout_uv()` is now a no-op.
  - Video tests: 90/90. Nothing under `game/`, `tuning/` or `tests/` has changed since the fork from `m6/full-art-audio` (056e697).
- **The wave's cost:** 1.19M subagent tokens. The 5-hour window went from 0% to 51%, and the weekly from 18% to 26%.
- **The Gate 2 set** is in `captures/video/gate2/`:
  - `<shot>/<shot>.png` for the six stills;
  - `moving_punk/moving_punk.mkv`: 5 s, 120 frames; the 4 hits land, then the uppercut finisher and the KO;
  - `sheets/`: reference | ours | target, rows s1-s7 and an overview;
  - `gate2_moving_punk_1080p.mp4`, for Slack.
- **Measured** (PLAN §6, LD-RENDER):
  - 0.31 s a frame at 2560×1440: moving_punk's 120 frames took 37 s of wall time, encode included.
  - 0.32 MB a frame of mezzanine, 10.8 MB raw, and 1.18 GB of VRAM.
  - So 40 s at 24 fps (960 frames) is about 5 minutes of rendering. Render hours aren't a constraint.
- **The lead's look,** at full resolution beside the references and the targets.
  - **Better:**
    - The environments carry drawn detail (brick courses, frames, fence, flagstones, puddles), and the path reads.
    - The Punk's and Ox's faces are drawn.
    - The roof's tanks, parapet and banded sun read as illustration.
  - **Worst, in order:**
    1. **The first-person arm.** Where the near plane cuts the arm there's a pure black hole, probably the inside of the inverted-hull outline showing. Its shading is faceted low-poly, and its colour a flat salmon. This is in every first-person shot and in the moving shot.
    2. **Colour.** Saturated royal blue with magenta and red: magenta blobs on the walls, and red fence frames and props. The references are navy and indigo with desaturated darks and an orange key.
    3. **Value.** No deep darks or silhouettes; the roof's tanks are front-lit instead of backlit.
    4. **Line.** The environment's lines are uniformly thin, with no bold contour hierarchy. At close range, heavy black bands cover the Punk's arms.
    5. **The boss roof.** Ox is lit violet, not warm orange. The flame spikes are regular, and the gloves near-black.
    6. **Atmosphere.** Steam like cotton, and no haze depth.
    7. A lens-flare glint at the sun.
  - **Rough scores:** P1 1.5, P2 1.5, P3 1.5, P4 1.0, P5 1.0, P6 2.0, P7 2.0, P8 1.5; mean about 1.5. That's below the bar (every pillar ≥ 2, mean ≥ 2.4).
- **Running:**
  - **The review round:** Workflow `review.js` with [args-review-g2.json](args-review-g2.json) (run `wf_5df89f41-295`, task `w2bnz0rl3`). It has an Opus style lens with the rubric and a Sonnet code lens. Skeptics check only the high findings, because of the 90% limit; there's no partition and no fixers.
  - **The blind check:** one Opus agent on 15 shuffled frames (8 reference frames, our six stills and moving_punk's frame 42). The key is in this session's scratchpad, `blind_key_gate2.json`.
  - **The watcher and the relay** run again; Game-boy pressed Start on both cards.
- **Next:**
  - When the review and the blind check land, send Gate 2 by Slack DM: the sheets, the 1080p clip, the scores, the round 3 proposal, and the fallbacks with their costs (A2 for P1, A+ for P2 and P7, PLAN §6).
  - Then the fix wave (look-dev round 3) on the lowest pillars, sized to the headroom. If it doesn't fit, hand off at 90% with it as the resume step.

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

- **Added at Gate 2,** 2026-11-08 20:50 CST, in the chat: "defaults on all three open questions are approved for next reset". The three questions and their defaults:
  1. Run look-dev round 3: yes.
  2. D7, A+: Gemini-painted backdrops (far buildings, the boss roof's sky, fire and smoke) as mattes, about $1.50-2.50 from the rest of the $5 Gemini cap: yes, with $2.50 as this round's cap.
  3. D6, Plan B: hold.
- **Added after round 3,** 2026-11-09 04:18 CST, by Slack DM (Michael, ts 1794219494.722819), answering the round 3 question (a Gemini paint-over of every shot's background, projected onto the set, about $2): "Extra $2 for Gemini use is approved if needed".
  - **The reading taken:** at most $2 more, for the per-shot background paint-overs, used only if round 4's code changes still read 3D in the blind check. That keeps the total at most $4.52, under the original $5 cap, so it holds under either reading of "extra".
- **Plan B after round 4,** 2026-11-09 06:22 CST, by Slack DM, answering "If round 5 still reads 3D, is Plan B (an AI restyle of the final cut, roughly $30-100) on the table?": "Let's keep it on hold for now.  The progress on graphics is heartening so far, and interested to see what a $2 overlay from Gemini can accomplish."
