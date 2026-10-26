extends RefCounted
## The crowd room's own acts (P1-room): a tour of the street in first person, a high fly-through
## with the F3 overlay on, and the spawn points seen from above. See tests/bot/crowd_bot.gd.


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Room tour", cam = &"first_person", fn = func() -> void: await _tour(bot)},
		{title = "Room tour, free fly, F3", cam = &"free_fly", fn = func() -> void: await _fly(bot)},
		{title = "Spawn points", cam = &"free_fly", fn = func() -> void: await _spawn_points(bot)},
		{title = "F4 menu", cam = &"first_person", fn = func() -> void: await _cheats(bot)},
	]


## A full turn on the spot, then east along the lane to the alley mouth, a look into the
## north doorway and the east alley, back west past the car to the west alley, a look into the
## far doorway, and a turn to the near curb.
static func _tour(bot: Node) -> void:
	await bot._look_to(0.0, 6)
	await bot._turn_by(360.0, 360)
	await bot._ticks(20)
	bot.player.input.scripted_move = Vector2(0, 1)
	await bot._wait_until(func() -> bool: return bot.player.global_position.x > 9.0, 400)
	bot.player.input.scripted_move = Vector2.ZERO
	await bot._turn_by(90.0, 40)
	await bot._ticks(50)
	await bot._turn_by(-90.0, 40)
	await bot._ticks(50)
	await bot._turn_by(180.0, 60)
	bot.player.input.scripted_move = Vector2(0, 1)
	await bot._wait_until(func() -> bool: return bot.player.global_position.x < -9.0, 600)
	bot.player.input.scripted_move = Vector2.ZERO
	await bot._ticks(40)
	await bot._turn_by(-90.0, 40)
	await bot._ticks(50)
	await bot._turn_by(180.0, 60)
	await bot._ticks(50)


## A pass above the street from the west end to the east end, looking into the lane, the
## F3 overlay on (the player's and enemies' debug draw, the navmesh paths of enemies if any).
static func _fly(bot: Node) -> void:
	var hud: Node = bot._hud()
	if hud:
		hud.call(&"set_debug_draw_enabled", true)
	await _fly_path(bot, Vector3(-13.0, 6.0, 10.0), Vector3(-6.0, 5.0, 9.0), Vector3(-2.0, 0.0, -2.0), 240)
	await _fly_path(bot, Vector3(-6.0, 5.0, 9.0), Vector3(6.0, 5.0, 9.0), Vector3(0.0, 0.0, -2.0), 360)
	await _fly_path(bot, Vector3(6.0, 5.0, 9.0), Vector3(13.0, 6.0, 10.0), Vector3(2.0, 0.0, -2.0), 240)
	if hud:
		hud.call(&"set_debug_draw_enabled", false)


## One enemy at every spawn point, seen from high above the lane, so each point's place (a
## doorway's back, an alley's far end, the strip behind the car) reads at once.
static func _spawn_points(bot: Node) -> void:
	bot.ensure_scene(&"punk")
	for point: Dictionary in bot.spawner.spawn_points:
		bot.spawner.spawn_enemy(&"punk", point.position, point.yaw, false, point.lane_point)
	await _fly_path(bot, Vector3(0.0, 24.0, 16.0), Vector3(0.0, 24.0, 16.0), Vector3(0.0, 0.0, 0.0), 30)
	await bot._ticks(150)
	await _fly_path(bot, Vector3(0.0, 24.0, 16.0), Vector3(-3.0, 12.0, 14.0), Vector3(-4.0, 0.0, 0.0), 120)
	await bot._ticks(90)


## Move the free-fly camera from `from` to `to` over `ticks` physics ticks, always looking at
## `target` (it only ever moves along the line: no input reaches it).
static func _fly_path(bot: Node, from: Vector3, to: Vector3, target: Vector3, ticks: int) -> void:
	var camera := bot.director.free_fly_camera as Camera3D
	for i in ticks:
		await bot.get_tree().physics_frame
		var at := from.lerp(to, float(i + 1) / float(ticks))
		camera.global_transform = Transform3D(Basis.IDENTITY, at).looking_at(target, Vector3.UP)


## The F4 menu open over the street (its enemy list, remove all, waves and freeze), an enemy
## spawned from it at the crosshair, then closed.
static func _cheats(bot: Node) -> void:
	var overlay := bot.room.find_children("*", "TuningOverlay", false, false)[0] as TuningOverlay
	await bot._look_to(0.0, 6)
	overlay.set_cheats_open(true)
	await bot._ticks(60)
	overlay.cheats.spawn_selected()
	bot.set_waves(true)
	await bot._ticks(90)
	overlay.close_all()
	bot.set_waves(false)
	await bot._ticks(30)
