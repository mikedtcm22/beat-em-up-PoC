extends RefCounted
## The level-run bot's drop look (M5 fix wave): the player is put at a few spots on the boss roof's
## open edge, and on the catwalk's for comparison, looking out and down at the drop, each held a
## second, so the read of "a 12 m fall" can be judged in first person (side view and free fly do not
## count).
##   "Look: drops"  logs `DROP <n> <label> f<frame>`, the frame to cut the still at; needs the whole
##                  level (`--level=res://game/level/mission1/mission1.tscn`).

const TourActs := preload("res://tests/bot/level_acts/tour_acts.gd")

## Seconds each pose is held.
const HOLD_S := 1.0

## {label, section (index in the level), at (that section's space), yaw_deg (0 looks along -Z, -90
## along +X, 90 along -X), pitch_deg}. The boss roof (section 2) has its open edge on +X, its rail
## gap at z -8..-13; the roofs (section 1) pose is the catwalk's drop.
const POSES: Array[Dictionary] = [
	{label = "boss_gap_level", section = 2, at = Vector3(6.0, 0.0, -10.5), yaw = -90.0, pitch = -12.0},
	{label = "boss_gap_wide", section = 2, at = Vector3(0.0, 0.0, -10.5), yaw = -90.0, pitch = -6.0},
	{label = "boss_gap_lip_down", section = 2, at = Vector3(8.5, 0.0, -10.5), yaw = -90.0, pitch = -40.0},
	{label = "boss_rail_down", section = 2, at = Vector3(8.5, 0.0, -4.0), yaw = -90.0, pitch = -40.0},
	{label = "boss_from_door", section = 2, at = Vector3(-2.0, 0.0, -16.0), yaw = -60.0, pitch = -8.0},
	{label = "catwalk_lip_down", section = 1, at = Vector3(-14.5, 4.5, -31.0), yaw = 90.0, pitch = -40.0},
]


static func acts(bot: Node) -> Array[Dictionary]:
	return [{title = "Look: drops", cam = &"first_person", fn = func() -> void: await _drops(bot)}]


static func _drops(bot: Node) -> void:
	if bot.level.sections.size() < 3:
		bot.log_line("NOTE the drop look needs the whole level")
		return
	bot.freeze_ai(true)
	var player: PlayerCharacter = bot.player
	for n in POSES.size():
		var pose: Dictionary = POSES[n]
		var section: Node3D = bot.level.sections[int(pose.section)]
		var yaw := deg_to_rad(float(pose.yaw))
		player.global_position = section.global_position + pose.at
		player.velocity = Vector3.ZERO
		player.rotation.y = yaw
		player.look_yaw = yaw
		player.look_pitch = deg_to_rad(float(pose.pitch))
		await TourActs.settle_light(bot, section)
		bot.log_line("DROP %d %s f%d" % [n, pose.label, Engine.get_physics_frames()])
		await bot._ticks(int(HOLD_S * Engine.physics_ticks_per_second))

