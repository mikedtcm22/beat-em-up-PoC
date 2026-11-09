# R4-SHOTS: judgement calls (round 4: the lens, the poses and the cast)

Each call: the decision, an alternative not taken, why.

## Calls
1. **The video's first-person lens is 75 degrees, set as the default of `VideoStillShot.first_person_fov_deg` (was 0, "the game's 90").** Every first-person still and trailer shot takes it, written through `Tuning.set_value` by the director as before and put back after. 75 is the bottom of the Tuning range (`fov_deg` 75-110), so nothing is written outside the range and the frame writer's camera needed no change. Alternative: 70 through the frame writer's camera (the brief's "70-75"): departs further from the game for 5 degrees. A shot can still set its own value in its `.tres`; 0 gives the game's. Tunable: none added (the property is the shot's data).
2. **Stepping the player back, not lowering the arm.** At 75 the target is 1.3x larger on screen, so `fp_punk` cut the Punk's boots and `fp_kicker_lamp` the Kicker's. The player moved back (fp_punk z -3.0 -> -2.5, so 3.5 m; fp_kicker_lamp z -1.0 -> -0.4, so 5.0 m) to keep the targets' size and the whole figure in frame. Alternative: a lens shift or pitch in the frame writer to push the arm down. It moves the arm and the target together, so it cannot lower the arm alone; the arm's size and shape are LD-ART2/R4-ART's.
3. **Ox's stills use held game poses, turned off the lens.**
   - `ox_closeup`: the idle guard (one glove forward is what the three-quarter turn gives), yaw 128 (38 degrees off the lens), so the head turns and the near glove is forward.
   - `ox_low`: `haymaker_charge` held at tick 38, yaw 110 (20 degrees off), camera pulled back 0.8 m (x 4.0 -> 3.2) so his boots stay in frame. One glove high and forward, the other low and back, the weight on one leg.
   - Tried: `jab_1` and `hook` held at tick 5-12 (they play as the idle guard in the rig's `play`, symmetric), `taunt` (arms spread, and a white blob shows at his belt, a game-art loincloth flash), `stagger_left`, and `haymaker_charge` at yaw 65 (a thin profile with the head away). Not taken for those reasons.
4. **`street_wide`: two Punks and one Kicker, each at its own yaw and stance.** Punk idle at yaw -25 (near, back three-quarter), Punk `taunt` at yaw 150 (mid), Kicker `brace` at yaw -170, small and far (z -15.5, 7.5 m from the first Punk). Only the Punk has the video art, so the second near figure is another Punk in a different stance; the one figure in the game's art is far and tiny. Alternative: a Veteran and a Thug at mid distance (the brief's "different type"): they read 3D at that size, and a blind judge needs only one tell.
5. **`roof_silhouette`: the Kicker takes `taunt` at yaw 150** (back three-quarter, arms apart), against the sun, instead of the symmetric idle facing the lens. In the ref the lone figure is seen from behind. The silhouette's front-lighting (Gate 2 finding 6) is the world/art packages'.
6. **Trailer shots t04, t11, t13: pitch beats, so the action stays in frame at 75.** At the narrower lens the fallen body (t04 Kicker, t13 Ox) left the bottom of the frame, and Ox's head left the top at point-blank range.
   - t04: window 3.0 -> 2.7 s; PITCH -16 over 0.5 s from 0.35 s after the kick's press, so the Kicker lies in frame.
   - t13: the view starts at +14 (was -2) so Ox's face is in frame at 2.4 m; PITCH -16 from 0.1 s after the release, to follow him down.
   - t11: pitch +22 (was +8) before the three-punch string, -10 after the knockdown, +16 before the haymaker's hold. Ox is still chest-filling at the closest beats (he is 0.5-1 m away: his belt and the gloves; the face does not fit at this lens however the pitch is set). Alternative: the player stepping back before the haymaker: the haymaker needs the reach.
   - The other first-person shots (t02, t03, t05, t06, t08, t09) keep their actions in frame at 75, judged from the 5-tile strips; t03's last frame is empty after the launch, as at 90.
7. **t08's two Punks still look like twins** (Punk and Veteran share the Punk's art; one is at yaw 135, but both stand in a guard facing the player). Not changed: the chain's third hit needs both live, and the cast of the blind set is the stills. Left for the art round that gives the Veteran its own look.
8. **Rear warning (t09, brief item 5):** it shows. From frame 9 an orange eight-petal flower with a white centre shows at the top right edge (and its fade at the top left from frame 12). It reads as a clip-art flower or a sticker, not a drawn warning. See requests.
9. **Test changes (old -> new):** none; no assertion changed. New: `video/tests/test_r4_shots_lens_and_cast.gd` (5 tests: every first-person still and trailer shot is within 70-75 degrees and narrower than the game's; no still shows one model twice in one pose; street_wide has three stances and distinct yaws; Ox's stills are turned at least 15 degrees off the lens, with ox_low not an idle).

## For each shot of the blind set: tells left (of PLAN's list of eight, as the round 4 brief numbers them: tell 5 is the CG primitives, copies and symmetric poses)
My package only changes the camera, the poses and the cast, so tells 1, 2, 3 (particles), 4, 6, 7 and 8 are the other packages'. A viewer who has not been told would still read every still as 3D, because the world and the figures are still lit, textured 3D; what changed is the pose and framing evidence.
- **fp_punk:** tell 5 reduced: the arm at 75 is less stretched, but it is larger on screen and still a tube with a mitten fist (R4-ART's). The Punk is whole in frame. Reads as 3D (arm, even-weight line).
- **fp_kicker_lamp:** the same. The arm at lower right still dominates; the lamp and Kicker are in frame. 3D.
- **moving_punk f42:** the head and cap in frame, the fists at the lens read less distorted. 3D.
- **ox_closeup:** the face turned three-quarter, one glove forward and near the lens, the other behind: tell 5's symmetric pose gone. The face under the hatch is still the near-photoreal tell. 3D, but the most likely to survive a look of the set.
- **ox_low:** asymmetric haymaker wind-up, a lopsided silhouette; the fire and smoke mattes read drawn. The figure is 3D.
- **street_wide:** no two copies in one pose; the world's tiling (tell 1) and the geometric pools (tell 2) dominate. 3D.
- **roof_silhouette:** the back three-quarter Kicker with an arm out, against the sun, reads as a silhouette figure. The banded sky is drawn; the figure and the water tanks are 3D (tell 5: twin tanks).

## Honest P6 (camera)
About 1.9 for the set of stills (was about 1.8: the framing was already near the references' language): low angle on Ox, the wide, the silhouette and the close-up are there; the first-person shots' lens is better and the poses are less stiff, but the arm at the lens, the missing depth of field and the missing smears keep it from 2.5. The trailer's cine shots (t10, t12, t14) are unchanged.

## Style meter, before (round 3) and after, same shots at 2560x1440
street_night: fp_punk 0.97 -> 0.96, fp_kicker_lamp 0.99 -> 0.98, street_wide 0.97 -> 0.97. boss_fire: ox_low 0.88 -> 0.91, ox_closeup 0.81 -> 0.85 (edge density and ink fraction fall a little with the new framing). roofs_dusk: roof_silhouette 0.72 -> 0.71. The meter measures the world's colour and line, which this package does not touch; the changes are framing.

## Requests (files this package does not own)
- **R4-INK (the cue pass / rear warning):** draw the rear warning as a flat, jagged chevron or burst pointing at the side the attacker is on, in the cue colour, not the petalled flower with a white disc it is now (t09, frames 9-24).
- **R4-ART:** the first-person arm at 75 is larger on screen: a shorter, slimmer forearm and a hand with fingers, so the lens does not read as a tube.
- **R4-WORLD:** t09's (and t08's) roof wall and stair brick are still the stair-stepped brick course tell.

## How to run
`tools/video/shoot_trailer.sh captures/r4/trailer` (the 14 at 1280x720; all rendered with `problems=0`), the stills by `tools/video/shoot.sh <key> <dir>`. The trailer's three changed shots come from `tools/video/gen_trailer_shots.py`.
