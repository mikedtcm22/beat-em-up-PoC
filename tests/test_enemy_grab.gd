extends GutTest
## An enemy's grab on the player (Milestone 3, P2-grab), proved with the test grabber
## (tests/fixtures/grab_test_enemy.gd: its only attack is the grab and its follow-up, the Bruiser's
## headbutt or, as the boss, the slam): the wind-up that a dodge, a jump or a heavy hit on an
## armored grabber gets out of, a connect only when the player can be grabbed, the held player
## mashing free before the follow-up's strike frame (and not with one press fewer), the unbroken hit
## landing, the holder letting go when it is hit or killed, the warning ending on the grab, and the
## director holding its tokens back while the player is held. The tests run on a flat floor with the
## real player and a stub director; the same grabber is spawned in the crowd room and the training
## room at the end. One sim tick is one physics frame (the runner uses --fixed-fps 60).

const GRABBER_SCENE := preload("res://tests/fixtures/grab_test_enemy.tscn")
const BOSS_SCENE := preload("res://tests/fixtures/grab_test_boss.tscn")
const StubDirector := preload("res://tests/fixtures/stub_director.gd")
const MOVES_DIR := "res://game/combat/moves/"
const LONG_TICKS := 900

var _scene: Node3D
var _player: PlayerCharacter
var _director: Object
var _hits: Array[HitInfo] = []
var _whiffs: Array[MoveData] = []
var _ended: Array[Dictionary] = []


func before_each() -> void:
	Tuning.reset_to_default()
	# The grabber stands where it is put and faces the player: force_attack() still starts its attack.
	Tuning.data.ai_frozen = true
	Tuning.data.god_mode = false
	Tuning.data.one_hit_ko = false
	TimeController.clear()
	TimeController.debug_scale = 1.0
	GameInput.menu_open = false
	_hits.clear()
	_whiffs.clear()
	_ended.clear()
	CombatEvents.hit_landed.connect(_on_hit_landed)
	CombatEvents.attack_whiffed.connect(_on_whiffed)
	CombatEvents.windup_ended.connect(_on_windup_ended)
	_scene = Node3D.new()
	add_child_autofree(_scene)
	_box(Vector3(0.0, -0.5, 0.0), Vector3(60.0, 1.0, 60.0))
	_player = PlayerCharacter.new()
	_scene.add_child(_player)
	_player.input.scripted = true
	_director = StubDirector.new()
	_scene.add_child(_director)


func after_each() -> void:
	for pair: Array in [[CombatEvents.hit_landed, _on_hit_landed], [CombatEvents.attack_whiffed, _on_whiffed],
			[CombatEvents.windup_ended, _on_windup_ended]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])
	GameInput.menu_open = false
	Tuning.reset_to_default()
	Tuning.data.god_mode = false
	TimeController.clear()


func _on_hit_landed(hit: HitInfo) -> void:
	_hits.append(hit)


func _on_whiffed(_attacker: Node3D, move: MoveData) -> void:
	_whiffs.append(move)


func _on_windup_ended(attacker: Node3D, interrupted: bool) -> void:
	_ended.append({attacker = attacker, interrupted = interrupted})


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


## The test grabber `ahead_m` in front of the player (who looks along -Z), facing him. `boss`: the
## boss-sized one with the slam.
func _grabber(ahead_m: float = 1.05, boss: bool = false, configure: Callable = Callable()) -> EnemyActor:
	var scene := BOSS_SCENE if boss else GRABBER_SCENE
	var enemy := scene.instantiate() as EnemyActor
	enemy.name = "Grabber1"
	enemy.position = Vector3(0.0, 0.0, -ahead_m)
	enemy.rotation.y = PI
	if configure.is_valid():
		configure.call(enemy)
	_scene.add_child(enemy)
	return enemy


func _move(id: StringName) -> MoveData:
	return load("%s%s.tres" % [MOVES_DIR, id]) as MoveData


## Wait until the grab has connected (the player is GRABBED) or `ticks` have passed.
func _until_held(ticks: int = 120) -> bool:
	return await _until(func() -> bool: return _player.state == CombatTypes.ActorState.GRABBED, ticks)


## Press P `n` times a tick apart (a mash), starting now.
func _mash(n: int, gap_ticks: int = 2) -> void:
	for i in n:
		_player.input.push_press(&"P", 1)
		await _ticks(gap_ticks)


## A hit on `victim` from `attacker`.
func _hit(attacker: CombatActor, victim: CombatActor, damage: float = 6.0,
		tier: CombatTypes.HitTier = CombatTypes.HitTier.LIGHT,
		reaction: CombatTypes.Reaction = CombatTypes.Reaction.FLINCH) -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = attacker
	hit.victim = victim
	hit.damage = damage
	hit.tier = tier
	hit.reaction = reaction
	hit.knockback = Vector3(0.0, 0.0, 1.5)
	hit.direction = Vector3.FORWARD
	hit.contact_point = victim.global_position + Vector3.UP
	return hit


# --- The connect ------------------------------------------------------------------------------


func test_a_grab_in_range_connects_and_holds_the_player() -> void:
	var grabber := _grabber()
	await _ticks(4)
	watch_signals(CombatEvents)
	grabber.force_attack()
	assert_true(await _until_held(), "the player is grabbed")
	assert_eq(_player.holder, grabber, "by the grabber")
	assert_true(grabber.is_holding(_player), "it holds him")
	assert_eq(grabber.current_move.id, &"bruiser_headbutt", "the headbutt's wind-up runs while he is held")
	assert_eq(grabber.state, CombatTypes.ActorState.WINDUP)
	assert_signal_emitted(CombatEvents, "grabbed")
	assert_eq(_whiffs.size(), 0, "no whiff")


func test_unbroken_the_headbutt_lands_for_15_and_knocks_him_down() -> void:
	var grabber := _grabber()
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _until_held())
	var held_at := Engine.get_physics_frames()
	assert_true(await _until(func() -> bool: return not _hits.is_empty(), 200), "the headbutt hit lands")
	var hit := _hits[0]
	assert_eq(hit.move.id, &"bruiser_headbutt")
	assert_eq(hit.victim, _player)
	assert_eq(hit.damage, 15.0, "15 damage")
	assert_eq(hit.reaction, CombatTypes.Reaction.KNOCKDOWN)
	assert_eq(_player.health, 85.0, "the player lost 15 health")
	assert_gte(Engine.get_physics_frames() - held_at, _move(&"bruiser_headbutt").startup, "after the whole mash window")
	await _ticks(2)
	assert_true(_player.state in [CombatTypes.ActorState.LAUNCHED, CombatTypes.ActorState.DOWNED], "knocked down")
	assert_null(_player.holder, "let go first")


func test_a_whiffed_grab_is_announced_and_recovers() -> void:
	# Out of range: it reaches and finds nothing. No hitbox to whiff, so it says so by hand.
	var grabber := _grabber(2.2)
	await _ticks(4)
	grabber.force_attack()
	await _until(func() -> bool: return not _whiffs.is_empty(), 80)
	assert_eq(_whiffs.size(), 1, "attack_whiffed was emitted once")
	assert_eq(_whiffs[0].id, &"bruiser_grab")
	assert_ne(_player.state, CombatTypes.ActorState.GRABBED, "nobody held")
	assert_true(await _until(func() -> bool: return grabber.current_move == null, 120), "the move runs out")
	assert_null(grabber._hold.victim)


func test_a_grab_out_of_its_facing_whiffs() -> void:
	var grabber := _grabber(1.05, false, func(e: EnemyActor) -> void: e.rotation.y = PI * 0.5)
	await _ticks(4)
	Tuning.data.windup_track_deg_per_s = 0.0
	grabber.force_attack()
	await _until(func() -> bool: return not _whiffs.is_empty(), 80)
	assert_eq(_whiffs.size(), 1, "it faces away from him: the grab whiffs")
	assert_ne(_player.state, CombatTypes.ActorState.GRABBED)


func test_the_connect_range_is_the_tunable_scaled_by_the_holders_height() -> void:
	var bruiser := _grabber()
	var boss := _grabber(1.05, true)
	await _ticks(3)
	assert_almost_eq(EnemyHold.new(bruiser).connect_range_m(), Tuning.data.enemy_grab_range_m * 2.05 / 1.8, 0.001)
	assert_almost_eq(EnemyHold.new(boss).connect_range_m(), Tuning.data.enemy_grab_range_m * 2.3 / 1.8, 0.001)


# --- Getting out of the wind-up ----------------------------------------------------------------


## Wait until the grabber's grab is `frame` frames into its wind-up.
func _until_grab_frame(grabber: EnemyActor, frame: int) -> bool:
	return await _until(func() -> bool:
		return grabber.current_move != null and grabber.move_frame >= frame, 120)


func test_a_dodge_through_the_wind_up_is_never_grabbed() -> void:
	var grabber := _grabber()
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _until_grab_frame(grabber, 27))
	_player.input.scripted_move = Vector2(0.0, -1.0)
	_player.input.push_press(&"DODGE", 2)
	await _ticks(2)
	assert_eq(_player.state, CombatTypes.ActorState.DODGE, "dodging")
	_player.input.scripted_move = Vector2.ZERO
	assert_false(_player.can_be_grabbed(), "a dodge cannot be grabbed")
	await _until(func() -> bool: return not _whiffs.is_empty(), 40)
	assert_eq(_whiffs.size(), 1, "the grab whiffed")
	await _ticks(40)
	assert_ne(_player.state, CombatTypes.ActorState.GRABBED, "never held")
	assert_eq(_player.health, 100.0, "and never hit")


func test_a_jump_through_the_wind_up_is_never_grabbed() -> void:
	var grabber := _grabber()
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _until_grab_frame(grabber, 18))
	_player.input.push_press(&"JUMP", 2)
	await _ticks(4)
	assert_eq(_player.state, CombatTypes.ActorState.AIRBORNE, "in the air")
	await _until(func() -> bool: return not _whiffs.is_empty(), 40)
	assert_eq(_whiffs.size(), 1, "the grab whiffed under him")
	assert_ne(_player.state, CombatTypes.ActorState.GRABBED)


func test_a_grunt_grabber_loses_its_wind_up_to_any_hit() -> void:
	var grabber := _grabber()
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _until_grab_frame(grabber, 10))
	grabber.receive_hit(_hit(_player, grabber, 6.0, CombatTypes.HitTier.LIGHT, CombatTypes.Reaction.FLINCH))
	assert_null(grabber.current_move, "the light hit cancelled the grab")
	assert_true(_ended.any(func(e: Dictionary) -> bool: return e.attacker == grabber and e.interrupted), "windup_ended(interrupted)")
	await _ticks(60)
	assert_ne(_player.state, CombatTypes.ActorState.GRABBED, "the grab never connected")


func test_an_armored_grabber_shrugs_off_a_light_hit_but_not_a_heavy_one() -> void:
	var armor := func(e: EnemyActor) -> void:
		e.armor_light = true
		e.armor_heavy_to_stagger = true
	var light := _grabber(1.05, false, armor)
	await _ticks(4)
	light.force_attack()
	assert_true(await _until_grab_frame(light, 10))
	var hp := light.health
	light.receive_hit(_hit(_player, light, 6.0, CombatTypes.HitTier.LIGHT, CombatTypes.Reaction.FLINCH))
	assert_lt(light.health, hp, "the damage landed")
	assert_not_null(light.current_move, "the wind-up goes on")
	assert_eq(light.state, CombatTypes.ActorState.WINDUP)
	assert_true(await _until_held(), "and the grab connects")
	# The heavy hit on a second one staggers it out of the wind-up.
	_player.reset_state()
	var heavy := _grabber(1.05, false, armor)
	heavy.name = "Grabber2"
	heavy.position = Vector3(5.0, 0.0, -1.05)
	_player.global_position = Vector3(5.0, 0.0, 0.0)
	await _ticks(4)
	heavy.force_attack()
	assert_true(await _until_grab_frame(heavy, 10))
	heavy.receive_hit(_hit(_player, heavy, 8.0, CombatTypes.HitTier.HEAVY, CombatTypes.Reaction.STAGGER))
	assert_null(heavy.current_move, "the heavy hit cancelled the grab")
	assert_eq(heavy.state, CombatTypes.ActorState.STAGGER)


# --- Mashing free ------------------------------------------------------------------------------


func _headbutt_startup() -> int:
	return _move(&"bruiser_headbutt").startup


func test_mashing_exactly_the_presses_breaks_free_before_the_strike_frame() -> void:
	var grabber := _grabber()
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _until_held())
	watch_signals(CombatEvents)
	var presses: int = Tuning.data.grab_break_presses
	for i in presses:
		_player.input.push_press(&"P", 1)
	assert_true(await _until(func() -> bool: return _player.state != CombatTypes.ActorState.GRABBED, 60), "breaks free")
	assert_lt(grabber.move_frame, _headbutt_startup(), "before the headbutt's strike frame")
	assert_signal_emitted_with_parameters(CombatEvents, "grab_escaped", [_player, grabber])
	assert_eq(_player.state, CombatTypes.ActorState.FREE, "on his feet")
	assert_true(_player.is_invulnerable(), "invulnerable for a moment")
	await _ticks(_headbutt_startup() + 10)
	assert_eq(_player.health, 100.0, "the headbutt never lands")
	assert_true(_hits.is_empty())


func test_one_press_short_of_breaking_free_is_not_enough() -> void:
	var grabber := _grabber()
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _until_held())
	for i in Tuning.data.grab_break_presses - 1:
		_player.input.push_press(&"K", 1)
	await _ticks(20)
	assert_eq(_player.state, CombatTypes.ActorState.GRABBED, "still held")
	assert_almost_eq(_player.grab_break_progress(), 7.0 / 8.0, 0.001, "7 of 8")
	assert_true(await _until(func() -> bool: return not _hits.is_empty(), 120), "the headbutt lands")
	assert_eq(_player.health, 85.0)


func test_a_press_of_p_and_one_of_k_both_count() -> void:
	var grabber := _grabber()
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _until_held())
	for i in Tuning.data.grab_break_presses:
		_player.input.push_press(&"P" if i % 2 == 0 else &"K", 1)
	assert_true(await _until(func() -> bool: return _player.state != CombatTypes.ActorState.GRABBED, 60), "P and K alternating break free")


func test_a_held_button_is_one_press() -> void:
	var grabber := _grabber()
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _until_held())
	_player.input.push_press(&"P", 40)
	await _ticks(45)
	assert_almost_eq(_player.grab_break_progress(), 1.0 / 8.0, 0.001, "holding P down is one press")


func test_other_buttons_do_not_start_anything_while_held_and_nothing_waits_for_the_release() -> void:
	var grabber := _grabber()
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _until_held())
	for i in 4:
		_player.input.push_press(&"JUMP", 2)
		_player.input.push_press(&"DODGE", 2)
		_player.input.push_press(&"GRAB", 2)
	await _ticks(30)
	assert_eq(_player.state, CombatTypes.ActorState.GRABBED, "still held: those buttons do nothing")
	for i in Tuning.data.grab_break_presses:
		_player.input.push_press(&"P", 1)
	assert_true(await _until(func() -> bool: return _player.state == CombatTypes.ActorState.FREE, 60))
	await _ticks(10)
	assert_eq(_player.state, CombatTypes.ActorState.FREE, "no buffered press started a move after the release")
	assert_null(_player.current_move)


func test_the_mash_decays_when_the_tunable_asks() -> void:
	Tuning.data.grab_break_decay_per_s = 6.0
	var grabber := _grabber()
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _until_held())
	for i in 4:
		_player.input.push_press(&"P", 1)
	await _ticks(10)
	var after := _player.grab_break_progress()
	await _ticks(20)
	assert_lt(_player.grab_break_progress(), after, "it drains while he is not pressing")


func test_the_holder_staggers_away_when_broken_free_of_and_gives_its_token_back() -> void:
	var grabber := _grabber()
	await _ticks(4)
	_director.give_token(grabber)
	grabber.force_attack()
	assert_true(await _until_held())
	await _ticks(20)
	var held_at := _player.global_position
	for i in Tuning.data.grab_break_presses:
		_player.input.push_press(&"P", 1)
	assert_true(await _until(func() -> bool: return _player.state == CombatTypes.ActorState.FREE, 60))
	assert_eq(grabber.state, CombatTypes.ActorState.STAGGER, "the holder staggers")
	assert_null(grabber.current_move, "its follow-up is cancelled")
	assert_false(grabber.has_token, "token released")
	assert_true(_director.released.has(grabber), "to the director")
	assert_true(_ended.any(func(e: Dictionary) -> bool: return e.attacker == grabber and e.interrupted), "its wind-up ended interrupted")
	var away := (grabber.global_position - _player.global_position)
	away.y = 0.0
	assert_gte(Vector3(grabber.sim_velocity.x, 0.0, grabber.sim_velocity.z).dot(away.normalized()), Tuning.data.grab_break_push_mps * 0.9, "shoved away at grab_break_push_mps")
	assert_lt(_player.global_position.distance_to(held_at), 0.05, "the victim stays where it stands")
	await _ticks(Tuning.data.stagger_frames + 5)
	assert_true(grabber.ai_state in [EnemyActor.AiState.APPROACH, EnemyActor.AiState.POSTURE], "the AI goes on from there")


# --- The hit ------------------------------------------------------------------------------------


func test_the_slam_throws_him_for_25() -> void:
	var grabber := _grabber(1.2, true)
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _until_held())
	assert_true(await _until(func() -> bool: return not _hits.is_empty(), 200), "the slam lands")
	var hit := _hits[0]
	assert_eq(hit.move.id, &"boss_slam")
	assert_eq(hit.damage, 25.0)
	assert_eq(hit.reaction, CombatTypes.Reaction.THROWN)
	assert_eq(hit.tier, CombatTypes.HitTier.HEAVY, "HEAVY, never FINISHER")
	assert_eq(_player.health, 75.0)
	await _ticks(2)
	assert_true(_player.state in [CombatTypes.ActorState.THROWN, CombatTypes.ActorState.LAUNCHED], "thrown")
	assert_null(_player.holder)


func test_a_killing_headbutt_knocks_him_out_and_he_gets_up() -> void:
	_player.auto_revive = true
	_player.health = 10.0
	var grabber := _grabber()
	await _ticks(4)
	watch_signals(CombatEvents)
	grabber.force_attack()
	assert_true(await _until_held())
	assert_true(await _until(func() -> bool: return _player.health <= 0.0, 200), "15 damage kills 10 health")
	assert_true(await _until(func() -> bool: return _player.is_ko(), 120), "KO")
	assert_signal_emitted(CombatEvents, "ko")
	assert_true(await _until(func() -> bool: return _player.health > 0.0, 400), "the room revives him")
	assert_signal_emitted(CombatEvents, "revived")


func test_a_holder_knocked_down_lets_go_with_no_hit() -> void:
	var grabber := _grabber()
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _until_held())
	await _ticks(10)
	var other := _grabber(4.0)
	other.name = "Other"
	var flyer := _hit(other, grabber, 5.0, CombatTypes.HitTier.HEAVY, CombatTypes.Reaction.KNOCKDOWN)
	flyer.knockback = Vector3(0.0, 3.0, 2.0)
	grabber.receive_hit(flyer)
	await _ticks(3)
	assert_ne(_player.state, CombatTypes.ActorState.GRABBED, "he is let go")
	assert_null(_player.holder)
	assert_false(grabber.is_holding(_player))
	assert_eq(_player.health, 100.0, "and not hit")
	assert_false(_hits.any(func(h: HitInfo) -> bool: return h.victim == _player), "no hit on him at all")
	await _ticks(100)
	assert_eq(_player.health, 100.0)


func test_a_holder_killed_lets_go() -> void:
	var grabber := _grabber()
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _until_held())
	grabber.receive_hit(_hit(_player, grabber, 9999.0, CombatTypes.HitTier.HEAVY, CombatTypes.Reaction.KNOCKDOWN))
	await _ticks(3)
	assert_ne(_player.state, CombatTypes.ActorState.GRABBED, "he is let go")
	assert_eq(_player.health, 100.0)


func test_a_holder_that_is_removed_lets_go() -> void:
	var grabber := _grabber()
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _until_held())
	grabber.remove_from_group(&"actor")
	grabber.queue_free()
	await _ticks(4)
	assert_ne(_player.state, CombatTypes.ActorState.GRABBED, "he is let go")
	assert_eq(_player.health, 100.0)


func test_an_armored_holder_keeps_holding_through_a_light_hit() -> void:
	var grabber := _grabber(1.05, false, func(e: EnemyActor) -> void: e.armor_light = true)
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _until_held())
	grabber.receive_hit(_hit(_player, grabber, 2.0, CombatTypes.HitTier.LIGHT, CombatTypes.Reaction.FLINCH))
	await _ticks(3)
	assert_eq(_player.state, CombatTypes.ActorState.GRABBED, "armor absorbed it: still held")
	assert_true(grabber.is_holding(_player))


# --- The rear warning ----------------------------------------------------------------------------


const HUD_SCENE := preload("res://game/ui/hud.tscn")
const StubEnemyScene := preload("res://tests/fixtures/stub_enemy.tscn")


## The rear warning's corner `side` is lit now.
func _lit(hud: GameHud, side: StringName) -> bool:
	return hud.rear_warning.corner_state(side).active


## `rel` (x right, y ahead of the player, who looks along -Z) at `bearing_deg` (positive to the
## left, +-180 behind) and `distance_m`.
func _rel_at(bearing_deg: float, distance_m: float) -> Vector3:
	var b := deg_to_rad(bearing_deg)
	return Vector3(-sin(b) * distance_m, 0.0, -cos(b) * distance_m)


func _grabber_at(bearing_deg: float, distance_m: float) -> EnemyActor:
	var grabber := GRABBER_SCENE.instantiate() as EnemyActor
	grabber.name = "Grabber1"
	grabber.position = _rel_at(bearing_deg, distance_m)
	var to_player := _player.global_position - grabber.position
	grabber.rotation.y = atan2(-to_player.x, -to_player.z)
	_scene.add_child(grabber)
	return grabber


func test_the_warning_lights_for_the_grab_from_behind_and_ends_on_the_grab() -> void:
	var hud := HUD_SCENE.instantiate() as GameHud
	_scene.add_child(hud)
	var grabber := _grabber_at(135.0, 1.1)
	await _ticks(4)
	grabber.force_attack()
	await _ticks(3)
	assert_true(_lit(hud, &"left"), "behind-left: the top-left corner burns for the grab's wind-up")
	assert_false(_lit(hud, &"right"))
	assert_true(await _until_held(), "the grab connects (the grabber faces him)")
	await _ticks(2)
	assert_false(_lit(hud, &"left"), "it ends on the grab (grabbed)")
	# The follow-up winds up on a player already in its hands: no warning for it.
	for i in 30:
		await _ticks(1)
		assert_false(_lit(hud, &"left") or _lit(hud, &"right"), "no warning through the hold (tick %d)" % i)
	assert_true(grabber.state == CombatTypes.ActorState.WINDUP, "the headbutt is still winding up")
	assert_lt(grabber.warning_reach_m(grabber.current_move), 0.0, "its warning reach is one nothing is within")


func test_the_warning_ends_on_a_whiffed_grab() -> void:
	var hud := HUD_SCENE.instantiate() as GameHud
	_scene.add_child(hud)
	var grabber := _grabber_at(-135.0, 1.1)
	await _ticks(4)
	grabber.force_attack()
	await _ticks(3)
	assert_true(_lit(hud, &"right"), "behind-right: the top-right corner")
	assert_false(_lit(hud, &"left"))
	# He steps out of it: the grab whiffs and the warning goes with it.
	assert_true(await _until_grab_frame(grabber, 27))
	_player.input.scripted_move = Vector2(0.0, 1.0)
	_player.input.push_press(&"DODGE", 2)
	assert_true(await _until(func() -> bool: return not _whiffs.is_empty(), 40), "the grab whiffed")
	await _ticks(2)
	assert_false(_lit(hud, &"right"), "the warning ended with the whiff")


func test_the_warning_for_the_grab_carries_the_heavy_burst() -> void:
	var hud := HUD_SCENE.instantiate() as GameHud
	_scene.add_child(hud)
	var grabber := _grabber_at(100.0, 1.0)
	await _ticks(4)
	grabber.force_attack()
	await _ticks(3)
	assert_true(hud.rear_warning.corner_state(&"left").heavy, "a grabber is heavy: the larger burst")


# --- The director ----------------------------------------------------------------------------------


func test_the_director_gives_nobody_a_token_while_the_player_is_held() -> void:
	_director.queue_free()
	var director := EnemyDirector.new()
	director.rng_seed = 5
	_scene.add_child(director)
	Tuning.data.ai_frozen = false
	var grabber := _grabber(1.05)
	grabber.force_attack()
	var others: Array[EnemyActor] = []
	for i in 2:
		var other := StubEnemyScene.instantiate() as EnemyActor
		other.name = "Waiter%d" % i
		other.position = Vector3(-3.0 + 6.0 * i, 0.0, -2.5)  # inside the token reach (4.5 m)
		_scene.add_child(other)
		others.append(other)
	await _ticks(2)
	assert_true(await _until_held(), "held")
	for other: EnemyActor in others:
		other.set(&"want_token", true)
	await _ticks(40)
	assert_eq(_player.state, CombatTypes.ActorState.GRABBED, "still held")
	for other: EnemyActor in others:
		assert_false(other.has_token, "%s got no token while he is held" % other.name)
	assert_false(director.debug_token_holders().any(func(e: EnemyActor) -> bool: return e != grabber), "only the holder holds one (or none)")
	# Free again: the director gives out tokens once its grace is over.
	for i in Tuning.data.grab_break_presses:
		_player.input.push_press(&"P", 1)
	assert_true(await _until(func() -> bool: return _player.state == CombatTypes.ActorState.FREE, 60))
	assert_true(await _until(func() -> bool: return others.any(func(e: EnemyActor) -> bool: return e.has_token), 300), "and then it gives tokens again")


# --- In the rooms ---------------------------------------------------------------------------------


const CROWD_ROOM := preload("res://game/level/crowd_room.tscn")
const TRAINING_ROOM := preload("res://game/level/test_room.tscn")


## The room has its own player: the harness's goes.
func _drop_harness_player() -> void:
	_player.remove_from_group(&"player")
	_player.remove_from_group(&"actor")
	_player.queue_free()
	await _ticks(2)


func test_the_real_ai_walks_up_and_grabs_the_player_in_the_crowd_room() -> void:
	await _drop_harness_player()
	var room := CROWD_ROOM.instantiate()
	room.set(&"with_presentation", false)
	room.set(&"waves_enabled_on_start", false)
	add_child_autofree(room)
	Tuning.data.ai_frozen = false
	await _ticks(8)
	var player: PlayerCharacter = room.get(&"player")
	player.input.scripted = true
	var spawner: EncounterSpawner = room.get(&"spawner")
	spawner.scene_override[&"grab_test"] = GRABBER_SCENE
	var at := player.global_position + player.global_basis * Vector3(0.0, 0.0, -5.0)
	var enemy := spawner.spawn_enemy(&"grab_test", at, player.rotation.y + PI)
	assert_not_null(enemy, "spawned through the spawner")
	var held := func() -> bool: return player.state == CombatTypes.ActorState.GRABBED
	var got := false
	for i in 1500:
		await get_tree().physics_frame
		if held.call():
			got = true
			break
	assert_true(got, "the director gave it a token, it closed in, wound up and grabbed him")
	assert_eq(player.holder, enemy)
	for i in Tuning.data.grab_break_presses:
		player.input.push_press(&"P", 1)
	assert_true(await _until(func() -> bool: return player.state == CombatTypes.ActorState.FREE, 60), "mashed free in the crowd room")
	assert_eq(player.health, 100.0)


func test_the_grabber_grabs_and_is_mashed_out_of_in_the_training_room() -> void:
	await _drop_harness_player()
	var room := TRAINING_ROOM.instantiate()
	room.set(&"with_presentation", false)
	Tuning.data.ai_frozen = true
	add_child_autofree(room)
	await _ticks(4)
	var player: PlayerCharacter = room.get(&"player")
	player.input.scripted = true
	for dummy: TrainingDummy in room.get(&"dummies"):
		dummy.sparring = false
		dummy.global_position = Vector3(40.0, 0.0, 40.0)
	var grabber := GRABBER_SCENE.instantiate() as EnemyActor
	grabber.name = "Grabber1"
	grabber.position = player.global_position + player.global_basis * Vector3(0.0, 0.0, -1.1)
	grabber.rotation.y = player.rotation.y + PI
	room.add_child(grabber)
	await _ticks(4)
	grabber.force_attack()
	var got := await _until(func() -> bool: return player.state == CombatTypes.ActorState.GRABBED, 120)
	assert_true(got, "grabbed in the training room (no navmesh)")
	for i in Tuning.data.grab_break_presses:
		player.input.push_press(&"K", 1)
	assert_true(await _until(func() -> bool: return player.state == CombatTypes.ActorState.FREE, 60), "mashed free")
	assert_eq(player.health, 100.0)
