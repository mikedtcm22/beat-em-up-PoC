class_name VideoMatteCard
extends Resource
## One painted matte card hung in the world behind the playfield (LD-WORLD): the far skyline, a smoke bank, a wall of fire. The
## picture is made by tools/video/paint_mattes.py (assets/video/mattes/*.png, RGBA); the card is placed from data in the space of
## the level section. It faces +Z at yaw 0, so a card behind a camera that looks down -Z needs no yaw.

@export var texture: Texture2D
## The card's centre (section space), its size in metres, and its yaw in degrees about Y (0 faces +Z toward a camera looking down -Z; 90 faces +X).
@export var position: Vector3 = Vector3.ZERO
@export var size_m: Vector2 = Vector2(120.0, 30.0)
@export_range(-180.0, 180.0) var yaw_deg: float = 0.0
## A multiplier on the painted colour, the share of the haze colour mixed in (a far card sits in the air), the alpha and the energy.
@export var tint: Color = Color(1.0, 1.0, 1.0)
@export_range(0.0, 1.0) var fade: float = 0.0
@export_range(0.0, 1.0) var alpha: float = 1.0
@export_range(0.0, 3.0) var energy: float = 1.0
## Round 3, for a Gemini-painted backdrop: the share of the card's left, right, top and bottom that feathers into the sky, the sway of the painted smoke
## (uv; 0 still) and the height (uv from the bottom) above which it sways.
@export var feather: Vector4 = Vector4.ZERO
@export_range(0.0, 0.03) var drift: float = 0.0
@export_range(0.0, 1.0) var drift_from: float = 0.3
