extends RefCounted
## The trailer kit's stretch (M7 T15): the street from its start to the first chain-link fence, in first person, one pose at a
## time, so stills can be cut and judged against the trailer's frames (t_02, t_05, t_06) and against M6's.
##   "Look: T15 street stretch"  logs `T15 <label> f<frame>`, the video frame to cut (60 a second). Needs the whole level
##   (`--level=res://game/level/mission1/mission1.tscn`); record it twice, `--tune=look_profile=1` (trailer) and without (M6):
##   CAPTURE_ARGS="--level=res://game/level/mission1/mission1.tscn --tune=look_profile=1" tools/capture_bot.sh res://tests/bot/level_bot.tscn captures/m7-slice/t15/trailer "T15" 2

const TourActs := preload("res://tests/bot/level_acts/tour_acts.gd")
## Seconds each pose is held.
const HOLD_S := 0.6
## {label, at (the street's space, the feet), yaw (degrees; 0 looks along -Z, -90 along +X, 90 along -X), pitch (degrees)}.
const POSES: Array[Dictionary] = [
	{label = "start", at = Vector3(3.0, 0.0, 0.8), yaw = 0.0, pitch = -4.0},
	{label = "right_wall", at = Vector3(-2.0, 0.0, -2.0), yaw = -90.0, pitch = 8.0},
	{label = "left_wall", at = Vector3(3.5, 0.0, -5.0), yaw = 90.0, pitch = 6.0},
	{label = "fence", at = Vector3(1.5, 0.0, -8.0), yaw = 0.0, pitch = -2.0},
	{label = "ground", at = Vector3(3.0, 0.0, -2.0), yaw = 0.0, pitch = -38.0},
	{label = "up", at = Vector3(3.0, 0.0, -5.0), yaw = 0.0, pitch = 32.0},
]


static func acts(bot: Node) -> Array[Dictionary]:
	return [{title = "Look: T15 street stretch", cam = &"first_person", fn = func() -> void: await _stretch(bot)}]


static func _stretch(bot: Node) -> void:
	if bot.level.sections.is_empty():
		bot.log_line("NOTE the T15 stretch needs the level")
		return
	bot.freeze_ai(true)
	var player: PlayerCharacter = bot.player
	var section: Node3D = bot.level.sections[0]
	for pose: Dictionary in POSES:
		var yaw := deg_to_rad(float(pose.yaw))
		player.global_position = section.global_position + pose.at
		player.velocity = Vector3.ZERO
		player.rotation.y = yaw
		player.look_yaw = yaw
		player.look_pitch = deg_to_rad(float(pose.pitch))
		await TourActs.settle_light(bot, section, player.global_position)
		bot.log_line("T15 %s f%d" % [pose.label, Engine.get_physics_frames()])
		await bot._ticks(int(HOLD_S * Engine.physics_ticks_per_second))
