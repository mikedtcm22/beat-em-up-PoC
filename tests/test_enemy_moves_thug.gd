extends GutTest
## The Pipe Thug's moves (thug_pipe_1..3) through the shared enemy move checks
## (tests/enemy_move_checks.gd): the clip's timing and held wind-up, every key pose inside the
## ragdoll's joint limits, the strike's measured reach against reach_m, and the wind-up as the
## defender's first-person lens sees it at 1 m and 2.5 m (the head in view, the striking
## WeaponTip in view at the held key). On top of those, the same wind-up with the pipe in the
## hand: the pipe never hides the face, and its tip shows (the shared checks draw no pipe).

const Checks := preload("res://tests/enemy_move_checks.gd")
const FPView := preload("res://tests/fp_view.gd")
const ThugTable := preload("res://tests/enemy_moves/thug_table.gd")
const MOVES_DIR := "res://game/combat/moves/"
const ENEMY_HEIGHT := 1.8
## Where a Thug stands to swing at its reach (the engage step-in) and at the posture ring's near
## edge (a wind-up must read from there too).
const CLOSE_M := 1.0
const RING_M := 2.5
## How much of the bare head the pipe must leave in the lens at 1 m and at the ring (a share: 0.9
## keeps nine tenths of the face). The backhand link swings the pipe out to the left across the
## front in its first two or three frames, so it is held to 0.7: it is no telegraph of its own.
const KEEP_HEAD_SHARE := 0.9
const KEEP_HEAD_SHARE_BACKHAND := 0.7
## The pipe's visual, as Weapon builds it (length, radius), for the first-person view.
const PIPE_LENGTH_M := 0.85
const PIPE_RADIUS_M := 0.028
const PIPE_GRIP_BACK_M := 0.12
## Points sampled along the cocked pipe, and how many of them must be in the view.
const PIPE_SAMPLES := 9
const PIPE_SAMPLES_SHOWN := 4


func before_all() -> void:
	# First-person checks use the shipped lens offsets.
	Tuning.reset_to_default()


func after_all() -> void:
	Tuning.reset_to_default()


func _move(id: StringName) -> MoveData:
	return load("%s%s.tres" % [MOVES_DIR, id]) as MoveData


func _rig() -> HumanoidRig:
	var rig := HumanoidRig.new()
	add_child_autofree(rig)
	rig.build()
	return rig


func _ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ThugTable.MOVES:
		out.append(id)
	return out


func test_the_three_moves_exist_and_have_recipes() -> void:
	assert_eq(_ids().size(), 3, "three swings")
	for id: StringName in _ids():
		assert_not_null(_move(id), "%s loads" % id)
		assert_true(PlaceholderEnemyPoses.has_recipe(id), "%s has a recipe" % id)
		assert_true(EnemyPosesThug.MOVE_IDS.has(id), "%s is the Thug's pose file's" % id)


func test_every_clip_is_timed_and_the_first_swings_windup_is_held() -> void:
	var rig := _rig()
	for id: StringName in _ids():
		# The second and third swings are chain links with no telegraph of their own: no held key.
		Checks.check_clip(self, rig, _move(id), id == &"thug_pipe_1")


func test_every_key_pose_is_inside_the_ragdolls_joint_limits() -> void:
	for id: StringName in _ids():
		Checks.check_recipe_joint_limits(self, _move(id))


func test_the_measured_reach_is_reach_m() -> void:
	for id: StringName in _ids():
		var move := _move(id)
		gut.p("%s measured reach %.2f m (reach_m %.2f)" % [id, Checks.measure_reach(ENEMY_HEIGHT, move, self), move.reach_m])
		Checks.check_reach(self, move, ENEMY_HEIGHT, self)


func test_the_swings_start_and_end_in_the_stance_the_thug_walks_in() -> void:
	# The recipes are authored on the boxer guard (the rig's stance), so a swing never pops from one
	# pose into another; the clip check already proves the end matches the start.
	for id: StringName in _ids():
		var poses := PlaceholderPoses.move_poses(id)
		assert_eq(poses.guard, PlaceholderPoses.guard(), "%s starts in the boxer guard" % id)
		assert_true(poses.finish.is_empty(), "%s ends in it" % id)


func test_the_first_swing_reads_in_first_person_at_one_metre_and_at_the_ring() -> void:
	for distance: float in [CLOSE_M, RING_M]:
		Checks.check_fp_telegraph(self, _hand_probe(_move(&"thug_pipe_1")), ENEMY_HEIGHT, distance)


func test_the_links_show_their_head_at_one_metre() -> void:
	for id: StringName in [&"thug_pipe_2", &"thug_pipe_3"]:
		Checks.check_fp_telegraph(self, _hand_probe(_move(id)), ENEMY_HEIGHT, CLOSE_M)


func test_the_pipe_in_the_hand_never_hides_the_face_and_shows_when_it_is_cocked() -> void:
	for id: StringName in _ids():
		for distance: float in [CLOSE_M, RING_M]:
			var problems := _pipe_problems(_move(id), distance, id == &"thug_pipe_1")
			assert_true(problems.is_empty(), "%s with its pipe at %.1f m%s" % [id, distance, "" if problems.is_empty() else " (%s)" % "; ".join(problems)])


func test_the_wind_ups_are_at_least_the_grunt_floor_and_the_links_are_short() -> void:
	var floor_frames := Tuning.data.windup_min_frames_grunt
	assert_gte(_move(&"thug_pipe_1").startup, floor_frames, "the first swing is a full telegraph")
	for id: StringName in [&"thug_pipe_2", &"thug_pipe_3"]:
		assert_lt(_move(id).startup, floor_frames, "%s is a short follow-up link" % id)


func test_the_table_rows_match_the_files() -> void:
	for id: StringName in _ids():
		var row: Dictionary = ThugTable.MOVES[id]
		var move := _move(id)
		assert_eq(move.damage, row.damage, "%s damage" % id)
		assert_eq(move.blocked_recoil_frames, row.recoil, "%s recoil" % id)
		assert_almost_eq(move.reach_m, float(row.reach_m), 0.0001, "%s reach" % id)
		assert_almost_eq(move.guard_damage_mult, float(row.guard_mult), 0.0001, "%s guard drain" % id)


# --- The pipe in the lens ----------------------------------------------------------------------


## A copy of `move` that strikes with the right fist, the hand that carries the pipe. The shared
## first-person check looks for the striking point in the view at the held key, and the pipe's tip
## is not it: cocked high it rises past the top of the lens at 1 m, which is the telegraph. The
## pipe's own visibility is _pipe_problems().
func _hand_probe(move: MoveData) -> MoveData:
	var probe := move.duplicate() as MoveData
	var spec := HitboxSpec.new()
	spec.kind = HitboxSpec.Kind.POINT_SPHERE
	spec.point = &"RightFistPoint"
	spec.radius = 0.14
	probe.hitboxes = [spec]
	return probe


## What the pipe in the Thug's hand does to the first-person view of `move`'s wind-up from
## `distance_m`: it may hide no more than a tenth of the bare head on any startup frame up to the
## held key (the wind-up key without one), and, with `must_show`, at least PIPE_SAMPLES_SHOWN of
## the PIPE_SAMPLES points along it are inside the view at that key (the whole pipe at the ring,
## its grip end and shaft at 1 m, where the tip rises past the top of the lens). The scratch rigs
## live under this test and are freed before it returns.
func _pipe_problems(move: MoveData, distance_m: float, must_show: bool) -> PackedStringArray:
	var problems := PackedStringArray()
	var scene := Node3D.new()
	add_child(scene)
	var player := HumanoidRig.new()
	var dresser := PlayerCharacter.new()
	dresser._configure_rig(player)
	dresser.free()
	scene.add_child(player)
	player.build()
	player.play(&"idle", 0.0)
	player.advance(0.0)
	var facing := player.global_basis.orthonormalized()
	var cam := Transform3D(facing, player.get_point_position(&"EyePoint") + FirstPersonCamera.lens_offset(facing))
	var enemy := Checks._boxer(scene, ENEMY_HEIGHT)
	enemy.position = Vector3(0.0, 0.0, -distance_m)
	enemy.rotation = Vector3(0.0, PI, 0.0)
	var pipe := _attach_pipe(enemy)
	enemy.play(&"idle", 0.0)
	enemy.advance(0.5)
	var poses := PlaceholderPoses.move_poses(move.get_anim())
	var look_at_t := PlaceholderAnims.windup_hold_time(move, poses)
	if look_at_t < 0.0:
		look_at_t = PlaceholderAnims.windup_time(move, poses)
	var look_at_frame := roundi(look_at_t / Checks.FRAME)
	enemy.play_move(move, 0.0)
	for f: int in clampi(look_at_frame, 1, move.startup):
		enemy.advance(Checks.FRAME)
		var with_pipe := FPView.hits(scene, cam)
		var without := FPView.hits(scene, cam, FPView.COLS, [pipe])
		var head := Checks._share_of(with_pipe, enemy, Checks.HEAD_PARTS)
		var bare := Checks._share_of(without, enemy, Checks.HEAD_PARTS)
		var keep := KEEP_HEAD_SHARE_BACKHAND if move.id == &"thug_pipe_2" else KEEP_HEAD_SHARE
		if bare > 0.0 and head < bare * keep:
			problems.append("startup frame %d: the pipe hides the face (%.2f%% of the view, %.2f%% without it)" % [f + 1, head * 100.0, bare * 100.0])
		if must_show and f + 1 == look_at_frame:
			var shown := 0
			for i: int in PIPE_SAMPLES:
				var along := -PIPE_LENGTH_M * 0.5 + PIPE_LENGTH_M * i / float(PIPE_SAMPLES - 1)
				var q := cam.affine_inverse() * pipe.to_global(Vector3(0.0, along, 0.0))
				var depth := -q.z
				if depth > FPView.NEAR and absf(rad_to_deg(atan2(q.x, depth))) < FPView.HALF_H_DEG \
						and absf(rad_to_deg(atan2(q.y, depth))) < FPView.HALF_V_DEG:
					shown += 1
			if shown < PIPE_SAMPLES_SHOWN:
				problems.append("only %d of %d points along the pipe are in the view at the cocked wind-up" % [shown, PIPE_SAMPLES])
	scene.free()
	return problems


## A mesh of the pipe's size on `rig`'s WeaponGrip, placed as Weapon places its own (its long axis
## from the grip toward the tip, the handle 0.12 m behind the grip).
func _attach_pipe(rig: HumanoidRig) -> MeshInstance3D:
	var grip := rig.get_attachment(&"WeaponGrip")
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = PIPE_RADIUS_M
	cylinder.bottom_radius = PIPE_RADIUS_M
	cylinder.height = PIPE_LENGTH_M
	mesh.mesh = cylinder
	grip.add_child(mesh)
	var tip_local := grip.global_transform.affine_inverse() * rig.get_point_position(&"WeaponTip")
	var dir := tip_local.normalized()
	mesh.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), dir * (PIPE_LENGTH_M * 0.5 - PIPE_GRIP_BACK_M))
	return mesh
