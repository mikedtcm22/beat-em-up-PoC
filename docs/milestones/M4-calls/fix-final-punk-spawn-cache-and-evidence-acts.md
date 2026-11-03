# M4 calls: fix-final-punk-spawn-cache-and-evidence-acts

The final review's package for final-v6-01 (the Punk's art cache dies with the warm-up rig), final-v2-03 (C5/C13 frame the KO body almost out of view) and final-v4-04 (C9 walks into its own cast). Each call is the decision, an alternative not taken, and why. The SL-int call for the cache is C11 in [SL-int.md](SL-int.md), the act calls are in [L0-bench.md](L0-bench.md) sections 6 and 8.

## 1. final-v6-01: the warm-up's art is held in a static on `RoomKit`

- **Decision.** `RoomKit._warm_art` (a static `CharacterArt`) is loaded by `RoomKit.warm_art()` and held for the run; the throwaway rig is `RoomKit.build_warm_rig(room)`, which `warm_up_art()` calls and frees as before. `release_warm_art()` and `warm_art_held()` are for the tests and the W1 act.
- **Alternative.** Make `SkinnedArt.Entry.art` a strong reference (the reviewer's second route, which needs `skinned_art.gd`); or hold the art on the room node.
- **Why not.** The strong entry removes the weak cache's behaviour for every art (a freed art would stay in the cache until `clear_cache()`), which ARCHITECTURE documents as intended. A hold on the room dies with the room: after an F6 switch the first Punk of the other room reads the GLB until its own warm-up has run. A static is what the hero's art already is (`PlayerCharacter._hero_art`), costs one resource, and `skinned_art.gd` stays untouched.

## 2. final-v6-01: the rig's building is split out of the windowed gate

- **Decision.** `warm_up_art()` is still windowed only and does nothing headless (`test_art_punk` and `test_flash_fp` assert it), but the rig it builds is `build_warm_rig()`, callable headless, so `tests/test_art_warm_cache.gd` drives the same call, frees the rig the way the room does and reads the cache.
- **Alternative.** Let `warm_up_art()` build and hold the art headless too.
- **Why not.** Headless `warm_up_art()` adds nothing by contract, and a hold in every headless test would change which tests read the GLB cold. The windowed side is checked by the W1 look act instead (`LOOK-WARM <room>: OK ... the Punk's art held after its rig is freed: true`, both rooms, run windowed here).

## 3. final-v6-01: "no read" is the Entry's identity

- **Decision.** The test asserts that `SkinnedArt.entry_of(art)` after the rig is freed and after a Street Punk has spawned is the very `Entry` the warm-up's rig made (`assert_same`); `_read()` runs only for a new `Entry`. The spawn timings are printed as `ART-WARM ...` lines and not asserted. A test that an art nothing holds still drops out of the cache (a duplicate of the art, freed) keeps the weak design honest and prints what a read costs (`ART-WARM a read of punk.glb ...`, 16 to 19 ms).
- **Alternative.** A read counter in `SkinnedArt`, or an assertion on a millisecond figure.
- **Why not.** A counter needs a change in `skinned_art.gd`, which the weak route does not otherwise touch; a clock on this shared machine is noise (3 to 4 ms against 17 to 19 ms is clear, but not a thing to fail a suite on).
- **Checked.** With `warm_art()` not storing its art, four of the eight tests fail (the art dead, the entry new, the reference count); with it, all pass. The first Punk after the warm-up spawns in 1.3 to 4.5 ms and the first Punk of the next wave in 1.1 to 2.1 ms with the hold, against 17.6 to 19.3 ms (V6: 18.7 to 19.2 ms) without it.
- **Found by the first full run.** Other test scripts preload the Punk's scene (`test_enemy_actor`, `test_kicker`, `test_bruiser` and others), which holds `punk_art.tres` too, so in a whole-suite run the art is not freed when the room kit lets go: my first control test ("let go of the hold and the old failure comes back") failed there, and the entry-identity tests would be masked (pass without the fix) in such a run. The game has no such holder (`look_acts.gd` is kept free of `StreetPunk` for the same reason, SL-int C10). So the control test is gone, and a test counts references instead (`get_reference_count()` goes up by exactly one with the hold and back with its release), which holds whatever else in the run keeps the resource alive. The entry-identity tests still fail without the fix when the file runs alone (`-gselect=test_art_warm_cache`).

## 4. final-v2-03: the KO view is -35 degrees, set once the KO state starts

- **Decision.** In `LookActs._reacts` (C5 and C13) the finishing jab, its flash and the launch are seen at the default view; when the body's state is KO the view pitches to `KO_PITCH_DEG` = -35 over `PITCH_TICKS` (the partition said about -30), then `ko_slump`, `ko_lying`, `ko_blink_off` and `ko_blink_on` are marked (state_frame based, and the first frames the rig is hidden and shown again). The recording (`captures/fix/c5`) reads: the jab's flash, the launch, the body landing on its back with the arms out, the slump, lying, then the blink with the splats left on the floor. The head is in the upper half of the frame, the shoes on its bottom edge.
- **Alternative.** -30 degrees (the reviewer's probe): the head, arms and legs read but the shoes are cut off; -45: the horizon and the street go out of the frame, and the act looks like the C8 limbs look.
- **Why not.** -35 is the least pitch that has the whole body in. Both are one constant.
- **The pair.** The M3 side was re-cut from the commit the before pack is on (`aa6b5cd`, L0-bench) in a worktree of its own (`.worktrees/m4-fix-final-punk-spawn-cache-before-recut`, detached, nothing committed) with only the act edits (this one and the tour's) and no `look_show_art`, into `captures/m4_before_recut/c5`, `c13` and `c9`; `captures/m4_before/` is untouched. The mark frames of the two sides are identical.
- **Tests.** `tests/test_look_acts.gd`: C5 runs headless; the view is the default on the KO's first frame and -35 at the end, the five marks come in order, and the head's rectangle at the slump and at the lying is in the upper 60% of the frame (it was centred at 670 of 900 px at the default view; 427 now). The body's rectangle is not asserted: a foot sphere near the lens clips it at 900.

## 5. final-v4-04: C9's Punk and Bruiser move off the walk lines

- **Decision.** `TOUR_CAST` entry 0 (the Punk) is at rel (2.0, 3.5) and entry 3 (the Bruiser) at rel (-2.0, -3.5); the comment above the cast says where the walks go. Every entry is now 2 m or more off the player's own x axis. C9 shrinks from 1,866 ticks (both walks ran to their caps against a body) to 1,144, and its stills show the alleys, doorways, the car and the crates, with the cast beside the lane (`captures/fix/c9/tour_sheet.png`).
- **Alternative.** Steer the walk round the bodies, or let the cast walk off.
- **Why not.** `RoomActs._tour()` is the room's own act (the crowd room's tour, not mine) and walks open loop; moving two bodies is the smallest change and keeps the act's recipe for the before side.
- **Test.** `test_c9s_cast_stands_beside_the_tours_walk_not_on_it`: no entry within 2 m of the player's own line, and the act (run headless) never brings the player within 1.2 m of anyone (0.70 m before the move; 2.0 m now).

## 6. The W1 act checks the hold

- **Decision.** `_warm_up_room()` releases the hold before each room's cold load and adds "the Punk's art held after its rig is freed" to the line's OK condition.
- **Alternative.** Leave W1 as it was and trust the headless test.
- **Why not.** `warm_up_art()` is windowed, so the headless test cannot see it; W1 is the one act that loads the room as the game does.
