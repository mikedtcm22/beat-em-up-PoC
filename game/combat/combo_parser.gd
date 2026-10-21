class_name ComboParser
extends RefCounted
## Turns buffered button presses into move choices using the Spec §4 cadence rules.
##
## Pure logic: no nodes, no Input singleton, no autoload reads. The owner copies window
## sizes from Tuning into the public vars and drives it once per SIM frame (sim frames
## stop during hitstop, so the buffer never expires while the attacker is frozen).
##
## Per-sim-frame call order for the owner:
##   1. tick()                       ages the buffer, hold timers and the post-recovery counter
##   2. press()/release()            this frame's input edges (presses get age 0)
##   3. select(...)                  only when the owner can act (FREE, or in a cancellable recovery)
##   4. notify_started(selection)    when the owner actually starts the selected move
##   5. notify_recovery_ended()      when a move's last recovery frame has played, then
##      take_auto_next()             to chain an auto_next move (flurry -> shove)
##
## Cadence rules (all windows are tunable):
##   - A press stays usable while its age <= buffer_frames (age 0 = the frame it was pressed).
##   - In a cancellable recovery: current move's repeat_input (if repeats remain), then the
##     current move's NORMAL branches, then the move set's interrupt_branches. Presses that
##     match nothing stay buffered (they may still fire once the move ends).
##   - FREE, frames_since_recovery f in [0, pause_min_frames): current NORMAL branches.
##   - FREE, f in [pause_min_frames, pause_max_frames]: current PAUSE branches, then
##     current NORMAL branches (lenient), so `P P · P` and `K · K` work.
##   - Any FREE case falls back to interrupt_branches, then root_branches (a new chain).
##   - f > pause_max_frames resets the chain: the next press uses root_branches.
##   - Releasing P after holding it for >= hold_frames buffers a synthetic P_HOLD press.
##   - Buffered presses are tried oldest first; the first that matches is consumed.
##   - Branches are evaluated in array order; a branch with `require` set only matches if
##     conditions[require] is true.
## Inputs that never appear in branches (e.g. &"JUMP", &"DODGE", &"GRAB") can share the
## buffer: the owner pulls them with consume().


## The result of select(): which move to start and why.
class Selection:
	extends RefCounted
	var move: MoveData
	var input: StringName = &""
	## &"root", &"chain", &"pause", &"repeat", or &"auto".
	var timing: StringName = &"root"
	## 1-based position of `move` in the chain once started.
	var chain_step: int = 1


## Tunable windows, copied from Tuning by the owner.
var buffer_frames: int = 8
var pause_min_frames: int = 12
var pause_max_frames: int = 30
var hold_frames: int = 24

## Root set for the current context (ground, air, hold, weapon). Changing it does not
## reset the chain by itself; owners call reset_chain() when the context changes.
var move_set: MoveSet

## Read-only state, exposed for the HUD, debug draw and tests.
## Last started move (the chain node), or null when there is no chain.
var current: MoveData
## 1-based step of `current` in the chain; 0 when there is no chain.
var chain_step: int = 0
## -1 while `current` is still running; otherwise sim frames since its recovery ended.
var frames_since_recovery: int = -1
## Times `current` has been repeated via repeat_input.
var repeat_count: int = 0


## Advance one sim frame.
func tick() -> void:
	pass


## Register a button press this frame (age 0). Starts P's hold timer.
func press(input: StringName) -> void:
	pass


## Register a button release this frame. Releasing P after hold_frames buffers P_HOLD.
func release(input: StringName) -> void:
	pass


## True while `input` is held (between press and release).
func is_held(input: StringName) -> bool:
	return false


## Sim frames `input` has been held, or 0 if it isn't held.
func held_frames(input: StringName) -> int:
	return 0


## Pick the move for the oldest usable buffered press, consuming that press.
## `in_recovery`: the owner is in a cancellable recovery of `current`.
## `conditions`: StringName -> bool for ComboBranch.require keys.
## Returns null when nothing should start.
func select(in_recovery: bool, conditions: Dictionary = {}) -> Selection:
	return null


## Record that the owner started `selection.move`.
func notify_started(selection: Selection) -> void:
	pass


## Record that the current move's recovery finished (f starts at 0 next tick()).
func notify_recovery_ended() -> void:
	pass


## After notify_recovery_ended(): the current move's auto_next as a Selection, or null.
func take_auto_next() -> Selection:
	return null


## True if an unexpired press of `input` is buffered.
func has_buffered(input: StringName) -> bool:
	return false


## Remove and report the oldest unexpired press of `input`.
func consume(input: StringName) -> bool:
	return false


## Forget the chain (current = null, chain_step = 0). Keeps the buffer.
func reset_chain() -> void:
	pass


## Drop every buffered press (hold timers keep running).
func clear_buffer() -> void:
	pass
