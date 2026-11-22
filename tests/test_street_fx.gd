extends GutTest
## Milestone 7, T16a: the trailer street's 2D effects (StreetFx under VfxDirector). They exist only under look profile "trailer" in
## Mission 1's street, are absent under m6, hold on twos, and carry no collider or navigation.

const LookProfileHelper := preload("res://tests/look_profile_helper.gd")
const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const CROWD_PATH := "res://game/level/crowd_room.tscn"
const SETTLE_FRAMES := 4


func before_each() -> void:
	Tuning.reset_to_default()
	LookProfileHelper.use_m6()
	Tuning.set_value(&"waves_enabled", false)
	# the trailer profile's drawn cards hold the simulation (M7 C5); these tests time the effects, so they run without them
	Tuning.set_value(&"cutins_enabled", false)


func after_each() -> void:
	Tuning.reset_to_default()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _build(path: String) -> Node:
	var root := (load(path) as PackedScene).instantiate()
	if "waves_enabled_on_start" in root:
		root.set(&"waves_enabled_on_start", false)
	add_child_autofree(root)
	await _ticks(SETTLE_FRAMES)
	return root


func _fx(room: Node) -> StreetFx:
	return room.find_child("StreetFx", true, false) as StreetFx


func _collision_nodes(node: Node) -> int:
	var count := 1 if node is CollisionObject3D or node is CollisionShape3D or node is NavigationRegion3D or node is NavigationObstacle3D else 0
	for child: Node in node.get_children():
		count += _collision_nodes(child)
	return count


func test_absent_under_m6() -> void:
	var room := await _build(LEVEL_PATH)
	var fx := _fx(room)
	assert_not_null(fx, "VfxDirector owns a StreetFx")
	assert_false(fx.is_built())
	assert_eq(fx.get_child_count(), 0, "m6 draws no street effect nodes at all")


func test_built_under_trailer_and_gone_again() -> void:
	var room := await _build(LEVEL_PATH)
	var fx := _fx(room)
	Tuning.set_value(&"look_profile", 1)
	assert_true(fx.is_built())
	assert_eq(fx.counts().cards, 4)
	assert_eq(fx.counts().barrels, 2)
	assert_gt(fx.materials().size(), 4)
	Tuning.set_value(&"look_profile", 0)
	assert_false(fx.is_built())
	await _ticks(2)
	assert_eq(fx.get_child_count(), 0)


func test_trailer_from_the_start() -> void:
	Tuning.set_value(&"look_profile", 1)
	var room := await _build(LEVEL_PATH)
	assert_true(_fx(room).is_built())


func test_no_colliders_or_navigation() -> void:
	Tuning.set_value(&"look_profile", 1)
	var room := await _build(LEVEL_PATH)
	assert_eq(_collision_nodes(_fx(room)), 0)
	var barrel: Node = autofree((load("res://game/level/props/burn_barrel.tscn") as PackedScene).instantiate())
	assert_eq(_collision_nodes(barrel), 0)


func test_holds_on_twos() -> void:
	Tuning.set_value(&"look_profile", 1)
	var room := await _build(LEVEL_PATH)
	var fx := _fx(room)
	var hz := Tuning.data.tfx_twos_hz
	var start := fx.slot()
	var changes := 0
	var last := start
	var ticks := 60
	for i in ticks:
		fx.advance(1.0 / 60.0)
		if fx.slot() != last:
			changes += 1
			last = fx.slot()
	assert_almost_eq(float(changes), hz, 1.0, "a second of effect time is tfx_twos_hz drawings")


func test_not_in_the_crowd_room() -> void:
	Tuning.set_value(&"look_profile", 1)
	var room := await _build(CROWD_PATH)
	var fx := _fx(room)
	assert_not_null(fx)
	assert_false(fx.is_built(), "the set names Mission 1's street; no other room draws it")


func test_warm_up_draws_stand_ins_on_the_camera_then_frees_them() -> void:
	var room := await _build(LEVEL_PATH)
	var fx := _fx(room)
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.make_current()
	var before := camera.get_child_count()
	fx.begin_warm_up(true)
	# process_frame fires before the frame's _process calls: one await lets the director's _process run, a second sees its result.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(fx.warming(), "the stand-ins are up for a frame")
	assert_gt(camera.get_child_count(), before)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(fx.warming())
	assert_eq(camera.get_child_count(), before, "nothing is left on the camera")
	assert_eq(fx.get_child_count(), 0, "m6 keeps no node under StreetFx")
	assert_false(fx.begin_warm_up(false), "headless: no warm-up")
