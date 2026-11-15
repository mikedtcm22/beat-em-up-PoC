extends Node
## Milestone 7 (e-rooms): first-person stills of the two practice rooms under the trailer look (a look-dev stage, not a test). The room has its
## waves off and its AI frozen; the player stands at each station and looks (yaw, pitch); the crowd room shows one of every enemy type in front.
## Record it with Movie Maker and cut a still near the end of each station (STATION_FRAMES):
##   godot --path . --write-movie out.avi --fixed-fps 60 --resolution 1600x900 --quit-after 200 res://tests/fixtures/m7/rooms_stage.tscn -- --room=crowd
## Arguments: --room=crowd|training (default crowd), --profile=m6 (the same shots under the m6 look).
const CROWD_PATH := "res://game/level/crowd_room.tscn"
const TRAINING_PATH := "res://game/level/test_room.tscn"
const STATION_FRAMES := 60
## {at, yaw, pitch, enemies: [{id, at, yaw}]}; the crowd room's enemies are one of each type on an arc in front of the player.
const CROWD_STATIONS: Array[Dictionary] = [
	{at = Vector3(-2.0, 0.0, 0.0), yaw = -90.0, pitch = 4.0, enemies = [
		{id = &"thug", at = Vector3(3.4, 0.0, -2.3), yaw = 100.0}, {id = &"punk", at = Vector3(2.5, 0.0, -0.9), yaw = 90.0},
		{id = &"kicker", at = Vector3(2.5, 0.0, 0.9), yaw = 90.0}, {id = &"bruiser", at = Vector3(3.6, 0.0, 2.4), yaw = 80.0},
		{id = &"boss", at = Vector3(5.6, 0.0, 0.0), yaw = 90.0}]},
	{at = Vector3(1.0, 0.0, 2.0), yaw = 0.0, pitch = 14.0, enemies = []},
	{at = Vector3(-9.0, 0.0, -1.0), yaw = 90.0, pitch = 6.0, enemies = []},
]
const TRAINING_STATIONS: Array[Dictionary] = [
	{at = Vector3(-4.0, 0.0, 0.0), yaw = -90.0, pitch = 4.0, enemies = []},
	{at = Vector3(-6.0, 0.0, 1.0), yaw = -115.0, pitch = 14.0, enemies = []},
	{at = Vector3(6.0, 0.0, 0.0), yaw = 90.0, pitch = 6.0, enemies = []},
]

var _room: Node3D
var _crowd: bool = true
var _frame: int = 0
var _spawned: Array[Node] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_crowd = not args.has("--room=training")
	Tuning.set_value(&"waves_enabled", false)
	Tuning.set_value(&"god_mode", true)
	Tuning.set_value(&"ai_frozen", true)
	Tuning.set_value(&"look_profile", 0 if args.has("--profile=m6") else 1)
	Tuning.set_value(&"cutins_enabled", false)
	_room = (load(CROWD_PATH if _crowd else TRAINING_PATH) as PackedScene).instantiate() as Node3D
	if _crowd:
		(_room as CrowdRoom).waves_enabled_on_start = false
	add_child(_room)
	for layer: Node in _room.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false


func _physics_process(_delta: float) -> void:
	if _room == null or _room.get("player") == null:
		return
	var stations := CROWD_STATIONS if _crowd else TRAINING_STATIONS
	var station := _frame / STATION_FRAMES
	if station >= stations.size():
		print("ROOMS-STAGE done")
		get_tree().quit()
		return
	if _frame % STATION_FRAMES == 0:
		_go(stations[station])
		print("ROOMS-STAGE station %d frame %d" % [station, _frame])
	_frame += 1


func _go(station: Dictionary) -> void:
	for node in _spawned:
		if is_instance_valid(node):
			EncounterSpawner.remove_enemy(node)
	_spawned.clear()
	var player := _room.get("player") as PlayerCharacter
	player.reset_state()
	player.global_position = station.at
	player.velocity = Vector3.ZERO
	player.rotation.y = deg_to_rad(float(station.yaw))
	player.look_yaw = deg_to_rad(float(station.yaw))
	player.look_pitch = deg_to_rad(float(station.pitch))
	var spawner := _room.get("spawner") as EncounterSpawner
	for entry: Dictionary in station.enemies:
		var enemy := spawner.spawn_enemy(entry.id, (station.at as Vector3) + (entry.at as Vector3), deg_to_rad(float(entry.yaw)))
		if enemy != null:
			_spawned.append(enemy)
