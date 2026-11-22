extends Node
## The perf bench's frame-time recorder (L0-bench, shared by perf_bot.gd and perf_level_bot.gd): over
## one act it records the wall time between process frames, the first time each enemy is seen and the
## hits, and `close()` returns the PERF-BENCH result (see perf_bot.gd's header for the fields). It only
## reads. Wall-clock times: a recording (Movie Maker) or a busy machine says nothing.

## The window after an event in which its worst frame is looked for (s): crowd_acts.gd's PERF_AFTER_S.
const HITCH_WINDOW_S := 0.5
## A frame this long (ms) is a stall, not a slow frame (the 1 s of a drawable that was not released).
const STALL_MS := 500.0
## DisplayServer.VSyncMode by value, for the result's `vsync`. (A headless run has a dummy display
## server that reports "enabled".)
const VSYNC_NAMES: Array[String] = ["disabled", "enabled", "adaptive", "mailbox"]

## The window being recorded: process-frame times (ms) and when each frame ended (s), the events'
## times (s, -1 until seen), the number of hits, and the act's title (read from `caption` on the
## first frame).
var recording: bool = false
## The Label whose text is the act's title (the bot's caption).
var caption: Label
var _ms: PackedFloat32Array = PackedFloat32Array()
var _stamp: PackedFloat64Array = PackedFloat64Array()
var _spawn_stamps: PackedFloat64Array = PackedFloat64Array()
var _first_hit: float = -1.0
var _first_finisher: float = -1.0
var _hits: int = 0
var _title: String = ""
var _known: Dictionary = {}
## Renderer counters summed over the frames (visible pass, then shadow passes): draw calls, objects and
## primitives in the frame, and the renderer's own CPU and GPU time (ms). Deterministic where the wall time
## is not: close() reports their means.
var _counter_sums: Dictionary = {}
var _counter_max: Dictionary = {}
## T54, the engine's own per-frame costs (ms), none of which depends on the display's refresh: the renderer's
## CPU time (main viewport + frame setup, as _count_frame), its GPU time, and the engine's process and physics
## times (Performance.TIME_PROCESS / TIME_PHYSICS_PROCESS). SubViewports in the tree, if any, add to the render times.
var _eng_cpu: PackedFloat32Array = PackedFloat32Array()
var _eng_gpu: PackedFloat32Array = PackedFloat32Array()
var _eng_proc: PackedFloat32Array = PackedFloat32Array()
var _eng_phys: PackedFloat32Array = PackedFloat32Array()
## Also timed here (ms): `sim` = this frame's process_frame to frame_pre_draw (scripts and nodes), `draw` =
## frame_pre_draw to frame_post_draw (the render submit and the swapchain, so it holds the wait for the display).
var _eng_sim: PackedFloat32Array = PackedFloat32Array()
var _eng_draw: PackedFloat32Array = PackedFloat32Array()
var _frame_start_us: int = 0
var _pre_draw_us: int = 0
var _sub_viewports: Array[RID] = []


func _ready() -> void:
	CombatEvents.hit_landed.connect(_on_hit)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)


func _on_pre_draw() -> void:
	_pre_draw_us = Time.get_ticks_usec()
	if recording and _frame_start_us > 0:
		_eng_sim.append(float(_pre_draw_us - _frame_start_us) / 1000.0)


func _on_post_draw() -> void:
	if recording and _pre_draw_us > 0:
		_eng_draw.append(float(Time.get_ticks_usec() - _pre_draw_us) / 1000.0)


## Start a window (the last one must have been closed).
func open() -> void:
	_ms = PackedFloat32Array()
	_stamp = PackedFloat64Array()
	_spawn_stamps = PackedFloat64Array()
	_first_hit = -1.0
	_first_finisher = -1.0
	_hits = 0
	_title = ""
	_known.clear()
	_counter_sums.clear()
	_counter_max.clear()
	_eng_cpu = PackedFloat32Array()
	_eng_gpu = PackedFloat32Array()
	_eng_proc = PackedFloat32Array()
	_eng_phys = PackedFloat32Array()
	_eng_sim = PackedFloat32Array()
	_eng_draw = PackedFloat32Array()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_sub_viewports.clear()
	for node: Node in get_tree().root.find_children("*", "SubViewport", true, false):
		var rid := (node as SubViewport).get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(rid, true)
		_sub_viewports.append(rid)
	recording = true
	_sample()


func _on_hit(hit: HitInfo) -> void:
	if not recording:
		return
	var now := float(Time.get_ticks_usec()) / 1000000.0
	_hits += 1
	if _first_hit < 0.0:
		_first_hit = now
	if _first_finisher < 0.0 and hit.tier == CombatTypes.HitTier.FINISHER:
		_first_finisher = now


## One entry per process frame until the window is closed: the wall time since the last frame, and
## the first time each enemy is seen. Its own coroutine, beside the act.
func _sample() -> void:
	var tree := get_tree()
	var last := Time.get_ticks_usec()
	while recording:
		await tree.process_frame
		_frame_start_us = Time.get_ticks_usec()
		if not recording:
			return
		var now := _frame_start_us
		_ms.append(float(now - last) / 1000.0)
		_stamp.append(float(now) / 1000000.0)
		last = now
		_count_frame()
		if _title == "" and caption != null:
			_title = caption.text
		for node: Node in tree.get_nodes_in_group(&"ai_enemy"):
			var id := node.get_instance_id()
			if not _known.has(id):
				_known[id] = true
				_spawn_stamps.append(float(now) / 1000000.0)


## Add this frame's renderer counters (the last frame's, as the viewport reports them).
func _count_frame() -> void:
	var viewport := get_viewport()
	var rid := viewport.get_viewport_rid()
	var values := {
		draws = viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		objects = viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
		prims = viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		shadow_draws = viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		shadow_objects = viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
		shadow_prims = viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		render_cpu_ms = RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu(),
		render_gpu_ms = RenderingServer.viewport_get_measured_render_time_gpu(rid),
	}
	var gpu := float(values.render_gpu_ms)
	var cpu := float(values.render_cpu_ms)
	for sub in _sub_viewports:
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(sub)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(sub)
	_eng_cpu.append(cpu)
	_eng_gpu.append(gpu)
	_eng_proc.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
	_eng_phys.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
	for key: String in values:
		_counter_sums[key] = float(_counter_sums.get(key, 0.0)) + float(values[key])
		_counter_max[key] = maxf(float(_counter_max.get(key, 0.0)), float(values[key]))


## The means of the renderer counters over the window (rounded), keyed as `_count_frame` names them.
func counter_means() -> Dictionary:
	var out := {}
	for key: String in _counter_sums:
		out[key] = snappedf(float(_counter_sums[key]) / float(maxi(_ms.size(), 1)), 0.01)
	return out


## Median, 95th percentile and mean of a series (ms), rounded.
static func _series_stats(series: PackedFloat32Array) -> Dictionary:
	if series.is_empty():
		return {}
	var sorted := series.duplicate()
	sorted.sort()
	var sum := 0.0
	for value in series:
		sum += value
	return {
		p50 = snappedf(sorted[int(floor(0.5 * (sorted.size() - 1)))], 0.001),
		p95 = snappedf(sorted[int(floor(0.95 * (sorted.size() - 1)))], 0.001),
		mean = snappedf(sum / float(series.size()), 0.001),
	}


## T54: the engine's own frame costs over the window, none of which waits on the display's refresh except
## `draw` and `wall`. Per frame: `cpu` / `gpu` = the renderer's CPU and GPU times (gpu is 0 on Metal: the
## driver reports no timestamps), `sum` = cpu + gpu, `proc` / `phys` = Performance TIME_PROCESS /
## TIME_PHYSICS_PROCESS (TIME_PROCESS spans the whole frame, swapchain wait included), `sim` and `draw` as
## the vars above, `wall` = the frame's wall time, and `work` = phys + sim + cpu: the CPU work in a frame,
## which no refresh can inflate. `over_work_pct` is the share of frames whose `work` is above `budget_ms`;
## `missed_pct` the share whose wall time is past 1.5 refreshes of it (a refresh missed).
func engine_costs(budget_ms: float = 16.7) -> Dictionary:
	var n := mini(mini(_eng_cpu.size(), _eng_sim.size()), mini(_eng_draw.size(), _ms.size()))
	var sum := PackedFloat32Array()
	var work := PackedFloat32Array()
	var wall := PackedFloat32Array()
	var over_work := 0
	var missed := 0
	var over_sum := 0
	for i in n:
		var s := _eng_cpu[i] + _eng_gpu[i]
		var w := _eng_phys[i] + _eng_sim[i] + _eng_cpu[i]
		sum.append(s)
		work.append(w)
		wall.append(_ms[_ms.size() - n + i])
		over_work += int(w > budget_ms)
		over_sum += int(s > budget_ms)
		missed += int(wall[i] > budget_ms * 1.5)
	var denom := float(maxi(n, 1))
	return {
		cpu = _series_stats(_eng_cpu),
		gpu = _series_stats(_eng_gpu),
		sum = _series_stats(sum),
		proc = _series_stats(_eng_proc),
		phys = _series_stats(_eng_phys),
		sim = _series_stats(_eng_sim),
		draw = _series_stats(_eng_draw),
		wall = _series_stats(wall),
		work = _series_stats(work),
		over_sum_pct = snappedf(100.0 * float(over_sum) / denom, 0.01),
		over_work_pct = snappedf(100.0 * float(over_work) / denom, 0.01),
		missed_pct = snappedf(100.0 * float(missed) / denom, 0.01),
		budget_ms = budget_ms,
		sub_viewports = _sub_viewports.size(),
	}


## The worst frame (ms) within HITCH_WINDOW_S after `stamp` (s); -1 when there was no such event.
func _worst_after(stamp: float) -> float:
	if stamp < 0.0:
		return -1.0
	var worst := 0.0
	for i in _stamp.size():
		if _stamp[i] >= stamp and _stamp[i] <= stamp + HITCH_WINDOW_S:
			worst = maxf(worst, _ms[i])
	return worst


## Stop recording and return the window's PERF-BENCH result (empty when no window was open or no
## frame was recorded).
func close() -> Dictionary:
	if not recording:
		return {}
	recording = false
	if _ms.is_empty():
		return {}
	var sorted := _ms.duplicate()
	sorted.sort()
	var sum := 0.0
	for value in _ms:
		sum += value
	var stalls := 0
	for value in _ms:
		if value >= STALL_MS:
			stalls += 1
	var spawn_hitch := -1.0
	for stamp in _spawn_stamps:
		spawn_hitch = maxf(spawn_hitch, _worst_after(stamp))
	return {
		act = _title,
		frames = _ms.size(),
		mean_ms = snappedf(sum / float(_ms.size()), 0.001),
		p95_ms = snappedf(sorted[mini(int(floor(0.95 * (sorted.size() - 1))), sorted.size() - 1)], 0.001),
		worst_ms = snappedf(sorted[sorted.size() - 1], 0.001),
		spawn_hitch_ms = snappedf(spawn_hitch, 0.001),
		first_spawn_ms = snappedf(_worst_after(_spawn_stamps[0]) if not _spawn_stamps.is_empty() else -1.0, 0.001),
		first_hit_ms = snappedf(_worst_after(_first_hit), 0.001),
		first_finisher_ms = snappedf(_worst_after(_first_finisher), 0.001),
		spawns = _spawn_stamps.size(),
		hits = _hits,
		stalls = stalls,
		counters = counter_means(),
		engine = engine_costs(),
		vsync = VSYNC_NAMES[DisplayServer.window_get_vsync_mode()],
	}
