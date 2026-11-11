extends RefCounted
## The two code-built rooms in the kit (M6 DRESS), for the crowd bot (tests/bot/crowd_bot.gd): the player is put at a
## row of spots in the crowd street, then in a training room built beside it (the room's own presentation off, its player
## freed), each held a moment, so a still can be cut at each pose.
##   "Look: rooms tour"  logs `TOUR <n> <label> f<frame>`, the frame to cut the still at (60 frames a second of video).
## Record with tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/rooms "Look: rooms tour" 0

const TRAINING_ROOM := preload("res://game/level/test_room.tscn")
const HOLD_S := 0.8
## Where the training room is built (m along +X), far enough from the crowd street to share nothing.
const TRAINING_OFFSET := Vector3(400.0, 0.0, 0.0)

## {label, at (the room's space), yaw (degrees; 0 looks along -Z, -90 along +X, 90 along -X, 180 along +Z), pitch (degrees), room (0 crowd, 1 training)}.
const POSES: Array[Dictionary] = [
	{label = "crowd_north_fronts", room = 0, at = Vector3(0.0, 0.0, 3.0), yaw = 0.0, pitch = 5.0},
	{label = "crowd_doorway", room = 0, at = Vector3(-9.0, 0.0, -2.0), yaw = 0.0, pitch = 0.0},
	{label = "crowd_lane_east", room = 0, at = Vector3(-13.0, 0.0, 0.0), yaw = -90.0, pitch = 0.0},
	{label = "crowd_car", room = 0, at = Vector3(-10.5, 0.0, 3.5), yaw = -90.0, pitch = -2.0},
	{label = "crowd_dumpster", room = 0, at = Vector3(9.0, 0.0, 0.0), yaw = -20.0, pitch = -2.0},
	{label = "crowd_south_skyline", room = 0, at = Vector3(0.0, 0.0, -3.0), yaw = 180.0, pitch = 6.0},
	{label = "training_far_fronts", room = 1, at = Vector3(0.0, 0.0, 0.0), yaw = 0.0, pitch = 3.0},
	{label = "training_down_street", room = 1, at = Vector3(-15.0, 0.0, 0.0), yaw = -90.0, pitch = 0.0},
	{label = "training_crates", room = 1, at = Vector3(-4.0, 0.0, 0.0), yaw = 34.0, pitch = -2.0},
	{label = "training_curb", room = 1, at = Vector3(0.0, 0.0, 0.0), yaw = 180.0, pitch = 0.0},
]


static func acts(bot: Node) -> Array[Dictionary]:
	return [{title = "Look: rooms tour", cam = &"first_person", slug = &"r1", fn = func() -> void: await _tour(bot)}]


static func _tour(bot: Node) -> void:
	bot.caption.visible = false
	bot.god()
	bot.freeze_ai(true)
	var training := TRAINING_ROOM.instantiate() as Node3D
	training.set(&"with_presentation", false)
	training.position = TRAINING_OFFSET
	bot.room.add_child(training)
	await bot._ticks(4)
	var spare: Node = training.get(&"player")
	if spare != null:
		spare.queue_free()
	var player: PlayerCharacter = bot.player
	for n in POSES.size():
		var pose: Dictionary = POSES[n]
		var yaw := deg_to_rad(float(pose.yaw))
		player.global_position = pose.at + (TRAINING_OFFSET if int(pose.room) == 1 else Vector3.ZERO)
		player.velocity = Vector3.ZERO
		player.rotation.y = yaw
		player.look_yaw = yaw
		player.look_pitch = deg_to_rad(float(pose.pitch))
		await bot._ticks(4)
		bot.log_line("TOUR %d %s f%d" % [n, pose.label, Engine.get_physics_frames()])
		await bot._ticks(int(HOLD_S * Engine.physics_ticks_per_second))
	training.queue_free()
	bot.caption.visible = true
