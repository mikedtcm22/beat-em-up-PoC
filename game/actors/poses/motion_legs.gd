class_name MotionLegs
extends RefCounted
## Two-bone leg IK for the placeholder skeleton (Milestone 4, F-motion): the legs' bone angles
## that put an ankle where a clip wants it, so a polished clip can hold its soles still on the
## floor (an idle that bounces and shifts its weight) or move them at the body's speed (a walk that
## plants its feet). Pure math at PlaceholderBody.REF_HEIGHT, in the rig's space (x right, y up,
## the body faces -z), like PlaceholderBody.pose_globals(), whose FK it inverts: the
## result is written into a pose dictionary of bone -> Euler degrees (YXZ), the clip keys' own form.
##
## A leg is the hip joint (on the Hips), the knee (LowerLeg) and the ankle (Foot), each limb
## PlaceholderBody.BONE_REST's 0.42 m. The knee bends toward the pole (forward, a little outward);
## the thigh is turned about its own axis so the knee hinges in the leg's plane. The foot is
## given as a world basis (a pitch, a yaw): flat on the floor, heel down at a strike, heel up at a
## push-off.

## Where the knee points (rig space; the body faces -z): forward, a little out to its own side.
const KNEE_POLE := Vector3(0.0, 0.0, -1.0)
## The knee points this far outward (radians) of straight forward, to its own side.
const KNEE_OUT_RAD := 0.12
## The farthest a leg may reach, as a share of its length (a straight knee is a singular pose).
const MAX_REACH := 0.995
## The nearest the ankle may come to the hip joint (m): a folded leg is out of the clips' range.
const MIN_REACH_M := 0.15
## Where the foot's contact points are, in the foot's frame (PlaceholderBody.SOLE_OFFSETS): the
## heel, and the toes joint the ball and the tip hang from.
const HEEL := Vector3(0.0, -0.085, 0.085)
const TOES_JOINT := Vector3(0.0, -0.05, -0.13)
const BALL_BELOW_TOES := Vector3(0.0, -0.035, 0.0)


## The Hips' transform (rig space) for `pose` and a `hips_offset` from the rest position.
static func hips_transform(pose: Dictionary[StringName, Vector3], hips_offset: Vector3) -> Transform3D:
	return Transform3D(PlaceholderBody.euler_basis(pose.get(&"Hips", Vector3.ZERO)),
			PlaceholderBody.BONE_REST[&"Hips"] + hips_offset)


## The hip joint of `side` ("Left" or "Right") for the Hips transform `hips`.
static func hip_joint(hips: Transform3D, side: StringName) -> Vector3:
	return hips * PlaceholderBody.BONE_REST[StringName(String(side) + "UpperLeg")]


## Put the ankle of `side` at `ankle` with the foot's world orientation `foot`: writes the side's
## UpperLeg, LowerLeg and Foot angles into `pose` (the Hips and everything above must be in it
## already). `toes_deg` is the toes' pitch against the foot. `knee_hint` is any vector from the
## hip joint toward the side the knee goes (the knee's offset from the hip, to follow a pose's own
## knee); empty = forward and a little out. Returns the shortfall (m) when the ankle was out of
## the leg's reach (0 when it was reached): the ankle then lands that far short.
static func plant(pose: Dictionary[StringName, Vector3], hips: Transform3D, side: StringName,
		ankle: Vector3, foot: Basis, toes_deg: float = 0.0, knee_hint: Vector3 = Vector3.ZERO) -> float:
	var upper := PlaceholderBody.BONE_REST[&"LeftLowerLeg"].length()
	var lower := PlaceholderBody.BONE_REST[&"LeftFoot"].length()
	var hip := hip_joint(hips, side)
	var to_ankle := ankle - hip
	var dist := to_ankle.length()
	var shortfall := maxf(dist - (upper + lower) * MAX_REACH, 0.0)
	dist = clampf(dist, MIN_REACH_M, (upper + lower) * MAX_REACH)
	var u := to_ankle.normalized() if to_ankle.length() > 1e-6 else Vector3.DOWN
	var reach := ankle if shortfall <= 0.0 else hip + u * dist
	# The knee: in the plane of the hip, the ankle and the pole.
	var side_sign := -1.0 if side == &"Left" else 1.0
	var pole := Vector3(sin(KNEE_OUT_RAD) * side_sign, 0.0, -cos(KNEE_OUT_RAD)) if knee_hint.length() < 1e-6 else knee_hint
	var along := (upper * upper - lower * lower + dist * dist) / (2.0 * dist)
	var height := sqrt(maxf(upper * upper - along * along, 0.0))
	var bend := (pole - u * pole.dot(u)).normalized()
	var knee := hip + u * along + bend * height
	var d1 := (knee - hip) / upper
	var d2 := (reach - knee) / lower
	# The thigh's frame: Y up the thigh, Z toward where the shin goes, X across the knee's hinge.
	var y_axis := -d1
	var z_axis := d2 - d1 * d1.dot(d2)
	if z_axis.length() < 1e-5:
		z_axis = -(bend - d1 * d1.dot(bend))
	z_axis = z_axis.normalized()
	var x_axis := y_axis.cross(z_axis)
	var thigh := Basis(x_axis, y_axis, z_axis)
	var flex := -acos(clampf(d1.dot(d2), -1.0, 1.0))
	var shin := thigh * Basis(Vector3.RIGHT, flex)
	var s := String(side)
	pose[StringName(s + "UpperLeg")] = _degrees((hips.basis.inverse() * thigh).get_euler(EULER_ORDER_YXZ))
	pose[StringName(s + "LowerLeg")] = Vector3(rad_to_deg(flex), 0.0, 0.0)
	pose[StringName(s + "Foot")] = _degrees((shin.inverse() * foot).get_euler(EULER_ORDER_YXZ))
	pose[StringName(s + "Toes")] = Vector3(toes_deg, 0.0, 0.0)
	return shortfall


## The foot's world basis for a pitch (degrees, toes up positive) and a yaw (degrees, toward the
## character's left positive).
static func foot_basis(pitch_deg: float, yaw_deg: float = 0.0) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0.0))


## The ankle that puts the foot's heel at `heel` (rig space) with the foot's basis `foot`.
static func ankle_for_heel(heel: Vector3, foot: Basis) -> Vector3:
	return heel - foot * HEEL


## The ankle that puts the ball of the foot at `ball` with the foot's basis `foot` and the toes
## flat on the floor (the toes' world basis is identity, so the ball hangs 0.035 under the toes
## joint, and the joint hangs off the ankle).
static func ankle_for_ball(ball: Vector3, foot: Basis) -> Vector3:
	return ball - BALL_BELOW_TOES - foot * TOES_JOINT


## The toes' pitch against the foot (degrees) that keeps them flat on the floor under a foot
## pitched `foot_pitch_deg` (toes up positive), the toes' world pitch being `toes_world_deg`.
static func flat_toes(foot_pitch_deg: float, toes_world_deg: float = 0.0) -> float:
	return toes_world_deg - foot_pitch_deg


static func _degrees(radians: Vector3) -> Vector3:
	return Vector3(rad_to_deg(radians.x), rad_to_deg(radians.y), rad_to_deg(radians.z))
