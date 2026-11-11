class_name TrailerLook
extends Node
## The level's layer for the trailer look profile (Milestone 7, T10): while Tuning's `look_profile` is the trailer it builds the
## night street (NightStreet, under each section whose `look_location` has a NightLook row), swaps the Environment's sky for the
## painted one (sky_painted.gdshader, its colours following the level's blended light, so a seam between sections still
## blends), lays the haze bands, lets the lamps and fire bloom, turns the moon's shadow map off (painted contact shadows stand
## in) and puts a contact shadow under every actor. Flipping back to m6 frees everything and restores what it changed (the
## sky material object, the glow settings, the sun's shadow), so the old light is exactly the old light.
## A child of the LevelRoot (it builds the layer in `_ready`); presentation only: it reads Tuning, the level and the actors
## and never writes game state.

const SKY_SHADER := preload("res://game/fx/sky_painted.gdshader")
const HAZE_SHADER := preload("res://game/fx/haze_band.gdshader")
const CONTACT_SHADER := preload("res://game/fx/contact_shadow.gdshader")
## Just above the contact flash (-128), with the edge pass (-127): the haze lies under the ink.
const HAZE_RENDER_PRIORITY := Material.RENDER_PRIORITY_MIN
const HAZE_CULL_MARGIN := 16384.0
const CONTACT_PLANE_M := 1.6
## The actor groups the contact shadows follow (the player's own feet are never in his view).
const ACTOR_GROUP := &"ai_enemy"

var _level: LevelRoot
var _active: bool = false
var _streets: Array[NightStreet] = []
var _sky_material: ShaderMaterial
var _sky_before: Sky = null
var _sky_material_before: Material = null
var _glow_before: Dictionary = {}
var _sun_shadow_before: bool = true
var _haze_quad: MeshInstance3D
var _haze_material: ShaderMaterial
## The actors' contact shadow cards: {actor, card, material}.
var _actor_shadows: Array[Dictionary] = []
var _contact_look: NightLook


func _init() -> void:
	name = "TrailerLook"


func _ready() -> void:
	_level = get_parent() as LevelRoot
	Tuning.changed.connect(_on_tuning_changed)
	_sync()


func _exit_tree() -> void:
	if Tuning.changed.is_connected(_on_tuning_changed):
		Tuning.changed.disconnect(_on_tuning_changed)
	if _active:
		_deactivate()


## Whether the trailer look is built now.
func is_active() -> bool:
	return _active


## The night streets built (one per section with a look), for tests.
func streets() -> Array[NightStreet]:
	return _streets


## The painted sky's material while the look is on, else null.
func sky_material() -> ShaderMaterial:
	return _sky_material


func haze_material() -> ShaderMaterial:
	return _haze_material


## The contact shadow cards under actors now.
func actor_shadow_count() -> int:
	return _actor_shadows.size()


func _on_tuning_changed(property: StringName) -> void:
	if property == &"" or property == &"look_profile":
		_sync()
	elif _active and String(property).begins_with("night_"):
		for street in _streets:
			street.apply_scales()
		_apply_haze_scale()


func _sync() -> void:
	var wanted := LookProfile.current() == LookProfile.Id.TRAILER and _level != null
	if wanted and not _active:
		_activate()
	elif not wanted and _active:
		_deactivate()


func _environment() -> Environment:
	var world := _level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	return world.environment if world != null else null


func _sun() -> DirectionalLight3D:
	return _level.get_node_or_null("Sun") as DirectionalLight3D


## The first night look of the level's sections (what is global to the layer: the sky's settings, the bloom, the haze).
func _any_look() -> NightLook:
	for section in _level.sections:
		var found := NightLook.for_location(section.look_location)
		if found != null:
			return found
	return null


## The look of the section the player is in, or null.
func _look_here() -> NightLook:
	var section := _level.current_section()
	return NightLook.for_location(section.look_location) if section != null else null


func _activate() -> void:
	_active = true
	var base := _any_look()
	for section in _level.sections:
		var section_look := NightLook.for_location(section.look_location)
		if section_look == null:
			continue
		var street := NightStreet.new()
		section.add_child(street)
		street.build(section, section_look)
		_streets.append(street)
	_contact_look = base
	if base == null:
		set_physics_process(false)
		return
	_swap_sky()
	_apply_glow(base)
	_build_haze(base)
	var sun := _sun()
	if sun != null:
		_sun_shadow_before = sun.shadow_enabled
	set_physics_process(true)
	_tick()


func _deactivate() -> void:
	_active = false
	for street in _streets:
		if is_instance_valid(street):
			street.get_parent().remove_child(street)
			street.queue_free()
	_streets.clear()
	for entry in _actor_shadows:
		(entry.card as Node).queue_free()
	_actor_shadows.clear()
	if _haze_quad != null:
		_haze_quad.queue_free()
		_haze_quad = null
		_haze_material = null
	var env := _environment()
	if env != null:
		if _sky_material_before != null and env.sky != null and env.sky.sky_material == _sky_material:
			env.sky.sky_material = _sky_material_before
		for property: StringName in _glow_before:
			env.set(property, _glow_before[property])
	_glow_before.clear()
	_sky_material = null
	_sky_material_before = null
	var sun := _sun()
	if sun != null:
		sun.shadow_enabled = _sun_shadow_before
	_contact_look = null
	set_physics_process(false)


# --- The sky, the bloom, the haze --------------------------------------------------------------


func _swap_sky() -> void:
	var env := _environment()
	if env == null or env.sky == null:
		return
	_sky_material_before = env.sky.sky_material
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = SKY_SHADER
	env.sky.sky_material = _sky_material


## Only what is hotter than the threshold blooms, so the lamps (and the fire) do and nothing else: the glow settings the
## look changes are written here and put back by _deactivate().
func _apply_glow(look: NightLook) -> void:
	var env := _environment()
	if env == null:
		return
	var wanted := {
		glow_hdr_threshold = look.glow_threshold, glow_intensity = look.glow_intensity,
		glow_strength = look.glow_strength, glow_bloom = look.glow_bloom,
	}
	for property: StringName in wanted:
		_glow_before[property] = env.get(property)
		env.set(property, wanted[property])


func _build_haze(look: NightLook) -> void:
	_haze_material = ShaderMaterial.new()
	_haze_material.shader = HAZE_SHADER
	_haze_material.render_priority = HAZE_RENDER_PRIORITY
	_haze_material.set_shader_parameter(&"band_start_m", look.haze_start_m)
	_haze_material.set_shader_parameter(&"mist_top", look.haze_mist_top)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_haze_quad = MeshInstance3D.new()
	_haze_quad.name = "HazeQuad"
	_haze_quad.mesh = quad
	_haze_quad.extra_cull_margin = HAZE_CULL_MARGIN
	_haze_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_haze_quad.material_override = _haze_material
	add_child(_haze_quad)
	_apply_haze_scale()


## The haze's colours are the look's, their alphas scaled by Tuning's `night_haze_scale`.
func _apply_haze_scale() -> void:
	if _haze_material == null or _contact_look == null:
		return
	var scale := Tuning.data.night_haze_scale
	var look := _contact_look
	_haze_material.set_shader_parameter(&"band_color_1", _scaled(look.haze_color_1, scale))
	_haze_material.set_shader_parameter(&"band_color_2", _scaled(look.haze_color_2, scale))
	_haze_material.set_shader_parameter(&"band_color_3", _scaled(look.haze_color_3, scale))
	_haze_material.set_shader_parameter(&"mist_color", _scaled(look.haze_mist_color, scale))


static func _scaled(color: Color, factor: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(color.a * factor, 0.0, 1.0))


# --- Each tick -----------------------------------------------------------------------------------


func _physics_process(_delta: float) -> void:
	_tick()


func _tick() -> void:
	if not _active or _level == null:
		return
	_tick_sky()
	var sun := _sun()
	var here := _look_here()
	if sun != null:
		var shadow := here.sun_shadow if here != null else _sun_shadow_before
		if sun.shadow_enabled != shadow:
			sun.shadow_enabled = shadow
	var ticks := Engine.get_physics_frames()
	for street in _streets:
		street.flicker(ticks)
	_tick_actor_shadows()


## The sky follows the level's blended light: the top and the horizon colour, the middle band between them; the moon's disc and the
## stars come from the night look and fade to nothing elsewhere.
func _tick_sky() -> void:
	if _sky_material == null:
		return
	var light := _level.current_light()
	if light.is_empty():
		return
	var base := _contact_look
	var top: Color = light.sky_top
	var horizon: Color = light.sky_horizon
	_sky_material.set_shader_parameter(&"zenith_color", top)
	_sky_material.set_shader_parameter(&"horizon_color", horizon)
	_sky_material.set_shader_parameter(&"mid_color", horizon.lerp(top, base.sky_mid_mix))
	_sky_material.set_shader_parameter(&"below_color", top * base.sky_below_mul)
	var here := _look_here()
	_sky_material.set_shader_parameter(&"disc_radius", here.sky_disc_radius if here != null else 0.0)
	_sky_material.set_shader_parameter(&"star_cover", here.sky_star_cover if here != null else 0.0)
	var shown := here if here != null else base
	_sky_material.set_shader_parameter(&"disc_color", shown.sky_disc_color)
	_sky_material.set_shader_parameter(&"halo_color", shown.sky_halo_color)
	_sky_material.set_shader_parameter(&"halo_strength", shown.sky_halo_strength)
	var sun := _sun()
	if sun != null:
		_sky_material.set_shader_parameter(&"disc_dir", sun.global_transform.basis.z)


## A contact shadow card under each live enemy, stretched away from the nearest lamp; cards of enemies that are gone are freed.
func _tick_actor_shadows() -> void:
	if _contact_look == null:
		return
	var actors := get_tree().get_nodes_in_group(ACTOR_GROUP)
	for i in range(_actor_shadows.size() - 1, -1, -1):
		var entry := _actor_shadows[i]
		if not is_instance_valid(entry.actor) or not actors.has(entry.actor):
			(entry.card as Node).queue_free()
			_actor_shadows.remove_at(i)
	for node: Node in actors:
		var actor := node as CombatActor
		if actor != null and _shadow_of(actor).is_empty():
			_actor_shadows.append(_new_actor_shadow(actor))
	var lamps := _lamp_points()
	var opacity := _contact_look.contact_opacity * Tuning.data.night_contact_opacity
	for entry in _actor_shadows:
		var actor: CombatActor = entry.actor
		var card: MeshInstance3D = entry.card
		card.visible = not actor.is_gone()
		if not card.visible:
			continue
		var at := actor.global_position
		card.global_position = Vector3(at.x, at.y + _contact_look.pool_lift_m, at.z)
		var away := _away_from(at, lamps)
		var material: ShaderMaterial = entry.material
		material.set_shader_parameter(&"dir", away)
		material.set_shader_parameter(&"opacity", opacity)


func _shadow_of(actor: CombatActor) -> Dictionary:
	for entry in _actor_shadows:
		if entry.actor == actor:
			return entry
	return {}


func _new_actor_shadow(actor: CombatActor) -> Dictionary:
	var card := MeshInstance3D.new()
	card.name = "ContactShadow"
	var plane := PlaneMesh.new()
	plane.size = Vector2(CONTACT_PLANE_M, CONTACT_PLANE_M)
	card.mesh = plane
	var width := actor.body_radius * _contact_look.contact_per_radius
	card.scale = Vector3(width / CONTACT_PLANE_M, 1.0, width / CONTACT_PLANE_M)
	card.top_level = true
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := NightStreet.contact_material(_contact_look, float(get_instance_id() % 97) + float(_actor_shadows.size()), Vector2(0.0, 1.0))
	card.material_override = material
	add_child(card)
	return {actor = actor, card = card, material = material}


## The lamps' world points (flat), from every street built.
func _lamp_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	for street in _streets:
		for rig in street.rigs():
			out.append((rig.light as OmniLight3D).global_position)
	return out


## The flat direction from the nearest of `lamps` to `at` (the way a shadow falls), or +z with no lamp.
static func _away_from(at: Vector3, lamps: PackedVector3Array) -> Vector2:
	var best := INF
	var out := Vector2(0.0, 1.0)
	for point in lamps:
		var flat := Vector2(at.x - point.x, at.z - point.z)
		var d := flat.length_squared()
		if d < best and d > 0.0001:
			best = d
			out = flat.normalized()
	return out
