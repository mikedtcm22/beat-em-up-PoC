extends RefCounted
## The level-run bot's seam look (FIX2): the player is put at a row of spots round the two seams of
## Mission 1, looking at them, each with the barrier closed and open, and held a second each, so the
## doubled or missing walls can be seen from both sides (the run only ever looks ahead).
##   "Look: seams"  logs `SEAM <n> <label> f<frame>`, the frame to cut the still at (60 frames a
##                  second of video); needs the whole level (`--level=res://game/level/mission1/mission1.tscn`).

## Seconds each pose is held.
const HOLD_S := 1.0

## {label, arena (whose ahead barrier it is), closed, at (level space), yaw_deg (0 looks along -Z,
## 180 back along +Z), pitch_deg}.
const POSES: Array[Dictionary] = [
	{label = "street_landing_closed", arena = 2, closed = true, at = Vector3(3.0, 4.5, -47.5), yaw = 0.0, pitch = -4.0},
	{label = "street_landing_open", arena = 2, closed = false, at = Vector3(3.0, 4.5, -47.5), yaw = 0.0, pitch = -4.0},
	{label = "street_shutter_closed_near", arena = 2, closed = true, at = Vector3(3.0, 4.5, -51.4), yaw = 0.0, pitch = 0.0},
	{label = "street_shutter_open_near", arena = 2, closed = false, at = Vector3(3.0, 4.5, -51.4), yaw = 0.0, pitch = 0.0},
	{label = "terrace_back_closed", arena = 2, closed = true, at = Vector3(1.0, 4.5, -57.0), yaw = 180.0, pitch = 0.0},
	{label = "terrace_back_open", arena = 2, closed = false, at = Vector3(1.0, 4.5, -57.0), yaw = 180.0, pitch = 0.0},
	{label = "terrace_back_right_open", arena = 2, closed = false, at = Vector3(1.0, 4.5, -56.0), yaw = 125.0, pitch = 0.0},
	{label = "terrace_ahead_open", arena = 2, closed = false, at = Vector3(1.0, 4.5, -55.0), yaw = 0.0, pitch = 0.0},
	{label = "a6_gate_closed", arena = 5, closed = true, at = Vector3(22.0, 12.0, -78.0), yaw = 0.0, pitch = 0.0},
	{label = "a6_gate_open", arena = 5, closed = false, at = Vector3(22.0, 12.0, -78.0), yaw = 0.0, pitch = 0.0},
	{label = "a6_gate_closed_near", arena = 5, closed = true, at = Vector3(22.0, 12.0, -80.8), yaw = 0.0, pitch = 0.0},
	{label = "a6_gate_left_closed", arena = 5, closed = true, at = Vector3(17.5, 12.0, -80.0), yaw = 20.0, pitch = 0.0},
	{label = "a6_gate_right_closed", arena = 5, closed = true, at = Vector3(26.5, 12.0, -80.0), yaw = -20.0, pitch = 0.0},
	{label = "a7_back_closed", arena = 5, closed = true, at = Vector3(22.0, 12.0, -87.0), yaw = 180.0, pitch = 0.0},
	{label = "a7_back_open", arena = 5, closed = false, at = Vector3(22.0, 12.0, -87.0), yaw = 180.0, pitch = 0.0},
	{label = "a7_back_left_closed", arena = 5, closed = true, at = Vector3(14.0, 12.0, -85.5), yaw = 180.0, pitch = 0.0},
	{label = "a7_back_right_closed", arena = 5, closed = true, at = Vector3(30.0, 12.0, -85.5), yaw = 180.0, pitch = 0.0},
]


static func acts(bot: Node) -> Array[Dictionary]:
	return [{title = "Look: seams", cam = &"first_person", fn = func() -> void: await _seams(bot)}]


static func _seams(bot: Node) -> void:
	var arenas: Array[Arena] = bot.level.arenas()
	if arenas.size() < 6:
		bot.log_line("NOTE the seam look needs the whole level")
		return
	bot.freeze_ai(true)
	var player: PlayerCharacter = bot.player
	for n in POSES.size():
		var pose: Dictionary = POSES[n]
		var barrier: Barrier = arenas[int(pose.arena)].ahead
		barrier.snap(bool(pose.closed))
		var yaw := deg_to_rad(float(pose.yaw))
		player.global_position = pose.at
		player.velocity = Vector3.ZERO
		player.rotation.y = yaw
		player.look_yaw = yaw
		player.look_pitch = deg_to_rad(float(pose.pitch))
		await bot._ticks(4)
		bot.log_line("SEAM %d %s f%d" % [n, pose.label, Engine.get_physics_frames()])
		await bot._ticks(int(HOLD_S * Engine.physics_ticks_per_second))
