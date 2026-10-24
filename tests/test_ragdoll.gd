extends GutTest
## Milestone 2 WP4: the partial and full ragdoll (game/actors/ragdoll.gd, Spec §6 "Hit
## reactions"). A visual layer: hurtboxes, rig points and get_point_transform() keep the
## animation's FK while it runs; staggers give way and return; bodies knocked off their feet
## fly, land, come to rest and get up where their hips lie; a KO goes limp and stays; the
## ragdoll runs in each actor's sim time (frozen in hitstop, slowed in slow-mo); a flying
## body still knocks a standing one down; the player keeps animated reactions by default;
## nothing explodes after many hits. The review fixes (docs/reviews/M2-WP4-review-findings.json)
## add: the hit's kick held through the hitstop, a get-up with no pop or shove, face-down
## landings, joints inside their limits, re-staggers, rest, idle cost, the parry and the
## launch's first frames.

const ROOM := preload("res://game/level/test_room.tscn")
const FAR := Vector3(30.0, 0.0, -30.0)
## The visible bones whose gap to the animation's FK is measured during a full ragdoll.
const GAP_BONES: Array[StringName] = [&"Head", &"Chest", &"LeftHand", &"RightHand", &"LeftFoot", &"RightFoot"]
## The bones a lying body's hurtboxes ride (head, torso, legs): lying, the drawn body stays
## on them. The arms, which carry none, lie looser (HANDS).
const HURT_BONES: Array[StringName] = [&"Head", &"Chest", &"Hips", &"LeftLowerLeg", &"RightLowerLeg", &"LeftFoot", &"RightFoot"]
const HANDS: Array[StringName] = [&"LeftHand", &"RightHand"]

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
	var lying_hands := 0.0
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
				lying_gap = maxf(lying_gap, _gap(dummy, HURT_BONES))
				lying_hands = maxf(lying_hands, _gap(dummy, HANDS))
			if ragdoll.asleep and slept_at < 0:
				slept_at = down_frames
		if dummy.is_downed() and dummy.state_frame == Tuning.data.downed_frames - 1:
			break
	gut.p("full ragdoll gap to the animation: %.3f m flying (%.3f m once caught up), %.3f m lying (hands %.3f m); asleep %d frames after landing"
			% [flight_gap, steady_gap, lying_gap, lying_hands, slept_at])
	assert_lt(lying_gap, 0.2, "a downed body lies where its hurtboxes are")
	assert_lt(lying_hands, 0.7, "its arms lying near where the animation has them")
	assert_lt(steady_gap, 0.5, "the flying body keeps with the sim body")
	assert_lt(flight_gap, 0.8, "even right after the launch")
	assert_between(slept_at, 1, roundi(Tuning.data.ragdoll_settle_max_s * 60.0) - 1,
			"comes to rest, by being at rest (before the settle cap)")
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
	# Launched by a synthetic hit with a hitstop, from standing still: the reference is the
	# pose the ragdoll starts from, before any physics step (the hit's frame included).
	var hit := _hit(dummy, CombatTypes.Reaction.LAUNCH, Vector3(0.0, 5.0, 4.0))
	assert_true(dummy.receive_hit(hit))
	TimeController.hitstop([dummy], 0.2)
	var ragdoll := dummy.rig.get_ragdoll()
	assert_not_null(ragdoll)
	var frozen := ragdoll.body_transforms()
	var head_v := ragdoll.body_sim_velocity(&"Head")
	assert_eq(ragdoll.pending_kicks(), 1, "the hit's kick waits")
	var drift := 0.0
	var frames := 0
	while frames == 0 or TimeController.is_in_hitstop(dummy):
		await get_tree().physics_frame
		frames += 1
		var now := ragdoll.body_transforms()
		for k in now.size():
			drift = maxf(drift, now[k].origin.distance_to(frozen[k].origin))
		if TimeController.is_in_hitstop(dummy):
			assert_eq(ragdoll.pending_kicks(), 1, "the kick is held through the freeze")
			assert_almost_eq(ragdoll.body_sim_velocity(&"Head"), head_v, Vector3.ONE * 1e-3,
					"the struck head keeps its velocity, kick not yet in")
	assert_gt(frames, 10, "watched the whole hitstop")
	assert_lt(drift, 2e-3, "the ragdoll holds still from the hit's frame through the hitstop (%.5f m)" % drift)
	assert_eq(Engine.time_scale, 1.0, "Engine.time_scale stays 1")
	await get_tree().physics_frame
	assert_eq(ragdoll.pending_kicks(), 0, "the kick lands on the first step after the hitstop")
	var kicked := (ragdoll.body_sim_velocity(&"Head") - head_v).length()
	assert_gt(kicked, 0.5 * hit.knockback.length() * Tuning.data.ragdoll_full_impulse,
			"the struck head took the kick then (%.2f m/s)" % kicked)
	await _ticks(2)
	var moved := 0.0
	var after := ragdoll.body_transforms()
	for k in after.size():
		moved = maxf(moved, after[k].origin.distance_to(frozen[k].origin))
	assert_gt(moved, 0.05, "and flies once it ends")
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


# --- Review fixes (docs/reviews/M2-WP4-review-findings.json) -------------------------


## Largest amount (degrees) any drawn joint is past its PlaceholderBody.ragdoll_specs()
## limit: a cone's swing of the bone's axis from its center in the parent's frame, a hinge's
## bend about X.
func _joint_excess(d: CombatActor) -> float:
	var worst := 0.0
	for spec: PlaceholderBody.RagdollSpec in PlaceholderBody.ragdoll_specs():
		if spec.bone == &"Hips":
			continue
		var parent: StringName = PlaceholderBody.BONE_PARENT[spec.bone]
		var pb := d.rig.get_attachment(parent).global_basis.orthonormalized()
		var cb := d.rig.get_attachment(spec.bone).global_basis.orthonormalized()
		if spec.joint == PlaceholderBody.RagdollJoint.CONE:
			worst = maxf(worst, rad_to_deg((pb * spec.center).angle_to(cb * spec.axis)) - spec.swing_deg)
		else:
			var bend := rad_to_deg((pb.inverse() * cb).get_euler().x)
			worst = maxf(worst, maxf(spec.lower_deg - bend, bend - spec.upper_deg))
	return worst


## Turn dummy `d` to face away from the player (it stops turning toward it).
func _face_away(d: TrainingDummy) -> void:
	d.face_player = false
	d.set_post(d.global_position, d.rotation.y + PI, true)
	await _ticks(3)


func test_the_get_up_fade_starts_where_the_ragdoll_lies_after_the_body_moves_under_it() -> void:
	# Just before the get-up the sim body is moved 0.45 m away from where its ragdoll lies
	# (woken, so it shows where its bodies are): the get-up moves the body back under the
	# ragdoll's hips, and the visible body must not jump by that.
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	_queue(&"P", 4)
	assert_true(await _wait_until(func() -> bool:
		return dummy.is_downed() and dummy.state_frame >= Tuning.data.downed_frames - 4, 300), "lies")
	var ragdoll := dummy.rig.get_ragdoll()
	dummy.global_position += dummy.global_basis.x * 0.45
	ragdoll.hit(dummy.get_chest_position(), Vector3.ZERO)
	var before := dummy.global_position
	var lying_head := dummy.rig.get_attachment(&"Head").global_position
	for i in 20:
		if dummy.state == CombatTypes.ActorState.GETUP:
			break
		before = dummy.global_position
		lying_head = dummy.rig.get_attachment(&"Head").global_position
		await get_tree().physics_frame
	assert_eq(dummy.state, CombatTypes.ActorState.GETUP, "gets up")
	var moved := Vector2(dummy.global_position.x - before.x, dummy.global_position.z - before.z).length()
	var jump := dummy.rig.get_attachment(&"Head").global_position.distance_to(lying_head)
	gut.p("get-up: moved %.3f m under the ragdoll, drawn head jumped %.3f m" % [moved, jump])
	assert_gt(moved, 0.35, "the body moved back under its ragdoll's hips")
	assert_lt(jump, 0.02, "the drawn body stays where it lay on the get-up frame")
	# And it slides there no faster than Tuning.ragdoll_getup_slide_speed.
	var step := 0.0
	var last := dummy.rig.get_attachment(&"Hips").global_position
	for i in 20:
		await get_tree().physics_frame
		var now := dummy.rig.get_attachment(&"Hips").global_position
		step = maxf(step, Vector2(now.x - last.x, now.z - last.z).length())
		last = now
	assert_lt(step * 60.0, Tuning.data.ragdoll_getup_slide_speed * 1.6, "a slide, not a pop (%.2f m/s)" % (step * 60.0))


func test_a_stomped_ragdoll_gets_up_where_it_lies_with_the_player_over_it() -> void:
	# The stomp (K on a downed enemy) leaves the player standing over the body: like without
	# a ragdoll, it gets up where it lies, not shoved aside.
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	dummy.face_player = false
	_queue(&"P", 4)
	assert_true(await _wait_until(func() -> bool: return dummy.is_downed(), 200), "down")
	await _ticks(10)
	var chest := dummy.get_chest_position()
	var from_dir := player.global_position - chest
	from_dir.y = 0.0
	from_dir = from_dir.normalized()
	player.global_position = Vector3(chest.x, player.global_position.y, chest.z) + from_dir * 1.0
	player.look_yaw = atan2(from_dir.x, from_dir.z)
	player.rotation.y = player.look_yaw
	await _ticks(2)
	var stomps := [0]
	var on_hit := func(hit: HitInfo) -> void:
		if hit.victim == dummy and hit.reaction == CombatTypes.Reaction.GROUND:
			stomps[0] += 1
	CombatEvents.hit_landed.connect(on_hit)
	player.input.push_press(&"K", 2)
	var before := dummy.global_position
	var lying_head := dummy.rig.get_attachment(&"Head").global_position
	for i in 300:
		if dummy.state == CombatTypes.ActorState.GETUP:
			break
		before = dummy.global_position
		lying_head = dummy.rig.get_attachment(&"Head").global_position
		await get_tree().physics_frame
	assert_eq(dummy.state, CombatTypes.ActorState.GETUP, "gets up")
	CombatEvents.hit_landed.disconnect(on_hit)
	assert_eq(stomps[0], 1, "the stomp landed on the lying ragdoll")
	var moved := Vector2(dummy.global_position.x - before.x, dummy.global_position.z - before.z).length()
	assert_lt(moved, 0.1, "gets up where it lies (moved %.3f m)" % moved)
	assert_lt(dummy.rig.get_attachment(&"Head").global_position.distance_to(lying_head), 0.03, "no pop")


func test_two_bodies_that_fell_on_each_other_get_up_beside_each_other() -> void:
	# The push kick throws the first dummy onto the second (the flying-body knockdown): the
	# one lying on top gets up beside the other, clear of it, without a pop; the other gets
	# up about where it lies.
	await _setup([Vector3(0, 0, -1.5), Vector3(0.15, 0, -3.6)])
	_queue(&"P", 2)
	_queue(&"K", 1)
	var moved: Array[float] = [-1.0, -1.0]
	var jump: Array[float] = [0.0, 0.0]
	var clear: Array[bool] = [false, false]
	var on_top: Array[bool] = [false, false]
	var before: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var head: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	for i in 400:
		if moved[0] >= 0.0 and moved[1] >= 0.0:
			break
		for k in 2:
			before[k] = dummies[k].global_position
			head[k] = dummies[k].rig.get_attachment(&"Head").global_position
			if dummies[k].is_downed():
				# Lying on the other body: its drawn hips well above the animation's.
				on_top[k] = dummies[k].rig.get_attachment(&"Hips").global_position.y \
						- dummies[k].rig.get_point_position(&"Hips").y > 0.08
		var was: Array[CombatTypes.ActorState] = [dummies[0].state, dummies[1].state]
		await get_tree().physics_frame
		for k in 2:
			var d := dummies[k]
			if d.state == CombatTypes.ActorState.GETUP and was[k] != CombatTypes.ActorState.GETUP:
				moved[k] = Vector2(d.global_position.x - before[k].x, d.global_position.z - before[k].z).length()
				jump[k] = d.rig.get_attachment(&"Head").global_position.distance_to(head[k])
				clear[k] = _room_for(d)
	gut.p("pile: top %s, get-ups moved %.3f / %.3f m, drawn head jumped %.3f / %.3f m" % [on_top, moved[0], moved[1], jump[0], jump[1]])
	assert_true(on_top[0], "the kicked body lies on the other")
	assert_gt(moved[0], 0.4, "and gets up beside it")
	assert_lt(moved[0], Tuning.data.ragdoll_getup_aside_m + 0.3, "not far off")
	assert_true(clear[0], "clear of the body still lying there")
	assert_lt(moved[1], 0.2, "the one underneath gets up about where it lies")
	# (The get-up fade's first frame moves a body lying far from its animation pose, a leg up
	# on the other body, a few centimeters; a pop would be the whole relocation.)
	for k in 2:
		assert_lt(jump[k], 0.06, "dummy %d: no pop on the get-up frame" % k)
	assert_true(await _wait_until(func() -> bool:
		return dummies[0].state == CombatTypes.ActorState.FREE and dummies[1].state == CombatTypes.ActorState.FREE, 120), "both stand")
	var apart := Vector2(dummies[0].global_position.x - dummies[1].global_position.x,
			dummies[0].global_position.z - dummies[1].global_position.z).length()
	assert_gt(apart, dummies[0].body_radius * 2.0, "side by side, not inside each other (%.2f m)" % apart)


func test_the_health_bar_anchor_follows_the_visible_head() -> void:
	# EnemyHealthBars (and the debug label) sit above get_head_top_position(): on the body as
	# drawn while a ragdoll runs, so a bar never floats off a body lying on another or slides
	# across at its get-up; the animation's rig point otherwise.
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	assert_eq(dummy.get_head_top_position(), dummy.rig.get_point_position(&"HeadTopPoint"), "no ragdoll: the rig point")
	assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.LAUNCH, Vector3(0.0, 4.0, 3.0))))
	var apart := 0.0
	var off_drawn := 0.0
	for i in 40:
		await get_tree().physics_frame
		var drawn := dummy.rig.get_attachment(&"HeadTopPoint").global_position
		off_drawn = maxf(off_drawn, dummy.get_head_top_position().distance_to(drawn))
		apart = maxf(apart, dummy.get_head_top_position().distance_to(dummy.rig.get_point_position(&"HeadTopPoint")))
	assert_lt(off_drawn, 1e-3, "on the drawn head (%.4f m)" % off_drawn)
	assert_gt(apart, 0.05, "not on the animation's while the two differ (%.3f m)" % apart)


func test_a_body_launched_from_behind_lands_face_down_where_its_hurtboxes_are() -> void:
	for haymaker: bool in [false, true]:
		await _setup([Vector3(0, 0, -1.6)])
		var dummy := dummies[0]
		await _face_away(dummy)
		if haymaker:
			player.input.push_press(&"P", Tuning.data.hold_frames + 10)
		else:
			_queue(&"P", 4)
		assert_true(await _wait_until(func() -> bool: return dummy.is_downed(), 240), "down")
		assert_eq(dummy.rig.current_anim(), &"downed_front", "the animation lies face down")
		await _ticks(25)
		var lying := 0.0
		var hands := 0.0
		var excess := 0.0
		while dummy.is_downed():
			lying = maxf(lying, _gap(dummy, HURT_BONES))
			hands = maxf(hands, _gap(dummy, HANDS))
			excess = maxf(excess, _joint_excess(dummy))
			await get_tree().physics_frame
		gut.p("%s from behind: lying gap %.3f m (hands %.3f m), joints at most %.0f deg past a limit" % ["haymaker" if haymaker else "uppercut", lying, hands, excess])
		assert_lt(lying, 0.35, "face down where its hurtboxes are")
		assert_lt(hands, 0.9, "its arms near")
		assert_lt(excess, 10.0, "no limb bent past its joint lying there")


func test_drawn_joints_stay_inside_their_limits() -> void:
	# A transient overshoot on impact is let through (a few frames); a joint held past its
	# limit is not.
	var scenarios: Array[String] = ["uppercut", "haymaker", "throw"]
	for title: String in scenarios:
		await _setup([Vector3(0, 0, -1.1) if title == "throw" else Vector3(0, 0, -1.6)])
		var dummy := dummies[0]
		match title:
			"uppercut":
				_queue(&"P", 4)
			"haymaker":
				player.input.push_press(&"P", Tuning.data.hold_frames + 10)
			"throw":
				player.input.push_wait(10)
				player.input.push_press(&"GRAB", 2)
				player.input.push_wait(12)
				player.input.push_press(&"K", 2)
		var worst := 0.0
		var run := 0
		var longest := 0
		for i in 220:
			await get_tree().physics_frame
			if dummy.rig.ragdoll_mode() != Ragdoll.Mode.FULL:
				continue
			var excess := _joint_excess(dummy)
			worst = maxf(worst, excess)
			run = run + 1 if excess > 10.0 else 0
			longest = maxi(longest, run)
		gut.p("%s: joints at most %.0f deg past a limit, %d frames running more than 10" % [title, worst, longest])
		assert_lt(longest, 12, "%s: no joint held past its limit (a throw's whip lasts a few frames)" % title)
		assert_lt(worst, 20.0, "%s: nor far past it" % title)


func test_a_stagger_on_a_stagger_does_not_pop_the_upper_body() -> void:
	for wait: int in [6, 14, 22]:
		await _setup([Vector3(0, 0, -1.6)])
		var dummy := dummies[0]
		assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.STAGGER, Vector3(2.0, 0.0, 1.0))))
		await _ticks(wait)
		assert_eq(dummy.rig.ragdoll_mode(), Ragdoll.Mode.PARTIAL)
		var head := dummy.rig.get_attachment(&"Head").global_position
		var anim_head := dummy.rig.get_point_position(&"Head")
		# A second stagger with no push: nothing new should show but the animation's restart.
		assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.STAGGER, Vector3.ZERO)))
		var worst := 0.0
		for i in 3:
			await get_tree().physics_frame
			var now := dummy.rig.get_attachment(&"Head").global_position
			var anim_now := dummy.rig.get_point_position(&"Head")
			worst = maxf(worst, now.distance_to(head) - anim_now.distance_to(anim_head))
			head = now
			anim_head = anim_now
		assert_lt(worst, 0.045, "after %d frames: the drawn head moves no more than the animation's (%.3f m more)" % [wait, worst])


func test_a_lying_ragdoll_sleeps_once_it_is_still_and_wakes_when_hit() -> void:
	Tuning.data.ragdoll_settle_max_s = 3.0
	# Down long enough to sleep, be woken and sleep again before it gets up.
	Tuning.data.downed_frames = 300
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	_queue(&"P", 4)
	assert_true(await _wait_until(func() -> bool: return dummy.is_downed(), 200), "down")
	var ragdoll := dummy.rig.get_ragdoll()
	var frames := 0
	while not ragdoll.asleep and frames < 200:
		await get_tree().physics_frame
		frames += 1
	assert_true(ragdoll.asleep, "sleeps")
	assert_lt(frames / 60.0, 1.6, "at rest, long before the 3 s cap (%.2f s)" % (frames / 60.0))
	# A stomp-like hit wakes it; it settles again.
	ragdoll.hit(dummy.get_chest_position(), Vector3.DOWN * 2.0, Ragdoll.Part.TORSO)
	await _ticks(2)
	assert_false(ragdoll.asleep, "woken")
	assert_true(await _wait_until(func() -> bool: return ragdoll.asleep, 200), "settles again")


func test_a_partials_kinematic_hips_and_legs_stay_off_every_layer() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.STAGGER, Vector3(2.0, 0.0, 1.0))))
	await _ticks(4)
	for edit: bool in [false, true]:
		if edit:
			# A tuning edit (the F1 panel) mid-stagger.
			Tuning.changed.emit(&"ragdoll_friction")
			await _ticks(1)
		assert_eq(dummy.rig.ragdoll_mode(), Ragdoll.Mode.PARTIAL)
		for body: Node in dummy.rig.skeleton.find_children("*", "PhysicalBone3D", true, false):
			var bone := String((body as PhysicalBone3D).get(&"bone_name"))
			var rid := (body as PhysicalBone3D).get_rid()
			var layer := PhysicsServer3D.body_get_collision_layer(rid)
			if Ragdoll.PARTIAL_BONES.has(StringName(bone)):
				assert_eq(layer, CombatTypes.bit(CombatTypes.LAYER_RAGDOLL), "%s simulates on the ragdoll layer (edit %s)" % [bone, edit])
			else:
				assert_eq(layer, 0, "%s, kinematic, on no layer (edit %s)" % [bone, edit])
				assert_eq(PhysicsServer3D.body_get_collision_mask(rid), 0, "%s sees nothing (edit %s)" % [bone, edit])


func test_idle_bodies_ignore_the_actor_moving() -> void:
	# Decision 9: built bodies cost nothing idle, not even being moved with a walking actor.
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.STAGGER, Vector3(2.0, 0.0, 1.0))))
	assert_true(await _wait_until(func() -> bool: return not dummy.rig.is_ragdolling(), 120), "the stagger ends")
	var bodies := dummy.rig.skeleton.find_children("*", "PhysicalBone3D", true, false)
	var before: Array[Transform3D] = []
	for body: Node in bodies:
		before.append(PhysicsServer3D.body_get_state((body as PhysicalBone3D).get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM))
	for i in 10:
		dummy.global_position += Vector3(0.1, 0.0, 0.0)
		await get_tree().physics_frame
	for k in bodies.size():
		var now: Transform3D = PhysicsServer3D.body_get_state((bodies[k] as PhysicalBone3D).get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
		assert_eq(now, before[k], "%s stays put on the server" % bodies[k].name)
	# And a new ragdoll still starts from the pose on screen.
	assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.LAUNCH, Vector3(0.0, 4.0, 3.0))))
	await _ticks(1)
	assert_lt(_gap(dummy), 0.1, "starts on the body where it is now")


func test_a_ragdoll_taken_out_of_the_tree_and_back_keeps_its_joints() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.LAUNCH, Vector3(0.0, 4.0, 3.0))))
	await _ticks(5)
	var expected := PlaceholderBody.ragdoll_specs().size() - 1
	assert_eq(dummy.rig.get_ragdoll().joint_count(), expected, "every joint")
	var parent := dummy.get_parent()
	parent.remove_child(dummy)
	await _ticks(2)
	parent.add_child(dummy)
	await _ticks(2)
	dummy.reset_state()
	await _ticks(2)
	var ragdoll := dummy.rig.get_ragdoll()
	assert_eq(ragdoll.joint_count(), expected, "the joints are back")
	assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.LAUNCH, Vector3(0.0, 4.0, 3.0))))
	var stretch := 0.0
	for i in 40:
		await get_tree().physics_frame
		stretch = maxf(stretch, ragdoll.joint_stretch())
	gut.p("re-entered: joints stretched at most %.3f m" % stretch)
	# (A few centimeters on the landing's impact; without joints the bodies part by most of
	# a meter.)
	assert_lt(stretch, 0.1, "and hold the bodies together (%.3f m)" % stretch)


func test_a_parried_jab_knocks_the_attackers_arm_back_not_into_the_lens() -> void:
	# The sparring dummy's jab, perfect-blocked: its fists never come closer to the player's
	# eyes after the parry than without a ragdoll (the animation snaps the arm back).
	var closest: Array[float] = []
	for enabled: bool in [false, true]:
		Tuning.data.ragdoll_enabled = enabled
		await _setup([Vector3(0, 0, -0.95)])
		var dummy := dummies[0]
		await _ticks(10)
		dummy.start_jab()
		var startup := dummy.current_move.startup
		assert_true(await _wait_until(func() -> bool: return dummy.move_frame >= startup - 7, 40))
		player.input.push_down(&"DODGE")
		assert_true(await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.STAGGER, 30), "parried")
		assert_eq(dummy.rig.is_ragdolling(), enabled)
		var near := INF
		for i in 30:
			await get_tree().physics_frame
			var eye := player.rig.get_point_position(&"EyePoint")
			for fist: StringName in [&"LeftFistPoint", &"RightFistPoint"]:
				near = minf(near, dummy.rig.get_visual_point_transform(fist).origin.distance_to(eye))
		closest.append(near)
		player.input.push_up(&"DODGE")
		await _ticks(2)
	Tuning.data.ragdoll_enabled = true
	gut.p("parry: closest fist to the eyes %.3f m with the ragdoll, %.3f m without" % [closest[1], closest[0]])
	assert_gt(closest[1], closest[0] - 0.03, "the ragdoll never brings the fist closer to the lens")


func test_a_launch_shows_the_animations_snap_first() -> void:
	# The finisher's hitstop and slow-mo show the hit's pose: the FULL ragdoll rises in from
	# the animation (Tuning.ragdoll_full_rise_s), so the first frames are the animation's and
	# the bodies take over from there. From standing, and from a stagger (the uppercut that
	# ends P P P P lands on a body still in the hook's partial ragdoll).
	for from_stagger: bool in [false, true]:
		await _setup([Vector3(0, 0, -1.6)])
		var dummy := dummies[0]
		if from_stagger:
			assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.STAGGER, Vector3(2.0, 0.0, 2.0))))
			await _ticks(12)
			assert_eq(dummy.rig.ragdoll_mode(), Ragdoll.Mode.PARTIAL, "staggering")
			assert_gt(_gap(dummy), 0.03, "its upper body giving way")
		assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.LAUNCH, Vector3(0.0, 6.0, 3.0))))
		TimeController.hitstop([dummy], 0.1)
		var early := 0.0
		while TimeController.is_in_hitstop(dummy) or early == 0.0:
			await get_tree().physics_frame
			early = maxf(early, _gap(dummy) + 1e-6)
		assert_lt(early, 0.02, "through the hitstop the visible body is the animation's (%.3f m, from a stagger %s)" % [early, from_stagger])
		var rise := 0.0
		for i in 4:
			await get_tree().physics_frame
			rise = maxf(rise, _gap(dummy))
		assert_lt(rise, 0.2, "and the first frames after it stay close to it (%.3f m, from a stagger %s)" % [rise, from_stagger])
		assert_true(await _wait_until(func() -> bool: return dummy.rig.get_ragdoll().simulator.influence >= 1.0, 30),
				"then the ragdoll shows alone")


func test_a_staggering_release_from_a_grab_gives_way_too() -> void:
	await _setup([Vector3(0, 0, -1.1)])
	var dummy := dummies[0]
	dummy.start_grabbed(player)
	await _ticks(10)
	dummy.release_from_grab(Vector3(0.0, 0.0, 2.0), true)
	assert_eq(dummy.state, CombatTypes.ActorState.STAGGER)
	assert_eq(dummy.rig.ragdoll_mode(), Ragdoll.Mode.PARTIAL, "the partial ragdoll, like every stagger")
	assert_true(await _wait_until(func() -> bool: return not dummy.rig.is_ragdolling(), 120), "and fades out")


func test_bodies_use_continuous_collision_and_stay_out_of_the_floor() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	var dummy := dummies[0]
	assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.LAUNCH, Vector3(0.0, 9.0, 12.0))))
	for body: Node in dummy.rig.skeleton.find_children("*", "PhysicalBone3D", true, false):
		assert_true(PhysicsServer3D.body_is_continuous_collision_detection_enabled((body as PhysicalBone3D).get_rid()), "%s" % body.name)
	var lowest := INF
	var sunk := 0
	for i in 120:
		await get_tree().physics_frame
		var frame_lowest := INF
		for bone: StringName in GAP_BONES:
			frame_lowest = minf(frame_lowest, dummy.rig.get_visual_point_transform(bone).origin.y)
		lowest = minf(lowest, frame_lowest)
		sunk += 1 if frame_lowest < -0.03 else 0
	# (A foot slammed in at 15 m/s may show a few centimeters in for the one frame of impact.)
	assert_lte(sunk, 1, "a hard landing leaves nothing in the floor after its impact")
	assert_gt(lowest, -0.1, "and only just in at impact (lowest %.3f m)" % lowest)
