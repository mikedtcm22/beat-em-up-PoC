extends RefCounted
## LD-INK's acts for the still stage (video/stage/still_bot.gd): the Punk at first-person distance and Ox in a
## close-up (the Gate 1 shots fp_punk and ox_closeup), rendered at 2560x1440 under a stand-in world look
## (the spike's night light and flat paint, video/spike/spike_look.gd, until LD-WORLD's is on the branch).
## The act stages a shot as VideoStillBot.shoot() does, with a hook between the staging and the grab where the
## look is applied. Run one variant per process, with tools/video/shoot_still.sh:
##   "Ink: fp_punk plain"   the stand-in world look and the game's own character paint and line
##   "Ink: fp_punk look"    + the ink piece (cine paint and line, rim, post, cues)
##   "Ink: ox_closeup look" / "... sketch"  (sketch strokes and hatching forced on)
##   "Ink: motion"          12 consecutive frames of fp_punk while the camera turns and the Punk walks
##                          (INK_SET on_twos=false for the A/B), each frame a PNG, with the pose log
##   "Ink: cues"            a punch on a Punk, three frames: the smear, the hit, the flash and speed lines
##                          (INK_SET smears=false;hide_comic_fx=false;flash_frames=false;speed_lines=false
##                          is the game's own set for the A/B)
## Environment: INK_LOOK (a location, default street_night; ox shots default to boss_fire), INK_SET
## ("prop=value;prop=value", GDScript literals) overrides VideoInkLook values for look sweeps, INK_TAG appends
## a tag to the PNG's name, INK_WORLD=0 leaves the stand-in world look off.

const SPIKE_DATA := "res://video/spike/spike_look.tres"
const LOOK_DIR := "res://video/look"
const STILLS_DIR := "res://video/stills"
const SHOTS: Array[StringName] = [&"fp_punk", &"ox_closeup", &"ox_low", &"fp_kicker_lamp", &"street_wide", &"roof_silhouette"]
const VARIANTS: Array[StringName] = [&"plain", &"look", &"sketch"]
const DEFAULT_LOCATION := {&"ox_closeup": &"boss_fire", &"ox_low": &"boss_fire", &"roof_silhouette": &"roofs_dusk"}
## The motion check: frames, the camera's turn per frame (degrees) and the Punk's clip.
const MOTION_FRAMES := 12
const MOTION_TURN_DEG := 1.1
const MOTION_CLIP := &"walk_forward"


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
	var punk := load(STILLS_DIR.path_join("fp_punk.tres")) as VideoStillShot
	out.append({title = "Ink: motion", cam = &"first_person", fn = func() -> void: await motion(bot, punk)})
	out.append({title = "Ink: cues", cam = &"free_fly", fn = func() -> void: await cues(bot)})
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


## Stage `shot` like VideoStillBot.shoot() up to the grab, apply the stand-in world look and then ours (unless
## `variant` is &"plain"). Returns {rig, world, at, yaw, pitch}.
static func stage(bot: Node, shot: VideoStillShot, variant: StringName) -> Dictionary:
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
	var world: CineSpikeLook
	if OS.get_environment("INK_WORLD") != "0":
		world = CineSpikeLook.new()
		world.data = load(SPIKE_DATA)
		bot.add_child(world)
		world.setup(level, func() -> Camera3D: return bot.get_viewport().get_camera_3d())
		var lamp_at := base + (shot.actors[0].position if not shot.actors.is_empty() else shot.player_pos + Vector3(0, 0, -2))
		world.set_punk_feet(lamp_at)
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
	return {rig = rig, world = world, at = at, yaw = yaw, pitch = pitch}


static func _tag_name(prefix: String) -> String:
	var tag: String = OS.get_environment("INK_TAG")
	return "%s_%s" % [prefix, tag] if tag != "" else prefix


static func _cleanup(staged: Dictionary) -> void:
	Engine.time_scale = 1.0
	if staged.rig != null:
		staged.rig.queue_free()
	if staged.world != null:
		staged.world.queue_free()


## One still: stage, warm up, press the shot's buttons, hold time, grab <key>_<variant>[_<tag>].png.
static func shoot(bot: Node, shot: VideoStillShot, variant: StringName) -> void:
	var staged := await stage(bot, shot, variant)
	var rig: CineInkRig = staged.rig
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
	var name_text := _tag_name("%s_%s" % [shot.key, variant])
	if rig != null:
		bot.grab.camera.compositor = rig.compositor
		bot.log_line("INK hatch %.2f key %s" % [rig.hatch_amount(), rig.key_world()])
		await bot.get_tree().process_frame
	var err: Error = await bot.grab.capture(String(bot.out_dir).path_join("%s.png" % name_text))
	bot.log_line("INK %s err=%d" % [name_text, err])
	_cleanup(staged)


## The motion check: MOTION_FRAMES consecutive output frames of fp_punk while the camera turns and the Punk
## walks (his rig advanced one 24 fps frame at a time), each a PNG motion_<tag>_<i>.png, and a log line per
## frame with a hash of the Punk's bone poses (a hold frame repeats the one before) and the camera's yaw.
static func motion(bot: Node, shot: VideoStillShot) -> void:
	var staged := await stage(bot, shot, &"look")
	var rig: CineInkRig = staged.rig
	var punk: EnemyActor = bot._stage_actors[0] if not bot._stage_actors.is_empty() else null
	if punk == null:
		bot.log_line("INK motion: no punk")
		return
	punk.rig.play(MOTION_CLIP, 0.0)
	Engine.time_scale = 0.0
	var frame_counter := [0]
	rig.frame_source = func() -> int: return frame_counter[0]
	bot.grab.camera.compositor = rig.compositor
	var skeleton: Skeleton3D = punk.rig.skeleton
	for i in MOTION_FRAMES:
		frame_counter[0] = i
		punk.rig.advance(1.0 / rig.look.output_fps)
		var yaw: float = staged.yaw + deg_to_rad(MOTION_TURN_DEG) * i
		bot._pin_player(staged.at, yaw, staged.pitch)
		for _frame in 3:
			await bot.get_tree().process_frame
		var pose_hash := 0
		for bone in skeleton.get_bone_count():
			pose_hash = hash([pose_hash, skeleton.get_bone_pose_rotation(bone)])
		var err: Error = await bot.grab.capture(String(bot.out_dir).path_join("%s_%02d.png" % [_tag_name("motion"), i]))
		bot.log_line("INK motion %d pose %d yaw %.2f err=%d" % [i, pose_hash, rad_to_deg(yaw), err])
	_cleanup(staged)


## The cues: the player punches a Punk in reach, a free camera at three quarters. Three grabs: the fist in
## flight (the smear), just after the hit (the comic burst, hidden or not), and a finisher's flash and speed
## lines (triggered by hand at the contact point). cues_<tag>_{smear,hit,flash}.png.
static func cues(bot: Node) -> void:
	var shot := VideoStillShot.new()
	shot.key = &"cues"
	shot.section = 0
	shot.player_pos = Vector3(3.0, 0.0, -3.0)
	shot.player_yaw_deg = 0.0
	shot.first_person = false
	shot.cam_pos = Vector3(4.6, 1.5, -2.2)
	shot.cam_look_at = Vector3(3.0, 1.35, -4.0)
	shot.cam_fov_deg = 62.0
	var staged := await stage(bot, shot, &"look")
	var rig: CineInkRig = staged.rig
	bot._pin_player(staged.at, staged.yaw, staged.pitch)
	var punk: EnemyActor = bot.spawner.spawn_enemy(&"punk", staged.at + Vector3(0.0, 0.0, -1.15), PI)
	bot._stage_actors.append(punk)
	bot.freeze_ai(true)
	await bot._ticks(40)
	bot._pin_player(staged.at, staged.yaw, staged.pitch, false)
	bot.grab.camera.compositor = rig.compositor
	var base_name := _tag_name("cues")
	bot.player.input.push_press(&"P", 2)
	# The fist in flight: the first tick a smear ribbon is drawn.
	var drawn := false
	for tick in 40:
		await bot._ticks(1)
		bot._pin_player(staged.at, staged.yaw, staged.pitch, false)
		if rig.smears_drawing() > 0:
			drawn = true
			break
	bot.log_line("INK cues smear drawn=%s ribbons=%d" % [drawn, rig.smears_drawing()])
	Engine.time_scale = 0.0
	for _frame in 4:
		await bot.get_tree().process_frame
	await bot.grab.capture(String(bot.out_dir).path_join("%s_smear.png" % base_name))
	Engine.time_scale = 1.0
	# After the hit: a few ticks on, where the comic burst stands.
	for tick in 30:
		await bot._ticks(1)
		bot._pin_player(staged.at, staged.yaw, staged.pitch, false)
		if punk.health < punk.max_health:
			break
	await bot._ticks(4)
	Engine.time_scale = 0.0
	for _frame in 4:
		await bot.get_tree().process_frame
	await bot.grab.capture(String(bot.out_dir).path_join("%s_hit.png" % base_name))
	Engine.time_scale = 1.0
	# A finisher hit by hand (as the level bot's knock-off builds one): the game's comic burst and word, its own
	# impact frame and speed lines (the main viewport's layers) and our flash frame and lines all come from it.
	var hit := HitInfo.new()
	hit.attacker = bot.player
	hit.victim = punk
	hit.damage = 1.0
	hit.tier = CombatTypes.HitTier.FINISHER
	hit.reaction = CombatTypes.Reaction.FLINCH
	hit.direction = Vector3.FORWARD
	hit.contact_point = punk.rig.get_point_position(&"EyePoint")
	punk.receive_hit(hit)
	CombatEvents.hit_landed.emit(hit)
	await bot._ticks(2)
	Engine.time_scale = 0.0
	for _frame in 4:
		await bot.get_tree().process_frame
	await bot.grab.capture(String(bot.out_dir).path_join("%s_flash.png" % base_name))
	bot.log_line("INK cues done health %.0f/%.0f" % [punk.health, punk.max_health])
	_cleanup(staged)
