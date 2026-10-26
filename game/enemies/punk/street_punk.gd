class_name StreetPunk
extends EnemyActor
## The Street Punk (Milestone 3, SPEC §7): the grunt every wave is made of. 30 HP, no armor, so a
## light hit knocks it out of its wind-up. Two attacks: the two-hit punch (a jab with a held
## wind-up, then a cross that follows with no wind-up, only if the jab landed or was blocked) and
## the shove (hands drawn to the chest, then a two-handed push that staggers). Both 6 damage,
## LIGHT. A saturated red jacket with a yellow cap and shoes: told from the orange dummy at a
## glance. All behaviour is EnemyActor's; this file is the Punk's data.

## The jacket and the accents (cap, glove straps, shoes), distinct from the training dummy's.
@export var color: Color = Color(0.82, 0.12, 0.2)
@export var accent: Color = Color(0.96, 0.82, 0.14)


func _ready() -> void:
	archetype = &"punk"
	super._ready()


func _configure_rig(r: HumanoidRig) -> void:
	r.body_color = color
	r.accent_color = accent


func _build_attacks() -> Array[EnemyAttack]:
	return [
		EnemyAttack.of(&"two-hit punch", [&"punk_jab", &"punk_cross"]),
		EnemyAttack.of(&"shove", [&"punk_shove"], &"punk_shove_chance"),
	]


func _health_tunable() -> StringName:
	return &"punk_health"


func _speed_tunable() -> StringName:
	return &"punk_speed_mult"


func _cooldown_tunable() -> StringName:
	return &"punk_attack_cooldown_s"
