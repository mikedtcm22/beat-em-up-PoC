extends GutTest
## The backward stagger (PlaceholderPoses.stagger_back_a/b) as drawn, without the ragdoll. M4, the lead's call 24 (final review
## finding final-v2-01): the M3 pose threw both arms out straight (upper arms about 75 degrees off the body, elbows barely bent),
## which on the skinned Punk, whose rig is bound in an A-pose, reads as the rig showing its bind pose, a T, for about 0.4 s after
## every third knee, on a grab release and in a long fight. It is re-posed the way stagger_right was in M3 (test_stagger_pose.gd):
## the guard broken open, the upper arms out about 40 degrees then 28, the elbows folded to 90-110 degrees, the forearms raised
## and forward, the trunk still thrown back. These tests hold that, and the M3 pose is the twin that fails them.

const FRAME := 1.0 / 60.0
## An upper arm is at most this far (degrees) from hanging at any frame of the stagger, measured on the drawn trunk, which is thrown
## back 24 degrees at key a: the M3 pose was 77 at its widest.
const MAX_UPPER_ARM_DEG := 65.0
## An elbow's inner angle (degrees; 180 is straight) is at most this in the keys, and at any frame where the upper arm is more than
## WIDE_ARM_DEG out: the M3 pose's was 140 at its straightest key, 36-40 degrees of bend.
const MAX_ELBOW_DEG := 125.0
const WIDE_ARM_DEG := 45.0
## A fist stays this far (m) in front of the hips at most (the lens is 1 m away; the boxer's guard holds it 0.26 m forward, the
## relaxed stance's lead hand 0.31 m): no fist swung at the attacker. The new pose reaches 0.41.
const MAX_FIST_FORWARD_M := 0.45
## A fist stays this far (m) from the trunk's axis at most (the M3 pose reached about 0.75 m, the new one 0.64).
const MAX_FIST_FROM_TRUNK_M := 0.68
## The arms still open: at its widest a fist is at least this far (m) beyond where the guard holds it.
const MIN_OPENING_M := 0.1
## The trunk is still thrown back this far (degrees) at its furthest: the stagger reads as a body knocked back.
const MIN_TRUNK_LEAN_DEG := 15.0
## The M3 key poses' arms (side "Left"; the right arm mirrors it): upper arm Euler (x, y, z) and elbow flexion, at key a and key b.
const M3_ARMS := {
	"a": {&"LeftUpperArm": Vector3(40.0, 0.0, -60.0), &"LeftLowerArm": Vector3(40.0, 0.0, 0.0),
			&"RightUpperArm": Vector3(30.0, 0.0, 66.0), &"RightLowerArm": Vector3(36.0, 0.0, 0.0)},
	"b": {&"LeftUpperArm": Vector3(30.0, 0.0, -36.0), &"LeftLowerArm": Vector3(40.0, 0.0, 0.0),
			&"RightUpperArm": Vector3(24.0, 0.0, 40.0), &"RightLowerArm": Vector3(36.0, 0.0, 0.0)},
}


func _rig(stance: StringName) -> HumanoidRig:
	var rig := HumanoidRig.new()
	rig.height = 1.8
	rig.stance = stance
	add_child_autofree(rig)
	rig.build()
	return rig


## Rig-local position of a rig point or bone.
func _local(rig: HumanoidRig, point: StringName) -> Vector3:
	return rig.global_transform.affine_inverse() * rig.get_point_position(point)


## How far `side`'s upper arm is from hanging, in degrees, given its shoulder and elbow.
func _upper_deg(shoulder: Vector3, elbow: Vector3) -> float:
	return rad_to_deg((elbow - shoulder).angle_to(Vector3.DOWN))


## The inner angle of an elbow in degrees (180 is a straight arm).
func _inner_deg(shoulder: Vector3, elbow: Vector3, wrist: Vector3) -> float:
	return rad_to_deg((shoulder - elbow).angle_to(wrist - elbow))


## The upper arm angle, the elbow's inner angle and the wrist's forward distance of `side`'s arm in the pose `pose` (the table's
## FK, hips at rest): `{upper, inner, forward}`.
func _key_arm(pose: Dictionary[StringName, Vector3], side: String) -> Dictionary:
	var globals := PlaceholderBody.pose_globals(pose, Vector3.ZERO, 1.0)
	var shoulder: Vector3 = globals[StringName(side + "UpperArm")].origin
	var elbow: Vector3 = globals[StringName(side + "LowerArm")].origin
	var wrist: Vector3 = globals[StringName(side + "Hand")].origin
	return {upper = _upper_deg(shoulder, elbow), inner = _inner_deg(shoulder, elbow, wrist), forward = -(wrist.z - (globals[&"Hips"] as Transform3D).origin.z)}


## What of the rules above `pose`'s two arms break, as text (empty: held).
func _key_problems(label: String, pose: Dictionary[StringName, Vector3]) -> PackedStringArray:
	var out := PackedStringArray()
	for side: String in ["Left", "Right"]:
		var arm := _key_arm(pose, side)
		if arm.upper > MAX_UPPER_ARM_DEG:
			out.append("%s %s: the upper arm is %.0f degrees off the body" % [label, side, arm.upper])
		if arm.inner > MAX_ELBOW_DEG:
			out.append("%s %s: the elbow is open to %.0f degrees" % [label, side, arm.inner])
	return out


func test_the_keys_break_the_guard_open_with_bent_elbows_not_a_t() -> void:
	var guard := PlaceholderPoses.guard()
	for case: Array in [["a", PlaceholderPoses.stagger_back_a(guard)], ["b", PlaceholderPoses.stagger_back_b(guard)]]:
		var pose: Dictionary[StringName, Vector3] = case[1]
		for side: String in ["Left", "Right"]:
			var arm := _key_arm(pose, side)
			gut.p("stagger_back key %s %s: upper arm %.0f degrees off the body, elbow inner angle %.0f, wrist %.2f m forward of the hips" % [case[0], side, arm.upper, arm.inner, arm.forward])
			assert_gt(arm.upper, 20.0, "key %s %s: the arm still swings out" % [case[0], side])
			assert_gt(arm.inner, 60.0, "key %s %s: and the elbow is not folded shut" % [case[0], side])
			assert_lt(arm.forward, MAX_FIST_FORWARD_M, "key %s %s: the hand stays near the guard's reach, not at the lens" % [case[0], side])
		assert_eq(_key_problems(case[0], pose), PackedStringArray(), "key %s: no straight, wide arm" % case[0])


func test_the_m3_pose_is_the_twin_that_fails_the_rules() -> void:
	# The M3 keys' arms on the same trunk and legs: both keys break both rules on both arms.
	for key: String in ["a", "b"]:
		var pose: Dictionary[StringName, Vector3] = PlaceholderPoses.stagger_back_a(PlaceholderPoses.guard()) if key == "a" else PlaceholderPoses.stagger_back_b(PlaceholderPoses.guard())
		for bone: StringName in M3_ARMS[key]:
			pose[bone] = M3_ARMS[key][bone]
		var problems := _key_problems(key, pose)
		gut.p("the M3 key %s breaks: %s" % [key, problems])
		if key == "a":
			assert_gte(problems.size(), 4, "M3 key a: the upper arm is too wide and the elbow too open on both arms (%s)" % [problems])
		else:
			assert_gte(problems.size(), 2, "M3 key b: the elbow is too open on both arms (%s)" % [problems])


## Play `anim` frame by frame to its end on a rig in `stance`: the worst of each rule over the clip, for `side`'s arm.
func _clip_arm(stance: StringName, side: String) -> Dictionary:
	var rig := _rig(stance)
	rig.play(&"idle", 0.0)
	rig.advance(0.5)
	var hips := _local(rig, &"Hips")
	var axis := (_local(rig, &"HeadTopPoint") - hips).normalized()
	var guard_rel := _local(rig, StringName(side + "FistPoint")) - hips
	var guard_out := (guard_rel - axis * guard_rel.dot(axis)).length()
	rig.play(&"stagger_back", 0.0)
	var out := {upper = 0.0, inner_wide = 0.0, forward = -INF, out = 0.0, lean = 0.0, guard_out = guard_out, guard_forward = -guard_rel.z, frames = 0}
	for i in roundi(rig.anim_player.get_animation(&"stagger_back").length / FRAME):
		rig.advance(FRAME)
		var shoulder := _local(rig, StringName(side + "UpperArm"))
		var elbow := _local(rig, StringName(side + "ElbowPoint"))
		var fist := _local(rig, StringName(side + "FistPoint"))
		var upper := _upper_deg(shoulder, elbow)
		out.upper = maxf(out.upper, upper)
		if upper > WIDE_ARM_DEG:
			out.inner_wide = maxf(out.inner_wide, _inner_deg(shoulder, elbow, fist))
		out.forward = maxf(out.forward, -(fist - _local(rig, &"Hips")).z)
		var rel := fist - _local(rig, &"Hips")
		var trunk := (_local(rig, &"HeadTopPoint") - _local(rig, &"Hips")).normalized()
		out.out = maxf(out.out, (rel - trunk * rel.dot(trunk)).length())
		out.lean = maxf(out.lean, rad_to_deg(trunk.angle_to(Vector3.UP)))
		out.frames += 1
	return out


func test_no_frame_of_the_clip_has_a_straight_wide_arm_and_the_stagger_still_reads_as_a_knock_back() -> void:
	for stance: StringName in [PlaceholderPoses.STANCE_BOXER, PlaceholderPoses.STANCE_RELAXED]:
		for side: String in ["Left", "Right"]:
			var m := _clip_arm(stance, side)
			var tag := "stagger_back (%s) %s" % [stance, side]
			gut.p("%s: upper arm at most %.0f degrees off the body, elbow inner angle at most %.0f while it is wide, fist at most %.2f m in front of the hips (guard %.2f) and %.2f m from the trunk (guard %.2f), trunk leans %.0f degrees" % [
				tag, m.upper, m.inner_wide, m.forward, m.guard_forward, m.out, m.guard_out, m.lean])
			assert_gt(m.frames, 30, "%s plays" % tag)
			assert_lt(m.upper, MAX_UPPER_ARM_DEG + 5.0, "%s: no frame throws the upper arm wide (the points are the rig's, a little off the bones)" % tag)
			assert_lt(m.inner_wide, MAX_ELBOW_DEG + 10.0, "%s: no frame has a wide arm with the elbow near straight" % tag)
			assert_lt(m.forward, MAX_FIST_FORWARD_M, "%s: the fist stays out of the lens" % tag)
			assert_lt(m.out, MAX_FIST_FROM_TRUNK_M, "%s: the fist stays within reach of the trunk" % tag)
			assert_gt(m.out, m.guard_out + MIN_OPENING_M, "%s: the guard still breaks open" % tag)
			assert_gt(m.lean, MIN_TRUNK_LEAN_DEG, "%s: the trunk is still thrown back" % tag)
