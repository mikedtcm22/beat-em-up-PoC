class_name BossroofWall
extends Resource
## One piece of the boss roof's far dressing under the trailer look (Milestone 7, e-bossroof): a fire wall (the flat stepped fire cloud,
## with the street's flame cards standing in front of it) or a skyline plate (flat dark silhouettes with a few lit windows). Positions are
## in the boss roof section's space; the card faces +Z at yaw 0, so a card behind a camera that looks down -Z needs no yaw (a fire
## wall always turns about the vertical to face the camera, a plate keeps its yaw).

enum Kind { FIRE, PLATE }

@export var kind: Kind = Kind.FIRE
## Where the card's bottom middle stands (the section's space), its size (m) and its yaw (a plate's facing; a fire wall's only says which way its width runs, for the flame cards along its foot).
@export var position: Vector3 = Vector3(0.0, -8.0, -90.0)
@export var size_m: Vector2 = Vector2(150.0, 60.0)
@export_range(-180.0, 180.0) var yaw_deg: float = 0.0
@export var seed: float = 1.0
## A fire wall: how many of the street's flame cards stand along its foot, and how big each is (m).
@export_range(0, 12, 1) var flames: int = 6
@export var flame_size_m: Vector2 = Vector2(16.0, 20.0)
## A plate: the cell width (m) of its two layers of buildings and the tallest roof (m) over the plate's bottom.
@export var cell_m: Vector2 = Vector2(7.0, 11.0)
@export var roof_m: Vector2 = Vector2(9.0, 24.0)
