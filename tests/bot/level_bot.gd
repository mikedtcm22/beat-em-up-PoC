extends "res://tests/bot/crowd_bot.gd"
## The level-run bot (Milestone 5, BOT): the crowd bot's harness (captions, the scripted player, the
## probe, the autopilot, the log lines) in a `LevelRoot`, playing the level arena by arena: it walks the
## route to the next arena, the arena locks, the autopilot fights until it clears, the gate opens, on to
## the next. The start-to-boss run is an act and its length is measured. Acts come from
## tests/bot/level_acts/*_acts.gd only (the crowd room's acts do not fit a level). Record with
##   tools/capture_bot.sh res://tests/bot/level_bot.tscn captures/<key> "Run: held back" 6
##   BOT_SCENE=res://tests/bot/level_bot.tscn tools/record_acts.sh captures/<round> "run|Run: held back"
## (CAPTURE_ARGS="--level=<res:// path> --from=<arena> --to=<arena>" picks the level and the arenas).
##
## Arguments after `--`: `--level=<res:// path>` (a `LevelRoot` scene or a lone `LevelSection` scene,
## which is wrapped as a one-section level; default the test strip), `--from=<arena>` and
## `--to=<arena>` (0-based; the run starts at `from` and ends when `to` is cleared; default the first
## and the last), `--presentation=0` (no cameras or HUD, for a headless timing), plus the crowd
## bot's own (`--act=`, `--seed=`, `--tune=`).
##
## Helpers for the act files, on top of the crowd bot's: walk_to(), walk_route(), run_arena(),
## run_level(), knock_off(). The log lines, each with its physics frame (see crowd_bot.gd for the rest):
##   ARENA+ f<frame> <id>                   an arena locked
##   WAVE f<frame> <id> <n>                 wave n of the arena in play began
##   ARENA- f<frame> <id> <seconds>         the arena cleared, seconds after it locked
##   LEVEL f<frame> <seconds>               run_level() cleared its last arena, seconds since it began
##   HAZARD f<frame> <enemy> <hazard>       a hazard volume KO'd an enemy
##   STALL f<frame> <what>                  a walk or a fight gave up (a budget ran out)
##   BLOCKED f<frame> <barrier>             a walk waited too long at a closed barrier
##   NOTE f<frame> <text>                   the bot changed its own style (the held-back pilot walks up)

const LEVEL_ACTS_DIR := "res://tests/bot/level_acts"
const DEFAULT_LEVEL := "res://tests/fixtures/level_strip.tscn"

@export_group("Run")
## The level scene (`--level=`).
@export var level_path: String = DEFAULT_LEVEL
## First and last arena of run_level() when an act does not say (`--from=`, `--to=`; -1 = the last).
@export var from_arena: int = 0
@export var to_arena: int = -1
## Build the cameras, HUD and effects (`--presentation=0` turns them off).
@export var presentation: bool = true
## Run the readability probe and the lock and crowd meters for each arena (run_arena's `measured`).
@export var measure_arenas: bool = true
@export_group("Walk")
## The look turns toward the next point at most this fast (degrees a second), and eases in
## (fraction of the remaining angle a tick), so the first-person view turns smoothly.
@export_range(30.0, 720.0) var walk_turn_deg_per_s: float = 200.0
@export_range(0.01, 1.0) var walk_turn_ease: float = 0.12
## The stick goes forward once the look is this close to the target (degrees).
@export_range(1.0, 180.0) var walk_forward_within_deg: float = 50.0
## A route point is reached within this flat distance (m).
@export_range(0.2, 3.0) var route_reach_m: float = 0.9
## A walk to one point gives up after this many seconds.
@export_range(2.0, 120.0) var point_budget_s: float = 30.0
## The walk stops this far short of a closed barrier (m), and gives up waiting for it after this long.
@export_range(0.5, 4.0) var barrier_stop_m: float = 1.0
@export_range(1.0, 120.0) var barrier_wait_s: float = 12.0
## Extra width and height past a barrier's opening that still count as being in its way (m).
@export_range(0.0, 2.0) var barrier_margin_m: float = 0.6
@export_group("Fight")
## An arena that is not cleared this long after it locked is given up (seconds).
@export_range(10.0, 900.0) var arena_budget_s: float = 150.0
## The held-back pilot starts walking up to enemies when it has not landed a hit for this long while
## some are alive (seconds), so a run cannot wait forever for a crowd that keeps its distance.
@export_range(2.0, 60.0) var stall_approach_s: float = 12.0
## After an arena clears, the bot stands this long (seconds) so the gate and the GO cue are seen.
@export_range(0.0, 10.0) var go_pause_s: float = 0.5
## At the end of a run to the last arena the bot stands this long (seconds) for the CLEAR cue.
@export_range(0.0, 10.0) var finish_pause_s: float = 1.5
@export_group("Knock-off")
## The player stands this far from the lip (m) and the Punk this far ahead of him.
@export_range(1.0, 8.0) var knock_stand_off_m: float = 3.0
@export_range(0.5, 4.0) var knock_gap_m: float = 1.6
## The launch (m/s): along the way to the lip, and up.
@export_range(2.0, 20.0) var knock_speed_mps: float = 9.0
@export_range(0.0, 12.0) var knock_lift_mps: float = 5.0
## Wait this long for the hazard to take the Punk (seconds).
@export_range(1.0, 20.0) var knock_wait_s: float = 6.0

var level: LevelRoot
## How many enemies a hazard volume has KO'd since the bot started.
var hazard_kos: int = 0

var _route_index: int = 0
var _barriers: Array[Barrier] = []
var _arena_frame: Dictionary = {}
var _run_frame: int = 0
var _last_hit_frame: int = 0


func _ready() -> void:
	super._ready()
	level = room as LevelRoot


## The level as a scene to instantiate: `level_path`'s LevelRoot scene, or a LevelRoot built round a
## lone section scene, with `presentation` applied.
func _room_scene() -> PackedScene:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			level_path = arg.trim_prefix("--level=")
		elif arg.begins_with("--from="):
			from_arena = int(arg.trim_prefix("--from="))
		elif arg.begins_with("--to="):
			to_arena = int(arg.trim_prefix("--to="))
		elif arg.begins_with("--presentation="):
			presentation = int(arg.trim_prefix("--presentation=")) != 0
	var scene := load(level_path) as PackedScene
	if scene == null:
		push_error("level_bot: '%s' is not a scene" % level_path)
		return load(DEFAULT_LEVEL) as PackedScene
	var instance := scene.instantiate()
	var root := instance as LevelRoot
	if root == null:
		if instance is LevelSection:
			root = LevelRoot.new()
			root.section_paths = PackedStringArray([level_path])
		else:
			push_error("level_bot: '%s' is neither a LevelRoot nor a LevelSection scene" % level_path)
			instance.free()
			return load(DEFAULT_LEVEL) as PackedScene
		instance.free()
	root.with_presentation = presentation
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


## Every act of tests/bot/level_acts/*_acts.gd, in file name order.
func _collect_acts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(LEVEL_ACTS_DIR)
	if dir == null:
		return out
	var files := PackedStringArray()
	for file in dir.get_files():
		if file.ends_with("_acts.gd"):
			files.append(file)
	files.sort()
	for file in files:
		var script := load(LEVEL_ACTS_DIR.path_join(file)) as GDScript
		if script:
			out.append_array(script.call(&"acts", self))
	return out


## The crowd bot's reset, for a level: every act starts at arena `from_arena` with the same names and
## seeds, the waves off (an act that wants them calls run_level()), the GO cue cleared.
func _reset(cam: StringName) -> void:
	clear_enemies()
	pilot.enabled = false
	pilot.stop()
	for knob: StringName in _pilot_defaults:
		pilot.set(knob, _pilot_defaults[knob])
	set_waves(false)
	freeze_ai(false)
	_keep_alive = 0
	_keep_alive_id = &"punk"
	for property: StringName in _tuned:
		Tuning.set_value(property, _tuned[property])
	_tuned.clear()
	Tuning.set_value(&"god_mode", false)
	_clear_floor_pipes()
	spawner.set(&"_serials", _fresh_serials())
	(spawner.get(&"_rng") as RandomNumberGenerator).seed = spawner.rng_seed
	_keep_alive_spawns = 0
	level.director.rng_seed = level.rng_seed
	player.input.clear_queue()
	player.input.scripted_move = Vector2.ZERO
	player.parser.release(&"DODGE")
	level.start_at_arena(from_arena)
	_route_start(from_arena)
	player.sim_velocity = Vector3.ZERO
	player.look_pitch = deg_to_rad(-6.0)
	player.parser.reset_chain()
	player.parser.clear_buffer()
	var hud := _hud()
	if hud and hud.get(&"go_cue") != null:
		(hud.get(&"go_cue") as Node).call(&"reset")
	if director:
		var guard := 0
		while director.get(&"mode") != cam and guard < 4:
			director.call(&"cycle")
			guard += 1
	await _ticks(2)


# --- Logs ----------------------------------------------------------------------------------


func _connect_logs() -> void:
	super._connect_logs()
	_barriers.clear()
	for section in level.sections:
		_barriers.append_array(section.barriers())
	CombatEvents.arena_locked.connect(_on_arena_locked)
	CombatEvents.arena_cleared.connect(_on_arena_cleared)
	CombatEvents.hazard_ko.connect(_on_hazard_ko)
	CombatEvents.hit_landed.connect(_on_player_hit)
	spawner.wave_started.connect(_on_wave_started)


func _on_arena_locked(arena: Node3D) -> void:
	_arena_frame[arena.get_instance_id()] = Engine.get_physics_frames()
	log_line("ARENA+ f%d %s" % [Engine.get_physics_frames(), _arena_name(arena)])


func _on_arena_cleared(arena: Node3D) -> void:
	var frame := Engine.get_physics_frames()
	var started: int = _arena_frame.get(arena.get_instance_id(), frame)
	log_line("ARENA- f%d %s %.1f" % [frame, _arena_name(arena), _seconds(frame - started)])


func _on_wave_started(number: int, _ids: PackedStringArray) -> void:
	var arena := level.current_arena()
	log_line("WAVE f%d %s %d" % [Engine.get_physics_frames(), _arena_name(arena), number])


func _on_hazard_ko(actor: Node3D, hazard: Node3D) -> void:
	hazard_kos += 1
	log_line("HAZARD f%d %s %s" % [Engine.get_physics_frames(), actor.name, hazard.name])


func _on_player_hit(hit: HitInfo) -> void:
	if hit.attacker == player and hit.victim != player:
		_last_hit_frame = Engine.get_physics_frames()


func _arena_name(arena: Node3D) -> String:
	var id := String((arena as Arena).arena_id) if arena is Arena else ""
	return id if id != "" else String(arena.name)


func _seconds(frames: int) -> float:
	return float(frames) / Engine.physics_ticks_per_second


# --- Walking -------------------------------------------------------------------------------


## Walk along the route to arena `arena_index` (-1: the last) until it locks. Returns true when it is
## locked (or was), false when a walk gave up (a stall or a closed barrier that did not open; the log
## says which).
func walk_route(arena_index: int = -1) -> bool:
	var arenas := level.arenas()
	if arenas.is_empty():
		return false
	var arena := arenas[clampi(arena_index if arena_index >= 0 else arenas.size() - 1, 0, arenas.size() - 1)]
	var route := level.route_points()
	var budget := int(point_budget_s * Engine.physics_ticks_per_second)
	while arena.state == Arena.State.WAITING and _route_index < route.size():
		var locked := func() -> bool: return arena.state != Arena.State.WAITING
		var reached: bool = await walk_to(route[_route_index], route_reach_m, budget, locked)
		if arena.state != Arena.State.WAITING:
			break
		if not reached:
			return false
		_route_index += 1
	player.input.scripted_move = Vector2.ZERO
	return arena.state != Arena.State.WAITING


## Walk the scripted player to `point` (flat distance within `tolerance`), the look easing round to it,
## holding forward once it faces the way, never into a closed barrier (it stops barrier_stop_m short
## and waits for it to open). Ends early when `until` (a Callable returning bool) says so. Returns
## true on arrival or `until`; false after `budget` ticks, or a barrier that stayed shut.
func walk_to(point: Vector3, tolerance: float, budget: int, until: Callable = Callable()) -> bool:
	var waited := 0
	var wait_limit := int(barrier_wait_s * Engine.physics_ticks_per_second)
	for i in budget:
		if until.is_valid() and until.call():
			player.input.scripted_move = Vector2.ZERO
			return true
		var flat := point - player.global_position
		flat.y = 0.0
		if flat.length() <= tolerance:
			player.input.scripted_move = Vector2.ZERO
			return true
		var barrier := _barrier_in_the_way(player.global_position, point)
		var gap := -barrier.past(player.global_position) if barrier else INF
		_steer(point)
		if gap < barrier_stop_m:
			player.input.scripted_move = Vector2.ZERO
			waited += 1
			if waited > wait_limit:
				log_line("BLOCKED f%d %s" % [Engine.get_physics_frames(), barrier.name])
				return false
		else:
			waited = 0
		await get_tree().physics_frame
	player.input.scripted_move = Vector2.ZERO
	log_line("STALL f%d walk to (%.1f, %.1f, %.1f)" % [Engine.get_physics_frames(), point.x, point.y, point.z])
	return false


## One tick of steering toward `point`: the look eases round to it (rate limited), and the stick is
## held forward once the look is near it.
func _steer(point: Vector3) -> void:
	var d := point - player.global_position
	var want := atan2(-d.x, -d.z)
	var error := wrapf(want - player.look_yaw, -PI, PI)
	var max_step := deg_to_rad(walk_turn_deg_per_s) / Engine.physics_ticks_per_second
	player.look_yaw = wrapf(player.look_yaw + clampf(error * walk_turn_ease, -max_step, max_step), -PI, PI)
	var forward := absf(error) <= deg_to_rad(walk_forward_within_deg)
	player.input.scripted_move = Vector2(0.0, 1.0) if forward else Vector2.ZERO


## The nearest closed barrier the straight walk from `from` to `to` crosses, or null.
func _barrier_in_the_way(from: Vector3, to: Vector3) -> Barrier:
	var best: Barrier = null
	var best_gap := INF
	for barrier in _barriers:
		if not barrier.is_closed():
			continue
		var before := barrier.past(from)
		var after := barrier.past(to)
		if before >= 0.0 or after <= 0.0:
			continue
		var cross := from + (to - from) * (before / (before - after))
		var local := barrier.global_transform.affine_inverse() * cross
		if absf(local.x) > barrier.width_m * 0.5 + barrier_margin_m \
				or local.y < -barrier_margin_m or local.y > barrier.height_m + barrier_margin_m:
			continue
		if -before < best_gap:
			best_gap = -before
			best = barrier
	return best


## The route index to walk to next when the run starts at arena `index` (the player stands at that
## arena's first route point, or at `Start` for the first).
func _route_start(index: int) -> void:
	_route_index = 0
	var arenas := level.arenas()
	if index <= 0 or index >= arenas.size():
		return
	var first := level.first_route_point(arenas[index])
	var route := level.route_points()
	for i in route.size():
		if route[i].is_equal_approx(first):
			_route_index = i + 1
			return


# --- Running -------------------------------------------------------------------------------


## Play the level from arena `from` to arena `to` (-1: the last): the player starts at `from`, waves
## on, then run_arena() for each. Logs `LEVEL` when `to` is cleared. Returns true when every arena
## cleared.
func run_level(from: int = 0, to: int = -1, held_back: bool = false, measured: bool = true) -> bool:
	var arenas := level.arenas()
	if arenas.is_empty():
		return false
	from = clampi(from, 0, arenas.size() - 1)
	to = clampi(to if to >= 0 else arenas.size() - 1, from, arenas.size() - 1)
	level.start_at_arena(from)
	_route_start(from)
	set_waves(true)
	_run_frame = Engine.get_physics_frames()
	for i in range(from, to + 1):
		if not await run_arena(held_back, measured):
			return false
		if i < to:
			await _ticks(int(go_pause_s * Engine.physics_ticks_per_second))
	log_line("LEVEL f%d %.1f" % [Engine.get_physics_frames(), _seconds(Engine.get_physics_frames() - _run_frame)])
	if to == arenas.size() - 1:
		await _ticks(int(finish_pause_s * Engine.physics_ticks_per_second))
	return true


## Play the current arena: walk the route in until it locks, then the autopilot fights (the held-back
## style when `held_back`: real damage, no walking up to anyone unless it stalls) until the arena
## clears. With `measured` and `measure_arenas`, the readability probe and the lock meter run over the
## fight (title: the act's caption and the arena's id). Returns true when it cleared.
func run_arena(held_back: bool = false, measured: bool = true) -> bool:
	var arena := level.current_arena()
	if arena == null:
		return false
	var name_text := _arena_name(arena)
	if arena.state == Arena.State.WAITING and not await walk_route(level.arenas().find(arena)):
		return false
	if arena.state == Arena.State.CLEARED:
		return true
	var title := "%s: %s" % [caption.text, name_text]
	var measure := measured and measure_arenas
	if measure:
		_start_measuring(title, {})
	if held_back:
		hold_back()
	pilot.enabled = true
	var start := Engine.get_physics_frames()
	_last_hit_frame = start
	var budget := int(arena_budget_s * Engine.physics_ticks_per_second)
	var stall := int(stall_approach_s * Engine.physics_ticks_per_second)
	while arena.state == Arena.State.LOCKED and Engine.get_physics_frames() - start < budget:
		await get_tree().physics_frame
		var frame := Engine.get_physics_frames()
		if _alive_count() == 0:
			_last_hit_frame = frame
		elif not pilot.approach and frame - _last_hit_frame >= stall:
			pilot.approach = true
			log_line("NOTE f%d %s: no hit for %.0f s, the pilot walks up" % [frame, name_text, _seconds(stall)])
	var cleared := arena.state == Arena.State.CLEARED
	if measure:
		_stop_measuring(title)
	else:
		pilot.enabled = false
		pilot.stop()
	if not cleared:
		log_line("STALL f%d arena %s not cleared in %.0f s" % [Engine.get_physics_frames(), name_text, arena_budget_s])
	return cleared


func _alive_count() -> int:
	var count := 0
	for enemy in level.enemies():
		if enemy.health > 0.0:
			count += 1
	return count


# --- Knock-off -----------------------------------------------------------------------------


## The first arena (level order) that has a hazard volume beside it, as {arena: int, hazard:
## HazardVolume}; empty when the level has none. A hazard belongs to the arena whose lock volume it
## is nearest to (flat gap between the two boxes).
func first_hazard() -> Dictionary:
	var arenas := level.arenas()
	var best := {}
	for node: Node in get_tree().get_nodes_in_group(HazardVolume.GROUP):
		var hazard := node as HazardVolume
		if hazard == null:
			continue
		var owner_index := -1
		var owner_gap := INF
		for i in arenas.size():
			var gap := _box_gap(hazard.global_position, hazard.size, arenas[i])
			if gap < owner_gap:
				owner_gap = gap
				owner_index = i
		if owner_index >= 0 and (best.is_empty() or owner_index < int(best.arena)):
			best = {arena = owner_index, hazard = hazard}
	return best


## The flat gap (m) between a box (centre, size) and `arena`'s lock volume (0 when they overlap).
func _box_gap(centre: Vector3, size: Vector3, arena: Arena) -> float:
	var trigger := arena.get_node_or_null("LockTrigger")
	if trigger == null:
		return INF
	for child in trigger.get_children():
		var shape := child as CollisionShape3D
		if shape and shape.shape is BoxShape3D:
			var half := (shape.shape as BoxShape3D).size * 0.5
			var dx := maxf(absf(centre.x - shape.global_position.x) - half.x - size.x * 0.5, 0.0)
			var dz := maxf(absf(centre.z - shape.global_position.z) - half.z - size.z * 0.5, 0.0)
			return Vector2(dx, dz).length()
	return INF


## In the first arena with a hazard: the player walks to the lip, stands knock_stand_off_m short of it,
## a Punk appears ahead of him and is launched over the edge, and the hazard takes it (`HAZARD` in the
## log). Returns true when the hazard KO'd it.
func knock_off() -> bool:
	var found := first_hazard()
	if found.is_empty():
		log_line("NOTE f%d no hazard volume in this level" % Engine.get_physics_frames())
		return false
	var hazard: HazardVolume = found.hazard
	level.start_at_arena(int(found.arena))
	_route_start(int(found.arena))
	await _ticks(2)
	# The point of the hazard's box nearest the player, flat, and the way to it.
	var local := hazard.global_transform.affine_inverse() * player.global_position
	var half := hazard.size * 0.5
	var lip_local := Vector3(clampf(local.x, -half.x, half.x), local.y, clampf(local.z, -half.z, half.z))
	var lip := hazard.global_transform * lip_local
	var way := lip - player.global_position
	way.y = 0.0
	var distance := way.length()
	if distance < 0.01:
		return false
	way /= distance
	if distance > knock_stand_off_m:
		var stand := player.global_position + way * (distance - knock_stand_off_m)
		await walk_to(stand, 0.4, int(point_budget_s * Engine.physics_ticks_per_second))
	await _face_way(way)
	freeze_ai(true)
	var punk := spawn(&"punk", Vector2(0.0, knock_gap_m))
	await _ticks(30)
	if punk == null or not is_instance_valid(punk):
		return false
	var before := hazard_kos
	var hit := HitInfo.new()
	hit.attacker = player
	hit.victim = punk
	hit.damage = 5.0
	hit.tier = CombatTypes.HitTier.HEAVY
	hit.reaction = CombatTypes.Reaction.LAUNCH
	hit.direction = way
	hit.knockback = way * knock_speed_mps + Vector3.UP * knock_lift_mps
	hit.contact_point = punk.global_position + Vector3.UP
	punk.receive_hit(hit)
	await _wait_until(func() -> bool: return hazard_kos > before, int(knock_wait_s * Engine.physics_ticks_per_second))
	await _ticks(30)
	return hazard_kos > before


## Ease the look round to flat direction `way` and hold still a moment.
func _face_way(way: Vector3) -> void:
	player.input.scripted_move = Vector2.ZERO
	for i in 120:
		_steer(player.global_position + way)
		player.input.scripted_move = Vector2.ZERO
		await get_tree().physics_frame
		var error := wrapf(atan2(-way.x, -way.z) - player.look_yaw, -PI, PI)
		if absf(error) < deg_to_rad(1.0):
			break
	await _ticks(10)
