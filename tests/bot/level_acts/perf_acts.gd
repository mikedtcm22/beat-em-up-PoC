extends RefCounted
## The level's frame-time act (M6 KIT, D29), measured by tests/bot/perf_level_bot.gd (which prints
## `PERF-BENCH`) and compared across checkouts by `tools/perf_compare.sh --bot`:
##   "Perf: level walk"  god mode, the full-speed autopilot plays street A1-A3 and the roofs' A4-A6
##                       (arenas 0 to 5 of Mission 1), walking the route between them; the seeded
##                       waves and the route are the same on every checkout. It is the "before" of
##                       M6's environment art (the first KIT commit) and its "after".
##   "Perf: counters"    (M6 fix-final-perf) the player is put at a row of fixed poses through the street,
##                       the roofs and the boss roof (the arena tour's), the AI frozen, each held; the
##                       renderer's counters (draw calls, objects, primitives, visible and shadow passes)
##                       are averaged over the last frames of each hold and logged as
##                       `POSE <n> <label> draws=.. objects=.. prims=.. sdraws=.. sobjects=.. sprims=..`.
##                       They do not depend on the machine's load, so a before and an after compare
##                       exactly. The PERF-BENCH line's `counters` are the act's means.
## Needs the whole level (the perf level bot's default is Mission 1).

## The last arena of the walk (0-based): A6, the roofs' top roof; the boss is not in it.
const LAST_ARENA := 5


## Physics ticks a pose is held before it is counted (the light's blend and the first draws settle), and
## the frames counted.
const SETTLE_TICKS := 90
const COUNT_FRAMES := 8

## {label, section (index in the level), at (that section's space, the feet), yaw (degrees), pitch}: the arena
## tour's poses (tests/bot/level_acts/tour_acts.gd), kept here so the act runs on a checkout without it.
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
	{label = "roofs_top_roof", section = 1, at = Vector3(19.0, 7.5, -8.5), yaw = 0.0, pitch = -3.0},
	{label = "roofs_tanks", section = 1, at = Vector3(19.0, 7.5, -16.0), yaw = 90.0, pitch = 2.0},
	{label = "roofs_skyline", section = 1, at = Vector3(22.0, 7.5, -14.0), yaw = -90.0, pitch = 6.0},
]


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Perf: level walk", cam = &"first_person", fn = func() -> void: await _walk(bot)},
		{title = "Perf: counters", cam = &"first_person", fn = func() -> void: await _counters(bot)},
	]


static func _counters(bot: Node) -> void:
	if bot.level.sections.size() < 2:
		bot.log_line("NOTE the counters act needs the whole level")
		return
	bot.freeze_ai(true)
	bot.god(true)
	var player: PlayerCharacter = bot.player
	var viewport: Viewport = bot.get_viewport()
	var tree: SceneTree = bot.get_tree()
	var totals := {}
	for n in POSES.size():
		var pose: Dictionary = POSES[n]
		var section: Node3D = bot.level.sections[int(pose.section)]
		var yaw := deg_to_rad(float(pose.yaw))
		var at: Vector3 = section.global_position + pose.at
		player.rotation.y = yaw
		player.look_yaw = yaw
		player.look_pitch = deg_to_rad(float(pose.pitch))
		for _tick in SETTLE_TICKS:
			player.global_position = at
			player.velocity = Vector3.ZERO
			await bot._ticks(1)
		var sums := {draws = 0, objects = 0, prims = 0, sdraws = 0, sobjects = 0, sprims = 0}
		for _frame in COUNT_FRAMES:
			await tree.process_frame
			sums.draws += viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
			sums.objects += viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME)
			sums.prims += viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
			sums.sdraws += viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
			sums.sobjects += viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_OBJECTS_IN_FRAME)
			sums.sprims += viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
		var line := "POSE %d %s" % [n, pose.label]
		for key: String in sums:
			var mean := roundi(float(sums[key]) / float(COUNT_FRAMES))
			totals[key] = int(totals.get(key, 0)) + mean
			line += " %s=%d" % [key, mean]
		bot.log_line(line)
	var total_line := "POSE-TOTAL"
	for key: String in totals:
		total_line += " %s=%d" % [key, totals[key]]
	bot.log_line(total_line)


static func _walk(bot: Node) -> void:
	bot.god(true)
	await bot._look_to(0.0, 10)
	var arenas: Array[Arena] = bot.level.arenas()
	var last := mini(LAST_ARENA, arenas.size() - 1)
	await bot.run_level(0, last, false, false)
