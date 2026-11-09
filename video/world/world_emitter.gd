class_name VideoWorldEmitter
extends Resource
## One particle emitter of a location's world look (LD-WORLD): embers, steam or dust, at positions given in the space of the
## level section. Sprites are made by code (VideoWorldSprites); the sim is seeded, so a frame is the same on every run.

enum Kind { EMBERS, STEAM, DUST }

@export var kind: Kind = Kind.EMBERS
## Where it emits (section space), one emitter per point, and the box it emits from (half extents, m).
@export var points: PackedVector3Array = PackedVector3Array()
@export var extents: Vector3 = Vector3(0.2, 0.05, 0.2)
## Particles per emitter, their life (s), and the sprite's size range (m). For STEAM (drawn plumes, R4-WORLD): `amount` is the number of plumes at each point
## (one or two), `size_m` the big plume's card (width, height), `life_s` the seconds a lobe takes to rise, `color_start` the light value and `color_end` the shade.
@export_range(1, 2000) var amount: int = 40
@export_range(0.2, 20.0) var life_s: float = 3.0
@export var size_m: Vector2 = Vector2(0.04, 0.09)
## The initial velocity: its direction and speed range (m/s), the spread (degrees) and the gravity (m/s^2, y; negative falls).
@export var direction: Vector3 = Vector3.UP
@export var speed: Vector2 = Vector2(0.6, 1.6)
@export_range(0.0, 180.0) var spread_deg: float = 35.0
@export var gravity: Vector3 = Vector3(0.0, 0.3, 0.0)
## Colour at birth and at death (alpha the share shown), and the energy of an additive ember.
@export var color_start: Color = Color(1.0, 0.7, 0.3, 1.0)
@export var color_end: Color = Color(0.8, 0.2, 0.1, 0.0)
@export_range(0.0, 4.0) var energy: float = 1.0
## The seed (so each emitter differs and a run repeats), and the seconds the sim has already run when the shot starts.
@export var seed: int = 1
@export_range(0.0, 20.0) var preprocess_s: float = 4.0
