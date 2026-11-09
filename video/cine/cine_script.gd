class_name CineScript
extends RefCounted
## The sequencer of a cine shot's beats, without a game in it: it is given the tick and a Callable that says whether a beat's trigger holds,
## and returns the beats that fire on that tick. The beats run in array order, one after the other: each waits for its time (`at_s` on the
## shot clock, or with `relative` after the step before fired), then for its trigger, for `timeout_s` at most (it then fires anyway, and the
## firing says so). Up to `MAX_PER_TICK` beats fire on one tick (a press and the hold that goes with it).

const MAX_PER_TICK := 16

## One firing: the beat, its index in the shot's beats, and whether its trigger timed out.
class Firing:
	extends RefCounted
	var beat: CineBeat
	var index: int = 0
	var timed_out: bool = false

var beats: Array[CineBeat] = []
var sim_fps: int = 60
## The next beat to fire, the tick the waiting beat's wait starts at (-1: not worked out yet), and the tick the last beat fired.
var next_index: int = 0
var wait_from: int = -1
var previous_fire: int = 0


func _init(p_beats: Array[CineBeat] = [], p_sim_fps: int = 60) -> void:
	beats = p_beats.duplicate()
	sim_fps = p_sim_fps


## True when every beat has fired.
func done() -> bool:
	return next_index >= beats.size()


## The beats left.
func remaining() -> int:
	return maxi(beats.size() - next_index, 0)


## The firings of tick `tick`. `trigger_met` takes a CineBeat and returns whether the state it waits for holds. `on_fire` (optional) takes
## each Firing the moment it is decided, before the next beat's trigger is read, so a beat that waits for the player to be free sees the press
## the beat before it just made.
func step(tick: int, trigger_met: Callable, on_fire: Callable = Callable()) -> Array[Firing]:
	var out: Array[Firing] = []
	while next_index < beats.size() and out.size() < MAX_PER_TICK:
		var beat := beats[next_index]
		if wait_from < 0:
			wait_from = (previous_fire if beat.relative else 0) + int(roundf(beat.at_s * float(sim_fps)))
		if tick < wait_from:
			break
		var timed_out := false
		if beat.trigger != CineBeat.Trigger.CLOCK and not bool(trigger_met.call(beat)):
			if float(tick - wait_from) < beat.timeout_s * float(sim_fps):
				break
			timed_out = true
		var firing := Firing.new()
		firing.beat = beat
		firing.index = next_index
		firing.timed_out = timed_out
		out.append(firing)
		if on_fire.is_valid():
			on_fire.call(firing)
		previous_fire = tick
		wait_from = -1
		next_index += 1
	return out
