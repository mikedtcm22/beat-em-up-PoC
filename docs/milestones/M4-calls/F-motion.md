# M4 calls: F-motion

Package F-motion (phase 2, M4-plan Part C section 7 with Part A A20, A9, A12's C12, and Part B's J8 and J9): the placeholder clips made to look alive on the same frame data. Each call is the decision, an alternative not taken, and why. Part 2 is what the numbers say, part 3 what the first-person sheets show. The machine was shared with other builders (1-minute load average 2.9 to 3.8), so every time figure is noisy; the pose and slide figures are exact (the clips are built, not timed).

## 1. Calls

**C1. The hash table comes first, and holds the named clips too.**
- *Decision.* Before any change, `tests/fixtures/motion/clip_hash.gd` hashed every move resource in `game/combat/moves` (41 files: the player's moves, `punk_jab`, `punk_cross`, `punk_shove` and the Kicker's, Thug's, Bruiser's and boss's) key for key (length, loop, every track's type, path, interpolation, key times and values to a micro-unit), as a rig builds it: plain, mirrored, from the charge, both; for both stances and two scales (1.0 and the boss's 1.278). It also hashed every `ANIM_IDS` clip as M3 built it (184 entries). The table (`move_clip_hashes.json`, 164 + 184 hashes) was committed first (`wip: F-motion the move-clip hash table`). `tests/test_motion_m4.gd` compares against it: no move changed; with `look_motion_polish` off (or `Life.off()`) every named clip is its M3 hash; with it on, exactly the 17 ids of `PlaceholderAnims.POLISHED_IDS` differ.
- *Alternative.* Hash only `MOVE_IDS`, as A20 words it.
- *Why not.* A20 names the clips the polish may change, so every other named clip (the dodges, block, stagger, launched, knockdown, KO, grab holds) is the same kind of promise; the table makes it one assertion each, and the Debug switch becomes a real A/B (the M3 clips are rebuilt bit for bit).

**C2. The polish is a `Life` value read when a library is built, not new state in the rig.**
- *Decision.* `PlaceholderAnims.build_named(id, scale, stance, life = null)` and `build_library(scale, stance, life = null)` take a `PlaceholderAnims.Life` (the Look > Motion tunables, `Life.from_tuning()`, or `Life.off()`). The named-library cache key keeps its shape (`"<stance>@<scale x 10000>"`, tested), so the amounts apply to a library when it is first built (the first rig of a size and stance) and to later ones; nothing already built changes.
- *Alternative.* A runtime layer on the rig (an additive pose added each tick), or a cache key with a revision in it.
- *Why not.* The rig is `humanoid_rig.gd`, not mine, and A20 pins the cache key. A runtime layer would also have been a second place for the pose to come from, which the active-frame tests would then have to cover. Reported in "requests": a rebuild on `Tuning.changed(look_motion_*)` would make the F1 sliders live.

**C3. Eased in-betweens are monotone cubic, resampled; Godot's `INTERPOLATION_CUBIC` is on the track but never on sparse keys.**
- *Decision.* The first build used `INTERPOLATION_CUBIC` on the authored keys. It overshoots between sparse keys, and three existing tests moved: the player's KO revive covered 34% of the view (bar a third) because a get-up's in-between poses swung past the keys. The polish now resamples each eased clip with `MotionClips.ease()`: per bone and axis a Fritsch-Carlson monotone cubic through the authored key poses (the key poses are exactly the keys; a bone that reverses at a key stops there, one that goes through it does not; none passes the poses it moves between), on a 1/30 s grid (at most 24 steps a clip), and the tracks are `INTERPOLATION_CUBIC` on those dense keys, which only rounds them off. A clip that plays once ends at rest; the get-ups start at the speed of their first segment (`drive_in`): an ease-in at the start of a get-up held the body on the camera longer (41% of the view in the revive test).
- *Alternative.* Cubic on the authored keys, or A20's "eased in-between keys" as a smoothstep per segment.
- *Why not.* The first overshoots (measured); a smoothstep per segment stops dead at every key, which is the pose-to-pose look this package exists to remove.

**C4. Idle: one breath long, IK on the feet, hurtbox motion under 1 cm peak to peak.**
- *Decision.* The idle is `1 / look_motion_breath_hz` long (4 s), keyed every 1/6 of a bounce, and every component is a whole number of cycles in it, so the seam is the first key: breathing (chest +1.5 degrees, the upper chest -1.8 per degree and the neck +0.5 so the head and torso hurtboxes stay within a millimeter or two, the shoulders up 1.6x), a bounce (the hips dip 5 mm at 1.5 Hz, six bounces a breath), a weight shift (the pelvis rolls 1 degree once a breath, the chest rolls against it: ratios found by a grid search over the FK of the hurtbox points), the guard's arms swaying after the bounce (3 degrees, they have no hurtbox), the head drifting (yaw twice, tilt once, nod three times a breath, 1.4 degrees). `MotionLegs` (two-bone IK on the placeholder skeleton) puts each ankle back on its spot in the guard as the hips dip and roll, so the soles stay planted (the knees compensate, as the brief says): the sole vertices of the art move 1.4 mm in a loop. The first key is the stance exactly (a clip that ends in the stance flows into it).
- *Alternative.* Hips +-1 cm (plan Part C's number).
- *Why not.* A20 says idle hurtboxes move less than 1 cm, and M3's own idle moved them 12.6 mm; a 1 cm bounce is 2 cm peak to peak. The reading taken is the strict one: every key point of every hurtbox, peak to peak, under 10 mm (8.7 mm the boxer's, 3.1 mm the player's; M3 12.6 and 12.1). The visible life is then in what has no hurtbox: the arms and gloves, the shoulders, the chest's shape and the head's tilt. A bigger body moves no more in meters (the amplitudes are divided by the rig's scale: the boss's idle is also 8.7 mm).

**C5. The player's idle is calmer by a tunable share, and everything else of his stays as it was.**
- *Decision.* `look_motion_player_calm` (0.35) scales every amplitude of the idle in the relaxed stance: 3.1 mm of hurtbox motion, the chest 0.5 degrees. The view rides his head, so a quiet body keeps the lens steady; the first-person tests (arms out of the view, strikes steady) pass unchanged.
- *Alternative.* No life at all in the relaxed idle (M3's own 12 mm sway stays), or the boxer's.
- *Why not.* M3's relaxed idle moved the lens 12 mm; the calm one moves it 3 mm and still breathes.

**C6. The boxer's walks plant their feet: the clip is as long as the stride takes at `move_speed`.**
- *Decision.* M3's walks slid 0.9 m a step forward and 2.5 m a side step on the art at the speed the game plays them (`play_locomotion` plays a clip at `v / move_speed`, so the body goes `move_speed` meters per second of CLIP time whatever `v` is: the clip's planted foot has to move back at that speed in the rig). So the cycle is `look_motion_stride_m` (0.62 m, the foot's sweep) over `move_speed x 0.56` (the share of the cycle a foot is down): 0.185 s forward, 0.070 s a side step (whose sweep is 0.38 of the stride), whatever the body's size (the stride is in meters: a bigger rig's angles are smaller). Each foot is solved with `MotionLegs`: it rolls (toes up at the strike, flat, heel up from 74% of the stance, toes flat on the floor) about a contact point that does not move in the world, and rises before it travels and settles before it lands. The pelvis turns 4 degrees with each step and tips, the chest turns against it by 5 degrees (the counter-swing; the head undoes 80% of it), the hips sway toward the planted foot, bob 12 mm and ride 45 mm lower than the guard's so the legs reach. `walk_back` is the forward cycle run backward (as M3's was). With the real playback (`play_locomotion`, the AnimationPlayer, the rig moved at the speed) a Punk walking at the circling (1.1 m/s), approach (2.6) and engage (3.0) paces, backing away, and side-stepping slides 0.8 to 1.4 cm at most.
- *Alternative.* Keep M3's keys and change `HumanoidRig.play_locomotion()` to play at a stride-matched speed; or leave the walks and report the slide.
- *Why not.* The rig is not mine, and the lead's brief says "change the clip, not the tunable". The cost is the cadence: the step is 0.57 m, so the Punk takes 4.4 steps a second at the approach pace (2.6 m/s) and 1.9 at the circling pace; that is the price of a stride a 0.9 m leg can plant at `move_speed` 6. The cycle length is read from `move_speed` when the library is built: a changed `move_speed` needs a rebuild (the request in part 4).

**C7. The player's walks keep M3's 0.6 s cycle, eased; their slide is reported, not fixed.**
- *Decision.* The relaxed stance's walks are M3's keys, eased by `ease()` (so no overshoot), with their M3 cadence. Their slide is 92 cm forward and 262 cm a side step on the art (M3 135 and 277).
- *Alternative.* Match them too (a 0.185 s cycle).
- *Why not.* At his full speed (6 m/s: `speed_ratio` 1) a matched cycle would run his legs at 11 steps a second in first person when he looks down (C8's walking act), and a 6 m/s walk cannot plant a 0.9 m leg; a run cycle with a flight phase would be needed (not this package's). A4's "every walk" is therefore proved for the enemies (the boxer stance) and printed for the player.

**C8. The sole is the art's foot and toe skin held 0.9 or more by those binds and under 2 cm at the rest; planted is under 1 cm.**
- *Decision.* `MotionProbe.sole_vertices()`. With the looser first definition (half the weight on the foot and toes binds, 3 cm) the worst slide was the back of the heel (0.56 foot, 0.44 shin: the ankle's blended skin follows the shin and rises 3 cm through the stance), 1.9 cm; the stricter definition measures 1.3 cm. A planted run is followed per vertex, so a rolling foot is no slide (its contact point is the stationary one).
- *Alternative.* Count every vertex under 5 mm only, or the sole's centroid.
- *Why not.* A centroid hides a roll's slide, and a 5 mm threshold lets a foot hover at 6 mm and slide unseen.

**C9. Flinches overlap per bone, on a frame grid; the key poses stay.**
- *Decision.* `MotionClips.flinch()` samples every frame (and the key times 0.06 s, 0.1 s, and the lead and lag times) with an envelope per bone: the body's bones arrive at 0.06 s (an ease-out snap), hold to 0.1 s and recover (an ease in and out) exactly as M3 keyed them; the shoulders and arms lead by `look_motion_overlap_s`; the neck and head lag by it (the neck half as much) and the head overshoots the hit pose by `look_motion_overshoot` (15%) before settling. The clip's length, its end pose and the body's key poses are M3's (tests). A20: no overlap on `punk_jab`, `punk_cross` or `punk_shove` (hashed), only on the five flinches.
- *Alternative.* Extra keys on the existing tracks.
- *Why not.* All bones share the key times in `make()`, so per-bone lead and lag need a dense list anyway.

**C10. Three existing ragdoll and KO-view tests sit on a knife edge; the defaults are ones that pass.**
- *Decision.* Every pose change reaches a ragdoll through the pose on screen and the bone velocities when a body is hit, and three existing tests have no margin: `test_ragdoll`'s "body launched from behind lands face down" (joints at most 10 degrees past a limit: M3 9.97 on the RightShoulder at the same frame; any new idle gave 10.2 to 11.1), "uppercut in a corner keeps the lens clear" (nearest 0.25 m: M3 0.301; the same code gave 0.231 to 0.313 over the overlap setting, not monotonic) and `test_ko_view`'s revive (a third of the view; see C3). They pass untouched with the shipped defaults (`look_motion_head_deg` 1.4, `look_motion_overlap_s` 0.025); other values flip them. No test was weakened.
- *Alternative.* Loosen the three bars, or take the idle and the flinch off the ragdoll's pose.
- *Why not.* The bars are other packages' (M2's ragdoll, M3's KO view) and are exactly what they were written to hold; the polish is the thing that has to fit them. A later merge that changes a pose (F-punk's art does not; F-look's does not) can flip them again: reported in part 4.

**C11. The tunables.**
- *Decision.* Look > Motion (a new subgroup after "FP feel", all `@export_range`): `look_motion_breath_deg` 1.5, `look_motion_breath_hz` 0.25, `look_motion_bounce_m` 0.005, `look_motion_bounce_hz` 1.5, `look_motion_shift_deg` 1.0, `look_motion_guard_sway_deg` 3.0, `look_motion_head_deg` 1.4, `look_motion_player_calm` 0.35, `look_motion_stride_m` 0.62, `look_motion_hip_roll_deg` 4.0, `look_motion_counter_swing_deg` 5.0, `look_motion_overlap_s` 0.025, `look_motion_overshoot` 0.15; and in Debug (presets skip it, A9) `look_motion_polish` (true; off builds the M3 clips, so a capture pairs an M3 and an M4 recording of one act). The shape numbers (which harmonic, the foot's roll angles and when, the lift of a swinging foot, the stance share 0.56, the IK's knee pole) are named constants in `motion_clips.gd` and `motion_legs.gd`, art data like the pose files' numbers. `tuning/default.json` was regenerated.
- *Alternative.* A tunable for every one of those.
- *Why not.* They are not feel dials; the thirteen are what Game-boy would turn.

**C12. The C12 act holds each pose on the skeleton and turns the Punk, and the motion acts play the rig by hand at the game's speeds.**
- *Decision.* `look_motion_acts.gd`: C12 `Look: extremes` (slug c12) shows the strain test's flexes (guard, elbow 150, arm raise 140, knee -130, spine twist), a deep knee bend, the hold's knee, and the four lying poses, each held 40 ticks and turned once round at 1 m in four quarter marks with rectangles; the view looks down for the legs and the lying bodies. The poses are written onto the Punk's skeleton (`hold()`); the Punk is off the physics tick. M1 idle (8 s body, 4 s face), M2 walks (back away, walk in, strafes at the circling pace, a quick step in at the approach pace, the view down at the feet), M3 the five flinches, M4 the two knockdowns, the lying breaths, the two get-ups and the taunt. Every title starts "Look:" and none holds or is held by another (tested against look_acts.gd's). A/B: `CAPTURE_ARGS="--tune=look_motion_polish=0"` records the M3 clips.
- *Alternative.* Play real hits for M3 and M4 (`receive_hit`).
- *Why not.* The flinch and the get-up are the clips; a real hit adds the flash, the pause and the ragdoll, which C5 (L0-bench's) already records.

## 2. Assertions that changed

One, forced by the Motion subgroup the lead asked for:
- `tests/test_m4_contracts.gd::test_every_look_subgroup_has_a_documented_seed`: the subgroup order `["Toon", "Outline", "Edges", "Grade", "FP feel"]` becomes `[..., "FP feel", "Motion"]`, and the seed table gains `"Motion": [look_motion_breath_deg]`. Twin on the visible path: `test_motion_m4::test_the_motion_tunables_are_in_the_look_group_and_the_switch_is_a_debug_value` (every Motion tunable is a slider, documented, saved in a preset, in `default.json`; the Debug switch is skipped by presets).

Nothing else: the full suite passes with every other existing test untouched.

## 3. What the numbers say (printed by `tests/test_motion_m4.gd` as `MOTION ...`)

- **Idle hurtbox motion (peak to peak, every key point, 4 s loop).** Boxer 8.7 mm at every size (x1.0, 1.139, 1.278), player 3.1 mm; M3 12.6 / 14.3 / 16.1 mm and 12.1 / 13.8 / 15.5 mm. The idle's soles (art) move 1.4 mm (boxer), 0 mm (relaxed); the lowest vertex -3.1 mm.
- **Walk slide (art, planted runs, 3 cycles).** Forward 1.3 cm, back 0.8 cm, right 0.4, left 0.4; lowest vertex -5 mm (M3: 89, 89, 256, 250 cm; -9 mm). Primitive sole points at x1.0, 1.139 and 1.278: 1.5 cm at most. Through the rig's own playback: 0.8 to 1.4 cm. With `move_speed` 4 the same bound holds.
- **Active frames.** 234 poses (every move, both stances, the first, middle and last active frame) compared between a rig built with the polish on and one built with it off after 1.3 s of idle: the largest difference of any rig point or hurtbox is 0 m.
- **Library build.** 26 to 31 ms polished against 9 to 12 ms as M3 (best of three, on a loaded machine), once per size and stance. SL-int's load-time warm-up builds the Punk's size; the Bruiser's (x1.139) and the boss's (x1.278) first spawn pays it (request).
- **A19 strain (the art against the skinned rest, the worst of 17 phases of each clip, p99.9 / worst edge), M3 then now, boxer stance.**

| Clip | M3 | now |
| --- | --- | --- |
| idle | 2.08 / 6.1 | 2.09 / 6.2 |
| walk_forward, walk_back | 2.45 / 18.6 | 2.63 / 18.4 |
| walk_left | 2.00 / 7.6 | 2.43 / 12.0 |
| walk_right | 2.00 / 10.5 | 2.43 / 13.9 |
| run_forward, taunt, brace | 3.14, 2.00, 2.14 | the same |
| flinch_head_front, _left, _right | 2.00, 2.00, 2.00 / 7.3, 18.6, 18.7 | 2.00, 2.00, 2.02 / 7.7, 20.2, 19.9 |
| flinch_gut, flinch_legs | 2.00, 2.75 | the same |
| getup_back, getup_front | 3.76, 5.61 | 3.81, 5.61 |
| downed_back, downed_front | 2.14, 5.61 | the same |

  The clips that keep M3's poses are no worse (p99.9 within 0.06; the flinch's head overshoot lengthens the worst edge by a tenth at most). The walks are worse by 0.18 (forward) and 0.43 (strafes) on p99.9, the strafes' worst edge 12 to 14 against 7.6 to 10.5, and the forward walk's worst edge is the same 18 (the left foot's seam, in both): a planted stride moves the legs further than M3's skating walks did, and the strafes' M3 steps were nearly still. Switching off the pelvis' roll and the chest's counter-swing leaves the forward walk at 2.45 (M3's) and the strafe at 2.39, so the legs are what the extra is; it is the foot seam and the groin skin of the smoke Punk's weights (F-punk's to smooth), and no clip's strain passes A19's bar (1.6) in M3 either. The bars of the test: 0.1 on p99.9 for the clips that keep M3's poses, 0.6 and twice the worst edge for the walks. The breathing and the bounce stay off the shoulder's worst range: the shoulders and upper arms stay within 5 degrees of the guard in the idle.
- **Seams.** Every looped polished clip (idle, the four walks, run, the two downed), both stances, two sizes: the first and last keys agree to 1e-4 rad and the step across the seam is no bigger than the largest step elsewhere in the clip.

## 4. What the sheets show (first person, 1600x900; `captures/`, never committed)

Looked at: C12 (every pose at four angles), M1 to M4 (the M3 clips and the polished ones, 12 fps sheets and 60 fps frame sheets), and C3 and C5 re-recorded against the M3 pack (`captures/m4_before/c3`, `c5`: the same marks and labels, the same frames).

- **The idle reads alive, and quiet.** At 12 fps over 1.7 s at 1 m the frames look near identical to the eye (the hands bob a centimeter or two, the vest's shoulder rises, the cap tilts a degree); a mean luma difference to the first frame cycles with the bounce (a 0.67 s beat on a 4 s breath) and peaks at about 9 of 255, the same size as the M3 idle's, which swung in one 2 s triangle wave. It no longer ticks between two poses. It would not read as "alive" at 2.5 m or more, and the amounts are tunables (the hurtbox bound is what limits the bounce, not taste).
- **Walks.** Looking 25 degrees down at 1.0 to 1.9 m: the Punk backs away, walks in and side-steps with its feet landing and leaving without skating; its body rides a few centimeters lower than in the idle, the pelvis and the chest turn against each other and the gloves swing a centimeter or two with them. The cadence is brisk (4 steps a second at the approach pace), which reads as a boxer's shuffle at the circling pace and as a scurry at the approach pace; the feet are in the lens only at 1.5 m or more with the default look, so at 1 m the walk is the upper body's turn and the head's steadiness. The legs' deformation at the foot seam shows as slight crumpling of the shoe's cuff in stride (F-punk's weights).
- **Flinches.** Frame by frame the head snaps back a frame after the shoulders, goes a little past the hit pose and settles while the body recovers; no pop in or out. C5's jab flinch plays the same with the contact flash.
- **Get-ups.** Lying on the back with the arms out (the lying breath is a smooth rise now), the Punk pushes up through a crouch into the guard with no snap at the changes of pose; the C5 get-up is the same sequence after the launch.
- **Extremes (C12).** The arm raised 140 degrees shows the armpit collapsing slightly and the vest's cut edge splaying (the A19 shoulder), the elbow at 150 keeps its volume, the spine twist shows a clean vest collar with the shoulder rolling under it, the deep knee bend and the lying poses hold their volumes (the legs need the lowest look, `LEGS_PITCH_DEG`). Nothing candy-wraps or collapses at 1 m in first person; the shoulder and the foot seam are the places to improve.
- **No pops** at any loop seam or between clips in M1 to M4, C3 and C5; the feet plant in the lens wherever they are in it.

## 5. Requests and risks

- *HumanoidRig* (not mine): rebuild or drop `_named_libraries` on `Tuning.changed` for `look_motion_*`, `move_speed` and the Debug switch so the F1 sliders are live; start a looped idle at a random phase so a wave of Punks spawned in one frame does not breathe in step; warm the Bruiser's and boss's libraries (`HumanoidRig._named_library(rig_scale, stance)`) in `RoomKit.warm_up_art` as the Punk's is, so their first spawn does not pay the extra 17 ms.
- *The player's walk* (F-player or P3-int): a run cycle with a flight phase (or a slower `move_speed` for the cadence) is what would plant his feet; the walk clip as it is cannot at 6 m/s.
- *F-punk:* the foot seam and the groin skin are the worst edges of every walk; smoothing there helps A19 and J8 more than any clip change.
- *Risk:* the three knife-edge tests of C10.
