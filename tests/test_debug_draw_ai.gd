extends GutTest
## F3's view of the enemy AI (Milestone 3; game/ui/debug_draw.gd): token holders, posture slots,
## the posture ring, the view boundary and the behind sector, and navigation paths, drawn from
## an EnemyDirector's read API (tests/fixtures/stub_director.gd) and the AI enemies in the scene
## (tests/fixtures/stub_enemy.tscn). Without a director and enemies the layer draws nothing, so
## the exact line counts of test_ui.gd stand. Lines are counted by their colour.

const DEBUG_DRAW := preload("res://game/ui/debug_draw.tscn")
const STUB_ENEMY := preload("res://tests/fixtures/stub_enemy.tscn")
const StubDirector := preload("res://tests/fixtures/stub_director.gd")


class FakePlayer:
	extends PlayerCharacter

	func _init() -> void:
		add_to_group(&"actor")
		add_to_group(&"player")
		display_name = "Player"
		team = 0
		max_health = 100.0
		health = 100.0

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func _physics_process(_delta: float) -> void:
		pass

	func _unhandled_input(_event: InputEvent) -> void:
		pass

	func get_head_top_position() -> Vector3:
		return global_position + Vector3.UP * 2.0

	func get_chest_position() -> Vector3:
		return global_position + Vector3.UP * 1.3

	func get_eye_transform() -> Transform3D:
		return Transform3D(Basis(), global_position + Vector3.UP * standing_eye_height)

	func get_magnetism_cone() -> Dictionary:
		return {}


var _draw: CombatDebugDraw
var _player: FakePlayer
var _director: Node


func before_each() -> void:
	Tuning.apply(TuningData.new())
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.make_current()
	_draw = DEBUG_DRAW.instantiate() as CombatDebugDraw
	add_child_autofree(_draw)
	_draw.enabled = true
	_player = FakePlayer.new()
	add_child_autofree(_player)


func _add_director() -> StubDirector:
	var director := StubDirector.new()
	add_child_autofree(director)
	_director = director
	return director


func _add_enemy(at: Vector3) -> EnemyActor:
	var enemy := STUB_ENEMY.instantiate() as EnemyActor
	add_child_autofree(enemy)
	enemy.global_position = at
	return enemy


## Lines of the AI layer's colours in the last rebuild, by name.
func _counts() -> Dictionary:
	_draw.rebuild()
	return {
		token = _draw.count_lines_of_color(_draw.token_color),
		slot = _draw.count_lines_of_color(_draw.slot_color),
		slot_line = _draw.count_lines_of_color(Color(_draw.slot_color, _draw.slot_line_alpha)),
		ring = _draw.count_lines_of_color(_draw.ring_color),
		view = _draw.count_lines_of_color(_draw.view_color),
		behind = _draw.count_lines_of_color(_draw.behind_color),
		path = _draw.count_lines_of_color(_draw.path_color),
	}


func _no_ai_lines(counts: Dictionary) -> bool:
	for key: String in counts:
		if counts[key] != 0:
			return false
	return true


func test_the_layer_draws_nothing_without_a_director_or_enemies() -> void:
	_add_enemy(Vector3(0.0, 0.0, -3.0))
	assert_true(_no_ai_lines(_counts()), "AI enemies but no director")
	var baseline := _draw.line_count
	var director := _add_director()
	assert_gt(_draw.line_count, baseline - 1)
	assert_false(_no_ai_lines(_counts()), "both: the layer is on")
	for enemy: Node in get_tree().get_nodes_in_group(&"ai_enemy"):
		enemy.remove_from_group(&"ai_enemy")
	assert_true(_no_ai_lines(_counts()), "a director and no AI enemies")
	assert_eq(_draw.line_count, baseline, "the lines are exactly what they were without it")
	assert_not_null(director)


func test_a_director_with_enemies_draws_the_ring_the_view_and_the_behind_sector() -> void:
	_add_director()
	_add_enemy(Vector3(0.0, 0.0, -3.0))
	var counts := _counts()
	assert_eq(counts.ring, 2 * CombatDebugDraw.CIRCLE_SEGMENTS, "two circles for the posture ring")
	assert_eq(counts.view, 2, "the view boundary, both ways")
	assert_eq(counts.behind, 2, "the behind sector's two edges")
	assert_eq(counts.token, 0, "nobody holds a token")
	assert_eq(counts.slot, 0, "nobody has a slot")


func test_the_boundary_lines_follow_the_look_and_the_tunables() -> void:
	_add_director()
	_add_enemy(Vector3(0.0, 0.0, -3.0))
	_player.look_yaw = deg_to_rad(30.0)
	Tuning.data.rear_warning_angle_deg = 70.0
	Tuning.data.rear_warning_behind_deg = 25.0
	_draw.rebuild()
	var verts: PackedVector3Array = _draw.get(&"_verts")
	var colors: PackedColorArray = _draw.get(&"_colors")
	var bearings: Dictionary = {}
	for i in range(0, verts.size() - 1, 2):
		var color := colors[i]
		if color != _draw.view_color and color != _draw.behind_color:
			continue
		var dir := verts[i + 1] - verts[i]
		# Degrees from the look (yaw 30 turned left; the look faces (-sin, -cos)), positive left.
		var look := Vector2(-sin(deg_to_rad(30.0)), -cos(deg_to_rad(30.0)))
		var left := Vector2(-cos(deg_to_rad(30.0)), sin(deg_to_rad(30.0)))
		var flat := Vector2(dir.x, dir.z)
		var bearing := rad_to_deg(atan2(flat.dot(left), flat.dot(look)))
		bearings.get_or_add(color, []).append(snappedf(bearing, 0.01))
		assert_almost_eq(flat.length(), _draw.view_line_length, 0.001, "the line's length")
	var view: Array = bearings[_draw.view_color]
	view.sort()
	assert_eq(view, [-70.0, 70.0], "rear_warning_angle_deg off the look, both ways")
	var behind: Array = bearings[_draw.behind_color]
	behind.sort()
	assert_eq(behind, [-155.0, 155.0], "the behind sector: 180 minus rear_warning_behind_deg, both ways")


func test_a_token_holder_gets_a_ring_and_a_line_to_the_player() -> void:
	var director := _add_director()
	var holder := _add_enemy(Vector3(2.0, 0.0, -3.0))
	director.give_token(holder)
	var other := _add_enemy(Vector3(-2.0, 0.0, -3.0))
	var counts := _counts()
	assert_eq(counts.token, CombatDebugDraw.CIRCLE_SEGMENTS + 1, "one ring and one line, for the holder only")
	# The line runs chest to chest.
	var verts: PackedVector3Array = _draw.get(&"_verts")
	var colors: PackedColorArray = _draw.get(&"_colors")
	var found := false
	for i in range(0, verts.size() - 1, 2):
		if colors[i] == _draw.token_color and verts[i].is_equal_approx(holder.get_chest_position()):
			found = true
			assert_true(verts[i + 1].is_equal_approx(_player.get_chest_position()), "to the player's chest")
	assert_true(found, "a line starts at the holder's chest")
	# A second holder doubles it; a freed one is skipped without an error.
	director.give_token(other)
	assert_eq(_counts().token, 2 * (CombatDebugDraw.CIRCLE_SEGMENTS + 1))
	other.free()
	assert_eq(_counts().token, CombatDebugDraw.CIRCLE_SEGMENTS + 1)


func test_posturing_enemies_get_a_slot_circle_and_a_dim_line() -> void:
	var director := _add_director()
	var one := _add_enemy(Vector3(0.0, 0.0, -3.5))
	var two := _add_enemy(Vector3(3.0, 0.0, 1.0))
	var three := _add_enemy(Vector3(-3.0, 0.0, 1.0))
	director.put_slot(one, Vector3(1.0, 0.0, -3.0))
	director.put_slot(two, Vector3(3.5, 0.0, 0.0))
	var counts := _counts()
	assert_eq(counts.slot, 2 * CombatDebugDraw.CIRCLE_SEGMENTS, "a circle for each enemy with a slot")
	assert_eq(counts.slot_line, 2, "and a dim line to it")
	assert_eq(counts.token, 0)
	assert_eq(director.debug_slot_of(three), Vector3.INF, "the third has none")
	_player.free()
	counts = _counts()
	assert_eq(counts.ring, 0, "no player: no ring, view or sector")
	assert_eq(counts.view, 0)
	assert_eq(counts.slot, 2 * CombatDebugDraw.CIRCLE_SEGMENTS, "but the slots still draw")


func test_a_ring_of_zero_is_not_drawn_and_the_ring_follows_the_directors() -> void:
	var director := _add_director()
	_add_enemy(Vector3(0.0, 0.0, -3.0))
	director.ring = Vector2(2.0, 0.0)
	assert_eq(_counts().ring, CombatDebugDraw.CIRCLE_SEGMENTS, "only the nearest circle")
	director.ring = Vector2(2.0, 5.0)
	assert_eq(_counts().ring, 2 * CombatDebugDraw.CIRCLE_SEGMENTS)


func test_an_enemy_with_a_navigation_agent_and_no_path_draws_no_path() -> void:
	_add_director()
	var enemy := _add_enemy(Vector3(0.0, 0.0, -3.0))
	var agent := NavigationAgent3D.new()
	enemy.add_child(agent)
	assert_eq(_counts().path, 0)


func test_the_ai_layer_writes_no_game_state() -> void:
	var director := _add_director()
	var holder := _add_enemy(Vector3(0.0, 0.0, -3.0))
	director.give_token(holder)
	director.put_slot(holder, Vector3(1.0, 0.0, -3.0))
	var before := [holder.global_position, holder.has_token, holder.posture_slot, director.holders.size(),
			_player.global_position, _player.look_yaw, director.released.size()]
	_draw.rebuild()
	_draw.rebuild()
	assert_eq([holder.global_position, holder.has_token, holder.posture_slot, director.holders.size(),
			_player.global_position, _player.look_yaw, director.released.size()], before)


# --- Attack arcs (Milestone 5) -------------------------------------------------------------------


## A stub director that says which enemies are engaged, on which line, and whether their arc slid.
class ArcDirector:
	extends StubDirector
	var centers: Dictionary = {}
	var slid: Dictionary = {}

	func debug_arc_center_of(enemy: EnemyActor) -> float:
		return float(centers.get(enemy, NAN))

	func debug_arc_slid(enemy: EnemyActor) -> bool:
		return bool(slid.get(enemy, false))


func _arc_counts() -> Dictionary:
	_draw.rebuild()
	return {
		arc = _draw.count_lines_of_color(_draw.arc_color),
		center = _draw.count_lines_of_color(Color(_draw.arc_color, _draw.slot_line_alpha)),
		slid = _draw.count_lines_of_color(_draw.arc_slid_color),
		wait = _draw.count_lines_of_color(_draw.wait_ring_color),
	}


func test_the_wait_ring_is_drawn_in_its_own_color_and_leaves_the_posture_ring_alone() -> void:
	_add_director()
	_add_enemy(Vector3(0.0, 0.0, -3.0))
	assert_eq(_arc_counts().wait, 2 * CombatDebugDraw.CIRCLE_SEGMENTS, "two circles for the wait ring")
	assert_eq(_counts().ring, 2 * CombatDebugDraw.CIRCLE_SEGMENTS, "the posture ring's lines are what they were")


func test_an_engaged_enemy_draws_its_arc_edges_and_center_line() -> void:
	var director := ArcDirector.new()
	add_child_autofree(director)
	_director = director
	var one := _add_enemy(Vector3(0.0, 0.0, -3.0))
	one.archetype = &"punk"
	var two := _add_enemy(Vector3(1.0, 0.0, -3.0))
	two.archetype = &"punk"
	var counts := _arc_counts()
	assert_eq(counts.arc, 0, "nobody engaged: no arc")
	director.centers[one] = 0.0
	director.centers[two] = 0.0
	counts = _arc_counts()
	assert_eq(counts.arc, 2, "two enemies on the same line share one arc: its two edges")
	assert_eq(counts.center, 1, "and its center line")
	# The edges are half the 90 degree arc either side of the line, from the player.
	var verts: PackedVector3Array = _draw.get(&"_verts")
	var colors: PackedColorArray = _draw.get(&"_colors")
	var bearings: Array[float] = []
	for i in range(0, verts.size() - 1, 2):
		if colors[i] == _draw.arc_color:
			var dir := verts[i + 1] - verts[i]
			bearings.append(snappedf(ViewGeometry.bearing_deg(0.0, Vector3.ZERO, Vector3(dir.x, 0.0, dir.z)), 0.01))
	bearings.sort()
	assert_eq(bearings, [-45.0, 45.0] as Array[float])
	director.centers[two] = 90.0
	assert_eq(_arc_counts().arc, 4, "another line, another arc")
	director.slid[two] = true
	counts = _arc_counts()
	assert_eq(counts.arc, 2)
	assert_eq(counts.slid, 2, "a slid arc is marked in its own color")


func test_a_360_degree_enemy_draws_no_edges() -> void:
	var director := ArcDirector.new()
	add_child_autofree(director)
	_director = director
	var kicker := _add_enemy(Vector3(0.0, 0.0, -3.0))
	kicker.archetype = &"kicker"
	director.centers[kicker] = 0.0
	assert_eq(_arc_counts().arc, 0)
