extends Node3D
## The base of the two attack-arc test rooms (Milestone 5, ARC): code-built static boxes on the world
## layer under one navmesh, baked at _ready() with the crowd room's settings (cell 0.25 / 0.1, agent
## 0.5 / 1.8, climb 0.2). A subclass says which boxes in _blocks(); a test waits NAV_SYNC_TICKS
## physics frames after adding the room before it asks the director for a seat.

## Frames the navigation map needs to sync after the region joins the tree.
const NAV_SYNC_TICKS := 6


## The boxes: [{center: Vector3, size: Vector3}, ...], a floor's top where its center y + size.y / 2 is.
func _blocks() -> Array[Dictionary]:
	return []


func _ready() -> void:
	for block: Dictionary in _blocks():
		var body := StaticBody3D.new()
		body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = block.size
		shape.shape = box
		body.add_child(shape)
		body.position = block.center
		add_child(body)
	var navmesh := NavigationMesh.new()
	navmesh.cell_size = 0.25
	navmesh.cell_height = 0.1
	navmesh.agent_radius = 0.5
	navmesh.agent_height = 1.8
	navmesh.agent_max_climb = 0.2
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_collision_mask = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navmesh, source, self)
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source)
	var region := NavigationRegion3D.new()
	region.navigation_mesh = navmesh
	add_child(region)
