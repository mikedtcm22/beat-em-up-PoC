class_name CineCamera
extends Camera3D
## The cine shots' camera (P1.md, LD-STAGE): a keyframed path (CineCameraKey), a look-at target, FOV and focus keys, and a
## depth of field from the focus keys. It is driven by the shot clock, never by `TIME`: the director calls `set_time()` each
## physics tick, so the same shot gives the same frames on every run. `sample()` is the pure path function (the tests and the
## director's preview use it).

## What the path gives at one time: the pose (world space), the lens and the focus.
class Pose:
	extends RefCounted
	var position: Vector3 = Vector3.ZERO
	var look_at: Vector3 = Vector3.ZERO
	var fov_deg: float = 60.0
	var focus_m: float = 0.0
	var focus_range_m: float = 3.0
	var roll_deg: float = 0.0


## The keys of the path (section space), sorted by time, and the world position of the section they are relative to.
var keys: Array[CineCameraKey] = []
var origin: Vector3 = Vector3.ZERO
## The world positions to follow, in the shot's actor order (a key with `target_actor` looks at its entry plus its offset).
var actor_points: Array[Vector3] = []
## The shot clock the camera last evaluated, in seconds.
var shot_time_s: float = 0.0
## The depth of field's transition (a share of the focus distance) and the blur's strength, as the camera's own data.
@export_range(0.05, 4.0) var dof_transition_share: float = 0.6
@export_range(0.0, 4.0) var dof_amount: float = 0.1

var _attributes: CameraAttributesPractical


func _init() -> void:
	top_level = true
	keep_aspect = Camera3D.KEEP_WIDTH
	_attributes = CameraAttributesPractical.new()


## Set the path and its origin; the keys are sorted by time.
func setup(p_keys: Array[CineCameraKey], p_origin: Vector3) -> void:
	keys = p_keys.duplicate()
	keys.sort_custom(func(a: CineCameraKey, b: CineCameraKey) -> bool: return a.time_s < b.time_s)
	origin = p_origin


## Evaluate the path at `t` seconds and put the camera there.
func set_time(t: float) -> void:
	shot_time_s = t
	if keys.is_empty():
		return
	var pose := CineCamera.sample(keys, t, origin, actor_points)
	var forward := pose.look_at - pose.position
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	var up := Vector3.UP
	if absf(forward.normalized().dot(up)) > 0.999:
		up = Vector3.FORWARD
	var basis := Basis.looking_at(forward, up)
	basis = basis * Basis(Vector3.BACK, deg_to_rad(pose.roll_deg))
	global_transform = Transform3D(basis, pose.position)
	fov = pose.fov_deg
	_apply_focus(pose)


func _apply_focus(pose: Pose) -> void:
	if pose.focus_m <= 0.0:
		_attributes.dof_blur_far_enabled = false
		_attributes.dof_blur_near_enabled = false
		attributes = null
		return
	var range_m := pose.focus_range_m
	var far_start := pose.focus_m + range_m
	var near_end := maxf(pose.focus_m - range_m, 0.0)
	_attributes.dof_blur_far_enabled = true
	_attributes.dof_blur_far_distance = far_start
	_attributes.dof_blur_far_transition = maxf(far_start * dof_transition_share, 0.5)
	_attributes.dof_blur_near_enabled = near_end > 0.2
	_attributes.dof_blur_near_distance = near_end
	_attributes.dof_blur_near_transition = maxf(near_end * dof_transition_share, 0.2)
	_attributes.dof_blur_amount = dof_amount
	attributes = _attributes


## The path at time `t`: `keys` (sorted by time, section space) relative to `origin`, with `actors` the world positions the keys'
## `target_actor` indices follow. Before the first key and after the last it holds that key. Positions and look-at points go
## through a Catmull-Rom spline (so the camera does not stop at each key), the lens, focus and roll blend linearly. Each
## segment's timing is its starting key's ease.
static func sample(keys: Array[CineCameraKey], t: float, origin: Vector3, actors: Array[Vector3] = []) -> Pose:
	var pose := Pose.new()
	if keys.is_empty():
		return pose
	var last := keys.size() - 1
	if t <= keys[0].time_s or keys.size() == 1:
		return _pose_of(keys[0], origin, actors)
	if t >= keys[last].time_s:
		return _pose_of(keys[last], origin, actors)
	var i := 0
	while i < last - 1 and t >= keys[i + 1].time_s:
		i += 1
	var a := keys[i]
	var b := keys[i + 1]
	var span := maxf(b.time_s - a.time_s, 0.0001)
	var u := clampf((t - a.time_s) / span, 0.0, 1.0)
	if a.ease == CineCameraKey.Ease.SMOOTH:
		u = u * u * (3.0 - 2.0 * u)
	var before := keys[maxi(i - 1, 0)]
	var after := keys[mini(i + 2, last)]
	var pa := _pose_of(a, origin, actors)
	var pb := _pose_of(b, origin, actors)
	var p0 := _pose_of(before, origin, actors)
	var p3 := _pose_of(after, origin, actors)
	pose.position = _spline(pa.position, pb.position, p0.position, p3.position, u, a, b, before, after)
	pose.look_at = _spline(pa.look_at, pb.look_at, p0.look_at, p3.look_at, u, a, b, before, after)
	pose.fov_deg = lerpf(pa.fov_deg, pb.fov_deg, u)
	pose.roll_deg = lerpf(pa.roll_deg, pb.roll_deg, u)
	# Focus off at one end: the other end's, so the depth of field does not pop in.
	if pa.focus_m <= 0.0:
		pose.focus_m = pb.focus_m
		pose.focus_range_m = pb.focus_range_m
	elif pb.focus_m <= 0.0:
		pose.focus_m = pa.focus_m
		pose.focus_range_m = pa.focus_range_m
	else:
		pose.focus_m = lerpf(pa.focus_m, pb.focus_m, u)
		pose.focus_range_m = lerpf(pa.focus_range_m, pb.focus_range_m, u)
	return pose


static func _pose_of(key: CineCameraKey, origin: Vector3, actors: Array[Vector3]) -> Pose:
	var pose := Pose.new()
	pose.position = origin + key.position
	if key.target_actor >= 0 and key.target_actor < actors.size():
		pose.look_at = actors[key.target_actor] + key.look_at
	else:
		pose.look_at = origin + key.look_at
	pose.fov_deg = key.fov_deg
	pose.focus_m = key.focus_m
	pose.focus_range_m = key.focus_range_m
	pose.roll_deg = key.roll_deg
	return pose


## A Catmull-Rom point between `b` and `c` (weight `u`), with the end tangents from their neighbours, timed by the keys' times.
static func _spline(b: Vector3, c: Vector3, a: Vector3, d: Vector3, u: float, kb: CineCameraKey, kc: CineCameraKey,
		ka: CineCameraKey, kd: CineCameraKey) -> Vector3:
	var span := maxf(kc.time_s - kb.time_s, 0.0001)
	var before_t := (ka.time_s - kb.time_s) / span
	var after_t := (kd.time_s - kb.time_s) / span
	if is_equal_approx(before_t, 0.0):
		before_t = -1.0
		a = b - (c - b)
	if is_equal_approx(after_t, 1.0):
		after_t = 2.0
		d = c + (c - b)
	return b.cubic_interpolate_in_time(c, a, d, u, 1.0, before_t, after_t)
