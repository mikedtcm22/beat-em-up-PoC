extends RefCounted
## The boss's ground pound from where a player really stands (final review, tells-01), first
## person, for the crowd bot (tests/bot/crowd_bot.gd). Record with
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/fix/pound "Final pound" 12
## "Final pound at 0.9 m" and "at 1.1 m" put the frozen boss that far in front of a player who
## stands still (god mode) and throw the pound (force_attack); the strike lands on him, and the
## view should show the boss squatting with its fists down, never its cap in the lens. The slam
## is "Boss grab slam" (boss_acts.gd), judged against "Bruiser headbutt" (bruiser_acts.gd); "Final
## slam (side view)" is the same act from the side, for the pose.

const BossActs := preload("res://tests/bot/acts/boss_acts.gd")
const ThugActs := preload("res://tests/bot/acts/thug_acts.gd")
## How many seconds the dropped pipe is watched for, once a second (final review, tells-02).
const PIPE_WATCH_S := 8


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Final pound at 0.9 m", cam = &"first_person", fn = func() -> void: await _pound(bot, 0.9)},
		{title = "Final pound at 1.1 m", cam = &"first_person", fn = func() -> void: await _pound(bot, 1.1)},
		{title = "Final pipe rest", cam = &"first_person", fn = func() -> void: await _pipe_rest(bot)},
		{title = "Final slam (side view)", cam = &"side_view", fn = func() -> void: await BossActs._grab_slam(bot)},
	]


static func _pound(bot: Node, metres: float) -> void:
	bot.god()
	var boss: EnemyActor = await BossActs._boss(bot, Vector2(0.0, metres))
	await BossActs._wind_up(bot, boss, 1)
	await BossActs._finish(bot, boss, 90)


## "Thug drops the pipe" (the knockdown, then a look down at it), then the player stands still and
## looks down at the pipe for PIPE_WATCH_S seconds: PIPE lines in the log give its distance from
## him and its speed each second. It should lie where it fell, in LB's reach, and not move.
static func _pipe_rest(bot: Node) -> void:
	await ThugActs._drops(bot)
	await bot._look_to(ThugActs.LOOK_DOWN_DEG, 20)
	for second in PIPE_WATCH_S:
		for node: Node in bot.get_tree().get_nodes_in_group(&"thug_pipe"):
			var pipe := node as Weapon
			if pipe and pipe.is_available():
				bot.log_line("PIPE s%d %.2f m from the player (in reach %s), speed %.3f m/s, spin %.3f rad/s, asleep %s" % [
						second, pipe.global_position.distance_to(bot.player.global_position + Vector3.UP * 0.3),
						pipe.global_position.distance_to(bot.player.global_position + Vector3.UP * 0.3) <= Tuning.data.pickup_range,
						pipe.linear_velocity.length(), pipe.angular_velocity.length(), pipe.sleeping])
		await bot._ticks(60)
