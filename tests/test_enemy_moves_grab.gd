extends GutTest
## The enemy grab moves (bruiser_grab, bruiser_headbutt, boss_grab, boss_slam) through the shared
## enemy move checks (tests/enemy_move_checks.gd): each clip's timing and held wind-up, every key
## pose inside the ragdoll's joint limits, plus what is particular to a grab: no hitbox, unblockable,
## never recoiling, a reach that is where the strike pose's fists meet the player (not a hitbox:
## measured on the rig) and the connect range of EnemyHold, a follow-up whose reach is the pin
## distance, the 15% rule for the Bruiser's pair, no FINISHER tier for the boss's slam, the three
## named holds (hold_collar, held_collar, held_lift), and how each grab wind-up reads from the
## defender's first-person lens.

const Checks := preload("res://tests/enemy_move_checks.gd")
const GrabTable := preload("res://tests/enemy_moves/grab_table.gd")
const MOVES_DIR := "res://game/combat/moves/"
## The grabbers' heights and radii (the test grabber scenes; the Bruiser's and the boss's own).
const BRUISER_HEIGHT := 2.05
const BOSS_HEIGHT := 2.3
const BRUISER_RADIUS := 0.45
const BOSS_RADIUS := 0.5
## How far in front of a standing player's origin his chest is (m): where a fist meets him.
const CHEST_FRONT_M := 0.12
## The grab's reach_m against the strike pose's fists and against the connect range.
const REACH_TOLERANCE_M := 0.15
const GRAB_IDS: Array[StringName] = [&"bruiser_grab", &"boss_grab"]
const FOLLOW_UP_IDS: Array[StringName] = [&"bruiser_headbutt", &"boss_slam"]


func before_all() -> void:
	Tuning.reset_to_default()


func after_all() -> void:
	Tuning.reset_to_default()


func _move(id: StringName) -> MoveData:
	return load("%s%s.tres" % [MOVES_DIR, id]) as MoveData


func _rig(height: float = 1.8) -> HumanoidRig:
	var rig := HumanoidRig.new()
	rig.height = height
	add_child_autofree(rig)
	rig.build()
	return rig


func _height_of(id: StringName) -> float:
	return BOSS_HEIGHT if String(id).begins_with("boss") else BRUISER_HEIGHT


func test_the_four_moves_exist_and_have_recipes() -> void:
	assert_eq(GrabTable.MOVES.size(), 4)
	for id: StringName in GrabTable.MOVES:
		assert_not_null(_move(id), "%s loads" % id)
		assert_true(PlaceholderEnemyPoses.has_recipe(id), "%s has a recipe" % id)
		assert_true(GrabPoses.MOVE_IDS.has(id), "%s is the grab pose file's" % id)


func test_every_clip_is_timed_and_held() -> void:
	var rig := _rig()
	for id: StringName in GrabTable.MOVES:
		Checks.check_clip(self, rig, _move(id), true)


func test_every_key_pose_is_inside_the_ragdolls_joint_limits() -> void:
	for id: StringName in GrabTable.MOVES:
		Checks.check_recipe_joint_limits(self, _move(id))
	var g := PlaceholderPoses.guard()
	for id: StringName in [&"hold_collar", &"held_collar", &"held_lift"]:
		var named := GrabPoses.named(id, g if id == &"hold_collar" else PlaceholderPoses.relaxed())
		var keys: Array = named["keys"]
		for key: PlaceholderAnims.PoseKey in keys:
			Checks.check_joint_limits(self, key.pose, "%s at %.2f s" % [id, key.time])
	Checks.check_joint_limits(self, GrabPoses.bruiser_hold(g), "bruiser hold")
	Checks.check_joint_limits(self, GrabPoses.boss_hold(g), "boss hold")


func test_the_moves_follow_the_grab_rules() -> void:
	for id: StringName in GrabTable.MOVES:
		var row: Dictionary = GrabTable.MOVES[id]
		var move := _move(id)
		assert_eq(move.hitboxes.size(), 0, "%s: no hitbox (a grab connects by code, a follow-up hits by code)" % id)
		assert_true(move.unblockable, "%s: unblockable" % id)
		assert_eq(move.blocked_recoil_frames, 0, "%s: no recoil" % id)
		assert_false(move.magnetism, "%s: no magnetism" % id)
		assert_eq(move.damage, row.damage, "%s: damage" % id)
		assert_almost_eq(move.reach_m, float(row.reach_m), 0.0001, "%s: reach_m" % id)
		assert_gte(move.startup, Tuning.data.windup_min_frames_heavy, "%s: at least the heavy wind-up floor" % id)
		assert_ne(move.tier, CombatTypes.HitTier.FINISHER, "%s: no FINISHER tier (A2.13)" % id)
	assert_eq([_move(&"bruiser_grab").startup, _move(&"bruiser_grab").active, _move(&"bruiser_grab").recovery], [32, 6, 24])
	assert_eq([_move(&"bruiser_headbutt").startup, _move(&"bruiser_headbutt").active, _move(&"bruiser_headbutt").recovery], [60, 3, 24])
	assert_eq([_move(&"boss_grab").startup, _move(&"boss_grab").active, _move(&"boss_grab").recovery], [32, 6, 24])
	assert_eq([_move(&"boss_slam").startup, _move(&"boss_slam").active, _move(&"boss_slam").recovery], [54, 4, 30])
	assert_eq(_move(&"bruiser_grab").damage, 0.0, "the grab itself costs nothing")
	assert_eq(_move(&"bruiser_headbutt").reaction, CombatTypes.Reaction.KNOCKDOWN)
	assert_eq(_move(&"boss_slam").reaction, CombatTypes.Reaction.THROWN)
	assert_eq(_move(&"boss_slam").tier, CombatTypes.HitTier.HEAVY, "the slam is HEAVY, THROWN, never FINISHER")


func test_the_bruisers_pair_costs_the_player_at_most_15_percent() -> void:
	var total := _move(&"bruiser_grab").damage + _move(&"bruiser_headbutt").damage
	assert_lte(total, 15.0, "grab + headbutt knock down for at most 15 of his 100 health (SPEC §4)")
	assert_true(GrabTable.ATTACKS.any(func(a: Dictionary) -> bool: return a.boss and a.moves == [&"boss_grab", &"boss_slam"]), "the boss's pair is the boss's")


## The flat distance (m) from a grabber's origin to the middle of the two fists at the grab's strike
## frame (its strike pose, held there): how far the arms reach.
func _fist_depth(id: StringName) -> float:
	var rig := _rig(_height_of(id))
	var move := _move(id)
	rig.play(&"idle", 0.0)
	rig.advance(0.5)
	rig.play_move(move, 0.0)
	for i: int in move.startup:
		rig.advance(1.0 / 60.0)
	var left := rig.get_point_position(&"LeftFistPoint")
	var right := rig.get_point_position(&"RightFistPoint")
	var middle := (left + right) * 0.5
	return Vector2(middle.x - rig.global_position.x, middle.z - rig.global_position.z).length()


func test_the_reach_is_where_the_strike_poses_fists_meet_his_chest() -> void:
	for id: StringName in GRAB_IDS:
		var depth := _fist_depth(id)
		var move := _move(id)
		gut.p("%s: the fists reach %.2f m, plus his chest %.2f; reach_m %.2f" % [id, depth, depth + CHEST_FRONT_M, move.reach_m])
		assert_almost_eq(depth + CHEST_FRONT_M, move.reach_m, REACH_TOLERANCE_M, "%s: reach_m is where the fists meet a standing player" % id)


func test_the_reach_is_inside_the_connect_range_the_hold_uses() -> void:
	for id: StringName in GRAB_IDS:
		var height := _height_of(id)
		var range_m := Tuning.data.enemy_grab_range_m * height / PlaceholderBody.REF_HEIGHT
		var move := _move(id)
		assert_almost_eq(move.reach_m, range_m, REACH_TOLERANCE_M, "%s: reach_m %.2f is the connect range %.2f" % [id, move.reach_m, range_m])
		assert_lte(move.reach_m - Tuning.data.engage_margin_m, range_m, "%s: the AI closes in to within the range" % id)


func test_a_follow_ups_reach_is_where_the_player_is_pinned() -> void:
	var probe := CombatActor.new()
	var default_radius := probe.body_radius
	probe.free()
	for pair: Array in [[&"bruiser_headbutt", BRUISER_RADIUS], [&"boss_slam", BOSS_RADIUS]]:
		var pinned := Tuning.data.grabbed_pin_distance_m + maxf(float(pair[1]) - default_radius, 0.0)
		assert_almost_eq(_move(pair[0]).reach_m, pinned, 0.0001, "%s: reach_m is the pin distance %.2f" % [pair[0], pinned])


func test_the_grab_winds_up_in_view_at_the_ring_and_close_in() -> void:
	# The first-person telegraph: the grabber's head stays in view through the wind-up (the arms
	# spread wide at the edges of the lens, judged from the sheets of "Grab: dodge out"). The boss, a
	# head taller, is judged from 1.5 m: at its strike range its head is over the top of the view
	# for the first moments of the wind-up (it stoops into the hold).
	var cases: Array[Array] = [[&"bruiser_grab", 1.1], [&"bruiser_grab", 2.5], [&"boss_grab", 1.5], [&"boss_grab", 2.5]]
	for entry: Array in cases:
		var problems := Checks.fp_telegraph_problems(_move(entry[0]), _height_of(entry[0]), entry[1], self)
		assert_true(problems.is_empty(), "%s from %.1f m: %s" % [entry[0], entry[1], "; ".join(problems)])


func test_the_named_holds_exist_loop_and_agree_with_the_moves() -> void:
	var rig := _rig()
	for id: StringName in [&"hold_collar", &"held_collar", &"held_lift"]:
		assert_true(rig.has_anim(id), "%s exists" % id)
		var anim := rig.anim_player.get_animation(id)
		assert_eq(anim.loop_mode, Animation.LOOP_LINEAR, "%s loops" % id)
	# The headbutt starts in the hold (its guard pose), so the follow-up begins with no jump.
	var hold := GrabPoses.bruiser_hold(PlaceholderPoses.guard())
	var poses := PlaceholderPoses.move_poses(&"bruiser_headbutt")
	for bone: StringName in hold:
		if PlaceholderPoses.is_bone_key(bone):
			assert_eq(poses.guard[bone], hold[bone], "bruiser_headbutt starts in the hold (%s)" % bone)
	var boss_hold := GrabPoses.boss_hold(PlaceholderPoses.guard())
	var slam := PlaceholderPoses.move_poses(&"boss_slam")
	for bone: StringName in boss_hold:
		if PlaceholderPoses.is_bone_key(bone):
			assert_eq(slam.guard[bone], boss_hold[bone], "boss_slam starts in the boss's hold (%s)" % bone)


func test_the_lifted_pose_hangs_higher_and_the_held_pose_does_not_nudge_the_hips() -> void:
	var relaxed := PlaceholderPoses.relaxed()
	var held := GrabPoses.held_pose(relaxed)
	var lifted := GrabPoses.held_pose(relaxed, true)
	assert_false(held.has(PlaceholderPoses.HIPS_POS), "the held pose is planted")
	assert_false(held.has(PlaceholderPoses.HIPS_NUDGE), "no hips nudge: a release moves nothing")
	var planted := PlaceholderAnims.resolve_hips(held)
	var raised := PlaceholderAnims.resolve_hips(lifted)
	assert_gt(raised.y, planted.y + GrabPoses.LIFT_M - 0.06, "lifted: the hips hang a lift's height higher")


func test_the_table_rows_match_the_files() -> void:
	for id: StringName in GrabTable.MOVES:
		var row: Dictionary = GrabTable.MOVES[id]
		var move := _move(id)
		assert_eq(move.tier, row.tier, "%s tier" % id)
		assert_eq(move.reaction, row.reaction, "%s reaction" % id)
		assert_eq(move.unblockable, row.unblockable, "%s unblockable" % id)
		assert_eq(move.blocked_recoil_frames, row.recoil, "%s recoil" % id)
