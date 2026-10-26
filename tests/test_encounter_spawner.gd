extends GutTest
## The encounter spawner (M3-plan P1-room): naming and placing, the wave table, the cap, the
## spawn point choice (behind share, minimum distance, room), menus holding the waves, adds. It
## runs against the probe enemy (tests/fixtures/spawn_probe_enemy: a stub that stands still and
## records enter_from()), through `scene_override`, so the real archetypes never change it.

const PROBE := preload("res://tests/fixtures/spawn_probe_enemy.tscn")
const TRAINING_DUMMY := preload("res://game/enemies/dummy/training_dummy.tscn")

var _scene: Node3D
var _player: PlayerCharacter


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.set_value(&"waves_enabled", false)
	Tuning.set_value(&"wave_gap_s", 0.1)
	Tuning.set_value(&"wave_spawn_interval_s", 0.05)
	Tuning.set_value(&"boss_wave_every", 100)
	TimeController.clear()
	TimeController.debug_scale = 1.0
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = false
	_scene = Node3D.new()
	add_child_autofree(_scene)
	RoomKit.add_box(_scene, Vector3(0.0, -0.5, 0.0), Vector3(80.0, 1.0, 80.0), null)
	_player = RoomKit.spawn_player(_scene, Vector3.ZERO, 0.0)  # facing -Z
	_player.input.scripted = true


func after_each() -> void:
	PlaceholderAnims.warn_on_fallback = true
	GameInput.menu_open = false
	Tuning.reset_to_default()
	TimeController.clear()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## A spawner in the scene with the probe standing in for the punk, the given waves (each an
## Array of ids) and `points`, waves off (turn them on with set_waves_enabled(true)).
func _spawner(waves: Array = [], points: Array[Dictionary] = []) -> EncounterSpawner:
	var spawner := EncounterSpawner.new()
	spawner.scene_override = {&"punk": PROBE}
	var table := EncounterTable.new()
	for wave: Array in waves:
		table.waves.append(PackedStringArray(wave))
	spawner.table = table
	spawner.rng_seed = 7
	spawner.spawn_points = points if not points.is_empty() else _grid_points()
	_scene.add_child(spawner)
	return spawner


## Eighteen points 10 m from the player: nine in front (z -10, in view) and nine behind (z +10).
func _grid_points() -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	for z: float in [-10.0, 10.0]:
		for i in 9:
			var x := -8.0 + float(i) * 2.0
			points.append({position = Vector3(x, 0.0, z), yaw = 0.0, tag = &"doorway", lane_point = Vector3(x, 0.0, z * 0.5)})
	return points


func _enemies() -> Array[EnemyActor]:
	var out: Array[EnemyActor] = []
	for node: Node in get_tree().get_nodes_in_group(&"ai_enemy"):
		out.append(node as EnemyActor)
	return out


# --- Spawning ---------------------------------------------------------------------------


func test_spawn_enemy_names_places_and_sends_it_in() -> void:
	var spawner := _spawner()
	var first := spawner.spawn_enemy(&"punk", Vector3(3.0, 0.0, 2.0), 1.0, false, Vector3(1.0, 0.0, 1.0)) as Node3D
	var second := spawner.spawn_enemy(&"punk", Vector3(-3.0, 0.0, 2.0), 0.0)
	await _ticks(2)
	assert_not_null(first, "spawned")
	assert_eq(first.name, &"Punk1", "named <Archetype><n>")
	assert_eq((first as CombatActor).display_name, "Punk 1")
	assert_eq(second.name, &"Punk2", "the count goes on")
	assert_eq(second.display_name, "Punk 2")
	assert_eq(first.get_parent(), _scene, "added to the room")
	assert_almost_eq(first.global_position.x, 3.0, 0.05, "where it was put")
	assert_almost_eq(first.rotation.y, 1.0, 0.001, "facing the yaw it was given")
	for group: StringName in [&"ai_enemy", &"enemy", &"actor"]:
		assert_true(first.is_in_group(group), "in group %s" % group)
	assert_eq(first.entered_from, Vector3(3.0, 0.0, 2.0), "told where it came from")
	assert_eq(first.entered_lane, Vector3(1.0, 0.0, 1.0), "and where to walk first")
	assert_eq(second.entered_lane, Vector3(-3.0, 0.0, 2.0), "with no lane point it is already there")
	assert_eq(second.enter_calls, 1)


func test_spawn_enemy_refuses_what_it_cannot_make() -> void:
	var spawner := _spawner()
	assert_null(spawner.spawn_enemy(&"no_such_enemy", Vector3(3.0, 0.0, 2.0), 0.0), "no scene, no enemy")
	spawner.scene_override = {&"dummy": TRAINING_DUMMY}
	assert_null(spawner.spawn_enemy(&"dummy", Vector3(3.0, 0.0, 2.0), 0.0), "the training dummy is not an EnemyActor")
	assert_null(EncounterSpawner.make_enemy(TRAINING_DUMMY, &"dummy", {}), "make_enemy says so too")
	assert_eq(_enemies().size(), 0)


func test_alive_count_counts_the_living() -> void:
	var spawner := _spawner()
	var a := spawner.spawn_enemy(&"punk", Vector3(3.0, 0.0, 2.0), 0.0)
	spawner.spawn_enemy(&"punk", Vector3(-3.0, 0.0, 2.0), 0.0)
	await _ticks(2)
	assert_eq(spawner.alive_count(), 2)
	a.health = 0.0
	assert_eq(spawner.alive_count(), 1, "health 0 is dead")


func test_remove_enemies_clears_the_groups_at_once() -> void:
	var spawner := _spawner()
	var a := spawner.spawn_enemy(&"punk", Vector3(3.0, 0.0, 2.0), 0.0)
	var dummy := TRAINING_DUMMY.instantiate() as TrainingDummy
	dummy.position = Vector3(-3.0, 0.0, 2.0)
	_scene.add_child(dummy)
	await _ticks(2)
	assert_eq(EncounterSpawner.remove_enemies(get_tree(), true), 1, "AI enemies only")
	assert_false(a.is_in_group(&"ai_enemy"))
	assert_false(a.is_in_group(&"enemy"))
	assert_false(a.is_in_group(&"actor"))
	assert_eq(get_tree().get_nodes_in_group(&"ai_enemy").size(), 0, "no member in the same frame")
	assert_true(dummy.is_in_group(&"enemy"), "the dummy stays")
	assert_eq(EncounterSpawner.remove_enemies(get_tree(), false), 1, "now the dummies too")
	await _ticks(1)
	assert_false(is_instance_valid(a))
	assert_false(is_instance_valid(dummy))


# --- The table ----------------------------------------------------------------------------


func test_the_shipped_table_is_the_plans() -> void:
	var table := load(EncounterSpawner.TABLE_PATH) as EncounterTable
	assert_not_null(table, "crowd_waves.tres loads")
	assert_eq(table.waves.size(), 5)
	assert_eq(table.waves[0], PackedStringArray(["punk", "punk"]))
	assert_eq(table.waves[1].size(), 4)
	assert_eq(table.waves[2], PackedStringArray(["punk", "kicker", "punk", "thug", "punk", "punk"]))
	assert_eq(table.waves[3], PackedStringArray(["bruiser", "punk", "kicker", "punk"]))
	assert_eq(table.waves[4], PackedStringArray(["thug", "kicker", "punk", "punk", "kicker", "punk"]))
	assert_eq(table.boss_wave, PackedStringArray(["boss"]))
	for wave in table.waves:
		assert_lte(wave.size(), 6, "no wave is bigger than the cap")


func test_a_boss_wave_comes_after_every_boss_every_waves() -> void:
	var table := EncounterTable.new()
	for ids: Array in [["a"], ["b"], ["c"]]:
		table.waves.append(PackedStringArray(ids))
	var order := PackedStringArray()
	for i in 10:
		order.append(table.wave_at(i, 2)[0])
	assert_eq(order, PackedStringArray(["a", "b", "boss", "c", "a", "boss", "b", "c", "boss", "a"]), "two waves, then the boss")
	assert_eq(table.wave_at(5, 0), PackedStringArray(["c"]), "0 = no boss: the plain table, wrapping")
	assert_eq(EncounterTable.new().wave_at(3, 2).size(), 0, "no waves, no wave")


func test_unknown_ids_are_replaced_by_the_punk() -> void:
	var spawner := _spawner([["no_such_a", "no_such_b"]])
	assert_eq(spawner.resolve_id(&"no_such_a"), &"punk")
	assert_eq(spawner.resolve_id(&"punk"), &"punk")
	spawner.set_waves_enabled(true)
	await _ticks(60)
	var made := _enemies()
	assert_eq(made.size(), 2, "both spawned")
	for enemy in made:
		assert_true(String(enemy.name).begins_with("Punk"), "as punks: %s" % enemy.name)


# --- Waves --------------------------------------------------------------------------------


func test_a_wave_waits_for_its_clear_and_the_table_repeats() -> void:
	var spawner := _spawner([["punk", "punk"], ["punk", "punk", "punk"]])
	var started: Array[int] = []
	spawner.wave_started.connect(func(number: int, _ids: PackedStringArray) -> void: started.append(number))
	var cleared: Array[int] = []
	spawner.wave_cleared.connect(func(number: int) -> void: cleared.append(number))
	spawner.set_waves_enabled(true)
	await _ticks(2)
	assert_eq(_enemies().size(), 0, "the first wave waits wave_gap_s")
	await _ticks(40)
	assert_eq(spawner.waves_started(), 1)
	assert_eq(_enemies().size(), 2, "wave 1 is two punks")
	await _ticks(90)
	assert_eq(spawner.waves_started(), 1, "wave 2 waits for the clear")
	assert_eq(_enemies().size(), 2)
	EncounterSpawner.remove_enemies(get_tree(), true)
	await _ticks(60)
	assert_eq(spawner.waves_started(), 2)
	assert_eq(_enemies().size(), 3, "wave 2 is three")
	EncounterSpawner.remove_enemies(get_tree(), true)
	await _ticks(60)
	assert_eq(spawner.waves_started(), 3, "and the table starts over")
	assert_eq(_enemies().size(), 2, "with wave 1 again")
	assert_eq(started, [1, 2, 3] as Array[int])
	assert_eq(cleared, [1, 2] as Array[int])


func test_a_dead_wave_is_cleared_at_health_zero() -> void:
	var spawner := _spawner([["punk", "punk"]])
	spawner.set_waves_enabled(true)
	await _ticks(40)
	for enemy in _enemies():
		enemy.health = 0.0
	await _ticks(40)
	assert_eq(spawner.waves_started(), 2, "KO'd bodies still lying there do not hold the next wave")


func test_never_more_than_wave_max_alive() -> void:
	Tuning.set_value(&"wave_max_alive", 3)
	Tuning.set_value(&"wave_gap_s", 0.0)
	var spawner := _spawner([["punk", "punk", "punk", "punk", "punk", "punk"]])
	spawner.set_waves_enabled(true)
	var peak := 0
	for i in 90:
		await _ticks(1)
		peak = maxi(peak, spawner.alive_count())
	assert_eq(peak, 3, "the cap holds the wave back")
	var victim := _enemies()[0]
	victim.health = 0.0
	await _ticks(20)
	assert_eq(spawner.alive_count(), 3, "a fall lets the next one in")
	assert_eq(_enemies().size(), 4, "one body down, three alive")


func test_other_spawns_count_toward_the_cap_but_are_not_held_by_it() -> void:
	Tuning.set_value(&"wave_max_alive", 2)
	Tuning.set_value(&"wave_gap_s", 0.0)
	var spawner := _spawner([["punk", "punk"]])
	for i in 3:
		assert_not_null(spawner.spawn_enemy(&"punk", Vector3(-4.0 + float(i) * 4.0, 0.0, 3.0), 0.0), "F4 spawns past the cap")
	spawner.set_waves_enabled(true)
	await _ticks(60)
	assert_eq(_enemies().size(), 3, "three alive already: the wave waits")
	assert_eq(spawner.waves_started(), 1)
	_enemies()[0].health = 0.0
	_enemies()[1].health = 0.0
	await _ticks(30)
	assert_eq(_enemies().size(), 4, "below the cap again: one wave enemy comes")


func test_waves_hold_while_a_menu_is_open() -> void:
	Tuning.set_value(&"wave_gap_s", 0.5)
	var spawner := _spawner([["punk", "punk"]])
	spawner.set_waves_enabled(true)
	GameInput.menu_open = true
	await _ticks(100)
	assert_eq(_enemies().size(), 0, "nothing spawns behind an open menu")
	assert_eq(spawner.waves_started(), 0)
	GameInput.menu_open = false
	await _ticks(15)
	assert_eq(spawner.waves_started(), 0, "the gap did not run while it was open: the wave still waits")
	await _ticks(30)
	assert_eq(spawner.waves_started(), 1, "then the wave starts")


func test_waves_off_start_nothing_and_resume_where_they_were() -> void:
	var spawner := _spawner([["punk", "punk"]])
	await _ticks(60)
	assert_eq(_enemies().size(), 0, "waves are off")
	assert_false(Tuning.data.waves_enabled)
	spawner.set_waves_enabled(true)
	assert_true(Tuning.data.waves_enabled, "the same switch as the F1 panel's")
	await _ticks(40)
	assert_eq(_enemies().size(), 2)


# --- Where waves spawn --------------------------------------------------------------------


func test_a_wave_spawns_its_share_from_outside_the_view() -> void:
	Tuning.set_value(&"wave_behind_share", 0.5)
	Tuning.set_value(&"wave_gap_s", 0.0)
	var wave: Array = ["punk", "punk", "punk", "punk", "punk", "punk"]
	var spawner := _spawner([wave, wave, wave])
	spawner.set_waves_enabled(true)
	for round in 3:
		await _ticks(60)
		var behind := 0
		var all := _enemies()
		assert_eq(all.size(), 6, "wave %d is six" % (round + 1))
		for enemy in all:
			if _player.is_outside_view(enemy.global_position, Tuning.data.rear_warning_angle_deg):
				behind += 1
		assert_eq(behind, 3, "wave %d: half of six from outside the view" % (round + 1))
		EncounterSpawner.remove_enemies(get_tree(), true)
		await _ticks(2)


func test_the_default_share_is_about_a_third() -> void:
	Tuning.set_value(&"wave_gap_s", 0.0)
	var wave: Array = ["punk", "punk", "punk", "punk", "punk", "punk"]
	var spawner := _spawner([wave, wave, wave, wave])
	spawner.set_waves_enabled(true)
	var behind := 0
	var total := 0
	for round in 4:
		await _ticks(60)
		for enemy in _enemies():
			total += 1
			if _player.is_outside_view(enemy.global_position, Tuning.data.rear_warning_angle_deg):
				behind += 1
		EncounterSpawner.remove_enemies(get_tree(), true)
		await _ticks(2)
	assert_eq(total, 24)
	assert_eq(behind, 8, "round(6 x 0.35) = 2 of every six")


func test_the_same_seed_picks_the_same_points() -> void:
	var picks: Array[PackedVector3Array] = []
	for run in 2:
		EncounterSpawner.remove_enemies(get_tree(), true)
		await _ticks(2)
		var spawner := _spawner([["punk", "punk", "punk", "punk"]])
		spawner.set_waves_enabled(true)
		await _ticks(60)
		var spots := PackedVector3Array()
		for enemy in _enemies():
			spots.append(enemy.global_position)
		picks.append(spots)
		spawner.queue_free()
		await _ticks(2)
	assert_eq(picks[0].size(), 4)
	assert_eq(picks[0], picks[1], "seeded")


func test_points_near_the_player_or_with_a_body_on_them_are_skipped() -> void:
	var points: Array[Dictionary] = [
		{position = Vector3(2.0, 0.0, 0.0), yaw = 0.0, tag = &"doorway", lane_point = Vector3.ZERO},
		{position = Vector3(8.0, 0.0, 0.0), yaw = 0.0, tag = &"doorway", lane_point = Vector3.ZERO},
		{position = Vector3(-8.0, 0.0, 0.0), yaw = 0.0, tag = &"alley", lane_point = Vector3.ZERO},
	]
	var spawner := _spawner([], points)
	var body := EnemyCatalog.body_size(&"punk")
	await _ticks(2)
	assert_eq(spawner.valid_point_indices(body), [1, 2] as Array[int], "2 m is inside spawn_min_player_distance_m")
	spawner.spawn_enemy(&"punk", Vector3(8.0, 0.0, 0.0), 0.0)
	await _ticks(3)
	assert_eq(spawner.valid_point_indices(body), [2] as Array[int], "a body standing on a point blocks it")
	assert_true(spawner.is_behind(points[1]), "east of a player facing -Z is 90 degrees off: outside the 55 degree view")
	assert_false(spawner.is_behind({position = Vector3(0.0, 0.0, -8.0)}), "dead ahead is in view")
	Tuning.set_value(&"spawn_min_player_distance_m", 1.0)
	assert_eq(spawner.valid_point_indices(body), [0, 2] as Array[int], "the minimum distance is live")


func test_a_wave_with_nowhere_to_spawn_waits() -> void:
	var points: Array[Dictionary] = [
		{position = Vector3(1.0, 0.0, 0.0), yaw = 0.0, tag = &"doorway", lane_point = Vector3.ZERO},
	]
	var spawner := _spawner([["punk", "punk"]], points)
	spawner.set_waves_enabled(true)
	await _ticks(60)
	assert_eq(_enemies().size(), 0, "the one point is too close to the player")
	_player.global_position = Vector3(0.0, 0.0, 12.0)
	await _ticks(40)
	assert_eq(_enemies().size(), 1, "then one comes, and the point is blocked for the other")


func test_the_sim_clock_slows_the_waves() -> void:
	Tuning.set_value(&"wave_gap_s", 0.5)
	var spawner := _spawner([["punk", "punk"]])
	spawner.set_waves_enabled(true)
	TimeController.debug_scale = 0.25
	await _ticks(60)
	assert_eq(spawner.waves_started(), 0, "half a second of gap takes two seconds at 0.25x")
	TimeController.debug_scale = 1.0
	await _ticks(40)
	assert_eq(spawner.waves_started(), 1)


# --- Adds ---------------------------------------------------------------------------------


func test_adds_come_in_at_the_nearest_free_points_and_join_the_wave() -> void:
	var points: Array[Dictionary] = []
	for i in 4:
		points.append({position = Vector3(-9.0 + float(i) * 6.0, 0.0, -10.0), yaw = 0.0, tag = &"doorway", lane_point = Vector3.ZERO})
	var spawner := _spawner([["punk"]], points)
	await _ticks(2)
	var adds := spawner.spawn_adds(&"punk", 2, Vector3(9.0, 0.0, -10.0))
	await _ticks(2)
	assert_eq(adds.size(), 2)
	assert_almost_eq(adds[0].global_position.x, 9.0, 0.05, "the nearest point first")
	assert_almost_eq(adds[1].global_position.x, 3.0, 0.05, "then the next nearest")
	assert_ne(adds[0].global_position, adds[1].global_position, "never two at one point")
	assert_eq(spawner.spawn_adds(&"punk", 9, Vector3(9.0, 0.0, -10.0)).size(), 2, "only the two free points are left")
