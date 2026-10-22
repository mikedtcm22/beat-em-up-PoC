class_name PlaceholderAnims
extends RefCounted
## Builds the procedural placeholder animations (Milestone 1) from PlaceholderPoses.
##
## Every animation has one rotation track per bone except Root ("Skeleton3D:<Bone>",
## relative to the AnimationPlayer's root node, the HumanoidRig) and a Hips position track
## (it carries crouches, jumps, falls, lying down and getting up; it is keyed even when the
## hips stay put). Planted poses get their hip height from the feet: the lowest sole point
## is put on y = 0.
## Real animation clips replace all of this in Milestone 4.

## MoveData frames are 60 Hz sim frames (docs/ARCHITECTURE.md "Time model").
const FRAME_S := 1.0 / 60.0
## Consecutive keys whose angles differ by more than this get evenly spaced in-between
## keys, so shortest-arc rotation interpolation follows the authored direction (360-degree
## spins, long swings).
const MAX_STEP_DEG := 90.0

## Every non-move animation id in docs/ARCHITECTURE.md "Animation ids".
const ANIM_IDS: Array[StringName] = [
	&"idle", &"walk_forward", &"walk_back", &"walk_left", &"walk_right",
	&"jump", &"fall", &"land",
	&"dodge_left", &"dodge_right", &"dodge_back", &"dodge_forward",
	&"grab", &"hold", &"held", &"thrown", &"pickup", &"haymaker_charge",
	&"flinch_head_front", &"flinch_head_left", &"flinch_head_right", &"flinch_gut",
	&"flinch_legs", &"stagger_back", &"stagger_left", &"stagger_right", &"stagger_forward",
	&"launched", &"knockdown_back", &"knockdown_forward", &"downed_back", &"downed_front",
	&"getup_back", &"getup_front", &"ko_back", &"ko_front",
]

## Animations that loop. Every other animation plays once and then holds its last pose.
const LOOPING: Array[StringName] = [
	&"idle", &"walk_forward", &"walk_back", &"walk_left", &"walk_right",
	&"hold", &"held", &"downed_back", &"downed_front",
]

## Move id -> the animation that holds its charge (it ends on the move's wind-up pose).
## HumanoidRig.play_move() starts such a move from the charge pose when it is released
## out of that animation.
const CHARGE_ANIMS: Dictionary[StringName, StringName] = {&"haymaker": &"haymaker_charge"}

## Falls that start with a standing buckle -> the time of their falling key, where a body
## that is already off its feet (launched, thrown) joins them (HumanoidRig.play()).
const FALL_JOIN_S: Dictionary[StringName, float] = {
	&"knockdown_back": 0.18, &"knockdown_forward": 0.18, &"ko_back": 0.3, &"ko_front": 0.3,
}

## False silences the warning for move ids without a recipe (for tests that use the
## fallback on purpose).
static var warn_on_fallback: bool = true

## Move ids with a dedicated recipe in PlaceholderPoses (docs/ARCHITECTURE.md "Moves").
const MOVE_IDS: Array[StringName] = [
	&"jab_1", &"jab_2", &"hook", &"uppercut", &"body_flurry", &"shove",
	&"front_kick", &"roundhouse", &"spinning_heel", &"stomp_kick", &"push_kick",
	&"haymaker", &"flying_kick", &"spin_kick", &"back_elbow", &"knee", &"throw",
	&"stomp", &"pipe_swing_1", &"pipe_swing_2", &"pipe_swing_3", &"weapon_throw",
	&"impact_body_knockdown", &"impact_body_stagger",
]


## One key: a pose at a time in seconds.
class PoseKey:
	var time: float
	var pose: Dictionary[StringName, Vector3]
	## Resolved Hips offset (meters at reference height); set by make().
	var hips: Vector3 = Vector3.ZERO

	func _init(p_time: float, p_pose: Dictionary[StringName, Vector3]) -> void:
		time = p_time
		pose = p_pose


static func _k(time: float, pose: Dictionary[StringName, Vector3]) -> PoseKey:
	return PoseKey.new(time, pose)


## Bones that get a rotation track (all but Root, which never moves).
static func animated_bones() -> Array[StringName]:
	var out: Array[StringName] = PlaceholderBody.BONE_NAMES.duplicate()
	out.erase(&"Root")
	return out


## Library holding every id in ANIM_IDS, lengths scaled for a rig of
## `scale` x PlaceholderBody.REF_HEIGHT standing in `stance` (PlaceholderPoses.STANCE_*).
static func build_library(scale: float,
		stance: StringName = PlaceholderPoses.STANCE_BOXER) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for id: StringName in ANIM_IDS:
		lib.add_animation(id, build_named(id, scale, stance))
	return lib


## One named (non-move) animation. Everything that starts or ends standing does so in
## `stance`'s pose.
static func build_named(id: StringName, scale: float,
		stance: StringName = PlaceholderPoses.STANCE_BOXER) -> Animation:
	var g := PlaceholderPoses.stance_pose(stance)
	var keys: Array[PoseKey] = []
	var length := 1.0
	match id:
		&"idle":
			length = 2.0
			var breathe := PlaceholderPoses.add(g, {
				&"Chest": Vector3(2.0, 0.0, 0.0), &"Neck": Vector3(-2.0, 0.0, 0.0),
				&"LeftUpperArm": Vector3(3.0, 0.0, 0.0), &"RightUpperArm": Vector3(3.0, 0.0, 0.0),
				&"LeftUpperLeg": Vector3(3.0, 0.0, 0.0), &"LeftLowerLeg": Vector3(-5.0, 0.0, 0.0),
				&"LeftFoot": Vector3(2.0, 0.0, 0.0), &"RightUpperLeg": Vector3(3.0, 0.0, 0.0),
				&"RightLowerLeg": Vector3(-5.0, 0.0, 0.0), &"RightFoot": Vector3(2.0, 0.0, 0.0),
			})
			keys = [_k(0.0, g), _k(1.0, breathe), _k(2.0, g)]
		&"walk_forward", &"walk_back":
			length = 0.6
			var contact := PlaceholderPoses.walk_contact(g)
			var pass_pose := PlaceholderPoses.walk_pass(g)
			var contact_r := _legs(g, PlaceholderPoses.mirror(contact))
			contact_r[&"Hips"] = PlaceholderPoses.mirror(contact)[&"Hips"]
			var pass_r := _legs(g, PlaceholderPoses.mirror(pass_pose))
			if stance == PlaceholderPoses.STANCE_RELAXED:
				# Loose arms swing against the legs (the boxer guard keeps its fists up).
				contact = PlaceholderPoses.add(contact, PlaceholderPoses.arm_swing(true))
				contact_r = PlaceholderPoses.add(contact_r, PlaceholderPoses.arm_swing(false))
			keys = [_k(0.0, contact), _k(0.15, pass_pose), _k(0.3, contact_r), _k(0.45, pass_r),
				_k(0.6, contact)]
			if id == &"walk_back":
				for key: PoseKey in keys:
					key.time = length - key.time
		&"walk_right", &"walk_left":
			length = 0.6
			var wide := PlaceholderPoses.step_wide(g)
			var close := PlaceholderPoses.step_close(g)
			if id == &"walk_left":
				wide = _legs(g, PlaceholderPoses.mirror(wide))
				close = _legs(g, PlaceholderPoses.mirror(close))
			keys = [_k(0.0, g), _k(0.2, wide), _k(0.4, close), _k(0.6, g)]
		&"jump":
			length = 0.35
			keys = [_k(0.0, g), _k(0.1, PlaceholderPoses.jump_takeoff(g)),
				_k(0.35, PlaceholderPoses.jump_tuck(g))]
		&"fall":
			length = 0.3
			keys = [_k(0.0, PlaceholderPoses.jump_tuck(g)), _k(0.3, PlaceholderPoses.fall_pose(g))]
		&"land":
			length = 0.25
			keys = [_k(0.0, PlaceholderPoses.crouch(g)), _k(0.25, g)]
		&"dodge_left", &"dodge_right", &"dodge_back", &"dodge_forward":
			length = 0.3
			var dodge := PlaceholderPoses.dodge_right(g)
			if id == &"dodge_left":
				dodge = PlaceholderPoses.mirror(dodge)
			elif id == &"dodge_back":
				dodge = PlaceholderPoses.dodge_back(g)
			elif id == &"dodge_forward":
				dodge = PlaceholderPoses.dodge_forward(g)
			# In by 3 frames and held to frame 13 of the 14-frame dodge (Tuning.dodge_frames).
			keys = [_k(0.0, g), _k(0.05, dodge), _k(0.22, dodge), _k(0.3, g)]
		&"grab":
			length = 0.25
			keys = [_k(0.0, g), _k(0.12, PlaceholderPoses.grab_reach(g)),
				_k(0.25, PlaceholderPoses.hold())]
		&"hold":
			length = 1.2
			var h := PlaceholderPoses.hold()
			keys = [_k(0.0, h), _k(0.6, PlaceholderPoses.add(h, {
				&"Spine": Vector3(-2.0, 2.0, 0.0), &"LeftLowerArm": Vector3(4.0, 0.0, 0.0),
				&"RightLowerArm": Vector3(-4.0, 0.0, 0.0)})), _k(1.2, h)]
		&"held":
			length = 1.0
			var hd := PlaceholderPoses.held()
			keys = [_k(0.0, hd), _k(0.5, PlaceholderPoses.add(hd, {
				&"Spine": Vector3(-3.0, 0.0, 2.0), &"Head": Vector3(-4.0, 6.0, 0.0)})),
				_k(1.0, hd)]
		&"thrown":
			length = 0.5
			keys = [_k(0.0, PlaceholderPoses.thrown_a()), _k(0.5, PlaceholderPoses.thrown_b())]
		&"pickup":
			length = 0.45
			keys = [_k(0.0, g), _k(0.2, PlaceholderPoses.pickup_reach(g)),
				_k(0.26, PlaceholderPoses.pickup_reach(g)), _k(0.45, g)]
		&"haymaker_charge":
			length = 0.3
			keys = [_k(0.0, g), _k(0.3, PlaceholderPoses.haymaker_charge(stance))]
		&"flinch_head_front", &"flinch_head_left", &"flinch_head_right", &"flinch_gut", &"flinch_legs":
			length = 0.25
			var f: Dictionary[StringName, Vector3]
			match id:
				&"flinch_head_front":
					f = PlaceholderPoses.flinch_head_front(g)
				&"flinch_head_left":
					f = PlaceholderPoses.flinch_head_side(g, true)
				&"flinch_head_right":
					f = PlaceholderPoses.flinch_head_side(g, false)
				&"flinch_gut":
					f = PlaceholderPoses.flinch_gut(g)
				_:
					f = PlaceholderPoses.flinch_legs(g)
			keys = [_k(0.0, g), _k(0.06, f), _k(0.1, f), _k(0.25, g)]
		&"stagger_back", &"stagger_left", &"stagger_right", &"stagger_forward":
			length = 0.6
			var a: Dictionary[StringName, Vector3]
			var b: Dictionary[StringName, Vector3]
			match id:
				&"stagger_back":
					a = PlaceholderPoses.stagger_back_a(g)
					b = PlaceholderPoses.stagger_back_b(g)
				&"stagger_forward":
					a = PlaceholderPoses.stagger_forward_a(g)
					b = PlaceholderPoses.stagger_forward_b(g)
				&"stagger_right":
					a = PlaceholderPoses.stagger_right_a(g)
					b = PlaceholderPoses.stagger_right_b(g)
				_:
					a = PlaceholderPoses.mirror(PlaceholderPoses.stagger_right_a(g))
					b = PlaceholderPoses.mirror(PlaceholderPoses.stagger_right_b(g))
			keys = [_k(0.0, g), _k(0.12, a), _k(0.34, b), _k(0.6, g)]
		&"launched":
			length = 0.4
			keys = [_k(0.0, PlaceholderPoses.launched_a()), _k(0.4, PlaceholderPoses.launched_b())]
		&"knockdown_back":
			length = 0.5
			var down := PlaceholderPoses.downed_back()
			keys = [_k(0.0, PlaceholderPoses.buckle(g)), _k(FALL_JOIN_S[id], PlaceholderPoses.falling_back()),
				_k(0.36, PlaceholderPoses.add(down, {&"Spine": Vector3(-8.0, 0.0, 0.0),
					&"LeftUpperLeg": Vector3(12.0, 0.0, 0.0), &"RightUpperLeg": Vector3(12.0, 0.0, 0.0)})),
				_k(0.5, down)]
		&"knockdown_forward":
			length = 0.5
			var down_f := PlaceholderPoses.downed_front()
			keys = [_k(0.0, PlaceholderPoses.buckle(g)), _k(FALL_JOIN_S[id], PlaceholderPoses.falling_front()),
				_k(0.36, PlaceholderPoses.add(down_f, {&"Spine": Vector3(8.0, 0.0, 0.0),
					&"Neck": Vector3(10.0, 0.0, 0.0)})),
				_k(0.5, down_f)]
		&"downed_back", &"downed_front":
			length = 2.0
			var lying := PlaceholderPoses.downed_back() if id == &"downed_back" else PlaceholderPoses.downed_front()
			# Slow breathing: the chest curls a little away from the floor and back.
			var lift := -1.0 if id == &"downed_back" else 1.0
			keys = [_k(0.0, lying), _k(1.0, PlaceholderPoses.add(lying, {
				&"Spine": Vector3(lift * 3.0, 0.0, 0.0), &"Chest": Vector3(lift * 2.0, 0.0, 0.0)})),
				_k(2.0, lying)]
		&"getup_back":
			length = 0.5
			keys = [_k(0.0, PlaceholderPoses.downed_back()), _k(0.18, PlaceholderPoses.getup_back_sit()),
				_k(0.34, PlaceholderPoses.getup_crouch(g)), _k(0.5, g)]
		&"getup_front":
			length = 0.5
			keys = [_k(0.0, PlaceholderPoses.downed_front()), _k(0.2, PlaceholderPoses.getup_front_push()),
				_k(0.36, PlaceholderPoses.getup_crouch(g)), _k(0.5, g)]
		&"ko_back":
			length = 0.8
			var ko := PlaceholderPoses.ko_back()
			keys = [_k(0.0, PlaceholderPoses.buckle(g)), _k(FALL_JOIN_S[id], PlaceholderPoses.falling_back()),
				_k(0.52, PlaceholderPoses.add(ko, {&"Spine": Vector3(-8.0, 0.0, 0.0),
					&"LeftUpperLeg": Vector3(10.0, 0.0, 0.0), &"RightUpperLeg": Vector3(14.0, 0.0, 0.0)})),
				_k(0.8, ko)]
		&"ko_front":
			length = 0.8
			var ko_f := PlaceholderPoses.ko_front()
			keys = [_k(0.0, PlaceholderPoses.buckle(g)), _k(FALL_JOIN_S[id], PlaceholderPoses.falling_front()),
				_k(0.52, PlaceholderPoses.add(ko_f, {&"Spine": Vector3(8.0, 0.0, 0.0)})),
				_k(0.8, ko_f)]
		_:
			push_warning("PlaceholderAnims: unknown animation id '%s'" % id)
			keys = [_k(0.0, g), _k(length, g)]
	return make(keys, length, LOOPING.has(id), scale)


## Animation for `move` in `stance`: length move.total_frames() / 60 s; the move's start
## pose (the stance, the clinch or a weapon carry, PlaceholderPoses.move_poses()) at 0, the
## wind-up at windup_at x startup, the strike pose exactly at startup / 60 s held until
## (startup + active) / 60 s, an optional follow-through, and back to the start pose at the
## end. `mirrored` swaps the upper body left for right, keeping the legs (the body flurry
## alternates fists this way). `from_charge` starts from the wind-up pose instead
## (released out of its CHARGE_ANIMS animation, which ends on that pose), so the startup
## holds the cocked pose until the wind-up time and then drives into the strike. Ids
## without a recipe fall back to a generic punch or kick picked from the first hitbox.
static func build_move(move: MoveData, scale: float, mirrored: bool = false,
		from_charge: bool = false, stance: StringName = PlaceholderPoses.STANCE_BOXER) -> Animation:
	var poses := _poses_for(move, stance)
	if mirrored:
		poses = poses.mirrored(true)
	var startup := move.startup * FRAME_S
	var active := move.active * FRAME_S
	var recovery := move.recovery * FRAME_S
	var length := maxi(move.total_frames(), 1) * FRAME_S
	var keys: Array[PoseKey] = []
	if move.startup > 0:
		keys.append(_k(0.0, poses.windup if from_charge else poses.guard))
		keys.append(_k(windup_time(move, poses), poses.windup))
	keys.append(_k(startup, poses.strike))
	var strike_end := poses.strike if poses.strike_end.is_empty() else poses.strike_end
	if move.active > 0:
		keys.append(_k(startup + active, strike_end))
	if move.recovery > 0:
		if not poses.follow.is_empty():
			keys.append(_k(startup + active + recovery * clampf(poses.follow_at, 0.05, 0.95), poses.follow))
		keys.append(_k(length, poses.guard if poses.finish.is_empty() else poses.finish))
	return make(keys, length, false, scale)


## Seconds into `move`'s animation where its wind-up pose is keyed. `poses` defaults to
## the move's recipe (or its fallback).
static func windup_time(move: MoveData, poses: PlaceholderPoses.MovePoses = null) -> float:
	if poses == null:
		poses = _poses_for(move)
	return move.startup * FRAME_S * clampf(poses.windup_at, 0.05, 0.95)


static func _poses_for(move: MoveData,
		stance: StringName = PlaceholderPoses.STANCE_BOXER) -> PlaceholderPoses.MovePoses:
	var poses := PlaceholderPoses.move_poses(move.get_anim(), stance)
	return poses if poses != null else _fallback_poses(move, stance)


## The first hitbox's strike point, or &"RightFootPoint" for an arc (spins are kicks).
static func _fallback_point(move: MoveData) -> StringName:
	if move.hitboxes.is_empty() or move.hitboxes[0] == null:
		return &""
	var spec: HitboxSpec = move.hitboxes[0]
	return spec.point if spec.kind == HitboxSpec.Kind.POINT_SPHERE else &"RightFootPoint"


## True when a move without a recipe falls back to the generic kick (its first hitbox is
## on a leg, or is an arc), false for the generic punch.
static func fallback_is_kick(move: MoveData) -> bool:
	var point := String(_fallback_point(move))
	return point.contains("Foot") or point.contains("Knee") or point.contains("Toes") \
			or point.contains("Leg")


static func _fallback_poses(move: MoveData, stance: StringName) -> PlaceholderPoses.MovePoses:
	var is_kick := fallback_is_kick(move)
	if warn_on_fallback:
		push_warning("HumanoidRig: no animation recipe for move '%s'; using a generic %s" % [
				move.get_anim(), "kick" if is_kick else "punch"])
	var poses := PlaceholderPoses.generic_kick(stance) if is_kick else PlaceholderPoses.generic_punch(stance)
	return poses.mirrored() if String(_fallback_point(move)).begins_with("Left") else poses


## `base` with the leg angles of `legs_from`.
static func _legs(base: Dictionary[StringName, Vector3],
		legs_from: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	return PlaceholderPoses.merge(base, PlaceholderPoses.only(legs_from, PlaceholderPoses.LEG_BONES))


## Build an Animation from pose keys (any order; a later key at the same time wins).
static func make(keys: Array[PoseKey], length: float, loop: bool, scale: float) -> Animation:
	var sorted: Array[PoseKey] = []
	for key: PoseKey in keys:
		var t := clampf(key.time, 0.0, length)
		var replaced := false
		for i: int in sorted.size():
			if is_equal_approx(sorted[i].time, t):
				sorted[i] = PoseKey.new(t, key.pose)
				replaced = true
		if not replaced:
			sorted.append(PoseKey.new(t, key.pose))
	sorted.sort_custom(func(x: PoseKey, y: PoseKey) -> bool: return x.time < y.time)
	for key: PoseKey in sorted:
		key.hips = resolve_hips(key.pose)
	sorted = _subdivide(sorted)

	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for bone: StringName in animated_bones():
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, NodePath("Skeleton3D:%s" % bone))
		anim.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		for key: PoseKey in sorted:
			var euler: Vector3 = key.pose.get(bone, Vector3.ZERO)
			anim.rotation_track_insert_key(track, key.time,
					PlaceholderBody.euler_basis(euler).get_rotation_quaternion())
	# The Hips position track is keyed on every animation (constant when the hips stay
	# put) so a cross-fade never leaves the hips where an earlier animation put them.
	var hips_track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hips_track, NodePath("Skeleton3D:Hips"))
	anim.track_set_interpolation_type(hips_track, Animation.INTERPOLATION_LINEAR)
	var rest: Vector3 = PlaceholderBody.BONE_REST[&"Hips"]
	for key: PoseKey in sorted:
		anim.position_track_insert_key(hips_track, key.time, (rest + key.hips) * scale)
	return anim


## Hips offset for a pose (meters at reference height): the explicit HIPS_POS, or the
## offset that plants the lowest sole point on y = 0 plus any HIPS_NUDGE.
static func resolve_hips(pose: Dictionary[StringName, Vector3]) -> Vector3:
	if pose.has(PlaceholderPoses.HIPS_POS):
		return pose[PlaceholderPoses.HIPS_POS]
	var globals := PlaceholderBody.pose_globals(pose, Vector3.ZERO, 1.0)
	var planted := Vector3(0.0, -PlaceholderBody.lowest_sole(globals, 1.0), 0.0)
	var nudge: Vector3 = pose.get(PlaceholderPoses.HIPS_NUDGE, Vector3.ZERO)
	return planted + nudge


## Insert in-between keys wherever an angle jumps more than MAX_STEP_DEG between keys.
static func _subdivide(keys: Array[PoseKey]) -> Array[PoseKey]:
	if keys.size() < 2:
		return keys
	var out: Array[PoseKey] = [keys[0]]
	for i: int in range(1, keys.size()):
		var a := keys[i - 1]
		var b := keys[i]
		var biggest := 0.0
		for bone: StringName in _union_keys(a.pose, b.pose):
			if not PlaceholderPoses.is_bone_key(bone):
				continue
			var d: Vector3 = b.pose.get(bone, Vector3.ZERO) - a.pose.get(bone, Vector3.ZERO)
			biggest = maxf(biggest, maxf(absf(d.x), maxf(absf(d.y), absf(d.z))))
		var steps := ceili(biggest / MAX_STEP_DEG)
		for s: int in range(1, steps):
			var w := float(s) / steps
			var mid: Dictionary[StringName, Vector3] = {}
			for bone: StringName in _union_keys(a.pose, b.pose):
				if not PlaceholderPoses.is_bone_key(bone):
					continue
				mid[bone] = (a.pose.get(bone, Vector3.ZERO) as Vector3).lerp(b.pose.get(bone, Vector3.ZERO), w)
			var key := PoseKey.new(lerpf(a.time, b.time, w), mid)
			key.hips = a.hips.lerp(b.hips, w)
			out.append(key)
		out.append(b)
	return out


static func _union_keys(a: Dictionary[StringName, Vector3], b: Dictionary[StringName, Vector3]) -> Array[StringName]:
	var out: Array[StringName] = []
	for key: StringName in a:
		out.append(key)
	for key: StringName in b:
		if not out.has(key):
			out.append(key)
	return out
