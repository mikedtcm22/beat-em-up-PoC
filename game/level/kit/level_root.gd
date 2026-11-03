class_name LevelRoot
extends Node3D
## The level (Milestone 5, D10, D11): a chain of section scenes (`LevelSection`) laid end to end, one
## navmesh over all of them, the player, the director, the ONE spawner and the presentation layer. It
## is the room contract of `CrowdRoom` for bots and tests (`player`, `player_start`,
## `player_yaw_deg`, `with_presentation`, `waves_enabled_on_start`, `rng_seed`, `director`, `spawner`,
## `nav_region`, `enemies()`), plus the level's own: `arenas()`, `current_arena()`, `route_points()`,
## `start_at_arena()`.
##
## `_ready()`: the environment; the sections (each `section_paths` scene that exists, a missing one
## skipped with a warning; section k+1's `Entry` on section k's `Exit`); every barrier closed; the
## navmesh bake (floors and stairs, see NavBaker; barriers closed so each arena is an island); the
## barriers to their start state; the player at the first section's `Start` (RoomKit.spawn_player:
## auto-revive, so a KO stands him back up in place and the arena stays locked); the director; the one
## spawner, idle; the pickups; the presentation layer. When an arena locks it gives the spawner its
## table and points; when the table has finished the arena clears; when the last arena clears
## `CombatEvents.level_cleared` fires. Every number of the layout is in the section scenes.

const GROUP := &"level_root"

@export_group("Level")
## The section scenes, in order (res:// paths of `LevelSection` scenes).
@export var section_paths: PackedStringArray = PackedStringArray()
## Start with this arena (0-based) as the current one: the earlier ones cleared and open.
@export var start_arena: int = 0
@export_group("Run")
## Build the presentation layer (cameras, HUD, tuning overlay, effects). Tests turn it off.
@export var with_presentation: bool = true
## Waves run on their own (the tunable waves_enabled; false turns it off).
@export var waves_enabled_on_start: bool = true
## Seeds the director and the spawner.
@export var rng_seed: int = 0
@export_group("Navigation")
## The navmesh bake (NavBaker); as the crowd room's, with the floor rule of a level: a polygon
## within `nav_floor_tolerance` m of a section's floor height (it sits `nav_floor_lift` above it)
## or inside a stair footprint is walkable.
@export var nav_cell_size: float = 0.25
@export var nav_cell_height: float = 0.1
@export var nav_agent_radius: float = 0.5
@export var nav_agent_height: float = 1.8
@export var nav_agent_max_climb: float = 0.2
@export var nav_floor_tolerance: float = 0.3
@export var nav_floor_lift: float = 0.2
@export_group("Safety")
## An AI enemy that falls this far (m) below the lowest floor of the level, past every HazardVolume's
## catch floor, is removed (nothing there to land on).
@export var void_depth_m: float = 30.0

var player: PlayerCharacter
var director: EnemyDirector
var spawner: EncounterSpawner
var nav_region: NavigationRegion3D
## Where the player started and the way he faced (the first section's `Start`).
var player_start: Vector3 = Vector3.ZERO
var player_yaw_deg: float = 0.0
## Microseconds the navmesh bake took, for tests and the log.
var nav_bake_usec: int = 0
## The sections in order.
var sections: Array[LevelSection] = []
## The node the sections hang under (the navmesh is baked from it).
var container: Node3D

var _arenas: Array[Arena] = []
var _lowest_floor_y: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	RoomKit.build_environment(self)
	container = Node3D.new()
	container.name = "Sections"
	add_child(container)
	_build_sections()
	_wire_arenas()
	_bake_navigation()
	var start := sections[0].start_marker() if not sections.is_empty() else null
	player_start = start.global_position if start else Vector3.ZERO
	player_yaw_deg = rad_to_deg(start.global_rotation.y) if start else 0.0
	player = RoomKit.spawn_player(self, player_start, player_yaw_deg)
	director = EnemyDirector.new()
	director.name = "EnemyDirector"
	director.rng_seed = rng_seed
	add_child(director)
	spawner = EncounterSpawner.new()
	spawner.name = "EncounterSpawner"
	spawner.rng_seed = rng_seed
	spawner.table = EncounterTable.new()
	add_child(spawner)
	spawner.stop()
	spawner.table_finished.connect(_on_table_finished)
	if not waves_enabled_on_start:
		spawner.set_waves_enabled(false)
	for i in _arenas.size():
		_arenas[i].armed = i == 0
		_arenas[i].locked.connect(_on_arena_locked.bind(_arenas[i]))
		_arenas[i].cleared.connect(_on_arena_cleared.bind(_arenas[i]))
	_place_pickups()
	if with_presentation:
		RoomKit.build_presentation(self)
	if start_arena > 0:
		start_at_arena(start_arena)


## The AI enemies in the level (members of "ai_enemy"), dead and alive.
func enemies() -> Array[EnemyActor]:
	var out: Array[EnemyActor] = []
	for node: Node in get_tree().get_nodes_in_group(&"ai_enemy"):
		var enemy := node as EnemyActor
		if enemy:
			out.append(enemy)
	return out


## Every arena, in level order.
func arenas() -> Array[Arena]:
	return _arenas


## The arena the player is fighting or about to fight: the locked one, else the first not cleared,
## else the last. Null in a level with none.
func current_arena() -> Arena:
	for arena in _arenas:
		if arena.state == Arena.State.LOCKED:
			return arena
	for arena in _arenas:
		if arena.state != Arena.State.CLEARED:
			return arena
	return _arenas.back() if not _arenas.is_empty() else null


## The Route markers of every section, in walking order (world positions).
func route_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	for section in sections:
		out.append_array(section.route_points())
	return out


## The first route point inside `arena`'s lock volume, or INF when it has none.
func first_route_point(arena: Arena) -> Vector3:
	for point in route_points():
		if arena.contains(point):
			return point
	return Vector3.INF


## Where the GO cue points after `arena` clears: the first route point of the arena that follows,
## INF when it is the last.
func next_target(arena: Arena) -> Vector3:
	var index := _arenas.find(arena)
	if index < 0 or index + 1 >= _arenas.size():
		return Vector3.INF
	return first_route_point(_arenas[index + 1])


## Make arena `index` (0-based) the current one: the arenas before it cleared and open (no signals),
## it and the ones after waiting with their barriers at their start state, the spawner stopped and
## the AI enemies removed, the player standing at its first route point (the level's `Start` for the
## first arena) and looking along the route. For bots and tests that need a later arena.
func start_at_arena(index: int) -> void:
	index = clampi(index, 0, maxi(_arenas.size() - 1, 0))
	spawner.stop()
	EncounterSpawner.remove_enemies(get_tree(), true)
	for i in range(_arenas.size() - 1, -1, -1):
		if i >= index:
			_arenas[i].reset_waiting()
	for i in _arenas.size():
		if i < index:
			_arenas[i].reset_cleared()
		_arenas[i].armed = i == index
	var at := player_start
	var yaw := deg_to_rad(player_yaw_deg)
	if index > 0 and not _arenas.is_empty():
		var first := first_route_point(_arenas[index])
		if first.is_finite():
			at = first
			yaw = _route_yaw(first, yaw)
	player.reset_state()
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw
	player.look_yaw = yaw


func _route_yaw(from: Vector3, fallback: float) -> float:
	var route := route_points()
	for i in route.size():
		if route[i].is_equal_approx(from) and i + 1 < route.size():
			var d := route[i + 1] - from
			if Vector2(d.x, d.z).length_squared() > 1e-4:
				return atan2(-d.x, -d.z)
	return fallback


func _physics_process(_delta: float) -> void:
	var limit := _lowest_floor_y - void_depth_m
	for enemy in enemies():
		if enemy.global_position.y < limit:
			EncounterSpawner.remove_enemy(enemy)


# --- Building -----------------------------------------------------------------------------


func _build_sections() -> void:
	var previous: LevelSection
	for path in section_paths:
		if not ResourceLoader.exists(path):
			push_warning("LevelRoot: section scene '%s' does not exist, skipped" % path)
			continue
		var scene := load(path) as PackedScene
		var section := scene.instantiate() as LevelSection if scene else null
		if section == null:
			push_warning("LevelRoot: '%s' is not a LevelSection scene, skipped" % path)
			continue
		var entry := section.entry()
		var offset := entry.position if entry else Vector3.ZERO
		if previous and previous.exit_marker():
			section.position = previous.exit_marker().global_position - offset
		else:
			section.position = -offset
		container.add_child(section)
		sections.append(section)
		_arenas.append_array(section.arena_list())
		previous = section


## Hand an arena with no named barrier its neighbour's: the previous section's ExitBarrier behind, its
## own ahead.
func _wire_arenas() -> void:
	for k in sections.size():
		var list := sections[k].arena_list()
		if list.is_empty():
			continue
		if k > 0 and sections[k - 1].exit_barrier():
			list[0].bind_behind(sections[k - 1].exit_barrier())
		if sections[k].exit_barrier():
			list[list.size() - 1].bind_ahead(sections[k].exit_barrier())


func _bake_navigation() -> void:
	var started := Time.get_ticks_usec()
	var barriers: Array[Barrier] = []
	var guards: Array[EdgeGuard] = []
	var heights := PackedFloat32Array()
	var stairs: Array[AABB] = []
	for section in sections:
		barriers.append_array(section.barriers())
		guards.append_array(section.edge_guards())
		for height in section.floor_heights:
			heights.append(section.global_position.y + height)
			_lowest_floor_y = minf(_lowest_floor_y, section.global_position.y + height)
		for flight in section.stairs():
			stairs.append(flight.footprint())
	# Every barrier closed and every guard on while the mesh is baked: each arena is an island that
	# stops an agent radius short of every open edge, whatever the start state and the tunable say.
	for barrier in barriers:
		barrier.snap(true)
	for guard in guards:
		guard.set_baking(true)
	nav_region = NavBaker.bake(container, {
		cell_size = nav_cell_size, cell_height = nav_cell_height, agent_radius = nav_agent_radius,
		agent_height = nav_agent_height, agent_max_climb = nav_agent_max_climb,
		floor_heights = heights, floor_tolerance = nav_floor_tolerance, floor_lift = nav_floor_lift,
		stair_footprints = stairs,
	})
	add_child(nav_region)
	for guard in guards:
		guard.set_baking(false)
	for barrier in barriers:
		barrier.snap(barrier.start_closed)
	nav_bake_usec = Time.get_ticks_usec() - started


func _place_pickups() -> void:
	for section in sections:
		for spot in section.pickup_spots():
			spot.place(self)


# --- Arenas -------------------------------------------------------------------------------


func _on_arena_locked(arena: Arena) -> void:
	spawner.play_table(arena.table if arena.table else EncounterTable.new(), arena.spawn_point_list())


func _on_table_finished() -> void:
	for arena in _arenas:
		if arena.state == Arena.State.LOCKED:
			arena.clear()
			return


func _on_arena_cleared(arena: Arena) -> void:
	var index := _arenas.find(arena)
	if index >= 0 and index + 1 < _arenas.size():
		_arenas[index + 1].armed = true
	elif index >= 0:
		CombatEvents.level_cleared.emit(self)
