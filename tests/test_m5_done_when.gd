extends GutTest
## The Milestone 5 done-when, headless: Mission 1 (res://game/level/mission1/mission1.tscn, the street,
## the roofs and the boss roof chained by LevelRoot), played arena by arena through start_at_arena(k)
## with the autopilot in god mode and one_hit_ko, the waves quickened (wave_gap_s and
## wave_spawn_interval_s, restored by before_each / after_each).
##
## 1. Every arena locks, spawns exactly its table, never has more than six alive, clears and opens, in
##    level order, its ahead barrier shut all through the fight and its behind barrier too, with R1 (the attacker cap), R3 (no hit without its wind-up) and R10 (the warning
##    against the rule) hard throughout (the readability probe, one act per arena).
## 2. The boss arena: at half health (set by the test) the boss calls in his two Punks at A7's spawn
##    points, and the last arena's clear emits `level_cleared`.
## 3. The boss roof alone (a lone section): its fence gate behind is closed once the lock is on, the
##    boss comes in at the roof door, a Punk knocked over the open edge is KO'd.
## 4. No two sections' solid blocks overlap (plan §2 "Level space").
## 5. The level is the main scene and F6's first room.
##
## The assembled level is asserted whole, unconditionally: three sections (LevelRoot skips a section
## that is missing or does not load, with only a warning, so a broken one must fail here), 7 arenas,
## 34 enemies. Only the tests that load a lone section on purpose tolerate fewer. The seams are walked
## in tests/test_m5_seams.gd.

const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const BOSS_ROOF := "res://game/level/mission1/boss_roof.tscn"
const Probe := preload("res://tests/bot/readability_probe.gd")
const Pilot := preload("res://tests/bot/autopilot.gd")

## The most sim frames one arena may take from its lock to its clear (30 s).
const ARENA_BUDGET_FRAMES := 1800
## The wall-clock budget of the whole level run (ms).
const WALL_BUDGET_MS := 120000
## The arenas of Mission 1 and its enemies (encounters.md, "Totals").
const FULL_ARENAS := 7
const FULL_ENEMIES := 34
## At most this many alive at once (SPEC §9; the director's cap on the screen).
const MAX_ALIVE := 6
## Frames the lock may take to close on a player standing at an arena's first route point.
const LOCK_FRAMES := 30
## How near an add's first position is to one of A7's spawn points (m).
const AT_POINT_M := 2.5
## The seed.
const SEED := 5
## The most a section's blocks may overlap another's (a block face touching is fine: this is volume).
const OVERLAP_EPS_M := 0.05

var _level: LevelRoot
var _locked_order: Array[StringName] = []
var _cleared_order: Array[StringName] = []
var _level_cleared: int = 0


func before_each() -> void:
	_reset_tuning()
	_locked_order.clear()
	_cleared_order.clear()
	_level_cleared = 0
	CombatEvents.arena_locked.connect(_on_locked)
	CombatEvents.arena_cleared.connect(_on_cleared)
	CombatEvents.level_cleared.connect(_on_level_cleared)


func after_each() -> void:
	CombatEvents.arena_locked.disconnect(_on_locked)
	CombatEvents.arena_cleared.disconnect(_on_cleared)
	CombatEvents.level_cleared.disconnect(_on_level_cleared)
	_reset_tuning()


func after_all() -> void:
	OS.delay_msec(250)


func _reset_tuning() -> void:
	Tuning.reset_to_default()
	# The Debug toggles are not in the preset: put them back by hand.
	Tuning.set_value(&"ai_frozen", false)
	Tuning.set_value(&"director_even_spread", false)
	Tuning.set_value(&"god_mode", false)
	Tuning.set_value(&"one_hit_ko", false)
	Tuning.set_value(&"waves_enabled", false)
	TimeController.clear()
	GameInput.menu_open = false


func _on_locked(arena: Node3D) -> void:
	_locked_order.append((arena as Arena).arena_id)


func _on_cleared(arena: Node3D) -> void:
	_cleared_order.append((arena as Arena).arena_id)


func _on_level_cleared(_level_node: Node3D) -> void:
	_level_cleared += 1


## A LevelRoot over `sections` (the whole of Mission 1 when empty), no presentation, seeded.
func _level_up(sections: PackedStringArray = PackedStringArray()) -> LevelRoot:
	var root: LevelRoot
	if sections.is_empty():
		root = (load(LEVEL_PATH) as PackedScene).instantiate() as LevelRoot
	else:
		root = LevelRoot.new()
		root.section_paths = sections
	root.with_presentation = false
	root.waves_enabled_on_start = false
	root.rng_seed = SEED
	add_child_autofree(root)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_level = root
	return root


func _quicken() -> void:
	Tuning.set_value(&"god_mode", true)
	Tuning.set_value(&"one_hit_ko", true)
	Tuning.set_value(&"wave_gap_s", 1.0)
	Tuning.set_value(&"wave_spawn_interval_s", 0.2)
	Tuning.set_value(&"waves_enabled", true)


## The hard rows of `rows`: none FAIL.
func _assert_hard_rows(rows: Array[Dictionary], what: String) -> void:
	for row in rows:
		if row.hard:
			assert_ne(row.status, "FAIL", "%s: %s %s: %s (needs %s)" % [what, row.id, row.name, row.value, row.limit])
	assert_true(Probe.hard_ok(rows), "%s: no hard readability metric fails" % what)


## The expected enemy count of an arena's table (every wave; the boss arena's adds are on top).
func _table_size(arena: Arena) -> int:
	var total := 0
	for wave in arena.table.waves:
		total += wave.size()
	return total


## Play `arena` (the level already stands at it): the autopilot fights from the lock to the clear.
## `on_tick` is called each frame with the stats. Returns {locked, cleared, frames, ids (distinct
## enemies seen), peak, first_seen (id -> position), verdict}.
func _play(arena: Arena, on_tick: Callable = Callable()) -> Dictionary:
	var player := _level.player
	var probe := Probe.new()
	probe.print_summary = false
	probe.print_oracle_lines = false
	probe.attach(_level, player)
	var pilot := Pilot.new()
	pilot.enemy_group = &"ai_enemy"
	pilot.approach_max_m = 40.0
	pilot.attach(_level, player)
	var seen: Dictionary[int, Vector3] = {}
	var archetypes: Dictionary[int, StringName] = {}
	var peak := 0
	var locked := false
	var behind_closed := true
	var ahead_closed := true
	for i in LOCK_FRAMES:
		await get_tree().physics_frame
		if arena.state != Arena.State.WAITING:
			locked = true
			break
	probe.start_act(String(arena.arena_id))
	var start := Engine.get_physics_frames()
	while arena.state == Arena.State.LOCKED and Engine.get_physics_frames() - start < ARENA_BUDGET_FRAMES:
		await get_tree().physics_frame
		for enemy in _level.enemies():
			if not seen.has(enemy.get_instance_id()):
				seen[enemy.get_instance_id()] = enemy.global_position
				archetypes[enemy.get_instance_id()] = enemy.archetype
		peak = maxi(peak, _level.spawner.alive_count())
		if arena.behind and arena.state == Arena.State.LOCKED and not arena.behind.is_closed():
			behind_closed = false
		if arena.ahead and arena.state == Arena.State.LOCKED and not arena.ahead.is_closed():
			ahead_closed = false
		if on_tick.is_valid():
			on_tick.call(seen)
	var frames := Engine.get_physics_frames() - start
	pilot.stop()
	var summary := probe.end_act()
	pilot.queue_free()
	probe.queue_free()
	return {locked = locked, cleared = arena.state == Arena.State.CLEARED, frames = frames, ids = seen.size(),
			peak = peak, behind_closed = behind_closed, ahead_closed = ahead_closed, first_seen = seen, archetypes = archetypes, verdict = summary.verdict}


## The player walks into `arena` from where he stands: when he is not where it locks on him he is
## put at its first route point, which must lock it (inside its volume and past its behind barrier's
## inset). Only the street's Start is outside the first arena; the bot run walks that in for real.
func _walk_into(arena: Arena) -> void:
	var player := _level.player
	if arena.contains(player.global_position) and arena.past_inset(player.global_position):
		return
	var point := _level.first_route_point(arena)
	assert_true(point.is_finite(), "%s has a route point" % arena.arena_id)
	if point.is_finite():
		assert_true(arena.past_inset(point), "%s: its first route point is far enough past its behind barrier to lock" % arena.arena_id)
		player.global_position = point


# --- 1 and 2. The level, arena by arena ----------------------------------------------------------


func test_every_arena_locks_spawns_its_table_and_clears_in_order() -> void:
	var wall_start := Time.get_ticks_msec()
	await _level_up()
	_quicken()
	# start_at_arena(k) stands the player at arena k's first route point, where it locks on him (the
	# first arena's start is the street end, so the test puts him at its first route point: the bot
	# run walks that in for real).
	_locked_order.clear()
	assert_eq(_level.sections.size(), 3, "mission1.tscn built all three sections (street, roofs, boss roof): none skipped")
	var arenas := _level.arenas()
	assert_eq(arenas.size(), FULL_ARENAS, "the level has %d arenas" % FULL_ARENAS)
	var spawned_total := 0
	var boss_arena := arenas.size() - 1
	var expected_order: Array[StringName] = []
	for k in arenas.size():
		var arena := arenas[k]
		expected_order.append(arena.arena_id)
		_level.start_at_arena(k)
		_walk_into(arena)
		_level.spawner.set_waves_enabled(true)
		var is_boss := arena.table != null and arena.table.waves.size() == 1 and arena.table.waves[0] == PackedStringArray(["boss"])
		var half := func(seen: Dictionary) -> void:
			# The boss at half health, as soon as he stands in the arena (phase 2 reads health every tick).
			for enemy in _level.enemies():
				if enemy is Boss and enemy.health > enemy.max_health * 0.5 and enemy.health > 0.0:
					enemy.health = enemy.max_health * 0.5
		var stats: Dictionary = await _play(arena, half if is_boss else Callable())
		var tag := "%s (arena %d)" % [arena.arena_id, k]
		assert_true(stats.locked, "%s locked on a player at its first route point" % tag)
		assert_true(stats.cleared, "%s cleared inside %d frames (took %d)" % [tag, ARENA_BUDGET_FRAMES, stats.frames])
		assert_lte(int(stats.peak), MAX_ALIVE, "%s: never over %d alive (peak %d)" % [tag, MAX_ALIVE, stats.peak])
		var expected := _table_size(arena) + (Tuning.data.boss_adds_count if is_boss else 0)
		assert_eq(int(stats.ids), expected, "%s spawned exactly its table (and the boss's adds)" % tag)
		spawned_total += int(stats.ids)
		if arena.ahead:
			assert_true(stats.ahead_closed, "%s: its ahead barrier was closed all through the fight" % tag)
			assert_false(arena.ahead.is_closed(), "%s: its ahead barrier opened on the clear" % tag)
		if arena.behind:
			assert_true(stats.behind_closed, "%s: its behind barrier was closed all through the fight" % tag)
		_assert_hard_rows(stats.verdict, tag)
		if is_boss:
			assert_eq(k, boss_arena, "the boss arena is the last")
			var boss_seen := 0
			for id in stats.archetypes:
				if stats.archetypes[id] == &"boss":
					boss_seen += 1
			assert_eq(boss_seen, 1, "one boss")
			var punks := 0
			for id in stats.archetypes:
				if stats.archetypes[id] == &"punk":
					punks += 1
					var near := INF
					for point in arena.spawn_point_list():
						near = minf(near, (stats.first_seen[id] - point.position).length())
					assert_lt(near, AT_POINT_M, "an add first stood at one of A7's spawn points (%.1f m)" % near)
			assert_eq(punks, Tuning.data.boss_adds_count, "his adds came: %d Punks" % punks)
	assert_eq(_locked_order, expected_order, "the arenas locked in level order")
	assert_eq(_cleared_order, expected_order, "and cleared in level order")
	assert_eq(_level_cleared, 1, "the last clear emitted level_cleared once")
	assert_eq(spawned_total, FULL_ENEMIES, "the whole level spawns %d enemies" % FULL_ENEMIES)
	var wall_ms := Time.get_ticks_msec() - wall_start
	gut.p("mission 1: %d arenas, %d enemies, %d ms wall" % [arenas.size(), spawned_total, wall_ms])
	assert_lt(wall_ms, WALL_BUDGET_MS, "the level run took %d ms (budget %d)" % [wall_ms, WALL_BUDGET_MS])


# --- 3. The boss roof alone -----------------------------------------------------------------------


func test_the_boss_roof_is_one_section_with_the_boss_arena() -> void:
	await _level_up(PackedStringArray([BOSS_ROOF]))
	assert_eq(_level.sections.size(), 1, "one section")
	var arenas := _level.arenas()
	assert_eq(arenas.size(), 1, "one arena")
	var arena := arenas[0]
	assert_eq(arena.arena_id, &"a7")
	assert_eq(arena.table.waves.size(), 1, "one wave")
	assert_eq(arena.table.waves[0], PackedStringArray(["boss"]), "the boss")
	assert_false(arena.table.loop, "a finite table")
	assert_eq(arena.table.wave_points[0][0], "RoofDoor", "he enters by the roof door")
	var names: Array[String] = []
	for point in arena.spawn_points():
		names.append(String(point.name))
		assert_true(arena.contains(point.global_position), "%s is inside the arena" % point.name)
		assert_true(arena.contains(point.lane_point().global_position), "%s's lane point is inside the arena" % point.name)
	names.sort()
	assert_eq(names, ["GateDoor", "RoofDoor", "ServiceDoor"] as Array[String], "the roof door, a service door and a door by the gate")
	assert_eq(_level.sections[0].floor_heights, PackedFloat32Array([0.0]), "one floor")
	assert_eq(_level.sections[0].barriers().size(), 0, "no barrier of its own: the gate behind is the roofs' ExitBarrier")


func test_the_boss_comes_in_at_the_roof_door_and_the_roof_is_one_island() -> void:
	await _level_up(PackedStringArray([BOSS_ROOF]))
	_quicken()
	_locked_order.clear()
	var arena := _level.arenas()[0]
	_level.start_at_arena(0)
	_level.spawner.set_waves_enabled(true)
	var door := arena.get_node("RoofDoor") as Node3D
	var first := {at = Vector3.INF}
	var on_tick := func(_seen: Dictionary) -> void:
		for enemy in _level.enemies():
			if enemy is Boss and not first.at.is_finite():
				first.at = enemy.global_position
	var stats: Dictionary = await _play(arena, on_tick)
	assert_true(stats.locked and stats.cleared, "locked and cleared")
	assert_lt((first.at - door.global_position).length(), AT_POINT_M, "the boss first stood at the roof door")


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


## A point of the boss roof's own space, in level space.
func _roof(x: float, y: float, z: float) -> Vector3:
	return _level.sections[0].global_position + Vector3(x, y, z)


func test_a_punk_launched_over_the_open_edge_is_ko_d() -> void:
	await _level_up(PackedStringArray([BOSS_ROOF]))
	_level.player.input.scripted = true
	_level.player.global_position = _roof(-6.0, 0.1, -3.0)
	Tuning.set_value(&"ai_frozen", true)
	var enemy := _level.spawner.spawn_enemy(&"punk", _roof(4.0, 0.0, -10.0), 0.0)
	for i in 4:
		await get_tree().physics_frame
	var kos: Array[Node3D] = []
	var hear := func(actor: Node3D, _h: Node3D) -> void:
		kos.append(actor)
	CombatEvents.hazard_ko.connect(hear)
	enemy.receive_hit(_hit(enemy, Vector3(14.0, 4.0, 0.0)))
	for i in 120:
		await get_tree().physics_frame
	CombatEvents.hazard_ko.disconnect(hear)
	assert_eq(kos, [enemy] as Array[Node3D], "the hazard KO'd it, once")
	assert_lte(enemy.health, 0.0, "KO'd at once")
	assert_true(enemy.is_ko(), "and it lies KO'd")


## The player walks right at the open edge from `z` (the rail, or its gap): he stays on the roof.
func _walk_at_the_edge(z: float) -> void:
	await _level_up(PackedStringArray([BOSS_ROOF]))
	var player := _level.player
	player.input.scripted = false
	player.global_position = _roof(6.0, 0.1, z)
	player.velocity = Vector3.ZERO
	player.look_yaw = 0.0
	player.rotation.y = 0.0
	Input.action_press(&"move_right")
	for i in 150:
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	player.input.scripted = true
	assert_lt(player.global_position.x, _roof(10.0, 0.0, 0.0).x, "stopped short of the lip (z %.1f)" % z)
	assert_gt(player.global_position.y, _roof(0.0, -0.5, 0.0).y, "still on the roof")
	assert_gt(player.global_position.x, _roof(8.0, 0.0, 0.0).x, "and he did walk to the edge")


func test_the_edge_guard_holds_the_player_at_the_rail() -> void:
	await _walk_at_the_edge(-3.0)


func test_the_edge_guard_holds_the_player_at_the_gap_in_the_rail() -> void:
	await _walk_at_the_edge(-10.5)


# --- 4. The sections do not overlap ------------------------------------------------------------


func test_no_two_sections_solid_blocks_overlap() -> void:
	await _level_up()
	var sections := _level.sections
	var boxes: Array[Array] = []
	for section in sections:
		var list: Array[AABB] = []
		for block in section.blocks():
			if block.solid and not (block is EdgeGuard):
				list.append(block.world_aabb())
		boxes.append(list)
	var overlaps := 0
	for a in sections.size():
		for b in range(a + 1, sections.size()):
			for first in boxes[a]:
				var shrunk: AABB = (first as AABB).grow(-OVERLAP_EPS_M)
				for second in boxes[b]:
					if shrunk.intersects((second as AABB).grow(-OVERLAP_EPS_M)):
						overlaps += 1
						gut.p("overlap: section %d %s with section %d %s" % [a, first, b, second])
	assert_eq(overlaps, 0, "no two sections' solid blocks overlap")


# --- 5. The main scene and F6 ------------------------------------------------------------------


func test_the_level_is_the_main_scene_and_f6_starts_there() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), LEVEL_PATH, "the main scene")
	assert_eq(GameInput.ROOM_SCENES[0], LEVEL_PATH, "F6's first room")
	assert_eq(GameInput.ROOM_SCENES.size(), 3, "level, crowd room, training room")
	assert_true(ResourceLoader.exists(LEVEL_PATH), "mission1.tscn exists")
