extends RefCounted
## The arena tour (M6 DRESS): the player is put at a row of spots through the street, the roofs and the boss
## roof, each held a moment, so a still can be cut at each pose and the dressing judged in first person
## against `captures/m5-final` (the same level, no art).
##   "Look: arena tour"  logs `TOUR <n> <section> <label> f<frame>`, the frame to cut the still at (60 frames
##                       a second of video). Needs the whole level (`--level=res://game/level/mission1/
##                       mission1.tscn`).
## What to look for: the section light (the street's dusk, the roofs' copper, the boss roof's dark drop), the
## doorways still dark openings, the skyline with depth, no pale plane under the boss roof's gap, no dashed
## coplanar line.

## Seconds each pose is held (long enough for the section light's blend to arrive after a jump).
const HOLD_S := 0.8

## {label, section (index in the level), at (that section's space, the feet), yaw (degrees; 0 looks along -Z,
## -90 along +X, 90 along -X), pitch (degrees)}.
const POSES: Array[Dictionary] = [
	{label = "street_start", section = 0, at = Vector3(3.0, 0.0, 0.8), yaw = 0.0, pitch = -4.0},
	{label = "street_a2_doors", section = 0, at = Vector3(-3.5, 0.0, -20.0), yaw = -90.0, pitch = 4.0},
	{label = "street_a2_van_fence", section = 0, at = Vector3(1.0, 0.0, -22.0), yaw = 90.0, pitch = 0.0},
	{label = "street_warehouse", section = 0, at = Vector3(2.5, 0.0, -36.0), yaw = 90.0, pitch = 2.0},
	{label = "street_a3_stairs", section = 0, at = Vector3(3.0, 0.0, -37.0), yaw = 0.0, pitch = 6.0},
	{label = "street_skyline_up", section = 0, at = Vector3(3.0, 0.0, -30.0), yaw = 0.0, pitch = 24.0},
	{label = "roofs_terrace_start", section = 1, at = Vector3(-3.0, 0.0, -1.0), yaw = 0.0, pitch = -3.0},
	{label = "roofs_terrace_doors", section = 1, at = Vector3(-4.0, 0.0, -6.0), yaw = -90.0, pitch = 2.0},
	{label = "roofs_terrace_second", section = 1, at = Vector3(-3.0, 1.0, -16.0), yaw = 0.0, pitch = 0.0},
	{label = "roofs_terrace_drop", section = 1, at = Vector3(-6.0, 1.0, -19.0), yaw = 90.0, pitch = -20.0},
	{label = "roofs_catwalk", section = 1, at = Vector3(6.0, 4.5, -10.5), yaw = 0.0, pitch = -4.0},
	{label = "roofs_catwalk_drop", section = 1, at = Vector3(3.5, 4.5, -17.0), yaw = 90.0, pitch = -30.0},
	{label = "roofs_top_roof", section = 1, at = Vector3(19.0, 7.5, -8.5), yaw = 0.0, pitch = -3.0},
	{label = "roofs_tanks", section = 1, at = Vector3(19.0, 7.5, -16.0), yaw = 90.0, pitch = 2.0},
	{label = "roofs_skyline", section = 1, at = Vector3(22.0, 7.5, -14.0), yaw = -90.0, pitch = 6.0},
	{label = "boss_start", section = 2, at = Vector3(0.0, 0.0, -2.0), yaw = 0.0, pitch = -3.0},
	{label = "boss_cars_gap", section = 2, at = Vector3(5.0, 0.0, -10.5), yaw = -90.0, pitch = -10.0},
	{label = "boss_gap_down", section = 2, at = Vector3(8.5, 0.0, -10.5), yaw = -90.0, pitch = -38.0},
	{label = "boss_skyline", section = 2, at = Vector3(6.0, 0.0, -4.0), yaw = -90.0, pitch = 8.0},
	{label = "boss_from_back", section = 2, at = Vector3(0.0, 0.0, -17.0), yaw = 180.0, pitch = -3.0},
]


static func acts(bot: Node) -> Array[Dictionary]:
	return [{title = "Look: arena tour", cam = &"first_person", fn = func() -> void: await _tour(bot)}]


static func _tour(bot: Node) -> void:
	if bot.level.sections.size() < 3:
		bot.log_line("NOTE the arena tour needs the whole level")
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
		await settle_light(bot, section, player.global_position)
		bot.log_line("TOUR %d %d %s f%d" % [n, pose.section, pose.label, Engine.get_physics_frames()])
		await bot._ticks(int(HOLD_S * Engine.physics_ticks_per_second))


## After a teleport into `section`: let the level notice it, then wait out the section light's blend (the level's
## `section_light_progress()` reaching 1), so no still is cut mid-blend (final review, world-05). The player is
## held at `at` and kept still for the wait: a pose in the air (a catwalk's lip) would otherwise fall off its
## spot while the light blends. The wait is bounded by the blend's length plus half a second, so a level that
## never arrives still moves on.
static func settle_light(bot: Node, section: Node3D, at: Vector3) -> void:
	var player: PlayerCharacter = bot.player
	var limit := int((Tuning.data.section_light_blend_s + 0.5) * Engine.physics_ticks_per_second)
	for _tick in 4:
		await bot._ticks(1)
		player.global_position = at
		player.velocity = Vector3.ZERO
	while limit > 0 and (bot.level.current_section() != section or bot.level.section_light_progress() < 1.0):
		await bot._ticks(1)
		player.global_position = at
		player.velocity = Vector3.ZERO
		limit -= 1
