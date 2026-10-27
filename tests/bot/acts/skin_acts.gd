extends RefCounted
## The skinned-art acts (P1-skin), in the crowd room: a Street Punk wearing the procedural probe
## art (tests/fixtures/skin_punk.gd: the primitives' own geometry baked into one skinned mesh,
## authored in an A-pose and weighted with blends) stands 1.5 m from the player and goes through
## what the art has to follow exactly: idle, the jab and cross, a stagger (the partial ragdoll),
## a knockdown with its get-up (the full one), and a KO whose rig blinks off and in. In first
## person and from the side (where the skeleton and the ragdoll's gap would show). Record with
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/skin "Look: skin probe" 6
## then tile the stills. The third act is the first with the art off, the primitives the art
## stands in for: its frames are the first act's, at the same offsets, to put side by side.

const SkinPunk := preload("res://tests/fixtures/skin_punk.tscn")
## How far (m) ahead of the player the Punk stands.
const DISTANCE_M := 1.5
## The Punk's health in the acts that hit it: enough to take every reaction in turn.
const HEALTH := 500.0


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Look: skin probe", cam = &"first_person", fn = func() -> void: await _probe(bot)},
		{title = "Look: skin probe (side view)", cam = &"side_view", fn = func() -> void: await _probe(bot)},
		# The same act with the art off (Tuning's look_show_art, the live A/B): the primitives the art
		# stands in for, frame for frame the same timeline, to lay beside the first one.
		{title = "Look: skin probe (primitives)", cam = &"first_person", fn = func() -> void:
			bot.tune(&"look_show_art", false)
			await _probe(bot)},
	]


static func _probe(bot: Node) -> void:
	bot.god()
	bot.freeze_ai(true)
	bot.spawner.scene_override[&"punk"] = SkinPunk
	var punk: EnemyActor = bot.spawn(&"punk", Vector2(0.0, DISTANCE_M))
	bot.spawner.scene_override.erase(&"punk")
	punk.max_health = HEALTH
	punk.health = HEALTH
	var rig: HumanoidRig = punk.rig
	bot.log_line("SKIN probe: has_art=%s meshes=%d" % [rig.has_art(), rig.art_meshes().size()])
	# Idle: the breathing guard.
	await bot._ticks(90)
	# The jab and the cross, as the AI throws them.
	punk.force_attack()
	await bot._wait_until(func() -> bool: return punk.current_move == null and punk.state == CombatTypes.ActorState.FREE, 300)
	await bot._ticks(40)
	# A stagger: the partial ragdoll on the upper body.
	_hit(punk, bot.player, CombatTypes.Reaction.STAGGER, Vector3(0.0, 0.0, 2.5))
	await bot._ticks(20)
	bot.log_line("SKIN stagger: ragdolling=%s" % rig.is_ragdolling())
	await bot._wait_until(func() -> bool: return punk.state == CombatTypes.ActorState.FREE, 300)
	await bot._ticks(30)
	# A knockdown and the get-up: the full ragdoll, then the animation again.
	_hit(punk, bot.player, CombatTypes.Reaction.KNOCKDOWN, Vector3(0.0, 2.0, 5.0))
	await bot._ticks(30)
	bot.log_line("SKIN knockdown: ragdolling=%s" % rig.is_ragdolling())
	await bot._wait_until(func() -> bool: return punk.state == CombatTypes.ActorState.FREE, 600)
	await bot._ticks(40)
	# A KO's blink: the rig shows and hides, the art with it.
	_hit(punk, bot.player, CombatTypes.Reaction.KNOCKDOWN, Vector3(0.0, 0.0, 3.0), 1000.0)
	await bot._ticks(80)
	for i in 3:
		rig.set_shown(false)
		await bot._ticks(8)
		rig.set_shown(true)
		await bot._ticks(14)
	await bot._ticks(30)


## A synthetic hit on `victim` from `attacker` (a push of `knockback` along the attacker's
## view, in the victim's frame toward the attacker's away direction).
static func _hit(victim: EnemyActor, attacker: Node3D, reaction: CombatTypes.Reaction, knockback: Vector3, damage: float = 1.0) -> void:
	var hit := HitInfo.new()
	hit.attacker = attacker
	hit.victim = victim
	hit.damage = damage
	hit.tier = CombatTypes.HitTier.HEAVY
	hit.reaction = reaction
	hit.region = CombatTypes.Region.HEAD
	var away := (victim.global_position - attacker.global_position)
	away.y = 0.0
	hit.direction = away.normalized()
	hit.knockback = Vector3(hit.direction.x * knockback.z, knockback.y, hit.direction.z * knockback.z)
	hit.contact_point = victim.rig.get_point_position(&"Head") - hit.direction * 0.15
	hit.physics_frame = Engine.get_physics_frames()
	victim.receive_hit(hit)
