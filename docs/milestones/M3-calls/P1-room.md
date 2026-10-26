# M3 judgement calls: P1-room

Calls the P1-room builder made where the plan left a gap or had two readings. Each is a decision, an alternative not taken and why. Game-boy was not asked (no grey-block feel questions): the default that changes least was taken.

1. **Waves on or off is one switch, the tunable `waves_enabled`; `EncounterSpawner.set_waves_enabled()` writes it.** The F1 panel's checkbox, the F4 button, a bot's `set_waves()` and the room's `waves_enabled_on_start = false` all end in `Tuning.set_value(&"waves_enabled", ...)`. *Alternative:* a flag on the spawner next to the tunable (both must be on). *Why not:* two switches for one thing, and `Tuning.reset_to_default()` in a test's setup would not reset the spawner's. The cost: a cheat toggle marks the preset "unsaved", as any edit of the Enemies group does.

2. **The boss wave is its own wave, played after every `boss_wave_every` regular waves** (waves 1-4, the boss, waves 5, 1, 2, the boss...), the ids in `EncounterTable.boss_wave` (default `["boss"]`). *Alternative:* the boss added to every Nth wave. *Why not:* a wave of up to six plus a boss is over the cap of six, so the boss would spawn last, after the others had fallen; alone it is a fight of its own, and the boss calls in its own two Punks at half health (`spawn_adds`). Until the boss merges, its id is replaced by the Punk, so the wave is one Punk.

3. **While a menu is open the waves' timers stop; they do not keep running and spawn on close.** A2.2 says "waves start no spawns". *Alternative:* count the gap down behind the menu and let the spawn happen the moment it closes. *Why not:* closing F4 after reading a tunable would drop a wave on the player at once, the thing the hold exists to prevent.

4. **An invisible barrier (8 m high) stands on the south curb**, over its 0.6 m of drawn height. The plan has a low curb on the near side (so the side-view camera sees the street) and no floor beyond it; a jump (`jump_velocity` 6.5) clears 0.6 m and falls out of the world (the test fails without the barrier: z 17.7, y -36). *Alternatives:* a higher curb (breaks the side view), a floor margin beyond it (a navmesh island the director may snap slots onto; the plan forbids wide margins), a kill plane (a visible fall). *Why this:* it changes nothing the camera or the navmesh sees. The ground and skyline beyond the curb are drawn only, so looking across the street shows a city.

5. **The vehicle spawn point is the strip between the car's far face and the curb**, at the car's x (`z` 5.1: a 1.8 m gap, 0.8 m of navmesh after the agent radius). The plan fixes the car at (-5, 0, 3.5) and asks for "the far side of the parked car". *Alternative:* move the car out so the strip is wider. *Why not:* the plan's place stands; the strip is enough for the 0.35 m body, and a test checks it is on the navmesh with a path to the lane.

6. **The crates and the dumpster sit a little off the plan's coordinates** (crates (5.6, -4.6) and (6.55, -5.1), dumpster (12, -5), against "near (7, -4.5)" and (11, -5)), so each doorway mouth (x 8..10) keeps 1 m clear on either side. *Why:* the navmesh erodes 0.5 m from every obstacle, so a 1.4 m gap closes the mouth and the east doorway's enemies would have no path out the short way.

7. **Spawn points are computed from the layout, inset by the agent radius plus `spawn_inset_m`**, not typed in. *Alternative:* literal coordinates. *Why not:* changing a wall's depth or the navmesh radius would silently leave a point off the mesh; a test still snaps every point within 0.3 m.

8. **Alleys and doorway recesses are drawn dark** (the same near-black), and the alley floors and walls too. *Why:* with the sun on the end walls the alley mouth read as part of the wall in the first tour sheets; a dark opening reads as "someone can come out of there" from across the street.

9. **The facades carry rows of drawn-only windows.** *Alternative:* plain slabs, like the training room's backdrop. *Why not:* turning on the spot in front of a featureless wall shows nothing moving, and the crowd test is judged from first-person sheets.

10. **`spawn_enemy()` has an optional fifth parameter, `lane_point`,** beside the contract's four. Without it, `enter_from(at, at)`: the F4 spawn is already where it walks to. *Alternative:* look the point up by position, or add a second method. *Why not:* a lookup by float equality is fragile.

11. **Adds (`spawn_adds`) join the running wave and respect `spawn_min_player_distance_m`.** *Alternative:* adds outside the wave, or at any point. *Why not:* a wave must not count as cleared while the boss's call-in lives; and a point under the player's nose is no place for a reinforcement.

12. **`SpawnRoomCheck.has_room(space, radius, height, spot, exclude)` keeps the plan's signature and finds the actors through `Engine.get_main_loop()`.** *Alternative:* pass the tree. *Why not:* the plan names the five arguments; a static helper can reach the running tree itself.

13. **A wave's "behind" spawns hit a quota exactly:** `round(size x wave_behind_share)`, in a random order (the chance of the next being from behind is the quota left over the spawns left). *Alternative:* an independent coin flip per spawn. *Why not:* it would make "about wave_behind_share" a statistic and the test a flake; the plan's wave of six hands out two from outside the view every time at 0.35. If no point of the wanted kind is valid it uses the other kind; if none is valid it waits one interval.

14. **"Behind" is "outside the view" at `rear_warning_angle_deg` (55 degrees)**, so beside the player counts, as it does for the director's blind spot and the rear warning (one definition, Part C 2.1). The plan's own word is "behind".

15. **The first wave waits `wave_gap_s` after the room is ready** (no separate "first wave delay" tunable), and a point is not used twice in a row unless it is the only one. *Alternative:* start at once; pure random points. *Why:* three seconds to look around; two enemies from one doorway in a row reads as a stream, not a crowd.

16. **`waves_enabled_on_start = false` writes the tunable off; `true` leaves it alone.** *Alternative:* always write it. *Why not:* a saved preset with waves off should stay off.

17. **The F4 menu keeps `spawn_dummy()`, `reset_dummies()`, `record_posts()` and `remove_spawned_dummies()` (now: any actor it spawned) and replaces the "Spawn training dummy" button with the list and "Spawn at crosshair"** (the dummy is the first item, so the default click does what the old button did). "Remove all enemies" removes the training dummies too. *Alternative:* AI enemies only. *Why not:* the plan says all enemies; F6 brings the training room back.

18. **In a room with no spawner (the training room) the menu makes the AI enemy itself** (`EncounterSpawner.make_enemy()`, names counted by the menu) and does not create a director: the enemy base does (P1-ai's deferred `EnemyDirector.ensure()`, A: the plan's step 11). `CheatMenu.scene_override` is the test seam. *Alternative:* the menu calls `EnemyDirector.ensure()` too. *Why not:* one owner for it; both are idempotent if the lead wants a belt.

19. **The crowd bot hides the combat log as well as the help** (the combo bot hides only the help), and every act starts with waves off, AI unfrozen and the room's enemies cleared. *Why:* the log covers the right side of every sheet and the bot prints its own event lines; an act that wants waves says so. A missing archetype is replaced by the stub (a stand-in that stands still) so acts written before the merge run.

20. **`RoomKit` owns the player's avoidance obstacle class** (`RoomKit.PlayerObstacle`, a child of the player that follows `player_avoid_radius_m` live), so `player.gd` stays untouched (a hot spot, P2-grab's in phase 2).

21. **A test fixture the lead's note did not list: `tests/fixtures/spawn_probe_enemy.gd`/`.tscn`**, the S0 `stub_enemy` plus a record of what `enter_from()` was told. *Why:* the stub's `enter_from()` only keeps private fields the real base may rename. It extends S0's stub and changes nothing of it.
