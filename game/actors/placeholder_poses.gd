class_name PlaceholderPoses
extends RefCounted
## Placeholder pose library (Milestone 1): every pose the procedural animations key, as
## dictionaries of bone name -> Euler degrees (YXZ). See PlaceholderBody for what each
## axis means on a bone. Bones a pose leaves out are at rest rotation.
##
## The special key HIPS_POS holds a Hips position offset from rest (meters at
## PlaceholderBody.REF_HEIGHT), not an angle. A pose that has it keeps that hip height (air
## poses, lying down, getting up). A pose without it is PLANTED: PlaceholderAnims raises or
## lowers the hips so the lowest sole point touches y = 0, then adds HIPS_NUDGE if the
## pose has it (a small shift of a planted pose, such as hips pushed back by a gut punch).
##
## Real animation replaces all of this in Milestone 4; the numbers here are art data.

## Pose key for the Hips position offset (meters at reference height), see class docs.
const HIPS_POS := &"HipsPos"
## Pose key for a shift added to a planted pose's hips (meters at reference height).
const HIPS_NUDGE := &"HipsNudge"

## Hip offset that lays the body flat with the back (or front) on the floor.
const LYING_HIPS := Vector3(0.0, -0.84, 0.0)


## Key poses of one move (see PlaceholderAnims.build_move for when each is keyed).
class MovePoses:
	## Start pose; also the end pose unless `finish` is set.
	var guard: Dictionary[StringName, Vector3] = {}
	var windup: Dictionary[StringName, Vector3] = {}
	## Keyed at windup_at x startup.
	var windup_at: float = 0.5
	## Reached exactly at the first active frame and held through the active frames.
	var strike: Dictionary[StringName, Vector3] = {}
	## Optional pose at the end of the active frames (spins keep turning); empty = strike.
	var strike_end: Dictionary[StringName, Vector3] = {}
	## Optional follow-through keyed at follow_at x recovery; empty = none.
	var follow: Dictionary[StringName, Vector3] = {}
	var follow_at: float = 0.35
	## Optional end pose; empty = guard (360-degree spins end at a full turn).
	var finish: Dictionary[StringName, Vector3] = {}

	## Left/right mirror image. With `keep_legs` only the upper body is mirrored and the
	## legs keep their stance (the body flurry alternates fists without switching feet).
	func mirrored(keep_legs: bool = false) -> MovePoses:
		var m := MovePoses.new()
		m.guard = _mirror_pose(guard, keep_legs)
		m.windup = _mirror_pose(windup, keep_legs)
		m.windup_at = windup_at
		m.strike = _mirror_pose(strike, keep_legs)
		m.strike_end = _mirror_pose(strike_end, keep_legs)
		m.follow = _mirror_pose(follow, keep_legs)
		m.follow_at = follow_at
		m.finish = _mirror_pose(finish, keep_legs)
		return m

	func _mirror_pose(pose: Dictionary[StringName, Vector3], keep_legs: bool) -> Dictionary[StringName, Vector3]:
		var out := PlaceholderPoses.mirror(pose)
		if keep_legs:
			for bone: StringName in PlaceholderPoses.LEG_BONES:
				out.erase(bone)
				if pose.has(bone):
					out[bone] = pose[bone]
		return out


static func _mp(guard_pose: Dictionary[StringName, Vector3], windup_pose: Dictionary[StringName, Vector3],
		strike_pose: Dictionary[StringName, Vector3]) -> MovePoses:
	var m := MovePoses.new()
	m.guard = guard_pose
	m.windup = windup_pose
	m.strike = strike_pose
	return m


# --- Helpers ---------------------------------------------------------------------------


## `base` with every entry of `over` replacing it.
static func merge(base: Dictionary[StringName, Vector3],
		over: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return base.merged(over, true)


## `base` with the angles (and hip offset) of `delta` added.
static func add(base: Dictionary[StringName, Vector3],
		delta: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	var out: Dictionary[StringName, Vector3] = base.duplicate()
	for key: StringName in delta:
		out[key] = out.get(key, Vector3.ZERO) + delta[key]
	return out


## Left/right mirror image: swaps Left*/Right* bones and negates yaw and roll.
static func mirror(pose: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	var out: Dictionary[StringName, Vector3] = {}
	for key: StringName in pose:
		var v: Vector3 = pose[key]
		if not is_bone_key(key):
			out[key] = Vector3(-v.x, v.y, v.z)
			continue
		var bone := String(key)
		if bone.begins_with("Left"):
			bone = "Right" + bone.substr(4)
		elif bone.begins_with("Right"):
			bone = "Left" + bone.substr(5)
		out[StringName(bone)] = Vector3(v.x, -v.y, -v.z)
	return out


## False for the special hip keys (HIPS_POS, HIPS_NUDGE), true for bone names.
static func is_bone_key(key: StringName) -> bool:
	return key != HIPS_POS and key != HIPS_NUDGE


## Only the entries of `pose` whose bone is in `bones`.
static func only(pose: Dictionary[StringName, Vector3], bones: Array[StringName]) -> Dictionary[StringName, Vector3]:
	var out: Dictionary[StringName, Vector3] = {}
	for key: StringName in pose:
		if bones.has(key):
			out[key] = pose[key]
	return out


const LEG_BONES: Array[StringName] = [
	&"LeftUpperLeg", &"LeftLowerLeg", &"LeftFoot", &"LeftToes",
	&"RightUpperLeg", &"RightLowerLeg", &"RightFoot", &"RightToes",
]


# --- Stances ---------------------------------------------------------------------------


## Fighting stance: left foot forward, knees soft, fists up in front of the chin (far
## enough forward that they show at the bottom corners of the first-person view).
static func guard() -> Dictionary[StringName, Vector3]:
	return {
		&"Spine": Vector3(-3.0, 0.0, 0.0),
		&"Chest": Vector3(-3.0, 0.0, 0.0),
		&"Neck": Vector3(4.0, 0.0, 0.0),
		&"Head": Vector3(2.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(57.0, -16.0, -4.0),
		&"LeftLowerArm": Vector3(102.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(53.0, 18.0, 7.0),
		&"RightLowerArm": Vector3(109.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(16.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-24.0, 0.0, 0.0),
		&"LeftFoot": Vector3(8.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-6.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-16.0, 0.0, 0.0),
		&"RightFoot": Vector3(22.0, 0.0, -5.0),
	}


## Guard holding a pipe: right hand up by the shoulder, the weapon resting back over it.
static func weapon_guard() -> Dictionary[StringName, Vector3]:
	return merge(guard(), {
		&"RightUpperArm": Vector3(30.0, 0.0, 22.0),
		&"RightLowerArm": Vector3(100.0, 0.0, 0.0),
		&"RightHand": Vector3(-10.0, 0.0, 0.0),
	})


## Clinch: both hands forward on a held victim at HoldPoint.
static func hold() -> Dictionary[StringName, Vector3]:
	return merge(guard(), {
		&"Spine": Vector3(-6.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(62.0, -14.0, -12.0),
		&"LeftLowerArm": Vector3(62.0, 0.0, 0.0),
		&"LeftHand": Vector3(10.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(62.0, 14.0, 12.0),
		&"RightLowerArm": Vector3(62.0, 0.0, 0.0),
		&"RightHand": Vector3(10.0, 0.0, 0.0),
	})


## Being held: hips pulled back, hunched, arms hanging, head forced down. Authored for a
## victim whose origin is pinned at the holder's HoldPoint (on the floor below it), facing
## the holder: the head then sits about 0.44 m in front of the holder at y 1.5, at the
## bottom edge of the holder's first-person view, and the holder's fists rest on the back
## of the victim's neck and shoulders.
static func held() -> Dictionary[StringName, Vector3]:
	return {
		HIPS_NUDGE: Vector3(0.0, 0.0, 0.14),
		&"Spine": Vector3(-2.0, 0.0, 0.0),
		&"Chest": Vector3(-10.0, 0.0, 0.0),
		&"UpperChest": Vector3(-14.0, 0.0, 0.0),
		&"Neck": Vector3(-28.0, 0.0, 0.0),
		&"Head": Vector3(-28.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(18.0, 0.0, -10.0),
		&"LeftLowerArm": Vector3(30.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(14.0, 0.0, 12.0),
		&"RightLowerArm": Vector3(34.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(14.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-26.0, 0.0, 0.0),
		&"LeftFoot": Vector3(12.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(8.0, 0.0, 4.0),
		&"RightLowerLeg": Vector3(-22.0, 0.0, 0.0),
		&"RightFoot": Vector3(14.0, 0.0, -4.0),
	}


## Lying on the back, head toward +z (fell backward), hips over the rig origin.
static func downed_back() -> Dictionary[StringName, Vector3]:
	return {
		HIPS_POS: LYING_HIPS,
		&"Hips": Vector3(90.0, 0.0, 0.0),
		&"Spine": Vector3(-2.0, 0.0, 0.0),
		&"Neck": Vector3(-14.0, 0.0, 0.0),
		&"Head": Vector3(-8.0, 20.0, 0.0),
		&"LeftUpperArm": Vector3(-10.0, 0.0, -55.0),
		&"LeftLowerArm": Vector3(30.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(-14.0, 0.0, 45.0),
		&"RightLowerArm": Vector3(40.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(6.0, 0.0, -8.0),
		&"LeftLowerLeg": Vector3(-12.0, 0.0, 0.0),
		&"LeftFoot": Vector3(-24.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(26.0, 0.0, 10.0),
		&"RightLowerLeg": Vector3(-46.0, 0.0, 0.0),
		&"RightFoot": Vector3(-6.0, 0.0, 0.0),
	}


## Lying face down, head toward -z (fell forward), hips over the rig origin.
static func downed_front() -> Dictionary[StringName, Vector3]:
	return {
		HIPS_POS: LYING_HIPS,
		&"Hips": Vector3(-90.0, 0.0, 0.0),
		&"Spine": Vector3(2.0, 0.0, 0.0),
		&"Neck": Vector3(14.0, 0.0, 0.0),
		&"Head": Vector3(10.0, -25.0, 0.0),
		&"LeftUpperArm": Vector3(150.0, 0.0, -20.0),
		&"LeftLowerArm": Vector3(40.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(20.0, 0.0, 30.0),
		&"RightLowerArm": Vector3(20.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(-4.0, 0.0, -8.0),
		&"LeftLowerLeg": Vector3(-34.0, 0.0, 0.0),
		&"LeftFoot": Vector3(-50.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(-2.0, 0.0, 8.0),
		&"RightLowerLeg": Vector3(-8.0, 0.0, 0.0),
		&"RightFoot": Vector3(-70.0, 0.0, 0.0),
	}


## Limp KO versions of the lying poses: arms flung out, head lolled.
static func ko_back() -> Dictionary[StringName, Vector3]:
	return merge(downed_back(), {
		&"Head": Vector3(-14.0, 50.0, 0.0),
		&"LeftUpperArm": Vector3(-30.0, 0.0, -95.0),
		&"LeftLowerArm": Vector3(10.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(-20.0, 0.0, 70.0),
		&"RightLowerArm": Vector3(15.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(2.0, 0.0, -14.0),
		&"LeftLowerLeg": Vector3(-6.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(4.0, 0.0, 16.0),
		&"RightLowerLeg": Vector3(-10.0, 0.0, 0.0),
		&"RightFoot": Vector3(-20.0, 0.0, 0.0),
	})


static func ko_front() -> Dictionary[StringName, Vector3]:
	return merge(downed_front(), {
		&"Head": Vector3(14.0, -60.0, 0.0),
		&"LeftUpperArm": Vector3(10.0, 0.0, -40.0),
		&"LeftLowerArm": Vector3(10.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(14.0, 0.0, 34.0),
		&"RightLowerArm": Vector3(10.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(-2.0, 0.0, -10.0),
		&"LeftLowerLeg": Vector3(-6.0, 0.0, 0.0),
		&"LeftFoot": Vector3(-70.0, 0.0, 0.0),
	})


# --- Locomotion ------------------------------------------------------------------------


## Walk contact pose: left foot reaching forward, right foot pushing off behind.
static func walk_contact() -> Dictionary[StringName, Vector3]:
	return merge(guard(), {
		&"Hips": Vector3(0.0, 4.0, 0.0),
		&"LeftUpperLeg": Vector3(24.0, 0.0, -3.0),
		&"LeftLowerLeg": Vector3(-12.0, 0.0, 0.0),
		&"LeftFoot": Vector3(-6.0, 0.0, 3.0),
		&"RightUpperLeg": Vector3(-18.0, 0.0, 3.0),
		&"RightLowerLeg": Vector3(-20.0, 0.0, 0.0),
		&"RightFoot": Vector3(30.0, 0.0, -3.0),
		&"RightToes": Vector3(10.0, 0.0, 0.0),
	})


## Walk passing pose: left leg planted under the body, right knee swinging through.
static func walk_pass() -> Dictionary[StringName, Vector3]:
	return merge(guard(), {
		&"LeftUpperLeg": Vector3(4.0, 0.0, -3.0),
		&"LeftLowerLeg": Vector3(-10.0, 0.0, 0.0),
		&"LeftFoot": Vector3(6.0, 0.0, 3.0),
		&"RightUpperLeg": Vector3(30.0, 0.0, 3.0),
		&"RightLowerLeg": Vector3(-62.0, 0.0, 0.0),
		&"RightFoot": Vector3(20.0, 0.0, -3.0),
	})


## Side-step: feet apart (lead foot out) for walk_right; mirror for walk_left.
static func step_wide() -> Dictionary[StringName, Vector3]:
	return merge(guard(), {
		&"LeftUpperLeg": Vector3(8.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-14.0, 0.0, 0.0),
		&"LeftFoot": Vector3(6.0, 0.0, 6.0),
		&"RightUpperLeg": Vector3(10.0, 0.0, 18.0),
		&"RightLowerLeg": Vector3(-16.0, 0.0, 0.0),
		&"RightFoot": Vector3(6.0, 0.0, -18.0),
	})


## Side-step: trailing foot lifted and closing in.
static func step_close() -> Dictionary[StringName, Vector3]:
	return merge(guard(), {
		&"LeftUpperLeg": Vector3(20.0, 0.0, 4.0),
		&"LeftLowerLeg": Vector3(-40.0, 0.0, 0.0),
		&"LeftFoot": Vector3(18.0, 0.0, -4.0),
		&"RightUpperLeg": Vector3(8.0, 0.0, 2.0),
		&"RightLowerLeg": Vector3(-18.0, 0.0, 0.0),
		&"RightFoot": Vector3(10.0, 0.0, -2.0),
	})


# --- Air ------------------------------------------------------------------------------


static func crouch() -> Dictionary[StringName, Vector3]:
	return merge(guard(), {
		&"Spine": Vector3(-12.0, 0.0, 0.0),
		&"Neck": Vector3(10.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(55.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-90.0, 0.0, 0.0),
		&"LeftFoot": Vector3(35.0, 0.0, 6.0),
		&"RightUpperLeg": Vector3(40.0, 0.0, 6.0),
		&"RightLowerLeg": Vector3(-82.0, 0.0, 0.0),
		&"RightFoot": Vector3(42.0, 0.0, -6.0),
	})


static func jump_takeoff() -> Dictionary[StringName, Vector3]:
	return merge(guard(), {
		HIPS_POS: Vector3(0.0, 0.02, 0.0),
		&"Spine": Vector3(2.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(70.0, 0.0, -20.0),
		&"RightUpperArm": Vector3(64.0, 0.0, 22.0),
		&"LeftUpperLeg": Vector3(4.0, 0.0, -3.0),
		&"LeftLowerLeg": Vector3(-4.0, 0.0, 0.0),
		&"LeftFoot": Vector3(-30.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(-4.0, 0.0, 3.0),
		&"RightLowerLeg": Vector3(-8.0, 0.0, 0.0),
		&"RightFoot": Vector3(-30.0, 0.0, 0.0),
	})


static func jump_tuck() -> Dictionary[StringName, Vector3]:
	return merge(guard(), {
		HIPS_POS: Vector3(0.0, 0.0, 0.0),
		&"Spine": Vector3(-8.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(70.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-100.0, 0.0, 0.0),
		&"LeftFoot": Vector3(-10.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(45.0, 0.0, 6.0),
		&"RightLowerLeg": Vector3(-95.0, 0.0, 0.0),
		&"RightFoot": Vector3(-15.0, 0.0, 0.0),
	})


static func fall_pose() -> Dictionary[StringName, Vector3]:
	return merge(guard(), {
		HIPS_POS: Vector3(0.0, 0.0, 0.0),
		&"Spine": Vector3(2.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(50.0, 0.0, -40.0),
		&"LeftLowerArm": Vector3(70.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(44.0, 0.0, 42.0),
		&"RightLowerArm": Vector3(70.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(26.0, 0.0, -5.0),
		&"LeftLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"LeftFoot": Vector3(-10.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(6.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-24.0, 0.0, 0.0),
		&"RightFoot": Vector3(-6.0, 0.0, 0.0),
	})


# --- Dodges (right / back / forward; dodge_left mirrors dodge_right) --------------------


static func dodge_right() -> Dictionary[StringName, Vector3]:
	return merge(crouch(), {
		&"Hips": Vector3(0.0, 0.0, -6.0),
		&"Spine": Vector3(-10.0, 0.0, -14.0),
		&"Chest": Vector3(-4.0, 0.0, -8.0),
		&"Neck": Vector3(8.0, 0.0, 14.0),
		&"Head": Vector3(0.0, 0.0, 8.0),
		&"LeftUpperLeg": Vector3(30.0, 0.0, -14.0),
		&"LeftLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"LeftFoot": Vector3(0.0, 0.0, 20.0),
		&"RightUpperLeg": Vector3(50.0, 0.0, 22.0),
		&"RightLowerLeg": Vector3(-90.0, 0.0, 0.0),
		&"RightFoot": Vector3(40.0, 0.0, -16.0),
	})


static func dodge_back() -> Dictionary[StringName, Vector3]:
	return merge(crouch(), {
		&"Spine": Vector3(6.0, 0.0, 0.0),
		&"Chest": Vector3(6.0, 0.0, 0.0),
		&"Neck": Vector3(-6.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(30.0, 0.0, -5.0),
		&"LeftLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"LeftFoot": Vector3(0.0, 0.0, 5.0),
		&"RightUpperLeg": Vector3(20.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-80.0, 0.0, 0.0),
		&"RightFoot": Vector3(60.0, 0.0, -5.0),
	})


static func dodge_forward() -> Dictionary[StringName, Vector3]:
	return merge(crouch(), {
		&"Spine": Vector3(-24.0, 0.0, 0.0),
		&"Chest": Vector3(-10.0, 0.0, 0.0),
		&"Neck": Vector3(22.0, 0.0, 0.0),
		&"Head": Vector3(10.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(70.0, 0.0, -5.0),
		&"LeftLowerLeg": Vector3(-80.0, 0.0, 0.0),
		&"LeftFoot": Vector3(10.0, 0.0, 5.0),
		&"RightUpperLeg": Vector3(0.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-60.0, 0.0, 0.0),
		&"RightFoot": Vector3(60.0, 0.0, -5.0),
	})


# --- Grab and pickup ------------------------------------------------------------------


static func grab_reach() -> Dictionary[StringName, Vector3]:
	return merge(guard(), {
		&"Spine": Vector3(-12.0, 0.0, 0.0),
		&"Chest": Vector3(-4.0, 0.0, 0.0),
		&"Neck": Vector3(12.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(84.0, -12.0, -10.0),
		&"LeftLowerArm": Vector3(20.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(84.0, 12.0, 10.0),
		&"RightLowerArm": Vector3(20.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(28.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"LeftFoot": Vector3(2.0, 0.0, 4.0),
	})


static func pickup_reach() -> Dictionary[StringName, Vector3]:
	return merge(crouch(), {
		&"Spine": Vector3(-30.0, 0.0, 0.0),
		&"Chest": Vector3(-14.0, 0.0, 0.0),
		&"Neck": Vector3(26.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(60.0, 0.0, 10.0),
		&"RightLowerArm": Vector3(10.0, 0.0, 0.0),
	})


# --- Hit reactions ---------------------------------------------------------------------


## Struck in the face: head and shoulders snap back.
static func flinch_head_front() -> Dictionary[StringName, Vector3]:
	return add(guard(), {
		&"Spine": Vector3(6.0, 0.0, 0.0),
		&"Chest": Vector3(6.0, 0.0, 0.0),
		&"Neck": Vector3(16.0, 0.0, 0.0),
		&"Head": Vector3(18.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(-14.0, 0.0, -8.0),
		&"RightUpperArm": Vector3(-14.0, 0.0, 8.0),
	})


## Head snaps sideways toward the victim's own left (`to_left`, the blow came from its
## right) or right.
static func flinch_head_side(to_left: bool) -> Dictionary[StringName, Vector3]:
	var delta: Dictionary[StringName, Vector3] = {
		&"Chest": Vector3(0.0, 8.0, 6.0),
		&"Neck": Vector3(4.0, 20.0, 14.0),
		&"Head": Vector3(4.0, 24.0, 14.0),
		&"LeftUpperArm": Vector3(-10.0, 0.0, -14.0),
		&"RightUpperArm": Vector3(-6.0, 0.0, 8.0),
	}
	return add(guard(), delta if to_left else mirror(delta))


static func flinch_gut() -> Dictionary[StringName, Vector3]:
	return add(guard(), {
		HIPS_NUDGE: Vector3(0.0, 0.0, 0.04),
		&"Spine": Vector3(-18.0, 0.0, 0.0),
		&"Chest": Vector3(-14.0, 0.0, 0.0),
		&"Neck": Vector3(-6.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(-10.0, 0.0, 6.0),
		&"LeftLowerArm": Vector3(10.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(-10.0, 0.0, -6.0),
		&"RightLowerArm": Vector3(10.0, 0.0, 0.0),
	})


static func flinch_legs() -> Dictionary[StringName, Vector3]:
	return merge(add(guard(), {
		&"Spine": Vector3(-6.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(-6.0, 0.0, -14.0),
		&"RightUpperArm": Vector3(-6.0, 0.0, 14.0),
	}), {
		&"LeftUpperLeg": Vector3(40.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-64.0, 0.0, 0.0),
		&"LeftFoot": Vector3(24.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(14.0, 0.0, 6.0),
		&"RightLowerLeg": Vector3(-56.0, 0.0, 0.0),
		&"RightFoot": Vector3(42.0, 0.0, -6.0),
	})


## Stumbling backward: torso thrown back, arms out, one foot stepping back.
static func stagger_back_a() -> Dictionary[StringName, Vector3]:
	return merge(guard(), {
		&"Spine": Vector3(14.0, 0.0, 0.0),
		&"Chest": Vector3(10.0, 0.0, 0.0),
		&"Neck": Vector3(10.0, 0.0, 0.0),
		&"Head": Vector3(12.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(40.0, 0.0, -60.0),
		&"LeftLowerArm": Vector3(40.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(30.0, 0.0, 66.0),
		&"RightLowerArm": Vector3(36.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(26.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-10.0, 0.0, 0.0),
		&"LeftFoot": Vector3(10.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-28.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"RightFoot": Vector3(30.0, 0.0, -5.0),
	})


static func stagger_back_b() -> Dictionary[StringName, Vector3]:
	return merge(stagger_back_a(), {
		&"Spine": Vector3(4.0, 0.0, 0.0),
		&"Chest": Vector3(2.0, 0.0, 0.0),
		&"Neck": Vector3(2.0, 0.0, 0.0),
		&"Head": Vector3(4.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(30.0, 0.0, -36.0),
		&"RightUpperArm": Vector3(24.0, 0.0, 40.0),
		&"LeftUpperLeg": Vector3(-14.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-40.0, 0.0, 0.0),
		&"LeftFoot": Vector3(30.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-16.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-20.0, 0.0, 0.0),
		&"RightFoot": Vector3(30.0, 0.0, -5.0),
	})


## Stumbling toward the victim's own right; stagger_left mirrors it.
static func stagger_right_a() -> Dictionary[StringName, Vector3]:
	return merge(guard(), {
		&"Hips": Vector3(0.0, -10.0, 0.0),
		&"Spine": Vector3(0.0, 0.0, -16.0),
		&"Chest": Vector3(0.0, 0.0, -8.0),
		&"Neck": Vector3(0.0, 0.0, -12.0),
		&"Head": Vector3(0.0, 0.0, -10.0),
		&"LeftUpperArm": Vector3(20.0, 0.0, -70.0),
		&"LeftLowerArm": Vector3(30.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(20.0, 0.0, 40.0),
		&"RightLowerArm": Vector3(60.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(10.0, 0.0, 10.0),
		&"LeftLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"LeftFoot": Vector3(14.0, 0.0, -10.0),
		&"RightUpperLeg": Vector3(14.0, 0.0, 24.0),
		&"RightLowerLeg": Vector3(-20.0, 0.0, 0.0),
		&"RightFoot": Vector3(6.0, 0.0, -24.0),
	})


static func stagger_right_b() -> Dictionary[StringName, Vector3]:
	return merge(stagger_right_a(), {
		&"Spine": Vector3(-4.0, 0.0, -6.0),
		&"Chest": Vector3(-2.0, 0.0, -2.0),
		&"Neck": Vector3(0.0, 0.0, -4.0),
		&"Head": Vector3(0.0, 0.0, -2.0),
		&"LeftUpperArm": Vector3(30.0, 0.0, -40.0),
		&"RightUpperArm": Vector3(30.0, 0.0, 30.0),
		&"LeftUpperLeg": Vector3(10.0, 0.0, 16.0),
		&"LeftLowerLeg": Vector3(-20.0, 0.0, 0.0),
		&"LeftFoot": Vector3(8.0, 0.0, -16.0),
		&"RightUpperLeg": Vector3(10.0, 0.0, 14.0),
		&"RightLowerLeg": Vector3(-24.0, 0.0, 0.0),
		&"RightFoot": Vector3(14.0, 0.0, -14.0),
	})


## Stumbling forward (hit from behind): pitched forward, arms flung back.
static func stagger_forward_a() -> Dictionary[StringName, Vector3]:
	return merge(guard(), {
		&"Spine": Vector3(-22.0, 0.0, 0.0),
		&"Chest": Vector3(-10.0, 0.0, 0.0),
		&"Neck": Vector3(-6.0, 0.0, 0.0),
		&"Head": Vector3(-14.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(-40.0, 0.0, -30.0),
		&"LeftLowerArm": Vector3(30.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(-36.0, 0.0, 30.0),
		&"RightLowerArm": Vector3(30.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(40.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-40.0, 0.0, 0.0),
		&"LeftFoot": Vector3(0.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-20.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"RightFoot": Vector3(50.0, 0.0, -5.0),
	})


static func stagger_forward_b() -> Dictionary[StringName, Vector3]:
	return merge(stagger_forward_a(), {
		&"Spine": Vector3(-10.0, 0.0, 0.0),
		&"Chest": Vector3(-4.0, 0.0, 0.0),
		&"Head": Vector3(-4.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(10.0, 0.0, -30.0),
		&"RightUpperArm": Vector3(10.0, 0.0, 30.0),
		&"LeftUpperLeg": Vector3(10.0, 0.0, -4.0),
		&"RightUpperLeg": Vector3(30.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-50.0, 0.0, 0.0),
		&"RightFoot": Vector3(20.0, 0.0, -5.0),
	})


## Airborne after a finisher: arched back, limbs flung forward.
static func launched_a() -> Dictionary[StringName, Vector3]:
	return {
		HIPS_POS: Vector3.ZERO,
		&"Hips": Vector3(30.0, 0.0, 0.0),
		&"Spine": Vector3(14.0, 0.0, 0.0),
		&"Chest": Vector3(10.0, 0.0, 0.0),
		&"Neck": Vector3(20.0, 0.0, 0.0),
		&"Head": Vector3(20.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(110.0, 0.0, -50.0),
		&"LeftLowerArm": Vector3(30.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(120.0, 0.0, 44.0),
		&"RightLowerArm": Vector3(40.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(40.0, 0.0, -10.0),
		&"LeftLowerLeg": Vector3(-50.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(20.0, 0.0, 12.0),
		&"RightLowerLeg": Vector3(-30.0, 0.0, 0.0),
	}


static func launched_b() -> Dictionary[StringName, Vector3]:
	return merge(launched_a(), {
		HIPS_POS: Vector3(0.0, -0.3, 0.0),
		&"Hips": Vector3(60.0, 0.0, 0.0),
		&"Spine": Vector3(10.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(150.0, 0.0, -60.0),
		&"RightUpperArm": Vector3(140.0, 0.0, 70.0),
		&"LeftUpperLeg": Vector3(10.0, 0.0, -14.0),
		&"LeftLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(-10.0, 0.0, 16.0),
		&"RightLowerLeg": Vector3(-60.0, 0.0, 0.0),
	})


## Thrown by a grab: tumbling sideways through the air.
static func thrown_a() -> Dictionary[StringName, Vector3]:
	return {
		HIPS_POS: Vector3.ZERO,
		&"Hips": Vector3(20.0, 0.0, 40.0),
		&"Spine": Vector3(-10.0, 0.0, 10.0),
		&"Neck": Vector3(-10.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(140.0, 0.0, -40.0),
		&"LeftLowerArm": Vector3(40.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(100.0, 0.0, 80.0),
		&"RightLowerArm": Vector3(20.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(50.0, 0.0, -20.0),
		&"LeftLowerLeg": Vector3(-70.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(10.0, 0.0, 30.0),
		&"RightLowerLeg": Vector3(-20.0, 0.0, 0.0),
	}


static func thrown_b() -> Dictionary[StringName, Vector3]:
	return merge(thrown_a(), {
		HIPS_POS: Vector3(0.0, -0.35, 0.0),
		&"Hips": Vector3(70.0, 0.0, 80.0),
		&"LeftUpperArm": Vector3(160.0, 0.0, -80.0),
		&"RightUpperArm": Vector3(150.0, 0.0, 60.0),
		&"LeftUpperLeg": Vector3(30.0, 0.0, -30.0),
		&"RightUpperLeg": Vector3(40.0, 0.0, 40.0),
		&"RightLowerLeg": Vector3(-70.0, 0.0, 0.0),
	})


## Knees buckling at the start of a fall (knockdowns and KOs).
static func buckle() -> Dictionary[StringName, Vector3]:
	return merge(guard(), {
		&"Spine": Vector3(-8.0, 0.0, 0.0),
		&"Neck": Vector3(-10.0, 0.0, 0.0),
		&"Head": Vector3(-10.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(14.0, 0.0, -20.0),
		&"LeftLowerArm": Vector3(40.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(10.0, 0.0, 22.0),
		&"RightLowerArm": Vector3(40.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(50.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-80.0, 0.0, 0.0),
		&"LeftFoot": Vector3(30.0, 0.0, 6.0),
		&"RightUpperLeg": Vector3(40.0, 0.0, 6.0),
		&"RightLowerLeg": Vector3(-76.0, 0.0, 0.0),
		&"RightFoot": Vector3(36.0, 0.0, -6.0),
	})


## Halfway down in a backward fall: sitting down hard, knees up in front.
static func falling_back() -> Dictionary[StringName, Vector3]:
	return merge(downed_back(), {
		HIPS_POS: Vector3(0.0, -0.45, 0.0),
		&"Hips": Vector3(45.0, 0.0, 0.0),
		&"Spine": Vector3(-6.0, 0.0, 0.0),
		&"Neck": Vector3(-20.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(70.0, 0.0, -50.0),
		&"RightUpperArm": Vector3(60.0, 0.0, 50.0),
		&"LeftUpperLeg": Vector3(35.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-50.0, 0.0, 0.0),
		&"LeftFoot": Vector3(0.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(45.0, 0.0, 6.0),
		&"RightLowerLeg": Vector3(-70.0, 0.0, 0.0),
		&"RightFoot": Vector3(0.0, 0.0, 0.0),
	})


## Halfway down in a forward fall: dropping to the knees, arms out to break the fall.
static func falling_front() -> Dictionary[StringName, Vector3]:
	return merge(downed_front(), {
		HIPS_POS: Vector3(0.0, -0.45, 0.0),
		&"Hips": Vector3(-45.0, 0.0, 0.0),
		&"Neck": Vector3(20.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(90.0, 0.0, -20.0),
		&"LeftLowerArm": Vector3(30.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(90.0, 0.0, 20.0),
		&"RightLowerArm": Vector3(30.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(40.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-85.0, 0.0, 0.0),
		&"LeftFoot": Vector3(-30.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(46.0, 0.0, 6.0),
		&"RightLowerLeg": Vector3(-80.0, 0.0, 0.0),
		&"RightFoot": Vector3(-30.0, 0.0, 0.0),
	})


## Get-up from the back: sitting up (left knee up, right leg still out along the floor),
## then a deep crouch.
static func getup_back_sit() -> Dictionary[StringName, Vector3]:
	return {
		HIPS_POS: Vector3(0.0, -0.8, 0.0),
		&"Hips": Vector3(30.0, 0.0, 0.0),
		&"Spine": Vector3(-30.0, 0.0, 0.0),
		&"Chest": Vector3(-14.0, 0.0, 0.0),
		&"Neck": Vector3(10.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(-30.0, 0.0, -20.0),
		&"LeftLowerArm": Vector3(10.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(-30.0, 0.0, 20.0),
		&"RightLowerArm": Vector3(10.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(105.0, 0.0, -8.0),
		&"LeftLowerLeg": Vector3(-115.0, 0.0, 0.0),
		&"LeftFoot": Vector3(-20.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(62.0, 0.0, 8.0),
		&"RightLowerLeg": Vector3(-10.0, 0.0, 0.0),
		&"RightFoot": Vector3(-6.0, 0.0, 0.0),
	}


static func getup_crouch() -> Dictionary[StringName, Vector3]:
	return merge(crouch(), {
		&"Spine": Vector3(-26.0, 0.0, 0.0),
		&"Neck": Vector3(20.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(80.0, 0.0, -8.0),
		&"LeftLowerLeg": Vector3(-120.0, 0.0, 0.0),
		&"LeftFoot": Vector3(40.0, 0.0, 8.0),
		&"RightUpperLeg": Vector3(70.0, 0.0, 8.0),
		&"RightLowerLeg": Vector3(-125.0, 0.0, 0.0),
		&"RightFoot": Vector3(55.0, 0.0, -8.0),
	})


## Get-up from the front: pushing up onto hands and one knee.
static func getup_front_push() -> Dictionary[StringName, Vector3]:
	return {
		HIPS_POS: Vector3(0.0, -0.55, 0.12),
		&"Hips": Vector3(-50.0, 0.0, 0.0),
		&"Spine": Vector3(-10.0, 0.0, 0.0),
		&"Chest": Vector3(-6.0, 0.0, 0.0),
		&"Neck": Vector3(30.0, 0.0, 0.0),
		&"Head": Vector3(10.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(40.0, 0.0, -10.0),
		&"LeftLowerArm": Vector3(10.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(40.0, 0.0, 10.0),
		&"RightLowerArm": Vector3(10.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(110.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-120.0, 0.0, 0.0),
		&"LeftFoot": Vector3(10.0, 0.0, 6.0),
		&"RightUpperLeg": Vector3(60.0, 0.0, 6.0),
		&"RightLowerLeg": Vector3(-100.0, 0.0, 0.0),
		&"RightFoot": Vector3(-30.0, 0.0, -6.0),
	}


# --- Moves -----------------------------------------------------------------------------


## Key poses for a move id from docs/ARCHITECTURE.md, or null if there is no recipe.
static func move_poses(id: StringName) -> MovePoses:
	match id:
		&"jab_1":
			return _jab_1()
		&"jab_2":
			return _jab_2()
		&"hook":
			return _hook()
		&"uppercut":
			return _uppercut()
		&"body_flurry":
			return _body_flurry()
		&"shove":
			return _shove()
		&"front_kick":
			return _front_kick()
		&"roundhouse":
			return _roundhouse()
		&"spinning_heel":
			return _spinning_heel()
		&"stomp_kick":
			return _stomp_kick()
		&"push_kick":
			return _push_kick()
		&"haymaker":
			return _haymaker()
		&"flying_kick":
			return _flying_kick()
		&"spin_kick":
			return _spin_kick()
		&"back_elbow":
			return _back_elbow()
		&"knee":
			return _knee()
		&"throw":
			return _throw()
		&"stomp":
			return _stomp()
		&"pipe_swing_1":
			return _pipe_swing_1()
		&"pipe_swing_2":
			return _pipe_swing_2()
		&"pipe_swing_3":
			return _pipe_swing_3()
		&"weapon_throw":
			return _weapon_throw()
		&"impact_body_knockdown", &"impact_body_stagger":
			return _mp(guard(), guard(), guard())
	return null


## Fallback straight punch with the right fist (mirror it for the left).
static func generic_punch() -> MovePoses:
	return _jab_2()


## Fallback straight kick with the right foot (mirror it for the left).
static func generic_kick() -> MovePoses:
	return _front_kick()


# Strike poses are tuned so the strike point lands in the "Strike reach" envelope of
# docs/ARCHITECTURE.md (checked by tests/test_humanoid_rig.gd), and so punches enter the
# first-person view from EyePoint.

static func _jab_1() -> MovePoses:
	var g := guard()
	var windup := merge(g, {
		&"Hips": Vector3(0.0, 6.0, 0.0),
		&"LeftUpperArm": Vector3(48.0, 0.0, -10.0),
		&"LeftLowerArm": Vector3(112.0, 0.0, 0.0),
	})
	var strike := merge(g, {
		&"Hips": Vector3(0.0, -10.0, 0.0),
		&"Spine": Vector3(-6.0, -8.0, 0.0),
		&"Chest": Vector3(-4.0, -8.0, 0.0),
		&"UpperChest": Vector3(0.0, -6.0, 0.0),
		&"Neck": Vector3(6.0, 16.0, 0.0),
		&"Head": Vector3(4.0, 16.0, 0.0),
		&"LeftShoulder": Vector3(0.0, -10.5, 0.0),
		&"LeftUpperArm": Vector3(100.0, 30.0, -0.5),
		&"LeftLowerArm": Vector3(33.5, 0.0, 0.0),
		&"RightUpperArm": Vector3(34.0, 0.0, 18.0),
		&"RightLowerArm": Vector3(126.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(22.0, 10.0, -4.0),
		&"LeftLowerLeg": Vector3(-26.0, 0.0, 0.0),
		&"LeftFoot": Vector3(4.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-10.0, 10.0, 5.0),
		&"RightLowerLeg": Vector3(-14.0, 0.0, 0.0),
		&"RightFoot": Vector3(24.0, 0.0, -5.0),
	})
	return _mp(g, windup, strike)


static func _jab_2() -> MovePoses:
	var g := guard()
	var windup := merge(g, {
		&"Hips": Vector3(0.0, -8.0, 0.0),
		&"RightUpperArm": Vector3(40.0, 0.0, 12.0),
		&"RightLowerArm": Vector3(116.0, 0.0, 0.0),
	})
	var strike := merge(g, {
		&"Hips": Vector3(0.0, 14.0, 0.0),
		&"Spine": Vector3(-6.0, 10.0, 0.0),
		&"Chest": Vector3(-4.0, 8.0, 0.0),
		&"UpperChest": Vector3(0.0, 6.0, 0.0),
		&"Neck": Vector3(6.0, -18.0, 0.0),
		&"Head": Vector3(4.0, -20.0, 0.0),
		&"RightShoulder": Vector3(0.0, 9.0, 0.0),
		&"RightUpperArm": Vector3(96.5, -34.0, 3.0),
		&"RightLowerArm": Vector3(39.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(40.0, 0.0, -16.0),
		&"LeftLowerArm": Vector3(124.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(18.0, -14.0, -4.0),
		&"LeftLowerLeg": Vector3(-26.0, 0.0, 0.0),
		&"LeftFoot": Vector3(8.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-10.0, -14.0, 5.0),
		&"RightLowerLeg": Vector3(-14.0, 0.0, 0.0),
		&"RightFoot": Vector3(30.0, 0.0, -5.0),
		&"RightToes": Vector3(20.0, 0.0, 0.0),
	})
	return _mp(g, windup, strike)


static func _hook() -> MovePoses:
	var g := guard()
	var windup := merge(g, {
		&"Hips": Vector3(0.0, 10.0, 0.0),
		&"Chest": Vector3(-3.0, 6.0, 0.0),
		&"LeftUpperArm": Vector3(20.0, 0.0, -60.0),
		&"LeftLowerArm": Vector3(110.0, 0.0, 0.0),
	})
	var strike := merge(g, {
		&"Hips": Vector3(0.0, -14.0, 0.0),
		&"Spine": Vector3(-4.0, -10.0, 0.0),
		&"Chest": Vector3(-2.0, -10.0, 0.0),
		&"UpperChest": Vector3(0.0, -8.0, 0.0),
		&"Neck": Vector3(4.0, 20.0, 0.0),
		&"Head": Vector3(2.0, 22.0, 0.0),
		&"LeftShoulder": Vector3(0.0, -12.5, 0.0),
		&"LeftUpperArm": Vector3(20.0, -9.0, -108.0),
		&"LeftLowerArm": Vector3(66.5, 0.0, 0.0),
		&"RightUpperArm": Vector3(34.0, 0.0, 18.0),
		&"RightLowerArm": Vector3(126.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(18.0, 14.0, -4.0),
		&"LeftFoot": Vector3(8.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-6.0, 14.0, 5.0),
	})
	var follow := merge(strike, {
		&"Hips": Vector3(0.0, -20.0, 0.0),
		&"LeftUpperArm": Vector3(10.0, -60.0, -70.0),
		&"LeftLowerArm": Vector3(100.0, 0.0, 0.0),
	})
	var m := _mp(g, windup, strike)
	m.follow = follow
	return m


static func _uppercut() -> MovePoses:
	var g := guard()
	# A short dip (knees half bent), not a full crouch, so the first-person camera on
	# EyePoint only bobs a few centimeters.
	var windup := merge(g, {
		&"Hips": Vector3(0.0, -16.0, 0.0),
		&"Spine": Vector3(-10.0, -6.0, 0.0),
		&"Neck": Vector3(10.0, 22.0, 0.0),
		&"LeftUpperLeg": Vector3(30.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-46.0, 0.0, 0.0),
		&"LeftFoot": Vector3(16.0, 0.0, 6.0),
		&"RightUpperLeg": Vector3(14.0, 0.0, 6.0),
		&"RightLowerLeg": Vector3(-40.0, 0.0, 0.0),
		&"RightFoot": Vector3(26.0, 0.0, -6.0),
		&"LeftUpperArm": Vector3(42.0, 0.0, -14.0),
		&"LeftLowerArm": Vector3(118.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(14.0, 0.0, 16.0),
		&"RightLowerArm": Vector3(100.0, 0.0, 0.0),
	})
	var strike := merge(g, {
		&"Hips": Vector3(0.0, 16.0, 0.0),
		&"Spine": Vector3(-2.0, 8.0, 0.0),
		&"Chest": Vector3(0.0, 8.0, 0.0),
		&"UpperChest": Vector3(0.0, 6.0, 0.0),
		&"Neck": Vector3(2.0, -18.0, 0.0),
		&"Head": Vector3(2.0, -20.0, 0.0),
		&"RightShoulder": Vector3(0.0, 22.0, 0.0),
		&"RightUpperArm": Vector3(82.0, -25.0, 24.0),
		&"RightLowerArm": Vector3(50.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(40.0, 0.0, -16.0),
		&"LeftLowerArm": Vector3(124.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(12.0, -16.0, -4.0),
		&"LeftLowerLeg": Vector3(-14.0, 0.0, 0.0),
		&"LeftFoot": Vector3(2.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-8.0, -16.0, 5.0),
		&"RightLowerLeg": Vector3(-10.0, 0.0, 0.0),
		&"RightFoot": Vector3(36.0, 0.0, -5.0),
		&"RightToes": Vector3(26.0, 0.0, 0.0),
	})
	return _mp(g, windup, strike)


static func _body_flurry() -> MovePoses:
	var g := guard()
	var low := merge(g, {
		&"Hips": Vector3(0.0, 0.0, 0.0),
		&"Spine": Vector3(-14.0, 0.0, 0.0),
		&"Chest": Vector3(-8.0, 0.0, 0.0),
		&"Neck": Vector3(14.0, 0.0, 0.0),
		&"Head": Vector3(8.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(30.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-44.0, 0.0, 0.0),
		&"LeftFoot": Vector3(14.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(4.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-36.0, 0.0, 0.0),
		&"RightFoot": Vector3(32.0, 0.0, -5.0),
	})
	var windup := merge(low, {
		&"Hips": Vector3(0.0, 8.0, 0.0),
		&"LeftUpperArm": Vector3(40.0, 0.0, -12.0),
		&"LeftLowerArm": Vector3(100.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(50.0, 0.0, 12.0),
		&"RightLowerArm": Vector3(70.0, 0.0, 0.0),
	})
	var strike := merge(low, {
		&"Hips": Vector3(0.0, -8.0, 0.0),
		&"Spine": Vector3(-14.0, -4.0, 0.0),
		&"Neck": Vector3(14.0, 6.0, 0.0),
		&"Head": Vector3(8.0, 6.0, 0.0),
		&"LeftShoulder": Vector3(0.0, -14.0, 0.0),
		&"LeftUpperArm": Vector3(71.0, 15.0, 7.0),
		&"LeftLowerArm": Vector3(42.0, 0.0, 0.0),
		&"RightShoulder": Vector3(0.0, 10.0, 0.0),
		&"RightUpperArm": Vector3(35.0, 15.0, -11.0),
		&"RightLowerArm": Vector3(124.0, 0.0, 0.0),
	})
	return _mp(g, windup, strike)


static func _shove() -> MovePoses:
	var g := guard()
	var windup := merge(g, {
		&"Spine": Vector3(2.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(24.0, 0.0, -24.0),
		&"LeftLowerArm": Vector3(130.0, 0.0, 0.0),
		&"LeftHand": Vector3(60.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(24.0, 0.0, 24.0),
		&"RightLowerArm": Vector3(130.0, 0.0, 0.0),
		&"RightHand": Vector3(60.0, 0.0, 0.0),
	})
	var strike := merge(g, {
		&"Spine": Vector3(-14.0, 0.0, 0.0),
		&"Chest": Vector3(-6.0, 0.0, 0.0),
		&"Neck": Vector3(12.0, 0.0, 0.0),
		&"Head": Vector3(8.0, 0.0, 0.0),
		&"LeftShoulder": Vector3(0.0, -10.0, 0.0),
		&"LeftUpperArm": Vector3(80.0, 10.0, 0.0),
		&"LeftLowerArm": Vector3(14.0, 0.0, 0.0),
		&"LeftHand": Vector3(70.0, 0.0, 0.0),
		&"RightShoulder": Vector3(0.0, 10.0, 0.0),
		&"RightUpperArm": Vector3(80.0, -10.0, 0.0),
		&"RightLowerArm": Vector3(14.0, 0.0, 0.0),
		&"RightHand": Vector3(70.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(34.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"LeftFoot": Vector3(-4.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-20.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-10.0, 0.0, 0.0),
		&"RightFoot": Vector3(30.0, 0.0, -5.0),
		&"RightToes": Vector3(20.0, 0.0, 0.0),
	})
	return _mp(g, windup, strike)


## Right-leg kick chamber: knee up, shin folded under.
static func _kick_chamber(g: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(g, {
		&"Spine": Vector3(2.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(84.0, 0.0, 4.0),
		&"RightLowerLeg": Vector3(-96.0, 0.0, 0.0),
		&"RightFoot": Vector3(-10.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(10.0, 0.0, -3.0),
		&"LeftLowerLeg": Vector3(-20.0, 0.0, 0.0),
		&"LeftFoot": Vector3(10.0, 0.0, 3.0),
	})


## Straight kicks lean back from the hips: the hips shift back and the spine tips back. The
## kicks land sole first, so only the sole sinks a few centimeters into a target at arm's
## length while the shoe and shin stay in front of it, in the lower part of the
## first-person view.
static func _kick_lean() -> Dictionary[StringName, Vector3]:
	return {
		HIPS_NUDGE: Vector3(0.0, 0.0, 0.08),
		&"Spine": Vector3(5.0, 0.0, 0.0),
		&"Chest": Vector3(0.0, 0.0, 0.0),
		&"Neck": Vector3(-5.0, 0.0, 0.0),
		&"Head": Vector3(-3.0, 0.0, 0.0),
	}


static func _front_kick() -> MovePoses:
	var g := guard()
	var strike := merge(merge(g, _kick_lean()), {
		&"RightUpperLeg": Vector3(115.0, 1.0, 2.0),
		&"RightLowerLeg": Vector3(-31.0, 0.0, 0.0),
		&"RightFoot": Vector3(-4.0, 0.0, 0.0),
		&"RightToes": Vector3(37.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(6.0, 0.0, -3.0),
		&"LeftLowerLeg": Vector3(-16.0, 0.0, 0.0),
		&"LeftFoot": Vector3(10.0, 0.0, 3.0),
		&"LeftUpperArm": Vector3(36.0, 0.0, -24.0),
		&"RightUpperArm": Vector3(20.0, 0.0, 30.0),
		&"RightLowerArm": Vector3(110.0, 0.0, 0.0),
	})
	var m := _mp(g, _kick_chamber(g), strike)
	m.follow = _kick_chamber(g)
	return m


static func _push_kick() -> MovePoses:
	var g := guard()
	var strike := merge(merge(g, _kick_lean()), {
		&"Hips": Vector3(0.0, 8.0, 0.0),
		&"RightUpperLeg": Vector3(114.0, -7.0, 0.0),
		&"RightLowerLeg": Vector3(-31.0, 0.0, 0.0),
		&"RightFoot": Vector3(7.0, 0.0, 0.0),
		&"RightToes": Vector3(33.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(4.0, -8.0, -3.0),
		&"LeftLowerLeg": Vector3(-20.0, 0.0, 0.0),
		&"LeftFoot": Vector3(16.0, 0.0, 3.0),
		&"LeftUpperArm": Vector3(30.0, 0.0, -30.0),
		&"RightUpperArm": Vector3(-10.0, 0.0, 30.0),
		&"RightLowerArm": Vector3(100.0, 0.0, 0.0),
	})
	var m := _mp(g, _kick_chamber(g), strike)
	m.follow = _kick_chamber(g)
	return m


static func _stomp_kick() -> MovePoses:
	var g := guard()
	var strike := merge(merge(g, _kick_lean()), {
		&"RightUpperLeg": Vector3(93.0, 3.0, 2.0),
		&"RightLowerLeg": Vector3(-3.0, 0.0, 0.0),
		&"RightFoot": Vector3(1.0, 0.0, 0.0),
		&"RightToes": Vector3(28.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(14.0, 0.0, -3.0),
		&"LeftLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"LeftFoot": Vector3(16.0, 0.0, 3.0),
		&"LeftUpperArm": Vector3(30.0, 0.0, -30.0),
		&"RightUpperArm": Vector3(14.0, 0.0, 30.0),
		&"RightLowerArm": Vector3(110.0, 0.0, 0.0),
	})
	var windup := merge(_kick_chamber(g), {
		&"RightUpperLeg": Vector3(100.0, 0.0, 4.0),
		&"RightLowerLeg": Vector3(-110.0, 0.0, 0.0),
	})
	var m := _mp(g, windup, strike)
	m.follow = _kick_chamber(g)
	return m


static func _roundhouse() -> MovePoses:
	var g := guard()
	var windup := merge(g, {
		&"Hips": Vector3(0.0, 30.0, 0.0),
		&"Spine": Vector3(0.0, -10.0, -4.0),
		&"Chest": Vector3(0.0, -8.0, 0.0),
		&"Neck": Vector3(4.0, -10.0, 0.0),
		&"RightUpperLeg": Vector3(60.0, 0.0, 50.0),
		&"RightLowerLeg": Vector3(-100.0, 0.0, 0.0),
		&"RightFoot": Vector3(-20.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(10.0, -30.0, -3.0),
		&"LeftLowerLeg": Vector3(-20.0, 0.0, 0.0),
		&"LeftFoot": Vector3(10.0, 0.0, 3.0),
	})
	var strike := merge(g, {
		&"Hips": Vector3(0.0, 56.0, 0.0),
		&"Spine": Vector3(0.0, -18.0, 14.0),
		&"Chest": Vector3(0.0, -14.0, 6.0),
		&"UpperChest": Vector3(0.0, -8.0, 0.0),
		&"Neck": Vector3(4.0, -10.0, -10.0),
		&"Head": Vector3(2.0, -6.0, -6.0),
		&"RightUpperLeg": Vector3(128.0, -8.0, 46.0),
		&"RightLowerLeg": Vector3(-1.0, 0.0, 0.0),
		&"RightFoot": Vector3(12.5, 0.0, 0.0),
		&"RightToes": Vector3(8.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(4.0, -56.0, -3.0),
		&"LeftLowerLeg": Vector3(-14.0, 0.0, 0.0),
		&"LeftFoot": Vector3(10.0, 0.0, 3.0),
		&"LeftUpperArm": Vector3(40.0, 0.0, -30.0),
		&"RightUpperArm": Vector3(10.0, 0.0, 30.0),
		&"RightLowerArm": Vector3(100.0, 0.0, 0.0),
	})
	var m := _mp(g, windup, strike)
	m.follow = merge(windup, {&"Hips": Vector3(0.0, 64.0, 0.0)})
	return m


## Spinning back heel: turns right a full 360 through the hips; the extended right leg
## crosses the front at the strike (hips yaw -270).
static func _spinning_heel() -> MovePoses:
	var g := guard()
	var leg_out: Dictionary[StringName, Vector3] = {
		&"Spine": Vector3(0.0, 0.0, 8.0),
		&"Chest": Vector3(0.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(4.0, 0.0, 92.0),
		&"RightLowerLeg": Vector3(-4.0, 0.0, 0.0),
		&"RightFoot": Vector3(10.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(8.0, 0.0, -10.0),
		&"LeftLowerLeg": Vector3(-20.0, 0.0, 0.0),
		&"LeftFoot": Vector3(12.0, 0.0, 10.0),
		&"LeftUpperArm": Vector3(40.0, 0.0, -50.0),
		# The right arm swings back along the side, out of the first-person view.
		&"RightUpperArm": Vector3(-25.0, 0.0, 25.0),
		&"RightLowerArm": Vector3(70.0, 0.0, 0.0),
	}
	var windup := merge(g, {
		&"Hips": Vector3(0.0, -120.0, 0.0),
		&"Spine": Vector3(-6.0, -10.0, 0.0),
		&"Neck": Vector3(4.0, 30.0, 0.0),
		&"Head": Vector3(2.0, 30.0, 0.0),
		&"RightUpperLeg": Vector3(30.0, 0.0, 30.0),
		&"RightLowerLeg": Vector3(-60.0, 0.0, 0.0),
	})
	var strike := merge(g, leg_out)
	strike[&"Hips"] = Vector3(0.0, -270.0, 0.0)
	# Spot the target over the shoulder: the torso twists 45 degrees back toward the
	# target and the head the rest of the way to -Z. The twist swings the right shoulder
	# out to the side, so it does not fill the first-person view in front of EyePoint.
	strike[&"Spine"] = Vector3(0.0, -15.0, 6.0)
	strike[&"Chest"] = Vector3(0.0, -15.0, 2.0)
	strike[&"UpperChest"] = Vector3(0.0, -15.0, 0.0)
	strike[&"Neck"] = Vector3(0.0, -22.0, -4.0)
	strike[&"Head"] = Vector3(0.0, -23.0, 0.0)
	var strike_end := strike.duplicate()
	strike_end[&"Hips"] = Vector3(0.0, -300.0, 0.0)
	var follow := merge(g, {&"Hips": Vector3(0.0, -335.0, 0.0)})
	var m := _mp(g, windup, strike)
	m.strike_end = strike_end
	m.follow = follow
	m.follow_at = 0.4
	m.finish = merge(g, {&"Hips": Vector3(0.0, -360.0, 0.0)})
	return m


## Air guard: legs tucked, used as the base pose of air moves.
static func _air_guard() -> Dictionary[StringName, Vector3]:
	return merge(guard(), {
		HIPS_POS: Vector3.ZERO,
		&"LeftUpperLeg": Vector3(40.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-70.0, 0.0, 0.0),
		&"LeftFoot": Vector3(-10.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(30.0, 0.0, 4.0),
		&"RightLowerLeg": Vector3(-60.0, 0.0, 0.0),
		&"RightFoot": Vector3(-10.0, 0.0, -4.0),
	})


static func _flying_kick() -> MovePoses:
	var g := _air_guard()
	var windup := merge(g, {
		&"RightUpperLeg": Vector3(80.0, 0.0, 4.0),
		&"RightLowerLeg": Vector3(-110.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(60.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-120.0, 0.0, 0.0),
	})
	var strike := merge(g, {
		# Leaning back in the air: the hips trail 8 cm behind the rig origin.
		HIPS_POS: Vector3(0.0, 0.0, 0.08),
		&"Spine": Vector3(6.0, 0.0, 0.0),
		&"Chest": Vector3(0.0, 0.0, 0.0),
		&"Neck": Vector3(-5.0, 0.0, 0.0),
		&"Head": Vector3(-3.0, 0.0, 0.0),
		# The kicker is 0.4-1.0 m off the ground, so the straight leg drives forward and
		# down: the foot lands at a standing target's chest, not over its head.
		&"RightUpperLeg": Vector3(67.0, 1.0, 2.0),
		&"RightLowerLeg": Vector3(-8.0, 0.0, 0.0),
		&"RightFoot": Vector3(30.0, 0.0, 0.0),
		&"RightToes": Vector3(20.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(50.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-120.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(50.0, 0.0, -40.0),
		&"LeftLowerArm": Vector3(80.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(10.0, 0.0, 40.0),
		&"RightLowerArm": Vector3(90.0, 0.0, 0.0),
	})
	return _mp(g, windup, strike)


## Air spin kick at the apex: a full right turn with the right leg straight out to the
## side through all the active frames.
static func _spin_kick() -> MovePoses:
	var g := _air_guard()
	var windup := merge(g, {
		&"Hips": Vector3(0.0, -50.0, 0.0),
		&"Neck": Vector3(0.0, 20.0, 0.0),
		&"Head": Vector3(0.0, 20.0, 0.0),
		&"RightUpperLeg": Vector3(40.0, 0.0, 40.0),
		&"RightLowerLeg": Vector3(-80.0, 0.0, 0.0),
	})
	var strike := merge(g, {
		&"Hips": Vector3(0.0, -100.0, 0.0),
		&"Spine": Vector3(0.0, 0.0, 6.0),
		&"Neck": Vector3(0.0, 45.0, -10.0),
		&"Head": Vector3(0.0, 45.0, 0.0),
		&"RightUpperLeg": Vector3(10.0, 0.0, 84.0),
		&"RightLowerLeg": Vector3(-4.0, 0.0, 0.0),
		&"RightFoot": Vector3(10.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(50.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-100.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(40.0, 0.0, -60.0),
		&"RightUpperArm": Vector3(30.0, 0.0, 50.0),
	})
	var strike_end := strike.duplicate()
	strike_end[&"Hips"] = Vector3(0.0, -330.0, 0.0)
	strike_end[&"Neck"] = Vector3(0.0, -10.0, -10.0)
	strike_end[&"Head"] = Vector3(0.0, -10.0, 0.0)
	var m := _mp(g, windup, strike)
	m.strike_end = strike_end
	m.follow = merge(g, {&"Hips": Vector3(0.0, -350.0, 0.0)})
	m.finish = merge(g, {&"Hips": Vector3(0.0, -360.0, 0.0)})
	return m


static func _haymaker() -> MovePoses:
	var g := guard()
	var windup := merge(g, {
		&"Hips": Vector3(0.0, -24.0, 0.0),
		&"Spine": Vector3(6.0, -12.0, 0.0),
		&"Chest": Vector3(2.0, -10.0, 0.0),
		&"UpperChest": Vector3(0.0, -6.0, 0.0),
		&"Neck": Vector3(-4.0, 26.0, 0.0),
		&"Head": Vector3(-2.0, 24.0, 0.0),
		&"RightShoulder": Vector3(0.0, -12.0, 6.0),
		&"RightUpperArm": Vector3(10.0, 0.0, 70.0),
		&"RightLowerArm": Vector3(120.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(60.0, 10.0, -20.0),
		&"LeftLowerArm": Vector3(90.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(26.0, 24.0, -4.0),
		&"LeftLowerLeg": Vector3(-20.0, 0.0, 0.0),
		&"LeftFoot": Vector3(0.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(4.0, 24.0, 5.0),
		&"RightLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"RightFoot": Vector3(26.0, 0.0, -5.0),
	})
	var strike := merge(g, {
		&"Hips": Vector3(0.0, 18.0, 0.0),
		&"Spine": Vector3(-10.0, 10.0, 0.0),
		&"Chest": Vector3(-6.0, 10.0, 0.0),
		&"UpperChest": Vector3(0.0, 8.0, 0.0),
		&"Neck": Vector3(10.0, -22.0, 0.0),
		&"Head": Vector3(6.0, -24.0, 0.0),
		&"RightShoulder": Vector3(0.0, 19.5, 0.0),
		&"RightUpperArm": Vector3(103.5, -50.0, 11.0),
		&"RightLowerArm": Vector3(49.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(30.0, 0.0, -20.0),
		&"LeftLowerArm": Vector3(126.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(30.0, -18.0, -4.0),
		&"LeftLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"LeftFoot": Vector3(2.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-16.0, -18.0, 5.0),
		&"RightLowerLeg": Vector3(-14.0, 0.0, 0.0),
		&"RightFoot": Vector3(40.0, 0.0, -5.0),
		&"RightToes": Vector3(30.0, 0.0, 0.0),
	})
	return _mp(g, windup, strike)


## Haymaker charge pose: the haymaker's wind-up, held while P is held.
static func haymaker_charge() -> Dictionary[StringName, Vector3]:
	return _haymaker().windup


static func _back_elbow() -> MovePoses:
	var g := guard()
	var windup := merge(g, {
		&"UpperChest": Vector3(0.0, 14.0, 0.0),
		&"Chest": Vector3(-3.0, 8.0, 0.0),
		&"RightUpperArm": Vector3(70.0, 30.0, 0.0),
		&"RightLowerArm": Vector3(110.0, 0.0, 0.0),
	})
	var strike := merge(g, {
		&"Spine": Vector3(4.0, -6.0, 0.0),
		&"Chest": Vector3(0.0, -12.0, 0.0),
		&"UpperChest": Vector3(0.0, -12.0, 0.0),
		&"Neck": Vector3(0.0, -14.0, 0.0),
		&"Head": Vector3(0.0, -20.0, 0.0),
		&"RightShoulder": Vector3(0.0, -10.0, 0.0),
		&"RightUpperArm": Vector3(-76.0, 0.0, 14.0),
		&"RightLowerArm": Vector3(130.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(40.0, 0.0, -16.0),
		&"LeftLowerArm": Vector3(120.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(10.0, 0.0, -4.0),
		&"RightUpperLeg": Vector3(-14.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-20.0, 0.0, 0.0),
		&"RightFoot": Vector3(34.0, 0.0, -5.0),
	})
	return _mp(g, windup, strike)


static func _knee() -> MovePoses:
	var g := hold()
	var windup := merge(g, {
		&"Spine": Vector3(-2.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(-24.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-50.0, 0.0, 0.0),
		&"RightFoot": Vector3(10.0, 0.0, -5.0),
	})
	# The hips drive forward into the knee while the hands pull the victim's head down.
	var strike := merge(g, {
		HIPS_NUDGE: Vector3(0.0, 0.0, -0.08),
		&"Spine": Vector3(6.0, 0.0, 0.0),
		&"Chest": Vector3(-6.0, 0.0, 0.0),
		&"Neck": Vector3(6.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(52.0, -14.0, -12.0),
		&"LeftLowerArm": Vector3(76.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(52.0, 14.0, 12.0),
		&"RightLowerArm": Vector3(76.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(113.5, 0.0, 2.0),
		&"RightLowerLeg": Vector3(-108.0, 0.0, 0.0),
		&"RightFoot": Vector3(-30.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(6.0, 0.0, -3.0),
		&"LeftLowerLeg": Vector3(-14.0, 0.0, 0.0),
		&"LeftFoot": Vector3(8.0, 0.0, 3.0),
	})
	return _mp(g, windup, strike)


static func _throw() -> MovePoses:
	var g := hold()
	var windup := merge(g, {
		&"Hips": Vector3(0.0, -20.0, 0.0),
		&"Spine": Vector3(0.0, -10.0, 0.0),
		&"Neck": Vector3(4.0, 20.0, 0.0),
		&"Head": Vector3(2.0, 10.0, 0.0),
		&"LeftUpperArm": Vector3(50.0, -20.0, -14.0),
		&"LeftLowerArm": Vector3(90.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(40.0, 0.0, 20.0),
		&"RightLowerArm": Vector3(100.0, 0.0, 0.0),
	})
	var strike := merge(g, {
		&"Hips": Vector3(0.0, 30.0, 0.0),
		&"Spine": Vector3(-10.0, 10.0, 0.0),
		&"Chest": Vector3(-6.0, 6.0, 0.0),
		&"Neck": Vector3(10.0, -24.0, 0.0),
		&"Head": Vector3(4.0, -16.0, 0.0),
		&"LeftUpperArm": Vector3(100.0, 10.0, -10.0),
		&"LeftLowerArm": Vector3(20.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(110.0, 10.0, 10.0),
		&"RightLowerArm": Vector3(20.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(30.0, -30.0, -4.0),
		&"LeftLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(-16.0, -30.0, 5.0),
		&"RightLowerLeg": Vector3(-14.0, 0.0, 0.0),
		&"RightFoot": Vector3(36.0, 0.0, -5.0),
		&"RightToes": Vector3(30.0, 0.0, 0.0),
	})
	return _mp(g, windup, strike)


static func _stomp() -> MovePoses:
	var g := guard()
	var windup := merge(g, {
		&"Spine": Vector3(-12.0, 0.0, 0.0),
		&"Chest": Vector3(-6.0, 0.0, 0.0),
		&"Neck": Vector3(-6.0, 0.0, 0.0),
		&"Head": Vector3(-8.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(84.0, 0.0, 2.0),
		&"RightLowerLeg": Vector3(-96.0, 0.0, 0.0),
		&"RightFoot": Vector3(10.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(10.0, 0.0, -3.0),
		&"LeftLowerLeg": Vector3(-20.0, 0.0, 0.0),
		&"LeftFoot": Vector3(10.0, 0.0, 3.0),
		&"LeftUpperArm": Vector3(30.0, 0.0, -30.0),
		&"RightUpperArm": Vector3(20.0, 0.0, 30.0),
	})
	var strike := merge(g, {
		&"Spine": Vector3(-16.0, 0.0, 0.0),
		&"Chest": Vector3(-8.0, 0.0, 0.0),
		&"Neck": Vector3(-4.0, 0.0, 0.0),
		&"Head": Vector3(-10.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(38.0, 0.0, 2.0),
		&"RightLowerLeg": Vector3(-6.0, 0.0, 0.0),
		&"RightFoot": Vector3(-32.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(30.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-56.0, 0.0, 0.0),
		&"LeftFoot": Vector3(26.0, 0.0, 4.0),
		&"LeftUpperArm": Vector3(20.0, 0.0, -36.0),
		&"RightUpperArm": Vector3(10.0, 0.0, 36.0),
		&"RightLowerArm": Vector3(90.0, 0.0, 0.0),
	})
	return _mp(g, windup, strike)


## Forehand pipe swing, right to left: the arm sweeps across the front, the weapon level.
## At contact the pipe comes in from the right and its tip meets the side of the target's
## head (it never passes through the head).
static func _pipe_swing_1() -> MovePoses:
	var g := weapon_guard()
	var windup := merge(g, {
		&"Hips": Vector3(0.0, -24.0, 0.0),
		&"Chest": Vector3(-3.0, -14.0, 0.0),
		&"Neck": Vector3(4.0, 20.0, 0.0),
		&"Head": Vector3(2.0, 18.0, 0.0),
		&"RightUpperArm": Vector3(20.0, 0.0, 88.0),
		&"RightLowerArm": Vector3(60.0, 0.0, 0.0),
		# The pipe cocked back behind the right shoulder.
		&"RightHand": Vector3(12.0, -157.0, -20.0),
	})
	var strike := merge(g, {
		&"Hips": Vector3(0.0, 10.0, 0.0),
		&"Chest": Vector3(-4.0, 6.0, 0.0),
		&"Neck": Vector3(4.0, -8.0, 0.0),
		&"Head": Vector3(2.0, -8.0, 0.0),
		&"RightShoulder": Vector3(0.0, -12.0, 0.0),
		&"RightUpperArm": Vector3(46.0, -50.0, 3.0),
		&"RightLowerArm": Vector3(94.5, 0.0, 0.0),
		&"RightHand": Vector3(-23.0, 81.0, 19.0),
	})
	var follow := merge(strike, {
		&"Hips": Vector3(0.0, 24.0, 0.0),
		&"RightUpperArm": Vector3(80.0, 30.0, 0.0),
		&"RightLowerArm": Vector3(40.0, 0.0, 0.0),
	})
	var m := _mp(g, windup, strike)
	m.follow = follow
	return m


## Backhand pipe swing, left to right: the arm reaches across the body and the pipe passes
## the left side of the target's head.
static func _pipe_swing_2() -> MovePoses:
	var g := weapon_guard()
	var windup := merge(g, {
		&"Hips": Vector3(0.0, 20.0, 0.0),
		&"Chest": Vector3(-3.0, 12.0, 0.0),
		&"Neck": Vector3(4.0, -16.0, 0.0),
		&"Head": Vector3(2.0, -16.0, 0.0),
		&"RightUpperArm": Vector3(70.0, 70.0, 0.0),
		&"RightLowerArm": Vector3(100.0, 0.0, 0.0),
		&"RightHand": Vector3(0.0, -90.0, 0.0),
	})
	var strike := merge(g, {
		&"Hips": Vector3(0.0, -10.0, 0.0),
		&"Chest": Vector3(-4.0, 6.0, 0.0),
		&"UpperChest": Vector3(0.0, 12.0, 0.0),
		&"Neck": Vector3(4.0, 8.0, 0.0),
		&"Head": Vector3(2.0, 8.0, 0.0),
		&"RightShoulder": Vector3(0.0, 37.5, 0.0),
		&"RightUpperArm": Vector3(93.0, 21.5, -1.0),
		&"RightLowerArm": Vector3(9.0, 0.0, 0.0),
		&"RightHand": Vector3(-4.0, -69.0, 1.0),
	})
	var follow := merge(strike, {
		&"Hips": Vector3(0.0, -24.0, 0.0),
		&"RightUpperArm": Vector3(60.0, -40.0, 20.0),
		&"RightLowerArm": Vector3(30.0, 0.0, 0.0),
	})
	var m := _mp(g, windup, strike)
	m.follow = follow
	return m


## Overhead pipe smash: the pipe chops down past the right side of the target's head onto
## its shoulder (the strike envelope keeps WeaponTip at or below 1.7 m, under the crown).
static func _pipe_swing_3() -> MovePoses:
	var g := weapon_guard()
	var windup := merge(g, {
		&"Spine": Vector3(6.0, 0.0, 0.0),
		&"Chest": Vector3(4.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(170.0, 0.0, 10.0),
		&"RightLowerArm": Vector3(70.0, 0.0, 0.0),
		&"RightHand": Vector3(0.0, 180.0, 0.0),
		&"LeftUpperArm": Vector3(60.0, 0.0, -20.0),
		&"LeftLowerArm": Vector3(80.0, 0.0, 0.0),
	})
	var strike := merge(g, {
		&"Spine": Vector3(-16.0, 6.0, 0.0),
		&"Chest": Vector3(-8.0, 4.0, 0.0),
		&"Neck": Vector3(14.0, -6.0, 0.0),
		&"Head": Vector3(8.0, -4.0, 0.0),
		&"RightShoulder": Vector3(0.0, -5.0, 0.0),
		&"RightUpperArm": Vector3(180.0, -11.0, 12.0),
		&"RightLowerArm": Vector3(26.0, 0.0, 0.0),
		&"RightHand": Vector3(35.0, 165.5, -2.0),
		&"LeftUpperArm": Vector3(30.0, 0.0, -24.0),
		&"LeftLowerArm": Vector3(110.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(30.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-36.0, 0.0, 0.0),
		&"LeftFoot": Vector3(6.0, 0.0, 4.0),
	})
	var follow := merge(strike, {
		&"RightUpperArm": Vector3(40.0, -10.0, 10.0),
		&"RightHand": Vector3(-40.0, 0.0, 0.0),
	})
	var m := _mp(g, windup, strike)
	m.follow = follow
	return m


## Overhand weapon throw with the right arm.
static func _weapon_throw() -> MovePoses:
	var g := weapon_guard()
	var windup := merge(g, {
		&"Hips": Vector3(0.0, -20.0, 0.0),
		&"Spine": Vector3(8.0, -6.0, 0.0),
		&"Neck": Vector3(-4.0, 20.0, 0.0),
		&"Head": Vector3(-2.0, 6.0, 0.0),
		&"RightUpperArm": Vector3(150.0, 0.0, 20.0),
		&"RightLowerArm": Vector3(100.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(80.0, 0.0, -10.0),
		&"LeftLowerArm": Vector3(20.0, 0.0, 0.0),
	})
	var strike := merge(g, {
		&"Hips": Vector3(0.0, 16.0, 0.0),
		&"Spine": Vector3(-12.0, 8.0, 0.0),
		&"Chest": Vector3(-6.0, 6.0, 0.0),
		&"Neck": Vector3(12.0, -20.0, 0.0),
		&"Head": Vector3(6.0, -6.0, 0.0),
		&"RightUpperArm": Vector3(100.0, -10.0, 4.0),
		&"RightLowerArm": Vector3(10.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(20.0, 0.0, -30.0),
		&"LeftLowerArm": Vector3(100.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(-14.0, -16.0, 5.0),
		&"RightFoot": Vector3(36.0, 0.0, -5.0),
		&"RightToes": Vector3(30.0, 0.0, 0.0),
	})
	return _mp(g, windup, strike)
