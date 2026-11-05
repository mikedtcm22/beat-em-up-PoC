extends RefCounted
## The ground's look and its stability (M6 playtest feedback, FB-GROUND): the player stands on the street floor
## and the view is held, drifted, panned and walked over it, so a recording can be measured for flicker
## (tools/ground_flicker.py) and a few frames cut at full resolution.
##   "Look: ground drift"  at street A1 and A2 (the feet on the floor, the lens pitched down so the floor fills the
##                         lower half): `still` (60 ticks, nothing moves: any frame difference is a temporal
##                         artefact), `creep` (yaw 1 degree a second: a fraction of a pixel a frame), `pan` (10 degrees
##                         a second with the pitch swaying), `walk` (0.8 m a second along the street). Logs
##                         `GROUND <variant> <spot> <phase> f<first> f<last>`, the frames of the video (60 a second).
## `-- --ground=<variant>` (after the scene's other arguments) switches one suspect off for the recording:
##   `control` nothing; `no_shadow` the sun casts no shadow; `hard_shadow` the sun's shadow edge is not blurred;
##   `no_edges` the edge pass is off; `no_ink` the trim material draws no ink; `lod_free` the trim material's mip cap
##   is lifted; `flat` the trim sheet is one flat colour (the control: nothing but geometry, light and shadow).
## Needs the whole level (`--level=res://game/level/mission1/mission1.tscn`).

const TourActs := preload("res://tests/bot/level_acts/tour_acts.gd")

## Seconds each phase is held.
const STILL_S := 1.0
const CREEP_S := 3.0
const PAN_S := 3.0
const WALK_S := 3.0

## {label, at (street space, the feet), yaw (degrees), pitch (degrees)}.
const SPOTS: Array[Dictionary] = [
	{label = "a1", at = Vector3(3.0, 0.0, 0.8), yaw = 0.0, pitch = -14.0},
	{label = "a2", at = Vector3(1.0, 0.0, -17.0), yaw = 0.0, pitch = -14.0},
]
const CREEP_DEG_PER_S := 1.0
const PAN_DEG_PER_S := 10.0
const PAN_SWAY_DEG := 3.0
const WALK_M_PER_S := 0.8


static func acts(bot: Node) -> Array[Dictionary]:
	return [{title = "Look: ground drift", cam = &"first_person", fn = func() -> void: await _drift(bot)}]


static func _variant() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ground="):
			return arg.trim_prefix("--ground=")
	return "control"


## Switch the suspect `variant` names off.
static func _apply(bot: Node, variant: String) -> void:
	match variant:
		"no_shadow":
			for node: Node in bot.level.find_children("*", "DirectionalLight3D", true, false):
				(node as DirectionalLight3D).shadow_enabled = false
		"hard_shadow":
			for node: Node in bot.level.find_children("*", "DirectionalLight3D", true, false):
				(node as DirectionalLight3D).shadow_blur = 0.0
			bot.tune(&"look_sun_shadow_blur", 0.0)
		"no_edges":
			bot.tune(&"look_edges_enabled", false)
		"no_ink":
			ToonMaterials.trim().set_shader_parameter(&"ink_cut", 4.0)
		"lod_free":
			ToonMaterials.trim().set_shader_parameter(&"lod_cap", 12.0)
		"dbg_strip", "dbg_lod", "dbg_alpha":
			ToonMaterials.trim().set_shader_parameter(&"debug_view", {"dbg_strip": 1, "dbg_lod": 2, "dbg_alpha": 4}[variant])
		"strip_interp":
			ToonMaterials.trim().set_shader_parameter(&"strip_interpolated", true)
		"flat":
			var image := Image.create(64, 64, true, Image.FORMAT_RGBA8)
			image.fill(Color(0.35, 0.35, 0.4, 0.0))
			image.generate_mipmaps()
			ToonMaterials.trim().set_shader_parameter(&"trim_tex", ImageTexture.create_from_image(image))


## A diagnostic (`--ground=diag`): every tick of a still hold, the sun's and the camera's state, one line a tick.
static func _diag(bot: Node) -> void:
	bot.freeze_ai(true)
	var player: PlayerCharacter = bot.player
	var spot: Dictionary = SPOTS[0]
	var yaw := deg_to_rad(float(spot.yaw))
	var pitch := deg_to_rad(float(spot.pitch))
	_place(player, spot.at, yaw, pitch)
	await TourActs.settle_light(bot, bot.level.sections[0], spot.at)
	var suns: Array[Node] = bot.level.find_children("*", "DirectionalLight3D", true, false)
	bot.log_line("DIAG suns %d" % suns.size())
	for n in 40:
		_place(player, spot.at, yaw, pitch)
		var sun := suns[0] as DirectionalLight3D
		var cam: Camera3D = bot.get_viewport().get_camera_3d()
		bot.log_line("DIAG f%d sun_rot=%s e=%.3f shadow=%s blur=%.2f cam=%s player=%s light_t=%.2f" % [Engine.get_physics_frames(),
				sun.rotation_degrees, sun.light_energy, sun.shadow_enabled, sun.shadow_blur, cam.global_position, player.global_position, bot.level.section_light_progress()])
		await bot._ticks(1)


## Every mesh whose box reaches the floor's plane over the point (3, 0, -6), with its box and surface count.
static func _diag_meshes(bot: Node) -> void:
	var probe := Vector3(3.0, 0.0, -6.0)
	for node: Node in bot.level.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		if probe.x >= box.position.x and probe.x <= box.end.x and probe.z >= box.position.z and probe.z <= box.end.z and box.position.y <= 0.02 and box.end.y >= -0.02:
			bot.log_line("MESH %s %s box=%s surfaces=%d shadow=%d vis=%s" % [bot.level.get_path_to(mi), mi.mesh.get_class(), box, mi.mesh.get_surface_count(), mi.cast_shadow, mi.is_visible_in_tree()])


static func _drift(bot: Node) -> void:
	if _variant() == "meshes":
		await _diag_meshes(bot)
		return
	if _variant() == "diag":
		await _diag(bot)
		return
	if bot.level.sections.size() < 1:
		bot.log_line("NOTE the ground drift needs the level")
		return
	bot.freeze_ai(true)
	var player: PlayerCharacter = bot.player
	var variant := _variant()
	_apply(bot, variant)
	for spot: Dictionary in SPOTS:
		var yaw0 := deg_to_rad(float(spot.yaw))
		var pitch0 := deg_to_rad(float(spot.pitch))
		var at: Vector3 = spot.at
		_place(player, at, yaw0, pitch0)
		await TourActs.settle_light(bot, bot.level.sections[0], at)
		await _phase(bot, variant, spot, "still", int(STILL_S * 60.0), func(_t: float) -> void: _place(player, at, yaw0, pitch0))
		await _phase(bot, variant, spot, "creep", int(CREEP_S * 60.0), func(t: float) -> void:
			_place(player, at, yaw0 + deg_to_rad(CREEP_DEG_PER_S * t), pitch0))
		await _phase(bot, variant, spot, "pan", int(PAN_S * 60.0), func(t: float) -> void:
			var yaw := yaw0 + deg_to_rad(PAN_DEG_PER_S * (t - PAN_S * 0.5))
			var pitch := pitch0 + deg_to_rad(PAN_SWAY_DEG * sin(t * TAU / 4.0))
			_place(player, at, yaw, pitch))
		await _phase(bot, variant, spot, "walk", int(WALK_S * 60.0), func(t: float) -> void:
			_place(player, at + Vector3(0.0, 0.0, -WALK_M_PER_S * t), yaw0, pitch0))


static func _place(player: PlayerCharacter, at: Vector3, yaw: float, pitch: float) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw
	player.look_yaw = yaw
	player.look_pitch = pitch


## Run `step` once a tick for `ticks` ticks (with the seconds since the phase began) and log the phase's frames.
static func _phase(bot: Node, variant: String, spot: Dictionary, phase: String, ticks: int, step: Callable) -> void:
	var first := Engine.get_physics_frames()
	for n in ticks:
		step.call(float(n) / 60.0)
		await bot._ticks(1)
	bot.log_line("GROUND %s %s %s f%d f%d" % [variant, spot.label, phase, first, Engine.get_physics_frames() - 1])
