extends "res://tests/fixtures/arc_fixture.gd"
## A raised platform with a street 4.5 m below it, not joined by any stairs (two navmesh islands): the
## platform is x -5..5, z -5..5 with its top at y = 0 and the player at (0, 0, -3) looking along -Z at
## its edge; the street is x -20..20, z -25..25 with its top at y = -4.5, so a seat past the edge is
## nearer the street below in the navmesh's 3D distance than the platform's lip.


func _blocks() -> Array[Dictionary]:
	return [
		{center = Vector3(0.0, -0.5, 0.0), size = Vector3(10.0, 1.0, 10.0)},
		{center = Vector3(0.0, -5.0, 0.0), size = Vector3(40.0, 1.0, 50.0)},
	]
