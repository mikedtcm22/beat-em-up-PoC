extends RefCounted
## FB-FEEL's acts (M6 playtest feedback; FIX-FEEL extended them): "Look: player hurt" and its three
## companions. The player stands still in first person (god mode off, health refilled before each attack so
## the damage is real and he is not KO'd) and:
##  - "Look: player hurt": a Punk, a Kicker and a Bruiser each throw one attack at him from the front, the
##    left, the right and behind, one after another (a jab, a jump kick, a smash: LIGHT and HEAVY);
##  - "Look: player hurt finishers": FINISHER-tier hits, from the front, the right and behind: a Punk's
##    shove and the Thug's pipe combo, whose third swing is the Pipe Smash (the 7 degree roll);
##  - "Look: player hurt blocked": his guard held, a Punk's jab and a Bruiser's smash from the front: the
##    light feel of M6 (the vignette at hurt_overlay_blocked_scale, no strokes, no roll);
##  - "Look: player hurt burst": three Punks at once, front, right and left, the last with the shove,
##    real damage, the view's stack of three in a row;
##  - "Look: player hurt rear run": VF2-FEEL: three Bruiser smashes in a row from behind, then the Thug's pipe
##    combo from behind (three swings), each hit on a rested player: the vignette's depth must stay at the
##    first hit's (it deepened with every rear hit before), the bottom strokes no longer than a front hit's;
##  - "Look: player hurt looking down": the player looks down about 45 degrees (as at a stomp) and takes a
##    Punk's jab from behind, the left and the front (VFIX-FEEL: the edge must follow the floor-plane side
##    at any pitch, the bottom edge from behind readable on the pale ground).
## The edge and the roll come from the attacker's side (hit_bearing). The recording judges what the view
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
## The heaviest attacks: `settle` is how many ticks a chain keeps swinging.
## No enemy move is FINISHER tier (A2.13), so the finisher's view is judged with `synthetic` ones: the
## Bruiser's smash as a FINISHER-tier hit applied to the player (damage and reaction as the smash's), logged
## "synthetic". The real heaviest enemy hits come first: the Punk's shove and the Thug's three pipe swings.
const FINISHERS: Array[Dictionary] = [
	{id = &"punk", index = 1, distance = 0.85, label = "punk shove", settle = 0},
	{id = &"thug", index = 0, distance = 1.0, label = "thug pipe combo", settle = 120},
	{id = &"bruiser", index = 0, distance = 1.2, label = "synthetic finisher (the smash as FINISHER tier)",
			settle = 0, synthetic = true},
]
## The attacks thrown at a held guard.
const BLOCKED: Array[Dictionary] = [
	{id = &"punk", index = 0, distance = 1.0, label = "punk jab", settle = 0},
	{id = &"bruiser", index = 0, distance = 1.2, label = "bruiser smash", settle = 0},
]
## The burst: three Punks (bearing in degrees, attack index, distance in metres, the ticks after the first
## at which it attacks): a jab ahead, a jab from the right, a shove from the left, all forced on one tick (a staggered player is
## out of reach of the later swings: staggering them apart landed only two hits, so `delay` stays 0).
const BURST: Array[Dictionary] = [
	{bearing = 0.0, index = 0, distance = 1.0, delay = 0, label = "ahead"},
	{bearing = 300.0, index = 0, distance = 1.0, delay = 0, label = "right"},
	{bearing = 60.0, index = 1, distance = 0.85, delay = 0, label = "left"},
]
## The bearings (degrees off the player's view: 0 ahead, 90 to his left, 180 behind) and their names.
const SIDES: Array[Dictionary] = [
	{bearing = 0.0, label = "front"},
	{bearing = 90.0, label = "left"},
	{bearing = 270.0, label = "right"},
	{bearing = 180.0, label = "behind"},
]
## The sides of the finisher acts.
const FINISHER_SIDES: Array[Dictionary] = [
	{bearing = 0.0, label = "front"},
	{bearing = 270.0, label = "right"},
	{bearing = 180.0, label = "behind"},
]
const SETTLE_TICKS := 30
const WINDUP_MAX_TICKS := 40
const MOVE_MAX_TICKS := 240
const FREE_MAX_TICKS := 240
const AFTER_TICKS := 40
## A pitch a little under level, as the default view of the look acts.
const PITCH_DEG := -6.0
## The pitch of "Look: player hurt looking down": about what a stomp on a downed enemy looks at.
const DOWN_PITCH_DEG := -45.0
## "Look: player hurt rear run": the heavy attacks from behind, in order, with how many times each lands.
const REAR_RUN: Array[Dictionary] = [
	{id = &"bruiser", index = 0, distance = 1.2, label = "bruiser smash", settle = 0, times = 3},
	{id = &"thug", index = 0, distance = 1.0, label = "thug pipe combo", settle = 120, times = 1},
]
## The sides of the looking-down act: behind first (the one that read as ahead), then the left and the front.
const DOWN_SIDES: Array[Dictionary] = [
	{bearing = 180.0, label = "behind"},
	{bearing = 90.0, label = "left"},
	{bearing = 0.0, label = "front"},
]


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Look: player hurt", cam = &"first_person", slug = &"hurt", fn = func() -> void: await _hurt(bot)},
		{title = "Look: player hurt finishers", cam = &"first_person", slug = &"hurt_finishers",
				fn = func() -> void: await _finishers(bot)},
		{title = "Look: player hurt blocked", cam = &"first_person", slug = &"hurt_blocked",
				fn = func() -> void: await _blocked(bot)},
		{title = "Look: player hurt burst", cam = &"first_person", slug = &"hurt_burst",
				fn = func() -> void: await _burst(bot)},
		{title = "Look: player hurt rear run", cam = &"first_person", slug = &"hurt_rear",
				fn = func() -> void: await _rear_run(bot)},
		{title = "Look: player hurt looking down", cam = &"first_person", slug = &"hurt_down",
				fn = func() -> void: await _looking_down(bot)},
	]


static func _hurt(bot: Node) -> void:
	var log_hit := await _begin(bot)
	for attack: Dictionary in ATTACKS:
		for side: Dictionary in SIDES:
			await _one(bot, attack, side)
	_end(bot, log_hit)


## Heavy blows from behind, one after another (VF2-FEEL: the vignette's depth must not compound).
static func _rear_run(bot: Node) -> void:
	var log_hit := await _begin(bot)
	var behind: Dictionary = SIDES[3]
	for attack: Dictionary in REAR_RUN:
		for i: int in int(attack.times):
			await _one(bot, attack, behind)
	_end(bot, log_hit)


## The Punk's jab from behind, the left and the front, with the player looking down 45 degrees.
static func _looking_down(bot: Node) -> void:
	var log_hit := await _begin(bot, DOWN_PITCH_DEG)
	for side: Dictionary in DOWN_SIDES:
		await _one(bot, ATTACKS[0], side)
	_end(bot, log_hit)


static func _finishers(bot: Node) -> void:
	var log_hit := await _begin(bot)
	for attack: Dictionary in FINISHERS:
		for side: Dictionary in FINISHER_SIDES:
			await _one(bot, attack, side)
	_end(bot, log_hit)


## Guard held (the held block: DODGE) for each attack, released after it.
static func _blocked(bot: Node) -> void:
	var log_hit := await _begin(bot)
	var front: Dictionary = SIDES[0]
	for attack: Dictionary in BLOCKED:
		await bot._hold_block()
		await _one(bot, attack, front)
		await bot._release_block()
		await bot._ticks(SETTLE_TICKS)
	_end(bot, log_hit)


## Three Punks forced to attack on one tick, from three sides, at real damage.
static func _burst(bot: Node) -> void:
	var log_hit := await _begin(bot)
	for round_index: int in 2:
		var enemies: Array[EnemyActor] = []
		for part: Dictionary in BURST:
			var bearing := deg_to_rad(float(part.bearing))
			var rel := Vector2(-sin(bearing), cos(bearing)) * float(part.distance)
			var enemy: EnemyActor = bot.spawn(&"punk", rel)
			if enemy != null:
				enemy.max_health = 600.0
				enemy.health = 600.0
				enemies.append(enemy)
		bot.player.health = bot.player.max_health
		await bot._ticks(SETTLE_TICKS)
		bot.log_line("HURT burst %d" % round_index)
		var elapsed := 0
		for i: int in enemies.size():
			await bot._ticks(int(BURST[i].delay) - elapsed)
			elapsed = int(BURST[i].delay)
			enemies[i].force_attack(int(BURST[i].index))
		await bot._ticks(MOVE_MAX_TICKS)
		await bot._wait_until(func() -> bool: return bot.player.state == CombatTypes.ActorState.FREE, FREE_MAX_TICKS)
		await bot._ticks(AFTER_TICKS)
		bot.clear_enemies()
		await bot._ticks(SETTLE_TICKS)
	_end(bot, log_hit)


## God mode off, the AI frozen, the hits taken logged, the view a little under level. Returns the logger.
static func _begin(bot: Node, pitch_deg: float = PITCH_DEG) -> Callable:
	bot.caption.visible = false
	bot.god(false)
	bot.freeze_ai(true)
	var log_hit := func(hit: HitInfo) -> void:
		if hit.victim == bot.player:
			bot.log_line("HURT-HIT %s %.0f %s" % [CombatTypes.tier_name(hit.tier), hit.damage, str(hit.blocked)])
	CombatEvents.hit_landed.connect(log_hit)
	await bot._look_to(pitch_deg, 6)
	await bot._ticks(SETTLE_TICKS)
	return log_hit


static func _end(bot: Node, log_hit: Callable) -> void:
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
	if attack.get("synthetic", false):
		_synthetic_finisher(bot, enemy)
		await bot._wait_until(func() -> bool: return bot.player.state == CombatTypes.ActorState.FREE, FREE_MAX_TICKS)
		await bot._ticks(AFTER_TICKS)
		bot.clear_enemies()
		await bot._ticks(SETTLE_TICKS)
		return
	enemy.force_attack(int(attack.index))
	await bot._wait_until(func() -> bool: return enemy.state == CombatTypes.ActorState.WINDUP, WINDUP_MAX_TICKS)
	await bot._wait_until(func() -> bool: return enemy.current_move == null, MOVE_MAX_TICKS)
	await bot._ticks(int(attack.get("settle", 0)))
	await bot._wait_until(func() -> bool: return bot.player.state == CombatTypes.ActorState.FREE, FREE_MAX_TICKS)
	await bot._ticks(AFTER_TICKS)
	bot.clear_enemies()
	await bot._ticks(SETTLE_TICKS)


## The Bruiser's smash landed on the player as a FINISHER-tier hit (the view's biggest stack: no enemy move
## is one), through receive_hit() and the event, as HitDetector would.
static func _synthetic_finisher(bot: Node, enemy: EnemyActor) -> void:
	var move := (load("res://game/combat/moves/bruiser_smash.tres") as MoveData).duplicate() as MoveData
	move.tier = CombatTypes.HitTier.FINISHER
	var hit := HitInfo.new()
	hit.attacker = enemy
	hit.victim = bot.player
	hit.move = move
	hit.damage = move.damage
	hit.tier = move.tier
	hit.reaction = move.reaction
	hit.region = CombatTypes.Region.TORSO
	var radial: Vector3 = bot.player.global_position - enemy.global_position
	radial.y = 0.0
	hit.direction = radial.normalized()
	hit.knockback = radial.normalized() * move.knockback.z + Vector3.UP * move.knockback.y
	hit.contact_point = bot.player.global_position + Vector3(0.0, 1.3, 0.0) - hit.direction * 0.2
	hit.physics_frame = Engine.get_physics_frames()
	if bot.player.receive_hit(hit):
		CombatEvents.hit_landed.emit(hit)
