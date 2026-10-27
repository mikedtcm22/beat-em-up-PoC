extends GutTest
## The damage looks' material tests (game/fx/damage_look.gd, Milestone 2 WP2; Spec §6 "Damage
## you can see"): a look changes the detail texture and the tile size and never the shader
## variant, the whole-body flash covers it, and the bruises hold no red. Moved here from
## tests/test_vfx.gd by Milestone 4's contract scaffold, verbatim, so the toon work
## (P1-toon) owns the file that pins the materials; the VFX tests (P1-fx) stay in test_vfx.gd.
## The director's health-driven looks (VfxDirector) are tested there too.


func test_rig_damage_look_changes_materials_only() -> void:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	add_child_autofree(rig)
	rig.build()
	var meshes := rig.find_children("*", "MeshInstance3D", true, false).size()
	var fist := rig.get_point_transform(&"RightFistPoint")
	var mats: Dictionary[int, StandardMaterial3D] = rig.get(&"_materials")
	rig.set_damage_look(DamageLook.Level.BRUISED)
	assert_eq(rig.damage_look, DamageLook.Level.BRUISED)
	assert_true(mats[PlaceholderBody.Paint.SKIN].detail_enabled, "bruised skin")
	assert_eq(mats[PlaceholderBody.Paint.SKIN].detail_albedo, VfxArt.texture(&"damage_bruised"))
	assert_true(mats[PlaceholderBody.Paint.SKIN].uv1_triplanar, "mapped triplanar")
	for paint: int in [PlaceholderBody.Paint.BODY, PlaceholderBody.Paint.PANTS, PlaceholderBody.Paint.ACCENT]:
		assert_eq(mats[paint].detail_albedo, VfxArt.texture(&"damage_scuffed"), "scuffed clothes: paint %d" % paint)
	assert_false(mats[PlaceholderBody.Paint.DARK].detail_enabled, "shades and soles stay")
	rig.set_damage_look(DamageLook.Level.BLOODIED)
	assert_eq(mats[PlaceholderBody.Paint.SKIN].detail_albedo, VfxArt.texture(&"damage_bloodied"))
	for paint: int in [PlaceholderBody.Paint.BODY, PlaceholderBody.Paint.PANTS, PlaceholderBody.Paint.ACCENT]:
		assert_eq(mats[paint].detail_albedo, VfxArt.texture(&"damage_blood"), "blood on paint %d" % paint)
	assert_false(mats[PlaceholderBody.Paint.DARK].detail_enabled, "shades and soles stay")
	rig.set_damage_look(DamageLook.Level.CLEAN)
	for paint: int in mats:
		if DamageLook.bruisable(paint):
			assert_eq(mats[paint].detail_albedo, VfxArt.clear_detail(), "clean again: nothing shows on paint %d" % paint)
		else:
			assert_false(mats[paint].detail_enabled, "still no detail layer: paint %d" % paint)
	assert_eq(rig.find_children("*", "MeshInstance3D", true, false).size(), meshes, "no meshes added")
	assert_eq(rig.get_point_transform(&"RightFistPoint"), fist, "pose untouched")


## Every stored property of `mat` but the two a damage look changes (the detail texture and
## its tile size): together they pick the material's shader variant, so equal dictionaries
## mean the same shader.
func _variant_props(mat: StandardMaterial3D) -> Dictionary:
	var out := {}
	for info: Dictionary in mat.get_property_list():
		var key: String = info.name
		if (info.usage as int) & PROPERTY_USAGE_STORAGE != 0 and key != "detail_albedo" and key != "uv1_scale":
			out[key] = mat.get(key)
	return out


## perf-02: the detail layer is on from the build (a transparent texture while clean), so a
## look change swaps the texture only and never the shader variant (a switch recompiled it
## on the first bruise of every clean cast: 3-5 ms and a pipeline compile).
func test_damage_look_never_switches_the_shader_variant() -> void:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	add_child_autofree(rig)
	rig.build()
	var mats: Dictionary[int, StandardMaterial3D] = rig.get(&"_materials")
	var variants := {}
	for paint: int in mats:
		variants[paint] = _variant_props(mats[paint])
	for paint: int in [PlaceholderBody.Paint.SKIN, PlaceholderBody.Paint.BODY, PlaceholderBody.Paint.PANTS,
			PlaceholderBody.Paint.ACCENT]:
		var mat := mats[paint]
		assert_true(mat.detail_enabled, "detail layer on from the build: paint %d" % paint)
		assert_true(mat.uv1_triplanar, "triplanar from the build: paint %d" % paint)
		assert_eq(mat.detail_blend_mode, BaseMaterial3D.BLEND_MODE_MIX)
		assert_eq(mat.detail_uv_layer, BaseMaterial3D.DETAIL_UV_1)
		assert_eq(mat.detail_albedo, VfxArt.clear_detail(), "clean shows nothing: paint %d" % paint)
	assert_false(mats[PlaceholderBody.Paint.DARK].detail_enabled, "the dark paint takes no marks")
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
	var skin: StandardMaterial3D = (rig.get(&"_materials") as Dictionary[int, StandardMaterial3D])[PlaceholderBody.Paint.SKIN]
	assert_eq(skin.uv1_scale, Vector3.ONE / Tuning.data.vfx_damage_tile_m, "from the build")
	Tuning.data.vfx_damage_tile_m = 0.5
	rig.set_damage_look(DamageLook.Level.BRUISED)
	assert_eq(skin.uv1_scale, Vector3.ONE / 0.5)
	rig.set_damage_look(DamageLook.Level.CLEAN)
	assert_eq(skin.uv1_scale, Vector3.ONE / 0.5)
	assert_eq(skin.detail_albedo, VfxArt.clear_detail())


## The whole-body flash (set_flash(), the parry's) is emission added over the lit, marked
## albedo; the hit flash is the contact overlay instead (test_hit_flash.gd checks it keeps
## the marks). Here: every marked material flashes whole-body, and keeps its marks.
func test_whole_body_flash_still_covers_the_damage_look() -> void:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	add_child_autofree(rig)
	rig.build()
	rig.set_damage_look(DamageLook.Level.BLOODIED)
	rig.set_flash(1.0)
	var mats: Dictionary[int, StandardMaterial3D] = rig.get(&"_materials")
	for paint: int in mats:
		assert_true(mats[paint].emission_enabled, "paint %d can flash" % paint)
		assert_eq(mats[paint].emission, Color.WHITE)
		assert_eq(mats[paint].emission_energy_multiplier, 1.0, "paint %d flashes" % paint)
	assert_true(mats[PlaceholderBody.Paint.SKIN].detail_enabled, "the marks stay under the flash")
	rig.set_flash(0.0)
	assert_eq(mats[PlaceholderBody.Paint.SKIN].emission_energy_multiplier, 0.0)
	assert_eq(mats[PlaceholderBody.Paint.SKIN].detail_albedo, VfxArt.texture(&"damage_bloodied"), "and show again")


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
