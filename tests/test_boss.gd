extends GutTest
## The boss (Milestone 3, P3-boss): its body and armor (light hits absorbed and no interrupt, heavy
## hits stagger it out of any wind-up, the grab's among them, finishers knock it down, it can never
## be grabbed), its attacks in play (the ground pound hits a standing player, goes through a guard
## and misses a jumping one; the charge dashes only in its active frames, knocks a standing player
## down for 20 and stops at a wall; the grab slam is the grab table's, proved in test_enemy_grab.gd
## with the same moves), the attack chosen by range, the rear warning's reach for a charge from
## behind, the parry's recoil, phase 2 (once, at half health: the event, the turn rate, two Punks
## through a spawner and without one), the HUD's boss bar, the view at its posture distance and the
## first-person lens when its strikes land. Flat-floor tests have no navmesh (it steers straight, as
## in the training room); every tick is one physics frame.

const BOSS_SCENE := preload("res://game/enemies/boss/boss.tscn")
const HUD_SCENE := preload("res://game/ui/hud.tscn")
const StubDirector := preload("res://tests/fixtures/stub_director.gd")
const FPView := preload("res://tests/fp_view.gd")
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


func test_a_heavy_hit_staggers_it_out_of_every_wind_up_the_grab_among_them() -> void:
	# Game-boy's rule: a heavy hit gets the player out of the grab's wind-up. The charge's and the
	# pound's are cut the same way.
	for index: int in 3:
		_ended.clear()
		var boss := _boss(2.5)
		assert_true(await _wind_up(boss, index), "attack %d winds up" % index)
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
		boss.free()
		await _ticks(2)


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


func test_it_picks_by_range_the_charge_only_from_afar() -> void:
	var boss := _boss(Tuning.data.boss_charge_min_m + 0.5)
	await _ticks(2)
	for i in 30:
		assert_eq(boss._choose_attack().label, &"shoulder charge", "far: only the charge reaches")
	boss.global_position.z = -(Tuning.data.boss_charge_min_m - 0.5)
	var seen: Dictionary = {}
	for i in 60:
		seen[boss._choose_attack().label] = true
	assert_false(seen.has(&"shoulder charge"), "close: never the charge")
	assert_true(seen.has(&"ground pound") and seen.has(&"grab and slam"), "close: the pound and the grab by their chances")


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
	var boss := _boss(2.5)
	await _ticks(2)
	Tuning.data.boss_pound_chance = 0.0
	for i in 40:
		assert_eq(boss._choose_attack().label, &"grab and slam", "pound at 0: the grab")
	Tuning.data.boss_grab_chance = 0.0
	assert_not_null(boss._choose_attack(), "nothing weighted: the base's pick")


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
	await _ticks(10)
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
	await _ticks(3)
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


func test_boss_adds_count_is_the_number_of_punks() -> void:
	Tuning.data.boss_adds_count = 4
	var boss := _boss(3.0)
	await _ticks(2)
	boss.health = 100.0
	await _ticks(3)
	assert_eq(boss.adds.size(), 4)
	var other := _boss(8.0)
	other.name = "Boss2"
	Tuning.data.boss_adds_count = 0
	await _ticks(2)
	other.health = 100.0
	await _ticks(3)
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
	await _ticks(3)
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
	await _ticks(3)
	assert_eq(boss.adds.size(), 2, "two, one way or the other")
	assert_true(boss.adds.any(func(a: EnemyActor) -> bool: return _flat_dist(a.global_position, only) < 0.2), "one at the spawn point")
	assert_true(boss.adds.any(func(a: EnemyActor) -> bool:
		return absf(_flat_dist(a.global_position, boss.global_position) - Tuning.data.boss_add_ring_m) < 0.2), "one on the ring")


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
	assert_eq(boss.adds.size(), 2)
	for add: EnemyActor in boss.adds:
		assert_eq(add.ai_state, EnemyActor.AiState.ENTER, "walking in from a spawn point")
	room.player.input.scripted = true
