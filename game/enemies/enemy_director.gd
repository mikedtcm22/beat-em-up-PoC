class_name EnemyDirector
extends Node
## The enemy director (Milestone 3, SPEC §7): hands out attack tokens (at most
## Tuning.data.attacker_cap attack at once, 0 = unlimited; blind-spot enemies first), spreads
## the waiting enemies around the player on the posture ring and paces the wind-ups, so a crowd
## attacks in turns the player can read. It is not an actor: it runs its own _physics_process on
## `delta * TimeController.sim_scale()` (so it keeps running through hitstop) with a seeded RNG,
## and holds while GameInput.menu_open. Lives in group "enemy_director".
##
## This is the skeleton (the contract, docs/ARCHITECTURE.md "Enemy AI and the rear warning"):
## find() and ensure() work, the read API answers "nobody holds anything" and may_start_windup()
## always says go. The tests of other packages run against tests/fixtures/stub_director.gd,
## which sets the lists the read API returns. Implemented by P1-director.

## Seeds the director's random rolls (the blind-spot priority roll, slot jitter).
@export var rng_seed: int = 0


func _ready() -> void:
	add_to_group(&"enemy_director")


## The director in `tree`, or null.
static func find(tree: SceneTree) -> EnemyDirector:
	return tree.get_first_node_in_group(&"enemy_director") as EnemyDirector


## The director in `host`'s tree, or a new one added under `host` (an enemy spawned by F4 in the
## training room has none). `host` must be in the tree. Idempotent.
static func ensure(host: Node) -> EnemyDirector:
	var found := find(host.get_tree())
	if found:
		return found
	var director := EnemyDirector.new()
	director.name = "EnemyDirector"
	host.add_child(director)
	return director


## The enemy's attack ended, was interrupted or timed out: its token goes back.
func release_token(_enemy: EnemyActor) -> void:
	pass


## The posture slot (world position) assigned to `enemy`; Vector3.INF = none.
func slot_for(_enemy: EnemyActor) -> Vector3:
	return Vector3.INF


## An enemy holding a token calls this right before it winds up: true means "go now" and the
## director records that wind-up start. The implementation holds the enemy back until
## Tuning.data.director_min_windup_gap_s has passed since another enemy's wind-up began, so no
## two wind-ups start together. The skeleton always says go.
func may_start_windup(_enemy: EnemyActor) -> bool:
	return true


# --- Read API for the F3 overlay and tests (presentation reads, never writes) ---


## The enemies holding a token now.
func debug_token_holders() -> Array[EnemyActor]:
	return []


## `enemy`'s posture slot, Vector3.INF when it has none.
func debug_slot_of(_enemy: EnemyActor) -> Vector3:
	return Vector3.INF


## The posture ring's nearest and furthest distance from the player (m).
func debug_ring() -> Vector2:
	return Vector2(Tuning.data.posture_ring_min_m, Tuning.data.posture_ring_max_m)


## Most simultaneous attackers (0 = unlimited).
func attacker_cap() -> int:
	return Tuning.data.attacker_cap


## The enemies that want a token and have none, longest waiting first.
func debug_waiting() -> Array[EnemyActor]:
	return []
