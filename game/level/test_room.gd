extends Node3D
## Milestone 1 graybox test room: a short street (axis = world X), the player, three
## training dummies, a pipe, the camera director and the HUD. Built in code so it stays
## readable as text; layout numbers live in the exports below. From Milestone 4 the sky, the
## boxes, the materials and the presentation come from RoomKit, like the crowd room's, so one
## look (the toon materials, the edge pass, the grade) serves both rooms.
## The centre dummy spars (throws telegraphed jabs to block); F5 ("sparring") toggles
## sparring on all three. A KO'd player gets back up after Tuning.player_revive_s.

const PLAYER_SCENE := "res://game/player/player.tscn"
const DUMMY_SCENE := "res://game/enemies/dummy/training_dummy.tscn"
const PIPE_SCENE := "res://game/weapons/pipe.tscn"

@export var street_length: float = 40.0
@export var street_width: float = 14.0
## The fight runs down the street (+X), as in a belt-scroller, so the side-view debug
## camera sees attacker and target side by side.
@export var player_start: Vector3 = Vector3(-4.0, 0.0, 0.0)
@export_range(-180.0, 180.0, 1.0) var player_yaw_deg: float = -90.0
@export var dummy_positions: Array[Vector3] = [
	Vector3(-0.8, 0.0, -1.8), Vector3(-0.5, 0.0, 0.0), Vector3(-0.8, 0.0, 1.8)
]
@export var dummy_colors: Array[Color] = [
	Color(0.86, 0.5, 0.16), Color(0.5, 0.72, 0.2), Color(0.62, 0.32, 0.72)
]
@export var pipe_position: Vector3 = Vector3(-3.0, 0.15, 2.6)
## Indices of the dummies that spar from the start (Dummy 2, the centre one).
@export var sparring_dummies: Array[int] = [1]
## Build the presentation layer (cameras, HUD). Tests can turn this off.
@export var with_presentation: bool = true

var player: PlayerCharacter
var dummies: Array[TrainingDummy] = []


func _ready() -> void:
	_build_environment()
	_build_street()
	_spawn_actors()
	if with_presentation:
		_build_presentation()


func _unhandled_input(event: InputEvent) -> void:
	# F4 (cheats) and F1 (tuning panel) belong to the TuningOverlay (_build_presentation()).
	if event.is_action_pressed(&"sparring"):
		toggle_sparring()
		get_viewport().set_input_as_handled()


## F5: every dummy spars (guard-break and crowd practice), or, if all already do, none.
func toggle_sparring() -> void:
	var all_on := true
	for dummy: TrainingDummy in dummies:
		all_on = all_on and dummy.sparring
	for dummy: TrainingDummy in dummies:
		dummy.sparring = not all_on


func _build_environment() -> void:
	RoomKit.build_environment(self)


func _build_street() -> void:
	_add_box(Vector3(0.0, -0.5, 0.0), Vector3(street_length + 20.0, 1.0, street_width + 20.0), RoomKit.grid_material())

	var wall_mat := RoomKit.flat_material(Color(0.42, 0.4, 0.44))
	var accent_mat := RoomKit.flat_material(Color(0.5, 0.46, 0.4))
	var half_l := street_length * 0.5
	var half_w := street_width * 0.5
	# Far side (-Z): building fronts of varied height, like the reference's backdrop.
	var x := -half_l
	var i := 0
	while x < half_l:
		var w := 5.0 + float(i % 3) * 1.5
		var h := 5.0 + float((i * 7) % 4) * 1.5
		_add_box(Vector3(x + w * 0.5, h * 0.5, -half_w - 1.0), Vector3(w, h, 2.0), wall_mat if i % 2 == 0 else accent_mat)
		x += w
		i += 1
	# Street ends.
	_add_box(Vector3(-half_l - 1.0, 2.5, 0.0), Vector3(2.0, 5.0, street_width + 2.0), wall_mat)
	_add_box(Vector3(half_l + 1.0, 2.5, 0.0), Vector3(2.0, 5.0, street_width + 2.0), wall_mat)
	# Near side (+Z) stays low so the side-view debug camera can see the street.
	_add_box(Vector3(0.0, 0.3, half_w + 0.25), Vector3(street_length, 0.6, 0.5), accent_mat)
	# Crates for spatial reference and cover.
	var crate_mat := RoomKit.prop_material(Color(0.55, 0.46, 0.3))
	for p: Vector3 in [Vector3(-7.0, 0.5, -4.5), Vector3(-6.0, 0.5, -5.2), Vector3(8.0, 0.5, 4.5)]:
		_add_box(p, Vector3(1.0, 1.0, 1.0), crate_mat)
	# Dashed center line along the street.
	var paint := RoomKit.flat_material(Color(0.82, 0.8, 0.72))
	var dash := -half_l + 1.0
	while dash < half_l:
		_add_visual_box(Vector3(dash + 0.75, 0.005, -2.0), Vector3(1.5, 0.01, 0.15), paint)
		dash += 3.0


func _spawn_actors() -> void:
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerCharacter
	player.position = player_start
	player.rotation.y = deg_to_rad(player_yaw_deg)
	player.auto_revive = true
	add_child(player)
	for n in dummy_positions.size():
		var dummy := (load(DUMMY_SCENE) as PackedScene).instantiate() as TrainingDummy
		dummy.name = "Dummy%d" % (n + 1)
		dummy.display_name = "Dummy %d" % (n + 1)
		dummy.color = dummy_colors[n % dummy_colors.size()]
		dummy.position = dummy_positions[n]
		var to_player := player_start - dummy_positions[n]
		dummy.rotation.y = atan2(-to_player.x, -to_player.z)  # face the player start
		dummy.sparring = sparring_dummies.has(n)
		add_child(dummy)
		dummies.append(dummy)
	var pipe := (load(PIPE_SCENE) as PackedScene).instantiate() as Weapon
	pipe.position = pipe_position
	pipe.rotation_degrees = Vector3(0.0, 30.0, 90.0)
	add_child(pipe)


## Cameras, HUD, the F1 tuning panel and F4 cheat menu, the VFX, audio and rumble directors
## and the look's post pass: RoomKit.build_presentation(), the crowd room's too.
func _build_presentation() -> void:
	RoomKit.build_presentation(self)


func _add_box(pos: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	return RoomKit.add_box(self, pos, size, material)


func _add_visual_box(pos: Vector3, size: Vector3, material: Material) -> void:
	RoomKit.add_visual_box(self, pos, size, material)
