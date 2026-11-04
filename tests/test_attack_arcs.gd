extends GutTest
## Attack arcs (Milestone 5, ARC; docs/milestones/M5-plan.md D1-D6): the director seats each enemy in
## an arc of the circle round the player, centred on the line it engaged with, and the enemy keeps
## to it. Director-level cases use tests/fixtures/stub_enemy.gd (they stand where they are put, in
## POSTURE, so they engage on the first tick) with a real director and a real player; the AI cases
## use real Punks. The attack arcs' numbers (90, 140, 180, 270, 360, the 0.5 s grace) are written
## out here by hand, never read from the tunables, so a changed default is a failing test.

const STUB_ENEMY := preload("res://tests/fixtures/stub_enemy.tscn")
const StubEnemy := preload("res://tests/fixtures/stub_enemy.gd")
const PUNK_SCENE := preload("res://game/enemies/punk/street_punk.tscn")
const WALL_ROOM := preload("res://tests/fixtures/arc_wall_fixture.tscn")
const TWO_FLOOR_ROOM := preload("res://tests/fixtures/two_floor_fixture.tscn")
const Probe := preload("res://tests/bot/readability_probe.gd")

## The player stands at the origin looking along -Z (look_yaw 0): bearing 0 is -Z, +90 is -X.
const NAV_TICKS := 8
## Slack (degrees) on an arc's edge: a seat is on the grid, a body stands where it walked to.
const EDGE_SLACK := 6.0

var _scene: Node3D
var _director: EnemyDirector
var _player: PlayerCharacter


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.data.ai_frozen = false
	Tuning.data.director_even_spread = false  # a Debug value: reset_to_default() leaves it
	TimeController.clear()
	TimeController.debug_scale = 1.0
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = false


func after_each() -> void:
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = true
	Tuning.reset_to_default()
	Tuning.data.director_even_spread = false
	TimeController.clear()


# --- Harness ----------------------------------------------------------------------------------


## A room: a flat floor (or `room`, a fixture with a navmesh), the player at `at` looking along -Z, the
## director. `cap` and `priority` set the Enemies tunables first.
func _setup(room: PackedScene = null, at: Vector3 = Vector3.ZERO, cap: int = 3, priority: float = 1.0) -> void:
	Tuning.data.attacker_cap = cap
	Tuning.data.blind_spot_priority = priority
	_scene = Node3D.new()
	add_child_autofree(_scene)
	if room != null:
		_scene.add_child(room.instantiate())
	else:
		var body := StaticBody3D.new()
		body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(80.0, 1.0, 80.0)
		shape.shape = box
		shape.position = Vector3(0.0, -0.5, 0.0)
		body.add_child(shape)
		_scene.add_child(body)
	_player = PlayerCharacter.new()
	_player.position = at
	_scene.add_child(_player)
	_player.input.scripted = true
	_director = EnemyDirector.new()
	_director.rng_seed = 1
	_scene.add_child(_director)
	await _ticks(NAV_TICKS if room != null else 2)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## The point `radius_m` from the player at world `bearing_deg` (0 is -Z, +90 is -X).
func _at(bearing_deg: float, radius_m: float) -> Vector3:
	return _player.global_position + ViewGeometry.forward(deg_to_rad(bearing_deg)) * radius_m


## A standing enemy of `archetype` at `pos`, asking for a token.
func _stub(archetype: StringName, pos: Vector3, wants: bool = true) -> StubEnemy:
	var enemy := STUB_ENEMY.instantiate() as StubEnemy
	enemy.archetype = archetype
	enemy.name = "%s%d" % [String(archetype).capitalize(), _scene.get_child_count()]
	enemy.position = pos
	enemy.want_token = wants
	enemy.prefers_blind_side = archetype == &"kicker"
	_scene.add_child(enemy)
	return enemy


## `count` Punk stubs at 7 m round `bearing_deg`, one every `gap_ticks` (so the order they engaged in is
## the order of the list).
func _punks(count: int, bearing_deg: float = 0.0, gap_ticks: int = 4) -> Array[StubEnemy]:
	var out: Array[StubEnemy] = []
	for i in count:
		out.append(_stub(&"punk", _at(bearing_deg + float(i) * 3.0, 7.0)))
		await _ticks(gap_ticks)
	return out


## Where the director's seat for `enemy` is, as a bearing from the player (world, degrees).
func _seat_bearing(enemy: EnemyActor) -> float:
	return ViewGeometry.bearing_deg(0.0, _player.global_position, _director.slot_for(enemy))


func _seat_distance(enemy: EnemyActor) -> float:
	var seat := _director.slot_for(enemy)
	return Vector2(seat.x - _player.global_position.x, seat.z - _player.global_position.z).length()


## Degrees between two bearings, 0 to 180.
func _off(a: float, b: float) -> float:
	return absf(wrapf(a - b, -180.0, 180.0))


func _kind_count(enemies: Array[StubEnemy], kind: StringName) -> int:
	var n := 0
	for enemy in enemies:
		if _director.debug_seat_kind(enemy) == kind:
			n += 1
	return n


func _turn_to(deg: float) -> void:
	_player.look_yaw = deg_to_rad(deg)


# --- The engage line (D1) ---------------------------------------------------------------------


func test_a_punk_engaging_behind_the_player_walks_round_to_his_front() -> void:
	await _setup()
	var punk := PUNK_SCENE.instantiate() as StreetPunk
	punk.name = "Punk1"
	punk.position = _at(180.0, 6.0)
	_scene.add_child(punk)
	await _ticks(2)
	assert_true(is_equal_approx(_director.debug_line_of(punk), 0.0), "it engaged at once (inside the engage radius) with the look as its line")
	for i in 900:
		await _ticks(1)
		if _off(ViewGeometry.bearing_deg(0.0, _player.global_position, punk.global_position), 0.0) <= 45.0 + EDGE_SLACK \
				and punk.ai_state == EnemyActor.AiState.POSTURE:
			break
	var bearing := ViewGeometry.bearing_deg(0.0, _player.global_position, punk.global_position)
	assert_lte(_off(bearing, 0.0), 45.0 + EDGE_SLACK, "it squared up inside its 90 degree arc, in front (bearing %.0f)" % bearing)
	assert_false(_player.is_outside_view(punk.global_position, Tuning.data.rear_warning_angle_deg), "in his view")


func test_inside_the_grace_the_line_follows_a_turn_and_after_it_does_not() -> void:
	await _setup()
	var punk := _stub(&"punk", _at(0.0, 5.0))
	await _ticks(2)
	assert_true(is_equal_approx(_director.debug_line_of(punk), 0.0))
	assert_false(_director.is_committed_line(punk), "inside the grace")
	await _ticks(6)
	_turn_to(90.0)
	await _ticks(4)
	assert_almost_eq(_director.debug_line_of(punk), 90.0, 0.01, "a turn inside the grace moves the line")
	await _ticks(32)
	assert_true(_director.is_committed_line(punk), "0.5 s after it engaged the line is committed")
	assert_almost_eq(_director.debug_line_of(punk), 90.0, 0.01)
	_turn_to(-90.0)
	await _ticks(10)
	assert_almost_eq(_director.debug_line_of(punk), 90.0, 0.01, "a turn after the grace does not move it")


func test_turning_your_back_lets_a_committed_punk_attack_from_behind() -> void:
	await _setup()
	var punk := _stub(&"punk", _at(0.0, 3.0))
	await _ticks(40)
	assert_true(_director.is_committed_line(punk))
	_turn_to(180.0)
	await _ticks(120)
	assert_gte(_off(_player.look_bearing_deg(_director.slot_for(punk)), 180.0), 0.0)
	assert_gt(absf(_player.look_bearing_deg(_director.slot_for(punk))), 135.0, "its seat is now behind him (it stayed where it was)")
	assert_eq(_director.debug_seat_kind(punk), &"inner")
	assert_true(punk.has_token, "and it is granted its token there: it hits him from behind")


func test_a_quick_turn_inside_the_grace_never_commits_a_line_early() -> void:
	await _setup()
	var punk := _stub(&"punk", _at(0.0, 5.0))
	await _ticks(2)
	for i in 5:
		_turn_to(80.0 if i % 2 == 0 else -80.0)
		await _ticks(5)
		assert_false(_director.is_committed_line(punk), "turn %d: still inside the grace" % i)
	_turn_to(0.0)
	await _ticks(10)
	assert_true(_director.is_committed_line(punk), "committed once the grace is out")
	assert_almost_eq(_director.debug_line_of(punk), 0.0, 0.01, "to where the look was")


func test_the_enemy_engages_again_when_its_attack_has_ended() -> void:
	await _setup()
	var punk := _stub(&"punk", _at(0.0, 5.0))
	await _ticks(40)
	assert_true(_director.is_committed_line(punk))
	_turn_to(90.0)
	punk.ai_state = EnemyActor.AiState.RECOVER
	punk.set_physics_process(false)  # the stub follows its state otherwise
	await _ticks(2)
	assert_true(is_nan(_director.debug_line_of(punk)), "no line while it recovers")
	punk.ai_state = EnemyActor.AiState.POSTURE
	await _ticks(2)
	assert_almost_eq(_director.debug_line_of(punk), 90.0, 0.01, "engaged again, with the look as it is now")
	assert_false(_director.is_committed_line(punk))


# --- Seats in the arc (D3) --------------------------------------------------------------------


func test_six_punks_three_stand_in_front_and_three_wait_behind_them() -> void:
	await _setup()
	var punks := await _punks(6)
	await _ticks(40)
	assert_eq(_kind_count(punks, &"inner"), 3, "a 90 degree arc seats three")
	assert_eq(_kind_count(punks, &"wait"), 3, "the others wait")
	for punk in punks:
		assert_lte(_off(_seat_bearing(punk), 0.0), 45.0 + EDGE_SLACK, "%s: inside its arc" % punk.name)
		if _director.debug_seat_kind(punk) == &"inner":
			assert_gte(_seat_distance(punk), 2.5 - 0.01, "%s inner: on the posture ring" % punk.name)
			assert_lte(_seat_distance(punk), 4.0 + 0.01)
		else:
			assert_gte(_seat_distance(punk), 5.5 - 0.01, "%s waiting: on the wait ring" % punk.name)
			assert_lte(_seat_distance(punk), 6.5 + 0.01)
	var inner: Array[StubEnemy] = []
	for punk in punks:
		if _director.debug_seat_kind(punk) == &"inner":
			inner.append(punk)
	for a in inner:
		for b in inner:
			if a != b:
				assert_gte(_off(_seat_bearing(a), _seat_bearing(b)), 40.0 - 0.01, "inner seats at least 40 degrees apart")


func test_no_token_comes_from_a_wait_seat_and_the_longest_waiter_takes_a_freed_seat() -> void:
	await _setup(null, Vector3.ZERO, 6)
	var punks := await _punks(6, 0.0, 8)
	await _ticks(60)
	for punk in punks:
		if _director.debug_seat_kind(punk) == &"inner":
			punk.position = _director.slot_for(punk)  # a stub stands where it is put: onto its seat
	await _ticks(10)
	var waiting: Array[StubEnemy] = []
	for punk in punks:
		if _director.debug_seat_kind(punk) == &"wait":
			assert_false(punk.has_token, "%s waits: no token" % punk.name)
			waiting.append(punk)
		else:
			assert_true(punk.has_token, "%s stands in front: a token (cap 6)" % punk.name)
	assert_eq(waiting.size(), 3)
	assert_eq(waiting[0], punks[3], "the first of the three to engage and wait is the fourth to come")
	var freed: StubEnemy = punks[1]
	freed.health = 0.0
	freed.queue_free()
	await _ticks(10)
	assert_eq(_director.debug_seat_kind(punks[3]), &"inner", "the longest waiter takes the seat that freed")
	assert_eq(_director.debug_seat_kind(punks[4]), &"wait")
	assert_eq(_director.debug_seat_kind(punks[5]), &"wait")
	assert_false(punks[3].has_token, "but no token while it still stands out on the wait ring")
	punks[3].position = _director.slot_for(punks[3])
	await _ticks(10)
	assert_true(punks[3].has_token, "it is granted its token once it has walked to the seat")


func test_a_punk_on_the_wait_ring_commits_after_the_grace_and_a_turn_does_not_move_its_seat() -> void:
	await _setup()
	var punks := await _punks(4)
	var waiter: StubEnemy = punks[3]
	waiter.position = _at(0.0, 6.5)
	await _ticks(40)
	assert_eq(_director.debug_seat_kind(waiter), &"wait")
	assert_true(_director.is_committed_line(waiter), "0.5 s after it arrived its line is committed")
	var seat := _director.slot_for(waiter)
	_turn_to(180.0)
	await _ticks(200)
	assert_lt(Vector2(seat.x - _director.slot_for(waiter).x, seat.z - _director.slot_for(waiter).z).length(), 0.01,
			"a 180 degree turn later its seat is where it was")
	assert_eq(_director.debug_seat_kind(waiter), &"wait")


func test_a_veteran_punk_seats_four_in_its_140_degree_arc() -> void:
	await _setup()
	var veterans: Array[StubEnemy] = []
	for i in 5:
		var vet := _stub(&"punk", _at(float(i) * 3.0, 7.0))
		EnemyCatalog.apply_variant(vet, &"punk_veteran")
		veterans.append(vet)
		await _ticks(4)
	await _ticks(40)
	assert_eq(veterans[0].attack_arc_deg(), 140.0, "the veteran's arc")
	assert_eq(_kind_count(veterans, &"inner"), 4, "a 140 degree arc at a gap of 40 degrees seats four")
	assert_eq(_kind_count(veterans, &"wait"), 1)
	for vet in veterans:
		assert_lte(_off(_seat_bearing(vet), 0.0), 70.0 + EDGE_SLACK, "inside the 140 degree arc")


func test_the_arcs_are_the_ones_game_boy_asked_for() -> void:
	await _setup()
	for row: Array in [[&"punk", 90.0], [&"thug", 140.0], [&"bruiser", 180.0], [&"boss", 270.0], [&"kicker", 360.0], [&"stub", 360.0]]:
		var enemy := _stub(row[0], _at(0.0, 5.0), false)
		assert_eq(enemy.attack_arc_deg(), float(row[1]), "%s" % row[0])
	var vet := _stub(&"punk", _at(0.0, 5.0), false)
	assert_eq(vet.attack_arc_deg(), 90.0)
	EnemyCatalog.apply_variant(vet, &"punk_veteran")
	assert_eq(vet.attack_arc_deg(), 140.0, "a variant overrides the archetype's")
	EnemyCatalog.apply_variant(vet, &"punk")
	assert_eq(vet.attack_arc_deg(), 140.0, "an id with no variant leaves it as it is")
	Tuning.data.punk_arc_deg = 120.0
	assert_eq(_stub(&"punk", _at(0.0, 5.0), false).attack_arc_deg(), 120.0, "the tunable is live")


func test_the_variant_tints_the_body_when_it_is_spawned() -> void:
	await _setup()
	var vet := EncounterSpawner.make_enemy(EnemyCatalog.scene(&"punk_veteran"), &"punk_veteran", {})
	assert_not_null(vet)
	assert_eq(vet.attack_arc_deg(), 140.0, "the spawner's own make_enemy() puts the variant on")
	vet.position = _at(0.0, 9.0)
	_scene.add_child(vet)
	await _ticks(2)
	var tint := EnemyCatalog.variant(&"punk_veteran").tint
	assert_eq(vet.rig.paint.color_of(PlaceholderBody.Paint.BODY), Color(tint, 1.0), "the jacket shows the variant's tint")
	var plain := EncounterSpawner.make_enemy(EnemyCatalog.scene(&"punk"), &"punk", {})
	assert_null(plain.variant, "a plain Punk has no variant")
	plain.free()


# --- The Kicker, the Bruiser and the boss (D4) ------------------------------------------------


func test_the_bruiser_stands_at_the_flank_never_behind() -> void:
	await _setup()
	var bruiser := _stub(&"bruiser", _at(180.0, 5.0))
	await _ticks(40)
	assert_lte(_off(_seat_bearing(bruiser), 0.0), 90.0 + EDGE_SLACK, "inside its 180 degree arc (bearing %.0f)" % _seat_bearing(bruiser))
	assert_gt(_off(_seat_bearing(bruiser), 180.0), 45.0, "never behind")


func test_the_kicker_circles_to_directly_behind() -> void:
	await _setup()
	var kicker := _stub(&"kicker", _at(0.0, 5.0))
	# The Punk is in his view inside the busy radius (Milestone 5), so the Kicker flanks.
	var punk := _stub(&"punk", _at(20.0, 3.5))
	await _ticks(70)
	assert_true(kicker.is_flanking(), "the Kicker flanks while the Punk keeps him busy")
	assert_gte(_off(_seat_bearing(kicker), 0.0), 135.0, "the Kicker's seat is behind him (bearing %.0f)" % _seat_bearing(kicker))
	assert_lte(_off(_seat_bearing(punk), 0.0), 45.0 + EDGE_SLACK, "the Punk's is in front")


func test_the_boss_is_never_within_45_degrees_of_directly_behind() -> void:
	await _setup()
	var boss := _stub(&"boss", _at(180.0, 6.0))
	await _ticks(40)
	assert_lte(_off(_seat_bearing(boss), 0.0), 135.0 + EDGE_SLACK, "inside its 270 degree arc (bearing %.0f)" % _seat_bearing(boss))
	assert_gt(_off(_seat_bearing(boss), 180.0), 45.0 - EDGE_SLACK, "not within 45 degrees of behind")


## A boss that just woke in place at `bearing_deg` and a Punk in front, both wanting the one token (cap 1).
func _waking_boss_case(bearing_deg: float) -> Array[StubEnemy]:
	var punk := _stub(&"punk", _at(0.0, 3.0), false)
	var boss := _stub(&"boss", _at(bearing_deg, 3.0), false)
	await _ticks(40)
	boss._resume_frames = 600
	boss.want_token = true
	punk.want_token = true
	await _ticks(4)
	return [boss, punk]


func test_the_boss_keeps_its_wake_in_place_priority_while_it_stands_inside_its_arc() -> void:
	await _setup(null, Vector3.ZERO, 1)
	var pair := await _waking_boss_case(90.0)
	assert_true(pair[0].has_token, "the boss at the flank is served before the queue")
	assert_false(pair[1].has_token)


func test_a_boss_that_woke_behind_the_player_walks_to_a_seat_and_has_no_priority() -> void:
	await _setup(null, Vector3.ZERO, 1, 0.0)  # no blind-spot roll either: this is about the wake priority
	var pair := await _waking_boss_case(180.0)
	assert_false(pair[0].has_token, "directly behind him it is outside its 270 degree arc: no priority")
	assert_true(pair[1].has_token, "the queue goes on")


# --- The blind spot (D5) ----------------------------------------------------------------------


func test_the_blind_spot_priority_is_for_arcs_that_reach_it() -> void:
	await _setup()
	for row: Array in [[&"punk", false], [&"thug", true], [&"bruiser", true], [&"boss", true], [&"kicker", true]]:
		assert_eq(_director.blind_spot_eligible(_stub(row[0], _at(0.0, 5.0), false)), row[1], "%s" % row[0])
	var vet := _stub(&"punk", _at(0.0, 5.0), false)
	EnemyCatalog.apply_variant(vet, &"punk_veteran")
	assert_true(_director.blind_spot_eligible(vet), "a veteran's 140 degrees (70 each way) reach past 55")
	Tuning.data.blind_spot_needs_wide_arc = false
	assert_true(_director.blind_spot_eligible(_stub(&"punk", _at(0.0, 5.0), false)), "off: any enemy, as SPEC section 7 words it")


## An older waiter in view and a newer one out of view (by where each stands): who is granted.
func _blind_case(newer_out_of_view: StringName) -> StubEnemy:
	var older := _stub(&"stub", _at(0.0, 3.0), false)
	var newer := _stub(newer_out_of_view, _at(150.0, 3.0), false)
	await _ticks(40)
	older.want_token = true
	newer.want_token = true
	await _ticks(4)
	return newer if newer.has_token else older


func test_a_punk_out_of_view_does_not_jump_the_queue_but_a_wide_arc_does() -> void:
	await _setup(null, Vector3.ZERO, 1)
	var winner := await _blind_case(&"thug")
	assert_eq(winner.archetype, &"thug", "a Thug out of view goes first (blind-spot priority)")
	assert_true(winner.blind_priority_granted)
	_scene.queue_free()
	await _ticks(2)
	await _setup(null, Vector3.ZERO, 1)
	winner = await _blind_case(&"punk")
	assert_eq(winner.archetype, &"stub", "a Punk out of view waits its turn behind the older waiter")
	assert_false(winner.blind_priority_granted, "no blind roll for a Punk")


func test_with_the_switch_on_a_punk_out_of_view_does_jump_the_queue() -> void:
	Tuning.data.director_even_spread = true
	await _setup(null, Vector3.ZERO, 1)
	var winner := await _blind_case(&"punk")
	assert_eq(winner.archetype, &"punk", "M3: any enemy out of view jumps the queue")
	assert_true(winner.blind_priority_granted)


# --- The A/B switch ---------------------------------------------------------------------------


func test_the_even_spread_switch_brings_back_m3s_director() -> void:
	Tuning.data.director_even_spread = true
	await _setup(null, Vector3.ZERO, 6)
	var punks := await _punks(6, 0.0, 2)
	await _ticks(40)
	assert_eq(_kind_count(punks, &"inner"), 6, "no wait seats: all six are seated on the posture ring")
	var angles: Array[float] = []
	for punk in punks:
		assert_true(is_nan(_director.debug_line_of(punk)), "no engage line")
		angles.append(_seat_bearing(punk))
	angles.sort()
	var widest := wrapf(angles[0] - angles[angles.size() - 1], 0.0, 360.0)
	for i in range(1, angles.size()):
		widest = maxf(widest, angles[i] - angles[i - 1])
	assert_lte(widest, 60.0 + 12.0 * 2.0 + 0.01, "evenly spread all the way round (the widest gap %.0f)" % widest)
	for punk in punks:
		assert_true(punk.has_token, "a token for any waiter (cap 6)")


# --- A wall and an edge (D3) ------------------------------------------------------------------


func test_facing_a_wall_the_arcs_slide_and_no_seat_is_in_the_wall() -> void:
	await _setup(WALL_ROOM, Vector3(0.0, 0.0, 0.0))
	var punks := await _punks_behind(5)
	await _ticks(40)
	var slid := 0
	for punk in punks:
		if _director.debug_arc_slid(punk):
			slid += 1
		var seat := _director.slot_for(punk)
		assert_true(seat.is_finite(), "%s has a seat" % punk.name)
		assert_gte(seat.z, -1.6, "%s: not past the wall (z %.2f)" % [punk.name, seat.z])
		assert_gte(_seat_distance(punk), 2.2, "%s: not within 2.2 m of him" % punk.name)
	assert_gt(slid, 0, "the arcs slid round to where the player's floor has room")
	assert_eq(_director.debug_seat_kind(punks[0]), &"inner")


func _punks_behind(count: int) -> Array[StubEnemy]:
	var out: Array[StubEnemy] = []
	for i in count:
		out.append(_stub(&"punk", Vector3(-2.0 + float(i), 0.0, 6.0)))
		await _ticks(4)
	return out


func test_facing_a_wall_real_punks_never_stick_overlap_or_stand_close_without_a_token() -> void:
	await _setup(WALL_ROOM, Vector3(0.0, 0.0, 0.0), 3)
	var probe := Probe.new()
	probe.auto_tick = false
	probe.attach(_scene, _player)
	probe.start_act("wall")
	var punks: Array[StreetPunk] = []
	for i in 4:
		var punk := PUNK_SCENE.instantiate() as StreetPunk
		punk.name = "Punk%d" % (i + 1)
		punk.position = Vector3(-3.0 + 2.0 * float(i), 0.0, 9.0)
		_scene.add_child(punk)
		punks.append(punk)
	var close_without_token := 0
	for frame in 900:
		await _ticks(1)
		probe.tick()
		_player.health = _player.max_health
		for punk in punks:
			if is_instance_valid(punk) and not punk.has_token and punk.ai_state == EnemyActor.AiState.POSTURE \
					and Vector2(punk.global_position.x, punk.global_position.z).length() < 2.2:
				close_without_token += 1
	var summary := probe.end_act()
	assert_eq(int(summary.metrics.stuck_events), 0, "R13: nobody stuck")
	assert_eq(int(summary.metrics.capsule_overlap_frames), 0, "R7: no two capsules overlap")
	assert_eq(close_without_token, 0, "nobody postures inside 2.2 m without a token")


func test_no_seat_snaps_to_a_floor_4_5_m_below_the_edge() -> void:
	await _setup(TWO_FLOOR_ROOM, Vector3(0.0, 0.0, -3.0))
	var punks: Array[StubEnemy] = []
	for i in 6:
		punks.append(_stub(&"punk", Vector3(-2.5 + float(i), 0.0, 2.0)))
		await _ticks(4)
	await _ticks(40)
	for punk in punks:
		var seat := _director.slot_for(punk)
		assert_true(seat.is_finite(), "%s has a seat" % punk.name)
		assert_lt(absf(seat.y - _player.global_position.y), 0.5, "%s: on the player's floor (y %.2f)" % [punk.name, seat.y])
	_turn_to(180.0)
	await _ticks(120)
	for punk in punks:
		assert_lt(absf(_director.slot_for(punk).y - _player.global_position.y), 0.5, "%s still, after he turned" % punk.name)


func test_a_token_goes_only_to_an_enemy_within_the_ring_plus_the_margin() -> void:
	# Feel (final-feel-02): a Punk promoted from a wait seat was granted its token 6 m out and ran out of
	# chase time short of the player. The numbers (4 m ring, 0.5 m margin) are written out here by hand.
	await _setup(null, Vector3.ZERO, 3)
	var near := _stub(&"punk", _at(0.0, 4.4))
	var far := _stub(&"punk", _at(10.0, 4.8))
	await _ticks(30)
	assert_eq(_director.debug_seat_kind(near), &"inner")
	assert_eq(_director.debug_seat_kind(far), &"inner")
	assert_true(near.has_token, "4.4 m out: granted")
	assert_false(far.has_token, "4.8 m out: not yet")
	far.position = _at(10.0, 4.4)
	await _ticks(10)
	assert_true(far.has_token, "granted once it is within reach")


func test_the_margin_is_a_tunable() -> void:
	Tuning.data.token_grant_margin_m = 2.0
	await _setup(null, Vector3.ZERO, 3)
	var punk := _stub(&"punk", _at(0.0, 5.8))
	await _ticks(30)
	assert_true(punk.has_token, "a 2 m margin reaches 6 m")


func test_a_punk_promoted_from_the_wait_ring_chases_and_attacks_with_no_give_up() -> void:
	# 'Arcs: quick turns' Punk1 (final-feel-02): three Punks stand round a still player and a fourth waits
	# on the wait ring; one dies and the waiter is promoted. It must not give up its chase and the fight
	# must not lull for long.
	await _setup(null, Vector3.ZERO, 3)
	var punks: Array[StreetPunk] = []
	for i in 4:
		var punk := PUNK_SCENE.instantiate() as StreetPunk
		punk.name = "Punk%d" % (i + 1)
		punk.position = _at(-30.0 + 20.0 * float(i), 7.0)
		_scene.add_child(punk)
		punks.append(punk)
		await _ticks(6)
	await _ticks(240)
	var waiter: StreetPunk = null
	for punk in punks:
		if _director.debug_seat_kind(punk) == &"wait":
			waiter = punk
	assert_not_null(waiter, "one Punk waits")
	var dying: StreetPunk = punks[0] if punks[0] != waiter else punks[1]
	dying.health = 0.0
	dying.queue_free()
	var gave_up := 0
	var longest_lull := 0
	var lull := 0
	var swung := false
	var was_engaging: Dictionary = {}
	for tick in 900:
		await _ticks(1)
		_player.health = _player.max_health
		var any_attacking := false
		for punk in punks:
			if not is_instance_valid(punk) or punk.health <= 0.0:
				continue
			if bool(was_engaging.get(punk, false)) and punk.ai_state == EnemyActor.AiState.APPROACH:
				gave_up += 1
			was_engaging[punk] = punk.ai_state == EnemyActor.AiState.ENGAGE
			if punk.ai_state == EnemyActor.AiState.WINDUP or punk.ai_state == EnemyActor.AiState.ATTACK:
				any_attacking = true
				if punk == waiter:
					swung = true
		lull = 0 if any_attacking else lull + 1
		longest_lull = maxi(longest_lull, lull)
	assert_eq(gave_up, 0, "no engage chase gave up")
	assert_true(swung, "the promoted Punk got to swing")
	assert_lte(longest_lull, 150, "no lull longer than 2.5 s with the Punks round a still player")
