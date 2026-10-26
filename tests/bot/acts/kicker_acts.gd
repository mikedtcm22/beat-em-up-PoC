extends RefCounted
## The Kicker's acts of Milestone 3 (P2-kicker) for the crowd bot (tests/bot/crowd_bot.gd), first
## person unless the title says otherwise. Record with
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/p2-kicker "Kicker flanks" 6
##
## "Kicker flanks": the player stands still and a Kicker walks in from ahead: it should circle
## to his back and the rear warning fire when it winds up there. The jump kick and the sweep in
## front are thrown with force_attack() on a frozen AI, so the wind-up is judged from the lens at
## its attack's own range; "jumped over" has the player jump the sweep. "Kicker and Punks" is the
## mixed crowd (cadence and the blind side against the Punk's). Acts with `probe = true` print the
## readability summary and the warning oracle's WARN-CHECK lines.

## How many frames into the sweep's wind-up the player jumps: the legs are off the floor by the
## time the arc is live (the sweep's startup is 20).
const JUMP_AT_FRAME := 11


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Kicker flanks", cam = &"first_person", probe = true, fn = func() -> void: await _flanks(bot)},
		{title = "Kicker jump kick in front", cam = &"first_person", fn = func() -> void: await _front(bot, 0, 2.6)},
		{title = "Kicker sweep in front", cam = &"first_person", fn = func() -> void: await _front(bot, 1, 1.4)},
		{title = "Kicker sweep jumped over", cam = &"first_person", fn = func() -> void: await _jumped_over(bot)},
		{title = "Kicker jump kick (side view)", cam = &"side_view", fn = func() -> void: await _front(bot, 0, 2.6)},
		{title = "Kicker sweep (side view)", cam = &"side_view", fn = func() -> void: await _front(bot, 1, 1.4)},
		{title = "Kicker behind warns", cam = &"first_person", probe = true, fn = func() -> void: await _behind(bot)},
		{title = "Kicker and Punks", cam = &"first_person", probe = true, fn = func() -> void: await _mixed(bot)},
	]


## The player stands still (god mode), one Kicker walks in from the east alley, ahead of him: it
## takes its slot round at his back, and from there winds up; the oracle checks the warning at
## every wind-up.
static func _flanks(bot: Node) -> void:
	bot.god()
	var kicker: EnemyActor = bot.spawn_at_point(&"kicker", 4)
	for i in 60:
		await bot._ticks(15)
		if is_instance_valid(kicker):
			bot.log_line("KICKER f%d bearing %d dist %.1f %s" % [Engine.get_physics_frames(),
					roundi(bot.player.look_bearing_deg(kicker.global_position)),
					Vector2(kicker.global_position.x - bot.player.global_position.x,
							kicker.global_position.z - bot.player.global_position.z).length(), kicker.ai_state_name()])


## `bot.spawn()` a Kicker `distance` metres ahead on a frozen AI and have it throw attack `index`
## (0 the jump kick, 1 the sweep); the player stands still and takes it (god mode).
static func _front(bot: Node, index: int, distance: float) -> void:
	bot.god()
	bot.freeze_ai(true)
	var kicker: EnemyActor = bot.spawn(&"kicker", Vector2(0.0, distance))
	await bot._ticks(30)
	kicker.force_attack(index)
	await bot._wait_until(func() -> bool: return kicker.state == CombatTypes.ActorState.WINDUP, 20)
	await bot._wait_until(func() -> bool: return kicker.current_move == null, 240)
	await bot._ticks(60)


## The sweep at 1.4 m; the player jumps in its wind-up, so it passes under (no damage, no
## knockdown: the legs are above the arc).
static func _jumped_over(bot: Node) -> void:
	bot.freeze_ai(true)
	var kicker: EnemyActor = bot.spawn(&"kicker", Vector2(0.0, 1.4))
	await bot._ticks(30)
	kicker.force_attack(1)
	await bot._wait_until(func() -> bool: return kicker.state == CombatTypes.ActorState.WINDUP, 20)
	await bot._wait_until(func() -> bool: return kicker.move_frame >= JUMP_AT_FRAME, 40)
	await bot._press(&"JUMP", 2)
	await bot._wait_until(func() -> bool: return kicker.current_move == null, 240)
	await bot._ticks(90)


## Kickers placed at the player's back (the warning's both-corners case at the jump kick's long
## reach, then the sweep's short one behind-left), the AI frozen, god mode, WARN-CHECK per wind-up.
static func _behind(bot: Node) -> void:
	bot.god()
	bot.freeze_ai(true)
	await bot._look_to(0.0, 6)
	for spec: Array in [[0, 180.0, 2.6], [1, 135.0, 1.4], [0, -135.0, 2.6]]:
		var kicker: EnemyActor = bot.spawn(&"kicker", _rel_at(spec[1], spec[2]))
		await bot._ticks(20)
		kicker.force_attack(spec[0])
		await bot._wait_until(func() -> bool: return kicker.state == CombatTypes.ActorState.WINDUP, 20)
		await bot._wait_until(func() -> bool: return kicker.current_move == null, 240)
		await bot._ticks(40)
		bot.clear_enemies()
		await bot._ticks(20)


## Two Kickers among four Punks, the player held back (the autopilot's defensive style), god mode:
## the crowd as the waves will make it.
static func _mixed(bot: Node) -> void:
	bot.god()
	for i in 6:
		bot.spawn_at_point(&"kicker" if i % 3 == 1 else &"punk", bot.SURROUND_POINTS[i])
		await bot._ticks(24)
	await bot.fight(1500)


## The `rel` (x right, y ahead of the player, metres) of a point `distance_m` away at `bearing_deg`
## from the look (0 ahead, positive to the left, +-180 behind, as the rear warning's bearings).
static func _rel_at(bearing_deg: float, distance_m: float) -> Vector2:
	var b := deg_to_rad(bearing_deg)
	return Vector2(-sin(b) * distance_m, cos(b) * distance_m)
