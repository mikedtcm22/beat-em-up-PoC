extends RefCounted
## The look acts of Milestone 4 (L0-bench) for the crowd bot (tests/bot/crowd_bot.gd): the Street Punk
## and the player's own limbs as the lens sees them, so a change of look is judged from the same
## frames before and after. Every title starts with "Look:". Record them with
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/<key> "Look:" 6
## (or one act: "Look: Punk face") and cut the stills and crops with
##   tools/look_sheets.sh captures/<key>/bot.avi captures/<key>/sheets
##
## Every act hides the bot's caption (it comes back when the act ends), freezes the AI, turns on god
## mode and seeds the comic effects' random generator (the same bursts every run). All motion is
## scripted: the player's own presses, the Punk's force_attack(), and for the strafe and the turntable
## the Punk's own rig played by hand (an actor on the AI's tick plays its idle every tick, so
## play_locomotion() on a frozen one is overwritten at once). The acts print, through look_rect.gd,
##   LOOK-MARK <slug> f<frame> <label>      a frame worth a still; `start` and `end` delimit the act
##   LOOK-RECT <slug> f<frame> <head|hands|body> x y w h   where the subject is, in 1600x900 pixels
## The slug is the act's number: c1 ... c13 (C12, the extremes, is F-motion's).
##
## | Act | Title | Shows |
## | C1 | Look: Punk face at 1 m | the Punk 1 m ahead, the view 8 degrees up, 3 s idle |
## | C2 | Look: Punk body at 1 m | the same at the default 6 degrees down, 3 s idle |
## | C3 | Look: Punk strafes at 1 m | a half circle at 1.0-1.3 m (the view follows), then a step in and out |
## | C4 | Look: Punk attacks at 1 m | its two-hit punch (jab, cross), then its shove, landing on the player |
## | C5 | Look: Punk reacts at 1 m | a jab (flinch and flash), P P P P (hook stagger, uppercut launch), the get-up, health 100/65/30%, then a jab finishes it (KO slump, blink-off) |
## | C6 | Look: distances | the Punk at 1, 2.5, 5 and 10 m |
## | C7 | Look: lineup | Punk, Kicker, Thug and Bruiser at 2.2 m, the street behind |
## | C8 | Look: own limbs | looking 45 degrees down: jab, cross, hook, front kick, block, walking; then 20 down (strikes, guard) and 65 down (walking) |
## | C9 | Look: street tour | the room's tour with a cast of the four archetypes standing in the street |
## | C10 | Look: turntable | free fly camera round the Punk at rest, in the guard and lying (mesh QA) |
## | C11 | Look: hold the Punk | grab, three knees, throw |
## | C13 | Look: Punk, impact frame off | C5 with the impact frame off |
## | P1 | Look: Perf, six art Punks | six art Punks and the autopilot for 30 s, frame times logged (A16); no marks, no rectangles |
## | W1 | Look: warm-up in the lens | a room's load run again, cold, in a viewport of its own (the crowd room, then the training room): the art warm-up's holder is in the camera's frustum on both frames it is drawn (LOOK-WARM lines); no marks, no rectangles |
##
## The Punk in every act wears the art (game/actors/art/punk_art.tres). The A/B between the four smoke
## GLBs is Tuning's Debug value look_punk_art_variant (0 punk.glb, 1 punk_rest, 2 punk_auto,
## 3 punk_auto_rest), through the bot's own argument: CAPTURE_ARGS="--tune=look_punk_art_variant=2"
## tools/capture_bot.sh ... "Look: Punk body at 1 m". Every act prints `LOOK-ART variant <n> <glb>` at
## its start, so a log says which Punk it recorded.
##
## Later packages add acts to this file (F-motion C12, P3-int): a new act is one entry of acts() and
## one function; use _begin(), _end(), LookRect.mark() and _watch() as these do.

const LookRect := preload("res://tests/bot/look_rect.gd")
const RoomActs := preload("res://tests/bot/acts/room_acts.gd")
const CrowdActs := preload("res://tests/bot/acts/crowd_acts.gd")

## The 1 m recipe: where the Punk stands (x right, y ahead, metres), and where it stands for its
## punches to land (the reach of its two-hit punch, as the Punk bot's "two-hit punch lands").
const CLOSE_M := 1.0
const HIT_M := 0.95
## The held Punk's distance (the combo bot's hold acts), the lineup's and the turntable's.
const HOLD_M := 1.1
const LINEUP_M := 2.2
## The view: pitch of the face shot (degrees, negative looks down), the default look of every act
## (combo_bot._reset), a level look and the look down at the player's own limbs.
const FACE_PITCH_DEG := 8.0
const DEFAULT_PITCH_DEG := -6.0
const LEVEL_PITCH_DEG := 0.0
const LIMBS_PITCH_DEG := -45.0
## C8's other two looks: where the guard and the strikes are in the view, and where the lead leg and
## the feet come in (the combo bot's stance act looks 65 degrees down for them).
const ARMS_PITCH_DEG := -20.0
const FEET_PITCH_DEG := -65.0
## Ticks to turn the view, to let a spawned body settle, and how long the idle is held (3 s).
const PITCH_TICKS := 10
const TURN_TICKS := 30
const SETTLE_TICKS := 30
const IDLE_TICKS := 180
## A held pose gets a mark this often (1 s).
const MARK_GAP_TICKS := 60
## The strafe: the arc (degrees), the nearest and farthest the Punk comes (m), how fast the view
## follows it (degrees a second), and the pause before the step in.
const STRAFE_ARC_DEG := 150.0
const STRAFE_NEAR_M := 1.0
const STRAFE_FAR_M := 1.3
const FOLLOW_DEG_PER_S := 90.0
const STEP_PAUSE_TICKS := 30
## The attacks: how long each may take (ticks) and how long it is watched after it.
const ATTACK_START_TICKS := 30
const ATTACK_MAX_TICKS := 240
const AFTER_ATTACK_TICKS := 40
## The reacts: a pause between the jab and the chain (the chain starts over after a wait), the frames
## between the chain's presses (the Punk bot's), how long a body may take to go down and get up,
## and how long each health look is held (1 s).
const REST_TICKS := 60
const CHAIN_GAP_TICKS := 8
const DOWN_MAX_TICKS := 120
const GETUP_MAX_TICKS := 300
const HEALTH_HOLD_TICKS := 60
const HEALTH_MARK_TICKS := 30
## The Punk's health for the reacts: enough to live through the jab and the chain (38 damage against
## its own 30), the little that one jab finishes at the end (the KO slump and blink-off), and how long
## the blink-off may take (ticks).
const SURVIVOR_HEALTH := 100.0
const FINISH_HEALTH := 5.0
const BLINK_MAX_TICKS := 600
const HEALTH_SHARES: Array[float] = [1.0, 0.65, 0.3]
## The distances act: the Punk's distances (m) and how long each is held (1.5 s).
const DISTANCES_M: Array[float] = [1.0, 2.5, 5.0, 10.0]
const DISTANCE_HOLD_TICKS := 90
## The lineup: the enemies left to right (bearing from the look in degrees, positive to the left) on
## an arc of LINEUP_M. The Bruiser is the widest, so it has the outer place.
const LINEUP: Array[Dictionary] = [
	{id = &"punk", bearing_deg = 33.0},
	{id = &"kicker", bearing_deg = 11.0},
	{id = &"thug", bearing_deg = -11.0},
	{id = &"bruiser", bearing_deg = -33.0},
]
const LINEUP_HOLD_TICKS := 180
## The own-limbs act: how long a held guard and the walk last, and the walk's marks.
const GUARD_TICKS := 40
const WALK_TICKS := 60
const WALK_MARK_TICKS := 20
## The street tour's cast: archetype and where it stands (x right, y ahead of the player's start, m).
## The first four ring the start for the tour's turn on the spot; the last two flank the lane the tour
## then walks.
const TOUR_CAST: Array[Dictionary] = [
	{id = &"punk", rel = Vector2(0.0, 3.5)},
	{id = &"kicker", rel = Vector2(-3.5, 0.0)},
	{id = &"thug", rel = Vector2(3.5, 0.0)},
	{id = &"bruiser", rel = Vector2(0.0, -3.5)},
	{id = &"punk", rel = Vector2(-2.2, 6.0)},
	{id = &"thug", rel = Vector2(2.4, 9.0)},
]
const TOUR_MARK_TICKS := 150
## The turntable: each stance's name and animation, the orbit's radius, the eye's and the aim's
## height above the Punk's feet (m), the orbit's length and the settle before it.
const TURNTABLE: Array[Dictionary] = [
	{name = &"rest", anim = &"idle", radius = 2.2, eye = 1.4, aim = 1.0},
	{name = &"guard", anim = &"block", radius = 2.2, eye = 1.4, aim = 1.0},
	{name = &"lying", anim = &"downed_back", radius = 1.8, eye = 1.3, aim = 0.25},
]
const ORBIT_QUARTER_TICKS := 120
const ORBIT_TICKS := ORBIT_QUARTER_TICKS * 4
const ORBIT_SETTLE_TICKS := 40
## Where the actors of the manually posed acts stand, in the acts' own frame (m ahead).
const POSED_M := 1.0
## The comic effects' random seed (the VFX bot's).
const VFX_SEED := 7
## The four smoke GLBs by Tuning's look_punk_art_variant (StreetPunk's art, then its ART_VARIANTS).
const PUNK_ARTS: Array[String] = ["punk", "punk_rest", "punk_auto", "punk_auto_rest"]
## The perf act's length (30 s of the autopilot's fight; the mixed six's is 30 s too).
const PERF_SIX_TICKS := 1800
## The warm-up act (W1): the rooms whose load it runs again, the size of the viewport each loads
## into (16:9, so its camera frames as the game's), the frames the warm-up's holder is drawn for
## (ToonMaterials.warm_up(): two) and the most frames the act waits for it to show and go.
const WARM_ROOMS: Array[Dictionary] = [
	{name = "crowd", scene = "res://game/level/crowd_room.tscn"},
	{name = "training", scene = "res://game/level/test_room.tscn"},
]
const WARM_VIEW_SIZE := Vector2i(320, 180)
const WARM_FRAMES := 2
const WARM_WAIT_FRAMES := 12


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Look: Punk face at 1 m", cam = &"first_person", slug = &"c1", fn = func() -> void: await _face(bot)},
		{title = "Look: Punk body at 1 m", cam = &"first_person", slug = &"c2", fn = func() -> void: await _body(bot)},
		{title = "Look: Punk strafes at 1 m", cam = &"first_person", slug = &"c3", fn = func() -> void: await _strafe(bot)},
		{title = "Look: Punk attacks at 1 m", cam = &"first_person", slug = &"c4", fn = func() -> void: await _attacks(bot)},
		{title = "Look: Punk reacts at 1 m", cam = &"first_person", slug = &"c5",
				fn = func() -> void: await _reacts(bot, "c5")},
		{title = "Look: distances", cam = &"first_person", slug = &"c6", fn = func() -> void: await _distances(bot)},
		{title = "Look: lineup", cam = &"first_person", slug = &"c7", fn = func() -> void: await _lineup(bot)},
		{title = "Look: own limbs", cam = &"first_person", slug = &"c8", fn = func() -> void: await _own_limbs(bot)},
		{title = "Look: street tour", cam = &"first_person", slug = &"c9", fn = func() -> void: await _tour(bot)},
		{title = "Look: turntable", cam = &"free_fly", slug = &"c10", fn = func() -> void: await _turntable(bot)},
		{title = "Look: hold the Punk", cam = &"first_person", slug = &"c11", fn = func() -> void: await _hold(bot)},
		{title = "Look: Punk, impact frame off", cam = &"first_person", slug = &"c13",
				fn = func() -> void: await _reacts(bot, "c13", false)},
		{title = "Look: Perf, six art Punks", cam = &"first_person", slug = &"p1", probe = true,
				fn = func() -> void: await _perf_six(bot)},
		{title = "Look: warm-up in the lens", cam = &"first_person", slug = &"w1", fn = func() -> void: await _warm_up(bot)},
	]


# --- The shared steps -------------------------------------------------------------------------


## The start of every act: the caption off (the bot sets its text before the act runs, so it is up
## for a frame or two of the act's slate), god mode, the AI frozen, the comic effects cleared and
## seeded.
static func _begin(bot: Node) -> void:
	bot.caption.visible = false
	bot.god()
	bot.freeze_ai(true)
	_log_art(bot)
	var vfx := bot.get_tree().get_first_node_in_group(VfxDirector.GROUP) as VfxDirector
	if vfx:
		vfx.clear()
		vfx.rng.seed = VFX_SEED


## `LOOK-ART variant <n> <glb>`: which of the four smoke GLBs the Punks of this run wear (Tuning's
## look_punk_art_variant; 0 is the scene's punk.glb), so a recording says what it recorded.
static func _log_art(bot: Node) -> void:
	var variant := clampi(Tuning.data.look_punk_art_variant, 0, PUNK_ARTS.size() - 1)
	bot.log_line("LOOK-ART variant %d %s" % [variant, PUNK_ARTS[variant]])


## The end of every act: the `end` mark and the caption back (the bot's own idle tail shows it).
static func _end(bot: Node, slug: String) -> void:
	LookRect.mark(bot, slug, "end")
	bot.caption.visible = true


## `ticks` of an idle held (`_idle_marks`), a mark with `subject`'s rectangles at its start and every
## MARK_GAP_TICKS, named <label>_t<tick>.
static func _idle_marks(bot: Node, slug: String, subject: CombatActor, ticks: int, label: String) -> void:
	var done := 0
	while true:
		LookRect.mark(bot, slug, "%s_t%03d" % [label, done], subject)
		if done >= ticks:
			return
		var step := mini(MARK_GAP_TICKS, ticks - done)
		await bot._ticks(step)
		done += step


## A coroutine that runs beside an act, until `run.running` is cleared, and marks what happens to
## `actor` (with its rectangles): every change of its state (`state_<name>`), each move it starts
## (`<move>_windup`) and gets to its first active frame (`<move>_strike`), and every hit it lands or
## takes (`<move>_hit` and `<move>_took`, and the frame after, `..._next`: the contact flash shows
## for a couple of frames). Start it without await.
static func _watch(bot: Node, slug: String, actor: CombatActor, run: Dictionary) -> void:
	var tree: SceneTree = bot.get_tree()
	var hits: Array[HitInfo] = []
	var on_hit := func(hit: HitInfo) -> void:
		if hit.attacker == actor or hit.victim == actor:
			hits.append(hit)
	CombatEvents.hit_landed.connect(on_hit)
	var state := actor.state
	var move: MoveData = null
	var struck := false
	var next_marks: Array[String] = []
	while run.running and is_instance_valid(actor):
		await tree.physics_frame
		if not run.running or not is_instance_valid(actor):
			break
		for label: String in next_marks:
			LookRect.mark(bot, slug, label, actor)
		next_marks.clear()
		if actor.state != state:
			state = actor.state
			LookRect.mark(bot, slug, "state_%s" % CombatTypes.state_name(state).to_lower(), actor)
		if actor.current_move != move:
			move = actor.current_move
			struck = false
			if move != null:
				LookRect.mark(bot, slug, "%s_windup" % move.id, actor)
		if move != null and not struck and actor.move_frame >= move.startup:
			struck = true
			LookRect.mark(bot, slug, "%s_strike" % move.id, actor)
		for hit: HitInfo in hits:
			var id: StringName = hit.move.id if hit.move != null else &"body"
			var label := "%s_%s" % [id, "hit" if hit.attacker == actor else "took"]
			LookRect.mark(bot, slug, label, actor)
			next_marks.append("%s_next" % label)
		hits.clear()
	CombatEvents.hit_landed.disconnect(on_hit)


## The Punk `rel` ahead of the player, standing in its idle, the AI frozen.
static func _punk(bot: Node, rel: Vector2) -> EnemyActor:
	return bot.spawn(&"punk", rel)


## Health for a Punk that is to live through what an act does to it (see SURVIVOR_HEALTH).
static func _survivor(punk: EnemyActor) -> void:
	punk.max_health = SURVIVOR_HEALTH
	punk.health = SURVIVOR_HEALTH


## Stand `punk` `rel` ahead of the player (x right, y ahead), facing him: the Punk bot's way of
## putting a body that has been knocked about back in front of the lens.
static func _place(bot: Node, punk: EnemyActor, rel: Vector2) -> void:
	var player: Node3D = bot.player
	var at := player.global_position + player.global_basis * Vector3(rel.x, 0.0, -rel.y)
	at.y = player.global_position.y
	var to := player.global_position - at
	punk.global_position = at
	punk.rotation.y = atan2(-to.x, -to.z)
	punk.sim_velocity = Vector3.ZERO


## Take `actor` off the physics tick, so an act can place it and play its rig by hand (_pose()).
static func _unplug(actor: CombatActor) -> void:
	actor.set_physics_process(false)


## Place the unplugged `actor` at `at`, facing `toward`, and advance its rig one tick: it walks the
## way it moved, as an enemy's own legs do (EnemyActor._animate_legs()).
static func _pose(actor: CombatActor, at: Vector3, toward: Vector3) -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	var velocity := (at - actor.global_position) / dt
	actor.global_position = at
	var to := toward - at
	actor.rotation.y = atan2(-to.x, -to.z)
	var forward := actor.get_forward()
	var right := forward.cross(Vector3.UP)
	actor.rig.play_locomotion(Vector2(velocity.dot(right), velocity.dot(forward)),
			velocity.length() / Tuning.data.move_speed)
	actor.rig.advance(dt)


## Turn the player's look toward `at`, by at most `deg_per_s` a second (the view that follows a
## circling enemy, as a player's does).
static func _follow(bot: Node, at: Vector3, deg_per_s: float) -> void:
	var step := deg_per_s / float(Engine.physics_ticks_per_second)
	var turn := clampf(bot.player.look_bearing_deg(at), -step, step)
	bot.player.look_yaw = wrapf(bot.player.look_yaw + deg_to_rad(turn), -PI, PI)


## The world position `radius` m from the player at `bearing` radians from `heading` (a yaw), 0
## ahead and positive to the left, at the player's height.
static func _ring(bot: Node, heading: float, bearing: float, radius: float) -> Vector3:
	var local := Vector3(-sin(bearing) * radius, 0.0, -cos(bearing) * radius)
	var at: Vector3 = bot.player.global_position + Basis(Vector3.UP, heading) * local
	at.y = bot.player.global_position.y
	return at


# --- C1, C2: standing --------------------------------------------------------------------------


static func _face(bot: Node) -> void:
	_begin(bot)
	var punk := _punk(bot, Vector2(0.0, CLOSE_M))
	await bot._look_to(FACE_PITCH_DEG, PITCH_TICKS)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "c1", "start")
	await _idle_marks(bot, "c1", punk, IDLE_TICKS, "idle")
	_end(bot, "c1")


static func _body(bot: Node) -> void:
	_begin(bot)
	var punk := _punk(bot, Vector2(0.0, CLOSE_M))
	await bot._look_to(DEFAULT_PITCH_DEG, PITCH_TICKS)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "c2", "start")
	await _idle_marks(bot, "c2", punk, IDLE_TICKS, "idle")
	_end(bot, "c2")


# --- C3: the strafe ----------------------------------------------------------------------------


## A half circle round the player, nearest in the middle (the Punk's own circle speed), the view
## following it; then a stop, a step in to the nearest and a step back (at the same walking pace: its
## own step-in speed is 0.1 s for this distance, too quick to see a stride).
static func _strafe(bot: Node) -> void:
	_begin(bot)
	var heading: float = bot.player.look_yaw
	var punk := _punk(bot, Vector2(0.0, STRAFE_FAR_M))
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "c3", "start")
	_unplug(punk)
	var arc := deg_to_rad(STRAFE_ARC_DEG)
	var length := arc * (STRAFE_NEAR_M + STRAFE_FAR_M) * 0.5
	var circle_ticks := ceili(length / Tuning.data.posture_circle_speed_mps * Engine.physics_ticks_per_second)
	var quarter := floori(circle_ticks / 4.0)
	for i in circle_ticks + 1:
		if i % quarter == 0:
			LookRect.mark(bot, "c3", "circle_%d_of_4" % floori(float(i) / quarter), punk)
		var t := float(i) / circle_ticks
		var radius := lerpf(STRAFE_FAR_M, STRAFE_NEAR_M, sin(PI * t))
		var at := _ring(bot, heading, -arc * t, radius)
		_pose(punk, at, bot.player.global_position)
		_follow(bot, at, FOLLOW_DEG_PER_S)
		await bot._ticks(1)
	# Stopped, then in and back along the line to the player.
	var from := punk.global_position
	var line_in: Vector3 = bot.player.global_position - from
	line_in.y = 0.0
	line_in = line_in.normalized()
	var step_ticks := ceili((STRAFE_FAR_M - STRAFE_NEAR_M) / Tuning.data.posture_circle_speed_mps * Engine.physics_ticks_per_second)
	for i in STEP_PAUSE_TICKS:
		_pose(punk, from, bot.player.global_position)
		await bot._ticks(1)
	LookRect.mark(bot, "c3", "step_in_start", punk)
	for i in step_ticks + 1:
		_pose(punk, from + line_in * (STRAFE_FAR_M - STRAFE_NEAR_M) * float(i) / step_ticks, bot.player.global_position)
		await bot._ticks(1)
	LookRect.mark(bot, "c3", "step_in_end", punk)
	for i in STEP_PAUSE_TICKS:
		_pose(punk, from + line_in * (STRAFE_FAR_M - STRAFE_NEAR_M), bot.player.global_position)
		await bot._ticks(1)
	for i in step_ticks + 1:
		_pose(punk, from + line_in * (STRAFE_FAR_M - STRAFE_NEAR_M) * (1.0 - float(i) / step_ticks), bot.player.global_position)
		await bot._ticks(1)
	LookRect.mark(bot, "c3", "step_back_end", punk)
	for i in STEP_PAUSE_TICKS:
		_pose(punk, from, bot.player.global_position)
		await bot._ticks(1)
	_end(bot, "c3")


# --- C4: attacks -------------------------------------------------------------------------------


## The Punk's two-hit punch (attack 0) and then its shove (attack 1), each landing on the player (god
## mode: the reaction plays, no damage). The watcher marks every wind-up, strike and landed hit.
static func _attacks(bot: Node) -> void:
	_begin(bot)
	var punk := _punk(bot, Vector2(0.0, HIT_M))
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "c4", "start")
	var run := {running = true}
	_watch(bot, "c4", punk, run)
	LookRect.mark(bot, "c4", "idle", punk)
	for index in 2:
		punk.force_attack(index)
		# It starts on the next control tick; the second attack begins from RECOVER, so wait for the
		# wind-up before waiting for the end.
		await bot._wait_until(func() -> bool: return punk.ai_state == EnemyActor.AiState.WINDUP, ATTACK_START_TICKS)
		await bot._wait_until(func() -> bool: return punk.ai_state == EnemyActor.AiState.RECOVER, ATTACK_MAX_TICKS)
		await bot._ticks(AFTER_ATTACK_TICKS)
	run.running = false
	_end(bot, "c4")


# --- C5, C13: reactions ------------------------------------------------------------------------


## The player's jab on the Punk (a flinch, the contact flash), a pause, then P P P P (the jab again,
## the hook's stagger, the uppercut's launch), the Punk down and getting up; then its health looks
## at 100, 65 and 30% held a second each, and a jab on what is left of it: the KO slump and the
## blink-off (J10). `impact_frame` false is C13: the finisher's ink print off, so what the Punk does
## at the hit is not covered.
static func _reacts(bot: Node, slug: String, impact_frame: bool = true) -> void:
	_begin(bot)
	if not impact_frame:
		bot.tune(&"impact_frame_enabled", false)
	var punk := _punk(bot, Vector2(0.0, CLOSE_M))
	_survivor(punk)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, slug, "start")
	var run := {running = true}
	_watch(bot, slug, punk, run)
	LookRect.mark(bot, slug, "idle", punk)
	await bot._press(&"P", 2)
	await bot._wait_idle()
	await bot._ticks(REST_TICKS)
	for i in 4:
		await bot._press(&"P", 2, CHAIN_GAP_TICKS)
	await bot._wait_until(func() -> bool: return punk.is_downed(), DOWN_MAX_TICKS)
	await bot._wait_until(func() -> bool:
			return punk.state == CombatTypes.ActorState.FREE and punk.current_move == null, GETUP_MAX_TICKS)
	await bot._ticks(SETTLE_TICKS)
	# The launch left it a few metres off: back in front of the lens for the health looks and the jab.
	_place(bot, punk, Vector2(0.0, CLOSE_M))
	await bot._ticks(SETTLE_TICKS)
	for share: float in HEALTH_SHARES:
		punk.health = punk.max_health * share
		CombatEvents.health_changed.emit(punk, punk.health, punk.max_health)
		await bot._ticks(HEALTH_MARK_TICKS)
		LookRect.mark(bot, slug, "health_%d" % roundi(share * 100.0), punk)
		await bot._ticks(HEALTH_HOLD_TICKS - HEALTH_MARK_TICKS)
	# A jab finishes it. The Punk is freed once it has blinked off, so the wait holds a WeakRef.
	punk.health = FINISH_HEALTH
	CombatEvents.health_changed.emit(punk, punk.health, punk.max_health)
	var ref: WeakRef = weakref(punk)
	await bot._press(&"P", 2)
	await bot._wait_until(func() -> bool: return ref.get_ref() == null, BLINK_MAX_TICKS)
	run.running = false
	_end(bot, slug)


# --- C6, C7: distance and company --------------------------------------------------------------


## The Punk at each of DISTANCES_M in turn, the view level, standing.
static func _distances(bot: Node) -> void:
	_begin(bot)
	await bot._look_to(LEVEL_PITCH_DEG, PITCH_TICKS)
	LookRect.mark(bot, "c6", "start")
	for distance: float in DISTANCES_M:
		bot.clear_enemies()
		var punk := _punk(bot, Vector2(0.0, distance))
		await bot._ticks(SETTLE_TICKS)
		await bot._ticks(DISTANCE_HOLD_TICKS - SETTLE_TICKS)
		LookRect.mark(bot, "c6", "d%s_m" % str(distance).replace(".", "_"), punk)
	_end(bot, "c6")


## The four archetypes on an arc of LINEUP_M, facing the player, the view level.
static func _lineup(bot: Node) -> void:
	_begin(bot)
	var punk: EnemyActor = null
	for entry: Dictionary in LINEUP:
		var bearing := deg_to_rad(entry.bearing_deg)
		var enemy: EnemyActor = bot.spawn(entry.id, Vector2(-sin(bearing), cos(bearing)) * LINEUP_M)
		if entry.id == &"punk":
			punk = enemy
	await bot._look_to(LEVEL_PITCH_DEG, PITCH_TICKS)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "c7", "start")
	await _idle_marks(bot, "c7", punk, LINEUP_HOLD_TICKS, "lineup")
	_end(bot, "c7")


# --- C8: the player's own limbs ----------------------------------------------------------------


## The player's own arms and legs, nothing in front of him, in three looks. LIMBS_PITCH_DEG (the plan's
## 45 degrees down): a jab, cross and hook (one chain), a front kick, the guard held, then walking. At
## 45 degrees the guard and the strikes are mostly above the view and only the kick's leg is in it, so
## ARMS_PITCH_DEG (20 down) repeats the chain and the guard where the arms are in the view, and
## FEET_PITCH_DEG (65 down) idles and walks where the lead leg and the feet come in. The marks follow
## the player's own moves; the rectangles are his fists and the legs and feet his lens sees.
static func _own_limbs(bot: Node) -> void:
	_begin(bot)
	await bot._look_to(LIMBS_PITCH_DEG, PITCH_TICKS + 5)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "c8", "start")
	var run := {running = true}
	_watch(bot, "c8", bot.player, run)
	LookRect.mark(bot, "c8", "idle", bot.player)
	await bot._ticks(MARK_GAP_TICKS)
	await _limbs_strikes(bot)
	await bot._press(&"K", 2)
	await bot._wait_idle()
	await bot._ticks(CHAIN_GAP_TICKS)
	await _limbs_guard(bot, "guard")
	await _limbs_walk(bot, "walk")
	# The walk went most of the way to the end of the lane: turn round, so the last walk has room.
	await bot._turn_by(180.0, TURN_TICKS)
	await bot._look_to(ARMS_PITCH_DEG, PITCH_TICKS + 5)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "c8", "arms_idle", bot.player)
	await _limbs_strikes(bot)
	await _limbs_guard(bot, "arms_guard")
	await bot._look_to(FEET_PITCH_DEG, PITCH_TICKS + 5)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "c8", "feet_idle", bot.player)
	await _limbs_walk(bot, "feet_walk")
	run.running = false
	_end(bot, "c8")


## A jab, a cross and a hook (one chain), then idle again.
static func _limbs_strikes(bot: Node) -> void:
	for i in 3:
		await bot._press(&"P", 2, CHAIN_GAP_TICKS)
	await bot._wait_idle()
	await bot._ticks(CHAIN_GAP_TICKS)


## The guard held GUARD_TICKS (marked at its end as `label`), then let go.
static func _limbs_guard(bot: Node, label: String) -> void:
	await bot._hold_block()
	await bot._ticks(GUARD_TICKS)
	LookRect.mark(bot, "c8", label, bot.player)
	await bot._release_block()
	await bot._ticks(CHAIN_GAP_TICKS)


## Walking forward WALK_TICKS, marked every WALK_MARK_TICKS as <label>_t<tick>.
static func _limbs_walk(bot: Node, label: String) -> void:
	bot.player.input.scripted_move = Vector2(0.0, 1.0)
	for i in WALK_TICKS:
		if i % WALK_MARK_TICKS == 0:
			LookRect.mark(bot, "c8", "%s_t%03d" % [label, i], bot.player)
		await bot._ticks(1)
	bot.player.input.scripted_move = Vector2.ZERO
	await bot._ticks(WALK_MARK_TICKS)


# --- C9: the street ----------------------------------------------------------------------------


## The room's tour (a turn on the spot, along the lane, looks into the doorways and the alleys) with
## TOUR_CAST standing in the street, a mark every TOUR_MARK_TICKS.
static func _tour(bot: Node) -> void:
	_begin(bot)
	for entry: Dictionary in TOUR_CAST:
		bot.spawn(entry.id, entry.rel)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "c9", "start")
	var run := {running = true}
	_ticker(bot, "c9", run)
	await RoomActs._tour(bot)
	run.running = false
	_end(bot, "c9")


## A coroutine that marks every TOUR_MARK_TICKS until `run.running` is cleared (no subject: the
## street has no single one).
static func _ticker(bot: Node, slug: String, run: Dictionary) -> void:
	var ticks := 0
	while run.running:
		await bot._ticks(1)
		ticks += 1
		if run.running and ticks % TOUR_MARK_TICKS == 0:
			LookRect.mark(bot, slug, "tour_t%04d" % ticks)


# --- C10: the turntable ------------------------------------------------------------------------


## The free fly camera once round the Punk (a full turn, a mark every quarter), at rest, in the
## guard and lying. For the mesh: nothing here is first person.
static func _turntable(bot: Node) -> void:
	_begin(bot)
	var punk := _punk(bot, Vector2(0.0, POSED_M))
	_unplug(punk)
	var camera := bot.director.free_fly_camera as Camera3D
	await bot._ticks(1)
	LookRect.mark(bot, "c10", "start")
	for stance: Dictionary in TURNTABLE:
		punk.rig.play(stance.anim, 0.0)
		for i in ORBIT_SETTLE_TICKS:
			punk.rig.advance(1.0 / Engine.physics_ticks_per_second)
			await bot._ticks(1)
		var yaw: float = punk.rotation.y
		var feet := punk.global_position
		for i in ORBIT_TICKS + 1:
			if i % ORBIT_QUARTER_TICKS == 0:
				LookRect.mark(bot, "c10", "%s_q%d" % [stance.name, 90 * floori(float(i) / ORBIT_QUARTER_TICKS)], punk)
			var angle := TAU * float(i) / ORBIT_TICKS
			var eye := feet + Basis(Vector3.UP, yaw) * Vector3(sin(angle) * stance.radius, stance.eye, -cos(angle) * stance.radius)
			camera.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(feet + Vector3(0.0, stance.aim, 0.0), Vector3.UP)
			punk.rig.advance(1.0 / Engine.physics_ticks_per_second)
			await bot._ticks(1)
	_end(bot, "c10")


# --- C11: hold ---------------------------------------------------------------------------------


## The player grabs the Punk 1.1 m ahead and knees it three times (the third lets go: Tuning's
## max_knees), grabs it again and throws it; the act waits for the Punk to be down.
static func _hold(bot: Node) -> void:
	_begin(bot)
	var punk := _punk(bot, Vector2(0.0, HOLD_M))
	_survivor(punk)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "c11", "start")
	var run := {running = true}
	_watch(bot, "c11", punk, run)
	LookRect.mark(bot, "c11", "idle", punk)
	await bot._press(&"GRAB", 2, 20)
	for i in 3:
		await bot._press(&"P", 2)
		await bot._wait_idle()
		await bot._ticks(CHAIN_GAP_TICKS)
	await bot._wait_until(func() -> bool: return punk.state == CombatTypes.ActorState.FREE, GETUP_MAX_TICKS)
	await bot._press(&"GRAB", 2, 20)
	await bot._press(&"K", 2)
	await bot._wait_until(func() -> bool: return punk.is_downed(), DOWN_MAX_TICKS)
	await bot._ticks(MARK_GAP_TICKS)
	run.running = false
	_end(bot, "c11")


# --- P1: the perf act ----------------------------------------------------------------------------


## M4-plan A16's perf act: six art Punks (the existing "Perf, six with ragdolls" spawns a mixed six)
## walk in from the six surround points and the autopilot fights them for PERF_SIX_TICKS, a Punk
## walking in whenever one falls; god mode. It reuses crowd_acts.gd's frame sampler and report: the
## PERF lines (the whole run, each spawn and each fall) are the measure, wall-clock times, so run it in a
## window that is not recording (tools/perf_compare.sh --act "Look: Perf, six art Punks"). The art is
## drawn by the engine, never measured with SkinnedView here (A4): the probe is the proxies'.
static func _perf_six(bot: Node) -> void:
	bot.god()
	_log_art(bot)
	var run := {running = true, ms = PackedFloat32Array(), stamp = PackedFloat64Array(), spawns = [], downs = PackedFloat64Array()}
	CrowdActs._sample_frames(bot, run)  # a coroutine of its own: it runs beside the act until `running` is cleared
	for point: int in bot.SURROUND_POINTS:
		bot.spawn_at_point(&"punk", point)
		await bot._ticks(CrowdActs.SPAWN_GAP_FRAMES)
	bot.keep_alive(bot.SURROUND_POINTS.size(), &"punk")
	bot.pilot.enabled = true
	await bot._ticks(PERF_SIX_TICKS)
	run.running = false
	await bot.get_tree().process_frame
	await bot.get_tree().process_frame
	CrowdActs._report_perf(bot, run)


# --- W1: the load-time warm-up in the lens ------------------------------------------------------


## slice-g1-03: the art warm-up (RoomKit.warm_up_art(), ToonMaterials.warm_up()) draws the skinned
## toon variant and every hull once at a room's load, which does nothing unless what it draws is in
## the camera's frustum on those frames. It was placed from the camera before the camera's first
## update, 1.2 m under the floor and behind the view, and so never drawn. A room's load is cold only
## once per run, so the act runs it again: the warm-up's two once-per-run flags are cleared and each
## of WARM_ROOMS loads afresh into a SubViewport of its own (its own world, so nothing of the bot's
## room is touched and the recording's view is the bot's camera still), its camera, riding that room's
## own player, as new as at the game's start. Every frame the holder is drawn (the frame_pre_draw before it), the skinned ArtBody's
## box and the five hull boxes are tested against that camera's frustum. Prints per room
##   LOOK-WARM <room> f<frame> holder (x y z) camera (x y z): skinned <in>/<n> hulls <in>/<n>
## for each frame, then the line to quote
##   LOOK-WARM <room>: <OK|FAIL> ...
## and nothing at all headless (the warm-up draws nothing there).
static func _warm_up(bot: Node) -> void:
	_begin(bot)
	LookRect.mark(bot, "w1", "start")
	if DisplayServer.get_name() == "headless":
		bot.log_line("LOOK-WARM skipped: headless, the warm-up draws nothing without a window")
	else:
		for room: Dictionary in WARM_ROOMS:
			await _warm_up_room(bot, room.name, room.scene)
	_end(bot, "w1")


## One room's cold load, watched (see _warm_up()).
static func _warm_up_room(bot: Node, label: String, scene: String) -> void:
	var tree: SceneTree = bot.get_tree()
	var view := SubViewport.new()
	view.size = WARM_VIEW_SIZE
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	bot.add_child(view)
	# A room loaded at the game's start is built before the first frame's process step, where every
	# camera is still unplaced: load this one from a physics frame, which runs before the process step
	# of its frame, not from a process_frame (the step has begun, and the camera would be placed before
	# the warm-up first looks at it).
	await tree.physics_frame
	ToonMaterials._warmed = false
	ToonMaterials._art_warmed = false
	var room := (load(scene) as PackedScene).instantiate() as Node3D
	view.add_child(room)
	# The room's own director finds the player by group and the bot's room comes first in the tree:
	# hand it this room's player, as the game's start has (the camera is not updated before the next
	# frame, so it is as cold as the game's).
	var player := room.get(&"player") as PlayerCharacter
	for child: Node in room.get_children():
		if child is CameraDirector and player != null:
			(child as CameraDirector).player = player
			(child as CameraDirector).first_person_camera.player = player
	var drawn: Array[Dictionary] = []
	var hidden := 0
	var sane := false
	for i: int in WARM_WAIT_FRAMES:
		await RenderingServer.frame_pre_draw
		var holder := room.get_node_or_null(NodePath(ToonMaterials._WARM_NAME)) as Node3D
		var camera := view.get_camera_3d()
		if holder == null or holder.is_queued_for_deletion() or camera == null:
			if not drawn.is_empty():
				break
			continue
		sane = sane or _frustum_sane(camera)
		if not holder.is_visible_in_tree():
			hidden += 1
			continue
		var frame := _warm_frame(holder, camera)
		drawn.append(frame)
		bot.log_line("LOOK-WARM %s f%d holder %s camera %s: skinned %d/%d hulls %d/%d" % [
				label, Engine.get_process_frames(), _v(holder.global_position), _v(camera.global_position),
				frame.skinned_in, frame.skinned, frame.hulls_in, frame.hulls])
	var skinned_in := 0
	var skinned := 0
	var hulls_in := 0
	var hulls := 0
	for frame: Dictionary in drawn:
		skinned_in += frame.skinned_in
		skinned += frame.skinned
		hulls_in += frame.hulls_in
		hulls += frame.hulls
	var ok := sane and drawn.size() >= WARM_FRAMES and skinned > 0 and hulls > 0 and skinned_in == skinned and hulls_in == hulls
	bot.log_line("LOOK-WARM %s: %s the holder's skinned ArtBody AABB (%d of %d) and hull boxes (%d of %d) are in the camera frustum on %d frames it is drawn (%d expected; %d hidden before it was placed; frustum test sane: %s)" % [
			label, "OK" if ok else "FAIL", skinned_in, skinned, hulls_in, hulls, drawn.size(), WARM_FRAMES, hidden, sane])
	view.queue_free()
	await tree.process_frame
	await tree.process_frame


## What of the holder's meshes (the skinned art's, the hull boxes') are in `camera`'s frustum now:
## `{skinned_in, skinned, hulls_in, hulls}`: the art meshes of the skeleton's copy (group
## HumanoidRig.ART_GROUP; its hidden view proxies are not counted) and the boxes under the holder.
static func _warm_frame(holder: Node3D, camera: Camera3D) -> Dictionary:
	var planes := camera.get_frustum()
	var out := {skinned_in = 0, skinned = 0, hulls_in = 0, hulls = 0}
	for node: Node in holder.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var inside := _in_frustum(mesh.global_transform * mesh.get_aabb(), planes)
		if mesh.is_in_group(HumanoidRig.ART_GROUP):
			out.skinned += 1
			out.skinned_in += int(inside)
		elif mesh.get_parent() == holder:
			out.hulls += 1
			out.hulls_in += int(inside)
	return out


## True unless every corner of `box` lies outside one plane of a camera's frustum (the planes face
## out), so a box that is wholly in view, or only partly, or just near it, is in.
static func _in_frustum(box: AABB, planes: Array[Plane]) -> bool:
	for plane: Plane in planes:
		var outside := true
		for i: int in 8:
			if not plane.is_point_over(box.position + box.size * Vector3(float(i & 1), float((i >> 1) & 1), float((i >> 2) & 1))):
				outside = false
				break
		if outside:
			return false
	return true


## The frustum test's own check: a speck 2 m dead ahead of `camera` is in, one 2 m behind it is not.
static func _frustum_sane(camera: Camera3D) -> bool:
	var planes := camera.get_frustum()
	var ahead := camera.global_position - camera.global_basis.z * 2.0
	var behind := camera.global_position + camera.global_basis.z * 2.0
	return _in_frustum(AABB(ahead, Vector3.ZERO), planes) and not _in_frustum(AABB(behind, Vector3.ZERO), planes)


static func _v(v: Vector3) -> String:
	return "(%.2f %.2f %.2f)" % [v.x, v.y, v.z]
