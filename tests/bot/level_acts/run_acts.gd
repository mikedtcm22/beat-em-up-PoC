extends RefCounted
## The level-run bot's acts (BOT), level-agnostic: they play whatever level the bot was given
## (`--level=`), from `--from` to `--to` (default the whole level). See tests/bot/level_bot.gd.
##   "Run: held back"  the held-back autopilot plays the level with real damage (a KO stands the player
##                     up in place), the readability probe running over each arena
##   "Run: knock-off"  in the first arena with a hazard volume, a Punk is launched over the edge
##   "Run: timing"     god mode, the full-speed autopilot, no probe: logs each arena's time and LEVEL
##                     (run it headless: `godot --headless --path . res://tests/bot/level_bot.tscn
##                     -- --act="Run: timing" --presentation=0`)


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Run: held back", cam = &"first_person", fn = func() -> void: await _held_back(bot)},
		{title = "Run: knock-off", cam = &"first_person", fn = func() -> void: await _knock_off(bot)},
		{title = "Run: timing", cam = &"first_person", fn = func() -> void: await _timing(bot)},
	]


static func _held_back(bot: Node) -> void:
	await bot._look_to(0.0, 10)
	await bot.run_level(bot.from_arena, bot.to_arena, true, true)


static func _knock_off(bot: Node) -> void:
	await bot._look_to(0.0, 10)
	await bot.knock_off()
	await bot._ticks(60)


static func _timing(bot: Node) -> void:
	bot.god(true)
	await bot.run_level(bot.from_arena, bot.to_arena, false, false)
