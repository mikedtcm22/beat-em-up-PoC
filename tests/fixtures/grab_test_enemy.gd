extends EnemyActor
## A test-only grabber (Milestone 3, P2-grab): an EnemyActor whose only attack is the grab, the
## Bruiser's (bruiser_grab, then bruiser_headbutt) or, with `boss`, the boss's (boss_grab, then
## boss_slam), so the enemy hold can be proved before the Bruiser and the boss exist. It has the
## real AI (the director gives it a token, it closes in, winds up and grabs), or a test places it and
## calls force_attack(). Heavy: the wind-up floor is the heavy one. The armor flags are the base's
## exports (a test sets them before it joins the tree). The scenes
## tests/fixtures/grab_test_enemy.tscn (2.05 m, radius 0.45) and grab_test_boss.tscn (2.3 m,
## radius 0.5) are the two sizes.

## The boss's grab and slam instead of the Bruiser's grab and headbutt.
@export var boss: bool = false


func _ready() -> void:
	archetype = &"grabber"
	heavy = true
	# The boss is in group "boss": the HUD's bar follows it and the 15% rule's exemption (R11) is its.
	if boss:
		add_to_group(&"boss")
	super._ready()


func _configure_rig(r: HumanoidRig) -> void:
	# A dark green jacket with orange accents: told from the Punk's red and the dummy's orange.
	r.body_color = Color(0.16, 0.36, 0.22)
	r.accent_color = Color(0.9, 0.5, 0.12)


func _build_attacks() -> Array[EnemyAttack]:
	if boss:
		return [EnemyAttack.of(&"grab and slam", [&"boss_grab", &"boss_slam"], &"", true, &"grab")]
	return [EnemyAttack.of(&"grab and headbutt", [&"bruiser_grab", &"bruiser_headbutt"], &"", true, &"grab")]


func _health_tunable() -> StringName:
	return &"boss_health" if boss else &"bruiser_health"


func _speed_tunable() -> StringName:
	return &"boss_speed_mult" if boss else &"bruiser_speed_mult"


func _cooldown_tunable() -> StringName:
	return &"boss_attack_cooldown_s" if boss else &"bruiser_attack_cooldown_s"
