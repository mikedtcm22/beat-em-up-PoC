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


## What the ledger rows say about the milestone's Tripo account: {open: the task ids created and never finished, spent: the
## credits the finished rows consumed, lowest: the lowest balance after a task (INF with none), bad_credits: finished rows
## without a numeric credits_consumed}. Both the real ledger test and the synthetic one below read their rows through this.
static func audit(rows: Array[Dictionary]) -> Dictionary:
	var open := {}
	var spent := 0.0
	var lowest := INF
	var bad_credits: Array[String] = []
	for row: Dictionary in rows:
		match String(row.get("event", "")):
			"created":
				open[String(row.task_id)] = true
			"finished":
				open.erase(String(row.task_id))
				var credits: Variant = row.get("credits_consumed", null)
				if not (credits is float or credits is int):
					bad_credits.append(String(row.task_id))
				spent += float(row.get("credits_consumed", 0.0))
				lowest = minf(lowest, float(row.get("balance_after", INF)))
	return {open = open.keys(), spent = spent, lowest = lowest, bad_credits = bad_credits}


## The checks, as failure messages (an empty list passes): every created task finished with a real credits_consumed, the spend
## is at most the stop, no balance is under the floor.
static func violations(rows: Array[Dictionary]) -> Array[String]:
	var report := audit(rows)
	var out: Array[String] = []
	for id: String in report.open:
		out.append("task %s was created and never finished" % id)
	for id: String in report.bad_credits:
		out.append("%s: no real credits_consumed is logged" % id)
	if float(report.spent) > TRIPO_STOP:
		out.append("spend %.0f is over the %.0f stop" % [report.spent, TRIPO_STOP])
	if float(report.lowest) < TRIPO_FLOOR:
		out.append("a balance of %.0f is under the %.0f floor" % [report.lowest, TRIPO_FLOOR])
	return out


func test_every_m6_task_finished_the_spend_is_under_the_stop_and_the_balance_never_under_the_floor() -> void:
	var rows := _rows(MILESTONE)
	var report := audit(rows)
	assert_eq(violations(rows), [] as Array[String], "the ledger holds the M6 policy")
	var finished := 0
	for row: Dictionary in rows:
		finished += 1 if row.get("event", "") == "finished" else 0
	print("M6-LEDGER %d tasks, %.0f credits (stop %.0f, floor %.0f)" % [finished, report.spent, TRIPO_STOP, TRIPO_FLOOR])


func test_the_helper_catches_an_unfinished_task_a_spend_over_the_stop_and_a_low_balance() -> void:
	var good: Array[Dictionary] = [
		{event = "created", task_id = "a"}, {event = "finished", task_id = "a", credits_consumed = 50.0, balance_after = 1200.0},
	]
	assert_eq(violations(good), [] as Array[String], "a clean ledger has no violation")
	var unfinished: Array[Dictionary] = [{event = "created", task_id = "a"}]
	assert_eq(violations(unfinished).size(), 1, "a created task with no finished row is caught")
	var over: Array[Dictionary] = [
		{event = "finished", task_id = "b", credits_consumed = 500.0, balance_after = 1200.0},
		{event = "finished", task_id = "c", credits_consumed = 450.0, balance_after = 1100.0},
	]
	var over_found := violations(over)
	assert_eq(over_found.size(), 1, "950 credits is over the stop (and nothing else)")
	assert_true(over_found[0].contains("over"), over_found[0])
	var low: Array[Dictionary] = [{event = "finished", task_id = "d", credits_consumed = 10.0, balance_after = 650.0}]
	var low_found := violations(low)
	assert_eq(low_found.size(), 1, "a balance of 650 is under the floor (and nothing else)")
	assert_true(low_found[0].contains("floor"), low_found[0])
	var no_credits: Array[Dictionary] = [{event = "finished", task_id = "e", balance_after = 1000.0}]
	assert_eq(violations(no_credits).size(), 1, "a finished row without credits_consumed is caught")
