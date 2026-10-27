extends GutTest
## The F4 cheat menu's enemy cheats (M3-plan P1-room): spawn any enemy of the catalog at the
## crosshair, in the crowd room (through its spawner) and in the training room (no spawner, no
## navmesh), remove every enemy, waves on or off, freeze AI. The AI enemy here is the probe stub
## (tests/fixtures/spawn_probe_enemy), put in place of the Punk through `scene_override`, so the
## real archetypes never change the test.

const PROBE := preload("res://tests/fixtures/spawn_probe_enemy.tscn")
const CROWD_PATH := "res://game/level/crowd_room.tscn"
const TRAINING_PATH := "res://game/level/test_room.tscn"


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.set_value(&"waves_enabled", false)
	Tuning.set_value(&"god_mode", false)
	TimeController.clear()
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = false


func after_each() -> void:
	PlaceholderAnims.warn_on_fallback = true
	GameInput.menu_open = false
	Tuning.reset_to_default()
	Tuning.set_value(&"god_mode", false)
	TimeController.clear()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _crowd() -> CrowdRoom:
	var room := (load(CROWD_PATH) as PackedScene).instantiate() as CrowdRoom
	room.with_presentation = false
	room.waves_enabled_on_start = false
	add_child_autofree(room)
	await _ticks(5)
	room.player.input.scripted = true
	return room


func _training() -> Node3D:
	var room := (load(TRAINING_PATH) as PackedScene).instantiate() as Node3D
	room.set(&"with_presentation", false)
	add_child_autofree(room)
	await _ticks(2)
	var player: PlayerCharacter = room.get(&"player")
	player.input.scripted = true
	var dummies: Array[TrainingDummy] = []
	dummies.assign(room.get(&"dummies"))
	for i in dummies.size():
		dummies[i].sparring = false
		dummies[i].set_post(Vector3(30.0 + float(i) * 3.0, 0.0, -30.0), 0.0, true)
	await _ticks(2)
	return room


func _menu(room: Node3D) -> CheatMenu:
	var menu := CheatMenu.new()
	menu.world = room
	add_child_autofree(menu)
	return menu


# --- The list and the dummy ---------------------------------------------------------------


func test_the_list_offers_every_available_enemy() -> void:
	var menu := _menu(await _training())
	var available := EnemyCatalog.available()
	assert_eq(menu.enemy_option.item_count, available.size(), "one item per available enemy")
	for i in available.size():
		assert_eq(menu.enemy_option.get_item_text(i), available[i].label)
		assert_eq(StringName(menu.enemy_option.get_item_metadata(i)), available[i].id)
	assert_eq(StringName(menu.enemy_option.get_item_metadata(0)), &"dummy", "the training dummy first, as before")


func test_the_default_pick_still_spawns_a_training_dummy() -> void:
	var room := await _training()
	var menu := _menu(room)
	var actor := menu.spawn_selected()
	assert_true(actor is TrainingDummy, "the first item is the dummy")
	assert_eq(menu.spawned, [actor] as Array[CombatActor])
	assert_true(menu.spawn_dummy() is TrainingDummy, "spawn_dummy() still returns one")
	assert_eq(menu.spawned.size(), 2)


func test_every_available_enemy_spawns_at_the_crosshair() -> void:
	var room := await _crowd()
	var menu := _menu(room)
	var player: PlayerCharacter = room.player
	player.look_pitch = 0.0
	for entry: Dictionary in EnemyCatalog.available():
		var id: StringName = entry.id
		var expected: Dictionary = menu.spawn_point(id)
		assert_false(expected.is_empty(), "%s: a spot ahead" % id)
		var actor := menu.spawn_enemy(id)
		assert_not_null(actor, "%s spawned" % id)
		if actor == null:
			continue
		assert_eq(actor.get_parent(), room, "%s: in the room" % id)
		assert_almost_eq(actor.global_position.x, (expected.position as Vector3).x, 0.02, "%s: at the crosshair" % id)
		assert_almost_eq(actor.global_position.z, (expected.position as Vector3).z, 0.02)
		assert_almost_eq(actor.global_position.y, 0.0, 0.02, "%s: on the floor" % id)
		assert_true(actor.is_in_group(&"enemy"))
		assert_true(menu.spawned.has(actor))
		await _ticks(2)


# --- AI enemies ---------------------------------------------------------------------------


func test_an_ai_enemy_spawned_in_the_crowd_room_goes_through_its_spawner() -> void:
	var room := await _crowd()
	room.spawner.scene_override = {&"punk": PROBE}
	var menu := _menu(room)
	room.player.look_pitch = 0.0
	var point: Dictionary = menu.spawn_point(&"punk")
	var enemy := menu.spawn_enemy(&"punk") as Node3D
	assert_not_null(enemy, "spawned")
	assert_eq(enemy.name, &"Punk1", "named and counted per archetype by the spawner")
	assert_eq(enemy.display_name, "Punk 1")
	assert_eq(enemy.entered_from, point.position, "it starts in ENTER from where it stands")
	assert_eq(enemy.entered_lane, point.position, "with nowhere to walk first")
	assert_eq(room.spawner.alive_count(), 1, "the spawner counts it")
	var second := menu.spawn_enemy(&"punk") as Node3D
	assert_not_null(second)
	assert_eq(second.name, &"Punk2")
	assert_gt(second.global_position.distance_to(enemy.global_position), menu.spawn_actor_clearance_m - 0.01, "beside the first, not on it")
	assert_eq(room.enemies().size(), 2)


func test_an_ai_enemy_spawned_in_the_training_room_has_no_spawner_and_no_navmesh() -> void:
	var room := await _training()
	var menu := _menu(room)
	menu.scene_override = {&"punk": PROBE}
	var player: PlayerCharacter = room.get(&"player")
	player.look_pitch = 0.0
	var point: Dictionary = menu.spawn_point(&"punk")
	var enemy := menu.spawn_enemy(&"punk") as Node3D
	assert_not_null(enemy, "spawned in a room with no spawner")
	assert_eq(enemy.name, &"Punk1")
	assert_eq(enemy.get_parent(), room)
	assert_eq(enemy.entered_from, point.position)
	assert_true(enemy.is_in_group(&"ai_enemy"))
	assert_eq((menu.spawn_enemy(&"punk") as Node3D).name, &"Punk2", "counted by the menu")
	assert_null(menu.spawn_enemy(&"no_such_enemy"), "an unknown id spawns nothing")


# --- Removing, waves, freeze --------------------------------------------------------------


func test_remove_all_enemies_leaves_no_group_member_in_the_same_frame() -> void:
	var room := await _crowd()
	room.spawner.scene_override = {&"punk": PROBE}
	var menu := _menu(room)
	room.player.look_pitch = 0.0
	var dummy := menu.spawn_dummy()
	var punk := menu.spawn_enemy(&"punk")
	room.spawner.spawn_enemy(&"punk", Vector3(-8.0, 0.0, -3.0), 0.0)
	await _ticks(2)
	assert_gte(get_tree().get_nodes_in_group(&"enemy").size(), 3)
	assert_eq(menu.remove_all_enemies(), 3, "every enemy, whoever spawned it")
	assert_eq(get_tree().get_nodes_in_group(&"enemy").size(), 0, "none left in the group, in the same frame")
	assert_eq(get_tree().get_nodes_in_group(&"ai_enemy").size(), 0)
	assert_false(punk.is_in_group(&"actor"), "and out of the actor group")
	assert_eq(menu.spawned.size(), 0)
	assert_eq(room.spawner.alive_count(), 0)
	await _ticks(2)
	assert_false(is_instance_valid(dummy))
	assert_false(is_instance_valid(punk))


func test_remove_spawned_takes_only_what_the_menu_spawned() -> void:
	var room := await _crowd()
	room.spawner.scene_override = {&"punk": PROBE}
	var menu := _menu(room)
	room.player.look_pitch = 0.0
	var mine := menu.spawn_enemy(&"punk")
	var other := room.spawner.spawn_enemy(&"punk", Vector3(-8.0, 0.0, -3.0), 0.0)
	await _ticks(2)
	assert_eq(menu.remove_spawned_dummies(), 1)
	assert_false(mine.is_in_group(&"ai_enemy"))
	assert_true(other.is_in_group(&"ai_enemy"), "the room's own enemy stays")


func test_the_waves_button_follows_the_room() -> void:
	var room := await _crowd()
	var menu := _menu(room)
	assert_false(menu.waves_button.disabled, "this room has waves")
	menu.set_waves(true)
	assert_true(Tuning.data.waves_enabled, "on")
	assert_string_contains(menu.waves_button.text, "ON")
	menu.waves_button.pressed.emit()
	assert_false(Tuning.data.waves_enabled, "the button toggles")
	assert_string_contains(menu.waves_button.text, "off")
	Tuning.set_value(&"waves_enabled", true)
	assert_string_contains(menu.waves_button.text, "ON", "the F1 panel's switch is the same one")


func test_the_waves_button_is_disabled_without_a_spawner() -> void:
	var menu := _menu(await _training())
	assert_true(menu.waves_button.disabled, "the training room has no waves")
	menu.set_waves(true)
	assert_false(Tuning.data.waves_enabled, "and the click does nothing")


func test_freeze_ai_is_the_debug_tunable() -> void:
	var menu := _menu(await _training())
	assert_false(menu.freeze_toggle.button_pressed)
	menu.freeze_toggle.button_pressed = true
	assert_true(Tuning.data.ai_frozen, "the toggle sets ai_frozen")
	assert_string_contains(menu.freeze_toggle.text, "ON")
	Tuning.set_value(&"ai_frozen", false)
	assert_false(menu.freeze_toggle.button_pressed, "and follows it")
	menu.set_ai_frozen(true)
	assert_true(Tuning.data.ai_frozen)
