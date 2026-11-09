extends "res://video/stage/cine_bot.gd"
## The plate capture's bot (round 5, R5-PAINT; docs/video/P1.md): the cine bot playing one shot to a chosen frame, and then, where the bot would quit, writing
## the plate's inputs from that frame's exact camera position: `<name>_blockout.png` (the world as flat masses with a thin line on its depth edges, every
## humanoid, pickup, steam, ember, flame, contact shadow, lamp shaft and cue hidden), `<name>_depth.png` (the view depth, plate_depth.gdshader's 16 bits in
## red and green) and `<name>.json` (the camera: VideoPlateCamera). The plate camera has the frame's position, aims along the shot's mean view and is wider
## than the frames (VideoPlateLook's margin), so a pan, a tilt or a zoom about the position stays inside the plate.
## Run it with tools/video/plate_capture.sh. Arguments after `--`, besides the cine bot's:
##   --plate-shot=<key>        the shot (video/stills/<key>.tres or video/shots/<key>.tres); --shot-from / --shot-to pick the frame (the window [from, to) of one frame)
##   --plate-name=<name>       the files' name (default plate_0)
##   --plate-flat=1            the world's own look, not the blockout (and no line): the unpainted capture of the motion check
##   --plate-fov=<deg>         the plate's horizontal FOV (default: covers the shot's frames, plus the margin)
##   --plate-size=WxH          the picture's size (default VideoPlateLook's)
## The look pieces are the director's: leave the ink and the plate piece out (`--shot-skip=ink.tres,plate.tres`) and turn the blockout on
## (`--shot-set=world.tres.blockout=true`), as the script does.

const LINE_SHADER := preload("res://video/shaders/blockout_line.gdshader")
const DEPTH_SHADER := preload("res://video/shaders/plate_depth.gdshader")
const LOOK_FALLBACK := "res://video/look/street_night/plate.tres"

var _plate_key: String = ""
var _plate_name: String = "plate_0"
var _plate_flat: bool = false
var _plate_fov: float = 0.0
var _plate_size: Vector2i = Vector2i.ZERO


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--plate-shot="):
			_plate_key = arg.trim_prefix("--plate-shot=")
		elif arg.begins_with("--plate-name="):
			_plate_name = arg.trim_prefix("--plate-name=")
		elif arg == "--plate-flat=1":
			_plate_flat = true
		elif arg.begins_with("--plate-fov="):
			_plate_fov = float(arg.trim_prefix("--plate-fov="))
		elif arg.begins_with("--plate-size="):
			var parts := arg.trim_prefix("--plate-size=").split("x")
			if parts.size() == 2:
				_plate_size = Vector2i(int(parts[0]), int(parts[1]))
	if _plate_key != "":
		for dir in ["res://video/stills/", "res://video/shots/"]:
			if ResourceLoader.exists(dir + _plate_key + ".tres"):
				shot = load(dir + _plate_key + ".tres") as VideoStillShot
				break
	super._ready()


func _quit() -> void:
	if _plate_key != "":
		await _capture_plate()
	await super._quit()


## The plate's look: the shot's location's plate.tres, else the street's (the capture's values are the same everywhere).
func _look() -> VideoPlateLook:
	var path := "res://video/look/%s/plate.tres" % String(cine.location)
	var look := load(path) as VideoPlateLook if ResourceLoader.exists(path) else null
	if look == null:
		look = load(LOOK_FALLBACK) as VideoPlateLook if ResourceLoader.exists(LOOK_FALLBACK) else VideoPlateLook.new()
	return look


func _capture_plate() -> void:
	Engine.time_scale = 0.0
	var look := _look()
	var live := get_viewport().get_camera_3d()
	if live == null:
		push_error("plate_bot: no camera to capture from")
		return
	var size := _plate_size if _plate_size != Vector2i.ZERO else look.capture_size
	var view := plate_view(live, look, size)
	var camera_data := VideoPlateCamera.from_pose(view.xform, view.fov_deg, size, live.near, live.far, look.depth_far_m)
	var hidden := look.capture_hidden(level)
	for node in hidden:
		node.visible = false
	log_line("PLATE %s: %d nodes hidden, fov %.1f (frame %.1f), size %s" % [_plate_name, hidden.size(), view.fov_deg, live.fov, size])

	var viewport := SubViewport.new()
	viewport.size = size
	viewport.own_world_3d = false
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var camera := Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = view.fov_deg
	camera.near = live.near
	camera.far = live.far
	viewport.add_child(camera)
	add_child(viewport)
	camera.global_transform = view.xform
	camera.make_current()

	var line_quad: PlateScreenQuad = null
	if not _plate_flat:
		line_quad = PlateScreenQuad.new("BlockoutLineQuad", LINE_SHADER, Material.RENDER_PRIORITY_MAX)
		line_quad.material().set_shader_parameter(&"line_color", look.line_color)
		line_quad.material().set_shader_parameter(&"width_px", look.line_width_px)
		line_quad.material().set_shader_parameter(&"step_share", look.line_step_share)
		level.add_child(line_quad)
	await _settle(4)
	var color_image := viewport.get_texture().get_image()
	color_image.convert(Image.FORMAT_RGB8)
	var color_path := out_dir.path_join("%s_%s.png" % [_plate_name, "flat" if _plate_flat else "blockout"])
	log_line("PLATE %s color %s err=%d" % [_plate_name, color_path, color_image.save_png(color_path)])

	if line_quad != null:
		line_quad.visible = false
	var depth_quad := PlateScreenQuad.new("PlateDepthQuad", DEPTH_SHADER, Material.RENDER_PRIORITY_MAX)
	depth_quad.material().set_shader_parameter(&"far_m", look.depth_far_m)
	level.add_child(depth_quad)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	camera.environment = env
	await _settle(3)
	var depth_image := viewport.get_texture().get_image()
	depth_image.convert(Image.FORMAT_RGB8)
	var depth_path := out_dir.path_join("%s_depth.png" % _plate_name)
	log_line("PLATE %s depth %s err=%d" % [_plate_name, depth_path, depth_image.save_png(depth_path)])

	var json := FileAccess.open(out_dir.path_join("%s.json" % _plate_name), FileAccess.WRITE)
	if json != null:
		json.store_string(camera_data.to_json({"shot": _plate_key, "frame_fov_deg": live.fov, "frame_origin": [live.global_position.x, live.global_position.y, live.global_position.z],
				"flat": _plate_flat}))
		json.close()
	if line_quad != null:
		line_quad.queue_free()
	depth_quad.queue_free()
	viewport.queue_free()


func _settle(frames: int) -> void:
	for _i in frames:
		await RenderingServer.frame_post_draw


## The plate camera: the live camera's position; the shot's mean view direction (a moving camera shot's keys sampled across its window, else the live
## camera's own); the FOV that holds every sampled frame's frustum, plus the margin, at most the look's maximum. `--plate-fov=` wins.
func plate_view(live: Camera3D, look: VideoPlateLook, size: Vector2i) -> Dictionary:
	var forward := -live.global_basis.z
	var samples: Array[Dictionary] = []
	var moving := shot is CineShot and cine.camera != null and (shot as CineShot).window_to_s > (shot as CineShot).window_from_s
	if moving:
		var moving_shot := shot as CineShot
		var mean := Vector3.ZERO
		var t := moving_shot.window_from_s
		while t <= moving_shot.window_to_s + 0.0001:
			var pose := CineCamera.sample(cine.camera.keys, t, cine.camera.origin, cine.camera.actor_points)
			var f := (pose.look_at - pose.position).normalized()
			samples.append({forward = f, fov = pose.fov_deg})
			mean += f
			t += 1.0 / float(cine.out_fps)
		if mean.length() > 0.001:
			forward = mean.normalized()
	else:
		samples.append({forward = forward, fov = live.fov})
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.999 else Vector3.FORWARD
	var basis := Basis.looking_at(forward, up)
	var aspect := float(size.y) / float(size.x)
	# The widest tangent (x) any sampled frame's corner needs, seen from the plate's axis.
	var need := 0.0
	for sample in samples:
		var frame_basis := Basis.looking_at(sample.forward, up)
		var tx := tan(deg_to_rad(float(sample.fov)) * 0.5)
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var ray: Vector3 = (frame_basis * Vector3(corner.x * tx, corner.y * tx * aspect, -1.0)).normalized()
			var local := basis.inverse() * ray
			if local.z < -0.01:
				need = maxf(need, maxf(absf(local.x / -local.z), absf(local.y / -local.z) / aspect))
	var fov := rad_to_deg(2.0 * atan(need)) + look.margin_deg
	if _plate_fov > 0.0:
		fov = _plate_fov
	fov = minf(fov, look.max_fov_deg)
	return {xform = Transform3D(basis, live.global_position), fov_deg = fov}
