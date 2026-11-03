extends GutTest
## The level kit (Milestone 5, KIT): sections chained on their markers, arenas and their locks, the
## three barrier kinds, the GO cue and CLEAR!, drop-offs (the hazard KO, the edge guard, the fall
## rule), stairs, pickup spots, the spawner's finite mode and the navmesh rule, all proved in the
## two-section test strip (tests/fixtures/level_strip.tscn: a street with a parked car behind, a
## doorway, an alley and a vehicle spawn, a stair up 4.5 m to a shutter; a terrace with a chain-link
## gate ahead, a drop edge, a pipe). The strip's enemies are the probe stub unless a test needs the
## real AI.

const STRIP := "res://tests/fixtures/level_strip.tscn"
const PROBE := preload("res://tests/fixtures/spawn_probe_enemy.tscn")
const ReadabilityProbe := preload("res://tests/bot/readability_probe.gd")
## The frames the navigation map needs to sync after a level's _ready().
const SYNC_FRAMES := 5
## Strip B in level space: its Entry is the seam shutter's centre.
const B_AT := Vector3(6.5, 4.5, -24.0)

var _hits_ko: Array[Node3D] = []
var _cleared: Array[Node3D] = []
var _levels_cleared: int = 0


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
	# Debug switches are no preset's: put back the one a test sets.
	Tuning.set_value(&"ai_frozen", false)
	Tuning.set_value(&"god_mode", false)
	TimeController.clear()


func _on_hazard_ko(actor: Node3D, _hazard: Node3D) -> void:
	_hits_ko.append(actor)


func _on_arena_cleared(arena: Node3D) -> void:
	_cleared.append(arena)


func _on_level_cleared(_level: Node3D) -> void:
	_levels_cleared += 1


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## The strip with no presentation, the probe standing in for every archetype, the player's input
## scripted (he stands where a test puts him).
func _level(frames: int = SYNC_FRAMES, probe: bool = true) -> LevelRoot:
	var level := (load(STRIP) as PackedScene).instantiate() as LevelRoot
	level.with_presentation = false
	add_child_autofree(level)
	if probe:
		level.spawner.scene_override = {&"punk": PROBE, &"thug": PROBE, &"boss": PROBE}
	level.player.input.scripted = true
	await _ticks(frames)
	return level


func _put_player(level: LevelRoot, at: Vector3) -> void:
	level.player.global_position = at
	level.player.velocity = Vector3.ZERO


## Level-space point of a point of strip B (its local coordinates).
func _b(x: float, y: float, z: float) -> Vector3:
	return B_AT + Vector3(x, y, z)


## Kill every AI enemy of the level (health to 0, as a test of the spawner's "cleared").
func _kill_all(level: LevelRoot) -> void:
	for enemy in level.enemies():
		enemy.health = 0.0


# --- Sections, seams, arenas ---------------------------------------------------------------


func test_sections_chain_on_their_markers_and_the_seam_barrier_serves_both_arenas() -> void:
	var level := await _level()
	assert_eq(level.sections.size(), 2, "both strip sections loaded")
	var a := level.sections[0]
	var b := level.sections[1]
	assert_true(b.global_position.is_equal_approx(a.exit_marker().global_position), "B's Entry sits on A's Exit")
	assert_true(b.entry().global_position.is_equal_approx(B_AT), "at the seam shutter's centre")
	var arenas := level.arenas()
	assert_eq(arenas.size(), 2)
	assert_eq(arenas[0].ahead, a.exit_barrier(), "arena 1's ahead barrier is the seam shutter")
	assert_eq(arenas[1].behind, a.exit_barrier(), "and arena 2's behind barrier is the same shutter (no behind named)")
	assert_eq(arenas[0].behind, a.barriers()[0], "arena 1's behind barrier is the car")
	assert_eq(arenas[0].behind.kind, Barrier.Kind.CAR)
	assert_eq(arenas[1].ahead.kind, Barrier.Kind.GATE)
	assert_eq(a.exit_barrier().kind, Barrier.Kind.SHUTTER)
	assert_eq(level.route_points().size(), 9, "the route runs through both sections")


func test_a_missing_section_is_skipped_with_a_warning_and_a_lone_section_is_a_level() -> void:
	var level := (load(STRIP) as PackedScene).instantiate() as LevelRoot
	level.with_presentation = false
	level.section_paths = PackedStringArray(["res://tests/fixtures/no_such_section.tscn", "res://tests/fixtures/level_strip_a.tscn"])
	add_child_autofree(level)
	await _ticks(SYNC_FRAMES)
	assert_eq(level.sections.size(), 1, "the missing scene is skipped")
	assert_eq(level.arenas().size(), 1)
	assert_not_null(level.player, "a one-section level plays")
	assert_eq(level.arenas()[0].ahead, level.sections[0].exit_barrier(), "its last arena's ahead is its own ExitBarrier")


func test_the_level_starts_with_ahead_barriers_closed_and_behind_open() -> void:
	var level := await _level()
	var arenas := level.arenas()
	assert_false(arenas[0].behind.is_closed(), "the car starts open")
	assert_true(arenas[0].ahead.is_closed(), "the seam shutter starts closed")
	assert_true(arenas[1].ahead.is_closed(), "the terrace gate starts closed")
	assert_eq(level.current_arena(), arenas[0])
	assert_true(level.player.global_position.is_equal_approx(level.player_start), "the player starts at Start")


func test_the_lock_closes_behind_only_past_the_inset() -> void:
	var level := await _level()
	var arena := level.arenas()[0]
	var car := arena.behind
	_put_player(level, Vector3(0.0, 0.1, -2.0))
	await _ticks(4)
	assert_eq(arena.state, Arena.State.WAITING, "before the car: outside the arena")
	_put_player(level, Vector3(0.0, 0.1, -6.2))
	await _ticks(4)
	assert_true(arena.contains(level.player.global_position), "past the car, inside the arena")
	assert_eq(arena.state, Arena.State.WAITING, "but 1.2 m past it is not the inset's 2.0")
	assert_false(car.is_closed(), "so the car is still open")
	_put_player(level, Vector3(0.0, 0.1, -7.5))
	await _ticks(4)
	assert_eq(arena.state, Arena.State.LOCKED, "2.5 m past the car locks the arena")
	assert_true(car.is_closed(), "the car closes behind him")
	assert_true(arena.ahead.is_closed(), "the ahead barrier was never open")


func test_a_barrier_collides_only_while_closed_and_moves_over_its_tunable_time() -> void:
	var level := await _level()
	var car := level.arenas()[0].behind
	var from := Vector3(0.0, 1.0, -3.0)
	var to := Vector3(0.0, 1.0, -7.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, CombatTypes.bit(CombatTypes.LAYER_WORLD))
	var space := level.get_world_3d().direct_space_state
	assert_true(space.intersect_ray(query).is_empty(), "an open car: nothing in the way")
	Tuning.set_value(&"barrier_close_s", 0.5)
	var moved: Array[bool] = []
	car.moved.connect(func(closed: bool) -> void: moved.append(closed))
	car.close()
	await _ticks(2)
	assert_false(space.intersect_ray(query).is_empty(), "a closing car blocks at once")
	assert_true(car.is_moving())
	await _ticks(20)
	assert_gt(car.progress(), 0.0)
	assert_lt(car.progress(), 1.0, "mid-way after a third of a second")
	assert_true(moved.is_empty())
	await _ticks(16)
	assert_eq(car.progress(), 1.0, "arrived after its 0.5 s")
	assert_eq(moved, [true] as Array[bool], "moved(true) fired once")
	car.open()
	await _ticks(2)
	assert_true(space.intersect_ray(query).is_empty(), "an open barrier has no collider")


func test_all_three_barrier_kinds_close_and_open() -> void:
	var level := await _level()
	var a := level.sections[0]
	var shutter := a.exit_barrier()
	var car := level.arenas()[0].behind
	var gate := level.arenas()[1].ahead
	for barrier: Barrier in [shutter, car, gate]:
		barrier.snap(false)
		assert_false(barrier.is_closed())
		assert_eq(barrier.progress(), 0.0)
		barrier.close()
		await _ticks(60)
		assert_eq(barrier.progress(), 1.0, "%s closed" % barrier.name)
		assert_true(barrier.is_closed())
		barrier.open()
		await _ticks(60)
		assert_eq(barrier.progress(), 0.0, "%s open" % barrier.name)
	# The shutter drops (its panel is above the opening when open); the gate slides sideways; the car rolls.
	shutter.snap(false)
	assert_gt(shutter.get_node("Panel").position.y, 3.0, "an open shutter is rolled up above the opening")
	gate.snap(false)
	assert_gt(absf(gate.get_node("Panel").position.x), 10.0, "an open gate has slid aside by its width")
	car.snap(true)
	assert_eq(car.get_node("Panel").position, Vector3.ZERO, "a closed car stands across the opening")


# --- The navmesh and the spawn points ---------------------------------------------------------


func _map(level: LevelRoot) -> RID:
	return level.get_world_3d().navigation_map


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Whether a navmesh path from `from` to `to` ends within `tolerance` of `to`.
func _reaches(level: LevelRoot, from: Vector3, to: Vector3, tolerance: float = 0.6) -> bool:
	var path := NavigationServer3D.map_get_path(_map(level), from, to, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(to) < tolerance


func test_the_navmesh_keeps_floors_and_stairs_and_drops_prop_and_wall_tops() -> void:
	var level := await _level()
	assert_true(NavBaker.map_ready(level.get_world_3d()), "the map synced")
	var mesh := level.nav_region.navigation_mesh
	var verts := mesh.get_vertices()
	assert_gt(mesh.get_polygon_count(), 40, "the strip is walkable")
	var footprints: Array[AABB] = []
	for section in level.sections:
		for flight in section.stairs():
			footprints.append(flight.footprint())
	var floors := PackedFloat32Array([0.0, 4.5])
	var on_stairs := 0
	for p in mesh.get_polygon_count():
		var poly := mesh.get_polygon(p)
		var centre := Vector3.ZERO
		var high := -INF
		for index in poly:
			centre += verts[index]
			high = maxf(high, verts[index].y)
		centre /= float(poly.size())
		var ok := false
		for height in floors:
			if absf(centre.y - height) <= 0.5:
				ok = true
		for footprint in footprints:
			if footprint.has_point(centre):
				ok = true
				on_stairs += 1 if centre.y > 0.6 and centre.y < 4.0 else 0
		assert_true(ok, "polygon %d at y %.2f is a floor or a stair" % [p, centre.y])
	assert_gt(on_stairs, 0, "the stairs are walkable: polygons climb between the floors (%d)" % on_stairs)
	# Nothing walkable on the parked car prop (1.5 m up) or under the edge on the catch floor.
	var car_top := NavigationServer3D.map_get_closest_point(_map(level), Vector3(-6.9, 1.7, -12.5))
	assert_lt(car_top.y, 0.6, "the car's roof is not on the mesh")
	assert_lt(level.nav_bake_usec, 60000, "the bake is a few tens of ms at most (%d us)" % level.nav_bake_usec)


func test_each_arena_is_a_navmesh_island_and_the_stairs_connect_the_floors_inside_one() -> void:
	var level := await _level()
	var a1 := level.arenas()[0]
	var a2 := level.arenas()[1]
	var in_a1 := Vector3(0.0, 0.0, -10.0)
	var in_a2 := _b(-0.5, 0.0, -10.0)
	assert_true(_reaches(level, in_a1, Vector3(-4.0, 0.0, -20.0)), "inside arena 1 paths run")
	assert_true(_reaches(level, in_a2, _b(2.0, 0.0, -3.0)), "inside arena 2 paths run")
	assert_true(_reaches(level, in_a1, Vector3(6.5, 4.5, -22.5), 0.8), "arena 1's street connects to its landing by the stairs")
	assert_false(_reaches(level, in_a1, in_a2), "no path from arena 1 to arena 2 with the barriers closed")
	assert_false(_reaches(level, Vector3(0.0, 0.0, -3.0), in_a1), "the car cuts the street before arena 1 off")
	assert_true(a1.contains(Vector3(6.5, 4.5, -22.5)), "the landing belongs to the arena below")
	assert_false(a2.contains(Vector3(6.5, 4.5, -22.5)))


func test_every_spawn_point_is_on_the_navmesh_inside_its_arena_and_reaches_its_lane_point() -> void:
	var level := await _level()
	var seen := 0
	for arena in level.arenas():
		var list := arena.spawn_point_list()
		assert_gt(list.size(), 2, "%s has spawn points" % arena.arena_id)
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
			assert_true(point.has_all(["position", "yaw", "tag", "lane_point", "name"]), "the spawner's point keys")
		for other in level.arenas():
			if other != arena:
				for point in list:
					assert_false(other.contains(point.position), "%s is in no other arena" % point.name)
	assert_eq(seen, 6)
	var tags: Array[String] = []
	for point in level.arenas()[0].spawn_point_list():
		tags.append(String(point.tag))
	tags.sort()
	assert_eq(tags, ["alley", "doorway", "vehicle"] as Array[String], "arena 1: a doorway, an alley and a vehicle")
	assert_eq(level.arenas()[1].spawn_point_list()[0].tag, &"stairwell", "arena 2 has a stairwell landing spawn")


func test_a_player_walks_up_the_stairs() -> void:
	var level := await _level()
	var player := level.player
	player.input.scripted = false
	Input.action_press(&"move_forward")
	_put_player(level, Vector3(6.5, 0.1, -12.0))
	player.look_yaw = 0.0
	player.rotation.y = 0.0
	await _ticks(300)
	Input.action_release(&"move_forward")
	player.input.scripted = true
	assert_gt(player.global_position.y, 4.0, "he climbed the 25 steps (y %.2f at z %.1f)" % [player.global_position.y, player.global_position.z])


# --- Drop-offs: the hazard, the guard, the fall rule -----------------------------------------


func _hit(victim: CombatActor, reaction: CombatTypes.Reaction, knockback: Vector3, damage: float = 1.0) -> HitInfo:
	var hit := HitInfo.new()
	hit.victim = victim
	hit.damage = damage
	hit.reaction = reaction
	hit.knockback = knockback
	hit.direction = Vector3(knockback.x, 0.0, knockback.z).normalized()
	hit.contact_point = victim.global_position + Vector3.UP
	hit.tier = CombatTypes.HitTier.HEAVY
	return hit


## A real Punk of the level's spawner, standing at `at` and frozen (no AI, so only what a test does moves it).
func _punk(level: LevelRoot, at: Vector3) -> EnemyActor:
	Tuning.set_value(&"ai_frozen", true)
	var enemy := level.spawner.spawn_enemy(&"punk", at, 0.0)
	await _ticks(4)
	return enemy


func test_an_enemy_launched_over_the_edge_is_ko_d_on_entering_the_hazard() -> void:
	var level := await _level(SYNC_FRAMES, false)
	_put_player(level, _b(-3.0, 0.1, -3.0))
	var enemy := await _punk(level, _b(3.0, 0.0, -8.0))
	assert_gt(enemy.health, 0.0)
	enemy.receive_hit(_hit(enemy, CombatTypes.Reaction.LAUNCH, Vector3(14.0, 4.0, 0.0), 1.0))
	assert_true(enemy.is_flying(), "launched toward the edge")
	assert_eq(enemy.collision_mask & CombatTypes.bit(CombatTypes.LAYER_EDGE_GUARD), 0, "a flying enemy is no ghost the guard holds")
	await _ticks(90)
	assert_eq(_hits_ko, [enemy] as Array[Node3D], "hazard_ko fired once, for it")
	assert_lte(enemy.health, 0.0, "KO'd at once, not hurt")
	for i in 300:
		if enemy.is_ko():
			break
		await _ticks(1)
	assert_true(enemy.is_ko(), "it lands on the catch floor and lies KO'd")
	assert_gt(enemy.global_position.x, _b(5.5, 0.0, 0.0).x, "past the lip")
	assert_lt(enemy.global_position.y, _b(0.0, -4.0, 0.0).y, "far below the terrace, on the catch floor")


func test_a_standing_enemy_is_stopped_by_the_guard_and_never_reaches_the_hazard() -> void:
	var level := await _level(SYNC_FRAMES, false)
	_put_player(level, _b(-3.0, 0.1, -3.0))
	var enemy := await _punk(level, _b(4.6, 0.0, -8.0))
	assert_ne(enemy.collision_mask & CombatTypes.bit(CombatTypes.LAYER_EDGE_GUARD), 0, "a standing enemy's mask holds the guard")
	assert_true(enemy.test_move(enemy.global_transform, Vector3(3.0, 0.0, 0.0)), "it cannot walk out over the edge")
	assert_true(_hits_ko.is_empty())


func test_the_player_standing_and_launched_toward_the_guard_stays_on_the_floor() -> void:
	var level := await _level()
	var player := level.player
	_put_player(level, _b(4.0, 0.1, -8.0))
	await _ticks(6)
	assert_ne(player.collision_mask & CombatTypes.bit(CombatTypes.LAYER_EDGE_GUARD), 0, "standing")
	assert_true(player.test_move(player.global_transform, Vector3(3.0, 0.0, 0.0)), "he cannot walk off")
	player.receive_hit(_hit(player, CombatTypes.Reaction.LAUNCH, Vector3(14.0, 4.0, 0.0), 1.0))
	assert_true(player.is_flying())
	assert_ne(player.collision_mask & CombatTypes.bit(CombatTypes.LAYER_EDGE_GUARD), 0, "and as a ghost in flight")
	await _ticks(150)
	assert_lt(player.global_position.x, _b(5.5, 0.0, 0.0).x, "launched at the edge, he stays on the terrace (x %.2f)" % player.global_position.x)
	assert_gt(player.global_position.y, _b(0.0, -0.5, 0.0).y, "on the floor")
	assert_true(_hits_ko.is_empty())


func test_with_the_guard_off_a_fall_costs_the_damage_and_puts_the_player_back_at_the_respawn() -> void:
	Tuning.set_value(&"god_mode", false)
	Tuning.set_value(&"level_edge_guard", false)
	var level := await _level()
	var player := level.player
	level.start_at_arena(1)
	await _ticks(10)
	_put_player(level, _b(4.5, 0.1, -9.0))
	player.look_yaw = 0.0
	player.rotation.y = 0.0
	await _ticks(10)
	var before := player.health
	player.input.scripted = false
	Input.action_press(&"move_right")
	for i in 120:
		await _ticks(1)
		if player.health < before:
			break
	Input.action_release(&"move_right")
	player.input.scripted = true
	var respawn := level.arenas()[1].respawn_position()
	assert_almost_eq(player.health, before - Tuning.data.level_fall_damage, 0.01, "the fall cost level_fall_damage")
	assert_lt(_flat(player.global_position, respawn), 1.0, "back at the arena's Respawn marker")
	assert_true(player.is_invulnerable(), "and safe for a moment")
	await _ticks(roundi(Tuning.data.level_fall_invuln_s * 60.0) + 5)
	assert_false(player.is_invulnerable(), "for level_fall_invuln_s only")


func test_the_guard_is_in_the_navmesh_so_agents_stop_short_of_the_edge() -> void:
	var level := await _level()
	var near_lip := NavigationServer3D.map_get_closest_point(_map(level), _b(5.45, 0.0, -9.0))
	assert_gt(_b(5.5, 0.0, 0.0).x - near_lip.x, level.nav_agent_radius - 0.05,
			"the mesh stops %.2f m short of the lip (x %.2f), an agent radius at least" % [_b(5.5, 0.0, 0.0).x - near_lip.x, near_lip.x])


func test_the_edge_guard_tunable_switches_its_layer() -> void:
	var level := await _level()
	var guard := level.sections[1].edge_guards()[0]
	assert_eq(guard.body.collision_layer, CombatTypes.bit(CombatTypes.LAYER_EDGE_GUARD), "on layer 9 and no other")
	Tuning.set_value(&"level_edge_guard", false)
	assert_eq(guard.body.collision_layer, 0, "off: on no layer")
	Tuning.set_value(&"level_edge_guard", true)
	assert_eq(guard.body.collision_layer, CombatTypes.bit(CombatTypes.LAYER_EDGE_GUARD))
	assert_eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_9"), "edge_guard", "the layer is named")


func test_six_posturing_punks_near_the_edge_never_enter_the_hazard() -> void:
	Tuning.set_value(&"god_mode", false)
	var level := await _level(SYNC_FRAMES, false)
	var player := level.player
	var six := EncounterTable.new()
	six.loop = false
	six.waves.append(PackedStringArray(["punk", "punk", "punk", "punk", "punk", "punk"]))
	level.arenas()[1].table = six
	level.start_at_arena(1)
	_put_player(level, _b(3.4, 0.1, -9.0))
	player.look_yaw = -PI * 0.5  # facing the drop, the edge ahead of him, the Punks' ring past it
	player.rotation.y = player.look_yaw
	var probe := ReadabilityProbe.new()
	probe.print_summary = false
	probe.print_oracle_lines = false
	probe.lens_every = 0
	probe.occlusion_every = 0
	add_child_autofree(probe)
	probe.attach(level, player)
	probe.start_act("edge", {"passive": true})
	await _ticks(1260)
	var summary: Dictionary = probe.end_act()
	assert_eq(level.arenas()[1].state, Arena.State.LOCKED, "the arena locked and the six came in")
	assert_gte(level.enemies().size(), 6)
	assert_true(_hits_ko.is_empty(), "no Punk went over (%d KO'd by the hazard)" % _hits_ko.size())
	var metrics: Dictionary = summary.metrics
	assert_true(metrics.capsule_overlap_share == null
			or float(metrics.capsule_overlap_share) <= ReadabilityProbe.LIMITS.capsule_overlap_share_max,
			"R7: standing capsules overlapped no more than the probe's limit (%s)" % str(metrics.capsule_overlap_share))
	assert_eq(int(metrics.stuck_events), 0, "R13: nobody stuck for 3 s")
	for enemy in level.enemies():
		assert_lt(enemy.global_position.x, _b(5.5, 0.0, 0.0).x, "%s stayed on the terrace" % enemy.name)
