extends GutTest
## Milestone 6's Tripo ledger (M6 plan §0, CHAIN): the twin of test_m4_done_when's A13 for the rows whose milestone is "M6"
## (assets/source/tripo_ledger.jsonl, tools/pipeline/tripo.py writes them). Every task that was created finished with its real
## credits_consumed logged, the milestone's spend is at most the 900 stop, and no balance after a task is under the 700 floor.
## A13 itself still reads only M4's rows (its stop is 750) and is unchanged. The M6 policy lives in tools/pipeline/tripo_prices.json;
## the test holds the file to the plan's numbers, so a stop raised by hand there fails here until the plan says so.

const LEDGER_PATH := "res://assets/source/tripo_ledger.jsonl"
const PRICES_PATH := "res://tools/pipeline/tripo_prices.json"
const MILESTONE := "M6"
const TRIPO_STOP := 900.0
const TRIPO_FLOOR := 700.0


## The ledger's rows of `milestone` (a row with no milestone is M4's: A13's default).
func _rows(milestone: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line: String in FileAccess.get_file_as_string(LEDGER_PATH).split("\n", false):
		var row: Variant = JSON.parse_string(line)
		if row is Dictionary and String((row as Dictionary).get("milestone", "M4")) == milestone:
			out.append(row)
	return out


func test_the_policy_names_m6_with_the_stop_and_the_floor_of_the_plan() -> void:
	var policy: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(PRICES_PATH)) as Dictionary).policy
	assert_eq(String(policy.milestone), MILESTONE, "the policy block is M6's")
	assert_lte(float(policy.ledger_stop), TRIPO_STOP, "the stop is at most the plan's 900")
	assert_gte(float(policy.balance_floor), TRIPO_FLOOR, "the floor is at least the plan's 700")


func test_every_m6_task_finished_the_spend_is_under_the_stop_and_the_balance_never_under_the_floor() -> void:
	var created := {}
	var finished := {}
	var spent := 0.0
	var floor_seen := INF
	for row: Dictionary in _rows(MILESTONE):
		match String(row.get("event", "")):
			"created":
				created[String(row.task_id)] = true
			"finished":
				finished[String(row.task_id)] = true
				var credits: Variant = row.get("credits_consumed", null)
				assert_true(credits is float or credits is int, "%s: the real credits_consumed is logged" % row.task_id)
				spent += float(row.get("credits_consumed", 0.0))
				floor_seen = minf(floor_seen, float(row.get("balance_after", INF)))
	for id: String in created:
		assert_true(finished.has(id), "task %s was created and finished (every credit is accounted for)" % id)
	assert_lte(spent, TRIPO_STOP, "M6's Tripo spend stays at or under the 900 stop (%.0f)" % spent)
	if not finished.is_empty():
		assert_gte(floor_seen, TRIPO_FLOOR, "no balance under the 700 floor (lowest %.0f)" % floor_seen)
	print("M6-LEDGER %d tasks, %.0f credits (stop %.0f, floor %.0f)" % [finished.size(), spent, TRIPO_STOP, TRIPO_FLOOR])


func test_the_test_has_teeth_an_unfinished_task_a_spend_over_the_stop_and_a_low_balance_are_caught() -> void:
	# The same arithmetic on synthetic rows: what the test above would fail on.
	var rows: Array[Dictionary] = [
		{event = "created", task_id = "a"}, {event = "finished", task_id = "b", credits_consumed = 500.0, balance_after = 1200.0},
		{event = "finished", task_id = "c", credits_consumed = 450.0, balance_after = 650.0},
	]
	var spent := 0.0
	var low := INF
	var open := {}
	for row: Dictionary in rows:
		if row.event == "created":
			open[row.task_id] = true
		else:
			open.erase(row.task_id)
			spent += float(row.credits_consumed)
			low = minf(low, float(row.balance_after))
	assert_true(open.has("a"), "a created task with no finished row is open")
	assert_gt(spent, TRIPO_STOP, "950 credits is over the stop")
	assert_lt(low, TRIPO_FLOOR, "650 is under the floor")
