extends GutTest
## The Pipe Thug and the dropped pipe (Milestone 3, P2-thug): it carries a pipe in its hand, swings
## the three-hit combo (10 each, the third staggers), drops the pipe on a knockdown or a killing
## blow (not on a flinch), fights unarmed with the Punk's moves after that, and the player takes the
## dropped pipe with LB and swings it as any pipe. The harness is a flat code-built floor with the
## real player and a stub director (tests/fixtures/stub_director.gd), as tests/test_enemy_actor.gd
## does. Every sim tick is one physics frame (the runner uses --fixed-fps 60).

const THUG_SCENE := preload("res://game/enemies/thug/pipe_thug.tscn")
const PUNK_SCENE := preload("res://game/enemies/punk/street_punk.tscn")
const StubDirector := preload("res://tests/fixtures/stub_director.gd")

## A long wait for slower things (a walk in, a recovery, a get-up).
const LONG_TICKS := 900
## Frames the dropped pipe gets to fall and settle.
const SETTLE_TICKS := 90
## The pipe at rest lies this low (m): on the floor, not in the air.
const REST_HEIGHT_M := 0.25

var _scene: Node3D
var _player: PlayerCharacter
var _director: Object
var _hits: Array[HitInfo] = []
var _started: Array[Dictionary] = []


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.data.ai_frozen = false
	Tuning.data.god_mode = false
	Tuning.data.one_hit_ko = false
	TimeController.clear()
	TimeController.debug_scale = 1.0
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = false
	_hits.clear()
	_started.clear()
	CombatEvents.hit_landed.connect(_on_hit_landed)
	CombatEvents.attack_started.connect(_on_attack_started)
	_scene = Node3D.new()
	add_child_autofree(_scene)
	_box(Vector3(0.0, -0.5, 0.0), Vector3(60.0, 1.0, 60.0))


func after_each() -> void:
	for pair: Array in [[CombatEvents.hit_landed, _on_hit_landed], [CombatEvents.attack_started, _on_attack_started]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = true
	Tuning.reset_to_default()
	Tuning.data.god_mode = false
	TimeController.clear()


func _on_hit_landed(hit: HitInfo) -> void:
	_hits.append(hit)


func _on_attack_started(attacker: Node3D, move: MoveData, chain_step: int, timing: StringName) -> void:
	_started.append({attacker = attacker, move = move, step = chain_step, timing = timing})


# --- Harness ----------------------------------------------------------------------------------


func _box(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	_scene.add_child(body)
	return body


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(condition: Callable, max_ticks: int = LONG_TICKS) -> bool:
	for i in max_ticks:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _make_player(at: Vector3 = Vector3.ZERO) -> PlayerCharacter:
	_player = PlayerCharacter.new()
	_player.position = at
	_scene.add_child(_player)
	_player.input.scripted = true
	return _player


func _make_director() -> Object:
	_director = StubDirector.new()
	_scene.add_child(_director)
	return _director


## A Pipe Thug at `at`, facing `toward` (the player's spot by default), armed unless told not.
func _thug(at: Vector3, is_armed: bool = true, toward: Vector3 = Vector3.ZERO) -> PipeThug:
	var thug := THUG_SCENE.instantiate() as PipeThug
	thug.name = "Thug1"
	thug.armed = is_armed
	thug.position = at
	thug.rotation.y = atan2(-(toward.x - at.x), -(toward.z - at.z))
	_scene.add_child(thug)
	return thug


func _punk(at: Vector3) -> StreetPunk:
	var punk := PUNK_SCENE.instantiate() as StreetPunk
	punk.name = "Punk1"
	punk.position = at
	punk.rotation.y = atan2(-(0.0 - at.x), -(0.0 - at.z))
	_scene.add_child(punk)
	return punk


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## A hit on `victim` from `attacker`: the reaction asked (a knockdown by default), pushing along -Z.
func _hit(attacker: CombatActor, victim: CombatActor, damage: float = 6.0,
		reaction: CombatTypes.Reaction = CombatTypes.Reaction.KNOCKDOWN) -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = attacker
	hit.victim = victim
	hit.damage = damage
	hit.tier = CombatTypes.HitTier.LIGHT
	hit.reaction = reaction
	hit.knockback = Vector3(0.0, 2.0, 3.0) if reaction == CombatTypes.Reaction.KNOCKDOWN else Vector3(0.0, 0.0, 1.5)
	hit.direction = Vector3.FORWARD
	hit.contact_point = victim.global_position + Vector3.UP
	return hit


## The pipes lying free in the scene (in group "weapon", not held or thrown).
func _free_pipes() -> Array[Weapon]:
	var out: Array[Weapon] = []
	for node: Node in get_tree().get_nodes_in_group(&"weapon"):
		var weapon := node as Weapon
		if weapon and weapon.is_available() and _scene.is_ancestor_of(weapon):
			out.append(weapon)
	return out


## A Thug with a token, standing at its reach in front of the player, ready to engage.
func _engaging_thug() -> PipeThug:
	_make_player()
	_make_director()
	var thug := _thug(Vector3(0.0, 0.0, -1.2))
	await _ticks(4)
	_director.give_token(thug)
	return thug


# --- What it is --------------------------------------------------------------------------------


func test_a_thug_is_an_ai_enemy_with_its_health_attack_and_look() -> void:
	_make_player()
	var thug := _thug(Vector3(0.0, 0.0, -4.0))
	await _ticks(3)
	assert_eq(thug.archetype, &"thug")
	assert_eq(thug.team, 1)
	assert_almost_eq(thug.max_health, Tuning.data.thug_health, 0.001, "35 HP from the tunable")
	for group: StringName in [&"actor", &"enemy", &"ai_enemy"]:
		assert_true(thug.is_in_group(group), "in group %s" % group)
	assert_false(thug.heavy or thug.armor_light, "a grunt: no armor, the light wind-up floor")
	assert_eq(thug._attacks.size(), 1, "one attack while armed: the pipe combo")
	var moves: Array[StringName] = []
	for move: MoveData in thug._attacks[0].moves:
		moves.append(move.id)
	assert_eq(moves, [&"thug_pipe_1", &"thug_pipe_2", &"thug_pipe_3"] as Array[StringName], "three swings")
	assert_almost_eq(thug.attack_range_m(), 1.23, 0.001, "it closes to the first swing's reach")
	# SPEC §10: red is the warning's, the blood's and the finishers'. The jacket is a green.
	assert_lt(thug.color.r, thug.color.g, "the jacket is no red")
	assert_lt(thug.pipe_color.r + 0.01, 1.0, "nor is the pipe a red")
	assert_ne(thug.color, Color(0.86, 0.5, 0.16), "not the training dummy's orange")


func test_the_health_follows_its_tunable_keeping_the_share_left() -> void:
	_make_player()
	var thug := _thug(Vector3(0.0, 0.0, -4.0))
	await _ticks(2)
	thug.health = thug.max_health * 0.5
	Tuning.set_value(&"thug_health", 70.0)
	assert_almost_eq(thug.max_health, 70.0, 0.001)
	assert_almost_eq(thug.health, 35.0, 0.001, "half left stays half")


func test_it_spawns_holding_a_pipe_in_its_right_hand() -> void:
	_make_player()
	var thug := _thug(Vector3(0.0, 0.0, -4.0))
	await _ticks(3)
	assert_true(thug.has_pipe(), "it carries a pipe")
	var pipe := thug._pipe
	assert_eq(pipe.holder, thug, "the pipe knows its holder")
	assert_false(pipe.is_available(), "a pipe in a hand is nobody's pick-up")
	assert_eq(pipe.get_parent(), thug.rig.get_attachment(&"WeaponGrip"), "on the grip of its right hand")
	assert_true(pipe.freeze, "it rides the hand, no physics of its own")
	assert_true(_free_pipes().is_empty(), "nothing lies on the floor yet")
	assert_ne(pipe.color, Color(0.55, 0.58, 0.62), "a brighter pipe than the training room's, so it reads")


func test_born_unarmed_it_carries_no_pipe_and_throws_the_punks_moves() -> void:
	_make_player()
	var thug := _thug(Vector3(0.0, 0.0, -4.0), false)
	await _ticks(3)
	assert_false(thug.has_pipe())
	var ids: Array[StringName] = []
	for attack: EnemyAttack in thug._attacks:
		for move: MoveData in attack.moves:
			ids.append(move.id)
	assert_eq(ids, [&"punk_jab", &"punk_cross", &"punk_shove"] as Array[StringName], "the Punk's two attacks")


# --- The combo ---------------------------------------------------------------------------------


func test_it_swings_three_times_for_ten_and_the_third_staggers() -> void:
	var thug := await _engaging_thug()
	var done := await _until(func() -> bool: return _hits.size() >= 3, 400)
	assert_true(done, "all three swings land on a standing player (%d)" % _hits.size())
	assert_eq(_started.size(), 3, "three moves, one telegraph")
	var ids: Array[StringName] = []
	for hit: HitInfo in _hits:
		ids.append(hit.move.id)
	assert_eq(ids, [&"thug_pipe_1", &"thug_pipe_2", &"thug_pipe_3"] as Array[StringName], "the combo in order")
	for hit: HitInfo in _hits:
		assert_eq(hit.damage, 10.0, "%s does 10" % hit.move.id)
	assert_eq(_hits[0].reaction, CombatTypes.Reaction.FLINCH)
	assert_eq(_hits[1].reaction, CombatTypes.Reaction.FLINCH)
	assert_eq(_hits[2].reaction, CombatTypes.Reaction.STAGGER, "the third staggers: the 15% rule (no knockdown from 30)")
	assert_eq(_player.state, CombatTypes.ActorState.STAGGER, "the player is staggered, not down")
	assert_almost_eq(_player.health, 70.0, 0.001, "30 damage for the whole combo")
	assert_eq([_started[1].timing, _started[2].timing], [&"chain", &"chain"] as Array[StringName], "the links start with no wind-up of their own")
	assert_true(thug.has_pipe(), "the swings do not cost it the pipe")


func test_the_first_swing_is_a_held_wind_up_with_the_warning_event() -> void:
	var windups: Array[Dictionary] = []
	var on_started := func(attacker: Node3D, move: MoveData) -> void: windups.append({attacker = attacker, move = move})
	CombatEvents.windup_started.connect(on_started)
	var thug := await _engaging_thug()
	await _until(func() -> bool: return _hits.size() >= 3, 400)
	CombatEvents.windup_started.disconnect(on_started)
	assert_eq(windups.size(), 1, "one wind-up for the whole combo")
	assert_eq(windups[0].attacker, thug)
	assert_eq(windups[0].move.id, &"thug_pipe_1")
	assert_gte(windups[0].move.startup, Tuning.data.windup_min_frames_grunt, "at least the grunt floor")


func test_a_blocked_swing_costs_the_guard_one_and_a_half_times_and_ends_the_combo() -> void:
	_make_player()
	_player.input.push_down(&"DODGE")
	while _player.input.queued() > 0:
		await get_tree().physics_frame
	await _ticks(Tuning.data.block_raise_frames + 2)
	_make_director()
	var thug := _thug(Vector3(0.0, 0.0, -1.2))
	await _ticks(3)
	_director.give_token(thug)
	var blocked := await _until(func() -> bool: return not _hits.is_empty(), 200)
	assert_true(blocked, "the first swing reaches the guard")
	assert_true(_hits[0].blocked, "blocked")
	assert_almost_eq(_hits[0].move.guard_damage_mult, 1.5, 0.0001, "the pipe's guard drain, as the player's own")
	var drain := Tuning.data.guard_drain_per_damage * 10.0 * 1.5
	assert_almost_eq(_player.guard, Tuning.data.guard_max - drain, 0.01, "the pipe drains the guard 1.5 times as fast as a fist")
	await _ticks(90)
	assert_eq(_started.size(), 1, "a blocked swing recoils: no second swing")
	assert_almost_eq(_player.health, 100.0 - 10.0 * Tuning.data.chip_ratio, 0.01, "only the chip got through")


func test_a_whiffed_swing_ends_the_combo_there() -> void:
	_make_player()
	var thug := _thug(Vector3(0.0, 0.0, -4.0))
	await _ticks(3)
	thug.force_attack(0)
	await _until(func() -> bool: return thug.ai_state == EnemyActor.AiState.RECOVER, 200)
	assert_eq(thug.ai_state, EnemyActor.AiState.RECOVER, "the whiff ends in RECOVER")
	assert_eq(_started.size(), 1, "no second swing after a whiffed opener")
	assert_true(_hits.is_empty())


# --- The drop ----------------------------------------------------------------------------------


func test_a_knockdown_drops_the_pipe_to_the_floor_as_a_pickup() -> void:
	_make_player()
	var thug := _thug(Vector3(0.0, 0.0, -1.2))
	await _ticks(3)
	var pipe := thug._pipe
	var from := thug.global_position
	assert_true(thug.receive_hit(_hit(_player, thug)), "the knockdown lands")
	assert_false(thug.has_pipe(), "the pipe left its hand")
	assert_true(pipe.is_available(), "it is a pick-up again")
	assert_true(pipe.is_in_group(&"weapon"), "in group weapon")
	await _ticks(SETTLE_TICKS)
	assert_eq(pipe.get_parent(), _scene, "back in the world (the room), not on a rig")
	assert_false(pipe.freeze, "a rigid body again")
	assert_eq(pipe.collision_layer, CombatTypes.bit(CombatTypes.LAYER_PICKUP), "on the pick-up layer")
	assert_lt(pipe.global_position.y, REST_HEIGHT_M, "it lies on the floor (%.2f m up)" % pipe.global_position.y)
	assert_gt(pipe.global_position.y, -0.1, "not through it")
	assert_lt(_flat_dist(pipe.global_position, from), 3.0, "within a few metres of where the Thug stood")
	assert_eq(_free_pipes(), [pipe] as Array[Weapon], "exactly one pipe on the floor")
	assert_eq(pipe.durability, Tuning.data.weapon_durability, "with its own full durability")


func test_a_flinch_or_a_stagger_does_not_drop_it() -> void:
	_make_player()
	var thug := _thug(Vector3(0.0, 0.0, -1.2))
	await _ticks(3)
	thug.receive_hit(_hit(_player, thug, 5.0, CombatTypes.Reaction.FLINCH))
	assert_true(thug.has_pipe(), "a flinch keeps the pipe")
	await _until(func() -> bool: return thug.state == CombatTypes.ActorState.FREE, 100)
	thug.receive_hit(_hit(_player, thug, 5.0, CombatTypes.Reaction.STAGGER))
	assert_true(thug.has_pipe(), "a stagger keeps it too")
	assert_true(_free_pipes().is_empty())


func test_a_killing_hit_drops_it_too() -> void:
	_make_player()
	var thug := _thug(Vector3(0.0, 0.0, -1.2))
	await _ticks(3)
	thug.health = 3.0
	thug.receive_hit(_hit(_player, thug, 10.0, CombatTypes.Reaction.FLINCH))
	assert_false(thug.has_pipe(), "a killing blow, whatever its reaction, drops the pipe")
	await _ticks(SETTLE_TICKS)
	assert_eq(_free_pipes().size(), 1, "it lies on the floor")


func test_a_thrown_thug_drops_it_and_the_pipe_drops_toward_whoever_hit_it() -> void:
	_make_player()
	var thug := _thug(Vector3(0.0, 0.0, -1.2))
	await _ticks(3)
	var pipe := thug._pipe
	var hit := _hit(_player, thug, 15.0, CombatTypes.Reaction.THROWN)
	hit.direction = Vector3.RIGHT
	thug.receive_hit(hit)
	assert_false(thug.has_pipe(), "a throw knocks it loose")
	assert_lt(pipe.linear_velocity.x, -Tuning.data.thug_drop_speed_mps * 0.9, "pushed back toward whoever hit it, at the drop speed")
	assert_almost_eq(pipe.linear_velocity.z, 0.0, 0.01, "and only along that line")


func test_after_the_drop_it_attacks_with_the_punks_moves_and_never_re_arms() -> void:
	_make_player()
	var thug := _thug(Vector3(0.0, 0.0, -3.0))
	await _ticks(3)
	thug.receive_hit(_hit(_player, thug))
	await _until(func() -> bool: return thug.state == CombatTypes.ActorState.FREE and thug.health > 0.0, LONG_TICKS)
	assert_false(thug.armed, "it is unarmed now")
	var ids: Array[StringName] = []
	for attack: EnemyAttack in thug._attacks:
		for move: MoveData in attack.moves:
			ids.append(move.id)
	assert_eq(ids, [&"punk_jab", &"punk_cross", &"punk_shove"] as Array[StringName], "the Punk's two attacks")
	_started.clear()
	thug.force_attack(0)
	await _until(func() -> bool: return not _started.is_empty(), 60)
	assert_eq(_started[0].move.id, &"punk_jab", "a punch, not a pipe swing")
	# Walking over the pipe is nothing to it: it is the player's.
	assert_false(thug.has_pipe())
	assert_eq(_free_pipes().size(), 1, "the pipe still lies where it fell")


func test_only_so_many_dropped_pipes_lie_in_the_street_the_oldest_go_first() -> void:
	Tuning.data.thug_pipes_on_floor_max = 2
	_make_player()
	var pipes: Array[Weapon] = []
	for i in 3:
		var thug := _thug(Vector3(2.0 * i - 2.0, 0.0, -3.0))
		thug.name = "Thug%d" % (i + 1)
		await _ticks(3)
		pipes.append(thug._pipe)
		thug.receive_hit(_hit(_player, thug))
		await _ticks(5)
	await _ticks(2)
	assert_false(is_instance_valid(pipes[0]), "the oldest pipe was cleared")
	assert_true(is_instance_valid(pipes[1]), "the next two stay")
	assert_true(is_instance_valid(pipes[2]))
	assert_eq(get_tree().get_nodes_in_group(PipeThug.DROPPED_GROUP).filter(
			func(n: Node) -> bool: return not n.is_queued_for_deletion()).size(), 2, "two lie in the street")


func test_a_pipe_the_player_holds_is_never_cleared() -> void:
	Tuning.data.thug_pipes_on_floor_max = 1
	_make_player()
	var first := _thug(Vector3(0.0, 0.0, -1.2))
	await _ticks(3)
	var held_pipe := first._pipe
	first.receive_hit(_hit(_player, first))
	await _ticks(SETTLE_TICKS)
	_player.input.push_press(&"GRAB", 2)
	await _until(func() -> bool: return _player.holding_weapon(), 60)
	assert_true(_player.holding_weapon(), "the player holds the first pipe")
	for i in 2:
		var thug := _thug(Vector3(3.0 + 2.0 * i, 0.0, -3.0))
		thug.name = "Thug%d" % (i + 2)
		await _ticks(3)
		thug.receive_hit(_hit(_player, thug))
		await _ticks(5)
	assert_true(is_instance_valid(held_pipe), "the pipe in the player's hand stays")
	assert_true(_player.holding_weapon())


# --- The player takes it -----------------------------------------------------------------------


## The player punches at a Thug 1.2 m ahead (a knockdown), then LB takes the dropped pipe and
## three swings hit a Punk standing in front. The pipe is where the player can take it.
func test_the_player_takes_the_dropped_pipe_with_lb_and_swings_it() -> void:
	_make_player()
	var thug := _thug(Vector3(0.0, 0.0, -1.2))
	await _ticks(3)
	thug.receive_hit(_hit(_player, thug))
	await _ticks(SETTLE_TICKS)
	var pipe := _free_pipes()[0]
	var reach := pipe.global_position.distance_to(_player.global_position + Vector3.UP * 0.3)
	gut.p("the dropped pipe lies %.2f m from the player (pickup range %.1f m)" % [reach, Tuning.data.pickup_range])
	assert_lte(reach, Tuning.data.pickup_range, "the pipe lies within reach of the player who knocked the Thug down (%.2f m)" % reach)
	# Nobody to grab but a downed Thug: LB takes the pipe.
	_player.input.push_press(&"GRAB", 2)
	await _until(func() -> bool: return _player.holding_weapon(), 60)
	assert_true(_player.holding_weapon(), "the player took the Thug's pipe")
	assert_eq(_player.weapon_durability_left(), Tuning.data.weapon_durability)
	assert_false(pipe.is_available())
	# Three swings on a Punk in front.
	_player.look_yaw = 0.0
	var punk := _punk(Vector3(0.0, 0.0, -1.2))
	punk.max_health = 500.0
	punk.health = 500.0
	await _until(func() -> bool: return _player.state == CombatTypes.ActorState.FREE, 60)
	_hits.clear()
	for i in 3:
		_player.input.push_press(&"P", 2)
		_player.input.push_wait(9)
	await _until(func() -> bool: return _hits.size() >= 3, 200)
	var ids: Array[StringName] = []
	for hit: HitInfo in _hits:
		if hit.attacker == _player and not hit.is_body_impact:
			ids.append(hit.move.id)
	assert_eq(ids, [&"pipe_swing_1", &"pipe_swing_2", &"pipe_swing_3"] as Array[StringName], "swung like any pipe")
	assert_eq(_player.weapon_durability_left(), Tuning.data.weapon_durability - 3, "wearing as any pipe does")


func test_a_pipe_in_the_thugs_hand_cannot_be_taken() -> void:
	_make_player()
	var thug := _thug(Vector3(0.0, 0.0, -3.0))
	await _ticks(3)
	# Beside the player: the thug's pipe is on its grip, far away, and nothing is on the floor.
	assert_null(_player._find_weapon(), "no pick-up in reach")
	thug.global_position = Vector3(0.3, 0.0, 0.0)
	await _ticks(3)
	assert_null(_player._find_weapon(), "not even from a hand within arm's length: a held pipe is nobody's pick-up")


# --- The token and the chain ------------------------------------------------------------------


func test_the_token_goes_back_when_the_combo_ends_and_the_cooldown_is_on() -> void:
	var thug := await _engaging_thug()
	await _until(func() -> bool: return thug.ai_state == EnemyActor.AiState.RECOVER, 400)
	assert_eq(thug.ai_state, EnemyActor.AiState.RECOVER)
	assert_false(thug.has_token, "the token is released when RECOVER starts")
	assert_true(_director.released.has(thug), "the director got it back")
	assert_false(thug.wants_token(), "the cooldown is on")


func test_a_hit_during_the_combo_ends_it_and_the_token_goes_back() -> void:
	var thug := await _engaging_thug()
	await _until(func() -> bool: return thug.state == CombatTypes.ActorState.WINDUP, 200)
	thug.receive_hit(_hit(_player, thug, 5.0, CombatTypes.Reaction.FLINCH))
	assert_false(thug.has_token)
	assert_true(thug.has_pipe(), "a flinch keeps the pipe")
	await _ticks(120)
	assert_true(_hits.is_empty(), "the swing never came")
