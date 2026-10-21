class_name HumanoidRig
extends Node3D
## Placeholder humanoid body shared by the player, dummies and enemies until real art
## arrives (Milestone 4). Builds, in code:
##   - a Skeleton3D using Godot humanoid-profile bone names (see docs/ARCHITECTURE.md),
##   - primitive meshes per bone (chunky proportions, slightly oversized hands and feet),
##   - region hurtboxes (Hurtbox areas) kept in sync with the bones,
##   - named rig points (strike markers, EyePoint, WeaponGrip/Tip, HeadTopPoint, ChestPoint),
##   - a procedural animation library played through an AnimationPlayer in MANUAL mode.
## The character faces -Z; the rig origin is at the feet.
##
## Time: the owner calls advance(dt) once per physics tick with its SIM delta (0 during
## hitstop, scaled during slow-mo). Nothing here advances on its own.

@export var height: float = 1.8
@export var body_color: Color = Color(0.22, 0.42, 0.78)
@export var accent_color: Color = Color(0.92, 0.9, 0.85)
@export var skin_color: Color = Color(0.86, 0.66, 0.5)
## Player only: put head and neck meshes on CombatTypes.VIS_FP_HIDDEN.
@export var first_person_body: bool = false
@export var build_hurtboxes: bool = true

## The CombatActor that owns this rig. Set before build(); copied into each Hurtbox.actor.
var actor: Node3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer


## Create skeleton, meshes, hurtboxes, rig points and the animation library. Idempotent.
func build() -> void:
	pass


## Play a named (non-move) animation such as &"idle", &"flinch_gut" or &"getup_back".
## `speed` scales playback. Restarts it if it is already playing.
func play(anim: StringName, blend_s: float = 0.08, speed: float = 1.0) -> void:
	pass


## Play the animation for `move`, built (and cached) so its length is exactly
## move.total_frames() / 60 s, it reaches the strike pose at move.startup / 60 s, holds it
## through the active frames, and returns to guard by the end of recovery.
func play_move(move: MoveData, blend_s: float = 0.04) -> void:
	pass


## Locomotion while FREE: idle or walk_forward/back/left/right, picked from the local move
## direction (x = right, y = forward) and played at `speed_ratio` (1 = full walk speed).
func play_locomotion(local_move: Vector2, speed_ratio: float) -> void:
	pass


## Advance animation by `dt` sim seconds, update the skeleton pose, sync hurtboxes.
func advance(dt: float) -> void:
	pass


func current_anim() -> StringName:
	return &""


func has_anim(anim: StringName) -> bool:
	return false


## World transform of a bone (by humanoid name) or rig point (e.g. &"RightFistPoint").
func get_point_transform(point: StringName) -> Transform3D:
	return global_transform


func get_point_position(point: StringName) -> Vector3:
	return get_point_transform(point).origin


## Node that follows a bone or rig point, for attaching visuals (held weapon at WeaponGrip).
func get_attachment(point: StringName) -> Node3D:
	return self


func get_hurtboxes() -> Array[Hurtbox]:
	return []


func set_hurtboxes_enabled(enabled: bool) -> void:
	pass


## White hit flash, 0..1 (Spec §6: 2 frames on contact).
func set_flash(amount: float) -> void:
	pass
