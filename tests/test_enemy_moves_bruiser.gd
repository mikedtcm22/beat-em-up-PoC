extends GutTest
## The Bruiser's smash (bruiser_smash) and brace clip through the shared enemy move checks
## (tests/enemy_move_checks.gd), on a 2.05 m rig: the clip's timing and held wind-up, every key pose
## inside the ragdoll's joint limits, the strike's measured reach against reach_m, and the wind-up as
## the defender's first-person lens sees it. What is the smash's own: the wind-up is overhead (both
## fists above the head, held), and the strike aims down (the poses are angles, so on a 2.05 m body an
## arm straight out would pass over a 1.8 m player's head: the fists end at his head and shoulders).
## Its grab and headbutt are tests/test_enemy_moves_grab.gd's.

const Checks := preload("res://tests/enemy_move_checks.gd")
const BruiserTable := preload("res://tests/enemy_moves/bruiser_table.gd")
const MOVES_DIR := "res://game/combat/moves/"
const ENEMY_HEIGHT := 2.05
## Where a Bruiser winds up from: the posture ring's near edge, where a wind-up is seen whole, and
## the step-in distance it really winds up at (its reach less engage_margin_m, the lens a little ahead).
const RING_M := 2.5
const CLOSE_M := 1.2
## The strike's fists end between these heights above the floor (m): a 1.8 m player's chest and head
## (his head hurtbox is centred at 1.66 m).
const STRIKE_LOW_M := 1.2
const STRIKE_HIGH_M := 1.9
## The strike's fists are at least this far in front of the Bruiser's origin (m).
const STRIKE_AHEAD_M := 0.8
## The brace pushes the chest out: the head goes back at least this far (degrees of neck and spine).
const BRACE_MIN_DEG := 6.0


func before_all() -> void:
	# First-person checks use the shipped lens offsets.
	Tuning.reset_to_default()


func after_all() -> void:
	Tuning.reset_to_default()


func _smash() -> MoveData:
	return load("%sbruiser_smash.tres" % MOVES_DIR) as MoveData


func _rig() -> HumanoidRig:
	var rig := HumanoidRig.new()
	rig.height = ENEMY_HEIGHT
	add_child_autofree(rig)
	rig.build()
	return rig


## The rig playing the smash, advanced `frames` frames into it.
func _rig_at(frames: int) -> HumanoidRig:
	var rig := _rig()
	rig.play(&"idle", 0.0)
	rig.advance(0.5)
	rig.play_move(_smash(), 0.0)
	for f: int in frames:
		rig.advance(Checks.FRAME)
	return rig


func test_the_move_exists_and_has_a_recipe() -> void:
	assert_not_null(_smash(), "bruiser_smash loads")
	assert_true(PlaceholderEnemyPoses.has_recipe(&"bruiser_smash"), "it has a recipe")
	assert_true(EnemyPosesBruiser.MOVE_IDS.has(&"bruiser_smash"), "the Bruiser's pose file's")


func test_the_clip_is_timed_and_held() -> void:
	Checks.check_clip(self, _rig(), _smash(), true)


func test_every_key_pose_is_inside_the_ragdolls_joint_limits() -> void:
	Checks.check_recipe_joint_limits(self, _smash())


func test_the_measured_reach_is_reach_m() -> void:
	var move := _smash()
	gut.p("smash measured reach %.2f m (reach_m %.2f)" % [Checks.measure_reach(ENEMY_HEIGHT, move, self), move.reach_m])
	Checks.check_reach(self, move, ENEMY_HEIGHT, self)


func test_the_wind_up_reads_from_the_ring() -> void:
	# At 2.5 m the whole of it is in the view: the head shows throughout and both fists are in view at the
	# held key (the shared check).
	Checks.check_fp_telegraph(self, _smash(), ENEMY_HEIGHT, RING_M)


func test_the_wind_up_keeps_the_head_in_view_at_arms_length() -> void:
	# At 1.2 m the raised fists are over the top of the lens (a raised weapon at arm's length is: the
	# Thug's call 6), so the shared check's "striking hand in view" line does not apply; the head still must.
	for distance: float in [1.0, CLOSE_M]:
		var problems := Checks.fp_telegraph_problems(_smash(), ENEMY_HEIGHT, distance, self)
		var head_problems := PackedStringArray()
		for problem: String in problems:
			if not problem.begins_with("the striking"):
				head_problems.append(problem)
		assert_true(head_problems.is_empty(), "the head shows through the wind-up from %.1f m (%s)" % [distance, "; ".join(head_problems)])


func test_the_held_wind_up_is_overhead() -> void:
	var move := _smash()
	var poses := PlaceholderPoses.move_poses(move.get_anim())
	var held := roundi(PlaceholderAnims.windup_hold_time(move, poses) / Checks.FRAME)
	var rig := _rig_at(held)
	var top := rig.get_point_position(&"HeadTopPoint").y
	for point: StringName in [&"LeftFistPoint", &"RightFistPoint"]:
		var fist := rig.get_point_position(point)
		gut.p("held wind-up: %s at y %.2f (head top %.2f)" % [point, fist.y, top])
		assert_gt(fist.y, top, "%s is above the head: both fists raised overhead" % point)
	assert_gte(held, 20, "it is held, not flashed: the raise is done well before the strike (frame %d of %d)" % [held, move.startup])


func test_the_strike_aims_down_at_the_players_head_and_shoulders() -> void:
	var move := _smash()
	var rig := _rig_at(move.startup)
	for point: StringName in [&"LeftFistPoint", &"RightFistPoint"]:
		var fist := rig.get_point_position(point)
		gut.p("strike: %s at (%.2f, %.2f, %.2f)" % [point, fist.x, fist.y, fist.z])
		assert_gte(fist.y, STRIKE_LOW_M, "%s is not below the chest" % point)
		assert_lte(fist.y, STRIKE_HIGH_M, "%s is not above the head: it chops down on a 1.8 m body" % point)
		assert_lt(fist.z, -STRIKE_AHEAD_M, "%s is out in front of the Bruiser" % point)
		assert_lt(absf(fist.x), 0.5, "%s is within a body's width of the centre line" % point)
	var left := rig.get_point_position(&"LeftFistPoint")
	var right := rig.get_point_position(&"RightFistPoint")
	assert_lt(left.x, right.x, "the left fist is on the left")
	assert_eq(move.hitboxes.size(), 2, "both fists strike")


func test_the_hitboxes_are_a_big_bodys_fists() -> void:
	var move := _smash()
	for spec: HitboxSpec in move.hitboxes:
		assert_eq(spec.kind, HitboxSpec.Kind.POINT_SPHERE)
		assert_gte(spec.radius, 0.2, "absolute metres: 0.2 for a body this big, not the Punk's 0.14")
	assert_eq(move.hitboxes[0].point, &"LeftFistPoint")
	assert_eq(move.hitboxes[1].point, &"RightFistPoint")


func test_the_wind_up_is_at_least_the_heavy_floor() -> void:
	assert_gte(_smash().startup, Tuning.data.windup_min_frames_heavy, "a full heavy telegraph")


func test_the_table_row_matches_the_file() -> void:
	var row: Dictionary = BruiserTable.MOVES[&"bruiser_smash"]
	var move := _smash()
	assert_eq(move.damage, row.damage, "damage")
	assert_eq(move.tier, row.tier, "tier")
	assert_eq(move.reaction, row.reaction, "reaction")
	assert_eq(move.blocked_recoil_frames, row.recoil, "no recoil from a block")
	assert_almost_eq(move.reach_m, float(row.reach_m), 0.0001, "reach")
	assert_false(move.unblockable, "a guard can stop it")
	assert_false(move.magnetism, "it does not track")
	assert_true(move.branches.is_empty(), "no branches")
	assert_eq(move.auto_next, null, "no auto_next")


func test_the_smash_costs_a_guard_60_of_100() -> void:
	var drain := Tuning.data.guard_drain_per_damage * _smash().damage * _smash().guard_damage_mult
	assert_almost_eq(drain, 60.0, 0.001, "SPEC §7: a heavy hit takes most of the guard")
	assert_lt(drain, Tuning.data.guard_max, "but one smash does not break it")


func test_the_attacks_stay_under_the_fifteen_percent_rule() -> void:
	# SPEC §4: a knockdown never costs more than 15 of the player's 100 health, the boss aside.
	for attack: Dictionary in BruiserTable.ATTACKS:
		var total := 0.0
		var knocks := false
		for id: StringName in attack.moves:
			total += float(BruiserTable.MOVES[id].damage)
			knocks = knocks or BruiserTable.MOVES[id].reaction == CombatTypes.Reaction.KNOCKDOWN
		if knocks:
			assert_lte(total, 15.0, "%s: a chain that knocks down costs %.0f" % [attack.name, total])


# --- The brace ---------------------------------------------------------------------------------


func test_the_brace_clip_is_a_short_push_out_and_back_to_the_stance() -> void:
	var rig := _rig()
	assert_true(rig.has_anim(&"brace"))
	var clip := rig.anim_player.get_animation(&"brace")
	assert_almost_eq(clip.length, EnemyPosesBruiser.BRACE_S, 0.001)
	assert_eq(clip.loop_mode, Animation.LOOP_NONE, "once")
	var named := EnemyPosesBruiser.named(&"brace", PlaceholderPoses.guard())
	for key: PlaceholderAnims.PoseKey in named.keys:
		var problems := Checks.joint_problems(key.pose)
		assert_true(problems.is_empty(), "the brace stays inside the joint limits (%s)" % "; ".join(problems))
	var spine := rig.anim_player.get_animation(&"brace").find_track(^"Skeleton3D:Spine", Animation.TYPE_ROTATION_3D)
	var start := clip.rotation_track_interpolate(spine, 0.0)
	var mid := clip.rotation_track_interpolate(spine, clip.length * 0.45)
	var finish := clip.rotation_track_interpolate(spine, clip.length)
	assert_gte(rad_to_deg(start.angle_to(mid)), 3.0, "the chest moves")
	assert_lt(rad_to_deg(start.angle_to(finish)), 0.5, "and it ends in the stance")
