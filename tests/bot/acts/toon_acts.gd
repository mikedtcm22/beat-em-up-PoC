extends RefCounted
## The toon look's own acts (Milestone 4, P1-toon) for the crowd bot (tests/bot/crowd_bot.gd): the
## primitive Punk, the dummies and the player's own limbs in first person, so the toon shader, the
## hull, the flash and the damage looks can be judged from the lens before and after (the plan's
## "before/after captures"). Every title starts "Look: toon". Record them with
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/<key> "Look: toon" 6
## (or one act: "Look: toon Punk at 1 m"). Each act hides the caption, freezes the AI, turns on god
## mode and seeds the comic effects' generator, so a before and an after are the same frames. All
## motion is scripted. The 1 m recipe is the plan's: `bot.spawn(&"punk", Vector2(0, 1.0))`, the
## face shot 8 degrees up.
##
## | Act | Shows |
## | Look: toon Punk at 1 m | the Punk 1 m ahead at the default look, then 8 degrees up for the face |
## | Look: toon Punk at 3 m | the same at 3 m |
## | Look: toon dummies | two dummies, two Punks and the pipe on the street at 1 to 3 m |
## | Look: toon hit and damage | a jab (flinch and contact flash), then the bruised and bloodied looks, then the parry flash |
## | Look: toon own limbs | the player's own arms looking 20 degrees down: jab, cross, guard |
## | Look: toon halftone | a Punk and a dummy with the halftone dots switched on, live, on the room and the characters |
## | Look: toon art fixture | the procedural skinned art fixture (tests/fixtures/toon_art_probe.gd) in the art's toon material, its hull and its detail mask: bent, marked, flashed |

const ArtProbe := preload("res://tests/fixtures/toon_art_probe.gd")
const DUMMY_SCENE := "res://game/enemies/dummy/training_dummy.tscn"

## Distances (m) of the Punk, in front of the lens.
const CLOSE_M := 1.0
const FAR_M := 3.0
## The look: pitch of the face shot, the bot's default look, and the look down at the own limbs (degrees).
const FACE_PITCH_DEG := 8.0
const DEFAULT_PITCH_DEG := -6.0
const LIMBS_PITCH_DEG := -20.0
## Ticks to turn the view, to let a spawned body settle, to hold a look (1.5 s) and a health look (1 s).
const PITCH_TICKS := 10
const SETTLE_TICKS := 30
const HOLD_TICKS := 90
const HEALTH_HOLD_TICKS := 60
## The comic effects' generator seed, so two recordings of the same act match.
const VFX_SEED := 4242
## The Punk's health for the damage looks: enough to take the jab.
const SURVIVOR_HEALTH := 100.0
const HEALTH_SHARES: Array[float] = [1.0, 0.65, 0.3]
## The art fixture: where it stands (x right, y ahead, m), how far its tip bends each way (degrees)
## over how many ticks, and how long each damage look is held (0.75 s).
const FIXTURE_REL := Vector2(0.0, 2.3)
const FIXTURE_BENDS_DEG: Array[float] = [70.0, -50.0, 0.0]
const FIXTURE_BEND_TICKS := 45
const FIXTURE_HOLD_TICKS := 45
## The pipe on the street: ahead, just inside the view's lowest ray (x right, y ahead, m) and its height.
const PIPE_REL := Vector2(0.1, 2.4)
const PIPE_HEIGHT_M := 0.2


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Look: toon Punk at 1 m", cam = &"first_person", fn = func() -> void: await _punk_at(bot, CLOSE_M, true)},
		{title = "Look: toon Punk at 3 m", cam = &"first_person", fn = func() -> void: await _punk_at(bot, FAR_M, false)},
		{title = "Look: toon dummies", cam = &"first_person", fn = func() -> void: await _dummies(bot)},
		{title = "Look: toon hit and damage", cam = &"first_person", fn = func() -> void: await _hit_and_damage(bot)},
		{title = "Look: toon own limbs", cam = &"first_person", fn = func() -> void: await _own_limbs(bot)},
		{title = "Look: toon halftone", cam = &"first_person", fn = func() -> void: await _halftone(bot)},
		{title = "Look: toon art fixture", cam = &"first_person", fn = func() -> void: await _art_fixture(bot)},
	]


## The start of every act: the caption hidden, god mode, the AI frozen, the comic effects seeded.
static func _begin(bot: Node) -> void:
	bot.caption.visible = false
	bot.god()
	bot.freeze_ai(true)
	var vfx := bot.get_tree().get_first_node_in_group(VfxDirector.GROUP) as VfxDirector
	if vfx:
		vfx.clear()
		vfx.rng.seed = VFX_SEED


## The end of every act: the caption back.
static func _end(bot: Node) -> void:
	bot.caption.visible = true


static func _punk_at(bot: Node, distance_m: float, face: bool) -> void:
	_begin(bot)
	bot.spawn(&"punk", Vector2(0.0, distance_m))
	await bot._ticks(SETTLE_TICKS)
	await bot._ticks(HOLD_TICKS)
	if face:
		await bot._look_to(FACE_PITCH_DEG, PITCH_TICKS)
		await bot._ticks(HOLD_TICKS)
		await bot._look_to(DEFAULT_PITCH_DEG, PITCH_TICKS)
	_end(bot)


## A training dummy standing `rel` (x right, y ahead, m) from the player, facing him (the crowd
## room's spawner makes AI enemies only, so the scene is placed by hand, as the training room does).
static func _dummy_at(bot: Node, rel: Vector2) -> TrainingDummy:
	var dummy := (load(DUMMY_SCENE) as PackedScene).instantiate() as TrainingDummy
	bot.room.add_child(dummy)
	var at: Vector3 = bot.player.global_position + bot.player.global_basis * Vector3(rel.x, 0.0, -rel.y)
	var to_player: Vector3 = bot.player.global_position - at
	dummy.set_post(at, atan2(-to_player.x, -to_player.z), true)
	return dummy


static func _dummies(bot: Node) -> void:
	_begin(bot)
	var dummies: Array[TrainingDummy] = [_dummy_at(bot, Vector2(-0.55, 1.1)), _dummy_at(bot, Vector2(0.0, 3.0))]
	bot.spawn(&"punk", Vector2(0.5, 1.3))
	bot.spawn(&"punk", Vector2(-1.6, 3.2))
	var pipe := Weapon.new()
	bot.room.add_child(pipe)
	pipe.global_position = bot.player.global_position + bot.player.global_basis * Vector3(PIPE_REL.x, PIPE_HEIGHT_M, -PIPE_REL.y)
	await bot._ticks(SETTLE_TICKS)
	await bot._ticks(HOLD_TICKS)
	await bot._look_to(FACE_PITCH_DEG, PITCH_TICKS)
	await bot._ticks(HOLD_TICKS)
	await bot._look_to(DEFAULT_PITCH_DEG, PITCH_TICKS)
	pipe.queue_free()
	for dummy: TrainingDummy in dummies:
		dummy.queue_free()
	_end(bot)


static func _hit_and_damage(bot: Node) -> void:
	_begin(bot)
	var punk: EnemyActor = bot.spawn(&"punk", Vector2(0.0, CLOSE_M))
	punk.max_health = SURVIVOR_HEALTH
	punk.health = SURVIVOR_HEALTH
	await bot._ticks(SETTLE_TICKS)
	await bot._press(&"P", 2, 8)
	await bot._ticks(HOLD_TICKS)
	for share: float in HEALTH_SHARES:
		punk.health = punk.max_health * share
		CombatEvents.health_changed.emit(punk, punk.health, punk.max_health)
		await bot._ticks(HEALTH_HOLD_TICKS)
	# The whole-body parry flash, as a perfect block gives the defender.
	punk.rig.set_flash(1.0, CombatActor.PARRY_FLASH_COLOR)
	await bot._ticks(6)
	punk.rig.set_flash(0.0)
	await bot._ticks(HEALTH_HOLD_TICKS)
	_end(bot)


static func _own_limbs(bot: Node) -> void:
	_begin(bot)
	await bot._look_to(LIMBS_PITCH_DEG, PITCH_TICKS)
	await bot._ticks(SETTLE_TICKS)
	await bot._press(&"P", 2, 20)
	await bot._press(&"P", 2, 20)
	await bot._wait_idle()
	await bot._hold_block()
	await bot._ticks(HOLD_TICKS)
	await bot._release_block()
	await bot._ticks(SETTLE_TICKS)
	await bot._look_to(DEFAULT_PITCH_DEG, PITCH_TICKS)
	_end(bot)


## The halftone dots on (the room's and the characters'), for a look at them: they are off by
## default (the look bible), and an act's tunables are put back at the next act.
static func _halftone(bot: Node) -> void:
	_begin(bot)
	bot.spawn(&"punk", Vector2(0.4, 1.6))
	var dummy := _dummy_at(bot, Vector2(-0.8, 2.2))
	bot.tune(&"look_halftone_env", true)
	bot.tune(&"look_halftone_chars", true)
	bot.tune(&"look_halftone_strength", 0.6)
	await bot._ticks(SETTLE_TICKS)
	await bot._ticks(HOLD_TICKS)
	dummy.queue_free()
	_end(bot)


## The art fixture standing 2.3 m ahead: bent through a few angles (the hull and the marks must
## follow the skin), then bruised, bloodied and flashed.
static func _art_fixture(bot: Node) -> void:
	_begin(bot)
	var material := ToonMaterials.art(ArtProbe.atlas(), ArtProbe.mask())
	var skeleton := ArtProbe.build(bot.room, material, ToonMaterials.outline())
	skeleton.global_position = bot.player.global_position + bot.player.global_basis * Vector3(FIXTURE_REL.x, 0.0, -FIXTURE_REL.y)
	skeleton.global_rotation.y = bot.player.rotation.y
	var tip := skeleton.find_bone(ArtProbe.TIP_BONE)
	# The warm-up has run at the room's load; run it again with the skinned fixture, to draw the
	# art's variant (a skin, the custom channels, the hull) once under a window.
	ToonMaterials._warmed = false
	ToonMaterials.warm_up(bot.room, skeleton)
	await bot._ticks(SETTLE_TICKS)
	await bot._ticks(HOLD_TICKS)
	var from := 0.0
	for bend: float in FIXTURE_BENDS_DEG:
		for step in FIXTURE_BEND_TICKS:
			await bot.get_tree().physics_frame
			var angle := lerpf(from, bend, float(step + 1) / float(FIXTURE_BEND_TICKS))
			skeleton.set_bone_pose_rotation(tip, Quaternion(Vector3.RIGHT, deg_to_rad(angle)))
		from = bend
		await bot._ticks(FIXTURE_HOLD_TICKS)
	for level: int in [DamageLook.Level.BRUISED, DamageLook.Level.BLOODIED]:
		DamageLook.apply_art(material, level)
		await bot._ticks(FIXTURE_HOLD_TICKS)
	skeleton.set_bone_pose_rotation(tip, Quaternion(Vector3.RIGHT, deg_to_rad(FIXTURE_BENDS_DEG[0])))
	material.set_shader_parameter(&"flash_color", Color.CYAN)
	material.set_shader_parameter(&"flash_amount", 1.0)
	await bot._ticks(FIXTURE_HOLD_TICKS)
	skeleton.queue_free()
	_end(bot)
