class_name EnemyAttack
extends RefCounted
## What one attack token buys an enemy (Milestone 3): a chain of moves the AI starts itself, one
## after the other (never through ComboParser, branches or auto_next). The first move is the
## telegraph: the AI winds it up (EnemyActor.windup_move()), and a chain link after it starts with
## no wind-up of its own, only if the previous hit landed or was blocked (M3-plan A2.14). An
## archetype lists its attacks in EnemyActor._build_attacks(); the base picks one per token.

const MOVES_DIR := "res://game/combat/moves/"

## The moves in order (each a shared MoveData resource, so F1 edits apply live).
var moves: Array[MoveData] = []
## &"strike" (hitboxes, the default) or &"grab" (an enemy hold on the player, P2-grab).
var kind: StringName = &"strike"
## The name of a TuningData property holding this attack's chance (0..1) of being picked; the
## attacks with none share what the named ones leave. Empty for an archetype's default attack.
var weight_property: StringName = &""
## The wind-up floor of the heavy tier applies (Bruiser, boss attacks).
var heavy: bool = false
## A short name for logs and F3.
var label: StringName = &""


## An attack from move ids (loaded from game/combat/moves/<id>.tres; ids that do not load are
## left out, so a half-merged archetype still builds).
static func of(p_label: StringName, move_ids: Array[StringName], p_weight_property: StringName = &"",
		p_heavy: bool = false, p_kind: StringName = &"strike") -> EnemyAttack:
	var attack := EnemyAttack.new()
	attack.label = p_label
	attack.weight_property = p_weight_property
	attack.heavy = p_heavy
	attack.kind = p_kind
	for id: StringName in move_ids:
		var path := "%s%s.tres" % [MOVES_DIR, id]
		if ResourceLoader.exists(path):
			attack.moves.append(load(path) as MoveData)
	return attack


## The opening move (the telegraph), or null when the attack has no moves.
func first() -> MoveData:
	return moves[0] if not moves.is_empty() else null


## The move after `move` in the chain (matched by id: a wind-up copy has the same id), or null at the end.
func next_after(move: MoveData) -> MoveData:
	for i: int in moves.size():
		if moves[i].id == move.id:
			return moves[i + 1] if i + 1 < moves.size() else null
	return null


## The reach (m) the AI closes to before winding up: the opening move's reach_m.
func reach_m() -> float:
	var opener := first()
	return opener.reach_m if opener else 0.0
