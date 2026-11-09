extends GutTest
## SHOTS: the beat sequencer (CineScript), the camera's sampling at the output frame's exact time, the cue sheet's frame numbers and the
## director's restore.


func _beat(kind: CineBeat.Kind, at: float, relative: bool = false, trigger: CineBeat.Trigger = CineBeat.Trigger.CLOCK) -> CineBeat:
	var beat := CineBeat.new()
	beat.kind = kind
	beat.at_s = at
	beat.relative = relative
	beat.trigger = trigger
	return beat


func _fired_ticks(script: CineScript, ticks: int, met: Callable) -> Array[int]:
	var out: Array[int] = []
	for tick in ticks:
		for firing in script.step(tick, met):
			out.append(tick)
	return out


func test_absolute_beats_fire_at_their_times_in_order() -> void:
	var script := CineScript.new([_beat(CineBeat.Kind.PRESS, 0.5), _beat(CineBeat.Kind.PRESS, 1.0)], 60)
	assert_eq(_fired_ticks(script, 100, func(_b: CineBeat) -> bool: return true), [30, 60])
	assert_true(script.done())


func test_a_relative_beat_counts_from_the_step_before() -> void:
	var script := CineScript.new([_beat(CineBeat.Kind.PRESS, 0.5), _beat(CineBeat.Kind.PRESS, 0.25, true),
			_beat(CineBeat.Kind.PRESS, 0.25, true)], 60)
	assert_eq(_fired_ticks(script, 100, func(_b: CineBeat) -> bool: return true), [30, 45, 60])


func test_a_trigger_holds_the_script_until_it_is_met_and_the_next_beat_counts_from_the_firing() -> void:
	var state := {met = false}
	var script := CineScript.new([_beat(CineBeat.Kind.PRESS, 0.0, false, CineBeat.Trigger.ACTOR_STAGGERED),
			_beat(CineBeat.Kind.PRESS, 0.5, true)], 60)
	var met := func(_b: CineBeat) -> bool: return state.met
	var fired: Array[int] = []
	for tick in 200:
		if tick == 40:
			state.met = true
		for firing in script.step(tick, met):
			fired.append(tick)
	assert_eq(fired, [40, 70], "the first fires when its state comes, the second half a second later")


func test_a_trigger_that_never_comes_times_out_and_says_so() -> void:
	var beat := _beat(CineBeat.Kind.PRESS, 0.0, false, CineBeat.Trigger.ACTOR_STRIKE)
	beat.timeout_s = 1.0
	var script := CineScript.new([beat], 60)
	var flags: Array[bool] = []
	var tick_fired := -1
	for tick in 200:
		for firing in script.step(tick, func(_b: CineBeat) -> bool: return false):
			flags.append(firing.timed_out)
			tick_fired = tick
	assert_eq(flags, [true])
	assert_eq(tick_fired, 60, "after the timeout")


func test_a_clock_beat_ignores_the_trigger_check() -> void:
	var script := CineScript.new([_beat(CineBeat.Kind.MOVE, 0.1)], 60)
	assert_eq(_fired_ticks(script, 20, func(_b: CineBeat) -> bool: return false), [6])


func test_several_beats_can_fire_on_one_tick() -> void:
	var script := CineScript.new([_beat(CineBeat.Kind.DOWN, 0.0), _beat(CineBeat.Kind.MOVE, 0.0, true), _beat(CineBeat.Kind.PRESS, 0.0, true)], 60)
	var firings := script.step(0, func(_b: CineBeat) -> bool: return true)
	assert_eq(firings.size(), 3)
	assert_eq(firings[2].index, 2)


func test_the_camera_is_sampled_at_each_output_frames_exact_time() -> void:
	# The picks of 24 fps from 60 Hz sit on ticks 0, 3, 5, 8, 10, 13: sampled at the output frame's time the camera steps evenly.
	var times: Array[float] = []
	for tick in CineFrameWriter.picks(0, 30, 60, 24):
		times.append(CineDirector.camera_time(tick, 60, 24))
	for i in range(1, times.size()):
		assert_almost_eq(times[i] - times[i - 1], 1.0 / 24.0, 0.00001, "frame %d steps one frame" % i)
	assert_almost_eq(times[1], 1.0 / 24.0, 0.00001)
	# The same ticks sampled at the tick's own time would step 3/60 and 2/60 s: the judder.
	var uneven := {}
	var last := -1.0
	for tick in CineFrameWriter.picks(0, 30, 60, 24):
		if last >= 0.0:
			uneven[snappedf(float(tick) / 60.0 - last, 0.0001)] = true
		last = float(tick) / 60.0
	assert_gte(uneven.size(), 2, "the tick time alternates two step sizes")


func test_the_camera_time_inside_one_output_frame_is_constant() -> void:
	assert_eq(CineDirector.camera_time(3, 60, 24), CineDirector.camera_time(4, 60, 24))
	assert_gt(CineDirector.camera_time(5, 60, 24), CineDirector.camera_time(4, 60, 24))


func test_the_cue_sheet_counts_frames_from_the_windows_first_tick() -> void:
	var log := CineEventLog.new()
	add_child_autofree(log)
	log.echo = false
	var state := {tick = 0}
	log.start(func() -> int: return state.tick, 60, 24)
	assert_eq(log.frame_of(60), 0, "the window's first tick is frame 0")
	assert_eq(log.frame_of(65), 2, "5 ticks later is the second output frame after it")
	assert_eq(log.frame_of(120), 24, "a second on")
	state.tick = 90
	log.note(&"hit_landed", "Player>Punk1 jab_1")
	assert_eq(log.lines.size(), 1)
	assert_true(log.lines[0].begins_with("EVENT f12 t90 hit_landed"), log.lines[0])


func test_the_cue_sheet_logs_the_combat_events_of_the_shot() -> void:
	var log := CineEventLog.new()
	add_child_autofree(log)
	log.echo = false
	log.start(func() -> int: return 12, 0, 24)
	var victim := Node3D.new()
	victim.name = "Punk1"
	add_child_autofree(victim)
	var hit := HitInfo.new()
	hit.victim = victim
	hit.attacker = victim
	hit.damage = 6.0
	CombatEvents.hit_landed.emit(hit)
	CombatEvents.jumped.emit(victim)
	CombatEvents.perfect_blocked.emit(victim, hit)
	var joined := "\n".join(log.lines)
	assert_true(joined.contains("hit_landed"), joined)
	assert_true(joined.contains("jumped Punk1"), joined)
	assert_true(joined.contains("perfect_blocked"), joined)


func test_the_director_puts_the_centre_dot_back() -> void:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var director := CineDirector.new()
	add_child_autofree(director)
	var before := bool(Tuning.data.show_center_dot)
	Tuning.set_value(&"show_center_dot", true)
	director.remember_overlays()
	CineDirector.hide_overlays(holder)
	assert_false(bool(Tuning.data.show_center_dot), "the overlays' hiding turns the dot off")
	director.restore()
	assert_true(bool(Tuning.data.show_center_dot), "restore() puts it back")
	Tuning.set_value(&"show_center_dot", before)
