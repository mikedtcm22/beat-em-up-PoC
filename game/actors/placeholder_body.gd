class_name PlaceholderBody
extends RefCounted
## Layout of the placeholder humanoid at the reference height (1.8 m): bone hierarchy and
## rest offsets, rig points, primitive mesh parts, hurtbox shapes and the sole points used
## to plant poses on the ground. HumanoidRig and PlaceholderAnims scale every length by
## height / REF_HEIGHT. Placeholder art data until real skeletons arrive (Milestone 4).
##
## Every bone's rest rotation is identity, so at rest each bone frame is aligned with the
## rig frame (x = right, y = up, -z = forward) and pose Euler angles (degrees, YXZ order)
## read the same way on every bone:
##   +x  swings a hanging limb forward (arms raise forward, legs kick forward) and tips
##       the spine, neck and head BACK; elbows flex with +x, knees with -x, feet point
##       their toes up with +x.
##   +y  turns toward the character's left (counter-clockwise seen from above).
##   +z  swings a hanging limb toward +x (out for right limbs, across for left limbs) and
##       tips the spine to the character's left.

## Height the lengths below are authored at (meters).
const REF_HEIGHT := 1.8

## Godot SkeletonProfileHumanoid bone names, parents before children.
const BONE_NAMES: Array[StringName] = [
	&"Root", &"Hips", &"Spine", &"Chest", &"UpperChest", &"Neck", &"Head",
	&"LeftShoulder", &"LeftUpperArm", &"LeftLowerArm", &"LeftHand",
	&"RightShoulder", &"RightUpperArm", &"RightLowerArm", &"RightHand",
	&"LeftUpperLeg", &"LeftLowerLeg", &"LeftFoot", &"LeftToes",
	&"RightUpperLeg", &"RightLowerLeg", &"RightFoot", &"RightToes",
]

const BONE_PARENT: Dictionary[StringName, StringName] = {
	&"Hips": &"Root", &"Spine": &"Hips", &"Chest": &"Spine", &"UpperChest": &"Chest",
	&"Neck": &"UpperChest", &"Head": &"Neck",
	&"LeftShoulder": &"UpperChest", &"LeftUpperArm": &"LeftShoulder",
	&"LeftLowerArm": &"LeftUpperArm", &"LeftHand": &"LeftLowerArm",
	&"RightShoulder": &"UpperChest", &"RightUpperArm": &"RightShoulder",
	&"RightLowerArm": &"RightUpperArm", &"RightHand": &"RightLowerArm",
	&"LeftUpperLeg": &"Hips", &"LeftLowerLeg": &"LeftUpperLeg",
	&"LeftFoot": &"LeftLowerLeg", &"LeftToes": &"LeftFoot",
	&"RightUpperLeg": &"Hips", &"RightLowerLeg": &"RightUpperLeg",
	&"RightFoot": &"RightLowerLeg", &"RightToes": &"RightFoot",
}

## Rest offset of each bone from its parent (meters at REF_HEIGHT). Arms hang straight
## down at rest; the ankle sits so the sole touches y = 0.
const BONE_REST: Dictionary[StringName, Vector3] = {
	&"Root": Vector3.ZERO,
	&"Hips": Vector3(0.0, 0.975, 0.0),
	&"Spine": Vector3(0.0, 0.1, 0.0),
	&"Chest": Vector3(0.0, 0.13, 0.0),
	&"UpperChest": Vector3(0.0, 0.13, 0.0),
	&"Neck": Vector3(0.0, 0.15, 0.0),
	&"Head": Vector3(0.0, 0.09, 0.0),
	&"LeftShoulder": Vector3(-0.05, 0.1, 0.0),
	&"LeftUpperArm": Vector3(-0.17, -0.01, 0.0),
	&"LeftLowerArm": Vector3(0.0, -0.29, 0.0),
	&"LeftHand": Vector3(0.0, -0.27, 0.0),
	&"RightShoulder": Vector3(0.05, 0.1, 0.0),
	&"RightUpperArm": Vector3(0.17, -0.01, 0.0),
	&"RightLowerArm": Vector3(0.0, -0.29, 0.0),
	&"RightHand": Vector3(0.0, -0.27, 0.0),
	&"LeftUpperLeg": Vector3(-0.11, -0.05, 0.0),
	&"LeftLowerLeg": Vector3(0.0, -0.42, 0.0),
	&"LeftFoot": Vector3(0.0, -0.42, 0.0),
	&"LeftToes": Vector3(0.0, -0.05, -0.13),
	&"RightUpperLeg": Vector3(0.11, -0.05, 0.0),
	&"RightLowerLeg": Vector3(0.0, -0.42, 0.0),
	&"RightFoot": Vector3(0.0, -0.42, 0.0),
	&"RightToes": Vector3(0.0, -0.05, -0.13),
}

## Rig points (docs/ARCHITECTURE.md "Rig points"): the bone each one follows...
const POINT_BONE: Dictionary[StringName, StringName] = {
	&"EyePoint": &"Head",
	&"HeadTopPoint": &"Head",
	&"ChestPoint": &"Chest",
	&"LeftFistPoint": &"LeftHand",
	&"RightFistPoint": &"RightHand",
	&"LeftElbowPoint": &"LeftLowerArm",
	&"RightElbowPoint": &"RightLowerArm",
	&"LeftKneePoint": &"LeftLowerLeg",
	&"RightKneePoint": &"RightLowerLeg",
	&"LeftFootPoint": &"LeftToes",
	&"RightFootPoint": &"RightToes",
	&"WeaponGrip": &"RightHand",
	&"WeaponTip": &"RightHand",
	&"HoldPoint": &"Chest",
}

## ...and its offset in that bone's frame (meters at REF_HEIGHT). The held weapon runs
## along the hand's -z axis: out of the front of the fist when the arm hangs.
const POINT_OFFSET: Dictionary[StringName, Vector3] = {
	&"EyePoint": Vector3(0.0, 0.105, -0.1),
	&"HeadTopPoint": Vector3(0.0, 0.485, 0.0),
	&"ChestPoint": Vector3(0.0, 0.07, -0.02),
	&"LeftFistPoint": Vector3(0.0, -0.065, -0.005),
	&"RightFistPoint": Vector3(0.0, -0.065, -0.005),
	&"LeftElbowPoint": Vector3(0.0, 0.02, 0.06),
	&"RightElbowPoint": Vector3(0.0, 0.02, 0.06),
	&"LeftKneePoint": Vector3(0.0, 0.02, -0.08),
	&"RightKneePoint": Vector3(0.0, 0.02, -0.08),
	&"LeftFootPoint": Vector3(0.0, 0.0, -0.03),
	&"RightFootPoint": Vector3(0.0, 0.0, -0.03),
	&"WeaponGrip": Vector3(0.0, -0.065, -0.005),
	&"WeaponTip": Vector3(0.0, -0.065, -0.705),
	&"HoldPoint": Vector3(0.0, 0.07, -0.55),
}

## Bones whose meshes go on CombatTypes.VIS_FP_HIDDEN when the rig is a first-person body,
## plus single parts on other bones (FP_HIDDEN_PARTS; see is_fp_hidden()). They still cast
## shadows and show in the side and free-fly views.
##   - Head and neck: the lens is in them.
##   - Chest and upper chest: the lens sits at throat height just in front of them
##     (FirstPersonCamera.lens_offset()), so every torso twist (spins, the back elbow)
##     swept the chest box and the shoulder balls across half the view.
##   - The shoulder balls (Delt) and the shoulder end of each upper arm: they sit right
##     beside the lens and swept across the view on every twist (a spinning heel or a spin
##     kick filled two fifths of it). The elbow end of the upper arm (Elbow) stays, so a
##     punch's arm comes in from the edge of the view as sleeve, forearm and fist instead of
##     a forearm floating in mid-view.
## Looking down, the lens sees the belly (its rounded top), belt and legs below it.
const FP_HIDDEN_BONES: Array[StringName] = [
	&"Chest", &"UpperChest", &"Neck", &"Head", &"LeftShoulder", &"RightShoulder",
]
const FP_HIDDEN_PARTS: Array[StringName] = [&"LeftDelt", &"RightDelt", &"LeftUpperArm", &"RightUpperArm"]

## Points on each sole (bone, offset at REF_HEIGHT) that PlaceholderAnims keeps at or
## above y = 0 when it plants a pose: heel, ball and toe tip.
const SOLE_BONES: Array[StringName] = [
	&"LeftFoot", &"LeftToes", &"LeftToes", &"RightFoot", &"RightToes", &"RightToes",
]
const SOLE_OFFSETS: Array[Vector3] = [
	Vector3(0.0, -0.085, 0.085), Vector3(0.0, -0.035, 0.0), Vector3(0.0, -0.035, -0.12),
	Vector3(0.0, -0.085, 0.085), Vector3(0.0, -0.035, 0.0), Vector3(0.0, -0.035, -0.12),
]

enum Shape { BOX, CAPSULE, SPHERE, CYLINDER, DOME }

## Which rig color a part takes: BODY = body_color, PANTS = pants_color (body_color
## darkened unless set), ACCENT = accent_color (cap, hand wraps, shoes), SKIN = skin_color,
## DARK = shades, belt and soles.
enum Paint { BODY, PANTS, ACCENT, SKIN, DARK }


## One primitive mesh attached to a bone. Sizes are at REF_HEIGHT:
## BOX size = extents; CAPSULE x = radius, y = total height; SPHERE x = radius,
## y = height; CYLINDER x = radius, y = height; DOME x = radius, y = height (a cap).
class Part:
	var name: StringName
	var bone: StringName
	var shape: Shape
	var size: Vector3
	var offset: Vector3
	var rot_deg: Vector3
	var paint: Paint

	func _init(p_name: StringName, p_bone: StringName, p_shape: Shape, p_size: Vector3,
			p_offset: Vector3, p_paint: Paint, p_rot_deg: Vector3 = Vector3.ZERO) -> void:
		name = p_name
		bone = p_bone
		shape = p_shape
		size = p_size
		offset = p_offset
		paint = p_paint
		rot_deg = p_rot_deg


## Hurtbox volume: a sphere around `bone_a`+`offset_a`, or a capsule whose axis runs from
## `bone_a`+`offset_a` to `bone_b`+`offset_b`. Capsule length is fixed at the rest length.
class HurtSpec:
	var name: StringName
	var region: CombatTypes.Region
	var radius: float
	var bone_a: StringName
	var offset_a: Vector3
	var bone_b: StringName
	var offset_b: Vector3

	func _init(p_name: StringName, p_region: CombatTypes.Region, p_radius: float,
			p_bone_a: StringName, p_offset_a: Vector3, p_bone_b: StringName = &"",
			p_offset_b: Vector3 = Vector3.ZERO) -> void:
		name = p_name
		region = p_region
		radius = p_radius
		bone_a = p_bone_a
		offset_a = p_offset_a
		bone_b = p_bone_b
		offset_b = p_offset_b

	func is_capsule() -> bool:
		return bone_b != &""


## Chunky placeholder body: broad V torso, thick limbs, slightly oversized fists and
## sneakers, a covered face (cap pulled low plus a wrap-around shades band) and dark hair
## at the back of the head. The hands
## are one size on everyone: with `wrapped_hands` (the player, Spec §10) skin-colored and
## wrapped (_wrapped_hand()), otherwise dark fingerless gloves (_gloved_hand()).
static func parts(wrapped_hands: bool = false) -> Array[Part]:
	var out: Array[Part] = [
		Part.new(&"Pelvis", &"Hips", Shape.BOX, Vector3(0.36, 0.2, 0.25), Vector3(0.0, -0.03, 0.0), Paint.PANTS),
		Part.new(&"Belt", &"Hips", Shape.BOX, Vector3(0.37, 0.05, 0.26), Vector3(0.0, 0.07, 0.0), Paint.DARK),
		Part.new(&"Belly", &"Spine", Shape.BOX, Vector3(0.36, 0.17, 0.24), Vector3(0.0, 0.07, 0.0), Paint.BODY),
		# A rounded top on the belly: a half-sunk cylinder lying across it, as wide and deep
		# as the belly. The chest box hides it from outside; with the chest hidden from the
		# first-person camera (FP_HIDDEN_BONES), looking steeply down shows a rounded shirt
		# front instead of the belly box's flat lid.
		Part.new(&"BellyTop", &"Spine", Shape.CYLINDER, Vector3(0.12, 0.36, 0.0), Vector3(0.0, 0.155, 0.0), Paint.BODY, Vector3(0.0, 0.0, 90.0)),
		Part.new(&"Chest", &"Chest", Shape.BOX, Vector3(0.43, 0.17, 0.27), Vector3(0.0, 0.07, 0.0), Paint.BODY),
		Part.new(&"UpperChest", &"UpperChest", Shape.BOX, Vector3(0.52, 0.17, 0.28), Vector3(0.0, 0.075, 0.0), Paint.BODY),
		Part.new(&"Neck", &"Neck", Shape.CYLINDER, Vector3(0.065, 0.15, 0.0), Vector3(0.0, 0.05, 0.0), Paint.SKIN),
		Part.new(&"Head", &"Head", Shape.SPHERE, Vector3(0.125, 0.27, 0.0), Vector3(0.0, 0.11, -0.01), Paint.SKIN),
		Part.new(&"Cap", &"Head", Shape.DOME, Vector3(0.134, 0.134, 0.0), Vector3(0.0, 0.135, -0.01), Paint.ACCENT),
		# Dark hair over the back of the head: a ball the head's size set back and up from it,
		# so the back of the head from the nape up (the held head seen from the hold view, the
		# back of anyone's head) is hair, not a bare skin dome, while the face stays as it was.
		Part.new(&"Hair", &"Head", Shape.SPHERE, Vector3(0.127, 0.254, 0.0), Vector3(0.0, 0.125, 0.015), Paint.DARK),
		Part.new(&"CapBrim", &"Head", Shape.BOX, Vector3(0.21, 0.022, 0.12), Vector3(0.0, 0.14, -0.16), Paint.ACCENT, Vector3(-6.0, 0.0, 0.0)),
		Part.new(&"Shades", &"Head", Shape.CYLINDER, Vector3(0.129, 0.045, 0.0), Vector3(0.0, 0.105, -0.01), Paint.DARK),
		Part.new(&"ShadesFront", &"Head", Shape.BOX, Vector3(0.22, 0.055, 0.04), Vector3(0.0, 0.105, -0.12), Paint.DARK),
	]
	for side: String in ["Left", "Right"]:
		var sx: float = -1.0 if side == "Left" else 1.0
		out.append_array([
			Part.new(StringName(side + "Delt"), StringName(side + "UpperArm"), Shape.SPHERE, Vector3(0.095, 0.19, 0.0), Vector3(0.0, -0.02, 0.0), Paint.BODY),
			# The upper arm in two overlapping capsules of one radius whose union is a single
			# capsule from the shoulder to the elbow: the shoulder end (FP_HIDDEN_PARTS) and the
			# elbow end, which the first-person camera still draws.
			Part.new(StringName(side + "UpperArm"), StringName(side + "UpperArm"), Shape.CAPSULE, Vector3(0.075, 0.275, 0.0), Vector3(0.0, -0.1125, 0.0), Paint.BODY),
			Part.new(StringName(side + "Elbow"), StringName(side + "UpperArm"), Shape.CAPSULE, Vector3(0.075, 0.215, 0.0), Vector3(0.0, -0.2075, 0.0), Paint.BODY),
			Part.new(StringName(side + "Thigh"), StringName(side + "UpperLeg"), Shape.CAPSULE, Vector3(0.1, 0.48, 0.0), Vector3(0.0, -0.205, 0.0), Paint.PANTS),
			Part.new(StringName(side + "Shin"), StringName(side + "LowerLeg"), Shape.CAPSULE, Vector3(0.085, 0.46, 0.0), Vector3(0.0, -0.2, 0.0), Paint.PANTS),
			Part.new(StringName(side + "Shoe"), StringName(side + "Foot"), Shape.BOX, Vector3(0.135, 0.095, 0.25), Vector3(0.0, -0.04, -0.035), Paint.ACCENT),
			Part.new(StringName(side + "Sole"), StringName(side + "Foot"), Shape.BOX, Vector3(0.14, 0.025, 0.25), Vector3(0.0, -0.075, -0.035), Paint.DARK),
			Part.new(StringName(side + "ToeCap"), StringName(side + "Toes"), Shape.BOX, Vector3(0.13, 0.07, 0.13), Vector3(0.0, 0.0, -0.06), Paint.ACCENT),
			Part.new(StringName(side + "ToeSole"), StringName(side + "Toes"), Shape.BOX, Vector3(0.135, 0.025, 0.13), Vector3(0.0, -0.025, -0.06), Paint.DARK),
		])
		out.append_array(_wrapped_hand(side, sx) if wrapped_hands else _gloved_hand(side))
		# Slight outward splay of the shoulder ball so the silhouette reads broad.
		out.append(Part.new(StringName(side + "Trap"), &"UpperChest", Shape.SPHERE, Vector3(0.1, 0.16, 0.0), Vector3(sx * 0.14, 0.13, 0.01), Paint.BODY))
	return out


## The forearm on `side`, the same on everyone.
static func _forearm(side: String) -> Part:
	return Part.new(StringName(side + "Forearm"), StringName(side + "LowerArm"), Shape.CAPSULE, Vector3(0.056, 0.3, 0.0), Vector3(0.0, -0.125, 0.0), Paint.SKIN)


## An enemy's forearm and hand on `side`: a dark fingerless glove (the fist), the bare
## fingers showing across its knuckle end and a strap in the accent color across its
## wrist end. The same size as the player's hand (_wrapped_hand()): about 0.9 times the old
## fist block (0.12 x 0.13 x 0.135 m, the enemies' hands until Game-boy's first-person
## playtest) in each direction, about 73% of its volume, so the guard's fists no longer
## fill the player's view at sparring range while they still read as fists from 2-10 m.
## No wrap on the forearm: the dark part of the hand stays as compact as the fist.
## Centered on the FistPoint. The fingers and the strap cap the glove's faces instead of
## ending flush with them (flush faces z-fight).
static func _gloved_hand(side: String) -> Array[Part]:
	var hand := StringName(side + "Hand")
	return [
		_forearm(side),
		Part.new(StringName(side + "Fist"), hand, Shape.BOX, Vector3(0.1, 0.118, 0.116), Vector3(0.0, -0.065, -0.005), Paint.DARK),
		Part.new(StringName(side + "Fingers"), hand, Shape.BOX, Vector3(0.106, 0.034, 0.122), Vector3(0.0, -0.108, -0.005), Paint.SKIN),
		Part.new(StringName(side + "Strap"), hand, Shape.BOX, Vector3(0.106, 0.026, 0.122), Vector3(0.0, -0.017, -0.005), Paint.ACCENT),
	]


## The player's forearm and hand on `side` (sx = -1 left, +1 right): a light wrap at the
## wrist, and a skin-colored fist the size of the enemies' gloves (_gloved_hand()), wrapped
## across the knuckles and at the wrist, with a dark fingerless-glove plate on the back of
## the hand (the outer side when the arm hangs). Centered on the FistPoint.
static func _wrapped_hand(side: String, sx: float) -> Array[Part]:
	var lower := StringName(side + "LowerArm")
	var hand := StringName(side + "Hand")
	return [
		_forearm(side),
		Part.new(StringName(side + "Wrap"), lower, Shape.CYLINDER, Vector3(0.059, 0.07, 0.0), Vector3(0.0, -0.23, 0.0), Paint.ACCENT),
		Part.new(StringName(side + "Hand"), hand, Shape.BOX, Vector3(0.1, 0.118, 0.116), Vector3(0.0, -0.065, -0.005), Paint.SKIN),
		Part.new(StringName(side + "KnuckleWrap"), hand, Shape.BOX, Vector3(0.106, 0.034, 0.122), Vector3(0.0, -0.078, -0.005), Paint.ACCENT),
		Part.new(StringName(side + "WristWrap"), hand, Shape.BOX, Vector3(0.106, 0.026, 0.122), Vector3(0.0, -0.017, -0.005), Paint.ACCENT),
		Part.new(StringName(side + "GloveBack"), hand, Shape.BOX, Vector3(0.012, 0.03, 0.09), Vector3(sx * 0.052, -0.047, -0.005), Paint.DARK),
	]


## Ragdoll body total mass (kg at REF_HEIGHT; it scales with the cube of the height).
## Ragdoll springs and impulses are velocity changes, so the mass only weighs in where two
## ragdolls collide.
const RAGDOLL_MASS := 75.0

## How a ragdoll bone hangs off its physical parent.
enum RagdollJoint {
	CONE,   ## A ball joint: the bone's axis swings within a cone and twists about itself.
	HINGE,  ## Bends about the bone's X axis only (elbows, knees, ankles).
}


## One ragdoll body (Ragdoll, game/actors/ragdoll.gd): a rigid body on `bone`, jointed to
## its parent bone's body at the bone's origin. Shapes are Part-style (BOX size = extents;
## CAPSULE x = radius, y = total height; SPHERE x = radius) in the bone's frame, meters at
## REF_HEIGHT, and cover the placeholder meshes so a lying body rests on its surface.
## Joints are body data, not feel: a CONE's `axis` is the bone's direction at rest (toward
## its child), `center` the direction in the parent's frame its cone is centered on, and
## `swing_deg` / `twist_deg` its half-angles; a HINGE bends from `lower_deg` to `upper_deg`
## about X (+x flexes elbows, -x knees, +x points the toes up; PlaceholderBody's header).
## The ranges hold every enemy animation pose (sampled from PlaceholderAnims) and stay
## within a human body's.
class RagdollSpec:
	var bone: StringName
	var shape: Shape
	var size: Vector3
	var offset: Vector3
	var rot_deg: Vector3
	var mass_share: float
	var joint: RagdollJoint = RagdollJoint.CONE
	var axis: Vector3 = Vector3.UP
	var center: Vector3 = Vector3.UP
	var swing_deg: float = 0.0
	var twist_deg: float = 0.0
	var lower_deg: float = 0.0
	var upper_deg: float = 0.0

	func _init(p_bone: StringName, p_shape: Shape, p_size: Vector3, p_offset: Vector3,
			p_mass_share: float, p_rot_deg: Vector3 = Vector3.ZERO) -> void:
		bone = p_bone
		shape = p_shape
		size = p_size
		offset = p_offset
		mass_share = p_mass_share
		rot_deg = p_rot_deg

	func cone(p_axis: Vector3, p_center: Vector3, p_swing_deg: float, p_twist_deg: float) -> RagdollSpec:
		joint = RagdollJoint.CONE
		axis = p_axis.normalized()
		center = p_center.normalized()
		swing_deg = p_swing_deg
		twist_deg = p_twist_deg
		return self

	func hinge(p_lower_deg: float, p_upper_deg: float) -> RagdollSpec:
		joint = RagdollJoint.HINGE
		axis = Vector3.DOWN
		lower_deg = p_lower_deg
		upper_deg = p_upper_deg
		return self


## The ragdoll bodies, parents before children; every bone from the Hips to the head, the
## arms and the legs has one, so a jointed pair never has an animated bone between them.
## Root, the hands and the toes have none: they keep their animation pose on their parent.
## The Hips have no joint (the ragdoll's root).
static func ragdoll_specs() -> Array[RagdollSpec]:
	var out: Array[RagdollSpec] = [
		RagdollSpec.new(&"Hips", Shape.BOX, Vector3(0.34, 0.24, 0.24), Vector3(0.0, -0.02, 0.0), 0.15),
		RagdollSpec.new(&"Spine", Shape.BOX, Vector3(0.34, 0.15, 0.22), Vector3(0.0, 0.07, 0.0), 0.09) \
				.cone(Vector3.UP, Vector3(0.0, 1.0, -0.065), 36.0, 20.0),
		RagdollSpec.new(&"Chest", Shape.BOX, Vector3(0.4, 0.14, 0.25), Vector3(0.0, 0.07, 0.0), 0.09) \
				.cone(Vector3.UP, Vector3(0.0, 1.0, -0.045), 28.0, 16.0),
		RagdollSpec.new(&"UpperChest", Shape.BOX, Vector3(0.48, 0.16, 0.26), Vector3(0.0, 0.075, 0.0), 0.1) \
				.cone(Vector3.UP, Vector3(0.0, 1.0, -0.01), 20.0, 16.0),
		RagdollSpec.new(&"Neck", Shape.CAPSULE, Vector3(0.06, 0.15, 0.0), Vector3(0.0, 0.045, 0.0), 0.02) \
				.cone(Vector3.UP, Vector3(0.0, 1.0, 0.04), 32.0, 30.0),
		RagdollSpec.new(&"Head", Shape.SPHERE, Vector3(0.125, 0.25, 0.0), Vector3(0.0, 0.11, -0.01), 0.065) \
				.cone(Vector3.UP, Vector3(-0.02, 1.0, 0.0), 44.0, 62.0),
	]
	for side: String in ["Left", "Right"]:
		var sx: float = -1.0 if side == "Left" else 1.0
		out.append_array([
			RagdollSpec.new(StringName(side + "Shoulder"), Shape.CAPSULE, Vector3(0.06, 0.2, 0.0),
					Vector3(sx * 0.085, 0.0, 0.0), 0.02, Vector3(0.0, 0.0, 90.0)) \
					.cone(Vector3(sx, 0.0, 0.0), Vector3(sx, 0.01, -0.02), 36.0, 10.0),
			RagdollSpec.new(StringName(side + "UpperArm"), Shape.CAPSULE, Vector3(0.075, 0.34, 0.0),
					Vector3(0.0, -0.13, 0.0), 0.032) \
					.cone(Vector3.DOWN, Vector3(sx * 0.42, -0.69, -0.58), 100.0, 90.0),
			# The forearm's body carries the fist.
			RagdollSpec.new(StringName(side + "LowerArm"), Shape.CAPSULE, Vector3(0.06, 0.42, 0.0),
					Vector3(0.0, -0.18, 0.0), 0.026).hinge(0.0, 150.0),
			RagdollSpec.new(StringName(side + "UpperLeg"), Shape.CAPSULE, Vector3(0.1, 0.5, 0.0),
					Vector3(0.0, -0.205, 0.0), 0.1) \
					.cone(Vector3.DOWN, Vector3(sx * 0.12, -0.96, -0.22), 95.0, 30.0),
			RagdollSpec.new(StringName(side + "LowerLeg"), Shape.CAPSULE, Vector3(0.085, 0.46, 0.0),
					Vector3(0.0, -0.2, 0.0), 0.05).hinge(-130.0, 0.0),
			# The foot's body carries the toes.
			RagdollSpec.new(StringName(side + "Foot"), Shape.BOX, Vector3(0.13, 0.1, 0.26),
					Vector3(0.0, -0.04, -0.05), 0.015).hinge(-72.0, 62.0),
		])
	return out


## Region hurtboxes (docs/ARCHITECTURE.md "Hurtboxes").
static func hurt_specs() -> Array[HurtSpec]:
	return [
		HurtSpec.new(&"HurtboxHead", CombatTypes.Region.HEAD, 0.15, &"Head", Vector3(0.0, 0.11, -0.01)),
		HurtSpec.new(&"HurtboxTorso", CombatTypes.Region.TORSO, 0.2, &"Spine", Vector3(0.0, -0.03, 0.0), &"UpperChest", Vector3(0.0, 0.08, 0.0)),
		HurtSpec.new(&"HurtboxLegL", CombatTypes.Region.LEGS, 0.1, &"LeftUpperLeg", Vector3.ZERO, &"LeftFoot", Vector3.ZERO),
		HurtSpec.new(&"HurtboxLegR", CombatTypes.Region.LEGS, 0.1, &"RightUpperLeg", Vector3.ZERO, &"RightFoot", Vector3.ZERO),
	]


## True when `part` goes on CombatTypes.VIS_FP_HIDDEN on a first-person body.
static func is_fp_hidden(part: Part) -> bool:
	return FP_HIDDEN_BONES.has(part.bone) or FP_HIDDEN_PARTS.has(part.name)


## Rotation basis for Euler angles in degrees (YXZ, Godot's default order).
static func euler_basis(deg: Vector3) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z)))


## Skeleton-space transform of every bone for `pose` (bone -> Euler degrees; missing
## bones are at rest rotation), with `hips_offset` added to the Hips rest position.
## Lengths are scaled by `scale`. Pure math; used to plant poses before they are keyed.
static func pose_globals(pose: Dictionary[StringName, Vector3], hips_offset: Vector3,
		scale: float) -> Dictionary[StringName, Transform3D]:
	var out: Dictionary[StringName, Transform3D] = {}
	for bone: StringName in BONE_NAMES:
		var origin: Vector3 = BONE_REST[bone] * scale
		if bone == &"Hips":
			origin += hips_offset * scale
		var local := Transform3D(euler_basis(pose.get(bone, Vector3.ZERO)), origin)
		if BONE_PARENT.has(bone):
			out[bone] = out[BONE_PARENT[bone]] * local
		else:
			out[bone] = local
	return out


## Lowest sole point height (skeleton space) for bone transforms from pose_globals().
static func lowest_sole(globals: Dictionary[StringName, Transform3D], scale: float) -> float:
	var lowest := INF
	for i: int in SOLE_BONES.size():
		var p: Vector3 = globals[SOLE_BONES[i]] * (SOLE_OFFSETS[i] * scale)
		lowest = minf(lowest, p.y)
	return lowest
