extends GutTest
## Mission 1's roofs (Milestone 5, ROOF): `game/level/mission1/roofs.tscn`, arenas A4 (the terrace with
## its step), A5 (the catwalk walked back above it) and A6 (the top roof, six at once), the two stairs
## between them, three drop edges. Proved in `[level_strip_a, roofs]` (the strip's street and its seam
## shutter stand in for STREET, so A4 has a real behind barrier) with the probe stub for the table tests,
## and as a lone section under the level-run bot with the real enemies.
##
## Plan coordinates are the M5 plan's "Level space" table (the street's Entry at the origin); the
## section's Entry is level (3, 4.5, -53), so a local point is the plan point minus that.

const STRIP_A := "res://tests/fixtures/level_strip_a.tscn"
const ROOFS := "res://game/level/mission1/roofs.tscn"
const PROBE := preload("res://tests/fixtures/spawn_probe_enemy.tscn")
## The roofs' Entry in the plan's level space.
const PLAN_ENTRY := Vector3(3.0, 4.5, -53.0)
const SYNC_FRAMES := 5
## Most ticks the whole lone-section run may take (three arenas, the walks, the stairs).
const RUN_BUDGET_TICKS := 9000

## The tables as the encounter plan gives them: per arena, per wave, "id@point".
const PLAN := {
	&"a4_terrace": [["punk@DoorAhead", "kicker@RoofDoorBehind"],
			["punk@DoorPastStep", "punk@DoorAhead", "kicker@RoofDoorBehind"]],
	&"a5_catwalk": [["punk@DoorFar", "punk@DoorBehindStair"], ["bruiser@DoorFar", "punk@DoorBehindStair"]],
	&"a6_top_roof": [["thug@BigShutter", "punk@BigShutter", "punk@Alley", "bruiser@Alley", "kicker@BehindDoor",
			"punk_veteran@RoofAccess"], ["punk@BigShutter", "punk@Alley", "kicker@BehindDoor"]],
}

var _hits_ko: Array[Node3D] = []
var _cleared: Array[Node3D] = []
var _levels_cleared: int = 0
var _bot: QuietBot


## The level bot that stops instead of quitting the test run's tree.
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
	_hits_ko.clear()
	_cleared.clear()
	_levels_cleared = 0
	CombatEvents.hazard_ko.connect(_on_hazard_ko)
	CombatEvents.arena_cleared.connect(_on_arena_cleared)
	CombatEvents.level_cleared.connect(_on_level_cleared)


func after_each() -> void:
	CombatEvents.hazard_ko.disconnect(_on_hazard_ko)
	CombatEvents.arena_cleared.disconnect(_on_arena_cleared)
	CombatEvents.level_cleared.disconnect(_on_level_cleared)
	PlaceholderAnims.warn_on_fallback = true
	GameInput.menu_open = false
	Tuning.reset_to_default()
	Tuning.set_value(&"ai_frozen", false)
	Tuning.set_value(&"god_mode", false)
	TimeController.clear()


func after_all() -> void:
	OS.delay_msec(250)


func _on_hazard_ko(actor: Node3D, _hazard: Node3D) -> void:
	_hits_ko.append(actor)


func _on_arena_cleared(arena: Node3D) -> void:
	_cleared.append(arena)


func _on_level_cleared(_level: Node3D) -> void:
	_levels_cleared += 1


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## `[level_strip_a, roofs]`: no presentation, the probe standing in for every archetype when `probe`
## (a still body that records where it came in), the player's input scripted. The roofs' arenas are
## `level.arenas()[1..3]`.
func _level(probe: bool = true, frames: int = SYNC_FRAMES) -> LevelRoot:
	var level := LevelRoot.new()
	level.section_paths = PackedStringArray([STRIP_A, ROOFS])
	level.with_presentation = false
	add_child_autofree(level)
	if probe:
		level.spawner.scene_override = {&"punk": PROBE, &"thug": PROBE, &"kicker": PROBE, &"bruiser": PROBE,
				&"punk_veteran": PROBE, &"boss": PROBE}
	level.player.input.scripted = true
	await _ticks(frames)
	return level


func _roofs(level: LevelRoot) -> LevelSection:
	return level.sections[1]


## The level-space point of plan point (x, y, z) in a level built by `_level()`.
func _p(level: LevelRoot, x: float, y: float, z: float) -> Vector3:
	return _roofs(level).global_position + Vector3(x, y, z) - PLAN_ENTRY


func _arena(level: LevelRoot, index: int) -> Arena:
	return level.arenas()[index + 1]


func _put_player(level: LevelRoot, at: Vector3) -> void:
	level.player.global_position = at
	level.player.velocity = Vector3.ZERO


func _map(level: LevelRoot) -> RID:
	return level.get_world_3d().navigation_map


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _reaches(level: LevelRoot, from: Vector3, to: Vector3, tolerance: float = 0.6) -> bool:
	var goal := NavigationServer3D.map_get_closest_point(_map(level), to)
	var path := NavigationServer3D.map_get_path(_map(level), from, goal, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(goal) < tolerance


func _until(check: Callable, frames: int) -> bool:
	for i in frames:
		if check.call():
			return true
		await _ticks(1)
	return check.call()


func _kill_all(level: LevelRoot) -> void:
	for enemy in level.enemies():
		enemy.health = 0.0
	EncounterSpawner.remove_enemies(get_tree(), true)


func _hit(victim: CombatActor, knockback: Vector3) -> HitInfo:
	var hit := HitInfo.new()
	hit.victim = victim
	hit.damage = 1.0
	hit.reaction = CombatTypes.Reaction.LAUNCH
	hit.knockback = knockback
	hit.direction = Vector3(knockback.x, 0.0, knockback.z).normalized()
	hit.contact_point = victim.global_position + Vector3.UP
	hit.tier = CombatTypes.HitTier.HEAVY
	return hit


# --- The section's contract ---------------------------------------------------------------


func test_the_section_follows_the_level_space_contract() -> void:
	var level := await _level()
	var roofs := _roofs(level)
	assert_eq(level.sections.size(), 2, "the strip's street and the roofs")
	assert_true(roofs.entry().position.is_zero_approx(), "Entry is the section's origin")
	var exit_local := roofs.exit_marker().position
	assert_almost_eq(exit_local.x, 19.0, 0.05, "Exit at the A6/A7 gate (level 22, 12, -83)")
	assert_almost_eq(exit_local.y, 7.5, 0.05)
	assert_almost_eq(exit_local.z, -30.0, 0.05)
	assert_eq(roofs.floor_heights, PackedFloat32Array([0.0, 1.0, 4.5, 7.5]), "the plan's floor heights")
	assert_true(roofs.entry().global_position.is_equal_approx(level.sections[0].exit_marker().global_position),
			"Entry sits on the street's Exit")
	var gate := roofs.exit_barrier()
	assert_not_null(gate, "an ExitBarrier at the gate")
	assert_eq(gate.kind, Barrier.Kind.GATE, "a chain-link gate")
	assert_true(gate.start_closed)
	assert_true(gate.global_position.is_equal_approx(roofs.exit_marker().global_position), "at the Exit")
	assert_eq(roofs.arena_list().size(), 3)
	assert_eq(level.arenas().size(), 4)
	var ids: Array[StringName] = []
	for arena in roofs.arena_list():
		ids.append(arena.arena_id)
	assert_eq(ids, [&"a4_terrace", &"a5_catwalk", &"a6_top_roof"] as Array[StringName])
	assert_eq(_arena(level, 0).behind, level.sections[0].exit_barrier(), "A4 is shut in by the seam shutter")
	assert_eq(_arena(level, 0).ahead, _arena(level, 1).behind, "stair 2's gate serves A4 and A5")
	assert_eq(_arena(level, 1).ahead, _arena(level, 2).behind, "stair 3's shutter serves A5 and A6")
	assert_eq(_arena(level, 0).ahead.kind, Barrier.Kind.GATE, "a chain-link gate at the top of stair 2")
	assert_eq(_arena(level, 1).ahead.kind, Barrier.Kind.SHUTTER, "a rolling shutter at the top of stair 3")
	assert_eq(_arena(level, 2).ahead, gate, "A6's ahead barrier is the exit gate")
	assert_eq(roofs.stairs().size(), 3, "the step flight, stair 2 and stair 3")
	assert_not_null(roofs.start_marker(), "a Start for the lone section")
	assert_true(_arena(level, 0).contains(roofs.start_marker().global_position), "inside A4")


func test_the_tables_are_the_encounter_plan() -> void:
	var level := await _level()
	var total := 0
	for arena in _roofs(level).arena_list():
		var table := arena.table
		assert_not_null(table, "%s has a table" % arena.arena_id)
		assert_false(table.loop, "%s plays once" % arena.arena_id)
		var want: Array = PLAN[arena.arena_id]
		assert_eq(table.waves.size(), want.size(), "%s: waves" % arena.arena_id)
		for w in want.size():
			var ids := PackedStringArray()
			var points := PackedStringArray()
			for entry: String in want[w]:
				ids.append(entry.get_slice("@", 0))
				points.append(entry.get_slice("@", 1))
			assert_eq(table.waves[w], ids, "%s wave %d ids" % [arena.arena_id, w + 1])
			assert_eq(table.points_for(w), points, "%s wave %d spawn points" % [arena.arena_id, w + 1])
			total += ids.size()
	assert_eq(total, 18, "A4 5, A5 4, A6 9")
	var a6: EncounterTable = _arena(level, 2).table
	assert_eq(a6.waves[0].size(), 6, "A6's first wave is six at once")
	assert_true("punk_veteran" in a6.waves[0], "with the veteran Punk")
	for arena in _roofs(level).arena_list():
		for w in arena.table.waves.size():
			for id in arena.table.waves[w]:
				assert_not_null(EnemyCatalog.scene(StringName(id)), "%s is a real enemy" % id)


func test_every_named_point_and_its_lane_point_lie_inside_their_arena_on_the_navmesh() -> void:
	var level := await _level()
	var seen := 0
	for arena in _roofs(level).arena_list():
		var list := arena.spawn_point_list()
		for point in list:
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
		# Every point a table names exists in the arena.
		var names: Array[String] = []
		for point in list:
			names.append(String(point.name))
		for w in arena.table.waves.size():
			for named in arena.table.points_for(w):
				assert_true(names.has(named), "%s names a point (%s) the arena has" % [arena.arena_id, named])
	assert_eq(seen, 10, "A4 has three points, A5 three, A6 four")


# --- Navigation --------------------------------------------------------------------------


func test_each_arena_is_an_island_and_the_stairs_connect_the_floors_inside_one() -> void:
	var level := await _level()
	var a4_start := _p(level, 0.0, 4.5, -56.0)
	var a4_second := _p(level, 0.0, 5.5, -72.0)
	var a4_stair_top := _p(level, 4.4, 9.0, -79.5)
	var a5_start := _p(level, 7.5, 9.0, -79.5)
	var a5_mid := _p(level, 10.0, 9.0, -70.0)
	var a5_stair_top := _p(level, 14.6, 12.0, -62.5)
	var a6_start := _p(level, 17.5, 12.0, -62.5)
	var a6_far := _p(level, 22.0, 12.0, -80.0)
	assert_true(_reaches(level, a4_start, a4_second, 0.8), "the step flight joins the terrace's two levels")
	assert_true(_reaches(level, a4_second, a4_stair_top, 0.8), "stair 2 belongs to A4 and runs to its head")
	assert_true(_reaches(level, a5_start, a5_mid), "the catwalk walks")
	assert_true(_reaches(level, a5_mid, a5_stair_top, 0.8), "stair 3 belongs to A5 and runs to its head")
	assert_true(_reaches(level, a6_start, a6_far), "the top roof walks")
	assert_false(_reaches(level, a4_start, a5_start), "no path A4 to A5 with stair 2's gate shut")
	assert_false(_reaches(level, a5_mid, a6_start), "no path A5 to A6 with stair 3's shutter shut")
	assert_false(_reaches(level, a4_start, a6_far))
	assert_true(_arena(level, 0).contains(a4_stair_top), "stair 2's head is A4's")
	assert_false(_arena(level, 1).contains(a4_stair_top))
	assert_true(_arena(level, 1).contains(a5_start), "the catwalk is A5's")
	assert_true(_arena(level, 1).contains(_p(level, 10.0, 10.5, -62.5)), "stair 3 is A5's")
	assert_true(_arena(level, 2).contains(a6_start))


func test_every_floor_height_is_on_the_navmesh() -> void:
	var level := await _level()
	var roofs := _roofs(level)
	var probes := {
		0.0: _p(level, 0.0, 4.5, -58.0),
		1.0: _p(level, 0.0, 5.5, -72.0),
		4.5: _p(level, 10.0, 9.0, -70.0),
		7.5: _p(level, 22.0, 12.0, -70.0),
	}
	for h: float in roofs.floor_heights:
		assert_true(probes.has(h), "a probe point for floor %.1f" % h)
		var at: Vector3 = probes[h]
		var snapped := NavigationServer3D.map_get_closest_point(_map(level), at)
		assert_lt(_flat(snapped, at), 0.3, "floor %.1f has navmesh under its probe" % h)
		assert_lt(absf(snapped.y - at.y), 0.45, "at the right height (floor %.1f)" % h)
	# Nothing a body could stand on at the catch floors, the ground or the walls' tops.
	var mesh := level.nav_region.navigation_mesh
	var verts := mesh.get_vertices()
	var heights: Array[float] = []
	for section in level.sections:
		for h: float in section.floor_heights:
			heights.append(section.global_position.y + h)
	for p in mesh.get_polygon_count():
		var y := verts[mesh.get_polygon(p)[0]].y
		var near := false
		for h in heights:
			if y >= h - 0.35 and y <= h + 0.55:
				near = true
		assert_true(near or _on_a_stair(level, verts[mesh.get_polygon(p)[0]]), "polygon %d at y %.2f is a floor or a stair" % [p, y])
		if not near:
			break


func _on_a_stair(level: LevelRoot, point: Vector3) -> bool:
	for section in level.sections:
		for flight in section.stairs():
			if flight.footprint().grow(0.4).has_point(point):
				return true
	return false


func test_the_route_runs_from_start_to_the_exit_through_every_arena() -> void:
	var level := await _level()
	var roofs := _roofs(level)
	var route := roofs.route_points()
	assert_gt(route.size(), 10, "a route through three arenas and three flights")
	assert_true(_arena(level, 0).contains(route[0]), "it starts inside A4")
	assert_lt(_flat(route[route.size() - 1], roofs.exit_marker().global_position), 3.5, "and ends at the gate")
	for k in 3:
		assert_ne(level.first_route_point(_arena(level, k)), Vector3.INF, "arena %d has a route point" % (k + 4))
	# Stair 2's head and stair 3's head lie on the route.
	var heights: Array[float] = []
	for point in route:
		heights.append(snappedf(point.y - roofs.global_position.y, 0.5))
	for h in [0.0, 1.0, 4.5, 7.5]:
		assert_true(heights.has(h), "the route touches floor %.1f" % h)
	# Walk it, arena by arena, on the real navmesh: consecutive points inside one arena are connected.
	for i in route.size() - 1:
		var from := route[i]
		var to := route[i + 1]
		var same := false
		for k in 3:
			if _arena(level, k).contains(from) and _arena(level, k).contains(to):
				same = true
		if same:
			assert_true(_reaches(level, from, to, 0.8), "route point %d reaches point %d" % [i, i + 1])


func test_no_solid_block_leaves_the_sections_footprint() -> void:
	var level := await _level(false)
	var roofs := _roofs(level)
	# The plan's footprint (x -5..29, z -53..-83) is x -8..26, z 0..-30 locally; one metre of tolerance.
	var lo := Vector2(-9.0, -31.0)
	var hi := Vector2(27.0, 1.0)
	var solids := 0
	for block in roofs.blocks():
		if not block.solid:
			continue
		solids += 1
		var box: AABB = block.world_aabb()
		var local_lo := Vector2(box.position.x, box.position.z) - Vector2(roofs.global_position.x, roofs.global_position.z)
		var local_hi := local_lo + Vector2(box.size.x, box.size.z)
		assert_true(local_lo.x >= lo.x and local_lo.y >= lo.y and local_hi.x <= hi.x and local_hi.y <= hi.y,
				"%s lies inside the roofs' footprint (%s to %s)" % [block.name, local_lo, local_hi])
	assert_gt(solids, 20)


# --- Fights: the tables, the drops --------------------------------------------------------


## The probe stub stands where it came in; move each on to its lane point, as a real enemy walks out
## of its doorway, so the next one named at the same point has room.
func _walk_out(level: LevelRoot) -> void:
	for enemy in level.enemies():
		var from: Vector3 = enemy.get("entered_from")
		var lane: Vector3 = enemy.get("entered_lane")
		if from.is_finite() and lane.is_finite() and _flat(enemy.global_position, from) < 0.3:
			enemy.global_position = lane


## Play arena `k` (0 = A4) on the probe stub: lock it, collect each wave's ids and the points they
## came in at, never more than six alive, kill each wave, then wait for the clear.
func _play(level: LevelRoot, k: int, stand: Vector3) -> Dictionary:
	var arena := _arena(level, k)
	level.start_at_arena(k + 1)
	_put_player(level, stand)
	await _ticks(4)
	var seen := {waves = [], max_alive = 0}
	var wave_ids: Array = []
	level.spawner.wave_started.connect(func(_n: int, ids: PackedStringArray) -> void: wave_ids.append(ids))
	var by_name := {}
	for point in arena.spawn_point_list():
		by_name[point.name] = point.position
	for w in arena.table.waves.size():
		var size := arena.table.waves[w].size()
		var came := await _until(func() -> bool:
			seen.max_alive = maxi(seen.max_alive, level.spawner.alive_count())
			_walk_out(level)
			return level.enemies().size() >= size, 600)
		assert_true(came, "%s wave %d: all %d came in" % [arena.arena_id, w + 1, size])
		var at: Array[String] = []
		for enemy in level.enemies():
			var from: Vector3 = enemy.get("entered_from")
			for point_name: String in by_name:
				if _flat(from, by_name[point_name]) < 0.5:
					at.append(point_name)
		at.sort()
		var want: Array[String] = []
		for named in arena.table.points_for(w):
			want.append(named)
		want.sort()
		assert_eq(at, want, "%s wave %d came in at the named points" % [arena.arena_id, w + 1])
		seen.waves.append(wave_ids[w] if w < wave_ids.size() else PackedStringArray())
		_kill_all(level)
		await _ticks(2)
	var done := await _until(func() -> bool:
		_kill_all(level)
		return arena.state == Arena.State.CLEARED, 600)
	assert_true(done, "%s clears when its table is done" % arena.arena_id)
	return seen


func test_each_arena_locks_plays_its_table_and_clears() -> void:
	var level := await _level()
	var stands := [_p(level, 0.0, 4.5, -57.0), _p(level, 10.0, 9.0, -70.0), _p(level, 22.0, 12.0, -68.0)]
	for k in 3:
		var arena := _arena(level, k)
		var seen: Dictionary = await _play(level, k, stands[k])
		assert_lte(int(seen.max_alive), 6, "%s never had more than six alive" % arena.arena_id)
		var want: Array = PLAN[arena.arena_id]
		for w in want.size():
			var ids := PackedStringArray()
			for entry: String in want[w]:
				ids.append(entry.get_slice("@", 0))
			assert_eq(seen.waves[w], ids, "%s wave %d ids" % [arena.arena_id, w + 1])
		assert_eq(arena.state, Arena.State.CLEARED)
		assert_false(arena.ahead.is_closed(), "%s opens its ahead barrier" % arena.arena_id)
		assert_eq(_cleared.back(), arena, "arena_cleared fired for it")
	assert_eq(_levels_cleared, 1, "the last arena's clear is the level's here (the strip has nothing after)")
	assert_false(_roofs(level).exit_barrier().is_closed(), "the gate to the boss roof is open")
	assert_true(_hits_ko.is_empty(), "nobody went over an edge on his own")


func test_a_punk_launched_off_each_drop_edge_is_ko_d() -> void:
	var level := await _level(false)
	# [arena, where he stands, the launch toward the edge, where the player stands]
	var cases := [
		["A4's front edge", 0, Vector3(-3.5, 4.5, -58.0), Vector3(-14.0, 4.0, 0.0)],
		["A5's open side", 1, Vector3(7.5, 9.0, -70.0), Vector3(-14.0, 4.0, 0.0)],
		["A6's far edge", 2, Vector3(26.5, 12.0, -70.0), Vector3(14.0, 4.0, 0.0)],
	]
	for c in cases:
		_hits_ko.clear()
		level.start_at_arena(int(c[1]) + 1)
		Tuning.set_value(&"ai_frozen", true)
		var at := _p(level, c[2].x, c[2].y, c[2].z)
		_put_player(level, _p(level, 10.0, 9.0, -70.0) if int(c[1]) != 1 else _p(level, 8.0, 9.0, -76.0))
		var enemy := level.spawner.spawn_enemy(&"punk", at, 0.0)
		await _ticks(4)
		assert_gt(enemy.health, 0.0)
		enemy.receive_hit(_hit(enemy, c[3]))
		assert_true(enemy.is_flying(), "%s: launched toward the edge" % c[0])
		assert_true(await _until(func() -> bool: return not _hits_ko.is_empty(), 120), "%s: the hazard took him" % c[0])
		assert_eq(_hits_ko, [enemy] as Array[Node3D], "%s: hazard_ko fired once, for him" % c[0])
		assert_lte(enemy.health, 0.0, "%s: KO'd at once" % c[0])
		assert_true(await _until(func() -> bool: return enemy.is_ko(), 400), "%s: he lies out his KO" % c[0])
		var floor_y := at.y
		assert_lt(enemy.global_position.y, floor_y - 2.0, "%s: below the floor he was launched from" % c[0])
		EncounterSpawner.remove_enemies(get_tree(), true)
		Tuning.set_value(&"ai_frozen", false)


func test_the_guard_holds_the_player_at_every_open_edge() -> void:
	var level := await _level(false)
	# [arena, start, yaw toward the edge, the coordinate that must hold, its limit, which side]
	var cases := [
		["A4", 0, Vector3(-3.5, 4.5, -60.0), PI * 0.5, -5.0, 1],
		["A4 upper level", 0, Vector3(-3.5, 5.5, -72.0), PI * 0.5, -5.0, 1],
		["A5", 1, Vector3(7.5, 9.0, -70.0), PI * 0.5, 5.0, 1],
		["A6", 2, Vector3(26.0, 12.0, -70.0), -PI * 0.5, 29.0, -1],
	]
	for c in cases:
		level.start_at_arena(int(c[1]) + 1)
		var from := _p(level, c[2].x, c[2].y, c[2].z)
		_put_player(level, from)
		level.player.look_yaw = c[3]
		level.player.rotation.y = c[3]
		level.player.input.scripted_move = Vector2(0.0, 1.0)
		await _ticks(150)
		level.player.input.scripted_move = Vector2.ZERO
		var edge_x := _p(level, float(c[4]), 0.0, 0.0).x
		var side := int(c[5])
		assert_true(level.player.global_position.x * side >= edge_x * side, "%s: he stayed inside the lip (x %.2f, lip %.2f)" % [c[0], level.player.global_position.x, edge_x])
		assert_gt(level.player.global_position.y, from.y - 0.5, "%s: still on his floor" % c[0])


func test_the_pipe_lies_in_front_of_the_big_shutter() -> void:
	var level := await _level()
	var spots := _roofs(level).pickup_spots()
	assert_eq(spots.size(), 1, "one pickup spot")
	var pipes := get_tree().get_nodes_in_group(&"weapon")
	assert_eq(pipes.size(), 1, "one pipe on the level")
	await _ticks(90)
	var pipe := pipes[0] as Weapon
	assert_lt(_flat(pipe.global_position, spots[0].global_position), 0.3, "it lies at its spot")
	assert_lt(absf(pipe.global_position.y - _p(level, 0.0, 12.0, 0.0).y), 0.4, "on the top roof")
	var shutter: Vector3 = _arena(level, 2).get_node("BigShutter").global_position
	assert_lt(_flat(pipe.global_position, shutter), 3.0, "within a few metres of the big shutter's doorway")
	assert_true(pipe.is_available(), "an ordinary pick-up")


func test_a6s_first_wave_fits_the_roof_and_nobody_goes_over() -> void:
	var level := await _level(false)
	var arena := _arena(level, 2)
	level.start_at_arena(3)
	level.player.input.scripted = true
	await _ticks(4)
	_put_player(level, _p(level, 22.0, 12.0, -68.0))
	assert_eq(arena.state, Arena.State.LOCKED, "A6 locked")
	assert_true(await _until(func() -> bool: return level.enemies().size() >= 6, 900), "six came in")
	var types := {}
	for enemy in level.enemies():
		types[String(enemy.archetype)] = int(types.get(String(enemy.archetype), 0)) + 1
	assert_eq(types.get("punk", 0), 3, "two Punks and the veteran (a Punk too)")
	assert_eq(types.get("thug", 0), 1)
	assert_eq(types.get("kicker", 0), 1)
	assert_eq(types.get("bruiser", 0), 1)
	await _ticks(420)
	assert_lte(level.spawner.alive_count(), 6, "never over six alive")
	for enemy in level.enemies():
		assert_true(arena.contains(enemy.global_position) or enemy.health <= 0.0,
				"%s stayed on the roof (at %s)" % [enemy.name, enemy.global_position])
	assert_true(_hits_ko.is_empty(), "none went off an edge on his own")


# --- The real thing, under the bot ---------------------------------------------------------


func test_the_lone_section_runs_clean_under_the_level_bot() -> void:
	_bot = QuietBot.new()
	_bot.act_filter = "no act has this title"
	_bot.presentation = false
	_bot.level_path = ROOFS
	add_child_autofree(_bot)
	for i in 600:
		await get_tree().physics_frame
		if _bot.finished:
			break
	assert_true(_bot.finished, "the bot set itself up")
	Tuning.set_value(&"god_mode", true)
	Tuning.set_value(&"wave_gap_s", 1.0)
	var started := Engine.get_physics_frames()
	var ok: bool = await _bot.run_level(0, -1, false, false)
	assert_true(ok, "the run cleared A4, A5 and A6")
	assert_lt(Engine.get_physics_frames() - started, RUN_BUDGET_TICKS, "inside the frame budget")
	for arena in _bot.level.arenas():
		assert_eq(arena.state, Arena.State.CLEARED, "%s cleared" % arena.arena_id)
	var waves := 0
	var arenas_locked := 0
	for line in _bot.log_lines:
		if line.begins_with("WAVE "):
			waves += 1
		elif line.begins_with("ARENA+ "):
			arenas_locked += 1
		assert_false(line.begins_with("STALL") or line.begins_with("BLOCKED"), "the run logged no %s" % line)
	assert_eq(waves, 6, "two waves in each of three arenas")
	assert_eq(arenas_locked, 3)
	assert_eq(_bot.hazard_kos, 0, "nobody went over an edge on his own")
	assert_true(_bot.level.arenas()[2].contains(_bot.level.player.global_position), "he ended on the top roof")
	assert_true(_bot.level.sections[0].exit_barrier().is_closed() == false, "the gate is open")
