extends GutTest
## Milestone 6 KIT (D1): the art only draws. The static colliders of Mission 1, the crowd room and the
## training room are held to the snapshot of M5's unchanged level (tests/fixtures/m6/m5_colliders.json;
## the builder is tests/m6_collider_snapshot.gd): the same walls, in the same places, at the same sizes
## and layers, whatever the kit draws over them. A collision that is changed on purpose rewrites the
## fixture, `M6_WRITE_COLLIDERS=1 tools/run_tests.sh -gselect=test_m6_colliders.gd`, and the reason
## goes in the milestone's calls file.
##
## Also: the art adds no collider (nothing under a visual node is a body).

const Snapshot := preload("res://tests/m6_collider_snapshot.gd")
const FIXTURE := "res://tests/fixtures/m6/m5_colliders.json"


func _build(key: StringName) -> Array:
	var holder := Node.new()
	add_child_autofree(holder)
	var node := Snapshot.instantiate(Snapshot.SCENES[key], holder)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return Snapshot.snapshot(node)


func before_all() -> void:
	if OS.get_environment("M6_WRITE_COLLIDERS") != "1":
		return
	var data := {}
	for key: StringName in Snapshot.SCENES:
		data[String(key)] = await _build(key)
	var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t", true))
	file.close()


func _fixture() -> Dictionary:
	var file := FileAccess.open(FIXTURE, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _same(key: StringName) -> void:
	var fixture := _fixture()
	assert_true(fixture.has(String(key)), "the fixture has '%s'" % key)
	var want: Array = fixture.get(String(key), [])
	var got := await _build(key)
	assert_gt(want.size(), 0, "%s: the snapshot is not empty" % key)
	assert_eq(got.size(), want.size(), "%s: the number of static colliders" % key)
	var want_keys := {}
	for entry: Dictionary in want:
		want_keys[Snapshot.key(_as_entry(entry))] = entry
	var got_keys := {}
	for entry: Dictionary in got:
		got_keys[Snapshot.key(entry)] = entry
	var gone := 0
	for k: String in want_keys:
		if not got_keys.has(k):
			gone += 1
			if gone <= 5:
				fail_test("%s: M5's collider is gone or changed: %s" % [key, want_keys[k]])
	var added := 0
	for k: String in got_keys:
		if not want_keys.has(k):
			added += 1
			if added <= 5:
				fail_test("%s: a collider that M5 did not have: %s" % [key, got_keys[k]])
	assert_eq(gone, 0, "%s: every M5 collider still there, as it was" % key)
	assert_eq(added, 0, "%s: no collider added" % key)


## A fixture entry as the snapshot's own types (JSON reads numbers as floats).
func _as_entry(entry: Dictionary) -> Dictionary:
	var out := entry.duplicate()
	out.position = Snapshot._mm(Vector3(entry.position[0], entry.position[1], entry.position[2]))
	out.size = Snapshot._mm(Vector3(entry.size[0], entry.size[1], entry.size[2]))
	out.layer = int(entry.layer)
	return out


func test_mission1_colliders_are_m5s() -> void:
	await _same(&"mission1")


func test_crowd_room_colliders_are_m5s() -> void:
	await _same(&"crowd_room")


func test_training_room_colliders_are_m5s() -> void:
	await _same(&"training_room")
