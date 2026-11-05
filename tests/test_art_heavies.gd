extends GutTest
## Milestone 6, HEAVIES: the Bruiser and Ox Pellerin through the chain (the roster rows hold A1-A12 for them; this file holds what is
## theirs). Their art is authored at 1.8 m and worn at 2.05 and 2.3 m, so each row's checks run at the scaled height; and the strikes that
## reach the lens (the Bruiser's overhead smash and headbutt, the boss's charge, pound and slam) are held to the Punk's lens rule: no vertex of
## the drawn art inside the view is nearer than the near plane (FPView.NEAR, the Punk's jab and cross rule, test_art_punk.gd).

const SkinnedView := preload("res://tests/skinned_view.gd")
const FPView := preload("res://tests/fp_view.gd")
const Roster := preload("res://tests/art_roster.gd")
## Where the Bruiser stands for its strikes, in metres from the player (the Punk's strike distance, 0.95). The boss stands at
## Tuning's boss_read_m instead: nearer than that the AI steps it back before a charge or a pound (its wind-up is over the lens),
## so no strike of the live game starts closer (a 0.95 m pound put its forearm 2.9 cm from the lens).
const STRIKE_DISTANCE_M := 0.95
## The attack indices (EnemyActor.force_attack) that reach the lens, by roster id: the Bruiser's smash and grab/headbutt, the boss's
## charge, pound and grab/slam.
var _last_bone := &""
const STRIKES := {&"bruiser": [0, 1], &"boss": [0, 1, 2]}


func after_each() -> void:
	Tuning.set_value(&"ai_frozen", false)
	Tuning.set_value(&"god_mode", false)


func test_both_heavies_are_in_the_roster_with_their_own_heights_and_budgets() -> void:
	var bruiser := Roster.row("bruiser")
	var boss := Roster.row("boss")
	assert_eq(float(bruiser.height_m), 2.05, "the Bruiser's height")
	assert_eq(float(boss.height_m), 2.3, "the boss's height")
	assert_eq(int(bruiser.budget), 15000)
	assert_eq(int(boss.budget), 30000, "SPEC section 10's Boss row")
	assert_eq(String(boss.label), "Ox Pellerin")
	# The actors go under a holder the test frees: an EnemyActor makes the EnemyDirector as its sibling, and one made as a child of
	# the test node itself stayed there (GUT's "unfreed children" warning, final-code-04).
	var holder := Node3D.new()
	add_child_autofree(holder)
	for id: String in ["bruiser", "boss"]:
		assert_eq(Roster.problems(id), PackedStringArray(), "%s: the roster file is complete" % id)
		var scene := load(String(Roster.row(id).actor_scene)) as PackedScene
		var actor := scene.instantiate() as EnemyActor
		holder.add_child(actor)
		await get_tree().physics_frame
		assert_true(actor.rig.has_art(), "%s: wears its art (no primitive body left)" % id)
		assert_almost_eq(actor.rig.height, float(Roster.row(id).height_m), 0.0001, "%s: the rig is at its height" % id)


func test_the_boss_is_named_ox_pellerin_on_the_scene_and_in_the_catalog() -> void:
	var scene := load("res://game/enemies/boss/boss.tscn") as PackedScene
	var boss := scene.instantiate() as Boss
	assert_eq(boss.display_name, "Ox Pellerin")
	boss.free()
	var label := ""
	for entry: Dictionary in EnemyCatalog.ENTRIES:
		if entry.id == &"boss":
			label = String(entry.label)
	assert_eq(label, "Ox Pellerin", "the training room's catalog entry")
	# A spawned boss keeps its scene's name (the spawner used to write "Boss" over it); other enemies are still "<Label> <n>".
	var serials := {}
	var spawned := EncounterSpawner.make_enemy(scene, &"boss", serials)
	assert_eq(spawned.display_name, "Ox Pellerin")
	spawned.free()
	var bruiser := EncounterSpawner.make_enemy(load("res://game/enemies/bruiser/bruiser.tscn") as PackedScene, &"bruiser", serials)
	assert_eq(bruiser.display_name, "Bruiser 1")
	bruiser.free()


func test_the_palettes_are_inside_their_slot_ranges_and_never_red() -> void:
	for id: String in ["bruiser", "boss"]:
		var palette: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/palette/%s.json" % id))
		var range_: Array = palette.slot_range
		for sw: Dictionary in palette.swatches:
			assert_between(int(sw.slot), int(range_[0]), int(range_[1]), "%s: slot %d is in its range" % [id, sw.slot])
			var c := Color.html(String(sw.srgb))
			var red := (c.h >= 345.0 / 360.0 or c.h <= 15.0 / 360.0) and c.s > 0.5
			assert_false(red, "%s %s: not in the red band" % [id, sw.name])
			assert_false(bool(sw.get("gloss", false)), "%s %s: nothing glossy (the Punk's lens stays the one)" % [id, sw.name])
		# Armour, the orange belt and trim: scuff, never blood (D6); skin is never blood-proof.
	var bruiser: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/palette/bruiser.json"))
	var boss: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/palette/boss.json"))
	for sw: Dictionary in bruiser.swatches:
		if sw.name == "bruiser_steel":
			assert_false(bool(sw.get("blood", true)), "the Bruiser's steel takes no blood")
	for sw: Dictionary in boss.swatches:
		if sw.name == "boss_orange":
			assert_false(bool(sw.get("blood", true)), "the boss's orange takes no blood")


func test_the_boss_is_darker_than_the_concepts_slate_and_its_orange_is_clear_of_the_dummys() -> void:
	var boss: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/palette/boss.json"))
	var dummy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/palette/dummy.json"))
	var charcoal := Color.WHITE
	var orange := Color.WHITE
	for sw: Dictionary in boss.swatches:
		if sw.name == "boss_charcoal":
			charcoal = Color.html(String(sw.srgb))
		if sw.name == "boss_orange":
			orange = Color.html(String(sw.srgb))
	assert_lt(charcoal.v, 0.3, "the robe's charcoal is darker than the concept's slate (value %.2f)" % charcoal.v)
	var dummy_orange := Color.WHITE
	for sw: Dictionary in dummy.swatches:
		if sw.slot == 57:
			dummy_orange = Color.html(String(sw.srgb))
	assert_gte(absf(orange.h - dummy_orange.h) * 360.0, 5.0, "the champion's orange is told from the dummy's muted orange by hue")
	assert_gt(orange.s, dummy_orange.s, "and is the more saturated")


func _swatch(id: String, swatch_name: String) -> Dictionary:
	var palette: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/palette/%s.json" % id))
	for sw: Dictionary in palette.swatches:
		if sw.name == swatch_name:
			return sw
	return {}


## final-chars-01: the boss's gloves read beside his charcoal sleeves: their own swatch of boss.json, darker than the robe, and the
## chain's config, the palette and the generated fist's slots agree on it (the wrist wrap above them is the orange).
func test_the_boss_gloves_are_their_own_darker_slot_and_the_chain_agrees() -> void:
	var glove := _swatch("boss", "boss_glove")
	var charcoal := _swatch("boss", "boss_charcoal")
	assert_false(glove.is_empty(), "boss.json has a glove swatch")
	assert_lt(Color.html(String(glove.srgb)).v, Color.html(String(charcoal.srgb)).v, "the glove leather is darker than the robe")
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/characters/boss/pipeline.json"))
	assert_eq(int(cfg.parts.fists.glove_slot), int(glove.slot), "parts.fists.glove_slot is the glove's slot")
	var regions: Array = (cfg.palette.regions as Array).filter(func(r: Dictionary) -> bool: return String(r.name).begins_with("glove"))
	assert_eq(regions.size(), 2, "one glove region a hand (OX-2 added a legs region of its own beside them)")
	for region: Dictionary in regions:
		assert_eq(int(region.slot), int(glove.slot), "%s labels the glove's slot" % region.name)
	assert_eq(int(cfg.palette.strap_paint_slot), int(_swatch("boss", "boss_orange").slot), "the wrist wrap is the orange")
	assert_true((cfg.palette.slots as Array).has(float(glove.slot)), "the labelling may use the glove's slot")


## final-chars-03: the steel is a mid-value blue-grey (it lit to near white at #9aa4c0) and the plates take ink through a zone.
func test_the_bruisers_steel_is_mid_value_and_the_plates_have_an_ink_zone() -> void:
	var steel := Color.html(String(_swatch("bruiser", "bruiser_steel").srgb))
	var purple := Color.html(String(_swatch("bruiser", "bruiser_purple").srgb))
	assert_lt(steel.v, 0.68, "the steel is a mid value (%.2f)" % steel.v)
	assert_gt(steel.v, 0.4, "and still lighter than the black")
	assert_gt(absf(steel.h - purple.h) * 360.0, 40.0, "told from the purple by hue")
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/characters/bruiser/pipeline.json"))
	var zones: Array = cfg.palette.detail_bake.zones
	assert_gt(zones.size(), 0, "the plates have a detail_bake zone")
	assert_true((zones[0].slots as Array).has(float(_swatch("bruiser", "bruiser_steel").slot)), "on the steel's slot")


## The nearest vertex of the art of `actor`, drawn inside the view of `cam`, to the lens.
func _nearest_in_view(actor: EnemyActor, cam: Transform3D) -> float:
	var nearest := INF
	var bone := &""
	var tan_h := tan(deg_to_rad(FPView.HALF_H_DEG))
	var tan_v := tan_h * 9.0 / 16.0
	var forward := -cam.basis.z
	for mi: MeshInstance3D in actor.rig.art_meshes():
		var world := mi.global_transform * SkinnedView.skin_vertices(mi, actor.rig)
		for i: int in world.size():
			var to := world[i] - cam.origin
			var depth := to.dot(forward)
			if depth <= 0.0 or absf(to.dot(cam.basis.x)) > tan_h * depth or absf(to.dot(cam.basis.y)) > tan_v * depth:
				continue
			if to.length() < nearest:
				nearest = to.length()
				bone = SkinnedView._dominant_bone(SkinnedView._mesh_data(mi.mesh as ArrayMesh), mi.skin, [i])
	_last_bone = bone
	return nearest


func _distance(id: String) -> float:
	return Tuning.data.boss_read_m if id == "boss" else STRIKE_DISTANCE_M


func _arena(id: String) -> Dictionary:
	Tuning.set_value(&"ai_frozen", true)
	Tuning.set_value(&"god_mode", true)
	var stage := Node3D.new()
	add_child_autofree(stage)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	floor_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(shape)
	stage.add_child(floor_body)
	var player := PlayerCharacter.new()
	stage.add_child(player)
	player.input.scripted = true
	var heavy := (load(String(Roster.row(id).actor_scene)) as PackedScene).instantiate() as EnemyActor
	heavy.position = Vector3(0.0, 0.0, -_distance(id))
	heavy.rotation.y = 0.0
	stage.add_child(heavy)
	return {stage = stage, player = player, heavy = heavy}


func _lens_rule(id: String) -> void:
	var arena := _arena(id)
	var player := arena.player as PlayerCharacter
	var heavy := arena.heavy as EnemyActor
	for i: int in 4:
		await get_tree().physics_frame
	assert_true(heavy.rig.has_art(), "%s wears its art" % id)
	var nearest := INF
	var worst_index := -1
	for index: int in STRIKES[StringName(id)]:
		heavy.global_position = player.global_position + Vector3(0.0, 0.0, -_distance(id))
		heavy.force_attack(index)
		var started := false
		for t: int in 120:
			await get_tree().physics_frame
			if heavy.current_move != null:
				started = true
				break
		assert_true(started, "%s: attack %d starts" % [id, index])
		var here := INF
		var here_bone := &""
		for t: int in 300:
			if heavy.current_move == null:
				break
			await get_tree().physics_frame
			var cam := FirstPersonCamera.view_from_eye(player, player.get_eye_transform().origin)
			var near_now := _nearest_in_view(heavy, cam)
			if near_now < here:
				here = near_now
				here_bone = _last_bone
		print("ART-HEAVIES %s attack %d: nearest art vertex in view %.3f m on %s (the near plane %.2f m)" % [id, index, here, here_bone, FPView.NEAR])
		if here < nearest:
			nearest = here
			worst_index = index
		for t: int in 40:
			await get_tree().physics_frame
	assert_lt(nearest, INF, "%s: the strikes were sampled" % id)
	assert_gte(nearest, FPView.NEAR, "%s: no vertex in view is nearer than the near plane (nearest %.3f m, attack %d)" % [id, nearest, worst_index])


func test_the_bruisers_smash_and_headbutt_bring_no_art_vertex_in_view_nearer_than_the_near_plane() -> void:
	await _lens_rule("bruiser")


func test_the_bosss_charge_pound_and_slam_bring_no_art_vertex_in_view_nearer_than_the_near_plane() -> void:
	await _lens_rule("boss")
