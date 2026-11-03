@tool
class_name EdgeGuard
extends LevelBlock
## The invisible guard along an open edge (Milestone 5, D8): a LevelBlock on physics layer 9 only
## (`CombatTypes.LAYER_EDGE_GUARD`), never drawn. The player's mask holds the layer in every state
## and a standing enemy's does, a ghost (knocked-down, launched, thrown) enemy's does not, so one
## crosses it and the HazardVolume past the lip KOs it. The navmesh bake parses the layer too, so the
## mesh stops an agent radius short of it. The tunable `level_edge_guard` (off: the player can fall)
## puts the collider on no layer at all; the bake always sees it (LevelRoot calls `set_baking()`).

var _baking: bool = false


func _ready() -> void:
	super()
	if not Engine.is_editor_hint():
		add_to_group(&"edge_guard")
		Tuning.changed.connect(_on_tuning_changed)


func _exit_tree() -> void:
	if not Engine.is_editor_hint() and Tuning.changed.is_connected(_on_tuning_changed):
		Tuning.changed.disconnect(_on_tuning_changed)


## For the navmesh bake: on while `baking`, whatever the tunable says; false puts the tunable back.
func set_baking(baking: bool) -> void:
	_baking = baking
	_apply()


func _layer_bit() -> int:
	return CombatTypes.bit(CombatTypes.LAYER_EDGE_GUARD) if _is_on() else 0


func _drawn() -> bool:
	return false


func _is_on() -> bool:
	return _baking or Engine.is_editor_hint() or Tuning.data.level_edge_guard


func _apply() -> void:
	if body != null:
		body.collision_layer = _layer_bit()


func _on_tuning_changed(property: StringName) -> void:
	if property == &"" or property == &"level_edge_guard":
		_apply()
