extends RefCounted
## The first-person arms on Mission 1's night street against a Punk (M7 G4): the stills the arms are judged from under the trailer profile.
## The player stands in the street's first stretch (the lamps, pools, windows and the burn barrel behind the Punk) and a Punk stands a
## jab's reach ahead, the AI frozen. The act logs `G4 <n> <label> f<frame>`, the video frame to cut each still at (60 a second):
##   0 stance (the Punk in guard, the arms at rest), 1 guard (B held), 2 jab landing, 3 hook landing (jab, jab, hook), 4 blocked jab
##   (B held, the Punk's own jab blocked on the guard).
## Record with the command in docs/milestones/M7-calls/g4.md. Needs the whole street (`--level=res://game/level/mission1/mission1.tscn`,
## which g4_arms_bot.gd sets).

## Where the player stands (the street section's space) and the Punk's distance in front of him (m).
const STAND_AT := Vector3(-1.0, 0.0, -6.0)
const PUNK_GAP_M := 1.0

static var _hits: Array[HitInfo] = []


static func acts(bot: Node) -> Array[Dictionary]:
	return [{title = "G4: arms against a Punk on the night street", cam = &"first_person", fn = func() -> void: await _arms(bot)}]


static func _on_hit(hit: HitInfo) -> void:
	_hits.append(hit)


## The Punk back in front of the player at the gap, facing him, whole and still.
static func _reset_punk(bot: Node, punk: EnemyActor) -> void:
	var player: PlayerCharacter = bot.player
	var at := player.global_position + player.global_basis * Vector3(0.0, 0.0, -PUNK_GAP_M)
	at.y = player.global_position.y
	punk.global_position = at
	punk.velocity = Vector3.ZERO
	var to_player := player.global_position - at
	punk.rotation.y = atan2(-to_player.x, -to_player.z)
	punk.health = punk.max_health
	await bot._ticks(24)


static func _still(bot: Node, n: int, label: String) -> void:
	bot.log_line("G4 %d %s f%d" % [n, label, Engine.get_physics_frames()])


static func _arms(bot: Node) -> void:
	if bot.level == null or bot.level.sections.is_empty():
		bot.log_line("NOTE the G4 arms act needs a level (the bot's --level)")
		return
	var player: PlayerCharacter = bot.player
	var street: Node3D = bot.level.sections[0]
	bot.freeze_ai(true)
	bot.god(true)
	var yaw := 0.0
	player.global_position = street.global_position + STAND_AT
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw
	player.look_yaw = yaw
	player.look_pitch = deg_to_rad(-4.0)
	await bot._ticks(30)
	var punk := bot.spawn(&"punk", Vector2(0.0, PUNK_GAP_M)) as EnemyActor
	if punk == null:
		bot.log_line("NOTE the G4 arms act could not spawn a Punk")
		return
	punk.max_health = 500.0
	punk.health = 500.0
	await bot._ticks(36)
	_hits.clear()
	CombatEvents.hit_landed.connect(_on_hit)
	# 0: stance. Held a second, so the cut can be taken anywhere in it.
	_still(bot, 0, "stance")
	await bot._ticks(40)
	# 1: guard up, held.
	await bot._hold_block()
	await bot._ticks(24)
	_still(bot, 1, "guard")
	await bot._ticks(20)
	await bot._release_block()
	await bot._ticks(20)
	# 2: a jab landing.
	var before := _hits.size()
	await bot._press(&"P", 2)
	await bot._wait_until(func() -> bool: return _hits.size() > before, 60)
	_still(bot, 2, "jab_landing")
	await bot._ticks(30)
	await _reset_punk(bot, punk)
	# 3: jab, jab, hook: the third lands the hook.
	before = _hits.size()
	for i in 3:
		await bot._press(&"P", 2, 8)
	await bot._wait_until(func() -> bool: return _hits.size() >= before + 3, 90)
	_still(bot, 3, "hook_landing")
	await bot._ticks(40)
	await bot._wait_idle()
	await _reset_punk(bot, punk)
	# 4: the Punk's jab blocked on the guard.
	await bot._hold_block()
	before = _hits.size()
	punk.force_attack(0)
	await bot._wait_until(func() -> bool: return _hits.size() > before, 120)
	_still(bot, 4, "blocked_jab")
	await bot._ticks(30)
	await bot._release_block()
	bot.god(false)
	CombatEvents.hit_landed.disconnect(_on_hit)
