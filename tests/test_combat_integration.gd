extends GutTest
## End-to-end combat in the real test room: a scripted player performs every Spec §4
## combo and move against training dummies; asserts which moves land, in what order,
## for how much, and with what tier. Milestone 1's "done when": every combo can be
## performed and registers hits.

const ROOM := preload("res://game/level/test_room.tscn")
const FPView := preload("res://tests/fp_view.gd")
const FAR := Vector3(30.0, 0.0, -30.0)

var room: Node3D
var player: PlayerCharacter
var dummies: Array[TrainingDummy] = []
var hits: Array[HitInfo] = []
var whiffs: Array[StringName] = []


func before_each() -> void:
	TimeController.clear()
	TimeController.debug_scale = 1.0
	Tuning.apply(TuningData.new())
	Tuning.data.dummy_health = 500.0
	hits.clear()
	whiffs.clear()
	CombatEvents.hit_landed.connect(_on_hit)
	CombatEvents.attack_whiffed.connect(_on_whiff)


func after_each() -> void:
	CombatEvents.hit_landed.disconnect(_on_hit)
	CombatEvents.attack_whiffed.disconnect(_on_whiff)
	TimeController.clear()


func _on_hit(hit: HitInfo) -> void:
	hits.append(hit)


func _on_whiff(_attacker: Node3D, move: MoveData) -> void:
	whiffs.append(move.id)


# --- Harness ------------------------------------------------------------------------


## Build the room; `posts` are dummy positions relative to the player (x right, -z ahead).
## `yaw_deg` overrides the player's facing (default: the room's, down the street).
func _setup(posts: Array[Vector3], presentation: bool = false, yaw_deg: float = NAN) -> void:
	if is_instance_valid(room):
		room.queue_free()
		await _ticks(2)
	room = ROOM.instantiate()
	room.set(&"with_presentation", presentation)
	add_child_autofree(room)
	await _ticks(2)
	player = room.get(&"player")
	player.input.scripted = true
	if not is_nan(yaw_deg):
		player.look_yaw = deg_to_rad(yaw_deg)
		player.rotation.y = player.look_yaw
	dummies.assign(room.get(&"dummies"))
	for i in dummies.size():
		# Posts are in the player's frame (x right, -z ahead), whichever way the room faces it.
		var pos := player.global_position + player.global_basis * posts[i] if i < posts.size() else FAR + Vector3(i * 3.0, 0.0, 0.0)
		var to_player := player.global_position - pos
		dummies[i].set_post(pos, atan2(-to_player.x, -to_player.z), true)
	await _ticks(3)
	hits.clear()
	whiffs.clear()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _press(button: StringName, hold: int = 2, gap: int = 0) -> void:
	player.input.push_press(button, hold)
	player.input.push_wait(gap)
	await _drain()


func _drain() -> void:
	var guard := 0
	while player.input.queued() > 0 and guard < 2000:
		guard += 1
		await get_tree().physics_frame


func _wait_until(condition: Callable, max_ticks: int = 400) -> bool:
	for i in max_ticks:
		if condition.call():
			return true
		await get_tree().physics_frame
	return false


func _wait_idle(max_ticks: int = 600) -> bool:
	return await _wait_until(
		func() -> bool:
			return (
				player.input.queued() == 0
				and player.current_move == null
				and player.state in [CombatTypes.ActorState.FREE, CombatTypes.ActorState.GRABBING]
				and not TimeController.is_in_hitstop(player)
			),
		max_ticks
	)


func _player_hits() -> Array[HitInfo]:
	var out: Array[HitInfo] = []
	for hit in hits:
		if hit.attacker == player and not hit.is_body_impact:
			out.append(hit)
	return out


func _ids(list: Array[HitInfo]) -> Array:
	var out: Array = []
	for hit in list:
		out.append(hit.move.id if hit.move else &"")
	return out


func _damages(list: Array[HitInfo]) -> Array:
	var out: Array = []
	for hit in list:
		out.append(hit.damage)
	return out


func _chain_ready_for_pause(move_id: StringName, frames: int) -> Callable:
	return func() -> bool:
		return (
			player.parser.current != null
			and player.parser.current.id == move_id
			and player.parser.frames_since_recovery >= frames
		)


# --- Combos (Spec §4 table) ---------------------------------------------------------


func test_mash_punch_is_jab_jab_hook_uppercut() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	for i in 4:
		player.input.push_press(&"P", 2)
		player.input.push_wait(7)
	await _drain()
	assert_true(await _wait_idle(), "player returns to idle")
	var landed := _player_hits()
	assert_eq(_ids(landed), [&"jab_1", &"jab_2", &"hook", &"uppercut"])
	assert_eq(_damages(landed), [6.0, 6.0, 8.0, 12.0])
	if landed.size() == 4:
		assert_eq(landed[3].tier, CombatTypes.HitTier.FINISHER, "uppercut is a finisher")
		assert_eq(landed[3].chain_step, 4)
		assert_eq(landed[1].input_timing, &"chain")


## Direction-dependent bugs (a stagger picking back vs. sideways from rounding) once made
## the uppercut miss in only some facings, so the core chains run in several.
func test_chains_land_whichever_way_the_player_faces() -> void:
	for yaw: float in [0.0, -90.0, 45.0, 180.0, 135.0, -30.0]:
		for chain: Array in [[&"P", &"P", &"P", &"P"], [&"K", &"K", &"K"]]:
			await _setup([Vector3(0, 0, -1.6)], false, yaw)
			for button: StringName in chain:
				player.input.push_press(button, 2)
				player.input.push_wait(9)
			await _drain()
			assert_true(await _wait_idle())
			assert_eq(_player_hits().size(), chain.size(), "%s at yaw %.0f: every hit lands (%s)" % [
				"".join(chain), yaw, _ids(_player_hits())])


func test_pause_branch_flurry_ends_in_shove() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	await _press(&"P", 2, 7)
	await _press(&"P", 2)
	assert_true(await _wait_until(_chain_ready_for_pause(&"jab_2", 15)), "waited into the pause window")
	for i in 7:
		player.input.push_press(&"P", 2)
		player.input.push_wait(3)
	await _drain()
	assert_true(await _wait_idle())
	var ids := _ids(_player_hits())
	assert_eq(ids.slice(0, 3), [&"jab_1", &"jab_2", &"body_flurry"])
	assert_gt(ids.count(&"body_flurry"), 2, "mashing repeats the flurry")
	assert_eq(ids.back(), &"shove", "flurry ends in the shove finisher")
	var flurry_hits := _player_hits().filter(func(h: HitInfo) -> bool: return h.move.id == &"body_flurry")
	if not flurry_hits.is_empty():
		assert_eq(flurry_hits[0].input_timing, &"pause")
		assert_eq(flurry_hits[0].damage, 2.0)


func test_mash_kick_is_front_roundhouse_spinning_heel() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	for i in 3:
		player.input.push_press(&"K", 2)
		player.input.push_wait(10)
	await _drain()
	assert_true(await _wait_idle())
	var landed := _player_hits()
	assert_eq(_ids(landed), [&"front_kick", &"roundhouse", &"spinning_heel"])
	assert_eq(_damages(landed), [8.0, 10.0, 14.0])


func test_kick_pause_kick_is_stomp_kick() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	await _press(&"K", 2)
	assert_true(await _wait_until(_chain_ready_for_pause(&"front_kick", 15)))
	await _press(&"K", 2)
	assert_true(await _wait_idle())
	assert_eq(_ids(_player_hits()), [&"front_kick", &"stomp_kick"])
	assert_eq(_damages(_player_hits()), [8.0, 16.0])


func test_punch_punch_kick_is_push_kick() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	await _press(&"P", 2, 7)
	await _press(&"P", 2, 7)
	await _press(&"K", 2)
	assert_true(await _wait_idle())
	assert_eq(_ids(_player_hits()), [&"jab_1", &"jab_2", &"push_kick"])
	assert_eq(_damages(_player_hits()), [6.0, 6.0, 10.0])


func test_hold_punch_releases_haymaker() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	player.input.push_press(&"P", Tuning.data.hold_frames + 8)
	# Held past hold_frames (the jab from the press is over): the cocked fist shows.
	var charged := await _wait_until(func() -> bool:
		return player.parser.held_frames(CombatTypes.IN_PUNCH) > Tuning.data.hold_frames)
	assert_true(charged, "P is still held past hold_frames")
	assert_eq(player.state, CombatTypes.ActorState.FREE)
	assert_eq(player.rig.current_anim(), &"haymaker_charge", "the rig shows the haymaker charge")
	await _drain()
	assert_true(await _wait_idle())
	var ids := _ids(_player_hits())
	assert_has(ids, &"haymaker")
	var haymaker := _player_hits().filter(func(h: HitInfo) -> bool: return h.move.id == &"haymaker")
	if not haymaker.is_empty():
		assert_eq(haymaker[0].damage, 18.0)
		assert_eq(haymaker[0].tier, CombatTypes.HitTier.FINISHER)


func test_waiting_too_long_restarts_the_chain() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	await _press(&"P", 2)
	assert_true(await _wait_idle())
	await _ticks(Tuning.data.pause_max_frames + 6)
	assert_null(player.parser.current, "chain reset after the pause window")
	await _press(&"P", 2)
	assert_true(await _wait_idle())
	assert_eq(_ids(_player_hits()), [&"jab_1", &"jab_1"])


# --- Other moves --------------------------------------------------------------------


func test_flying_kick_lunges_and_hits() -> void:
	await _setup([Vector3(0, 0, -2.4)])
	var start := player.global_position
	await _press(&"JUMP", 2, 2)
	await _press(&"K", 2)
	assert_true(await _wait_idle())
	assert_eq(_ids(_player_hits()), [&"flying_kick"])
	assert_gt(start.distance_to(player.global_position), 0.8, "flying kick lunged forward")


func test_spin_kick_at_apex_hits_all_around() -> void:
	await _setup([Vector3(0, 0, -1.2), Vector3(0, 0, 1.2)])
	await _press(&"JUMP", 2)
	assert_true(await _wait_until(func() -> bool: return player.sim_velocity.y < 1.0))
	await _press(&"K", 2)
	assert_true(await _wait_idle())
	var landed := _player_hits()
	assert_eq(landed.size(), 2, "spin kick hits front and back")
	for hit in landed:
		assert_eq(hit.move.id, &"spin_kick")
		assert_eq(hit.damage, 10.0)


func test_back_elbow_hits_behind_without_turning() -> void:
	await _setup([Vector3(0, 0, 1.0)])
	var yaw := player.look_yaw
	var start_gap := dummies[0].global_position.distance_to(player.global_position)
	await _press(&"RB", 2)
	assert_true(await _wait_idle())
	assert_eq(_ids(_player_hits()), [&"back_elbow"])
	assert_almost_eq(player.look_yaw, yaw, 0.001, "no turn")
	assert_true(dummies[0].is_flying() or dummies[0].is_downed(), "knockdown")
	assert_true(await _wait_until(func() -> bool: return dummies[0].is_downed(), 120))
	var gap := dummies[0].global_position.distance_to(player.global_position)
	assert_gt(gap, start_gap + 0.5, "knocked away from the player, not pulled through")
	var to_dummy := dummies[0].global_position - player.global_position
	assert_lt(to_dummy.dot(player.get_forward()), 0.0, "still behind the player")


func test_grab_knees_release_then_throw_knocks_down_another() -> void:
	await _setup([Vector3(0, 0, -1.4), Vector3(0, 0, -3.6)])
	# P P P: the hook staggers the dummy.
	await _press(&"P", 2, 7)
	await _press(&"P", 2, 7)
	await _press(&"P", 2)
	assert_true(await _wait_until(func() -> bool: return dummies[0].state == CombatTypes.ActorState.STAGGER))
	assert_true(await _wait_idle())
	await _press(&"GRAB", 2, 4)
	assert_eq(player.state, CombatTypes.ActorState.GRABBING, "grabbed the staggered dummy")
	assert_eq(dummies[0].state, CombatTypes.ActorState.GRABBED)
	# A knee can't be cancelled into the next one, so press each after the last ends.
	for i in 3:
		await _press(&"P", 2)
		assert_true(await _wait_idle())
	var knees := _ids(_player_hits()).count(&"knee")
	assert_eq(knees, 3, "three knees")
	assert_eq(dummies[0].state, CombatTypes.ActorState.STAGGER, "third knee releases into a stagger")
	await _press(&"GRAB", 2, 4)
	assert_eq(player.state, CombatTypes.ActorState.GRABBING, "re-grab")
	await _press(&"K", 2)
	assert_true(await _wait_until(func() -> bool: return dummies[1].is_flying() or dummies[1].is_downed(), 240), "thrown body knocks down the dummy behind")
	assert_has(_ids(_player_hits()), &"throw")
	var impacts := hits.filter(func(h: HitInfo) -> bool: return h.is_body_impact and h.victim == dummies[1])
	assert_eq(impacts.size(), 1, "one body impact on the second dummy")


## Nearest distance from the player's first-person lens to `victim`'s meshes, and the share
## of the player's view `victim` covers (the camera at EyePoint + lens offset, looking along
## the player's look).
func _victim_in_lens(victim: CombatActor) -> Vector2:
	var cam := FPView.camera(player.get_eye_transform().origin, player.get_look_basis())
	return Vector2(FPView.nearest_mesh(victim.rig, cam.origin), FPView.covered(FPView.hits(victim.rig, cam, 32)))


func test_grabbed_victim_stays_out_of_the_holders_lens() -> void:
	# A grab pulls the victim in from where it stood while it bends over into &"held", head
	# first: its head and shoulders never sweep through the holder's throat-height lens (the
	# view never goes dark), on the grab and on the regrab after the third knee. Released on
	# its feet, it stands up away from the holder.
	await _setup([Vector3(0, 0, -1.4)])
	await _press(&"P", 2, 7)
	await _press(&"P", 2, 7)
	await _press(&"P", 2)
	assert_true(await _wait_until(func() -> bool: return dummies[0].state == CombatTypes.ActorState.STAGGER))
	assert_true(await _wait_idle())
	for phase: String in ["grab", "release", "regrab"]:
		if phase == "release":
			for i in 3:
				await _press(&"P", 2)
				if i < 2:
					assert_true(await _wait_idle())
		else:
			player.input.push_press(&"GRAB", 2)
		# Grabs are watched while the dummy is held, the release through the third knee.
		var nearest := INF
		var widest := 0.0
		var watched := 0
		for i in 40:
			await _ticks(1)
			if phase != "release" and dummies[0].state != CombatTypes.ActorState.GRABBED:
				continue
			watched += 1
			var seen := _victim_in_lens(dummies[0])
			nearest = minf(nearest, seen.x)
			widest = maxf(widest, seen.y)
		assert_gt(watched, 20, "%s: frames watched" % phase)
		var bound := 0.2 if phase == "release" else 0.25
		assert_gt(nearest, bound, "%s: the dummy stays %.2f m or more from the lens (nearest %.2f m)" % [phase, bound, nearest])
		assert_lt(widest, 0.5, "%s: the dummy covers at most %.0f%% of the view" % [phase, widest * 100.0])
		if phase == "release":
			assert_eq(dummies[0].state, CombatTypes.ActorState.STAGGER, "the third knee releases into a stagger")
			assert_true(await _wait_idle())


func test_stomp_hits_a_downed_dummy() -> void:
	await _setup([Vector3(0, 0, -1.0)])
	var knock := HitInfo.new()
	knock.attacker = player
	knock.victim = dummies[0]
	knock.reaction = CombatTypes.Reaction.KNOCKDOWN
	knock.direction = Vector3.FORWARD
	knock.knockback = Vector3(0, 2.5, 0)
	dummies[0].receive_hit(knock)
	assert_true(await _wait_until(func() -> bool: return dummies[0].is_downed()))
	await _press(&"K", 2)
	assert_true(await _wait_idle())
	assert_eq(_ids(_player_hits()), [&"stomp"])
	assert_true(dummies[0].is_downed(), "still down after the stomp")


func test_pipe_pickup_swings_and_throw() -> void:
	await _setup([Vector3(0, 0, -1.6), Vector3(0, 0, -6.0)])
	var pipe := get_tree().get_first_node_in_group(&"weapon") as Weapon
	pipe.global_position = player.global_position + player.global_basis * Vector3(0, 0.1, -0.6)
	pipe.linear_velocity = Vector3.ZERO
	await _ticks(5)
	await _press(&"GRAB", 2, 14)
	assert_true(player.holding_weapon(), "picked up the pipe")
	for i in 3:
		player.input.push_press(&"P", 2)
		player.input.push_wait(9)
	await _drain()
	assert_true(await _wait_idle())
	assert_eq(_ids(_player_hits()), [&"pipe_swing_1", &"pipe_swing_2", &"pipe_swing_3"])
	assert_eq(player.weapon_durability_left(), Tuning.data.weapon_durability - 3)
	# Face the far dummy and throw the pipe at it.
	hits.clear()
	dummies[0].set_post(FAR)
	await _ticks(2)
	await _press(&"GRAB", 2)
	assert_true(await _wait_until(func() -> bool: return not player.holding_weapon()))
	assert_true(await _wait_until(func() -> bool: return hits.any(func(h: HitInfo) -> bool: return h.move and h.move.id == &"weapon_throw"), 120), "thrown pipe hits")


func test_pipe_breaks_after_durability_runs_out() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	var pipe := get_tree().get_first_node_in_group(&"weapon") as Weapon
	pipe.global_position = player.global_position + player.global_basis * Vector3(0, 0.1, -0.6)
	await _ticks(5)
	await _press(&"GRAB", 2, 14)
	assert_true(player.holding_weapon())
	pipe.durability = 2
	var broke := [false]
	var on_broke := func(_a: Node3D, _w: Node3D) -> void: broke[0] = true
	CombatEvents.weapon_broke.connect(on_broke)
	for i in 3:
		player.input.push_press(&"P", 2)
		player.input.push_wait(9)
	await _drain()
	await _wait_idle()
	CombatEvents.weapon_broke.disconnect(on_broke)
	assert_true(broke[0], "weapon broke")
	assert_false(player.holding_weapon())
	var ids := _ids(_player_hits())
	assert_eq(ids.slice(0, 2), [&"pipe_swing_1", &"pipe_swing_2"])
	assert_does_not_have(ids, &"pipe_swing_3", "no phantom swing after the pipe broke")


func test_dodge_sidesteps_three_meters_with_iframes() -> void:
	await _setup([])
	var start := player.global_position
	player.input.scripted_move = Vector2(1, 0)
	player.input.push_press(&"DODGE", 2)
	await _ticks(2)
	assert_eq(player.state, CombatTypes.ActorState.DODGE)
	assert_true(player.is_invulnerable(), "invulnerable at the start of a dodge")
	player.input.scripted_move = Vector2.ZERO
	assert_true(await _wait_idle())
	var moved := player.global_position - start
	assert_almost_eq(moved.length(), Tuning.data.dodge_distance, 0.15, "about 3 m")
	assert_gt(moved.dot(player.global_basis.x), 2.0, "to the right")


func test_player_stands_relaxed_and_a_neutral_dodge_puts_the_guard_up() -> void:
	# Game-boy's M1 playtest: the player's arms hang loose until a strike (enemies keep the
	# boxer guard), and a dodge with no stick backsteps with the guard up by the face.
	await _setup([Vector3(0, 0, -2.5)])
	assert_eq(player.rig.stance, PlaceholderPoses.STANCE_RELAXED, "the player stands relaxed")
	assert_true(player.rig.wrapped_hands, "with wrapped hands")
	for dummy: TrainingDummy in dummies:
		assert_eq(dummy.rig.stance, PlaceholderPoses.STANCE_BOXER, "%s keeps the boxer guard" % dummy.name)
		assert_false(dummy.rig.wrapped_hands, "%s keeps its fist blocks" % dummy.name)
	var chest := player.rig.get_point_position(&"ChestPoint").y
	assert_lt(player.rig.get_point_position(&"LeftFistPoint").y, chest, "the lead hand hangs low")
	var start := player.global_position
	player.input.push_press(&"DODGE", 2)
	await _ticks(6)
	assert_eq(player.state, CombatTypes.ActorState.DODGE)
	assert_eq(player.rig.current_anim(), &"dodge_back", "no stick: the backstep")
	for point: StringName in [&"LeftFistPoint", &"RightFistPoint"]:
		assert_gt(player.rig.get_point_position(point).y, player.rig.get_point_position(&"ChestPoint").y + 0.15,
				"%s up by the face during the backstep" % point)
	assert_true(await _wait_idle())
	var moved := player.global_position - start
	assert_almost_eq(moved.length(), Tuning.data.dodge_distance, 0.15, "about 3 m")
	assert_gt(moved.dot(player.global_basis.z), 2.0, "backward")


func test_dodge_cancels_recovery() -> void:
	await _setup([])
	await _press(&"P", 2)
	assert_true(await _wait_until(func() -> bool: return player.current_move and player.current_move.is_recovery(player.move_frame)))
	await _press(&"DODGE", 2)
	await _ticks(1)
	assert_eq(player.state, CombatTypes.ActorState.DODGE, "dodge cancelled the jab's recovery")


func test_quick_turn_is_180_in_a_fifth_of_a_second() -> void:
	await _setup([])
	var yaw := player.look_yaw
	await _press(&"TURN", 2)
	await _ticks(Tuning.data.quick_turn_frames + 2)
	assert_almost_eq(absf(wrapf(player.look_yaw - yaw, -PI, PI)), PI, 0.05)


func test_magnetism_turns_toward_an_off_center_target() -> void:
	var off := Vector3(0, 0, -1.5).rotated(Vector3.UP, deg_to_rad(-20.0))
	await _setup([off])
	var start_yaw := player.look_yaw
	await _press(&"P", 2)
	assert_true(await _wait_idle())
	assert_eq(_ids(_player_hits()), [&"jab_1"])
	var turned := rad_to_deg(absf(wrapf(player.look_yaw - start_yaw, -PI, PI)))
	assert_between(turned, 5.0, Tuning.data.magnet_turn_deg + 0.5, "turned toward the target, capped")


func test_attack_with_no_target_whiffs_cleanly() -> void:
	await _setup([Vector3(3, 0, 3)])
	await _press(&"P", 2)
	assert_true(await _wait_idle())
	assert_eq(_player_hits().size(), 0)
	assert_has(whiffs, &"jab_1")


func test_finisher_ko_launches_and_dummy_revives() -> void:
	Tuning.data.dummy_health = 30.0
	await _setup([Vector3(0, 0, -1.6)])
	for d in dummies:
		d.max_health = 30.0
		d.health = 30.0
	for i in 4:
		player.input.push_press(&"P", 2)
		player.input.push_wait(7)
	await _drain()
	assert_true(await _wait_until(func() -> bool: return dummies[0].is_ko(), 240), "KO after P P P P")
	var landed := _player_hits()
	assert_false(landed.is_empty(), "hits landed")
	if not landed.is_empty():
		assert_true(landed.back().killed, "the uppercut killed")
	assert_true(await _wait_until(func() -> bool: return not dummies[0].is_ko(), int(Tuning.data.dummy_revive_s * 60) + 120), "revives")


# --- Presentation smoke -------------------------------------------------------------


func test_side_view_camera_cycles_while_gameplay_runs() -> void:
	await _setup([Vector3(0, 0, -1.6)], true)
	var director := get_tree().get_first_node_in_group(&"camera_director")
	assert_not_null(director, "camera director present")
	if director == null:
		return
	director.call(&"cycle")
	await _ticks(2)
	assert_eq(director.get(&"mode"), &"side_view")
	var cam := director.call(&"active_camera") as Camera3D
	assert_true(cam != null and cam.current, "side camera is current")
	for i in 4:
		player.input.push_press(&"P", 2)
		player.input.push_wait(7)
	await _drain()
	assert_true(await _wait_idle())
	assert_eq(_player_hits().size(), 4, "combo lands with the side camera active")
	director.call(&"cycle")
	await _ticks(2)
	assert_eq(director.get(&"mode"), &"free_fly")
	director.call(&"cycle")
	await _ticks(2)
	assert_eq(director.get(&"mode"), &"first_person")
