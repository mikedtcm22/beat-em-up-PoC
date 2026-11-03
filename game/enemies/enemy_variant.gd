class_name EnemyVariant
extends Resource
## A variant of an archetype (Milestone 5, D2): the same scene and moves with a few numbers of its
## own, as data, so a later level's tougher Punk is a `.tres` file and not code. Files live in
## game/enemies/variants/<id>.tres and are named by an EnemyCatalog entry (`variant = "res://..."`);
## EnemyCatalog.apply_variant() puts one on an enemy the spawner makes.

## The catalog id this variant is spawned as (&"punk_veteran").
@export var id: StringName = &""
## The archetype it is a variant of (&"punk"): the catalog entry whose scene it uses.
@export var base_id: StringName = &""
## The name F4 lists it by.
@export var label: String = ""
## The attack arc (degrees) of this variant. -1 keeps the archetype's own (Tuning "Attack arcs").
@export_range(-1.0, 360.0, 5.0) var arc_deg: float = -1.0
## The graybox marker: a color that tints the body (the jacket of a primitive body, the whole skinned
## art's palette). Alpha 0 = no tint.
@export var tint: Color = Color(0.0, 0.0, 0.0, 0.0)
