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
##
## Implementation notes:
##   - Interrupt branches continue the chain (timing &"chain", chain_step + 1); only root
##     branches start a new chain (timing &"root", chain_step 1). With no chain at all
##     (current == null) a FREE press uses root_branches only.
##   - ComboBranch.timing is honoured on the current move's branches only. Root and
##     interrupt branches match regardless of their timing field.
##   - chain_step counts every started move of the chain, repeats and auto_next included
##     (jab_1 1, jab_2 2, body_flurry 3, its repeats 4.., shove last).
##   - The chain resets inside tick() as soon as f passes pause_max_frames, so the HUD
##     sees current == null from that frame on.
##   - select(false) while `current` is still running (the owner interrupted the move
##     without notify_recovery_ended() or reset_chain()) ignores the chain: roots only.
##   - Hold timers run for every pressed input (is_held / held_frames work for K too);
##     only P synthesizes a hold press (P_HOLD).


## The result of select(): which move to start and why.
class Selection:
	extends RefCounted
	var move: MoveData
	var input: StringName = &""
	## &"root", &"chain", &"pause", &"repeat", or &"auto".
	var timing: StringName = &"root"
	## 1-based position of `move` in the chain once started.
	var chain_step: int = 1


# One buffered button press. Age 0 is the frame it was pressed; tick() ages it.
class _BufferedPress:
	extends RefCounted
	var input: StringName
	var age: int = 0

	func _init(p_input: StringName) -> void:
		input = p_input


const _TIMING_ROOT := &"root"
const _TIMING_CHAIN := &"chain"
const _TIMING_PAUSE := &"pause"
const _TIMING_REPEAT := &"repeat"
const _TIMING_AUTO := &"auto"
# Branch timing filter that accepts any ComboBranch.timing (roots and interrupts).
const _ANY_TIMING := -1


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

# Buffered presses, oldest first (press order, so same-frame presses keep their order).
var _buffer: Array[_BufferedPress] = []
# Held inputs -> sim frames held so far (0 on the press frame).
var _held: Dictionary[StringName, int] = {}
# True from notify_started() until notify_recovery_ended(): `current` is still playing,
# so frames_since_recovery stays at -1.
var _running: bool = false


## Advance one sim frame.
func tick() -> void:
	# Age the buffer and drop presses that left the window.
	for entry: _BufferedPress in _buffer:
		entry.age += 1
	_drop_expired()
	# Hold timers.
	for held_input: StringName in _held.keys():
		_held[held_input] += 1
	# Post-recovery counter: notify_recovery_ended() leaves it at -1, so the first tick
	# after the recovery reads 0.
	if current != null and not _running:
		frames_since_recovery += 1
		if frames_since_recovery > pause_max_frames:
			reset_chain()


## Register a button press this frame (age 0). Starts P's hold timer.
func press(input: StringName) -> void:
	_buffer.append(_BufferedPress.new(input))
	_held[input] = 0


## Buffer a press of `input` with age 0 without touching the hold timers: a press the
## owner held back while it could not act on it (the player's P or K during a block) is
## handed back fresh the frame it can.
func buffer(input: StringName) -> void:
	_buffer.append(_BufferedPress.new(input))


## Register a button release this frame. Releasing P after hold_frames buffers P_HOLD.
func release(input: StringName) -> void:
	if not _held.has(input):
		return
	var frames: int = _held[input]
	_held.erase(input)
	if input == CombatTypes.IN_PUNCH and frames >= hold_frames:
		_buffer.append(_BufferedPress.new(CombatTypes.IN_PUNCH_HOLD))


## True while `input` is held (between press and release).
func is_held(input: StringName) -> bool:
	return _held.has(input)


## Sim frames `input` has been held, or 0 if it isn't held.
func held_frames(input: StringName) -> int:
	if not _held.has(input):
		return 0
	return _held[input]


## Pick the move for the oldest usable buffered press, consuming that press.
## `in_recovery`: the owner is in a cancellable recovery of `current`.
## `conditions`: StringName -> bool for ComboBranch.require keys.
## Returns null when nothing should start.
func select(in_recovery: bool, conditions: Dictionary = {}) -> Selection:
	for i: int in _buffer.size():
		var entry: _BufferedPress = _buffer[i]
		if entry.age > buffer_frames:
			continue
		var selection: Selection
		if in_recovery:
			selection = _match_in_recovery(entry.input, conditions)
		else:
			selection = _match_free(entry.input, conditions)
		if selection != null:
			_buffer.remove_at(i)
			return selection
	return null


## Record that the owner started `selection.move`.
func notify_started(selection: Selection) -> void:
	if selection == null or selection.move == null:
		return
	if selection.timing == _TIMING_REPEAT and selection.move == current:
		repeat_count += 1
	else:
		repeat_count = 0
	current = selection.move
	chain_step = selection.chain_step
	frames_since_recovery = -1
	_running = true


## Record that the current move's recovery finished (f starts at 0 next tick()).
func notify_recovery_ended() -> void:
	_running = false
	frames_since_recovery = -1


## After notify_recovery_ended(): the current move's auto_next as a Selection, or null.
func take_auto_next() -> Selection:
	if current == null or _running or current.auto_next == null:
		return null
	return _make_selection(current.auto_next, &"", _TIMING_AUTO, chain_step + 1)


## True if an unexpired press of `input` is buffered.
func has_buffered(input: StringName) -> bool:
	return _find_buffered(input) >= 0


## Remove and report the oldest unexpired press of `input`.
func consume(input: StringName) -> bool:
	var index := _find_buffered(input)
	if index < 0:
		return false
	_buffer.remove_at(index)
	return true


## Forget the chain (current = null, chain_step = 0). Keeps the buffer.
func reset_chain() -> void:
	current = null
	chain_step = 0
	frames_since_recovery = -1
	repeat_count = 0
	_running = false


## Drop every buffered press (hold timers keep running).
func clear_buffer() -> void:
	_buffer.clear()


# --- Matching -----------------------------------------------------------------------

# Cancellable recovery: repeat, then the current move's NORMAL branches, then interrupts.
# PAUSE branches and roots never fire from recovery.
func _match_in_recovery(input: StringName, conditions: Dictionary) -> Selection:
	if current != null:
		if (current.repeat_input != &"" and input == current.repeat_input
				and repeat_count < current.repeat_max):
			return _make_selection(current, input, _TIMING_REPEAT, chain_step + 1)
		var branch := _find_branch(current.branches, input, CombatTypes.BranchTiming.NORMAL, conditions)
		if branch != null:
			return _make_selection(branch.move, input, _TIMING_CHAIN, chain_step + 1)
	if move_set != null:
		var interrupt := _find_branch(move_set.interrupt_branches, input, _ANY_TIMING, conditions)
		if interrupt != null:
			return _make_selection(interrupt.move, input, _TIMING_CHAIN, chain_step + 1)
	return null


# FREE: grace window -> NORMAL; pause window -> PAUSE then NORMAL; then interrupts, then
# roots. With no chain, roots only. A FREE select while `current` is still marked as
# running means the owner cut the move short without notify_recovery_ended() (hit,
# dodge, ...): the chain is treated as broken and only roots apply.
func _match_free(input: StringName, conditions: Dictionary) -> Selection:
	if current != null and not _running:
		# Right after notify_recovery_ended() f is still -1: that is grace (f < pause_min).
		if frames_since_recovery >= pause_min_frames and frames_since_recovery <= pause_max_frames:
			var pause := _find_branch(current.branches, input, CombatTypes.BranchTiming.PAUSE, conditions)
			if pause != null:
				return _make_selection(pause.move, input, _TIMING_PAUSE, chain_step + 1)
		if frames_since_recovery <= pause_max_frames:
			var normal := _find_branch(current.branches, input, CombatTypes.BranchTiming.NORMAL, conditions)
			if normal != null:
				return _make_selection(normal.move, input, _TIMING_CHAIN, chain_step + 1)
			if move_set != null:
				var interrupt := _find_branch(move_set.interrupt_branches, input, _ANY_TIMING, conditions)
				if interrupt != null:
					return _make_selection(interrupt.move, input, _TIMING_CHAIN, chain_step + 1)
	if move_set != null:
		var root := _find_branch(move_set.root_branches, input, _ANY_TIMING, conditions)
		if root != null:
			return _make_selection(root.move, input, _TIMING_ROOT, 1)
	return null


# First branch in array order with this input, an allowed timing (_ANY_TIMING accepts
# all) and a satisfied `require`. Branches without a move are skipped.
func _find_branch(branches: Array[ComboBranch], input: StringName, timing: int,
		conditions: Dictionary) -> ComboBranch:
	for branch: ComboBranch in branches:
		if branch == null or branch.move == null or branch.input != input:
			continue
		if timing != _ANY_TIMING and branch.timing != timing:
			continue
		if branch.require != &"" and not _condition_holds(conditions, branch.require):
			continue
		return branch
	return null


# Only a real `true` counts; missing keys and non-bool values are false.
static func _condition_holds(conditions: Dictionary, key: StringName) -> bool:
	var value: Variant = conditions.get(key, false)
	return value is bool and value


static func _make_selection(move: MoveData, input: StringName, timing: StringName,
		step: int) -> Selection:
	var selection := Selection.new()
	selection.move = move
	selection.input = input
	selection.timing = timing
	selection.chain_step = step
	return selection


# --- Buffer --------------------------------------------------------------------------

# Index of the oldest unexpired press of `input`, or -1.
func _find_buffered(input: StringName) -> int:
	for i: int in _buffer.size():
		var entry: _BufferedPress = _buffer[i]
		if entry.input == input and entry.age <= buffer_frames:
			return i
	return -1


func _drop_expired() -> void:
	for i: int in range(_buffer.size() - 1, -1, -1):
		if _buffer[i].age > buffer_frames:
			_buffer.remove_at(i)
