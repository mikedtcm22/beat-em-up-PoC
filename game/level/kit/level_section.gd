class_name LevelSection
extends Node3D
## One section of the level (Milestone 5, D11): a scene built in its own space (`Entry` at the
## origin, the walk along local -Z, its first floor at y = 0). The level chains sections by their
## markers, section k+1's `Entry` on section k's `Exit`.
##
## Children: `Entry` and `Exit` (Marker3D; local -Z is the walking direction), an optional `Start` (the
## player's place at the level's first section), `Geometry` (the LevelBlocks, stairs, barriers, guards and
## hazards), `Route` (Marker3Ds in walking order through every arena and up every stair: the bots' and
## the GO cue's path), the `Arena` nodes, and an optional `ExitBarrier` (the seam barrier at `Exit`).
## `floor_heights` lists the local y of each walkable floor (the navmesh bake keeps those
## and the stairs and drops prop and wall tops).

## The local y of each walkable floor of this section.
@export var floor_heights: PackedFloat32Array = PackedFloat32Array([0.0])
## The ambience bed's pool while the player is in this section (Milestone 6, D8), for example
## `&"ambience_street"` or `&"ambience_roof"`. Empty: the AudioDirector's default bed.
@export var ambience: StringName = &""
@export_group("Light")
## The section has its own light (Milestone 6, DRESS; D12): `LevelRoot` blends the level's sun, fog and
## sky horizon to these over Tuning's `section_light_blend_s` when the player enters the section. Off:
## the section takes Tuning's sun (Look > Toon) and the room's default fog.
@export var light_enabled: bool = false
## The sun's height above the horizon (degrees) and the direction it comes from (the light's own yaw).
@export_range(5.0, 85.0, 1.0) var sun_elevation_deg: float = 45.0
@export_range(-180.0, 180.0, 1.0) var sun_yaw_deg: float = -50.0
## The sun's colour and energy (the toon bands take both).
@export var sun_color: Color = Color.WHITE
@export_range(0.2, 3.0, 0.05) var sun_energy: float = 1.2
## The fog's colour and density: the colour is what the far world fades to, so a dark one gives a drop
## and a far skyline depth instead of a pale plane.
@export var fog_color: Color = RoomKit.DEFAULT_FOG_COLOR
@export_range(0.0, 0.05, 0.0005) var fog_density: float = RoomKit.DEFAULT_FOG_DENSITY
## The sky the far gaps show: its top and its horizon.
@export var sky_top_color: Color = RoomKit.DEFAULT_SKY_TOP
@export var sky_horizon_color: Color = RoomKit.DEFAULT_SKY_HORIZON


## This section's light as the blend reads it: sun_elevation, sun_yaw, sun_color, sun_energy, fog_color,
## fog_density, sky_top, sky_horizon.
func light() -> Dictionary:
	return {
		sun_elevation = sun_elevation_deg, sun_yaw = sun_yaw_deg, sun_color = sun_color, sun_energy = sun_energy,
		fog_color = fog_color, fog_density = fog_density, sky_top = sky_top_color, sky_horizon = sky_horizon_color,
	}


func entry() -> Marker3D:
	return get_node_or_null("Entry") as Marker3D


func exit_marker() -> Marker3D:
	return get_node_or_null("Exit") as Marker3D


func start_marker() -> Marker3D:
	return get_node_or_null("Start") as Marker3D


## The seam barrier at the Exit, or null.
func exit_barrier() -> Barrier:
	return get_node_or_null("ExitBarrier") as Barrier


## The arenas of this section in tree order.
func arena_list() -> Array[Arena]:
	var out: Array[Arena] = []
	_collect_arenas(self, out)
	return out


## The Route markers' world positions, in order.
func route_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	var route := get_node_or_null("Route")
	if route:
		for child in route.get_children():
			if child is Node3D:
				out.append((child as Node3D).global_position)
	return out


## Every barrier below this node, the ExitBarrier included.
func barriers() -> Array[Barrier]:
	var out: Array[Barrier] = []
	_collect_typed(self, out, &"Barrier")
	return out


## Every LevelBlock (solid or not) below this node, the stairs' steps and edge guards included.
func blocks() -> Array[LevelBlock]:
	var out: Array[LevelBlock] = []
	_collect_typed(self, out, &"LevelBlock")
	return out


## Every LevelStairs below this node.
func stairs() -> Array[LevelStairs]:
	var out: Array[LevelStairs] = []
	_collect_typed(self, out, &"LevelStairs")
	return out


## Every EdgeGuard below this node.
func edge_guards() -> Array[EdgeGuard]:
	var out: Array[EdgeGuard] = []
	_collect_typed(self, out, &"EdgeGuard")
	return out


## Every PickupSpot below this node.
func pickup_spots() -> Array[PickupSpot]:
	var out: Array[PickupSpot] = []
	_collect_typed(self, out, &"PickupSpot")
	return out


func _collect_arenas(node: Node, out: Array[Arena]) -> void:
	for child in node.get_children():
		if child is Arena:
			out.append(child)
		_collect_arenas(child, out)


## Collect the descendants whose script class is `class_name_` (or extends it).
func _collect_typed(node: Node, out: Array, class_name_: StringName) -> void:
	for child in node.get_children():
		var script := child.get_script() as Script
		while script != null:
			if script.get_global_name() == class_name_:
				out.append(child)
				break
			script = script.get_base_script()
		_collect_typed(child, out, class_name_)
