class_name PlayerInput
extends RefCounted
## One physics tick of player intent, read from the live devices or from a script (the
## combo bot and integration tests push frames instead of touching Input).

## Button ids handed to ComboParser. Attack ids match CombatTypes.IN_*.
const BUTTONS: Dictionary[StringName, StringName] = {
	&"punch": &"P",
	&"kick": &"K",
	&"back_attack": &"RB",
	&"jump": &"JUMP",
	&"dodge": &"DODGE",
	&"grab": &"GRAB",
	&"quick_turn": &"TURN",
}


class Frame:
	extends RefCounted
	## Movement, x = right, y = forward, length <= 1.
	var move: Vector2 = Vector2.ZERO
	var pressed: Array[StringName] = []
	var released: Array[StringName] = []


## When true, poll() returns queued frames (or idle frames when the queue is empty).
var scripted: bool = false
## Movement held while scripted, reused for every frame without its own value.
var scripted_move: Vector2 = Vector2.ZERO

var _queue: Array[Frame] = []
## Live mode: the buttons whose press poll() reported and whose release it has not.
var _down: Dictionary[StringName, bool] = {}


## This tick's intent. Live, a button reported held whose action is no longer pressed is
## released even without a release edge: an edge poll() never saw (let go while the game
## was paused, when the player does not poll) would otherwise leave it held, a raised guard
## or a haymaker charge stuck until the button is pressed and let go again.
## With `drop_presses` the live buttons pressed this tick are not reported (and not remembered as held): a card is up, or has just
## been skipped by this very press.
func poll(drop_presses: bool = false) -> Frame:
	if scripted:
		if _queue.is_empty() or drop_presses:
			var idle := Frame.new()
			idle.move = scripted_move
			return idle
		return _queue.pop_front()
	var frame := Frame.new()
	frame.move = Input.get_vector(
		&"move_left", &"move_right", &"move_back", &"move_forward", Tuning.data.stick_deadzone
	)
	for action: StringName in BUTTONS:
		var button: StringName = BUTTONS[action]
		if Input.is_action_just_pressed(action) and not drop_presses:
			frame.pressed.append(button)
			_down[button] = true
		if Input.is_action_just_released(action) or (_down.has(button) and not Input.is_action_pressed(action)):
			frame.released.append(button)
			_down.erase(button)
	return frame


## Queue `ticks` idle physics ticks.
func push_wait(ticks: int) -> void:
	for i in ticks:
		var frame := Frame.new()
		frame.move = scripted_move
		_queue.append(frame)


## Queue a press of `button` held for `hold_ticks` ticks, then released.
func push_press(button: StringName, hold_ticks: int = 2) -> void:
	var down := Frame.new()
	down.move = scripted_move
	down.pressed.append(button)
	_queue.append(down)
	push_wait(maxi(hold_ticks - 1, 0))
	var up := Frame.new()
	up.move = scripted_move
	up.released.append(button)
	_queue.append(up)


## Queue a press of `button` that stays held until push_up() (the held block).
func push_down(button: StringName) -> void:
	var down := Frame.new()
	down.move = scripted_move
	down.pressed.append(button)
	_queue.append(down)


## Queue the release of a button pressed with push_down().
func push_up(button: StringName) -> void:
	var up := Frame.new()
	up.move = scripted_move
	up.released.append(button)
	_queue.append(up)


func queued() -> int:
	return _queue.size()


func clear_queue() -> void:
	_queue.clear()
