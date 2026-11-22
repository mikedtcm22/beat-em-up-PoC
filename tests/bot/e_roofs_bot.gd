extends Node
## Milestone 7, e-roofs: stills along Mission 1's roofs under a look profile, for the dusk look's review. A look-dev bot, not a test:
## it builds the level with the waves off and the AI frozen, stands the player at stations along the roofs' route (looking at the
## next route point) with two enemies in view, and quits. Record it with tools/capture_bot.sh:
##   CAPTURE_ARGS="--profile=trailer" tools/capture_bot.sh res://tests/bot/e_roofs_bot.tscn captures/m7-comic/e-roofs/raw
## `--profile=m6|trailer` picks the look (default trailer); `--enemies=a,b` the pair in view; `--stations=1,4,...` route indices.

const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const STATION_FRAMES := 90
## Route markers (section roofs) the six stills stand at, and the enemies' distance in front of the player (m) and sideways (m).
const DEFAULT_STATIONS: Array[int] = [1, 5, 8, 11, 14, 17]
const ENEMY_AHEAD_M := 4.5
const ENEMY_SIDE_M := 1.6

var _level: LevelRoot
var _frame: int = 0
var _spawned: Array[Node] = []
var _stations: Array[int] = DEFAULT_STATIONS.duplicate()
var _enemies: Array[StringName] = [&"thug", &"kicker"]
var _route: Array[Vector3] = []


func _ready() -> void:
	var profile := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			profile = 0 if arg.ends_with("m6") else 1
		elif arg.begins_with("--enemies="):
			_enemies.clear()
			for id in arg.trim_prefix("--enemies=").split(","):
				_enemies.append(StringName(id))
		elif arg.begins_with("--stations="):
			_stations.clear()
			for i in arg.trim_prefix("--stations=").split(","):
				_stations.append(int(i))
		elif arg.begins_with("--tune="):
			var pair := arg.trim_prefix("--tune=").split("=")
			Tuning.set_value(StringName(pair[0]), float(pair[1]))
	Tuning.set_value(&"waves_enabled", false)
	Tuning.set_value(&"god_mode", true)
	Tuning.set_value(&"ai_frozen", true)
	Tuning.set_value(&"look_profile", profile)
	_level = (load(LEVEL_PATH) as PackedScene).instantiate() as LevelRoot
	_level.waves_enabled_on_start = false
	add_child(_level)
	if not OS.get_cmdline_user_args().has("--hud"):
		for layer: Node in _level.find_children("*", "CanvasLayer", true, false):
			(layer as CanvasLayer).visible = false
	for marker: Node in _level.sections[1].get_node("Route").get_children():
		_route.append((marker as Node3D).position)


func _physics_process(_delta: float) -> void:
	if _level == null or _level.player == null:
		return
	var station := _frame / STATION_FRAMES
	if station >= _stations.size():
		print("E-ROOFS-BOT done profile=%s" % LookProfile.profile_name())
		get_tree().quit()
		return
	if _frame % STATION_FRAMES == 0:
		_go(_stations[station])
	_frame += 1


func _go(index: int) -> void:
	for node in _spawned:
		if is_instance_valid(node):
			EncounterSpawner.remove_enemy(node)
	_spawned.clear()
	var roofs := _level.sections[1]
	var here := _route[index]
	var ahead := _route[mini(index + 1, _route.size() - 1)]
	var flat := Vector2(ahead.x - here.x, ahead.z - here.z)
	if flat.length() < 0.5:
		var back := _route[maxi(index - 1, 0)]
		flat = Vector2(here.x - back.x, here.z - back.z)
	flat = flat.normalized()
	# Yaw 0 looks down -z; yaw rotates counter-clockwise seen from above.
	var yaw := atan2(-flat.x, -flat.y)
	var player := _level.player
	player.reset_state()
	player.global_position = roofs.to_global(here)
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw
	player.look_yaw = yaw
	player.look_pitch = deg_to_rad(4.0)
	var side := Vector2(-flat.y, flat.x)
	for i in _enemies.size():
		var offset := Vector2(flat.x * (ENEMY_AHEAD_M + 2.0 * i) + side.x * ENEMY_SIDE_M * (1.0 if i % 2 == 0 else -1.0),
				flat.y * (ENEMY_AHEAD_M + 2.0 * i) + side.y * ENEMY_SIDE_M * (1.0 if i % 2 == 0 else -1.0))
		var at := Vector3(here.x + offset.x, here.y, here.z + offset.y)
		var enemy := _level.spawner.spawn_enemy(_enemies[i], roofs.to_global(at), yaw + PI)
		if enemy != null:
			_spawned.append(enemy)
	print("E-ROOFS-BOT station f%d route=%d profile=%s" % [_frame, index, LookProfile.profile_name()])
