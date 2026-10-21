class_name HealthGauge
extends RefCounted
## Displayed state of one HUD health bar: the shown fraction, a white "damage taken" ghost
## that lingers and then drains down to it, and a short flash on damage. Presentation only;
## fed from an actor's health every frame.

## Shown health fraction, 0..1.
var value: float = 1.0
## Lagging fraction behind `value` after damage, 0..1 (always >= value).
var ghost: float = 1.0
## Damage flash, 1 on the frame damage arrives, decays to 0.
var flash: float = 0.0
## Seconds the ghost holds before draining.
var ghost_delay_s: float = 0.35
## Ghost drain speed in fractions per second.
var ghost_drain_per_s: float = 0.9
## Flash decay per second.
var flash_decay_per_s: float = 5.0

var _hold: float = 0.0


## Jump straight to `ratio` with no ghost or flash (new target, revive, first read).
func reset(ratio: float) -> void:
	value = clampf(ratio, 0.0, 1.0)
	ghost = value
	flash = 0.0
	_hold = 0.0


## Follow a new health fraction. A drop leaves a ghost and flashes; a rise snaps up.
func set_target(ratio: float) -> void:
	var target := clampf(ratio, 0.0, 1.0)
	if target < value - 0.0001:
		ghost = maxf(ghost, value)
		_hold = ghost_delay_s
		flash = 1.0
	value = target
	ghost = maxf(ghost, value)


## Hold, then drain the ghost toward `value`, and decay the flash, over `delta` seconds.
func advance(delta: float) -> void:
	if _hold > 0.0:
		_hold -= delta
	else:
		ghost = move_toward(ghost, value, ghost_drain_per_s * delta)
	flash = move_toward(flash, 0.0, flash_decay_per_s * delta)


## Health fraction of `actor`, safe for a zero max.
static func ratio_of(actor: CombatActor) -> float:
	if actor.max_health <= 0.0:
		return 0.0
	return clampf(actor.health / actor.max_health, 0.0, 1.0)
