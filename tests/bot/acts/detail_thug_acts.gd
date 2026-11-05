extends RefCounted
## The Pipe Thug's detail acts (Milestone 6, ROLL-THUG): "Look: Thug detail turn" holds the Thug 1.6 m ahead, turned away from the
## player by 0, 90 and 150 degrees (the AI is overridden each tick), so the hoodie, the strap and the bandana are judged where the
## guard does not hide them; "Look: Thug detail distances" holds him facing the player at 1, 2.5 and 5 m, level view. Record with
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/<key> "Look: Thug detail" 6
## The marks are LOOK-MARK dt f<frame> yaw<deg> ... and dd f<frame> d<m>_m ..., each act ending with end.

const LookActs := preload("res://tests/bot/acts/look_acts.gd")
const LookRect := preload("res://tests/bot/look_rect.gd")
## The turn act: how far ahead (m), the turns from facing the player (degrees) and how long each is held (physics ticks).
const TURN_DISTANCE_M := 1.6
const YAWS_DEG: Array[float] = [0.0, 90.0, 150.0]
const HOLD_TICKS := 60
## The distance act: the distances (m) and how long each is held.
const DISTANCES_M: Array[float] = [1.0, 2.5, 5.0]
const DISTANCE_HOLD_TICKS := 90


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Look: Thug detail turn", cam = &"first_person", slug = &"dt", fn = func() -> void: await _turn(bot)},
		{title = "Look: Thug detail distances", cam = &"first_person", slug = &"dd", fn = func() -> void: await _distances(bot)},
	]


static func _turn(bot: Node) -> void:
	LookActs._begin(bot)
	await bot._look_to(LookActs.LEVEL_PITCH_DEG, LookActs.PITCH_TICKS)
	LookRect.mark(bot, "dt", "start")
	for yaw_deg: float in YAWS_DEG:
		bot.clear_enemies()
		var subject: EnemyActor = bot.spawn(&"thug", Vector2(0.0, TURN_DISTANCE_M))
		var facing := subject.rotation.y + deg_to_rad(yaw_deg)
		for _i in HOLD_TICKS:
			subject.rotation.y = facing
			await bot._ticks(1)
		LookRect.mark(bot, "dt", "yaw%d" % int(yaw_deg), subject)
	LookActs._end(bot, "dt")


static func _distances(bot: Node) -> void:
	LookActs._begin(bot)
	await bot._look_to(LookActs.LEVEL_PITCH_DEG, LookActs.PITCH_TICKS)
	LookRect.mark(bot, "dd", "start")
	for distance: float in DISTANCES_M:
		bot.clear_enemies()
		var subject: EnemyActor = bot.spawn(&"thug", Vector2(0.0, distance))
		await bot._ticks(DISTANCE_HOLD_TICKS)
		LookRect.mark(bot, "dd", "d%s_m" % str(distance).replace(".", "_"), subject)
	LookActs._end(bot, "dd")
