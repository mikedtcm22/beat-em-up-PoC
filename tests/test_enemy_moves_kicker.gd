extends GutTest
## The Kicker's moves (kicker_jump_kick, kicker_sweep) through the shared enemy move checks
## (tests/enemy_move_checks.gd): the clip's timing and held wind-up, every key pose inside the
## ragdoll's joint limits, the strike's measured reach against reach_m (the jump kick's includes
## its leap), and the wind-up as the defender's first-person lens sees it. Both telegraphs are
## crouches, so the lens sees the head sink rather than a striking limb: the head stays in view and
## the eye drops by a body's length of crouch, which is what these tests hold the poses to (the
## shared check wants the striking limb in view at the held key, and a kicking foot is on the
## floor there). The strike's own shapes: the jump kick leaves the floor (the hips rise), the sweep
## is an arc over the legs only.

const Checks := preload("res://tests/enemy_move_checks.gd")
const FPView := preload("res://tests/fp_view.gd")
const KickerTable := preload("res://tests/enemy_moves/kicker_table.gd")
const MOVES_DIR := "res://game/combat/moves/"
const ENEMY_HEIGHT := 1.8
## Where a Kicker winds up: the jump kick from the posture ring's near edge (its engage distance is
## its whole reach, 2.7 m), the sweep from its own short reach; and one metre, as the shared
## checks read a telegraph at.
const CLOSE_M := 1.0
const RING_M := 2.5
## How far the eye (the head) sinks from the guard to the held wind-up: at least this much (m), so
## the crouch reads from the lens, for the jump kick and for the sweep's drop to the floor.
const JUMP_KICK_SINK_M := 0.3
const SWEEP_SINK_M := 0.4
## How far the hips rise at the jump kick's strike (m): the body visibly leaves the floor.
const JUMP_KICK_RISE_M := 0.25
## The sweep's arc covers up to this height above the floor (m) and no more.
const SWEEP_TOP_M := 0.6


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
	for id: StringName in KickerTable.MOVES:
		out.append(id)
	return out


func test_the_two_moves_exist_and_have_recipes() -> void:
	assert_eq(_ids().size(), 2, "jump kick and sweep")
	for id: StringName in _ids():
		assert_not_null(_move(id), "%s loads" % id)
		assert_true(PlaceholderEnemyPoses.has_recipe(id), "%s has a recipe" % id)
		assert_true(EnemyPosesKicker.MOVE_IDS.has(id), "%s is the Kicker's pose file's" % id)


func test_every_clip_is_timed_and_held() -> void:
	var rig := _rig()
	for id: StringName in _ids():
		Checks.check_clip(self, rig, _move(id), true)


func test_every_key_pose_is_inside_the_ragdolls_joint_limits() -> void:
	for id: StringName in _ids():
		Checks.check_recipe_joint_limits(self, _move(id))


func test_the_measured_reach_is_reach_m() -> void:
	for id: StringName in _ids():
		var move := _move(id)
		gut.p("%s measured reach %.2f m (reach_m %.2f)" % [id, Checks.measure_reach(ENEMY_HEIGHT, move, self), move.reach_m])
		Checks.check_reach(self, move, ENEMY_HEIGHT, self)


func test_the_jump_kicks_reach_includes_its_leap() -> void:
	# A5.2: reach_m is where the strike connects, travel included, so the rear warning still fires
	# from the far end of the leap. The strike pose alone touches a standing body about a metre out.
	var kick := _move(&"kicker_jump_kick")
	assert_gt(kick.free_lunge, 1.0, "it leaps")
	assert_gt(kick.reach_m, kick.free_lunge + 1.0, "reach_m is the strike's reach plus the leap")
	var without := kick.duplicate() as MoveData
	without.free_lunge = 0.0
	assert_almost_eq(Checks.measure_reach(ENEMY_HEIGHT, without, self) + kick.free_lunge, kick.reach_m, Checks.REACH_TOLERANCE_M,
			"the leap is what the reach adds to the strike's own")


func test_the_telegraphs_keep_the_head_in_view_at_one_metre_and_at_the_ring() -> void:
	for id: StringName in _ids():
		for distance: float in [CLOSE_M, RING_M]:
			var problems := Checks.fp_telegraph_problems(_move(id), ENEMY_HEIGHT, distance, self)
			# The shared check also wants the striking foot in the view at the held key; a crouch
			# keeps the foot on the floor, out of the lens (the sink tests below hold the read).
			var head_problems := PackedStringArray()
			for problem: String in problems:
				if not problem.begins_with("the striking"):
					head_problems.append(problem)
			assert_true(head_problems.is_empty(), "%s: the head shows through the wind-up from %.1f m (%s)" % [id, distance, "; ".join(head_problems)])


func test_the_jump_kicks_wind_up_is_a_crouch_the_lens_can_see() -> void:
	var sink := _eye_sink(_move(&"kicker_jump_kick"))
	gut.p("jump kick: the eye sinks %.2f m at the held wind-up" % sink)
	assert_gte(sink, JUMP_KICK_SINK_M, "the head sinks at least %.2f m: a coil, not a stance" % JUMP_KICK_SINK_M)


func test_the_sweeps_wind_up_reads_as_low() -> void:
	var sink := _eye_sink(_move(&"kicker_sweep"))
	gut.p("sweep: the eye sinks %.2f m at the held wind-up" % sink)
	assert_gte(sink, SWEEP_SINK_M, "the head drops at least %.2f m: down to the floor" % SWEEP_SINK_M)


func test_the_jump_kick_leaves_the_floor_and_the_sweep_stays_low() -> void:
	var rig := _rig()
	var kick := _move(&"kicker_jump_kick")
	rig.play(&"idle", 0.0)
	rig.advance(0.5)
	var standing := rig.get_point_position(&"EyePoint").y
	rig.play_move(kick, 0.0)
	for f: int in kick.startup:
		rig.advance(Checks.FRAME)
	assert_gte(rig.get_point_position(&"EyePoint").y - standing, JUMP_KICK_RISE_M, "the hips rise at the strike: the body leaves the floor")
	var sweep := _move(&"kicker_sweep")
	var spec: HitboxSpec = sweep.hitboxes[0]
	assert_eq(spec.kind, HitboxSpec.Kind.ARC, "the sweep is an arc")
	assert_almost_eq(spec.arc_height.x, 0.0, 0.0001, "it starts at the floor")
	assert_lte(spec.arc_height.y, SWEEP_TOP_M, "and reaches no higher than the legs: a jumping player passes over it")


func test_the_wind_ups_are_at_least_the_grunt_floor() -> void:
	var floor_frames := Tuning.data.windup_min_frames_grunt
	for id: StringName in _ids():
		assert_gte(_move(id).startup, floor_frames, "%s: a full telegraph" % id)


func test_the_table_rows_match_the_files() -> void:
	for id: StringName in _ids():
		var row: Dictionary = KickerTable.MOVES[id]
		var move := _move(id)
		assert_eq(move.damage, row.damage, "%s damage" % id)
		assert_eq(move.blocked_recoil_frames, row.recoil, "%s recoil" % id)
		assert_almost_eq(move.reach_m, float(row.reach_m), 0.0001, "%s reach" % id)
		assert_false(move.unblockable, "%s can be blocked" % id)


func test_the_attacks_stay_under_the_fifteen_percent_rule() -> void:
	# SPEC §4: a knockdown never costs more than 15 of the player's 100 health, the boss aside.
	for attack: Dictionary in KickerTable.ATTACKS:
		var total := 0.0
		var knocks := false
		for id: StringName in attack.moves:
			total += float(KickerTable.MOVES[id].damage)
			knocks = knocks or KickerTable.MOVES[id].reaction == CombatTypes.Reaction.KNOCKDOWN
		if knocks:
			assert_lte(total, 15.0, "%s: a chain that knocks down costs %.0f" % [attack.name, total])


## How far the eye of a boxer rig drops (m) from its guard to `move`'s held wind-up key.
func _eye_sink(move: MoveData) -> float:
	var rig := _rig()
	rig.play(&"idle", 0.0)
	rig.advance(0.5)
	var standing := rig.get_point_position(&"EyePoint").y
	var poses := PlaceholderPoses.move_poses(move.get_anim())
	var held_frame := roundi(PlaceholderAnims.windup_hold_time(move, poses) / Checks.FRAME)
	rig.play_move(move, 0.0)
	for f: int in held_frame:
		rig.advance(Checks.FRAME)
	return standing - rig.get_point_position(&"EyePoint").y
