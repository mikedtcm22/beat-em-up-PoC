extends GutTest
## The level kit (Milestone 5, KIT): sections chained on their markers, arenas and their locks, the
## three barrier kinds, the GO cue and CLEAR!, drop-offs (the hazard KO, the edge guard, the fall
## rule), stairs, pickup spots, the spawner's finite mode and the navmesh rule, all proved in the
## two-section test strip (tests/fixtures/level_strip.tscn: a street with a parked car behind, a
## doorway, an alley and a vehicle spawn, a stair up 4.5 m to a shutter; a terrace with a chain-link
## gate ahead, a drop edge, a pipe). The strip's enemies are the probe stub unless a test needs the
## real AI.

const STRIP := "res://tests/fixtures/level_strip.tscn"
const PROBE := preload("res://tests/fixtures/spawn_probe_enemy.tscn")
## The frames the navigation map needs to sync after a level's _ready().
const SYNC_FRAMES := 5
## Strip B in level space: its Entry is the seam shutter's centre.
const B_AT := Vector3(6.5, 4.5, -24.0)

var _hits_ko: Array[Node3D] = []
var _cleared: Array[Node3D] = []
var _levels_cleared: int = 0


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.set_value(&"waves_enabled", true)
	Tuning.set_value(&"wave_gap_s", 0.1)
	Tuning.set_value(&"wave_spawn_interval_s", 0.05)
	Tuning.set_value(&"god_mode", true)
	TimeController.clear()
	TimeController.debug_scale = 1.0
	GameInput.menu_open = false
	PlaceholderAnims.warn_on_fallback = false
	_hits_ko.clear()
	_cleared.clear()
	_levels_cleared = 0
	CombatEvents.hazard_ko.connect(_on_hazard_ko)
	CombatEvents.arena_cleared.connect(_on_arena_cleared)
	CombatEvents.level_cleared.connect(_on_level_cleared)


func after_each() -> void:
	CombatEvents.hazard_ko.disconnect(_on_hazard_ko)
	CombatEvents.arena_cleared.disconnect(_on_arena_cleared)
	CombatEvents.level_cleared.disconnect(_on_level_cleared)
	PlaceholderAnims.warn_on_fallback = true
	GameInput.menu_open = false
	Tuning.reset_to_default()
	TimeController.clear()


func _on_hazard_ko(actor: Node3D, _hazard: Node3D) -> void:
	_hits_ko.append(actor)


func _on_arena_cleared(arena: Node3D) -> void:
	_cleared.append(arena)


func _on_level_cleared(_level: Node3D) -> void:
	_levels_cleared += 1


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## The strip with no presentation, the probe standing in for every archetype, the player's input
## scripted (he stands where a test puts him).
func _level(frames: int = SYNC_FRAMES, probe: bool = true) -> LevelRoot:
	var level := (load(STRIP) as PackedScene).instantiate() as LevelRoot
	level.with_presentation = false
	add_child_autofree(level)
	if probe:
		level.spawner.scene_override = {&"punk": PROBE, &"thug": PROBE, &"boss": PROBE}
	level.player.input.scripted = true
	await _ticks(frames)
	return level


func _put_player(level: LevelRoot, at: Vector3) -> void:
	level.player.global_position = at
	level.player.velocity = Vector3.ZERO


## Level-space point of a point of strip B (its local coordinates).
func _b(x: float, y: float, z: float) -> Vector3:
	return B_AT + Vector3(x, y, z)


## Kill every AI enemy of the level (health to 0, as a test of the spawner's "cleared").
func _kill_all(level: LevelRoot) -> void:
	for enemy in level.enemies():
		enemy.health = 0.0


# --- Sections, seams, arenas ---------------------------------------------------------------


func test_sections_chain_on_their_markers_and_the_seam_barrier_serves_both_arenas() -> void:
	var level := await _level()
	assert_eq(level.sections.size(), 2, "both strip sections loaded")
	var a := level.sections[0]
	var b := level.sections[1]
	assert_true(b.global_position.is_equal_approx(a.exit_marker().global_position), "B's Entry sits on A's Exit")
	assert_true(b.entry().global_position.is_equal_approx(B_AT), "at the seam shutter's centre")
	var arenas := level.arenas()
	assert_eq(arenas.size(), 2)
	assert_eq(arenas[0].ahead, a.exit_barrier(), "arena 1's ahead barrier is the seam shutter")
	assert_eq(arenas[1].behind, a.exit_barrier(), "and arena 2's behind barrier is the same shutter (no behind named)")
	assert_eq(arenas[0].behind, a.barriers()[0], "arena 1's behind barrier is the car")
	assert_eq(arenas[0].behind.kind, Barrier.Kind.CAR)
	assert_eq(arenas[1].ahead.kind, Barrier.Kind.GATE)
	assert_eq(a.exit_barrier().kind, Barrier.Kind.SHUTTER)
	assert_eq(level.route_points().size(), 9, "the route runs through both sections")


func test_a_missing_section_is_skipped_with_a_warning_and_a_lone_section_is_a_level() -> void:
	var level := (load(STRIP) as PackedScene).instantiate() as LevelRoot
	level.with_presentation = false
	level.section_paths = PackedStringArray(["res://tests/fixtures/no_such_section.tscn", "res://tests/fixtures/level_strip_a.tscn"])
	add_child_autofree(level)
	await _ticks(SYNC_FRAMES)
	assert_eq(level.sections.size(), 1, "the missing scene is skipped")
	assert_eq(level.arenas().size(), 1)
	assert_not_null(level.player, "a one-section level plays")
	assert_eq(level.arenas()[0].ahead, level.sections[0].exit_barrier(), "its last arena's ahead is its own ExitBarrier")


func test_the_level_starts_with_ahead_barriers_closed_and_behind_open() -> void:
	var level := await _level()
	var arenas := level.arenas()
	assert_false(arenas[0].behind.is_closed(), "the car starts open")
	assert_true(arenas[0].ahead.is_closed(), "the seam shutter starts closed")
	assert_true(arenas[1].ahead.is_closed(), "the terrace gate starts closed")
	assert_eq(level.current_arena(), arenas[0])
	assert_true(level.player.global_position.is_equal_approx(level.player_start), "the player starts at Start")


func test_the_lock_closes_behind_only_past_the_inset() -> void:
	var level := await _level()
	var arena := level.arenas()[0]
	var car := arena.behind
	_put_player(level, Vector3(0.0, 0.1, -2.0))
	await _ticks(4)
	assert_eq(arena.state, Arena.State.WAITING, "before the car: outside the arena")
	_put_player(level, Vector3(0.0, 0.1, -6.2))
	await _ticks(4)
	assert_true(arena.contains(level.player.global_position), "past the car, inside the arena")
	assert_eq(arena.state, Arena.State.WAITING, "but 1.2 m past it is not the inset's 2.0")
	assert_false(car.is_closed(), "so the car is still open")
	_put_player(level, Vector3(0.0, 0.1, -7.5))
	await _ticks(4)
	assert_eq(arena.state, Arena.State.LOCKED, "2.5 m past the car locks the arena")
	assert_true(car.is_closed(), "the car closes behind him")
	assert_true(arena.ahead.is_closed(), "the ahead barrier was never open")


func test_a_barrier_collides_only_while_closed_and_moves_over_its_tunable_time() -> void:
	var level := await _level()
	var car := level.arenas()[0].behind
	var from := Vector3(0.0, 1.0, -3.0)
	var to := Vector3(0.0, 1.0, -7.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, CombatTypes.bit(CombatTypes.LAYER_WORLD))
	var space := level.get_world_3d().direct_space_state
	assert_true(space.intersect_ray(query).is_empty(), "an open car: nothing in the way")
	Tuning.set_value(&"barrier_close_s", 0.5)
	var moved: Array[bool] = []
	car.moved.connect(func(closed: bool) -> void: moved.append(closed))
	car.close()
	await _ticks(2)
	assert_false(space.intersect_ray(query).is_empty(), "a closing car blocks at once")
	assert_true(car.is_moving())
	await _ticks(20)
	assert_gt(car.progress(), 0.0)
	assert_lt(car.progress(), 1.0, "mid-way after a third of a second")
	assert_true(moved.is_empty())
	await _ticks(16)
	assert_eq(car.progress(), 1.0, "arrived after its 0.5 s")
	assert_eq(moved, [true] as Array[bool], "moved(true) fired once")
	car.open()
	await _ticks(2)
	assert_true(space.intersect_ray(query).is_empty(), "an open barrier has no collider")


func test_all_three_barrier_kinds_close_and_open() -> void:
	var level := await _level()
	var a := level.sections[0]
	var shutter := a.exit_barrier()
	var car := level.arenas()[0].behind
	var gate := level.arenas()[1].ahead
	for barrier: Barrier in [shutter, car, gate]:
		barrier.snap(false)
		assert_false(barrier.is_closed())
		assert_eq(barrier.progress(), 0.0)
		barrier.close()
		await _ticks(60)
		assert_eq(barrier.progress(), 1.0, "%s closed" % barrier.name)
		assert_true(barrier.is_closed())
		barrier.open()
		await _ticks(60)
		assert_eq(barrier.progress(), 0.0, "%s open" % barrier.name)
	# The shutter drops (its panel is above the opening when open); the gate slides sideways; the car rolls.
	shutter.snap(false)
	assert_gt(shutter.get_node("Panel").position.y, 3.0, "an open shutter is rolled up above the opening")
	gate.snap(false)
	assert_gt(absf(gate.get_node("Panel").position.x), 10.0, "an open gate has slid aside by its width")
	car.snap(true)
	assert_eq(car.get_node("Panel").position, Vector3.ZERO, "a closed car stands across the opening")
