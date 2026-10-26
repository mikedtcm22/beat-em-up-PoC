extends GutTest
## The HUD's "LB" pick-up cue (Milestone 3, P4-int): it shows while LB would pick a weapon up (one
## lies within pickup_range, the player stands free with empty hands and no enemy is in the
## grab's reach), is tunable, and writes no game state. In the real crowd room with its real HUD.

const ROOM_PATH := "res://game/level/crowd_room.tscn"
const PIPE_SCENE := preload("res://game/weapons/pipe.tscn")

var _room: CrowdRoom
var _hud: GameHud
var _player: PlayerCharacter


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.set_value(&"waves_enabled", false)
	TimeController.clear()
	GameInput.menu_open = false
	_room = (load(ROOM_PATH) as PackedScene).instantiate() as CrowdRoom
	_room.with_presentation = true
	_room.waves_enabled_on_start = false
	add_child_autofree(_room)
	await _ticks(8)
	_player = _room.player
	_player.input.scripted = true
	for node: Node in _room.get_children():
		if node is GameHud:
			_hud = node as GameHud


func after_each() -> void:
	GameInput.menu_open = false
	Tuning.reset_to_default()
	TimeController.clear()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## A pipe lying on the floor `ahead` m in front of the player (x -1.. along the look).
func _pipe_at(ahead: float) -> Weapon:
	var pipe := PIPE_SCENE.instantiate() as Weapon
	_room.add_child(pipe)
	pipe.global_position = _player.global_position + _player.get_forward() * ahead + Vector3.UP * 0.15
	for i in 240:  # it falls and settles
		await get_tree().physics_frame
		if pipe.sleeping:
			break
	return pipe


func test_it_is_hidden_with_nothing_to_pick_up() -> void:
	await _ticks(2)
	assert_null(_player.pickup_target(), "nothing in reach")
	assert_false(_hud.pickup_cue.visible, "so no cue")


func test_it_shows_while_a_pipe_lies_within_reach_and_goes_when_it_does_not() -> void:
	var pipe := await _pipe_at(1.0)
	assert_eq(_player.pickup_target(), pipe, "the player's own read: LB would take it")
	assert_true(_hud.pickup_cue.visible, "the cue is up")
	# The same pipe out of reach (the pick-up range is a tunable).
	pipe.global_position = _player.global_position + _player.get_forward() * (Tuning.data.pickup_range + 1.0) + Vector3.UP * 0.15
	await _ticks(2)
	assert_null(_player.pickup_target())
	assert_false(_hud.pickup_cue.visible, "out of reach, no cue")


func test_it_goes_once_the_weapon_is_in_hand() -> void:
	var pipe := await _pipe_at(0.8)
	assert_true(_hud.pickup_cue.visible)
	_player.input.push_press(&"GRAB", 2)
	await _ticks(10)
	assert_true(_player.holding_weapon(), "LB took the pipe")
	assert_true(pipe.holder == _player)
	assert_false(_hud.pickup_cue.visible, "nothing left to pick up")


func test_it_stays_down_while_an_enemy_is_in_the_grabs_reach() -> void:
	Tuning.set_value(&"ai_frozen", true)
	await _pipe_at(0.8)
	assert_true(_hud.pickup_cue.visible, "the pipe alone: the cue")
	var at := _player.global_position + _player.get_forward() * 1.0
	_room.spawner.spawn_enemy(&"punk", at, _player.rotation.y + PI)
	await _ticks(10)
	assert_false(_hud.pickup_cue.visible, "LB would grab the Punk first, so it does not promise the pipe")


func test_it_stays_down_unless_the_player_stands_free() -> void:
	await _pipe_at(0.8)
	assert_true(_hud.pickup_cue.visible)
	_player.health = 0.0
	await _ticks(2)
	assert_false(_hud.pickup_cue.visible, "a KO'd player picks nothing up")
	_player.reset_state()
	await _ticks(2)
	assert_true(_hud.pickup_cue.visible, "back on his feet, the cue is back")


func test_the_tunables_switch_and_size_it() -> void:
	await _pipe_at(0.8)
	assert_true(_hud.pickup_cue.visible)
	Tuning.set_value(&"pickup_cue_enabled", false)
	await _ticks(2)
	assert_false(_hud.pickup_cue.visible, "off in F1, off on the HUD")
	Tuning.set_value(&"pickup_cue_enabled", true)
	await _ticks(2)
	assert_true(_hud.pickup_cue.visible)
	# The breath: at rest at 0, its top at the swell, steady with the pulse off.
	var cue := _hud.pickup_cue
	var period: float = Tuning.data.pickup_cue_pulse_s
	assert_almost_eq(cue.swell_at(0.0), 0.0, 0.0001)
	assert_almost_eq(cue.swell_at(period * 0.5), cue.pulse_swell, 0.0001)
	Tuning.set_value(&"pickup_cue_pulse_s", 0.0)
	assert_eq(cue.swell_at(0.3), 0.0, "pulse 0 is steady")


func test_the_cue_reads_and_writes_nothing_in_the_game() -> void:
	var pipe := await _pipe_at(0.8)
	var before := [_player.health, _player.state, _player.holding_weapon(), pipe.is_available(), pipe.global_position]
	await _ticks(30)
	assert_true(_hud.pickup_cue.visible)
	var after := [_player.health, _player.state, _player.holding_weapon(), pipe.is_available(), pipe.global_position]
	assert_eq(after[0], before[0])
	assert_eq(after[1], before[1])
	assert_eq(after[2], before[2])
	assert_eq(after[3], before[3])
	assert_lt((after[4] as Vector3).distance_to(before[4] as Vector3), 0.05, "the pipe lay where it was")
