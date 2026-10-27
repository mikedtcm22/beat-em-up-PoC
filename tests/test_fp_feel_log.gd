extends GutTest
## Feel question 4 of Milestone 4 (grab-03, P3-early): the combat log sits over the knee in a hold.
## Two alternatives, both defaulting to today's behavior: a key (L, listed in the help overlay) that
## puts the log away and brings it back, and Tuning's combat_log_hide_while_holding (Look > FP feel),
## which holds the log back for as long as the player holds an enemy. The log keeps recording
## through both.

const ROOM := preload("res://game/level/test_room.tscn")
const FAR := Vector3(30.0, 0.0, -30.0)

var room: Node3D
var player: PlayerCharacter
var dummy: TrainingDummy


func before_each() -> void:
	TimeController.clear()
	TimeController.debug_scale = 1.0
	Tuning.apply(TuningData.new())
	Tuning.data.dummy_health = 500.0


func after_each() -> void:
	TimeController.clear()
	Tuning.apply(TuningData.new())


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_until(condition: Callable, max_ticks: int = 400) -> bool:
	for i in max_ticks:
		if condition.call():
			return true
		await get_tree().physics_frame
	return false


## The test room with one dummy 1.1 m ahead of the player (the others far away) and a log overlay in
## the tree.
func _setup() -> CombatLogOverlay:
	room = ROOM.instantiate()
	room.set(&"with_presentation", false)
	add_child_autofree(room)
	await _ticks(2)
	player = room.get(&"player")
	player.input.scripted = true
	var dummies: Array[TrainingDummy] = []
	dummies.assign(room.get(&"dummies"))
	for i in dummies.size():
		var pos := player.global_position + player.global_basis * Vector3(0.0, 0.0, -1.1) if i == 0 else FAR + Vector3(i * 3.0, 0.0, 0.0)
		var to_player := player.global_position - pos
		dummies[i].sparring = false
		dummies[i].set_post(pos, atan2(-to_player.x, -to_player.z), true)
	dummy = dummies[0]
	await _ticks(3)
	var log_overlay := CombatLogOverlay.new()
	add_child_autofree(log_overlay)
	return log_overlay


func _holding() -> bool:
	return player.holding_enemy() != null and player.state == CombatTypes.ActorState.GRABBING


func _key(keycode: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	return event


# --- The tunable and the key are today's by default -----------------------------------------------


func test_the_feel_alternative_defaults_to_todays_behavior_and_sits_in_fp_feel() -> void:
	assert_false(TuningData.new().combat_log_hide_while_holding, "the log is not hidden by a hold by default")
	var info := Tuning._property_info(Tuning.tuning_properties(), &"combat_log_hide_while_holding")
	assert_eq(info.group, "Look", "in the Look group")
	assert_eq(info.subgroup, "FP feel", "in its FP feel subgroup, beside fp_knockdown_hide_torso")
	assert_eq(info.type, TYPE_BOOL, "a toggle")
	assert_true(Tuning.is_preset_property(&"combat_log_hide_while_holding"), "a preset holds it")
	var shipped := FileAccess.get_file_as_string("res://tuning/default.json")
	assert_true(shipped.contains("combat_log_hide_while_holding"), "tuning/default.json lists it")


func test_the_log_is_shown_by_default_and_is_not_held_back() -> void:
	var overlay := await _setup()
	assert_true(overlay.visible)
	assert_true(overlay.is_showing())
	assert_false(overlay.is_held_back())


# --- The key -----------------------------------------------------------------------------------------


func test_the_l_key_puts_the_log_away_and_brings_it_back() -> void:
	var overlay := CombatLogOverlay.new()
	add_child_autofree(overlay)
	overlay.add_whiff(null, null)
	assert_eq(overlay.entry_count(), 1)
	overlay._unhandled_input(_key(KEY_L))
	assert_false(overlay.visible, "L hides it")
	assert_false(overlay.is_showing())
	overlay.add_whiff(null, null)
	assert_eq(overlay.entry_count(), 2, "it keeps recording while hidden")
	overlay._unhandled_input(_key(KEY_L))
	assert_true(overlay.visible, "L shows it again")
	assert_true(overlay.is_showing())


func test_the_key_is_one_press_not_a_release_a_repeat_or_another_key() -> void:
	var overlay := CombatLogOverlay.new()
	add_child_autofree(overlay)
	overlay._unhandled_input(_key(KEY_L, false))
	overlay._unhandled_input(_key(KEY_L, true, true))
	overlay._unhandled_input(_key(KEY_K))
	overlay._unhandled_input(_key(KEY_H))
	assert_true(overlay.visible, "neither a release, a held key's repeat nor another key touches it")
	assert_eq(CombatLogOverlay.TOGGLE_KEY, KEY_L)


func test_the_key_reaches_the_log_through_the_viewport() -> void:
	var overlay := CombatLogOverlay.new()
	add_child_autofree(overlay)
	get_viewport().push_input(_key(KEY_L), false)
	await _ticks(1)
	assert_false(overlay.visible, "a key event the viewport delivers hides it")
	get_viewport().push_input(_key(KEY_L, false), false)
	get_viewport().push_input(_key(KEY_L), false)
	await _ticks(1)
	assert_true(overlay.visible, "and the next press brings it back")


func test_the_help_overlay_lists_the_key() -> void:
	var rows: Array[String] = []
	for row: Array in HelpOverlay.KEY_ROWS:
		rows.append("%s %s" % [OS.get_keycode_string(row[1] as Key), row[0]])
	assert_has(rows, "L Combat log on / off", "a row for the combat log")
	var help := HelpOverlay.new()
	add_child_autofree(help)
	var texts: Array[String] = []
	for node: Node in help.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	assert_has(texts, "Combat log on / off", "the help overlay draws the row's label")
	assert_has(texts, OS.get_keycode_string(CombatLogOverlay.TOGGLE_KEY), "and its key")


# --- Hide while holding ---------------------------------------------------------------------------


func test_a_hold_leaves_the_log_alone_by_default() -> void:
	var overlay := await _setup()
	player.input.push_press(&"GRAB", 2)
	assert_true(await _wait_until(_holding, 30), "grabbed")
	await _ticks(3)
	assert_true(overlay.is_showing(), "the M3 behavior: the log stays over the knee")
	assert_false(overlay.is_held_back())


func test_a_hold_holds_the_log_back_while_the_tunable_is_on_and_it_keeps_recording() -> void:
	Tuning.set_value(&"combat_log_hide_while_holding", true)
	var overlay := await _setup()
	await _ticks(2)
	assert_false(overlay.is_held_back(), "no hold: shown")
	player.input.push_press(&"GRAB", 2)
	assert_true(await _wait_until(_holding, 30), "grabbed")
	assert_true(await _wait_until(func() -> bool: return overlay.is_held_back(), 5), "the log is held back")
	assert_true(overlay.visible, "the player's own switch (L) is not the thing that hid it")
	assert_false(overlay.is_showing(), "it draws nothing")
	# A hit is recorded while the log is held back (this overlay is not wired to CombatEvents: the
	# HUD's is, and it takes the same call).
	var before := overlay.entry_count()
	overlay.add_hit(_hit())
	assert_eq(overlay.entry_count(), before + 1, "a hit is recorded while the log is held back")
	# A knee does not let go of the held body: the log stays held back through it.
	player.input.push_press(&"P", 2)
	await _ticks(30)
	assert_true(_holding(), "still holding after the first knee")
	assert_true(overlay.is_held_back(), "and the log still held back")
	# Let go (a throw): it comes back.
	player.input.push_press(&"K", 2)
	assert_true(await _wait_until(func() -> bool: return not overlay.is_held_back(), 300), "the log returns when the hold ends")
	assert_true(overlay.is_showing())


func test_turning_the_tunable_off_in_a_hold_brings_the_log_back() -> void:
	Tuning.set_value(&"combat_log_hide_while_holding", true)
	var overlay := await _setup()
	player.input.push_press(&"GRAB", 2)
	assert_true(await _wait_until(_holding, 30), "grabbed")
	assert_true(await _wait_until(func() -> bool: return overlay.is_held_back(), 5))
	Tuning.set_value(&"combat_log_hide_while_holding", false)
	await _ticks(2)
	assert_false(overlay.is_held_back(), "off again: the log comes back at once, the hold goes on")
	assert_true(_holding())


func test_the_keys_switch_and_the_hold_are_two_things() -> void:
	# L off and a hold: still off when the hold ends (the hold only holds it back).
	Tuning.set_value(&"combat_log_hide_while_holding", true)
	var overlay := await _setup()
	overlay._unhandled_input(_key(KEY_L))
	assert_false(overlay.visible)
	player.input.push_press(&"GRAB", 2)
	assert_true(await _wait_until(_holding, 30))
	assert_true(await _wait_until(func() -> bool: return overlay.is_held_back(), 5))
	player.input.push_press(&"K", 2)
	assert_true(await _wait_until(func() -> bool: return not _holding(), 200), "the hold ends")
	assert_true(await _wait_until(func() -> bool: return not overlay.is_held_back(), 30))
	assert_false(overlay.is_showing(), "the log is still away: L put it away")
	assert_false(overlay.visible)


func _hit() -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = player
	hit.victim = dummy
	hit.damage = 4.0
	return hit
