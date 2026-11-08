class_name VideoWorldLight
extends Resource
## One practical light of a location's world look (LD-WORLD): a sodium lamp post, a fire barrel, or a bare light (the boss roof's
## fire from below), placed from data in the space of the level section the look is for. Video only: the game has no lamps.

enum Prop { LAMP_POST, FIRE_BARREL, BARE }

## What stands there: a lamp post (pole, arm, head, lens), a burning barrel (barrel, flame card), or nothing (a light alone).
@export var prop: Prop = Prop.LAMP_POST
## The prop's feet (section space), or the light's own position for a bare light.
@export var position: Vector3 = Vector3.ZERO
## A lamp post's arm leans toward this side (-1 left, 1 right, 0 none): the head stands this many metres off the pole.
@export_range(-1.0, 1.0) var arm_side: float = 0.0
## A bare light, or a lamp that is not to point straight down, aims at this point (section space). Zero: straight down for a lamp.
@export var aim_at: Vector3 = Vector3.ZERO
## Height of the lamp head or the flame above the feet (m).
@export_range(0.3, 10.0) var height_m: float = 4.2
## The light: a spot (a cone with a hard pool) or an omni, its colour, energy (the toon light caps a channel at 1, so keep
## it near 1), range in metres, the cone's full angle in degrees, the distance attenuation's exponent.
@export var spot: bool = true
@export var color: Color = Color(1.0, 0.604, 0.235)
@export_range(0.0, 8.0) var energy: float = 1.0
@export_range(1.0, 40.0) var range_m: float = 9.0
@export_range(10.0, 170.0) var cone_deg: float = 70.0
@export_range(0.1, 4.0) var attenuation: float = 1.2
## Whether this light casts THE shadow of the shot (the rig lets one light cast: the sun's shadow switch is off when a light is).
@export var shadow: bool = false
## A flame's flicker: the energy swings by this share, re-rolled at the look's flicker rate from the frame number (never time).
@export_range(0.0, 0.6) var flicker: float = 0.0
## The banded halo card on the light: size (m), its rings, its strength.
@export var halo: bool = true
@export_range(0.1, 12.0) var halo_m: float = 1.6
@export_range(0.0, 6.0) var halo_rings: float = 3.0
@export_range(0.0, 3.0) var halo_energy: float = 1.0
@export_range(0.0, 0.5) var halo_wobble: float = 0.3
@export_range(0.0, 2.0) var halo_ring_strength: float = 0.35
