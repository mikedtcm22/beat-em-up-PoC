extends GutTest
## LD-STAGE's CineCamera: its path function (the keys, the spline, the eases, the focus), the camera it drives (the pose, the lens, the
## depth of field) and the data of its keys.


func _key(t: float, pos: Vector3, look: Vector3 = Vector3(0, 0, -10), fov: float = 60.0, focus: float = 0.0) -> CineCameraKey:
	var key := CineCameraKey.new()
	key.time_s = t
	key.position = pos
	key.look_at = look
	key.fov_deg = fov
	key.focus_m = focus
	return key


func _keys() -> Array[CineCameraKey]:
	return [_key(0.0, Vector3(0, 8, 2)), _key(2.0, Vector3(1, 5, 1), Vector3(0, 0, -12), 50.0), _key(4.0, Vector3(2, 2, 0), Vector3(0, 0, -8), 40.0)]


func test_the_path_holds_before_the_first_key_and_after_the_last() -> void:
	var keys := _keys()
	assert_eq(CineCamera.sample(keys, -1.0, Vector3.ZERO).position, Vector3(0, 8, 2))
	assert_eq(CineCamera.sample(keys, 9.0, Vector3.ZERO).position, Vector3(2, 2, 0))
	assert_almost_eq(CineCamera.sample(keys, 9.0, Vector3.ZERO).fov_deg, 40.0, 0.001)


func test_the_path_passes_through_each_key() -> void:
	var keys := _keys()
	for key in keys:
		var pose := CineCamera.sample(keys, key.time_s, Vector3.ZERO)
		assert_true(pose.position.is_equal_approx(key.position), "key at %s: position %s" % [key.time_s, pose.position])
		assert_true(pose.look_at.is_equal_approx(key.look_at), "key at %s: look-at" % key.time_s)
		assert_almost_eq(pose.fov_deg, key.fov_deg, 0.001, "key at %s: lens" % key.time_s)


func test_the_origin_moves_the_whole_path() -> void:
	var keys := _keys()
	var origin := Vector3(3, 4.5, -53)
	var a := CineCamera.sample(keys, 1.3, Vector3.ZERO)
	var b := CineCamera.sample(keys, 1.3, origin)
	assert_true((b.position - a.position).is_equal_approx(origin))
	assert_true((b.look_at - a.look_at).is_equal_approx(origin))


func test_a_smooth_segment_starts_and_ends_slowly_and_a_linear_one_does_not() -> void:
	var smooth: Array[CineCameraKey] = [_key(0.0, Vector3.ZERO), _key(1.0, Vector3(10, 0, 0))]
	var linear: Array[CineCameraKey] = [_key(0.0, Vector3.ZERO), _key(1.0, Vector3(10, 0, 0))]
	linear[0].ease = CineCameraKey.Ease.LINEAR
	var early_smooth := CineCamera.sample(smooth, 0.1, Vector3.ZERO).position.x
	var early_linear := CineCamera.sample(linear, 0.1, Vector3.ZERO).position.x
	assert_lt(early_smooth, early_linear, "a smoothstep leaves the key slower")
	assert_almost_eq(early_linear, 1.0, 0.05, "a linear segment is even")
	assert_almost_eq(CineCamera.sample(smooth, 0.5, Vector3.ZERO).position.x, 5.0, 0.01, "both meet in the middle")


func test_the_path_is_continuous() -> void:
	var keys := _keys()
	var previous := CineCamera.sample(keys, 0.0, Vector3.ZERO).position
	var step := 0.02
	var t := step
	while t <= 4.0:
		var here := CineCamera.sample(keys, t, Vector3.ZERO).position
		assert_lt(here.distance_to(previous), 0.4, "no jump at %s" % t)
		previous = here
		t += step


func test_the_look_at_can_follow_an_actor() -> void:
	var key := _key(0.0, Vector3(0, 2, 5), Vector3(0, 0.2, 0))
	key.target_actor = 1
	var keys: Array[CineCameraKey] = [key]
	var actors: Array[Vector3] = [Vector3(9, 9, 9), Vector3(4, 1.5, -6)]
	var pose := CineCamera.sample(keys, 0.0, Vector3.ZERO, actors)
	assert_true(pose.look_at.is_equal_approx(Vector3(4, 1.7, -6)), "the actor's point plus the key's offset")
	var missing := CineCamera.sample(keys, 0.0, Vector3.ZERO, [] as Array[Vector3])
	assert_true(missing.look_at.is_equal_approx(key.look_at), "no actor: the point as given")


func test_the_focus_does_not_pop_in() -> void:
	var a := _key(0.0, Vector3.ZERO, Vector3(0, 0, -10), 60.0, 0.0)
	var b := _key(2.0, Vector3(0, 0, -2), Vector3(0, 0, -10), 60.0, 12.0)
	var keys: Array[CineCameraKey] = [a, b]
	assert_almost_eq(CineCamera.sample(keys, 0.2, Vector3.ZERO).focus_m, 12.0, 0.001, "off at one end: the other end's focus")
	b.focus_m = 0.0
	a.focus_m = 8.0
	assert_almost_eq(CineCamera.sample(keys, 1.9, Vector3.ZERO).focus_m, 8.0, 0.001)
	b.focus_m = 16.0
	assert_almost_eq(CineCamera.sample(keys, 1.0, Vector3.ZERO).focus_m, 12.0, 0.2, "both on: a blend")


func test_the_camera_takes_the_pose_and_the_lens() -> void:
	var camera := CineCamera.new()
	add_child_autofree(camera)
	camera.setup(_keys(), Vector3(10, 0, 0))
	camera.set_time(0.0)
	assert_true(camera.global_position.is_equal_approx(Vector3(10, 8, 2)))
	assert_almost_eq(camera.fov, 60.0, 0.001)
	assert_eq(camera.keep_aspect, Camera3D.KEEP_WIDTH, "the FOV is horizontal, as the game's first-person lens")
	var forward := -camera.global_basis.z
	assert_true(forward.is_equal_approx((Vector3(10, 0, -10) - Vector3(10, 8, 2)).normalized()), "looks at its point")
	camera.set_time(4.0)
	assert_almost_eq(camera.fov, 40.0, 0.001)
	assert_eq(camera.shot_time_s, 4.0)


func test_the_depth_of_field_follows_the_focus_keys() -> void:
	var keys: Array[CineCameraKey] = [_key(0.0, Vector3(0, 2, 0), Vector3(0, 1, -10), 60.0, 10.0)]
	var camera := CineCamera.new()
	add_child_autofree(camera)
	camera.setup(keys, Vector3.ZERO)
	camera.set_time(0.0)
	assert_not_null(camera.attributes, "a focus key turns the depth of field on")
	var attributes := camera.attributes as CameraAttributesPractical
	assert_true(attributes.dof_blur_far_enabled)
	assert_almost_eq(attributes.dof_blur_far_distance, 10.0 + keys[0].focus_range_m, 0.001, "sharp up to focus plus the half-depth")
	keys[0].focus_m = 0.0
	camera.set_time(0.0)
	assert_null(camera.attributes, "no focus key: no depth of field")


func test_a_camera_looking_straight_down_does_not_break() -> void:
	var keys: Array[CineCameraKey] = [_key(0.0, Vector3(0, 8, 0), Vector3(0, 0, 0))]
	var camera := CineCamera.new()
	add_child_autofree(camera)
	camera.setup(keys, Vector3.ZERO)
	camera.set_time(0.0)
	assert_true(camera.global_basis.is_finite())
	assert_true((-camera.global_basis.z).is_equal_approx(Vector3.DOWN))


func test_keys_are_sorted_by_time_on_setup() -> void:
	var keys: Array[CineCameraKey] = [_key(3.0, Vector3(3, 0, 0)), _key(1.0, Vector3(1, 0, 0))]
	var camera := CineCamera.new()
	add_child_autofree(camera)
	camera.setup(keys, Vector3.ZERO)
	assert_eq(camera.keys[0].time_s, 1.0)
	assert_eq(keys[0].time_s, 3.0, "the caller's array is left alone")
