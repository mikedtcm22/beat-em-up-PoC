extends RefCounted
## Ox's robe act (Milestone 6, OX-2): Ox 1.6 m ahead, turned away from the player by 0, 90 and 150 degrees and
## held there (the AI is overridden each tick), so the robe's folds, the orange trim's borders and the belt can be judged where the
## guard does not hide them. Record with
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/<key> "Look: Ox robe" 6
## The marks are LOOK-MARK dox f<frame> yaw<deg> ... and end.

const LookActs := preload("res://tests/bot/acts/look_acts.gd")
const LookRect := preload("res://tests/bot/look_rect.gd")
## How far ahead (m), the turns from facing the player (degrees) and how long each is held (physics ticks).
const DISTANCE_M := 1.6
const YAWS_DEG: Array[float] = [0.0, 90.0, 150.0]
const HOLD_TICKS := 60


static func acts(bot: Node) -> Array[Dictionary]:
	return [{title = "Look: Ox robe", cam = &"first_person", slug = &"dox", fn = func() -> void: await _robe(bot)}]


static func _robe(bot: Node) -> void:
	LookActs._begin(bot)
	await bot._look_to(LookActs.LEVEL_PITCH_DEG, LookActs.PITCH_TICKS)
	LookRect.mark(bot, "dox", "start")
	for yaw_deg: float in YAWS_DEG:
		bot.clear_enemies()
		var subject: EnemyActor = bot.spawn(&"boss", Vector2(0.0, DISTANCE_M))
		var facing := subject.rotation.y + deg_to_rad(yaw_deg)
		for _i in HOLD_TICKS:
			subject.rotation.y = facing
			await bot._ticks(1)
		LookRect.mark(bot, "dox", "yaw%d" % int(yaw_deg), subject)
	LookActs._end(bot, "dox")
