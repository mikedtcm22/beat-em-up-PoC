extends "res://tests/bot/combo_bot.gd"
## Rear-warning acts (Milestone 3, P1-hud; Spec §8) for review captures and for the log: a
## training dummy posted around the player winds up its jab (TrainingDummy.start_jab()), and
## the bot checks the HUD's RearWarning corner state against the corner each act says (written
## here by hand from the spec, not taken from ViewGeometry) and prints one line per act:
##   WARN-CHECK ok|FAIL <act> <corner> f<frame>   (+ want=... got=... on a FAIL)
## plus the signals as they fire, so the frames can be compared:
##   WU+ <attacker> f<frame> / WU- <attacker> interrupted|strike f<frame>   (wind-up events)
##   W+ side=<left|right> count=<n> heavy=<bool> f<frame> / W- side=<...> f<frame>   (the warning)
## First person, help and combat log hidden, the player still, titles short so the caption clears
## the top-right corner. Record it with:
##   tools/capture_bot.sh res://tests/bot/warning_bot.tscn <out dir> "<act filter>" 6
## then crop the corners to judge it, for example
##   ffmpeg -i <out dir>/bot.avi -vf "crop=iw*0.3:ih*0.3:0:0,scale=480:-1,tile=6x2" ...
## Bearings are positive to the left of the look: +135 is behind-left.

const STUB_ENEMY := preload("res://tests/fixtures/stub_enemy.tscn")
const StubDirector := preload("res://tests/fixtures/stub_director.gd")
## Where a dummy winds up: close enough that its jab lands, 0.9 m from the player.
const NEAR := 0.9
## Frames a jab gets before the bot cuts it short in the sweep (the wind-up is 24).
const SWEEP_HOLD := 14

var _warning: Control
var _hud_node: Node
var _results: Array[bool] = []
var _last_corner: StringName = &""
var _stubs: Array[EnemyActor] = []


func _run() -> void:
	await _ticks(3)
	player = room.get(&"player")
	player.input.scripted = true
	dummies.assign(room.get(&"dummies"))
	director = get_tree().get_first_node_in_group(&"camera_director")
	_hud_node = _hud()
	for child in room.get_children():
		if child.has_method(&"set_help_visible"):
			child.call(&"set_help_visible", false)
		if child.has_method(&"set_combat_log_visible"):
			child.call(&"set_combat_log_visible", false)
	_warning = _hud_node.get(&"rear_warning") if _hud_node else null
	_connect_logs()
	var acts: Array[Dictionary] = [
		{title = "Warn: behind-left", cam = &"first_person", fn = _act_behind_left},
		{title = "Warn: behind-right", cam = &"first_person", fn = _act_behind_right},
		{title = "Warn: directly behind", cam = &"first_person", fn = _act_directly_behind},
		{title = "Warn: edge of behind", cam = &"first_person", fn = _act_edge},
		{title = "Warn: in view", cam = &"first_person", fn = _act_in_view},
		{title = "Warn: out of range", cam = &"first_person", fn = _act_out_of_range},
		{title = "Warn: two on the left", cam = &"first_person", fn = _act_two_left},
		{title = "Warn: left, right and behind", cam = &"first_person", fn = _act_three},
		{title = "Warn: heavy", cam = &"first_person", fn = _act_heavy},
		{title = "Warn: blocked ends it", cam = &"first_person", fn = _act_blocked},
		{title = "Warn: hit out of it ends it", cam = &"first_person", fn = _act_interrupted},
		{title = "Warn: sweep", cam = &"first_person", fn = _act_sweep},
		{title = "F3: AI layer (side view)", cam = &"side_view", fn = _act_ai_layer, check = false},
		{title = "F3: AI layer (first person)", cam = &"first_person", fn = _act_ai_layer, check = false},
	]
	for act in acts:
		var title: String = act.title
		if act_filter != "" and not _matches(title):
			continue
		await _reset(act.cam)
		_clear_stubs()
		_results.clear()
		_last_corner = &""
		caption.text = title
		print("=== %s  (f%d)" % [title, Engine.get_physics_frames()])
		var fn: Callable = act.fn
		await fn.call()
		await _ticks(30)
		if act.get("check", true):
			_report(title)
		_clear_stubs()
		await _ticks(15)
	caption.text = "done"
	await _ticks(10)
	print("\n".join(log_lines))
	get_tree().quit()


# --- Logging and checks -------------------------------------------------------------------


func _connect_logs() -> void:
	CombatEvents.windup_started.connect(func(attacker: Node3D, _move: MoveData) -> void:
		_log("WU+ %s f%d" % [attacker.name, Engine.get_physics_frames()]))
	CombatEvents.windup_ended.connect(func(attacker: Node3D, interrupted: bool) -> void:
		_log("WU- %s %s f%d" % [attacker.name, "interrupted" if interrupted else "strike",
				Engine.get_physics_frames()]))
	if _warning != null:
		_warning.connect(&"shown", func(side: StringName, count: int, heavy: bool) -> void:
			_log("W+ side=%s count=%d heavy=%s f%d" % [side, count, heavy, Engine.get_physics_frames()]))
		_warning.connect(&"cleared", func(side: StringName) -> void:
			_log("W- side=%s f%d" % [side, Engine.get_physics_frames()]))


## Print a log line (once: the base bot's closing dump repeats only what it collected itself).
func _log(line: String) -> void:
	print(line)


## Which top corners the HUD's warning has lit now: &"", &"left", &"right" or &"both".
func _corner() -> StringName:
	if _warning == null:
		return &"missing"
	var left: bool = _warning.call(&"corner_state", &"left").active
	var right: bool = _warning.call(&"corner_state", &"right").active
	if left and right:
		return &"both"
	if left:
		return &"left"
	return &"right" if right else &""


## Note whether the corner lit right now is the one the act says (`want`, &"" for none).
func _check(want: StringName) -> void:
	var got := _corner()
	_last_corner = got
	_results.append(got == want)
	if got != want:
		_log("  (wanted '%s', the warning shows '%s' at f%d)" % [want, got, Engine.get_physics_frames()])


func _report(title: String) -> void:
	var ok := not _results.is_empty() and not _results.has(false) and _warning != null
	_log("WARN-CHECK %s %s %s f%d" % ["ok" if ok else "FAIL", title,
			_last_corner if _last_corner != &"" else &"none", Engine.get_physics_frames()])


# --- Posting -------------------------------------------------------------------------------


## The post, in the player's frame (x right, -z ahead), of a spot `distance` m away at
## `bearing_deg` off the look (positive left).
func _spot(bearing_deg: float, distance: float = NEAR) -> Vector3:
	var a := deg_to_rad(bearing_deg)
	return Vector3(-sin(a), 0.0, -cos(a)) * distance


## Post dummy `index` at a bearing and distance, facing the player, the others parked.
func _post(index: int, bearing_deg: float, distance: float = NEAR) -> void:
	var d := dummies[index]
	d.sparring = false
	d.max_health = 500.0
	var pos := player.global_position + player.global_basis * _spot(bearing_deg, distance)
	var to_player := player.global_position - pos
	d.set_post(pos, atan2(-to_player.x, -to_player.z), true)


func _park_rest(used: int) -> void:
	for i in dummies.size():
		if i >= used:
			dummies[i].sparring = false
			dummies[i].set_post(PARK + PARK_STEP * i, 0.0, true)


## Wind up dummy `index`'s jab, check the warning on that same frame, and wait it out.
func _jab_and_check(index: int, want: StringName, wait_for_end: bool = true) -> void:
	dummies[index].start_jab()
	_check(want)
	if wait_for_end:
		await _wait_until(func() -> bool: return dummies[index].current_move == null, 90)
		await _ticks(10)


func _clear_stubs() -> void:
	for stub in _stubs:
		if is_instance_valid(stub):
			stub.get_parent().remove_child(stub)
			stub.free()
	_stubs.clear()


# --- Acts ----------------------------------------------------------------------------------


func _act_behind_left() -> void:
	_post(0, 135.0)
	_park_rest(1)
	await _ticks(25)
	await _jab_and_check(0, &"left")


func _act_behind_right() -> void:
	_post(0, -135.0)
	_park_rest(1)
	await _ticks(25)
	await _jab_and_check(0, &"right")


func _act_directly_behind() -> void:
	_post(0, 180.0)
	_park_rest(1)
	await _ticks(25)
	await _jab_and_check(0, &"both")


## 161 degrees (inside the +-20 of straight behind: both corners), then 159 (one corner).
func _act_edge() -> void:
	_post(0, 161.0)
	_park_rest(1)
	await _ticks(25)
	await _jab_and_check(0, &"both")
	_post(0, 159.0)
	await _ticks(25)
	await _jab_and_check(0, &"left")


## The negative controls: in view (50 degrees, then straight ahead), no corner.
func _act_in_view() -> void:
	_post(0, 50.0)
	_park_rest(1)
	await _ticks(25)
	await _jab_and_check(0, &"")
	_post(0, 0.0)
	await _ticks(25)
	await _jab_and_check(0, &"")


## Behind-left but too far to reach (2.6 m against reach 1.05 + 1.0): no corner.
func _act_out_of_range() -> void:
	_post(0, 135.0, 2.6)
	_park_rest(1)
	await _ticks(25)
	await _jab_and_check(0, &"")


## Two jabs from the left at once: one burst, brighter, pulsing again as the second joins.
func _act_two_left() -> void:
	_post(0, 135.0, 0.9)
	_post(1, 105.0, 1.0)
	_park_rest(2)
	await _ticks(25)
	dummies[0].start_jab()
	_check(&"left")
	await _ticks(6)
	dummies[1].start_jab()
	_check(&"left")
	await _wait_until(func() -> bool: return dummies[0].current_move == null and dummies[1].current_move == null, 120)
	await _ticks(10)


## Left, right and behind, one after another and then all three together.
func _act_three() -> void:
	_post(0, 120.0)
	_post(1, -120.0)
	_post(2, 180.0)
	await _ticks(25)
	dummies[0].start_jab()
	_check(&"left")
	await _wait_until(func() -> bool: return dummies[0].current_move == null, 90)
	dummies[1].start_jab()
	_check(&"right")
	await _wait_until(func() -> bool: return dummies[1].current_move == null, 90)
	dummies[2].start_jab()
	_check(&"both")
	await _wait_until(func() -> bool: return dummies[2].current_move == null, 90)
	await _ticks(20)
	for d in dummies:
		d.set_post(d.global_position, d.rotation.y, true)
	await _ticks(10)
	dummies[0].start_jab()
	await _ticks(2)
	dummies[1].start_jab()
	await _ticks(2)
	dummies[2].start_jab()
	_check(&"both")
	await _wait_until(func() -> bool:
		return dummies[0].current_move == null and dummies[1].current_move == null and dummies[2].current_move == null,
		120)
	await _ticks(10)


## A heavy attacker (a stub enemy with `heavy`, as the Bruiser and boss are) behind-right gets
## the larger burst; a plain dummy behind-left the usual one, for comparison.
func _act_heavy() -> void:
	_post(0, 135.0)
	_park_rest(1)
	var stub := STUB_ENEMY.instantiate() as EnemyActor
	stub.heavy = true
	stub.position = player.global_position + player.global_basis * _spot(-135.0)
	var to_player := player.global_position - stub.position
	stub.rotation.y = atan2(-to_player.x, -to_player.z)
	room.add_child(stub)
	_stubs.append(stub)
	await _ticks(25)
	dummies[0].start_jab()
	_check(&"left")
	await _ticks(6)
	stub.force_attack()
	await _ticks(2)
	var heavy_state: Dictionary = _warning.call(&"corner_state", &"right")
	_results.append(heavy_state.active and heavy_state.heavy)
	_last_corner = _corner()
	await _wait_until(func() -> bool: return stub.current_move == null and dummies[0].current_move == null, 120)
	await _ticks(10)


## An attacker just outside the view (58 degrees, inside the guard's 60): the warning lights
## and the held guard blocks the jab, which ends it.
func _act_blocked() -> void:
	_post(0, 58.0, 1.0)
	_park_rest(1)
	await _ticks(25)
	await _hold_block()
	await _ticks(10)
	await _jab_and_check(0, &"left", false)
	await _wait_until(func() -> bool: return dummies[0].current_move == null, 90)
	_results.append(_corner() == &"")
	await _ticks(10)
	await _release_block()


## A back elbow into the wind-up of a dummy straight behind: the interrupt ends the warning.
func _act_interrupted() -> void:
	_post(0, 180.0, 1.0)
	_park_rest(1)
	await _ticks(25)
	dummies[0].start_jab()
	_check(&"both")
	await _ticks(4)
	await _press(&"RB", 2)
	await _wait_until(func() -> bool: return dummies[0].state != CombatTypes.ActorState.WINDUP, 60)
	_results.append(_corner() == &"")
	await _wait_idle()


## One jab every 15 degrees all round the player, each cut short after SWEEP_HOLD frames (the
## wind-up is 24): the corner follows the rule at every bearing.
func _act_sweep() -> void:
	_park_rest(1)
	for step in 24:
		var bearing := wrapf(-180.0 + 15.0 * step + 7.5, -180.0, 180.0)
		_post(0, bearing)
		await _ticks(6)
		dummies[0].start_jab()
		var off := absf(bearing)
		var want: StringName = &""
		if off > 55.0:
			want = &"both" if off >= 160.0 else (&"left" if bearing > 0.0 else &"right")
		_check(want)
		await _ticks(SWEEP_HOLD)
		dummies[0].abort_move()
		_results.append(_corner() == &"")
		await _ticks(4)


## The F3 layer for the enemy AI, with no AI yet: stub enemies on the posture ring, one holding
## a token (a ring at its feet and a line to the player), the others with slots (a circle on the
## ring and a dim line to it), the player's view boundary and the behind sector on the floor.
## A stub director sets what the read API answers, as the real one will.
func _act_ai_layer() -> void:
	_park_rest(0)
	var stub_director := StubDirector.new()
	room.add_child(stub_director)
	var hud := _hud()
	if hud:
		hud.call(&"set_debug_draw_enabled", true)
	var bearings: Array[float] = [20.0, 75.0, 140.0, 180.0, -110.0, -45.0]
	for i in bearings.size():
		var stub := STUB_ENEMY.instantiate() as EnemyActor
		var radius := 2.6 + 0.3 * float(i % 3)
		stub.position = player.global_position + player.global_basis * _spot(bearings[i], radius)
		var to_player := player.global_position - stub.position
		stub.rotation.y = atan2(-to_player.x, -to_player.z)
		room.add_child(stub)
		_stubs.append(stub)
		var slot := player.global_position + player.global_basis * _spot(bearings[i] + 8.0, 3.2)
		stub_director.put_slot(stub, slot)
	stub_director.give_token(_stubs[0])
	stub_director.give_token(_stubs[3], true)
	await _ticks(90)
	await _turn_by(70.0, 60)
	await _ticks(60)
	if hud:
		hud.call(&"set_debug_draw_enabled", false)
	stub_director.get_parent().remove_child(stub_director)
	stub_director.free()
