extends GutTest
## The Milestone 4 contract scaffold (M4-plan Part C §2 as amended by Part A, package
## S0-contract): every seam, signature, tunable and data file the art packages build on, tested
## on its own before any of them lands. With `art == null` nothing here changes the M3 game:
## the rig builds its 41/45 primitives, and the room, the pipe and the tuning panel behave as
## before (P1-toon since made every material the toon shader's and gave the placeholders their
## hulls: see the notes where a test changed). The art itself (SkinnedArt, the toon shader, the
## edge pass) is tested by the packages that build it.

const DUMP := preload("res://tools/pipeline/dump_joints.gd")
const JOINTS_PATH := "res://tools/pipeline/joints.json"
const GRID_SHADER_PATH := "res://game/level/grid.gdshader"
## The meshes PlaceholderBody builds for an enemy and for the player (wrapped hands): the
## 41 and 45 of the M3 rig (codemap rig-render §1.4).
const ENEMY_MESHES := 41
const PLAYER_MESHES := 45


## A fighter that logs when its rig hooks run, and what the rig looked like at the time.
class HookActor:
	extends CombatActor
	var calls: Array[String] = []
	var built_at_art_hook: bool = true
	var art_seen: CharacterArt

	func _configure_rig(_r: HumanoidRig) -> void:
		calls.append("rig")

	func _configure_art(r: HumanoidRig) -> void:
		calls.append("art")
		built_at_art_hook = r.skeleton != null
		super(r)
		art_seen = r.art


func _rig(wrapped: bool = false, art: CharacterArt = null) -> HumanoidRig:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	rig.wrapped_hands = wrapped
	rig.art = art
	add_child_autofree(rig)
	rig.build()
	return rig


func _art(id: StringName = &"probe") -> CharacterArt:
	var art := CharacterArt.new()
	art.id = id
	art.palette = VfxArt.clear_detail()
	art.triangle_budget = 100
	return art


func _meshes(rig: HumanoidRig) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node: Node in rig.find_children("*", "MeshInstance3D", true, false):
		out.append(node as MeshInstance3D)
	return out


# --- Signatures (the contract, §2.1-§2.4 and A6) ----------------------------------------------


## Every method a later package calls, by arity and staticness: the scaffold's promise, kept
## by the stubs and by the implementations that replace them.
func test_the_contract_signatures_exist() -> void:
	var wanted := {
		"res://game/actors/rig_paint.gd": {
			&"build": [0, false], &"material": [1, false], &"art_material": [0, false],
			&"outline_material": [0, false], &"outline_material_for": [1, false], &"apply_colors": [0, false],
			&"color_of": [1, false], &"set_flash": [2, false], &"show_flash_overlay": [2, false],
			&"set_damage_look": [1, false], &"base_materials": [0, false], &"warm_up": [1, false],
		},
		"res://game/actors/skinned_art.gd": {&"attach": [2, true], &"check": [1, true]},
		"res://game/fx/toon_materials.gd": {
			# P1-toon: character() and environment() gained optional parameters (takes_marks and
			# glossy; hulled), which the argument count includes (was 1 and 1). P3-int: outline()
			# gained first_person (the player's own body, M4-calls/P3-int.md C1; was 0). Final review:
			# art() gained sharp_detail (the hero's cut ink, M4-calls/fix-final-toon-light-and-ink.md C2; was 2).
			&"character": [3, true], &"art": [3, true], &"outline": [1, true], &"prop": [1, true],
			&"outline_for_prop": [0, true], &"environment": [2, true], &"grid": [0, true], &"warm_up": [2, true],
		},
		"res://game/actors/humanoid_rig.gd": {
			&"has_art": [0, false], &"art_meshes": [0, false], &"set_art_shown": [1, false],
		},
		"res://game/actors/combat_actor.gd": {&"_configure_art": [1, false]},
	}
	for path: String in wanted:
		var script := load(path) as GDScript
		assert_not_null(script, "%s loads" % path)
		var found: Dictionary = {}
		for info: Dictionary in script.get_script_method_list():
			found[StringName(info.name)] = info
		for method: StringName in wanted[path]:
			assert_true(found.has(method), "%s has %s()" % [path, method])
			if not found.has(method):
				continue
			var row: Array = wanted[path][method]
			var info: Dictionary = found[method]
			assert_eq((info.args as Array).size(), row[0], "%s.%s: its argument count" % [path, method])
			assert_eq((int(info.flags) & METHOD_FLAG_STATIC) != 0, row[1], "%s.%s: static" % [path, method])


func test_character_art_is_a_resource_with_the_pinned_fields() -> void:
	var art := CharacterArt.new()
	assert_true(art is Resource)
	var fields: Dictionary = {}
	for info: Dictionary in art.get_property_list():
		if int(info.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields[String(info.name)] = int(info.type)
	assert_eq(fields, {
		"id": TYPE_STRING_NAME, "scene": TYPE_OBJECT, "palette": TYPE_OBJECT,
		"detail_mask": TYPE_OBJECT, "triangle_budget": TYPE_INT,
	})
	assert_null(art.scene)
	assert_null(art.palette)
	assert_null(art.detail_mask)


func test_the_rig_and_the_actor_keep_the_art_field_and_the_group_names() -> void:
	assert_eq(HumanoidRig.VIEW_PROXY_GROUP, &"view_proxy")
	assert_eq(HumanoidRig.ART_GROUP, &"rig_art")
	var rig := HumanoidRig.new()
	assert_null(rig.art, "no art by default")
	assert_true(rig.paint is RigPaint, "a rig has its RigPaint from the start, so a color set before build() works")
	rig.free()
	var actor := CombatActor.new()
	assert_null(actor.art, "no art by default")
	actor.free()


# --- A rig without art is today's rig ---------------------------------------------------------


func test_a_rig_without_art_builds_exactly_the_m3_primitives() -> void:
	for wrapped: bool in [false, true]:
		var rig := _rig(wrapped)
		var meshes := _meshes(rig)
		assert_eq(meshes.size(), PLAYER_MESHES if wrapped else ENEMY_MESHES, "wrapped %s: its primitive count" % wrapped)
		assert_eq(meshes.size(), PlaceholderBody.parts(wrapped).size())
		for mesh: MeshInstance3D in meshes:
			assert_true(mesh.visible, "%s drawn" % mesh.name)
			# P1-toon (A7): every placeholder has its hull on material_overlay and the toon
			# shader's material (was: no overlay, a StandardMaterial3D).
			assert_true(mesh.material_overlay is ShaderMaterial, "%s has its hull" % mesh.name)
			assert_eq((mesh.material_overlay as ShaderMaterial).shader, ToonMaterials.OUTLINE_SHADER, "%s: the hull's shader" % mesh.name)
			assert_true(mesh.material_override is ShaderMaterial, "%s: a toon material" % mesh.name)
			assert_eq((mesh.material_override as ShaderMaterial).shader, ToonMaterials.TOON_SHADER, "%s: the toon shader" % mesh.name)
			assert_false(mesh.is_in_group(HumanoidRig.VIEW_PROXY_GROUP), "%s is no proxy" % mesh.name)
			assert_false(mesh.is_in_group(HumanoidRig.ART_GROUP), "%s is no art" % mesh.name)
		assert_false(rig.has_art())
		assert_eq(rig.art_meshes().size(), 0)
		rig.set_art_shown(false)
		rig.set_art_shown(true)
		for mesh: MeshInstance3D in meshes:
			assert_true(mesh.visible, "the A/B leaves a rig without art alone")


func test_a_rig_with_art_builds_the_primitives_as_view_proxies_and_keeps_them_while_nothing_attaches() -> void:
	var rig := _rig(true, _art())
	var meshes := _meshes(rig)
	assert_eq(meshes.size(), PLAYER_MESHES, "every primitive is still built")
	for mesh: MeshInstance3D in meshes:
		assert_true(mesh.is_in_group(HumanoidRig.VIEW_PROXY_GROUP), "%s is a view proxy" % mesh.name)
	# SkinnedArt.attach() is P1-skin's; until it adds meshes the body must not vanish.
	if not rig.has_art():
		for mesh: MeshInstance3D in meshes:
			assert_true(mesh.visible, "%s stays drawn while no art is attached" % mesh.name)


func test_the_art_ab_swaps_the_art_and_the_proxies() -> void:
	var rig := _rig(false, _art())
	var art_mesh := MeshInstance3D.new()
	rig.skeleton.add_child(art_mesh)
	art_mesh.add_to_group(HumanoidRig.ART_GROUP)
	var attached: Array[MeshInstance3D] = [art_mesh]
	rig.set(&"_art_meshes", attached)
	assert_true(rig.has_art())
	assert_eq(rig.art_meshes(), attached)
	rig.set_art_shown(true)
	assert_true(art_mesh.visible)
	for mesh: MeshInstance3D in _meshes(rig):
		if mesh != art_mesh:
			assert_false(mesh.visible, "%s hides while the art shows" % mesh.name)
	rig.set_art_shown(false)
	assert_false(art_mesh.visible)
	for mesh: MeshInstance3D in _meshes(rig):
		if mesh != art_mesh:
			assert_true(mesh.visible, "%s shows for the A/B" % mesh.name)
			assert_true(mesh.is_in_group(HumanoidRig.VIEW_PROXY_GROUP))
	rig.set_shown(false)
	assert_false(rig.visible, "set_shown() hides the whole rig, art and proxies alike")


func test_configure_art_runs_once_per_body_after_configure_rig_and_before_build() -> void:
	var actor := HookActor.new()
	actor.art = _art(&"punk")
	add_child_autofree(actor)
	assert_eq(actor.calls, ["rig", "art"], "once each, the art second")
	assert_false(actor.built_at_art_hook, "before the rig builds its skeleton")
	assert_eq(actor.art_seen, actor.art, "the default hands the actor's art to the rig")
	assert_eq(actor.rig.art, actor.art)
	assert_eq(_meshes(actor.rig).size(), ENEMY_MESHES)
	var bare := HookActor.new()
	add_child_autofree(bare)
	assert_null(bare.rig.art, "no art, no change")
	assert_false(bare.rig.has_art())


# --- RigPaint: the material code moved out of the rig, behaving as before ---------------------


func test_rig_paint_holds_the_rigs_materials_and_colors() -> void:
	var rig := HumanoidRig.new()
	rig.body_color = Color(0.1, 0.2, 0.3)
	assert_eq(rig.paint.materials.size(), 0, "colors set before build() make no materials")
	rig.build_hurtboxes = false
	add_child_autofree(rig)
	rig.build()
	var mats: Dictionary[int, ShaderMaterial] = rig.get(&"_materials")
	assert_true(is_same(mats, rig.paint.materials), "the rig's dictionary is the paint's")
	assert_eq(mats.size(), PlaceholderBody.Paint.values().size())
	for paint: int in mats:
		assert_same(rig.paint.material(paint), mats[paint])
		assert_eq(rig.paint.color_of(paint), mats[paint].get_shader_parameter(&"albedo"))
		# P1-toon: the flash is a uniform of the one toon shader, at 0 from the build (was
		# emission_energy_multiplier 0 with emission enabled); the shader is every paint's.
		assert_eq(mats[paint].get_shader_parameter(&"flash_amount"), 0.0)
		assert_eq(mats[paint].shader, ToonMaterials.TOON_SHADER, "the parry flash never switches variants: one shader")
	assert_eq(rig.paint.color_of(PlaceholderBody.Paint.BODY), Color(0.1, 0.2, 0.3), "set before build(), applied at it")
	assert_eq(rig.paint.color_of(PlaceholderBody.Paint.PANTS), Color(0.1, 0.2, 0.3).darkened(RigPaint.PANTS_DARKEN))
	assert_eq(rig.paint.color_of(PlaceholderBody.Paint.DARK), RigPaint.DARK_COLOR)
	rig.pants_color = Color(0.5, 0.4, 0.3)
	assert_eq(rig.paint.color_of(PlaceholderBody.Paint.PANTS), Color(0.5, 0.4, 0.3), "the setters re-apply")
	rig.accent_color = Color.GREEN
	rig.skin_color = Color.BLUE
	assert_eq(rig.paint.color_of(PlaceholderBody.Paint.ACCENT), Color.GREEN)
	assert_eq(rig.paint.color_of(PlaceholderBody.Paint.SKIN), Color.BLUE)
	assert_eq(rig.paint.base_materials().size(), mats.size(), "no art, so just the primitives'")
	assert_null(rig.paint.art_material(), "no art, no art material")
	# P1-toon: the hulls exist (was: both null, no outline yet).
	assert_not_null(rig.paint.outline_material(), "the art's hull")
	assert_not_null(rig.paint.outline_material_for(PlaceholderBody.parts()[0]), "a placeholder's hull (A7)")


func test_rig_paint_flash_damage_and_overlay_reach_every_base_material() -> void:
	var rig := HumanoidRig.new()
	rig.art = _art()
	add_child_autofree(rig)
	rig.build()
	var art_mat := rig.paint.art_material() as ShaderMaterial
	assert_not_null(art_mat, "a rig with art has an art material")
	assert_same(rig.paint.art_material(), art_mat, "one per rig")
	assert_eq(art_mat.get_shader_parameter(&"albedo_tex"), rig.art.palette, "the palette atlas")
	assert_eq(art_mat.shader, ToonMaterials.TOON_SHADER, "the toon shader")
	# Nearest, no blur between swatches: a sampler hint now, was texture_filter NEAREST.
	assert_string_contains(ToonMaterials.TOON_SHADER.code, "uniform sampler2D albedo_tex : source_color, filter_nearest")
	var bases := rig.paint.base_materials()
	assert_eq(bases.size(), PlaceholderBody.Paint.values().size() + 1, "the primitives' and the art's")
	assert_has(bases, art_mat)
	rig.set_flash(0.8, Color.CYAN)
	for base: Material in bases:
		var mat := base as ShaderMaterial
		assert_eq(mat.get_shader_parameter(&"flash_color"), Color.CYAN)
		assert_almost_eq(float(mat.get_shader_parameter(&"flash_amount")), 0.8, 0.0001, "the parry flash covers the art too")
	rig.set_flash(0.0)
	for base: Material in bases:
		assert_eq((base as ShaderMaterial).get_shader_parameter(&"flash_amount"), 0.0)
	rig.flash_at(Vector3(0.0, 1.0, -0.3), 1.0, 0.5, 0.5)
	var overlay := rig.flash_overlay()
	assert_not_null(overlay, "a contact flash runs")
	for base: Material in bases:
		assert_same(base.next_pass, overlay, "the contact flash is every base material's next_pass")
	rig.set_flash(0.0)
	for base: Material in bases:
		assert_null(base.next_pass, "and gone when cleared")
	rig.set_damage_look(DamageLook.Level.BRUISED)
	assert_eq(rig.paint.materials[PlaceholderBody.Paint.SKIN].get_shader_parameter(&"damage_tex"), VfxArt.texture(&"damage_bruised"),
			"the damage look still marks the primitives")


func test_rig_paint_warm_up_adds_nothing_headless() -> void:
	var rig := _rig()
	var children := rig.get_child_count()
	rig.paint.warm_up(rig)
	assert_eq(rig.get_child_count(), children, "no warm-up box without a window")
	assert_null(rig.find_child("FlashWarmUp", false, false))
	RigPaint.end_warm_up()


# --- ToonMaterials, RoomKit and the pipe: the call sites keep today's materials ---------------


## P1-toon: was test_toon_material_stubs_keep_todays_recipes, which pinned the StandardMaterial3D
## recipes (prop rough 0.5 / metal 0.4, environment rough 0.9, the stub nulls). The factories now
## return the toon shader's materials; the colors, the grid's shader and the warm-up no-op are
## kept, and the recipes' roughness and metal are the toon look's (test_toon.gd).
func test_toon_material_factories_return_the_toon_materials() -> void:
	var prop := ToonMaterials.prop(Color(0.1, 0.2, 0.3))
	assert_eq(prop.shader, ToonMaterials.TOON_SHADER, "the pipe's material is the toon shader")
	assert_eq(prop.get_shader_parameter(&"albedo"), Color(0.1, 0.2, 0.3))
	var env := ToonMaterials.environment(Color(0.4, 0.3, 0.2))
	assert_eq(env.shader, ToonMaterials.TOON_SHADER, "the room's flat material is the toon shader")
	assert_eq(env.get_shader_parameter(&"albedo"), Color(0.4, 0.3, 0.2))
	var grid := ToonMaterials.grid() as ShaderMaterial
	assert_not_null(grid)
	assert_eq(grid.shader, load(GRID_SHADER_PATH), "the grey-box floor grid's shader")
	assert_eq(ToonMaterials.outline_for_prop().shader, ToonMaterials.OUTLINE_SHADER, "the pipe's hull (A7)")
	assert_eq(ToonMaterials.outline().shader, ToonMaterials.OUTLINE_SHADER)
	assert_not_null(ToonMaterials.character(Color.RED))
	assert_not_null(ToonMaterials.art(null))
	var children := get_child_count()
	ToonMaterials.warm_up(self)
	assert_eq(get_child_count(), children, "warming up is a no-op without a window")


## M6 KIT (D10): the kit's one trim material is a toon-lit ShaderMaterial of its own shader, the same
## object on every call, with the flat `albedo` tint a test can read and the edge pass's tag.
func test_the_trim_material_is_one_toon_lit_shader_material() -> void:
	var trim := ToonMaterials.trim()
	assert_true(trim is ShaderMaterial)
	assert_eq(trim.shader, load(ToonMaterials.TRIM_SHADER), "the trim shader (the grid's precedent: its own shader, the same lighting)")
	assert_same(ToonMaterials.trim(), trim, "one shared material, not one per call (the room's flat materials are one per call)")
	assert_eq(trim.get_shader_parameter(&"albedo"), Color.WHITE)
	assert_eq(trim.get_shader_parameter(&"edge_tag"), 1.0, "ROUGHNESS 1: the edge pass keeps working on a module")
	assert_true(trim.shader.code.contains("toon_light.gdshaderinc"), "lit by the one toon lighting")
	assert_true(trim.shader.code.contains("ROUGHNESS = edge_tag"), "writes the edge pass's tag")


func test_room_kit_materials_delegate_to_toon_materials() -> void:
	var flat := RoomKit.flat_material(Color(0.42, 0.4, 0.44))
	# P1-toon: the toon shader's material (was today's StandardMaterial3D recipe, rough 0.9).
	assert_true(flat is ShaderMaterial, "a toon material, typed Material")
	assert_eq((flat as ShaderMaterial).shader, ToonMaterials.TOON_SHADER)
	assert_eq((flat as ShaderMaterial).get_shader_parameter(&"albedo"), Color(0.42, 0.4, 0.44))
	assert_not_same(RoomKit.flat_material(Color.WHITE), RoomKit.flat_material(Color.WHITE), "one material per call, as before")
	var grid := RoomKit.grid_material()
	assert_true(grid is ShaderMaterial)
	assert_eq((grid as ShaderMaterial).shader, load(GRID_SHADER_PATH))


func test_the_pipe_takes_its_material_and_overlay_from_toon_materials() -> void:
	# M6 (D28): the amber is the Debug switch `weapon_floor_amber`'s now; the glint is the default (twin below).
	Tuning.set_value(&"weapon_floor_amber", true)
	var weapon := Weapon.new()
	weapon.color = Color(0.2, 0.3, 0.4)
	add_child_autofree(weapon)
	var meshes := weapon.find_children("*", "MeshInstance3D", false, false)
	assert_eq(meshes.size(), 1)
	var mesh := meshes[0] as MeshInstance3D
	var cylinder := mesh.mesh as CylinderMesh
	assert_not_null(cylinder)
	var mat := cylinder.material as ShaderMaterial
	assert_not_null(mat, "the pipe's toon material")
	assert_eq(mat.shader, ToonMaterials.TOON_SHADER)
	assert_eq(mat.get_shader_parameter(&"albedo"), Tuning.data.weapon_floor_color, "lying on the floor it takes the floor colour (Level > Weapon look)")
	# P1-toon (A7): the pipe has a hull (was: no overlay), and its material is the toon shader's
	# (was rough 0.5 / metal 0.4).
	assert_eq((mesh.material_overlay as ShaderMaterial).shader, ToonMaterials.OUTLINE_SHADER, "the pipe's hull")
	Tuning.set_value(&"weapon_floor_amber", false)
	# The twin on the default path: no amber, the pipe's own colour, and the glint instead.
	weapon.refresh_look()
	assert_eq(mat.get_shader_parameter(&"albedo"), weapon.color, "lying with the amber off: its own colour")
	assert_true(weapon.find_child("Glint", false, false).visible, "and the glint shows")


# --- Tuning: the Look group --------------------------------------------------------------------


func _groups() -> Array[String]:
	var out: Array[String] = []
	for info: Dictionary in TuningData.new().get_property_list():
		if int(info.usage) & PROPERTY_USAGE_GROUP:
			out.append(String(info.name))
	return out


func test_the_look_group_sits_between_audio_and_debug() -> void:
	var groups := _groups()
	var at := groups.find("Look")
	assert_gt(at, 0, "there is a Look group")
	assert_eq(groups[at - 1], "Audio")
	assert_eq(groups[at + 1], "Debug")
	assert_eq(groups[-1], "Debug", "and Debug stays last")


func test_every_look_subgroup_has_a_documented_seed() -> void:
	var seeds := {
		"Toon": [&"look_mid_level"],
		"Outline": [&"look_outline_px", &"look_hull_on_placeholders"],
		"Edges": [&"look_edges_enabled"],
		"Grade": [&"look_grade_enabled"],
		"Trim": [&"look_trim_ink_cut"],
		"FP feel": [&"fp_knockdown_hide_torso"],
		"Motion": [&"look_motion_breath_deg"],
	}
	var docs := TuningPanel.doc_comments(TuningData)
	var found: Dictionary = {}
	var order := PackedStringArray()
	for info: Dictionary in Tuning.tuning_properties():
		if info.group != "Look":
			continue
		var sub: String = info.subgroup
		if not found.has(sub):
			found[sub] = []
			order.append(sub)
		found[sub].append(StringName(info.name))
		assert_ne(docs.get(StringName(info.name), ""), "", "%s is documented" % info.name)
		if int(info.type) == TYPE_FLOAT or int(info.type) == TYPE_INT:
			assert_eq(int(info.hint), PROPERTY_HINT_RANGE, "%s is a slider" % info.name)
	assert_eq(order, PackedStringArray(["Toon", "Outline", "Edges", "Grade", "Trim", "FP feel", "Motion"]), "the owners' subgroups, in order")
	for sub: String in seeds:
		for name: StringName in seeds[sub]:
			assert_has(found.get(sub, []), name)
	# The plan's starting values (look bible, A7).
	var defaults := TuningData.new()
	assert_eq(defaults.look_mid_level, 0.72)
	assert_eq(defaults.look_outline_px, 3.75)
	assert_true(defaults.look_hull_on_placeholders, "A7: the hull is on the placeholders by default")
	assert_true(defaults.look_edges_enabled)
	assert_true(defaults.look_grade_enabled)
	assert_false(defaults.fp_knockdown_hide_torso, "a feel alternative defaults to today")


func test_look_show_art_is_a_debug_switch_and_never_in_a_preset() -> void:
	var info := Tuning._property_info(Tuning.tuning_properties(), &"look_show_art")
	assert_eq(info.group, "Debug", "A9: the A/B lives in Debug")
	assert_true(TuningData.new().look_show_art, "the art shows by default")
	assert_false(Tuning.is_preset_property(&"look_show_art"), "presets skip it")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tuning/default.json"))
	assert_false((data.tuning as Dictionary).has("look_show_art"))
	for name: StringName in [&"look_mid_level", &"look_outline_px", &"look_hull_on_placeholders",
			&"look_edges_enabled", &"look_grade_enabled", &"fp_knockdown_hide_torso"]:
		assert_true(Tuning.is_preset_property(name), "%s is saved in presets" % name)
		assert_true((data.tuning as Dictionary).has(String(name)), "default.json holds %s" % name)


# --- The joint table ----------------------------------------------------------------------------


## Numbers within a micrometre, strings and structure exactly.
func _same(a: Variant, b: Variant, path: String) -> bool:
	if a is Dictionary and b is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			gut.p("%s: %d keys vs %d" % [path, da.size(), db.size()])
			return false
		for key: Variant in da:
			if not db.has(key) or not _same(da[key], db[key], "%s.%s" % [path, key]):
				return false
		return true
	if a is Array and b is Array:
		var aa: Array = a
		var ab: Array = b
		if aa.size() != ab.size():
			gut.p("%s: %d items vs %d" % [path, aa.size(), ab.size()])
			return false
		for i: int in aa.size():
			if not _same(aa[i], ab[i], "%s[%d]" % [path, i]):
				return false
		return true
	if (a is float or a is int) and (b is float or b is int):
		if absf(float(a) - float(b)) > 0.000002:
			gut.p("%s: %s vs %s" % [path, a, b])
			return false
		return true
	if a != b:
		gut.p("%s: %s vs %s" % [path, a, b])
		return false
	return true


## tools/pipeline/joints.json is the asset contract's joint table, written from PlaceholderBody
## by tools/pipeline/dump_joints.gd. It must say what PlaceholderBody says: change the body,
## then run `godot --headless -s tools/pipeline/dump_joints.gd --quit-after 5` and commit it.
func test_the_joint_table_file_matches_placeholder_body() -> void:
	assert_true(FileAccess.file_exists(JOINTS_PATH), "joints.json is committed")
	var on_disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(JOINTS_PATH))
	assert_true(on_disk is Dictionary, "it parses")
	var fresh: Variant = JSON.parse_string(DUMP.to_json())
	assert_true(_same(fresh, on_disk, "joints"),
			"joints.json is stale: run godot --headless -s tools/pipeline/dump_joints.gd --quit-after 5")


func test_the_joint_table_holds_the_skeleton_the_pipeline_fits_to() -> void:
	var table: Dictionary = DUMP.table()
	var bones: Array = table.bones
	assert_eq(bones.size(), 23)
	var globals: Dictionary[String, Vector3] = {}
	for i: int in bones.size():
		var bone: Dictionary = bones[i]
		assert_eq(bone.name, String(PlaceholderBody.BONE_NAMES[i]), "bones in BONE_NAMES order")
		var parent: String = bone.parent
		var local: Array = bone.rest_local
		var rest := Vector3(local[0], local[1], local[2])
		var expected: Vector3 = rest + (globals[parent] if parent != "" else Vector3.ZERO)
		globals[bone.name] = expected
		var global: Array = bone.rest_global
		assert_almost_eq(Vector3(global[0], global[1], global[2]), expected, Vector3.ONE * 0.00001, "%s: its rest global is the sum of the offsets" % bone.name)
	assert_eq(globals["Hips"], Vector3(0.0, 0.975, 0.0))
	assert_eq((table.soles as Array).size(), 6, "heel, ball and toe tip per side")
	assert_eq((table.fist_boxes as Array).size(), 2)
	assert_eq((table.hurtboxes as Array).size(), 4, "head, torso, two legs")
	assert_eq((table.points as Dictionary).size(), PlaceholderBody.POINT_BONE.size())
	assert_eq((table.parts_enemy as Array).size(), ENEMY_MESHES)
	assert_eq((table.parts_player as Array).size(), PLAYER_MESHES)
	for fist: Dictionary in table.fist_boxes:
		assert_eq(fist["size"], [0.1, 0.118, 0.116], "the fist box the glove is fitted to (rig-render §9b.9)")
		assert_eq(fist["center_offset"], [0.0, -0.065, -0.005])
	var lowest := INF
	for sole: Dictionary in table.soles:
		lowest = minf(lowest, (sole.rest_global as Array)[1])
	assert_almost_eq(lowest, 0.0, 0.00001, "the soles' lowest sample rests on the floor")
