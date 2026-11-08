class_name CineSpikeLook
extends Node
## The Phase 0 spike's look, stage by stage on top of the game's own scene (P0-SPIKE). Four things and nothing
## else, applied cumulatively, so every stage is the one before plus one change and nothing is ever undone:
##   a  the game's plain look (nothing applied)
##   b  + hand-placed night light: the moon, a sodium lamp, a rim light, volumetric fog and glow
##   c  + flat paint: video/shaders/flat_paint_env.gdshader swapped onto the shared trim material
##   d  + ink: the screen-space ink pass (video/shaders/ink_screen.gdshader), the game's constant-width edge
##      pass hidden, the characters' hull thinned and tinted to the same ink
##   e  + the palette LUT (tools/video/palette_lut.py) on Environment.adjustment_color_correction
## Every value is in `data` (spike_look.tres). Only the Environment, the Sun, the trim material, the hull
## materials' ink and Tuning's runtime values (never its presets) are written; nothing under game/ is touched.
## The level re-applies its section light only while a blend runs or the section changes, so with the street's
## light settled (the act waits for it) these writes stand; fog_sky_affect goes through Tuning, which the level
## reads every physics frame.

const PAINT_SHADER := preload("res://video/shaders/flat_paint_env.gdshader")
const INK_SHADER := preload("res://video/shaders/ink_screen.gdshader")
const HEAD_SHADER_CODE := "shader_type spatial;\nrender_mode unshaded, fog_disabled;\nuniform vec3 glow_color : source_color = vec3(1.0);\nuniform float glow_energy = 12.0;\nvoid fragment() { ALBEDO = glow_color * glow_energy; }\n"
const INK_PRIORITY := Material.RENDER_PRIORITY_MIN + 2

## The numbers (assigned in spike_bot.tscn from spike_look.tres).
@export var data: CineSpikeLookData

var stage: StringName = &"a"

var _level: LevelRoot
var _sun: DirectionalLight3D
var _env: Environment
var _camera_source: Callable
var _lamp: OmniLight3D
var _rim: SpotLight3D
var _lamp_head: MeshInstance3D
var _pole: Node3D
var _ink_quad: MeshInstance3D
var _ink_material: ShaderMaterial
var _original_trim_shader: Shader
var _punk_feet: Vector3 = Vector3.ZERO
var _lut_texture: ImageTexture3D


func _init() -> void:
	process_priority = 100


## Find the level's sun and environment. `camera_source` returns the camera the frame is taken with.
func setup(level: LevelRoot, camera_source: Callable) -> void:
	_level = level
	_sun = level.get_node_or_null("Sun") as DirectionalLight3D
	_env = LookPost.find_environment(level)
	_camera_source = camera_source
	_original_trim_shader = ToonMaterials.trim().shader


## Where the Punk's feet are: the lamp and rim light are placed from here.
func set_punk_feet(at: Vector3) -> void:
	_punk_feet = at


## Apply stage `which` (one of b, c, d, e) on top of the ones before it.
func apply_stage(which: StringName) -> void:
	stage = which
	match which:
		&"b":
			_apply_light()
		&"c":
			_apply_paint()
		&"d":
			_apply_ink()
		&"e":
			_apply_lut()


func _process(_delta: float) -> void:
	_update_ink_uniforms()


# --- b: light ------------------------------------------------------------------------------


func _apply_light() -> void:
	var d := data
	Tuning.set_value(&"section_fog_sky_affect", d.fog_sky_affect)
	Tuning.set_value(&"look_shadow_level", d.toon_shadow_level)
	if d.night_grade_off:
		Tuning.set_value(&"look_grade_enabled", false)
	if _sun != null:
		_sun.rotation_degrees = Vector3(-d.moon_elevation_deg, d.moon_yaw_deg, 0.0)
		_sun.light_color = d.moon_color
		_sun.light_energy = d.moon_energy
		_sun.shadow_enabled = true
		_sun.light_volumetric_fog_energy = d.moon_volumetric_energy
	if _env != null:
		var sky := _env.sky.sky_material as ProceduralSkyMaterial if _env.sky != null else null
		if sky != null:
			sky.sky_top_color = d.sky_top
			sky.sky_horizon_color = d.sky_horizon
			sky.ground_horizon_color = d.ground_horizon
			sky.ground_bottom_color = d.ground_bottom
		_env.ambient_light_color = d.ambient_color
		_env.ambient_light_energy = d.ambient_energy
		_env.fog_enabled = true
		_env.fog_light_color = d.fog_color
		_env.fog_density = d.fog_density
		_env.volumetric_fog_enabled = d.vfog_enabled
		_env.volumetric_fog_density = d.vfog_density
		_env.volumetric_fog_albedo = d.vfog_albedo
		_env.volumetric_fog_emission = d.vfog_emission
		_env.volumetric_fog_anisotropy = d.vfog_anisotropy
		_env.volumetric_fog_length = d.vfog_length_m
		_env.glow_enabled = d.glow_enabled
		_env.glow_intensity = d.glow_intensity
		_env.glow_strength = d.glow_strength
		_env.glow_bloom = d.glow_bloom
		_env.glow_hdr_threshold = d.glow_hdr_threshold
		_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		for i in mini(d.glow_levels.size(), 7):
			_env.set_glow_level(i, d.glow_levels[i])
	RenderingServer.environment_set_volumetric_fog_volume_size(d.volume_size, d.volume_depth)
	_build_lamp()
	_build_rim()


func _build_lamp() -> void:
	var d := data
	var at := _punk_feet + d.lamp_offset
	_lamp = OmniLight3D.new()
	_lamp.name = "SpikeLamp"
	_lamp.light_color = d.lamp_color
	_lamp.light_energy = d.lamp_energy
	_lamp.omni_range = d.lamp_range_m
	_lamp.omni_attenuation = d.lamp_attenuation
	_lamp.light_volumetric_fog_energy = d.lamp_volumetric_energy
	_lamp.shadow_enabled = true
	_lamp.shadow_blur = 1.0
	_level.add_child(_lamp)
	_lamp.global_position = at
	# The lamp's visible head, an HDR disc that blooms, on a thin pole and arm.
	var shader := Shader.new()
	shader.code = HEAD_SHADER_CODE
	var head_material := ShaderMaterial.new()
	head_material.shader = shader
	head_material.set_shader_parameter(&"glow_color", d.lamp_color)
	head_material.set_shader_parameter(&"glow_energy", d.lamp_head_energy)
	var sphere := SphereMesh.new()
	sphere.radius = d.lamp_head_m * 0.5
	sphere.height = d.lamp_head_m
	_lamp_head = MeshInstance3D.new()
	_lamp_head.name = "SpikeLampHead"
	_lamp_head.mesh = sphere
	_lamp_head.material_override = head_material
	_lamp_head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_level.add_child(_lamp_head)
	_lamp_head.global_position = at
	var pole_material := StandardMaterial3D.new()
	pole_material.albedo_color = d.ink_color.lerp(d.fog_color, 0.5)
	pole_material.roughness = 1.0
	pole_material.metallic_specular = 0.0
	_pole = Node3D.new()
	_pole.name = "SpikePole"
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.06
	shaft_mesh.bottom_radius = 0.09
	shaft_mesh.height = at.y
	shaft.mesh = shaft_mesh
	shaft.material_override = pole_material
	_pole.add_child(shaft)
	shaft.position = Vector3(-0.55, at.y * 0.5, 0.0)
	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.5, 0.06, 0.06)
	arm.mesh = arm_mesh
	arm.material_override = pole_material
	_pole.add_child(arm)
	arm.position = Vector3(-0.32, at.y, 0.0)
	_level.add_child(_pole)
	_pole.global_position = Vector3(at.x, 0.0, at.z)


func _build_rim() -> void:
	var d := data
	_rim = SpotLight3D.new()
	_rim.name = "SpikeRim"
	_rim.light_color = d.rim_color
	_rim.light_energy = d.rim_energy
	_rim.spot_range = d.rim_range_m
	_rim.spot_angle = 38.0
	_rim.spot_attenuation = 0.6
	_rim.shadow_enabled = true
	_rim.light_volumetric_fog_energy = 0.0
	_level.add_child(_rim)
	_rim.global_position = _punk_feet + d.rim_offset
	_rim.look_at(_punk_feet + Vector3(0.0, 1.2, 0.0), Vector3.UP)


# --- c: paint ------------------------------------------------------------------------------


func _apply_paint() -> void:
	var d := data
	var trim := ToonMaterials.trim()
	trim.shader = PAINT_SHADER
	trim.set_shader_parameter(&"paint_lod", d.paint_lod)
	trim.set_shader_parameter(&"paint_bands", d.paint_bands)
	trim.set_shader_parameter(&"paint_band_soft", d.paint_band_soft)
	trim.set_shader_parameter(&"paint_shadow_tint", d.paint_shadow_tint)
	trim.set_shader_parameter(&"paint_shadow_level", d.paint_shadow_level)
	trim.set_shader_parameter(&"paint_mid_level", d.paint_mid_level)
	trim.set_shader_parameter(&"paint_ink_keep", d.paint_ink_keep)
	trim.set_shader_parameter(&"paint_grain", d.paint_grain)
	trim.set_shader_parameter(&"paint_grain_scale", d.paint_grain_scale)
	trim.set_shader_parameter(&"paint_break", d.paint_break)
	trim.set_shader_parameter(&"paint_break_scale", d.paint_break_scale)
	trim.set_shader_parameter(&"paint_sat", d.paint_sat)
	trim.set_shader_parameter(&"paint_value_gain", d.paint_value_gain)
	# The scissor material (the chain-link) keeps the game's shader: it needs the alpha scissor.


# --- d: ink --------------------------------------------------------------------------------


func _apply_ink() -> void:
	var d := data
	# The hull: thinner and tinted to the ink, so the screen pass carries the weight. This is a Tuning write
	# (a look_* change re-applies the look), so it comes before the grade is touched.
	Tuning.set_value(&"look_outline_px", d.hull_px)
	_tint_hulls()
	var post := _find_look_post()
	if post != null:
		# The game's constant-width edge pass is replaced, not stacked: the new pass does its job with weight.
		post.edge_quad().visible = false
	_ink_material = ShaderMaterial.new()
	_ink_material.shader = INK_SHADER
	_ink_material.render_priority = INK_PRIORITY
	_ink_material.set_shader_parameter(&"ink", d.ink_color)
	_ink_material.set_shader_parameter(&"alpha_max", d.ink_alpha)
	_ink_material.set_shader_parameter(&"debug_view", d.ink_debug_view)
	_ink_material.set_shader_parameter(&"width_thin_px", d.ink_width_thin_px)
	_ink_material.set_shader_parameter(&"width_heavy_px", d.ink_width_heavy_px)
	_ink_material.set_shader_parameter(&"lit_lost", d.ink_lit_lost)
	_ink_material.set_shader_parameter(&"lit_full", d.ink_lit_full)
	_ink_material.set_shader_parameter(&"lit_floor", d.ink_lit_floor)
	_ink_material.set_shader_parameter(&"depth_threshold", d.ink_depth_threshold)
	_ink_material.set_shader_parameter(&"normal_threshold", d.ink_normal_threshold)
	_ink_material.set_shader_parameter(&"env_major_m", d.ink_env_major_m)
	_ink_material.set_shader_parameter(&"fade_start_m", d.ink_fade_start_m)
	_ink_material.set_shader_parameter(&"fade_end_m", d.ink_fade_end_m)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	_ink_quad = MeshInstance3D.new()
	_ink_quad.name = "SpikeInkQuad"
	_ink_quad.mesh = mesh
	_ink_quad.extra_cull_margin = 16384.0
	_ink_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ink_quad.material_override = _ink_material
	add_child(_ink_quad)


## Every inverted-hull material in the scene gets the ink's colour (the hull's `ink` is never rewritten by the game).
func _tint_hulls() -> void:
	for node: Node in _level.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		for material: Material in [gi.material_overlay, gi.material_override.next_pass if gi.material_override != null else null]:
			var shader_material := material as ShaderMaterial
			if shader_material != null and shader_material.shader != null \
					and shader_material.shader.resource_path.ends_with("toon_outline.gdshader"):
				shader_material.set_shader_parameter(&"ink", data.ink_color)


func _find_look_post() -> LookPost:
	var found := _level.find_children("*", "LookPost", true, false)
	return found[0] as LookPost if not found.is_empty() else null


func _update_ink_uniforms() -> void:
	if _ink_material == null or not _camera_source.is_valid():
		return
	var camera := _camera_source.call() as Camera3D
	if camera == null:
		return
	var inv := camera.global_transform.affine_inverse()
	if _lamp != null:
		var key := inv * _lamp.global_position
		_ink_material.set_shader_parameter(&"key_view", Vector4(key.x, key.y, key.z, _lamp.omni_range))
	if _rim != null:
		var rim := inv * _rim.global_position
		_ink_material.set_shader_parameter(&"rim_view", Vector4(rim.x, rim.y, rim.z, _rim.spot_range))
	if _sun != null:
		_ink_material.set_shader_parameter(&"moon_dir_view", inv.basis * _sun.global_basis.z)


# --- e: palette ----------------------------------------------------------------------------


func _apply_lut() -> void:
	if _env == null:
		return
	var texture := load_lut(data.lut_path)
	if texture == null:
		push_warning("CineSpikeLook: no LUT at %s" % data.lut_path)
		return
	_lut_texture = texture
	# After LookPost has set the grade (adjustment_enabled, the game's own strip): ours replaces it.
	_env.adjustment_color_correction = texture
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
