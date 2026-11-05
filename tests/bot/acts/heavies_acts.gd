extends RefCounted
## The heavies' look act (Milestone 6, HEAVIES): the Bruiser and Ox Pellerin beside a Street Punk, level view, at 2.5, 5 and 10 m, so the
## height read (a 2.05 m and a 2.3 m rig against the 1.8 m Punk) and the silhouettes are judged together. Record with
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/<key> "Look: heavies beside a Punk" 6
## The marks are LOOK-MARK h1 f<frame> d2_5_m ... and end; the stills are the second before each mark.

const LookActs := preload("res://tests/bot/acts/look_acts.gd")
const LookRect := preload("res://tests/bot/look_rect.gd")
## The distances (m) and how long each is held, in physics ticks.
const DISTANCES_M: Array[float] = [2.5, 5.0, 10.0]
const HOLD_TICKS := 90
## The three on an arc: id and bearing from the look in degrees (positive to the left).
const ARC: Array[Dictionary] = [
	{id = &"punk", bearing_deg = 7.0},
	{id = &"bruiser", bearing_deg = 0.0},
	{id = &"boss", bearing_deg = -7.0},
]


static func acts(bot: Node) -> Array[Dictionary]:
	return [{title = "Look: heavies beside a Punk", cam = &"first_person", slug = &"h1", fn = func() -> void: await _beside(bot)}]


static func _beside(bot: Node) -> void:
	LookActs._begin(bot)
	await bot._look_to(LookActs.LEVEL_PITCH_DEG, LookActs.PITCH_TICKS)
	LookRect.mark(bot, "h1", "start")
	for distance: float in DISTANCES_M:
		bot.clear_enemies()
		var subjects: Array[EnemyActor] = []
		for entry: Dictionary in ARC:
			var bearing := deg_to_rad(float(entry.bearing_deg) * 2.5 / distance * 2.0)
			subjects.append(bot.spawn(entry.id, Vector2(-sin(bearing), cos(bearing)) * distance))
		await bot._ticks(HOLD_TICKS)
		LookRect.mark(bot, "h1", "d%s_m" % str(distance).replace(".", "_"), subjects[1])
	LookActs._end(bot, "h1")
