# M3 final review: the boss's strike poses (pound and slam)

What the final review's tells lens found in the boss's two strike poses, the numbers before and after, and the corrections to earlier calls. The judgement calls are in `fix-final-boss-poses-and-pipe-rest.md`. Measured with the real `FirstPersonCamera` and `FPView.nearest_mesh()` (the least distance from the lens to any mesh of the boss, the arm's-length rule of 0.25 m), deterministically, at 60 Hz.

## The ground pound (final-tells-01)

The strike and strike-end keys folded the 2.3 m body 72 degrees over its knees (spine -32, chest -26, upper chest -14, neck +28, head +18 on a deep squat), so the head travelled 0.67 m forward and 0.72 m down in the last seven frames of the wind-up (from the held key at frame 29 to the strike at 36) and stayed there through the hitstop: at 0.9 m the cap was in the lens. The strike is now a squat: the hips drop 0.33 m below the guard's (the same deep legs as before), the spine is near vertical (spine -5, chest -4, upper chest -3, neck +6, head +4: the head 0.09 m ahead of the hips at the strike key, 0.12 m at its end, against 0.50 m), and both fists are driven down in front of the knees (0.70 m up, the hips at 0.88 m; raise 18 to 24 degrees, the elbows nearly straight). The follow-through key carries the arms out wide and low (raise 10, roll 64) instead of the guard's fists, so a pound that misses (the player is in a get-up's invulnerability, or a jump clears the ring) does not bring the fists up through the lens on the way to the guard. The held overhead wind-up key, the joint limits and `reach_m` (the ring is the arc's, not the pose's: measured 2.62 m against 2.60) are untouched, and the move's timing is unchanged, so `tools/gen_moves.gd` and the `.tres` files are as they were.

Nearest boss mesh to the lens from the held wind-up key through the hitstop and the player's flight (`tests/test_boss_close_lens.gd`, the player standing in front of the boss and taking the hit):

| player from the boss | before | after |
| --- | --- | --- |
| 0.8 m | 0.000 m (cap) | 0.404 m (the strap on the chest, mid-swing of the arms) |
| 0.9 m | 0.000 m (cap, f35) | 0.406 m |
| 1.1 m | 0.105 m (cap brim) | 0.469 m |
| 1.3 m | 0.298 m | 0.548 m |
| 2.2 m (`test_boss.gd`, untouched) | 1.55 m | 1.55 m |

The 0.9 m case clears, so no pose-only limit applies and **the fallback, excluding the pound under about 1.4 m in `Boss._choose_attack()`, is not needed** for the lens. (The player stands at about 1.05 m after his magnetism; 0.8 m, a step nearer than he is likely to get, is 0.40 m.) At 0.9 m the boss's own torso fills the view in any pose, as it does in its guard (0.45 m from the lens at 0.9 m before the attack starts), which is distance, not the pose; the first-person sheets (`captures/fix/pound`, local) show the black torso, the arms swinging down and out to the sides, the hit, and the boss squatting with its head up and its fists down: never the cap, no orange fill.

A pound that does not land (the same player under a get-up's invulnerability, `test_a_pound_he_does_not_take_keeps_clear_of_the_lens_through_its_follow_through`) is as clear through the follow-through key: 0.406, 0.469, 0.548 m. The follow-through's rise back to the guard, on the way out, passes 0.24 m at 0.9 m (0.35 m at 1.1 m, 0.48 m at 1.3 m): the guard itself is 0.45 m from the lens at 0.9 m, and a standing player at 0.9 m is a rare case there. I did not hold that part to the rule (the finding is the strike's, through the hitstop).

### Correction to P3-boss.md call 11

Call 11 judged the boss's wind-ups from the ring (2.5 and 4.0 m) because "the only attack it throws from that close is the grab". That premise was wrong. `Boss._choose_attack()` makes the pound eligible at any range (50% under `boss_charge_min_m`, all of it with two or more others near), the pound's wind-up is armored and uninterruptible (a heavy hit is absorbed while it winds up), and the player's own magnetism brings him to about 1.05 m of the boss whenever he punches it. So the pound is thrown at, and past, a metre in ordinary play. The wind-ups are still judged from the ring for the telegraph's read (call 11's head-over-the-top reasoning stands for the wind-up), but the strike, the part that comes to the lens, is now judged from 0.9, 1.1 and 1.3 m as well (A6.3's clearance rule). `docs/ARCHITECTURE.md`'s "1.2 m for the pound" (the nearest boss mesh, measured only from 2.2 m) should read 0.41 m at 0.9 m, 1.55 m at 2.2 m; it is the lead's file.

## The grab slam (final-tells-04)

The slam's strike folded forward like the headbutt's (spine -34, lean 0.14 against the headbutt's -32 and 0.12), so the last fifth of its wind-up, from the held player's lens, was the boss's cap filling the view (0.115 m from the lens one frame before the strike, while he was still held), then BOFF: the Bruiser's headbutt picture, with the boss's signature 25-damage move told apart from it only by the throw after. The strike is now a heave: spine +10, chest +8, upper chest +4 (the torso arches back), the hips leaning back 0.06 m, the legs straightened, the head's pitch holding the eyes on him, the arms up and out (raise 112, yaw -6, roll -34, the elbows 14 degrees) at the frame he is let go. From the lens: the head and cap sink a little as he is lifted, hold and tremble at the top, then the arms fly up and out on both sides of the view as the boss rears back, BAM, and he is thrown up and away (`captures/fix/slam` against the headbutt in "Bruiser headbutt"; `captures/fix/slam_side` for the pose). Measured on the rigs: from the held key to the strike the slam's head goes 0.46 m **back** (0.17 m ahead of the feet held, 0.29 m behind them at the strike), the headbutt's goes 0.31 m ahead.

Held-view clearance (`test_player_grabbed.gd`, now to the slam's strike frame, the tick before the release; the headbutt's check still stops at the held key, its dive being deliberate): the nearest boss mesh to the lens is 0.26 m (the right fingers, tick 42, the held wind-up key's own pose, which is unchanged: the drive-in adds nothing nearer) against 0.12 m before.

The release itself is as before: `EnemyHold._strike()` lets him go and applies the THROWN hit (25 damage, knockback (0, 4.5, 6.0)) at the strike frame, so the throw's direction is the same up-and-away, and `held_lift`'s victim pose and its 0.4 s settle are untouched.
