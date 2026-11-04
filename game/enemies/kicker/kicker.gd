class_name Kicker
extends EnemyActor
## The Kicker (Milestone 3, SPEC §7): the fast flanker. 25 HP, no armor, so a light hit knocks it
## out of its wind-up. Two attacks: the jump kick (a held crouch, then a leap of 1.6 m with the
## right foot out, 8, a flinch) and the low sweep (a held drop to the floor, then a low spin that
## takes a standing player's legs out, 8, a knockdown; a jumping player passes over it). It
## flanks opportunistically (Milestone 5, Game-boy's playtest): only while the player is busy with
## someone else he faces (turn to the Kicker and it fights) does the director (is_flanking()) give it
## a seat of its own directly behind the look (the others' seats are not moved for it), and it gets
## there by walking round the posture ring at a fast pace, visibly leaving the view at its edge, never
## through the player (the way round the ring is EnemyActor's, for every archetype: _orbit_toward()).
## Otherwise it is seated by its own arc like any enemy and squares up where it stands, so a
## one-on-one is fought face to face. Told from the Punk by a lime jacket with
## near-black accents (SPEC §10 reserves red) and a higher voice.
##
## What is the Kicker's own, beside the data (hooks, as the Punk): while flanking, how fast it circles and
## which way it strafes when it is in view (toward the nearer edge of the view). Everything else is
## EnemyActor's.

## The jacket and the accents (cap, wrist wraps, shoes), distinct from the dummy's orange, the
## player's blue and the Punk's.
@export var color: Color = Color(0.55, 0.84, 0.14)
@export var accent: Color = Color(0.1, 0.12, 0.1)


func _ready() -> void:
	archetype = &"kicker"
	prefers_blind_side = true
	super._ready()


func _configure_rig(r: HumanoidRig) -> void:
	r.body_color = color
	r.accent_color = accent


func _build_attacks() -> Array[EnemyAttack]:
	return [
		EnemyAttack.of(&"jump kick", [&"kicker_jump_kick"]),
		EnemyAttack.of(&"sweep", [&"kicker_sweep"], &"kicker_sweep_chance"),
	]


func _health_tunable() -> StringName:
	return &"kicker_health"


func _speed_tunable() -> StringName:
	return &"kicker_speed_mult"


func _cooldown_tunable() -> StringName:
	return &"kicker_attack_cooldown_s"


func _circle_mult() -> float:
	return Tuning.data.kicker_circle_mult if is_flanking() else super._circle_mult()


# --- Strafing in view ---------------------------------------------------------------------------


## Flanking and in view: toward the nearer edge of the view, so it works its way out of sight (a
## strafe segment is short, so it keeps heading that way until it is out). Out of view, or not flanking,
## it strafes as any enemy does.
func _pick_strafe_dir() -> float:
	var player := _find_player()
	if is_flanking() and player and player.has_method(&"is_outside_view") and player.has_method(&"look_bearing_deg") \
			and not player.call(&"is_outside_view", global_position, Tuning.data.rear_warning_angle_deg):
		var away := _flat(global_position - player.global_position)
		if away.length() > 0.01:
			# The tangent the base strafes along for _strafe_dir = +1, and which way it moves the bearing.
			var tangent := Vector3(-away.normalized().z, 0.0, away.normalized().x)
			var now := absf(float(player.call(&"look_bearing_deg", global_position)))
			var later := absf(float(player.call(&"look_bearing_deg", global_position + tangent * 0.5)))
			if not is_equal_approx(now, later):
				return 1.0 if later > now else -1.0
	return super._pick_strafe_dir()
