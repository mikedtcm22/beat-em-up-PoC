extends GutTest
## The grab from the first-person view and side on (Game-boy's playtest, 2026-10-24; M2
## phase 3 package B): while an enemy is held the view pitches down (Tuning "Grab and
## weapons" > "Hold view"), eased in on the grab and back out on the throw or any release,
## and a knee's own pitch adds to it without a jump; the lens itself moves back and up into
## the hold and out again on its own ease, never bobbing past either end whatever the pose
## does (package C review, code-03); the player bends at the waist for the hold and the
## knees; the hands stay 0.3 m or more from the lens, nothing fills the view, and the knee
## shows landing on the held body, looking level and looking down; a hit that breaks the
## hold sends the held body staggering away. Judged through the real view
## (FirstPersonCamera.view_from_eye(), or the camera itself where its smoothing matters) in
## the real test room, and on bare rigs side on.

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


## The test room with the player looking `look_deg` degrees up (level by default) and
## dummies at `posts` (player frame: x right, -z ahead); the rest far away. No dummy spars.
func _setup(posts: Array[Vector3], look_deg: float = 0.0) -> void:
	if is_instance_valid(room):
		room.queue_free()
		await _ticks(2)
	room = ROOM.instantiate()
	room.set(&"with_presentation", false)
	add_child_autofree(room)
	await _ticks(2)
	player = room.get(&"player")
	player.input.scripted = true
	player.look_pitch = deg_to_rad(look_deg)
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


func _assert_pitch_steps_within(steps: Vector3, bound: Vector3, what: String) -> void:
	assert_lte(steps.x, bound.x + 1e-4, "%s: the pitch moves at most %.2f degrees a tick (%.2f)" % [what, bound.x, steps.x])


## A first-person camera riding the player, as the camera director makes it.
func _camera() -> FirstPersonCamera:
	var cam := FirstPersonCamera.new()
	add_child_autofree(cam)
	cam.player = player
	cam.update_camera(FRAME)
	return cam


## Where the camera's lens is (before punch and shake) from the player's origin: x up, y
## ahead along the body's facing (meters).
func _lens(cam: FirstPersonCamera) -> Vector2:
	var local := player.global_basis.inverse() * (cam.view_transform().origin - player.global_position)
	return Vector2(local.y, -local.z)


## Follow the camera's lens for `ticks` physics ticks (calling `each` before every tick, if
## given; the camera updates after it): every tick's lens (_lens()) and the largest change
## of each axis between two ticks.
func _follow_lens(cam: FirstPersonCamera, ticks: int, each: Callable = Callable()) -> Dictionary:
	var seen: Array[Vector2] = []
	var steps := Vector2.ZERO
	var last := _lens(cam)
	for i in ticks:
		if each.is_valid():
			each.call()
		await _ticks(1)
		cam.update_camera(FRAME)
		var now := _lens(cam)
		steps = steps.max((now - last).abs())
		seen.append(now)
		last = now
	return {seen = seen, steps = steps}


## The lens path `seen` from `from` to its last point moves each tick at most the hold
## view's own bound (`bound`: _hold_step(), y the rise's and z the pull-back's) and never
## past either end (or the points in `also`: a walk's own bob) by more than `slack` meters
## (up and ahead): it eases, it does not bob (it bobbed 5-7 cm past the ends, and 18 cm
## back on a grab). The default slack is the hold pose's own sway: its breathing leans the
## eye about a centimeter.
func _assert_lens_eases(seen: Array[Vector2], from: Vector2, steps: Vector2, bound: Vector3,
		what: String, also: Array[Vector2] = [], slack: Vector2 = Vector2(0.01, 0.015)) -> void:
	var to := seen[seen.size() - 1]
	assert_lte(steps.x, bound.y + 1e-5, "%s: the lens moves up or down at most %.4f m a tick (%.4f)" % [what, bound.y, steps.x])
	assert_lte(steps.y, bound.z + 1e-5, "%s: the lens moves back or ahead at most %.4f m a tick (%.4f)" % [what, bound.z, steps.y])
	var high := from.max(to)
	var low := from.min(to)
	for p: Vector2 in also:
		high = high.max(p)
		low = low.min(p)
	var over := Vector2.ZERO
	for p: Vector2 in seen:
		over = over.max(p - high).max(low - p)
	assert_lte(over.x, slack.x, "%s: the lens never rises or sinks past either end (%.3f m beyond, %.3f -> %.3f m up)" % [what, over.x, from.x, to.x])
	assert_lte(over.y, slack.y, "%s: the lens never moves back or ahead past either end (%.3f m beyond, %.3f -> %.3f m ahead)" % [what, over.y, from.y, to.y])


# --- The hold view --------------------------------------------------------------------


func test_hold_view_eases_in_on_the_grab() -> void:
	await _setup([Vector3(0, 0, -1.1)])
	var cam := _camera()
	await _ticks(2)
	cam.update_camera(FRAME)
	assert_eq(_offsets(), Vector3.ZERO, "no hold view before the grab")
	var standing := _lens(cam)
	player.input.push_press(&"GRAB", 2)
	var in_ticks := ceili(Tuning.data.grab_view_in_s * Engine.physics_ticks_per_second)
	var pitches: Array[float] = []
	var record := func() -> void: pitches.append(_offsets().x)
	# Long enough for the body to finish bending into the hold (it bends late, after the
	# grab's reach).
	var followed := await _follow_lens(cam, in_ticks + 24, record)
	pitches.append(_offsets().x)
	assert_true(_holding(), "holding")
	var bound := _hold_step(Tuning.data.grab_view_in_s)
	for i in range(1, pitches.size()):
		assert_lte(absf(pitches[i] - pitches[i - 1]), bound.x + 1e-4, "tick %d: the pitch moves at most %.2f degrees a tick" % [i, bound.x])
		assert_lte(pitches[i], pitches[i - 1] + 1e-4, "tick %d: the view only tips further down while it eases in" % i)
	assert_almost_eq(pitches[in_ticks + 1], -Tuning.data.grab_view_pitch_deg, 1e-4,
			"within grab_view_in_s the view is pitched down %.0f degrees" % Tuning.data.grab_view_pitch_deg)
	# The lens moves back and up into the hold on its own ease, whenever the body bends.
	_assert_lens_eases(followed.seen, standing, followed.steps, bound, "grab")
	var held := _lens(cam)
	assert_gt(held.x, standing.x, "holding, the lens sits higher than standing (the rise makes up for the bend's drop)")
	assert_lt(held.y, standing.y - 0.05, "holding, the lens sits well back from where it stands")
	assert_almost_eq(_offsets(), _full_hold(), Vector3.ONE * 1e-4, "bent into the hold, the view is pitched down, raised and pulled back in full")
	var settled := await _follow_lens(cam, 30)
	assert_almost_eq(settled.steps, Vector2.ZERO, Vector2.ONE * 0.002, "held, the lens stays put")


func test_knee_pitch_adds_to_the_hold_view_without_a_jump() -> void:
	await _setup([Vector3(0, 0, -1.1)])
	await _grab()
	await _ticks(20)
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
	# The last knee releases the victim into a stagger: the hold view's pitch eases back out
	# over grab_view_out_s while the knee's own pitch eases out over its recovery, together
	# with no jump; the lens eases out once the knee is over (it ends in the hold, still bent),
	# and the view ends level and back on the eye.
	player.input.push_press(&"P", 2)
	var out_ticks := ceili(Tuning.data.grab_view_out_s * Engine.physics_ticks_per_second)
	var last := await _watch(knee.total_frames() + out_ticks + 20)
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
	var out_ticks := ceili(Tuning.data.grab_view_out_s * Engine.physics_ticks_per_second)
	var watched := await _watch(throw.total_frames() + out_ticks,
			func() -> void: weights.append(player.get_hold_view_weight()))
	assert_null(player.holding_enemy(), "thrown")
	_assert_pitch_steps_within(watched.steps, _hold_step(Tuning.data.grab_view_out_s), "throw")
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
		var cam := _camera()
		await _grab()
		await _follow_lens(cam, 20)
		var held := _lens(cam)
		var victim := dummies[0]
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
			assert_eq(victim.state, CombatTypes.ActorState.STAGGER, "the hit tears the clinch apart: the held body staggers away")
			# TimeController starts a hitstop on the next physics tick.
			await _ticks(1)
			assert_true(TimeController.is_in_hitstop(victim), "the body let go freezes with the hit's hitstop")
		var out_ticks := ceili(Tuning.data.grab_view_out_s * Engine.physics_ticks_per_second)
		var pitches := await _watch(out_ticks + 20, Callable())
		assert_null(player.holding_enemy(), "%s: let go" % how)
		_assert_pitch_steps_within(pitches.steps, _hold_step(Tuning.data.grab_view_out_s), how)
		assert_almost_eq(_offsets(), Vector3.ZERO, Vector3.ONE * 1e-4, "%s: the view is level and back on the eye" % how)
		if how == "release":
			# The body straightens in about a third of grab_view_out_s; the lens still eases.
			await _setup([Vector3(0, 0, -1.1)])
			cam = _camera()
			await _grab()
			await _follow_lens(cam, 20)
			held = _lens(cam)
			player.input.push_press(&"GRAB", 2)
			var followed := await _follow_lens(cam, out_ticks + 20)
			_assert_lens_eases(followed.seen, held, followed.steps, _hold_step(Tuning.data.grab_view_out_s), "release")


func test_a_hold_that_ends_while_the_view_eases_in_turns_back_without_a_jump() -> void:
	# LB again a few ticks into the grab, while the view is still easing in: the pitch and the
	# lens turn back from wherever they are, at the ease-out's pace, and the lens never goes
	# past where it was or where it ends.
	var out_ticks := ceili(Tuning.data.grab_view_out_s * Engine.physics_ticks_per_second)
	for after: int in [3, 6, 9]:
		await _setup([Vector3(0, 0, -1.1)])
		var cam := _camera()
		player.input.push_press(&"GRAB", 2)
		assert_true(await _wait_until(func() -> bool:
			cam.update_camera(FRAME)
			return _holding(), 30), "grabbed")
		await _follow_lens(cam, after)
		var from := _lens(cam)
		assert_lt(player.get_hold_view_weight(), 1.0, "%d ticks in, the hold view is still easing in" % after)
		player.input.push_press(&"GRAB", 2)
		var pitches := []
		var followed := await _follow_lens(cam, out_ticks + 20, func() -> void: pitches.append(_offsets().x))
		var what := "LB %d ticks into the grab" % after
		assert_false(_holding(), "%s: let go" % what)
		var bound := _hold_step(Tuning.data.grab_view_out_s)
		for i in range(1, pitches.size()):
			assert_lte(absf(pitches[i] - pitches[i - 1]), bound.x + 1e-4, "%s, tick %d: the pitch moves at most %.2f degrees a tick" % [what, i, bound.x])
		_assert_lens_eases(followed.seen, from, followed.steps, bound, what)
		assert_almost_eq(_offsets(), Vector3.ZERO, Vector3.ONE * 1e-4, "%s: the view is level and back on the eye" % what)


func test_walking_with_a_held_enemy_keeps_the_hold_view_on_the_bent_eye() -> void:
	# Walking while holding shows the hold pose (no walk cycle), whose bent-over eye sits
	# well under the standing eye: the camera's walking bob clamp (cam_bob_clamp_m around
	# the standing height) would lift the view off it, so it is not applied while holding.
	await _setup([Vector3(0, 0, -1.1)])
	await _grab()
	var cam := _camera()
	player.input.scripted_move = Vector2(0.0, 1.0)
	for i in 30:
		await _ticks(1)
		cam.update_camera(FRAME)
	assert_true(player.is_walking(), "walking with the held enemy")
	var target := FirstPersonCamera.view_from_eye(player, player.get_eye_transform().origin)
	assert_almost_eq(cam.view_transform().origin.y, target.origin.y, 0.01,
			"the view rides the bent eye (standing eye %.2f m above the feet)" % player.standing_eye_height)
	player.input.scripted_move = Vector2.ZERO


func test_grab_and_release_while_walking_ease_the_lens() -> void:
	# Walking into a grab and letting go while still walking: the lens eases into and out of
	# the hold as standing still. The walking bob clamp lets go of the eye as the hold view
	# comes in and takes it back as it eases out, so the release never pops the view (it
	# jumped 3.5 cm in one frame) and the lens never bobs past either end (it rose 5-7 cm
	# over the hold and sank back).
	await _setup([Vector3(0, 0, -2.2)])
	var cam := _camera()
	var victim := dummies[0]
	player.input.scripted_move = Vector2(0.0, 1.0)
	var walking := await _follow_lens(cam, 20)
	assert_true(player.is_walking(), "walking up to the dummy")
	# The walk's own bob stays on top of either end: the lens may go anywhere it went
	# walking (from where it then sat), standing or holding.
	var bob: Array[Vector2] = []
	for p: Vector2 in walking.seen:
		bob.append(p)
	assert_true(await _wait_until(func() -> bool:
		cam.update_camera(FRAME)
		return victim.global_position.distance_to(player.global_position) < 1.2, 60), "close enough to grab")
	var before := _lens(cam)
	player.input.push_press(&"GRAB", 2)
	var in_ticks := ceili(Tuning.data.grab_view_in_s * Engine.physics_ticks_per_second)
	var grab := await _follow_lens(cam, in_ticks + 24)
	assert_true(_holding(), "grabbed while walking")
	var bound := _hold_step(Tuning.data.grab_view_in_s)
	bound.y = maxf(bound.y, walking.steps.x * 1.05)
	_assert_lens_eases(grab.seen, before, grab.steps, bound, "grab while walking", bob)
	var held := _lens(cam)
	player.input.push_press(&"GRAB", 2)
	var out_ticks := ceili(Tuning.data.grab_view_out_s * Engine.physics_ticks_per_second)
	var release := await _follow_lens(cam, out_ticks + 20)
	assert_false(_holding(), "let go")
	assert_true(player.is_walking(), "still walking")
	bound = _hold_step(Tuning.data.grab_view_out_s)
	bound.y = maxf(bound.y, walking.steps.x * 1.05)
	_assert_lens_eases(release.seen, held, release.steps, bound, "release while walking", bob)
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
## victim, the shares of the view the player's own body, its right leg, the victim and the
## two together cover, and the share of the middle of the view (its middle two thirds
## across and down) the elbow ends of the upper arms cover: one there shows end on, a
## round ball mid-view, where at the edge it reads as a sleeve.
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
	var elbow_mid := 0
	var rows := FPView.rows(cols)
	for i in cells.size():
		var mesh := cells[i]
		if mesh == null:
			continue
		if victim.rig.is_ancestor_of(mesh):
			vic += 1
			continue
		own += 1
		var row := i / cols
		var col := i % cols
		if String(mesh.name).ends_with("Elbow") and col * 6 >= cols and col * 6 < cols * 5 and row * 6 >= rows and row * 6 < rows * 5:
			elbow_mid += 1
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
		elbow_mid = elbow_mid / total,
		knee_in_view = _in_view(cam, player.rig.get_point_position(&"RightKneePoint")),
	}


func _in_view(cam: Transform3D, world: Vector3) -> bool:
	var q := cam.affine_inverse() * world
	if q.z >= -FPView.NEAR:
		return false
	return absf(q.x / -q.z) < tan(deg_to_rad(FPView.HALF_H_DEG)) and absf(q.y / -q.z) < tan(deg_to_rad(FPView.HALF_V_DEG))


## Worst of the lens rules seen so far (see _assert_lens_clear()).
func _lens_worst() -> Dictionary:
	return {arm = INF, victim_near = INF, own = 0.0, victim = 0.0, covered = 0.0, elbow_mid = 0.0, ticks = 0}


## Watch the view for `ticks` physics ticks, folding each tick's _view_report() into
## `worst`: every tick if `always`, else only while the victim is held or a move runs.
func _watch_lens(worst: Dictionary, victim: CombatActor, ticks: int, always: bool = false) -> void:
	for i in ticks:
		await _ticks(1)
		if not always and victim.state != CombatTypes.ActorState.GRABBED and player.current_move == null:
			continue
		var r := _view_report(victim)
		worst.arm = minf(worst.arm, r.arm)
		worst.victim_near = minf(worst.victim_near, r.victim_near)
		worst.own = maxf(worst.own, r.own)
		worst.victim = maxf(worst.victim, r.victim)
		worst.covered = maxf(worst.covered, r.covered)
		worst.elbow_mid = maxf(worst.elbow_mid, r.elbow_mid)
		worst.ticks += 1


## The first-person lens rules: no forearm or hand within 0.3 m of the lens (ARCHITECTURE
## "First-person lens"), the player's own body over at most a third of the view, the
## victim 0.25 m or more from the lens and over at most half of it, and the view never
## full: some of it is always open.
func _assert_lens_clear(worst: Dictionary, what: String) -> void:
	gut.p("%s, worst: %s" % [what, worst])
	assert_gte(worst.arm, 0.3, "%s: no forearm or hand within 0.3 m of the lens (nearest %.3f m)" % [what, worst.arm])
	assert_lte(worst.own, 1.0 / 3.0, "%s: the player's own body covers at most a third of the view (%.0f%%)" % [what, worst.own * 100.0])
	assert_gte(worst.victim_near, 0.25, "%s: the victim stays 0.25 m or more from the lens (nearest %.3f m)" % [what, worst.victim_near])
	assert_lte(worst.victim, 0.5, "%s: the victim covers at most half the view (%.0f%%)" % [what, worst.victim * 100.0])
	assert_lte(worst.covered, 0.85, "%s: the view never fills (at most %.0f%% covered)" % [what, worst.covered * 100.0])


func test_hold_knees_and_throw_keep_the_lens_clear() -> void:
	# Looking level: through the grab, the hold and three knees, and 45 ticks after the last
	# lets go (the victim staggers off); a regrab, LB, and 45 ticks after it (the victim
	# stands up in front); then a regrab and a throw, whose heave keeps the elbow ends of the
	# upper arms out of the middle of the view (seen end on from the pulled-back lens, the
	# right one showed as a round ball there).
	await _setup([Vector3(0, 0, -1.1)])
	var victim := dummies[0]
	var knee := Tuning.get_move(&"knee")
	var worst := _lens_worst()
	player.input.push_press(&"GRAB", 2)
	await _watch_lens(worst, victim, 30)
	for n in Tuning.data.max_knees:
		player.input.push_press(&"P", 2)
		await _watch_lens(worst, victim, knee.total_frames() + 10)
	await _watch_lens(worst, victim, 45, true)
	_assert_lens_clear(worst, "hold, three knees and the last one's release")
	assert_true(await _wait_until(func() -> bool: return player.state == CombatTypes.ActorState.FREE and player.current_move == null, 60), "let go")
	worst = _lens_worst()
	player.input.push_press(&"GRAB", 2)
	await _watch_lens(worst, victim, 30)
	assert_true(_holding(), "regrabbed")
	player.input.push_press(&"GRAB", 2)
	await _watch_lens(worst, victim, 45, true)
	assert_false(_holding(), "LB let go")
	_assert_lens_clear(worst, "LB release")
	worst = _lens_worst()
	player.input.push_press(&"GRAB", 2)
	await _watch_lens(worst, victim, 30)
	assert_true(_holding(), "regrabbed")
	_assert_lens_clear(worst, "regrab")
	worst = _lens_worst()
	var throw := Tuning.get_move(&"throw")
	player.input.push_press(&"K", 2)
	await _watch_lens(worst, victim, throw.total_frames() + 10)
	_assert_lens_clear(worst, "throw")
	assert_eq(worst.elbow_mid, 0.0, "throw: no elbow end of an upper arm in the middle of the view (%.1f%%)" % (worst.elbow_mid * 100.0))


func test_looking_down_the_hold_view_does_not_stack_on_the_look() -> void:
	# The hold's pitch only brings the view down to grab_view_target_pitch_deg in all: looking
	# level it adds all of grab_view_pitch_deg, looking 25 degrees down none (it stacked to
	# 53 degrees with a knee, the own belly and sleeves over most of the view). Through the
	# hold and two knees looking that far down the lens rules still hold. (The grab's reach
	# before it is the look's own: arms reaching out under a view already 25 degrees down
	# cover about a third of it with the own body, the hold view adding nothing.)
	var data := Tuning.data
	await _setup([Vector3(0, 0, -1.1)], -25.0)
	assert_almost_eq(player.get_hold_view_pitch_deg(), maxf(0.0, data.grab_view_target_pitch_deg - 25.0), 1e-4, "looking 25 degrees down")
	player.look_pitch = 0.0
	assert_almost_eq(player.get_hold_view_pitch_deg(), data.grab_view_pitch_deg, 1e-4, "looking level, all of it")
	player.look_pitch = deg_to_rad(-6.0)
	assert_almost_eq(player.get_hold_view_pitch_deg(), clampf(data.grab_view_target_pitch_deg - 6.0, 0.0, data.grab_view_pitch_deg), 1e-4, "looking 6 degrees down (the bots)")
	player.look_pitch = deg_to_rad(-25.0)
	var victim := dummies[0]
	var knee := Tuning.get_move(&"knee")
	await _grab()
	var worst := _lens_worst()
	await _watch_lens(worst, victim, 20)
	var total := rad_to_deg(player.look_pitch) + player.get_camera_move_offset().x
	assert_gte(total, -maxf(data.grab_view_target_pitch_deg, 25.0) - 1e-3, "held, the view tips no further down than the look or the target (%.1f degrees)" % total)
	for n in 2:
		player.input.push_press(&"P", 2)
		await _watch_lens(worst, victim, knee.total_frames() + 10)
	_assert_lens_clear(worst, "looking 25 degrees down")


func test_a_hit_that_breaks_the_hold_keeps_the_released_body_off_the_lens() -> void:
	# A second dummy jabs the player while he holds the first. The hit breaks the hold: the
	# held body freezes with the hit's hitstop (standing up meanwhile, its head came up
	# through the frozen, bent-over view), then staggers away. Through the hitstop and the
	# hold view's ease-out the lens rules hold.
	await _setup([Vector3(0, 0, -1.1), Vector3(0.85, 0, -0.2)])
	var victim := dummies[0]
	var jabber := dummies[1]
	await _grab()
	jabber.start_jab()
	var worst := _lens_worst()
	var hit_at := -1
	var frozen_together := 0
	for i in 120:
		await _ticks(1)
		if hit_at < 0 and player.state == CombatTypes.ActorState.HITSTUN:
			hit_at = i
			assert_eq(victim.state, CombatTypes.ActorState.STAGGER, "the hit tears the clinch apart: the held body staggers away")
		if TimeController.is_in_hitstop(player) and TimeController.is_in_hitstop(victim):
			frozen_together += 1
		if hit_at >= 0:
			var r := _view_report(victim)
			worst.arm = minf(worst.arm, r.arm)
			worst.victim_near = minf(worst.victim_near, r.victim_near)
			worst.own = maxf(worst.own, r.own)
			worst.victim = maxf(worst.victim, r.victim)
			worst.covered = maxf(worst.covered, r.covered)
			worst.ticks += 1
		if hit_at >= 0 and i - hit_at > 60:
			break
	assert_gte(hit_at, 0, "the jab lands while holding")
	assert_null(player.holding_enemy(), "the hold is broken")
	assert_gt(frozen_together, 0, "the body let go freezes with the player in the hit's hitstop")
	_assert_lens_clear(worst, "a hit breaks the hold")


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
