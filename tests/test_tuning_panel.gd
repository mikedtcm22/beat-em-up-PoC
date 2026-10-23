extends GutTest
## Milestone 2 WP1 (Spec §11): the F1 tuning panel, presets and the F4 cheat menu, and the
## TuningOverlay that hosts them in the test room. Every test starts and ends at the shipped
## defaults (Tuning.reset_to_default() also restores the shared move resources), and the
## preset files it writes are removed afterwards.

const ROOM := preload("res://game/level/test_room.tscn")
const TEST_PRESET := "gut_tuning_roundtrip"
const TEST_EXPORT := "gut_tuning_export"
const DEFAULT_PATH := "res://tuning/default.json"
const FAR := Vector3(30.0, 0.0, -30.0)

var hits: Array[HitInfo] = []


func before_each() -> void:
	Tuning.reset_to_default()
	TimeController.clear()
	TimeController.debug_scale = 1.0
	hits.clear()


func after_each() -> void:
	Tuning.reset_to_default()
	TimeController.clear()
	TimeController.debug_scale = 1.0
	for path: String in [
		Tuning.USER_DIR.path_join(TEST_PRESET + ".json"),
		Tuning.EXPORT_DIR.path_join(TEST_EXPORT + ".json"),
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if CombatEvents.hit_landed.is_connected(_on_hit):
		CombatEvents.hit_landed.disconnect(_on_hit)


func _on_hit(hit: HitInfo) -> void:
	hits.append(hit)


func _panel() -> TuningPanel:
	var panel := TuningPanel.new()
	panel.size = Vector2(790.0, 860.0)
	add_child_autofree(panel)
	return panel


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## The test room (no presentation unless asked) with its player scripted.
func _room(presentation: bool = false) -> Node3D:
	var room: Node3D = ROOM.instantiate()
	room.set(&"with_presentation", presentation)
	add_child_autofree(room)
	await _ticks(2)
	return room


func _supported(info: Dictionary) -> bool:
	return Tuning.VALUE_TYPES.has(int(info.type))


# --- Panel ------------------------------------------------------------------------------


func test_every_exported_tuning_property_gets_a_control() -> void:
	var panel := _panel()
	var props := Tuning.tuning_properties()
	assert_gt(props.size(), 100, "TuningData's exported properties are found")
	for info: Dictionary in props:
		var row := panel.field(StringName(info.name))
		assert_not_null(row, "a row for %s" % info.name)
		if row == null:
			continue
		assert_ne(row.kind, &"none", "%s is editable" % info.name)
		assert_true(Tuning.values_equal(row.current_value(), Tuning.data.get(info.name)), "%s shows its value" % info.name)
		match int(info.type):
			TYPE_BOOL:
				assert_not_null(row.check, "%s: a toggle" % info.name)
			TYPE_INT, TYPE_FLOAT:
				if int(info.hint) == PROPERTY_HINT_RANGE:
					assert_not_null(row.slider, "%s: a slider" % info.name)
					assert_eq(row.focus_control, row.slider, "%s: the gamepad steps the slider" % info.name)
				assert_not_null(row.spin, "%s: a number field" % info.name)
	# One category per @export_group, in declaration order, then the moves.
	var groups: PackedStringArray = []
	for info: Dictionary in props:
		var group := str(info.group) if str(info.group) != "" else TuningPanel.GENERAL_CATEGORY
		if not groups.has(group):
			groups.append(group)
	groups.append(TuningPanel.MOVES_CATEGORY)
	assert_eq(panel.categories(), groups, "categories follow the groups")
	assert_eq(panel.category, "Hit feel", "opens on hit feel")


func test_any_exported_type_gets_an_editor() -> void:
	# New tunables show up with no UI code, whatever their type.
	var cases: Array[Array] = [
		[{name = &"a", type = TYPE_FLOAT, hint = PROPERTY_HINT_RANGE, hint_string = "0,2,0.1,or_greater"}, 1.0, &"range"],
		[{name = &"b", type = TYPE_INT, hint = PROPERTY_HINT_NONE, hint_string = ""}, 3, &"number"],
		[{name = &"c", type = TYPE_BOOL, hint = PROPERTY_HINT_NONE, hint_string = ""}, true, &"bool"],
		[{name = &"d", type = TYPE_INT, hint = PROPERTY_HINT_ENUM, hint_string = "Low:0,High:5"}, 5, &"enum"],
		[{name = &"e", type = TYPE_VECTOR2, hint = PROPERTY_HINT_NONE, hint_string = ""}, Vector2(1.0, 2.0), &"vector"],
		[{name = &"f", type = TYPE_VECTOR3, hint = PROPERTY_HINT_NONE, hint_string = ""}, Vector3(1.0, 2.0, 3.0), &"vector"],
		[{name = &"g", type = TYPE_COLOR, hint = PROPERTY_HINT_NONE, hint_string = ""}, Color.RED, &"color"],
		[{name = &"h", type = TYPE_STRING, hint = PROPERTY_HINT_NONE, hint_string = ""}, "text", &"text"],
	]
	for case: Array in cases:
		var row := TuningField.new()
		add_child_autofree(row)
		row.setup(case[0], case[1], "doc", 200.0, 150.0, 100.0)
		row.show_value(case[1])
		assert_eq(row.kind, case[2], "%s editor" % case[0].name)
		assert_true(Tuning.values_equal(row.current_value(), case[1]), "%s shows its value" % case[0].name)
		assert_false(row.is_changed(), "%s at its default" % case[0].name)
	var enum_row := TuningField.new()
	add_child_autofree(enum_row)
	enum_row.setup(cases[3][0], 5, "", 200.0, 150.0, 100.0)
	enum_row.show_value(5)
	assert_eq(enum_row.option.get_item_text(enum_row.option.selected), "High", "enum ids from the hint")
	var range_row := TuningField.new()
	add_child_autofree(range_row)
	range_row.setup(cases[0][0], 1.0, "", 200.0, 150.0, 100.0)
	assert_true(range_row.spin.allow_greater, "or_greater lets the number field past the slider")


func test_editing_a_slider_changes_tuning_and_emits_changed() -> void:
	var panel := _panel()
	watch_signals(Tuning)
	var row := panel.field(&"hitstop_heavy_ms")
	row.slider.value = 120.0
	assert_almost_eq(Tuning.data.hitstop_heavy_ms, 120.0, 0.0001, "the slider sets the value")
	assert_signal_emitted_with_parameters(Tuning, "changed", [&"hitstop_heavy_ms"])
	assert_almost_eq(row.spin.value, 120.0, 0.0001, "the number field follows")
	assert_true(row.is_changed(), "marked as changed")
	assert_eq(row.name_label.get_theme_color(&"font_color"), HudStyle.HEALTH, "changed values are yellow")
	assert_string_ends_with(panel._category_buttons["Hit feel"].text, TuningPanel.CHANGED_MARK)
	# The number field the other way round.
	row.spin.value = 95.0
	assert_almost_eq(Tuning.data.hitstop_heavy_ms, 95.0, 0.0001, "the number field sets the value")
	assert_almost_eq(row.slider.value, 95.0, 0.0001, "the slider follows")
	# Ints stay ints.
	panel.field(&"dodge_frames").slider.value = 20.0
	assert_eq(typeof(Tuning.data.dodge_frames), TYPE_INT)
	assert_eq(Tuning.data.dodge_frames, 20)
	assert_signal_emitted_with_parameters(Tuning, "changed", [&"dodge_frames"])
	# Toggles.
	panel.field(&"impact_frame_enabled").check.button_pressed = false
	assert_false(Tuning.data.impact_frame_enabled, "the toggle sets the bool")
	assert_signal_emitted_with_parameters(Tuning, "changed", [&"impact_frame_enabled"])
	# "reset" puts the default back.
	row.reset_button.pressed.emit()
	assert_almost_eq(Tuning.data.hitstop_heavy_ms, 85.0, 0.0001, "reset restores the default")
	assert_false(row.is_changed())


func test_changes_made_elsewhere_show_in_the_panel() -> void:
	var panel := _panel()
	Tuning.set_value(&"fov_deg", 100.0)
	assert_almost_eq(panel.field(&"fov_deg").slider.value, 100.0, 0.0001, "set_value shows")
	Tuning.set_value(&"god_mode", true)
	assert_true(panel.field(&"god_mode").check.button_pressed, "a cheat toggled elsewhere shows")
	Tuning.reset_to_default()
	assert_almost_eq(panel.field(&"fov_deg").slider.value, 90.0, 0.0001, "a reset shows")
	assert_false(panel.field(&"god_mode").check.button_pressed)


func test_doc_comments_become_tooltips() -> void:
	var panel := _panel()
	var tip := panel.field(&"attack_move_mult").tooltip_text
	assert_string_contains(tip, "Fraction of move_speed", "the ## doc comment")
	assert_string_contains(tip, "Default: 0.2")
	assert_string_contains(panel.move_field(&"knockback").tooltip_text, "Knockback velocity")


func test_the_moves_page_edits_the_loaded_move_resources() -> void:
	var panel := _panel()
	watch_signals(Tuning)
	var files: Array[String] = []
	for file: String in ResourceLoader.list_directory(Tuning.MOVES_DIR):
		if file.get_extension() == "tres":
			files.append(file)
	assert_eq(panel.move_picker.item_count, files.size(), "every move is listed")
	# The brief's fields: frame data, damage, knockback, hitstun, camera offsets, blocking.
	for field_name: StringName in [&"startup", &"active", &"recovery", &"damage", &"knockback", &"hitstun",
			&"tier", &"reaction", &"camera_pitch_deg", &"camera_drop_m", &"camera_yaw_deg", &"unblockable",
			&"guard_damage_mult", &"blocked_recoil_frames"]:
		assert_not_null(panel.move_field(field_name), "a move row for %s" % field_name)
	assert_null(panel.move_field(&"hitboxes"), "hitboxes are structure, not tuning")
	assert_null(panel.move_field(&"id"))

	panel.select_move(&"hook")
	var hook := load("res://game/combat/moves/hook.tres") as MoveData
	assert_true(is_same(hook, Tuning.get_move(&"hook")), "the panel edits the loaded resource")
	panel.move_field(&"startup").slider.value = 9.0
	assert_eq(hook.startup, 9, "startup edited")
	assert_signal_emitted_with_parameters(Tuning, "changed", [&"moves/hook/startup"])
	panel.move_field(&"knockback").axes[0].value = -3.0
	assert_almost_eq(hook.knockback.x, -3.0, 0.0001, "knockback edited")
	var tier := panel.move_field(&"tier").option
	var finisher := tier.get_item_index(CombatTypes.HitTier.FINISHER)
	tier.select(finisher)
	tier.item_selected.emit(finisher)
	assert_eq(hook.tier, CombatTypes.HitTier.FINISHER, "tier edited")
	assert_eq(Tuning.shipped_move_value(&"hook", &"startup"), 6, "the shipped value is kept apart")
	assert_true(panel.move_field(&"startup").is_changed())
	assert_string_ends_with(panel.move_picker.get_item_text(panel.move_picker.selected), TuningPanel.CHANGED_MARK)
	# Another move shows its own values and defaults.
	panel.select_move(&"jab_1")
	assert_eq(panel.move_field(&"startup").current_value(), 4, "jab_1's startup")
	assert_false(panel.move_field(&"startup").is_changed())
	# The move sets (what the player chains) hold the same resources.
	var ground := load("res://game/combat/movesets/ground.tres") as MoveSet
	assert_not_null(ground)
	var jab_1 := Tuning.get_move(&"jab_1")
	var jab_2: MoveData = jab_1.branches[0].move
	assert_true(is_same(jab_2, Tuning.get_move(&"jab_2")), "branches reach the edited resources")
	assert_true(is_same(jab_2.branches[0].move, hook), "hook too")
	# Reset move.
	panel.select_move(&"hook")
	Tuning.reset_move(&"hook")
	assert_eq(hook.startup, 6, "reset move restores the shipped values")
	assert_eq(hook.tier, CombatTypes.HitTier.HEAVY)
	assert_almost_eq(panel.move_field(&"knockback").current_value().x, -2.2, 0.0001, "and the panel shows them")


func test_a_move_edit_applies_on_the_next_use() -> void:
	var room: Node3D = await _room()
	var player: PlayerCharacter = room.get(&"player")
	player.input.scripted = true
	var dummies: Array[TrainingDummy] = []
	dummies.assign(room.get(&"dummies"))
	for i in dummies.size():
		var pos := player.global_position + player.global_basis * Vector3(0.0, 0.0, -0.85) if i == 0 else FAR + Vector3(i * 3.0, 0.0, 0.0)
		var to_player := player.global_position - pos
		dummies[i].sparring = false
		dummies[i].set_post(pos, atan2(-to_player.x, -to_player.z), true)
	Tuning.set_value(&"dummy_health", 500.0)
	await _ticks(3)
	CombatEvents.hit_landed.connect(_on_hit)
	Tuning.set_move_value(&"jab_1", &"damage", 21.0)
	player.input.push_press(&"P")
	for i in 40:
		await get_tree().physics_frame
		if not hits.is_empty():
			break
	assert_eq(hits.size(), 1, "the jab lands")
	if hits.size() == 1:
		assert_eq(hits[0].move.id, &"jab_1")
		assert_almost_eq(hits[0].damage, 21.0, 0.0001, "with the edited damage")


func test_dummies_re_read_what_they_cache() -> void:
	var room: Node3D = await _room()
	var dummies: Array[TrainingDummy] = []
	dummies.assign(room.get(&"dummies"))
	var dummy := dummies[0]
	dummy.sparring = false
	dummy.set_post(FAR, 0.0, true)
	await _ticks(2)
	dummy.health = dummy.max_health * 0.5
	Tuning.set_value(&"dummy_health", 60.0)
	assert_almost_eq(dummy.max_health, 60.0, 0.0001, "dummy_health applies at once")
	assert_almost_eq(dummy.health, 30.0, 0.0001, "keeping the share of health left")
	# The sparring jab's wind-up-scaled copy follows edits of the jab.
	Tuning.set_value(&"windup_mult", 2.0)
	dummy.start_jab()
	assert_eq(dummy.current_move.startup, 48, "24-frame wind-up, doubled")
	dummy.reset_state()
	Tuning.set_move_value(&"dummy_jab", &"startup", 30)
	dummy.start_jab()
	assert_eq(dummy.current_move.startup, 60, "the edited 30 frames, doubled")
	dummy.reset_state()


# --- Presets ----------------------------------------------------------------------------


func test_a_preset_round_trips_through_json_including_move_overrides() -> void:
	# Every value away from its default, plus move overrides of each field type.
	for info: Dictionary in Tuning.tuning_properties():
		var value: Variant = Tuning.data.get(info.name)
		if value is bool:
			Tuning.set_value(info.name, not value)
		elif (value is float or value is int) and int(info.hint) == PROPERTY_HINT_RANGE:
			var parts := str(info.hint_string).split(",")
			var far_end := float(parts[1]) if not is_equal_approx(float(value), float(parts[1])) else float(parts[0])
			Tuning.set_value(info.name, roundi(far_end) if value is int else far_end)
	Tuning.set_move_value(&"uppercut", &"damage", 15.5)
	Tuning.set_move_value(&"uppercut", &"knockback", Vector3(0.5, 7.0, 2.0))
	Tuning.set_move_value(&"push_kick", &"tier", CombatTypes.HitTier.HEAVY)
	Tuning.set_move_value(&"back_elbow", &"unblockable", true)
	var before := Tuning.preset_dict(TEST_PRESET)
	var overrides := Tuning.move_overrides()
	assert_eq(overrides.keys().size(), 3, "three moves overridden")
	assert_eq((overrides[&"uppercut"] as Dictionary).size(), 2, "only the fields that differ")

	assert_eq(Tuning.save_preset(TEST_PRESET), OK, "saved")
	var path := Tuning.USER_DIR.path_join(TEST_PRESET + ".json")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "the file is JSON")
	if not parsed is Dictionary:
		return
	assert_eq(parsed.preset, TEST_PRESET)
	assert_eq(parsed.moves.uppercut.knockback, [0.5, 7.0, 2.0], "vectors as arrays")
	assert_eq((parsed.tuning as Dictionary).size(), before.tuning.size(), "every value is in the file")

	Tuning.reset_to_default()
	assert_true(Tuning.is_default(), "back to defaults before loading")
	assert_eq(Tuning.load_preset(TEST_PRESET), OK, "loaded")
	assert_eq(Tuning.last_warnings, PackedStringArray(), "nothing skipped")
	for info: Dictionary in Tuning.tuning_properties():
		if not _supported(info):
			continue
		var expected: Variant = Tuning.decode_value(before.tuning[str(info.name)], int(info.type))
		var got: Variant = Tuning.data.get(info.name)
		assert_eq(typeof(got), int(info.type), "%s keeps its type" % info.name)
		assert_true(Tuning.values_equal(got, expected), "%s round-trips (%s, %s)" % [info.name, got, expected])
	var uppercut := Tuning.get_move(&"uppercut")
	assert_almost_eq(uppercut.damage, 15.5, 0.0001, "move damage")
	assert_true(uppercut.knockback.is_equal_approx(Vector3(0.5, 7.0, 2.0)), "move knockback")
	assert_eq(Tuning.get_move(&"push_kick").tier, CombatTypes.HitTier.HEAVY, "move tier")
	assert_true(Tuning.get_move(&"back_elbow").unblockable, "move bool")
	assert_eq(Tuning.move_overrides().keys().size(), 3, "the same overrides")


func test_the_default_preset_equals_the_shipped_defaults() -> void:
	var preset := Tuning.read_preset_file(DEFAULT_PATH)
	assert_false(preset.is_empty(), "res://tuning/default.json is shipped")
	if preset.is_empty():
		return
	var regenerate := " (regenerate: godot --headless -s tools/gen_default_preset.gd)"
	var tuning: Dictionary = preset.tuning
	var names: Array[String] = []
	for info: Dictionary in Tuning.tuning_properties():
		if _supported(info):
			names.append(str(info.name))
			assert_true(tuning.has(str(info.name)), "default.json has %s%s" % [info.name, regenerate])
			if tuning.has(str(info.name)):
				var value: Variant = Tuning.decode_value(tuning[str(info.name)], int(info.type))
				assert_true(Tuning.values_equal(value, Tuning.defaults().get(info.name)),
						"default.json %s = %s, the code says %s%s" % [info.name, value, Tuning.defaults().get(info.name), regenerate])
	for key: Variant in tuning:
		assert_true(names.has(str(key)), "default.json has no stale %s%s" % [key, regenerate])
	assert_eq(preset.moves, {}, "no move overrides")
	# Loading it from changed values gives exactly the shipped defaults.
	Tuning.set_value(&"hitstop_light_ms", 99.0)
	Tuning.set_move_value(&"jab_1", &"startup", 9)
	assert_false(Tuning.is_default())
	assert_eq(Tuning.load_preset(Tuning.DEFAULT_PRESET), OK)
	assert_true(Tuning.is_default(), "default.json loads the shipped defaults")
	assert_eq(JSON.stringify(Tuning.default_preset_dict(), "\t", false) + "\n",
			FileAccess.get_file_as_string(DEFAULT_PATH), "the file is the generator's output" + regenerate)


func test_presets_skip_unknown_values_and_default_missing_ones() -> void:
	Tuning.set_value(&"move_speed", 9.0)
	Tuning.set_move_value(&"hook", &"startup", 11)
	var err := Tuning.apply_preset({
		"tuning": {"hitstop_light_ms": 70, "no_such_value": 1, "fov_deg": "wide"},
		"moves": {"no_such_move": {"damage": 1}, "jab_1": {"startup": 6, "id": "x"}},
	})
	assert_eq(err, OK)
	assert_almost_eq(Tuning.data.hitstop_light_ms, 70.0, 0.0001, "known values load")
	assert_eq(typeof(Tuning.data.hitstop_light_ms), TYPE_FLOAT, "as floats")
	assert_almost_eq(Tuning.data.fov_deg, 90.0, 0.0001, "an unreadable value keeps the default")
	assert_almost_eq(Tuning.data.move_speed, 6.0, 0.0001, "a missing value is the default")
	assert_eq(Tuning.get_move(&"jab_1").startup, 6, "move override loads")
	assert_eq(Tuning.get_move(&"jab_1").id, &"jab_1", "non-tuning move fields are skipped")
	assert_eq(Tuning.get_move(&"hook").startup, 6, "moves start from the shipped values")
	assert_eq(Tuning.last_warnings.size(), 4, "each skip is reported: %s" % [Tuning.last_warnings])
	assert_eq(Tuning.apply_preset({"tuning": []}), ERR_INVALID_DATA, "not a preset")
	assert_eq(Tuning.load_preset("gut_no_such_preset"), ERR_FILE_NOT_FOUND)


func test_the_panel_saves_loads_exports_and_resets_presets() -> void:
	var panel := _panel()
	panel.field(&"shake_heavy").slider.value = 0.4
	Tuning.set_move_value(&"roundhouse", &"recovery", 20)
	assert_eq(panel.save_preset(" gut tuning roundtrip "), OK, "Save")
	assert_eq(panel.preset_name_edit.text, TEST_PRESET, "names are made file-safe")
	assert_string_contains(panel.status_label.text, "Saved")
	assert_true(FileAccess.file_exists(Tuning.USER_DIR.path_join(TEST_PRESET + ".json")))
	assert_eq(panel.save_preset("  "), ERR_INVALID_PARAMETER, "a name is needed")

	panel.reset_to_default()
	assert_true(Tuning.is_default(), "Reset to default")
	assert_almost_eq(panel.field(&"shake_heavy").slider.value, 0.25, 0.0001, "the panel shows it")

	panel.refresh_presets()
	var index := -1
	for i in panel.preset_picker.item_count:
		if panel.preset_picker.get_item_text(i) == TEST_PRESET:
			index = i
	assert_gt(index, -1, "the saved preset is listed")
	panel.preset_picker.select(index)
	assert_eq(panel.load_picked_preset(), OK, "Load")
	assert_almost_eq(Tuning.data.shake_heavy, 0.4, 0.0001, "the value is back")
	assert_eq(Tuning.get_move(&"roundhouse").recovery, 20, "the move override is back")
	assert_almost_eq(panel.field(&"shake_heavy").slider.value, 0.4, 0.0001, "and shown")

	assert_eq(panel.export_preset(TEST_EXPORT), OK, "Export")
	var exported := Tuning.EXPORT_DIR.path_join(TEST_EXPORT + ".json")
	assert_true(FileAccess.file_exists(exported), "written to res://tuning/")
	var exported_moves: Dictionary = Tuning.read_preset_file(exported).moves
	assert_eq(exported_moves.keys(), ["roundhouse"], "the move override is exported")
	assert_eq(int(exported_moves.get("roundhouse", {}).get("recovery", 0)), 20)
	var listed := false
	for i in panel.preset_picker.item_count:
		listed = listed or panel.preset_picker.get_item_text(i) == TEST_EXPORT + "  (shipped)"
	assert_true(listed, "exported presets are listed as shipped")
	var shipped_default := FileAccess.get_file_as_string(DEFAULT_PATH)
	assert_eq(panel.export_preset(Tuning.DEFAULT_PRESET), ERR_INVALID_PARAMETER, "default.json stays the defaults")
	assert_eq(FileAccess.get_file_as_string(DEFAULT_PATH), shipped_default, "untouched")


# --- Cheats -----------------------------------------------------------------------------


func test_cheats_toggle() -> void:
	var cheats := CheatMenu.new()
	add_child_autofree(cheats)
	watch_signals(Tuning)
	cheats.god_mode_toggle.button_pressed = true
	assert_true(Tuning.data.god_mode, "god mode on")
	assert_signal_emitted_with_parameters(Tuning, "changed", [&"god_mode"])
	cheats.one_hit_toggle.button_pressed = true
	assert_true(Tuning.data.one_hit_ko, "one-hit KOs on")
	cheats.god_mode_toggle.button_pressed = false
	assert_false(Tuning.data.god_mode, "god mode off")
	Tuning.set_value(&"one_hit_ko", false)
	assert_false(cheats.one_hit_toggle.button_pressed, "the menu follows changes made elsewhere")

	assert_eq(cheats.time_scale_buttons.size(), 2)
	cheats.time_scale_buttons[0].pressed.emit()
	assert_almost_eq(TimeController.debug_scale, 0.25, 0.0001, "0.25x")
	assert_true(cheats.time_scale_buttons[0].button_pressed)
	assert_almost_eq(TimeController.sim_scale(), 0.25, 0.0001, "the whole simulation slows")
	cheats.time_scale_buttons[1].pressed.emit()
	assert_almost_eq(TimeController.debug_scale, 1.0, 0.0001, "1x")
	assert_true(cheats.time_scale_buttons[1].button_pressed)
	assert_false(cheats.time_scale_buttons[0].button_pressed)

	assert_true(cheats.skip_arena_button.disabled, "skip to arena waits for Milestone 5")


func test_cheats_spawn_a_dummy_at_the_crosshair_and_reset_dummies() -> void:
	var room: Node3D = await _room()
	var player: PlayerCharacter = room.get(&"player")
	player.input.scripted = true
	var dummies: Array[TrainingDummy] = []
	dummies.assign(room.get(&"dummies"))
	for i in dummies.size():
		dummies[i].sparring = false
		dummies[i].set_post(FAR + Vector3(i * 3.0, 0.0, 0.0), 0.0, true)
	await _ticks(2)
	var cheats := CheatMenu.new()
	cheats.world = room
	add_child_autofree(cheats)
	var start_count := get_tree().get_nodes_in_group(&"enemy").size()

	# Looking level: nothing within reach, so it stands spawn_open_distance_m along the ray.
	player.look_pitch = 0.0
	var ahead := cheats.spawn_point()
	var flat := Vector3(-player.get_look_basis().z.x, 0.0, -player.get_look_basis().z.z).normalized()
	var expected: Vector3 = player.get_eye_transform().origin + flat * cheats.spawn_open_distance_m
	assert_almost_eq((ahead.position as Vector3).x, expected.x, 0.02, "open ray: spawn ahead")
	assert_almost_eq((ahead.position as Vector3).y, 0.0, 0.02, "dropped to the floor")
	# Looking 30 degrees down: the crosshair ray meets the floor.
	player.look_pitch = deg_to_rad(-30.0)
	var eye := player.get_eye_transform().origin
	var dir := -player.get_look_basis().z
	var floor_spot := eye + dir * (eye.y / -dir.y)
	var dummy := cheats.spawn_dummy()
	assert_not_null(dummy, "spawned")
	if dummy == null:
		return
	assert_true(dummy.is_in_group(&"enemy"), "a real enemy")
	assert_eq(dummy.get_parent(), room, "in the room")
	assert_almost_eq(dummy.global_position.x, floor_spot.x, 0.02, "at the crosshair (x)")
	assert_almost_eq(dummy.global_position.z, floor_spot.z, 0.02, "at the crosshair (z)")
	assert_almost_eq(dummy.global_position.y, 0.0, 0.02, "on the floor")
	var to_player := (player.global_position - dummy.global_position).normalized()
	assert_gt(dummy.get_forward().dot(to_player), 0.99, "facing the player")
	assert_eq(get_tree().get_nodes_in_group(&"enemy").size(), start_count + 1)

	# Looking at one's feet: never on top of the player.
	player.look_pitch = deg_to_rad(-85.0)
	var feet: Vector3 = cheats.spawn_point().position
	var off := feet - player.global_position
	off.y = 0.0
	assert_gt(off.length(), cheats.spawn_min_distance_m - 0.01, "kept off the player")
	# Never inside another body: a dummy standing at the crosshair moves the spot back.
	player.look_pitch = deg_to_rad(-30.0)
	dummies[1].global_position = Vector3(floor_spot.x, 0.0, floor_spot.z)
	var clear: Vector3 = cheats.spawn_point().position
	var gap := clear - dummies[1].global_position
	gap.y = 0.0
	assert_gt(gap.length(), cheats.spawn_actor_clearance_m - 0.01, "clear of the dummy there")
	assert_lt((clear - player.global_position).length(), (floor_spot - player.global_position).length(),
			"stepped back toward the player")
	dummies[1].global_position = FAR + Vector3(3.0, 0.0, 0.0)

	# Reset dummies: back on their posts, standing, at full (re-read) health.
	var post := dummies[0].global_position
	dummies[0].global_position = post + Vector3(2.0, 0.0, 1.0)
	dummies[0].health = 3.0
	Tuning.set_value(&"dummy_health", 80.0)
	assert_almost_eq(dummies[2].max_health, 80.0, 0.0001, "dummies re-read dummy_health at once")
	assert_eq(cheats.reset_dummies(), start_count + 1, "every dummy reset")
	assert_true(dummies[0].global_position.is_equal_approx(post), "back on its post")
	assert_almost_eq(dummies[0].health, 80.0, 0.0001, "at full health")
	assert_eq(dummies[0].state, CombatTypes.ActorState.FREE)

	assert_eq(cheats.remove_spawned_dummies(), 1, "spawned dummies removed")
	await _ticks(1)
	assert_false(is_instance_valid(dummy))
	assert_eq(get_tree().get_nodes_in_group(&"enemy").size(), start_count)


# --- Overlay (the test room's F1 / F4 host) -----------------------------------------------


func _key(keycode: Key, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	return event


func _tap(keycode: Key) -> void:
	get_tree().root.push_input(_key(keycode, true))
	get_tree().root.push_input(_key(keycode, false))


## A left click at `pos` in canvas (1920x1080-based) coordinates.
func _click(pos: Vector2) -> void:
	var root := get_tree().root
	var screen := root.get_final_transform() * pos
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = screen
		event.global_position = screen
		root.push_input(event)


class InputProbe:
	extends Node
	var clicks: int = 0
	var keys: int = 0

	func _input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			clicks += 1
		elif event is InputEventKey:
			keys += 1


func test_the_test_room_wires_the_overlay_and_f1_f4_toggle_it() -> void:
	var room: Node3D = await _room(true)
	var overlays := room.find_children("*", "TuningOverlay", false, false)
	assert_eq(overlays.size(), 1, "the test room adds one TuningOverlay")
	if overlays.is_empty():
		return
	var overlay: TuningOverlay = overlays[0]
	var player: PlayerCharacter = room.get(&"player")
	assert_false(player.input.scripted, "the live player")
	assert_false(overlay.window.visible, "closed at start")

	var hud: GameHud = room.find_children("*", "GameHud", false, false)[0]
	hud.set_help_visible(true)
	_tap(KEY_F1)
	assert_true(overlay.panel.visible, "F1 opens the panel")
	assert_false(hud.help_overlay.visible, "the startup help steps aside")
	assert_true(overlay.window.visible)
	assert_true(player.input.scripted, "the player stands still")
	assert_true(overlay.is_player_frozen())
	assert_not_null(overlay.window.gui_get_focus_owner(), "a control has focus for the gamepad")

	_tap(KEY_F4)
	assert_true(overlay.cheats.visible, "F4 (pressed in the window) opens the cheats too")
	_tap(KEY_F1)
	assert_false(overlay.panel.visible, "F1 in the window closes the panel")
	assert_true(overlay.window.visible, "the cheats stay")
	assert_true(player.input.scripted, "still standing still")

	_tap(KEY_ESCAPE)
	assert_false(overlay.is_open(), "Esc closes everything")
	assert_false(overlay.window.visible)
	assert_false(GameInput.paused, "Esc did not pause the game")
	assert_true(player.input.scripted, "input stays out for a couple of ticks")
	await _ticks(TuningOverlay.UNFREEZE_TICKS + 1)
	assert_false(player.input.scripted, "then the player has input again")
	assert_false(overlay.is_player_frozen())

	# The gamepad's View button toggles the panel too.
	var view := InputEventJoypadButton.new()
	view.button_index = JOY_BUTTON_BACK
	view.pressed = true
	get_tree().root.push_input(view)
	assert_true(overlay.panel.visible, "View opens the panel")
	get_tree().root.push_input(view)
	assert_false(overlay.panel.visible, "View closes it")
	await _ticks(TuningOverlay.UNFREEZE_TICKS + 1)

	# The combo bot's scripted player is left alone.
	player.input.scripted = true
	overlay.toggle_cheats()
	overlay.toggle_cheats()
	await _ticks(TuningOverlay.UNFREEZE_TICKS + 1)
	assert_true(player.input.scripted, "a scripted player stays scripted")


func test_the_overlay_keeps_gameplay_input_out() -> void:
	var room: Node3D = await _room(true)
	var overlay: TuningOverlay = room.find_children("*", "TuningOverlay", false, false)[0]
	var probe := InputProbe.new()
	add_child_autofree(probe)
	overlay.set_panel_open(true)
	await get_tree().process_frame
	# A click on the panel goes to the panel's window only, never to the game's _input
	# handlers (GameInput would recapture the mouse on it).
	var rect := overlay.panel.get_global_rect()
	_click(rect.position + Vector2(rect.size.x * 0.5, 12.0))
	assert_eq(probe.clicks, 0, "a click on the panel stays in the window")
	_tap(KEY_W)
	assert_eq(probe.keys, 0, "keys go to the window")
	# A click on the game area around the panels lands on the transparent window too.
	_click(Vector2(1500.0, 800.0))
	assert_eq(probe.clicks, 0, "the game never sees the mouse while the overlay is up")
	assert_true(overlay.window.has_focus(), "and the window keeps focus")
	# Gamepad: the D-pad walks the controls.
	var before := overlay.window.gui_get_focus_owner()
	var down := InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_DPAD_DOWN
	down.pressed = true
	get_tree().root.push_input(down)
	var after := overlay.window.gui_get_focus_owner()
	assert_not_null(after)
	assert_ne(after, before, "D-pad down moves the focus")
	overlay.close_all()
	_tap(KEY_W)
	assert_gt(probe.keys, 0, "closed, the game gets its input again")
