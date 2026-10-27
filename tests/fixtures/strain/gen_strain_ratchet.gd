extends Node
## Writes tests/fixtures/strain/strain_ratchet.json: the per-clip figures of the shipped art's A19 strain run (tests/art_strain.gd),
## what the final art does today, which test_skinned_art and test_m4_done_when hold every clip to, plus CLIP_MARGIN. Each art's
## entry is `{"<clip>": {high, low, max, min, bad}}` (the worst p99.9, the lowest p0.1, the longest stretch and the deepest
## compression over the clip's five phases; `bad` is a peak flex's squashed or turned-over triangles), rounded to 4 places.
##
## A scene (the rigs read autoloads): `godot --headless res://tests/fixtures/strain/gen_strain_ratchet.tscn --quit-after 5`
## (about 15 s). It also prints the whole-run figures SHIPPED's rows are set from (today's figure plus a margin). Run it when a
## ratchet is meant to move, after a GLB rebuild that improved the strain, and commit the file with the new SHIPPED figures: a
## ratchet only ever moves down.

const ArtStrain := preload("res://tests/art_strain.gd")


func _ready() -> void:
	var out := {}
	for row: Dictionary in ArtStrain.SHIPPED:
		var art := load(row.art) as CharacterArt
		if row.player:
			art = PlayerCharacter.worn_art(art)
		var rig := HumanoidRig.new()
		if row.player:
			var dresser := PlayerCharacter.new()
			dresser._configure_rig(rig)
			dresser.free()
		rig.height = 1.8
		rig.build_hurtboxes = false
		rig.art = art
		add_child(rig)
		rig.build()
		rig.play(&"idle", 0.0)
		rig.advance(0.0)
		var moves: Array[MoveData] = []
		if not row.player:
			moves = ArtStrain.punk_moves()
		var run := ArtStrain.run(rig, moves)
		var table := ArtStrain.clip_table(run)
		var rounded := {}
		for clip: String in table:
			var figures: Dictionary = table[clip]
			rounded[clip] = {high = snappedf(figures.high, 0.0001), low = snappedf(figures.low, 0.0001),
					max = snappedf(figures.max, 0.0001), min = snappedf(figures.min, 0.0001), bad = figures.bad}
		out[row.name] = rounded
		print("STRAIN-RATCHET %s: %d samples, %d clips; in_bar %d, worst p99.9 %.4f, worst p0.1 %.4f, longest stretch x%.4f, deepest compression x%.5f, worst flex share %.4f%%, %d problem lines" % [
				row.name, run.samples, table.size(), run.in_bar, run.worst_high, run.worst_low, run.worst_max, run.worst_min,
				ArtStrain.worst_flex_share(run) * 100.0, run.problems.size()])
		rig.free()
	var file := FileAccess.open(ArtStrain.RATCHET_TABLE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("cannot write %s" % ArtStrain.RATCHET_TABLE_PATH)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(out, "\t", true) + "\n")
	file.close()
	print("wrote the per-clip strain figures to %s" % ArtStrain.RATCHET_TABLE_PATH)
	get_tree().quit(0)
