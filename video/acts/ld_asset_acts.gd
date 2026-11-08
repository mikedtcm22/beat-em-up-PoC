extends RefCounted
## LD-ASSET's acts for the still stage (video/stage/still_bot.gd): the upgraded cast (docs/video/P1.md) in the shots where it is judged,
## rendered at 2560x1440 under the location's world look and LD-INK's ink look. Each act is "Asset: <shot> <variant>":
##   game   the game's own art (palette swatches, its detail mask) under the world and ink looks: the baseline
##   art    the art piece first (video meshes, painted albedo, ink mask), then the world look, then the ink look
##   paint  the art piece with only the painted albedo (an A/B: INK_ART="meshes=false;ink=false")
## The shots: the Phase 0 stills fp_punk, ox_closeup and ox_low, and four of LD-ASSET's own, made in code (a close-up of the Punk's
## face at 0.9 m, the Punk and Ox at about 2 m from a low three-quarter angle, and the Punk at 1.3 m in first person with the jab out,
## for the arms and wraps). "Asset: motion" is 12 consecutive frames of the Punk at 2 m while the camera turns (the textures must not swim).
## Environment: INK_SET ("prop=value;...", GDScript literals) overrides VideoInkLook values, ART_SET the same for VideoArtLook, ART_TAG
## appends a tag to the PNG's name, ART_FEEL=1 turns the Punk's and Ox's sketch mode and forced hatching on (the close-up look).

const LOCATIONS: Array[StringName] = [&"street_night", &"roofs_dusk", &"boss_fire"]
const LOOK_DIR := "res://video/look/%s/%s.tres"
const STILLS_DIR := "res://video/stills"
const PHASE0: Array[StringName] = [&"fp_punk", &"ox_closeup", &"ox_low"]
const VARIANTS: Array[StringName] = [&"game", &"art", &"paint"]
const MOTION_FRAMES := 12
const MOTION_TURN_DEG := 1.1
## The Punk stands here in the street section, facing the player (as in fp_punk).
const PUNK_AT := Vector3(3.5, 0.0, -6.0)
const OX_AT := Vector3(7.0, 0.0, -10.0)


static func acts(bot: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for shot in shots():
		for variant in VARIANTS:
			out.append({
				title = "Asset: %s %s" % [shot.key, variant],
				cam = &"first_person" if shot.first_person else &"free_fly",
				fn = func() -> void: await shoot(bot, shot, variant, false),
			})
	var motion_shot := own_shot(&"punk_2m")
	out.append({title = "Asset: motion", cam = &"free_fly", fn = func() -> void: await motion(bot, motion_shot)})
	return out


static func shots() -> Array[VideoStillShot]:
	var out: Array[VideoStillShot] = []
	for key in PHASE0:
		var shot := load(STILLS_DIR.path_join("%s.tres" % key)) as VideoStillShot
		if shot != null:
			out.append(shot)
	for key: StringName in [&"punk_close", &"punk_2m", &"ox_2m", &"fp_jab"]:
		out.append(own_shot(key))
	return out


static func _actor(id: StringName, at: Vector3) -> VideoStillActor:
	var actor := VideoStillActor.new()
	actor.id = id
	actor.position = at
	actor.facing = VideoStillActor.Facing.VIEWER
	actor.anim = &"idle"
	actor.hold_tick = 20
	return actor


## LD-ASSET's own shots, built in code (the stills directory is the stage's).
static func own_shot(key: StringName) -> VideoStillShot:
	var shot := VideoStillShot.new()
	shot.key = key
	shot.first_person = false
	shot.player_pos = Vector3(3.0, 0.0, -3.0)
	shot.warmup_ticks = 40
	match key:
		&"punk_close":
			shot.note = "The Punk's head at 0.9 m: the cap, the shades, the mask, the ear (ref 1 at 0.9 s's shot size)."
			shot.section = 0
			shot.actors = [_actor(&"punk", PUNK_AT)]
			shot.cam_pos = Vector3(3.55, 1.7, -5.15)
			shot.cam_look_at = Vector3(3.5, 1.66, -6.0)
			shot.cam_fov_deg = 42.0
		&"punk_2m":
			shot.note = "The Punk full figure at about 2 m from a low three-quarter angle."
			shot.section = 0
			shot.actors = [_actor(&"punk", PUNK_AT)]
			shot.cam_pos = Vector3(2.3, 1.0, -4.1)
			shot.cam_look_at = Vector3(3.5, 1.2, -6.0)
			shot.cam_fov_deg = 58.0
		&"ox_2m":
			shot.note = "Ox full figure at about 2 m from a low three-quarter angle."
			shot.section = 2
			shot.actors = [_actor(&"boss", OX_AT)]
			shot.cam_pos = Vector3(5.2, 1.1, -7.3)
			shot.cam_look_at = Vector3(7.0, 1.1, -10.0)
			shot.cam_fov_deg = 58.0
		&"fp_jab":
			shot.note = "First person, the Punk at 1.3 m, the player's right jab out: the arms and the wraps."
			shot.section = 0
			shot.first_person = true
			shot.player_pos = Vector3(3.5, 0.0, -4.6)
			shot.player_pitch_deg = -4.0
			shot.player_buttons = PackedStringArray(["P"])
			shot.player_button_ticks = 6
			shot.hold_time = true
			shot.actors = [_actor(&"punk", PUNK_AT)]
	return shot


## `prop=value;...` overrides of a look's properties (GDScript literals), from the environment variable `name`.
static func _override(look: Object, name: String) -> void:
	for pair in OS.get_environment(name).split(";", false):
		var parts := pair.split("=", true, 1)
		if parts.size() == 2 and parts[0] in look:
			look.set(parts[0], str_to_var(parts[1]))


static func _load_look(location: StringName, piece: String) -> Resource:
	var path := LOOK_DIR % [location, piece]
	if not ResourceLoader.exists(path):
		return null
	return (load(path) as Resource).duplicate()


## Apply the pieces in the order art, world, ink; returns {ink: the ink rig (or null)}.
static func apply_looks(bot: Node, shot: VideoStillShot, variant: StringName) -> Dictionary:
	var level: Node = bot.level
	var location := LOCATIONS[shot.section]
	if variant != &"game":
		var art := _load_look(location, "art") as VideoArtLook
		if art == null:
			art = VideoArtLook.new()
		if variant == &"paint":
			art.swap_meshes = false
			art.ink = false
		_override(art, "ART_SET")
		art.apply(level)
	var world := _load_look(location, "world") as VideoLookPiece
	if world != null:
		world.apply(level)
	var ink := _load_look(location, "ink") as VideoInkLook
	if ink == null:
		ink = VideoInkLook.new()
	if OS.get_environment("ART_FEEL") == "1":
		ink.sketch_mode = true
		ink.hatch_force = 1.0
	_override(ink, "INK_SET")
	ink.apply(level)
	var rig := level.get_node_or_null(^"CineInkRig") as CineInkRig
	if rig != null:
		rig.frame_source = func() -> int: return 0
	return {ink = rig}


## Stage `shot` as VideoStillBot.shoot() does, with the looks applied first. Returns {rig, at, yaw, pitch}.
static func stage(bot: Node, shot: VideoStillShot, variant: StringName) -> Dictionary:
	var level: Node = bot.level
	var looks := apply_looks(bot, shot, variant)
	var section: Node3D = level.sections[shot.section]
	var base := section.global_position
	var yaw := deg_to_rad(shot.player_yaw_deg)
	var at := base + shot.player_pos
	var pitch := deg_to_rad(shot.player_pitch_deg)
	bot.freeze_ai(true)
	bot.god(true)
	if shot.first_person and shot.first_person_fov_deg > 0.0:
		bot.tune(&"fov_deg", shot.first_person_fov_deg)
	bot._pin_player(at, yaw, pitch)
	await bot._settle_light(section, at, yaw, pitch)
	var viewer: Vector3 = at + Vector3.UP * float(bot.player.body_height)
	if not shot.first_person:
		viewer = base + shot.cam_pos
	for spec in shot.actors:
		bot._place_actor(spec, base, viewer)
	if not shot.first_person:
		var forward: Vector3 = (base + shot.cam_look_at) - viewer
		bot._free_xf = Transform3D(Basis.looking_at(forward, Vector3.UP), viewer)
		bot._free_fov = shot.cam_fov_deg
		bot._free_on = true
	return {rig = looks.ink, at = at, yaw = yaw, pitch = pitch}


static func _name(shot: VideoStillShot, variant: StringName) -> String:
	var tag := OS.get_environment("ART_TAG")
	var text := "%s_%s" % [shot.key, variant]
	return "%s_%s" % [text, tag] if tag != "" else text


## One still: stage, warm up, press the shot's buttons, hold time, grab <key>_<variant>[_<tag>].png.
static func shoot(bot: Node, shot: VideoStillShot, variant: StringName, _unused: bool) -> void:
	var staged := await stage(bot, shot, variant)
	for _tick in shot.warmup_ticks:
		await bot._ticks(1)
		bot._pin_player(staged.at, staged.yaw, staged.pitch, false)
	if shot.player_hold != &"":
		bot.player.input.push_down(shot.player_hold)
	for n in shot.player_buttons.size():
		bot.player.input.push_press(StringName(shot.player_buttons[n]), 2)
		if n < shot.player_buttons.size() - 1:
			await bot._ticks(shot.player_button_gap_ticks)
	await bot._ticks(shot.player_button_ticks)
	if shot.hold_time:
		Engine.time_scale = 0.0
	for _frame in 8:
		await bot.get_tree().process_frame
	var rig: CineInkRig = staged.rig
	if rig != null:
		bot.grab.camera.compositor = rig.compositor
		await bot.get_tree().process_frame
	var name_text := _name(shot, variant)
	var err: Error = await bot.grab.capture(String(bot.out_dir).path_join("%s.png" % name_text))
	var art := bot.level.get_node_or_null(^"CineArtRig") as CineArtRig
	bot.log_line("ASSET %s err=%d dressed %s" % [name_text, err, art.dressed if art != null else {}])
	Engine.time_scale = 1.0


## 12 consecutive frames of `shot` (art variant) while the camera turns a little each frame.
static func motion(bot: Node, shot: VideoStillShot) -> void:
	var staged := await stage(bot, shot, &"art")
	for _tick in shot.warmup_ticks:
		await bot._ticks(1)
		bot._pin_player(staged.at, staged.yaw, staged.pitch, false)
	var rig: CineInkRig = staged.rig
	if rig != null:
		bot.grab.camera.compositor = rig.compositor
	for frame in MOTION_FRAMES:
		var xf: Transform3D = bot._free_xf
		xf.basis = xf.basis.rotated(Vector3.UP, deg_to_rad(MOTION_TURN_DEG))
		bot._free_xf = xf
		await bot._ticks(1)
		await bot.get_tree().process_frame
		var path := "%s/motion_m%02d.png" % [bot.out_dir, frame]
		await bot.grab.capture(path)
