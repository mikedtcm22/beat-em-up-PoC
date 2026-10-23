class_name TuningData
extends Resource
## Every global tunable value (Spec §11). Per-move numbers live in each MoveData .tres.
## Exported properties with range hints become tuning-panel sliders (Milestone 2), so
## add new values here with @export_range and a group, never as script constants.

@export_group("Player movement")
@export_range(1.0, 12.0, 0.1) var move_speed: float = 6.0
@export_range(5.0, 200.0, 1.0) var move_accel: float = 60.0
@export_range(5.0, 200.0, 1.0) var move_decel: float = 80.0
## Fraction of move_speed the player may steer with while attacking.
@export_range(0.0, 1.0, 0.05) var attack_move_mult: float = 0.2
@export_range(2.0, 15.0, 0.1) var jump_velocity: float = 6.5
@export_range(5.0, 60.0, 0.5) var gravity: float = 22.0
## A K press within this many frames of the jump's apex becomes the spin kick.
@export_range(0, 20, 1) var apex_window_frames: int = 6
@export_range(0.5, 6.0, 0.1) var dodge_distance: float = 3.0
@export_range(4, 40, 1) var dodge_frames: int = 14
@export_range(0, 30, 1) var dodge_invuln_frames: int = 8
@export_range(4, 40, 1) var quick_turn_frames: int = 12
## Degrees of look per pixel of mouse motion.
@export_range(0.01, 1.0, 0.01) var mouse_sensitivity: float = 0.12
## Degrees per second of look at full right-stick deflection.
@export_range(30.0, 600.0, 5.0) var stick_look_speed: float = 200.0
@export_range(0.0, 0.5, 0.01) var stick_deadzone: float = 0.15
@export var invert_look_y: bool = false

@export_group("Combo windows")
@export_range(0, 20, 1) var input_buffer_frames: int = 8
@export_range(0, 60, 1) var pause_min_frames: int = 12
@export_range(0, 120, 1) var pause_max_frames: int = 30
@export_range(6, 90, 1) var hold_frames: int = 24

@export_group("Magnetism")
@export_range(0.0, 90.0, 1.0) var magnet_half_angle_deg: float = 35.0
@export_range(0.0, 6.0, 0.1) var magnet_range: float = 2.5
@export_range(0.0, 3.0, 0.05) var magnet_lunge: float = 0.8
@export_range(0.0, 45.0, 1.0) var magnet_turn_deg: float = 15.0
## Lunges stop when the attacker's center is this close to the target's center.
@export_range(0.4, 1.5, 0.05) var magnet_stop_distance: float = 0.85

@export_group("Grab and weapons")
@export_range(0.5, 3.0, 0.1) var grab_range: float = 1.3
@export_range(0.0, 90.0, 1.0) var grab_half_angle_deg: float = 60.0
@export_range(30, 600, 10) var hold_max_frames: int = 180
@export_range(1, 5, 1) var max_knees: int = 3
@export_range(0.5, 3.0, 0.1) var pickup_range: float = 1.5
@export_range(1, 20, 1) var weapon_durability: int = 8
@export_range(5.0, 30.0, 0.5) var weapon_throw_speed: float = 16.0
@export_range(0.5, 3.0, 0.1) var stomp_range: float = 1.5

@export_group("Reactions")
@export_range(10, 90, 1) var stagger_frames: int = 40
@export_range(30, 150, 1) var downed_frames: int = 75
@export_range(10, 60, 1) var getup_frames: int = 30
@export_range(0, 60, 1) var getup_invuln_frames: int = 30
## Deceleration of knockback slides on the ground (m/s^2).
@export_range(0.0, 60.0, 0.5) var ground_friction: float = 14.0
## A flying body must move at least this fast (m/s) to knock down whoever it hits.
@export_range(0.5, 15.0, 0.5) var body_impact_min_speed: float = 3.0
@export_range(5.0, 500.0, 1.0) var dummy_health: float = 30.0
@export_range(0.0, 10.0, 0.1) var dummy_revive_s: float = 2.5

@export_group("Feel details")
## Fraction of move speed while holding a grabbed enemy, and while airborne.
@export_range(0.0, 1.0, 0.05) var hold_move_mult: float = 0.5
@export_range(0.0, 1.0, 0.05) var air_control_mult: float = 0.5
## Push given to a grabbed enemy when released (m/s).
@export_range(0.0, 8.0, 0.1) var release_push: float = 2.5
## Stomps stop this close to the downed body's chest; stomp targets must sit in this cone.
@export_range(0.2, 1.2, 0.05) var stomp_stop_distance: float = 0.45
@export_range(10.0, 120.0, 1.0) var stomp_half_angle_deg: float = 70.0
## Frames the player can't act after landing a jump / picking up a weapon.
@export_range(0, 20, 1) var land_lock_frames: int = 3
@export_range(0, 30, 1) var pickup_lock_frames: int = 10
## Every launch leaves the ground at least this fast (m/s).
@export_range(0.0, 8.0, 0.1) var min_launch_up: float = 2.5
## A killing light hit still knocks the victim down at least this hard (m/s).
@export_range(0.0, 8.0, 0.1) var ko_push: float = 2.5
@export_range(0.0, 8.0, 0.1) var ko_lift: float = 3.0
## Fraction of horizontal speed kept when a flying body lands.
@export_range(0.0, 1.0, 0.05) var landing_slide_keep: float = 0.35
## Frames of white flash on a struck victim (Spec §6: 2), counted in real ticks.
@export_range(0, 10, 1) var hit_flash_frames: int = 2
@export_range(0.5, 6.0, 0.1) var dummy_walk_speed: float = 2.5

@export_group("Hit feel")
@export_range(0.0, 300.0, 1.0) var hitstop_light_ms: float = 50.0
@export_range(0.0, 300.0, 1.0) var hitstop_heavy_ms: float = 85.0
@export_range(0.0, 300.0, 1.0) var hitstop_finisher_ms: float = 140.0
@export_range(0.0, 10.0, 0.1) var cam_punch_light_deg: float = 0.5
@export_range(0.0, 10.0, 0.1) var cam_punch_heavy_deg: float = 1.5
@export_range(0.0, 10.0, 0.1) var cam_punch_finisher_deg: float = 3.0
@export_range(0.0, 1.0, 0.01) var shake_light: float = 0.1
@export_range(0.0, 1.0, 0.01) var shake_heavy: float = 0.25
@export_range(0.0, 1.0, 0.01) var shake_finisher: float = 0.5
@export_range(0.05, 1.0, 0.05) var slowmo_scale: float = 0.3
@export_range(0.0, 1000.0, 10.0) var slowmo_ms: float = 250.0
@export var impact_frame_enabled: bool = true

@export_group("VFX")
## Comic effects (Spec §6; VfxDirector, game/fx/). Sizes are meters at the contact point
## (a word's or a burst's width); times are seconds of sim time, so slow-mo stretches them.
## Every effect size is multiplied by this.
@export_range(0.0, 3.0, 0.05) var vfx_scale: float = 1.0
## A world effect never covers more than this share of the view's width, so a hit a meter
## from the first-person lens never fills the screen (the side view sees full sizes).
@export_range(0.05, 1.0, 0.01) var vfx_max_view_share: float = 0.25
## ...and never less than this share (bursts, sparks and words), so hits seen from afar
## (the side view) stay readable.
@export_range(0.0, 0.3, 0.01) var vfx_min_view_share: float = 0.06
## Effects nearer the camera than this are pushed out along the view ray (hits on the
## first-person player land at the lens).
@export_range(0.1, 1.5, 0.05) var vfx_min_camera_dist_m: float = 0.45
@export_range(0.0, 2.0, 0.01) var vfx_burst_small_m: float = 0.24
@export_range(0.0, 2.0, 0.01) var vfx_burst_medium_m: float = 0.36
@export_range(0.0, 2.0, 0.01) var vfx_burst_large_m: float = 0.62
@export_range(0.03, 1.0, 0.01) var vfx_burst_s: float = 0.18
## Share of a burst's, a spark's or a splash's time spent fading out at its end.
@export_range(0.0, 1.0, 0.05) var vfx_burst_fade_share: float = 0.4
## Seconds a burst or a word takes to pop in: from vfx_pop_start of its size up past it to
## vfx_pop_peak, then back to full size.
@export_range(0.0, 0.3, 0.005) var vfx_pop_s: float = 0.07
@export_range(0.0, 1.0, 0.05) var vfx_pop_start: float = 0.5
@export_range(1.0, 2.0, 0.05) var vfx_pop_peak: float = 1.25
## Chance of comic lettering per hit tier (Spec §6: light hits none or a small word).
@export_range(0.0, 1.0, 0.05) var vfx_word_chance_light: float = 0.0
@export_range(0.0, 1.0, 0.05) var vfx_word_chance_heavy: float = 1.0
@export_range(0.0, 1.0, 0.05) var vfx_word_chance_finisher: float = 1.0
## Word widths: small (light), medium (heavy), large (finisher).
@export_range(0.0, 2.0, 0.01) var vfx_word_small_m: float = 0.3
@export_range(0.0, 2.0, 0.01) var vfx_word_medium_m: float = 0.42
@export_range(0.0, 2.0, 0.01) var vfx_word_large_m: float = 0.6
@export_range(0.1, 2.0, 0.05) var vfx_word_s: float = 0.6
## Share of a word's time spent fading out at its end.
@export_range(0.0, 1.0, 0.05) var vfx_word_fade_share: float = 0.35
## A word sits this many of its widths above the contact point and this many to a random
## side (on screen), drifts up vfx_word_rise_m over its time and tilts up to the angle.
@export_range(0.0, 1.5, 0.05) var vfx_word_lift: float = 0.45
@export_range(0.0, 1.0, 0.05) var vfx_word_side: float = 0.3
@export_range(0.0, 0.5, 0.01) var vfx_word_rise_m: float = 0.06
@export_range(0.0, 30.0, 1.0) var vfx_word_tilt_deg: float = 10.0
## Words stay inside the view, at least this share of its width from the edges.
@export_range(0.0, 0.3, 0.01) var vfx_word_view_margin: float = 0.04
## Radial speed lines (a screen overlay) on finishers and on the player's lunges (first
## person), fading over these times.
@export_range(0.0, 1.5, 0.05) var vfx_speed_lines_s: float = 0.35
@export_range(0.0, 1.5, 0.05) var vfx_lunge_lines_s: float = 0.2
@export_range(0, 80, 1) var vfx_speed_lines_count: int = 34
## Thickness of the lines (1 = as drawn in speed_lines.png).
@export_range(0.1, 3.0, 0.05) var vfx_speed_lines_width: float = 1.6
@export_range(0.0, 1.0, 0.05) var vfx_speed_lines_opacity: float = 0.85
@export_range(0.0, 1.0, 0.05) var vfx_lunge_lines_opacity: float = 0.45
## The lines stay outside this share of the screen's half-diagonal around their focus.
@export_range(0.0, 0.9, 0.05) var vfx_speed_lines_clear: float = 0.5
## Real 60 Hz frames between redraws of the lines in new places (the comic flicker).
@export_range(1, 10, 1) var vfx_speed_lines_redraw_frames: int = 2
## A player attack that has lunged this far (meters) shows the lunge lines.
@export_range(0.1, 3.0, 0.05) var vfx_lunge_lines_min_m: float = 0.6
## The finisher impact frame (Spec §6: 1-2 frames), in 60 Hz frames, and the luminance
## above which its inverted ink flash prints ink (the rest prints paper).
@export_range(0, 6, 1) var vfx_impact_frame_frames: int = 2
@export_range(0.0, 1.0, 0.01) var vfx_impact_frame_threshold: float = 0.45
## Blood (heavy and finisher hits): chance, droplets, and the splash at the contact.
@export_range(0.0, 1.0, 0.05) var vfx_blood_chance_heavy: float = 1.0
@export_range(0.0, 1.0, 0.05) var vfx_blood_chance_finisher: float = 1.0
@export_range(0, 40, 1) var vfx_blood_drops_heavy: int = 5
@export_range(0, 40, 1) var vfx_blood_drops_finisher: int = 12
@export_range(0.0, 0.3, 0.005) var vfx_blood_drop_m: float = 0.05
## Droplet launch speed (m/s), along the hit (spread either side by the angle) and up.
@export_range(0.0, 10.0, 0.1) var vfx_blood_speed: float = 2.6
@export_range(0.0, 90.0, 1.0) var vfx_blood_spread_deg: float = 40.0
## Droplets, spit and teeth vary their size and launch speed by up to these shares.
@export_range(0.0, 0.9, 0.05) var vfx_particle_size_jitter: float = 0.3
@export_range(0.0, 0.9, 0.05) var vfx_particle_speed_jitter: float = 0.5
## The splash is drawn behind the burst, so its droplets ring the burst.
@export_range(0.0, 1.0, 0.01) var vfx_blood_spray_m: float = 0.5
@export_range(0.03, 1.0, 0.01) var vfx_blood_spray_s: float = 0.22
## Splats left where droplets land: size, seconds before they fade, and how many at most.
@export_range(0.0, 1.0, 0.01) var vfx_blood_splat_m: float = 0.22
@export_range(0.0, 60.0, 0.5) var vfx_blood_splat_s: float = 8.0
@export_range(0, 200, 1) var vfx_blood_splat_max: int = 40
## Head finishers: spit droplets and the chance of a tooth.
@export_range(0, 20, 1) var vfx_spit_drops: int = 6
@export_range(0.0, 0.2, 0.005) var vfx_spit_drop_m: float = 0.035
@export_range(0.1, 3.0, 0.05) var vfx_spit_s: float = 0.6
@export_range(0.0, 1.0, 0.05) var vfx_tooth_chance: float = 0.6
@export_range(0.0, 0.2, 0.005) var vfx_tooth_m: float = 0.05
## Turns per second a flying tooth tumbles (either way, up to this).
@export_range(0.0, 6.0, 0.25) var vfx_tooth_spin: float = 2.0
## Gravity on blood, spit and teeth (m/s²), and the longest a droplet flies.
@export_range(0.0, 40.0, 0.5) var vfx_gravity: float = 14.0
@export_range(0.1, 3.0, 0.05) var vfx_particle_s: float = 1.2
## Blocked hits: the block spark, the parry spark (perfect block) and the guard-break burst.
@export_range(0.0, 2.0, 0.01) var vfx_block_spark_m: float = 0.2
@export_range(0.0, 2.0, 0.01) var vfx_parry_spark_m: float = 0.42
@export_range(0.0, 2.0, 0.01) var vfx_guard_break_m: float = 0.5
@export_range(0.03, 1.5, 0.01) var vfx_block_fx_s: float = 0.22
## Damage looks (Spec §6): an enemy looks bruised at or below this share of its health,
## bloodied at or below the next; one damage-texture tile spans this many meters.
@export_range(0.0, 1.0, 0.01) var vfx_bruised_at: float = 0.66
@export_range(0.0, 1.0, 0.01) var vfx_bloodied_at: float = 0.33
@export_range(0.05, 2.0, 0.05) var vfx_damage_tile_m: float = 0.4

@export_group("Camera")
@export_range(75.0, 110.0, 1.0) var fov_deg: float = 90.0
@export_range(0.0, 0.3, 0.005) var cam_smoothing_s: float = 0.05
@export_range(0.0, 0.05, 0.001) var cam_bob_clamp_m: float = 0.015
## The first-person lens sits this far from EyePoint: up/down (negative = lower) and ahead
## along the flat look. Game-boy's call after the M1 playtest: lower, near the throat, so
## hands and feet both fit in the view (Mirror's Edge style) instead of an eye-level
## "dukes up" gun view. Only a little ahead: with the relaxed stance's arms low there is no
## guard to clear at rest, and a lens close over the body keeps the block guard's forearms
## 0.3 m or more away (PlaceholderPoses.block_guard_arms() is authored for these values),
## the lead foot ahead of it when looking down and a held victim's head further off (much
## closer, the belly comes up under the lens over the legs). Presentation only: aim and
## hit detection never use it.
@export_range(-0.5, 0.1, 0.01) var cam_height_offset_m: float = -0.2
@export_range(0.0, 0.3, 0.01) var cam_forward_offset_m: float = 0.04
@export_range(0.0, 1.0, 0.05) var screen_shake_intensity: float = 1.0
## Scales every move's camera_spin_follow: 1 turns the first-person view with a spinning
## move's body (the spin kick, spinning heel kick and spinning backfist land back on the
## heading), 0 keeps the view on the look. Presentation only.
@export_range(0.0, 1.0, 0.05) var cam_spin_follow_mult: float = 1.0
@export var show_center_dot: bool = true

@export_group("Enemies")
## Max simultaneous attackers; 0 = unlimited (Milestone 3).
@export_range(0, 6, 1) var attacker_cap: int = 3
@export_range(0.0, 1.0, 0.05) var blind_spot_priority: float = 1.0
@export_range(0.25, 3.0, 0.05) var windup_mult: float = 1.0

@export_group("Rear warning")
@export_range(20.0, 120.0, 1.0) var rear_warning_angle_deg: float = 55.0
@export_range(0.25, 3.0, 0.05) var rear_warning_size: float = 1.0
@export_range(0.0, 1.0, 0.05) var rear_warning_opacity: float = 0.9
@export var rear_warning_audio: bool = true

@export_group("Block")
## B with the stick under this deflection blocks; above it, B dodges that way.
@export_range(0.05, 0.9, 0.05) var block_stick_threshold: float = 0.3
## Frames of holding before the guard is effective. 1 since Game-boy's second playtest:
## a press on reaction to a wind-up has to be up in time.
@export_range(0, 15, 1) var block_raise_frames: int = 1
## A guard raised by B with the stick centered turns into a dodge when the stick passes
## block_stick_threshold within this many frames of the press: B (or Shift) pressed a
## moment before the direction still dodges. Never after the guard has stopped a hit.
@export_range(0, 20, 1) var dodge_late_stick_frames: int = 8
## Frames back to neutral after releasing B.
@export_range(0, 20, 1) var block_release_frames: int = 4
## Frames from pressing P/K while blocking until the attack starts.
@export_range(0, 15, 1) var block_attack_cancel_frames: int = 2
## Hits from attackers within this many degrees of the facing are blocked.
@export_range(10.0, 180.0, 1.0) var block_arc_half_angle_deg: float = 60.0
@export_range(0.0, 1.0, 0.05) var block_move_mult: float = 0.35
## Share of a blocked hit's damage that still gets through (never below 1 health).
@export_range(0.0, 1.0, 0.01) var chip_ratio: float = 0.15
@export_range(0, 40, 1) var blockstun_light_frames: int = 10
@export_range(0, 40, 1) var blockstun_heavy_frames: int = 16
@export_range(0.0, 2.0, 0.05) var block_push_light_m: float = 0.3
@export_range(0.0, 2.0, 0.05) var block_push_heavy_m: float = 0.6
@export_range(0.0, 300.0, 1.0) var block_hitstop_ms: float = 30.0
@export_range(10.0, 400.0, 5.0) var guard_max: float = 100.0
## Guard drained per point of blocked damage (times the move's guard_damage_mult).
@export_range(0.0, 20.0, 0.5) var guard_drain_per_damage: float = 4.0
@export_range(0.0, 200.0, 1.0) var guard_regen_per_s: float = 35.0
@export_range(0.0, 5.0, 0.05) var guard_regen_delay_s: float = 0.75
@export_range(0, 120, 1) var guard_break_frames: int = 45
## Guard the meter returns to after a guard break.
@export_range(0.0, 400.0, 5.0) var guard_break_refill: float = 50.0
## Thrown or launched bodies blocked from the front drain the guard this many times harder.
@export_range(0.0, 5.0, 0.1) var body_impact_guard_mult: float = 2.0
@export var perfect_block_enabled: bool = true
## A hit landing within this many frames of a guard raised by a fresh B press (counted from
## the raise; a press buffered in a move raises it when the move can be cancelled) is a
## perfect block (about 0.23 s: a press on reaction to a sparring jab's 24-frame wind-up parries).
@export_range(0, 30, 1) var perfect_block_window_frames: int = 14
@export_range(0, 90, 1) var perfect_block_stagger_frames: int = 30
## Real ticks the defender's rig flashes cyan on a perfect block (the parry flash).
@export_range(0, 30, 1) var parry_flash_frames: int = 8

@export_group("Sparring")
## Seconds from the start of one of a sparring dummy's jabs to the next (varied a little).
@export_range(0.5, 10.0, 0.1) var sparring_interval_s: float = 2.0
## Each wait is sparring_interval_s plus or minus up to this much (seeded per dummy).
@export_range(0.0, 2.0, 0.05) var sparring_jitter_s: float = 0.3
## A sparring dummy spars with the player within this range in front of it.
@export_range(0.8, 4.0, 0.1) var sparring_range: float = 1.7
## ...and within this many degrees of the dummy's facing.
@export_range(5.0, 90.0, 1.0) var sparring_facing_deg: float = 30.0
## Sparring, the dummy walks in (at dummy_walk_speed) until the player is this close,
## center to center, and only jabs from there: inside the jab's reach (about 1.05 m).
@export_range(0.7, 1.05, 0.01) var sparring_step_in_m: float = 0.9
## Test room: seconds before a KO'd player gets back up at full health.
@export_range(0.5, 10.0, 0.1) var player_revive_s: float = 2.5

@export_group("Audio")
## Volume of every sound effect (the SFX bus), in dB.
@export_range(-40.0, 6.0, 0.5) var sfx_volume_db: float = 0.0
## Each one-shot's pitch varies at random by up to plus or minus this share (Spec §6: 8%).
@export_range(0.0, 0.3, 0.01) var sfx_pitch_variation: float = 0.08
## ...and its volume (as amplitude) by up to plus or minus this share (Spec §6: 8%).
@export_range(0.0, 0.3, 0.01) var sfx_volume_variation: float = 0.08
## Layer volumes in dB (every sample is normalized to the same peak). Light hits play whoosh
## + thud, heavy hits add the crack, finishers play whoosh + thud + crunch + body fall + sub
## thump (Spec §6).
@export_range(-40.0, 12.0, 0.5) var whoosh_db: float = -13.0
@export_range(-40.0, 12.0, 0.5) var thud_db: float = -6.0
@export_range(-40.0, 12.0, 0.5) var crack_db: float = -7.0
@export_range(-40.0, 12.0, 0.5) var crunch_db: float = -8.0
@export_range(-40.0, 12.0, 0.5) var body_fall_db: float = -10.0
@export_range(-40.0, 12.0, 0.5) var sub_thump_db: float = -8.0
## A missed swing's whoosh (attack_whiffed): no impact and no hitstop.
@export_range(-40.0, 12.0, 0.5) var whiff_db: float = -12.0
## An enemy hit cleanly grunts; the player grunts too, at the listener.
@export_range(-40.0, 12.0, 0.5) var grunt_db: float = -9.0
@export_range(-40.0, 12.0, 0.5) var player_grunt_db: float = -13.0
## An actor grunts at most once per this many ms (a body-blow flurry lands every few frames).
@export_range(0.0, 1000.0, 10.0) var grunt_min_interval_ms: float = 300.0
## Each actor's voice is pitched up or down by up to this share, the same every time.
@export_range(0.0, 0.3, 0.01) var voice_pitch_spread: float = 0.1
@export_range(-40.0, 12.0, 0.5) var block_clack_db: float = -8.0
@export_range(-40.0, 12.0, 0.5) var parry_ting_db: float = -7.0
@export_range(-40.0, 12.0, 0.5) var guard_break_db: float = -7.0
## An enemy's wind-up: an effort grunt and a whoosh at the attacker (Spec §8's audio cue,
## on while rear_warning_audio).
@export_range(-40.0, 12.0, 0.5) var windup_db: float = -10.0
## Sounds play at their layer's volume within this distance (m) of the listener (the
## player's eyes), 6 dB quieter at twice it, and so on.
@export_range(0.5, 20.0, 0.5) var sfx_unit_size_m: float = 3.0
## Sounds further away than this (m) are not heard; 0 = no limit.
@export_range(0.0, 100.0, 1.0) var sfx_max_distance_m: float = 40.0
## Sounds from further than this many degrees off the look are muffled (low-passed at
## rear_muffle_hz), so stereo can tell behind from in front.
@export_range(60.0, 180.0, 5.0) var rear_muffle_angle_deg: float = 110.0
## 20500 turns the muffle off.
@export_range(500.0, 20500.0, 100.0) var rear_muffle_hz: float = 2500.0
## Placeholder fight loop (Spec §13 leaves music open: off by default).
@export var music_enabled: bool = false
@export_range(-40.0, 6.0, 0.5) var music_volume_db: float = -14.0
## Controller rumble on hits the player lands or takes (Spec §6). Each pulse drives the
## weak (high-frequency) and strong (low-frequency) motors, 0..1, times rumble_strength.
@export var rumble_enabled: bool = true
@export_range(0.0, 1.0, 0.05) var rumble_strength: float = 1.0
## Light: short and low.
@export_range(0.0, 1.0, 0.05) var rumble_light_weak: float = 0.35
@export_range(0.0, 1.0, 0.05) var rumble_light_strong: float = 0.0
@export_range(0.0, 500.0, 5.0) var rumble_light_ms: float = 70.0
## Heavy (and a guard break): medium.
@export_range(0.0, 1.0, 0.05) var rumble_heavy_weak: float = 0.5
@export_range(0.0, 1.0, 0.05) var rumble_heavy_strong: float = 0.45
@export_range(0.0, 500.0, 5.0) var rumble_heavy_ms: float = 140.0
## Finisher: a strong double pulse, each pulse this long, rumble_finisher_gap_ms apart.
@export_range(0.0, 1.0, 0.05) var rumble_finisher_weak: float = 0.8
@export_range(0.0, 1.0, 0.05) var rumble_finisher_strong: float = 1.0
@export_range(0.0, 500.0, 5.0) var rumble_finisher_ms: float = 120.0
@export_range(0.0, 500.0, 5.0) var rumble_finisher_gap_ms: float = 80.0
## A blocked or parried hit: a light tick.
@export_range(0.0, 1.0, 0.05) var rumble_block_weak: float = 0.25
@export_range(0.0, 1.0, 0.05) var rumble_block_strong: float = 0.0
@export_range(0.0, 500.0, 5.0) var rumble_block_ms: float = 40.0

@export_group("Debug")
@export var god_mode: bool = false
@export var one_hit_ko: bool = false


func hitstop_s(tier: CombatTypes.HitTier) -> float:
	match tier:
		CombatTypes.HitTier.HEAVY:
			return hitstop_heavy_ms / 1000.0
		CombatTypes.HitTier.FINISHER:
			return hitstop_finisher_ms / 1000.0
	return hitstop_light_ms / 1000.0


func shake(tier: CombatTypes.HitTier) -> float:
	match tier:
		CombatTypes.HitTier.HEAVY:
			return shake_heavy
		CombatTypes.HitTier.FINISHER:
			return shake_finisher
	return shake_light


func cam_punch_deg(tier: CombatTypes.HitTier) -> float:
	match tier:
		CombatTypes.HitTier.HEAVY:
			return cam_punch_heavy_deg
		CombatTypes.HitTier.FINISHER:
			return cam_punch_finisher_deg
	return cam_punch_light_deg
