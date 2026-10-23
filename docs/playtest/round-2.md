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

### 2. Grab anytime
**Cause.** Spec §4 says "LB next to a *staggered* enemy". Enemies stagger from the hook, roundhouse, shove, a guard break or a parry, so in practice the grab felt parry-gated.

**Plan (Spec §4 change).** LB grabs any standing enemy in front within `grab_range` and `grab_half_angle_deg`. It works when they are FREE, winding up, in hitstun, staggered or blocking. It whiffs when they are in their strike's active frames, downed, flying or KO'd.

**Tests.** Grab an idle dummy; grab during a wind-up; whiff during active frames; the existing stagger grab still works.

### 3. Dodge with stick + B
**Investigate first.** Reproduce with live input (Input.action_press plus joypad motion and keyboard events through the real `PlayerInput.poll()`), not the scripted path the tests use. Suspects:
- the stick reading used for the press decision;
- deadzone vs `block_stick_threshold`;
- the held-B re-raise logic swallowing the dodge;
- the gamepad B binding.

Fix it and add a live-input test.

**Game-boy asked whether to remove dodges.** Default: keep them, fixed. The sidestep is the escape from flankers in the spec's "don't let them get behind you" design; the block only covers the front. Decide after trying the fixed version.

### 4. Camera follows spinning moves
**Plan.**
- New `MoveData.camera_spin_follow` (0..1). During the move, the first-person camera adds that fraction of the body's yaw change since the move started to the view. The spin kick (360°) and the spinning heel kick both get 1.0, so the view spins with the body and lands back on the original heading.
- Presentation only: aim and hits are unchanged.
- Global dial `Tuning.cam_spin_follow_mult` (1.0; 0 turns it off) in case it's too dizzy.
- It must be smooth: render-rate interpolation, no 60 Hz stepping.
- The spinning backhand (5) uses it too.

### 5. Spinning backhand on P P · P (Spec §4 change)
**Plan.**
- New move `spinning_backfist`, a FINISHER. Starting values: startup about 12, active 3, recovery about 20, damage about 14, KNOCKDOWN. The lead hand (or rear, whichever reads best) strikes after a full body turn. The camera follows the spin.
- It takes over the jab_2 PAUSE P branch.
- The body-blow flurry, which held that branch, moves to **P · P** (pause after the first jab, then mash), ending in the shove as before. Default; see the open questions.
- Update move data, move sets, the parser and integration tests, the combo bot, ARCHITECTURE and the README combo list.

### 6. Back elbow: see it connect
**Plan.**
- New `MoveData.camera_yaw_deg`, a first-person view turn eased in over startup, held through the active frames plus a few, and eased out over recovery, like `camera_pitch_deg`.
- The back elbow turns about 110° toward the elbow's side, so the view sweeps over the shoulder and the elbow connecting is visible, then returns.
- Presentation only: aim and body facing are unchanged.

## Open questions (defaults used unless Game-boy answers)
1. **Flurry placement:** with the spinning backhand on P P · P, does the flurry move to P · P? Default: yes.
2. **Dodge:** keep (fixed) or remove? Default: keep, fixed.
3. **Grab:** should an enemy in its strike's active frames beat the grab? Default: yes, the grab whiffs.
