extends GutTest
## The Milestone 3 done-when, headless (SPEC §12: "a 6-enemy fight is readable, and the warning fires
## correctly behind-left, behind-right and directly behind"), in the real crowd room with its real
## HUD and real enemies.
##
## 1. The warning, with every archetype: a real Punk, Kicker and Bruiser (and the Thug and the
##    boss) placed at 135 degrees left, 135 degrees right and 180 degrees from the look, which is
##    fixed, wind up; the HUD's RearWarning must show the top-left corner only, the top-right only,
##    and both, from the wind-up's first frame to the contact, and nothing after it (a chain link
##    has no wind-up of its own). Negative controls: 50 degrees (in view) and out of range show
##    nothing. The expected corners and distances are written out here by hand, never taken from
##    ViewGeometry.
## 2. The fight: a 1500-frame seeded soak of the six archetypes' mix (Punk, Kicker, Thug, Bruiser,
##    Punk, Kicker) with the readability probe on (tests/bot/readability_probe.gd): the hard metrics
##    R1 (the cap), R2 (the wind-up gap), R3 (no hit without its wind-up), R10 (the warning against
##    the rule) and R11 (no big knockdown), nobody stuck. The player takes the damage the enemies
##    deal but his health is refilled each frame: god mode would zero every hit and R11 would be
##    vacuous.
## 3. The waves: with the waves on and the autopilot fighting, never more than six alive from waves,
##    from the opening Punk waves (1 and 2) and from the mixed ones (3 and 4: Punk, Kicker, Thug and
##    Bruiser together), with R1 and R3 held in both.

const ROOM_PATH := "res://game/level/crowd_room.tscn"
const Probe := preload("res://tests/bot/readability_probe.gd")
const Pilot := preload("res://tests/bot/autopilot.gd")
const CrowdBot := preload("res://tests/bot/crowd_bot.gd")

## How the warning cases are placed. Each row: archetype id, the attack index force_attack() takes,
## and the distance (m) at which that archetype really stands when it winds up (its attack's reach
## less its engage margin), so each wind-up ends in a hit, plus how far out of the warning's range
## it is (the attack's reach plus the range margin of 1 m, and a half metre more). The Thug's
## combo, the Punk's two-hit punch and the rest are the first attack of each.
const CASES: Array[Dictionary] = [
	{id = &"punk", attack = 0, strike_m = 1.0, far_m = 2.6, heavy = false},
	{id = &"kicker", attack = 0, strike_m = 2.6, far_m = 4.3, heavy = false},
	{id = &"bruiser", attack = 0, strike_m = 1.25, far_m = 2.9, heavy = true},
	{id = &"thug", attack = 0, strike_m = 1.0, far_m = 2.8, heavy = false},
	{id = &"boss", attack = 1, strike_m = 2.55, far_m = 4.2, heavy = true},
]
## The positive bearings (degrees, positive to the left) and the corner the done-when wants.
const POSITIVE: Array[Dictionary] = [
	{bearing = 135.0, corner = &"left"},
	{bearing = -135.0, corner = &"right"},
	{bearing = 180.0, corner = &"both"},
]
## The control that is in view (the rule's edge is 55 degrees).
const IN_VIEW_DEG := 50.0
## Frames the AI-frozen enemy gets to settle after it is placed, and the longest a throw may take.
const SETTLE_FRAMES := 12
const THROW_FRAMES := 400
## The mixed soak: its length and the gap between two of the six walking in.
const SOAK_FRAMES := 1500
const SPAWN_GAP_FRAMES := 24
## The waves run: its length.
const WAVES_FRAMES := 1500
## The mixed waves run: the wave it starts at (the table's third, six enemies of three archetypes),
## its length (45 s: wave 3 held back is cleared in about 36 s and wave 4's Bruiser walks in) and
## the archetypes a mixed wave must bring.
const MIXED_WAVE_FROM := 3
const MIXED_WAVES_FRAMES := 2700
const MIXED_WAVE_ARCHETYPES := 3
const MIXED_SIX: Array[StringName] = [&"punk", &"kicker", &"thug", &"bruiser", &"punk", &"kicker"]


## Records which corners of the HUD's warning are lit at the end of every physics frame (after the
## simulation and the HUD's own event handlers), so a test sees the widget as the frame ends.
class Sampler extends Node:
	var warning: RearWarning
	var rows: Array[Dictionary] = []

	func _init() -> void:
		process_physics_priority = 1000

	func _physics_process(_delta: float) -> void:
		if warning == null:
			return
		var left: bool = warning.corner_state(&"left").active
		var right: bool = warning.corner_state(&"right").active
		var lit := &"both" if left and right else (&"left" if left else (&"right" if right else &""))
		rows.append({frame = Engine.get_physics_frames(), lit = lit,
				size = maxf(warning.corner_state(&"left").size_px, warning.corner_state(&"right").size_px),
				heavy = warning.corner_state(&"left").heavy or warning.corner_state(&"right").heavy})


var _room: CrowdRoom
var _player: PlayerCharacter
var _warning: RearWarning
var _sampler: Sampler
## Frames of the events of the enemy under test.
var _enemy: EnemyActor
var _windup_frames: Array[int] = []
var _hit_frames: Array[int] = []
var _whiff_frames: Array[int] = []


func after_all() -> void:
	# A headless run is far ahead of the audio clock: give the mixer a moment to drop the sounds
	# the fights played, or the process exits with "resources still in use".
	OS.delay_msec(250)


func before_each() -> void:
	Tuning.reset_to_default()
	# The Debug toggles are not in the preset: put them back by hand, or one test's frozen AI or
	# god mode is the next one's.
	Tuning.set_value(&"ai_frozen", false)
	Tuning.set_value(&"director_even_spread", false)
	Tuning.set_value(&"god_mode", false)
	Tuning.set_value(&"waves_enabled", false)
	TimeController.clear()
	GameInput.menu_open = false
	_enemy = null
	_windup_frames.clear()
	_hit_frames.clear()
	_whiff_frames.clear()
	CombatEvents.windup_started.connect(_on_windup_started)
	CombatEvents.hit_landed.connect(_on_hit_landed)
	CombatEvents.attack_whiffed.connect(_on_attack_whiffed)


func after_each() -> void:
	for pair: Array in [[CombatEvents.windup_started, _on_windup_started], [CombatEvents.hit_landed, _on_hit_landed],
			[CombatEvents.attack_whiffed, _on_attack_whiffed]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])
	GameInput.menu_open = false
	Tuning.reset_to_default()
	Tuning.set_value(&"ai_frozen", false)
	Tuning.set_value(&"director_even_spread", false)
	Tuning.set_value(&"god_mode", false)
	TimeController.clear()


func _on_windup_started(attacker: Node3D, _move: MoveData) -> void:
	if attacker == _enemy:
		_windup_frames.append(Engine.get_physics_frames())


func _on_hit_landed(hit: HitInfo) -> void:
	if hit.attacker == _enemy:
		_hit_frames.append(Engine.get_physics_frames())


func _on_attack_whiffed(attacker: Node3D, _move: MoveData) -> void:
	if attacker == _enemy:
		_whiff_frames.append(Engine.get_physics_frames())


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _room_up(presentation: bool = true) -> CrowdRoom:
	var room := (load(ROOM_PATH) as PackedScene).instantiate() as CrowdRoom
	room.with_presentation = presentation
	room.waves_enabled_on_start = false
	add_child_autofree(room)
	await _ticks(8)  # the navigation map syncs 2 or 3 physics frames after _ready()
	_player = room.player
	_player.input.scripted = true
	return room


func _spawn_at_point(room: CrowdRoom, id: StringName, index: int) -> EnemyActor:
	var point: Dictionary = room.spawner.spawn_points[index]
	return room.spawner.spawn_enemy(id, point.position, point.yaw, false, point.lane_point)


func _row(rows: Array[Dictionary], id: String) -> Dictionary:
	for row in rows:
		if row.id == id:
			return row
	return {}


## The hard rows of `rows` (R1, R2, R3, R10, R11): none FAIL, and each of `must_measure` has a value.
func _assert_hard_rows(rows: Array[Dictionary], must_measure: Array[String]) -> void:
	for row in rows:
		if row.hard:
			assert_ne(row.status, "FAIL", "%s %s: %s (needs %s)" % [row.id, row.name, row.value, row.limit])
	for id in must_measure:
		assert_ne(_row(rows, id).get("status", "n/a"), "n/a", "%s was measured, not skipped (%s)" % [id, _row(rows, id).get("value", "")])
	assert_true(Probe.hard_ok(rows), "no hard readability metric fails")


# --- 1. The warning, with every archetype ----------------------------------------------------------


## The room with the AI frozen (an enemy stands and asks for nothing; force_attack() still starts its
## attack), god mode (a hit lands and reacts, the player does not die), the look fixed down the
## street, and a sampler on the HUD's warning.
func _warning_room() -> void:
	Tuning.set_value(&"god_mode", true)
	Tuning.set_value(&"ai_frozen", true)
	_room = await _room_up(true)
	_player.rotation.y = _player.look_yaw
	for node: Node in _room.get_children():
		if node is GameHud:
			_warning = (node as GameHud).rear_warning
	assert_not_null(_warning, "the room has its HUD and the HUD its warning")
	_sampler = Sampler.new()
	_sampler.warning = _warning
	_room.add_child(_sampler)


## An enemy `id` `distance` m from the player at `bearing_deg` off his look (positive to the left),
## facing him. The position is worked out here from the look's yaw (forward is -sin, -cos of it).
func _place(id: StringName, bearing_deg: float, distance: float) -> EnemyActor:
	var yaw := _player.look_yaw
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var left := Vector3(-cos(yaw), 0.0, sin(yaw))
	var b := deg_to_rad(bearing_deg)
	var at := _player.global_position + (forward * cos(b) + left * sin(b)) * distance
	at.y = _player.global_position.y
	var to_player := _player.global_position - at
	var enemy := _room.spawner.spawn_enemy(id, at, atan2(-to_player.x, -to_player.z))
	assert_not_null(enemy, "%s spawned" % id)
	var off := absf(rad_to_deg(angle_difference(deg_to_rad(_player.look_bearing_deg(at)), b)))
	assert_lt(off, 0.6, "the player's own look API sees %s at the bearing it was placed at (%.2f degrees off)" % [id, off])
	return enemy


## Place `case` at `bearing_deg`, `distance` m away, let it settle, throw its attack and wait until
## its attack is over. Returns the frames of the sampler from the frame before the wind-up on.
func _throw(case: Dictionary, bearing_deg: float, distance: float) -> Dictionary:
	_enemy = _place(case.id, bearing_deg, distance)
	await _ticks(SETTLE_FRAMES)
	_windup_frames.clear()
	_hit_frames.clear()
	_whiff_frames.clear()
	_sampler.rows.clear()
	await _ticks(3)  # a few dark frames to compare the wind-up's against
	_enemy.force_attack(case.attack)
	for i in THROW_FRAMES:
		await get_tree().physics_frame
		if _enemy.state == CombatTypes.ActorState.FREE and _enemy.current_move == null and not _windup_frames.is_empty():
			break
	await _ticks(30)  # a chain's links, the recovery: nothing may relight
	var rows := _sampler.rows.duplicate()
	var out := {rows = rows, windup = _windup_frames.duplicate(), hits = _hit_frames.duplicate(), whiffs = _whiff_frames.duplicate()}
	EncounterSpawner.remove_enemies(get_tree(), true)
	await _ticks(2)
	# The next one starts when the player is on his feet again (a knockdown takes a second or two).
	for i in 300:
		if _player.state == CombatTypes.ActorState.FREE and not _player.is_invulnerable():
			break
		await get_tree().physics_frame
	return out


func _lit_at(rows: Array[Dictionary], frame: int) -> Variant:
	for row in rows:
		if row.frame == frame:
			return row.lit
	return null


func test_every_archetype_lights_the_right_corner_from_the_first_frame_to_the_contact() -> void:
	await _warning_room()
	var heavy_size := 0.0
	var grunt_size := 0.0
	for case in CASES:
		for spot in POSITIVE:
			var label := "%s at %.0f degrees" % [case.id, spot.bearing]
			var seen := await _throw(case, spot.bearing, case.strike_m)
			assert_eq(seen.windup.size(), 1, "%s: one wind-up (a chain link has none of its own): %s" % [label, str(seen.windup)])
			assert_gt(seen.hits.size(), 0, "%s: the attack landed (%s)" % [label, str(seen.hits)])
			if seen.windup.is_empty() or seen.hits.is_empty():
				continue
			var first: int = seen.windup[0]
			var contact: int = seen.hits[0]
			assert_lt(first, contact, "%s: the contact comes after the wind-up starts" % label)
			assert_eq(_lit_at(seen.rows, first - 1), &"", "%s: dark before the wind-up" % label)
			var gaps: Array[int] = []
			for frame in range(first, contact):
				if _lit_at(seen.rows, frame) != spot.corner:
					gaps.append(frame)
			assert_eq(gaps, [] as Array[int], "%s: %s lit on every frame from the wind-up's first (f%d) to the contact (f%d)" % [label, spot.corner, first, contact])
			assert_eq(_lit_at(seen.rows, contact), &"", "%s: dark on the contact's own frame (f%d)" % [label, contact])
			# And after it: the rest of the attack (a chain's links, the recovery) never relights it.
			var relit: Array[int] = []
			for row in seen.rows:
				if row.frame >= contact and row.lit != &"":
					relit.append(row.frame)
			assert_eq(relit, [] as Array[int], "%s: nothing relights after the contact" % label)
			# A heavy attacker's burst is larger, a grunt's not.
			for row in seen.rows:
				if row.frame == first:
					if case.heavy:
						assert_true(row.heavy, "%s: a heavy attacker's burst is flagged heavy" % label)
						heavy_size = maxf(heavy_size, row.size)
					else:
						assert_false(row.heavy, "%s: a grunt's burst is not" % label)
						grunt_size = maxf(grunt_size, row.size)
	assert_gt(heavy_size, grunt_size, "a heavy attacker's burst (%.0f px) is larger than a grunt's (%.0f px)" % [heavy_size, grunt_size])


func test_the_negative_controls_show_nothing() -> void:
	await _warning_room()
	var watched := 0
	for case in CASES:
		if not case.id in [&"punk", &"kicker", &"bruiser"]:
			continue
		for control in [{label = "in view at 50 degrees", bearing = IN_VIEW_DEG, distance = case.strike_m},
				{label = "in view at -50 degrees", bearing = -IN_VIEW_DEG, distance = case.strike_m},
				{label = "out of range at 135 degrees", bearing = 135.0, distance = case.far_m},
				{label = "out of range at 180 degrees", bearing = 180.0, distance = case.far_m}]:
			var label := "%s %s" % [case.id, control.label]
			var seen := await _throw(case, control.bearing, control.distance)
			assert_eq(seen.windup.size(), 1, "%s: it wound up (%s)" % [label, str(seen.windup)])
			watched += seen.windup.size()
			var lit: Array[int] = []
			for row in seen.rows:
				if row.lit != &"":
					lit.append(row.frame)
			assert_eq(lit, [] as Array[int], "%s: no corner on any frame" % label)
	assert_eq(watched, 12, "every control wound up and was watched")


# --- 2. The six-enemy fight ----------------------------------------------------------------------


func test_a_mixed_six_soak_keeps_the_hard_metrics() -> void:
	var summary := await _mixed_six_soak(false)
	# M5's rows on the attack arcs (soft rows, but this soak is where they were seen to hold).
	for id in ["R5", "R5w", "R6", "R6w", "R9"]:
		assert_ne(_status_of(summary.verdict, id), "miss", "%s on the arcs: %s" % [id, _value_of(summary.verdict, id)])


## The same soak with the Debug switch on (M3's director: the even spread, a token to any waiter, the
## blind-spot roll for any enemy): M3's numbers must hold as they did, R5 and R6 included.
func test_a_mixed_six_soak_with_the_even_spread_switch_on_keeps_m3s_numbers() -> void:
	var summary := await _mixed_six_soak(true)
	for id in ["R5", "R6"]:
		assert_ne(_status_of(summary.verdict, id), "miss", "%s as M3 counted it: %s" % [id, _value_of(summary.verdict, id)])
	assert_eq(_status_of(summary.verdict, "R6w"), "n/a", "no wait ring in M3's director")
	Tuning.data.director_even_spread = false


func _status_of(rows: Array[Dictionary], id: String) -> String:
	for row in rows:
		if row.id == id:
			return row.status
	return "missing"


func _value_of(rows: Array[Dictionary], id: String) -> String:
	for row in rows:
		if row.id == id:
			return str(row.value)
	return ""


## The 1500-frame mixed soak; returns the act's summary after asserting the hard rows.
func _mixed_six_soak(even_spread: bool) -> Dictionary:
	Tuning.data.director_even_spread = even_spread
	_room = await _room_up(true)
	var probe := Probe.new()
	probe.print_summary = false
	probe.print_oracle_lines = false
	probe.attach(_room, _player)
	probe.start_act("mixed six soak")
	var enemies: Array[EnemyActor] = []
	var archetypes: Dictionary = {}
	var cap: int = Tuning.data.attacker_cap
	var most_alive := 0
	for frame in SOAK_FRAMES:
		if frame % SPAWN_GAP_FRAMES == 0 and enemies.size() < MIXED_SIX.size():
			var index := enemies.size()
			enemies.append(_spawn_at_point(_room, MIXED_SIX[index], CrowdBot.SURROUND_POINTS[index]))
		await get_tree().physics_frame
		# He takes the hits (R3 and R11 count real damage) but never goes down for good.
		_player.health = _player.max_health
		most_alive = maxi(most_alive, _room.spawner.alive_count())
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.current_move != null and enemy.state == CombatTypes.ActorState.WINDUP:
				archetypes[enemy.archetype] = int(archetypes.get(enemy.archetype, 0)) + 1
	var summary := probe.end_act()
	var metrics: Dictionary = summary.metrics
	gut.p("mixed six soak: %d wind-ups by %s, %d hits (%d knockdowns, worst %.0f), R1 max %d, R2 min gap %s, R10 %s of %d" % [
			int(metrics.windups), str(archetypes.keys()), int(metrics.hits_on_player), int(metrics.knockdowns_on_player),
			float(metrics.max_knockdown_hit_damage_non_boss), int(metrics.max_concurrent_attackers),
			str(metrics.min_windup_start_gap_frames), str(metrics.warning_oracle_agreement), int(metrics.warning_windups)])
	_assert_hard_rows(summary.verdict, ["R1", "R2", "R3", "R10", "R11"])
	assert_lte(int(metrics.max_concurrent_attackers), cap, "R1: never more than attacker_cap in WINDUP, ATTACK or a hold")
	assert_lte(int(metrics.attacker_cap_violation_frames), 0, "R1: no frame over the cap")
	assert_gte(int(metrics.get("min_windup_start_gap_frames", 0) if metrics.get("min_windup_start_gap_frames") != null else 0),
			int(floor(Tuning.data.director_min_windup_gap_s * Engine.physics_ticks_per_second)),
			"R2: no two wind-ups start together")
	assert_eq(int(metrics.unwarned_hits), 0, "R3: every hit had its wind-up (%s)" % str(metrics.unwarned_detail))
	assert_eq(float(metrics.warning_oracle_agreement), 1.0, "R10: the widget agreed with the rule every time")
	assert_eq(int(metrics.warning_false_positives), 0, "R10: no burst without a wind-up to explain it")
	assert_lte(int(metrics.get("warning_latency_frames", 0) if metrics.get("warning_latency_frames") != null else 0), 1,
			"R10: lit within a frame of the wind-up")
	assert_lte(int(metrics.get("warning_end_lag_frames", 0) if metrics.get("warning_end_lag_frames") != null else 0), 1,
			"R10: out within a frame of its end")
	assert_true(bool(metrics.warning_widget_found), "the HUD's RearWarning was found")
	assert_gt(int(metrics.knockdowns_on_player), 0, "R11 had a knockdown to judge (%d)" % int(metrics.knockdowns_on_player))
	assert_lte(float(metrics.max_knockdown_hit_damage_non_boss), 15.0, "R11: no non-boss hit that knocked the player down hit harder than 15")
	assert_gt(int(metrics.windups), 8, "the crowd attacks all the same (%d wind-ups)" % int(metrics.windups))
	assert_gt(int(metrics.hits_on_player), 5, "and the hits land (%d)" % int(metrics.hits_on_player))
	assert_gte(archetypes.size(), 3, "at least three of the four archetypes wound up in %d frames (%s)" % [SOAK_FRAMES, str(archetypes.keys())])
	assert_eq(int(metrics.stuck_events), 0, "R13: nobody stuck for 3 s")
	assert_lte(most_alive, MIXED_SIX.size(), "never more than six alive")
	return summary


# --- 3. The waves ------------------------------------------------------------------------------------


func test_the_waves_never_put_more_than_six_alive_and_the_fight_stays_readable() -> void:
	Tuning.set_value(&"god_mode", true)
	_room = await _room_up(true)
	var probe := Probe.new()
	probe.print_summary = false
	probe.print_oracle_lines = false
	probe.attach(_room, _player)
	var pilot := Pilot.new()
	pilot.enemy_group = &"ai_enemy"
	pilot.attach(_room, _player)
	probe.start_act("waves")
	Tuning.set_value(&"waves_enabled", true)
	_room.spawner.set_waves_enabled(true)
	var most_alive := 0
	var cap: int = Tuning.data.wave_max_alive
	for frame in WAVES_FRAMES:
		await get_tree().physics_frame
		most_alive = maxi(most_alive, _room.spawner.alive_count())
		assert_lte(_room.spawner.alive_count(), cap, "alive from waves never over wave_max_alive (frame %d)" % frame)
	pilot.stop()
	var summary := probe.end_act()
	var metrics: Dictionary = summary.metrics
	gut.p("waves: peak alive %d, %d spawns, %d waves started" % [most_alive, int(metrics.spawns), _room.spawner.waves_started()])
	assert_lte(most_alive, 6, "never more than six alive from waves")
	assert_gt(most_alive, 1, "and the waves did put a crowd on the street (%d)" % most_alive)
	assert_gte(_room.spawner.waves_started(), 2, "the waves went on to the next")
	_assert_hard_rows(summary.verdict, ["R1", "R3"])
	assert_eq(int(metrics.stuck_events), 0, "R13: nobody stuck")


## The mixed waves of the table (3 and 4), which the Punk waves above never reach: the spawner
## starts at wave 3, no boss wave, the autopilot held back (as CrowdBot.hold_back(): a crowd that
## gets to attack instead of falling to the first combo), god mode, the probe on.
func test_the_mixed_waves_never_put_more_than_six_alive_and_the_fight_stays_readable() -> void:
	Tuning.set_value(&"god_mode", true)
	Tuning.set_value(&"boss_wave_every", 0)
	_room = await _room_up(true)
	var probe := Probe.new()
	probe.print_summary = false
	probe.print_oracle_lines = false
	probe.attach(_room, _player)
	var pilot := Pilot.new()
	pilot.enemy_group = &"ai_enemy"
	pilot.attach(_room, _player)
	pilot.approach = false
	pilot.use_kicks = false
	pilot.punches_per_chain = 2
	pilot.chain_rest_frames = 60
	_room.spawner.start_at_wave(MIXED_WAVE_FROM)
	assert_eq(_room.spawner.waves_started(), MIXED_WAVE_FROM - 1, "wave 3 is the next to start")
	var started: Array[int] = []
	_room.spawner.wave_started.connect(func(number: int, _ids: PackedStringArray) -> void: started.append(number))
	probe.start_act("mixed waves")
	_room.spawner.set_waves_enabled(true)
	var most_alive := 0
	var archetypes: Dictionary = {}
	var cap: int = Tuning.data.wave_max_alive
	for frame in MIXED_WAVES_FRAMES:
		await get_tree().physics_frame
		var alive := _room.spawner.alive_count()
		most_alive = maxi(most_alive, alive)
		assert_lte(alive, cap, "alive from waves never over wave_max_alive (frame %d)" % frame)
		for node: Node in get_tree().get_nodes_in_group(&"ai_enemy"):
			var enemy := node as EnemyActor
			if enemy != null:
				archetypes[enemy.archetype] = true
	pilot.stop()
	var summary := probe.end_act()
	var metrics: Dictionary = summary.metrics
	gut.p("mixed waves: peak alive %d, archetypes %s, waves started %s, %d wind-ups, %d hits, R1 %d, R3 %d unwarned, R10 %s of %d" % [
			most_alive, str(archetypes.keys()), str(started), int(metrics.windups), int(metrics.hits_on_player),
			int(metrics.max_concurrent_attackers), int(metrics.unwarned_hits), str(metrics.warning_oracle_agreement),
			int(metrics.warning_windups)])
	assert_eq(started.slice(0, 1), [MIXED_WAVE_FROM] as Array[int], "the first wave to start was wave 3")
	assert_lte(most_alive, 6, "never more than six alive from a mixed wave")
	assert_gte(most_alive, 5, "and wave 3 did put a crowd on the street (%d)" % most_alive)
	assert_gte(archetypes.size(), MIXED_WAVE_ARCHETYPES, "a mixed wave: at least three archetypes (%s)" % str(archetypes.keys()))
	assert_gt(int(metrics.windups), 5, "the crowd attacks all the same (%d wind-ups)" % int(metrics.windups))
	_assert_hard_rows(summary.verdict, ["R1", "R3", "R10"])
	assert_lte(int(metrics.max_concurrent_attackers), int(Tuning.data.attacker_cap), "R1: never more than attacker_cap at once")
	assert_eq(int(metrics.unwarned_hits), 0, "R3: every hit had its wind-up (%s)" % str(metrics.unwarned_detail))
	assert_eq(int(metrics.stuck_events), 0, "R13: nobody stuck")
