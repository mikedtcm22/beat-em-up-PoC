extends GutTest
## The art roster (Milestone 6, CHAIN, M6 plan D26): tests/fixtures/art/roster/<id>.json, one file per character. This file
## holds what is true of every roster character, so that CREW and HEAVIES add a folder and a roster file and nothing else: the
## file loads and is complete, its art attaches at its height (a broken art fails HERE through has_art(), not as the warning
## SkinnedArt prints), its scene wears it, its chain report is committed and names the GLBs it exported, its strain file holds
## the whole-run figures and a figure for every clip, every catalog art is warmed (D27), and the first rows of the dummy, the
## roster's proof (D17). The measured rows A1-A12 for each character are test_m4_done_when's, which loops over this roster.

const Roster := preload("res://tests/art_roster.gd")
const ArtStrain := preload("res://tests/art_strain.gd")
const CHARACTERS := "res://assets/source/characters"
const EXPORT := "res://assets/export/characters"


func before_each() -> void:
	SkinnedArt.clear_cache()
	RoomKit.release_catalog_arts()


func after_each() -> void:
	RoomKit.release_catalog_arts()


func _rig(r: Dictionary) -> HumanoidRig:
	var rig := HumanoidRig.new()
	rig.height = float(r.height_m)
	rig.build_hurtboxes = false
	rig.art = load(r.art) as CharacterArt
	add_child_autofree(rig)
	rig.build()
	return rig


func test_the_roster_has_the_punk_and_the_dummy_and_every_file_is_well_formed() -> void:
	var ids := Roster.ids()
	assert_eq(ids[0], "punk", "the Punk is first")
	assert_true(ids.has("dummy"), "the dummy is in the roster")
	for id: String in ids:
		assert_eq(Roster.problems(id), PackedStringArray(), "%s: the roster file is complete" % id)
		var r := Roster.row(id)
		assert_between(float(r.height_m), 1.5, 2.5, "%s: a body height" % id)
		assert_true(int(r.budget) == 15000 or (id == "boss" and int(r.budget) == 30000), "%s: SPEC §10's budget (15000, the boss 30000)" % id)
		assert_gt(int(r.budget), 0)


func test_each_roster_art_names_its_own_glb_and_the_shared_atlas_and_carries_the_files_budget() -> void:
	for id: String in Roster.ids():
		var r := Roster.row(id)
		var art := load(r.art) as CharacterArt
		assert_not_null(art, "%s: the art loads" % id)
		assert_eq(String(art.id), id, "%s: the art's id" % id)
		assert_eq(art.triangle_budget, int(r.budget), "%s: the art resource carries the roster's budget" % id)
		assert_eq(art.palette.resource_path, "res://assets/export/palette/palette_atlas.png", "%s: the shared atlas" % id)
		assert_eq(Roster.glb_of(r), "%s/%s/%s.glb" % [EXPORT, id, id], "%s: the GLB of the contract's path" % id)
		assert_eq(SkinnedArt.check(art), PackedStringArray(), "%s: SkinnedArt.check() is empty" % id)


func test_each_roster_art_attaches_at_its_height_and_a_broken_art_would_fail_here() -> void:
	for id: String in Roster.ids():
		var r := Roster.row(id)
		var rig := _rig(r)
		assert_true(rig.has_art(), "%s: the rig wears its art at %.2f m (has_art(): check() passed)" % [id, float(r.height_m)])
		assert_gt(rig.art_meshes().size(), 0, "%s: art meshes are on the rig" % id)
		var names := PackedStringArray()
		for mi: MeshInstance3D in rig.art_meshes():
			names.append(String(mi.name).trim_prefix("Art"))
		names.sort()
		var want := PackedStringArray(r.meshes)
		want.sort()
		assert_eq(names, want, "%s: the meshes the roster names" % id)
	# The teeth: an art that breaks the contract does not attach, and has_art() says so.
	var broken := CharacterArt.new()
	broken.id = &"broken"
	var rig := HumanoidRig.new()
	rig.art = broken
	add_child_autofree(rig)
	rig.build()
	assert_false(rig.has_art(), "an art with no scene is not worn")


func test_each_roster_actor_scene_wears_its_art() -> void:
	for id: String in Roster.ids():
		var r := Roster.row(id)
		var stage := Node3D.new()
		add_child_autofree(stage)
		var actor := (load(r.actor_scene) as PackedScene).instantiate() as CombatActor
		assert_not_null(actor, "%s: the scene is a CombatActor" % id)
		stage.add_child(actor)
		await get_tree().physics_frame
		assert_eq(actor.art, load(r.art), "%s: the scene's `art` is the roster's" % id)
		assert_true(actor.rig.has_art(), "%s: its rig wears the art" % id)
		assert_almost_eq(actor.rig.height, float(r.height_m), 0.001, "%s: the body is the roster's height" % id)


func test_each_roster_character_has_a_chain_report_that_names_the_glbs_it_exported_and_a_pipeline() -> void:
	for id: String in Roster.ids():
		assert_true(FileAccess.file_exists("%s/%s/pipeline.json" % [CHARACTERS, id]), "%s: assets/source/characters/%s/pipeline.json" % [id, id])
		var path := "%s/%s/report/report.json" % [CHARACTERS, id]
		assert_true(FileAccess.file_exists(path), "%s: the chain report is committed (run.py --asset %s --check says YES)" % [id, id])
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_eq(String(report.asset), id, "%s: the report is its own" % id)
		assert_true((report.outputs as Dictionary).has("%s.glb" % id), "%s: the report names %s.glb" % [id, id])
		for glb: String in report.outputs:
			assert_eq(FileAccess.get_sha256("%s/%s/%s" % [EXPORT, id, glb]), report.outputs[glb], "%s: %s is the file the report hashed" % [id, glb])


func test_each_roster_character_has_a_strain_file_with_the_whole_run_figures_and_every_clip() -> void:
	for id: String in Roster.ids():
		var file := Roster.strain_file(id)
		assert_false(file.is_empty(), "%s: tests/fixtures/strain/%s.json" % [id, id])
		for key: String in Roster.STRAIN_KEYS:
			assert_true((file.get("whole", {}) as Dictionary).has(key), "%s: whole.%s" % [id, key])
		var clips: Dictionary = file.get("clips", {})
		for anim: StringName in PlaceholderAnims.ANIM_IDS:
			assert_true(clips.has(String(anim)), "%s: a strain figure for the animation %s" % [id, anim])
		for move_id: String in Roster.row(id).moves:
			assert_true(clips.has(move_id), "%s: a strain figure for its move %s" % [id, move_id])
		for flex: Dictionary in ArtStrain.peak_poses():
			assert_true(clips.has("flex: %s" % flex.label), "%s: a figure for the peak flex %s" % [id, flex.label])


func test_the_punks_m4_numbers_moved_into_the_roster_unchanged() -> void:
	var punk := Roster.row("punk")
	var ratchets: Dictionary = punk.ratchets
	assert_eq(float(ratchets.a9_cells), 0.07)
	assert_eq(float(ratchets.a9_strike_art_share_min), 0.27)
	assert_eq(Roster.lens_bar(punk, "punk_jab pitch +8"), 0.056)
	assert_eq(Roster.lens_bar(punk, "punk_cross pitch +8"), 0.054)
	assert_eq(Roster.lens_bar(punk, "punk_shove pitch +8"), 0.04, "every other pose is held at the plan's 4 points")
	assert_eq(ratchets.anchor_m, {"head": 0.02, "torso": 0.065, "leg": 0.032})
	assert_eq(float(ratchets.stretch_m), 0.09)
	assert_eq(float(ratchets.variant_stretch_m), 0.10)
	assert_eq(int(punk.budget), 15000)
	assert_eq(float(punk.height_m), 1.8)
	assert_eq(punk.moves, ["punk_jab", "punk_cross", "punk_shove"])
	var shipped := ArtStrain.SHIPPED[0]
	assert_eq(shipped.name, "punk", "ArtStrain.SHIPPED[0] is the Punk, from his strain file")
	assert_eq([shipped.in_bar_min, shipped.high_max, shipped.low_min, shipped.max_max, shipped.min_min, shipped.flex_share_max], [1, 4.23, 0.153, 12.85, 0.0144, 0.0173])
	var hero: Dictionary = ArtStrain.SHIPPED[1]
	assert_eq([hero.name, hero.high_max, hero.low_min, hero.max_max, hero.min_min, hero.flex_share_max], ["player", 9.1, 0.14, 39.1, 0.0282, 0.0066], "the hero's row is as M4 set it")


func test_every_catalog_art_is_warmed_and_a_broken_one_is_not_silent() -> void:
	# D27: RoomKit.warm_catalog_arts() reads every EnemyCatalog scene's art once and holds it, so its GLB is read off the spawn frame.
	var held := RoomKit.warm_catalog_arts()
	var ids := PackedStringArray()
	for art: CharacterArt in held:
		ids.append(String(art.id))
		assert_true(SkinnedArt.entry_of(art).problems.is_empty(), "%s: warmed and clean" % art.id)
	for id: String in Roster.ids():
		var r := Roster.row(id)
		var entry_has_art := false
		for entry: Dictionary in EnemyCatalog.available():
			if entry.scene == r.actor_scene:
				entry_has_art = true
		assert_true(entry_has_art, "%s: its scene is in EnemyCatalog (that is what warms it)" % id)
		assert_true(ids.has(id), "%s: its art is among the %d warmed (%s)" % [id, held.size(), ids])
	assert_eq(RoomKit.held_catalog_arts(), held, "the arts are held")
	RoomKit.release_catalog_arts()
	assert_eq(RoomKit.held_catalog_arts().size(), 0, "released")
	# Every catalog scene that carries art has its art in the warm set: none is left cold.
	for entry: Dictionary in EnemyCatalog.available():
		var state := (load(entry.scene) as PackedScene).get_state()
		for i: int in state.get_node_property_count(0):
			if state.get_node_property_name(0, i) == &"art":
				assert_true(RoomKit.catalog_arts().has(state.get_node_property_value(0, i)), "%s: its art is in the warm set" % entry.id)


# --- The dummy, the roster's proof (D17) ----------------------------------------------------------------


func test_the_dummy_is_the_padded_look_four_colours_no_red_in_its_own_slots() -> void:
	var art := load("res://game/actors/art/dummy_art.tres") as CharacterArt
	var entry := SkinnedArt.entry_of(art)
	var slots := {}
	for part: SkinnedArt.ArtMesh in entry.meshes:
		for uv: Vector2 in (part.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] as PackedVector2Array):
			slots[int(roundf(uv.y * 2.0 - 0.5)) * 32 + int(roundf(uv.x * 32.0 - 0.5))] = true
	var keys := slots.keys()
	keys.sort()
	assert_eq(keys, [56, 57, 58, 59], "the dummy draws only its own slots 56-59")
	var atlas := (load("res://assets/export/palette/palette_atlas.png") as Texture2D).get_image()
	for slot: int in keys:
		var c := atlas.get_pixel((slot % 32) * 8 + 4, (slot / 32) * 8 + 4)
		var hue := c.h * 360.0
		assert_false((hue >= 345.0 or hue <= 15.0) and c.s > 0.5, "slot %d is not in the red band" % slot)
	var triangles := 0
	for part: SkinnedArt.ArtMesh in entry.meshes:
		triangles += part.triangles
	assert_lte(triangles, 15000, "the dummy is at most 15000 triangles (%d)" % triangles)
	assert_eq(entry.meshes.size(), 1, "one mesh: no first-person split on a dummy")


func test_the_training_dummy_scene_wears_the_art_and_draws_no_colour_of_its_own() -> void:
	var dummy := (load("res://game/enemies/dummy/training_dummy.tscn") as PackedScene).instantiate() as TrainingDummy
	add_child_autofree(dummy)
	await get_tree().physics_frame
	assert_true(dummy.rig.has_art(), "the dummy wears dummy_art.tres")
	for mi: MeshInstance3D in dummy.rig.art_meshes():
		assert_eq(mi.material_override.get_shader_parameter(&"albedo"), Color.WHITE, "the art is untinted")
	var room := (load("res://game/level/test_room.tscn") as PackedScene).instantiate()
	room.set(&"with_presentation", false)
	add_child_autofree(room)
	await get_tree().physics_frame
	assert_null(room.get(&"dummy_colors"), "the training room has no per-dummy colours")
	for d: TrainingDummy in room.get(&"dummies"):
		assert_true(d.rig.has_art(), "%s wears the art" % d.name)
