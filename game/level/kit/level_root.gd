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
@export var nav_floor_tolerance: float = NavBaker.FLOOR_TOLERANCE_M
@export var nav_floor_lift: float = NavBaker.FLOOR_LIFT_M
@export_group("Sections")
## A section takes over as "the one the player is in" (`CombatEvents.section_entered`) only when one
## of its route points is this much nearer (m) than the current section's nearest, so a player
## standing at a seam does not make it flicker.
@export_range(0.0, 5.0, 0.1) var section_switch_margin_m: float = 1.0
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
## The section the player is in (section_entered's last), -1 before the first.
var _section_index: int = -1
## Every route point with the section it belongs to: (point, section index).
var _route_owners: Array[Dictionary] = []
## The level's light now, and the blend it is in the middle of (Milestone 6, D12): the light it left, the
## light it goes to and how far (0 to 1).
var _light_now: Dictionary = {}
var _light_from: Dictionary = {}
var _light_to: Dictionary = {}
var _light_t: float = 1.0
var _light_is_default: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	Tuning.changed.connect(_on_tuning_changed)
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
		add_child(TrailerLook.new())
	_index_route()
	if start_arena > 0:
		start_at_arena(start_arena)
	_track_section()


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


## The section the player is in, or null before the level has one.
func current_section() -> LevelSection:
	return sections[_section_index] if _section_index >= 0 and _section_index < sections.size() else null


## Which section owns each route point, for the section tracking.
func _index_route() -> void:
	_route_owners.clear()
	for k in sections.size():
		for point in sections[k].route_points():
			_route_owners.append({point = point, section = k})


## `CombatEvents.section_entered` (Milestone 6, D12; the ambience bed and, in DRESS, the section's
## light follow it): once when the level starts, then each time the section owning the route point
## nearest the player changes. A section wins the nearest point only by `section_switch_margin_m`, so
## the seam does not flicker. A level with no route has no section to be in; its first is the one.
func _track_section() -> void:
	if sections.is_empty() or player == null:
		return
	var nearest := _nearest_owner(player.global_position)
	if _section_index >= 0 and nearest != _section_index:
		var current := _owner_distance(player.global_position, _section_index)
		if _owner_distance(player.global_position, nearest) > current - section_switch_margin_m:
			nearest = _section_index
	if nearest == _section_index:
		return
	var first := _section_index < 0
	_section_index = nearest
	_retarget_light(first)
	CombatEvents.section_entered.emit(sections[_section_index])


## Whether the section the player is in has its own light and the switch is on: LookPost then leaves
## the sun to the blend (Tuning's Look > Toon sun applies only where no section light does).
func section_light_applies() -> bool:
	var section := current_section()
	return Tuning.data.section_light_enabled and section != null and section.light_enabled


## Tuning's sun and the room's default fog and sky, the light of a section with none of its own.
func default_light() -> Dictionary:
	var t := Tuning.data
	return {
		sun_elevation = t.look_sun_elevation_deg, sun_yaw = t.look_sun_yaw_deg, sun_color = Color.WHITE,
		sun_energy = t.look_sun_energy, fog_color = RoomKit.DEFAULT_FOG_COLOR, fog_density = RoomKit.DEFAULT_FOG_DENSITY,
		sky_top = RoomKit.DEFAULT_SKY_TOP, sky_horizon = RoomKit.DEFAULT_SKY_HORIZON,
	}


## The light the level is at now (mid-blend between two sections' while it changes).
func current_light() -> Dictionary:
	return _light_now


## How far the blend to the current section's light has got, 0 to 1 (1: arrived).
func section_light_progress() -> float:
	return _light_t


## The light `section` calls for.
func light_for(section: LevelSection) -> Dictionary:
	var light: Dictionary
	if section != null and section.light_enabled and Tuning.data.section_light_enabled:
		light = LookProfile.resolve_light(section.light())
	else:
		light = LookProfile.resolve_light(default_light())
	# The trailer profile's own place looks (M7, T10): the profile's rows that are not a light are dropped, and the
	# section's night look, when it has one, lays its colour script over the light.
	light = NightLook.strip_rows(light)
	var look := NightLook.for_location(section.look_location) if section != null else null
	if look != null:
		light = light.duplicate()
		light.merge(look.light(), true)
	return light


## The blend of two lights at `t` (0 to 1, eased): colours and numbers lerp, the sun's yaw the short way.
static func blend_light(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	if a.is_empty():
		return b.duplicate()
	var e := smoothstep(0.0, 1.0, clampf(t, 0.0, 1.0))
	var out := {}
	for key: StringName in b:
		var from: Variant = a.get(key, b[key])
		if from is Color:
			out[key] = (from as Color).lerp(b[key] as Color, e)
		elif key == &"sun_yaw":
			out[key] = rad_to_deg(lerp_angle(deg_to_rad(float(from)), deg_to_rad(float(b[key])), e))
		else:
			out[key] = lerpf(float(from), float(b[key]), e)
	return out


## A flip of the look profile (F7) puts its light on the level at once, with no blend.
func _on_tuning_changed(property: StringName) -> void:
	if (property == &"look_profile" or property == &"") and _section_index >= 0:
		_retarget_light(true)


func _exit_tree() -> void:
	if Tuning.changed.is_connected(_on_tuning_changed):
		Tuning.changed.disconnect(_on_tuning_changed)


## Aim the blend at the current section's light (snapping when it is the first or the blend is 0).
func _retarget_light(snap: bool) -> void:
	var target := light_for(current_section())
	if target == _light_to:
		return
	# Tuning's sun moving live (the F1 panel) is not a change of section: it follows at once.
	var was_default := _light_is_default
	_light_is_default = not section_light_applies()
	_light_from = _light_now
	_light_to = target
	_light_t = 1.0 if snap or (was_default and _light_is_default) or Tuning.data.section_light_blend_s <= 0.0 else 0.0
	if _light_t >= 1.0:
		_light_now = _light_to.duplicate()
		_apply_light()


## Advance the blend and put the light on the sun, the fog and the sky.
func _step_light(delta: float) -> void:
	_retarget_light(false)
	_apply_fog_sky_affect()
	if _light_t >= 1.0:
		return
	var seconds := Tuning.data.section_light_blend_s
	_light_t = 1.0 if seconds <= 0.0 else minf(1.0, _light_t + delta / seconds)
	_light_now = blend_light(_light_from, _light_to, _light_t)
	_apply_light()


## Keep the fog's cover of the sky at Tuning's value (live: the F1 panel moves it), written only on a change.
func _apply_fog_sky_affect() -> void:
	var world := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world != null and world.environment != null:
		var affect := Tuning.data.section_fog_sky_affect
		if not is_equal_approx(world.environment.fog_sky_affect, affect):
			world.environment.fog_sky_affect = affect


func _apply_light() -> void:
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.rotation_degrees = Vector3(-float(_light_now.sun_elevation), float(_light_now.sun_yaw), 0.0)
		sun.light_color = _light_now.sun_color
		sun.light_energy = float(_light_now.sun_energy)
	var world := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world != null and world.environment != null:
		var env := world.environment
		env.fog_light_color = _light_now.fog_color
		env.fog_density = float(_light_now.fog_density)
		var sky := env.sky.sky_material as ProceduralSkyMaterial if env.sky != null else null
		if sky != null:
			sky.sky_top_color = _light_now.sky_top
			sky.sky_horizon_color = _light_now.sky_horizon


## The section whose route point is nearest `at` (the first section when there is no route).
func _nearest_owner(at: Vector3) -> int:
	var best := 0
	var best_distance := INF
	for entry in _route_owners:
		var d := at.distance_squared_to(entry.point as Vector3)
		if d < best_distance:
			best_distance = d
			best = int(entry.section)
	return best


## The distance from `at` to the nearest route point of section `k` (INF when it has none).
func _owner_distance(at: Vector3, k: int) -> float:
	var best := INF
	for entry in _route_owners:
		if int(entry.section) == k:
			best = minf(best, at.distance_to(entry.point as Vector3))
	return best


func _physics_process(delta: float) -> void:
	_track_section()
	_step_light(delta)
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
