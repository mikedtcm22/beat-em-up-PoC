extends GutTest
## Milestone 4's done-when, the measured rows of M4-plan Part B section B1 (A1-A14), one test each, on the SHIPPED art: the Punk
## (game/actors/art/punk_art.tres, assets/export/characters/punk/punk.glb) and the hero (player_art.tres, player.glb), worn the
## way the game wears them. The [W] rows (L1-L3, L5; L4 is the lead's perf run) are windowed: tests/bot/look_probe.gd prints them
## (tests/bot/acts/look_final_acts.gd, one run, look.json), so they are listed here and never asserted.
##
## M6 (CHAIN, plan D26): the characters are the ROSTER (tests/fixtures/art/roster/<id>.json, tests/art_roster.gd): every row
## below loops over the roster's characters at each one's height, with its own moves and its own ratchets; a new character adds
## its file and changes nothing here. The Punk's M4 numbers moved into punk.json unchanged. The hero is not in the roster: his row
## and the *_PLAYER constants below stay verbatim (ARM changes them).
##
## This file is the one place that shows every row's state. A row whose bar the shipped art meets is asserted at the bar ("PASS").
## A row it does not meet yet (A7's strain, A9's 3% of the cells, A11's anchor on the torso and legs, A6 and the rest of what the
## art fixers are working on) is asserted at a RATCHET, what the art does today with a margin so that a fix only makes it better,
## and the plan's bar is printed as a GATE line. Nothing here is frozen to a number from one file of art beyond that margin: every
## figure is read from whatever is on disk. After the last test the table of all rows is printed ("DONE-WHEN ...").
##
## Each test names the test that already holds its row elsewhere and mirrors it (a test script cannot call another's tests, and the
## art fixers are changing the files that hold the helpers); the full A19 strain run is shared with test_skinned_art through
## tests/art_strain.gd (kept per art, so it is made once). Three more tests at the end are P3-int's own: the player's first-person
## hull from ToonMaterials.outline(true), the final probe's source acts, and the arithmetic of the windowed rows.
##
##   A1 test_art_contract, test_skinned_art      A8 test_skinned_art, test_art_punk
##   A2 test_art_contract                         A9 test_art_punk, test_art_player, test_skinned_art
##   A3 test_art_contract, test_look_post         A10 test_art_punk, test_damage_look
##   A4 test_skinned_art, test_motion_m4          A11 test_art_punk, test_hit_flash
##   A5 test_art_contract                         A12 tools/run_tests.sh (the whole suite)
##   A6 test_art_punk, test_skinned_art           A13 test_art_contract, the ledger
##   A7 test_skinned_art, test_art_punk           A14 test_slice_crowd, tools/check_m3_log.py

const SkinnedView := preload("res://tests/skinned_view.gd")
const FPView := preload("res://tests/fp_view.gd")
const ArtStrain := preload("res://tests/art_strain.gd")
const MotionProbe := preload("res://tests/fixtures/motion/motion_probe.gd")
const Probe := preload("res://tests/bot/readability_probe.gd")
const Pilot := preload("res://tests/bot/autopilot.gd")
const CrowdBot := preload("res://tests/bot/crowd_bot.gd")
const LookProbe := preload("res://tests/bot/look_probe.gd")
const LookTuneActs := preload("res://tests/bot/acts/look_tune_acts.gd")
const LookActs := preload("res://tests/bot/acts/look_acts.gd")
const LookFinalActs := preload("res://tests/bot/acts/look_final_acts.gd")
const ArtPlayerTest := preload("res://tests/test_art_player.gd")
const Roster := preload("res://tests/art_roster.gd")

const PLAYER_ART := "res://game/actors/art/player_art.tres"
const CROWD_ROOM := "res://game/level/crowd_room.tscn"
const TRAINING_ROOM := "res://game/level/test_room.tscn"
const JOINTS_PATH := "res://tools/pipeline/joints.json"
const ATLAS_PATH := "res://assets/export/palette/palette_atlas.png"
const ASSETS_MD := "res://ASSETS.md"
const LEDGER_PATH := "res://assets/source/tripo_ledger.jsonl"
const GITATTRIBUTES := "res://.gitattributes"
const FRAME := 1.0 / 60.0

# --- Part B's bars (the plan's numbers; what the art does today is in the RATCHET constants) ---
## A1/A4: the joints on the chained table (SkinnedArt.JOINT_TOLERANCE_M checks it), the soles on the floor, a planted frame.
const SOLE_TOLERANCE_M := 0.005
const PLANTED_FLOOR_M := -0.015
const SLIDE_M := 0.02
## A2: the budgets (SPEC §10): the roster files carry each character's (15000 for an enemy, the boss 30000); the hero's is here.
const TRIANGLES_PLAYER := 30000
## A3: 4-6 flat colours, the palette atlas's geometry, and the red band (hue 345-15 degrees, saturation above 0.5).
const SWATCH_MIN := 4
const SWATCH_MAX := 6
const SWATCH_COLUMNS := 32
const SWATCH_ROWS := 2
const SWATCH_PX := 8
const RED_SATURATION := 0.5
## A5: the fist box (tools/pipeline/joints.json) within 15 mm at its centre and 20% on its size.
const FIST_CENTROID_M := 0.015
const FIST_EXTENT := 0.2
## A6: 95% of the torso and leg vertices within the hurtbox radius + 6 cm, the head's within + 5 cm.
const FIT_SHARE := 0.95
## A8: the skeleton against the ragdoll's visual pose, 1 mm.
const RAGDOLL_GAP_M := 0.001
## A9: at most 3% of the cells differ, the lens share within 4 points, the player's art never 2 cm nearer, the block guard's
## forearms and hands 0.3 m from the lens.
const FRAMING_DIFFER := 0.03
const FRAMING_SHARE := 0.04
const FRAMING_NEAREST_M := 0.02
const GUARD_CLEAR_M := 0.3
## The slice gate's visible-stretch rule (contingency 4, M4-slice-gate.md): no edge the lens sees grows more than 2 cm over its length
## in the skinned rest at the 1 m acts' poses.
const VISIBLE_STRETCH_M := 0.02
## A11: the flash anchor within 2 cm of the skinned surface.
const ANCHOR_M := 0.02
## A12: the suite's count only rises (M3 closed at 1198).
const SUITE_COUNT_MIN := 1198
## A13: Tripo's spend, the stop and the cap (M4-plan A10), and the balance floor.
const TRIPO_STOP := 750.0
const TRIPO_CAP := 800.0
const TRIPO_FLOOR := 700.0

# --- RATCHETS: what the shipped art does today, with a margin (a fix only makes these better) ---
## Each is today's figure on the final art plus a small margin (M4-calls/fix-final-done-when-ratchets-and-suite-time.md has every
## old -> new): 5% on a length or a slide, half a point on a share of cells or of vertices, half a centimetre on an anchor. The plan's
## bar is still printed beside each as a GATE line, where the art misses it. P3-int's first set (C4) was made on the pre-fix art and
## sat 20% to 100% above what the art does.
## A4: the player's walks slide his planted soles by metres (M3's 0.6 s cycle at his speed, M4-calls/F-motion.md C7: a walk cannot
## plant a 0.9 m leg at 6 m/s); the most a planted step may slide on his art (today 2.29 m, the side step; the enemies' are held at 2 cm).
const SLIDE_RATCHET_PLAYER_M := 2.4
## A6: the hero's vertices inside their hurtbox + slack, by region (today torso 100%, legs 89.4%, head 99.0%), and the axis points
## outside the art (today none).
const FIT_RATCHET_PLAYER := {"torso": 0.985, "legs": 0.88, "head": 0.975}
const AXIS_OUTSIDE_RATCHET_PLAYER := 0
## A9, A7's visible stretch and A11's anchor, for the Punk: M4's ratchets (cells 0.07; the jab's and the cross's +8 degree lens gaps
## 0.056 and 0.054 with the twin STRIKE_ART_SHARE_MIN 0.27, F-cuff and F-fist-turn; stretch 0.09; anchors head 2, torso 6.5, leg 3.2 cm)
## moved unchanged into tests/fixtures/art/roster/punk.json, where each has its reason.
## A9: the hero over the 15 first-person poses is held to test_art_player's own HERO_* constants (HERO_DIFFER_MAX, HERO_SHARE_MAX,
## HERO_NEAREST_MAX_M: read, not copied, so this row cannot be looser than the test it mirrors): cells that differ (today 8.4%, the
## block), the lens share's gap (8.4 points, the block), the nearest the art stands to the lens against its proxies (8.1 cm, the front kick).
## A11, the hero: the same (today head 2.8 cm, torso 4.6 cm, leg 4.7 cm).
const ANCHOR_RATCHET_PLAYER_M := {"head": 0.033, "torso": 0.051, "leg": 0.052}

## The first-person framing's own geometry: the player's eye height in the crowd room, and the 1 m acts' two views.
const EYE_Y := 1.656
const PUNK_VIEW_PITCHES: Array[float] = [8.0, -6.0]

## Row id -> the notes the row's test left: {ok, text}. `ok` is whether the plan's bar was met. after_all() prints them.
var _notes: Dictionary = {}


func before_each() -> void:
	TimeController.clear()
	TimeController.debug_scale = 1.0
	Tuning.apply(TuningData.new())
	Tuning.data.dummy_health = 500.0
	SkinnedArt.clear_cache()
	SkinnedView.clear_cache()


func after_each() -> void:
	TimeController.clear()
	TimeController.debug_scale = 1.0
	Tuning.apply(TuningData.new())


func after_all() -> void:
	# A headless run is far ahead of the audio clock: give the mixer a moment to drop the sounds the fights made.
	OS.delay_msec(250)
	_print_table()


# --- Harness ------------------------------------------------------------------------------------


## The shipped art under test: `{name, art, player, budget, glb, height, meshes, moves, ratchets}`. The roster's characters (each
## at its height, with its own moves and ratchets: tests/art_roster.gd), then the hero, whose row and ratchets are the constants
## above. The hero's CharacterArt names his GLB in metadata and is made ready to wear by PlayerCharacter.worn_art(), as the game does it.
func _arts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in Roster.ids():
		var r := Roster.row(id)
		assert_eq(Roster.problems(id), PackedStringArray(), "%s: the roster file is well formed" % id)
		out.append({name = id, art = load(r.art) as CharacterArt, player = false, budget = int(r.budget), glb = Roster.glb_of(r),
				height = float(r.height_m), meshes = r.meshes, moves = r.moves, ratchets = r.ratchets})
	var hero := PlayerCharacter.worn_art(load(PLAYER_ART) as CharacterArt)
	assert_not_null(hero, "the hero's art is worn: assets/export/characters/player/player.glb is shipped")
	if hero != null:
		out.append({name = "player", art = hero, player = true, budget = TRIANGLES_PLAYER,
				glb = "res://assets/export/characters/player/player.glb", height = 1.8, meshes = ["Body", "Body__fp_hidden", "Body__fp_torso"],
				moves = [], ratchets = {a5_extent = FIST_EXTENT}})
	return out


## The row named `name` of _arts().
func _row(name: String) -> Dictionary:
	for row: Dictionary in _arts():
		if row.name == name:
			return row
	return {}


## The roster characters' rows (every row but the hero's).
func _enemy_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in _arts():
		if not row.player:
			out.append(row)
	return out


## A bare rig wearing `row`'s art at the character's height, dressed as the player for the hero, idle.
func _rig(row: Dictionary, hurtboxes: bool = false) -> HumanoidRig:
	var rig := HumanoidRig.new()
	if row.player:
		var dresser := PlayerCharacter.new()
		dresser._configure_rig(rig)
		dresser.free()
	rig.height = row.height
	rig.build_hurtboxes = hurtboxes
	rig.art = row.art
	add_child_autofree(rig)
	rig.build()
	rig.play(&"idle", 0.0)
	rig.advance(0.0)
	return rig


func _pose(rig: HumanoidRig, animation: StringName, at: float) -> void:
	rig.play(animation, 0.0)
	rig.advance(0.0)
	rig.advance(at)


func _move_file(id: String) -> MoveData:
	return load("res://game/combat/moves/%s.tres" % id) as MoveData


func _move(id: StringName, startup: int, active: int, recovery: int) -> MoveData:
	var move := MoveData.new()
	move.id = id
	move.startup = startup
	move.active = active
	move.recovery = recovery
	return move


## Every art mesh's skinned vertices at the table's rest, rig space.
func _rest_vertices(rig: HumanoidRig) -> PackedVector3Array:
	var out := PackedVector3Array()
	var rest := SkinnedView.rest_pose(rig)
	for mi: MeshInstance3D in rig.art_meshes():
		out.append_array(SkinnedView.skin_vertices(mi, rig, rest))
	return out


## Record a note for `row`: whether the plan's bar was met, and what was measured. Printed at once and again in the table.
func _note(row: String, ok: bool, text: String) -> void:
	var list: Array = _notes.get(row, [])
	list.append({ok = ok, text = text})
	_notes[row] = list
	print("DONE-WHEN %s %s %s" % [row, "ok  " if ok else "GATE", text])


func _print_table() -> void:
	print("DONE-WHEN ===== M4-plan Part B section B1: the measured rows on the shipped art =====")
	for n: int in range(1, 15):
		var row := "A%d" % n
		var list: Array = _notes.get(row, [])
		var gate := 0
		for note: Dictionary in list:
			if not note.ok:
				gate += 1
		var state := "NOT RUN" if list.is_empty() else ("PASS" if gate == 0 else "GATE (ratchet held)")
		print("DONE-WHEN %-3s %s" % [row, state])
		for note: Dictionary in list:
			print("DONE-WHEN     %s %s" % ["ok  " if note.ok else "GATE", note.text])
	print("DONE-WHEN L1-L3, L5 [W]  printed by tests/bot/look_probe.gd (act 'Look: final probe', look.json); L4 [W]: tools/perf_compare.sh, the lead's run")


func _in_red_band(color: Color) -> bool:
	var hue := color.h * 360.0
	return (hue >= 345.0 or hue <= 15.0) and color.s > RED_SATURATION


func _atlas() -> Image:
	var texture := load(ATLAS_PATH) as Texture2D
	if texture == null:
		return null
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	return image


func _swatch_color(atlas: Image, slot: int) -> Color:
	var c := atlas.get_pixel((slot % SWATCH_COLUMNS) * SWATCH_PX + SWATCH_PX / 2, (slot / SWATCH_COLUMNS) * SWATCH_PX + SWATCH_PX / 2)
	return Color(c.r, c.g, c.b, 1.0)


# --- A1: the GLB contract ------------------------------------------------------------------------


func test_a1_the_glb_contract_holds_on_the_shipped_art() -> void:
	# Source: test_art_contract (the GLB's own arrays and skeleton) and SkinnedArt.check(), which reads the same contract the game
	# reads: 23 named binds, no neutral_bone or unknown name, every exported joint within 1 mm of the table chained through the
	# swing, at most 4 normalized influences, every vertex weighted, none on Root. Faces -Z with the soles at y 0 is read off the
	# skinned art at the table's rest.
	for row: Dictionary in _arts():
		var art: CharacterArt = row.art
		assert_eq(SkinnedArt.check(art), PackedStringArray(), "%s: SkinnedArt.check() is empty (binds, chained joints, weights)" % row.name)
		var entry := SkinnedArt.entry_of(art)
		assert_gt(entry.meshes.size(), 0, "%s: the GLB has meshes" % row.name)
		for part: SkinnedArt.ArtMesh in entry.meshes:
			assert_eq(part.bind_names.size(), 23, "%s %s: 23 named binds" % [row.name, part.node_name])
			assert_false(part.bind_names.has(SkinnedArt.NEUTRAL_BONE), "%s %s: no neutral_bone" % [row.name, part.node_name])
			for bone: StringName in PlaceholderBody.BONE_NAMES:
				assert_true(part.bind_names.has(bone), "%s %s: a bind named %s" % [row.name, part.node_name, bone])
			for bind: StringName in part.bind_names:
				assert_true(PlaceholderBody.BONE_NAMES.has(bind), "%s %s: %s is a name of the table" % [row.name, part.node_name, bind])
		var names := PackedStringArray()
		for part: SkinnedArt.ArtMesh in entry.meshes:
			names.append(String(part.node_name))
		names.sort()
		# The hero is three meshes since F-player-fix (test_art_contract: the belly and belt are their own
		# Body__fp_torso, so fp_knockdown_hide_torso hides only them).
		var want := PackedStringArray(row.meshes)
		want.sort()
		assert_eq(names, want, "%s: the meshes the pipeline contract names" % row.name)
		var rig := _rig(row)
		assert_true(rig.has_art(), "%s: the rig wears it (check() passed)" % row.name)
		var verts := _rest_vertices(rig)
		var toes := 0.0
		var heels := 0.0
		for side: float in [-1.0, 1.0]:
			var lowest := INF
			for v: Vector3 in verts:
				if v.x * side > 0.02 and v.y < 0.12:
					lowest = minf(lowest, v.y)
			var z_min := INF
			var z_max := -INF
			for v: Vector3 in verts:
				if v.x * side > 0.02 and v.y < lowest + 0.012:
					z_min = minf(z_min, v.z)
					z_max = maxf(z_max, v.z)
			toes = minf(toes, z_min) if side < 0.0 else z_min
			heels = z_max
			assert_lt(z_min, -0.2, "%s: the %s toe reaches forward to -Z (z %.3f)" % [row.name, "left" if side < 0.0 else "right", z_min])
			assert_gt(z_max, 0.04, "%s: the %s heel sits behind the ankle at +Z (z %.3f)" % [row.name, "left" if side < 0.0 else "right", z_max])
		_note("A1", true, "%s: check() clean, %d meshes x 23 binds, faces -Z (toe z %.3f, heel z %.3f)" % [row.name, entry.meshes.size(), toes, heels])


# --- A2: triangles ---------------------------------------------------------------------------------


func test_a2_the_triangle_budgets_hold() -> void:
	# Source: test_art_contract::test_triangle_budgets.
	for row: Dictionary in _arts():
		var entry := SkinnedArt.entry_of(row.art)
		var total := 0
		for part: SkinnedArt.ArtMesh in entry.meshes:
			total += part.triangles
		assert_eq((row.art as CharacterArt).triangle_budget, row.budget, "%s: the art resource carries the budget of SPEC §10" % row.name)
		assert_lte(total, row.budget, "%s: %d triangles against its budget %d" % [row.name, total, row.budget])
		assert_gt(total, 500, "%s: not an empty mesh" % row.name)
		_note("A2", true, "%s: %d of %d triangles" % [row.name, total, row.budget])


# --- A3: colours -----------------------------------------------------------------------------------


func test_a3_each_character_has_four_to_six_flat_colours_none_red_and_no_street_colour_is_red() -> void:
	# Source: test_art_contract::test_palette_uvs_sit_on_swatch_centres_few_and_never_red (the colours of the GLB's UV1 against the
	# shared atlas) and test_look_post::test_no_environment_or_prop_color_is_red_and_the_car_is_muted.
	var atlas := _atlas()
	assert_not_null(atlas, "the palette atlas loads")
	if atlas == null:
		return
	for row: Dictionary in _arts():
		var slots: Dictionary = {}
		for part: SkinnedArt.ArtMesh in SkinnedArt.entry_of(row.art).meshes:
			var uvs: PackedVector2Array = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
			for uv: Vector2 in uvs:
				slots[int(roundf(uv.y * SWATCH_ROWS - 0.5)) * SWATCH_COLUMNS + int(roundf(uv.x * SWATCH_COLUMNS - 0.5))] = true
		var colours: Dictionary = {}
		for slot: int in slots:
			var c := _swatch_color(atlas, slot)
			colours[c.to_html(false)] = true
			assert_false(_in_red_band(c), "%s: slot %d (%s) is not in the red band" % [row.name, slot, c.to_html(false)])
		assert_between(colours.size(), SWATCH_MIN, SWATCH_MAX, "%s: %d flat colours" % [row.name, colours.size()])
		_note("A3", true, "%s: %d flat colours on %d swatches, none in the red band" % [row.name, colours.size(), slots.size()])
	var seen := 0
	for path: String in [CROWD_ROOM, TRAINING_ROOM]:
		var room := (load(path) as PackedScene).instantiate()
		room.set(&"with_presentation", false)
		add_child_autofree(room)
		await get_tree().physics_frame
		await get_tree().physics_frame
		for node: Node in room.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			var material: Material = mesh.material_override
			if material == null and mesh.mesh is PrimitiveMesh:
				material = (mesh.mesh as PrimitiveMesh).material
			var color: Variant = null
			if material is StandardMaterial3D:
				color = (material as StandardMaterial3D).albedo_color
			elif material is ShaderMaterial:
				color = (material as ShaderMaterial).get_shader_parameter(&"albedo")
			if color is Color:
				seen += 1
				assert_false(_in_red_band(color), "%s %s is not red" % [mesh.get_path(), color])
	assert_gt(seen, 20, "the walls, crates, the car and the street were read (%d)" % seen)
	_note("A3", true, "the crowd room and the training room: %d surfaces, none in the red band (the car is muted)" % seen)


# --- A4: feet --------------------------------------------------------------------------------------


func test_a4_the_soles_stand_on_the_floor_and_the_walks_plant_them() -> void:
	# Source: test_skinned_art (the soles at the rest), test_motion_m4::test_the_punks_soles_stay_planted_through_every_walk (the
	# Punk's four walks, at most 2 cm a planted step, none under -15 mm) and the idle: here for the hero's art as well. The hero's
	# walks keep M3's cadence (F-motion C7), so their slide is held at a ratchet and printed; his soles are never under -15 mm.
	var walks: Dictionary[StringName, Vector3] = {
		&"walk_forward": Vector3(0.0, 0.0, -1.0), &"walk_back": Vector3(0.0, 0.0, 1.0),
		&"walk_right": Vector3(1.0, 0.0, 0.0), &"walk_left": Vector3(-1.0, 0.0, 0.0),
	}
	for row: Dictionary in _arts():
		var rig := _rig(row)
		var lowest := INF
		for v: Vector3 in _rest_vertices(rig):
			lowest = minf(lowest, v.y)
		assert_between(lowest, -SOLE_TOLERANCE_M, SOLE_TOLERANCE_M, "%s: the lowest sole vertex at the rest is on the floor (%.4f m)" % [row.name, lowest])
		var stance := PlaceholderPoses.STANCE_RELAXED if row.player else PlaceholderPoses.STANCE_BOXER
		var mi := rig.art_meshes()[0]
		var sole := MotionProbe.sole_vertices(mi, rig)
		assert_gt(sole.size(), 40, "%s: the art has a sole (%d vertices)" % [row.name, sole.size()])
		var worst_slide := 0.0
		var worst_low := INF
		for id: StringName in walks:
			var clip := PlaceholderAnims.build_named(id, rig.rig_scale(), stance, PlaceholderAnims.Life.new())
			# The enemies' walks at the probe's 120 Hz, as test_motion_m4; the hero's, whose slide is metres, at 60 Hz.
			var result := MotionProbe.walk_slide(mi, rig, clip, sole, walks[id], Tuning.data.move_speed, FRAME if row.player else FRAME / 2.0)
			worst_slide = maxf(worst_slide, result.slide)
			worst_low = minf(worst_low, result.lowest)
			assert_gt(result.runs, 10, "%s %s: planted steps to measure" % [row.name, id])
			var slide_bar: float = SLIDE_RATCHET_PLAYER_M if row.player else float(row.ratchets.slide_m)
			assert_lt(result.slide, slide_bar, "%s %s: a planted step slides at most %.2f cm (%.2f cm)" % [row.name, id, slide_bar * 100.0, result.slide * 100.0])
			assert_gt(result.lowest, PLANTED_FLOOR_M, "%s %s: no sole vertex under -15 mm (%.1f mm)" % [row.name, id, result.lowest * 1000.0])
		var idle := PlaceholderAnims.build_named(&"idle", rig.rig_scale(), stance, PlaceholderAnims.Life.new())
		var idle_low := INF
		for step: int in 13:
			var posed := SkinnedView.skin_vertices(mi, rig, MotionProbe.clip_globals(rig, idle, idle.length * float(step) / 12.0))
			for v: int in sole:
				idle_low = minf(idle_low, posed[v].y)
		assert_gt(idle_low, PLANTED_FLOOR_M, "%s: the idle's soles are never under -15 mm (%.1f mm)" % [row.name, idle_low * 1000.0])
		_note("A4", worst_slide < SLIDE_M, "%s: rest sole %+.1f mm; four walks slide at most %.2f cm (bar 2 cm%s), lowest %.1f mm; idle lowest %.1f mm" % [
				row.name, lowest * 1000.0, worst_slide * 100.0, "; the hero's keep M3's 0.6 s cycle, F-motion C7, ratchet %.0f cm, margin %.1f cm" % [
				SLIDE_RATCHET_PLAYER_M * 100.0, (SLIDE_RATCHET_PLAYER_M - worst_slide) * 100.0] if row.player else "",
				worst_low * 1000.0, idle_low * 1000.0])


# --- A5: fists ------------------------------------------------------------------------------------


func test_a5_the_fists_fill_the_fist_box() -> void:
	# Source: test_art_contract::test_the_fists_fill_the_fist_box (the GLB's own arrays, un-swung to the table). Here the art is
	# skinned at the table's rest, which is the same frame: the vertices held 0.9 or more by a Hand bone, an area-weighted
	# centroid within 15 mm of the box's centre and extents within 20% of 0.1 x 0.118 x 0.116 m.
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(JOINTS_PATH))
	for row: Dictionary in _arts():
		var rig := _rig(row)
		var rest := SkinnedView.rest_pose(rig)
		var mi := rig.art_meshes()[0]
		var data := SkinnedView._mesh_data(mi.mesh as ArrayMesh)
		var posed := SkinnedView.skin_vertices(mi, rig, rest)
		var summary := PackedStringArray()
		for box: Dictionary in table.fist_boxes:
			var hand := StringName(box.bone)
			var share := PackedFloat32Array()
			share.resize(posed.size())
			for e: int in data.entry_vertex.size():
				if StringName(mi.skin.get_bind_name(data.entry_bind[e])) == hand:
					share[data.entry_vertex[e]] += data.entry_weight[e]
			var lo := Vector3.INF
			var hi := -Vector3.INF
			var area := 0.0
			var centroid := Vector3.ZERO
			for t: int in data.indices.size() / 3:
				var i0 := data.indices[t * 3]
				var i1 := data.indices[t * 3 + 1]
				var i2 := data.indices[t * 3 + 2]
				if share[i0] < 0.9 or share[i1] < 0.9 or share[i2] < 0.9:
					continue
				var a := (posed[i1] - posed[i0]).cross(posed[i2] - posed[i0]).length() * 0.5
				area += a
				centroid += (posed[i0] + posed[i1] + posed[i2]) / 3.0 * a
				for p: Vector3 in [posed[i0], posed[i1], posed[i2]]:
					lo = lo.min(p)
					hi = hi.max(p)
			assert_gt(area, 0.001, "%s: the %s fist is found" % [row.name, box.side])
			if area <= 0.001:
				continue
			centroid /= area
			var c: Array = box.center_rest_global
			var gap := centroid.distance_to(Vector3(c[0], c[1], c[2]) * rig.rig_scale())  # the box is the 1.8 m table's; the rig is scaled (M6 HEAVIES)
			assert_lt(gap / rig.rig_scale(), FIST_CENTROID_M, "%s: the %s fist's centroid is %.1f mm from the fist box (%.1f mm in the 1.8 m table's frame, the bar)" % [row.name, box.side, gap * 1000.0, gap / rig.rig_scale() * 1000.0])
			var size: Array = box.size
			var ext := hi - lo
			var ratios := PackedStringArray()
			for axis: int in 3:
				var ratio := ext[axis] / (float(size[axis]) * rig.rig_scale())
				ratios.append("%.2f" % ratio)
				assert_between(ratio, 1.0 - float(row.ratchets.a5_extent), 1.0 + float(row.ratchets.a5_extent), "%s: the %s fist's extent on axis %d is x%.2f of the box" % [row.name, box.side, axis, ratio])
			summary.append("%s %.1f mm, extents x%s" % [box.side, gap * 1000.0, "/".join(ratios)])
		_note("A5", true, "%s: fist centroid off the box by %s" % [row.name, "; ".join(summary)])


# --- A6: hurtbox fit at idle ---------------------------------------------------------------------


## Row A6's shares with every vertex counted by its DOMINANT bind (as test_art_punk does: SkinnedView.hurtbox_fit() counts only the
## vertices a single bind holds alone): `{torso, legs, head}` the share within the covering hurtbox's radius plus the slack of its
## axis (6 cm, the head's 5 cm), the vertex counts, and `axis_outside` the axis points the art does not enclose.
func _fit(rig: HumanoidRig) -> Dictionary:
	var regions := {
		&"Hips": &"torso", &"Spine": &"torso", &"Chest": &"torso", &"UpperChest": &"torso",
		&"LeftUpperLeg": &"legs", &"LeftLowerLeg": &"legs", &"RightUpperLeg": &"legs", &"RightLowerLeg": &"legs",
		&"Head": &"head",
	}
	var share := {torso = [0, 0], legs = [0, 0], head = [0, 0]}
	var world := rig.global_transform
	for mi: MeshInstance3D in rig.art_meshes():
		var data := SkinnedView._mesh_data(mi.mesh as ArrayMesh)
		var posed := mi.global_transform * SkinnedView.skin_vertices(mi, rig)
		for spec: PlaceholderBody.HurtSpec in PlaceholderBody.hurt_specs():
			var from := world * (rig.animation_pose(rig.skeleton.find_bone(spec.bone_a)) * (spec.offset_a * rig.rig_scale()))
			var to := from
			if spec.is_capsule():
				to = world * (rig.animation_pose(rig.skeleton.find_bone(spec.bone_b)) * (spec.offset_b * rig.rig_scale()))
			for v: int in posed.size():
				var best := 0
				for j: int in SkinnedArt.INFLUENCES:
					if data.weights[v * SkinnedArt.INFLUENCES + j] > data.weights[v * SkinnedArt.INFLUENCES + best]:
						best = j
				var bone := StringName(mi.skin.get_bind_name(data.bones[v * SkinnedArt.INFLUENCES + best]))
				var region: StringName = regions.get(bone, &"")
				var covers := (region == &"torso" and spec.region == CombatTypes.Region.TORSO) \
						or (region == &"legs" and spec.region == CombatTypes.Region.LEGS \
								and String(bone).begins_with("Left") == String(spec.bone_a).begins_with("Left")) \
						or (region == &"head" and spec.region == CombatTypes.Region.HEAD)
				if not covers:
					continue
				var gap := posed[v].distance_to(Geometry3D.get_closest_point_to_segment(posed[v], from, to))
				var limit := spec.radius * rig.rig_scale() + (0.05 if region == &"head" else 0.06)
				share[region][1] += 1
				if gap <= limit:
					share[region][0] += 1
	return {
		torso = float(share.torso[0]) / maxi(share.torso[1], 1), legs = float(share.legs[0]) / maxi(share.legs[1], 1),
		head = float(share.head[0]) / maxi(share.head[1], 1),
		counts = {torso = share.torso[1], legs = share.legs[1], head = share.head[1]},
		axis_outside = SkinnedView.hurtbox_fit(rig).outside,
	}


## The shares row A6 holds `row`'s vertices to: the hero's constants, a roster file's `a6` ratchet, or the plan's 95%.
func _fit_ratchet(row: Dictionary) -> Dictionary:
	if row.player:
		return FIT_RATCHET_PLAYER
	if row.ratchets.a6 is Dictionary:
		var own: Dictionary = {torso = FIT_SHARE, legs = FIT_SHARE, head = FIT_SHARE}
		own.merge(row.ratchets.a6, true)
		return own
	return {torso = FIT_SHARE, legs = FIT_SHARE, head = FIT_SHARE}


func test_a6_the_hurtboxes_sit_inside_the_art_at_idle() -> void:
	# Source: test_art_punk::test_the_hurtbox_fit_of_every_glb_is_printed_and_the_passing_bars_hold (the Punk, asserted at the bar)
	# and test_skinned_art::test_the_hurtboxes_sit_inside_the_art_at_idle. The hero is held to a ratchet and printed.
	for row: Dictionary in _arts():
		var rig := _rig(row, true)
		_pose(rig, &"idle", 0.3)
		var fit := _fit(rig)
		var misses := PackedStringArray()
		var axis: Array = fit.axis_outside
		if not axis.is_empty():
			misses.append("%d axis points outside the art" % axis.size())
		for region: String in ["torso", "legs", "head"]:
			if float(fit[region]) < FIT_SHARE:
				misses.append("%s %.1f%% < 95%%" % [region, float(fit[region]) * 100.0])
		var held := ""
		if row.player:
			held = "; ratchets torso %.1f%%, legs %.1f%%, head %.1f%% (margins %.1f, %.1f, %.1f points), axis points %d" % [
					FIT_RATCHET_PLAYER.torso * 100.0, FIT_RATCHET_PLAYER.legs * 100.0, FIT_RATCHET_PLAYER.head * 100.0,
					(fit.torso - FIT_RATCHET_PLAYER.torso) * 100.0, (fit.legs - FIT_RATCHET_PLAYER.legs) * 100.0,
					(fit.head - FIT_RATCHET_PLAYER.head) * 100.0, AXIS_OUTSIDE_RATCHET_PLAYER]
		_note("A6", misses.is_empty(), "%s: torso %.1f%% of %d vertices, legs %.1f%% of %d, head %.1f%% of %d, %d axis points outside%s%s" % [
				row.name, fit.torso * 100.0, fit.counts.torso, fit.legs * 100.0, fit.counts.legs, fit.head * 100.0, fit.counts.head,
				axis.size(), ("  (plan's bar missed: %s)" % "; ".join(misses)) if not misses.is_empty() else "", held])
		assert_gt(fit.counts.torso, 100, "%s: the torso vertices were counted" % row.name)
		for region: String in ["torso", "legs", "head"]:
			var floor_share: float = float(_fit_ratchet(row)[region])
			assert_gte(float(fit[region]), floor_share, "%s: the %s vertices hug their hurtbox (%.1f%%, held at %.1f%%)" % [row.name, region, float(fit[region]) * 100.0, floor_share * 100.0])
		var axis_ratchet := AXIS_OUTSIDE_RATCHET_PLAYER
		if not row.player:
			axis_ratchet = int((row.ratchets.a6 as Dictionary).get("axis_outside", 0)) if row.ratchets.a6 is Dictionary else 0
		if not row.player and axis_ratchet == 0:
			assert_eq(axis, [], "%s: every hurtbox axis point is inside the art" % row.name)
		else:
			assert_lte(axis.size(), axis_ratchet, "%s: at most %d axis points outside the art (%s)" % [row.name, axis_ratchet, axis])


# --- A7: deformation ---------------------------------------------------------------------------------


## The strain ratchet row (ArtStrain.SHIPPED's shape) of `row`: the hero's from ArtStrain, a roster character's from its strain file.
func _shipped_row(row: Dictionary) -> Dictionary:
	for shipped: Dictionary in ArtStrain.SHIPPED:
		if shipped.name == row.name:
			return shipped
	var own := Roster.shipped_row(row.name)
	assert_false(own.is_empty(), "%s: tests/fixtures/strain/%s.json holds its whole-run figures (run gen_strain_ratchet.tscn)" % [row.name, row.name])
	return own


func test_a7_the_strain_of_every_animation_and_move_is_held_at_its_ratchet() -> void:
	# Source: test_skinned_art::test_the_strain_of_the_shipped_glbs_is_reported_for_the_gate (the same run, kept per art in
	# tests/art_strain.gd) and test_art_punk's A19 and flip tests. Every ANIM_IDS id and the Punk's moves at five phases, then the
	# peak flexes (guard, elbow 150, arm raise 140, knee -130, spine twist, lying), against the skinned rest. Neither GLB meets
	# the plan's p99.9 in [0.6, 1.6] (the shoulder at the guard and the arm raise is the weak joint): the ratchet is
	# ArtStrain.SHIPPED's, the bar is the GATE line.
	var started := Time.get_ticks_msec()
	for row: Dictionary in _arts():
		var shipped := _shipped_row(row)
		var run := ArtStrain.cached(shipped.path)
		if run.is_empty():
			var moves: Array[MoveData] = []
			if not row.player:
				moves = ArtStrain.roster_moves(row.name)
			run = ArtStrain.keep(shipped.path, ArtStrain.run(_rig(row), moves))
		var share := ArtStrain.worst_flex_share(run)
		var over := ArtStrain.flexes_over_bar(run)
		assert_eq(run.kinds.get("NaN", 0), 0, "%s: no NaN" % row.name)
		assert_eq(run.kinds.get("the floor", 0), 0, "%s: no vertex under the floor in a planted pose" % row.name)
		# The ratchet can fail (tests/art_strain.gd): the samples inside the bars, the worst p99.9 and p0.1, the extreme edges, the
		# peak flexes' share and every clip's own figures held to today's plus a margin. A count of problem lines is not held: it
		# saturates at two a sample, so no regression could raise it.
		var table := ArtStrain.load_table(row.name)
		assert_false(table.is_empty(), "%s: the per-clip strain figures are shipped (tests/fixtures/strain/<id>.json, the hero's strain_ratchet.json)" % row.name)
		var broken := ArtStrain.ratchet_problems(run, shipped, table)
		assert_eq(broken.size(), 0, "%s: every strain ratchet holds: %s" % [row.name, broken.slice(0, 6)])
		_note("A7", run.problems.is_empty() and over.is_empty(), "%s: %d samples, %d with every number inside the bars, worst p99.9 %.2f, %d problem lines %s; peak flexes over the %d-triangle bar: %s (worst %.2f%% of the triangles; the plan's bar is 0.5%%); %s" % [
				row.name, run.samples, run.in_bar, run.worst_high, run.problems.size(), run.kinds,
				run.bad_bar, ", ".join(over) if not over.is_empty() else "none", share * 100.0, ArtStrain.margin_text(run, shipped)])
	print("DONE-WHEN A7 strain run: %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))


## Which of `world` (vertices, world space) the camera `cam` draws: in front of the near plane, inside the view's half-angles and
## facing the lens. Occlusion is not tested here, so this is a superset of what the lens sees (test_art_punk's `_in_view`).
func _in_view(world: PackedVector3Array, normals: PackedVector3Array, cam: Transform3D) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(world.size())
	var tan_h := tan(deg_to_rad(FPView.HALF_H_DEG))
	var tan_v := tan_h * 9.0 / 16.0
	var forward := -cam.basis.z
	for v: int in world.size():
		var to := world[v] - cam.origin
		var depth := to.dot(forward)
		if depth <= FPView.NEAR:
			continue
		if absf(to.dot(cam.basis.x)) > tan_h * depth or absf(to.dot(cam.basis.y)) > tan_v * depth:
			continue
		if normals[v].dot(-to) <= 0.0:
			continue
		out[v] = 1
	return out


## True when `point` is the first surface of `soup` along the ray from `origin` (nothing nearer by more than 1.5 cm).
func _seen_from(soup: SkinnedView.Soup, origin: Vector3, point: Vector3) -> bool:
	var to := point - origin
	var dist := to.length()
	var hit := soup.triangles.intersect_ray(origin, to / dist)
	return hit.is_empty() or origin.distance_to(hit.position) >= dist - 0.015


func test_a7_no_edge_the_lens_sees_of_a_roster_character_grows_more_than_its_ratchet_at_the_one_metre_poses() -> void:
	# Source: test_art_punk::test_no_edge_in_view_grows_more_than_2_cm_in_the_one_metre_acts_poses (the slice gate's contingency 4,
	# the visible-stretch test). At the 1 m acts' poses (idle and the character's own moves at their first active frame) from the
	# face and the body views, every deforming edge the lens sees (both ends in the view, facing it, the first surface along their
	# ray) grows at most 2 cm over its length in the skinned rest. The Punk misses the 2 cm bar (the waist hem in the cross's
	# twist: weight smoothing, a torso height blend and the heat-map weights were tried, M4-calls/F-punk.md): held at a ratchet.
	for row: Dictionary in _enemy_rows():
		var rig := _rig(row)
		rig.global_position = Vector3(0.0, 0.0, -1.0)
		rig.rotation.y = PI
		var moves: Array[MoveData] = [null]
		for id: String in row.moves:
			moves.append(_move_file(id))
		var worst := 0.0
		var worst_label := ""
		var edges_seen := 0
		var stretch_bar := float(row.ratchets.stretch_m)
		for pitch: float in PUNK_VIEW_PITCHES:
			var cam := _view(pitch)
			for move: MoveData in moves:
				_pose(rig, &"idle", 0.3)
				if move != null:
					rig.play_move(move)
					for i: int in move.startup + 1:
						rig.advance(FRAME)
				for mi: MeshInstance3D in rig.art_meshes():
					var data := SkinnedView._mesh_data(mi.mesh as ArrayMesh)
					SkinnedView._prepare_strain(data)
					var rest := SkinnedView.skin_vertices(mi, rig, SkinnedView.rest_pose(rig))
					var posed := SkinnedView.skin_vertices(mi, rig)
					var world := mi.global_transform * posed
					var normals := SkinnedView.skin_normals(mi, rig)
					var world_normals := PackedVector3Array()
					world_normals.resize(normals.size())
					for v: int in normals.size():
						world_normals[v] = mi.global_transform.basis * normals[v]
					var in_frustum := _in_view(world, world_normals, cam)
					var soup := SkinnedView._soup(mi, rig, cam)
					for e: int in data.edge_a.size():
						var a := data.edge_a[e]
						var b := data.edge_b[e]
						if in_frustum[a] == 0 or in_frustum[b] == 0:
							continue
						edges_seen += 1
						var grow := posed[a].distance_to(posed[b]) - rest[a].distance_to(rest[b])
						if grow <= worst:
							continue
						if not (_seen_from(soup, cam.origin, world[a]) and _seen_from(soup, cam.origin, world[b])):
							continue
						worst = grow
						worst_label = "%s pitch %+.0f, bones %s/%s" % [move.id if move != null else &"idle", pitch,
								SkinnedView._dominant_bone(data, mi.skin, [a]), SkinnedView._dominant_bone(data, mi.skin, [b])]
		assert_gt(edges_seen, 1000, "the poses were measured (%d edges in view)" % edges_seen)
		assert_lte(worst, stretch_bar, "%s: no edge in view grows more than the ratchet's %.0f cm (%.1f cm, %s)" % [row.name, stretch_bar * 100.0, worst * 100.0, worst_label])
		_note("A7", worst <= VISIBLE_STRETCH_M, "%s visible stretch (slice gate contingency 4): %d edges in view over the 1 m poses, the longest growth %.1f cm (%s); bar %.0f cm, ratchet %.0f cm (margin %.1f cm)" % [
				row.name, edges_seen, worst * 100.0, worst_label, VISIBLE_STRETCH_M * 100.0, stretch_bar * 100.0, (stretch_bar - worst) * 100.0])


# --- A8: ragdoll ---------------------------------------------------------------------------------------


## A SkeletonModifier3D placed after the Ragdoll: it composes every bone's global pose from the local poses the skeleton holds and
## compares it, in rig space, with the ragdoll's visual pose (the pose the followers, the flash anchors and the held pipe show).
## A copy of test_skinned_art's PoseProbe.
class PoseProbe:
	extends SkeletonModifier3D
	var rig: HumanoidRig
	var worst_origin: float = 0.0
	var updates: int = 0
	## A probe that ran earlier in the same update (before the Ragdoll), and the largest origin gap between its poses and this
	## one's: what the Ragdoll modifier changed in between.
	var peer: PoseProbe
	var worst_vs_peer: float = 0.0
	var last_globals: Array[Transform3D] = []

	func _process_modification_with_delta(_delta: float) -> void:
		var skeleton := get_skeleton()
		var ragdoll := rig.get_ragdoll()
		if skeleton == null or ragdoll == null or not ragdoll.is_running():
			return
		var globals: Array[Transform3D] = []
		for i: int in skeleton.get_bone_count():
			var local := skeleton.get_bone_pose(i)
			var parent := skeleton.get_bone_parent(i)
			globals.append(local if parent < 0 else globals[parent] * local)
		for i: int in globals.size():
			worst_origin = maxf(worst_origin, globals[i].origin.distance_to(ragdoll.visual_pose(i).origin))
		if peer != null and peer.last_globals.size() == globals.size():
			for i: int in globals.size():
				worst_vs_peer = maxf(worst_vs_peer, globals[i].origin.distance_to(peer.last_globals[i].origin))
		last_globals = globals
		updates += 1


func _probe(rig: HumanoidRig, before_ragdoll: bool) -> PoseProbe:
	var probe := PoseProbe.new()
	probe.rig = rig
	probe.name = "ProbeBefore" if before_ragdoll else "ProbeAfter"
	rig.skeleton.add_child(probe)
	if before_ragdoll:
		rig.skeleton.move_child(probe, rig.get_ragdoll().get_index())
	return probe


func test_a8_the_skeleton_equals_the_ragdolls_visual_pose_partial_and_full_and_a_primitive_rig_is_as_in_m3() -> void:
	# Source: test_skinned_art::test_a_partial_ragdoll_... / test_a_full_ragdoll_and_a_launch_..._ / test_a_primitive_rigs_ragdoll_is_
	# the_m3_code_path, and test_art_punk's real-Punk fight. A stagger (the partial ragdoll), then a launch out of it at once (the
	# full one), on the shipped art; every bone within 1 mm of Ragdoll._visual on every update. A primitive rig's skeleton keeps what
	# the simulator left.
	var worst := 0.0
	var updates := 0
	for row: Dictionary in _arts():
		var rig := _rig(row)
		rig.ragdoll_start(false, rig.get_point_position(&"Head"), Vector3(0.0, 1.0, 4.0), Vector3.ZERO, Ragdoll.Part.ANY, 0.6)
		var raw := _probe(rig, true)
		var after := _probe(rig, false)
		after.peer = raw
		for i: int in 30:
			rig.advance(FRAME)
			await get_tree().physics_frame
		rig.ragdoll_start(true, rig.get_point_position(&"Chest"), Vector3(0.0, 4.0, 6.0), Vector3(0.0, 0.0, 3.0), Ragdoll.Part.ANY, INF, true)
		for i: int in 40:
			rig.advance(FRAME)
			await get_tree().physics_frame
		assert_gt(after.updates, 50, "%s: the probe ran" % row.name)
		assert_lt(after.worst_origin, RAGDOLL_GAP_M, "%s: PARTIAL then FULL: every bone within 1 mm of _visual (worst %.5f m)" % [row.name, after.worst_origin])
		assert_gt(raw.worst_origin, 0.01, "%s: the raw simulator output is %.3f m from _visual in a stagger, so the check has teeth" % [row.name, raw.worst_origin])
		worst = maxf(worst, after.worst_origin)
		updates += after.updates
	var plain := HumanoidRig.new()
	plain.height = 1.8
	plain.build_hurtboxes = false
	add_child_autofree(plain)
	plain.build()
	plain.play(&"idle", 0.0)
	plain.advance(0.0)
	plain.ragdoll_start(false, plain.get_point_position(&"Head"), Vector3(0.0, 1.0, 4.0), Vector3.ZERO, Ragdoll.Part.ANY, 0.6)
	var plain_raw := _probe(plain, true)
	var plain_after := _probe(plain, false)
	plain_after.peer = plain_raw
	for i: int in 30:
		plain.advance(FRAME)
		await get_tree().physics_frame
	assert_gt(plain_after.updates, 20, "the primitive rig's probe ran")
	assert_eq(plain_after.worst_vs_peer, 0.0, "the Ragdoll modifier wrote nothing into a primitive rig's skeleton (the M3 code path)")
	_note("A8", true, "punk and player: skeleton vs Ragdoll._visual worst %.5f m over %d updates (partial, then a launch at once); a primitive rig's skeleton untouched" % [worst, updates])


# --- A9: first-person framing ---------------------------------------------------------------------


func _view(pitch_deg: float) -> Transform3D:
	var look := Basis(Vector3.RIGHT, deg_to_rad(pitch_deg))
	return Transform3D(look, Vector3(0.0, EYE_Y, 0.0) + FirstPersonCamera.lens_offset(look))


## A first-person camera on `rig`, as FirstPersonCamera places it: the eye, the look turned `yaw_deg` and tipped `pitch_deg`
## (negative looks down), and the lens offset.
func _fp_camera(rig: HumanoidRig, pitch_deg: float = 0.0, yaw_deg: float = 0.0) -> Transform3D:
	var look := Basis(Vector3.UP, deg_to_rad(yaw_deg)) * rig.global_basis.orthonormalized()
	var lens := rig.get_point_position(&"EyePoint") + FirstPersonCamera.lens_offset(look)
	return Transform3D(look * Basis.from_euler(Vector3(deg_to_rad(pitch_deg), 0.0, 0.0)), lens)


## The player's first-person poses (test_humanoid_rig's, as test_art_player lists them): idle ahead; looking down 45 and 60 degrees;
## jab, cross, hook and uppercut at their active frames; the block; the knee in the hold; the front kick and the spin kick
## mid-turn; the haymaker's charge. `{label, pitch, yaw, setup}`.
func _view_poses() -> Array[Dictionary]:
	var poses: Array[Dictionary] = []
	poses.append({label = "idle ahead", pitch = 0.0, yaw = 0.0, setup = func(rig: HumanoidRig) -> void: _pose(rig, &"idle", 0.3)})
	for pitch: float in [-45.0, -60.0]:
		poses.append({label = "idle looking down %.0f" % -pitch, pitch = pitch, yaw = 0.0, setup = func(rig: HumanoidRig) -> void: _pose(rig, &"idle", 0.3)})
	for row: Array in [["jab", &"jab_1", 4, 3, 10], ["cross", &"jab_2", 4, 3, 10], ["hook", &"hook", 6, 3, 14], ["uppercut", &"uppercut", 8, 3, 22]]:
		var move := _move(row[1], row[2], row[3], row[4])
		poses.append({label = "%s active" % row[0], pitch = 0.0, yaw = 0.0, setup = func(rig: HumanoidRig) -> void:
			_pose(rig, &"idle", 0.5)
			rig.play_move(move)
			for i: int in move.startup + 1:
				rig.advance(FRAME)})
	poses.append({label = "block", pitch = 0.0, yaw = 0.0, setup = func(rig: HumanoidRig) -> void: _pose(rig, &"block", 0.5)})
	poses.append({label = "block, looking down 20", pitch = -20.0, yaw = 0.0, setup = func(rig: HumanoidRig) -> void: _pose(rig, &"block", 0.5)})
	var knee := _move(&"knee", 5, 3, 12)
	poses.append({label = "knee in the hold", pitch = 0.0, yaw = 0.0, setup = func(rig: HumanoidRig) -> void:
		_pose(rig, &"hold", 0.3)
		rig.play_move(knee)
		for i: int in knee.startup + 1:
			rig.advance(FRAME)})
	var front_kick := _move(&"front_kick", 7, 3, 16)
	poses.append({label = "front kick active, looking down 20", pitch = -20.0, yaw = 0.0, setup = func(rig: HumanoidRig) -> void:
		_pose(rig, &"idle", 0.5)
		rig.play_move(front_kick)
		for i: int in front_kick.startup + 1:
			rig.advance(FRAME)})
	var spin := _move(&"spin_kick", 6, 10, 16)
	for yaw: float in [0.0, 120.0, 240.0]:
		poses.append({label = "spin kick mid-turn, view %.0f" % yaw, pitch = 0.0, yaw = yaw, setup = func(rig: HumanoidRig) -> void:
			_pose(rig, &"idle", 0.5)
			rig.play_move(spin)
			for i: int in spin.startup + 5:
				rig.advance(FRAME)})
	poses.append({label = "haymaker charge", pitch = 0.0, yaw = 0.0, setup = func(rig: HumanoidRig) -> void: _pose(rig, &"haymaker_charge", 0.4)})
	return poses


func test_a9_the_art_frames_like_its_proxies_at_the_one_metre_poses_and_in_the_players_first_person_poses() -> void:
	# Source: test_art_punk::test_the_framing_of_every_glb_against_its_proxies_at_the_one_metre_poses_is_printed (the Punk), and
	# test_art_player::test_the_arts_frame_like_their_proxies_in_every_first_person_pose plus test_skinned_art's block-guard test
	# (the hero). The plan's bars: at most 3% of the 48x27 cells differ, the lens share within 4 points, the player's art never 2 cm
	# or more nearer the lens than its proxies, the guard's forearms and hands 0.3 m from the lens. The Punk's lens share is held
	# at the bar (the binding one, M4-slice-gate.md) and its cells at a ratchet; the hero is held to ratchets on all three.
	for row: Dictionary in _enemy_rows():
		var rig := _rig(row)
		rig.global_position = Vector3(0.0, 0.0, -1.0)
		rig.rotation.y = PI
		var worst_differ := 0.0
		var worst_share := 0.0
		var poses := 0
		var moves: Array[MoveData] = [null]
		for id: String in row.moves:
			moves.append(_move_file(id))
		var differ_bar := float(row.ratchets.a9_cells)
		var strike_min := float(row.ratchets.a9_strike_art_share_min)
		var lens_bars: Variant = row.ratchets.a9_lens_pp
		for pitch: float in PUNK_VIEW_PITCHES:
			var cam := _view(pitch)
			for move: MoveData in moves:
				_pose(rig, &"idle", 0.3)
				if move != null:
					rig.play_move(move)
					for i: int in move.startup + 1:
						rig.advance(FRAME)
				var cmp := SkinnedView.compare_with_proxies(rig, cam)
				var key := "%s pitch %+.0f" % [move.id if move != null else &"idle", pitch]
				var label := "%s %s" % [row.name, key]
				var share_bar := Roster.lens_bar(row, key)
				worst_differ = maxf(worst_differ, cmp.differ_share)
				worst_share = maxf(worst_share, absf(cmp.art_share - cmp.proxy_share))
				poses += 1
				assert_gt(cmp.art_share, 0.03, "%s: the art fills the view at 1 m" % label)
				assert_lte(absf(cmp.art_share - cmp.proxy_share), share_bar, "%s: the lens share is within %.1f points of the proxies'" % [label, share_bar * 100.0])
				if lens_bars is Dictionary and (lens_bars as Dictionary).has(key):
					assert_gt(cmp.art_share, strike_min, "%s: the striking art itself keeps at least %.0f%% of the view" % [label, strike_min * 100.0])
				assert_lte(cmp.differ_share, differ_bar, "%s: cells that differ stay under the ratchet (%.1f%%)" % [label, cmp.differ_share * 100.0])
		_note("A9", worst_differ <= FRAMING_DIFFER and worst_share <= FRAMING_SHARE, "%s, %d poses at 1 m: worst cells differ %.1f%% (bar 3%%, ratchet %.1f%%, margin %.1f points), worst lens share gap %.1f points (bar 4; a pose with its own lens ratchet in the roster file is held to it exactly)" % [
				row.name, poses, worst_differ * 100.0, differ_bar * 100.0, (differ_bar - worst_differ) * 100.0, worst_share * 100.0])
	var hero := _row("player")
	var hero_rig := _rig(hero)
	var hero_differ := 0.0
	var hero_share := 0.0
	var hero_nearest := 0.0
	var hero_misses := 0
	var views := _view_poses()
	for row: Dictionary in views:
		(row.setup as Callable).call(hero_rig)
		var cam := _fp_camera(hero_rig, row.pitch, row.yaw)
		var cmp := SkinnedView.compare_with_proxies(hero_rig, cam)
		hero_differ = maxf(hero_differ, cmp.differ_share)
		hero_share = maxf(hero_share, absf(cmp.art_share - cmp.proxy_share))
		hero_nearest = maxf(hero_nearest, cmp.nearest)
		if not SkinnedView.framing_problems(cmp, row.label).is_empty():
			hero_misses += 1
		assert_lte(cmp.differ_share, ArtPlayerTest.HERO_DIFFER_MAX, "hero %s: cells that differ stay under the ratchet (%.1f%%)" % [row.label, cmp.differ_share * 100.0])
		assert_lte(absf(cmp.art_share - cmp.proxy_share), ArtPlayerTest.HERO_SHARE_MAX, "hero %s: the lens share's gap stays under the ratchet (%.1f points)" % [row.label, absf(cmp.art_share - cmp.proxy_share) * 100.0])
		assert_lte(cmp.nearest, ArtPlayerTest.HERO_NEAREST_MAX_M, "hero %s: the art is at most %.1f cm nearer the lens than its proxies (%.1f cm)" % [row.label, ArtPlayerTest.HERO_NEAREST_MAX_M * 100.0, cmp.nearest * 100.0])
	_note("A9", hero_misses == 0, "player, %d first-person poses: %d miss the plan's bars; worst cells differ %.1f%% (bar 3%%, ratchet %.1f%%, margin %.1f points), lens share gap %.1f points (bar 4, ratchet %.1f, margin %.1f), art nearer than its proxies by %.1f cm (bar 2, ratchet %.1f, margin %.1f cm)" % [
			views.size(), hero_misses, hero_differ * 100.0, ArtPlayerTest.HERO_DIFFER_MAX * 100.0, (ArtPlayerTest.HERO_DIFFER_MAX - hero_differ) * 100.0,
			hero_share * 100.0, ArtPlayerTest.HERO_SHARE_MAX * 100.0, (ArtPlayerTest.HERO_SHARE_MAX - hero_share) * 100.0,
			hero_nearest * 100.0, ArtPlayerTest.HERO_NEAREST_MAX_M * 100.0, (ArtPlayerTest.HERO_NEAREST_MAX_M - hero_nearest) * 100.0])
	# The guard's forearms and hands against the lens.
	_pose(hero_rig, &"block", 0.5)
	var cam := _fp_camera(hero_rig)
	var lens := hero_rig.global_transform.affine_inverse() * cam.origin
	var arm_bones: Array[StringName] = [&"LeftLowerArm", &"RightLowerArm", &"LeftHand", &"RightHand"]
	var nearest := INF
	var counted := 0
	for mi: MeshInstance3D in hero_rig.art_meshes():
		for v: Vector3 in SkinnedView.bone_vertices(mi, hero_rig, arm_bones):
			nearest = minf(nearest, v.distance_to(lens))
			counted += 1
	assert_gt(counted, 100, "the hero's forearm and hand vertices were found (%d)" % counted)
	assert_gte(nearest, GUARD_CLEAR_M, "the guard's forearms and hands stay 0.3 m from the lens (nearest %.3f m)" % nearest)
	_note("A9", nearest >= GUARD_CLEAR_M, "player block guard: nearest forearm or hand vertex %.3f m from the lens (bar 0.3 m)" % nearest)


# --- A10: marks stick ------------------------------------------------------------------------------


func test_a10_the_marks_stick_to_the_bind_pose_and_a_damage_look_swaps_textures_only() -> void:
	# Source: test_art_punk::test_the_marks_of_every_glb_stay_on_the_bind_pose_and_a_look_change_swaps_textures_only and
	# test_damage_look: CUSTOM0/1 hold each vertex's bind-pose position and normal (read against the GLB's own mesh), the mark
	# coordinates of 100 sample vertices are identical across idle, a jab and a knockdown while the skinned vertices move, and a
	# damage-look change swaps the damage textures and their scale only (the same Shader, every other uniform as it was).
	for row: Dictionary in _arts():
		var rig := _rig(row)
		var source := SkinnedArt.entry_of(row.art).scene.instantiate()
		var moved := 0
		var checked := 0
		for mi: MeshInstance3D in rig.art_meshes():
			var arrays := (mi.mesh as ArrayMesh).surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var c0: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
			var c1: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
			assert_eq(c0.size(), vertices.size() * 3, "%s %s: CUSTOM0 per vertex" % [row.name, mi.name])
			assert_eq(c1.size(), normals.size() * 3, "%s %s: CUSTOM1 per vertex" % [row.name, mi.name])
			var source_mesh := (source.find_child(String(mi.name).trim_prefix("Art"), true, false) as MeshInstance3D).mesh as ArrayMesh
			var source_arrays := source_mesh.surface_get_arrays(0)
			var source_vertices: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
			var source_normals: PackedVector3Array = source_arrays[Mesh.ARRAY_NORMAL]
			assert_eq(source_vertices.size(), vertices.size(), "%s %s: the same vertices as the GLB's" % [row.name, mi.name])
			var step := maxi(vertices.size() / 100, 1)
			var held: Array[Vector3] = []
			for v: int in range(0, vertices.size(), step):
				var position := Vector3(c0[v * 3], c0[v * 3 + 1], c0[v * 3 + 2])
				assert_almost_eq(position, source_vertices[v], Vector3.ONE * 1e-6, "%s %s: CUSTOM0 of vertex %d is its bind-pose position" % [row.name, mi.name, v])
				assert_almost_eq(Vector3(c1[v * 3], c1[v * 3 + 1], c1[v * 3 + 2]), source_normals[v], Vector3.ONE * 1e-5, "%s %s: CUSTOM1 is its normal" % [row.name, mi.name])
				held.append(position)
				checked += 1
			var rest_skinned := SkinnedView.skin_vertices(mi, rig, SkinnedView.rest_pose(rig))
			for label: String in ["idle", "jab", "knockdown_back"]:
				_pose(rig, &"idle", 0.2)
				if label == "jab":
					var jab := _move_file(row.moves[0]) if not row.player and not row.moves.is_empty() else _move(&"jab_1", 4, 3, 10)
					rig.play_move(jab)
					for i: int in jab.startup + 1:
						rig.advance(FRAME)
				elif label == "knockdown_back":
					_pose(rig, &"knockdown_back", 0.3)
				var posed := SkinnedView.skin_vertices(mi, rig)
				var after := (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0] as PackedFloat32Array
				var k := 0
				for v: int in range(0, vertices.size(), step):
					assert_eq(Vector3(after[v * 3], after[v * 3 + 1], after[v * 3 + 2]), held[k], "%s %s %s: mark coordinate of vertex %d" % [row.name, mi.name, label, v])
					if posed[v].distance_to(rest_skinned[v]) > 0.01:
						moved += 1
					k += 1
		source.free()
		assert_gte(checked, 100, "%s: %d sample vertices" % [row.name, checked])
		assert_gt(moved, 50, "%s: the body moved while its marks did not (%d sample moves)" % [row.name, moved])
		var material := rig.paint.art_material()
		var shader: Shader = material.shader
		var names := ["albedo_tex", "use_albedo_tex", "marks", "use_rest_custom", "edge_tag", "ink", "flash_amount"]
		var before: Dictionary = {}
		for name: String in names:
			before[name] = material.get_shader_parameter(name)
		var textures: Array[Texture2D] = []
		for level: int in [DamageLook.Level.CLEAN, DamageLook.Level.BRUISED, DamageLook.Level.BLOODIED]:
			rig.set_damage_look(level)
			assert_same(material.shader, shader, "%s: level %d keeps the shader" % [row.name, level])
			for name: String in names:
				assert_eq(material.get_shader_parameter(name), before[name], "%s: level %d leaves %s" % [row.name, level, name])
			textures.append(material.get_shader_parameter(&"damage_tex"))
		assert_ne(textures[0], textures[1], "%s: bruised swaps the damage texture" % row.name)
		assert_ne(textures[1], textures[2], "%s: bloodied swaps it again" % row.name)
		_note("A10", true, "%s: CUSTOM0/1 are the bind pose on %d sample vertices through idle, a jab and a knockdown (%d moves of the skin); three damage looks, one shader" % [row.name, checked, moved])


# --- A11: the flash on the art ----------------------------------------------------------------------


## Whether `rig` draws its contact-flash overlay on the ART's material (the overlay is every base material's next pass, or none).
func _art_overlay_on(rig: HumanoidRig) -> bool:
	var overlay := rig.flash_overlay()
	return overlay != null and rig.paint.art_material().next_pass == overlay


func test_a11_the_flash_shows_for_hit_flash_frames_and_sits_on_the_skinned_surface() -> void:
	# Source: test_hit_flash::test_the_flash_shows_for_exactly_hit_flash_frames_rendered_frames (dummies; here the player jabs a real
	# Street Punk in its art) and test_art_punk::test_the_contact_flash_anchor_of_every_glb_is_near_the_skinned_surface. The anchor
	# of a hit on the head, the torso and a leg at 1 m against the CPU-skinned surface: the head meets 2 cm; the torso and the legs are
	# at their ratchet (the contact point is clamped onto the nearest bone's follower, which the art's bulk is not).
	Tuning.data.ai_frozen = true
	var room := (load(TRAINING_ROOM) as PackedScene).instantiate()
	room.set(&"with_presentation", false)
	add_child_autofree(room)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player: PlayerCharacter = room.get(&"player")
	player.input.scripted = true
	for dummy: Node3D in room.get(&"dummies"):
		dummy.global_position = Vector3(30.0, 0.0, -30.0)
	var hits: Array[HitInfo] = []
	var on_hit := func(hit: HitInfo) -> void: hits.append(hit)
	CombatEvents.hit_landed.connect(on_hit)
	var shown_by_frames := {}
	for frames: int in [2, 1, 3]:
		Tuning.data.hit_flash_frames = frames
		var punk := (load(Roster.row("punk").actor_scene) as PackedScene).instantiate() as StreetPunk
		var stage := Node3D.new()
		add_child_autofree(stage)
		stage.add_child(punk)
		await get_tree().physics_frame
		assert_true(punk.rig.has_art(), "the Street Punk wears its art")
		punk.max_health = 1000.0
		punk.health = 1000.0
		var at := player.global_position + player.global_basis * Vector3(0.0, 0.0, -1.2)
		punk.global_position = at
		var to_player := player.global_position - at
		punk.rotation.y = atan2(-to_player.x, -to_player.z)
		await get_tree().physics_frame
		hits.clear()
		player.input.push_press(&"P", 2)
		var shown: Array[bool] = []
		for i: int in 240:
			await get_tree().process_frame
			var landed := false
			for hit: HitInfo in hits:
				if hit.victim == punk:
					landed = true
			if landed:
				shown.append(_art_overlay_on(punk.rig))
				if shown.size() > 8:
					break
		var expected: Array[bool] = []
		for i: int in 9:
			expected.append(i < frames)
		assert_eq(shown, expected, "the art flashes for exactly %d rendered frames from the hit's" % frames)
		shown_by_frames[frames] = shown.filter(func(b: bool) -> bool: return b).size()
		stage.queue_free()
		await get_tree().physics_frame
		await get_tree().physics_frame
	CombatEvents.hit_landed.disconnect(on_hit)
	_note("A11", true, "a real Street Punk's art flashes for exactly hit_flash_frames rendered frames (shown for %s frames at hit_flash_frames 2, 1, 3 from the jab's hit)" % [
			[shown_by_frames[2], shown_by_frames[1], shown_by_frames[3]]])
	var points := {"head": Vector3(0.0, 1.68, -0.4), "torso": Vector3(0.0, 1.25, -0.4), "leg": Vector3(0.11, 0.6, -0.4)}
	for row: Dictionary in _arts():
		var rig := _rig(row, true)
		_pose(rig, &"idle", 0.3)
		var gaps := PackedStringArray()
		var misses := PackedStringArray()
		var ratchet: Dictionary = ANCHOR_RATCHET_PLAYER_M if row.player else row.ratchets.anchor_m
		for label: String in points:
			rig.flash_at(points[label], 1.0, 0.5, 0.5)
			var anchor: Vector3 = rig.flash_overlay().get_shader_parameter(&"flash_point")
			var gap := INF
			for mi: MeshInstance3D in rig.art_meshes():
				gap = minf(gap, SkinnedView.surface_gap(mi, rig, anchor))
			gaps.append("%s %.1f cm (ratchet %.1f, margin %.1f)" % [label, gap * 100.0, float(ratchet[label]) * 100.0, (float(ratchet[label]) - gap) * 100.0])
			if gap > ANCHOR_M:
				misses.append("%s %.1f cm" % [label, gap * 100.0])
			assert_lte(gap, float(ratchet[label]), "%s: the %s flash sits within %.1f cm of the skinned surface (%.1f cm)" % [row.name, label, float(ratchet[label]) * 100.0, gap * 100.0])
			rig.set_flash(0.0)
		_note("A11", misses.is_empty(), "%s: flash anchor to the skinned surface: %s%s" % [row.name, ", ".join(gaps), ("  (plan's 2 cm missed: %s)" % ", ".join(misses)) if not misses.is_empty() else ""])


# --- A12: the suite ----------------------------------------------------------------------------------


func test_a12_the_suite_count_only_rises_and_look_show_art_off_is_the_primitives_as_in_m3() -> void:
	# Source: tools/run_tests.sh (the whole suite, 0 SCRIPT ERROR / SHADER ERROR / ERROR in the output, which the lead reads) and
	# test_skinned_art::test_look_show_art_reaches_every_rig_with_art_live. Here: the number of test functions in the files of
	# tests/ against M3's 1198, and the switch.
	var count := 0
	var files := 0
	var dir := DirAccess.open("res://tests")
	assert_not_null(dir, "tests/ opens")
	if dir != null:
		for file: String in dir.get_files():
			if not (file.begins_with("test_") and file.ends_with(".gd")):
				continue
			files += 1
			for line: String in FileAccess.get_file_as_string("res://tests/%s" % file).split("\n"):
				if line.begins_with("func test_"):
					count += 1
	assert_gte(count, SUITE_COUNT_MIN, "the suite holds at least M3's 1198 tests (%d in %d files)" % [count, files])
	for row: Dictionary in _arts():
		var rig := _rig(row)
		var proxies: Array[MeshInstance3D] = []
		for node: Node in get_tree().get_nodes_in_group(HumanoidRig.VIEW_PROXY_GROUP):
			if rig.is_ancestor_of(node):
				proxies.append(node as MeshInstance3D)
		assert_gte(proxies.size(), 41, "%s: the primitives are all built as proxies (%d)" % [row.name, proxies.size()])
		for mi: MeshInstance3D in rig.art_meshes():
			assert_true(mi.visible, "%s: the art shows with look_show_art on" % row.name)
		Tuning.set_value(&"look_show_art", false)
		for mi: MeshInstance3D in rig.art_meshes():
			assert_false(mi.visible, "%s: look_show_art off hides the art" % row.name)
		for proxy: MeshInstance3D in proxies:
			assert_true(proxy.visible, "%s: and shows the primitives (%s)" % [row.name, proxy.name])
		var late := _rig(row)
		assert_false(late.art_meshes()[0].visible, "%s: a rig built while it is off starts with the primitives" % row.name)
		Tuning.set_value(&"look_show_art", true)
	_note("A12", true, "%d test functions in %d files against M3's %d; look_show_art off shows the primitives of every roster character and the hero (the full run's SCRIPT/SHADER/ERROR count is the lead's read of tools/run_tests.sh)" % [count, files, SUITE_COUNT_MIN])


# --- A13: assets and money ------------------------------------------------------------------------------


func _files_under(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f: String in dir.get_files():
		out.append("%s/%s" % [dir_path, f])
	for d: String in dir.get_directories():
		out.append_array(_files_under("%s/%s" % [dir_path, d]))
	return out


func test_a13_every_asset_has_a_row_is_in_lfs_and_the_ledger_accounts_for_the_credits() -> void:
	# Source: test_art_contract::test_every_exported_file_has_an_assets_row (and the report tests). Here: every file under
	# assets/export and assets/source/concepts named in ASSETS.md; every binary extension of them tracked by LFS in .gitattributes;
	# the Tripo ledger (assets/source/tripo_ledger.jsonl): every created task finished, M4's spend at most the 750 stop (the cap is
	# 800), no balance under the 700 floor.
	var assets := FileAccess.get_file_as_string(ASSETS_MD)
	assert_false(assets.is_empty(), "ASSETS.md opens")
	var lfs := FileAccess.get_file_as_string(GITATTRIBUTES)
	var binary := ["glb", "png", "jpg", "jpeg", "webp", "blend", "mp4", "wav", "ogg"]
	var missing: Array[String] = []
	var not_lfs: Array[String] = []
	var checked := 0
	for dir_path: String in ["res://assets/export", "res://assets/source/concepts"]:
		for file_path: String in _files_under(dir_path):
			if file_path.ends_with(".import") or file_path.ends_with(".uid") or file_path.ends_with(".gitkeep") or file_path.get_file() == ".gdignore":
				continue
			checked += 1
			var rel := file_path.trim_prefix("res://")
			if not assets.contains(rel):
				missing.append(rel)
			var extension := file_path.get_extension().to_lower()
			if binary.has(extension) and not lfs.contains("*.%s filter=lfs" % extension) and not lfs.contains("%s filter=lfs" % rel):
				not_lfs.append(rel)
	assert_gt(checked, 10, "assets were found (%d)" % checked)
	assert_eq(missing, [] as Array[String], "every file under assets/export and assets/source/concepts is named in ASSETS.md")
	assert_eq(not_lfs, [] as Array[String], "every binary of them goes through Git LFS")
	var created := {}
	var finished := {}
	var spent := 0.0
	var floor_seen := INF
	var tasks := 0
	for line: String in FileAccess.get_file_as_string(LEDGER_PATH).split("\n", false):
		var row: Variant = JSON.parse_string(line)
		if not row is Dictionary:
			continue
		if row.get("milestone", "M4") != "M4":
			continue
		match String(row.get("event", "")):
			"created":
				created[String(row.task_id)] = true
			"finished":
				finished[String(row.task_id)] = true
				spent += float(row.get("credits_consumed", 0.0))
				floor_seen = minf(floor_seen, float(row.get("balance_after", INF)))
				tasks += 1
				assert_true(row.get("credits_consumed", null) is float or row.get("credits_consumed", null) is int, "%s: the real credits_consumed is logged" % row.task_id)
	for id: String in created:
		assert_true(finished.has(id), "task %s was created and finished (every credit is accounted for)" % id)
	assert_lte(spent, TRIPO_STOP, "M4's Tripo spend stays at or under the 750 stop (%.0f)" % spent)
	assert_lte(spent, TRIPO_CAP)
	if tasks > 0:
		assert_gte(floor_seen, TRIPO_FLOOR, "no balance under the 700 floor (lowest %.0f)" % floor_seen)
	_note("A13", true, "%d files under assets/export and assets/source/concepts, each named in ASSETS.md and in LFS; Tripo: %d tasks, %.0f credits (stop 750, cap 800), lowest balance %.0f (floor 700)" % [
			checked, tasks, spent, floor_seen])


# --- A14: readability holds ---------------------------------------------------------------------------


func test_a14_the_autopilot_crowd_with_art_punks_keeps_the_hard_readability_metrics() -> void:
	# Source: test_slice_crowd::test_the_autopilot_fights_real_punks_and_the_hard_metrics_hold (the M3 act's headless twin, the
	# Punks now wearing their art) and the windowed act 'Six Punks, fight' through tools/check_m3_log.py. Three real Punks are
	# kept on the street for 15 s of game time, the scripted player fights them in god mode: R1 (the cap), R2 (the wind-up gap), R3
	# (no hit without its wind-up), R10 (the rear warning against the rule), R11 (no big knockdown) hold, nobody is stuck, and every
	# Punk of the crowd wears the art.
	Tuning.set_value(&"waves_enabled", false)
	Tuning.set_value(&"god_mode", true)
	var room := (load(CROWD_ROOM) as PackedScene).instantiate() as CrowdRoom
	room.with_presentation = true
	room.waves_enabled_on_start = false
	add_child_autofree(room)
	await get_tree().physics_frame
	for i: int in 8:
		await get_tree().physics_frame
	var player: PlayerCharacter = room.player
	var probe := Probe.new()
	probe.attach(room, player)
	var pilot := Pilot.new()
	pilot.enemy_group = &"ai_enemy"
	pilot.attach(room, player)
	probe.start_act("m4 done-when, autopilot, three art punks")
	var spawned := 0
	var last_spawn := -1000
	var with_art := 0
	var without_art := 0
	for frame in 900:
		if room.spawner.alive_count() < 3 and frame - last_spawn >= 45:
			last_spawn = frame
			var point: Dictionary = room.spawner.spawn_points[CrowdBot.SURROUND_POINTS[spawned % CrowdBot.SURROUND_POINTS.size()]]
			var punk := room.spawner.spawn_enemy(&"punk", point.position, point.yaw, false, point.lane_point)
			spawned += 1
			if punk != null and punk.rig != null and punk.rig.has_art():
				with_art += 1
			else:
				without_art += 1
		await get_tree().physics_frame
	pilot.stop()
	var summary := probe.end_act()
	var fallen := spawned - room.spawner.alive_count()
	assert_gt(spawned, 3, "Punks were spawned (%d)" % spawned)
	assert_eq(without_art, 0, "every Punk of the crowd wears the art (%d of %d)" % [with_art, spawned])
	assert_gte(fallen, 4, "the autopilot put at least four Punks down in 15 s (%d of %d)" % [fallen, spawned])
	for row: Dictionary in summary.verdict:
		if row.hard:
			assert_ne(row.status, "FAIL", "%s %s: %s (needs %s)" % [row.id, row.name, row.value, row.limit])
	assert_true(Probe.hard_ok(summary.verdict), "no hard readability metric fails")
	assert_eq(int(summary.metrics.stuck_events), 0, "R13: nobody stuck")
	var hard := PackedStringArray()
	for row: Dictionary in summary.verdict:
		if row.hard:
			hard.append("%s %s" % [row.id, row.status])
	_note("A14", true, "autopilot, %d art Punks over 900 ticks (%d fell): hard rows %s, none stuck; the 60 s windowed act is tools/check_m3_log.py's, the lead's run" % [
			spawned, fallen, ", ".join(hard)])


# --- P3-int's own: the first-person hull, and the windowed rows' arithmetic -----------------------------


func test_the_players_art_hull_is_toon_materials_first_person_outline_and_an_enemys_is_the_full_width_one() -> void:
	# P3-int step 1: RigPaint.outline_material() hands the rig's first_person_body to ToonMaterials.outline(first_person), so the
	# player's art needs no PlayerCharacter._wear_first_person_hull() (deleted) and no call of ToonMaterials' private _hull(). No look
	# change: the same two shared materials as before (M4-calls/P3-int.md C1 has the before and after of the player's hull width).
	var hero := _rig(_row("player"))
	for mi: MeshInstance3D in hero.art_meshes():
		assert_same(mi.material_overlay, ToonMaterials.outline(true), "%s wears the first-person variant" % mi.name)
		assert_same(mi.material_overlay, hero.paint.outline_material(), "and it is what RigPaint hands out for the player's own body")
	var punk := _rig(_row("punk"))
	for mi: MeshInstance3D in punk.art_meshes():
		assert_same(mi.material_overlay, ToonMaterials.outline(false), "%s wears the full-width one" % mi.name)
	assert_same(ToonMaterials.outline(), ToonMaterials.outline(false), "no argument is the full-width hull")
	assert_ne(ToonMaterials.outline(true), ToonMaterials.outline(false), "two materials")
	assert_eq(ToonMaterials.outline(true).get_shader_parameter(&"fp_scale"), Tuning.data.look_outline_fp_scale, "the player's own line is x look_outline_fp_scale")
	assert_eq(ToonMaterials.outline(false).get_shader_parameter(&"fp_scale"), 1.0, "an enemy's is full width")
	assert_eq(ToonMaterials.outline(true).get_shader_parameter(&"mode"), ToonMaterials.Hull.ART)
	var player := PlayerCharacter.new()
	assert_false(player.has_method(&"_wear_first_person_hull"), "the player no longer picks his own hull")
	player.free()
	Tuning.set_value(&"look_outline_fp_scale", 0.5)
	assert_eq(ToonMaterials.outline(true).get_shader_parameter(&"fp_scale"), 0.5, "the F1 panel still moves it live")


func test_the_final_probes_source_acts_exist_by_title_and_it_is_the_only_act_with_its_title() -> void:
	# The final act plays five acts by title (tests/bot/acts/look_final_acts.gd): a renamed act would silently read "not measured".
	var bot := Node.new()
	var titles := {}
	for acts: Array[Dictionary] in [LookTuneActs.acts(bot), LookActs.acts(bot), LookFinalActs.acts(bot)]:
		for act: Dictionary in acts:
			titles[act.title] = int(titles.get(act.title, 0)) + 1
	bot.free()
	for title: String in LookFinalActs.SOURCES:
		assert_eq(titles.get(title, 0), 1, "'%s' is one act" % title)
	assert_eq(titles.get("Look: final probe", 0), 1)
	for title: String in titles:
		if title != "Look: final probe":
			assert_false(title.to_lower().contains("look: final probe") or "look: final probe".contains(title.to_lower()), "no title holds the final probe's or is held by it (%s)" % title)


func test_the_windowed_rows_are_summed_from_what_the_acts_measured_and_missed_bars_read_missed() -> void:
	# look_probe.gd final_rows(): L1 (hull widths within a pixel of look_outline_px and under 4.5, the own body at x fp scale), L2
	# (2-3 jacket bands, shadow/lit at least 0.4, the shadow's hue nearer the tint), L3 (M2's jab flash share + 2 points) and L5 (the
	# art-drawn R8 within 2 and 4 points of the proxies', no hidden wind-up the proxies missed), from synthetic metrics.
	var t3 := {}
	for label: String in ["d1_0_m", "d2_5_m", "d5_0_m", "d10_0_m"]:
		for family: String in ["crown", "left", "right"]:
			t3["%s_%s_px1080" % [label, family]] = 3.6
	var t8 := {"guard_left_px1080": 3.4, "guard_right_px1080": 3.0, "guard_top_px1080": 3.5}
	var t1 := {
		"front_lit_jacket_bands": 3, "front_lit_jacket_shadow_over_lit": 0.55,
		"front_lit_jacket_luma_hue": "0.150/250/0.30/0.40,0.300/200/0.30/0.50,0.600/190/0.40/0.55",
		"back_lit_jacket_bands": 1, "back_lit_jacket_shadow_over_lit": 1.0, "back_lit_jacket_luma_hue": "0.200/250/1.00/0.40",
	}
	var t5 := {"jab_flash_white_share_of_view": 0.039, "jab_flash_hit_landed": true}
	var l5 := PackedStringArray([
		"LOOK-L5 Six Punks, fight R8 (164 samples of the lens, 1644 ticks): proxies p50 27.6% p95 43.8% max 60.0% | art drawn p50 28.1% p95 46.5% max 62.0% | difference p50 +0.5 pp p95 +2.7 pp | cells that differ: mean 3.1% worst 10.2%",
		"LOOK-L5 Six Punks, fight R4 (16 wind-ups, 14 in the lens, 2 never sampled): hidden by another enemy: proxies 0 of 14 | art drawn 0 of 14 | worst sample 212.0 ms",
	])
	var tint_hue := Color(0.36, 0.32, 0.55).h * 360.0
	var good := LookProbe.final_rows({"t3": t3, "t8": t8, "t1": t1, "t5": t5}, l5, 3.75, 0.8, tint_hue)
	for id: String in ["L1", "L2", "L3", "L5"]:
		assert_eq(good[id].state, "met", "%s: %s" % [id, good[id].text])
	assert_eq(LookProbe.parse_l5(l5)["Six Punks, fight"].r4_art, 0)
	assert_almost_eq(float(LookProbe.parse_l5(l5)["Six Punks, fight"].diff_p95), 2.7, 0.001)
	assert_eq(LookProbe.parse_bands(t1.front_lit_jacket_luma_hue).size(), 3)
	# A hull 1.3 px off, a crown over the ceiling, a single band, a flash over M2's + 2 points and an art R8 6 points off at the 95th: each
	# row misses, and says so.
	var bad_t3 := t3.duplicate()
	bad_t3["d2_5_m_left_px1080"] = 5.1
	bad_t3["d10_0_m_crown_px1080"] = 2.4
	var bad_t1 := t1.duplicate()
	bad_t1["front_lit_jacket_bands"] = 1
	var bad_l5 := PackedStringArray([l5[0].replace("difference p50 +0.5 pp p95 +2.7 pp", "difference p50 +0.5 pp p95 +6.0 pp"), l5[1]])
	var bad := LookProbe.final_rows({"t3": bad_t3, "t8": t8, "t1": bad_t1, "t5": {"jab_flash_white_share_of_view": 0.07, "jab_flash_hit_landed": true}}, bad_l5, 3.75, 0.8, tint_hue)
	for id: String in ["L1", "L2", "L3", "L5"]:
		assert_eq(bad[id].state, "missed", "%s misses: %s" % [id, bad[id].text])
	assert_eq(bad.L1.misses.size(), 2, "the 5.1 px side and the 2.4 px crown")
	# Nothing measured (a headless run draws nothing): "not measured", never a pass.
	var none := LookProbe.final_rows({}, PackedStringArray(), 3.75, 0.8, tint_hue)
	for id: String in ["L1", "L2", "L3", "L5"]:
		assert_eq(none[id].state, "not measured", id)
	assert_eq(LookProbe.final_lines(none).size(), 4)
