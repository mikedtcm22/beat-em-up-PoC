extends GutTest
## Milestone 7, Phase 3 (C5): the drawn cards. Each fires once at its event (the mission's first frame, an enemy type's first
## appearance, an arena's clear, the level's clear), holds for its tunable, skips on input and writes no game state; they are
## off under the m6 profile and behind cutins_enabled, and a card with no art is skipped silently.

const StubEnemy := preload("res://tests/fixtures/stub_enemy.gd")
const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const CUT_IN_SCRIPT := "res://game/ui/cut_in.gd"

var _texture: Texture2D


func before_each() -> void:
	Tuning.reset_to_default()
	TimeController.clear()
	_texture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))


func after_each() -> void:
	Tuning.reset_to_default()
	TimeController.clear()


func _entry(key: StringName, label: String = "", textures: int = 1) -> CutInEntry:
	var entry := CutInEntry.new()
	entry.key = key
	entry.label = label
	for i in textures:
		entry.textures.append(_texture)
	return entry


## A set with art for the title, punk and Ox entrances, two punk knockout panels and the end; the thug has an entry but no art.
func _card_set() -> CutInSet:
	var set := CutInSet.new()
	set.title = _entry(&"title", "MISSION 1")
	set.entrances = [_entry(&"punk", "PUNK"), _entry(&"boss", "OX PELLERIN"), _entry(&"thug", "THUG", 0)]
	set.ko_panels = [_entry(&"punk", "", 2)]
	set.mission_end = _entry(&"mission_end", "CLEAR")
	return set


## A CutIn on `set`, with the trailer profile on unless `trailer` is false; `with_level` puts a level_root in the tree first.
func _cut_in(trailer: bool = true, with_level: bool = false, card_set: CutInSet = null) -> CutIn:
	Tuning.set_value(&"look_profile", 1 if trailer else 0)
	if with_level:
		var level := Node.new()
		level.add_to_group(LevelRoot.GROUP)
		add_child_autofree(level)
	var cut_in := CutIn.new()
	cut_in.cards = card_set if card_set != null else _card_set()
	add_child_autofree(cut_in)
	return cut_in


func _enemy(archetype: StringName) -> EnemyActor:
	var enemy := StubEnemy.new()
	enemy.archetype = archetype
	add_child_autofree(enemy)
	return enemy


## A KO of an `archetype` enemy, then an arena's clear. `clear_cards` puts away the entrance its spawn brought.
func _ko(cut_in: CutIn, archetype: StringName, clear_cards: bool = true) -> Node3D:
	var victim := _enemy(archetype)
	if clear_cards:
		while cut_in.is_showing():
			cut_in.skip()
	CombatEvents.ko.emit(victim, HitInfo.new())
	var arena := Node3D.new()
	add_child_autofree(arena)
	CombatEvents.arena_cleared.emit(arena)
	return arena


func _node() -> Node3D:
	var node := Node3D.new()
	add_child_autofree(node)
	return node


func _press(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _kinds(cut_in: CutIn) -> Array:
	return cut_in.history.map(func(h: Dictionary) -> int: return h.kind)


# --- Trigger -----------------------------------------------------------------------------------------------


func test_the_title_fires_once_on_the_first_frame_of_play() -> void:
	var cut_in := _cut_in(true, true)
	assert_false(cut_in.is_showing(), "nothing before the first frame")
	cut_in.advance(0.0)
	assert_true(cut_in.is_showing())
	assert_eq(cut_in.current_kind(), CutIn.Kind.TITLE)
	cut_in.advance(Tuning.data.cutin_title_hold_s + 0.1)
	cut_in.advance(1.0)
	assert_eq(_kinds(cut_in), [CutIn.Kind.TITLE], "once")


func test_no_title_without_a_level() -> void:
	var cut_in := _cut_in(true, false)
	cut_in.advance(0.0)
	assert_false(cut_in.is_showing(), "the rooms have no mission")


func test_each_enemy_type_enters_once() -> void:
	var cut_in := _cut_in()
	_enemy(&"punk")
	assert_eq(cut_in.current_kind(), CutIn.Kind.ENTRANCE)
	assert_eq(cut_in.current_key(), &"punk")
	cut_in.skip()
	_enemy(&"punk")
	assert_false(cut_in.is_showing(), "the second punk brings no card")
	assert_eq(_kinds(cut_in), [CutIn.Kind.ENTRANCE])


func test_ox_gets_his_name_card_at_the_boss_intro() -> void:
	var cut_in := _cut_in()
	_enemy(&"boss")
	assert_eq(cut_in.current_key(), &"boss")
	assert_eq(cut_in.cards.entrance_for(&"boss").label, "OX PELLERIN", "his name is drawn over the art")


func test_a_knockout_panel_per_arena_from_the_last_enemy_knocked_out() -> void:
	var cut_in := _cut_in()
	_ko(cut_in, &"punk")
	assert_eq(cut_in.current_kind(), CutIn.Kind.KO)
	assert_eq(cut_in.current_key(), &"punk")
	cut_in.skip()
	# A second arena takes the punk's next panel (the pick turns).
	_ko(cut_in, &"punk")
	assert_eq(cut_in.history.size(), 3, "two knockout panels after the entrance")
	assert_eq(cut_in.history[1].kind, CutIn.Kind.KO)


func test_an_arena_that_clears_twice_shows_one_panel() -> void:
	var cut_in := _cut_in()
	var arena := _ko(cut_in, &"punk")
	cut_in.skip()
	CombatEvents.arena_cleared.emit(arena)
	assert_false(cut_in.is_showing())


func test_the_panel_follows_the_last_ko_and_a_type_without_panels_shows_none() -> void:
	var cut_in := _cut_in()
	var thug := _enemy(&"thug")
	CombatEvents.ko.emit(thug, HitInfo.new())
	var arena := Node3D.new()
	add_child_autofree(arena)
	CombatEvents.arena_cleared.emit(arena)
	assert_false(cut_in.is_showing(), "no thug panels: skipped silently")


func test_the_mission_end_fires_on_level_cleared_and_holds_until_a_button() -> void:
	var cut_in := _cut_in()
	CombatEvents.level_cleared.emit(_node())
	assert_eq(cut_in.current_kind(), CutIn.Kind.END)
	cut_in.advance(600.0)
	assert_true(cut_in.is_showing(), "no time limit")
	cut_in._input(_press(&"punch"))
	assert_false(cut_in.is_showing())


# --- Hold ----------------------------------------------------------------------------------------------------


func test_a_card_holds_for_its_tunable() -> void:
	Tuning.set_value(&"cutin_entrance_hold_s", 0.9)
	Tuning.set_value(&"cutin_ko_hold_s", 0.5)
	Tuning.set_value(&"cutin_title_hold_s", 1.5)
	var cut_in := _cut_in(true, true)
	cut_in.advance(0.0)
	cut_in.advance(1.45)
	assert_true(cut_in.is_showing(), "the title is still up at 1.45 s")
	cut_in.advance(0.1)
	assert_false(cut_in.is_showing(), "and gone after 1.5 s")
	_enemy(&"punk")
	cut_in.advance(0.85)
	assert_true(cut_in.is_showing(), "the entrance holds 0.9 s")
	cut_in.advance(0.1)
	assert_false(cut_in.is_showing())
	_ko(cut_in, &"punk")
	cut_in.advance(0.45)
	assert_true(cut_in.is_showing(), "the knockout panel holds 0.5 s")
	cut_in.advance(0.1)
	assert_false(cut_in.is_showing())


func test_the_hold_follows_a_changed_tunable() -> void:
	Tuning.set_value(&"cutin_entrance_hold_s", 2.0)
	var cut_in := _cut_in()
	_enemy(&"punk")
	cut_in.advance(1.5)
	assert_true(cut_in.is_showing(), "a longer hold lasts longer")


func test_the_simulation_holds_while_a_card_is_up_and_runs_again_after() -> void:
	var cut_in := _cut_in()
	assert_eq(TimeController.sim_scale(), 1.0)
	_enemy(&"punk")
	assert_eq(TimeController.sim_scale(), 0.0, "held through TimeController")
	assert_false(GameInput.paused, "a hold is not a pause")
	cut_in.skip()
	assert_eq(TimeController.sim_scale(), 1.0)


func test_a_card_freed_while_up_lets_the_simulation_go() -> void:
	var cut_in := _cut_in()
	_enemy(&"punk")
	cut_in.free()
	assert_eq(TimeController.sim_scale(), 1.0)


func test_cards_queue_in_order_and_hold_until_the_last() -> void:
	var cut_in := _cut_in(true, true)
	cut_in.advance(0.0)
	_enemy(&"punk")
	_enemy(&"boss")
	assert_eq(cut_in.current_kind(), CutIn.Kind.TITLE)
	assert_eq(cut_in.waiting(), 2)
	cut_in.skip()
	assert_eq(cut_in.current_key(), &"punk")
	assert_eq(TimeController.sim_scale(), 0.0, "held across the hand-over")
	cut_in.skip()
	cut_in.skip()
	assert_eq(TimeController.sim_scale(), 1.0)


func test_a_knockout_panel_is_dropped_when_another_card_is_up() -> void:
	var cut_in := _cut_in()
	_enemy(&"punk")
	var before := cut_in.history.size()
	_ko(cut_in, &"punk", false)
	assert_eq(cut_in.history.size(), before, "no panel on top of a card")
	assert_eq(cut_in.waiting(), 0)


# --- Skip ----------------------------------------------------------------------------------------------------


func test_any_attack_or_confirm_input_skips_a_card() -> void:
	for action: StringName in [&"punch", &"kick", &"back_attack", &"grab", &"ui_accept"]:
		TimeController.clear()
		var cut_in := _cut_in()
		cut_in._seen.clear()
		var enemy := StubEnemy.new()
		enemy.archetype = &"punk"
		add_child_autofree(enemy)
		assert_true(cut_in.is_showing(), action)
		cut_in._input(_press(action))
		assert_false(cut_in.is_showing(), "%s skips the card" % action)
		cut_in.free()


func test_other_input_does_not_skip() -> void:
	var cut_in := _cut_in()
	_enemy(&"punk")
	cut_in._input(_press(&"move_forward"))
	assert_true(cut_in.is_showing())


func test_the_end_card_takes_no_button_during_its_lock() -> void:
	Tuning.set_value(&"cutin_end_lock_s", 0.5)
	var cut_in := _cut_in()
	CombatEvents.level_cleared.emit(_node())
	cut_in.advance(0.2)
	cut_in._input(_press(&"punch"))
	assert_true(cut_in.is_showing(), "a mashed attack does not dismiss it unseen")
	cut_in.advance(0.4)
	cut_in._input(_press(&"punch"))
	assert_false(cut_in.is_showing())


func test_a_skip_starts_the_next_waiting_card() -> void:
	var cut_in := _cut_in()
	_enemy(&"punk")
	CombatEvents.level_cleared.emit(_node())
	assert_eq(cut_in.waiting(), 1)
	cut_in._input(_press(&"kick"))
	assert_eq(cut_in.current_kind(), CutIn.Kind.END)


func test_the_card_ended_signal_says_whether_a_button_ended_it() -> void:
	var cut_in := _cut_in()
	var ends: Array = []
	cut_in.card_ended.connect(func(kind: int, _key: StringName, skipped: bool) -> void: ends.append([kind, skipped]))
	_enemy(&"punk")
	cut_in.skip()
	_enemy(&"boss")
	cut_in.advance(5.0)
	assert_eq(ends, [[CutIn.Kind.ENTRANCE, true], [CutIn.Kind.ENTRANCE, false]])


# --- Off -----------------------------------------------------------------------------------------------------


func test_no_card_under_the_m6_profile() -> void:
	var cut_in := _cut_in(false, true)
	cut_in.advance(0.0)
	_enemy(&"punk")
	_ko(cut_in, &"punk")
	CombatEvents.level_cleared.emit(_node())
	assert_eq(cut_in.history.size(), 0, "no card of any kind")
	assert_false(cut_in.visible)
	assert_eq(TimeController.sim_scale(), 1.0, "and no hold")


func test_no_card_with_the_tunable_off() -> void:
	Tuning.set_value(&"cutins_enabled", false)
	var cut_in := _cut_in(true, true)
	cut_in.advance(0.0)
	_enemy(&"punk")
	_ko(cut_in, &"punk")
	CombatEvents.level_cleared.emit(_node())
	assert_eq(cut_in.history.size(), 0)
	assert_eq(TimeController.sim_scale(), 1.0)


func test_a_card_goes_down_when_the_profile_flips_to_m6() -> void:
	var cut_in := _cut_in()
	_enemy(&"punk")
	Tuning.set_value(&"look_profile", 0)
	cut_in.advance(0.016)
	assert_false(cut_in.is_showing())
	assert_eq(TimeController.sim_scale(), 1.0)


func test_a_card_with_no_texture_is_skipped_silently() -> void:
	var cut_in := _cut_in()
	_enemy(&"thug")
	assert_false(cut_in.is_showing(), "the thug's entry has no art yet")
	assert_eq(cut_in.history.size(), 0)
	var bare := CutInSet.new()
	var empty := _cut_in(true, true, bare)
	empty.advance(0.0)
	_enemy(&"bruiser")
	CombatEvents.level_cleared.emit(_node())
	assert_eq(empty.history.size(), 0, "a set with nothing in it shows nothing")


# --- Presentation only -----------------------------------------------------------------------------------------


func test_the_cards_write_no_game_state() -> void:
	var source := FileAccess.get_file_as_string(CUT_IN_SCRIPT)
	for forbidden: String in ["Tuning.set_value", ".emit(", "health =", "global_position =", "velocity =", "GameInput.set_paused", "queue_free"]:
		# card_started and card_ended are the node's own signals, the one allowed emit.
		var text := source.replace("card_started.emit(", "").replace("card_ended.emit(", "")
		assert_false(text.contains(forbidden), "cut_in.gd must not contain %s" % forbidden)
	var cut_in := _cut_in()
	var before := Tuning.data.duplicate()
	var enemy := _enemy(&"punk")
	var health := enemy.health
	cut_in.advance(5.0)
	CombatEvents.level_cleared.emit(_node())
	cut_in.skip()
	assert_eq(enemy.health, health)
	for prop in before.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			assert_eq(Tuning.data.get(prop.name), before.get(prop.name), "tuning %s unchanged" % prop.name)


func test_simulation_code_does_not_read_the_cards() -> void:
	for dir: String in ["res://game/combat", "res://game/actors", "res://game/enemies", "res://game/player"]:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				var source := FileAccess.get_file_as_string(dir.path_join(file))
				assert_false(source.contains("CutIn"), "%s reads the cards" % file)


# --- The shipped data ----------------------------------------------------------------------------------------


func test_the_shipped_set_has_the_five_placeholder_cards() -> void:
	var set := load(CutIn.DEFAULT_SET) as CutInSet
	assert_not_null(set)
	assert_not_null(set.title.pick(), "title")
	assert_not_null(set.entrance_for(&"punk").pick(), "punk entrance")
	assert_not_null(set.ko_for(&"punk").pick(0), "ko_punk_1")
	assert_not_null(set.ko_for(&"punk").pick(1), "ko_punk_2")
	assert_ne(set.ko_for(&"punk").pick(0), set.ko_for(&"punk").pick(1))
	assert_not_null(set.mission_end.pick(), "mission end")
	for texture: Texture2D in [set.title.pick(), set.mission_end.pick()]:
		assert_eq(texture.get_size(), Vector2(1600, 900), "cards are 1600x900")
	for key: StringName in [&"thug", &"bruiser", &"kicker", &"boss"]:
		assert_not_null(set.entrance_for(key), "%s has an entry for the art that comes next" % key)
		assert_null(set.entrance_for(key).pick(), "%s has no art yet" % key)


func test_an_entry_picks_in_turn_and_wraps() -> void:
	var entry := CutInEntry.new()
	var a := ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	var b := ImageTexture.create_from_image(Image.create(3, 3, false, Image.FORMAT_RGBA8))
	entry.textures = [a, null, b]
	assert_eq(entry.pick(0), a)
	assert_eq(entry.pick(1), b)
	assert_eq(entry.pick(2), a, "wraps")
	assert_null(CutInEntry.new().pick(), "no art, no card")


func test_the_group_is_declared_before_debug() -> void:
	var groups: Array[String] = []
	for info in Tuning.data.get_property_list():
		if info.usage & PROPERTY_USAGE_GROUP:
			groups.append(info.name)
	assert_true(groups.has("Cut-ins (M7)"))
	assert_eq(groups.back(), "Debug", "Debug stays last")
	assert_eq(groups[groups.size() - 2], "Cut-ins (M7)")


# --- In the game ---------------------------------------------------------------------------------------------


func _hud_of(level: Node) -> GameHud:
	return level.find_children("*", "GameHud", true, false)[0] as GameHud


func test_mission_1_under_the_trailer_profile_opens_on_the_title_and_holds() -> void:
	Tuning.set_value(&"waves_enabled", false)
	Tuning.set_value(&"look_profile", 1)
	var level := (load(LEVEL_PATH) as PackedScene).instantiate()
	level.set(&"waves_enabled_on_start", false)
	add_child_autofree(level)
	await get_tree().physics_frame
	var cut_in := _hud_of(level).cut_in
	assert_eq(cut_in.history[0].kind, CutIn.Kind.TITLE, "the first card is the mission title")
	assert_eq(TimeController.sim_scale(), 0.0, "the street holds while it is up")
	cut_in.skip()
	assert_eq(TimeController.sim_scale(), 1.0)


func test_mission_1_under_m6_shows_no_card() -> void:
	Tuning.set_value(&"waves_enabled", false)
	var level := (load(LEVEL_PATH) as PackedScene).instantiate()
	level.set(&"waves_enabled_on_start", false)
	add_child_autofree(level)
	await get_tree().physics_frame
	var cut_in := _hud_of(level).cut_in
	assert_eq(cut_in.history.size(), 0)
	assert_false(cut_in.visible)
	assert_eq(TimeController.sim_scale(), 1.0)
