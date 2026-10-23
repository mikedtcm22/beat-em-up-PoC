class_name EnemyHealthBars
extends Control
## Small over-head health bars (Spec §5). An actor in group "enemy" gets one for
## `show_seconds` after it takes a hit (CombatEvents.hit_landed, or a health drop through
## CombatEvents.health_changed). Each bar is anchored above actor.get_head_top_position(),
## projected through the viewport's current Camera3D, hidden while that point is behind
## the camera, and dropped when the actor is freed. Full-rect, draws every bar itself.
## Driven by GameHud.advance().

## Seconds a bar stays up after the latest hit.
@export var show_seconds: float = 2.0
## Fade-out at the end of a bar's life, in seconds.
@export var fade_seconds: float = 0.25
@export var bar_size: Vector2 = Vector2(92.0, 11.0)
## Gap between the projected anchor point and the bottom of the bar, in pixels.
@export var lift_px: float = 6.0
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
	if victim != null and victim.is_in_group(&"enemy"):
		_touch(victim)


## CombatEvents.health_changed: a drop on an enemy shows or refreshes its bar; any other
## change only updates a bar that is already showing. A drop is measured from the last
## health seen for that enemy (its max health if none), so a repeated or rising value on
## an enemy that is already hurt does not bring its bar back.
func on_health_changed(actor: Node3D, health: float, max_health: float) -> void:
	if not is_instance_valid(actor):
		return
	var enemy := actor as CombatActor
	if enemy == null or not enemy.is_in_group(&"enemy"):
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
		bar.on_screen = false
		if camera != null and camera.is_inside_tree():
			var anchor := bar.actor.get_head_top_position()
			if not camera.is_position_behind(anchor):
				bar.screen_position = camera.unproject_position(anchor)
				bar.on_screen = true
	queue_redraw()


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


func _draw() -> void:
	for bar: Bar in _bars:
		if not bar.on_screen:
			continue
		var alpha := clampf(bar.time_left / fade_seconds, 0.0, 1.0) if fade_seconds > 0.0 else 1.0
		var top_left := bar.screen_position - Vector2(bar_size.x * 0.5, bar_size.y + lift_px)
		HudStyle.draw_gauge(self, Rect2(top_left, bar_size), slant, bar.gauge, HudStyle.HEALTH, 2.0, alpha)


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
