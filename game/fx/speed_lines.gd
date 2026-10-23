class_name SpeedLines
extends Control
## Radial comic speed lines over the view (Spec §6, "Speed lines"): ink streaks from past
## the screen edges in toward a focus point, tapering to points and leaving a clear middle
## (Tuning.vfx_speed_lines_clear), redrawn in new places every few real frames (the comic
## flicker) and fading out. Each streak is one row of speed_lines.png (VfxArt).
## VfxDirector starts them on finishers (focused on the contact point on screen) and on the
## player's lunges (focused on the view center, lighter). Their strength is scaled by
## Tuning.screen_shake_intensity, the motion comfort option: at 0 there are none.
## Driven by advance(); drawn under the HUD.

## Screen point the lines converge on (this control's coordinates).
var focus: Vector2 = Vector2.ZERO
## Seconds of effect time left, out of `duration`, and the opacity at the start.
var time_left: float = 0.0
var duration: float = 0.0
var opacity: float = 0.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _since_shuffle: float = 0.0
## One per line: x = angle (radians), y = inner end (times the clear radius), z = texture
## row, w = thickness multiplier.
var _lines: Array[Vector4] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


## Show lines converging on `focus_px` for `seconds` at `strength` opacity (times the
## shake-intensity comfort option). Lines already showing more strongly are kept.
func start(focus_px: Vector2, seconds: float, strength: float) -> void:
	var alpha := strength * Tuning.data.screen_shake_intensity
	if seconds <= 0.0 or alpha <= 0.0 or Tuning.data.vfx_speed_lines_count <= 0:
		return
	if is_active() and current_alpha() > alpha:
		return
	focus = focus_px
	duration = seconds
	time_left = seconds
	opacity = alpha
	_shuffle()
	visible = true
	queue_redraw()


func is_active() -> bool:
	return time_left > 0.0


## Opacity now: the start opacity fading linearly to 0 over the duration.
func current_alpha() -> float:
	if time_left <= 0.0 or duration <= 0.0:
		return 0.0
	return opacity * clampf(time_left / duration, 0.0, 1.0)


func line_count() -> int:
	return _lines.size() if is_active() else 0


## Step `dt` seconds of effect time and `real_dt` real seconds (the flicker).
func advance(dt: float, real_dt: float) -> void:
	if time_left <= 0.0:
		return
	time_left -= dt
	_since_shuffle += real_dt
	if _since_shuffle >= Tuning.data.vfx_speed_lines_redraw_frames / 60.0 - 0.0001:
		_shuffle()
	if time_left <= 0.0:
		time_left = 0.0
		visible = false
	queue_redraw()


func _shuffle() -> void:
	_since_shuffle = 0.0
	_lines.clear()
	var count := Tuning.data.vfx_speed_lines_count
	var phase := _rng.randf() * TAU
	for i in count:
		var angle := phase + TAU * (i + _rng.randf_range(-0.35, 0.35)) / count
		_lines.append(Vector4(angle, _rng.randf_range(1.0, 1.4), _rng.randi() % VfxArt.SPEED_LINE_ROWS,
				_rng.randf_range(0.55, 1.2)))


func _draw() -> void:
	var tex := VfxArt.texture(&"speed_lines")
	var alpha := current_alpha()
	if tex == null or alpha <= 0.0:
		return
	var row_h := tex.get_height() / float(VfxArt.SPEED_LINE_ROWS)
	var clear := Tuning.data.vfx_speed_lines_clear * size.length() * 0.5
	var reach := 0.0
	for corner: Vector2 in [Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]:
		reach = maxf(reach, focus.distance_to(corner))
	reach += row_h
	var color := Color(HudStyle.INK, alpha)
	for line: Vector4 in _lines:
		var dir := Vector2.from_angle(line.x)
		var inner := clear * line.y
		var length := reach - inner
		if length <= 0.0:
			continue
		# The streak's thick end sits off screen; it points in toward the focus.
		draw_set_transform(focus + dir * reach, (-dir).angle(),
				Vector2(length / tex.get_width(), line.w * Tuning.data.vfx_speed_lines_width))
		draw_texture_rect_region(tex, Rect2(0.0, -row_h * 0.5, tex.get_width(), row_h),
				Rect2(0.0, row_h * int(line.z), tex.get_width(), row_h), color)
	draw_set_transform(Vector2.ZERO)
