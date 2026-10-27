extends GutTest
## Milestone 4, F-player-int: the player in his own art. The hero's GLB (assets/export/characters/
## player/player.glb, F-player-art's) does not exist yet, so the player wears his primitives in the
## game; behind Tuning's Debug switch look_player_art_probe he wears the probe body instead
## (tests/fixtures/art/probe_body.glb: Body + Body__fp_hidden, UV2, COLOR, the chained binds), and
## these tests run on it. They run on the hero's GLB as well the moment it exists (`_arts()`).
##
## What they hold: the wiring (the missing GLB is a silent no-op, the probe and the hero's art go
## through CombatActor.art; Body on the visible layer, Body__fp_hidden on the first-person-hidden
## one; the art's hull at look_outline_fp_scale); the first-person view of the drawn art against its
## proxies (M4-plan A4, row A9) over the poses of test_humanoid_rig; the visible mesh watertight; the
## gate's lens rules on the SKINNED art through SkinnedView (slice-gate gap 7): in a hold the forearms
## and hands stay 0.3 m from the lens and the own body covers a third of the view or less, and in the
## KO view the lens keeps its distance from the drawn body; and feel question 3's switch,
## fp_knockdown_hide_torso, measured with it off and on, on the primitives and on the art.
##
## Every number is printed ("ART-PLAYER ..."). The framing rules (A9) are asserted where the probe
## passes them; where it does not, the figure is printed with "GATE" and re-run on the real GLB:
## the probe is a mannequin whose proportions are a voxel remesh's, not the hero's.

const SkinnedView := preload("res://tests/skinned_view.gd")
const FPView := preload("res://tests/fp_view.gd")
const ROOM := preload("res://game/level/test_room.tscn")
const KICKER_SCENE := preload("res://game/enemies/kicker/kicker.tscn")
const StubDirector := preload("res://tests/fixtures/stub_director.gd")
const PLAYER_SCENE := "res://game/player/player.tscn"
const PLAYER_ART := "res://game/actors/art/player_art.tres"
const PROBE_GLB := "res://tests/fixtures/art/probe_body.glb"
const FRAME := 1.0 / 60.0
## Row A9: at most 3% of the cells differ, the share of the view within 4 points, the art never
## 2 cm or more nearer the lens than its proxies.
const NEAREST_LIMIT_M := 0.02
## The gate's lens rules (test_grab_view): the forearms and hands this far from the lens, the own
## body this share of the view or less.
const ARM_CLEAR_M := 0.3
const OWN_SHARE_MAX := 1.0 / 3.0
## The KO view's distance from the body (test_ko_view): nothing of the drawn body nearer the lens than
## this while the head layer is lifted.
const KO_BODY_CLEAR_M := 0.25
## What the probe body does today (a mannequin, not the hero): the most of its cells that differ
## from its proxies and its share of the view's gap (points) over the poses, how much nearer than
## FPView's loose proxies it stands (P1-skin C6's 7 cm), the share of the proxies' cells it covers
## where they fill PROBE_COVERAGE_FROM of the view, and the poses whose silhouette cells (two on the
## view's lower edge) put it nearer than the proxies' own meshes by the figure of a surface behind.
const PROBE_DIFFER_MAX := 0.06
const PROBE_SHARE_MAX := 0.06
const PROBE_NEAREST_MAX_M := 0.07
const PROBE_EXACT_NEAREST_MAX_M := 0.03
const PROBE_COVERAGE_MIN := 0.6
const PROBE_COVERAGE_FROM := 0.03
const PROBE_SILHOUETTE_POSES: Array[String] = ["idle looking down 60"]

var room: Node3D
var player: PlayerCharacter


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


# --- Harness ------------------------------------------------------------------------------


## The arts under test: the probe body, and the hero's GLB once it exists (player_art.tres resolves
## to it). Each is `{name, art}` with the CharacterArt ready to wear.
func _arts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({name = "probe", art = PlayerCharacter.worn_art(null, true)})
	var hero := PlayerCharacter.worn_art(load(PLAYER_ART) as CharacterArt)
	if hero != null:
		out.append({name = "hero", art = hero})
	return out


## A bare rig dressed as the player (PlayerCharacter._configure_rig()) wearing `art`, idle.
func _rig(art: CharacterArt, height: float = 1.8) -> HumanoidRig:
	var rig := HumanoidRig.new()
	var dresser := PlayerCharacter.new()
	dresser._configure_rig(rig)
	dresser.free()
	rig.height = height
	rig.build_hurtboxes = false
	rig.art = art
	add_child_autofree(rig)
	rig.build()
	rig.play(&"idle", 0.0)
	rig.advance(0.0)
	return rig


## The real player scene alone in the tree, its body built with the probe switch as given.
func _player(probe: bool) -> PlayerCharacter:
	Tuning.data.look_player_art_probe = probe
	var p := (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerCharacter
	add_child_autofree(p)
	await get_tree().physics_frame
	return p


func _pose(rig: HumanoidRig, animation: StringName, at: float) -> void:
	rig.play(animation, 0.0)
	rig.advance(0.0)
	rig.advance(at)


func _move(id: StringName, startup: int, active: int, recovery: int) -> MoveData:
	var move := MoveData.new()
	move.id = id
	move.startup = startup
	move.active = active
	move.recovery = recovery
	return move


## A first-person camera on `rig`, as FirstPersonCamera places it: the eye, the look turned `yaw_deg`
## and tipped `pitch_deg` (negative looks down), and the lens offset.
func _fp_camera(rig: HumanoidRig, pitch_deg: float = 0.0, yaw_deg: float = 0.0) -> Transform3D:
	var look := Basis(Vector3.UP, deg_to_rad(yaw_deg)) * rig.global_basis.orthonormalized()
	var lens := rig.get_point_position(&"EyePoint") + FirstPersonCamera.lens_offset(look)
	return Transform3D(look * Basis.from_euler(Vector3(deg_to_rad(pitch_deg), 0.0, 0.0)), lens)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_until(condition: Callable, max_ticks: int = 400) -> bool:
	for i in max_ticks:
		if condition.call():
			return true
		await get_tree().physics_frame
	return false


func _lines(title: String, lines: PackedStringArray) -> void:
	print("ART-PLAYER %s" % title)
	for line: String in lines:
		print("ART-PLAYER   ", line)


func _art_mesh(rig: HumanoidRig, mesh_name: StringName) -> MeshInstance3D:
	for mi: MeshInstance3D in rig.art_meshes():
		if mi.name == mesh_name:
			return mi
	return null


# --- The player wears the art ---------------------------------------------------------------


func test_the_missing_hero_glb_is_a_silent_no_op_and_the_player_keeps_his_primitives() -> void:
	var scene_art := load(PLAYER_ART) as CharacterArt
	assert_not_null(scene_art, "the scene's art loads whether or not the GLB exists")
	assert_eq(scene_art.id, &"player")
	assert_eq(scene_art.triangle_budget, 30000, "Spec §10: the player's budget")
	var glb: String = scene_art.get_meta(PlayerCharacter.ART_SCENE_META)
	assert_eq(glb, "res://assets/export/characters/player/player.glb", "it names the hero's GLB where F-player-art puts it")
	var p := await _player(false)
	assert_same(p.art, scene_art, "player.tscn carries player_art.tres")
	if ResourceLoader.exists(glb):
		assert_true(p.rig.has_art(), "the hero's GLB exists: the player wears it")
		return
	assert_null(PlayerCharacter.worn_art(scene_art), "no GLB, no art to wear")
	assert_null(p.rig.art, "the rig is a placeholder rig: art null builds exactly M3's primitives")
	assert_false(p.rig.has_art())
	assert_eq(p.rig.art_meshes().size(), 0)
	var primitives := 0
	for mesh: MeshInstance3D in FPView.meshes_under(p.rig):
		assert_true(mesh.visible, "%s is drawn" % mesh.name)
		assert_false(mesh.is_in_group(HumanoidRig.VIEW_PROXY_GROUP), "%s is no proxy" % mesh.name)
		assert_false(mesh.is_in_group(HumanoidRig.ART_GROUP))
		primitives += 1
	assert_eq(primitives, 45, "the player's 45 primitives")


func test_worn_art_resolves_the_probe_the_scene_art_and_a_named_glb_that_exists() -> void:
	var scene_art := load(PLAYER_ART) as CharacterArt
	var probe := PlayerCharacter.worn_art(scene_art, true)
	assert_not_null(probe)
	assert_not_null(probe.scene, "the probe body")
	assert_eq(probe.scene.resource_path, PROBE_GLB)
	assert_eq(probe.triangle_budget, 30000)
	assert_same(PlayerCharacter.worn_art(null, true), probe, "the probe is one resource, so SkinnedArt's cache holds")
	assert_null(PlayerCharacter.worn_art(null), "no art: none")
	var carrying := CharacterArt.new()
	carrying.scene = load(PROBE_GLB)
	assert_same(PlayerCharacter.worn_art(carrying), carrying, "an art that carries a scene is worn as it is")
	# An art that names a GLB by its metadata gets it once the file exists: here the probe stands in.
	var naming := CharacterArt.new()
	naming.id = &"player"
	naming.palette = scene_art.palette
	naming.triangle_budget = 30000
	naming.set_meta(PlayerCharacter.ART_SCENE_META, PROBE_GLB)
	var worn := PlayerCharacter.worn_art(naming)
	assert_not_null(worn)
	assert_not_same(worn, naming, "a copy: the scene's resource is never changed")
	assert_null(naming.scene)
	assert_eq(worn.scene.resource_path, PROBE_GLB)
	assert_eq(worn.id, &"player")
	assert_same(PlayerCharacter.worn_art(naming), worn, "one copy per art")
	var missing := CharacterArt.new()
	missing.set_meta(PlayerCharacter.ART_SCENE_META, "res://assets/export/characters/player/no_such_file.glb")
	assert_null(PlayerCharacter.worn_art(missing), "a file that is not there is no art")


func test_the_probe_switch_makes_the_player_wear_the_probe_body_and_off_he_does_not() -> void:
	var off := await _player(false)
	var off_has := off.rig.has_art()
	var on := await _player(true)
	assert_true(on.rig.has_art(), "look_player_art_probe on: the probe attaches")
	assert_eq(SkinnedArt.check(on.rig.art), PackedStringArray(), "and keeps the contract")
	assert_eq(on.rig.art_meshes().size(), 2, "Body and Body__fp_hidden")
	assert_not_null(_art_mesh(on.rig, &"ArtBody"))
	assert_not_null(_art_mesh(on.rig, &"ArtBody__fp_hidden"))
	assert_eq(off_has, ResourceLoader.exists("res://assets/export/characters/player/player.glb"), "off: only the hero's GLB, when it exists")
	assert_false(TuningData.new().look_player_art_probe, "the switch defaults to off")
	var info := Tuning._property_info(Tuning.tuning_properties(), &"look_player_art_probe")
	assert_eq(info.group, "Debug", "in the Debug group (A9)")
	assert_false(Tuning.is_preset_property(&"look_player_art_probe"), "which presets skip")


func test_the_probe_body_is_two_meshes_body_visible_and_body_fp_hidden_on_the_hidden_layer() -> void:
	var p := await _player(true)
	var body := _art_mesh(p.rig, &"ArtBody")
	var hidden := _art_mesh(p.rig, &"ArtBody__fp_hidden")
	var default_layer := CombatTypes.bit(CombatTypes.VIS_DEFAULT)
	var hidden_layer := CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN)
	assert_eq(body.layers, default_layer, "Body on the visible layer")
	assert_eq(hidden.layers, hidden_layer, "Body__fp_hidden on layer 2, the same as PlaceholderBody.FP_HIDDEN_BONES' primitives")
	for proxy: MeshInstance3D in FPView.meshes_under(p.rig):
		if proxy.is_in_group(HumanoidRig.VIEW_PROXY_GROUP):
			assert_false(proxy.visible, "%s: a primitive of a rig with art stands in as a hidden proxy" % proxy.name)
	var hidden_names: Array[StringName] = []
	for part: PlaceholderBody.Part in PlaceholderBody.parts(true):
		if PlaceholderBody.is_fp_hidden(part):
			hidden_names.append(StringName(part.name))
	for proxy: MeshInstance3D in FPView.meshes_under(p.rig):
		if proxy.is_in_group(HumanoidRig.VIEW_PROXY_GROUP) and hidden_names.has(proxy.name):
			assert_eq(proxy.layers, hidden_layer, "%s stays on the hidden layer" % proxy.name)
	assert_true(hidden.is_visible_in_tree(), "the hidden upper body is still drawn: it casts the shadows the player sees")
	assert_eq(hidden.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	assert_eq(body.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	# The camera: the first-person lens never draws layer 2, and the KO view's does once it is out.
	var cam := FirstPersonCamera.new()
	add_child_autofree(cam)
	cam.player = p
	assert_eq(hidden.layers & cam.cull_mask, 0, "the first-person lens never draws the upper body (inside the head and chest)")
	assert_ne(body.layers & cam.cull_mask, 0, "and draws Body")
	cam.set_cull_mask_value(CombatTypes.VIS_FP_HIDDEN, true)
	assert_ne(hidden.layers & cam.cull_mask, 0, "the KO view, with the layer lifted, shows the whole body")
	# Every other camera (the side view, free fly) has the default mask: the whole body.
	var other := Camera3D.new()
	add_child_autofree(other)
	assert_ne(hidden.layers & other.cull_mask, 0, "the side view and free fly show it")


func test_the_art_hull_of_the_players_body_is_the_first_person_one() -> void:
	var p := await _player(true)
	var data := Tuning.data
	for mi: MeshInstance3D in p.rig.art_meshes():
		var hull := mi.material_overlay as ShaderMaterial
		assert_not_null(hull, "%s wears a hull" % mi.name)
		assert_eq(hull.get_shader_parameter(&"mode"), ToonMaterials.Hull.ART, "%s: the art's smooth-normal hull" % mi.name)
		assert_eq(hull.get_shader_parameter(&"fp_scale"), data.look_outline_fp_scale, "%s: at look_outline_fp_scale" % mi.name)
		assert_eq(hull.get_shader_parameter(&"lens_fade_m"), data.look_outline_lens_fade_m, "%s: fading out near the lens" % mi.name)
		assert_eq(hull.get_shader_parameter(&"width_px"), data.look_outline_px)
		assert_false(mi.material_override == null, "%s has its toon material" % mi.name)
	var punk_hull := ToonMaterials.outline()
	assert_eq(punk_hull.get_shader_parameter(&"fp_scale"), 1.0, "an enemy's art hull is at full width")
	assert_not_same(p.rig.art_meshes()[0].material_overlay, punk_hull)
	# The width at the arms' 0.3-0.6 m is the character's times fp_scale; it fades to nothing at the lens.
	var d := Tuning.data
	for dist: float in [0.3, 0.45, 0.6]:
		var full := ToonMaterials.outline_width_m(dist, d.look_outline_px, 1.0, 1080.0, d.look_outline_near_m, d.look_outline_far_m, d.look_outline_lens_fade_m, 1.0)
		var own := ToonMaterials.outline_width_m(dist, d.look_outline_px, 1.0, 1080.0, d.look_outline_near_m, d.look_outline_far_m, d.look_outline_lens_fade_m, d.look_outline_fp_scale)
		assert_almost_eq(own, full * d.look_outline_fp_scale, 1e-6, "%.2f m: the player's own line is x%.1f" % [dist, d.look_outline_fp_scale])
	assert_eq(ToonMaterials.outline_width_m(d.look_outline_lens_fade_m * 0.5, d.look_outline_px, 1.0, 1080.0, d.look_outline_near_m, d.look_outline_far_m, d.look_outline_lens_fade_m, d.look_outline_fp_scale), 0.0, "inside the fade the hull is nothing")
	# Live: the Look values reach it as any hull's.
	Tuning.set_value(&"look_outline_fp_scale", 0.5)
	Tuning.set_value(&"look_outline_px", 5.0)
	var hull := p.rig.art_meshes()[0].material_overlay as ShaderMaterial
	assert_eq(hull.get_shader_parameter(&"fp_scale"), 0.5, "the F1 panel moves it live")
	assert_eq(hull.get_shader_parameter(&"width_px"), 5.0)


# --- The first-person view of the drawn art (row A9) --------------------------------------------


## test_humanoid_rig's first-person poses, as a camera and a setup: idle ahead; looking down 45
## and 60 degrees; jab, cross, hook and uppercut at their active frames; the block's guard; the
## knee in the hold; the front kick and the spin kick mid-turn (the view turned with it, and
## not); the haymaker's charge.
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


## The art measured against its proxies at one pose: A9's figures against FPView's proxies and
## against the proxies' own meshes ray-cast exactly (FPView models a cap as a flat ellipsoid and a
## capsule seen along its axis roughly, so it is looser than the primitives as drawn:
## M4-calls/P1-skin.md C6), and the share of the proxies' cells the art covers.
func _framing(rig: HumanoidRig, row: Dictionary) -> Dictionary:
	(row.setup as Callable).call(rig)
	var cam := _fp_camera(rig, row.pitch, row.yaw)
	var cmp := SkinnedView.compare_with_proxies(rig, cam)
	var exact := SkinnedView.compare_with_exact_proxies(rig, cam)
	var proxy_cells: float = cmp.proxy_share * cmp.cells
	return {
		label = row.label, cmp = cmp, exact = exact,
		coverage = (float(cmp.both) / proxy_cells) if proxy_cells >= 1.0 else 1.0,
	}


func _framing_line(f: Dictionary) -> String:
	var cmp: Dictionary = f.cmp
	var exact: Dictionary = f.exact
	return "%-40s art %5.1f%% proxies %5.1f%% differ %4.1f%% nearest %5.1f cm, covers %3.0f%% | exact: proxies %5.1f%% differ %4.1f%% nearest %5.1f cm" % [
			f.label, cmp.art_share * 100.0, cmp.proxy_share * 100.0, cmp.differ_share * 100.0, cmp.nearest * 100.0,
			f.coverage * 100.0, exact.proxy_share * 100.0, exact.differ_share * 100.0, exact.nearest * 100.0]


func test_the_arts_frame_like_their_proxies_in_every_first_person_pose() -> void:
	# The hero's art is held to the plan's row A9 (3% of the cells, 4 points of share, 2 cm
	# nearer) against the proxies FPView casts. The probe is a mannequin whose proportions are a
	# voxel remesh's, not the primitives': it is held to the bars below, which are what it does
	# today (a ratchet: a change that makes it worse fails), and every figure is printed, the plan's
	# bars it misses marked GATE for the hero's run.
	for entry: Dictionary in _arts():
		var rig := _rig(entry.art)
		var lines := PackedStringArray()
		var worst := {differ = 0.0, share = 0.0, nearest = 0.0, exact_nearest = 0.0, coverage = 1.0}
		for row: Dictionary in _view_poses():
			var f := _framing(rig, row)
			var cmp: Dictionary = f.cmp
			var gate := SkinnedView.framing_problems(cmp, row.label)
			lines.append(_framing_line(f) + ("  GATE" if not gate.is_empty() else ""))
			if entry.name == "hero":
				assert_eq(gate, PackedStringArray(), "%s: the plan's A9 against the proxies" % row.label)
				continue
			worst.differ = maxf(worst.differ, cmp.differ_share)
			worst.share = maxf(worst.share, absf(cmp.art_share - cmp.proxy_share))
			if not PROBE_SILHOUETTE_POSES.has(row.label):
				worst.nearest = maxf(worst.nearest, cmp.nearest)
				worst.exact_nearest = maxf(worst.exact_nearest, f.exact.nearest)
			if cmp.proxy_share >= PROBE_COVERAGE_FROM:
				worst.coverage = minf(worst.coverage, f.coverage)
		_lines("A9 framing, %s (the plan's bars: 3%% of the cells, 4 points of share, 2 cm)" % entry.name, lines)
		if entry.name == "probe":
			assert_lte(worst.differ, PROBE_DIFFER_MAX, "the probe differs from its proxies in at most %.0f%% of the cells (%.1f%%)" % [PROBE_DIFFER_MAX * 100.0, worst.differ * 100.0])
			assert_lte(worst.share, PROBE_SHARE_MAX, "and its share of the view is within %.0f points of theirs (%.1f)" % [PROBE_SHARE_MAX * 100.0, worst.share * 100.0])
			assert_lt(worst.nearest, PROBE_NEAREST_MAX_M, "and is never %.0f cm nearer the lens than FPView's proxies, which are loose (%.1f cm)" % [PROBE_NEAREST_MAX_M * 100.0, worst.nearest * 100.0])
			assert_lt(worst.exact_nearest, PROBE_EXACT_NEAREST_MAX_M, "and never %.0f cm nearer than the proxies' own meshes (%.1f cm; the plan's bar is 2 cm)" % [PROBE_EXACT_NEAREST_MAX_M * 100.0, worst.exact_nearest * 100.0])
			assert_gte(worst.coverage, PROBE_COVERAGE_MIN, "and covers at least %.0f%% of the proxies' cells where they fill 3%% of the view (%.0f%%)" % [PROBE_COVERAGE_MIN * 100.0, worst.coverage * 100.0])


func test_the_framing_check_has_teeth_an_art_with_a_bulge_fails_it() -> void:
	# A body whose forearms the skin carries 15 cm toward the lens: in the guard they cover far
	# more of the view than the proxies, and sit nearer by the bulge.
	var rig := _rig(_arts()[0].art)
	_pose(rig, &"block", 0.5)
	var cam := _fp_camera(rig)
	var good := SkinnedView.compare_with_proxies(rig, cam)
	var mi := _art_mesh(rig, &"ArtBody")
	var swollen := mi.mesh.duplicate() as ArrayMesh
	var arrays := swollen.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i: int in verts.size():
		verts[i] += normals[i] * 0.15
	arrays[Mesh.ARRAY_VERTEX] = verts
	var skin := mi.skin
	var flags := swollen.surface_get_format(0)
	swollen.clear_surfaces()
	swollen.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	mi.mesh = swollen
	mi.skin = skin
	SkinnedView.clear_cache()
	var bad := SkinnedView.compare_with_proxies(rig, cam)
	assert_gt(bad.nearest, good.nearest + 0.05, "a swollen body stands nearer the lens than the good one (%.1f cm against %.1f)" % [bad.nearest * 100.0, good.nearest * 100.0])
	assert_false(SkinnedView.framing_problems(bad, "swollen").is_empty(), "and the plan's A9 names it")


func test_the_visible_mesh_is_watertight_and_the_split_closes_at_the_seam() -> void:
	for entry: Dictionary in _arts():
		var rig := _rig(entry.art)
		var body := _art_mesh(rig, &"ArtBody")
		var upper := _art_mesh(rig, &"ArtBody__fp_hidden")
		assert_not_null(body, "%s: Body" % entry.name)
		assert_not_null(upper, "%s: Body__fp_hidden" % entry.name)
		var visible_edges := _edges(body)
		var hidden_edges := _edges(upper)
		var open := 0
		var over := 0
		for key: String in visible_edges:
			open += int(visible_edges[key] == 1)
			over += int(visible_edges[key] > 2)
		assert_eq(open, 0, "%s: Body has no open edge: every cut of the split is capped" % entry.name)
		# The hidden part is open where it was cut (the waist, the arms); each of its open edges is
		# an edge of the visible part, so together they close: no hollow where the lens sees both
		# (the KO view's).
		var hidden_open := 0
		var unmatched := 0
		for key: String in hidden_edges:
			if hidden_edges[key] != 1:
				continue
			hidden_open += 1
			unmatched += int(not visible_edges.has(key))
		print("ART-PLAYER watertight, %s: Body %d open edges and %d edges three or more triangles share (non-manifold; printed, not asserted: the probe has 23 where its caps meet); Body__fp_hidden %d open edges, %d not on Body's" % [entry.name, open, over, hidden_open, unmatched])
		assert_gt(hidden_open, 0, "%s: the hidden part is open where it was cut (the seam is real)" % entry.name)
		assert_eq(unmatched, 0, "%s: every open edge of the hidden part lies on the visible part (the seam closes)" % entry.name)


## The edges of `mi`'s mesh, welded by position (to a tenth of a millimeter), as `{key: triangles
## using it}`: a closed mesh uses every edge twice, an open rim once.
func _edges(mi: MeshInstance3D) -> Dictionary[String, int]:
	var arrays := (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var names := PackedStringArray()
	names.resize(verts.size())
	for i: int in verts.size():
		var k := Vector3i((verts[i] * 10000.0).round())
		names[i] = "%d,%d,%d" % [k.x, k.y, k.z]
	var uses: Dictionary[String, int] = {}
	for t: int in index.size() / 3:
		for e: int in 3:
			var a := names[index[t * 3 + e]]
			var b := names[index[t * 3 + (e + 1) % 3]]
			var key := "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]
			uses[key] = uses.get(key, 0) + 1
	return uses


# --- The gate's lens rules on the skinned art (slice-gate gap 7) ---------------------------------


## The test room with the player wearing `art` (the probe switch, set before the room builds: the
## hero's GLB, when it exists, is worn without it) and dummies at `posts` (player frame: x right, -z
## ahead). No dummy spars, the rest stand far away.
func _setup_room(posts: Array[Vector3], probe: bool = true) -> void:
	if is_instance_valid(room):
		room.queue_free()
		await _ticks(2)
	Tuning.data.look_player_art_probe = probe
	Tuning.data.dummy_health = 500.0
	room = ROOM.instantiate()
	room.set(&"with_presentation", false)
	add_child_autofree(room)
	await _ticks(2)
	player = room.get(&"player")
	player.input.scripted = true
	var dummies: Array[TrainingDummy] = []
	dummies.assign(room.get(&"dummies"))
	for i in dummies.size():
		var pos := player.global_position + player.global_basis * posts[i] if i < posts.size() else Vector3(30.0 + i * 3.0, 0.0, -30.0)
		var to_player := player.global_position - pos
		dummies[i].sparring = false
		dummies[i].set_post(pos, atan2(-to_player.x, -to_player.z), true)
	await _ticks(3)


func _dummies() -> Array[TrainingDummy]:
	var out: Array[TrainingDummy] = []
	out.assign(room.get(&"dummies"))
	return out


const ARM_BONES: Array[StringName] = [&"LeftLowerArm", &"RightLowerArm", &"LeftHand", &"RightHand"]


## What the real first-person view (FirstPersonCamera.view_from_eye(), from EyePoint itself) shows of
## the player's SKINNED art this tick: the nearest forearm or hand vertex to the lens, and the share of
## the view the own body covers (SkinnedView.hits(): the triangles the lens draws, in the drawn pose).
func _art_view_report() -> Dictionary:
	var cam := FirstPersonCamera.view_from_eye(player, player.get_eye_transform().origin)
	var lens := player.rig.global_transform.affine_inverse() * cam.origin
	var nearest_arm := INF
	for mi: MeshInstance3D in player.rig.art_meshes():
		for v: Vector3 in SkinnedView.bone_vertices(mi, player.rig, ARM_BONES):
			nearest_arm = minf(nearest_arm, v.distance_to(lens))
	var cells := SkinnedView.hits(player.rig, cam)
	var own := 0
	for cell: Dictionary in cells:
		own += int(not cell.is_empty())
	return {arm = nearest_arm, own = float(own) / cells.size()}


func test_a_hold_keeps_the_skinned_forearms_and_hands_off_the_lens_and_the_own_body_to_a_third() -> void:
	# test_grab_view's rules on the art the lens draws: through the grab, the hold, three knees and the
	# throw, no forearm or hand within 0.3 m of the lens and the own body over at most a third of the
	# view (the proxies' figures are the other test's; the art is the drawn pose).
	await _setup_room([Vector3(0, 0, -1.1)])
	assert_true(player.rig.has_art(), "the player wears the art")
	var victim := _dummies()[0]
	var worst := {arm = INF, own = 0.0, samples = 0}
	var watch := func(ticks: int, always: bool) -> void:
		for i in ticks:
			await _ticks(1)
			if i % 2 != 0:
				continue
			if not always and victim.state != CombatTypes.ActorState.GRABBED and player.current_move == null:
				continue
			var r := _art_view_report()
			worst.arm = minf(worst.arm, r.arm)
			worst.own = maxf(worst.own, r.own)
			worst.samples += 1
	player.input.push_press(&"GRAB", 2)
	await watch.call(30, false)
	assert_not_null(player.holding_enemy(), "grabbed")
	var knee := Tuning.get_move(&"knee")
	for n in Tuning.data.max_knees:
		player.input.push_press(&"P", 2)
		await watch.call(knee.total_frames() + 10, false)
	await watch.call(45, true)
	assert_true(await _wait_until(func() -> bool: return player.state == CombatTypes.ActorState.FREE and player.current_move == null, 60), "let go")
	player.input.push_press(&"GRAB", 2)
	await watch.call(30, false)
	assert_not_null(player.holding_enemy(), "regrabbed")
	player.input.push_press(&"K", 2)
	await watch.call(Tuning.get_move(&"throw").total_frames() + 10, false)
	print("ART-PLAYER hold, art drawn: %d samples; nearest forearm or hand %.3f m (the rule: %.1f m); own body at most %.1f%% of the view (the rule: %.0f%%)" % [
			worst.samples, worst.arm, ARM_CLEAR_M, worst.own * 100.0, OWN_SHARE_MAX * 100.0])
	assert_gt(worst.samples, 40, "the hold was sampled")
	assert_gte(worst.arm, ARM_CLEAR_M, "no forearm or hand within 0.3 m of the lens (nearest %.3f m)" % worst.arm)
	assert_lte(worst.own, OWN_SHARE_MAX, "the own body covers at most a third of the view (%.0f%%)" % (worst.own * 100.0))


## The KO view's lens rules, on the art: from the killing blow through the get-up, the camera updated each
## tick as the game does, with the head layer lifted the lens is `KO_BODY_CLEAR_M` or more from every vertex
## of the drawn body (the upper half's included), the own body covers at most a third of the view, and
## lifting or hiding the head layer pops at most a head's edge into view (the primitives' figures in test_ko_view).
func test_the_ko_view_keeps_its_distance_from_the_skinned_body_and_shows_all_of_it() -> void:
	await _setup_room([Vector3(0.0, 0.0, -0.95)])
	assert_true(player.rig.has_art())
	var cam := FirstPersonCamera.new()
	add_child_autofree(cam)
	cam.set_process(false)
	cam.player = player
	cam.update_camera(FRAME)
	var hidden_mesh := _art_mesh(player.rig, &"ArtBody__fp_hidden")
	var stats := {nearest = INF, own = 0.0, lifts = [], hides = [], previous_hides = true, shown_whole = false, samples = 0}
	player.health = 3.0
	_dummies()[0].start_jab()
	var ticks := roundi((Tuning.data.player_revive_s + 3.0) * 60.0)
	for i in ticks:
		await _ticks(1)
		cam.update_camera(FRAME)
		var hides := not cam.get_cull_mask_value(CombatTypes.VIS_FP_HIDDEN)
		var view := cam.view_transform()
		if cam.ko_view_weight() > 0.0 and i % 3 == 0:
			stats.samples += 1
			# The head layer as the lens draws it: lifted unless the camera hides it.
			if not hides:
				player.rig.first_person_body = false
			var cells := SkinnedView.hits(player.rig, view)
			player.rig.first_person_body = true
			var own := 0
			for cell: Dictionary in cells:
				own += int(not cell.is_empty())
			stats.own = maxf(stats.own, float(own) / cells.size())
			if not hides:
				var lens := player.rig.global_transform.affine_inverse() * view.origin
				for mi: MeshInstance3D in player.rig.art_meshes():
					for v: Vector3 in SkinnedView.skin_vertices(mi, player.rig):
						stats.nearest = minf(stats.nearest, v.distance_to(lens))
		if hides != stats.previous_hides:
			# The share of the view the hidden part holds at the moment the layer changes.
			player.rig.first_person_body = false
			var cells := SkinnedView.hits(player.rig, view)
			player.rig.first_person_body = true
			var share := 0
			for cell: Dictionary in cells:
				share += int(not cell.is_empty() and cell.mesh == hidden_mesh)
			(stats.hides if hides else stats.lifts).append(float(share) / cells.size())
		stats.previous_hides = hides
		stats.shown_whole = stats.shown_whole or (not hides and cam.ko_view_weight() >= 1.0)
	print("ART-PLAYER KO view, art drawn: %d samples; nearest vertex to the lens with the head layer lifted %.3f m (the rule: %.2f m); own body at most %.1f%% of the view; the head layer popping %s on the lift, %s on the hide" % [
			stats.samples, stats.nearest, KO_BODY_CLEAR_M, stats.own * 100.0, stats.lifts, stats.hides])
	assert_true(stats.shown_whole, "the whole body shows while the lens is out")
	assert_eq(stats.lifts.size(), 1, "the head layer is lifted once")
	assert_eq(stats.hides.size(), 1, "and hidden once")
	assert_gte(stats.nearest, KO_BODY_CLEAR_M, "with the head layer lifted nothing of the drawn body comes within %.2f m of the lens (%.3f m)" % [KO_BODY_CLEAR_M, stats.nearest])
	assert_lte(stats.own, OWN_SHARE_MAX, "the own body covers at most a third of the view (%.0f%%)" % (stats.own * 100.0))
	for share: float in stats.hides:
		assert_lte(share, 0.02, "hiding the head layer again pops no head, neck or shoulder out of view (%.1f%%)" % (share * 100.0))
	for share: float in stats.lifts:
		assert_lte(share, 0.08, "lifting it pops at most a head's edge into view (%.1f%%)" % (share * 100.0))
	assert_eq(player.state, CombatTypes.ActorState.FREE, "back on his feet")
	assert_true(player.rig.first_person_body, "the rig's own layers are as they were")
	assert_eq(hidden_mesh.layers, CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN))


## Layers of every mesh under the player's rig, by mesh.
func _layers() -> Dictionary:
	var layers := {}
	for mesh: MeshInstance3D in FPView.meshes_under(player.rig):
		layers[mesh] = mesh.layers
	return layers


## The share of the view the player's own body covers through `cam`, as the lens draws it: the
## primitives through FPView (the proxies of a rig with art stand for it), the art through SkinnedView
## (the triangles drawn, in the drawn pose).
func _own_share(cam: Transform3D) -> float:
	var n := 0
	if player.rig.has_art():
		var cells := SkinnedView.hits(player.rig, cam)
		for cell: Dictionary in cells:
			n += int(not cell.is_empty())
		return float(n) / cells.size()
	var cells := FPView.hits(room, cam, FPView.COLS)
	for mesh: MeshInstance3D in cells:
		n += int(mesh != null and player.rig.is_ancestor_of(mesh))
	return float(n) / cells.size()


## The real player (the room, the look along -Z) struck by `scene`'s attack number `attack` from
## `bearing_deg` (0 ahead, positive to the left, 180 behind) at `distance_m`: knocked down, down and up
## again, with a first-person camera of its own, current, updated each tick. `hide_torso` is the
## switch of feel question 3. Returns the worst share of the view the own body covers through the
## knockdown, the frames over a third and over a half, the frames of the knockdown, the layers before
## and after, and the player's states.
func _knockdown(scene: PackedScene, attack: int, bearing_deg: float, distance_m: float, probe: bool, hide_torso: bool) -> Dictionary:
	await _setup_room([], probe)
	Tuning.data.ai_frozen = true
	Tuning.data.god_mode = false
	Tuning.data.fp_knockdown_hide_torso = hide_torso
	add_child_autofree(StubDirector.new())
	var cam := FirstPersonCamera.new()
	add_child_autofree(cam)
	cam.set_process(false)
	cam.player = player
	cam.make_current()
	cam.update_camera(FRAME)
	var before := _layers()
	var enemy := scene.instantiate() as EnemyActor
	var to := Basis(Vector3.UP, deg_to_rad(bearing_deg)) * Vector3(0.0, 0.0, -distance_m)
	enemy.position = player.global_position + to
	enemy.rotation.y = atan2(to.x, to.z)
	room.add_child(enemy)
	await _ticks(10)
	enemy.force_attack(attack)
	var out := {worst = 0.0, frames = 0, over_third = 0, over_half = 0, states = {}, hit = false, before = before, hidden_frames = 0}
	var down := [CombatTypes.ActorState.LAUNCHED, CombatTypes.ActorState.DOWNED, CombatTypes.ActorState.GETUP]
	var hidden := CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN)
	for i in 300:
		await _ticks(1)
		cam.update_camera(FRAME)
		var state := player.state
		out.states[state] = true
		if state in down:
			var share := _own_share(cam.global_transform)
			out.frames += 1
			out.worst = maxf(out.worst, share)
			out.over_third += int(share > OWN_SHARE_MAX)
			out.over_half += int(share > 0.5)
			for mesh: MeshInstance3D in before:
				if before[mesh] != hidden and mesh.layers == hidden:
					out.hidden_frames += 1
					break
		if out.states.has(CombatTypes.ActorState.GETUP) and state == CombatTypes.ActorState.FREE:
			break
	out["after"] = _layers()
	out["camera"] = cam
	return out


## Feel question 3 (README M2 "until the art is in"; M4-plan section 8): the non-KO knockdown's belly slab.
## A face-down fall (the Kicker's sweep from behind) is the case that fills the view; measured with the
## switch off (today) and on, on the primitives and on the probe body.
func test_the_knockdown_slab_off_and_on_on_the_primitives_and_on_the_probe_body() -> void:
	var results := {}
	for probe: bool in [false, true]:
		for hide: bool in [false, true]:
			var r := await _knockdown(KICKER_SCENE, 1, 180.0, 1.2, probe, hide)
			results[[probe, hide]] = r
			print("ART-PLAYER knockdown slab, %s, fp_knockdown_hide_torso %s: %d frames, own body at most %.0f%% of the view, over a third for %d frames, over half for %d; torso hidden on %d frames" % [
					"probe body" if probe else "primitives", "on " if hide else "off", r.frames, r.worst * 100.0, r.over_third, r.over_half, r.hidden_frames])
			assert_gt(r.frames, 60, "the player went down and up")
			assert_true(r.states.has(CombatTypes.ActorState.DOWNED) and r.states.has(CombatTypes.ActorState.GETUP))
			if not hide:
				assert_eq(r.hidden_frames, 0, "off: the camera hides nothing, as in M3")
				assert_eq(r.after, r.before, "off: every mesh keeps its layers")
			else:
				assert_gt(r.hidden_frames, 40, "on: the torso is off the lens's layers while the body lies there")
				assert_eq(r.after, r.before, "on: and every mesh has its layers back after the get-up")
			(r.camera as Node).queue_free()
			await _ticks(1)
	# The slab as M3 had it: over half the view, for a second, on the primitives.
	assert_gt(results[[false, false]].worst, 0.5, "off, the primitives' belly fills over half the view (%.0f%%)" % (results[[false, false]].worst * 100.0))
	assert_gt(results[[false, false]].over_half, 20, "for more than 20 frames")
	assert_gt(results[[true, false]].worst, 0.2, "and the probe body's own slab is real too (%.0f%%)" % (results[[true, false]].worst * 100.0))
	for probe: bool in [false, true]:
		var on: Dictionary = results[[probe, true]]
		assert_lte(on.worst, OWN_SHARE_MAX, "%s, on: the own body covers at most a third of the view (%.0f%%)" % ["probe" if probe else "primitives", on.worst * 100.0])
		assert_eq(on.over_third, 0)


## The switch only touches a knockdown seen through this lens: a lens that is not the current camera
## (the side view, free fly) leaves the layers alone, so does a stand and a KO view, and with the switch
## off nothing ever does.
func test_the_torso_switch_leaves_other_views_and_the_ko_view_alone() -> void:
	await _setup_room([Vector3(0.0, 0.0, -0.95)], false)
	Tuning.data.fp_knockdown_hide_torso = true
	var cam := FirstPersonCamera.new()
	add_child_autofree(cam)
	cam.set_process(false)
	cam.player = player
	cam.update_camera(FRAME)
	var before := _layers()
	var hidden := CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN)
	# Standing: nothing.
	await _ticks(3)
	cam.make_current()
	cam.update_camera(FRAME)
	assert_eq(_layers(), before, "standing: nothing moves")
	# A knockdown seen by a lens that is not the one drawing: nothing.
	cam.clear_current()
	player.state = CombatTypes.ActorState.DOWNED
	cam.update_camera(FRAME)
	assert_eq(_layers(), before, "a camera that is not current leaves the torso on the default layer")
	cam.make_current()
	cam.update_camera(FRAME)
	var belly := player.rig.find_child("Belly", true, false) as MeshInstance3D
	assert_eq(belly.layers, hidden, "current, in the knockdown, the belly is off the lens's layers")
	# Another camera (the side view) switching in: the layers come back.
	cam.clear_current()
	cam.update_camera(FRAME)
	assert_eq(_layers(), before, "and when this lens stops drawing, they are back")
	# The KO view shows the body whole: dying brings the layers back at once.
	cam.make_current()
	cam.update_camera(FRAME)
	assert_eq(belly.layers, hidden)
	player.health = 0.0
	player.state = CombatTypes.ActorState.KO
	cam.update_camera(FRAME)
	assert_eq(belly.layers, before[belly], "the killing blow ends it: the KO view shows the whole body")
	# Standing again with the switch off: nothing.
	player.health = 100.0
	player.state = CombatTypes.ActorState.DOWNED
	Tuning.data.fp_knockdown_hide_torso = false
	cam.update_camera(FRAME)
	assert_eq(belly.layers, before[belly], "off: nothing")
	assert_false(TuningData.new().fp_knockdown_hide_torso, "the default is today's")
	player.state = CombatTypes.ActorState.FREE


# --- The act (tests/bot/acts/look_player_acts.gd) -------------------------------------------------


const LookPlayerActs := preload("res://tests/bot/acts/look_player_acts.gd")
## The longest the act may take in the tests (physics ticks): about 2500 played.
const ACT_MAX_TICKS := 5000


## The crowd bot that stops instead of quitting the test run's tree when its acts are done.
class QuietBot extends "res://tests/bot/crowd_bot.gd":
	var finished: bool = false

	func _quit() -> void:
		clear_enemies()
		finished = true


func test_the_act_lists_its_title_and_no_other_act_holds_it() -> void:
	var node := Node.new()
	autofree(node)
	var acts := LookPlayerActs.acts(node)
	assert_eq(acts.size(), 1)
	assert_eq(acts[0].title, "Look: my arms and legs")
	assert_true(String(acts[0].title).begins_with("Look: "))
	assert_eq(acts[0].cam, &"first_person")
	var bot := QuietBot.new()
	autofree(bot)
	var titles: Array[String] = []
	for act in bot._collect_acts():
		titles.append(act.title)
	assert_has(titles, "Look: my arms and legs", "the crowd bot loads the file by name")
	var mine := String(acts[0].title).to_lower()
	var holders := 0
	for title: String in titles:
		var other := title.to_lower()
		if other.contains(mine):
			holders += 1
		else:
			assert_false(mine.contains(other), "'%s' does not hold '%s'" % [mine, other])
	assert_eq(holders, 1, "a capture filter with the title picks one act")


func test_the_act_runs_headless_on_the_probe_body_with_its_marks_rectangles_and_the_ko_view() -> void:
	Tuning.reset_to_default()
	Tuning.set_value(&"waves_enabled", false)
	Tuning.data.look_player_art_probe = true
	GameInput.menu_open = false
	var bot := QuietBot.new()
	bot.act_filter = "Look: my arms and legs"
	add_child_autofree(bot)
	var at_start := {}
	for i in ACT_MAX_TICKS:
		await get_tree().physics_frame
		if at_start.is_empty() and bot.log_lines.size() > 0:
			for line: String in bot.log_lines:
				if line.contains(" start"):
					at_start = {caption_visible = bot.caption.visible, ai_frozen = Tuning.data.ai_frozen, god_mode = Tuning.data.god_mode}
					break
		if bot.finished:
			break
	assert_true(bot.finished, "the act finished within %d ticks" % ACT_MAX_TICKS)
	assert_false(at_start.get("caption_visible", true), "the caption is hidden during the act")
	assert_true(at_start.get("ai_frozen", false), "the AI is frozen")
	assert_true(at_start.get("god_mode", false), "god mode is on")
	assert_true(bot.caption.visible, "the caption is back when the act is over")
	var labels := {}
	var rects := 0
	var art_line := ""
	for line: String in bot.log_lines:
		if line.begins_with("LOOK-MARK pa1 "):
			labels[line.split(" ")[3]] = true
		elif line.begins_with("LOOK-RECT pa1 "):
			rects += 1
		elif line.begins_with("LOOK-PLAYER art "):
			art_line = line
	print("ART-PLAYER act: ", art_line, "; marks ", labels.keys(), "; rectangles ", rects)
	assert_true(art_line.begins_with("LOOK-PLAYER art probe "), "the log says which body it recorded: %s" % art_line)
	for label: String in ["start", "idle_level", "idle_down45", "idle_down65", "idle_arms", "guard", "haymaker_charge", "hold",
			"ko_before", "ko_view_out", "ko_view_held", "ko_back_in_the_eyes", "end"]:
		assert_true(labels.has(label), "the act marks %s" % label)
	for move: String in ["jab_1_strike", "jab_2_strike", "hook_strike", "uppercut_strike", "front_kick_strike", "spin_kick_strike", "knee_strike"]:
		assert_true(labels.has(move), "the act marks %s" % move)
	assert_gt(rects, 20, "and prints the rectangles of his hands and body")
	assert_true(Tuning.data.god_mode, "god mode is back on after the KO")
