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
## A weapon lying on the floor (dropped, or thrown and landed) comes to rest: from its first touch of
## the world its linear and angular damping (per second, replacing the engine's 0.1) are these, which
## take the slide and the roll out of it within a second or two so it lies where it fell and Jolt then
## lets it sleep. Without them a capsule rolls on for many seconds (a dropped pipe left pickup_range
## 2.8 s after it landed) since nothing resists a roll.
@export_range(0.0, 30.0, 0.5) var weapon_rest_linear_damp: float = 6.0
@export_range(0.0, 30.0, 0.5) var weapon_rest_angular_damp: float = 8.0
@export_range(0.5, 3.0, 0.1) var stomp_range: float = 1.5
## Leaving a grab, the body unbends over this long (sim seconds) around its bent-over hips,
## so its head rises while it moves away instead of up through the holder's view: released
## on its feet, or launched out of the hold (a throw, or a knee that KOs it).
@export_range(0.0, 0.6, 0.01) var grab_release_blend_s: float = 0.22
## Grabbed, the body bends over into the held pose over this blend (sim seconds) while its
## origin eases in from where it stood to the holder's hold point over grab_pin_ease_s,
## slowly at first: the head drops below the holder's first-person lens (at the throat)
## before the body closes in, instead of sweeping through it. A staggering body leaves its
## partial ragdoll over at least the blend.
@export_range(0.0, 0.5, 0.01) var grab_hold_blend_s: float = 0.12
@export_range(0.0, 1.0, 0.01) var grab_pin_ease_s: float = 0.23
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
@export_subgroup("Pick-up cue")
## The HUD's "LB" cue (a small panel low in the view) shows while LB would pick a weapon up: one
## lies within pickup_range, the player stands free with nothing in his hands, and no enemy is
## within his grab's reach (LB grabs it first). The Pipe Thug's dropped pipe lies below the
## forward lens, so a player who does not look down never sees it. Presentation only.
@export var pickup_cue_enabled: bool = true
## Size multiplier and opacity (0..1) of the cue.
@export_range(0.5, 2.0, 0.05) var pickup_cue_size: float = 1.0
@export_range(0.0, 1.0, 0.05) var pickup_cue_opacity: float = 0.95
## Seconds one breath of the cue takes (it swells and settles so the eye catches it; 0 = steady).
@export_range(0.0, 3.0, 0.05) var pickup_cue_pulse_s: float = 0.9

@export_group("Reactions")
@export_range(10, 90, 1) var stagger_frames: int = 40
@export_range(30, 150, 1) var downed_frames: int = 75
@export_range(10, 60, 1) var getup_frames: int = 30
@export_range(0, 60, 1) var getup_invuln_frames: int = 30
## A hit's pose snaps in over this long (sim seconds): a launch's, a knee's jolt on a held
## body, a flinch's and a guard break's. A stagger's snaps in over stagger_snap_blend_s.
@export_range(0.0, 0.2, 0.005) var reaction_snap_blend_s: float = 0.03
@export_range(0.0, 0.2, 0.005) var stagger_snap_blend_s: float = 0.04
## Deceleration of knockback slides on the ground (m/s^2).
@export_range(0.0, 60.0, 0.5) var ground_friction: float = 14.0
## A flying body must move at least this fast (m/s) to knock down whoever it hits.
@export_range(0.5, 15.0, 0.5) var body_impact_min_speed: float = 3.0
@export_range(5.0, 500.0, 1.0) var dummy_health: float = 30.0
## A training dummy that blinked off after a KO (Ragdoll > "KO and blink-off") is gone this
## long, then blinks back in standing at its post at full health: about 4 s from the KO to
## back with the KO defaults.
@export_range(0.0, 10.0, 0.1) var dummy_revive_s: float = 1.0
## When someone stands on a dummy's post as it comes back, it blinks in beside the post, one
## body width plus this much clearance (m) from it (two of each when that spot is taken), so
## it never arrives touching the body on the post.
@export_range(0.0, 0.5, 0.01) var dummy_respawn_gap_m: float = 0.1
## Of the equally far spots around the post (a player standing on it sees them all at the
## same distance) the comeback takes the one whose angle off his facing is nearest to this
## many degrees: off-centre but in view, not dead ahead filling more than half of it (the
## eight spots are 45 degrees apart, so 50 takes one of the two 45 degrees off his facing;
## 0 takes the one straight ahead, 90 one beside him).
@export_range(0.0, 90.0, 1.0) var dummy_respawn_off_axis_deg: float = 50.0
## A training dummy left alone (standing, nobody to spar with) this long (s) walks back to
## its post, turning toward it at dummy_return_turn_rate (rad/s), until it is within
## dummy_return_slack_m of it. It stays put while someone is on the post, and while a
## standing body (the player, another dummy) is within dummy_return_look_ahead_m (m) ahead of
## it on the way, standing facing the player until he steps aside instead of walking into
## him. It gives up a walk that gets no nearer for dummy_return_stuck_s (a crate or wall in
## the way) and tries no more until it is hit or moved dummy_return_retry_moved_m (m) from
## where it gave up.
@export_range(0.0, 10.0, 0.1) var dummy_return_idle_s: float = 1.0
@export_range(0.0, 2.0, 0.05) var dummy_return_slack_m: float = 0.3
@export_range(0.5, 20.0, 0.5) var dummy_return_turn_rate: float = 6.0
@export_range(0.1, 3.0, 0.05) var dummy_return_stuck_s: float = 0.25
@export_range(0.0, 2.0, 0.05) var dummy_return_look_ahead_m: float = 0.5
@export_range(0.0, 2.0, 0.05) var dummy_return_retry_moved_m: float = 0.3
## How fast (rad/s) a dummy turns to face the player, standing or sparring.
@export_range(0.5, 20.0, 0.5) var dummy_face_turn_rate: float = 4.0

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

@export_subgroup("Hurt")
## What the player feels when he is the one hit (M6 playtest, Game-boy's ruling: a Punk's jab went by
## unnoticed). SPEC §6's table (shake_* and cam_punch_*) still holds for the hits he lands and for
## the ones his guard stops; these scale and add to it for a clean hit he takes. Every part goes off
## together with Debug's hurt_feel_enabled.
## Trauma of a hit taken = the tier's shake_* times this, and never less than hurt_shake_min.
@export_range(0.0, 10.0, 0.1) var hurt_shake_mult: float = 2.5
## The least trauma any clean hit taken adds (a light jab: 0.1 x 2.5 would be a quarter).
@export_range(0.0, 1.0, 0.01) var hurt_shake_min: float = 0.3
## The camera punch (the kick the way the blow pushes) of a hit taken = the tier's cam_punch_*_deg times this.
@export_range(0.0, 10.0, 0.1) var hurt_punch_mult: float = 2.5
## The head's roll, away from the side the blow came from, per tier, in degrees (it uses the punch's
## snap-and-settle). A blow from straight ahead or behind rolls the head to alternating sides.
@export_range(0.0, 20.0, 0.5) var hurt_roll_light_deg: float = 2.0
@export_range(0.0, 20.0, 0.5) var hurt_roll_heavy_deg: float = 4.0
@export_range(0.0, 20.0, 0.5) var hurt_roll_finisher_deg: float = 7.0
## How much of the roll a blow from dead ahead or behind still gets (1 = as much as one from the side).
@export_range(0.0, 1.0, 0.05) var hurt_roll_frontal_share: float = 0.5
## The edge vignette (game/ui/hurt_overlay.gd, drawn under the HUD's panels). Its colour is the ink,
## not red: SPEC §10 keeps red for blood, the rear warning and the finisher accents. Alpha is the
## strongest it gets (a finisher, or a hit of hurt_overlay_full_damage).
@export var hurt_overlay_color: Color = Color(0.05, 0.04, 0.07, 0.8)
## The comic impact strokes along the struck edge (spikes pointing in), and their colour.
@export var hurt_overlay_stroke_color: Color = Color(0.97, 0.94, 0.85, 0.9)
## How many impact strokes a hit draws on its edge (0 = a plain vignette).
@export_range(0, 16, 1) var hurt_overlay_strokes: int = 7
## Seconds the vignette and the strokes take to fade out.
@export_range(0.1, 1.5, 0.05) var hurt_overlay_fade_s: float = 0.45
## How deep the vignette reaches in from the edge, as a share of the screen's height: at a hit of
## no damage, and at hurt_overlay_full_damage or more.
@export_range(0.0, 0.6, 0.01) var hurt_overlay_depth_min: float = 0.12
@export_range(0.0, 0.6, 0.01) var hurt_overlay_depth_max: float = 0.32
## The damage at which the vignette is at its deepest and strongest; below it, in proportion.
@export_range(1.0, 100.0, 1.0) var hurt_overlay_full_damage: float = 20.0
## The weakest a hit's vignette is, as a share of the strongest (so a 3-damage jab still shows).
@export_range(0.0, 1.0, 0.05) var hurt_overlay_min_strength: float = 0.5
## The share of a hit's vignette every edge gets whichever way it came; the rest is on the side
## it came from (left, right, or the bottom edge for a blow from behind).
@export_range(0.0, 1.0, 0.05) var hurt_overlay_even_share: float = 0.3
## A blocked hit's vignette, as a share of a clean hit's (0 = none), and no strokes.
@export_range(0.0, 1.0, 0.05) var hurt_overlay_blocked_scale: float = 0.2
## The health panel's jolt on damage: its offset in canvas pixels per point of damage taken (capped
## at hurt_panel_jolt_max_px), and the seconds it takes to settle.
@export_range(0.0, 20.0, 0.1) var hurt_panel_jolt_px_per_hp: float = 1.2
@export_range(0.0, 60.0, 1.0) var hurt_panel_jolt_max_px: float = 22.0
@export_range(0.05, 1.0, 0.05) var hurt_panel_jolt_s: float = 0.25
## The rattle's two rates, in radians per second (x and y; unequal so the offset traces a loop, not a line).
@export_range(10.0, 300.0, 1.0) var hurt_panel_jolt_rate_x: float = 95.0
@export_range(10.0, 300.0, 1.0) var hurt_panel_jolt_rate_y: float = 113.0
## Which way a hit came from is the attacker's position against the view (the contact point is on the
## player's own hurtbox, a few tenths of a metre from the lens). An attacker nearer the lens than this
## horizontally (metres) has no side: the push direction stands in.
@export_range(0.0, 1.0, 0.01) var hurt_bearing_min_m: float = 0.05
## A blow whose bearing has a sine smaller than this (nearly dead ahead or behind) counts as frontal: the
## roll alternates sides instead of keeping one.
@export_range(0.0, 0.5, 0.01) var hurt_roll_frontal_sine: float = 0.1
## The vignette's gradient: the band's mid-stop sits at this share of the depth, at this share of the
## edge's alpha (it then falls to nothing at the depth).
@export_range(0.05, 0.95, 0.05) var hurt_overlay_mid_stop: float = 0.4
@export_range(0.0, 1.0, 0.05) var hurt_overlay_mid_alpha: float = 0.4
## One impact stroke's length: this share of the vignette's depth at least, plus up to this much more
## (random per stroke), then scaled by the strength (see hurt_overlay_stroke_len_floor).
@export_range(0.1, 2.0, 0.05) var hurt_overlay_stroke_len_min: float = 0.55
@export_range(0.0, 2.0, 0.05) var hurt_overlay_stroke_len_range: float = 0.7
## The length scale of a stroke is the hit's strength plus this, up to 1 (so a weak hit's strokes are
## not stubs).
@export_range(0.0, 1.0, 0.05) var hurt_overlay_stroke_len_floor: float = 0.3
## The strokes' width across the edge, as a share of the edge's length shared by all of them (0.4 = the
## strokes' bases cover 40% of it).
@export_range(0.05, 1.0, 0.05) var hurt_overlay_stroke_width: float = 0.4
## How far a stroke's tip leans off the straight-in line, as a share of its half-width, either way.
@export_range(0.0, 3.0, 0.05) var hurt_overlay_stroke_lean: float = 0.6
## How far a stroke's place along the edge is jittered, as a share of the spacing, either way.
@export_range(0.0, 0.5, 0.05) var hurt_overlay_stroke_jitter: float = 0.3
## The strokes' opacity is the hit's strength times this (up to 1): the strokes reach full opacity before the vignette does.
@export_range(1.0, 4.0, 0.1) var hurt_overlay_stroke_gain: float = 1.5
## A blow from ahead lights the top edge's strokes only when its cosine against the view is over this
## (0 = any blow in the front half; the top edge's strength then rises to full at dead ahead).
@export_range(0.0, 0.95, 0.05) var hurt_overlay_top_threshold: float = 0.5
## A blocked hit's vignette is shallower than a clean hit's: its depth is the clean depth times
## hurt_overlay_blocked_scale times this, at most the clean depth (a block's edge stays thin).
@export_range(1.0, 10.0, 0.5) var hurt_overlay_blocked_depth_gain: float = 2.0
## Every impact stroke has an ink rim, so it reads on any ground (the pale street, a bright sky): its
## width, as a share of the screen's height, and its colour.
@export_range(0.0, 0.03, 0.001) var hurt_overlay_outline_width: float = 0.007
@export var hurt_overlay_outline_color: Color = Color(0.05, 0.04, 0.07, 0.95)
## A clean hit's bottom edge (a blow from behind, which the player cannot see coming) is inked this much
## stronger than the same blow on another edge (1 = the same; the alpha stays at most 1), and its strokes
## are this much longer (so they rise above the health panel at the screen's bottom left).
@export_range(1.0, 2.0, 0.05) var hurt_overlay_bottom_ink_gain: float = 1.5
@export_range(1.0, 2.5, 0.05) var hurt_overlay_bottom_stroke_gain: float = 1.4

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
## Each burst tier has two drawn variants and shows them in turn (never the same twice running); off,
## every burst is the first one.
@export var vfx_burst_variants: bool = true
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
## Word widths: small (light), medium (heavy), large (finisher). Every lettering PNG is drawn the same
## number of cap heights wide, so a width sets the letters' height, the same for every word.
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
## A splat is drawn flat and unshaded, at this share of its colors' brightness (1: as drawn).
@export_range(0.4, 1.0, 0.01) var vfx_splat_shade: float = 0.85
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
## The blood's hard edge (M6 D6): the bloodied look's alpha is cut at this value with an edge one
## pixel wide, so a blob is red and ink and nothing between (a soft alpha over the yellow cap read
## orange). 0 keeps M4's soft blend. Off with `look_marks_per_swatch`.
@export_range(0.0, 0.95, 0.05) var vfx_blood_edge_cut: float = 0.5

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
## The share of each blink cycle (KO blink-off and blink-in) the body is shown for; the rest
## of the cycle it is off. 0.5 is even on and off.
@export_range(0.05, 0.95, 0.05) var ko_blink_duty: float = 0.5

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
## The lowest the first-person lens may sit above the floor under the player (meters): the near
## plane (0.05 m) plus a margin for the shake. The lens rides EyePoint less cam_height_offset_m,
## and a player lying face-down (struck from the side or behind) has EyePoint only 0.15 m up, so
## the lowered lens ended up 4 cm inside the street, whose top face is drawn from above only:
## the floor vanished for the whole 1.1 s the body lay there. The lens stops at this height
## instead (a face-up fall, EyePoint 0.3 m up, moves it about 1.4 cm). It is a floor on the lens
## and never touches the KO view. Presentation only.
@export_range(0.0, 0.5, 0.01) var cam_floor_clearance_m: float = 0.13
@export_range(0.0, 1.0, 0.05) var screen_shake_intensity: float = 1.0
## Scales every move's camera_spin_follow: 1 turns the first-person view with a spinning
## move's body (the spin kick, spinning heel kick and spinning backfist land back on the
## heading), 0 keeps the view on the look. Presentation only.
@export_range(0.0, 1.0, 0.05) var cam_spin_follow_mult: float = 1.0
@export var show_center_dot: bool = true
@export_subgroup("KO view")
## The player's KO (Game-boy, 2026-10-25): from the killing blow the first-person camera
## leaves the eyes for an "out of body" view of the player lying on the floor, held while
## KO'd, and eases back into the eyes through the get-up. The only time the camera leaves
## the player's eyes. Presentation only. The lens sits beside the lying body (across its
## length, on whichever side has room), this far from the body's middle along the floor,
## this high above the floor, looking at the body across the floor and down by
## ko_view_pitch_deg: with the defaults the whole body fills about half the view. With no
## room on either side (a corner, a fighter each side) it sits along the body instead, past
## its feet, at the same distance and height; and with no room there either,
## straight over the body's middle ko_view_steep_height_m up (high enough for the whole
## body, arms out, to fit the view), looking down by ko_view_steep_pitch_deg.
@export_range(0.5, 6.0, 0.05) var ko_view_distance_m: float = 1.7
@export_range(0.3, 5.0, 0.05) var ko_view_height_m: float = 1.6
@export_range(0.0, 89.0, 1.0) var ko_view_pitch_deg: float = 40.0
## Seconds the lens takes to ease out of the eyes from the killing blow, and to ease back in
## from the get-up (the test room's get-up takes getup_frames, half a second).
@export_range(0.0, 3.0, 0.05) var ko_view_out_s: float = 0.8
@export_range(0.0, 3.0, 0.05) var ko_view_in_s: float = 0.5
## On the way back the look returns to the eyes' direction ahead of the lens: its share of the
## way is the lens's share to this power. 1 turns it with the lens (the head, neck and chest
## pass through the view as the lens comes in, 25 to 50% of it for a moment, and hide with a
## pop); 2 has the body out of the view by the time the lens is near it.
@export_range(1.0, 4.0, 0.1) var ko_view_look_lead: float = 1.5
## The lens keeps this far (meters) from a wall, crate or standing fighter between it and the
## body, and the head, neck, chest and shoulders (hidden from the first-person lens, which
## sits in them) show once the lens is this far from all of them: lifted sooner, a cap's brim
## covered a third of the view for a frame at the killing blow. A wall, crate or fighter in
## the way brings the lens in toward the body, never into it: a pose with less than
## ko_view_min_reach of ko_view_distance_m and ko_view_height_m (an arm or a foot would
## leave the view, from 0.7 down) is passed over for the next one (across, along, over the
## hips).
@export_range(0.05, 1.0, 0.05) var ko_view_clearance_m: float = 0.25
@export_range(0.1, 1.0, 0.05) var ko_view_min_reach: float = 0.8
@export_range(45.0, 89.0, 1.0) var ko_view_steep_pitch_deg: float = 85.0
@export_range(0.5, 6.0, 0.05) var ko_view_steep_height_m: float = 2.6

@export_group("Enemies")
## Most enemies that may attack at once, a held grab included (Spec §7); 0 = unlimited. The
## enemy director hands out the attack tokens.
@export_range(0, 6, 1) var attacker_cap: int = 3
## Chance (0..1) that a waiting enemy outside the player's view, in the blind spot, jumps the
## token queue: 1 always goes first, 0 ignores the blind spot.
@export_range(0.0, 1.0, 0.05) var blind_spot_priority: float = 1.0
## Multiplies the length of every enemy wind-up (the telegraph before a strike), but never
## below the wind-up floors (Wind-up). The F4 slow-mo cheat and Tuning edits apply live.
@export_range(0.25, 3.0, 0.05) var windup_mult: float = 1.0

@export_subgroup("Wind-up")
## Fewest frames any grunt wind-up lasts, however small windup_mult is (Spec §7: 18 at 60 Hz).
@export_range(1, 120, 1) var windup_min_frames_grunt: int = 18
## Fewest frames a heavy's (Bruiser, boss) wind-up lasts (Spec §7: 30 at 60 Hz).
@export_range(1, 120, 1) var windup_min_frames_heavy: int = 30
## How fast (degrees per second) a wind-up turns the enemy toward the player while it tracks.
@export_range(0.0, 720.0, 5.0) var windup_track_deg_per_s: float = 180.0
## Share (0..1) of a wind-up, from its start, in which the enemy still turns toward the player;
## after it the facing is locked, so a late sidestep or dodge makes the strike miss.
@export_range(0.0, 1.0, 0.05) var windup_track_share: float = 0.5

@export_subgroup("Posture")
## Nearest and furthest (m) an enemy waiting for its turn keeps from the player: the posture
## ring (Spec §7: 2.5-4 m).
@export_range(1.0, 8.0, 0.1) var posture_ring_min_m: float = 2.5
@export_range(1.0, 10.0, 0.1) var posture_ring_max_m: float = 4.0
## Speed (m/s) of circling along the ring, how long (s) before it switches direction (plus or
## minus a random share of posture_strafe_jitter_s), and the pause (s) between turns of the strafe.
@export_range(0.0, 6.0, 0.05) var posture_circle_speed_mps: float = 1.1
@export_range(0.2, 10.0, 0.1) var posture_strafe_switch_s: float = 1.6
@export_range(0.0, 5.0, 0.05) var posture_strafe_jitter_s: float = 0.6
@export_range(0.0, 5.0, 0.05) var posture_pause_s: float = 0.5
## Chance (0..1) each pause that the enemy taunts (an open-handed gesture, never a wind-up).
@export_range(0.0, 1.0, 0.01) var posture_taunt_chance: float = 0.12
## Speeds (m/s) walking to its slot on the ring and stepping in to strike range with a token.
@export_range(0.5, 10.0, 0.1) var approach_speed_mps: float = 2.6
@export_range(0.5, 10.0, 0.1) var engage_speed_mps: float = 3.0
## With a token the enemy squares up this many frames (a visible "I'm next"), then steps in
## to its attack's reach minus engage_margin_m, and gives the token back after engage_timeout_s
## without getting there.
@export_range(0, 60, 1) var commit_pause_frames: int = 12
## (0.05, not 0.1: measured over six-Punk fights, an attacker standing 5 cm further out covers half
## the player's view a third as often, and still lands 95% of its openers on a standing player.)
@export_range(0.0, 1.0, 0.01) var engage_margin_m: float = 0.05
@export_range(0.5, 10.0, 0.1) var engage_timeout_s: float = 2.0
## A holder steps in only when the director's go is near (EnemyDirector.windup_eta_s()): until
## then it stands squared up where it is (the ring), so it never waits at the player's nose for
## the wind-up gap, a flinch or the hit grace. It starts walking when the go is due within the
## time its step-in takes plus this many seconds, so it arrives that much early at most (0 = it
## arrives just as the go comes, and a hair late when the walk is slowed).
@export_range(0.0, 1.0, 0.01) var engage_go_lead_s: float = 0.1
## A step-in aims this far (m) to one side of the player's origin (a side picked once per enemy),
## not at it: the avoidance treats the player as a circle, and a body walking straight at its
## centre is slowed to a crawl before it gets there (the head-on tie), then times out of ENGAGE;
## a hair to one side the avoidance lets it slide in at full speed.
@export_range(0.0, 0.5, 0.01) var engage_aim_offset_m: float = 0.1
## Seconds an enemy holds still after its attack before it backs off to its slot.
@export_range(0.0, 3.0, 0.05) var recover_hold_s: float = 0.35
## How fast (rad/s) an enemy turns to face the player while posturing and engaging.
@export_range(0.5, 20.0, 0.5) var enemy_turn_rate: float = 6.0
## How far (m) a posturing enemy may stray from its slot while strafing before it turns back.
@export_range(0.0, 6.0, 0.1) var posture_wander_m: float = 1.5
## The way round the ring (every archetype, APPROACH and RECOVER): an enemy inside the ring's near
## edge backs out, and one whose slot is more than posture_orbit_gap_deg round the ring from it
## (with the straight line cutting the near edge) walks round the ring in legs of
## posture_orbit_lead_deg, always facing the player, instead of crossing his front on the chord.
@export_range(10.0, 90.0, 5.0) var posture_orbit_lead_deg: float = 40.0
@export_range(10.0, 180.0, 5.0) var posture_orbit_gap_deg: float = 60.0
## An enemy that wakes in place (the boss: free again after a reaction within the ring's far edge) takes
## up POSTURE where it stands, eligible for a token and served first, and the slot it left does not call
## it back for this long (s).
@export_range(0.0, 10.0, 0.1) var posture_resume_s: float = 3.0

@export_subgroup("Navigation")
## NavigationAgent3D avoidance: the enemy's radius (m), how far ahead (s) it avoids and how far
## (m) it sees neighbours.
@export_range(0.1, 1.5, 0.05) var enemy_avoid_radius_m: float = 0.45
@export_range(0.1, 3.0, 0.05) var enemy_avoid_horizon_s: float = 0.75
@export_range(1.0, 15.0, 0.5) var enemy_avoid_neighbor_m: float = 6.0
## Distances (m) at which a path waypoint and the posture slot count as reached.
@export_range(0.1, 2.0, 0.05) var enemy_waypoint_reach_m: float = 0.5
@export_range(0.05, 2.0, 0.05) var enemy_slot_reach_m: float = 0.3
## Sim frames between path re-queries (staggered per enemy), and the top speed (m/s) the agent
## may be asked for.
@export_range(1, 60, 1) var enemy_retarget_ticks: int = 6
@export_range(1.0, 15.0, 0.5) var enemy_max_speed_mps: float = 6.0
## An enemy that makes no progress toward its slot this long (s) asks for another one.
@export_range(0.2, 10.0, 0.1) var enemy_stuck_s: float = 1.0
## A stalled enemy tries a spot this many degrees around the player from where it stands, for
## this many seconds, then its slot again.
@export_range(10.0, 180.0, 5.0) var enemy_detour_deg: float = 90.0
@export_range(0.2, 10.0, 0.1) var enemy_detour_s: float = 2.0

@export_subgroup("Director")
## Least gap (s) between two wind-up starts of different enemies: the director holds an
## enemy with a token back until it has passed, so no two telegraphs start together and the
## player is never flinch-locked by a volley.
@export_range(0.0, 3.0, 0.05) var director_min_windup_gap_s: float = 0.35
## The posture slots are reassigned every director_reslot_s, or when the player moved more
## than director_reslot_move_m (m) since the last assignment.
@export_range(0.2, 10.0, 0.1) var director_reslot_s: float = 1.5
@export_range(0.1, 5.0, 0.1) var director_reslot_move_m: float = 1.0
## Random spread (degrees) added to each enemy's even share of the 360 degrees around the player.
@export_range(0.0, 45.0, 1.0) var director_spread_jitter_deg: float = 12.0
## A slot snapped onto the navmesh further than this (m) from where it was meant is rejected,
## and the next angle step (degrees, both ways) is tried.
@export_range(0.05, 3.0, 0.05) var director_slot_snap_tolerance_m: float = 0.5
@export_range(1.0, 90.0, 1.0) var director_slot_retry_deg: float = 15.0
## No token is granted for this long (s) after the player revives.
@export_range(0.0, 10.0, 0.1) var director_revive_grace_s: float = 1.5
## A token held longer than this (s) is taken back.
@export_range(0.5, 20.0, 0.5) var director_token_timeout_s: float = 4.0
## No wind-up starts for this long (s) after a hit lands on the player (a blocked one does not
## count), and none while he is in hitstun or staggering. director_min_windup_gap_s spaces the
## starts, but a flinch lasts about as long as that gap, so a stack of hits could flinch-lock him;
## this leaves him time to act between two bursts (a hit already winding up still lands).
@export_range(0.0, 3.0, 0.05) var director_hit_grace_s: float = 0.5
## An enemy with no seat yet (a spawn, a call-in) weighs this much (0..1) against one that has a
## seat when the ring is turned to fit the enemies, so a newcomer never turns the ring or swaps the
## seat of one already on it.
@export_range(0.0, 1.0, 0.05) var director_newcomer_weight: float = 0.1
## A Kicker takes a seat of its own as near directly behind the look as it can, kept at least this
## many degrees from every other seat (the others never move for it).
@export_range(0.0, 90.0, 5.0) var director_flank_gap_deg: float = 20.0

@export_subgroup("Attack arcs")
## Each archetype attacks from an arc of the circle round the player (Milestone 5; Game-boy's
## attack arcs, replacing M3's even spread): the sector, in degrees, centred on its line (the
## player's look when it engages, held after engage_commit_s). The trickier the enemy, the wider
## the arc; 360 attacks from anywhere (the Kicker also circles to the blind side). An archetype
## with no tunable of its own (the training dummy, a test stub) has 360. A variant resource
## (game/enemies/variants/) can override an archetype's arc.
@export_range(10.0, 360.0, 5.0) var punk_arc_deg: float = 90.0
@export_range(10.0, 360.0, 5.0) var thug_arc_deg: float = 140.0
@export_range(10.0, 360.0, 5.0) var bruiser_arc_deg: float = 180.0
@export_range(10.0, 360.0, 5.0) var boss_arc_deg: float = 270.0
@export_range(10.0, 360.0, 5.0) var kicker_arc_deg: float = 360.0
## An enemy's line follows the player's look for this long (s) after it engages (it reaches its
## seat, or comes within arc_engage_radius_m), then holds until its next engagement: a quick turn
## cannot stun-lock a Punk into walking round forever, and turning your back after the grace lets
## it hit you from behind.
@export_range(0.0, 3.0, 0.05) var engage_commit_s: float = 0.5
## An approaching enemy engages (fixes its line) when it comes this near (m) to the player. At
## least wait_ring_max_m + arc_engage_wait_margin_m, so no wait seat lies outside it.
@export_range(2.0, 20.0, 0.5) var arc_engage_radius_m: float = 7.0
## How far past wait_ring_max_m the engage radius always reaches (m).
@export_range(0.0, 3.0, 0.1) var arc_engage_wait_margin_m: float = 0.5
## A wait seat may sit as near as posture_ring_max_m plus this (m) when the wait ring is full.
@export_range(0.0, 4.0, 0.1) var wait_seat_floor_gap_m: float = 1.0
## A token goes only to an enemy within posture_ring_max_m plus this (m) of the player: one promoted
## from a wait seat walks to its inner seat first, so it has the chase time to land its attack
## (granted from the wait ring it ran out of engage_timeout_s short and sat out a cooldown).
@export_range(0.0, 3.0, 0.1) var token_grant_margin_m: float = 0.5
## Inner seats inside an arc are at least this many degrees apart: a 90 degree arc seats three.
@export_range(10.0, 120.0, 5.0) var director_seat_gap_deg: float = 40.0
## The wait ring: with no free inner seat in its arc an enemy stands back here (m from the
## player), inside its arc, until one frees.
@export_range(3.0, 12.0, 0.1) var wait_ring_min_m: float = 5.5
@export_range(3.0, 14.0, 0.1) var wait_ring_max_m: float = 6.5
## A seat whose floor is more than this (m) above or below the player's is rejected (a catwalk's
## lip must not seat an enemy on the street below).
@export_range(0.1, 3.0, 0.05) var director_slot_max_rise_m: float = 0.5
## The blind-spot priority (blind_spot_priority) is for enemies whose arc reaches the blind
## spot (half the arc past rear_warning_angle_deg): not a 90 degree Punk. Off: any enemy, as SPEC §7
## words it.
@export var blind_spot_needs_wide_arc: bool = true

@export_subgroup("Waves")
## Waves spawn on their own in the crowd street (off: only F4 spawns).
@export var waves_enabled: bool = true
## Most AI enemies alive at once for a wave to add another (F4 spawns can exceed it).
@export_range(1, 12, 1) var wave_max_alive: int = 6
## Seconds after a wave is cleared before the next starts, and between spawns inside a wave.
@export_range(0.0, 30.0, 0.5) var wave_gap_s: float = 3.0
@export_range(0.05, 5.0, 0.05) var wave_spawn_interval_s: float = 0.6
## Share (0..1) of each wave that spawns behind the player, outside his view.
@export_range(0.0, 1.0, 0.05) var wave_behind_share: float = 0.35
## A boss comes with every this-many-th wave.
@export_range(1, 20, 1) var boss_wave_every: int = 4
## No spawn point nearer than this (m) to the player is used.
@export_range(0.0, 12.0, 0.5) var spawn_min_player_distance_m: float = 4.0
## Radius (m) of the player's avoidance obstacle: enemies steer around him. Avoidance keeps an
## enemy this far plus enemy_avoid_radius_m from the player's origin, so the sum must stay below
## the shortest strike an enemy closes to (reach_m minus engage_margin_m, a Punk's shove 0.87 m):
## above it the enemy stalls just short of its range, times out of ENGAGE and never attacks.
## 0.3 keeps them 0.75 m off, about where the bodies touch (0.7 m).
@export_range(0.1, 1.5, 0.05) var player_avoid_radius_m: float = 0.3

@export_subgroup("Street Punk")
@export_range(5.0, 500.0, 1.0) var punk_health: float = 30.0
## Chance (0..1) that its attack is the shove rather than the two-hit punch.
@export_range(0.0, 1.0, 0.05) var punk_shove_chance: float = 0.3
## Seconds after its attack ends (or after a hit or a block ended the attempt) before it wants
## another token. It runs during the recover hold and the walk back to the ring, so below about
## 4 s it is spent before the Punk is back in POSTURE and never binds (the cadence is then the
## director's gap, hit grace and cap, and a Punk is almost always at the player's nose). 5 s is
## the feel default locked at the M3 slice gate: about a third of six Punks posture (SPEC 7),
## the lens is walled less, and a passive player lasts about 15 s instead of 13.
@export_range(0.0, 10.0, 0.1) var punk_attack_cooldown_s: float = 5.0
## Walking speed multiplier.
@export_range(0.25, 3.0, 0.05) var punk_speed_mult: float = 1.0

@export_subgroup("Kicker")
@export_range(5.0, 500.0, 1.0) var kicker_health: float = 25.0
## Multiplier on the posture circling speed (it flanks fast) and on its walking speed.
@export_range(0.25, 4.0, 0.05) var kicker_circle_mult: float = 1.6
@export_range(0.25, 3.0, 0.05) var kicker_speed_mult: float = 1.3
## Chance (0..1) that its attack is the low sweep rather than the jump kick.
@export_range(0.0, 1.0, 0.05) var kicker_sweep_chance: float = 0.4
## Seconds after its attack ends (or after a hit or a block ended the attempt) before it wants
## another token; it runs through the recover hold and the walk back to the ring (the Kicker walks
## that in about a second and a half). 3 s is the feel default chosen from measurement (two Kickers
## round a player who stands still, 40 s, 4 seeds): 15-17 attacks, against 10-11 for two Punks at
## their locked 5 s, about the same damage a second (a kick is 8, a two-hit punch 12) but half
## again as many wind-ups, from behind. It is a plateau from 2.5 s to 3.5 s (the director's pacing
## sets the cadence there: 17 and 16 attacks); 1.2 s (the S0 seed) gave 21, 5 s gave 12.
@export_range(0.0, 10.0, 0.1) var kicker_attack_cooldown_s: float = 3.0
## Milestone 5 (Game-boy's playtest): a Kicker flanks only while the player is busy with someone
## else (see kicker_flank_busy_radius_m); otherwise it is seated by its own arc like any enemy, so a
## one-on-one is fought face to face. Off: M5's rule, a Kicker always takes the seat nearest directly
## behind the look. (director_even_spread on: M3's rule, always flank, whatever this says.)
@export var kicker_flank_opportunistic: bool = true
## A Kicker counts the player as busy while another live, engaged enemy that is not itself flanking
## stands inside the player's view within this distance (m) of him and nearer the middle of the view than
## the Kicker is (the player faces that enemy, not the Kicker). 4.5 is the token reach: posture_ring_max_m
## 4.0 plus token_grant_margin_m 0.5, the farthest an enemy can be and still be about to attack.
@export_range(1.0, 12.0, 0.1) var kicker_flank_busy_radius_m: float = 4.5
## Seconds the player must have been busy before a Kicker starts flanking (the engage grace, so a
## glance at a Punk, or a quick turn past one, does not send it round).
@export_range(0.0, 3.0, 0.05) var kicker_flank_on_s: float = 0.5
## Seconds the player must have been free (not busy) before a Kicker stops flanking and squares up
## where it is: longer than the on-delay, so a Punk dipping out of view for a moment does not flip it.
@export_range(0.0, 5.0, 0.05) var kicker_flank_off_s: float = 1.0
## Seconds a flanking Kicker keeps flanking once the player faces it (it stands inside his view and no other
## enemy he is busy with is nearer the middle of it). 0 is the tick he faces it: "when he turns on it, it
## fights". kicker_flank_off_s still times the other way the flank ends (the other enemy leaves the view or
## the radius, or goes down).
@export_range(0.0, 3.0, 0.05) var kicker_flank_faced_off_s: float = 0.0

@export_subgroup("Pipe Thug")
@export_range(5.0, 500.0, 1.0) var thug_health: float = 35.0
## Seconds before it wants another attack token, counted from the end of its combo through the recover
## hold and the walk back (below about 4 s it never binds). Locked at 8.0 from measurement: its combo
## costs 30 against the Punk's 12, so it comes at 8 s to the Punk's 5.
@export_range(0.0, 10.0, 0.1) var thug_attack_cooldown_s: float = 8.0
@export_range(0.25, 3.0, 0.05) var thug_speed_mult: float = 0.95
## Speed (m/s) the dropped pipe leaves the thug's hand at, toward whoever hit it (it slides on the
## floor: 0.5 lands it a metre or so from the player, inside LB's reach; the first plan's 2.0 away
## from the hit landed it out of reach), and how fast it spins about the vertical (radians a
## second) as it falls.
@export_range(0.0, 8.0, 0.1) var thug_drop_speed_mps: float = 0.5
@export_range(0.0, 20.0, 0.5) var thug_drop_spin_rps: float = 3.0
## Pipes dropped by Thugs that may lie on the floor at once (the oldest are cleared past it; 0 = no
## limit): waves repeat and every Thug drops one.
@export_range(0, 30, 1) var thug_pipes_on_floor_max: int = 4

@export_subgroup("Enemy grabs")
## Presses of P or K that break an enemy's hold before its hit lands, and the sim frames of
## invulnerability the victim keeps after breaking free (CombatActor.break_free()).
@export_range(1, 30, 1) var grab_break_presses: int = 8
@export_range(0, 120, 1) var grab_break_invuln_frames: int = 20
## Mash progress lost per second (0 = none), and the speed (m/s) the holder is shoved away at
## when broken free of.
@export_range(0.0, 20.0, 0.1) var grab_break_decay_per_s: float = 0.0
@export_range(0.0, 10.0, 0.1) var grab_break_push_mps: float = 3.0
## Frames the held player's look takes to turn to the holder, the distance (m) the held body is
## pinned from the holder's origin (more for a holder wider than he is), and the most the held
## view tips up (degrees) toward the holder's eyes.
@export_range(1, 60, 1) var grabbed_turn_frames: int = 8
@export_range(0.3, 2.0, 0.05) var grabbed_pin_distance_m: float = 0.9
@export_range(0.0, 45.0, 1.0) var grabbed_view_pitch_deg: float = 30.0
## Seconds the held player takes to be lifted off the floor (the boss's slam wind-up).
@export_range(0.0, 1.0, 0.05) var grabbed_lift_s: float = 0.4
## An enemy's grab connects within this range (m, at a 1.8 m rig: a taller grabber reaches
## further) and this many degrees of its facing.
@export_range(0.5, 3.0, 0.05) var enemy_grab_range_m: float = 1.05
@export_range(5.0, 90.0, 1.0) var enemy_grab_half_angle_deg: float = 50.0
## The break-free sound's volume (dB, on top of its layers' own), played at the holder.
@export_range(-20.0, 12.0, 0.5) var grab_break_db: float = 0.0

@export_subgroup("Bruiser")
@export_range(5.0, 500.0, 1.0) var bruiser_health: float = 80.0
## Seconds its armor stays off after a haymaker.
@export_range(0.0, 10.0, 0.1) var bruiser_armor_break_s: float = 2.0
## Chance (0..1) that its attack is the grab rather than the smash.
@export_range(0.0, 1.0, 0.05) var bruiser_grab_chance: float = 0.4
## Seconds after an attack ends before it asks for another token. It counts through the recover hold
## and the walk back, so below about 4 it hardly binds (measured: 7 attacks in 40 s at 2.2, 5 at 3.5
## and 4.0, 4-5 at 5.0 against a player who does nothing).
@export_range(0.0, 10.0, 0.1) var bruiser_attack_cooldown_s: float = 4.0
@export_range(0.25, 3.0, 0.05) var bruiser_speed_mult: float = 0.8
## Armor shrugging a light hit off (the Bruiser's, and the boss's): the grey spark's width (m; the
## block spark's art, tinted), how grey it is (0 black to 1 white), and the clank (the block clack
## pitched down: its pitch scale and its volume in dB on top of the clack's own).
## How much farther out than any held body it stands (m) while the player holds a Bruiser: its head
## and shoulders are bigger and nearer the lens than a 1.8 m body's, a wall of purple at the same pin.
@export_range(0.0, 1.0, 0.01) var bruiser_held_pin_extra_m: float = 0.3
@export_range(0.0, 2.0, 0.01) var armor_spark_m: float = 0.24
@export_range(0.0, 1.0, 0.01) var armor_spark_grey: float = 0.55
@export_range(0.25, 2.0, 0.05) var armor_clank_pitch: float = 0.6
@export_range(-20.0, 12.0, 0.5) var armor_clank_db: float = 0.0

@export_subgroup("Boss")
@export_range(50.0, 2000.0, 10.0) var boss_health: float = 300.0
## Share (0..1) of its health at which it enters phase 2 (once), the turn rate (rad/s) it
## has before that and the multiplier on it after, and the Street Punks it calls in at that
## moment, placed this far (m) around it when no spawner is there.
@export_range(0.05, 0.95, 0.05) var boss_phase2_at: float = 0.5
@export_range(0.5, 20.0, 0.5) var boss_turn_rate: float = 2.5
@export_range(1.0, 5.0, 0.1) var boss_phase2_turn_mult: float = 1.8
@export_range(0, 6, 1) var boss_adds_count: int = 2
@export_range(2.0, 12.0, 0.5) var boss_add_ring_m: float = 5.0
## It charges only when the player is at least this far (m): up close it has no run-up and pounds
## or grabs. The weights below pick between the charge, the ground pound and the grab when more
## than one fits. (2.5 is the posture ring's near edge: the plan's 4.0 is the ring's far edge, where
## nothing posturing stands, so the charge never came.)
@export_range(1.0, 12.0, 0.5) var boss_charge_min_m: float = 2.5
@export_range(0.0, 1.0, 0.05) var boss_charge_chance: float = 0.4
@export_range(0.0, 1.0, 0.05) var boss_pound_chance: float = 0.3
@export_range(0.0, 1.0, 0.05) var boss_grab_chance: float = 0.3
@export_range(0.0, 10.0, 0.1) var boss_attack_cooldown_s: float = 1.5
@export_range(0.25, 3.0, 0.05) var boss_speed_mult: float = 0.85
## A crowd round the player (boss_crowd_count or more other enemies within boss_crowd_m of him)
## makes the boss pound rather than grab.
@export_range(1.0, 8.0, 0.5) var boss_crowd_m: float = 3.0
@export_range(1, 6, 1) var boss_crowd_count: int = 2
## Frames a perfect block (a parry) knocks the boss into a recoil: a small window to hit it in.
## A plain block does nothing to it (no blocked recoil on its moves).
@export_range(0, 120, 1) var boss_parry_recoil_frames: int = 36
## Poise (the boss cannot be stun-locked by the basic chain): for this many seconds after it is back
## on its feet from a stagger or a knockdown, or until its next attack is over, a heavy hit and a
## finisher (not the haymaker) are absorbed like a light one: the damage lands, a grey spark, no
## reaction. 0 = no poise (the armor alone). A heavy hit still cuts its grab.
@export_range(0.0, 10.0, 0.1) var boss_poise_s: float = 4.0
## How many of its own attacks (a wind-up that was not cut, through its recovery) end a poise early:
## 1 = its next attack, 0 = none (the time alone).
@export_range(0, 4, 1) var boss_poise_attacks: int = 1
## A second guard: this many reactions (a hit that staggered or floored it) within boss_poise_window_s
## make it poised until the oldest leaves the window. 0 = no cap.
@export_range(0, 6, 1) var boss_poise_after_reactions: int = 2
@export_range(1.0, 30.0, 0.5) var boss_poise_window_s: float = 8.0
## A charge or a pound with the player within boss_read_m (its wind-up is over the lens at that range:
## 1.4 m for the pound, 1.2 for the charge) is preceded by a step back, for up to boss_back_off_s.
## Either at 0 = it winds up where it stands.
@export_range(0.0, 4.0, 0.1) var boss_read_m: float = 1.5
@export_range(0.0, 3.0, 0.1) var boss_back_off_s: float = 0.8

@export_group("Rear warning")
## An attacker winding up more than this many degrees off the look, close enough, lights a
## top corner (Spec §8). Also the edge of the player's view for the director's blind spot.
@export_range(20.0, 120.0, 1.0) var rear_warning_angle_deg: float = 55.0
## Size multiplier and opacity (0..1) of the corner burst. Every burst lies inside the reserved
## corner (20% x 20% of the screen: 216 px at 1080p) and a heavy one is rear_warning_heavy_scale
## times the normal one, so the normal burst stops growing at the corner over that scale
## (166 px at 1080p and the default scale: a size of 1.04 at the default base) and a larger
## setting does nothing: the plan's corner is the limit, and it moves with the base and the
## scale, so the range stays as it is.
@export_range(0.25, 3.0, 0.05) var rear_warning_size: float = 1.0
@export_range(0.0, 1.0, 0.05) var rear_warning_opacity: float = 0.9
## The wind-up's own effort and whoosh sounds (positional) play: off silences every wind-up cue.
@export var rear_warning_audio: bool = true
## Both corners light when the attacker is within this many degrees of directly behind.
@export_range(0.0, 60.0, 1.0) var rear_warning_behind_deg: float = 20.0
## The warning fires within the attack's reach (MoveData.reach_m) plus this many metres.
@export_range(0.0, 4.0, 0.1) var rear_warning_range_margin_m: float = 1.0
## Burst size (pixels at 1920 x 1080) before rear_warning_size, how far in from the screen's
## top corner its centre sits (pixels; a big burst is pushed further in so it stays on screen,
## and every burst stays inside the reserved 20% x 20% corner), and the multiplier on it for a
## heavy attacker (SPEC §8: larger for the Bruiser and boss, at every size setting).
@export_range(40.0, 400.0, 5.0) var rear_warning_base_px: float = 160.0
@export_range(0.0, 200.0, 1.0) var rear_warning_inset_px: float = 96.0
@export_range(1.0, 3.0, 0.05) var rear_warning_heavy_scale: float = 1.3
## Pulses when it appears (and again when another attacker joins that side), and the length
## (s) of each, then it holds steady.
@export_range(0, 8, 1) var rear_warning_pulses: int = 2
@export_range(0.02, 1.0, 0.01) var rear_warning_pulse_s: float = 0.12
## How the burst beats: it pops in this much larger (0..1 of its size, fading over the
## pulses), and each pulse dips to this share of its steady alpha before coming back.
@export_range(0.0, 1.0, 0.05) var rear_warning_pulse_grow: float = 0.25
@export_range(0.0, 1.0, 0.05) var rear_warning_min_alpha: float = 0.65
## Brightness of a burst is 1 plus this for each attacker on that side beyond the first (it
## multiplies the burst's colour and its alpha, which rear_warning_opacity caps at 1).
@export_range(0.0, 1.0, 0.05) var rear_warning_brightness_step: float = 0.2
## The side is decided when the wind-up starts and kept (off); on, it follows the player's turning.
@export var rear_warning_follow_turn: bool = false
## The warning is hidden while the player is KO'd (the KO view).
@export var rear_warning_hide_in_ko: bool = true

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

@export_group("Level")
@export_subgroup("Arena locks")
## Seconds a barrier takes to close (a shutter drops, a gate slides, a car rolls across).
@export_range(0.1, 3.0, 0.05) var barrier_close_s: float = 0.6
## Seconds a barrier takes to open once the arena is clear.
@export_range(0.1, 3.0, 0.05) var barrier_open_s: float = 0.8
## An arena's behind barrier closes once the player is this far (m) past it, along the walk, so
## he can never be shut on the wrong side of it.
@export_range(0.5, 6.0, 0.1) var arena_lock_inset_m: float = 2.0
## A named spawn point nearer the player than spawn_min_player_distance_m (or with no room) is
## waited for this long (s); then the nearest free point with the same tag is used. With
## spawn_behind_waits_out_of_view on, the same wait holds a behind point (a spawn point flagged
## `out_of_view`) while it is inside the player's view; then the nearest free point outside the view,
## of any tag, takes it.
@export_range(0.0, 10.0, 0.1) var spawn_named_wait_s: float = 2.0
## When no point of its tag is free either (a point with a unique tag, with the player standing
## by it), a further wait (s) after spawn_named_wait_s; then the nearest free point of any tag in
## the arena takes it, so a player holding a spot cannot stall the wave.
@export_range(0.0, 20.0, 0.1) var spawn_named_any_wait_s: float = 3.0
## How often (s) a named spawn that cannot be placed yet (its point is too near the player, has no
## room or, for a behind point with spawn_behind_waits_out_of_view on, is in view) tries again.
@export_range(0.02, 1.0, 0.01) var spawn_named_retry_s: float = 0.1
## Off (the default, Game-boy's playtest ruling): a behind point (flagged `out_of_view`) is used like
## any named point, at once when it is free, even with the point inside the player's view, so there is
## no lull before a hit from behind. On: M5's hold, a behind point waits (spawn_named_wait_s, then
## spawn_named_any_wait_s) while it is inside the player's view and falls back to the nearest free
## point outside the view.
@export var spawn_behind_waits_out_of_view: bool = false
@export_subgroup("Weapon look")
## The colour of a weapon lying on the floor (a level's pick-up, a dropped or landed pipe), so it
## reads against the floor's grey from across a room. In a hand or in the air it keeps its own colour.
@export var weapon_floor_color: Color = Color(0.96, 0.7, 0.1)
## How much thicker a weapon is drawn while it lies on the floor (the collision does not change).
@export_range(1.0, 4.0, 0.1) var weapon_floor_radius_scale: float = 1.6
## The floor glint (M6, D28), the look of a weapon lying on the floor now that the amber is retired: a small four-point
## sparkle that floats above it, drawn facing the lens and never smaller than `weapon_glint_min_angle_deg` on screen
## (so it still shows from across a street), pulsing at `weapon_glint_pulse_hz`. Gone while the weapon is held or flying.
@export_range(0.0, 1.5, 0.05) var weapon_glint_height_m: float = 0.45
## The glint's drawn size (m) when it is near; far away the angular floor below takes over.
@export_range(0.1, 1.0, 0.05) var weapon_glint_size_m: float = 0.35
## The smallest angle the glint covers on screen (degrees): 3 is about 35 px of a 900 px frame at any distance (the
## first recording at 1.6 left a 12 px star at 10 m, which hardly read).
@export_range(0.5, 6.0, 0.1) var weapon_glint_min_angle_deg: float = 3.0
@export_range(0.2, 4.0, 0.1) var weapon_glint_pulse_hz: float = 1.1
## How far the glint dims at the bottom of a pulse (0 = steady, 1 = out).
@export_range(0.0, 1.0, 0.05) var weapon_glint_pulse_depth: float = 0.35
## Degrees a second the four points turn, so the sparkle twinkles.
@export_range(0.0, 180.0, 5.0) var weapon_glint_spin_dps: float = 30.0
@export_range(0.2, 3.0, 0.1) var weapon_glint_intensity: float = 1.6
## A warm white: no red (SPEC section 10) and not the retired amber.
@export var weapon_glint_color: Color = Color(1.0, 0.96, 0.78)
## The bike chain's links (M6, a presentation-only sim; docs/ARCHITECTURE.md, WEAPONS): Verlet points pinned at the grip and
## drawn as a MultiMesh of the art's `Link`, a point to the tip's nominal line. It never touches a hit or a body.
@export_range(3, 16, 1) var weapon_chain_points: int = 8
@export_range(1, 10, 1) var weapon_chain_iterations: int = 4
## How hard each point is pulled back to the straight line from the grip (1/s): high keeps the chain near the weapon's axis
## (the padlock stays under the hitbox), low lets it trail and whip.
@export_range(0.0, 120.0, 1.0) var weapon_chain_follow_rate: float = 30.0
@export_range(0.0, 30.0, 0.5) var weapon_chain_gravity: float = 9.8
## The share of speed each point loses a step.
@export_range(0.0, 0.5, 0.01) var weapon_chain_damping: float = 0.04
## A grip that moves further than this in one step (m: a pick-up, a reparent) snaps the chain straight rather than whipping it.
@export_range(0.1, 3.0, 0.05) var weapon_chain_snap_m: float = 0.6
## The distance between two drawn links along the chain (m); the Link mesh is 0.05 m long.
@export_range(0.02, 0.06, 0.002) var weapon_chain_link_pitch_m: float = 0.032
## The longest step the chain sim integrates in one go (s): a longer frame is cut to it, so a hitch cannot blow the Verlet
## points apart (the stability limit; 1/30 s).
@export_range(0.01, 0.1, 0.001) var weapon_chain_max_dt_s: float = 1.0 / 30.0
@export_subgroup("Prop art")
## How much of tuning's floor colour (weapon_floor_color) a weapon's ART takes while it lies on the floor (M6, until the
## floor glint replaces it): 0 keeps the art's own colours, 1 multiplies them by the floor colour outright (the steel of a
## chain goes near black), so a weapon reads against the floor and its palette still shows.
@export_range(0.0, 1.0, 0.05) var weapon_art_floor_tint: float = 0.45
@export_subgroup("Drop-offs")
## The invisible guard along every open edge (physics layer 9): the player can never walk or be
## knocked off, a standing enemy never walks off. Off, the player can fall (the fall rule below).
@export var level_edge_guard: bool = true
## Health the player loses to a fall (with the guard off), before he is put back at the arena's
## Respawn marker.
@export_range(0.0, 100.0, 1.0) var level_fall_damage: float = 20.0
## Seconds the player cannot be hurt after a fall.
@export_range(0.0, 5.0, 0.1) var level_fall_invuln_s: float = 1.5
@export_subgroup("GO cue")
## Seconds the "GO" arrow shows after an arena clears.
@export_range(0.5, 6.0, 0.1) var go_cue_s: float = 2.0
## Size of the cue (1 = the default panel).
@export_range(0.5, 2.0, 0.05) var go_cue_size: float = 1.0
## Seconds of one swell of the cue's breath (0 = steady).
@export_range(0.0, 2.0, 0.05) var go_cue_pulse_s: float = 0.5
## "GO" stays up at least go_cue_s and then until the player faces the exit (his look within
## go_cue_face_deg of it) or comes within go_cue_pass_m of it, but no longer than go_cue_max_s.
## Off, it lasts go_cue_s as in the first build.
@export var go_cue_until_faced: bool = true
## A look within this many degrees of the exit counts as facing it.
@export_range(5.0, 90.0, 1.0) var go_cue_face_deg: float = 30.0
## Coming within this flat distance of the exit (m) ends the cue.
@export_range(0.5, 12.0, 0.5) var go_cue_pass_m: float = 3.0
## The longest the cue stays up (s) while go_cue_until_faced is on.
@export_range(2.0, 20.0, 0.5) var go_cue_max_s: float = 8.0
## The panel's layout (pixels at 1920 x 1080, before go_cue_size): the gap between the word and the
## arrow, the padding round them (across, down) and the offset of the panel's shadow.
## The gap between the word and the arrow (px).
@export_range(0.0, 100.0, 1.0) var go_cue_gap_px: float = 26.0
## The padding across (px).
@export_range(0.0, 100.0, 1.0) var go_cue_pad_x_px: float = 34.0
## The padding down (px).
@export_range(0.0, 100.0, 1.0) var go_cue_pad_y_px: float = 18.0
## The panel shadow's offset (px).
@export_range(0.0, 20.0, 0.5) var go_cue_shadow_px: float = 6.0
@export_subgroup("Kit")
## The trim sheet's tiling (Milestone 6, KIT): the metres one width of the sheet (2048 px) covers on a
## module's face. The strips are painted for 4 m; a smaller number makes the brick, the plaster and the
## asphalt finer, a larger one coarser. The faces' UVs are in metres, so a wall of any length fits.
@export_range(1.0, 16.0, 0.25) var kit_trim_m_per_tile: float = 4.0
@export_subgroup("Ground")
## The street's ground tile (M6 playtest feedback, FB-GROUND; assets/export/kit/ground_sheet.png): the metres one side of
## it covers. It is painted for 8; a smaller number repeats its cracks, squares and manhole more often, a larger one
## spreads them. It is sampled in world metres, so two floor blocks butt without a seam at any value. The tile is mirrored on
## every other tile along the street's length, so its manhole and grates repeat down the street every twice this.
@export_range(2.0, 16.0, 0.5) var ground_m_per_tile: float = 8.0
## Where the ground's ink starts to soften with distance (the mip level at which the cut's edge begins to widen)...
@export_range(0.0, 8.0, 0.25) var ground_ink_soft_from_lod: float = 2.0
## ...how much it widens a level (0 = the cut stays crisp, and a crack thinner than a pixel flickers)...
@export_range(0.0, 0.5, 0.01) var ground_ink_soft_per_lod: float = 0.12
## ...and the most it widens (0.45: the ink then shows as the sheet's own coverage, a crack dimming with the mips).
@export_range(0.0, 0.5, 0.01) var ground_ink_soft_max: float = 0.45
## The strips' ink (the concrete's joints, the kerb's, the plaster's cracks) fades out between these two sizes of a
## pixel, in texels of the 2048 px sheet, measured as the mean of the pixel's two sides (FIX-WORLD: the longer side alone
## faded a roof deck's or a kerb top's seams within 6 to 10 m, where the eye sees them at a graze): the capped mip
## (Look > Trim) would alias it past the first, so it is gone by the second. A wall seen square at 10 m is about 9 texels
## a pixel, at 20 m about 17; a deck seen from eye height at 10 m is about 15 (46 along, 5 across).
@export_range(1.0, 256.0, 1.0) var ground_ink_fade_start_texels: float = 16.0
@export_range(2.0, 512.0, 1.0) var ground_ink_fade_end_texels: float = 64.0
@export_subgroup("Draw cost")
## M6 final review (perf): the largest error (m) a static prop's shadow mesh may have against the prop's own
## triangles. The sun's shadow pass draws a coarser mesh of a car, a tank or a dumpster (about half the triangles,
## within 0.12 m: a shadow is soft and falls on the floor), cast by a shadow-only twin of the prop's mesh; 0 draws the prop's own triangles in the shadow
## pass too. Read when a StaticArt model is first built, so set it (a preset never holds it) before the room loads.
@export_range(0.0, 0.5, 0.01) var draw_prop_shadow_error_m: float = 0.12
## The distance (m) from the lens past which a prop's shadow twin is not drawn: the sun's shadows end at 40 m
## (RoomKit.build_environment), and a car's or a tank's shadow is a few metres long, so 60 m shows no change.
## 0 draws it at every distance. Read when a StaticArt is built.
@export_range(0.0, 200.0, 5.0) var draw_prop_shadow_range_m: float = 60.0
## The simplification's normal merge angle and split angle (degrees; ImporterMesh.generate_lods): the surface angle
## under which neighbouring faces count as one surface when a level is simplified, and over which an edge stays hard.
@export_range(0.0, 90.0, 1.0) var draw_prop_lod_merge_deg: float = 25.0
@export_range(0.0, 90.0, 1.0) var draw_prop_lod_split_deg: float = 25.0
@export_subgroup("Section light")
## How long the level's light takes to change from one section's to the next's (Milestone 6, DRESS; D12):
## the sun's direction, colour and energy, the fog and the sky horizon, blended from the moment the
## player enters the new section (`CombatEvents.section_entered`). 0 snaps. Each section's own light is
## its `LevelSection` exports (the street's dusk, the roofs' copper, the boss roof's dark drop).
@export_range(0.0, 10.0, 0.1) var section_light_blend_s: float = 2.5
## How much the fog covers the sky (Milestone 6, final review; Environment.fog_sky_affect): 1 paints the sky
## the fog's colour, so a section's dusk sky (its `sky_top_color` and `sky_horizon_color`) never shows;
## 0 leaves the sky untouched by the fog. A low value lets the skyline gaps show the dusk while the fog
## still softens it. Every room takes it (RoomKit.build_environment; LevelRoot keeps it live).
@export_range(0.0, 1.0, 0.05) var section_fog_sky_affect: float = 0.3

@export_group("Audio")
@export_subgroup("Mix")
## Volume of every sound effect, in dB: the SFX bus limiter's pre-gain, so turning it down
## also leaves the limiter headroom (below 0 by default: finishers barely touch it).
@export_range(-40.0, 6.0, 0.5) var sfx_volume_db: float = -3.0
## Each one-shot's pitch varies at random by up to plus or minus this share (Spec §6: 8%).
@export_range(0.0, 0.3, 0.01) var sfx_pitch_variation: float = 0.08
## ...and its volume (as amplitude) by up to plus or minus this share (Spec §6: 8%).
@export_range(0.0, 0.3, 0.01) var sfx_volume_variation: float = 0.08
## The sound audition room's (debug) feel: how far in front of the listener a one-shot is played (m), and the gap left after a
## variant when the whole bank plays (s).
@export_range(0.5, 10.0, 0.1) var audition_ahead_m: float = 2.0
@export_range(0.0, 2.0, 0.05) var audition_bank_gap_s: float = 0.35
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
@export_range(-40.0, 12.0, 0.5) var whoosh_db: float = -8.0
@export_range(-40.0, 12.0, 0.5) var thud_db: float = -5.0
@export_range(-40.0, 12.0, 0.5) var crack_db: float = -4.0
@export_range(-40.0, 12.0, 0.5) var crunch_db: float = -11.0
@export_range(-40.0, 12.0, 0.5) var body_fall_db: float = -12.0
@export_range(-40.0, 12.0, 0.5) var sub_thump_db: float = -12.0
## A missed swing's whoosh (attack_whiffed): no impact and no hitstop.
@export_range(-40.0, 12.0, 0.5) var whiff_db: float = -6.0
@export_subgroup("Voices")
## An enemy hit cleanly grunts; the player grunts too, at the listener.
@export_range(-40.0, 12.0, 0.5) var grunt_db: float = -14.0
@export_range(-40.0, 12.0, 0.5) var player_grunt_db: float = -17.0
## An actor grunts at most once per this many ms (a body-blow flurry lands every few frames).
@export_range(0.0, 1000.0, 10.0) var grunt_min_interval_ms: float = 300.0
## Each actor's voice is pitched up or down by up to this share, the same every time.
@export_range(0.0, 0.3, 0.01) var voice_pitch_spread: float = 0.1
## An enemy's wind-up: an effort grunt and a whoosh at the attacker (Spec §8's audio cue,
## on while rear_warning_audio).
@export_range(-40.0, 12.0, 0.5) var windup_db: float = -12.0
## An enemy's KO line (Milestone 6), played at its eyes as it goes down.
@export_range(-40.0, 12.0, 0.5) var ko_db: float = -15.0
## The boss's roar as it enters phase 2.
@export_range(-40.0, 12.0, 0.5) var boss_line_db: float = -10.0
@export_subgroup("Blocks")
@export_range(-40.0, 12.0, 0.5) var block_clack_db: float = -2.5
@export_range(-40.0, 12.0, 0.5) var parry_ting_db: float = -6.0
@export_range(-40.0, 12.0, 0.5) var guard_break_db: float = -1.0
@export_subgroup("World")
## The world's sounds (Milestone 6, D23), in dB at the listener's unit distance: a barrier closing or
## opening (shutter, gate or car), a weapon picked up, thrown, breaking or landing, and a weapon's own
## impact layered on the hit stack of a swing that names one (`MoveData.impact_sfx`).
@export_range(-40.0, 12.0, 0.5) var barrier_db: float = -5.0
@export_range(-40.0, 12.0, 0.5) var weapon_pickup_db: float = -8.0
@export_range(-40.0, 12.0, 0.5) var weapon_throw_db: float = -8.0
@export_range(-40.0, 12.0, 0.5) var weapon_break_db: float = -4.0
@export_range(-40.0, 12.0, 0.5) var weapon_land_db: float = -8.0
@export_range(-40.0, 12.0, 0.5) var weapon_hit_db: float = -8.0
@export_subgroup("Stings")
## The 2D cues: GO when an arena opens its way, CLEAR! at the end of the level.
@export_range(-40.0, 12.0, 0.5) var sting_go_db: float = -8.0
@export_range(-40.0, 12.0, 0.5) var sting_clear_db: float = -8.0
@export_subgroup("Ambience")
## The looping bed under the level (street hum, roof wind), in dB, and how long a crossfade to
## the next section's bed takes.
@export_range(-60.0, 0.0, 0.5) var ambience_db: float = -22.0
@export_range(0.1, 10.0, 0.1) var ambience_fade_s: float = 1.5
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

# The look (Milestone 4; docs/milestones/M4-look-bible.md has the targets). One subgroup per
# owning package, each declared here by the contract scaffold with a seed tunable, so a
# package only adds lines inside its own subgroup. There is no Art subgroup: its one planned
# name, look_show_art, lives in Debug below, since presets skip that group by name and the
# art switch is an A/B, not a look setting.
@export_group("Look")
@export_subgroup("Toon")
## The middle band's brightness as a share of the lit band's (the look bible: 72%). The
## shadow band sits below it, tinted, never black.
@export_range(0.3, 1.0, 0.01) var look_mid_level: float = 0.72
## Where the bands break, on the light a surface gets (its angle to the sun, times the shadow
## map): below the first it is in shadow, below the second in the mid band, above it lit.
@export_range(0.0, 1.0, 0.01) var look_band_1: float = 0.22
## The second break: above it a surface is lit (see look_band_1).
@export_range(0.0, 1.0, 0.01) var look_band_2: float = 0.52
## How wide a band edge is, in pixels at 1080p (the look bible: at most 2 at 1 m). 0 is a hard step.
@export_range(0.0, 8.0, 0.1) var look_band_soft: float = 1.2
## The shadow band's brightness as a share of the lit band's (the look bible: at least 40%,
## never black).
@export_range(0.2, 1.0, 0.01) var look_shadow_level: float = 0.42
## The color the shadow band's hue is shifted toward (a violet), by look_shadow_tint_amount.
@export var look_shadow_tint: Color = Color(0.36, 0.32, 0.55)
## How far the shadow's hue is shifted toward look_shadow_tint, brightness kept (the look
## bible: 45%).
@export_range(0.0, 1.0, 0.01) var look_shadow_tint_amount: float = 0.45
## The one hard highlight shows where a surface faces the half vector this closely (1 is a
## point; the look bible keeps it under 3% of the visible surface).
@export_range(0.5, 1.0, 0.001) var look_spec_cut: float = 0.99
## How bright the highlight is, on the glossy materials; a matte paint takes none.
@export_range(0.0, 2.0, 0.05) var look_spec_strength: float = 0.5
## The factor on the highlight of glossy materials (shades, belts, soles, the pipe).
@export_range(1.0, 8.0, 0.1) var look_spec_gloss: float = 3.0
## The glint on a glossy swatch of the skinned art (the Punk's lens; the palette JSON's `gloss`):
## a second hard highlight from the fill light's camera-fixed direction, shown where the surface
## faces that light's half vector this closely (1 is a point, 0.81 is within 36 degrees; lower
## makes a bigger glint). A visor facing the lens never meets the sun's half vector, so without it
## the lens would never glint; every matte swatch (denim, cotton, cap, skin) takes no highlight.
## The cut only decides WHEN the lens glints: WHERE is the art's mask (the detail mask's G, the lens's
## two authored streaks per eye), so a head tipped back into the cone lights the streaks, never the lens.
@export_range(0.5, 1.0, 0.001) var look_glint_cut: float = 0.81
## The glint's strength as a share of the glossy highlight (0 is off: a glossy swatch then
## highlights only where it faces the sun's half vector, look_spec_cut).
@export_range(0.0, 1.0, 0.05) var look_glint_strength: float = 1.0
## The stepped rim on characters shows past this share of a grazing view (0 to 1, higher is
## thinner; the look bible: about 25% of the silhouette band).
@export_range(0.0, 1.0, 0.01) var look_rim_cut: float = 0.4
## The rim's falloff toward the middle of the body.
@export_range(0.5, 8.0, 0.1) var look_rim_power: float = 2.0
## How much the rim lifts the value (the look bible: +35%).
@export_range(0.0, 1.0, 0.01) var look_rim_strength: float = 0.35
## The sun's height above the horizon in degrees: it sets how much light a vertical surface gets
## (cos of it), so how the bands fall on a character's front. Both rooms' sun (RoomKit).
@export_range(10.0, 85.0, 1.0) var look_sun_elevation_deg: float = 45.0
## The sun's direction about the vertical, the DirectionalLight3D's own yaw in degrees: where
## the light comes from, so which side of a character is lit.
@export_range(-180.0, 180.0, 1.0) var look_sun_yaw_deg: float = -50.0
## The sun's energy. The toon bands take the light's color and cap its brightness, so this
## only moves what the cast shadows and the specular read against.
@export_range(0.2, 3.0, 0.05) var look_sun_energy: float = 1.2
## How soft the sun's shadow edges are (Light3D.shadow_blur: 0 is a hard edge, 1 Godot's default).
## A blurred edge is dithered by the renderer's shadow filter, and a toon band edge laid over that
## dither reads as a stippled strip 10 to 20 px wide (slice gate, gap 11): keep it small.
@export_range(0.0, 3.0, 0.05) var look_sun_shadow_blur: float = 0.25
## The characters' fill light, as a share of a full light: a light fixed to the camera (in its
## view space, so it never turns away from a character that faces the lens) that gives a
## character that faces away from the sun a mid band and a shadow instead of one flat shadow.
## 0 is off. Characters only: the room is lit by the sun alone. Keep it under look_band_2 (the
## fill alone never reaches the lit band: that band is the sun's, so a front-lit character keeps
## its sun-lit, fill-mid and violet shadow bands; at 0.8 the fill lit every lens-facing normal and
## flattened the front-lit vest to one teal) and above look_band_1 / 0.63 (a lens-facing front is
## a mid band, not the flat shadow: the F-look gap 2). The useful range is 0.35 to 0.45.
@export_range(0.0, 1.5, 0.01) var look_fill_strength: float = 0.4
## The fill's direction in the camera's view: degrees to the right of the lens (negative: from
## the left).
@export_range(-90.0, 90.0, 1.0) var look_fill_yaw_deg: float = -35.0
## The fill's height above the lens's axis in degrees.
@export_range(-30.0, 80.0, 1.0) var look_fill_pitch_deg: float = 40.0
## Halftone dots in the shadow band of the room's surfaces, in screen space (off, as the look
## bible says).
@export var look_halftone_env: bool = false
## The same on the characters (off).
@export var look_halftone_chars: bool = false
## A halftone cell's size in pixels at 1080p.
@export_range(2.0, 24.0, 0.5) var look_halftone_cell_px: float = 6.0
## How dark the dots are.
@export_range(0.0, 1.0, 0.01) var look_halftone_strength: float = 0.5
## The cut of the sharp ink: the detail mask of an art that asks for it (metadata/detail_sharp:
## the hero's wraps, straps and glove lines, and the Punk's tape, mouth, nose and seams) is
## thresholded here with a pixel-wide antialiased edge instead of mixed in by its bilinear value,
## so a one-texel line stays a crisp line when it is magnified to 3 to 9 pixels at 0.2 to 0.4 m
## (the hero) or about 2 pixels at 1 m (the Punk). A low cut keeps the strands whole (0.35 to 0.5
## breaks them into dashes). 0 is the soft linear mix for every art (the A/B).
@export_range(0.0, 0.9, 0.01) var look_detail_cut: float = 0.15

## M6 DETAIL-2: an art whose detail mask carries a palette slot per texel (the Bruiser's) takes each
## texel's swatch, so a colour border follows the texture, not the 2 cm faces. A border at texel
## resolution (about 4 mm) is exact up close but crawls once a texel is smaller than a pixel, so the
## swatch fades to the face's between this many texels per pixel (below it every texel is its own;
## the Bruiser's texels are about 4 mm, so 1 is about 3 m) and `look_texel_swatch_fade_far`.
@export_range(0.1, 8.0, 0.1) var look_texel_swatch_fade_near: float = 1.0
## The texels per pixel at and beyond which a texel takes its face's swatch (about 10 m at 3).
@export_range(0.2, 16.0, 0.1) var look_texel_swatch_fade_far: float = 3.0

@export_subgroup("Outline")
## The inverted-hull outline's width in pixels at 1080p (the look bible: 3.5 to 4 px at 1 to
## 3 m, never above 4.5).
@export_range(0.5, 8.0, 0.05) var look_outline_px: float = 3.75
## The line holds its pixel width from this distance from the lens (m) out to look_outline_far_m;
## nearer it is as wide in the world as here (so wider on screen: the player's own arms are
## seen at 0.3 to 0.6 m).
@export_range(0.1, 5.0, 0.05) var look_outline_near_m: float = 0.3
## Beyond this distance (m) the line is as wide in the world as here, so thinner on screen
## (the look bible keeps it at 2 px or more out to 10 m).
@export_range(2.0, 60.0, 0.5) var look_outline_far_m: float = 12.0
## The player's own body in first person is drawn this much of the line's width (the look
## bible: x0.8).
@export_range(0.0, 1.5, 0.05) var look_outline_fp_scale: float = 0.8
## The line fades out from this distance from the lens (m) to twice it, so a lens never sits
## inside a hull.
@export_range(0.0, 0.5, 0.01) var look_outline_lens_fade_m: float = 0.1
## Primitive characters, dummies, props and the room's boxes get the hull too, so the
## placeholders sit beside the art in one style (Spec §10 asks for it on characters and props).
## Read when a body, a prop or a room's box is built: a change shows on the next one.
@export var look_hull_on_placeholders: bool = true

@export_subgroup("Edges")
## The post-process edge lines on the environment (creases, silhouettes, floor edges).
@export var look_edges_enabled: bool = true
## The edge lines' width in pixels at 1080p (the look bible: 1 to 1.5 px; the pass draws whole
## pixels, so 1.5 and 1.0 differ only at a 1440p or taller screen).
@export_range(0.5, 4.0, 0.05) var look_edge_px: float = 1.25
## How big a depth step draws a silhouette line: the share of the one-over-distance the next
## pixels lose (0.5 = half). A plane never draws, however steep.
@export_range(0.02, 1.0, 0.01) var look_edge_depth_threshold: float = 0.08
## How sharp a corner draws a crease line: one minus the dot product of the two neighbouring
## surface normals (0 = flat, 1 = a right angle).
@export_range(0.05, 1.0, 0.01) var look_edge_normal_threshold: float = 0.35
## The lines start to fade out at this distance (m): the look bible's 25 m.
@export_range(1.0, 200.0, 1.0) var look_edge_fade_start_m: float = 25.0
## ... and are gone at this one (m): the look bible's 60 m.
@export_range(2.0, 300.0, 1.0) var look_edge_fade_end_m: float = 60.0
## The character mask's reach in pixels at 1080p: no edge line is drawn this close to a drawn
## character, whose hull is the line there (the hull's width bound is 4.5 px).
@export_range(0.0, 16.0, 0.5) var look_edge_mask_px: float = 6.0
## The anti-aliasing: 0 = 4x MSAA (the project's), 1 = FXAA (the cheap one for the Mac), 2 = off.
## Applied to the room's viewport; project.godot is untouched.
@export_range(0, 2, 1) var look_aa_mode: int = 0

@export_subgroup("Grade")
## The tonemapper of both rooms' picture: 0 = linear (a flat color shows as authored, so a
## swatch keeps its hue and the ink stays ink), 1 = filmic (M3's: brighter mid-tones, blacks
## lifted, colors pulled toward grey), 2 = Reinhard, 3 = ACES.
@export_range(0, 3, 1) var look_tonemap: int = 0
## The color grade (a LUT: cool shadows, warm highlights).
@export var look_grade_enabled: bool = true
## How much of the grade shows: 0 = the picture as it is, 1 = the whole LUT.
@export_range(0.0, 1.0, 0.05) var look_grade_strength: float = 1.0

@export_subgroup("Trim")
## The trim material's ink (the painted seams and joints of the sheet, its alpha) is cut at this level,
## with an edge one pixel wide (as toon.gdshader's detail_cut does for the characters), so a seam
## stays a crisp line under the sheet's mipmaps. Lower: thicker lines. 1 would show no line.
@export_range(0.05, 0.95, 0.01) var look_trim_ink_cut: float = 0.5
## The sharpest mip level (0 = the sheet's full 2048 px) the trim material may read when a surface
## runs away from the lens. A strip is a 128 px band that wraps, so a level past about 4 (16 px)
## would blend one band into its neighbour; the cap keeps a far wall's detail from smearing into
## the next strip. Higher: a calmer far wall, and a blend between strips.
@export_range(1.0, 7.0, 0.25) var look_trim_lod_cap: float = 4.0

@export_subgroup("FP feel")
## First-person feel alternative: the non-KO knockdown hides the torso slab that fills the
## view while the body lies on the camera. Off = the M3 behavior.
@export var fp_knockdown_hide_torso: bool = false
## First-person feel alternative (grab-03): the combat log, docked right of the view center, sits
## over the knee in a hold, so it hides for as long as the player holds an enemy and comes back
## when the hold ends. Off = the M3 behavior (the L key puts the log away at any time).
@export var combat_log_hide_while_holding: bool = false
## First-person feel alternative (grab-05, hit-01): the most of the view a contact flash may change on
## screen (0.06 = 6%), whatever the camera distance. The flash shader (hit_flash.gdshader) shrinks the
## flash across the line of sight to its point where it would cover more: a knee in a hold or a flurry's
## jabs a few centimeters from the lens, which change a fifth of the view. A flash that already fits
## is not touched, so one farther away is as it was. The figure is the share of the view the flash's
## disc may cover; what it changes on a body is less (a disc is partly off the body), about a third
## to a half of it at close range. 0 = off, the M2 / M3 behavior.
@export_range(0.0, 0.5, 0.005) var hit_flash_fp_max_share: float = 0.0
## First-person feel alternative (r3look-05): a clean finisher's contact flash is this many times
## hit_flash_radius_m, so the haymaker's and the uppercut's, which barely show in the first-person view
## (their contact is behind the surface the lens sees), read. Only a clean finisher's flash (a blocked
## finisher's is the ordinary size). With hit_flash_fp_max_share on, the cap's share grows by the same
## factor for it (this squared), so it stays this many times an ordinary flash. 1 = off, the M3 behavior.
@export_range(1.0, 4.0, 0.05) var hit_flash_finisher_radius_mult: float = 1.0

# Motion (F-motion): the life in the placeholder clips, read when a rig's named-clip library is
# built (the first rig of a size and stance), so a change reaches the rigs built after it. The
# idle breathes and bounces without moving a hurtbox 1 cm, and the walks plant their feet; no move
# clip uses any of it (M4-plan A20).
@export_subgroup("Motion")
## Breathing: how far the chest rocks at the top of a breath (degrees; the upper chest and the
## shoulders follow in proportion). The torso hurtbox moves less than a centimeter.
@export_range(0.0, 4.0, 0.1) var look_motion_breath_deg: float = 1.5
## Breaths per second. The idle loop is one breath long, so this sets its length (about 4 s).
@export_range(0.1, 1.0, 0.05) var look_motion_breath_hz: float = 0.25
## The boxer bounce: how far the hips dip at the bottom of a bounce (meters at 1.8 m; the knees
## compensate, so the soles stay planted). A hurtbox moves at most this far.
@export_range(0.0, 0.03, 0.001) var look_motion_bounce_m: float = 0.005
## Bounces per second (snapped to a whole number per breath).
@export_range(0.5, 3.0, 0.1) var look_motion_bounce_hz: float = 1.5
## The weight shift: how far the pelvis rolls over each foot in turn (degrees), once per breath.
@export_range(0.0, 5.0, 0.1) var look_motion_shift_deg: float = 1.0
## How far the guard's arms and shoulders sway with the bounce and the breath (degrees). They
## have no hurtbox, so this is the most the idle shows of the Punk's hands and shoulders.
@export_range(0.0, 8.0, 0.1) var look_motion_guard_sway_deg: float = 3.0
## Head micro-motion: a slow drift and tilt of the head (degrees), which keeps the hurtbox's
## center within a few millimeters.
@export_range(0.0, 4.0, 0.1) var look_motion_head_deg: float = 1.4
## The player's relaxed idle gets this share of the above (first person: the view rides his
## head, so a quiet body keeps the lens steady).
@export_range(0.0, 1.0, 0.05) var look_motion_player_calm: float = 0.35
## How far a Punk's feet sweep while planted in a walk (meters). The clip is as long as the
## sweep takes at move_speed, so the planted foot moves as fast as the body does and does not
## slide; the step is a little longer than this. Applies to enemies (the boxer stance).
@export_range(0.3, 0.9, 0.01) var look_motion_stride_m: float = 0.62
## The pelvis' turn with each step (degrees); the chest turns against it by the counter-swing.
@export_range(0.0, 10.0, 0.1) var look_motion_hip_roll_deg: float = 4.0
## How far the chest and shoulders turn against the pelvis in a walk (degrees).
@export_range(0.0, 15.0, 0.1) var look_motion_counter_swing_deg: float = 5.0
## Overlap in a flinch: how long (s) the head lags the body's snap and the shoulders lead it.
@export_range(0.0, 0.1, 0.005) var look_motion_overlap_s: float = 0.025
## Overlap: how far the head overshoots the hit pose before it settles (share of the snap).
@export_range(0.0, 0.5, 0.01) var look_motion_overshoot: float = 0.15

@export_group("Debug")
@export var god_mode: bool = false
## The player feels the hits he takes (M6 playtest): the larger shake and punch, the head's roll, the
## edge vignette and the health panel's jolt (Tuning > Hit feel > Hurt). Off gives M6's view back,
## where a hit taken felt as one landed. Presets never hold it.
@export var hurt_feel_enabled: bool = true
## M6's GO sting: on plays `sting_go` when an arena's table finishes, as M6 did; off (Game-boy's
## ruling at his playtest) is silent. The level's CLEAR! sting is not affected. Presets never hold it.
@export var audio_sting_go: bool = false
## A/B switch for Milestone 5's attack arcs: on brings back all of M3's director (the even spread
## round the player, a token to any waiter, the blind-spot roll for any enemy, no engage line).
## Presets never hold it.
@export var director_even_spread: bool = false
@export var one_hit_ko: bool = false
## Enemy AI stands still, faces the player and asks for nothing (F4 "Freeze AI"): a scripted
## act can then place and trigger each attacker by hand.
@export var ai_frozen: bool = false
## Draw the skinned art (on) or the placeholder primitives it stands in for (off): the live
## A/B of Milestone 4. Presets never hold it.
@export var look_show_art: bool = true
## Which of the four smoke-Punk GLBs a Street Punk wears (the slice gate's A/B, SL-int): 0 =
## punk.glb (Tripo's weights, the A-pose route, the default), 1 = punk_rest.glb (the arms-down
## bake), 2 = punk_auto.glb (heat-map weights), 3 = punk_auto_rest.glb. Read when a Punk's body
## is built, so set it (a preset never holds it) before the Punks spawn.
@export_range(0, 3, 1) var look_punk_art_variant: int = 0
## The player wears the probe body (tests/fixtures/art/probe_body.glb: a mannequin through the real
## chain, Body + Body__fp_hidden) instead of his primitives, until the hero's GLB exists
## (F-player-int, M4-plan A14). Read when the player's body is built, so set it (a preset never
## holds it) before the room loads. With the hero's GLB in place the player wears that and this
## switch picks the probe over it.
@export var look_player_art_probe: bool = false
## The edge pass's debug view: 0 = the picture, 1 = the roughness buffer (white = the world, black =
## a character or the sky), 2 = the normals, 3 = the distance, 4 = the character mask (red),
## 5 = only the depth lines, 6 = only the crease lines.
@export_range(0, 6, 1) var look_edge_debug_view: int = 0
## A8's switch: the edge pass skips pixels near a drawn character (on), or draws its depth lines
## there too (off: the fallback for a thinner hull, the lines may double).
@export var look_edge_character_mask: bool = true
## The cheap fallback: depth lines only, so the renderer makes no normal-roughness buffer (no
## creases, no character mask).
@export var look_edge_depth_only: bool = false
## Motion's A/B (read when a named-clip library is built): off builds the M3 clips, with linear
## keys and no life, so a capture can pair an M3 and an M4 recording of one act.
@export var look_motion_polish: bool = true
## A/B for M6's damage marks per swatch (D6): on, a swatch that says "blood": false (the Punk's cap,
## laces and strap) scuffs but never takes blood, and blood has a hard edge (`vfx_blood_edge_cut`);
## off brings back M4's: every clothes swatch takes the blood tile, soft-edged. Read at each look
## change. Presets never hold it.
@export var look_marks_per_swatch: bool = true
## A/B of M6 DETAIL-2's texel swatches: on, an art whose detail mask has palette codes in its blue
## channel (the Bruiser's) takes each texel's swatch; off, every face takes its own, as M6 did. Read
## when a material is made or refreshed. Presets never hold it.
@export var look_texel_swatch: bool = true
## A/B of D14 (M6 PROPS): a static prop's baked-smooth-normal hull (on) or the screen edge pass's
## lines alone (off). Read when a StaticArt is built, so set it (a preset never holds it) before the
## room loads.
@export var prop_art_hull: bool = true
## KIT's A/B (Milestone 6, D1): every block, barrier panel, stair flight and room box draws as M5's
## graybox (a flat colour box, the grid floor, plain barrier boxes), the kit's modules, dressing and
## prop spots hidden. The colliders are the same either way. Read when a block is built, so set it
## (a preset never holds it) before the level loads.
@export var kit_draw_graybox: bool = false
## Milestone 6's audio A/B: every pool the Milestone 2 placeholders had plays from them
## (tests/fixtures/sfx_legacy/) instead of the final sounds. The training room's audition room
## toggles it with the minus key. Presets never hold it.
@export var audio_legacy_bank: bool = false
## A/B switch for the floor glint (M6, D28): on brings back M5's look, a weapon on the floor coloured `weapon_floor_color`
## and drawn thicker (its art tinted), and no glint. Presets never hold it.
@export var weapon_floor_amber: bool = false
## A/B switch for the bike chain's sim: off draws StaticArt's straight repeats of the link instead. Presets never hold it.
@export var weapon_chain_sim: bool = true
## ARM's A/B (Milestone 6, D7): the hero's upper arms are drawn in the first-person lens during the
## haymaker and the uppercut (the moves that say fp_show_upper_arm: his art's Body__fp_arm mesh goes
## on the default layer while they run), or off, M5's view where the arm starts at the elbow's dome.
## Read every frame. Presets never hold it.
@export var look_near_arm: bool = true
## How the near upper arm is lit while it is drawn (M6 fix-final-arm): the toon bands of its material copy, so it reads as one limb
## with the forearm. The sun and the fill light a raised arm's underside below band_1 (a violet tube beside the lit forearm); the arm
## takes these instead: shadow only below `look_near_arm_band_1` (0 = only a surface turned right away from the light), full light
## above `look_near_arm_band_2`, and the mid band at `look_near_arm_mid_level` between. The toon values (Look > Toon) are the forearm's.
@export_range(0.0, 0.5, 0.01) var look_near_arm_band_1: float = 0.0
@export_range(0.0, 1.0, 0.01) var look_near_arm_band_2: float = 0.35
@export_range(0.3, 1.0, 0.01) var look_near_arm_mid_level: float = 0.86
## DRESS's A/B (Milestone 6, D12): each section's own light (sun, fog, sky) on, or Tuning's one sun
## and the room's default fog everywhere, as in M5. Read live by the level. Presets never hold it.
@export var section_light_enabled: bool = true
## FB-GROUND's A/B: on, the street's asphalt is drawn from the sheet's own asphalt strip (a wrapped 4 x 1 m strip per
## face, its mip capped) instead of the ground tile, as in M6's first cut. Read live. Presets never hold it.
@export var ground_sheet_off: bool = false


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


## Trauma a clean hit of `tier` adds to the view of the player it hits (hurt_feel_enabled): the tier's
## shake times hurt_shake_mult, never under hurt_shake_min.
func hurt_shake(tier: CombatTypes.HitTier) -> float:
	return clampf(maxf(shake(tier) * hurt_shake_mult, hurt_shake_min), 0.0, 1.0)


## Camera punch, in degrees, of a clean hit of `tier` on the player (hurt_feel_enabled).
func hurt_punch_deg(tier: CombatTypes.HitTier) -> float:
	return cam_punch_deg(tier) * hurt_punch_mult


## Head roll, in degrees, of a clean hit of `tier` on the player (hurt_feel_enabled).
func hurt_roll_deg(tier: CombatTypes.HitTier) -> float:
	match tier:
		CombatTypes.HitTier.HEAVY:
			return hurt_roll_heavy_deg
		CombatTypes.HitTier.FINISHER:
			return hurt_roll_finisher_deg
	return hurt_roll_light_deg


func cam_punch_deg(tier: CombatTypes.HitTier) -> float:
	match tier:
		CombatTypes.HitTier.HEAVY:
			return cam_punch_heavy_deg
		CombatTypes.HitTier.FINISHER:
			return cam_punch_finisher_deg
	return cam_punch_light_deg
