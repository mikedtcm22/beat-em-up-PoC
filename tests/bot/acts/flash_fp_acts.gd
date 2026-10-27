extends RefCounted
## The contact flash in first person, measured (Milestone 4, P3-flash): feel questions 1 and 2 of
## M4-plan Part C section 8 with the art Punk in the lens. Each act plays one scenario several times,
## once per setting of the two FP feel tunables (Tuning hit_flash_fp_max_share and
## hit_flash_finisher_radius_mult), the first pass always "today" (0 and 1.0), and prints for every
## contact flash the share of the frame it whitens:
##   FLASH-FP <slug> <scenario> <setting> n<k> <move> <tier> depth=<m> radius=<m> cap=<share>
##            disc=<share> disc_capped=<share> white=<share> base=<share> flash=<share>
## `white` is the share of the frame's pixels that are white (look_probe's WHITE_LEVEL) in a frame the
## flash is drawn in; `base` the same in the frame after the flash ended (the HUD, the Punk's highlight,
## the comic burst: what is white without the flash); `flash` = white - base. `disc` is what the flash's
## outer disc covers on a surface at the flash point's depth by the shader's own math
## (HumanoidRig.flash_view_share()), `disc_capped` after the cap. Each pass ends with a
## `FLASH-FP-SUM` line (hits, the largest and the mean `flash`, how many flashes were over 5% and 10%).
## Every title starts with "Look: flash share"; the crowd bot loads this file by name. Record one act per
## process, as for the other look acts:
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/p3flash/hold "Look: flash share, hold knees" 6
##
## | Act | Title | Shows |
## | FF1 | Look: flash share, jab and flurry | the player's jab on the Punk at 1 m (the reference: L3), then the body-blow flurry (grab-05's sibling, hit-01: P, then seven P at 8.6 Hz) |
## | FF2 | Look: flash share, hold knees | the player grabs the Punk 1.1 m ahead and knees it three times (grab-05) |
## | FF3 | Look: flash share, haymaker and finishers | the haymaker (a held P, r3look-05) and the P P P P chain's uppercut |

const LookRect := preload("res://tests/bot/look_rect.gd")
const LookProbe := preload("res://tests/bot/look_probe.gd")

## Where the Punk stands (x right, y ahead, metres): the jab's (the 1 m recipe), the flurry's and the
## haymaker's (the combo bot's), the hold's (C11's).
const JAB_M := 1.0
const FLURRY_M := 1.6
const HAYMAKER_M := 1.6
const HOLD_M := 1.1
## The Punk lives through everything an act does to it.
const SURVIVOR_HEALTH := 5000.0
const DEFAULT_PITCH_DEG := -6.0
const PITCH_TICKS := 10
const SETTLE_TICKS := 30
const VFX_SEED := 7
## The ticks a pass keeps watching after the scenario, for a late flash (a finisher waits out the
## impact frame) and the last baseline frame.
const AFTER_TICKS := 40
## A hit whose flash never shows (a hit that armor or hit_flash_frames 0 spent) is given up on after this
## many ticks.
const PENDING_MAX_TICKS := 90
## Every Nth pixel of a row and a column is counted.
const SAMPLE_STEP := 2
## The shares past which a flash is counted as big, in the sum line.
const BIG_SHARES: Array[float] = [0.05, 0.10]
## The frames of a flurry's second hit on: the combo bot's flurry waits for the first move to have
## recovered this long.
const FLURRY_WAIT_FRAMES := 16
const FLURRY_PRESSES := 7
const HOLD_KNEES := 3
## The P P P P chain's gaps (test_hit_flash.gd's): the third press waits longer, so the fourth is the
## uppercut, the finisher.
const CHAIN_GAP_TICKS := 8
const CHAIN_FINISHER_GAP_TICKS := 24
## The settings of each act (a pass each): the cap's share of the view and the finisher's radius
## multiple. The first is always today's.
const JAB_SETTINGS: Array[Dictionary] = [
	{label = "today", share = 0.0, mult = 1.0},
	{label = "cap06", share = 0.06, mult = 1.0},
]
const FLURRY_SETTINGS: Array[Dictionary] = [
	{label = "today", share = 0.0, mult = 1.0},
	{label = "cap03", share = 0.03, mult = 1.0},
	{label = "cap06", share = 0.06, mult = 1.0},
	{label = "cap10", share = 0.10, mult = 1.0},
]
const HOLD_SETTINGS: Array[Dictionary] = [
	{label = "today", share = 0.0, mult = 1.0},
	{label = "cap03", share = 0.03, mult = 1.0},
	{label = "cap06", share = 0.06, mult = 1.0},
	{label = "cap10", share = 0.10, mult = 1.0},
]
const FINISHER_SETTINGS: Array[Dictionary] = [
	{label = "today", share = 0.0, mult = 1.0},
	{label = "mult15", share = 0.0, mult = 1.5},
	{label = "mult20", share = 0.0, mult = 2.0},
	{label = "mult30", share = 0.0, mult = 3.0},
]


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Look: flash share, jab and flurry", cam = &"first_person", slug = &"ff1",
				fn = func() -> void: await _jab_and_flurry(bot)},
		{title = "Look: flash share, hold knees", cam = &"first_person", slug = &"ff2",
				fn = func() -> void: await _hold(bot)},
		{title = "Look: flash share, haymaker and finishers", cam = &"first_person", slug = &"ff3",
				fn = func() -> void: await _finishers(bot)},
	]


# --- The acts ---------------------------------------------------------------------------------


static func _jab_and_flurry(bot: Node) -> void:
	await _scenario(bot, "ff1", "jab", JAB_M, JAB_SETTINGS, _jab)
	await _scenario(bot, "ff1", "flurry", FLURRY_M, FLURRY_SETTINGS, _flurry)
	_end(bot, "ff1")


static func _hold(bot: Node) -> void:
	await _scenario(bot, "ff2", "hold", HOLD_M, HOLD_SETTINGS, _knees)
	_end(bot, "ff2")


static func _finishers(bot: Node) -> void:
	await _scenario(bot, "ff3", "haymaker", HAYMAKER_M, FINISHER_SETTINGS, _haymaker)
	await _scenario(bot, "ff3", "chain", HAYMAKER_M, FINISHER_SETTINGS, _chain)
	_end(bot, "ff3")


## One scenario, a pass for each of `settings`: the room is reset as an act's start does it, the
## tunables are set, a Punk `dist` ahead is hit as `play` says, and every flash it takes is measured.
static func _scenario(bot: Node, slug: String, name: String, dist: float, settings: Array[Dictionary],
		play: Callable) -> void:
	for setting: Dictionary in settings:
		await bot._reset(&"first_person")
		bot.caption.visible = false
		bot.god()
		bot.freeze_ai(true)
		bot.tune(&"hit_flash_fp_max_share", setting.share)
		bot.tune(&"hit_flash_finisher_radius_mult", setting.mult)
		var vfx := bot.get_tree().get_first_node_in_group(VfxDirector.GROUP) as VfxDirector
		if vfx:
			vfx.clear()
			vfx.rng.seed = VFX_SEED
		bot.log_line("FLASH-FP-CONFIG %s %s %s cap=%.3f mult=%.2f" % [slug, name, setting.label, setting.share, setting.mult])
		var punk: EnemyActor = bot.spawn(&"punk", Vector2(0.0, dist))
		punk.max_health = SURVIVOR_HEALTH
		punk.health = SURVIVOR_HEALTH
		await bot._look_to(DEFAULT_PITCH_DEG, PITCH_TICKS)
		await bot._ticks(SETTLE_TICKS)
		LookRect.mark(bot, slug, "%s_%s_start" % [name, setting.label], punk)
		var run := {running = true, rows = [] as Array[Dictionary]}
		_meter(bot, slug, "%s %s" % [name, setting.label], punk, run)
		await play.call(bot, punk)
		await bot._wait_idle()
		await bot._ticks(AFTER_TICKS)
		run.running = false
		await bot._ticks(2)
		_sum(bot, slug, name, setting.label, run.rows)


static func _end(bot: Node, slug: String) -> void:
	LookRect.mark(bot, slug, "end")
	bot.caption.visible = true


# --- The scenarios ----------------------------------------------------------------------------


## The player's jab on the Punk (T5's, the 1 m reference).
static func _jab(bot: Node, _punk: EnemyActor) -> void:
	await bot._press(&"P", 2)


## P, then seven P three ticks apart once the first has recovered (the combo bot's flurry): the
## body blows at 8.6 Hz of hit-01.
static func _flurry(bot: Node, _punk: EnemyActor) -> void:
	await bot._press(&"P", 2)
	await bot._wait_until(func() -> bool:
		return bot.player.parser.current != null and bot.player.parser.frames_since_recovery >= FLURRY_WAIT_FRAMES)
	for i in FLURRY_PRESSES:
		await bot._press(&"P", 2, 3)


## Grab, then a knee each time the last has ended (C11's hold).
static func _knees(bot: Node, _punk: EnemyActor) -> void:
	await bot._press(&"GRAB", 2, 20)
	for i in HOLD_KNEES:
		await bot._press(&"P", 2)
		await bot._wait_idle()
		await bot._ticks(CHAIN_GAP_TICKS)


## A held P, released a little past the charge (the combo bot's haymaker).
static func _haymaker(bot: Node, _punk: EnemyActor) -> void:
	await bot._press(&"P", Tuning.data.hold_frames + 10)


## Four presses, the third followed by a longer gap: jab, jab, hook, uppercut (a finisher).
static func _chain(bot: Node, _punk: EnemyActor) -> void:
	for i in 4:
		bot.player.input.push_press(&"P", 2)
		bot.player.input.push_wait(CHAIN_FINISHER_GAP_TICKS if i == 2 else CHAIN_GAP_TICKS)
	while bot.player.input.queued() > 0:
		await bot.get_tree().physics_frame


# --- The meter --------------------------------------------------------------------------------


## Runs beside a scenario until `run.running` is cleared (start it without await): each hit on
## `victim` waits for its contact flash to show, and then the frame that draws it and the frame after
## are grabbed (_sample()). `run.rows` collects the measurements.
static func _meter(bot: Node, slug: String, tag: String, victim: CombatActor, run: Dictionary) -> void:
	var tree: SceneTree = bot.get_tree()
	var pending: Array[Dictionary] = []
	var on_hit := func(hit: HitInfo) -> void:
		if hit.victim == victim:
			pending.append({hit = hit, ticks = 0})
	CombatEvents.hit_landed.connect(on_hit)
	var n := 0
	while run.running and is_instance_valid(victim):
		await tree.physics_frame
		if pending.is_empty() or victim.rig == null:
			continue
		var entry: Dictionary = pending[0]
		if victim.rig.flash_overlay() == null:
			entry.ticks += 1
			if entry.ticks > PENDING_MAX_TICKS:
				pending.pop_front()
			continue
		pending.pop_front()
		n += 1
		await _sample(bot, slug, tag, n, victim, entry.hit, run.rows)
	CombatEvents.hit_landed.disconnect(on_hit)


## The flash is on as a tick starts, so the frame about to be drawn has it: that frame, and the one after
## (the flash lasts hit_flash_frames, 2, and its second frame is the first of a later tick's), are grabbed
## when drawn.
static func _sample(bot: Node, slug: String, tag: String, n: int, victim: CombatActor, hit: HitInfo,
		rows: Array[Dictionary]) -> void:
	var overlay := victim.rig.flash_overlay()
	var camera: Camera3D = bot.get_viewport().get_camera_3d()
	if overlay == null or camera == null or DisplayServer.get_name() == "headless":
		return
	var point: Vector3 = overlay.get_shader_parameter(&"flash_point")
	var radius := float(overlay.get_shader_parameter(&"flash_radius"))
	var cap := float(overlay.get_shader_parameter(&"flash_max_share"))
	var depth := -(camera.global_transform.affine_inverse() * point).z
	var size := bot.get_viewport().get_visible_rect().size
	var aspect := size.x / size.y
	var proj11 := camera.get_camera_projection().y.y
	await RenderingServer.frame_post_draw
	LookRect.mark(bot, slug, "%s_n%d_flash" % [tag.replace(" ", "_"), n], victim)
	var drawn := LookProbe.grab(bot.get_viewport())
	await RenderingServer.frame_post_draw
	var after := LookProbe.grab(bot.get_viewport())
	if drawn == null or after == null:
		return
	var white := LookProbe.white_share(drawn, Rect2i(), SAMPLE_STEP)
	var base := LookProbe.white_share(after, Rect2i(), SAMPLE_STEP)
	var move_id: StringName = hit.move.id if hit.move != null else &"body"
	var row := {
		move = move_id, tier = CombatTypes.tier_name(hit.tier), depth = depth, radius = radius, cap = cap,
		disc = HumanoidRig.flash_view_share(radius, depth, proj11, aspect),
		disc_capped = HumanoidRig.flash_view_share(HumanoidRig.flash_capped_radius(radius, depth, proj11, aspect, cap),
				depth, proj11, aspect),
		white = white, base = base, flash = maxf(white - base, 0.0),
	}
	rows.append(row)
	bot.log_line("FLASH-FP %s %s n%d %s %s depth=%.3f radius=%.3f cap=%.3f disc=%.4f disc_capped=%.4f white=%.4f base=%.4f flash=%.4f" % [
			slug, tag, n, row.move, row.tier, row.depth, row.radius, row.cap, row.disc, row.disc_capped, row.white,
			row.base, row.flash])


static func _sum(bot: Node, slug: String, name: String, label: String, rows: Array[Dictionary]) -> void:
	var largest := 0.0
	var total := 0.0
	var big: Array[int] = []
	big.resize(BIG_SHARES.size())
	for row: Dictionary in rows:
		largest = maxf(largest, row.flash)
		total += row.flash
		for i in BIG_SHARES.size():
			if row.flash > BIG_SHARES[i]:
				big[i] += 1
	var parts: Array[String] = []
	for i in BIG_SHARES.size():
		parts.append("over%d=%d" % [roundi(BIG_SHARES[i] * 100.0), big[i]])
	bot.log_line("FLASH-FP-SUM %s %s %s hits=%d flash_max=%.4f flash_mean=%.4f %s" % [
			slug, name, label, rows.size(), largest, total / maxf(rows.size(), 1.0), " ".join(parts)])
