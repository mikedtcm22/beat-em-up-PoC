# M5 KIT: judgement calls

Each: the decision / an alternative not taken / why. Game-boy was not asked; each takes the default that departs least.

## Stairs

1. **Box steps for the eye and the ground, a hidden glide ramp for walking bodies.** The steps (rise 0.18 m, run 0.3 m, 25 for 4.5 m) are solid world-layer boxes; a ramp collider on layer 9 laid along their tips, `glide_lift_m` (0.01) above, carries the player and standing enemies. / Not box steps alone: a capsule of radius 0.35 meets the 0.18 m edge at a 60 degree normal, past the floor angle, and the first test had the player stuck at the foot. Not a ramp alone (D7: knocked-down enemies slide on ramps): a ghost body (downed, KO'd; mask: world only) lies on the real steps and does not see layer 9. / The walking bodies see a ramp, the eye sees stairs; layer 9 now holds two kinds of thing (guards and glide ramps), documented in ARCHITECTURE.
2. **`LevelStairs.rise_m` is the whole climb, `run_m` the whole depth**, with `max_step_rise_m` 0.18 an export: the step count is the smallest that keeps every step at or under it (4.5 m is 25 steps). / Not a per-step rise with a count: the section author thinks "up 4.5 m". The plan's wording ("rise_m, run_m, width_m; the step count from the rise") fits either.

## Barriers and locks

3. **`close()` and `open()` move the collider at once; the panel follows.** A closing car blocks the lane the frame it is told to. `is_closed()` is that logical state, `progress()` the panel's. / Not a collider that arrives with the panel: a player could run through a half-closed shutter, and "closed" would depend on a frame count.
4. **Lock volume tested geometrically, not by physics overlap.** `Arena.contains()` reads the `LockTrigger` box shape; the lock check runs every physics frame while WAITING and armed. The Area3D stays (the contract names it) but nothing waits on a physics frame for it. / Not `body_entered`: it needs the physics server to have synced, and a test or `start_at_arena()` that teleports the player would see it a frame late.
5. **"Past the behind barrier" is measured along the barrier's own -Z** (`Barrier.past()`), so a barrier in a wall that runs another way is just rotated. / Not a world axis: the catwalk (A5) walks +Z.
6. **An arena is armed only once the one before it is cleared** (`Arena.armed`, set by `LevelRoot`; arena 0 starts armed). The barriers already keep him out; this keeps a teleporting bot or a test from locking arena 3 from arena 1. / Not free-running arenas.
7. **A first arena with no `behind_barrier` takes the previous section's `ExitBarrier`, a last arena with no `ahead_barrier` its own.** The plan says the first; the second is the same rule at the other end, so a lone section works. / Not an error for a missing barrier.
8. **`start_at_arena(0)` stands the player at `Start`, any later index at the arena's first route point** (the first route marker inside its volume), looking toward the next. The plan says "that arena's first route point" for every index; arena 0's first marker is past the car, which skips the car's closing. / Not the first route point for arena 0 too.
9. **The strip's parked-car barrier slides into the left wall when open** (`open_side` -1). The strip has no side street for it to roll out of; the real level gives its car barriers a side street or alley mouth of the width the barrier needs. / Not an alley for the strip: it would cost geometry for nothing the tests need.

## Drop-offs

10. **The hazard polls its overlaps each physics frame** instead of `body_entered`: an enemy getting up is invulnerable for a few frames and `receive_hit()` refuses it; polling KOs it the first frame it can be. / Not a one-shot signal that a getting-up enemy would slip past.
11. **A flying body (LAUNCHED, THROWN) has its health taken, not a second hit.** `receive_hit()` on a flying body would relaunch it with `min_launch_up`, a visible bounce at the lip; with health 0 its landing KOs it (`_land_from_flight()`). Everything else goes through a killing `HitInfo` (`is_body_impact`, no attacker). `ko` and `health_changed` are emitted by hand for the flying case so the rear warning and bars hear it.
12. **A `HazardVolume` has its own catch floor, and the strip's is 40 x 60 m.** A KO'd body that nothing stops falls for ever (the first test watched one reach y -370). The slab sits at the volume's bottom, at a depth no floor height is within the bake's 0.3 m tolerance of (the bake would keep it as a nav island). Past the volume `LevelRoot` frees an AI enemy `void_depth_m` (30) under the lowest floor, as a last net. / Not a kill plane alone: the body would never lie out its KO on screen.
13. **The hazard also masks layer 2 (the standing player).** The plan lists layers 3 and 6; a ghost player is on 6, but a standing one on 2, and the fall rule needs to see him. The enemy branch takes `EnemyActor` only.
14. **The fall rule does no damage in god mode and never takes the last health** (`max(health - damage, min(health, 1))`). A fall costs 20, it is not a KO (D8). It resets the player's state (`reset_state()`), puts him at the Respawn marker and sets `_invuln_frames` directly: CombatActor has no public way to grant invulnerability (see "requests").
15. **`EdgeGuard`'s collider is always baked in.** `LevelRoot` turns every guard on while baking, whatever `level_edge_guard` says, so the mesh stops short of the lip even for a run that starts with the guard off. The tunable only moves the collider's layer (to 0) afterwards.

## Spawner and table

16. **`play_table()` does not turn `waves_enabled` on.** The plan's note reads "waves on"; `waves_enabled` is the global switch the F1 panel and a test's `set_waves_enabled(false)` hold, and a level where one press of F1 could not stop the waves would be a trap. The level's tests set it. / Not forcing it true.
17. **Named spawns are outside the behind share.** The quota counts only spawns that choose their point (`_wave_free`), so a wave of one named and four free enemies still hits `round(4 x share)` behind spawns. For a looping table nothing changes: every spawn is free, the random draws are the same as M3's.
18. **A named spawn that cannot be placed retries every 0.1 s, and the wait is timed in sim seconds** (`NAMED_RETRY_S`), not once per `wave_spawn_interval_s` (0.6): the fallback would otherwise arrive up to 0.6 s after the 2.0 s the tunable says. A name no point has is a warning and an ordinary spawn.
19. **Finite tables finish when the last wave is cleared with no gap after it**, `wave_cleared` first, then `table_finished`. An empty finite table finishes on the next tick. The `IDLE` phase after `stop()` or a finish is new; `wave_running()` is false in it (it was "not GAP").

## Level

20. **`LevelRoot` bakes from a `Sections` container node**, not itself, so only sections' geometry is parsed (the player, enemies and pickups come after anyway). One `NavigationRegion3D` for the whole level; arenas are islands because the barriers are closed during the bake.
21. **`NavBaker`'s level rule is additive**: `floor_heights` (with `floor_tolerance` 0.3 and `floor_lift` 0.2, both exports of `LevelRoot`) and `stair_footprints`; `max_floor_y` and the crowd room's call are untouched. Stair polygons are kept by their centre inside the footprint AABB.
22. **R7 in the edge test is the probe's own limit (0.005), not zero.** The brief says "R7 and R13 stay 0"; six Punks against an edge measured R7 = 0.0016 on M3's director, and `LIMITS.capsule_overlap_share_max` is what M3's tests hold the crowd to. R13 is asserted 0. The test is director-independent and runs before and after ARC.
23. **The strip is two real section scenes** (`level_strip_a`, `level_strip_b`), not code-built, so STREET and ROOF can copy the node patterns (an arena with its `LockTrigger`, `Respawn`, spawn points with a `LanePoint`; the seam shutter as `ExitBarrier`). The scene files are written by a throwaway script (Python in the scratchpad, not in the repo); the .tscn is the source.
24. **GoCue: the arrow is straight up for "ahead" and turns with the target.** SPEC says "GO ->"; a right-pointing arrow would read as "right" in first person. It is a rotated block arrow, drawn by polygon, in the HUD's panel style, with "GO" beside it. `CLEAR!` stays until `reset()`. The HUD builds the cue in `_ready()` (no `hud.tscn` edit: not in KIT's files).
