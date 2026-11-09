extends GutTest
## LD-STAGE's frame writer, the parts that need no GPU: which ticks of the 60 Hz simulation are written (the 24 fps picks, never blended),
## the encode's arguments, the concat list and the file names. The pixels are windowed: tools/video/shoot.sh renders them.


func test_a_second_of_ticks_gives_24_picks_and_no_blending() -> void:
	var picks := CineFrameWriter.picks(0, 59, 60, 24)
	assert_eq(picks.size(), 24, "24 of the 60 ticks are written")
	for n in picks.size():
		assert_eq(CineFrameWriter.output_index(picks[n], 60, 24), n, "pick %d is output frame %d: one tick per frame, in order" % [n, n])
	# Each output frame is one tick of the simulation (a pick), so nothing is the mix of two ticks.
	for n in range(1, picks.size()):
		assert_gt(picks[n], picks[n - 1], "the picks only move forward")


func test_the_picks_follow_floor_of_tick_times_24_over_60() -> void:
	# The first ticks: 0, 3, 5, 8, 10, 13 ... (the index changes at 3 (1.2), 5 (2.0), 8 (3.2), 10 (4.0)).
	var expected := PackedInt32Array([0, 3, 5, 8, 10, 13, 15, 18, 20, 23])
	assert_eq(CineFrameWriter.picks(0, 23, 60, 24), expected)
	assert_true(CineFrameWriter.is_pick(0, 0, 60, 24), "the window's first tick is always written")
	assert_false(CineFrameWriter.is_pick(1, 0, 60, 24))
	assert_false(CineFrameWriter.is_pick(2, 0, 60, 24))
	assert_true(CineFrameWriter.is_pick(3, 0, 60, 24))


func test_a_window_that_starts_late_writes_its_first_tick_and_keeps_the_clock_indices() -> void:
	# A window starting at tick 1 (index 0): written although the index did not change there; the next pick is tick 3.
	var picks := CineFrameWriter.picks(1, 10, 60, 24)
	assert_eq(picks[0], 1)
	assert_eq(picks[1], 3)
	assert_false(CineFrameWriter.is_pick(0, 1, 60, 24), "nothing before the window")


func test_five_seconds_is_120_frames() -> void:
	assert_eq(CineFrameWriter.picks(0, 299, 60, 24).size(), 120)
	assert_eq(CineFrameWriter.picks(0, 299, 60, 30).size(), 150, "another output rate follows the same rule")


func test_the_mezzanine_is_high_quality_yuv444_and_tagged() -> void:
	var args := CineFrameWriter.raw_encode_args("/tmp/c.rgb", Vector2i(2560, 1440), 200, 24, "/tmp/p.mkv", 8, "slow", "yuv444p")
	assert_true(args.has("libx264"))
	assert_eq(args[args.find("-crf") + 1], "8")
	assert_eq(args[args.find("-preset") + 1], "slow")
	assert_eq(args[args.find("-pix_fmt") + 1], "yuv444p")
	assert_eq(args[args.find("-video_size") + 1], "2560x1440")
	assert_eq(args[args.find("-frames:v") + 1], "200")
	assert_eq(args[args.find("-colorspace") + 1], "bt709", "tagged BT.709")
	assert_true(String(args[args.find("-vf") + 1]).ends_with("format=yuv444p"), "converted with the BT.709 matrix")
	var png_args := CineFrameWriter.encode_args("/tmp/f%05d.png", 400, 200, 24, "/tmp/p.mkv", 8, "slow", "yuv444p")
	assert_eq(png_args[png_args.find("-start_number") + 1], "400", "a PNG chunk starts at its first number")


func test_the_mask_is_the_alpha_channel_as_lossless_gray() -> void:
	var args := CineFrameWriter.mask_encode_args("/tmp/m%05d.png", 0, 10, 24, "/tmp/m.mkv")
	assert_true(args.has("ffv1"))
	assert_eq(args[args.find("-vf") + 1], "alphaextract,format=gray")
	assert_eq(args[args.find("-pix_fmt") + 1], "gray")


func test_parts_are_joined_by_the_concat_list() -> void:
	var list := CineFrameWriter.concat_list(PackedStringArray(["/o/s_part000.mkv", "/o/s_part001.mkv"]))
	assert_eq(list, "file 's_part000.mkv'\nfile 's_part001.mkv'\n")


func test_frame_files_have_fixed_width_names() -> void:
	assert_eq(CineFrameWriter.frame_path("/d", 7), "/d/f00007.png")
	assert_eq(CineFrameWriter.mask_frame_path("/d", 123), "/d/m00123.png")
	assert_eq(CineFrameWriter.raw_path("/d", 200), "/d/chunk00200.rgb")


func test_the_writer_defaults_are_the_brief() -> void:
	var writer := CineFrameWriter.new()
	assert_eq(writer.size, Vector2i(2560, 1440))
	assert_eq(writer.out_fps, 24)
	assert_eq(writer.chunk_frames, 200)
	assert_eq(writer.crf, 8)
	assert_eq(writer.preset, "slow")
	assert_eq(writer.pixel_format, "yuv444p")
	assert_eq(writer.msaa, Viewport.MSAA_4X)
	assert_true(writer.write_mask)
	writer.free()


func test_the_mask_layer_is_not_a_layer_the_game_uses() -> void:
	var used := CombatTypes.bit(CombatTypes.VIS_DEFAULT) | CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN) | CombatTypes.bit(CombatTypes.VIS_DEBUG)
	assert_eq(CineFrameWriter.MASK_LAYER & used, 0, "the extra layer is free")
