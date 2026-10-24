extends GutTest
## The grab from the first-person view and side on (Game-boy's playtest, 2026-10-24; M2
## phase 3 package B): while an enemy is held the view pitches down (Tuning "Grab and
## weapons" > "Hold view"), eased in on the grab and back out on the throw or any release,
## and a knee's own pitch adds to it without a jump; the player bends at the waist for the
## hold and the knees; the hands stay 0.3 m or more from the lens, nothing fills the view,
## and the knee shows landing on the held body. Judged through the real view
## (FirstPersonCamera.view_from_eye()) in the real test room, and on bare rigs side on.

const ROOM := preload("res://game/level/test_room.tscn")
const FPView := preload("res://tests/fp_view.gd")
const FAR := Vector3(30.0, 0.0, -30.0)
const FRAME := 1.0 / 60.0

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


func after_all() -> void:
	Tuning.apply(TuningData.new())


# --- Harness ------------------------------------------------------------------------


## The test room with the player looking level and dummies at `posts` (player frame: x
## right, -z ahead); the rest far away. No dummy spars.
func _setup(posts: Array[Vector3]) -> void:
	if is_instance_valid(room):
		room.queue_free()
		await _ticks(2)
	room = ROOM.instantiate()
	room.set(&"with_presentation", false)
	add_child_autofree(room)
	await _ticks(2)
	player = room.get(&"player")
	player.input.scripted = true
	player.look_pitch = 0.0
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


func _wait_until(condition: Callable, max_ticks: int = 400) -> bool:
	for i in max_ticks:
		if condition.call():
			return true
		await get_tree().physics_frame
	return false


func _holding() -> bool:
	return player.holding_enemy() != null and player.state == CombatTypes.ActorState.GRABBING


## Grab the dummy in front and wait until the hold view is at full weight.
func _grab() -> void:
	player.input.push_press(&"GRAB", 2)
	assert_true(await _wait_until(_holding, 30), "grabbed")
	assert_true(await _wait_until(func() -> bool: return player.get_hold_view_weight() >= 1.0, 60), "the hold view eases all the way in")


## The view's extra pitch (x, degrees), drop (y, meters) and pull-back (z, meters).
func _offsets() -> Vector3:
	var o := player.get_camera_move_offset()
	return Vector3(o.x, o.y, player.get_camera_pull_back())


## Watch the view offsets for `ticks` physics ticks (calling `each` before every tick,
## if given): the largest change of each between two ticks, and every tick's offsets.
func _watch(ticks: int, each: Callable = Callable()) -> Dictionary:
	var steps := Vector3.ZERO
	var seen: Array[Vector3] = []
	var last := _offsets()
	for i in ticks:
		if each.is_valid():
			each.call()
		await _ticks(1)
		var now := _offsets()
		steps = Vector3(maxf(steps.x, absf(now.x - last.x)), maxf(steps.y, absf(now.y - last.y)), maxf(steps.z, absf(now.z - last.z)))
		seen.append(now)
		last = now
	return {steps = steps, seen = seen}


## The most the hold view's own offsets can change in one sim tick easing over `seconds`
## (smoothstep peaks at 1.5 times the linear rate), with a little slack.
func _hold_step(seconds: float) -> Vector3:
	var rate := 1.5 / maxf(seconds * Engine.physics_ticks_per_second, 1.0) * 1.05
	return Vector3(Tuning.data.grab_view_pitch_deg, Tuning.data.grab_view_rise_m, Tuning.data.grab_view_back_m) * rate


func _full_hold() -> Vector3:
	return Vector3(-Tuning.data.grab_view_pitch_deg, -Tuning.data.grab_view_rise_m, Tuning.data.grab_view_back_m)


func _assert_steps_within(steps: Vector3, bound: Vector3, what: String) -> void:
	assert_lte(steps.x, bound.x + 1e-4, "%s: the pitch moves at most %.2f degrees a tick (%.2f)" % [what, bound.x, steps.x])
	assert_lte(steps.y, bound.y + 1e-5, "%s: the rise moves at most %.4f m a tick (%.4f)" % [what, bound.y, steps.y])
	assert_lte(steps.z, bound.z + 1e-5, "%s: the pull-back moves at most %.4f m a tick (%.4f)" % [what, bound.z, steps.z])


# --- The hold view --------------------------------------------------------------------


func test_hold_view_eases_in_on_the_grab() -> void:
	await _setup([Vector3(0, 0, -1.1)])
	assert_eq(_offsets(), Vector3.ZERO, "no hold view before the grab")
	player.input.push_press(&"GRAB", 2)
	var in_ticks := ceili(Tuning.data.grab_view_in_s * Engine.physics_ticks_per_second)
	var watched := await _watch(in_ticks + 6)
	var seen: Array[Vector3] = watched.seen
	assert_true(_holding(), "holding")
	_assert_steps_within(watched.steps, _hold_step(Tuning.data.grab_view_in_s), "grab")
	for i in range(1, seen.size()):
		assert_lte(seen[i].x, seen[i - 1].x + 1e-4, "tick %d: the view only tips further down while it eases in" % i)
	assert_almost_eq(seen[seen.size() - 1], _full_hold(), Vector3.ONE * 1e-4,
			"within grab_view_in_s the view is pitched down %.0f degrees, raised and pulled back" % Tuning.data.grab_view_pitch_deg)
	var settled := await _watch(30)
	assert_almost_eq(settled.steps, Vector3.ZERO, Vector3.ONE * 1e-5, "held, the view stays put")


func test_knee_pitch_adds_to_the_hold_view_without_a_jump() -> void:
	await _setup([Vector3(0, 0, -1.1)])
	await _grab()
	var knee := Tuning.get_move(&"knee")
	for n in Tuning.data.max_knees - 1:
		player.input.push_press(&"P", 2)
		var watched := await _watch(knee.total_frames() + 10)
		var seen: Array[Vector3] = watched.seen
		# The knee's own pitch eases in over its 5-frame startup (like a kick's), the hold's
		# stays: no step bigger than the knee's own easing.
		var knee_step := absf(knee.camera_pitch_deg) * 1.5 / knee.startup * 1.05
		assert_lte(watched.steps.x, knee_step, "knee %d: the pitch moves at most %.1f degrees a tick (%.2f)" % [n + 1, knee_step, watched.steps.x])
		var lowest := 0.0
		for o: Vector3 in seen:
			lowest = minf(lowest, o.x)
		assert_almost_eq(lowest, -Tuning.data.grab_view_pitch_deg + knee.camera_pitch_deg, 0.01,
				"knee %d: the knee's pitch adds to the hold's at the strike" % [n + 1])
		assert_true(_holding(), "knee %d: still holding" % [n + 1])
		assert_almost_eq(_offsets(), _full_hold(), Vector3.ONE * 1e-4, "knee %d: back to the hold view after the knee" % [n + 1])
	# The last knee releases the victim into a stagger: the hold view eases back out over
	# grab_view_out_s while the knee's own pitch eases out over its recovery, together
	# with no jump, and the view ends level again.
	player.input.push_press(&"P", 2)
	var out_ticks := ceili(Tuning.data.grab_view_out_s * Engine.physics_ticks_per_second)
	var last := await _watch(maxi(out_ticks, knee.total_frames()) + 20)
	assert_false(_holding(), "the last knee lets go")
	var bound := _hold_step(Tuning.data.grab_view_out_s)
	bound.x += absf(knee.camera_pitch_deg) * 1.5 / knee.startup * 1.05
	assert_lte(last.steps.x, bound.x, "release knee: the pitch moves at most %.1f degrees a tick (%.2f)" % [bound.x, last.steps.x])
	assert_almost_eq(_offsets(), Vector3.ZERO, Vector3.ONE * 1e-4, "after the release the view is level and back on the eye")


func test_hold_view_eases_out_on_the_throw() -> void:
	await _setup([Vector3(0, 0, -1.1)])
	await _grab()
	var throw := Tuning.get_move(&"throw")
	player.input.push_press(&"K", 2)
	var weights: Array[float] = []
	var watched := await _watch(throw.total_frames() + 30,
			func() -> void: weights.append(player.get_hold_view_weight()))
	assert_null(player.holding_enemy(), "thrown")
	_assert_steps_within(watched.steps, _hold_step(Tuning.data.grab_view_out_s), "throw")
	# Full through the heave's startup, then down without ever coming back up.
	var released := 0
	while released < weights.size() and weights[released] >= 1.0:
		released += 1
	assert_gte(released, throw.startup, "the view stays on the victim until it is thrown (the throw's startup)")
	for i in range(1, weights.size()):
		assert_lte(weights[i], weights[i - 1] + 1e-6, "tick %d: the hold view only eases out" % i)
	assert_almost_eq(_offsets(), Vector3.ZERO, Vector3.ONE * 1e-4, "after the throw the view is level and back on the eye")


func test_hold_view_eases_out_on_a_release_and_when_a_hit_breaks_the_hold() -> void:
	for how: String in ["release", "hit"]:
		await _setup([Vector3(0, 0, -1.1)])
		await _grab()
		if how == "release":
			player.input.push_press(&"GRAB", 2)
		else:
			var hit := HitInfo.new()
			hit.attacker = dummies[0]
			hit.victim = player
			hit.move = Tuning.get_move(&"dummy_jab")
			hit.damage = 1.0
			hit.tier = CombatTypes.HitTier.LIGHT
			hit.reaction = CombatTypes.Reaction.FLINCH
			hit.region = CombatTypes.Region.HEAD
			hit.direction = player.global_basis * Vector3.BACK
			hit.contact_point = player.get_head_top_position()
			hit.physics_frame = Engine.get_physics_frames()
			assert_true(player.receive_hit(hit), "the hit lands")
		var out_ticks := ceili(Tuning.data.grab_view_out_s * Engine.physics_ticks_per_second)
		var watched := await _watch(out_ticks + 20)
		assert_null(player.holding_enemy(), "%s: let go" % how)
		_assert_steps_within(watched.steps, _hold_step(Tuning.data.grab_view_out_s), how)
		assert_almost_eq(_offsets(), Vector3.ZERO, Vector3.ONE * 1e-4, "%s: the view is level and back on the eye" % how)


func test_walking_with_a_held_enemy_keeps_the_hold_view_on_the_bent_eye() -> void:
	# Walking while holding shows the hold pose (no walk cycle), whose bent-over eye sits
	# well under the standing eye: the camera's walking bob clamp (cam_bob_clamp_m around
	# the standing height) would lift the view off it, so it is not applied while holding.
	await _setup([Vector3(0, 0, -1.1)])
	await _grab()
	var cam := FirstPersonCamera.new()
	add_child_autofree(cam)
	cam.player = player
	player.input.scripted_move = Vector2(0.0, 1.0)
	for i in 30:
		await _ticks(1)
		cam.update_camera(FRAME)
	assert_true(player.is_walking(), "walking with the held enemy")
	var target := FirstPersonCamera.view_from_eye(player, player.get_eye_transform().origin)
	assert_almost_eq(cam.view_transform().origin.y, target.origin.y, 0.01,
			"the view rides the bent eye (standing eye %.2f m above the feet)" % player.standing_eye_height)
	player.input.scripted_move = Vector2.ZERO


# --- What the hold view shows -----------------------------------------------------------


func _is_arm(m: MeshInstance3D) -> bool:
	var n := String(m.name)
	for part: String in ["Forearm", "Wrap", "Hand", "GloveBack"]:
		if n.contains(part):
			return true
	return false


func _is_right_leg(m: MeshInstance3D) -> bool:
	return m.name in [&"RightThigh", &"RightShin"]


## What the real first-person view (FirstPersonCamera.view_from_eye(), from EyePoint itself)
## shows this tick: the nearest forearm or hand to the lens, the nearest part of the held
## victim, and the shares of the view the player's own body, its right leg, the victim and
## the two together cover.
func _view_report(victim: CombatActor) -> Dictionary:
	var cam := FirstPersonCamera.view_from_eye(player, player.get_eye_transform().origin)
	# Both bodies in one cast, so each covers what it hides of the other.
	var skip := FPView.meshes_under(room).filter(func(m: MeshInstance3D) -> bool:
		return not (player.rig.is_ancestor_of(m) or victim.rig.is_ancestor_of(m)))
	var cols := 32
	var cells := FPView.hits(room, cam, cols, skip)
	var own := 0
	var leg := 0
	var vic := 0
	var touching := false
	for i in cells.size():
		var mesh := cells[i]
		if mesh == null:
			continue
		if victim.rig.is_ancestor_of(mesh):
			vic += 1
			continue
		own += 1
		if not _is_right_leg(mesh):
			continue
		leg += 1
		# The knee meets the victim: a victim cell right beside a leg cell.
		for step: int in [-1, 1, -cols, cols]:
			var j := i + step
			if j >= 0 and j < cells.size() and cells[j] != null and victim.rig.is_ancestor_of(cells[j]):
				touching = true
	var total := float(cells.size())
	return {
		arm = FPView.nearest_mesh(player.rig, cam.origin, _is_arm),
		victim_near = FPView.nearest_mesh(victim.rig, cam.origin),
		own = own / total,
		leg = leg / total,
		victim = vic / total,
		covered = (own + vic) / total,
		touching = touching,
		knee_in_view = _in_view(cam, player.rig.get_point_position(&"RightKneePoint")),
	}


func _in_view(cam: Transform3D, world: Vector3) -> bool:
	var q := cam.affine_inverse() * world
	if q.z >= -FPView.NEAR:
		return false
	return absf(q.x / -q.z) < tan(deg_to_rad(FPView.HALF_H_DEG)) and absf(q.y / -q.z) < tan(deg_to_rad(FPView.HALF_V_DEG))


func test_hold_knees_and_throw_keep_the_lens_clear() -> void:
	# Looking level, through the grab, the hold and three knees (the last lets go), then a
	# regrab and a throw: no forearm or hand comes within 0.3 m of the lens (ARCHITECTURE
	# "First-person lens"), the player's own body covers at most a third of the view, the
	# victim stays 0.25 m or more from the lens and covers at most half of it, and the view
	# never fills: some of it is always open.
	await _setup([Vector3(0, 0, -1.1)])
	var victim := dummies[0]
	var knee := Tuning.get_move(&"knee")
	var worst := {arm = INF, victim_near = INF, own = 0.0, victim = 0.0, covered = 0.0, ticks = 0}
	var check := func() -> void:
		if victim.state != CombatTypes.ActorState.GRABBED and player.current_move == null:
			return
		var r := _view_report(victim)
		worst.arm = minf(worst.arm, r.arm)
		worst.victim_near = minf(worst.victim_near, r.victim_near)
		worst.own = maxf(worst.own, r.own)
		worst.victim = maxf(worst.victim, r.victim)
		worst.covered = maxf(worst.covered, r.covered)
		worst.ticks += 1
	player.input.push_press(&"GRAB", 2)
	for i in 30:
		await _ticks(1)
		check.call()
	for n in Tuning.data.max_knees:
		player.input.push_press(&"P", 2)
		for i in knee.total_frames() + 10:
			await _ticks(1)
			check.call()
	assert_true(await _wait_until(func() -> bool: return player.state == CombatTypes.ActorState.FREE and player.current_move == null, 60), "let go")
	player.input.push_press(&"GRAB", 2)
	for i in 30:
		await _ticks(1)
		check.call()
	assert_true(_holding(), "regrabbed")
	var throw := Tuning.get_move(&"throw")
	player.input.push_press(&"K", 2)
	for i in throw.total_frames() + 10:
		await _ticks(1)
		check.call()
	gut.p("hold, knees and throw, worst: %s" % worst)
	assert_gt(worst.ticks, 120, "ticks watched")
	assert_gte(worst.arm, 0.3, "no forearm or hand within 0.3 m of the lens (nearest %.3f m)" % worst.arm)
	assert_lte(worst.own, 1.0 / 3.0, "the player's own body covers at most a third of the view (%.0f%%)" % (worst.own * 100.0))
	assert_gte(worst.victim_near, 0.25, "the victim stays 0.25 m or more from the lens (nearest %.3f m)" % worst.victim_near)
	assert_lte(worst.victim, 0.5, "the victim covers at most half the view (%.0f%%)" % (worst.victim * 100.0))
	assert_lte(worst.covered, 0.85, "the view never fills (at most %.0f%% covered)" % (worst.covered * 100.0))


func test_the_knee_shows_landing_on_the_held_body() -> void:
	# Looking level, on every active frame of a knee the hold view (with the knee's own
	# pitch and drop) shows the player's right thigh and knee rising into the view right
	# beside the held victim, its knee point in view.
	await _setup([Vector3(0, 0, -1.1)])
	await _grab()
	var knee := Tuning.get_move(&"knee")
	player.input.push_press(&"P", 2)
	assert_true(await _wait_until(func() -> bool: return player.current_move == knee and player.move_frame >= knee.startup, 30), "the knee reaches its active frames")
	var victim := dummies[0]
	var frames := {}
	while player.current_move == knee and knee.is_active(player.move_frame):
		var r := _view_report(victim)
		assert_true(r.knee_in_view, "frame %d: the knee is in view" % player.move_frame)
		assert_gte(r.leg, 0.03, "frame %d: the thigh and knee show (%.1f%% of the view)" % [player.move_frame, r.leg * 100.0])
		assert_true(r.touching, "frame %d: the knee meets the victim on screen" % player.move_frame)
		frames[player.move_frame] = true
		await _ticks(1)
	assert_eq(frames.size(), knee.active, "every active frame checked")


# --- Bent at the waist (bare rigs, side on) -------------------------------------------------


func _player_rig() -> HumanoidRig:
	var rig := HumanoidRig.new()
	rig.first_person_body = true
	rig.stance = PlaceholderPoses.STANCE_RELAXED
	rig.wrapped_hands = true
	add_child_autofree(rig)
	rig.build()
	return rig


## Degrees the torso leans forward from upright: the line from the hips to the neck,
## against vertical, positive leaning ahead (-Z).
func _lean_deg(rig: HumanoidRig) -> float:
	var up := rig.get_point_position(&"Neck") - rig.get_point_position(&"Hips")
	return rad_to_deg(atan2(-up.z, up.y))


func test_the_hold_and_the_knees_bend_at_the_waist() -> void:
	# Side on the clinch reads as a clinch: the torso leans well forward from the hips in the
	# hold and through every frame of a knee (standing, it is nearly upright), and the eye
	# stays within a few centimeters of the hold's through the knee, so the first-person view
	# rides steady over it.
	var rig := _player_rig()
	rig.play(&"idle", 0.0)
	rig.advance(0.5)
	var standing := _lean_deg(rig)
	rig.play(&"hold", 0.0)
	rig.advance(0.0)
	var held := _lean_deg(rig)
	var eye := rig.get_point_position(&"EyePoint")
	assert_lt(standing, 10.0, "standing, the torso is nearly upright (%.1f degrees)" % standing)
	assert_gte(held, 20.0, "holding, the torso leans forward from the hips (%.1f degrees)" % held)
	var knee := Tuning.get_move(&"knee")
	rig.play_move(knee)
	var least := INF
	var drift := 0.0
	for f in knee.total_frames():
		rig.advance(FRAME)
		least = minf(least, _lean_deg(rig))
		drift = maxf(drift, rig.get_point_position(&"EyePoint").distance_to(eye))
	assert_gte(least, 18.0, "through the knee the torso stays bent (least %.1f degrees)" % least)
	assert_lt(drift, 0.06, "through the knee the eye stays within 6 cm of the hold's (%.3f m)" % drift)
