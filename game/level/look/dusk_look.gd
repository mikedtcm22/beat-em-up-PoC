class_name DuskLook
extends NightLook
## The dusk of Mission 1's roofs under the trailer look profile (Milestone 7, e-roofs): a NightLook (the same dressing of windows,
## skyline cards, pools, haze and contact shadows, the same row in the profile's `light_overrides`) whose colour script is a deep
## orange-to-violet evening: a low warm key, cool violet shadows, a painted sky with flat cloud bands and a low sun disc, and a far
## skyline of flat stepped silhouettes (assets/export/kit/trailer_roofs_skyline_*.png, tools/gen_roofs_kit.py). It adds what the night
## street has no use for: the sky's cloud banks and band count, written by TrailerLook while the player is in the section.
## Presentation only; Tuning's "Dusk roofs (M7)" group scales the live parts.

@export_group("Cloud bands")
## The share of the sky the cloud banks cover (0: none), the colour of a bank's lit top and its shaded underside, the elevation range
## (sine of the angle above the horizon) they live in, their noise scale (cycles round the horizon, bands up the sky), and how many
## flat bands the sky's gradient is cut into.
@export_range(0.0, 1.0, 0.01) var cloud_cover: float = 0.34
@export var cloud_lit: Color = Color(0.98, 0.56, 0.4)
@export var cloud_shade: Color = Color(0.4, 0.2, 0.46)
@export var cloud_range: Vector2 = Vector2(0.04, 0.55)
@export var cloud_scale: Vector2 = Vector2(2.0, 11.0)
@export_range(2.0, 12.0, 1.0) var sky_band_count: float = 5.0
