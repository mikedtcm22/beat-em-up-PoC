# Playtest round 2: Game-boy's notes and the plan

These are Game-boy's notes after playing PR #1's round 2: the throat-height camera, the relaxed stance and the held block. The work is scheduled for the next usage window. The open questions at the end come with defaults, which the follow-up session uses unless Game-boy answers first.

## Game-boy's notes (as given)

Controls:
- Parry needed you to basically guess when the enemy was going to wind up, and hit the button at exactly the same time as the first frame of winding up. That's too close for someone to get right on sight. Make the block come up a split second faster, so a player still has a fraction of a second after the very first bit of wind-up to pull off the parry.
- I wasn't able to grab enemies with the grab button. Was that set so you could only do it after a parry? I don't know if that's necessary. You should be able to grab an enemy whenever, I think. Otherwise we need to make parrying WAY easier if grabbing is parry-gated.
- I'm not sure the dodge works now that blocks are set up. I couldn't get the character to dodge with left/right on the stick + B. Might we just take dodges out? The block might be enough (?)

Camera:
- One or two moves would spin if done in real life (the spin kick, and I think a heel kick in one of the combos). For those, try having the camera do the 360 with the spinning character. It might make the game too dizzy, but if it's smooth enough it could help immersion and make the player feel like they're actually doing a spinning kick.
- Since we're working on spinning moves, add a spinning backhand as well, for the punch combos. Make it the "P P · P" combo: the last P after the pause starts the spinning backhand.
- The back attack doesn't let you see anything connect. It would be great if the camera turned about 100-120 degrees toward the attack, so the player sees the elbow connect with the enemy.

## Diagnosis and plan

### 1. Parry timing
**Cause.** Two settings combine:
- The guard only becomes effective `block_raise_frames` (4) after B is pressed.
- A parry needs the hit to land within raise + `perfect_block_window_frames` (4 + 8 = 12 frames) of the press.

The sparring jab's wind-up is 18 frames. A press on reaction to the wind-up (seeing it start, plus about 200 ms of reaction time) comes about 12-15 frames in. That leaves 3-6 frames, often less than the 4 the guard needs to come up. A press right at the start of the wind-up is 18 frames before contact, which is outside the 12-frame window. So only a narrow, early band of timings worked.

**Plan.**
- `block_raise_frames` 4 → 1, so the guard is effective almost at once.
- A parry when the hit lands within `perfect_block_window_frames` of the press, with the window raised from 8 to 14 frames (about 0.23 s).
- Sparring jab wind-up 18 → 24 frames (0.4 s; the spec's minimum for grunts is 18).

**Result.** Any press from about 10 frames into the wind-up until 1 frame before contact parries, which covers a normal reaction. A test sweeps press timing across the wind-up, including a "reaction" press 200 ms after the wind-up starts.

**Done (round 3).** As planned: raise 1, window 14 (from the press), wind-up 24. The sweep (`test_parry_timing_sweep_covers_a_reaction_to_the_wind_up`) presses B 0-23 frames into the wind-up: 0-8 block, 10-22 parry (the 12-frame reaction press included), 23 is too late because the press is read on the next tick, the contact frame. The combo bot's "Parry on reaction" act parries 0.2 s into the wind-up.

### 2. Grab anytime
**Cause.** Spec §4 says "LB next to a *staggered* enemy". Enemies stagger from the hook, roundhouse, shove, a guard break or a parry, so in practice the grab felt parry-gated.

**Plan (Spec §4 change).** LB grabs any standing enemy in front within `grab_range` and `grab_half_angle_deg`. It works when they are FREE, winding up, in hitstun, staggered or blocking. It whiffs when they are in their strike's active frames, downed, flying or KO'd.

**Tests.** Grab an idle dummy; grab during a wind-up; whiff during active frames; the existing stagger grab still works.

**Done (round 3).** `CombatActor.can_be_grabbed()`; also allowed in an attack's startup or recovery, never while dodging, getting up or invulnerable. Grabbing an enemy out of its wind-up ends the wind-up as interrupted. Tests for idle, wind-up, active-frame whiff, recovery and downed/flying bodies; the bot's "Grab anytime" act grabs an idle dummy, knees and throws it.

### 3. Dodge with stick + B
**Investigate first.** Reproduce with live input (Input.action_press plus joypad motion and keyboard events through the real `PlayerInput.poll()`), not the scripted path the tests use. Suspects:
- the stick reading used for the press decision;
- deadzone vs `block_stick_threshold`;
- the held-B re-raise logic swallowing the dodge;
- the gamepad B binding.

Fix it and add a live-input test.

**Done (round 3).** The live repro (joypad axis and button events, keyboard events and `Input.action_press`, all through `PlayerInput.poll()`) showed the stick, deadzone and B binding fine: stick then B dodges. What failed was B (or Shift) pressed a moment before the direction, which raised the guard and then walked in it; on keyboard, Shift then D always blocked. Fix: a guard raised by a fresh B press with the stick centered turns into a dodge when the stick passes the threshold within `dodge_late_stick_frames` (8, about 0.13 s), B still held, unless it has already stopped a hit. `test_stick_and_b_dodge_through_the_live_input_path` covers nine live cases. Dodges stay (Game-boy's answer).

**Game-boy asked whether to remove dodges.** Default: keep them, fixed. The sidestep is the escape from flankers in the spec's "don't let them get behind you" design; the block only covers the front. Decide after trying the fixed version.

### 4. Camera follows spinning moves
**Plan.**
- New `MoveData.camera_spin_follow` (0..1). During the move, the first-person camera adds that fraction of the body's yaw change since the move started to the view. The spin kick (360°) and the spinning heel kick both get 1.0, so the view spins with the body and lands back on the original heading.
- Presentation only: aim and hits are unchanged.
- Global dial `Tuning.cam_spin_follow_mult` (1.0; 0 turns it off) in case it's too dizzy.
- It must be smooth: render-rate interpolation, no 60 Hz stepping.
- The spinning backhand (5) uses it too.

**Done (round 3).** `MoveData.camera_spin_follow`, measured from the eyes (`HumanoidRig.eye_yaw()`), not the hips: the hips are 90° off the target at the heel kick's contact, the eyes face it. The spin kick's and heel kick's heads were re-keyed to lead the turn evenly (at most 30° a frame from idle; about 40 when the heel kick is chained out of the roundhouse) and to stay on the target after contact. The view lands on whole turns over the recovery, and a spin cut short settles back to the look. It is interpolated between physics ticks in the camera. Tests check a full turn, no reversal, the final heading and unchanged aim; the captures show smooth sweeps that end on the heading.

### 5. Spinning backhand on P P · P (Spec §4 change)
**Plan.**
- New move `spinning_backfist`, a FINISHER. Starting values: startup about 12, active 3, recovery about 20, damage about 14, KNOCKDOWN. The lead hand (or rear, whichever reads best) strikes after a full body turn. The camera follows the spin.
- It takes over the jab_2 PAUSE P branch.
- The body-blow flurry, which held that branch, moves to **P · P** (pause after the first jab, then mash), ending in the shove as before. Default; see the open questions.
- Update move data, move sets, the parser and integration tests, the combo bot, ARCHITECTURE and the README combo list.

**Done (round 3).** 12/3/20, 14 damage, FINISHER, KNOCKDOWN, knockback −1.5,3,6, RightFistPoint r0.15 (the rear hand, turning right like the heel kick). The wind-up chambers the fist low across the belly (at the chest it filled half the turned view). The flurry is on P · P. The parser code needed no change, only its tests' fixture.

### 6. Back elbow: see it connect
**Plan.**
- New `MoveData.camera_yaw_deg`, a first-person view turn eased in over startup, held through the active frames plus a few, and eased out over recovery, like `camera_pitch_deg`.
- The back elbow turns about 110° toward the elbow's side, so the view sweeps over the shoulder and the elbow connecting is visible, then returns.
- Presentation only: aim and body facing are unchanged.

**Done (round 3), at 150° instead of 110°: Game-boy to confirm.** `MoveData.camera_yaw_deg` −150 and `camera_pitch_deg` −10, held 6 frames into the recovery (`camera_hold_frames`). Measured from the lens, the elbow drives straight back behind the spine (0.45 m behind the body's center), so at the 90° FOV a 110-120° turn shows neither the elbow nor an enemy straight behind (the enemy's edge comes in from about 121°, the elbow from about 140°). At 150° the dummy and the elbow meeting it are in view through the hitstop. The player's own upper arm is large near the lens on those frames (under a third of the view). It is one constant in `tools/gen_moves.gd` if Game-boy prefers a smaller turn.

## Open questions: answered by Game-boy (use these)
1. **Flurry placement:** the spinning backfist goes on P P · P, and the flurry moves to P · P (then mash), ending in the shove. Confirmed.
2. **Dodge:** keep it, fixed. Confirmed.
3. **Grab:** a grab whiffs against an enemy in its strike's active frames. Confirmed.

## Review after the build (round 3)

An independent review found two camera bugs, both fixed with a regression test (`test_chained_view_turns_never_jump_or_sweep_round`, which fails on the old code):
- A back elbow cancelled into another back elbow made the view jump 134° in one tick.
- A spin cancelled into the back elbow made the camera's interpolation sweep about 340° the wrong way between two ticks.

The fix wraps the turn on screen and carries it over whenever the turning move changes. Also from the review: a late-stick dodge now drops a P or K held back in the guard.

Noted and left as they are:
- The parry window counts from the guard coming up, so a B buffered during a move counts from the recovery cancel.
- At the backfist's contact the player's right forearm covers much of the right half of the view (under a third in all), with the dummy's head above it.
- The back elbow's 150° turn in 5 frames is a whip rather than a turn.
