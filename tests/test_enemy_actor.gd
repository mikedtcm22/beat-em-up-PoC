extends GutTest
## The enemy base and the Street Punk (Milestone 3, P1-ai): the AI's whole life on a flat floor
## (no navmesh: it steers straight, as in the training room) and in a small code-built arena
## with a wall and a navmesh (it paths round); the wind-up (held, floored, scaled, tracking and
## then locked, no slide), the chain (a link only after a hit that landed), the token on every
## exit path, armor, death and vanishing, the menu hold, ai_frozen and determinism. The
## director here is tests/fixtures/stub_director.gd, so these tests do not depend on the real
## one. Every sim tick is one physics frame (the runner uses --fixed-fps 60).

const PUNK_SCENE := preload("res://game/enemies/punk/street_punk.tscn")
const StubDirector := preload("res://tests/fixtures/stub_director.gd")
const MOVES_DIR := "res://game/combat/moves/"

## Frames to wait after a navmesh joins the map before anything that paths (the map syncs by
## the second or third physics frame).
const NAV_SYNC_TICKS := 6
## The wind-up never slides: the most the body may move during it (m).
const SLIDE_TOLERANCE_M := 0.01
## A long wait for slower things (a walk in, a back-off, a recovery).
const LONG_TICKS := 900


## A stub director that gives the go to one enemy only (the others wait at strike range).
class PickyDirector:
	extends StubDirector
	var only: EnemyActor

	func may_start_windup(enemy: EnemyActor) -> bool:
		windup_asks.append(enemy)
		return enemy == only


## A stub director whose go is due in `eta` seconds (what windup_eta_s() answers; a test counts it
## down) and that says go once it is zero.
class EtaDirector:
	extends StubDirector
	var eta: float = 0.0

	func windup_eta_s(_enemy: EnemyActor) -> float:
		return eta

	func may_start_windup(enemy: EnemyActor) -> bool:
		windup_asks.append(enemy)
		return eta <= 0.0


var _scene: Node3D
var _player: PlayerCharacter
var _director: Object
var _started: Array[Dictionary] = []
var _ended: Array[Dictionary] = []
var _attacks: Array[Dictionary] = []
var _hits: Array[HitInfo] = []


func before_each() -> void:
	_reset_tuning()
	TimeController.clear()
	TimeController.debug_scale = 1.0
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = false
	_started.clear()
	_ended.clear()
	_attacks.clear()
	_hits.clear()
	CombatEvents.windup_started.connect(_on_windup_started)
	CombatEvents.windup_ended.connect(_on_windup_ended)
	CombatEvents.attack_started.connect(_on_attack_started)
	CombatEvents.hit_landed.connect(_on_hit_landed)
	_scene = Node3D.new()
	add_child_autofree(_scene)
	_floor()


func after_each() -> void:
	for pair: Array in [[CombatEvents.windup_started, _on_windup_started], [CombatEvents.windup_ended, _on_windup_ended],
			[CombatEvents.attack_started, _on_attack_started], [CombatEvents.hit_landed, _on_hit_landed]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = true
	_reset_tuning()
	TimeController.clear()


## The shipped defaults and the cheats off (reset_to_default() leaves the cheats as they are).
func _reset_tuning() -> void:
	Tuning.reset_to_default()
	Tuning.data.ai_frozen = false
	Tuning.data.god_mode = false
	Tuning.data.one_hit_ko = false


func _on_windup_started(attacker: Node3D, move: MoveData) -> void:
	_started.append({attacker = attacker, move = move, frame = Engine.get_physics_frames(), at = attacker.global_position})


func _on_windup_ended(attacker: Node3D, interrupted: bool) -> void:
	_ended.append({attacker = attacker, interrupted = interrupted, frame = Engine.get_physics_frames()})


func _on_attack_started(attacker: Node3D, move: MoveData, chain_step: int, timing: StringName) -> void:
	_attacks.append({attacker = attacker, move = move, step = chain_step, timing = timing})


func _on_hit_landed(hit: HitInfo) -> void:
	_hits.append(hit)


# --- Harness ----------------------------------------------------------------------------------


## A wide floor whose top is y = 0 on the world layer.
func _floor() -> void:
	_box(Vector3(0.0, -0.5, 0.0), Vector3(60.0, 1.0, 60.0))


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


## Wait up to `max_ticks` for `condition`; true when it came true.
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


## A Street Punk at `at`, facing `toward` (the player's spot by default).
func _punk(at: Vector3, toward: Vector3 = Vector3.ZERO) -> StreetPunk:
	var punk := PUNK_SCENE.instantiate() as StreetPunk
	punk.name = "Punk1"
	punk.position = at
	punk.rotation.y = atan2(-(toward.x - at.x), -(toward.z - at.z))
	_scene.add_child(punk)
	return punk


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _move(id: StringName) -> MoveData:
	return load("%s%s.tres" % [MOVES_DIR, id]) as MoveData


## A hit on `victim` from `attacker`: `damage`, the tier and the reaction asked.
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


## A Punk with a token (from the stub director), standing 1.2 m in front of the player, ready to
## engage: the wind-up starts a commit pause and a step later.
func _engaging_punk() -> StreetPunk:
	_make_player()
	_make_director()
	var punk := _punk(Vector3(0.0, 0.0, -1.2))
	await _ticks(4)
	_director.give_token(punk)
	return punk


## A navmesh over `_scene`'s static colliders on the world layer (what P1-room's NavBaker does),
## set before the region joins the tree; waits for the map to sync.
func _bake_navmesh() -> void:
	var navmesh := NavigationMesh.new()
	navmesh.cell_size = 0.25
	navmesh.cell_height = 0.1
	navmesh.agent_radius = 0.5
	navmesh.agent_height = 1.8
	navmesh.agent_max_climb = 0.2
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_collision_mask = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navmesh, source, _scene)
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source)
	var region := NavigationRegion3D.new()
	region.navigation_mesh = navmesh
	_scene.add_child(region)
	await _ticks(NAV_SYNC_TICKS)


# --- The Punk's data --------------------------------------------------------------------------


func test_a_punk_is_an_ai_enemy_with_its_health_attacks_and_look() -> void:
	_make_player()
	var punk := _punk(Vector3(0.0, 0.0, -4.0))
	await _ticks(2)
	assert_eq(punk.archetype, &"punk")
	assert_eq(punk.team, 1)
	assert_almost_eq(punk.max_health, Tuning.data.punk_health, 0.001, "30 HP from the tunable")
	for group: StringName in [&"actor", &"enemy", &"ai_enemy"]:
		assert_true(punk.is_in_group(group), "in group %s" % group)
	assert_false(punk.heavy or punk.armor_light, "a grunt: no armor, the light wind-up floor")
	assert_eq(punk._attacks.size(), 2, "the two-hit punch and the shove")
	assert_eq(punk._attacks[0].moves.size(), 2, "jab then cross")
	assert_eq(punk._attacks[1].moves.size(), 1, "the shove")
	assert_gt(punk.attack_range_m(), 0.9, "it knows its reach")
	assert_ne(punk.color, Color(0.86, 0.5, 0.16), "not the training dummy's orange")


func test_the_punks_health_follows_its_tunable_keeping_the_share_left() -> void:
	_make_player()
	var punk := _punk(Vector3(0.0, 0.0, -4.0))
	await _ticks(2)
	punk.health = punk.max_health * 0.5
	Tuning.set_value(&"punk_health", 60.0)
	assert_almost_eq(punk.max_health, 60.0, 0.001)
	assert_almost_eq(punk.health, 30.0, 0.001, "half left stays half")


# --- Walking in and posturing -----------------------------------------------------------------


func test_it_walks_in_postures_and_keeps_to_the_ring_on_a_flat_floor() -> void:
	_make_player()
	# The stub director grants nothing unless told (the real one would hand out tokens).
	_make_director()
	var punk := _punk(Vector3(0.0, 0.0, -14.0))
	punk.enter_from(punk.position, Vector3(0.0, 0.0, -10.0))
	var seen: Array[int] = []
	var came := await _until(func() -> bool:
		if seen.is_empty() or seen[seen.size() - 1] != punk.ai_state:
			seen.append(punk.ai_state)
		return punk.ai_state == EnemyActor.AiState.POSTURE)
	assert_true(came, "it reaches POSTURE")
	assert_eq(seen, [EnemyActor.AiState.ENTER, EnemyActor.AiState.APPROACH, EnemyActor.AiState.POSTURE] as Array[int], "ENTER, APPROACH, POSTURE in order")
	var nearest := INF
	var farthest := 0.0
	var moved := 0.0
	var last := punk.global_position
	for i in 400:
		await get_tree().physics_frame
		var d := _flat_dist(punk.global_position, _player.global_position)
		nearest = minf(nearest, d)
		farthest = maxf(farthest, d)
		moved += _flat_dist(punk.global_position, last)
		last = punk.global_position
	gut.p("posturing: ring %.2f..%.2f m, walked %.1f m in 400 ticks" % [nearest, farthest, moved])
	assert_gte(nearest, Tuning.data.posture_ring_min_m - 0.25, "never closer than the ring")
	assert_lte(farthest, Tuning.data.posture_ring_max_m + Tuning.data.posture_wander_m, "stays out near the ring")
	assert_gt(moved, 1.0, "it circles and strafes, it does not stand like a post")
	assert_true(punk.ai_state in [EnemyActor.AiState.POSTURE, EnemyActor.AiState.APPROACH], "still posturing")


func test_it_paths_round_a_wall_to_the_ring_with_a_navmesh() -> void:
	# A wall between the spawn (north) and the player (south): straight steering would end
	# against it; the nav agent walks round its end.
	_box(Vector3(0.0, 1.5, -3.0), Vector3(10.0, 3.0, 1.0))
	await _bake_navmesh()
	_make_player(Vector3(0.0, 0.0, 3.0))
	var punk := _punk(Vector3(0.0, 0.0, -8.0), Vector3(0.0, 0.0, 3.0))
	await _ticks(2)
	punk.enter_from(punk.position, punk.position)
	var came := await _until(func() -> bool: return punk.ai_state == EnemyActor.AiState.POSTURE)
	assert_true(came, "it gets to its posture spot round the wall")
	var d := _flat_dist(punk.global_position, _player.global_position)
	assert_between(d, Tuning.data.posture_ring_min_m - 0.5, Tuning.data.posture_ring_max_m + 0.5, "on the ring (%.2f m)" % d)
	assert_gt(punk.global_position.z, -2.0, "on the player's side of the wall")


func test_it_goes_to_the_directors_slot() -> void:
	_make_player()
	_make_director()
	var punk := _punk(Vector3(0.0, 0.0, -9.0))
	var slot := Vector3(3.0, 0.0, 1.5)
	_director.put_slot(punk, slot)
	var came := await _until(func() -> bool: return punk.ai_state == EnemyActor.AiState.POSTURE)
	assert_true(came, "it posturess")
	assert_lt(_flat_dist(punk.global_position, slot), Tuning.data.enemy_slot_reach_m + 0.2, "at its slot")


func test_a_posturing_punk_taunts_open_handed_and_is_never_a_threat() -> void:
	Tuning.data.posture_taunt_chance = 1.0
	Tuning.data.posture_pause_s = 0.2
	_make_player()
	var punk := _punk(Vector3(0.0, 0.0, -3.2))
	var taunted := await _until(func() -> bool: return punk.rig.current_anim() == &"taunt", 300)
	assert_true(taunted, "it taunts")
	assert_false(punk.wants_token(), "not while it taunts")
	assert_eq(punk.state, CombatTypes.ActorState.FREE)
	await _ticks(80)
	assert_true(_started.is_empty(), "a taunt starts no wind-up (no warning, no wind-up audio)")
	assert_true(_attacks.is_empty(), "and no attack")


func test_strafing_plays_the_side_step_and_facing_stays_on_the_player() -> void:
	Tuning.data.posture_taunt_chance = 0.0
	_make_player()
	# The stub director grants nothing unless told (the real one would hand out tokens).
	_make_director()
	var punk := _punk(Vector3(0.0, 0.0, -3.2))
	var saw_side_step := false
	var worst_facing := 0.0
	for i in 300:
		await get_tree().physics_frame
		if punk.rig.current_anim() in [&"walk_left", &"walk_right"]:
			saw_side_step = true
		var to_player := (_player.global_position - punk.global_position)
		to_player.y = 0.0
		worst_facing = maxf(worst_facing, rad_to_deg(punk.get_forward().angle_to(to_player.normalized())))
	assert_true(saw_side_step, "a strafe reads as the side-step walk")
	assert_lt(worst_facing, 25.0, "it keeps facing the player while it circles (worst %.0f deg)" % worst_facing)


## A director that takes the stall report (the real one may add the same method; the enemy
## calls it duck-typed).
class ReportingDirector:
	extends "res://tests/fixtures/stub_director.gd"
	var stalled: Array[Node] = []

	func report_stalled(enemy: Node) -> void:
		stalled.append(enemy)


func test_a_stalled_punk_reports_it_and_tries_a_detour() -> void:
	# A wall across its way to the ring (no navmesh: it steers straight into it).
	_box(Vector3(0.0, 1.5, -4.0), Vector3(30.0, 3.0, 1.0))
	_make_player()
	_director = ReportingDirector.new()
	_scene.add_child(_director)
	var punk := _punk(Vector3(0.0, 0.0, -8.0))
	var detoured := await _until(func() -> bool: return punk._detour_frames > 0, 400)
	assert_true(detoured, "after enemy_stuck_s without progress it tries another spot")
	assert_eq(_director.stalled.size() >= 1, true, "and tells the director")
	assert_lt(punk.global_position.z, -4.0, "it is held on its side of the wall")


# --- The way round the ring (final M3 fix, findings crowd-02, fair-04 and tells-05) -----------------


## The yaw error (degrees) between where `enemy` faces and the player.
func _facing_error_deg(enemy: EnemyActor) -> float:
	var to_player := _player.global_position - enemy.global_position
	to_player.y = 0.0
	return rad_to_deg(enemy.get_forward().angle_to(to_player.normalized()))


func test_an_enemy_at_the_players_nose_backs_out_facing_him_instead_of_crossing_him_to_a_slot_behind() -> void:
	# After a reaction beside the player the director's slot is often across him; the straight way
	# there runs through him (the navmesh does not know him), and avoidance only slid the body round
	# his nose at contact distance with the guard up, covering half the lens. Now it backs out to the
	# ring first (an enemy inside the near edge always does), then goes round.
	_make_player()
	_make_director()
	var punk := _punk(Vector3(0.0, 0.0, -1.0))
	_director.put_slot(punk, Vector3(0.0, 0.0, 3.2))
	var start := _flat_dist(punk.global_position, _player.global_position)
	var seen := {nearest = INF, worst_facing = 0.0, ticks = 0}
	var came := await _until(func() -> bool:
		seen.ticks += 1
		seen.nearest = minf(seen.nearest, _flat_dist(punk.global_position, _player.global_position))
		if seen.ticks > 20:
			seen.worst_facing = maxf(seen.worst_facing, _facing_error_deg(punk))
		return punk.ai_state == EnemyActor.AiState.POSTURE and _flat_dist(punk.global_position, punk.posture_slot) < 0.6)
	assert_true(came, "it gets to the slot behind the player (%s)" % punk.ai_state_name())
	assert_gte(seen.nearest, start - 0.1, "it never came nearer to him than where it started (%.2f of %.2f m)" % [seen.nearest, start])
	assert_lt(seen.worst_facing, 40.0, "and it faced him all the way (worst %.0f degrees off)" % seen.worst_facing)


func test_a_slot_across_the_ring_is_reached_round_it_and_not_along_the_chord() -> void:
	_make_player()
	_make_director()
	var punk := _punk(Vector3(0.0, 0.0, -3.0))
	Tuning.data.posture_taunt_chance = 0.0
	_director.put_slot(punk, Vector3(0.0, 0.0, 3.0))
	var seen := {nearest = INF}
	var came := await _until(func() -> bool:
		seen.nearest = minf(seen.nearest, _flat_dist(punk.global_position, _player.global_position))
		return punk.ai_state == EnemyActor.AiState.POSTURE, 900)
	assert_true(came, "it gets there")
	assert_gte(seen.nearest, Tuning.data.posture_ring_min_m - 0.35, "never nearer than the ring's near edge on the way (%.2f m: the chord passes through the player)" % seen.nearest)


func test_the_way_round_is_a_point_on_the_ring_for_a_far_slot_and_a_back_out_for_a_near_one() -> void:
	_make_player()
	var punk := _punk(Vector3(0.0, 0.0, -3.0))
	await _ticks(2)
	Tuning.data.ai_frozen = true
	var lead := Tuning.data.posture_orbit_lead_deg
	var far := punk._orbit_toward(_player, Vector3(0.0, 0.0, 3.0))
	assert_true(far.is_finite(), "a slot across the player is reached by a point on the way")
	assert_almost_eq(_flat_dist(far, _player.global_position), 3.0, 0.05, "on the ring at the radius it walks at")
	assert_almost_eq(absf(rad_to_deg(Vector3(0.0, 0.0, -1.0).signed_angle_to(far - _player.global_position, Vector3.UP))), lead, 0.5, "a lead round")
	var near := punk._orbit_toward(_player, Vector3(3.0 * sin(deg_to_rad(50.0)), 0.0, -3.0 * cos(deg_to_rad(50.0))))
	assert_false(near.is_finite(), "a slot within posture_orbit_gap_deg round is walked to straight")
	punk.global_position = Vector3(0.0, 0.0, -1.0)
	var out := punk._orbit_toward(_player, Vector3(0.0, 0.0, -3.5))
	assert_true(out.is_finite(), "inside the ring's near edge the walk is a back-out even when the slot is straight out")
	assert_gte(_flat_dist(out, _player.global_position), Tuning.data.posture_ring_min_m, "to the ring")
	assert_lt(absf(rad_to_deg(Vector3(0.0, 0.0, -1.0).signed_angle_to(out - _player.global_position, Vector3.UP))), 1.0, "straight out, not through him")
	var side := punk._orbit_toward(_player, Vector3(3.0, 0.0, 0.0))
	assert_true(side.is_finite())
	assert_gte(_flat_dist(side, _player.global_position), Tuning.data.posture_ring_min_m, "a back-out toward a slot at his side leaves on a diagonal, never nearer to him")


func test_a_way_round_point_inside_the_car_is_skipped() -> void:
	# The orbit points are checked against the navmesh: one inside a parked car (a bollard here: a box
	# wider than the agent leaves a walkable top the mesh counts) would walk the enemy into its side. A
	# leg whose point is off the mesh gives way to another radius or a shorter leg. Bollards on both
	# legs, because which way round a slot exactly across the player is reached is a coin.
	_make_player()
	var lead := deg_to_rad(Tuning.data.posture_orbit_lead_deg)
	var blocked: Array[Vector3] = [Vector3(0.0, 0.0, -3.0).rotated(Vector3.UP, lead), Vector3(0.0, 0.0, -3.0).rotated(Vector3.UP, -lead)]
	for spot in blocked:
		_box(Vector3(spot.x, 1.0, spot.z), Vector3(0.8, 2.0, 0.8))
	await _bake_navmesh()
	var punk := _punk(Vector3(0.0, 0.0, -3.0))
	await _ticks(4)
	Tuning.data.ai_frozen = true
	await _ticks(2)
	assert_true(punk._navmesh_ready, "the navmesh has synced")
	for spot in blocked:
		assert_false(punk._on_navmesh(spot), "the bollard's spot is off the mesh")
	var step := punk._orbit_toward(_player, Vector3(0.0, 0.0, 3.0))
	assert_true(step.is_finite(), "there is still a way round")
	for spot in blocked:
		assert_gte(_flat_dist(step, spot), 0.9, "but not through a bollard (%s)" % str(step))
	assert_true(punk._on_navmesh(step), "the point is on the mesh")


func test_a_repeated_stall_goes_round_the_player_the_other_way() -> void:
	# The detour's side was a coin toss every time, so a body wedged on one side (the car, a crate) took
	# the same blocked way again and again (an armored Bruiser stood at the nose for 5 s).
	_make_player()
	var punk := _punk(Vector3(0.0, 0.0, -3.0))
	await _ticks(2)
	Tuning.data.ai_frozen = true
	var sides: Array[float] = []
	for i in 4:
		punk._start_detour(_player)
		sides.append(signf(punk._detour.x))
		punk._detour_frames = 0
		await _ticks(5)
	assert_ne(sides[0], 0.0)
	for i in range(1, sides.size()):
		assert_eq(sides[i], -sides[i - 1], "stall %d went the other way from the last" % i)


func test_a_body_that_does_not_move_is_stalled_whatever_its_target_and_the_director_do() -> void:
	# A Bruiser wedged between the crates and the player for 3 s never stalled: the way round the ring
	# and the reslots (set_slot() starts the count over) kept changing its target, so "no nearer to the
	# target" never ran out. A body that has not moved a slot reach in enemy_stuck_s is stalled.
	_make_player()
	var punk := _punk(Vector3(0.0, 0.0, -3.0))
	await _ticks(2)
	Tuning.data.ai_frozen = true
	var frames := EnemyActor._frames(Tuning.data.enemy_stuck_s)
	var stalled_at := -1
	for i in frames + 10:
		var target := Vector3(4.0 if i % 2 == 0 else 0.5, 0.0, -3.0)
		if i % 20 == 19:
			punk.set_slot(Vector3(0.0, 0.0, 3.0 + float(i)))
		if punk._stalled(target):
			stalled_at = i
			break
	assert_between(stalled_at, frames - 2, frames + 1, "it stalls after enemy_stuck_s (%d frames), not never (%d)" % [frames, stalled_at])
	# And a body that is walking is not wedged: it moves a slot reach every few ticks toward its target.
	punk._wedge_anchor = Vector3.INF
	punk._progress_best = INF
	var stalls := 0
	for i in frames * 3:
		punk.global_position.x += 0.05
		if punk._stalled(Vector3(100.0, 0.0, punk.global_position.z)):
			stalls += 1
	assert_eq(stalls, 0, "a body that is walking toward its target never stalls")


func test_a_detour_never_takes_the_side_with_no_navmesh_under_it() -> void:
	# A bollard on one side of the player: the detour spot there is off the mesh, so whatever the
	# enemy's own coin says the detour goes the other way.
	_make_player()
	_box(Vector3(3.0, 1.0, 0.0), Vector3(0.8, 2.0, 0.8))
	await _bake_navmesh()
	Tuning.data.ai_frozen = true
	for label in ["PunkA", "PunkB", "PunkC", "PunkD", "PunkE", "PunkF"]:
		var punk := _punk(Vector3(0.0, 0.0, -3.0))
		punk.name = label
		await _ticks(4)
		assert_true(punk._navmesh_ready)
		punk._start_detour(_player)
		assert_lt(punk._detour.x, 0.0, "%s's detour is on the open side (%s)" % [label, str(punk._detour)])
		punk.queue_free()
		await _ticks(2)


func test_a_taunt_in_progress_finishes_before_a_moved_slot_calls_the_enemy_back() -> void:
	# The boss's beckon was cut one frame after it began: the call-in's first Punk changed the set of
	# enemies, the reslot gave the boss a seat across the player, and _tick_posture() sent it to APPROACH
	# (which zeroes the taunt) before it counted the taunt down.
	Tuning.data.posture_taunt_chance = 0.0
	_make_player()
	_make_director()
	var punk := _punk(Vector3(0.0, 0.0, -3.2))
	_director.put_slot(punk, punk.global_position)
	await _until(func() -> bool: return punk.ai_state == EnemyActor.AiState.POSTURE)
	punk._start_taunt()
	var frames := punk._taunt_frames
	assert_gt(frames, 30, "a taunt of some length")
	_director.put_slot(punk, Vector3(0.0, 0.0, 6.0))
	await _ticks(frames - 3)
	assert_eq(punk.ai_state, EnemyActor.AiState.POSTURE, "still gesturing, not walking, a few frames before it ends")
	assert_eq(punk.rig.current_anim(), &"taunt")
	await _ticks(8)
	assert_eq(punk.ai_state, EnemyActor.AiState.APPROACH, "and then the moved slot calls it back")


func test_only_an_archetype_that_wakes_in_place_resumes_posture_after_a_reaction() -> void:
	# The Punk goes back to its slot (the slice gate settled it); the hook is the boss's.
	_make_player()
	var punk := _punk(Vector3(0.0, 0.0, -1.5))
	await _ticks(4)
	assert_false(punk._wakes_in_place(), "the base and the Punk go back to the slot")
	assert_false(punk.has_token_priority())


# --- The attack: commit, step in, wind-up, strike, recover -------------------------------------


func test_a_token_makes_it_square_up_step_in_and_wind_up_after_the_directors_go() -> void:
	var punk := await _engaging_punk()
	await _ticks(2)
	assert_eq(punk.ai_state, EnemyActor.AiState.ENGAGE, "the token: ENGAGE")
	assert_eq(punk.velocity.length(), 0.0, "squared up, standing")
	var windup := await _until(func() -> bool: return punk.state == CombatTypes.ActorState.WINDUP)
	assert_true(windup, "it winds up")
	assert_eq(_director.windup_asks.size() >= 1, true, "it asked the director's may_start_windup() first")
	var d := _flat_dist(punk.global_position, _player.global_position)
	assert_lte(d, punk.attack_range_m() + 0.01, "inside its reach when the wind-up starts (%.2f m)" % d)
	assert_true(punk.has_token, "the token is held through the attack")


func test_it_waits_for_the_director_before_winding_up() -> void:
	var punk := await _engaging_punk()
	_director.windup_allowed = false
	await _ticks(120)
	assert_ne(punk.state, CombatTypes.ActorState.WINDUP, "held back")
	assert_eq(punk.ai_state, EnemyActor.AiState.ENGAGE)
	_director.windup_allowed = true
	var windup := await _until(func() -> bool: return punk.state == CombatTypes.ActorState.WINDUP, 30)
	assert_true(windup, "then it goes")


func test_the_commit_pause_holds_it_still_before_it_steps_in() -> void:
	# The player is far enough for it to walk: for commit_pause_frames it stands.
	_make_player()
	_make_director()
	var punk := _punk(Vector3(0.0, 0.0, -3.0))
	await _ticks(4)
	var at := punk.global_position
	_director.give_token(punk)
	await _ticks(Tuning.data.commit_pause_frames - 2)
	assert_eq(punk.ai_state, EnemyActor.AiState.ENGAGE)
	assert_lt(_flat_dist(punk.global_position, at), 0.05, "squared up: no steps yet")
	await _ticks(30)
	assert_gt(_flat_dist(punk.global_position, at), 0.3, "then it steps in")


## A Punk 3 m from the player with a token from an EtaDirector whose go is due in `eta` s. Returns
## the Punk; the director is `_director`.
func _waiting_punk(eta: float) -> StreetPunk:
	_make_player()
	var director := EtaDirector.new()
	_director = director
	_scene.add_child(director)
	var punk := _punk(Vector3(0.0, 0.0, -3.0))
	await _ticks(4)
	director.eta = eta
	director.give_token(punk)
	return punk


func test_a_holder_whose_go_is_far_off_stays_squared_up_where_it_is_and_the_wait_is_not_a_failed_chase() -> void:
	# The go is 4 s away: longer than engage_timeout_s. It stands on the ring, facing the player,
	# and keeps its token: waiting is not walking in and not getting there.
	var punk := await _waiting_punk(4.0)
	var at := punk.global_position
	await _ticks(150)
	assert_eq(punk.ai_state, EnemyActor.AiState.ENGAGE, "ENGAGE")
	assert_lt(_flat_dist(punk.global_position, at), 0.05, "it did not step in")
	assert_true(punk.has_token, "and it still holds its token after %.1f s" % (150.0 / 60.0))
	assert_true(_director.released.is_empty(), "nothing gave it back")
	assert_eq(punk.get(&"_engage_frames"), 0, "no frame of it counted as a chase that failed")
	assert_true(_started.is_empty(), "and no wind-up")
	var facing := -punk.get_forward()
	assert_gt(facing.dot(Vector3(at.x, 0.0, at.z).normalized()), 0.95, "squared up: facing the player")


func test_a_holder_steps_in_when_its_go_is_due_within_the_walk_and_arrives_as_it_comes() -> void:
	var walk_s := 0.0
	var punk := await _waiting_punk(2.0)
	var want := punk.attack_range_m() - Tuning.data.engage_margin_m
	walk_s = (3.0 - want) / Tuning.data.engage_speed_mps
	var due: float = walk_s + Tuning.data.engage_go_lead_s
	var started_eta := -1.0
	var wound := -1
	var in_zone := 0
	var still_in_zone := 0
	for i in 300:
		_director.eta = maxf(_director.eta - 1.0 / 60.0, 0.0)
		await get_tree().physics_frame
		if started_eta < 0.0 and int(punk.get(&"_engage_frames")) > 0:
			started_eta = _director.eta
		if wound < 0 and punk.state == CombatTypes.ActorState.WINDUP:
			wound = i
		if wound < 0 and _flat_dist(punk.global_position, _player.global_position) <= 1.3:
			in_zone += 1
			if Vector2(punk.sim_velocity.x, punk.sim_velocity.z).length() < 0.3:
				still_in_zone += 1
	assert_almost_eq(started_eta, due, 0.08, "it started walking when the go was due within the walk (%.2f s) and the lead" % due)
	assert_gte(wound, 0, "it wound up")
	assert_lte(still_in_zone, 8, "it did not stand at the player's nose waiting for its go (%d ticks)" % still_in_zone)
	assert_lte(in_zone, 20, "inside 1.3 m for the last stretch of the walk only (%d ticks)" % in_zone)


func test_a_go_that_slips_away_mid_walk_stops_it_where_it_is() -> void:
	# A hit lands on the player while it walks in: the go is a second away again. It stops short of
	# the nose and waits there, instead of walking on to wait at his face.
	var punk := await _waiting_punk(0.0)
	assert_true(await _until(func() -> bool:
			return _flat_dist(punk.global_position, _player.global_position) < 2.0, 120), "it walks in")
	_director.eta = 1.5
	await _ticks(2)
	var at := punk.global_position
	await _ticks(40)
	assert_lt(_flat_dist(punk.global_position, at), 0.1, "stopped where it was")
	assert_gt(_flat_dist(punk.global_position, _player.global_position), 1.3, "short of the nose")
	assert_true(punk.has_token)
	assert_true(_started.is_empty())
	_director.eta = 0.0
	assert_true(await _until(func() -> bool: return punk.state == CombatTypes.ActorState.WINDUP, 120), "the go is open again: it finishes the walk and winds up")


func test_a_lone_punk_exactly_on_the_players_axis_gets_to_strike_range_and_attacks() -> void:
	# The player's avoidance obstacle slows a body whose wish points exactly at its centre to a crawl
	# (a head-on tie: the speed it may keep is the gap over the avoidance horizon, 0.4 m/s at about
	# 1.05 m); it never reached 0.9 m and gave up after engage_timeout_s. A step-in aims a hand's width
	# to one side (engage_aim_offset_m), which breaks the tie.
	Tuning.data.god_mode = true
	await _bake_navmesh()
	_make_player()
	_player.add_child(RoomKit.PlayerObstacle.new())
	_make_director()
	var punk := _punk(Vector3(0.0, 0.0, -4.5))
	_director.put_slot(punk, Vector3(0.0, 0.0, -3.4))
	await _ticks(3)
	_director.give_token(punk)
	assert_true(await _until(func() -> bool: return punk.state == CombatTypes.ActorState.WINDUP, 240), "it reaches its range and winds up")
	assert_true(punk.has_token, "it did not give up the token")
	assert_lte(_flat_dist(punk.global_position, _player.global_position), punk.attack_range_m() + 0.01, "within its reach")


func test_a_step_in_aims_to_one_side_of_the_player_and_each_enemy_keeps_its_side() -> void:
	_make_player()
	_make_director()
	var sides := {}
	for n in 12:
		var punk := PUNK_SCENE.instantiate() as StreetPunk
		punk.name = "Punk%d" % (n + 20)  # named before it enters the tree, as the spawner does
		punk.position = Vector3(0.0, 0.0, -3.0)
		_scene.add_child(punk)
		await _ticks(2)
		var aim: Vector3 = punk.call(&"_engage_aim", _player)
		var off := aim - _player.global_position
		var to_player := _player.global_position - punk.global_position
		assert_almost_eq(Vector2(off.x, off.z).length(), Tuning.data.engage_aim_offset_m, 0.001, "the offset is the tunable")
		assert_almost_eq(off.dot(to_player.normalized()), 0.0, 0.001, "sideways: not nearer or further")
		sides[signf(off.cross(to_player).y)] = true
		assert_eq(punk.call(&"_engage_aim", _player), aim, "the same side every time")
		punk.queue_free()
	assert_eq(sides.size(), 2, "both sides are used, by name")
	Tuning.data.engage_aim_offset_m = 0.0
	var plain := _punk(Vector3(0.0, 0.0, -3.0))
	await _ticks(2)
	assert_eq(plain.call(&"_engage_aim", _player), _player.global_position, "no offset: the player's origin")


func test_the_last_strike_of_an_attack_in_flight_is_counted_through_its_chain() -> void:
	# The two-hit punch's last strike is the cross: the jab's whole length plus the cross's startup
	# from the first frame; the shove has one strike. Idle: none. A whiffed jab ends the chain.
	_make_player(Vector3(0.0, 0.0, 30.0))
	_make_director()
	var punk := _punk(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 30.0))
	await _ticks(4)
	assert_eq(punk.last_strike_eta_s(), 0.0, "nothing under way")
	var jab := _move(&"punk_jab")
	var cross := _move(&"punk_cross")
	punk.force_attack(0)
	await _ticks(2)
	assert_eq(punk.state, CombatTypes.ActorState.WINDUP)
	var chain_frames := jab.total_frames() + cross.startup
	var expected := float(chain_frames - punk.move_frame) / 60.0
	assert_almost_eq(punk.last_strike_eta_s(), expected, 0.02, "the jab's length plus the cross's startup, from here")
	await _ticks(10)
	assert_almost_eq(punk.last_strike_eta_s(), expected - 10.0 / 60.0, 0.02, "and counting down")
	# Nobody there: the jab whiffs and the chain ends with it.
	await _ticks(jab.startup + jab.active)
	assert_eq(punk.last_strike_eta_s(), 0.0, "a whiffed jab has no cross after it")
	assert_true(await _until(func() -> bool: return punk.current_move == null, 90))
	punk.force_attack(1)
	await _ticks(3)
	var shove := _move(&"punk_shove")
	assert_eq(punk.state, CombatTypes.ActorState.WINDUP)
	assert_almost_eq(punk.last_strike_eta_s(), float(shove.startup - punk.move_frame) / 60.0, 0.02, "one strike: the shove's startup")


func test_the_punks_jacket_is_not_red() -> void:
	# SPEC §10 keeps red for blood, the rear warning and the finisher's accents: an enemy is a
	# saturated colour that is not that, so it pops against the muted street and never reads as a
	# warning or a wound.
	var punk := PUNK_SCENE.instantiate() as StreetPunk
	var hue := punk.color.h
	assert_gt(punk.color.s, 0.6, "saturated")
	assert_true(hue > 0.08 and hue < 0.92, "not red or orange-red (hue %.2f)" % hue)
	assert_gt(absf(hue - Color(0.86, 0.5, 0.16).h), 0.15, "and not the training dummy's orange")
	assert_gt(punk.accent.s, 0.6, "the accents are saturated too")
	punk.free()


func test_force_attack_winds_up_for_exactly_the_scaled_floored_startup() -> void:
	_make_player()
	for case: Array in [[1.0, 22], [0.25, 18], [2.0, 44]]:
		Tuning.set_value(&"windup_mult", case[0])
		var punk := _punk(Vector3(0.0, 0.0, -4.0))
		punk.name = "Punk%d" % [absi(hash(case))]
		await _ticks(3)
		_started.clear()
		_ended.clear()
		punk.force_attack(0)
		var came := await _until(func() -> bool: return not _ended.is_empty(), 200)
		assert_true(came, "mult %.2f: the wind-up ends" % case[0])
		if _started.is_empty() or _ended.is_empty():
			continue
		assert_false(_ended[0].interrupted, "it came out, it was not cut short")
		assert_eq(_ended[0].frame - _started[0].frame, case[1], "mult %.2f: %d frames of wind-up" % [case[0], case[1]])
		punk.queue_free()
		await _ticks(2)


func test_a_heavy_is_floored_at_the_heavy_wind_up_and_the_move_copy_is_cached() -> void:
	var jab := _move(&"punk_jab")
	Tuning.set_value(&"windup_mult", 0.5)
	var grunt := EnemyActor.windup_move(jab, false)
	assert_eq(grunt.startup, 18, "a grunt: the floor of 18 (22 x 0.5 = 11)")
	var heavy := EnemyActor.windup_move(jab, true)
	assert_eq(heavy.startup, 30, "a heavy: the floor of 30")
	assert_eq(grunt.id, jab.id, "the copy keeps the move's id (compare by id)")
	assert_same(EnemyActor.windup_move(jab, false), grunt, "cached per id, multiplier and floor")
	assert_eq(jab.startup, 22, "the shared move is untouched")
	Tuning.set_value(&"windup_mult", 1.0)
	assert_same(EnemyActor.windup_move(jab, false), jab, "at 1.0 its own startup stands: the move itself")
	Tuning.set_value(&"windup_mult", 3.0)
	assert_eq(EnemyActor.windup_move(jab, false).startup, 66, "stretched")
	Tuning.set_value(&"windup_min_frames_grunt", 80)
	assert_eq(EnemyActor.windup_move(jab, false).startup, 80, "the floor is a tunable and the cache follows it")


func test_the_windup_does_not_slide_and_the_facing_locks_after_tracking() -> void:
	# It was walking when it was told to attack: the wind-up must not carry that speed. The
	# player jumps to its side early in the wind-up (it turns toward him) and again after the
	# tracking share is over (it has locked its facing: the strike would miss).
	_make_player(Vector3(0.0, 0.0, 0.0))
	var punk := _punk(Vector3(0.0, 0.0, -3.5))
	await _ticks(60)
	punk.force_attack(0)
	assert_true(await _until(func() -> bool: return punk.state == CombatTypes.ActorState.WINDUP, 10), "winding up")
	var start := punk.global_position
	var startup := punk.current_move.startup
	var tracking := roundi(startup * Tuning.data.windup_track_share)
	_player.global_position = start + Vector3(2.0, 0.0, 0.0)
	await _ticks(2)
	var turned := punk.rotation.y
	await _ticks(tracking)
	var locked := punk.rotation.y
	_player.global_position = start + Vector3(-2.0, 0.0, 0.0)
	await _ticks(startup - tracking - 4)
	assert_gt(absf(wrapf(locked - turned, -PI, PI)), deg_to_rad(5.0), "while it tracks it turns toward the player")
	assert_almost_eq(punk.rotation.y, locked, 0.0001, "after the tracking share the facing is locked")
	assert_lt(_flat_dist(punk.global_position, start), SLIDE_TOLERANCE_M, "no slide through the telegraph")
	# The turn is bounded by the tracking rate (from where it faced to where it locked).
	var budget := deg_to_rad(Tuning.data.windup_track_deg_per_s) * (tracking + 4) / 60.0 + 0.01
	assert_lte(absf(wrapf(locked - turned, -PI, PI)), budget, "it turns no faster than windup_track_deg_per_s")


func test_a_step_in_move_travels_over_its_active_frames_and_not_before() -> void:
	# reach_m "includes the move's travel" (free_lunge), so the travel must run while the strike is
	# active: a lunge set on the first active frame moved the body from the second, and a 3 frame
	# strike got two thirds of it (a 0.3 m step-in jab from 1.3 m then landed 0 of 738 wind-ups in
	# the crowd room). Nor may it move anything through the startup.
	_make_player(Vector3(0.0, 0.0, 8.0))
	Tuning.data.ai_frozen = true
	var punk := _punk(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -5.0))
	await _ticks(4)
	var move := _move(&"punk_cross").duplicate() as MoveData
	move.startup = 14
	move.free_lunge = 0.3
	var start := punk.global_position
	punk.start_move(move, 1, &"chain", false)
	var before_strike := 0.0
	var by_the_end := 0.0
	for i in 40:
		await get_tree().physics_frame
		if punk.current_move == null:
			break
		if punk.move_frame == move.startup - 1:
			before_strike = _flat_dist(punk.global_position, start)
		if punk.move_frame == move.startup + move.active - 1:
			by_the_end = _flat_dist(punk.global_position, start)
	assert_lt(before_strike, SLIDE_TOLERANCE_M, "nothing moves through the startup")
	assert_almost_eq(by_the_end, move.free_lunge, 0.03, "the whole step is covered by the last active frame")


func test_the_two_hit_punch_lands_a_jab_then_a_cross_without_a_second_telegraph() -> void:
	Tuning.data.punk_shove_chance = 0.0
	_make_player(Vector3(0.0, 0.0, 0.0))
	Tuning.data.god_mode = true
	var punk := _punk(Vector3(0.0, 0.0, -0.95))
	await _ticks(3)
	punk.force_attack(0)
	var done := await _until(func() -> bool: return _hits.size() >= 2, 200)
	assert_true(done, "the jab and the cross both land")
	assert_eq(_started.size(), 1, "one telegraph for the whole attack")
	assert_eq(_attacks.size(), 2, "two moves")
	assert_eq(_attacks[0].move.id, &"punk_jab")
	assert_eq(_attacks[1].move.id, &"punk_cross")
	assert_eq([_attacks[0].step, _attacks[1].step], [1, 2], "chain steps 1 and 2")
	assert_eq(_attacks[1].timing, &"chain")
	assert_eq(_hits[0].move.id, &"punk_jab", "hit moves keep their ids")
	assert_eq(_hits[1].move.id, &"punk_cross")


func test_a_whiffed_jab_ends_the_attack_there() -> void:
	_make_player(Vector3(0.0, 0.0, 0.0))
	var punk := _punk(Vector3(0.0, 0.0, -3.0))
	await _ticks(3)
	punk.force_attack(0)
	await _until(func() -> bool: return punk.ai_state == EnemyActor.AiState.RECOVER, 200)
	assert_eq(punk.ai_state, EnemyActor.AiState.RECOVER, "the whiff ends in RECOVER")
	assert_eq(_attacks.size(), 1, "no cross after a whiffed opener")
	assert_true(_hits.is_empty())


func test_a_blocked_jab_staggers_nothing_and_the_punk_recoils_without_a_cross() -> void:
	_make_player(Vector3(0.0, 0.0, 0.0))
	_player.input.push_down(&"DODGE")
	while _player.input.queued() > 0:
		await get_tree().physics_frame
	await _ticks(Tuning.data.block_raise_frames + 2)
	var punk := _punk(Vector3(0.0, 0.0, -0.95))
	await _ticks(3)
	punk.force_attack(0)
	var blocked := await _until(func() -> bool: return not _hits.is_empty(), 100)
	assert_true(blocked, "the jab reaches the guard")
	assert_true(_hits[0].blocked, "blocked")
	await _ticks(60)
	assert_eq(_attacks.size(), 1, "a blocked jab recoils: no cross")


func test_recover_gives_the_token_back_and_it_backs_off_to_its_slot() -> void:
	_make_player()
	_make_director()
	var punk := _punk(Vector3(0.0, 0.0, -1.0))
	var slot := Vector3(0.0, 0.0, -3.4)
	_director.put_slot(punk, slot)
	await _ticks(3)
	_director.give_token(punk)
	var recovering := await _until(func() -> bool: return punk.ai_state == EnemyActor.AiState.RECOVER)
	assert_true(recovering, "the attack ends in RECOVER")
	assert_false(punk.has_token, "the token is released when RECOVER starts")
	assert_true(_director.released.has(punk), "the director got it back")
	assert_false(punk.wants_token(), "the cooldown is on")
	var back := await _until(func() -> bool: return punk.ai_state == EnemyActor.AiState.POSTURE)
	assert_true(back, "it backs off to its slot and postures")
	assert_lt(_flat_dist(punk.global_position, slot), 0.8, "out on the ring again (%.2f m from the slot)" % _flat_dist(punk.global_position, slot))


func test_a_punk_that_walked_in_and_attacked_backs_off_the_right_way_at_its_walking_speed() -> void:
	# The avoidance agent keeps its own velocity, and setting the wish does not touch it: a Punk
	# that stepped in at 3 m/s and then stood through the attack and the recover hold started its
	# back-off on that stale velocity and, with neighbours waiting at strike range, went on at up
	# to 6 m/s (the walk is 2.6), toward the player or past his shoulder, instead of stepping back.
	Tuning.data.god_mode = true
	Tuning.data.punk_shove_chance = 0.0
	await _bake_navmesh()
	_make_player()
	_player.add_child(RoomKit.PlayerObstacle.new())
	var director := PickyDirector.new()
	_director = director
	_scene.add_child(director)
	var punk := _punk(Vector3(0.1, 0.0, -4.5))
	director.only = punk
	var slot := Vector3(0.0, 0.0, -3.4)
	director.put_slot(punk, slot)
	var waiting: Array[StreetPunk] = []
	var n := 2
	for degrees: float in [30.0, -30.0, 80.0]:
		var at := Vector3(sin(deg_to_rad(degrees)) * 3.0, 0.0, -cos(deg_to_rad(degrees)) * 3.0)
		var other := _punk(at)
		other.name = "Punk%d" % n
		n += 1
		director.put_slot(other, at)
		waiting.append(other)
	await _ticks(3)
	director.give_token(punk)
	assert_true(await _until(func() -> bool: return punk.ai_state == EnemyActor.AiState.WINDUP), "it walked in and winds up")
	# The others take their tokens now and stand at strike range for a go they never get.
	for other in waiting:
		director.give_token(other)
	assert_true(await _until(func() -> bool: return punk.ai_state == EnemyActor.AiState.RECOVER), "the attack ends in RECOVER")
	assert_true(await _until(func() -> bool: return punk.get(&"_recover_frames") <= 0), "the hold is over")
	var walk_speed: float = Tuning.data.approach_speed_mps
	var toward := -INF
	var fastest := 0.0
	var sweep := 0.0
	var last_angle := atan2(punk.global_position.z, punk.global_position.x)
	var settled := -1
	for i in 240:
		await get_tree().physics_frame
		var velocity := Vector2(punk.sim_velocity.x, punk.sim_velocity.z)
		var to_player := Vector2(-punk.global_position.x, -punk.global_position.z)
		if i < 12:
			toward = maxf(toward, velocity.dot(to_player.normalized()))
		fastest = maxf(fastest, velocity.length())
		var angle := atan2(punk.global_position.z, punk.global_position.x)
		if to_player.length() < 1.2:
			sweep += absf(wrapf(angle - last_angle, -PI, PI))
		last_angle = angle
		if settled < 0 and punk.ai_state == EnemyActor.AiState.POSTURE:
			settled = i
	gut.p("back-off: toward %.2f m/s in the first 12 ticks, fastest %.2f m/s, %.0f deg around the player inside 1.2 m, at its slot after %d ticks" % [toward, fastest, rad_to_deg(sweep), settled])
	assert_lte(toward, 0.1, "its first walking ticks never move toward the player")
	assert_lte(fastest, walk_speed + 0.05, "never faster than its walking speed (a stale avoidance velocity gave 4-6 m/s)")
	assert_lt(rad_to_deg(sweep), 30.0, "it steps back, it does not orbit the player inside 1.2 m")
	assert_gte(settled, 0, "it reaches its slot and postures")


func test_a_latched_answer_against_the_wish_keeps_only_its_sideways_part_and_never_outruns_the_wish() -> void:
	# The avoidance's answer is last tick's: after a squeeze or a stale course it can point the
	# other way, or at 6 m/s. The body takes its sideways part (a zero would freeze a squeezed
	# body at the player's nose) and nothing faster than the wish.
	_make_player()
	_make_director()
	var punk := _punk(Vector3(0.0, 0.0, -4.0))
	await _ticks(3)
	var wish := Vector3(0.0, 0.0, -2.6)
	punk.set(&"_safe_velocity", Vector3(3.0, 0.0, 4.0))
	punk.call(&"_apply_velocity", wish)
	assert_lte(punk.sim_velocity.z, 0.001, "never against the wish")
	assert_almost_eq(Vector2(punk.sim_velocity.x, punk.sim_velocity.z).length(), 2.6, 0.01, "its sideways part, no faster than the wish")
	assert_gt(punk.sim_velocity.x, 0.0, "the sideways part is kept")
	punk.set(&"_safe_velocity", Vector3(0.0, 0.0, -6.0))
	punk.call(&"_apply_velocity", wish)
	assert_almost_eq(punk.sim_velocity.z, -2.6, 0.01, "an answer along the wish is cut to the wish's speed")
	punk.set(&"_safe_velocity", Vector3(1.0, 0.0, -1.0))
	punk.call(&"_apply_velocity", wish)
	assert_almost_eq(punk.sim_velocity.z, -1.0, 0.01, "a slower answer along the wish stands (avoidance slowing it)")


func test_a_stop_clears_the_avoidance_memory_of_the_walk() -> void:
	_make_player()
	_make_director()
	var punk := _punk(Vector3(0.0, 0.0, -4.0))
	await _ticks(3)
	punk.set(&"_safe_velocity", Vector3(2.0, 0.0, 3.0))
	var nav := punk.get(&"_nav") as NavigationAgent3D
	nav.velocity = Vector3(2.0, 0.0, 3.0)
	punk.call(&"_stop")
	assert_eq(punk.get(&"_safe_velocity"), Vector3.ZERO, "the latched answer goes with the stop")
	assert_eq(punk.sim_velocity.x, 0.0)
	assert_eq(nav.velocity, Vector3.ZERO, "and the wish")


func test_the_cooldown_keeps_it_from_asking_for_a_token_until_it_is_over() -> void:
	Tuning.data.punk_attack_cooldown_s = 1.0
	_make_player()
	# The stub director grants nothing unless told (the real one would hand out tokens).
	_make_director()
	var punk := _punk(Vector3(0.0, 0.0, -3.0))
	await _ticks(3)
	punk.force_attack(0)
	await _until(func() -> bool: return punk.ai_state == EnemyActor.AiState.RECOVER, 200)
	var frames := 0
	var posture := await _until(func() -> bool: return punk.ai_state == EnemyActor.AiState.POSTURE)
	assert_true(posture, "it comes back to posture")
	while not punk.wants_token() and frames < 200:
		await get_tree().physics_frame
		frames += 1
	assert_true(punk.wants_token(), "and asks again once the cooldown is over")


func test_it_gives_up_a_chase_it_cannot_win_and_returns_the_token() -> void:
	# The player runs off faster than it can follow: after engage_timeout_s it gives the token back.
	Tuning.data.engage_timeout_s = 0.5
	_make_player(Vector3(0.0, 0.0, 0.0))
	_make_director()
	var punk := _punk(Vector3(0.0, 0.0, -5.0))
	await _ticks(4)
	_director.give_token(punk)
	_player.global_position = Vector3(0.0, 0.0, 30.0)
	await _ticks(200)
	assert_false(punk.has_token, "the token went back")
	assert_true(_director.released.has(punk))
	assert_true(_started.is_empty(), "it never wound up")


# --- The token on every exit path -------------------------------------------------------------


func test_a_light_hit_in_the_windup_interrupts_it_and_releases_the_token() -> void:
	var punk := await _engaging_punk()
	await _until(func() -> bool: return punk.state == CombatTypes.ActorState.WINDUP)
	assert_true(punk.has_token)
	_ended.clear()
	punk.receive_hit(_hit(_player, punk))
	assert_eq(_ended.size(), 1, "the wind-up ended")
	assert_true(_ended[0].interrupted, "interrupted (a light hit)")
	assert_false(punk.has_token, "the token is back")
	assert_true(_director.released.has(punk))
	assert_eq(punk.ai_state, EnemyActor.AiState.REACT)
	await _until(func() -> bool: return punk.state == CombatTypes.ActorState.FREE)
	await _ticks(2)
	assert_eq(punk.ai_state, EnemyActor.AiState.APPROACH, "free again: back to its slot")


func test_a_hit_while_engaging_releases_the_token() -> void:
	var punk := await _engaging_punk()
	await _ticks(3)
	assert_eq(punk.ai_state, EnemyActor.AiState.ENGAGE)
	punk.receive_hit(_hit(_player, punk))
	assert_false(punk.has_token)
	assert_true(_director.released.has(punk))


func test_a_grab_releases_the_token() -> void:
	var punk := await _engaging_punk()
	await _ticks(3)
	punk.start_grabbed(_player)
	await _ticks(3)
	assert_false(punk.has_token, "grabbed: the token is back")
	assert_eq(punk.ai_state, EnemyActor.AiState.REACT)
	assert_eq(punk.state, CombatTypes.ActorState.GRABBED)


func test_a_revoked_token_while_engaging_sends_it_back_to_its_slot() -> void:
	var punk := await _engaging_punk()
	await _ticks(3)
	assert_eq(punk.ai_state, EnemyActor.AiState.ENGAGE)
	punk.revoke_token()
	assert_false(punk.has_token)
	assert_eq(punk.ai_state, EnemyActor.AiState.APPROACH, "the attack is dropped")
	await _ticks(60)
	assert_true(_started.is_empty(), "no wind-up")


func test_the_killing_blow_releases_the_token_at_once_and_ends_the_ai() -> void:
	var punk := await _engaging_punk()
	await _until(func() -> bool: return punk.state == CombatTypes.ActorState.WINDUP)
	punk.receive_hit(_hit(_player, punk, 999.0))
	assert_lte(punk.health, 0.0)
	assert_false(punk.has_token, "released at the killing blow")
	assert_true(_director.released.has(punk))
	assert_eq(punk.ai_state, EnemyActor.AiState.KO)
	assert_false(punk.wants_token(), "a dead body never asks for one")
	await _ticks(10)
	assert_eq(punk.ai_state, EnemyActor.AiState.KO, "flying, health 0: still KO")


func test_a_punk_removed_with_a_token_gives_it_back() -> void:
	var punk := await _engaging_punk()
	await _ticks(3)
	punk.queue_free()
	await _ticks(2)
	assert_eq(_director.released.size(), 1, "freed with a token (F4 removal, room switch): handed back")
	assert_true(_director.holders.is_empty(), "the director holds nothing")


func test_a_blocked_attack_releases_the_token() -> void:
	var punk := await _engaging_punk()
	await _until(func() -> bool: return punk.state == CombatTypes.ActorState.WINDUP)
	punk._on_move_interrupted()
	assert_false(punk.has_token)
	assert_true(_director.released.has(punk))


# --- Armor ------------------------------------------------------------------------------------


func _winding_punk(armored_light: bool, armored_heavy: bool = false, armored_finisher: bool = false) -> StreetPunk:
	_make_player()
	var punk := PUNK_SCENE.instantiate() as StreetPunk
	punk.armor_light = armored_light
	punk.armor_heavy_to_stagger = armored_heavy
	punk.armor_finisher_to_stagger = armored_finisher
	punk.position = Vector3(0.0, 0.0, -4.0)
	_scene.add_child(punk)
	await _ticks(3)
	punk.force_attack(0)
	await _until(func() -> bool: return punk.state == CombatTypes.ActorState.WINDUP, 10)
	_ended.clear()
	return punk


func test_without_armor_a_light_hit_interrupts_a_grunt_wind_up() -> void:
	var punk := await _winding_punk(false)
	punk.receive_hit(_hit(_player, punk))
	assert_eq(_ended.size(), 1)
	assert_true(_ended[0].interrupted)
	assert_ne(punk.state, CombatTypes.ActorState.WINDUP)


func test_light_armor_absorbs_a_light_hit_and_the_wind_up_runs_on() -> void:
	var punk := await _winding_punk(true)
	var before := punk.health
	var hit := _hit(_player, punk, 6.0)
	assert_true(punk.receive_hit(hit))
	assert_true(hit.armor_absorbed, "absorbed")
	assert_eq(hit.reaction, CombatTypes.Reaction.NONE)
	assert_eq(punk.health, before - 6.0, "the damage still lands")
	assert_eq(punk.state, CombatTypes.ActorState.WINDUP, "the wind-up keeps going")
	assert_true(_ended.is_empty(), "no windup_ended: the warning would stay lit")
	var came := await _until(func() -> bool: return not _ended.is_empty(), 60)
	assert_true(came and not _ended[0].interrupted, "it comes out as an attack")


func test_a_heavy_hit_staggers_an_armored_punk_out_of_its_wind_up() -> void:
	var punk := await _winding_punk(true, true, true)
	var hit := _hit(_player, punk, 8.0, CombatTypes.HitTier.HEAVY, CombatTypes.Reaction.FLINCH)
	punk.receive_hit(hit)
	assert_eq(hit.reaction, CombatTypes.Reaction.STAGGER, "heavy staggers")
	assert_eq(punk.state, CombatTypes.ActorState.STAGGER)
	assert_true(_ended[0].interrupted)


func test_a_finisher_staggers_instead_of_launching_and_armor_breakers_pass_through() -> void:
	var punk := await _winding_punk(true, true, true)
	var finisher := _hit(_player, punk, 12.0, CombatTypes.HitTier.FINISHER, CombatTypes.Reaction.LAUNCH)
	punk.receive_hit(finisher)
	assert_eq(finisher.reaction, CombatTypes.Reaction.STAGGER, "a finisher staggers an armored body")
	var breaker := await _winding_punk(true, true, true)
	var haymaker := _hit(_player, breaker, 18.0, CombatTypes.HitTier.FINISHER, CombatTypes.Reaction.LAUNCH)
	haymaker.move = MoveData.new()
	haymaker.move.breaks_armor = true
	breaker.receive_hit(haymaker)
	assert_eq(haymaker.reaction, CombatTypes.Reaction.LAUNCH, "a move that breaks armor is not softened")


func test_armor_never_saves_a_killing_hit() -> void:
	var punk := await _winding_punk(true, true, true)
	punk.health = 3.0
	var hit := _hit(_player, punk, 6.0)
	punk.receive_hit(hit)
	assert_false(hit.armor_absorbed, "killed is killed")
	assert_lte(punk.health, 0.0)


# --- Death and vanishing ----------------------------------------------------------------------


func test_a_dead_punk_leaves_every_group_before_it_is_freed() -> void:
	Tuning.data.ko_linger_s = 0.0
	Tuning.data.ko_blink_s = 0.1
	_make_player()
	var punk := _punk(Vector3(0.0, 0.0, -3.0))
	await _ticks(3)
	# What a scan sees at the moment it leaves the tree.
	var seen := {exiting = false, groups = [], scan = true}
	punk.tree_exiting.connect(func() -> void:
		seen.exiting = true
		for group: StringName in [&"ai_enemy", &"enemy", &"actor", &"boss"]:
			if punk.is_in_group(group):
				seen.groups.append(group)
		seen.scan = get_tree().get_nodes_in_group(&"ai_enemy").has(punk))
	punk.receive_hit(_hit(_player, punk, 999.0))
	for i in 400:
		if seen.exiting:
			break
		await get_tree().physics_frame
	assert_true(seen.exiting, "it blinks off and is freed")
	assert_eq(seen.groups, [], "out of every group by the time it leaves the tree")
	assert_false(seen.scan, "a group scan does not find it")


# --- Frozen, menus, determinism ---------------------------------------------------------------


func test_a_frozen_punk_stands_faces_the_player_asks_for_nothing_and_still_attacks_when_told() -> void:
	Tuning.data.ai_frozen = true
	_make_player(Vector3(0.0, 0.0, 0.0))
	var punk := _punk(Vector3(0.0, 0.0, -3.0), Vector3(5.0, 0.0, -3.0))
	await _ticks(60)
	assert_eq(punk.velocity.length(), 0.0, "standing")
	assert_almost_eq(punk.global_position.z, -3.0, 0.01, "it did not walk")
	assert_false(punk.wants_token(), "it asks for nothing")
	var to_player := _player.global_position - punk.global_position
	to_player.y = 0.0
	assert_lt(rad_to_deg(punk.get_forward().angle_to(to_player.normalized())), 5.0, "it faces the player")
	punk.force_attack(0)
	var came := await _until(func() -> bool: return punk.state == CombatTypes.ActorState.WINDUP, 10)
	assert_true(came, "a scripted act can still make it attack")


func test_an_open_menu_holds_the_fight() -> void:
	_make_player()
	_make_director()
	var punk := _punk(Vector3(0.0, 0.0, -3.0))
	await _ticks(60)
	GameInput.menu_open = true
	assert_false(punk.wants_token(), "no token while a menu is open")
	await _ticks(60)
	var at := punk.global_position
	await _ticks(30)
	assert_lt(_flat_dist(punk.global_position, at), 0.01, "it stands")
	GameInput.menu_open = false
	await _ticks(2)
	await _until(func() -> bool: return punk.wants_token(), 300)


func test_a_menu_does_not_start_a_wind_up_but_one_already_winding_up_finishes() -> void:
	var punk := await _engaging_punk()
	GameInput.menu_open = true
	await _ticks(120)
	assert_true(_started.is_empty(), "no wind-up while the menu is open")
	GameInput.menu_open = false
	var winding := await _until(func() -> bool: return punk.state == CombatTypes.ActorState.WINDUP)
	assert_true(winding, "with the menu closed it winds up")
	GameInput.menu_open = true
	var came := await _until(func() -> bool: return not _ended.is_empty(), 100)
	assert_true(came, "the wind-up under way finishes with the menu open")
	if came:
		assert_false(_ended[0].interrupted, "it came out")


func test_the_debug_text_shows_the_ai_state_the_slot_and_the_token() -> void:
	_make_player()
	_make_director()
	var punk := _punk(Vector3(0.0, 0.0, -3.0))
	await _ticks(10)
	assert_string_contains(punk.debug_state_text(), "AI ")
	_director.put_slot(punk, Vector3(2.0, 0.0, 2.0))
	_director.give_token(punk, true)
	await _ticks(2)
	var text := punk.debug_state_text()
	assert_string_contains(text, "ENGAGE")
	assert_string_contains(text, "TOKEN (blind)")
	assert_string_contains(text, "slot ")
	assert_eq(text.split("\n").size(), 3, "three lines: the name, the state, the AI")


func _positions_hash(ticks: int) -> String:
	var root := Node3D.new()
	_scene.add_child(root)
	var player := PlayerCharacter.new()
	root.add_child(player)
	player.input.scripted = true
	var punks: Array[StreetPunk] = []
	for i in 3:
		var punk := PUNK_SCENE.instantiate() as StreetPunk
		punk.name = "Punk%d" % (i + 1)
		punk.position = Vector3(-6.0 + 6.0 * i, 0.0, -9.0)
		root.add_child(punk)
		punks.append(punk)
	await _ticks(ticks)
	var text := ""
	for punk: StreetPunk in punks:
		text += "%.4f,%.4f,%s;" % [punk.global_position.x, punk.global_position.z, punk.ai_state_name()]
	root.free()
	return text.md5_text()


func test_two_identical_runs_end_at_the_same_positions() -> void:
	# The first run of a process starts the avoidance one tick earlier than later ones (the map's
	# first sync): one warm-up run, then two that must agree.
	await _positions_hash(30)
	var first := await _positions_hash(300)
	var second := await _positions_hash(300)
	assert_eq(first, second, "deterministic: seeded by name, timed in sim frames")
