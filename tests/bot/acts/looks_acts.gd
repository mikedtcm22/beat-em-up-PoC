extends RefCounted
## The Milestone 6 LOOKS acts (D6 and D4), for the A/B stills Game-boy judges. The crowd bot loads this file by name; every
## title starts with "Look:". Record one act per process:
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/looks/cap "Look: bloodied cap" 6
##
## | Act | Title | Shows |
## | LK1 | Look: bloodied cap at 1 m | one Punk 1 m ahead at 20% health, the view 8 degrees up on the cap and face: first M4's marks (`look_marks_per_swatch` off: the soft blood tile on the cap), then M6's (per swatch: scuffs on the cap, a hard-edged blood on the vest and the skin) |
## | LK2 | Look: veteran beside the Punk | a Punk and a Veteran Punk side by side at 1 m, then at 5 m, clean and then bloodied, the view level |

const SETTLE_TICKS := 40
const HOLD_TICKS := 100
const CAP_PITCH_DEG := 8.0
const LEVEL_PITCH_DEG := 0.0
const PITCH_TICKS := 10
const SURVIVOR_HEALTH := 5000.0
const VFX_SEED := 7


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Look: bloodied cap at 1 m", cam = &"first_person", slug = &"lk1", fn = func() -> void: await _cap(bot)},
		{title = "Look: veteran beside the Punk", cam = &"first_person", slug = &"lk2", fn = func() -> void: await _veteran(bot)},
	]


static func _begin(bot: Node) -> void:
	bot.god()
	bot.freeze_ai(true)
	var vfx := bot.get_tree().get_first_node_in_group(VfxDirector.GROUP) as VfxDirector
	if vfx:
		vfx.clear()
		vfx.rng.seed = VFX_SEED


## Set `enemy`'s health to `share` of its maximum and tell the damage look (the director's own listener).
static func _health(enemy: EnemyActor, share: float) -> void:
	enemy.health = enemy.max_health * share
	CombatEvents.health_changed.emit(enemy, enemy.health, enemy.max_health)


static func _survivor(enemy: EnemyActor) -> void:
	enemy.max_health = SURVIVOR_HEALTH
	enemy.health = SURVIVOR_HEALTH


static func _cap(bot: Node) -> void:
	_begin(bot)
	var punk: EnemyActor = bot.spawn(&"punk", Vector2(0.0, 1.0))
	_survivor(punk)
	await bot._look_to(CAP_PITCH_DEG, PITCH_TICKS)
	await bot._ticks(SETTLE_TICKS)
	_health(punk, 0.2)
	for per_swatch: bool in [false, true]:
		bot.tune(&"look_marks_per_swatch", per_swatch)
		bot.caption.text = "Look: bloodied cap, %s" % ("M6 per swatch (cap scuffs only, hard-edged blood)" if per_swatch else "M4 (the soft blood tile on the cap)")
		bot.log_line("LOOKS cap per_swatch=%s" % per_swatch)
		await bot._ticks(HOLD_TICKS)


static func _veteran(bot: Node) -> void:
	_begin(bot)
	await bot._look_to(LEVEL_PITCH_DEG, PITCH_TICKS)
	for distance: float in [1.0, 5.0]:
		bot.clear_enemies()
		var half := distance * 0.32
		var punk: EnemyActor = bot.spawn(&"punk", Vector2(-half, distance))
		var vet: EnemyActor = bot.spawn(&"punk_veteran", Vector2(half, distance))
		_survivor(punk)
		_survivor(vet)
		for share: float in [1.0, 0.2]:
			_health(punk, share)
			_health(vet, share)
			bot.caption.text = "Look: veteran (right) beside the Punk (left), %.0f m, health %.0f%%" % [distance, share * 100.0]
			bot.log_line("LOOKS veteran d=%.0f share=%.1f" % [distance, share])
			await bot._ticks(SETTLE_TICKS + 20)
