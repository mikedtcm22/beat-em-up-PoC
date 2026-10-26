extends GutTest
## The Street Punk's moves (punk_jab, punk_cross, punk_shove) through the shared enemy move
## checks (tests/enemy_move_checks.gd): the clip's timing and held wind-up, every key pose inside
## the ragdoll's joint limits, the strike's measured reach against reach_m, and the wind-up as
## the defender's first-person lens sees it at 1 m and 2.5 m (the head in view, the striking hand
## in view at the held key). Plus the taunt: open-handed, never a wind-up.

const Checks := preload("res://tests/enemy_move_checks.gd")
const PunkTable := preload("res://tests/enemy_moves/punk_table.gd")
const MOVES_DIR := "res://game/combat/moves/"
const ENEMY_HEIGHT := 1.8
## Where a Punk stands to strike at its reach (the engage step-in) and at the posture ring's
## near edge (a wind-up must read from there too).
const CLOSE_M := 1.0
const RING_M := 2.5
## A taunt keeps every hand below the shoulders: the least height drop (m, at 1.8 m) of a hand
## below its shoulder through the whole clip.
const TAUNT_HAND_BELOW_SHOULDER_M := 0.05


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
	for id: StringName in PunkTable.MOVES:
		out.append(id)
	return out


func test_the_three_moves_exist_and_have_recipes() -> void:
	assert_eq(_ids().size(), 3, "jab, cross and shove")
	for id: StringName in _ids():
		assert_not_null(_move(id), "%s loads" % id)
		assert_true(PlaceholderEnemyPoses.has_recipe(id), "%s has a recipe" % id)
		assert_true(EnemyPosesPunk.MOVE_IDS.has(id), "%s is the Punk's pose file's" % id)


func test_every_clip_is_timed_and_held() -> void:
	var rig := _rig()
	for id: StringName in _ids():
		# The cross is a chain link with no telegraph of its own: no held key.
		Checks.check_clip(self, rig, _move(id), id != &"punk_cross")


func test_every_key_pose_is_inside_the_ragdolls_joint_limits() -> void:
	for id: StringName in _ids():
		Checks.check_recipe_joint_limits(self, _move(id))


func test_the_measured_reach_is_reach_m() -> void:
	for id: StringName in _ids():
		var move := _move(id)
		gut.p("%s measured reach %.2f m (reach_m %.2f)" % [id, Checks.measure_reach(ENEMY_HEIGHT, move, self), move.reach_m])
		Checks.check_reach(self, move, ENEMY_HEIGHT, self)


func test_the_jab_and_the_shove_read_in_first_person_at_one_metre_and_at_the_ring() -> void:
	for id: StringName in [&"punk_jab", &"punk_shove"]:
		for distance: float in [CLOSE_M, RING_M]:
			Checks.check_fp_telegraph(self, _move(id), ENEMY_HEIGHT, distance)


func test_the_cross_shows_its_head_at_one_metre() -> void:
	Checks.check_fp_telegraph(self, _move(&"punk_cross"), ENEMY_HEIGHT, CLOSE_M)


func test_the_wind_ups_are_at_least_the_grunt_floor_and_the_cross_is_a_link() -> void:
	var floor_frames := Tuning.data.windup_min_frames_grunt
	for id: StringName in [&"punk_jab", &"punk_shove"]:
		assert_gte(_move(id).startup, floor_frames, "%s: a full telegraph" % id)
	assert_lt(_move(&"punk_cross").startup, floor_frames, "the cross is a short follow-up link")


func test_the_table_rows_match_the_files() -> void:
	for id: StringName in _ids():
		var row: Dictionary = PunkTable.MOVES[id]
		var move := _move(id)
		assert_eq(move.damage, row.damage, "%s damage" % id)
		assert_eq(move.blocked_recoil_frames, row.recoil, "%s recoil" % id)
		assert_almost_eq(move.reach_m, float(row.reach_m), 0.0001, "%s reach" % id)


func test_the_taunt_is_open_handed_and_about_a_second_long() -> void:
	var rig := _rig()
	var anim := rig.anim_player.get_animation(&"taunt")
	assert_not_null(anim, "the rig has a taunt clip")
	assert_almost_eq(anim.length, 1.1, 0.05, "about 1.1 s")
	assert_eq(anim.loop_mode, Animation.LOOP_NONE, "it plays once")
	var named := EnemyNamedPoses.named(&"taunt", PlaceholderPoses.guard())
	var keys: Array = named["keys"]
	for i: int in keys.size():
		var key: PlaceholderAnims.PoseKey = keys[i]
		Checks.check_joint_limits(self, key.pose, "taunt at %.2f s" % key.time)
		# A hand above its own shoulder would read as a cocked fist: every gesture key keeps both
		# hands below the shoulders (the first and last keys are the guard itself, fists at the chin).
		if i == 0 or i == keys.size() - 1:
			continue
		var globals := PlaceholderBody.pose_globals(key.pose, Vector3.ZERO, 1.0)
		for side: String in ["Left", "Right"]:
			var hand: float = globals[StringName(side + "Hand")].origin.y
			var shoulder: float = globals[StringName(side + "UpperArm")].origin.y
			assert_lt(hand, shoulder - TAUNT_HAND_BELOW_SHOULDER_M, "taunt at %.2f s: the %s hand stays below the shoulder" % [key.time, side.to_lower()])
