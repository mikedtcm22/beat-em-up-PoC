class_name Ragdoll
extends SkeletonModifier3D
## The visual ragdoll of a HumanoidRig (Spec §6 "Hit reactions"; docs/ARCHITECTURE.md
## "Ragdoll"). A presentation layer over the animation: the simulation (the CombatActor's
## body, hurtboxes, rig points, get_point_transform()) never reads it, except where a body
## gets up (HumanoidRig.ragdoll_hips_offset()).
##
## Built once per rig, on its first ragdoll (HumanoidRig.ragdoll_start()): a
## PhysicalBoneSimulator3D under the skeleton with one PhysicalBone3D per
## PlaceholderBody.ragdoll_specs() bone, joints between them with human limits (cone twist,
## hinges for elbows, knees and ankles), and this modifier after the simulator. Idle, both
## modifiers are inactive and the bodies static with no collision layer, and they ignore
## their parents' moves (no transform notifications): no cost, and the visuals are exactly
## the animation's.
##
## Modes:
##   PARTIAL (staggers): the upper body (Spine and up, the arms) simulates on the hips and
##     legs, which stay kinematic on the animation; the simulator's influence
##     (Tuning.ragdoll_partial_influence) blends it over the animation, holds, fades back to
##     the animation and stops.
##   FULL (a body knocked off its feet, and a KO): every body simulates; its influence rises
##     from 0 to 1 over Tuning.ragdoll_full_rise_s (from a stagger too), so the animation's
##     snap of the hit shows first and the bodies take over from it.
## Either way soft pose springs pull each simulated bone toward the animation's pose
## re-anchored on the hips as they are (per phase: a stagger, flight, lying down, and a
## nearly limp KO; the turns stronger while a FULL ragdoll's influence rises), with each
## turn target kept inside its joint's limits from its parent body. A FULL ragdoll as a whole is pulled toward the
## animation's hips (Tuning.ragdoll_hips_hz) and turned as one toward their rotation (or,
## flying to a face-down landing, toward the lying pose's: aim_landing()), so the visible
## body never drifts from the sim body and a downed body lies where its hurtboxes are. A
## hit adds a kick on the struck part, landing at the contact point
## (Tuning.ragdoll_kick_at_contact): a central kick, plus the twist of its off-center part
## on the struck body and its parents, turned as one from their joint and capped per part
## (_twist_at_contact()). A lying body comes to rest and sleeps.
##
## Time: the bodies run in the actor's sim time (HumanoidRig passes
## TimeController.scale_for(actor) every tick, sim_scale): when the scale changes from a to
## b their velocities scale by b/a, gravity by b² and damping by b; at 0 (the actor's
## hitstop) they hold still, their velocities kept. The physics step of the frame a kick
## was queued (the hit's frame, whose hitstop starts on the next) holds still too, so a kick
## lands on the first step after the hitstop. Engine.time_scale stays 1. Gravity, damping
## and the springs are applied here, as velocity changes before each physics step (the
## bodies' own gravity is off).
##
## Visuals: this modifier runs after the simulator in the skeleton's deferred update (the
## end of the physics frame, after every actor has posed), reads the post-modifier local
## poses and moves the rig's bone followers (meshes and attachments) to them. In a PARTIAL
## ragdoll the neck and head, and the arms unless the kick landed on them, show less of the
## simulation on their joints (Tuning.ragdoll_partial_head_influence, _arm_influence): they
## ride the trunk as it gives way instead of lolling or trailing behind it.

enum Mode { NONE, PARTIAL, FULL }
## The body part a hit's impulse lands on (the struck hurtbox's region, or the striking
## arm of a parried attacker); ANY = the body nearest to the contact.
enum Part { ANY, HEAD, TORSO, ARMS, LEGS }
## Which pose-spring strength a running ragdoll uses (see the Tuning "Ragdoll" group).
enum Phase { STAGGER, FLIGHT, DOWN, LIMP }

## The bodies of each Part (bone names without their Left/Right side).
const PART_BONES: Dictionary[Part, Array] = {
	Part.HEAD: [&"Head", &"Neck"],
	Part.TORSO: [&"Hips", &"Spine", &"Chest", &"UpperChest"],
	Part.ARMS: [&"Shoulder", &"UpperArm", &"LowerArm"],
	Part.LEGS: [&"UpperLeg", &"LowerLeg", &"Foot"],
}

## Bones that simulate in a PARTIAL ragdoll (the upper body); the rest stay kinematic.
const PARTIAL_BONES: Array[StringName] = [
	&"Spine", &"Chest", &"UpperChest", &"Neck", &"Head",
	&"LeftShoulder", &"LeftUpperArm", &"LeftLowerArm",
	&"RightShoulder", &"RightUpperArm", &"RightLowerArm",
]

## The rig this ragdoll belongs to (setup()).
var rig: HumanoidRig
## The modifier that runs the bodies; it sits before this one under the skeleton.
var simulator: PhysicalBoneSimulator3D
## NONE while idle, otherwise the running mode.
var mode: Mode = Mode.NONE
## The pose springs a running ragdoll uses (set_phase()).
var phase: Phase = Phase.FLIGHT
## The actor's sim time scale this tick (set by the rig every tick while running).
var sim_scale: float = 1.0
## True while a lying ragdoll is at rest (every body asleep).
var asleep: bool = false
## The rig's world transform when the visual pose (visual_pose()) was last read.
var visual_rig_transform: Transform3D = Transform3D.IDENTITY

## Per body (PlaceholderBody.ragdoll_specs() order, parents before children): the node, its
## skeleton bone index, its mass and its parent body (-1 for the Hips, the root).
var _bodies: Array[PhysicalBone3D] = []
var _bone_of: PackedInt32Array = PackedInt32Array()
var _mass: PackedFloat32Array = PackedFloat32Array()
var _parent_body: PackedInt32Array = PackedInt32Array()
## Each body's Part, and its shape's center in its bone's frame.
var _part: Array[Part] = []
var _center: PackedVector3Array = PackedVector3Array()
## Per skeleton bone: the Part of its body, or -1 for a bone without one.
var _bone_part: PackedInt32Array = PackedInt32Array()
## The Part a PARTIAL's latest kick landed on (its arms keep the full influence).
var _partial_part: Part = Part.ANY
## Each body's joint to its parent (PlaceholderBody.RagdollSpec): its spec, and its frames
## in the parent's and its own bone frame (as _make_joint() builds them; cone twists only).
var _spec: Array[PlaceholderBody.RagdollSpec] = []
var _frame_a: Array[Quaternion] = []
var _frame_b: Array[Quaternion] = []
var _joints: Array[RID] = []
## Bodies simulating now (indices into _bodies).
var _sim: PackedInt32Array = PackedInt32Array()
## The scale the bodies' velocities are in now, and their sim velocities kept through a
## freeze (scale 0).
var _applied_scale: float = 1.0
## Asleep through a freeze (scale 0), not at rest.
var _frozen: bool = false
var _held_lin: Array[Vector3] = []
var _held_ang: Array[Vector3] = []
## Kicks waiting for the next unfrozen step: [body index, sim velocity change, the contact
## (world) whose twist the body takes, or null] (_queue_impulse()).
var _pending: Array[Array] = []
## The physics frame the latest ragdoll start or kick came in (its step holds still).
var _hold_frame: int = -1
## Each body's animation pose (world) last step, for the targets' velocities.
var _prev_anim: Array[Transform3D] = []
var _has_prev: bool = false
## Sim seconds since a PARTIAL started, and its hold and fade lengths.
var _partial_t: float = 0.0
var _partial_hold: float = 0.0
var _partial_fade: float = 0.0
## The influence rise of the latest start(): from this influence, over this many sim
## seconds (0 = none), and the sim seconds risen so far.
var _rise_from: float = 0.0
var _rise_s: float = 0.0
var _rise_t: float = 0.0
## A flight that lands face down turns the whole body toward this hips rotation (rig
## space) instead of the flying animation's (aim_landing()).
var _landing: Quaternion = Quaternion.IDENTITY
var _aims_landing: bool = false
## Sim seconds calm and lying (rest detection).
var _calm_s: float = 0.0
var _lying_s: float = 0.0
## Skeleton-space post-ragdoll pose of every bone after the latest update.
var _visual: Array[Transform3D] = []
## Per Part: the fastest the contact push has turned a struck body of it (sim rad/s), since
## the ragdoll was built (top_contact_twist(); for tests).
var _top_twist: Dictionary[Part, float] = {}


## Build the bodies and joints for `p_rig` (once). Adds the simulator and this modifier to
## its skeleton, both inactive.
func setup(p_rig: HumanoidRig) -> void:
	rig = p_rig
	name = "Ragdoll"
	active = false
	var skeleton := rig.skeleton
	simulator = PhysicalBoneSimulator3D.new()
	simulator.name = "RagdollSimulator"
	simulator.active = false
	skeleton.add_child(simulator)
	skeleton.add_child(self)
	var scale := rig.rig_scale()
	var specs := PlaceholderBody.ragdoll_specs()
	var body_of: Dictionary[StringName, int] = {}
	for spec: PlaceholderBody.RagdollSpec in specs:
		var body := PhysicalBone3D.new()
		body.name = "Ragdoll%s" % spec.bone
		body.set(&"bone_name", spec.bone)
		body.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
		body.mass = maxf(spec.mass_share * PlaceholderBody.RAGDOLL_MASS * scale * scale * scale, 0.01)
		body.gravity_scale = 0.0
		body.linear_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
		body.angular_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
		body.linear_damp = 0.0
		body.angular_damp = 0.0
		body.can_sleep = true
		var shape := CollisionShape3D.new()
		shape.shape = _make_shape(spec, scale)
		shape.position = spec.offset * scale
		shape.rotation_degrees = spec.rot_deg
		body.add_child(shape)
		simulator.add_child(body)
		# Idle, a body ignores the actor's moves (the server would move every static body
		# each frame the actor walks); start() puts it onto the pose on screen.
		body.set_notify_transform(false)
		# A light hand or foot flung onto the floor does not tunnel into it.
		PhysicsServer3D.body_set_enable_continuous_collision_detection(body.get_rid(), true)
		_parent_body.append(body_of.get(PlaceholderBody.BONE_PARENT.get(spec.bone, &""), -1))
		body_of[spec.bone] = _bodies.size()
		_bodies.append(body)
		_bone_of.append(skeleton.find_bone(spec.bone))
		_mass.append(body.mass)
		_center.append(spec.offset * scale)
		_spec.append(spec)
		var along := Quaternion(Vector3.RIGHT, spec.axis)
		_frame_b.append(along)
		_frame_a.append(Quaternion(spec.axis, spec.center) * along)
		var part := Part.ANY
		var side_free := String(spec.bone).trim_prefix("Left").trim_prefix("Right")
		for key: Part in PART_BONES:
			if PART_BONES[key].has(StringName(side_free)):
				part = key
		_part.append(part)
	_held_lin.resize(_bodies.size())
	_held_ang.resize(_bodies.size())
	_prev_anim.resize(_bodies.size())
	_visual.resize(skeleton.get_bone_count())
	_bone_part.resize(skeleton.get_bone_count())
	_bone_part.fill(-1)
	for i: int in _bodies.size():
		_bone_part[_bone_of[i]] = _part[i]
	apply_tuning()
	Tuning.changed.connect(_on_tuning_changed)
	_build_joints()
	for i: int in specs.size():
		for j: int in i:
			PhysicsServer3D.body_add_collision_exception(_bodies[i].get_rid(), _bodies[j].get_rid())


func _enter_tree() -> void:
	# Back in the tree after leaving it (pooled, reparented): the joints _exit_tree() freed
	# come back.
	if not _bodies.is_empty() and _joints.is_empty():
		_build_joints()


func _exit_tree() -> void:
	for joint: RID in _joints:
		if joint.is_valid():
			PhysicsServer3D.free_rid(joint)
	_joints.clear()


## Re-read the body tuning (friction, bounce, collision with other ragdolls).
func apply_tuning() -> void:
	var tuning := Tuning.data
	var mask := CombatTypes.bit(CombatTypes.LAYER_WORLD)
	if tuning.ragdoll_collide_ragdolls:
		mask |= CombatTypes.bit(CombatTypes.LAYER_RAGDOLL)
	for i: int in _bodies.size():
		var body := _bodies[i]
		body.friction = tuning.ragdoll_friction
		body.bounce = tuning.ragdoll_bounce
		# The node keeps the layers the simulator gives a body when it simulates; a body not
		# simulating (idle, or a PARTIAL's kinematic hips and legs) stays on none (setting them
		# reaches the server at once).
		body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_RAGDOLL)
		body.collision_mask = mask
		if not _sim.has(i):
			PhysicsServer3D.body_set_collision_layer(body.get_rid(), 0)
			PhysicsServer3D.body_set_collision_mask(body.get_rid(), 0)


func _on_tuning_changed(_property: StringName) -> void:
	apply_tuning()


## True while a PARTIAL or FULL ragdoll runs.
func is_running() -> bool:
	return mode != Mode.NONE


## Start (or switch to) `new_mode` from the pose on screen. `contact` and `push` (world, m/s)
## place the hit's kick (scaled by the mode's impulse tuning) on the `part` body nearest to
## the contact; every body that starts simulating also gets `body_velocity` (the actor's
## new sim velocity, world m/s, times Tuning.ragdoll_inherit_velocity) on top of the
## velocity its bone already had in the animation (`bone_velocity`, sim m/s per skeleton
## bone; may be empty; a PARTIAL drops the part of it running against the push, so a parried
## jab's arm does not carry on into the defender). `partial_length_s` caps a PARTIAL's hold
## and fade (the stagger's length). Bodies already simulating keep their pose and motion:
## the influence rises from what showed, so nothing jumps. A FULL ragdoll started `at_once`
## shows alone from the start, taking over from the pose on screen instead of rising in from
## the animation's snap (a body launched out of a hold leaves from its held pose).
func start(new_mode: Mode, contact: Vector3, push: Vector3, body_velocity: Vector3,
		bone_velocity: Array[Vector3], part: Part = Part.ANY, partial_length_s: float = INF,
		at_once: bool = false) -> void:
	if new_mode == Mode.NONE:
		stop()
		return
	var tuning := Tuning.data
	var was := mode
	var previous_sim := _sim.duplicate()
	var shown_influence := simulator.influence if was != Mode.NONE else 0.0
	# The pose on screen, before the simulator takes over (world).
	var shown: Array[Transform3D] = []
	for i: int in _bodies.size():
		shown.append(_world_visual(_bone_of[i]))
	mode = new_mode
	phase = Phase.STAGGER if new_mode == Mode.PARTIAL else Phase.FLIGHT
	_wake()
	# A freeze running on re-freezes every body (the new ones too) on the next step.
	if _frozen:
		_frozen = false
		for i: int in _sim:
			PhysicsServer3D.body_set_state(_bodies[i].get_rid(), PhysicsServer3D.BODY_STATE_SLEEPING, false)
	if new_mode == Mode.PARTIAL:
		_partial_part = part
		_partial_t = 0.0
		var length := maxf(partial_length_s, 0.0)
		_partial_hold = minf(tuning.ragdoll_partial_hold_s, length)
		_partial_fade = minf(tuning.ragdoll_partial_fade_s, maxf(length - _partial_hold, 0.0))
	_calm_s = 0.0
	_lying_s = 0.0
	_hold_frame = Engine.get_physics_frames()
	if was != Mode.FULL:
		_aims_landing = false
	if was == Mode.FULL and new_mode == Mode.FULL:
		# Already flying or lying: only the new hit's kick.
		_queue_impulse(contact, push * tuning.ragdoll_full_impulse, part)
		return
	# The influence rises from what shows: a fresh stagger's bodies start on the animation,
	# so it shows at once; a stagger on a stagger rises back from where its fade had got to.
	# A body knocked off its feet shows the animation's snap first, from standing or
	# staggering alike (the hit's frame snaps into the hit's pose, as without a ragdoll),
	# unless it takes over at once.
	_rise_t = 0.0
	_rise_from = shown_influence
	if new_mode == Mode.FULL:
		_rise_from = 1.0 if at_once else 0.0
		_rise_s = 0.0 if at_once else tuning.ragdoll_full_rise_s
	elif was == Mode.PARTIAL:
		_rise_s = tuning.ragdoll_partial_rise_s
	else:
		_rise_from = tuning.ragdoll_partial_influence
		_rise_s = 0.0
	simulator.influence = _rise_from
	var names: Array[StringName] = []
	_sim.clear()
	for i: int in _bodies.size():
		var bone := rig.skeleton.get_bone_name(_bone_of[i])
		if new_mode == Mode.FULL or PARTIAL_BONES.has(StringName(bone)):
			names.append(StringName(bone))
			_sim.append(i)
	if was == Mode.NONE:
		# Still static: every body jumps onto the pose on screen. (A kinematic body set
		# later would sweep there from wherever it was left, dragging its joints along.)
		for i: int in _bodies.size():
			PhysicsServer3D.body_set_state(_bodies[i].get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, shown[i])
	simulator.active = true
	active = true
	simulator.physical_bones_start_simulation(names)
	var scale := maxf(sim_scale, 0.0)
	var inherit := body_velocity * tuning.ragdoll_inherit_velocity
	var away := push.normalized() if push.length_squared() > 1e-8 else Vector3.ZERO
	for i: int in _sim:
		var rid := _bodies[i].get_rid()
		if previous_sim.has(i):
			_rescale_body(i, _applied_scale, scale)
			continue
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, shown[i])
		var lin := inherit
		if not bone_velocity.is_empty():
			var bone_v := bone_velocity[_bone_of[i]]
			if new_mode == Mode.PARTIAL:
				bone_v -= away * minf(bone_v.dot(away), 0.0)
			lin += bone_v
		lin = lin.limit_length(tuning.ragdoll_max_speed)
		_held_lin[i] = lin
		_held_ang[i] = Vector3.ZERO
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, lin * scale)
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	_applied_scale = scale
	# The kinematic bodies of a PARTIAL stay off every layer (apply_tuning()).
	apply_tuning()
	var impulse_scale := tuning.ragdoll_partial_impulse if new_mode == Mode.PARTIAL else tuning.ragdoll_full_impulse
	_pending.clear()
	_queue_impulse(contact, push * impulse_scale, part)
	_has_prev = false


## An extra hit on a running ragdoll (a stomp on a downed body): wakes it and adds a kick
## of `push` (world m/s) on the `part` body nearest to `contact`.
func hit(contact: Vector3, push: Vector3, part: Part = Part.ANY) -> void:
	if mode == Mode.NONE:
		return
	_wake()
	_calm_s = 0.0
	_lying_s = 0.0
	_hold_frame = Engine.get_physics_frames()
	_queue_impulse(contact, push, part)


## A FULL ragdoll flying to a face-down landing: while it flies, the whole body turns toward
## `hips_rotation` (rig space; the lying animation's hips), not toward the flying
## animation's (a back-arched launch pose that the animation flips over on landing, which a
## body on the floor cannot do): the body pitches over in the air and lands face down.
func aim_landing(hips_rotation: Quaternion) -> void:
	if mode != Mode.FULL:
		return
	_landing = hips_rotation.normalized()
	_aims_landing = true


## Switch a running ragdoll's pose springs (a FULL ragdoll lands: DOWN, or is KO'd: LIMP).
func set_phase(new_phase: Phase) -> void:
	if mode == Mode.NONE:
		return
	if new_phase != Phase.FLIGHT:
		_aims_landing = false
	if new_phase != phase:
		_calm_s = 0.0
		if new_phase == Phase.LIMP:
			_wake()
	phase = new_phase


## Stop simulating: the bodies go back to static with no collision, and the visuals to the
## animation (HumanoidRig fades from the last visual pose).
func stop() -> void:
	if mode == Mode.NONE:
		return
	mode = Mode.NONE
	asleep = false
	_frozen = false
	_sim.clear()
	_pending.clear()
	simulator.physical_bones_stop_simulation()
	simulator.active = false
	active = false


## Skeleton-space post-ragdoll pose of skeleton bone `bone` after the latest update.
func visual_pose(bone: int) -> Transform3D:
	return _visual[bone]


## Largest sim speed (m/s) of any simulating body (0 when none). For tests.
func max_body_speed() -> float:
	var top := 0.0
	var scale := _applied_scale
	for i: int in _sim:
		var rid := _bodies[i].get_rid()
		var lin: Vector3 = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY)
		top = maxf(top, lin.length() / scale if scale > 0.0 else _held_lin[i].length())
	return top


## Largest sim spin (rad/s) of any simulating body, and of the bodies on these skeleton
## bones if `bones` is not empty (0 when none). For tests.
func max_body_spin(bones: Array[StringName] = []) -> float:
	var top := 0.0
	for i: int in _sim:
		if not bones.is_empty() and not bones.has(_spec[i].bone):
			continue
		var ang: Vector3 = PhysicsServer3D.body_get_state(_bodies[i].get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY)
		top = maxf(top, ang.length() / _applied_scale if _applied_scale > 0.0 else _held_ang[i].length())
	return top


## The simulating bodies' world transforms (for tests and debug draw).
func body_transforms() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for i: int in _sim:
		out.append(PhysicsServer3D.body_get_state(_bodies[i].get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM))
	return out


## Kicks waiting for a step to land in (for tests).
func pending_kicks() -> int:
	return _pending.size()


## Sim velocity (m/s) of the simulating body on bone `bone`, or zero (for tests).
func body_sim_velocity(bone: StringName) -> Vector3:
	for i: int in _sim:
		if _spec[i].bone != bone:
			continue
		if _frozen or _applied_scale <= 0.0:
			return _held_lin[i]
		var lin: Vector3 = PhysicsServer3D.body_get_state(_bodies[i].get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY)
		return lin / _applied_scale
	return Vector3.ZERO


## Sim spin (rad/s) of the simulating body on bone `bone`, or zero (for tests).
func body_sim_spin(bone: StringName) -> Vector3:
	for i: int in _sim:
		if _spec[i].bone != bone:
			continue
		if _frozen or _applied_scale <= 0.0:
			return _held_ang[i]
		var ang: Vector3 = PhysicsServer3D.body_get_state(_bodies[i].get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY)
		return ang / _applied_scale
	return Vector3.ZERO


## The fastest the kick at the contact point has turned a struck body of `part` (sim rad/s,
## as its spin changed), since the ragdoll was built; 0 if none was struck. For tests: each
## stays within its part's cap (Tuning.ragdoll_contact_spin_*).
func top_contact_twist(part: Part) -> float:
	return _top_twist.get(part, 0.0)


## The joints that exist now (for tests).
func joint_count() -> int:
	return _joints.filter(func(joint: RID) -> bool: return joint.is_valid()).size()


## The farthest any simulating body's joint has pulled apart: meters between its bone
## origin and its anchor on the parent body (for tests).
func joint_stretch() -> float:
	var worst := 0.0
	var scale := rig.rig_scale()
	for i: int in _sim:
		var parent := _parent_body[i]
		if parent < 0:
			continue
		var parent_xf: Transform3D = PhysicsServer3D.body_get_state(_bodies[parent].get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
		var child_xf: Transform3D = PhysicsServer3D.body_get_state(_bodies[i].get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
		var anchor: Vector3 = parent_xf * (PlaceholderBody.BONE_REST[_spec[i].bone] * scale)
		worst = maxf(worst, anchor.distance_to(child_xf.origin))
	return worst


# --- Skeleton update ------------------------------------------------------------------


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or rig == null:
		return
	var head_share := 1.0
	var arm_share := 1.0
	if mode == Mode.PARTIAL:
		var tuning := Tuning.data
		head_share = _partial_share(tuning.ragdoll_partial_head_influence)
		if _partial_part != Part.ARMS:
			arm_share = _partial_share(tuning.ragdoll_partial_arm_influence)
	for i: int in skeleton.get_bone_count():
		var local := skeleton.get_bone_pose(i)
		var parent := skeleton.get_bone_parent(i)
		var share := 1.0
		match _bone_part[i]:
			Part.HEAD:
				share = head_share
			Part.ARMS:
				share = arm_share
		if share < 1.0 and parent >= 0:
			# The simulator blended this joint's turn from the animation's by its influence;
			# this joint shows `share` of that (the same arc, so share x influence of it).
			var anim := (rig.animation_pose(parent).basis.inverse() * rig.animation_pose(i).basis).get_rotation_quaternion()
			local = Transform3D(Basis(anim.slerp(local.basis.get_rotation_quaternion(), share)), local.origin)
		_visual[i] = local if parent < 0 else _visual[parent] * local
	visual_rig_transform = rig.global_transform
	rig.show_visual_pose(_visual)
	if mode != Mode.NONE:
		_step()


## One physics tick of control, before the physics step: time scale, gravity, damping, the
## springs, kicks, the influence (rise, PARTIAL fade) and rest.
func _step() -> void:
	var tuning := Tuning.data
	var dt := 1.0 / Engine.physics_ticks_per_second
	var scale := maxf(sim_scale, 0.0)
	if Engine.get_physics_frames() == _hold_frame:
		# The frame a ragdoll started or took a kick: the hit's hitstop starts on the next
		# one, so this step holds still and the kick lands after the hitstop.
		scale = 0.0
	var states: Array[PhysicsDirectBodyState3D] = []
	for i: int in _sim:
		states.append(PhysicsServer3D.body_get_direct_state(_bodies[i].get_rid()))
	# How fast the bodies moved in the last physics step (sim m/s), before this step adds
	# gravity and the springs: rest detection.
	var moving := INF
	if not _frozen and _applied_scale > 0.0:
		moving = 0.0
		for state: PhysicsDirectBodyState3D in states:
			moving = maxf(moving, state.linear_velocity.length() / _applied_scale)
	if asleep:
		var woke := false
		for state: PhysicsDirectBodyState3D in states:
			woke = woke or not state.sleeping
		if not woke:
			_applied_scale = scale
			return
		# A contact woke it (another body fell on it): it settles again from now.
		asleep = false
		_calm_s = 0.0
		_lying_s = 0.0
		_has_prev = false
	if scale <= 0.0:
		# Frozen (the actor's hitstop): the velocities are kept and the bodies put to sleep,
		# so the solver moves nothing at all (it would replay the last step's joint impulses).
		if not _frozen:
			_rescale(states, 0.0)
			for state: PhysicsDirectBodyState3D in states:
				state.sleeping = true
			_frozen = true
		_has_prev = false
		return
	if _frozen:
		_frozen = false
		for state: PhysicsDirectBodyState3D in states:
			state.sleeping = false
	_rescale(states, scale)
	# The waiting kicks land first, so the speed caps below hold them too.
	_apply_pending(states, scale)
	var sim_dt := dt * scale
	var influence := 1.0
	if mode == Mode.PARTIAL:
		_partial_t += sim_dt
		var fade_t := _partial_t - _partial_hold
		if fade_t >= _partial_fade:
			stop()
			return
		var w := 1.0 - fade_t / _partial_fade if fade_t > 0.0 else 1.0
		influence = tuning.ragdoll_partial_influence * w
	_rise_t += sim_dt
	var rise := clampf(_rise_t / _rise_s, 0.0, 1.0) if _rise_s > 0.0 else 1.0
	rise = smoothstep(0.0, 1.0, rise)
	simulator.influence = lerpf(_rise_from, influence, rise)
	# Every body's animation pose (world) and its angular velocity (real rad/s).
	var to_world := rig.global_transform
	var anim: Array[Transform3D] = []
	var anim_q: Array[Quaternion] = []
	var anim_w: Array[Vector3] = []
	for i: int in _bodies.size():
		var pose := to_world * rig.animation_pose(_bone_of[i])
		anim.append(pose)
		anim_q.append(pose.basis.get_rotation_quaternion())
		anim_w.append(_turn_rate(_prev_anim[i].basis, pose.basis, dt) if _has_prev else Vector3.ZERO)
	# Body index -> its state's index (-1: not simulating).
	var k_of := PackedInt32Array()
	k_of.resize(_bodies.size())
	k_of.fill(-1)
	for k: int in _sim.size():
		k_of[_sim[k]] = k
	if mode == Mode.PARTIAL:
		# The kinematic hips and legs ride the animation (this tick's pose, not the
		# simulator's copy from the last update).
		for i: int in _bodies.size():
			if k_of[i] < 0:
				PhysicsServer3D.body_set_state(_bodies[i].get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, anim[i])
	var hips_target := anim[0].origin
	var hips_target_v := (hips_target - _prev_anim[0].origin) / dt if _has_prev else Vector3.ZERO
	var gravity_mult := tuning.ragdoll_partial_gravity if mode == Mode.PARTIAL else tuning.ragdoll_gravity_mult
	var gravity := Vector3.DOWN * tuning.gravity * gravity_mult * scale * scale * dt
	var lin_keep := maxf(1.0 - tuning.ragdoll_linear_damp * scale * dt, 0.0)
	var ang_keep := maxf(1.0 - tuning.ragdoll_angular_damp * scale * dt, 0.0)
	# The hips spring moves the whole FULL ragdoll as one toward the animation's hips.
	var shift := Vector3.ZERO
	if mode == Mode.FULL:
		var hips_k := _stiffness(tuning.ragdoll_hips_hz)
		var hips_c := _damping(tuning.ragdoll_hips_hz, tuning.ragdoll_hips_damping)
		var total := 0.0
		var momentum := Vector3.ZERO
		for k: int in _sim.size():
			momentum += states[k].linear_velocity * _mass[_sim[k]]
			total += _mass[_sim[k]]
		var mean_v := momentum / maxf(total, 1e-6)
		var error := hips_target - states[k_of[0]].transform.origin
		shift = (error * hips_k * scale * scale - (mean_v - hips_target_v) * hips_c * scale) * dt
	# While a FULL ragdoll's influence rises, its springs are stronger: the bodies catch up
	# with the animation's snap before they show alone.
	var rise_hz := tuning.ragdoll_full_rise_pose_hz if mode == Mode.FULL and rise < 1.0 else 0.0
	var lin: Array[Vector3] = []
	var ang: Array[Vector3] = []
	for state: PhysicsDirectBodyState3D in states:
		lin.append(state.linear_velocity * lin_keep + gravity + shift)
		ang.append(state.angular_velocity * ang_keep)
	# The animation's pose, re-anchored on the hips as they are (a FULL ragdoll's; a
	# PARTIAL's are the animation's): how the hips are turned from the animation's, and where
	# they are and how they move.
	var anchor := Quaternion.IDENTITY
	var hips_now := hips_target
	var hips_v := hips_target_v
	var hips_w := anim_w[0]
	if mode == Mode.FULL:
		var hips_state := states[k_of[0]]
		anchor = (hips_state.transform.basis.get_rotation_quaternion() * anim_q[0].inverse()).normalized()
		hips_now = hips_state.transform.origin
		hips_v = hips_state.linear_velocity
		# The whole FULL ragdoll turns as one, about its hips, toward the animation's hips
		# rotation: a rigid turn (no strain on the joints), so the body rolls as a body.
		var turn_hz := tuning.ragdoll_hips_turn_hz
		match phase:
			Phase.FLIGHT:
				turn_hz = tuning.ragdoll_flight_turn_hz
			Phase.LIMP:
				turn_hz = tuning.ragdoll_ko_hips_turn_hz
		if rise_hz > turn_hz:
			turn_hz = lerpf(rise_hz, turn_hz, rise)
		var turn_to := anim[0].basis
		var turn_w := anim_w[0]
		if _aims_landing and phase == Phase.FLIGHT:
			turn_to = Basis(to_world.basis.get_rotation_quaternion() * _landing)
			turn_w = Vector3.ZERO
		var error := _rotation_error(turn_to, hips_state.transform.basis)
		var turn := (error * _stiffness(turn_hz) * scale * scale
				- (hips_state.angular_velocity - turn_w) * _damping(turn_hz, tuning.ragdoll_hips_damping) * scale) * dt
		for k: int in _sim.size():
			ang[k] += turn
			lin[k] += turn.cross(states[k].transform.origin - hips_now)
		hips_w = hips_state.angular_velocity + turn
	# The pose springs pull each body toward the re-anchored animation pose relative to the
	# hips (where it sits from them, and how it is turned): the shape of the pose, not where
	# the whole body is (the hips spring's job) nor how it is turned (the turn's). A body's
	# turn is kept inside its joint's limits from its parent body as it is.
	for k: int in _sim.size():
		var i := _sim[k]
		var parent := _parent_body[i]
		if parent < 0:
			continue
		var state := states[k]
		var hz := _pose_hz(i)
		var pose_k := _stiffness(hz)
		var pose_c := _damping(hz, tuning.ragdoll_pose_damping)
		# The rise strengthens only the turns: a strong pull on where a light head or hand
		# sits would wrench its joint past the limit while its parent lags.
		var turn_hz := lerpf(rise_hz, hz, rise) if rise_hz > hz else hz
		var turn_k := _stiffness(turn_hz)
		var turn_c := _damping(turn_hz, tuning.ragdoll_pose_damping)
		var parent_rot := states[k_of[parent]].transform.basis.get_rotation_quaternion() if k_of[parent] >= 0 \
				else anim_q[parent]
		var target := parent_rot * _within_limits(i, parent_rot.inverse() * (anchor * anim_q[i]).normalized())
		var target_v := (anim[i].origin - _prev_anim[i].origin) / dt if _has_prev else Vector3.ZERO
		var error := anchor * (anim[i].origin - hips_target) - (state.transform.origin - hips_now)
		var relative_v := (state.linear_velocity - hips_v) - anchor * (target_v - hips_target_v)
		lin[k] += (error * pose_k * scale * scale - relative_v * pose_c * scale) * dt
		var target_w := hips_w + anim_w[i] - anim_w[0]
		ang[k] += (_rotation_error(Basis(target), state.transform.basis) * turn_k * scale * scale
				- (ang[k] - target_w) * turn_c * scale) * dt
	var max_v := tuning.ragdoll_max_speed * scale
	var max_w := tuning.ragdoll_max_spin * scale
	for k: int in _sim.size():
		states[k].linear_velocity = _finite(lin[k]).limit_length(max_v)
		states[k].angular_velocity = _finite(ang[k]).limit_length(max_w)
	for i: int in _bodies.size():
		_prev_anim[i] = anim[i]
	_has_prev = true
	if mode == Mode.FULL and (phase == Phase.DOWN or phase == Phase.LIMP):
		_rest(states, moving, sim_dt)


## `relative` (body `i`'s rotation in its parent's bone frame) clamped into its joint's
## limits: a motor never pushes a joint against its limit (an animation pose a little past
## one would hold the bodies there and wrench the light ones past theirs).
func _within_limits(i: int, relative: Quaternion) -> Quaternion:
	var spec := _spec[i]
	if spec.joint == PlaceholderBody.RagdollJoint.HINGE:
		var bend := _twist_angle(relative, Vector3.RIGHT)
		return Quaternion(Vector3.RIGHT, clampf(bend, deg_to_rad(spec.lower_deg), deg_to_rad(spec.upper_deg)))
	# A cone twist: swing and twist about the frames' X, in the joint's frames.
	var joint := _frame_a[i].inverse() * relative * _frame_b[i]
	var twist_angle := _twist_angle(joint, Vector3.RIGHT)
	var twist := Quaternion(Vector3.RIGHT, twist_angle)
	var swing := (joint * twist.inverse()).normalized()
	if swing.w < 0.0:
		swing = -swing
	var limit_swing := deg_to_rad(spec.swing_deg)
	var limit_twist := deg_to_rad(spec.twist_deg)
	if swing.get_angle() > limit_swing:
		swing = Quaternion(swing.get_axis(), limit_swing)
	if absf(twist_angle) > limit_twist:
		twist = Quaternion(Vector3.RIGHT, signf(twist_angle) * limit_twist)
	return _frame_a[i] * (swing * twist) * _frame_b[i].inverse()


## The signed angle (radians, -PI..PI) `q` turns about the unit `axis` (its twist part).
static func _twist_angle(q: Quaternion, axis: Vector3) -> float:
	var along := Vector3(q.x, q.y, q.z).dot(axis)
	var angle := 2.0 * atan2(along, q.w)
	return wrapf(angle, -PI, PI)


## The rotation (world axis times angle, radians) that turns `current` into `target`.
static func _rotation_error(target: Basis, current: Basis) -> Vector3:
	var q := (target.get_rotation_quaternion() * current.get_rotation_quaternion().inverse()).normalized()
	if q.w < 0.0:
		q = -q
	var angle := q.get_angle()
	return q.get_axis() * angle if angle > 1e-5 else Vector3.ZERO


## World angular velocity (rad/s) that turns `from` into `to` in `dt` seconds.
static func _turn_rate(from: Basis, to: Basis, dt: float) -> Vector3:
	return _rotation_error(to, from) / dt


## Scale the bodies' velocities from the scale they are in to `scale` (see the class docs).
func _rescale(states: Array[PhysicsDirectBodyState3D], scale: float) -> void:
	var from := _applied_scale
	if is_equal_approx(from, scale):
		_applied_scale = scale
		return
	for k: int in _sim.size():
		var i := _sim[k]
		var state := states[k]
		var lin := _held_lin[i]
		var ang := _held_ang[i]
		if from > 0.0:
			lin = state.linear_velocity / from
			ang = state.angular_velocity / from
		_held_lin[i] = lin
		_held_ang[i] = ang
		state.linear_velocity = lin * scale
		state.angular_velocity = ang * scale
	_applied_scale = scale


## _rescale() for one body (by index) from scale `from` to `to`, through the server.
func _rescale_body(i: int, from: float, to: float) -> void:
	if is_equal_approx(from, to):
		return
	var rid := _bodies[i].get_rid()
	if from > 0.0:
		_held_lin[i] = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY) / from
		_held_ang[i] = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY) / from
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, _held_lin[i] * to)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, _held_ang[i] * to)


## Apply the waiting kicks (velocity changes) at sim scale `scale`: each a central kick on
## its body, and the struck body's (Tuning.ragdoll_kick_at_contact) the twist of the
## kick landing off its center too (_twist_at_contact()).
func _apply_pending(states: Array[PhysicsDirectBodyState3D], scale: float) -> void:
	for entry: Array in _pending:
		var i: int = entry[0]
		var k := _sim.find(i)
		if k < 0:
			continue
		var change: Vector3 = entry[1]
		states[k].apply_central_impulse(change * _mass[i] * scale)
	if Tuning.data.ragdoll_kick_at_contact:
		for entry: Array in _pending:
			var contact: Variant = entry[2]
			if contact != null and _sim.has(entry[0]):
				_twist_at_contact(states, entry[0], contact, entry[1], scale)
	_pending.clear()


## The off-center part of a kick of `change` (sim m/s) landing at `contact` (world) on body
## `i` (Spec §6, "an impulse at the contact point"): its angular impulse about the body's
## center of mass, the lever clamped to Tuning.ragdoll_contact_lever_m and scaled by
## Tuning.ragdoll_contact_twist. It turns the struck body and its simulating parents (up to
## Tuning.ragdoll_contact_chain bodies) as one rigid piece about the joint the piece hangs
## from (the body's center for the hips), at the rate that impulse gives that piece's
## inertia, capped per body part (Tuning.ragdoll_contact_spin_*). A light hand or neck alone
## would spin wildly (the joints then fight it: a glitch, not a contortion); the piece
## turning as one from its joint twists the body along the hit instead, and the joints stay
## together.
func _twist_at_contact(states: Array[PhysicsDirectBodyState3D], i: int, contact: Vector3,
		change: Vector3, scale: float) -> void:
	var tuning := Tuning.data
	var struck := states[_sim.find(i)]
	var lever := (contact - (struck.transform.origin + struck.center_of_mass)).limit_length(tuning.ragdoll_contact_lever_m)
	var angular := lever.cross(change * _mass[i]) * tuning.ragdoll_contact_twist
	if angular.length_squared() < 1e-10:
		return
	var chain: PackedInt32Array = [i]
	var top := i
	while chain.size() < tuning.ragdoll_contact_chain and _parent_body[top] >= 0 and _sim.has(_parent_body[top]):
		top = _parent_body[top]
		chain.append(top)
	var top_state := states[_sim.find(top)]
	var pivot := top_state.transform.origin
	if _parent_body[top] < 0:
		pivot += top_state.center_of_mass
	# The piece's inertia about the axis through the pivot: each body's own, plus its mass
	# times its distance from the axis squared.
	var axis := angular.normalized()
	var inertia := 0.0
	for b: int in chain:
		var state := states[_sim.find(b)]
		var arm := state.transform.origin + state.center_of_mass - pivot
		inertia += axis.dot(state.inverse_inertia_tensor.inverse() * axis) \
				+ _mass[b] * (arm.length_squared() - pow(arm.dot(axis), 2.0))
	var cap := tuning.ragdoll_contact_spin_trunk
	match _part[i]:
		Part.HEAD:
			cap = tuning.ragdoll_contact_spin_head
		Part.ARMS, Part.LEGS:
			cap = tuning.ragdoll_contact_spin_limb
	var turn := axis * minf(angular.length() / maxf(inertia, 1e-6), cap) * scale
	var spun := struck.angular_velocity
	for b: int in chain:
		var state := states[_sim.find(b)]
		state.angular_velocity += turn
		state.linear_velocity += turn.cross(state.transform.origin + state.center_of_mass - pivot)
	if scale > 0.0:
		var rate := (struck.angular_velocity - spun).length() / scale
		_top_twist[_part[i]] = maxf(_top_twist.get(_part[i], 0.0), rate)


## Queue a kick of `push` (sim m/s) on the simulating `part` body (any body if none of that
## part simulates) whose shape's center is nearest to `contact`. A kick on an arm moves the
## whole arm, up to the shoulder, not just its light end; a PARTIAL's kick on the trunk, every
## simulating trunk body.
func _queue_impulse(contact: Vector3, push: Vector3, part: Part) -> void:
	if push.length_squared() < 1e-8 or _sim.is_empty():
		return
	var best := -1
	var best_d := INF
	for pass_any: bool in [false, true]:
		for i: int in _sim:
			if not pass_any and part != Part.ANY and _part[i] != part:
				continue
			var d := (_world_visual(_bone_of[i]) * _center[i]).distance_squared_to(contact)
			if d < best_d:
				best_d = d
				best = i
		if best >= 0:
			break
	var change := push.limit_length(Tuning.data.ragdoll_max_kick)
	# [body, sim velocity change, contact (the struck body's: its twist) or null].
	_pending.append([best, change, contact])
	# A kick on an arm moves the whole arm; a stagger's kick on the trunk, the whole trunk
	# (on one light body the joints soak it up and the chest hardly gives).
	if _part[best] == Part.ARMS:
		var up := _parent_body[best]
		while up >= 0 and _part[up] == Part.ARMS and _sim.has(up):
			_pending.append([up, change, null])
			up = _parent_body[up]
	elif mode == Mode.PARTIAL and _part[best] == Part.TORSO:
		for i: int in _sim:
			if i != best and _part[i] == Part.TORSO:
				_pending.append([i, change, null])


## Rest detection for a lying ragdoll: asleep once every body has moved slower than
## Tuning.ragdoll_rest_speed (`moving`, the last step's top speed) for Tuning.ragdoll_rest_s,
## or Tuning.ragdoll_settle_max_s after it started lying (or was last woken), whichever
## comes first.
func _rest(states: Array[PhysicsDirectBodyState3D], moving: float, sim_dt: float) -> void:
	var tuning := Tuning.data
	_lying_s += sim_dt
	_calm_s = _calm_s + sim_dt if moving < tuning.ragdoll_rest_speed else 0.0
	if _calm_s >= tuning.ragdoll_rest_s or _lying_s >= tuning.ragdoll_settle_max_s:
		for state: PhysicsDirectBodyState3D in states:
			state.linear_velocity = Vector3.ZERO
			state.angular_velocity = Vector3.ZERO
			state.sleeping = true
		asleep = true
		# Woken later (a stomp), the targets' motion restarts from then.
		_has_prev = false


func _wake() -> void:
	if not asleep:
		return
	asleep = false
	for i: int in _sim:
		PhysicsServer3D.body_set_state(_bodies[i].get_rid(), PhysicsServer3D.BODY_STATE_SLEEPING, false)


## A PARTIAL body part's own influence as a share of ragdoll_partial_influence (0..1).
static func _partial_share(influence: float) -> float:
	var whole := Tuning.data.ragdoll_partial_influence
	return clampf(influence / whole, 0.0, 1.0) if whole > 0.0 else 1.0


## The pose-spring frequency of body `i` in this phase (its arms have their own while
## staggering, its arms and legs theirs while lying).
func _pose_hz(i: int) -> float:
	var tuning := Tuning.data
	var limb := _part[i] == Part.ARMS or _part[i] == Part.LEGS
	match phase:
		Phase.STAGGER:
			return tuning.ragdoll_partial_limb_pose_hz if limb else tuning.ragdoll_partial_pose_hz
		Phase.DOWN:
			match _part[i]:
				Part.ARMS:
					return tuning.ragdoll_down_arm_pose_hz
				Part.LEGS:
					return tuning.ragdoll_down_leg_pose_hz
			return tuning.ragdoll_down_pose_hz
		Phase.LIMP:
			return tuning.ragdoll_ko_pose_hz
	return tuning.ragdoll_flight_pose_hz


## Spring stiffness (1/s²) and damping (1/s) for a natural frequency in Hz and a damping
## ratio.
static func _stiffness(hz: float) -> float:
	var w := TAU * maxf(hz, 0.0)
	return w * w


static func _damping(hz: float, ratio: float) -> float:
	return 2.0 * ratio * TAU * maxf(hz, 0.0)


static func _finite(v: Vector3) -> Vector3:
	return v if v.is_finite() else Vector3.ZERO


## World transform of skeleton bone `bone` as shown now: the animation's, or a running
## ragdoll's last visual pose.
func _world_visual(bone: int) -> Transform3D:
	if mode == Mode.NONE:
		return rig.global_transform * rig.animation_pose(bone)
	return visual_rig_transform * _visual[bone]


func _make_shape(spec: PlaceholderBody.RagdollSpec, scale: float) -> Shape3D:
	var size := spec.size * scale
	match spec.shape:
		PlaceholderBody.Shape.BOX:
			var box := BoxShape3D.new()
			box.size = size
			return box
		PlaceholderBody.Shape.CAPSULE:
			var capsule := CapsuleShape3D.new()
			capsule.radius = size.x
			capsule.height = maxf(size.y, size.x * 2.0)
			return capsule
	var sphere := SphereShape3D.new()
	sphere.radius = size.x
	return sphere


## Every joint, body to its parent body (_make_joint()).
func _build_joints() -> void:
	var specs := PlaceholderBody.ragdoll_specs()
	var scale := rig.rig_scale()
	for i: int in specs.size():
		if _parent_body[i] >= 0:
			_joints.append(_make_joint(specs[i], i, scale))


## The joint from body `i` (`spec`'s bone) to its parent's body, its frames at the rest pose
## (every rest rotation is identity, so the bone sits at its rest offset in its parent's
## frame).
func _make_joint(spec: PlaceholderBody.RagdollSpec, i: int, scale: float) -> RID:
	var body_a := _bodies[_parent_body[i]].get_rid()
	var body_b := _bodies[i].get_rid()
	var anchor: Vector3 = PlaceholderBody.BONE_REST[spec.bone] * scale
	var joint := PhysicsServer3D.joint_create()
	if spec.joint == PlaceholderBody.RagdollJoint.HINGE:
		# The hinge axis is the frames' Z, turned onto the bone's -X: the hinge angle then
		# reads like the pose's +x rotation (Jolt measures it the other way about +Z).
		var frame := Basis(Vector3.UP, -PI * 0.5)
		PhysicsServer3D.joint_make_hinge(joint, body_a, Transform3D(frame, anchor), body_b, Transform3D(frame, Vector3.ZERO))
		PhysicsServer3D.hinge_joint_set_flag(joint, PhysicsServer3D.HINGE_JOINT_FLAG_USE_LIMIT, true)
		PhysicsServer3D.hinge_joint_set_param(joint, PhysicsServer3D.HINGE_JOINT_LIMIT_LOWER, deg_to_rad(spec.lower_deg))
		PhysicsServer3D.hinge_joint_set_param(joint, PhysicsServer3D.HINGE_JOINT_LIMIT_UPPER, deg_to_rad(spec.upper_deg))
	else:
		# The twist axis is the frames' X: along the bone in the child, along the cone's
		# center in the parent, so the cone is centered there.
		var along := Basis(Quaternion(Vector3.RIGHT, spec.axis))
		var to_center := Basis(Quaternion(spec.axis, spec.center))
		PhysicsServer3D.joint_make_cone_twist(joint, body_a, Transform3D(to_center * along, anchor), body_b, Transform3D(along, Vector3.ZERO))
		PhysicsServer3D.cone_twist_joint_set_param(joint, PhysicsServer3D.CONE_TWIST_JOINT_SWING_SPAN, deg_to_rad(spec.swing_deg))
		PhysicsServer3D.cone_twist_joint_set_param(joint, PhysicsServer3D.CONE_TWIST_JOINT_TWIST_SPAN, deg_to_rad(spec.twist_deg))
	PhysicsServer3D.joint_disable_collisions_between_bodies(joint, true)
	return joint
