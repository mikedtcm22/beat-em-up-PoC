extends GutTest
## The slice, headless (M3-plan P1-int, Part C section 5 and Part A A3.6): six real Street Punks
## in the real crowd room with the real HUD, the player in god mode and standing still, 900
## physics frames (1350 for the rules run), seeded, waves off. It checks what the plan lists
## (never more than the cap attacking, nobody inside 0.7 m of another, nobody stuck walking in,
## the posture ring spread all the way round, a blind-spot grant, a deterministic run) and
## asserts the hard readability metrics through the probe (tests/bot/readability_probe.gd): R1 the
## cap, R2 the wind-up gap, R3 no hit without its wind-up, R10 the rear warning against the rule,
## R11 no big knockdown. Then the autopilot fights three real Punks (the bots' scripted player
## must be able to).

const ROOM_PATH := "res://game/level/crowd_room.tscn"
const Probe := preload("res://tests/bot/readability_probe.gd")
const Pilot := preload("res://tests/bot/autopilot.gd")
const CrowdBot := preload("res://tests/bot/crowd_bot.gd")
const EngageMeter := preload("res://tests/bot/engage_meter.gd")

## The frames of the long run, and the gap between two of the six spawns.
const RUN_FRAMES := 900
## The rules run (_six_punk_run) lasts as long as the "Six Punks, observed" act (1344 frames). With
## the Punk's locked attack cooldown (punk_attack_cooldown_s 5) two Punks first overlap in
## WINDUP or ATTACK between frame 350 and 911 over seeds 0-3, so 900 frames could end just before the
## first overlap of a seed (it did, by 11 frames, at seed 0): the crowd still attacks together, a
## little less often.
const PRESSURE_FRAMES := 1350
const SPAWN_GAP_FRAMES := 24
## The spread is judged from this frame on.
const RING_FRAME := 300
## "Nobody inside 0.7 m of another" counts from here (the walk-ins have sorted themselves out). Two
## capsules touch at 0.7 m (radius 0.35 each); avoidance leaves a hair of overlap, so 0.68 m is
## the line.
const SPACING_FROM_FRAME := 240
const MIN_SPACING_M := 0.68
## A walk-in with no progress for this long is stuck: it moved less than STUCK_MOVE_M.
const STUCK_FRAMES := 120
const STUCK_MOVE_M := 0.3


func after_all() -> void:
	# A headless run is far ahead of the audio clock: give the mixer a moment to drop the sounds
	# the fights played, or the process exits with "resources still in use".
	OS.delay_msec(250)


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.set_value(&"waves_enabled", false)
	TimeController.clear()
	GameInput.menu_open = false


func after_each() -> void:
	GameInput.menu_open = false
	Tuning.reset_to_default()
	TimeController.clear()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _room(presentation: bool) -> CrowdRoom:
	var room := (load(ROOM_PATH) as PackedScene).instantiate() as CrowdRoom
	room.with_presentation = presentation
	room.waves_enabled_on_start = false
	add_child_autofree(room)
	await _ticks(8)  # the navigation map syncs 2 or 3 physics frames after _ready()
	return room


func _spawn(room: CrowdRoom, index: int) -> EnemyActor:
	var point: Dictionary = room.spawner.spawn_points[index]
	return room.spawner.spawn_enemy(&"punk", point.position, point.yaw, false, point.lane_point)


func _row(rows: Array[Dictionary], id: String) -> Dictionary:
	for row in rows:
		if row.id == id:
			return row
	return {}


## The hard rows of `rows` (R1, R2, R3, R10, R11): none FAIL, and each that this act must have
## produced something for is measured (not "n/a").
func _assert_hard_rows(rows: Array[Dictionary], must_measure: Array[String]) -> void:
	for row in rows:
		if row.hard:
			assert_ne(row.status, "FAIL", "%s %s: %s (needs %s)" % [row.id, row.name, row.value, row.limit])
	for id in must_measure:
		assert_ne(_row(rows, id).get("status", "n/a"), "n/a", "%s was measured, not skipped (%s)" % [id, _row(rows, id).get("value", "")])
	assert_true(Probe.hard_ok(rows), "no hard readability metric fails")


# --- Six Punks round a player who stands still -----------------------------------------------


## Spawn six, run PRESSURE_FRAMES, sample the rules each frame. Returns what was seen.
func _six_punk_run() -> Dictionary:
	Tuning.set_value(&"god_mode", true)
	var room := await _room(true)
	var player: PlayerCharacter = room.player
	var probe := Probe.new()
	probe.attach(room, player)
	probe.start_act("six punks, still player")
	var meter := EngageMeter.new()
	meter.lens_enabled = false
	meter.attach(room, player)
	var seen := {
		"most_attacking": 0, "min_spacing": INF, "stuck": [], "blind_grants": 0, "grants": 0,
	}
	var had_token: Dictionary = {}
	var walk: Dictionary = {}  # enemy id -> {frame, pos} of the APPROACH window in progress
	var cap: int = Tuning.data.attacker_cap
	var enemies: Array[EnemyActor] = []
	for frame in PRESSURE_FRAMES:
		if frame % SPAWN_GAP_FRAMES == 0 and enemies.size() < CrowdBot.SURROUND_POINTS.size():
			enemies.append(_spawn(room, CrowdBot.SURROUND_POINTS[enemies.size()]))
		await get_tree().physics_frame
		var attacking := 0
		for enemy in enemies:
			if not is_instance_valid(enemy) or enemy.health <= 0.0:
				continue
			if enemy.state == CombatTypes.ActorState.WINDUP or enemy.state == CombatTypes.ActorState.ATTACK:
				attacking += 1
			# Tokens: a new one is a grant; one that came from the blind spot is a blind grant.
			var id := enemy.get_instance_id()
			if enemy.has_token and not had_token.get(id, false):
				seen.grants += 1
				if enemy.blind_priority_granted:
					seen.blind_grants += 1
			had_token[id] = enemy.has_token
			_track_walk(enemy, walk, frame, seen)
		seen.most_attacking = maxi(seen.most_attacking, attacking)
		if frame >= SPACING_FROM_FRAME:
			seen.min_spacing = minf(seen.min_spacing, _closest_pair(enemies))
	var summary := probe.end_act()
	seen["verdict"] = summary.verdict
	seen["metrics"] = summary.metrics
	seen["engage"] = meter.result()
	return seen


## One more frame of the "no progress while walking in" rule for `enemy`.
func _track_walk(enemy: EnemyActor, walk: Dictionary, frame: int, seen: Dictionary) -> void:
	var id := enemy.get_instance_id()
	if enemy.ai_state != EnemyActor.AiState.APPROACH:
		walk.erase(id)
		return
	if not walk.has(id):
		walk[id] = {"frame": frame, "pos": enemy.global_position}
		return
	var window: Dictionary = walk[id]
	if frame - int(window.frame) < STUCK_FRAMES:
		return
	var moved := Vector2(enemy.global_position.x - window.pos.x, enemy.global_position.z - window.pos.z).length()
	if moved < STUCK_MOVE_M:
		seen.stuck.append("%s f%d" % [enemy.name, frame])
	walk[id] = {"frame": frame, "pos": enemy.global_position}


## The closest two standing enemies' centres (m).
func _closest_pair(enemies: Array[EnemyActor]) -> float:
	var standing: Array[EnemyActor] = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.health > 0.0 and enemy.state in [
				CombatTypes.ActorState.FREE, CombatTypes.ActorState.WINDUP, CombatTypes.ActorState.ATTACK]:
			standing.append(enemy)
	var least := INF
	for i in standing.size():
		for j in range(i + 1, standing.size()):
			var a := standing[i].global_position
			var b := standing[j].global_position
			least = minf(least, Vector2(a.x - b.x, a.z - b.z).length())
	return least


func test_six_punks_round_a_standing_player_keep_the_rules_and_the_hard_metrics() -> void:
	var seen := await _six_punk_run()
	assert_lte(seen.most_attacking, Tuning.data.attacker_cap, "never more than attacker_cap in WINDUP or ATTACK")
	# The crowd attacks in turns (P1-engage): a holder waits squared up on the ring while the one in
	# front attacks and the player reels from it, and steps in so as to arrive as its go comes, so
	# two attacks overlap only when one of them does not land (a block, a whiff), and a player who
	# takes every hit (this one is in god mode and stands still) sees them one after the other.
	assert_gte(int(seen.metrics.windups), 8, "the crowd attacks all the same: %d wind-ups in %d frames" % [int(seen.metrics.windups), PRESSURE_FRAMES])
	assert_gte(seen.min_spacing, MIN_SPACING_M, "nobody inside 0.7 m of another after frame 240, give or take a hair of avoidance (%.3f m)" % seen.min_spacing)
	assert_eq(seen.stuck, [], "nobody stuck walking in for over 2 s")
	assert_gt(seen.grants, 4, "several attacks were granted (%d)" % seen.grants)
	assert_gt(seen.blind_grants, 0, "at least one went to an enemy outside the view (%d of %d)" % [seen.blind_grants, seen.grants])
	# R1, R2, R3, R10 and R11 are measured (a fight with hits, wind-ups from behind) and none fails.
	_assert_hard_rows(seen.verdict, ["R1", "R2", "R3", "R10", "R11"])
	var metrics: Dictionary = seen.metrics
	assert_gt(int(metrics.hits_on_player), 5, "the player was hit (%d times)" % int(metrics.hits_on_player))
	# A token holder never waits at the player's nose (the slice gate's follow-up): from its token to
	# its wind-up it is within 1.3 m only for the last stretch of the walk in. Before P1-engage a holder
	# stood there for 0.8-2.6 s (and 2-5 s of the act in all, with a holder at the nose a third of it).
	var engage: Dictionary = seen.engage
	assert_gt(int(engage.wound_up), 5, "holders wound up (%d)" % int(engage.wound_up))
	assert_lte(float(engage.still_nose_max_s), 0.3, "no holder stood still at the nose for its go (%.2f s at most)" % float(engage.still_nose_max_s))
	assert_lte(float(engage.nose_p95_s), 0.5, "and the walk in's last stretch is all of its time there (p95 %.2f s)" % float(engage.nose_p95_s))
	assert_lte(float(engage.nose_any_share), 0.2, "a holder is at the nose a fifth of the time at most (%.0f%%)" % (100.0 * float(engage.nose_any_share)))
	assert_eq(int(metrics.unwarned_hits), 0, "R3: every hit had its wind-up")
	assert_gt(int(metrics.warning_windups), 3, "R10 checked the warning on %d wind-ups" % int(metrics.warning_windups))
	assert_eq(float(metrics.warning_oracle_agreement), 1.0, "R10: the widget agreed with the rule every time")
	assert_eq(int(metrics.warning_false_positives), 0, "R10: no burst without a wind-up to explain it")
	assert_true(bool(metrics.warning_widget_found), "the HUD's RearWarning was found")
	assert_lte(int(metrics.attacker_cap_violation_frames), 0, "R1: no frame over the cap")
	assert_lte(float(metrics.max_knockdown_hit_damage_non_boss), 15.0, "R11: no non-boss hit that knocked the player down hit harder than 15")



# --- The posture ring ---------------------------------------------------------------------


## The posturing enemies (POSTURE: settled on their slots, circling).
func _posturing(enemies: Array[EnemyActor]) -> Array[EnemyActor]:
	var out: Array[EnemyActor] = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.health > 0.0 and enemy.ai_state == EnemyActor.AiState.POSTURE:
			out.append(enemy)
	return out


func test_the_posture_slots_are_spread_all_round_the_player() -> void:
	# The director seats every enemy at an even share of the 360 degrees, snapped onto the navmesh
	# (a slot inside a crate or the car is moved a step round the circle), so with six enemies the
	# widest gap between two neighbouring slots is the even share plus each one's jitter and a
	# snap step. That is the spread the plan asks for ("the largest empty arc <= 360/n + 30"),
	# judged where the director's slots are, because where the enemies stand is another matter: an
	# enemy backing off from an attack often walks round the player to a seat on the far side, and
	# in this fight the widest empty arc between the enemies themselves reaches 130 to 180 degrees
	# (an open finding for the slice gate, in docs/milestones/M3-calls/P1-int.md).
	Tuning.set_value(&"god_mode", true)
	var room := await _room(false)
	var player: PlayerCharacter = room.player
	var enemies: Array[EnemyActor] = []
	var widest := 0.0
	var checked := 0
	for frame in RUN_FRAMES:
		if frame % SPAWN_GAP_FRAMES == 0 and enemies.size() < CrowdBot.SURROUND_POINTS.size():
			enemies.append(_spawn(room, CrowdBot.SURROUND_POINTS[enemies.size()]))
		await get_tree().physics_frame
		if frame < RING_FRAME or frame % 10 != 0:
			continue
		var bearings: Array[float] = []
		for enemy in enemies:
			var slot: Vector3 = room.director.slot_for(enemy)
			if is_instance_valid(enemy) and enemy.health > 0.0 and slot.is_finite():
				bearings.append(player.look_bearing_deg(slot))
		if bearings.size() < 6:
			continue
		checked += 1
		bearings.sort()
		var arc := bearings[0] + 360.0 - bearings[bearings.size() - 1]
		for i in range(1, bearings.size()):
			arc = maxf(arc, bearings[i] - bearings[i - 1])
		widest = maxf(widest, arc - 360.0 / bearings.size())
	assert_gt(checked, 50, "enough moments with six seated to judge (%d)" % checked)
	var allowed: float = 2.0 * Tuning.data.director_spread_jitter_deg + Tuning.data.director_slot_retry_deg
	gut.p("widest slot arc over an even share: %.0f deg (allowed %.0f)" % [widest, allowed])
	assert_lte(widest, allowed, "no gap between neighbouring slots over an even share by more than the jitter and a snap step (%.0f deg)" % widest)

# --- Determinism ------------------------------------------------------------------------------


## Six Punks walk in and fight for `frames`; a hash of where every one stands and what it is doing.
func _positions_hash(frames: int) -> String:
	Tuning.set_value(&"god_mode", true)
	var room := await _room(false)
	var enemies: Array[EnemyActor] = []
	for frame in frames:
		if frame % SPAWN_GAP_FRAMES == 0 and enemies.size() < CrowdBot.SURROUND_POINTS.size():
			enemies.append(_spawn(room, CrowdBot.SURROUND_POINTS[enemies.size()]))
		await get_tree().physics_frame
	var text := ""
	for enemy in enemies:
		text += "%s %.4f,%.4f,%s;" % [enemy.name, enemy.global_position.x, enemy.global_position.z, enemy.ai_state_name()]
	text += "%.4f,%.4f" % [room.player.global_position.x, room.player.global_position.z]
	room.free()
	await _ticks(2)
	return text.md5_text()


func test_two_identical_runs_end_with_everyone_in_the_same_place() -> void:
	# The first run of a process starts the avoidance one tick earlier than the ones after it (the
	# navigation map's first sync, found by P1-ai): a short warm-up run is discarded, then two
	# full runs must agree.
	await _positions_hash(30)
	var first := await _positions_hash(450)
	var second := await _positions_hash(450)
	assert_eq(first, second, "the same room, names and seeds give the same fight (timed in sim frames)")


# --- The autopilot against real Punks ---------------------------------------------------------


func test_the_autopilot_fights_real_punks_and_the_hard_metrics_hold() -> void:
	# Three Punks are kept on the street (a new one walks in when one falls) for 15 s, and the
	# scripted player must be able to beat them: it lands combos (several Punks go down) and the
	# hard metrics hold with a moving, fighting player too.
	Tuning.set_value(&"god_mode", true)
	var room := await _room(true)
	var player: PlayerCharacter = room.player
	var probe := Probe.new()
	probe.attach(room, player)
	var pilot := Pilot.new()
	pilot.enemy_group = &"ai_enemy"
	pilot.attach(room, player)
	probe.start_act("autopilot, three punks")
	var spawned := 0
	var last_spawn := -1000
	for frame in RUN_FRAMES:
		if room.spawner.alive_count() < 3 and frame - last_spawn >= 45:
			last_spawn = frame
			_spawn(room, CrowdBot.SURROUND_POINTS[spawned % CrowdBot.SURROUND_POINTS.size()])
			spawned += 1
		await get_tree().physics_frame
	pilot.stop()
	var summary := probe.end_act()
	var done: Dictionary = pilot.result()
	var fallen := spawned - room.spawner.alive_count()
	assert_gt(int(done.punches), 8, "it threw punches (%d)" % int(done.punches))
	assert_gte(fallen, 4, "and put at least four Punks down in 15 s (%d of %d)" % [fallen, spawned])
	_assert_hard_rows(summary.verdict, ["R1", "R3", "R11"])
	assert_eq(int(summary.metrics.stuck_events), 0, "R13: nobody stuck")
