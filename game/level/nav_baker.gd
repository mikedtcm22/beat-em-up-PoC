class_name NavBaker
extends RefCounted
## Bakes a room's navigation mesh at run time from its code-built geometry (Milestone 3; the
## recipe is docs/milestones/M3-codemap/godot-navigation.md section 0, proved in a spike):
## - the parse takes only the static colliders on the world layer, so the actors, the pipe, the
##   rig meshes and the paint never become obstacles;
## - the bake is synchronous (about 2 ms) and the mesh is set on the region before the region
##   enters the tree (with the project's async-iteration settings off, section 4.3);
## - polygons on roofs (crates, cars, walls) are dropped afterwards, so the street floor is the
##   only walkable surface and "closest point" never snaps onto a car.
## The numbers come from the room (level-layout exports), as the `settings` of bake(); a key it
## lacks keeps NavigationMesh's own default. The cell height must equal the project's
## navigation/3d/default_cell_height (0.1): a taller cell floats the mesh above the floor
## and agents stall (section 3.3).
##
## Settings keys (all optional): cell_size, cell_height, agent_radius, agent_height,
## agent_max_climb (the bake), max_floor_y (polygons whose top vertex is higher are dropped).
## Make agent_radius a multiple of cell_size, and agent_height and agent_max_climb multiples of
## cell_height, or the bake warns.


## Bake the world-layer static colliders under `geometry_root` (which must be in the tree) into
## a NavigationRegion3D, not yet added to the tree: the caller adds it, then waits for the map's
## first sync (NavigationServer3D.map_get_iteration_id > 0, 2 or 3 physics frames) before any
## map query.
static func bake(geometry_root: Node3D, settings: Dictionary = {}) -> NavigationRegion3D:
	var navmesh := NavigationMesh.new()
	for key: String in ["cell_size", "cell_height", "agent_radius", "agent_height", "agent_max_climb"]:
		if settings.has(key):
			navmesh.set(key, float(settings[key]))
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_collision_mask = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navmesh, source, geometry_root)
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source)
	if settings.has("max_floor_y"):
		drop_roof_polygons(navmesh, float(settings.max_floor_y))
	var region := NavigationRegion3D.new()
	region.name = "NavRegion"
	region.navigation_mesh = navmesh
	return region


## Keeps only the polygons whose highest vertex is below `max_floor_y` (the street floor and
## its recesses); roofs of crates, cars and walls go. The unused vertices stay, harmlessly.
static func drop_roof_polygons(navmesh: NavigationMesh, max_floor_y: float) -> void:
	var verts := navmesh.get_vertices()
	var keep: Array[PackedInt32Array] = []
	for p in navmesh.get_polygon_count():
		var poly := navmesh.get_polygon(p)
		var top := -INF
		for index in poly:
			top = maxf(top, verts[index].y)
		if top < max_floor_y:
			keep.append(poly)
	navmesh.clear_polygons()
	for poly in keep:
		navmesh.add_polygon(poly)


## True once the default navigation map of `world` has synced at least once, i.e. map queries
## are legal (before that they print an ERROR and answer (0, 0, 0)).
static func map_ready(world: World3D) -> bool:
	return world != null and NavigationServer3D.map_get_iteration_id(world.navigation_map) > 0
