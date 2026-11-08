extends GutTest
## LD-INK's rig, headless: the shaders are swapped in place onto a character's materials, the key and the
## hatching reach them, characters go on twos (a hold frame repeats the stored pose, the next draw frame
## stores a new one), the flash and speed lines fire on a finisher and not on a light hit, the comic effects
## hide, and the game's edge quad is turned off.

const LOOK_PATH := "res://video/look/street_night/ink.tres"


## A rig stand-in for the nodes that only need the output frame.
class FrameSource extends Node:
	var frame: int = 0


	func output_frame() -> int:
		return frame


func _look() -> VideoInkLook:
	return (load(LOOK_PATH) as VideoInkLook).duplicate()


## A level stand-in with one character-like mesh in the rig group: a toon material and its hull.
func _make_level() -> Dictionary:
	var level := Node3D.new()
	add_child_autofree(level)
	var skeleton := Skeleton3D.new()
	skeleton.add_bone("Root")
	skeleton.add_bone("Arm")
	skeleton.set_bone_parent(1, 0)
	level.add_child(skeleton)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var material := ToonMaterials.character(Color(0.6, 0.5, 0.4), true, false)
	var hull := ToonMaterials.outline_for_part(PlaceholderBody.Shape.BOX)
	if hull == null:
		hull = ToonMaterials.outline(false)
	mesh.material_override = material
	mesh.material_overlay = hull
	skeleton.add_child(mesh)
	mesh.add_to_group(HumanoidRig.ART_GROUP)
	var camera := Camera3D.new()
	level.add_child(camera)
	camera.make_current()
	return {level = level, skeleton = skeleton, mesh = mesh, material = material, hull = hull, camera = camera}


func test_apply_swaps_the_shaders_in_place_and_is_idempotent() -> void:
	var scene := _make_level()
	var look := _look()
	look.screen_ink = false
	look.post_enabled = false
	look.apply(scene.level)
	look.apply(scene.level)
	var rigs: Array[Node] = scene.level.find_children("CineInkRig", "", false, false)
	assert_eq(rigs.size(), 1, "apply() adds one rig, however often it is called")
	var rig := rigs[0] as CineInkRig
	await wait_process_frames(2)
	var material: ShaderMaterial = scene.material
	assert_eq(material.shader.resource_path, "res://video/shaders/cine_toon.gdshader", "the character material has the cine toon")
	assert_eq((scene.mesh as MeshInstance3D).material_override, material, "in place: the very same material object")
	assert_eq(material.get_shader_parameter(&"cine_shadow"), look.shadow_color, "the shadow hue is the location's")
	assert_not_null(material.get_shader_parameter(&"hatch_tex"), "the hatching map is set")
	var hull: ShaderMaterial = scene.hull
	assert_eq(hull.shader.resource_path, "res://video/shaders/cine_outline.gdshader", "the hull has the cine outline")
	assert_eq(hull.get_shader_parameter(&"ink"), look.ink_color, "tinted to the scene's ink")
	assert_eq(hull.get_shader_parameter(&"width_px"), look.hull_px, "at the look's width")
	assert_true(material.get_shader_parameter(&"key_dir_view") is Vector3, "the key's view-space direction reaches the paint")
	assert_true(is_instance_valid(rig), "the rig lives")


func test_sketch_mode_chains_jittered_passes_and_reseeds_at_12_fps() -> void:
	var scene := _make_level()
	var look := _look()
	look.screen_ink = false
	look.post_enabled = false
	look.sketch_mode = true
	look.sketch_extra_passes = 2
	look.apply(scene.level)
	var rig := scene.level.get_node(^"CineInkRig") as CineInkRig
	var counter := FrameSource.new()
	add_child_autofree(counter)
	rig.frame_source = func() -> int: return counter.frame
	counter.frame = 0
	await wait_process_frames(2)
	var hull: ShaderMaterial = scene.hull
	var pass_two := hull.next_pass as ShaderMaterial
	assert_not_null(pass_two, "a second hull pass is chained")
	assert_gt(float(pass_two.get_shader_parameter(&"jitter_px")), 0.0, "and it is jittered")
	assert_not_null(pass_two.next_pass, "and a third")
	counter.frame = 4
	await wait_process_frames(2)
	var seed_a: float = hull.get_shader_parameter(&"boil_seed")
	counter.frame = 5
	await wait_process_frames(2)
	assert_eq(hull.get_shader_parameter(&"boil_seed"), seed_a, "frames 4 and 5 share a boil seed (12 fps from 24)")
	counter.frame = 6
	await wait_process_frames(2)
	assert_ne(hull.get_shader_parameter(&"boil_seed"), seed_a, "frame 6 has a new one")


func test_twos_hold_the_stored_pose_on_the_odd_frame() -> void:
	var scene := _make_level()
	var skeleton: Skeleton3D = scene.skeleton
	var source := FrameSource.new()
	add_child_autofree(source)
	var twos := CineTwos.new()
	twos.rig = source
	twos.hold = 2
	add_child_autofree(twos)
	skeleton.set_bone_pose_position(1, Vector3(1, 0, 0))
	source.frame = 0
	await wait_process_frames(1)
	# The simulation moves the arm; frame 1 is a hold frame: the stored pose comes back.
	skeleton.set_bone_pose_position(1, Vector3(2, 0, 0))
	source.frame = 1
	await wait_process_frames(1)
	assert_eq(skeleton.get_bone_pose_position(1), Vector3(1, 0, 0), "a hold frame draws the pose of the draw frame")
	skeleton.set_bone_pose_position(1, Vector3(3, 0, 0))
	source.frame = 2
	await wait_process_frames(1)
	assert_eq(skeleton.get_bone_pose_position(1), Vector3(3, 0, 0), "the next draw frame draws the new pose")
	twos.enabled = false
	skeleton.set_bone_pose_position(1, Vector3(4, 0, 0))
	source.frame = 3
	await wait_process_frames(1)
	assert_eq(skeleton.get_bone_pose_position(1), Vector3(4, 0, 0), "switched off, nothing is held")


func test_flash_and_lines_fire_on_a_finisher_only() -> void:
	var scene := _make_level()
	var look := _look()
	look.screen_ink = false
	look.post_enabled = false
	look.apply(scene.level)
	var rig := scene.level.get_node(^"CineInkRig") as CineInkRig
	var quad := rig.get_node(^"CineCues/CineCueQuad") as MeshInstance3D
	await wait_process_frames(2)
	assert_false(quad.visible, "no cue at rest")
	var hit := HitInfo.new()
	hit.tier = CombatTypes.HitTier.LIGHT
	CombatEvents.hit_landed.emit(hit)
	await wait_process_frames(2)
	assert_false(quad.visible, "a light hit fires nothing")
	hit.tier = CombatTypes.HitTier.FINISHER
	hit.contact_point = Vector3(0, 1, -2)
	CombatEvents.hit_landed.emit(hit)
	await wait_process_frames(2)
	assert_true(quad.visible, "a finisher fires the flash and speed lines inside the 3D scene")
	var material := quad.material_override as ShaderMaterial
	assert_gt(float(material.get_shader_parameter(&"flash")), 0.0, "the flash is on")
	assert_gt(float(material.get_shader_parameter(&"lines")), 0.0, "and the lines")
	var blocked := HitInfo.new()
	blocked.tier = CombatTypes.HitTier.FINISHER
	blocked.blocked = true
	rig.look.flash_frames = false
	rig.look.speed_lines = false
	await wait_physics_frames(look.lines_ticks + 2)
	CombatEvents.hit_landed.emit(blocked)
	await wait_process_frames(2)
	assert_false(quad.visible, "a blocked hit, and a look with the cues off, fire nothing")


func test_comic_effects_are_hidden_and_the_edge_quad_is_off() -> void:
	var scene := _make_level()
	var vfx := Node3D.new()
	vfx.add_to_group(&"vfx_director")
	scene.level.add_child(vfx)
	var post := LookPost.new()
	scene.level.add_child(post)
	assert_true(post.edge_quad().visible, "the game's edge quad is on to begin with")
	var look := _look()
	look.screen_ink = false
	look.post_enabled = false
	look.hide_comic_fx = true
	look.apply(scene.level)
	await wait_process_frames(3)
	assert_false(post.edge_quad().visible, "the game's constant-width edge quad is turned off")
	assert_false(vfx.visible, "the VfxDirector (the comic words and starbursts' parent) is hidden")
	var game := _look()
	game.hide_comic_fx = false
	vfx.visible = true
	game.screen_ink = false
	game.post_enabled = false
	var second := _make_level()
	var vfx2 := Node3D.new()
	vfx2.add_to_group(&"vfx_director")
	second.level.add_child(vfx2)
	vfx.remove_from_group(&"vfx_director")
	game.apply(second.level)
	await wait_process_frames(3)
	assert_true(vfx2.visible, "with the switch off the game's own comic effects stay")


func test_the_key_is_found_from_a_lamp_and_hatching_comes_with_closeness() -> void:
	var scene := _make_level()
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.6, 0.24)
	lamp.light_energy = 1.0
	lamp.omni_range = 9.0
	scene.level.add_child(lamp)
	lamp.global_position = Vector3(-2.0, 3.0, -1.0)
	var look := _look()
	look.screen_ink = false
	look.post_enabled = false
	look.rim_lights = false
	look.apply(scene.level)
	var rig := scene.level.get_node(^"CineInkRig") as CineInkRig
	await wait_process_frames(3)
	assert_almost_eq(rig.key_world(), lamp.global_position, Vector3(0.01, 0.01, 0.01), "the key is the lamp's position")
	assert_gte(rig.hatch_amount(), 0.0, "the hatching amount is a share")
	assert_lte(rig.hatch_amount(), 1.0, "of one")
	look.hatch_force = 1.0
	await wait_process_frames(2)
	assert_eq(rig.hatch_amount(), 1.0, "forced hatching is full")
