extends GutTest
## The warning oracle (tests/bot/warning_oracle.gd, Milestone 3 metric R10): it must say the widget
## is right when it is, and say exactly what is wrong when it is not. A stand-in widget with
## controllable faults (a mirrored side, a late show, a lingering burst, a burst nobody asked for)
## is wound up against stub enemies placed at hand-computed bearings in a small code-built arena.

const Oracle := preload("res://tests/bot/warning_oracle.gd")
const STUB_ENEMY := preload("res://tests/fixtures/stub_enemy.tscn")

## What the rear warning does, in a test double with the faults of a bad one. It answers
## corner_state(side) the way RearWarning does, from its own entries (the rule of Part B §B1.3).
class FakeWidget:
	extends Node
	var player: Node3D
	## Frames after a wind-up starts before it shows; frames after it ends before it goes.
	var lag: int = 0
	var end_lag: int = 0
	## Light the opposite corner.
	var mirror: bool = false
	## Light this side whatever happens (&"" = off).
	var always: StringName = &""
	## Ignore the attacker's `heavy`.
	var ignore_heavy: bool = false
	var _entries: Array[Dictionary] = []

	func _ready() -> void:
		CombatEvents.windup_started.connect(_on_windup_started)
		CombatEvents.windup_ended.connect(_on_windup_ended)
		CombatEvents.hit_landed.connect(_on_hit)
		CombatEvents.attack_whiffed.connect(_on_whiff)

	func _exit_tree() -> void:
		CombatEvents.windup_started.disconnect(_on_windup_started)
		CombatEvents.windup_ended.disconnect(_on_windup_ended)
		CombatEvents.hit_landed.disconnect(_on_hit)
		CombatEvents.attack_whiffed.disconnect(_on_whiff)

	func _on_windup_started(attacker: Node3D, move: MoveData) -> void:
		var bearing := ViewGeometry.bearing_deg(player.look_yaw, player.global_position, attacker.global_position)
		var flat := Vector2(attacker.global_position.x - player.global_position.x, attacker.global_position.z - player.global_position.z)
		var t := Tuning.data
		var corner := ViewGeometry.warning_corner(bearing, flat.length(), move.reach_m, t.rear_warning_angle_deg,
				t.rear_warning_behind_deg, t.rear_warning_range_margin_m)
		if corner == &"":
			return
		var sides: Array[StringName] = []
		if corner == &"both":
			sides.append_array([&"left", &"right"])
		else:
			sides.append(corner)
		if mirror:
			var flipped: Array[StringName] = []
			for side in sides:
				flipped.append(&"left" if side == &"right" else &"right")
			sides = flipped
		_entries.append({"attacker": attacker, "sides": sides, "start": Engine.get_physics_frames(), "end": -1})

	func _on_windup_ended(attacker: Node3D, interrupted: bool) -> void:
		if interrupted:
			_end(attacker)

	func _on_hit(hit: HitInfo) -> void:
		_end(hit.attacker)

	func _on_whiff(attacker: Node3D, _move: MoveData) -> void:
		_end(attacker)

	func _end(attacker: Node3D) -> void:
		for entry in _entries:
			if entry.attacker == attacker and entry.end < 0:
				entry.end = Engine.get_physics_frames()

	func corner_state(side: StringName) -> Dictionary:
		var frame := Engine.get_physics_frames()
		if player.health <= 0.0:
			return {"active": false, "count": 0, "heavy": false, "alpha": 0.0, "size_px": 0.0}
		var count := 0
		var heavy := false
		for entry in _entries:
			if not entry.sides.has(side) or frame < int(entry.start) + lag:
				continue
			if int(entry.end) >= 0 and frame >= int(entry.end) + end_lag:
				continue
			if int(entry.end) < 0:
				if not is_instance_valid(entry.attacker):
					continue
				var state: int = entry.attacker.state
				if state != CombatTypes.ActorState.WINDUP and state != CombatTypes.ActorState.ATTACK:
					continue
			count += 1
			heavy = heavy or (bool(entry.attacker.heavy) and not ignore_heavy)
		if always == side and count == 0:
			count = 1
		return {"active": count > 0, "count": count, "heavy": heavy, "alpha": 1.0, "size_px": 100.0}


var _scene: Node3D
var _player: PlayerCharacter
var _oracle: Oracle
var _widget: FakeWidget


func before_each() -> void:
	Tuning.reset_to_default()
	TimeController.clear()
	TimeController.debug_scale = 1.0
	PlaceholderAnims.warn_on_fallback = false
	_scene = Node3D.new()
	add_child_autofree(_scene)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	floor_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(shape)
	_scene.add_child(floor_body)
	_player = PlayerCharacter.new()
	_scene.add_child(_player)
	_player.input.scripted = true
	_widget = null
	_oracle = Oracle.new()
	_oracle.print_lines = false
	_scene.add_child(_oracle)
	_oracle.attach(null, _player)
	_oracle.start_act("test act")


func after_each() -> void:
	PlaceholderAnims.warn_on_fallback = true
	Tuning.reset_to_default()
	TimeController.clear()


# --- Harness ----------------------------------------------------------------------------


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _with_widget() -> FakeWidget:
	_widget = FakeWidget.new()
	_widget.player = _player
	_scene.add_child(_widget)
	return _widget


## Where a point `bearing` degrees from the look (positive left) and `dist` m away stands, worked
## out by hand for a look along (-sin yaw, -cos yaw): ahead, and left = (-cos yaw, sin yaw).
func _at(bearing: float, dist: float) -> Vector3:
	var yaw := _player.look_yaw
	var ahead := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var left := Vector3(-cos(yaw), 0.0, sin(yaw))
	return _player.global_position + (ahead * cos(deg_to_rad(bearing)) + left * sin(deg_to_rad(bearing))) * dist


func _stub(bearing: float, dist: float = 1.5) -> EnemyActor:
	var stub := STUB_ENEMY.instantiate() as EnemyActor
	stub.position = _at(bearing, dist)
	_scene.add_child(stub)
	return stub


## One wind-up at `bearing`, run to the end of the attack (the jab whiffs at 1.5 m), then the
## stub is gone, so the next one does not stand in it.
func _attack_from(bearing: float, dist: float = 1.5) -> void:
	var stub := _stub(bearing, dist)
	await _ticks(3)
	stub.force_attack()
	await _ticks(60)
	stub.queue_free()
	await _ticks(2)


# --- The corner ---------------------------------------------------------------------------


func test_a_correct_widget_agrees_at_every_corner_and_on_the_negative_controls() -> void:
	_with_widget()
	var cases: Array[Array] = [
		[135.0, 1.5, "left"], [-135.0, 1.5, "right"], [180.0, 1.5, "both"], [170.0, 1.5, "both"],
		[159.9, 1.5, "left"], [-159.9, 1.5, "right"], [50.0, 1.5, "none"], [0.0, 1.5, "none"],
		[135.0, 2.5, "none"],
	]
	for item in cases:
		await _attack_from(item[0], item[1])
	var r := _oracle.end_act()
	assert_eq(r.warning_windups, cases.size(), "one entry per wind-up")
	assert_eq(r.warning_oracle_agreement, 1.0, "every corner as the rule says: %s" % [r.warning_failures])
	assert_eq(r.warning_false_positives, 0)
	assert_true(Oracle.passes(r), "R10 holds: latency %d, end lag %d" % [r.warning_latency_frames, r.warning_end_lag_frames])
	for i in cases.size():
		assert_eq(r.events[i].expected, "" if cases[i][2] == "none" else cases[i][2], "case %d (%s deg)" % [i, cases[i][0]])
	assert_eq(r.warning_latency_frames, 0, "shown on the wind-up's own frame")


func test_the_bearing_follows_the_look_not_the_world() -> void:
	_with_widget()
	# Looking along +X, an attacker placed 100 degrees to the left of the look.
	_player.look_yaw = -PI / 2.0
	await _attack_from(100.0, 1.0)
	# And across the wrap: look_yaw 3.1 rad, an attacker at -179.9 degrees is directly behind.
	_player.look_yaw = 3.1
	await _attack_from(-179.9, 1.0)
	_player.look_yaw = -3.1
	await _attack_from(-179.9, 1.0)
	var r := _oracle.end_act()
	assert_eq(r.events[0].expected, "left", "100 degrees left of a look along +X")
	assert_eq(r.events[1].expected, "both", "-179.9 degrees at look_yaw 3.1")
	assert_eq(r.events[2].expected, "both", "-179.9 degrees at look_yaw -3.1")
	assert_eq(r.warning_oracle_agreement, 1.0)


func test_a_mirrored_widget_disagrees_and_lights_the_wrong_corner() -> void:
	_with_widget().mirror = true
	await _attack_from(135.0)
	var r := _oracle.end_act()
	assert_eq(r.warning_oracle_agreement, 0.0, "the left corner never lit")
	assert_gt(r.warning_false_positives, 0, "the right one lit for nobody")
	assert_false(Oracle.passes(r))
	assert_true(_oracle.lines[0].begins_with("WARN-CHECK FAIL test act left f"), _oracle.lines[0])


func test_a_burst_for_an_attacker_in_view_is_a_false_positive() -> void:
	_with_widget().always = &"left"
	await _attack_from(30.0)
	var r := _oracle.end_act()
	assert_gt(r.warning_false_positives, 0)
	assert_eq(r.warning_oracle_agreement, 0.0, "expected none, got a burst")
	assert_true(r.events[0].expected == "", "the rule says nothing at 30 degrees")


func test_a_burst_with_nobody_winding_up_is_counted_once_per_episode() -> void:
	_with_widget().always = &"right"
	await _ticks(20)
	var r := _oracle.end_act()
	assert_eq(r.warning_false_positives, 1, "one steady burst is one false positive, not twenty")
	assert_eq(_oracle.lines.size(), 1)
	assert_true(_oracle.lines[0].contains("unexplained"))


func test_a_late_widget_misses_the_latency_limit() -> void:
	_with_widget().lag = 3
	await _attack_from(135.0)
	var r := _oracle.end_act()
	assert_eq(r.warning_oracle_agreement, 1.0, "it did light the right corner")
	assert_eq(r.warning_latency_frames, 3)
	assert_false(Oracle.passes(r), "but three frames late")
	assert_true(_oracle.lines[0].contains("why=late"), _oracle.lines[0])


func test_one_frame_late_is_within_the_limit() -> void:
	_with_widget().lag = 1
	await _attack_from(-135.0)
	var r := _oracle.end_act()
	assert_eq(r.warning_latency_frames, 1)
	assert_true(Oracle.passes(r), "the widget runs on the render frame, one is allowed")


func test_a_lingering_widget_misses_the_end_lag_limit() -> void:
	_with_widget().end_lag = 4
	await _attack_from(135.0)
	var r := _oracle.end_act()
	assert_eq(r.warning_end_lag_frames, 4)
	assert_false(Oracle.passes(r))
	assert_true(_oracle.lines[0].contains("why=end-late"), _oracle.lines[0])


func test_no_widget_at_all_fails_every_corner_but_not_the_negative_controls() -> void:
	await _attack_from(135.0)
	await _attack_from(30.0)
	var r := _oracle.end_act()
	assert_false(r.widget_found)
	assert_eq(r.warning_windups, 2)
	assert_eq(r.warning_oracle_agreement, 0.5, "the corner one failed, the in-view one is right to show nothing")
	assert_false(Oracle.passes(r))


func test_two_attackers_on_one_side_make_a_count_of_two() -> void:
	var widget := _with_widget()
	var a := _stub(120.0)
	var b := _stub(140.0)
	await _ticks(3)
	a.force_attack()
	b.force_attack()
	await _ticks(4)
	assert_eq(widget.corner_state(&"left").count, 2, "the double's own count")
	assert_eq(_oracle.live_count(), 2)
	await _ticks(60)
	var r := _oracle.end_act()
	assert_eq(r.warning_oracle_agreement, 1.0, "%s" % [r.warning_failures])
	assert_eq(r.warning_false_positives, 0)


func test_a_heavy_attacker_must_show_as_heavy() -> void:
	var widget := _with_widget()
	var stub := _stub(135.0)
	stub.heavy = true
	await _ticks(3)
	stub.force_attack()
	await _ticks(10)
	var ok := _oracle.end_act()
	assert_eq(ok.warning_heavy_mismatch_frames, 0, "a widget that flags the heavy one agrees")
	stub.queue_free()
	await _ticks(60)
	widget.ignore_heavy = true
	_oracle.start_act("heavy ignored")
	var second := _stub(135.0)
	second.heavy = true
	await _ticks(3)
	second.force_attack()
	await _ticks(10)
	var bad := _oracle.end_act()
	assert_gt(bad.warning_heavy_mismatch_frames, 0, "a widget that never enlarges it does not")


# --- Where a wind-up's warning ends (Part B §B1.3) ----------------------------------------------


## A stub 135 degrees behind-left, mid wind-up, its entry live in the model.
func _winding_stub() -> EnemyActor:
	var stub := _stub(135.0)
	await _ticks(3)
	stub.force_attack()
	await _ticks(4)
	assert_eq(stub.state, CombatTypes.ActorState.WINDUP)
	assert_eq(_oracle.live_count(), 1, "the wind-up is warned")
	return stub


func test_the_strike_coming_out_does_not_end_the_warning() -> void:
	var stub := await _winding_stub()
	CombatEvents.windup_ended.emit(stub, false)
	assert_eq(_oracle.live_count(), 1, "windup_ended(false) is the strike, not the end")


func test_an_interrupted_windup_ends_the_warning() -> void:
	var stub := await _winding_stub()
	CombatEvents.windup_ended.emit(stub, true)
	assert_eq(_oracle.live_count(), 0)


func test_a_landed_or_blocked_hit_ends_the_warning() -> void:
	var stub := await _winding_stub()
	var hit := HitInfo.new()
	hit.attacker = stub
	hit.victim = _player
	hit.blocked = true
	CombatEvents.hit_landed.emit(hit)
	assert_eq(_oracle.live_count(), 0, "a blocked hit counts")


func test_a_whiff_a_grab_a_ko_and_a_vanish_end_the_warning() -> void:
	for event in [&"whiff", &"grab", &"ko", &"vanished"]:
		var stub := await _winding_stub()
		match event:
			&"whiff":
				CombatEvents.attack_whiffed.emit(stub, stub.attack)
			&"grab":
				CombatEvents.grabbed.emit(stub, _player)
			&"ko":
				CombatEvents.ko.emit(stub, HitInfo.new())
			&"vanished":
				CombatEvents.vanished.emit(stub)
		assert_eq(_oracle.live_count(), 0, "ended by %s" % event)
		stub.queue_free()
		await _ticks(2)


func test_a_freed_attacker_and_one_out_of_its_windup_end_the_warning() -> void:
	var freed := await _winding_stub()
	freed.queue_free()
	await _ticks(2)
	assert_eq(_oracle.live_count(), 0, "freed")
	var cut := await _winding_stub()
	cut.abort_move()
	await _ticks(2)
	assert_eq(_oracle.live_count(), 0, "out of WINDUP and ATTACK, its move gone")


func test_a_windup_during_the_ko_view_expects_nothing() -> void:
	_with_widget()
	_player.health = 0.0
	var stub := _stub(135.0)
	await _ticks(3)
	stub.force_attack()
	await _ticks(60)
	var r := _oracle.end_act()
	assert_eq(r.events[0].expected, "", "the widget is suppressed while the player's health is 0")
	assert_eq(r.warning_oracle_agreement, 1.0)
	assert_eq(r.warning_false_positives, 0)


# --- Lines and acts -------------------------------------------------------------------------------


func test_each_windup_prints_a_warn_check_line_the_log_checker_can_parse() -> void:
	_with_widget()
	var got: Array[String] = []
	_oracle.checked.connect(func(line: String) -> void: got.append(line))
	await _attack_from(-135.0)
	await _attack_from(20.0)
	_oracle.end_act()
	assert_eq(got.size(), 2)
	var pattern := RegEx.create_from_string("^WARN-CHECK (ok|FAIL) (.+) (left|right|both|none) f(\\d+) lat=(\\S+) end=(\\S+)")
	for line in got:
		var m := pattern.search(line)
		assert_not_null(m, "parses: %s" % line)
		if m:
			assert_eq(m.get_string(1), "ok", line)
			assert_eq(m.get_string(2), "test act")
	assert_true(got[0].contains(" right f"))
	assert_true(got[1].contains(" none f"))
	assert_eq(_oracle.lines.size(), 2, "kept for the bot's log")


func test_total_result_merges_the_acts() -> void:
	_with_widget()
	await _attack_from(135.0)
	_oracle.start_act("second act")
	await _attack_from(-135.0)
	await _attack_from(180.0)
	_oracle.end_act()
	var total := _oracle.total_result()
	assert_eq(total.warning_windups, 3)
	assert_eq(total.warning_oracle_agreement, 1.0)
	assert_true(Oracle.passes(total))


func test_a_run_with_no_windups_is_not_a_pass() -> void:
	var r := _oracle.end_act()
	assert_eq(r.warning_windups, 0)
	assert_null(r.warning_oracle_agreement)
	assert_false(Oracle.passes(r), "nothing was checked")
