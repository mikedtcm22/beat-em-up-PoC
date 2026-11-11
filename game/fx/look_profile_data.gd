class_name LookProfileData
extends Resource
## One look profile's data (Milestone 7, T05a): what LookProfile hands to the presentation code that
## asks for per-profile resources. A profile is a .tres of this class in game/fx/look_profiles/, named
## as LookProfile.NAMES says. The defaults ARE Milestone 6's look, so `m6.tres` holds none of them and a
## new profile lists only what it changes. Presentation only: no simulation code reads one.

## Replaces entries of a light (LevelSection.light()'s keys: sun_elevation, sun_yaw, sun_color,
## sun_energy, fog_color, fog_density, sky_top, sky_horizon) wherever the level takes one: a section's
## own, the room's default, and the sky and fog of the rooms that have no sections. An entry not named
## keeps the section's. Empty: every light as authored.
@export var light_overrides: Dictionary = {}
## The grade LUT (a strip of N slices of N x N pixels; tools/gen_lut.gd writes it).
@export_file("*.png") var grade_lut_path: String = "res://assets/export/look/grade_lut.png"
## Whether the room's Environment may glow (bloom). M6's look bible has none outside the effects.
@export var bloom_allowed: bool = false
## A multiplier on the ink: the character hull's width (look_outline_px) and the edge pass's line
## (look_edge_px). 1 is Tuning's value as it stands.
@export_range(0.1, 4.0, 0.05) var ink_width_scale: float = 1.0
## The folder of the comic effect textures (VfxArt.DIR is M6's).
@export_dir var vfx_art_dir: String = "res://assets/export/fx/"
## The HUD's style set, by name (HudStyle is M6's).
@export var hud_style: StringName = &"m6"
