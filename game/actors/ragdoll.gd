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
## modifiers are inactive and the bodies static with no collision layer: no cost, and the
## visuals are exactly the animation's.
##
## Modes:
##   PARTIAL (staggers): the upper body (Spine and up, the arms) simulates on the hips and
##     legs, which stay kinematic on the animation; the simulator's influence
##     (Tuning.ragdoll_partial_influence) blends it over the animation, holds, fades back to
##     the animation and stops.
##   FULL (a body knocked off its feet, and a KO): every body simulates at full influence.
## Either way each simulated bone is pulled toward its animation pose by a soft rotation
## spring (per phase: a stagger, flight, lying down, and a nearly limp KO), and a FULL
## ragdoll as a whole toward the animation's hips (Tuning.ragdoll_hips_hz), so the visible
## body never drifts from the sim body and a downed body lies where its hurtboxes are. A hit
## adds an impulse at its contact point. A lying body comes to rest and sleeps.
##
## Time: the bodies run in the actor's sim time (HumanoidRig passes
## TimeController.scale_for(actor) every tick, sim_scale): when the scale changes from a to
## b their velocities scale by b/a, gravity by b² and damping by b; at 0 (the actor's
## hitstop) they hold still, their velocities kept, and impulses wait until it ends.
## Engine.time_scale stays 1. Gravity, damping and the springs are applied here, as
## velocity changes before each physics step (the bodies' own gravity is off).
##
## Visuals: this modifier runs after the simulator in the skeleton's deferred update (the
## end of the physics frame, after every actor has posed), reads the post-modifier local
## poses and moves the rig's bone followers (meshes and attachments) to them.

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

var rig: HumanoidRig
var simulator: PhysicalBoneSimulator3D
var mode: Mode = Mode.NONE
var phase: Phase = Phase.FLIGHT
## The actor's sim time scale this tick (set by the rig every tick while running).
var sim_scale: float = 1.0
## True while a lying ragdoll is at rest (every body asleep).
var asleep: bool = false
## The rig's world transform when the visual pose (visual_pose()) was last read.
var visual_rig_transform: Transform3D = Transform3D.IDENTITY

## Per body (PlaceholderBody.ragdoll_specs() order): the node, its skeleton bone index and
## its mass.
var _bodies: Array[PhysicalBone3D] = []
var _bone_of: PackedInt32Array = PackedInt32Array()
var _mass: PackedFloat32Array = PackedFloat32Array()
## Each body's Part, and its shape's center in its bone's frame.
var _part: Array[Part] = []
var _center: PackedVector3Array = PackedVector3Array()
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
## Impulses waiting for the next unfrozen step: [body index, sim velocity change, world
## contact point].
var _pending: Array[Array] = []
## Each body's animation target (world) last step, for the target velocities.
var _prev_target: Array[Transform3D] = []
var _prev_hips_target: Vector3 = Vector3.ZERO
var _has_prev_target: bool = false
## Sim seconds since a PARTIAL started; sim seconds calm and lying (rest detection).
var _partial_t: float = 0.0
var _partial_hold: float = 0.0
var _partial_fade: float = 0.0
var _calm_s: float = 0.0
var _lying_s: float = 0.0
## Skeleton-space post-ragdoll pose of every bone after the latest update.
var _visual: Array[Transform3D] = []


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
		body_of[spec.bone] = _bodies.size()
		_bodies.append(body)
		_bone_of.append(skeleton.find_bone(spec.bone))
		_mass.append(body.mass)
		_center.append(spec.offset * scale)
		var part := Part.ANY
		var side_free := String(spec.bone).trim_prefix("Left").trim_prefix("Right")
		for key: Part in PART_BONES:
			if PART_BONES[key].has(StringName(side_free)):
				part = key
		_part.append(part)
	_held_lin.resize(_bodies.size())
	_held_ang.resize(_bodies.size())
	_prev_target.resize(_bodies.size())
	_visual.resize(skeleton.get_bone_count())
	apply_tuning()
	Tuning.changed.connect(_on_tuning_changed)
	for i: int in specs.size():
		if i > 0:
			_joints.append(_make_joint(specs[i], body_of, scale))
		for j: int in i:
			PhysicsServer3D.body_add_collision_exception(_bodies[i].get_rid(), _bodies[j].get_rid())


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
	for body: PhysicalBone3D in _bodies:
		body.friction = tuning.ragdoll_friction
		body.bounce = tuning.ragdoll_bounce
		body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_RAGDOLL)
		body.collision_mask = mask


func _on_tuning_changed(_property: StringName) -> void:
	apply_tuning()


func is_running() -> bool:
	return mode != Mode.NONE


## Start (or switch to) `new_mode` from the pose on screen. `contact` and `push` (world, m/s)
## place the hit's impulse (scaled by the mode's impulse tuning) on the `part` body nearest
## to the contact; every simulating body also
## gets `body_velocity` (the actor's new sim velocity, world m/s, times
## Tuning.ragdoll_inherit_velocity) on top of the velocity its bone already had in the
## animation (`bone_velocity`, sim m/s per skeleton bone; may be empty). `partial_length_s` caps a
## PARTIAL's hold and fade (the stagger's length).
func start(new_mode: Mode, contact: Vector3, push: Vector3, body_velocity: Vector3,
		bone_velocity: Array[Vector3], part: Part = Part.ANY, partial_length_s: float = INF) -> void:
	if new_mode == Mode.NONE:
		stop()
		return
	var tuning := Tuning.data
	var was := mode
	var previous_sim := _sim.duplicate()
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
		simulator.influence = tuning.ragdoll_partial_influence
		_partial_t = 0.0
		var length := maxf(partial_length_s, 0.0)
		_partial_hold = minf(tuning.ragdoll_partial_hold_s, length)
		_partial_fade = minf(tuning.ragdoll_partial_fade_s, maxf(length - _partial_hold, 0.0))
	else:
		simulator.influence = 1.0
	_calm_s = 0.0
	_lying_s = 0.0
	if was == Mode.FULL and new_mode == Mode.FULL:
		# Already flying or lying: only the new hit's impulse.
		_queue_impulse(contact, push * tuning.ragdoll_full_impulse, part)
		return
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
	_applied_scale = scale
	var inherit := body_velocity * tuning.ragdoll_inherit_velocity
	for i: int in _sim:
		var rid := _bodies[i].get_rid()
		var kept := previous_sim.has(i)
		if not kept:
			PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, shown[i])
			var lin := inherit
			if not bone_velocity.is_empty():
				lin += bone_velocity[_bone_of[i]]
			lin = lin.limit_length(tuning.ragdoll_max_speed)
			_held_lin[i] = lin
			_held_ang[i] = Vector3.ZERO
			PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, lin * scale)
			PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	var impulse_scale := tuning.ragdoll_partial_impulse if new_mode == Mode.PARTIAL else tuning.ragdoll_full_impulse
	_pending.clear()
	_queue_impulse(contact, push * impulse_scale, part)
	_has_prev_target = false


## An extra hit on a running ragdoll (a stomp on a downed body): wakes it and adds an
## impulse of `push` (world m/s) at `contact`, on the `part` body nearest to it.
func hit(contact: Vector3, push: Vector3, part: Part = Part.ANY) -> void:
	if mode == Mode.NONE:
		return
	_wake()
	_calm_s = 0.0
	_lying_s = 0.0
	_queue_impulse(contact, push, part)


## Switch a running ragdoll's pose springs (a FULL ragdoll lands: DOWN, or is KO'd: LIMP).
func set_phase(new_phase: Phase) -> void:
	if mode == Mode.NONE:
		return
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


## World position of the simulated Hips body (the visible hips).
func hips_position() -> Vector3:
	return PhysicsServer3D.body_get_state(_bodies[0].get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM).origin


## Largest sim speed (m/s) of any simulating body (0 when none). For tests.
func max_body_speed() -> float:
	var top := 0.0
	var scale := _applied_scale
	for i: int in _sim:
		var rid := _bodies[i].get_rid()
		var lin: Vector3 = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY)
		top = maxf(top, lin.length() / scale if scale > 0.0 else _held_lin[i].length())
	return top


## The simulating bodies' world transforms (for tests and debug draw).
func body_transforms() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for i: int in _sim:
		out.append(PhysicsServer3D.body_get_state(_bodies[i].get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM))
	return out


# --- Skeleton update ------------------------------------------------------------------


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or rig == null:
		return
	for i: int in skeleton.get_bone_count():
		var local := skeleton.get_bone_pose(i)
		var parent := skeleton.get_bone_parent(i)
		_visual[i] = local if parent < 0 else _visual[parent] * local
	visual_rig_transform = rig.global_transform
	rig.show_visual_pose(_visual)
	if mode != Mode.NONE:
		_step()


## One physics tick of control, before the physics step: time scale, gravity, damping, the
## springs, impulses, the PARTIAL fade and rest.
func _step() -> void:
	var tuning := Tuning.data
	var dt := 1.0 / Engine.physics_ticks_per_second
	var scale := maxf(sim_scale, 0.0)
	var states: Array[PhysicsDirectBodyState3D] = []
	for i: int in _sim:
		states.append(PhysicsServer3D.body_get_direct_state(_bodies[i].get_rid()))
	if asleep:
		var woke := false
		for state: PhysicsDirectBodyState3D in states:
			woke = woke or not state.sleeping
		if not woke:
			_applied_scale = scale
			return
		asleep = false
	if scale <= 0.0:
		# Frozen (the actor's hitstop): the velocities are kept and the bodies put to sleep,
		# so the solver moves nothing at all (it would replay the last step's joint impulses).
		if not _frozen:
			_rescale(states, 0.0)
			for state: PhysicsDirectBodyState3D in states:
				state.sleeping = true
			_frozen = true
		_has_prev_target = false
		return
	if _frozen:
		_frozen = false
		for state: PhysicsDirectBodyState3D in states:
			state.sleeping = false
	_rescale(states, scale)
	# The waiting kicks land first, so the speed caps below hold them too.
	_apply_pending(states, scale)
	var sim_dt := dt * scale
	if mode == Mode.PARTIAL:
		_partial_t += sim_dt
		var fade_t := _partial_t - _partial_hold
		if fade_t >= _partial_fade:
			stop()
			return
		var w := 1.0 - fade_t / _partial_fade if fade_t > 0.0 else 1.0
		simulator.influence = tuning.ragdoll_partial_influence * w
	# Animation targets (world) and their velocities.
	var to_world := rig.global_transform
	if mode == Mode.PARTIAL:
		# The kinematic hips and legs ride the animation (this tick's pose, not the
		# simulator's copy from the last update).
		for i: int in _bodies.size():
			if not _sim.has(i):
				PhysicsServer3D.body_set_state(_bodies[i].get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM,
						to_world * rig.animation_pose(_bone_of[i]))
	var targets: Array[Transform3D] = []
	for i: int in _sim:
		targets.append(to_world * rig.animation_pose(_bone_of[i]))
	var gravity_mult := tuning.ragdoll_partial_gravity if mode == Mode.PARTIAL else tuning.ragdoll_gravity_mult
	var gravity := Vector3.DOWN * tuning.gravity * gravity_mult * scale * scale * dt
	var lin_keep := maxf(1.0 - tuning.ragdoll_linear_damp * scale * dt, 0.0)
	var ang_keep := maxf(1.0 - tuning.ragdoll_angular_damp * scale * dt, 0.0)
	# The hips spring moves the whole FULL ragdoll as one toward the animation's hips.
	var shift := Vector3.ZERO
	if mode == Mode.FULL:
		var hips_k := _stiffness(tuning.ragdoll_hips_hz)
		var hips_c := _damping(tuning.ragdoll_hips_hz, tuning.ragdoll_hips_damping)
		var hips_target := targets[0].origin
		var hips_target_v := Vector3.ZERO
		if _has_prev_target:
			hips_target_v = (hips_target - _prev_target[0].origin) / dt
		var total := 0.0
		var momentum := Vector3.ZERO
		for k: int in _sim.size():
			momentum += states[k].linear_velocity * _mass[_sim[k]]
			total += _mass[_sim[k]]
		var mean_v := momentum / maxf(total, 1e-6)
		var error := hips_target - states[0].transform.origin
		shift = (error * hips_k * scale * scale - (mean_v - hips_target_v) * hips_c * scale) * dt
	var pose_k := _stiffness(_pose_hz())
	var pose_c := _damping(_pose_hz(), tuning.ragdoll_pose_damping)
	var max_v := tuning.ragdoll_max_speed * scale
	var max_w := tuning.ragdoll_max_spin * scale
	# The pose springs pull each body toward its animation pose relative to the hips (where
	# it sits from them, and how it is turned): the shape of the pose, not where the whole
	# body is (the hips spring's job). A PARTIAL's hips are the animation's.
	var hips_now := targets[0].origin if mode == Mode.PARTIAL else states[0].transform.origin
	var hips_v := Vector3.ZERO if mode == Mode.PARTIAL else states[0].linear_velocity
	var hips_target_v := Vector3.ZERO
	var hips_target := to_world * rig.animation_pose(_bone_of[0])
	if mode == Mode.PARTIAL:
		hips_now = hips_target.origin
	for k: int in _sim.size():
		var state := states[k]
		var i := _sim[k]
		var k_rot := pose_k
		var c_rot := pose_c
		if i == 0 and mode == Mode.FULL:
			var turn_hz := tuning.ragdoll_ko_hips_turn_hz if phase == Phase.LIMP else tuning.ragdoll_hips_turn_hz
			k_rot = _stiffness(turn_hz)
			c_rot = _damping(turn_hz, tuning.ragdoll_hips_damping)
		var lin := state.linear_velocity * lin_keep + gravity + shift
		if i != 0:
			var target_v := Vector3.ZERO
			if _has_prev_target:
				target_v = (targets[k].origin - _prev_target[i].origin) / dt
				hips_target_v = (hips_target.origin - _prev_hips_target) / dt
			var error := (targets[k].origin - hips_target.origin) - (state.transform.origin - hips_now)
			var relative_v := (state.linear_velocity - hips_v) - (target_v - hips_target_v)
			lin += (error * pose_k * scale * scale - relative_v * pose_c * scale) * dt
		var ang := state.angular_velocity * ang_keep
		var current := state.transform.basis.get_rotation_quaternion()
		var target := targets[k].basis.get_rotation_quaternion()
		var error_q := (target * current.inverse()).normalized()
		if error_q.w < 0.0:
			error_q = -error_q
		var angle := error_q.get_angle()
		var axis := error_q.get_axis() if angle > 1e-5 else Vector3.ZERO
		var target_w := Vector3.ZERO
		if _has_prev_target:
			var step_q := (target * _prev_target[i].basis.get_rotation_quaternion().inverse()).normalized()
			if step_q.w < 0.0:
				step_q = -step_q
			var step_angle := step_q.get_angle()
			if step_angle > 1e-5:
				target_w = step_q.get_axis() * step_angle / dt
		ang += (axis * angle * k_rot * scale * scale - (ang - target_w) * c_rot * scale) * dt
		state.linear_velocity = _finite(lin).limit_length(max_v)
		state.angular_velocity = _finite(ang).limit_length(max_w)
	for k: int in _sim.size():
		_prev_target[_sim[k]] = targets[k]
	_prev_hips_target = hips_target.origin
	_has_prev_target = true
	if mode == Mode.FULL and (phase == Phase.DOWN or phase == Phase.LIMP):
		_rest(states, scale, sim_dt)


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


## Apply the waiting impulses (velocity changes at contact points) at sim scale `scale`.
func _apply_pending(states: Array[PhysicsDirectBodyState3D], scale: float) -> void:
	for entry: Array in _pending:
		var i: int = entry[0]
		var k := _sim.find(i)
		if k < 0:
			continue
		var state := states[k]
		var change: Vector3 = entry[1]
		# A central kick on the struck body: the joints turn it into the chain's swing (an
		# off-center impulse on a light body, a hand or the neck, would spin it wildly).
		state.apply_central_impulse(change * _mass[i] * scale)
	_pending.clear()


## Queue an impulse of `push` (sim m/s) at `contact` on the simulating `part` body (any
## body if none of that part simulates) whose shape's center is nearest to it.
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
	_pending.append([best, push.limit_length(Tuning.data.ragdoll_max_kick), contact])


## Rest detection for a lying ragdoll: asleep once every body has moved slower than
## Tuning.ragdoll_rest_speed for Tuning.ragdoll_rest_s, or Tuning.ragdoll_settle_max_s
## after it started lying, whichever comes first.
func _rest(states: Array[PhysicsDirectBodyState3D], scale: float, sim_dt: float) -> void:
	var tuning := Tuning.data
	_lying_s += sim_dt
	var top := 0.0
	for state: PhysicsDirectBodyState3D in states:
		top = maxf(top, state.linear_velocity.length() / scale)
	_calm_s = _calm_s + sim_dt if top < tuning.ragdoll_rest_speed else 0.0
	if _calm_s >= tuning.ragdoll_rest_s or _lying_s >= tuning.ragdoll_settle_max_s:
		for state: PhysicsDirectBodyState3D in states:
			state.linear_velocity = Vector3.ZERO
			state.angular_velocity = Vector3.ZERO
			state.sleeping = true
		asleep = true


func _wake() -> void:
	if not asleep:
		return
	asleep = false
	for i: int in _sim:
		PhysicsServer3D.body_set_state(_bodies[i].get_rid(), PhysicsServer3D.BODY_STATE_SLEEPING, false)


func _pose_hz() -> float:
	var tuning := Tuning.data
	match phase:
		Phase.STAGGER:
			return tuning.ragdoll_partial_pose_hz
		Phase.DOWN:
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


## World transform of skeleton bone `bone` as shown now.
func _world_visual(bone: int) -> Transform3D:
	var to_world := rig.global_transform
	if mode == Mode.NONE:
		return to_world * rig.animation_pose(bone)
	return to_world * _visual[bone]


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


## The joint from `spec`'s bone to its parent's body, its frames at the rest pose (every
## rest rotation is identity, so the bone sits at its rest offset in its parent's frame).
func _make_joint(spec: PlaceholderBody.RagdollSpec, body_of: Dictionary[StringName, int], scale: float) -> RID:
	var parent_bone: StringName = PlaceholderBody.BONE_PARENT[spec.bone]
	var body_a := _bodies[body_of[parent_bone]].get_rid()
	var body_b := _bodies[body_of[spec.bone]].get_rid()
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
