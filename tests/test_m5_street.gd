extends GutTest
## The street section of Mission 1 (Milestone 5, STREET): `street.tscn`, arenas A1-A3 of
## reference/encounters.md, in a one-section `LevelRoot`. Each arena locks, plays its table (the ids and
## the spawn point names the table says, never more than six alive), clears and opens; every named
## spawn point and its lane point lie inside their own arena and on the navmesh; the barriers are
## the kinds the plan names; the route walks from `Start` to `Exit`; the landing's open edges are
## guarded; and the level bot clears the whole section with the real AI.

const STREET := "res://game/level/mission1/street.tscn"
const PROBE := preload("res://tests/fixtures/spawn_probe_enemy.tscn")
## The frames the navigation map needs to sync after a level's _ready().
const SYNC_FRAMES := 5
## The most ticks the whole section may take under the bot (three arenas, the walks between).
const RUN_BUDGET_TICKS := 14400
## Where the player stands to lock each arena (past its behind barrier by more than the inset).
const LOCK_AT: Array[Vector3] = [Vector3(3.0, 0.1, -6.0), Vector3(3.0, 0.1, -18.0), Vector3(3.0, 0.1, -33.0)]
## The tables as reference/encounters.md has them: per arena, per wave, the (id, spawn point name).
const TABLES: Array = [
	[[["punk", "Doorway"], ["punk", "Alley"]]],
	[
		[["punk", "Alley"], ["punk", "Office"], ["punk", "VanL"]],
		[["punk", "VanL"], ["punk", "Office"], ["thug", "VanR"]],
	],
	[
		[["punk", "LandingA"], ["punk", "LandingB"]],
		[["punk", "Brick"], ["punk", "WarehouseA"], ["thug", "WarehouseB"]],
	],
]

var _wave_seen: Array = []


## The bot that stops instead of quitting the test run's tree (as test_level_bot.gd's).
class QuietBot extends "res://tests/bot/level_bot.gd":
	var finished: bool = false

	func _quit() -> void:
		clear_enemies()
		finished = true


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.set_value(&"waves_enabled", true)
	Tuning.set_value(&"wave_gap_s", 0.1)
	Tuning.set_value(&"wave_spawn_interval_s", 0.05)
	Tuning.set_value(&"god_mode", true)
	TimeController.clear()
	TimeController.debug_scale = 1.0
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = false


func after_each() -> void:
	PlaceholderAnims.warn_on_fallback = true
	GameInput.menu_open = false
	Tuning.reset_to_default()
	Tuning.set_value(&"ai_frozen", false)
	Tuning.set_value(&"god_mode", false)
	TimeController.clear()


func after_all() -> void:
	OS.delay_msec(250)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## The street alone as a level: no presentation, the probe standing in for the Punk and the Thug,
## the player's input scripted.
func _level(probe: bool = true) -> LevelRoot:
	var level := LevelRoot.new()
	level.section_paths = PackedStringArray([STREET])
	level.with_presentation = false
	add_child_autofree(level)
	if probe:
		level.spawner.scene_override = {&"punk": PROBE, &"thug": PROBE}
	level.player.input.scripted = true
	await _ticks(SYNC_FRAMES)
	return level


## The street as a bare section, for the checks that need no running level.
func _section() -> LevelSection:
	var section := (load(STREET) as PackedScene).instantiate() as LevelSection
	add_child_autofree(section)
	return section


func _map(level: LevelRoot) -> RID:
	return level.get_world_3d().navigation_map


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _reaches(level: LevelRoot, from: Vector3, to: Vector3, tolerance: float = 0.6) -> bool:
	var path := NavigationServer3D.map_get_path(_map(level), from, to, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(to) < tolerance


func _put_player(level: LevelRoot, at: Vector3) -> void:
	level.player.global_position = at
	level.player.velocity = Vector3.ZERO


func _until(check: Callable, frames: int) -> bool:
	for i in frames:
		if check.call():
			return true
		await _ticks(1)
	return check.call()


func _point_named(arena: Arena, point_name: String) -> Dictionary:
	for point in arena.spawn_point_list():
		if String(point.name) == point_name:
			return point
	return {}


# --- The section ---------------------------------------------------------------------------


func test_the_section_has_its_markers_arenas_and_barrier_kinds() -> void:
	var section := _section()
	assert_eq(section.entry().position, Vector3.ZERO, "Entry at the origin")
	assert_eq(section.floor_heights, PackedFloat32Array([0.0, 4.5]), "two floors: the street and the landing")
	assert_almost_eq(section.exit_marker().position.y, 4.5, 0.01, "Exit at the landing's height")
	assert_lt(section.exit_marker().position.z, -52.0, "Exit at the far end of A3")
	assert_not_null(section.start_marker(), "a Start")
	var arenas := section.arena_list()
	assert_eq(arenas.size(), 3, "A1, A2, A3")
	var ids: Array[StringName] = []
	for arena in arenas:
		ids.append(arena.arena_id)
	assert_eq(ids, [&"street_a1", &"street_a2", &"street_a3"] as Array[StringName])
	var a1 := arenas[0]
	var a2 := arenas[1]
	var a3 := arenas[2]
	var car_start := a1.get_node(a1.behind_barrier) as Barrier
	var gate := a1.get_node(a1.ahead_barrier) as Barrier
	assert_eq(car_start.kind, Barrier.Kind.CAR, "A1: a parked car behind")
	assert_eq(gate.kind, Barrier.Kind.GATE, "A1: a chain-link gate ahead")
	assert_eq(a2.get_node(a2.behind_barrier), gate, "A2: the same gate behind")
	var car := a2.get_node(a2.ahead_barrier) as Barrier
	assert_eq(car.kind, Barrier.Kind.CAR, "A2: a parked car ahead")
	assert_eq(a3.get_node(a3.behind_barrier), car, "A3: the same car behind")
	var shutter := a3.get_node(a3.ahead_barrier) as Barrier
	assert_eq(shutter.kind, Barrier.Kind.SHUTTER, "A3: a rolling shutter ahead")
	assert_eq(shutter, section.exit_barrier(), "which is the seam's ExitBarrier")
	assert_true(shutter.start_closed and gate.start_closed and car.start_closed, "ahead barriers start closed")
	assert_false(car_start.start_closed, "the start car starts open")
	assert_almost_eq(shutter.global_position.y, 4.5, 0.01, "the shutter is at the stair's head")
	assert_eq(section.stairs().size(), 1, "one stair flight")
	assert_almost_eq(section.stairs()[0].rise_m, 4.5, 0.01, "up 4.5 m")


func test_the_street_is_in_its_footprint_and_nothing_is_solid_past_the_exit() -> void:
	var section := _section()
	var past := 0
	for block in section.blocks():
		if not block.solid:
			continue
		var box := block.world_aabb()
		if box.position.z < -53.05:
			past += 1
	assert_eq(past, 0, "no solid block lies past the Exit (z -53)")
	for arena in section.arena_list():
		var shape := arena.get_node("LockTrigger/Shape") as CollisionShape3D
		var box := shape.shape as BoxShape3D
		var centre := shape.global_position
		assert_lt(centre.z - box.size.z * 0.5, 0.01, "%s is on the street's side of the Entry" % arena.arena_id)
		assert_gt(centre.z + box.size.z * 0.5, -53.1, "%s starts inside the street" % arena.arena_id)


func test_the_arena_sizes_follow_the_table() -> void:
	var section := _section()
	var arenas := section.arena_list()
	var expect: Array[Vector2] = [Vector2(-1.5, -14.0), Vector2(-14.0, -30.0), Vector2(-30.0, -53.0)]
	for i in 3:
		var box := (arenas[i].get_node("LockTrigger/Shape") as CollisionShape3D).shape as BoxShape3D
		var centre := (arenas[i].get_node("LockTrigger/Shape") as CollisionShape3D).global_position
		assert_almost_eq(centre.z + box.size.z * 0.5, expect[i].x, 0.3, "%s's near end" % arenas[i].arena_id)
		assert_almost_eq(centre.z - box.size.z * 0.5, expect[i].y, 0.3, "%s's far end" % arenas[i].arena_id)


# --- Tables and spawn points ---------------------------------------------------------------


func test_the_tables_are_finite_with_the_waves_and_points_of_the_encounter_plan() -> void:
	var section := _section()
	var arenas := section.arena_list()
	for i in 3:
		var table := arenas[i].table as EncounterTable
		assert_not_null(table, "%s has a table" % arenas[i].arena_id)
		assert_false(table.loop, "%s plays once" % arenas[i].arena_id)
		assert_eq(table.waves.size(), (TABLES[i] as Array).size(), "%s: its waves" % arenas[i].arena_id)
		for w in table.waves.size():
			var want_ids := PackedStringArray()
			var want_points := PackedStringArray()
			for pair: Array in TABLES[i][w]:
				want_ids.append(pair[0])
				want_points.append(pair[1])
			assert_eq(table.waves[w], want_ids, "%s wave %d: the enemies" % [arenas[i].arena_id, w + 1])
			assert_eq(table.points_for(w), want_points, "%s wave %d: the points" % [arenas[i].arena_id, w + 1])
			assert_lte(want_ids.size(), 6, "never more than six at once")
			for point_name in want_points:
				assert_false(_point_named(arenas[i], point_name).is_empty(), "%s has a spawn point '%s'" % [arenas[i].arena_id, point_name])


func test_the_counts_follow_the_ramp_of_spec_9() -> void:
	var section := _section()
	var arenas := section.arena_list()
	var most: Array[int] = []
	var total := 0
	var thugs := 0
	for arena in arenas:
		var biggest := 0
		for wave in (arena.table as EncounterTable).waves:
			biggest = maxi(biggest, wave.size())
			total += wave.size()
			for id in wave:
				thugs += 1 if id == "thug" else 0
				assert_true(id == "punk" or id == "thug", "A1-A3 hold only Punks and Thugs (no wide arcs before the roofs): %s" % id)
		most.append(biggest)
	assert_eq(most, [2, 3, 3] as Array[int], "A1 two, A2 three, A3 three at most (the difficulty table)")
	assert_eq(total, 13, "thirteen enemies on the street (A1 2, A2 6, A3 5)")
	assert_eq(thugs, 2, "two Pipe Thugs (A2 and A3)")


func test_every_spawn_point_and_its_lane_point_lie_inside_their_own_arena_on_the_navmesh() -> void:
	var level := await _level()
	var seen := 0
	for arena in level.arenas():
		for point in arena.spawn_point_list():
			seen += 1
			var at: Vector3 = point.position
			var lane: Vector3 = point.lane_point
			var label := "%s/%s" % [arena.arena_id, point.name]
			assert_true(arena.contains(at), "%s lies inside its arena" % label)
			assert_true(arena.contains(lane), "%s's lane point lies inside its arena" % label)
			var snapped := NavigationServer3D.map_get_closest_point(_map(level), at)
			assert_lt(_flat(snapped, at), 0.3, "%s snaps to the navmesh" % label)
			assert_lt(absf(snapped.y - at.y), 0.5, "%s on its floor" % label)
			assert_true(_reaches(level, at, lane), "%s has a path to its lane point" % label)
			for other in level.arenas():
				if other != arena:
					assert_false(other.contains(at), "%s is in no other arena" % label)
					assert_false(other.contains(lane), "%s's lane point is in no other arena" % label)
	assert_eq(seen, 11, "two + four + five spawn points")


func test_the_spawn_point_kinds_follow_the_plan() -> void:
	var section := _section()
	var arenas := section.arena_list()
	assert_eq(_point_named(arenas[0], "Doorway").tag, &"doorway", "A1: the dock's shutter doorway")
	assert_eq(_point_named(arenas[0], "Alley").tag, &"alley", "A1: the crate alley")
	assert_eq(_point_named(arenas[1], "Alley").tag, &"alley", "A2: the crate alley")
	assert_eq(_point_named(arenas[1], "Office").tag, &"doorway", "A2: an office doorway")
	assert_eq(_point_named(arenas[1], "VanL").tag, &"vehicle", "A2: the van's back doors")
	assert_eq(_point_named(arenas[1], "VanR").tag, &"vehicle")
	assert_eq(_point_named(arenas[2], "Brick").tag, &"doorway", "A3: a brick doorway")
	assert_eq(_point_named(arenas[2], "WarehouseA").tag, &"doorway", "A3: the warehouse shutter")
	for name_ in ["LandingA", "LandingB"]:
		var point := _point_named(arenas[2], name_)
		assert_eq(point.tag, &"stairwell", "A3: the stair-head landing")
		assert_almost_eq(point.position.y, 4.5, 0.01, "%s stands on the landing" % name_)
		assert_lt(point.position.z, -48.5, "inside the shutter, past the stair's head")
	# Behind and ahead as the plan reads them, measured from where the player locks the arena.
	assert_gt(_point_named(arenas[0], "Doorway").position.z, -14.0)
	assert_lt(_point_named(arenas[0], "Doorway").position.z, LOCK_AT[0].z, "A1's spawns are all ahead of the player")
	assert_lt(_point_named(arenas[0], "Alley").position.z, LOCK_AT[0].z, "A1's spawns are all ahead of the player")
	assert_gt(_point_named(arenas[1], "Alley").position.z, _point_named(arenas[1], "VanL").position.z, "A2's alley is the rear one, the van the front")
	assert_gt(_point_named(arenas[2], "Brick").position.z, _point_named(arenas[2], "LandingA").position.z, "A3's brick door is behind the landing")


# --- Playing the arenas --------------------------------------------------------------------


## Lock arena `index`, play its table with the probe (killing each wave once it has all arrived),
## and return what spawned: an Array of waves, each an Array of [id, nearest point name].
func _play(level: LevelRoot, index: int) -> Array:
	var arena := level.arenas()[index]
	var waves: Array = []
	var sizes: Array[int] = []
	level.spawner.wave_started.connect(func(_n: int, ids: PackedStringArray) -> void:
		waves.append([])
		sizes.append(ids.size()))
	if index > 0:
		level.start_at_arena(index)
		await _ticks(4)
	_put_player(level, LOCK_AT[index])
	await _ticks(2)
	assert_eq(arena.state, Arena.State.LOCKED, "%s locks with the player inside" % arena.arena_id)
	assert_true(arena.behind.is_closed(), "its behind barrier closed")
	assert_true(arena.ahead.is_closed(), "and its ahead barrier is shut")
	var seen := {}
	var most_alive := 0
	for i in 1500:
		for enemy in level.enemies():
			if seen.has(enemy.get_instance_id()):
				continue
			seen[enemy.get_instance_id()] = true
			var probe := enemy as Node3D
			var from: Vector3 = probe.get("entered_from")
			var best := ""
			var best_d := INF
			for point in arena.spawn_point_list():
				var d := _flat(point.position, from)
				if d < best_d:
					best_d = d
					best = String(point.name)
			assert_lt(best_d, 0.6, "%s came in at a spawn point" % enemy.name)
			var id := String(enemy.name).to_lower().rstrip("0123456789")
			waves[waves.size() - 1].append([id, best])
		most_alive = maxi(most_alive, level.enemies().size())
		if not waves.is_empty() and level.enemies().size() >= sizes[waves.size() - 1]:
			for enemy in level.enemies():
				enemy.health = 0.0
			EncounterSpawner.remove_enemies(get_tree(), true)
		if arena.state == Arena.State.CLEARED:
			break
		await _ticks(1)
	assert_lte(most_alive, 6, "never more than six alive")
	return waves


func _sorted_pairs(wave: Array) -> Array:
	var out := wave.duplicate()
	out.sort_custom(func(a: Array, b: Array) -> bool: return String(a[1]) < String(b[1]))
	return out


func _check_arena(index: int) -> void:
	var level := await _level()
	var arena := level.arenas()[index]
	var waves := await _play(level, index)
	assert_eq(arena.state, Arena.State.CLEARED, "%s clears once its table is played" % arena.arena_id)
	assert_false(arena.ahead.is_closed(), "and its ahead barrier opens")
	assert_eq(waves.size(), (TABLES[index] as Array).size(), "%s plays its waves and no boss wave" % arena.arena_id)
	for w in waves.size():
		assert_eq(_sorted_pairs(waves[w]), _sorted_pairs(TABLES[index][w]), "%s wave %d: the ids at the points the table names" % [arena.arena_id, w + 1])


func test_a1_locks_plays_two_punks_from_the_doorway_and_the_alley_and_clears() -> void:
	await _check_arena(0)


func test_a2_locks_plays_its_two_waves_and_clears() -> void:
	await _check_arena(1)


func test_a3_locks_plays_the_stair_wave_and_the_second_wave_and_clears() -> void:
	await _check_arena(2)


func test_a3s_first_wave_comes_in_on_the_landing_and_down_the_stair() -> void:
	var level := await _level(false)
	level.start_at_arena(2)
	await _ticks(4)
	_put_player(level, LOCK_AT[2])
	await _ticks(4)
	assert_true(await _until(func() -> bool: return level.enemies().size() == 2, 180), "two Punks arrive")
	for enemy in level.enemies():
		assert_gt(enemy.global_position.y, 3.5, "%s starts on the landing" % enemy.name)
	assert_true(await _until(func() -> bool:
		for enemy in level.enemies():
			if enemy.global_position.y > 3.0:
				return false
		return true, 1500), "the real AI walks both down the stair to the street")


func test_stair_1_connects_the_street_to_the_landing_inside_arena_3() -> void:
	var level := await _level()
	var a3 := level.arenas()[2]
	var landing := Vector3(3.0, 4.5, -50.5)
	assert_true(a3.contains(landing), "the landing belongs to the arena below")
	assert_true(a3.contains(Vector3(4.5, 2.25, -44.75)), "and so does the flight")
	assert_true(_reaches(level, Vector3(0.0, 0.0, -34.0), landing, 0.8), "the street reaches the landing by the stair")
	assert_false(_reaches(level, Vector3(0.0, 0.0, -10.0), Vector3(0.0, 0.0, -22.0)), "A1 and A2 are separate islands (gate shut)")
	assert_false(_reaches(level, Vector3(0.0, 0.0, -22.0), Vector3(0.0, 0.0, -34.0)), "A2 and A3 are separate islands (car across)")
	assert_false(_reaches(level, Vector3(3.0, 0.0, 0.2), Vector3(3.0, 0.0, -5.0)), "the start pocket is cut off from A1 while the car is across")


func test_a_player_walks_up_stair_1() -> void:
	var level := await _level()
	var player := level.player
	player.input.scripted = false
	Input.action_press(&"move_forward")
	_put_player(level, Vector3(4.5, 0.1, -39.0))
	player.look_yaw = 0.0
	player.rotation.y = 0.0
	await _ticks(420)
	Input.action_release(&"move_forward")
	player.input.scripted = true
	assert_gt(player.global_position.y, 4.0, "he climbed the stair (y %.2f at z %.1f)" % [player.global_position.y, player.global_position.z])


# --- Edges ---------------------------------------------------------------------------------


func test_the_landings_open_edges_and_the_stairs_open_side_are_guarded() -> void:
	var level := await _level()
	var player := level.player
	_put_player(level, Vector3(1.5, 4.6, -50.0))
	await _ticks(6)
	assert_true(player.test_move(player.global_transform, Vector3(-3.0, 0.0, 0.0)), "he cannot walk off the landing's left edge")
	_put_player(level, Vector3(1.5, 4.6, -49.5))
	await _ticks(6)
	assert_true(player.test_move(player.global_transform, Vector3(0.0, 0.0, 2.0)), "nor off its front edge, beside the stair's head")
	_put_player(level, Vector3(3.6, 1.2, -43.0))
	await _ticks(2)
	assert_true(player.test_move(player.global_transform, Vector3(-3.0, 0.0, 0.0)), "nor off the stair's open side")
	var guards := 0
	for block in level.sections[0].blocks():
		if block is EdgeGuard:
			guards += 1
	assert_gte(guards, 3, "a guard on each open edge")
	assert_eq(level.get_tree().get_nodes_in_group(&"hazard_volume").size(), 0, "no hazard on the street: the landing is railed, the street has no drop")


func test_a_launched_player_cannot_leave_the_landing() -> void:
	var level := await _level()
	var player := level.player
	_put_player(level, Vector3(3.0, 4.6, -50.0))
	await _ticks(6)
	var hit := HitInfo.new()
	hit.victim = player
	hit.damage = 1.0
	hit.reaction = CombatTypes.Reaction.LAUNCH
	hit.knockback = Vector3(-14.0, 4.0, 0.0)
	hit.direction = Vector3(-1.0, 0.0, 0.0)
	hit.contact_point = player.global_position + Vector3.UP
	hit.tier = CombatTypes.HitTier.HEAVY
	player.receive_hit(hit)
	await _ticks(150)
	assert_gt(player.global_position.x, -0.2, "launched at the edge, he stays on the landing (x %.2f)" % player.global_position.x)
	assert_gt(player.global_position.y, 4.0, "still up on the landing")


# --- The route and the whole section -------------------------------------------------------


func test_the_route_runs_from_start_to_exit_through_every_arena_and_up_the_stair() -> void:
	var level := await _level()
	var route := level.route_points()
	assert_gte(route.size(), 8, "a marker through every arena")
	assert_lt(_flat(route[0], level.player_start), 2.0, "it starts at Start")
	var exit_at := level.sections[0].exit_marker().global_position
	assert_lt(_flat(route[route.size() - 1], exit_at), 1.5, "and ends at the Exit")
	assert_almost_eq(route[route.size() - 1].y, exit_at.y, 0.05, "on the landing")
	for i in range(1, route.size()):
		assert_lte(route[i].z, route[i - 1].z + 0.01, "the street runs one way, -Z (point %d)" % i)
		assert_lte(absf(route[i].y - route[i - 1].y), 2.5, "no jump in height between points (point %d)" % i)
	for arena in level.arenas():
		assert_gt(level.first_route_point(arena).x, -INF, "%s has a route point" % arena.arena_id)
		assert_true(arena.contains(level.first_route_point(arena)), "%s's first route point is inside it" % arena.arena_id)
	for p in route:
		var snapped := NavigationServer3D.map_get_closest_point(_map(level), p)
		assert_lt(_flat(snapped, p), 0.5, "route point (%.1f, %.1f) is on a walkable floor" % [p.x, p.z])


func test_the_level_bot_clears_the_whole_street_with_the_real_ai_and_ends_at_the_exit() -> void:
	var bot := QuietBot.new()
	bot.act_filter = "no act has this title"
	bot.presentation = false
	bot.level_path = STREET
	add_child_autofree(bot)
	for i in 600:
		await get_tree().physics_frame
		if bot.finished:
			break
	assert_true(bot.finished, "the bot set itself up")
	Tuning.set_value(&"god_mode", true)
	Tuning.set_value(&"wave_gap_s", 1.0)
	var started := Engine.get_physics_frames()
	var ok: bool = await bot.run_level(0, 2, false, false)
	assert_true(ok, "run_level cleared the street")
	assert_lt(Engine.get_physics_frames() - started, RUN_BUDGET_TICKS, "inside the frame budget")
	for arena in bot.level.arenas():
		assert_eq(arena.state, Arena.State.CLEARED, "%s cleared" % arena.arena_id)
	assert_false(bot.level.arenas()[2].ahead.is_closed(), "the seam shutter is open at the end (the others close behind him)")
	var blocked := 0
	var stalled := 0
	for line in bot.log_lines:
		blocked += 1 if line.begins_with("BLOCKED") else 0
		stalled += 1 if line.begins_with("STALL") else 0
	assert_eq(blocked, 0, "the walk was never blocked by a barrier it should have found open")
	assert_eq(stalled, 0, "the fight never stalled")
