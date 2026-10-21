class_name TrainingDummy
extends CombatActor
## A target that never attacks (Milestone 1). Full hit reactions, health from Tuning,
## revives after a KO, faces the player, and walks back to its post when left alone.

@export var face_player: bool = true
@export var return_home: bool = true
@export var color: Color = Color(0.86, 0.5, 0.16)
@export var accent: Color = Color(0.16, 0.16, 0.18)

var _home: Vector3
var _idle_frames: int = 0


func _ready() -> void:
	team = 1
	add_to_group(&"enemy")
	max_health = Tuning.data.dummy_health
	super._ready()
	_home = global_position


func _configure_rig(r: HumanoidRig) -> void:
	r.body_color = color
	r.accent_color = accent


func _tick_control() -> void:
	if state != CombatTypes.ActorState.FREE:
		_idle_frames = 0
		return
	_idle_frames += 1
	var to_home := _home - global_position
	to_home.y = 0.0
	if return_home and _idle_frames > 60 and to_home.length() > 0.3:
		var dir := to_home.normalized()
		sim_velocity.x = dir.x * 2.5
		sim_velocity.z = dir.z * 2.5
		_turn_toward(dir, 6.0)
		rig.play_locomotion(Vector2(0.0, 1.0), 0.45)
		return
	sim_velocity.x = 0.0
	sim_velocity.z = 0.0
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if face_player and player:
		var to_player := player.global_position - global_position
		to_player.y = 0.0
		if to_player.length_squared() > 0.01:
			_turn_toward(to_player.normalized(), 4.0)
	rig.play_locomotion(Vector2.ZERO, 0.0)


## Move the dummy and make `pos` the post it walks back to.
func set_post(pos: Vector3, yaw: float = rotation.y) -> void:
	global_position = pos
	rotation.y = yaw
	_home = pos
	sim_velocity = Vector3.ZERO


func _tick_ko() -> void:
	if state_frame >= int(Tuning.data.dummy_revive_s * 60.0):
		_revive()


func _revive() -> void:
	max_health = Tuning.data.dummy_health
	health = max_health
	rig.set_hurtboxes_enabled(true)
	CombatEvents.health_changed.emit(self, health, max_health)
	CombatEvents.revived.emit(self)
	_start_getup()


## Rotate toward a horizontal direction at `rate` radians per second.
func _turn_toward(dir: Vector3, rate: float) -> void:
	var target_yaw := atan2(-dir.x, -dir.z)
	var diff := wrapf(target_yaw - rotation.y, -PI, PI)
	var step := rate / Engine.physics_ticks_per_second
	rotation.y = wrapf(rotation.y + clampf(diff, -step, step), -PI, PI)
