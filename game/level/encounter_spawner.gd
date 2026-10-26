class_name EncounterSpawner
extends Node3D
## Puts enemies into a room and runs its waves (Milestone 3, SPEC §7: "Spawns: at most 6 enemies
## alive at once. Spawn points sit in doorways, alleys, vehicles and stairwells, and some arenas
## spawn enemies behind the player"). Group "encounter_spawner".
##
## Spawning: spawn_enemy() builds an enemy from the catalog (or `scene_override`), names it
## "<Archetype><n>" (display name "Punk 3"), places it before it enters the tree and tells it
## enter_from(spawn point, lane point); spawn_adds() brings reinforcements in at the free spawn
## points nearest a spot (the boss's call-in).
##
## Waves (Tuning "Waves"): the table's waves play in turn, forever. A wave starts wave_gap_s after
## the one before is cleared (every enemy it spawned has health <= 0; the first waits wave_gap_s
## after the room is ready), spawns one enemy every wave_spawn_interval_s, and never lets more
## than wave_max_alive AI enemies live at once (F4 spawns count toward that, but only waves are
## held back by it). Each spawn is chosen when it happens, from the points that are at least
## spawn_min_player_distance_m from the player and have room (SpawnRoomCheck): about
## wave_behind_share of each wave comes from points outside the player's view (the same
## "outside the view" as the director's blind spot and the rear warning), the rest from the
## others, picked with a seeded random generator. Waves are held while a menu is open
## (GameInput.menu_open, the F1 and F4 menus): no timer runs and nothing spawns. Whether they run
## at all is the tunable waves_enabled (set_waves_enabled() writes it, so F1 and F4 agree).
## Timers run in sim time (slow-mo and the F4 0.25x slow them).

## A wave has just started: its number (1 for the first) and the ids it will spawn.
signal wave_started(number: int, ids: PackedStringArray)
## Every enemy of wave `number` is down; the gap to the next wave starts.
signal wave_cleared(number: int)

const GROUP := &"encounter_spawner"
const TABLE_PATH := "res://game/level/encounters/crowd_waves.tres"
## The enemy a wave uses in place of an id that has no scene (an archetype not built yet).
const FALLBACK_ID := &"punk"

## Seeds the spawn point choice.
@export var rng_seed: int = 0

## Where enemies may walk in from: {position: Vector3, yaw: float (the way it faces on
## arrival), tag: StringName (&"doorway", &"alley" or &"vehicle"), lane_point: Vector3 (where
## it walks to first)}. The room fills it in.
var spawn_points: Array[Dictionary] = []
## Tests: enemy id -> the PackedScene to spawn instead of the catalog's.
var scene_override: Dictionary = {}
## The waves (crowd_waves.tres unless a test sets another).
var table: EncounterTable
## The node enemies are added to: this node's parent (the room) unless set.
var host: Node3D

enum _Phase { GAP, SPAWNING, FIGHTING }

var _rng := RandomNumberGenerator.new()
## Archetype label -> enemies of it spawned so far (the n in "Punk 3").
var _serials: Dictionary = {}
var _phase: _Phase = _Phase.GAP
## Sim seconds left of the gap before a wave, or until the next spawn of one.
var _timer: float = 0.0
## Waves started so far.
var _started: int = 0
var _queue: Array[StringName] = []
var _wave_size: int = 0
var _wave_spawned: int = 0
var _wave_behind: int = 0
var _wave_behind_quota: int = 0
var _members: Array[EnemyActor] = []
## The spawn point index used last, so one point is not used twice in a row (unless alone).
var _last_point: int = -1


func _ready() -> void:
	add_to_group(GROUP)
	_rng.seed = rng_seed
	if table == null and ResourceLoader.exists(TABLE_PATH):
		table = load(TABLE_PATH) as EncounterTable
	_timer = Tuning.data.wave_gap_s


## Instantiate enemy `id`'s scene as an EnemyActor and name it: "<Archetype><n>" with n counted
## in `serials` (a Dictionary the caller keeps, label -> count), display name "Punk 3". The
## archetype is the actor's own, or `id` when it has none. Not yet in the tree, not placed.
## Null when the scene is not an EnemyActor (the training dummy is not one).
static func make_enemy(scene: PackedScene, id: StringName, serials: Dictionary) -> EnemyActor:
	var node := scene.instantiate()
	var enemy := node as EnemyActor
	if enemy == null:
		node.free()
		return null
	var label := String(enemy.archetype if enemy.archetype != &"" else id).capitalize()
	var number := int(serials.get(label, 0)) + 1
	serials[label] = number
	enemy.name = "%s%d" % [label, number]
	# The boss is one of a kind: its HUD bar reads "BOSS", not "BOSS 1".
	enemy.display_name = label if enemy.archetype == &"boss" else "%s %d" % [label, number]
	return enemy


## Spawn enemy `id` standing at `at` (a floor point) facing `yaw`, and let it walk in:
## enter_from(at, lane_point), `lane_point` defaulting to `at` (it is already there). `from_wave`
## makes it part of the running wave (the wave is not cleared while it lives). Null when `id`
## has no scene or is not an EnemyActor.
func spawn_enemy(id: StringName, at: Vector3, yaw: float, from_wave: bool = false,
		lane_point: Vector3 = Vector3.INF) -> EnemyActor:
	var scene := _scene_for(id)
	var parent := _host()
	if scene == null or parent == null:
		return null
	var enemy := make_enemy(scene, id, _serials)
	if enemy == null:
		return null
	enemy.position = parent.to_local(at)
	enemy.rotation.y = yaw - parent.global_rotation.y
	parent.add_child(enemy)
	enemy.enter_from(at, lane_point if lane_point.is_finite() else at)
	if from_wave:
		_members.append(enemy)
	return enemy


## Reinforcements (the boss calls in two Punks at half health): up to `count` of enemy `id` at the
## free spawn points nearest `near`, each at least spawn_min_player_distance_m from the player
## and with room, no two at one point. They join the running wave. Fewer when fewer points are
## free.
func spawn_adds(id: StringName, count: int, near: Vector3) -> Array[EnemyActor]:
	var out: Array[EnemyActor] = []
	var free := valid_point_indices(EnemyCatalog.body_size(id))
	free.sort_custom(func(a: int, b: int) -> bool:
		return _flat_distance(spawn_points[a].position, near) < _flat_distance(spawn_points[b].position, near))
	for index in free:
		if out.size() >= count:
			break
		var point := spawn_points[index]
		var enemy := spawn_enemy(id, point.position, point.yaw, true, point.lane_point)
		if enemy:
			out.append(enemy)
	return out


## Take enemies out of `tree` now: every member of "ai_enemy", or with `only_ai` false every
## member of "enemy" too (the training dummies). Each leaves its groups first, so a scan in the
## same frame no longer finds it, then is freed. Returns how many.
static func remove_enemies(tree: SceneTree, only_ai: bool = false) -> int:
	var doomed: Array[Node] = []
	for node: Node in tree.get_nodes_in_group(&"ai_enemy"):
		doomed.append(node)
	if not only_ai:
		for node: Node in tree.get_nodes_in_group(&"enemy"):
			if not doomed.has(node):
				doomed.append(node)
	for node in doomed:
		for group: StringName in [&"ai_enemy", &"enemy", &"actor", &"boss"]:
			if node.is_in_group(group):
				node.remove_from_group(group)
		node.queue_free()
	return doomed.size()


## AI enemies alive now: members of "ai_enemy" with health above 0 (a KO'd one lying on the
## floor is not alive).
func alive_count() -> int:
	var count := 0
	for node: Node in get_tree().get_nodes_in_group(&"ai_enemy"):
		var enemy := node as CombatActor
		if enemy and not enemy.is_queued_for_deletion() and enemy.health > 0.0:
			count += 1
	return count


## Waves on or off (the tunable waves_enabled, so the F1 panel and the F4 button agree). Off,
## nothing spawns and no timer runs; the wave in progress carries on when they are turned on.
func set_waves_enabled(on: bool) -> void:
	Tuning.set_value(&"waves_enabled", on)


## Waves started so far (the running wave counts).
func waves_started() -> int:
	return _started


## Make wave `number` (1 = the first; boss waves count, as in wave_started) the next to start,
## after a full wave_gap_s: a bot or a test reaches a later wave without playing the earlier ones.
## The wave in progress is dropped (what is still queued never spawns; what already spawned stays
## in the room as ordinary enemies and no longer holds the next wave), and waves_started() reads
## number - 1 until the new wave begins. start_at_wave(1) starts the sequence over. A number
## under 1 is 1.
func start_at_wave(number: int) -> void:
	_started = maxi(number, 1) - 1
	_phase = _Phase.GAP
	_timer = Tuning.data.wave_gap_s
	_queue.clear()
	_members.clear()
	_wave_size = 0
	_wave_spawned = 0
	_wave_behind = 0
	_wave_behind_quota = 0
	_last_point = -1


## True from a wave's first spawn until its last enemy is down.
func wave_running() -> bool:
	return _phase != _Phase.GAP


## The id a wave spawns for `id`: `id` itself when it has a scene (an override or the catalog's),
## else FALLBACK_ID (the Punk) when that has one, else `id` (it will spawn nothing).
func resolve_id(id: StringName) -> StringName:
	if _scene_for(id) != null or _scene_for(FALLBACK_ID) == null:
		return id
	return FALLBACK_ID


## Indices into spawn_points of the points an enemy with a `body` capsule (Vector2 radius,
## height) may appear at now: far enough from the player (spawn_min_player_distance_m) and with
## room (SpawnRoomCheck).
func valid_point_indices(body: Vector2) -> Array[int]:
	var out: Array[int] = []
	var player := _player()
	var space := get_world_3d().direct_space_state
	for i in spawn_points.size():
		var at: Vector3 = spawn_points[i].position
		if player and _flat_distance(player.global_position, at) < Tuning.data.spawn_min_player_distance_m:
			continue
		if SpawnRoomCheck.has_room(space, body.x, body.y, at):
			out.append(i)
	return out


## Whether spawn point `point` is outside the player's view (the blind spot); false with no player.
func is_behind(point: Dictionary) -> bool:
	var player := _player()
	return player != null and player.is_outside_view(point.position, Tuning.data.rear_warning_angle_deg)


func _physics_process(delta: float) -> void:
	if GameInput.menu_open or not Tuning.data.waves_enabled:
		return
	var step := delta * TimeController.sim_scale()
	_prune_members()
	match _phase:
		_Phase.GAP:
			_timer -= step
			if _timer <= 0.0 and _begin_wave():
				_phase = _Phase.SPAWNING
				_timer = 0.0
		_Phase.SPAWNING:
			_timer -= step
			if _timer <= 0.0:
				_timer = Tuning.data.wave_spawn_interval_s
				_spawn_next()
			if _queue.is_empty():
				_phase = _Phase.FIGHTING
		_Phase.FIGHTING:
			if _members.is_empty():
				_phase = _Phase.GAP
				_timer = Tuning.data.wave_gap_s
				wave_cleared.emit(_started)


## Start the next wave of the table; false when the table has none.
func _begin_wave() -> bool:
	if table == null:
		return false
	var ids := table.wave_at(_started, Tuning.data.boss_wave_every)
	if ids.is_empty():
		return false
	_started += 1
	_queue.clear()
	for id in ids:
		_queue.append(resolve_id(StringName(id)))
	_wave_size = _queue.size()
	_wave_spawned = 0
	_wave_behind = 0
	_wave_behind_quota = roundi(_wave_size * Tuning.data.wave_behind_share)
	wave_started.emit(_started, ids)
	return true


## Spawn the first id of the queue at a point chosen now, if the cap and the points allow it.
func _spawn_next() -> void:
	if alive_count() >= Tuning.data.wave_max_alive:
		return
	var id := _queue[0]
	var body := EnemyCatalog.body_size(id)
	var valid := valid_point_indices(body)
	if valid.size() > 1 and valid.has(_last_point):
		valid.erase(_last_point)
	# A random order that still hits the wave's quota of "behind" spawns: the chance of the next
	# one being from behind is what is left of the quota over what is left of the wave.
	var want_behind := _rng.randf() * float(_wave_size - _wave_spawned) < float(_wave_behind_quota - _wave_behind)
	var behind: Array[int] = []
	var ahead: Array[int] = []
	for index in valid:
		(behind if is_behind(spawn_points[index]) else ahead).append(index)
	var pool := behind if want_behind else ahead
	if pool.is_empty():
		pool = ahead if want_behind else behind
	if pool.is_empty():
		return  # nowhere to put it now: try again at the next spawn time
	var index := pool[_rng.randi() % pool.size()]
	var point := spawn_points[index]
	_last_point = index
	_queue.remove_at(0)
	_wave_spawned += 1
	if is_behind(point):
		_wave_behind += 1
	spawn_enemy(id, point.position, point.yaw, true, point.lane_point)


func _prune_members() -> void:
	var alive: Array[EnemyActor] = []
	for enemy in _members:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.health > 0.0:
			alive.append(enemy)
	_members = alive


func _scene_for(id: StringName) -> PackedScene:
	var scene := scene_override.get(id) as PackedScene
	return scene if scene else EnemyCatalog.scene(id)


func _host() -> Node3D:
	if is_instance_valid(host):
		return host
	return get_parent() as Node3D


func _player() -> PlayerCharacter:
	return get_tree().get_first_node_in_group(&"player") as PlayerCharacter


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
