extends GutTest
## The lead's round 3 call after LD-INK2 (docs/video/HANDOFF.md, 2026-11-09): the player's first-person arm takes its own, lower face-zone
## fill at night and on the boss roof, so it is no longer the brightest thing in the frame, while the Punk's and Ox's faces keep theirs.


func test_an_id_without_an_entry_takes_the_face_fill() -> void:
	var look := VideoArtLook.new()
	look.face_fill = 0.5
	look.face_fill_by_id = {"player": 0.15}
	assert_almost_eq(look.face_fill_of(&"punk"), 0.5, 0.0001)
	assert_almost_eq(look.face_fill_of(&"player"), 0.15, 0.0001)


func test_the_arm_is_filled_less_than_the_faces_at_night_and_on_the_boss_roof() -> void:
	for path: String in ["res://video/look/street_night/art.tres", "res://video/look/boss_fire/art.tres"]:
		var look := load(path) as VideoArtLook
		assert_not_null(look, path)
		assert_lt(look.face_fill_of(&"player"), look.face_fill_of(&"punk"), path)
		assert_lt(look.face_fill_of(&"player"), look.face_fill_of(&"boss"), path)
		assert_almost_eq(look.face_fill_of(&"boss"), look.face_fill, 0.0001, path)
