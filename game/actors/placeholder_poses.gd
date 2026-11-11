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
## Stances: guard() is the boxer stance and relaxed() the player's (stance_pose()). Pose
## builders that take a `base` lay their changes over that stance pose, so the same walk,
## crouch, dodge or hit reaction keeps each stance's arms. Move recipes are authored on the
## boxer guard; move_poses() adapts them to the relaxed stance.
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
	## Optional second wind-up key at windup_hold_at x startup (a held telegraph, the enemy
	## attacks of Milestone 3): the wind-up pose, plus `windup_hold` (a delta added to it, empty
	## = none), held until the strike drives in over the rest of the startup. Negative (the
	## default) = no hold: the body creeps from the wind-up into the strike. Enemy moves use
	## windup_at 0.4-0.6 and windup_hold_at about 0.8. Must lie after windup_at.
	var windup_hold_at: float = -1.0
	var windup_hold: Dictionary[StringName, Vector3] = {}
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
		m.windup_hold_at = windup_hold_at
		m.windup_hold = _mirror_pose(windup_hold, keep_legs)
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

const ARM_BONES: Array[StringName] = [
	&"LeftShoulder", &"LeftUpperArm", &"LeftLowerArm", &"LeftHand",
	&"RightShoulder", &"RightUpperArm", &"RightLowerArm", &"RightHand",
]


# --- Stances ---------------------------------------------------------------------------

## HumanoidRig.stance values: the pose a body stands and walks in, starts every move from
## and returns to (stance_pose()).
## Boxer guard, fists up at the chin: enemies and dummies (a raised guard reads as a threat
## from the player's view).
const STANCE_BOXER := &"boxer"
## Loose, low arms until a strike (the player: the first-person view stays clear).
const STANCE_RELAXED := &"relaxed"

## Moves whose start and end pose is not the stance itself: knees and throws run in the
## clinch (hold()), pipe moves in the weapon carry (weapon_guard() or
## relaxed_weapon_guard()).
const _HOLD_MOVES: Array[StringName] = [&"knee", &"throw"]
const _WEAPON_MOVES: Array[StringName] = [
	&"pipe_swing_1", &"pipe_swing_2", &"pipe_swing_3", &"weapon_throw",
	&"chain_swing_1", &"chain_swing_2", &"chain_swing_3", &"chain_throw",
]
## Air moves start and end in the air guard (_air_guard()): legs tucked.
const _AIR_MOVES: Array[StringName] = [&"flying_kick", &"spin_kick"]
## Code-applied impacts have no motion of their own: every key is the stance.
const _STILL_MOVES: Array[StringName] = [&"impact_body_knockdown", &"impact_body_stagger"]
## In the relaxed stance, the arm a move does not strike with (left or right) stays low and
## loose (relaxed_ready_arm()) instead of guarding the chin. Moves left out (the flurry, the
## shove, kicks, grabs, the weapon throw) keep both arms as authored.
const _FREE_ARM: Dictionary[StringName, StringName] = {
	&"jab_1": &"Right", &"jab_2": &"Left", &"hook": &"Right", &"uppercut": &"Left",
	&"haymaker": &"Left", &"back_elbow": &"Left", &"spinning_backfist": &"Left", &"pipe_swing_1": &"Left",
	&"pipe_swing_2": &"Left", &"pipe_swing_3": &"Left",
	&"chain_swing_1": &"Left", &"chain_swing_2": &"Left", &"chain_swing_3": &"Left",
}
## Moves whose wind-up keeps its authored free arm in the relaxed stance: the haymaker's
## wind-up is the charge pose held while P is held, and its lead hand reaching out on the
## left (clear of the view center) is the read of the charge.
const _WINDUP_KEEPS_FREE_ARM: Array[StringName] = [&"haymaker"]
const _HIPS_ONLY: Array[StringName] = [&"Hips"]


## The pose of `stance` (STANCE_BOXER or STANCE_RELAXED; anything else is the boxer guard).
static func stance_pose(stance: StringName) -> Dictionary[StringName, Vector3]:
	return relaxed() if stance == STANCE_RELAXED else guard()


## Boxer stance: left foot forward, knees soft, fists up at the chin (enemies and dummies).
## The gloves sit at chin height a hand's width in front of it, either side of the face
## (the lead a little further out), the forearms angled in from elbows held low and a
## little wide: "fists up" from 2-10 m and side on, while from the player's throat-height
## lens facing it at sparring range the face and cap show whole above and between the
## gloves (they used to stand out at the lens's eye line and fill most of the view).
## Authored with two-bone IK for gloves 0.26 m in front of the body, the forearms clear of
## the chest. The player's own "dukes up" is the block guard (block_guard_arms()).
static func guard() -> Dictionary[StringName, Vector3]:
	return {
		&"Spine": Vector3(-3.0, 0.0, 0.0),
		&"Chest": Vector3(-3.0, 0.0, 0.0),
		&"Neck": Vector3(4.0, 0.0, 0.0),
		&"Head": Vector3(2.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(43.5, -22.0, -13.5),
		&"LeftLowerArm": Vector3(130.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(40.0, 22.5, 13.0),
		&"RightLowerArm": Vector3(134.5, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(16.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-24.0, 0.0, 0.0),
		&"LeftFoot": Vector3(8.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-6.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-16.0, 0.0, 0.0),
		&"RightFoot": Vector3(22.0, 0.0, -5.0),
	}


## Relaxed ("Bruce Lee") stance: the boxer guard's body and footing (the torso a little
## forward, the lead foot forward) on soft knees, the rear heel up so the weight sits on
## the balls of the feet; the arms hang loose, the lead hand a little forward at belt
## height and the rear hand by the hip. Seen from the first-person lens, nothing of the
## arms shows while looking ahead.
## The hips, torso and head match the guard's (the hips about 4 mm lower), so strike
## poses, which are authored on the guard's body, move EyePoint (and the first-person
## camera riding it) no more in this stance than in the guard.
static func relaxed() -> Dictionary[StringName, Vector3]:
	return merge(guard(), {
		&"LeftUpperArm": Vector3(14.0, -6.0, -6.0),
		&"LeftLowerArm": Vector3(36.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(2.0, 6.0, 8.0),
		&"RightLowerArm": Vector3(22.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(17.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-27.0, 0.0, 0.0),
		&"LeftFoot": Vector3(10.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(0.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"RightFoot": Vector3(14.0, 0.0, -5.0),
		&"RightToes": Vector3(16.0, 0.0, 0.0),
	})


## The relaxed stance's arm that does not strike (`side` &"Left" or &"Right"): low and
## loose by the solar plexus, below the first-person view.
static func relaxed_ready_arm(side: StringName) -> Dictionary[StringName, Vector3]:
	var right: Dictionary[StringName, Vector3] = {
		&"RightShoulder": Vector3.ZERO,
		&"RightUpperArm": Vector3(20.0, 8.0, 10.0),
		&"RightLowerArm": Vector3(70.0, 0.0, 0.0),
		&"RightHand": Vector3.ZERO,
	}
	return right if side == &"Right" else mirror(right)


## Guard holding a pipe: right hand up by the shoulder, the weapon resting back over it.
static func weapon_guard() -> Dictionary[StringName, Vector3]:
	return merge(guard(), {
		&"RightUpperArm": Vector3(30.0, 0.0, 22.0),
		&"RightLowerArm": Vector3(100.0, 0.0, 0.0),
		&"RightHand": Vector3(-10.0, 0.0, 0.0),
	})


## Relaxed stance holding a pipe: carried low in the right hand, angled forward and down.
static func relaxed_weapon_guard() -> Dictionary[StringName, Vector3]:
	return merge(relaxed(), {
		&"RightUpperArm": Vector3(12.0, 0.0, 10.0),
		&"RightLowerArm": Vector3(50.0, 0.0, 0.0),
		&"RightHand": Vector3(-60.0, 0.0, 0.0),
	})


## Clinch (Game-boy, 2026-10-24): bent forward at the waist over a held victim at
## HoldPoint, the hips back and the knees soft, the head over the victim's back looking down
## at it, both fists on its shoulders from elbows held low and wide. Side on it reads as a
## clinch. The bend leans the eyes about 0.12 m forward and 0.07 m down, out over the
## victim; the first-person hold view (Tuning "Grab and weapons" > "Hold view") moves the
## lens back and up from there and pitches it down onto the victim. Clinch moves (knee,
## throw) start here; the knee ends here, the throw in the stance.
static func hold() -> Dictionary[StringName, Vector3]:
	return merge(guard(), {
		HIPS_NUDGE: Vector3(0.0, 0.0, 0.08),
		&"Spine": Vector3(-18.0, 0.0, 0.0),
		&"Chest": Vector3(-10.0, 0.0, 0.0),
		&"UpperChest": Vector3(-6.0, 0.0, 0.0),
		&"Neck": Vector3(16.0, 0.0, 0.0),
		&"Head": Vector3(8.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(60.0, -24.0, -33.5),
		&"LeftLowerArm": Vector3(82.0, 0.0, 0.0),
		&"LeftHand": Vector3(10.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(60.0, 24.0, 33.5),
		&"RightLowerArm": Vector3(82.0, 0.0, 0.0),
		&"RightHand": Vector3(10.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(24.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-32.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(2.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-24.0, 0.0, 0.0),
	})


## Being held: hips pulled back, bent over at the waist, arms hanging, head forced down.
## Authored for a victim whose origin is pinned at the holder's HoldPoint (on the floor
## below it), facing the holder: the head then sits about 0.35 m in front of the holder at
## y 1.24, under the holder's throat-height first-person lens (the hold view pitches down
## onto its back and head), and the holder's fists rest on the victim's shoulders.
static func held() -> Dictionary[StringName, Vector3]:
	return {
		HIPS_NUDGE: Vector3(0.0, 0.0, 0.3),
		&"Spine": Vector3(-30.0, 0.0, 0.0),
		&"Chest": Vector3(-26.0, 0.0, 0.0),
		&"UpperChest": Vector3(-18.0, 0.0, 0.0),
		&"Neck": Vector3(-24.0, 0.0, 0.0),
		&"Head": Vector3(-36.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(18.0, 0.0, -10.0),
		&"LeftLowerArm": Vector3(30.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(14.0, 0.0, 12.0),
		&"RightLowerArm": Vector3(34.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(36.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-42.0, 0.0, 0.0),
		&"LeftFoot": Vector3(16.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(30.0, 0.0, 4.0),
		&"RightLowerLeg": Vector3(-38.0, 0.0, 0.0),
		&"RightFoot": Vector3(18.0, 0.0, -4.0),
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
static func walk_contact(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(base, {
		&"Hips": Vector3(0.0, 4.0, 0.0),
		&"LeftUpperLeg": Vector3(24.0, 0.0, -3.0),
		&"LeftLowerLeg": Vector3(-12.0, 0.0, 0.0),
		&"LeftFoot": Vector3(-6.0, 0.0, 3.0),
		&"RightUpperLeg": Vector3(-18.0, 0.0, 3.0),
		&"RightLowerLeg": Vector3(-20.0, 0.0, 0.0),
		&"RightFoot": Vector3(30.0, 0.0, -3.0),
		&"RightToes": Vector3(10.0, 0.0, 0.0),
	})


## Arm swing added to the relaxed stance's walk contact poses: with the left foot forward
## (`left_foot_forward`) the right arm swings forward and the left back, and the other way.
static func arm_swing(left_foot_forward: bool) -> Dictionary[StringName, Vector3]:
	var swing: Dictionary[StringName, Vector3] = {
		&"LeftUpperArm": Vector3(-10.0, 0.0, 0.0),
		&"LeftLowerArm": Vector3(-6.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(8.0, 0.0, 0.0),
		&"RightLowerArm": Vector3(4.0, 0.0, 0.0),
	}
	return swing if left_foot_forward else mirror(swing)


## Walk passing pose: left leg planted under the body, right knee swinging through.
static func walk_pass(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(base, {
		&"LeftUpperLeg": Vector3(4.0, 0.0, -3.0),
		&"LeftLowerLeg": Vector3(-10.0, 0.0, 0.0),
		&"LeftFoot": Vector3(6.0, 0.0, 3.0),
		&"RightUpperLeg": Vector3(30.0, 0.0, 3.0),
		&"RightLowerLeg": Vector3(-62.0, 0.0, 0.0),
		&"RightFoot": Vector3(20.0, 0.0, -3.0),
	})


## Side-step: feet apart (lead foot out) for walk_right; mirror for walk_left.
static func step_wide(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(base, {
		&"LeftUpperLeg": Vector3(8.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-14.0, 0.0, 0.0),
		&"LeftFoot": Vector3(6.0, 0.0, 6.0),
		&"RightUpperLeg": Vector3(10.0, 0.0, 18.0),
		&"RightLowerLeg": Vector3(-16.0, 0.0, 0.0),
		&"RightFoot": Vector3(6.0, 0.0, -18.0),
	})


## Side-step: trailing foot lifted and closing in.
static func step_close(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(base, {
		&"LeftUpperLeg": Vector3(20.0, 0.0, 4.0),
		&"LeftLowerLeg": Vector3(-40.0, 0.0, 0.0),
		&"LeftFoot": Vector3(18.0, 0.0, -4.0),
		&"RightUpperLeg": Vector3(8.0, 0.0, 2.0),
		&"RightLowerLeg": Vector3(-18.0, 0.0, 0.0),
		&"RightFoot": Vector3(10.0, 0.0, -2.0),
	})


# --- Air ------------------------------------------------------------------------------


static func crouch(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(base, {
		&"Spine": Vector3(-12.0, 0.0, 0.0),
		&"Neck": Vector3(10.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(55.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-90.0, 0.0, 0.0),
		&"LeftFoot": Vector3(35.0, 0.0, 6.0),
		&"RightUpperLeg": Vector3(40.0, 0.0, 6.0),
		&"RightLowerLeg": Vector3(-82.0, 0.0, 0.0),
		&"RightFoot": Vector3(42.0, 0.0, -6.0),
	})


static func jump_takeoff(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(base, {
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


static func jump_tuck(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(base, {
		HIPS_POS: Vector3(0.0, 0.0, 0.0),
		&"Spine": Vector3(-8.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(70.0, 0.0, -6.0),
		&"LeftLowerLeg": Vector3(-100.0, 0.0, 0.0),
		&"LeftFoot": Vector3(-10.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(45.0, 0.0, 6.0),
		&"RightLowerLeg": Vector3(-95.0, 0.0, 0.0),
		&"RightFoot": Vector3(-15.0, 0.0, 0.0),
	})


static func fall_pose(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(base, {
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


# --- Guard (block) ----------------------------------------------------------------------


## The held guard ("dukes up"): `base` (a stance pose: its legs and torso) with
## block_guard_arms(). &"block" holds it (the held block, B with no stick); in the relaxed
## stance it is the only "dukes up" image.
static func block_guard(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(base, block_guard_arms())


## A blocked hit's push-back in the guard (&"block_hit"): the hips driven back, the torso
## rocked back over a deeper rear knee, the chin tucked, and the guard jammed in: the
## forearms fold back and the elbows pull in, so from the first-person lens both fists
## jolt toward the view center and down while the body slides back. Side on, the torso
## rocks back behind the fists.
static func block_hit(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return add(block_guard(base), {
		HIPS_NUDGE: Vector3(0.0, 0.0, 0.05),
		&"Spine": Vector3(6.0, 0.0, 0.0),
		&"Chest": Vector3(3.0, 0.0, 0.0),
		&"Neck": Vector3(-6.0, 0.0, 0.0),
		&"Head": Vector3(-4.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(-8.0, 0.0, 9.0),
		&"LeftLowerArm": Vector3(5.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(-8.0, 0.0, -9.0),
		&"RightLowerArm": Vector3(5.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(-4.0, 0.0, 0.0),
		&"LeftLowerLeg": Vector3(4.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(8.0, 0.0, 0.0),
		&"RightLowerLeg": Vector3(-14.0, 0.0, 0.0),
		&"RightFoot": Vector3(6.0, 0.0, 0.0),
	})


## A broken guard (&"guard_break"), first key: the blow forces the guard open, the elbows
## knocked up and out so from the first-person lens both fists swing out toward the upper
## corners of the view while the head starts to snap back.
static func guard_break_open(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return add(block_guard(base), {
		&"Spine": Vector3(4.0, 0.0, 0.0),
		&"Neck": Vector3(3.0, 0.0, 0.0),
		&"Head": Vector3(4.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(10.0, 0.0, -14.0),
		&"LeftLowerArm": Vector3(-14.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(10.0, 0.0, 14.0),
		&"RightLowerArm": Vector3(-14.0, 0.0, 0.0),
	})


## A broken guard, second key: the arms knocked apart, flung up and out to the sides, the
## head and torso snapped back and the rear foot stepping back. From the first-person lens
## the fists fly out of the upper corners of the view.
static func guard_break_a(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(base, {
		&"Spine": Vector3(12.0, 0.0, 0.0),
		&"Chest": Vector3(8.0, 0.0, 0.0),
		&"Neck": Vector3(8.0, 0.0, 0.0),
		&"Head": Vector3(10.0, 0.0, 0.0),
		&"LeftShoulder": Vector3(0.0, 10.0, -12.0),
		&"LeftUpperArm": Vector3(62.0, 0.0, -78.0),
		&"LeftLowerArm": Vector3(34.0, 0.0, 0.0),
		&"LeftHand": Vector3(-20.0, 0.0, 0.0),
		&"RightShoulder": Vector3(0.0, -10.0, 12.0),
		&"RightUpperArm": Vector3(62.0, 0.0, 78.0),
		&"RightLowerArm": Vector3(34.0, 0.0, 0.0),
		&"RightHand": Vector3(-20.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(24.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-12.0, 0.0, 0.0),
		&"LeftFoot": Vector3(10.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-24.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"RightFoot": Vector3(28.0, 0.0, -5.0),
	})


## A broken guard, third key: reeling, the arms hanging wide and low, the weight over the
## rear foot (then the stagger recovers to the stance).
static func guard_break_b(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(guard_break_a(base), {
		&"Spine": Vector3(6.0, 0.0, 0.0),
		&"Chest": Vector3(3.0, 0.0, 0.0),
		&"Neck": Vector3(2.0, 0.0, 0.0),
		&"Head": Vector3(4.0, 0.0, 0.0),
		&"LeftShoulder": Vector3.ZERO,
		&"LeftUpperArm": Vector3(22.0, 0.0, -42.0),
		&"LeftLowerArm": Vector3(30.0, 0.0, 0.0),
		&"LeftHand": Vector3.ZERO,
		&"RightShoulder": Vector3.ZERO,
		&"RightUpperArm": Vector3(18.0, 0.0, 44.0),
		&"RightLowerArm": Vector3(34.0, 0.0, 0.0),
		&"RightHand": Vector3.ZERO,
		&"LeftUpperLeg": Vector3(-8.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-36.0, 0.0, 0.0),
		&"LeftFoot": Vector3(26.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-14.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-22.0, 0.0, 0.0),
		&"RightFoot": Vector3(28.0, 0.0, -5.0),
	})


## An attack stopped by a guard (&"recoil"): the striking (right) arm knocked back and
## out, its shoulder thrown back so the torso twists away and the head jerks back; the
## other arm keeps the stance's, turned back against the twist so it holds its side (the
## boxer's lead glove would otherwise swing in front of its face for the whole punish
## window). Short: the attacker's punish window.
static func recoil(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	var hips_yaw := -8.0
	var spine_yaw := -6.0
	var chest_yaw := -4.0
	var other_arm: Vector3 = base.get(&"LeftUpperArm", Vector3.ZERO)
	return merge(base, {
		HIPS_NUDGE: Vector3(0.0, 0.0, 0.03),
		&"Hips": Vector3(0.0, hips_yaw, 0.0),
		&"Spine": Vector3(6.0, spine_yaw, 0.0),
		&"Chest": Vector3(3.0, chest_yaw, 0.0),
		&"LeftUpperArm": other_arm - Vector3(0.0, hips_yaw + spine_yaw + chest_yaw, 0.0),
		&"Neck": Vector3(6.0, 8.0, 0.0),
		&"Head": Vector3(6.0, 8.0, 0.0),
		&"RightShoulder": Vector3(0.0, -8.0, 8.0),
		&"RightUpperArm": Vector3(44.0, -6.0, 56.0),
		&"RightLowerArm": Vector3(112.0, 0.0, 0.0),
		&"RightHand": Vector3(-24.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(12.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-18.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(-12.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-26.0, 0.0, 0.0),
		&"RightFoot": Vector3(30.0, 0.0, -5.0),
	})


## Arms of the held guard: both fists up at about mouth height, 0.36 m ahead of the
## first-person lens and about 34 degrees either side of the view center, whole inside the
## upper third of the view (14 degrees up); the forearms rise to them from elbows held low
## and wide, outside the view's lower corners, so no forearm comes within 0.3 m of the lens
## and the arms fill about a quarter of the view, framing whoever stands ahead. The
## shoulders roll forward and up a little, like a shell. From the side the fists stand in
## front of the face, the elbows bent square.
## Authored with two-bone IK on the stance torso (guard()'s spine, chest, neck and head,
## which relaxed() shares) for the lens at EyePoint + FirstPersonCamera.lens_offset() with
## the shipped Tuning offsets. Mirrored for the right arm.
static func block_guard_arms() -> Dictionary[StringName, Vector3]:
	var left: Dictionary[StringName, Vector3] = {
		&"LeftShoulder": Vector3(0.0, -30.0, -10.0),
		&"LeftUpperArm": Vector3(46.5, 6.0, -53.0),
		&"LeftLowerArm": Vector3(90.0, 0.0, 0.0),
		&"LeftHand": Vector3.ZERO,
	}
	return merge(left, mirror(left))


# --- Dodges (right / back / forward; dodge_left mirrors dodge_right) --------------------
# Every dodge keeps the stance's arms: the backstep (B + back) and the forward step no
# longer cover up, since the held block (B with no stick) is the "dukes up" image now.


static func dodge_right(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(crouch(base), {
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


## Backstep (B + back): the stance torso stays up, the rear leg folds under as the weight
## shifts back.
static func dodge_back(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(base, {
		&"LeftUpperLeg": Vector3(30.0, 0.0, -5.0),
		&"LeftLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"LeftFoot": Vector3(0.0, 0.0, 5.0),
		&"RightUpperLeg": Vector3(20.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-80.0, 0.0, 0.0),
		&"RightFoot": Vector3(60.0, 0.0, -5.0),
	})


## Lunging in (B + forward): the lead knee deep, the rear leg trailing.
static func dodge_forward(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(base, {
		&"LeftUpperLeg": Vector3(70.0, 0.0, -5.0),
		&"LeftLowerLeg": Vector3(-80.0, 0.0, 0.0),
		&"LeftFoot": Vector3(10.0, 0.0, 5.0),
		&"RightUpperLeg": Vector3(0.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-60.0, 0.0, 0.0),
		&"RightFoot": Vector3(60.0, 0.0, -5.0),
	})


# --- Grab and pickup ------------------------------------------------------------------


static func grab_reach(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(base, {
		&"Spine": Vector3(-5.0, 0.0, 0.0),
		&"Chest": Vector3(-2.0, 0.0, 0.0),
		&"Neck": Vector3(5.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(84.0, -12.0, -10.0),
		&"LeftLowerArm": Vector3(20.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(84.0, 12.0, 10.0),
		&"RightLowerArm": Vector3(20.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(28.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"LeftFoot": Vector3(2.0, 0.0, 4.0),
	})


static func pickup_reach(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(crouch(base), {
		&"Spine": Vector3(-30.0, 0.0, 0.0),
		&"Chest": Vector3(-14.0, 0.0, 0.0),
		&"Neck": Vector3(26.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(60.0, 0.0, 10.0),
		&"RightLowerArm": Vector3(10.0, 0.0, 0.0),
	})


# --- Hit reactions ---------------------------------------------------------------------


## Struck in the face: head and shoulders snap back.
static func flinch_head_front(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return add(base, {
		&"Spine": Vector3(6.0, 0.0, 0.0),
		&"Chest": Vector3(6.0, 0.0, 0.0),
		&"Neck": Vector3(16.0, 0.0, 0.0),
		&"Head": Vector3(18.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(-14.0, 0.0, -8.0),
		&"RightUpperArm": Vector3(-14.0, 0.0, 8.0),
	})


## Head snaps sideways toward the victim's own left (`to_left`, the blow came from its
## right) or right.
static func flinch_head_side(base: Dictionary[StringName, Vector3],
		to_left: bool) -> Dictionary[StringName, Vector3]:
	var delta: Dictionary[StringName, Vector3] = {
		&"Chest": Vector3(0.0, 8.0, 6.0),
		&"Neck": Vector3(4.0, 20.0, 14.0),
		&"Head": Vector3(4.0, 24.0, 14.0),
		&"LeftUpperArm": Vector3(-10.0, 0.0, -14.0),
		&"RightUpperArm": Vector3(-6.0, 0.0, 8.0),
	}
	return add(base, delta if to_left else mirror(delta))


static func flinch_gut(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return add(base, {
		HIPS_NUDGE: Vector3(0.0, 0.0, 0.04),
		&"Spine": Vector3(-18.0, 0.0, 0.0),
		&"Chest": Vector3(-14.0, 0.0, 0.0),
		&"Neck": Vector3(-6.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(-10.0, 0.0, 6.0),
		&"LeftLowerArm": Vector3(10.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(-10.0, 0.0, -6.0),
		&"RightLowerArm": Vector3(10.0, 0.0, 0.0),
	})


static func flinch_legs(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(add(base, {
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


## Stumbling backward: torso thrown back, the guard broken open, one foot stepping back. The upper arms
## swing out to about 40 degrees off the body (then settle to about 28) with both elbows folded to about
## 90-110 degrees and the forearms forward and raised, so the fists stay about 0.3 m in front of the hips
## like the guard's (M4, the lead's call 24: they were straight arms flung out 75 degrees, which on the
## skinned Punk, whose rig is bound in an A-pose, read as the rig showing its bind pose, a T, for 0.4 s
## after every third knee, on a grab release and in a long fight; stagger_right got the same fix in M3).
static func stagger_back_a(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(base, {
		&"Spine": Vector3(14.0, 0.0, 0.0),
		&"Chest": Vector3(10.0, 0.0, 0.0),
		&"Neck": Vector3(10.0, 0.0, 0.0),
		&"Head": Vector3(12.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(22.0, 0.0, -42.0),
		&"LeftLowerArm": Vector3(95.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(18.0, 0.0, 44.0),
		&"RightLowerArm": Vector3(92.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(26.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-10.0, 0.0, 0.0),
		&"LeftFoot": Vector3(10.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-28.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"RightFoot": Vector3(30.0, 0.0, -5.0),
	})


static func stagger_back_b(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(stagger_back_a(base), {
		&"Spine": Vector3(4.0, 0.0, 0.0),
		&"Chest": Vector3(2.0, 0.0, 0.0),
		&"Neck": Vector3(2.0, 0.0, 0.0),
		&"Head": Vector3(4.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(12.0, 0.0, -28.0),
		&"LeftLowerArm": Vector3(108.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(8.0, 0.0, 30.0),
		&"RightLowerArm": Vector3(105.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(-14.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-40.0, 0.0, 0.0),
		&"LeftFoot": Vector3(30.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(-16.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-20.0, 0.0, 0.0),
		&"RightFoot": Vector3(30.0, 0.0, -5.0),
	})


## Stumbling toward the victim's own right; stagger_left mirrors it. The trunk rocks over and
## both arms fling out, bent: the far (left) arm's elbow out to the side and folded, the
## forearm raised beside the shoulder, so the fist stays within about 0.6 m of the trunk and
## goes no more than about 0.1 m in front of the hips (it was a straight arm thrown out
## about 70 degrees, a rope in the first-person view, and then a forearm folded forward whose
## fist swung at the attacker's lens; the partial ragdoll's arm influence cannot calm what
## the animation poses).
static func stagger_right_a(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(base, {
		&"Hips": Vector3(0.0, -10.0, 0.0),
		&"Spine": Vector3(0.0, 0.0, -16.0),
		&"Chest": Vector3(0.0, 0.0, -8.0),
		&"Neck": Vector3(0.0, 0.0, -12.0),
		&"Head": Vector3(0.0, 0.0, -10.0),
		&"LeftUpperArm": Vector3(-10.0, 85.0, -25.0),
		&"LeftLowerArm": Vector3(130.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(20.0, 0.0, 40.0),
		&"RightLowerArm": Vector3(60.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(10.0, 0.0, 10.0),
		&"LeftLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"LeftFoot": Vector3(14.0, 0.0, -10.0),
		&"RightUpperLeg": Vector3(14.0, 0.0, 24.0),
		&"RightLowerLeg": Vector3(-20.0, 0.0, 0.0),
		&"RightFoot": Vector3(6.0, 0.0, -24.0),
	})


static func stagger_right_b(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(stagger_right_a(base), {
		&"Spine": Vector3(-4.0, 0.0, -6.0),
		&"Chest": Vector3(-2.0, 0.0, -2.0),
		&"Neck": Vector3(0.0, 0.0, -4.0),
		&"Head": Vector3(0.0, 0.0, -2.0),
		&"LeftUpperArm": Vector3(-4.0, 85.0, -13.0),
		&"LeftLowerArm": Vector3(135.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(30.0, 0.0, 30.0),
		&"LeftUpperLeg": Vector3(10.0, 0.0, 16.0),
		&"LeftLowerLeg": Vector3(-20.0, 0.0, 0.0),
		&"LeftFoot": Vector3(8.0, 0.0, -16.0),
		&"RightUpperLeg": Vector3(10.0, 0.0, 14.0),
		&"RightLowerLeg": Vector3(-24.0, 0.0, 0.0),
		&"RightFoot": Vector3(14.0, 0.0, -14.0),
	})


## Stumbling forward (hit from behind): pitched forward, arms flung back.
static func stagger_forward_a(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(base, {
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


static func stagger_forward_b(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(stagger_forward_a(base), {
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
static func buckle(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(base, {
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


static func getup_crouch(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(crouch(base), {
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


## Key poses for a move id from docs/ARCHITECTURE.md in `stance`, or null if there is no
## recipe. Recipes are authored on the boxer guard. In the relaxed stance the move starts
## and ends in relaxed() (or the relaxed weapon carry), and its free arm (_FREE_ARM) stays
## low and loose (relaxed_ready_arm()) through the swing. The striking limb and the body
## keep their authored angles, so every strike reaches the same spot in either stance.
static func move_poses(id: StringName, stance: StringName = STANCE_BOXER) -> MovePoses:
	var relaxed_stance := stance == STANCE_RELAXED
	# Key poses build on the boxer guard's body and legs with the stance's arms: an arm a
	# key pose leaves alone hangs loose in the relaxed stance.
	var g := guard()
	var wg := weapon_guard()
	if relaxed_stance:
		g = merge(g, only(relaxed(), ARM_BONES))
		wg = merge(wg, only(relaxed_weapon_guard(), ARM_BONES))
	var m := _recipe(id, g, wg)
	if m != null and relaxed_stance:
		_relax(m, id)
	return m


## Fallback straight punch with the right fist (mirror it for the left).
static func generic_punch(stance: StringName = STANCE_BOXER) -> MovePoses:
	return move_poses(&"jab_2", stance)


## Fallback straight kick with the right foot (mirror it for the left).
static func generic_kick(stance: StringName = STANCE_BOXER) -> MovePoses:
	return move_poses(&"front_kick", stance)


## Turn a boxer-authored recipe for move `id` into its relaxed-stance version (see
## move_poses()). Clinch moves (knee, throw) start in hold() in either stance; the knee ends
## there too, the throw in the stance.
static func _relax(m: MovePoses, id: StringName) -> void:
	if _HOLD_MOVES.has(id):
		if id == &"throw":
			m.finish = relaxed()
		return
	var neutral := relaxed()
	if _WEAPON_MOVES.has(id):
		neutral = relaxed_weapon_guard()
	elif _AIR_MOVES.has(id):
		neutral = _air_guard(relaxed())
	m.guard = neutral
	if _STILL_MOVES.has(id):
		m.windup = neutral
		m.strike = neutral
		return
	if not m.finish.is_empty():
		# Spins end a full turn round: keep the turn, take the rest from the stance.
		m.finish = merge(neutral, only(m.finish, _HIPS_ONLY))
	if not _FREE_ARM.has(id):
		return
	var arm := relaxed_ready_arm(_FREE_ARM[id])
	if not _WINDUP_KEEPS_FREE_ARM.has(id):
		m.windup = merge(m.windup, arm)
	m.strike = merge(m.strike, arm)
	if not m.strike_end.is_empty():
		m.strike_end = merge(m.strike_end, arm)
	if not m.follow.is_empty():
		m.follow = merge(m.follow, arm)



## The key poses of move `id` built on `g` (pipe moves on `wg`), or null.
static func _recipe(id: StringName, g: Dictionary[StringName, Vector3],
		wg: Dictionary[StringName, Vector3]) -> MovePoses:
	match id:
		&"jab_1":
			return _jab_1(g, true)
		&"jab_2":
			return _jab_2(g, true)
		&"hook":
			return _hook(g)
		&"uppercut":
			return _uppercut(g)
		&"body_flurry":
			return _body_flurry(g)
		&"shove":
			return _shove(g)
		&"spinning_backfist":
			return _spinning_backfist(g)
		&"front_kick":
			return _front_kick(g)
		&"roundhouse":
			return _roundhouse(g)
		&"spinning_heel":
			return _spinning_heel(g)
		&"stomp_kick":
			return _stomp_kick(g)
		&"push_kick":
			return _push_kick(g)
		&"haymaker":
			return _haymaker(g)
		&"flying_kick":
			return _flying_kick(g)
		&"spin_kick":
			return _spin_kick(g)
		&"back_elbow":
			return _back_elbow(g)
		&"knee":
			return _knee()
		&"throw":
			return _throw(g)
		&"stomp":
			return _stomp(g)
		# The bike chain swings on the pipe's three recipes (WEAPONS, D5): its own timing and hitbox are the move data's.
		&"pipe_swing_1", &"chain_swing_1":
			return _pipe_swing_1(wg)
		&"pipe_swing_2", &"chain_swing_2":
			return _pipe_swing_2(wg)
		&"pipe_swing_3", &"chain_swing_3":
			return _pipe_swing_3(wg)
		&"weapon_throw", &"chain_throw":
			return _weapon_throw(wg)
		&"impact_body_knockdown", &"impact_body_stagger":
			return _mp(g, g, g)
		&"dummy_jab":
			return _dummy_jab(g)
	return PlaceholderEnemyPoses.recipe(id, g, wg)


# Strike poses are tuned so the strike point lands in the "Strike reach" envelope of
# docs/ARCHITECTURE.md (checked by tests/test_humanoid_rig.gd), and so punches come into
# the view of the first-person lens (FirstPersonCamera.lens_offset()).

# The straight punches' corkscrew (Game-boy, 2026-11-02, M4 call 28): over the punch the fist turns about 90 degrees, so it lands
# palm down with the curled fingers toward the ground and the back of the hand up. M3's pose left it standing on its edge, thumb up,
# the fingers curled inward at the other hand. The roll is about the forearm's own long axis, so the fist (the strike point) stays
# where the hits were tuned: it moves 7 mm at most, the 5 mm the strike point sits off that axis. "Down" is as far as the forearm
# allows: it rises 34 and 36 degrees at contact, so the palm lands 34 and 36 degrees from straight down (tests/test_punch_turn.gd).
# The roll is split between the lower arm and the hand, as a real forearm's is, so the skinned wrist does not candy-wrap: a roll all
# in the hand pinched the hero's wrist to 78% of its width (the skin blends lower arm to hand over about 9 cm), this split to 89%.
# The lower arm's roll is nearly the same in the wind-up as in the strike, and the hand's is what turns over between them. Two keys
# that differ by a bend alone slerp as a bend, so the fist keeps the path M3 gave it (a lower arm rolled only at contact sweeps the
# wrist 3-4 cm off it halfway). A lower arm rolled as far at the wind-up as at contact would be better still, but a roll that follows a
# bend past 90 degrees makes the Euler triple jump more than PlaceholderAnims.MAX_STEP_DEG between keys, which subdivides the clip
# and lerps the angles, and the wrist wanders up to 6 cm; 15 degrees at the wind-up and 27 at contact keep the keys M3 had.
# The lower arm takes the smaller part of the turn because the ragdoll's elbow is a hinge and the hand has no body of its own.
# These are the player's moves (jab_1 and jab_2 as _recipe() builds them). The Street Punk's cross and the sparring dummy's jab are
# the same strikes without the turn (A20: no enemy clip changes), so they take the default `turn_fist = false`.
## How far the fist has turned over at contact (degrees about the forearm's axis, from standing on its edge to palm down).
const PUNCH_TURN_DEG := 90.0
## How much of that the lower arm carries at contact (the hand carries the rest).
const PUNCH_TURN_LOWER_DEG := 27.0
## How far the fist is turned in the wind-up key: the fist at the chin stays nearly as it was, and the rest of the turn is the snap
## over the last two frames of the startup. The lower arm carries most of this one (see above), the hand the rest.
const PUNCH_TURN_WINDUP_DEG := 22.5
const PUNCH_TURN_WINDUP_LOWER_DEG := 15.0


## `pose` with `side`'s (&"Left" or &"Right") fist turned `turn_deg` degrees about the forearm's long axis from where `pose` had it,
## toward palm down for a forearm raised forward (the left hand's palm faces inward at rest, the right's the other way: they roll
## opposite ways). The lower arm keeps its elbow bend and is rolled `lower_deg` of that; the hand takes the rest.
static func _turn_fist(pose: Dictionary[StringName, Vector3], side: StringName, turn_deg: float, lower_deg: float) -> Dictionary[StringName, Vector3]:
	var direction := 1.0 if side == &"Right" else -1.0
	var lower := StringName(String(side) + "LowerArm")
	var hand := StringName(String(side) + "Hand")
	var out := pose.duplicate()
	out[lower] = _rolled(pose.get(lower, Vector3.ZERO), direction * lower_deg)
	out[hand] = _rolled(pose.get(hand, Vector3.ZERO), direction * (turn_deg - lower_deg))
	return out


## The Euler angles (degrees, YXZ) of the rotation `euler` followed by a roll of `roll_deg` about the bone's own long axis (y, after
## the bend). A roll that follows a bend is not a lone y angle in YXZ, so the angles are composed and read back, as the equivalent
## triple nearest `euler`: the elbow's bend runs past 90 degrees in a wind-up, where the principal triple flips to (180 - x, y + 180,
## z + 180) and a clip that lerped between the two would wander.
static func _rolled(euler: Vector3, roll_deg: float) -> Vector3:
	var basis := PlaceholderBody.euler_basis(euler) * Basis(Vector3.UP, deg_to_rad(roll_deg))
	var e := basis.get_euler(EULER_ORDER_YXZ)
	var principal := Vector3(rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z))
	var flipped := Vector3(180.0 - principal.x, principal.y + 180.0, principal.z + 180.0)
	var best := principal
	var best_distance := INF
	for candidate: Vector3 in [principal, flipped]:
		var near := Vector3(
				candidate.x + 360.0 * roundf((euler.x - candidate.x) / 360.0),
				candidate.y + 360.0 * roundf((euler.y - candidate.y) / 360.0),
				candidate.z + 360.0 * roundf((euler.z - candidate.z) / 360.0))
		if near.distance_to(euler) < best_distance:
			best_distance = near.distance_to(euler)
			best = near
	return best


## The left jab. `turn_fist` rolls the left fist over the punch (see PUNCH_TURN_DEG): the wind-up key is turned a little
## (PUNCH_TURN_WINDUP_DEG) and the strike key all the way. Off, it is the pose M3 shipped.
static func _jab_1(g: Dictionary[StringName, Vector3], turn_fist: bool = false) -> MovePoses:
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
	if turn_fist:
		windup = _turn_fist(windup, &"Left", PUNCH_TURN_WINDUP_DEG, PUNCH_TURN_WINDUP_LOWER_DEG)
		strike = _turn_fist(strike, &"Left", PUNCH_TURN_DEG, PUNCH_TURN_LOWER_DEG)
	return _mp(g, windup, strike)


## The right cross, the jab's mirror in its turn: the right fist rolls the other way (see _jab_1()).
static func _jab_2(g: Dictionary[StringName, Vector3], turn_fist: bool = false) -> MovePoses:
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
	if turn_fist:
		windup = _turn_fist(windup, &"Right", PUNCH_TURN_WINDUP_DEG, PUNCH_TURN_WINDUP_LOWER_DEG)
		strike = _turn_fist(strike, &"Right", PUNCH_TURN_DEG, PUNCH_TURN_LOWER_DEG)
	return _mp(g, windup, strike)


## The sparring dummy's telegraphed right (dummy_jab, 18 frames of startup): a big,
## readable wind-up (the right fist cocked back by the ear, the elbow up and out, the hips
## and shoulders turned away, the weight on the rear foot) reached at 60% of the startup,
## then jab_2's straight right. From the defender's first-person view the fist draws back
## beside the dummy's head, on the defender's left, before it comes straight in. The lead
## (left) fist holds its side of the chin while the shoulders turn away (left in the
## guard's angles, the turn would carry it in front of the face), so the face and the
## cocked fist both stay in view.
static func _dummy_jab(g: Dictionary[StringName, Vector3]) -> MovePoses:
	var m := _jab_2(g)
	m.windup = merge(g, {
		&"Hips": Vector3(0.0, -20.0, 0.0),
		&"Spine": Vector3(2.0, -10.0, 0.0),
		&"Chest": Vector3(2.0, -8.0, 0.0),
		&"Neck": Vector3(4.0, 18.0, 0.0),
		&"Head": Vector3(2.0, 18.0, 0.0),
		&"LeftUpperArm": Vector3(23.0, 32.5, -22.5),
		&"LeftLowerArm": Vector3(147.0, 0.0, 0.0),
		&"RightShoulder": Vector3(0.0, -12.0, 10.0),
		&"RightUpperArm": Vector3(36.0, -24.0, 62.0),
		&"RightLowerArm": Vector3(128.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(10.0, -10.0, -4.0),
		&"LeftLowerLeg": Vector3(-16.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(0.0, -10.0, 5.0),
		&"RightLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"RightFoot": Vector3(26.0, 0.0, -5.0),
	})
	m.windup_at = 0.6
	return m


static func _hook(g: Dictionary[StringName, Vector3]) -> MovePoses:
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


static func _uppercut(g: Dictionary[StringName, Vector3]) -> MovePoses:
	# A short dip (knees half bent), not a full crouch, so the first-person camera riding
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


static func _body_flurry(g: Dictionary[StringName, Vector3]) -> MovePoses:
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


static func _shove(g: Dictionary[StringName, Vector3]) -> MovePoses:
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


## Spinning backfist (P P · P, Game-boy's second playtest): a full turn to the right on
## the spot, the head leading it (spotting), and the back of the right fist whipping in at
## head height from the right as the turn comes round. Wind-up half way: the back to the
## target, the right fist chambered low across the belly, under the first-person view. At contact
## the hips are 40 degrees short of the full turn, the torso and head twisted the rest of
## the way, so the eyes and the first-person view following them
## (MoveData.camera_spin_follow) face the target and the arm sweeps in from the right edge
## of the view; after it the hips finish the turn while the twist unwinds, the head held on
## the target.
static func _spinning_backfist(g: Dictionary[StringName, Vector3]) -> MovePoses:
	var windup := merge(g, {
		&"Hips": Vector3(0.0, -150.0, 0.0),
		&"Spine": Vector3(-4.0, -10.0, 0.0),
		&"Chest": Vector3(-3.0, -10.0, 0.0),
		&"Neck": Vector3(4.0, -5.0, 0.0),
		&"Head": Vector3(2.0, -5.0, 0.0),
		&"RightUpperArm": Vector3(10.0, 30.0, 10.0),
		&"RightLowerArm": Vector3(95.0, 0.0, 0.0),
	})
	var strike := merge(g, {
		&"Hips": Vector3(0.0, -320.0, 0.0),
		&"Spine": Vector3(-4.0, -8.0, 0.0),
		&"Chest": Vector3(-2.0, -8.0, 0.0),
		&"UpperChest": Vector3(0.0, -8.0, 0.0),
		&"Neck": Vector3(4.0, -8.0, 0.0),
		&"Head": Vector3(2.0, -8.0, 0.0),
		&"RightShoulder": Vector3(0.0, -6.0, 0.0),
		&"RightUpperArm": Vector3(92.0, 10.0, 10.0),
		&"RightLowerArm": Vector3(12.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(40.0, 0.0, -16.0),
		&"LeftLowerArm": Vector3(120.0, 0.0, 0.0),
	})
	var strike_end := merge(strike, {
		&"Hips": Vector3(0.0, -335.0, 0.0),
		&"Spine": Vector3(-4.0, -5.0, 0.0),
		&"Chest": Vector3(-2.0, -5.0, 0.0),
		&"UpperChest": Vector3(0.0, -5.0, 0.0),
		&"Neck": Vector3(4.0, -5.0, 0.0),
		&"Head": Vector3(2.0, -5.0, 0.0),
		&"RightUpperArm": Vector3(92.0, 25.0, 10.0),
	})
	var follow := merge(g, {
		&"Hips": Vector3(0.0, -352.0, 0.0),
		&"Neck": Vector3(4.0, -4.0, 0.0),
		&"Head": Vector3(2.0, -4.0, 0.0),
		&"RightUpperArm": Vector3(20.0, 10.0, 15.0),
		&"RightLowerArm": Vector3(80.0, 0.0, 0.0),
	})
	var m := _mp(g, windup, strike)
	m.strike_end = strike_end
	m.follow = follow
	m.follow_at = 0.4
	m.finish = merge(g, {&"Hips": Vector3(0.0, -360.0, 0.0)})
	return m


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


static func _front_kick(g: Dictionary[StringName, Vector3]) -> MovePoses:
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


static func _push_kick(g: Dictionary[StringName, Vector3]) -> MovePoses:
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


static func _stomp_kick(g: Dictionary[StringName, Vector3]) -> MovePoses:
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


static func _roundhouse(g: Dictionary[StringName, Vector3]) -> MovePoses:
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
static func _spinning_heel(g: Dictionary[StringName, Vector3]) -> MovePoses:
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
	# The head leads the turn (spotting): about half way round at the wind-up key and on
	# the target from the strike on, so the eyes, and the first-person view following them
	# (MoveData.camera_spin_follow), turn at an even rate and land on the target at contact.
	var windup := merge(g, {
		&"Hips": Vector3(0.0, -120.0, 0.0),
		&"Spine": Vector3(-6.0, -10.0, 0.0),
		&"Neck": Vector3(4.0, -25.0, 0.0),
		&"Head": Vector3(2.0, -25.0, 0.0),
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
	# The hips keep turning after contact while the twist unwinds, so the head stays on the
	# target (a full turn in all) until the end.
	var strike_end := strike.duplicate()
	strike_end[&"Hips"] = Vector3(0.0, -300.0, 0.0)
	strike_end[&"Spine"] = Vector3(0.0, -10.0, 6.0)
	strike_end[&"Chest"] = Vector3(0.0, -10.0, 2.0)
	strike_end[&"UpperChest"] = Vector3(0.0, -10.0, 0.0)
	strike_end[&"Neck"] = Vector3(0.0, -15.0, -4.0)
	strike_end[&"Head"] = Vector3(0.0, -15.0, 0.0)
	var follow := merge(g, {
		&"Hips": Vector3(0.0, -335.0, 0.0),
		&"Spine": Vector3(-3.0, -10.0, 0.0),
		&"Neck": Vector3(4.0, -8.0, 0.0),
		&"Head": Vector3(2.0, -7.0, 0.0),
	})
	var m := _mp(g, windup, strike)
	m.strike_end = strike_end
	m.follow = follow
	m.follow_at = 0.4
	m.finish = merge(g, {&"Hips": Vector3(0.0, -360.0, 0.0)})
	return m


## Air guard: `base` with the legs tucked, used as the base pose of air moves.
static func _air_guard(base: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return merge(base, {
		HIPS_POS: Vector3.ZERO,
		&"LeftUpperLeg": Vector3(40.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-70.0, 0.0, 0.0),
		&"LeftFoot": Vector3(-10.0, 0.0, 4.0),
		&"RightUpperLeg": Vector3(30.0, 0.0, 4.0),
		&"RightLowerLeg": Vector3(-60.0, 0.0, 0.0),
		&"RightFoot": Vector3(-10.0, 0.0, -4.0),
	})


static func _flying_kick(base: Dictionary[StringName, Vector3]) -> MovePoses:
	var g := _air_guard(base)
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
## side through all the active frames. The head turns with the hips, a little ahead of them
## near the end, so the eyes (and the first-person view following them) turn steadily and
## finish the turn facing the way they started.
static func _spin_kick(base: Dictionary[StringName, Vector3]) -> MovePoses:
	var g := _air_guard(base)
	var windup := merge(g, {
		&"Hips": Vector3(0.0, -50.0, 0.0),
		&"Neck": Vector3(0.0, 5.0, 0.0),
		&"Head": Vector3(0.0, 5.0, 0.0),
		&"RightUpperLeg": Vector3(40.0, 0.0, 40.0),
		&"RightLowerLeg": Vector3(-80.0, 0.0, 0.0),
	})
	var strike := merge(g, {
		&"Hips": Vector3(0.0, -100.0, 0.0),
		&"Spine": Vector3(0.0, 0.0, 6.0),
		&"Neck": Vector3(0.0, 0.0, -10.0),
		&"Head": Vector3(0.0, 0.0, 0.0),
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
	m.follow = merge(g, {
		&"Hips": Vector3(0.0, -350.0, 0.0),
		&"Neck": Vector3(4.0, -5.0, 0.0),
		&"Head": Vector3(2.0, -5.0, 0.0),
	})
	m.finish = merge(g, {&"Hips": Vector3(0.0, -360.0, 0.0)})
	return m


static func _haymaker(g: Dictionary[StringName, Vector3]) -> MovePoses:
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
		# The lead arm reaches out toward the target, low and to the left of the first-person
		# view. With the torso twisted away, a guard-like left arm would park the glove over
		# the view center (and haymaker_charge holds this pose for as long as P is held).
		&"LeftUpperArm": Vector3(40.0, 40.0, -40.0),
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


## Haymaker charge pose in `stance`: the haymaker's wind-up, held while P is held. The
## right fist is cocked back out of the first-person view.
static func haymaker_charge(stance: StringName = STANCE_BOXER) -> Dictionary[StringName, Vector3]:
	return move_poses(&"haymaker", stance).windup


static func _back_elbow(g: Dictionary[StringName, Vector3]) -> MovePoses:
	var windup := merge(g, {
		&"UpperChest": Vector3(0.0, 14.0, 0.0),
		&"Chest": Vector3(-3.0, 8.0, 0.0),
		# The right fist cocks across the belly, under the first-person lens at the throat.
		&"RightUpperArm": Vector3(40.0, 30.0, 0.0),
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
		&"RightUpperLeg": Vector3(-24.0, 0.0, 5.0),
		&"RightLowerLeg": Vector3(-50.0, 0.0, 0.0),
		&"RightFoot": Vector3(10.0, 0.0, -5.0),
	})
	# The hips drive forward into the knee while the hands pull the victim down. The knee
	# comes up a little out to the right, beside the victim's head into its shoulder and chest:
	# from straight under, the head hid it from the first-person view (which tips further
	# down for the knee, MoveData.camera_pitch_deg). The torso stays bent, so the eye moves
	# only a few centimeters.
	var strike := merge(g, {
		HIPS_NUDGE: Vector3(0.0, 0.0, 0.02),
		&"Spine": Vector3(-14.0, 0.0, 0.0),
		&"Chest": Vector3(-10.0, 0.0, 0.0),
		&"LeftUpperArm": Vector3(55.5, -31.5, -42.0),
		&"LeftLowerArm": Vector3(72.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(55.5, 31.5, 42.0),
		&"RightLowerArm": Vector3(72.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(128.0, 0.0, 12.0),
		&"RightLowerLeg": Vector3(-112.0, 0.0, 0.0),
		&"RightFoot": Vector3(-30.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(20.0, 0.0, -3.0),
		&"LeftLowerLeg": Vector3(-28.0, 0.0, 0.0),
		&"LeftFoot": Vector3(8.0, 0.0, 3.0),
	})
	return _mp(g, windup, strike)


## The throw heaves from the hold and, with nothing left to hold, lands in the stance `neutral`
## (the relaxed stance gets its own in _relax()); back in the bent-over hold, the arms reached
## for the thrown body across the first-person view as the hold view eased out.
static func _throw(neutral: Dictionary[StringName, Vector3]) -> MovePoses:
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
		# Heaving forward and out to the sides, so the arms frame the throw in first person
		# instead of sweeping up across the middle of the view. The twist brings the right
		# shoulder in front of the lens, still pulled back by the hold view: the right upper
		# arm swings out wide, its elbow end off the right edge (raised ahead, it showed end on
		# as a round ball mid-view), and the forearm bends back in so the fist heaves up in the
		# top right corner.
		&"LeftUpperArm": Vector3(80.0, 10.0, -26.0),
		&"LeftLowerArm": Vector3(24.0, 0.0, 0.0),
		&"RightUpperArm": Vector3(70.0, -20.0, 95.0),
		&"RightLowerArm": Vector3(90.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(30.0, -30.0, -4.0),
		&"LeftLowerLeg": Vector3(-30.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(-16.0, -30.0, 5.0),
		&"RightLowerLeg": Vector3(-14.0, 0.0, 0.0),
		&"RightFoot": Vector3(36.0, 0.0, -5.0),
		&"RightToes": Vector3(30.0, 0.0, 0.0),
	})
	var m := _mp(g, windup, strike)
	m.finish = neutral
	return m


## Stomp on a body lying in front: the knee pulled up high, then the foot driven down flat
## onto the top of the body (its sole about 0.26 m up, where a lying torso's top is, and
## RightFootPoint inside the stomp's reach, y 0.0-0.3) instead of through it to the floor.
## The pose is fixed and does not track the body; the player stops stomp_stop_distance
## from the body's chest, so the foot comes down on the chest or just past it. The foot
## lifts off the body again before it steps back (follow).
static func _stomp(g: Dictionary[StringName, Vector3]) -> MovePoses:
	var windup := merge(g, {
		&"Spine": Vector3(-12.0, 0.0, 0.0),
		&"Chest": Vector3(-6.0, 0.0, 0.0),
		&"Neck": Vector3(-6.0, 0.0, 0.0),
		&"Head": Vector3(-8.0, 0.0, 0.0),
		&"RightUpperLeg": Vector3(100.0, 0.0, 2.0),
		&"RightLowerLeg": Vector3(-110.0, 0.0, 0.0),
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
		# The knee high, the shin near upright and the foot flat (thigh + knee + foot = 0).
		&"RightUpperLeg": Vector3(80.0, 0.0, 2.0),
		&"RightLowerLeg": Vector3(-66.0, 0.0, 0.0),
		&"RightFoot": Vector3(-14.0, 0.0, 0.0),
		&"LeftUpperLeg": Vector3(30.0, 0.0, -4.0),
		&"LeftLowerLeg": Vector3(-56.0, 0.0, 0.0),
		&"LeftFoot": Vector3(26.0, 0.0, 4.0),
		&"LeftUpperArm": Vector3(20.0, 0.0, -36.0),
		&"RightUpperArm": Vector3(10.0, 0.0, 36.0),
		&"RightLowerArm": Vector3(90.0, 0.0, 0.0),
	})
	var m := _mp(g, windup, strike)
	# Off the body first: the knee comes back up, still leaning over it.
	m.follow = merge(strike, {
		&"RightUpperLeg": windup[&"RightUpperLeg"],
		&"RightLowerLeg": windup[&"RightLowerLeg"],
		&"RightFoot": windup[&"RightFoot"],
	})
	return m


## Forehand pipe swing, right to left: the arm sweeps across the front, the weapon level.
## At contact the pipe comes in from the right and its tip meets the side of the target's
## head (it never passes through the head).
static func _pipe_swing_1(g: Dictionary[StringName, Vector3]) -> MovePoses:
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
static func _pipe_swing_2(g: Dictionary[StringName, Vector3]) -> MovePoses:
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
static func _pipe_swing_3(g: Dictionary[StringName, Vector3]) -> MovePoses:
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
static func _weapon_throw(g: Dictionary[StringName, Vector3]) -> MovePoses:
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
