extends GutTest
## The rear-attack warning (Spec §8, M3-plan Part B §B1; game/ui/rear_warning.gd): which corner
## lights for an attacker at which bearing, distance and reach, when it ends, how several and
## heavy attackers look, the live tunables, pause and slow-mo, the KO view, and that it writes no
## game state. Unit tests run the HUD scene on fakes (a player looking down -Z at the origin,
## attackers placed by hand: bearing positive to the left, so +135 is behind-left); the last two
## tests run real training dummies in the real room with the real HUD, the second a sweep of 72
## bearings against the rule written out here by hand.

const HUD_SCENE := preload("res://game/ui/hud.tscn")
const ROOM := preload("res://game/level/test_room.tscn")
## An attacker 1.5 m from the player: inside reach 1.0 + margin 1.0.
const NEAR := 1.5
## Where the unused dummies of the real room wait.
const FAR := Vector3(24.0, 0.0, 0.0)


class FakeEnemy:
	extends CombatActor
	var heavy: bool = false

	func _init() -> void:
		add_to_group(&"actor")
		add_to_group(&"enemy")
		display_name = "Fake Enemy"
		team = 1
		max_health = 30.0
		health = 30.0

	func _ready() -> void:
		pass

	func _physics_process(_delta: float) -> void:
		pass


## An attacker that knows its own reach (the warning asks it before the move's).
class FakeReachEnemy:
	extends FakeEnemy
	var reach: float = 3.0

	func warning_reach_m(_move: MoveData) -> float:
		return reach


class FakePlayer:
	extends PlayerCharacter

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


var _hud: GameHud
var _warning: RearWarning
var _player: FakePlayer
## Every shown / cleared signal of the warning, as "side count heavy" and "side".
var _shown: Array[String] = []
var _cleared: Array[String] = []
var _room: Node3D


func before_each() -> void:
	Tuning.apply(TuningData.new())
	TimeController.clear()
	TimeController.debug_scale = 1.0
	_shown.clear()
	_cleared.clear()


func after_each() -> void:
	TimeController.clear()
	TimeController.debug_scale = 1.0
	get_tree().paused = false


## A HUD on fakes: a player at the origin looking down -Z, processing off (the tests step it).
func _build(with_player: bool = true) -> void:
	_hud = HUD_SCENE.instantiate() as GameHud
	add_child_autofree(_hud)
	_hud.set_process(false)
	_warning = _hud.rear_warning
	_warning.shown.connect(func(side: StringName, count: int, heavy: bool) -> void:
		_shown.append("%s %d %s" % [side, count, heavy]))
	_warning.cleared.connect(func(side: StringName) -> void: _cleared.append(String(side)))
	if with_player:
		_player = FakePlayer.new()
		add_child_autofree(_player)
	await wait_process_frames(2)  # the HUD lays out against the viewport


## An enemy `bearing_deg` off the player's look (positive left) and `distance` away, flat.
func _enemy_at(bearing_deg: float, distance: float = NEAR, kind: Script = FakeEnemy) -> FakeEnemy:
	var enemy := kind.new() as FakeEnemy
	add_child_autofree(enemy)
	var a := deg_to_rad(bearing_deg)
	enemy.global_position = _player.global_position + Vector3(-sin(a), 0.0, -cos(a)) * distance
	return enemy


func _move(reach: float = 1.0, id: StringName = &"fake_jab") -> MoveData:
	var move := MoveData.new()
	move.id = id
	move.reach_m = reach
	move.startup = 24
	return move


## `enemy` winds up `move`: its state and move, then the event, as CombatActor.start_move() does.
func _wind_up(enemy: CombatActor, move: MoveData = null) -> MoveData:
	if move == null:
		move = _move()
	enemy.state = CombatTypes.ActorState.WINDUP
	enemy.current_move = move
	CombatEvents.windup_started.emit(enemy, move)
	return move


## Which corners are lit: &"", &"left", &"right" or &"both".
func _lit() -> StringName:
	var left: bool = _warning.corner_state(&"left").active
	var right: bool = _warning.corner_state(&"right").active
	if left and right:
		return &"both"
	if left:
		return &"left"
	return &"right" if right else &""


func _hit_by(attacker: Node3D, blocked: bool = false) -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = attacker
	hit.victim = _player
	hit.blocked = blocked
	return hit


# --- Which corner ---------------------------------------------------------------------------


func test_behind_left_lights_the_top_left_corner_only() -> void:
	await _build()
	# 135 degrees to the left of a player looking down -Z: left (-X) and behind (+Z).
	var enemy := _enemy_at(0.0)
	enemy.global_position = Vector3(-1.06, 0.0, 1.06)
	_wind_up(enemy)
	assert_eq(_lit(), &"left")
	assert_eq(_shown, ["left 1 false"], "shown on the wind-up's own frame")
	assert_true(_warning.visible)
	var state := _warning.corner_state(&"left")
	assert_eq(state.count, 1)
	assert_false(_warning.corner_state(&"right").active)
	# The burst is in the top-left of the screen.
	var screen := _warning.size
	assert_lt(state.rect.get_center().x, screen.x * 0.2, "left corner")
	assert_lt(state.rect.get_center().y, screen.y * 0.2, "top corner")


func test_behind_right_lights_the_top_right_corner_only() -> void:
	await _build()
	var enemy := _enemy_at(0.0)
	enemy.global_position = Vector3(1.06, 0.0, 1.06)
	_wind_up(enemy)
	assert_eq(_lit(), &"right")
	assert_eq(_shown, ["right 1 false"])
	var rect: Rect2 = _warning.corner_state(&"right").rect
	assert_gt(rect.get_center().x, _warning.size.x * 0.8, "right corner")


func test_directly_behind_lights_both_corners() -> void:
	await _build()
	var enemy := _enemy_at(0.0)
	enemy.global_position = Vector3(0.0, 0.0, 1.5)
	_wind_up(enemy)
	assert_eq(_lit(), &"both")
	assert_eq(_shown.size(), 2, "one burst per corner")
	assert_true(_shown.has("left 1 false") and _shown.has("right 1 false"))
	_wind_up(_enemy_at(165.0))
	assert_eq(_warning.corner_state(&"left").count, 2, "165 degrees is directly behind too")


func test_the_both_corners_edge_is_20_degrees_from_straight_behind() -> void:
	await _build()
	_wind_up(_enemy_at(170.0))
	assert_eq(_lit(), &"both", "170 is within 20 of behind")
	_reset_warning()
	_wind_up(_enemy_at(-170.0))
	assert_eq(_lit(), &"both")
	_reset_warning()
	_wind_up(_enemy_at(155.0))
	assert_eq(_lit(), &"left", "155 is not")
	_reset_warning()
	_wind_up(_enemy_at(-155.0))
	assert_eq(_lit(), &"right")


func test_in_view_and_out_of_range_attackers_do_not_warn() -> void:
	await _build()
	for bearing: float in [0.0, 30.0, -30.0, 54.9, -54.9, 50.0]:
		_wind_up(_enemy_at(bearing))
		assert_eq(_lit(), &"", "%.1f degrees is in view" % bearing)
	_wind_up(_enemy_at(55.1))
	assert_eq(_lit(), &"left", "just past the view's edge")
	_reset_warning()
	# Reach 1.0 + margin 1.0: 1.99 m is in range, 2.01 m is not.
	_wind_up(_enemy_at(135.0, 1.99))
	assert_eq(_lit(), &"left")
	_reset_warning()
	_wind_up(_enemy_at(135.0, 2.01))
	assert_eq(_lit(), &"", "out of range")


func test_the_reach_comes_from_the_attacker_when_it_has_its_own() -> void:
	await _build()
	var plain := _enemy_at(135.0, 3.5)
	_wind_up(plain)
	assert_eq(_lit(), &"", "3.5 m is past the move's reach 1.0 + 1.0")
	var charger := _enemy_at(135.0, 3.5, FakeReachEnemy) as FakeReachEnemy
	_wind_up(charger)
	assert_eq(_lit(), &"left", "its own warning_reach_m (3.0) + 1.0 covers it")


func test_the_rule_is_measured_from_the_look_not_the_world() -> void:
	await _build()
	# Looking along +X (yaw -90 degrees): an attacker on the world's +Z side is to the RIGHT of
	# the look... and one on -Z to the left, however the world is laid out.
	_player.look_yaw = -PI * 0.5
	var enemy := _enemy_at(0.0)
	enemy.global_position = Vector3(-1.0, 0.0, -1.0)  # behind (-X) and on the -Z side
	_wind_up(enemy)
	assert_eq(_lit(), &"left", "-Z is the left hand of a player facing +X")


func test_a_friendly_wind_up_never_warns() -> void:
	await _build()
	var enemy := _enemy_at(135.0)
	enemy.team = 0
	_wind_up(enemy)
	assert_eq(_lit(), &"")


func test_no_player_no_warning() -> void:
	await _build(false)
	var enemy := FakeEnemy.new()
	add_child_autofree(enemy)
	enemy.global_position = Vector3(0.0, 0.0, 1.5)
	_wind_up(enemy)
	assert_eq(_lit(), &"")
	assert_eq(_shown, [])


# --- The end --------------------------------------------------------------------------------


## Each way the warning ends: how it is triggered, and whether the event or the HUD's next
## step ends it.
func _end_cases() -> Array[Dictionary]:
	return [
		{name = "a hit lands", polled = false, fn = func(e: FakeEnemy, _m: MoveData) -> void:
			CombatEvents.hit_landed.emit(_hit_by(e))},
		{name = "a hit is blocked", polled = false, fn = func(e: FakeEnemy, _m: MoveData) -> void:
			CombatEvents.hit_landed.emit(_hit_by(e, true))},
		{name = "the strike whiffs", polled = false, fn = func(e: FakeEnemy, m: MoveData) -> void:
			CombatEvents.attack_whiffed.emit(e, m)},
		{name = "the wind-up is interrupted", polled = false, fn = func(e: FakeEnemy, _m: MoveData) -> void:
			CombatEvents.windup_ended.emit(e, true)},
		{name = "it grabs", polled = false, fn = func(e: FakeEnemy, _m: MoveData) -> void:
			CombatEvents.grabbed.emit(e, _player)},
		{name = "it is KO'd", polled = false, fn = func(e: FakeEnemy, _m: MoveData) -> void:
			CombatEvents.ko.emit(e, HitInfo.new())},
		{name = "it vanishes", polled = false, fn = func(e: FakeEnemy, _m: MoveData) -> void:
			CombatEvents.vanished.emit(e)},
		{name = "it is freed", polled = true, fn = func(e: FakeEnemy, _m: MoveData) -> void:
			e.get_parent().remove_child(e)
			e.free()},
		{name = "it leaves WINDUP and ATTACK", polled = true, fn = func(e: FakeEnemy, _m: MoveData) -> void:
			e.state = CombatTypes.ActorState.HITSTUN},
		{name = "it runs another move", polled = true, fn = func(e: FakeEnemy, _m: MoveData) -> void:
			e.current_move = _move(1.0, &"other_move")},
		{name = "its move ends", polled = true, fn = func(e: FakeEnemy, _m: MoveData) -> void:
			e.current_move = null},
	]


func test_the_warning_ends_on_every_end_event_and_poll() -> void:
	await _build()
	for end: Dictionary in _end_cases():
		var enemy := _enemy_at(135.0)
		var move := _wind_up(enemy)
		assert_eq(_lit(), &"left", "lit before: %s" % end.name)
		_cleared.clear()
		var fn: Callable = end.fn
		fn.call(enemy, move)
		if end.polled:
			assert_eq(_lit(), &"left", "a polled end waits for the HUD's step: %s" % end.name)
			_hud.advance(0.016)
		assert_eq(_lit(), &"", "ends when %s" % end.name)
		assert_eq(_cleared, ["left"], "cleared once when %s" % end.name)
		assert_false(_hud.rear_warning.visible)


func test_the_strike_coming_out_does_not_end_it() -> void:
	await _build()
	var enemy := _enemy_at(135.0)
	var move := _wind_up(enemy)
	_hud.advance(0.1)
	# windup_ended(false): the telegraph is over and the strike comes out; nothing has landed.
	enemy.state = CombatTypes.ActorState.ATTACK
	CombatEvents.windup_ended.emit(enemy, false)
	_hud.advance(0.1)
	assert_eq(_lit(), &"left", "still warning through the active frames")
	assert_eq(_cleared, [])
	CombatEvents.hit_landed.emit(_hit_by(enemy))
	assert_eq(_lit(), &"", "until it lands")
	assert_not_null(move)


func test_another_attackers_hit_does_not_end_it() -> void:
	await _build()
	var first := _enemy_at(135.0)
	_wind_up(first)
	var other := _enemy_at(30.0)
	CombatEvents.hit_landed.emit(_hit_by(other))
	CombatEvents.windup_ended.emit(other, true)
	CombatEvents.ko.emit(other, HitInfo.new())
	assert_eq(_lit(), &"left")


# --- Several, heavy -------------------------------------------------------------------------


func test_two_attackers_on_one_side_are_brighter_and_pulse_again() -> void:
	await _build()
	Tuning.data.rear_warning_opacity = 0.5
	var first := _enemy_at(135.0)
	_wind_up(first)
	var alone: Dictionary = _warning.corner_state(&"left")
	_hud.advance(1.0)  # the pulses are over
	_wind_up(_enemy_at(100.0))
	var two: Dictionary = _warning.corner_state(&"left")
	assert_eq(two.count, 2)
	assert_eq(_shown, ["left 1 false", "left 2 false"], "one burst per corner, pulsing again at 2")
	assert_eq(alone.brightness, 1.0)
	assert_almost_eq(two.brightness, 1.0 + Tuning.data.rear_warning_brightness_step, 0.0001)
	assert_gt(two.brightness, alone.brightness, "brighter")
	_hud.advance(1.0)
	assert_gt(_warning.corner_state(&"left").alpha, 0.5 * 1.0, "and more opaque (steady)")
	_wind_up(_enemy_at(120.0))
	assert_almost_eq(_warning.corner_state(&"left").brightness,
			1.0 + 2.0 * Tuning.data.rear_warning_brightness_step, 0.0001, "a third adds a step more")
	# One ends: back to the second's brightness, with no new shown.
	var count := _shown.size()
	CombatEvents.windup_ended.emit(first, true)
	assert_eq(_warning.corner_state(&"left").count, 2)
	assert_eq(_shown.size(), count)
	assert_eq(_cleared, [], "the corner stays lit")


func test_a_behind_attacker_counts_on_both_sides() -> void:
	await _build()
	_wind_up(_enemy_at(180.0))
	_wind_up(_enemy_at(100.0))
	assert_eq(_warning.corner_state(&"left").count, 2, "the left one and the behind one")
	assert_eq(_warning.corner_state(&"right").count, 1, "the behind one alone")
	_wind_up(_enemy_at(-100.0))
	assert_eq(_warning.corner_state(&"right").count, 2)


func test_a_heavy_attacker_gets_a_larger_burst() -> void:
	await _build()
	Tuning.data.rear_warning_size = 0.5
	var normal := _enemy_at(135.0)
	_wind_up(normal)
	var small: Dictionary = _warning.corner_state(&"left")
	var heavy := _enemy_at(-135.0)
	heavy.heavy = true
	_wind_up(heavy)
	var big: Dictionary = _warning.corner_state(&"right")
	assert_true(big.heavy)
	assert_false(small.heavy)
	assert_almost_eq(big.size_px / small.size_px, Tuning.data.rear_warning_heavy_scale, 0.001)
	assert_eq(_shown, ["left 1 false", "right 1 true"], "shown tells the heavy flag")
	# A heavy attacker joining a corner enlarges the corner's one burst.
	var more := _enemy_at(100.0)
	more.heavy = true
	_wind_up(more)
	assert_true(_warning.corner_state(&"left").heavy)
	assert_gt(_warning.corner_state(&"left").size_px, small.size_px)


# --- Tunables, time, KO view ----------------------------------------------------------------


func test_the_tunables_are_read_live() -> void:
	await _build()
	# The view's edge: 70 degrees is behind-left at 55, in view at 80.
	_wind_up(_enemy_at(70.0))
	assert_eq(_lit(), &"left")
	_reset_warning()
	Tuning.data.rear_warning_angle_deg = 80.0
	_wind_up(_enemy_at(70.0))
	assert_eq(_lit(), &"", "the angle")
	# The both-corners cone: 150 degrees is one corner at 20, both at 40.
	Tuning.data.rear_warning_angle_deg = 55.0
	_wind_up(_enemy_at(150.0))
	assert_eq(_lit(), &"left")
	_reset_warning()
	Tuning.data.rear_warning_behind_deg = 40.0
	_wind_up(_enemy_at(150.0))
	assert_eq(_lit(), &"both", "the behind cone")
	_reset_warning()
	# The range margin: reach 1.0 + 0.0 leaves 1.5 m out.
	Tuning.data.rear_warning_range_margin_m = 0.0
	_wind_up(_enemy_at(135.0, 1.5))
	assert_eq(_lit(), &"", "the range margin")
	_reset_warning()
	Tuning.data.rear_warning_range_margin_m = 1.0
	# Size and opacity apply to a burst already showing.
	_wind_up(_enemy_at(135.0))
	_hud.advance(1.0)
	var before: Dictionary = _warning.corner_state(&"left")
	Tuning.data.rear_warning_size = 0.5
	Tuning.data.rear_warning_opacity = 0.4
	var after: Dictionary = _warning.corner_state(&"left")
	assert_almost_eq(after.size_px, before.size_px * 0.5, 0.01, "size")
	assert_almost_eq(after.alpha, 0.4, 0.0001, "opacity")


func test_it_pops_in_beats_twice_and_holds() -> void:
	await _build()
	Tuning.data.rear_warning_opacity = 1.0
	Tuning.data.rear_warning_brightness_step = 0.0
	_wind_up(_enemy_at(135.0))
	var pulse := Tuning.data.rear_warning_pulse_s
	var steady: float = _warning.corner_state(&"left").size_px
	var pop: Dictionary = _warning.corner_state(&"left")
	assert_almost_eq(pop.alpha, 1.0, 0.0001, "the pop is bright")
	assert_almost_eq(pop.scale, 1.0 + Tuning.data.rear_warning_pulse_grow, 0.0001, "and oversized")
	_hud.advance(pulse * 0.5)
	var dip: Dictionary = _warning.corner_state(&"left")
	assert_almost_eq(dip.alpha, Tuning.data.rear_warning_min_alpha, 0.0001, "mid-pulse it dips")
	assert_lt(dip.scale, pop.scale)
	_hud.advance(pulse * 0.5)
	assert_gt(_warning.corner_state(&"left").alpha, 0.99, "and is back at the pulse's end")
	_hud.advance(pulse * 0.5)
	assert_almost_eq(_warning.corner_state(&"left").alpha, Tuning.data.rear_warning_min_alpha, 0.0001,
			"the second pulse dips too")
	_hud.advance(pulse * 0.5 + 0.01)
	var held: Dictionary = _warning.corner_state(&"left")
	assert_almost_eq(held.alpha, 1.0, 0.0001, "then it holds")
	assert_almost_eq(held.scale, 1.0, 0.0001)
	assert_almost_eq(held.size_px, steady, 0.0001)
	_hud.advance(1.0)
	assert_eq(_warning.corner_state(&"left").alpha, held.alpha, "steady")


func test_no_pulses_means_a_steady_burst_from_the_start() -> void:
	await _build()
	Tuning.data.rear_warning_pulses = 0
	_wind_up(_enemy_at(135.0))
	var state: Dictionary = _warning.corner_state(&"left")
	assert_almost_eq(state.scale, 1.0, 0.0001)
	assert_almost_eq(state.alpha, Tuning.data.rear_warning_opacity, 0.0001)


func test_a_pause_holds_the_pulses() -> void:
	await _build()
	_wind_up(_enemy_at(135.0))
	get_tree().paused = true
	_hud.advance(5.0)
	get_tree().paused = false
	assert_almost_eq(_warning.corner_state(&"left").scale, 1.0 + Tuning.data.rear_warning_pulse_grow, 0.0001,
			"still at the pop: no game time passed")
	assert_eq(_lit(), &"left", "and still showing")


func test_slow_motion_stretches_the_pulses() -> void:
	await _build()
	_wind_up(_enemy_at(135.0))
	TimeController.debug_scale = 0.25
	_hud.advance(0.12)  # a whole pulse at 1x; a quarter of one at 0.25x
	var slow: Dictionary = _warning.corner_state(&"left")
	assert_gt(slow.scale, 1.0, "a quarter into the first pulse, still swelling")
	assert_gt(slow.alpha, Tuning.data.rear_warning_min_alpha, "not yet at the dip")
	TimeController.debug_scale = 1.0
	_hud.advance(0.24)
	assert_almost_eq(_warning.corner_state(&"left").scale, 1.0, 0.0001, "over at 1x")


func test_it_hides_while_the_player_is_ko() -> void:
	await _build()
	_player.health = 0.0
	_wind_up(_enemy_at(135.0))
	assert_eq(_lit(), &"", "no warning is raised in the KO view")
	_player.health = 100.0
	var enemy := _enemy_at(-135.0)
	_wind_up(enemy)
	assert_eq(_lit(), &"right")
	_player.health = 0.0
	_hud.advance(0.016)
	assert_eq(_lit(), &"", "and one showing goes dark")
	assert_eq(_cleared, ["right"])
	_player.health = 100.0
	_hud.advance(0.016)
	assert_eq(_lit(), &"right", "back with the player (the wind-up is still on)")
	Tuning.data.rear_warning_hide_in_ko = false
	_player.health = 0.0
	_hud.advance(0.016)
	assert_eq(_lit(), &"right", "rear_warning_hide_in_ko off keeps it")


func test_the_side_follows_the_players_turn_only_when_asked() -> void:
	await _build()
	var enemy := _enemy_at(135.0)
	_wind_up(enemy)
	_player.look_yaw = deg_to_rad(40.0)  # turned left: the attacker is now 95 degrees to the left
	_hud.advance(0.016)
	assert_eq(_lit(), &"left")
	_player.look_yaw = deg_to_rad(225.0)  # turned far round: it is 90 degrees to the right
	_hud.advance(0.016)
	assert_eq(_lit(), &"left", "off: the side is fixed at the wind-up's start")
	_reset_warning()
	Tuning.data.rear_warning_follow_turn = true
	_player.look_yaw = 0.0
	_wind_up(enemy)
	assert_eq(_lit(), &"left")
	_player.look_yaw = deg_to_rad(135.0)  # facing it: in view, so no warning is needed
	_hud.advance(0.016)
	assert_eq(_lit(), &"", "on: facing it, the warning goes")
	assert_eq(_cleared, ["left"])
	_player.look_yaw = deg_to_rad(225.0)
	_hud.advance(0.016)
	assert_eq(_lit(), &"right", "turned away the other way it is on the right")
	_player.look_yaw = deg_to_rad(40.0)
	_hud.advance(0.016)
	assert_eq(_lit(), &"left", "and on the left again")


func test_it_writes_no_game_state() -> void:
	await _build()
	var enemy := _enemy_at(135.0)
	var move := _wind_up(enemy)
	var before := [enemy.health, enemy.state, enemy.global_position, enemy.sim_velocity,
			_player.health, _player.state, _player.global_position, _player.look_yaw]
	_hud.advance(0.3)
	CombatEvents.attack_whiffed.emit(enemy, move)
	_hud.advance(0.3)
	assert_eq([enemy.health, enemy.state, enemy.global_position, enemy.sim_velocity,
			_player.health, _player.state, _player.global_position, _player.look_yaw], before)
	assert_false(TimeController.is_in_hitstop(enemy), "no time changes")
	assert_false(TimeController.is_slowmo())


func test_a_freed_hud_leaves_the_event_bus() -> void:
	await _build()
	var before := CombatEvents.windup_started.get_connections().size()
	_hud.queue_free()
	await wait_process_frames(2)
	assert_lt(CombatEvents.windup_started.get_connections().size(), before)
	var enemy := FakeEnemy.new()
	add_child_autofree(enemy)
	CombatEvents.windup_started.emit(enemy, _move())  # no handler left to fail


# --- Real dummies in the real training room -------------------------------------------------


## The real room with presentation on (the real HUD), the player scripted and facing down the
## street, every dummy parked and not sparring.
func _build_room() -> void:
	_room = ROOM.instantiate()
	add_child_autofree(_room)
	await _ticks(2)
	_player = null
	var player := _room.get(&"player") as PlayerCharacter
	player.input.scripted = true
	player.rotation.y = player.look_yaw
	for node: Node in _room.get_children():
		if node is GameHud:
			_hud = node as GameHud
	_warning = _hud.rear_warning
	_warning.shown.connect(func(side: StringName, count: int, heavy: bool) -> void:
		_shown.append("%s %d %s f%d" % [side, count, heavy, Engine.get_physics_frames()]))
	_warning.cleared.connect(func(side: StringName) -> void:
		_cleared.append("%s f%d" % [side, Engine.get_physics_frames()]))
	var dummies: Array[TrainingDummy] = []
	dummies.assign(_room.get(&"dummies"))
	for i in dummies.size():
		dummies[i].sparring = false
		dummies[i].set_post(FAR + Vector3(i * 3.0, 0.0, 0.0), 0.0, true)
	await _ticks(3)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Place `dummy` `distance` m from `player` at `bearing_deg` off its look (positive left), in
## the player's own frame (x right, -z ahead), facing it, and stand it up fresh.
func _post_dummy(dummy: TrainingDummy, player: PlayerCharacter, bearing_deg: float, distance: float) -> void:
	var a := deg_to_rad(bearing_deg)
	var pos := player.global_position + player.global_basis * (Vector3(-sin(a), 0.0, -cos(a)) * distance)
	var to_player := player.global_position - pos
	dummy.set_post(pos, atan2(-to_player.x, -to_player.z), true)


func test_real_dummies_behind_the_player_light_the_corner_and_it_ends_on_the_hit() -> void:
	await _build_room()
	var player := _room.get(&"player") as PlayerCharacter
	var dummy := (_room.get(&"dummies") as Array)[0] as TrainingDummy
	var hit_frames: Array[int] = []
	var on_hit := func(_hit: HitInfo) -> void: hit_frames.append(Engine.get_physics_frames())
	CombatEvents.hit_landed.connect(on_hit)
	var cases: Array[Array] = [[135.0, &"left"], [-135.0, &"right"], [180.0, &"both"]]
	for row: Array in cases:
		hit_frames.clear()
		_shown.clear()
		_cleared.clear()
		_post_dummy(dummy, player, row[0], 0.9)
		await _ticks(2)
		var wind_up_frame := Engine.get_physics_frames()
		dummy.start_jab()
		assert_eq(dummy.state, CombatTypes.ActorState.WINDUP)
		assert_eq(_lit(), row[1], "%.0f degrees: the corner on the wind-up's first frame" % row[0])
		assert_true(_shown[0].ends_with("f%d" % wind_up_frame), "shown on the wind-up frame: %s" % _shown[0])
		# Through the wind-up and into the strike the corner stays lit.
		var landed := false
		for t in 80:
			await get_tree().physics_frame
			if player.health < player.max_health:
				landed = true
				break
			assert_eq(_lit(), row[1], "still lit before the hit (tick %d)" % t)
		assert_true(landed, "the jab lands on a player who cannot see it coming")
		assert_eq(_lit(), &"", "gone when it landed")
		assert_eq(hit_frames.size(), 1, "one hit")
		assert_true(_cleared.size() >= 1 and _cleared[0].ends_with("f%d" % hit_frames[0]),
				"cleared on the hit's frame %d: %s" % [hit_frames[0], str(_cleared)])
		player.reset_state()
		await _ticks(2)
	CombatEvents.hit_landed.disconnect(on_hit)


func test_real_dummies_in_view_or_out_of_range_light_nothing() -> void:
	await _build_room()
	var player := _room.get(&"player") as PlayerCharacter
	var dummy := (_room.get(&"dummies") as Array)[0] as TrainingDummy
	for row: Array in [[0.0, 0.9], [50.0, 0.9], [-50.0, 0.9], [135.0, 2.5]]:
		_post_dummy(dummy, player, row[0], row[1])
		await _ticks(2)
		dummy.start_jab()
		assert_eq(dummy.state, CombatTypes.ActorState.WINDUP)
		assert_eq(_lit(), &"", "%.0f degrees at %.1f m" % [row[0], row[1]])
		dummy.abort_move()
		await _ticks(1)
	assert_eq(_shown, [])


## The rule written out by hand from Spec §8 and Part B, not taken from ViewGeometry: nothing
## within 55 degrees of the look, both corners within 20 of directly behind, else the side the
## attacker is on.
static func _expected_corner(bearing_deg: float) -> StringName:
	var off := absf(bearing_deg)
	if off <= 55.0:
		return &""
	if off >= 160.0:
		return &"both"
	return &"left" if bearing_deg > 0.0 else &"right"


func test_warning_sweep_every_5_degrees() -> void:
	await _build_room()
	var player := _room.get(&"player") as PlayerCharacter
	var dummy := (_room.get(&"dummies") as Array)[0] as TrainingDummy
	var wrong: Array[String] = []
	var checked := 0
	# 72 bearings, 5 degrees apart, offset 2.5 so none sits on the 55 or 160 degree edge (the
	# edges themselves are the truth table's, in test_view_geometry.gd).
	for step in 72:
		var bearing := -177.5 + 5.0 * step
		_post_dummy(dummy, player, bearing, 0.9)
		await _ticks(2)
		dummy.start_jab()
		var want := _expected_corner(bearing)
		var got := _lit()
		checked += 1
		if got != want:
			wrong.append("%.1f: wanted '%s' got '%s'" % [bearing, want, got])
		dummy.abort_move()
		assert_eq(_lit(), &"", "interrupting the wind-up ends the warning (%.1f)" % bearing)
		await _ticks(1)
	assert_eq(checked, 72)
	assert_eq(wrong, [], "every bearing agrees with the rule")
	# And the player turned another way: the rule follows the look, not the room.
	player.look_yaw = deg_to_rad(40.0)
	player.rotation.y = player.look_yaw
	for bearing: float in [97.5, -97.5, 177.5, 12.5]:
		_post_dummy(dummy, player, bearing, 0.9)
		await _ticks(2)
		dummy.start_jab()
		assert_eq(_lit(), _expected_corner(bearing), "looking another way: %.1f" % bearing)
		dummy.abort_move()
		await _ticks(1)


## Clear every wind-up from the warning and the signal logs (the warning's own end events).
func _reset_warning() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		if node is FakeEnemy:
			CombatEvents.windup_ended.emit(node, true)
	_hud.advance(0.016)
	_shown.clear()
	_cleared.clear()
