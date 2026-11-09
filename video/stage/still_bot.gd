extends "res://tests/bot/level_bot.gd"
## The still stage's bot: the level bot's harness (the scripted player, the level, the captions) without the
## readability probe and the autopilot, reading its acts from `res://video/acts/*_acts.gd` and rendering each
## still through a VideoStillGrab at 2560x1440. Run it with tools/video/shoot_still.sh, or by hand:
##   godot --path . --fixed-fps 60 --resolution 1280x720 res://video/stage/still_bot.tscn -- \
##     --level=res://game/level/mission1/mission1.tscn --act=<filter> --still-out=<abs dir>
## Arguments after `--`: the level bot's, plus `--still-out=<dir>` (default `captures/video/stills`) and
## `--still-window` (also save the window's own frame, to compare it with the grab).
## An act of a stills file calls `shoot(shot)`; the shots are data (VideoStillShot, `res://video/stills/*.tres`).

## Where the acts are read from (the base constant names the tests' directory and cannot be redeclared).
const VIDEO_ACTS_DIR := "res://video/acts"
## Where the stills are written when no `--still-out=` is given.
const DEFAULT_OUT := "res://captures/video/stills"
## The head bone, logged for each actor so a free camera can be aimed at it.
const HEAD_POINT := &"Head"
## The seeds of the effect and audio directors (their rngs randomize at startup).
const EFFECT_SEED := 1
const AUDIO_SEED := 1

var grab: VideoStillGrab
## `--still-window`: also write the main window's own frame (`<key>_window.png`), to compare it with the grab.
var save_window: bool = false
var out_dir: String = ""
## Actors the stage placed (they are taken out of the enemy groups, so clear_enemies() cannot free them).
var _stage_actors: Array[Node] = []
var _props: Array[Node] = []
## The free camera's pose while a free still is staged (applied every frame, after the game cameras).
var _free_xf: Transform3D = Transform3D.IDENTITY
var _free_fov: float = 70.0
var _free_on: bool = false
## False: the stage builds no lamp posts of its own (a world look places its own, from data).
var stage_lamps: bool = true


func _ready() -> void:
	process_priority = 60
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--still-out="):
			out_dir = arg.trim_prefix("--still-out=")
		elif arg == "--still-window":
			save_window = true
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	super._ready()


func _process(_delta: float) -> void:
	if _free_on and director != null:
		var camera: FreeFlyCamera = director.free_fly_camera
		camera.global_transform = _free_xf
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = _free_fov


## Every act of `res://video/acts/*_acts.gd`, in file name order.
func _collect_acts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(VIDEO_ACTS_DIR)
	if dir == null:
		return out
	var files := PackedStringArray()
	for file in dir.get_files():
		if file.ends_with("_acts.gd"):
			files.append(file)
	files.sort()
	for file in files:
		var script := load(VIDEO_ACTS_DIR.path_join(file)) as GDScript
		if script:
			out.append_array(script.call(&"acts", self))
	return out


func _run() -> void:
	await _ticks(8)  # the navigation map syncs 2 or 3 physics frames after the room's _ready()
	player = room.get(&"player")
	player.input.scripted = true
	spawner = room.get(&"spawner")
	director = get_tree().get_first_node_in_group(&"camera_director")
	AudioServer.set_bus_mute(0, true)
	_hide_overlays()
	for child in room.get_children():
		if child is VfxDirector:
			(child as VfxDirector).rng.seed = EFFECT_SEED
		elif child is AudioDirector:
			(child as AudioDirector).rng.seed = AUDIO_SEED
	grab = VideoStillGrab.new()
	add_child(grab)
	for act in _collect_acts():
		var title: String = act.title
		if act_filter != "" and not _matches(title):
			continue
		await _reset(act.cam)
		print("=== %s  (f%d)" % [title, Engine.get_physics_frames()])
		var fn: Callable = act.fn
		await fn.call()
		await _ticks(2)
	await _quit()


## The level bot's reset without the pilot: every act starts from the same names and seeds, the arenas disarmed
## (a teleport into one must not lock it), the camera mode asked for.
func _reset(cam: StringName) -> void:
	Engine.time_scale = 1.0
	_free_on = false
	clear_enemies()
	_clear_stage()
	set_waves(false)
	freeze_ai(false)
	for property: StringName in _tuned:
		Tuning.set_value(property, _tuned[property])
	_tuned.clear()
	Tuning.set_value(&"god_mode", false)
	_clear_floor_pipes()
	spawner.set(&"_serials", _fresh_serials())
	(spawner.get(&"_rng") as RandomNumberGenerator).seed = spawner.rng_seed
	level.director.rng_seed = level.rng_seed
	player.input.clear_queue()
	player.input.scripted_move = Vector2.ZERO
	player.parser.release(&"DODGE")
	level.start_at_arena(from_arena)
	for arena in level.arenas():
		arena.armed = false
	player.sim_velocity = Vector3.ZERO
	player.parser.reset_chain()
	player.parser.clear_buffer()
	if director:
		var guard := 0
		while director.get(&"mode") != cam and guard < 4:
			director.call(&"cycle")
			guard += 1
	_hide_overlays()
	await _ticks(2)


func _quit() -> void:
	_clear_stage()
	await super._quit()


## The HUD, the bot's caption and the debug draw off: nothing but the world reaches a still.
func _hide_overlays() -> void:
	for child in room.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
		if child.has_method(&"set_debug_draw_enabled"):
			child.call(&"set_debug_draw_enabled", false)
	caption.get_parent().visible = false
	Tuning.set_value(&"show_center_dot", false)


func _clear_stage() -> void:
	for node in _stage_actors + _props:
		if is_instance_valid(node):
			node.queue_free()
	_stage_actors.clear()
	_props.clear()


## Stage `shot` and write its PNG to `out_dir/<key>.png`.
func shoot(shot: VideoStillShot) -> void:
	await stage(shot)
	var path := out_dir.path_join("%s.png" % shot.key)
	var err := await grab.capture(path)
	if save_window:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_window.png" % shot.key))
	Engine.time_scale = 1.0
	log_line("STILL %s %s err=%d" % [shot.key, path, err])


## Stage `shot` up to the grab: the player placed and the section light settled, the lamps and the actors in,
## the camera set, the room warmed up and the player's buttons pressed (the time stopped when the shot holds it).
func stage(shot: VideoStillShot) -> void:
	var section: Node3D = level.sections[shot.section]
	var base := section.global_position
	var yaw := deg_to_rad(shot.player_yaw_deg)
	var at := base + shot.player_pos
	freeze_ai(true)
	god(true)
	if shot.first_person and shot.first_person_fov_deg > 0.0:
		tune(&"fov_deg", shot.first_person_fov_deg)
	_pin_player(at, yaw, deg_to_rad(shot.player_pitch_deg))
	await _settle_light(section, at, yaw, deg_to_rad(shot.player_pitch_deg))
	if stage_lamps:
		_build_lamps(shot, base)
	var viewer := at + Vector3.UP * player.body_height
	if not shot.first_person:
		viewer = base + shot.cam_pos
	for spec in shot.actors:
		_place_actor(spec, base, viewer)
	if not shot.first_person:
		_place_free_camera(shot, base, viewer)
	for _tick in shot.warmup_ticks:
		await _ticks(1)
		_pin_player(at, yaw, deg_to_rad(shot.player_pitch_deg), false)
	if shot.player_hold != &"":
		player.input.push_down(shot.player_hold)
	for n in shot.player_buttons.size():
		player.input.push_press(StringName(shot.player_buttons[n]), 2)
		if n < shot.player_buttons.size() - 1:
			await _ticks(shot.player_button_gap_ticks)
	await _ticks(shot.player_button_ticks)
	if shot.hold_time:
		Engine.time_scale = 0.0
	for _frame in 3:
		await get_tree().process_frame
	_log_sun()


## Aim the free camera of a free-camera shot (a subclass puts its own camera here). The stage's own: the game's
## free-fly camera, held at one pose every frame.
func _place_free_camera(shot: VideoStillShot, base: Vector3, viewer: Vector3) -> void:
	var forward := (base + shot.cam_look_at) - viewer
	_free_xf = Transform3D(Basis.looking_at(forward, Vector3.UP), viewer)
	_free_fov = shot.cam_fov_deg
	_free_on = true


## Put the player at `at` facing `yaw` and looking `pitch`; `settled` also stops him moving.
func _pin_player(at: Vector3, yaw: float, pitch: float, hard: bool = true) -> void:
	if hard:
		player.global_position = at
	player.velocity = Vector3.ZERO
	player.sim_velocity = Vector3.ZERO
	player.rotation.y = yaw
	player.look_yaw = yaw
	player.look_pitch = pitch


## After a teleport into `section`: wait for the level to notice it and for the section light's blend to arrive.
func _settle_light(section: Node3D, at: Vector3, yaw: float, pitch: float) -> void:
	var limit := int((Tuning.data.section_light_blend_s + 0.5) * Engine.physics_ticks_per_second)
	for _tick in 4:
		await _ticks(1)
		_pin_player(at, yaw, pitch)
	while limit > 0 and (level.current_section() != section or level.section_light_progress() < 1.0):
		await _ticks(1)
		_pin_player(at, yaw, pitch)
		limit -= 1


## An enemy of the catalog, placed, taken off its own tick and held in `spec`'s pose.
func _place_actor(spec: VideoStillActor, base: Vector3, viewer: Vector3) -> void:
	var at := base + spec.position
	var yaw := deg_to_rad(spec.yaw_deg)
	if spec.facing == VideoStillActor.Facing.VIEWER:
		var to_viewer := viewer - at
		yaw = atan2(-to_viewer.x, -to_viewer.z)
	var enemy := spawner.spawn_enemy(spec.id, at, yaw)
	if enemy == null:
		log_line("STILL actor %s could not be spawned" % spec.id)
		return
	if not spec.live:
		ShowcaseRunner.unplug(enemy)
	enemy.global_position = at
	enemy.rotation.y = yaw
	if not spec.live:
		enemy.rig.play(spec.anim, 0.0)
		enemy.rig.advance(float(spec.hold_tick) / float(Engine.physics_ticks_per_second))
	_stage_actors.append(enemy)
	log_line("STILL actor %s at %s head %s" % [spec.id, at, enemy.rig.get_point_position(HEAD_POINT)])


## Video-only lamp posts: a pole, an arm and a glowing head (the game has no lamps).
func _build_lamps(shot: VideoStillShot, base: Vector3) -> void:
	var pole_material := ToonMaterials.environment(Color(0.12, 0.11, 0.14))
	var head_material := StandardMaterial3D.new()
	head_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	head_material.albedo_color = Color(1.0, 0.6, 0.24)
	for foot in shot.lamp_posts:
		var post := Node3D.new()
		post.position = base + foot
		var pole := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = shot.lamp_pole_radius_m * 0.8
		cylinder.bottom_radius = shot.lamp_pole_radius_m
		cylinder.height = shot.lamp_height_m
		pole.mesh = cylinder
		pole.position.y = shot.lamp_height_m * 0.5
		pole.material_override = pole_material
		post.add_child(pole)
		var head := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(shot.lamp_head_m, shot.lamp_head_m * 0.4, shot.lamp_head_m)
		head.mesh = box
		head.position.y = shot.lamp_height_m + shot.lamp_head_m * 0.2
		head.material_override = head_material
		post.add_child(head)
		room.add_child(post)
		_props.append(post)


## The sun's direction, for aiming a camera at it.
func _log_sun() -> void:
	var sun := level.get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		var toward := sun.global_basis.z
		log_line("STILL sun toward %s (yaw_deg %.1f, elev_deg %.1f)" % [toward,
				rad_to_deg(atan2(-toward.x, -toward.z)), rad_to_deg(asin(toward.y))])
