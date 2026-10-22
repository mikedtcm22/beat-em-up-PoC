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

static var _bold_font: FontVariation


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


## A comic panel: drop shadow, ink border `border` px wide around `rect`, flat `fill`.
static func draw_panel(ci: CanvasItem, rect: Rect2, slant: float, fill: Color, border: float,
		shadow: Vector2 = Vector2(6.0, 6.0), alpha: float = 1.0) -> void:
	var outer := rect.grow(border)
	if shadow != Vector2.ZERO:
		var shadow_quad := slanted_quad(Rect2(outer.position + shadow, outer.size), slant)
		ci.draw_colored_polygon(shadow_quad, Color(INK, 0.5 * alpha))
	ci.draw_colored_polygon(slanted_quad(outer, slant), with_alpha(INK, alpha))
	ci.draw_colored_polygon(slanted_quad(rect, slant), with_alpha(fill, alpha))


## A slanted health bar inside an ink border: trough, white damage ghost, then the fill
## (flashed toward white right after damage).
static func draw_gauge(ci: CanvasItem, rect: Rect2, slant: float, gauge: HealthGauge, fill: Color,
		border: float, alpha: float = 1.0) -> void:
	ci.draw_colored_polygon(slanted_quad(rect.grow(border), slant), with_alpha(INK, alpha))
	ci.draw_colored_polygon(slanted_quad(rect, slant), with_alpha(TROUGH, alpha))
	_draw_fill(ci, rect, slant, gauge.ghost, with_alpha(GHOST, alpha))
	var color := fill.lerp(Color.WHITE, gauge.flash * 0.7)
	_draw_fill(ci, rect, slant, gauge.value, with_alpha(color, alpha))


## Text with an optional ink outline. `pos` is the left end of the baseline (or of the
## `width` box when aligned).
static func draw_text(ci: CanvasItem, pos: Vector2, text: String, font_size: int, color: Color,
		outline: int = 0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
		width: float = -1.0, font: Font = null) -> void:
	var used_font := font if font != null else bold_font()
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
