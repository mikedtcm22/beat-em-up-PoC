class_name FirstPersonCamera
extends Camera3D
## The player's view (Spec §5 and §6). It rides the player's EyePoint, takes its rotation
## only from the player's look plus the running move's camera offset (never from the head
## bone), and adds the hit-feel camera punch and trauma screen shake on top.
## Presentation only: it reads the player once per frame in _process and never writes
## simulation state. CameraDirector creates it and assigns `player`.
##
## Smoothing: the camera follows the player's origin rigidly and damps only the eye's
## offset from that origin, with time constant Tuning.data.cam_smoothing_s. Head-bone
## jitter from the animation is steadied, while walking, lunges, dodges and knockback
## never leave the view trailing behind the head.
##
## Even motion at frame rates other than 60 fps needs project physics interpolation
## (physics/common/physics_interpolation = true). The origin is read with
## get_global_transform_interpolated(), which then lies between the last two physics
## ticks, so the view moves evenly at any frame rate and in step with the interpolated
## body. With interpolation off that call returns the latest tick, and the view moves in
## 60 Hz steps (as do the body and every other actor), which judders on faster displays.
## The camera does not smooth those steps on its own: the full body renders in first
## person (Spec §5) and would then jitter against the view instead.

## Seconds a camera punch takes to snap out and spring back to rest.
@export_range(0.03, 0.5, 0.01) var punch_duration_s: float = 0.12
## Share of punch_duration_s spent snapping out to the peak; the rest eases back.
@export_range(0.05, 0.9, 0.05) var punch_attack_share: float = 0.25
## Trauma removed per real-time second.
@export_range(0.1, 10.0, 0.1) var trauma_decay_per_s: float = 1.5
## Shake rotation (pitch, yaw and roll, each) at trauma 1 and intensity 1, in degrees.
@export_range(0.0, 10.0, 0.1) var shake_max_deg: float = 3.0
## Shake offset (each axis) at trauma 1 and intensity 1, in meters.
@export_range(0.0, 0.2, 0.005) var shake_max_offset_m: float = 0.04
## How fast the shake noise is sampled; higher rattles faster.
@export_range(1.0, 60.0, 1.0) var shake_frequency_hz: float = 15.0

## Total pitch is clamped to this, so a downward move offset on top of looking straight
## down never flips the view over.
const PITCH_LIMIT_RAD := PI * 89.0 / 180.0
## A punch whose contact point is this close to screen center (radians) dips the view
## instead, since "toward the contact" has no direction there.
const PUNCH_CENTER_RAD := PI / 180.0

## The player this camera rides. Null (or freed) holds the last view.
var player: PlayerCharacter:
	set = set_player
## Screen-shake trauma, 0 to 1. Shake strength is trauma squared.
var trauma: float = 0.0

## Eye position relative to the player's origin, smoothed.
var _eye_offset: Vector3 = Vector3.ZERO
var _has_eye: bool = false
## The view before punch and shake: where the player is looking.
var _view: Transform3D = Transform3D.IDENTITY
## Live punches: x = pitch kick and y = yaw kick at the peak (radians), z = age (seconds).
var _punches: Array[Vector3] = []
var _shake_time: float = 0.0
var _noise: FastNoiseLite = FastNoiseLite.new()


func _init() -> void:
	top_level = true
	keep_aspect = Camera3D.KEEP_WIDTH
	near = 0.05
	# Also set in _init, so a camera that takes over this view before it enters the tree
	# (free fly picked early) copies the right field of view.
	fov = Tuning.data.fov_deg
	set_cull_mask_value(CombatTypes.VIS_FP_HIDDEN, false)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	_noise.frequency = 1.0


func _enter_tree() -> void:
	if not CombatEvents.hit_landed.is_connected(_on_hit_landed):
		CombatEvents.hit_landed.connect(_on_hit_landed)


func _exit_tree() -> void:
	if CombatEvents.hit_landed.is_connected(_on_hit_landed):
		CombatEvents.hit_landed.disconnect(_on_hit_landed)


func _ready() -> void:
	fov = Tuning.data.fov_deg


func _process(delta: float) -> void:
	update_camera(delta)


## Ride `value` from now on, jumping straight to its eye on the next update.
func set_player(value: PlayerCharacter) -> void:
	player = value
	snap()


## Jump straight to the eye point on the next update instead of easing toward it.
func snap() -> void:
	_has_eye = false


## Advance one presentation frame of `delta` real seconds: follow the player, age the punch
## and shake, and place the camera. _process calls this; tests may call it directly.
func update_camera(delta: float) -> void:
	fov = Tuning.data.fov_deg
	if _player_ok():
		_view = _follow(delta)
	_advance_effects(delta)
	global_transform = _view * _effects_transform()


## The view without punch and shake: the player's eye and look direction.
func view_transform() -> Transform3D:
	return _view


## Add screen-shake trauma (clamped to 0..1). Hits involving the player add
## Tuning.data.shake(tier) on their own.
func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Start a camera punch that peaks at `kick_deg` (x = pitch, positive looks up; y = yaw,
## positive turns left) and springs back over punch_duration_s. A punch that arrives while
## another is still snapping out (one strike hitting several victims) joins it: one punch
## toward their combined direction, as strong as the stronger of the two. Later punches
## overlap, but the total never exceeds the strongest live punch.
func add_punch(kick_deg: Vector2) -> void:
	if kick_deg.is_zero_approx():
		return
	var kick := Vector2(deg_to_rad(kick_deg.x), deg_to_rad(kick_deg.y))
	var attack_s := punch_duration_s * punch_attack_share
	for i: int in _punches.size():
		var live := _punches[i]
		if live.z >= attack_s:
			continue
		var peak := Vector2(live.x, live.y)
		var strength := maxf(peak.length(), kick.length())
		var combined := peak + kick
		if combined.is_zero_approx():
			# Opposite kicks cancel: keep the stronger one's direction.
			combined = peak if peak.length() >= kick.length() else kick
		combined = combined.normalized() * strength
		_punches[i] = Vector3(combined.x, combined.y, live.z)
		return
	_punches.append(Vector3(kick.x, kick.y, 0.0))


## Current punch rotation in degrees (x = pitch, y = yaw).
func get_punch_deg() -> Vector2:
	var punch := _punch_rad()
	return Vector2(rad_to_deg(punch.x), rad_to_deg(punch.y))


## True when no punch is running and trauma is zero.
func is_settled() -> bool:
	return trauma <= 0.0 and _punches.is_empty()


func _player_ok() -> bool:
	return is_instance_valid(player) and player.is_inside_tree()


func _follow(delta: float) -> Transform3D:
	var origin := player.global_position
	var eye := player.get_eye_transform().origin - origin
	if player.is_walking():
		# Steady view while walking: the eye may bob only this far from its idle height.
		var bob := Tuning.data.cam_bob_clamp_m
		var idle := player.standing_eye_height
		eye.y = clampf(eye.y, idle - bob, idle + bob)
	if _has_eye:
		var weight := CameraMath.damp_weight(delta, Tuning.data.cam_smoothing_s)
		_eye_offset = _eye_offset.lerp(eye, weight)
	else:
		_eye_offset = eye
		_has_eye = true
	# x = extra pitch in degrees, y = drop in meters along world -Y. Already eased.
	var move_offset := player.get_camera_move_offset()
	var root := player.get_global_transform_interpolated().origin
	var eye_position := root + _eye_offset + Vector3.DOWN * move_offset.y
	var ahead := player.get_look_basis() * Vector3.FORWARD
	ahead.y = 0.0
	if ahead.length_squared() > 0.0001:
		eye_position += ahead.normalized() * Tuning.data.cam_forward_offset_m
	var look := _add_pitch(player.get_look_basis(), deg_to_rad(move_offset.x))
	return Transform3D(look, eye_position)


func _advance_effects(delta: float) -> void:
	_shake_time += delta
	trauma = maxf(0.0, trauma - trauma_decay_per_s * delta)
	for i: int in range(_punches.size() - 1, -1, -1):
		var punch := _punches[i]
		punch.z += delta
		if punch.z >= punch_duration_s:
			_punches.remove_at(i)
		else:
			_punches[i] = punch


## Punch and shake as a transform in the view's local space.
func _effects_transform() -> Transform3D:
	var punch := _punch_rad()
	var rotation_rad := Vector3(punch.x, punch.y, 0.0)
	var offset := Vector3.ZERO
	var amount := trauma * trauma * Tuning.data.screen_shake_intensity
	if amount > 0.0:
		var max_rad := deg_to_rad(shake_max_deg) * amount
		var max_m := shake_max_offset_m * amount
		rotation_rad += Vector3(_shake_noise(0), _shake_noise(1), _shake_noise(2)) * max_rad
		offset = Vector3(_shake_noise(3), _shake_noise(4), _shake_noise(5)) * max_m
	if rotation_rad == Vector3.ZERO and offset == Vector3.ZERO:
		return Transform3D.IDENTITY
	return Transform3D(Basis.from_euler(rotation_rad), offset)


## Sum of the live punches in radians (x = pitch, y = yaw), no longer than the strongest
## live punch's peak, so overlapping hits never punch harder than their tier.
func _punch_rad() -> Vector2:
	var total := Vector2.ZERO
	var strongest := 0.0
	for punch: Vector3 in _punches:
		var peak := Vector2(punch.x, punch.y)
		total += peak * _punch_envelope(punch.z / punch_duration_s)
		strongest = maxf(strongest, peak.length())
	return total.limit_length(strongest)


## Smooth noise in -1..1, one independent channel per shake axis.
func _shake_noise(channel: int) -> float:
	var sample := _noise.get_noise_2d(_shake_time * shake_frequency_hz, float(channel) * 37.0)
	return clampf(sample, -1.0, 1.0)


## Quick snap out (ease-out sine) then a smooth ease back to rest; u is age / duration.
func _punch_envelope(u: float) -> float:
	if u <= 0.0 or u >= 1.0:
		return 0.0
	if u < punch_attack_share:
		return sin(u / punch_attack_share * PI * 0.5)
	return 0.5 + 0.5 * cos((u - punch_attack_share) / (1.0 - punch_attack_share) * PI)


func _on_hit_landed(hit: HitInfo) -> void:
	if hit == null or not _player_ok():
		return
	var is_attacker := hit.attacker == player
	if not is_attacker and hit.victim != player:
		return
	add_trauma(Tuning.data.shake(hit.tier))
	var direction := _toward(hit.contact_point) if is_attacker else _away(hit)
	add_punch(direction * Tuning.data.cam_punch_deg(hit.tier))


## Unit kick (x = pitch up, y = yaw left) that turns the view toward `point`. A contact at
## screen center dips the view, as if leaning into the blow.
func _toward(point: Vector3) -> Vector2:
	var local := _view.basis.inverse() * (point - _view.origin)
	var horizontal := Vector2(local.x, local.z).length()
	var angles := Vector2(atan2(local.y, horizontal), atan2(-local.x, -local.z))
	if angles.length() < PUNCH_CENTER_RAD:
		return Vector2(-1.0, 0.0)
	return angles.normalized()


## Unit kick (x = pitch up, y = yaw left) that jolts the view the way the hit pushes the
## player: pushed back tips the head up, pushed sideways turns it with the push.
func _away(hit: HitInfo) -> Vector2:
	var push := hit.direction
	if push.is_zero_approx():
		push = _view.origin - hit.contact_point
	var local := _view.basis.inverse() * push
	var kick := Vector2(local.z, -local.x)
	if kick.is_zero_approx():
		return Vector2(1.0, 0.0)
	return kick.normalized()


## `look` with `extra_pitch` radians more pitch, the total clamped short of straight up/down.
static func _add_pitch(look: Basis, extra_pitch: float) -> Basis:
	var euler := look.get_euler()
	euler.x = clampf(euler.x + extra_pitch, -PITCH_LIMIT_RAD, PITCH_LIMIT_RAD)
	return Basis.from_euler(euler)
