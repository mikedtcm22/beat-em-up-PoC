extends RefCounted
## The contact flash in first person, measured (Milestone 4, P3-flash): feel questions 1 and 2 of
## M4-plan Part C section 8 with the art Punk in the lens. Each act plays one scenario several times,
## once per setting of the two FP feel tunables (Tuning hit_flash_fp_max_share and
## hit_flash_finisher_radius_mult), the first pass always "today" (0 and 1.0), and prints for every
## contact flash the share of the frame it whitens:
##   FLASH-FP <slug> <scenario> <setting> n<k> <move> <tier> depth=<m> radius=<m> cap=<share>
##            disc=<share> scale=<k> white=<share> pure=<share> any=<share>
## The frame the flash is drawn in is grabbed, then the same frame is drawn again with the flash's
## strength at 0 (RenderingServer.force_draw(): no tick runs between, and a Movie Maker recording takes
## no extra frame), so the two differ by the flash alone. `white` is the share of the first frame's pixels
## that are white (look_probe's WHITE_LEVEL, T5's figure, L3's measure), `pure` the share that the flash
## made white (white with it, not without), `any` the share it changed at all (its whole visible patch,
## the fade included). `disc` is what the flash's outer disc covers on a surface at the flash point's
## depth by the shader's own math (HumanoidRig.flash_view_share()), `scale` how much the cap shrinks it there
## (HumanoidRig.flash_cap_scale(): 1 = not at all). Each pass
## ends with a `FLASH-FP-SUM` line (hits, the largest and the mean `pure` and `any`, how many flashes
## changed over 5% and 10% of the view).
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
## The shares of the view a flash's whole patch may pass to be counted as big, in the sum line.
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
	{label = "cap04", share = 0.04, mult = 1.0},
	{label = "cap06", share = 0.06, mult = 1.0},
	{label = "cap08", share = 0.08, mult = 1.0},
	{label = "cap12", share = 0.12, mult = 1.0},
]
const FLURRY_SETTINGS: Array[Dictionary] = [
	{label = "today", share = 0.0, mult = 1.0},
	{label = "cap04", share = 0.04, mult = 1.0},
	{label = "cap06", share = 0.06, mult = 1.0},
	{label = "cap08", share = 0.08, mult = 1.0},
	{label = "cap12", share = 0.12, mult = 1.0},
]
const HOLD_SETTINGS: Array[Dictionary] = [
	{label = "today", share = 0.0, mult = 1.0},
	{label = "cap04", share = 0.04, mult = 1.0},
	{label = "cap06", share = 0.06, mult = 1.0},
	{label = "cap08", share = 0.08, mult = 1.0},
	{label = "cap12", share = 0.12, mult = 1.0},
]
const FINISHER_SETTINGS: Array[Dictionary] = [
	{label = "today", share = 0.0, mult = 1.0},
	{label = "mult15", share = 0.0, mult = 1.5},
	{label = "mult20", share = 0.0, mult = 2.0},
	{label = "mult30", share = 0.0, mult = 3.0},
	{label = "mult20cap06", share = 0.06, mult = 2.0},
	{label = "mult30cap06", share = 0.06, mult = 3.0},
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
	var viewport: Viewport = bot.get_viewport()
	var drawn := LookProbe.grab(viewport)
	var strength: Variant = overlay.get_shader_parameter(&"flash_strength")
	overlay.set_shader_parameter(&"flash_strength", 0.0)
	RenderingServer.force_draw(false)
	var clear := LookProbe.grab(viewport)
	overlay.set_shader_parameter(&"flash_strength", strength)
	if drawn == null or clear == null:
		return
	var move_id: StringName = hit.move.id if hit.move != null else &"body"
	var row := {
		move = move_id, tier = CombatTypes.tier_name(hit.tier), depth = depth, radius = radius, cap = cap,
		disc = HumanoidRig.flash_view_share(radius, depth, proj11, aspect),
		scale = HumanoidRig.flash_cap_scale(radius, depth, proj11, aspect, cap),
		white = LookProbe.white_share(drawn, Rect2i(), SAMPLE_STEP),
		pure = _made_white_share(drawn, clear),
		any = LookProbe.changed_share(drawn, clear, Rect2i(), SAMPLE_STEP),
	}
	rows.append(row)
	bot.log_line("FLASH-FP %s %s n%d %s %s depth=%.3f radius=%.3f cap=%.3f disc=%.4f scale=%.3f white=%.4f pure=%.4f any=%.4f" % [
			slug, tag, n, row.move, row.tier, row.depth, row.radius, row.cap, row.disc, row.scale, row.white,
			row.pure, row.any])


## The share of pixels that are white in `with_flash` and not in `without`: what the flash made white.
static func _made_white_share(with_flash: Image, without: Image) -> float:
	var size := with_flash.get_size()
	var made := 0
	var total := 0
	for y in range(0, size.y, SAMPLE_STEP):
		for x in range(0, size.x, SAMPLE_STEP):
			var a := with_flash.get_pixel(x, y)
			var b := without.get_pixel(x, y)
			if minf(a.r, minf(a.g, a.b)) >= LookProbe.WHITE_LEVEL and minf(b.r, minf(b.g, b.b)) < LookProbe.WHITE_LEVEL:
				made += 1
			total += 1
	return float(made) / float(maxi(total, 1))


static func _sum(bot: Node, slug: String, name: String, label: String, rows: Array[Dictionary]) -> void:
	var pure_max := 0.0
	var pure_sum := 0.0
	var any_max := 0.0
	var any_sum := 0.0
	var big: Array[int] = []
	big.resize(BIG_SHARES.size())
	for row: Dictionary in rows:
		pure_max = maxf(pure_max, row.pure)
		pure_sum += row.pure
		any_max = maxf(any_max, row.any)
		any_sum += row.any
		for i in BIG_SHARES.size():
			if row.any > BIG_SHARES[i]:
				big[i] += 1
	var parts: Array[String] = []
	for i in BIG_SHARES.size():
		parts.append("any_over%d=%d" % [roundi(BIG_SHARES[i] * 100.0), big[i]])
	var count := maxf(rows.size(), 1.0)
	bot.log_line("FLASH-FP-SUM %s %s %s hits=%d pure_max=%.4f pure_mean=%.4f any_max=%.4f any_mean=%.4f %s" % [
			slug, name, label, rows.size(), pure_max, pure_sum / count, any_max, any_sum / count, " ".join(parts)])
