class_name NightLamp
extends Resource
## One light of the trailer's night street (Milestone 7, T10; ported from the video branch's world_light): a street lamp on a pole
## or a burn barrel, with the real light it throws (toon-shaded surfaces take it), the painted halo round its head and, for a
## key lamp, a brush-stroke shaft. Positions are in the street section's space (x across, z along the walk; y 0 is the floor).

enum Kind { LAMP, BARREL }

@export var kind: Kind = Kind.LAMP
## Where the pole (or barrel) stands on the floor.
@export var position: Vector3 = Vector3.ZERO
## Which way the arm reaches from the pole across the street: +1 toward +x, -1 toward -x (a lamp only).
@export_range(-1.0, 1.0, 2.0) var arm_side: float = -1.0
## The light's height above the floor, and the arm's reach (a lamp), in metres.
@export var height_m: float = 4.4
@export var arm_m: float = 0.9
@export var color: Color = Color(1.0, 0.58, 0.1)
@export_range(0.0, 8.0, 0.05) var energy: float = 0.12
@export_range(1.0, 20.0, 0.1) var range_m: float = 4.5
## The light's falloff exponent (Light3D.omni_attenuation): higher keeps it close to the lamp.
@export_range(0.2, 6.0, 0.05) var falloff: float = 1.6
## How hot the lamp head (or the barrel's coals) glows: HDR, above the bloom threshold.
@export_range(0.0, 16.0, 0.1) var head_glow: float = 4.0
## Flicker amplitude as a share of the energy (a barrel's fire), held on twos of the 60 Hz tick.
@export_range(0.0, 0.5, 0.01) var flicker: float = 0.0
@export_group("Halo")
## The halo card's diameter in metres (0: none), its energy (HDR: only this and the fire may bloom), rings and ring wobble.
@export var halo_m: float = 1.6
@export_range(0.0, 8.0, 0.1) var halo_energy: float = 1.6
@export_range(0.0, 6.0, 1.0) var halo_rings: float = 2.0
@export_range(0.0, 0.5, 0.01) var halo_wobble: float = 0.3
@export_group("Pool")
## The painted ground pool's diameter in metres (0: none) and how far it is pushed from the pole toward the street's middle.
@export var pool_m: float = 4.4
@export_range(0.0, 1.0, 0.01) var pool_push: float = 0.25
## The painted glow on the wall nearest the lamp: its diameter in metres (0: none) and its height above the lamp head's.
@export var wall_glow_m: float = 3.8
@export var wall_glow_rise_m: float = -0.4
@export_group("Shaft")
@export var shaft: bool = false
@export var shaft_len_m: float = 4.0
@export var shaft_w_m: float = 2.6
@export_range(0.0, 1.0, 0.01) var shaft_energy: float = 0.12


## The light's own point: the lamp head, or the top of the barrel.
func head_position() -> Vector3:
	var out := position + Vector3(0.0, height_m, 0.0)
	if kind == Kind.LAMP:
		out.x += arm_side * arm_m
	return out
