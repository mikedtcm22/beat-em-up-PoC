extends GutTest
## Milestone 6 DRESS: the level, the crowd street and the training room in the kit. No graybox box is drawn in the
## three scenes (the art draws, the colliders stay M5's: tests/test_m6_colliders.gd), a spawn doorway reads darker
## than the walls round it and nothing dressing overhangs into a spawn, each section has its own light and the
## level blends to it over Tuning's `section_light_blend_s`, and LookPost leaves the sun to it.

const LookProfileHelper := preload("res://tests/look_profile_helper.gd")
const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const CROWD_PATH := "res://game/level/crowd_room.tscn"
const TRAINING_PATH := "res://game/level/test_room.tscn"
const LAYOUT_PATH := "res://assets/source/kit/trim_layout.json"
const SECTION_PATHS: Array[String] = [
	"res://game/level/mission1/street.tscn",
	"res://game/level/mission1/roofs.tscn",
	"res://game/level/mission1/boss_roof.tscn",
]
## The dressing pieces a spawn doorway may carry: the frame round the opening, a roller shutter and its housing.
const DOORWAY_PIECES: Array[StringName] = [&"door_frame", &"shutter", &"housing"]
const ALLOWED_NODE_NAMES: Array[String] = ["ToonWarmUp", "FlashWarmUp", "EdgeQuad"]
const SETTLE_FRAMES := 4
const PROPS_PALETTE_PATH := "res://assets/source/palette/props.json"
const CAR_SLOT := 60
## The characters' main hues (degrees): the Punk's teal, the player's blue, the dummy's, the veteran's and Ox's
## orange, the veteran's violet and the Bruiser's purple, the Kicker's lime, the Thug's olive and yellow.
const FIGHTER_HUES_DEG: Array[float] = [180.0, 215.0, 28.0, 280.0, 75.0, 60.0, 50.0]


func before_each() -> void:
	LookProfileHelper.use_m6()


func after_each() -> void:
	LookProfileHelper.restore()
	Tuning.data.section_light_blend_s = 2.5
	Tuning.data.section_light_enabled = true
	Tuning.data.section_fog_sky_affect = TuningData.new().section_fog_sky_affect


# --- No graybox box ---------------------------------------------------------------------------------


func test_the_level_draws_no_graybox_box() -> void:
	var root := await _build(LEVEL_PATH)
	assert_eq(_boxes(root), 0, "no visible BoxMesh or PrimitiveMesh in Mission 1")
	assert_gt(_count(root, &"KitPiece"), 60, "the dressing's pieces draw")


func test_the_crowd_street_draws_no_graybox_box() -> void:
	var room := await _build(CROWD_PATH)
	assert_eq(_boxes(room), 0, "no visible BoxMesh or PrimitiveMesh in the crowd street")
	var spots := room.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n is PropSpot)
	assert_eq(spots.size(), 2, "the car and the dumpster are prop spots")
	for spot: PropSpot in spots:
		assert_not_null(spot.art, "%s draws PROPS's scene" % spot.prop_id)


func test_the_training_room_draws_no_graybox_box() -> void:
	var room := await _build(TRAINING_PATH)
	assert_eq(_boxes(room), 0, "no visible BoxMesh or PrimitiveMesh in the training room")


func test_a_prop_spot_stands_for_each_pinned_prop() -> void:
	var ids: Dictionary = {}
	for path: String in SECTION_PATHS:
		var section := (load(path) as PackedScene).instantiate() as LevelSection
		add_child_autofree(section)
		for node: Node in section.find_children("*", "Node3D", true, false):
			var spot := node as PropSpot
			if spot != null:
				ids[spot.prop_id] = true
				assert_ne(spot.size, Vector3.ZERO, "%s has a size" % spot.name)
	for id: StringName in [&"car", &"dumpster", &"ac_unit", &"water_tank"]:
		assert_true(ids.has(id), "a '%s' spot is placed in the level" % id)


func test_the_prop_fallbacks_stay_in_the_bibles_band_and_the_crowd_street_hulls_its_props() -> void:
	for id: StringName in PropSpot.PROPS:
		var color: Color = PropSpot.PROPS[id].color
		assert_lte(color.s, 0.305, "%s's fallback colour: saturation at most 0.30" % id)
		assert_between(color.v, 0.245, 0.605, "%s's fallback colour: value" % id)
	var room := await _build(CROWD_PATH)
	var overlays := 0
	for node: Node in room.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.get_parent() is StaticBody3D and mesh_node.material_overlay != null:
			overlays += 1  # a crate module's hull
		if mesh_node.get_parent() is StaticArt and mesh_node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			# (a shadow-only twin draws nothing, so it has no hull)
			assert_not_null(mesh_node.material_overlay, "%s draws the prop hull" % mesh_node.name)
	assert_eq(overlays, (room as CrowdRoom).crate_positions.size(), "each crate module wears the prop hull on its overlay")


## The props' own slots of the shared atlas (assets/source/palette/props.json, 60-63) hold the look bible's
## environment band: saturation at most 0.30, value 0.25-0.6 (final review, world-03). The test reads the drawn
## pixels of the atlas and the source file, not the fallback boxes' colours (which never draw).
func test_the_props_atlas_swatches_stay_in_the_bibles_band_and_the_car_is_off_every_fighters_hue() -> void:
	var atlas := (load("res://assets/export/palette/palette_atlas.png") as Texture2D).get_image()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROPS_PALETTE_PATH))
	var swatches: Array = source.swatches
	assert_eq(swatches.size(), 4, "props.json holds slots 60 to 63")
	for entry: Dictionary in swatches:
		var slot := int(entry.slot)
		var color := atlas.get_pixel((slot % 32) * 8 + 4, (slot / 32) * 8 + 4)
		assert_eq(color.to_html(false), String(entry.srgb).trim_prefix("#"), "%s: the atlas draws props.json's colour" % entry.name)
		assert_lte(color.s, 0.305, "%s: saturation at most 0.30" % entry.name)
		assert_between(color.v, 0.245, 0.605, "%s: value 0.25-0.6" % entry.name)
		assert_false(color.s > 0.5 and (color.h > 0.958 or color.h < 0.042), "%s is not in the red band" % entry.name)
	var car := atlas.get_pixel((CAR_SLOT % 32) * 8 + 4, (CAR_SLOT / 32) * 8 + 4)
	for fighter_hue_deg: float in FIGHTER_HUES_DEG:
		var apart := absf(fposmod(car.h * 360.0 - fighter_hue_deg + 180.0, 360.0) - 180.0)
		assert_gt(apart, 30.0, "the car's hue is at least 30 degrees from the fighter hue %.0f" % fighter_hue_deg)


func test_the_arena_tour_act_lists_every_section() -> void:
	var acts := load("res://tests/bot/level_acts/tour_acts.gd") as GDScript
	var poses: Array = acts.get(&"POSES")
	assert_gt(poses.size(), 15, "the tour has its poses")
	var sections: Dictionary = {}
	for pose: Dictionary in poses:
		sections[int(pose.section)] = true
	assert_eq(sections.keys().size(), 3, "street, roofs and boss roof")


func test_the_skyline_blocks_are_facades() -> void:
	for path: String in SECTION_PATHS:
		var section := (load(path) as PackedScene).instantiate() as LevelSection
		add_child_autofree(section)
		var found := 0
		for block: LevelBlock in section.blocks():
			var lowered := String(block.name).to_lower()
			if lowered.begins_with("skyline") or lowered.begins_with("block") or lowered.begins_with("lowblock"):
				found += 1
				assert_eq(block.module, &"skyline", "%s/%s is a skyline facade" % [section.name, block.name])
		assert_gt(found, 0, "%s has skyline blocks" % section.name)


func test_every_section_names_its_ambience_and_has_a_light() -> void:
	var beds: Dictionary = {}
	for path: String in SECTION_PATHS:
		var section := (load(path) as PackedScene).instantiate() as LevelSection
		add_child_autofree(section)
		assert_true(section.light_enabled, "%s has its own light" % section.name)
		assert_ne(section.ambience, &"", "%s names its bed" % section.name)
		beds[section.name] = section.ambience
	assert_eq(beds["Street"], &"ambience_street")
	assert_eq(beds["Roofs"], &"ambience_roof")
	assert_eq(beds["BossRoof"], &"ambience_roof")


# --- Doorways ---------------------------------------------------------------------------------------


func test_the_dark_strip_is_darker_than_every_wall_strip() -> void:
	var strips := _strip_values()
	for wall: String in ["brick", "plaster", "concrete", "facade"]:
		assert_lt(strips["dark"], strips[wall] - 0.08, "the doorway interior (dark) is darker than %s" % wall)
	assert_lt(strips["shutter"], strips["brick"] + 0.03, "a roller shutter in a doorway is no lighter than the brick")


func test_nothing_overhangs_into_a_spawn_and_doorways_keep_a_dark_back() -> void:
	var level := await _build(LEVEL_PATH) as LevelRoot
	var spawns: Array[SpawnPoint] = []
	for node: Node in level.find_children("*", "Marker3D", true, false):
		if node is SpawnPoint:
			spawns.append(node)
	assert_gt(spawns.size(), 15, "the level's spawn points")
	for spawn in spawns:
		var at := spawn.global_position + Vector3.UP * 0.9
		for node: Node in level.find_children("*", "Node3D", true, false):
			var spot := node as PropSpot
			if spot != null:
				var box := _spot_box(spot)
				assert_false(box.has_point(at), "%s is not over spawn %s" % [spot.name, spawn.name])
			var piece := node as KitPiece
			if piece != null and not DOORWAY_PIECES.has(piece.kind):
				var world := AABB(piece.global_position - piece.size * 0.5, piece.size)
				assert_false(world.has_point(at), "%s (%s) is not over spawn %s" % [piece.name, piece.kind, spawn.name])
		if spawn.tag == &"doorway":
			var darks := 0
			for block: LevelBlock in level.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n is LevelBlock):
				if block.look == &"dark" and block.global_position.distance_to(spawn.global_position) < 5.0:
					darks += 1
			assert_gt(darks, 0, "doorway %s has a dark back and jambs" % spawn.name)


func test_the_rooms_doorways_are_dark_modules() -> void:
	var room := await _build(CROWD_PATH)
	var dark := 0
	for body: Node in room.get_node("Geometry").get_children():
		for child: Node in body.get_children():
			var mesh_node := child as MeshInstance3D
			if mesh_node != null and mesh_node.mesh is ArrayMesh:
				var box := (mesh_node.mesh as ArrayMesh).get_aabb().size
				if absf(box.x - (room.get(&"door_width") as float)) < 0.01:
					dark += 1
	assert_gt(dark, 2, "the crowd street's doorway recesses draw as modules")


# --- Section light ----------------------------------------------------------------------------------


func test_the_sections_light_the_level_differently() -> void:
	var lights: Array[Dictionary] = []
	for path: String in SECTION_PATHS:
		var section := (load(path) as PackedScene).instantiate() as LevelSection
		add_child_autofree(section)
		lights.append(section.light())
	assert_ne(lights[0].sun_color, lights[1].sun_color, "the roofs' sun is another colour than the street's")
	assert_lt(lights[1].sun_elevation, lights[0].sun_elevation, "the roofs' sun is lower")
	assert_lt((lights[2].fog_color as Color).v, (lights[0].fog_color as Color).v, "the boss roof's fog is darker (a drop with depth)")


func test_adjacent_sections_keep_their_sun_close_so_the_blend_does_not_sweep_the_shadows() -> void:
	var lights: Array[Dictionary] = []
	for path: String in SECTION_PATHS:
		var section := (load(path) as PackedScene).instantiate() as LevelSection
		add_child_autofree(section)
		lights.append(section.light())
	for k in lights.size() - 1:
		var turn := absf(fposmod(float(lights[k + 1].sun_yaw) - float(lights[k].sun_yaw) + 180.0, 360.0) - 180.0)
		assert_lte(turn, 12.0, "sections %d and %d: the sun's yaw differs by at most 12 degrees (%.0f)" % [k, k + 1, turn])
	for light: Dictionary in lights:
		assert_gte(float(light.sun_elevation), 35.0, "a sun at 35 degrees or more: the player's own shadow stays short")


func test_the_fog_lets_the_dusk_sky_show_in_every_room_and_the_level_keeps_it_live() -> void:
	assert_lt(Tuning.data.section_fog_sky_affect, 0.6, "the fog does not paint the whole sky its own colour")
	for path: String in [CROWD_PATH, TRAINING_PATH, LEVEL_PATH]:
		var room := await _build(path)
		var world := room.get_node("WorldEnvironment") as WorldEnvironment
		assert_almost_eq(world.environment.fog_sky_affect, Tuning.data.section_fog_sky_affect, 0.0001, "%s: the fog's cover of the sky is Tuning's" % path)
	var level := (await _build(LEVEL_PATH)) as LevelRoot
	Tuning.data.section_fog_sky_affect = 0.8
	await _ticks(2)
	assert_almost_eq((level.get_node("WorldEnvironment") as WorldEnvironment).environment.fog_sky_affect, 0.8, 0.0001, "the level follows the F1 panel")
	Tuning.data.section_fog_sky_affect = TuningData.new().section_fog_sky_affect


func test_a_section_without_a_light_of_its_own_defaults_to_the_rooms_fog_and_sky() -> void:
	var section := LevelSection.new()
	add_child_autofree(section)
	assert_eq(section.fog_color, RoomKit.DEFAULT_FOG_COLOR)
	assert_eq(section.fog_density, RoomKit.DEFAULT_FOG_DENSITY)
	assert_eq(section.sky_top_color, RoomKit.DEFAULT_SKY_TOP)
	assert_eq(section.sky_horizon_color, RoomKit.DEFAULT_SKY_HORIZON)


func test_the_light_blends_over_the_tuned_time() -> void:
	Tuning.data.section_light_blend_s = 1.0
	var level := LevelRoot.new()
	level.section_paths = PackedStringArray(SECTION_PATHS)
	level.with_presentation = false
	add_child_autofree(level)
	await _ticks(SETTLE_FRAMES)
	var street := level.sections[0].light()
	assert_eq(level.current_section(), level.sections[0], "the level starts in the street")
	assert_eq(level.current_light().sun_color, street.sun_color, "the first light is snapped")
	var sun := level.get_node("Sun") as DirectionalLight3D
	assert_eq(sun.light_color, street.sun_color, "the sun wears the street's colour")
	# Walk into the roofs: put the player on the roofs' last route point.
	var route := level.sections[1].route_points()
	level.player.global_position = route[route.size() - 1]
	await _ticks(2)
	assert_eq(level.current_section(), level.sections[1], "the roofs are entered")
	var roofs := level.sections[1].light()
	assert_lt(level.section_light_progress(), 0.2, "the blend has just begun")
	await _ticks(30)
	var half := level.section_light_progress()
	assert_between(half, 0.35, 0.65, "half a blend after half the time (%f)" % half)
	var mid: Color = level.current_light().sun_color
	assert_ne(mid, street.sun_color, "the sun is on its way")
	assert_ne(mid, roofs.sun_color, "and has not arrived")
	await _ticks(40)
	assert_eq(level.section_light_progress(), 1.0, "the blend is done after the tuned time")
	assert_eq(sun.light_color, roofs.sun_color, "the sun wears the roofs' colour")
	assert_almost_eq(sun.rotation_degrees.x, -float(roofs.sun_elevation), 0.01, "at the roofs' height")
	var world := level.get_node("WorldEnvironment") as WorldEnvironment
	assert_eq(world.environment.fog_light_color, roofs.fog_color, "and the roofs' fog")


func test_a_blend_of_zero_snaps() -> void:
	Tuning.data.section_light_blend_s = 0.0
	var level := LevelRoot.new()
	level.section_paths = PackedStringArray(SECTION_PATHS)
	level.with_presentation = false
	add_child_autofree(level)
	await _ticks(SETTLE_FRAMES)
	var route := level.sections[2].route_points()
	level.player.global_position = route[route.size() - 1]
	await _ticks(2)
	assert_eq(level.section_light_progress(), 1.0, "no blend")
	assert_eq(level.current_light().sun_color, level.sections[2].light().sun_color)


func test_blend_light_takes_the_short_way_round_the_yaw() -> void:
	var a := {sun_yaw = 170.0, sun_energy = 1.0, sun_color = Color.WHITE}
	var b := {sun_yaw = -170.0, sun_energy = 2.0, sun_color = Color.BLACK}
	var mid := LevelRoot.blend_light(a, b, 0.5)
	assert_almost_eq(absf(float(mid.sun_yaw)), 180.0, 0.01, "through 180, not through 0")
	assert_almost_eq(float(mid.sun_energy), 1.5, 0.001)
	assert_almost_eq((mid.sun_color as Color).r, 0.5, 0.001)
	assert_eq(LevelRoot.blend_light(a, b, 1.0).sun_color, Color.BLACK)


func test_lookpost_leaves_the_sun_to_the_section() -> void:
	var level := LevelRoot.new()
	level.section_paths = PackedStringArray(SECTION_PATHS)
	level.with_presentation = false
	add_child_autofree(level)
	await _ticks(SETTLE_FRAMES)
	var sun := level.get_node("Sun") as DirectionalLight3D
	var energy := sun.light_energy
	assert_true(level.section_light_applies(), "the street has a light")
	var post := LookPost.new()
	level.add_child(post)
	await _ticks(2)
	var tuned := Tuning.data.look_sun_energy
	Tuning.data.look_sun_energy = 0.4
	Tuning.changed.emit(&"look_sun_energy")
	assert_almost_eq(sun.light_energy, energy, 0.001, "Tuning's sun energy does not override the section's")
	Tuning.data.section_light_enabled = false
	await _ticks(2)
	assert_false(level.section_light_applies(), "off: no section light")
	Tuning.changed.emit(&"look_sun_energy")
	assert_almost_eq(sun.light_energy, 0.4, 0.001, "with the section light off, Tuning's sun applies as in M5")
	Tuning.data.look_sun_energy = tuned
	Tuning.changed.emit(&"look_sun_energy")


func test_the_crowd_and_training_rooms_keep_tunings_sun() -> void:
	for path: String in [CROWD_PATH, TRAINING_PATH]:
		var room := await _build(path)
		var sun := room.get_node("Sun") as DirectionalLight3D
		assert_almost_eq(sun.light_energy, Tuning.data.look_sun_energy, 0.001, "%s keeps Tuning's sun" % path)
		assert_eq(sun.light_color, Color.WHITE)


# --- Helpers ----------------------------------------------------------------------------------------


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _build(path: String) -> Node:
	var root := (load(path) as PackedScene).instantiate()
	if "with_presentation" in root:
		root.set(&"with_presentation", false)
	if "waves_enabled_on_start" in root:
		root.set(&"waves_enabled_on_start", false)
	add_child_autofree(root)
	await _ticks(SETTLE_FRAMES)
	return root


func _count(root: Node, script_name: StringName) -> int:
	var n := 0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var script := node.get_script() as Script
		if script != null and script.get_global_name() == script_name:
			n += 1
	return n


## Visible primitive meshes outside the actors, the weapons, the edge guards and the allowed nodes.
func _boxes(root: Node) -> int:
	var n := 0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if not (mesh_instance.mesh is PrimitiveMesh) or not mesh_instance.is_visible_in_tree():
			continue
		if (mesh_instance.layers & (1 << (CombatTypes.VIS_DEFAULT - 1))) == 0:
			continue
		var skip := false
		var cursor: Node = node
		while cursor != null and cursor != root:
			if cursor is CombatActor or cursor is Weapon or cursor is EdgeGuard or ALLOWED_NODE_NAMES.has(String(cursor.name)):
				skip = true
				break
			cursor = cursor.get_parent()
		if not skip:
			n += 1
	return n


## A prop spot's footprint box in world space (stands on the floor at its middle; yaw is a multiple of 90).
func _spot_box(spot: PropSpot) -> AABB:
	var size := spot.box_size()
	var turned := absf(sin(spot.global_rotation.y)) > 0.7
	var extent := Vector3(size.z, size.y, size.x) if turned else size
	return AABB(spot.global_position + Vector3(-extent.x * 0.5, 0.0, -extent.z * 0.5), extent)


## The mean value (HSV v) of each strip's colours in the trim layout.
func _strip_values() -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	var out := {}
	for strip: Dictionary in parsed.strips:
		var total := 0.0
		var hsv: Dictionary = strip.hsv
		for key: String in hsv:
			total += float((hsv[key] as Array)[2])
		if not hsv.is_empty():
			out[strip.name] = total / float(hsv.size())
	return out
