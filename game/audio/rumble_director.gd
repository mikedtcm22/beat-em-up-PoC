class_name RumbleDirector
extends Node
## Controller rumble (Spec §6, the rumble row of the tier table) for every hit the player
## lands or takes (`hit_landed` with the player as attacker or victim; a thrown weapon or a
## launched body counts as the player's when the player threw or launched it). Presentation
## only: it subscribes to CombatEvents and never writes game state.
##
## - Light: one short, low pulse. Heavy: one medium pulse. Finisher: a strong double pulse
##   (two pulses `rumble_finisher_gap_ms` apart).
## - A blocked or parried hit: a light tick. A guard break: the heavy pulse.
##
## Each pulse drives the weak (high-frequency) and strong (low-frequency) motors of every
## connected joypad with `Input.start_joy_vibration()`; every strength and length is in
## Tuning's "Audio" group (`rumble_*`), times `rumble_strength`, read when the pulse fires.
## `rumble_enabled` turns it all off. The second finisher pulse runs on real (_process)
## time, so hitstop and slow-mo don't stretch it.
##
## A joypad plays one vibration at a time (start_joy_vibration replaces the running one), so
## a pulse that comes while another runs takes the stronger of each motor and lasts until
## the later end: a block tick or a light hit never cuts a heavy or finisher pulse short.
## Pulses due at the same moment (a finisher hitting several bodies) queue once.

## Test stub: when valid, every pulse calls `vibrate.call(weak, strong, duration_s)`
## instead of Input.start_joy_vibration() on each connected joypad.
var vibrate: Callable

## Seconds of _process time.
var _clock_s: float = 0.0
## Pulses waiting for their time, earliest first: {at (s), weak, strong, ms}.
var _queued: Array[Dictionary] = []
## The vibration running now: its motors and when (_clock_s) it ends.
var _weak_now: float = 0.0
var _strong_now: float = 0.0
var _until_s: float = 0.0


func _init() -> void:
	name = &"RumbleDirector"


func _ready() -> void:
	add_to_group(&"rumble_director")
	CombatEvents.hit_landed.connect(_on_hit_landed)


func _exit_tree() -> void:
	_queued.clear()
	_until_s = 0.0
	if not vibrate.is_valid():
		for device in Input.get_connected_joypads():
			Input.stop_joy_vibration(device)


func _notification(what: int) -> void:
	# Paused (the pause menu) between a finisher's two pulses, the second would come out of
	# the blue on unpausing.
	if what == NOTIFICATION_PAUSED:
		_queued.clear()


func _process(delta: float) -> void:
	_clock_s += delta
	while not _queued.is_empty() and float(_queued[0].at) <= _clock_s:
		var due: Dictionary = _queued.pop_front()
		if Tuning.data.rumble_enabled:
			pulse(due.weak, due.strong, due.ms)


## One pulse: both motors (0..1, times rumble_strength) for `ms` milliseconds, merged with
## a pulse still running (the stronger of each motor, until the later end).
func pulse(weak: float, strong: float, ms: float) -> void:
	var scale := Tuning.data.rumble_strength
	var w := clampf(weak * scale, 0.0, 1.0)
	var s := clampf(strong * scale, 0.0, 1.0)
	var seconds := ms / 1000.0
	if seconds <= 0.0 or (w <= 0.0 and s <= 0.0):
		return
	if _clock_s < _until_s:
		w = maxf(w, _weak_now)
		s = maxf(s, _strong_now)
		seconds = maxf(seconds, _until_s - _clock_s)
	_weak_now = w
	_strong_now = s
	_until_s = _clock_s + seconds
	if vibrate.is_valid():
		vibrate.call(w, s, seconds)
		return
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, w, s, seconds)


## Pulses still waiting (the finisher's second pulse).
func queued_pulses() -> int:
	return _queued.size()


func _on_hit_landed(hit: HitInfo) -> void:
	var tuning := Tuning.data
	if not tuning.rumble_enabled or not _involves_player(hit):
		return
	if hit.blocked and not hit.guard_broken:
		pulse(tuning.rumble_block_weak, tuning.rumble_block_strong, tuning.rumble_block_ms)
	elif hit.guard_broken or hit.tier == CombatTypes.HitTier.HEAVY:
		pulse(tuning.rumble_heavy_weak, tuning.rumble_heavy_strong, tuning.rumble_heavy_ms)
	elif hit.tier == CombatTypes.HitTier.FINISHER:
		pulse(tuning.rumble_finisher_weak, tuning.rumble_finisher_strong, tuning.rumble_finisher_ms)
		_queue(
			(tuning.rumble_finisher_ms + tuning.rumble_finisher_gap_ms) / 1000.0,
			tuning.rumble_finisher_weak,
			tuning.rumble_finisher_strong,
			tuning.rumble_finisher_ms
		)
	else:
		pulse(tuning.rumble_light_weak, tuning.rumble_light_strong, tuning.rumble_light_ms)


func _queue(delay_s: float, weak: float, strong: float, ms: float) -> void:
	var at := _clock_s + delay_s
	for due in _queued:
		if is_equal_approx(float(due.at), at) and due.weak == weak and due.strong == strong and due.ms == ms:
			return
	_queued.append({at = at, weak = weak, strong = strong, ms = ms})
	_queued.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.at) < float(b.at))


static func _involves_player(hit: HitInfo) -> bool:
	return (
		(is_instance_valid(hit.attacker) and hit.attacker.is_in_group(&"player"))
		or (is_instance_valid(hit.victim) and hit.victim.is_in_group(&"player"))
	)
