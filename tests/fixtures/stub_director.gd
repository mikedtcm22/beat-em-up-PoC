extends EnemyDirector
## A test-only EnemyDirector (M3-plan A2.12): its holders, slots and waiting lists are whatever a
## test sets, and it never decides anything on its own. The read API answers from them; the calls
## the enemies make are recorded. Add it to the tree and EnemyDirector.find()/ensure() return it.

## What debug_token_holders(), debug_waiting() and debug_slot_of() answer.
var holders: Array[EnemyActor] = []
var waiting: Array[EnemyActor] = []
var slots: Dictionary = {}
## debug_ring(), unless left at zero (then the tunables').
var ring: Vector2 = Vector2.ZERO
## attacker_cap(), unless negative (then the tunable).
var cap: int = -1
## What may_start_windup() answers.
var windup_allowed: bool = true

## Every release_token() and may_start_windup() call, in order.
var released: Array[EnemyActor] = []
var windup_asks: Array[EnemyActor] = []


## Give `enemy` a token as the director would (it joins holders).
func give_token(enemy: EnemyActor, blind: bool = false) -> void:
	holders.append(enemy)
	enemy.grant_token(blind)


## Give `enemy` a posture slot as the director would.
func put_slot(enemy: EnemyActor, pos: Vector3) -> void:
	slots[enemy] = pos
	enemy.set_slot(pos)


func release_token(enemy: EnemyActor) -> void:
	released.append(enemy)
	holders.erase(enemy)
	if is_instance_valid(enemy) and enemy.has_token:
		enemy.revoke_token()


func slot_for(enemy: EnemyActor) -> Vector3:
	return slots.get(enemy, Vector3.INF)


func may_start_windup(enemy: EnemyActor) -> bool:
	windup_asks.append(enemy)
	return windup_allowed


func debug_token_holders() -> Array[EnemyActor]:
	return holders.duplicate()


func debug_slot_of(enemy: EnemyActor) -> Vector3:
	return slot_for(enemy)


func debug_ring() -> Vector2:
	return ring if ring != Vector2.ZERO else super.debug_ring()


func attacker_cap() -> int:
	return cap if cap >= 0 else super.attacker_cap()


func debug_waiting() -> Array[EnemyActor]:
	return waiting.duplicate()
