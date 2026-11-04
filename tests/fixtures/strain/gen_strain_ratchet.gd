extends Node
## Writes tests/fixtures/strain/<id>.json for every roster character (M6, tests/art_roster.gd: {id, whole, clips}) and
## strain_ratchet.json for the hero: the per-clip figures of the shipped art's A19 strain run (tests/art_strain.gd), what the final
## art does today, which test_skinned_art and test_m4_done_when hold every clip to, plus CLIP_MARGIN. Each art's clips are `{"<clip>": {high, low, max, min, bad}}` (the worst p99.9, the lowest p0.1, the longest stretch and the deepest
## compression over the clip's five phases; `bad` is a peak flex's squashed or turned-over triangles), rounded to 4 places.
##
## A scene (the rigs read autoloads): `godot --headless res://tests/fixtures/strain/gen_strain_ratchet.tscn --quit-after 5 [-- <id>...]`
## (about 15 s). It also prints the whole-run figures SHIPPED's rows are set from (today's figure plus a margin). Run it when a
## ratchet is meant to move, after a GLB rebuild that improved the strain, and commit the file with the new SHIPPED figures: a
## ratchet only ever moves down.

const ArtStrain := preload("res://tests/art_strain.gd")
const Roster := preload("res://tests/art_roster.gd")
## A new character's whole-run figures are today's plus this margin (as M4's were set: about 5%); an existing file's are kept, a
## ratchet only moves down (edit them by hand when a rebuild improved the strain).
const WHOLE_MARGIN := 0.05


## Every art this generator covers, as ArtStrain rows: the roster's characters (their strain files may not exist yet), then the hero.
func _rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in Roster.ids():
		var r := Roster.row(id)
		out.append({name = id, path = Roster.glb_of(r), art = String(r.art), player = false, budget = int(r.budget), height = float(r.height_m), moves = Roster.moves_of(r)})
	for row: Dictionary in ArtStrain.SHIPPED:
		if row.player:
			var hero: Dictionary = row.duplicate()
			hero.height = 1.8
			hero.moves = [] as Array[MoveData]
			out.append(hero)
	return out


func _ready() -> void:
	var player_table := {}
	# User arguments (after `--`) name the ids to write; none writes them all. Naming the new character alone leaves the others'
	# files byte for byte as they are.
	var only := OS.get_cmdline_user_args()
	for row: Dictionary in _rows():
		if not only.is_empty() and not only.has(row.name):
			continue
		var art := load(row.art) as CharacterArt
		if row.player:
			art = PlayerCharacter.worn_art(art)
		var rig := HumanoidRig.new()
		if row.player:
			var dresser := PlayerCharacter.new()
			dresser._configure_rig(rig)
			dresser.free()
		rig.height = row.height
		rig.build_hurtboxes = false
		rig.art = art
		add_child(rig)
		rig.build()
		rig.play(&"idle", 0.0)
		rig.advance(0.0)
		var run := ArtStrain.run(rig, row.moves)
		var table := ArtStrain.clip_table(run)
		var rounded := {}
		for clip: String in table:
			var figures: Dictionary = table[clip]
			rounded[clip] = {high = snappedf(figures.high, 0.0001), low = snappedf(figures.low, 0.0001),
					max = snappedf(figures.max, 0.0001), min = snappedf(figures.min, 0.0001), bad = figures.bad}
		print("STRAIN-RATCHET %s: %d samples, %d clips; in_bar %d, worst p99.9 %.4f, worst p0.1 %.4f, longest stretch x%.4f, deepest compression x%.5f, worst flex share %.4f%%, %d problem lines" % [
				row.name, run.samples, table.size(), run.in_bar, run.worst_high, run.worst_low, run.worst_max, run.worst_min,
				ArtStrain.worst_flex_share(run) * 100.0, run.problems.size()])
		rig.free()
		if row.player:
			player_table[row.name] = rounded
			continue
		var file := Roster.strain_file(row.name)
		var whole: Dictionary = file.get("whole", {})
		if whole.is_empty():
			whole = {
				in_bar_min = run.in_bar,
				high_max = snappedf(run.worst_high * (1.0 + WHOLE_MARGIN), 0.01),
				low_min = snappedf(run.worst_low * (1.0 - WHOLE_MARGIN), 0.001),
				max_max = snappedf(run.worst_max * (1.0 + WHOLE_MARGIN), 0.01),
				min_min = snappedf(run.worst_min * (1.0 - WHOLE_MARGIN), 0.0001),
				flex_share_max = snappedf(ArtStrain.worst_flex_share(run) * (1.0 + WHOLE_MARGIN) + 0.0005, 0.0001),
			}
			print("STRAIN-RATCHET %s: new whole-run figures %s" % [row.name, whole])
		if not _write("%s/%s.json" % [Roster.STRAIN_DIR, row.name], {id = row.name, whole = whole, clips = rounded}):
			return
	if not player_table.is_empty() and not _write(ArtStrain.RATCHET_TABLE_PATH, player_table):
		return
	print("wrote the per-clip strain figures")
	get_tree().quit(0)


func _write(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("cannot write %s" % path)
		get_tree().quit(1)
		return false
	file.store_string(JSON.stringify(data, "\t", true) + "\n")
	file.close()
	return true
