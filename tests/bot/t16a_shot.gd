extends Node
## M7 T16a probe: windowed. Loads Mission 1, puts the player at fixed poses in the street's first stretch under a profile, saves stills
## and measures the mean frame time over a fixed window with the street effects on, off (StreetFx hidden) and under m6.
## godot --path . res://tests/bot/t16a_shot.tscn -- --out=captures/m7-slice/t16a [--frames=240]

const POSES: Array[Vector3] = [Vector3(-2.0, 0.0, -3.0), Vector3(2.0, 0.0, -6.0)]
var _out: String = "captures/m7-slice/t16a"
var _frames: int = 240


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--frames="):
			_frames = int(arg.substr(9))
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _mean_ms(room: LevelRoot) -> Vector2:
	await _wait(30)
	var times: Array[float] = []
	for i in _frames:
		var t0 := Time.get_ticks_usec()
		await get_tree().process_frame
		times.append(float(Time.get_ticks_usec() - t0) / 1000.0)
	times.sort()
	return Vector2(times[times.size() / 2], times[int(times.size() * 0.95)])


func _pose(room: LevelRoot, p: Vector3) -> void:
	room.player.global_position = p
	room.player.velocity = Vector3.ZERO
	room.player.rotation.y = room.player_yaw_deg * PI / 180.0
	room.player.look_yaw = room.player.rotation.y


func _run() -> void:
	Tuning.set_value(&"waves_enabled", false)
	var room := (load("res://game/level/mission1/mission1.tscn") as PackedScene).instantiate() as LevelRoot
	room.waves_enabled_on_start = false
	get_tree().root.add_child(room)
	await _wait(10)
	for node: Node in get_tree().root.find_children("*", "Control", true, false):
		if node is HelpOverlay or node is CombatLogOverlay:
			(node as Control).visible = false
	var vp := get_tree().root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var fx := get_tree().root.find_child("StreetFx", true, false) as StreetFx
	Tuning.set_value(&"look_profile", 1)
	await _wait(5)
	print("T16A built=", fx.is_built(), " counts=", fx.counts())
	for i in POSES.size():
		_pose(room, POSES[i])
		await _wait(40)
		get_tree().root.get_texture().get_image().save_png("%s/trailer_%d.png" % [_out, i])
		await _wait(7)
		get_tree().root.get_texture().get_image().save_png("%s/trailer_%d_b.png" % [_out, i])
	Tuning.set_value(&"look_profile", 0)
	await _wait(5)
	print("T16A m6 built=", fx.is_built(), " children=", fx.get_child_count())
	_pose(room, POSES[0])
	await _wait(40)
	get_tree().root.get_texture().get_image().save_png("%s/m6_0.png" % _out)
	var m6 := await _mean_ms(room)
	print("T16A pose 0 (median ms, p95 ms) m6 ", m6)
	for i in POSES.size():
		_pose(room, POSES[i])
		Tuning.set_value(&"look_profile", 1)
		await _wait(5)
		fx.visible = true
		var on := Vector2.ZERO
		var off := Vector2.ZERO
		for round in 3:
			fx.visible = true
			on += await _mean_ms(room) / 3.0
			fx.visible = false
			off += await _mean_ms(room) / 3.0
		fx.visible = true
		print("T16A pose %d (median ms, p95 ms) trailer fx on %s, off %s" % [i, on, off])
	get_tree().quit()
