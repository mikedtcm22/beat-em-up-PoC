extends GutTest
## The crowd room (M3-plan P1-room): it builds, bakes a navmesh the spawn points sit on, hosts
## the player with an avoidance obstacle and auto-revive, keeps the presentation layer as direct
## children, and the F6 switch finds it from the training room and back.

const ROOM_PATH := "res://game/level/crowd_room.tscn"
const TRAINING_PATH := "res://game/level/test_room.tscn"
## The frames the navigation map needs to sync after a room's _ready() (godot-navigation codemap 4.1).
const SYNC_FRAMES := 5


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.set_value(&"waves_enabled", false)
	TimeController.clear()
	GameInput.menu_open = false


func after_each() -> void:
	GameInput.menu_open = false
	Tuning.reset_to_default()
	TimeController.clear()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _room(presentation: bool = false, frames: int = SYNC_FRAMES) -> CrowdRoom:
	var room := (load(ROOM_PATH) as PackedScene).instantiate() as CrowdRoom
	room.with_presentation = presentation
	room.waves_enabled_on_start = false
	add_child_autofree(room)
	await _ticks(frames)
	return room


func _map(room: CrowdRoom) -> RID:
	return room.get_world_3d().navigation_map


## The first world-layer hit along the segment, or {}.
func _ray(room: CrowdRoom, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, CombatTypes.bit(CombatTypes.LAYER_WORLD))
	return room.get_world_3d().direct_space_state.intersect_ray(query)


# --- The navmesh --------------------------------------------------------------------------


func test_the_map_syncs_by_physics_frame_3_and_the_mesh_has_polygons() -> void:
	var room := await _room(false, 3)
	assert_true(NavBaker.map_ready(room.get_world_3d()), "synced within 3 physics frames of _ready()")
	var mesh := room.nav_region.navigation_mesh
	assert_gt(mesh.get_polygon_count(), 20, "the street is walkable")
	assert_lt(mesh.get_polygon_count(), 120, "and the roofs, crates and walls are not")
	assert_lt(room.nav_bake_usec, 25000, "the bake is a few milliseconds (%d us)" % room.nav_bake_usec)


func test_no_polygon_floats_above_the_street() -> void:
	var room := await _room()
	var mesh := room.nav_region.navigation_mesh
	var verts := mesh.get_vertices()
	var top := -INF
	var low := INF
	for p in mesh.get_polygon_count():
		for index in mesh.get_polygon(p):
			top = maxf(top, verts[index].y)
			low = minf(low, verts[index].y)
	assert_lt(top, room.nav_max_floor_y, "no polygon on a roof or the curb (highest vertex %.2f)" % top)
	assert_gt(low, -0.05, "none below the floor either")


func test_every_spawn_point_is_on_the_navmesh_and_reaches_the_lane() -> void:
	var room := await _room()
	var map := _map(room)
	var points := room.spawn_point_list()
	assert_eq(points.size(), 7, "three doorways, three alleys and the car's far side")
	for point: Dictionary in points:
		var at: Vector3 = point.position
		var snapped := NavigationServer3D.map_get_closest_point(map, at)
		var off := Vector2(snapped.x - at.x, snapped.z - at.z).length()
		assert_lt(off, 0.3, "%s at %s snaps within 0.3 m (%.2f)" % [point.tag, at, off])
		var path := NavigationServer3D.map_get_path(map, snapped, Vector3.ZERO, true)
		assert_gt(path.size(), 1, "%s at %s has a path to the lane centre" % [point.tag, at])
		if path.size() > 1:
			var end := path[path.size() - 1]
			assert_lt(Vector2(end.x, end.z).length(), 0.5, "and it ends there")
		var lane: Vector3 = point.lane_point
		var lane_snap := NavigationServer3D.map_get_closest_point(map, lane)
		assert_lt(Vector2(lane_snap.x - lane.x, lane_snap.z - lane.z).length(), 0.3, "%s's lane point is walkable" % point.tag)


func test_the_spawn_points_are_where_the_plan_puts_them() -> void:
	var room := await _room()
	var tags := {}
	for point: Dictionary in room.spawn_point_list():
		tags[point.tag] = int(tags.get(point.tag, 0)) + 1
	assert_eq(tags, {&"doorway": 3, &"alley": 3, &"vehicle": 1})
	var vehicle: Dictionary = room.spawn_point_list().filter(func(p: Dictionary) -> bool: return p.tag == &"vehicle")[0]
	var car_far_side := room.car_position.z + room.car_size.z * 0.5
	assert_gt(vehicle.position.z, car_far_side, "behind the parked car, as seen from the lane")
	assert_almost_eq(vehicle.position.x, room.car_position.x, 0.01, "level with it")
	var behind := 0
	var player: PlayerCharacter = room.player
	for point: Dictionary in room.spawn_point_list():
		if player.is_outside_view(point.position, Tuning.data.rear_warning_angle_deg):
			behind += 1
	assert_gte(behind, 3, "with the default look, several points are behind or beside the player")


func test_a_navigation_agent_walks_from_a_doorway_to_the_lane() -> void:
	var room := await _room()
	var map := _map(room)
	var door: Dictionary = room.spawn_point_list()[2]  # the east doorway, behind the crates
	var path := NavigationServer3D.map_get_path(map, door.position, room.player_start, true)
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	assert_gt(length, door.position.distance_to(room.player_start) - 0.5, "a path, not a teleport")
	assert_lt(length, door.position.distance_to(room.player_start) * 1.8, "and not a long way round")


# --- The player and the layers ------------------------------------------------------------


func test_the_player_has_an_obstacle_and_auto_revive() -> void:
	var room := await _room()
	var player: PlayerCharacter = room.player
	assert_not_null(player)
	assert_true(player.auto_revive, "a KO'd player gets back up here")
	assert_true(player.is_in_group(&"player"))
	var obstacle: NavigationObstacle3D
	for child in player.get_children():
		if child is NavigationObstacle3D:
			obstacle = child
	assert_not_null(obstacle, "enemies steer around him")
	assert_almost_eq(obstacle.radius, Tuning.data.player_avoid_radius_m, 0.001)
	assert_almost_eq(obstacle.height, player.body_height, 0.001)
	assert_true(obstacle.avoidance_enabled)
	Tuning.set_value(&"player_avoid_radius_m", 0.8)
	assert_almost_eq(obstacle.radius, 0.8, 0.001, "live")
	assert_eq(player.global_position, room.player_start)
	assert_almost_eq(player.rotation.y, deg_to_rad(room.player_yaw_deg), 0.001, "facing +X")


func test_the_obstacle_leaves_room_to_close_to_a_strike() -> void:
	# Avoidance keeps an enemy player_avoid_radius_m + enemy_avoid_radius_m off the player. A
	# Punk's shove connects at 0.97 m and ENGAGE stops engage_margin_m inside that; with the
	# sum above it (the plan's 0.5 + 0.45) a real Punk stalls just short of its range, times out
	# and never attacks (found in the first recording of real enemies in this room).
	var closest := 0.97 - Tuning.data.engage_margin_m
	assert_lt(Tuning.data.player_avoid_radius_m + Tuning.data.enemy_avoid_radius_m, closest,
			"the avoidance floor is under the shortest strike an enemy closes to (%.2f m)" % closest)


func test_the_room_contract_for_bots_and_tests() -> void:
	var room := await _room()
	for property: StringName in [&"player", &"player_start", &"player_yaw_deg", &"with_presentation",
			&"waves_enabled_on_start", &"rng_seed", &"spawner", &"director"]:
		assert_true(property in room, "the room has %s" % property)
	assert_true(room.spawner is EncounterSpawner and room.spawner.get_parent() == room)
	assert_true(room.director is EnemyDirector and room.director.get_parent() == room)
	assert_eq(room.spawner.spawn_points.size(), 7, "the spawner has the room's points")
	assert_eq(room.enemies().size(), 0, "no enemies until a wave or an F4 spawn")
	var enemy := room.spawner.spawn_enemy(&"punk", Vector3(-6.0, 0.0, -3.0), 0.0)
	if enemy:
		assert_eq(room.enemies(), [enemy] as Array[EnemyActor], "enemies() lists the AI enemies")
		enemy.queue_free()


func test_waves_off_on_start_when_asked() -> void:
	Tuning.set_value(&"waves_enabled", true)
	await _room()
	assert_false(Tuning.data.waves_enabled, "waves_enabled_on_start = false turns them off")
	Tuning.set_value(&"waves_enabled", false)
	var room := (load(ROOM_PATH) as PackedScene).instantiate() as CrowdRoom
	room.with_presentation = false
	Tuning.set_value(&"waves_enabled", true)
	add_child_autofree(room)
	await _ticks(2)
	assert_true(Tuning.data.waves_enabled, "left alone when it is on")


func test_the_presentation_layer_is_made_of_direct_children() -> void:
	var room := await _room(true)
	var kinds := {}
	for child in room.get_children():
		for cls: String in ["CameraDirector", "GameHud", "TuningOverlay", "VfxDirector", "AudioDirector", "RumbleDirector",
				"EnemyDirector", "EncounterSpawner", "PlayerCharacter"]:
			if child.is_class(cls) or (child.get_script() and child.get_script().get_global_name() == cls):
				kinds[cls] = true
	for cls: String in ["CameraDirector", "GameHud", "TuningOverlay", "VfxDirector", "AudioDirector", "RumbleDirector",
			"EnemyDirector", "EncounterSpawner", "PlayerCharacter"]:
		assert_true(kinds.has(cls), "%s is a direct child of the room" % cls)
	assert_not_null(get_tree().get_first_node_in_group(&"debug_draw"), "F3's drawing is there")
	assert_true(room.find_children("*", "TuningOverlay", false, false).size() == 1)


func test_without_presentation_there_is_none() -> void:
	var room := await _room(false)
	assert_eq(room.find_children("*", "TuningOverlay", false, false).size(), 0)
	assert_eq(room.find_children("*", "CameraDirector", false, false).size(), 0)
	assert_not_null(room.player)


func test_waves_hold_while_the_f4_menu_is_open() -> void:
	Tuning.set_value(&"wave_gap_s", 0.1)
	Tuning.set_value(&"wave_spawn_interval_s", 0.05)
	var room := await _room(true)
	room.spawner.scene_override = {&"punk": preload("res://tests/fixtures/spawn_probe_enemy.tscn")}
	var overlay := room.find_children("*", "TuningOverlay", false, false)[0] as TuningOverlay
	overlay.set_cheats_open(true)
	assert_true(GameInput.menu_open, "F4 holds the fight")
	room.spawner.set_waves_enabled(true)
	await _ticks(90)
	assert_eq(room.enemies().size(), 0, "no wave starts behind the open menu")
	overlay.close_all()
	assert_false(GameInput.menu_open)
	await _ticks(60)
	assert_gt(room.enemies().size(), 0, "and it starts once the menu is closed")


# --- The street ---------------------------------------------------------------------------


func test_the_floor_is_at_zero_under_every_spawn_point() -> void:
	var room := await _room()
	for point: Dictionary in room.spawn_point_list():
		var at: Vector3 = point.position
		var hit := _ray(room, at + Vector3.UP * 2.0, at + Vector3.DOWN * 2.0)
		assert_false(hit.is_empty(), "floor under %s" % at)
		if not hit.is_empty():
			assert_almost_eq((hit.position as Vector3).y, 0.0, 0.01, "at y 0 under %s" % at)


func test_the_doorways_are_open_recesses_with_a_back_wall() -> void:
	var room := await _room()
	for x in room.door_xs:
		var from := Vector3(x, 1.0, -room.lane_half_width + 0.5)
		var depth := room.door_depth + 0.4
		var hit := _ray(room, from, from + Vector3(0.0, 0.0, -depth - 1.0))
		assert_false(hit.is_empty(), "a back wall behind the doorway at x %.0f" % x)
		if not hit.is_empty():
			assert_almost_eq((hit.position as Vector3).z, -room.lane_half_width - room.door_depth, 0.05, "at the recess's depth")
		# Beside the doorway the front is solid from the lane's edge.
		var beside := Vector3(x + room.door_width, 1.0, -room.lane_half_width + 0.5)
		var wall_hit := _ray(room, beside, beside + Vector3(0.0, 0.0, -1.0))
		assert_almost_eq((wall_hit.position as Vector3).z, -room.lane_half_width, 0.05, "the building front is at the lane's edge")


func test_the_alleys_are_open_through_the_end_walls_and_the_curb() -> void:
	var room := await _room()
	for sign_x: float in [-1.0, 1.0]:
		var through := _ray(room, Vector3(sign_x * (room.lane_half_length - 1.0), 1.0, 0.0), Vector3(sign_x * (room.lane_half_length + 3.0), 1.0, 0.0))
		assert_true(through.is_empty(), "the end wall has a mouth at z 0 (x side %.0f)" % sign_x)
		var blocked := _ray(room, Vector3(sign_x * (room.lane_half_length - 1.0), 1.0, 4.0), Vector3(sign_x * (room.lane_half_length + 3.0), 1.0, 4.0))
		assert_false(blocked.is_empty(), "and is solid elsewhere")
	var side := _ray(room, Vector3(room.side_alley_x, 0.3, room.lane_half_width - 1.0), Vector3(room.side_alley_x, 0.3, room.lane_half_width + 3.0))
	assert_true(side.is_empty(), "the curb has a gap at the side alley")
	var curb := _ray(room, Vector3(-8.0, 0.3, room.lane_half_width - 1.0), Vector3(-8.0, 0.3, room.lane_half_width + 3.0))
	assert_false(curb.is_empty(), "and is solid elsewhere")


func test_nobody_can_jump_the_curb() -> void:
	var room := await _room()
	var high := _ray(room, Vector3(-8.0, 3.0, room.lane_half_width - 1.0), Vector3(-8.0, 3.0, room.lane_half_width + 3.0))
	assert_false(high.is_empty(), "an invisible barrier stands over the curb, 3 m up")
	var player: PlayerCharacter = room.player
	player.input.scripted = true
	player.global_position = Vector3(-8.0, 0.0, room.lane_half_width - 3.0)
	await _ticks(3)
	# Facing +X, the stick to the right walks toward the curb (+Z); jump at it.
	player.input.scripted_move = Vector2(1.0, 0.0)
	var peak := 0.0
	for i in 150:
		if i % 40 == 5:
			player.input.push_press(&"JUMP", 2)
		await _ticks(1)
		peak = maxf(peak, player.global_position.y)
	assert_gt(peak, 0.8, "he did jump (%.2f m)" % peak)
	assert_lt(player.global_position.z, room.lane_half_width, "and the street kept him (z %.2f)" % player.global_position.z)
	assert_gt(player.global_position.z, room.lane_half_width - 1.0, "against the curb")
	assert_gt(player.global_position.y, -0.5, "never out of the world")


func test_the_player_stands_in_the_open() -> void:
	var room := await _room()
	assert_true(SpawnRoomCheck.has_room(room.get_world_3d().direct_space_state, 0.35, 1.8,
			room.player_start + Vector3(3.0, 0.0, 0.0)), "the lane ahead of the start is free")
	assert_false(SpawnRoomCheck.has_room(room.get_world_3d().direct_space_state, 0.35, 1.8,
			Vector3(room.car_position.x, 0.0, room.car_position.z)), "the car is not")
	assert_false(SpawnRoomCheck.has_room(room.get_world_3d().direct_space_state, 0.35, 1.8,
			Vector3(room.crate_positions[0].x, 0.0, room.crate_positions[0].z)), "nor a crate")


# --- F6 -----------------------------------------------------------------------------------


func test_f6_finds_the_other_room_both_ways() -> void:
	assert_true(ResourceLoader.exists(ROOM_PATH))
	assert_eq(GameInput.room_after(TRAINING_PATH), ROOM_PATH, "from the training room to the crowd street")
	assert_eq(GameInput.room_after(ROOM_PATH), TRAINING_PATH, "and back")
	assert_eq(GameInput.ROOM_SCENES[0], ROOM_PATH)
	var room := await _room()
	assert_eq(room.scene_file_path, ROOM_PATH, "the scene knows its own path, so F6 can tell where it is")
