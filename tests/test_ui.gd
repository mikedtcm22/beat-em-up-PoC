extends GutTest
## HUD, combat log, over-head bars, overlays and debug draw (game/ui/). Fake actors extend
## the CombatActor / PlayerCharacter API and override every callback and every method the
## HUD reads, so they need no rig and stay inert next to the real implementations. HUD time
## is driven by calling GameHud.advance() with chosen deltas (processing is turned off).

const HUD_SCENE := preload("res://game/ui/hud.tscn")


class FakeEnemy:
	extends CombatActor
	var head_top: Vector3 = Vector3(0.0, 2.0, -4.0)
	var state_text: String = "FAKE ENEMY STATE"

	func _init() -> void:
		add_to_group(&"actor")
		add_to_group(&"enemy")
		display_name = "Fake Enemy"
		max_health = 30.0
		health = 30.0

	func _ready() -> void:
		pass

	func _physics_process(_delta: float) -> void:
		pass

	func get_head_top_position() -> Vector3:
		return head_top

	func get_chest_position() -> Vector3:
		return head_top - Vector3(0.0, 0.7, 0.0)

	func debug_state_text() -> String:
		return state_text


class FakePlayer:
	extends PlayerCharacter
	var weapon: bool = false
	var durability: int = 0
	var cone: Dictionary = {}

	func _init() -> void:
		add_to_group(&"actor")
		add_to_group(&"player")
		display_name = "Player"
		team = 0
		max_health = 100.0
		health = 100.0

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func _physics_process(_delta: float) -> void:
		pass

	func _unhandled_input(_event: InputEvent) -> void:
		pass

	func get_head_top_position() -> Vector3:
		return global_position + Vector3.UP * 2.0

	func get_chest_position() -> Vector3:
		return global_position + Vector3.UP * 1.3

	func get_eye_transform() -> Transform3D:
		return Transform3D(Basis(), global_position + Vector3.UP * standing_eye_height)

	func debug_state_text() -> String:
		return "FAKE PLAYER STATE"

	func holding_weapon() -> bool:
		return weapon

	func weapon_durability_left() -> int:
		return durability

	func get_magnetism_cone() -> Dictionary:
		return cone


class FakeRig:
	extends HumanoidRig
	var boxes: Array[Hurtbox] = []

	func _ready() -> void:
		pass

	func get_hurtboxes() -> Array[Hurtbox]:
		return boxes


class FakeDirector:
	extends Node
	@warning_ignore("unused_signal")
	signal camera_changed(mode: StringName)
	var mode: StringName = &"first_person"

	func _init() -> void:
		add_to_group(&"camera_director")


var _hud: GameHud
var _camera: Camera3D
var _saved_center_dot: bool


func before_each() -> void:
	_saved_center_dot = Tuning.data.show_center_dot
	# Camera at the origin looking down -Z, so enemies at negative z are in front of it.
	_camera = Camera3D.new()
	add_child_autofree(_camera)
	_camera.make_current()
	_hud = HUD_SCENE.instantiate() as GameHud
	add_child_autofree(_hud)
	_hud.set_process(false)


func after_each() -> void:
	Tuning.data.show_center_dot = _saved_center_dot


func _spawn_enemy(head_top: Vector3 = Vector3(0.0, 2.0, -4.0)) -> FakeEnemy:
	var enemy := FakeEnemy.new()
	enemy.head_top = head_top
	add_child_autofree(enemy)
	enemy.global_position = Vector3(head_top.x, 0.0, head_top.z)
	return enemy


func _spawn_player() -> FakePlayer:
	var player := FakePlayer.new()
	add_child_autofree(player)
	return player


func _make_move(id: StringName, display_name: String) -> MoveData:
	var move := MoveData.new()
	move.id = id
	move.display_name = display_name
	return move


func _make_hit(attacker: Node3D, victim: Node3D, move: MoveData, frame: int) -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = attacker
	hit.victim = victim
	hit.move = move
	hit.damage = 6.0
	hit.tier = CombatTypes.HitTier.HEAVY
	hit.reaction = CombatTypes.Reaction.STAGGER
	hit.region = CombatTypes.Region.HEAD
	hit.physics_frame = frame
	hit.move_frame = 5
	hit.chain_step = 2
	hit.input_timing = &"chain"
	return hit


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


# --- Scene -------------------------------------------------------------------------------


func test_hud_scene_instantiates_with_every_part() -> void:
	assert_not_null(_hud, "hud.tscn root is a GameHud")
	assert_eq(_hud.process_mode, Node.PROCESS_MODE_ALWAYS, "HUD runs while paused")
	assert_not_null(_hud.player_panel)
	assert_not_null(_hud.boss_bar)
	assert_not_null(_hud.enemy_bars)
	assert_not_null(_hud.center_dot)
	assert_not_null(_hud.combat_log)
	assert_not_null(_hud.camera_toast)
	assert_not_null(_hud.help_overlay)
	assert_not_null(_hud.pause_overlay)
	assert_not_null(_hud.debug_draw)
	assert_true(_hud.is_combat_log_visible(), "combat log visible by default")
	assert_false(_hud.boss_bar.visible, "boss bar hidden until show_boss")
	assert_false(_hud.pause_overlay.visible)
	assert_false(_hud.debug_draw.enabled, "debug draw off by default")
	# Both process after the camera director and its cameras (CameraDirector.PROCESS_PRIORITY
	# is 50), so projections use the view of the frame being drawn.
	assert_eq(_hud.process_priority, HudStyle.PROCESS_PRIORITY)
	assert_eq(_hud.debug_draw.process_priority, HudStyle.PROCESS_PRIORITY)
	assert_gt(HudStyle.PROCESS_PRIORITY, 50, "after the camera director")
	# A frame of real processing with nothing in the world must not error either.
	_hud.set_process(true)
	await wait_physics_frames(2)
	_hud.set_process(false)


func test_hud_stays_out_of_the_top_corners() -> void:
	await wait_process_frames(2)  # let the help panel grow to fit its content
	var screen := _hud.get_viewport().get_visible_rect().size
	var corner := Vector2(screen.x * 0.2, screen.y * 0.2)
	var corners: Array[Rect2] = [
		Rect2(Vector2.ZERO, corner),
		Rect2(Vector2(screen.x - corner.x, 0.0), corner),
	]
	var parts: Array[Control] = [_hud.player_panel, _hud.boss_bar, _hud.combat_log, _hud.camera_toast,
			_hud.help_overlay]
	for part: Control in parts:
		for rect: Rect2 in corners:
			assert_false(part.get_global_rect().intersects(rect), "%s clear of top corners" % part.name)


# --- Player panel ---------------------------------------------------------------------------


func test_player_panel_reads_the_player_and_weapon_durability() -> void:
	var player := _spawn_player()
	player.health = 40.0
	_hud.advance(0.016)
	assert_true(_hud.player_panel.visible)
	assert_eq(_hud.player_panel.player, player)
	assert_almost_eq(_hud.player_panel.gauge.value, 0.4, 0.001)
	assert_eq(_hud.player_panel.pips_total, 0, "no pips without a weapon")

	player.weapon = true
	player.durability = 5
	_hud.advance(0.016)
	assert_eq(_hud.player_panel.pips_filled, 5)
	assert_eq(_hud.player_panel.pips_total, maxi(Tuning.data.weapon_durability, 5))

	# health_changed reacts immediately, with a damage ghost behind the new value.
	player.health = 25.0
	CombatEvents.health_changed.emit(player, 25.0, 100.0)
	assert_almost_eq(_hud.player_panel.gauge.value, 0.25, 0.001)
	assert_almost_eq(_hud.player_panel.gauge.ghost, 0.4, 0.001)


func test_guard_meter_shows_while_blocking_or_below_full_and_flashes_on_a_break() -> void:
	var player := _spawn_player()
	_hud.advance(0.016)
	assert_false(_hud.player_panel.guard_shown, "full guard, not blocking: hidden")
	player.state = CombatTypes.ActorState.BLOCK
	_hud.advance(0.016)
	assert_true(_hud.player_panel.guard_shown, "shown while blocking")
	assert_almost_eq(_hud.player_panel.guard_gauge.value, 1.0, 0.001)
	player.state = CombatTypes.ActorState.FREE
	player.guard = player.max_guard() * 0.4
	_hud.advance(0.016)
	assert_true(_hud.player_panel.guard_shown, "shown below full")
	assert_almost_eq(_hud.player_panel.guard_gauge.value, 0.4, 0.001)
	player.guard = player.max_guard()
	_hud.advance(0.016)
	assert_false(_hud.player_panel.guard_shown, "hidden again when full")
	# A guard break flashes the meter (and pops the callout) for the player only.
	player.guard = 0.0
	CombatEvents.guard_broken.emit(_spawn_enemy(), HitInfo.new())
	assert_eq(_hud.player_panel.guard_flash_left, 0.0, "another actor's guard break: no flash")
	CombatEvents.guard_broken.emit(player, HitInfo.new())
	assert_gt(_hud.player_panel.guard_flash_left, 0.0, "flashing")
	assert_true(_hud.block_callout.visible)
	assert_eq(_hud.block_callout.text, "GUARD BREAK!")
	player.guard = player.max_guard()
	_hud.advance(0.016)
	assert_true(_hud.player_panel.guard_shown, "shown while it flashes")
	_hud.advance(_hud.player_panel.guard_break_flash_s)
	_hud.advance(1.0)
	assert_false(_hud.player_panel.guard_shown)
	assert_false(_hud.block_callout.visible, "the callout fades")


func test_perfect_block_pops_a_parry_callout_for_the_player() -> void:
	var player := _spawn_player()
	var enemy := _spawn_enemy()
	_hud.advance(0.016)
	CombatEvents.perfect_blocked.emit(enemy, HitInfo.new())
	assert_false(_hud.block_callout.visible, "not for other actors")
	CombatEvents.perfect_blocked.emit(player, HitInfo.new())
	assert_true(_hud.block_callout.visible)
	assert_eq(_hud.block_callout.text, "PARRY!")
	var screen := _hud.get_viewport().get_visible_rect().size
	var rect := _hud.block_callout.get_global_rect()
	assert_gt(rect.position.y, screen.y * 0.5, "below the view center")
	assert_almost_eq(rect.get_center().x, screen.x * 0.5, 1.0, "centered")
	_hud.advance(_hud.block_callout.show_seconds + 0.1)
	assert_false(_hud.block_callout.visible)


func test_player_panel_hides_without_a_player() -> void:
	_hud.advance(0.016)
	assert_false(_hud.player_panel.visible)


# --- Combat log ---------------------------------------------------------------------------


func test_combat_log_keeps_the_last_ten_hits_with_timing() -> void:
	var player := _spawn_player()
	var enemy := _spawn_enemy()
	var move := _make_move(&"jab_2", "Jab 2")
	for i: int in 12:
		CombatEvents.hit_landed.emit(_make_hit(player, enemy, move, 100 + i * 7))
	assert_eq(_hud.combat_log.entry_count(), 10, "only the last 10 entries")
	var lines := _hud.combat_log.get_lines()
	assert_true(lines[0].begins_with("f114 "), "oldest kept is the third hit: %s" % lines[0])
	var newest := lines[9]
	assert_true(newest.begins_with("f177 +7 "), "frame and frames since previous: %s" % newest)
	for part: String in ["Player > Fake Enemy", "Jab 2", "#2 chain", "6 dmg", "HEAVY", "STAGGER", "HEAD", "mf5"]:
		assert_string_contains(newest, part)


func test_combat_log_records_whiffs_with_chain_step_and_timing() -> void:
	var player := _spawn_player()
	var move := _make_move(&"hook", "Hook")
	CombatEvents.attack_started.emit(player, move, 3, &"pause")
	player.move_frame = 9
	CombatEvents.attack_whiffed.emit(player, move)
	assert_eq(_hud.combat_log.entry_count(), 1)
	var line := _hud.combat_log.get_lines()[0]
	for part: String in ["Player", "Hook", "#3 pause", "WHIFF", "mf9"]:
		assert_string_contains(line, part)


func test_combat_log_visibility_toggle() -> void:
	_hud.set_combat_log_visible(false)
	assert_false(_hud.is_combat_log_visible())
	CombatEvents.attack_whiffed.emit(_spawn_player(), _make_move(&"jab_1", "Jab 1"))
	assert_eq(_hud.combat_log.entry_count(), 1, "still records while hidden")
	_hud.set_combat_log_visible(true)
	assert_true(_hud.combat_log.visible)


func test_combat_log_flags_blocked_perfect_and_guard_break_hits() -> void:
	var player := _spawn_player()
	var enemy := _spawn_enemy()
	var move := _make_move(&"dummy_jab", "Sparring Jab")
	var cases := [
		["blocked", ["0.9 chip", "BLOCKED"], ["PERFECT", "GUARD BREAK", " dmg"]],
		["perfect", ["0 chip", "PERFECT"], ["BLOCKED", "GUARD BREAK"]],
		["broken", ["0.9 chip", "BLOCKED GUARD BREAK"], ["PERFECT"]],
		["clean", ["6 dmg"], ["chip", "BLOCKED", "PERFECT", "GUARD BREAK"]],
	]
	for row: Array in cases:
		var hit := _make_hit(enemy, player, move, 200)
		hit.blocked = row[0] != "clean"
		hit.perfect_block = row[0] == "perfect"
		hit.guard_broken = row[0] == "broken"
		hit.damage = 0.0 if hit.perfect_block else (6.0 if not hit.blocked else 0.9)
		CombatEvents.hit_landed.emit(hit)
		var line: String = _hud.combat_log.get_lines()[-1]
		for part: String in row[1]:
			assert_string_contains(line, part)
		for part: String in row[2]:
			assert_false(line.contains(part), "%s: no '%s' in %s" % [row[0], part, line])


func test_combat_log_body_impacts_flags_and_line_fitting() -> void:
	var enemy := _spawn_enemy()
	var hit := _make_hit(null, enemy, null, 50)
	hit.is_body_impact = true
	hit.from_behind = true
	hit.killed = true
	CombatEvents.hit_landed.emit(hit)
	var line := _hud.combat_log.get_lines()[0]
	for part: String in ["f50 +--", "? > Fake Enemy", "body", "BEHIND", "BODY", "KO"]:
		assert_string_contains(line, part)
	var combat_log := _hud.combat_log
	var font := HudStyle.regular_font()
	assert_eq(combat_log.fit_font_size(font, line, 2000.0), combat_log.font_size, "a line that fits keeps the size")
	assert_eq(combat_log.fit_font_size(font, "x".repeat(400), 700.0), combat_log.min_font_size,
			"an overlong line shrinks, down to the minimum")


# --- Enemy bars ---------------------------------------------------------------------------


func test_enemy_bar_appears_on_hit_and_expires_after_two_seconds() -> void:
	var player := _spawn_player()
	var enemy := _spawn_enemy()
	enemy.health = 24.0
	CombatEvents.hit_landed.emit(_make_hit(player, enemy, _make_move(&"jab_1", "Jab 1"), 10))
	_hud.advance(0.016)
	assert_eq(_hud.enemy_bars.bar_count(), 1)
	assert_eq(_hud.enemy_bars.visible_bar_count(), 1, "enemy in front of the camera")
	var screen := _hud.get_viewport().get_visible_rect().size
	var anchor := _hud.enemy_bars.get_bar_screen_position(enemy)
	assert_almost_eq(anchor.x, screen.x * 0.5, 1.0, "straight ahead projects to the center")
	assert_lt(anchor.y, screen.y * 0.5, "head top is above the horizon")
	_hud.advance(1.0)
	assert_eq(_hud.enemy_bars.bar_count(), 1, "still up after 1 s")
	_hud.advance(1.0)
	assert_eq(_hud.enemy_bars.bar_count(), 0, "gone after 2 s")


func test_enemy_bar_time_holds_while_paused() -> void:
	var enemy := _spawn_enemy()
	CombatEvents.hit_landed.emit(_make_hit(_spawn_player(), enemy, _make_move(&"jab_1", "Jab 1"), 10))
	get_tree().paused = true
	_hud.advance(5.0)
	get_tree().paused = false
	assert_eq(_hud.enemy_bars.bar_count(), 1, "a pause does not use up the 2 s")
	_hud.advance(2.1)
	assert_eq(_hud.enemy_bars.bar_count(), 0)


func test_enemy_bar_from_health_drop_and_not_for_player_hits() -> void:
	var player := _spawn_player()
	var enemy := _spawn_enemy()
	CombatEvents.hit_landed.emit(_make_hit(enemy, player, _make_move(&"jab_1", "Jab 1"), 10))
	_hud.advance(0.016)
	assert_eq(_hud.enemy_bars.bar_count(), 0, "the player gets no over-head bar")
	enemy.health = 20.0
	CombatEvents.health_changed.emit(enemy, 20.0, 30.0)
	_hud.advance(0.016)
	assert_true(_hud.enemy_bars.has_bar(enemy))
	_hud.advance(2.1)
	assert_false(_hud.enemy_bars.has_bar(enemy), "expired")
	CombatEvents.health_changed.emit(enemy, 20.0, 30.0)
	_hud.advance(0.016)
	assert_false(_hud.enemy_bars.has_bar(enemy), "a repeat of the same health is not a hit")
	enemy.health = 30.0
	CombatEvents.health_changed.emit(enemy, 30.0, 30.0)
	_hud.advance(0.016)
	assert_false(_hud.enemy_bars.has_bar(enemy), "nor is a revive")
	enemy.health = 25.0
	CombatEvents.health_changed.emit(enemy, 25.0, 30.0)
	_hud.advance(0.016)
	assert_true(_hud.enemy_bars.has_bar(enemy), "a new drop is")


func test_enemy_bar_hidden_behind_camera_and_dropped_when_freed() -> void:
	var player := _spawn_player()
	var behind := _spawn_enemy(Vector3(0.0, 2.0, 4.0))
	var doomed := FakeEnemy.new()
	add_child(doomed)
	var move := _make_move(&"jab_1", "Jab 1")
	CombatEvents.hit_landed.emit(_make_hit(player, behind, move, 10))
	CombatEvents.hit_landed.emit(_make_hit(player, doomed, move, 11))
	_hud.advance(0.016)
	assert_eq(_hud.enemy_bars.bar_count(), 2)
	assert_eq(_hud.enemy_bars.visible_bar_count(), 1, "the one behind the camera is not drawn")
	doomed.free()
	_hud.advance(0.016)
	assert_eq(_hud.enemy_bars.bar_count(), 1, "freed actor's bar is dropped")


# --- Boss bar, overlays -------------------------------------------------------------------


func test_show_boss_reveals_the_boss_bar() -> void:
	var boss := _spawn_enemy()
	boss.display_name = "Boss"
	assert_false(_hud.boss_bar.visible)
	_hud.show_boss(boss)
	_hud.advance(0.016)
	assert_true(_hud.boss_bar.visible)
	assert_eq(_hud.boss_bar.boss, boss)
	_hud.hide_boss()
	assert_false(_hud.boss_bar.visible)


func test_help_overlay_shows_at_start_then_toggles_with_h() -> void:
	assert_true(_hud.help_overlay.visible, "visible at start")
	_hud.advance(_hud.help_startup_seconds - 0.1)
	assert_true(_hud.help_overlay.visible)
	_hud.advance(0.2)
	assert_false(_hud.help_overlay.visible, "auto-hidden after the startup seconds")
	_hud._unhandled_input(_action_event(&"help"))
	assert_true(_hud.help_overlay.visible, "H shows it")
	_hud.advance(30.0)
	assert_true(_hud.help_overlay.visible, "no auto-hide after a manual toggle")
	_hud._unhandled_input(_action_event(&"help"))
	assert_false(_hud.help_overlay.visible, "H hides it")


func test_help_startup_time_holds_while_paused() -> void:
	_hud.advance(_hud.help_startup_seconds - 1.0)
	get_tree().paused = true
	_hud.advance(5.0)
	get_tree().paused = false
	assert_true(_hud.help_overlay.visible, "a pause does not use up the startup seconds")
	_hud.advance(1.1)
	assert_false(_hud.help_overlay.visible)


func test_help_overlay_lists_controls_from_bindings() -> void:
	assert_eq(HelpOverlay.binding_text([&"move_forward", &"move_left", &"move_back", &"move_right"], false), "W A S D")
	assert_eq(HelpOverlay.binding_text([&"punch"], false), "Left mouse")
	assert_eq(HelpOverlay.binding_text([&"punch"], true), "X")
	assert_eq(HelpOverlay.binding_text([&"back_attack"], true), "RB")
	assert_eq(HelpOverlay.binding_text([&"look_left", &"look_right"], true), "Right stick")
	assert_eq(HelpOverlay.binding_text([&"pause"], false), "Esc")
	assert_eq(HelpOverlay.binding_text([&"debug_draw"], false), "F3")


func test_help_overlay_shows_controls_and_debug_keys() -> void:
	var texts := PackedStringArray()
	for node: Node in _hud.help_overlay.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	for expected: String in ["GAMEPAD", "KEYBOARD + MOUSE", "Left stick", "W A S D", "Mouse", "Left mouse",
			"Right mouse", "RB", "Q", "LB", "E", "F1", "F2", "F3", "F4", "F5", "H", "Esc", "R", "Menu", "View",
			"Restart (while paused)", "Block (hold, no direction)", "Dodge (with a direction)",
			"Sparring dummies on / off"]:
		assert_has(texts, expected, "help lists %s" % expected)


func test_pause_overlay_follows_game_input() -> void:
	assert_false(_hud.pause_overlay.visible)
	GameInput.paused_changed.emit(true)
	assert_true(_hud.pause_overlay.visible)
	GameInput.paused_changed.emit(false)
	assert_false(_hud.pause_overlay.visible)


func test_camera_toast_shows_mode_then_fades() -> void:
	var director := FakeDirector.new()
	add_child_autofree(director)
	_hud.advance(0.016)
	director.camera_changed.emit(&"side_view")
	assert_true(_hud.camera_toast.visible)
	assert_string_contains(_hud.camera_toast.text, "SIDE VIEW")
	_hud.advance(1.0)
	assert_true(_hud.camera_toast.visible)
	_hud.advance(0.6)
	assert_false(_hud.camera_toast.visible, "gone after about 1.5 s")


func test_center_dot_rule() -> void:
	Tuning.data.show_center_dot = true
	_hud.advance(0.0)
	assert_true(_hud.center_dot.visible, "shown with no director")
	var director := FakeDirector.new()
	add_child_autofree(director)
	_hud.advance(0.0)
	assert_true(_hud.center_dot.visible, "shown in first person")
	director.mode = &"side_view"
	_hud.advance(0.0)
	assert_false(_hud.center_dot.visible, "hidden in side view")
	director.mode = &"free_fly"
	_hud.advance(0.0)
	assert_false(_hud.center_dot.visible, "hidden in free fly")
	director.mode = &"first_person"
	Tuning.data.show_center_dot = false
	_hud.advance(0.0)
	assert_false(_hud.center_dot.visible, "hidden when the option is off")


# --- Debug draw ---------------------------------------------------------------------------


func test_debug_draw_joins_its_group_and_loads_standalone() -> void:
	assert_true(_hud.debug_draw.is_in_group(&"debug_draw"), "a level can find the HUD's debug draw")
	var standalone := (load("res://game/ui/debug_draw.tscn") as PackedScene).instantiate() as CombatDebugDraw
	assert_not_null(standalone, "debug_draw.tscn root is a CombatDebugDraw")
	add_child_autofree(standalone)
	assert_true(standalone.is_in_group(&"debug_draw"))
	assert_eq(standalone.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_false(standalone.enabled)


func test_debug_draw_toggles_with_its_action() -> void:
	var draw := _hud.debug_draw
	assert_false(draw.enabled)
	draw._unhandled_input(_action_event(&"debug_draw"))
	assert_true(draw.enabled)
	draw._unhandled_input(_action_event(&"debug_draw"))
	assert_false(draw.enabled)


func test_debug_draw_builds_hitboxes_hurtboxes_cone_and_labels() -> void:
	var draw := _hud.debug_draw
	var enemy := _spawn_enemy(Vector3(0.0, 2.0, -3.0))
	enemy.debug_hitbox_volumes = [
		{kind = &"sphere", center = Vector3(0.0, 1.5, -3.0), radius = 0.12},
	]
	draw.enabled = true
	draw.rebuild()
	assert_eq(draw.line_count, 3 * CombatDebugDraw.CIRCLE_SEGMENTS, "sphere = three circles")
	assert_eq(draw.get_mesh().get_surface_count(), 1)
	assert_eq(draw.get_label_count(), 1)
	assert_eq(draw.get_label(enemy).text, "FAKE ENEMY STATE")
	assert_eq(draw.get_label(enemy).layers, CombatTypes.bit(CombatTypes.VIS_DEBUG))
	assert_true(draw.get_label(enemy).no_depth_test)
	assert_eq(draw.get_label(enemy).billboard, BaseMaterial3D.BILLBOARD_ENABLED)
	var lines := draw.get_node(^"Lines") as MeshInstance3D
	assert_eq(lines.layers, CombatTypes.bit(CombatTypes.VIS_DEBUG), "lines on the debug render layer")
	var material := draw.get_mesh().surface_get_material(0) as StandardMaterial3D
	assert_true(material.no_depth_test, "lines show through bodies")
	assert_eq(material.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_true(material.vertex_color_use_as_albedo and material.vertex_color_is_srgb, "line colors shown as authored")
	assert_eq(draw.count_lines_of_color(draw.hitbox_color), draw.line_count, "hitbox lines are all hitbox-colored")
	var sphere_lines := draw.line_count

	enemy.debug_hitbox_volumes.append({
		kind = &"arc", origin = Vector3(0.0, 0.0, -3.0), forward = Vector3.FORWARD,
		radius = 1.9, half_angle_deg = 75.0, h_min = 0.3, h_max = 1.8,
	})
	draw.rebuild()
	var arc_lines := draw.line_count - sphere_lines
	assert_gt(arc_lines, 0, "arc outline drawn")
	var bounds := draw.get_mesh().get_aabb().grow(0.01)
	assert_true(bounds.has_point(Vector3(0.0, 1.8, -4.9)), "arc reaches its radius ahead at h_max")
	assert_true(bounds.has_point(Vector3(0.0, 0.3, -4.9)), "and at h_min")
	assert_almost_eq(bounds.end.y, 1.8 + 0.01, 0.001, "nothing above h_max")

	# Hurtboxes: a head sphere and a torso capsule CollisionShape3D on a fake rig.
	var rig := FakeRig.new()
	enemy.add_child(rig)
	enemy.rig = rig
	var head := SphereShape3D.new()
	head.radius = 0.12
	var torso := CapsuleShape3D.new()
	torso.radius = 0.15
	torso.height = 0.6
	rig.boxes.append(_make_hurtbox(rig, head, Vector3(0.0, 1.6, 0.0)))
	rig.boxes.append(_make_hurtbox(rig, torso, Vector3(0.0, 0.9, 0.0)))
	draw.rebuild()
	assert_gt(draw.line_count, sphere_lines + arc_lines, "hurtboxes drawn")
	assert_eq(draw.count_lines_of_color(draw.hitbox_color), sphere_lines + arc_lines, "arc lines are hitbox-colored")
	assert_eq(draw.count_lines_of_color(draw.hurtbox_color), draw.line_count - sphere_lines - arc_lines,
			"hurtbox lines are hurtbox-colored")
	var with_hurtboxes := draw.line_count

	# A hurtbox around the camera (the player's own head in first person) is skipped.
	_camera.global_position = rig.boxes[0].global_position
	draw.rebuild()
	assert_eq(draw.line_count, with_hurtboxes - 3 * CombatDebugDraw.CIRCLE_SEGMENTS, "sphere hugging the camera skipped")
	_camera.global_position = Vector3.ZERO

	# The player's magnetism cone, aimed at the enemy.
	var player := _spawn_player()
	player.cone = {
		origin = Vector3(0.0, 1.3, 0.0), forward = Vector3.FORWARD,
		half_angle_deg = 35.0, range = 2.5, target = enemy,
	}
	draw.rebuild()
	assert_gt(draw.line_count, with_hurtboxes, "cone and target marker drawn")
	var cone_lines := draw.count_lines_of_color(draw.cone_color)
	var target_lines := draw.count_lines_of_color(draw.target_color)
	assert_gt(cone_lines, 0, "cone lines are cone-colored")
	assert_gt(target_lines, 0, "the target is highlighted")
	assert_eq(with_hurtboxes + cone_lines + target_lines, draw.line_count, "nothing else drawn")
	# Spec §11 colors: red hitboxes, green hurtboxes, a yellow cone.
	assert_true(draw.hitbox_color.h < 0.03 or draw.hitbox_color.h > 0.97, "hitboxes red")
	assert_between(draw.hurtbox_color.h, 0.25, 0.45, "hurtboxes green")
	assert_between(draw.cone_color.h, 0.11, 0.19, "cone yellow")
	assert_eq(draw.get_label_count(), 2, "one state label per actor")

	draw.enabled = false
	assert_eq(draw.line_count, 0)
	assert_eq(draw.get_mesh().get_surface_count(), 0)
	assert_eq(draw.get_label_count(), 0)


func test_debug_draw_shows_the_block_arc_while_guarding() -> void:
	var draw := _hud.debug_draw
	var player := _spawn_player()
	draw.enabled = true
	draw.rebuild()
	assert_eq(draw.count_lines_of_color(draw.block_color), 0, "no arc while not blocking")
	player.state = CombatTypes.ActorState.BLOCK
	player.look_yaw = 0.0
	draw.rebuild()
	var dim := Color(draw.block_color, 0.35)
	assert_gt(draw.count_lines_of_color(dim), 0, "a dim arc while the guard rises")
	var arc := player.get_block_arc()
	assert_eq(arc.get("half_angle_deg"), Tuning.data.block_arc_half_angle_deg)
	assert_almost_eq(arc.get("forward") as Vector3, Vector3.FORWARD, Vector3.ONE * 0.001, "faces the look")
	player._guard_frames = Tuning.data.block_raise_frames
	draw.rebuild()
	assert_gt(draw.count_lines_of_color(draw.block_color), 0, "cyan once the guard is up")
	assert_between(draw.block_color.h, 0.45, 0.55, "cyan")
	var bounds := draw.get_mesh().get_aabb().grow(0.01)
	var reach := draw.block_arc_radius
	assert_true(bounds.has_point(Vector3(0.0, draw.block_arc_heights.y, -reach)), "reaches ahead of the look")
	assert_false(bounds.has_point(Vector3(0.0, draw.block_arc_heights.y, reach * 0.9)), "nothing behind")


func test_debug_draw_survives_freed_actors_and_full_circle_arcs() -> void:
	var draw := _hud.debug_draw
	var doomed := FakeEnemy.new()
	add_child(doomed)
	doomed.debug_hitbox_volumes = [
		{kind = &"arc", origin = Vector3.ZERO, forward = Vector3.ZERO, radius = 1.8,
			half_angle_deg = 180.0, h_min = 0.0, h_max = 1.9},
	]
	var player := _spawn_player()
	player.cone = {origin = Vector3.ZERO, forward = Vector3.FORWARD, half_angle_deg = 35.0,
			range = 2.5, target = doomed}
	draw.enabled = true
	draw.rebuild()
	assert_gt(draw.line_count, 0)
	assert_eq(draw.get_label_count(), 2)
	doomed.free()
	draw.rebuild()
	assert_eq(draw.get_label_count(), 1, "label of the freed actor removed")


func _make_hurtbox(rig: Node3D, shape: Shape3D, local_position: Vector3) -> Hurtbox:
	var hurtbox := Hurtbox.new()
	var collision := CollisionShape3D.new()
	collision.shape = shape
	hurtbox.add_child(collision)
	hurtbox.position = local_position
	rig.add_child(hurtbox)
	return hurtbox
