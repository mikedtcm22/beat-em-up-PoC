extends RefCounted
## The look profile for the tests (not a test script). The game starts under the trailer profile (the comic look, since
## Milestone 7, T53); a test that asserts M6 pixels, colours, materials, HUD or timing calls `LookProfileHelper.use_m6()` in its
## setup, after any `Tuning.apply(TuningData.new())` or `Tuning.reset_to_default()` (those bring the shipped default back).
## `no_cards()` is the other switch: a test or bot whose simulation timing the drawn cut-in cards would disturb turns them off,
## and the default (cards on under the trailer profile) stays what it is.

const M6 := 0
const TRAILER := 1


## Run the M6 look (Tuning's `look_profile` = 0), live, so the post pass and the materials follow.
static func use_m6() -> void:
	Tuning.set_value(&"look_profile", M6)


## Run the trailer look.
static func use_trailer() -> void:
	Tuning.set_value(&"look_profile", TRAILER)


## Turn the cut-in cards off (the `cutins_enabled` tunable); the look profile is untouched.
static func no_cards() -> void:
	Tuning.set_value(&"cutins_enabled", false)


## Put the look profile back to the shipped default (a test that ran under m6 and does not reset all of Tuning calls this in its teardown).
static func restore() -> void:
	Tuning.set_value(&"look_profile", TuningData.new().look_profile)
