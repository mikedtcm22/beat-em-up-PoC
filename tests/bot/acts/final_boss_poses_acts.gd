extends RefCounted
## The boss's ground pound from where a player really stands (final review, tells-01), first
## person, for the crowd bot (tests/bot/crowd_bot.gd). Record with
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/fix/pound "Final pound" 12
## "Final pound at 0.9 m" and "at 1.1 m" put the frozen boss that far in front of a player who
## stands still (god mode) and throw the pound (force_attack); the strike lands on him, and the
## view should show the boss squatting with its fists down, never its cap in the lens. The slam
## is "Boss grab slam" (boss_acts.gd), judged against "Bruiser headbutt" (bruiser_acts.gd).

const BossActs := preload("res://tests/bot/acts/boss_acts.gd")


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Final pound at 0.9 m", cam = &"first_person", fn = func() -> void: await _pound(bot, 0.9)},
		{title = "Final pound at 1.1 m", cam = &"first_person", fn = func() -> void: await _pound(bot, 1.1)},
	]


static func _pound(bot: Node, metres: float) -> void:
	bot.god()
	var boss: EnemyActor = await BossActs._boss(bot, Vector2(0.0, metres))
	await BossActs._wind_up(bot, boss, 1)
	await BossActs._finish(bot, boss, 90)
