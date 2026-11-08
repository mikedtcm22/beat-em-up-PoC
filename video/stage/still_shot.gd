class_name VideoStillShot
extends Resource
## One still of the stills stage, as data: where the player stands, which actors are in the frame, where the
## camera is and how long the room warms up. One `.tres` per still in `res://video/stills/`; the still bot
## (still_bot.gd) reads them and `VideoStillGrab` renders the frame at 2560x1440.
## All positions are in the space of the level section `section` (0 the street, 1 the roofs, 2 the boss roof),
## like the arena tour's poses. Yaw 0 looks along -Z, -90 along +X, 90 along -X.

## The still's file name (`<out dir>/<key>.png`) and its act title ("Still: <key>").
@export var key: StringName = &""
## What the still is for (a line for the reader of the .tres).
@export_multiline var note: String = ""
## The level section the still is in (0 street, 1 roofs, 2 boss roof).
@export_range(0, 2) var section: int = 0
## The player's feet, yaw and pitch (degrees). In a free-camera still he only keeps the section light on this
## section: stand him out of frame.
@export var player_pos: Vector3 = Vector3.ZERO
@export_range(-180.0, 180.0) var player_yaw_deg: float = 0.0
@export_range(-85.0, 85.0) var player_pitch_deg: float = 0.0
## A button the player presses once the room has warmed up (&"P" a punch; empty = none) and the physics
## ticks after the press at which the time is stopped, so the pose is held for the grab.
@export var player_button: StringName = &""
@export_range(0, 120) var player_button_ticks: int = 0
## First person (the game's own camera, riding the player's eyes) or a free camera.
@export var first_person: bool = true
## First person: the horizontal FOV in degrees (0 leaves the game's setting).
@export_range(0.0, 110.0) var first_person_fov_deg: float = 0.0
## Free camera: its position, the point it looks at and its horizontal FOV (degrees).
@export var cam_pos: Vector3 = Vector3.ZERO
@export var cam_look_at: Vector3 = Vector3.ZERO
@export_range(10.0, 120.0) var cam_fov_deg: float = 70.0
## The actors in the frame (spawned from the enemy catalog and held still).
@export var actors: Array[VideoStillActor] = []
## Video-only street lamp posts (the game has none), the feet of each.
@export var lamp_posts: PackedVector3Array = PackedVector3Array()
## Lamp post dimensions: the pole's height and radius, and the lamp head's edge (m).
@export_range(1.0, 10.0) var lamp_height_m: float = 4.5
@export_range(0.02, 0.5) var lamp_pole_radius_m: float = 0.08
@export_range(0.1, 1.5) var lamp_head_m: float = 0.45
## Physics ticks the room runs before the grab, so the light, the actors and the camera have settled.
@export_range(0, 600) var warmup_ticks: int = 40
