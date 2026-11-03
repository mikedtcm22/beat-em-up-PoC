extends GutTest
## The player held by an enemy (Milestone 3, P2-grab), judged from his side and through the
## real first-person camera: the mouse look is dropped while he is held and the look turns to the
## holder, no stale kick offset survives the grab, the held view keeps the holder's head and arms
## at arm's length (nothing nearer the lens than 0.25 m, his own body no more than a third of the
## view, the holder's head in it), the pose he hangs in (upright, lifted for the slam), the MASH
## prompt, and a release that moves the lens no more than 2 cm and the view no more than a degree
## and a half in a tick. The holder is the test grabber (tests/fixtures/grab_test_enemy.gd).

const GRABBER_SCENE := preload("res://tests/fixtures/grab_test_enemy.tscn")
const BOSS_SCENE := preload("res://tests/fixtures/grab_test_boss.tscn")
const HUD_SCENE := preload("res://game/ui/hud.tscn")
const StubDirector := preload("res://tests/fixtures/stub_director.gd")
const FPView := preload("res://tests/fp_view.gd")
const SkinnedView := preload("res://tests/skinned_view.gd")
const FRAME := 1.0 / 60.0
## Nothing may be nearer the lens than this (m): the grabber's head and hands stay at arm's length.
const LENS_CLEARANCE_M := 0.25
## The release moves the lens at most this far in one tick (m), and turns the view at most this
## many degrees.
const RELEASE_STEP_M := 0.02
const RELEASE_TURN_DEG := 1.5

var _scene: Node3D
var _player: PlayerCharacter
var _director: Object


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.data.ai_frozen = true
	Tuning.data.god_mode = false
	TimeController.clear()
	TimeController.debug_scale = 1.0
	GameInput.menu_open = false
	_scene = Node3D.new()
	add_child_autofree(_scene)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	_scene.add_child(floor_body)
	_player = PlayerCharacter.new()
	_scene.add_child(_player)
	_player.input.scripted = true
	_director = StubDirector.new()
	_scene.add_child(_director)


func after_each() -> void:
	GameInput.menu_open = false
	Tuning.reset_to_default()
	Tuning.data.god_mode = false
	TimeController.clear()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(condition: Callable, max_ticks: int = 400) -> bool:
	for i in max_ticks:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


## The grabber `ahead_m` in front of the player, facing him; `boss` for the boss-sized slammer.
func _grabber(ahead_m: float = 1.05, boss: bool = false) -> EnemyActor:
	var enemy := (BOSS_SCENE if boss else GRABBER_SCENE).instantiate() as EnemyActor
	enemy.name = "Grabber1"
	enemy.position = Vector3(0.0, 0.0, -ahead_m)
	enemy.rotation.y = PI
	_scene.add_child(enemy)
	return enemy


func _held(grabber: EnemyActor) -> bool:
	return await _until(func() -> bool: return _player.state == CombatTypes.ActorState.GRABBED, 120)


func _camera() -> FirstPersonCamera:
	var cam := FirstPersonCamera.new()
	_scene.add_child(cam)
	cam.player = _player
	cam.update_camera(FRAME)
	return cam


## The mouse turns the look by `pixels` as the game's _process() would, and what it turned.
func _mouse_turn(pixels: float) -> float:
	var before := _player.look_yaw
	GameInput.consume_mouse_delta()
	GameInput._mouse_delta = Vector2(pixels, 0.0)
	_player.input.scripted = false
	_player._process(FRAME)
	_player.input.scripted = true
	return absf(wrapf(_player.look_yaw - before, -PI, PI))


# --- The look ----------------------------------------------------------------------------------


func test_the_mouse_does_not_turn_the_look_while_held() -> void:
	var grabber := _grabber()
	await _ticks(4)
	assert_gt(_mouse_turn(400.0), 0.1, "free, the mouse turns the look")
	grabber.force_attack()
	assert_true(await _held(grabber))
	assert_eq(_mouse_turn(400.0), 0.0, "held, the look does not turn")
	assert_eq(GameInput.consume_mouse_delta(), Vector2.ZERO, "and the motion is used up, not kept for later")
	for i in Tuning.data.grab_break_presses:
		_player.input.push_press(&"P", 1)
	assert_true(await _until(func() -> bool: return _player.state == CombatTypes.ActorState.FREE, 60))
	assert_gt(_mouse_turn(400.0), 0.1, "free again, the mouse turns the look")


func test_the_look_faces_the_holder_within_the_turn_frames_whatever_way_he_looked() -> void:
	for yaw_deg: float in [0.0, 90.0, 180.0, -100.0]:
		_player.look_yaw = deg_to_rad(yaw_deg)
		_player.rotation.y = _player.look_yaw
		var grabber := _grabber(1.05)
		grabber.global_position = _player.global_position + Vector3(0.0, 0.0, -1.05)
		grabber.rotation.y = PI
		await _ticks(4)
		grabber.force_attack()
		assert_true(await _held(grabber), "held (looking %.0f)" % yaw_deg)
		await _ticks(Tuning.data.grabbed_turn_frames + 1)
		var to_holder := grabber.global_position - _player.global_position
		var bearing := _player.look_bearing_deg(grabber.global_position)
		assert_lt(absf(bearing), 3.0, "looking %.0f, the look is on the holder (%.1f degrees off)" % [yaw_deg, bearing])
		# Let him go and put the grabber away for the next look.
		_player.reset_state()
		grabber.remove_from_group(&"actor")
		grabber.queue_free()
		await _ticks(3)
		assert_gt(to_holder.length(), 0.5)


func test_the_look_turns_by_itself_over_the_turn_frames_not_in_one_step() -> void:
	_player.look_yaw = deg_to_rad(120.0)
	var grabber := _grabber(1.05)
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _held(grabber))
	var steps: Array[float] = []
	var last := _player.look_yaw
	for i in Tuning.data.grabbed_turn_frames + 2:
		await _ticks(1)
		steps.append(absf(wrapf(_player.look_yaw - last, -PI, PI)))
		last = _player.look_yaw
	var biggest: float = steps.max()
	assert_lt(rad_to_deg(biggest), 120.0 / Tuning.data.grabbed_turn_frames * 1.6, "an even turn (largest step %.1f degrees)" % rad_to_deg(biggest))


func test_a_kicks_view_offset_does_not_outlive_the_grab() -> void:
	var grabber := _grabber(1.05)
	await _ticks(4)
	# A kick moves the camera (pitch and drop); grab him in the middle of its recovery.
	_player.input.push_press(&"K", 2)
	assert_true(await _until(func() -> bool: return _player.current_move != null and _player.current_move.camera_pitch_deg != 0.0, 30))
	await _until(func() -> bool: return _player.current_move != null and _player.move_frame > _player.current_move.startup + 1, 30)
	assert_ne(_player.get_camera_move_offset(), Vector2.ZERO, "the kick moves the camera")
	grabber.force_attack()
	assert_true(await _held(grabber))
	await _ticks(2)
	assert_eq(_player._cam_offset, Vector2.ZERO, "no stale kick offset while held")
	assert_null(_player.current_move, "the kick was dropped")
	assert_eq(_player.parser.chain_step, 0, "and the combo chain")


# --- The view ----------------------------------------------------------------------------------


## The held view over `ticks` ticks of the hold of `grabber`: the nearest any mesh but his own comes to the lens (m),
## the most of the view his own body covers, and the least and most of it the holder's head
## meshes cover once the view has settled (the second half of the hold), every few ticks.
func _judge_hold(grabber: EnemyActor, cam: FirstPersonCamera, ticks: int) -> Dictionary:
	var nearest := INF
	var own_worst := 0.0
	var head_least := 1.0
	var head_most := 0.0
	var all_worst := 0.0
	var nearest_at := -1
	var nearest_name := ""
	for i in ticks:
		await _ticks(1)
		cam.update_camera(FRAME)
		if _player.state != CombatTypes.ActorState.GRABBED:
			break
		var view := cam.view_transform()
		var near := FPView.nearest_mesh(_scene, view.origin, func(m: MeshInstance3D) -> bool: return not _player.rig.is_ancestor_of(m))
		if near < nearest:
			nearest = near
			nearest_at = i
			for mesh: MeshInstance3D in FPView.meshes_under(_scene):
				if not (mesh.layers & CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN)) and mesh.is_visible_in_tree() \
						and is_equal_approx(FPView.mesh_distance(mesh, view.origin), near):
					var rig_node: Node = mesh
					while rig_node != null and not rig_node is HumanoidRig:
						rig_node = rig_node.get_parent()
					nearest_name = "%s of %s" % [mesh.name, rig_node.get_parent().name if rig_node else "?"]
		if i % 4 != 0:
			continue
		var cells := FPView.hits(_scene, Transform3D(view.basis, view.origin))
		own_worst = maxf(own_worst, FPView.share(cells, func(m: MeshInstance3D) -> bool: return _player.rig.is_ancestor_of(m)))
		all_worst = maxf(all_worst, FPView.covered(cells))
		var head := FPView.share(cells, func(m: MeshInstance3D) -> bool:
			return grabber.rig.is_ancestor_of(m) and ["Head", "Cap", "Hair", "CapBrim", "Shades", "ShadesFront"].has(String(m.name)))
		if i > ticks / 4:
			head_least = minf(head_least, head)
			head_most = maxf(head_most, head)
	return {nearest = nearest, nearest_at = nearest_at, nearest_name = nearest_name, own = own_worst, head_least = head_least, head_most = head_most, covered = all_worst}


func _check_the_held_view(boss: bool) -> void:
	var grabber := _grabber(1.2 if boss else 1.05, boss)
	await _ticks(4)
	var cam := _camera()
	grabber.force_attack()
	assert_true(await _held(grabber))
	# The hold from the connect to the follow-up's strike frame, where he is let go and hit. The
	# Bruiser's headbutt drives its head in over the last fifth of the wind-up, through where his
	# face is: that dive is deliberate and the check stops at its held key (80% of the startup). The
	# boss's slam does not dive (final review, tells-04: a forward fold put its cap 0.115 m from the
	# lens one frame before the strike, the headbutt's picture): its strike rears back and heaves
	# him, so every frame of it, up to the strike's, is held to the arm's length.
	var follow: MoveData = load("res://game/combat/moves/%s.tres" % ("boss_slam" if boss else "bruiser_headbutt"))
	var window := follow.startup if boss else roundi(follow.startup * PlaceholderEnemyPoses.WINDUP_HOLD_AT)
	var stats := await _judge_hold(grabber, cam, window)
	gut.p("nearest: %s at tick %d" % [stats.nearest_name, stats.nearest_at])
	gut.p("%s held view: nearest %.2f m, own body %.0f%%, holder's head %.0f-%.0f%%, all meshes %.0f%%" % [
			"boss" if boss else "bruiser", stats.nearest, stats.own * 100.0, stats.head_least * 100.0,
			stats.head_most * 100.0, stats.covered * 100.0])
	assert_gte(stats.nearest, LENS_CLEARANCE_M, "nothing within %.2f m of the lens (%.3f)" % [LENS_CLEARANCE_M, stats.nearest])
	assert_lte(stats.own, 1.0 / 3.0, "his own body covers at most a third of the view (%.0f%%)" % (stats.own * 100.0))
	assert_gt(stats.head_most, 0.02, "the holder's head is in the view (%.1f%% at best)" % (stats.head_most * 100.0))


func test_the_bruisers_hold_keeps_its_head_and_hands_at_arms_length() -> void:
	await _check_the_held_view(false)


func test_the_bosss_hold_keeps_its_head_and_hands_at_arms_length() -> void:
	await _check_the_held_view(true)


func test_the_view_tips_up_toward_the_holders_eyes_and_never_past_the_tunable() -> void:
	var grabber := _grabber(1.05)
	await _ticks(4)
	assert_eq(_player.get_grabbed_view_pitch_deg(), 0.0, "free, no extra pitch")
	grabber.force_attack()
	assert_true(await _held(grabber))
	await _ticks(30)
	var pitch := _player.get_grabbed_view_pitch_deg()
	assert_gt(pitch, 5.0, "a tall grabber is looked up to (%.1f degrees)" % pitch)
	assert_lte(pitch, Tuning.data.grabbed_view_pitch_deg, "within the tunable")
	assert_eq(_player.get_grabbed_view_weight(), 1.0, "at full weight")
	assert_almost_eq(_player.get_camera_move_offset().x, pitch, 0.001, "the view's extra pitch carries it")
	Tuning.data.grabbed_view_pitch_deg = 3.0
	await _ticks(2)
	assert_lte(_player.get_grabbed_view_pitch_deg(), 3.0, "a live tunable")


func test_the_held_player_hangs_upright_and_is_lifted_for_the_slam() -> void:
	var grabber := _grabber(1.05)
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _held(grabber))
	await _ticks(10)
	assert_eq(_player.rig.current_anim(), &"held_collar", "upright in the collar hold")
	var boss := _grabber(1.2, true)
	boss.name = "Boss1"
	boss.global_position = Vector3(8.0, 0.0, -1.2)
	_player.reset_state()
	grabber.remove_from_group(&"actor")
	grabber.queue_free()
	_player.global_position = Vector3(8.0, 0.0, 0.0)
	await _ticks(4)
	boss.force_attack()
	assert_true(await _held(boss))
	assert_true(await _until(func() -> bool: return _player.rig.current_anim() == &"held_lift", 20), "the slam lifts him")
	assert_true(boss.lifts_victim(_player))
	assert_false(is_instance_valid(grabber) and grabber.lifts_victim(_player), "the Bruiser does not")


func test_he_is_pinned_in_front_of_the_holder_facing_it_at_the_pin_distance() -> void:
	var grabber := _grabber(1.05)
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _held(grabber))
	await _ticks(20)
	var expected := Tuning.data.grabbed_pin_distance_m + (grabber.body_radius - _player.body_radius)
	var to_player := _player.global_position - grabber.global_position
	to_player.y = 0.0
	assert_almost_eq(to_player.length(), expected, 0.01, "%.2f m from the holder (its radius over his added)" % expected)
	assert_gt(to_player.normalized().dot(grabber.get_forward()), 0.999, "on the holder's forward axis")
	var facing := -_player.global_basis.z
	assert_gt(facing.dot(-to_player.normalized()), 0.99, "facing the holder")
	assert_almost_eq(_player.global_position.y, grabber.global_position.y, 0.001, "on the holder's floor")


# --- The release -------------------------------------------------------------------------------


## Watch the lens through a release: the largest step of its position (m) and of its view
## direction (degrees) between two ticks, from `ticks_before` ticks before it to `ticks_after`
## after.
func _release_steps(cam: FirstPersonCamera, do_release: Callable, ticks_before: int, ticks_after: int) -> Dictionary:
	var step_m := 0.0
	var step_deg := 0.0
	var last := cam.view_transform()
	var released_at := -1
	for i in ticks_before + ticks_after:
		if i == ticks_before:
			do_release.call()
		await _ticks(1)
		cam.update_camera(FRAME)
		if released_at < 0 and _player.state != CombatTypes.ActorState.GRABBED and i >= ticks_before:
			released_at = i
		var now := cam.view_transform()
		step_m = maxf(step_m, now.origin.distance_to(last.origin))
		step_deg = maxf(step_deg, rad_to_deg((-now.basis.z).angle_to(-last.basis.z)))
		last = now
	return {m = step_m, deg = step_deg, released_at = released_at}


func test_breaking_free_moves_the_lens_no_more_than_2_cm_and_the_view_no_more_than_a_degree_and_a_half() -> void:
	var grabber := _grabber(1.05)
	await _ticks(4)
	var cam := _camera()
	grabber.force_attack()
	assert_true(await _held(grabber))
	await _ticks(25)
	var mash := func() -> void:
		for i in Tuning.data.grab_break_presses:
			_player.input.push_press(&"P", 1)
	var steps := await _release_steps(cam, mash, 3, 70)
	gut.p("break free: lens step %.4f m, view step %.2f degrees" % [steps.m, steps.deg])
	assert_eq(_player.state, CombatTypes.ActorState.FREE, "he broke free")
	assert_lte(steps.m, RELEASE_STEP_M, "the lens moves at most 2 cm a tick through the release (%.4f)" % steps.m)
	assert_lte(steps.deg, RELEASE_TURN_DEG, "the view turns at most %.1f degrees a tick (%.2f)" % [RELEASE_TURN_DEG, steps.deg])


func test_the_release_by_a_holder_that_is_hit_does_not_pop_either() -> void:
	var grabber := _grabber(1.05)
	await _ticks(4)
	var cam := _camera()
	grabber.force_attack()
	assert_true(await _held(grabber))
	await _ticks(25)
	var knock := func() -> void:
		var hit := HitInfo.new()
		hit.attacker = _player
		hit.victim = grabber
		hit.damage = 4.0
		hit.tier = CombatTypes.HitTier.HEAVY
		hit.reaction = CombatTypes.Reaction.STAGGER
		hit.knockback = Vector3(0.0, 0.0, -2.0)
		hit.direction = Vector3.FORWARD
		hit.contact_point = grabber.global_position + Vector3.UP
		grabber.receive_hit(hit)
	var steps := await _release_steps(cam, knock, 3, 70)
	assert_ne(_player.state, CombatTypes.ActorState.GRABBED, "let go")
	assert_lte(steps.m, RELEASE_STEP_M, "lens step %.4f m" % steps.m)
	assert_lte(steps.deg, RELEASE_TURN_DEG, "view step %.2f degrees" % steps.deg)


func test_the_bosss_release_does_not_pop() -> void:
	var grabber := _grabber(1.2, true)
	await _ticks(4)
	var cam := _camera()
	grabber.force_attack()
	assert_true(await _held(grabber))
	# Held up in the slam's wind-up, he breaks free.
	await _ticks(30)
	var mash := func() -> void:
		for i in Tuning.data.grab_break_presses:
			_player.input.push_press(&"K", 1)
	var steps := await _release_steps(cam, mash, 3, 80)
	gut.p("boss break free: lens step %.4f m, view step %.2f degrees" % [steps.m, steps.deg])
	assert_eq(_player.state, CombatTypes.ActorState.FREE, "he broke free")
	assert_lte(steps.m, RELEASE_STEP_M, "lens step %.4f m" % steps.m)
	assert_lte(steps.deg, RELEASE_TURN_DEG, "view step %.2f degrees" % steps.deg)


func test_reset_state_forgets_the_mash_and_the_view() -> void:
	var grabber := _grabber(1.05)
	await _ticks(4)
	grabber.force_attack()
	assert_true(await _held(grabber))
	for i in 3:
		_player.input.push_press(&"P", 1)
	await _ticks(10)
	assert_gt(_player.grab_break_progress(), 0.0)
	_player.reset_state()
	assert_eq(_player.grab_break_progress(), 0.0)
	assert_eq(_player.get_grabbed_view_weight(), 0.0)
	assert_eq(_player.get_grabbed_view_pitch_deg(), 0.0)


# --- The MASH prompt ---------------------------------------------------------------------------


func test_the_mash_prompt_shows_only_while_held_and_follows_the_presses() -> void:
	var hud := HUD_SCENE.instantiate() as GameHud
	_scene.add_child(hud)
	var prompt := hud.grab_prompt
	var grabber := _grabber(1.05)
	await _ticks(4)
	hud.advance(0.016)
	assert_false(prompt.visible, "not shown while free")
	grabber.force_attack()
	assert_true(await _held(grabber))
	hud.advance(0.016)
	assert_true(prompt.visible, "shown while held")
	assert_eq(prompt.gauge.value, 0.0, "empty")
	for i in 4:
		_player.input.push_press(&"P", 1)
	await _ticks(12)
	for i in 10:
		hud.advance(0.05)
	assert_almost_eq(prompt.gauge.value, 0.5, 0.01, "half full after half the presses")
	for i in 4:
		_player.input.push_press(&"K", 1)
	assert_true(await _until(func() -> bool: return _player.state != CombatTypes.ActorState.GRABBED, 40))
	hud.advance(0.016)
	assert_false(prompt.visible, "gone once he is free")


func test_the_mash_prompt_is_below_the_center_and_clear_of_the_top_corners() -> void:
	var hud := HUD_SCENE.instantiate() as GameHud
	_scene.add_child(hud)
	await _ticks(2)
	var prompt := hud.grab_prompt
	var canvas := hud.get_viewport().get_visible_rect().size
	var rect := Rect2(prompt.global_position, prompt.size)
	assert_gt(rect.position.y, canvas.y * 0.5, "below the view center")
	assert_lt(rect.end.y, canvas.y - 40.0, "above the bottom edge")
	var corners := canvas * 0.2
	assert_false(rect.intersects(Rect2(Vector2.ZERO, corners)), "clear of the top-left corner")
	assert_false(rect.intersects(Rect2(Vector2(canvas.x - corners.x, 0.0), corners)), "clear of the top-right corner")
	assert_eq(prompt.mouse_filter, Control.MOUSE_FILTER_IGNORE, "takes no clicks")


## M4 (F-player-int): the twin of the held-view checks above on the SKINNED art. Those cast the player's
## own body through the proxies (the primitives that stand in for his art, M4-plan A4); this one
## has him wear the probe body (Tuning's Debug look_player_art_probe) and casts the triangles his lens
## draws (tests/skinned_view.gd, in the drawn pose): held by the Bruiser-sized grabber from its connect
## to its follow-up's held key, his own body covers at most a third of the view and no vertex of it is
## nearer the lens than 0.25 m.
func test_the_held_view_on_the_skinned_art_keeps_the_own_body_to_a_third_and_off_the_lens() -> void:
	_scene.remove_child(_player)
	_player.free()
	Tuning.data.look_player_art_probe = true
	_player = PlayerCharacter.new()
	_scene.add_child(_player)
	_player.input.scripted = true
	await _ticks(2)
	assert_true(_player.rig.has_art(), "the player wears the art")
	var grabber := _grabber()
	await _ticks(4)
	var cam := _camera()
	grabber.force_attack()
	assert_true(await _held(grabber))
	var follow: MoveData = load("res://game/combat/moves/bruiser_headbutt.tres")
	var window := roundi(follow.startup * PlaceholderEnemyPoses.WINDUP_HOLD_AT)
	var own_worst := 0.0
	var nearest := INF
	var samples := 0
	for i in window:
		await _ticks(1)
		cam.update_camera(FRAME)
		if _player.state != CombatTypes.ActorState.GRABBED or i % 4 != 0:
			continue
		var view := cam.view_transform()
		var cells := SkinnedView.hits(_player.rig, view)
		var own := 0
		for cell: Dictionary in cells:
			own += int(not cell.is_empty())
		own_worst = maxf(own_worst, float(own) / cells.size())
		var lens := _player.rig.global_transform.affine_inverse() * view.origin
		for mi: MeshInstance3D in _player.rig.art_meshes():
			if mi.layers & CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN):
				continue
			for v: Vector3 in SkinnedView.skin_vertices(mi, _player.rig):
				nearest = minf(nearest, v.distance_to(lens))
		samples += 1
	gut.p("held view on the art: %d samples, own body at most %.0f%% of the view, nearest drawn vertex %.3f m" % [samples, own_worst * 100.0, nearest])
	assert_gt(samples, 5, "the hold was sampled")
	assert_lte(own_worst, 1.0 / 3.0, "his own body, as drawn, covers at most a third of the view (%.0f%%)" % (own_worst * 100.0))
	assert_gte(nearest, LENS_CLEARANCE_M, "no vertex of the body the lens draws is within %.2f m of it (%.3f)" % [LENS_CLEARANCE_M, nearest])
