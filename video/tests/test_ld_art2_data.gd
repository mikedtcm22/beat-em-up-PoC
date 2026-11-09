extends GutTest
## LD-ART2's cast (docs/video/P1.md, round 3), headless: the maps have no holes where the meshes are (the Gate 2 finding: pure #000000 on a
## quarter of the first-person arm and Ox's glove cuffs), the player has a video mesh that obeys the art contract, the skin is warm, the
## faces carry their zone and catchlights, and the rig dresses a punk with the round 2 settings (no plastic sheen, no decals, no game mask).

const ART_DIR := "res://assets/video/characters"
const IDS: Array[StringName] = [&"punk", &"boss", &"player"]
## Triangles sampled at their UV2 centroid that may still be empty (the slivers a 3D-degenerate triangle leaves): well under 1%.
const MAX_BAD_SHARE := 0.005
const SOURCE_DIR := "res://assets/source/video_art"


func _image(path: String) -> Image:
	return (load(path) as Texture2D).get_image()


## The game's own art of `id` with its scene (the player's .tres names it only in metadata).
func _game_art(id: StringName) -> CharacterArt:
	var art := (load("res://game/actors/art/%s_art.tres" % id) as CharacterArt).duplicate() as CharacterArt
	if art.scene == null and art.has_meta(&"scene_path"):
		art.scene = load(String(art.get_meta(&"scene_path"))) as PackedScene
	return art


func _video_meshes(id: StringName) -> Array[ArrayMesh]:
	var out: Array[ArrayMesh] = []
	var base := _game_art(id)
	var video := base.duplicate() as CharacterArt
	video.scene = load("%s/%s/%s_video.glb" % [ART_DIR, id, id]) as PackedScene
	video.triangle_budget = 250000
	for part: SkinnedArt.ArtMesh in SkinnedArt.entry_of(video).meshes:
		out.append(part.mesh)
	return out


## The share of the triangles of `id`'s video meshes whose UV2 centroid has no paint (alpha under half) or pure black paint.
func _bad_share(id: StringName) -> Dictionary:
	var paint := _image("%s/%s/%s_paint.png" % [ART_DIR, id, id])
	var width := paint.get_width()
	var triangles := 0
	var empty := 0
	var black := 0
	for mesh in _video_meshes(id):
		var arrays := mesh.surface_get_arrays(0)
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in range(0, indices.size(), 3):
			var c := (uv2[indices[t]] + uv2[indices[t + 1]] + uv2[indices[t + 2]]) / 3.0
			var pixel := paint.get_pixel(clampi(int(c.x * width), 0, width - 1), clampi(int(c.y * width), 0, width - 1))
			triangles += 1
			if pixel.a < 0.5:
				empty += 1
			elif maxf(pixel.r, maxf(pixel.g, pixel.b)) < 0.02:
				black += 1
	return {triangles = triangles, empty = empty, black = black}


func test_no_triangle_of_any_character_samples_an_empty_or_black_texel() -> void:
	for id in IDS:
		var stats := _bad_share(id)
		assert_gt(int(stats.triangles), 1000, "%s: has triangles to sample" % id)
		assert_lt(float(stats.empty) / float(stats.triangles), MAX_BAD_SHARE, "%s: the maps have no empty texels inside the mesh's UV2 islands (%d of %d)" % [id, stats.empty, stats.triangles])
		assert_lt(float(stats.black) / float(stats.triangles), 0.001, "%s: and no pure black paint under the mesh (%d of %d)" % [id, stats.black, stats.triangles])


func test_the_bake_reports_no_empty_and_no_black_texels_in_the_islands() -> void:
	for id in IDS:
		var file := FileAccess.open("%s/%s/coverage.json" % [SOURCE_DIR, id], FileAccess.READ)
		assert_not_null(file, "%s has its bake's coverage report" % id)
		if file == null:
			continue
		var stats := JSON.parse_string(file.get_as_text()) as Dictionary
		assert_eq(int(stats.empty_texels_in_islands), 0, "%s: every island texel has paint" % id)
		assert_eq(int(stats.pure_black_texels_in_islands), 0, "%s: none of it is #000000" % id)


func test_the_paint_pads_the_islands_and_fills_the_rest_with_the_mean_colour() -> void:
	for id in IDS:
		var paint := _image("%s/%s/%s_paint.png" % [ART_DIR, id, id])
		var empty := 0
		var wrong := 0
		for y in range(0, paint.get_height(), 17):
			for x in range(0, paint.get_width(), 17):
				var pixel := paint.get_pixel(x, y)
				if pixel.a < 0.5:
					empty += 1
					# Where nothing is mapped the colour is the mean, never black (a mip level blends toward it).
					if maxf(pixel.r, maxf(pixel.g, pixel.b)) < 0.02:
						wrong += 1
		assert_gt(empty, 100, "%s: the atlas has unmapped texels to look at" % id)
		assert_eq(wrong, 0, "%s: none of the unmapped texels is black" % id)


func test_the_players_video_mesh_obeys_the_art_contract_and_the_layout_is_clean() -> void:
	var base := _game_art(&"player")
	var video := base.duplicate() as CharacterArt
	video.scene = load("%s/player/player_video.glb" % ART_DIR) as PackedScene
	video.triangle_budget = 250000
	assert_eq(SkinnedArt.check(video), PackedStringArray(), "the player's video GLB breaks no part of the art contract")
	var meshes := _video_meshes(&"player")
	assert_eq(meshes.size(), SkinnedArt.entry_of(base).meshes.size(), "the same four meshes")
	for mesh in meshes:
		var arrays := mesh.surface_get_arrays(0)
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		for uv in uv2:
			assert_true(uv.x >= -0.0001 and uv.x <= 1.0001 and uv.y >= -0.0001 and uv.y <= 1.0001, "UV2 stays inside the atlas")
			if uv.x < -0.0001 or uv.x > 1.0001 or uv.y < -0.0001 or uv.y > 1.0001:
				break


func test_the_players_skin_is_warm_and_not_saturated() -> void:
	var file := FileAccess.open("%s/player/paint.json" % SOURCE_DIR, FileAccess.READ)
	var cfg := JSON.parse_string(file.get_as_text()) as Dictionary
	for key in ["base", "light"]:
		var rgb: Array = cfg.materials["7"][key]
		var colour := Color(rgb[0], rgb[1], rgb[2])
		assert_between(colour.h * 360.0, 12.0, 40.0, "the skin's %s is orange-tan, not pink or red" % key)
		assert_lt(colour.s, 0.45, "the skin's %s is not saturated (%.2f)" % [key, colour.s])


func test_the_ink_maps_carry_the_face_zone_and_the_catchlights() -> void:
	for id in [&"punk", &"boss"]:
		var ink := _image("%s/%s/%s_ink.png" % [ART_DIR, id, id])
		ink.resize(512, 512, Image.INTERPOLATE_BILINEAR)
		var face := 0
		var catch_light := 0
		for y in 512:
			for x in 512:
				var pixel := ink.get_pixel(x, y)
				face += 1 if pixel.b > 0.5 else 0
				catch_light += 1 if pixel.a > 0.08 else 0
		assert_gt(face, 40, "%s: a face zone for the shader's fill" % id)
		assert_lt(face, 20000, "%s: and only the face (%d)" % [id, face])
		assert_gt(catch_light, 0, "%s: drawn catchlights (an eye, a lens)" % id)
		assert_lt(catch_light, 500, "%s: and only a few" % id)
	var player := _image("%s/player/player_ink.png" % ART_DIR)
	player.resize(512, 512, Image.INTERPOLATE_BILINEAR)
	var zone := 0
	for y in 512:
		for x in 512:
			zone += 1 if player.get_pixel(x, y).b > 0.3 else 0
	assert_gt(zone, 100, "the player's arm skin and wraps have their warm fill zone")


func test_the_toon_shader_has_the_round_two_uniforms_and_the_paint_falls_back_to_the_swatch() -> void:
	var shader := load(CineArtRig.TOON_SHADER_PATH) as Shader
	var names: Array[String] = []
	for u: Dictionary in shader.get_shader_uniform_list():
		names.append(String(u.name))
	for want in ["face_fill", "face_fill_color", "catch_strength", "catch_color", "spec_gain", "marks_gain"]:
		assert_true(names.has(want), "cine_toon has %s" % want)
	assert_true(shader.code.contains("painted.a"), "the paint's alpha gates it: where it is 0 the swatch colour stays")


func _spawn_punk(look: VideoArtLook) -> HumanoidRig:
	var level := Node3D.new()
	add_child_autofree(level)
	var punk := (load("res://game/enemies/punk/street_punk.tscn") as PackedScene).instantiate() as Node3D
	level.add_child(punk)
	await wait_process_frames(2)
	var rig := punk.get(&"rig") as HumanoidRig
	look.apply(level)
	await wait_process_frames(3)
	return rig


func test_the_rig_dresses_a_character_without_plastic_sheen_decals_or_the_games_mask() -> void:
	var look := load("res://video/look/street_night/art.tres") as VideoArtLook
	var rig := await _spawn_punk(look)
	var material := rig.art_meshes()[0].material_override as ShaderMaterial
	assert_false(material.get_shader_parameter(&"use_detail_tex"), "the game's detail mask (its own UV2) is off: the video's layout is a new one")
	assert_almost_eq(float(material.get_shader_parameter(&"spec_gain")), look.plastic_spec, 0.0001, "the soft highlight is the look's")
	assert_almost_eq(float(material.get_shader_parameter(&"marks_gain")), look.damage_marks, 0.0001, "the damage decals are the look's")
	assert_almost_eq(float(material.get_shader_parameter(&"face_fill")), look.face_fill, 0.0001, "the face fill is set")
	assert_eq(look.plastic_spec, 0.0, "no plastic sheen by default")
	assert_eq(look.damage_marks, 0.0, "no sticker blood by default (logged in the calls file)")


func test_the_switches_bring_the_game_mask_and_the_decals_back() -> void:
	var look := (load("res://video/look/street_night/art.tres") as VideoArtLook).duplicate() as VideoArtLook
	look.game_detail_off = false
	look.damage_marks = 1.0
	var rig := await _spawn_punk(look)
	var material := rig.art_meshes()[0].material_override as ShaderMaterial
	assert_ne(material.get_shader_parameter(&"use_detail_tex"), false, "game_detail_off = false leaves the game's mask as it was")
	assert_almost_eq(float(material.get_shader_parameter(&"marks_gain")), 1.0, 0.0001, "the decals come back at 1")
