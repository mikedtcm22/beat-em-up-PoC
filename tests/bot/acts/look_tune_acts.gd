extends RefCounted
## The look-tuning acts of Milestone 4 (F-look): the Punk and the placeholders as the lens sees them
## in each light, at 1, 2.5, 3, 5, 8 and 10 m, with the numbers of Part B's rows L1-L3 measured from
## the frames themselves (tests/bot/look_probe.gd) and written to look.json beside the recording.
## Every title starts with "Look: tune"; none is in another's. The crowd bot (tests/bot/crowd_bot.gd)
## loads this file by name; the training room's bot (tests/bot/look_tune_bot.gd) runs the same acts, so
## both rooms are judged from one script. Record one act per process:
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/t1 "Look: tune bands at 1 m" 6
##   tools/capture_bot.sh res://tests/bot/look_tune_bot.tscn captures/t1t "Look: tune bands at 1 m" 6
## and cut stills and crops with tools/look_sheets.sh as for the other look acts.
##
## "Front-lit" and "back-lit" are the sun turned: the room's default sun (Look > Toon, `look_sun_yaw_deg`)
## lights the player's default view from behind him, so the Punk's front is lit; the back-lit shot turns
## the sun half a circle, so the Punk's front faces away from it (the contre-jour case: about half of all
## enemies, whatever the sun's azimuth, M4-slice-gate.md gap 2). A metric frame is taken with the
## character on and again with it hidden: the pixels that differ are the character's.
##
## | Act | Title | Shows |
## | T1 | Look: tune bands at 1 m | the Punk at 1 m, view 6 degrees down, front-lit then back-lit (L2: bands on the jacket, a swatch's hue by band, the shadow's share, the highlight's share) |
## | T2 | Look: tune distances 3 and 8 m | the Punk at 3 and at 8 m, front-lit and back-lit |
## | T3 | Look: tune hull widths | the Punk at 1 (face shot, +8 degrees), 2.5, 5 and 10 m, with the hull and with its width 0: the ring's width on the crown and the sides (L1) and the ink on screen |
## | T4 | Look: tune damage at 1 m | health 100, 65 and 30%: the skin's bands and hue at each |
## | T5 | Look: tune jab flash | the player's jab on the Punk at 1 m: the white share of the frame the flash is drawn in (L3) |
## | T6 | Look: tune lineup, both lights | Punk, Kicker, Thug and Bruiser at 2.2 m, front-lit and back-lit |
## | T7 | Look: tune street, both lights | the street's four views, front-lit and back-lit (the room's two bands, its lines) |
##
## Log lines: `LOOK-TUNE <room> <slug> start ...` (what was set), `LOOK-METRIC <slug> <key> <value>`, and the
## LOOK-MARK / LOOK-RECT lines of look_rect.gd.

const LookRect := preload("res://tests/bot/look_rect.gd")
const LookProbe := preload("res://tests/bot/look_probe.gd")

## The Punk's distance for the 1 m shots.
const CLOSE_M := 1.0
## The distances of the second act, and the hull's (L1).
const MID_DISTANCES_M: Array[float] = [3.0, 8.0]
const HULL_DISTANCES_M: Array[float] = [1.0, 2.5, 5.0, 10.0]
const LINEUP_M := 2.2
## The view: the default look of every act, a level look, and the face shot's.
const DEFAULT_PITCH_DEG := -6.0
const LEVEL_PITCH_DEG := 0.0
const FACE_PITCH_DEG := 8.0
const PITCH_TICKS := 10
const SETTLE_TICKS := 30
## Ticks for a changed tunable to reach a drawn frame before it is grabbed.
const SHOW_TICKS := 6
## The sun turned half a circle is the back-lit case.
const BACK_TURN_DEG := 180.0
## The health looks of T4 (the reacts' own), and how long each is held.
const HEALTH_SHARES: Array[float] = [1.0, 0.65, 0.3]
const HEALTH_HOLD_TICKS := 40
const SURVIVOR_HEALTH := 100.0
## The lineup (look_acts.gd's): the enemies left to right, as bearings from the look in degrees.
const LINEUP: Array[Dictionary] = [
	{id = &"punk", bearing_deg = 33.0},
	{id = &"kicker", bearing_deg = 11.0},
	{id = &"thug", bearing_deg = -11.0},
	{id = &"bruiser", bearing_deg = -33.0},
]
## The swatches' colours, as the palette atlas authors them (assets/source/palette/*.json), and the
## families a pixel is counted in: how far its hue may be from the swatch's (the shadow band's violet
## moves it), and the saturation range that tells a skin from the cap's yellow.
const SKIN_SRGB := "#f0c9a8"
const TEAL_SRGB := "#3f8f96"
const TEAL_HUE_TOL_DEG := 50.0
const SKIN_HUE_TOL_DEG := 60.0
const TEAL_S_MIN := 0.25
const SKIN_S_MAX := 0.5
const SKIN_S_MIN := 0.06
const FAMILY_V_MIN := 0.12
## The skin's window of the head's rectangle (the face under the shades), as fractions of it.
const FACE_WINDOW := Rect2(0.2, 0.45, 0.6, 0.55)
## The hull's windows: how far past the figure's rectangle they reach (px at 1600x900), and the rows of
## the sides (as fractions of the body's height).
const RING_MARGIN_PX := 24
const SIDE_ROWS := Vector2(0.55, 0.9)
## The crown's window: from this share of the head's height above its rectangle, this tall (the cap
## stands above the head's sphere).
const CROWN_ROWS := Vector2(0.6, 0.95)
## T5: how many physics frames to wait for the hit.
const HIT_MAX_TICKS := 90
## T7: the quarter turns of the view.
const STREET_TURNS_DEG: Array[float] = [0.0, 90.0, -180.0, -90.0]


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Look: tune bands at 1 m", cam = &"first_person", slug = &"t1", fn = func() -> void: await _bands(bot)},
		{title = "Look: tune distances 3 and 8 m", cam = &"first_person", slug = &"t2", fn = func() -> void: await _distances(bot)},
		{title = "Look: tune hull widths", cam = &"first_person", slug = &"t3", fn = func() -> void: await _hulls(bot)},
		{title = "Look: tune damage at 1 m", cam = &"first_person", slug = &"t4", fn = func() -> void: await _damage(bot)},
		{title = "Look: tune jab flash", cam = &"first_person", slug = &"t5", fn = func() -> void: await _flash(bot)},
		{title = "Look: tune lineup, both lights", cam = &"first_person", slug = &"t6", fn = func() -> void: await _lineup(bot)},
		{title = "Look: tune street, both lights", cam = &"first_person", slug = &"t7", fn = func() -> void: await _street(bot)},
	]


# --- The shared steps -------------------------------------------------------------------------


## The start of every act: the caption off, god mode, the AI frozen, the comic effects cleared and
## seeded, and which room and look this is (`LOOK-TUNE`).
static func _begin(bot: Node, slug: String) -> void:
	bot.caption.visible = false
	bot.god()
	bot.freeze_ai(true)
	var vfx := bot.get_tree().get_first_node_in_group(VfxDirector.GROUP) as VfxDirector
	if vfx:
		vfx.clear()
		vfx.rng.seed = 7
	bot.log_line("LOOK-TUNE %s %s viewport %s window %s" % [bot.room.name, slug,
			bot.get_viewport().get_visible_rect().size, bot.get_window().size])
	bot.log_line("LOOK-TUNE %s %s start sun_yaw=%.0f elevation=%.0f fill=%.2f band_1=%.2f band_2=%.2f" % [
			bot.room.name, slug, Tuning.data.look_sun_yaw_deg, Tuning.data.look_sun_elevation_deg,
			Tuning.data.look_fill_strength, Tuning.data.look_band_1, Tuning.data.look_band_2])


static func _end(bot: Node, slug: String) -> void:
	LookRect.mark(bot, slug, "end")
	bot.caption.visible = true


## The sun in the lighting `front` (the default) or not (turned half a circle).
static func _light(bot: Node, front: bool, base_yaw: float) -> void:
	bot.tune(&"look_sun_yaw_deg", base_yaw if front else wrapf(base_yaw + BACK_TURN_DEG, -180.0, 180.0))
	await bot._ticks(SHOW_TICKS)


## A drawn frame, now (null when headless: nothing is drawn).
static func _shot(bot: Node) -> Image:
	await bot._ticks(SHOW_TICKS)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	return LookProbe.grab(bot.get_viewport())


## The frame with `actor` in it, marked `label` (a still and its rectangles), and then the same frame
## with it hidden: {on, off}. The mark is made before the actor is hidden: a mark names the frame
## last drawn.
static func _pair(bot: Node, slug: String, label: String, actor: CombatActor) -> Dictionary:
	var on := await _shot(bot)
	LookRect.mark(bot, slug, label, actor)
	actor.visible = false
	var off := await _shot(bot)
	actor.visible = true
	return {on = on, off = off}


static func _metric(bot: Node, slug: String, values: Dictionary) -> void:
	for key: String in values:
		bot.log_line("LOOK-METRIC %s %s %s" % [slug, key, values[key]])
	LookProbe.record(slug, values)


static func _survivor(punk: EnemyActor) -> void:
	punk.max_health = SURVIVOR_HEALTH
	punk.health = SURVIVOR_HEALTH


## `rect` (1600x900 px, look_rect.gd) in the pixels of `image`.
static func _px(rect: Rect2, image: Image) -> Rect2i:
	var scale := Vector2(image.get_size()) / LookRect.FRAME_SIZE
	return Rect2i(Vector2i(rect.position * scale), Vector2i(rect.size * scale))


static func _rect(bot: Node, actor: CombatActor, region: StringName, image: Image) -> Rect2i:
	var camera: Camera3D = bot.get_viewport().get_camera_3d()
	return _px(LookRect.region_rect(camera, actor.rig, region), image)


static func _round(value: float, step: float = 0.01) -> float:
	return snappedf(value, step)


## The bands of a swatch's family as `luma/hue/share/saturation`, for a metric line.
static func _band_text(bands: Array[Dictionary]) -> String:
	var parts := PackedStringArray()
	for band: Dictionary in bands:
		var color: Color = band.color
		parts.append("%.3f/%.0f/%.2f/%.2f" % [band.luma, color.h * 360.0, band.share, color.s])
	return ",".join(parts)


## The share of the character's pixels (the pixels `on` and `off` disagree on) in `rect` that are
## near-white: the highlight.
static func _white_share_of(on: Image, off: Image, rect: Rect2i) -> float:
	var r := rect.intersection(Rect2i(Vector2i.ZERO, on.get_size()))
	var white := 0
	var total := 0
	for y in range(r.position.y, r.end.y, 2):
		for x in range(r.position.x, r.end.x, 2):
			var a := on.get_pixel(x, y)
			var b := off.get_pixel(x, y)
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) <= LookProbe.CHANGED_DELTA:
				continue
			total += 1
			if minf(a.r, minf(a.g, a.b)) >= LookProbe.WHITE_LEVEL:
				white += 1
	return float(white) / float(maxi(total, 1))


## The numbers of one lit shot of `punk`: the jacket's and the skin's bands (L2, and each band's hue
## against its swatch's) and the share of the Punk that is white (the highlight, under 3%). `key` is
## the metric prefix.
static func _band_metrics(bot: Node, slug: String, key: String, pair: Dictionary, punk: CombatActor) -> void:
	var on: Image = pair.on
	var off: Image = pair.off
	if on == null or off == null:
		return
	var body := _rect(bot, punk, LookRect.BODY, on)
	var head := _rect(bot, punk, LookRect.HEAD, on)
	var face := Rect2i(
			head.position + Vector2i(Vector2(head.size) * FACE_WINDOW.position),
			Vector2i(Vector2(head.size) * FACE_WINDOW.size))
	var teal_hue := Color(TEAL_SRGB).h * 360.0
	var skin_hue := Color(SKIN_SRGB).h * 360.0
	var jacket := LookProbe.bands(on, body, {hue = teal_hue, hue_tol = TEAL_HUE_TOL_DEG, s_min = TEAL_S_MIN,
			v_min = FAMILY_V_MIN, only = off})
	var skin := LookProbe.bands(on, face, {hue = skin_hue, hue_tol = SKIN_HUE_TOL_DEG, s_min = SKIN_S_MIN,
			s_max = SKIN_S_MAX, v_min = FAMILY_V_MIN, only = off})
	var values := {}
	values["%s_jacket_bands" % key] = jacket.size()
	values["%s_jacket_luma_hue" % key] = _band_text(jacket)
	if jacket.size() >= 2:
		values["%s_jacket_shadow_over_lit" % key] = _round(jacket[0].luma / jacket[jacket.size() - 1].luma)
		values["%s_jacket_shadow_hue_gap_to_teal" % key] = _round(
				LookProbe.hue_gap((jacket[0].color as Color).h * 360.0, teal_hue), 1.0)
	if not jacket.is_empty():
		var lit: Color = jacket[jacket.size() - 1].color
		values["%s_jacket_lit_hue_gap_to_teal" % key] = _round(LookProbe.hue_gap(lit.h * 360.0, teal_hue), 1.0)
	values["%s_skin_bands" % key] = skin.size()
	values["%s_skin_luma_hue" % key] = _band_text(skin)
	for i in skin.size():
		values["%s_skin_band%d_hue_gap_to_skin" % [key, i]] = _round(
				LookProbe.hue_gap((skin[i].color as Color).h * 360.0, skin_hue), 1.0)
	values["%s_white_share_of_punk" % key] = _round(_white_share_of(on, off, body), 0.0001)
	_metric(bot, slug, values)


## The hull's width at the crown and on the two sides of `punk` (L1), from `on` and `flat` (the same
## frame with the hull's width 0): {crown, left, right} each a {width (1080p px), ink, runs} of
## LookProbe.ring_width_px(), {all} the whole body's. The crown window is the strip across the middle of
## the head and above it; the sides are the outer quarter of the body's rectangle, in its lower half.
static func _hull_rings(bot: Node, on: Image, flat: Image, punk: CombatActor) -> Dictionary:
	var head := _rect(bot, punk, LookRect.HEAD, on)
	var body := _rect(bot, punk, LookRect.BODY, on)
	var scale := float(on.get_width()) / LookRect.FRAME_SIZE.x
	var margin := roundi(RING_MARGIN_PX * scale)
	var crown := Rect2i(head.position.x + head.size.x / 4, head.position.y - roundi(float(head.size.y) * CROWN_ROWS.x),
			head.size.x / 2, roundi(float(head.size.y) * CROWN_ROWS.y))
	var y0 := body.position.y + roundi(float(body.size.y) * SIDE_ROWS.x)
	var rows := roundi(float(body.size.y) * (SIDE_ROWS.y - SIDE_ROWS.x))
	var quarter := body.size.x / 4
	var left := Rect2i(body.position.x - margin, y0, quarter + margin, rows)
	var right := Rect2i(body.end.x - quarter, y0, quarter + margin, rows)
	return {
		crown = LookProbe.outer_ring_px(on, flat, crown, Vector2i(0, 1)),
		left = LookProbe.outer_ring_px(on, flat, left, Vector2i(1, 0)),
		right = LookProbe.outer_ring_px(on, flat, right, Vector2i(-1, 0)),
		all = LookProbe.ring_width_px(on, flat, body),
	}


## The ink as it reads on screen, `r,g,b` of 0-255.
static func _color_text(color: Color) -> String:
	return "%d,%d,%d" % [roundi(color.r * 255.0), roundi(color.g * 255.0), roundi(color.b * 255.0)]


# --- T1, T2: bands -------------------------------------------------------------------------------


static func _bands(bot: Node) -> void:
	_begin(bot, "t1")
	var base_yaw := Tuning.data.look_sun_yaw_deg
	var punk: EnemyActor = bot.spawn(&"punk", Vector2(0.0, CLOSE_M))
	_survivor(punk)
	await bot._look_to(DEFAULT_PITCH_DEG, PITCH_TICKS)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "t1", "start")
	for front: bool in [true, false]:
		await _light(bot, front, base_yaw)
		var label := "front_lit" if front else "back_lit"
		var pair := await _pair(bot, "t1", label, punk)
		_band_metrics(bot, "t1", label, pair, punk)
	_end(bot, "t1")


static func _distances(bot: Node) -> void:
	_begin(bot, "t2")
	var base_yaw := Tuning.data.look_sun_yaw_deg
	await bot._look_to(LEVEL_PITCH_DEG, PITCH_TICKS)
	LookRect.mark(bot, "t2", "start")
	for distance: float in MID_DISTANCES_M:
		bot.clear_enemies()
		var punk: EnemyActor = bot.spawn(&"punk", Vector2(0.0, distance))
		_survivor(punk)
		await bot._ticks(SETTLE_TICKS)
		for front: bool in [true, false]:
			await _light(bot, front, base_yaw)
			var label := "d%s_%s" % [str(distance).replace(".", "_"), "front_lit" if front else "back_lit"]
			var pair := await _pair(bot, "t2", label, punk)
			_band_metrics(bot, "t2", label, pair, punk)
	_end(bot, "t2")


# --- T3: hull widths -----------------------------------------------------------------------------


static func _hulls(bot: Node) -> void:
	_begin(bot, "t3")
	var px := Tuning.data.look_outline_px
	LookRect.mark(bot, "t3", "start")
	for distance: float in HULL_DISTANCES_M:
		bot.clear_enemies()
		# The 1 m shot is the face shot, so the crown is in the frame.
		await bot._look_to(FACE_PITCH_DEG if distance <= CLOSE_M else LEVEL_PITCH_DEG, PITCH_TICKS)
		var punk: EnemyActor = bot.spawn(&"punk", Vector2(0.0, distance))
		_survivor(punk)
		await bot._ticks(SETTLE_TICKS)
		bot.tune(&"look_outline_px", px)
		var on := await _shot(bot)
		var label := "d%s_m" % str(distance).replace(".", "_")
		LookRect.mark(bot, "t3", label, punk)
		bot.tune(&"look_outline_px", 0.0)
		var flat := await _shot(bot)
		bot.tune(&"look_outline_px", px)
		if on == null or flat == null:
			continue
		LookProbe.dump(on, "t3_%s_on" % label)
		LookProbe.dump(flat, "t3_%s_flat" % label)
		var rings := _hull_rings(bot, on, flat, punk)
		var values := {}
		for family: String in ["crown", "left", "right", "all"]:
			var ring: Dictionary = rings[family]
			values["%s_%s_px1080" % [label, family]] = _round(ring.width)
			values["%s_%s_runs" % [label, family]] = ring.runs
		values["%s_ink_rgb" % label] = _color_text(rings.all.get("ink", Color.BLACK))
		_metric(bot, "t3", values)
	_end(bot, "t3")


# --- T4: damage ----------------------------------------------------------------------------------


static func _damage(bot: Node) -> void:
	_begin(bot, "t4")
	var punk: EnemyActor = bot.spawn(&"punk", Vector2(0.0, CLOSE_M))
	_survivor(punk)
	await bot._look_to(DEFAULT_PITCH_DEG, PITCH_TICKS)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "t4", "start")
	for share: float in HEALTH_SHARES:
		punk.health = punk.max_health * share
		CombatEvents.health_changed.emit(punk, punk.health, punk.max_health)
		await bot._ticks(HEALTH_HOLD_TICKS)
		var label := "health_%d" % roundi(share * 100.0)
		var pair := await _pair(bot, "t4", label, punk)
		_band_metrics(bot, "t4", label, pair, punk)
	_end(bot, "t4")


# --- T5: the jab's flash ---------------------------------------------------------------------------


## The player's jab on the Punk at 1 m; the frame the contact flash is first drawn in is grabbed and
## the white share of the whole view is the L3 figure (the before pack's frame of the same hit is the
## M2 figure to set it against; the flash shows `hit_flash_frames` frames).
static func _flash(bot: Node) -> void:
	_begin(bot, "t5")
	var punk: EnemyActor = bot.spawn(&"punk", Vector2(0.0, CLOSE_M))
	_survivor(punk)
	await bot._look_to(DEFAULT_PITCH_DEG, PITCH_TICKS)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "t5", "start")
	var hit := {landed = false}
	var on_hit := func(info: HitInfo) -> void:
		if info.victim == punk:
			hit.landed = true
	CombatEvents.hit_landed.connect(on_hit)
	await bot._press(&"P", 2)
	var waited := 0
	while not hit.landed and waited < HIT_MAX_TICKS:
		await bot.get_tree().physics_frame
		waited += 1
	CombatEvents.hit_landed.disconnect(on_hit)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	LookRect.mark(bot, "t5", "jab_flash", punk)
	var image := LookProbe.grab(bot.get_viewport())
	if image != null:
		_metric(bot, "t5", {
			"jab_flash_white_share_of_view": _round(LookProbe.white_share(image, Rect2i(), 2), 0.0001),
			"jab_flash_hit_landed": hit.landed,
		})
	await bot._ticks(2)
	LookRect.mark(bot, "t5", "jab_flash_next", punk)
	_end(bot, "t5")


# --- T6, T7: the cast and the street, both lights --------------------------------------------------


static func _lineup(bot: Node) -> void:
	_begin(bot, "t6")
	var base_yaw := Tuning.data.look_sun_yaw_deg
	var punk: EnemyActor = null
	for entry: Dictionary in LINEUP:
		var bearing := deg_to_rad(entry.bearing_deg)
		var enemy: EnemyActor = bot.spawn(entry.id, Vector2(-sin(bearing), cos(bearing)) * LINEUP_M)
		if entry.id == &"punk":
			punk = enemy
	await bot._look_to(LEVEL_PITCH_DEG, PITCH_TICKS)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "t6", "start")
	for front: bool in [true, false]:
		await _light(bot, front, base_yaw)
		await bot._ticks(SETTLE_TICKS)
		LookRect.mark(bot, "t6", "front_lit" if front else "back_lit", punk)
	_end(bot, "t6")


## The room with nothing in front of the player: the default view and the sun turned, then the
## view turned in quarters, so every wall of the street is seen in both lights.
static func _street(bot: Node) -> void:
	_begin(bot, "t7")
	var base_yaw := Tuning.data.look_sun_yaw_deg
	await bot._look_to(LEVEL_PITCH_DEG, PITCH_TICKS)
	LookRect.mark(bot, "t7", "start")
	for turn: float in STREET_TURNS_DEG:
		if turn != 0.0:
			await bot._turn_by(turn, SETTLE_TICKS)
		for front: bool in [true, false]:
			await _light(bot, front, base_yaw)
			await bot._ticks(SHOW_TICKS)
			LookRect.mark(bot, "t7", "turn%d_%s" % [roundi(turn), "front_lit" if front else "back_lit"])
	_end(bot, "t7")
