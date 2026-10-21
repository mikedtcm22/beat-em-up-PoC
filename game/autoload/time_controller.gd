extends Node
## The only path for presentation to affect the simulation (autoload "TimeController").
## Hitstop freezes specific actors; slow-mo and the debug time scale scale everyone.
## Engine.time_scale stays 1.0: actors scale their own sim step via scale_for().

## Cheat/debug multiplier on the whole simulation (F4: 0.25x or 1x).
var debug_scale: float = 1.0

# instance id -> Vector2i(first frozen physics frame, first unfrozen physics frame)
var _hitstop: Dictionary[int, Vector2i] = {}
var _slowmo_scale: float = 1.0
var _slowmo_left: float = 0.0
var _slowmo_delay: float = 0.0
var _pending_slowmo_scale: float = 1.0
var _pending_slowmo_duration: float = 0.0


## Freeze `actors` for `duration_s` (rounded to whole physics ticks, minimum 1), starting
## on the next physics tick so attacker and victim freeze for the same ticks no matter
## which processed first. Overlapping requests extend to the later end.
func hitstop(actors: Array, duration_s: float) -> void:
	if duration_s <= 0.0:
		return
	var ticks := maxi(1, roundi(duration_s * Engine.physics_ticks_per_second))
	var start := Engine.get_physics_frames() + 1
	for actor: Object in actors:
		if actor == null:
			continue
		var id := actor.get_instance_id()
		var window := Vector2i(start, start + ticks)
		if _hitstop.has(id):
			var old: Vector2i = _hitstop[id]
			window = Vector2i(mini(old.x, start), maxi(old.y, start + ticks))
		_hitstop[id] = window


## Scale the whole simulation to `scale` for `duration_s` real seconds, starting after
## `delay_s` (finishers start slow-mo once their hitstop ends).
func slowmo(scale: float, duration_s: float, delay_s: float = 0.0) -> void:
	if delay_s > 0.0:
		_slowmo_delay = delay_s
		_pending_slowmo_scale = scale
		_pending_slowmo_duration = duration_s
	else:
		_slowmo_scale = scale
		_slowmo_left = duration_s


func is_in_hitstop(actor: Object) -> bool:
	if actor == null:
		return false
	var id := actor.get_instance_id()
	if not _hitstop.has(id):
		return false
	var window: Vector2i = _hitstop[id]
	var frame := Engine.get_physics_frames()
	return frame >= window.x and frame < window.y


func is_slowmo() -> bool:
	return _slowmo_left > 0.0


## Global sim scale (slow-mo x debug), for sim objects that aren't actors.
func sim_scale() -> float:
	return (_slowmo_scale if _slowmo_left > 0.0 else 1.0) * debug_scale


## Sim scale for one actor: 0 during its hitstop, otherwise the global scale.
func scale_for(actor: Object) -> float:
	if is_in_hitstop(actor):
		return 0.0
	return sim_scale()


func clear() -> void:
	_hitstop.clear()
	_slowmo_left = 0.0
	_slowmo_delay = 0.0


func _ready() -> void:
	# Run after every actor each physics tick, so timers expire at the end of a tick.
	process_physics_priority = 1000


func _physics_process(delta: float) -> void:
	if not _hitstop.is_empty():
		var frame := Engine.get_physics_frames()
		for id: int in _hitstop.keys():
			if _hitstop[id].y <= frame + 1 or not is_instance_id_valid(id):
				_hitstop.erase(id)
	# Slow-mo counts real time.
	if _slowmo_delay > 0.0:
		_slowmo_delay -= delta
		if _slowmo_delay <= 0.0:
			_slowmo_scale = _pending_slowmo_scale
			_slowmo_left = _pending_slowmo_duration
	elif _slowmo_left > 0.0:
		_slowmo_left -= delta
