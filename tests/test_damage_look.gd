extends GutTest
## The damage looks' material tests (game/fx/damage_look.gd, Milestone 2 WP2; Spec §6 "Damage
## you can see"): a look changes the damage texture and the tile size and never the shader
## variant, the whole-body flash covers it, and the bruises hold no red. Moved here from
## tests/test_vfx.gd by Milestone 4's contract scaffold, verbatim, so the toon work
## (P1-toon) owns the file that pins the materials; the VFX tests (P1-fx) stay in test_vfx.gd.
## The director's health-driven looks (VfxDirector) are tested there too.
##
## P1-toon retyped the materials: the rig's are ShaderMaterials of the one toon shader, a look is
## its `damage_tex` and `damage_scale` uniforms, `marks` says which paints take it, and the
## flash is `flash_color` times `flash_amount`. Where an assertion read a StandardMaterial3D
## property it reads the uniform that replaced it, noted at each (docs/milestones/M4-calls/
## P1-toon.md has the old -> new list).

const TOON_PATHS: Array[String] = ["res://game/fx/toon.gdshader", "res://game/fx/toon_light.gdshaderinc"]


## The material's `damage_tex` uniform (was detail_albedo).
func _damage_tex(mat: ShaderMaterial) -> Variant:
	return mat.get_shader_parameter(&"damage_tex")


## True if the paint's material takes marks (was detail_enabled, which the dark paint left off).
func _takes_marks(mat: ShaderMaterial) -> bool:
	return float(mat.get_shader_parameter(&"marks")) > 0.5


func test_rig_damage_look_changes_materials_only() -> void:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	add_child_autofree(rig)
	rig.build()
	var meshes := rig.find_children("*", "MeshInstance3D", true, false).size()
	var fist := rig.get_point_transform(&"RightFistPoint")
	var mats: Dictionary[int, ShaderMaterial] = rig.get(&"_materials")
	rig.set_damage_look(DamageLook.Level.BRUISED)
	assert_eq(rig.damage_look, DamageLook.Level.BRUISED)
	assert_true(_takes_marks(mats[PlaceholderBody.Paint.SKIN]), "bruised skin")
	assert_eq(_damage_tex(mats[PlaceholderBody.Paint.SKIN]), VfxArt.texture(&"damage_bruised"))
	# Was uv1_triplanar: the shader maps the texture triplanar (three taps blended by the normal).
	assert_string_contains(FileAccess.get_file_as_string(TOON_PATHS[0]), "texture(damage_tex, p.zy) * w.x + texture(damage_tex, p.xz) * w.y + texture(damage_tex, p.xy) * w.z")
	for paint: int in [PlaceholderBody.Paint.BODY, PlaceholderBody.Paint.PANTS, PlaceholderBody.Paint.ACCENT]:
		assert_eq(_damage_tex(mats[paint]), VfxArt.texture(&"damage_scuffed"), "scuffed clothes: paint %d" % paint)
	assert_false(_takes_marks(mats[PlaceholderBody.Paint.DARK]), "shades and soles stay")
	assert_eq(_damage_tex(mats[PlaceholderBody.Paint.DARK]), VfxArt.clear_detail(), "and show nothing")
	rig.set_damage_look(DamageLook.Level.BLOODIED)
	assert_eq(_damage_tex(mats[PlaceholderBody.Paint.SKIN]), VfxArt.texture(&"damage_bloodied"))
	for paint: int in [PlaceholderBody.Paint.BODY, PlaceholderBody.Paint.PANTS, PlaceholderBody.Paint.ACCENT]:
		assert_eq(_damage_tex(mats[paint]), VfxArt.texture(&"damage_blood"), "blood on paint %d" % paint)
	assert_false(_takes_marks(mats[PlaceholderBody.Paint.DARK]), "shades and soles stay")
	rig.set_damage_look(DamageLook.Level.CLEAN)
	for paint: int in mats:
		if DamageLook.bruisable(paint):
			assert_eq(_damage_tex(mats[paint]), VfxArt.clear_detail(), "clean again: nothing shows on paint %d" % paint)
		else:
			assert_false(_takes_marks(mats[paint]), "still no marks: paint %d" % paint)
	assert_eq(rig.find_children("*", "MeshInstance3D", true, false).size(), meshes, "no meshes added")
	assert_eq(rig.get_point_transform(&"RightFistPoint"), fist, "pose untouched")


## The uniforms the toon shader declares (its own file and the lighting include): name -> value
## on `mat`, but the two a damage look changes (the damage texture and its tile scale). Equal
## dictionaries mean the same shader and the same everything else. (A ShaderMaterial headless
## lists no parameters, so the names come from the shader source.)
func _variant_props(mat: ShaderMaterial) -> Dictionary:
	var out := {"shader": mat.shader}
	var declared := RegEx.create_from_string("(?m)^uniform\\s+\\w+\\s+(\\w+)")
	for path: String in TOON_PATHS:
		for found in declared.search_all(FileAccess.get_file_as_string(path)):
			var key := found.get_string(1)
			if key != "damage_tex" and key != "damage_scale":
				out[key] = mat.get_shader_parameter(key)
	return out


## perf-02: the damage texture slot is filled from the build (a transparent texture while clean),
## so a look change swaps the texture only and never the shader variant (on the StandardMaterial3D
## this replaced, switching the detail layer on recompiled it on the first bruise of every clean
## cast: 3-5 ms and a pipeline compile). Now: the shader and every uniform but `damage_tex` and
## `damage_scale` are unchanged by a look. (Was: every stored property but detail_albedo and
## uv1_scale.)
func test_damage_look_never_switches_the_shader_variant() -> void:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	add_child_autofree(rig)
	rig.build()
	var mats: Dictionary[int, ShaderMaterial] = rig.get(&"_materials")
	var variants := {}
	for paint: int in mats:
		variants[paint] = _variant_props(mats[paint])
		assert_eq(mats[paint].shader, ToonMaterials.TOON_SHADER, "the one toon shader: paint %d" % paint)
	for paint: int in [PlaceholderBody.Paint.SKIN, PlaceholderBody.Paint.BODY, PlaceholderBody.Paint.PANTS,
			PlaceholderBody.Paint.ACCENT]:
		var mat := mats[paint]
		assert_true(_takes_marks(mat), "marks on from the build: paint %d" % paint)
		assert_eq(_damage_tex(mat), VfxArt.clear_detail(), "clean shows nothing: paint %d" % paint)
		assert_false(bool(mat.get_shader_parameter(&"use_rest_custom")), "a primitive maps in its own space")
	assert_false(_takes_marks(mats[PlaceholderBody.Paint.DARK]), "the dark paint takes no marks")
	for level: int in [DamageLook.Level.BRUISED, DamageLook.Level.BLOODIED, DamageLook.Level.CLEAN,
			DamageLook.Level.BRUISED, DamageLook.Level.CLEAN]:
		rig.set_damage_look(level)
		for paint: int in mats:
			assert_eq(_variant_props(mats[paint]), variants[paint], "level %d keeps paint %d's variant" % [level, paint])
	# The same textures as before (the look picks them by paint and level).
	assert_null(DamageLook.texture_for(PlaceholderBody.Paint.SKIN, DamageLook.Level.CLEAN))
	assert_eq(DamageLook.texture_for(PlaceholderBody.Paint.SKIN, DamageLook.Level.BRUISED), VfxArt.texture(&"damage_bruised"))
	assert_eq(DamageLook.texture_for(PlaceholderBody.Paint.SKIN, DamageLook.Level.BLOODIED), VfxArt.texture(&"damage_bloodied"))
	assert_eq(DamageLook.texture_for(PlaceholderBody.Paint.PANTS, DamageLook.Level.BRUISED), VfxArt.texture(&"damage_scuffed"))
	assert_eq(DamageLook.texture_for(PlaceholderBody.Paint.ACCENT, DamageLook.Level.BLOODIED), VfxArt.texture(&"damage_blood"))
	assert_null(DamageLook.texture_for(PlaceholderBody.Paint.DARK, DamageLook.Level.BLOODIED))


## The "nothing" texture shows nothing: fully transparent, one pixel, held for the run.
func test_clean_detail_texture_is_clear_and_held() -> void:
	var tex := VfxArt.clear_detail()
	assert_eq(tex, VfxArt.clear_detail(), "one texture for the run")
	var image := tex.get_image()
	assert_eq(image.get_size(), Vector2i(1, 1))
	assert_eq(image.get_pixel(0, 0).a, 0.0, "mixes in nothing")


## The tile size is the one thing besides the texture a look re-reads (Tuning.vfx_damage_tile_m).
func test_damage_look_rereads_the_tile_size() -> void:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	add_child_autofree(rig)
	rig.build()
	var skin: ShaderMaterial = (rig.get(&"_materials") as Dictionary[int, ShaderMaterial])[PlaceholderBody.Paint.SKIN]
	# Was uv1_scale = Vector3.ONE / tile: the shader's damage_scale is the tiles per metre.
	assert_almost_eq(float(skin.get_shader_parameter(&"damage_scale")), 1.0 / Tuning.data.vfx_damage_tile_m, 1e-5, "from the build")
	Tuning.data.vfx_damage_tile_m = 0.5
	rig.set_damage_look(DamageLook.Level.BRUISED)
	assert_almost_eq(float(skin.get_shader_parameter(&"damage_scale")), 1.0 / 0.5, 1e-5)
	rig.set_damage_look(DamageLook.Level.CLEAN)
	assert_almost_eq(float(skin.get_shader_parameter(&"damage_scale")), 1.0 / 0.5, 1e-5)
	assert_eq(_damage_tex(skin), VfxArt.clear_detail())


## The whole-body flash (set_flash(), the parry's) is the flash color times share added over the
## lit, marked albedo (the toon shader's EMISSION; it was the material's emission); the hit flash
## is the contact overlay instead (test_hit_flash.gd checks it keeps the marks). Here: every
## marked material flashes whole-body, and keeps its marks.
func test_whole_body_flash_still_covers_the_damage_look() -> void:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	add_child_autofree(rig)
	rig.build()
	rig.set_damage_look(DamageLook.Level.BLOODIED)
	rig.set_flash(1.0)
	var mats: Dictionary[int, ShaderMaterial] = rig.get(&"_materials")
	for paint: int in mats:
		assert_eq(mats[paint].get_shader_parameter(&"flash_color"), Color.WHITE)
		assert_eq(mats[paint].get_shader_parameter(&"flash_amount"), 1.0, "paint %d flashes" % paint)
	assert_true(_takes_marks(mats[PlaceholderBody.Paint.SKIN]), "the marks stay under the flash")
	assert_eq(_damage_tex(mats[PlaceholderBody.Paint.SKIN]), VfxArt.texture(&"damage_bloodied"), "still the bloodied tile")
	rig.set_flash(0.0)
	assert_eq(mats[PlaceholderBody.Paint.SKIN].get_shader_parameter(&"flash_amount"), 0.0)
	assert_eq(_damage_tex(mats[PlaceholderBody.Paint.SKIN]), VfxArt.texture(&"damage_bloodied"), "and show again")


func test_bruises_are_not_red_paint() -> void:
	# Spec §10: red is for blood, the rear warning and finisher accents. The bruised look's
	# textures hold no blood-red pixels; the bloodied ones do.
	for name: StringName in [&"damage_bruised", &"damage_scuffed"]:
		assert_eq(_red_share(name), 0.0, "%s has no red" % name)
	for name: StringName in [&"damage_bloodied", &"damage_blood"]:
		assert_gt(_red_share(name), 0.02, "%s has blood" % name)


## Share of the visible pixels of FX texture `name` that are saturated red.
func _red_share(name: StringName) -> float:
	var image := VfxArt.texture(name).get_image()
	image.decompress()
	var seen := 0
	var red := 0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var c := image.get_pixel(x, y)
			if c.a < 0.3:
				continue
			seen += 1
			if c.r > 0.55 and c.r > c.g * 2.5 and c.r > c.b * 2.5:
				red += 1
	return float(red) / maxf(seen, 1.0)
