extends Node
## Input map registration, mouse capture and pause (autoload "GameInput").
## Bindings follow Spec §4: gamepad first (Xbox layout), keyboard + mouse supported.
## Mouse look deltas are accumulated here and consumed once per frame by their reader.

signal paused_changed(paused: bool)
signal restart_requested

const BINDINGS := {
	# action: [keys..., mouse buttons as "mb:N", joy buttons as "jb:N", joy axes as "ja:AXIS:SIGN"]
	&"move_forward": [KEY_W, "ja:1:-1"],
	&"move_back": [KEY_S, "ja:1:1"],
	&"move_left": [KEY_A, "ja:0:-1"],
	&"move_right": [KEY_D, "ja:0:1"],
	&"look_left": ["ja:2:-1"],
	&"look_right": ["ja:2:1"],
	&"look_up": ["ja:3:-1"],
	&"look_down": ["ja:3:1"],
	&"punch": ["mb:1", "jb:2"],  # X
	&"kick": ["mb:2", "jb:3"],  # Y
	&"jump": [KEY_SPACE, "jb:0"],  # A
	&"dodge": [KEY_SHIFT, "jb:1"],  # B
	&"back_attack": [KEY_Q, "jb:10"],  # RB
	&"grab": [KEY_E, "jb:9"],  # LB
	&"quick_turn": [KEY_TAB, "jb:8"],  # right stick click
	&"pause": [KEY_ESCAPE, "jb:6"],  # Menu
	&"restart": [KEY_R],
	&"tuning_panel": [KEY_F1, "jb:4"],  # View
	&"camera_cycle": [KEY_F2],
	&"debug_draw": [KEY_F3],
	&"cheats": [KEY_F4],
	&"help": [KEY_H],
	&"sparring": [KEY_F5],  # toggle sparring on every training dummy
	# Free-fly debug camera (keeps WASD/mouse for the player).
	&"fly_forward": [KEY_UP],
	&"fly_back": [KEY_DOWN],
	&"fly_left": [KEY_LEFT],
	&"fly_right": [KEY_RIGHT],
	&"fly_up": [KEY_PAGEUP],
	&"fly_down": [KEY_PAGEDOWN],
	&"fly_look": ["mb:3"],  # hold middle mouse to steer the free-fly camera
}

var paused: bool = false

var _mouse_delta: Vector2 = Vector2.ZERO
var _fly_mouse_delta: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	register_actions()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


static func register_actions() -> void:
	for action: StringName in BINDINGS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, 0.2)
		for binding: Variant in BINDINGS[action]:
			var event := _make_event(binding)
			if event:
				InputMap.action_add_event(action, event)


static func _make_event(binding: Variant) -> InputEvent:
	if binding is int:
		var key := InputEventKey.new()
		key.physical_keycode = binding
		return key
	var text: String = binding
	var parts := text.split(":")
	match parts[0]:
		"mb":
			var mb := InputEventMouseButton.new()
			mb.button_index = int(parts[1]) as MouseButton
			return mb
		"jb":
			var jb := InputEventJoypadButton.new()
			jb.button_index = int(parts[1]) as JoyButton
			return jb
		"ja":
			var ja := InputEventJoypadMotion.new()
			ja.axis = int(parts[1]) as JoyAxis
			ja.axis_value = float(parts[2])
			return ja
	return null


## Mouse motion since the last call, for the player's look.
func consume_mouse_delta() -> Vector2:
	var d := _mouse_delta
	_mouse_delta = Vector2.ZERO
	return d


## Mouse motion while the free-fly look button is held.
func consume_fly_mouse_delta() -> Vector2:
	var d := _fly_mouse_delta
	_fly_mouse_delta = Vector2.ZERO
	return d


func set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	paused_changed.emit(value)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		if Input.is_action_pressed(&"fly_look"):
			_fly_mouse_delta += motion.relative
		else:
			_mouse_delta += motion.relative
	elif event is InputEventMouseButton and event.is_pressed() and not paused:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		set_paused(not paused)
		get_viewport().set_input_as_handled()
	elif paused and event.is_action_pressed(&"restart"):
		set_paused(false)
		TimeController.clear()
		restart_requested.emit()
		get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()
