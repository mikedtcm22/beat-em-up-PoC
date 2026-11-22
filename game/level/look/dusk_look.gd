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

@export_group("Practicals")
## The lit things of the roofs (DuskDeck builds them): bulkhead lamps over the doors, skylights in the deck, a sign, and the long flat
## shadow shapes the low sun lays on the deck.
@export var practicals: Array[DuskLamp] = []
## A shadow shape's colour (alpha is its strength) and the colour of the lighter step along its edge.
@export var shade_color: Color = Color(0.1, 0.03, 0.2, 0.5)
@export var shade_edge_color: Color = Color(0.2, 0.07, 0.3, 0.3)

@export_group("Far windows")
## The window rows laid on the faces of the far skyline blocks that look toward the roofs (DuskDeck): the grid's cell (m), the window's
## size in its cell (m), the share of cells that are lit and the share that are dark panes (the rest are left as the wall), the seed,
## and how far above the block's foot the first row sits (m). Lit, dark, boarded (a blind drawn down) and curtained variants come from
## the window card's own seeds, so no row repeats evenly.
@export var far_window_cell_m: Vector2 = Vector2(3.4, 3.8)
@export var far_window_size_m: Vector2 = Vector2(1.5, 2.1)
@export_range(0.0, 1.0, 0.01) var far_window_lit_share: float = 0.4
@export_range(0.0, 1.0, 0.01) var far_window_dark_share: float = 0.3
@export var far_window_seed: int = 17
@export var far_window_first_row_m: float = 1.5
## The middle of the roofs' decks (section x, z) that the far blocks' faces look toward.
@export var deck_centre: Vector2 = Vector2(6.0, -14.0)
