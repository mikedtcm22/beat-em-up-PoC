class_name CrowdRoom
extends Node3D
## Milestone 3's crowd room: a 30 x 12 m city street built in code, where waves of enemies
## walk in from doorways, alleys and behind a parked car, some from behind the player, and the
## fight can be judged in first person. Street axis = world X, building fronts on -Z (a
## tall wall with three doorway recesses), the near side (+Z) a low curb with one side alley, an
## alley through each end wall, a parked car, a crate pair and a dumpster for cover. As in the
## training room the near side stays low so the side-view debug camera can see the street.
##
## Every number of the layout is an export below. All solid geometry hangs under one `Geometry`
## node; the navmesh is baked from it (NavBaker) in _ready(), before any actor exists. Then come
## the player (RoomKit.spawn_player: auto-revive, an avoidance obstacle), the EnemyDirector, the
## EncounterSpawner with this room's spawn points, and the presentation layer as direct
## children (RoomKit.build_presentation). The map syncs 2 or 3 physics frames after _ready():
## wait before asking it anything (NavBaker.map_ready()).
##
## The room contract for bots and tests (M3-plan 2.12): `player`, `player_start`, `player_yaw_deg`,
## `with_presentation`, `waves_enabled_on_start`, `rng_seed`, `spawner`, `director`, enemies().
## The training room (test_room.tscn) is the other room; F6 switches (GameInput.switch_room()).

@export_group("Player")
@export var player_start: Vector3 = Vector3(0.0, 0.0, 0.0)
## Facing +X, so the west alley and two of the doorways start behind or beside the player.
@export_range(-180.0, 180.0, 1.0) var player_yaw_deg: float = -90.0
@export_group("Run")
## Build the presentation layer (cameras, HUD, tuning overlay, effects). Tests turn it off.
@export var with_presentation: bool = true
## Waves start on their own (the tunable waves_enabled, set false here when this is off).
@export var waves_enabled_on_start: bool = true
## Seeds the director and the spawner.
@export var rng_seed: int = 0

@export_group("Lane")
## The lane's floor spans x -half_length..half_length and z -half_width..half_width, top at y 0.
## No floor margins past the walls: they would be navmesh islands.
@export var lane_half_length: float = 15.0
@export var lane_half_width: float = 6.0
## How far in from the lane's edge an arriving enemy walks first (its lane point).
@export var lane_entry_m: float = 2.5
@export_group("North buildings")
## Doorway recesses in the north fronts: centre x of each, opening width, depth into the
## building and clear height (the building goes on above, as a lintel).
@export var door_xs: PackedFloat32Array = PackedFloat32Array([-9.0, 0.0, 9.0])
@export var door_width: float = 2.0
@export var door_depth: float = 1.5
@export var door_height: float = 2.8
## Depth of a building front, and the heights of the blocks between the doorways, west to east.
@export var front_depth: float = 2.0
@export var front_heights: PackedFloat32Array = PackedFloat32Array([7.0, 9.0, 6.0, 8.0])
## Windows on the fronts (drawn only): size, spacing along the front and between rows, the
## height of the first row.
@export var window_size: Vector2 = Vector2(1.0, 1.3)
@export var window_pitch_m: float = 2.2
@export var window_row_m: float = 2.1
@export var window_first_m: float = 3.2
@export_group("Ends and alleys")
## The end walls (x = +-half_length) and the alley through each: width, length, wall thickness
## and height.
@export var end_wall_thickness: float = 1.0
@export var end_wall_height: float = 6.0
@export var alley_width: float = 3.0
@export var alley_length: float = 5.0
@export var alley_wall_thickness: float = 0.5
@export_group("South side")
## The low curb along +Z (the invisible barrier above it keeps the player on the street) and
## the side alley through it: its x, the gap in the curb, the alley's width, length and fence height.
@export var curb_height: float = 0.6
@export var curb_thickness: float = 0.5
@export var curb_barrier_height: float = 8.0
@export var side_alley_x: float = 4.0
@export var side_alley_gap: float = 2.5
@export var side_alley_width: float = 3.0
@export var side_alley_length: float = 5.0
@export var side_alley_wall_height: float = 2.4
@export_group("Props")
@export var car_position: Vector3 = Vector3(-5.0, 0.0, 3.5)
## Length (x), height and width (z) of the parked car.
@export var car_size: Vector3 = Vector3(4.2, 1.9, 1.4)
@export var crate_positions: PackedVector3Array = PackedVector3Array([Vector3(5.6, 0.0, -4.6), Vector3(6.55, 0.0, -5.1)])
@export var crate_size: float = 1.0
@export var dumpster_position: Vector3 = Vector3(12.0, 0.0, -5.0)
@export var dumpster_size: Vector3 = Vector3(2.0, 1.3, 1.0)
@export_group("Backdrop")
## Drawn only: the ground and the skyline beyond the near curb (x, z of each block's centre and
## its width, depth and height).
@export var skyline: PackedVector3Array = PackedVector3Array([
	Vector3(-26.0, 22.0, 9.0), Vector3(-12.0, 25.0, 12.0), Vector3(4.0, 21.0, 8.0), Vector3(18.0, 26.0, 13.0),
	Vector3(32.0, 23.0, 10.0), Vector3(-40.0, 26.0, 11.0), Vector3(44.0, 25.0, 12.0),
])
@export var skyline_depth: float = 8.0
@export var skyline_heights: PackedFloat32Array = PackedFloat32Array([14.0, 20.0, 11.0, 17.0, 13.0, 16.0, 12.0])
@export_group("Navigation")
## The navmesh bake (NavBaker): cell sizes must match the project's navigation settings
## (cell height 0.1), the radius is a multiple of the cell size, the height and the climb
## multiples of the cell height, and polygons above max_floor_y are roofs.
@export var nav_cell_size: float = 0.25
@export var nav_cell_height: float = 0.1
@export var nav_agent_radius: float = 0.5
@export var nav_agent_height: float = 1.8
@export var nav_agent_max_climb: float = 0.2
@export var nav_max_floor_y: float = 0.5
## A spawn point stands this far inside the walkable edge of its recess or alley.
@export var spawn_inset_m: float = 0.35

var player: PlayerCharacter
var spawner: EncounterSpawner
var director: EnemyDirector
var geometry: Node3D
var nav_region: NavigationRegion3D
## Microseconds the navmesh bake took (parse + bake + roof filter), for tests and the log.
var nav_bake_usec: int = 0


func _ready() -> void:
	RoomKit.build_environment(self)
	_build_geometry()
	_bake_navigation()
	player = RoomKit.spawn_player(self, player_start, player_yaw_deg)
	director = EnemyDirector.new()
	director.name = "EnemyDirector"
	director.rng_seed = rng_seed
	add_child(director)
	spawner = EncounterSpawner.new()
	spawner.name = "EncounterSpawner"
	spawner.rng_seed = rng_seed
	spawner.spawn_points = spawn_point_list()
	add_child(spawner)
	if not waves_enabled_on_start:
		spawner.set_waves_enabled(false)
	if with_presentation:
		RoomKit.build_presentation(self)


## The AI enemies in the room (members of "ai_enemy"), dead and alive.
func enemies() -> Array[EnemyActor]:
	var out: Array[EnemyActor] = []
	for node: Node in get_tree().get_nodes_in_group(&"ai_enemy"):
		var enemy := node as EnemyActor
		if enemy:
			out.append(enemy)
	return out


## The places enemies walk in from, built from the layout: a doorway recess in each north
## front (its back), an alley through each end wall, the side alley, and the far side of the
## parked car ("vehicle"). Each {position, yaw, tag, lane_point} (see EncounterSpawner).
func spawn_point_list() -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	var inset := nav_agent_radius + spawn_inset_m
	for x in door_xs:
		var at := Vector3(x, 0.0, -(lane_half_width + door_depth) + inset)
		var lane := Vector3(x, 0.0, -lane_half_width + lane_entry_m)
		points.append(_point(at, lane, &"doorway"))
	for sign_x: float in [-1.0, 1.0]:
		var at := Vector3(sign_x * (lane_half_length + alley_length - inset), 0.0, 0.0)
		var lane := Vector3(sign_x * (lane_half_length - lane_entry_m), 0.0, 0.0)
		points.append(_point(at, lane, &"alley"))
	var side_at := Vector3(side_alley_x, 0.0, lane_half_width + side_alley_length - inset)
	points.append(_point(side_at, Vector3(side_alley_x, 0.0, lane_half_width - lane_entry_m), &"alley"))
	# The car's far side: the strip between its south face and the curb.
	var car_far_z := car_position.z + car_size.z * 0.5
	var strip := Vector3(car_position.x, 0.0, (car_far_z + lane_half_width) * 0.5)
	var strip_lane := Vector3(car_position.x + car_size.x * 0.5 + lane_entry_m, 0.0, car_position.z)
	points.append(_point(strip, strip_lane, &"vehicle"))
	return points


func _point(at: Vector3, lane: Vector3, tag: StringName) -> Dictionary:
	var facing := lane - at
	return {position = at, yaw = atan2(-facing.x, -facing.z), tag = tag, lane_point = lane}


# --- Navigation ---------------------------------------------------------------------------


func _bake_navigation() -> void:
	var started := Time.get_ticks_usec()
	nav_region = NavBaker.bake(geometry, {
		cell_size = nav_cell_size, cell_height = nav_cell_height, agent_radius = nav_agent_radius,
		agent_height = nav_agent_height, agent_max_climb = nav_agent_max_climb, max_floor_y = nav_max_floor_y,
	})
	add_child(nav_region)
	nav_bake_usec = Time.get_ticks_usec() - started


# --- Geometry -----------------------------------------------------------------------------


func _build_geometry() -> void:
	geometry = Node3D.new()
	geometry.name = "Geometry"
	add_child(geometry)
	var wall := RoomKit.flat_material(Color(0.42, 0.4, 0.44))
	var accent := RoomKit.flat_material(Color(0.5, 0.46, 0.4))
	# Alleys and doorways are dark openings, so a spawn point reads from across the street.
	var dark := RoomKit.flat_material(Color(0.12, 0.1, 0.13))
	_build_lane()
	_build_north(wall, accent, dark)
	_build_ends(wall, dark)
	_build_south(accent, dark)
	_build_props()
	_build_backdrop(wall, accent)


func _build_lane() -> void:
	var size := Vector3(lane_half_length * 2.0, 1.0, lane_half_width * 2.0)
	RoomKit.add_box(geometry, Vector3(0.0, -0.5, 0.0), size, RoomKit.grid_material())
	# The dashed centre line.
	var paint := RoomKit.flat_material(Color(0.82, 0.8, 0.72))
	var x := -lane_half_length + 1.0
	while x < lane_half_length - 1.0:
		RoomKit.add_visual_box(geometry, Vector3(x + 0.75, 0.005, 0.0), Vector3(1.5, 0.01, 0.15), paint)
		x += 3.0


## The north fronts: a block between each pair of doorways (and at the ends), a dark back wall,
## floor and lintel for each doorway recess, and windows on the blocks.
func _build_north(wall: Material, accent: Material, door: Material) -> void:
	var window := RoomKit.flat_material(Color(0.16, 0.2, 0.28))
	var edges: Array[float] = [-lane_half_length]
	for x in door_xs:
		edges.append(x - door_width * 0.5)
		edges.append(x + door_width * 0.5)
	edges.append(lane_half_length)
	var z_face := -lane_half_width
	var block := 0
	for i in range(0, edges.size(), 2):
		var x0 := edges[i]
		var x1 := edges[i + 1]
		var height := front_heights[block % front_heights.size()]
		var material := wall if block % 2 == 0 else accent
		RoomKit.add_box(geometry, Vector3((x0 + x1) * 0.5, height * 0.5, z_face - front_depth * 0.5),
				Vector3(x1 - x0, height, front_depth), material)
		_add_windows(x0, x1, z_face, height, window)
		block += 1
	var back := front_depth - door_depth
	var floor_material := RoomKit.grid_material()
	for i in door_xs.size():
		var x := door_xs[i]
		# The recess: floor, a dark back wall and a lintel over the opening.
		RoomKit.add_box(geometry, Vector3(x, -0.5, z_face - door_depth * 0.5), Vector3(door_width, 1.0, door_depth), floor_material)
		RoomKit.add_box(geometry, Vector3(x, door_height * 0.5, z_face - front_depth + back * 0.5),
				Vector3(door_width, door_height, back), door)
		var top := maxf(front_heights[i % front_heights.size()], front_heights[(i + 1) % front_heights.size()])
		var lintel_height := top - door_height
		RoomKit.add_box(geometry, Vector3(x, door_height + lintel_height * 0.5, z_face - front_depth * 0.5),
				Vector3(door_width, lintel_height, front_depth), accent)


func _add_windows(x0: float, x1: float, z_face: float, height: float, material: Material) -> void:
	var columns := int(floor((x1 - x0 - window_size.x) / window_pitch_m)) + 1
	if columns <= 0:
		return
	var span := float(columns - 1) * window_pitch_m
	var start := (x0 + x1) * 0.5 - span * 0.5
	var y := window_first_m
	while y + window_size.y * 0.5 < height - 0.5:
		for c in columns:
			var window := RoomKit.add_visual_box(geometry, Vector3(start + float(c) * window_pitch_m, y, z_face + 0.015),
					Vector3(window_size.x, window_size.y, 0.03), material)
			window.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		y += window_row_m


## The end walls with an alley through each: floor, dark side walls and a dark blind end.
func _build_ends(wall: Material, dark: Material) -> void:
	var half_gap := alley_width * 0.5
	var z_north := -(lane_half_width + front_depth)
	var z_south := lane_half_width + curb_thickness
	var base := -1.0
	var height := end_wall_height - base
	for sign_x: float in [-1.0, 1.0]:
		var x_wall := sign_x * (lane_half_length + end_wall_thickness * 0.5)
		# The wall either side of the alley mouth.
		for pair: Vector2 in [Vector2(z_north, -half_gap), Vector2(half_gap, z_south)]:
			RoomKit.add_box(geometry, Vector3(x_wall, base + height * 0.5, (pair.x + pair.y) * 0.5),
					Vector3(end_wall_thickness, height, pair.y - pair.x), wall)
		# The alley floor (a little into the lane so no seam opens), its side walls and its end.
		var x_in := sign_x * (lane_half_length - 0.1)
		var x_out := sign_x * (lane_half_length + alley_length)
		RoomKit.add_box(geometry, Vector3((x_in + x_out) * 0.5, -0.5, 0.0),
				Vector3(absf(x_out - x_in), 1.0, alley_width), RoomKit.grid_material())
		var x_a := sign_x * (lane_half_length + end_wall_thickness)
		var x_b := sign_x * (lane_half_length + alley_length + alley_wall_thickness)
		for sign_z: float in [-1.0, 1.0]:
			RoomKit.add_box(geometry,
					Vector3((x_a + x_b) * 0.5, base + height * 0.5, sign_z * (half_gap + alley_wall_thickness * 0.5)),
					Vector3(absf(x_b - x_a), height, alley_wall_thickness), dark)
		RoomKit.add_box(geometry,
				Vector3(sign_x * (lane_half_length + alley_length + alley_wall_thickness * 0.5), base + height * 0.5, 0.0),
				Vector3(alley_wall_thickness, height, alley_width + alley_wall_thickness * 2.0), dark)


## The low curb with the side alley, an invisible barrier above it (a jump would otherwise
## clear it and fall out of the world) and the alley's dark fences.
func _build_south(curb: Material, fence: Material) -> void:
	var half_gap := side_alley_gap * 0.5
	var z_curb := lane_half_width + curb_thickness * 0.5
	for pair: Vector2 in [Vector2(-lane_half_length, side_alley_x - half_gap), Vector2(side_alley_x + half_gap, lane_half_length)]:
		var length := pair.y - pair.x
		var x := (pair.x + pair.y) * 0.5
		RoomKit.add_box(geometry, Vector3(x, curb_height * 0.5, z_curb), Vector3(length, curb_height, curb_thickness), curb)
		var barrier := curb_barrier_height - curb_height
		RoomKit.add_box(geometry, Vector3(x, curb_height + barrier * 0.5, z_curb), Vector3(length, barrier, curb_thickness), null)
	# The side alley: floor, two fences and a blind end.
	var z_in := lane_half_width - 0.1
	var z_out := lane_half_width + side_alley_length
	RoomKit.add_box(geometry, Vector3(side_alley_x, -0.5, (z_in + z_out) * 0.5),
			Vector3(side_alley_width, 1.0, z_out - z_in), RoomKit.grid_material())
	var z_a := lane_half_width + curb_thickness
	var z_b := z_out + alley_wall_thickness
	var base := -1.0
	var height := side_alley_wall_height - base
	for sign_x: float in [-1.0, 1.0]:
		RoomKit.add_box(geometry,
				Vector3(side_alley_x + sign_x * (side_alley_width + alley_wall_thickness) * 0.5, base + height * 0.5, (z_a + z_b) * 0.5),
				Vector3(alley_wall_thickness, height, z_b - z_a), fence)
	RoomKit.add_box(geometry, Vector3(side_alley_x, base + height * 0.5, z_out + alley_wall_thickness * 0.5),
			Vector3(side_alley_width + alley_wall_thickness * 2.0, height, alley_wall_thickness), fence)


func _build_props() -> void:
	var crate := RoomKit.prop_material(Color(0.55, 0.46, 0.3))
	for p in crate_positions:
		RoomKit.add_box(geometry, Vector3(p.x, crate_size * 0.5, p.z), Vector3(crate_size, crate_size, crate_size), crate)
	# A muted blue-grey: red is only for blood, the warning and finisher accents (M4-plan A13), and the
	# street's own colors stay under the look bible's saturation of 0.30.
	RoomKit.add_box(geometry, car_position + Vector3.UP * car_size.y * 0.5, car_size,
			RoomKit.prop_material(Color(0.34, 0.38, 0.45)))
	RoomKit.add_box(geometry, dumpster_position + Vector3.UP * dumpster_size.y * 0.5, dumpster_size,
			RoomKit.prop_material(Color(0.2, 0.42, 0.3)))


## Drawn only: the ground beyond the near curb and a skyline on it, so looking across the street
## shows a city, not a void. No collision (the curb's barrier keeps everyone out), no navmesh.
func _build_backdrop(wall: Material, accent: Material) -> void:
	var ground := RoomKit.flat_material(Color(0.24, 0.23, 0.26))
	RoomKit.add_visual_box(geometry, Vector3(0.0, -0.55, lane_half_width + curb_thickness + 30.0),
			Vector3(160.0, 1.0, 60.0), ground)
	for i in skyline.size():
		var block := skyline[i]
		var height := skyline_heights[i % skyline_heights.size()]
		RoomKit.add_visual_box(geometry, Vector3(block.x, height * 0.5 - 0.05, block.y),
				Vector3(block.z, height, skyline_depth), wall if i % 2 == 0 else accent)
