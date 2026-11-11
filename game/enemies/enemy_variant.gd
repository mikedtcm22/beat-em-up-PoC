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
## A palette swap (Milestone 6, D4): an atlas that stands in for the archetype's on the skinned art's
## material (`albedo_tex`), built by tools/pipeline/gen_palette.py from assets/source/palette/variants/<id>.json
## to assets/export/palette/<id>_atlas.png. It recolours some swatches and keeps every alpha, so the
## marks, the gloss and the silhouette are the archetype's. Null = the archetype's own atlas.
@export var palette: Texture2D
## The graybox marker, retired by the palette swap and kept for a graybox variant: a color that tints
## the body (the jacket of a primitive body, the whole skinned art's palette). Alpha 0 = no tint.
## No shipped variant sets one (tests/test_m6_no_placeholders.gd counts a tint as a placeholder).
@export var tint: Color = Color(0.0, 0.0, 0.0, 0.0)

## M7 (T12): the paint map a trailer-profile painted art wears for this variant (`metadata/trailer_paint` in the .tres, a Texture2D on the
## same UV2 as the art's own paint map: the same drawing recoloured, so the ink, the face and the hull are the archetype's). Null = none.
func trailer_paint() -> Texture2D:
	return get_meta(&"trailer_paint") as Texture2D if has_meta(&"trailer_paint") else null
