extends GutTest
## The shared enemy move checks (tests/enemy_move_checks.gd) against a move that exists today:
## the sparring dummy's jab, an enemy attack in everything but its table. The archetypes' own
## move tests run the same helpers on their moves, so these keep the helpers honest: they must
## pass a good move, and fail a bad pose.

const Checks := preload("res://tests/enemy_move_checks.gd")
const JAB_PATH := "res://game/combat/moves/dummy_jab.tres"
const SPARRING_STEP_IN_M := 0.9
const ENEMY_HEIGHT := 1.8


func before_all() -> void:
	# First-person checks use the shipped lens offsets.
	Tuning.reset_to_default()


func after_all() -> void:
	Tuning.reset_to_default()


func _jab() -> MoveData:
	return load(JAB_PATH) as MoveData


func _rig() -> HumanoidRig:
	var rig := HumanoidRig.new()
	add_child_autofree(rig)
	rig.build()
	return rig


func test_the_clip_checks_pass_the_dummy_jab() -> void:
	# It has no held wind-up (that is for the new enemy moves), but its clip is the right
	# length, keys the wind-up at 40-60% of the startup and returns to the guard.
	Checks.check_clip(self, _rig(), _jab(), false)


func test_a_clip_without_a_held_windup_fails_when_one_is_required() -> void:
	var problems := Checks.clip_problems(_rig(), _jab(), true)
	assert_eq(problems.size(), 1, "only the hold is missing: %s" % [problems])
	assert_string_contains("; ".join(problems), "does not hold its wind-up")


func test_joint_limits_accept_the_stances_and_the_jab_and_refuse_a_wild_arm() -> void:
	Checks.check_joint_limits(self, PlaceholderPoses.guard(), "the boxer guard")
	Checks.check_recipe_joint_limits(self, _jab())
	# A 170-degree forward raise of the upper arm (the pipe swing's old wind-up) is past the
	# ragdoll cone; a knee bent the wrong way and an elbow past 150 are past their hinges.
	var wild := PlaceholderPoses.guard()
	wild[&"RightUpperArm"] = Vector3(170.0, 0.0, 13.0)
	wild[&"LeftLowerLeg"] = Vector3(30.0, 0.0, 0.0)
	wild[&"LeftLowerArm"] = Vector3(160.0, 0.0, 0.0)
	var problems := Checks.joint_problems(wild)
	assert_eq(problems.size(), 3, "the arm, the knee and the elbow are each refused: %s" % [problems])
	# 135 degrees of raise is the edge, still inside.
	var edge := PlaceholderPoses.guard()
	edge[&"RightUpperArm"] = Vector3(135.0, 0.0, 0.0)
	Checks.check_joint_limits(self, edge, "135 degrees of raise")


func test_the_measured_reach_of_the_dummy_jab_is_its_reach_m() -> void:
	var jab := _jab()
	var measured := Checks.measure_reach(ENEMY_HEIGHT, jab, self)
	gut.p("dummy_jab measured reach: %.2f m (reach_m %.2f)" % [measured, jab.reach_m])
	Checks.check_reach(self, jab, ENEMY_HEIGHT, self)
	assert_between(measured, 0.8, 1.4, "about a metre")


func test_a_bigger_attacker_reaches_further() -> void:
	# The same move on a 2.05 m rig strikes from further off (strike points scale with the rig).
	var jab := _jab()
	var small := Checks.measure_reach(ENEMY_HEIGHT, jab, self)
	var big := Checks.measure_reach(2.05, jab, self)
	assert_gt(big, small, "the Bruiser's rig is %.2f m against %.2f m" % [big, small])


func test_reach_counts_the_moves_travel() -> void:
	var jab := _jab().duplicate() as MoveData
	var plain := Checks.measure_reach(ENEMY_HEIGHT, jab, self)
	jab.free_lunge = 1.5
	assert_almost_eq(Checks.measure_reach(ENEMY_HEIGHT, jab, self), plain + 1.5, 0.001, "travel is added")


func test_the_first_person_telegraph_of_the_dummy_jab() -> void:
	# At the sparring step-in and a posture ring's 2.5 m: the head shows through the startup and
	# the striking fist is in the view at the wind-up key.
	Checks.check_fp_telegraph(self, _jab(), ENEMY_HEIGHT, SPARRING_STEP_IN_M)
	Checks.check_fp_telegraph(self, _jab(), ENEMY_HEIGHT, 2.5)
