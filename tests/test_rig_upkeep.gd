extends GutTest
## Rig upkeep (P3-early, F-motion's two requests to HumanoidRig): the named animation libraries are
## rebuilt when a tunable they are built from changes (the Motion subgroup, move_speed and Debug's
## look_motion_polish), so the F1 sliders are live, and the rigs already built take the new library
## without a pop; and each body's looped idle starts at a phase of its own, from its actor's name,
## so a wave spawned in one frame does not breathe and bounce in step.

const ClipHash := preload("res://tests/fixtures/motion/clip_hash.gd")
const FRAME := 1.0 / 60.0
## The points whose motion is watched for a pop.
const WATCHED: Array[StringName] = [&"LeftFistPoint", &"RightFistPoint", &"EyePoint", &"ChestPoint", &"LeftFootPoint"]
## The most a point may move in one tick across a library swap (m): the idle moves a hand a few
## centimeters in a second, a walk's foot about a hundredth of a meter a tick, so a pop shows as a
## step of centimeters.
const POP_M := 0.02


func before_each() -> void:
	Tuning.apply(TuningData.new())
	HumanoidRig._named_libraries.clear()


func after_each() -> void:
	Tuning.apply(TuningData.new())
	HumanoidRig._named_libraries.clear()


# --- Harness ------------------------------------------------------------------------------------


## A boxer rig (the enemies') of `scale` x 1.8 m, built, with `actor` as its actor when it is given.
func _rig(actor: Node3D = null, scale: float = 1.0) -> HumanoidRig:
	var rig := HumanoidRig.new()
	rig.height = 1.8 * scale
	rig.build_hurtboxes = false
	rig.actor = actor
	add_child_autofree(rig)
	rig.build()
	return rig


## A node named `name` in the tree: a stand-in actor for a rig, in the crowd's group unless `crowd`
## is false. Each has a parent of its own, so the same name can be used twice without the tree
## renaming one.
func _actor(name: String, crowd: bool = true) -> Node3D:
	var node := Node3D.new()
	node.name = name
	var holder := Node.new()
	add_child_autofree(holder)
	holder.add_child(node)
	if crowd:
		node.add_to_group(&"ai_enemy")
	return node


func _positions(rig: HumanoidRig) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for point: StringName in WATCHED:
		out.append(rig.get_point_position(point))
	return out


## The largest distance (m) any watched point of `rig` is from where it was in `before`.
func _moved(rig: HumanoidRig, before: Array[Vector3]) -> float:
	var worst := 0.0
	var now := _positions(rig)
	for i: int in now.size():
		worst = maxf(worst, now[i].distance_to(before[i]))
	return worst


## The share of its loop the rig's current animation is at.
func _share(rig: HumanoidRig) -> float:
	return rig.anim_player.current_animation_position / rig.anim_player.current_animation_length


func _hash_of(lib: AnimationLibrary, id: StringName) -> String:
	return ClipHash.sha(ClipHash.clip_text(lib.get_animation(id)))


# --- Step 4: the F1 sliders are live ------------------------------------------------------------


func test_a_motion_slider_drops_the_cached_libraries_and_the_rigs_take_the_rebuilt_one() -> void:
	var a := _rig()
	var b := _rig()
	var old := a.anim_player.get_animation_library(&"")
	assert_same(b.anim_player.get_animation_library(&""), old, "one library for a size and stance")
	var old_idle := _hash_of(old, &"idle")
	Tuning.set_value(&"look_motion_bounce_m", Tuning.data.look_motion_bounce_m * 3.0)
	assert_true(HumanoidRig._named_libraries.is_empty(), "the change drops the cache")
	a.advance(FRAME)
	b.advance(FRAME)
	var fresh := a.anim_player.get_animation_library(&"")
	assert_ne(fresh, old, "the rig has a new library")
	assert_same(b.anim_player.get_animation_library(&""), fresh, "and so does the other rig, the same one")
	assert_same(HumanoidRig._named_libraries["boxer@10000"], fresh, "the one the cache holds")
	assert_ne(_hash_of(fresh, &"idle"), old_idle, "built with the new bounce")
	assert_eq(a.current_anim(), &"idle", "still in the idle")
	assert_eq(a.anim_player.assigned_animation, &"idle", "and playing it")


func test_each_tunable_the_clips_are_built_from_reaches_the_rigs() -> void:
	# The Motion subgroup, move_speed (the walks' length) and the Debug switch: each one, set the
	# way the F1 panel sets it, gives every rig a library that differs from the one it had.
	var changes: Array[Array] = [
		[&"look_motion_breath_deg", 3.0], [&"look_motion_breath_hz", 0.5], [&"look_motion_bounce_m", 0.02],
		[&"look_motion_bounce_hz", 2.0], [&"look_motion_shift_deg", 3.0], [&"look_motion_guard_sway_deg", 6.0],
		[&"look_motion_head_deg", 3.0], [&"look_motion_stride_m", 0.4], [&"look_motion_hip_roll_deg", 8.0],
		[&"look_motion_counter_swing_deg", 10.0], [&"look_motion_overlap_s", 0.06], [&"look_motion_overshoot", 0.4],
		[&"move_speed", 4.0], [&"look_motion_polish", false],
	]
	for change: Array in changes:
		Tuning.apply(TuningData.new())
		HumanoidRig._named_libraries.clear()
		var rig := _rig()
		var old := rig.anim_player.get_animation_library(&"")
		Tuning.set_value(change[0], change[1])
		rig.advance(FRAME)
		assert_ne(rig.anim_player.get_animation_library(&""), old, "%s gives the rig a new library" % change[0])
		assert_same(rig.anim_player.get_animation_library(&""), HumanoidRig._named_libraries["boxer@10000"])


func test_a_player_calm_change_reaches_the_relaxed_stance_too() -> void:
	# The stance is part of the cache key, not of what is watched: the player's rig, whose idle the
	# calm tunable scales, takes the new library as the enemies' do.
	var rig := HumanoidRig.new()
	rig.stance = PlaceholderPoses.STANCE_RELAXED
	rig.build_hurtboxes = false
	add_child_autofree(rig)
	rig.build()
	var old := rig.anim_player.get_animation_library(&"")
	Tuning.set_value(&"look_motion_player_calm", 1.0)
	rig.advance(FRAME)
	assert_ne(rig.anim_player.get_animation_library(&""), old)
	assert_eq(rig.anim_player.get_animation_library(&"").get_animation(&"idle").length, old.get_animation(&"idle").length)


func test_a_change_that_leaves_every_value_as_it_was_rebuilds_nothing() -> void:
	# Every test and every preset load ends with a whole-set change (Tuning.apply, reset_to_default):
	# the libraries stay, and no rig fades into a copy of its own clip.
	var rig := _rig()
	var old := rig.anim_player.get_animation_library(&"")
	Tuning.reset_to_default()
	Tuning.set_value(&"look_motion_bounce_m", Tuning.data.look_motion_bounce_m)
	Tuning.set_value(&"punk_health", 31.0)
	Tuning.apply(TuningData.new())
	assert_same(HumanoidRig._named_libraries["boxer@10000"], old, "the cache keeps its library")
	rig.advance(FRAME)
	assert_same(rig.anim_player.get_animation_library(&""), old, "and the rig keeps it")


func test_a_tunable_the_clips_do_not_read_rebuilds_nothing() -> void:
	var rig := _rig()
	var old := rig.anim_player.get_animation_library(&"")
	for name: StringName in [&"punk_health", &"hit_flash_frames", &"look_outline_px", &"god_mode"]:
		Tuning.set_value(name, Tuning.data.get(name))
	Tuning.set_value(&"hit_flash_frames", 5)
	Tuning.set_value(&"look_outline_px", 2.0)
	rig.advance(FRAME)
	assert_same(rig.anim_player.get_animation_library(&""), old)


func test_the_idle_goes_on_from_the_same_share_of_its_loop_and_does_not_pop() -> void:
	var rig := _rig(_actor("Punk3"))
	for i: int in 95:
		rig.advance(FRAME)
	var share := _share(rig)
	var before := _positions(rig)
	# A longer breath: the loop is twice as long, so its share, not its second, is what carries over.
	Tuning.set_value(&"look_motion_breath_hz", 0.125)
	rig.advance(FRAME)
	assert_eq(rig.anim_player.assigned_animation, &"idle")
	assert_almost_eq(rig.anim_player.current_animation_length, 8.0, 0.01, "the new loop is 8 s")
	assert_almost_eq(_share(rig), share, 0.01, "at the share it was at")
	assert_lt(_moved(rig, before), POP_M, "no point steps %.1f cm across the swap" % (_moved(rig, before) * 100.0))
	# And on through the fade, with the tick-to-tick motion of the idle (a few millimeters).
	var worst := 0.0
	for i: int in 30:
		var last := _positions(rig)
		rig.advance(FRAME)
		worst = maxf(worst, _moved(rig, last))
	assert_lt(worst, POP_M, "no point steps %.1f cm in the fade that follows" % (worst * 100.0))
	assert_almost_eq(rig.anim_player.current_animation_length, 8.0, 0.01)


func test_a_walk_goes_on_from_the_same_share_of_its_stride_when_move_speed_changes() -> void:
	var rig := _rig(_actor("Punk2"))
	rig.play_locomotion(Vector2(0.0, 1.0), 1.0)
	for i: int in 17:
		rig.advance(FRAME)
	assert_eq(rig.anim_player.assigned_animation, &"walk_forward")
	var share := _share(rig)
	var length := rig.anim_player.current_animation_length
	var before := _positions(rig)
	Tuning.set_value(&"move_speed", Tuning.data.move_speed * 0.5)
	rig.advance(FRAME)
	assert_eq(rig.anim_player.assigned_animation, &"walk_forward", "still the walk")
	assert_almost_eq(rig.anim_player.current_animation_length, length * 2.0, 0.01, "twice as long at half the speed")
	# The swap keeps the share; the tick that follows it moves the clip on by FRAME of its new length.
	assert_almost_eq(_share(rig), share + FRAME / rig.anim_player.current_animation_length, 0.01, "from the same share of the stride")
	assert_lt(_moved(rig, before), POP_M, "no point steps %.1f cm across the swap" % (_moved(rig, before) * 100.0))
	assert_eq(rig.anim_player.speed_scale, 1.0, "at the speed it was played at")


func test_a_move_that_is_playing_is_left_alone() -> void:
	var rig := _rig()
	var jab := load("res://game/combat/moves/punk_jab.tres") as MoveData
	rig.play_move(jab)
	for i: int in 6:
		rig.advance(FRAME)
	var name := rig.anim_player.assigned_animation
	var position := rig.anim_player.current_animation_position
	Tuning.set_value(&"look_motion_overshoot", 0.45)
	rig.advance(FRAME)
	assert_eq(rig.anim_player.assigned_animation, name, "the move's clip plays on")
	assert_almost_eq(rig.anim_player.current_animation_position, position + FRAME, 1e-4, "at its own time, unrestarted")
	assert_eq(rig.current_anim(), jab.get_anim())


func test_the_rebuilt_clips_are_the_ones_a_fresh_rig_gets() -> void:
	var rig := _rig()
	Tuning.set_value(&"look_motion_stride_m", 0.45)
	rig.advance(FRAME)
	var late := _rig()
	assert_same(late.anim_player.get_animation_library(&""), rig.anim_player.get_animation_library(&""),
			"a rig built after the change shares the library the rig took")
	assert_almost_eq(rig.anim_player.get_animation_library(&"").get_animation(&"walk_forward").length,
			0.45 / (Tuning.data.move_speed * MotionClips.STANCE_SHARE), 1e-4, "built from the new stride")


# --- Step 5: each body's idle has its own phase -------------------------------------------------


func test_the_punks_of_a_wave_start_their_idles_at_different_phases() -> void:
	var shares: Array[float] = []
	for i: int in 6:
		var rig := _rig(_actor("Punk%d" % (i + 1)))
		assert_eq(rig.anim_player.assigned_animation, &"idle")
		shares.append(_share(rig))
	for i: int in shares.size():
		assert_between(shares[i], 0.0, 1.0)
		for j: int in range(i + 1, shares.size()):
			var gap := absf(shares[i] - shares[j])
			gap = minf(gap, 1.0 - gap)
			assert_gt(gap, 0.05, "Punk%d and Punk%d breathe %.2f of a loop apart" % [i + 1, j + 1, gap])


func test_the_phase_comes_from_the_name_and_is_the_same_every_run() -> void:
	# Nothing random: the same name, the same phase, in a rig built now and in one built later, and
	# the share the Fibonacci hash gives for a given name is what the rig starts at.
	var first := _share(_rig(_actor("Kicker2")))
	var again := _share(_rig(_actor("Kicker2")))
	assert_eq(first, again, "the same name, the same phase")
	var expected := fposmod(float("Kicker2".hash()) * 0.6180339887, 1.0)
	assert_almost_eq(first, expected, 0.001, "the phase is the Fibonacci hash of the name")
	assert_ne(first, _share(_rig(_actor("Kicker3"))), "another name, another phase")


func test_a_scratch_rig_a_dummy_and_the_players_own_body_keep_their_idles_as_they_were() -> void:
	assert_eq(_share(_rig()), 0.0, "a rig with no actor starts at the first key")
	assert_eq(_share(_rig(_actor("Dummy1", false))), 0.0, "a body that is not of the crowd starts at the first key")
	var player_like := HumanoidRig.new()
	player_like.build_hurtboxes = false
	player_like.actor = _actor("Player", false)
	player_like.first_person_body = true
	player_like.stance = PlaceholderPoses.STANCE_RELAXED
	add_child_autofree(player_like)
	player_like.build()
	assert_eq(_share(player_like), 0.0, "the player's own body starts at the first key: the lens rides his head")


func test_the_phase_shows_the_bodies_are_in_different_poses_not_just_different_numbers() -> void:
	# The visible-path twin of the share: two Punks of a wave stand in different guards. The idle is
	# quiet by design (no hurtbox moves 1 cm), so the glove and the head are what show it.
	var a := _rig(_actor("Punk1"))
	var b := _rig(_actor("Punk2"))
	var c := _rig(_actor("Punk3"))
	var spread := 0.0
	for pair: Array in [[a, b], [b, c], [a, c]]:
		var one: HumanoidRig = pair[0]
		var other: HumanoidRig = pair[1]
		for point: StringName in WATCHED:
			spread = maxf(spread, one.get_point_position(point).distance_to(other.get_point_position(point)))
	assert_gt(spread, 0.002, "a point of the guard differs by %.1f mm between bodies" % (spread * 1000.0))
	assert_lt(spread, 0.05, "and by under 5 cm: it is a breath, not a different stance")


func test_a_body_that_leaves_the_crowd_keeps_the_phase_its_idle_started_at() -> void:
	# The showcase Punk and a KO'd body leave "ai_enemy": the idle they restart is the one they had.
	var actor := _actor("Punk6")
	var rig := _rig(actor)
	var own := _share(rig)
	assert_gt(own, 0.0)
	actor.remove_from_group(&"ai_enemy")
	rig.play(&"taunt")
	rig.play(&"idle")
	assert_almost_eq(_share(rig), own, 0.001)


func test_the_idle_comes_back_at_the_rigs_own_phase_after_a_walk() -> void:
	var rig := _rig(_actor("Punk4"))
	var own := _share(rig)
	rig.play_locomotion(Vector2(0.0, 1.0), 1.0)
	for i: int in 30:
		rig.advance(FRAME)
	assert_eq(rig.anim_player.assigned_animation, &"walk_forward")
	rig.play_locomotion(Vector2.ZERO, 0.0)
	assert_eq(rig.anim_player.assigned_animation, &"idle")
	assert_almost_eq(_share(rig), own, 0.001, "the idle starts again where this body's idle starts")


func test_a_restarted_idle_and_a_get_up_into_it_use_the_phase_and_no_other_clip_does() -> void:
	var rig := _rig(_actor("Punk5"))
	var own := _share(rig)
	rig.play(&"taunt")
	assert_eq(_share(rig), 0.0, "a clip that is not the idle starts at its first key")
	rig.play(&"idle")
	assert_almost_eq(_share(rig), own, 0.001, "play(idle) starts at the body's phase")
