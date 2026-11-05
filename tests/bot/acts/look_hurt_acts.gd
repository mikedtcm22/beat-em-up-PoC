extends RefCounted
## FB-FEEL's act (M6 playtest feedback): "Look: player hurt". The player stands still in first person (god
## mode off, health refilled before each attack so the damage is real and he is not KO'd) and a Punk, a Kicker and a Bruiser each throw one attack at him
## from the front, from the left and from behind, one after another. The recording judges what the view
## and the HUD do (the shake, the head's roll, the edge vignette, the health panel's jolt). The bot log
## prints `HURT <who> <side>` before each attack and `HURT-HIT <tier> <damage> <blocked>` for each hit he
## takes. Record it with the feel on and off (the switch is Debug's hurt_feel_enabled):
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/<key>/after "Look: player hurt" 6
##   CAPTURE_ARGS="--tune=hurt_feel_enabled=0" tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/<key>/before "Look: player hurt" 6

## Who throws what: the archetype, its attack index (force_attack), the distance in metres, the label.
const ATTACKS: Array[Dictionary] = [
	{id = &"punk", index = 0, distance = 1.0, label = "punk jab"},
	{id = &"kicker", index = 0, distance = 2.6, label = "kicker jump kick"},
	{id = &"bruiser", index = 0, distance = 1.2, label = "bruiser smash"},
]
## The bearings (degrees off the player's view: 0 ahead, 90 to his left, 180 behind) and their names.
const SIDES: Array[Dictionary] = [
	{bearing = 0.0, label = "front"},
	{bearing = 90.0, label = "left"},
	{bearing = 180.0, label = "behind"},
]
const SETTLE_TICKS := 30
const WINDUP_MAX_TICKS := 40
const MOVE_MAX_TICKS := 240
const FREE_MAX_TICKS := 240
const AFTER_TICKS := 40
## A pitch a little under level, as the default view of the look acts.
const PITCH_DEG := -6.0


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Look: player hurt", cam = &"first_person", slug = &"hurt", fn = func() -> void: await _hurt(bot)},
	]


static func _hurt(bot: Node) -> void:
	bot.caption.visible = false
	bot.god(false)
	bot.freeze_ai(true)
	var log_hit := func(hit: HitInfo) -> void:
		if hit.victim == bot.player:
			bot.log_line("HURT-HIT %s %.0f %s" % [CombatTypes.tier_name(hit.tier), hit.damage, str(hit.blocked)])
	CombatEvents.hit_landed.connect(log_hit)
	await bot._look_to(PITCH_DEG, 6)
	await bot._ticks(SETTLE_TICKS)
	for attack: Dictionary in ATTACKS:
		for side: Dictionary in SIDES:
			await _one(bot, attack, side)
	CombatEvents.hit_landed.disconnect(log_hit)
	bot.god(true)
	bot.clear_enemies()


## One attacker at `side`, throwing `attack`: the player takes it, gets up if it knocked him down, and rests.
static func _one(bot: Node, attack: Dictionary, side: Dictionary) -> void:
	var bearing := deg_to_rad(float(side.bearing))
	var distance: float = attack.distance
	var rel := Vector2(-sin(bearing) * distance, cos(bearing) * distance)
	var enemy: EnemyActor = bot.spawn(attack.id, rel)
	if enemy == null:
		return
	bot.player.health = bot.player.max_health
	enemy.max_health = 600.0
	enemy.health = 600.0
	await bot._ticks(SETTLE_TICKS)
	bot.log_line("HURT %s %s" % [attack.label, side.label])
	enemy.force_attack(int(attack.index))
	await bot._wait_until(func() -> bool: return enemy.state == CombatTypes.ActorState.WINDUP, WINDUP_MAX_TICKS)
	await bot._wait_until(func() -> bool: return enemy.current_move == null, MOVE_MAX_TICKS)
	await bot._wait_until(func() -> bool: return bot.player.state == CombatTypes.ActorState.FREE, FREE_MAX_TICKS)
	await bot._ticks(AFTER_TICKS)
	bot.clear_enemies()
	await bot._ticks(SETTLE_TICKS)
