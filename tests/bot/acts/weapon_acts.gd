extends RefCounted
## The weapon act of Milestone 6 (WEAPONS) for the crowd bot (tests/bot/crowd_bot.gd): both weapons from the lens's side. Record with
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/weapons "Look: weapons" 6
## It hides the caption, freezes the AI and turns on god mode, and prints through look_rect.gd
##   LOOK-MARK w1 f<frame> <label>      a frame worth a still; `start` and `end` delimit the act
##
## | Act | Title | Shows |
## | w1 | Look: weapons | for the pipe and then the bike chain: lying 0.7 m from the feet (the glint), picked up, three swings at a Punk, the throw at one 4 m off, then the same weapon lying 5 m and 10 m away (the glint's read at distance) |

const LookRect := preload("res://tests/bot/look_rect.gd")
const IDS: Array[StringName] = [&"pipe", &"bike_chain"]
const LEVEL_PITCH_DEG := -6.0
const DOWN_PITCH_DEG := -45.0
const PITCH_TICKS := 20
const SETTLE_TICKS := 50
const NEAR_M := 0.7
const FAR_DISTANCES_M: Array[float] = [5.0, 10.0]
const PUNK_HEALTH := 800.0
const PUNK_DISTANCE_M := 1.2
const TARGET_DISTANCE_M := 4.0
## The ticks after a P press when a swing's tip is at the target (the weapons' startup, 6 to 7, and the first active frames).
const STRIKE_TICKS: Array[int] = [7, 9]
const THROW_FLIGHT_TICKS := 10


static func acts(bot: Node) -> Array[Dictionary]:
	return [{title = "Look: weapons", cam = &"first_person", slug = &"w1", fn = func() -> void: await _weapons(bot)}]


## The weapon `id` lying `distance_m` ahead on the floor, on its side along the player's right, and settled.
static func _lay(bot: Node, id: StringName, distance_m: float) -> Weapon:
	var def := WeaponCatalog.get_def(id)
	var weapon := def.scene.instantiate() as Weapon
	bot.room.add_child(weapon)
	var player: Node3D = bot.player
	weapon.global_position = player.global_position + player.global_basis * Vector3(0.0, 0.2, -distance_m)
	weapon.global_rotation = Vector3(0.0, player.global_rotation.y + PI * 0.5, PI * 0.5)
	await bot._ticks(SETTLE_TICKS)
	return weapon


static func _clear_weapons(bot: Node) -> void:
	for node: Node in bot.get_tree().get_nodes_in_group(&"weapon"):
		node.queue_free()
	await bot._ticks(2)


static func _weapons(bot: Node) -> void:
	bot.caption.visible = false
	bot.god()
	bot.freeze_ai(true)
	LookRect.mark(bot, "w1", "start")
	for id: StringName in IDS:
		var player: PlayerCharacter = bot.player
		await bot._look_to(DOWN_PITCH_DEG, PITCH_TICKS)
		var weapon := await _lay(bot, id, NEAR_M)
		LookRect.mark(bot, "w1", "%s_lying" % id)
		await bot._press(&"GRAB", 2, 14)
		await bot._ticks(10)
		LookRect.mark(bot, "w1", "%s_picked" % id)
		await bot._look_to(LEVEL_PITCH_DEG, PITCH_TICKS)
		var punk: EnemyActor = bot.spawn(&"punk", Vector2(0.0, PUNK_DISTANCE_M))
		punk.max_health = PUNK_HEALTH
		punk.health = PUNK_HEALTH
		await bot._ticks(30)
		LookRect.mark(bot, "w1", "%s_held" % id)
		for i: int in 3:
			player.input.push_press(&"P", 2)
			player.input.push_wait(9)
			var waited := 0
			for tick: int in STRIKE_TICKS:
				await bot._ticks(tick - waited)
				waited = tick
				LookRect.mark(bot, "w1", "%s_swing%d_%d" % [id, i + 1, tick])
			await bot._wait_until(func() -> bool: return player.input.queued() == 0)
		await bot._wait_idle()
		await bot._ticks(30)
		bot.clear_enemies()
		var target: EnemyActor = bot.spawn(&"punk", Vector2(0.0, TARGET_DISTANCE_M))
		target.max_health = PUNK_HEALTH
		target.health = PUNK_HEALTH
		await bot._ticks(20)
		await bot._press(&"GRAB", 2, 0)
		await bot._ticks(THROW_FLIGHT_TICKS)
		LookRect.mark(bot, "w1", "%s_throw" % id)
		await bot._ticks(40)
		bot.clear_enemies()
		await _clear_weapons(bot)
		for distance: float in FAR_DISTANCES_M:
			var far := await _lay(bot, id, distance)
			await bot._look_to(-rad_to_deg(atan2(1.5, distance)), PITCH_TICKS)
			await bot._ticks(40)
			LookRect.mark(bot, "w1", "%s_glint_%dm" % [id, int(distance)])
			far.queue_free()
			await bot._ticks(2)
		await _clear_weapons(bot)
		if weapon != null and is_instance_valid(weapon):
			weapon.queue_free()
	LookRect.mark(bot, "w1", "end")
	bot.caption.visible = true
