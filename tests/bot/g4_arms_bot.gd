extends "res://tests/bot/level_bot.gd"
## The G4 arms bot (M7): the level bot with one act, the first-person arms against a Punk on Mission 1's night street
## (tests/bot/g4_arms_acts.gd). It defaults to the whole level, so the street is the first section. Record with
##   godot --path . --write-movie captures/m7-slice/g4/arms/bot.avi --fixed-fps 60 --resolution 1600x900 \
##     res://tests/bot/g4_arms_bot.tscn -- --clean --tune=look_profile=1
## (`--tune=look_profile=0` for the m6 comparison); the act logs `G4 <n> <label> f<frame>` for each still to cut.

const ARMS_ACTS := preload("res://tests/bot/g4_arms_acts.gd")


func _init() -> void:
	level_path = "res://game/level/mission1/mission1.tscn"


func _collect_acts() -> Array[Dictionary]:
	return ARMS_ACTS.acts(self)
