extends GutTest
## The Kicker (Milestone 3, P2-kicker): its data (25 HP, the fast walk, the circling pace, two
## attacks picked by kicker_sweep_chance), the flank (with a Punk it takes the slot nearest directly
## behind the look and gets there round the ring, never across the player's front), the strafe in
## view toward the edge, the moves in play (the sweep knocks a standing player down for 8 and
## passes over a jumping one; the jump kick lands on a standing player from its engage distance
## and leaps only in its active frames), the rear warning's reach (the leap is in it) and the whole
## thing in the real crowd room with the real HUD: a lone Kicker walks round to the player's back
## and its wind-up lights both corners on the wind-up's first frame. Flat-floor tests have no
## navmesh (the enemy steers straight, as in the training room); every tick is one physics frame.

const KICKER_SCENE := preload("res://game/enemies/kicker/kicker.tscn")
const PUNK_SCENE := preload("res://game/enemies/punk/street_punk.tscn")
const ROOM_PATH := "res://game/level/crowd_room.tscn"
const MOVES_DIR := "res://game/combat/moves/"
## A long wait for slower things (a flank, a recovery).
const LONG_TICKS := 900
## The wind-up never slides: the most the body may move during it (m).
const SLIDE_TOLERANCE_M := 0.01
## Slack on the ring's near edge for a body that steers by a latched velocity (m).
const RING_SLACK_M := 0.35

var _scene: Node3D
var _player: PlayerCharacter
var _director: EnemyDirector
var _hits: Array[HitInfo] = []


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
	CombatEvents.hit_landed.connect(_on_hit_landed)
	_scene = Node3D.new()
	add_child_autofree(_scene)
	_box(Vector3(0.0, -0.5, 0.0), Vector3(60.0, 1.0, 60.0))


func after_each() -> void:
	if CombatEvents.hit_landed.is_connected(_on_hit_landed):
		CombatEvents.hit_landed.disconnect(_on_hit_landed)
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = true
	Tuning.reset_to_default()
	Tuning.data.ai_frozen = false
	Tuning.data.god_mode = false
	TimeController.clear()


func _on_hit_landed(hit: HitInfo) -> void:
	_hits.append(hit)


# --- Harness ----------------------------------------------------------------------------------


func _box(center: Vector3, size: Vector3) -> void:
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


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(condition: Callable, max_ticks: int = LONG_TICKS) -> bool:
	for i in max_ticks:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _make_player() -> PlayerCharacter:
	_player = PlayerCharacter.new()
	_scene.add_child(_player)
	_player.input.scripted = true
	return _player


func _make_director() -> EnemyDirector:
	_director = EnemyDirector.new()
	_scene.add_child(_director)
	return _director


## A Kicker at `at`, facing the player's spot (the origin).
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


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _move(id: StringName) -> MoveData:
	return load("%s%s.tres" % [MOVES_DIR, id]) as MoveData


## `distance` metres from the player (at the origin, looking down -Z) at `bearing_deg` off its
## look (positive left).
func _ahead(distance: float, bearing_deg: float = 0.0) -> Vector3:
	var b := deg_to_rad(bearing_deg)
	return Vector3(-sin(b) * distance, 0.0, -cos(b) * distance)


## The bearing (degrees, positive left) of `point` from the player's look.
func _bearing(point: Vector3) -> float:
	return _player.look_bearing_deg(point)


## A player, a director and a Kicker `distance` metres ahead facing him, the AI frozen so only
## force_attack() makes it do anything.
func _duel(distance: float) -> Kicker:
	_make_player()
	_make_director()
	var kicker := _kicker(_ahead(distance))
	Tuning.data.ai_frozen = true
	await _ticks(10)
	return kicker


# --- The data ----------------------------------------------------------------------------------


func test_the_kicker_is_the_fast_flanker_of_the_catalog() -> void:
	var kicker := _kicker(Vector3(0.0, 0.0, -5.0))
	await _ticks(2)
	assert_eq(kicker.archetype, &"kicker")
	assert_true(kicker.prefers_blind_side, "the director gives it the blind slots first")
	assert_false(kicker.heavy, "a grunt: the grunt floor and the small burst")
	assert_almost_eq(kicker.max_health, Tuning.data.kicker_health, 0.0001, "kicker_health")
	assert_almost_eq(kicker.max_health, 25.0, 0.0001, "SPEC §7: 25 HP")
	for group: StringName in [&"actor", &"enemy", &"ai_enemy"]:
		assert_true(kicker.is_in_group(group), "in group %s" % group)
	assert_gt(kicker._walk_speed(), Tuning.data.approach_speed_mps, "it walks faster than the base pace (kicker_speed_mult)")
	assert_almost_eq(kicker._circle_mult(), 1.0, 0.0001, "not flanking, it circles at the base pace (Milestone 5)")
	kicker.set_flanking(true)
	assert_almost_eq(kicker._circle_mult(), Tuning.data.kicker_circle_mult, 0.0001, "flanking, it circles fast")
	assert_eq(kicker._attacks.size(), 2, "the jump kick and the sweep")
	assert_eq(kicker._attacks[0].moves[0].id, &"kicker_jump_kick")
	assert_eq(kicker._attacks[1].moves[0].id, &"kicker_sweep")
	assert_eq(EnemyCatalog.scene(&"kicker").resource_path, KICKER_SCENE.resource_path, "the catalog finds it")
	assert_gt(kicker.voice_pitch_mult, 1.0, "a higher voice than the grunt's, for the ear to tell it from behind")
	assert_false(kicker._wakes_in_place(), "it goes back to its seat after a reaction, as the Punk does")


func test_the_kickers_colours_are_not_red_and_not_the_punks() -> void:
	var kicker := _kicker(Vector3(0.0, 0.0, -5.0))
	var punk := _punk(Vector3(3.0, 0.0, -5.0))
	assert_lt(kicker.color.r, kicker.color.g, "a jacket that is not red (SPEC §10 reserves red)")
	assert_gt(absf(kicker.color.h - punk.color.h), 0.1, "its hue is not the Punk's")


func test_the_sweep_chance_picks_the_attack() -> void:
	var kicker := _kicker(Vector3(0.0, 0.0, -5.0))
	await _ticks(2)
	Tuning.data.kicker_sweep_chance = 0.0
	for i in 12:
		assert_eq(kicker._choose_attack().label, &"jump kick", "never the sweep at chance 0")
	Tuning.data.kicker_sweep_chance = 1.0
	for i in 12:
		assert_eq(kicker._choose_attack().label, &"sweep", "always the sweep at chance 1")


func test_each_attack_says_how_far_it_reaches_for_the_engage_step() -> void:
	var kicker := _kicker(Vector3(0.0, 0.0, -5.0))
	await _ticks(2)
	Tuning.data.kicker_sweep_chance = 0.0
	kicker._next_attack = kicker._choose_attack()
	assert_almost_eq(kicker.attack_range_m(), _move(&"kicker_jump_kick").reach_m, 0.0001, "the jump kick winds up from its whole leap away")
	Tuning.data.kicker_sweep_chance = 1.0
	kicker._next_attack = kicker._choose_attack()
	assert_almost_eq(kicker.attack_range_m(), _move(&"kicker_sweep").reach_m, 0.0001, "the sweep from close in")


# --- The flank ---------------------------------------------------------------------------------


func test_with_a_punk_and_a_kicker_the_kicker_takes_the_slot_nearest_directly_behind() -> void:
	_make_player()
	_make_director()
	# The Punk is engaged in front, inside the busy radius, so the Kicker flanks (Milestone 5).
	var punk := _punk(_ahead(3.5, 20.0))
	var kicker := _kicker(_ahead(6.0, -25.0))
	await _ticks(90)
	assert_true(kicker.is_flanking(), "the player is busy with the Punk, so it flanks")
	var kicker_slot := _director.debug_slot_of(kicker)
	var punk_slot := _director.debug_slot_of(punk)
	assert_true(kicker_slot.is_finite() and punk_slot.is_finite(), "both have slots")
	assert_gt(absf(_bearing(kicker_slot)), 165.0, "the Kicker's slot is directly behind the look (%.0f degrees)" % _bearing(kicker_slot))
	assert_lt(absf(_bearing(punk_slot)), 30.0, "the Punk gets the opposite slot, ahead (%.0f degrees)" % _bearing(punk_slot))


func test_the_kicker_walks_round_the_ring_to_the_back_and_never_across_the_front() -> void:
	# The walk round is the flank's geometry: M5's always-flank switch, so no Punk is needed to start it.
	Tuning.data.kicker_flank_opportunistic = false
	_make_player()
	_make_director()
	var kicker := _kicker(_ahead(5.0))
	var seen := {closest = INF, left_the_view_at = -1, tick = 0}
	var arrived := await _until(func() -> bool:
		seen.tick += 1
		seen.closest = minf(seen.closest, _flat_dist(kicker.global_position, _player.global_position))
		if seen.left_the_view_at < 0 and _player.is_outside_view(kicker.global_position, Tuning.data.rear_warning_angle_deg):
			seen.left_the_view_at = seen.tick
		return kicker.ai_state == EnemyActor.AiState.POSTURE and absf(_bearing(kicker.global_position)) > 150.0, 1500)
	assert_true(arrived, "it takes up the ring directly behind the player (bearing %.0f, %s)" % [_bearing(kicker.global_position), kicker.ai_state_name()])
	assert_gte(seen.closest, Tuning.data.posture_ring_min_m - RING_SLACK_M,
			"it never came nearer than the ring's near edge: %.2f m (the straight line to a slot behind crosses the player)" % seen.closest)
	assert_gt(seen.left_the_view_at, 0, "it left the view on the way")
	assert_lt(seen.tick, 600, "and the flank is quick: %d ticks" % seen.tick)


func test_a_kicker_that_is_in_view_strafes_toward_the_edge_of_the_view() -> void:
	# While it flanks (an enemy makes its own director, which decides this: M5's always-flank switch).
	Tuning.data.kicker_flank_opportunistic = false
	_make_player()
	for bearing: float in [20.0, -20.0, 40.0, -40.0]:
		var kicker := _kicker(_ahead(3.0, bearing), "KickerB%d" % int(bearing))
		await _ticks(6)  # its director is added a frame late and decides on its first step
		assert_true(kicker.is_flanking(), "flanking")
		var dir := kicker._pick_strafe_dir()
		var away := Vector3(kicker.global_position.x, 0.0, kicker.global_position.z).normalized()
		var tangent := Vector3(-away.z, 0.0, away.x) * dir
		var now := absf(_bearing(kicker.global_position))
		var later := absf(_bearing(kicker.global_position + tangent * 0.5))
		assert_gt(later, now, "%.0f degrees: the strafe takes it toward the edge (%.1f then %.1f)" % [bearing, now, later])
		kicker.queue_free()


func test_the_edge_ward_strafe_wins_over_the_way_to_the_slot_in_view() -> void:
	# The base strafes back toward its slot once it is off it by more than the slot reach; the Kicker in
	# view heads for the nearer edge of the view instead, even where that is away from the slot. (The
	# test above has no slot, so the base's own answer was the same coin and nothing held the override.)
	_make_player()
	Tuning.data.kicker_flank_opportunistic = false
	var kicker := _kicker(_ahead(3.0, 20.0), "KickerEdge")
	var punk := _punk(_ahead(3.0, 20.0), "PunkSlot")
	await _ticks(6)  # its director is added a frame late and decides on its first step
	Tuning.data.ai_frozen = true
	assert_true(kicker.is_flanking(), "flanking (M5's always-flank switch)")
	# The slot is straight ahead: toward it is toward the middle of the view, away from the edge.
	var slot := _ahead(3.0, 0.0)
	kicker.set_slot(slot)
	punk.set_slot(slot)
	var toward_slot := punk._pick_strafe_dir()
	var edge_ward := kicker._pick_strafe_dir()
	assert_ne(edge_ward, toward_slot, "the Kicker does not take the slot-ward way a Punk does")
	var away := Vector3(kicker.global_position.x, 0.0, kicker.global_position.z).normalized()
	var tangent := Vector3(-away.z, 0.0, away.x)
	var now := absf(_bearing(kicker.global_position))
	assert_gt(absf(_bearing(kicker.global_position + tangent * edge_ward * 0.5)), now, "its way takes it toward the edge")
	assert_lt(absf(_bearing(punk.global_position + tangent * toward_slot * 0.5)), now, "the Punk's takes it toward the slot, into the middle")


func test_the_waypoints_on_the_way_round_are_on_the_ring_and_ahead_of_it() -> void:
	_make_player()
	var kicker := _kicker(_ahead(3.0, 10.0))
	await _ticks(2)
	var step := kicker._orbit_toward(_player, _ahead(3.0, 180.0))
	assert_true(step.is_finite(), "a slot across the player is reached round the ring")
	assert_almost_eq(_flat_dist(step, _player.global_position), 3.0, 0.05, "a waypoint at the ring's radius")
	assert_gt(_flat_dist(step, kicker.global_position), 0.5, "ahead of where it stands")
	assert_gt(absf(_bearing(step)), absf(_bearing(kicker.global_position)), "toward the back")
	var near := kicker._orbit_toward(_player, _ahead(3.0, 40.0))
	assert_false(near.is_finite(), "a slot near on the ring is walked to straight")


func test_reaching_a_waypoint_goes_on_round_but_any_other_caller_gets_the_posture() -> void:
	_make_player()
	var kicker := _kicker(_ahead(3.0, 10.0))
	await _ticks(2)
	kicker.ai_state = EnemyActor.AiState.APPROACH
	kicker.set_slot(_ahead(3.0, 180.0))
	var target := kicker._posture_target(_player)
	assert_ne(target, kicker.posture_slot, "the walk is aimed at a point on the way round, not the slot")
	kicker._enter_posture()
	assert_eq(kicker.ai_state, EnemyActor.AiState.APPROACH, "arriving at it is not arriving: the walk goes on")
	await get_tree().physics_frame
	kicker._enter_posture()
	assert_eq(kicker.ai_state, EnemyActor.AiState.POSTURE, "an arrival in another frame (another caller) takes up the posture")


# --- The moves in play -------------------------------------------------------------------------


func test_the_sweep_knocks_a_standing_player_down_for_eight() -> void:
	var kicker := await _duel(1.4)
	kicker.force_attack(1)
	assert_true(await _until(func() -> bool: return not _hits.is_empty(), 90), "the sweep lands on a standing player")
	assert_eq(_hits[0].move.id, &"kicker_sweep")
	assert_eq(_hits[0].reaction, CombatTypes.Reaction.KNOCKDOWN)
	assert_almost_eq(_player.health, _player.max_health - 8.0, 0.0001, "8 damage: a knockdown costs well under 15% of the player's health")
	await _ticks(3)
	assert_true(_player.is_flying() or _player.is_downed(), "he is on his way down")


func test_the_sweep_passes_over_a_jumping_player() -> void:
	var kicker := await _duel(1.4)
	kicker.force_attack(1)
	assert_true(await _until(func() -> bool: return kicker.state == CombatTypes.ActorState.WINDUP, 5), "winding up")
	# Jump inside the wind-up: by the arc's live frames the legs are above its top.
	assert_true(await _until(func() -> bool: return kicker.move_frame >= 11, 30))
	_player.input.push_press(&"JUMP", 2)
	assert_true(await _until(func() -> bool: return kicker.current_move == null, 120), "the sweep ran its course")
	assert_true(_hits.is_empty(), "it hit nobody: the legs were over it")
	assert_almost_eq(_player.health, _player.max_health, 0.0001, "no damage")


func test_the_jump_kick_lands_on_a_standing_player_from_its_engage_distance() -> void:
	var kicker := await _duel(_move(&"kicker_jump_kick").reach_m - Tuning.data.engage_margin_m)
	kicker.force_attack(0)
	assert_true(await _until(func() -> bool: return not _hits.is_empty(), 120), "the jump kick lands from where the engage step stops")
	assert_eq(_hits[0].move.id, &"kicker_jump_kick")
	assert_eq(_hits[0].reaction, CombatTypes.Reaction.FLINCH)
	assert_almost_eq(_player.health, _player.max_health - 8.0, 0.0001, "8 damage")
	assert_eq(_hits[0].region, CombatTypes.Region.TORSO, "a kick to the chest, not the legs or the head")


func test_the_jump_kick_lands_from_the_near_edge_of_the_ring_too() -> void:
	var kicker := await _duel(Tuning.data.posture_ring_min_m)
	kicker.force_attack(0)
	assert_true(await _until(func() -> bool: return not _hits.is_empty(), 120), "the jump kick lands from 2.5 m")
	assert_almost_eq(_player.health, _player.max_health - 8.0, 0.0001, "8 damage")


func test_the_jump_kick_leaps_only_in_its_active_frames() -> void:
	# Aimed past the player (he stands 8 m off to the side), so nothing stops the leap.
	_make_player()
	_player.position = Vector3(8.0, 0.0, 0.0)
	_make_director()
	var kicker := _kicker(Vector3.ZERO)
	kicker.rotation.y = 0.0
	Tuning.data.ai_frozen = true
	await _ticks(10)
	var start := kicker.global_position
	kicker.force_attack(0)
	assert_true(await _until(func() -> bool: return kicker.state == CombatTypes.ActorState.WINDUP, 5))
	var move := kicker.current_move
	var slid := 0.0
	while kicker.state == CombatTypes.ActorState.WINDUP:
		slid = maxf(slid, _flat_dist(kicker.global_position, start))
		await get_tree().physics_frame
	assert_lte(slid, SLIDE_TOLERANCE_M, "nothing slides through the telegraph (%.3f m)" % slid)
	assert_true(await _until(func() -> bool: return kicker.current_move == null, 120))
	assert_almost_eq(_flat_dist(kicker.global_position, start), move.free_lunge, 0.12, "the leap is the move's free_lunge")


func test_the_jump_kicks_reach_keeps_the_warning_alive_from_far_behind() -> void:
	# A5.2: reach_m includes the leap. From 3.4 m behind the player a wind-up warns; with the
	# strike's own reach alone (the leap taken out) it would not (3.4 > 1.2 + 1.0).
	var kick := _move(&"kicker_jump_kick")
	var angle := Tuning.data.rear_warning_angle_deg
	var behind := Tuning.data.rear_warning_behind_deg
	var margin := Tuning.data.rear_warning_range_margin_m
	assert_eq(ViewGeometry.warning_corner(180.0, 3.4, kick.reach_m, angle, behind, margin), &"both", "directly behind at 3.4 m")
	assert_eq(ViewGeometry.warning_corner(135.0, 3.4, kick.reach_m, angle, behind, margin), &"left", "behind left at 3.4 m")
	assert_eq(ViewGeometry.warning_corner(-135.0, 3.4, kick.reach_m, angle, behind, margin), &"right", "behind right at 3.4 m")
	assert_eq(ViewGeometry.warning_corner(180.0, kick.reach_m + margin + 0.2, kick.reach_m, angle, behind, margin), &"", "out of range beyond reach + 1 m")
	assert_eq(ViewGeometry.warning_corner(10.0, 2.6, kick.reach_m, angle, behind, margin), &"", "in view: nothing")
	var without := kick.reach_m - kick.free_lunge
	assert_eq(ViewGeometry.warning_corner(180.0, 3.4, without, angle, behind, margin), &"", "the strike's own reach would not have warned")
	var sweep := _move(&"kicker_sweep")
	assert_eq(ViewGeometry.warning_corner(135.0, 2.2, sweep.reach_m, angle, behind, margin), &"left", "the sweep warns within its reach plus a metre")


# --- In the crowd room, with the HUD -----------------------------------------------------------


func test_a_lone_kicker_flanks_in_the_crowd_room_and_its_wind_up_behind_lights_both_corners() -> void:
	Tuning.set_value(&"waves_enabled", false)
	var room := (load(ROOM_PATH) as PackedScene).instantiate() as CrowdRoom
	room.with_presentation = true
	room.waves_enabled_on_start = false
	add_child_autofree(room)
	await _ticks(8)  # the navigation map syncs 2 or 3 physics frames after _ready()
	var player := room.player
	player.input.scripted = true
	var hud: GameHud
	for node: Node in room.get_children():
		if node is GameHud:
			hud = node as GameHud
	assert_not_null(hud, "the real HUD")
	var warning := hud.rear_warning
	var lit: Array[StringName] = []
	var first := {frame = -1, bearing = 0.0}
	var on_wind_up := func(attacker: Node3D, _move_data: MoveData) -> void:
		if first.frame >= 0 or not attacker is Kicker:
			return
		first.frame = Engine.get_physics_frames()
		first.bearing = player.look_bearing_deg(attacker.global_position)
		for side: StringName in [&"left", &"right"]:
			if warning.corner_state(side).active:
				lit.append(side)
	CombatEvents.windup_started.connect(on_wind_up)
	# A Punk holds the player's attention in front (the Kicker flanks only while he is busy), kept from
	# attacking so the first wind-up is the Kicker's.
	room.spawner.spawn_enemy(&"punk", player.global_position + Vector3(0.0, 0.0, -3.0), 0.0, false, Vector3.INF)
	Tuning.data.god_mode = true
	var point: Dictionary = room.spawner.spawn_points[4]
	var kicker := room.spawner.spawn_enemy(&"kicker", point.position, point.yaw, false, point.lane_point)
	var seen := {closest = INF}
	var arrived := await _until(func() -> bool:
		if kicker.ai_state != EnemyActor.AiState.ENTER:
			seen.closest = minf(seen.closest, _flat_dist(kicker.global_position, player.global_position))
		return first.frame >= 0, 1500)
	CombatEvents.windup_started.disconnect(on_wind_up)
	assert_true(arrived, "the Kicker winds up")
	assert_gt(absf(first.bearing), 150.0, "from directly behind the look (%.0f degrees)" % first.bearing)
	assert_gte(seen.closest, Tuning.data.posture_ring_min_m - RING_SLACK_M, "it never came nearer than the ring on the way: %.2f m" % seen.closest)
	assert_eq(lit, [&"left", &"right"] as Array[StringName], "both corners were lit on the wind-up's first frame")
