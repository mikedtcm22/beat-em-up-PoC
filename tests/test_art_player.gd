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
## Real time the mixer is given to let go of the sounds at the end of the run (test_look_acts does the same).
const AUDIO_DRAIN_MS := 250
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
## What the hero's art does today (F-player-fix, after the legs were turned right way out, the arm cut made a dome and the torso its
## own mesh): the same ratchet as the probe's, at the hero's own figures, so a change that makes it worse fails. Against the plan's
## 3%, 4 points and 2 cm (the GATE lines) it differs in the block (8.4% of the cells, 8.4 points of share: the generated fists are
## rounder than the proxies' boxes, so the art covers less), the knee in the hold (4.6%), the haymaker's charge and the front kick
## (7.5 and 8.1 cm nearer than FPView's loose proxies; 7.5 and 4.4 against the proxies' own meshes): M4-calls/F-player-art.md C13 and its Fix round. The probe's coverage floor does not hold for the hero's knee
## (the art's thigh and the proxies' knee box are different shapes at 0.3 m).
## test_m4_done_when.gd's row A9 reads HERO_DIFFER_MAX, HERO_SHARE_MAX and HERO_NEAREST_MAX_M from here (they are public constants of
## this script), so the done-when's mirror cannot be looser than this test; today's figures are 8.4%, 8.4 points and 8.1 cm.
const HERO_DIFFER_MAX := 0.09
const HERO_SHARE_MAX := 0.09
const HERO_NEAREST_MAX_M := 0.09
const HERO_EXACT_NEAREST_MAX_M := 0.08
const HERO_COVERAGE_MIN := 0.40
## The near upper arm in the straight punches is no bigger on screen than M3's Elbow capsule: at most this share of the view more.
const ARM_SHARE_SLACK := 0.03
## The torso mesh of the hero's GLB (the belly and belt, what fp_knockdown_hide_torso hides on the art).
const TORSO_MESH := &"ArtBody__fp_torso"
## The hero's upper-arm mesh (the shoulder half of each upper arm: the haymaker and the uppercut show it, M6 D7).
const ARM_MESH := &"ArtBody__fp_arm"

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


func after_all() -> void:
	# A headless run is far ahead of the audio clock: give the mixer a moment to drop the sounds the
	# fights above made, or the exit reports their streams as resources still in use.
	OS.delay_msec(AUDIO_DRAIN_MS)


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


func test_the_hero_is_four_meshes_the_belly_and_belt_on_the_visible_layer_apart_from_the_legs() -> void:
	var hero := PlayerCharacter.worn_art(load(PLAYER_ART) as CharacterArt)
	if hero == null:
		return
	var rig := _rig(hero)
	assert_eq(rig.art_meshes().size(), 4, "Body, Body__fp_hidden, Body__fp_torso and Body__fp_arm")
	var body := _art_mesh(rig, &"ArtBody")
	var torso := _art_mesh(rig, TORSO_MESH)
	var hidden := _art_mesh(rig, &"ArtBody__fp_hidden")
	var arm := _art_mesh(rig, ARM_MESH)
	assert_not_null(torso, "the torso mesh is there")
	assert_not_null(arm, "the upper-arm mesh is there")
	assert_eq(arm.layers, CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN), "the upper arms start hidden from the lens: only the moves that say fp_show_upper_arm lift them")
	assert_true(arm.get_meta(SkinnedArt.FP_HIDDEN_META, false), "and carry the hidden meta, so the knockdown view does not take them for the visible body")
	assert_eq(arm.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	assert_eq(torso.layers, CombatTypes.bit(CombatTypes.VIS_DEFAULT), "the belly and belt are on the visible layer: the lens looking down sees them")
	assert_eq(body.layers, torso.layers)
	assert_eq(hidden.layers, CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN))
	assert_eq(torso.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	var torso_tris: int = ((torso.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	var body_tris: int = ((body.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	var hidden_tris: int = ((hidden.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	var arm_tris: int = ((arm.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	print("ART-PLAYER hero meshes: Body %d, Body__fp_hidden %d, Body__fp_torso %d, Body__fp_arm %d triangles (%d of the 30000)" % [body_tris, hidden_tris, torso_tris, arm_tris, body_tris + hidden_tris + torso_tris + arm_tris])
	assert_lte(body_tris + hidden_tris + torso_tris + arm_tris, 30000, "the budget holds with the fourth mesh")
	# the camera takes only the torso mesh for the knockdown view
	var p := await _player(false)
	var cam := FirstPersonCamera.new()
	add_child_autofree(cam)
	cam.player = p
	var found := cam._find_torso_meshes()
	var names: Array[StringName] = []
	for mesh: MeshInstance3D in found:
		names.append(mesh.name)
	assert_has(names, TORSO_MESH, "the camera's knockdown view hides the belly and belt mesh")
	assert_does_not_have(names, &"ArtBody", "and leaves the legs and forearms")
	assert_does_not_have(names, ARM_MESH, "and the upper arms, which are the hidden layer's and not the visible body's")


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
	# Neither art meets the plan's row A9 (3% of the cells, 4 points of share, 2 cm nearer) against FPView's loose proxies: the probe
	# is a mannequin whose proportions are a voxel remesh's, the hero is the generated body (its block covers 7 points less than the
	# proxies' boxes, its haymaker and front kick are 7-8 cm nearer). Each is held to what it does today (a ratchet: a change that
	# makes it worse fails), and every figure is printed, the plan's bars it misses marked GATE.
	for entry: Dictionary in _arts():
		var hero: bool = entry.name == "hero"
		var rig := _rig(entry.art)
		var lines := PackedStringArray()
		var worst := {differ = 0.0, share = 0.0, nearest = 0.0, exact_nearest = 0.0, coverage = 1.0}
		for row: Dictionary in _view_poses():
			var f := _framing(rig, row)
			var cmp: Dictionary = f.cmp
			var gate := SkinnedView.framing_problems(cmp, row.label)
			lines.append(_framing_line(f) + ("  GATE" if not gate.is_empty() else ""))
			worst.differ = maxf(worst.differ, cmp.differ_share)
			worst.share = maxf(worst.share, absf(cmp.art_share - cmp.proxy_share))
			if hero or not PROBE_SILHOUETTE_POSES.has(row.label):
				worst.nearest = maxf(worst.nearest, cmp.nearest)
				worst.exact_nearest = maxf(worst.exact_nearest, f.exact.nearest)
			if cmp.proxy_share >= PROBE_COVERAGE_FROM:
				worst.coverage = minf(worst.coverage, f.coverage)
		_lines("A9 framing, %s (the plan's bars: 3%% of the cells, 4 points of share, 2 cm)" % entry.name, lines)
		var limits := {
			differ = HERO_DIFFER_MAX if hero else PROBE_DIFFER_MAX,
			share = HERO_SHARE_MAX if hero else PROBE_SHARE_MAX,
			nearest = HERO_NEAREST_MAX_M if hero else PROBE_NEAREST_MAX_M,
			exact_nearest = HERO_EXACT_NEAREST_MAX_M if hero else PROBE_EXACT_NEAREST_MAX_M,
			coverage = HERO_COVERAGE_MIN if hero else PROBE_COVERAGE_MIN,
		}
		assert_lte(worst.differ, limits.differ, "%s differs from its proxies in at most %.0f%% of the cells (%.1f%%)" % [entry.name, limits.differ * 100.0, worst.differ * 100.0])
		assert_lte(worst.share, limits.share, "and its share of the view is within %.0f points of theirs (%.1f)" % [limits.share * 100.0, worst.share * 100.0])
		assert_lt(worst.nearest, limits.nearest, "and is never %.0f cm nearer the lens than FPView's proxies, which are loose (%.1f cm)" % [limits.nearest * 100.0, worst.nearest * 100.0])
		assert_lt(worst.exact_nearest, limits.exact_nearest, "and never %.0f cm nearer than the proxies' own meshes (%.1f cm; the plan's bar is 2 cm)" % [limits.exact_nearest * 100.0, worst.exact_nearest * 100.0])
		assert_gte(worst.coverage, limits.coverage, "and covers at least %.0f%% of the proxies' cells where they fill 3%% of the view (%.0f%%)" % [limits.coverage * 100.0, worst.coverage * 100.0])


## The near upper arm in the straight punches. M3 keeps the elbow end of the upper arm on purpose (placeholder_body.gd, FP_HIDDEN_PARTS:
## the arm comes in from the edge of the view as sleeve, forearm and fist), so the probe's and the primitives' Elbow capsule fill the same
## quarter of the view; the hero's cut is a dome of that capsule's profile. Printed for the level view and for the 20 degrees down the
## recordings use: the art's share of the view in cells whose nearest drawn face belongs to an UpperArm, beside the proxies' Elbow share.
func test_the_near_upper_arm_in_the_punches_fills_no_more_of_the_view_than_the_primitives_elbow() -> void:
	for entry: Dictionary in _arts():
		var rig := _rig(entry.art)
		var lines := PackedStringArray()
		for pitch: float in [0.0, -20.0]:
			var line := "view %3.0f deg:" % pitch
			for row: Dictionary in _view_poses().slice(3, 7):
				(row.setup as Callable).call(rig)
				var cam := _fp_camera(rig, pitch, 0.0)
				var cells := SkinnedView.hits(rig, cam)
				var upper := 0
				for cell: Dictionary in cells:
					upper += int(not cell.is_empty() and String(cell.bone).ends_with("UpperArm"))
				var elbow := 0
				var proxies := FPView.hits(rig, cam, FPView.COLS)
				for mesh: MeshInstance3D in proxies:
					elbow += int(mesh != null and String(mesh.name).ends_with("Elbow"))
				var art_share := float(upper) / cells.size()
				var proxy_share := float(elbow) / proxies.size()
				line += "  %s %.1f%% (the primitives' Elbow %.1f%%)" % [String(row.label).trim_suffix(" active"), art_share * 100.0, proxy_share * 100.0]
				assert_lte(art_share, proxy_share + ARM_SHARE_SLACK, "%s, %s at %.0f deg: the near upper arm fills no more than %.0f points beyond M3's Elbow capsule (%.1f%% against %.1f%%)" % [entry.name, row.label, pitch, ARM_SHARE_SLACK * 100.0, art_share * 100.0, proxy_share * 100.0])
			lines.append(line)
		_lines("own upper arm in the straight punches, %s" % entry.name, lines)


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
		# The hero's belly and belt are a mesh of their own: closed on its own, and with the body they close the hidden part's waist.
		var torso := _art_mesh(rig, TORSO_MESH)
		var torso_open := 0
		if torso != null:
			var torso_edges := _edges(torso)
			for key: String in torso_edges:
				torso_open += int(torso_edges[key] == 1)
				visible_edges[key] = visible_edges.get(key, 0) + torso_edges[key]
			assert_eq(torso_open, 0, "%s: the torso has no open edge: its two cuts are capped" % entry.name)
		var open := 0
		var over := 0
		for key: String in visible_edges:
			open += int(visible_edges[key] == 1)
			over += int(visible_edges[key] > 2)
		assert_eq(open, 0, "%s: Body has no open edge: every cut of the split is capped" % entry.name)
		# The hero's upper arms (the shoulder half of each) are a mesh of their own, closed on its own; the hidden part's cut at the
		# shoulder side of them lies on its edges.
		var arm := _art_mesh(rig, ARM_MESH)
		var closing_edges := visible_edges.duplicate()
		if arm != null:
			var arm_edges := _edges(arm)
			var arm_open := 0
			for key: String in arm_edges:
				arm_open += int(arm_edges[key] == 1)
				closing_edges[key] = closing_edges.get(key, 0) + arm_edges[key]
			assert_eq(arm_open, 0, "%s: the upper-arm mesh has no open edge: both its cuts are capped" % entry.name)
		# The hidden part is open where it was cut (the waist, the arms); each of its open edges is
		# an edge of the visible part, so together they close: no hollow where the lens sees both
		# (the KO view's).
		var hidden_open := 0
		var unmatched := 0
		for key: String in hidden_edges:
			if hidden_edges[key] != 1:
				continue
			hidden_open += 1
			unmatched += int(not closing_edges.has(key))
		print("ART-PLAYER watertight, %s: Body %d open edges and %d edges three or more triangles share (non-manifold; printed, not asserted: the probe has some where its caps meet)%s; Body__fp_hidden %d open edges, %d not on Body's%s" % [entry.name, open, over,
				(", torso %d open edges" % torso_open) if torso != null else "", hidden_open, unmatched, " or the torso's" if torso != null else ""])
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
	# view (the proxies' figures are the other test's; the art is the drawn pose). The probe body, and
	# the hero's art when its GLB exists.
	for entry: Dictionary in _arts():
		await _check_hold(entry.name == "probe", entry.name)


func _check_hold(probe: bool, what: String) -> void:
	await _setup_room([Vector3(0, 0, -1.1)], probe)
	assert_true(player.rig.has_art(), "%s: the player wears the art" % what)
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
	print("ART-PLAYER hold, %s drawn: %d samples; nearest forearm or hand %.3f m (the rule: %.1f m); own body at most %.1f%% of the view (the rule: %.0f%%)" % [
			what, worst.samples, worst.arm, ARM_CLEAR_M, worst.own * 100.0, OWN_SHARE_MAX * 100.0])
	assert_gt(worst.samples, 40, "%s: the hold was sampled" % what)
	assert_gte(worst.arm, ARM_CLEAR_M, "%s: no forearm or hand within 0.3 m of the lens (nearest %.3f m)" % [what, worst.arm])
	assert_lte(worst.own, OWN_SHARE_MAX, "%s: the own body covers at most a third of the view (%.0f%%)" % [what, worst.own * 100.0])


## The KO view's lens rules, on the art: from the killing blow through the get-up, the camera updated each
## tick as the game does, with the head layer lifted the lens is `KO_BODY_CLEAR_M` or more from every vertex
## of the drawn body (the upper half's included), the own body covers at most a third of the view, and
## lifting or hiding the head layer pops at most a head's edge into view (the primitives' figures in test_ko_view).
func test_the_ko_view_keeps_its_distance_from_the_skinned_body_and_shows_all_of_it() -> void:
	for entry: Dictionary in _arts():
		await _check_ko_view(entry.name == "probe", entry.name)


func _check_ko_view(probe: bool, what: String) -> void:
	await _setup_room([Vector3(0.0, 0.0, -0.95)], probe)
	assert_true(player.rig.has_art(), "%s: the player wears the art" % what)
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
	print("ART-PLAYER KO view, %s drawn: %d samples; nearest vertex to the lens with the head layer lifted %.3f m (the rule: %.2f m); own body at most %.1f%% of the view; the head layer popping %s on the lift, %s on the hide" % [
			what, stats.samples, stats.nearest, KO_BODY_CLEAR_M, stats.own * 100.0, stats.lifts, stats.hides])
	assert_true(stats.shown_whole, "%s: the whole body shows while the lens is out" % what)
	assert_eq(stats.lifts.size(), 1, "%s: the head layer is lifted once" % what)
	assert_eq(stats.hides.size(), 1, "%s: and hidden once" % what)
	assert_gte(stats.nearest, KO_BODY_CLEAR_M, "%s: with the head layer lifted nothing of the drawn body comes within %.2f m of the lens (%.3f m)" % [what, KO_BODY_CLEAR_M, stats.nearest])
	assert_gte(stats.nearest, Tuning.data.ko_view_clearance_m, "%s: nor within the camera's own ko_view_clearance_m, which it tests the proxies against" % what)
	assert_lte(stats.own, OWN_SHARE_MAX, "%s: the own body covers at most a third of the view (%.0f%%)" % [what, stats.own * 100.0])
	for share: float in stats.hides:
		assert_lte(share, 0.02, "%s: hiding the head layer again pops no head, neck or shoulder out of view (%.1f%%)" % [what, share * 100.0])
	for share: float in stats.lifts:
		assert_lte(share, 0.08, "%s: lifting it pops at most a head's edge into view (%.1f%%)" % [what, share * 100.0])
	assert_eq(player.state, CombatTypes.ActorState.FREE, "%s: back on his feet" % what)
	assert_true(player.rig.first_person_body, "%s: the rig's own layers are as they were" % what)
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
	var out := {worst = 0.0, frames = 0, over_third = 0, over_half = 0, states = {}, hit = false, before = before, hidden_frames = 0, art = player.rig.has_art()}
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
					"probe body" if probe else ("the hero's art" if r.art else "primitives"), "on " if hide else "off", r.frames, r.worst * 100.0, r.over_third, r.over_half, r.hidden_frames])
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
	# The slab as M3 had it: over half the view, for a second, on the primitives (which the player wears
	# with the probe switch off until the hero's GLB exists).
	if not results[[false, false]].art:
		assert_gt(results[[false, false]].worst, 0.5, "off, the primitives' belly fills over half the view (%.0f%%)" % (results[[false, false]].worst * 100.0))
		assert_gt(results[[false, false]].over_half, 20, "for more than 20 frames")
	assert_gt(results[[true, false]].worst, 0.2, "and the probe body's own slab is real too (%.0f%%)" % (results[[true, false]].worst * 100.0))
	for probe: bool in [false, true]:
		var on: Dictionary = results[[probe, true]]
		assert_lte(on.worst, OWN_SHARE_MAX, "%s, on: the own body covers at most a third of the view (%.0f%%)" % ["probe" if probe else ("hero" if on.art else "primitives"), on.worst * 100.0])
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


func test_the_acts_list_their_titles_and_no_other_act_holds_one() -> void:
	var node := Node.new()
	autofree(node)
	var acts := LookPlayerActs.acts(node)
	var mine: Array[String] = []
	assert_eq(acts.size(), 2)
	assert_eq(acts[0].title, "Look: my arms and legs")
	assert_eq(acts[1].title, "Look: my knockdown")
	for act in acts:
		assert_true(String(act.title).begins_with("Look: "))
		assert_eq(act.cam, &"first_person")
		assert_true((act.fn as Callable).is_valid())
		mine.append(String(act.title).to_lower())
	var bot := QuietBot.new()
	autofree(bot)
	var titles: Array[String] = []
	for act in bot._collect_acts():
		titles.append(act.title)
	for title: String in mine:
		assert_has(titles.map(func(t: String) -> String: return t.to_lower()), title, "the crowd bot loads the file by name")
		var holders := 0
		for other_title: String in titles:
			var other := other_title.to_lower()
			if other.contains(title):
				holders += 1
			else:
				assert_false(title.contains(other), "'%s' does not hold '%s'" % [title, other])
		assert_eq(holders, 1, "a capture filter with '%s' picks one act" % title)


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


func test_the_knockdown_act_runs_headless_and_the_torso_switch_is_in_its_log() -> void:
	for hide: bool in [false, true]:
		Tuning.reset_to_default()
		Tuning.set_value(&"waves_enabled", false)
		Tuning.data.look_player_art_probe = true
		Tuning.data.fp_knockdown_hide_torso = hide
		GameInput.menu_open = false
		var bot := QuietBot.new()
		bot.act_filter = "Look: my knockdown"
		add_child_autofree(bot)
		for i in ACT_MAX_TICKS:
			await get_tree().physics_frame
			if bot.finished:
				break
		assert_true(bot.finished, "the act finished")
		var labels := {}
		var switch_line := ""
		for line: String in bot.log_lines:
			if line.begins_with("LOOK-MARK pa2 "):
				labels[line.split(" ")[3]] = true
			elif line.begins_with("LOOK-PLAYER fp_knockdown_hide_torso"):
				switch_line = line
		assert_eq(switch_line, "LOOK-PLAYER fp_knockdown_hide_torso %s" % hide, "the log says which way the switch was")
		for label: String in ["start", "standing", "state_downed", "down_t020", "down_t045", "down_t070", "state_getup", "end"]:
			assert_true(labels.has(label), "hide %s: the act marks %s" % [hide, label])
		assert_true(Tuning.data.god_mode)
		bot.queue_free()
		await get_tree().physics_frame


# --- The near upper arm (M6 D7, ARM) ---------------------------------------------------------

const MOVES_DIR := "res://game/combat/moves/"


## The moves that say fp_show_upper_arm: the haymaker and the uppercut, no other (every .tres of the catalog is read).
func test_only_the_haymaker_and_the_uppercut_show_the_upper_arm() -> void:
	var showing: Array[StringName] = []
	for file: String in DirAccess.get_files_at(MOVES_DIR):
		if not file.ends_with(".tres"):
			continue
		var move := load(MOVES_DIR + file) as MoveData
		if move != null and move.fp_show_upper_arm:
			showing.append(move.id)
	showing.sort()
	assert_eq(showing, [&"haymaker", &"uppercut"] as Array[StringName], "the straight punches and the hook keep M5's view: the arm starts at the elbow's dome")
	assert_true(TuningData.new().look_near_arm, "look_near_arm defaults to the new view")
	assert_eq(Tuning._property_info(Tuning.tuning_properties(), &"look_near_arm").group, "Debug", "in the Debug group (the A/B)")
	assert_false(Tuning.is_preset_property(&"look_near_arm"), "which presets skip")


func _lens_on(p: PlayerCharacter) -> FirstPersonCamera:
	var cam := FirstPersonCamera.new()
	add_child_autofree(cam)
	cam.set_process(false)
	cam.player = p
	cam.current = true
	cam.update_camera(FRAME)
	return cam


## Whether the lens `cam` draws `mesh` (a layer of the mesh in its cull mask).
func _draws(cam: Camera3D, mesh: MeshInstance3D) -> bool:
	return (mesh.layers & cam.cull_mask) != 0


func test_the_first_person_lens_draws_the_upper_arms_only_while_the_haymaker_or_the_uppercut_runs() -> void:
	var hero := PlayerCharacter.worn_art(load(PLAYER_ART) as CharacterArt)
	if hero == null:
		return
	var p := await _player(false)
	var arm := _art_mesh(p.rig, ARM_MESH)
	var body := _art_mesh(p.rig, &"ArtBody")
	assert_not_null(arm, "the hero wears the upper-arm mesh")
	if arm == null:
		return
	var cam := _lens_on(p)
	assert_false(_draws(cam, arm), "standing: the lens does not draw the upper arms")
	assert_true(_draws(cam, body), "and draws Body")
	for id: StringName in [&"haymaker", &"uppercut"]:
		var move := load(MOVES_DIR + "%s.tres" % id) as MoveData
		p.start_move(move)
		cam.update_camera(FRAME)
		assert_true(_draws(cam, arm), "%s running: the lens draws the upper arms" % id)
		assert_eq(arm.layers, CombatTypes.bit(CombatTypes.VIS_DEFAULT), "%s: on the default layer" % id)
		p._enter_state(CombatTypes.ActorState.FREE)
		cam.update_camera(FRAME)
		assert_false(_draws(cam, arm), "%s over: hidden again" % id)
		assert_eq(arm.layers, CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN), "%s over: back on the hidden layer" % id)
	for id: StringName in [&"jab_1", &"jab_2", &"hook", &"front_kick", &"knee"]:
		p.start_move(load(MOVES_DIR + "%s.tres" % id) as MoveData)
		cam.update_camera(FRAME)
		assert_false(_draws(cam, arm), "%s running: the upper arms stay hidden" % id)
		p._enter_state(CombatTypes.ActorState.FREE)
	# the switch: off is M5's view
	Tuning.data.look_near_arm = false
	p.start_move(load(MOVES_DIR + "haymaker.tres") as MoveData)
	cam.update_camera(FRAME)
	assert_false(_draws(cam, arm), "look_near_arm off: the haymaker keeps the arm hidden")
	Tuning.data.look_near_arm = true
	cam.update_camera(FRAME)
	assert_true(_draws(cam, arm), "and on again, the next frame draws it")
	# a lens that is not the current camera puts the layers back (the side view took over mid-move)
	cam.current = false
	cam.update_camera(FRAME)
	assert_eq(arm.layers, CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN), "the lens that is not current leaves the layers as the rig set them")
	# a first-person lens swapped off the player mid-move restores too
	cam.current = true
	cam.update_camera(FRAME)
	assert_true(_draws(cam, arm))
	cam.player = null
	assert_eq(arm.layers, CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN), "a new player puts the arm back on the hidden layer")


func test_the_side_view_and_free_fly_always_draw_the_upper_arms() -> void:
	var hero := PlayerCharacter.worn_art(load(PLAYER_ART) as CharacterArt)
	if hero == null:
		return
	var p := await _player(false)
	var arm := _art_mesh(p.rig, ARM_MESH)
	assert_not_null(arm)
	if arm == null:
		return
	var side := Camera3D.new()
	add_child_autofree(side)
	var cam := _lens_on(p)
	assert_true(_draws(side, arm), "standing: a camera with the default mask draws the arms (the side view, free fly)")
	p.start_move(load(MOVES_DIR + "haymaker.tres") as MoveData)
	cam.update_camera(FRAME)
	assert_true(_draws(side, arm), "and during the haymaker")
	p._enter_state(CombatTypes.ActorState.FREE)
	cam.update_camera(FRAME)
	assert_true(_draws(side, arm), "and after it")
	assert_true(arm.is_visible_in_tree(), "the arm mesh is never switched off: it casts the shadow the player sees")
