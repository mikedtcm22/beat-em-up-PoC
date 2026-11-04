extends GutTest
## The Kicker flanks opportunistically (Milestone 5, Game-boy's playtest). The director has a Kicker
## flank (take the seat nearest directly behind the look, strafe toward the view's edge, circle fast)
## only while the player is busy with another enemy he faces: another live, engaged enemy that is not itself
## flanking stands inside his view within kicker_flank_busy_radius_m and nearer the middle of the view than
## the Kicker. It starts after kicker_flank_on_s of that, stops after kicker_flank_off_s of its absence and
## after kicker_flank_faced_off_s once he turns onto the Kicker (it then fights from in view); otherwise it is seated by its own arc like any enemy, so a
## one-on-one is fought face to face. Real player, director and Kickers on a flat floor (no navmesh: the
## enemies steer straight); the tests that judge the decision freeze the AI (the director still decides
## and seats), the ones that judge the behaviour let it walk. Every tick is one physics frame.

const KICKER_SCENE := preload("res://game/enemies/kicker/kicker.tscn")
const PUNK_SCENE := preload("res://game/enemies/punk/street_punk.tscn")

## Slack, in ticks, on a timer the director counts on its own clock.
const TICK_SLACK := 3

var _scene: Node3D
var _player: PlayerCharacter
var _director: EnemyDirector
var _winds: Array[Dictionary] = []


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.data.ai_frozen = false
	Tuning.data.god_mode = true
	Tuning.data.director_even_spread = false  # a Debug value: reset_to_default() leaves it
	TimeController.clear()
	TimeController.debug_scale = 1.0
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = false
	_winds.clear()
	CombatEvents.windup_started.connect(_on_windup)
	_scene = Node3D.new()
	add_child_autofree(_scene)
	var body := StaticBody3D.new()
	body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	body.add_child(shape)
	_scene.add_child(body)
	_player = PlayerCharacter.new()
	_scene.add_child(_player)
	_player.input.scripted = true
	_director = EnemyDirector.new()
	_scene.add_child(_director)


func after_each() -> void:
	if CombatEvents.windup_started.is_connected(_on_windup):
		CombatEvents.windup_started.disconnect(_on_windup)
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = true
	Tuning.reset_to_default()
	Tuning.data.ai_frozen = false
	Tuning.data.god_mode = false
	Tuning.data.director_even_spread = false
	TimeController.clear()


func _on_windup(attacker: Node3D, _move: MoveData) -> void:
	_winds.append({attacker = attacker, bearing = _player.look_bearing_deg(attacker.global_position),
			outside = _player.is_outside_view(attacker.global_position, Tuning.data.rear_warning_angle_deg)})


# --- Harness ----------------------------------------------------------------------------------


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Ticks for `seconds` of the director's clock.
func _ticks_for(seconds: float) -> int:
	return ceili(seconds * 60.0)


## `distance` m from the player (at the origin, looking down -Z at the start) at `bearing_deg` off that look
## (positive left).
func _ahead(distance: float, bearing_deg: float = 0.0) -> Vector3:
	var b := deg_to_rad(bearing_deg)
	return Vector3(-sin(b) * distance, 0.0, -cos(b) * distance)


func _kicker(at: Vector3, label: String = "Kicker1") -> Kicker:
	var kicker := KICKER_SCENE.instantiate() as Kicker
	kicker.name = label
	kicker.position = at
	kicker.rotation.y = atan2(at.x, at.z)
	_scene.add_child(kicker)
	return kicker


func _punk(at: Vector3, label: String = "Punk1") -> StreetPunk:
	var punk := PUNK_SCENE.instantiate() as StreetPunk
	punk.name = label
	punk.position = at
	punk.rotation.y = atan2(at.x, at.z)
	_scene.add_child(punk)
	return punk


## The world bearing (degrees) of `point` from the player.
func _world_bearing(point: Vector3) -> float:
	return ViewGeometry.bearing_deg(0.0, _player.global_position, point)


## The bearing of the director's seat for `enemy` from the player's look (degrees, positive left).
func _seat_off_look(enemy: EnemyActor) -> float:
	return _player.look_bearing_deg(_director.slot_for(enemy))


## Turn the look dead onto `point`.
func _face(point: Vector3) -> void:
	_player.look_yaw = atan2(-point.x, -point.z)


## Tick with the look held dead onto `node` each tick (the held-back autopilot's snap-turn), `n` ticks.
func _face_for(node: Node3D, n: int) -> void:
	for i in n:
		_face(node.global_position)
		await get_tree().physics_frame


func _off(a: float, b: float) -> float:
	return absf(wrapf(a - b, -180.0, 180.0))


## Tick until `condition` holds (up to `max_ticks`); how many ticks it took, or -1.
func _until(condition: Callable, max_ticks: int) -> int:
	for i in max_ticks:
		if condition.call():
			return i
		await get_tree().physics_frame
	return max_ticks if condition.call() else -1


# --- A one-on-one ------------------------------------------------------------------------------


func test_a_lone_kicker_in_front_of_a_standing_player_never_goes_behind_him() -> void:
	var kicker := _kicker(_ahead(6.0))
	var worst := 0.0
	var flanked := false
	for t in _ticks_for(25.0):
		await _ticks(1)
		flanked = flanked or kicker.is_flanking()
		var seat := _director.slot_for(kicker)
		if seat.is_finite():
			worst = maxf(worst, absf(_seat_off_look(kicker)))
	assert_false(flanked, "a lone Kicker never flanks")
	assert_lt(worst, Tuning.data.rear_warning_angle_deg, "its seat never goes more than the view's half angle off the look (%.0f degrees)" % worst)
	var wound_up := 0
	for wind: Dictionary in _winds:
		if wind.attacker == kicker:
			wound_up += 1
			assert_false(wind.outside, "every wind-up starts inside the view (bearing %.0f)" % wind.bearing)
	assert_gt(wound_up, 0, "it did attack in 25 s")


func test_a_lone_kicker_does_not_follow_the_look_round() -> void:
	var kicker := _kicker(_ahead(5.0))
	await _ticks(_ticks_for(3.0))
	var gap := Tuning.data.director_seat_gap_deg
	var flanked := false
	var before := _world_bearing(_director.slot_for(kicker))
	for yaw: float in [PI * 0.5, PI]:
		_player.look_yaw = yaw
		for t in _ticks_for(3.0):
			await _ticks(1)
			flanked = flanked or kicker.is_flanking()
		var now := _world_bearing(_director.slot_for(kicker))
		assert_lte(_off(now, before), gap, "look %.0f deg: its seat is where it was in the world (%.0f then %.0f)" % [rad_to_deg(yaw), before, now])
		before = now
	assert_false(flanked, "it was not flanking at any time")


func test_two_kickers_alone_are_not_both_flanking() -> void:
	var first := _kicker(_ahead(4.0, 15.0), "KickerA")
	var second := _kicker(_ahead(4.0, -15.0), "KickerB")
	var both := 0
	var any := 0
	for t in _ticks_for(12.0):
		await _ticks(1)
		if first.is_flanking() and second.is_flanking():
			both += 1
		if first.is_flanking() or second.is_flanking():
			any += 1
	assert_eq(both, 0, "at no tick are both Kickers flanking")
	# The first stays put in front; the second counts it as busy and may flank (frozen or not, the rule).
	assert_gt(any, 0, "one of them does flank: each is the other's busy")


func test_two_kickers_that_are_frozen_do_not_both_flank_either() -> void:
	Tuning.data.ai_frozen = true
	var first := _kicker(_ahead(4.0, 15.0), "KickerA")
	var second := _kicker(_ahead(4.0, -15.0), "KickerB")
	var both := 0
	for t in _ticks_for(6.0):
		await _ticks(1)
		if first.is_flanking() and second.is_flanking():
			both += 1
	assert_eq(both, 0, "at no tick are both Kickers flanking")
	assert_true(first.is_flanking() != second.is_flanking(), "exactly one flanks, and it stays so")


# --- Busy ---------------------------------------------------------------------------------------


func test_a_busy_player_sends_the_kicker_round_after_the_on_delay() -> void:
	Tuning.data.ai_frozen = true
	var kicker := _kicker(_ahead(6.0, -20.0))
	_punk(_ahead(3.5, 15.0))
	var started := _director._clock_s
	var ticks := await _until(func() -> bool: return kicker.is_flanking(), 120)
	assert_gte(ticks, 0, "it flanks")
	var waited := _director._clock_s - started
	assert_gte(waited, Tuning.data.kicker_flank_on_s - 0.05, "not before the on-delay (%.2f s)" % waited)
	assert_lte(ticks, _ticks_for(Tuning.data.kicker_flank_on_s) + TICK_SLACK, "and within it plus a tick or two (%d ticks)" % ticks)
	await _ticks(30)
	var jitter := Tuning.data.director_spread_jitter_deg
	var gap := Tuning.data.director_flank_gap_deg
	assert_gte(_off(_seat_off_look(kicker), 0.0), 180.0 - jitter - 2.0 * gap - 0.5,
			"its seat is the one nearest directly behind the look (%.0f degrees)" % _seat_off_look(kicker))


func test_a_punk_out_of_the_busy_radius_or_the_view_does_not_make_the_player_busy() -> void:
	Tuning.data.ai_frozen = true
	var kicker := _kicker(_ahead(4.0))
	_punk(_ahead(Tuning.data.kicker_flank_busy_radius_m + 1.0, 10.0), "PunkFar")
	_punk(_ahead(3.0, 180.0), "PunkBehind")
	await _ticks(_ticks_for(Tuning.data.kicker_flank_on_s + 1.5))
	assert_false(kicker.is_flanking(), "one too far and one behind him: he is not busy")


func test_a_glance_never_starts_a_flank() -> void:
	Tuning.data.ai_frozen = true
	var kicker := _kicker(_ahead(4.0))
	_punk(_ahead(3.5, 180.0))  # behind him: out of view
	await _ticks(10)
	_player.look_yaw = PI  # it is in view for 0.2 s ...
	var flanked := false
	for t in _ticks_for(0.2):
		await _ticks(1)
		flanked = flanked or kicker.is_flanking()
	_player.look_yaw = 0.0  # ... and he turns away again
	for t in _ticks_for(Tuning.data.kicker_flank_on_s + 1.0):
		await _ticks(1)
		flanked = flanked or kicker.is_flanking()
	assert_false(flanked, "a 0.2 s glance at the Punk never starts the flank")


func test_the_flank_ends_after_the_off_delay_when_the_punk_leaves_the_view() -> void:
	Tuning.data.ai_frozen = true
	var kicker := _kicker(_ahead(4.0, -20.0))
	var punk := _punk(_ahead(3.5, 10.0))
	assert_gte(await _until(func() -> bool: return kicker.is_flanking(), 120), 0, "it flanks first")
	await _ticks(60)
	# He turns round so the Punk leaves the view (the Kicker, frozen, stays where it is).
	_player.look_yaw = PI
	assert_true(_player.is_outside_view(punk.global_position, Tuning.data.rear_warning_angle_deg), "the Punk is out of the view")
	var turned := _director._clock_s
	await _ticks(_ticks_for(Tuning.data.kicker_flank_off_s) - TICK_SLACK)
	assert_true(kicker.is_flanking(), "still flanking just before the off-delay")
	var ticks := await _until(func() -> bool: return not kicker.is_flanking(), 3 * TICK_SLACK + 20)
	assert_gte(ticks, 0, "it stops flanking")
	assert_gte(_director._clock_s - turned, Tuning.data.kicker_flank_off_s - 0.01, "and not before the off-delay")
	# The change of mode reslots it: its seat is now the one nearest where it stands, not behind the look.
	await _ticks(3)
	assert_lte(_off(_world_bearing(_director.slot_for(kicker)), _world_bearing(kicker.global_position)),
			Tuning.data.director_seat_gap_deg + Tuning.data.director_spread_jitter_deg,
			"its seat is by where it stands (%.0f, it stands at %.0f)" % [_world_bearing(_director.slot_for(kicker)), _world_bearing(kicker.global_position)])


func test_a_player_facing_the_kicker_is_not_busy_with_a_punk_in_view_beside_it() -> void:
	Tuning.data.ai_frozen = true
	var kicker := _kicker(_ahead(3.5, 0.0))
	var punk := _punk(_ahead(3.5, 30.0))
	var flanked := false
	for t in _ticks_for(Tuning.data.kicker_flank_on_s + Tuning.data.kicker_flank_off_s + 1.0):
		await _ticks(1)
		flanked = flanked or kicker.is_flanking()
	assert_false(_player.is_outside_view(punk.global_position, Tuning.data.rear_warning_angle_deg), "the Punk is in view")
	assert_false(flanked, "the look on the Kicker, a Punk in view at 30 degrees: it never flanks")


func test_the_look_on_the_punk_sends_the_kicker_round_after_the_on_delay() -> void:
	Tuning.data.ai_frozen = true
	var kicker := _kicker(_ahead(3.5, 30.0))
	_punk(_ahead(3.5, 0.0))
	var started := _director._clock_s
	var ticks := await _until(func() -> bool: return kicker.is_flanking(), 120)
	assert_gte(ticks, 0, "the same two, the look on the Punk: it flanks")
	assert_gte(_director._clock_s - started, Tuning.data.kicker_flank_on_s - 0.05, "not before the on-delay")
	assert_lte(ticks, _ticks_for(Tuning.data.kicker_flank_on_s) + TICK_SLACK, "and within it plus a tick or two (%d ticks)" % ticks)


func test_turning_onto_a_flanking_kicker_stops_its_flank_at_once_with_a_punk_still_in_view() -> void:
	Tuning.data.ai_frozen = true
	var kicker := _kicker(_ahead(3.5, 30.0))
	var punk := _punk(_ahead(3.5, 0.0))
	assert_gte(await _until(func() -> bool: return kicker.is_flanking(), 120), 0, "it flanks first")
	await _ticks(30)
	assert_true(kicker.is_flanking(), "and keeps on flanking while he looks at the Punk")
	_face(kicker.global_position)  # an instant turn onto it: the Punk is now 30 degrees off, still in view
	assert_false(_player.is_outside_view(punk.global_position, Tuning.data.rear_warning_angle_deg), "the Punk is still in view")
	var ticks := await _until(func() -> bool: return not kicker.is_flanking(), _ticks_for(Tuning.data.kicker_flank_faced_off_s) + TICK_SLACK)
	assert_gte(ticks, 0, "it stops flanking within kicker_flank_faced_off_s plus a tick (%d ticks)" % ticks)
	assert_lt(Tuning.data.kicker_flank_faced_off_s, Tuning.data.kicker_flank_off_s, "that is the shorter delay")
	# Held on it from here, the rule holds: it never goes back.
	var again := false
	for t in _ticks_for(Tuning.data.kicker_flank_on_s + 1.0):
		await _ticks(1)
		again = again or kicker.is_flanking()
	assert_false(again, "and it stays unflanked while he faces it")


func test_a_kicker_he_turns_onto_attacks_from_in_view_while_the_punk_is_still_there() -> void:
	var kicker := _kicker(_ahead(3.5, 30.0))
	var punk := _punk(_ahead(3.5, 0.0))
	# Keep the Punk from attacking so the Kicker's attacks are the ones counted.
	punk.set_process(false)
	punk.set_physics_process(false)
	assert_gte(await _until(func() -> bool: return kicker.is_flanking(), 120), 0, "it flanks first")
	# He looks at the Punk until the Kicker is round behind him, then turns onto it and keeps on it.
	var behind := await _until(func() -> bool: return absf(_player.look_bearing_deg(kicker.global_position)) > 120.0, 900)
	assert_gte(behind, 0, "it went round behind him")
	var seen_before := _winds.size()
	var winds_in_view := 0
	for t in _ticks_for(8.0):
		_face(kicker.global_position)
		await _ticks(1)
		for i in range(seen_before, _winds.size()):
			if _winds[i].attacker == kicker and not _winds[i].outside:
				winds_in_view += 1
		seen_before = _winds.size()
		if winds_in_view > 0:
			break
	assert_gt(winds_in_view, 0, "once he faced it, it wound up from inside the view")
	assert_false(kicker.is_flanking(), "not flanking while he faces it")


func test_a_kicker_that_has_a_token_when_it_stops_flanking_keeps_it_and_its_attack_goes_on() -> void:
	var kicker := _kicker(_ahead(3.5, 30.0))
	var punk := _punk(_ahead(3.5, 0.0))
	punk.set_process(false)
	punk.set_physics_process(false)
	assert_gte(await _until(func() -> bool: return kicker.is_flanking(), 120), 0, "it flanks first")
	# He looks at the Punk until the Kicker winds up (behind him, holding its token), then turns round.
	var wound_up := await _until(func() -> bool: return kicker.ai_state == EnemyActor.AiState.WINDUP, 900)
	assert_gte(wound_up, 0, "the Kicker winds up")
	assert_true(_director.debug_token_holders().has(kicker), "holding a token")
	assert_true(kicker.is_flanking(), "and still flanking")
	_face(kicker.global_position)
	await _ticks(TICK_SLACK)
	assert_false(kicker.is_flanking(), "he turned onto it: the flank ended")
	assert_true(_director.debug_token_holders().has(kicker), "it keeps its token")
	assert_eq(kicker.ai_state, EnemyActor.AiState.WINDUP, "and its wind-up goes on")
	var attacked := await _until(func() -> bool: return kicker.ai_state == EnemyActor.AiState.ATTACK, 240)
	assert_gte(attacked, 0, "and its attack goes off (a hit or a whiff)")
	var released := await _until(func() -> bool: return not _director.debug_token_holders().has(kicker), 240)
	assert_gte(released, 0, "the token goes back only when the attack has ended")


func test_the_opportunistic_switch_off_sends_a_lone_kicker_behind_as_in_m5() -> void:
	Tuning.data.kicker_flank_opportunistic = false
	Tuning.data.ai_frozen = true
	var kicker := _kicker(_ahead(5.0))
	await _ticks(30)
	assert_true(kicker.is_flanking(), "flanking with nobody else in the room")
	assert_gte(_off(_seat_off_look(kicker), 0.0), 180.0 - Tuning.data.director_spread_jitter_deg - 0.5, "directly behind the look")


func test_even_spread_keeps_m3s_always_flank() -> void:
	Tuning.data.director_even_spread = true
	Tuning.data.ai_frozen = true
	var kicker := _kicker(_ahead(5.0))
	await _ticks(30)
	assert_true(kicker.is_flanking(), "M3's rule: a Kicker always flanks")


func test_a_kicker_with_no_director_decision_circles_at_the_base_pace() -> void:
	var kicker := _kicker(_ahead(5.0))
	assert_false(kicker.is_flanking(), "the hook defaults to false")
	assert_almost_eq(kicker._circle_mult(), 1.0, 0.0001, "so it circles at the base pace")
	kicker.set_flanking(true)
	assert_almost_eq(kicker._circle_mult(), Tuning.data.kicker_circle_mult, 0.0001, "and flanking at kicker_circle_mult")
