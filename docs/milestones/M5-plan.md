# Milestone 5 plan: the level blockout

SPEC §12: an approved encounter plan, then the graybox level from the reference with arena locks, spawns, pickups, hazards and the boss arena. **Done when the level plays from start to boss.**
Inputs: [M5-inputs.md](M5-inputs.md) (Game-boy's attack-arc calls), [reference/encounters.md](../../reference/encounters.md) (the table he approves), [reference/dd2-nes-mission1/notes.md](../../reference/dd2-nes-mission1/notes.md).

## 0. The approach

- **Phase 1** builds what doesn't depend on the table, in parallel:
  - ARC: Game-boy's attack arcs in the director, with M3's readability metrics re-measured;
  - KIT: the level kit (sections, arenas and their locks, the three barrier kinds, the "GO →" cue, drop-offs, edge guards, stairs, pickup spots, the spawner's finite mode), proved in a two-section test strip;
  - then BOT, the level-run bot, which needs KIT's `LevelRoot` merged.
- **The pause.** The lead DMs Game-boy the encounter table and the open rear-warning question **when phase 1 launches**, not after it merges: the table doesn't depend on phase 1's code, so his answer can arrive while it builds. The level waits for his yes.
- **Phase 2** (his yes, and BOT merged): STREET, ROOF and FINALE build the level from the approved table, as three section scenes with disjoint files. FINALE adds the boss roof, the level root, the main scene and the done-when test. One post-merge fixer is budgeted for what only the whole level shows.
- **Phase 3:** the lead's look, one review round (three lenses), one fix wave (at most 3 fixers), a targeted re-check, README's departures, the PR and the final DM.
- **Done:** `tests/test_m5_done_when.gd` passes (every arena locks, fills, clears and opens in order, and the boss calls in his adds), the start-to-boss run works as a bot act, and Game-boy plays it.

## 1. Decisions taken by default

Each: the decision / the alternative not taken / why / README departure?

- **D1 Engage moment.** An enemy *engages* on its first tick in POSTURE (it reached its seat, inner or wait), or on its first APPROACH tick within `arc_engage_radius_m` (7.0) of the player, whichever comes first. The code clamps that radius to at least `wait_ring_max_m + 0.5`, so no wait seat lies outside it. It engages again when its own attack's recovery ends, and when it is FREE again after a hit reaction.
  - From an engagement until `engage_commit_s` (0.5) later, its center line is the player's look; after that, the line is a fixed world yaw (centred on the player wherever he walks) until its next engagement.
  - / Not "first wants a token": a waiter would follow the look until its turn, the gentle reading Game-boy turned down. Not "at spawn": the look then is seconds stale.
  - / The line decides where the enemy stands, so it must be fixed before or as it takes its seat. / Part of departure M5-1.
- **D2 Arcs in data.** Per archetype as tunables ("Enemies" > "Attack arcs": `punk_arc_deg` 90, `thug_arc_deg` 140, `bruiser_arc_deg` 180, `boss_arc_deg` 270, `kicker_arc_deg` 360), found by the enemy's `archetype` id (`&"punk"` reads `punk_arc_deg`; an archetype without one is 360, as in M3). A variant is an `EnemyVariant` `.tres` that overrides the arc (`punk_veteran.tres`, 140). / Not an export on each scene (F1 couldn't tune it, presets couldn't save it). / Not a departure.
- **D3 Room in the arc.** Inner seats sit on the posture ring (2.5-4 m) inside the enemy's arc, at least `director_seat_gap_deg` (40) apart: a 90° arc seats 3 Punks. With no free inner seat it takes a wait seat on the wait ring (`wait_ring_min_m` 5.5 to `wait_ring_max_m` 6.5) inside its arc. Only an inner-seated enemy is granted a token; the longest-waiting wait-seated enemy takes the next inner seat that frees in its arc.
  - **Crowd-blocked arcs wait; geometry-blocked arcs slide.** A seat that snaps off the navmesh tries, in order: (a) other angles inside the arc at its ring's radii; (b) for a wait seat, radii stepping down to `posture_ring_max_m + 1.0`; (c) if no point inside the arc is on the player's floor at all (he faces a wall or the drop), the arc's center slides round in `director_slot_retry_deg` steps to the nearest stretch with room, and the search repeats there. No seat is ever on another floor or across a closed barrier.
  - / Not "waiters walk in from the wait ring" (bunching in front). Not "no seat outside the arc, ever": a player facing a wall would have Punks with no seat at all, a jam, and a safe spot. / The A/B switch `director_even_spread` (Debug, off) brings all of M3's director back. / Departure M5-1 (Game-boy's call: it replaces SPEC §7 "Spread"; the slide is ours and is named in it).
- **D4 The Kicker and the boss.** The Kicker (360°) keeps M3's seat nearest directly behind the look. The boss (270°) keeps its wake-in-place priority only while it stands inside its arc; outside, it walks to an inner seat. / No other per-archetype code. / Part of M5-1.
- **D5 Blind-spot priority** applies only when `arc_deg / 2 > rear_warning_angle_deg` (Thug, veteran Punk, Bruiser, boss, Kicker; never a 90° Punk). `blind_spot_needs_wide_arc` (true) off restores SPEC §7's "any enemy". / Departure M5-2 (his call).
- **D6 Metrics re-measured, not weakened.** Three of M3's readability rows measure the old spread and change their population; each keeps the old row printed as information, adds a twin, and is logged old -> new in `M5-calls/ARC.md`:
  - **R5** (front-wedge crowding) counts posturing enemies within `posture_ring_max_m + 0.5` only. Twin **R5w**: no wait-seated enemy inside 5.0 m.
  - **R6** (ring adherence, median 2.5-4.0 m, p10 >= 2.2) counts inner-seated posturers only. Twin **R6w**: wait-seated enemies' distance within `wait_ring_min_m - 0.5` to `wait_ring_max_m + 0.5`.
  - **R9** (blind grants >= 60% in a crowd) counts a grant as "mixed" only when an out-of-view waiter eligible for blind priority (D5) waited; N/A when none did.
  - Every other R1-R15 and rear-warning threshold stays. One that must move is logged the same way with a twin on the visible path. `director_even_spread` on restores all of M3 (the spread, tokens to any waiter, the blind roll for any enemy, no engage line): only `test_enemy_director.gd`'s M3 tests set it. `test_m3_done_when.gd` and the readability soaks run on the new default, plus one twin soak with the switch on that asserts M3's numbers.
  - / Not a spec departure (plan metrics); README's ratchets line if any moves.
- **D7 Climbs are stairs.** The reference climbs ladders (screens 03-04, 07-08, 10). Graybox uses stair flights (rise <= 0.18 m) beside the same walls. / Not a first-person ladder climb: a new player state in `player.gd`, a fall-off rule and an enemy ladder descent, for a beat with no fighting. Not ramps: they read as slides, and knocked-down enemies slide. / Stairs keep the beat (leave the street, go up, look down at the drop), need no new controls, and keep SPEC §7's stairwell spawns (enemies come down the stairs at you, as down the ladder in 03). / Departure M5-3; a ladder climb is an M7 option.
- **D8 Edges and falls.** One invisible guard (physics layer 9, `edge_guard`) runs along every open edge.
  - It is in the player's collision mask in every state, standing and ghost (flying, downed, held), so the boss's charge or a launch can't throw him off. It is in a standing enemy's mask, so a strafe, avoidance or a flinch slide never walks one off. It is in no ghost enemy's mask, so a knocked-down, launched or thrown enemy crosses it, and a `HazardVolume` just past the lip KOs it.
  - The navmesh bake parses layer 9 too, so the navmesh stops an agent radius short of every guard.
  - With `level_edge_guard` off the player can fall: `level_fall_damage` (20), back at the arena's `Respawn` marker with `level_fall_invuln_s` (1.5).
  - / Not "a fall is a KO" (the NES lost a life; with no lives it would only be a restart). Not a player-only guard: a ghost player passes it (`combat_actor.gd` `_set_ghost()` masks the world only), and walking enemies would step off on their own. / Spec silent: README "where the spec is silent".
- **D9 Locks.** Each arena's ahead barrier is closed from the level's start; its behind barrier closes once the player is `arena_lock_inset_m` (2.0) past it, so he can't be shut on the wrong side. Adjacent arenas share a barrier. **Where a stair joins two arenas the barrier is at the stair's head, so the stair belongs to the arena below.** Kinds: rolling shutter (drops), chain-link gate (slides), parked car (rolls across).
  - Arenas are separate navmesh islands (baked with every barrier closed). **Every spawn point and its lane point lie inside its own arena, between its barriers:** a "stairwell" spawn is the stair-head landing inside the barrier, a "stair head (behind)" spawn is a door beside the stair head on the arena side.
  - / Not a lock trigger only (an open behind barrier lets the fight leak back). / Not a departure.
- **D10 One spawner.** The level has one `EncounterSpawner`; an arena hands it its spawn points and a finite table on lock. In finite mode `wave_at()` never inserts `boss_wave`; a named point overrides `wave_behind_share`; a named point within `spawn_min_player_distance_m` of the player waits up to `spawn_named_wait_s` (2.0), then uses the nearest valid point with the same tag. / Not one spawner per arena (the boss's `spawn_adds()` finds the spawner by group). The crowd room is unchanged. / Not a departure.
- **D11 Sections in one level space.** The level is a `LevelRoot` that chains `street.tscn` (A1-A3), `roofs.tscn` (A4-A6) and `boss_roof.tscn` (A7) by their `Entry` and `Exit` markers, laid out by §2's level-space table: each higher floor is set back from the one below and the walking direction alternates, as on full-map.jpg. / Not one scene (one builder, no parallel work). / Not a departure.
- **D12 Graybox weapons.** Screen 11's chain-like weapon is today's pipe at that spot; an original second weapon is M6 art. / README line (graybox stand-in).
- **D13 KO and clear.** The player's KO revives in place (`RoomKit.spawn_player`'s `auto_revive`); the arena stays locked. No lives, no game over (SPEC §1 non-goals). The last arena's clear (the boss and his adds down: its table finished) emits `level_cleared` and shows "CLEAR!"; restart is the pause menu's. / Not a restart from the arena. / Spec silent: README.
- **D14 The level is the main scene;** F6 cycles level -> crowd room -> training room. / Not a menu (non-goal). / Not a departure.
- **D15 Counts follow SPEC §9's ramp, order follows the reference** (encounters.md, "How the reference converts"). / Not the stills' counts (a still catches one moment). / Not a departure (§9 says so).

## 2. Pinned contracts

**Enemies (ARC).**
- `EnemyVariant` (`game/enemies/enemy_variant.gd`, `Resource`): `id: StringName`, `base_id: StringName`, `label: String`, `arc_deg: float = -1.0` (-1 = the archetype's tunable), `tint: Color = Color(0, 0, 0, 0)` (alpha 0 = none; the graybox marker). Files `game/enemies/variants/<id>.tres`.
- `EnemyCatalog`: `ENTRIES` may carry `variant = "res://..."`; new entry `&"punk_veteran"` (the Punk's scene, label "Veteran Punk"). `variant(id) -> EnemyVariant` (null if none); `apply_variant(enemy: EnemyActor, id: StringName) -> void`, called by `EncounterSpawner.make_enemy()` before it returns, so waves, adds and F4 all get it (F4 lists `EnemyCatalog.available()`: `cheat_menu.gd` needs no edit).
- `EnemyActor`: `variant: EnemyVariant`, `attack_arc_deg() -> float`, `seat_kind: StringName`. `set_slot(pos: Vector3, kind: StringName = &"inner")` (`&"inner"` or `&"wait"`): on a wait seat `_tick_posture()` keeps it on the wait ring (not the posture ring), facing the player, strafing only inside its arc. `wants_token()` is unchanged: the director's grant is the one place that skips wait seats.
- `EnemyDirector` read API (presentation and bots): `debug_line_of(enemy) -> float` (world yaw in degrees, `NAN` when not engaged), `debug_seat_kind(enemy) -> StringName` (`&"inner"`, `&"wait"`, `&""`), `is_committed_line(enemy) -> bool` (past its grace), `debug_arc_slid(enemy) -> bool`. F3 draws each engaged enemy's arc as two floor lines, and the wait ring.

**Spawner and table (KIT).**
- `EncounterTable`: `loop: bool = true` (false: play once, never the boss wave), `wave_points: Array[PackedStringArray]` (optional, parallel to `waves`; a spawn's point name, `""` = choose as today).
- `EncounterSpawner`: point dictionaries gain `name: StringName` and `tag: StringName`; `play_table(table: EncounterTable, points: Array[Dictionary]) -> void` (waves on, wave 1 after `wave_gap_s`); `stop() -> void`; `signal table_finished()` (a finite table's last wave cleared, adds included). Existing API unchanged.

**Events (KIT; `game/autoload/combat_events.gd`).** `arena_locked(arena: Node3D)`, `arena_cleared(arena: Node3D)`, `level_cleared(level: Node3D)` (emitted by `LevelRoot` when its last arena clears), `hazard_ko(actor: Node3D, hazard: Node3D)`.

**Level kit (KIT; `game/level/kit/`).**
- `LevelRoot` (`level_root.gd`, `Node3D`): exports `section_paths: PackedStringArray` (a missing scene is skipped with a warning, as `EnemyCatalog.available()` does), `with_presentation`, `rng_seed`, `start_arena: int`.
  - `_ready()`: environment; sections chained (section k+1's `Entry` on section k's `Exit`); every barrier closed; nav bake; barriers to their start state; the player through `RoomKit.spawn_player` (auto-revive) at section 0's `Start`; director; the one spawner; pickups; presentation.
  - API: `player`, `director`, `spawner`, `arenas() -> Array[Arena]` (level order), `current_arena() -> Arena`, `route_points() -> PackedVector3Array`, `start_at_arena(index: int)` (earlier arenas cleared and open, the player at that arena's first route point), `enemies()`. The same room contract as `CrowdRoom` for bots (`player_start`, `with_presentation`, `rng_seed`, `nav_region`). A lone section scene given to it is wrapped as a one-section level.
- `LevelSection` (`level_section.gd`): children `Entry`, `Exit` (Marker3D; local -Z is the walking direction), optional `Start`, `Geometry`, `Route` (Marker3Ds in walking order through every arena and up every stair), the `Arena` nodes, optional `ExitBarrier` (the seam barrier at its `Exit`); export `floor_heights: PackedFloat32Array` (local y of each walkable floor).
- `Arena` (`arena.gd`): exports `arena_id`, `table: EncounterTable`, `behind_barrier: NodePath`, `ahead_barrier: NodePath` (an empty `behind_barrier` on a section's first arena means the previous section's `ExitBarrier`, wired by `LevelRoot`); children `LockTrigger` (Area3D), `Respawn` (Marker3D), `SpawnPoint`s. `state` (`WAITING`, `LOCKED`, `CLEARED`), signals `locked`, `cleared`, `lock()`, `clear()`, `spawn_point_list() -> Array[Dictionary]`, `contains(point: Vector3) -> bool` (inside its lock volume). The boss arena's table is `["boss"]`; adds come through `spawn_adds()` at its points.
- `SpawnPoint` (Marker3D): `tag` (`&"doorway"`, `&"alley"`, `&"vehicle"`, `&"stairwell"`), `lane_point: Marker3D` child (where it walks first).
- `Barrier` (`barrier.gd`, `barrier.tscn`): `kind` (`SHUTTER`, `GATE`, `CAR`), `width_m`, `height_m`, `start_closed`, `open()`, `close()`, `is_closed()`, `signal moved(closed: bool)`. Closed: a world-layer collider; open: none.
- `HazardVolume` (Area3D, `kind = &"drop"`): masks layers 3 (`enemy_body`) and 6 (`downed_body`); an `EnemyActor` entering in any state is KO'd at once (a killing `HitInfo` with no attacker; `hazard_ko` emitted). The player only by D8's fall rule. `EdgeGuard`: a `LevelBlock` on layer 9 only.
- `PickupSpot` (Marker3D): `weapon_scene` (default `pipe.tscn`), placed at level start.
- `LevelBlock` (`@tool`): `size: Vector3`, `look` (`&"wall"`, `&"floor"`, `&"accent"`, `&"dark"`, `&"prop"`, `&"fence"`), `solid: bool`; builds its collider and mesh through `RoomKit`. `LevelStairs` (`@tool`): `rise_m`, `run_m`, `width_m`; the step count from the rise.
- `NavBaker`: keeps a polygon within ±0.3 m of a floor height or inside a `LevelStairs` footprint, and drops the rest (prop and wall tops); the crowd room's call is unchanged.
- `CombatTypes.LAYER_EDGE_GUARD = 9` (`edge_guard` in `project.godot`); `combat_actor.gd` `_set_ghost()` puts it in the player's mask in both states and in a standing enemy's mask (D8).
- `GoCue` (`game/ui/go_cue.gd`, a HUD child stepped by `GameHud.advance()`): "GO →" on `arena_cleared` (the arrow toward the next arena's first route point, relative to the look), "CLEAR!" on `level_cleared`.

**Scene conventions.** Each section is built in its own space: `Entry` at the origin, the walk along -Z, its first floor at y = 0, every number an export or a node transform (never a script constant). Lanes 10-14 m wide; one reference screen ≈ 12-16 m of walk. Nav settings as the crowd room's (cell 0.25 / 0.1, agent 0.5 / 1.8, climb 0.2, so a step rise <= 0.18). A section builds solid geometry only inside its own footprint below, and nothing past its `Exit`. Under its own open edges it draws non-solid ground at street level for the view down.

**Level space** (origin: the street's `Entry`; -Z is the street's walking direction, +X the building side; y up; footprints ±1 m; walking direction in brackets):

| Piece | Owner | x (m) | z (m) | Floor y (m) |
| --- | --- | --- | --- | --- |
| A1 loading dock [-Z] | STREET | -6..6 | 0..-14 | 0 |
| A2 crate yard [-Z] | STREET | -6..6 | -14..-30 | 0 |
| A3 warehouse front [-Z], stair 1 along its right wall to a landing | STREET | -6..6 | -30..-53 | 0, landing 4.5 |
| Seam shutter (A3/A4), `ExitBarrier` | STREET | 0..6 | -53 | 4.5 |
| A4 terrace [-Z], 1 m step at z -67, drop on its -X side | ROOF | -5..5 | -53..-81 | 4.5, then 5.5 |
| Stair 2, from the terrace's far end up +X | ROOF | 0..6 | -78..-81 | 5.5 to 9 |
| A5 catwalk [+Z], drop to the terrace on its -X side | ROOF | 5..15 | -81..-61 | 9 |
| Stair 3, from the catwalk's +Z end up +X | ROOF | 10..16 | -61..-64 | 9 to 12 |
| A6 top roof [-Z], railed drop on its +X side | ROOF | 15..29 | -59..-83 | 12 |
| A7 boss roof [-Z], fenced, one railed gap | FINALE | 12..32 | -83..-103 | 12 |

Entries in level space: STREET (0, 0, 0); ROOF at the seam shutter's centre (3, 4.5, -53); FINALE at the A6/A7 gate's centre (22, 12, -83). A section's local coordinates are level minus its `Entry`, with no rotation (every seam walks -Z). The building under the terrace, the catwalk and the top roof (x -5..29, z -53..-83, below their floors) is ROOF's; the boss roof's is FINALE's. FINALE's done-when test checks that no two sections' solid blocks overlap.

**Tuning.**
- "Enemies" > "Attack arcs" (ARC): `punk_arc_deg` 90, `thug_arc_deg` 140, `bruiser_arc_deg` 180, `boss_arc_deg` 270, `kicker_arc_deg` 360, `engage_commit_s` 0.5, `arc_engage_radius_m` 7.0, `director_seat_gap_deg` 40, `wait_ring_min_m` 5.5, `wait_ring_max_m` 6.5, `director_slot_max_rise_m` 0.5, `blind_spot_needs_wide_arc` true. "Debug" (ARC): `director_even_spread` false.
- New group **"Level"** after "Sparring", before "Audio" (KIT): "Arena locks" (`barrier_close_s` 0.6, `barrier_open_s` 0.8, `arena_lock_inset_m` 2.0, `spawn_named_wait_s` 2.0), "Drop-offs" (`level_edge_guard` true, `level_fall_damage` 20, `level_fall_invuln_s` 1.5), "GO cue" (`go_cue_s` 2.0, `go_cue_size` 1.0, `go_cue_pulse_s` 0.5).

**File ownership.**

| Package | Owns |
| --- | --- |
| ARC | `game/enemies/{enemy_director,enemy_actor,enemy_catalog,enemy_variant}.gd`, `game/enemies/variants/*`, the one `apply_variant` line in `EncounterSpawner.make_enemy()`, the AI layer of `game/ui/debug_draw.gd`, `tests/bot/readability_probe.gd`, `tests/test_{enemy_director,attack_arcs,readability_probe,m3_done_when,debug_draw_ai}.gd`, `test_the_catalog_lists_only_scenes_that_exist` in `tests/test_m3_contracts.gd`, `tests/bot/acts/arc_acts.gd`, `tests/fixtures/{arc_wall,two_floor}_fixture.tscn` |
| KIT | `game/level/kit/*`, `game/level/{encounter_spawner,encounter_table,nav_baker}.gd` (not `make_enemy()`), `_set_ghost()` in `game/actors/combat_actor.gd`, `game/ui/go_cue.gd`, the GoCue lines of `game/ui/hud.gd`, `tests/fixtures/level_strip*.tscn`, `tests/fixtures/strip/*.tres`, `tests/test_{level_kit,encounter_spawner}.gd` |
| BOT | `tests/bot/level_bot.{gd,tscn}`, `tests/bot/level_acts/run_acts.gd`, `tools/record_acts.sh`, `tests/test_level_bot.gd` |
| STREET | `game/level/mission1/street.tscn`, `game/level/mission1/encounters/a{1,2,3}.tres`, `tests/test_m5_street.gd` |
| ROOF | `game/level/mission1/roofs.tscn`, `game/level/mission1/encounters/a{4,5,6}.tres`, `tests/test_m5_roofs.gd` |
| FINALE | `game/level/mission1/{boss_roof,mission1}.tscn`, `game/level/mission1/encounters/a7.tres`, `ROOM_SCENES` in `game/autoload/game_input.gd`, `tests/test_m5_done_when.gd`, `test_f6_switches_rooms_and_the_help_lists_it` in `tests/test_m3_contracts.gd`, `test_f6_finds_the_other_room_both_ways` in `tests/test_crowd_room.gd` |
| Shared, by region | `game/autoload/tuning_data.gd` (ARC: "Attack arcs" and Debug; KIT: "Level"), `project.godot` (KIT: the layer 9 name; FINALE: `run/main_scene`), `combat_events.gd` and `combat_types.gd` (KIT only). The lead regenerates the default preset after each merge. |
| Lead | README.md, docs/HANDOFF.md, the "## Level blockout (Milestone 5)" intro in ARCHITECTURE.md, merges |

## 3. The packages

Every brief adds to build.js's COMMON rules. Each package fills its own ARCHITECTURE.md heading under "## Level blockout (Milestone 5)", named in its brief, and reports its spec departures for the lead's README section "Where M5 departs from the spec".

### ARC: Attack arcs in the director

est 8 · godot true · base `m5/level-blockout` · depends on nothing · phase 1, first.
**Goal.** Replace M3's evenly spread posture ring with Game-boy's attack arcs (M5-inputs.md and his answers; D1-D6), data-driven per archetype and per variant, then re-measure M3's readability metrics and the rear-warning tests.
**Owns.** §2 "File ownership", row ARC. **Tunables.** "Enemies" > "Attack arcs"; "Debug" > `director_even_spread` (§2 "Tuning").
**Read.** M5-inputs.md (whole); this plan §1 D1-D6, §2 "Enemies", "Tuning", "File ownership"; ARCHITECTURE.md "### Director", "### Rear warning and the F3 AI overlay", "### Instruments: readability probe, autopilot, warning oracle"; `enemy_director.gd` header, `_track_waiting()`, `_grant()`, `_assign_slots()`, `_flank_angle()`, `_snap_slot()`; `enemy_actor.gd` (grep `wants_token|grant_token|set_slot|_tick_posture|_enter_recover|_wakes_in_place|has_token_priority`); `tuning_data.gd` lines 577-724; `readability_probe.gd` (grep `R5|R6|R9|LIMITS`); `test_m3_done_when.gd` header; `test_enemy_director.gd` (grep `blind`).
**Provides** §2 "Enemies". **Uses** nothing new (KIT's level arrives after merge).
**Build.**
- The engage book per enemy (D1), held in the director like `_claims`, driven by the enemy's AI state, never by a camera.
- Seats (D3): inner seats inside each arc `director_seat_gap_deg` apart; holders and seated enemies keep theirs while inside their arc; the rest on wait seats; the fallback chain and the slide; the Kicker and the boss per D4.
- `_snap_slot()` rejects a snap whose y differs from the player's by more than `director_slot_max_rise_m`, and one the enemy can't reach (a path query, cached per reslot). Today it checks XZ only, so a seat past a catwalk lip would land on the floor below.
- `set_slot(pos, kind)` and `_tick_posture()` per §2; `_grant()` grants inner seats only, the blind roll per D5; the longest waiter is the longest on a wait seat.
- `EnemyVariant`, the catalog entry, `apply_variant()` and its one call in `make_enemy()`; `punk_veteran.tres` (arc 140; a tint the rig can show cheaply; if no paint seam takes it, the jacket colour, and log the call).
- F3: each engaged enemy's arc edges and line, the wait ring, a slid arc marked.
- `director_even_spread` per D6; the probe's R5, R5w, R6, R6w and R9 per D6.
**Tests.** `tests/test_attack_arcs.gd`:
- a Punk engaging behind the player walks round to his front; inside the grace its line follows a turn, after it doesn't; turning your back lets a committed Punk attack from behind;
- a Punk seated at 6.5 m on the wait ring has a committed line 0.5 s after it arrives, and a later 180° turn doesn't move its seat;
- 6 Punks: 3 inner, 3 waiting at 5.5-6.5 m, no token from a wait seat, the longest waiter takes a freed seat;
- the player 2 m from a wall and facing it (`arc_wall_fixture`): the arcs slide, R7 and R13 stay 0, nobody stands inside 2.2 m without a token;
- `two_floor_fixture` (a floor 4.5 m below an edge): no seat snaps to the lower floor;
- the Bruiser seated at the flank, the Kicker behind, the boss never within 45° of directly behind; no blind roll for a Punk; the veteran's 140°; the A/B switch restores M3.
- Re-run `test_m3_done_when.gd` and the readability tests per D6; the catalog's id list in `test_m3_contracts.gd` gains `punk_veteran`.
**Acts** (`tests/bot/acts/arc_acts.gd`, first person): "Arcs: six Punks" (a front line of three, three waiting behind it), "Arcs: turn your back" (engage, wait past the grace, quick-turn: the wind-up comes from behind and the warning fires), "Arcs: mixed six" (Punk, Punk, Thug, Bruiser, Kicker, veteran), "Arcs: quick turns" (turning inside the grace never stalls a Punk). Look for: Punks square up in front; waiters stand clearly back; the Kicker is the only one that circles behind.
**ARCHITECTURE.** "### Attack arcs (ARC)", and the spread paragraph of "### Director" amended.
**Done when.** The full suite passes; `readability.json` for the crowd acts shows the hard rows (R1-R3, R10, R11) ok and R5/R5w, R6/R6w and R9 per D6; `M5-calls/ARC.md` lists every re-measured number before and after.

### KIT: Level kit and the test strip

est 8 · godot true · base `m5/level-blockout` · depends on nothing · phase 1, with ARC.
**Goal.** Every mechanism the level needs, proved in a two-section test strip: sections and seams, arenas and locks, the three barrier kinds, the "GO →" cue and "CLEAR!", drop-offs with KO, the edge guard and the fall rule, stairs across two floors, pickup spots, the spawner's finite mode.
**Owns.** §2 "File ownership", row KIT. **Tunables.** the "Level" group (§2 "Tuning").
**Read.** This plan §1 D7-D13, §2 (all but "Enemies"); SPEC §9's conversion table (lines 268-279); ARCHITECTURE.md "## Physics and visual layers (`CombatTypes`)", "### Crowd room, navigation and waves", "### Pipe Thug and the dropped pipe"; `crowd_room.gd` `_ready()` and `spawn_point_list()`; `room_kit.gd` (function list, `add_box`, `spawn_player`); `nav_baker.gd`; `encounter_spawner.gd` (header, `_physics_process`, `_begin_wave`, `_spawn_next`, `valid_point_indices`, `spawn_adds`); `encounter_table.gd`; `combat_actor.gd` `_set_ghost()` and its callers (grep); `weapon.gd` (`_ready`, `drop`); `game/ui/pickup_cue.gd` (the HUD-child pattern).
**Provides** §2 "Spawner and table", "Events", "Level kit", layer 9. **Uses** `RoomKit`, today's director (ARC's after merge, unchanged API).
**Build.**
- The contracts, the "Level" tuning group, layer 9 and its masks in `_set_ghost()` (D8), the NavBaker rule (floors and stairs).
- The strip, two sections chained by a seam:
  - `level_strip_a.tscn`: arena 1 on the street (a parked car behind; a doorway, an alley and a vehicle spawn, one behind the player; table: 2 Punks, then 2 Punks and a Thug), stair 1 up 4.5 m along its wall to a landing, a shutter at the stair head as its `ExitBarrier`.
  - `level_strip_b.tscn`: arena 2 on a terrace (a chain-link gate ahead; a landing spawn inside its barriers; a drop edge with its guard and hazard; a pickup spot; table: 3 Punks), the last arena, so its clear emits `level_cleared`.
  - `level_strip.tscn`: the `LevelRoot` with both.
**Tests.** `tests/test_level_kit.gd`:
- sections chain on their markers and the seam barrier serves both arenas; the lock closes behind only past the inset; the ahead barrier stays closed until the table finishes, then opens with `arena_cleared` and the GO cue; the last arena's clear emits `level_cleared` and shows "CLEAR!";
- arenas are nav islands; every spawn point snaps to the navmesh, lies inside its arena (`contains()`) and has a path to its lane point;
- an enemy launched over the edge is KO'd on entering the hazard; the player, standing and launched toward the guard, stays on the floor; with the guard off a fall costs the damage and respawns him;
- 6 posturing Punks near the edge for 20 s with no player input: none enters the hazard, R7 and R13 stay 0 (director-independent, so it runs before and after ARC's merge);
- a KO'd player gets back up and the arena stays locked; the pipe lies at its spot; `start_at_arena(1)`;
- finite mode never plays the boss wave; a named point overrides the behind share; a too-close named point waits, then falls back; the crowd room's wave and spawn tests unchanged.
**Acts.** None of its own (BOT records the strip). Its look: one Movie Maker capture of the strip (`godot --path . --write-movie <worktree>/captures/kit/strip.avi --fixed-fps 60 --quit-after 900 tests/fixtures/level_strip.tscn`, waves on, god mode) and stills of a barrier closing, the GO cue and the drop edge seen from the lane. Judge that barriers read as barriers, the cue as a comic panel, the edge as a drop.
**ARCHITECTURE.** "### Level kit (KIT)", and layer 9 in "## Physics and visual layers (`CombatTypes`)".
**Done when.** The full suite passes and the strip plays both arenas by hand (`godot --path . tests/fixtures/level_strip.tscn`).

### BOT: Level-run bot

est 4 · godot true · base `m5/level-blockout` after KIT's merge · depends on KIT · phase 1b, during the pause.
**Goal.** A bot that plays any `LevelRoot` arena by arena with the autopilot, records it and logs each arena's times, so the start-to-boss run is an act and its length is measured.
**Owns.** §2 "File ownership", row BOT. **Tunables.** none (bot exports only).
**Read.** This plan §2 "Level kit" and "File ownership"; ARCHITECTURE.md "### Instruments: readability probe, autopilot, warning oracle" and "### Level kit (KIT)" (as merged); `tests/bot/crowd_bot.gd` (`_room_scene`, `_run`, `fight`, `hold_back`, the log lines, `ACTS_DIR`); `tests/bot/autopilot.gd` (exports); `tools/record_acts.sh`, `tools/capture_bot.sh`.
**Provides.** `level_bot` args `--level=<LevelRoot or section scene>` (default the strip), `--from=<arena>`, `--to=<arena>`; helpers `walk_route(to_arena)`, `run_arena()`, `run_level(from, to)`; log lines with the physics frame: `ARENA+ <id>`, `WAVE <id> <n>`, `ARENA- <id> <seconds>`, `LEVEL <seconds>`, `HAZARD <name>`. `record_acts.sh` takes `BOT_SCENE` (default crowd_bot). **Uses** `LevelRoot`.
**Build.** `level_bot.gd` extends `crowd_bot.gd`, with acts from `tests/bot/level_acts/` only. `walk_route` steers the scripted player through the route points (look at the next point, hold forward, never into a closed barrier); `run_arena` walks in until it locks, then the autopilot fights until it clears. The readability probe runs per arena. Three level-agnostic acts in `run_acts.gd`: "Run: held back" (the held-back autopilot, real damage), "Run: knock-off" (in the first arena with a hazard, a Punk launched over the edge) and "Run: timing" (headless, god mode, logs `LEVEL`).
**Tests.** `tests/test_level_bot.gd` (headless, the strip, god mode): `run_level(0, 1)` clears both arenas inside a frame budget; the log carries every line.
**Acts.** "Run: held back" and "Run: knock-off" on the strip. Look for: the walk turns smoothly to each route point (no jitter in first person); the GO cue shows as the gate opens.
**ARCHITECTURE.** "### Level-run bot (BOT)".
**Done when.** Both acts record with no error lines, and the log prints the arena times.

### STREET: Street section (arenas A1-A3)

est 6 · godot true · base `m5/level-blockout` after phase 1 and Game-boy's yes · depends on ARC, KIT, BOT, approval · phase 2.
**Goal.** Build `street.tscn` from encounters.md A1-A3 (as approved), ending at the seam shutter at the head of stair 1.
**Owns.** §2 "File ownership", row STREET. **Tunables.** none new.
**Read.** reference/encounters.md A1-A3 and "How the reference converts"; notes.md rows 01-04 and 01.jpg-04.jpg (layout only; SPEC §1's IP rules: no character, enemy, art or sound copied); this plan §1 D7-D11 and §2 "Level kit", "Scene conventions", "Level space", "File ownership"; ARCHITECTURE.md "### Level kit (KIT)" and "### Level-run bot (BOT)"; `tests/fixtures/level_strip_a.tscn` as the worked example.
**Provides.** `street.tscn` (`Entry`, `Start`, `Exit` at the landing, `ExitBarrier`), `floor_heights` [0, 4.5]. **Uses** the level kit.
**Build.** Three arenas with the table's sizes, barriers and spawn points (doorways in the warehouse fronts, the crate alley, the parked van, the stair-head landing inside the shutter), their waves (`a1.tres`..`a3.tres`, `loop = false`, point names per spawn), set dressing in the reference's location type (loading docks, crate stacks, a chain-link fence, the warehouse with its rolling shutter), stair 1 inside A3, the landing's open side guarded.
**Tests.** `tests/test_m5_street.gd`: a `LevelRoot` with only this section; each arena locks, plays its table (ids and point names as the table says, never over 6 alive), clears and opens; every named point and its lane point lie inside their arena; the route walks from `Start` to `Exit`.
**Acts.** `BOT_SCENE=res://tests/bot/level_bot.tscn CAPTURE_ARGS="--level=res://game/level/mission1/street.tscn" tools/record_acts.sh <worktree>/captures/street "street|Run: held back"`. Look for: doorways read as openings; spawns behind the player aren't seen before they arrive; barriers read; A3's Punks come down the stair.
**ARCHITECTURE.** "### Mission 1: the street (STREET)".
**Done when.** The full suite passes and the section runs clean under the bot.

### ROOF: Roof section (arenas A4-A6)

est 6 · godot true · base as STREET · depends on ARC, KIT, BOT, approval · phase 2, with STREET and FINALE.
**Goal.** Build `roofs.tscn` from encounters.md A4-A6: the terrace with its step, the catwalk walked back above it, the top-roof crowd arena, stairs 2 and 3, and the drop-offs.
**Owns.** §2 "File ownership", row ROOF. **Tunables.** none new.
**Read.** reference/encounters.md A4-A6; notes.md rows 05-11 and 05.jpg-11.jpg; full-map.jpg (the stacking); the rest as STREET, with `level_strip_b.tscn` as the example.
**Provides.** `roofs.tscn` (`Entry` at the A3/A4 seam, `Exit` at the A6/A7 gate, `ExitBarrier`), `floor_heights` [0, 1.0, 4.5, 7.5] (local). **Uses** the level kit; the seam shutter is STREET's.
**Build.** As STREET, plus:
- the step halfway along the terrace as a 1 m stair flight;
- every open edge has an `EdgeGuard` and a `HazardVolume` and reads as a drop in first person (a lip, a low rail with gaps, non-solid ground at street level below);
- the catwalk 10 m wide with its open side over the terrace; the top roof's railed edge on its far side;
- the pipe `PickupSpot` in front of the top roof's big shutter; `punk_veteran` in A6's first wave.
**Tests.** `tests/test_m5_roofs.gd`: as STREET's, plus a Punk launched off each drop edge is KO'd, and every floor height is on the navmesh.
**Acts.** As STREET with `--level=res://game/level/mission1/roofs.tscn`, "Run: held back" and "Run: knock-off". Look for: the drop is visible before the player reaches the edge; A6's six fit and read (Punks in front, the Kicker behind).
**ARCHITECTURE.** "### Mission 1: the roofs (ROOF)".
**Done when.** As STREET.

### FINALE: Boss roof, level root and done-when

est 7 · godot true · base as STREET · depends on ARC, KIT, BOT, approval · phase 2, with STREET and ROOF.
**Goal.** The boss arena, the level that chains all three sections, the main scene, and the start-to-boss run as a test.
**Owns.** §2 "File ownership", row FINALE (and `run/main_scene` in `project.godot`). **Tunables.** none new.
**Read.** reference/encounters.md A7 and "Totals"; notes.md row 12 and 12.jpg; this plan §1 D9-D14, §2 "Level kit", "Level space", "File ownership"; ARCHITECTURE.md "### Boss" (grep `spawn_adds`, `boss_adds_count`), "### Level kit (KIT)", "### Level-run bot (BOT)"; `game/autoload/game_input.gd` (`ROOM_SCENES`, `switch_room`, `room_after`); `tests/test_m3_done_when.gd` as a pattern.
**Provides.** `boss_roof.tscn`, `mission1.tscn`, the main scene, F6's three rooms. **Uses** `level_cleared` (KIT's `LevelRoot` emits it), BOT's acts.
**Build.** `boss_roof.tscn` (about 20 x 20 m, the fence gate behind stays closed, one railed gap with guard and hazard, points for the boss and his adds); `mission1.tscn` (`LevelRoot`, `section_paths` = street, roofs, boss_roof); `run/main_scene` and `ROOM_SCENES` (level, crowd room, training room) with its two F6 tests.
**Tests.** `tests/test_m5_done_when.gd` (the real level, seeded, god mode and `one_hit_ko`, the autopilot; short `wave_gap_s` and `wave_spawn_interval_s`, set and restored by the test), **arena by arena** through `start_at_arena(k)`:
- every arena locks, spawns exactly its table, never over 6 alive, clears and opens in order; R1, R3 and R10 hard throughout;
- the boss at half health (set by the test) calls in his two adds at A7's points; the last clear emits `level_cleared`;
- no two sections' solid blocks overlap (§2 "Level space").
- Budget: at most 1800 sim frames an arena and 120 s of wall time for the file; report the suite's growth. Sections missing in its worktree are skipped by `LevelRoot`, so build the boss roof first and run the whole file after the lead's merge.
**Acts.** The whole run is BOT's "Run: timing" with `--level=res://game/level/mission1/mission1.tscn` (headless, logs `LEVEL <s>`); the boss with `--from=6`, "Run: held back". Look for: the boss arena reads as closed; the adds come from doors you can see.
**ARCHITECTURE.** "### Mission 1: the boss roof and the level (FINALE)".
**Done when.** After the lead's merge of all three sections: the done-when test and the full suite pass, and the level is the main scene.

## 4. Merge order and checks

1. **Phase 1 launch:** ARC and KIT together (2 Godot slots); the lead sends the DM (§6) at the same time.
2. Merge ARC, then KIT, into `m5/level-blockout`; regenerate the default preset; full `tools/run_tests.sh` (KIT's edge test now runs on the arcs). The lead looks at "Arcs: six Punks" and "Arcs: turn your back" stills and plays the strip. HANDOFF.
3. Launch BOT; merge it; full suite. HANDOFF.
4. **Phase 2** on Game-boy's yes (apply any change he asks to encounters.md first): STREET, ROOF and FINALE together (3 Godot slots). Merge STREET, ROOF, then FINALE; preset; full suite plus `test_m5_done_when.gd`; the "Run: timing" log for the run time. One post-merge fixer (Sonnet) takes whatever only the whole level shows: seams, overlaps, the done-when. Then the recording (§5) and the lead's own look. HANDOFF.
5. **Phase 3:** review round, fix wave, re-check, README "Where M5 departs from the spec" from the packages' reported departures (M5-1 arcs and the slide, M5-2 blind-spot, M5-3 stairs; the spec-silent D8 and D13; the D12 stand-in), PR, final DM.

## 5. The review round

Recorded once by the lead into `captures/m5-final/`:
- `tools/record_acts.sh captures/m5-final "arc-punks|Arcs: six Punks" "arc-turn|Arcs: turn your back" "arc-mixed|Arcs: mixed six"`;
- `BOT_SCENE=res://tests/bot/level_bot.tscn` and `CAPTURE_ARGS="--level=res://game/level/mission1/mission1.tscn --from=<a> --to=<b>"` with "Run: held back", three runs: street (0-2), roofs (3-5), boss (6);
- the headless "Run: timing" log for the run time.

| Lens | Model | Judges |
| --- | --- | --- |
| `sees` | Opus, high | What the player sees, from first-person sheets: barriers, doorways and drops read; the GO cue; spawns behind arrive unseen; the pipe is findable; the boss arena reads as closed; the arcs show (a front line, waiters back from the fray). |
| `feel` | Opus, high | Motion, feel and pacing: Punks square up and don't circle; turning your back is punished and a quick turn doesn't stall them; the ramp (2 Punks, the crowd arena, the boss); arena and level times against 8-12 minutes (the autopilot's time x 1.5 for a first run); walking and stairs never drag. |
| `code` | Sonnet, high | Code, tests and pipeline: the §2 contracts as landed, no numbers in scripts, layer rules (the GO cue and F3 only read), thresholds moved only with a log and a twin, the done-when test is honest (no forced clears), the suite's growth. |

Skeptics (Sonnet, medium) for high and medium findings only. One fix wave of at most 3 fixers, partitioned inline by the lead. Re-check: the lead re-records only the acts whose findings were fixed, and the lens that raised each finding re-judges only those items (Sonnet for code items).

## 6. The encounter-plan DM

The lead sends Game-boy one Slack DM at phase 1's launch: the arena-by-arena summary (7 arenas, 34 enemies with the boss and adds, about 9-10 minutes; the arcs and the progression), the whole of reference/encounters.md in the DM's thread (written for a phone; GitHub links 404 for Game-boy), and two asks:
1. **Approve the table**, or say what to change.
2. **The rear warning** (M5-inputs open question 3): with the arcs, Punks reach your back only when you turn it on them, so the warning fires mostly for Kickers, the Bruiser's flank, the boss, and Punks you turned away from. Should a crowd of Punks ever come round behind you on their own (for example when you're surrounded)? Default: no.

Then three defaults he can overrule in a word: stairs where the original climbs ladders (D7); the player can't fall off edges while knocked enemies can (D8); an arc blocked by a wall slides to the nearest open side (D3).

## 7. Usage

Budget about 125% of a 5-hour window for all of M5; planning has spent about 15%.

| Phase | Agents | Estimate |
| --- | --- | --- |
| 1 | ARC 8 + KIT 8, then BOT 4; lead (merges, preset, suites, look, DM) 7 | about 27% |
| 2 | STREET 6 + ROOF 6 + FINALE 7; post-merge fixer 5; lead (3 merges, preset, suite, done-when, recording, look) 8 | about 32% |
| 3 | 2 Opus lenses 12 + 1 Sonnet lens 3, skeptics about 5, fixers up to 3 x 5, re-check 4, lead (README, PR, DM) 6 | at most 45% |
| M5 | | about 104%, plus planning: about 119% of 125% |

Headroom is about 6% if phase 3 uses all three fixers, about 11% with two. Check `get_usage` before every launch, and size each launch to the headroom below 90% of the window. If a phase doesn't fit: phase 1 launches ARC alone, then KIT and BOT in the next window; phase 2 launches STREET and ROOF first and FINALE in the next window (its full test needs both merged anyway); phase 3 runs the three lenses and the skeptics in one window and the fix wave in the next, never splitting a lens. Hand off at 90% (CLAUDE.md, "Handoff protocol").
