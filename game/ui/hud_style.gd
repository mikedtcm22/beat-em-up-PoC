class_name HudStyle
extends RefCounted
## Shared look for the HUD (Spec §5, §10): comic panels with flat fills, thick dark ink
## borders and a slight slant. Red is reserved for blood, the rear-attack warning and
## finisher accents, so health bars are yellow (player, enemies) and violet (boss).
## Sizes assume the 1920x1080 canvas (stretch mode canvas_items).
## The draw_* helpers must be called from inside the target CanvasItem's _draw().

const INK := Color(0.07, 0.06, 0.09)
const PAPER := Color(0.97, 0.94, 0.85)
const TROUGH := Color(0.22, 0.2, 0.27)
const GHOST := Color(1.0, 1.0, 1.0)
const HEALTH := Color(1.0, 0.82, 0.16)
const BOSS := Color(0.7, 0.42, 0.98)
const DURABILITY := Color(0.55, 0.86, 1.0)
## The guard meter (held block) and the PARRY callout.
const GUARD := Color(0.42, 0.96, 0.82)
const PARRY := Color(0.35, 0.92, 1.0)
const MUTED := Color(0.62, 0.62, 0.68)
## Only for finisher accents (Spec §10).
const FINISHER_ACCENT := Color(1.0, 0.42, 0.32)

## process_priority of the HUD and the debug draw. They must process after the camera
## director and its cameras (CameraDirector.PROCESS_PRIORITY = 50, game/camera/), which
## place the view in their own _process: anything projected through the camera (over-head
## bars) or measured from it (debug draw clearances) then uses the transform of the frame
## being rendered instead of the previous one. Becomes CameraDirector.PROCESS_PRIORITY + 1
## once the camera module is on the same branch.
const PROCESS_PRIORITY := 100

## Where the eight points of a comic outline stray (unit offsets, times the wobble tunable): the same for every box, so a box never shimmers.
## The outer edge of the ink and the inner edge of it use different sets, so the border's width varies along its length.
const _STRAY_OUTER: Array[Vector2] = [
	Vector2(-0.6, 0.5), Vector2(0.3, -0.8), Vector2(0.7, -0.4), Vector2(-0.2, 0.9),
	Vector2(0.5, 0.7), Vector2(-0.7, 0.2), Vector2(-0.4, -0.6), Vector2(0.8, 0.3),
]
const _STRAY_INNER: Array[Vector2] = [
	Vector2(0.4, -0.3), Vector2(-0.5, 0.6), Vector2(-0.3, 0.8), Vector2(0.6, -0.5),
	Vector2(-0.8, -0.2), Vector2(0.2, -0.7), Vector2(0.7, 0.4), Vector2(-0.4, -0.9),
]

static var _bold_font: FontVariation


## True while the trailer look profile is running: the HUD then draws its comic caption boxes (Milestone 7, "HUD (M7)" tunables).
## Under the m6 profile every helper below draws exactly as it did before.
static func comic() -> bool:
	return LookProfile.current() == LookProfile.Id.TRAILER


## `color` as the running profile draws it: under the trailer profile the HUD's four palette colours (ink, paper, the health and boss
## bars) are the "HUD (M7)" tunables, with the alpha kept; every other colour, and every colour under m6, as given.
static func tone(color: Color) -> Color:
	if not comic():
		return color
	var d := Tuning.data
	var mapped := color
	if _same_rgb(color, INK):
		mapped = d.hud_m7_ink
	elif _same_rgb(color, PAPER):
		mapped = d.hud_m7_paper
	elif _same_rgb(color, HEALTH):
		mapped = d.hud_m7_health
	elif _same_rgb(color, BOSS):
		mapped = d.hud_m7_boss
	else:
		return color
	return Color(mapped, mapped.a * color.a)


## The colour of an empty bar, a spent pip and a bar's trough: the cool dark trough under m6, the shaded cream paper under the trailer profile.
static func empty_tone() -> Color:
	return Tuning.data.hud_m7_paper_shade if comic() else TROUGH


## Where a HUD element that sits in a corner or on an edge (`anchor`: (0,1) bottom-left, (0.5,1) bottom-centre) is drawn from under
## the trailer profile: the share its scale gives up toward that anchor plus the offset tunables. Zero under m6.
static func corner_offset(size: Vector2, anchor: Vector2) -> Vector2:
	if not comic():
		return Vector2.ZERO
	var d := Tuning.data
	return Vector2(size.x * anchor.x, size.y * anchor.y) * (1.0 - d.hud_m7_scale) + Vector2(d.hud_m7_offset_x, d.hud_m7_offset_y)


## The scale of the player's panel and the boss bar: hud_m7_scale under the trailer profile, 1 under m6.
static func corner_scale() -> Vector2:
	return Vector2.ONE * (Tuning.data.hud_m7_scale if comic() else 1.0)


## `slant` as the running profile draws it (the trailer profile keeps a share of it, hud_m7_slant_scale).
static func slant_of(slant: float) -> float:
	return slant * Tuning.data.hud_m7_slant_scale if comic() else slant


static func _same_rgb(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.002 and absf(a.g - b.g) < 0.002 and absf(a.b - b.b) < 0.002


## The outline of `rect` as a hand would ink it: its sheared corners and the middle of each edge, every point strayed a little by
## `table` (times `amount` px, kept small against the rect so a thin bar stays a clean shape). Falls back to the plain quad at 0.
static func hand_polygon(rect: Rect2, slant: float, table: Array[Vector2], amount: float) -> PackedVector2Array:
	var quad := slanted_quad(rect, slant)
	var stray := minf(amount, minf(rect.size.x, rect.size.y) * 0.12)
	if stray < 0.05:
		return quad
	var points := PackedVector2Array()
	for i in 4:
		points.append(quad[i])
		points.append((quad[i] + quad[(i + 1) % 4]) * 0.5)
	for i in points.size():
		points[i] += table[i] * stray
	return points


## The default theme font, emboldened for comic lettering.
static func bold_font() -> Font:
	if _bold_font == null:
		_bold_font = FontVariation.new()
		_bold_font.base_font = ThemeDB.fallback_font
		_bold_font.variation_embolden = 0.9
	return _bold_font


## The default theme font, for compact text (combat log).
static func regular_font() -> Font:
	return ThemeDB.fallback_font


## LabelSettings in the default theme font (bold = emboldened) with an optional ink outline.
static func label_settings(font_size: int, color: Color, bold: bool = false, outline: int = 0) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = bold_font() if bold else regular_font()
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_size = outline
	settings.outline_color = INK
	return settings


## Corners of `rect` sheared to the right: the top edge starts `slant * height` in from the
## left, the bottom edge ends the same amount in from the right. Stays inside `rect`.
## The shift is capped at half the width so narrow quads never self-intersect.
static func slanted_quad(rect: Rect2, slant: float) -> PackedVector2Array:
	var shift := minf(slant * rect.size.y, rect.size.x * 0.5)
	return PackedVector2Array([
		Vector2(rect.position.x + shift, rect.position.y),
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x - shift, rect.end.y),
		Vector2(rect.position.x, rect.end.y),
	])


## `color` with its alpha multiplied by `alpha`.
static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color, color.a * alpha)


## A comic panel: drop shadow, ink border `border` px wide around `rect`, flat `fill`. Under the trailer profile it is a drawn
## caption box instead: a hard offset shadow in solid ink, a bold ink border that strays a little, a flat cream fill.
static func draw_panel(ci: CanvasItem, rect: Rect2, slant: float, fill: Color, border: float,
		shadow: Vector2 = Vector2(6.0, 6.0), alpha: float = 1.0) -> void:
	if comic():
		_draw_caption_box(ci, rect, slant, fill, border, shadow != Vector2.ZERO, alpha)
		return
	var outer := rect.grow(border)
	if shadow != Vector2.ZERO:
		var shadow_quad := slanted_quad(Rect2(outer.position + shadow, outer.size), slant)
		ci.draw_colored_polygon(shadow_quad, Color(INK, 0.5 * alpha))
	ci.draw_colored_polygon(slanted_quad(outer, slant), with_alpha(INK, alpha))
	ci.draw_colored_polygon(slanted_quad(rect, slant), with_alpha(fill, alpha))


## A flat slab inside an ink border `border` px wide (the pips, the guard meter's trough). Hand-inked under the trailer profile.
static func draw_slab(ci: CanvasItem, rect: Rect2, slant: float, fill: Color, border: float, alpha: float = 1.0) -> void:
	if comic():
		var d := Tuning.data
		var ink := with_alpha(d.hud_m7_ink, alpha)
		ci.draw_colored_polygon(hand_polygon(rect.grow(border * d.hud_m7_border_scale), slant_of(slant), _STRAY_OUTER, d.hud_m7_wobble_px * 0.5), ink)
		ci.draw_colored_polygon(hand_polygon(rect, slant_of(slant), _STRAY_INNER, d.hud_m7_wobble_px * 0.25), with_alpha(tone(fill), alpha))
		return
	ci.draw_colored_polygon(slanted_quad(rect.grow(border), slant), with_alpha(INK, alpha))
	ci.draw_colored_polygon(slanted_quad(rect, slant), with_alpha(fill, alpha))


static func _draw_caption_box(ci: CanvasItem, rect: Rect2, slant: float, fill: Color, border: float, with_shadow: bool,
		alpha: float) -> void:
	var d := Tuning.data
	var s := slant_of(slant)
	var outer := rect.grow(border * d.hud_m7_border_scale)
	var ink := with_alpha(d.hud_m7_ink, alpha)
	if with_shadow and d.hud_m7_shadow_px > 0.0:
		var shifted := Rect2(outer.position + Vector2.ONE * d.hud_m7_shadow_px, outer.size)
		ci.draw_colored_polygon(hand_polygon(shifted, s, _STRAY_INNER, d.hud_m7_wobble_px), ink)
	ci.draw_colored_polygon(hand_polygon(outer, s, _STRAY_OUTER, d.hud_m7_wobble_px), ink)
	ci.draw_colored_polygon(hand_polygon(rect, s, _STRAY_INNER, d.hud_m7_wobble_px * 0.5), with_alpha(tone(fill), alpha))


## A slanted health bar inside an ink border: trough, white damage ghost, then the fill
## (flashed toward white right after damage). Under the trailer profile: a flat fill in an ink outline over a shaded-cream
## trough, with the lost span hanging as a hard-edged chunk that then drops away (HealthGauge.chunk_*).
static func draw_gauge(ci: CanvasItem, rect: Rect2, slant: float, gauge: HealthGauge, fill: Color,
		border: float, alpha: float = 1.0) -> void:
	if comic():
		_draw_comic_gauge(ci, rect, slant, gauge, fill, border, alpha)
		return
	ci.draw_colored_polygon(slanted_quad(rect.grow(border), slant), with_alpha(INK, alpha))
	ci.draw_colored_polygon(slanted_quad(rect, slant), with_alpha(TROUGH, alpha))
	_draw_fill(ci, rect, slant, gauge.ghost, with_alpha(GHOST, alpha))
	var color := fill.lerp(Color.WHITE, gauge.flash * 0.7)
	_draw_fill(ci, rect, slant, gauge.value, with_alpha(color, alpha))


static func _draw_comic_gauge(ci: CanvasItem, rect: Rect2, slant: float, gauge: HealthGauge, fill: Color, border: float,
		alpha: float) -> void:
	var d := Tuning.data
	var s := slant_of(slant)
	var bw := border * d.hud_m7_bar_outline_scale
	var ink := with_alpha(d.hud_m7_ink, alpha)
	if bw > 0.0:
		ci.draw_colored_polygon(hand_polygon(rect.grow(bw), s, _STRAY_OUTER, d.hud_m7_wobble_px * 0.5), ink)
	ci.draw_colored_polygon(hand_polygon(rect, s, _STRAY_INNER, d.hud_m7_wobble_px * 0.25), with_alpha(d.hud_m7_paper_shade, alpha))
	var lo := maxf(gauge.chunk_lo, gauge.value)
	if gauge.chunk_hi > lo:
		_draw_chunk(ci, rect, s, lo, gauge.chunk_hi, gauge.chunk_age, alpha)
	var color := tone(fill).lerp(Color.WHITE, gauge.flash * 0.7)
	_draw_fill(ci, rect, s, gauge.value, with_alpha(color, alpha))


## The damage chunk: the span lo..hi of the bar, flat, in an ink edge. It hangs for hud_m7_chunk_hold_s, then falls (faster and
## faster) and turns, and goes out over the last of the fall.
static func _draw_chunk(ci: CanvasItem, rect: Rect2, slant: float, lo: float, hi: float, age_s: float, alpha: float) -> void:
	var d := Tuning.data
	var shift := slant * rect.size.y
	var span := rect.size.x - shift
	var x_lo := clampf(lo, 0.0, 1.0) * span
	var x_hi := clampf(hi, 0.0, 1.0) * span
	if x_hi - x_lo < 1.0:
		return
	var fall := clampf((age_s - d.hud_m7_chunk_hold_s) / maxf(d.hud_m7_chunk_fall_s, 0.01), 0.0, 1.0)
	var corners := PackedVector2Array([
		Vector2(rect.position.x + shift + x_lo, rect.position.y), Vector2(rect.position.x + shift + x_hi, rect.position.y),
		Vector2(rect.position.x + x_hi, rect.end.y), Vector2(rect.position.x + x_lo, rect.end.y),
	])
	var centre := (corners[0] + corners[1] + corners[2] + corners[3]) * 0.25
	var turn := deg_to_rad(d.hud_m7_chunk_spin_deg) * fall
	var move := Vector2(0.0, d.hud_m7_chunk_drop_px * fall * fall)
	var fade := alpha * (1.0 - clampf((fall - 0.7) / 0.3, 0.0, 1.0))
	if fade <= 0.0:
		return
	var edge := 2.5
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 4:
		var offset := corners[i] - centre
		var grown := offset + offset.normalized() * edge * 1.4
		outer.append(centre + grown.rotated(turn) + move)
		inner.append(centre + offset.rotated(turn) + move)
	ci.draw_colored_polygon(outer, with_alpha(d.hud_m7_ink, fade))
	ci.draw_colored_polygon(inner, with_alpha(d.hud_m7_chunk, fade))


## Text with an optional ink outline. `pos` is the left end of the baseline (or of the
## `width` box when aligned).
static func draw_text(ci: CanvasItem, pos: Vector2, text: String, font_size: int, color: Color,
		outline: int = 0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
		width: float = -1.0, font: Font = null) -> void:
	var used_font := font if font != null else bold_font()
	if comic():
		color = tone(color)
		var ink := Color(Tuning.data.hud_m7_ink, color.a)
		if outline > 0:
			# Lettering over the picture sits in a thick ink edge with a hard offset shadow, like a drawn sound effect.
			var drop := Vector2.ONE * Tuning.data.hud_m7_text_shadow_px
			ci.draw_string_outline(used_font, pos + drop, text, align, width, font_size, outline, ink)
			ci.draw_string(used_font, pos + drop, text, align, width, font_size, ink)
			ci.draw_string_outline(used_font, pos, text, align, width, font_size, outline, ink)
		ci.draw_string(used_font, pos, text, align, width, font_size, color)
		return
	if outline > 0:
		ci.draw_string_outline(used_font, pos, text, align, width, font_size, outline, Color(INK, color.a))
	ci.draw_string(used_font, pos, text, align, width, font_size, color)


static func _draw_fill(ci: CanvasItem, rect: Rect2, slant: float, ratio: float, color: Color) -> void:
	var shift := slant * rect.size.y
	var length := clampf(ratio, 0.0, 1.0) * (rect.size.x - shift)
	# Skip slivers: a near-zero-area polygon fails to triangulate and logs an error.
	if length < 0.5:
		return
	var x0 := rect.position.x
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(x0 + shift, rect.position.y),
		Vector2(x0 + shift + length, rect.position.y),
		Vector2(x0 + length, rect.end.y),
		Vector2(x0, rect.end.y),
	]), color)
