class_name DuskLamp
extends Resource
## One practical of the dusk roofs (Milestone 7, x-roofs): a bulkhead lamp over a door, a skylight in the deck, a lit sign or a flat
## shadow shape laid on the deck. DuskDeck (game/level/look/dusk_deck.gd) builds them from the DuskLook's `practicals`, in the section's
## space. Painted only (no real light, no shadow caster): a lamp is an emissive slab, a stepped halo, a stepped wall glow and a stepped
## pool on the floor.

enum Kind { BULKHEAD, SKYLIGHT, SIGN, SHADE, WINDOWS }

@export var kind: Kind = Kind.BULKHEAD
## The lamp head's centre (a bulkhead, a sign), or the centre of the thing on the deck (a skylight, a shadow shape; y is then the deck's height).
@export var position: Vector3 = Vector3.ZERO
## Which way the wall faces, degrees about the vertical: 0 looks toward +z, 90 toward +x, -90 toward -x, 180 toward -z. A shadow shape's yaw is its long axis.
@export_range(-180.0, 180.0, 1.0) var yaw_deg: float = 0.0
## The size on its face (m): a sign's or skylight's panel, a shadow shape's length and width.
@export var size_m: Vector2 = Vector2(1.0, 1.0)
@export var color: Color = Color(1.0, 0.6, 0.22)
## The glow's HDR energy on a lamp head, a sign or a skylight pane.
@export_range(0.0, 8.0, 0.1) var glow: float = 2.0
## The halo round the head (m, 0: none), and the pool it throws on the floor (m, 0: none), pushed out from the wall by `pool_out_m`.
@export var halo_m: float = 1.6
## The halo's energy (a multiplier on the card's own rings).
@export_range(0.0, 2.0, 0.05) var halo_energy: float = 0.5
@export var pool_m: float = 5.0
@export var pool_out_m: float = 1.4
## The wall glow (m, 0: none), a stepped pool on the wall the lamp hangs on.
@export var wall_glow_m: float = 3.2
## The deck's height under the lamp (m): where the pool lies.
@export var floor_y: float = 0.0
@export var seed: float = 1.0


## The unit vector the wall faces, in the horizontal plane.
func facing() -> Vector3:
	var yaw := deg_to_rad(yaw_deg)
	return Vector3(sin(yaw), 0.0, cos(yaw))
