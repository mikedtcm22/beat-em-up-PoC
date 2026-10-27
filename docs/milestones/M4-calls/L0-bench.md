# L0-bench: judgement calls

Package L0-bench (M4-plan Part A A12): the look acts, `look_rect.gd`, `look_sheets.sh`, `perf_compare.sh`, the `CAPTURE_ARGS` passthrough and the "before" pack. Each call is the decision, an alternative not taken, and why.

## 1. A log frame is a video frame, counted in process frames

- **Decision.** `LOOK-MARK` and `LOOK-RECT` print `f<frame>` as `Engine.get_process_frames() - 1`: the 0-based index in a Movie Maker video of the frame that shows the state the bot has just read. `look_sheets.sh` cuts exactly that frame (`FRAME_OFFSET` 0).
- **Alternative.** Print `Engine.get_physics_frames()` like every other bot line and add a fixed offset (−2) in `look_sheets.sh`.
- **Why not.** I calibrated the offset first, with a scratch scene that lights one frame (red on physics frame 40: video index 39). The first C5 recording then put the contact flash one frame away from where the physics offset predicted: a frame ran two physics ticks early in the run, so the two counts had drifted by one. The process-frame count is the video's own count, so it cannot drift. The cost: the marks' numbers run one to two behind the bot's own `f<n>` lines (hits, AI states). The header of `look_rect.gd` says so.
- **Also found.** `ffmpeg -ss <t>` returns the first frame at or after `t`, so a seek to the middle of frame n gave frame n+1. The script seeks a quarter of a frame early. `test_look_acts` checks it on a video whose brightness is the frame number.

## 2. The perf bench measures with its own bot, copied into each ref

- **Decision.** `tests/bot/perf_bot.gd` and `perf_bot.tscn` (the crowd bot plus a frame-time recorder over each act) are new files. `perf_compare.sh` copies them into each temporary worktree before the import, so the same measuring runs on `afdb39e`, which has no such bot. It prints one `PERF-BENCH {json}` line per act: mean, p95, worst, spawn hitch, first spawn, first hit and first finisher, using the acts' own definitions (wall time between process frames; the worst frame within 0.5 s of an event; p95 at `floor(0.95 (n-1))`).
- **Alternative.** Parse the `PERF` lines the existing act prints (`crowd_acts.gd`).
- **Why not.** Those lines carry the whole run, the windows and the spawns, but no first-hit or first-finisher time: the brief asks for both and M4's soft bars (A16) use the first hit. A recorder beside the act also measures `Look: Perf, six art Punks` (SL-int's) without that act having to log anything.
- **Departure from the file list.** The lead's note lists the files I touch. These two are new, tooling only, and under `tests/bot/` so `test_bot_scripts_compile` loads them. Nothing else refers to them. They are reported under "requests" in case the lead wants them elsewhere.

## 3. The refs run in turn, round by round

- **Decision.** `perf_compare.sh a b` runs a, b, a, b, a, b (3 rounds), each in its own worktree, both imported before the first run.
- **Alternative.** All of a, then all of b ("back to back" read literally).
- **Why not.** Drift (thermal state, another builder starting a job) lands wholly on one ref in the grouped order. In turn, it falls on both, and the run-to-run spread is printed beside each mean.
- It also takes one ref, which the proof run needs, and several `--act` options (A16 compares two acts).

## 4. The strafe and the turntable play the Punk's rig by hand

- **Decision.** For C3 and C10 the act takes the Punk off the physics tick (`set_physics_process(false)`), places it and calls `rig.play_locomotion()` and `rig.advance()` itself, with the walk's velocity worked out as `EnemyActor._animate_legs()` does.
- **Alternatives.** (a) `rig.play_locomotion()` on a frozen Punk: with the AI frozen, `_hold_still()` plays the idle every tick and undoes it before the frame is drawn. (b) Let the AI walk it: `enter_from()` to a chain of lane points on the half circle. (c) Let the posture ring circle at 1 m.
- **Why not.** (a) does not work. (b) and (c) bring the navmesh, avoidance and the director in (the codemap's AI-driven 1 m circling attacked at once and then stood in RECOVER), and the act's frames would depend on them. By hand, the strafe is the same walk cycle the game plays, at the Punk's own `posture_circle_speed_mps`, and repeatable.

## 5. C3: a 150 degree arc, the view follows, the step at the circle's pace

- **Decision.** "A half circle" is a 150 degree arc (the Punk starts on the player's heading and ends 150 degrees round to the right), nearest (1.0 m) in the middle and 1.3 m at the ends. The player's view follows at 90 degrees a second, as a player's does. The step in and out (1.3 to 1.0 m and back) is walked at `posture_circle_speed_mps`.
- **Alternative.** A full 180 degrees; the Punk's own `engage_speed_mps` for the steps.
- **Why not.** At 180 degrees the Punk is beside the player, out of the 90 degree view, for the first and last part. `engage_speed_mps` (3 m/s) does 0.3 m in 6 frames: no stride to see. Both are constants at the top of `look_acts.gd`.

## 6. C5 and C13: a Punk that lives through the chain, is put back in front, and is finished

- **Decision.** The act gives the Punk 100 health (`SURVIVOR_HEALTH`), because its own 30 is gone after 38 damage (jab, jab, jab, hook, uppercut) and the plan wants a get-up. After the get-up it is put back 1 m in front of the lens (`_place()`), since the uppercut leaves it metres off and the health looks are judged at 1 m. The health looks are set by hand (100, 65, 30%) as `vfx_bot` does. Then one jab on a Punk with 5 health shows the KO slump and the blink-off (J10), which no other 1 m act covers.
- **Alternatives.** The Punk's own health (it dies in the chain, so no get-up); no re-place (the health looks at 3-4 m); no KO (the plan's C5 list stops at the health looks).
- **Why.** The re-place is a cut in the recording, right after the get-up; the stills at the marks are before and after it. The KO is an addition to the plan's C5 list: it costs 4 s of recording and every later package can read the KO from the same act.
- C13's title is "Look: Punk, impact frame off", not "...reacts...": the capture filter is a substring match, and C5's title must not pick C13.

## 7. C11: grab again after the third knee

- **Decision.** The hold ends on the third knee (`max_knees`), so the act grabs the Punk again once it is back on its feet and throws it with K, as the combo bot's own grab act does.
- **Alternative.** Press K straight after the third knee (it was a front kick on a staggering Punk).

## 8. C9: the street tour has a cast

- **Decision.** Six frozen enemies (the four archetypes, a second Punk and Thug) stand in the street for the room's tour: four round the start for the turn on the spot, two beside the lane.
- **Alternative.** The bare tour that `room_acts.gd` records.
- **Why.** The rubric's J13 ("one game") is judged on C7 and C9, and a street with no character in it says nothing about the characters beside the street. The environment is unchanged by the cast. SL-int can change the cast to art Punks.

## 9. Marks and rectangles

- **Marks.** Acts mark their own beats (every second of an idle, the circle's quarters, each hold's start); a watcher beside C4, C5, C8 and C11 marks every change of the subject's state, each move's wind-up and first active frame, and each hit it lands or takes with the frame after (the flash lasts a couple of frames). `start` and `end` only delimit an act and get no stills.
- **Rectangles.** Bounds of spheres round the rig's drawn points through the current camera, grown 12 px and clipped to the frame. Head: the head hurtbox plus 4 cm. Hands: the two fists (10 cm). Body: every bone (12 cm), the head and the hands too. A first-person body (the player's own, C8) leaves out the bones its own lens hides, and has no head. A region wholly off the screen prints nothing; a sphere that reaches the lens fills the frame.
- **Alternative.** A mesh-accurate bound (project the drawn vertices).
- **Why not.** The Punk is still primitives, and from the next package on it is a skinned mesh whose vertices are not reachable from here without `SkinnedView` (P1-skin's). Spheres round the skeleton work for both and are a little generous, which suits a crop.

## 10. look_sheets.sh

- One overview per act, a page every 20 tiles at 6 fps (a plain `tile=5x4` with `-frames:v 1` would only show the first 3 s). Stills and crops are named by frame and label, so two runs of the same act line up in a before/after pair. The log's doubled lines are dropped. `ffmpeg` runs with `-nostdin`: it reads the terminal, and inside the script's `while read` loops it ate the loop's input (a crop went missing).

## 11. CAPTURE_ARGS

- **Decision.** An environment variable, split on spaces: `CAPTURE_ARGS="--tune=impact_frame_enabled=0" tools/capture_bot.sh ...`.
- **Alternative.** More positional arguments after the stills rate.
- **Why not.** The script's four positions are used by every builder's habit and by the docs; an environment variable adds nothing to them. An argument with a space in it cannot be passed (none of the bots' options has one).

## 12. Numbers in the act files

- The acts' distances, pitches, tick counts and cast are `const`s at the top of `look_acts.gd`, as the other bot act files keep theirs (`crowd_acts.gd`, `slice_acts.gd`). They are test tooling, not game feel. Everything the game decides (the Punk's circle speed, its step speed, the move's frames, the flash's frames) is read from `Tuning` and the moves.
