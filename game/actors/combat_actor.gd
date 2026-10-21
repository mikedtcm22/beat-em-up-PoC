class_name CombatActor
extends CharacterBody3D
## Base for every fighter (player, dummies, enemies). API skeleton: the implementation
## lands with the actor core. See docs/ARCHITECTURE.md "Interfaces between modules".

@export var max_health: float = 100.0
## 0 = player, 1 = enemies.
@export var team: int = 1
@export var display_name: String = "Actor"

var health: float = 100.0
var state: CombatTypes.ActorState = CombatTypes.ActorState.FREE
var rig: HumanoidRig
var current_move: MoveData
## 0-based frame within current_move.
var move_frame: int = 0
## Hitbox volumes live this sim frame, for debug draw. See ARCHITECTURE.md for the format.
var debug_hitbox_volumes: Array[Dictionary] = []


func is_ko() -> bool:
	return state == CombatTypes.ActorState.KO


func is_downed() -> bool:
	return state == CombatTypes.ActorState.DOWNED


func is_invulnerable() -> bool:
	return false


func get_head_top_position() -> Vector3:
	return global_position + Vector3.UP * 2.0


func get_chest_position() -> Vector3:
	return global_position + Vector3.UP * 1.3


## Apply a landed hit. Returns false if the hit was ignored (invulnerable, KO, ...).
func receive_hit(_hit: HitInfo) -> bool:
	return false


func debug_state_text() -> String:
	return CombatTypes.state_name(state)
