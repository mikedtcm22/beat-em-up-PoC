extends Node
## Milestone 7 (e-bossroof): fight-distance and set stills of the boss roof under the trailer look (a look-dev stage, not a test).
## The level with the waves off, the player at one spot per station on the boss roof and Ox (`boss`) in front, the AI frozen except in
## the fight stations. Record it with Movie Maker and cut a still near the end of each station (STATION_FRAMES):
##   godot --path . --write-movie out.avi --fixed-fps 60 --resolution 1600x900 --quit-after 600 res://tests/fixtures/m7/bossroof_stage.tscn
## `--profile=m6` shows the same shots under the m6 look. `--perf` is the frame-time run (windowed, no recording, the AI frozen throughout):
## it times every frame from the 30th of each station on and prints one `BOSSROOF-PERF` line (mean and p95 frame ms), for an m6 against trailer comparison.
const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const STATION_FRAMES := 100
## The boss roof is section 2. Stations, in that section's space: {name, at (the feet), yaw (degrees; 0 looks along -Z, -90 along +X),
## pitch, ai (the AI runs), ox: {at, yaw} or empty}.
const STATIONS: Array[Dictionary] = [
	{name = "entrance", at = Vector3(0.0, 0.0, -6.0), yaw = 0.0, pitch = 3.0, ai = false, ox = {at = Vector3(0.0, 0.0, -16.2), yaw = 180.0}},
	{name = "fight", at = Vector3(-1.0, 0.0, -9.0), yaw = 0.0, pitch = 4.0, ai = true, ox = {at = Vector3(-1.0, 0.0, -11.6), yaw = 180.0}},
	{name = "edge", at = Vector3(4.0, 0.0, -6.0), yaw = -90.0, pitch = 8.0, ai = false, ox = {}},
	{name = "back", at = Vector3(0.0, 0.0, -4.0), yaw = 0.0, pitch = 10.0, ai = false, ox = {at = Vector3(1.4, 0.0, -9.0), yaw = 200.0}},
	{name = "fight_edge", at = Vector3(1.0, 0.0, -8.0), yaw = -90.0, pitch = 7.0, ai = true, ox = {at = Vector3(5.2, 0.0, -8.0), yaw = 90.0}},
]

var _level: LevelRoot
var _frame: int = 0
var _spawned: Array[Node] = []
var _perf: bool = false
var _last_us: int = 0
var _times: Array[float] = []


func _ready() -> void:
	var profile := 0 if OS.get_cmdline_user_args().has("--profile=m6") else 1
	_perf = OS.get_cmdline_user_args().has("--perf")
	Tuning.set_value(&"waves_enabled", false)
	Tuning.set_value(&"god_mode", true)
	Tuning.set_value(&"ai_frozen", true)
	Tuning.set_value(&"look_profile", profile)
	Tuning.set_value(&"cutins_enabled", false)
	Tuning.set_value(&"section_light_blend_s", 0.0)
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
		if _perf and not _times.is_empty():
			_times.sort()
			var sum := 0.0
			for t in _times:
				sum += t
			print("BOSSROOF-PERF profile=%d n=%d mean_ms=%.3f p95_ms=%.3f" % [profile_id(), _times.size(), sum / _times.size(), _times[int(_times.size() * 0.95)]])
		print("BOSSROOF-STAGE done")
		get_tree().quit()
		return
	if _perf:
		var now := Time.get_ticks_usec()
		if _frame % STATION_FRAMES >= 30 and _last_us > 0:
			_times.append(float(now - _last_us) / 1000.0)
		_last_us = now
	if _frame % STATION_FRAMES == 0:
		_go(STATIONS[station])
		print("BOSSROOF-STAGE station %d %s frame %d" % [station, STATIONS[station].name, _frame])
	_frame += 1


func profile_id() -> int:
	return Tuning.data.look_profile


func _go(station: Dictionary) -> void:
	for node in _spawned:
		if is_instance_valid(node):
			EncounterSpawner.remove_enemy(node)
	_spawned.clear()
	var roof := _level.sections[2]
	var player := _level.player
	player.reset_state()
	player.global_position = roof.to_global(station.at)
	player.velocity = Vector3.ZERO
	player.rotation.y = deg_to_rad(float(station.yaw))
	player.look_yaw = deg_to_rad(float(station.yaw))
	player.look_pitch = deg_to_rad(float(station.pitch))
	Tuning.set_value(&"ai_frozen", _perf or not bool(station.ai))
	var ox: Dictionary = station.ox
	if not ox.is_empty():
		var enemy := _level.spawner.spawn_enemy(&"boss", roof.to_global(ox.at), deg_to_rad(float(ox.yaw)))
		if enemy != null:
			_spawned.append(enemy)
