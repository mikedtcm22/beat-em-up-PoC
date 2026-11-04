extends GutTest
## The GO cue's arrow (M5, FIX2): drawn as triangles that are valid at every turn. One polygon through
## the engine's triangulation printed "Invalid polygon data" at a few turns (checked below with
## Geometry2D, the way the canvas triangulates), and a non-finite turn must not reach it.

const TURN_STEP_DEG := 0.05
const MIN_AREA_PX2 := 1.0


func _cue() -> GoCue:
	var cue := GoCue.new()
	add_child_autofree(cue)
	return cue


func test_every_arrow_triangle_has_an_area_at_every_turn_and_size() -> void:
	var cue := _cue()
	var worst := INF
	var bad := 0
	for scale_by: float in [0.5, 1.0, 1.07, 1.5, 2.0]:
		for grow: float in [0.0, cue.border * 0.6 * scale_by]:
			for step in int(360.0 / TURN_STEP_DEG) + 1:
				var tris := cue.arrow_triangles(deg_to_rad(step * TURN_STEP_DEG), cue.arrow_length * scale_by, scale_by, grow)
				assert_eq(tris.size() % 3, 0, "whole triangles")
				for i in range(0, tris.size(), 3):
					var area := absf((tris[i + 1] - tris[i]).cross(tris[i + 2] - tris[i])) * 0.5
					worst = minf(worst, area)
					if not (area > MIN_AREA_PX2) or not tris[i].is_finite():
						bad += 1
	assert_eq(bad, 0, "no sliver or non-finite triangle (smallest %.1f px2)" % worst)


func test_every_piece_of_the_arrow_triangulates_at_every_turn() -> void:
	# The single seven-point outline failed this at some turns (34 of 72010 at the sizes swept); the pieces never do.
	var cue := _cue()
	var pieces_ok := true
	for step in 7201:
		var tris := cue.arrow_triangles(deg_to_rad(step * TURN_STEP_DEG), cue.arrow_length, 1.07, 3.8)
		for i in range(0, tris.size(), 3):
			var tri := PackedVector2Array([tris[i], tris[i + 1], tris[i + 2]])
			if Geometry2D.triangulate_polygon(tri).is_empty():
				pieces_ok = false
	assert_true(pieces_ok, "every piece triangulates at every turn")


func test_a_turn_that_is_not_a_number_draws_straight_up() -> void:
	var cue := _cue()
	var nan_turn := cue.arrow_triangles(NAN, cue.arrow_length, 1.0, 0.0)
	var up := cue.arrow_triangles(0.0, cue.arrow_length, 1.0, 0.0)
	assert_eq(nan_turn.size(), up.size())
	for i in nan_turn.size():
		assert_true(nan_turn[i].is_finite(), "point %d is finite" % i)
		assert_true(nan_turn[i].is_equal_approx(up[i]), "and the same as pointing up")


func test_the_cue_draws_over_a_sweep_of_looks_without_an_error() -> void:
	# A frame is drawn at each look; the run's output is read for ERROR lines.
	var cue := _cue()
	cue.size = Vector2(600.0, 180.0)
	var player := PlayerCharacter.new()
	add_child_autofree(player)
	cue.player = player
	player.global_position = Vector3.ZERO
	cue.show_go(Vector3(7.0, 0.0, -24.0))
	for step in 60:
		player.look_yaw = deg_to_rad(step * 6.0)
		cue.advance(0.03)
		await get_tree().process_frame
	assert_true(cue.is_showing(), "still showing after the sweep")


# --- How long "GO" stays (final-sees-05): until the player faces the exit ---------------------------


func _cue_with_player(look_deg: float) -> GoCue:
	Tuning.reset_to_default()
	var cue := _cue()
	cue.size = Vector2(600.0, 180.0)
	var player := PlayerCharacter.new()
	add_child_autofree(player)
	cue.player = player
	player.global_position = Vector3.ZERO
	player.look_yaw = deg_to_rad(look_deg)
	return cue


func _run(cue: GoCue, seconds: float) -> void:
	for i in int(seconds * 10.0):
		cue.advance(0.1)


func test_the_cue_outlasts_go_cue_s_while_the_player_faces_away_and_ends_when_he_faces_the_exit() -> void:
	# The exit is straight ahead (-Z); the player looks 120 degrees away from it.
	var cue := _cue_with_player(120.0)
	cue.show_go(Vector3(0.0, 0.0, -20.0))
	_run(cue, 5.0)
	assert_true(cue.is_showing(), "5 s on (the fixed time was 2 s) and he still faces away")
	cue.player.look_yaw = deg_to_rad(20.0)  # within 30 degrees of the exit
	cue.advance(0.1)
	assert_false(cue.is_showing(), "gone once he faces it")


func test_the_cue_never_goes_before_go_cue_s_even_when_the_player_faces_the_exit() -> void:
	var cue := _cue_with_player(0.0)
	cue.show_go(Vector3(0.0, 0.0, -20.0))
	_run(cue, 1.8)
	assert_true(cue.is_showing(), "1.8 s: still up, facing it from the start")
	_run(cue, 0.5)
	assert_false(cue.is_showing(), "gone just after go_cue_s (2 s)")


func test_the_cue_is_gone_at_the_cap_if_he_never_turns() -> void:
	var cue := _cue_with_player(180.0)
	cue.show_go(Vector3(0.0, 0.0, -20.0))
	_run(cue, 7.5)
	assert_true(cue.is_showing(), "7.5 s: up")
	_run(cue, 1.0)
	assert_false(cue.is_showing(), "gone at the 8 s cap")


func test_the_cue_ends_when_the_player_gets_up_to_the_exit() -> void:
	var cue := _cue_with_player(180.0)
	cue.show_go(Vector3(0.0, 0.0, -20.0))
	_run(cue, 3.0)
	assert_true(cue.is_showing())
	cue.player.global_position = Vector3(0.0, 0.0, -18.0)  # 2 m short of it, looking away
	cue.advance(0.1)
	assert_false(cue.is_showing(), "he is through the barrier: the cue is done")


func test_the_switch_off_restores_the_fixed_time() -> void:
	var cue := _cue_with_player(180.0)
	Tuning.data.go_cue_until_faced = false
	cue.show_go(Vector3(0.0, 0.0, -20.0))
	_run(cue, 2.2)
	assert_false(cue.is_showing(), "2 s and gone, as in the first build")
	Tuning.reset_to_default()
