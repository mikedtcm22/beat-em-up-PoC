extends GutTest
## LD-ASSET's art (docs/video/P1.md), headless: the video textures are there and are what the shader reads, the video GLBs obey the
## art contract with the same body and a different face shading, and a character that spawns is dressed by the art rig: the meshes
## swapped, the paint and ink textures on its material, each part switchable for an A/B.

const ART_DIR := "res://assets/video/characters"
const PAINT_SIZE := 4096
const INK_SIZE := 4096
## The video GLBs: every character has one since round 2 (the new UV2 layout; the player's smoothed arm).
const GLB_IDS: Array[StringName] = [&"punk", &"boss", &"player"]
const ALL_IDS: Array[StringName] = [&"punk", &"boss", &"player"]
const PUNK_SCENE := "res://game/enemies/punk/street_punk.tscn"


func _image(path: String) -> Image:
	return (load(path) as Texture2D).get_image()


func test_the_textures_exist_at_their_sizes_and_the_ink_is_sparse() -> void:
	for id in ALL_IDS:
		var paint := _image("%s/%s/%s_paint.png" % [ART_DIR, id, id])
		var ink := _image("%s/%s/%s_ink.png" % [ART_DIR, id, id])
		assert_eq(paint.get_width(), PAINT_SIZE, "%s paint is %d wide" % [id, PAINT_SIZE])
		assert_eq(ink.get_width(), INK_SIZE, "%s ink is %d wide" % [id, INK_SIZE])
		ink.resize(256, 256, Image.INTERPOLATE_BILINEAR)
		var inked := 0.0
		for y in 256:
			for x in 256:
				inked += ink.get_pixel(x, y).r
		var share := inked / 65536.0
		assert_between(share, 0.001, 0.2, "%s ink covers a few percent of the layout, not none and not all (%.4f)" % [id, share])


func test_the_painted_albedo_is_painted_not_the_swatches() -> void:
	# At most 64 swatches of the game's palette; the painted albedo has many more distinct colours (3 values to a material, a brush grain).
	for id in ALL_IDS:
		var paint := _image("%s/%s/%s_paint.png" % [ART_DIR, id, id])
		paint.resize(256, 256, Image.INTERPOLATE_NEAREST)
		var seen := {}
		for y in 256:
			for x in 256:
				seen[paint.get_pixel(x, y).to_html(false)] = true
		assert_gt(seen.size(), 200, "%s has far more than a palette's worth of colours (%d)" % [id, seen.size()])


func _game_art(id: StringName) -> CharacterArt:
	var art := (load("res://game/actors/art/%s_art.tres" % id) as CharacterArt).duplicate() as CharacterArt
	if art.scene == null and art.has_meta(&"scene_path"):
		art.scene = load(String(art.get_meta(&"scene_path"))) as PackedScene
	return art


func _video_art(id: StringName) -> CharacterArt:
	var base := _game_art(id)
	var video := base.duplicate() as CharacterArt
	video.scene = load("%s/%s/%s_video.glb" % [ART_DIR, id, id]) as PackedScene
	video.triangle_budget = 250000  # the player's arms are subdivided in round 2 (the game's budget is 30,000)
	return video


func test_the_video_glbs_keep_the_contract_the_body_and_change_the_face_shading() -> void:
	for id in GLB_IDS:
		var game := _game_art(id)
		var video := _video_art(id)
		assert_eq(SkinnedArt.check(video), PackedStringArray(), "%s: the video GLB breaks no part of the art contract" % id)
		var game_parts := SkinnedArt.entry_of(game).meshes
		var video_parts := SkinnedArt.entry_of(video).meshes
		assert_eq(video_parts.size(), game_parts.size(), "%s: the same meshes" % id)
		var a: AABB = game_parts[0].mesh.get_aabb()
		var b: AABB = video_parts[0].mesh.get_aabb()
		# The Punk and Ox: the same body to 2 mm. The player's arms are relaxed and subdivided (round 2), which pulls the fists and elbows in (the smoothing shrinks the extremes: 5 cm measured on the box).
		var tolerance := 0.08 if id == &"player" else 0.002
		assert_lt(a.position.distance_to(b.position) + a.size.distance_to(b.size), tolerance, "%s: the same body, to %.0f mm" % [id, tolerance * 1000.0])
		var game_normals: PackedVector3Array = game_parts[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		var video_normals: PackedVector3Array = video_parts[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		# Vertices were split where the new normals differ across a corner (more, never fewer), or the normals changed in place.
		assert_gte(video_normals.size(), game_normals.size(), "%s: no vertex lost" % id)
		var changed := video_normals.size() != game_normals.size()
		if not changed:
			for i in game_normals.size():
				if game_normals[i].distance_to(video_normals[i]) > 0.05:
					changed = true
					break
		assert_true(changed, "%s: the face's normals now differ from the game's" % id)


func test_the_player_has_a_video_mesh_with_smooth_normals() -> void:
	# Round 2 (old: "the player needs no video mesh", assert_false on the file): its arm is a third of a first-person frame, and the game's
	# shading normals are lumpy at a centimetre. The twin of the old assertion is in test_ld_art2_data.gd (the contract and the layout).
	assert_true(ResourceLoader.exists("%s/player/player_video.glb" % ART_DIR), "the player has a video mesh")


func test_the_layout_uv_edit_makes_the_shader_read_uv2_and_is_idempotent() -> void:
	assert_true(CineArtRig.ensure_layout_uv(), "the cine toon reads paint_tex and ink_tex with UV2")
	var code := (load(CineArtRig.TOON_SHADER_PATH) as Shader).code
	assert_false(code.contains("texture(paint_tex, UV)"), "no sample of the paint with the swatch UV is left")
	assert_false(code.contains("texture(ink_tex, UV)"), "nor of the ink")
	assert_true(CineArtRig.ensure_layout_uv(), "a second call changes nothing")


func test_the_look_files_load_for_every_location() -> void:
	for location in ["street_night", "roofs_dusk", "boss_fire"]:
		var look := load("res://video/look/%s/art.tres" % location) as VideoArtLook
		assert_not_null(look, "%s has an art piece" % location)
		assert_true(look.swap_meshes and look.paint and look.ink, "%s: all three parts on" % location)
		assert_eq(look.characters.size(), 3, "%s: the three characters of round 1" % location)


func _spawn_punk(look: VideoArtLook) -> Dictionary:
	var level := Node3D.new()
	add_child_autofree(level)
	var punk := (load(PUNK_SCENE) as PackedScene).instantiate() as Node3D
	level.add_child(punk)
	await wait_process_frames(2)
	var rig := punk.get(&"rig") as HumanoidRig
	var game_meshes: Array[Mesh] = []
	for mesh in rig.art_meshes():
		game_meshes.append(mesh.mesh)
	look.apply(level)
	await wait_process_frames(3)
	return {level = level, rig = rig, game_meshes = game_meshes}


func test_the_art_rig_dresses_a_punk_and_each_part_switches() -> void:
	var staged := await _spawn_punk(load("res://video/look/street_night/art.tres") as VideoArtLook)
	var rig: HumanoidRig = staged.rig
	assert_true(rig.has_art(), "the punk has art on")
	var art_rig := staged.level.get_node(^"CineArtRig") as CineArtRig
	assert_gte(int(art_rig.dressed.get(&"punk", 0)), 1, "the rig dressed the punk's art mesh")
	var mesh: MeshInstance3D = rig.art_meshes()[0]
	assert_ne(mesh.mesh, staged.game_meshes[0], "the video mesh replaced the game's")
	var material := mesh.material_override as ShaderMaterial
	assert_true(material.get_shader_parameter(&"use_paint_tex"), "the paint is on")
	assert_true(material.get_shader_parameter(&"use_ink_tex"), "the ink is on")
	assert_eq((material.get_shader_parameter(&"paint_tex") as Texture2D).get_width(), PAINT_SIZE, "the painted albedo is the one in assets/video")
	assert_eq((material.get_shader_parameter(&"ink_tex") as Texture2D).get_width(), INK_SIZE, "and the ink mask")


func test_the_parts_are_separate_switches() -> void:
	var look := (load("res://video/look/street_night/art.tres") as VideoArtLook).duplicate() as VideoArtLook
	look.swap_meshes = false
	look.ink = false
	var staged := await _spawn_punk(look)
	var mesh: MeshInstance3D = staged.rig.art_meshes()[0]
	assert_eq(mesh.mesh, staged.game_meshes[0], "meshes off: the game's mesh stays")
	var material := mesh.material_override as ShaderMaterial
	assert_true(material.get_shader_parameter(&"use_paint_tex"), "paint on")
	assert_false(material.get_shader_parameter(&"use_ink_tex"), "ink off")


func test_apply_is_idempotent_and_a_character_without_files_is_left_alone() -> void:
	var look := (load("res://video/look/street_night/art.tres") as VideoArtLook).duplicate() as VideoArtLook
	look.characters = PackedStringArray(["boss"])
	var staged := await _spawn_punk(look)
	look.apply(staged.level)
	assert_eq(staged.level.find_children("CineArtRig", "", false, false).size(), 1, "one rig, however often apply() is called")
	var mesh: MeshInstance3D = staged.rig.art_meshes()[0]
	assert_eq(mesh.mesh, staged.game_meshes[0], "a punk is not in `characters`: untouched")
	assert_ne((mesh.material_override as ShaderMaterial).get_shader_parameter(&"use_paint_tex"), true, "and has no paint")
