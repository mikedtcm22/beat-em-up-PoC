extends GutTest
## The Bruiser (Milestone 3, P3-bruiser): 80 HP, 2.05 m, heavy, armored. A light hit lands its damage
## and is absorbed (no flinch, no interrupt, no stretched wind-up), the hook (a heavy hit) and the
## uppercut (a finisher) stagger it, the haymaker knocks it down and opens the armor for a while once
## it is up, and it can be grabbed only while staggered or open. It smashes (15, a knockdown, a block
## costs the guard 60 and the Bruiser never recoils) or grabs (the headbutt, mashed free or landing).
## The harness is a flat code-built floor with the real player and a stub director
## (tests/fixtures/stub_director.gd), as tests/test_pipe_thug.gd does. One sim tick is one physics
## frame (the runner uses --fixed-fps 60).

const BRUISER_SCENE := preload("res://game/enemies/bruiser/bruiser.tscn")
const PUNK_SCENE := preload("res://game/enemies/punk/street_punk.tscn")
const StubDirector := preload("res://tests/fixtures/stub_director.gd")
const FPView := preload("res://tests/fp_view.gd")
const FRAME := 1.0 / 60.0
const LONG_TICKS := 900
## Nothing of the Bruiser may come nearer the lens than this (m) when a strike lands on the player:
## twice the first-person camera's near plane (0.05 m), so no part of it is ever cut by the plane.
const LENS_CLEARANCE_M := 0.1

var _scene: Node3D
var _player: PlayerCharacter
var _director: Object
var _hits: Array[HitInfo] = []
var _started: Array[Dictionary] = []
var _ended: Array[Dictionary] = []


func before_each() -> void:
	Tuning.reset_to_default()
	# The Bruiser stands where it is put and faces the player; force_attack() still starts its attack.
	Tuning.data.ai_frozen = true
	Tuning.data.god_mode = false
	Tuning.data.one_hit_ko = false
	TimeController.clear()
	TimeController.debug_scale = 1.0
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = false
	_hits.clear()
	_started.clear()
	_ended.clear()
	CombatEvents.hit_landed.connect(_on_hit_landed)
	CombatEvents.windup_started.connect(_on_windup_started)
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
	for pair: Array in [[CombatEvents.hit_landed, _on_hit_landed], [CombatEvents.windup_started, _on_windup_started],
			[CombatEvents.windup_ended, _on_windup_ended]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = true
	Tuning.reset_to_default()
	Tuning.data.god_mode = false
	TimeController.clear()


func _on_hit_landed(hit: HitInfo) -> void:
	_hits.append(hit)


func _on_windup_started(attacker: Node3D, move: MoveData) -> void:
	_started.append({attacker = attacker, move = move, frame = Engine.get_physics_frames()})


func _on_windup_ended(attacker: Node3D, interrupted: bool) -> void:
	_ended.append({attacker = attacker, interrupted = interrupted, frame = Engine.get_physics_frames()})


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


## A Bruiser `ahead_m` in front of the player (who looks along -Z), facing him, with `health` so a
## test's hits do not kill it.
func _bruiser(ahead_m: float = 1.2, health: float = 500.0, at: Vector3 = Vector3.INF) -> Bruiser:
	var bruiser := BRUISER_SCENE.instantiate() as Bruiser
	bruiser.name = "Bruiser1"
	bruiser.position = at if at.is_finite() else Vector3(0.0, 0.0, -ahead_m)
	bruiser.rotation.y = atan2(-(0.0 - bruiser.position.x), -(0.0 - bruiser.position.z))
	_scene.add_child(bruiser)
	bruiser.max_health = health
	bruiser.health = health
	return bruiser


## A hit on `victim`: a jab by default (LIGHT, FLINCH); `move` is the move it came from, if any.
func _hit(victim: CombatActor, damage: float = 6.0, tier: CombatTypes.HitTier = CombatTypes.HitTier.LIGHT,
		reaction: CombatTypes.Reaction = CombatTypes.Reaction.FLINCH, move: MoveData = null) -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = _player
	hit.victim = victim
	hit.damage = damage
	hit.tier = tier
	hit.reaction = reaction
	hit.move = move
	hit.knockback = Vector3(0.0, 0.0, 1.5) if reaction != CombatTypes.Reaction.LAUNCH else Vector3(0.0, 4.0, 6.0)
	hit.direction = Vector3.BACK * -1.0
	hit.contact_point = victim.global_position + Vector3.UP * 1.4
	return hit


func _move(id: StringName) -> MoveData:
	return load("res://game/combat/moves/%s.tres" % id) as MoveData


## The Bruiser winding up its smash: the frame it is in WINDUP and `frames` into it.
func _into_windup(bruiser: Bruiser, frames: int = 4) -> void:
	bruiser.force_attack(0)
	await _until(func() -> bool: return bruiser.state == CombatTypes.ActorState.WINDUP and bruiser.move_frame >= frames, 60)


# --- What it is --------------------------------------------------------------------------------


func test_a_bruiser_is_a_heavy_armored_ai_enemy_with_its_body_and_attacks() -> void:
	var bruiser := _bruiser(4.0, 80.0)
	await _ticks(3)
	assert_eq(bruiser.archetype, &"bruiser")
	assert_eq(bruiser.team, 1)
	for group: StringName in [&"actor", &"enemy", &"ai_enemy"]:
		assert_true(bruiser.is_in_group(group), "in group %s" % group)
	assert_false(bruiser.is_in_group(&"boss"), "not the boss")
	assert_true(bruiser.heavy, "heavy: the larger warning burst and the heavy wind-up floor")
	assert_true(bruiser.armor_light and bruiser.armor_heavy_to_stagger and bruiser.armor_finisher_to_stagger, "armored")
	assert_almost_eq(bruiser.body_height, 2.05, 0.0001)
	assert_almost_eq(bruiser.body_radius, 0.45, 0.0001)
	assert_lt(bruiser.voice_pitch_mult, 1.0, "a deeper voice")
	# SPEC §10: red is the warning's, the blood's and the finishers'. Deep purple: blue over red, no green.
	assert_gt(bruiser.color.b, bruiser.color.r, "the jacket is a purple, no red")
	assert_gt(bruiser.color.r, bruiser.color.g, "a purple, not a blue")
	assert_ne(bruiser.color, Color(0.86, 0.5, 0.16), "not the training dummy's orange")
	assert_eq(bruiser._attacks.size(), 2, "two attacks")
	assert_eq(bruiser._attacks[0].kind, &"strike")
	assert_eq(bruiser._attacks[0].moves[0].id, &"bruiser_smash")
	assert_eq(bruiser._attacks[1].kind, &"grab", "the grab goes through EnemyHold")
	assert_eq([bruiser._attacks[1].moves[0].id, bruiser._attacks[1].moves[1].id], [&"bruiser_grab", &"bruiser_headbutt"] as Array[StringName])
	assert_true(bruiser._attacks[0].heavy and bruiser._attacks[1].heavy, "both wind up at the heavy floor")


func test_the_health_follows_its_tunable_keeping_the_share_left() -> void:
	var bruiser := BRUISER_SCENE.instantiate() as Bruiser
	_scene.add_child(bruiser)
	await _ticks(2)
	assert_almost_eq(bruiser.max_health, 80.0, 0.001, "80 HP from the tunable")
	bruiser.health = 40.0
	Tuning.set_value(&"bruiser_health", 160.0)
	assert_almost_eq(bruiser.max_health, 160.0, 0.001)
	assert_almost_eq(bruiser.health, 80.0, 0.001, "half left stays half")


func test_the_smash_is_wound_up_at_the_heavy_floor_and_scales_with_windup_mult() -> void:
	var smash := _move(&"bruiser_smash")
	assert_gte(smash.startup, Tuning.data.windup_min_frames_heavy, "its own startup is the telegraph")
	assert_eq(EnemyActor.windup_move(smash, true).startup, smash.startup, "the default multiplier leaves it")
	Tuning.data.windup_mult = 0.25
	assert_eq(EnemyActor.windup_move(smash, true).startup, Tuning.data.windup_min_frames_heavy, "floored at 30, never 9")
	Tuning.data.windup_mult = 1.0
	var bruiser := _bruiser()
	await _ticks(3)
	await _into_windup(bruiser, 1)
	assert_eq(bruiser.current_move.startup, smash.startup, "the wind-up it runs")


# --- Armor -------------------------------------------------------------------------------------


func test_a_light_hit_lands_its_damage_and_is_absorbed() -> void:
	var bruiser := _bruiser()
	await _ticks(3)
	var hit := _hit(bruiser)
	assert_true(bruiser.receive_hit(hit), "the hit lands")
	assert_true(hit.armor_absorbed, "armor took the reaction")
	assert_eq(hit.reaction, CombatTypes.Reaction.NONE)
	assert_eq(hit.knockback, Vector3.ZERO)
	assert_almost_eq(bruiser.health, 494.0, 0.001, "the damage landed")
	assert_eq(bruiser.state, CombatTypes.ActorState.FREE, "no flinch")
	assert_true(hit.describe().ends_with(" ARMOR") or hit.describe().contains(" ARMOR"), "the combat log reads ARMOR")


func test_jabs_in_the_windup_land_damage_and_neither_interrupt_nor_stretch_it() -> void:
	var bruiser := _bruiser()
	await _ticks(3)
	await _into_windup(bruiser, 8)
	var before := bruiser.health
	_player.input.push_press(&"P", 2)
	_player.input.push_wait(6)
	_player.input.push_press(&"P", 2)
	assert_true(await _until(func() -> bool: return not _ended.is_empty(), 120), "the wind-up ends")
	var jabs := _hits.filter(func(h: HitInfo) -> bool: return h.victim == bruiser)
	assert_gte(jabs.size(), 2, "both jabs landed (%d)" % jabs.size())
	for hit: HitInfo in jabs:
		assert_true(hit.armor_absorbed, "%s was absorbed" % hit.move.id)
	assert_lt(bruiser.health, before, "their damage landed")
	assert_false(_ended[0].interrupted, "the wind-up ended in its strike, not interrupted")
	var length: int = _ended[0].frame - _started[0].frame
	assert_almost_eq(float(length), float(_move(&"bruiser_smash").startup), 1.0, "no hitstop on the armored victim stretched it (%d frames)" % length)


func test_the_rear_warning_keeps_going_through_an_absorbed_hit_and_the_burst_is_the_larger_one() -> void:
	var warning := RearWarning.new()
	warning.size = Vector2(1920.0, 1080.0)
	_scene.add_child(warning)
	_player.look_yaw = 0.0
	var bruiser := _bruiser(0.0, 500.0, Vector3(-1.0, 0.0, 1.0))  # behind-left of a player looking along -Z
	await _ticks(3)
	bruiser.force_attack(0)
	assert_true(await _until(func() -> bool: return bruiser.state == CombatTypes.ActorState.WINDUP and bruiser.move_frame >= 4, 60))
	warning.advance(0.0)
	var left: Dictionary = warning.corner_state(&"left")
	assert_true(left.active, "the Bruiser behind-left of the look lights the left corner")
	assert_true(left.heavy, "and it is the heavy one")
	bruiser.receive_hit(_hit(bruiser))
	await _ticks(2)
	warning.advance(0.0)
	assert_true(warning.corner_state(&"left").active, "an absorbed jab does not end the warning")
	assert_eq(bruiser.state, CombatTypes.ActorState.WINDUP, "the wind-up goes on")
	# A Punk at the same spot: a smaller burst than the Bruiser's.
	var punk := PUNK_SCENE.instantiate() as StreetPunk
	punk.name = "Punk1"
	punk.position = Vector3(1.0, 0.0, 1.0)
	_scene.add_child(punk)
	await _ticks(3)
	punk.force_attack(0)
	assert_true(await _until(func() -> bool: return punk.state == CombatTypes.ActorState.WINDUP, 60))
	warning.advance(0.0)
	var right: Dictionary = warning.corner_state(&"right")
	assert_true(right.active and not right.heavy, "the Punk lights the other corner, not heavy")
	assert_gt(float(left.size_px), float(right.size_px), "the Bruiser's burst is larger (%.0f against %.0f px)" % [left.size_px, right.size_px])
	var reserved := Rect2(0.0, 0.0, 1920.0 * 0.2, 1080.0 * 0.2)
	assert_true(reserved.encloses(warning.corner_state(&"left").rect), "inside its reserved corner")
	# The smash comes out and lands (the player is in reach? no: it is behind), the warning ends with it.
	assert_true(await _until(func() -> bool: return bruiser.current_move == null, 200))
	warning.advance(0.0)
	assert_false(warning.corner_state(&"left").active, "the warning ends with the attack")


func test_the_hook_staggers_it_out_of_its_windup() -> void:
	var bruiser := _bruiser()
	await _ticks(3)
	await _into_windup(bruiser, 8)
	var hook := _move(&"hook")
	var hit := _hit(bruiser, 8.0, CombatTypes.HitTier.HEAVY, CombatTypes.Reaction.STAGGER, hook)
	bruiser.receive_hit(hit)
	assert_false(hit.armor_absorbed, "a heavy hit is not absorbed")
	assert_eq(bruiser.state, CombatTypes.ActorState.STAGGER, "staggered")
	assert_null(bruiser.current_move, "out of the move")
	assert_true(_ended[0].interrupted, "the wind-up ended interrupted")
	assert_eq(bruiser.ai_state, EnemyActor.AiState.REACT)


func test_the_uppercut_a_finisher_staggers_it_instead_of_launching_it() -> void:
	var bruiser := _bruiser()
	await _ticks(3)
	var hit := _hit(bruiser, 12.0, CombatTypes.HitTier.FINISHER, CombatTypes.Reaction.LAUNCH, _move(&"uppercut"))
	bruiser.receive_hit(hit)
	assert_eq(hit.reaction, CombatTypes.Reaction.STAGGER)
	assert_eq(bruiser.state, CombatTypes.ActorState.STAGGER, "staggered, not launched")
	assert_false(bruiser.is_flying())


func test_the_haymaker_knocks_it_down_and_opens_the_armor_once_it_is_up() -> void:
	var bruiser := _bruiser()
	await _ticks(3)
	var hit := _hit(bruiser, 18.0, CombatTypes.HitTier.FINISHER, CombatTypes.Reaction.LAUNCH, _move(&"haymaker"))
	bruiser.receive_hit(hit)
	assert_false(hit.armor_absorbed)
	assert_eq(hit.reaction, CombatTypes.Reaction.LAUNCH, "the haymaker keeps its own reaction")
	assert_true(bruiser.is_flying(), "knocked off its feet")
	assert_true(bruiser.armor_is_broken(), "the armor is broken")
	var full := Tuning.data.bruiser_armor_break_s
	assert_almost_eq(bruiser.armor_break_left_s(), full, 0.05, "the window has not started: it is on the floor")
	assert_true(await _until(func() -> bool: return bruiser.is_downed(), 200))
	await _ticks(Tuning.data.downed_frames - 10)
	assert_almost_eq(bruiser.armor_break_left_s(), full, 0.05, "it does not run down while the Bruiser lies there")
	assert_true(await _until(func() -> bool: return bruiser.state == CombatTypes.ActorState.FREE, 300), "it gets up")
	assert_true(bruiser.armor_is_broken(), "and the armor is still off")
	# A jab flinches it now.
	await _ticks(Tuning.data.getup_invuln_frames + 2)
	var jab := _hit(bruiser, 6.0, CombatTypes.HitTier.LIGHT, CombatTypes.Reaction.FLINCH, _move(&"jab_1"))
	bruiser.receive_hit(jab)
	assert_false(jab.armor_absorbed, "armor off: not absorbed")
	assert_eq(bruiser.state, CombatTypes.ActorState.HITSTUN, "it flinches")
	# Then the window closes: bruiser_armor_break_s after it was up.
	assert_true(await _until(func() -> bool: return not bruiser.armor_is_broken(), 400), "the armor comes back")
	assert_true(await _until(func() -> bool: return bruiser.state == CombatTypes.ActorState.FREE, 100))
	var later := _hit(bruiser, 6.0, CombatTypes.HitTier.LIGHT, CombatTypes.Reaction.FLINCH, _move(&"jab_1"))
	bruiser.receive_hit(later)
	assert_true(later.armor_absorbed, "absorbed again")


func test_a_second_haymaker_restarts_the_window() -> void:
	var bruiser := _bruiser()
	await _ticks(3)
	bruiser.receive_hit(_hit(bruiser, 18.0, CombatTypes.HitTier.FINISHER, CombatTypes.Reaction.LAUNCH, _move(&"haymaker")))
	assert_true(await _until(func() -> bool: return bruiser.state == CombatTypes.ActorState.FREE and not bruiser.is_invulnerable(), 400))
	await _ticks(30)
	var left := bruiser.armor_break_left_s()
	assert_lt(left, Tuning.data.bruiser_armor_break_s - 0.3, "it has run down")
	bruiser.receive_hit(_hit(bruiser, 18.0, CombatTypes.HitTier.FINISHER, CombatTypes.Reaction.LAUNCH, _move(&"haymaker")))
	assert_almost_eq(bruiser.armor_break_left_s(), Tuning.data.bruiser_armor_break_s, 0.05, "full again")


func test_reset_state_puts_the_armor_back_on() -> void:
	var bruiser := _bruiser()
	await _ticks(3)
	bruiser._break_armor()
	assert_true(bruiser.armor_is_broken())
	bruiser.reset_state()
	assert_false(bruiser.armor_is_broken(), "a fresh Bruiser has its armor")
	assert_eq(bruiser.armor_break_left_s(), 0.0)
	assert_true(bruiser.debug_state_text().find("ARMOR OFF") < 0)


func test_a_killing_light_hit_is_never_absorbed() -> void:
	var bruiser := _bruiser(1.2, 500.0)
	await _ticks(3)
	bruiser.health = 3.0
	var hit := _hit(bruiser, 6.0)
	bruiser.receive_hit(hit)
	assert_false(hit.armor_absorbed)
	assert_true(hit.killed, "armor never saves a body")
	assert_eq(bruiser.ai_state, EnemyActor.AiState.KO)


func test_the_brace_plays_when_a_light_hit_bounces_off_a_bruiser_with_no_move_running() -> void:
	var bruiser := _bruiser()
	await _ticks(3)
	bruiser.receive_hit(_hit(bruiser))
	assert_eq(bruiser.rig.current_anim(), &"brace", "the chest pushes out")
	await _ticks(2)
	assert_eq(bruiser.rig.current_anim(), &"brace", "and the AI's locomotion leaves it be while it plays")
	await _ticks(60)
	assert_ne(bruiser.rig.current_anim(), &"brace", "then it is back in its stance")
	# In a wind-up the move's own pose is never swapped for it.
	await _into_windup(bruiser, 8)
	var anim := bruiser.rig.current_anim()
	bruiser.receive_hit(_hit(bruiser))
	assert_eq(bruiser.rig.current_anim(), anim, "the telegraph keeps its pose")
	assert_eq(anim, &"bruiser_smash")


# --- Grabbing it -------------------------------------------------------------------------------


func test_it_can_be_grabbed_only_staggered_or_with_its_armor_open() -> void:
	var bruiser := _bruiser()
	await _ticks(3)
	assert_false(bruiser.can_be_grabbed(), "standing: no")
	await _into_windup(bruiser, 8)
	assert_false(bruiser.can_be_grabbed(), "winding up: no")
	bruiser.receive_hit(_hit(bruiser, 8.0, CombatTypes.HitTier.HEAVY, CombatTypes.Reaction.STAGGER, _move(&"hook")))
	assert_eq(bruiser.state, CombatTypes.ActorState.STAGGER)
	assert_true(bruiser.can_be_grabbed(), "staggered: yes")
	await _until(func() -> bool: return bruiser.state == CombatTypes.ActorState.FREE, 200)
	assert_false(bruiser.can_be_grabbed(), "on its feet again, armor on: no")
	bruiser._break_armor()
	assert_true(bruiser.can_be_grabbed(), "armor open: yes")


func test_the_player_grabs_a_staggered_bruiser_with_lb_and_not_a_standing_one() -> void:
	var bruiser := _bruiser(1.0)
	await _ticks(3)
	_player.input.push_press(&"GRAB", 2)
	await _ticks(20)
	assert_ne(_player.state, CombatTypes.ActorState.GRABBING, "a standing Bruiser cannot be taken")
	bruiser.receive_hit(_hit(bruiser, 8.0, CombatTypes.HitTier.HEAVY, CombatTypes.Reaction.STAGGER, _move(&"hook")))
	bruiser.sim_velocity = Vector3.ZERO
	_player.input.push_press(&"GRAB", 2)
	assert_true(await _until(func() -> bool: return _player.state == CombatTypes.ActorState.GRABBING, 20), "a staggered one is")
	assert_eq(bruiser.state, CombatTypes.ActorState.GRABBED)
	# Knee it, then throw it: the heavy body goes where any held body goes.
	_player.input.push_press(&"K", 2)
	await _ticks(10)
	_player.input.push_press(&"GRAB", 2)
	await _ticks(2)
	assert_true(await _until(func() -> bool: return _player.state == CombatTypes.ActorState.FREE, 200), "the player is free again")


func test_a_perfect_block_staggers_the_bruiser_that_was_blocked() -> void:
	var bruiser := _bruiser()
	await _ticks(3)
	await _into_windup(bruiser, 8)
	await _until(func() -> bool: return bruiser.state == CombatTypes.ActorState.ATTACK, 60)
	var blocked := _hit(_player, 15.0, CombatTypes.HitTier.HEAVY, CombatTypes.Reaction.KNOCKDOWN, _move(&"bruiser_smash"))
	blocked.attacker = bruiser
	blocked.blocked = true
	blocked.perfect_block = true
	bruiser.react_to_block(blocked)
	assert_eq(bruiser.state, CombatTypes.ActorState.STAGGER, "a parry still staggers it (kept on purpose)")
	assert_true(bruiser.can_be_grabbed(), "and a staggered Bruiser can be grabbed")
	assert_true(bruiser._parry_staggers())


# --- Its attacks -------------------------------------------------------------------------------


func test_the_smash_lands_for_15_and_knocks_the_player_down() -> void:
	var bruiser := _bruiser()
	await _ticks(3)
	bruiser.force_attack(0)
	assert_true(await _until(func() -> bool: return _hits.any(func(h: HitInfo) -> bool: return h.victim == _player), 200), "it lands")
	var hit: HitInfo = _hits.filter(func(h: HitInfo) -> bool: return h.victim == _player)[0]
	assert_eq(hit.move.id, &"bruiser_smash")
	assert_eq(hit.damage, 15.0)
	assert_eq(hit.tier, CombatTypes.HitTier.HEAVY)
	assert_eq(hit.reaction, CombatTypes.Reaction.KNOCKDOWN)
	assert_eq(_player.health, 85.0, "15 of 100: the 15% rule's limit")
	await _ticks(3)
	assert_true(_player.state in [CombatTypes.ActorState.LAUNCHED, CombatTypes.ActorState.DOWNED], "knocked down")
	assert_eq(_started.size(), 1, "one telegraph")
	assert_gte(_started[0].move.startup, Tuning.data.windup_min_frames_heavy)


func test_the_smash_on_a_raised_guard_drains_60_and_the_bruiser_does_not_recoil() -> void:
	_player.input.push_down(&"DODGE")
	while _player.input.queued() > 0:
		await get_tree().physics_frame
	await _ticks(Tuning.data.block_raise_frames + 2)
	var bruiser := _bruiser()
	await _ticks(3)
	bruiser.force_attack(0)
	assert_true(await _until(func() -> bool: return _hits.any(func(h: HitInfo) -> bool: return h.victim == _player), 200))
	var hit: HitInfo = _hits.filter(func(h: HitInfo) -> bool: return h.victim == _player)[0]
	assert_true(hit.blocked, "the guard stops it: it is blockable")
	assert_false(hit.guard_broken, "60 of the 100 does not break it")
	assert_almost_eq(_player.guard, Tuning.data.guard_max - 60.0, 0.01, "the guard lost 60 (4 per damage)")
	assert_almost_eq(_player.health, 100.0 - 15.0 * Tuning.data.chip_ratio, 0.01, "only the chip got through")
	await _ticks(2)
	assert_ne(bruiser.state, CombatTypes.ActorState.HITSTUN, "it does not recoil from the block")
	assert_eq(bruiser.state, CombatTypes.ActorState.ATTACK, "its recovery plays out")


func test_a_whiffed_smash_ends_the_attack_and_recovers() -> void:
	var bruiser := _bruiser(3.5)
	await _ticks(3)
	bruiser.force_attack(0)
	assert_true(await _until(func() -> bool: return bruiser.ai_state == EnemyActor.AiState.RECOVER, 200))
	assert_true(_hits.is_empty())
	assert_false(_ended.is_empty() or _ended[0].interrupted, "it ended in the strike")


func test_the_grab_mashed_free_and_the_headbutt_left_to_land() -> void:
	var bruiser := _bruiser(1.1)
	await _ticks(3)
	bruiser.force_attack(1)
	assert_true(await _until(func() -> bool: return _player.state == CombatTypes.ActorState.GRABBED, 120), "the grab connects")
	assert_true(bruiser.is_holding(_player))
	for i in Tuning.data.grab_break_presses:
		_player.input.push_press(&"P", 1)
		await _ticks(2)
	assert_ne(_player.state, CombatTypes.ActorState.GRABBED, "free before the headbutt")
	assert_eq(_player.health, 100.0, "nothing was lost")
	assert_eq(bruiser.state, CombatTypes.ActorState.STAGGER, "the Bruiser staggers away from it")
	assert_true(bruiser.can_be_grabbed(), "a Bruiser that got mashed off is open to a grab")
	# And the other way: held and not mashing, the headbutt knocks him down for 15.
	await _until(func() -> bool: return bruiser.state == CombatTypes.ActorState.FREE, 200)
	_hits.clear()
	bruiser._cooldown_frames = 0
	bruiser.global_position = Vector3(0.0, 0.0, -1.1)
	bruiser.rotation.y = PI
	_player.sim_velocity = Vector3.ZERO
	await _ticks(70)
	bruiser.force_attack(1)
	assert_true(await _until(func() -> bool: return _player.state == CombatTypes.ActorState.GRABBED, 120))
	assert_true(await _until(func() -> bool: return _hits.any(func(h: HitInfo) -> bool: return h.victim == _player), 200))
	var hit: HitInfo = _hits.filter(func(h: HitInfo) -> bool: return h.victim == _player)[0]
	assert_eq(hit.move.id, &"bruiser_headbutt")
	assert_eq(hit.damage, 15.0)
	assert_eq(hit.reaction, CombatTypes.Reaction.KNOCKDOWN)


func test_a_heavy_hit_gets_the_player_out_of_the_grab_windup_and_a_light_one_does_not() -> void:
	var bruiser := _bruiser(1.1)
	await _ticks(3)
	bruiser.force_attack(1)
	await _until(func() -> bool: return bruiser.state == CombatTypes.ActorState.WINDUP and bruiser.move_frame >= 8, 60)
	bruiser.receive_hit(_hit(bruiser))
	assert_eq(bruiser.state, CombatTypes.ActorState.WINDUP, "a jab does not stop the grab")
	bruiser.receive_hit(_hit(bruiser, 8.0, CombatTypes.HitTier.HEAVY, CombatTypes.Reaction.STAGGER, _move(&"hook")))
	assert_eq(bruiser.state, CombatTypes.ActorState.STAGGER, "a hook does")
	await _ticks(120)
	assert_ne(_player.state, CombatTypes.ActorState.GRABBED, "the player was never grabbed")


# --- Its AI ------------------------------------------------------------------------------------


func test_with_a_token_it_closes_in_winds_up_attacks_and_gives_the_token_back() -> void:
	Tuning.data.ai_frozen = false
	var bruiser := _bruiser(3.0)
	bruiser._rng.seed = 3
	await _ticks(4)
	_director.give_token(bruiser)
	assert_true(await _until(func() -> bool: return bruiser.state == CombatTypes.ActorState.WINDUP, 400), "it winds up")
	assert_true(await _until(func() -> bool: return bruiser.ai_state == EnemyActor.AiState.RECOVER, 400), "and finishes")
	assert_false(bruiser.has_token, "the token goes back when the attack ends")
	assert_true(_director.released.has(bruiser))
	assert_false(bruiser.wants_token(), "the cooldown is on")


func test_a_token_is_released_when_a_hook_staggers_it_mid_attack() -> void:
	Tuning.data.ai_frozen = false
	var bruiser := _bruiser(1.2)
	await _ticks(4)
	_director.give_token(bruiser)
	await _until(func() -> bool: return bruiser.state == CombatTypes.ActorState.WINDUP, 400)
	bruiser.receive_hit(_hit(bruiser))
	assert_true(bruiser.has_token, "a light hit leaves it its token: the attack goes on")
	bruiser.receive_hit(_hit(bruiser, 8.0, CombatTypes.HitTier.HEAVY, CombatTypes.Reaction.STAGGER, _move(&"hook")))
	assert_false(bruiser.has_token, "a hook takes it away")


# --- The first-person view of its strikes (A6.3) ---------------------------------------------------


func _camera() -> FirstPersonCamera:
	var cam := FirstPersonCamera.new()
	_scene.add_child(cam)
	cam.player = _player
	cam.update_camera(FRAME)
	return cam


## Over `ticks` ticks the nearest any of `bruiser`'s meshes comes to the lens (m), and the most of the
## view they cover (0..1), judged from the real first-person camera.
func _watch_lens(bruiser: Bruiser, cam: FirstPersonCamera, ticks: int) -> Dictionary:
	var nearest := INF
	var covered := 0.0
	for i in ticks:
		await _ticks(1)
		cam.update_camera(FRAME)
		var view := cam.view_transform()
		nearest = minf(nearest, FPView.nearest_mesh(bruiser, view.origin))
		if i % 3 == 0:
			var cells := FPView.hits(_scene, Transform3D(view.basis, view.origin))
			covered = maxf(covered, FPView.share(cells, func(m: MeshInstance3D) -> bool: return bruiser.rig.is_ancestor_of(m)))
	return {nearest = nearest, covered = covered}


func test_the_smash_landing_on_the_player_keeps_the_bruiser_off_the_lens() -> void:
	var bruiser := _bruiser(1.25)
	await _ticks(3)
	var cam := _camera()
	bruiser.force_attack(0)
	assert_true(await _until(func() -> bool: return bruiser.state == CombatTypes.ActorState.WINDUP, 20))
	var stats := await _watch_lens(bruiser, cam, _move(&"bruiser_smash").total_frames() + 30)
	assert_true(_hits.any(func(h: HitInfo) -> bool: return h.victim == _player), "the smash landed")
	gut.p("smash on the player: nearest Bruiser mesh %.2f m from the lens, up to %.0f%% of the view" % [stats.nearest, stats.covered * 100.0])
	assert_gte(stats.nearest, LENS_CLEARANCE_M, "nothing within %.2f m of the lens (%.3f)" % [LENS_CLEARANCE_M, stats.nearest])
	assert_lte(stats.covered, 0.9, "it never fills the whole view (%.0f%%)" % (stats.covered * 100.0))


func test_the_headbutt_landing_on_the_player_keeps_the_bruiser_off_the_lens() -> void:
	var bruiser := _bruiser(1.1)
	await _ticks(3)
	var cam := _camera()
	bruiser.force_attack(1)
	assert_true(await _until(func() -> bool: return _player.state == CombatTypes.ActorState.GRABBED, 120))
	var stats := await _watch_lens(bruiser, cam, _move(&"bruiser_headbutt").total_frames() + 30)
	assert_true(_hits.any(func(h: HitInfo) -> bool: return h.victim == _player), "the headbutt landed")
	gut.p("headbutt on the player: nearest Bruiser mesh %.2f m from the lens, up to %.0f%% of the view" % [stats.nearest, stats.covered * 100.0])
	assert_gte(stats.nearest, LENS_CLEARANCE_M, "nothing within %.2f m of the lens (%.3f)" % [LENS_CLEARANCE_M, stats.nearest])


func test_a_bruiser_the_player_holds_is_not_a_wall_in_the_lens() -> void:
	# The held pose bends a body over at the waist in front of the lens. A 2.05 m Bruiser is bigger and
	# its head nearer than a 1.8 m body's (0.08 m from the lens and 83% of the view at the same pin), so
	# it stands bruiser_held_pin_extra_m further out: nearer than 0.24 m and beyond a third of the view
	# is what a held 1.8 m dummy does.
	var bruiser := _bruiser(1.0)
	await _ticks(3)
	var cam := _camera()
	bruiser.receive_hit(_hit(bruiser, 8.0, CombatTypes.HitTier.HEAVY, CombatTypes.Reaction.STAGGER, _move(&"hook")))
	bruiser.sim_velocity = Vector3.ZERO
	_player.input.push_press(&"GRAB", 2)
	assert_true(await _until(func() -> bool: return _player.state == CombatTypes.ActorState.GRABBING, 20), "the player holds it")
	var stats := await _watch_lens(bruiser, cam, 60)
	gut.p("held Bruiser: nearest mesh %.2f m from the lens, up to %.0f%% of the view" % [stats.nearest, stats.covered * 100.0])
	assert_gte(stats.nearest, 0.24, "nothing nearer the lens than a held 1.8 m body's (%.3f)" % stats.nearest)
	assert_lte(stats.covered, 0.5, "it covers no more than half the view (%.0f%%)" % (stats.covered * 100.0))


func test_the_knee_and_the_throw_still_reach_a_held_bruiser_pushed_out_to_stand_further_off() -> void:
	var bruiser := _bruiser(1.0)
	await _ticks(3)
	bruiser.receive_hit(_hit(bruiser, 8.0, CombatTypes.HitTier.HEAVY, CombatTypes.Reaction.STAGGER, _move(&"hook")))
	bruiser.sim_velocity = Vector3.ZERO
	_player.input.push_press(&"GRAB", 2)
	assert_true(await _until(func() -> bool: return _player.state == CombatTypes.ActorState.GRABBING, 20))
	await _ticks(14)
	_player.input.push_press(&"P", 2)
	await _ticks(30)
	assert_true(_hits.any(func(h: HitInfo) -> bool: return h.victim == bruiser and h.move != null and h.move.id == &"knee"), "the knee lands on it")
	await _until(func() -> bool: return _player.current_move == null, 60)
	await _ticks(4)
	_player.input.push_press(&"K", 2)
	await _ticks(60)
	assert_true(_hits.any(func(h: HitInfo) -> bool: return h.victim == bruiser and h.move != null and h.move.id == &"throw"), "and so does the throw")
