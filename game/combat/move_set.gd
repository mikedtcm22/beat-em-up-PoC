class_name MoveSet
extends Resource
## The roots of a combo tree for one context (ground, air, holding an enemy, holding a weapon).

@export var id: StringName = &"ground"
## Starting moves. Evaluated in order; the first branch whose input matches and whose
## `require` condition holds wins, so conditional branches go before plain ones.
@export var root_branches: Array[ComboBranch] = []
## Branches usable from the recovery of ANY move in this set (e.g. RB back elbow),
## checked after the current move's own branches.
@export var interrupt_branches: Array[ComboBranch] = []
