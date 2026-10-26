# M3 judgement calls: P1-ai (the enemy base and the Street Punk)

Calls the P1-ai builder made where the plan left a gap or two readings. Each is a decision, an alternative not taken and why. Game-boy was not asked (no grey-block feel questions): the default that changes least was taken.

1. **Every move aims the navigation agent, and a strafe aims it a second ahead.** The agent passes a velocity through its avoidance only while it has somewhere to go: with no `target_position` it answers zero (measured in a probe project, with and without a navmesh region). So a path walk sets the real target, and a direct strafe or back-out sets `global_position + desired` (one second of travel). *Alternative:* skip avoidance for direct steering and for rooms with no navmesh. *Why not:* enemies would stop steering round each other the moment they strafe, and the training room would behave differently from the crowd room for no reason.

2. **No navmesh on the map (the training room) means straight steering, still through the agent.** `_has_navmesh()` asks `map_get_iteration_id() > 0` and a non-empty `map_get_regions()`; the agent is aimed at the target anyway (call 1), so its avoidance works, and the direction is the straight line. *Alternative:* a navmesh baked into `test_room`. *Why not:* the room is frozen for M3.

3. **The first run of a process starts the avoidance one tick earlier than later ones** (measured: the same punk is 0.043 m ahead in the first of three identical runs, the other two agree). `test_two_identical_runs_end_at_the_same_positions` runs a short warm-up first and compares the next two. *Alternative:* compare across two processes. *Why not:* GUT runs one process; a separate process per run is for P1-int's soak.

4. **`EnemyAttack.weight_property` names a chance, not a weight.** The attacks with a property are rolled in order against their chance (`punk_shove_chance` 0.3); those without share what is left. *Alternative:* normalised weights (the Punk would need a tunable for the punch too). *Why not:* the tunables S0 declared are all called `..._chance`, and the Punk then needs one tunable, not two.

5. **The attack is picked when the token is granted (and previewed when it re-arms), through the overridable `_choose_attack()`.** The boss picks by range, and the range is only known at the token. `attack_range_m()` answers for the preview before it. *Alternative:* fix it when it re-arms. *Why not:* the boss's charge-or-grab-by-distance would have to be decided seconds before.

6. **The cross steps in 0.3 m over its active frames, and its `reach_m` (1.36) includes the step.** Without it the second hit was a coin flip: the jab's flinch pushes the player about 7 cm back, the Punk stands at reach minus the margin (0.95 m) and the cross's strike reaches 1.06 m, so the chain landed or missed on a millimetre. *Alternatives:* a shorter jab knockback; a smaller engage margin. *Why not:* both change how the jab feels, and the margin is every archetype's. The rear warning and the engage distance read the opener's reach, so the cross's longer one changes neither.

7. **A chain link needs `_move_landed_hit`, and a blocked jab ends the chain through its recoil.** A2.14 says "landed or blocked"; the jab's `blocked_recoil_frames` (20) cuts a blocked jab short before any link could start, so for the Punk "blocked" means the chain ends in the punish window. The chain code would continue after a block for a move with no recoil (the heavies). *Alternative:* a recoil-free jab that chains after a block. *Why not:* it removes the punish window SPEC §5 gives the player.

8. **The token is released when RECOVER starts (A3.1), and the cooldown starts there.** *Alternative:* at the end of the back-off. *Why not:* A3.1 says so, and the director then hands the token to the next waiting enemy while this one walks away, so the crowd keeps its pace.

9. **`wants_token()` is true only in POSTURE (not APPROACH or RECOVER), and not mid-taunt.** *Alternative:* any free state. *Why not:* an enemy walking in would be granted a token from across the room and arrive already attacking; a taunt cut short by a wind-up would pop from the beckon to the cocked fist, the one thing the taunt must never look like.

10. **A strafe picks a random side but heads back once it is off the slot by more than `enemy_slot_reach_m`, and ends at a leash (`posture_wander_m`, new tunable, 1.5 m).** *Alternatives:* always alternate sides (reads as pacing); one orbit direction (the ring drifts as a whole, against the director's even spread). *Why not:* random with a leash reads as circling and stays near the slot the director chose.

11. **With no slot the Punk postures at the nearest spot of the ring on the line from the player.** The training room has no director that grants slots (the skeleton director gives none), and F4 spawns there. *Alternative:* stand where it spawned. *Why not:* a Punk spawned 12 m away would never come.

12. **A stall asks the director through a duck-typed `report_stalled(enemy)`, and also tries its own detour** (`enemy_detour_deg` 90 and `enemy_detour_s` 2, new tunables). The plan says "asks the director for a new slot" but the S0 contract has no such method. *Alternative:* add the method to the skeleton director (not my file) or only detour. *Why not:* the call costs nothing when the director lacks the method, and the detour keeps an enemy from standing at a crate corner while waiting for one. A request is in the final message.

13. **The first control tick adds the skeleton director, deferred, instead of `_ready()`.** The plan says `_ready()`. A test double that replaces the control tick (`stub_enemy`) then adds none, so a test that adds its own `stub_director` a frame after the enemy is not shadowed by an auto-added one (`EnemyDirector.find()` returns the first in the group).

14. **`_on_armor_absorbed()` does nothing.** The plan allows a `brace` pose "additively (or nothing)", and the rig has no additive layer: playing `brace` would replace the wind-up pose on screen and read as a flinch. The contact flash is the sign; P3-bruiser adds the spark and clank (A6.1). *Alternative:* play `brace`. *Why not:* it reads as the very flinch armor is meant to remove.

15. **Armor sets the reaction to STAGGER for the tiers it names whatever it was** (a heavy that would knock down, a finisher that would launch), and leaves `breaks_armor` moves and killing hits alone. *Alternative:* only lower reactions that are weaker than STAGGER. *Why not:* the Bruiser's tests want the uppercut and the spinning backfist (finishers: launch, knockdown) to stagger.

16. **The wind-up copy is only made when the scaled startup differs from the move's own.** At `windup_mult` 1 `windup_move()` returns the shared move, so F1 edits of its damage or knockback apply at once; only a stretched or floored wind-up is a cached copy, flushed on any `moves/` change. *Alternative:* always duplicate. *Why not:* every F1 edit would need a flush to be seen at all.

17. **The jab's wind-up arm is raised higher than its first draft, its body twist is not.** In the first 2.5 m sheet the cocked fist read faintly against the guard, so the right elbow went from 70 to 82 degrees out; a bigger hip and spine twist (28 and 9 degrees) swung the arm in front of the face and failed the first-person check (the head must show at 90% through the telegraph), so the body stays at 26 and 5. *Alternative:* relax the check. *Why not:* the check is the spec of "the head stays visible".

18. **The shove's wind-up is two raised palms, elbows wide, torso rocked back, authored new rather than reusing the player's `shove` wind-up (hands at the chest).** *Alternative:* the existing wind-up. *Why not:* the Punk's two attacks must be told apart from across the room, and a raised pair of open hands reads as a push where a single cocked fist reads as a punch (the 1 m sheet shows both palms beside the head).

19. **A token holder gives up when the player is down, flying, held or KO'd, and waits while he is only invulnerable (a dodge, a get-up).** The director should not grant then, and takes tokens back, but an attack already begun at a body that cannot be hit is a wasted telegraph. *Alternative:* go on and whiff. *Why not:* it spends a token and a warning on nothing.

20. **After a reaction it goes back to APPROACH, not POSTURE, and a taunt may be rolled at every arrival.** *Alternative:* resume POSTURE where it stands. *Why not:* the director may have moved its slot while it was down, and APPROACH finishes at once when it is already there.

21. **Hit during an attempt starts the cooldown; hit while posturing does not.** *Alternative:* a cooldown after every hit. *Why not:* a punk that was jabbed while strafing would stop asking for turns for a second and a half, which reads as fear, not as pacing.

22. **Facing: ENTER faces the way it walks, APPROACH faces the player once within the ring's far edge, RECOVER's back-off always faces the player.** *Alternative:* always face the player. *Why not:* a Punk walking in from a doorway crabs sideways down the lane; and a Punk that turns its back to retreat reads as giving up (rubric 7 wants "back off", not "run away").

23. **`windup_track_share` counts from the wind-up's first frame (`move_frame < round(startup x share)`).** *Alternative:* from the commit pause. *Why not:* the commit pause is already the "looking at you" beat; the lock is what the player dodges.

24. **No avoidance for the dead.** At `health <= 0` the agent's avoidance is switched off (not at the get-up or the knockdown: a downed body is still steered round).

25. **The Punk's look:** a saturated red jacket (0.82, 0.12, 0.20) with yellow accents (cap, glove straps, shoes), against the dummy's orange and dark grey. *Alternative:* a blue jacket. *Why not:* red-and-yellow stays readable against the grey street and the player's blue sleeves in the sheets.

26. **`tests/bot/punk_bot.gd` uses `tests/fixtures/stub_director.gd` for the token act** (the real director is P1-director's). *Alternative:* wait for the merge. *Why not:* the commit pause and the step-in are judged from the lens before the slice, and the fixture is the plan's way for packages not to wait on each other.
