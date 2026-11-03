extends GutTest
## The look acts and their instruments (L0-bench, M4-plan Part A A12): the act file lists the plan's
## acts with titles a capture filter can pick one by; look_rect.gd projects a body into 1600x900
## pixels; one act runs headless in the real crowd room and prints its marks and rectangles; the
## perf bench's bot prints one PERF-BENCH line; tools/look_sheets.sh cuts stills and crops out of a
## video from those lines.

const LookActs := preload("res://tests/bot/acts/look_acts.gd")
const LookRect := preload("res://tests/bot/look_rect.gd")

## Every act the file holds, by slug (C12, the extremes, is F-motion's: another file).
const SLUGS: Array[StringName] = [&"c1", &"c2", &"c3", &"c4", &"c5", &"c6", &"c7", &"c8", &"c9", &"c10", &"c11", &"c13"]
const FIRST_ACT := "Look: Punk face"
## The longest an act may take in the tests (physics ticks).
const MAX_TICKS := 900
## The longest the long acts may take: C5 (the chain, the get-up, the health looks and the KO) and C9 (the tour).
const LONG_MAX_TICKS := 2400
const ROOM_FRAME := Vector2(1600.0, 900.0)


## The crowd bot that stops instead of quitting the test run's tree when its acts are done.
class QuietBot extends "res://tests/bot/crowd_bot.gd":
	var finished: bool = false

	func _quit() -> void:
		clear_enemies()
		finished = true


## The perf bot, stopped the same way (it closes its window first, as its own _quit() does).
class QuietPerfBot extends "res://tests/bot/perf_bot.gd":
	var finished: bool = false

	func _quit() -> void:
		_close_window()
		clear_enemies()
		finished = true


func after_all() -> void:
	# A headless run is far ahead of the audio clock: give the mixer a moment to drop the sounds.
	OS.delay_msec(250)


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.set_value(&"waves_enabled", false)
	TimeController.clear()
	GameInput.menu_open = false


func after_each() -> void:
	GameInput.menu_open = false
	Tuning.reset_to_default()
	TimeController.clear()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Run `bot` (already in the tree) until its acts are done, at most MAX_TICKS ticks; the log lines
## printed during the act, and what the bot looked like at its `start` mark: {caption_visible,
## ai_frozen, god_mode}.
func _run_bot(bot: Variant, max_ticks: int = MAX_TICKS) -> Dictionary:
	var seen := {}
	for i in max_ticks:
		await get_tree().physics_frame
		if seen.is_empty() and bot.log_lines.size() > 0:
			for line: String in bot.log_lines:
				if line.contains(" start"):
					seen = {caption_visible = bot.caption.visible, ai_frozen = Tuning.data.ai_frozen,
							god_mode = Tuning.data.god_mode}
					break
		if bot.finished:
			break
	assert_true(bot.finished, "the act finished within %d ticks" % max_ticks)
	return seen


## The `LOOK-` lines of a bot's log, each once, as arrays of their words.
func _look_lines(bot: Variant, kind: String) -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	var seen := {}
	for line: String in bot.log_lines:
		if line.begins_with(kind + " ") and not seen.has(line):
			seen[line] = true
			out.append(line.split(" "))
	return out


# --- The act file ------------------------------------------------------------------------------


func test_the_act_file_holds_the_plans_acts_with_their_slugs() -> void:
	var acts := LookActs.acts(_bare_node())
	var slugs: Array[StringName] = []
	for act in acts:
		slugs.append(act.slug)
		assert_true(String(act.title).begins_with("Look: "), "%s starts with Look:" % act.title)
		assert_true(act.cam in [&"first_person", &"free_fly"], "%s has a camera mode" % act.title)
		assert_true((act.fn as Callable).is_valid(), "%s has an act" % act.title)
	# SL-int adds the perf act after them (A16), the slice gate's fixer the warm-up act (W1), P3-early
	# the long take (C14) and the L5 readability act: C1-C11 and C13 stay first, in the plan's order.
	assert_eq(slugs.slice(0, SLUGS.size()), SLUGS, "the acts are C1-C11 and C13, in the plan's order")
	assert_eq(slugs.slice(SLUGS.size()), [&"p1", &"w1", &"c14", &"c15", &"l5"] as Array[StringName],
			"then SL-int's perf act, the warm-up act, the long take, the F4 showcase and the L5 act")


func test_the_perf_act_runs_six_art_punks_with_the_probe_on() -> void:
	# The twin of the slug list's change: A16's act is in the file, titled as the lead's perf_compare
	# asks for it, and no other act's title holds it or is held by it.
	var perf: Dictionary = {}
	for act in LookActs.acts(_bare_node()):
		if act.slug == &"p1":
			perf = act
	assert_eq(perf.get("title"), "Look: Perf, six art Punks")
	assert_eq(perf.get("cam"), &"first_person")
	assert_true(perf.get("probe", false), "the probe is on, as the existing perf act has it")
	assert_true((perf.fn as Callable).is_valid())
	for title: String in ["Perf, six with ragdolls", "Look: Punk reacts at 1 m"]:
		assert_false(title.to_lower().contains("look: perf, six art punks"))
		assert_false("look: perf, six art punks".contains(title.to_lower()))


func test_the_long_take_and_the_l5_act_are_in_the_file_with_titles_nothing_else_holds() -> void:
	# P3-early: the 40 s long take (C14, for the DM), the F4 showcase act (C15) and the windowed L5 act (R4 and R8
	# with the art drawn).
	var by_slug := {}
	for act in LookActs.acts(_bare_node()):
		by_slug[act.slug] = act
	assert_eq(by_slug[&"c14"].title, "Look: Punk at 1 m, the long take")
	assert_eq(by_slug[&"c15"].title, "Look: F4 Showcase Punk")
	assert_eq(by_slug[&"l5"].title, "Look: readability with the art drawn")
	for slug: StringName in [&"c14", &"c15", &"l5"]:
		assert_eq(by_slug[slug].cam, &"first_person")
		assert_true((by_slug[slug].fn as Callable).is_valid())
		assert_false(by_slug[slug].get("probe", false), "no probe: the act measures the lens itself")
		var title := String(by_slug[slug].title).to_lower()
		for act in LookActs.acts(_bare_node()):
			if act.slug == slug:
				continue
			assert_false(title.contains(String(act.title).to_lower()), "%s does not hold %s" % [title, act.title])
			assert_false(String(act.title).to_lower().contains(title), "%s does not hold %s" % [act.title, title])
	# The titles of the other acts' files (the crowd, the slice, F-motion's) too: a capture filter is a
	# substring match over every act of the run.
	for other: String in ["Six Punks, fight", "Mixed six, fight", "Perf, six with ragdolls", "Look: extremes"]:
		for slug: StringName in [&"c14", &"c15", &"l5"]:
			var title := String(by_slug[slug].title).to_lower()
			assert_false(title.contains(other.to_lower()) or other.to_lower().contains(title), "%s and %s" % [title, other])


func test_every_title_picks_only_its_own_act() -> void:
	# A capture takes one act with its title as the filter (a case-insensitive substring), as the
	# before pack does: no title may be inside another.
	var acts := LookActs.acts(_bare_node())
	for act in acts:
		var matches := 0
		for other in acts:
			if String(other.title).to_lower().contains(String(act.title).to_lower()):
				matches += 1
		assert_eq(matches, 1, "'%s' picks one act" % act.title)


func test_the_crowd_bot_loads_the_look_acts_by_name() -> void:
	var bot := QuietBot.new()
	autofree(bot)
	var titles: Array[String] = []
	for act in bot._collect_acts():
		titles.append(act.title)
	for act in LookActs.acts(bot):
		assert_has(titles, act.title, "%s is collected" % act.title)


# --- look_rect.gd ------------------------------------------------------------------------------


func _bare_node() -> Node:
	var node := Node.new()
	autofree(node)
	return node


func _camera() -> Camera3D:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.current = true
	return camera


func test_a_sphere_ahead_is_a_rectangle_round_the_frame_centre() -> void:
	var camera := _camera()
	var rect := LookRect.bounds(camera, PackedVector3Array([Vector3(0.0, 0.0, -2.0)]), 0.5, 0.0)
	assert_true(rect.has_area(), "it is on the screen")
	assert_almost_eq(rect.get_center().x, ROOM_FRAME.x / 2.0, 1.0, "centred across")
	assert_almost_eq(rect.get_center().y, ROOM_FRAME.y / 2.0, 1.0, "centred down")
	var padded := LookRect.bounds(camera, PackedVector3Array([Vector3(0.0, 0.0, -2.0)]), 0.5, 10.0)
	assert_almost_eq(padded.size.x, rect.size.x + 20.0, 0.5, "the pad grows each side")


func test_a_nearer_sphere_is_bigger_and_one_at_the_lens_fills_the_frame() -> void:
	var camera := _camera()
	var far := LookRect.bounds(camera, PackedVector3Array([Vector3(0.0, 0.0, -4.0)]), 0.3, 0.0)
	var near := LookRect.bounds(camera, PackedVector3Array([Vector3(0.0, 0.0, -2.0)]), 0.3, 0.0)
	assert_almost_eq(near.size.y / far.size.y, 2.0, 0.05, "twice as near, twice as tall")
	var lens := LookRect.bounds(camera, PackedVector3Array([Vector3(0.0, 0.0, -0.1)]), 0.3, 0.0)
	assert_eq(lens, Rect2(Vector2.ZERO, ROOM_FRAME), "a sphere on the lens fills the frame")


func test_behind_the_lens_or_off_the_side_is_not_on_the_screen() -> void:
	var camera := _camera()
	var behind := LookRect.bounds(camera, PackedVector3Array([Vector3(0.0, 0.0, 3.0)]), 0.3)
	assert_false(behind.has_area(), "behind the lens: no rectangle")
	var aside := LookRect.bounds(camera, PackedVector3Array([Vector3(40.0, 0.0, -2.0)]), 0.3)
	assert_false(aside.has_area(), "far to the side: no rectangle")


func test_a_rectangle_is_clipped_to_the_frame() -> void:
	var camera := _camera()
	# Half out of the frame on the left: the rectangle starts at 0 and stays inside.
	var edge := LookRect.bounds(camera, PackedVector3Array([Vector3(-1.7, 0.0, -2.0)]), 0.6, 8.0)
	assert_true(edge.has_area(), "partly on the screen")
	assert_eq(edge.position.x, 0.0, "clipped at the left edge")
	assert_true(Rect2(Vector2.ZERO, ROOM_FRAME).encloses(edge), "inside the frame")


func test_a_line_is_the_logs_format() -> void:
	assert_eq(LookRect.line("c1", 123, LookRect.HEAD, Rect2(612.4, 80.0, 240.6, 233.0)),
			"LOOK-RECT c1 f123 head 612 80 241 233")


# --- One act, headless -------------------------------------------------------------------------


func test_c1_runs_headless_and_prints_its_marks_and_rectangles() -> void:
	var bot := QuietBot.new()
	bot.act_filter = FIRST_ACT
	add_child_autofree(bot)
	var at_start := await _run_bot(bot)
	assert_false(at_start.get("caption_visible", true), "the caption is hidden during the act")
	assert_true(at_start.get("ai_frozen", false), "the AI is frozen")
	assert_true(at_start.get("god_mode", false), "god mode is on")
	assert_true(bot.caption.visible, "the caption is back when the act is over")
	var marks := _look_lines(bot, "LOOK-MARK")
	var rects := _look_lines(bot, "LOOK-RECT")
	assert_gt(marks.size(), 3, "the act marks its start, its idle seconds and its end")
	var start := -1
	var end := -1
	for mark in marks:
		assert_eq(mark[1], "c1", "the slug")
		var frame := int(mark[2].trim_prefix("f"))
		if mark[3] == "start":
			start = frame
		elif mark[3] == "end":
			end = frame
	assert_gt(start, 0, "a start mark")
	assert_gte(end - start, 120, "the act runs at least 120 ticks between its marks")
	var regions := {}
	for rect in rects:
		assert_eq(rect.size(), 8, "LOOK-RECT <slug> f<frame> <region> x y w h")
		assert_eq(rect[1], "c1", "the slug")
		var frame := int(rect[2].trim_prefix("f"))
		assert_between(frame, start, end, "inside the act")
		var x := int(rect[4])
		var y := int(rect[5])
		var w := int(rect[6])
		var h := int(rect[7])
		assert_gt(w, 0, "%s has a width" % rect[3])
		assert_gt(h, 0, "%s has a height" % rect[3])
		assert_true(x >= 0 and y >= 0 and x + w <= int(ROOM_FRAME.x) and y + h <= int(ROOM_FRAME.y),
				"%s is inside 1600x900: %s" % [rect[3], " ".join(rect)])
		regions[rect[3]] = true
	for region: StringName in LookRect.ALL_REGIONS:
		assert_true(regions.has(String(region)), "a %s rectangle was printed" % region)


func test_c5_keeps_the_default_view_for_the_finishing_jab_and_pitches_down_when_the_ko_starts() -> void:
	# final-v2-03: the finishing jab launches the Punk about 3 m back, where it lay on the lens's bottom edge at the
	# default view (only the cap in the frame) for the KO slump and the blink-off, the J10 evidence. The view now
	# stays at the default through the jab and the launch and pitches down KO_PITCH_DEG once the KO state starts.
	var bot := QuietBot.new()
	bot.act_filter = "Look: Punk reacts at 1 m"
	add_child_autofree(bot)
	var pitch_at_ko := NAN
	var ran := 0
	for i in LONG_MAX_TICKS:
		await get_tree().physics_frame
		ran += 1
		if is_nan(pitch_at_ko) and bot.player != null:
			for enemy: Node in get_tree().get_nodes_in_group(&"enemy"):
				if (enemy as CombatActor).state == CombatTypes.ActorState.KO:
					pitch_at_ko = bot.player.look_pitch
		if bot.finished:
			break
	assert_true(bot.finished, "the act finished within %d ticks (%d)" % [LONG_MAX_TICKS, ran])
	assert_almost_eq(pitch_at_ko, deg_to_rad(LookActs.DEFAULT_PITCH_DEG), 0.001, "the view is the default on the KO's first frame: the jab and the launch were seen from it")
	assert_almost_eq(bot.player.look_pitch, deg_to_rad(LookActs.KO_PITCH_DEG), 0.001, "and it ends pitched down onto the body")
	var frame_of := {}
	var labels: Array[String] = []
	for mark in _look_lines(bot, "LOOK-MARK"):
		labels.append(mark[3])
		frame_of[mark[3]] = int(mark[2].trim_prefix("f"))
	for label: String in ["state_ko", "ko_slump", "ko_lying", "ko_blink_off", "ko_blink_on"]:
		assert_has(labels, label, "C5 marks %s" % label)
	if not (frame_of.has("state_ko") and frame_of.has("ko_slump") and frame_of.has("ko_lying") and frame_of.has("ko_blink_off") and frame_of.has("ko_blink_on")):
		return
	assert_lt(frame_of.state_ko, frame_of.ko_slump, "the KO starts, then the slump")
	assert_lt(frame_of.ko_slump, frame_of.ko_lying, "then the lying")
	assert_lt(frame_of.ko_lying, frame_of.ko_blink_off, "then the blink hides it")
	assert_lt(frame_of.ko_blink_off, frame_of.ko_blink_on, "and shows it again")
	# The body is in the frame at the slump and in the lying, its head in the upper part of the view: at the default view
	# the head's rectangle was centred at about 670 px of 900, on the bottom edge's side, and the legs, which come
	# nearest the lens, filled the rest. (The body's own rectangle is no test: a foot sphere near the lens clips it at 900.)
	for label: String in ["ko_slump", "ko_lying"]:
		var rects := {}
		for rect in _look_lines(bot, "LOOK-RECT"):
			if rect[2] == "f%d" % frame_of[label]:
				rects[rect[3]] = Rect2(int(rect[4]), int(rect[5]), int(rect[6]), int(rect[7]))
		assert_true(rects.has("head") and rects.has("body"), "%s: the head and the body are on the screen" % label)
		if not rects.has("head"):
			continue
		print("LOOK-ACTS C5 %s: the head's rectangle %s" % [label, rects.head])
		assert_lt((rects.head as Rect2).get_center().y, ROOM_FRAME.y * 0.6, "%s: the head is in the upper 60%% of the frame (%s)" % [label, rects.head])


func test_c9s_cast_stands_beside_the_tours_walk_not_on_it() -> void:
	# final-v4-04: the Punk 3.5 m ahead and the Bruiser 3.5 m behind stood on the two lines the tour walks, and the
	# open-loop walk pressed against them for most of the act (a Punk's face and then a Bruiser's chest at 0.4 m).
	# The cast flanks the lane now: the walk keeps its distance from everybody.
	for entry: Dictionary in LookActs.TOUR_CAST:
		assert_gte(absf((entry.rel as Vector2).x), 2.0, "%s at %s stands at least 2 m off the player's own line, ahead or behind" % [entry.id, entry.rel])
	var bot := QuietBot.new()
	bot.act_filter = "Look: street tour"
	add_child_autofree(bot)
	var nearest := INF
	var ran := 0
	for i in LONG_MAX_TICKS:
		await get_tree().physics_frame
		ran += 1
		if bot.player != null:
			for enemy: Node in get_tree().get_nodes_in_group(&"enemy"):
				var gap := (enemy as Node3D).global_position - (bot.player as Node3D).global_position
				gap.y = 0.0
				nearest = minf(nearest, gap.length())
		if bot.finished:
			break
	assert_true(bot.finished, "the act finished within %d ticks (%d)" % [LONG_MAX_TICKS, ran])
	# Two bodies touch at 0.8 m, the Punk and the player (0.4 m radii; the Bruiser's is wider). On the walk lines the
	# player stood at 0.8 m or so from them for hundreds of ticks; flanking at 2 m, the nearest any body comes is
	# well over a metre.
	print("LOOK-ACTS C9: the nearest the tour comes to anyone: %.2f m" % nearest)
	assert_gt(nearest, 1.2, "the tour never comes within 1.2 m of anyone (%.2f)" % nearest)


func test_the_warm_up_act_runs_and_says_so_when_there_is_no_window() -> void:
	# W1 watches the art warm-up's holder in the camera's frustum (slice-g1-03), which only a window
	# draws: headless the act marks its start and end and prints one LOOK-WARM line saying it skipped,
	# so a log never reads as a pass it did not make. The windowed result is recorded by the lead.
	var bot := QuietBot.new()
	bot.act_filter = "Look: warm-up in the lens"
	add_child_autofree(bot)
	await _run_bot(bot)
	var warm := _look_lines(bot, "LOOK-WARM")
	assert_eq(warm.size(), 1, "one line headless")
	assert_eq(warm[0][1], "skipped:")
	var labels: Array[String] = []
	for mark in _look_lines(bot, "LOOK-MARK"):
		assert_eq(mark[1], "w1", "the slug")
		labels.append(mark[3])
	assert_eq(labels, ["start", "end"] as Array[String], "no stills: only the act's own limits")
	assert_true(_look_lines(bot, "LOOK-RECT").is_empty(), "no rectangles")
	assert_true(bot.caption.visible, "the caption is back when the act is over")


func test_the_head_is_inside_the_body_rectangle() -> void:
	var bot := QuietBot.new()
	bot.act_filter = FIRST_ACT
	add_child_autofree(bot)
	await _run_bot(bot)
	var by_frame := {}
	for rect in _look_lines(bot, "LOOK-RECT"):
		by_frame[rect[2]] = by_frame.get(rect[2], {})
		by_frame[rect[2]][rect[3]] = Rect2(int(rect[4]), int(rect[5]), int(rect[6]), int(rect[7]))
	assert_gt(by_frame.size(), 0, "rectangles were printed")
	for frame: String in by_frame:
		var regions: Dictionary = by_frame[frame]
		if regions.has("head") and regions.has("body"):
			assert_true((regions.body as Rect2).grow(1.0).encloses(regions.head), "%s: the head is in the body" % frame)
		if regions.has("hands") and regions.has("body"):
			assert_true((regions.body as Rect2).grow(1.0).encloses(regions.hands), "%s: the hands are in the body" % frame)


# --- The perf bench's bot ----------------------------------------------------------------------


func test_the_perf_bot_prints_one_bench_line_for_an_act() -> void:
	var bot := QuietPerfBot.new()
	bot.act_filter = FIRST_ACT
	add_child_autofree(bot)
	await _run_bot(bot)
	var lines: Array[String] = []
	for line: String in bot.log_lines:
		if line.begins_with("PERF-BENCH "):
			lines.append(line.trim_prefix("PERF-BENCH "))
	assert_eq(lines.size(), 1, "one PERF-BENCH line for the one act")
	if lines.is_empty():
		return
	var result: Dictionary = JSON.parse_string(lines[0])
	assert_not_null(result, "it is JSON")
	for key in ["act", "frames", "mean_ms", "p95_ms", "worst_ms", "spawn_hitch_ms", "first_spawn_ms",
			"first_hit_ms", "first_finisher_ms", "spawns", "hits", "stalls", "vsync"]:
		assert_true(result.has(key), "has %s" % key)
	assert_eq(result.get("act"), "Look: Punk face at 1 m", "the act's own title")
	assert_gt(int(result.get("frames", 0)), 200, "a frame per process frame of the act")
	assert_lte(float(result.get("p95_ms", 0.0)), float(result.get("worst_ms", -1.0)), "p95 is at most the worst")
	assert_eq(int(result.get("spawns", 0)), 1, "the one Punk of the act appeared")
	assert_gte(float(result.get("first_spawn_ms", -1.0)), 0.0, "the first spawn has a hitch")
	assert_eq(float(result.get("first_hit_ms", 0.0)), -1.0, "nobody was hit: no first hit")


# --- tools/look_sheets.sh ----------------------------------------------------------------------


## The grey a still of frame `n` of the test video reads back as (see the test).
func _grey_of_frame(n: int) -> float:
	return (2.0 * n - 16.0) * 255.0 / 219.0


func test_look_sheets_cuts_stills_and_crops_from_a_video_and_its_log() -> void:
	var ffmpeg_ok := OS.execute("ffmpeg", ["-version"], [], true) == 0
	if not ffmpeg_ok:
		pending("ffmpeg is not installed")
		return
	var dir := ProjectSettings.globalize_path("user://look_sheets_test")
	OS.execute("rm", ["-rf", dir])
	DirAccess.make_dir_recursive_absolute(dir)
	var avi := dir.path_join("bot.avi")
	# A grey video whose brightness is twice the frame number (two seconds: up to 238), so a still
	# says which frame it is.
	var made := OS.execute("ffmpeg", ["-loglevel", "error", "-y", "-f", "lavfi", "-i",
			"color=c=black:size=1600x900:rate=60,format=yuvj420p,geq=lum='2*N':cb=128:cr=128", "-t", "2",
			"-c:v", "mjpeg", "-q:v", "1", avi], [], true)
	assert_eq(made, 0, "a test video was made")
	var log := FileAccess.open(dir.path_join("bot.log"), FileAccess.WRITE)
	log.store_string("\n".join([
		"=== Look: test  (f10)",
		"LOOK-MARK c1 f20 start",
		"LOOK-MARK c1 f50 idle_t030",
		"LOOK-RECT c1 f50 head 600 100 300 250",
		"LOOK-RECT c1 f50 body 300 100 1000 800",
		"LOOK-MARK c1 f110 end",
		"LOOK-MARK c2 f30 start",
		"LOOK-MARK c2 f100 hit",
		"LOOK-RECT c2 f100 hands 1500 700 400 400",
		"LOOK-MARK c2 f115 end",
		"LOOK-MARK c1 f20 start",
		"LOOK-MARK c1 f50 idle_t030",
		"LOOK-RECT c1 f50 head 600 100 300 250",
		"",
	]))
	log.close()
	var out := dir.path_join("sheets")
	var output: Array = []
	var status := OS.execute("bash", [ProjectSettings.globalize_path("res://tools/look_sheets.sh"), avi, out], output, true)
	assert_eq(status, 0, "look_sheets.sh ran: %s" % "".join(output))
	assert_true(FileAccess.file_exists(out.path_join("c1/overview_01.png")), "an overview of c1")
	assert_true(FileAccess.file_exists(out.path_join("c1/stills/c1_f50_idle_t030.png")), "a still at the mark")
	assert_false(FileAccess.file_exists(out.path_join("c1/stills/c1_f20_start.png")), "none at the start")
	assert_true(FileAccess.file_exists(out.path_join("c1/crops/c1_f50_head.png")), "a head crop")
	assert_true(FileAccess.file_exists(out.path_join("c1/crops/c1_f50_body.png")), "a body crop")
	assert_true(FileAccess.file_exists(out.path_join("c2/stills/c2_f100_hit.png")), "a still of the other act")
	# The still of frame 50 is frame 50: the grey of frame n reads back as (2n - 16) 255 / 219 (the
	# video's levels are taken as limited range), 98 for 50, where 49 and 51 would be 96 and 100.
	var still := Image.load_from_file(out.path_join("c1/stills/c1_f50_idle_t030.png"))
	assert_not_null(still, "the still loads")
	if still != null:
		assert_almost_eq(float(still.get_pixel(800, 450).r8), _grey_of_frame(50), 1.2, "the still is frame 50")
	var hit := Image.load_from_file(out.path_join("c2/stills/c2_f100_hit.png"))
	if hit != null:
		assert_almost_eq(float(hit.get_pixel(800, 450).r8), _grey_of_frame(100), 1.2, "and the other still is frame 100")
	var hands := Image.load_from_file(out.path_join("c2/crops/c2_f100_hands.png"))
	assert_not_null(hands, "the hands crop loads")
	if hands != null:
		# 1500 + 400 is past the right edge and 700 + 400 past the bottom: clipped to 100 x 200, twice.
		assert_eq(hands.get_size(), Vector2i(200, 400), "the crop is clipped to the video and doubled")
	var head := Image.load_from_file(out.path_join("c1/crops/c1_f50_head.png"))
	if head != null:
		assert_eq(head.get_size(), Vector2i(600, 500), "a 300 x 250 crop doubled")
	var index := FileAccess.get_file_as_string(out.path_join("index.txt"))
	assert_eq(index.count("c1_f50_idle_t030"), 1, "the log's repeated lines make one still")
	OS.execute("rm", ["-rf", dir])
