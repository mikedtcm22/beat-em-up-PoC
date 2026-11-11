class_name NightMatte
extends Resource
## One painted matte card hung behind the playfield (Milestone 7, T10; ported from the video branch's matte_card): the far
## skyline. The picture is a Gemini plate keyed to alpha (assets/export/look/trailer/). It faces +Z at yaw 0, so a card behind a
## camera that looks down -Z needs no yaw. Position is in the street section's space.

@export var texture: Texture2D
@export var position: Vector3 = Vector3(0.0, 24.0, -92.0)
@export var size_m: Vector2 = Vector2(170.0, 72.0)
@export_range(-180.0, 180.0) var yaw_deg: float = 0.0
## A multiplier on the painted colour, the share of the haze colour mixed in (a far card sits in the air), the haze colour and the energy.
@export var tint: Color = Color.WHITE
@export_range(0.0, 1.0) var fade: float = 0.3
@export var haze_color: Color = Color(0.1, 0.12, 0.3)
@export_range(0.0, 3.0) var energy: float = 0.8
## The share of the card's left, right, top and bottom that feathers into the sky.
@export var feather: Vector4 = Vector4(0.06, 0.06, 0.0, 0.0)
