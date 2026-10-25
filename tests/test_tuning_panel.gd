extends GutTest
## Milestone 2 WP1 (Spec §11): the F1 tuning panel, presets and the F4 cheat menu, and the
## TuningOverlay that hosts them in the test room. Every test starts and ends at the shipped
## defaults (Tuning.reset_to_default() also restores the shared move resources). Presets
## are saved and exported into a scratch folder of this run (Tuning.user_dir and
## export_dir), never into the user://tuning that every worktree and Game-boy share, and the
## folder is removed afterwards.

const ROOM := preload("res://game/level/test_room.tscn")
const TEST_PRESET := "gut_tuning_roundtrip"
const TEST_EXPORT := "gut_tuning_export"
const DEFAULT_PATH := "res://tuning/default.json"
const FAR := Vector3(30.0, 0.0, -30.0)

var hits: Array[HitInfo] = []
## This run's scratch preset folder.
var scratch_dir: String = ""


func before_all() -> void:
	scratch_dir = "user://gut_tuning_%d" % OS.get_process_id()
	Tuning.user_dir = scratch_dir.path_join("user")
	Tuning.export_dir = scratch_dir.path_join("export")


func after_all() -> void:
	_remove_tree(scratch_dir)
	Tuning.user_dir = Tuning.USER_DIR
	Tuning.export_dir = Tuning.EXPORT_DIR


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.set_value(&"god_mode", false)
	Tuning.set_value(&"one_hit_ko", false)
	TimeController.clear()
	TimeController.debug_scale = 1.0
	hits.clear()
	# A shipped default to list and load, as in res://tuning.
	_remove_tree(scratch_dir)
	DirAccess.make_dir_recursive_absolute(Tuning.export_dir)
	DirAccess.copy_absolute(DEFAULT_PATH, Tuning.export_dir.path_join(Tuning.DEFAULT_PRESET + ".json"))


func after_each() -> void:
	Tuning.reset_to_default()
	Tuning.set_value(&"god_mode", false)
	Tuning.set_value(&"one_hit_ko", false)
	TimeController.clear()
	TimeController.debug_scale = 1.0
	_remove_tree(scratch_dir)
	if CombatEvents.hit_landed.is_connected(_on_hit):
		CombatEvents.hit_landed.disconnect(_on_hit)


func _remove_tree(dir: String) -> void:
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		return
	for sub: String in DirAccess.get_directories_at(dir):
		_remove_tree(dir.path_join(sub))
	for file: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


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
	assert_true(panel.field(&"god_mode").check.button_pressed, "a reset leaves the cheats as they are")


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
	# The picker stays above the scrolling rows, on the Moves page only.
	assert_false(panel._content.is_ancestor_of(panel.move_picker), "the move picker doesn't scroll away")
	panel.show_category(TuningPanel.MOVES_CATEGORY)
	assert_true(panel.move_picker.is_visible_in_tree(), "shown with the Moves page")
	panel.show_category("Camera")
	assert_false(panel.move_picker.is_visible_in_tree(), "hidden with any other page")

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


func test_show_category_presses_only_its_own_button() -> void:
	var panel := _panel()
	for category_name: String in ["Camera", "Block", TuningPanel.MOVES_CATEGORY]:
		panel.show_category(category_name)
	var pressed: PackedStringArray = []
	for category_name: String in panel.categories():
		if panel.category_button(category_name).button_pressed:
			pressed.append(category_name)
	assert_eq(pressed, PackedStringArray([TuningPanel.MOVES_CATEGORY]), "one category highlighted")


func test_a_value_edit_refreshes_only_its_own_markers() -> void:
	var panel := _panel()
	# A TuningData edit leaves the move markers alone (no move_overrides() rebuild per edit).
	panel.move_picker.set_item_text(0, "untouched")
	panel.field(&"hitstop_heavy_ms").slider.value = 120.0
	assert_eq(panel.move_picker.get_item_text(0), "untouched", "the move picker isn't rebuilt")
	assert_string_ends_with(panel.category_button("Hit feel").text, TuningPanel.CHANGED_MARK)
	assert_false(panel.category_button("Camera").text.ends_with(TuningPanel.CHANGED_MARK))
	panel.field(&"hitstop_heavy_ms").slider.value = 85.0
	assert_eq(panel.category_button("Hit feel").text, "Hit feel", "and its mark goes with the change")
	# A move edit marks that move and Moves.
	Tuning.set_move_value(&"hook", &"startup", 9)
	var hook_index := -1
	for i in panel.move_picker.item_count:
		if panel.move_picker.get_item_metadata(i) == &"hook":
			hook_index = i
	assert_eq(panel.move_picker.get_item_text(hook_index), "hook" + TuningPanel.CHANGED_MARK)
	assert_string_ends_with(panel.category_button(TuningPanel.MOVES_CATEGORY).text, TuningPanel.CHANGED_MARK)
	Tuning.reset_move(&"hook")
	assert_eq(panel.move_picker.get_item_text(hook_index), "hook")
	assert_eq(panel.category_button(TuningPanel.MOVES_CATEGORY).text, TuningPanel.MOVES_CATEGORY)
	assert_ne(panel.move_picker.get_item_text(0), "untouched", "a full refresh (&\"\") rebuilds them")


func test_subgroups_are_parsed_and_shown_as_headings() -> void:
	# exported_properties() records each property's @export_subgroup within its group.
	var script := GDScript.new()
	script.source_code = "\n".join([
		"extends Resource",
		"@export var a: float = 1.0",
		"@export_group(\"G\")",
		"@export_subgroup(\"S1\")",
		"@export var b: float = 1.0",
		"@export var c: float = 1.0",
		"@export_subgroup(\"S2\")",
		"@export var d: bool = true",
		"@export_group(\"H\")",
		"@export var e: int = 2",
	])
	assert_eq(script.reload(), OK)
	var places := {}
	for info: Dictionary in Tuning.exported_properties(script.new()):
		places[str(info.name)] = [info.group, info.subgroup]
	assert_eq(places, {a = ["", ""], b = ["G", "S1"], c = ["G", "S1"], d = ["G", "S2"], e = ["H", ""]},
			"group and subgroup per property; a new group ends the subgroup")
	# The panel draws a heading above each subgroup's rows. TuningData's own subgroups arrive
	# with the VFX and Audio groups, so this gives Hit feel some for the test.
	var saved: Array[Dictionary] = Tuning._tuning_props
	var with_subgroups: Array[Dictionary] = []
	var expected: PackedStringArray = []
	var first_rows: Array[StringName] = []
	for info: Dictionary in Tuning.tuning_properties():
		var entry := info.duplicate()
		if entry.group == "Hit feel":
			var prop := str(entry.name)
			entry.subgroup = "Hitstop" if prop.begins_with("hitstop") else ("Camera punch" if prop.begins_with("cam_punch") \
					else ("Shake" if prop.begins_with("shake") else "Slow-mo and impact"))
			if not expected.has(entry.subgroup):
				expected.append(entry.subgroup)
				first_rows.append(StringName(prop))
		with_subgroups.append(entry)
	Tuning._tuning_props = with_subgroups
	var panel := _panel()
	Tuning._tuning_props = saved
	assert_eq(panel.headings("Hit feel"), expected, "a heading per subgroup, in order")
	assert_eq(panel.headings("Enemies"), PackedStringArray([
			"Wind-up", "Posture", "Navigation", "Director", "Waves", "Street Punk", "Kicker", "Pipe Thug",
			"Enemy grabs", "Bruiser", "Boss"]), "Milestone 3's enemy subgroups, in order")
	assert_eq(panel.headings("Camera"), PackedStringArray(["KO view"]), "TuningData's own Camera subgroup")
	var page: Control = panel._pages["Hit feel"]
	for i in expected.size():
		var row := panel.field(first_rows[i])
		var heading := page.get_child(row.get_index() - 1)
		var label := heading.get_child(0) as Label if heading.get_child_count() > 0 else null
		assert_not_null(label, "a heading above %s" % first_rows[i])
		if label:
			assert_string_contains(label.text, expected[i])
	assert_eq(panel.focus_chain("Hit feel").size(), 16, "the D-pad still walks every Hit feel row, past the headings")


# --- Presets ----------------------------------------------------------------------------


func test_a_preset_round_trips_through_json_including_move_overrides() -> void:
	# Every value away from its default, plus move overrides of each field type.
	for info: Dictionary in Tuning.preset_properties():
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
	var path := Tuning.user_dir.path_join(TEST_PRESET + ".json")
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
	for info: Dictionary in Tuning.preset_properties():
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
	for info: Dictionary in Tuning.preset_properties():
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
	assert_eq(Tuning.load_preset_file(DEFAULT_PATH), OK)
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


func test_presets_clamp_ranges_and_skip_unknown_enum_ids() -> void:
	# A stale or hand-edited preset can't break the camera, the VFX or the combat log.
	var err := Tuning.apply_preset({
		"tuning": {"fov_deg": 500, "hitstop_light_ms": -20, "dodge_frames": 9999, "shake_light": 0.2},
		"moves": {"jab_1": {"tier": 9, "reaction": 42, "startup": 500, "damage": 7.5},
				"hook": {"tier": CombatTypes.HitTier.FINISHER}},
	})
	assert_eq(err, OK)
	var fov := Tuning._property_info(Tuning.tuning_properties(), &"fov_deg")
	assert_almost_eq(Tuning.data.fov_deg, float(str(fov.hint_string).split(",")[1]), 0.0001, "FOV clamped to its range")
	assert_almost_eq(Tuning.data.hitstop_light_ms, 0.0, 0.0001, "clamped at the low end too")
	assert_eq(Tuning.data.dodge_frames, 40, "ints clamp to ints")
	assert_eq(typeof(Tuning.data.dodge_frames), TYPE_INT)
	assert_almost_eq(Tuning.data.shake_light, 0.2, 0.0001, "values in range load as they are")
	var jab := Tuning.get_move(&"jab_1")
	assert_eq(jab.tier, Tuning.shipped_move_value(&"jab_1", &"tier"), "an unknown tier id is skipped")
	assert_eq(jab.reaction, Tuning.shipped_move_value(&"jab_1", &"reaction"), "an unknown reaction id is skipped")
	assert_eq(jab.startup, 120, "move fields clamp to their range")
	assert_almost_eq(jab.damage, 7.5, 0.0001)
	assert_eq(Tuning.get_move(&"hook").tier, CombatTypes.HitTier.FINISHER, "a known enum id loads")
	var warnings := ", ".join(Tuning.last_warnings)
	for part: String in ["fov_deg clamped", "hitstop_light_ms clamped", "dodge_frames clamped", "skipped jab_1/tier",
			"skipped jab_1/reaction", "jab_1/startup clamped"]:
		assert_string_contains(warnings, part)
	assert_eq(Tuning.last_warnings.size(), 6, "nothing else: %s" % warnings)
	# or_greater / or_less let a value past that end of the slider.
	var open := {name = &"x", type = TYPE_FLOAT, hint = PROPERTY_HINT_RANGE, hint_string = "0,2,0.1,or_greater"}
	assert_almost_eq(float(Tuning._checked(open, 5.0, "x")), 5.0, 0.0001, "or_greater")
	assert_almost_eq(float(Tuning._checked(open, -1.0, "x")), 0.0, 0.0001, "but not below")
	assert_eq(Tuning.enum_ids("Light,Heavy,Finisher"), PackedInt32Array([0, 1, 2]))
	assert_eq(Tuning.enum_ids("Low:0,High:5,Max"), PackedInt32Array([0, 5, 6]))


func test_an_older_presets_dummy_revive_s_still_brings_the_dummy_back_on_time() -> void:
	# Before the KO blink-off (M2 phase 3) dummy_revive_s counted from the KO; it now counts
	# from the blink-off. A preset saved before (format 1, no ko_linger_s) holds the old count.
	var tuning := Tuning.data
	assert_eq(Tuning.PRESET_FORMAT, 2)
	assert_eq(Tuning.preset_dict(TEST_PRESET).format, Tuning.PRESET_FORMAT, "presets are saved in the new format")
	var after_blink := 4.0 - tuning.ko_linger_s - tuning.ko_blink_s
	assert_eq(Tuning.apply_preset({"format": 1, "tuning": {"dummy_revive_s": 4.0, "move_speed": 7.0}, "moves": {}}), OK)
	assert_almost_eq(tuning.dummy_revive_s, after_blink, 0.0001, "the old count less the lie and the blink")
	assert_almost_eq(tuning.move_speed, 7.0, 0.0001, "the rest loads as it is")
	assert_eq(Tuning.last_warnings.size(), 1, "noted: %s" % [Tuning.last_warnings])
	assert_string_contains(", ".join(Tuning.last_warnings), "dummy_revive_s")
	# The old default (2.5 s from the KO) is used up by the lie and the blink: no wait after.
	Tuning.apply_preset({"format": 1, "tuning": {"dummy_revive_s": 2.5}, "moves": {}})
	assert_almost_eq(tuning.dummy_revive_s, 0.0, 0.0001, "never below 0")
	# A format-1 preset saved since the blink-off (it holds ko_linger_s) already counts from it.
	Tuning.apply_preset({"format": 1, "tuning": {"dummy_revive_s": 2.0, "ko_linger_s": 1.0}, "moves": {}})
	assert_almost_eq(tuning.dummy_revive_s, 2.0, 0.0001, "a phase 3 preset loads as it is")
	assert_eq(Tuning.last_warnings, PackedStringArray(), "with nothing to note")
	# The current format, and a hand-written preset with no format, load as they are.
	for preset: Dictionary in [{"format": Tuning.PRESET_FORMAT, "tuning": {"dummy_revive_s": 2.5}},
			{"tuning": {"dummy_revive_s": 2.5}}]:
		Tuning.apply_preset(preset)
		assert_almost_eq(tuning.dummy_revive_s, 2.5, 0.0001, "%s loads as it is" % [preset])
		assert_eq(Tuning.last_warnings, PackedStringArray())


func test_preset_names_are_lower_case_and_default_is_reserved() -> void:
	assert_eq(Tuning.sanitize_preset_name(" Heavy V2! "), "heavy_v2_", "lower case, file-safe")
	for reserved: String in ["default", "Default", "_BACKUP"]:
		assert_true(Tuning.is_reserved_preset_name(reserved))
		assert_eq(Tuning.save_preset(reserved), ERR_ALREADY_IN_USE, "a user preset can't be called %s" % reserved)
	assert_false(DirAccess.dir_exists_absolute(Tuning.user_dir) and not DirAccess.get_files_at(Tuning.user_dir).is_empty(),
			"nothing saved")
	var panel := _panel()
	assert_eq(panel.save_preset("Default"), ERR_ALREADY_IN_USE)
	assert_string_contains(panel.status_label.text, "reserved")
	# A user default.json (from before the name was reserved) doesn't shadow the shipped one.
	Tuning.set_value(&"hitstop_light_ms", 99.0)
	Tuning.write_preset_file(Tuning.user_dir.path_join("default.json"), Tuning.preset_dict("default"))
	assert_eq(Tuning.load_preset("Default"), OK)
	assert_true(Tuning.is_default(), "'default' always loads the shipped defaults")
	for preset: Dictionary in Tuning.list_presets():
		assert_false(str(preset.name) == "default" and not preset.shipped, "and the user copy isn't listed")
	# Exporting "Default" with changed values is refused in any case.
	Tuning.set_value(&"hitstop_light_ms", 99.0)
	assert_eq(Tuning.export_preset("DeFaUlT"), ERR_INVALID_PARAMETER)


func test_cheat_states_stay_out_of_presets() -> void:
	Tuning.set_value(&"god_mode", true)
	Tuning.set_value(&"one_hit_ko", true)
	assert_false(Tuning.has_unsaved(), "a cheat isn't an unsaved tuning edit")
	assert_true(Tuning.is_default(), "nor a changed value")
	var preset := Tuning.preset_dict("x")
	for cheat: String in ["god_mode", "one_hit_ko"]:
		assert_false((preset.tuning as Dictionary).has(cheat), "%s isn't saved" % cheat)
		assert_false((Tuning.default_preset_dict().tuning as Dictionary).has(cheat), "nor in default.json")
	Tuning.reset_to_default()
	assert_true(Tuning.data.god_mode, "Reset to default leaves the cheats on")
	assert_true(Tuning.data.one_hit_ko)
	Tuning.set_value(&"god_mode", false)
	assert_eq(Tuning.apply_preset({"tuning": {"god_mode": true, "one_hit_ko": false}}), OK)
	assert_false(Tuning.data.god_mode, "an older preset holding a cheat doesn't turn it on")
	assert_true(Tuning.data.one_hit_ko, "or off")
	assert_eq(Tuning.last_warnings, PackedStringArray(), "and isn't reported as unknown")


func _pick(panel: TuningPanel, label: String) -> bool:
	panel.refresh_presets()
	for i in panel.preset_picker.item_count:
		if panel.preset_picker.get_item_text(i) == label:
			panel.preset_picker.select(i)
			return true
	return false


func test_reset_and_load_keep_unsaved_values_as_a_backup() -> void:
	var panel := _panel()
	var backup := Tuning.user_dir.path_join(Tuning.BACKUP_PRESET + ".json")
	panel.field(&"hitstop_heavy_ms").slider.value = 140.0
	Tuning.set_move_value(&"hook", &"startup", 9)
	assert_true(Tuning.has_unsaved())
	panel.reset_to_default()
	assert_true(Tuning.is_default(), "reset")
	assert_true(FileAccess.file_exists(backup), "the unsaved values are kept")
	assert_string_contains(panel.status_label.text, Tuning.BACKUP_PRESET, "and the status line says so")
	# Another Reset, with nothing unsaved, leaves that backup alone.
	panel.reset_to_default()
	var kept := Tuning.read_preset_file(backup)
	assert_almost_eq(float(kept.tuning.hitstop_heavy_ms), 140.0, 0.0001, "the backup still holds the edits")
	assert_eq(int(kept.moves.hook.startup), 9)
	# Loading the backup undoes the reset.
	assert_true(_pick(panel, Tuning.BACKUP_PRESET), "the backup is listed")
	assert_eq(panel.load_picked_preset(), OK)
	assert_almost_eq(Tuning.data.hitstop_heavy_ms, 140.0, 0.0001, "the edits are back")
	assert_eq(Tuning.get_move(&"hook").startup, 9)
	# Loading another preset over unsaved edits keeps them too.
	panel.field(&"shake_light").slider.value = 0.3
	assert_true(_pick(panel, "default  (shipped)"))
	assert_eq(panel.load_picked_preset(), OK)
	assert_true(Tuning.is_default())
	kept = Tuning.read_preset_file(backup)
	assert_almost_eq(float(kept.tuning.shake_light), 0.3, 0.0001, "the newer edits are the backup now")
	# Saved values aren't backed up again: the save holds them.
	panel.field(&"shake_light").slider.value = 0.35
	assert_eq(panel.save_preset(TEST_PRESET), OK)
	panel.reset_to_default()
	assert_almost_eq(float(Tuning.read_preset_file(backup).tuning.shake_light), 0.3, 0.0001, "the backup is unchanged")
	assert_false(panel.status_label.text.contains(Tuning.BACKUP_PRESET))


func test_the_panel_saves_loads_exports_and_resets_presets() -> void:
	var panel := _panel()
	panel.field(&"shake_heavy").slider.value = 0.4
	Tuning.set_move_value(&"roundhouse", &"recovery", 20)
	assert_eq(panel.save_preset(" gut tuning roundtrip "), OK, "Save")
	assert_eq(panel.preset_name_edit.text, TEST_PRESET, "names are made file-safe")
	assert_string_contains(panel.status_label.text, "Saved")
	assert_true(FileAccess.file_exists(Tuning.user_dir.path_join(TEST_PRESET + ".json")))
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
	var exported := Tuning.export_dir.path_join(TEST_EXPORT + ".json")
	assert_true(FileAccess.file_exists(exported), "written to the export folder (res://tuning/ in the game)")
	var exported_moves: Dictionary = Tuning.read_preset_file(exported).moves
	assert_eq(exported_moves.keys(), ["roundhouse"], "the move override is exported")
	assert_eq(int(exported_moves.get("roundhouse", {}).get("recovery", 0)), 20)
	var listed := false
	for i in panel.preset_picker.item_count:
		listed = listed or panel.preset_picker.get_item_text(i) == TEST_EXPORT + "  (shipped)"
	assert_true(listed, "exported presets are listed as shipped")
	var default_copy := Tuning.export_dir.path_join(Tuning.DEFAULT_PRESET + ".json")
	var shipped_default := FileAccess.get_file_as_string(default_copy)
	for name_text: String in [Tuning.DEFAULT_PRESET, "Default", " DEFAULT "]:
		assert_eq(panel.export_preset(name_text), ERR_INVALID_PARAMETER, "'%s' can't replace default.json" % name_text)
	assert_eq(FileAccess.get_file_as_string(default_copy), shipped_default, "untouched")
	assert_eq(DirAccess.get_files_at(Tuning.export_dir).size(), 2, "no Default.json beside it either")


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
	# The crosshair on a body: the new dummy stands beside it, in view (not hidden behind it,
	# not inside it).
	player.look_pitch = deg_to_rad(-6.0)
	var target := player.global_position + flat * 1.6
	dummies[1].global_position = target
	await _ticks(2)
	var beside: Vector3 = cheats.spawn_point().position
	var gap := beside - target
	gap.y = 0.0
	assert_gt(gap.length(), cheats.spawn_actor_clearance_m - 0.01, "clear of the dummy there")
	assert_lt(absf(gap.dot(flat)), 0.3, "beside it, not behind it")
	var sight := beside - player.global_position
	sight.y = 0.0
	assert_gt(sight.normalized().dot(flat), cos(deg_to_rad(40.0)), "in view")
	dummies[1].global_position = FAR + Vector3(3.0, 0.0, 0.0)

	# Reset dummies: back on their posts, standing, at full (re-read) health.
	var recorded: Vector4 = cheats._posts[dummies[0].get_instance_id()]
	var post := Vector3(recorded.x, recorded.y, recorded.z)
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


## How far `spot` is inside the near side of the north building fronts (their face is at z = -7).
func _past_north_wall(spot: Vector3, radius: float) -> float:
	return -7.0 + radius - spot.z


func test_spawning_keeps_out_of_walls_and_follows_the_player_in_other_views() -> void:
	var room: Node3D = await _room(true)
	var player: PlayerCharacter = room.get(&"player")
	player.input.scripted = true
	var dummies: Array[TrainingDummy] = []
	dummies.assign(room.get(&"dummies"))
	for i in dummies.size():
		dummies[i].sparring = false
		dummies[i].set_post(FAR + Vector3(i * 3.0, 0.0, 0.0), 0.0, true)
	var overlay: TuningOverlay = room.find_children("*", "TuningOverlay", false, false)[0]
	var cheats := overlay.cheats
	var radius := dummies[0].body_radius
	var cases: Array[Array] = [
		# [player position, look yaw (deg), look pitch (deg), what]
		[Vector3(-2.0, 0.0, -6.4), 0.0, -6.0, "facing a wall from 0.6 m"],
		[Vector3(-2.0, 0.0, -5.8), 70.0, -6.0, "70 degrees off a wall from 1.2 m"],
		[Vector3(-2.0, 0.0, -5.0), 0.0, -20.0, "the crosshair low on a wall"],
	]
	for case: Array in cases:
		player.global_position = case[0]
		player.look_yaw = deg_to_rad(case[1])
		player.look_pitch = deg_to_rad(case[2])
		await _ticks(3)
		var point := cheats.spawn_point()
		assert_false(point.is_empty(), "%s: a spot" % case[3])
		if point.is_empty():
			continue
		var spot: Vector3 = point.position
		assert_lt(_past_north_wall(spot, radius), 0.01, "%s: out of the wall (%s)" % [case[3], spot])
		var off := spot - player.global_position
		off.y = 0.0
		assert_gt(off.length(), cheats.spawn_min_distance_m - 0.01, "%s: off the player" % case[3])
		assert_almost_eq(spot.y, 0.0, 0.02, "%s: on the floor" % case[3])
	# Side view and free fly have no crosshair: the spot is in front of the player, not the
	# camera (which stands 11 m off, by the near curb).
	var director := room.find_child("CameraDirector", true, false)
	player.global_position = Vector3(-4.0, 0.0, 0.0)
	player.look_yaw = deg_to_rad(-90.0)
	player.look_pitch = 0.0
	for mode: StringName in [&"side_view", &"free_fly"]:
		director.call(&"set_mode", mode)
		await _ticks(3)
		var point := cheats.spawn_point()
		assert_false(point.is_empty(), "%s: a spot" % mode)
		if point.is_empty():
			continue
		var spot: Vector3 = point.position
		assert_almost_eq(spot.distance_to(player.global_position), cheats.spawn_open_distance_m, 0.3,
				"%s: in front of the player (%s)" % [mode, spot])
		assert_lt(absf(spot.z), 1.0, "%s: in the fight lane" % mode)
	director.call(&"set_mode", &"first_person")


func test_the_slow_time_scale_stretches_hitstop_and_slow_mo() -> void:
	var actor := Node.new()
	add_child_autofree(actor)
	var frozen_ticks := func(scale: float) -> int:
		TimeController.clear()
		TimeController.debug_scale = scale
		TimeController.hitstop([actor], Tuning.data.hitstop_light_ms / 1000.0)
		var count := 0
		for i in 60:
			await get_tree().physics_frame
			if TimeController.is_in_hitstop(actor):
				count += 1
		return count
	var normal: int = await frozen_ticks.call(1.0)
	var slow: int = await frozen_ticks.call(0.25)
	assert_eq(normal, roundi(Tuning.data.hitstop_light_ms * 0.06), "3 ticks of hitstop at 1x")
	assert_eq(slow, normal * 4, "four times as long at 0.25x")
	# Slow-mo (and its delay after the finisher's hitstop) stretches the same way.
	var slowmo_ticks := func(scale: float) -> int:
		TimeController.clear()
		TimeController.debug_scale = scale
		TimeController.slowmo(Tuning.data.slowmo_scale, Tuning.data.slowmo_ms / 1000.0, 0.1)
		var count := 0
		for i in 120:
			await get_tree().physics_frame
			if TimeController.is_slowmo():
				count += 1
		return count
	var slowmo_normal: int = await slowmo_ticks.call(1.0)
	var slowmo_slow: int = await slowmo_ticks.call(0.25)
	assert_almost_eq(slowmo_normal, roundi(Tuning.data.slowmo_ms * 0.06), 1, "250 ms of slow-mo at 1x")
	assert_almost_eq(slowmo_slow, roundi(Tuning.data.slowmo_ms * 0.06 * 4.0), 1, "four times as long, after a 4x delay")
	TimeController.debug_scale = 1.0
	TimeController.clear()


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


## A gamepad button pressed and let go, through the Input singleton like a real pad.
func _pad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func test_the_gamepad_reaches_every_row_and_a_b_lb_rb_work() -> void:
	var room: Node3D = await _room(true)
	var overlay: TuningOverlay = room.find_children("*", "TuningOverlay", false, false)[0]
	var panel := overlay.panel
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	assert_true(a.is_action(&"ui_accept"), "A is ui_accept")
	assert_true(b.is_action(&"ui_cancel"), "B is ui_cancel")
	var focus := func() -> Control: return overlay.window.gui_get_focus_owner()

	_pad(JOY_BUTTON_BACK)
	assert_true(panel.visible, "View opens the panel")
	assert_eq(focus.call(), panel.category_button("Hit feel"), "on Hit feel")
	_pad(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(focus.call(), panel.field(&"hitstop_light_ms").focus_control, "D-pad right enters Hit feel's first slider")

	# RB walks every category; down walks every row of each, and the last row holds.
	var order := panel.categories()
	var start := order.find("Hit feel")
	for step in order.size():
		var category_name := order[(start + step) % order.size()]
		var chain := panel.focus_chain(category_name)
		assert_eq(panel.category, category_name)
		assert_eq(focus.call(), chain[0] if not chain.is_empty() else null, "%s: on its first row" % category_name)
		if category_name != TuningPanel.MOVES_CATEGORY:
			var rows: Array[Control] = []
			for property: StringName in panel._category_fields[category_name]:
				rows.append(panel.field(property).focus_control)
			assert_eq(chain, rows, "%s: every row is on the D-pad" % category_name)
		for i in range(1, chain.size()):
			_pad(JOY_BUTTON_DPAD_DOWN)
			assert_eq(focus.call(), chain[i], "%s: down to row %d" % [category_name, i])
		_pad(JOY_BUTTON_DPAD_DOWN)
		assert_eq(focus.call(), chain[-1], "%s: the last row holds" % category_name)
		for i in range(chain.size() - 2, -1, -1):
			_pad(JOY_BUTTON_DPAD_UP)
		assert_eq(focus.call(), chain[0], "%s: back up to the first row" % category_name)
		_pad(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(panel.category, "Hit feel", "RB wraps around")
	_pad(JOY_BUTTON_LEFT_SHOULDER)
	assert_eq(panel.category, order[start - 1], "LB goes back")
	_pad(JOY_BUTTON_RIGHT_SHOULDER)

	# A flips a toggle; left from it goes back to the category, where down browses the list.
	var toggle := panel.field(&"impact_frame_enabled")
	for i in panel.focus_chain("Hit feel").size():
		if focus.call() == toggle.focus_control:
			break
		_pad(JOY_BUTTON_DPAD_DOWN)
	assert_true(toggle.has_row_focus(), "the focused row is marked")
	_pad(JOY_BUTTON_A)
	assert_false(Tuning.data.impact_frame_enabled, "A flips the toggle")
	_pad(JOY_BUTTON_A)
	assert_true(Tuning.data.impact_frame_enabled)
	_pad(JOY_BUTTON_DPAD_LEFT)
	assert_eq(focus.call(), panel.category_button("Hit feel"), "left goes back to the category")
	assert_false(toggle.has_row_focus())
	_pad(JOY_BUTTON_DPAD_DOWN)
	assert_eq(focus.call(), panel.category_button(order[start + 1]))
	assert_eq(panel.category, order[start + 1], "browsing the list shows each page")
	_pad(JOY_BUTTON_A)
	assert_eq(panel.category, order[start + 1], "A on a category keeps it shown")
	# Right on a slider steps it.
	_pad(JOY_BUTTON_DPAD_RIGHT)
	var slider_row: TuningField = null
	for property: StringName in panel._category_fields[order[start + 1]]:
		if panel.field(property).focus_control == focus.call():
			slider_row = panel.field(property)
	assert_not_null(slider_row)
	if slider_row and slider_row.slider:
		var before: float = slider_row.slider.value
		# A slider reads a pad press as Input.is_action_just_pressed(), which only holds in a
		# process frame (as for a real pad's events), not in the physics frame tests run in.
		await get_tree().process_frame
		_pad(JOY_BUTTON_DPAD_RIGHT)
		assert_almost_eq(float(Tuning.data.get(slider_row.property)), minf(before + slider_row.slider.step, slider_row.slider.max_value),
				0.0001, "right steps the slider")

	# The Moves page: A opens the move picker, B closes the list, then B closes the panel.
	for i in order.size():
		if panel.category == TuningPanel.MOVES_CATEGORY:
			break
		_pad(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(focus.call(), panel.move_picker)
	_pad(JOY_BUTTON_A)
	await get_tree().process_frame
	assert_true(panel.move_picker.get_popup().visible, "A opens the drop-down")
	_pad(JOY_BUTTON_B)
	await get_tree().process_frame
	assert_false(panel.move_picker.get_popup().visible, "B closes the drop-down")
	assert_true(overlay.is_open(), "but not the panel")
	_pad(JOY_BUTTON_B)
	assert_false(overlay.is_open(), "B closes the panel")
	await _ticks(TuningOverlay.UNFREEZE_TICKS + 1)


func test_the_free_fly_camera_stays_put_while_the_overlay_is_open() -> void:
	var room: Node3D = await _room(true)
	var overlay: TuningOverlay = room.find_children("*", "TuningOverlay", false, false)[0]
	var director := room.find_child("CameraDirector", true, false)
	director.call(&"set_mode", &"free_fly")
	await _ticks(2)
	var camera := get_tree().root.get_camera_3d()
	assert_true(camera is FreeFlyCamera, "free fly")
	var fly_events := InputMap.action_get_events(&"fly_forward").size()
	# Up held when the panel opens, then pressed again inside it.
	Input.parse_input_event(_key(KEY_UP, true))
	for i in 3:
		await get_tree().process_frame
	overlay.set_panel_open(true)
	assert_false(Input.is_action_pressed(&"fly_forward"), "the held key lets go of the action")
	var start := camera.global_position
	for keycode: Key in [KEY_UP, KEY_DOWN, KEY_PAGEUP, KEY_LEFT]:
		Input.parse_input_event(_key(keycode, true))
		for i in 6:
			await get_tree().process_frame
		Input.parse_input_event(_key(keycode, false))
	await get_tree().process_frame
	assert_almost_eq(camera.global_position.distance_to(start), 0.0, 0.0001, "the panel's keys don't fly the camera")
	overlay.close_all()
	assert_eq(InputMap.action_get_events(&"fly_forward").size(), fly_events, "the bindings are back on closing")
	assert_false(Input.is_action_pressed(&"fly_forward"), "and nothing is stuck down")
	await get_tree().process_frame
	start = camera.global_position
	Input.parse_input_event(_key(KEY_UP, true))
	for i in 6:
		await get_tree().process_frame
	Input.parse_input_event(_key(KEY_UP, false))
	await get_tree().process_frame
	assert_gt(camera.global_position.distance_to(start), 0.1, "closed, the arrow keys fly it again")
	director.call(&"set_mode", &"first_person")
	await _ticks(TuningOverlay.UNFREEZE_TICKS + 1)
