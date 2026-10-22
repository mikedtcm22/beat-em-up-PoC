extends GutTest
## Cameras module (game/camera/): CameraDirector cycling and player discovery, the
## first-person camera's follow, rotation and hit feel, the side view and free fly.
## Camera updates are driven by calling update_camera() with a fixed delta, except where
## the test is about per-frame behavior.


## Stand-in for the player. It drives the camera-facing API directly and skips the real
## controller's lifecycle callbacks.
class FakePlayer extends PlayerCharacter:
	## Eye point relative to the player's origin.
	var eye_offset: Vector3 = Vector3(0.0, 1.68, 0.0)
	## Rotation of the head bone's EyePoint. Deliberately unlike any look basis the tests
	## use, as an animated head would be, so a camera that took its rotation from the head
	## instead of the look would fail.
	var head_basis: Basis = Basis.from_euler(Vector3(0.35, -0.6, 0.25))
	var walking: bool = false
	var move_offset: Vector2 = Vector2.ZERO

	func _ready() -> void:
		add_to_group(&"player")

	func _process(_delta: float) -> void:
		pass

	func _physics_process(_delta: float) -> void:
		pass

	func _input(_event: InputEvent) -> void:
		pass

	func _unhandled_input(_event: InputEvent) -> void:
		pass

	func get_eye_transform() -> Transform3D:
		return Transform3D(head_basis, global_position + eye_offset)

	func get_camera_move_offset() -> Vector2:
		return move_offset

	func is_walking() -> bool:
		return walking


## A fake player that walks along +X at a constant speed in its physics ticks.
class MovingPlayer extends FakePlayer:
	var speed: float = 6.0

	func _physics_process(delta: float) -> void:
		global_position.x += speed * delta


## Records, after the cameras have run each process frame, the physics time (ticks plus
## the interpolation fraction) and where the camera and the rendered player are along X.
class FrameRecorder extends Node:
	var camera: Camera3D
	var player: Node3D
	var ticks: Array[float] = []
	var camera_x: Array[float] = []
	var player_x: Array[float] = []

	func _init() -> void:
		process_priority = CameraDirector.PROCESS_PRIORITY + 10

	func _process(_delta: float) -> void:
		ticks.append(float(Engine.get_physics_frames()) + Engine.get_physics_interpolation_fraction())
		camera_x.append(camera.global_position.x)
		player_x.append(player.get_global_transform_interpolated().origin.x)


const DT := 1.0 / 60.0
const EPS := 0.0005
const V_EPS := Vector3(EPS, EPS, EPS)


func before_each() -> void:
	Tuning.apply(TuningData.new())
	# These tests pin the camera to the eye point; the lens offsets have their own test.
	Tuning.data.cam_forward_offset_m = 0.0
	Tuning.data.cam_height_offset_m = 0.0


func after_all() -> void:
	Tuning.apply(TuningData.new())
	TimeController.clear()


# --- helpers -------------------------------------------------------------------------


func _make_player(at: Vector3 = Vector3.ZERO) -> FakePlayer:
	var player := FakePlayer.new()
	player.name = "FakePlayer"
	add_child_autofree(player)
	player.global_position = at
	return player


func _make_director() -> CameraDirector:
	var director := CameraDirector.new()
	add_child_autofree(director)
	return director


func _make_fp(player: PlayerCharacter) -> FirstPersonCamera:
	var cam := FirstPersonCamera.new()
	add_child_autofree(cam)
	cam.player = player
	return cam


func _cameras(director: CameraDirector) -> Array[Camera3D]:
	return [director.first_person_camera, director.side_view_camera, director.free_fly_camera]


func _current_count(director: CameraDirector) -> int:
	var count := 0
	for cam: Camera3D in _cameras(director):
		if cam.current:
			count += 1
	return count


func _run_fp(cam: FirstPersonCamera, seconds: float, dt: float = DT) -> void:
	for i: int in roundi(seconds / dt):
		cam.update_camera(dt)


func _hit(attacker: Node3D, victim: Node3D, tier: CombatTypes.HitTier, contact: Vector3,
		direction: Vector3) -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = attacker
	hit.victim = victim
	hit.tier = tier
	hit.contact_point = contact
	hit.direction = direction
	return hit


func _make_dummy(at: Vector3) -> Node3D:
	var dummy := Node3D.new()
	dummy.name = "Dummy"
	add_child_autofree(dummy)
	dummy.global_position = at
	return dummy


func _assert_basis_almost_eq(got: Basis, expected: Basis, text: String) -> void:
	assert_almost_eq(got.x, expected.x, V_EPS, text + " (x axis)")
	assert_almost_eq(got.y, expected.y, V_EPS, text + " (y axis)")
	assert_almost_eq(got.z, expected.z, V_EPS, text + " (z axis)")


func _assert_transform_almost_eq(got: Transform3D, expected: Transform3D, text: String) -> void:
	_assert_basis_almost_eq(got.basis, expected.basis, text)
	assert_almost_eq(got.origin, expected.origin, V_EPS, text + " (origin)")


# --- director ------------------------------------------------------------------------


func test_director_starts_in_first_person_with_one_current_camera() -> void:
	var director := _make_director()
	assert_true(director.is_in_group(&"camera_director"), "in camera_director group")
	assert_eq(director.mode, CameraDirector.MODE_FIRST_PERSON)
	assert_eq(director.active_camera(), director.first_person_camera as Camera3D)
	assert_eq(_current_count(director), 1, "exactly one current camera")
	assert_true(director.first_person_camera.current)
	assert_eq(director.get_viewport().get_camera_3d(), director.active_camera())
	for cam: Camera3D in _cameras(director):
		assert_eq(cam.get_parent(), director as Node, "camera is a child of the director")
		assert_true(cam.top_level, "camera ignores the director's transform")


func test_cycle_order_signals_and_single_current_camera() -> void:
	var director := _make_director()
	watch_signals(director)
	var expected: Array[StringName] = [
		CameraDirector.MODE_SIDE_VIEW,
		CameraDirector.MODE_FREE_FLY,
		CameraDirector.MODE_FIRST_PERSON,
	]
	var cams: Array[Camera3D] = [
		director.side_view_camera, director.free_fly_camera, director.first_person_camera,
	]
	for i: int in expected.size():
		director.cycle()
		assert_eq(director.mode, expected[i], "cycle step %d" % i)
		assert_eq(director.active_camera(), cams[i], "active camera at step %d" % i)
		assert_true(cams[i].current, "active camera is current at step %d" % i)
		assert_eq(_current_count(director), 1, "exactly one current camera at step %d" % i)
		assert_eq(director.get_viewport().get_camera_3d(), cams[i],
				"viewport camera at step %d" % i)
		assert_eq(get_signal_parameters(director, "camera_changed", i), [expected[i]])
	assert_signal_emit_count(director, "camera_changed", 3)


func test_set_mode_to_same_mode_is_a_no_op_and_assigning_mode_switches() -> void:
	var director := _make_director()
	watch_signals(director)
	director.set_mode(CameraDirector.MODE_FIRST_PERSON)
	assert_signal_emit_count(director, "camera_changed", 0)
	director.mode = CameraDirector.MODE_SIDE_VIEW
	assert_eq(director.active_camera(), director.side_view_camera as Camera3D,
			"assigning mode switches")
	assert_signal_emit_count(director, "camera_changed", 1)


func test_camera_cycle_action_cycles() -> void:
	var director := _make_director()
	var press := InputEventKey.new()
	press.physical_keycode = KEY_F2
	press.pressed = true
	director.get_viewport().push_input(press)
	var release := InputEventKey.new()
	release.physical_keycode = KEY_F2
	release.pressed = false
	director.get_viewport().push_input(release)
	assert_eq(director.mode, CameraDirector.MODE_SIDE_VIEW, "F2 cycles to the side view")


func test_cameras_hold_still_when_paused() -> void:
	var director := _make_director()
	assert_eq(director.process_mode, Node.PROCESS_MODE_PAUSABLE)
	get_tree().paused = true
	var frozen := true
	for cam: Camera3D in _cameras(director):
		frozen = frozen and not cam.can_process()
	get_tree().paused = false
	assert_true(frozen, "no camera processes while the tree is paused")
	for cam: Camera3D in _cameras(director):
		assert_true(cam.can_process(), "cameras process again after unpausing")


func test_paused_view_holds_while_the_player_moves() -> void:
	var player := _make_player()
	# Under an always-processing parent (a level or UI root may be one), so the director
	# holds still on its own account rather than by inheriting pause from the test.
	var holder := Node3D.new()
	holder.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child_autofree(holder)
	var director := CameraDirector.new()
	holder.add_child(director)
	var cam := director.first_person_camera
	await wait_process_frames(2)
	var held := cam.global_transform
	get_tree().paused = true
	player.global_position += Vector3(2.0, 0.0, -1.0)
	player.look_yaw = 1.0
	await wait_process_frames(3)
	var paused_view := cam.global_transform
	get_tree().paused = false
	_assert_transform_almost_eq(paused_view, held, "the view holds while paused")
	await wait_process_frames(2)
	assert_almost_eq(cam.global_position, player.get_eye_transform().origin, V_EPS,
			"follows again after unpausing")
	_assert_basis_almost_eq(cam.global_basis, player.get_look_basis(), "and turns with the look")


func test_director_finds_late_player_and_survives_replacement() -> void:
	var director := _make_director()
	assert_null(director.player, "no player yet")
	await wait_process_frames(2)
	var first := _make_player(Vector3(3.0, 0.0, -2.0))
	await wait_process_frames(2)
	assert_eq(director.player, first as PlayerCharacter, "finds a player added after _ready")
	assert_eq(director.first_person_camera.player, first as PlayerCharacter)
	assert_eq(director.side_view_camera.player, first as PlayerCharacter)
	assert_almost_eq(director.first_person_camera.global_position,
			first.get_eye_transform().origin, V_EPS, "FP camera snaps to the eye")

	first.free()
	await wait_process_frames(2)
	assert_null(director.player, "drops the freed player")
	var held := director.first_person_camera.global_transform
	await wait_process_frames(3)
	_assert_transform_almost_eq(director.first_person_camera.global_transform, held,
			"FP camera holds its view without a player")

	var second := _make_player(Vector3(-4.0, 0.0, 1.0))
	await wait_process_frames(2)
	assert_eq(director.player, second as PlayerCharacter, "finds the replacement player")
	assert_almost_eq(director.first_person_camera.global_position,
			second.get_eye_transform().origin, V_EPS, "FP camera jumps to the new player")


# --- first-person camera -------------------------------------------------------------


func test_fp_projection_settings() -> void:
	var cam := _make_fp(_make_player())
	assert_true(cam.top_level, "top level")
	assert_eq(cam.keep_aspect, Camera3D.KEEP_WIDTH, "fov is horizontal")
	assert_almost_eq(cam.near, 0.05, 0.000001, "near plane")
	assert_almost_eq(cam.fov, Tuning.data.fov_deg, 0.0001, "fov from tuning")
	assert_false(cam.get_cull_mask_value(CombatTypes.VIS_FP_HIDDEN), "head layer hidden")
	assert_true(cam.get_cull_mask_value(CombatTypes.VIS_DEFAULT), "default layer visible")
	assert_true(cam.get_cull_mask_value(CombatTypes.VIS_DEBUG), "debug layer visible")
	Tuning.set_value(&"fov_deg", 105.0)
	cam.update_camera(DT)
	assert_almost_eq(cam.fov, 105.0, 0.0001, "fov is read live")


func test_fp_converges_to_eye_point() -> void:
	var player := _make_player(Vector3(2.0, 0.0, -3.0))
	player.state = CombatTypes.ActorState.KO
	var cam := _make_fp(player)
	cam.update_camera(DT)
	assert_almost_eq(cam.global_position, player.get_eye_transform().origin, V_EPS,
			"first update snaps to the eye")

	var shift := Vector3(0.3, -0.2, 0.1)
	player.eye_offset += shift
	var tau := Tuning.data.cam_smoothing_s
	cam.update_camera(tau)
	assert_almost_eq(player.get_eye_transform().origin - cam.global_position,
			shift * exp(-1.0), V_EPS, "one time constant leaves 1/e of the gap")

	_run_fp(cam, 1.0)
	assert_almost_eq(cam.global_position, player.get_eye_transform().origin, V_EPS,
			"converges to the eye")


func test_fp_smoothing_is_frame_rate_independent() -> void:
	var player_a := _make_player()
	var player_b := _make_player()
	var cam_a := _make_fp(player_a)
	var cam_b := _make_fp(player_b)
	cam_a.update_camera(DT)
	cam_b.update_camera(DT)
	player_a.eye_offset += Vector3(0.0, -0.3, 0.2)
	player_b.eye_offset += Vector3(0.0, -0.3, 0.2)
	_run_fp(cam_a, 0.05, DT)
	_run_fp(cam_b, 0.05, 1.0 / 240.0)
	assert_almost_eq(cam_a.global_position, cam_b.global_position, V_EPS,
			"same position at 60 and 240 fps")


func test_fp_follows_body_motion_without_lag() -> void:
	var player := _make_player()
	var cam := _make_fp(player)
	cam.update_camera(DT)
	player.global_position += Vector3(1.5, 0.4, -0.7)
	cam.update_camera(DT)
	assert_almost_eq(cam.global_position, player.get_eye_transform().origin, V_EPS,
			"moving the whole body moves the camera at once; only head motion is smoothed")


func test_fp_moves_evenly_between_physics_ticks_with_interpolation() -> void:
	# Physics interpolation on, as the project needs it, and more frames than physics
	# ticks: 24 Hz physics under a 60 fps frame cap gives 2.5 frames per tick, as a 144 Hz
	# display does at 60 Hz, so most frames land between ticks. Lowering the tick rate
	# rather than raising the frame rate keeps that true when the runner steps fixed
	# 1/60 s frames (--fixed-fps 60) as well as in real time.
	var old_interpolation := get_tree().physics_interpolation
	var old_max_fps := Engine.max_fps
	var old_ticks := Engine.physics_ticks_per_second
	get_tree().physics_interpolation = true
	Engine.max_fps = 60
	Engine.physics_ticks_per_second = 24
	var player := MovingPlayer.new()
	player.name = "MovingPlayer"
	add_child_autofree(player)
	var director := _make_director()
	var recorder := FrameRecorder.new()
	recorder.camera = director.first_person_camera
	recorder.player = player
	add_child_autofree(recorder)
	await wait_physics_frames(24)
	var meters_per_tick := player.speed / float(Engine.physics_ticks_per_second)
	get_tree().physics_interpolation = old_interpolation
	Engine.max_fps = old_max_fps
	Engine.physics_ticks_per_second = old_ticks
	recorder.set_process(false)
	player.set_physics_process(false)

	var max_rate_error := 0.0
	var max_body_gap := 0.0
	var between_ticks := 0
	# Skip the first frames while the interpolation history fills up.
	for i: int in range(6, recorder.ticks.size()):
		max_body_gap = maxf(max_body_gap, absf(recorder.camera_x[i] - recorder.player_x[i]))
		var elapsed := recorder.ticks[i] - recorder.ticks[i - 1]
		if elapsed < 0.05:
			continue
		if absf(elapsed - roundf(elapsed)) > 0.05:
			between_ticks += 1
		var rate := (recorder.camera_x[i] - recorder.camera_x[i - 1]) / elapsed
		max_rate_error = maxf(max_rate_error, absf(rate - meters_per_tick))
	assert_gt(between_ticks, 10, "many frames advanced by part of a tick")
	assert_lt(max_rate_error, 0.002,
			"every frame moves the view in proportion to the time it covers: even steps")
	assert_lt(max_body_gap, 0.0005, "the view stays with the interpolated body")


func test_fp_uses_look_basis_never_the_head() -> void:
	var player := _make_player(Vector3(1.0, 0.0, 1.0))
	player.look_yaw = 0.8
	player.look_pitch = -0.4
	assert_false(player.get_eye_transform().basis.is_equal_approx(player.get_look_basis()),
			"the head points elsewhere than the look, so the test can tell them apart")
	var cam := _make_fp(player)
	cam.update_camera(DT)
	_assert_basis_almost_eq(cam.global_basis, player.get_look_basis(), "rotation = look basis")
	player.look_yaw = -2.0
	player.look_pitch = 0.3
	cam.update_camera(DT)
	_assert_basis_almost_eq(cam.global_basis, player.get_look_basis(),
			"rotation follows look at once")
	# The head animates (a flinch snaps it sideways); the view does not turn with it.
	player.head_basis = Basis.from_euler(Vector3(-0.5, 1.2, -0.4))
	cam.update_camera(DT)
	_assert_basis_almost_eq(cam.global_basis, player.get_look_basis(),
			"head motion never turns the view")


func test_fp_lens_sits_lower_and_ahead_of_the_eye() -> void:
	Tuning.data.cam_forward_offset_m = 0.12
	Tuning.data.cam_height_offset_m = -0.2
	var player := _make_player(Vector3(1.0, 0.0, 1.0))
	player.look_yaw = 0.8
	player.look_pitch = -0.6
	var cam := _make_fp(player)
	cam.update_camera(DT)
	var flat := Vector3(-sin(0.8), 0.0, -cos(0.8))
	var expected := player.get_eye_transform().origin + flat * 0.12 + Vector3.DOWN * 0.2
	assert_almost_eq(cam.global_position.distance_to(expected), 0.0, 0.002,
			"0.2 m below and 0.12 m ahead of the eye, level even when looking down")
	assert_almost_eq(FirstPersonCamera.lens_offset(player.get_look_basis()).distance_to(flat * 0.12 + Vector3.DOWN * 0.2),
			0.0, 0.0001, "lens_offset() matches the camera")


func test_fp_applies_move_pitch_and_drop() -> void:
	var player := _make_player()
	player.look_yaw = 0.5
	player.look_pitch = 0.1
	player.move_offset = Vector2(-10.0, 0.05)
	var cam := _make_fp(player)
	cam.update_camera(DT)
	var expected := Basis.from_euler(Vector3(0.1 + deg_to_rad(-10.0), 0.5, 0.0))
	_assert_basis_almost_eq(cam.global_basis, expected, "pitched down 10 degrees")
	assert_almost_eq(cam.global_position, player.get_eye_transform().origin + Vector3.DOWN * 0.05,
			V_EPS, "dropped 5 cm along world -Y")


func test_fp_total_pitch_never_flips() -> void:
	var player := _make_player()
	player.look_pitch = deg_to_rad(-85.0)
	player.move_offset = Vector2(-25.0, 0.05)
	var cam := _make_fp(player)
	cam.update_camera(DT)
	assert_almost_eq(cam.global_basis.get_euler().x, deg_to_rad(-89.0), 0.0001, "clamped")
	assert_gt(cam.global_basis.y.y, 0.0, "camera up still points up")


func test_fp_bob_clamp_only_while_walking() -> void:
	var player := _make_player(Vector3(0.0, 0.5, 0.0))
	var idle := player.standing_eye_height
	var cam := _make_fp(player)
	var base := player.global_position.y + idle
	var bob := Tuning.data.cam_bob_clamp_m

	player.walking = true
	player.eye_offset = Vector3(0.0, idle + 0.1, 0.0)
	_run_fp(cam, 1.0)
	assert_almost_eq(cam.global_position.y - base, bob, EPS, "clamped above while walking")
	player.eye_offset = Vector3(0.0, idle - 0.1, 0.0)
	_run_fp(cam, 1.0)
	assert_almost_eq(cam.global_position.y - base, -bob, EPS, "clamped below while walking")
	player.eye_offset = Vector3(0.0, idle + 0.01, 0.0)
	_run_fp(cam, 1.0)
	assert_almost_eq(cam.global_position.y - base, 0.01, EPS, "small bob passes through")

	player.walking = false
	player.eye_offset = Vector3(0.0, idle - 0.3, 0.0)
	_run_fp(cam, 1.0)
	assert_almost_eq(cam.global_position.y - base, -0.3, EPS, "no clamp when not walking")

	Tuning.set_value(&"cam_bob_clamp_m", 0.03)
	player.walking = true
	_run_fp(cam, 1.0)
	assert_almost_eq(cam.global_position.y - base, -0.03, EPS, "clamp is read live")


func test_fp_never_writes_player_state() -> void:
	var player := _make_player(Vector3(1.0, 0.0, 2.0))
	player.look_yaw = 0.3
	player.look_pitch = -0.2
	var cam := _make_fp(player)
	var dummy := _make_dummy(Vector3(1.0, 0.0, 1.0))
	cam.update_camera(DT)
	CombatEvents.hit_landed.emit(_hit(player, dummy, CombatTypes.HitTier.FINISHER,
			Vector3(1.0, 1.5, 1.2), Vector3.FORWARD))
	_run_fp(cam, 0.5)
	assert_eq(player.global_position, Vector3(1.0, 0.0, 2.0))
	assert_eq(player.look_yaw, 0.3)
	assert_eq(player.look_pitch, -0.2)
	assert_eq(player.state, CombatTypes.ActorState.FREE)


# --- hit feel ------------------------------------------------------------------------


func test_trauma_adds_clamps_and_decays() -> void:
	var cam := _make_fp(_make_player())
	cam.add_trauma(0.7)
	cam.add_trauma(0.7)
	assert_eq(cam.trauma, 1.0, "clamped to 1")
	cam.update_camera(0.2)
	assert_almost_eq(cam.trauma, 1.0 - 0.2 * cam.trauma_decay_per_s, 0.0001, "decays linearly")
	cam.add_trauma(-5.0)
	assert_eq(cam.trauma, 0.0, "clamped to 0")


func test_shake_from_player_hit_moves_view_then_returns_to_rest() -> void:
	# No camera punch, so whatever moves the view is the hit's trauma shake alone.
	Tuning.set_value(&"cam_punch_finisher_deg", 0.0)
	var player := _make_player()
	var cam := _make_fp(player)
	var dummy := _make_dummy(Vector3(0.0, 0.0, -0.9))
	cam.update_camera(DT)
	CombatEvents.hit_landed.emit(_hit(player, dummy, CombatTypes.HitTier.FINISHER,
			Vector3(0.0, 1.5, -0.7), Vector3.FORWARD))
	assert_almost_eq(cam.trauma, Tuning.data.shake_finisher, 0.0001, "finisher trauma added")

	var max_offset := 0.0
	var max_angle := 0.0
	for i: int in 20:
		cam.update_camera(DT)
		assert_eq(cam.get_punch_deg(), Vector2.ZERO, "no punch at 0 degrees")
		var view := cam.view_transform()
		max_offset = maxf(max_offset, cam.global_position.distance_to(view.origin))
		var local_rot := (view.basis.inverse() * cam.global_basis).get_euler().abs()
		max_angle = maxf(max_angle, maxf(local_rot.x, maxf(local_rot.y, local_rot.z)))
	assert_gt(max_offset, 0.001, "the hit's shake moves the view (a punch never offsets it)")
	assert_gt(max_angle, deg_to_rad(0.05), "the hit's shake turns the view")

	_run_fp(cam, 1.0)
	assert_true(cam.is_settled(), "trauma and punch gone after a second")
	_assert_transform_almost_eq(cam.global_transform, cam.view_transform(), "back at rest")
	assert_almost_eq(cam.global_position, player.get_eye_transform().origin, V_EPS, "at the eye")


func test_shake_bounds_at_full_trauma() -> void:
	var cam := _make_fp(_make_player())
	cam.update_camera(DT)
	cam.add_trauma(1.0)
	var max_offset := Vector3.ZERO
	var max_rot := Vector3.ZERO
	for i: int in 120:
		cam.update_camera(1.0 / 240.0)
		var view := cam.view_transform()
		var local_offset := view.basis.inverse() * (cam.global_position - view.origin)
		var local_rot := (view.basis.inverse() * cam.global_basis).get_euler()
		max_offset = max_offset.max(local_offset.abs())
		max_rot = max_rot.max(local_rot.abs())
	var limit_rad := deg_to_rad(cam.shake_max_deg) + 0.0001
	assert_lte(maxf(max_rot.x, maxf(max_rot.y, max_rot.z)), limit_rad, "rotation within 3 degrees")
	var limit_m := cam.shake_max_offset_m + 0.0001
	assert_lte(maxf(max_offset.x, maxf(max_offset.y, max_offset.z)), limit_m, "offset within 4 cm")
	assert_gt(max_offset.length(), 0.004, "full trauma visibly shakes")


func test_shake_intensity_zero_disables_shake() -> void:
	var cam := _make_fp(_make_player())
	cam.update_camera(DT)
	Tuning.set_value(&"screen_shake_intensity", 0.0)
	cam.add_trauma(1.0)
	for i: int in 10:
		cam.update_camera(DT)
		_assert_transform_almost_eq(cam.global_transform, cam.view_transform(), "no shake at 0")


func test_shake_decays_in_real_time_during_hitstop() -> void:
	var player := _make_player()
	var cam := _make_fp(player)
	# Driven by hand below; its own frames would also decay the trauma.
	cam.set_process(false)
	cam.update_camera(DT)
	cam.add_trauma(0.8)
	# Hitstop freezes from the next physics tick on.
	TimeController.hitstop([player], 1.0)
	await wait_physics_frames(1)
	var frozen := TimeController.is_in_hitstop(player)
	var before := cam.trauma
	var decay_per_s := cam.trauma_decay_per_s
	cam.update_camera(0.1)
	var after := cam.trauma
	# With trauma held constant, only the noise running on can move the view.
	cam.trauma_decay_per_s = 0.0
	cam.update_camera(DT)
	var first := cam.global_transform
	cam.update_camera(DT)
	var second := cam.global_transform
	var still_frozen := TimeController.is_in_hitstop(player)
	TimeController.clear()
	assert_true(frozen, "the player is in hitstop while the camera updates")
	assert_true(still_frozen, "and still is at the end")
	assert_almost_eq(after, before - 0.1 * decay_per_s, 0.0001,
			"trauma keeps decaying in real time while the player is frozen")
	var moved := first.origin.distance_to(second.origin)
	var turned := first.basis.get_rotation_quaternion().angle_to(
			second.basis.get_rotation_quaternion())
	assert_gt(moved + turned, 0.0005, "the shake keeps moving while the player is frozen")


func test_punch_toward_contact_when_attacking_springs_back() -> void:
	var player := _make_player()
	var cam := _make_fp(player)
	var dummy := _make_dummy(Vector3(-0.6, 0.0, -0.6))
	cam.update_camera(DT)
	# Contact ahead and to the left at eye height: the view turns left (positive yaw).
	var contact := player.get_eye_transform().origin + Vector3(-0.5, 0.0, -0.6)
	CombatEvents.hit_landed.emit(_hit(player, dummy, CombatTypes.HitTier.HEAVY, contact,
			Vector3(-0.7, 0.0, -0.7)))
	var peak := Vector2.ZERO
	var peak_forward := Vector3.FORWARD
	var dt := 1.0 / 480.0
	for i: int in roundi(0.15 / dt):
		cam.update_camera(dt)
		var punch := cam.get_punch_deg()
		if punch.length() > peak.length():
			peak = punch
			peak_forward = -cam.global_basis.z
	assert_almost_eq(peak.length(), Tuning.data.cam_punch_heavy_deg, 0.02,
			"peaks at the tier's degrees")
	assert_gt(peak.y, 0.0, "yaws left toward the contact")
	assert_almost_eq(peak.x, 0.0, 0.05, "no pitch for a contact at eye height")
	assert_lt(peak_forward.x, 0.0, "the camera actually turned left")
	assert_eq(cam.get_punch_deg(), Vector2.ZERO, "sprung back within 0.12 s")
	_assert_transform_almost_eq(cam.global_transform, cam.view_transform(), "at rest")


## Highest get_punch_deg() length while updating `cam` for `seconds` in small steps.
func _peak_punch_deg(cam: FirstPersonCamera, seconds: float) -> float:
	var peak := 0.0
	var dt := 1.0 / 480.0
	for i: int in roundi(seconds / dt):
		cam.update_camera(dt)
		peak = maxf(peak, cam.get_punch_deg().length())
	return peak


func test_same_frame_hits_punch_once_at_the_tier_value() -> void:
	Tuning.set_value(&"screen_shake_intensity", 0.0)
	var player := _make_player()
	var cam := _make_fp(player)
	cam.update_camera(DT)
	var eye := player.get_eye_transform().origin
	var tier_deg := Tuning.data.cam_punch_finisher_deg

	# One strike hits two victims standing close together, ahead and to the left.
	var a := _make_dummy(Vector3(-0.5, 0.0, -0.8))
	var b := _make_dummy(Vector3(-0.4, 0.0, -0.9))
	CombatEvents.hit_landed.emit(_hit(player, a, CombatTypes.HitTier.FINISHER,
			eye + Vector3(-0.5, -0.2, -0.6), Vector3.FORWARD))
	CombatEvents.hit_landed.emit(_hit(player, b, CombatTypes.HitTier.FINISHER,
			eye + Vector3(-0.4, -0.2, -0.7), Vector3.FORWARD))
	assert_almost_eq(_peak_punch_deg(cam, 0.15), tier_deg, 0.02,
			"two victims in one frame punch once, at the tier's degrees")
	assert_eq(cam.get_punch_deg(), Vector2.ZERO, "and springs back")

	# A spin kick hits three victims: left, center and right at chest height.
	for x: float in [-0.9, 0.0, 0.9]:
		var victim := _make_dummy(Vector3(x, 0.0, -0.9))
		CombatEvents.hit_landed.emit(_hit(player, victim, CombatTypes.HitTier.FINISHER,
				eye + Vector3(x, -0.3, -0.7), Vector3.FORWARD))
	assert_lte(_peak_punch_deg(cam, 0.15), tier_deg + 0.02, "three victims: still one punch")

	# A second hit landing while the first punch springs back overlaps it, capped too.
	CombatEvents.hit_landed.emit(_hit(player, a, CombatTypes.HitTier.FINISHER,
			eye + Vector3(-0.5, 0.0, -0.6), Vector3.FORWARD))
	var peak := _peak_punch_deg(cam, 0.04)
	CombatEvents.hit_landed.emit(_hit(player, b, CombatTypes.HitTier.FINISHER,
			eye + Vector3(-0.5, 0.0, -0.6), Vector3.FORWARD))
	peak = maxf(peak, _peak_punch_deg(cam, 0.2))
	assert_almost_eq(peak, tier_deg, 0.02, "overlapping punches never pass the tier's degrees")
	assert_eq(cam.get_punch_deg(), Vector2.ZERO, "all punches over")


func test_punches_while_snapping_out_merge_into_one() -> void:
	var player := _make_player()
	var single := _make_fp(player)
	var merged := _make_fp(player)
	single.update_camera(DT)
	merged.update_camera(DT)
	single.add_punch(Vector2(0.0, 3.0))
	merged.add_punch(Vector2(0.0, 3.0))
	merged.add_punch(Vector2(0.0, 3.0))
	merged.add_punch(Vector2(0.0, 1.5))
	var dt := 1.0 / 480.0
	for i: int in roundi(0.15 / dt):
		single.update_camera(dt)
		merged.update_camera(dt)
		assert_almost_eq(merged.get_punch_deg(), single.get_punch_deg(), Vector2(0.001, 0.001),
				"same curve as one punch at %.3f s" % (i * dt))

	# Two kicks at right angles: one punch halfway between them, as strong as the stronger.
	merged.add_punch(Vector2(2.0, 0.0))
	merged.add_punch(Vector2(0.0, 3.0))
	var peak := Vector2.ZERO
	for i: int in roundi(0.15 / dt):
		merged.update_camera(dt)
		if merged.get_punch_deg().length() > peak.length():
			peak = merged.get_punch_deg()
	assert_almost_eq(peak.length(), 3.0, 0.02, "as strong as the stronger kick")
	assert_almost_eq(peak.normalized(), Vector2(2.0, 3.0).normalized(), Vector2(0.01, 0.01),
			"toward the combined direction")


func test_punch_dips_for_centered_contact() -> void:
	var player := _make_player()
	var cam := _make_fp(player)
	var dummy := _make_dummy(Vector3(0.0, 0.0, -0.9))
	cam.update_camera(DT)
	var contact := player.get_eye_transform().origin + Vector3(0.0, 0.0, -0.7)
	CombatEvents.hit_landed.emit(_hit(player, dummy, CombatTypes.HitTier.LIGHT, contact,
			Vector3.FORWARD))
	cam.update_camera(0.03)
	var punch := cam.get_punch_deg()
	assert_lt(punch.x, 0.0, "dips down into a hit straight ahead")
	assert_almost_eq(punch.y, 0.0, 0.0001, "no yaw")


func test_punch_jolts_away_when_player_is_hit() -> void:
	var player := _make_player()
	var cam := _make_fp(player)
	var enemy := _make_dummy(Vector3(0.0, 0.0, -0.9))
	cam.update_camera(DT)
	# Hit in the face from the front: pushed toward +Z (backward), the head tips up.
	var contact := player.get_eye_transform().origin + Vector3(0.0, 0.0, -0.1)
	CombatEvents.hit_landed.emit(_hit(enemy, player, CombatTypes.HitTier.FINISHER, contact,
			Vector3.BACK))
	assert_almost_eq(cam.trauma, Tuning.data.shake_finisher, 0.0001, "victim gets trauma too")
	Tuning.set_value(&"screen_shake_intensity", 0.0)
	cam.update_camera(0.03)
	var punch := cam.get_punch_deg()
	assert_gt(punch.x, 0.0, "head snaps back (pitch up)")
	assert_gt((-cam.global_basis.z).y, 0.0, "camera looks up")

	# Pushed to the right turns the view right (negative yaw).
	_run_fp(cam, 0.2)
	CombatEvents.hit_landed.emit(_hit(enemy, player, CombatTypes.HitTier.HEAVY, contact,
			Vector3.RIGHT))
	cam.update_camera(0.03)
	assert_lt(cam.get_punch_deg().y, 0.0, "jolts right with a push to the right")
	_run_fp(cam, 0.2)
	assert_eq(cam.get_punch_deg(), Vector2.ZERO, "springs back")


func test_blocked_hits_shake_and_punch_the_view_less() -> void:
	# A hit the player's guard stopped (hit.blocked) still jolts the view, scaled down by
	# blocked_feel_scale.
	var player := _make_player()
	var cam := _make_fp(player)
	var enemy := _make_dummy(Vector3(0.0, 0.0, -0.9))
	cam.update_camera(DT)
	var contact := player.get_eye_transform().origin + Vector3(0.0, 0.0, -0.3)
	var hit := _hit(enemy, player, CombatTypes.HitTier.LIGHT, contact, Vector3.BACK)
	hit.blocked = true
	CombatEvents.hit_landed.emit(hit)
	assert_almost_eq(cam.trauma, Tuning.data.shake_light * cam.blocked_feel_scale, 0.0001, "less trauma")
	assert_lt(cam.blocked_feel_scale, 1.0)
	Tuning.set_value(&"screen_shake_intensity", 0.0)
	cam.update_camera(0.03)
	var blocked_punch := cam.get_punch_deg().length()
	assert_gt(blocked_punch, 0.0, "the guard still jolts the view")
	_run_fp(cam, 1.0)
	CombatEvents.hit_landed.emit(_hit(enemy, player, CombatTypes.HitTier.LIGHT, contact, Vector3.BACK))
	cam.update_camera(0.03)
	assert_almost_eq(blocked_punch, cam.get_punch_deg().length() * cam.blocked_feel_scale, 0.001,
			"a clean hit punches harder")


func test_ignores_hits_without_the_player() -> void:
	var player := _make_player()
	var cam := _make_fp(player)
	var a := _make_dummy(Vector3(2.0, 0.0, 0.0))
	var b := _make_dummy(Vector3(3.0, 0.0, 0.0))
	cam.update_camera(DT)
	CombatEvents.hit_landed.emit(_hit(a, b, CombatTypes.HitTier.FINISHER, Vector3(2.5, 1.5, 0.0),
			Vector3.RIGHT))
	cam.update_camera(0.03)
	assert_true(cam.is_settled(), "no trauma or punch from other fights")


# --- side view -----------------------------------------------------------------------


func test_side_view_frames_the_street_and_follows_x() -> void:
	var player := _make_player(Vector3(0.0, 0.0, 2.0))
	var cam := SideViewCamera.new()
	add_child_autofree(cam)
	cam.player = player
	cam.update_camera(DT)
	assert_almost_eq(cam.fov, 38.0, 0.0001, "narrow perspective")
	assert_true(cam.get_cull_mask_value(CombatTypes.VIS_FP_HIDDEN), "the player's head shows")
	assert_true(cam.get_cull_mask_value(CombatTypes.VIS_DEFAULT))
	assert_true(cam.get_cull_mask_value(CombatTypes.VIS_DEBUG))
	assert_almost_eq(cam.global_position, Vector3(0.0, 3.5, 13.0), V_EPS, "11 m out, 3.5 m up")
	var aim := (player.global_position + Vector3.UP - cam.global_position).normalized()
	assert_almost_eq(-cam.global_basis.z, aim, V_EPS, "looks at the player's waist")
	assert_lt((-cam.global_basis.z).z, 0.0, "looks toward -Z")
	var basis_before := cam.global_basis

	player.global_position.x = 5.0
	cam.update_camera(DT)
	assert_between(cam.global_position.x, 0.01, 4.99, "follows X smoothly, not instantly")
	for i: int in 120:
		cam.update_camera(DT)
	assert_almost_eq(cam.global_position.x, 5.0, 0.001, "catches up along X")
	_assert_basis_almost_eq(cam.global_basis, basis_before, "pans without turning")

	player.global_position.z = -1.0
	for i: int in 600:
		cam.update_camera(DT)
	assert_almost_eq(cam.global_position.z, -1.0 + 11.0, 0.001, "keeps its distance in depth")


# --- free fly ------------------------------------------------------------------------


func test_free_fly_starts_at_previous_camera() -> void:
	var player := _make_player(Vector3(1.0, 0.0, -2.0))
	player.look_yaw = 0.9
	player.look_pitch = -0.2
	var director := _make_director()
	assert_eq(director.player, player as PlayerCharacter, "found the existing player in _ready")
	director.first_person_camera.update_camera(DT)
	director.side_view_camera.update_camera(DT)
	director.cycle()
	director.cycle()
	assert_eq(director.mode, CameraDirector.MODE_FREE_FLY)
	_assert_transform_almost_eq(director.free_fly_camera.global_transform,
			director.side_view_camera.global_transform, "starts at the side view")
	assert_almost_eq(director.free_fly_camera.fov, director.side_view_camera.fov, 0.0001)

	var other := _make_director()
	other.first_person_camera.update_camera(DT)
	other.set_mode(CameraDirector.MODE_FREE_FLY)
	_assert_transform_almost_eq(other.free_fly_camera.global_transform,
			other.first_person_camera.global_transform, "starts at the first-person view")
	assert_eq(other.free_fly_camera.keep_aspect, Camera3D.KEEP_WIDTH, "keeps the FP projection")


func test_free_fly_chosen_before_the_director_enters_the_tree() -> void:
	var player := _make_player(Vector3(1.0, 0.0, -2.0))
	player.look_yaw = 0.7
	player.look_pitch = -0.3
	var director := CameraDirector.new()
	watch_signals(director)
	director.set_mode(CameraDirector.MODE_FREE_FLY)
	assert_signal_emit_count(director, "camera_changed", 1)
	add_child_autofree(director)
	assert_eq(director.mode, CameraDirector.MODE_FREE_FLY)
	assert_true(director.free_fly_camera.current, "free fly is current once in the tree")
	assert_eq(_current_count(director), 1, "exactly one current camera")
	# The first-person camera places itself before free fly in a frame (tree order).
	director.first_person_camera.update_camera(DT)
	director.free_fly_camera.update_camera(DT)
	_assert_transform_almost_eq(director.free_fly_camera.global_transform,
			director.first_person_camera.global_transform, "starts at the first-person view")
	assert_almost_eq(director.free_fly_camera.fov, Tuning.data.fov_deg, 0.0001,
			"with the first-person field of view, not Camera3D's default")
	assert_eq(director.free_fly_camera.keep_aspect, Camera3D.KEEP_WIDTH, "and its projection")
	director.free_fly_camera.fly(0.0, Vector3.ZERO, Vector2(0.0, 50.0))
	var pitch := -0.3 - deg_to_rad(50.0 * Tuning.data.mouse_sensitivity)
	_assert_basis_almost_eq(director.free_fly_camera.global_basis,
			Basis.from_euler(Vector3(pitch, 0.7, 0.0)), "looks on from the copied view")


func test_free_fly_levels_shake_roll_on_activation() -> void:
	var player := _make_player(Vector3(1.0, 0.0, -2.0))
	player.look_yaw = 0.4
	player.look_pitch = -0.2
	var director := _make_director()
	var fp := director.first_person_camera
	var fly := director.free_fly_camera
	fp.update_camera(DT)
	fp.add_trauma(1.0)
	# Shake until the view is visibly rolled.
	var rolled := false
	for i: int in 30:
		fp.update_camera(DT)
		if absf(fp.global_basis.get_euler().z) > deg_to_rad(0.5):
			rolled = true
			break
	assert_true(rolled, "the shake rolls the first-person view")
	director.set_mode(CameraDirector.MODE_FREE_FLY)
	assert_almost_eq(fly.global_position, fp.global_position, V_EPS, "starts at the shaken view")
	assert_almost_eq(-fly.global_basis.z, -fp.global_basis.z, V_EPS, "looking the same way")
	assert_almost_eq(fly.global_basis.get_euler().z, 0.0, 0.0001, "with the roll leveled")
	var start := fly.global_basis.get_euler()
	fly.fly(0.0, Vector3.ZERO, Vector2(1.0, 0.0))
	var yaw := start.y - deg_to_rad(Tuning.data.mouse_sensitivity)
	_assert_basis_almost_eq(fly.global_basis, Basis.from_euler(Vector3(start.x, yaw, 0.0)),
			"a 1-pixel mouse move turns 1 pixel's worth and nothing snaps")


func test_free_fly_steers_with_the_fly_mouse_delta_only() -> void:
	# Another camera holds the viewport, or the first camera added would become current.
	var other := Camera3D.new()
	add_child_autofree(other)
	other.make_current()
	var cam := FreeFlyCamera.new()
	add_child_autofree(cam)
	# Driven by hand below; its own frames would also consume the deltas.
	cam.set_process(false)
	cam.activate_from(null)
	cam.make_current()
	var player_delta := Vector2(7.0, -3.0)
	GameInput.consume_mouse_delta()
	GameInput._mouse_delta = player_delta
	GameInput._fly_mouse_delta = Vector2(50.0, 0.0)
	cam.update_camera(DT)
	var player_left := GameInput.consume_mouse_delta()
	var fly_left := GameInput.consume_fly_mouse_delta()
	var yaw := -deg_to_rad(50.0 * Tuning.data.mouse_sensitivity)
	_assert_basis_almost_eq(cam.global_basis, Basis.from_euler(Vector3(0.0, yaw, 0.0)),
			"turned by the fly mouse delta alone")
	assert_eq(fly_left, Vector2.ZERO, "the fly delta was consumed")
	assert_eq(player_left, player_delta, "the player's mouse delta is left for the player")


func test_free_fly_moves_in_look_direction_frame_rate_independent() -> void:
	var start := Transform3D(Basis.from_euler(Vector3(-0.3, PI * 0.5, 0.0)), Vector3(1.0, 2.0, 3.0))
	var a := FreeFlyCamera.new()
	var b := FreeFlyCamera.new()
	add_child_autofree(a)
	add_child_autofree(b)
	a.global_transform = start
	b.global_transform = start
	a.activate_from(null)
	b.activate_from(null)
	a.fly(0.5, Vector3(0.0, 0.0, -1.0), Vector2.ZERO)
	for i: int in 50:
		b.fly(0.01, Vector3(0.0, 0.0, -1.0), Vector2.ZERO)
	var expected := start.origin - start.basis.z * a.fly_speed * 0.5
	assert_almost_eq(a.global_position, expected, V_EPS, "3 m along the look direction")
	assert_almost_eq(b.global_position, expected, V_EPS, "same at a higher frame rate")

	a.global_position = start.origin
	a.fly(1.0, Vector3(0.0, 1.0, 0.0), Vector2.ZERO)
	assert_almost_eq(a.global_position, start.origin + Vector3.UP * a.fly_speed, V_EPS,
			"up is world up")

	a.fly(0.0, Vector3.ZERO, Vector2(100.0, 0.0))
	var yaw := PI * 0.5 - deg_to_rad(100.0 * Tuning.data.mouse_sensitivity)
	var turned := Basis.from_euler(Vector3(-0.3, yaw, 0.0))
	_assert_basis_almost_eq(a.global_basis, turned, "mouse right turns right")


func test_free_fly_reads_fly_actions_only_when_current() -> void:
	# Another camera holds the viewport, or the first camera added would become current.
	var other := Camera3D.new()
	add_child_autofree(other)
	other.make_current()
	var cam := FreeFlyCamera.new()
	add_child_autofree(cam)
	cam.activate_from(null)
	Input.action_press(&"fly_forward")
	cam.update_camera(0.5)
	assert_almost_eq(cam.global_position, Vector3.ZERO, V_EPS, "not current: stays put")
	cam.make_current()
	cam.update_camera(0.5)
	Input.action_release(&"fly_forward")
	assert_almost_eq(cam.global_position, Vector3(0.0, 0.0, -0.5 * cam.fly_speed), V_EPS,
			"current: flies forward")
