class_name CineSpikeLookData
extends Resource
## Every number of the Phase 0 spike's night look (P0-SPIKE): the stage, the hand-placed light, the
## fog and glow, the ink pass and the flat paint. Lives in `spike_look.tres`; spike_look.gd only
## applies it. Nothing here touches Tuning's presets or the game's own files.

@export_group("Stage")
## Where the player stands (street section space, the feet), his yaw and look pitch in degrees.
@export var player_at: Vector3 = Vector3(3.0, 0.0, 0.8)
@export var player_yaw_deg: float = 0.0
@export var player_pitch_deg: float = -4.0
## The Street Punk: right of the player and ahead of him (metres, flat).
@export var punk_rel: Vector2 = Vector2(0.45, 2.0)
## The animation the Punk holds (his guard), and how long it runs before the freeze (ticks).
@export var punk_anim: StringName = &"idle"
@export var punk_settle_ticks: int = 40
## The player holds his guard (block) this many ticks before the freeze, so his gloves are in the near foreground
## (0 = no guard: idle shows no hands).
@export var player_guard_ticks: int = 26
## Ticks to wait after a stage's change before the frame is taken (the volumetric fog converges).
@export var stage_settle_ticks: int = 24
@export var capture_size: Vector2i = Vector2i(2560, 1440)

@export_group("Moon and sky")
@export var moon_color: Color = Color(0.42, 0.52, 0.95)
@export_range(0.0, 3.0) var moon_energy: float = 0.5
@export_range(0.0, 8.0) var moon_volumetric_energy: float = 0.15
@export_range(5.0, 80.0) var moon_elevation_deg: float = 38.0
@export_range(-180.0, 180.0) var moon_yaw_deg: float = 70.0
@export var sky_top: Color = Color(0.02, 0.03, 0.10)
@export var sky_horizon: Color = Color(0.07, 0.08, 0.22)
@export var ground_horizon: Color = Color(0.04, 0.05, 0.12)
@export var ground_bottom: Color = Color(0.02, 0.02, 0.06)
@export var ambient_color: Color = Color(0.05, 0.06, 0.16)
@export_range(0.0, 2.0) var ambient_energy: float = 0.25
@export var fog_color: Color = Color(0.06, 0.08, 0.20)
@export_range(0.0, 0.1) var fog_density: float = 0.012
@export_range(0.0, 1.0) var fog_sky_affect: float = 0.6

@export_group("Grade")
## The game's dusk grade (look_grade_enabled) is switched off with the night light: its tint is a dusk's, and the
## palette LUT (stage e) is the night's grade. Off here, the stats the LUT is made from are the raw render's.
@export var night_grade_off: bool = true

@export_group("Toon shadow")
## Tuning's look_shadow_level for the night. The toon light() adds shadow_level x the light's colour inside the
## whole volume of EVERY light, so a point light floods its range unless this is low (the moon's shadow side
## goes near-black navy, which is the night).
@export_range(0.0, 0.6) var toon_shadow_level: float = 0.07

@export_group("Lamp (the warm key)")
## Offset of the lamp head from the Punk's feet (x right, y up, z toward the player is positive).
@export var lamp_offset: Vector3 = Vector3(-1.6, 3.1, -0.6)
@export var lamp_color: Color = Color(1.0, 0.604, 0.235)
@export_range(0.0, 20.0) var lamp_energy: float = 3.0
@export_range(1.0, 30.0) var lamp_range_m: float = 9.0
@export_range(0.1, 4.0) var lamp_attenuation: float = 1.4
@export_range(0.0, 16.0) var lamp_volumetric_energy: float = 4.0
## The lamp's visible head (an emissive disc): size in metres and emission energy (HDR, so it blooms).
@export_range(0.05, 1.0) var lamp_head_m: float = 0.28
@export_range(1.0, 40.0) var lamp_head_energy: float = 14.0

@export_group("Rim")
## Where the rim light sits behind the Punk (from his feet; z negative is further from the player).
@export var rim_offset: Vector3 = Vector3(-1.0, 1.9, -1.4)
@export var rim_color: Color = Color(1.0, 0.62, 0.3)
@export_range(0.0, 20.0) var rim_energy: float = 2.4
@export_range(1.0, 20.0) var rim_range_m: float = 5.0

@export_group("Atmosphere")
@export var vfog_enabled: bool = true
@export_range(0.0, 0.5) var vfog_density: float = 0.035
@export var vfog_albedo: Color = Color(0.35, 0.42, 0.75)
@export var vfog_emission: Color = Color(0.0, 0.0, 0.02)
@export_range(-0.9, 0.9) var vfog_anisotropy: float = 0.55
@export_range(8.0, 128.0) var vfog_length_m: float = 40.0
@export var glow_enabled: bool = true
@export_range(0.0, 8.0) var glow_intensity: float = 0.9
@export_range(0.0, 2.0) var glow_strength: float = 1.1
@export_range(0.0, 1.0) var glow_bloom: float = 0.05
@export_range(0.0, 4.0) var glow_hdr_threshold: float = 0.9
## Which of the seven glow levels are on (0 or 1 each): the wide ones give the halo.
@export var glow_levels: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0])
@export var volume_size: int = 128
@export var volume_depth: int = 96

@export_group("Outline hull")
## The characters' inverted hull, thinned and tinted to the ink so the screen pass carries the weight.
@export_range(0.0, 8.0) var hull_px: float = 1.6
@export var ink_color: Color = Color(0.09, 0.055, 0.05)

@export_group("Ink pass")
@export_range(0.5, 6.0) var ink_width_thin_px: float = 1.0
@export_range(0.5, 8.0) var ink_width_heavy_px: float = 3.2
## The surface's light factor (dot of its normal with the key) at which the line is lost, and at which it is full.
@export_range(-1.0, 1.0) var ink_lit_lost: float = 0.55
@export_range(-1.0, 1.0) var ink_lit_full: float = -0.1
@export_range(0.0, 1.0) var ink_lit_floor: float = 0.1
@export_range(0.02, 1.0) var ink_depth_threshold: float = 0.07
@export_range(0.05, 1.0) var ink_normal_threshold: float = 0.45
## Past this distance the environment draws only its major silhouettes: depth steps of this size.
@export_range(0.5, 40.0) var ink_env_major_m: float = 8.0
@export_range(1.0, 100.0) var ink_fade_start_m: float = 10.0
@export_range(2.0, 200.0) var ink_fade_end_m: float = 40.0
@export_range(0.0, 1.0) var ink_alpha: float = 0.96
## Debug view of the ink shader: 0 the picture, 1 the light factor, 2 the line width, 3 the lines only.
@export_range(0, 3) var ink_debug_view: int = 0

@export_group("Flat paint")
@export_range(1.0, 7.0) var paint_lod: float = 3.2
@export_range(2.0, 4.0) var paint_bands: float = 3.0
@export_range(0.0, 1.0) var paint_band_soft: float = 0.05
@export var paint_shadow_tint: Color = Color(0.20, 0.22, 0.48)
@export_range(0.0, 1.0) var paint_shadow_level: float = 0.5
@export_range(0.0, 1.0) var paint_mid_level: float = 0.78
@export_range(0.0, 1.0) var paint_ink_keep: float = 0.0
@export_range(0.0, 0.6) var paint_grain: float = 0.16
@export var paint_grain_scale: Vector2 = Vector2(22.0, 5.0)
@export_range(0.0, 0.5) var paint_break: float = 0.18
@export var paint_break_scale: Vector2 = Vector2(5.0, 2.0)
@export_range(0.0, 1.0) var paint_sat: float = 1.0
@export_range(0.5, 3.0) var paint_value_gain: float = 1.0

@export_group("Palette")
## The LUT strip written by tools/video/palette_lut.py, and the 32-cube size it holds.
@export_file("*.png") var lut_path: String = "res://captures/video/p0-spike/lut/lut.png"
