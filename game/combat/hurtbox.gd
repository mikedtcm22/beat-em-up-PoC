class_name Hurtbox
extends Area3D
## A body-region volume that attacks can hit. Lives on CombatTypes.LAYER_HURTBOX, is
## monitorable but never monitors. The rig keeps its transform in sync with the bones.

@export var region: CombatTypes.Region = CombatTypes.Region.TORSO
## The CombatActor that owns this hurtbox (typed loosely to avoid a class cycle).
var actor: Node3D
## Radius of the main shape, used for contact-point estimates.
var radius: float = 0.2


func _init() -> void:
	monitoring = false
	monitorable = true
	collision_layer = CombatTypes.bit(CombatTypes.LAYER_HURTBOX)
	collision_mask = 0
