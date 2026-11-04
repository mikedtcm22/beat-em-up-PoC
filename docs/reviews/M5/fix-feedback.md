# M5 playtest feedback: package FEEDBACK

Game-boy played the M5 build on 2026-11-04 and said this, word for word:

> Mostly good, I think. Basically only annoying thing I'd say was any instance where there was just me and one of the enemies who try to attack from behind and the fight was just them trying to maneuver behind me the whole time (so a LOT of whiffs). We should set up the attack rules so that the effect is that certain enemies will get behind you *opportunistically* when you're fighting other enemies — but I don't want the 1-on-1 behavior to look like the enemy is constantly trying to just run around you.
>
> We don't have to wait for enemies to spawn when my back is turned. I think that makes it seem like there's a lot of nothing going on and then suddenly you're hit from behind.

Both items are his rulings, so they are not spec questions. Build them as written below. One builder, one branch (`m5/feedback`), with a commit per item or a few. Finish with `M5 FEEDBACK: ...`.

## Item 1: Kickers flank opportunistically

**What happens now.**
- The Kicker (`prefers_blind_side`, 360° arc) always takes the seat nearest directly behind the player's look:
  - `EnemyDirector._assign_arcs()`, its `flank` list, `_flank_order()` and `_flank_angle()`;
  - with `director_even_spread` on, the same in the even-spread path.
- In view, it strafes toward the nearer edge of the view (`Kicker._pick_strafe_dir()`).
- It circles at `kicker_circle_mult` (1.6x).
- So in a one-on-one (A4 after its Punk is down, or A6's second wave once the Punks are down), every turn toward it moves its seat behind him again. It runs round him the whole fight, and he whiffs.

**The rule to build.** A Kicker *flanks* (today's behaviour) only while the player is busy with someone else. Otherwise it is seated like every other enemy, by its own arc.

**Busy:**
- At least one other live, engaged enemy that is not itself flanking stands inside the player's view (`player.is_outside_view(pos, rear_warning_angle_deg)` is false) and within `kicker_flank_busy_radius_m` of him.
- The radius defaults to 4.5 m, the token reach: `posture_ring_max_m` 4.0 plus `token_grant_margin_m` 0.5. Say so in the tunable's docs; don't derive it in code.
- "Not itself flanking" is read from the previous tick's decision, so two Kickers don't depend on each other circularly. The first Kicker stays put in front, and a second one counts it as busy and may flank.

**Hysteresis, per Kicker:**
- It starts flanking once busy has held for `kicker_flank_on_s` (default 0.5 s, the engage grace).
- It stops once busy has been false for `kicker_flank_off_s` (default 1.0 s).
- So a glance at a Punk, or a quick turn past one, doesn't flip it.
- Time these on the director's own clock (`_clock_s`), never wall time.

**Flanking:** exactly today's behaviour. That's the seat nearest directly behind the look (the others never move for it), the strafe toward the edge of the view, and the fast circling.

**Not flanking:**
- It goes through the same path as the other arc enemies: keepers, then seekers, `_find_inner()` nearest its bearing, then `_find_wait()`. Its arc is `attack_arc_deg()` (360) about its line.
- So it takes the inner seat nearest where it stands, and keeps that seat as the player turns, the way a committed Punk does.
- It strafes in POSTURE as any enemy does (the base `_pick_strafe_dir()`, not toward the view's edge).
- It circles at the base speed (no `kicker_circle_mult`).
- One-on-one, it squares up wherever it is and fights face to face once he turns to it.

**Switching mid-fight:**
- A token holder keeps its seat until its attack ends (the existing holder rule). A Kicker that is winding up behind finishes from there.
- The mode change applies at its next reslot as a non-holder.
- Make sure a change of mode triggers a reslot. Today's reslot triggers are the clock, a request, the player moving, and the member set changing.

**The hook:**
- The director decides and tells the enemy through a new director hook on `EnemyActor`: `set_flanking(on: bool)`, read with `is_flanking()`. It defaults to false; the director is the only writer.
- `Kicker._pick_strafe_dir()` and `Kicker._circle_mult()` read `is_flanking()`.
- `prefers_blind_side` stays and means "may flank".
- Add the hook to ARCHITECTURE.md's director contract, beside `grant_token()`, `revoke_token()` and `set_slot()`.
- Expose `debug_is_flanking(enemy)` on the director if the tests need it.

**Switches:**
- `kicker_flank_opportunistic` (bool, default true). Off restores M5's always-flank, so it keeps the earlier value reachable.
- With `director_even_spread` on, M3's rule stays as it is (always flank).
- Put the new tunables in Tuning's "Kicker" subgroup, with `##` docs and `@export_range` on the numbers.
- Regenerate `tuning/default.json` with `godot --headless -s tools/gen_default_preset.gd`.

**Unchanged:**
- The blind-spot token priority (M5-2, `blind_spot_eligible()`, `blind_spot_priority`).
- The other archetypes' arcs.
- The engage book and `engage_commit_s`.

**Tests (tests/test_kicker.gd, tests/test_enemy_director.gd, tests/test_attack_arcs.gd; new files if they grow):**
- **One-on-one, standing:**
  - A lone Kicker that engages in front of a standing player (god mode, director running) never takes a seat more than `rear_warning_angle_deg` off the look.
  - Every wind-up starts inside the view.
- **One-on-one, turning:**
  - The player turns 90° and then 180° (instant `look_yaw` writes, each held 3 s).
  - The Kicker's seat angle in world terms changes by no more than a seat gap or so after each turn: it does not follow the look round.
  - It isn't flanking at any time.
- **Busy:**
  - A Punk engaged in front within the radius: the Kicker is flanking within `kicker_flank_on_s` plus a tick or two.
  - Its seat is the one nearest directly behind the look, as today.
- **Busy ends:**
  - The player turns to the Kicker, so the Punk leaves the view.
  - The Kicker stops flanking after `kicker_flank_off_s`, and not before.
- **Hysteresis:** a 0.2 s glance (busy for 0.2 s) never starts flanking.
- **Two Kickers alone:** they don't both flank. At least one is not flanking at any time once both are engaged.
- **Switch off:** with `kicker_flank_opportunistic` off, a lone Kicker goes behind the look, as M5 did.
- **The existing tests that assume a lone Kicker goes behind:**
  - Give each one a busy Punk in front, or turn the switch off in that test. Choose per test by what it is about.
  - "Flanking works" tests get a Punk; "a seat of its own behind the look" geometry tests may use the switch.
  - These include `test_a_kicker_takes_a_seat_of_its_own_as_near_directly_behind_the_look_as_it_can`, `test_two_kickers_take_seats_of_their_own_behind_the_look_and_the_others_keep_their_ring`, `test_a_kicker_moves_nobody_else_when_the_look_turns`, `test_the_kicker_circles_to_directly_behind`, `test_the_kicker_walks_round_the_ring_to_the_back_and_never_across_the_front`, `test_a_kicker_that_is_in_view_strafes_toward_the_edge_of_the_view` and `test_a_lone_kicker_flanks_in_the_crowd_room_and_its_wind_up_behind_lights_both_corners`.
  - Grep for the rest.
- **Readability (the M3 rows, as M5 re-measured them):**
  - Every hard row must still hold in the arc and Kicker probe acts.
  - Don't move a threshold. If a row moves, log it in your calls file and tell the lead.

**Bot acts (tests/bot/acts/kicker_acts.gd):**
- `"Kicker flanks"` today spawns a lone Kicker and expects it behind. Rework it so a Punk holds the front and the Kicker flanks; keep the title.
- Add `"Kicker one on one"`:
  - The player in god mode fights a lone Kicker with the autopilot, which turns to face what attacks it (see how `Run: held back` drives it in `tests/bot/level_bot.gd`), for about 30 s.
  - Each second, log a line with the Kicker's bearing off the look, its distance, its state and whether it is flanking.
  - This is the act that shows Game-boy's case.
- Add `"Kicker opportunist"`: a Punk and a Kicker, with the autopilot fighting the Punk. The Kicker gets behind, and once the autopilot turns to the Kicker, the Kicker stops circling.

## Item 2: Spawns don't wait for your back

**What happens now.** A named spawn point flagged `out_of_view` (the six "behind" points in street.tscn and roofs.tscn) holds its spawn while the point is inside the player's view. After `spawn_named_wait_s` it falls back to the nearest free out-of-view point, and after `spawn_named_any_wait_s` more to any free point (`EncounterSpawner._spawn_named()`). That's the lull Game-boy means.

**Build:**
- A switch `spawn_behind_waits_out_of_view` (bool, default **false**) in Tuning, beside `spawn_named_wait_s` in the Level group.
- Off: the `out_of_view` flag is ignored. A behind point is used like any named point: at once when it is free and not nearer than `spawn_min_player_distance_m`, with the existing tag fallback after `spawn_named_wait_s` only when the point itself is not free.
- On: today's behaviour, exactly.
- Keep the flags in the scenes and the A4 door recess as they are.
- Update the docs on `SpawnPoint.out_of_view`, the spawner's class docs, `_spawn_named()` and the tunables, so they say the hold is behind the switch.
- The four `test_encounter_spawner.gd` tests for behind points set the switch on, since they test that mode.
- Add a test that with it off, a behind point in view is used at once (no wait).
- Check test_m5_street.gd, test_m5_roofs.gd, test_m5_done_when.gd and test_level_kit.gd for anything that relied on the hold.
- Also check for any other path that delays a spawn by the view, and say in your calls what you found. Leave `wave_behind_share`, which picks a point rather than waiting.

## Done when
- Both items are built, with the tests above.
- Each touched test file passes alone, and then the full suite passes once (`tools/run_tests.sh`) with no `SCRIPT ERROR`, `SHADER ERROR` or `ERROR` lines. Report the count and time against 1748 tests and 293 s.
- `tuning/default.json` is regenerated.
- ARCHITECTURE.md is updated: the director contract and the Kicker's rule.
- **Recordings and a first-person look:**
  - Record `"Kicker one on one"`, `"Kicker opportunist"` and `"Kicker flanks"` with `tools/record_acts.sh <your worktree>/captures/feedback "<slug>|<title>" ...`.
  - Record A4 held back with the level bot: `BOT_SCENE=res://tests/bot/level_bot.tscn CAPTURE_ARGS="--level=res://game/level/mission1/mission1.tscn --from=3 --to=3"`, slug `a4`.
  - Judge them from the sheets. In the one-on-one, the Kicker squares up and attacks from in view, and doesn't run round. In the opportunist act it gets behind while the Punk is busy with him.
  - The lead's "before" recording of A4 is in captures_dir (`before/a4/`), for comparison.
- Your calls go in `docs/milestones/M5-calls/FEEDBACK.md`: the radius and timing defaults and why, the tests you switched against the ones you gave a Punk, what you saw in the recordings, and anything left open.
- Don't touch README.md; the lead writes Game-boy's rulings there.
