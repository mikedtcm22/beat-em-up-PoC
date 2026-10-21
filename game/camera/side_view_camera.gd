class_name SideViewCamera
extends Camera3D
## Debug side view (Spec §11): a classic belt-scroller shot of the street. The street axis
## is world X; the camera sits on the +Z side looking toward -Z, slightly down at the
## player, follows them along X and drifts slowly in height and depth so jumps barely move
## the shot. Its direction never changes, so the view pans like a 2D scroller. It shows
## every render layer, including the player's head. Presentation only.
## CameraDirector creates it and assigns `player`.

## Vertical field of view in degrees.
@export_range(10.0, 90.0, 1.0) var view_fov_deg: float = 38.0
## Distance from the player's Z line toward +Z, in meters.
@export_range(2.0, 40.0, 0.5) var distance_m: float = 11.0
## Camera height above the player's feet, in meters.
@export_range(0.0, 20.0, 0.1) var height_m: float = 3.5
## The camera aims at the player's origin raised by this much, in meters.
@export_range(0.0, 3.0, 0.05) var look_height_m: float = 1.0
## Time constant for following along the street (X), in seconds.
@export_range(0.0, 2.0, 0.01) var follow_x_time_s: float = 0.15
## Time constant for following height and depth (Y and Z), in seconds.
@export_range(0.0, 5.0, 0.05) var follow_yz_time_s: float = 0.6

## The player to follow. Null (or freed) holds the last shot.
var player: PlayerCharacter:
	set = set_player

## Smoothed point on the ground the shot is framed around.
var _focus: Vector3 = Vector3.ZERO
var _has_focus: bool = false


func _init() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ready() -> void:
	fov = view_fov_deg


func _process(delta: float) -> void:
	update_camera(delta)


## Follow `value` from now on, jumping straight to it on the next update.
func set_player(value: PlayerCharacter) -> void:
	player = value
	snap()


## Jump straight to the player on the next update instead of easing toward them.
func snap() -> void:
	_has_focus = false


## Advance one presentation frame of `delta` real seconds. _process calls this; tests may
## call it directly.
func update_camera(delta: float) -> void:
	fov = view_fov_deg
	if is_instance_valid(player) and player.is_inside_tree():
		var target := player.get_global_transform_interpolated().origin
		if _has_focus:
			var along := CameraMath.damp_weight(delta, follow_x_time_s)
			var across := CameraMath.damp_weight(delta, follow_yz_time_s)
			_focus = Vector3(
				lerpf(_focus.x, target.x, along),
				lerpf(_focus.y, target.y, across),
				lerpf(_focus.z, target.z, across))
		else:
			_focus = target
			_has_focus = true
	var eye := _focus + Vector3(0.0, height_m, distance_m)
	var aim := _focus + Vector3.UP * look_height_m
	global_transform = Transform3D(Basis.looking_at(aim - eye, Vector3.UP), eye)
