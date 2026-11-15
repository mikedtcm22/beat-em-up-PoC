extends GutTest
## Milestone 7, G4: the painted light shapes and the far street. Under the trailer profile the lit windows are never one rectangle
## repeated (a seeded size, offset, tilt and mullion each), the far facades get a painted wash, the steam wisp is outlined as the
## plume is, no light shape melts (the shaders carry no Gaussian falloff), and the crowd room and the training room get the night
## look the street has (lamps, pools, a painted sky) while m6 gets none of it. And the bot's arms act exists.

const LookProfileHelper := preload("res://tests/look_profile_helper.gd")
const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const CROWD_PATH := "res://game/level/crowd_room.tscn"
const TEST_ROOM_PATH := "res://game/level/test_room.tscn"
const SHAPE_SHADERS: Array[String] = [
	"res://game/fx/light_pool.gdshader", "res://game/fx/street_pool.gdshader", "res://game/fx/haze_halo.gdshader",
	"res://game/fx/haze_band.gdshader", "res://game/fx/light_shaft.gdshader", "res://game/fx/skyline_wash.gdshader",
	"res://game/fx/window_glow.gdshader",
]


func before_each() -> void:
	Tuning.reset_to_default()
	LookProfileHelper.use_m6()
	Tuning.set_value(&"waves_enabled", false)


func after_each() -> void:
	Tuning.reset_to_default()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _build(path: String) -> Node:
	var root := (load(path) as PackedScene).instantiate()
	if "waves_enabled_on_start" in root:
		root.set(&"waves_enabled_on_start", false)
	add_child_autofree(root)
	await _ticks(4)
	return root


func test_windows_are_never_one_rectangle_repeated() -> void:
	var level := await _build(LEVEL_PATH)
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _ticks(3)
	var street := (level.get_node("TrailerLook") as TrailerLook).streets()[0]
	var cards: Array[MeshInstance3D] = []
	for node: Node in street.find_children("WindowGlow*", "MeshInstance3D", false, false):
		cards.append(node as MeshInstance3D)
	assert_true(cards.size() >= 4, "windows are lit")
	var sizes := {}
	var tilts := {}
	var seeds := {}
	for card in cards:
		sizes[snappedf((card.mesh as QuadMesh).size.x, 0.001)] = true
		tilts[snappedf(card.rotation.z, 0.001)] = true
		seeds[(card.material_override as ShaderMaterial).get_shader_parameter(&"seed")] = true
	assert_true(sizes.size() > cards.size() / 2, "the cards differ in width")
	assert_true(tilts.size() > cards.size() / 2, "and in tilt")
	assert_eq(seeds.size(), cards.size(), "each card has a seed of its own, for its corners and strokes")
	var material := cards[0].material_override as ShaderMaterial
	assert_true(float(material.get_shader_parameter(&"mullion")) > 0.0, "a mullion stroke")
	assert_true(float(material.get_shader_parameter(&"uneven")) > 0.0, "an uneven quad")


func test_the_far_facades_get_a_painted_wash_and_m6_none() -> void:
	var level := await _build(LEVEL_PATH)
	var street: Node = level.sections[0]
	assert_eq(street.find_children("SkylineWash*", "MeshInstance3D", true, false).size(), 0, "m6: no wash")
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _ticks(3)
	var washes: Array[Node] = street.find_children("SkylineWash*", "MeshInstance3D", true, false)
	assert_eq(washes.size(), 3, "one per skyline block (left, right, far)")
	for node: Node in washes:
		var material := (node as MeshInstance3D).material_override as ShaderMaterial
		assert_true(material.get_shader_parameter(&"cover") > 0.0)
	Tuning.set_value(&"look_profile", LookProfile.Id.M6)
	await _ticks(3)
	assert_eq(street.find_children("SkylineWash*", "MeshInstance3D", true, false).size(), 0, "gone again")


func test_the_wisp_is_outlined_like_the_plume() -> void:
	var level := await _build(LEVEL_PATH)
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _ticks(3)
	var fx := level.find_child("StreetFx", true, false) as StreetFx
	assert_not_null(fx)
	var wisp_lines := 0
	var plumes := 0
	for material in fx.materials():
		if material.shader.resource_path.ends_with("street_steam.gdshader"):
			if float(material.get_shader_parameter(&"light_alpha")) == Tuning.data.tfx_wisp_alpha:
				assert_true(float(material.get_shader_parameter(&"line_share")) > 0.5, "the wisp has a line")
				assert_true(float(material.get_shader_parameter(&"min_line_px")) > 0.0, "that stays visible far away")
				wisp_lines += 1
			else:
				plumes += 1
	assert_true(wisp_lines >= 1 and plumes >= 1, "both kinds exist")


func test_no_light_shape_melts() -> void:
	for path in SHAPE_SHADERS:
		var code := (load(path) as Shader).code
		# A smoothstep over a whole radius (a Gaussian-like falloff) is what the shapes avoid: every smoothstep edge is a few pixels
		# (fwidth), a tunable's small share, or a noise-bitten step. The pool shaders have no falloff term at all.
		assert_false(code.contains("exp(-"), "%s has no exponential falloff" % path)
	var pool := (load("res://game/fx/light_pool.gdshader") as Shader).code
	assert_true(pool.contains("cover(f_wash") and pool.contains("cover(f_mid") and pool.contains("cover(f_core"), "three stepped tones")


func test_rooms_get_the_night_look_only_under_trailer() -> void:
	for path in [CROWD_PATH, TEST_ROOM_PATH]:
		var room := await _build(path)
		var look := room.find_child("TrailerLook", false, false) as TrailerLook
		assert_not_null(look, "%s hangs the look layer" % path)
		assert_false(look.is_active(), "m6: nothing built")
		assert_eq(look.streets().size(), 0)
		Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
		await _ticks(3)
		assert_true(look.is_active(), "trailer: the layer is on")
		assert_eq(look.streets().size(), 1, "the room is one dressed street")
		assert_eq(look.streets()[0].lights().size(), TrailerLook.ROOM_LOOK.lamps.size(), "a light per lamp")
		assert_not_null(look.sky_material(), "the painted sky")
		var env := (room.get_node("WorldEnvironment") as WorldEnvironment).environment
		assert_eq(env.fog_light_color, TrailerLook.ROOM_LOOK.fog_color, "the night's fog")
		Tuning.set_value(&"look_profile", LookProfile.Id.M6)
		await _ticks(3)
		assert_false(look.is_active())
		assert_eq(env.fog_light_color, RoomKit.DEFAULT_FOG_COLOR, "and back to the room's own fog")
		room.queue_free()
		await _ticks(2)


func test_the_crowd_rooms_windows_are_lit_with_cards_of_their_own() -> void:
	var room := await _build(CROWD_PATH)
	Tuning.set_value(&"look_profile", LookProfile.Id.TRAILER)
	await _ticks(3)
	var street := (room.find_child("TrailerLook", false, false) as TrailerLook).streets()[0]
	assert_true(street.find_children("WindowGlow*", "MeshInstance3D", false, false).size() >= 3, "the plain-mesh windows are found by their meta")
	assert_true(street.find_children("SkylineWash*", "MeshInstance3D", false, false).size() >= 1, "and the backdrop blocks are washed")


func test_the_arms_act_is_a_bot_act() -> void:
	var acts_script := load("res://tests/bot/g4_arms_acts.gd") as GDScript
	var acts: Array[Dictionary] = acts_script.call(&"acts", null)
	assert_eq(acts.size(), 1)
	assert_true(String(acts[0].title).begins_with("G4"))
	assert_eq(acts[0].cam, &"first_person")
	var bot := load("res://tests/bot/g4_arms_bot.gd") as GDScript
	assert_not_null(bot)
