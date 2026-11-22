class_name StreetFxSet
extends Resource
## Where the trailer street's 2D effects stand (M7 T16a): a data row per kind, positions local to the level section
## `section_path` names. The trailer profile's set is game/fx/look_profiles/<profile>_street_fx.tres (the m6 profile has
## none, so it draws none). Presentation only; nothing here has a collider.

## The LevelSection scene the positions are local to.
@export_file("*.tscn") var section_path: String = ""
## Steam plumes (white, outlined): where each rises from the ground.
@export var steam: PackedVector3Array = PackedVector3Array()
## Soft grey wisps: where each rises from the ground.
@export var wisps: PackedVector3Array = PackedVector3Array()
## Burn barrels: where each stands on the ground.
@export var barrels: PackedVector3Array = PackedVector3Array()
