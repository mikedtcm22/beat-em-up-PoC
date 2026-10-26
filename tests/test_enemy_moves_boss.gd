extends GutTest
## The boss's moves (boss_charge, boss_pound) through the shared enemy move checks
## (tests/enemy_move_checks.gd), measured on a 2.3 m rig: the clip's timing and held wind-up, every
## key pose inside the ragdoll's joint limits, the strike's measured reach against reach_m (the
## charge's includes its 4 m dash: A6.2), and the wind-up as the defender's first-person lens sees
## it. Both strikes are arcs round the boss's feet and shoulder, so the poses only have to read: the
## charge's crouch and the pound's raised arms are held to the lens (the head stays in view, the
## eye sinks for the charge, the fists rise past the head for the pound). Plus the run loop and the
## shape of the data: heavy tier, no recoil when blocked, the pound unblockable and low enough for a
## jump to clear, the grab's slam HEAVY and THROWN (A6.2).

const Checks := preload("res://tests/enemy_move_checks.gd")
const BossTable := preload("res://tests/enemy_moves/boss_table.gd")
const GrabTable := preload("res://tests/enemy_moves/grab_table.gd")
const MOVES_DIR := "res://game/combat/moves/"
const BOSS_HEIGHT := 2.3
## Where a wind-up is read from: the posture ring's near and far edges. Not one metre: the boss's
## head is 2.1 m up, which at a metre is over the top of the lens whatever it does (the lens looks 29
## degrees up), and the only attack it throws from that close is the grab, whose hold is the view.
const NEAR_M := 2.5
const RING_M := 4.0
## How far the eye (the head) sinks from the guard to the charge's held wind-up: at least this
## much (m), so the crouch reads from the lens.
const CHARGE_SINK_M := 0.3
## The pound's fists are this far (m) above the eyes at the held key: the ragdoll's shoulder cone
## (140 degrees of raise) keeps them about level with the top of the head, no higher.
const POUND_FISTS_ABOVE_EYE_M := 0.25
## The charge's dash covers this share of its reach at least (the rest is the arc).
const DASH_SHARE := 0.6


func before_all() -> void:
	# First-person checks use the shipped lens offsets.
	Tuning.reset_to_default()


func after_all() -> void:
	Tuning.reset_to_default()


func _move(id: StringName) -> MoveData:
	return load("%s%s.tres" % [MOVES_DIR, id]) as MoveData


func _rig(height: float = BOSS_HEIGHT) -> HumanoidRig:
	var rig := HumanoidRig.new()
	rig.height = height
	add_child_autofree(rig)
	rig.build()
	return rig


func _ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in BossTable.MOVES:
		out.append(id)
	return out


func test_the_two_moves_exist_and_have_recipes() -> void:
	assert_eq(_ids().size(), 2, "charge and pound (the grab and slam are the grab table's)")
	for id: StringName in _ids():
		assert_not_null(_move(id), "%s loads" % id)
		assert_true(PlaceholderEnemyPoses.has_recipe(id), "%s has a recipe" % id)
		assert_true(EnemyPosesBoss.MOVE_IDS.has(id), "%s is the boss's pose file's" % id)


func test_every_clip_is_timed_and_held() -> void:
	var rig := _rig()
	for id: StringName in _ids():
		Checks.check_clip(self, rig, _move(id), true)


func test_every_key_pose_is_inside_the_ragdolls_joint_limits() -> void:
	for id: StringName in _ids():
		Checks.check_recipe_joint_limits(self, _move(id))


func test_the_run_loop_is_a_looping_clip_inside_the_joint_limits() -> void:
	var rig := _rig()
	assert_true(rig.has_anim(&"run_forward"), "the rig has it")
	assert_true(PlaceholderAnims.LOOPING.has(&"run_forward"), "and it is a loop")
	var named := EnemyPosesBoss.named(&"run_forward", PlaceholderPoses.guard())
	assert_almost_eq(float(named.length), EnemyPosesBoss.RUN_LOOP_S, 0.0001)
	var keys: Array[PlaceholderAnims.PoseKey] = named.keys
	assert_gte(keys.size(), 4, "a stride is more than a held pose")
	assert_almost_eq(keys[0].time, 0.0, 0.0001)
	assert_almost_eq(keys[keys.size() - 1].time, float(named.length), 0.0001, "the loop closes on its length")
	for key: PlaceholderAnims.PoseKey in keys:
		Checks.check_joint_limits(self, key.pose, "run_forward at %.3f s" % key.time)
	# The last key is the first: it loops without a pop.
	assert_eq(keys[0].pose, keys[keys.size() - 1].pose)
	rig.play(&"run_forward", 0.0)
	assert_eq(rig.anim_player.get_animation(&"run_forward").loop_mode, Animation.LOOP_LINEAR)


func test_the_measured_reach_is_reach_m() -> void:
	for id: StringName in _ids():
		var move := _move(id)
		gut.p("%s measured reach %.2f m (reach_m %.2f)" % [id, Checks.measure_reach(BOSS_HEIGHT, move, self), move.reach_m])
		Checks.check_reach(self, move, BOSS_HEIGHT, self)


func test_the_charges_reach_includes_its_dash() -> void:
	# A6.2: reach_m is where the strike connects, travel included, so the rear warning still fires
	# from the far end of the dash. The arc alone touches a standing body a little past a metre.
	var charge := _move(&"boss_charge")
	assert_almost_eq(charge.free_lunge, 4.0, 0.0001, "it dashes 4 m")
	assert_gt(charge.reach_m, charge.free_lunge, "reach_m is the dash plus the arc's")
	assert_gte(charge.free_lunge / charge.reach_m, DASH_SHARE, "the dash is most of the reach")
	var without := charge.duplicate() as MoveData
	without.free_lunge = 0.0
	assert_almost_eq(Checks.measure_reach(BOSS_HEIGHT, without, self) + charge.free_lunge, charge.reach_m,
			Checks.REACH_TOLERANCE_M, "the dash is what the reach adds to the arc's own")


func test_the_dash_is_a_free_lunge_over_the_active_frames_only() -> void:
	# The base applies free_lunge from the last startup frame over `active` frames, so the wind-up
	# never slides (and the held telegraph stays where it stands).
	var charge := _move(&"boss_charge")
	assert_gt(charge.active, 12, "a long active window to run in")
	assert_eq(charge.lunge, 0.0, "no startup lunge: the base would spread it over the wind-up")
	assert_gt(charge.free_lunge, 0.0)


func test_the_telegraphs_keep_the_head_in_view_at_the_ring() -> void:
	for id: StringName in _ids():
		for distance: float in [NEAR_M, RING_M]:
			var problems := Checks.fp_telegraph_problems(_move(id), BOSS_HEIGHT, distance, self)
			assert_true(problems.is_empty(), "%s: the wind-up reads from %.1f m%s" % [id, distance, Checks._list(problems)])


func test_the_charges_wind_up_is_a_crouch_the_lens_can_see() -> void:
	var sink := _eye_sink(_move(&"boss_charge"))
	gut.p("charge: the eye sinks %.2f m at the held wind-up" % sink)
	assert_gte(sink, CHARGE_SINK_M, "the head sinks at least %.2f m: a bull lowering its head, not a stance" % CHARGE_SINK_M)


func test_the_pounds_fists_are_overhead_at_the_held_wind_up() -> void:
	var rig := _rig()
	var pound := _move(&"boss_pound")
	rig.play(&"idle", 0.0)
	rig.advance(0.5)
	var poses := PlaceholderPoses.move_poses(pound.get_anim())
	var held_frame := roundi(PlaceholderAnims.windup_hold_time(pound, poses) / Checks.FRAME)
	rig.play_move(pound, 0.0)
	for f: int in held_frame:
		rig.advance(Checks.FRAME)
	var left := rig.get_point_position(&"LeftFistPoint").y
	var right := rig.get_point_position(&"RightFistPoint").y
	var eye := rig.get_point_position(&"EyePoint").y
	gut.p("pound: fists %.2f / %.2f m, eye %.2f m" % [left, right, eye])
	assert_gte(minf(left, right), eye + POUND_FISTS_ABOVE_EYE_M, "both fists are well above the face at the held wind-up: a rearing slam")


func test_the_charge_strikes_in_a_stride_and_the_pound_is_a_ring_near_the_floor() -> void:
	var charge := _move(&"boss_charge")
	var spec: HitboxSpec = charge.hitboxes[0]
	assert_eq(spec.kind, HitboxSpec.Kind.ARC, "the charge is an arc in front of the shoulder")
	assert_lt(spec.arc_half_angle_deg, 90.0, "a cone, not a ring: a sidestep dodges it")
	var pound := _move(&"boss_pound")
	var ring: HitboxSpec = pound.hitboxes[0]
	assert_eq(ring.kind, HitboxSpec.Kind.ARC)
	assert_eq(ring.arc_half_angle_deg, 180.0, "all the way round")
	assert_almost_eq(ring.arc_height.x, 0.0, 0.0001, "from the floor")
	assert_lte(ring.arc_height.y, 0.7, "to the shins: a jump clears it")
	assert_true(pound.unblockable, "a guard does not stop it")


func test_the_wind_ups_are_at_least_the_heavy_floor() -> void:
	var floor_frames := Tuning.data.windup_min_frames_heavy
	for id: StringName in _ids():
		assert_gte(_move(id).startup, floor_frames, "%s: a full heavy telegraph" % id)


func test_the_table_rows_match_the_files() -> void:
	for id: StringName in _ids():
		var row: Dictionary = BossTable.MOVES[id]
		var move := _move(id)
		assert_eq(move.damage, row.damage, "%s damage" % id)
		assert_eq(move.tier, row.tier, "%s tier" % id)
		assert_eq(move.reaction, row.reaction, "%s reaction" % id)
		assert_eq(move.blocked_recoil_frames, row.recoil, "%s recoil (the boss's moves never recoil)" % id)
		assert_eq(move.blocked_recoil_frames, 0)
		assert_almost_eq(move.reach_m, float(row.reach_m), 0.0001, "%s reach" % id)
		assert_eq(move.unblockable, row.get("unblockable", false), "%s unblockable" % id)
		assert_false(move.magnetism, "%s does not track" % id)
		assert_true(move.branches.is_empty() and move.auto_next == null, "%s has no chain of its own" % id)


func test_no_boss_move_is_a_finisher_and_the_slam_is_heavy_and_thrown() -> void:
	# A2.13: the finisher tier fires the global slow-mo and impact frame. A6.2: boss_slam is HEAVY, THROWN.
	for id: StringName in [&"boss_charge", &"boss_pound", &"boss_grab", &"boss_slam"]:
		assert_ne(_move(id).tier, CombatTypes.HitTier.FINISHER, "%s is not a finisher" % id)
	var slam := _move(&"boss_slam")
	assert_eq(slam.tier, CombatTypes.HitTier.HEAVY)
	assert_eq(slam.reaction, CombatTypes.Reaction.THROWN)
	assert_eq(slam.damage, 25.0)
	assert_true(GrabTable.ATTACKS.any(func(a: Dictionary) -> bool: return a.boss and a.moves.has(&"boss_slam")),
			"the slam is in the grab table's boss attack")


func test_every_boss_attack_is_marked_boss_so_the_fifteen_percent_rule_exempts_it() -> void:
	for attack: Dictionary in BossTable.ATTACKS:
		assert_true(attack.boss, "%s is the boss's" % attack.name)
	var total := 0.0
	for id: StringName in _ids():
		total += float(BossTable.MOVES[id].damage)
	assert_gt(total, 15.0, "together they cost more than a Punk's knockdown could: that is why it is exempt")


## How far the eye of a rig `BOSS_HEIGHT` tall drops (m) from its guard to `move`'s held wind-up key.
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
