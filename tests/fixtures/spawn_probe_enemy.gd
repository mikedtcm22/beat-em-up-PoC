extends "res://tests/fixtures/stub_enemy.gd"
## The stub enemy that remembers how it was brought in (P1-room's tests): what enter_from() was told,
## and how many times. The spawner and the F4 menu call it right after the enemy enters the tree.

var entered_from: Vector3 = Vector3.INF
var entered_lane: Vector3 = Vector3.INF
var enter_calls: int = 0


func enter_from(spawn_pos: Vector3, lane_point: Vector3) -> void:
	entered_from = spawn_pos
	entered_lane = lane_point
	enter_calls += 1
	super.enter_from(spawn_pos, lane_point)
