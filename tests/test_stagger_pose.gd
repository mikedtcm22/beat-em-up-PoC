extends GutTest
## The sideways stagger animations (PlaceholderPoses.stagger_right_a/b, stagger_left mirrors
## them) as drawn, without the ragdoll: the trunk rocks over and both arms fling out, but
## the far arm stays bent near the guard, not thrown out straight (review gap-04: the hook
## stagger's far arm swung out about 70 degrees with the elbow barely bent, and the partial
## ragdoll's arm influence cannot calm a swing that is in the animation); and not forward at
## the attacker's lens either (review r3look-03; the lens itself: tests/test_ragdoll.gd).

const FRAME := 1.0 / 60.0
## How far (m, from the trunk's axis) the far fist may go: the arm thrown out straight
## about 70 degrees reached 0.88 m; the guard holds the fist 0.26 to 0.41 m out (by stance).
const MAX_FAR_FIST_M := 0.66
## The far fist must still go out this much (m) past the guard: a fling that shows.
const MIN_FLING_M := 0.15
## The far elbow's inner angle (degrees; 180 is straight) is at most this at the widest
## swing: bent at a right angle or tighter. It was 128 degrees (a barely bent arm).
const MAX_FAR_ELBOW_DEG := 100.0
## While the arm flings (from its first key at 0.12 s to its second at 0.34 s) the far fist
## stays this far (m) in front of the hips at most: up and out beside the shoulder, not
## forward at the attacker's lens (the forearm folded forward put the fist 0.44 m in front,
## and the partial ragdoll flung it to 0.20 m from the lens; the guard itself holds it
## 0.26 m forward).
const MAX_FAR_FIST_FORWARD_M := 0.2
## The trunk leans at least this far (degrees) off upright at its furthest: the rock.
const MIN_TRUNK_LEAN_DEG := 8.0


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


## The trunk's axis, hips to the top of the head (a unit vector, rig-local).
func _trunk(rig: HumanoidRig) -> Vector3:
	return (_local(rig, &"HeadTopPoint") - _local(rig, &"Hips")).normalized()


## How far `side`'s ("Left" or "Right") fist is from the trunk's axis, as drawn.
func _fist_from_trunk(rig: HumanoidRig, side: String) -> float:
	var axis := _trunk(rig)
	var rel := _local(rig, StringName(side + "FistPoint")) - _local(rig, &"Hips")
	return (rel - axis * rel.dot(axis)).length()


## The inner angle of `side`'s elbow in degrees (180 is a straight arm), as drawn.
func _elbow_deg(rig: HumanoidRig, side: String) -> float:
	var shoulder := _local(rig, StringName(side + "UpperArm"))
	var elbow := _local(rig, StringName(side + "ElbowPoint"))
	var fist := _local(rig, StringName(side + "FistPoint"))
	return rad_to_deg((shoulder - elbow).angle_to(fist - elbow))


## Play `anim` frame by frame to its end: the widest the `side` arm swings (fist from the
## trunk, and the elbow's angle then) and the furthest the trunk leans off upright.
func _stagger(stance: StringName, anim: StringName, side: String) -> Dictionary:
	var rig := _rig(stance)
	rig.play(&"idle", 0.0)
	rig.advance(0.5)
	var guard := _fist_from_trunk(rig, side)
	rig.play(anim, 0.0)
	var out := {guard = guard, fist = 0.0, elbow = 0.0, lean = 0.0, forward = -INF, frames = 0}
	for i in roundi(rig.anim_player.get_animation(anim).length / FRAME):
		rig.advance(FRAME)
		if i >= 7 and i <= 20:
			# Rig-local: forward is -Z.
			out.forward = maxf(out.forward, -(_local(rig, StringName(side + "FistPoint")) - _local(rig, &"Hips")).z)
		var fist := _fist_from_trunk(rig, side)
		if fist > out.fist:
			out.fist = fist
			out.elbow = _elbow_deg(rig, side)
		out.lean = maxf(out.lean, rad_to_deg(_trunk(rig).angle_to(Vector3.UP)))
		out.frames += 1
	return out


func test_the_far_arm_of_a_sideways_stagger_swings_out_bent_not_straight() -> void:
	# stagger_right throws the left arm out the far side; stagger_left mirrors it (the right).
	for stance: StringName in [PlaceholderPoses.STANCE_BOXER, PlaceholderPoses.STANCE_RELAXED]:
		for case: Array in [[&"stagger_right", "Left"], [&"stagger_left", "Right"]]:
			var anim: StringName = case[0]
			var side: String = case[1]
			var m := _stagger(stance, anim, side)
			var tag := "%s (%s)" % [anim, stance]
			gut.p("%s: far fist %.2f m from the trunk at its widest (guard %.2f m), elbow %.0f degrees there, %.2f m forward at most while it flings, trunk leans %.0f degrees" % [
				tag, m.fist, m.guard, m.elbow, m.forward, m.lean])
			assert_gt(m.frames, 20, "%s plays" % tag)
			assert_lt(m.fist, MAX_FAR_FIST_M, "%s: the far fist stays near the body, not flung out straight" % tag)
			assert_gt(m.fist, m.guard + MIN_FLING_M, "%s: and still flings out past the guard" % tag)
			assert_lt(m.elbow, MAX_FAR_ELBOW_DEG, "%s: the far elbow stays bent at its widest" % tag)
			assert_lt(m.forward, MAX_FAR_FIST_FORWARD_M, "%s: and the flung fist goes up and out, not forward at the attacker" % tag)
			assert_gt(m.lean, MIN_TRUNK_LEAN_DEG, "%s: the trunk still rocks over" % tag)
