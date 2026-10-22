extends GutTest
## HumanoidRig (game/actors/humanoid_rig.gd) and its placeholder pose and animation
## builders: skeleton, rig points, hurtboxes, layers, the animation library, move timing
## and the "Strike reach" envelopes of docs/ARCHITECTURE.md.

const FRAME := 1.0 / 60.0
## Horizontal FOV of the first-person camera and the vertical half-angle that gives at
## 16:9 with Camera3D.KEEP_WIDTH (Spec §5).
const FP_HALF_H_DEG := 45.0
const FP_HALF_V_DEG := 29.36
## Distance between two fighters' centers in the strike tests (docs/ARCHITECTURE.md).
const TARGET_DISTANCE := 0.85

## docs/ARCHITECTURE.md "Bones", spelled out here so a typo in the rig cannot hide.
const BONES: Array[StringName] = [
	&"Root", &"Hips", &"Spine", &"Chest", &"UpperChest", &"Neck", &"Head",
	&"LeftShoulder", &"LeftUpperArm", &"LeftLowerArm", &"LeftHand",
	&"RightShoulder", &"RightUpperArm", &"RightLowerArm", &"RightHand",
	&"LeftUpperLeg", &"LeftLowerLeg", &"LeftFoot", &"LeftToes",
	&"RightUpperLeg", &"RightLowerLeg", &"RightFoot", &"RightToes",
]

## docs/ARCHITECTURE.md "Rig points".
const POINTS: Array[StringName] = [
	&"EyePoint", &"HeadTopPoint", &"ChestPoint", &"LeftFistPoint", &"RightFistPoint",
	&"LeftElbowPoint", &"RightElbowPoint", &"LeftKneePoint", &"RightKneePoint",
	&"LeftFootPoint", &"RightFootPoint", &"WeaponGrip", &"WeaponTip", &"HoldPoint",
]

## docs/ARCHITECTURE.md "Animation ids" (the move ids are in MOVES).
const ANIM_IDS: Array[StringName] = [
	&"idle", &"walk_forward", &"walk_back", &"walk_left", &"walk_right",
	&"jump", &"fall", &"land",
	&"dodge_left", &"dodge_right", &"dodge_back", &"dodge_forward",
	&"grab", &"hold", &"held", &"thrown", &"pickup", &"haymaker_charge",
	&"flinch_head_front", &"flinch_head_left", &"flinch_head_right", &"flinch_gut",
	&"flinch_legs", &"stagger_back", &"stagger_left", &"stagger_right", &"stagger_forward",
	&"launched", &"knockdown_back", &"knockdown_forward", &"downed_back", &"downed_front",
	&"getup_back", &"getup_front", &"ko_back", &"ko_front",
]

## Looping or holding animations (everything else plays once and holds its last pose).
const LOOPING: Array[StringName] = [
	&"idle", &"walk_forward", &"walk_back", &"walk_left", &"walk_right",
	&"hold", &"held", &"downed_back", &"downed_front",
]

## docs/ARCHITECTURE.md moves table: [id, startup, active, recovery].
const MOVES: Array = [
	[&"jab_1", 4, 3, 10], [&"jab_2", 4, 3, 10], [&"hook", 6, 3, 14], [&"uppercut", 8, 3, 22],
	[&"body_flurry", 2, 2, 6], [&"shove", 6, 3, 18], [&"front_kick", 7, 3, 14],
	[&"roundhouse", 9, 3, 16], [&"spinning_heel", 12, 5, 24], [&"stomp_kick", 10, 3, 22],
	[&"push_kick", 8, 3, 20], [&"haymaker", 14, 3, 26], [&"flying_kick", 5, 8, 14],
	[&"spin_kick", 6, 10, 16], [&"back_elbow", 5, 3, 18], [&"knee", 5, 3, 12],
	[&"throw", 8, 2, 20], [&"stomp", 8, 3, 14], [&"pipe_swing_1", 7, 3, 12],
	[&"pipe_swing_2", 7, 3, 12], [&"pipe_swing_3", 9, 4, 20], [&"weapon_throw", 6, 1, 14],
	[&"impact_body_knockdown", 0, 1, 0], [&"impact_body_stagger", 0, 1, 0],
]


## One "Strike reach" row: the strike point(s) must be at z <= z_max (z >= z_min for the
## back elbow) and y_min..y_max in the attacker's frame on every active frame.
class Reach:
	var id: StringName
	var points: Array[StringName]
	var z_max: float
	var y_min: float
	var y_max: float
	## Hitbox radius from the moves table (0 = no contact check).
	var radius: float
	## What the contact check stands the target in: &"stand", &"held", &"downed" or &"".
	var target: StringName
	## Region the strike must touch on that target (-1 = any).
	var region: int
	## Straight strikes land on a target at arm's length instead of sinking into it: the
	## strike point stays at z >= bury_z (-INF = no limit).
	var bury_z: float

	func _init(p_id: StringName, p_points: Array[StringName], p_z_max: float, p_y_min: float,
			p_y_max: float, p_radius: float, p_target: StringName = &"stand", p_region: int = -1,
			p_bury_z: float = -INF) -> void:
		id = p_id
		points = p_points
		z_max = p_z_max
		y_min = p_y_min
		y_max = p_y_max
		radius = p_radius
		target = p_target
		region = p_region
		bury_z = p_bury_z


func _reach_rows() -> Array[Reach]:
	var head := CombatTypes.Region.HEAD
	var torso := CombatTypes.Region.TORSO
	# Fists stop at the face (about 0.72 m away) instead of vanishing into the head, and
	# kicks sink at most a few centimeters past the belly, so both read in first person.
	var fist_bury := -0.78
	var foot_bury := -0.8
	return [
		Reach.new(&"jab_1", [&"LeftFistPoint"], -0.65, 1.35, 1.65, 0.12, &"stand", head, fist_bury),
		Reach.new(&"jab_2", [&"RightFistPoint"], -0.65, 1.35, 1.65, 0.12, &"stand", head, fist_bury),
		Reach.new(&"hook", [&"LeftFistPoint"], -0.5, 1.35, 1.65, 0.14, &"stand", head, fist_bury),
		Reach.new(&"uppercut", [&"RightFistPoint"], -0.45, 1.4, 1.8, 0.14, &"stand", head, fist_bury),
		Reach.new(&"shove", [&"LeftFistPoint", &"RightFistPoint"], -0.55, 1.1, 1.45, 0.16, &"stand", torso, fist_bury),
		Reach.new(&"front_kick", [&"RightFootPoint"], -0.75, 0.8, 1.2, 0.15, &"stand", torso, foot_bury),
		Reach.new(&"roundhouse", [&"RightFootPoint"], -0.6, 1.1, 1.6, 0.16),
		Reach.new(&"stomp_kick", [&"RightFootPoint"], -0.75, 0.7, 1.1, 0.16, &"stand", torso, foot_bury),
		Reach.new(&"push_kick", [&"RightFootPoint"], -0.75, 0.8, 1.2, 0.16, &"stand", torso, foot_bury),
		Reach.new(&"haymaker", [&"RightFistPoint"], -0.65, 1.35, 1.65, 0.16, &"stand", head, fist_bury),
		# Airborne (origin 0.4-1.0 m up), so the foot aims forward and down at the chest.
		Reach.new(&"flying_kick", [&"RightFootPoint"], -0.7, 0.35, 0.75, 0.18),
		Reach.new(&"knee", [&"RightKneePoint"], -0.35, 0.9, 1.25, 0.18, &"held", torso),
		Reach.new(&"stomp", [&"RightFootPoint"], -0.5, 0.0, 0.3, 0.22, &"downed"),
		Reach.new(&"pipe_swing_1", [&"WeaponTip"], -0.7, 1.0, 1.7, 0.18, &"stand", head),
		Reach.new(&"pipe_swing_2", [&"WeaponTip"], -0.7, 1.0, 1.7, 0.18, &"stand", head),
		Reach.new(&"pipe_swing_3", [&"WeaponTip"], -0.7, 1.0, 1.7, 0.2, &"stand", head),
	]


# --- Helpers ---------------------------------------------------------------------------


func _rig(first_person: bool = false, height: float = 1.8, actor: Node3D = null) -> HumanoidRig:
	var rig := HumanoidRig.new()
	rig.first_person_body = first_person
	rig.height = height
	rig.actor = actor
	add_child_autofree(rig)
	rig.build()
	return rig


func _move(row: Array) -> MoveData:
	var move := MoveData.new()
	move.id = row[0]
	move.startup = row[1]
	move.active = row[2]
	move.recovery = row[3]
	return move


func _move_by_id(id: StringName) -> MoveData:
	for row: Array in MOVES:
		if row[0] == id:
			return _move(row)
	return null


## Play `move` from idle and stop on its first active frame (sim frames of 1/60 s).
func _to_first_active_frame(rig: HumanoidRig, move: MoveData) -> void:
	rig.play(&"idle", 0.0)
	rig.advance(0.5)
	rig.play_move(move)
	for i: int in move.startup:
		rig.advance(FRAME)


## Rig-local position (the rig stands at its parent's origin in these tests).
func _local(rig: HumanoidRig, point: StringName) -> Vector3:
	return rig.global_transform.affine_inverse() * rig.get_point_position(point)


func _in_envelope(p: Vector3, row: Reach) -> bool:
	if row.id == &"back_elbow":
		return p.z >= row.z_max
	return p.z <= row.z_max and p.y >= row.y_min and p.y <= row.y_max


## Stand `target` facing `rig` the way `kind` says (see Reach.target) and pose it.
func _place_target(rig: HumanoidRig, target: HumanoidRig, kind: StringName) -> void:
	match kind:
		&"held":
			# The victim's origin is pinned on the floor below HoldPoint, facing the holder.
			rig.play(&"hold", 0.0)
			rig.advance(0.0)
			var hold := rig.get_point_position(&"HoldPoint")
			target.position = Vector3(hold.x, 0.0, hold.z)
			target.rotation = Vector3(0.0, PI, 0.0)
			target.play(&"held", 0.0)
		&"downed":
			# Lying across the attacker's path, about a step ahead.
			target.position = Vector3(0.0, 0.0, -0.7)
			target.rotation = Vector3(0.0, PI * 0.5, 0.0)
			target.play(&"downed_back", 0.0)
		_:
			target.position = Vector3(0.0, 0.0, -TARGET_DISTANCE)
			target.rotation = Vector3(0.0, PI, 0.0)
			target.play(&"idle", 0.0)
	target.advance(0.0)


func _fmt(p: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]


## Regions of `target`'s hurtboxes that a sphere at world `center` with `radius` touches.
func _touched_regions(target: HumanoidRig, center: Vector3, radius: float) -> Array[int]:
	var out: Array[int] = []
	for hurtbox: Hurtbox in target.get_hurtboxes():
		var shape := (hurtbox.get_child(0) as CollisionShape3D).shape
		var xf := hurtbox.global_transform
		var dist := xf.origin.distance_to(center)
		if shape is CapsuleShape3D:
			var capsule := shape as CapsuleShape3D
			var half := capsule.height * 0.5 - capsule.radius
			var a := xf * Vector3(0.0, -half, 0.0)
			var b := xf * Vector3(0.0, half, 0.0)
			dist = Geometry3D.get_closest_point_to_segment(center, a, b).distance_to(center)
		if dist < hurtbox.radius + radius:
			out.append(hurtbox.region)
	return out


## Camera-space angles (degrees: x = right of center, y = above center) of a rig point
## seen from EyePoint looking down -Z, pitched by `pitch_deg` and dropped by `drop`.
## z is the distance in front of the camera.
func _view(rig: HumanoidRig, point: StringName, pitch_deg: float = 0.0, drop: float = 0.0) -> Vector3:
	var eye := rig.get_point_position(&"EyePoint") + Vector3.DOWN * drop
	var cam := Basis.from_euler(Vector3(deg_to_rad(pitch_deg), 0.0, 0.0))
	var q := cam.inverse() * (rig.get_point_position(point) - eye)
	return Vector3(rad_to_deg(atan2(q.x, -q.z)), rad_to_deg(atan2(q.y, -q.z)), -q.z)


func _in_fp_view(view: Vector3) -> bool:
	return view.z > 0.05 and absf(view.x) < FP_HALF_H_DEG and absf(view.y) < FP_HALF_V_DEG


func _meshes_under(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		out.append(child as MeshInstance3D)
	return out


func _hurtboxes_of(rig: HumanoidRig, region: CombatTypes.Region) -> Array[Hurtbox]:
	var out: Array[Hurtbox] = []
	for hurtbox: Hurtbox in rig.get_hurtboxes():
		if hurtbox.region == region:
			out.append(hurtbox)
	return out


func _current_animation(rig: HumanoidRig) -> Animation:
	return rig.anim_player.get_animation(rig.anim_player.assigned_animation)


func _track(anim: Animation, path: String) -> int:
	return anim.find_track(NodePath(path), Animation.TYPE_ROTATION_3D)


# --- Skeleton and rig points -----------------------------------------------------------


func test_builds_headless_with_a_manual_animation_player() -> void:
	var rig := _rig()
	assert_not_null(rig.skeleton, "skeleton built")
	assert_eq(rig.skeleton.name, &"Skeleton3D")
	assert_eq(rig.get_node_or_null(^"Skeleton3D"), rig.skeleton, "Skeleton3D is a direct child")
	assert_not_null(rig.anim_player, "animation player built")
	assert_eq(rig.anim_player.callback_mode_process,
			AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, "animation only advances in advance()")
	assert_eq(rig.current_anim(), &"idle", "starts in idle")


func test_all_bone_names_exist() -> void:
	var rig := _rig()
	assert_eq(rig.skeleton.get_bone_count(), BONES.size(), "exactly the humanoid bones")
	for bone: StringName in BONES:
		assert_gte(rig.skeleton.find_bone(bone), 0, "bone %s" % bone)
	assert_eq(rig.skeleton.get_bone_parent(rig.skeleton.find_bone(&"Root")), -1, "Root is the root")
	assert_eq(rig.skeleton.get_bone_parent(rig.skeleton.find_bone(&"Head")),
			rig.skeleton.find_bone(&"Neck"), "Head hangs off Neck")


func test_rig_points_exist_and_stand_where_the_contract_says() -> void:
	var rig := _rig()
	for point: StringName in POINTS:
		var marker := rig.get_attachment(point)
		assert_true(marker is Marker3D, "%s is a marker" % point)
		assert_eq(marker.name, point)
		assert_almost_eq(marker.global_position, rig.get_point_position(point), Vector3.ONE * 1e-4,
				"%s marker follows its bone" % point)
	var eye := rig.get_point_position(&"EyePoint")
	assert_between(eye.y, 1.6, 1.75, "EyePoint height in idle")
	assert_lt(eye.z, 0.0, "eyes are at the front of the head")
	var head_top := rig.get_point_position(&"HeadTopPoint")
	assert_between(head_top.y - eye.y, 0.3, 0.5, "HeadTopPoint floats above the head")
	var chest := rig.get_point_position(&"ChestPoint")
	assert_between(chest.y, 1.1, 1.45, "ChestPoint at chest height")
	var hold := rig.get_point_position(&"HoldPoint")
	assert_between(chest.z - hold.z, 0.45, 0.65, "HoldPoint about 0.55 m in front of the chest")
	assert_almost_eq(hold.y, chest.y, 0.1, "HoldPoint at chest height")
	var grip := rig.get_point_position(&"WeaponGrip")
	assert_almost_eq(grip.distance_to(rig.get_point_position(&"WeaponTip")), 0.7, 0.01,
			"WeaponTip is 0.7 m along the weapon")
	assert_almost_eq(grip.distance_to(rig.get_point_position(&"RightFistPoint")), 0.0, 0.03,
			"WeaponGrip sits in the right fist")


func test_bone_names_work_as_points_and_the_skeleton_pose_is_current() -> void:
	var rig := _rig()
	rig.play(&"flinch_gut", 0.0)
	rig.advance(0.07)
	for bone: StringName in BONES:
		var idx := rig.skeleton.find_bone(bone)
		var expected := rig.skeleton.global_transform * rig.skeleton.get_bone_global_pose(idx)
		assert_almost_eq(rig.get_point_position(bone), expected.origin, Vector3.ONE * 1e-4,
				"%s matches Skeleton3D's global pose right after advance()" % bone)
		assert_almost_eq(rig.get_attachment(bone).global_position, expected.origin,
				Vector3.ONE * 1e-4, "%s attachment follows the bone" % bone)


func test_feet_rest_on_the_floor_and_height_scales_the_rig() -> void:
	var rig := _rig()
	var tall := _rig(false, 2.0)
	var lowest := INF
	for bone: StringName in [&"LeftFoot", &"RightFoot", &"LeftToes", &"RightToes"]:
		lowest = minf(lowest, rig.get_point_position(bone).y)
	assert_between(lowest, 0.0, 0.1, "the origin is at the feet")
	var ratio := tall.get_point_position(&"EyePoint").y / rig.get_point_position(&"EyePoint").y
	assert_almost_eq(ratio, 2.0 / 1.8, 0.01, "height scales the whole rig")
	var face := rig.get_point_position(&"EyePoint") - rig.get_point_position(&"Head")
	assert_lt(face.z, 0.0, "the character faces -Z")


func test_build_twice_is_safe() -> void:
	var rig := _rig()
	var skeleton := rig.skeleton
	var player := rig.anim_player
	var children := rig.get_child_count()
	var meshes := _meshes_under(rig).size()
	rig.build()
	assert_eq(rig.skeleton, skeleton, "same skeleton")
	assert_eq(rig.anim_player, player, "same animation player")
	assert_eq(rig.get_child_count(), children, "no duplicate nodes")
	assert_eq(_meshes_under(rig).size(), meshes, "no duplicate meshes")
	assert_eq(rig.skeleton.get_bone_count(), BONES.size())
	assert_eq(rig.get_hurtboxes().size(), 4)


# --- Meshes, layers and materials ------------------------------------------------------


func test_meshes_cast_shadows_and_use_few_flat_colors() -> void:
	var rig := _rig()
	var meshes := _meshes_under(rig)
	assert_gt(meshes.size(), 20, "a primitive mesh per body part")
	var colors: Array[Color] = []
	for mesh: MeshInstance3D in meshes:
		assert_eq(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "%s casts shadows" % mesh.name)
		var mat := mesh.material_override as StandardMaterial3D
		assert_not_null(mat, "%s has a flat material" % mesh.name)
		if mat and not colors.has(mat.albedo_color):
			colors.append(mat.albedo_color)
	assert_between(colors.size(), 4, 6, "4 to 6 flat colors (Spec §10)")
	assert_has(colors, rig.body_color)
	assert_has(colors, rig.accent_color)
	assert_has(colors, rig.skin_color)


func test_first_person_body_hides_only_head_neck_and_upper_arms() -> void:
	var fp := _rig(true)
	var hidden := CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN)
	var default := CombatTypes.bit(CombatTypes.VIS_DEFAULT)
	var head_meshes: Array[MeshInstance3D] = []
	for bone: StringName in PlaceholderBody.FP_HIDDEN_BONES:
		head_meshes.append_array(_meshes_under(fp.get_attachment(bone)))
	assert_gt(head_meshes.size(), 6, "head, cap, shades, neck, shoulder and upper-arm meshes")
	assert_true(_meshes_under(fp.get_attachment(&"RightLowerArm")).all(
		func(m: MeshInstance3D) -> bool: return m.layers == default), "forearms stay visible")
	for mesh: MeshInstance3D in _meshes_under(fp):
		var expected := hidden if head_meshes.has(mesh) else default
		assert_eq(mesh.layers, expected, "%s render layers" % mesh.name)
	var third := _rig(false)
	for mesh: MeshInstance3D in _meshes_under(third):
		assert_eq(mesh.layers, default, "%s on layer 1 for a third-person body" % mesh.name)
	fp.first_person_body = false
	for mesh: MeshInstance3D in head_meshes:
		assert_eq(mesh.layers, default, "turning first_person_body off shows the head again")


func test_flash_is_white_emission_per_rig() -> void:
	var rig := _rig()
	var other := _rig()
	rig.set_flash(1.0)
	for mesh: MeshInstance3D in _meshes_under(rig):
		var mat := mesh.material_override as StandardMaterial3D
		assert_true(mat.emission_enabled)
		assert_eq(mat.emission, Color.WHITE)
		assert_almost_eq(mat.emission_energy_multiplier, 1.0, 1e-4, "%s flashes" % mesh.name)
	for mesh: MeshInstance3D in _meshes_under(other):
		var mat := mesh.material_override as StandardMaterial3D
		assert_almost_eq(mat.emission_energy_multiplier, 0.0, 1e-4, "other rigs do not flash")
	rig.set_flash(0.0)
	for mesh: MeshInstance3D in _meshes_under(rig):
		var mat := mesh.material_override as StandardMaterial3D
		assert_almost_eq(mat.emission_energy_multiplier, 0.0, 1e-4, "flash cleared")


# --- Hurtboxes -------------------------------------------------------------------------


func test_hurtboxes_per_region_with_actor_and_shapes() -> void:
	var actor := Node3D.new()
	add_child_autofree(actor)
	var rig := _rig(false, 1.8, actor)
	assert_eq(_hurtboxes_of(rig, CombatTypes.Region.HEAD).size(), 1, "one HEAD hurtbox")
	assert_eq(_hurtboxes_of(rig, CombatTypes.Region.TORSO).size(), 1, "one TORSO hurtbox")
	assert_eq(_hurtboxes_of(rig, CombatTypes.Region.LEGS).size(), 2, "a LEGS hurtbox per leg")
	for hurtbox: Hurtbox in rig.get_hurtboxes():
		assert_eq(hurtbox.actor, actor, "%s knows its actor" % hurtbox.name)
		assert_gt(hurtbox.radius, 0.05, "%s radius" % hurtbox.name)
		assert_eq(hurtbox.collision_layer, CombatTypes.bit(CombatTypes.LAYER_HURTBOX))
		assert_true(hurtbox.monitorable)
		assert_false(hurtbox.monitoring)
		var shape := hurtbox.get_child(0) as CollisionShape3D
		assert_not_null(shape, "%s has a CollisionShape3D" % hurtbox.name)
		if shape:
			var expected_kind := "SphereShape3D" if hurtbox.region == CombatTypes.Region.HEAD else "CapsuleShape3D"
			assert_eq(shape.shape.get_class(), expected_kind, "%s shape" % hurtbox.name)
	var head := _hurtboxes_of(rig, CombatTypes.Region.HEAD)[0]
	assert_almost_eq(head.global_position.distance_to(rig.get_point_position(&"EyePoint")), 0.1, 0.06,
			"head sphere wraps the head")
	var torso := _hurtboxes_of(rig, CombatTypes.Region.TORSO)[0]
	assert_between(torso.global_position.y, rig.get_point_position(&"Spine").y,
			rig.get_point_position(&"UpperChest").y + 0.1, "torso capsule spans Spine to UpperChest")
	var later := Node3D.new()
	add_child_autofree(later)
	rig.actor = later
	for hurtbox: Hurtbox in rig.get_hurtboxes():
		assert_eq(hurtbox.actor, later, "setting actor after build updates %s" % hurtbox.name)


func test_hurtboxes_follow_the_pose_on_the_same_advance() -> void:
	var rig := _rig()
	var head := _hurtboxes_of(rig, CombatTypes.Region.HEAD)[0]
	var standing_y := head.global_position.y
	assert_gt(standing_y, 1.4, "head hurtbox is high while standing")
	rig.play(&"downed_back", 0.0)
	rig.advance(FRAME)
	assert_lt(head.global_position.y, 0.5, "head hurtbox drops in downed_back on the same advance")
	for hurtbox: Hurtbox in rig.get_hurtboxes():
		var server := PhysicsServer3D.area_get_transform(hurtbox.get_rid())
		assert_almost_eq(server.origin, hurtbox.global_position, Vector3.ONE * 1e-4,
				"%s physics transform is current, not a frame late" % hurtbox.name)
	var legs := _hurtboxes_of(rig, CombatTypes.Region.LEGS)
	rig.play(&"idle", 0.0)
	rig.advance(0.0)
	var knee := rig.get_point_position(&"LeftKneePoint")
	var left := legs[0] if legs[0].global_position.x < legs[1].global_position.x else legs[1]
	assert_lt(left.global_position.distance_to(knee), 0.2, "left leg capsule runs past the knee")


func test_hurtboxes_can_be_disabled_and_enabled() -> void:
	var rig := _rig()
	rig.set_hurtboxes_enabled(false)
	for hurtbox: Hurtbox in rig.get_hurtboxes():
		assert_false(hurtbox.monitorable, "%s not monitorable" % hurtbox.name)
		assert_true((hurtbox.get_child(0) as CollisionShape3D).disabled, "%s shape disabled" % hurtbox.name)
	rig.set_hurtboxes_enabled(true)
	for hurtbox: Hurtbox in rig.get_hurtboxes():
		assert_true(hurtbox.monitorable, "%s monitorable again" % hurtbox.name)
		assert_false((hurtbox.get_child(0) as CollisionShape3D).disabled, "%s shape enabled" % hurtbox.name)


# --- Animation library -----------------------------------------------------------------


func test_every_animation_id_exists_with_bone_tracks() -> void:
	var rig := _rig()
	for id: StringName in ANIM_IDS:
		assert_true(rig.has_anim(id), "has_anim(%s)" % id)
		assert_true(rig.anim_player.has_animation(id), "library has %s" % id)
		if not rig.anim_player.has_animation(id):
			continue
		var anim := rig.anim_player.get_animation(id)
		for bone: StringName in BONES:
			if bone == &"Root":
				continue
			assert_gte(_track(anim, "Skeleton3D:%s" % bone), 0, "%s rotates %s" % [id, bone])
		assert_gte(anim.find_track(^"Skeleton3D:Hips", Animation.TYPE_POSITION_3D), 0,
				"%s has a Hips position track" % id)
		var expected_loop := Animation.LOOP_LINEAR if LOOPING.has(id) else Animation.LOOP_NONE
		assert_eq(anim.loop_mode, expected_loop, "%s loop mode" % id)
	for row: Array in MOVES:
		assert_true(rig.has_anim(row[0]), "has_anim(%s)" % row[0])
	assert_false(rig.has_anim(&"moonwalk"), "unknown ids are not claimed")


func test_reaction_durations() -> void:
	var rig := _rig()
	var lengths := {
		&"flinch_head_front": 0.25, &"flinch_gut": 0.25, &"flinch_legs": 0.25,
		&"stagger_back": 0.6, &"stagger_left": 0.6, &"knockdown_back": 0.5,
		&"knockdown_forward": 0.5, &"getup_back": 0.5, &"getup_front": 0.5,
		&"ko_back": 0.8, &"ko_front": 0.8,
	}
	for id: StringName in lengths:
		assert_almost_eq(rig.anim_player.get_animation(id).length, float(lengths[id]), 0.05, "%s length" % id)


func test_body_goes_down_and_comes_back_up() -> void:
	var rig := _rig()
	var standing := rig.get_point_position(&"Hips").y
	rig.play(&"knockdown_back", 0.0)
	rig.advance(0.0)
	rig.advance(0.5)
	assert_lt(rig.get_point_position(&"Hips").y, 0.3, "knockdown_back ends lying down")
	rig.play(&"getup_back", 0.0)
	rig.advance(0.0)
	rig.advance(0.5)
	assert_almost_eq(rig.get_point_position(&"Hips").y, standing, 0.02, "getup_back ends standing")
	rig.play(&"ko_front", 0.0)
	rig.advance(0.0)
	rig.advance(2.0)
	assert_eq(rig.current_anim(), &"ko_front", "KO holds its last pose")
	assert_lt(rig.get_point_position(&"Head").y, 0.4, "KO slumps to the floor and stays there")
	rig.play(&"jump", 0.0)
	rig.advance(0.0)
	rig.advance(0.3)
	var tuck := rig.get_point_position(&"RightFoot").y
	assert_gt(tuck, 0.2, "jump tucks the feet up")


func test_falls_from_the_air_never_raise_the_head() -> void:
	# Launched and thrown bodies are already off their feet: a KO or knockdown (or the
	# landing) must not stand them back up in a buckle, nor swing them up through upright
	# when they come down on the other face. Blend times as in CombatActor.
	var rig := _rig()
	var falls := {
		&"ko_back": 0.1, &"ko_front": 0.1, &"knockdown_back": 0.03, &"knockdown_forward": 0.03,
		&"downed_back": 0.08, &"downed_front": 0.08,
	}
	for from: StringName in [&"launched", &"thrown"]:
		for t: float in [0.0, 0.1, 0.2, 0.3, 0.45, 0.7]:
			for anim: StringName in falls:
				rig.play(from, 0.0)
				rig.advance(0.0)
				rig.advance(t)
				var start := rig.get_point_position(&"Head").y
				rig.play(anim, falls[anim])
				var highest := start
				for i: int in 60:
					rig.advance(FRAME)
					highest = maxf(highest, rig.get_point_position(&"Head").y)
				assert_lt(highest - start, 0.05, "%s from %s at %.2f s: head rises %.3f m" % [
						anim, from, t, highest - start])
				assert_lt(rig.get_point_position(&"Head").y, 0.4, "%s from %s at %.2f s ends lying" % [
						anim, from, t])


func test_spins_turn_a_full_circle_and_back_elbow_does_not() -> void:
	var rig := _rig()
	for id: StringName in [&"spinning_heel", &"spin_kick", &"back_elbow"]:
		var move := _move_by_id(id)
		rig.play(&"idle", 0.0)
		rig.advance(0.5)
		rig.play_move(move, 0.0)
		var total := 0.0
		var widest := 0.0
		var last := rig.get_point_transform(&"Hips").basis.z
		for i: int in move.total_frames():
			rig.advance(FRAME)
			var now := rig.get_point_transform(&"Hips").basis.z
			total += rad_to_deg(Vector2(last.x, last.z).angle_to(Vector2(now.x, now.z)))
			widest = maxf(widest, absf(total))
			last = now
		if id == &"back_elbow":
			assert_lt(widest, 60.0, "back_elbow strikes backward without turning around")
		else:
			assert_almost_eq(absf(total), 360.0, 10.0, "%s turns the body a full circle" % id)


func test_play_restarts_and_advance_zero_does_not_move_time() -> void:
	var rig := _rig()
	rig.play(&"flinch_gut", 0.0)
	rig.advance(0.1)
	var pos := rig.anim_player.current_animation_position
	var fist := rig.get_point_position(&"LeftFistPoint")
	rig.advance(0.0)
	assert_almost_eq(rig.anim_player.current_animation_position, pos, 1e-6, "advance(0) keeps the time")
	assert_almost_eq(rig.get_point_position(&"LeftFistPoint"), fist, Vector3.ONE * 1e-5,
			"advance(0) keeps the pose")
	rig.play(&"flinch_gut", 0.0)
	rig.advance(0.0)
	assert_almost_eq(rig.anim_player.current_animation_position, 0.0, 1e-6, "playing it again restarts it")
	var move := _move_by_id(&"jab_1")
	rig.play_move(move)
	rig.advance(0.0)
	assert_almost_eq(rig.anim_player.current_animation_position, 0.0, 1e-6, "a new move starts at 0")
	assert_eq(rig.current_anim(), &"jab_1", "current_anim() is the move id")


# --- Moves -----------------------------------------------------------------------------


func test_play_move_length_and_strike_key_timing() -> void:
	var rig := _rig()
	for row: Array in MOVES:
		var move := _move(row)
		rig.play_move(move)
		var anim := _current_animation(rig)
		assert_almost_eq(anim.length, move.total_frames() * FRAME, 1e-4, "%s length" % move.id)
		assert_eq(anim.loop_mode, Animation.LOOP_NONE, "%s plays once" % move.id)
		var track := _track(anim, "Skeleton3D:RightUpperArm")
		var strike_t := move.startup * FRAME
		var end_t := (move.startup + move.active) * FRAME
		assert_gte(anim.track_find_key(track, strike_t, Animation.FIND_MODE_APPROX), 0,
				"%s keys the strike pose at startup / 60 s" % move.id)
		assert_gte(anim.track_find_key(track, end_t, Animation.FIND_MODE_APPROX), 0,
				"%s keys the end of the active frames" % move.id)
		if move.startup > 1:
			var windup_key := false
			for k: int in anim.track_get_key_count(track):
				var t := anim.track_get_key_time(track, k)
				windup_key = windup_key or (t >= strike_t * 0.4 - 1e-4 and t <= strike_t * 0.6 + 1e-4)
			assert_true(windup_key, "%s has a wind-up key at 40-60%% of startup" % move.id)
		for bone: StringName in BONES:
			if bone == &"Root":
				continue
			var t_bone := _track(anim, "Skeleton3D:%s" % bone)
			var start := anim.rotation_track_interpolate(t_bone, 0.0)
			var finish := anim.rotation_track_interpolate(t_bone, anim.length)
			assert_lt(rad_to_deg(start.angle_to(finish)), 0.5, "%s returns %s to guard" % [move.id, bone])
			if move.id != &"spinning_heel" and move.id != &"spin_kick":
				var a := anim.rotation_track_interpolate(t_bone, strike_t)
				var b := anim.rotation_track_interpolate(t_bone, end_t)
				assert_lt(rad_to_deg(a.angle_to(b)), 0.5, "%s holds the strike pose (%s)" % [move.id, bone])


func test_play_move_caches_per_move_and_frame_data() -> void:
	var rig := _rig()
	var library := rig.anim_player.get_animation_library(&"moves")
	var move := _move_by_id(&"hook")
	rig.play_move(move)
	var count := library.get_animation_list().size()
	rig.play_move(move)
	assert_eq(library.get_animation_list().size(), count, "replaying a move reuses its animation")
	var slower := _move_by_id(&"hook")
	slower.startup = 12
	rig.play_move(slower)
	assert_eq(library.get_animation_list().size(), count + 1, "new frame data builds a new animation")
	assert_almost_eq(_current_animation(rig).length, slower.total_frames() * FRAME, 1e-4)


func test_strike_reach_on_every_active_frame() -> void:
	var rig := _rig()
	for row: Reach in _reach_rows():
		var move := _move_by_id(row.id)
		_to_first_active_frame(rig, move)
		for f: int in move.active:
			if f > 0:
				rig.advance(FRAME)
			for point: StringName in row.points:
				var p := _local(rig, point)
				assert_true(_in_envelope(p, row), "%s %s at %s on active frame %d" % [
						row.id, point, _fmt(p), f])
				assert_gte(p.z, row.bury_z, "%s %s lands on the target instead of sinking into it (%s)" % [
						row.id, point, _fmt(p)])


func test_strikes_reach_full_weight_after_a_cross_fade_still_running() -> void:
	# A move that starts while an earlier cross-fade is still running (a locomotion switch,
	# a dodge) must still hit its strike pose exactly: nothing of the old pose may linger.
	var rig := _rig()
	var lead_ins := {
		&"idle_to_walk": func() -> void:
			rig.play_locomotion(Vector2(0.0, 1.0), 1.0)
			rig.advance(FRAME),
		&"walk_to_idle": func() -> void:
			rig.play_locomotion(Vector2(0.0, 1.0), 1.0)
			rig.advance(0.4)
			rig.play_locomotion(Vector2.ZERO, 0.0)
			rig.advance(FRAME),
		&"mid_dodge": func() -> void:
			rig.play(&"dodge_left")
			rig.advance(FRAME),
		&"dodge_then_idle": func() -> void:
			rig.play(&"dodge_right", 0.03)
			rig.advance(0.3)
			rig.play_locomotion(Vector2.ZERO, 0.0)
			rig.advance(FRAME),
	}
	for row: Reach in _reach_rows():
		var move := _move_by_id(row.id)
		_to_first_active_frame(rig, move)
		var expected: Array[Vector3] = []
		for point: StringName in row.points:
			expected.append(_local(rig, point))
		for lead: StringName in lead_ins:
			rig.play(&"idle", 0.0)
			rig.advance(0.5)
			(lead_ins[lead] as Callable).call()
			rig.play_move(move)
			for i: int in move.startup:
				rig.advance(FRAME)
			for p: int in row.points.size():
				var at := _local(rig, row.points[p])
				assert_almost_eq(at, expected[p], Vector3.ONE * 0.01, "%s after %s: %s at %s, from idle %s" % [
						row.id, lead, row.points[p], _fmt(at), _fmt(expected[p])])
			for f: int in move.active:
				if f > 0:
					rig.advance(FRAME)
				for point: StringName in row.points:
					var p := _local(rig, point)
					assert_true(_in_envelope(p, row), "%s after %s: %s at %s on active frame %d" % [
							row.id, lead, point, _fmt(p), f])


func test_cross_fades_are_continuous_and_advance_zero_keeps_them() -> void:
	var rig := _rig()
	rig.play(&"idle", 0.0)
	rig.advance(0.5)
	var before := rig.get_point_position(&"LeftFistPoint")
	rig.play(&"flinch_gut", 0.2)
	rig.advance(0.0)
	assert_almost_eq(rig.get_point_position(&"LeftFistPoint"), before, Vector3.ONE * 1e-4,
			"a cross-fade starts from the pose on screen")
	rig.advance(0.05)
	var mid := rig.get_point_position(&"LeftFistPoint")
	rig.advance(0.0)
	rig.advance(0.0)
	assert_almost_eq(rig.get_point_position(&"LeftFistPoint"), mid, Vector3.ONE * 1e-5,
			"advance(0) keeps a cross-fade where it is")
	# A new animation fades from what is shown, even halfway through another fade.
	rig.play(&"stagger_back", 0.1)
	rig.advance(0.0)
	assert_almost_eq(rig.get_point_position(&"LeftFistPoint"), mid, Vector3.ONE * 1e-4,
			"no jump when a fade starts during a fade")
	assert_eq(rig.anim_player.assigned_animation, &"stagger_back")


func test_haymaker_released_from_its_charge_swings_straight_in() -> void:
	# haymaker_charge holds the haymaker's wind-up. Released from it, the haymaker drives
	# straight from the cocked fist into the strike, with no trip back to guard first.
	var rig := _rig()
	var move := _move_by_id(&"haymaker")
	_to_first_active_frame(rig, move)
	var strike := _local(rig, &"RightFistPoint")
	rig.play(&"idle", 0.0)
	rig.advance(0.5)
	rig.play(&"haymaker_charge")
	rig.advance(0.5)
	assert_eq(rig.current_anim(), &"haymaker_charge")
	var cocked := _local(rig, &"RightFistPoint")
	assert_gt(cocked.distance_to(strike), 0.4, "the charge cocks the fist far from the strike")
	rig.play_move(move)
	var last := cocked
	for i: int in move.startup:
		rig.advance(FRAME)
		var fist := _local(rig, &"RightFistPoint")
		if i == 0:
			assert_lt(fist.distance_to(cocked), 0.02, "the release starts from the cocked fist")
		assert_lt(fist.distance_to(strike), last.distance_to(strike) + 0.01,
				"frame %d: the fist never pulls back from the strike (%s)" % [i + 1, _fmt(fist)])
		last = fist
	assert_almost_eq(last, strike, Vector3.ONE * 0.01, "the charged haymaker reaches the same strike pose")
	assert_eq(rig.current_anim(), &"haymaker")
	# Released early, before the charge is fully cocked, it still lands the same strike.
	rig.play(&"idle", 0.0)
	rig.advance(0.5)
	rig.play(&"haymaker_charge")
	rig.advance(0.12)
	rig.play_move(move)
	for i: int in move.startup:
		rig.advance(FRAME)
	assert_almost_eq(_local(rig, &"RightFistPoint"), strike, Vector3.ONE * 0.01,
			"a partly charged haymaker reaches the strike pose")
	# Without the charge it still winds up from guard (the uncharged animation).
	rig.play(&"idle", 0.0)
	rig.advance(0.5)
	var guard := _local(rig, &"RightFistPoint")
	rig.play_move(move, 0.0)
	var pulled_back := 0.0
	for i: int in move.startup:
		rig.advance(FRAME)
		pulled_back = maxf(pulled_back, _local(rig, &"RightFistPoint").distance_to(strike) - guard.distance_to(strike))
	assert_gt(pulled_back, 0.1, "the uncharged haymaker winds up from guard")


func test_back_elbow_drives_back() -> void:
	var rig := _rig()
	var move := _move_by_id(&"back_elbow")
	_to_first_active_frame(rig, move)
	var elbow := _local(rig, &"RightElbowPoint")
	assert_gte(elbow.z, 0.3, "back_elbow elbow behind the body at %s" % _fmt(elbow))
	assert_between(elbow.y, 1.0, 1.6, "back_elbow at torso height")


func test_body_flurry_alternates_fists_at_gut_height() -> void:
	var rig := _rig()
	var move := _move_by_id(&"body_flurry")
	var row := Reach.new(&"body_flurry", [], -0.55, 1.0, 1.3, 0.12)
	_to_first_active_frame(rig, move)
	var left := _local(rig, &"LeftFistPoint")
	assert_true(_in_envelope(left, row), "first flurry blow leads with the left fist at %s" % _fmt(left))
	var left_foot := _local(rig, &"LeftFoot")
	for i: int in move.recovery + move.active:
		rig.advance(FRAME)
	rig.play_move(move)
	for i: int in move.startup:
		rig.advance(FRAME)
	var right := _local(rig, &"RightFistPoint")
	assert_true(_in_envelope(right, row), "the repeat leads with the right fist at %s" % _fmt(right))
	assert_almost_eq(_local(rig, &"LeftFoot"), left_foot, Vector3.ONE * 0.08, "alternating keeps the stance")


func test_strikes_connect_with_a_target_at_arms_length() -> void:
	var rig := _rig()
	var target := _rig()
	for row: Reach in _reach_rows():
		var move := _move_by_id(row.id)
		_place_target(rig, target, row.target)
		_to_first_active_frame(rig, move)
		var touched: Array[int] = []
		for point: StringName in row.points:
			touched.append_array(_touched_regions(target, rig.get_point_position(point), row.radius))
		assert_false(touched.is_empty(), "%s connects with a %s target (strike point %s)" % [
				row.id, row.target, _fmt(_local(rig, row.points[0]))])
		if row.region >= 0:
			assert_has(touched, row.region, "%s hits the %s (touched %s)" % [
					row.id, CombatTypes.Region.keys()[row.region], touched])


func test_pipe_swings_meet_the_head_without_passing_through_it() -> void:
	var rig := _rig()
	var target := _rig()
	_place_target(rig, target, &"stand")
	var head := _hurtboxes_of(target, CombatTypes.Region.HEAD)[0]
	for id: StringName in [&"pipe_swing_1", &"pipe_swing_2", &"pipe_swing_3"]:
		_to_first_active_frame(rig, _move_by_id(id))
		var grip := rig.get_point_position(&"WeaponGrip")
		var tip := rig.get_point_position(&"WeaponTip")
		var center := head.global_position
		var closest := Geometry3D.get_closest_point_to_segment(center, grip, tip)
		# 0.125 m is the head mesh radius (PlaceholderBody.parts()).
		assert_gt(closest.distance_to(center), 0.125 * 1.05,
				"%s: the pipe passes beside the head, not through it" % id)
		# Nor through the neck (0.065 m mesh radius) into the chest.
		var neck := Geometry3D.get_closest_points_between_segments(grip, tip,
				target.get_point_position(&"Neck"), target.get_point_position(&"Head"))
		assert_gt(neck[0].distance_to(neck[1]), 0.09, "%s: the pipe passes beside the neck" % id)
		assert_lt(tip.distance_to(center), head.radius + 0.2, "%s: the tip reaches the head" % id)


func test_held_victim_sits_at_the_bottom_of_the_holders_view() -> void:
	var rig := _rig(true)
	var victim := _rig()
	_place_target(rig, victim, &"held")
	var head := _hurtboxes_of(victim, CombatTypes.Region.HEAD)[0]
	var eye := rig.get_point_position(&"EyePoint")
	assert_gt(head.global_position.distance_to(eye), 0.25, "the victim's head is not in the holder's face")
	var to_head := head.global_position - eye
	var pitch := rad_to_deg(atan2(to_head.y, -to_head.z))
	assert_between(pitch, -40.0, -15.0, "the victim's head sits low in the first-person view")
	# The holder's hands rest on the victim's shoulders (left fist on the victim's right).
	for pair: Array in [[&"LeftFistPoint", &"RightUpperArm"], [&"RightFistPoint", &"LeftUpperArm"]]:
		var fist := rig.get_point_position(pair[0])
		assert_lt(fist.distance_to(victim.get_point_position(pair[1])), 0.15, "%s on the victim's shoulder" % pair[0])


func test_eye_point_stays_steady_through_strikes() -> void:
	# The first-person camera rides EyePoint (Spec §5: steady camera). Spins orbit the eye
	# around the neck and the stomp leans over a downed body, so they are left out.
	var rig := _rig()
	rig.play(&"idle", 0.0)
	rig.advance(0.0)
	var idle := rig.get_point_position(&"EyePoint")
	for row: Array in MOVES:
		if [&"spinning_heel", &"spin_kick", &"stomp"].has(row[0]):
			continue
		var move := _move(row)
		rig.play(&"idle", 0.0)
		rig.advance(0.5)
		rig.play_move(move)
		var widest := 0.0
		for i: int in move.total_frames():
			rig.advance(FRAME)
			widest = maxf(widest, rig.get_point_position(&"EyePoint").distance_to(idle))
		assert_lt(widest, 0.22, "%s moves EyePoint at most 0.22 m" % row[0])


func test_punches_come_into_first_person_view() -> void:
	var rig := _rig(true)
	var fists := {
		&"jab_1": &"Left", &"jab_2": &"Right", &"hook": &"Left", &"uppercut": &"Right",
		&"haymaker": &"Right",
	}
	for id: StringName in fists:
		_to_first_active_frame(rig, _move_by_id(id))
		var side: String = fists[id]
		for point: StringName in [StringName(side + "FistPoint"), StringName(side + "Hand")]:
			var view := _view(rig, point)
			assert_true(_in_fp_view(view), "%s %s in the first-person view (angles %s)" % [id, point, view])
			assert_lt(view.y, 5.0, "%s %s in the lower half or center" % [id, point])
			assert_gt(view.x, -20.0, "%s %s lower-center or right" % [id, point])


func test_kicks_come_into_first_person_view() -> void:
	var rig := _rig(true)
	for id: StringName in [&"front_kick", &"roundhouse", &"stomp_kick", &"push_kick", &"flying_kick"]:
		_to_first_active_frame(rig, _move_by_id(id))
		# The flying kick dives at the target, with the camera pitched further down.
		var pitch := -25.0 if id == &"flying_kick" else -10.0
		var view := _view(rig, &"RightFootPoint", pitch, 0.05)
		assert_true(_in_fp_view(view), "%s foot in the pitched-down view (angles %s)" % [id, view])
		assert_lt(view.y, 0.0, "%s foot in the lower part of the view" % id)
	# Straight kicks land sole first: the ankle stays (nearly) in front of a target at
	# arm's length, so the shoe is not hidden inside the target's belly.
	for id: StringName in [&"front_kick", &"stomp_kick", &"push_kick", &"flying_kick"]:
		_to_first_active_frame(rig, _move_by_id(id))
		var ankle := _local(rig, &"RightFoot")
		assert_gt(ankle.z, -0.77, "%s ankle in front of the target at %s" % [id, _fmt(ankle)])


func test_guard_fists_show_at_the_bottom_of_the_first_person_view() -> void:
	var rig := _rig(true)
	for point: StringName in [&"LeftFistPoint", &"RightFistPoint"]:
		var view := _view(rig, point)
		assert_lt(view.y, -15.0, "%s low in the view" % point)
		assert_gt(view.y, -FP_HALF_V_DEG - 6.0, "%s at least partly on screen (angles %s)" % [point, view])


func test_unknown_moves_fall_back_to_a_generic_strike() -> void:
	var punch := MoveData.new()
	punch.id = &"mystery_punch"
	var spec := HitboxSpec.new()
	spec.point = &"LeftFistPoint"
	punch.hitboxes = [spec]
	var kick := MoveData.new()
	kick.id = &"mystery_kick"
	var foot := HitboxSpec.new()
	foot.point = &"RightFootPoint"
	kick.hitboxes = [foot]
	assert_false(PlaceholderAnims.fallback_is_kick(punch), "fist hitbox -> generic punch")
	assert_true(PlaceholderAnims.fallback_is_kick(kick), "foot hitbox -> generic kick")
	var rig := _rig()
	PlaceholderAnims.warn_on_fallback = false
	_to_first_active_frame(rig, punch)
	PlaceholderAnims.warn_on_fallback = true
	assert_almost_eq(_current_animation(rig).length, punch.total_frames() * FRAME, 1e-4)
	var fist := _local(rig, &"LeftFistPoint")
	assert_lt(fist.z, -0.6, "the generic punch extends the left fist at %s" % _fmt(fist))


# --- Locomotion ------------------------------------------------------------------------


func test_locomotion_picks_the_dominant_direction() -> void:
	var rig := _rig()
	var cases := [
		[Vector2(0.0, 1.0), 1.0, &"walk_forward"], [Vector2(0.2, -1.0), 0.5, &"walk_back"],
		[Vector2(1.0, 0.3), 0.8, &"walk_right"], [Vector2(-1.0, -0.4), 0.6, &"walk_left"],
		[Vector2(0.0, 1.0), 0.05, &"idle"], [Vector2.ZERO, 0.7, &"idle"],
	]
	for c: Array in cases:
		var dir: Vector2 = c[0]
		var ratio: float = c[1]
		rig.play_locomotion(dir, ratio)
		assert_eq(rig.current_anim(), c[2], "%s at %.2f" % [dir, ratio])
		if c[2] != &"idle":
			assert_almost_eq(rig.anim_player.speed_scale, ratio, 0.01, "plays at the speed ratio")
	rig.play_locomotion(Vector2(0.0, 1.0), 1.0)
	rig.advance(0.2)
	var pos := rig.anim_player.current_animation_position
	rig.play_locomotion(Vector2(0.1, 1.0), 0.7)
	assert_almost_eq(rig.anim_player.current_animation_position, pos, 1e-6, "same direction keeps the cycle going")
	assert_almost_eq(rig.anim_player.speed_scale, 0.7, 0.01, "only the speed changes")
	rig.advance(0.3)
	var swing := rig.get_point_position(&"RightFoot")
	rig.advance(0.25)
	assert_gt(rig.get_point_position(&"RightFoot").distance_to(swing), 0.02, "the walk moves the legs")
