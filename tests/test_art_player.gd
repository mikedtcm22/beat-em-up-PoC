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
