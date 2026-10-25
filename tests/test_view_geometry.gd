extends GutTest
## ViewGeometry (M3-plan A2.1, Part B §B1): where a point is, seen from the player's look, and
## the rear warning's rule. The truth table below is written by hand from SPEC §8, row for row
## as Part B §B1 lists it: it is never derived from the function under test.
##
## Conventions: the look faces -Z at yaw 0; bearings are signed degrees, positive to the left,
## +-180 directly behind. Reach 1.0, margin 1.0, angle 55 and behind 20 (the tunables'
## defaults) unless a row says otherwise.

const ANGLE := 55.0
const BEHIND := 20.0
const MARGIN := 1.0
const REACH := 1.0
const NONE := &""
const LEFT := &"left"
const RIGHT := &"right"
const BOTH := &"both"


## [bearing, distance, expected corner]: Part B §B1's truth table.
const TABLE: Array[Array] = [
	# In view (inside +-55): nothing.
	[0.0, 1.5, &""], [30.0, 1.5, &""], [-30.0, 1.5, &""], [54.9, 1.5, &""], [-54.9, 1.5, &""],
	# Behind-left: top-left only.
	[55.1, 1.5, &"left"], [90.0, 1.5, &"left"], [135.0, 1.5, &"left"], [159.9, 1.5, &"left"],
	# Behind-right: top-right only.
	[-55.1, 1.5, &"right"], [-90.0, 1.5, &"right"], [-135.0, 1.5, &"right"], [-159.9, 1.5, &"right"],
	# Directly behind (within 20 of 180): both.
	[160.0, 1.5, &"both"], [-160.0, 1.5, &"both"], [170.0, 1.5, &"both"], [-170.0, 1.5, &"both"],
	[180.0, 1.5, &"both"], [-180.0, 1.5, &"both"],
	# Range: reach 1.0 + margin 1.0 = 2.0, inclusive.
	[135.0, 1.99, &"left"], [135.0, 2.0, &"left"], [135.0, 2.01, &""],
	[-135.0, 1.99, &"right"], [-135.0, 2.01, &""], [180.0, 2.01, &""],
]


func test_the_truth_table_of_the_warning_rule() -> void:
	for row: Array in TABLE:
		var corner := ViewGeometry.warning_corner(row[0], row[1], REACH, ANGLE, BEHIND, MARGIN)
		assert_eq(corner, row[2], "bearing %.1f at %.2f m" % [row[0], row[1]])


func test_the_rule_follows_its_tunables() -> void:
	# A wider view (angle 80) puts 70 in view; a narrower one (40) puts 45 out of it.
	assert_eq(ViewGeometry.warning_corner(70.0, 1.5, REACH, 80.0, BEHIND, MARGIN), NONE)
	assert_eq(ViewGeometry.warning_corner(45.0, 1.5, REACH, 40.0, BEHIND, MARGIN), LEFT)
	# The behind sector: 30 makes 150 "directly behind", 0 makes only the exact back so.
	assert_eq(ViewGeometry.warning_corner(150.0, 1.5, REACH, ANGLE, 30.0, MARGIN), BOTH)
	assert_eq(ViewGeometry.warning_corner(179.0, 1.5, REACH, ANGLE, 0.0, MARGIN), LEFT)
	assert_eq(ViewGeometry.warning_corner(180.0, 1.5, REACH, ANGLE, 0.0, MARGIN), BOTH)
	# The range: a longer reach, a bigger margin.
	assert_eq(ViewGeometry.warning_corner(135.0, 4.0, 3.0, ANGLE, BEHIND, MARGIN), LEFT)
	assert_eq(ViewGeometry.warning_corner(135.0, 2.9, REACH, ANGLE, BEHIND, 2.0), LEFT)
	assert_eq(ViewGeometry.warning_corner(135.0, 3.1, REACH, ANGLE, BEHIND, 2.0), NONE)
	# A behind sector wider than the view's far edge never lights a corner inside the view.
	assert_eq(ViewGeometry.warning_corner(50.0, 1.5, REACH, ANGLE, 140.0, MARGIN), NONE)


func test_bearings_from_the_look_along_minus_z() -> void:
	var from := Vector3(2.0, 0.0, 3.0)
	# Dead ahead, left (-X), right (+X) and behind (+Z).
	assert_almost_eq(ViewGeometry.bearing_deg(0.0, from, from + Vector3(0.0, 0.0, -2.0)), 0.0, 0.001, "ahead")
	assert_almost_eq(ViewGeometry.bearing_deg(0.0, from, from + Vector3(-2.0, 0.0, 0.0)), 90.0, 0.001, "left is positive")
	assert_almost_eq(ViewGeometry.bearing_deg(0.0, from, from + Vector3(2.0, 0.0, 0.0)), -90.0, 0.001, "right is negative")
	assert_almost_eq(absf(ViewGeometry.bearing_deg(0.0, from, from + Vector3(0.0, 0.0, 2.0))), 180.0, 0.001, "behind")
	# Behind-left at 135 degrees: left (-X) and back (+Z) in equal measure.
	assert_almost_eq(ViewGeometry.bearing_deg(0.0, from, from + Vector3(-1.0, 0.0, 1.0)), 135.0, 0.001, "behind-left")
	assert_almost_eq(ViewGeometry.bearing_deg(0.0, from, from + Vector3(1.0, 0.0, 1.0)), -135.0, 0.001, "behind-right")
	# Height changes nothing; a point straight above has no bearing.
	assert_almost_eq(ViewGeometry.bearing_deg(0.0, from, from + Vector3(-1.0, 5.0, 1.0)), 135.0, 0.001, "flat")
	assert_eq(ViewGeometry.bearing_deg(0.7, from, from + Vector3.UP * 3.0), 0.0, "straight above")


func test_the_bearing_is_independent_of_the_frame() -> void:
	# Looking along +X (yaw -90 degrees), a point placed at bearing +100 is on the look's left:
	# the same answer as with the look along -Z. Built from the look's own ahead and left.
	for yaw: float in [-PI * 0.5, PI * 0.5, 1.2, -2.5, 3.0]:
		var ahead := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var left := Vector3(-cos(yaw), 0.0, sin(yaw))
		for bearing: float in [0.0, 30.0, 100.0, 135.0, -135.0, -100.0, 170.0, -170.0]:
			var rad := deg_to_rad(bearing)
			var point := Vector3(5.0, 1.0, -4.0) + (ahead * cos(rad) + left * sin(rad)) * 1.5
			assert_almost_eq(ViewGeometry.bearing_deg(yaw, Vector3(5.0, 0.0, -4.0), point), bearing, 0.001,
					"yaw %.2f, bearing %.0f" % [yaw, bearing])
	# The table's frame-independence row: looking along +X, bearing +100, 1.0 m: LEFT.
	var yaw := -PI * 0.5
	var rad := deg_to_rad(100.0)
	var look := Vector3(-sin(yaw), 0.0, -cos(yaw))
	assert_almost_eq(look, Vector3.RIGHT, Vector3.ONE * 0.0001, "yaw -pi/2 faces +X")
	var attacker := look * cos(rad) + Vector3(-cos(yaw), 0.0, sin(yaw)) * sin(rad)
	var bearing := ViewGeometry.bearing_deg(yaw, Vector3.ZERO, attacker)
	assert_eq(ViewGeometry.warning_corner(bearing, 1.0, REACH, ANGLE, BEHIND, MARGIN), LEFT)


func test_the_bearing_wraps_around_behind() -> void:
	# -179.9 degrees with the look near +-pi: the yaw wrap (3.1 rad and -3.1 rad, either side
	# of the seam at pi) never turns a point directly behind into one in view.
	for yaw: float in [3.1, -3.1]:
		var ahead := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var left := Vector3(-cos(yaw), 0.0, sin(yaw))
		var rad := deg_to_rad(-179.9)
		var point := (ahead * cos(rad) + left * sin(rad)) * 1.0
		var bearing := ViewGeometry.bearing_deg(yaw, Vector3.ZERO, point)
		assert_almost_eq(bearing, -179.9, 0.001, "bearing at yaw %.1f" % yaw)
		assert_eq(ViewGeometry.warning_corner(bearing, 1.0, REACH, ANGLE, BEHIND, MARGIN), BOTH, "both corners at yaw %.1f" % yaw)


func test_is_outside_view() -> void:
	var from := Vector3.ZERO
	var at_54 := Vector3(-sin(deg_to_rad(54.0)), 0.0, -cos(deg_to_rad(54.0)))
	var at_56 := Vector3(-sin(deg_to_rad(56.0)), 0.0, -cos(deg_to_rad(56.0)))
	assert_false(ViewGeometry.is_outside_view(0.0, from, at_54, ANGLE), "54 degrees is in view")
	assert_true(ViewGeometry.is_outside_view(0.0, from, at_56, ANGLE), "56 degrees is outside")
	assert_true(ViewGeometry.is_outside_view(0.0, from, Vector3(0.0, 0.0, 1.0), ANGLE), "behind")
	assert_false(ViewGeometry.is_outside_view(0.0, from, Vector3(0.0, 0.0, -1.0), ANGLE), "ahead")
	# Mirrored on the right, and turned with the look.
	assert_true(ViewGeometry.is_outside_view(0.0, from, Vector3(at_56.x * -1.0, 0.0, at_56.z), ANGLE))
	assert_true(ViewGeometry.is_outside_view(PI * 0.5, from, Vector3(0.0, 0.0, -1.0), ANGLE), "a look turned 90 left has -Z on its right")


func test_forward_is_the_looks_flat_unit_vector() -> void:
	assert_almost_eq(ViewGeometry.forward(0.0), Vector3(0.0, 0.0, -1.0), Vector3.ONE * 0.0001)
	assert_almost_eq(ViewGeometry.forward(PI * 0.5), Vector3(-1.0, 0.0, 0.0), Vector3.ONE * 0.0001, "yaw turns left")
	assert_almost_eq(ViewGeometry.forward(-PI * 0.5), Vector3(1.0, 0.0, 0.0), Vector3.ONE * 0.0001)
	assert_almost_eq(ViewGeometry.forward(1.234).length(), 1.0, 0.0001)
