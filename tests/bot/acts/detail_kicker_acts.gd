extends RefCounted
## The Kicker's detail acts (Milestone 6, ROLL-KICKER): "Look: Kicker vest" turns him 1.6 m ahead by 0, 90 and 150 degrees and holds
## each (the AI is overridden every tick), so the vest's hood and hem, the wraps and the shorts' pockets are judged where the guard does
## not hide them (DETAIL-2's jacket act, for the Kicker); "Look: Kicker beside a Punk" puts him next to a Street Punk at 1.2, 2.5 and 5 m.
## Record with
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/<key> "Look: Kicker" 6
## The marks are LOOK-MARK dk f<frame> yaw<deg> ... and end, and dk2 f<frame> d<m>_m ... and end.

const LookActs := preload("res://tests/bot/acts/look_acts.gd")
const LookRect := preload("res://tests/bot/look_rect.gd")
## How far ahead (m), the turns from facing the player (degrees) and how long each is held (physics ticks).
const DISTANCE_M := 1.6
const YAWS_DEG: Array[float] = [0.0, 90.0, 150.0]
const HOLD_TICKS := 60
## The distances (m) for the lineup beside a Punk and the bearings (degrees, positive to the left) at 2.5 m.
const LINEUP_DISTANCES_M: Array[float] = [1.2, 2.5, 5.0]
const LINEUP_HOLD_TICKS := 90
const PUNK_BEARING_DEG := 7.0


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Look: Kicker vest", cam = &"first_person", slug = &"dk", fn = func() -> void: await _vest(bot)},
		{title = "Look: Kicker beside a Punk", cam = &"first_person", slug = &"dk2", fn = func() -> void: await _beside(bot)},
	]


static func _vest(bot: Node) -> void:
	LookActs._begin(bot)
	await bot._look_to(LookActs.LEVEL_PITCH_DEG, LookActs.PITCH_TICKS)
	LookRect.mark(bot, "dk", "start")
	for yaw_deg: float in YAWS_DEG:
		bot.clear_enemies()
		var subject: EnemyActor = bot.spawn(&"kicker", Vector2(0.0, DISTANCE_M))
		var facing := subject.rotation.y + deg_to_rad(yaw_deg)
		for _i in HOLD_TICKS:
			subject.rotation.y = facing
			await bot._ticks(1)
		LookRect.mark(bot, "dk", "yaw%d" % int(yaw_deg), subject)
	LookActs._end(bot, "dk")


static func _beside(bot: Node) -> void:
	LookActs._begin(bot)
	await bot._look_to(LookActs.LEVEL_PITCH_DEG, LookActs.PITCH_TICKS)
	LookRect.mark(bot, "dk2", "start")
	for distance: float in LINEUP_DISTANCES_M:
		bot.clear_enemies()
		var bearing := deg_to_rad(PUNK_BEARING_DEG * 2.5 / distance * 2.0)
		bot.spawn(&"punk", Vector2(-sin(bearing), cos(bearing)) * distance)
		var subject: EnemyActor = bot.spawn(&"kicker", Vector2(0.0, distance))
		await bot._ticks(LINEUP_HOLD_TICKS)
		LookRect.mark(bot, "dk2", "d%s_m" % str(distance).replace(".", "_"), subject)
	LookActs._end(bot, "dk2")
