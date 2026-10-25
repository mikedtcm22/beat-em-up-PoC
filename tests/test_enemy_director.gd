extends GutTest
## The enemy director (Milestone 3, P1-director; M3-plan Part C section 5, Part A A2.2, A2.10 and
## A3.2): tokens and the cap, the blind-spot priority roll, the revive grace and every reason the
## player cannot be hit, the menu hold, the wind-up gap (readability metrics R1, R2 and R9), the
## timeout and the pruning, and the posture slots (an even spread, no churn, the Kicker behind,
## the navmesh snap). Every enemy here is tests/fixtures/stub_enemy.gd, which stands still, so
## nothing of the real AI can change these tests; the player is a real PlayerCharacter.

const STUB_ENEMY := preload("res://tests/fixtures/stub_enemy.tscn")
const StubEnemy := preload("res://tests/fixtures/stub_enemy.gd")
const StubDirector := preload("res://tests/fixtures/stub_director.gd")

## The player stands at the origin looking along -Z (look_yaw 0): bearing 0 is -Z, +90 is -X.
const AHEAD := 0.0
const BEHIND := 180.0

var _scene: Node3D
var _director: EnemyDirector
var _player: PlayerCharacter
var _starts: Array[int] = []


func before_each() -> void:
	Tuning.reset_to_default()
	TimeController.clear()
	TimeController.debug_scale = 1.0
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = false
	_starts.clear()
	CombatEvents.windup_started.connect(_on_windup_started)


func after_each() -> void:
	if CombatEvents.windup_started.is_connected(_on_windup_started):
		CombatEvents.windup_started.disconnect(_on_windup_started)
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = true
	Tuning.reset_to_default()
	TimeController.clear()


func _on_windup_started(_attacker: Node3D, _move: MoveData) -> void:
	_starts.append(Engine.get_physics_frames())


# --- Harness ----------------------------------------------------------------------------


## A fresh room: a floor, the player at the origin, the director. `cap` and `priority` set the
## Enemies tunables first.
func _setup(cap: int = 3, priority: float = 1.0, seed_value: int = 1) -> void:
	Tuning.data.attacker_cap = cap
	Tuning.data.blind_spot_priority = priority
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
	_director.rng_seed = seed_value
	_scene.add_child(_director)
	await _ticks(2)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## A point `radius_m` from the origin, where the player stands, at `bearing_deg` off a look
## along -Z (look_yaw 0: 0 is -Z, +90 is -X).
func _at(bearing_deg: float, radius_m: float) -> Vector3:
	return ViewGeometry.forward(deg_to_rad(bearing_deg)) * radius_m


## A standing-still enemy at `pos`. `wants` says whether it asks for a token.
func _stub(pos: Vector3, wants: bool = true) -> StubEnemy:
	var enemy := STUB_ENEMY.instantiate() as StubEnemy
	enemy.name = "Stub%d" % _scene.get_child_count()
	enemy.position = pos
	enemy.want_token = wants
	_scene.add_child(enemy)
	return enemy


## `count` enemies spread over `bearings` (cycled), 3 m out, 2 m apart in angle at least.
func _crowd(count: int, bearings: Array = [AHEAD, 90.0, -90.0, 45.0, -45.0, 135.0]) -> Array[StubEnemy]:
	var out: Array[StubEnemy] = []
	for i in count:
		out.append(_stub(_at(float(bearings[i % bearings.size()]) + 7.0 * float(i / bearings.size()), 3.0)))
	return out


## Stop the player's own simulation so a state set by hand stays (a test of what the director
## does while the player is closed).
func _freeze_player() -> void:
	_player.set_physics_process(false)


## director_min_windup_gap_s in physics ticks.
func _gap_ticks() -> int:
	return ceili(Tuning.data.director_min_windup_gap_s * float(Engine.physics_ticks_per_second))


func _holders() -> Array[EnemyActor]:
	return _director.debug_token_holders()


## Run grants one at a time (cap 1): each token is released at once; returns who got each as an
## index into `stubs` (-1 = not in it).
func _grant_sequence(stubs: Array, rounds: int) -> Array[int]:
	var seq: Array[int] = []
	var guard := 0
	while seq.size() < rounds and guard < rounds * 4:
		guard += 1
		await _ticks(1)
		for holder in _holders():
			seq.append(stubs.find(holder))
			_director.release_token(holder)
	return seq


## The flat angle (degrees, look-relative) of a slot as the player sees it.
func _bearing_of(pos: Vector3) -> float:
	return _player.look_bearing_deg(pos)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The biggest gap (degrees) between neighbouring angles around the circle.
func _max_gap(angles: Array) -> float:
	var sorted := angles.duplicate()
	sorted.sort()
	var gap := 0.0
	for i in sorted.size():
		var next: float = sorted[(i + 1) % sorted.size()]
		var here: float = sorted[i]
		gap = maxf(gap, fposmod(next - here, 360.0) if sorted.size() > 1 else 360.0)
	return gap


# --- Tokens and the cap ----------------------------------------------------------------------


func test_the_cap_limits_the_holders_and_a_release_lets_the_next_in() -> void:
	await _setup(3, 0.0)
	var stubs := _crowd(6)
	await _ticks(3)
	assert_eq(_holders(), [stubs[0], stubs[1], stubs[2]] as Array[EnemyActor], "the first three in line hold")
	assert_eq(_director.debug_waiting(), [stubs[3], stubs[4], stubs[5]] as Array[EnemyActor], "the rest wait in order")
	assert_true(stubs[0].has_token and not stubs[3].has_token, "the tokens are on the enemies")
	assert_eq(_director.attacker_cap(), 3)
	_director.release_token(stubs[0])
	assert_false(stubs[0].has_token, "a release takes the token back")
	await _ticks(3)
	assert_eq(_holders().size(), 3, "the freed place is taken at once")
	assert_true(_holders().has(stubs[3]), "by the longest waiting, not the one that just let go")
	assert_false(_holders().has(stubs[0]))
	assert_eq(_director.debug_waiting().back(), stubs[0], "the released enemy queues up again, last")


func test_cap_zero_is_unlimited() -> void:
	await _setup(0, 0.0)
	_crowd(6)
	await _ticks(3)
	assert_eq(_holders().size(), 6, "no limit: everyone who wants one holds one")
	assert_true(_director.debug_waiting().is_empty())
	assert_eq(_director.attacker_cap(), 0)


func test_the_longest_waiting_goes_first_whatever_the_tree_order() -> void:
	await _setup(1, 0.0)
	var late_in_tree := _stub(_at(AHEAD, 3.0), false)
	var early_in_tree := _stub(_at(45.0, 3.0), false)
	var blocker := _stub(_at(-45.0, 3.0), true)
	await _ticks(3)
	assert_eq(_holders(), [blocker] as Array[EnemyActor])
	blocker.want_token = false
	early_in_tree.want_token = true
	await _ticks(10)
	late_in_tree.want_token = true
	await _ticks(10)
	assert_eq(_director.debug_waiting(), [early_in_tree, late_in_tree] as Array[EnemyActor], "by how long each has wanted one")
	_director.release_token(blocker)
	await _ticks(3)
	assert_eq(_holders(), [early_in_tree] as Array[EnemyActor], "the one that waited longest")


func test_the_read_api_is_exact() -> void:
	await _setup(2, 0.0)
	var stubs := _crowd(3)
	await _ticks(3)
	assert_eq(_director.debug_ring(), Vector2(Tuning.data.posture_ring_min_m, Tuning.data.posture_ring_max_m))
	assert_eq(_holders().size(), 2)
	assert_eq(_director.debug_waiting(), [stubs[2]] as Array[EnemyActor])
	assert_eq(_director.debug_slot_of(stubs[2]), _director.slot_for(stubs[2]))
	assert_ne(_director.debug_slot_of(stubs[2]), Vector3.INF, "a waiting enemy has a slot")
	var stranger := EnemyActor.new()
	assert_eq(_director.slot_for(stranger), Vector3.INF, "an enemy it does not know has none")
	stranger.free()
	stubs[0].free()
	assert_false(_holders().has(null), "a freed holder is never listed")
	assert_eq(_holders().size(), 1)


# --- Blind-spot priority (readability metric R9) ----------------------------------------------


func test_blind_priority_one_always_lets_a_blind_waiter_jump_the_queue() -> void:
	await _setup(1, 1.0)
	var old_in_view := _stub(_at(0.0, 3.0), false)
	var blocker := _stub(_at(45.0, 3.0), true)
	await _ticks(3)
	assert_eq(_holders(), [blocker] as Array[EnemyActor])
	old_in_view.want_token = true
	await _ticks(20)
	var blind := _stub(_at(BEHIND, 3.0), true)
	await _ticks(3)
	blocker.want_token = false
	_director.release_token(blocker)
	await _ticks(3)
	assert_eq(_holders(), [blind] as Array[EnemyActor], "the blind enemy, though the in-view one waited longer")
	assert_true(blind.blind_priority_granted, "its grant says so (F3)")
	_director.release_token(blind)
	blind.want_token = false
	await _ticks(3)
	assert_eq(_holders(), [old_in_view] as Array[EnemyActor], "then the in-view one")
	assert_false(old_in_view.blind_priority_granted)


func test_at_priority_one_at_least_90_percent_of_grants_go_to_blind_waiters() -> void:
	await _setup(1, 1.0)
	var stubs: Array = [_stub(_at(BEHIND, 3.0)), _stub(_at(150.0, 3.0)),
			_stub(_at(AHEAD, 3.0)), _stub(_at(-30.0, 3.0))]
	await _ticks(2)
	var seq := await _grant_sequence(stubs, 40)
	assert_eq(seq.size(), 40)
	var blind_grants := 0
	for who in seq:
		if who in [0, 1]:
			blind_grants += 1
	assert_gte(float(blind_grants) / float(seq.size()), 0.9, "R9: both kinds waited at every grant")
	assert_false(seq.has(2) or seq.has(3), "in fact the in-view pair never got one while blind ones waited")


func test_priority_zero_ignores_the_blind_spot_and_goes_by_age() -> void:
	await _setup(1, 0.0)
	var stubs: Array = [_stub(_at(AHEAD, 3.0)), _stub(_at(BEHIND, 3.0)),
			_stub(_at(45.0, 3.0)), _stub(_at(150.0, 3.0))]
	await _ticks(2)
	var seq := await _grant_sequence(stubs, 8)
	assert_eq(seq, [0, 1, 2, 3, 0, 1, 2, 3] as Array[int], "round robin in age order, blind or not")
	for stub: StubEnemy in stubs:
		assert_false(stub.blind_priority_granted)


func test_the_priority_roll_is_deterministic_per_seed() -> void:
	await _setup(1, 0.5, 11)
	var first := await _grant_sequence(_crowd_mixed(), 30)
	_scene.queue_free()
	await _ticks(2)
	await _setup(1, 0.5, 11)
	var second := await _grant_sequence(_crowd_mixed(), 30)
	assert_eq(first, second, "the same seed rolls the same sequence")
	_scene.queue_free()
	await _ticks(2)
	await _setup(1, 0.5, 12)
	var other := await _grant_sequence(_crowd_mixed(), 30)
	assert_ne(first, other, "another seed rolls another one")
	assert_true(first.has(1) or first.has(3), "a half priority lets blind enemies through")
	assert_true(first.has(0) or first.has(2), "and is not all or nothing: in-view ones get turns")


func _crowd_mixed() -> Array:
	return [_stub(_at(AHEAD, 3.0)), _stub(_at(BEHIND, 3.0)), _stub(_at(45.0, 3.0)), _stub(_at(150.0, 3.0))]


# --- The player must be hittable ------------------------------------------------------------------


func test_no_grants_while_the_player_is_ko_downed_flying_or_held() -> void:
	await _setup(3, 0.0)
	_freeze_player()
	var stubs := _crowd(3)
	var closed: Array[Callable] = [
		func() -> void: _player.health = 0.0,
		func() -> void: _player.state = CombatTypes.ActorState.DOWNED,
		func() -> void: _player.state = CombatTypes.ActorState.LAUNCHED,
		func() -> void: _player.state = CombatTypes.ActorState.THROWN,
		func() -> void: _player.state = CombatTypes.ActorState.GRABBED,
	]
	var open: Callable = func() -> void:
		_player.health = _player.max_health
		_player.state = CombatTypes.ActorState.FREE
	for i in closed.size():
		closed[i].call()
		await _ticks(4)
		assert_true(_holders().is_empty(), "closed state %d: no tokens" % i)
		assert_false(stubs[0].has_token)
		assert_eq(_director.debug_waiting().size(), 3, "they keep waiting (state %d)" % i)
		open.call()
		await _ticks(3)
		assert_eq(_holders().size(), 3, "open again: granted (state %d)" % i)
		for stub in stubs:
			_director.release_token(stub)
		await _ticks(1)


func test_no_grants_while_the_player_is_invulnerable_but_the_tokens_in_hand_stay() -> void:
	await _setup(2, 0.0)
	_freeze_player()
	var stubs := _crowd(3)
	await _ticks(3)
	assert_eq(_holders().size(), 2)
	_player._invuln_frames = 600
	await _ticks(3)
	assert_eq(_holders().size(), 2, "a dodge or a get-up does not take tokens back")
	_director.release_token(stubs[0])
	await _ticks(3)
	assert_eq(_holders().size(), 1, "but none are given while the player cannot be hit")
	_player._invuln_frames = 0
	await _ticks(3)
	assert_eq(_holders().size(), 2)


func test_no_grants_without_a_player() -> void:
	await _setup(3, 0.0)
	_player.remove_from_group(&"player")
	_crowd(3)
	await _ticks(4)
	assert_true(_holders().is_empty(), "nobody to attack")
	_player.add_to_group(&"player")
	await _ticks(3)
	assert_eq(_holders().size(), 3)


func test_the_revive_grace_holds_the_tokens_back() -> void:
	await _setup(3, 0.0)
	Tuning.data.director_revive_grace_s = 0.5
	_crowd(3)
	await _ticks(3)
	assert_eq(_holders().size(), 3)
	_player.health = 0.0
	_freeze_player()
	await _ticks(3)
	assert_true(_holders().is_empty(), "taken back when the player went down")
	_player.health = _player.max_health
	CombatEvents.revived.emit(_player)
	await _ticks(20)
	assert_true(_holders().is_empty(), "no tokens in the grace after the revive")
	await _ticks(20)
	assert_eq(_holders().size(), 3, "the grace is over")
	CombatEvents.revived.emit(_stub(_at(BEHIND, 3.0), false))
	await _ticks(3)
	assert_eq(_holders().size(), 3, "another actor's revive is none of its business")


func test_a_token_is_taken_back_when_the_player_closes_before_the_windup() -> void:
	await _setup(3, 0.0)
	_freeze_player()
	var stubs := _crowd(3)
	await _ticks(3)
	assert_eq(_holders().size(), 3)
	_player.state = CombatTypes.ActorState.DOWNED
	await _ticks(2)
	assert_true(_holders().is_empty(), "all taken back")
	for stub in stubs:
		assert_false(stub.has_token, "the enemy itself lost it")


func test_a_token_whose_windup_has_started_is_never_taken_back() -> void:
	await _setup(2, 0.0)
	_freeze_player()
	var stubs := _crowd(2)
	for stub in stubs:
		stub.attack_on_token = true
	await _ticks(4)
	var winding: StubEnemy
	for stub in stubs:
		if stub.state == CombatTypes.ActorState.WINDUP:
			winding = stub
	assert_not_null(winding, "one has begun its wind-up")
	_player.health = 0.0
	await _ticks(3)
	assert_true(_holders().has(winding), "its token stays: the count of attackers stays honest")
	assert_eq(winding.state, CombatTypes.ActorState.WINDUP)


func test_a_holder_flying_a_move_keeps_its_token_until_the_move_is_gone() -> void:
	await _setup(1, 0.0)
	var kicker := _stub(_at(AHEAD, 3.0), true)
	kicker.releases_token = false
	var next := _stub(_at(90.0, 3.0), true)
	await _ticks(3)
	assert_eq(_holders(), [kicker] as Array[EnemyActor])
	kicker.set_physics_process(false)
	kicker.state = CombatTypes.ActorState.AIRBORNE
	kicker.current_move = kicker.attack
	await _ticks(3)
	assert_eq(_holders(), [kicker] as Array[EnemyActor], "a jump kick in flight is still an attack")
	kicker.current_move = null
	await _ticks(3)
	assert_eq(_holders(), [next] as Array[EnemyActor], "airborne with no move is a reaction: the token goes")


# --- F1 and F4 hold the fight ---------------------------------------------------------------------


func test_an_open_menu_holds_the_director() -> void:
	await _setup(3, 0.0)
	var stubs := _crowd(5)
	await _ticks(3)
	assert_eq(_holders().size(), 3)
	GameInput.menu_open = true
	await _ticks(3)
	assert_true(_holders().is_empty(), "unstarted tokens are taken back")
	for stub in stubs:
		assert_false(stub.has_token)
	await _ticks(20)
	assert_true(_holders().is_empty(), "and none are granted while it is open")
	GameInput.menu_open = false
	await _ticks(3)
	assert_eq(_holders().size(), 3, "the fight goes on when it closes")


func test_an_open_menu_lets_an_attack_already_winding_up_finish() -> void:
	await _setup(2, 0.0)
	var stubs := _crowd(2)
	for stub in stubs:
		stub.attack_on_token = true
	await _ticks(4)
	var winding: Array[StubEnemy] = []
	for stub in stubs:
		if stub.state == CombatTypes.ActorState.WINDUP:
			winding.append(stub)
	assert_eq(winding.size(), 1, "only the first wind-up has begun (the gap holds the other)")
	GameInput.menu_open = true
	await _ticks(3)
	assert_true(_holders().has(winding[0]), "it keeps its token")
	assert_eq(winding[0].state, CombatTypes.ActorState.WINDUP, "and keeps winding up")
	var other: StubEnemy = stubs[1] if stubs[0] == winding[0] else stubs[0]
	assert_false(other.has_token, "the other had not started: its token is back")
	await _ticks(60)
	assert_eq(winding[0].state, CombatTypes.ActorState.FREE, "the attack finished")
	assert_false(winding[0].has_token, "and gave its token back")
	assert_ne(other.state, CombatTypes.ActorState.WINDUP, "nobody wound up behind the open menu")


func test_frozen_ai_grants_nothing() -> void:
	await _setup(3, 0.0)
	Tuning.data.ai_frozen = true
	_crowd(3)
	await _ticks(5)
	assert_true(_holders().is_empty())
	Tuning.data.ai_frozen = false
	await _ticks(3)
	assert_eq(_holders().size(), 3)


# --- The wind-up gap (R1, R2) --------------------------------------------------------------------


func test_may_start_windup_holds_a_second_one_back_for_the_gap() -> void:
	await _setup(3, 0.0)
	var stubs := _crowd(3)
	await _ticks(3)
	assert_eq(_holders().size(), 3)
	assert_true(_director.may_start_windup(stubs[0]), "the first goes")
	assert_false(_director.may_start_windup(stubs[1]), "a second asking the same tick must wait")
	var gap_ticks := _gap_ticks()
	var waited := 0
	while not _director.may_start_windup(stubs[1]) and waited < 200:
		await _ticks(1)
		waited += 1
	assert_gte(waited, gap_ticks, "never sooner than the gap")
	assert_lte(waited, gap_ticks + 1, "and no later than a tick of slack")
	assert_false(_director.may_start_windup(stubs[2]), "the third waits behind the second")


func test_may_start_windup_refuses_what_the_director_did_not_grant() -> void:
	await _setup(1, 0.0)
	var holder := _stub(_at(AHEAD, 3.0), true)
	var waiter := _stub(_at(90.0, 3.0), true)
	await _ticks(3)
	assert_eq(_holders(), [holder] as Array[EnemyActor])
	assert_false(_director.may_start_windup(waiter), "no token, no go")
	GameInput.menu_open = true
	assert_false(_director.may_start_windup(holder), "not while a menu holds the fight")
	GameInput.menu_open = false
	_freeze_player()
	_player.health = 0.0
	assert_false(_director.may_start_windup(holder), "not at a player who is down")
	_player.health = _player.max_health
	assert_true(_director.may_start_windup(holder))


func test_a_forced_windup_counts_toward_the_gap_too() -> void:
	await _setup(2, 0.0)
	var forced := _stub(_at(AHEAD, 3.0), false)
	var holder := _stub(_at(90.0, 3.0), true)
	await _ticks(3)
	assert_eq(_holders(), [holder] as Array[EnemyActor])
	forced.force_attack()
	await _ticks(2)
	assert_eq(forced.state, CombatTypes.ActorState.WINDUP, "a bot forced one without a token")
	assert_false(_director.may_start_windup(holder), "the token holder still has to wait the gap")
	await _ticks(_gap_ticks() + 3)
	assert_true(_director.may_start_windup(holder))


func test_wind_ups_start_at_least_the_gap_apart_and_never_more_than_the_cap_attack() -> void:
	await _setup(2, 0.0)
	var stubs := _crowd(4)
	for stub in stubs:
		stub.attack_on_token = true
	var most := 0
	for i in 420:
		await _ticks(1)
		var attacking := 0
		for stub in stubs:
			if stub.state == CombatTypes.ActorState.WINDUP or stub.state == CombatTypes.ActorState.ATTACK:
				attacking += 1
		most = maxi(most, attacking)
	assert_gte(_starts.size(), 6, "several attacks ran (%d)" % _starts.size())
	var gap_ticks := _gap_ticks()
	var least := 1000000
	for i in range(1, _starts.size()):
		least = mini(least, _starts[i] - _starts[i - 1])
	assert_gte(least, gap_ticks, "R2: the least gap between two wind-up starts (frames)")
	assert_eq(most, 2, "R1: the cap is reached and never exceeded")


func test_slow_motion_stretches_the_gap_with_it() -> void:
	await _setup(2, 0.0)
	var stubs := _crowd(2)
	await _ticks(3)
	TimeController.debug_scale = 0.25
	assert_true(_director.may_start_windup(stubs[0]))
	await _ticks(_gap_ticks() + 3)
	assert_false(_director.may_start_windup(stubs[1]), "the same wall time is a quarter of the sim time")
	await _ticks(_gap_ticks() * 3 + 6)
	assert_true(_director.may_start_windup(stubs[1]))


# --- Timeout and pruning ---------------------------------------------------------------------------


func test_a_holder_that_never_attacks_loses_the_token_after_the_timeout() -> void:
	await _setup(1, 0.0)
	Tuning.data.director_token_timeout_s = 0.5
	var first := _stub(_at(AHEAD, 3.0), true)
	var second := _stub(_at(90.0, 3.0), true)
	await _ticks(3)
	assert_eq(_holders(), [first] as Array[EnemyActor])
	await _ticks(20)
	assert_eq(_holders(), [first] as Array[EnemyActor], "still inside the timeout")
	await _ticks(25)
	assert_eq(_holders(), [second] as Array[EnemyActor], "taken back after it; the waiting one is next")
	assert_false(first.has_token)


func test_dead_and_freed_holders_are_pruned_and_their_place_reused() -> void:
	await _setup(2, 0.0)
	var stubs := _crowd(4)
	await _ticks(3)
	assert_eq(_holders(), [stubs[0], stubs[1]] as Array[EnemyActor])
	stubs[0].health = 0.0
	await _ticks(2)
	assert_false(_holders().has(stubs[0]), "a dead holder is dropped")
	assert_false(stubs[0].has_token, "and its token revoked")
	assert_true(_holders().has(stubs[2]), "the next in line took its place")
	stubs[1].queue_free()
	await _ticks(3)
	assert_eq(_holders().size(), 2, "a freed holder is gone and replaced")
	assert_true(_holders().has(stubs[3]))
	assert_false(_director.debug_waiting().has(stubs[0]), "the dead do not wait")


func test_a_holder_that_is_hit_loses_the_token_even_if_it_forgot_to_give_it_back() -> void:
	await _setup(1, 0.0)
	var victim := _stub(_at(AHEAD, 1.0), true)
	victim.releases_token = false
	var next := _stub(_at(90.0, 3.0), true)
	await _ticks(3)
	assert_eq(_holders(), [victim] as Array[EnemyActor])
	var hit := HitInfo.new()
	hit.attacker = _player
	hit.victim = victim
	hit.damage = 3.0
	hit.reaction = CombatTypes.Reaction.FLINCH
	hit.direction = Vector3.FORWARD
	hit.contact_point = victim.global_position + Vector3.UP
	victim.receive_hit(hit)
	assert_ne(victim.state, CombatTypes.ActorState.FREE, "it is reeling")
	await _ticks(2)
	assert_false(victim.has_token, "the director took the token")
	assert_eq(_holders(), [next] as Array[EnemyActor], "and gave it to the next")


func test_the_enemy_gives_the_token_back_on_its_own_and_the_book_is_kept() -> void:
	await _setup(1, 0.0)
	var stubs := _crowd(2)
	stubs[0].attack_on_token = true
	await _ticks(4)
	assert_eq(stubs[0].state, CombatTypes.ActorState.WINDUP)
	await _ticks(60)
	assert_false(stubs[0].has_token, "its attack ended: it released the token")
	assert_eq(_holders(), [stubs[1]] as Array[EnemyActor], "the other enemy is up next")


func test_the_stub_director_is_not_driven_by_the_real_loop() -> void:
	await _setup(3, 0.0)
	_director.queue_free()
	await _ticks(2)
	var stub_director := StubDirector.new()
	_scene.add_child(stub_director)
	var stubs := _crowd(3)
	await _ticks(10)
	assert_true(stub_director.debug_token_holders().is_empty(), "the fixture decides nothing on its own")
	assert_false(stubs[0].has_token)
	assert_eq(stubs[0].posture_slot, Vector3.INF)
	stub_director.give_token(stubs[1])
	await _ticks(10)
	assert_true(stubs[1].has_token, "and nothing takes back what a test hands out")


func test_an_ensured_director_with_no_player_just_waits() -> void:
	await _setup(3, 0.0)
	_director.queue_free()
	_player.queue_free()
	await _ticks(2)
	var ensured := EnemyDirector.ensure(_scene)
	var stubs := _crowd(3)
	await _ticks(10)
	assert_true(ensured.debug_token_holders().is_empty())
	assert_eq(ensured.debug_waiting().size(), 3, "they are waiting for somebody to attack")
	assert_eq(ensured.slot_for(stubs[0]), Vector3.INF, "and have nowhere to stand yet")


func test_leaving_the_tree_returns_every_token() -> void:
	await _setup(3, 0.0)
	var stubs := _crowd(3)
	await _ticks(3)
	assert_eq(_holders().size(), 3)
	_scene.remove_child(_director)
	for stub in stubs:
		assert_false(stub.has_token, "no enemy keeps a token nobody can take back")
	_director.free()


# --- Posture slots (spread) --------------------------------------------------------------------------


func test_n_enemies_are_spread_evenly_around_the_player() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for n in range(1, 7):
		await _setup(3, 1.0)
		var stubs: Array[StubEnemy] = []
		for i in n:
			stubs.append(_stub(_at(rng.randf_range(-180.0, 180.0), 3.0 + 0.2 * float(i)), false))
		await _ticks(4)
		var angles: Array = []
		for stub in stubs:
			var slot := _director.slot_for(stub)
			assert_ne(slot, Vector3.INF, "n=%d: every enemy has a slot" % n)
			assert_eq(stub.posture_slot, slot, "n=%d: and has been told it" % n)
			var d := _flat_distance(slot, _player.global_position)
			assert_gte(d, Tuning.data.posture_ring_min_m - 0.001, "n=%d: on the ring, not inside it" % n)
			assert_lte(d, Tuning.data.posture_ring_max_m + 0.001, "n=%d: nor outside it" % n)
			angles.append(_bearing_of(slot))
		var allowed := 360.0 / float(n) + 2.0 * Tuning.data.director_spread_jitter_deg + 0.01
		assert_lte(_max_gap(angles), allowed, "n=%d: no gap wider than an even share plus the jitter" % n)
		_scene.queue_free()
		await _ticks(2)


func test_a_settled_crowd_is_not_reassigned() -> void:
	await _setup(0, 1.0)
	Tuning.data.director_reslot_s = 0.2
	var stubs: Array[StubEnemy] = []
	for angle in [10.0, 100.0, 170.0, -120.0]:
		stubs.append(_stub(_at(angle, 3.0), false))
	await _ticks(4)
	var first: Array[Vector3] = []
	for stub in stubs:
		first.append(_director.slot_for(stub))
		stub.global_position = Vector3(_director.slot_for(stub).x, 0.0, _director.slot_for(stub).z)
	await _ticks(70)
	for i in stubs.size():
		assert_lt(_flat_distance(_director.slot_for(stubs[i]), first[i]), 0.01,
				"enemy %d keeps its slot through five reassignments" % i)


func test_the_slots_follow_a_player_who_moved_but_not_one_who_shuffled() -> void:
	await _setup(0, 1.0)
	Tuning.data.director_reslot_s = 10.0
	Tuning.data.director_reslot_move_m = 1.0
	var stubs := _crowd(3)
	for stub in stubs:
		stub.want_token = false
	await _ticks(4)
	var before: Array[Vector3] = []
	for stub in stubs:
		before.append(_director.slot_for(stub))
	_player.global_position += Vector3(0.6, 0.0, 0.0)
	await _ticks(3)
	for i in stubs.size():
		assert_eq(_director.slot_for(stubs[i]), before[i], "0.6 m is inside the move threshold")
	_player.global_position += Vector3(1.4, 0.0, 0.0)
	await _ticks(3)
	for i in stubs.size():
		assert_ne(_director.slot_for(stubs[i]), before[i], "2 m is not")
		var d := _flat_distance(_director.slot_for(stubs[i]), _player.global_position)
		assert_gte(d, Tuning.data.posture_ring_min_m - 0.001, "and the new slot is on the ring around him")
		assert_lte(d, Tuning.data.posture_ring_max_m + 0.001)


func test_a_new_enemy_gets_a_slot_at_once_and_the_crowd_makes_room() -> void:
	await _setup(0, 1.0)
	Tuning.data.director_reslot_s = 10.0
	var stubs := _crowd(2)
	for stub in stubs:
		stub.want_token = false
	await _ticks(4)
	var late := _stub(_at(BEHIND, 8.0), false)
	await _ticks(3)
	assert_ne(_director.slot_for(late), Vector3.INF, "no waiting for the timer")
	var angles: Array = []
	for stub in [stubs[0], stubs[1], late]:
		angles.append(_bearing_of(_director.slot_for(stub)))
	assert_lte(_max_gap(angles), 120.0 + 2.0 * Tuning.data.director_spread_jitter_deg + 0.01, "three evenly spread")


func test_a_token_holder_keeps_its_slot_and_leaves_the_spread() -> void:
	await _setup(1, 0.0)
	var stubs := _crowd(3)
	await _ticks(4)
	var holder: EnemyActor = _holders()[0]
	var kept := _director.slot_for(holder)
	assert_ne(kept, Vector3.INF)
	var angles: Array = []
	for stub in stubs:
		if stub != holder:
			angles.append(_bearing_of(_director.slot_for(stub)))
	assert_lte(_max_gap(angles), 180.0 + 2.0 * Tuning.data.director_spread_jitter_deg + 0.01, "the two others share the circle")
	await _ticks(30)
	assert_eq(_director.slot_for(holder), kept, "the slot it left stays where it backs off to")
	_director.release_token(holder)
	await _ticks(3)
	assert_ne(_director.slot_for(holder), Vector3.INF)


func test_a_dead_enemy_has_no_slot_and_the_rest_close_ranks() -> void:
	await _setup(0, 1.0)
	var stubs := _crowd(4)
	for stub in stubs:
		stub.want_token = false
	await _ticks(4)
	stubs[0].health = 0.0
	await _ticks(3)
	assert_eq(_director.slot_for(stubs[0]), Vector3.INF)
	var angles: Array = []
	for i in range(1, 4):
		angles.append(_bearing_of(_director.slot_for(stubs[i])))
	assert_lte(_max_gap(angles), 120.0 + 2.0 * Tuning.data.director_spread_jitter_deg + 0.01)


func test_a_kicker_takes_the_slot_directly_behind_the_look() -> void:
	await _setup(0, 1.0)
	var jitter := Tuning.data.director_spread_jitter_deg
	for others in [0, 1, 2, 4]:
		var kicker := _stub(_at(60.0, 3.5), false)
		kicker.prefers_blind_side = true
		var stubs: Array[StubEnemy] = [kicker]
		for i in others:
			stubs.append(_stub(_at(-100.0 + 50.0 * float(i), 3.0), false))
		await _ticks(4)
		var b := _bearing_of(_director.slot_for(kicker))
		assert_gte(absf(b), 180.0 - jitter - 0.5, "with %d others: the Kicker's slot is behind (%.1f deg)" % [others, b])
		for stub in stubs:
			stub.queue_free()
		await _ticks(3)
	# The look turns: the Kicker's slot swings round behind the new look.
	var turning := _stub(_at(60.0, 3.5), false)
	turning.prefers_blind_side = true
	var mate := _stub(_at(-100.0, 3.0), false)
	Tuning.data.director_reslot_s = 0.2
	_player.look_yaw = PI * 0.5
	await _ticks(20)
	assert_gte(absf(_bearing_of(_director.slot_for(turning))), 180.0 - jitter - 0.5, "behind the look as it is now")
	assert_not_null(mate)


func test_two_kickers_take_the_two_rearmost_slots() -> void:
	await _setup(0, 1.0)
	var jitter := Tuning.data.director_spread_jitter_deg
	var kickers: Array[StubEnemy] = [_stub(_at(60.0, 3.5), false), _stub(_at(-60.0, 3.5), false)]
	var others: Array[StubEnemy] = [_stub(_at(AHEAD, 3.0), false), _stub(_at(90.0, 3.0), false)]
	for kicker in kickers:
		kicker.prefers_blind_side = true
	await _ticks(4)
	var rearmost := 0.0
	for kicker in kickers:
		var b := absf(_bearing_of(_director.slot_for(kicker)))
		assert_gte(b, 90.0 - jitter - 0.5, "a Kicker is at the side or behind (%.1f deg)" % b)
		rearmost = maxf(rearmost, b)
	assert_gte(rearmost, 180.0 - jitter - 0.5, "one of them directly behind")
	var in_front := 0
	for other in others:
		if absf(_bearing_of(_director.slot_for(other))) <= jitter + 0.5:
			in_front += 1
	assert_eq(in_front, 1, "the others keep the front and the other flank")


func test_a_stalled_enemy_is_given_another_angle() -> void:
	await _setup(0, 1.0)
	Tuning.data.director_slot_retry_deg = 20.0
	var stubs := _crowd(3)
	for stub in stubs:
		stub.want_token = false
	await _ticks(4)
	var before := _bearing_of(_director.slot_for(stubs[1]))
	for stub in stubs:
		stub.global_position = _director.slot_for(stub)
	_director.report_stalled(stubs[1])
	await _ticks(3)
	var after := _bearing_of(_director.slot_for(stubs[1]))
	assert_gt(absf(wrapf(after - before, -180.0, 180.0)), 5.0, "its slot moved to another angle (%.1f -> %.1f)" % [before, after])


# --- Slots on a navmesh -----------------------------------------------------------------------------


## A 16 x 16 m floor with a 4.5 x 4 m hole (a crate) east of the origin, as polygons.
func _add_navmesh_with_a_hole() -> void:
	var xs: Array[float] = [-8.0, 1.5, 6.0, 8.0]
	var zs: Array[float] = [-8.0, -2.0, 2.0, 8.0]
	var mesh := NavigationMesh.new()
	mesh.cell_size = 0.25
	mesh.cell_height = 0.1
	var verts := PackedVector3Array()
	for iz in 4:
		for ix in 4:
			verts.append(Vector3(xs[ix], 0.0, zs[iz]))
	mesh.vertices = verts
	for cell: Array in [[0, 0], [1, 0], [2, 0], [0, 2], [1, 2], [2, 2], [0, 1], [2, 1]]:
		var a: int = int(cell[1]) * 4 + int(cell[0])
		mesh.add_polygon(PackedInt32Array([a, a + 1, a + 5, a + 4]))
	var region := NavigationRegion3D.new()
	region.navigation_mesh = mesh
	_scene.add_child(region)


func test_no_slot_lands_inside_a_crate_the_navmesh_does_not_cover() -> void:
	await _setup(0, 1.0)
	_add_navmesh_with_a_hole()
	await _ticks(8)
	var map := _player.get_world_3d().navigation_map
	assert_gt(NavigationServer3D.map_get_iteration_id(map), 0, "the map synced")
	var stubs: Array[StubEnemy] = []
	for angle in [-90.0, -60.0, -120.0, 150.0, 20.0, 60.0]:
		stubs.append(_stub(_at(angle, 3.0), false))
	await _ticks(4)
	for stub in stubs:
		var slot := _director.slot_for(stub)
		assert_ne(slot, Vector3.INF)
		var inside_the_hole := slot.x > 1.5 + 0.01 and slot.x < 6.0 - 0.01 and slot.z > -2.0 + 0.01 and slot.z < 2.0 - 0.01
		assert_false(inside_the_hole, "slot %s is not in the crate" % str(slot))
		var on_mesh := NavigationServer3D.map_get_closest_point(map, slot)
		assert_lt(_flat_distance(on_mesh, slot), 0.01, "slot %s is on the navmesh" % str(slot))


func test_without_a_navmesh_the_slots_are_the_raw_ring_points() -> void:
	await _setup(0, 1.0)
	var stub := _stub(_at(90.0, 3.0), false)
	await _ticks(4)
	var slot := _director.slot_for(stub)
	assert_ne(slot, Vector3.INF)
	assert_gte(_flat_distance(slot, _player.global_position), Tuning.data.posture_ring_min_m - 0.001)
	assert_almost_eq(slot.y, _player.global_position.y, 0.001, "at the player's height")


# --- Determinism ---------------------------------------------------------------------------------------


func test_two_identical_runs_make_the_same_decisions() -> void:
	var runs: Array = []
	for run in 2:
		await _setup(2, 0.5, 3)
		var stubs: Array[StubEnemy] = []
		for angle in [AHEAD, 90.0, BEHIND, -90.0, 150.0]:
			stubs.append(_stub(_at(angle, 3.0 + 0.1 * float(stubs.size())), true))
		var log: Array = []
		for tick in 90:
			await _ticks(1)
			for holder in _holders():
				log.append([tick, stubs.find(holder)])
				if tick % 15 == 0:
					_director.release_token(holder)
		for stub in stubs:
			log.append(_director.slot_for(stub))
		runs.append(log)
		_scene.queue_free()
		await _ticks(2)
	assert_eq(runs[0], runs[1], "same seed, same scene, same grants and slots")
