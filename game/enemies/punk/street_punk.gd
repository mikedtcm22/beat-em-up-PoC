class_name StreetPunk
extends EnemyActor
## The Street Punk (Milestone 3, SPEC §7): the grunt every wave is made of. 30 HP, no armor, so a
## light hit knocks it out of its wind-up. Two attacks: the two-hit punch (a jab with a held
## wind-up, then a cross that follows with no wind-up, only if the jab landed or was blocked) and
## the shove (hands drawn to the chest, then a two-handed push that staggers). Both 6 damage,
## LIGHT. A saturated deep teal jacket with a yellow cap and shoes: told from the orange dummy at
## a glance, and not red, which SPEC §10 keeps for blood, the rear warning and the finisher's
## accents. All behaviour is EnemyActor's; this file is the Punk's data.

## The other smoke-Punk arts, for Tuning's look_punk_art_variant 1-3: the arms-down bake, the
## heat-map weights, both. Loaded only when asked for.
const ART_VARIANTS: Array[String] = [
	"res://game/actors/art/punk_rest_art.tres",
	"res://game/actors/art/punk_auto_art.tres",
	"res://game/actors/art/punk_auto_rest_art.tres",
]

## The jacket and the accents (cap, glove straps, shoes), distinct from the training dummy's.
@export var color: Color = Color(0.02, 0.5, 0.56)
@export var accent: Color = Color(0.96, 0.82, 0.14)


func _ready() -> void:
	archetype = &"punk"
	super._ready()


func _configure_rig(r: HumanoidRig) -> void:
	r.body_color = color
	r.accent_color = accent


## The scene's art (punk_art.tres), or, for the slice gate's A/B, one of the other three smoke
## GLBs (Tuning's Debug value look_punk_art_variant; 0 keeps the scene's).
func _configure_art(r: HumanoidRig) -> void:
	var variant := clampi(Tuning.data.look_punk_art_variant, 0, ART_VARIANTS.size())
	if variant > 0:
		r.art = load(ART_VARIANTS[variant - 1]) as CharacterArt
	else:
		r.art = art


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
