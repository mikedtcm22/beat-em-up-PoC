class_name EnemyHealthBars
extends Control
## Small over-head health bars (Spec §5). An actor in group "enemy" (but not one in group
## "boss": the boss has the big bottom bar, BossHealthBar) gets one for
## `show_seconds` after it takes a hit (CombatEvents.hit_landed, or a health drop through
## CombatEvents.health_changed). Each bar sits just above the body as it is drawn, seen
## through the viewport's current Camera3D (screen_anchor_of(): over the head of a body on
## its feet, over the middle of one lying, flying or held bent over), and is hidden while
## the head is behind the camera or the body is hidden (a KO's blink, a comeback's
## blink-in). A KO'd actor's bar fades out once the killing hit's chunk has drained, and by
## the time the body starts blinking at the latest (an empty bar over a lying body adds
## nothing); it is dropped when the actor is freed or blinks off (CombatEvents.vanished).
## Full-rect, draws every bar itself. Driven by GameHud.advance(). Presentation: it only
## reads the actors.

## The drawn body's joints a bar stays above on screen, each raised by body_margin_m
## (screen_anchor_of()); the head's top counts as it is.
const _BODY_POINTS: Array[StringName] = [
	&"Head", &"EyePoint", &"UpperChest", &"ChestPoint", &"Hips",
	&"LeftUpperArm", &"RightUpperArm", &"LeftElbowPoint", &"RightElbowPoint",
	&"LeftFistPoint", &"RightFistPoint", &"LeftKneePoint", &"RightKneePoint",
	&"LeftFootPoint", &"RightFootPoint",
]
## The gauge's ink border, in pixels.
const _BORDER_PX := 2.0

## Seconds a bar stays up after the latest hit.
@export var show_seconds: float = 2.0
## Fade-out at the end of a bar's life, in seconds.
@export var fade_seconds: float = 0.25
@export var bar_size: Vector2 = Vector2(92.0, 11.0)
## Gap between the projected anchor point and the bottom of the bar, in pixels.
@export var lift_px: float = 6.0
## How far the body reaches above its joints (the chest's half depth, a shoulder), in meters:
## a bar over a lying, bent or held body clears its back (screen_anchor_of()).
@export var body_margin_m: float = 0.15
@export var slant: float = 0.35


## One live bar.
class Bar:
	extends RefCounted
	var actor: CombatActor
	var time_left: float = 0.0
	var last_health: float = 0.0
	var gauge := HealthGauge.new()
	var on_screen: bool = false
	var screen_position: Vector2 = Vector2.ZERO


var _bars: Array[Bar] = []
# Last health seen per enemy (instance id), so a new bar can start from the pre-hit value.
var _known_health: Dictionary[int, float] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## CombatEvents.hit_landed: show (or refresh) the victim's bar if it is an enemy.
func on_hit_landed(hit: HitInfo) -> void:
	if hit == null or not is_instance_valid(hit.victim):
		return
	var victim := hit.victim as CombatActor
	if victim != null and _wants_bar(victim):
		_touch(victim)


## CombatEvents.health_changed: a drop on an enemy shows or refreshes its bar; any other
## change only updates a bar that is already showing. A drop is measured from the last
## health seen for that enemy (its max health if none), so a repeated or rising value on
## an enemy that is already hurt does not bring its bar back.
func on_health_changed(actor: Node3D, health: float, max_health: float) -> void:
	if not is_instance_valid(actor):
		return
	var enemy := actor as CombatActor
	if enemy == null or not _wants_bar(enemy):
		return
	var bar := _find(enemy)
	if bar == null:
		var before: float = _known_health.get(enemy.get_instance_id(), max_health)
		if health < before:
			_touch(enemy)
	elif health < bar.last_health:
		_touch(enemy)
	else:
		bar.last_health = health
	_remember_health(enemy, health)


## CombatEvents.vanished: a KO'd enemy that blinked off loses its bar at once.
func on_vanished(actor: Node3D) -> void:
	for i: int in range(_bars.size() - 1, -1, -1):
		if _bars[i].actor == actor:
			_bars.remove_at(i)
	queue_redraw()


## Age every bar by `delta` seconds, drop expired or freed ones, and re-project the
## rest through the viewport's current Camera3D.
func advance(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	for i: int in range(_bars.size() - 1, -1, -1):
		var bar := _bars[i]
		bar.time_left -= delta
		if bar.time_left <= 0.0 or not is_instance_valid(bar.actor) or not bar.actor.is_inside_tree():
			_bars.remove_at(i)
			continue
		bar.last_health = bar.actor.health
		_remember_health(bar.actor, bar.actor.health)
		bar.gauge.set_target(HealthGauge.ratio_of(bar.actor))
		bar.gauge.advance(delta)
		if bar.actor.is_ko():
			_end_ko_bar(bar)
		bar.on_screen = false
		var shown := bar.actor.rig == null or bar.actor.rig.visible
		if shown and camera != null and camera.is_inside_tree():
			var anchor := screen_anchor_of(bar.actor, camera)
			if anchor.is_finite():
				bar.screen_position = anchor
				bar.on_screen = true
	queue_redraw()


## Where `actor`'s bar sits on `camera`'s screen (canvas pixels; the bar's bottom is
## `lift_px` above it): over the body as it is drawn, in any view.
## - Across: over its hips as drawn, the middle of the body: under the head while it stands,
##   the middle of a body lying or flying, and the far side of one held bent over (its head
##   is at the holder's waist, and a bar over it would sit on the holder).
## - Up: at the highest the drawn body shows on that screen, its head's top or any joint
##   raised by `body_margin_m`. The head's top is get_head_top_position() (which floats a
##   little above the head) brought over the head's joint at its height: the point itself
##   floats beside a bent or lying head, over empty floor. A head bent toward the camera,
##   arms flung up, a bent back or a body lying on the floor stay under the bar, and the bar
##   stays about as close above them as over a standing head.
## Vector2.INF while the head is behind the camera.
func screen_anchor_of(actor: CombatActor, camera: Camera3D) -> Vector2:
	var head := actor.get_head_top_position()
	if actor.rig != null:
		var neck := actor.rig.get_visual_point_transform(&"Head").origin
		head = Vector3(neck.x, maxf(head.y, neck.y), neck.z)
	if camera.is_position_behind(head):
		return Vector2.INF
	var screen := camera.unproject_position(head)
	if actor.rig == null:
		return screen
	var hips := actor.rig.get_visual_point_transform(&"Hips").origin
	if not camera.is_position_behind(hips):
		screen.x = camera.unproject_position(hips).x
	for point: StringName in _BODY_POINTS:
		var p := actor.rig.get_visual_point_transform(point).origin + Vector3.UP * body_margin_m
		if not camera.is_position_behind(p):
			screen.y = minf(screen.y, camera.unproject_position(p).y)
	return screen


## Remove every bar and the remembered health values.
func clear() -> void:
	_bars.clear()
	_known_health.clear()
	queue_redraw()


## Bars alive (on or off screen).
func bar_count() -> int:
	return _bars.size()


## Bars currently drawn (anchor in front of the camera).
func visible_bar_count() -> int:
	var count := 0
	for bar: Bar in _bars:
		if bar.on_screen:
			count += 1
	return count


## True while `actor` has a live bar (on or off screen).
func has_bar(actor: CombatActor) -> bool:
	return _find(actor) != null


## Projected anchor (canvas pixels) of `actor`'s bar, or Vector2(-1, -1) without one.
func get_bar_screen_position(actor: CombatActor) -> Vector2:
	var bar := _find(actor)
	return bar.screen_position if bar != null and bar.on_screen else Vector2(-1.0, -1.0)


## True when `bar` is drawn: on screen and its gauge, with the ink border, overlaps this
## canvas. A head just in front of the camera plane projects millions of pixels away, where
## float precision collapses the thin fill and the polygon fails to triangulate.
func is_drawn(bar: Bar) -> bool:
	return bar.on_screen and _rect_of(bar).grow(_BORDER_PX).intersects(Rect2(Vector2.ZERO, size))


func _rect_of(bar: Bar) -> Rect2:
	return Rect2(bar.screen_position - Vector2(bar_size.x * 0.5, bar_size.y + lift_px), bar_size)


func _draw() -> void:
	for bar: Bar in _bars:
		if not is_drawn(bar):
			continue
		var alpha := clampf(bar.time_left / fade_seconds, 0.0, 1.0) if fade_seconds > 0.0 else 1.0
		HudStyle.draw_gauge(self, _rect_of(bar), slant, bar.gauge, HudStyle.HEALTH, _BORDER_PX, alpha)


## A KO'd actor's bar: once the killing hit's chunk has drained (the ghost down to the
## value), and by the time the body starts blinking (Tuning.ko_linger_s into the KO) at the
## latest, it fades out over `fade_seconds`.
func _end_ko_bar(bar: Bar) -> void:
	var end := Tuning.data.ko_linger_s - bar.actor.state_frame / float(Engine.physics_ticks_per_second)
	if bar.gauge.ghost <= bar.gauge.value + 0.0001:
		end = minf(end, fade_seconds)
	bar.time_left = minf(bar.time_left, maxf(end, 0.0))


## An enemy gets an over-head bar; the boss (group "boss") does not, it has its own bar.
func _wants_bar(actor: CombatActor) -> bool:
	return actor.is_in_group(&"enemy") and not actor.is_in_group(&"boss")


func _touch(actor: CombatActor) -> void:
	var bar := _find(actor)
	if bar == null:
		bar = Bar.new()
		bar.actor = actor
		# Start from the last health we saw (full if none), so the first hit shows its chunk
		# as a ghost no matter whether hit_landed or health_changed arrives first.
		var before: float = _known_health.get(actor.get_instance_id(), actor.max_health)
		bar.gauge.reset(before / actor.max_health if actor.max_health > 0.0 else 0.0)
		_bars.append(bar)
	bar.time_left = show_seconds
	bar.last_health = actor.health
	bar.gauge.set_target(HealthGauge.ratio_of(actor))


func _find(actor: CombatActor) -> Bar:
	for bar: Bar in _bars:
		if is_instance_valid(bar.actor) and bar.actor == actor:
			return bar
	return null


func _remember_health(actor: CombatActor, health: float) -> void:
	if _known_health.size() > 64:
		for id: int in _known_health.keys():
			if not is_instance_id_valid(id):
				_known_health.erase(id)
	_known_health[actor.get_instance_id()] = health
