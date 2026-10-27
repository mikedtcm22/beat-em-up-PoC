class_name MotionClips
extends RefCounted
## The life of the placeholder clips (Milestone 4, F-motion): the keys of the named animations that
## M4-plan A20 lets the polish touch (PlaceholderAnims.POLISHED_IDS), built from the same stance
## poses PlaceholderAnims already keys. A move is never one of them.
##
## - idle: one breath long (about 4 s). The chest and shoulders breathe, the boxer bounces and
##   shifts his weight, the guard's arms sway after the bounce and the head drifts. The soles
##   stay where the guard puts them (MotionLegs puts each ankle back on its spot as the hips
##   dip and roll), and no hurtbox moves a centimeter: the head and torso volumes keep still
##   while the shapes the skin draws around them breathe.
## - the boxer's walks: the planted foot moves back as fast as the body goes forward. HumanoidRig
##   plays a walk at speed_ratio = v / move_speed, so the body covers move_speed meters per second
##   of CLIP time whatever v is, and a foot planted for a step must sweep that distance in the
##   clip. The cycle is as long as the sweep (Tuning look_motion_stride_m) takes at move_speed,
##   the feet roll heel to toe about a contact point that does not move, the pelvis turns and the
##   chest turns against it (counter-swing). walk_back is the forward cycle run backward.
## - the flinches overlap: the shoulders lead the body's snap and the head lags it and overshoots,
##   every other bone keeps the key poses (0.06 s and 0.1 s).
## - everything else on the list (taunt, brace, run, get-ups, downed) keeps its key poses at their
##   times and is eased between them (ease()): a monotone cubic through each bone's angles, so the
##   body leaves and reaches a pose without a kink and never overshoots one.
## Numbers named in a constant here are the shape of a motion (art data: which harmonic, how the
## roll goes); how much and how fast are Tuning's "Motion" subgroup, in PlaceholderAnims.Life.

# --- Idle ---------------------------------------------------------------------------------------

## Keys per bounce (a bounce is the shortest thing the idle does).
const KEYS_PER_BOUNCE := 6
## The idle is never shorter than this (s), whatever the breath rate.
const IDLE_MIN_S := 2.0
## Breathing, in units of the amplitude (degrees): the chest rocks back and the upper chest
## and neck give way so the head's volume stays put; the shoulders rise.
const BREATH_CHEST := 1.0
const BREATH_UPPER_CHEST := -1.8
const BREATH_NECK := 0.5
const BREATH_HEAD := 0.3
const BREATH_SHOULDER := 1.6
## The weight shift: the pelvis rolls, the chest rolls against it (these ratios keep the head's
## and the torso's volumes within a millimeter of still per degree of roll).
const SHIFT_CHEST := -1.9
const SHIFT_UPPER_CHEST := 0.4
## The guard's arms sway after the bounce (units of the sway amplitude, degrees) and lag it
## (radians of the bounce).
const SWAY_UPPER_ARM := 0.5
const SWAY_LOWER_ARM := 1.0
const SWAY_SHOULDER := 0.4
const SWAY_LAG_RAD := 0.9
## The head drifts: yaw (a glance) twice a breath, tilt once, nod three times; the neck shares.
const HEAD_YAW_CYCLES := 2.0
const HEAD_TILT_CYCLES := 1.0
const HEAD_NOD_CYCLES := 3.0
const HEAD_YAW_PHASE := 0.6
const HEAD_TILT_PHASE := 1.9
const HEAD_NOD_PHASE := 2.3
const HEAD_TILT_SHARE := 0.6
const HEAD_NOD_SHARE := 0.4
const NECK_SHARE := 0.5

# --- Walks --------------------------------------------------------------------------------------

## Keys per cycle of a walk.
const WALK_KEYS := 24
## The share of a cycle each foot is planted (the other is in the air; above half, both feet are
## down for a moment).
const STANCE_SHARE := 0.56
## The planted foot's roll: toes up at the strike, flat from `FLAT_FROM` of the stance, heel up
## from `HEEL_OFF` of it (degrees, forward walking; strafes land flat).
const STRIKE_PITCH_DEG := 12.0
const HEEL_OFF_PITCH_DEG := 28.0
const STRAFE_HEEL_OFF_DEG := 10.0
const FLAT_FROM := 0.14
const HEEL_OFF := 0.74
## How high the swinging ankle lifts above its straight path (m at 1.8 m), and the toe-out of the
## feet (degrees).
const SWING_LIFT_M := 0.075
## The share of the swing at its start (and again at its end) the ankle only rises (falls).
const SWING_LIFT_FIRST := 0.14
const TOE_OUT_DEG := 6.0
## Where the feet center along the body's length and across it (m at 1.8 m), a stagger less than
## the guard's, so a longer stride reaches.
const FOOT_Z_FORWARD := Vector2(-0.05, 0.05)
const FOOT_Z_STRAFE := Vector2(-0.09, 0.1)
const FOOT_X_FORWARD := 0.145
const FOOT_X_STRAFE := 0.25
## A strafe's sweep is this share of the stride (a side step is shorter than a walking one).
const STRAFE_SWEEP_SHARE := 0.38
## The hips ride this far below the guard's height in a walk so the legs reach the stride, bob
## this much per step (highest at mid-stance), and sway toward the planted foot (m at 1.8 m).
const WALK_DROP_M := 0.045
const WALK_BOB_M := 0.012
const WALK_SWAY_M := 0.014
## The pelvis tips (share of the hip roll) as the weight crosses, and the chest chain takes the
## counter-swing in these shares (Spine, Chest, UpperChest); the neck and head undo the chest's
## share so the head looks where it was looking.
const WALK_TILT_SHARE := 0.45
const COUNTER_SHARES: Array[float] = [0.3, 0.4, 0.3]
const HEAD_UNDO_SHARE := 0.8
## How far the guard's arms rock with the strides (share of the counter-swing, degrees at the
## upper arm).
const WALK_ARM_SHARE := 0.5

# --- Flinches -----------------------------------------------------------------------------------

## The key times the flinches keep (s): the snap arrives, the hold ends.
const FLINCH_SNAP_S := 0.06
const FLINCH_HOLD_S := 0.1
## How long an overshoot takes to settle (s), and the neck's share of the head's lag and overshoot.
const SETTLE_S := 0.05
const FLINCH_NECK_SHARE := 0.5
## Frames of a flinch's sampling grid.
const GRID_S := 1.0 / 60.0

# --- Easing -------------------------------------------------------------------------------------

## The grid an eased clip is sampled on (s), and the most intervals a clip gets (a slow clip gets a
## coarser grid: the curve is smooth, and a rig builds the library once per size).
const EASE_GRID_S := 1.0 / 30.0
const EASE_MAX_STEPS := 24

## The bones that lead a flinch (the shoulders and the arms they carry) and the ones that lag.
const LEAD_BONES: Array[StringName] = [
	&"LeftShoulder", &"RightShoulder", &"LeftUpperArm", &"RightUpperArm", &"LeftLowerArm", &"RightLowerArm",
]


# --- The idle -------------------------------------------------------------------------------------


## The idle of a body in `g` (its stance pose) on a rig of `scale`: `{length, keys}`. A bigger body moves
## as little as a small one, in meters (the amplitudes are divided by `scale`, which the clip's own
## lengths then multiply back), so no hurtbox moves more than the Punk's does.
static func idle(g: Dictionary[StringName, Vector3], stance: StringName, life: PlaceholderAnims.Life,
		scale: float = 1.0) -> Dictionary:
	var calm := (life.player_calm if stance == PlaceholderPoses.STANCE_RELAXED else 1.0) / maxf(scale, 0.01)
	var length := maxf(1.0 / maxf(life.breath_hz, 0.01), IDLE_MIN_S)
	var bounces := maxi(roundi(life.bounce_hz * length), 1)
	var count := bounces * KEYS_PER_BOUNCE
	var base_hips := PlaceholderAnims.resolve_hips(g)
	var guard_globals := PlaceholderBody.pose_globals(g, base_hips, 1.0)
	var keys: Array[PlaceholderAnims.PoseKey] = []
	for i: int in count + 1:
		var tau := float(i % count) / count
		var key := PlaceholderAnims.PoseKey.new(length * float(i) / count,
				_idle_pose(g, guard_globals, base_hips, bounces, tau, life, calm))
		keys.append(key)
	return {length = length, keys = keys}


static func _idle_pose(g: Dictionary[StringName, Vector3], guard_globals: Dictionary[StringName, Transform3D],
		base_hips: Vector3, bounces: int, tau: float, life: PlaceholderAnims.Life,
		calm: float) -> Dictionary[StringName, Vector3]:
	var pose: Dictionary[StringName, Vector3] = g.duplicate()
	var breath := 0.5 - 0.5 * cos(TAU * tau)
	var bounce_phase := TAU * bounces * tau
	var dip := 0.5 - 0.5 * cos(bounce_phase)
	var shift := sin(TAU * tau)
	# Zero at the start of the loop, so the idle begins in the guard exactly (a clip that ends in the
	# stance flows into it).
	var sway := sin(bounce_phase - SWAY_LAG_RAD) + sin(SWAY_LAG_RAD)
	var breathing := life.breath_deg * calm * breath
	_add(pose, &"Chest", Vector3(BREATH_CHEST * breathing, 0.0, 0.0))
	_add(pose, &"UpperChest", Vector3(BREATH_UPPER_CHEST * breathing, 0.0, 0.0))
	_add(pose, &"Neck", Vector3(BREATH_NECK * breathing, 0.0, 0.0))
	_add(pose, &"Head", Vector3(BREATH_HEAD * breathing, 0.0, 0.0))
	_add(pose, &"LeftShoulder", Vector3(0.0, 0.0, -BREATH_SHOULDER * breathing))
	_add(pose, &"RightShoulder", Vector3(0.0, 0.0, BREATH_SHOULDER * breathing))
	var rolling := life.shift_deg * calm * shift
	_add(pose, &"Hips", Vector3(0.0, 0.0, rolling))
	_add(pose, &"Chest", Vector3(0.0, 0.0, SHIFT_CHEST * rolling))
	_add(pose, &"UpperChest", Vector3(0.0, 0.0, SHIFT_UPPER_CHEST * rolling))
	var swaying := life.guard_sway_deg * calm * sway
	for side: String in ["Left", "Right"]:
		var s := -1.0 if side == "Left" else 1.0
		_add(pose, StringName(side + "UpperArm"), Vector3(SWAY_UPPER_ARM * swaying, 0.0, 0.0))
		_add(pose, StringName(side + "LowerArm"), Vector3(SWAY_LOWER_ARM * swaying, 0.0, 0.0))
		_add(pose, StringName(side + "Shoulder"), Vector3(0.0, 0.0, -s * SWAY_SHOULDER * swaying))
	var head := life.head_deg * calm
	var yaw := sin(TAU * HEAD_YAW_CYCLES * tau + HEAD_YAW_PHASE) - sin(HEAD_YAW_PHASE)
	var tilt := sin(TAU * HEAD_TILT_CYCLES * tau + HEAD_TILT_PHASE) - sin(HEAD_TILT_PHASE)
	var nod := sin(TAU * HEAD_NOD_CYCLES * tau + HEAD_NOD_PHASE) - sin(HEAD_NOD_PHASE)
	var drift := Vector3(HEAD_NOD_SHARE * head * nod, head * yaw, HEAD_TILT_SHARE * head * tilt)
	_add(pose, &"Head", drift * (1.0 - NECK_SHARE))
	_add(pose, &"Neck", drift * NECK_SHARE)
	var offset := base_hips + Vector3(0.0, -life.bounce_m * calm * dip, 0.0)
	var hips := MotionLegs.hips_transform(pose, offset)
	for side: StringName in [&"Left", &"Right"]:
		_hold_foot(pose, guard_globals, base_hips, hips, side, g)
	pose[PlaceholderPoses.HIPS_POS] = offset
	return pose


## Put the ankle of `side` back where the guard has it.
static func _hold_foot(pose: Dictionary[StringName, Vector3], guard_globals: Dictionary[StringName, Transform3D],
		base_hips: Vector3, hips: Transform3D, side: StringName, g: Dictionary[StringName, Vector3]) -> void:
	var s := String(side)
	var foot: Transform3D = guard_globals[StringName(s + "Foot")]
	var guard_hip := MotionLegs.hip_joint(MotionLegs.hips_transform(g, base_hips), side)
	var hint: Vector3 = guard_globals[StringName(s + "LowerLeg")].origin - guard_hip
	MotionLegs.plant(pose, hips, side, foot.origin, foot.basis, g.get(StringName(s + "Toes"), Vector3.ZERO).x, hint)


# --- Walks ----------------------------------------------------------------------------------------


## The walk `id` (walk_forward, walk_back, walk_left, walk_right) of a boxer in `g`, on a rig of
## `scale`: `{length, keys}`.
static func walk(id: StringName, g: Dictionary[StringName, Vector3], scale: float,
		life: PlaceholderAnims.Life) -> Dictionary:
	if id == &"walk_back":
		var forward := walk(&"walk_forward", g, scale, life)
		var length: float = forward.length
		var reversed: Array[PlaceholderAnims.PoseKey] = []
		for key: PlaceholderAnims.PoseKey in forward.keys:
			reversed.append(PlaceholderAnims.PoseKey.new(length - key.time, key.pose))
		reversed.reverse()
		return {length = length, keys = reversed}
	var lateral := id == &"walk_left" or id == &"walk_right"
	var sweep_m := life.stride_m * (STRAFE_SWEEP_SHARE if lateral else 1.0)
	# What the clip must cover so that a foot planted for STANCE_SHARE of it keeps still in the
	# world: the body goes move_speed meters per clip second (see the file's docs).
	var length := sweep_m / (maxf(life.move_speed, 0.1) * STANCE_SHARE)
	var sweep := sweep_m / maxf(scale, 0.01)
	var body_dir := Vector3.FORWARD
	if id == &"walk_right":
		body_dir = Vector3.RIGHT
	elif id == &"walk_left":
		body_dir = Vector3.LEFT
	var drop := _walk_drop(g)
	var keys: Array[PlaceholderAnims.PoseKey] = []
	for i: int in WALK_KEYS + 1:
		var p := float(i % WALK_KEYS) / WALK_KEYS
		keys.append(PlaceholderAnims.PoseKey.new(length * float(i) / WALK_KEYS,
				_walk_pose(g, body_dir, sweep, drop, p, lateral, life)))
	return {length = length, keys = keys}


## How far below the guard's height the hips ride in a walk.
static func _walk_drop(g: Dictionary[StringName, Vector3]) -> Vector3:
	return PlaceholderAnims.resolve_hips(g) + Vector3(0.0, -WALK_DROP_M, 0.0)


## One key of a walk at phase `p` of its cycle (the left foot's stance starts at 0).
static func _walk_pose(g: Dictionary[StringName, Vector3], body_dir: Vector3, sweep: float, base_hips: Vector3,
		p: float, lateral: bool, life: PlaceholderAnims.Life) -> Dictionary[StringName, Vector3]:
	var pose: Dictionary[StringName, Vector3] = g.duplicate()
	var swing := TAU * p
	var yaw := -life.hip_roll_deg * cos(swing)
	var tilt := -life.hip_roll_deg * WALK_TILT_SHARE * cos(swing - TAU * STANCE_SHARE * 0.5)
	_add(pose, &"Hips", Vector3(0.0, yaw, tilt))
	var counter := life.counter_swing_deg * cos(swing) + life.hip_roll_deg * cos(swing)
	for i: int in COUNTER_SHARES.size():
		var bone: StringName = [&"Spine", &"Chest", &"UpperChest"][i]
		_add(pose, bone, Vector3(0.0, COUNTER_SHARES[i] * counter, 0.0))
	var chest_yaw := (life.counter_swing_deg) * cos(swing)
	_add(pose, &"Neck", Vector3(0.0, -HEAD_UNDO_SHARE * chest_yaw * 0.5, 0.0))
	_add(pose, &"Head", Vector3(0.0, -HEAD_UNDO_SHARE * chest_yaw * 0.5, 0.0))
	for side: String in ["Left", "Right"]:
		var s := -1.0 if side == "Left" else 1.0
		# The arms rock with the shoulders: the lead arm back as the chest turns that way.
		_add(pose, StringName(side + "UpperArm"), Vector3(s * -WALK_ARM_SHARE * chest_yaw * 0.4, 0.0, 0.0))
	var mid_stance := STANCE_SHARE * 0.5
	var bob := WALK_BOB_M * (cos(2.0 * swing - TAU * mid_stance * 2.0) - 1.0) * 0.5
	var sway := -WALK_SWAY_M * cos(swing - TAU * mid_stance)
	var offset := base_hips + Vector3(sway, bob, 0.0)
	var hips := MotionLegs.hips_transform(pose, offset)
	var foot_x := FOOT_X_STRAFE if lateral else FOOT_X_FORWARD
	var foot_z := FOOT_Z_STRAFE if lateral else FOOT_Z_FORWARD
	var lowering := 0.0
	for attempt: int in 3:
		hips = MotionLegs.hips_transform(pose, offset + Vector3(0.0, -lowering, 0.0))
		var worst := 0.0
		for side: StringName in [&"Left", &"Right"]:
			var left := side == &"Left"
			var phase := p if left else fposmod(p + 0.5, 1.0)
			# The contact point of a flat foot is its heel; the ankle is a heel's depth in front of it.
			var centre := Vector3(-foot_x if left else foot_x, 0.0,
					(foot_z.x if left else foot_z.y) + MotionLegs.HEEL.z)
			var spec := _foot(phase, centre, -body_dir, sweep, lateral, left)
			worst = maxf(worst, MotionLegs.plant(pose, hips, side, spec.ankle, spec.basis, spec.toes))
		if worst <= 0.0:
			break
		lowering += worst + 0.002
	pose[PlaceholderPoses.HIPS_POS] = offset + Vector3(0.0, -lowering, 0.0)
	return pose


## One foot at `phase` of its own cycle (the stance starts at 0): `{ankle, basis, toes}`. `centre` is
## where its planted contact point is at mid-stance (rig space), `u` the direction the contact point
## moves while planted (opposite the body's), `sweep` how far it goes.
static func _foot(phase: float, centre: Vector3, u: Vector3, sweep: float, lateral: bool, left: bool) -> Dictionary:
	var yaw := TOE_OUT_DEG if left else -TOE_OUT_DEG
	var strike := 0.0 if lateral else STRIKE_PITCH_DEG
	var lift_off := STRAFE_HEEL_OFF_DEG if lateral else HEEL_OFF_PITCH_DEG
	if phase < STANCE_SHARE:
		var q := phase / STANCE_SHARE
		return _stance(q, centre, u, sweep, strike, lift_off, yaw)
	var w := (phase - STANCE_SHARE) / (1.0 - STANCE_SHARE)
	var from := _stance(1.0, centre, u, sweep, strike, lift_off, yaw)
	var to := _stance(0.0, centre, u, sweep, strike, lift_off, yaw)
	# The foot rises before it travels and settles after: the planted toes do not drag.
	var travel := clampf((w - SWING_LIFT_FIRST) / (1.0 - 2.0 * SWING_LIFT_FIRST), 0.0, 1.0)
	var move := travel * travel * (3.0 - 2.0 * travel)
	var arc := sin(PI * pow(w, 0.8)) * SWING_LIFT_M
	var pitch := lerpf(-lift_off, strike, move)
	var basis := MotionLegs.foot_basis(pitch, yaw)
	var toes := lerpf(lift_off, 0.0, minf(w * 3.0, 1.0))
	var ankle := (from.ankle as Vector3).lerp(to.ankle as Vector3, move) + Vector3(0.0, arc, 0.0)
	return {ankle = ankle, basis = basis, toes = toes}


## The planted foot at `q` (0..1) of its stance: it rolls about a contact point that moves at the
## body's pace in the rig and stays still in the world.
static func _stance(q: float, centre: Vector3, u: Vector3, sweep: float, strike: float, lift_off: float,
		yaw: float) -> Dictionary:
	var contact := centre + u * sweep * (q - 0.5)
	var pitch := 0.0
	var on_ball := false
	if q < FLAT_FROM:
		var s := q / FLAT_FROM
		pitch = strike * (1.0 - s * s * (3.0 - 2.0 * s))
	elif q > HEEL_OFF:
		var s := (q - HEEL_OFF) / (1.0 - HEEL_OFF)
		pitch = -lift_off * s * s * (3.0 - 2.0 * s)
		on_ball = true
	var basis := MotionLegs.foot_basis(pitch, yaw)
	var ankle: Vector3
	var toes := 0.0
	if on_ball:
		# The ball stays where the flat foot had it (the heel's contact point less the foot's length).
		var ball := contact + MotionLegs.foot_basis(0.0, yaw) * Vector3(0.0, 0.0, -(MotionLegs.HEEL.z - MotionLegs.TOES_JOINT.z))
		ankle = MotionLegs.ankle_for_ball(ball, basis)
		toes = MotionLegs.flat_toes(pitch)
	else:
		ankle = MotionLegs.ankle_for_heel(contact, basis)
	return {ankle = ankle, basis = basis, toes = toes}


# --- Flinches ---------------------------------------------------------------------------------------


## The flinch from the stance `g` to the hit pose `f`, as keys on a frame grid with the shoulders
## leading and the head lagging: `Array[PoseKey]`, the same length and the same pose at the snap
## (0.06 s) and the hold (0.1 s) for every bone but the head's and neck's.
static func flinch(g: Dictionary[StringName, Vector3], f: Dictionary[StringName, Vector3], length: float,
		life: PlaceholderAnims.Life) -> Array[PlaceholderAnims.PoseKey]:
	var lead := life.overlap_s
	var lag := life.overlap_s
	var times: Array[float] = []
	var steps := ceili(length / GRID_S - 1e-4)
	for i: int in steps:
		times.append(i * GRID_S)
	for t: float in [FLINCH_SNAP_S, FLINCH_HOLD_S, FLINCH_SNAP_S - lead, FLINCH_SNAP_S + lag,
			FLINCH_HOLD_S + lag, FLINCH_SNAP_S + lag * FLINCH_NECK_SHARE, FLINCH_HOLD_S + lag * FLINCH_NECK_SHARE]:
		if t > 0.0 and t < length:
			times.append(t)
	times.append(length)
	times.sort()
	var keys: Array[PlaceholderAnims.PoseKey] = []
	var last := -1.0
	for t: float in times:
		if t - last < 1e-4:
			continue
		last = t
		var pose: Dictionary[StringName, Vector3] = {}
		var bones := _union(g, f)
		for bone: StringName in bones:
			var from: Vector3 = g.get(bone, Vector3.ZERO)
			var to: Vector3 = f.get(bone, Vector3.ZERO)
			var e := _envelope(t, length, bone, lead, lag, life.overshoot)
			pose[bone] = from + (to - from) * e
		keys.append(PlaceholderAnims.PoseKey.new(t, pose))
	return keys


## How far into the flinch `bone` is at `t` (0 = the stance, 1 = the hit pose).
static func _envelope(t: float, length: float, bone: StringName, lead: float, lag: float, overshoot: float) -> float:
	var arrive := FLINCH_SNAP_S
	var release := FLINCH_HOLD_S
	var over := 0.0
	if LEAD_BONES.has(bone):
		arrive = maxf(FLINCH_SNAP_S - lead, 0.02)
	elif bone == &"Head":
		arrive += lag
		release += lag
		over = overshoot
	elif bone == &"Neck":
		arrive += lag * FLINCH_NECK_SHARE
		release += lag * FLINCH_NECK_SHARE
		over = overshoot * FLINCH_NECK_SHARE
	if t < arrive:
		var s := t / arrive
		return (1.0 + over) * (1.0 - (1.0 - s) * (1.0 - s))
	if t < release:
		return 1.0 + over * cos(PI * 0.5 * minf((t - arrive) / SETTLE_S, 1.0))
	var r := clampf((t - release) / maxf(length - release, 1e-4), 0.0, 1.0)
	return 1.0 - r * r * (3.0 - 2.0 * r)


# --- Easing ------------------------------------------------------------------------------------------


## `keys` (a clip's poses at their times) eased: every key stays where it is with the pose it has (the
## hips resolved to an explicit offset, as make() does), and between them each angle follows a monotone
## cubic (Fritsch-Carlson tangents: a bone that reverses at a key stops there, one that goes through
## it does not, and none passes the poses it moves between). A clip that plays once ends at rest and
## starts at rest too unless `drive_in` (a body that is pushed out of a pose, a get-up, leaves it at the
## speed its first segment has); a loop's tangents wrap. Sampled every EASE_GRID_S, so the result is a
## dense key list.
static func ease(keys: Array[PlaceholderAnims.PoseKey], length: float, loop: bool,
		drive_in: bool = false) -> Array[PlaceholderAnims.PoseKey]:
	var sorted: Array[PlaceholderAnims.PoseKey] = keys.duplicate()
	sorted.sort_custom(func(x: PlaceholderAnims.PoseKey, y: PlaceholderAnims.PoseKey) -> bool: return x.time < y.time)
	if sorted.size() < 2:
		return keys
	var times: Array[float] = []
	var poses: Array[Dictionary] = []
	for key: PlaceholderAnims.PoseKey in sorted:
		times.append(clampf(key.time, 0.0, length))
		var pose: Dictionary[StringName, Vector3] = key.pose.duplicate()
		pose[PlaceholderPoses.HIPS_POS] = PlaceholderAnims.resolve_hips(key.pose)
		pose.erase(PlaceholderPoses.HIPS_NUDGE)
		poses.append(pose)
	var bones: Array[StringName] = []
	for pose: Dictionary in poses:
		for bone: StringName in pose:
			if not bones.has(bone):
				bones.append(bone)
	# Each bone's tangents (per axis) at every key.
	var tangents := {}
	for bone: StringName in bones:
		var values: Array[Vector3] = []
		for pose: Dictionary in poses:
			values.append(pose.get(bone, Vector3.ZERO))
		tangents[bone] = _tangents(times, values, loop, drive_in)
	var at: Array[float] = []
	var grid := maxf(EASE_GRID_S, length / EASE_MAX_STEPS)
	var steps := ceili(length / grid - 1e-4)
	for i: int in steps:
		at.append(minf(i * grid, length))
	at.append_array(times)
	at.append(length)
	at.sort()
	var out: Array[PlaceholderAnims.PoseKey] = []
	var last := -1.0
	for t: float in at:
		if t - last < 1e-4:
			continue
		last = t
		var segment := 0
		while segment < times.size() - 2 and t >= times[segment + 1] - 1e-6:
			segment += 1
		var pose: Dictionary[StringName, Vector3] = {}
		for bone: StringName in bones:
			var a: Vector3 = poses[segment].get(bone, Vector3.ZERO)
			var b: Vector3 = poses[segment + 1].get(bone, Vector3.ZERO)
			var m: Array = tangents[bone]
			pose[bone] = _hermite(a, b, m[segment], m[segment + 1], times[segment], times[segment + 1], t)
		out.append(PlaceholderAnims.PoseKey.new(t, pose))
	return out


## Fritsch-Carlson tangents of `values` at `times`, per axis. A loop wraps (its last key repeats its
## first); a clip that plays once has zero tangents at its ends (but the first's, with `drive_in`).
static func _tangents(times: Array[float], values: Array[Vector3], loop: bool, drive_in: bool) -> Array[Vector3]:
	var n := times.size()
	var slope: Array[Vector3] = []
	var span: Array[float] = []
	for i: int in n - 1:
		var h := maxf(times[i + 1] - times[i], 1e-6)
		span.append(h)
		slope.append((values[i + 1] - values[i]) / h)
	var out: Array[Vector3] = []
	for i: int in n:
		var before_slope := Vector3.ZERO
		var after_slope := Vector3.ZERO
		var before_span := 0.0
		var after_span := 0.0
		var has_before := i > 0
		var has_after := i < n - 1
		if i > 0:
			before_slope = slope[i - 1]
			before_span = span[i - 1]
		if i < n - 1:
			after_slope = slope[i]
			after_span = span[i]
		# A loop's first and last keys are the same pose: each sees the other side's segment.
		if loop and n > 2:
			if i == 0:
				before_slope = slope[n - 2]
				before_span = span[n - 2]
				has_before = true
			elif i == n - 1:
				after_slope = slope[0]
				after_span = span[0]
				has_after = true
		var m := Vector3.ZERO
		if has_before and has_after:
			for axis: int in 3:
				var d0 := before_slope[axis]
				var d1 := after_slope[axis]
				if d0 * d1 > 0.0:
					var w0 := 2.0 * after_span + before_span
					var w1 := after_span + 2.0 * before_span
					m[axis] = (w0 + w1) / (w0 / d0 + w1 / d1)
		elif drive_in and i == 0 and has_after:
			m = after_slope
		out.append(m)
	return out


static func _hermite(a: Vector3, b: Vector3, ma: Vector3, mb: Vector3, t0: float, t1: float, t: float) -> Vector3:
	var h := maxf(t1 - t0, 1e-6)
	var s := clampf((t - t0) / h, 0.0, 1.0)
	var s2 := s * s
	var s3 := s2 * s
	return a * (2.0 * s3 - 3.0 * s2 + 1.0) + ma * h * (s3 - 2.0 * s2 + s) \
			+ b * (-2.0 * s3 + 3.0 * s2) + mb * h * (s3 - s2)


# --- Helpers ----------------------------------------------------------------------------------------


## `pose[bone] += delta`.
static func _add(pose: Dictionary[StringName, Vector3], bone: StringName, delta: Vector3) -> void:
	pose[bone] = pose.get(bone, Vector3.ZERO) + delta


static func _union(a: Dictionary[StringName, Vector3], b: Dictionary[StringName, Vector3]) -> Array[StringName]:
	var out: Array[StringName] = []
	for key: StringName in a:
		out.append(key)
	for key: StringName in b:
		if not out.has(key):
			out.append(key)
	return out
