extends GutTest
## Milestone 4, final review (V6-01): the Punk's art cache outlives the room's warm-up rig. SkinnedArt's
## cache holds an art only weakly (an Entry dies with its CharacterArt), and the throwaway rig of
## RoomKit.warm_up_art() was the only holder of the Punk's: freed at the room's first frame, it took the
## read of punk.glb with it, and the first Punk of every wave (the street empty again) ran
## SkinnedArt._read() on its spawn frame, about 19 ms headless against 2 ms with the art cached.
## RoomKit.warm_art() now holds the art for the run. warm_up_art() draws nothing without a window, so
## these tests drive the rig it builds (RoomKit.build_warm_rig(), the same call) themselves.
##
## "Reads nothing" is the Entry's identity: SkinnedArt._read() runs only for a new Entry, so the very
## Entry the warm-up's rig made, found again, means no read. The spawn costs are printed ("ART-WARM
## ...") and not asserted: a clock on a shared machine is noise, the Entry is not.

const PUNK_SCENE := "res://game/enemies/punk/street_punk.tscn"
const PUNK_ART := "res://game/actors/art/punk_art.tres"
## Frames a freed node needs to be gone (queue_free() runs at the end of the frame).
const SETTLE_FRAMES := 3


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.data.ai_frozen = true
	TimeController.clear()
	SkinnedArt.clear_cache()
	RoomKit.release_warm_art()


func after_each() -> void:
	# The hold and the cache are statics: leave neither for the next file.
	RoomKit.release_warm_art()
	SkinnedArt.clear_cache()
	Tuning.reset_to_default()
	TimeController.clear()


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## RoomKit.warm_up_art()'s steps without its window gate and its draw: the throwaway rig built and
## queue_free()d, as the room does at its load. Returns the Entry its build made and the art's
## instance id; the art itself is not kept here, so only the room kit's hold can keep it alive.
func _warm_up(host: Node3D) -> Dictionary:
	var rig := RoomKit.build_warm_rig(host)
	assert_not_null(rig, "the warm-up's art exists")
	var art_id := rig.art.get_instance_id()
	var entry := SkinnedArt.entry_of(rig.art)
	rig.queue_free()
	await _ticks(SETTLE_FRAMES)
	return {entry = entry, art_id = art_id}


## A Street Punk of the scene on a stage of its own, timed: {punk, ms}.
func _spawn(host: Node3D) -> Dictionary:
	var started := Time.get_ticks_usec()
	var punk := (load(PUNK_SCENE) as PackedScene).instantiate() as StreetPunk
	host.add_child(punk)
	return {punk = punk, ms = (Time.get_ticks_usec() - started) / 1000.0}


func _host() -> Node3D:
	var host := Node3D.new()
	add_child_autofree(host)
	return host


func test_the_warm_up_rig_builds_with_the_punks_art_and_reads_it_once() -> void:
	var host := _host()
	var rig := RoomKit.build_warm_rig(host)
	assert_not_null(rig)
	assert_eq(rig.name, &"WarmUpRig")
	assert_false(rig.build_hurtboxes, "a throwaway rig has no hurtboxes")
	assert_eq(rig.art.resource_path, PUNK_ART, "it wears the Punk's art")
	assert_true(rig.has_art(), "the art is attached")
	var entry := SkinnedArt.entry_of(rig.art)
	assert_true(entry.problems.is_empty(), "a clean read: %s" % [entry.problems])
	assert_false(entry.meshes.is_empty())
	assert_eq(RoomKit.warm_art(), rig.art, "warm_art() is the art the rig wears")
	rig.free()


func test_the_warmed_art_and_its_cache_entry_outlive_the_rig() -> void:
	var host := _host()
	var warmed := await _warm_up(host)
	assert_true(is_instance_id_valid(warmed.art_id), "the CharacterArt is still alive after its rig is freed")
	assert_true(RoomKit.warm_art_held())
	assert_same(SkinnedArt.entry_of(load(PUNK_ART) as CharacterArt), warmed.entry,
			"the cache still has the entry the warm-up's rig made: no read for the next Punk")


func test_the_first_punk_after_the_warm_up_reads_no_art() -> void:
	var host := _host()
	var warmed := await _warm_up(host)
	var first := _spawn(host)
	var punk: StreetPunk = first.punk
	assert_true(punk.rig.has_art(), "the Punk wears its art")
	assert_eq(punk.rig.art.get_instance_id(), warmed.art_id, "the scene's CharacterArt is the warm-up's: one resource")
	assert_same(SkinnedArt.entry_of(punk.rig.art), warmed.entry, "and its cache entry is the warm-up's: _read() did not run")
	print("ART-WARM first Punk after the warm-up: %.1f ms (art read %s)" % [first.ms, "no" if SkinnedArt.entry_of(punk.rig.art) == warmed.entry else "yes"])


func test_the_first_punk_of_a_later_wave_reads_no_art_either() -> void:
	var host := _host()
	var warmed := await _warm_up(host)
	var wave_one: Array[StreetPunk] = []
	for i: int in 3:
		wave_one.append(_spawn(host).punk)
	for punk: StreetPunk in wave_one:
		punk.queue_free()
	await _ticks(SETTLE_FRAMES)
	var next := _spawn(host)
	assert_same(SkinnedArt.entry_of(next.punk.rig.art), warmed.entry, "after every Punk is gone, the next wave's first still finds the entry")
	print("ART-WARM first Punk of the next wave: %.1f ms" % next.ms)


func test_without_the_hold_the_cache_still_drops_an_art_nothing_wears() -> void:
	# The weak cache is SkinnedArt's design and stays (ARCHITECTURE "Skinned art on the rig"): what the room kit
	# adds is a holder, not a stronger cache. With the hold let go, the old failure comes back (the control).
	var host := _host()
	var warmed := await _warm_up(host)
	RoomKit.release_warm_art()
	assert_false(RoomKit.warm_art_held())
	assert_false(is_instance_id_valid(warmed.art_id), "nothing else holds the art: it is freed with the hold")
	var first := _spawn(host)
	assert_not_same(SkinnedArt.entry_of(first.punk.rig.art), warmed.entry, "a Punk's own load reads afresh: a new entry")
	print("ART-WARM first Punk with no hold (the old behaviour): %.1f ms" % first.ms)


func test_warm_art_loads_once_and_is_the_same_object_every_time() -> void:
	assert_false(RoomKit.warm_art_held(), "nothing held before the first call")
	var art := RoomKit.warm_art()
	assert_not_null(art)
	assert_same(RoomKit.warm_art(), art)
	assert_same(load(PUNK_ART), art, "the path loads the same resource: a scene naming it gets this one")


func test_the_headless_warm_up_still_holds_nothing() -> void:
	# warm_up_art() is windowed work (test_art_punk, test_flash_fp): headless it neither adds a node nor holds an art,
	# so the tests' own cache behaviour is what it was.
	if DisplayServer.get_name() != "headless":
		pending("windowed: warm_up_art() holds the art")
		return
	var host := _host()
	RoomKit.warm_up_art(host)
	assert_eq(host.get_child_count(), 0)
	assert_false(RoomKit.warm_art_held())
