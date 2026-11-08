extends RefCounted
## LD-INK's acts for the still stage (video/stage/still_bot.gd): the Punk at first-person distance and Ox in a
## close-up (the Gate 1 shots fp_punk and ox_closeup), rendered at 2560x1440 under a stand-in world look
## (the spike's night light and flat paint, video/spike/spike_look.gd, until LD-WORLD's is on the branch).
## The act stages a shot as VideoStillBot.shoot() does, with a hook between the staging and the grab where the
## look is applied. Run one variant per process, with tools/video/shoot_still.sh:
##   "Ink: fp_punk plain"   the stand-in world look and the game's own character paint and line
##   "Ink: fp_punk look"    + the ink piece (cine paint and line, rim, post, cues)
##   "Ink: ox_closeup look" / "... sketch"  (sketch strokes and hatching forced on)
## Environment: INK_LOOK (a location, default street_night; ox_closeup defaults to boss_fire), INK_SET
## ("prop=value;prop=value", GDScript literals) overrides VideoInkLook values for look sweeps, INK_TAG appends
## a tag to the PNG's name, INK_WORLD=0 leaves the stand-in world look off.

const SPIKE_DATA := "res://video/spike/spike_look.tres"
const LOOK_DIR := "res://video/look"
const STILLS_DIR := "res://video/stills"
const SHOTS: Array[StringName] = [&"fp_punk", &"ox_closeup", &"ox_low", &"fp_kicker_lamp", &"street_wide"]
const VARIANTS: Array[StringName] = [&"plain", &"look", &"sketch"]
const DEFAULT_LOCATION := {&"ox_closeup": &"boss_fire", &"ox_low": &"boss_fire", &"roof_silhouette": &"roofs_dusk"}


static func acts(bot: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in SHOTS:
		var shot := load(STILLS_DIR.path_join("%s.tres" % key)) as VideoStillShot
		if shot == null:
			continue
		for variant in VARIANTS:
			out.append({
				title = "Ink: %s %s" % [key, variant],
				cam = &"first_person" if shot.first_person else &"free_fly",
				fn = func() -> void: await shoot(bot, shot, variant),
			})
	return out


## The look the act applies: the location's ink.tres with INK_SET's overrides.
static func load_look(key: StringName) -> VideoInkLook:
	var location: StringName = StringName(OS.get_environment("INK_LOOK")) if OS.get_environment("INK_LOOK") != "" \
			else DEFAULT_LOCATION.get(key, &"street_night")
	var path := LOOK_DIR.path_join("%s/ink.tres" % location)
	var source := load(path) as VideoInkLook
	var look: VideoInkLook = source.duplicate() if source != null else VideoInkLook.new()
	for pair in OS.get_environment("INK_SET").split(";", false):
		var parts := pair.split("=", true, 1)
		if parts.size() == 2 and parts[0] in look:
			look.set(parts[0], str_to_var(parts[1]))
	return look


## Stage `shot` like VideoStillBot.shoot(), with the look applied after the staging; write <key>_<variant>.png.
static func shoot(bot: Node, shot: VideoStillShot, variant: StringName) -> void:
	var level: Node = bot.level
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
	# The stand-in world look, then ours.
	var world: CineSpikeLook
	if OS.get_environment("INK_WORLD") != "0" and not shot.actors.is_empty():
		world = CineSpikeLook.new()
		world.data = load(SPIKE_DATA)
		bot.add_child(world)
		world.setup(level, func() -> Camera3D: return bot.get_viewport().get_camera_3d())
		world.set_punk_feet(base + shot.actors[0].position)
		world.apply_stage(&"b")
		world.apply_stage(&"c")
	var rig: CineInkRig
	if variant != &"plain":
		var look := load_look(shot.key)
		if variant == &"sketch":
			look.sketch_mode = true
			look.hatch_force = 1.0
		look.apply(level)
		rig = level.get_node(^"CineInkRig") as CineInkRig
		rig.frame_source = func() -> int: return 0
		bot.log_line("INK look %s variant %s" % [OS.get_environment("INK_LOOK"), variant])
	for _tick in shot.warmup_ticks:
		await bot._ticks(1)
		bot._pin_player(at, yaw, pitch, false)
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
	var tag: String = OS.get_environment("INK_TAG")
	var name_text := "%s_%s%s" % [shot.key, variant, ("_" + tag) if tag != "" else ""]
	if rig != null:
		bot.grab.camera.compositor = rig.compositor
		bot.log_line("INK hatch %.2f key %s" % [rig.hatch_amount(), rig.key_world()])
		await bot.get_tree().process_frame
	var err: Error = await bot.grab.capture(String(bot.out_dir).path_join("%s.png" % name_text))
	Engine.time_scale = 1.0
	bot.log_line("INK %s err=%d" % [name_text, err])
	if rig != null:
		rig.queue_free()
	if world != null:
		world.queue_free()
