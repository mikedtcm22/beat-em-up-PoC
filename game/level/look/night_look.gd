class_name NightLook
extends Resource
## The night street of the trailer look profile (Milestone 7, T10), as data: the colour script (indigo shadow, sodium-orange key
## lamps, warm windows, a cyan-white accent), the painted sky, the lamps with their halos and ground pools, the haze, the
## skyline cards, the contact shadows and the bloom. It hangs in `trailer.tres`'s `light_overrides` under the key `KEY`
## (the level strips it from the light it blends: LevelRoot.light_for()), and applies to the section whose
## `LevelSection.look_location` equals `location`. Presentation only: simulation code never reads it.

## The key it has in a profile's `light_overrides`.
const KEY := &"t10_night_street"

@export var location: StringName = &"street_night"

@export_group("Light")
## The moon, carried by the sun's slot: height, direction it comes from, colour (the shadow hue), energy, whether it casts shadows.
@export_range(5.0, 85.0, 1.0) var sun_elevation_deg: float = 50.0
@export_range(-180.0, 180.0, 1.0) var sun_yaw_deg: float = 80.0
@export var sun_color: Color = Color(0.46, 0.5, 0.74)
@export_range(0.0, 3.0, 0.05) var sun_energy: float = 1.0
@export var sun_shadow: bool = false
@export var fog_color: Color = Color(0.1, 0.12, 0.3)
@export_range(0.0, 0.05, 0.0005) var fog_density: float = 0.01

@export_group("Sky")
@export var sky_top: Color = Color(0.02, 0.03, 0.1)
@export var sky_horizon: Color = Color(0.16, 0.15, 0.34)
## The sky's middle band is the horizon colour this far (0..1) toward the top; the ground below the horizon is the top colour times this.
@export_range(0.0, 1.0, 0.01) var sky_mid_mix: float = 0.5
@export_range(0.0, 2.0, 0.01) var sky_below_mul: float = 1.0
@export var sky_disc_radius: float = 0.05
@export var sky_disc_color: Color = Color(0.85, 0.92, 1.0)
@export var sky_halo_color: Color = Color(0.2, 0.3, 0.6)
@export_range(0.0, 1.0, 0.01) var sky_halo_strength: float = 0.4
@export_range(0.0, 0.2, 0.001) var sky_star_cover: float = 0.01

@export_group("Lamps")
@export var lamps: Array[NightLamp] = []
@export var halo_core_color: Color = Color(1.0, 0.95, 0.8)
@export var pool_rim_color: Color = Color(0.9, 0.38, 0.08)
@export var pool_core_color: Color = Color(1.0, 0.62, 0.2)
@export_range(0.0, 1.0, 0.01) var pool_rim_alpha: float = 0.5
@export_range(0.0, 1.0, 0.01) var pool_core_alpha: float = 0.62
## How far above the floor the pool cards lie (m).
@export_range(0.005, 0.2, 0.005) var pool_lift_m: float = 0.03
## The wall glow's alphas (rim, core), and how far in front of the wall it lies (m).
@export var wall_glow_alpha: Vector2 = Vector2(0.16, 0.26)
@export_range(0.005, 0.2, 0.005) var wall_lift_m: float = 0.03

@export_group("Windows")
## The kit windows (`KitPiece` kind `window`) of the section that are lit: a share of them, picked by a seed, in the warm colours.
@export_range(0.0, 1.0, 0.01) var window_lit_share: float = 0.55
@export var window_seed: int = 3
@export var window_color: Color = Color(1.0, 0.7, 0.32)
@export var window_deep_color: Color = Color(0.85, 0.4, 0.12)
@export_range(0.0, 4.0, 0.05) var window_energy: float = 1.2
## The glow card's size as a share of the window piece's, and how far behind the piece's front face it lies (m).
@export var window_card_share: Vector2 = Vector2(0.72, 0.8)
@export_range(0.0, 0.3, 0.005) var window_inset_m: float = 0.03
## G4, no two windows alike: how far a glow card's size may differ from the rule above (a share, either way), how far it may sit off the
## piece's middle (a share of the piece), how far it may tilt (degrees), how far each corner of its quad is pulled in (a share), a mullion
## stroke's width (a share) and the stroke's and frame's colour.
@export_range(0.0, 0.4, 0.01) var window_size_jitter: float = 0.2
@export_range(0.0, 0.3, 0.01) var window_offset_jitter: float = 0.08
@export_range(0.0, 12.0, 0.5) var window_tilt_deg: float = 3.0
@export_range(0.0, 0.3, 0.01) var window_uneven: float = 0.1
@export_range(0.0, 0.3, 0.005) var window_mullion: float = 0.09
@export var window_mullion_color: Color = Color(0.1, 0.06, 0.1)

@export_group("Haze")
## Start distances (m) of the three flat haze bands, their colours (alpha is the strength), the mist's top (world y) and colour.
@export var haze_start_m: Vector3 = Vector3(12.0, 26.0, 48.0)
@export var haze_color_1: Color = Color(0.1, 0.14, 0.36, 0.04)
@export var haze_color_2: Color = Color(0.1, 0.14, 0.36, 0.08)
@export var haze_color_3: Color = Color(0.1, 0.14, 0.36, 0.14)
@export var haze_mist_top: float = 0.6
@export var haze_mist_color: Color = Color(0.1, 0.12, 0.3, 0.06)

@export_group("Cards")
@export var mattes: Array[NightMatte] = []

@export_group("Skyline wash")
## G4: a painted wash laid on the street-facing face of each kit skyline block (the far facades), irregular flat patches in two stepped
## tones that paint out part of the window rows: its colour (alpha is its strength), the share of the face it covers, the size of a patch
## (m) and how far in front of the face it lies (m). Cover 0 builds none.
@export var skyline_wash_color: Color = Color(0.2, 0.18, 0.42, 0.7)
@export_range(0.0, 1.0, 0.01) var skyline_wash_cover: float = 0.42
@export_range(1.0, 20.0, 0.5) var skyline_wash_patch_m: float = 5.0
@export_range(0.02, 0.5, 0.01) var skyline_wash_lift_m: float = 0.15

@export_group("Contact shadows")
@export var contact_color: Color = Color(0.01, 0.012, 0.035)
@export_range(0.0, 1.0, 0.01) var contact_opacity: float = 0.8
## The shadow card's width under an actor, in metres per metre of its body radius, and the stretch away from the nearest lamp.
@export_range(1.0, 12.0, 0.1) var contact_per_radius: float = 5.4
@export_range(1.0, 3.0, 0.05) var contact_stretch: float = 1.4
## A prop's card is its footprint times this.
@export_range(0.5, 3.0, 0.05) var contact_prop_share: float = 1.5

@export_group("Bloom")
## The Environment's glow while the look is on: only HDR above the threshold blooms (the lamps and the fire).
@export_range(0.0, 8.0, 0.05) var glow_threshold: float = 1.6
@export_range(0.0, 2.0, 0.01) var glow_intensity: float = 0.5
@export_range(0.0, 1.0, 0.01) var glow_strength: float = 0.9
@export_range(0.0, 1.0, 0.01) var glow_bloom: float = 0.0

@export_group("Painted characters")
## The area's colours for the painted (trailer) character materials, given to ToonMaterials.set_area_look() while the look is
## on: the hue their shadow tone is pulled toward (the street's indigo) and their one-sided rim (the sodium lamps' orange).
@export var paint_shadow_hue: Color = Color(0.2, 0.2, 0.5)
@export var paint_rim_color: Color = Color(1.0, 0.62, 0.2)


## The light dictionary this look gives its section (LevelSection.light()'s keys): LevelRoot lays it over the profile's.
func light() -> Dictionary:
	return {
		sun_elevation = sun_elevation_deg, sun_yaw = sun_yaw_deg, sun_color = sun_color, sun_energy = sun_energy,
		fog_color = fog_color, fog_density = fog_density, sky_top = sky_top, sky_horizon = sky_horizon,
	}


## The running profile's night look for a section whose `look_location` is `where`, or null (m6, another place, no row).
static func for_location(where: StringName) -> NightLook:
	if where == &"":
		return null
	var row: Variant = LookProfile.data().light_overrides.get(KEY)
	var look := row as NightLook
	return look if look != null and look.location == where else null


## `light` without the keys that are not a light's (the look rows a profile's `light_overrides` may carry).
static func strip_rows(light: Dictionary) -> Dictionary:
	if not light.has(KEY):
		return light
	var out := light.duplicate()
	out.erase(KEY)
	return out
