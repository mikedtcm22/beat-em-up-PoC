class_name PickupSpot
extends Marker3D
## A weapon lying where the level puts one (Milestone 5; SPEC §9 "Weapons on the ground: the same
## spots"). LevelRoot places `weapon_scene` here at the level's start; the weapon is the ordinary
## pick-up (LB) with its own durability. The graybox's second weapon is today's pipe (D12).

@export var weapon_scene: PackedScene = preload("res://game/weapons/pipe.tscn")
## How far above the floor the weapon is dropped from (m), so its capsule never starts in the floor.
@export_range(0.0, 1.0, 0.05) var drop_height_m: float = 0.3


## The weapon at this spot, parented to `host`. Null without a scene.
func place(host: Node3D) -> Weapon:
	if weapon_scene == null:
		return null
	var weapon := weapon_scene.instantiate() as Weapon
	if weapon == null:
		return null
	host.add_child(weapon)
	weapon.global_position = global_position + Vector3.UP * drop_height_m
	weapon.global_rotation = Vector3(0.0, global_rotation.y, PI * 0.5)
	return weapon
