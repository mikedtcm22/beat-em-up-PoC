class_name CineViewRig
extends Node
## The first-person view of a cine shot, staged for a painted background (P1.md, R5-SHOTS): after the game's own camera has moved (its
## process priority is 50, this node's 60) it puts the lens where the shot's data says, and after the frame writer has not yet copied it
## (100). Presentation only: nothing here writes game state, and the simulation never reads the camera.
##  - the lift and the pull-back: the camera moves along its own up and back axes, so the guard fist sits lower in the frame (cropped at the
##    bottom edge) and the opponent's framing gets room. EyePoint and the hitboxes do not move: only the lens does;
##  - the roll: a fixed bank about the view axis (the fight set-ups get one, alternating in sign);
##  - the off-hand: one of the player's arms is scaled away in the drawn skeleton unless a move strikes with it (or a guard or a hold needs
##    both). The sim's own bone poses (hitboxes, weapon grips) are put back before every physics tick, so only the picture changes.
## The FOV is not here: it is written through Tuning by the CineDirector (the main camera, the plate capture and the writer all agree).

## The scale of a hidden arm: not zero, so the skeleton's transforms stay invertible.
const HIDDEN_SCALE := Vector3(0.001, 0.001, 0.001)
## The bone that roots the hidden forearm and fist, by side.
const ARM_BONE_SUFFIX := "LowerArm"
const POINT_SUFFIX := "FistPoint"

var shot: CineShot
var player: PlayerCharacter

var _bone: int = -1
var _hidden: bool = false


func _init() -> void:
	# After the game's cameras (50) and the stage's own poses (60 is the bot); before the frame writer (100).
	process_priority = 60
	# Before every actor's physics tick: the hidden arm's scale is put back first, so the sim never reads a collapsed pose.
	process_physics_priority = -1000


func setup(p_shot: CineShot, p_player: PlayerCharacter) -> void:
	shot = p_shot
	player = p_player
	_bone = -1
	if shot.hide_off_hand and player != null and player.rig != null and player.rig.skeleton != null:
		_bone = player.rig.skeleton.find_bone(StringName(String(shot.off_hand) + ARM_BONE_SUFFIX))


func _physics_process(_delta: float) -> void:
	_set_hidden(false)


func _process(_delta: float) -> void:
	if shot == null or player == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		apply_to_camera(camera, shot)
	_set_hidden(_bone >= 0 and not off_hand_needed(player, shot.off_hand))


## The shot's lift, pull-back and roll on `camera` (the first-person camera, already moved this frame): along its own axes.
static func apply_to_camera(camera: Camera3D, p_shot: CineShot) -> void:
	var basis := camera.global_transform.basis
	var shifted := camera.global_position + basis.y * p_shot.view_lift_m + basis.z * p_shot.view_back_m
	if not is_zero_approx(p_shot.view_roll_deg):
		basis = basis * Basis(Vector3.BACK, deg_to_rad(p_shot.view_roll_deg))
	camera.global_transform = Transform3D(basis, shifted)


## Whether the player's `side` hand ("Left" or "Right") shows now: a move that strikes with it, or a guard, a hold or a throw (both hands).
static func off_hand_needed(p_player: PlayerCharacter, side: StringName) -> bool:
	var states := CombatTypes.ActorState
	if p_player.state in [states.BLOCK, states.BLOCKSTUN, states.GRABBING, states.DODGE]:
		return true
	if p_player.holding_weapon() and side == &"Right":
		return true
	var move := p_player.current_move
	if move == null:
		return false
	if move.hitboxes.is_empty():
		return p_player.state == states.ATTACK
	for spec in move.hitboxes:
		if spec.kind != HitboxSpec.Kind.POINT_SPHERE or String(spec.point).begins_with(String(side)):
			return true
	return false


func _set_hidden(hide_arm: bool) -> void:
	if _bone < 0 or _hidden == hide_arm:
		return
	var skeleton := player.rig.skeleton
	skeleton.set_bone_pose_scale(_bone, HIDDEN_SCALE if hide_arm else Vector3.ONE)
	_hidden = hide_arm
