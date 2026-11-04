extends RefCounted
## The level's frame-time act (M6 KIT, D29), measured by tests/bot/perf_level_bot.gd (which prints
## `PERF-BENCH`) and compared across checkouts by `tools/perf_compare.sh --bot`:
##   "Perf: level walk"  god mode, the full-speed autopilot plays street A1-A3 and the roofs' A4-A6
##                       (arenas 0 to 5 of Mission 1), walking the route between them; the seeded
##                       waves and the route are the same on every checkout. It is the "before" of
##                       M6's environment art (the first KIT commit) and its "after".
## Needs the whole level (the perf level bot's default is Mission 1).

## The last arena of the walk (0-based): A6, the roofs' top roof; the boss is not in it.
const LAST_ARENA := 5


static func acts(bot: Node) -> Array[Dictionary]:
	return [{title = "Perf: level walk", cam = &"first_person", fn = func() -> void: await _walk(bot)}]


static func _walk(bot: Node) -> void:
	bot.god(true)
	await bot._look_to(0.0, 10)
	var arenas: Array[Arena] = bot.level.arenas()
	var last := mini(LAST_ARENA, arenas.size() - 1)
	await bot.run_level(0, last, false, false)
