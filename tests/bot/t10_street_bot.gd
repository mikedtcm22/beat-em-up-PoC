extends Node
## Milestone 7, T10: stills of Mission 1's street under a look profile, for the night-street look's review. A look-dev bot, not a test:
## it builds the level with the waves off and the AI frozen, stands the player at a few stations along the street with a few
## enemies in view, and quits. Record it with tools/capture_bot.sh and cut stills with ffmpeg (one every STATION_FRAMES):
##   CAPTURE_ARGS="--profile=trailer" tools/capture_bot.sh res://tests/bot/t10_street_bot.tscn captures/m7-slice/t10/trailer
## `--profile=m6|trailer` picks the look (default trailer).

const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
## Frames a station holds (the still is cut near its end, once the enemies have settled).
const STATION_FRAMES := 60
## Stations: the player's spot (section space of the street, which starts at the origin), yaw (degrees; 0 looks down -z), pitch
## (degrees up), and the enemies in view, {id, at, yaw}.
const STATIONS: Array[Dictionary] = [
	{at = Vector3(1.0, 0.0, 0.5), yaw = 0.0, pitch = 4.0, enemies = [
		{id = &"punk", at = Vector3(-0.5, 0.0, -4.0), yaw = 180.0}, {id = &"kicker", at = Vector3(2.8, 0.0, -6.5), yaw = 180.0},
		{id = &"thug", at = Vector3(-2.6, 0.0, -9.0), yaw = 180.0}]},
	{at = Vector3(0.0, 0.0, -12.0), yaw = 0.0, pitch = 3.0, enemies = [
		{id = &"punk", at = Vector3(1.4, 0.0, -15.0), yaw = 180.0}, {id = &"punk_veteran", at = Vector3(-1.8, 0.0, -17.0), yaw = 180.0},
		{id = &"bruiser", at = Vector3(0.5, 0.0, -21.0), yaw = 180.0}]},
	{at = Vector3(-2.0, 0.0, -25.0), yaw = 12.0, pitch = 2.0, enemies = [
		{id = &"punk", at = Vector3(-1.0, 0.0, -28.5), yaw = 180.0}, {id = &"kicker", at = Vector3(2.5, 0.0, -30.0), yaw = 180.0}]},
	{at = Vector3(0.5, 0.0, -34.0), yaw = -20.0, pitch = 12.0, enemies = [
		{id = &"thug", at = Vector3(0.0, 0.0, -37.5), yaw = 180.0}]},
]

var _level: LevelRoot
var _frame: int = 0
var _spawned: Array[Node] = []


func _ready() -> void:
	var profile := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			profile = 0 if arg.ends_with("m6") else 1
	Tuning.set_value(&"waves_enabled", false)
	Tuning.set_value(&"god_mode", true)
	Tuning.set_value(&"ai_frozen", true)
	Tuning.set_value(&"look_profile", profile)
	_level = (load(LEVEL_PATH) as PackedScene).instantiate() as LevelRoot
	_level.waves_enabled_on_start = false
	add_child(_level)
	# The stills are the street's light: no HUD, no help panel (add --hud to keep them).
	if not OS.get_cmdline_user_args().has("--hud"):
		for layer: Node in _level.find_children("*", "CanvasLayer", true, false):
			(layer as CanvasLayer).visible = false


func _physics_process(_delta: float) -> void:
	if _level == null or _level.player == null:
		return
	var station := _frame / STATION_FRAMES
	if station >= STATIONS.size():
		print("T10-BOT done profile=%s" % LookProfile.profile_name())
		get_tree().quit()
		return
	if _frame == 0:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--hide="):
				for node: Node in _level.find_children(arg.trim_prefix("--hide=") + "*", "Node3D", true, false):
					(node as Node3D).visible = false
	if _frame % STATION_FRAMES == 0:
		_go(STATIONS[station])
	_frame += 1


func _go(station: Dictionary) -> void:
	for node in _spawned:
		if is_instance_valid(node):
			EncounterSpawner.remove_enemy(node)
	_spawned.clear()
	var street := _level.sections[0]
	var player := _level.player
	player.reset_state()
	player.global_position = street.to_global(station.at)
	player.velocity = Vector3.ZERO
	var yaw := deg_to_rad(float(station.yaw))
	player.rotation.y = yaw
	player.look_yaw = yaw
	player.look_pitch = deg_to_rad(float(station.pitch))
	for entry: Dictionary in station.enemies:
		var enemy := _level.spawner.spawn_enemy(entry.id, street.to_global(entry.at), deg_to_rad(float(entry.yaw)))
		if enemy != null:
			_spawned.append(enemy)
	var sun := _level.get_node("Sun") as DirectionalLight3D
	print("T10-BOT station f%d profile=%s sun=%s x%.2f shadow=%s rot=%s" % [_frame, LookProfile.profile_name(), sun.light_color,
			sun.light_energy, sun.shadow_enabled, sun.rotation_degrees])
