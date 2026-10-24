extends GutTest
## Milestone 2 WP4: the partial and full ragdoll (game/actors/ragdoll.gd, Spec §6 "Hit
## reactions"). A visual layer: hurtboxes, rig points and get_point_transform() keep the
## animation's FK while it runs; staggers give way and return; bodies knocked off their feet
## fly, land, come to rest and get up where their hips lie; a KO goes limp and stays; the
## ragdoll runs in each actor's sim time (frozen in hitstop, slowed in slow-mo); a flying
## body still knocks a standing one down; the player keeps animated reactions by default;
## nothing explodes after many hits.

const ROOM := preload("res://game/level/test_room.tscn")
const FAR := Vector3(30.0, 0.0, -30.0)
## The visible bones whose gap to the animation's FK is measured during a full ragdoll.
const GAP_BONES: Array[StringName] = [&"Head", &"Chest", &"LeftHand", &"RightHand", &"LeftFoot", &"RightFoot"]

var room: Node3D
var player: PlayerCharacter
var dummies: Array[TrainingDummy] = []


func before_each() -> void:
	TimeController.clear()
	TimeController.debug_scale = 1.0
	Tuning.apply(TuningData.new())
	Tuning.data.dummy_health = 500.0


func after_each() -> void:
	TimeController.clear()
	TimeController.debug_scale = 1.0


# --- Harness ------------------------------------------------------------------------


## Build the room; `posts` are dummy positions relative to the player (x right, -z ahead).
func _setup(posts: Array[Vector3], yaw_deg: float = NAN, at: Vector3 = Vector3.INF) -> void:
	if is_instance_valid(room):
		room.queue_free()
		await _ticks(2)
	room = ROOM.instantiate()
	room.set(&"with_presentation", false)
	add_child_autofree(room)
	await _ticks(2)
	player = room.get(&"player")
	player.input.scripted = true
	if at != Vector3.INF:
		player.global_position = at
	if not is_nan(yaw_deg):
		player.look_yaw = deg_to_rad(yaw_deg)
		player.rotation.y = player.look_yaw
	dummies.assign(room.get(&"dummies"))
	for i in dummies.size():
		var pos := player.global_position + player.global_basis * posts[i] if i < posts.size() else FAR + Vector3(i * 3.0, 0.0, 0.0)
		var to_player := player.global_position - pos
		dummies[i].sparring = false
		dummies[i].set_post(pos, atan2(-to_player.x, -to_player.z), true)
	await _ticks(3)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Queue `count` presses of `button`, `gap` ticks apart (the player's combo cadence).
func _queue(button: StringName, count: int, gap: int = 8, hold: int = 2) -> void:
	for i in count:
		player.input.push_press(button, hold)
		player.input.push_wait(gap)


func _wait_until(condition: Callable, max_ticks: int = 400) -> bool:
	for i in max_ticks:
		if condition.call():
			return true
		await get_tree().physics_frame
	return false


## The largest distance between a visible bone and its animation-FK counterpart.
func _gap(d: CombatActor, bones: Array[StringName] = GAP_BONES) -> float:
	var worst := 0.0
	for bone: StringName in bones:
		worst = maxf(worst, d.rig.get_visual_point_transform(bone).origin.distance_to(d.rig.get_point_position(bone)))
	return worst


## A synthetic hit on `victim` (from the first dummy far away, or `attacker`).
func _hit(victim: CombatActor, reaction: CombatTypes.Reaction, knockback: Vector3,
		region: CombatTypes.Region = CombatTypes.Region.HEAD, attacker: CombatActor = null) -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = attacker if attacker else dummies[2]
	hit.victim = victim
	hit.damage = 1.0
	hit.tier = CombatTypes.HitTier.HEAVY
	hit.reaction = reaction
	hit.region = region
	hit.direction = Vector3(knockback.x, 0.0, knockback.z).normalized() if Vector2(knockback.x, knockback.z).length() > 0.01 else Vector3.FORWARD
	hit.knockback = knockback
	var point := &"Head" if region == CombatTypes.Region.HEAD else &"ChestPoint"
	hit.contact_point = victim.rig.get_point_position(point) - hit.direction * 0.15
	hit.physics_frame = Engine.get_physics_frames()
	return hit


## Every ragdoll body's transform is finite and no body is much faster than the cap (applied
## before each physics step; the joints may add a little within the step).
func _sane(d: CombatActor) -> bool:
	var ragdoll := d.rig.get_ragdoll()
	if ragdoll == null or not ragdoll.is_running():
		return true
	for xf: Transform3D in ragdoll.body_transforms():
		if not xf.is_finite():
			return false
	return ragdoll.max_body_speed() <= Tuning.data.ragdoll_max_speed * 1.25


# --- Tests --------------------------------------------------------------------------


func test_hurtboxes_and_rig_points_ignore_an_active_ragdoll() -> void:
	# The same uppercut launch with the ragdoll on and off: until the get-up (which moves
	# the body under the ragdoll's hips) the body, its rig points and its hurtboxes are
	# identical, frame for frame.
	var runs: Array[Array] = []
	for enabled: bool in [true, false]:
		Tuning.data.ragdoll_enabled = enabled
		await _setup([Vector3(0, 0, -1.6)])
		var dummy := dummies[0]
		_queue(&"P", 4)
		var frames: Array = []
		var ragdolled := false
		for i in 150:
			await get_tree().physics_frame
			if dummy.state == CombatTypes.ActorState.GETUP:
				break
			ragdolled = ragdolled or dummy.rig.is_ragdolling()
			var row: Array = [dummy.global_position, dummy.rig.get_point_transform(&"Head"),
					dummy.rig.get_point_transform(&"RightFistPoint")]
			for hurtbox: Hurtbox in dummy.rig.get_hurtboxes():
				row.append(hurtbox.global_transform)
			frames.append(row)
		assert_eq(ragdolled, enabled, "the dummy ragdolls only with the ragdoll on")
		runs.append(frames)
	assert_gt(runs[0].size(), 60, "watched the flight and the lying")
	assert_eq(runs[0].size(), runs[1].size(), "same timeline")
	var worst := 0.0
	for f in mini(runs[0].size(), runs[1].size()):
		for k in runs[0][f].size():
			var a: Variant = runs[0][f][k]
			var b: Variant = runs[1][f][k]
			if a is Vector3:
				worst = maxf(worst, (a as Vector3).distance_to(b as Vector3))
			else:
				worst = maxf(worst, (a as Transform3D).origin.distance_to((b as Transform3D).origin))
				worst = maxf(worst, ((a as Transform3D).basis.x - (b as Transform3D).basis.x).length())
	assert_lt(worst, 1e-5, "body, rig points and hurtboxes match the animation-only run (worst %.7f)" % worst)
	# And while it ran, the hurtboxes sat on the animation's FK, not on the visible body.
	Tuning.data.ragdoll_enabled = true


func test_a_staggered_upper_body_gives_way_and_returns_to_the_animation() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	_queue(&"P", 3)  # jab, jab, hook: the hook staggers
	assert_true(await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.STAGGER, 120), "staggered")
	assert_eq(dummy.rig.ragdoll_mode(), Ragdoll.Mode.PARTIAL, "a partial ragdoll")
	var upper := 0.0
	var legs := 0.0
	while dummy.state == CombatTypes.ActorState.STAGGER:
		await get_tree().physics_frame
		upper = maxf(upper, _gap(dummy, [&"Head", &"Chest", &"LeftHand", &"RightHand"]))
		legs = maxf(legs, _gap(dummy, [&"Hips", &"LeftFoot", &"RightFoot", &"LeftLowerLeg"]))
	gut.p("stagger: upper body gave way %.3f m, legs %.4f m" % [upper, legs])
	assert_gt(upper, 0.08, "the upper body visibly gives way")
	assert_lt(upper, 0.6, "but stays a stagger")
	assert_lt(legs, 0.002, "the hips and legs stay on the animation")
	await _ticks(2)
	assert_false(dummy.rig.is_ragdolling(), "faded back and stopped by the stagger's end")
	for bone: StringName in [&"Head", &"LeftHand", &"Hips"]:
		assert_almost_eq(dummy.rig.get_attachment(bone).global_position, dummy.rig.get_point_position(bone),
				Vector3.ONE * 1e-4, "%s shows the animation again" % bone)


func test_a_launched_dummy_ragdolls_rests_and_gets_up_where_its_hips_lie() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	_queue(&"P", 4)
	assert_true(await _wait_until(func() -> bool: return dummy.is_flying(), 150), "launched")
	assert_eq(dummy.rig.ragdoll_mode(), Ragdoll.Mode.FULL, "a full ragdoll")
	var ragdoll := dummy.rig.get_ragdoll()
	var flight_gap := 0.0
	var steady_gap := 0.0
	var lying_gap := 0.0
	var slept_at := -1
	var down_frames := 0
	while dummy.state != CombatTypes.ActorState.GETUP:
		await get_tree().physics_frame
		assert_true(_sane(dummy), "no NaN, no runaway")
		if dummy.is_flying():
			flight_gap = maxf(flight_gap, _gap(dummy))
			# Once the body has caught up with the launch (the animation snaps into its flying
			# pose in two frames; the bodies take a few tenths of a second to swing there).
			if dummy.state_frame > 12:
				steady_gap = maxf(steady_gap, _gap(dummy))
		elif dummy.is_downed():
			down_frames += 1
			# After the landing's first bounce: lying where its hurtboxes are.
			if down_frames > 20:
				lying_gap = maxf(lying_gap, _gap(dummy))
			if ragdoll.asleep and slept_at < 0:
				slept_at = down_frames
		if dummy.is_downed() and dummy.state_frame == Tuning.data.downed_frames - 1:
			break
	gut.p("full ragdoll gap to the animation: %.3f m flying (%.3f m once caught up), %.3f m lying; asleep %d frames after landing"
			% [flight_gap, steady_gap, lying_gap, slept_at])
	assert_lt(lying_gap, 0.3, "a downed body lies where its hurtboxes are")
	assert_lt(steady_gap, 0.5, "the flying body keeps with the sim body")
	assert_lt(flight_gap, 1.2, "even right after the launch")
	assert_between(slept_at, 1, roundi(Tuning.data.ragdoll_settle_max_s * 60.0) + 1, "comes to rest")
	# The frame before the get-up: where it will stand, and the body as it lies.
	var spot := dummy.global_position + dummy.rig.ragdoll_hips_offset()
	var lying_head := dummy.rig.get_attachment(&"Head").global_position
	assert_true(await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.GETUP, 5), "gets up")
	assert_almost_eq(dummy.rig.get_attachment(&"Head").global_position, lying_head, Vector3.ONE * 0.08,
			"the get-up starts from the pose the ragdoll lies in")
	assert_almost_eq(dummy.global_position, spot, Vector3.ONE * 2e-3, "stands where its ragdoll's hips lay")
	assert_false(dummy.rig.is_ragdolling(), "the get-up is animated")
	assert_true(_room_for(dummy), "with no overlap")
	assert_true(await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.FREE, 60), "stands")
	await _ticks(2)
	assert_almost_eq(dummy.rig.get_attachment(&"Head").global_position, dummy.rig.get_point_position(&"Head"),
			Vector3.ONE * 1e-4, "shows the animation")
	assert_gt(dummy.rig.get_point_position(&"Head").y - dummy.global_position.y, 1.5, "standing")


func test_a_ragdoll_thrown_against_a_wall_gets_up_clear_of_it() -> void:
	# The room's far buildings stand at z = -7 (street_width 14): the player faces them,
	# the dummy between, and the haymaker throws it at the wall.
	await _setup([Vector3(0, 0, -1.4)], 0.0, Vector3(0.0, 0.0, -4.4))
	var dummy := dummies[0]
	player.input.push_press(&"P", Tuning.data.hold_frames + 10)
	assert_true(await _wait_until(func() -> bool: return dummy.is_downed(), 200), "flew and landed")
	assert_true(await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.GETUP, 200), "gets up")
	assert_true(_room_for(dummy), "its body clear of the wall and other bodies")
	assert_lt(dummy.global_position.z, -5.5, "against the wall")


## No world or other body overlaps `d`'s capsule where it stands.
func _room_for(d: CombatActor) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = d.body_radius
	shape.height = d.body_height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = CombatTypes.bit(CombatTypes.LAYER_WORLD) | CombatTypes.bit(CombatTypes.LAYER_PLAYER_BODY) \
			| CombatTypes.bit(CombatTypes.LAYER_ENEMY_BODY) | CombatTypes.bit(CombatTypes.LAYER_DOWNED_BODY)
	query.exclude = [d.get_rid()]
	query.transform = Transform3D(Basis.IDENTITY, d.global_position + Vector3.UP * (d.body_height * 0.5 + 0.03))
	return d.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func test_a_kod_dummy_goes_limp_settles_and_stays() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	dummy.max_health = 30.0
	dummy.reset_state()
	dummy.health = 1.0
	_queue(&"P", 1)
	assert_true(await _wait_until(func() -> bool: return dummy.is_ko(), 200), "KO")
	var ragdoll := dummy.rig.get_ragdoll()
	assert_eq(dummy.rig.ragdoll_mode(), Ragdoll.Mode.FULL, "a full ragdoll")
	assert_eq(ragdoll.phase, Ragdoll.Phase.LIMP, "limp")
	assert_true(await _wait_until(func() -> bool: return ragdoll.asleep, roundi(Tuning.data.ragdoll_settle_max_s * 60.0) + 60), "settles")
	var pose: Array[Vector3] = []
	for bone: StringName in GAP_BONES:
		pose.append(dummy.rig.get_visual_point_transform(bone).origin)
	await _ticks(40)
	assert_true(dummy.is_ko(), "still KO'd")
	var moved := 0.0
	for i in GAP_BONES.size():
		moved = maxf(moved, dummy.rig.get_visual_point_transform(GAP_BONES[i]).origin.distance_to(pose[i]))
	assert_lt(moved, 1e-3, "stays where it settled")
	var lowest := INF
	for bone: StringName in GAP_BONES:
		lowest = minf(lowest, dummy.rig.get_visual_point_transform(bone).origin.y)
	assert_gt(lowest, -0.02, "nothing sinks into the floor")
	assert_lt(_gap(dummy, [&"Hips"]), 0.35, "lies at its body")


func test_the_ragdoll_freezes_in_hitstop_and_slows_in_slow_mo() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	# Launched by a synthetic hit with a hitstop, from standing still.
	var hit := _hit(dummy, CombatTypes.Reaction.LAUNCH, Vector3(0.0, 5.0, 4.0))
	assert_true(dummy.receive_hit(hit))
	TimeController.hitstop([dummy], 0.2)
	var ragdoll := dummy.rig.get_ragdoll()
	assert_not_null(ragdoll)
	await get_tree().physics_frame
	assert_true(TimeController.is_in_hitstop(dummy), "frozen")
	var frozen := ragdoll.body_transforms()
	var drift := 0.0
	while TimeController.is_in_hitstop(dummy):
		await get_tree().physics_frame
		var now := ragdoll.body_transforms()
		for k in now.size():
			drift = maxf(drift, now[k].origin.distance_to(frozen[k].origin))
	assert_lt(drift, 2e-3, "the ragdoll holds still through the actor's hitstop (%.5f m)" % drift)
	assert_eq(Engine.time_scale, 1.0, "Engine.time_scale stays 1")
	await _ticks(3)
	var moved := 0.0
	var after := ragdoll.body_transforms()
	for k in after.size():
		moved = maxf(moved, after[k].origin.distance_to(frozen[k].origin))
	assert_gt(moved, 0.05, "and flies once it ends (with the kick held till then)")
	# Slow-mo (the debug scale): the bodies' real speed drops to the scale, their sim speed
	# carries on, and the visible body stays with the slowed sim body.
	await _ticks(4)
	var hips_rid := ragdoll._bodies[0].get_rid()
	var sim_speed: float = (PhysicsServer3D.body_get_state(hips_rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY) as Vector3).length()
	TimeController.debug_scale = 0.25
	await _ticks(2)
	var real_speed: float = (PhysicsServer3D.body_get_state(hips_rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY) as Vector3).length()
	assert_almost_eq(real_speed / maxf(sim_speed, 1e-3), 0.25, 0.08, "real speed at the 0.25x scale")
	assert_almost_eq(ragdoll.max_body_speed() / maxf(sim_speed, 1e-3), 1.0, 0.5, "sim speed carries on")
	var slow_gap := 0.0
	for i in 24:
		await get_tree().physics_frame
		slow_gap = maxf(slow_gap, _gap(dummy, [&"Hips", &"Chest"]))
	assert_lt(slow_gap, 0.4, "the slowed ragdoll keeps with the slowed body")
	TimeController.debug_scale = 1.0


func test_a_flying_ragdolled_body_still_knocks_a_standing_dummy_down() -> void:
	await _setup([Vector3(0, 0, -1.5), Vector3(0.15, 0, -3.6)])
	var flyer := dummies[0]
	var standing := dummies[1]
	_queue(&"P", 2)
	_queue(&"K", 1)  # jab, jab, push kick
	assert_true(await _wait_until(func() -> bool: return flyer.is_flying(), 150), "the push kick sends it flying")
	assert_true(flyer.rig.is_ragdolling(), "ragdolled")
	assert_true(await _wait_until(func() -> bool: return standing.is_flying() or standing.is_downed(), 120),
			"the body it flies into goes down too")
	assert_eq(standing.rig.ragdoll_mode(), Ragdoll.Mode.FULL, "and ragdolls")


func test_the_player_keeps_animated_reactions_by_default() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	assert_false(Tuning.data.ragdoll_player, "off by default (Game-boy's call)")
	for reaction: CombatTypes.Reaction in [CombatTypes.Reaction.STAGGER, CombatTypes.Reaction.LAUNCH]:
		player.reset_state()
		await _ticks(2)
		assert_true(player.receive_hit(_hit(player, reaction, Vector3(0.0, 3.0, 3.0), CombatTypes.Region.HEAD, dummies[0])))
		await _ticks(10)
		assert_false(player.rig.is_ragdolling(), "%s: no ragdoll on the player" % CombatTypes.reaction_name(reaction))
	assert_null(player.rig.get_ragdoll(), "never even built")
	# The toggle turns it on.
	Tuning.data.ragdoll_player = true
	player.reset_state()
	await _ticks(2)
	assert_true(player.receive_hit(_hit(player, CombatTypes.Reaction.LAUNCH, Vector3(0.0, 3.0, 3.0), CombatTypes.Region.HEAD, dummies[0])))
	assert_true(player.rig.is_ragdolling(), "with Tuning.ragdoll_player it ragdolls")
	Tuning.data.ragdoll_player = false


func test_no_nan_or_runaway_after_many_hits_in_a_row() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	var reactions: Array[CombatTypes.Reaction] = [
		CombatTypes.Reaction.STAGGER, CombatTypes.Reaction.STAGGER, CombatTypes.Reaction.LAUNCH,
		CombatTypes.Reaction.GROUND, CombatTypes.Reaction.KNOCKDOWN,
	]
	var regions: Array[CombatTypes.Region] = [CombatTypes.Region.HEAD, CombatTypes.Region.TORSO, CombatTypes.Region.LEGS]
	for i in 60:
		var reaction := reactions[i % reactions.size()]
		if dummy.is_downed():
			reaction = CombatTypes.Reaction.GROUND
		var kb := Vector3(sin(i * 1.3) * 6.0, 2.0 + (i % 3) * 2.0, cos(i * 0.7) * 6.0)
		var hit := _hit(dummy, reaction, kb, regions[i % regions.size()])
		hit.reaction = reaction
		dummy.receive_hit(hit)
		dummy.reset_state() if i % 17 == 16 else null
		for t in 3:
			await get_tree().physics_frame
			assert_true(_sane(dummy), "sane after hit %d: speed %.2f finite %s state %s" % [i, dummy.rig.get_ragdoll().max_body_speed() if dummy.rig.get_ragdoll() else 0.0, dummy.rig.get_ragdoll().body_transforms().all(func(x: Transform3D) -> bool: return x.is_finite()) if dummy.rig.get_ragdoll() else true, CombatTypes.state_name(dummy.state)])
			assert_true(dummy.global_position.is_finite(), "the body stays finite")
	assert_true(await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.FREE, 400), "and recovers")


func test_bodies_are_built_once_and_cost_nothing_idle() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	assert_null(dummy.rig.get_ragdoll(), "nothing built before the first ragdoll")
	for round_i in 2:
		assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.STAGGER, Vector3(2.0, 0.0, 1.0))))
		assert_true(dummy.rig.is_ragdolling())
		await _wait_until(func() -> bool: return not dummy.rig.is_ragdolling(), 120)
		await _ticks(2)
	var ragdoll := dummy.rig.get_ragdoll()
	assert_eq(dummy.rig.skeleton.find_children("*", "PhysicalBone3D", true, false).size(),
			PlaceholderBody.ragdoll_specs().size(), "one body per ragdoll bone, built once")
	assert_false(ragdoll.simulator.active or ragdoll.active, "both modifiers inactive when idle")
	# A tuning edit (the F1 panel) re-reads the body tuning: idle bodies stay off every layer.
	Tuning.changed.emit(&"ragdoll_friction")
	for body: Node in dummy.rig.skeleton.find_children("*", "PhysicalBone3D", true, false):
		var rid := (body as PhysicalBone3D).get_rid()
		assert_eq(PhysicsServer3D.body_get_mode(rid), PhysicsServer3D.BODY_MODE_STATIC, "%s static" % body.name)
		assert_eq(PhysicsServer3D.body_get_collision_layer(rid), 0, "%s on no layer" % body.name)
	# Idle, the visuals are the animation's exactly.
	dummy.rig.advance(0.0)
	for bone: StringName in [&"Head", &"RightHand", &"LeftFoot"]:
		assert_eq(dummy.rig.get_attachment(bone).global_transform, dummy.rig.get_point_transform(bone),
				"%s: the follower is the animation FK, bit for bit" % bone)


func test_ragdoll_bodies_collide_with_the_world_and_ragdolls_only() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.LAUNCH, Vector3(0.0, 4.0, 3.0))))
	await _ticks(2)
	var allowed := CombatTypes.bit(CombatTypes.LAYER_WORLD) | CombatTypes.bit(CombatTypes.LAYER_RAGDOLL)
	for body: Node in dummy.rig.skeleton.find_children("*", "PhysicalBone3D", true, false):
		var rid := (body as PhysicalBone3D).get_rid()
		assert_eq(PhysicsServer3D.body_get_collision_layer(rid), CombatTypes.bit(CombatTypes.LAYER_RAGDOLL), "%s on the ragdoll layer" % body.name)
		assert_eq(PhysicsServer3D.body_get_collision_mask(rid) & ~allowed, 0, "%s sees the world and ragdolls only" % body.name)
	for actor: CombatActor in [player, dummy]:
		assert_eq(actor.collision_mask & CombatTypes.bit(CombatTypes.LAYER_RAGDOLL), 0, "%s's body never meets a ragdoll" % actor.name)


func test_grabbing_a_staggering_dummy_hands_back_to_the_animation_without_a_jump() -> void:
	await _setup([Vector3(0, 0, -1.1)])
	var dummy := dummies[0]
	assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.STAGGER, Vector3(2.0, 0.0, 1.0), CombatTypes.Region.HEAD, player)))
	await _ticks(8)
	assert_eq(dummy.rig.ragdoll_mode(), Ragdoll.Mode.PARTIAL)
	var shown := dummy.rig.get_attachment(&"Head").global_position
	dummy.start_grabbed(player)
	assert_false(dummy.rig.is_ragdolling(), "the grab ends the partial ragdoll")
	dummy.rig.advance(0.0)
	# (The fade keeps the rotations and the hips; the joints' few centimeters of stretch
	# under the springs are let go.)
	assert_almost_eq(dummy.rig.get_attachment(&"Head").global_position, shown, Vector3.ONE * 0.06,
			"the held pose fades in from the pose on screen")
	dummy.release_from_grab(Vector3.ZERO, false)
