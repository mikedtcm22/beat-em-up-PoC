extends RefCounted
## The Street Punk's recipe acts (Milestone 6, ROLL-PUNK). Record one act per process:
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/<key> "Look: Punk jacket" 6
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/<key> "Look: Punk beside the veteran" 6
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/<key> "Look: Punk at 1, 2.5 and 5 m" 6
##
## | Act | Title | Shows |
## | dp1 | Look: Punk jacket | a Punk 1.6 m ahead, turned away from the player by 0, 90 and 150 degrees and held there, so the vest, the trousers' seams and the colour borders show where the guard hides them (the Bruiser's act, tests/bot/acts/detail2_acts.gd) |
## | dp2 | Look: Punk beside the veteran | a Punk and a Veteran Punk (the palette swap: a violet vest, orange trousers) side by side at 1 m and 2.5 m, level view, so the texel codes are seen to recolour with the swap |
## | dp3 | Look: Punk at 1, 2.5 and 5 m | one Punk, level view, at the three distances of the A/B sheet |
## The marks are LOOK-MARK <slug> f<frame> <label> ... and end.

const LookActs := preload("res://tests/bot/acts/look_acts.gd")
const LookRect := preload("res://tests/bot/look_rect.gd")
## How far ahead (m), the turns from facing the player (degrees) and how long each is held (physics ticks).
const DISTANCE_M := 1.6
const YAWS_DEG: Array[float] = [0.0, 90.0, 150.0]
const HOLD_TICKS := 60
## The pair's distances (m), the side-by-side spread as a share of the distance, and how long each is held.
const PAIR_DISTANCES_M: Array[float] = [1.0, 2.5]
const PAIR_SPREAD := 0.32
const PAIR_HOLD_TICKS := 90
## The A/B sheet's distances (m).
const SHEET_DISTANCES_M: Array[float] = [1.0, 2.5, 5.0]


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Look: Punk jacket", cam = &"first_person", slug = &"dp1", fn = func() -> void: await _jacket(bot)},
		{title = "Look: Punk beside the veteran", cam = &"first_person", slug = &"dp2", fn = func() -> void: await _pair(bot)},
		{title = "Look: Punk at 1, 2.5 and 5 m", cam = &"first_person", slug = &"dp3", fn = func() -> void: await _distances(bot)},
	]


static func _jacket(bot: Node) -> void:
	LookActs._begin(bot)
	await bot._look_to(LookActs.LEVEL_PITCH_DEG, LookActs.PITCH_TICKS)
	LookRect.mark(bot, "dp1", "start")
	for yaw_deg: float in YAWS_DEG:
		bot.clear_enemies()
		var subject: EnemyActor = bot.spawn(&"punk", Vector2(0.0, DISTANCE_M))
		var facing := subject.rotation.y + deg_to_rad(yaw_deg)
		for _i in HOLD_TICKS:
			subject.rotation.y = facing
			await bot._ticks(1)
		LookRect.mark(bot, "dp1", "yaw%d" % int(yaw_deg), subject)
	LookActs._end(bot, "dp1")


static func _pair(bot: Node) -> void:
	LookActs._begin(bot)
	await bot._look_to(LookActs.LEVEL_PITCH_DEG, LookActs.PITCH_TICKS)
	LookRect.mark(bot, "dp2", "start")
	for distance: float in PAIR_DISTANCES_M:
		bot.clear_enemies()
		var half := distance * PAIR_SPREAD
		var punk: EnemyActor = bot.spawn(&"punk", Vector2(-half, distance))
		var veteran: EnemyActor = bot.spawn(&"punk_veteran", Vector2(half, distance))
		await bot._ticks(PAIR_HOLD_TICKS)
		LookRect.mark(bot, "dp2", "d%s_m" % str(distance).replace(".", "_"), punk)
		bot.log_line("DETAIL-PUNK pair d=%.1f veteran=%s" % [distance, veteran.name])
	LookActs._end(bot, "dp2")


static func _distances(bot: Node) -> void:
	LookActs._begin(bot)
	await bot._look_to(LookActs.LEVEL_PITCH_DEG, LookActs.PITCH_TICKS)
	LookRect.mark(bot, "dp3", "start")
	for distance: float in SHEET_DISTANCES_M:
		bot.clear_enemies()
		var subject: EnemyActor = bot.spawn(&"punk", Vector2(0.0, distance))
		await bot._ticks(PAIR_HOLD_TICKS)
		LookRect.mark(bot, "dp3", "d%s_m" % str(distance).replace(".", "_"), subject)
	LookActs._end(bot, "dp3")
