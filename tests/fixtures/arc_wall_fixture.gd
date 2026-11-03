extends "res://tests/fixtures/arc_fixture.gd"
## The player's end of a room with a wall 2 m ahead (the origin looking along -Z): floor from the wall
## (z = -2) back to z = 14 and x -10..10, the wall across it. No floor past the wall, so no point on
## the posture ring ahead of the player is on his floor.


func _blocks() -> Array[Dictionary]:
	return [
		{center = Vector3(0.0, -0.5, 6.0), size = Vector3(20.0, 1.0, 16.0)},
		{center = Vector3(0.0, 2.0, -2.5), size = Vector3(20.0, 5.0, 1.0)},
	]
