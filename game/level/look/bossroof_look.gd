class_name BossroofLook
extends NightLook
## The boss roof's area look for the trailer profile (Milestone 7, e-bossroof): the night street's data shape (a colour script, lamps that
## here are the fire's glow, the sky, the haze) with the fire wall's own colours and cards. Finds itself the way a street does: it hangs in
## `trailer.tres`'s `light_overrides` (NightLook.for_location) and applies to the section whose `look_location` is `location`. The fire
## wall, the embers and the skyline are built by BossroofFx (game/fx/bossroof_fx.gd), which hangs in `boss_roof.tscn`. Presentation only.

@export_group("Fire wall")
## The cards of the far dressing: fire walls and skyline plates.
@export var walls: Array[BossroofWall] = []
## The cloud's tones from the outside in: the smoke over it, the outer sheet, the red, the orange and the hot core (the core is HDR).
@export var smoke_color: Color = Color(0.14, 0.05, 0.14)
@export var smoke_inner_color: Color = Color(0.3, 0.07, 0.15)
@export var fire_outer_color: Color = Color(0.5, 0.09, 0.08)
@export var fire_red_color: Color = Color(0.86, 0.2, 0.07)
@export var fire_orange_color: Color = Color(1.0, 0.5, 0.1)
@export var fire_core_color: Color = Color(1.0, 0.84, 0.4)
@export var fire_line_color: Color = Color(0.13, 0.025, 0.07)
## How deep each inner tone starts inside the fire's edge, as a share of the wall's height.
@export var fire_depth_shares: Vector3 = Vector3(0.025, 0.06, 0.11)

@export_group("Skyline")
@export var plate_body_color: Color = Color(0.1, 0.045, 0.12)
@export var plate_window_color: Color = Color(0.16, 0.07, 0.16)
@export var plate_lit_color: Color = Color(1.0, 0.46, 0.14)
## The fire-lit edge along a roof's top and a wall's fire side.
@export var plate_edge_color: Color = Color(0.96, 0.36, 0.1)
@export_range(0.0, 1.0, 0.01) var plate_lit_share: float = 0.1
## Whether the kit's skyline blocks of the section get a flat silhouette card over their faces.
@export var cover_blocks: bool = true

@export_group("Embers")
@export var ember_young_color: Color = Color(1.0, 0.8, 0.3)
@export var ember_old_color: Color = Color(0.95, 0.25, 0.06)
## The box the embers are spread over (section space: centre and size, m).
@export var ember_box_center: Vector3 = Vector3(14.0, 2.0, -12.0)
@export var ember_box_size: Vector3 = Vector3(60.0, 1.0, 70.0)


## BossroofFx builds the lamps (the fire's glow) and the pools with the rest of the area's dressing.
func builds_street() -> bool:
	return false
