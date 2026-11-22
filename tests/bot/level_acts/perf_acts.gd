extends RefCounted
## The level's frame-time act (M6 KIT, D29), measured by tests/bot/perf_level_bot.gd (which prints
## `PERF-BENCH`) and compared across checkouts by `tools/perf_compare.sh --bot`:
##   "Perf: level walk"  god mode, the full-speed autopilot plays street A1-A3 and the roofs' A4-A6
##                       (arenas 0 to 5 of Mission 1), walking the route between them; the seeded
##                       waves and the route are the same on every checkout. It is the "before" of
##                       M6's environment art (the first KIT commit) and its "after".
##   "Perf: roofs walk"  (M7 T52) the same walk over the roofs' arenas only (A4-A6), so the roofs' frame time
##                       can be read on its own.
##   "Perf: boss roof"   (M7 T52) god mode, the autopilot fights the boss roof's arena (Ox) from its start.
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
## The roofs' first arena (A4, the terrace).
const FIRST_ROOFS_ARENA := 3


## Physics ticks a pose is held before it is counted (the light's blend and the first draws settle), and
## the frames counted.
const SETTLE_TICKS := 90
const COUNT_FRAMES := 40

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
		{title = "Perf: inventory", cam = &"first_person", fn = func() -> void: await _inventory(bot)},
		{title = "Perf: roofs walk", cam = &"first_person", fn = func() -> void: await _walk(bot, FIRST_ROOFS_ARENA, LAST_ARENA)},
		{title = "Perf: boss roof", cam = &"first_person", fn = func() -> void: await _walk(bot, LAST_ARENA + 1, -1)},
	]


## The pose-by-pose inventory (a diagnostic, not a bench): at each counters pose, the meshes whose box is in the
## camera's frustum, as `INV <pose> <triangles> <overlay triangles> <shadow> <path>` lines, the biggest first, and
## the pose's sums by group (the node's parent chain under the section, indices stripped).
static func _inventory(bot: Node) -> void:
	bot.freeze_ai(true)
	bot.god(true)
	var player: PlayerCharacter = bot.player
	var cam: Camera3D = bot.get_viewport().get_camera_3d()
	for n in POSES.size():
		var pose: Dictionary = POSES[n]
		var section: Node3D = bot.level.sections[int(pose.section)]
		var yaw := deg_to_rad(float(pose.yaw))
		var at: Vector3 = section.global_position + pose.at
		player.rotation.y = yaw
		player.look_yaw = yaw
		player.look_pitch = deg_to_rad(float(pose.pitch))
		for _tick in 30:
			player.global_position = at
			player.velocity = Vector3.ZERO
			await bot._ticks(1)
		var rows: Array[Dictionary] = []
		var groups := {}
		var buckets: Array[int] = [0, 0, 0, 0]
		var bucket_n: Array[int] = [0, 0, 0, 0]
		for node: Node in bot.level.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			var box := mi.global_transform * mi.mesh.get_aabb()
			var inside := false
			for corner in 8:
				if cam.is_position_in_frustum(box.get_endpoint(corner)):
					inside = true
					break
			if not inside and not cam.is_position_in_frustum(box.get_center()):
				continue
			var tris := _tris(mi.mesh)
			var over := _tris(mi.mesh) if mi.material_overlay != null else 0
			var next_pass := 0
			for s in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(s)
				if mat != null and mat.next_pass != null:
					next_pass += _tris(mi.mesh, s)
			var shadow := mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var path := str(section.get_path_to(mi))
			var dist := cam.global_position.distance_to(box.get_center())
			var bucket := 0 if dist < 15.0 else (1 if dist < 30.0 else (2 if dist < 60.0 else 3))
			buckets[bucket] += tris + over + next_pass
			bucket_n[bucket] += 1
			rows.append({tris = tris, over = over + next_pass, shadow = shadow, path = path, range_end = mi.visibility_range_end, dist = dist})
			var key := "[%d] " % bucket
			for part in path.split("/"):
				var clean := part
				while clean.length() > 0 and clean[clean.length() - 1].is_valid_int():
					clean = clean.left(clean.length() - 1)
				key += "/" + clean
			var g: Dictionary = groups.get(key, {n = 0, tris = 0, over = 0})
			g.n += 1
			g.tris += tris
			g.over += over + next_pass
			groups[key] = g
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.tris) + int(a.over) > int(b.tris) + int(b.over))
		for i in mini(rows.size(), 6):
			bot.log_line("INV %d %s %d %d %s d=%.0f %s" % [n, pose.label, rows[i].tris, rows[i].over, rows[i].shadow, rows[i].dist, rows[i].path])
		bot.log_line("DIST %d %s <15m n=%d tris=%d | 15-30 n=%d tris=%d | 30-60 n=%d tris=%d | >60 n=%d tris=%d" % [n, pose.label, bucket_n[0], buckets[0], bucket_n[1], buckets[1], bucket_n[2], buckets[2], bucket_n[3], buckets[3]])
		var keys := groups.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return int(groups[a].tris) + int(groups[a].over) > int(groups[b].tris) + int(groups[b].over))
		for i in mini(keys.size(), 14):
			bot.log_line("GRP %d %s n=%d tris=%d over=%d %s" % [n, pose.label, groups[keys[i]].n, groups[keys[i]].tris, groups[keys[i]].over, keys[i]])


static func _tris(mesh: Mesh, only_surface: int = -1) -> int:
	var total := 0
	for s in mesh.get_surface_count():
		if only_surface >= 0 and s != only_surface:
			continue
		var arrays := mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var idx = arrays[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			total += (idx as PackedInt32Array).size() / 3
		else:
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


## A local experiment file (tests/bot/level_acts/perf_experiments.gd, not committed) may switch things off before and during the count.
static func _experiments(bot: Node, method: StringName) -> void:
	var path := "res://tests/bot/level_acts/perf_experiments.gd"
	if OS.get_environment("PERF_EXP") != "" and ResourceLoader.exists(path):
		(load(path) as GDScript).call(method, bot)


static func _counters(bot: Node) -> void:
	if bot.level.sections.size() < 2:
		bot.log_line("NOTE the counters act needs the whole level")
		return
	bot.freeze_ai(true)
	bot.god(true)
	_experiments(bot, &"_experiment")
	var player: PlayerCharacter = bot.player
	var viewport: Viewport = bot.get_viewport()
	var tree: SceneTree = bot.get_tree()
	var totals := {}
	var pose_ms := PackedFloat32Array()
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
		_experiments(bot, &"_experiment_pose")
		var times := PackedFloat32Array()
		var last_us := Time.get_ticks_usec()
		for _frame in COUNT_FRAMES:
			await tree.process_frame
			var now_us := Time.get_ticks_usec()
			times.append(float(now_us - last_us) / 1000.0)
			last_us = now_us
			sums.draws += viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
			sums.objects += viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME)
			sums.prims += viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
			sums.sdraws += viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
			sums.sobjects += viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_OBJECTS_IN_FRAME)
			sums.sprims += viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
		times.sort()
		pose_ms.append(times[COUNT_FRAMES / 4])
		var line := "POSE %d %s p25=%.2f" % [n, pose.label, times[COUNT_FRAMES / 4]]
		for key: String in sums:
			var mean := roundi(float(sums[key]) / float(COUNT_FRAMES))
			totals[key] = int(totals.get(key, 0)) + mean
			line += " %s=%d" % [key, mean]
		bot.log_line(line)
	var ms_sum := 0.0
	for value in pose_ms:
		ms_sum += value
	var total_line := "POSE-TOTAL p25_sum=%.2f" % ms_sum
	for key: String in totals:
		total_line += " %s=%d" % [key, totals[key]]
	bot.log_line(total_line)


## God mode, the autopilot plays arenas `from` to `to` (-1: the last; default the level walk's, 0 to LAST_ARENA).
static func _walk(bot: Node, from: int = 0, to: int = LAST_ARENA) -> void:
	bot.god(true)
	await bot._look_to(0.0, 10)
	var arenas: Array[Arena] = bot.level.arenas()
	var last := mini(to, arenas.size() - 1) if to >= 0 else arenas.size() - 1
	await bot.run_level(mini(from, last), last, false, false)
