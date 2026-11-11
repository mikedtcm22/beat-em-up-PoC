class_name WeaponDef
extends Resource
## One kind of pick-up weapon (Milestone 6, D5, D22): everything the player needs to carry it that is not the weapon's body.
## `game/weapons/defs/<id>.tres`; WeaponCatalog loads them. A weapon's scene names its def by `Weapon.def_id`, so a def can
## point at the scene without the two resources referring to each other.

## The def's id: the weapon scene's `def_id`, and the key of the move set the player swaps to while he holds it.
@export var id: StringName = &""
@export var display_name: String = ""
## The weapon, a `Weapon` scene (game/weapons/<id>.tscn; the pipe's path is kept).
@export var scene: PackedScene
## The moves while it is held: P is the first swing, with the ground set's kicks and elbow (docs/ARCHITECTURE.md "Move sets").
@export var move_set: MoveSet
## The LB throw while it is held (15 damage, a knockdown: Spec section 4).
@export var throw_move: MoveData
## The ids of its swings, in chain order. The player spends a durability point per body a swing hits, and refuses a swing
## the held weapon does not own.
@export var swing_ids: Array[StringName] = []
## The impact layer every move of this weapon names (`MoveData.impact_sfx`: `weapon_<impact_sfx>_hit`).
@export var impact_sfx: StringName = &""


## Whether `move_id` is one of this weapon's swings.
func owns_swing(move_id: StringName) -> bool:
	return swing_ids.has(move_id)
