extends RefCounted
## The street walk (M7 e-street): the player is put at a row of spots along the whole Mission 1 street, each held a
## moment, so a still can be cut at each pose and the roll-out of the trailer look judged in first person.
##   "Look: street walk"  logs `ESTREET <n> <label> f<frame>`, the frame to cut the still at. Needs the whole level.

const HOLD_S := 0.5

## {label, at (level space, the feet), yaw (degrees; 0 looks along -Z, -90 along +X, 90 along -X), pitch (degrees)}.
const POSES: Array[Dictionary] = [
	{label = "start", at = Vector3(3.0, 0.0, 0.8), yaw = 0.0, pitch = -4.0},
	{label = "left_wall", at = Vector3(2.0, 0.0, -4.0), yaw = 90.0, pitch = 10.0},
	{label = "right_wall", at = Vector3(-2.0, 0.0, -5.0), yaw = -90.0, pitch = 10.0},
	{label = "dumpster", at = Vector3(2.5, 0.0, -5.0), yaw = -90.0, pitch = -3.0},
	{label = "skyline_up", at = Vector3(3.0, 0.0, -6.0), yaw = 0.0, pitch = 28.0},
	{label = "doorway", at = Vector3(0.5, 0.0, -10.75), yaw = -90.0, pitch = 0.0},
	{label = "crates", at = Vector3(-2.4, 0.0, -11.0), yaw = 53.0, pitch = -2.0},
	{label = "gate", at = Vector3(3.0, 0.0, -10.5), yaw = 0.0, pitch = -2.0},
	{label = "lamp_c", at = Vector3(3.0, 0.0, -17.0), yaw = 0.0, pitch = 10.0},
	{label = "a2_doors", at = Vector3(-3.5, 0.0, -20.0), yaw = -90.0, pitch = 4.0},
	{label = "a2_van_fence", at = Vector3(1.0, 0.0, -22.0), yaw = 90.0, pitch = 0.0},
	{label = "yard", at = Vector3(3.0, 0.0, -26.0), yaw = 0.0, pitch = -2.0},
	{label = "warehouse", at = Vector3(2.5, 0.0, -36.0), yaw = 90.0, pitch = 2.0},
	{label = "stairs", at = Vector3(4.5, 0.0, -36.5), yaw = 0.0, pitch = -8.0},
	{label = "a3_back", at = Vector3(3.0, 0.0, -45.0), yaw = 180.0, pitch = 4.0},
	{label = "towers_up", at = Vector3(3.0, 0.0, -20.0), yaw = 0.0, pitch = 24.0},
]


static func acts(bot: Node) -> Array[Dictionary]:
	return [{title = "Look: street walk", cam = &"first_person", fn = func() -> void: await _walk(bot)}]


static func _walk(bot: Node) -> void:
	var section: LevelSection = bot.level.sections[0]
	for barrier_name: String in ["StartCar", "Gate", "YardCar"]:
		var barrier := section.get_node_or_null("Barriers/" + barrier_name) as Barrier
		if barrier != null:
			barrier.snap(barrier_name == "Gate" or barrier_name == "YardCar")
	bot.freeze_ai(true)
	var player: PlayerCharacter = bot.player
	for n in POSES.size():
		var pose: Dictionary = POSES[n]
		var yaw := deg_to_rad(float(pose.yaw))
		player.global_position = pose.at
		player.velocity = Vector3.ZERO
		player.rotation.y = yaw
		player.look_yaw = yaw
		player.look_pitch = deg_to_rad(float(pose.pitch))
		await bot._ticks(4)
		for _tick in 6:
			player.global_position = pose.at
			player.velocity = Vector3.ZERO
			await bot._ticks(1)
		bot.log_line("ESTREET %d %s f%d" % [n, pose.label, Engine.get_physics_frames()])
		await bot._ticks(int(HOLD_S * Engine.physics_ticks_per_second))
		# ESTREET_SHOTS=<dir>: a lossless still of the pose (the movie's own frames are lossy)
		var dir := OS.get_environment("ESTREET_SHOTS")
		if dir != "":
			bot.get_viewport().get_texture().get_image().save_png("%s/s_%02d_%s.png" % [dir, n, pose.label])
