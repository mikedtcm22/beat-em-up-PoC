class_name ShowcaseRunner
extends Node
## Plays ShowcaseScript on one Punk by hand: each step is `rig.play()`, `play_locomotion()` or
## `play_move()` on the Punk's own rig, the body placed and turned by the runner, the rig advanced
## by the delta it is given. The Punk is an EnemyActor that has been taken off its own tick
## (set_physics_process(false)): nothing here, and nothing of its AI, moves it but the script, and
## nothing reads it as an enemy (CheatMenu.set_showcase() and the look act both take it out of the
## enemy groups and switch its hurtboxes off). The runner writes the rig and the actor's transform
## and nothing else: no game state, no events.
##
## It is a child of the Punk it plays, so it goes with it. `auto_advance` (the F4 showcase) steps it
## from its own _physics_process with the simulation's delta (TimeController.sim_scale(): F4's
## 0.25x time scale slows the take); an act steps it itself with advance() once a tick, so the
## recording is the same every run.

## A step began: its index and its name.
signal step_started(index: int, step_name: StringName)
## A mark inside a step (ShowcaseScript's `marks`): the step's name and which of its marks.
signal step_marked(step_name: StringName, label: String)
## The whole take has played once (it then starts again when `loop` is set).
signal take_finished

## A step ends when its seconds are used up to within this much: a sum of 1/60 s ticks is never
## exactly a clip's length.
const _SEAM_S := 1e-4

## The Punk the runner plays.
var actor: CombatActor
## Where the Punk stands, in the world: its spot on the floor and the facing it stands to the
## player in. A walk step moves it off this and back, a turn step turns it about it.
var anchor: Transform3D = Transform3D.IDENTITY
## Start the take again when it ends (the showcase); off, the Punk stays as the last step left it.
var loop: bool = true
## Step in _physics_process (see the class docs).
var auto_advance: bool = true:
	set(value):
		auto_advance = value
		set_physics_process(value)
## The step playing now (-1 before the first and after a take that does not loop), and the
## seconds of it played.
var index: int = -1
var elapsed: float = 0.0
## The takes finished so far.
var takes: int = 0

var _steps: Array[Dictionary] = []
var _seconds: PackedFloat32Array = PackedFloat32Array()
## The Punk's position at the start of the step, and how far it has turned about its vertical
## (radians, positive to its left) from the anchor's facing.
var _from: Vector3 = Vector3.ZERO
var _turned: float = 0.0
var _turn_from: float = 0.0
## Ticks of the contact flash still to run (counted in ticks the simulation moves).
var _flash_left: int = 0
var _next_mark: int = 1
var _finished: bool = false


func _ready() -> void:
	set_physics_process(auto_advance)


func _physics_process(delta: float) -> void:
	advance(delta * TimeController.sim_scale())


## Take `punk` (an EnemyActor just added to the tree) off its own tick and out of everything that
## reads an enemy: the groups the director, the spawner, the probes and "Remove all enemies" find
## enemies by (it stays in "actor", so the camera and the spawn clearance still know it is a body),
## the navigation avoidance the other enemies steer round, and its hurtboxes. What this leaves is a
## body that stands where it is put and plays what the runner tells its rig. Freeing it (after
## leaving "actor") undoes all of it.
static func unplug(punk: CombatActor) -> void:
	for group: StringName in [&"enemy", &"ai_enemy", &"boss"]:
		if punk.is_in_group(group):
			punk.remove_from_group(group)
	punk.set_physics_process(false)
	for agent: Node in punk.find_children("*", "NavigationAgent3D", false, false):
		(agent as NavigationAgent3D).avoidance_enabled = false
	punk.rig.set_hurtboxes_enabled(false)


## Put `p_actor` (an EnemyActor already in the tree, off its own tick) at `p_anchor` and read the
## take's length from its rig's clips. The take begins on the next advance().
func setup(p_actor: CombatActor, p_anchor: Transform3D, p_loop: bool = true) -> void:
	actor = p_actor
	anchor = p_anchor
	loop = p_loop
	_steps = ShowcaseScript.steps()
	_seconds = ShowcaseScript.durations(actor.rig)
	index = -1
	takes = 0
	_finished = false
	_reset_body()


## The take's length in seconds, as this Punk's clips and the pace make it.
func take_seconds() -> float:
	var total := 0.0
	for seconds: float in _seconds:
		total += seconds
	return total


## Seconds of step `i` on this Punk.
func seconds_of_step(i: int) -> float:
	return _seconds[i]


func step_count() -> int:
	return _steps.size()


## The step playing now, or {} before the first and after the last of a take that does not loop.
func current_step() -> Dictionary:
	return _steps[index] if index >= 0 and index < _steps.size() else {}


## True once a take that does not loop has played to its end.
func is_finished() -> bool:
	return _finished


## Play the take from the first step.
func restart() -> void:
	index = -1
	_finished = false
	_reset_body()


## Move the take on by `dt` simulation seconds: the body is placed first, then the rig advanced, as
## its owner does each tick. A step that ends hands the rest of the tick to the next.
func advance(dt: float) -> void:
	if actor == null or not is_instance_valid(actor) or _steps.is_empty() or _finished:
		return
	if index < 0:
		_begin(0)
	var left := maxf(dt, 0.0)
	while index >= 0 and elapsed + left >= _seconds[index] - _SEAM_S:
		var used := maxf(_seconds[index] - elapsed, 0.0)
		_play(used)
		left -= used
		if not _next_step():
			return
	_play(left)


## The Punk as a take starts it: whole, standing in its idle at the anchor.
func _reset_body() -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var rig := actor.rig
	rig.set_shown(true)
	rig.set_flash(0.0)
	rig.set_damage_look(DamageLook.Level.CLEAN)
	_flash_left = 0
	_turned = 0.0
	_place(anchor.origin)
	rig.play(&"idle", 0.0)
	rig.advance(0.0)


## Place the Punk at world `at`, turned `_turned` from the anchor's facing.
func _place(at: Vector3) -> void:
	actor.global_transform = Transform3D(anchor.basis * Basis(Vector3.UP, _turned), at)


## Step `index` ends: begin the next, or end the take (and begin it again when it loops). False
## when nothing is left to play this tick.
func _next_step() -> bool:
	if index + 1 < _steps.size():
		_begin(index + 1)
		return true
	takes += 1
	take_finished.emit()
	if loop and is_instance_valid(actor):
		_reset_body()
		_begin(0)
		return true
	index = -1
	_finished = true
	return false


func _begin(i: int) -> void:
	index = i
	elapsed = 0.0
	_next_mark = 1
	var step := _steps[i]
	var rig := actor.rig
	_from = actor.global_position
	_turn_from = _turned
	match step.kind:
		&"stand":
			rig.play_locomotion(Vector2.ZERO, 0.0)
		&"walk":
			_walk_anim(step)
		&"clip":
			rig.play(step.anim)
		&"move":
			rig.play_move(ShowcaseScript.move_of(step))
	if step.has("damage"):
		rig.set_damage_look(int(step.damage))
	if step.has("hit_point"):
		_flash(step.hit_point)
	step_started.emit(i, step.name)


## The walk step's legs: forward or backward at the pace, as the AI's own steps play them.
func _walk_anim(step: Dictionary) -> void:
	var local := Vector2(0.0, signf(float(step.move_m)))
	actor.rig.play_locomotion(local, ShowcaseScript.pace_of(step) / Tuning.data.move_speed)


## The contact flash of a hit, aimed at rig point `point`, with the numbers a real hit uses.
func _flash(point: StringName) -> void:
	var tuning := Tuning.data
	var rig := actor.rig
	_flash_left = tuning.hit_flash_frames
	rig.flash_at(rig.get_point_position(point), tuning.hit_flash_strength, tuning.hit_flash_radius_m, tuning.hit_flash_core)


## Play `dt` seconds of the current step: place the body, advance the rig, run the flash.
func _play(dt: float) -> void:
	var step := _steps[index]
	var rig := actor.rig
	elapsed += dt
	var share := clampf(elapsed / maxf(_seconds[index], 0.001), 0.0, 1.0)
	match step.kind:
		&"stand":
			_turned = _turn_from + deg_to_rad(float(step.get("turn_deg", 0.0))) * share
			_place(_from)
		&"walk":
			_walk_anim(step)
			var along := signf(float(step.move_m)) * minf(ShowcaseScript.pace_of(step) * elapsed, absf(float(step.move_m)))
			_place(_from + anchor.basis * Vector3.FORWARD * along)
	rig.advance(dt)
	if dt > 0.0 and _flash_left > 0:
		_flash_left -= 1
		if _flash_left == 0:
			rig.set_flash(0.0)
		else:
			rig.follow_flash()
	var marks := int(step.get("marks", 0))
	while _next_mark <= marks and share >= float(_next_mark) / float(marks + 1):
		step_marked.emit(step.name, "%s_%d_of_%d" % [step.name, _next_mark, marks + 1])
		_next_mark += 1
