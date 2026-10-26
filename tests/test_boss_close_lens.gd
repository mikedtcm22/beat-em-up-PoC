extends GutTest
## The boss's ground pound through the first-person lens at the distances a player really stands at
## (final review, tells-01): about 1.05 m from the boss after his own magnetism closes on it, and
## closer or further while he rushes in during the armored wind-up. test_boss.gd checks the pound
## only from the posture ring (2.2 m), where nothing of a 2.3 m boss comes near the lens; here the
## boss is 0.9, 1.1 and 1.3 m from him and nothing of it may come within 0.25 m of the lens (A6.3)
## from the held wind-up key through the strike and its hitstop. The strike is a deep squat with
## the head over the hips and the fists driven down in front of the knees; a torso folded over the
## knees put the cap through the lens (0.000 m at 0.9 m).
##
## The harness is test_boss.gd's: the boss stands where it is put and faces the player, and
## force_attack(1) starts its pound.

const BOSS_SCENE := preload("res://game/enemies/boss/boss.tscn")
const StubDirector := preload("res://tests/fixtures/stub_director.gd")
const FPView := preload("res://tests/fp_view.gd")
const FRAME := 1.0 / 60.0
## Nothing of the boss may be nearer the lens than this (m): test_boss.gd's arm's-length rule.
const LENS_CLEARANCE_M := 0.25
## The distances (m, boss origin to the player's) the pound is judged at: the player's own stop
## distance after magnetism is about 1.05 m, so these are on either side of it and 0.9 m is the
## nearest he gets to the boss in a fight.
const DISTANCES_M: Array[float] = [0.9, 1.1, 1.3]
## Ticks sampled from the held key: the drive-in (7), the hitstop (6) and the player's flight.
const HIT_WINDOW_TICKS := 40

var _scene: Node3D
var _player: PlayerCharacter
var _hits: Array[HitInfo] = []


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.data.ai_frozen = true
	Tuning.data.god_mode = false
	Tuning.data.one_hit_ko = false
	Tuning.data.waves_enabled = false
	TimeController.clear()
	TimeController.debug_scale = 1.0
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = false
	_hits.clear()
	CombatEvents.hit_landed.connect(_on_hit_landed)
	_scene = Node3D.new()
	add_child_autofree(_scene)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	floor_body.collision_mask = 0
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
	_scene.add_child(StubDirector.new())


func after_each() -> void:
	if CombatEvents.hit_landed.is_connected(_on_hit_landed):
		CombatEvents.hit_landed.disconnect(_on_hit_landed)
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = true
	Tuning.reset_to_default()
	Tuning.data.god_mode = false
	TimeController.clear()


func _on_hit_landed(hit: HitInfo) -> void:
	_hits.append(hit)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(condition: Callable, max_ticks: int = 400) -> bool:
	for i in max_ticks:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


## The boss `ahead_m` in front of the player (who looks along -Z), facing him.
func _boss(ahead_m: float) -> Boss:
	var boss := BOSS_SCENE.instantiate() as Boss
	boss.name = "Boss1"
	boss.position = Vector3(0.0, 0.0, -ahead_m)
	boss.rotation.y = PI
	_scene.add_child(boss)
	return boss


func _camera() -> FirstPersonCamera:
	var cam := FirstPersonCamera.new()
	_scene.add_child(cam)
	cam.player = _player
	return cam


## The least distance (m) from the lens to any mesh of `boss` over `ticks` ticks from now
## (test_boss.gd's helper).
func _nearest_to_the_lens(boss: Boss, cam: FirstPersonCamera, ticks: int) -> float:
	var nearest := INF
	for i in ticks:
		await _ticks(1)
		cam.update_camera(FRAME)
		var view := cam.view_transform()
		nearest = minf(nearest, FPView.nearest_mesh(_scene, view.origin, func(m: MeshInstance3D) -> bool: return boss.rig.is_ancestor_of(m)))
	return nearest


## Starts the pound and runs to its held wind-up key (80% of the startup): where the dive begins.
func _to_the_held_key(boss: Boss) -> bool:
	boss.force_attack(1)
	if not await _until(func() -> bool: return boss.state == CombatTypes.ActorState.WINDUP, 10):
		return false
	var held_frame := roundi(boss.current_move.startup * PlaceholderEnemyPoses.WINDUP_HOLD_AT)
	return await _until(func() -> bool: return boss.move_frame >= held_frame, 60)


func test_the_pound_keeps_the_boss_off_the_lens_when_it_lands_from_close_range() -> void:
	for distance: float in DISTANCES_M:
		_hits.clear()
		_player.reset_state()
		_player.global_position = Vector3.ZERO
		var boss := _boss(distance)
		var cam := _camera()
		await _ticks(3)
		assert_true(await _to_the_held_key(boss), "the pound winds up at %.1f m" % distance)
		assert_eq(boss.current_move.id, &"boss_pound")
		assert_eq(_player.state, CombatTypes.ActorState.FREE, "the player stands in front of it")
		var nearest: float = await _nearest_to_the_lens(boss, cam, HIT_WINDOW_TICKS)
		gut.p("pound at %.1f m: nearest boss mesh %.3f m from the lens (%d hits)" % [distance, nearest, _hits.size()])
		assert_false(_hits.is_empty(), "the pound landed at %.1f m" % distance)
		assert_gte(nearest, LENS_CLEARANCE_M, "at %.1f m nothing of the boss within %.2f m of the lens, from the held key through the hitstop (%.3f)" % [distance, LENS_CLEARANCE_M, nearest])
		boss.free()
		cam.free()
		await _ticks(2)


func test_a_pound_he_does_not_take_keeps_clear_of_the_lens_through_its_follow_through() -> void:
	# He is in the middle of a get-up's invulnerability (nothing lands) and stands where he stood:
	# the strike is held through its active frames and the follow-through key is reached, still
	# off the lens.
	for distance: float in DISTANCES_M:
		_player.reset_state()
		_player.global_position = Vector3.ZERO
		_player._invuln_frames = 10000
		var boss := _boss(distance)
		var cam := _camera()
		await _ticks(3)
		assert_true(await _to_the_held_key(boss), "the pound winds up at %.1f m" % distance)
		var move := boss.current_move
		var held_frame := roundi(move.startup * PlaceholderEnemyPoses.WINDUP_HOLD_AT)
		var poses := PlaceholderPoses.move_poses(move.get_anim())
		var follow_frame := move.startup + move.active + roundi(move.recovery * poses.follow_at)
		var nearest: float = await _nearest_to_the_lens(boss, cam, follow_frame - held_frame + 4)
		gut.p("whiffed pound at %.1f m: nearest boss mesh %.3f m from the lens" % [distance, nearest])
		assert_true(_hits.is_empty(), "nothing landed at %.1f m" % distance)
		assert_gte(nearest, LENS_CLEARANCE_M, "at %.1f m nothing of the boss within %.2f m of the lens (%.3f)" % [distance, LENS_CLEARANCE_M, nearest])
		boss.free()
		cam.free()
		await _ticks(2)
