extends RefCounted
## The static-prop acts of Milestone 6 (PROPS) for the crowd bot (tests/bot/crowd_bot.gd): every rigid model as the lens sees it, so a
## change of art, palette or hull is judged from the same frames before and after. Titles start with "Look: props". Record with
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/props "Look: props" 6
## (or one act: "Look: props hull A/B"). Each act hides the caption, freezes the AI and turns on god mode, and prints through look_rect.gd
##   LOOK-MARK p<n> f<frame> <label>      a frame worth a still; `start` and `end` delimit the act
##
## | Act | Title | Shows |
## | p1 | Look: props at 1 m and 5 m | the car, dumpster, AC unit and water tank, each side-on with its near face 1 m, then 5 m from the lens |
## | p2 | Look: props hull A/B | the car and the tank at 5 m with the baked-smooth-normal hull, then with the screen edge pass's lines alone (Debug prop_art_hull) |
## | p3 | Look: props weapons | the pipe and the bike chain, lying on the street at 0.8 m and held upright at 1 m, then the Thug's pipe in its hand at 1.4 m |

const LookRect := preload("res://tests/bot/look_rect.gd")
const PROP_IDS: Array[StringName] = [&"car", &"dumpster", &"ac_unit", &"water_tank"]
const DISTANCES_M: Array[float] = [1.0, 5.0]
const SETTLE_TICKS := 20
const HOLD_TICKS := 45
const LEVEL_PITCH_DEG := -6.0
const PITCH_TICKS := 6
## The weapons' art scenes (game/weapons/art/<id>.tscn) the third act draws, and the player's eye height above his feet it stands them at (m).
const WEAPON_IDS: Array[StringName] = [&"pipe", &"bike_chain"]
const UPRIGHT_HEIGHT_M := 1.25
const LYING_DISTANCE_M := 0.8
const UPRIGHT_DISTANCE_M := 1.0
const THUG_DISTANCE_M := 1.4


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Look: props at 1 m and 5 m", cam = &"first_person", slug = &"p1", fn = func() -> void: await _distances(bot)},
		{title = "Look: props hull A/B", cam = &"first_person", slug = &"p2", fn = func() -> void: await _hull(bot)},
		{title = "Look: props weapons", cam = &"first_person", slug = &"p3", fn = func() -> void: await _weapons(bot)},
	]


static func _begin(bot: Node) -> void:
	bot.caption.visible = false
	bot.god()
	bot.freeze_ai(true)


static func _end(bot: Node, slug: String) -> void:
	LookRect.mark(bot, slug, "end")
	bot.caption.visible = true


## A prop scene `id` standing on the street with its near face `distance_m` from the lens, side-on (its X along the player's right).
static func _place(bot: Node, id: StringName, distance_m: float) -> Node3D:
	var prop := (load("res://game/level/props/%s.tscn" % id) as PackedScene).instantiate() as Node3D
	bot.room.add_child(prop)
	var art := prop as StaticArt
	var depth := art.bounds().size.z if art != null else 1.0
	var player: Node3D = bot.player
	prop.global_transform = Transform3D(player.global_basis, player.global_position + player.global_basis * Vector3(0.0, 0.0, -(distance_m + depth * 0.5)))
	return prop


static func _distances(bot: Node) -> void:
	_begin(bot)
	await bot._look_to(LEVEL_PITCH_DEG, PITCH_TICKS)
	LookRect.mark(bot, "p1", "start")
	for id: StringName in PROP_IDS:
		for distance: float in DISTANCES_M:
			var prop := _place(bot, id, distance)
			await bot._ticks(SETTLE_TICKS)
			await bot._ticks(HOLD_TICKS - SETTLE_TICKS)
			LookRect.mark(bot, "p1", "%s_%sm" % [id, str(distance).replace(".", "_")])
			prop.queue_free()
			await bot._ticks(2)
	_end(bot, "p1")


static func _hull(bot: Node) -> void:
	_begin(bot)
	await bot._look_to(LEVEL_PITCH_DEG, PITCH_TICKS)
	LookRect.mark(bot, "p2", "start")
	var was: bool = Tuning.data.prop_art_hull
	for hull_on: bool in [true, false]:
		Tuning.set_value(&"prop_art_hull", hull_on)
		for id: StringName in [&"car", &"water_tank"]:
			var prop := _place(bot, id, 5.0)
			await bot._ticks(HOLD_TICKS)
			LookRect.mark(bot, "p2", "%s_hull_%s" % [id, "on" if hull_on else "off"])
			prop.queue_free()
			await bot._ticks(2)
	Tuning.set_value(&"prop_art_hull", was)
	_end(bot, "p2")


## A weapon scene `id` (game/weapons/art/<id>.tscn as its art) as a frozen Weapon: lying on the street, or upright in front of the lens.
static func _weapon(bot: Node, id: StringName, upright: bool) -> Weapon:
	var weapon := Weapon.new()
	weapon.art_scene = load("res://game/weapons/art/%s.tscn" % id) as PackedScene
	bot.room.add_child(weapon)
	weapon.freeze = true
	var player: Node3D = bot.player
	var forward := player.global_basis * Vector3(0.0, 0.0, -(UPRIGHT_DISTANCE_M if upright else LYING_DISTANCE_M))
	var lift := Vector3.UP * (UPRIGHT_HEIGHT_M if upright else weapon.radius * 2.0)
	weapon.global_position = player.global_position + forward + lift
	# Upright is the art frame as it is (long axis +Y); lying, on its side along the player's right.
	weapon.global_basis = player.global_basis if upright else player.global_basis * Basis(Vector3.BACK, PI * 0.5)
	return weapon


static func _weapons(bot: Node) -> void:
	_begin(bot)
	await bot._look_to(LEVEL_PITCH_DEG, PITCH_TICKS)
	LookRect.mark(bot, "p3", "start")
	for id: StringName in WEAPON_IDS:
		for upright: bool in [true, false]:
			if not upright:
				await bot._look_to(-40.0, PITCH_TICKS)
			var weapon := _weapon(bot, id, upright)
			await bot._ticks(HOLD_TICKS)
			LookRect.mark(bot, "p3", "%s_%s" % [id, "upright" if upright else "lying"])
			weapon.queue_free()
			await bot._ticks(2)
			await bot._look_to(LEVEL_PITCH_DEG, PITCH_TICKS)
	bot.spawn(&"thug", Vector2(0.0, THUG_DISTANCE_M))
	await bot._ticks(HOLD_TICKS)
	LookRect.mark(bot, "p3", "thug_pipe")
	bot.clear_enemies()
	_end(bot, "p3")
