class_name CineInkRig
extends Node
## The ink piece's per-frame worker (Phase 1, LD-INK), added under a level by VideoInkLook.apply(). It does
## nothing to the game's files; it swaps shaders on materials, adds nodes and writes uniforms:
##  - swaps video/shaders/cine_toon.gdshader and cine_outline.gdshader IN PLACE onto every character's art
##    material and hull (the nodes of group HumanoidRig.ART_GROUP, the player's first-person body included),
##    new ones as they spawn, so the rig's materials, atlas, detail mask and damage tiles stay;
##  - finds the scene's key (the lamp that lights the characters, or the sun) and writes its direction, in
##    view space, to the paint, the line and the screen ink every frame, with the boil seed (12 fps, from the
##    output frame) and the hatching's close-up fade;
##  - adds the rim lights that follow the nearest characters, the screen-space ink quad (the game's edge quad
##    hidden), the 2D cues (CineTwos, CineSmears, CineCues) and the finish pass's Compositor;
##  - assigns the location's palette LUT to the level's Environment.
## `frame_source` is the frame writer's output-frame counter (a Callable returning an int); without one the
## frame is counted from the physics frames at `output_fps`.

const TOON_SHADER := preload("res://video/shaders/cine_toon.gdshader")
const OUTLINE_SHADER := preload("res://video/shaders/cine_outline.gdshader")
const INK_SHADER := preload("res://video/shaders/ink_screen.gdshader")
const INK_PRIORITY := Material.RENDER_PRIORITY_MIN + 2
const RIM_NAME := "CineInkRim"
## How often (frames) the slow scans run: the lights of the level, the cameras that need the compositor.
const SCAN_EVERY := 20

var look: VideoInkLook
## The frame writer's output frame counter: a Callable returning the int index of the frame being rendered.
var frame_source: Callable = Callable()
## The finish pass's Compositor (null when the look has the post off or the renderer has no RenderingDevice).
var compositor: Compositor

var _level: Node
var _toon: Array[ShaderMaterial] = []
var _hulls: Array[ShaderMaterial] = []
var _extras: Dictionary[int, Array] = {}
var _rigs: Array[HumanoidRig] = []
var _lights: Array[Light3D] = []
var _rim_lights: Array[OmniLight3D] = []
var _sun: DirectionalLight3D
var _look_post: LookPost
var _env: Environment
var _lut: ImageTexture3D
var _ink_material: ShaderMaterial
var _ink_quad: MeshInstance3D
var _twos: CineTwos
var _smears: CineSmears
var _cues: CineCues
var _key_world: Vector3 = Vector3.ZERO
var _key_is_point: bool = false
var _key_range: float = 0.0
var _frame: int = 0
var _hatch_amount: float = 0.0


func _init() -> void:
	process_priority = 95


## Called by VideoInkLook.apply() once the rig is in the tree.
func setup(level: Node) -> void:
	_level = level
	_sun = level.get_node_or_null("Sun") as DirectionalLight3D
	_env = LookPost.find_environment(level)
	var found := level.find_children("*", "LookPost", true, false)
	_look_post = found[0] as LookPost if not found.is_empty() else null
	if look.screen_ink:
		_build_ink_quad()
	_twos = CineTwos.new()
	_twos.name = "CineTwos"
	_twos.rig = self
	add_child(_twos)
	_smears = CineSmears.new()
	_smears.name = "CineSmears"
	add_child(_smears)
	_cues = CineCues.new()
	_cues.name = "CineCues"
	_cues.look = look
	_cues.rig = self
	add_child(_cues)
	_build_rim_lights()
	_push_options()
	if look.post_enabled:
		compositor = CinePostEffect.make_compositor(look)
		_assign_compositor()
	if look.lut_path != "":
		_lut = load_lut(look.lut_path)
		_assign_lut()
	_apply_shadow_quality()
	_scan()


## The soft-shadow filter and the directional atlas, raised: a cast shadow's texel steps are too fine for the
## posterised bands to hide otherwise. Runtime RenderingServer settings, video only.
func _apply_shadow_quality() -> void:
	if look.shadow_quality > 0:
		RenderingServer.directional_soft_shadow_filter_set_quality(look.shadow_quality as RenderingServer.ShadowQuality)
		RenderingServer.positional_soft_shadow_filter_set_quality(look.shadow_quality as RenderingServer.ShadowQuality)
	if look.shadow_atlas_size > 0:
		RenderingServer.directional_shadow_atlas_set_size(look.shadow_atlas_size, true)


## Re-read the look's values (after a value was changed in code): the cues' options and every material.
func refresh() -> void:
	_push_options()
	for material in _toon:
		_push_paint(material)
	for hull in _hulls:
		_push_hull(hull)


## The index of the frame being rendered, at `look.output_fps`.
func output_frame() -> int:
	if frame_source.is_valid():
		return int(frame_source.call())
	return int(floorf(float(Engine.get_physics_frames()) * look.output_fps / float(Engine.physics_ticks_per_second)))


## How many smear ribbons are drawn right now.
func smears_drawing() -> int:
	return _smears.drawing_count()


## Fire the flash frame and speed lines at world point `at`, as a finisher's hit does.
func trigger_cues(at: Vector3) -> void:
	_cues.trigger(at)


## The hatching's current amount (0..1), for tests and the act's log.
func hatch_amount() -> float:
	return _hatch_amount


## The key's world position or direction last found (a lamp's position, or the sun's direction to the light).
func key_world() -> Vector3:
	return _key_world


func _process(_delta: float) -> void:
	_frame += 1
	_adopt()
	if _frame % SCAN_EVERY == 1:
		_scan()
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	_update_key(camera)
	_update_hatch(camera)
	var seed_value := float(int(floorf(float(output_frame()) * look.boil_fps / look.output_fps)) % 1000)
	var view_basis := camera.global_transform.affine_inverse().basis
	var key_view := view_basis * _key_dir_world(camera)
	for material in _toon:
		material.set_shader_parameter(&"key_dir_view", key_view)
		material.set_shader_parameter(&"hatch_on", _hatch_amount)
	for hull in _hulls:
		hull.set_shader_parameter(&"key_dir_view", key_view)
		hull.set_shader_parameter(&"boil_seed", seed_value)
		for extra: ShaderMaterial in _extras.get(hull.get_instance_id(), []):
			extra.set_shader_parameter(&"key_dir_view", key_view)
			extra.set_shader_parameter(&"boil_seed", seed_value)
	_update_rim_lights(camera)
	_update_ink_quad(camera)
	if _look_post != null and is_instance_valid(_look_post):
		_look_post.edge_quad().visible = false
	if _frame % SCAN_EVERY == 2:
		_assign_compositor()
		_assign_lut()


# --- the materials -------------------------------------------------------------------------


## Swap the shaders onto characters that are new since the last frame.
func _adopt() -> void:
	for node in get_tree().get_nodes_in_group(HumanoidRig.ART_GROUP):
		var mesh := node as MeshInstance3D
		if mesh == null or not mesh.is_inside_tree():
			continue
		var material := mesh.material_override as ShaderMaterial
		if material != null and material.shader != TOON_SHADER and _is_game_toon(material.shader):
			material.shader = TOON_SHADER
			_toon.append(material)
			_push_paint(material)
		elif material != null and material.shader == TOON_SHADER and not _toon.has(material):
			_toon.append(material)
			_push_paint(material)
		var hull := mesh.material_overlay as ShaderMaterial
		if hull != null and hull.shader != OUTLINE_SHADER and _is_game_outline(hull.shader):
			hull.shader = OUTLINE_SHADER
			_hulls.append(hull)
			_push_hull(hull)
		elif hull != null and hull.shader == OUTLINE_SHADER and not _hulls.has(hull):
			_hulls.append(hull)
			_push_hull(hull)
		var rig := _rig_of(mesh)
		if rig != null and not _rigs.has(rig):
			_rigs.append(rig)


func _is_game_toon(shader: Shader) -> bool:
	return shader != null and shader.resource_path.ends_with("toon.gdshader")


func _is_game_outline(shader: Shader) -> bool:
	return shader != null and shader.resource_path.ends_with("toon_outline.gdshader")


func _rig_of(node: Node) -> HumanoidRig:
	var up := node.get_parent()
	while up != null:
		if up is HumanoidRig:
			return up as HumanoidRig
		up = up.get_parent()
	return null


## The look's paint values onto a character material.
func _push_paint(material: ShaderMaterial) -> void:
	material.set_shader_parameter(&"cine_band_1", look.band_1)
	material.set_shader_parameter(&"cine_band_2", look.band_2)
	material.set_shader_parameter(&"cine_mid", look.mid_level)
	material.set_shader_parameter(&"cine_shadow_level", look.shadow_level)
	material.set_shader_parameter(&"cine_shadow", look.shadow_color)
	material.set_shader_parameter(&"cine_shadow_amount", look.shadow_amount)
	material.set_shader_parameter(&"cine_fill", look.fill)
	material.set_shader_parameter(&"cine_point_gain", look.point_gain)
	material.set_shader_parameter(&"cine_dir_floor", look.dir_floor)
	material.set_shader_parameter(&"term_soft", look.term_soft)
	material.set_shader_parameter(&"term_wobble", look.term_wobble)
	material.set_shader_parameter(&"grain_amount", look.grain_amount)
	material.set_shader_parameter(&"grain_scale", look.grain_scale)
	material.set_shader_parameter(&"key_color", look.rim_color)
	material.set_shader_parameter(&"cine_rim_strength", look.rim_strength)
	material.set_shader_parameter(&"cine_rim_cut", look.rim_cut)
	material.set_shader_parameter(&"cine_rim_key", look.rim_key)
	material.set_shader_parameter(&"cine_rim_curve", look.rim_curve)
	material.set_shader_parameter(&"cine_rim_wobble", look.rim_wobble)
	material.set_shader_parameter(&"hatch_tex", CineHatchTam.texture())
	material.set_shader_parameter(&"hatch_scale", look.hatch_scale)
	material.set_shader_parameter(&"hatch_dark", look.hatch_dark)
	material.set_shader_parameter(&"ink_color", look.ink_color)


## The look's line values onto a hull material, with its sketch passes when the look asks for them.
func _push_hull(hull: ShaderMaterial) -> void:
	_push_hull_values(hull, 0.0, 1.0, 0.0)
	var extras: Array = []
	if look.sketch_mode:
		var previous := hull
		for i in look.sketch_extra_passes:
			var extra := ShaderMaterial.new()
			extra.shader = OUTLINE_SHADER
			extra.render_priority = hull.render_priority
			for name_text in ["near_m", "far_m", "fp_scale", "lens_fade_m", "mode"]:
				extra.set_shader_parameter(StringName(name_text), hull.get_shader_parameter(StringName(name_text)))
			_push_hull_values(extra, look.sketch_jitter_px * (1.0 if i == 0 else -1.3), look.sketch_width_scale, float(i + 1))
			previous.next_pass = extra
			previous = extra
			extras.append(extra)
	else:
		hull.next_pass = null
	_extras[hull.get_instance_id()] = extras


func _push_hull_values(material: ShaderMaterial, jitter_px: float, width_scale: float, pass_id: float) -> void:
	material.set_shader_parameter(&"ink", look.ink_color)
	material.set_shader_parameter(&"width_px", look.hull_px)
	material.set_shader_parameter(&"heavy_mult", look.heavy_mult)
	material.set_shader_parameter(&"thin_mult", look.thin_mult)
	material.set_shader_parameter(&"far_thin", look.far_thin)
	material.set_shader_parameter(&"thin_start_m", look.thin_start_m)
	material.set_shader_parameter(&"thin_end_m", look.thin_end_m)
	material.set_shader_parameter(&"wander", look.wander)
	material.set_shader_parameter(&"wander_scale", look.wander_scale)
	material.set_shader_parameter(&"jitter_px", absf(jitter_px))
	material.set_shader_parameter(&"width_scale", width_scale)
	material.set_shader_parameter(&"pass_id", pass_id)


func _push_options() -> void:
	_twos.enabled = look.on_twos
	_twos.hold = look.twos_hold
	_smears.enabled = look.smears
	_smears.min_speed = look.smear_min_speed
	_smears.samples = look.smear_samples
	_smears.width_m = look.smear_width_m
	_smears.alpha = look.smear_alpha
	_smears.color = look.smear_color
	if _ink_material != null:
		_push_ink_values()


# --- the key -------------------------------------------------------------------------------


## Rebuild the list of the level's lights (not our own rim lights).
func _scan() -> void:
	_lights.clear()
	for node in _level.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light != null and not String(light.name).begins_with(RIM_NAME):
			_lights.append(light)
			if light.shadow_enabled and look.shadow_blur_min > 0.0:
				light.shadow_blur = maxf(light.shadow_blur, look.shadow_blur_min)


## The key: the point light that lights the nearest character most, or the sun.
func _update_key(camera: Camera3D) -> void:
	var focus := _focus_point(camera)
	var best := 0.0
	var best_light: Light3D
	for light in _lights:
		if not is_instance_valid(light) or not light.is_visible_in_tree() or light is DirectionalLight3D:
			continue
		var range_m := 0.0
		if light is OmniLight3D:
			range_m = (light as OmniLight3D).omni_range
		elif light is SpotLight3D:
			range_m = (light as SpotLight3D).spot_range
		var d := light.global_position.distance_to(focus)
		if d >= range_m:
			continue
		var luma := light.light_color.get_luminance() * light.light_energy
		var score := luma * (1.0 - d / range_m)
		if score > best:
			best = score
			best_light = light
	if best_light != null:
		_key_is_point = true
		_key_world = best_light.global_position
		_key_range = (best_light as OmniLight3D).omni_range if best_light is OmniLight3D else (best_light as SpotLight3D).spot_range
	elif _sun != null and _sun.light_energy > 0.0:
		_key_is_point = false
		_key_world = _sun.global_basis.z.normalized()
		_key_range = 0.0
	else:
		_key_is_point = false
		_key_world = look.key_dir_fallback.normalized()
		_key_range = 0.0


## From a surface at the focus to the key, in world space (a unit vector).
func _key_dir_world(camera: Camera3D) -> Vector3:
	if _key_is_point:
		return (_key_world - _focus_point(camera)).normalized()
	return _key_world


## The point the key is judged for: the nearest character (not the player) to the camera, else 3 m ahead.
func _focus_point(camera: Camera3D) -> Vector3:
	var rig := _nearest_rig(camera)
	if rig != null:
		return rig.global_position + Vector3.UP * 1.0
	return camera.global_position - camera.global_basis.z * 3.0


func _nearest_rig(camera: Camera3D) -> HumanoidRig:
	var player := get_tree().get_first_node_in_group(&"player")
	var best: HumanoidRig
	var best_d := INF
	for rig in _rigs:
		if not is_instance_valid(rig) or not rig.is_inside_tree():
			continue
		if player != null and player.is_ancestor_of(rig):
			continue
		var d := rig.global_position.distance_to(camera.global_position)
		if d < best_d:
			best_d = d
			best = rig
	return best


## Hatching comes in as a character gets close (its eyes or its middle inside hatch_near_m).
func _update_hatch(camera: Camera3D) -> void:
	_hatch_amount = look.hatch_force
	if not look.hatch_enabled:
		return
	var rig := _nearest_rig(camera)
	if rig == null:
		return
	var d := minf(rig.global_position.distance_to(camera.global_position) - 1.0,
			rig.get_point_position(&"EyePoint").distance_to(camera.global_position))
	var close := 1.0 - smoothstep(look.hatch_near_m, maxf(look.hatch_far_m, look.hatch_near_m + 0.01), d)
	_hatch_amount = maxf(_hatch_amount, close)


# --- the rim lights ------------------------------------------------------------------------


func _build_rim_lights() -> void:
	if not look.rim_lights:
		return
	for i in look.rim_light_count:
		var light := OmniLight3D.new()
		light.name = "%s%d" % [RIM_NAME, i]
		light.light_color = look.rim_light_color
		light.light_energy = 0.0
		light.omni_range = look.rim_light_range_m
		light.omni_attenuation = 1.0
		light.shadow_enabled = false
		light.light_specular = 0.0
		light.light_volumetric_fog_energy = 0.0
		_level.add_child(light)
		_rim_lights.append(light)


## Each rim light sits behind its character (from the camera), toward the key's side, above his head.
func _update_rim_lights(camera: Camera3D) -> void:
	if _rim_lights.is_empty():
		return
	var player := get_tree().get_first_node_in_group(&"player")
	var near: Array[HumanoidRig] = []
	for rig in _rigs:
		if is_instance_valid(rig) and rig.is_inside_tree() and not (player != null and player.is_ancestor_of(rig)):
			near.append(rig)
	near.sort_custom(func(a: HumanoidRig, b: HumanoidRig) -> bool:
		return a.global_position.distance_squared_to(camera.global_position) < b.global_position.distance_squared_to(camera.global_position))
	for i in _rim_lights.size():
		var light := _rim_lights[i]
		if i >= near.size():
			light.light_energy = 0.0
			continue
		var at := near[i].global_position + Vector3.UP * 1.0
		var back := at - camera.global_position
		back.y = 0.0
		back = back.normalized() if back.length() > 0.001 else -camera.global_basis.z
		var to_key := _key_dir_world(camera)
		to_key.y = 0.0
		var side := to_key.normalized() if to_key.length() > 0.001 else back.cross(Vector3.UP)
		light.global_position = at + back * look.rim_light_offset.z + side * look.rim_light_offset.x + Vector3.UP * (look.rim_light_offset.y - 1.0)
		light.light_energy = look.rim_light_energy
		light.light_color = look.rim_light_color
		light.omni_range = look.rim_light_range_m


# --- the screen ink ------------------------------------------------------------------------


func _build_ink_quad() -> void:
	_ink_material = ShaderMaterial.new()
	_ink_material.shader = INK_SHADER
	_ink_material.render_priority = INK_PRIORITY
	_push_ink_values()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	_ink_quad = MeshInstance3D.new()
	_ink_quad.name = "CineInkQuad"
	_ink_quad.mesh = mesh
	_ink_quad.extra_cull_margin = 16384.0
	_ink_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ink_quad.material_override = _ink_material
	add_child(_ink_quad)


func _push_ink_values() -> void:
	_ink_material.set_shader_parameter(&"ink", look.ink_color)
	_ink_material.set_shader_parameter(&"alpha_max", look.ink_alpha)
	_ink_material.set_shader_parameter(&"width_thin_px", look.ink_width_thin_px)
	_ink_material.set_shader_parameter(&"width_heavy_px", look.ink_width_heavy_px)
	_ink_material.set_shader_parameter(&"depth_threshold", look.ink_depth_threshold)
	_ink_material.set_shader_parameter(&"normal_threshold", look.ink_normal_threshold)
	_ink_material.set_shader_parameter(&"env_major_m", look.ink_env_major_m)
	_ink_material.set_shader_parameter(&"fade_start_m", look.ink_fade_start_m)
	_ink_material.set_shader_parameter(&"fade_end_m", look.ink_fade_end_m)
	_ink_material.set_shader_parameter(&"wobble", look.ink_wobble)
	_ink_material.set_shader_parameter(&"wobble_scale", look.ink_wobble_scale)
	_ink_material.set_shader_parameter(&"crease_gain", look.ink_crease_gain)


## The ink pass's lights, in view space: the key lamp (a position, or off when the key is the sun), the
## nearest rim light, and the sun's direction.
func _update_ink_quad(camera: Camera3D) -> void:
	if _ink_material == null:
		return
	var inv := camera.global_transform.affine_inverse()
	if _key_is_point:
		var key := inv * _key_world
		_ink_material.set_shader_parameter(&"key_view", Vector4(key.x, key.y, key.z, _key_range))
	else:
		_ink_material.set_shader_parameter(&"key_view", Vector4(0.0, 0.0, 0.0, 0.0))
	var rim_view := Vector4(0.0, 0.0, 0.0, 0.0)
	for light in _rim_lights:
		if light.light_energy > 0.0:
			var p := inv * light.global_position
			rim_view = Vector4(p.x, p.y, p.z, light.omni_range)
			break
	_ink_material.set_shader_parameter(&"rim_view", rim_view)
	if _sun != null:
		_ink_material.set_shader_parameter(&"moon_dir_view", inv.basis * _sun.global_basis.z)


# --- the post and the palette --------------------------------------------------------------


## The finish pass's compositor on the level's WorldEnvironment and on every camera in the tree that has none
## (the frame writer's SubViewport camera among them: a camera's own compositor wins over the world's).
func _assign_compositor() -> void:
	if compositor == null:
		return
	for node in _level.find_children("*", "WorldEnvironment", true, false):
		(node as WorldEnvironment).compositor = compositor
	for node in get_tree().root.find_children("*", "Camera3D", true, false):
		var camera := node as Camera3D
		if camera.compositor == null:
			camera.compositor = compositor


func _assign_lut() -> void:
	if _lut != null and _env != null and _env.adjustment_color_correction != _lut:
		_env.adjustment_color_correction = _lut
		_env.adjustment_enabled = true


## An ImageTexture3D from a LUT strip PNG (N slices of N x N: slice = blue, x = red, y = green), or null.
static func load_lut(path: String) -> ImageTexture3D:
	if not FileAccess.file_exists(path):
		return null
	var strip := Image.load_from_file(path)
	if strip == null or strip.is_empty():
		return null
	strip.convert(Image.FORMAT_RGB8)
	var n := strip.get_height()
	if n < 2 or strip.get_width() != n * n:
		return null
	var slices: Array[Image] = []
	for b in n:
		slices.append(strip.get_region(Rect2i(b * n, 0, n, n)))
	var texture := ImageTexture3D.new()
	texture.create(Image.FORMAT_RGB8, n, n, n, false, slices)
	return texture
