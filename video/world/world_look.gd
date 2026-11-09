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
const SHAFT_SHADER := preload("res://video/shaders/light_shaft.gdshader")
const FLAME_SHADER := preload("res://video/shaders/flame_painted.gdshader")
const PLUME_SHADER := preload("res://video/shaders/steam_plume.gdshader")
const ROOT_NAME := &"VideoWorldRig"
## The haze quad draws before the ink (the ink's priority is MIN + 2) and after LookPost's own edge quad (MIN + 1).
const HAZE_PRIORITY := Material.RENDER_PRIORITY_MIN

## The shader the trim materials had before any look replaced it (kept across applications, so a second look restores it first).
static var _game_trim_shader: Shader
static var _game_scissor_shader: Shader
## The lights' slots the paint shader has (flat_paint_env_body.gdshaderinc's `lamps`).
const LAMP_SLOTS := 8
## The paint uniforms the last look wrote, so the next one can clear what it does not set (a look leaves nothing of another).
static var _painted: Array[StringName] = []
## The paint materials of the last application (the kit's, the props', the lamp posts'): the rig writes the focus on them each frame.
var live_materials: Array[ShaderMaterial] = []
## The uniforms this look derives from its own data for the paint (the lights' places, the key's direction), written on every paint material it makes.
var _derived: Dictionary = {}

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

@export_group("Focus and contact shadows (round 3)")
## Where the shot spends its detail: a world point in section space and its radius (m). With `focus_follow_m` above 0 the point instead rides the
## camera: that many metres ahead of it (the subject is usually that far), each frame. `focus_on` (in the paint values) switches the cut on.
@export var focus_point: Vector3 = Vector3(0.0, 1.2, -8.0)
@export_range(1.0, 60.0) var focus_radius_m: float = 12.0
@export_range(0.0, 40.0) var focus_follow_m: float = 7.0
## The painted contact shadow under every character: its colour, strength (0: none), radius and stretch (m, a share), how far its edge is broken, its lift above the floor (m), and how
## near the camera a first-person body is left without one.
@export var contact_color: Color = Color(0.01, 0.012, 0.035)
@export_range(0.0, 1.0) var contact_opacity: float = 0.8
@export_range(0.1, 1.5) var contact_radius_m: float = 0.55
@export_range(1.0, 3.0) var contact_stretch: float = 1.4
@export_range(0.0, 0.6) var contact_broken: float = 0.28
@export_range(0.0, 0.1) var contact_lift_m: float = 0.03
@export_range(0.0, 3.0) var contact_skip_m: float = 1.2

@export_group("Props (round 2)")
## The game's own props (water tanks, AC units, cars, dumpsters, crates) painted like the kit: mesh node name -> {color, pattern, rib_m}. The pattern
## numbers are flat_paint_env_body.gdshaderinc's `prop_pattern`: 0 tank, 1 dumpster, 2 car, 3 air conditioner, 4 crate. A prop keeps the hull its
## material carried (as next_pass). Found at run time by name and by the game's toon shader, never by editing game/.
@export var props: Dictionary = {}

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
	live_materials.clear()
	var rig := VideoWorldRig.new()
	rig.name = ROOT_NAME
	rig.look = self
	rig.level = level
	level.add_child(rig)
	_tuning()
	_paint_materials(rig)
	rig.sun = level.get_node_or_null("Sun") as DirectionalLight3D
	rig.env = LookPost.find_environment(level)
	_apply_sun(rig)
	_apply_environment(rig)
	_build_lights(rig)
	_build_haze(rig)
	_build_mattes(rig)
	_build_emitters(rig)
	_paint_props(level)
	_build_contact(rig)
	rig.start()
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
func _paint_materials(rig: VideoWorldRig) -> void:
	var trim := ToonMaterials.trim()
	var scissor := ToonMaterials.trim_scissor()
	if _game_trim_shader == null and trim.shader != PAINT_SHADER:
		_game_trim_shader = trim.shader
	if _game_scissor_shader == null and scissor.shader != PAINT_SCISSOR_SHADER:
		_game_scissor_shader = scissor.shader
	trim.shader = PAINT_SHADER
	scissor.shader = PAINT_SCISSOR_SHADER
	# Values written in a section's own space are moved to the world: the fire's height is metres above the section's floor.
	var values := paint.duplicate()
	_derived = _derive_uniforms(rig)
	if float(paint.get(&"r4_on", 0.0)) > 0.0:
		values.merge(_derived, true)
	if values.has(&"fire_top_m"):
		values[&"fire_top_m"] = float(values[&"fire_top_m"]) + rig.section_origin().y
	for key in _painted:
		if not paint.has(key):
			trim.set_shader_parameter(key, null)
			scissor.set_shader_parameter(key, null)
	_painted.clear()
	for key: Variant in values:
		_painted.append(StringName(key))
	apply_uniforms(trim, values)
	apply_uniforms(scissor, values)
	live_materials.append(trim)
	live_materials.append(scissor)


## What the paint needs from the look's own data (round 4): the places of its lights and the radius each lights (`lamps`, up to LAMP_SLOTS, padded with zeros), and the
## key's direction (the sun's). The paint reads these to know which surfaces are in a light (full detail) and which are a mass.
func _derive_uniforms(rig: VideoWorldRig) -> Dictionary:
	var base := rig.section_origin()
	var places := PackedVector4Array()
	for spec in lights:
		if places.size() >= LAMP_SLOTS:
			break
		var at := base + spec.position + spec.head_offset()
		places.append(Vector4(at.x, at.y, at.z, spec.range_m * spec.mask_range_scale))
	while places.size() < LAMP_SLOTS:
		places.append(Vector4.ZERO)
	# The section's floors, as world heights: the paint rims the tops of ledges and crates, never a floor.
	var floors := Vector4(-1000.0, -1000.0, -1000.0, -1000.0)
	var root := rig.level as LevelRoot
	if root != null and section < root.sections.size():
		var heights: Variant = root.sections[section].get(&"floor_heights")
		if heights is PackedFloat32Array:
			for k in mini((heights as PackedFloat32Array).size(), 4):
				floors[k] = base.y + (heights as PackedFloat32Array)[k]
	return {
		&"floors": floors,
		&"lamps": places,
		&"key_dir": VideoWorldRig.toward_from_angles(sun_elevation_deg, sun_yaw_deg),
	}


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
	if float(paint.get(&"r4_on", 0.0)) > 0.0:
		apply_uniforms(material, _derived)
	material.set_shader_parameter(&"albedo", color)
	live_materials.append(material)
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
		material.set_shader_parameter(&"feather", card.feather)
		material.set_shader_parameter(&"drift", card.drift)
		material.set_shader_parameter(&"drift_from", card.drift_from)
		rig.matte_materials.append(material)
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
		var index := 0
		for point in spec.points:
			if spec.kind == VideoWorldEmitter.Kind.STEAM:
				# Steam is drawn (a few big flat lobes on a card), not a column of particle puffs.
				for card in VideoWorldPlume.build(self, spec, base + point, index):
					rig.add_child(card)
					rig.plume_materials.append(card.get_meta(&"plume") as ShaderMaterial)
			else:
				rig.add_child(VideoWorldParticles.build(spec, base + point))
			index += 1


## The props named in `props`: each MeshInstance3D of the level with that name whose surfaces wear the game's toon material gets the prop paint
## (its colour, its pattern) as a material override; the hull that material carried (its next_pass) goes along. Characters are never touched
## (they are in the rig_art and view_proxy groups, and are not named here). Round 4: no twin props. A spec may carry `vary_hue` (the hue wheel's share the colour wanders by,
## from a hash of the prop's place), `vary_value` (a share of the value, the sign alternating between twins), `vary_scale` and `vary_tilt_deg` (the prop's art is scaled and tilted about
## its feet, a visual-only change of the PropSpot's art node, never of the game's files), `vary_yaw_deg`, and `patch` (a repair plate and a dent on a water tank).
func _paint_props(level: Node) -> void:
	if props.is_empty():
		return
	var ordinal := {}
	for node in level.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not props.has(String(mesh.name)):
			continue
		var spec: Dictionary = props[String(mesh.name)]
		var spot := _spot_of(mesh)
		var place := (spot.global_position if spot != null else mesh.global_position)
		var nth: int = ordinal.get(mesh.name, 0)
		ordinal[mesh.name] = nth + 1
		var sign_k := 1.0 if nth % 2 == 0 else -1.0
		var h1 := _hash01(place, 1.0)
		var h2 := _hash01(place, 2.0)
		var h3 := _hash01(place, 3.0)
		var color: Color = spec.get(&"color", Color(0.3, 0.3, 0.3))
		var vary_hue := float(spec.get(&"vary_hue", 0.0))
		var vary_value := float(spec.get(&"vary_value", 0.0))
		if vary_hue > 0.0:
			color.h = fposmod(color.h + (h1 - 0.5) * vary_hue, 1.0)
		if vary_value > 0.0:
			color.v = clampf(color.v * (1.0 + sign_k * vary_value * (0.6 + 0.4 * h2)), 0.0, 1.0)
		var material := prop_material(color)
		material.set_shader_parameter(&"prop_pattern", int(spec.get(&"pattern", -1)))
		material.set_shader_parameter(&"prop_rib_m", float(spec.get(&"rib_m", 0.25)))
		material.set_shader_parameter(&"prop_seed", h3 * 60.0 + 1.0)
		material.set_shader_parameter(&"prop_patch", float(spec.get(&"patch", 0.0)))
		material.set_shader_parameter(&"prop_base_m", place.y)
		if spot != null:
			_vary_art(spot, spec, sign_k, h1, h2, h3)
		var hull: Material = null
		if mesh.has_meta(&"world2_hull"):
			hull = mesh.get_meta(&"world2_hull") as Material
		else:
			var original := mesh.material_override
			if original == null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
				original = mesh.get_surface_override_material(0)
				if original == null:
					original = mesh.mesh.surface_get_material(0)
			if original != null:
				hull = original.next_pass
			mesh.set_meta(&"world2_hull", hull)
		material.next_pass = hull
		mesh.material_override = material


## The PropSpot a prop mesh belongs to (its art's parent), or null.
func _spot_of(mesh: Node) -> PropSpot:
	var up := mesh.get_parent()
	while up != null:
		if up is PropSpot:
			return up as PropSpot
		up = up.get_parent()
	return null


static func _hash01(at: Vector3, salt: float) -> float:
	return fposmod(sin(at.x * 12.9898 + at.y * 78.233 + at.z * 37.719 + salt * 4.1) * 43758.5453, 1.0)


## A twin differs by a transform: the prop's art is scaled (the sign alternates between twins) and tilted about the PropSpot's origin, which stands on the floor at the middle of
## the footprint, and turned a little. The art's first transform is kept in meta, so a second application starts from it. Visual only: the collider is the block it dresses.
func _vary_art(spot: PropSpot, spec: Dictionary, sign_k: float, h1: float, h2: float, h3: float) -> void:
	var art := spot.art
	if art == null:
		return
	var vary_scale := float(spec.get(&"vary_scale", 0.0))
	var vary_tilt := float(spec.get(&"vary_tilt_deg", 0.0))
	var vary_yaw := float(spec.get(&"vary_yaw_deg", 0.0))
	if vary_scale <= 0.0 and vary_tilt <= 0.0 and vary_yaw <= 0.0:
		return
	if not art.has_meta(&"r4_base"):
		art.set_meta(&"r4_base", art.transform)
	var base: Transform3D = art.get_meta(&"r4_base")
	var grow := 1.0 + sign_k * vary_scale * (0.6 + 0.4 * h1)
	var tall := 1.0 + sign_k * vary_scale * (0.5 + 0.5 * h2) * 0.6
	var axis := Vector3(cos(h3 * TAU), 0.0, sin(h3 * TAU))
	var tilt := Basis(axis, deg_to_rad(vary_tilt * sign_k * (0.5 + 0.5 * h2)))
	var turn := Basis(Vector3.UP, deg_to_rad(vary_yaw * (h1 - 0.5) * 2.0))
	var shape := Basis.from_scale(Vector3(grow, tall, grow))
	art.transform = Transform3D(turn * tilt * shape, Vector3.ZERO) * base


func _build_contact(rig: VideoWorldRig) -> void:
	if contact_opacity <= 0.0:
		return
	var contact := VideoWorldContact.new()
	contact.look = self
	contact.rig = rig
	rig.add_child(contact)
