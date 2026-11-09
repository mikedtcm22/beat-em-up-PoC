class_name VideoInkLook
extends VideoLookPiece
## The characters' paint and line, the 2D cues and the post (Phase 1, LD-INK; docs/video/P1.md): the ink
## piece of a location's look. One `.tres` per location under `res://video/look/<location>/ink.tres` holds
## every value; `apply(level)` adds a CineInkRig under the level, which does the work every frame:
## video/shaders/cine_toon.gdshader and cine_outline.gdshader swapped in place onto the characters' art
## materials, the screen-space ink (video/shaders/ink_screen.gdshader), the rim lights that follow the
## characters, the 2D cues (on twos, smears, the comic words hidden, flash frames and speed lines) and the
## finish pass (a CompositorEffect). A shot applies its pieces in the order art, world, then ink. Video only.
## Nothing here is written to Tuning: look values never reach the game's presets.

@export_group("Paint")
## The light-term cuts of the shadow, mid and lit bands, the mid band's level (1 makes two bands) and the
## shadow's level; its hue is the scene's shadow colour, `shadow_amount` the share of the hue.
@export_range(0.0, 1.0) var band_1: float = 0.30
@export_range(0.0, 1.0) var band_2: float = 0.66
@export_range(0.0, 1.0) var mid_level: float = 0.62
@export_range(0.0, 1.0) var shadow_level: float = 0.2
@export var shadow_color: Color = Color(0.20, 0.22, 0.50)
@export_range(0.0, 1.0) var shadow_amount: float = 0.8
## The camera-fixed fill the game gives a character (0 = none: at night the key and the moon do the work).
@export_range(0.0, 1.5) var fill: float = 0.0
## A directional light lights a character at no less than this share of full, in its hue.
@export_range(0.0, 1.0) var dir_floor: float = 0.42
## A lamp's light term is multiplied by this before the bands (a point light's falloff keeps its term low).
@export_range(0.5, 6.0) var point_gain: float = 2.2
## The painted terminator: the least band edge (pixels at 1080p), the brush noise's push on the light term.
@export_range(0.0, 12.0) var term_soft: float = 3.0
@export_range(0.0, 0.6) var term_wobble: float = 0.22
## Every shadow-casting light of the level gets at least this shadow blur (the shadow map's PCF kernel), so the
## texel steps of a cast shadow are too soft to survive the posterised bands (0 leaves the world's own).
@export_range(0.0, 8.0) var shadow_blur_min: float = 2.5
## The soft-shadow filter's quality (RenderingServer.ShadowQuality: 0 hard .. 5 ultra) for directional and positional
## lights, and the directional shadow atlas size (0 leaves the project's own).
@export_range(0, 5) var shadow_quality: int = 5
@export_range(0, 8192) var shadow_atlas_size: int = 4096
## Object-space brush grain: a share of the value and cells per metre.
@export_range(0.0, 0.6) var grain_amount: float = 0.14
@export_range(1.0, 200.0) var grain_scale: float = 38.0

@export_group("Rim")
## The rim's colour (the key's tint), strength, the 1 - n.v + key facing at which the band starts, the pull of
## the key's direction, how much curvature narrows it, and the wander of its edge.
@export var rim_color: Color = Color(1.0, 0.6, 0.24)
@export_range(0.0, 2.0) var rim_strength: float = 0.9
@export_range(0.3, 1.0) var rim_cut: float = 0.72
@export_range(0.0, 1.0) var rim_key: float = 0.42
@export_range(0.0, 4.0) var rim_curve: float = 1.2
@export_range(0.0, 0.5) var rim_wobble: float = 0.12
## The key's direction (from a surface to the light, in the world) when the scene has no lamp to find.
@export var key_dir_fallback: Vector3 = Vector3(-0.5, 0.6, -0.6)
## Rim lights that follow the nearest characters: an omni light behind each, on the key's side. Their number,
## energy, range, colour, and where they sit relative to the character (x toward the key's side, y above,
## z behind it as seen from the camera).
@export var rim_lights: bool = true
@export_range(0, 4) var rim_light_count: int = 2
@export_range(0.0, 4.0) var rim_light_energy: float = 0.7
@export_range(0.5, 8.0) var rim_light_range_m: float = 2.6
@export var rim_light_color: Color = Color(1.0, 0.62, 0.3)
@export var rim_light_offset: Vector3 = Vector3(0.9, 1.0, 1.1)

@export_group("Hatching")
## Hatching in the shadow band, on for close-ups: it fades in as the nearest character comes inside
## hatch_near_m and is gone beyond hatch_far_m. `hatch_force` (0..1) pins it on for an A/B.
@export var hatch_enabled: bool = true
@export_range(0.0, 1.0) var hatch_force: float = 0.0
@export_range(0.2, 10.0) var hatch_near_m: float = 1.6
@export_range(0.5, 20.0) var hatch_far_m: float = 3.2
@export_range(0.5, 12.0) var hatch_scale: float = 3.2
@export_range(0.0, 1.0) var hatch_dark: float = 0.7

@export_group("Line")
## The ink (a warm brown-black, never pure black), the hull's width at 1080p, the weight on the shadow side
## and on the lit side (x the width), the thinning with distance, and the wander along the contour.
@export var ink_color: Color = Color(0.09, 0.055, 0.05)
@export_range(0.0, 8.0) var hull_px: float = 3.2
@export_range(0.2, 4.0) var heavy_mult: float = 1.7
@export_range(0.0, 2.0) var thin_mult: float = 0.25
@export_range(0.0, 1.0) var far_thin: float = 0.45
@export_range(0.0, 60.0) var thin_start_m: float = 5.0
@export_range(1.0, 100.0) var thin_end_m: float = 20.0
@export_range(0.0, 1.0) var wander: float = 0.45
@export_range(0.5, 40.0) var wander_scale: float = 7.0
## Sketch mode (close-ups): extra jittered hull passes (1 or 2 more than the main one), their offset (pixels at
## 1080p) and width share, re-seeded from the output frame at `boil_fps`.
@export var sketch_mode: bool = false
@export_range(1, 2) var sketch_extra_passes: int = 2
@export_range(0.0, 12.0) var sketch_jitter_px: float = 3.2
@export_range(0.0, 1.5) var sketch_width_scale: float = 0.7
@export_range(1.0, 24.0) var boil_fps: float = 12.0
## The line's hierarchy (round 3). The taper swells and pinches the width along the contour (a share), over cells per
## metre; `break_amount` lifts the line on the lit side where that noise is low (0 = unbroken). `fp_weight` scales the
## first-person body's line (the arm is a third of the frame: the heaviest, tapered line on screen) and `char_weight`
## every other character's; the arm's taper runs over `fp_taper_scale` cells per metre (longer swells).
@export_range(0.0, 1.0) var taper_amount: float = 0.6
@export_range(0.5, 40.0) var taper_scale: float = 3.0
@export_range(0.0, 1.0) var break_amount: float = 0.7
@export_range(0.0, 4.0) var char_weight: float = 1.0
@export_range(0.0, 4.0) var fp_weight: float = 1.0
@export_range(0.5, 40.0) var fp_taper_scale: float = 2.0

@export_group("Screen ink")
## The screen-space ink pass (characters' creases and inner lines, the environment's major silhouettes only,
## thinning and dropping out with distance) and its values; the game's constant-width edge quad is hidden.
@export var screen_ink: bool = true
@export_range(0.5, 6.0) var ink_width_thin_px: float = 1.0
@export_range(0.5, 8.0) var ink_width_heavy_px: float = 2.8
@export_range(0.0, 1.0) var ink_alpha: float = 0.94
@export_range(0.02, 1.0) var ink_depth_threshold: float = 0.07
@export_range(0.05, 1.0) var ink_normal_threshold: float = 0.45
@export_range(0.5, 40.0) var ink_env_major_m: float = 6.0
@export_range(1.0, 100.0) var ink_fade_start_m: float = 8.0
@export_range(2.0, 200.0) var ink_fade_end_m: float = 34.0
@export_range(0.0, 1.0) var ink_wobble: float = 0.55
@export_range(0.5, 40.0) var ink_wobble_scale: float = 4.5
## How strongly a character's creases draw (0 = silhouettes only).
@export_range(0.0, 1.0) var ink_crease_gain: float = 1.0
## The hierarchy: the screen ink's weight on environment pixels (the world draws its own lines) and on a character's
## creases against its silhouette (1 = as heavy), and the separation band: the environment's darkening within
## `sep_px` (1080p pixels) of a figure at least `sep_min_m` from the lens, in `sep_color` at `sep_alpha` (0 = none).
@export_range(0.0, 1.0) var ink_env_weight: float = 0.5
@export_range(0.0, 1.0) var ink_inner_weight: float = 0.6
## The terminator line: a thin inner line on the dark side of each paint step inside a character (the toon bands' edges), read from the
## rendered colour: its strength (0 = none), the luminance step in stops where it starts and is full, its width (1080p pixels).
@export_range(0.0, 1.0) var term_line: float = 1.0
@export var term_stops: Vector2 = Vector2(0.2, 0.42)
@export_range(0.5, 6.0) var term_px: float = 2.4
@export_range(0.0, 4.0) var term_lod: float = 1.2
@export var sep_color: Color = Color(0.02, 0.02, 0.06)
@export_range(0.0, 1.0) var sep_alpha: float = 0.3
@export_range(0.0, 60.0) var sep_px: float = 14.0
@export_range(0.0, 10.0) var sep_min_m: float = 1.5

## A debug view of the screen ink for looks and A/Bs (0 = the picture; 1 light factor; 2 line width; 3 lines only; 4 character tag; 5 terminator line).
@export_range(0, 5) var ink_debug_view: int = 0

@export_group("Cues")
## Characters on twos: each character's pose holds for `twos_hold` output frames (the frame writer's 24 fps,
## so 2 = 12 drawings a second) while the camera moves every frame.
@export var on_twos: bool = true
@export_range(1, 4) var twos_hold: int = 2
## The output frame rate the holds and the boil are counted in.
@export_range(1.0, 60.0) var output_fps: float = 24.0
## Smears on fast limbs: a streak along the fists' and the foot's path while an attack is on.
@export var smears: bool = true
@export_range(1.0, 20.0) var smear_min_speed: float = 5.0
@export_range(2, 16) var smear_samples: int = 7
@export_range(0.02, 0.6) var smear_width_m: float = 0.16
@export_range(0.0, 1.0) var smear_alpha: float = 0.85
@export var smear_color: Color = Color(1.0, 0.93, 0.8)
## The game's comic words and starbursts hidden (neither reference has them).
@export var hide_comic_fx: bool = true
## Flash frames and speed lines inside the 3D render, on finisher hits (and heavy ones with flash_on_heavy):
## the game's are CanvasLayers that never reach the 2560x1440 viewport. The flash holds `flash_ticks`
## simulation ticks, the lines `lines_ticks`.
@export var flash_frames: bool = true
@export var speed_lines: bool = true
@export var flash_on_heavy: bool = false
@export_range(1, 30) var flash_ticks: int = 5
@export_range(1, 60) var lines_ticks: int = 18
@export_range(0.0, 1.0) var flash_alpha: float = 0.78
@export_range(0.0, 1.0) var lines_alpha: float = 0.8
@export var flash_paper: Color = Color(1.0, 0.96, 0.88)

## The rear warning, drawn in the cue pass (the HUD's never reaches the render): on or off, and the burst's size as a share of the HUD's.
@export var rear_warning: bool = true
@export_range(0.3, 2.5) var warning_scale: float = 1.3

@export_group("Brush")
## The brush pass (round 4): an anisotropic Kuwahara filter and a soft posterize on the world's pixels, before the transparent pass (haze,
## steam, flames and mattes draw over it, the screen ink draws its lines over it); characters and the sky are never brushed. `brush_on` false
## switches it off for an A/B. The radius, in pixels at 1080p, is `brush_r_near` at the lens and `brush_r_far` from `brush_depth_far_m` (a smooth
## step from `brush_depth_near_m`), plus `brush_focus_gain` far from the shot's focus and `brush_edge_gain` toward the frame's edge (from
## `brush_edge_start` of the radius), and at most `brush_r_max`.
@export var brush_on: bool = true
@export_range(0.0, 16.0) var brush_r_near: float = 2.0
@export_range(0.0, 24.0) var brush_r_far: float = 7.0
@export_range(0.0, 60.0) var brush_depth_near_m: float = 3.0
@export_range(0.5, 120.0) var brush_depth_far_m: float = 22.0
@export_range(0.0, 12.0) var brush_focus_gain: float = 2.0
@export_range(0.0, 12.0) var brush_edge_gain: float = 2.0
@export_range(0.0, 1.0) var brush_edge_start: float = 0.55
@export_range(1.0, 24.0) var brush_r_max: float = 10.0
## The ellipse's roundness (1 = elongated along an edge as the structure tensor says, larger = rounder), the sector weight's exponent (larger =
## crisper edges), and the taps from the middle to the edge of the window (the stride grows with the radius).
@export_range(0.2, 8.0) var brush_aniso_alpha: float = 1.0
@export_range(1.0, 16.0) var brush_sharpness: float = 8.0
@export_range(2, 8) var brush_tap_half: int = 5
## The mip level of the screen the structure tensor is read at (the paint's fine texture blurs out, the strokes follow the shapes).
@export_range(0.0, 3.0) var brush_tensor_lod: float = 1.0
## The hand wobble: pixels at 1080p and the world cell in metres of the low-frequency noise (a depth-buffer position, so it holds on the world).
@export_range(0.0, 12.0) var brush_wobble_px: float = 3.0
@export_range(0.2, 20.0) var brush_wobble_cell_m: float = 1.6
## A tap across a relative depth step larger than this is not sampled: a pole's edge stays hard.
@export_range(0.01, 1.0) var brush_depth_reject: float = 0.12
## The soft posterize: the band in stops of luminance (0 = off), the edge softness (a share of a band), the share applied, and the world noise on the
## band edges (a share of a band, cell in metres) so they are hand-cut, not contours.
@export_range(0.0, 3.0) var brush_post_step: float = 0.55
@export_range(0.0, 1.0) var brush_post_soft: float = 0.25
@export_range(0.0, 1.0) var brush_post_mix: float = 1.0
@export_range(0.0, 1.0) var brush_post_noise: float = 0.3
@export_range(0.1, 20.0) var brush_post_cell_m: float = 0.9
## A debug view (0 = the picture; 1 = the radius and anisotropy; 2 = the orientation; 3 = the wobble's noise; 4 = the tags).
@export_range(0, 4) var brush_debug_view: int = 0

@export_group("Post")
## The finish pass (a CompositorEffect): the static paper grain (a share of value), the vignette (a share of the
## value at the corner and where it starts), a little chromatic aberration (a fraction of the frame at the corner).
@export var post_enabled: bool = true
@export_range(0.0, 0.3) var post_grain: float = 0.05
@export_range(0.5, 6.0) var post_grain_cell_px: float = 1.6
@export_range(0.0, 1.0) var post_paper_seed: float = 0.37
@export_range(0.0, 1.0) var post_vignette: float = 0.35
@export_range(0.0, 1.0) var post_vignette_start: float = 0.45
@export_range(0.0, 0.01) var post_aberration: float = 0.0008

@export_group("Grade")
## The grade, in the finish pass on the linear colour (before the LUT): the darks pushed toward `grade_dark_tint` at their own
## luminance (a share), desaturated by `grade_dark_desat`, over the luminance range lo..hi (linear); the highlights multiplied by
## `grade_high_tint` (a share). Night: navy and indigo with desaturated darks; the boss roof maroon-violet darks; the roofs violet.
@export var grade_dark_tint: Color = Color(0.18, 0.2, 0.42)
@export_range(0.0, 1.0) var grade_dark_amount: float = 0.0
@export_range(0.0, 1.0) var grade_dark_desat: float = 0.0
@export_range(0.0, 0.5) var grade_dark_lo: float = 0.01
@export_range(0.001, 1.0) var grade_dark_hi: float = 0.08
@export var grade_high_tint: Color = Color(1.0, 1.0, 1.0)
@export_range(0.0, 1.0) var grade_high_amount: float = 0.0

@export_group("Delivery")
## The delivery pass (the references are seen through a stream: soft, with grain; ours are pixel-sharp): a sub-pixel soften (a share
## blended toward a 3x3 kernel; a one-pixel line keeps most of its weight) and a fine grain that is new every `grain_hold` output
## frames (on twos). `delivery_on` false switches both off for an A/B; the grade and the paper grain stay.
@export var delivery_on: bool = true
@export_range(0.0, 1.0) var deliver_soften: float = 0.45
@export_range(0.0, 0.2) var deliver_grain: float = 0.035
@export_range(1, 4) var grain_hold: int = 2
## The delivery's re-scale (round 4): the picture is box-filtered to this share of the render size and bicubic-scaled back, so its frequency
## content is the references' (1440p streams that look upscaled from a lower master). 1 = off. Lines stay lines.
@export_range(0.3, 1.0) var deliver_scale: float = 0.75

@export_group("Palette")
## The location's palette LUT strip (tools/video/palette_lut.py; N slices of N x N: slice = blue, x = red,
## y = green). Empty, or a missing file, leaves the grade as it is.
@export_file("*.png") var lut_path: String = ""


## Add the ink rig under `level` (once) and start it.
func apply(level: Node) -> void:
	if level == null or level.get_node_or_null(^"CineInkRig") != null:
		return
	var rig := CineInkRig.new()
	rig.name = "CineInkRig"
	rig.look = self
	level.add_child(rig)
	rig.setup(level)
