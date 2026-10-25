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
## Leaving a grab, the body unbends over this long (sim seconds) around its bent-over hips,
## so its head rises while it moves away instead of up through the holder's view: released
## on its feet, or launched out of the hold (a throw, or a knee that KOs it).
@export_range(0.0, 0.6, 0.01) var grab_release_blend_s: float = 0.22
@export_subgroup("Hold view")
## While an enemy is held, the first-person view pitches down this many degrees (Game-boy,
## 2026-10-24), so the knees show landing on the held body; a knee's own camera_pitch_deg
## adds to it. Presentation only: aim never uses it.
@export_range(0.0, 45.0, 0.5) var grab_view_pitch_deg: float = 16.0
## The hold's pitch only takes the view down to this many degrees below level in all
## (grab_view_pitch_deg at most): a player already looking down at the held body gets less
## of it, and none from this far down, so the two never stack into a view of the own belly.
## The bots look 6 degrees down and get all of it.
@export_range(0.0, 60.0, 0.5) var grab_view_target_pitch_deg: float = 22.0
## The hold bends the player at the waist, which leans the eyes out over the held body.
## While holding, the first-person lens moves back this far along the flat look and up by
## grab_view_rise_m, so the held enemy stays readable (not a wall of shirt) and the hands
## on its shoulders stay 0.3 m or more from the lens.
@export_range(0.0, 0.3, 0.005) var grab_view_back_m: float = 0.24
@export_range(0.0, 0.15, 0.005) var grab_view_rise_m: float = 0.1
## Seconds the hold view eases in over after a grab, and back out over after a throw or a
## release (any way the hold ends).
@export_range(0.0, 1.0, 0.01) var grab_view_in_s: float = 0.2
@export_range(0.0, 1.0, 0.01) var grab_view_out_s: float = 0.45

@export_group("Reactions")
@export_range(10, 90, 1) var stagger_frames: int = 40
@export_range(30, 150, 1) var downed_frames: int = 75
@export_range(10, 60, 1) var getup_frames: int = 30
@export_range(0, 60, 1) var getup_invuln_frames: int = 30
## A hit's pose snaps in over this long (sim seconds): a launch's, a knee's jolt on a held
## body, a flinch's and a guard break's.
@export_range(0.0, 0.2, 0.005) var reaction_snap_blend_s: float = 0.03
## Deceleration of knockback slides on the ground (m/s^2).
@export_range(0.0, 60.0, 0.5) var ground_friction: float = 14.0
## A flying body must move at least this fast (m/s) to knock down whoever it hits.
@export_range(0.5, 15.0, 0.5) var body_impact_min_speed: float = 3.0
@export_range(5.0, 500.0, 1.0) var dummy_health: float = 30.0
## A training dummy that blinked off after a KO (Ragdoll > "KO and blink-off") is gone this
## long, then blinks back in standing at its post at full health: about 4 s from the KO to
## back with the KO defaults.
@export_range(0.0, 10.0, 0.1) var dummy_revive_s: float = 1.0

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
## The finisher impact frame (Spec §6); off for photosensitive players, which also stops
## the speed lines' flicker.
@export var impact_frame_enabled: bool = true
@export_subgroup("Hit flash")
## The white flash on a struck body (Spec §6), localized by Game-boy (2026-10-24): full white
## at the hit's contact point, fading out by hit_flash_radius_m. A blocked hit flashes at
## CombatActor.BLOCK_FLASH_AMOUNT of the strength; the cyan parry flash stays whole-body.
## Frames it shows for (Spec: 2), counted in real ticks (one rendered frame each at 60 Hz),
## so hitstop doesn't stretch it.
@export_range(0, 10, 1) var hit_flash_frames: int = 2
## How far from the contact point the flash reaches (meters, on the struck body only). 0.25
## is about a head's width; about 4 whites the whole body, the flash before the change.
@export_range(0.0, 4.0, 0.01, "or_greater") var hit_flash_radius_m: float = 0.25
## How white the flash gets at the contact point (1 = pure white).
@export_range(0.0, 1.0, 0.05) var hit_flash_strength: float = 1.0
## Share of hit_flash_radius_m flashing at full strength before the smooth fade to nothing.
@export_range(0.0, 1.0, 0.05) var hit_flash_core: float = 0.5

@export_group("VFX")
## Comic effects (Spec §6; VfxDirector, game/fx/). Sizes are meters at the contact point
## (a word's or a burst's width); times are seconds of sim time, so slow-mo stretches them.
@export_subgroup("Size and view")
## Every effect size is multiplied by this.
@export_range(0.0, 3.0, 0.05) var vfx_scale: float = 1.0
## A world effect never covers more than this share of the view's width, so a hit a meter
## from the first-person lens never fills the screen. The largest of a kind (the finisher
## burst, the large word) sets the cap; smaller tiers shrink with it, keeping their ratio.
@export_range(0.05, 1.0, 0.01) var vfx_max_view_share: float = 0.25
## ...and never less than this share, so hits seen from afar (the side view) stay
## readable. The smallest of a kind (the light burst) sets the floor; bigger tiers grow
## with it, keeping their ratio. The cap wins when both can't hold.
@export_range(0.0, 0.3, 0.01) var vfx_min_view_share: float = 0.04
## Effects nearer the camera than this are pushed out along the view ray (hits on the
## first-person player land at the lens).
@export_range(0.1, 1.5, 0.05) var vfx_min_camera_dist_m: float = 0.45
## A hit's burst, spark and word are pulled inside the view when its contact is just
## outside it: up to this many degrees beyond its side edges, and this many above or below
## it (a knee or a stomp lands under the first-person view). Farther out, or behind the
## camera, they stay at the contact.
@export_range(0.0, 90.0, 1.0) var vfx_clamp_reach_side_deg: float = 10.0
@export_range(0.0, 90.0, 1.0) var vfx_clamp_reach_low_deg: float = 40.0

@export_subgroup("Bursts")
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

@export_subgroup("Lettering")
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
## side (on screen), drifts up vfx_word_rise_m over its time and tilts between the two
## angles toward that side.
@export_range(0.0, 1.5, 0.05) var vfx_word_lift: float = 0.45
@export_range(0.0, 1.0, 0.05) var vfx_word_side: float = 0.3
@export_range(0.0, 0.5, 0.01) var vfx_word_rise_m: float = 0.06
@export_range(0.0, 30.0, 1.0) var vfx_word_tilt_min_deg: float = 3.0
@export_range(0.0, 30.0, 1.0) var vfx_word_tilt_deg: float = 10.0
## Words and effects kept in view stay at least this share of its width from the edges.
@export_range(0.0, 0.3, 0.01) var vfx_word_view_margin: float = 0.04

@export_subgroup("Speed lines and impact frame")
## Radial speed lines (a screen overlay) on finishers and on the player's lunges (first
## person), fading over these times.
@export_range(0.0, 1.5, 0.05) var vfx_speed_lines_s: float = 0.35
@export_range(0.0, 1.5, 0.05) var vfx_lunge_lines_s: float = 0.2
@export_range(0, 80, 1) var vfx_speed_lines_count: int = 34
## Thickness of the lines (1 = as drawn in speed_lines.png), and each line's random share
## of it.
@export_range(0.1, 3.0, 0.05) var vfx_speed_lines_width: float = 1.6
@export_range(0.1, 2.0, 0.05) var vfx_speed_lines_width_min: float = 0.55
@export_range(0.1, 2.0, 0.05) var vfx_speed_lines_width_max: float = 1.2
@export_range(0.0, 1.0, 0.05) var vfx_speed_lines_opacity: float = 0.85
@export_range(0.0, 1.0, 0.05) var vfx_lunge_lines_opacity: float = 0.45
## The lines stay outside this share of the screen's half-diagonal around their focus;
## each line's inner end lands between that and this many times it.
@export_range(0.0, 0.9, 0.05) var vfx_speed_lines_clear: float = 0.5
@export_range(1.0, 2.5, 0.05) var vfx_speed_lines_inner_max: float = 1.4
## How far each line's angle strays from even spacing (share of the spacing).
@export_range(0.0, 0.5, 0.05) var vfx_speed_lines_jitter: float = 0.35
## A finisher's lines converge between the view center (0) and the contact on screen (1),
## so a contact near an edge still leaves the middle of the view clear.
@export_range(0.0, 1.0, 0.05) var vfx_speed_lines_focus_follow: float = 0.35
## Real 60 Hz frames between redraws of the lines in new places (the comic flicker). With
## the photosensitivity toggle off (impact_frame_enabled) they are never redrawn.
@export_range(1, 10, 1) var vfx_speed_lines_redraw_frames: int = 2
## A player attack with its own lunge (the flying kick; not the magnetism step-in of jabs
## and chain hits) shows the lunge lines once it has carried the player this far (meters).
@export_range(0.1, 3.0, 0.05) var vfx_lunge_lines_min_m: float = 1.0
## The finisher impact frame (Spec §6: 1-2 frames), in 60 Hz frames; the luminance above
## which its inverted ink flash prints ink (the rest prints paper); how much each pixel's
## neighborhood moves that cut (keeps shapes from flooding into one tone), and the
## neighborhood's size (a mip level of the screen: each step doubles it).
@export_range(0, 6, 1) var vfx_impact_frame_frames: int = 2
@export_range(0.0, 1.0, 0.01) var vfx_impact_frame_threshold: float = 0.45
@export_range(0.0, 1.0, 0.05) var vfx_impact_frame_local_mix: float = 0.6
@export_range(0.0, 8.0, 0.5) var vfx_impact_frame_blur_mip: float = 5.0

@export_subgroup("Blood, spit and teeth")
## Blood (heavy and finisher hits): chance, droplets, and the splash at the contact.
@export_range(0.0, 1.0, 0.05) var vfx_blood_chance_heavy: float = 1.0
@export_range(0.0, 1.0, 0.05) var vfx_blood_chance_finisher: float = 1.0
@export_range(0, 40, 1) var vfx_blood_drops_heavy: int = 5
@export_range(0, 40, 1) var vfx_blood_drops_finisher: int = 12
@export_range(0.0, 0.3, 0.005) var vfx_blood_drop_m: float = 0.05
## Droplet launch speed (m/s), along the hit (spread either side by the angle) and up at
## an angle between the two launch angles.
@export_range(0.0, 10.0, 0.1) var vfx_blood_speed: float = 2.6
@export_range(0.0, 90.0, 1.0) var vfx_blood_spread_deg: float = 40.0
@export_range(0.0, 90.0, 1.0) var vfx_blood_launch_min_deg: float = 17.0
@export_range(0.0, 90.0, 1.0) var vfx_blood_launch_max_deg: float = 45.0
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

@export_subgroup("Block sparks")
## Blocked hits: the block spark, the parry spark (perfect block) and the guard-break burst.
@export_range(0.0, 2.0, 0.01) var vfx_block_spark_m: float = 0.2
@export_range(0.0, 2.0, 0.01) var vfx_parry_spark_m: float = 0.42
@export_range(0.0, 2.0, 0.01) var vfx_guard_break_m: float = 0.5
@export_range(0.03, 1.5, 0.01) var vfx_block_fx_s: float = 0.22

@export_subgroup("Damage looks")
## Damage looks (Spec §6): an enemy looks bruised at or below this share of its health,
## bloodied at or below the next; one damage-texture tile spans this many meters.
@export_range(0.0, 1.0, 0.01) var vfx_bruised_at: float = 0.66
@export_range(0.0, 1.0, 0.01) var vfx_bloodied_at: float = 0.33
@export_range(0.05, 2.0, 0.05) var vfx_damage_tile_m: float = 0.4

@export_group("Ragdoll")
## Victim reactions (Spec §6, the tier table's "Victim reaction" row; game/actors/ragdoll.gd):
## staggers blend a partial ragdoll of the upper body over the animation, and a body knocked
## off its feet (launch, knockdown, throw, KO) goes full ragdoll, then gets up from where it
## lies or goes limp. A visual layer: hits, hurtboxes and the sim body never read it, except
## where a body gets up. Spring strengths are natural frequencies (Hz) with damping ratios
## (1 = critical); speeds are sim m/s; times are sim seconds, so hitstop freezes and slow-mo
## stretches them.
@export_subgroup("Who")
## Enemies and training dummies ragdoll; off, every reaction stays animated.
@export var ragdoll_enabled: bool = true
## The player ragdolls too (Game-boy's call: off, so its own arms and legs never flop in the
## first-person view; the camera rides the animated eyes either way).
@export var ragdoll_player: bool = false
@export_subgroup("Stagger (partial)")
## How much of the simulated upper body shows over the animation (above Spec §6's 0.3-0.6,
## Game-boy's call: staggers that read from the side view too), how long it holds, then how
## long it fades back to the animation (both cut to the stagger's length).
@export_range(0.0, 1.0, 0.01) var ragdoll_partial_influence: float = 0.9
@export_range(0.0, 1.0, 0.01) var ragdoll_partial_hold_s: float = 0.25
@export_range(0.05, 1.5, 0.01) var ragdoll_partial_fade_s: float = 0.4
## A stagger on a body already staggering: the influence rises back from where its fade had
## got to over this long (no pop).
@export_range(0.0, 0.5, 0.01) var ragdoll_partial_rise_s: float = 0.08
## The hit's push (its knockback speed) times this is the kick given to the struck body
## part at the contact point (up to ragdoll_max_kick).
@export_range(0.0, 12.0, 0.1) var ragdoll_partial_impulse: float = 7.0
## How hard the staggering upper body (spine, neck, head) and its arms are pulled back
## toward the animation's joint angles, and the share of gravity on it (0: the stagger
## animation carries its weight, the ragdoll only gives way).
@export_range(0.0, 6.0, 0.05) var ragdoll_partial_pose_hz: float = 0.7
@export_range(0.0, 8.0, 0.05) var ragdoll_partial_limb_pose_hz: float = 3.0
@export_range(0.0, 1.0, 0.05) var ragdoll_partial_gravity: float = 0.0
## A perfect block knocks the attacker's striking arm back as a hit at this speed would
## (times ragdoll_partial_impulse, like every stagger's push).
@export_range(0.0, 5.0, 0.05) var ragdoll_parry_push: float = 0.8
## How much of the simulation the neck and head show on their joints, and the arms on
## theirs unless the kick landed on them (a guard break, a parry): the trunk gives way at
## ragdoll_partial_influence and they ride it, so the head does not loll onto a shoulder nor
## a far arm string out behind a trunk thrown sideways (M2 phase 3 review: the hook).
@export_range(0.0, 1.0, 0.01) var ragdoll_partial_head_influence: float = 0.45
@export_range(0.0, 1.0, 0.01) var ragdoll_partial_arm_influence: float = 0.45
## A stagger pushed sideways (the hook) also leans the trunk back, away from the attacker,
## as a push of this share of its sideways speed would: visual only (a kick on the trunk; the
## body slides as the move says), so the side view, looking along the sideways push, sees
## the body give way too.
@export_range(0.0, 2.0, 0.05) var ragdoll_stagger_back_share: float = 0.5
@export_subgroup("Knocked off the feet (full)")
## The kick at the contact point, times the hit's knockback speed (up to ragdoll_max_kick).
@export_range(0.0, 5.0, 0.05) var ragdoll_full_impulse: float = 0.5
## A body knocked off its feet shows the animation's snap first (from standing or from a
## stagger): the ragdoll's influence rises from 0 to full over this long, its pose springs
## this strong (Hz) at first, easing to the flight's.
@export_range(0.0, 0.6, 0.01) var ragdoll_full_rise_s: float = 0.15
@export_range(0.0, 10.0, 0.1) var ragdoll_full_rise_pose_hz: float = 6.0
## A launch the world stops right away (a wall, a crate or the curb within the distance it
## flies while the snap shows, plus this many meters: how far the arched-back pose reaches
## past the body's capsule) skips the animation's snap: the ragdoll takes over at once from
## the pose on screen, so no part of the body is drawn inside the wall. A launch from behind
## takes over at once too (the arch would swing the head back at the attacker).
@export_range(0.0, 1.5, 0.05) var ragdoll_wall_reach_m: float = 0.5
## No kick at a contact point changes its body part's speed by more than this (m/s).
@export_range(0.0, 30.0, 0.5) var ragdoll_max_kick: float = 14.0
## Share of the knocked body's new velocity every ragdoll body starts with (the rest comes
## from the hips spring).
@export_range(0.0, 1.0, 0.05) var ragdoll_inherit_velocity: float = 1.0
## How hard each bone is pulled toward the animation's joint angles while flying, while
## lying down (the torso, neck and head, then the arms, then the legs: a downed body lies
## where its hurtboxes are, the head, torso and legs; the arms, which have none, lie more
## as they fell) and when KO'd (0 = limp).
@export_range(0.0, 6.0, 0.05) var ragdoll_flight_pose_hz: float = 2.5
@export_range(0.0, 6.0, 0.05) var ragdoll_down_pose_hz: float = 3.0
@export_range(0.0, 6.0, 0.05) var ragdoll_down_arm_pose_hz: float = 2.0
@export_range(0.0, 6.0, 0.05) var ragdoll_down_leg_pose_hz: float = 3.0
@export_range(0.0, 6.0, 0.05) var ragdoll_ko_pose_hz: float = 0.0
## Damping ratio of those pose springs.
@export_range(0.0, 2.0, 0.05) var ragdoll_pose_damping: float = 0.8
## A stomp on a downed body jolts it this hard (m/s at the contact), down into the floor
## and tilted this much along the stomp (1 = as much along it as down).
@export_range(0.0, 10.0, 0.1) var ragdoll_ground_push: float = 2.5
@export_range(0.0, 1.0, 0.05) var ragdoll_ground_push_tilt: float = 0.25
@export_subgroup("Kick at the contact point")
## The hit's kick lands at its contact point (Spec §6): besides the central kick, its
## off-center part twists the struck body part and its parents as one piece from the joint
## it hangs on. Off, only the central kick (the body part pushed straight along the hit).
@export var ragdoll_kick_at_contact: bool = true
## The twist's lever: the contact's distance (m) from the struck body's center counts up to
## this much. Times this on the twist (above 1 exaggerates it).
@export_range(0.0, 0.4, 0.01) var ragdoll_contact_lever_m: float = 0.15
@export_range(0.0, 3.0, 0.05) var ragdoll_contact_twist: float = 1.0
## How many bodies turn as one piece: the struck one and its parents up the chain (1 = the
## struck body alone, about its own joint).
@export_range(1, 4, 1) var ragdoll_contact_chain: int = 2
## The twist turns its piece no faster than this (rad/s) on the head and neck, the trunk,
## and the arms and legs.
@export_range(0.0, 40.0, 0.5) var ragdoll_contact_spin_head: float = 14.0
@export_range(0.0, 40.0, 0.5) var ragdoll_contact_spin_trunk: float = 8.0
@export_range(0.0, 40.0, 0.5) var ragdoll_contact_spin_limb: float = 14.0
@export_subgroup("Hips spring")
## The whole ragdoll is held to the animation's hips (where the sim body is): position
## spring frequency and damping ratio, and the whole body's turn toward the animation's
## hips rotation while flying (it rolls over in the air as the animation does), lying (and
## a KO's, weaker).
@export_range(0.5, 6.0, 0.05) var ragdoll_hips_hz: float = 3.0
## While a flying body's capsule is stopped by the world (a wall or the curb), the pull
## toward the animation's hips is this strong instead (Hz): the body, which collides with the
## world, slides on from the capsule a little, away from the lens it pivoted at (3 = no
## difference: the legs swung at the lens of a player against a wall). Lower slides it
## further, deeper into the wall and (lying) further from its hurtboxes. Back to the full
## pull when it lands.
@export_range(0.0, 6.0, 0.05) var ragdoll_hips_blocked_hz: float = 1.5
@export_range(0.1, 2.0, 0.05) var ragdoll_hips_damping: float = 1.0
@export_range(0.0, 8.0, 0.05) var ragdoll_flight_turn_hz: float = 2.5
@export_range(0.0, 6.0, 0.05) var ragdoll_hips_turn_hz: float = 2.5
@export_range(0.0, 6.0, 0.05) var ragdoll_ko_hips_turn_hz: float = 0.6
@export_subgroup("Body")
## Gravity on the ragdoll, times Tuning.gravity (the sim's).
@export_range(0.0, 2.0, 0.05) var ragdoll_gravity_mult: float = 1.0
## Velocity lost per second (linear, angular).
@export_range(0.0, 5.0, 0.05) var ragdoll_linear_damp: float = 0.1
@export_range(0.0, 10.0, 0.1) var ragdoll_angular_damp: float = 1.0
@export_range(0.0, 1.0, 0.05) var ragdoll_friction: float = 0.8
@export_range(0.0, 1.0, 0.05) var ragdoll_bounce: float = 0.0
## Ragdoll bodies collide with other ragdolls (a flying body tumbles over the one it knocks
## down); off, they pass through each other.
@export var ragdoll_collide_ragdolls: bool = true
## Safety caps: no ragdoll body moves faster (m/s) or spins faster (rad/s) than this.
@export_range(5.0, 60.0, 1.0) var ragdoll_max_speed: float = 25.0
@export_range(5.0, 100.0, 1.0) var ragdoll_max_spin: float = 40.0
@export_subgroup("Rest and get-up")
## A lying ragdoll sleeps once every body has moved slower than this (m/s) for
## ragdoll_rest_s, and at the latest ragdoll_settle_max_s after it started lying (about as
## long as a knockdown lies, downed_frames: a body about to get up is not frozen mid-motion).
@export_range(0.0, 1.0, 0.01) var ragdoll_rest_speed: float = 0.25
@export_range(0.0, 2.0, 0.05) var ragdoll_rest_s: float = 0.3
@export_range(0.2, 5.0, 0.05) var ragdoll_settle_max_s: float = 1.25
## The get-up fades from the pose the ragdoll lies in over this long, and longer when the
## body has further to go to where it stands up (it slides there no faster than this, m/s;
## at most over the whole get-up).
@export_range(0.0, 0.5, 0.01) var ragdoll_getup_blend_s: float = 0.2
@export_range(0.5, 6.0, 0.1) var ragdoll_getup_slide_speed: float = 1.5
## A body that fell on another gets up beside it, this far (m) from where its hips lie.
@export_range(0.5, 2.0, 0.05) var ragdoll_getup_aside_m: float = 0.8
## A ragdoll cut short (a staggering body grabbed) fades back over this long.
@export_range(0.0, 0.5, 0.01) var ragdoll_stop_blend_s: float = 0.1
@export_subgroup("KO and blink-off")
## A KO'd enemy or dummy (never the player) lies limp this long, then blinks on and off for
## ko_blink_s, its rate (on-off cycles per second) rising from ko_blink_start_hz to
## ko_blink_end_hz, and is gone for good (Game-boy's departure from Spec §6's "bodies stay
## until the arena clears"; README). Sim seconds.
@export_range(0.0, 5.0, 0.05) var ko_linger_s: float = 1.5
@export_range(0.0, 3.0, 0.05) var ko_blink_s: float = 1.0
@export_range(0.5, 30.0, 0.5) var ko_blink_start_hz: float = 4.0
@export_range(0.5, 30.0, 0.5) var ko_blink_end_hz: float = 12.0
## A body that comes back (a training dummy, dummy_revive_s after it blinked off) blinks in
## over this long at this rate, out of reach until it is solid.
@export_range(0.0, 2.0, 0.05) var ko_blink_in_s: float = 0.5
@export_range(0.5, 30.0, 0.5) var ko_blink_in_hz: float = 8.0

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
@export_subgroup("Mix")
## Volume of every sound effect, in dB: the SFX bus limiter's pre-gain, so turning it down
## also leaves the limiter headroom (below 0 by default: finishers barely touch it).
@export_range(-40.0, 6.0, 0.5) var sfx_volume_db: float = -3.0
## Each one-shot's pitch varies at random by up to plus or minus this share (Spec §6: 8%).
@export_range(0.0, 0.3, 0.01) var sfx_pitch_variation: float = 0.08
## ...and its volume (as amplitude) by up to plus or minus this share (Spec §6: 8%).
@export_range(0.0, 0.3, 0.01) var sfx_volume_variation: float = 0.08
@export_subgroup("Tiers")
## Every one-shot of a hit (its layers, or a blocked hit's clack, ting or crash) is this many
## dB louder per tier, so the tiers rank in loudness as well as in layers.
@export_range(-20.0, 12.0, 0.5) var hit_light_db: float = 0.0
@export_range(-20.0, 12.0, 0.5) var hit_heavy_db: float = 3.0
@export_range(-20.0, 12.0, 0.5) var hit_finisher_db: float = 4.0
## One swing hitting several bodies in a frame (a spinning heel's arc): the whoosh and the sub
## thump play once, and every victim after the first is this many dB quieter.
@export_range(-24.0, 0.0, 0.5) var extra_victim_db: float = -8.0
@export_subgroup("Layers")
## Layer volumes in dB (every sample is normalized to the same peak). Light hits play whoosh
## + thud, heavy hits add the crack, finishers play whoosh + thud + crunch + body fall + sub
## thump (Spec §6).
@export_range(-40.0, 12.0, 0.5) var whoosh_db: float = -10.0
@export_range(-40.0, 12.0, 0.5) var thud_db: float = -8.0
@export_range(-40.0, 12.0, 0.5) var crack_db: float = -7.0
@export_range(-40.0, 12.0, 0.5) var crunch_db: float = -10.0
@export_range(-40.0, 12.0, 0.5) var body_fall_db: float = -12.0
@export_range(-40.0, 12.0, 0.5) var sub_thump_db: float = -10.0
## A missed swing's whoosh (attack_whiffed): no impact and no hitstop.
@export_range(-40.0, 12.0, 0.5) var whiff_db: float = -6.0
@export_subgroup("Voices")
## An enemy hit cleanly grunts; the player grunts too, at the listener.
@export_range(-40.0, 12.0, 0.5) var grunt_db: float = -9.0
@export_range(-40.0, 12.0, 0.5) var player_grunt_db: float = -13.0
## An actor grunts at most once per this many ms (a body-blow flurry lands every few frames).
@export_range(0.0, 1000.0, 10.0) var grunt_min_interval_ms: float = 300.0
## Each actor's voice is pitched up or down by up to this share, the same every time.
@export_range(0.0, 0.3, 0.01) var voice_pitch_spread: float = 0.1
## An enemy's wind-up: an effort grunt and a whoosh at the attacker (Spec §8's audio cue,
## on while rear_warning_audio).
@export_range(-40.0, 12.0, 0.5) var windup_db: float = -10.0
@export_subgroup("Blocks")
@export_range(-40.0, 12.0, 0.5) var block_clack_db: float = -2.5
@export_range(-40.0, 12.0, 0.5) var parry_ting_db: float = -6.0
@export_range(-40.0, 12.0, 0.5) var guard_break_db: float = -1.0
@export_subgroup("Distance")
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
## Hits on the player sound this far (m) from its eyes toward the attacker: their contact
## point sits around the listener itself, too close to tell a direction.
@export_range(0.1, 2.0, 0.05) var self_hit_offset_m: float = 0.5
@export_subgroup("Music")
## Placeholder fight loop (Spec §13 leaves music open: off by default).
@export var music_enabled: bool = false
@export_range(-40.0, 6.0, 0.5) var music_volume_db: float = -14.0
@export_subgroup("Rumble")
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
