class_name SpeedLines
extends Control
## Radial comic speed lines over the view (Spec §6, "Speed lines"): ink streaks from past
## the screen edges in toward a focus point, tapering to points and leaving a clear middle
## (Tuning.vfx_speed_lines_clear), redrawn in new places every few real frames (the comic
## flicker) and fading out. Each streak is one row of speed_lines.png (VfxArt), held here.
## VfxDirector starts them on finishers (focused near the contact point on screen) and on
## the player's lunges (focused on the view center, lighter), and hands them the screen
## rects of the live comic effects each frame (keep_clear): a streak that would run into
## one stops at its edge, so the lines frame the burst and the word instead of crossing them.
## Their strength is scaled by Tuning.screen_shake_intensity, the motion comfort option: at
## 0 there are none. With the photosensitivity toggle off (Tuning.impact_frame_enabled)
## they never flicker: one set of lines fades out in place.
## Driven by advance(); drawn under the HUD.

## Screen point the lines converge on (this control's coordinates).
var focus: Vector2 = Vector2.ZERO
## Seconds of effect time left, out of `duration`, and the opacity at the start.
var time_left: float = 0.0
var duration: float = 0.0
var opacity: float = 0.0
## Screen rects (this control's coordinates) no streak may enter, set every frame.
var keep_clear: Array[Rect2] = []
## Times the lines were placed since start() (1 = never redrawn in new places).
var shuffles: int = 0

var _tex: Texture2D = VfxArt.texture(&"speed_lines")
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
	shuffles = 0
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


## The lines as placed now (angle, inner end, texture row, thickness; tests).
func lines() -> Array[Vector4]:
	return _lines.duplicate()


## Step `dt` seconds of effect time and `real_dt` real seconds (the flicker).
func advance(dt: float, real_dt: float) -> void:
	if time_left <= 0.0:
		return
	time_left -= dt
	_since_shuffle += real_dt
	if Tuning.data.impact_frame_enabled \
			and _since_shuffle >= Tuning.data.vfx_speed_lines_redraw_frames / float(Engine.physics_ticks_per_second) - 0.0001:
		_shuffle()
	if time_left <= 0.0:
		time_left = 0.0
		visible = false
	queue_redraw()


## Where `line` (one of lines()) runs, as distances from the focus along its angle: x its
## inner end (its point), y its outer end (its thick end, past the screen corners).
func streak_ends(line: Vector4) -> Vector2:
	var reach := 0.0
	for corner: Vector2 in [Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]:
		reach = maxf(reach, focus.distance_to(corner))
	if _tex:
		reach += _tex.get_height() / float(VfxArt.SPEED_LINE_ROWS)
	var clear := Tuning.data.vfx_speed_lines_clear * size.length() * 0.5
	return Vector2(inner_end(line.x, clear * line.y, reach), reach)


## Where the streak at `angle` ends inside (its distance from the focus): `inner`, or
## farther out where it first enters a keep_clear rect coming in from `reach`.
func inner_end(angle: float, inner: float, reach: float) -> float:
	var dir := Vector2.from_angle(angle)
	var outer := focus + dir * reach
	var end := inner
	for rect: Rect2 in keep_clear:
		var t := _ray_enters(outer, -dir, rect)
		if t >= 0.0:
			end = maxf(end, reach - t)
	return end


## The distance along the ray from `from` going `dir` (unit) at which it enters `rect`, 0
## when it starts inside, or -1 when it misses.
static func _ray_enters(from: Vector2, dir: Vector2, rect: Rect2) -> float:
	var t_near := -INF
	var t_far := INF
	for axis in 2:
		var lo := rect.position[axis]
		var hi := rect.end[axis]
		if absf(dir[axis]) < 0.000001:
			if from[axis] < lo or from[axis] > hi:
				return -1.0
			continue
		var t1 := (lo - from[axis]) / dir[axis]
		var t2 := (hi - from[axis]) / dir[axis]
		t_near = maxf(t_near, minf(t1, t2))
		t_far = minf(t_far, maxf(t1, t2))
	if t_near > t_far or t_far < 0.0:
		return -1.0
	return maxf(t_near, 0.0)


func _shuffle() -> void:
	_since_shuffle = 0.0
	shuffles += 1
	_lines.clear()
	var t := Tuning.data
	var count := t.vfx_speed_lines_count
	var phase := _rng.randf() * TAU
	var jitter := t.vfx_speed_lines_jitter
	for i in count:
		var angle := phase + TAU * (i + _rng.randf_range(-jitter, jitter)) / count
		var inner := _rng.randf_range(1.0, maxf(t.vfx_speed_lines_inner_max, 1.0))
		var width := _rng.randf_range(t.vfx_speed_lines_width_min, maxf(t.vfx_speed_lines_width_max, t.vfx_speed_lines_width_min))
		_lines.append(Vector4(angle, inner, _rng.randi() % VfxArt.SPEED_LINE_ROWS, width))


func _draw() -> void:
	var alpha := current_alpha()
	if _tex == null or alpha <= 0.0:
		return
	var row_h := _tex.get_height() / float(VfxArt.SPEED_LINE_ROWS)
	var color := Color(HudStyle.INK, alpha)
	for line: Vector4 in _lines:
		var dir := Vector2.from_angle(line.x)
		var ends := streak_ends(line)
		var inner := ends.x
		var reach := ends.y
		var length := reach - inner
		if length <= 0.0:
			continue
		# The streak's thick end sits off screen; it points in toward the focus.
		draw_set_transform(focus + dir * reach, (-dir).angle(),
				Vector2(length / _tex.get_width(), line.w * Tuning.data.vfx_speed_lines_width))
		draw_texture_rect_region(_tex, Rect2(0.0, -row_h * 0.5, _tex.get_width(), row_h),
				Rect2(0.0, row_h * int(line.z), _tex.get_width(), row_h), color)
	draw_set_transform(Vector2.ZERO)
