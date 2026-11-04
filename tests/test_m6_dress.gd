extends GutTest
## Milestone 6 DRESS: the level, the crowd street and the training room in the kit. No graybox box is drawn in the
## three scenes (the art draws, the colliders stay M5's: tests/test_m6_colliders.gd), a spawn doorway reads darker
## than the walls round it and nothing dressing overhangs into a spawn, each section has its own light and the
## level blends to it over Tuning's `section_light_blend_s`, and LookPost leaves the sun to it.

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


func after_each() -> void:
	Tuning.data.section_light_blend_s = 2.5
	Tuning.data.section_light_enabled = true


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
