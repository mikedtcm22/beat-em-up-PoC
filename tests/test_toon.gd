extends GutTest
## The toon look (Milestone 4, package P1-toon; docs/ARCHITECTURE.md "Toon shader, hull, flash
## and damage on toon"): the one toon shader and its hull, the materials ToonMaterials makes and
## the Tuning values that move them, the hull's width and its push direction (mirrors of the
## shader's math: a headless run draws nothing, so the shaders themselves are looked at in the
## captures), the flash and the damage look on toon, set_shown() and the first-person layers
## over the hulls, and the detail mask on UV2.

const TOON_PATH := "res://game/fx/toon.gdshader"
const LIGHT_PATH := "res://game/fx/toon_light.gdshaderinc"
const OUTLINE_PATH := "res://game/fx/toon_outline.gdshader"
const GRID_PATH := "res://game/level/grid.gdshader"
## The uniforms M4-plan §2.7 pins for toon.gdshader (the lighting include's, too).
const PINNED_UNIFORMS: Array[String] = [
	"albedo", "albedo_tex", "use_albedo_tex", "detail_tex", "use_detail_tex", "ink", "band_1", "band_2",
	"band_soft", "mid_level", "shadow_tint", "spec_cut", "spec_strength", "rim_cut", "rim_power", "rim_strength",
	"flash_color", "flash_amount", "damage_tex", "damage_skin_tex", "damage_scale", "marks", "use_rest_custom",
	"halftone_strength", "halftone_cell_px", "edge_tag",
]
## The first-person camera's horizontal field of view (Tuning.fov_deg's default).
const FOV_DEG := 90.0
## Where the light sweeps of the band tests start: not a multiple of the step from any default
## break (a sample that lands exactly on a break is half way, a fourth color; F-look moved the breaks).
const SWEEP_FROM := -0.2007


func before_each() -> void:
	Tuning.apply(TuningData.new())


func after_each() -> void:
	Tuning.apply(TuningData.new())


func _source(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## The uniform names `path`'s source declares.
func _uniforms(path: String) -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	var declared := RegEx.create_from_string("(?m)^uniform\\s+(\\w+)\\s+(\\w+)([^;]*);")
	for found in declared.search_all(_source(path)):
		out[found.get_string(2)] = found.get_string(1) + found.get_string(3)
	return out


func _rig(first_person: bool = false) -> HumanoidRig:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	rig.first_person_body = first_person
	rig.wrapped_hands = first_person
	add_child_autofree(rig)
	rig.build()
	return rig


func _meshes(rig: HumanoidRig) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node: Node in rig.find_children("*", "MeshInstance3D", true, false):
		out.append(node as MeshInstance3D)
	return out


## The vertical projection scale (PROJECTION_MATRIX[1][1]) of a camera with horizontal field of
## view `fov_deg` (the first-person camera keeps its width) on a `width` x `height` viewport.
func _proj11(fov_deg: float, width: float, height: float) -> float:
	var half_x := tan(deg_to_rad(fov_deg) * 0.5)
	return 1.0 / (half_x * height / width)


# --- The shaders ------------------------------------------------------------------------------


func test_the_shaders_load_and_share_one_lighting_include() -> void:
	for path: String in [TOON_PATH, OUTLINE_PATH, GRID_PATH]:
		var shader := load(path) as Shader
		assert_not_null(shader, "%s loads" % path)
		assert_string_contains(shader.code, "shader_type spatial")
	for path: String in [TOON_PATH, GRID_PATH]:
		assert_string_contains(_source(path), "#include \"%s\"" % LIGHT_PATH, "%s has the toon lighting" % path)
		assert_string_contains(_source(path), "render_mode ambient_light_disabled", "%s: the ramp owns the shadow side" % path)
	assert_string_contains(_source(LIGHT_PATH), "void light()", "the one light()")
	assert_string_contains(_source(OUTLINE_PATH), "render_mode unshaded, cull_front", "an inverted hull")
	assert_eq(ToonMaterials.TOON_SHADER, load(TOON_PATH))
	assert_eq(ToonMaterials.OUTLINE_SHADER, load(OUTLINE_PATH))


func test_toon_shader_declares_every_pinned_uniform_with_a_range_on_every_float() -> void:
	var declared := _uniforms(TOON_PATH)
	declared.merge(_uniforms(LIGHT_PATH))
	for name: String in PINNED_UNIFORMS:
		assert_true(declared.has(name), "toon.gdshader (or its lighting) declares %s" % name)
	for path: String in [TOON_PATH, LIGHT_PATH, OUTLINE_PATH]:
		for name: String in _uniforms(path):
			var spec: String = _uniforms(path)[name]
			if spec.begins_with("float") or spec.begins_with("int"):
				assert_string_contains(spec, "hint_range", "%s: %s is a ranged uniform (no free numbers)" % [path.get_file(), name])


func test_the_edge_tag_is_roughness_and_the_hull_never_fattens_a_shadow() -> void:
	# A8: ROUGHNESS is the edge pass's tag. A hull on material_overlay draws into the shadow
	# map too (measured: a 40 px hull grew a box's shadow by half with this guard off), under the
	# light's own orthographic projection, so it is cut to nothing there.
	assert_string_contains(_source(TOON_PATH), "ROUGHNESS = edge_tag")
	assert_string_contains(_source(GRID_PATH), "ROUGHNESS = 1.0")
	assert_string_contains(_source(OUTLINE_PATH), "PROJECTION_MATRIX[3][3] != 0.0")
	assert_false(_source(TOON_PATH).contains("shadows_disabled"), "the toon surfaces cast and receive shadows")


# --- The hull's width (the shader's math, mirrored) ---------------------------------------------


## What the hull line measures on screen, in 1080p-equivalent pixels, at `dist` m.
func _hull_px_1080(dist: float, viewport_w: float = 1600.0, viewport_h: float = 900.0, fp_scale: float = 1.0) -> float:
	var d := Tuning.data
	var proj := _proj11(FOV_DEG, viewport_w, viewport_h)
	var width := ToonMaterials.outline_width_m(dist, d.look_outline_px, proj, viewport_h, d.look_outline_near_m,
			d.look_outline_far_m, d.look_outline_lens_fade_m, fp_scale)
	# metres -> pixels on the viewport at that distance, then to 1080p
	var viewport_px := width * proj * viewport_h / (2.0 * dist)
	return viewport_px * 1080.0 / viewport_h


func test_the_hull_holds_its_pixel_width_between_near_and_far_whatever_the_viewport() -> void:
	var px := Tuning.data.look_outline_px
	for dist: float in [0.4, 0.6, 1.0, 1.5, 2.5, 3.0, 5.0, 8.0, 10.0, 12.0]:
		for viewport: Vector2 in [Vector2(1280, 720), Vector2(1600, 900), Vector2(1920, 1080), Vector2(2560, 1440)]:
			assert_almost_eq(_hull_px_1080(dist, viewport.x, viewport.y), px, 0.0001,
					"%.1f m on %dx%d: the line is look_outline_px at 1080p" % [dist, viewport.x, viewport.y])


func test_the_hull_meets_the_look_bible_at_1_to_10_m() -> void:
	# Look bible: 3.5-4 px at 1-3 m, at least 2 px out to 10 m, never above 4.5 px.
	for dist: float in [1.0, 1.5, 2.0, 3.0]:
		assert_between(_hull_px_1080(dist), 3.5, 4.0, "%.1f m" % dist)
	for dist: float in [1.0, 2.5, 5.0, 7.5, 10.0]:
		assert_gte(_hull_px_1080(dist), 2.0, "%.1f m: at least 2 px" % dist)
	for dist: float in [0.3, 0.5, 1.0, 3.0, 10.0, 12.0]:
		assert_lte(_hull_px_1080(dist), 4.5, "%.1f m: never above 4.5 px" % dist)
	# The player's own body is x look_outline_fp_scale, at its arms' 0.3-0.6 m.
	for dist: float in [0.3, 0.45, 0.6]:
		assert_almost_eq(_hull_px_1080(dist, 1600.0, 900.0, Tuning.data.look_outline_fp_scale),
				Tuning.data.look_outline_px * 0.8, 0.0001, "%.2f m: the player's own line" % dist)


func test_the_hull_thins_beyond_far_and_fades_out_at_the_lens() -> void:
	var far := Tuning.data.look_outline_far_m
	assert_almost_eq(_hull_px_1080(far * 2.0), Tuning.data.look_outline_px * 0.5, 0.0001, "twice as far: half the pixels")
	assert_lt(_hull_px_1080(far * 4.0), _hull_px_1080(far * 2.0))
	var near := Tuning.data.look_outline_near_m
	assert_almost_eq(_hull_px_1080(near * 0.8), Tuning.data.look_outline_px * near / (near * 0.8), 0.001,
			"nearer than near the line keeps its world width")
	var fade := Tuning.data.look_outline_lens_fade_m
	var proj := _proj11(FOV_DEG, 1600.0, 900.0)
	for dist: float in [0.0, 0.5 * fade, fade]:
		assert_eq(ToonMaterials.outline_width_m(dist, 3.75, proj, 900.0, 0.3, 12.0, fade), 0.0,
				"%.2f m: nothing within the lens fade, so a lens never sits inside a hull" % dist)
	var last := 0.0
	for step in 21:
		var dist := fade + fade * float(step) / 20.0
		var width := ToonMaterials.outline_width_m(dist, 3.75, proj, 900.0, 0.3, 12.0, fade)
		assert_gte(width, last - 1e-9, "the line grows steadily out of the fade")
		last = width
	assert_almost_eq(_hull_px_1080(2.0 * fade), Tuning.data.look_outline_px * Tuning.data.look_outline_near_m / (2.0 * fade), 0.001,
			"full width at twice the fade distance")


func test_the_hull_width_follows_the_field_of_view() -> void:
	# The same pixel width through a wider lens is a wider world line (it is PROJECTION_MATRIX).
	var wide := ToonMaterials.outline_width_m(2.0, 3.75, _proj11(110.0, 1600.0, 900.0), 900.0, 0.3, 12.0, 0.1)
	var narrow := ToonMaterials.outline_width_m(2.0, 3.75, _proj11(75.0, 1600.0, 900.0), 900.0, 0.3, 12.0, 0.1)
	assert_gt(wide, narrow)


# --- The hull's push direction: no corner cracks, every face plane out by exactly the width ------


## The hull offset (unit width) of every vertex of `mesh` for hull `mode`, grouped by position:
## each position's offsets must agree (no cracks), and a face's own vertices must each move
## `along` its normal by exactly 1 (every face plane moves out by the width).
func _check_hull(mesh: Mesh, mode: int, label: String, exact_planes: bool) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var by_position: Dictionary[Vector3i, Vector3] = {}
	for i in vertices.size():
		var dir := ToonMaterials.hull_direction(mode, vertices[i], normals[i])
		var key := Vector3i((vertices[i] * 10000.0).round())
		if by_position.has(key):
			assert_almost_eq(dir, by_position[key], Vector3.ONE * 0.001, "%s: vertices at %s split apart" % [label, vertices[i]])
		else:
			by_position[key] = dir
		if exact_planes:
			assert_almost_eq(dir.dot(normals[i]), 1.0, 0.001, "%s: vertex %d moves its face plane out by exactly the width" % [label, i])


func test_hull_directions_leave_no_cracks_and_move_every_face_plane_by_the_width() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.36, 0.2, 0.25)
	_check_hull(box, ToonMaterials.Hull.BOX, "box", true)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.07
	cylinder.bottom_radius = 0.07
	cylinder.height = 0.4
	cylinder.radial_segments = 16
	cylinder.rings = 1
	_check_hull(cylinder, ToonMaterials.Hull.CYLINDER, "cylinder", true)
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.075
	capsule.height = 0.3
	capsule.radial_segments = 16
	capsule.rings = 4
	_check_hull(capsule, ToonMaterials.Hull.NORMAL, "capsule", true)
	var sphere := SphereMesh.new()
	sphere.radius = 0.125
	sphere.height = 0.27
	sphere.radial_segments = 16
	sphere.rings = 8
	_check_hull(sphere, ToonMaterials.Hull.NORMAL, "sphere", true)
	# A hemisphere (the cap's dome) is open at its rim: along the radius, so the rim and its
	# lid never split (the lid's own plane is not moved by exactly the width).
	var dome := SphereMesh.new()
	dome.radius = 0.14
	dome.height = 0.14
	dome.radial_segments = 16
	dome.rings = 8
	dome.is_hemisphere = true
	_check_hull(dome, ToonMaterials.Hull.RADIAL, "dome", false)


func _parts_by_name(wrapped: bool) -> Dictionary[StringName, PlaceholderBody.Part]:
	var out: Dictionary[StringName, PlaceholderBody.Part] = {}
	for part: PlaceholderBody.Part in PlaceholderBody.parts(wrapped):
		out[part.name] = part
	return out


func test_every_rig_primitive_gets_the_hull_of_its_shape_with_no_cracks() -> void:
	for first_person: bool in [false, true]:
		var rig := _rig(first_person)
		var parts := _parts_by_name(first_person)
		var meshes := _meshes(rig)
		assert_eq(meshes.size(), parts.size())
		for mesh_instance: MeshInstance3D in meshes:
			var part := parts[mesh_instance.name]
			var hull := mesh_instance.material_overlay as ShaderMaterial
			assert_not_null(hull, "%s has a hull" % mesh_instance.name)
			var mode := int(hull.get_shader_parameter(&"mode"))
			match part.shape:
				PlaceholderBody.Shape.BOX:
					assert_eq(mode, ToonMaterials.Hull.BOX, "%s: a box" % mesh_instance.name)
				PlaceholderBody.Shape.CYLINDER:
					assert_eq(mode, ToonMaterials.Hull.CYLINDER, "%s: a cylinder" % mesh_instance.name)
				PlaceholderBody.Shape.DOME:
					assert_eq(mode, ToonMaterials.Hull.RADIAL, "%s: a dome" % mesh_instance.name)
				_:
					assert_eq(mode, ToonMaterials.Hull.NORMAL, "%s: along the normal" % mesh_instance.name)
			var exact := mode != ToonMaterials.Hull.RADIAL
			_check_hull(mesh_instance.mesh, mode, "%s %s" % ["player" if first_person else "enemy", mesh_instance.name], exact)
			assert_eq(hull.get_shader_parameter(&"fp_scale"), Tuning.data.look_outline_fp_scale if first_person else 1.0,
					"%s: the player's own body is drawn thinner" % mesh_instance.name)


func test_hulls_are_shared_per_shape_and_off_when_placeholders_get_none() -> void:
	var shapes: Array[PlaceholderBody.Shape] = [PlaceholderBody.Shape.BOX, PlaceholderBody.Shape.CAPSULE,
			PlaceholderBody.Shape.CYLINDER, PlaceholderBody.Shape.SPHERE, PlaceholderBody.Shape.DOME]
	for shape: PlaceholderBody.Shape in shapes:
		assert_same(ToonMaterials.outline_for_part(shape), ToonMaterials.outline_for_part(shape), "one hull per shape")
		assert_not_same(ToonMaterials.outline_for_part(shape), ToonMaterials.outline_for_part(shape, true), "the player's own is another")
	assert_same(ToonMaterials.outline(), ToonMaterials.outline(), "one hull for the art")
	assert_eq(ToonMaterials.outline().get_shader_parameter(&"mode"), ToonMaterials.Hull.ART)
	assert_eq(ToonMaterials.outline_for_prop().get_shader_parameter(&"mode"), ToonMaterials.Hull.CYLINDER, "the pipe is a cylinder")
	Tuning.data.look_hull_on_placeholders = false
	for shape: PlaceholderBody.Shape in shapes:
		assert_null(ToonMaterials.outline_for_part(shape), "no hull on placeholders")
	assert_null(ToonMaterials.outline_for_prop())
	assert_not_null(ToonMaterials.outline(), "the art always has its hull")
	var rig := _rig()
	for mesh_instance: MeshInstance3D in _meshes(rig):
		assert_null(mesh_instance.material_overlay, "%s: no overlay without the hull" % mesh_instance.name)
	assert_eq(rig.paint.materials[PlaceholderBody.Paint.BODY].get_shader_parameter(&"edge_tag"), 1.0,
			"without its hull a placeholder is tagged for the edge pass's silhouette")


func test_the_art_hull_carries_its_baked_normal_through_the_skin() -> void:
	# The shader's mode 4 rotates the baked smooth normal by the turn from the vertex's rest
	# normal to its skinned one (a rest normal in CUSTOM1); the contract names COLOR and CUSTOM1.
	var source := _source(OUTLINE_PATH)
	assert_string_contains(source, "COLOR.rgb * 2.0 - 1.0")
	assert_string_contains(source, "CUSTOM1.xyz")
	assert_string_contains(source, "rotate_arc(normalize(rest_normal), normalize(NORMAL), smooth_rest)")


# --- The bands (the shader's math, mirrored) ---------------------------------------------------


func _shade(lit: float, mid: float = -1.0) -> Color:
	var d := Tuning.data
	return ToonMaterials.band_shade(lit, 0.0005, d.look_band_1, d.look_band_2, d.look_mid_level if mid < 0.0 else mid,
			d.look_shadow_level, d.look_shadow_tint, d.look_shadow_tint_amount)


func test_a_character_has_three_bands_and_a_shadow_that_is_never_black() -> void:
	var lit := _shade(1.0)
	var mid := _shade((Tuning.data.look_band_1 + Tuning.data.look_band_2) * 0.5)
	var shadow := _shade(-0.5)
	assert_eq(lit, Color.WHITE, "lit is the albedo as it is")
	assert_almost_eq(mid.get_luminance(), Tuning.data.look_mid_level, 0.001, "mid at 72% (the look bible)")
	assert_almost_eq(shadow.get_luminance(), Tuning.data.look_shadow_level, 0.001, "the shadow keeps its brightness once tinted")
	assert_gte(shadow.get_luminance(), 0.4, "never below 40% of the lit value (the look bible)")
	assert_gt(shadow.b, shadow.r, "the hue shifted toward the violet")
	assert_gt(shadow.b, shadow.g)
	assert_gt(shadow.r, 0.0, "never black")
	var distinct: Array[Color] = []
	for step in 41:
		var color := _shade(SWEEP_FROM + 1.4 * float(step) / 40.0)
		if not distinct.any(func(c: Color) -> bool: return c.is_equal_approx(color)):
			distinct.append(color)
	assert_eq(distinct.size(), 3, "three bands on a smooth sweep of light (edges a hair wide)")


func test_the_room_has_two_bands() -> void:
	var seen: Array[Color] = []
	for step in 41:
		var color := _shade(SWEEP_FROM + 1.4 * float(step) / 40.0, 1.0)
		if not seen.any(func(c: Color) -> bool: return c.is_equal_approx(color)):
			seen.append(color)
	assert_eq(seen.size(), 2, "lit and shadow: the mid band is as bright as the lit one")


func test_a_band_edge_is_half_way_at_its_break_and_steps_nowhere_else() -> void:
	var d := Tuning.data
	var below := ToonMaterials.band_shade(d.look_band_1 - 0.2, 0.01, d.look_band_1, d.look_band_2, d.look_mid_level, d.look_shadow_level, d.look_shadow_tint, d.look_shadow_tint_amount)
	var at := ToonMaterials.band_shade(d.look_band_1, 0.01, d.look_band_1, d.look_band_2, d.look_mid_level, d.look_shadow_level, d.look_shadow_tint, d.look_shadow_tint_amount)
	var above := ToonMaterials.band_shade(d.look_band_1 + 0.2, 0.01, d.look_band_1, d.look_band_2, d.look_mid_level, d.look_shadow_level, d.look_shadow_tint, d.look_shadow_tint_amount)
	assert_almost_eq(at.get_luminance(), (below.get_luminance() + above.get_luminance()) * 0.5, 0.01, "half way at the break")
	assert_almost_eq(above.get_luminance(), d.look_mid_level, 0.001, "flat in the band")


# --- Materials and the Tuning values that move them -------------------------------------------


func test_materials_take_the_look_values_now_and_on_every_change() -> void:
	var character := ToonMaterials.character(Color.RED, true)
	var glossy := ToonMaterials.character(Color.BLACK, false, true)
	var art := ToonMaterials.art(VfxArt.clear_detail())
	var prop := ToonMaterials.prop(Color.GRAY)
	var env := ToonMaterials.environment(Color.GRAY)
	var grid := ToonMaterials.grid()
	var d := Tuning.data
	for material: ShaderMaterial in [character, glossy, art, prop, env, grid]:
		assert_eq(material.get_shader_parameter(&"band_1"), d.look_band_1)
		assert_eq(material.get_shader_parameter(&"band_2"), d.look_band_2)
		assert_eq(material.get_shader_parameter(&"band_soft"), d.look_band_soft)
		assert_eq(material.get_shader_parameter(&"shadow_level"), d.look_shadow_level)
		assert_eq(material.get_shader_parameter(&"shadow_tint"), d.look_shadow_tint)
		assert_eq(material.get_shader_parameter(&"spec_cut"), d.look_spec_cut)
		assert_eq(material.get_shader_parameter(&"rim_cut"), d.look_rim_cut)
	# What differs by what a thing is.
	for material: ShaderMaterial in [character, glossy, art, prop]:
		assert_eq(material.get_shader_parameter(&"mid_level"), d.look_mid_level, "three bands on a character or a prop")
		assert_eq(material.get_shader_parameter(&"spec_strength"), d.look_spec_strength)
	for material: ShaderMaterial in [env, grid]:
		assert_eq(material.get_shader_parameter(&"mid_level"), 1.0, "two bands on the room")
		assert_eq(material.get_shader_parameter(&"spec_strength"), 0.0, "the room is matte")
	for material: ShaderMaterial in [character, art]:
		assert_eq(material.get_shader_parameter(&"rim_strength"), d.look_rim_strength, "a rim on characters")
	for material: ShaderMaterial in [prop, env, grid]:
		assert_eq(material.get_shader_parameter(&"rim_strength"), 0.0, "and on characters only")
	assert_eq(glossy.get_shader_parameter(&"spec_gloss"), d.look_spec_gloss, "shades and soles are glossy")
	assert_eq(prop.get_shader_parameter(&"spec_gloss"), d.look_spec_gloss, "so is the pipe")
	assert_eq(character.get_shader_parameter(&"spec_gloss"), 1.0)
	assert_eq(character.get_shader_parameter(&"halftone_strength"), 0.0, "halftone off by default (the look bible)")
	assert_eq(env.get_shader_parameter(&"halftone_strength"), 0.0)
	# A change moves every live material.
	Tuning.set_value(&"look_band_1", 0.3)
	Tuning.set_value(&"look_mid_level", 0.6)
	Tuning.set_value(&"look_rim_strength", 0.5)
	Tuning.set_value(&"look_halftone_env", true)
	Tuning.set_value(&"look_halftone_strength", 0.7)
	Tuning.set_value(&"look_shadow_tint", Color(0.5, 0.4, 0.8))
	for material: ShaderMaterial in [character, glossy, art, prop, env, grid]:
		assert_eq(material.get_shader_parameter(&"band_1"), 0.3, "the F1 panel's slider moves the whole game")
		assert_eq(material.get_shader_parameter(&"shadow_tint"), Color(0.5, 0.4, 0.8))
	assert_eq(character.get_shader_parameter(&"mid_level"), 0.6)
	assert_eq(env.get_shader_parameter(&"mid_level"), 1.0, "the room keeps two bands")
	assert_eq(character.get_shader_parameter(&"rim_strength"), 0.5)
	assert_eq(env.get_shader_parameter(&"halftone_strength"), 0.7, "halftone on the room only")
	assert_eq(grid.get_shader_parameter(&"halftone_strength"), 0.7)
	assert_eq(character.get_shader_parameter(&"halftone_strength"), 0.0)
	Tuning.set_value(&"look_halftone_chars", true)
	assert_eq(character.get_shader_parameter(&"halftone_strength"), 0.7)
	# A whole-set change (a preset load) moves them too, and an unrelated edit leaves them be.
	Tuning.apply(TuningData.new())
	assert_eq(character.get_shader_parameter(&"band_1"), TuningData.new().look_band_1)
	character.set_shader_parameter(&"band_1", 0.9)
	Tuning.set_value(&"hit_flash_frames", 3)
	assert_eq(character.get_shader_parameter(&"band_1"), 0.9, "a non-Look edit does not touch the look")


func test_hulls_take_the_outline_values() -> void:
	var hull := ToonMaterials.outline_for_part(PlaceholderBody.Shape.BOX)
	var own := ToonMaterials.outline_for_part(PlaceholderBody.Shape.BOX, true)
	var d := Tuning.data
	assert_eq(hull.get_shader_parameter(&"width_px"), d.look_outline_px)
	assert_eq(hull.get_shader_parameter(&"near_m"), d.look_outline_near_m)
	assert_eq(hull.get_shader_parameter(&"far_m"), d.look_outline_far_m)
	assert_eq(hull.get_shader_parameter(&"lens_fade_m"), d.look_outline_lens_fade_m)
	assert_eq(hull.get_shader_parameter(&"fp_scale"), 1.0)
	assert_eq(own.get_shader_parameter(&"fp_scale"), d.look_outline_fp_scale)
	assert_eq(hull.get_shader_parameter(&"ink"), HudStyle.INK, "one ink for the hull and the HUD")
	Tuning.set_value(&"look_outline_px", 5.0)
	Tuning.set_value(&"look_outline_fp_scale", 0.5)
	Tuning.set_value(&"look_outline_far_m", 20.0)
	assert_eq(hull.get_shader_parameter(&"width_px"), 5.0)
	assert_eq(own.get_shader_parameter(&"fp_scale"), 0.5)
	assert_eq(hull.get_shader_parameter(&"far_m"), 20.0)
	Tuning.set_value(&"look_outline_near_m", 30.0)
	assert_gt(float(hull.get_shader_parameter(&"far_m")), 30.0, "far stays past near")


func test_dead_materials_leave_the_registry() -> void:
	var before := ToonMaterials._live.size()
	for i in 20:
		ToonMaterials.character(Color(float(i) / 20.0, 0.5, 0.5))
	assert_gte(ToonMaterials._live.size(), before + 20, "tracked weakly while alive")
	Tuning.set_value(&"look_band_2", 0.5)
	assert_lt(ToonMaterials._live.size(), before + 20, "the dead ones are dropped on the next change")
	# And without any change at all, a long run of spawns sweeps them as it goes.
	for i in 1500:
		ToonMaterials.character(Color(0.5, float(i % 7) / 7.0, 0.5))
	assert_lt(ToonMaterials._live.size(), 1200, "the registry is swept as it grows")


func test_the_edge_tag_marks_what_has_its_own_hull() -> void:
	assert_eq(ToonMaterials.character(Color.RED).get_shader_parameter(&"edge_tag"), 0.0, "a placeholder with its hull")
	assert_eq(ToonMaterials.art(null).get_shader_parameter(&"edge_tag"), 0.0, "the art")
	assert_eq(ToonMaterials.prop(Color.GRAY).get_shader_parameter(&"edge_tag"), 0.0)
	assert_eq(ToonMaterials.environment(Color.GRAY).get_shader_parameter(&"edge_tag"), 1.0, "the room takes edge lines")
	assert_eq(ToonMaterials.environment(Color.GRAY, true).get_shader_parameter(&"edge_tag"), 0.0, "a prop box with its hull")
	Tuning.data.look_hull_on_placeholders = false
	assert_eq(ToonMaterials.character(Color.RED).get_shader_parameter(&"edge_tag"), 1.0)
	assert_eq(ToonMaterials.environment(Color.GRAY, true).get_shader_parameter(&"edge_tag"), 1.0)
	assert_null(ToonMaterials.environment(Color.GRAY, true).next_pass, "and no hull")


func test_a_prop_box_takes_its_hull_as_its_next_pass() -> void:
	var material := ToonMaterials.environment(Color(0.55, 0.46, 0.3), true)
	assert_not_null(material.next_pass)
	assert_eq((material.next_pass as ShaderMaterial).get_shader_parameter(&"mode"), ToonMaterials.Hull.BOX)
	var box := RoomKit.box_mesh(Vector3(1.0, 1.0, 1.0), material)
	autofree(box)
	assert_same((box.mesh as BoxMesh).material, material, "a room's box draws it")
	assert_null(ToonMaterials.environment(Color.GRAY).next_pass, "a wall has none")


# --- The rig's materials: flash, damage, sets ---------------------------------------------------


func test_a_rig_has_one_toon_material_per_paint_and_the_dark_one_is_glossy_and_takes_no_marks() -> void:
	var rig := _rig()
	var mats: Dictionary[int, ShaderMaterial] = rig.get(&"_materials")
	assert_eq(mats.size(), PlaceholderBody.Paint.values().size())
	var seen: Array[ShaderMaterial] = []
	for paint: int in mats:
		assert_false(seen.has(mats[paint]), "one material per paint")
		seen.append(mats[paint])
		assert_eq(mats[paint].shader, ToonMaterials.TOON_SHADER)
		assert_eq(mats[paint].get_shader_parameter(&"spec_gloss"), Tuning.data.look_spec_gloss if paint == PlaceholderBody.Paint.DARK else 1.0,
				"only the shades, belt and soles are glossy")
		assert_eq(float(mats[paint].get_shader_parameter(&"marks")) > 0.5, DamageLook.bruisable(paint))
	var other := _rig()
	for paint: int in mats:
		assert_not_same(mats[paint], (other.get(&"_materials") as Dictionary[int, ShaderMaterial])[paint], "one set per rig, so flashes stay per actor")
	assert_false((load("res://game/actors/humanoid_rig.gd") as GDScript).get_script_constant_map().has("_FLASH_SHADER"),
			"the rig has no second copy of the flash shader: RigPaint.FLASH_SHADER is the one")
	assert_eq(RigPaint.FLASH_SHADER, load("res://game/fx/hit_flash.gdshader"))


func test_the_contact_flash_keeps_next_pass_and_the_hull_keeps_the_overlay() -> void:
	var rig := _rig()
	rig.flash_at(Vector3(0.0, 1.0, -0.3), 1.0, 0.5, 0.5)
	var overlay := rig.flash_overlay()
	assert_not_null(overlay)
	assert_eq(overlay.shader, RigPaint.FLASH_SHADER)
	for mesh_instance: MeshInstance3D in _meshes(rig):
		var base := mesh_instance.material_override as ShaderMaterial
		assert_same(base.next_pass, overlay, "%s: the flash is the base material's next pass" % mesh_instance.name)
		assert_eq((mesh_instance.material_overlay as ShaderMaterial).shader, ToonMaterials.OUTLINE_SHADER,
				"%s: and its hull is still on the overlay slot" % mesh_instance.name)
		assert_null((mesh_instance.material_overlay as ShaderMaterial).next_pass, "the hull carries no pass of its own")
	rig.set_flash(0.0)
	for mesh_instance: MeshInstance3D in _meshes(rig):
		assert_null((mesh_instance.material_override as ShaderMaterial).next_pass)
		assert_not_null(mesh_instance.material_overlay, "%s keeps its hull after the flash" % mesh_instance.name)


func _art_rig() -> HumanoidRig:
	var art := CharacterArt.new()
	art.id = &"fixture"
	art.palette = VfxArt.clear_detail()
	art.triangle_budget = 100
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	rig.art = art
	add_child_autofree(rig)
	rig.build()
	return rig


func test_the_art_material_flashes_and_takes_the_damage_look_by_texture_swaps_alone() -> void:
	var rig := _art_rig()
	var art := rig.paint.art_material() as ShaderMaterial
	assert_not_null(art)
	assert_eq(art.shader, ToonMaterials.TOON_SHADER, "the same shader as the primitives")
	assert_true(bool(art.get_shader_parameter(&"use_rest_custom")), "marks from the rest pose, so they stick to the moving body")
	assert_true(bool(art.get_shader_parameter(&"use_albedo_tex")))
	assert_eq(art.get_shader_parameter(&"edge_tag"), 0.0)
	assert_has(rig.paint.base_materials(), art)
	var declared := _uniforms(TOON_PATH)
	declared.merge(_uniforms(LIGHT_PATH))
	var before := {}
	for name: String in declared:
		if name != "damage_tex" and name != "damage_skin_tex" and name != "damage_scale":
			before[name] = art.get_shader_parameter(name)
	for level: int in [DamageLook.Level.BRUISED, DamageLook.Level.BLOODIED, DamageLook.Level.CLEAN, DamageLook.Level.BRUISED]:
		rig.set_damage_look(level)
		var tex: Variant = art.get_shader_parameter(&"damage_tex")
		var skin_tex: Variant = art.get_shader_parameter(&"damage_skin_tex")
		match level:
			DamageLook.Level.CLEAN:
				assert_eq(tex, VfxArt.clear_detail())
				assert_eq(skin_tex, VfxArt.clear_detail())
			DamageLook.Level.BRUISED:
				assert_eq(tex, VfxArt.texture(&"damage_scuffed"), "the clothes' tile (the swatches' alpha class picks it)")
				assert_eq(skin_tex, VfxArt.texture(&"damage_bruised"), "the skin's tile, the primitives' bruises")
			DamageLook.Level.BLOODIED:
				assert_eq(tex, VfxArt.texture(&"damage_blood"))
				assert_eq(skin_tex, VfxArt.texture(&"damage_bloodied"))
		assert_eq(art.shader, ToonMaterials.TOON_SHADER, "a look swaps textures only: the same shader")
		for name: String in before:
			assert_eq(art.get_shader_parameter(name), before[name], "level %d leaves %s alone" % [level, name])
	rig.set_flash(0.6, Color.CYAN)
	assert_eq(art.get_shader_parameter(&"flash_color"), Color.CYAN)
	assert_almost_eq(float(art.get_shader_parameter(&"flash_amount")), 0.6, 1e-6, "the parry flash covers the art")
	assert_eq(art.get_shader_parameter(&"damage_tex"), VfxArt.texture(&"damage_scuffed"), "over the marks")
	rig.set_flash(0.0)


func test_the_art_hull_and_the_materials_of_a_rig_with_art() -> void:
	var rig := _art_rig()
	assert_eq(rig.paint.outline_material(), ToonMaterials.outline(), "the art's hull, shared")
	assert_eq(rig.paint.art_material().get_shader_parameter(&"use_detail_tex"), false, "an enemy has no detail mask (Spec §10)")


# --- set_shown and the first-person layers over the hulls ---------------------------------------


func test_set_shown_false_hides_every_hull() -> void:
	var rig := _rig()
	var meshes := _meshes(rig)
	for mesh_instance: MeshInstance3D in meshes:
		assert_not_null(mesh_instance.material_overlay)
		assert_true(mesh_instance.is_visible_in_tree(), "%s and its hull draw" % mesh_instance.name)
	rig.set_shown(false)
	for mesh_instance: MeshInstance3D in meshes:
		assert_false(mesh_instance.is_visible_in_tree(), "%s: a KO's blink-off hides the hull with the body" % mesh_instance.name)
	rig.set_shown(true)
	for mesh_instance: MeshInstance3D in meshes:
		assert_true(mesh_instance.is_visible_in_tree())


func test_the_hulls_of_the_first_person_hidden_meshes_stay_off_the_cameras_layer() -> void:
	var rig := _rig(true)
	var parts := _parts_by_name(true)
	var camera := FirstPersonCamera.new()
	autofree(camera)
	assert_false(camera.get_cull_mask_value(CombatTypes.VIS_FP_HIDDEN), "the lens never draws the hidden layer, hulls and all")
	assert_true(camera.get_cull_mask_value(CombatTypes.VIS_DEFAULT))
	var hidden := 0
	for mesh_instance: MeshInstance3D in _meshes(rig):
		if PlaceholderBody.is_fp_hidden(parts[mesh_instance.name]):
			hidden += 1
			assert_eq(mesh_instance.layers, CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN), "%s is on the hidden layer" % mesh_instance.name)
			assert_not_null(mesh_instance.material_overlay, "%s has a hull (the KO view shows the whole body)" % mesh_instance.name)
		else:
			assert_eq(mesh_instance.layers, CombatTypes.bit(CombatTypes.VIS_DEFAULT), "%s is on the default layer" % mesh_instance.name)
	assert_gt(hidden, 10, "the head, neck, chest, shoulders and upper-arm ends")


# --- The detail mask on UV2 (M4-plan A18) -------------------------------------------------------


## A fixture mesh: a quad with palette UVs on a swatch and a UV2 channel running across it, for a
## detail mask that is ink on its left half (the stand-in for the probe body until its GLB lands).
func _uv2_quad() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners: Array[Vector3] = [Vector3(-1, -1, 0), Vector3(1, -1, 0), Vector3(1, 1, 0), Vector3(-1, 1, 0)]
	var uv2: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for index: int in [0, 1, 2, 0, 2, 3]:
		tool.set_normal(Vector3.BACK)
		tool.set_uv(Vector2(0.03, 0.03))
		tool.set_uv2(uv2[index])
		tool.add_vertex(corners[index])
	return tool.commit()


func test_the_detail_mask_is_a_uv2_ink_multiply_available_to_any_art() -> void:
	var mesh := _uv2_quad()
	var arrays := mesh.surface_get_arrays(0)
	assert_eq((arrays[Mesh.ARRAY_TEX_UV2] as PackedVector2Array).size(), 6, "the fixture has UV2")
	var mask_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	mask_image.fill(Color(0, 0, 0, 1))
	for y in 4:
		for x in 2:
			mask_image.set_pixel(x, y, Color(1, 0, 0, 1))
	var mask := ImageTexture.create_from_image(mask_image)
	var plain := ToonMaterials.art(VfxArt.clear_detail())
	var masked := ToonMaterials.art(VfxArt.clear_detail(), mask)
	assert_false(bool(plain.get_shader_parameter(&"use_detail_tex")), "no mask by default (the Punk ships without one)")
	assert_true(bool(masked.get_shader_parameter(&"use_detail_tex")))
	assert_eq(masked.get_shader_parameter(&"detail_tex"), mask)
	assert_eq(masked.shader, plain.shader, "the mask is a uniform, never a shader variant")
	assert_eq(masked.get_shader_parameter(&"ink"), HudStyle.INK, "toward the one ink")
	var shader := _source(TOON_PATH)
	assert_string_contains(shader, "texture(detail_tex, UV2).r", "R of the mask, on the second UV set")
	assert_string_contains(shader, "color = mix(color, ink,", "toward ink, never shading")
	# A rig's art takes the CharacterArt's mask.
	var art := CharacterArt.new()
	art.id = &"player"
	art.palette = VfxArt.clear_detail()
	art.detail_mask = mask
	art.triangle_budget = 100
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	rig.art = art
	add_child_autofree(rig)
	rig.build()
	assert_eq(rig.paint.art_material().get_shader_parameter(&"detail_tex"), mask)
	assert_true(bool(rig.paint.art_material().get_shader_parameter(&"use_detail_tex")))


func test_warming_up_is_a_headless_no_op() -> void:
	var children := get_child_count()
	ToonMaterials.warm_up(self)
	assert_eq(get_child_count(), children)
	assert_null(find_child("ToonWarmUp", false, false))


# --- The art fixture (the stand-in for the probe body until its GLB lands) ----------------------


func test_the_art_fixture_has_every_channel_a_real_art_brings() -> void:
	var Probe := preload("res://tests/fixtures/toon_art_probe.gd")
	var mesh := Probe.mesh()
	var format := mesh.surface_get_format(0)
	for flag: int in [Mesh.ARRAY_FORMAT_VERTEX, Mesh.ARRAY_FORMAT_NORMAL, Mesh.ARRAY_FORMAT_COLOR, Mesh.ARRAY_FORMAT_TEX_UV,
			Mesh.ARRAY_FORMAT_TEX_UV2, Mesh.ARRAY_FORMAT_CUSTOM0, Mesh.ARRAY_FORMAT_CUSTOM1, Mesh.ARRAY_FORMAT_BONES,
			Mesh.ARRAY_FORMAT_WEIGHTS]:
		assert_ne(format & flag, 0, "the fixture has format flag %d" % flag)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var rest_position: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var rest_normal: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
	assert_eq(rest_position.size(), vertices.size() * 3, "CUSTOM0 is the rest position (RGB float)")
	assert_eq(rest_normal.size(), vertices.size() * 3, "CUSTOM1 is the rest normal (RGB float)")
	for i in vertices.size():
		assert_almost_eq(Vector3(rest_position[i * 3], rest_position[i * 3 + 1], rest_position[i * 3 + 2]), vertices[i], Vector3.ONE * 1e-5)
		var baked := Vector3(colors[i].r, colors[i].g, colors[i].b) * 2.0 - Vector3.ONE
		assert_almost_eq(baked, normals[i], Vector3.ONE * 0.01, "COLOR is the smooth normal as n * 0.5 + 0.5")
		assert_between(uv2[i].x, 0.0, 1.0)
		assert_between(uv2[i].y, 0.0, 1.0)
		assert_between(vertices[i].y, -0.001, Probe.HEIGHT + 0.001, "stands on y = 0")
	assert_almost_eq(mesh.get_aabb().size.y, Probe.HEIGHT, 0.01)


func test_the_art_fixture_draws_with_the_art_material_and_its_mask_headless() -> void:
	var Probe := preload("res://tests/fixtures/toon_art_probe.gd")
	var atlas := Probe.atlas()
	var material := ToonMaterials.art(atlas, Probe.mask())
	var holder := Node3D.new()
	add_child_autofree(holder)
	var skeleton := Probe.build(holder, material, ToonMaterials.outline(), 45.0)
	var instance := skeleton.get_node("ArtFixture") as MeshInstance3D
	assert_eq(instance.material_override, material)
	assert_eq((instance.material_overlay as ShaderMaterial).get_shader_parameter(&"mode"), ToonMaterials.Hull.ART)
	assert_eq(skeleton.get_bone_count(), 2)
	assert_eq(instance.skin.get_bind_count(), 2)
	# The marks: swatches with alpha 1 take the clothes' (a skin swatch, alpha 0.8, the skin's), the dark swatch (alpha 0.5) none.
	var image := atlas.get_image()
	assert_eq(image.get_pixelv(Vector2i(Probe.swatch_uv(Probe.SLOT_SKIN) * Vector2(Probe.ATLAS_SIZE))).a, 1.0)
	assert_almost_eq(image.get_pixelv(Vector2i(Probe.swatch_uv(Probe.SLOT_DARK) * Vector2(Probe.ATLAS_SIZE))).a, 0.5, 0.01)
	assert_string_contains(_source(TOON_PATH), "takes_marks *= step(0.75, swatch.a)")
	# The skin class (slice-g2-07): the alpha under 0.9 picks damage_skin_tex over damage_tex in the triplanar, and the
	# unset skin texture is transparent, so a material nobody filled shows a clean skin.
	assert_string_contains(_source(TOON_PATH), "skin_marks = 1.0 - step(0.9, swatch.a)")
	assert_string_contains(_source(TOON_PATH), "d = mix(d, d_skin, skin_marks)")
	assert_string_contains(_uniforms(TOON_PATH)["damage_skin_tex"], "hint_default_transparent")
