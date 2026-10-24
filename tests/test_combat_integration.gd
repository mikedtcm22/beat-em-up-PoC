extends GutTest
## End-to-end combat in the real test room: a scripted player performs every Spec §4
## combo and move against training dummies; asserts which moves land, in what order,
## for how much, and with what tier. Milestone 1's "done when": every combo can be
## performed and registers hits. The held block (Game-boy's addition to Spec §4) is
## tested against a sparring dummy's telegraphed jab: coverage, chip, guard meter,
## blockstun, recoil, perfect block, guard break and the B press rule.

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
## `yaw_deg` overrides the player's facing (default: the room's, down the street). No
## dummy spars (the room's centre dummy does by default) unless its index is in `sparring`.
func _setup(posts: Array[Vector3], presentation: bool = false, yaw_deg: float = NAN,
		sparring: Array[int] = []) -> void:
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
		dummies[i].sparring = sparring.has(i)
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


## P · P, then mash (Game-boy's second playtest moved the flurry here from P P · P).
func test_pause_branch_flurry_ends_in_shove() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	await _press(&"P", 2)
	assert_true(await _wait_until(_chain_ready_for_pause(&"jab_1", 15)), "waited into the pause window")
	for i in 7:
		player.input.push_press(&"P", 2)
		player.input.push_wait(3)
	await _drain()
	assert_true(await _wait_idle())
	var ids := _ids(_player_hits())
	assert_eq(ids.slice(0, 2), [&"jab_1", &"body_flurry"])
	assert_gt(ids.count(&"body_flurry"), 2, "mashing repeats the flurry")
	assert_eq(ids.back(), &"shove", "flurry ends in the shove finisher")
	var flurry_hits := _player_hits().filter(func(h: HitInfo) -> bool: return h.move.id == &"body_flurry")
	if not flurry_hits.is_empty():
		assert_eq(flurry_hits[0].input_timing, &"pause")
		assert_eq(flurry_hits[0].damage, 2.0)


## P P · P: the spinning backfist (Game-boy's second playtest), a full turn and the back
## of the right fist; the first-person view spins with it and lands back on the heading.
func test_punch_punch_pause_punch_is_the_spinning_backfist() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	var yaw := player.look_yaw
	await _press(&"P", 2, 7)
	await _press(&"P", 2)
	assert_true(await _wait_until(_chain_ready_for_pause(&"jab_2", 15)), "waited into the pause window")
	await _press(&"P", 2)
	var widest := 0.0
	while player.current_move != null or TimeController.is_in_hitstop(player):
		widest = maxf(widest, absf(wrapf(player.get_camera_view_yaw(), -180.0, 180.0)))
		await get_tree().physics_frame
	assert_true(await _wait_idle())
	assert_eq(_ids(_player_hits()), [&"jab_1", &"jab_2", &"spinning_backfist"])
	assert_eq(_damages(_player_hits()), [6.0, 6.0, 14.0])
	if _player_hits().size() == 3:
		var backfist := _player_hits()[2]
		assert_eq(backfist.tier, CombatTypes.HitTier.FINISHER)
		assert_eq(backfist.input_timing, &"pause")
		assert_eq(backfist.chain_step, 3)
	assert_true(await _wait_until(func() -> bool: return dummies[0].is_downed(), 120), "knocked down")
	assert_gt(widest, 150.0, "the view spun round with the body")
	assert_almost_eq(wrapf(player.get_camera_view_yaw(), -180.0, 180.0), 0.0, 0.01, "and landed back on the heading")
	assert_lt(absf(angle_difference(player.look_yaw, yaw)), deg_to_rad(16.0), "aim untouched (magnetism aside)")


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
## Nearest distance (x) from the player's first-person lens to `victim`'s meshes, and the
## share of the view (y) they cover, seen through the real view (the hold view included).
func _victim_in_lens(victim: CombatActor) -> Vector2:
	var cam := FirstPersonCamera.view_from_eye(player, player.get_eye_transform().origin)
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


func test_player_stands_relaxed_and_b_back_backsteps_with_the_stance_arms() -> void:
	# Game-boy's M1 playtest: the player's arms hang loose until a strike (enemies keep the
	# boxer guard). The backstep is B + back now (neutral B blocks) and keeps the stance's
	# arms: the guard is the held block's. (This test pinned the old neutral-B backstep
	# with the guard up; the held block changed both on purpose.)
	await _setup([Vector3(0, 0, -2.5)])
	assert_eq(player.rig.stance, PlaceholderPoses.STANCE_RELAXED, "the player stands relaxed")
	assert_true(player.rig.wrapped_hands, "with wrapped hands")
	for dummy: TrainingDummy in dummies:
		assert_eq(dummy.rig.stance, PlaceholderPoses.STANCE_BOXER, "%s keeps the boxer guard" % dummy.name)
		assert_false(dummy.rig.wrapped_hands, "%s wears gloves" % dummy.name)
	var chest := player.rig.get_point_position(&"ChestPoint").y
	assert_lt(player.rig.get_point_position(&"LeftFistPoint").y, chest, "the lead hand hangs low")
	var start := player.global_position
	player.input.scripted_move = Vector2(0, -1)
	player.input.push_press(&"DODGE", 2)
	await _ticks(6)
	assert_eq(player.state, CombatTypes.ActorState.DODGE)
	assert_eq(player.rig.current_anim(), &"dodge_back", "B + back: the backstep")
	for point: StringName in [&"LeftFistPoint", &"RightFistPoint"]:
		assert_lt(player.rig.get_point_position(point).y, player.rig.get_point_position(&"ChestPoint").y,
				"%s stays low during the backstep" % point)
	player.input.scripted_move = Vector2.ZERO
	assert_true(await _wait_idle())
	var moved := player.global_position - start
	assert_almost_eq(moved.length(), Tuning.data.dodge_distance, 0.15, "about 3 m")
	assert_gt(moved.dot(player.global_basis.z), 2.0, "backward")


func test_dodge_and_block_cancel_recovery() -> void:
	# B + stick dodges out of a recovery; neutral B blocks out of it (this test used a
	# neutral B for the dodge before the held block took it).
	for blocking: bool in [false, true]:
		await _setup([])
		await _press(&"P", 2)
		assert_true(await _wait_until(func() -> bool: return player.current_move and player.current_move.is_recovery(player.move_frame)))
		player.input.scripted_move = Vector2.ZERO if blocking else Vector2(-1, 0)
		player.input.push_down(&"DODGE")
		await _drain()
		await _ticks(1)
		player.input.scripted_move = Vector2.ZERO
		if blocking:
			assert_eq(player.state, CombatTypes.ActorState.BLOCK, "neutral B blocked out of the jab's recovery")
			assert_null(player.current_move, "the jab was cancelled")
		else:
			assert_eq(player.state, CombatTypes.ActorState.DODGE, "B + left dodged out of the jab's recovery")
		player.input.push_up(&"DODGE")
		assert_true(await _wait_idle())


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


# --- Held block (Game-boy-approved addition to Spec §4) -----------------------------
# A sparring dummy's telegraphed jab (dummy_jab: 18 frames of wind-up, 6 damage, LIGHT)
# connects out to about 1.05 m; JAB_DIST keeps the dummy inside that.

const JAB_DIST := 0.95


## One dummy JAB_DIST ahead of the player (sparring off; tests throw its jabs).
func _partner(yaw_deg: float = NAN) -> TrainingDummy:
	await _setup([Vector3(0, 0, -JAB_DIST)], false, yaw_deg)
	return dummies[0]


## Put `dummy` back JAB_DIST from the player, on the line between them (blocked jabs push
## the player out of reach).
func _restage(dummy: TrainingDummy) -> void:
	var to_player := player.global_position - dummy.global_position
	to_player.y = 0.0
	dummy.set_post(player.global_position - to_player.normalized() * JAB_DIST, atan2(-to_player.x, -to_player.z))


func _player_hits_taken() -> Array[HitInfo]:
	var out: Array[HitInfo] = []
	for hit in hits:
		if hit.victim == player:
			out.append(hit)
	return out


## Throw `dummy`'s jab (or `move` as a telegraphed attack) and wait for it to reach the
## player. Returns the hit, or null if it never landed.
func _jab_lands(dummy: TrainingDummy, move: MoveData = null) -> HitInfo:
	var before := _player_hits_taken().size()
	if move:
		dummy.start_move(move, 1, &"root", true)
	else:
		dummy.start_jab()
	var landed := await _wait_until(func() -> bool: return _player_hits_taken().size() > before, 90)
	return _player_hits_taken().back() if landed else null


## Hold B with the stick centered for `ticks` ticks: the guard is up (well past the
## perfect-block window) when it returns.
func _raise_guard(ticks: int = 24) -> void:
	player.input.scripted_move = Vector2.ZERO
	player.input.push_down(&"DODGE")
	await _drain()
	await _ticks(ticks)


func test_sparring_jab_hits_an_idle_player() -> void:
	var dummy := await _partner()
	var hit := await _jab_lands(dummy)
	assert_not_null(hit, "the jab lands")
	if hit == null:
		return
	assert_eq(hit.move.id, &"dummy_jab")
	assert_eq(hit.attacker, dummy)
	assert_false(hit.blocked)
	assert_eq(hit.damage, 6.0)
	assert_eq(hit.reaction, CombatTypes.Reaction.FLINCH)
	assert_eq(player.state, CombatTypes.ActorState.HITSTUN, "the player flinches")
	assert_almost_eq(player.health, 94.0, 0.001)
	assert_true(await _wait_idle(), "and recovers")


func test_sparring_dummy_winds_up_on_its_own_when_the_player_is_in_front() -> void:
	# Sparring: the jab comes every sparring_interval_s (seeded jitter) while the player
	# stands within sparring_range in front of the dummy; the startup is a WINDUP that
	# scales with Tuning.windup_mult; a light hit knocks the dummy out of it.
	var events: Array = []
	var on_start := func(actor: Node3D, move: MoveData) -> void: events.append([&"start", actor, move.id, Engine.get_physics_frames()])
	var on_end := func(actor: Node3D, interrupted: bool) -> void: events.append([&"end", actor, interrupted, Engine.get_physics_frames()])
	CombatEvents.windup_started.connect(on_start)
	CombatEvents.windup_ended.connect(on_end)
	await _setup([Vector3(0, 0, -JAB_DIST)], false, NAN, [0])
	var dummy := dummies[0]
	assert_true(dummy.sparring)
	var interval := Tuning.data.sparring_interval_s + Tuning.data.sparring_jitter_s
	assert_true(await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.WINDUP,
			ceili(interval * 60.0) + 10), "the dummy winds up within an interval")
	assert_eq(dummy.current_move.id, &"dummy_jab")
	assert_true(await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.ATTACK, 40))
	assert_eq(events.size(), 2, "windup_started, then windup_ended")
	if events.size() == 2:
		assert_eq(events[0][2], &"dummy_jab")
		assert_false(events[1][2], "the wind-up ran its course")
		assert_eq(events[1][3] - events[0][3], dummy.current_move.startup, "the wind-up is the jab's startup")
	assert_true(await _wait_idle())
	# Out of range, or behind the dummy: no jab.
	for post: Vector3 in [Vector3(0, 0, -2.5)]:
		dummy.set_post(player.global_position + player.global_basis * post, dummy.rotation.y)
		dummy.spar_in(0)
		await _ticks(40)
		assert_eq(dummy.state, CombatTypes.ActorState.FREE, "no jab with the player %.1f m away" % absf(post.z))
	var behind := player.global_position + player.global_basis * Vector3(0, 0, -JAB_DIST)
	dummy.face_player = false
	dummy.set_post(behind, player.rotation.y)  # facing away from the player
	dummy.spar_in(0)
	await _ticks(40)
	assert_eq(dummy.state, CombatTypes.ActorState.FREE, "no jab at a player behind the dummy")
	# Wind-ups scale with windup_mult, and a light hit interrupts one.
	dummy.face_player = true
	var to_player := player.global_position - behind
	dummy.set_post(behind, atan2(-to_player.x, -to_player.z))
	Tuning.data.windup_mult = 2.0
	events.clear()
	hits.clear()
	dummy.start_jab()
	assert_eq(dummy.current_move.startup, 48, "startup doubled")
	await _ticks(10)
	await _press(&"P", 2)
	assert_true(await _wait_until(func() -> bool: return events.size() >= 2, 30))
	assert_eq(events.back()[0], &"end")
	assert_true(events.back()[2], "the jab hit the dummy out of its wind-up")
	assert_null(dummy.current_move)
	assert_eq(_player_hits_taken().size(), 0, "the interrupted jab never came out")
	CombatEvents.windup_started.disconnect(on_start)
	CombatEvents.windup_ended.disconnect(on_end)


func test_neutral_b_blocks_the_jab_from_the_front() -> void:
	var events: Array[StringName] = []
	var on_blocked := func(defender: Node3D, _hit: HitInfo) -> void:
		if defender == player:
			events.append(&"blocked")
	var on_started := func(actor: Node3D) -> void:
		if actor == player:
			events.append(&"block_started")
	var on_ended := func(actor: Node3D) -> void:
		if actor == player:
			events.append(&"block_ended")
	CombatEvents.blocked.connect(on_blocked)
	CombatEvents.block_started.connect(on_started)
	CombatEvents.block_ended.connect(on_ended)
	var dummy := await _partner()
	await _raise_guard()
	assert_eq(player.state, CombatTypes.ActorState.BLOCK, "neutral B raises the guard")
	assert_true(player.is_guard_effective())
	assert_eq(player.rig.current_anim(), &"block")
	var start := player.global_position
	var hit := await _jab_lands(dummy)
	assert_not_null(hit)
	if hit == null:
		return
	assert_true(hit.blocked, "blocked")
	assert_false(hit.perfect_block, "raised long before: not perfect")
	assert_false(hit.guard_broken)
	assert_almost_eq(hit.damage, 6.0 * Tuning.data.chip_ratio, 0.001, "chip damage 15%")
	assert_almost_eq(player.health, 100.0 - 6.0 * Tuning.data.chip_ratio, 0.001)
	assert_almost_eq(player.guard, Tuning.data.guard_max - 24.0, 0.001, "guard drained by 4 x 6")
	assert_eq(player.state, CombatTypes.ActorState.BLOCKSTUN)
	assert_eq(player.rig.current_anim(), &"block_hit")
	assert_eq(dummy.state, CombatTypes.ActorState.HITSTUN, "the attacker recoils")
	assert_null(dummy.current_move, "its jab is cut short")
	assert_eq(dummy.rig.current_anim(), &"recoil")
	assert_string_contains(dummy.debug_state_text(), "recoil")
	# Blockstun: pushed straight back, still in the guard, then the plain guard again.
	var dir := hit.direction
	assert_true(await _wait_until(func() -> bool: return player.state == CombatTypes.ActorState.BLOCK, 30))
	var pushed := player.global_position - start
	assert_almost_eq(pushed.length(), Tuning.data.block_push_light_m, 0.04, "pushed back about 0.3 m")
	assert_gt(pushed.normalized().dot(dir), 0.95, "along the hit")
	assert_true(await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.FREE, 30), "the recoil ends")
	player.input.push_up(&"DODGE")
	assert_true(await _wait_idle())
	assert_eq(events, [&"block_started", &"blocked", &"block_ended"])
	CombatEvents.blocked.disconnect(on_blocked)
	CombatEvents.block_started.disconnect(on_started)
	CombatEvents.block_ended.disconnect(on_ended)


## The approved design: a blocked grunt attack opens a punish window. A jab pressed during
## the blockstun must land while the attacker is still recoiling.
func test_punch_in_blockstun_lands_inside_the_attackers_recoil() -> void:
	var dummy := await _partner()
	await _raise_guard()
	var recovered := [false]
	var on_state := func(actor: Node3D, _old: int, new_state: int) -> void:
		if actor == dummy and new_state == CombatTypes.ActorState.FREE:
			recovered[0] = true
	var hit := await _jab_lands(dummy)
	assert_true(hit != null and hit.blocked, "blocked")
	CombatEvents.actor_state_changed.connect(on_state)
	player.input.push_press(&"P", 2)
	assert_true(await _wait_until(func() -> bool: return _player_hits().size() > 0, 40), "the punish lands")
	CombatEvents.actor_state_changed.disconnect(on_state)
	assert_false(recovered[0], "the jab connected before the attacker's recoil ended")
	if not _player_hits().is_empty():
		assert_eq(_player_hits()[0].move.id, &"jab_1")
	player.input.push_up(&"DODGE")


func test_jabs_from_behind_or_the_side_land_in_full() -> void:
	# Only attackers within block_arc_half_angle_deg (60) of the look are blocked: turned
	# away, the player eats the jab whole (the rear warning still matters).
	for turn: float in [180.0, 90.0, -90.0, 45.0]:
		var dummy := await _partner()
		await _raise_guard()
		player.look_yaw = wrapf(player.look_yaw + deg_to_rad(turn), -PI, PI)
		await _ticks(2)
		assert_eq(player.state, CombatTypes.ActorState.BLOCK)
		var hit := await _jab_lands(dummy)
		assert_not_null(hit, "turned %.0f: the jab reaches the player" % turn)
		if hit == null:
			continue
		if absf(turn) <= Tuning.data.block_arc_half_angle_deg:
			assert_true(hit.blocked, "turned %.0f: still inside the guard's arc" % turn)
			continue
		assert_false(hit.blocked, "turned %.0f: the guard does not cover it" % turn)
		assert_eq(hit.damage, 6.0, "turned %.0f: full damage" % turn)
		assert_almost_eq(player.health, 94.0, 0.001)
		assert_eq(player.state, CombatTypes.ActorState.HITSTUN, "turned %.0f: the player flinches" % turn)
		assert_almost_eq(player.guard, Tuning.data.guard_max, 0.001, "no guard drained")
		player.input.push_up(&"DODGE")
		await _drain()


func test_a_guard_raised_just_in_time_is_a_perfect_block_and_the_attacker_can_be_grabbed() -> void:
	var events: Array[StringName] = []
	var on_perfect := func(defender: Node3D, _hit: HitInfo) -> void:
		if defender == player:
			events.append(&"perfect_blocked")
	CombatEvents.perfect_blocked.connect(on_perfect)
	var dummy := await _partner()
	dummy.start_jab()
	var startup := dummy.current_move.startup
	# Raise the guard 7 frames before the jab comes out: up (4 frames) just before it lands.
	assert_true(await _wait_until(func() -> bool: return dummy.move_frame >= startup - 7, 30))
	player.input.push_down(&"DODGE")
	assert_true(await _wait_until(func() -> bool: return not _player_hits_taken().is_empty(), 30), "the jab lands")
	var hit := _player_hits_taken()[0]
	assert_true(hit.blocked and hit.perfect_block, "a perfect block")
	assert_eq(hit.damage, 0.0, "no chip")
	assert_eq(player.health, 100.0)
	assert_almost_eq(player.guard, Tuning.data.guard_max, 0.001, "no guard drained")
	assert_eq(player.state, CombatTypes.ActorState.BLOCK, "no blockstun")
	assert_eq(dummy.state, CombatTypes.ActorState.STAGGER, "the attacker staggers")
	assert_true(dummy.can_be_grabbed(), "a real stagger: grabbable")
	assert_eq(events, [&"perfect_blocked"])
	# Drop the guard and grab the staggered dummy (LB does nothing while blocking).
	player.input.push_up(&"DODGE")
	player.input.push_press(&"GRAB", 2)
	await _drain()
	assert_true(await _wait_until(func() -> bool: return player.state == CombatTypes.ActorState.GRABBING, 20), "grabbed")
	assert_eq(dummy.state, CombatTypes.ActorState.GRABBED)
	CombatEvents.perfect_blocked.disconnect(on_perfect)
	# Perfect blocks can be turned off: the same timing is an ordinary block.
	Tuning.data.perfect_block_enabled = false
	dummy = await _partner()
	dummy.start_jab()
	assert_true(await _wait_until(func() -> bool: return dummy.move_frame >= startup - 7, 30))
	player.input.push_down(&"DODGE")
	assert_true(await _wait_until(func() -> bool: return not _player_hits_taken().is_empty(), 30))
	assert_true(_player_hits_taken()[0].blocked)
	assert_false(_player_hits_taken()[0].perfect_block, "perfect_block_enabled = false")
	assert_eq(dummy.state, CombatTypes.ActorState.HITSTUN, "an ordinary recoil")


func test_too_late_a_guard_is_not_up_yet() -> void:
	# The guard stops hits only after block_raise_frames of holding (1 since Game-boy's
	# second playtest; raised here to 4 to see it).
	Tuning.data.block_raise_frames = 4
	var dummy := await _partner()
	dummy.start_jab()
	var startup := dummy.current_move.startup
	assert_true(await _wait_until(func() -> bool: return dummy.move_frame >= startup - 2, 40))
	player.input.push_down(&"DODGE")
	assert_true(await _wait_until(func() -> bool: return not _player_hits_taken().is_empty(), 30))
	assert_false(_player_hits_taken()[0].blocked, "raised 2 frames before the hit: not up yet")
	assert_eq(_player_hits_taken()[0].damage, 6.0)


## Game-boy's second playtest: a parry has to work on reaction to the wind-up. B pressed
## `offset` frames after the sparring jab's wind-up starts (24 frames): early presses are
## an ordinary block, presses from 10 frames in until 2 frames before contact parry (the
## press is polled a tick later), a reaction press 200 ms (12 frames) in included.
func test_parry_timing_sweep_covers_a_reaction_to_the_wind_up() -> void:
	var results := {}
	for offset: int in [0, 4, 8, 10, 12, 14, 16, 18, 20, 22, 23]:
		var dummy := await _partner()
		dummy.start_jab()
		assert_eq(dummy.current_move.startup, 24, "the sparring jab winds up for 0.4 s")
		assert_true(await _wait_until(func() -> bool: return dummy.move_frame >= offset, 40))
		player.input.push_down(&"DODGE")
		assert_true(await _wait_until(func() -> bool: return not _player_hits_taken().is_empty(), 40), "offset %d: the jab lands" % offset)
		var hit := _player_hits_taken()[0]
		results[offset] = &"parry" if hit.perfect_block else (&"block" if hit.blocked else &"hit")
		player.input.push_up(&"DODGE")
		await _drain()
	gut.p("parry sweep (press frames after the wind-up starts): %s" % results)
	# The press reaches the player on the next tick: pressed on the frame before contact
	# (23) the guard is not up yet.
	for offset: int in results:
		var expected := &"parry" if offset >= 10 else &"block"
		if offset >= 23:
			expected = &"hit"
		assert_eq(results[offset], expected, "B pressed %d frames into the wind-up" % offset)
	assert_eq(results[12], &"parry", "a reaction press 200 ms after the wind-up starts parries")


func test_repeated_blocked_hits_break_the_guard() -> void:
	var broken: Array[HitInfo] = []
	var on_broken := func(defender: Node3D, hit: HitInfo) -> void:
		if defender == player:
			broken.append(hit)
	CombatEvents.guard_broken.connect(on_broken)
	var dummy := await _partner()
	await _raise_guard()
	var expected := Tuning.data.guard_max
	for i in 5:
		# Back in reach (each blocked jab pushes the player 0.3 m away); jabs come faster
		# than guard_regen_delay_s, so the meter does not refill in between.
		_restage(dummy)
		var hit := await _jab_lands(dummy)
		assert_not_null(hit, "jab %d lands" % (i + 1))
		if hit == null:
			return
		assert_true(hit.blocked, "jab %d is blocked" % (i + 1))
		expected -= 24.0
		if i < 4:
			assert_false(hit.guard_broken)
			assert_almost_eq(player.guard, expected, 0.001, "jab %d drains 24" % (i + 1))
			assert_true(await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.FREE, 40))
			continue
		assert_true(hit.guard_broken, "the fifth jab empties the meter")
		assert_eq(hit.reaction, CombatTypes.Reaction.STAGGER)
		assert_eq(player.guard, 0.0)
		assert_eq(player.state, CombatTypes.ActorState.STAGGER, "the guard is knocked apart")
		assert_eq(player.rig.current_anim(), &"guard_break")
		assert_false(player.is_guarding(), "the guard drops")
		assert_eq(dummy.state, CombatTypes.ActorState.ATTACK, "breaking the guard is no recoil")
	assert_eq(broken.size(), 1, "guard_broken emitted once")
	await _ticks(Tuning.data.guard_break_frames - 5)
	assert_eq(player.guard, 0.0, "still empty during the break")
	await _ticks(10)
	assert_almost_eq(player.guard, Tuning.data.guard_break_refill, 0.001, "refilled to 50 after the break")
	assert_ne(player.state, CombatTypes.ActorState.STAGGER, "the stagger is over")
	assert_eq(player.state, CombatTypes.ActorState.BLOCK, "B still held: the guard comes back up")
	CombatEvents.guard_broken.disconnect(on_broken)


func test_unblockable_moves_go_through_a_block() -> void:
	var dummy := await _partner()
	var grab_like := (load("res://game/combat/moves/dummy_jab.tres") as MoveData).duplicate() as MoveData
	grab_like.unblockable = true
	await _raise_guard()
	var hit := await _jab_lands(dummy, grab_like)
	assert_not_null(hit)
	if hit == null:
		return
	assert_false(hit.blocked, "unblockable")
	assert_eq(hit.damage, 6.0)
	assert_eq(player.state, CombatTypes.ActorState.HITSTUN)
	assert_almost_eq(player.guard, Tuning.data.guard_max, 0.001)


func test_b_with_a_stick_direction_dodges_and_neutral_b_blocks() -> void:
	# The press decides: stick under block_stick_threshold blocks, otherwise B dodges that
	# way (sidestep, and the backstep on B + back).
	for stick: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(0.2, 0.1), Vector2.ZERO]:
		await _setup([])
		var start := player.global_position
		player.input.scripted_move = stick
		player.input.push_press(&"DODGE", 2)
		await _drain()
		player.input.scripted_move = Vector2.ZERO
		if stick.length() < Tuning.data.block_stick_threshold:
			assert_true(player.is_guarding(), "stick %s: B blocks" % stick)
			assert_true(await _wait_idle())
			assert_lt(start.distance_to(player.global_position), 0.05, "stick %s: no dodge" % stick)
			continue
		assert_eq(player.state, CombatTypes.ActorState.DODGE, "stick %s: B dodges" % stick)
		assert_true(await _wait_idle())
		var moved := player.global_basis.inverse() * (player.global_position - start)
		assert_almost_eq(moved.length(), Tuning.data.dodge_distance, 0.15, "stick %s: about 3 m" % stick)
		assert_gt(Vector2(moved.x, -moved.z).normalized().dot(stick.normalized()), 0.95, "stick %s: that way" % stick)


func test_the_stick_at_press_time_decides_block_or_dodge() -> void:
	# A B press buffered during a jab's startup is decided by the stick when it was pressed.
	await _setup([])
	await _press(&"P", 2)
	player.input.scripted_move = Vector2.ZERO
	player.input.push_down(&"DODGE")
	await _drain()
	player.input.scripted_move = Vector2(1, 0)
	assert_true(await _wait_until(func() -> bool: return player.is_guarding(), 30), "pressed with the stick centered: a block")
	player.input.scripted_move = Vector2.ZERO
	player.input.push_up(&"DODGE")
	assert_true(await _wait_idle())


func test_p_while_blocking_attacks_after_the_cancel_frames() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	await _raise_guard(10)
	player.input.push_press(&"P", 2)
	await _ticks(1)
	assert_true(player.is_dropping_guard(), "P drops the guard")
	assert_false(player.is_guard_effective(), "a dropping guard stops nothing")
	await _ticks(Tuning.data.block_attack_cancel_frames - 1)
	assert_eq(player.state, CombatTypes.ActorState.BLOCK, "still coming down")
	await _ticks(1)
	assert_eq(player.state, CombatTypes.ActorState.ATTACK, "the jab starts %d frames after the press" % Tuning.data.block_attack_cancel_frames)
	assert_eq(player.current_move.id, &"jab_1")
	assert_true(await _wait_until(func() -> bool: return player.current_move == null, 40))
	assert_eq(player.state, CombatTypes.ActorState.BLOCK, "B still held: the guard comes back up after the jab")
	player.input.push_up(&"DODGE")
	assert_true(await _wait_idle())
	assert_eq(_ids(_player_hits()), [&"jab_1"], "and lands")
	# K works the same way.
	await _raise_guard(10)
	player.input.push_press(&"K", 2)
	await _ticks(Tuning.data.block_attack_cancel_frames + 1)
	assert_eq(player.state, CombatTypes.ActorState.ATTACK)
	assert_eq(player.current_move.id, &"front_kick")
	player.input.push_up(&"DODGE")
	assert_true(await _wait_idle())


func test_releasing_b_drops_the_guard_after_the_release_frames() -> void:
	await _setup([])
	await _raise_guard(10)
	player.input.push_up(&"DODGE")
	await _ticks(1)
	assert_true(player.is_dropping_guard())
	await _ticks(Tuning.data.block_release_frames - 1)
	assert_eq(player.state, CombatTypes.ActorState.BLOCK, "still coming down")
	await _ticks(1)
	assert_eq(player.state, CombatTypes.ActorState.FREE, "back to neutral after %d frames" % Tuning.data.block_release_frames)


func test_blocking_walks_slowly_turns_freely_and_ignores_jump_and_grab() -> void:
	await _setup([])
	await _raise_guard(10)
	var start := player.global_position
	player.input.scripted_move = Vector2(0, 1)
	await _ticks(60)
	var speed := Vector2(player.sim_velocity.x, player.sim_velocity.z).length()
	assert_almost_eq(speed, Tuning.data.move_speed * Tuning.data.block_move_mult, 0.05, "walks at 35% speed")
	assert_gt(start.distance_to(player.global_position), 1.0, "and moves")
	player.input.scripted_move = Vector2.ZERO
	player.input.push_press(&"JUMP", 2)
	player.input.push_press(&"GRAB", 2)
	await _drain()
	await _ticks(2)
	assert_eq(player.state, CombatTypes.ActorState.BLOCK, "no jump or grab in the guard")
	assert_true(player.is_on_floor())
	var yaw := player.look_yaw
	player.input.push_press(&"TURN", 2)
	await _drain()
	await _ticks(Tuning.data.quick_turn_frames + 2)
	assert_almost_eq(absf(wrapf(player.look_yaw - yaw, -PI, PI)), PI, 0.05, "quick turn works")
	assert_almost_eq(player.get_forward().dot(player.get_look_basis() * Vector3.FORWARD), 1.0, 0.01,
			"the guard swings with the look")
	player.input.push_up(&"DODGE")
	assert_true(await _wait_idle())


func test_guard_regenerates_after_the_delay() -> void:
	var dummy := await _partner()
	await _raise_guard()
	assert_not_null(await _jab_lands(dummy))
	var drained := player.guard
	assert_almost_eq(drained, Tuning.data.guard_max - 24.0, 0.001)
	var delay := roundi(Tuning.data.guard_regen_delay_s * 60.0)
	await _ticks(delay - 6)
	assert_almost_eq(player.guard, drained, 0.001, "no regeneration before the delay")
	await _ticks(36)
	# About half a second of regeneration at 35/s.
	assert_between(player.guard, drained + 12.0, drained + 24.0, "regenerating at guard_regen_per_s")
	assert_true(await _wait_until(func() -> bool: return player.guard >= Tuning.data.guard_max, 90), "back to full")
	assert_eq(player.guard, Tuning.data.guard_max)


func test_chip_never_takes_the_last_point_of_health() -> void:
	var dummy := await _partner()
	player.health = 1.4
	await _raise_guard()
	var hit := await _jab_lands(dummy)
	assert_true(hit != null and hit.blocked)
	assert_almost_eq(player.health, 1.0, 0.001, "chip stops at 1 health")
	assert_almost_eq(hit.damage, 0.4, 0.001, "the chip that got through")
	assert_true(await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.FREE, 40))
	_restage(dummy)
	hit = await _jab_lands(dummy)
	assert_true(hit != null and hit.blocked)
	assert_almost_eq(player.health, 1.0, 0.001, "and stays there")


func test_bodies_and_weapons_hitting_the_guard_drain_it_harder() -> void:
	# Code-applied hits from the front: a flying body drains guard x body_impact_guard_mult,
	# a thrown weapon (or a pipe swing) x its move's guard_damage_mult.
	var dummy := await _partner()
	await _raise_guard()
	var cases := {
		&"impact_body_knockdown": [&"body", true, 4.0 * 5.0 * Tuning.data.body_impact_guard_mult],
		&"weapon_throw": [&"thrown", true, 4.0 * 15.0],
		&"pipe_swing_1": [&"root", false, 4.0 * 10.0 * 1.5],
	}
	for id: StringName in cases:
		var move := load("res://game/combat/moves/%s.tres" % id) as MoveData
		var row: Array = cases[id]
		player.guard = Tuning.data.guard_max
		var hit := HitInfo.new()
		hit.attacker = dummy
		hit.victim = player
		hit.move = move
		hit.damage = move.damage
		hit.tier = move.tier
		hit.reaction = move.reaction
		hit.direction = (player.global_position - dummy.global_position).normalized()
		hit.is_body_impact = row[1]
		hit.input_timing = row[0]
		assert_true(player.receive_hit(hit))
		assert_true(hit.blocked, "%s from the front is blocked" % id)
		assert_almost_eq(Tuning.data.guard_max - player.guard, float(row[2]), 0.001, "%s drains %.0f" % [id, row[2]])
		player.reset_state()
		await _raise_guard()


func test_the_player_is_knocked_out_and_gets_back_up_in_the_test_room() -> void:
	var dummy := await _partner()
	player.health = 4.0
	var hit := await _jab_lands(dummy)
	assert_true(hit != null and hit.killed, "the jab finishes the player")
	assert_true(await _wait_until(func() -> bool: return player.is_ko(), 120), "KO")
	assert_true(player.is_invulnerable())
	var revive := roundi(Tuning.data.player_revive_s * 60.0)
	assert_true(await _wait_until(func() -> bool: return not player.is_ko(), revive + 30), "gets back up")
	assert_eq(player.health, player.max_health, "at full health")
	assert_true(await _wait_idle())
	# God mode: hits still land, without damage.
	Tuning.data.god_mode = true
	_restage(dummy)
	hit = await _jab_lands(dummy)
	assert_true(hit != null and not hit.blocked)
	assert_eq(player.health, player.max_health, "god mode keeps the health")
	assert_eq(player.state, CombatTypes.ActorState.HITSTUN, "but the player still flinches")


func test_f5_toggles_sparring_on_every_dummy() -> void:
	var fresh: Node3D = ROOM.instantiate()
	fresh.set(&"with_presentation", false)
	add_child_autofree(fresh)
	await _ticks(2)
	var all: Array[TrainingDummy] = []
	all.assign(fresh.get(&"dummies"))
	assert_eq(all.map(func(d: TrainingDummy) -> bool: return d.sparring), [false, true, false],
			"the centre dummy spars by default")
	var press := InputEventAction.new()
	press.action = &"sparring"
	press.pressed = true
	fresh.call(&"_unhandled_input", press)
	assert_eq(all.map(func(d: TrainingDummy) -> bool: return d.sparring), [true, true, true], "F5: all three spar")
	fresh.call(&"_unhandled_input", press)
	assert_eq(all.map(func(d: TrainingDummy) -> bool: return d.sparring), [false, false, false], "F5 again: none")
	assert_true(InputMap.has_action(&"sparring"))


## dummy_jab as a HEAVY hit (the heavy blockstun), or with `startup` frames of wind-up.
func _jab_variant(tier: CombatTypes.HitTier, startup: int = -1) -> MoveData:
	var move := (load("res://game/combat/moves/dummy_jab.tres") as MoveData).duplicate() as MoveData
	move.tier = tier
	if startup >= 0:
		move.startup = startup
	return move


func test_p_or_k_pressed_during_blockstun_attacks_right_after_it() -> void:
	# A P (or K) pressed on any frame of a blockstun, light or heavy, is never lost and
	# never strands the player: the guard stays up through the stun, then drops, and the
	# attack starts block_attack_cancel_frames after the stun ends (the press waits outside
	# the parser's 8-frame buffer). Pressed after the stun, it attacks cancel frames later.
	var cancel := Tuning.data.block_attack_cancel_frames
	var cases: Array[Array] = [
		[null, Tuning.data.blockstun_light_frames],
		[_jab_variant(CombatTypes.HitTier.HEAVY), Tuning.data.blockstun_heavy_frames],
	]
	for case: Array in cases:
		var move: MoveData = case[0]
		var stun: int = case[1]
		var hitstop := roundi(Tuning.data.block_hitstop_ms / 1000.0 * 60.0)
		for offset: int in range(0, hitstop + stun + 3):
			var button := &"K" if offset % 5 == 4 else &"P"
			var label := "%s blockstun, %s %d frames after the block" % [
				"heavy" if move else "light", button, offset]
			var dummy := await _partner()
			await _raise_guard()
			var hit := await _jab_lands(dummy, move)
			if hit == null or not hit.blocked:
				fail_test("%s: the jab was not blocked" % label)
				return
			await _ticks(offset)
			var in_stun := player.state == CombatTypes.ActorState.BLOCKSTUN
			player.input.push_press(button, 2)
			var states: Array[int] = []
			var ok := await _wait_until(
				func() -> bool:
					states.append(player.state)
					return player.state == CombatTypes.ActorState.ATTACK,
				60)
			assert_true(ok, "%s: the attack starts" % label)
			if not ok:
				return
			assert_eq(player.current_move.id, &"front_kick" if button == &"K" else &"jab_1", label)
			states.pop_back()
			var guarded := states.all(func(s: int) -> bool:
				return s == CombatTypes.ActorState.BLOCKSTUN or s == CombatTypes.ActorState.BLOCK)
			assert_true(guarded, "%s: guarding until it does (%s)" % [label, states])
			if in_stun and player.state_frame == 0:
				assert_eq(states.count(CombatTypes.ActorState.BLOCK), cancel,
						"%s: %d frames after the stun" % [label, cancel])
			player.input.push_up(&"DODGE")
			await _drain()


func test_holding_b_raises_the_guard_again_after_an_interruption() -> void:
	# Game-boy's "holding B keeps the block": back to FREE with B still held (after a flank
	# hit, a knockdown and get-up), the guard comes back up, raise frames and all. A guard
	# re-raised that way never parries (that takes a fresh press). B pressed with a stick
	# direction and held is a dodge, not a block.
	var dummy := await _partner()
	await _raise_guard()
	player.look_yaw = wrapf(player.look_yaw + PI * 0.5, -PI, PI)
	var hit := await _jab_lands(dummy)
	assert_true(hit != null and not hit.blocked, "the flank jab lands")
	assert_true(await _wait_until(func() -> bool: return player.state != CombatTypes.ActorState.HITSTUN, 40))
	assert_eq(player.state, CombatTypes.ActorState.BLOCK, "after the flinch the guard is up again")
	assert_false(player.is_guard_effective(), "rising (raise frames count again)")
	await _ticks(Tuning.data.block_raise_frames)
	assert_true(player.is_guard_effective())
	# A guard re-raised that way does not parry: knocked out of it by an unblockable jab from
	# the front, B still held, a quick jab landing inside the perfect-block window of the
	# re-raised guard is an ordinary block (after a fresh press it would be perfect).
	player.look_yaw = wrapf(player.look_yaw - PI * 0.5, -PI, PI)
	assert_true(await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.FREE, 40))
	_restage(dummy)
	var through := _jab_variant(CombatTypes.HitTier.LIGHT)
	through.unblockable = true
	hit = await _jab_lands(dummy, through)
	assert_true(hit != null and not hit.blocked, "knocked out of the guard")
	dummy.reset_state()
	assert_true(await _wait_until(func() -> bool: return player.state == CombatTypes.ActorState.BLOCK, 40))
	var raised := Engine.get_physics_frames()
	await _ticks(Tuning.data.block_raise_frames)
	var quick := _jab_variant(CombatTypes.HitTier.LIGHT, 2)
	hit = await _jab_lands(dummy, quick)
	assert_true(hit != null and hit.blocked, "blocked from the front")
	if hit:
		assert_lte(hit.physics_frame - raised, Tuning.data.block_raise_frames + Tuning.data.perfect_block_window_frames,
				"landing inside the perfect-block window")
		assert_false(hit.perfect_block, "a re-raised guard does not parry")
	player.input.push_up(&"DODGE")
	await _drain()
	# Knocked down through the guard (unblockable): up again, still holding B, it blocks.
	dummy = await _partner()
	await _raise_guard()
	var sweep := _jab_variant(CombatTypes.HitTier.HEAVY)
	sweep.unblockable = true
	sweep.reaction = CombatTypes.Reaction.KNOCKDOWN
	sweep.knockback = Vector3(0.0, 2.0, 3.0)
	hit = await _jab_lands(dummy, sweep)
	assert_true(hit != null and not hit.blocked)
	var downs: Array[int] = []
	assert_true(await _wait_until(
		func() -> bool:
			if downs.is_empty() or downs.back() != player.state:
				downs.append(player.state)
			return player.state == CombatTypes.ActorState.BLOCK,
		300), "back up in the guard")
	assert_true(downs.has(CombatTypes.ActorState.DOWNED) and downs.has(CombatTypes.ActorState.GETUP),
			"after the knockdown and the get-up (%s)" % [downs])
	player.input.push_up(&"DODGE")
	await _drain()
	# B + a stick direction, held: a dodge, and no guard after it.
	await _setup([])
	player.input.scripted_move = Vector2(1, 0)
	player.input.push_down(&"DODGE")
	await _drain()
	player.input.scripted_move = Vector2.ZERO
	assert_eq(player.state, CombatTypes.ActorState.DODGE)
	assert_true(await _wait_until(func() -> bool: return player.state == CombatTypes.ActorState.FREE, 40))
	await _ticks(10)
	assert_eq(player.state, CombatTypes.ActorState.FREE, "a held dodge press does not block")
	player.input.push_up(&"DODGE")
	await _drain()


func test_jump_and_grab_pressed_in_the_guard_are_dropped() -> void:
	# No jump and LB ignored while the guard is up: the presses are dropped, not buffered,
	# so letting go of B right after does not jump or grab. (LB after the release grabs.)
	var dummy := await _partner()
	await _raise_guard()
	dummy.release_from_grab(Vector3.ZERO, true)
	assert_true(dummy.can_be_grabbed(), "a staggered dummy in grab range")
	for button: StringName in [&"JUMP", &"GRAB"]:
		dummy.release_from_grab(Vector3.ZERO, true)
		player.input.push_press(button, 2)
		player.input.push_wait(1)
		player.input.push_up(&"DODGE")
		var seen: Array[int] = []
		for i in 20:
			await _ticks(1)
			seen.append(player.state)
		assert_false(seen.has(CombatTypes.ActorState.AIRBORNE) or seen.has(CombatTypes.ActorState.GRABBING),
				"%s in the guard, then B let go: nothing (%s)" % [button, seen])
		assert_eq(player.state, CombatTypes.ActorState.FREE)
		player.input.push_down(&"DODGE")
		await _drain()
		await _ticks(6)
	dummy.release_from_grab(Vector3.ZERO, true)
	player.input.push_up(&"DODGE")
	player.input.push_press(&"GRAB", 2)
	await _drain()
	assert_true(await _wait_until(func() -> bool: return player.state == CombatTypes.ActorState.GRABBING, 20),
			"LB once the guard is dropping grabs")


func test_letting_go_of_b_while_paused_still_drops_the_guard() -> void:
	# Live input: a release the player never polled (let go during the pause) is caught when
	# the game resumes, so the guard cannot stick.
	await _setup([])
	player.input.scripted = false
	Input.action_press(&"dodge")
	assert_true(await _wait_until(func() -> bool: return player.state == CombatTypes.ActorState.BLOCK, 10), "B blocks")
	GameInput.set_paused(true)
	await _ticks(3)
	Input.action_release(&"dodge")
	await _ticks(3)
	GameInput.set_paused(false)
	var dropped := await _wait_until(func() -> bool: return player.state == CombatTypes.ActorState.FREE, 20)
	assert_true(dropped, "the guard drops after the pause")
	assert_false(player.parser.is_held(&"DODGE"))
	# The same for a P held (charging the haymaker) through a pause.
	Input.action_press(&"punch")
	await _ticks(2)
	GameInput.set_paused(true)
	await _ticks(2)
	Input.action_release(&"punch")
	GameInput.set_paused(false)
	await _ticks(3)
	assert_false(player.parser.is_held(CombatTypes.IN_PUNCH), "P released too")
	player.input.scripted = true
	assert_true(await _wait_idle())


func test_a_jab_landing_on_the_player_never_fills_the_lens() -> void:
	# A strike that lands clean, or breaks the guard, on the first-person player is pulled
	# back into the stance once its hitstop is over: the dummy's fist, which reached the
	# face, never retracts through the throat-height lens (it used to fill the upper view
	# as a dark slab for about five frames).
	for case: String in ["clean", "guard break"]:
		var dummy := await _partner()
		if case == "guard break":
			await _raise_guard()
			player.guard = 10.0
		# The dummy's right glove (PlaceholderBody._gloved_hand()).
		var glove := func(m: MeshInstance3D) -> bool: return m.name in [&"RightFist", &"RightFingers", &"RightStrap"]
		var arm := func(m: MeshInstance3D) -> bool: return String(m.name).begins_with("Right")
		var hit := await _jab_lands(dummy)
		assert_not_null(hit, case)
		if hit == null:
			continue
		assert_eq(hit.guard_broken, case == "guard break", case)
		# From the first sim frame after the hit's hitstop (the contact pose holds through it).
		var widest := 0.0
		var nearest := INF
		var watched := 0
		for i in 30:
			if dummy.current_move == null or dummy.move_frame > hit.move_frame:
				var cam := FPView.camera(player.get_eye_transform().origin, player.get_look_basis())
				widest = maxf(widest, FPView.share(FPView.hits(dummy.rig, cam, 32), glove))
				nearest = minf(nearest, FPView.nearest_mesh(dummy.rig, cam.origin, arm))
				watched += 1
			await _ticks(1)
		assert_gt(watched, 20, "%s: frames watched" % case)
		assert_lt(widest, 0.12, "%s: the glove covers at most %.0f%% of the view" % [case, widest * 100.0])
		assert_gt(nearest, 0.3, "%s: the striking arm stays %.2f m or more from the lens" % [case, nearest])
		assert_true(await _wait_until(func() -> bool: return dummy.current_move == null, 40))


func test_sparring_dummy_steps_in_and_jabs_every_interval_from_start_to_start() -> void:
	# Holding B in front of a sparring dummy blocks jab after jab: it walks in (facing the
	# player) to sparring_step_in_m, inside its jab's reach, before each wind-up, so the
	# blocked jab's push-back never makes the next one whiff; and the interval runs from one
	# jab's start to the next (with the seeded jitter), not from its recovery.
	var starts: Array[Array] = []
	var on_start := func(actor: Node3D, _move: MoveData) -> void:
		starts.append([Engine.get_physics_frames(), player.global_position.distance_to(actor.global_position)])
	CombatEvents.windup_started.connect(on_start)
	await _setup([Vector3(0, 0, -1.5)], false, NAN, [0])
	var dummy := dummies[0]
	await _raise_guard(2)
	await _ticks(roundi((Tuning.data.sparring_interval_s + Tuning.data.sparring_jitter_s) * 60.0) * 6)
	CombatEvents.windup_started.disconnect(on_start)
	assert_gte(starts.size(), 6, "jab after jab")
	var taken := _player_hits_taken()
	assert_gte(taken.size(), starts.size() - 1, "every jab connects")
	assert_true(taken.all(func(h: HitInfo) -> bool: return h.blocked), "every one blocked")
	var low := roundi((Tuning.data.sparring_interval_s - Tuning.data.sparring_jitter_s) * 60.0)
	var high := roundi((Tuning.data.sparring_interval_s + Tuning.data.sparring_jitter_s) * 60.0)
	for i in starts.size():
		assert_lt(starts[i][1], Tuning.data.sparring_step_in_m + 0.05, "jab %d thrown from %.2f m" % [i + 1, starts[i][1]])
		if i > 0:
			assert_between(starts[i][0] - starts[i - 1][0], low - 1, high + 1, "jab %d starts an interval after the last" % (i + 1))
	assert_gt(player.global_position.distance_to(dummy._home), 0.3, "the dummy left its post to follow")
	player.input.push_up(&"DODGE")


# --- Grab anytime (Game-boy's second playtest, a Spec §4 change) ---------------------


func test_lb_grabs_an_idle_dummy() -> void:
	await _setup([Vector3(0, 0, -1.0)])
	assert_eq(dummies[0].state, CombatTypes.ActorState.FREE)
	await _press(&"GRAB", 2, 4)
	assert_eq(player.state, CombatTypes.ActorState.GRABBING, "grabbed a dummy just standing there")
	assert_eq(dummies[0].state, CombatTypes.ActorState.GRABBED)
	await _press(&"P", 2)
	assert_true(await _wait_idle())
	assert_eq(_ids(_player_hits()), [&"knee"], "and kneed it")


func test_lb_grabs_out_of_a_wind_up_but_whiffs_in_the_active_frames() -> void:
	var interrupted: Array[bool] = []
	var on_end := func(_actor: Node3D, was_interrupted: bool) -> void:
		interrupted.append(was_interrupted)
	CombatEvents.windup_ended.connect(on_end)
	var dummy := await _partner()
	dummy.start_jab()
	assert_true(await _wait_until(func() -> bool: return dummy.move_frame >= 8, 20))
	assert_eq(dummy.state, CombatTypes.ActorState.WINDUP)
	await _press(&"GRAB", 2, 4)
	assert_eq(player.state, CombatTypes.ActorState.GRABBING, "grabbed out of the wind-up")
	assert_eq(dummy.state, CombatTypes.ActorState.GRABBED)
	assert_eq(interrupted, [true], "the wind-up ended, interrupted")
	assert_eq(_player_hits_taken().size(), 0, "the jab never came out")
	CombatEvents.windup_ended.disconnect(on_end)
	# Turned 90 degrees away, its jab misses the player, who presses LB on its first active
	# frame (read the frame after): no grab while the fist is out.
	dummy = await _partner()
	dummy.rotation.y += PI * 0.5
	dummy.start_jab()
	assert_true(await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.ATTACK, 40))
	assert_false(dummy.can_be_grabbed(), "not grabbable in its active frames")
	await _press(&"GRAB", 2)
	assert_ne(player.state, CombatTypes.ActorState.GRABBING, "LB whiffs during the active frames")
	assert_ne(dummy.state, CombatTypes.ActorState.GRABBED)
	assert_eq(_player_hits_taken().size(), 0)
	# In its recovery it can be grabbed again.
	assert_true(await _wait_until(func() -> bool: return dummy.current_move != null and dummy.current_move.is_recovery(dummy.move_frame), 20))
	assert_true(dummy.can_be_grabbed(), "grabbable again in the recovery")


func test_downed_flying_and_ko_bodies_cannot_be_grabbed() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	for i in 3:
		player.input.push_press(&"K", 2)
		player.input.push_wait(10)
	await _drain()
	assert_true(await _wait_until(func() -> bool: return dummies[0].is_flying() or dummies[0].is_downed(), 60))
	assert_false(dummies[0].can_be_grabbed(), "a body knocked off its feet")
	assert_true(await _wait_until(func() -> bool: return dummies[0].is_downed(), 120))
	assert_false(dummies[0].can_be_grabbed(), "a downed body")


# --- Dodge with stick + B through the live input path (Game-boy's second playtest) ----


func _joy_axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _joy_button(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	event.shift_pressed = key == KEY_SHIFT and pressed
	Input.parse_input_event(event)


## Let go of every device input the live dodge tests use.
func _release_live_input() -> void:
	_joy_axis(JOY_AXIS_LEFT_X, 0.0)
	_joy_axis(JOY_AXIS_LEFT_Y, 0.0)
	_joy_button(JOY_BUTTON_B, false)
	_key(KEY_SHIFT, false)
	_key(KEY_D, false)
	for action: StringName in [&"dodge", &"move_left", &"move_right", &"move_back", &"move_forward"]:
		Input.action_release(action)


## One live-input case: `steps` is a list of [Callable, ticks to wait after it]. Returns
## DODGE if the player dodged at any point, else its state at the end and how far the player moved in its own frame (x right, y ahead).
func _live_case(steps: Array) -> Array:
	await _setup([])
	player.input.scripted = false
	var start := player.global_position
	# A dodge seen at any point wins (a guard turned into a dodge), else the last state.
	var state := -1
	for step: Array in steps:
		(step[0] as Callable).call()
		for i: int in step[1]:
			await get_tree().physics_frame
			if state != CombatTypes.ActorState.DODGE:
				state = player.state
	_release_live_input()
	assert_true(await _wait_until(func() -> bool: return player.state == CombatTypes.ActorState.FREE, 60))
	var moved := player.global_basis.inverse() * (player.global_position - start)
	player.input.scripted = true
	return [state, Vector2(moved.x, -moved.z)]


func test_stick_and_b_dodge_through_the_live_input_path() -> void:
	var dodge := CombatTypes.ActorState.DODGE
	var block := CombatTypes.ActorState.BLOCK
	var cases := [
		# [name, steps, expected state, expected direction or ZERO]
		["stick left, then B", [[_joy_axis.bind(JOY_AXIS_LEFT_X, -1.0), 3], [_joy_button.bind(JOY_BUTTON_B, true), 2]], dodge, Vector2.LEFT],
		["stick back, then B (backstep)", [[_joy_axis.bind(JOY_AXIS_LEFT_Y, 1.0), 3], [_joy_button.bind(JOY_BUTTON_B, true), 2]], dodge, Vector2(0, -1)],
		["B and the stick in the same frame", [[func() -> void:
			_joy_button(JOY_BUTTON_B, true)
			_joy_axis(JOY_AXIS_LEFT_X, 1.0), 3]], dodge, Vector2.RIGHT],
		["B a few frames before the stick", [[_joy_button.bind(JOY_BUTTON_B, true), 4], [_joy_axis.bind(JOY_AXIS_LEFT_X, 1.0), 3]], dodge, Vector2.RIGHT],
		["B, the stick well after: a guard walked in", [[_joy_button.bind(JOY_BUTTON_B, true), 20], [_joy_axis.bind(JOY_AXIS_LEFT_X, 1.0), 6]], block, Vector2.ZERO],
		["B alone blocks", [[_joy_button.bind(JOY_BUTTON_B, true), 6]], block, Vector2.ZERO],
		["D, then Shift", [[_key.bind(KEY_D, true), 3], [_key.bind(KEY_SHIFT, true), 2]], dodge, Vector2.RIGHT],
		["Shift, then D", [[_key.bind(KEY_SHIFT, true), 2], [_key.bind(KEY_D, true), 3]], dodge, Vector2.RIGHT],
		["action_press: move right, dodge", [[Input.action_press.bind(&"move_right", 1.0), 3], [Input.action_press.bind(&"dodge", 1.0), 2]], dodge, Vector2.RIGHT],
	]
	for case: Array in cases:
		var result: Array = await _live_case(case[1])
		var name: String = case[0]
		assert_eq(result[0], case[2], "%s: %s" % [name, CombatTypes.state_name(case[2])])
		var moved: Vector2 = result[1]
		if case[3] == Vector2.ZERO:
			assert_lt(moved.length(), 0.8, "%s: no dodge (moved %s)" % [name, moved])
		else:
			assert_gt(moved.length(), Tuning.data.dodge_distance - 0.3, "%s: a full dodge (moved %s)" % [name, moved])
			assert_gt(moved.normalized().dot(case[3]), 0.9, "%s: that way (moved %s)" % [name, moved])


func test_a_guard_that_stopped_a_hit_never_turns_into_a_dodge() -> void:
	var dummy := await _partner()
	dummy.start_jab()
	var startup := dummy.current_move.startup
	assert_true(await _wait_until(func() -> bool: return dummy.move_frame >= startup - 3, 40))
	player.input.scripted_move = Vector2.ZERO
	player.input.push_down(&"DODGE")
	assert_true(await _wait_until(func() -> bool: return not _player_hits_taken().is_empty(), 20))
	assert_true(_player_hits_taken()[0].blocked)
	player.input.scripted_move = Vector2(1, 0)
	await _ticks(4)
	assert_true(player.is_guarding(), "the stick after a parry walks in the guard, no dodge")
	player.input.scripted_move = Vector2.ZERO
	player.input.push_up(&"DODGE")
	assert_true(await _wait_idle())


# --- The first-person view turns with spins and the back elbow (presentation only) ---


## The first-person camera's yaw relative to the player's look, in degrees (left positive).
func _view_turn_deg(cam: FirstPersonCamera) -> float:
	var forward := cam.view_transform().basis * Vector3.FORWARD
	return rad_to_deg(wrapf(atan2(-forward.x, -forward.z) - player.look_yaw, -PI, PI))


## Runs frames until the player is idle, following the first-person view's turn as each
## frame shows it (after the camera's _process; `each_frame` is called then too):
## [total turn (unwrapped, degrees), largest turn in one frame, largest turn back against
## the total's direction, the turn at the end, every frame's turn].
func _follow_view_turn(cam: FirstPersonCamera, each_frame: Callable = Callable()) -> Array:
	var last := _view_turn_deg(cam)
	var total := 0.0
	var widest := 0.0
	var turns: Array[float] = []
	var steps: Array[float] = []
	for i in 400:
		await get_tree().process_frame
		if each_frame.is_valid():
			each_frame.call()
		var now := _view_turn_deg(cam)
		var step := wrapf(now - last, -180.0, 180.0)
		last = now
		total += step
		steps.append(step)
		turns.append(now)
		widest = maxf(widest, absf(step))
		if (player.input.queued() == 0 and player.current_move == null and player.state == CombatTypes.ActorState.FREE
				and not TimeController.is_in_hitstop(player) and absf(now) < 0.01 and i > 20):
			break
	var back := 0.0
	for step in steps:
		if signf(step) != signf(total):
			back = maxf(back, absf(step))
	return [total, widest, back, last, turns]


func test_first_person_view_spins_with_the_spinning_heel_and_spin_kick_and_lands_on_the_heading() -> void:
	for spin: StringName in [&"spinning_heel", &"spin_kick"]:
		await _setup([Vector3(0, 0, -1.6), Vector3(0, 0, 1.4)], true)
		var cam := get_tree().get_first_node_in_group(&"camera_director").call(&"active_camera") as FirstPersonCamera
		assert_not_null(cam, "first person")
		var yaw := player.look_yaw
		if spin == &"spinning_heel":
			for i in 3:
				player.input.push_press(&"K", 2)
				player.input.push_wait(10)
		else:
			player.input.push_press(&"JUMP", 2)
			await _drain()
			assert_true(await _wait_until(func() -> bool: return player.sim_velocity.y < 1.0, 60))
			player.input.push_press(&"K", 2)
		var result: Array = await _follow_view_turn(cam)
		assert_has(_ids(_player_hits()), spin, "%s lands" % spin)
		gut.p("%s: the view turns %.0f degrees, at most %.1f per frame" % [spin, result[0], result[1]])
		assert_almost_eq(result[0], -360.0, 6.0, "%s: the view spins a full turn with the body" % spin)
		# 30 degrees a frame from idle; chained out of the roundhouse, the cross-fade from
		# its recovery adds a little at the start.
		assert_lt(result[1], 45.0, "%s: smoothly, at most 45 degrees a frame" % spin)
		assert_lt(result[2], 3.0, "%s: never turning back against the spin" % spin)
		assert_almost_eq(result[3], 0.0, 0.01, "%s: back on the heading" % spin)
		assert_almost_eq(player.look_yaw, yaw, 0.001, "%s: aim and body facing untouched" % spin)
	# Tuning.cam_spin_follow_mult 0 keeps the view on the look.
	Tuning.data.cam_spin_follow_mult = 0.0
	await _setup([Vector3(0, 0, -1.6)], true)
	var flat := get_tree().get_first_node_in_group(&"camera_director").call(&"active_camera") as FirstPersonCamera
	for i in 3:
		player.input.push_press(&"K", 2)
		player.input.push_wait(10)
	var off: Array = await _follow_view_turn(flat)
	assert_lt(absf(off[0]) + off[1], 1.0, "cam_spin_follow_mult 0: no turn")


func test_back_elbow_turns_the_view_over_the_shoulder_and_back() -> void:
	await _setup([Vector3(0, 0, 1.0)], true)
	var cam := get_tree().get_first_node_in_group(&"camera_director").call(&"active_camera") as FirstPersonCamera
	var elbow := load("res://game/combat/moves/back_elbow.tres") as MoveData
	var yaw := player.look_yaw
	# The dummy's chest, seen from the turned view, on the frames of the contact's hitstop
	# (the frozen moment the elbow connects).
	var contact: Array[Vector3] = []
	var at_contact := func() -> void:
		if not _player_hits().is_empty() and TimeController.is_in_hitstop(player):
			var local := cam.view_transform().affine_inverse() * dummies[0].get_chest_position()
			contact.append(Vector3(rad_to_deg(atan2(local.x, -local.z)), rad_to_deg(atan2(local.y, -local.z)), -local.z))
	player.input.push_press(&"RB", 2)
	var result: Array = await _follow_view_turn(cam, at_contact)
	assert_eq(_ids(_player_hits()), [&"back_elbow"])
	var turns: Array[float] = result[4]
	var deepest := 0.0
	var deepest_at := 0
	for i in turns.size():
		if turns[i] < deepest:
			deepest = turns[i]
			deepest_at = i
	assert_almost_eq(deepest, elbow.camera_yaw_deg, 1.0, "the view turns right, over the shoulder toward the elbow")
	for i in deepest_at:
		assert_lte(turns[i + 1], turns[i] + 0.01, "eased in: always turning further toward it")
	for i in range(deepest_at, turns.size() - 1):
		assert_gte(turns[i + 1], turns[i] - 0.01, "eased out: always turning back")
	assert_gt(turns.size() - deepest_at, elbow.recovery - elbow.camera_hold_frames, "the turn back takes the recovery")
	assert_almost_eq(result[3], 0.0, 0.01, "back on the look")
	assert_gt(contact.size(), 2, "the contact's hitstop lasts a few frames")
	var seen_frames := 0
	for seen: Vector3 in contact:
		if seen.z > 0.0 and absf(seen.x) < FPView.HALF_H_DEG - 5.0 and absf(seen.y) < FPView.HALF_V_DEG:
			seen_frames += 1
	assert_gte(seen_frames, contact.size() - 1, "the dummy behind is in the turned view while the elbow connects (%s)" % [contact])
	assert_almost_eq(player.look_yaw, yaw, 0.001, "aim unchanged")
	assert_almost_eq(player.rotation.y, yaw, 0.001, "body facing unchanged")


## Review finding: a turning move cancelled into another (the back elbow interrupts any
## recovery, its own included) made the view jump, or sweep almost a full turn the wrong
## way between two ticks (134 and 333 degrees). Each tick's turn, and the span the camera
## interpolates over, stay within the elbow's own ease-in, and the view ends on the look.
func test_chained_view_turns_never_jump_or_sweep_round() -> void:
	var started: Array[StringName] = []
	var on_start := func(attacker: Node3D, move: MoveData, _step: int, _timing: StringName) -> void:
		if attacker == player:
			started.append(move.id)
	CombatEvents.attack_started.connect(on_start)
	for first: StringName in [&"back_elbow", &"spinning_heel"]:
		await _setup([Vector3(0, 0, -1.6), Vector3(0, 0, 1.0)])
		started.clear()
		if first == &"back_elbow":
			player.input.push_press(&"RB", 2)
		else:
			for i in 3:
				player.input.push_press(&"K", 2)
				player.input.push_wait(10)
		# In the hold of the elbow's turn; late in the heel kick's spin, still unwrapped.
		var cancel_at := 9 if first == &"back_elbow" else 30
		var widest := 0.0
		var widest_span := 0.0
		var pressed := false
		for i in 300:
			await get_tree().physics_frame
			if not pressed and player.current_move and player.current_move.id == first and player.move_frame >= cancel_at:
				player.input.push_press(&"RB", 2)
				pressed = true
			var last := player.get_camera_view_yaw(0.0)
			var now := player.get_camera_view_yaw(1.0)
			widest = maxf(widest, absf(wrapf(now - last, -180.0, 180.0)))
			widest_span = maxf(widest_span, absf(now - last))
			if pressed and i > 20 and player.current_move == null and is_zero_approx(now):
				break
		assert_true(pressed, "%s: cancelled into the back elbow" % first)
		assert_eq(started.back() if not started.is_empty() else &"", &"back_elbow", "%s: the elbow came out (%s)" % [first, started])
		# The elbow's own 150-degree turn eases in over 5 frames, up to about 44 degrees a tick.
		assert_lt(widest, 50.0, "%s, then the back elbow: at most 50 degrees a tick (%.1f)" % [first, widest])
		assert_lt(widest_span, 50.0, "%s, then the back elbow: the camera interpolates over less than 50 degrees (%.1f)" % [first, widest_span])
		assert_almost_eq(player.get_camera_view_yaw(), 0.0, 0.01, "%s: back on the look" % first)
	CombatEvents.attack_started.disconnect(on_start)
