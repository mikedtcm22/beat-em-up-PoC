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
## Tuning is an autoload that outlives the script: the tests below set tile size, edge cut and the per-swatch switch, so each
## starts from and leaves the shipped defaults (as test_toon.gd does).
func before_each() -> void:
	Tuning.apply(TuningData.new())


func after_each() -> void:
	Tuning.apply(TuningData.new())


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
	assert_string_contains(FileAccess.get_file_as_string(TOON_PATHS[0]), "textureGrad(tex, p.zy, dpdx.zy, dpdy.zy) * w.x + textureGrad(tex, p.xz, dpdx.xz, dpdy.xz) * w.y")
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
			if not ["damage_tex", "damage_scale", "damage_scuff_tex", "blood_edge"].has(key):
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


## The art is one material, but the skin shows the primitives' skin tiles (the bruises, then the blood) and the
## clothes show the scuffs, then the blood: the clothes' sequence stays in `damage_tex` (test_art_punk A10 reads it),
## the skin's is `damage_skin_tex`, which the shader picks by the swatch's alpha class (slice-g2-07).
func test_the_art_shows_the_skin_tiles_on_the_skin_and_the_clothes_tiles_on_the_clothes() -> void:
	var art := ToonMaterials.art(load("res://assets/export/palette/palette_atlas.png") as Texture2D)
	assert_null(art.get_shader_parameter(&"damage_skin_tex"), "unset: the shader's own default, transparent (hint_default_transparent)")
	var clear := VfxArt.clear_detail()
	DamageLook.apply_art(art, DamageLook.Level.CLEAN)
	assert_eq(art.get_shader_parameter(&"damage_tex"), clear, "clean clothes")
	assert_eq(art.get_shader_parameter(&"damage_skin_tex"), clear, "clean skin")
	DamageLook.apply_art(art, DamageLook.Level.BRUISED)
	assert_eq(art.get_shader_parameter(&"damage_tex"), VfxArt.texture(&"damage_scuffed"), "bruised: the clothes scuff")
	assert_eq(art.get_shader_parameter(&"damage_skin_tex"), VfxArt.texture(&"damage_bruised"), "bruised: the skin takes the bruises M3's skin paint wore")
	DamageLook.apply_art(art, DamageLook.Level.BLOODIED)
	assert_eq(art.get_shader_parameter(&"damage_tex"), VfxArt.texture(&"damage_blood"), "bloodied: the clothes' blood")
	assert_eq(art.get_shader_parameter(&"damage_skin_tex"), VfxArt.texture(&"damage_bloodied"), "bloodied: the skin's blood")
	for level: int in [DamageLook.Level.BRUISED, DamageLook.Level.BLOODIED]:
		DamageLook.apply_art(art, level)
		assert_eq(art.get_shader_parameter(&"damage_skin_tex"), DamageLook.texture_for(PlaceholderBody.Paint.SKIN, level), "the skin tile is the skin paint's at level %d" % level)
		assert_eq(art.get_shader_parameter(&"damage_tex"), DamageLook.texture_for(PlaceholderBody.Paint.BODY, level), "the clothes tile is the body paint's at level %d" % level)
	DamageLook.apply_art(art, DamageLook.Level.CLEAN)
	assert_eq(art.get_shader_parameter(&"damage_skin_tex"), clear, "clean again")
	assert_eq(art.shader, ToonMaterials.TOON_SHADER, "a look swaps textures only")
	# the primitives are prepared with both slots clear, so no material ever shows the shader's default by accident
	for paint: int in [PlaceholderBody.Paint.SKIN, PlaceholderBody.Paint.BODY, PlaceholderBody.Paint.PANTS, PlaceholderBody.Paint.ACCENT]:
		var mat := ToonMaterials.character(Color.WHITE, true)
		DamageLook.prepare(mat, paint)
		assert_eq(mat.get_shader_parameter(&"damage_tex"), clear, "prepared clear: paint %d" % paint)
		assert_eq(mat.get_shader_parameter(&"damage_skin_tex"), clear, "prepared clear, skin slot: paint %d" % paint)


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


# --- Marks per swatch (M6 D6) -------------------------------------------------------------------


func _atlas_alpha(slot: int) -> float:
	var image := (load("res://assets/export/palette/palette_atlas.png") as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	return image.get_pixel((slot % 32) * 8 + 4, (slot / 32) * 8 + 4).a


## The Punk's cap, laces and strap (slot 17) say "blood": false: at the bloodied look the art shows them the scuffs, never the blood
## tile, while the vest, the jeans and the skin still show their blood (the shader's choice, mirrored by DamageLook.art_tile_for_alpha(),
## whose thresholds the shader source pins below).
func test_blood_never_lands_on_a_blood_false_swatch() -> void:
	var swatches := _palette_swatches()
	var no_blood := 0
	for sw: Dictionary in swatches:
		var alpha := _atlas_alpha(sw.slot)
		var tile := DamageLook.art_tile_for_alpha(alpha, DamageLook.Level.BLOODIED)
		if not sw.marks:
			assert_null(tile, "%s takes no marks" % sw.name)
		elif sw.skin:
			assert_eq(tile, VfxArt.texture(&"damage_bloodied"), "%s: the skin's blood" % sw.name)
		elif sw.blood:
			assert_eq(tile, VfxArt.texture(&"damage_blood"), "%s takes the blood" % sw.name)
		else:
			no_blood += 1
			assert_eq(tile, VfxArt.texture(&"damage_scuffed"), "%s takes the scuffs and never the blood" % sw.name)
			assert_eq(_red_share(&"damage_scuffed"), 0.0, "and the tile it shows has no red")
			assert_eq(DamageLook.art_tile_for_alpha(alpha, DamageLook.Level.BRUISED), VfxArt.texture(&"damage_scuffed"), "scuffed when bruised")
			assert_null(DamageLook.art_tile_for_alpha(alpha, DamageLook.Level.CLEAN), "and clean when clean")
	assert_gte(no_blood, 1, "the Punk's cap swatch is one")
	# The Punk's slot 17 is the one (D6: no Punk rebuild, the cap, laces and strap share it).
	assert_between(_atlas_alpha(17), 0.85, 0.95, "slot 17 is the no-blood class")
	assert_gte(_atlas_alpha(16), 0.95, "the vest takes the blood")
	var shader := FileAccess.get_file_as_string(TOON_PATHS[0])
	assert_string_contains(shader, "no_blood = step(0.85, swatch.a) * (1.0 - step(0.95, swatch.a));")
	assert_string_contains(shader, "d = damage_triplanar(damage_scuff_tex, p, w, dpdx, dpdy);")
	assert_string_contains(shader, "if (blood_edge > 0.0 && no_blood < 0.5) {", "the cut is for the blood, not the scuffs a cap shows")


func _palette_swatches() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open("res://assets/source/palette")
	for file: String in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var pal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/palette/%s" % file))
		for sw: Dictionary in pal.swatches:
			out.append({slot = int(sw.slot), name = String(sw.name), marks = bool(sw.get("marks", true)),
					skin = bool(sw.get("skin", false)), blood = bool(sw.get("blood", true))})
	return out


func test_the_art_look_has_a_hard_blood_edge_and_the_a_b_switch_gives_m4s_back() -> void:
	var art := ToonMaterials.art(load("res://assets/export/palette/palette_atlas.png") as Texture2D)
	assert_eq(art.get_shader_parameter(&"blood_edge"), null, "unset: the shader's default, 0 = off")
	for level: int in [DamageLook.Level.CLEAN, DamageLook.Level.BRUISED]:
		DamageLook.apply_art(art, level)
		assert_eq(art.get_shader_parameter(&"blood_edge"), 0.0, "no cut before the blood (level %d)" % level)
	DamageLook.apply_art(art, DamageLook.Level.BLOODIED)
	assert_eq(art.get_shader_parameter(&"blood_edge"), Tuning.data.vfx_blood_edge_cut, "bloodied: the blood's alpha is cut at the tunable")
	assert_gt(Tuning.data.vfx_blood_edge_cut, 0.0)
	assert_eq(art.get_shader_parameter(&"damage_scuff_tex"), VfxArt.texture(&"damage_scuffed"), "the cap's scuffs")
	Tuning.data.vfx_blood_edge_cut = 0.7
	DamageLook.apply_art(art, DamageLook.Level.BLOODIED)
	assert_eq(art.get_shader_parameter(&"blood_edge"), 0.7, "the tunable is live")
	# The switch: off, the cap takes the blood tile and the blood is M4's soft blend.
	Tuning.data.look_marks_per_swatch = false
	DamageLook.apply_art(art, DamageLook.Level.BLOODIED)
	assert_eq(art.get_shader_parameter(&"blood_edge"), 0.0, "no cut")
	assert_eq(art.get_shader_parameter(&"damage_scuff_tex"), VfxArt.texture(&"damage_blood"), "and the cap bloodies as it did in M4")
	assert_eq(DamageLook.art_tile_for_alpha(230.0 / 255.0, DamageLook.Level.BLOODIED), VfxArt.texture(&"damage_blood"))
	for property: StringName in [&"vfx_blood_edge_cut", &"look_marks_per_swatch"]:
		assert_has(DamageLook.TUNABLES, property, "a change re-applies the look on the live enemies")


## Declared last on purpose: the per-swatch test before it sets look_marks_per_swatch false, vfx_blood_edge_cut 0.7 and the
## tile 0.5 m, and none of that may reach a later script.
func test_a_test_that_changed_the_tuning_leaves_the_shipped_defaults_behind() -> void:
	var defaults := TuningData.new()
	assert_eq(Tuning.data.look_marks_per_swatch, defaults.look_marks_per_swatch)
	assert_true(Tuning.data.look_marks_per_swatch, "M6's per-swatch look is the default")
	assert_eq(Tuning.data.vfx_blood_edge_cut, defaults.vfx_blood_edge_cut)
	assert_eq(Tuning.data.vfx_damage_tile_m, defaults.vfx_damage_tile_m)
