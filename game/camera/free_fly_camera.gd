class_name FreeFlyCamera
extends Camera3D
## Debug free-fly camera (Spec §11). It starts exactly where the previously active camera
## was, flies with the fly_* actions (arrow keys, Page Up/Down) in its own look direction
## and steers with GameInput.consume_fly_mouse_delta(), which only collects mouse motion
## while the middle button is held. The player therefore keeps WASD and the mouse, and
## gameplay keeps running. It shows every render layer. Presentation only.
## CameraDirector creates it and calls activate_from() when switching to it.

## Flying speed in meters per second.
@export_range(0.5, 50.0, 0.5) var fly_speed: float = 6.0

## Pitch limit, so the view never flips over the vertical.
const PITCH_LIMIT_RAD := PI * 89.0 / 180.0

var _yaw: float = 0.0
var _pitch: float = 0.0


func _init() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(delta: float) -> void:
	update_camera(delta)


## Start where `source` is, with its field of view, so switching does not jump. With a
## null source it stays where it is.
func activate_from(source: Camera3D) -> void:
	if source != null:
		global_transform = source.global_transform
		fov = source.fov
		keep_aspect = source.keep_aspect
	var euler := global_basis.get_euler()
	_pitch = euler.x
	_yaw = euler.y
	# Drop look motion gathered before this camera took over.
	GameInput.consume_fly_mouse_delta()


## Advance one presentation frame of `delta` real seconds from the fly_* actions and the
## fly mouse delta. Only the current camera moves; otherwise the mouse delta is discarded.
func update_camera(delta: float) -> void:
	var look_pixels := GameInput.consume_fly_mouse_delta()
	if not current:
		return
	var move := Vector3(
		Input.get_axis(&"fly_left", &"fly_right"),
		Input.get_axis(&"fly_down", &"fly_up"),
		Input.get_axis(&"fly_forward", &"fly_back"))
	fly(delta, move, look_pixels)


## Turn by `look_pixels` of mouse motion (Tuning.data.mouse_sensitivity degrees per pixel),
## then move for `delta` seconds at fly_speed. `move` is x = right, y = world up, z = back
## (so -1 flies forward along the look direction), each -1..1.
func fly(delta: float, move: Vector3, look_pixels: Vector2) -> void:
	if look_pixels != Vector2.ZERO:
		var rad_per_pixel := deg_to_rad(Tuning.data.mouse_sensitivity)
		var pitch_pixels := -look_pixels.y if Tuning.data.invert_look_y else look_pixels.y
		_yaw = wrapf(_yaw - look_pixels.x * rad_per_pixel, -PI, PI)
		_pitch = clampf(_pitch - pitch_pixels * rad_per_pixel, -PITCH_LIMIT_RAD, PITCH_LIMIT_RAD)
		global_basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	var input := move.normalized() if move.length_squared() > 1.0 else move
	var axes := global_basis.orthonormalized()
	var velocity := (axes.x * input.x + Vector3.UP * input.y + axes.z * input.z) * fly_speed
	global_position += velocity * delta
