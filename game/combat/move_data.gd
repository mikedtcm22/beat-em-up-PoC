class_name MoveData
extends Resource
## One attack, as data (Spec §3). Every number here is a tunable default; no attack
## numbers live in scripts. All timing is in frames at 60 Hz.

@export var id: StringName = &""
@export var display_name: String = ""
## Animation id in the actor's animation library. Empty = use `id`.
@export var anim: StringName = &""

@export_group("Frames (60 Hz)")
@export_range(0, 120, 1) var startup: int = 4
@export_range(0, 60, 1) var active: int = 3
@export_range(0, 120, 1) var recovery: int = 10
## First recovery frame (0-based, counted from the start of recovery) at which a chain
## continuation may cancel the rest of recovery.
@export_range(0, 120, 1) var cancel_start: int = 0

@export_group("Damage and reaction")
@export_range(0.0, 100.0, 0.5) var damage: float = 6.0
## Hitstun frames applied on FLINCH (STAGGER/KNOCKDOWN use Tuning durations).
@export_range(0, 120, 1) var hitstun: int = 14
## Knockback velocity in m/s in the hit's frame: z = along the horizontal direction from
## attacker to victim (positive pushes the victim away), x = that direction's right, y = up.
@export var knockback: Vector3 = Vector3(0.0, 0.0, 1.5)
@export var reaction: CombatTypes.Reaction = CombatTypes.Reaction.FLINCH
@export var tier: CombatTypes.HitTier = CombatTypes.HitTier.LIGHT
## Staggers/knocks down armored enemies (Bruiser) regardless of tier (haymaker).
@export var breaks_armor: bool = false
## If true the move hits ONLY downed victims (stomp); otherwise downed victims are skipped.
@export var hits_downed: bool = false
## Max victims per activation; 0 = unlimited.
@export_range(0, 16, 1) var max_targets: int = 0

@export_group("Blocking")
## Goes straight through a guard (grabs, ground pounds).
@export var unblockable: bool = false
## Multiplies the guard drain when this move is blocked (weapons hit the guard harder).
@export_range(0.0, 5.0, 0.05) var guard_damage_mult: float = 1.0
## Frames the attacker recoils when this move is blocked (a punish window); 0 = none
## (Bruiser and boss attacks).
@export_range(0, 60, 1) var blocked_recoil_frames: int = 14

@export_group("Hitboxes")
@export var hitboxes: Array[HitboxSpec] = []

@export_group("Movement")
## Uses target magnetism (Spec §5): lunge toward and turn toward the chosen target.
@export var magnetism: bool = true
## Max lunge during startup in meters. 0 = use Tuning.magnet_lunge. When there is no
## target, the move lunges straight ahead by `free_lunge` instead.
@export_range(0.0, 8.0, 0.05) var lunge: float = 0.0
@export_range(0.0, 8.0, 0.05) var free_lunge: float = 0.0
## Flat distance from the attacker's origin to a standing 1.8 m target's origin at which this
## move's strike connects, travel included (its lunge or free_lunge): a boss charge or a jump
## kick from 4-6 m away still reaches. 0 = not an AI attack. The AI closes to it before
## winding up, and the rear warning fires within reach_m + rear_warning_range_margin_m. Set
## per enemy move in tools/gen_moves.gd and checked against the measured strike.
@export_range(0.0, 10.0, 0.01) var reach_m: float = 0.0

@export_group("Camera")
## First-person camera offset at full weight: eased in over startup, held through active,
## eased out over recovery. Negative pitch looks down (kicks use about -10).
@export_range(-30.0, 30.0, 0.5) var camera_pitch_deg: float = 0.0
@export_range(0.0, 0.3, 0.005) var camera_drop_m: float = 0.0
## First-person view turn at full weight, eased in and out like the pitch (positive turns
## left): the back elbow turns the view over the shoulder toward its elbow.
@export_range(-180.0, 180.0, 1.0) var camera_yaw_deg: float = 0.0
## Recovery frames the offsets above stay at full weight before they ease out.
@export_range(0, 60, 1) var camera_hold_frames: int = 0
## Share (0..1) of the body's spin since the move started that the view turns with
## (the eyes' facing, EyePoint): 1 for 360-degree spins, so the view spins with the body
## and lands back on the heading. Times Tuning.cam_spin_follow_mult.
@export_range(0.0, 1.0, 0.05) var camera_spin_follow: float = 0.0
## First-person view (M6 D7): while this move runs, the hero's upper arms are drawn in the lens
## (his art's Body__fp_arm mesh, the shoulder half of each upper arm, hidden from the lens
## otherwise), so the arm comes in from the shoulder instead of starting at the elbow's dome.
## Only the haymaker and the uppercut set it. Off with Tuning.look_near_arm.
@export var fp_show_upper_arm: bool = false

@export_group("Combo")
@export var branches: Array[ComboBranch] = []
## Pressing `repeat_input` during this move's recovery repeats this same move, up to
## `repeat_max` extra times (the body-blow flurry). Avoids self-referencing resources.
@export var repeat_input: StringName = &""
@export_range(0, 30, 1) var repeat_max: int = 0
## Started automatically when this move's recovery ends with no continuation chosen,
## or when repeats are exhausted (flurry -> shove).
@export var auto_next: MoveData

@export_group("Audio")
## The weapon-hit pool for this move (Milestone 6, D22): a landed hit plays
## `weapon_<impact_sfx>_hit`. Empty for fists and feet, which keep the tier's hit stack.
@export var impact_sfx: StringName = &""


func get_anim() -> StringName:
	return anim if anim != &"" else id


func total_frames() -> int:
	return startup + active + recovery


func is_finisher() -> bool:
	return tier == CombatTypes.HitTier.FINISHER


## Phase helpers for a 0-based frame index within the move.
func is_startup(frame: int) -> bool:
	return frame < startup


func is_active(frame: int) -> bool:
	return frame >= startup and frame < startup + active


func is_recovery(frame: int) -> bool:
	return frame >= startup + active and frame < total_frames()


func can_cancel(frame: int) -> bool:
	return frame >= startup + active + cancel_start
