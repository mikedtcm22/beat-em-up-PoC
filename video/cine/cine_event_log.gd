class_name CineEventLog
extends Node
## The sound's cue sheet of a cine shot (PLAN.md §5, "Sound"): every combat event of the shot, with its physics tick on the shot clock and
## the frame of the video it lands on (the writer's picks: the window's first tick is frame 0), one line each, written to
## `<out dir>/<key>_events.log` and printed to the run's log (`EVENT ...`). The editor places the game's sound bank from these lines.
## It only reads `CombatEvents`; nothing here writes game state.

## The shot clock, in physics ticks (a Callable returning int), the window's first tick and the output rate.
var clock: Callable = func() -> int: return 0
var first_tick: int = 0
var out_fps: int = 24
var sim_fps: int = 60
## Every line logged, in order.
var lines: PackedStringArray = PackedStringArray()
## A line printed to the run's log, too.
var echo: bool = true

var _connected: bool = false


## Start listening. `p_clock` returns the shot clock's tick, `p_first_tick` is the window's first tick.
func start(p_clock: Callable, p_first_tick: int, p_out_fps: int) -> void:
	clock = p_clock
	first_tick = p_first_tick
	out_fps = p_out_fps
	sim_fps = Engine.physics_ticks_per_second
	lines.clear()
	if _connected:
		return
	_connected = true
	CombatEvents.attack_started.connect(func(who: Node3D, move: MoveData, step: int, timing: StringName) -> void:
			note(&"attack_started", "%s %s step=%d timing=%s" % [_name(who), _move(move), step, timing]))
	CombatEvents.attack_whiffed.connect(func(who: Node3D, move: MoveData) -> void:
			note(&"attack_whiffed", "%s %s" % [_name(who), _move(move)]))
	CombatEvents.windup_started.connect(func(who: Node3D, move: MoveData) -> void:
			note(&"windup_started", "%s %s" % [_name(who), _move(move)]))
	CombatEvents.hit_landed.connect(func(hit: HitInfo) -> void: note(&"hit_landed", _hit(hit)))
	CombatEvents.blocked.connect(func(who: Node3D, hit: HitInfo) -> void: note(&"blocked", "%s %s" % [_name(who), _hit(hit)]))
	CombatEvents.perfect_blocked.connect(func(who: Node3D, hit: HitInfo) -> void:
			note(&"perfect_blocked", "%s %s" % [_name(who), _hit(hit)]))
	CombatEvents.guard_broken.connect(func(who: Node3D, hit: HitInfo) -> void:
			note(&"guard_broken", "%s %s" % [_name(who), _hit(hit)]))
	CombatEvents.knocked_down.connect(func(who: Node3D, hit: HitInfo) -> void:
			note(&"knocked_down", "%s %s" % [_name(who), _hit(hit)]))
	CombatEvents.ko.connect(func(who: Node3D, hit: HitInfo) -> void: note(&"ko", "%s %s" % [_name(who), _hit(hit)]))
	CombatEvents.got_up.connect(func(who: Node3D) -> void: note(&"got_up", _name(who)))
	CombatEvents.grabbed.connect(func(holder: Node3D, victim: Node3D) -> void:
			note(&"grabbed", "%s holds %s" % [_name(holder), _name(victim)]))
	CombatEvents.released.connect(func(holder: Node3D, victim: Node3D) -> void:
			note(&"released", "%s releases %s" % [_name(holder), _name(victim)]))
	CombatEvents.thrown.connect(func(holder: Node3D, victim: Node3D) -> void:
			note(&"thrown", "%s throws %s" % [_name(holder), _name(victim)]))
	CombatEvents.weapon_picked_up.connect(func(who: Node3D, weapon: Node3D) -> void:
			note(&"weapon_picked_up", "%s %s" % [_name(who), _name(weapon)]))
	CombatEvents.weapon_thrown.connect(func(who: Node3D, weapon: Node3D) -> void:
			note(&"weapon_thrown", "%s %s" % [_name(who), _name(weapon)]))
	CombatEvents.weapon_broke.connect(func(who: Node3D, weapon: Node3D) -> void:
			note(&"weapon_broke", "%s %s" % [_name(who), _name(weapon)]))
	CombatEvents.weapon_landed.connect(func(weapon: Node3D) -> void: note(&"weapon_landed", _name(weapon)))
	CombatEvents.dodged.connect(func(who: Node3D, direction: Vector3) -> void:
			note(&"dodged", "%s dir=%s" % [_name(who), direction]))
	CombatEvents.jumped.connect(func(who: Node3D) -> void: note(&"jumped", _name(who)))
	CombatEvents.landed.connect(func(who: Node3D) -> void: note(&"landed", _name(who)))
	CombatEvents.quick_turned.connect(func(who: Node3D) -> void: note(&"quick_turned", _name(who)))
	CombatEvents.block_started.connect(func(who: Node3D) -> void: note(&"block_started", _name(who)))
	CombatEvents.block_ended.connect(func(who: Node3D) -> void: note(&"block_ended", _name(who)))
	CombatEvents.hazard_ko.connect(func(who: Node3D, _hazard: Node3D) -> void: note(&"hazard_ko", _name(who)))
	CombatEvents.boss_phase_changed.connect(func(who: Node3D, phase: int) -> void:
			note(&"boss_phase_changed", "%s phase=%d" % [_name(who), phase]))


## The video frame a shot-clock tick lands on: the picks' index counted from the window's first tick (negative before it).
func frame_of(tick: int) -> int:
	return CineFrameWriter.output_index(tick, sim_fps, out_fps) - CineFrameWriter.output_index(first_tick, sim_fps, out_fps)


## Log `name` with `detail` now.
func note(event: StringName, detail: String) -> void:
	var tick: int = clock.call()
	var line := "EVENT f%d t%d %s %s" % [frame_of(tick), tick, event, detail]
	lines.append(line)
	if echo:
		print(line)


## Write the cue sheet to `path`.
func save(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("CineEventLog: cannot write %s" % path)
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()


static func _name(node: Node) -> String:
	return String(node.name) if node != null and is_instance_valid(node) else "-"


static func _move(move: MoveData) -> String:
	return String(move.id) if move != null else "-"


static func _hit(hit: HitInfo) -> String:
	if hit == null:
		return "-"
	return "%s>%s %s dmg=%.0f tier=%d%s%s%s%s" % [_name(hit.attacker), _name(hit.victim), _move(hit.move), hit.damage, hit.tier,
			" blocked" if hit.blocked else "", " perfect" if hit.perfect_block else "", " guard_broken" if hit.guard_broken else "",
			" killed" if hit.killed else ""]
