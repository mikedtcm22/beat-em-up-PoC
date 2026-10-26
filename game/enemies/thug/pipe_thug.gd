class_name PipeThug
extends EnemyActor
## The Pipe Thug (Milestone 3, SPEC §7): a weapon carrier. 35 HP, no armor, so a light hit knocks
## it out of its wind-up. It carries a pipe (the player's own Weapon, in its right hand) and
## swings a three-hit combo: a held wind-up with the pipe cocked high behind the shoulder, then
## three swings of 10 (the first two flinch, the third staggers: no knockdown may take more than
## 15% of the player's health, and the chain counts, M3-plan 2.10), the second and third only if the
## swing before landed or was blocked. A knockdown or a killing hit knocks the pipe out of its hand
## (Weapon.drop()): it falls to the street, toward whoever hit it, where the player can take it
## with LB and swing it like any pipe. From then on the Thug is unarmed and throws the Punk's two attacks; it never re-arms
## (the pipe is the player's prize). All behaviour is EnemyActor's; this file is the Thug's data and
## the pipe.

## The pipe the Thug carries (the same scene as the pipe on the training room's floor).
const PIPE_SCENE := preload("res://game/weapons/pipe.tscn")
## The pipes Thugs have dropped are in this group (the "weapon" group also holds the training room's
## pipe and the one the player holds), and carry the physics frame they fell on in this meta, so the
## oldest can be cleared when too many lie in the street (cull_dropped_pipes()).
const DROPPED_GROUP := &"thug_pipe"
const DROPPED_AT_META := &"dropped_at"

## The work jacket and the accents (cap, wraps, shoes): an olive green with cream, told from the
## dummy's orange, the Punk and the Kicker at a glance. SPEC §10: no red.
@export var color: Color = Color(0.4, 0.52, 0.14)
@export var accent: Color = Color(0.93, 0.9, 0.78)
## The pipe's color and drawn radius: brighter and thicker than the training room's grey pipe, so
## it reads in the Thug's hand from the ring and, dropped, on the street's grey floor.
@export var pipe_color: Color = Color(0.96, 0.74, 0.1)
@export var pipe_radius: float = 0.04
## Spawns carrying a pipe. Off, the Thug is born unarmed (tests, bots): it throws the Punk's attacks.
@export var armed: bool = true

## The pipe in its hand; null once dropped (or never carried).
var _pipe: Weapon


func _ready() -> void:
	archetype = &"thug"
	super._ready()
	if armed:
		_take_up_pipe()


## True while the pipe is in its hand.
func has_pipe() -> bool:
	return _pipe != null


func _configure_rig(r: HumanoidRig) -> void:
	r.body_color = color
	r.accent_color = accent


## The pipe combo while it carries the pipe, the Punk's two attacks (by move id) once it has not.
func _build_attacks() -> Array[EnemyAttack]:
	if armed:
		return [EnemyAttack.of(&"pipe combo", [&"thug_pipe_1", &"thug_pipe_2", &"thug_pipe_3"])]
	return [
		EnemyAttack.of(&"two-hit punch", [&"punk_jab", &"punk_cross"]),
		EnemyAttack.of(&"shove", [&"punk_shove"], &"punk_shove_chance"),
	]


func _health_tunable() -> StringName:
	return &"thug_health"


func _speed_tunable() -> StringName:
	return &"thug_speed_mult"


func _cooldown_tunable() -> StringName:
	return &"thug_attack_cooldown_s"


## A knockdown (the reaction asked, or a killing blow) knocks the pipe loose. A flinch or a stagger
## does not: it only breaks the swing.
func _on_hit_received(hit: HitInfo) -> void:
	super._on_hit_received(hit)
	if _pipe and (hit.killed or hit.reaction in [CombatTypes.Reaction.KNOCKDOWN,
			CombatTypes.Reaction.LAUNCH, CombatTypes.Reaction.THROWN]):
		_drop_pipe(hit)


## The pipe goes into its right hand: a child of the Thug until it is on the grip (Weapon.attach_to()
## reparents it on the next idle frame).
func _take_up_pipe() -> void:
	_pipe = PIPE_SCENE.instantiate() as Weapon
	_pipe.color = pipe_color
	_pipe.radius = pipe_radius
	add_child(_pipe)
	_pipe.attach_to(self)


## The pipe leaves the hand and drops toward whoever hit it (the hit's direction reversed; its
## forward, the way it faces the player, when the hit has none), and the Thug goes on unarmed: its
## attacks are the Punk's from the next one. Away from the hit, as the plan first had it, the pipe
## slid two to three metres past the Thug and lay out of the player's reach.
func _drop_pipe(hit: HitInfo) -> void:
	var pipe := _pipe
	_pipe = null
	var toward := Vector3(-hit.direction.x, 0.0, -hit.direction.z)
	if toward.length_squared() < 0.0001:
		toward = get_forward()
	pipe.drop(toward.normalized() * Tuning.data.thug_drop_speed_mps, Tuning.data.thug_drop_spin_rps)
	pipe.add_to_group(DROPPED_GROUP)
	pipe.set_meta(DROPPED_AT_META, Engine.get_physics_frames())
	cull_dropped_pipes(get_tree())
	armed = false
	_attacks = _build_attacks()
	_next_attack = _choose_attack()


## Waves repeat, and every Thug drops a pipe: when more than Tuning.thug_pipes_on_floor_max dropped
## pipes lie free in the scene (not held, not flying), the oldest are cleared, so the street does
## not fill up with them (0 = no limit). A pipe the player holds is never touched.
static func cull_dropped_pipes(tree: SceneTree) -> void:
	var limit: int = Tuning.data.thug_pipes_on_floor_max
	if limit <= 0:
		return
	var lying: Array[Weapon] = []
	for node: Node in tree.get_nodes_in_group(DROPPED_GROUP):
		var weapon := node as Weapon
		if weapon and weapon.is_available() and not weapon.is_queued_for_deletion():
			lying.append(weapon)
	lying.sort_custom(func(a: Weapon, b: Weapon) -> bool:
			return int(a.get_meta(DROPPED_AT_META, 0)) < int(b.get_meta(DROPPED_AT_META, 0)))
	while lying.size() > limit:
		var oldest: Weapon = lying.pop_front()
		oldest.remove_from_group(DROPPED_GROUP)
		oldest.break_apart()
