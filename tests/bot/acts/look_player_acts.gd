extends RefCounted
## The player's own arms and legs in his own art (Milestone 4, F-player-int), for the crowd bot
## (tests/bot/crowd_bot.gd): the first-person view of the body he wears while he stands, looks down,
## strikes, kicks, blocks, holds an enemy, charges a haymaker and is knocked out, so the wiring, the
## layers and the hull are judged from the frames the lens draws, 0.3-0.6 m from his arms and legs.
## The title starts with "Look:" (the capture filter is a substring match: no title is inside another).
##
## The art. His GLB (assets/export/characters/player/player.glb, F-player-art's) does not exist yet,
## so the game still draws his primitives; Tuning's Debug value look_player_art_probe puts the probe
## body on him instead (a mannequin through the real chain: Body + Body__fp_hidden). It is read when
## the room builds his body, so record with it on, through the bot's argument:
##   CAPTURE_ARGS="--tune=look_player_art_probe=1" tools/capture_bot.sh res://tests/bot/crowd_bot.tscn \
##       captures/pa "Look: my arms and legs" 6
## (the same act without the argument records his primitives). The act prints
##   LOOK-PLAYER art <probe|hero|primitives> <triangles of the visible mesh>
## at its start, so a log says which body it recorded; then cut the stills and the crops with
##   tools/look_sheets.sh captures/pa/bot.avi captures/pa/sheets
##
## | Act | Title | Shows |
## | PA1 | Look: my arms and legs | idle level, looking 45 and 65 degrees down; at 20 down the chain jab, cross, hook, uppercut, the front kick, the block's guard, the spin kick, the haymaker's charge and its swing; a Punk held 1.1 m ahead and kneed; then his own KO: the lens leaves his eyes and shows the whole body |
##
## Every act of this file prints the marks and rectangles of look_rect.gd for the player (`hands` and
## `body` are the parts his lens draws). It hides the caption, freezes the AI, sets god mode (but for
## the KO at the end) and seeds the comic effects, as look_acts.gd's do.

const LookRect := preload("res://tests/bot/look_rect.gd")
const LookActs := preload("res://tests/bot/acts/look_acts.gd")

## The act's slug in the marks.
const SLUG := "pa1"
## The views (degrees, negative looks down): level, the plan's 45 and 65, and 20 where his arms and
## the strikes are in the picture (look_acts.gd's C8 finds the same).
const LEVEL_PITCH_DEG := 0.0
const DOWN_45_DEG := -45.0
const DOWN_65_DEG := -65.0
const ARMS_PITCH_DEG := -20.0
## Ticks to turn the view, to let a pose settle, between the presses of a chain, and how long a still
## pose is held before and after its mark (the guard, the charge).
const PITCH_TICKS := 15
const SETTLE_TICKS := 40
const CHAIN_GAP_TICKS := 8
const GUARD_TICKS := 40
const AFTER_MOVE_TICKS := 20
## The held Punk's distance (the combo bot's hold acts) and the Punk's reach for the KO's jab.
const HOLD_M := 1.1
const KO_PUNK_M := 0.95
## The player's health for the KO (one jab of the Punk's finishes it) and how long the KO's lens is
## watched once it is all the way out (the hold is 2 s: the stills are in it), and the most the
## view may take to get out.
const KO_HEALTH := 3.0
const KO_WATCH_TICKS := 150
const KO_OUT_MAX_TICKS := 240
const KO_BACK_MAX_TICKS := 600


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Look: my arms and legs", cam = &"first_person", slug = &"pa1", fn = func() -> void: await _arms_and_legs(bot)},
	]


## What the player wears: the hero's art, the probe body or his primitives, and the triangles of the
## visible mesh.
static func _art_name(bot: Node) -> String:
	var rig: HumanoidRig = bot.player.rig
	if not rig.has_art():
		return "primitives 0"
	var kind := "probe" if bot.player.rig.art.id == &"player_probe" else "hero"
	var triangles := 0
	for mesh: MeshInstance3D in rig.art_meshes():
		if mesh.name == &"ArtBody":
			triangles = (mesh.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
	return "%s %d" % [kind, triangles]


static func _begin(bot: Node) -> void:
	bot.caption.visible = false
	bot.god()
	bot.freeze_ai(true)
	bot.log_line("LOOK-PLAYER art %s" % _art_name(bot))
	var vfx := bot.get_tree().get_first_node_in_group(VfxDirector.GROUP) as VfxDirector
	if vfx:
		vfx.clear()
		vfx.rng.seed = LookActs.VFX_SEED


## The end of the act: the `end` mark and the caption back (the bot's own idle tail shows it).
static func _end(bot: Node) -> void:
	LookRect.mark(bot, SLUG, "end")
	bot.caption.visible = true


## One held look: turn the view to `pitch_deg`, let it settle, mark `label`.
static func _look(bot: Node, pitch_deg: float, label: String) -> void:
	await bot._look_to(pitch_deg, PITCH_TICKS)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, SLUG, label, bot.player)


static func _arms_and_legs(bot: Node) -> void:
	_begin(bot)
	LookRect.mark(bot, SLUG, "start")
	var run := {running = true}
	LookActs._watch(bot, SLUG, bot.player, run)
	# Standing: level, then looking down at his own legs and feet.
	await _look(bot, LEVEL_PITCH_DEG, "idle_level")
	await _look(bot, DOWN_45_DEG, "idle_down45")
	await _look(bot, DOWN_65_DEG, "idle_down65")
	# At 20 down his arms are in the view: the chain, the kick, the guard, the spin kick, the charge.
	await _look(bot, ARMS_PITCH_DEG, "idle_arms")
	for i in 4:
		await bot._press(&"P", 2, CHAIN_GAP_TICKS)
	await bot._wait_idle()
	await bot._ticks(AFTER_MOVE_TICKS)
	await bot._press(&"K", 2)
	await bot._wait_idle()
	await bot._ticks(AFTER_MOVE_TICKS)
	await bot._hold_block()
	await bot._ticks(GUARD_TICKS)
	LookRect.mark(bot, SLUG, "guard", bot.player)
	await bot._release_block()
	await bot._ticks(AFTER_MOVE_TICKS)
	await _spin_kick(bot)
	await _haymaker(bot)
	# A held enemy and the knee (the hold's own bend and view).
	await _hold_and_knee(bot)
	run.running = false
	await _ko(bot)
	_end(bot)


## Jump, then K at the apex: the spin kick turns the body and the view with it.
static func _spin_kick(bot: Node) -> void:
	await bot._press(&"JUMP", 2)
	await bot._wait_until(func() -> bool: return bot.player.sim_velocity.y < 1.0)
	await bot._press(&"K", 2)
	await bot._wait_idle()
	await bot._ticks(AFTER_MOVE_TICKS)


## Hold P past the haymaker's charge (marked once the charge is in its pose), then let go: the swing.
static func _haymaker(bot: Node) -> void:
	bot.player.input.push_press(&"P", Tuning.data.hold_frames + CHAIN_GAP_TICKS * 2)
	await bot._ticks(Tuning.data.hold_frames + CHAIN_GAP_TICKS)
	LookRect.mark(bot, SLUG, "haymaker_charge", bot.player)
	await bot._wait_idle()
	await bot._ticks(AFTER_MOVE_TICKS)


## A Punk HOLD_M ahead, held by the grab (the hold view tips down and in) and kneed once.
static func _hold_and_knee(bot: Node) -> void:
	var punk := LookActs._punk(bot, Vector2(0.0, HOLD_M))
	LookActs._survivor(punk)
	await bot._ticks(SETTLE_TICKS)
	await bot._press(&"GRAB", 2, 20)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, SLUG, "hold", bot.player)
	await bot._press(&"P", 2)
	await bot._wait_idle()
	await bot._ticks(CHAIN_GAP_TICKS)
	await bot._press(&"GRAB", 2, 15)
	await bot._wait_until(func() -> bool: return bot.player.state == CombatTypes.ActorState.FREE, 120)
	bot.clear_enemies()
	await bot._ticks(AFTER_MOVE_TICKS)


## His own KO: the view level, god mode off, the Punk's jab finishing him; the lens leaves his eyes
## (the KO view shows the whole body, the hidden upper half too), held a couple of seconds, marked
## when it is all the way out and once more through the hold.
static func _ko(bot: Node) -> void:
	await bot._look_to(LEVEL_PITCH_DEG, PITCH_TICKS)
	var punk := LookActs._punk(bot, Vector2(0.0, KO_PUNK_M))
	LookActs._survivor(punk)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, SLUG, "ko_before", bot.player)
	bot.god(false)
	bot.player.health = KO_HEALTH
	punk.force_attack(0)
	var camera: FirstPersonCamera = bot.director.get(&"first_person_camera")
	await bot._wait_until(func() -> bool: return camera.ko_view_weight() >= 1.0 and bot.player.is_ko(), KO_OUT_MAX_TICKS)
	LookRect.mark(bot, SLUG, "ko_view_out")
	await bot._ticks(KO_WATCH_TICKS / 2)
	LookRect.mark(bot, SLUG, "ko_view_held")
	await bot._ticks(KO_WATCH_TICKS / 2)
	bot.god(true)
	# He gets up (the room revives him) and the lens eases back into his eyes.
	await bot._wait_until(func() -> bool: return camera.ko_view_weight() <= 0.0 and not bot.player.is_ko() and bot.player.health > 0.0, KO_BACK_MAX_TICKS)
	await bot._ticks(AFTER_MOVE_TICKS)
	LookRect.mark(bot, SLUG, "ko_back_in_the_eyes", bot.player)
