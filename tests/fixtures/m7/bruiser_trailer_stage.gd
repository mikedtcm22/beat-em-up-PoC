extends Node
## Milestone 7 (e-bruiser): fight-distance stills of the trailer Bruiser in Mission 1's street (a look-dev stage, not a test). Derived from
## tests/bot/t10_street_bot.gd: the level with the waves off and the AI frozen, the player at one spot, a Bruiser (and a Punk for scale) in
## front at fight distances and angles. Record it with Movie Maker and cut a still near the end of each station (STATION_FRAMES):
##   godot --path . --write-movie out.avi --fixed-fps 60 --resolution 1600x900 --quit-after 240 res://tests/fixtures/m7/bruiser_trailer_stage.tscn
## `--profile=m6` shows the same shots under the m6 look.
const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const STATION_FRAMES := 60
## The player's spot (section space) and the stations: {enemies: [{id, at, yaw}]}; the Bruiser at 2.0 m, then three-quarter at 1.6 m beside a
## Punk, then the smash's distance (1.2 m), the face's most common view in play.
const PLAYER_AT := Vector3(-2.0, 0.0, -25.0)
const PLAYER_YAW := 0.0
const STATIONS: Array[Dictionary] = [
	{pitch = 4.0, enemies = [{id = &"bruiser", at = Vector3(-1.9, 0.0, -27.4), yaw = 180.0}]},
	{pitch = 4.0, enemies = [{id = &"bruiser", at = Vector3(-1.4, 0.0, -27.0), yaw = 145.0}, {id = &"punk", at = Vector3(-3.5, 0.0, -28.0), yaw = 185.0}]},
	{pitch = 12.0, enemies = [{id = &"bruiser", at = Vector3(-2.2, 0.0, -26.4), yaw = 220.0}]},
]

var _level: LevelRoot
var _frame: int = 0
var _spawned: Array[Node] = []


func _ready() -> void:
	var profile := 0 if OS.get_cmdline_user_args().has("--profile=m6") else 1
	Tuning.set_value(&"waves_enabled", false)
	Tuning.set_value(&"god_mode", true)
	Tuning.set_value(&"ai_frozen", true)
	Tuning.set_value(&"look_profile", profile)
	Tuning.set_value(&"cutins_enabled", false)
	_level = (load(LEVEL_PATH) as PackedScene).instantiate() as LevelRoot
	_level.waves_enabled_on_start = false
	add_child(_level)
	for layer: Node in _level.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false


func _physics_process(_delta: float) -> void:
	if _level == null or _level.player == null:
		return
	var station := _frame / STATION_FRAMES
	if station >= STATIONS.size():
		print("BRUISER-STAGE done")
		get_tree().quit()
		return
	if _frame % STATION_FRAMES == 0:
		_go(STATIONS[station])
		print("BRUISER-STAGE station %d frame %d" % [station, _frame])
	_frame += 1


func _go(station: Dictionary) -> void:
	for node in _spawned:
		if is_instance_valid(node):
			EncounterSpawner.remove_enemy(node)
	_spawned.clear()
	var street := _level.sections[0]
	var player := _level.player
	player.reset_state()
	player.global_position = street.to_global(PLAYER_AT)
	player.velocity = Vector3.ZERO
	player.rotation.y = deg_to_rad(PLAYER_YAW)
	player.look_yaw = deg_to_rad(PLAYER_YAW)
	player.look_pitch = deg_to_rad(float(station.pitch))
	for entry: Dictionary in station.enemies:
		var enemy := _level.spawner.spawn_enemy(entry.id, street.to_global(entry.at), deg_to_rad(float(entry.yaw)))
		if enemy != null:
			_spawned.append(enemy)
