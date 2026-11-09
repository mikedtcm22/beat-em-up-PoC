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
@export_group("Shaft and flame (round 3)")
## A painted shaft of light from the lamp head down (a flat-shape cone, not fog): its length and its width at the bottom (m), and its strength.
@export var shaft: bool = false
@export_range(0.5, 12.0) var shaft_len_m: float = 4.0
@export_range(0.2, 8.0) var shaft_w_m: float = 2.4
@export_range(0.0, 1.0) var shaft_energy: float = 0.14
## A fire barrel burns: a painted flame (tongues in three values, re-rolled at the flicker rate) stands in the barrel; its height and width (m).
@export var flame: bool = false
@export_range(0.2, 2.5) var flame_h_m: float = 1.1
@export_range(0.2, 2.0) var flame_w_m: float = 0.8

@export_group("Pole and light mask (round 4)")
## A lamp post's pole: the radius at its top and at its foot (m): it tapers. The post leans off the vertical by `lean_deg` (1 to 3 degrees, toward `lean_yaw_deg`); 0 takes
## a hash of the post's place, so no two lean alike and a look never repeats itself.
@export_range(0.02, 0.15) var pole_top_m: float = 0.04
@export_range(0.03, 0.25) var pole_base_m: float = 0.095
@export_range(0.0, 6.0) var lean_deg: float = 0.0
@export_range(-180.0, 180.0) var lean_yaw_deg: float = 0.0
## How far the paint shader treats this light as lighting the world, as a share of its range (the "in the light" zone where detail draws at full contrast).
@export_range(0.3, 2.0) var mask_range_scale: float = 1.0


## The basis a lamp post's lean gives: a tilt of `lean_deg` (from a hash of the place when it is 0) about a horizontal axis at `lean_yaw_deg` (hashed when 0 too).
func lean_basis() -> Basis:
	var h1 := _hash01(position.x * 12.9898 + position.z * 78.233)
	var h2 := _hash01(position.x * 39.346 + position.z * 11.135 + 5.0)
	var angle := lean_deg if lean_deg > 0.0 else 1.0 + 2.0 * h1
	var yaw := lean_yaw_deg if absf(lean_yaw_deg) > 0.001 else (h2 * 360.0 - 180.0)
	var axis := Vector3(cos(deg_to_rad(yaw)), 0.0, sin(deg_to_rad(yaw)))
	return Basis(axis, deg_to_rad(angle))


static func _hash01(x: float) -> float:
	return fposmod(sin(x) * 43758.5453, 1.0)


## Where the light is, relative to the feet, ignoring any lean (a lamp's head, a barrel's flame, a bare light's own place).
func head_offset() -> Vector3:
	match prop:
		Prop.LAMP_POST:
			return lean_basis() * Vector3(arm_side * 0.7, height_m - 0.1, 0.0)
		Prop.FIRE_BARREL:
			return Vector3(0.0, height_m, 0.0)
	return Vector3.ZERO
