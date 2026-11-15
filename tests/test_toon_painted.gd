extends GutTest
## Milestone 7, T11: the painted material, its hull, the area look and the grain on the trim (docs/ARCHITECTURE.md
## "The painted material (M7)"). The fixture is the Punk's GLB with generated placeholder paint and ink maps
## (tests/fixtures/m7/gen_painted_fixture.gd), worn as the trailer variant of a base Punk art. Shader maths is read through the
## CPU mirrors in ToonMaterials, as the M4 tests read the toon lighting.

const LookProfileHelper := preload("res://tests/look_profile_helper.gd")
const BASE_PATH := "res://tests/fixtures/m7/punk_with_painted_art.tres"
const INK_PATH := "res://tests/fixtures/m7/painted_ink.png"
const ATLAS := "res://assets/export/palette/palette_atlas.png"
const PAINTED_SHADER_PATH := "res://game/fx/toon_painted.gdshader"
const PAINTED_HULL_PATH := "res://game/fx/toon_outline_painted.gdshader"

var _base: CharacterArt


func before_each() -> void:
	Tuning.reset_to_default()
	LookProfileHelper.use_m6()
	ToonMaterials.clear_area_look()
	_base = load(BASE_PATH) as CharacterArt


func after_each() -> void:
	Tuning.reset_to_default()
	ToonMaterials.clear_area_look()


func _rig(art: CharacterArt) -> HumanoidRig:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	rig.art = art
	add_child_autofree(rig)
	rig.build()
	return rig


func _uniforms(material: ShaderMaterial) -> Dictionary:
	var values := {}
	for uniform: Dictionary in material.shader.get_shader_uniform_list():
		values[uniform.name] = material.get_shader_parameter(uniform.name)
	return values


func _ink_pixel(u: float, v: float) -> Color:
	var image := (load(INK_PATH) as Texture2D).get_image()
	return image.get_pixel(int(u * image.get_width()), int(v * image.get_height()))


# --- the fixture and the hook ---

func test_the_fixture_is_painted_and_the_base_is_not() -> void:
	assert_true(ToonMaterials.is_painted(_base.trailer_art()))
	assert_false(ToonMaterials.is_painted(_base))
	assert_false(ToonMaterials.is_painted(null))
	assert_true(SkinnedArt.check(_base.trailer_art()).is_empty(), "the variant keeps the art contract")
	assert_eq(ToonMaterials.art_for(_base).shader, ToonMaterials.TOON_SHADER, "an unpainted art is the toon shader's, as ever")
	assert_eq(ToonMaterials.art_for(_base.trailer_art()).shader, ToonMaterials.PAINTED_SHADER)
	assert_same(ToonMaterials.outline_for_art(_base), ToonMaterials.outline(), "an unpainted art keeps the shared hull")
	assert_same(ToonMaterials.outline_for_art(null), ToonMaterials.outline())


func test_the_maps_follow_the_contract() -> void:
	var ink := load(INK_PATH) as Texture2D
	assert_eq(ink.get_width(), ink.get_height())
	assert_true(ink.get_image().has_mipmaps() or ink.get_image().get_width() > 0)
	# G: the damage classes, as the atlas's alpha bytes; B: gloss; A: the weight, by V alone.
	assert_eq(roundi(_ink_pixel(0.1, 0.5).g * 255.0), 255)
	assert_eq(roundi(_ink_pixel(0.3, 0.5).g * 255.0), 230)
	assert_eq(roundi(_ink_pixel(0.6, 0.5).g * 255.0), 204)
	assert_eq(roundi(_ink_pixel(0.9, 0.5).g * 255.0), 128)
	assert_gt(_ink_pixel(0.55, 0.5).b, 0.9, "the glossy strip")
	assert_lt(_ink_pixel(0.1, 0.5).b, 0.1)
	assert_gt(_ink_pixel(0.1, 0.5).a, _ink_pixel(0.1, 0.02).a, "the weight tapers toward the ends of V")


func test_a_painted_material_is_the_painted_shader_with_its_maps() -> void:
	var art := _base.trailer_art()
	var material := ToonMaterials.art_for(art)
	assert_eq(material.shader.resource_path, PAINTED_SHADER_PATH)
	assert_eq(material.get_shader_parameter(&"paint_tex"), art.get_meta(ToonMaterials.PAINT_META))
	assert_eq(material.get_shader_parameter(&"ink_tex"), art.get_meta(ToonMaterials.INK_META))
	assert_eq(material.get_shader_parameter(&"marks"), 1.0)
	assert_eq(material.get_shader_parameter(&"edge_tag"), 0.0, "the art always has its hull")
	var data := Tuning.data
	assert_eq(material.get_shader_parameter(&"paint_cut"), data.look_paint_cut)
	assert_eq(material.get_shader_parameter(&"paint_grain"), data.look_paint_grain)
	assert_eq(material.get_shader_parameter(&"paint_rim_px"), data.look_paint_rim_px)
	# A tunable moves it live, like the rest of the Look values.
	Tuning.set_value(&"look_paint_cut", 0.5)
	assert_eq(material.get_shader_parameter(&"paint_cut"), 0.5)


func test_the_rig_wears_the_painted_variant_with_its_own_hull_and_flips_back() -> void:
	var rig := _rig(_base)
	var m6_mesh := rig.art_meshes()[0]
	var m6_material := m6_mesh.material_override as ShaderMaterial
	assert_eq(m6_material.shader, ToonMaterials.TOON_SHADER)
	assert_same(m6_mesh.material_overlay, ToonMaterials.outline())
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	var mesh := rig.art_meshes()[0]
	var material := mesh.material_override as ShaderMaterial
	assert_eq(material.shader.resource_path, PAINTED_SHADER_PATH, "painted under the trailer profile")
	var hull := mesh.material_overlay as ShaderMaterial
	assert_eq(hull.shader.resource_path, PAINTED_HULL_PATH)
	assert_eq(hull.get_shader_parameter(&"ink_tex"), _base.trailer_art().get_meta(ToonMaterials.INK_META))
	assert_eq(hull.get_shader_parameter(&"near_gain"), Tuning.data.look_paint_hull_near_gain)
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	var back := rig.art_meshes()[0]
	assert_same(back.material_override, m6_material, "m6's very material comes back")
	assert_same(back.material_overlay, ToonMaterials.outline(), "and the shared hull")


# --- damage marks and the glint, as the m6 path has them ---

func test_damage_marks_reach_a_painted_material_as_they_reach_the_atlas_one() -> void:
	var m6 := ToonMaterials.art_for(_base)
	var painted := ToonMaterials.art_for(_base.trailer_art())
	for level: int in [DamageLook.Level.CLEAN, DamageLook.Level.BRUISED, DamageLook.Level.BLOODIED]:
		DamageLook.apply_art(m6, level)
		DamageLook.apply_art(painted, level)
		for name: StringName in [&"damage_tex", &"damage_skin_tex", &"damage_scuff_tex", &"blood_edge", &"damage_scale"]:
			assert_eq(painted.get_shader_parameter(name), m6.get_shader_parameter(name), "%s at level %d" % [name, level])
	# And the rig's own paths reach it: the flash and the damage look.
	var rig := _rig(_base)
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	rig.set_flash(0.6, Color.RED)
	rig.set_damage_look(DamageLook.Level.BLOODIED)
	var material := rig.art_meshes()[0].material_override as ShaderMaterial
	assert_eq(material.get_shader_parameter(&"flash_amount"), 0.6)
	assert_eq(material.get_shader_parameter(&"flash_color"), Color.RED)
	assert_eq(material.get_shader_parameter(&"damage_tex"), DamageLook.texture_for(PlaceholderBody.Paint.BODY, DamageLook.Level.BLOODIED))


func test_the_ink_map_classes_choose_the_tile_the_atlas_alpha_would() -> void:
	# A class byte in the ink map's G is the byte the atlas's alpha has: the same tile at every look.
	var expected := {255: ToonMaterials.PaintClass.CLOTHES, 230: ToonMaterials.PaintClass.CLOTHES_NO_BLOOD,
			204: ToonMaterials.PaintClass.SKIN, 128: ToonMaterials.PaintClass.NONE}
	for byte: int in expected:
		assert_eq(ToonMaterials.painted_class(float(byte) / 255.0), expected[byte], "class byte %d" % byte)
		for level: int in [DamageLook.Level.BRUISED, DamageLook.Level.BLOODIED]:
			var tile := DamageLook.art_tile_for_alpha(float(byte) / 255.0, level)
			match expected[byte]:
				ToonMaterials.PaintClass.NONE:
					assert_null(tile)
				ToonMaterials.PaintClass.SKIN:
					assert_eq(tile, DamageLook.texture_for(PlaceholderBody.Paint.SKIN, level))
				_:
					assert_not_null(tile)
	# The atlas's glossy marking (a class byte minus one step) is not the painted gloss: B carries it, and is read at one half.
	assert_true(ToonMaterials.painted_glossy(1.0))
	assert_true(ToonMaterials.painted_glossy(0.5))
	assert_false(ToonMaterials.painted_glossy(0.0))
	assert_false(ToonMaterials.painted_glossy(0.49))
	# The painted material carries the glint's tunables the atlas one does.
	var material := ToonMaterials.art_for(_base.trailer_art())
	var atlas_material := ToonMaterials.art_for(_base)
	for name: StringName in [&"glint_cut", &"glint_strength", &"spec_cut", &"spec_strength", &"spec_gloss", &"fill_dir"]:
		assert_eq(material.get_shader_parameter(name), atlas_material.get_shader_parameter(name), String(name))


# --- two tones, and a night with no flooded shadow ---

func test_two_flat_tones_and_a_shadow_that_is_never_black() -> void:
	var hue := Color(0.2, 0.2, 0.6)
	var shadow := ToonMaterials.painted_shade(0.0, 0.01, 0.42, 0.58, hue, 0.75)
	var lit := ToonMaterials.painted_shade(1.0, 0.01, 0.42, 0.58, hue, 0.75)
	assert_eq(lit, Color.WHITE, "the lit tone is the paint as it is")
	assert_gt(shadow.get_luminance(), 0.3, "the shadow tone stays readable")
	assert_gt(shadow.b, shadow.r, "and carries the area's hue")
	assert_almost_eq(shadow.get_luminance(), 0.58, 0.02, "its brightness is the level")
	assert_eq(ToonMaterials.painted_shade(0.3, 0.01, 0.42, 0.58, hue, 0.75), shadow, "no mid band: anything under the cut is the shadow tone")
	assert_eq(ToonMaterials.painted_shade(0.5, 0.01, 0.42, 0.58, hue, 0.75), lit)


func test_a_lamp_adds_nothing_inside_the_shadow_band() -> void:
	var hue := Color(0.2, 0.2, 0.6)
	var shadow := ToonMaterials.painted_shade(0.0, 0.01, 0.42, 0.58, hue, 0.75)
	for lit_value: float in [0.0, 0.1, 0.3, 0.4]:
		var shade := ToonMaterials.painted_shade(lit_value, 0.01, 0.42, 0.58, hue, 0.75)
		assert_eq(ToonMaterials.painted_lamp_add(shade, shadow), Color(0, 0, 0, 1), "lit %.1f is in the shadow band" % lit_value)
	var in_pool := ToonMaterials.painted_lamp_add(ToonMaterials.painted_shade(0.9, 0.01, 0.42, 0.58, hue, 0.75), shadow)
	assert_gt(in_pool.r, 0.1, "inside its pool a lamp lifts the paint to the lit tone")
	var shader_source := (load(PAINTED_SHADER_PATH) as Shader).code
	assert_true(shader_source.contains("max(shade - shadow, vec3(0.0))"), "the shader does what the mirror does")


func test_the_area_gives_the_shadow_hue_and_the_rim_colour() -> void:
	var material := ToonMaterials.art_for(_base.trailer_art())
	assert_eq(material.get_shader_parameter(&"paint_shadow_hue"), Tuning.data.look_paint_shadow_hue)
	assert_eq(material.get_shader_parameter(&"paint_rim_color"), Tuning.data.look_paint_rim_color)
	ToonMaterials.set_area_look(Color(0.5, 0.2, 0.3), Color(1.0, 0.8, 0.5))
	assert_eq(material.get_shader_parameter(&"paint_shadow_hue"), Color(0.5, 0.2, 0.3), "a live material takes it at once")
	assert_eq(ToonMaterials.art_for(_base.trailer_art()).get_shader_parameter(&"paint_rim_color"), Color(1.0, 0.8, 0.5), "and a new one")
	ToonMaterials.clear_area_look()
	assert_eq(material.get_shader_parameter(&"paint_shadow_hue"), Tuning.data.look_paint_shadow_hue)


# --- the hull ---

func _width(dist: float, hint: float = 1.0, facing_down: float = 0.0) -> float:
	var d := Tuning.data
	return ToonMaterials.painted_hull_width_m(dist, d.look_outline_px, 1.7, 1080.0, d.look_outline_near_m, d.look_outline_far_m,
			d.look_outline_lens_fade_m, 1.0, d.look_paint_hull_near_gain, d.look_paint_hull_boost_to_m, d.look_paint_hull_thin_from_m,
			d.look_paint_hull_far_gain, hint, d.look_paint_hull_weight_min, d.look_paint_hull_weight_max, facing_down, d.look_paint_hull_under_bias)


func _m6_width(dist: float) -> float:
	var d := Tuning.data
	return ToonMaterials.outline_width_m(dist, d.look_outline_px, 1.7, 1080.0, d.look_outline_near_m, d.look_outline_far_m, d.look_outline_lens_fade_m)


func test_the_painted_line_is_heavier_than_m6_near_the_lens_and_thins_with_distance() -> void:
	var d := Tuning.data
	var at := d.look_outline_near_m + 0.5
	# a full weight hint and a surface facing sideways: the distance gain alone
	assert_gt(_width(at, 1.0) / _m6_width(at), 1.0 + (d.look_paint_hull_weight_max - 1.0) - 0.001, "heavier than m6 near the camera")
	var far := d.look_outline_far_m
	assert_lt(_width(far, 1.0) / _m6_width(far), d.look_paint_hull_weight_max, "the gain has thinned the line by the far distance")
	var in_pixels_near := _width(1.5) / (2.0 * 1.5 / (1.7 * 1080.0) * 1080.0 / 1080.0)
	var in_pixels_far := _width(far) / (2.0 * far / (1.7 * 1080.0))
	assert_gt(in_pixels_near, in_pixels_far, "in pixels the line thins with distance")


func test_the_width_varies_along_a_limb_with_the_ink_weight_and_the_form() -> void:
	assert_gt(_width(3.0, 1.0), _width(3.0, 0.1), "a painted taper: the hint's 1 is heavier than its 0.1")
	assert_gt(_width(3.0, 0.5, 1.0), _width(3.0, 0.5, 0.0), "ink weighs under a form")
	assert_gt(_width(3.0, 0.5, 0.0), _width(3.0, 0.5, -1.0), "and lightens on top")
	assert_almost_eq(_width(0.0), 0.0, 0.00001, "no line inside the lens")
	assert_eq(_width(3.0, 0.5, 5.0), _width(3.0, 0.5, 1.0), "the facing is clamped")


func test_the_painted_hull_takes_the_profile_ink_width_scale() -> void:
	var hull := ToonMaterials.outline_painted(load(INK_PATH) as Texture2D)
	assert_same(hull, ToonMaterials.outline_painted(load(INK_PATH) as Texture2D), "one hull per ink map")
	assert_ne(hull, ToonMaterials.outline_painted(load(INK_PATH) as Texture2D, true), "and per first-person flag")
	var before: float = hull.get_shader_parameter(&"width_px")
	assert_eq(before, Tuning.data.look_outline_px * LookProfile.ink_width_scale())
	assert_eq(hull.get_shader_parameter(&"fp_scale"), 1.0)
	assert_eq(ToonMaterials.outline_painted(load(INK_PATH) as Texture2D, true).get_shader_parameter(&"fp_scale"), Tuning.data.look_outline_fp_scale)


# --- m6 stays as it was ---

func test_m6_materials_have_exactly_their_old_uniforms_and_the_trim_grain_is_trailer_only() -> void:
	for kind: String in ["trim", "scissor"]:
		var material := ToonMaterials.trim() if kind == "trim" else ToonMaterials.trim_scissor()
		assert_null(material.get_shader_parameter(&"grain_amount"), "%s: no grain uniform of its own, under m6 or not" % kind)
	assert_eq(ToonMaterials.trim_grain.x, 0.0, "no grain under m6")
	var before := {
		trim = _uniforms(ToonMaterials.trim()), scissor = _uniforms(ToonMaterials.trim_scissor()),
		art = _uniforms(ToonMaterials.art(load(ATLAS) as Texture2D)), hull = _uniforms(ToonMaterials.outline()),
		character = _uniforms(ToonMaterials.character(Color.RED, true, true)),
		environment = _uniforms(ToonMaterials.environment(Color.GRAY, true)),
	}
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	assert_eq(ToonMaterials.trim_grain, Vector2(Tuning.data.look_paint_trim_grain, Tuning.data.look_paint_trim_grain_cells), "the trailer profile's grain")
	# The trailer kit (T15) puts its own sheets on the trim (trim_tex, ground_tex, strips: the lead's decision at the Phase 1
	# merge); every other uniform of the trim's own is untouched by the grain.
	var trailer_trim := _uniforms(ToonMaterials.trim())
	var m6_trim: Dictionary = (before.trim as Dictionary).duplicate()
	for sheet: String in ["trim_tex", "ground_tex", "strips"]:
		trailer_trim.erase(sheet)
		m6_trim.erase(sheet)
	assert_eq(trailer_trim, m6_trim, "and the trim material's own uniforms did not move but the kit's sheets")
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	assert_eq(ToonMaterials.trim_grain.x, 0.0, "flipped back: no grain")
	assert_eq(_uniforms(ToonMaterials.trim()), before.trim, "trim: m6's uniforms again")
	assert_eq(_uniforms(ToonMaterials.trim_scissor()), before.scissor)
	assert_eq(_uniforms(ToonMaterials.outline()), before.hull, "the shared hull is untouched by the painted one")
	var art_now := _uniforms(ToonMaterials.art(load(ATLAS) as Texture2D))
	for name: Variant in before.art:
		assert_eq(art_now[name], before.art[name], String(name))
	for name: Variant in before.character:
		assert_eq(_uniforms(ToonMaterials.character(Color.RED, true, true))[name], before.character[name], String(name))


func test_the_toon_shader_and_the_trim_know_nothing_of_the_painted_path_but_the_grain() -> void:
	var toon := (ToonMaterials.TOON_SHADER as Shader).code
	assert_false(toon.contains("paint_"), "toon.gdshader has no painted uniform")
	for uniform: Dictionary in (load("res://game/fx/trim.gdshader") as Shader).get_shader_uniform_list():
		if String(uniform.name).begins_with("paint_"):
			fail_test("trim.gdshader has %s" % uniform.name)


func test_the_painted_tunables_sit_in_their_own_group_before_audio() -> void:
	var group := ""
	var found := 0
	var groups: Array[String] = []
	for info: Dictionary in TuningData.new().get_property_list():
		if int(info.usage) & PROPERTY_USAGE_GROUP and not int(info.usage) & PROPERTY_USAGE_SUBGROUP:
			group = String(info.name)
			groups.append(group)
		elif String(info.name).begins_with("look_paint_"):
			found += 1
			assert_eq(group, "Painted look (M7)", String(info.name))
	assert_gt(found, 20)
	assert_lt(groups.find("Painted look (M7)"), groups.find("Audio"))


# --- M7 G1: no mark at full health, the drawn line, the broken rim, no ragged self-shadow ---

func _alpha_of(tex: Texture2D) -> float:
	var image := tex.get_image()
	var most := 0.0
	for y in image.get_height():
		for x in image.get_width():
			most = maxf(most, image.get_pixel(x, y).a)
	return most


func test_a_painted_character_at_full_health_shows_no_damage_mark_and_a_hurt_one_does() -> void:
	# The grey and purple patches seen on full-health Punks were the key's shadow map shading the figure (the next test), not the damage
	# look: marks are pinned here. All three damage tiles of a fresh painted material, and of one set to CLEAN, are fully transparent.
	var material := ToonMaterials.art_for(_base.trailer_art())
	for name: StringName in [&"damage_tex", &"damage_skin_tex", &"damage_scuff_tex"]:
		var tex := material.get_shader_parameter(name) as Texture2D
		assert_not_null(tex, "%s is set from the start" % name)
		assert_eq(_alpha_of(tex), 0.0, "%s draws nothing on a fresh figure" % name)
	assert_true(material.get_shader_parameter(&"blood_edge") in [null, 0.0], "no blood edge cut either")
	var rig := _rig(_base)
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	var worn := rig.art_meshes()[0].material_override as ShaderMaterial
	rig.set_damage_look(DamageLook.Level.CLEAN)
	for name: StringName in [&"damage_tex", &"damage_skin_tex", &"damage_scuff_tex"]:
		assert_eq(_alpha_of(worn.get_shader_parameter(name) as Texture2D), 0.0, "%s clean on the worn painted material" % name)
	# Hurt: the marks are the M6 tiles, with alpha to show.
	rig.set_damage_look(DamageLook.Level.BLOODIED)
	assert_gt(_alpha_of(worn.get_shader_parameter(&"damage_tex") as Texture2D), 0.0, "blood on the clothes")
	assert_gt(_alpha_of(worn.get_shader_parameter(&"damage_skin_tex") as Texture2D), 0.0, "and on the skin")
	rig.set_damage_look(DamageLook.Level.CLEAN)
	assert_eq(_alpha_of(worn.get_shader_parameter(&"damage_skin_tex") as Texture2D), 0.0, "healed back to nothing")


func test_a_painted_figure_takes_no_shadow_map_from_the_key_by_default() -> void:
	# The shadow map's self-shadow (between the legs, under the cap's brim) is ragged and reads as a translucent blotch; the paint has its own
	# designed shadows. The share is a tunable at 0, and the shader mixes ATTENUATION in by it for a directional light only.
	assert_eq(Tuning.data.look_paint_cast_shadow, 0.0)
	var material := ToonMaterials.art_for(_base.trailer_art())
	assert_eq(material.get_shader_parameter(&"paint_cast_shadow"), 0.0)
	Tuning.set_value(&"look_paint_cast_shadow", 1.0)
	assert_eq(material.get_shader_parameter(&"paint_cast_shadow"), 1.0, "live, and 1 gives the shadow map back")
	var code := (load(PAINTED_SHADER_PATH) as Shader).code
	assert_true(code.contains("LIGHT_IS_DIRECTIONAL ? mix(1.0, ATTENUATION, paint_cast_shadow) : ATTENUATION"), "only a directional light's map is mixed")


func test_the_drawn_line_tunables_reach_the_painted_material_and_its_hull() -> void:
	var data := Tuning.data
	var material := ToonMaterials.art_for(_base.trailer_art())
	var hull := ToonMaterials.outline_painted(_base.trailer_art().get_meta(ToonMaterials.INK_META) as Texture2D)
	var wanted := {
		&"line_vary": data.look_paint_line_vary, &"line_vary_cells": data.look_paint_line_vary_cells,
		&"line_shadow": data.look_paint_line_shadow, &"line_wobble_texels": data.look_paint_line_wobble_texels,
		&"line_gap": data.look_paint_line_gap, &"line_gap_cells": data.look_paint_line_gap_cells,
		&"paint_wobble_hz": data.look_paint_wobble_hz, &"paint_rim_patch_cells": data.look_paint_rim_patch_cells,
		&"paint_rim_patch_cut": data.look_paint_rim_patch_cut,
	}
	for name: StringName in wanted:
		assert_eq(material.get_shader_parameter(name), wanted[name], "the paint's %s" % name)
	var hull_wanted := {
		&"hull_vary": data.look_paint_hull_vary, &"hull_vary_cells": data.look_paint_hull_vary_cells,
		&"hull_shadow": data.look_paint_hull_shadow, &"hull_wobble_px": data.look_paint_hull_wobble_px,
		&"hull_wobble_cells": data.look_paint_hull_wobble_cells, &"hull_gap": data.look_paint_hull_gap,
		&"hull_gap_cells": data.look_paint_hull_gap_cells, &"paint_wobble_hz": data.look_paint_wobble_hz,
	}
	for name: StringName in hull_wanted:
		assert_eq(hull.get_shader_parameter(name), hull_wanted[name], "the hull's %s" % name)
	Tuning.set_value(&"look_paint_hull_gap", 0.2)
	assert_eq(hull.get_shader_parameter(&"hull_gap"), 0.2, "live")
	# The wobble holds on twos: 12 steps a second is a new shape every other frame of a 24 fps cadence.
	assert_eq(data.look_paint_wobble_hz, 12.0)


func test_the_drawn_line_is_built_in_object_space_and_steps_on_the_beat() -> void:
	# No per-frame shimmer: the wobble is a noise of the rest pose seeded by floor(TIME * hz), and no TIME reaches it otherwise.
	for path: String in [PAINTED_SHADER_PATH, PAINTED_HULL_PATH]:
		var code := (load(path) as Shader).code
		assert_true(code.contains("floor(TIME * paint_wobble_hz)"), "%s steps on the beat" % path)
	var hull := (load(PAINTED_HULL_PATH) as Shader).code
	assert_true(hull.contains("CUSTOM0"), "the hull's noise is in the rest pose, so it sticks to the body")
	assert_true(hull.contains("discard"), "and it breaks on the lit side")


func test_the_clean_cel_defaults_draw_no_grain_wobble_breaks_or_rim_patches() -> void:
	# M7 C1: the trailer figure is flat fills, one clean line and a thin rim; the noise tunables stay, at zero.
	var d := Tuning.defaults()
	for key: StringName in [&"look_paint_grain", &"look_paint_line_vary", &"look_paint_line_wobble_texels", &"look_paint_line_gap",
			&"look_paint_hull_vary", &"look_paint_hull_wobble_px", &"look_paint_hull_gap", &"look_paint_rim_patch_cut",
			&"look_finish_grain", &"look_finish_wobble_px", &"look_finish_line_break"]:
		assert_eq(d.get(key), 0.0, "%s defaults to none" % key)
	assert_eq(d.get(&"look_finish_scale"), 1.0, "the 3D view renders at full scale")
	assert_gt(d.get(&"look_paint_hull_shadow"), 0.0, "the hull still swells on the shadow side")


# --- M7 D1: flat bruises under the ink, no figure shadow-map shadow ---

func test_the_damage_mark_tunables_reach_the_painted_material_live() -> void:
	var data := Tuning.data
	var material := ToonMaterials.art_for(_base.trailer_art())
	var wanted := {
		&"bruise_density": data.look_paint_bruise_density, &"bruise_cut": data.look_paint_bruise_cut,
		&"bruise_keep": data.look_paint_bruise_keep, &"bruise_cells": data.look_paint_bruise_cells,
		&"bruise_darken": data.look_paint_bruise_darken, &"bruise_hue": data.look_paint_bruise_hue,
		&"bruise_hue_amount": data.look_paint_bruise_hue_amount, &"blood_color": data.look_paint_blood_color,
	}
	for name: StringName in wanted:
		assert_eq(material.get_shader_parameter(name), wanted[name], "the paint's %s" % name)
	Tuning.set_value(&"look_paint_bruise_keep", 0.2)
	assert_eq(material.get_shader_parameter(&"bruise_keep"), 0.2, "live")
	# A hard-edged flat shape: the cut is high, and the maroon is muted (no channel far above the others, never a saturated violet).
	assert_gte(data.look_paint_bruise_cut, 0.5)
	var hue := data.look_paint_bruise_hue
	assert_gt(hue.r, hue.b, "maroon, not violet")
	assert_lt(hue.s, 0.65, "muted")


func test_the_marks_are_drawn_under_the_ink_and_never_wash_or_land_on_cloth() -> void:
	var code := (load(PAINTED_SHADER_PATH) as Shader).code
	var marks_at := code.find("color = mix(color, mix(bruise, blood_color, bloody)")
	var ink_at := code.find("color = mix(color, ink, line);")
	assert_gt(marks_at, 0, "the flat bruise colour is written")
	assert_gt(ink_at, marks_at, "after the marks: the ink line lies over them")
	assert_true(code.contains("smoothstep(bruise_cut - mark_edge, bruise_cut + mark_edge, shape)"), "the shape is cut hard, never a translucent wash")
	assert_true(code.contains("mix(1.0, bloody, 1.0 - skin_marks)"), "cloth takes the blood's spots only, no bruise")
	assert_true(code.contains("no_blood < 0.5"), "the cap and the laces take nothing")
	assert_false(code.contains("color = mix(color, d.rgb, d.a * takes_marks)"), "the M6 soft tile mix is gone from the painted shader")


func test_the_trailer_profile_art_casts_no_shadow_map_shadow_and_m6_still_does() -> void:
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	var rig := _rig(_base)
	assert_true(rig.has_art())
	for mesh_instance: MeshInstance3D in rig.art_meshes():
		assert_eq(mesh_instance.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "trailer: no map shadow from %s" % mesh_instance.name)
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	for mesh_instance: MeshInstance3D in rig.art_meshes():
		assert_eq(mesh_instance.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "m6 keeps its shadow on %s" % mesh_instance.name)
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	for mesh_instance: MeshInstance3D in rig.art_meshes():
		assert_eq(mesh_instance.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "and off again on the flip back")
