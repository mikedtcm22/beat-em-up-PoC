extends Node
## The only path for presentation to write to the simulation (autoload "TimeController").
## The one thing the simulation reads back from presentation is the visual ragdoll's drawn pose,
## for the get-up, a dummy's respawn and its walk home (game/actors/ragdoll.gd).
## Hitstop freezes specific actors; slow-mo and the debug time scale scale everyone.
## Engine.time_scale stays 1.0: actors scale their own sim step via scale_for().

## Cheat/debug multiplier on the whole simulation (F4: 0.25x or 1x). It also stretches
## hitstop and the slow-mo timers, so a slowed-down hit keeps its feel, only slower.
var debug_scale: float = 1.0

# instance id -> Vector2i(first frozen physics frame, first unfrozen physics frame)
var _hitstop: Dictionary[int, Vector2i] = {}
var _slowmo_scale: float = 1.0
var _slowmo_left: float = 0.0
var _slowmo_delay: float = 0.0
var _pending_slowmo_scale: float = 1.0
var _pending_slowmo_duration: float = 0.0
# instance id -> true for every presentation holder that has the whole simulation stopped (hold_sim()).
var _sim_holds: Dictionary[int, bool] = {}


## Freeze `actors` for `duration_s` (rounded to whole physics ticks, minimum 1; divided by
## debug_scale, so 0.25x freezes four times as long), starting on the next physics tick so
## attacker and victim freeze for the same ticks no matter which processed first.
## Overlapping requests extend to the later end.
func hitstop(actors: Array, duration_s: float) -> void:
	if duration_s <= 0.0:
		return
	var stretch := 1.0 / debug_scale if debug_scale > 0.0 else 1.0
	var ticks := maxi(1, roundi(duration_s * stretch * Engine.physics_ticks_per_second))
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


## Scale the whole simulation to `scale` for `duration_s` seconds, starting after `delay_s`
## (finishers start slow-mo once their hitstop ends). Both count real time times
## debug_scale, like hitstop.
func slowmo(scale: float, duration_s: float, delay_s: float = 0.0) -> void:
	if delay_s > 0.0:
		_slowmo_delay = delay_s
		_pending_slowmo_scale = scale
		_pending_slowmo_duration = duration_s
	else:
		_slowmo_scale = scale
		_slowmo_left = duration_s


## Stop (`on`) or resume the whole simulation for `source`, a presentation node (the M7 cut-in cards: a card holds the
## game while it is up). Several sources may hold at once; the simulation runs again when the last one lets go.
## The hold is not a pause: nothing else changes (the HUD keeps running, GameInput.paused stays false).
func hold_sim(source: Object, on: bool) -> void:
	if source == null:
		return
	if on:
		_sim_holds[source.get_instance_id()] = true
	else:
		_sim_holds.erase(source.get_instance_id())


## True while any source holds the simulation (hold_sim()).
func is_sim_held() -> bool:
	for id: int in _sim_holds.keys():
		if is_instance_id_valid(id):
			return true
		_sim_holds.erase(id)
	return false


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
	if is_sim_held():
		return 0.0
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
	_sim_holds.clear()


func _ready() -> void:
	# Run after every actor each physics tick, so timers expire at the end of a tick.
	process_physics_priority = 1000


func _physics_process(delta: float) -> void:
	if not _hitstop.is_empty():
		var frame := Engine.get_physics_frames()
		for id: int in _hitstop.keys():
			if _hitstop[id].y <= frame + 1 or not is_instance_id_valid(id):
				_hitstop.erase(id)
	# Slow-mo counts real time, slowed by the debug scale like hitstop.
	var step := delta * debug_scale
	if _slowmo_delay > 0.0:
		_slowmo_delay -= step
		if _slowmo_delay <= 0.0:
			_slowmo_scale = _pending_slowmo_scale
			_slowmo_left = _pending_slowmo_duration
	elif _slowmo_left > 0.0:
		_slowmo_left -= step
