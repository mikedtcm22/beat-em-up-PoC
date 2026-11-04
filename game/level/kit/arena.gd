class_name Arena
extends Node3D
## One arena of a level (Milestone 5, D9): a stretch of floor between two barriers where a fight
## happens. While WAITING it watches the player; once he is inside its lock volume and the
## `arena_lock_inset_m` past its behind barrier it LOCKS: the behind barrier closes (the ahead one
## has been closed since the level began), `locked` and `CombatEvents.arena_locked` fire, and the
## level hands its table and spawn points to the spawner. When the table has finished `clear()`
## opens the ahead barrier and `cleared` and `CombatEvents.arena_cleared` fire (the GO cue).
##
## Children: `LockTrigger` (an Area3D whose BoxShape3D is the arena's volume: from its behind
## barrier to its ahead one, floor to clear height; a stair that joins two arenas belongs to the one
## below, so its volume runs up the stair to the barrier at the stair's head), `Respawn` (a Marker3D:
## where a fall puts the player back) and `SpawnPoint`s (anywhere below this node). Every spawn point
## and its lane point lie inside the volume. Arenas are separate navmesh islands: the bake runs with
## every barrier closed.
##
## `behind_barrier` and `ahead_barrier` are paths from this node; an empty behind on a section's first
## arena means the previous section's ExitBarrier (LevelRoot wires it with `bind_behind()`), an
## empty ahead on a section's last arena means its own ExitBarrier (`bind_ahead()`).

enum State { WAITING, LOCKED, CLEARED }

## The lock closed behind the player.
signal locked()
## The table is finished and the ahead barrier opens.
signal cleared()

const GROUP := &"arena"

@export var arena_id: StringName = &""
## The waves of this arena (a finite EncounterTable); the boss arena's is `["boss"]`.
@export var table: EncounterTable
@export var behind_barrier: NodePath
@export var ahead_barrier: NodePath
## Watches the player (the level arms an arena once the one before it is cleared).
@export var armed: bool = true

var state: State = State.WAITING
var behind: Barrier
var ahead: Barrier


func _ready() -> void:
	add_to_group(GROUP)
	if behind == null and not behind_barrier.is_empty():
		behind = get_node_or_null(behind_barrier) as Barrier
	if ahead == null and not ahead_barrier.is_empty():
		ahead = get_node_or_null(ahead_barrier) as Barrier


## Use `barrier` as the behind barrier when none is named (the previous section's seam shutter).
func bind_behind(barrier: Barrier) -> void:
	if behind == null:
		behind = barrier


## Use `barrier` as the ahead barrier when none is named (this section's own ExitBarrier).
func bind_ahead(barrier: Barrier) -> void:
	if ahead == null:
		ahead = barrier


## Close the lock now (a test or a bot may call it; the level calls it when the player crosses the
## inset). Does nothing unless WAITING.
func lock() -> void:
	if state != State.WAITING:
		return
	state = State.LOCKED
	if behind:
		behind.close()
	locked.emit()
	CombatEvents.arena_locked.emit(self)


## The fight is won: open the ahead barrier. Does nothing once CLEARED.
func clear() -> void:
	if state == State.CLEARED:
		return
	state = State.CLEARED
	if ahead:
		ahead.open()
	cleared.emit()
	CombatEvents.arena_cleared.emit(self)


## Back to WAITING with no signals (the level restarting at an arena): the ahead barrier to its
## start state, the behind barrier open unless the level starts it closed.
func reset_waiting() -> void:
	state = State.WAITING
	if ahead:
		ahead.snap(ahead.start_closed)
	if behind:
		behind.snap(behind.start_closed)


## CLEARED with no signals (an arena before the one the level starts at): both barriers open.
func reset_cleared() -> void:
	state = State.CLEARED
	if ahead:
		ahead.snap(false)
	if behind:
		behind.snap(false)


## Whether `point` is inside this arena's lock volume (its LockTrigger's box).
func contains(point: Vector3) -> bool:
	var shape := _volume_shape()
	if shape == null:
		return false
	var box := shape.shape as BoxShape3D
	var local := shape.global_transform.affine_inverse() * point
	var half := box.size * 0.5
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z


## Whether `point` is far enough past the behind barrier for the lock to close (always, with none).
func past_inset(point: Vector3) -> bool:
	return behind == null or behind.past(point) >= Tuning.data.arena_lock_inset_m


## Where the player goes back to after a fall (the Respawn marker; this node's origin without one).
func respawn_position() -> Vector3:
	var marker := get_node_or_null("Respawn") as Node3D
	return marker.global_position if marker else global_position


## Every SpawnPoint below this node, in tree order.
func spawn_points() -> Array[SpawnPoint]:
	var out: Array[SpawnPoint] = []
	_collect(self, out)
	return out


## The spawner's points: {position, yaw, tag, lane_point, name} of each SpawnPoint.
func spawn_point_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for point in spawn_points():
		out.append(point.as_point())
	return out


func _physics_process(_delta: float) -> void:
	if state != State.WAITING or not armed:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player and contains(player.global_position) and past_inset(player.global_position):
		lock()


func _volume_shape() -> CollisionShape3D:
	var trigger := get_node_or_null("LockTrigger")
	if trigger == null:
		return null
	for child in trigger.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			return child as CollisionShape3D
	return null


static func _collect(node: Node, out: Array[SpawnPoint]) -> void:
	for child in node.get_children():
		if child is SpawnPoint:
			out.append(child)
		_collect(child, out)
