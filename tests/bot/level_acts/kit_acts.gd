extends RefCounted
## The environment kit's look (M6 KIT): the player is put at a row of spots in the street (A1, and the
## stair, A3's) looking at what the kit draws, each held a moment, so a still can be cut at each pose.
##   "Look: kit strip"  logs `KIT <n> <label> f<frame>`, the frame to cut the still at (60 frames a
##                      second of video). Needs the whole level (`--level=res://game/level/mission1/
##                      mission1.tscn`, whose first section, the street, is built at the origin).
## The doorways are still dark openings, no coplanar line dashes, no doubled ink: the things to look
## for against `captures/m5-final/street`.

## Seconds each pose is held.
const HOLD_S := 0.8

## {label, at (level space, the feet), yaw (degrees; 0 looks along -Z, -90 along +X, 90 along -X),
## pitch (degrees), car / gate (a barrier of the street snapped closed or open first)}.
const POSES: Array[Dictionary] = [
	{label = "start_down_street", at = Vector3(3.0, 0.0, 0.8), yaw = 0.0, pitch = -4.0},
	{label = "start_car_open", at = Vector3(3.0, 0.0, 3.0), yaw = 0.0, pitch = -3.0, car = false},
	{label = "start_car_closed", at = Vector3(3.0, 0.0, 3.0), yaw = 0.0, pitch = -3.0, car = true},
	{label = "mid_street", at = Vector3(3.0, 0.0, -4.0), yaw = 0.0, pitch = -4.0},
	{label = "doorway_far", at = Vector3(0.5, 0.0, -10.75), yaw = -90.0, pitch = 0.0},
	{label = "doorway_near", at = Vector3(3.8, 0.0, -10.75), yaw = -90.0, pitch = 2.0},
	{label = "left_wall_windows", at = Vector3(2.0, 0.0, -4.0), yaw = 90.0, pitch = 10.0},
	{label = "right_wall_windows", at = Vector3(-2.0, 0.0, -5.0), yaw = -90.0, pitch = 10.0},
	{label = "crates_dumpster", at = Vector3(-2.4, 0.0, -11.0), yaw = 53.0, pitch = -2.0},
	{label = "gate_closed", at = Vector3(3.0, 0.0, -10.5), yaw = 0.0, pitch = -2.0, gate = true},
	{label = "gate_open", at = Vector3(3.0, 0.0, -10.5), yaw = 0.0, pitch = -2.0, gate = false},
	{label = "skyline_up", at = Vector3(3.0, 0.0, -6.0), yaw = 0.0, pitch = 28.0},
	{label = "stair_flight", at = Vector3(4.5, 0.0, -36.5), yaw = 0.0, pitch = -8.0},
]


static func acts(bot: Node) -> Array[Dictionary]:
	return [{title = "Look: kit strip", cam = &"first_person", fn = func() -> void: await _strip(bot)}]


static func _strip(bot: Node) -> void:
	var arenas: Array[Arena] = bot.level.arenas()
	if arenas.size() < 3:
		bot.log_line("NOTE the kit strip needs the whole level")
		return
	bot.freeze_ai(true)
	var player: PlayerCharacter = bot.player
	var section: LevelSection = bot.level.sections[0]
	var cars: Barrier = section.get_node("Barriers/StartCar")
	var gate: Barrier = section.get_node("Barriers/Gate")
	for n in POSES.size():
		var pose: Dictionary = POSES[n]
		if pose.has("car"):
			cars.snap(bool(pose.car))
		if pose.has("gate"):
			gate.snap(bool(pose.gate))
		var yaw := deg_to_rad(float(pose.yaw))
		player.global_position = pose.at
		player.velocity = Vector3.ZERO
		player.rotation.y = yaw
		player.look_yaw = yaw
		player.look_pitch = deg_to_rad(float(pose.pitch))
		await bot._ticks(4)
		bot.log_line("KIT %d %s f%d" % [n, pose.label, Engine.get_physics_frames()])
		await bot._ticks(int(HOLD_S * Engine.physics_ticks_per_second))
