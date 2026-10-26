class_name Boss
extends EnemyActor
## The graybox boss (Milestone 3, SPEC §7; placeholder name "Boss": its name and look wait for the
## art). 300 HP over two phases, 2.3 m tall and 0.5 m wide, group "boss" (the HUD's bottom bar
## follows it and skips its over-head bar). Armored: a light hit lands its damage and is absorbed
## (no flinch, the move runs on), a heavy hit staggers it (which also gets the player out of its
## grab wind-up: Game-boy's rule), and a finisher knocks it down (the punish window). It can never
## be grabbed. Three attacks, picked by range (_choose_attack()):
##   the shoulder charge (boss_charge): a held crouch, then a 4 m dash over the move's active frames
##     (stopping at a wall) with an arc in front of the shoulder, 20, a knockdown; blockable. Thrown
##     from beyond boss_charge_min_m.
##   the ground pound (boss_pound): a rearing wind-up, then a ring round the boss at the feet, 15, a
##     knockdown; unblockable, but a jump or a dodge gets out of it. Thrown when the player is
##     close, and when others crowd him.
##   the grab slam (boss_grab, then boss_slam; P2-grab's EnemyHold): a grab that connects by code,
##     then a slam that lifts the held player and throws him, 25; the player mashes free first.
## Every move's wind-up is the heavy floor of 30 frames or more, so the rear warning's larger burst
## (heavy) and the held telegraph read at the posture ring.
##
## Phase 2: at health <= boss_phase2_at of its maximum, once, it emits
## CombatEvents.boss_phase_changed(self, 2), turns faster (its turn rate times boss_phase2_turn_mult)
## and calls in boss_adds_count Street Punks, through the room's EncounterSpawner when there is one
## (the nearest free spawn points, so they walk in from the doorways and alleys) and otherwise on
## the navmesh boss_add_ring_m round it. A beckoning gesture marks it when it is free to make one.
##
## A parry (a perfect block) does not stagger it (_parry_staggers() is false: it would be parry-locked
## by a perfect block every time); it takes a short recoil instead, boss_parry_recoil_frames, so a
## parried boss attack opens a small window. A plain block does nothing to it (its moves never
## recoil when blocked: the data rule). Everything else is EnemyActor's; this file is the boss's data.

## The body and its trim: charcoal with orange accents (cap, wrist wraps, shoes), told from the
## Punk's teal, the Kicker's lime, the Thug's olive and the Bruiser's purple at a glance, and not
## red, which SPEC §10 keeps for blood, the rear warning and the finisher's accents.
@export var color: Color = Color(0.13, 0.13, 0.15)
@export var accent: Color = Color(0.96, 0.5, 0.08)

## 1 until it enters phase 2.
var phase: int = 1
## The Street Punks it has called in (read by tests and the bots).
var adds: Array[EnemyActor] = []


func _init() -> void:
	archetype = &"boss"
	heavy = true
	armor_light = true
	armor_heavy_to_stagger = true
	armor_finisher_to_stagger = false
	voice_pitch_mult = 0.7


func _ready() -> void:
	add_to_group(&"boss")
	super._ready()


func _configure_rig(r: HumanoidRig) -> void:
	r.body_color = color
	r.accent_color = accent


func _build_attacks() -> Array[EnemyAttack]:
	return [
		EnemyAttack.of(&"shoulder charge", [&"boss_charge"], &"boss_charge_chance", true),
		EnemyAttack.of(&"ground pound", [&"boss_pound"], &"boss_pound_chance", true),
		EnemyAttack.of(&"grab and slam", [&"boss_grab", &"boss_slam"], &"boss_grab_chance", true, &"grab"),
	]


func _health_tunable() -> StringName:
	return &"boss_health"


func _speed_tunable() -> StringName:
	return &"boss_speed_mult"


func _cooldown_tunable() -> StringName:
	return &"boss_attack_cooldown_s"


# --- What it throws ---------------------------------------------------------------------------


## By range, with the chances as weights: beyond boss_charge_min_m only the charge reaches; closer,
## the pound or the grab, and with boss_crowd_count or more other enemies within boss_crowd_m of the
## player (a crowd to catch in the ring, no room for a grab) only the pound.
func _choose_attack() -> EnemyAttack:
	var player := _find_player()
	if player == null or _attacks.size() < 3:
		return super._choose_attack()
	var tuning := Tuning.data
	var far := _flat_dist(global_position, player.global_position) >= tuning.boss_charge_min_m
	var weights: Array[float] = [
		tuning.boss_charge_chance if far else 0.0,
		0.0 if far else tuning.boss_pound_chance,
		0.0 if far or _crowded_round(player) else tuning.boss_grab_chance,
	]
	if _crowded_round(player) and not far:
		weights[1] = maxf(tuning.boss_pound_chance, 0.01)
	var total := weights[0] + weights[1] + weights[2]
	if total <= 0.0:
		return super._choose_attack()
	var roll := _rng.randf() * total
	for i in 3:
		roll -= weights[i]
		if roll < 0.0:
			return _attacks[i]
	return _attacks[2]


## Other live AI enemies within boss_crowd_m of the player, boss_crowd_count or more.
func _crowded_round(player: CombatActor) -> bool:
	var count := 0
	for node: Node in get_tree().get_nodes_in_group(&"ai_enemy"):
		var other := node as EnemyActor
		if other == null or other == self or other.health <= 0.0 or other.is_gone():
			continue
		if _flat_dist(other.global_position, player.global_position) <= Tuning.data.boss_crowd_m:
			count += 1
	return count >= Tuning.data.boss_crowd_count


## Never grabbable (the player's grab cannot take a boss: SPEC §7).
func can_be_grabbed() -> bool:
	return false


# --- Turning ----------------------------------------------------------------------------------


## It turns at boss_turn_rate where the base's posture turn is enemy_turn_rate: every turn the base
## makes (posture, engage, the wind-up's tracking) is scaled by the ratio, and by
## boss_phase2_turn_mult from phase 2, so the boss is slow to follow a sidestep and faster after
## the change.
func _face(dir: Vector3, rate: float) -> void:
	super._face(dir, rate * _turn_scale())


func _turn_scale() -> float:
	var scale := Tuning.data.boss_turn_rate / maxf(Tuning.data.enemy_turn_rate, 0.001)
	if phase >= 2:
		scale *= Tuning.data.boss_phase2_turn_mult
	return scale


# --- Parry ------------------------------------------------------------------------------------


## A boss is not staggered by a perfect block (it would be parry-locked); react_to_block() gives it
## a recoil instead.
func _parry_staggers() -> bool:
	return false


## The attacker's side of a blocked hit. An ordinary block does nothing to the boss (its moves have
## no blocked recoil); a perfect one knocks it into a recoil of boss_parry_recoil_frames, a small
## window to hit it in (light hits are absorbed, a heavy one staggers). The recoil is the base's
## (HITSTUN with the recoil pose), only longer than a move's data allows for the boss.
func react_to_block(hit: HitInfo) -> void:
	var frames := Tuning.data.boss_parry_recoil_frames
	if not hit.perfect_block or hit.guard_broken or is_ko() or frames <= 0:
		super.react_to_block(hit)
		return
	if current_move:
		_cancel_move()
	sim_velocity = Vector3(0.0, sim_velocity.y, 0.0)
	_enter_state(CombatTypes.ActorState.HITSTUN, frames)
	_recoiling = true
	var length := rig.anim_player.get_animation(&"recoil").length
	rig.play(&"recoil", 0.0, length * Engine.physics_ticks_per_second / frames)
	rig.advance(0.0)
	_on_move_interrupted()


# --- Phase 2 ----------------------------------------------------------------------------------


## Polled every sim tick, so every way health can fall (a hit, an absorbed hit, a block's chip, a
## cheat) is seen: at health <= boss_phase2_at of its maximum, once, while it is alive.
func _tick_control() -> void:
	super._tick_control()
	if phase == 1 and health > 0.0 and health <= max_health * Tuning.data.boss_phase2_at:
		_enter_phase2()


func _enter_phase2() -> void:
	phase = 2
	CombatEvents.boss_phase_changed.emit(self, 2)
	# The beckoning gesture, when it is free and standing on the ring: "come on".
	if state == CombatTypes.ActorState.FREE and ai_state == AiState.POSTURE and not has_token:
		_start_taunt()
	_call_in_adds()


## boss_adds_count Street Punks: the spawner's free spawn points nearest the boss, so they walk in
## from the doorways and alleys and join the running wave; any it cannot place that way (no
## spawner, or no free point) are put on the navmesh boss_add_ring_m round the boss.
func _call_in_adds() -> void:
	var count := Tuning.data.boss_adds_count
	if count <= 0:
		return
	var spawner := get_tree().get_first_node_in_group(&"encounter_spawner") as EncounterSpawner
	if spawner != null:
		adds.append_array(spawner.spawn_adds(&"punk", count, global_position))
	if adds.size() < count:
		_spawn_adds_round(count - adds.size())


## `count` Punks on the ring round the boss, at the nearest navmesh points (the flat spot itself
## with no navmesh) that have room, spread evenly round it and starting toward the player.
func _spawn_adds_round(count: int) -> void:
	var scene := EnemyCatalog.scene(&"punk")
	var parent := get_parent() as Node3D
	if scene == null or parent == null:
		return
	var player := _find_player()
	var start := _flat(player.global_position - global_position) if player else -get_forward()
	if start.length_squared() < 0.0001:
		start = -get_forward()
	var space := get_world_3d().direct_space_state
	var body := EnemyCatalog.body_size(&"punk")
	var serials := {"Punk": _highest_serial("Punk")}
	var placed := 0
	# A few more directions than punks, so a blocked one (a wall, a crate) is skipped.
	var steps := maxi(count * 3, 6)
	for i in steps:
		if placed >= count:
			break
		var dir := start.normalized().rotated(Vector3.UP, TAU * float(i) / float(steps))
		var spot := _nav_snap(global_position + dir * Tuning.data.boss_add_ring_m)
		if not SpawnRoomCheck.has_room(space, body.x, body.y, spot):
			continue
		var punk := EncounterSpawner.make_enemy(scene, &"punk", serials)
		if punk == null:
			return
		punk.position = parent.to_local(spot)
		var to_boss := global_position - spot
		punk.rotation.y = atan2(-to_boss.x, -to_boss.z) - parent.global_rotation.y
		parent.add_child(punk)
		punk.enter_from(spot, spot)
		adds.append(punk)
		placed += 1


## The nearest point on the navmesh to `spot` when there is one (and it has synced), else `spot` itself
## on the boss's floor.
func _nav_snap(spot: Vector3) -> Vector3:
	var flat := Vector3(spot.x, global_position.y, spot.z)
	if not _has_navmesh():
		return flat
	var snapped := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, flat)
	return Vector3(snapped.x, global_position.y, snapped.z)


## The highest number after `label` among the live AI enemies' names ("Punk12" is 12), so the adds
## get fresh names.
func _highest_serial(label: String) -> int:
	var highest := 0
	for node: Node in get_tree().get_nodes_in_group(&"ai_enemy"):
		var text := String(node.name)
		if text.begins_with(label) and text.substr(label.length()).is_valid_int():
			highest = maxi(highest, text.substr(label.length()).to_int())
	return highest
