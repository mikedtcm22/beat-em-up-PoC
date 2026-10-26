extends GutTest
## tools/check_m3_log.py (Milestone 3, P4-int): it passes a good crowd-bot log and fails a bad one,
## each of its checks on a log written here. Skipped (pending) where python3 is not installed.

const SCRIPT := "res://tools/check_m3_log.py"

## Act one, then a wind-up that began in the gap before act two (the bot runs on 45 frames after an
## act and then resets the room; the reset cuts the wind-up short, so it has no WU- line and its
## line can come out after the next act's header), then act two with one wind-up of its own.
const GAP := """=== Act one  (f10)
W+ f41 side=left count=1 heavy=false
WU+ f41 Punk1 punk_jab
W- f63 side=left
WARN-CHECK ok Act one left f41 lat=0 end=0
READABILITY Act one
W+ f2591 side=right count=1 heavy=false
WU+ f2591 Kicker9 kicker_jump_kick
W- f2600 side=right
=== Act two  (f2602)
WARN-CHECK ok Act two right f2591 lat=- end=-
W+ f2700 side=left count=1 heavy=false
WU+ f2700 Punk2 punk_jab
WARN-CHECK ok Act two left f2700 lat=0 end=0
"""

## An act with three wind-ups: behind-left, in view (dark) and directly behind; one token holder.
const GOOD := """=== Act one  (f10)
TOK+ f20 Punk1
W+ f41 side=left count=1 heavy=false
WU+ f41 Punk1 punk_jab
WU+ f41 Punk1 punk_jab
W- f63 side=left
WARN-CHECK ok Act one left f41 lat=0 end=0
WU+ f90 Punk1 punk_jab
WARN-CHECK ok Act one none f90 lat=- end=-
W+ f120 side=left count=1 heavy=false
W+ f120 side=right count=1 heavy=false
WU+ f120 Kicker1 kicker_jump_kick
WARN-CHECK ok Act one both f120 lat=0 end=1
TOK- f130 Punk1
"""


## Where this run writes its log: every worktree is the same project and shares one user://, so
## the name carries the process id (as test_tuning_panel.gd's scratch folder does) and a suite
## running beside this one cannot overwrite it between the write and the read.
func _log_path() -> String:
	return "user://check_m3_log_test_%d.log" % OS.get_process_id()


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_log_path()))


func _check(text: String, extra: Array[String] = []) -> Dictionary:
	var path := _log_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var args: Array[String] = [ProjectSettings.globalize_path(SCRIPT)]
	args.append_array(extra)
	args.append(ProjectSettings.globalize_path(path))
	var output: Array = []
	var code := OS.execute("python3", PackedStringArray(args), output, true)
	return {code = code, text = "\n".join(PackedStringArray(output))}


func _python_missing(result: Dictionary) -> bool:
	if result.code == -1:
		pending("python3 is not installed")
		return true
	return false


func test_a_good_log_passes_and_a_repeated_event_line_is_read_once() -> void:
	var result := _check(GOOD)
	if _python_missing(result):
		return
	assert_eq(result.code, 0, result.text)
	assert_string_contains(result.text, "3 WARN-CHECK (2 warned)")


func test_a_windup_from_the_gap_before_an_act_is_skipped_even_when_its_line_follows_the_header() -> void:
	var result := _check(GAP)
	if _python_missing(result):
		return
	assert_eq(result.code, 0, "the gap's wind-up is not act two's: " + result.text)
	assert_string_contains(result.text, "2 WARN-CHECK (2 warned)")
	assert_string_contains(result.text, "skipped")
	# The same line with a frame inside the act is the act's own wind-up, and a corner that never
	# lit is still a failure there.
	var own := _check(GAP.replace("f2591 lat=- end=-", "f2610 lat=- end=-").replace("WU+ f2591", "WU+ f2610").replace("W+ f2591", "W+ f2610").replace("W- f2600", "W- f2620"))
	assert_eq(own.code, 1, "a wind-up of the act's own that never lit fails: " + own.text)
	assert_string_contains(own.text, "never lit")
	# And a line that follows its act's READABILITY block (no header since) is skipped as before.
	var after := _check(GAP.replace("=== Act two  (f2602)\nWARN-CHECK ok Act two right f2591 lat=- end=-\n", "WARN-CHECK ok Act one right f2591 lat=- end=-\n=== Act two  (f2602)\n"))
	assert_eq(after.code, 0, "a line after the READABILITY block: " + after.text)
	assert_string_contains(after.text, "1 WARN-CHECK")


func test_a_failing_warn_check_fails_the_log() -> void:
	var result := _check(GOOD.replace("WARN-CHECK ok Act one left f41 lat=0 end=0", "WARN-CHECK FAIL Act one left f41 lat=- end=- why=not-lit"))
	if _python_missing(result):
		return
	assert_eq(result.code, 1, result.text)
	assert_string_contains(result.text, "WARN-CHECK FAIL")


func test_a_corner_lit_late_or_without_its_widget_line_fails() -> void:
	var late := _check(GOOD.replace("lat=0 end=0", "lat=2 end=0"))
	if _python_missing(late):
		return
	assert_eq(late.code, 1, late.text)
	assert_string_contains(late.text, "over 1")
	var dark := _check(GOOD.replace("W+ f41 side=left count=1 heavy=false\n", ""))
	assert_eq(dark.code, 1, dark.text)
	assert_string_contains(dark.text, "no W+ line for left")


func test_a_corner_lit_where_the_rule_says_dark_fails() -> void:
	var result := _check(GOOD + "W+ f90 side=right count=1 heavy=false\n")
	if _python_missing(result):
		return
	assert_eq(result.code, 1, result.text)
	assert_string_contains(result.text, "dark")


func test_more_token_holders_than_the_cap_fails_and_an_act_header_forgets_them() -> void:
	var over := "=== A  (f1)\nTOK+ f2 Punk1\nTOK+ f3 Punk2\nTOK+ f4 Punk3\nTOK+ f5 Punk4\n"
	var result := _check(over)
	if _python_missing(result):
		return
	assert_eq(result.code, 1, result.text)
	assert_string_contains(result.text, "over the cap of 3")
	var split := _check("=== A  (f1)\nTOK+ f2 Punk1\nTOK+ f3 Punk2\nTOK+ f4 Punk3\n=== B  (f9)\nTOK+ f12 Punk1\nTOK+ f13 Punk2\nTOK+ f14 Punk3\n")
	assert_eq(split.code, 0, split.text)
	var wider := _check(over, ["--cap", "4"])
	assert_eq(wider.code, 0, "four holders fit a cap of 4: " + wider.text)


func test_a_hand_over_in_one_frame_is_not_a_fourth_holder() -> void:
	# The bot prints a frame's token lines in tree order: a grant can come before the loss it follows.
	var text := "=== A  (f1)\nTOK+ f2 Punk1\nTOK+ f3 Punk2\nTOK+ f4 Punk3\nTOK+ f9 Punk4\nTOK- f9 Punk1\n"
	var result := _check(text)
	if _python_missing(result):
		return
	assert_eq(result.code, 0, result.text)
	var four := _check(text.replace("TOK- f9 Punk1\n", "TOK- f10 Punk1\n"))
	assert_eq(four.code, 1, "but a fourth holder that lives a frame is over the cap: " + four.text)


func test_a_hard_metric_failure_or_an_engine_error_fails_the_log() -> void:
	var hard := _check(GOOD + "READABILITY Act one\n  R1  attackers at once        max 4      FAIL (hard) <= 3\n")
	if _python_missing(hard):
		return
	assert_eq(hard.code, 1, hard.text)
	assert_string_contains(hard.text, "hard metric")
	var error := _check(GOOD + "SCRIPT ERROR: Parse Error: nope\n")
	assert_eq(error.code, 1, error.text)


func test_a_log_with_no_warning_checks_is_a_note_and_a_failure_only_when_strict() -> void:
	var plain := _check("=== A  (f1)\nAI f2 Punk1 new->ENTER\n")
	if _python_missing(plain):
		return
	assert_eq(plain.code, 0, plain.text)
	var strict := _check("=== A  (f1)\nAI f2 Punk1 new->ENTER\n", ["--strict"])
	assert_eq(strict.code, 1, strict.text)
