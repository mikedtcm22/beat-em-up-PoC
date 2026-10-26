extends GutTest
## The boss (Milestone 3, P3-boss): its body and armor (light hits absorbed and no interrupt, heavy
## hits stagger it out of any wind-up, the grab's among them, finishers knock it down, it can never
## be grabbed), its attacks in play (the ground pound hits a standing player, goes through a guard
## and misses a jumping one; the charge dashes only in its active frames, knocks a standing player
## down for 20 and stops at a wall; the grab slam is the grab table's, proved in test_enemy_grab.gd
## with the same moves), the attack chosen by range, the rear warning's reach for a charge from
## behind, the parry's recoil, its poise (a heavy hit and a finisher absorbed for a while after it gets
## up, never the haymaker, never the grab's cut) and the step back before a wind-up that cannot be read
## up close, phase 2 (once, at half health: the event, the turn rate, two Punks
## through a spawner and without one), the HUD's boss bar, the view at its posture distance and the
## first-person lens when its strikes land. Flat-floor tests have no navmesh (it steers straight, as
## in the training room); every tick is one physics frame.

const BOSS_SCENE := preload("res://game/enemies/boss/boss.tscn")
const HUD_SCENE := preload("res://game/ui/hud.tscn")
const StubDirector := preload("res://tests/fixtures/stub_director.gd")
const FPView := preload("res://tests/fp_view.gd")
const Checks := preload("res://tests/enemy_move_checks.gd")
const ROOM_PATH := "res://game/level/crowd_room.tscn"
const MOVES_DIR := "res://game/combat/moves/"
const FRAME := 1.0 / 60.0
const LONG_TICKS := 900
## The wind-up never slides: the most the body may move during it (m).
const SLIDE_TOLERANCE_M := 0.01
## Nothing of the boss may be nearer the lens than this when its strike lands (m): the same
## arm's-length rule as the held view's.
const LENS_CLEARANCE_M := 0.25
## A boss at the posture ring covers at most this share of the first-person view (the readability
## probe's R8 limit for the 95th percentile frame).
const VIEW_SHARE_MAX := 0.5

var _scene: Node3D
var _player: PlayerCharacter
var _director: Object
var _hits: Array[HitInfo] = []
var _ended: Array[Dictionary] = []


func before_each() -> void:
	Tuning.reset_to_default()
	# The boss stands where it is put and faces the player: force_attack() still starts its attack.
	Tuning.data.ai_frozen = true
	Tuning.data.god_mode = false
	Tuning.data.one_hit_ko = false
	Tuning.data.waves_enabled = false
	TimeController.clear()
	TimeController.debug_scale = 1.0
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = false
	_hits.clear()
	_ended.clear()
	CombatEvents.hit_landed.connect(_on_hit_landed)
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
	for pair: Array in [[CombatEvents.hit_landed, _on_hit_landed], [CombatEvents.windup_ended, _on_windup_ended]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = true
	Tuning.reset_to_default()
	Tuning.data.god_mode = false
	TimeController.clear()


func _on_hit_landed(hit: HitInfo) -> void:
	_hits.append(hit)


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


## The boss `ahead_m` in front of the player (who looks along -Z), facing him.
func _boss(ahead_m: float = 2.5, configure: Callable = Callable()) -> Boss:
	var boss := BOSS_SCENE.instantiate() as Boss
	boss.name = "Boss1"
	boss.position = Vector3(0.0, 0.0, -ahead_m)
	boss.rotation.y = PI
	if configure.is_valid():
		configure.call(boss)
	_scene.add_child(boss)
	return boss


func _move(id: StringName) -> MoveData:
	return load("%s%s.tres" % [MOVES_DIR, id]) as MoveData


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


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


## Wait until `boss` is winding up its attack `index` (it starts from the next control tick).
func _wind_up(boss: Boss, index: int) -> bool:
	boss.force_attack(index)
	return await _until(func() -> bool: return boss.state == CombatTypes.ActorState.WINDUP, 10)


# --- Body, armor, never grabbed ---------------------------------------------------------------


func test_the_boss_is_the_plans_body_groups_and_attacks() -> void:
	var boss := _boss()
	await _ticks(2)
	assert_eq(boss.body_height, 2.3)
	assert_eq(boss.body_radius, 0.5)
	assert_eq(boss.archetype, &"boss")
	assert_true(boss.heavy, "the heavy wind-up floor and the larger rear-warning burst")
	assert_eq(boss.max_health, 300.0)
	assert_eq(boss.health, 300.0)
	assert_eq(boss.display_name, "Boss")
	assert_almost_eq(boss.voice_pitch_mult, 0.7, 0.0001, "a deep voice")
	for group: StringName in [&"actor", &"enemy", &"ai_enemy", &"boss"]:
		assert_true(boss.is_in_group(group), "in group %s" % group)
	assert_true(boss.armor_light and boss.armor_heavy_to_stagger, "light absorbed, heavy staggers")
	assert_false(boss.armor_finisher_to_stagger, "a finisher knocks it down: the punish window")
	assert_eq(boss._attacks.size(), 3)
	assert_eq(boss._attacks[0].moves[0].id, &"boss_charge")
	assert_eq(boss._attacks[1].moves[0].id, &"boss_pound")
	assert_eq(boss._attacks[2].kind, &"grab", "the grab slam is P2-grab's hold")
	assert_eq(boss._attacks[2].moves[1].id, &"boss_slam")
	for attack: EnemyAttack in boss._attacks:
		assert_true(attack.heavy, "%s winds up for the heavy floor" % attack.label)
	assert_eq(EnemyCatalog.body_size(&"boss"), Vector2(0.5, 2.3), "the catalog's size")
	assert_true(EnemyCatalog.available().any(func(e: Dictionary) -> bool: return e.id == &"boss"), "offered by F4")
	assert_eq(boss.rig.height, 2.3, "the rig is scaled by its height, never its node")
	assert_eq(boss.rig.scale, Vector3.ONE)


func test_the_deep_voice_is_the_scenes_data_as_the_bruisers_is_and_not_a_number_in_the_script() -> void:
	# CLAUDE.md: feel numbers are never script constants. The pitch lives in boss.tscn.
	var bare := Boss.new()
	assert_almost_eq(bare.voice_pitch_mult, 1.0, 0.0001, "the script sets none")
	bare.free()
	var boss := BOSS_SCENE.instantiate() as Boss
	assert_almost_eq(boss.voice_pitch_mult, 0.7, 0.0001, "the scene's 0.7")
	boss.free()


func test_the_boss_is_charcoal_with_orange_accents_and_not_red() -> void:
	var boss := _boss()
	assert_lt(boss.color.v, 0.25, "charcoal")
	assert_gt(boss.accent.r, 0.8)
	assert_gt(boss.accent.r, boss.accent.g * 1.5, "an orange")
	assert_lt(boss.accent.b, 0.3)
	for c: Color in [boss.color, boss.accent]:
		assert_false(c.r > 0.6 and c.g < 0.2 and c.b < 0.2, "SPEC §10 reserves red")


func test_it_is_never_grabbable() -> void:
	var boss := _boss(1.0)
	await _ticks(2)
	assert_false(boss.can_be_grabbed(), "free")
	boss.force_attack(0)
	await _ticks(3)
	assert_eq(boss.state, CombatTypes.ActorState.WINDUP)
	assert_false(boss.can_be_grabbed(), "winding up")
	boss.abort_move()
	boss._enter_state(CombatTypes.ActorState.STAGGER, 30)
	assert_false(boss.can_be_grabbed(), "staggered: the one state a Bruiser can be grabbed in")
	boss._enter_state(CombatTypes.ActorState.HITSTUN, 30)
	assert_false(boss.can_be_grabbed(), "in hitstun")
	# The player's own LB finds nobody to take, with the boss at arm's length in front of him.
	boss._enter_state(CombatTypes.ActorState.FREE)
	_player.input.push_press(&"GRAB", 2)
	await _ticks(8)
	assert_ne(_player.state, CombatTypes.ActorState.GRABBING, "LB does not take it")
	assert_null(boss.holder)


func test_light_hits_land_their_damage_and_never_interrupt_a_wind_up() -> void:
	var boss := _boss()
	assert_true(await _wind_up(boss, 0))
	var frame := boss.move_frame
	for i in 3:
		var hit := _hit(_player, boss, 6.0)
		assert_true(boss.receive_hit(hit))
		assert_true(hit.armor_absorbed, "absorbed")
		assert_eq(hit.reaction, CombatTypes.Reaction.NONE)
		await _ticks(2)
	assert_eq(boss.health, 300.0 - 18.0, "the damage lands")
	assert_eq(boss.state, CombatTypes.ActorState.WINDUP, "the wind-up goes on")
	assert_gt(boss.move_frame, frame, "and the move runs")
	assert_true(_ended.is_empty(), "no windup_ended: the rear warning keeps going")


func test_a_heavy_hit_staggers_it_out_of_the_grab_wind_up() -> void:
	# Game-boy's rule: a heavy hit gets the player out of the grab's wind-up.
	var boss := _boss(1.3)
	assert_true(await _wind_up(boss, 2), "the grab winds up")
	await _ticks(6)
	var hit := _hit(_player, boss, 10.0, CombatTypes.HitTier.HEAVY, CombatTypes.Reaction.KNOCKDOWN)
	assert_true(boss.receive_hit(hit))
	assert_eq(hit.reaction, CombatTypes.Reaction.STAGGER, "a heavy hit staggers, it does not knock down")
	assert_false(hit.armor_absorbed)
	assert_eq(boss.state, CombatTypes.ActorState.STAGGER)
	assert_null(boss.current_move, "the move is cut")
	assert_eq(_ended.size(), 1, "windup_ended once")
	assert_true(_ended[0].interrupted, "interrupted: the warning ends")
	await _ticks(Tuning.data.stagger_frames + 4)
	assert_ne(_player.state, CombatTypes.ActorState.GRABBED, "nobody is held after the cut")


func test_a_heavy_hit_does_not_cut_the_charge_or_the_pound_short() -> void:
	# The charge and the pound are answered by a dodge, a jump, a block or a finisher: a heavy hit
	# (the hook of the third punch) is absorbed like a light one, in the wind-up and in the strike.
	for index: int in 2:
		_ended.clear()
		var boss := _boss(5.0)
		assert_true(await _wind_up(boss, index), "attack %d winds up" % index)
		await _ticks(6)
		var health := boss.health
		var hit := _hit(_player, boss, 8.0, CombatTypes.HitTier.HEAVY, CombatTypes.Reaction.KNOCKDOWN)
		assert_true(boss.receive_hit(hit))
		assert_true(hit.armor_absorbed, "absorbed")
		assert_eq(hit.reaction, CombatTypes.Reaction.NONE)
		assert_eq(boss.health, health - 8.0, "the damage lands")
		assert_eq(boss.state, CombatTypes.ActorState.WINDUP, "the wind-up goes on")
		assert_true(_ended.is_empty(), "no windup_ended")
		assert_true(await _until(func() -> bool: return boss.state == CombatTypes.ActorState.ATTACK, 60))
		var again := _hit(_player, boss, 8.0, CombatTypes.HitTier.HEAVY, CombatTypes.Reaction.KNOCKDOWN)
		assert_true(boss.receive_hit(again))
		assert_true(again.armor_absorbed, "and in the strike")
		assert_eq(boss.state, CombatTypes.ActorState.ATTACK)
		assert_not_null(boss.current_move)
		boss.free()
		await _ticks(2)


func test_a_finisher_cuts_the_charge_short_and_knocks_it_down() -> void:
	var boss := _boss(5.0)
	assert_true(await _wind_up(boss, 0))
	await _ticks(6)
	var hit := _hit(_player, boss, 14.0, CombatTypes.HitTier.FINISHER, CombatTypes.Reaction.LAUNCH)
	assert_true(boss.receive_hit(hit))
	assert_false(hit.armor_absorbed, "the finisher is the answer")
	assert_eq(hit.reaction, CombatTypes.Reaction.LAUNCH)
	assert_null(boss.current_move, "the charge is cut")
	assert_eq(_ended.size(), 1)
	assert_true(_ended[0].interrupted)


func test_a_finisher_knocks_it_down() -> void:
	var boss := _boss()
	await _ticks(2)
	var hit := _hit(_player, boss, 18.0, CombatTypes.HitTier.FINISHER, CombatTypes.Reaction.LAUNCH)
	hit.knockback = Vector3(0.0, 4.0, 5.0)
	assert_true(boss.receive_hit(hit))
	assert_eq(hit.reaction, CombatTypes.Reaction.LAUNCH, "the finisher keeps its reaction")
	assert_false(hit.armor_absorbed)
	await _ticks(3)
	assert_true(boss.is_flying() or boss.is_downed(), "it is on its way down: the punish window")


func test_a_killing_hit_is_never_softened() -> void:
	var boss := _boss()
	await _ticks(2)
	boss.health = 5.0
	var hit := _hit(_player, boss, 6.0)
	assert_true(boss.receive_hit(hit))
	assert_true(hit.killed)
	assert_false(hit.armor_absorbed)
	assert_eq(boss.health, 0.0)
	assert_eq(boss.phase, 1, "a boss killed from above half health never enters phase 2")
	await _ticks(2)
	assert_eq(boss.phase, 1)


# --- Poise ------------------------------------------------------------------------------------


## Only the poise after getting up: no reaction cap.
func _poise_only(seconds: float = 4.0) -> void:
	Tuning.data.boss_poise_s = seconds
	Tuning.data.boss_poise_after_reactions = 0


## Only the reaction cap: no poise after getting up.
func _cap_only(reactions: int = 2, window_s: float = 8.0) -> void:
	Tuning.data.boss_poise_s = 0.0
	Tuning.data.boss_poise_after_reactions = reactions
	Tuning.data.boss_poise_window_s = window_s


## A heavy hit as the hook is (HEAVY, STAGGER) and a finisher as the uppercut is (FINISHER, LAUNCH), from
## the player, with their damage.
func _hook(boss: Boss) -> HitInfo:
	return _hit(_player, boss, 8.0, CombatTypes.HitTier.HEAVY, CombatTypes.Reaction.STAGGER)


func _uppercut(boss: Boss) -> HitInfo:
	var hit := _hit(_player, boss, 12.0, CombatTypes.HitTier.FINISHER, CombatTypes.Reaction.LAUNCH)
	hit.knockback = Vector3(0.0, 6.0, 3.0)
	return hit


## Stagger `boss` (it has no poise yet) and wait until it is on its feet again, one tick on.
func _staggered_and_up(boss: Boss) -> void:
	assert_true(boss.receive_hit(_hook(boss)))
	assert_eq(boss.state, CombatTypes.ActorState.STAGGER, "the first hook staggers it: it has no poise yet")
	assert_true(await _until(func() -> bool: return boss.state == CombatTypes.ActorState.FREE, 200), "on its feet")
	await _ticks(1)


func test_a_fresh_boss_is_not_poised_and_the_armor_alone_applies() -> void:
	_poise_only()
	var boss := _boss()
	await _ticks(2)
	assert_false(boss.is_poised())
	var hook := _hook(boss)
	assert_true(boss.receive_hit(hook))
	assert_false(hook.armor_absorbed, "a heavy hit staggers it, as the armor says")
	assert_eq(boss.state, CombatTypes.ActorState.STAGGER)


func test_after_a_stagger_it_is_poised_and_a_hook_and_an_uppercut_do_only_their_damage() -> void:
	_poise_only()
	var boss := _boss()
	await _ticks(2)
	assert_true(boss.receive_hit(_hook(boss)))
	assert_false(boss.is_poised(), "not while it is still reeling")
	assert_true(await _until(func() -> bool: return boss.state == CombatTypes.ActorState.FREE, 200))
	await _ticks(1)
	assert_true(boss.is_poised(), "on its feet after a stagger")
	assert_almost_eq(boss.poise_left_s(), Tuning.data.boss_poise_s, 0.1)
	var health := boss.health
	var hook := _hook(boss)
	assert_true(boss.receive_hit(hook))
	assert_true(hook.armor_absorbed, "the hook is absorbed like a light hit")
	assert_eq(hook.reaction, CombatTypes.Reaction.NONE)
	assert_eq(hook.knockback, Vector3.ZERO)
	var uppercut := _uppercut(boss)
	assert_true(boss.receive_hit(uppercut))
	assert_true(uppercut.armor_absorbed, "and so is the finisher")
	assert_eq(boss.health, health - 20.0, "the damage of both lands")
	await _ticks(3)
	assert_eq(boss.state, CombatTypes.ActorState.FREE, "no reaction: it stands")
	assert_true(boss.is_poised(), "and the hits did not spend the poise")


func test_after_a_knockdown_it_is_poised_once_it_has_got_up() -> void:
	_poise_only()
	var boss := _boss()
	await _ticks(2)
	assert_true(boss.receive_hit(_uppercut(boss)))
	await _ticks(3)
	assert_true(boss.is_flying() or boss.is_downed(), "the first finisher floors it: no poise yet")
	assert_false(boss.is_poised())
	assert_true(await _until(func() -> bool: return boss.state == CombatTypes.ActorState.FREE, 600), "it gets up")
	await _ticks(1)
	assert_true(boss.is_poised(), "poised from the first free tick")
	var hook := _hook(boss)
	assert_true(boss.receive_hit(hook))
	assert_true(hook.armor_absorbed)


func test_the_poise_runs_out_after_boss_poise_s() -> void:
	_poise_only(1.0)
	var boss := _boss()
	await _ticks(2)
	await _staggered_and_up(boss)
	assert_true(boss.is_poised())
	await _ticks(EnemyActor._frames(1.0) + 2)
	assert_false(boss.is_poised(), "a second later it is not")
	var hook := _hook(boss)
	assert_true(boss.receive_hit(hook))
	assert_eq(boss.state, CombatTypes.ActorState.STAGGER, "the hook staggers it again")


func test_the_poise_ends_when_its_next_attack_is_over() -> void:
	_poise_only(10.0)
	var boss := _boss(3.0)
	await _ticks(2)
	await _staggered_and_up(boss)
	assert_true(await _wind_up(boss, 1), "the pound winds up")
	assert_true(boss.is_poised(), "poised through the wind-up")
	var hook := _hook(boss)
	assert_true(boss.receive_hit(hook))
	assert_true(hook.armor_absorbed, "the hook does not cut it")
	assert_true(await _until(func() -> bool: return boss.ai_state == EnemyActor.AiState.RECOVER, 200), "the attack is over")
	assert_false(boss.is_poised(), "and so is the poise, with seconds to spare")
	assert_true(boss.receive_hit(_hook(boss)))
	assert_eq(boss.state, CombatTypes.ActorState.STAGGER)


func test_boss_poise_attacks_zero_leaves_the_time_alone_to_end_it() -> void:
	_poise_only(10.0)
	Tuning.data.boss_poise_attacks = 0
	var boss := _boss(3.0)
	await _ticks(2)
	await _staggered_and_up(boss)
	assert_true(await _wind_up(boss, 1))
	assert_true(await _until(func() -> bool: return boss.ai_state == EnemyActor.AiState.RECOVER, 200))
	assert_true(boss.is_poised(), "no attack count: it is poised until the time is up")


func test_the_haymaker_still_knocks_a_poised_boss_down() -> void:
	_poise_only()
	var boss := _boss()
	await _ticks(2)
	await _staggered_and_up(boss)
	assert_true(boss.is_poised())
	var haymaker := _hit(_player, boss, 18.0, CombatTypes.HitTier.FINISHER, CombatTypes.Reaction.LAUNCH)
	haymaker.move = _move(&"haymaker")
	haymaker.knockback = Vector3(0.0, 4.0, 8.0)
	assert_true(boss.receive_hit(haymaker))
	assert_false(haymaker.armor_absorbed, "the haymaker breaks armor, poise included")
	assert_eq(haymaker.reaction, CombatTypes.Reaction.LAUNCH)
	await _ticks(3)
	assert_true(boss.is_flying() or boss.is_downed(), "knocked down: the deliberate punish")


func test_a_heavy_hit_still_cuts_a_poised_boss_out_of_the_grab_and_the_poise_goes_on() -> void:
	_poise_only(10.0)
	var boss := _boss(1.3)
	await _ticks(2)
	await _staggered_and_up(boss)
	assert_true(boss.is_poised())
	assert_true(await _wind_up(boss, 2), "the grab winds up")
	await _ticks(6)
	var hook := _hook(boss)
	assert_true(boss.receive_hit(hook))
	assert_false(hook.armor_absorbed, "Game-boy's rule: a heavy hit gets the player out of the grab")
	assert_eq(boss.state, CombatTypes.ActorState.STAGGER)
	assert_null(boss.current_move, "the grab is cut")
	assert_true(_ended[_ended.size() - 1].interrupted)
	# The uppercut that follows the hook finds it staggering and still poised: absorbed, so no knockdown.
	assert_true(boss.is_poised(), "the cut does not spend the poise")
	var uppercut := _uppercut(boss)
	assert_true(boss.receive_hit(uppercut))
	assert_true(uppercut.armor_absorbed, "the chain's finisher does not floor it")
	assert_eq(boss.state, CombatTypes.ActorState.STAGGER)


func test_a_killing_hit_goes_through_the_poise() -> void:
	_poise_only()
	var boss := _boss()
	await _ticks(2)
	await _staggered_and_up(boss)
	boss.health = 5.0
	var hit := _hook(boss)
	assert_true(boss.receive_hit(hit))
	assert_true(hit.killed)
	assert_false(hit.armor_absorbed, "a killing hit is never softened")
	assert_eq(boss.health, 0.0)


func test_two_reactions_inside_the_window_make_it_poised_without_getting_up() -> void:
	_cap_only(2, 8.0)
	var boss := _boss()
	await _ticks(2)
	assert_true(boss.receive_hit(_hook(boss)), "the first reaction")
	assert_false(boss.is_poised(), "one is not a cap")
	var uppercut := _uppercut(boss)
	assert_true(boss.receive_hit(uppercut), "the second, on the staggering boss")
	assert_false(uppercut.armor_absorbed)
	assert_true(boss.is_poised(), "two inside the window: the cap")
	assert_true(await _until(func() -> bool: return boss.state == CombatTypes.ActorState.FREE, 600), "it gets up")
	assert_true(boss.is_poised(), "still capped on its feet")
	var hook := _hook(boss)
	assert_true(boss.receive_hit(hook))
	assert_true(hook.armor_absorbed, "the next chain cannot floor it")
	assert_eq(boss.state, CombatTypes.ActorState.FREE)


func test_the_cap_lets_go_when_the_oldest_reaction_leaves_the_window() -> void:
	_cap_only(2, 3.0)
	var boss := _boss()
	await _ticks(2)
	boss.receive_hit(_hook(boss))
	boss.receive_hit(_uppercut(boss))
	assert_true(boss.is_poised())
	assert_true(await _until(func() -> bool: return boss.state == CombatTypes.ActorState.FREE, 600))
	await _ticks(EnemyActor._frames(3.0) + 2)
	assert_false(boss.is_poised(), "three seconds after the first reaction")
	assert_true(boss.receive_hit(_hook(boss)))
	assert_eq(boss.state, CombatTypes.ActorState.STAGGER, "a hook staggers it again")


func test_a_parry_recoil_does_not_give_it_poise() -> void:
	_poise_only()
	var boss := _boss()
	assert_true(await _wind_up(boss, 0))
	var hit := HitInfo.new()
	hit.move = _move(&"boss_charge")
	hit.attacker = boss
	hit.victim = _player
	hit.blocked = true
	hit.perfect_block = true
	boss.react_to_block(hit)
	assert_eq(boss.state, CombatTypes.ActorState.HITSTUN)
	assert_true(await _until(func() -> bool: return boss.state == CombatTypes.ActorState.FREE, 200))
	await _ticks(1)
	assert_false(boss.is_poised(), "the parry's window is the player's reward: a recoil is not a stagger")


func test_with_both_tunables_at_zero_it_is_the_armor_alone_as_before() -> void:
	Tuning.data.boss_poise_s = 0.0
	Tuning.data.boss_poise_after_reactions = 0
	var boss := _boss()
	await _ticks(2)
	await _staggered_and_up(boss)
	assert_false(boss.is_poised())
	assert_true(boss.receive_hit(_hook(boss)))
	assert_eq(boss.state, CombatTypes.ActorState.STAGGER, "heavy hits stagger as ever")
	assert_true(boss.receive_hit(_uppercut(boss)))
	await _ticks(3)
	assert_true(boss.is_flying() or boss.is_downed(), "and the finisher floors it")


func test_the_wake_up_hold_lasts_as_long_as_the_poise_so_it_does_not_walk_back_to_its_slot() -> void:
	Tuning.data.ai_frozen = false
	Tuning.data.posture_taunt_chance = 0.0
	_poise_only(4.0)
	var boss := _boss(1.4)
	_director.put_slot(boss, Vector3(0.0, 0.0, 6.5))
	await _ticks(6)
	boss._cooldown_frames = 100000
	boss.receive_hit(_hook(boss))
	await _until(func() -> bool: return boss.state == CombatTypes.ActorState.FREE, 200)
	await _ticks(1)
	assert_eq(boss.ai_state, EnemyActor.AiState.POSTURE, "resumed")
	await _ticks(EnemyActor._frames(Tuning.data.posture_resume_s) + 20)
	assert_eq(boss.ai_state, EnemyActor.AiState.POSTURE, "past the base's hold, still holding its ground while poised")
	await _ticks(EnemyActor._frames(Tuning.data.boss_poise_s) - EnemyActor._frames(Tuning.data.posture_resume_s) + 20)
	assert_eq(boss.ai_state, EnemyActor.AiState.APPROACH, "the poise is over: the slot calls it back")


# --- Stepping back before a wind-up that cannot be read ----------------------------------------


func test_the_pound_and_the_charge_read_from_boss_read_m_and_not_from_the_nose() -> void:
	# The measured data behind boss_read_m (the shared first-person telegraph check, a 2.3 m body): the
	# pound reads from 1.4 m and the charge from 1.2 m, and neither at 1.0 m, where the raised arms are over
	# the lens and the head is out of the view.
	for id: StringName in [&"boss_pound", &"boss_charge"]:
		var at_read := Checks.fp_telegraph_problems(_move(id), 2.3, Tuning.data.boss_read_m, self)
		assert_true(at_read.is_empty(), "%s reads from boss_read_m (%.1f m)%s" % [id, Tuning.data.boss_read_m, Checks._list(at_read)])
		var at_nose := Checks.fp_telegraph_problems(_move(id), 2.3, 1.0, self)
		assert_false(at_nose.is_empty(), "%s does not read from 1.0 m: the step back is for that" % id)


## The boss with a token and squared up at `ahead_m` from the player, its next attack the pound, the
## director's go always yes (the stub's): it commits, may step back, then winds up. Returns the boss.
func _engaged(ahead_m: float) -> Boss:
	Tuning.data.ai_frozen = false
	Tuning.data.boss_charge_chance = 0.0
	Tuning.data.boss_grab_chance = 0.0
	Tuning.data.boss_pound_chance = 1.0
	var boss := _boss(ahead_m)
	await _ticks(2)
	_director.give_token(boss)
	return boss


func test_close_up_it_steps_back_to_boss_read_m_before_the_pound_winds_up() -> void:
	var boss := await _engaged(1.0)
	assert_true(await _until(func() -> bool: return boss.state == CombatTypes.ActorState.WINDUP, 120), "it winds up")
	var distance := _flat_dist(boss.global_position, _player.global_position)
	assert_gte(distance, Tuning.data.boss_read_m - 0.1, "from a distance the wind-up reads at (%.2f m)" % distance)
	assert_eq(boss.current_move.id, &"boss_pound")


func test_the_step_back_is_bounded_so_a_player_who_follows_it_is_still_attacked() -> void:
	var boss := await _engaged(1.0)
	var started := -1
	for tick in 200:
		# The player keeps to a metre of it, as a chain's magnetism does.
		_player.global_position.z = boss.global_position.z + 1.0
		await _ticks(1)
		if boss.state == CombatTypes.ActorState.WINDUP:
			started = tick
			break
	assert_gte(started, 0, "it winds up although the player follows")
	var limit := Tuning.data.commit_pause_frames + EnemyActor._frames(Tuning.data.boss_back_off_s) + 30
	assert_lte(started, limit, "after the commit pause and at most boss_back_off_s of stepping back (tick %d)" % started)


func test_boss_read_m_zero_winds_up_where_it_stands() -> void:
	Tuning.data.boss_read_m = 0.0
	var boss := await _engaged(1.0)
	assert_true(await _until(func() -> bool: return boss.state == CombatTypes.ActorState.WINDUP, 120))
	assert_almost_eq(_flat_dist(boss.global_position, _player.global_position), 1.0, 0.1, "no step back")


func test_the_grab_is_thrown_from_where_it_stands_not_after_a_step_back() -> void:
	Tuning.data.ai_frozen = false
	Tuning.data.boss_charge_chance = 0.0
	Tuning.data.boss_pound_chance = 0.0
	Tuning.data.boss_grab_chance = 1.0
	var boss := _boss(1.2)
	await _ticks(2)
	_director.give_token(boss)
	assert_true(await _until(func() -> bool: return boss.state == CombatTypes.ActorState.WINDUP, 120))
	assert_eq(boss.current_move.id, &"boss_grab")
	assert_lt(_flat_dist(boss.global_position, _player.global_position), Tuning.data.boss_read_m, "its own range is 1.3 m")


# --- The attacks in play ----------------------------------------------------------------------


func test_the_pound_hits_a_standing_player_for_15_and_knocks_him_down() -> void:
	var boss := _boss(2.2)
	assert_true(await _wind_up(boss, 1))
	assert_true(await _until(func() -> bool: return not _hits.is_empty(), 80), "the pound lands")
	assert_eq(_hits[0].move.id, &"boss_pound")
	assert_eq(_hits[0].damage, 15.0)
	assert_eq(_hits[0].reaction, CombatTypes.Reaction.KNOCKDOWN)
	assert_eq(_player.health, 85.0)
	assert_gte(boss.move_frame, boss.current_move.startup if boss.current_move else 36, "at its strike frame")
	await _ticks(3)
	assert_true(_player.is_flying() or _player.is_downed(), "knocked down")


func test_the_pound_goes_through_a_raised_guard() -> void:
	var boss := _boss(2.0)
	_player.input.push_down(&"DODGE")
	await _ticks(10)
	assert_true(_player.is_guarding(), "his guard is up")
	assert_true(await _wind_up(boss, 1))
	assert_true(await _until(func() -> bool: return not _hits.is_empty(), 80), "it lands")
	assert_false(_hits[0].blocked, "unblockable")
	assert_eq(_player.health, 85.0, "the whole 15, not a chip")


func test_a_jump_clears_the_pound() -> void:
	var boss := _boss(2.0)
	assert_true(await _wind_up(boss, 1))
	assert_true(await _until(func() -> bool: return boss.move_frame >= 14, 40))
	_player.input.push_press(&"JUMP", 2)
	var strike := boss.current_move.startup
	assert_true(await _until(func() -> bool: return boss.move_frame >= strike, 60))
	var height := _player.global_position.y
	gut.p("the player is %.2f m up at the pound's first active frame" % height)
	assert_gt(height, 0.45, "he is well off the floor when the ring is live")
	assert_true(await _until(func() -> bool: return boss.current_move == null, 120), "the pound runs its course")
	assert_true(_hits.is_empty(), "it hit nobody: his legs were over the ring")
	assert_eq(_player.health, 100.0)


func test_the_pound_misses_a_player_outside_its_ring() -> void:
	var boss := _boss(3.6)
	assert_true(await _wind_up(boss, 1))
	assert_true(await _until(func() -> bool: return boss.current_move == null, 120))
	assert_true(_hits.is_empty(), "the ring is %.1f m and he stands 3.6 m off" % 2.5)


## The boss at the origin facing -Z with the player out of the way (far to the right), so nothing
## stops its charge. Returns its positions on the frames of the move.
func _record_charge(configure: Callable = Callable()) -> Dictionary:
	_player.position = Vector3(14.0, 0.0, 0.0)
	var boss := _boss(0.0, configure)
	boss.rotation.y = 0.0
	await _ticks(2)
	# Aim straight down -Z whatever the tracking does: the player is 14 m to the side.
	Tuning.data.windup_track_share = 0.0
	assert_true(await _wind_up(boss, 0))
	var start := boss.global_position
	var move := boss.current_move
	var at_strike := start
	var at_end := start
	var slid := 0.0
	var lunging := 0
	while boss.current_move != null and boss.move_frame < move.total_frames():
		await _ticks(1)
		if boss.current_move == null:
			break
		if boss.move_frame < move.startup:
			slid = maxf(slid, _flat_dist(boss.global_position, start))
		elif boss.move_frame == move.startup:
			at_strike = boss.global_position
		if boss.move_frame <= move.startup + move.active:
			at_end = boss.global_position
		if boss._lunge_velocity.length() > 0.1:
			lunging += 1
	return {boss = boss, start = start, slid = slid, at_strike = at_strike, at_end = at_end, lunging = lunging, move = move}


func test_the_charge_dashes_four_metres_only_in_its_active_frames() -> void:
	var run := await _record_charge()
	assert_lte(run.slid, SLIDE_TOLERANCE_M, "the wind-up never slides (%.3f m)" % run.slid)
	var dash := _flat_dist(run.at_end, run.at_strike)
	gut.p("the dash covered %.2f m in %d frames" % [dash, run.lunging])
	assert_almost_eq(dash, run.move.free_lunge, 0.25, "the move's 4 m, over the active frames")
	assert_lte(run.lunging, run.move.active + 1, "only in the active frames")
	assert_gte(run.lunging, run.move.active - 2)
	assert_lt(run.at_end.z, run.start.z - 3.5, "along its facing, -Z")


func test_the_charge_stops_at_a_wall() -> void:
	# A wall 2.5 m ahead (its face on the boss's line): the body ends against it, not 4 m on.
	_box(Vector3(0.0, 1.5, -3.0), Vector3(6.0, 3.0, 1.0))
	var run := await _record_charge()
	var travelled := _flat_dist(run.boss.global_position, run.start)
	gut.p("the charge ended %.2f m from where it started, the wall's face is 2.5 m out" % travelled)
	assert_lt(travelled, 2.5 - run.boss.body_radius + 0.15, "stopped by the wall")
	assert_gt(travelled, 1.0, "after charging towards it")


func test_the_charge_knocks_a_standing_player_down_for_20() -> void:
	var boss := _boss(3.0)
	assert_true(await _wind_up(boss, 0))
	assert_true(await _until(func() -> bool: return not _hits.is_empty(), 120), "the charge lands")
	assert_eq(_hits[0].move.id, &"boss_charge")
	assert_eq(_hits[0].damage, 20.0)
	assert_eq(_hits[0].tier, CombatTypes.HitTier.HEAVY)
	assert_eq(_hits[0].reaction, CombatTypes.Reaction.KNOCKDOWN)
	assert_eq(_player.health, 80.0)
	assert_gte(boss.move_frame, boss.current_move.startup, "in its active frames")


func test_a_sidestep_dodges_the_charge() -> void:
	# A cone, not a ring: 1.6 m off its line the shoulder passes him (the boss's tracking stops
	# halfway through its wind-up, so a late sidestep makes it miss).
	var boss := _boss(3.0)
	assert_true(await _wind_up(boss, 0))
	assert_true(await _until(func() -> bool: return boss.move_frame >= boss.current_move.startup * 3 / 4, 60))
	_player.global_position.x += 1.6
	assert_true(await _until(func() -> bool: return boss.current_move == null, 200))
	assert_true(_hits.is_empty(), "it went by")


func test_a_plain_block_does_not_recoil_the_boss_and_the_charge_chips() -> void:
	var boss := _boss(3.0)
	_player.input.push_down(&"DODGE")
	await _ticks(30)  # past the parry window: an ordinary block
	assert_true(await _wind_up(boss, 0))
	assert_true(await _until(func() -> bool: return not _hits.is_empty(), 120), "the charge reaches him")
	assert_true(_hits[0].blocked, "a blocked hit")
	assert_false(_hits[0].perfect_block)
	assert_ne(boss.state, CombatTypes.ActorState.HITSTUN, "no recoil: the boss's moves never have one")
	assert_ne(boss.state, CombatTypes.ActorState.STAGGER)


# --- The parry --------------------------------------------------------------------------------


func test_a_parry_gives_the_boss_a_recoil_not_a_stagger() -> void:
	var boss := _boss()
	assert_true(await _wind_up(boss, 0))
	assert_false(boss._parry_staggers(), "S0's hook: no parry-lock")
	var hit := HitInfo.new()
	hit.move = _move(&"boss_charge")
	hit.attacker = boss
	hit.victim = _player
	hit.blocked = true
	hit.perfect_block = true
	boss.react_to_block(hit)
	assert_eq(boss.state, CombatTypes.ActorState.HITSTUN, "a recoil")
	assert_ne(boss.state, CombatTypes.ActorState.STAGGER)
	assert_eq(boss._state_length, Tuning.data.boss_parry_recoil_frames, "the tunable's length")
	assert_null(boss.current_move, "its move is cut")
	assert_eq(boss.ai_state, EnemyActor.AiState.REACT)
	assert_false(boss.has_token)


func test_an_ordinary_block_or_a_broken_guard_leaves_the_boss_alone() -> void:
	var boss := _boss()
	assert_true(await _wind_up(boss, 0))
	var hit := HitInfo.new()
	hit.move = _move(&"boss_charge")
	hit.blocked = true
	boss.react_to_block(hit)
	assert_eq(boss.state, CombatTypes.ActorState.WINDUP, "an ordinary block: its blocked recoil is 0")
	hit.perfect_block = true
	hit.guard_broken = true
	boss.react_to_block(hit)
	assert_eq(boss.state, CombatTypes.ActorState.WINDUP, "a broken guard is not a parry")


func test_a_real_parry_of_the_charge_opens_a_window() -> void:
	var boss := _boss(3.0)
	assert_true(await _wind_up(boss, 0))
	var strike := boss.current_move.startup
	# The guard goes up just before the arc reaches him: a raise inside the parry window.
	assert_true(await _until(func() -> bool: return boss.move_frame >= strike - 1, 60))
	_player.input.push_down(&"DODGE")
	assert_true(await _until(func() -> bool: return not _hits.is_empty() or boss.current_move == null, 120))
	assert_false(_hits.is_empty(), "the charge reached his guard")
	assert_true(_hits[0].perfect_block, "a parry")
	await _ticks(1)
	assert_eq(boss.state, CombatTypes.ActorState.HITSTUN, "the boss recoils")
	assert_eq(_player.health, 100.0, "and nothing hurt him")
	assert_null(boss.current_move)
	assert_eq(boss._lunge_velocity, Vector3.ZERO, "the dash is stopped dead")


# --- The choice of attack, the warning --------------------------------------------------------


func test_it_picks_by_range_the_charge_only_while_he_is_far_enough() -> void:
	var boss := _boss(Tuning.data.boss_charge_min_m + 0.5)
	await _ticks(2)
	var far: Dictionary = {}
	for i in 90:
		far[boss._choose_attack().label] = true
	assert_true(far.has(&"shoulder charge") and far.has(&"ground pound") and far.has(&"grab and slam"),
			"far enough: the three by their chances")
	boss.global_position.z = -(Tuning.data.boss_charge_min_m - 0.5)
	var near: Dictionary = {}
	for i in 90:
		near[boss._choose_attack().label] = true
	assert_false(near.has(&"shoulder charge"), "up close: no run-up, never the charge")
	assert_true(near.has(&"ground pound") and near.has(&"grab and slam"), "up close: the pound and the grab by their chances")


func test_a_crowd_round_the_player_makes_it_pound() -> void:
	var boss := _boss(2.5)
	await _ticks(2)
	for i in Tuning.data.boss_crowd_count:
		var punk := load("res://game/enemies/punk/street_punk.tscn").instantiate() as EnemyActor
		punk.name = "Punk%d" % (i + 1)
		punk.position = Vector3(1.2 * (i + 1), 0.0, 1.0)
		_scene.add_child(punk)
	await _ticks(2)
	for i in 40:
		assert_eq(boss._choose_attack().label, &"ground pound", "with others close round him: the pound")


func test_the_chances_are_the_weights_and_zero_everywhere_falls_back() -> void:
	var boss := _boss(Tuning.data.boss_charge_min_m - 0.5)
	await _ticks(2)
	Tuning.data.boss_pound_chance = 0.0
	for i in 40:
		assert_eq(boss._choose_attack().label, &"grab and slam", "pound at 0, no run-up: the grab")
	Tuning.data.boss_grab_chance = 0.0
	assert_not_null(boss._choose_attack(), "nothing weighted: the base's pick")
	Tuning.data.boss_pound_chance = 0.3
	Tuning.data.boss_grab_chance = 0.3
	Tuning.data.boss_charge_chance = 0.0
	boss.global_position.z = -(Tuning.data.boss_charge_min_m + 0.5)
	for i in 40:
		assert_ne(boss._choose_attack().label, &"shoulder charge", "charge at 0: never")


func test_the_charges_warning_reaches_as_far_as_the_dash() -> void:
	# A6.2: from behind, a charge warns out to its reach plus the margin, dash included.
	var boss := _boss()
	var charge := _move(&"boss_charge")
	assert_eq(boss.warning_reach_m(charge), charge.reach_m, "no hold: the move's own reach")
	var angle := Tuning.data.rear_warning_angle_deg
	var behind := Tuning.data.rear_warning_behind_deg
	var margin := Tuning.data.rear_warning_range_margin_m
	assert_gt(charge.reach_m, 4.0, "the dash is in it")
	assert_eq(ViewGeometry.warning_corner(180.0, 5.0, charge.reach_m, angle, behind, margin), &"both", "5 m behind")
	assert_eq(ViewGeometry.warning_corner(135.0, charge.reach_m + margin - 0.1, charge.reach_m, angle, behind, margin), &"left")
	assert_eq(ViewGeometry.warning_corner(180.0, charge.reach_m + margin + 0.2, charge.reach_m, angle, behind, margin), &"", "beyond it: nothing")
	assert_eq(ViewGeometry.warning_corner(135.0, 5.0, charge.reach_m - charge.free_lunge, angle, behind, margin), &"", "the arc's reach alone would not")
	var pound := _move(&"boss_pound")
	assert_eq(ViewGeometry.warning_corner(-135.0, 3.4, pound.reach_m, angle, behind, margin), &"right", "the pound warns within its ring and a metre")


# --- Phase 2 ----------------------------------------------------------------------------------


func test_phase_two_comes_at_half_health_exactly_once() -> void:
	var boss := _boss(3.0)
	await _ticks(2)
	watch_signals(CombatEvents)
	boss.health = 151.0
	await _ticks(3)
	assert_eq(boss.phase, 1, "151 of 300 is still phase 1")
	assert_signal_not_emitted(CombatEvents, "boss_phase_changed")
	boss.health = 150.0
	await _ticks(3)
	assert_eq(boss.phase, 2, "150 of 300 is phase 2")
	assert_signal_emit_count(CombatEvents, "boss_phase_changed", 1)
	assert_signal_emitted_with_parameters(CombatEvents, "boss_phase_changed", [boss, 2])
	boss.health = 100.0
	await _ticks(10)
	boss.health = 40.0
	await _until(func() -> bool: return boss.adds.size() >= 2, 200)
	await _ticks(90)
	assert_signal_emit_count(CombatEvents, "boss_phase_changed", 1, "once")
	assert_eq(boss.adds.size(), 2, "and called in only once")


func test_phase_two_follows_the_tunable_at_the_live_value() -> void:
	var boss := _boss(3.0)
	Tuning.data.boss_phase2_at = 0.8
	boss.health = 250.0
	await _ticks(3)
	assert_eq(boss.phase, 1, "80% of 300 is 240: 250 is above it")
	boss.health = 240.0
	await _ticks(3)
	assert_eq(boss.phase, 2, "240 is 80%")


func test_phase_two_turns_the_boss_faster() -> void:
	var boss := _boss(3.0)
	await _ticks(2)
	var rate := Tuning.data.enemy_turn_rate
	var turn := func() -> float:
		boss.rotation.y = 0.0
		boss._face(Vector3.LEFT, rate)
		return absf(boss.rotation.y)
	var before: float = turn.call()
	assert_almost_eq(before, Tuning.data.boss_turn_rate / Engine.physics_ticks_per_second, 0.0001,
			"phase 1: boss_turn_rate where a grunt turns at enemy_turn_rate")
	boss.health = 150.0
	await _ticks(3)
	var after: float = turn.call()
	assert_almost_eq(after / before, Tuning.data.boss_phase2_turn_mult, 0.0001, "phase 2: boss_phase2_turn_mult times faster")
	# The wind-up's tracking turns slowly too, in the same proportion.
	var tracking := deg_to_rad(Tuning.data.windup_track_deg_per_s)
	boss.rotation.y = 0.0
	boss._face(Vector3.LEFT, tracking)
	assert_lt(absf(boss.rotation.y), tracking / Engine.physics_ticks_per_second, "slower than a grunt's tracking even in phase 2 of the boss's")


func test_phase_two_puts_two_punks_on_the_ring_when_there_is_no_spawner() -> void:
	var boss := _boss(3.0)
	await _ticks(2)
	boss.health = 150.0
	assert_true(await _until(func() -> bool: return boss.adds.size() >= Tuning.data.boss_adds_count, 200))
	assert_eq(boss.adds.size(), Tuning.data.boss_adds_count, "boss_adds_count Punks")
	var names := PackedStringArray()
	for add: EnemyActor in boss.adds:
		assert_true(is_instance_valid(add) and add.is_inside_tree())
		assert_eq(add.archetype, &"punk", "Street Punks")
		assert_true(add.is_in_group(&"ai_enemy"), "they count toward alive and take tokens like anyone")
		assert_almost_eq(_flat_dist(add.global_position, boss.global_position), Tuning.data.boss_add_ring_m, 0.2, "boss_add_ring_m round it")
		assert_false(names.has(String(add.name)), "named apart")
		names.append(String(add.name))
	assert_ne(boss.adds[0].global_position, boss.adds[1].global_position)
	assert_eq(get_tree().get_nodes_in_group(&"ai_enemy").size(), 3, "the boss and its two")


func test_the_punks_come_one_at_a_time_the_first_at_once() -> void:
	# A rig takes about 10 ms to build: two in one frame was a 40 ms spawn hitch (the limit is 33).
	var boss := _boss(3.0)
	await _ticks(2)
	boss.health = 150.0
	await _ticks(2)
	assert_eq(boss.adds.size(), 1, "the first at once")
	var interval := EnemyActor._frames(Tuning.data.wave_spawn_interval_s)
	await _ticks(interval - 6)
	assert_eq(boss.adds.size(), 1, "the second waits wave_spawn_interval_s")
	await _ticks(10)
	assert_eq(boss.adds.size(), 2, "and comes")


func test_a_boss_that_dies_calls_no_more_punks() -> void:
	var boss := _boss(3.0)
	await _ticks(2)
	boss.health = 150.0
	await _ticks(2)
	assert_eq(boss.adds.size(), 1)
	boss.health = 0.0
	await _ticks(120)
	assert_eq(boss.adds.size(), 1, "the call-in stops with the boss")


func test_boss_adds_count_is_the_number_of_punks() -> void:
	Tuning.data.boss_adds_count = 4
	var boss := _boss(3.0)
	await _ticks(2)
	boss.health = 100.0
	assert_true(await _until(func() -> bool: return boss.adds.size() >= 4, 400))
	await _ticks(60)
	assert_eq(boss.adds.size(), 4)
	var other := _boss(8.0)
	other.name = "Boss2"
	Tuning.data.boss_adds_count = 0
	await _ticks(2)
	other.health = 100.0
	await _ticks(60)
	assert_eq(other.adds.size(), 0, "none at 0")
	assert_eq(other.phase, 2, "the phase still changes")


func test_phase_two_calls_the_spawner_when_there_is_one() -> void:
	var spawner := EncounterSpawner.new()
	spawner.host = _scene
	var near := Vector3(-8.0, 0.0, -9.0)
	var near_two := Vector3(-3.0, 0.0, -10.0)
	var far := Vector3(18.0, 0.0, 9.0)
	for spot: Vector3 in [far, near, near_two]:
		spawner.spawn_points.append({position = spot, yaw = 0.0, tag = &"doorway", lane_point = spot + Vector3(0.0, 0.0, 2.0)})
	_scene.add_child(spawner)
	var boss := _boss(3.0)
	boss.position = Vector3(-6.0, 0.0, -6.0)
	await _ticks(2)
	boss.health = 150.0
	assert_true(await _until(func() -> bool: return boss.adds.size() >= 2, 200))
	assert_eq(boss.adds.size(), 2)
	var spots: Array[Vector3] = []
	for add: EnemyActor in boss.adds:
		spots.append(add.global_position)
		assert_eq(add.ai_state, EnemyActor.AiState.ENTER, "they walk in from the spawn point")
	assert_true(spots.any(func(p: Vector3) -> bool: return _flat_dist(p, near) < 0.2), "from the nearest free point")
	assert_true(spots.any(func(p: Vector3) -> bool: return _flat_dist(p, near_two) < 0.2), "and the next")
	assert_false(spots.any(func(p: Vector3) -> bool: return _flat_dist(p, far) < 0.2), "not the far one")
	assert_true(spawner._members.size() >= 2, "they join the running wave: it is not cleared while they live")


func test_the_spawner_falls_short_and_the_ring_makes_up_the_rest() -> void:
	var spawner := EncounterSpawner.new()
	spawner.host = _scene
	var only := Vector3(-8.0, 0.0, -9.0)
	spawner.spawn_points.append({position = only, yaw = 0.0, tag = &"doorway", lane_point = only})
	_scene.add_child(spawner)
	var boss := _boss(3.0)
	boss.position = Vector3(-6.0, 0.0, -6.0)
	await _ticks(2)
	boss.health = 150.0
	assert_true(await _until(func() -> bool: return boss.adds.size() >= 2, 200))
	assert_eq(boss.adds.size(), 2, "two, one way or the other")
	assert_true(boss.adds.any(func(a: EnemyActor) -> bool: return _flat_dist(a.global_position, only) < 0.2), "one at the spawn point")
	assert_true(boss.adds.any(func(a: EnemyActor) -> bool:
		return absf(_flat_dist(a.global_position, boss.global_position) - Tuning.data.boss_add_ring_m) < 0.2), "one on the ring")


# --- Phase 2 and the wake-up under a live director (final M3 fix) ------------------------------


## The real director in place of before_each()'s stub, and the AI on.
func _live_ai() -> EnemyDirector:
	_director.queue_free()
	await _ticks(1)
	var director := EnemyDirector.new()
	_scene.add_child(director)
	_director = director
	Tuning.data.ai_frozen = false
	return director


func test_the_call_in_waits_while_a_menu_is_open_and_the_ai_freeze_does_not_hold_it() -> void:
	# A2.2: while F1 or F4 is open the fight holds and waves start no spawns. The boss's call-in is a
	# spawn too; its countdown waited for nothing. (ai_frozen is the Debug panel's own switch and the
	# scripted acts' way of placing an attacker, so it does not hold the call-in.)
	var boss := _boss(3.0)
	await _ticks(2)
	GameInput.menu_open = true
	boss.health = 150.0
	await _ticks(200)
	assert_eq(boss.phase, 2, "the phase itself changes")
	assert_eq(boss.adds.size(), 0, "but nothing is called in while a menu is open")
	GameInput.menu_open = false
	await _ticks(3)
	assert_eq(boss.adds.size(), 1, "the first walks in as the menu closes")
	var interval := EnemyActor._frames(Tuning.data.wave_spawn_interval_s)
	await _ticks(interval + 6)
	assert_eq(boss.adds.size(), 2, "and the second after the interval, as ever")
	# Frozen AI (the Debug checkbox): the countdown runs.
	var other := _boss(8.0)
	other.name = "Boss2"
	Tuning.data.ai_frozen = true
	await _ticks(2)
	other.health = 100.0
	assert_true(await _until(func() -> bool: return other.adds.size() >= 1, 20), "ai_frozen does not hold the call-in")


## Phase 2 from POSTURE with the real director, a spawner whose nearest doorway is at `doorway_x`
## (the sign decides which of the two mirrored two-enemy arrangements the old tie-break picked), the
## beckon played in full and the walk after it kept off the player.
func _phase_two_beckon(doorway_x: float) -> void:
	await _live_ai()
	var spawner := EncounterSpawner.new()
	spawner.host = _scene
	var spot := Vector3(doorway_x, 0.0, -9.0)
	spawner.spawn_points.append({position = spot, yaw = 0.0, tag = &"doorway", lane_point = spot + Vector3(0.0, 0.0, 2.0)})
	_scene.add_child(spawner)
	var boss := _boss(4.0)
	boss._cooldown_frames = 100000  # it postures and asks for nothing: the call-in's moment is the test
	assert_true(await _until(func() -> bool: return boss.ai_state == EnemyActor.AiState.POSTURE and _flat_dist(boss.global_position, boss.posture_slot) < 0.6, 600), "it is posturing on its slot")
	await _ticks(30)
	var seat := boss.posture_slot
	boss.health = 140.0
	await _ticks(1)
	assert_eq(boss.phase, 2)
	var beckon := boss._taunt_frames
	assert_gt(beckon, 30, "the beckon is under way (%d frames)" % beckon)
	var nearest := INF
	for i in beckon - 3:
		await get_tree().physics_frame
		nearest = minf(nearest, _flat_dist(boss.global_position, _player.global_position))
		assert_eq(boss.ai_state, EnemyActor.AiState.POSTURE, "frame %d of the beckon: still posturing" % i)
		if boss.ai_state != EnemyActor.AiState.POSTURE:
			break
	assert_gt(boss._taunt_frames, 0, "the beckon is still playing a few frames before its end")
	assert_eq(boss.rig.current_anim(), &"taunt")
	assert_gte(boss.adds.size(), 1, "the Punks walk in meanwhile")
	# Two more enemies spread the ring thirds (the boss may shift a step, 60 degrees: 3.9 m at 3.9 m out),
	# never to the seat across the player (7.8 m).
	assert_lt(_flat_dist(boss.posture_slot, seat), 5.0, "the call-in did not hand the boss the seat across the player (%s from %s)" % [str(boss.posture_slot), str(seat)])
	for i in 420:
		await get_tree().physics_frame
		nearest = minf(nearest, _flat_dist(boss.global_position, _player.global_position))
	assert_gte(nearest, Tuning.data.posture_ring_min_m - 0.5, "it never came within the ring's near edge of the player, in the beckon or the walk after it (%.2f m)" % nearest)


func test_phase_two_from_posture_plays_the_whole_beckon_and_the_boss_does_not_walk_through_the_player_left() -> void:
	# The call-in's first Punk changes the director's set of enemies; a newcomer that spawns on the
	# boss's side used to hand the lone boss the seat across the player (a 7.6 m walk through him), and
	# _tick_posture() sent it to APPROACH, which zeroes the taunt, one frame after the beckon began.
	await _phase_two_beckon(-2.0)


func test_phase_two_from_posture_plays_the_whole_beckon_and_the_boss_does_not_walk_through_the_player_right() -> void:
	await _phase_two_beckon(2.5)


func test_a_boss_that_gets_up_beside_the_player_postures_there_is_served_first_and_winds_up() -> void:
	# After every stagger or knockdown it walked back to a slot 2.5-4 m away in APPROACH, which never asks
	# for a token, while the next chain landed: the autopilot killed it in 40 s having thrown one attack.
	var director := await _live_ai()
	var boss := _boss(1.4)
	await _ticks(6)
	boss.receive_hit(_hit(_player, boss, 8.0, CombatTypes.HitTier.HEAVY, CombatTypes.Reaction.STAGGER))
	assert_eq(boss.ai_state, EnemyActor.AiState.REACT)
	assert_true(await _until(func() -> bool: return boss.state == CombatTypes.ActorState.FREE, 200), "it is on its feet")
	assert_true(await _until(func() -> bool: return boss.ai_state != EnemyActor.AiState.REACT, 10), "its first free tick")
	assert_true(boss.ai_state in [EnemyActor.AiState.POSTURE, EnemyActor.AiState.ENGAGE], "beside the player it takes up POSTURE where it stands (the director may have served it already), it does not walk back to a slot (%s)" % boss.ai_state_name())
	assert_lt(_flat_dist(boss.global_position, _player.global_position), 3.0, "within the ring's far edge")
	assert_true(await _until(func() -> bool: return director.debug_token_holders().has(boss), 20), "it is given the token at once")
	assert_true(await _until(func() -> bool: return boss.state == CombatTypes.ActorState.WINDUP, 60), "and winds an attack up within a second (%s)" % boss.ai_state_name())
	assert_false(boss.has_token_priority(), "the priority is spent with the token")


func test_a_boss_knocked_far_away_walks_back_to_its_slot_as_anyone_does() -> void:
	var director := await _live_ai()
	var boss := _boss(9.0)
	await _ticks(6)
	boss.receive_hit(_hit(_player, boss, 8.0, CombatTypes.HitTier.HEAVY, CombatTypes.Reaction.STAGGER))
	await _until(func() -> bool: return boss.state == CombatTypes.ActorState.FREE, 200)
	await _ticks(1)
	assert_eq(boss.ai_state, EnemyActor.AiState.APPROACH, "more than the ring's far edge away: it walks in")
	assert_false(boss.has_token_priority())
	assert_not_null(director)


func test_the_wake_up_hold_is_over_after_posture_resume_s_and_the_slot_calls_the_boss_back() -> void:
	# It has no business with the slot it left while it waits for a token it may not have (the attack
	# cooldown is running): after posture_resume_s the leash applies again.
	Tuning.data.ai_frozen = false
	Tuning.data.posture_taunt_chance = 0.0
	Tuning.data.boss_poise_s = 0.0  # the poise lengthens the hold (below): this is the base's
	var boss := _boss(1.4)
	_director.put_slot(boss, Vector3(0.0, 0.0, 6.5))  # across the player and beyond reach
	await _ticks(6)
	boss._cooldown_frames = 100000
	boss.receive_hit(_hit(_player, boss, 8.0, CombatTypes.HitTier.HEAVY, CombatTypes.Reaction.STAGGER))
	await _until(func() -> bool: return boss.state == CombatTypes.ActorState.FREE, 200)
	await _ticks(1)
	assert_eq(boss.ai_state, EnemyActor.AiState.POSTURE, "resumed")
	var hold := EnemyActor._frames(Tuning.data.posture_resume_s)
	await _ticks(hold - 20)
	assert_eq(boss.ai_state, EnemyActor.AiState.POSTURE, "still on the ring before the hold is over, whatever the slot says")
	assert_gte(_flat_dist(boss.global_position, _player.global_position), 1.4 - 0.05, "and not walking in at him")
	await _ticks(40)
	assert_eq(boss.ai_state, EnemyActor.AiState.APPROACH, "then the slot it left calls it back")


# --- The HUD, the view, the lens --------------------------------------------------------------


func test_the_boss_bar_shows_while_it_lives_and_goes_when_it_vanishes() -> void:
	var hud := HUD_SCENE.instantiate() as GameHud
	_scene.add_child(hud)
	hud.advance(0.016)
	assert_false(hud.boss_bar.visible, "no boss, no bar")
	var boss := _boss(3.0)
	await _ticks(2)
	hud.advance(0.016)
	assert_true(hud.boss_bar.visible, "shown for the boss: nobody called the HUD")
	assert_eq(hud.boss_bar.boss, boss)
	var canvas := hud.get_viewport().get_visible_rect().size
	var rect := Rect2(hud.boss_bar.global_position, hud.boss_bar.size)
	assert_gt(rect.position.y, canvas.y * 0.7, "at the bottom")
	assert_almost_eq(rect.get_center().x, canvas.x * 0.5, canvas.x * 0.05, "centred")
	boss.health = 0.0
	hud.advance(0.016)
	assert_true(hud.boss_bar.visible, "a dead boss keeps its empty bar until it vanishes")
	CombatEvents.vanished.emit(boss)
	assert_false(hud.boss_bar.visible, "hidden on vanished")
	hud.advance(0.016)
	assert_false(hud.boss_bar.visible)


func test_the_boss_does_not_fill_the_view_at_the_posture_ring() -> void:
	var cam := FirstPersonCamera.new()
	_scene.add_child(cam)
	cam.player = _player
	for distance: float in [Tuning.data.posture_ring_min_m, Tuning.data.posture_ring_max_m]:
		var boss := _boss(distance)
		await _ticks(3)
		cam.update_camera(FRAME)
		var view := cam.view_transform()
		var cells := FPView.hits(_scene, Transform3D(view.basis, view.origin))
		var covered := FPView.share(cells, func(m: MeshInstance3D) -> bool: return boss.rig.is_ancestor_of(m))
		gut.p("the boss covers %.0f%% of the view at %.1f m" % [covered * 100.0, distance])
		assert_lte(covered, VIEW_SHARE_MAX, "at %.1f m it covers at most half of the view (%.0f%%)" % [distance, covered * 100.0])
		assert_gt(covered, 0.02, "and it is plainly there")
		boss.free()
		await _ticks(2)


## The least distance (m) from the lens to any mesh of `boss` over `ticks` ticks from now.
func _nearest_to_the_lens(boss: Boss, cam: FirstPersonCamera, ticks: int) -> float:
	var nearest := INF
	for i in ticks:
		await _ticks(1)
		cam.update_camera(FRAME)
		var view := cam.view_transform()
		nearest = minf(nearest, FPView.nearest_mesh(_scene, view.origin, func(m: MeshInstance3D) -> bool: return boss.rig.is_ancestor_of(m)))
	return nearest


func test_the_charge_landing_keeps_the_boss_clear_of_the_lens() -> void:
	# A6.3: from a 2.3 m rig, the landed strike (a shoulder that dashed into him) leaves nothing of
	# the boss within arm's length of the lens, through the hit's hitstop.
	var boss := _boss(3.0)
	var cam := FirstPersonCamera.new()
	_scene.add_child(cam)
	cam.player = _player
	assert_true(await _wind_up(boss, 0))
	assert_true(await _until(func() -> bool: return boss.move_frame >= boss.current_move.startup + 1, 60))
	var nearest: float = await _nearest_to_the_lens(boss, cam, 40)
	gut.p("charge: nearest boss mesh %.2f m from the lens (%d hits)" % [nearest, _hits.size()])
	assert_false(_hits.is_empty(), "the charge landed")
	assert_gte(nearest, LENS_CLEARANCE_M, "nothing of the boss within %.2f m of the lens (%.2f)" % [LENS_CLEARANCE_M, nearest])


func test_the_pound_landing_keeps_the_boss_clear_of_the_lens() -> void:
	var boss := _boss(Tuning.data.posture_ring_min_m - 0.3)
	var cam := FirstPersonCamera.new()
	_scene.add_child(cam)
	cam.player = _player
	assert_true(await _wind_up(boss, 1))
	assert_true(await _until(func() -> bool: return boss.move_frame >= boss.current_move.startup - 3, 60))
	var nearest: float = await _nearest_to_the_lens(boss, cam, 40)
	gut.p("pound: nearest boss mesh %.2f m from the lens (%d hits)" % [nearest, _hits.size()])
	assert_false(_hits.is_empty(), "the pound landed")
	assert_gte(nearest, LENS_CLEARANCE_M, "nothing of the boss within %.2f m of the lens (%.2f)" % [LENS_CLEARANCE_M, nearest])


# --- In the crowd room ------------------------------------------------------------------------


func test_the_boss_wave_brings_the_boss_in_the_crowd_room_with_its_bar() -> void:
	var room := (load(ROOM_PATH) as PackedScene).instantiate() as CrowdRoom
	room.with_presentation = true
	room.waves_enabled_on_start = false
	add_child_autofree(room)
	await _ticks(8)  # the navigation map syncs 2 or 3 physics frames after _ready()
	var spawner: EncounterSpawner = room.spawner
	assert_eq(spawner.resolve_id(&"boss"), &"boss", "the boss has a scene now: no Punk in its place")
	assert_eq(spawner.table.wave_at(Tuning.data.boss_wave_every, Tuning.data.boss_wave_every), PackedStringArray(["boss"]))
	var point: Dictionary = spawner.spawn_points[1]
	var boss := spawner.spawn_enemy(&"boss", point.position, point.yaw, true, point.lane_point) as Boss
	assert_not_null(boss)
	assert_eq(boss.name, &"Boss1")
	await _ticks(30)
	var hud: GameHud
	for node: Node in room.get_children():
		if node is GameHud:
			hud = node as GameHud
	assert_not_null(hud)
	assert_true(hud.boss_bar.visible, "the bottom bar follows it")
	assert_eq(hud.boss_bar.boss, boss)
	# Half health in the real room: the adds walk in from the doorways and alleys and join the wave.
	boss.health = boss.max_health * 0.5
	await _ticks(4)
	assert_eq(boss.phase, 2)
	assert_true(await _until(func() -> bool: return boss.adds.size() >= 2, 200))
	assert_eq(boss.adds.size(), 2)
	for add: EnemyActor in boss.adds:
		assert_eq(add.ai_state, EnemyActor.AiState.ENTER, "walking in from a spawn point")
	room.player.input.scripted = true
