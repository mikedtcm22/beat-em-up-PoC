class_name VideoWorldLook
extends VideoLookPiece
## The world's light, paint and atmosphere for one location (LD-WORLD; docs/video/P1.md, PLAN.md section 4 parts 1, 2, 4 and 7):
## `apply(level)` turns the level's own section light and sun off, lays one location's rig on it and leaves a VideoWorldRig
## under the level. One `.tres` per location (`res://video/look/<location>/world.tres`); every value is in it. It does:
##  - the LIGHT: one motivated key, one accent of the opposite temperature, ONE shadow caster, and the practicals (sodium lamp
##    posts, fire barrels, fire from below) placed from data, each a hard-edged pool, not a falloff;
##  - the PAINT: the flat-paint environment shader (video/shaders/flat_paint_env*.gdshader) on the kit's shared materials;
##  - the SKY and MATTES: a painted sky shader with a banded-halo disc, painted matte cards behind the playfield;
##  - the ATMOSPHERE: flat haze bands (not a depth fog), banded halo cards on the lights, and code-made embers, steam and dust.
## Nothing here is used by the game; it writes only Tuning's runtime values (never its presets), the Environment, the Sun, the shared
## trim materials' shader and nodes it adds. Rim lights belong to LD-INK: the key's colour and direction are published for it (see
## VideoWorldRig.hook()).

const PAINT_SHADER := preload("res://video/shaders/flat_paint_env.gdshader")
const PAINT_SCISSOR_SHADER := preload("res://video/shaders/flat_paint_env_scissor.gdshader")
const PAINT_PROP_SHADER := preload("res://video/shaders/flat_paint_prop.gdshader")
const SKY_SHADER := preload("res://video/shaders/sky_painted.gdshader")
const HAZE_SHADER := preload("res://video/shaders/haze_band.gdshader")
const HALO_SHADER := preload("res://video/shaders/haze_halo.gdshader")
const MATTE_SHADER := preload("res://video/shaders/haze_matte.gdshader")
const ROOT_NAME := &"VideoWorldRig"
## The haze quad draws before the ink (the ink's priority is MIN + 2) and after LookPost's own edge quad (MIN + 1).
const HAZE_PRIORITY := Material.RENDER_PRIORITY_MIN

## The shader the trim materials had before any look replaced it (kept across applications, so a second look restores it first).
static var _game_trim_shader: Shader
static var _game_scissor_shader: Shader
## The paint uniforms the last look wrote, so the next one can clear what it does not set (a look leaves nothing of another).
static var _painted: Array[StringName] = []

@export_group("Location")
## street_night, roofs_dusk or boss_fire; and the level section its positions are in (0 street, 1 roofs, 2 boss roof).
@export var location: StringName = &"street_night"
@export_range(0, 2) var section: int = 0
## Frames a second the fire's flicker is re-rolled at (from the frame number).
@export_range(1, 60) var flicker_fps: int = 12

@export_group("Sun (the moon, or the sun)")
@export var sun_color: Color = Color(0.42, 0.52, 0.95)
@export_range(0.0, 3.0) var sun_energy: float = 0.5
@export_range(2.0, 85.0) var sun_elevation_deg: float = 38.0
@export_range(-180.0, 180.0) var sun_yaw_deg: float = 70.0
## Whether the sun casts the shot's shadow. Off when a light of `lights` does (one shadow caster a shot).
@export var sun_shadow: bool = true
@export_range(0.0, 8.0) var sun_shadow_blur: float = 1.5
@export_range(10.0, 200.0) var sun_shadow_max_m: float = 45.0
@export var ambient_color: Color = Color(0.05, 0.06, 0.16)
@export_range(0.0, 2.0) var ambient_energy: float = 0.2

@export_group("Toon (the characters)")
## The toon light adds this share of a light's colour inside the WHOLE volume of every light, so a night wants it low (the
## characters are toon-lit; their paint is LD-INK's). Written through Tuning at runtime (never to a preset).
@export_range(0.0, 0.6) var toon_shadow_level: float = 0.07
## The toon light's camera-fixed fill (Tuning's look_fill_strength): -1 leaves it; 0 lets a character against the sun go to a silhouette.
@export_range(-1.0, 1.5) var toon_fill_strength: float = -1.0
## The game's dusk grade is off (its tint is a dusk's; the palette LUT, LD-INK's post, is the grade).
@export var grade_off: bool = true

@export_group("Rim hook (for LD-INK)")
## The key's colour and the direction its light comes FROM (toward the key), for the rim lights. Empty = the sun's.
@export var hook_color: Color = Color(1.0, 0.6, 0.24)
@export var hook_from_sun: bool = false

@export_group("Practicals")
@export var lights: Array[VideoWorldLight] = []
@export var emitters: Array[VideoWorldEmitter] = []
@export var mattes: Array[VideoMatteCard] = []
## The colour of the posts and barrels (the flat paint's albedo), and the lens colour of a lamp (an unlit bright disc).
@export var prop_color: Color = Color(0.1, 0.1, 0.16)
@export var lens_color: Color = Color(1.0, 0.88, 0.6)
@export var barrel_color: Color = Color(0.2, 0.12, 0.1)

@export_group("Shader values")
## Uniform name -> value, for the flat paint (video/shaders/flat_paint_env_body.gdshaderinc), the painted sky, the haze quad and
## the Environment's own properties (name -> value). Plain dictionaries so a look is a data file; the tests check every name.
@export var paint: Dictionary = {}
@export var sky: Dictionary = {}
@export var sky_disc_follows_sun: bool = false
@export var haze: Dictionary = {}
@export var environment: Dictionary = {}


## Apply this look to `level` (a LevelRoot after its _ready). Replaces a look of this kind already on the level.
func apply(level: Node) -> void:
	var old := level.get_node_or_null(NodePath(String(ROOT_NAME)))
	if old != null:
		level.remove_child(old)
		old.queue_free()
	var rig := VideoWorldRig.new()
	rig.name = ROOT_NAME
	rig.look = self
	rig.level = level
	level.add_child(rig)
	_tuning()
	_paint_materials()
	rig.sun = level.get_node_or_null("Sun") as DirectionalLight3D
	rig.env = LookPost.find_environment(level)
	_apply_sun(rig)
	_apply_environment(rig)
	_build_lights(rig)
	_build_haze(rig)
	_build_mattes(rig)
	_build_emitters(rig)
	rig.publish_hook()


## The Tuning values this look sets (runtime only): the level's section light is off (it would overwrite the sun and fog), the
## toon shadow level is low, the dusk grade is off. A look_* write makes LookPost re-apply, so these come before the Environment's.
func _tuning() -> void:
	Tuning.set_value(&"section_light_enabled", false)
	Tuning.set_value(&"look_shadow_level", toon_shadow_level)
	if toon_fill_strength >= 0.0:
		Tuning.set_value(&"look_fill_strength", toon_fill_strength)
	if grade_off:
		Tuning.set_value(&"look_grade_enabled", false)


func _apply_sun(rig: VideoWorldRig) -> void:
	rig.assert_sun()


func _apply_environment(rig: VideoWorldRig) -> void:
	var env := rig.env
	if env == null:
		push_warning("VideoWorldLook: the level has no Environment")
		return
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER
	var sky_values := sky.duplicate()
	if sky_disc_follows_sun and rig.sun != null:
		sky_values[&"disc_dir"] = rig.sun_toward()
	apply_uniforms(material, sky_values)
	var sky_resource := Sky.new()
	sky_resource.sky_material = material
	sky_resource.process_mode = Sky.PROCESS_MODE_QUALITY
	sky_resource.radiance_size = Sky.RADIANCE_SIZE_64
	env.background_mode = Environment.BG_SKY
	env.sky = sky_resource
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# The exact depth fog is replaced by the haze bands (video/shaders/haze_band.gdshader).
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.glow_enabled = false
	for key: Variant in environment:
		env.set(String(key), environment[key])
	rig.sky_material = material


## Write `values` (uniform name -> value) onto `material`; a name the shader has not warns, a typo must not pass silently.
static func apply_uniforms(material: ShaderMaterial, values: Dictionary) -> void:
	var known := {}
	for uniform: Dictionary in material.shader.get_shader_uniform_list():
		known[StringName(uniform.name)] = true
	for key: Variant in values:
		var uniform_name := StringName(key)
		if not known.has(uniform_name):
			push_warning("VideoWorldLook: %s has no uniform '%s'" % [material.shader.resource_path, uniform_name])
			continue
		material.set_shader_parameter(uniform_name, values[key])


## The paint shaders go on the kit's shared materials (the trim, and the scissor trim of the chain-link). Each look sets every
## uniform again, so applying a second location after the first leaves nothing of it.
func _paint_materials() -> void:
	var trim := ToonMaterials.trim()
	var scissor := ToonMaterials.trim_scissor()
	if _game_trim_shader == null and trim.shader != PAINT_SHADER:
		_game_trim_shader = trim.shader
	if _game_scissor_shader == null and scissor.shader != PAINT_SCISSOR_SHADER:
		_game_scissor_shader = scissor.shader
	trim.shader = PAINT_SHADER
	scissor.shader = PAINT_SCISSOR_SHADER
	for key in _painted:
		if not paint.has(key):
			trim.set_shader_parameter(key, null)
			scissor.set_shader_parameter(key, null)
	_painted.clear()
	for key: Variant in paint:
		_painted.append(StringName(key))
	apply_uniforms(trim, paint)
	apply_uniforms(scissor, paint)


## Give the kit's shared materials their own shaders back (a test, or a shot that ends the look).
static func restore_game_materials() -> void:
	if _game_trim_shader != null:
		ToonMaterials.trim().shader = _game_trim_shader
	if _game_scissor_shader != null:
		ToonMaterials.trim_scissor().shader = _game_scissor_shader


## A paint ShaderMaterial for a prop (a lamp post, a barrel), with this look's paint values and `color` as its albedo.
func prop_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PAINT_PROP_SHADER
	apply_uniforms(material, paint)
	material.set_shader_parameter(&"albedo", color)
	return material


func _build_lights(rig: VideoWorldRig) -> void:
	var base := rig.section_origin()
	var index := 0
	for spec in lights:
		var node := VideoWorldPractical.build(self, spec, base, index)
		rig.add_child(node)
		rig.practicals.append(node)
		index += 1
	# One shadow caster a shot: the sun gives its shadow up to a light that asks for it.
	if rig.shadow_caster_count() > 1:
		push_warning("VideoWorldLook: %d shadow casters; one a shot (%s)" % [rig.shadow_caster_count(), location])


func _build_haze(rig: VideoWorldRig) -> void:
	if haze.is_empty():
		return
	var material := ShaderMaterial.new()
	material.shader = HAZE_SHADER
	material.render_priority = HAZE_PRIORITY
	apply_uniforms(material, haze)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	var quad := MeshInstance3D.new()
	quad.name = "HazeQuad"
	quad.mesh = mesh
	quad.extra_cull_margin = 16384.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.material_override = material
	rig.add_child(quad)
	rig.haze_material = material


func _build_mattes(rig: VideoWorldRig) -> void:
	var base := rig.section_origin()
	var haze_color := Color(0.1, 0.12, 0.3)
	if haze.has(&"band_color_3"):
		haze_color = haze[&"band_color_3"]
	for card in mattes:
		if card.texture == null:
			continue
		var material := ShaderMaterial.new()
		material.shader = MATTE_SHADER
		material.set_shader_parameter(&"matte", card.texture)
		material.set_shader_parameter(&"tint", card.tint)
		material.set_shader_parameter(&"haze_color", haze_color)
		material.set_shader_parameter(&"fade", card.fade)
		material.set_shader_parameter(&"alpha_mul", card.alpha)
		material.set_shader_parameter(&"energy", card.energy)
		material.set_shader_parameter(&"card_size_m", card.size_m)
		var mesh := QuadMesh.new()
		mesh.size = card.size_m
		var instance := MeshInstance3D.new()
		instance.name = "Matte_%s" % card.texture.resource_path.get_file().get_basename()
		instance.mesh = mesh
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig.add_child(instance)
		instance.global_position = base + card.position
		instance.rotation_degrees = Vector3(0.0, card.yaw_deg, 0.0)


func _build_emitters(rig: VideoWorldRig) -> void:
	var base := rig.section_origin()
	for spec in emitters:
		for point in spec.points:
			rig.add_child(VideoWorldParticles.build(spec, base + point))
