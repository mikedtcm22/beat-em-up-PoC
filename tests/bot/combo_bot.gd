extends Node
## Scripted combo bot (Spec §11): performs every combo and move against training dummies
## in the test room, alternating first-person and side-view cameras, with a caption per
## act; the block acts use a sparring dummy's telegraphed jab (the bot times it). Record it
## with Movie Maker:
##   godot --path . --write-movie captures/combos.avi --fixed-fps 60 res://tests/bot/combo_bot.tscn
## (tools/capture_combos.sh wraps this and extracts review stills.)

const ROOM := preload("res://game/level/test_room.tscn")
## Where an act parks the dummies it doesn't use (the n-th one PARK_STEP further on): on the
## floor behind the street's east end wall, out of both views.
const PARK := Vector3(24.0, 0.0, 0.0)
const PARK_STEP := Vector3(1.5, 0.0, 0.0)

## Only run acts whose title contains this text (empty = all; `a|b` runs acts matching
## either). Set with `-- --act=<text>` after the scene path; `--tune=<property>=<number>`
## (repeatable) sets a TuningData value for the run.
var act_filter: String = ""

var room: Node3D
var player: PlayerCharacter
var dummies: Array[TrainingDummy] = []
var director: Node
var caption: Label
var log_lines: PackedStringArray = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--act="):
			act_filter = arg.trim_prefix("--act=")
		elif arg.begins_with("--tune="):
			# `--tune=<TuningData property>=<number>`: record with a tunable changed (A/B sheets).
			var pair := arg.trim_prefix("--tune=").split("=")
			if pair.size() == 2 and pair[0] in Tuning.data:
				Tuning.data.set(pair[0], type_convert(float(pair[1]), typeof(Tuning.data.get(pair[0]))))
	Tuning.data.dummy_health = 500.0
	room = _room_scene().instantiate()
	add_child(room)
	_build_caption()
	CombatEvents.hit_landed.connect(_on_hit)
	_run.call_deferred()


## The room the bot plays in: the training room. Subclasses (the crowd bot) return theirs.
func _room_scene() -> PackedScene:
	return ROOM


func _on_hit(hit: HitInfo) -> void:
	var flags := ""
	if hit.perfect_block:
		flags = " PERFECT"
	elif hit.guard_broken:
		flags = " BLOCKED GUARD BREAK"
	elif hit.blocked:
		flags = " BLOCKED"
	var line := "f%d %s: %s %.1f dmg %s%s" % [
		hit.physics_frame,
		hit.victim.name,
		hit.move.display_name if hit.move else "body",
		hit.damage,
		CombatTypes.tier_name(hit.tier),
		flags,
	]
	log_lines.append(line)
	print(line)


func _run() -> void:
	await _ticks(3)
	player = room.get(&"player")
	player.input.scripted = true
	dummies.assign(room.get(&"dummies"))
	director = get_tree().get_first_node_in_group(&"camera_director")
	# The help overlay would cover the captures; the combat log stays for timing review.
	for child in room.get_children():
		if child.has_method(&"set_help_visible"):
			child.call(&"set_help_visible", false)
	var acts: Array[Dictionary] = [
		{title = "P P P P: jab, jab, hook, uppercut", cam = &"first_person", fn = _act_pppp},
		{title = "P P P P (side view)", cam = &"side_view", fn = _act_pppp},
		{title = "P · P: jab, flurry (mash), shove", cam = &"first_person", fn = _act_flurry},
		{title = "P P · P: jab, jab, spinning backfist", cam = &"first_person", fn = _act_backfist},
		{title = "P P · P: spinning backfist (side view)", cam = &"side_view", fn = _act_backfist},
		{title = "K K K: front kick, roundhouse, spinning heel", cam = &"first_person", fn = _act_kkk},
		{title = "K K K (side view)", cam = &"side_view", fn = _act_kkk},
		{title = "K · K: front kick, stomp kick", cam = &"first_person", fn = _act_k_pause_k},
		{title = "P P K: jab, jab, push kick", cam = &"first_person", fn = _act_ppk},
		{title = "Hold P, release: haymaker", cam = &"first_person", fn = _act_haymaker},
		{title = "Hold P, release: haymaker (side view)", cam = &"side_view", fn = _act_haymaker},
		{title = "Jump + K: flying kick", cam = &"side_view", fn = _act_flying_kick},
		{title = "Jump + K at apex: spin kick", cam = &"side_view", fn = _act_spin_kick},
		{title = "Jump + K at apex: spin kick (first person)", cam = &"first_person", fn = _act_spin_kick},
		{title = "RB: back elbow", cam = &"side_view", fn = _act_back_elbow},
		{title = "RB: back elbow (first person)", cam = &"first_person", fn = _act_back_elbow},
		{title = "Grab, knee x3, grab, throw", cam = &"first_person", fn = _act_grab},
		{title = "Grab and throw (side view)", cam = &"side_view", fn = _act_grab},
		{title = "Stomp a downed enemy", cam = &"first_person", fn = _act_stomp},
		{title = "Pipe: pick up, 3 swings, throw", cam = &"first_person", fn = _act_pipe},
		{title = "Dodge right, quick turn", cam = &"first_person", fn = _act_dodge_turn},
		{title = "Stance: idle, walk, look down", cam = &"first_person", fn = _act_stance},
		{title = "Dodge back: B + back", cam = &"first_person", fn = _act_dodge_back},
		{title = "Block: sparring jab from the front", cam = &"first_person", fn = _act_block},
		{title = "Block: sparring jab (side view)", cam = &"side_view", fn = _act_block},
		{title = "Perfect block, then grab", cam = &"first_person", fn = _act_perfect_block},
		{title = "Parry on reaction (B 0.2 s into the wind-up), then grab", cam = &"first_person", fn = _act_parry_on_reaction},
		{title = "Grab anytime: an idle dummy, then a throw", cam = &"first_person", fn = _act_grab_idle},
		{title = "Grab looking level: knee, knee, LB lets go", cam = &"first_person", fn = _act_grab_level},
		{title = "Perfect block, then grab (side view)", cam = &"side_view", fn = _act_perfect_block},
		{title = "Guard break", cam = &"first_person", fn = _act_guard_break},
		{title = "Guard break (side view)", cam = &"side_view", fn = _act_guard_break},
		{title = "Flank hit lands", cam = &"first_person", fn = _act_flank_hit},
		{title = "Flank hit lands (side view, debug draw)", cam = &"side_view", fn = _act_flank_hit_debug},
		{title = "Hold view: grab, knee, knee, LB lets go (side view)", cam = &"side_view", fn = _act_grab_level},
		{title = "Hold view: walk in, grab, walk on, back off, LB lets go walking", cam = &"first_person", fn = _act_hold_walk},
		{title = "Hold view: walk in, grab, back off, LB lets go walking (side view)", cam = &"side_view", fn = _act_hold_walk},
		{title = "Hold view: looking 25° down, grab, knee, knee, throw", cam = &"first_person", fn = _act_hold_look_down},
		{title = "Hold view: looking 25° down (side view)", cam = &"side_view", fn = _act_hold_look_down},
		{title = "Hold view: a jab from the side breaks the hold", cam = &"first_person", fn = _act_hold_hit},
		{title = "Hold view: a jab breaks the hold (side view)", cam = &"side_view", fn = _act_hold_hit.bind(-1.0)},
	]
	for act in acts:
		var title: String = act.title
		if act_filter != "" and not _matches(title):
			continue
		await _reset(act.cam)
		caption.text = title
		print("=== %s  (f%d)" % [title, Engine.get_physics_frames()])
		var fn: Callable = act.fn
		await fn.call()
		await _wait_idle()
		await _ticks(45)
	caption.text = "done"
	await _ticks(10)
	print("\n".join(log_lines))
	get_tree().quit()


## Whether act `title` matches act_filter (any of its `|`-separated parts, ignoring case).
func _matches(title: String) -> bool:
	for part: String in act_filter.to_lower().split("|", false):
		if title.to_lower().contains(part):
			return true
	return false


# --- Acts ---------------------------------------------------------------------------


func _act_pppp() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	for i in 4:
		await _press(&"P", 2, 8)


## P · P, then mash: the body-blow flurry (moved here from P P · P after Game-boy's second
## playtest), ending in the shove.
func _act_flurry() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	await _press(&"P", 2)
	await _wait_until(func() -> bool: return player.parser.current != null and player.parser.frames_since_recovery >= 16)
	for i in 7:
		await _press(&"P", 2, 3)


## P P · P: a full turn and the back of the right fist; in first person the view spins with
## the body and lands back on the dummy.
func _act_backfist() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	await _look_to(0.0, 6)
	await _press(&"P", 2, 8)
	await _press(&"P", 2)
	await _wait_until(func() -> bool: return player.parser.current != null and player.parser.frames_since_recovery >= 16)
	await _press(&"P", 2)


func _act_kkk() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	for i in 3:
		await _press(&"K", 2, 10)


func _act_k_pause_k() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	await _press(&"K", 2)
	await _wait_until(func() -> bool: return player.parser.current != null and player.parser.frames_since_recovery >= 16)
	await _press(&"K", 2)


func _act_ppk() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	await _press(&"P", 2, 8)
	await _press(&"P", 2, 8)
	await _press(&"K", 2)


func _act_haymaker() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	await _press(&"P", Tuning.data.hold_frames + 10)


func _act_flying_kick() -> void:
	await _stage([Vector3(0, 0, -2.4)])
	await _press(&"JUMP", 2, 2)
	await _press(&"K", 2)


func _act_spin_kick() -> void:
	await _stage([Vector3(0, 0, -1.2), Vector3(0, 0, 1.2), Vector3(1.2, 0, 0)])
	await _press(&"JUMP", 2)
	await _wait_until(func() -> bool: return player.sim_velocity.y < 1.0)
	await _press(&"K", 2)


func _act_back_elbow() -> void:
	await _stage([Vector3(0, 0, 1.0)])
	await _look_to(0.0, 6)
	await _ticks(20)
	await _press(&"RB", 2)


func _act_grab() -> void:
	await _stage([Vector3(0, 0, -1.4), Vector3(0, 0, -3.6)])
	await _press(&"P", 2, 8)
	await _press(&"P", 2, 8)
	await _press(&"P", 2)
	await _wait_idle()
	await _press(&"GRAB", 2, 10)
	# Knees can't cancel into each other: press each one after the last ends.
	for i in 3:
		await _press(&"P", 2)
		await _wait_idle()
		await _ticks(4)
	await _press(&"GRAB", 2, 15)
	await _press(&"K", 2)


func _act_stomp() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	for i in 3:
		await _press(&"K", 2, 10)
	await _wait_idle()
	await _wait_until(func() -> bool: return dummies[0].is_downed(), 120)
	# Walk up to the body, then stomp.
	player.input.scripted_move = Vector2(0, 1)
	await _wait_until(
		func() -> bool:
			var d := dummies[0].get_chest_position() - player.global_position
			return Vector2(d.x, d.z).length() < 1.1,
		90
	)
	player.input.scripted_move = Vector2.ZERO
	await _ticks(4)
	await _press(&"K", 2)


func _act_pipe() -> void:
	await _stage([Vector3(0, 0, -1.6), Vector3(0, 0, -6.0)])
	var pipe := get_tree().get_first_node_in_group(&"weapon") as Weapon
	if pipe == null:
		return
	pipe.global_position = player.global_position + player.global_basis * Vector3(0, 0.1, -0.6)
	pipe.linear_velocity = Vector3.ZERO
	await _ticks(10)
	await _press(&"GRAB", 2, 16)
	for i in 3:
		await _press(&"P", 2, 10)
	await _wait_idle()
	dummies[0].set_post(PARK)
	await _ticks(20)
	await _press(&"GRAB", 2, 40)


func _act_dodge_turn() -> void:
	await _stage([Vector3(0, 0, -2.5)])
	player.input.scripted_move = Vector2(1, 0)
	await _press(&"DODGE", 2)
	player.input.scripted_move = Vector2.ZERO
	await _wait_idle()
	await _ticks(20)
	await _press(&"TURN", 2, 30)
	await _press(&"TURN", 2, 20)


## The relaxed stance in first person: idle looking level, a walk, then a look down at
## the player's own hands, legs and feet (45 degrees for a second, then 65, where the lead
## leg comes in) and back up.
func _act_stance() -> void:
	await _stage([Vector3(1.5, 0, -9.0)])
	await _look_to(0.0, 10)
	await _ticks(60)
	player.input.scripted_move = Vector2(0, 1)
	await _ticks(60)
	player.input.scripted_move = Vector2.ZERO
	await _wait_until(func() -> bool: return not player.is_walking(), 60)
	await _ticks(10)
	await _look_to(-45.0, 15)
	await _ticks(60)
	await _look_to(-65.0, 10)
	await _ticks(30)
	await _look_to(0.0, 15)
	await _ticks(20)


## B + back: the backstep, arms in the stance (neutral B blocks now).
func _act_dodge_back() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	await _look_to(0.0, 6)
	for i in 2:
		player.input.scripted_move = Vector2(0, -1)
		await _press(&"DODGE", 2)
		player.input.scripted_move = Vector2.ZERO
		await _wait_idle()
		await _ticks(40)


## Distance between the sparring dummy and the player at which its jab connects.
const SPAR_DIST := 0.95


## Hold B with the stick centered: the held block's guard.
func _hold_block() -> void:
	player.input.scripted_move = Vector2.ZERO
	player.input.push_down(&"DODGE")
	while player.input.queued() > 0:
		await get_tree().physics_frame


func _release_block() -> void:
	player.input.push_up(&"DODGE")
	while player.input.queued() > 0:
		await get_tree().physics_frame


## Throw `dummy`'s telegraphed jab now, from where it stands, and wait for it to be over
## (blocked, landed or missed).
func _jab(dummy: TrainingDummy) -> void:
	await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.FREE, 90)
	dummy.start_jab()
	await _wait_until(func() -> bool: return dummy.current_move == null, 90)


## Let `dummy` spar for one jab, due at once: it steps in to its jab distance (after a
## push-back, too), winds up and jabs. Returns once the jab has started.
func _spar_jab(dummy: TrainingDummy) -> void:
	dummy.sparring = true
	dummy.spar_in(0)
	await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.WINDUP, 120)
	dummy.sparring = false


## The guard held in front of a sparring dummy that starts 1.5 m away: it steps in and jabs
## every couple of seconds, each jab glancing off the guard (chip, guard meter, blockstun
## push-back) and the dummy recoiling; it steps back in for the next. P pressed early in
## the second blockstun punches back right after it, and with B still held the guard comes
## back up after the jab.
func _act_block() -> void:
	await _stage([Vector3(0, 0, -1.5)])
	await _look_to(0.0, 6)
	await _hold_block()
	var dummy := dummies[0]
	dummy.sparring = true
	dummy.spar_in(40)
	await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.WINDUP, 200)
	await _wait_until(func() -> bool: return player.state == CombatTypes.ActorState.BLOCKSTUN, 60)
	await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.WINDUP, 200)
	await _wait_until(func() -> bool: return player.state == CombatTypes.ActorState.BLOCKSTUN, 60)
	dummy.sparring = false
	await _ticks(3)
	await _press(&"P", 2)
	await _wait_until(func() -> bool: return player.state == CombatTypes.ActorState.ATTACK, 40)
	await _wait_until(func() -> bool: return player.state == CombatTypes.ActorState.BLOCK, 60)
	await _ticks(40)
	await _release_block()


## The guard raised just as the jab comes out: a perfect block (no chip, PARRY), the dummy
## staggers; drop the guard and grab it, then a knee.
func _act_perfect_block() -> void:
	await _stage([Vector3(0, 0, -SPAR_DIST)])
	await _look_to(0.0, 6)
	await _ticks(20)
	var dummy := dummies[0]
	dummy.start_jab()
	var startup := dummy.current_move.startup
	await _wait_until(func() -> bool: return dummy.move_frame >= startup - 7, 40)
	await _hold_block()
	await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.STAGGER, 30)
	await _ticks(6)
	await _release_block()
	await _press(&"GRAB", 2, 20)
	await _press(&"P", 2)
	await _wait_idle()
	await _ticks(20)


## B pressed on reaction: 12 frames (0.2 s) after the sparring jab's wind-up starts, a
## perfect block (Game-boy's second playtest: the window now covers a reaction), then a grab.
func _act_parry_on_reaction() -> void:
	await _stage([Vector3(0, 0, -SPAR_DIST)])
	await _look_to(0.0, 6)
	await _ticks(20)
	var dummy := dummies[0]
	dummy.start_jab()
	await _wait_until(func() -> bool: return dummy.move_frame >= 12, 40)
	await _hold_block()
	await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.STAGGER, 30)
	await _ticks(6)
	await _release_block()
	await _press(&"GRAB", 2, 20)
	await _press(&"K", 2)
	await _wait_idle()
	await _ticks(20)


## LB on a dummy just standing there (grab anytime, Game-boy's second playtest), a knee,
## then a throw.
func _act_grab_idle() -> void:
	await _stage([Vector3(0, 0, -1.1)])
	await _look_to(0.0, 6)
	await _ticks(10)
	await _press(&"GRAB", 2, 12)
	await _press(&"P", 2)
	await _wait_idle()
	await _ticks(6)
	await _press(&"K", 2)


## The hold view looking level (the other acts look 6 degrees down): LB on an idle dummy,
## two knees, then LB again lets go and the view eases back up.
func _act_grab_level() -> void:
	await _stage([Vector3(0, 0, -1.1)])
	await _look_to(0.0, 6)
	await _ticks(10)
	await _press(&"GRAB", 2, 20)
	for i in 2:
		await _press(&"P", 2)
		await _wait_idle()
		await _ticks(8)
	await _press(&"GRAB", 2, 30)


## The hold view on the move, looking level: walk up to an idle dummy and grab it without
## stopping, walk on with it, then back off and let go with LB while still walking. The
## lens eases into and out of the hold as standing (it bobbed and popped, M2 phase 3 review
## code-03).
func _act_hold_walk() -> void:
	await _stage([Vector3(0, 0, -2.6)])
	await _look_to(0.0, 6)
	player.input.scripted_move = Vector2(0, 1)
	await _wait_until(func() -> bool: return dummies[0].global_position.distance_to(player.global_position) < 1.15, 120)
	await _press(&"GRAB", 2, 40)
	player.input.scripted_move = Vector2(0, -1)
	await _ticks(20)
	await _press(&"GRAB", 2, 30)
	player.input.scripted_move = Vector2.ZERO
	await _ticks(20)


## The hold view looking 25 degrees down at the held body: the hold's pitch only brings the
## view down to grab_view_target_pitch_deg, so with the knees' own pitch the view still
## shows the street ahead (it stacked into a view of the own belly, review grab-06).
func _act_hold_look_down() -> void:
	await _stage([Vector3(0, 0, -1.1)])
	await _look_to(-25.0, 10)
	await _ticks(10)
	await _press(&"GRAB", 2, 20)
	for i in 2:
		await _press(&"P", 2)
		await _wait_idle()
		await _ticks(8)
	await _press(&"K", 2)
	await _wait_idle()
	await _look_to(-6.0, 10)


## A second dummy beside the player (on his right, or his left if `side` is -1, so the side
## view sees past it) jabs him while he holds the first, looking level: the hit tears the
## clinch apart, the body let go freezes with the hit's hitstop and staggers away instead
## of standing up through the bent-over view (review grab-02).
func _act_hold_hit(side: float = 1.0) -> void:
	await _stage([Vector3(0, 0, -1.1), Vector3(0.85 * side, 0, -0.2)])
	await _look_to(0.0, 6)
	await _ticks(10)
	await _press(&"GRAB", 2, 23)
	var jabber := dummies[1]
	jabber.start_jab()
	await _wait_until(func() -> bool: return jabber.current_move == null, 90)
	await _ticks(60)


## Jab after jab into the held guard, faster than it regenerates: the sparring dummy steps
## back in after each push-back and jabs as soon as it is out of its recoil. The meter
## empties on the fifth and the guard is knocked apart; B still held, the guard comes back
## up after the stagger. Let go, the next jab lands clean (and is pulled back out of the
## view after its hitstop).
func _act_guard_break() -> void:
	await _stage([Vector3(0, 0, -SPAR_DIST)])
	await _look_to(0.0, 6)
	await _hold_block()
	await _ticks(20)
	var dummy := dummies[0]
	for i in 6:
		await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.FREE, 90)
		await _spar_jab(dummy)
		await _wait_until(func() -> bool: return dummy.current_move == null, 60)
		if player.state == CombatTypes.ActorState.STAGGER:
			break
	await _wait_until(func() -> bool: return player.state == CombatTypes.ActorState.BLOCK, 90)
	await _ticks(20)
	await _release_block()
	await _wait_until(func() -> bool: return dummy.state == CombatTypes.ActorState.FREE, 90)
	await _spar_jab(dummy)
	await _wait_until(func() -> bool: return dummy.current_move == null, 60)
	await _ticks(30)


## Holding the guard but turned away from the dummy (90 degrees): its jab comes from outside
## the guard's arc and lands in full. B still held, the guard comes back up after the
## flinch, and turned back to the dummy it blocks the next jab.
func _act_flank_hit() -> void:
	await _stage([Vector3(0, 0, -SPAR_DIST)])
	await _look_to(0.0, 6)
	await _hold_block()
	await _ticks(20)
	await _turn_by(90.0, 12)
	await _ticks(10)
	await _jab(dummies[0])
	await _ticks(20)
	await _turn_by(-90.0, 12)
	await _ticks(10)
	await _spar_jab(dummies[0])
	await _wait_until(func() -> bool: return dummies[0].current_move == null, 60)
	await _ticks(30)
	await _release_block()
	await _ticks(20)


## The flank hit seen from the side with debug draw (F3) on: the cyan block arc swings
## away with the look, the dummy's label reads WINDUP, and the jab lands outside the arc.
func _act_flank_hit_debug() -> void:
	var hud := _hud()
	if hud:
		hud.call(&"set_debug_draw_enabled", true)
	await _act_flank_hit()
	if hud:
		hud.call(&"set_debug_draw_enabled", false)


func _hud() -> Node:
	for child in room.get_children():
		if child.has_method(&"set_debug_draw_enabled"):
			return child
	return null


## Turn the look by `degrees` (positive turns left) evenly over `ticks` physics ticks.
func _turn_by(degrees: float, ticks: int) -> void:
	var from := player.look_yaw
	for i in ticks:
		await get_tree().physics_frame
		player.look_yaw = wrapf(from + deg_to_rad(degrees) * float(i + 1) / ticks, -PI, PI)


# --- Harness ------------------------------------------------------------------------


## Turn the view to `pitch_deg` (negative looks down) evenly over `ticks` physics ticks.
func _look_to(pitch_deg: float, ticks: int) -> void:
	var from := player.look_pitch
	var to := deg_to_rad(pitch_deg)
	for i in ticks:
		await get_tree().physics_frame
		player.look_pitch = lerpf(from, to, float(i + 1) / ticks)


func _reset(cam: StringName) -> void:
	player.input.clear_queue()
	player.input.scripted_move = Vector2.ZERO
	player.parser.release(&"DODGE")
	player.reset_state()
	player.global_position = room.get(&"player_start")
	player.sim_velocity = Vector3.ZERO
	player.look_yaw = deg_to_rad(room.get(&"player_yaw_deg"))
	player.rotation.y = player.look_yaw
	player.look_pitch = deg_to_rad(-6.0)
	player.parser.reset_chain()
	player.parser.clear_buffer()
	if director:
		var guard := 0
		while director.get(&"mode") != cam and guard < 4:
			director.call(&"cycle")
			guard += 1
	await _ticks(2)


## Place dummies relative to the player (x right, -z ahead); the rest go far away. No dummy
## spars on its own (the block acts start and time the jabs themselves).
func _stage(posts: Array[Vector3]) -> void:
	for i in dummies.size():
		var d := dummies[i]
		d.sparring = false
		# Posts are in the player's frame (x right, -z ahead).
		var pos := player.global_position + player.global_basis * posts[i] if i < posts.size() else PARK + PARK_STEP * i
		var to_player := player.global_position - pos
		d.max_health = 500.0
		d.set_post(pos, atan2(-to_player.x, -to_player.z), true)
	await _ticks(20)


func _press(button: StringName, hold: int = 2, gap: int = 0) -> void:
	player.input.push_press(button, hold)
	player.input.push_wait(gap)
	while player.input.queued() > 0:
		await get_tree().physics_frame


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_until(condition: Callable, max_ticks: int = 400) -> void:
	for i in max_ticks:
		if condition.call():
			return
		await get_tree().physics_frame


func _wait_idle() -> void:
	await _wait_until(
		func() -> bool:
			return (
				player.input.queued() == 0
				and player.current_move == null
				and player.state in [CombatTypes.ActorState.FREE, CombatTypes.ActorState.GRABBING]
			),
		600
	)


func _build_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	caption = Label.new()
	caption.add_theme_font_size_override(&"font_size", 34)
	caption.add_theme_color_override(&"font_outline_color", Color.BLACK)
	caption.add_theme_constant_override(&"outline_size", 8)
	caption.position = Vector2(560, 120)
	layer.add_child(caption)
	add_child(layer)
