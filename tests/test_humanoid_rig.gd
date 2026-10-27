extends GutTest
## HumanoidRig (game/actors/humanoid_rig.gd) and its placeholder pose and animation
## builders: skeleton, rig points, hurtboxes, layers, the animation library, move timing
## and the "Strike reach" envelopes of docs/ARCHITECTURE.md.

const FPView := preload("res://tests/fp_view.gd")

const FRAME := 1.0 / 60.0
## First-person view (see tests/fp_view.gd): FOV half-angles at 16:9 and the default grid.
const FP_HALF_H_DEG := FPView.HALF_H_DEG
const FP_HALF_V_DEG := FPView.HALF_V_DEG
const FP_COLS := FPView.COLS
## Distance between two fighters' centers in the strike tests (docs/ARCHITECTURE.md).
const TARGET_DISTANCE := 0.85
## An enemy's head parts: what the player sees of its face (cap, shades, face).
const ENEMY_HEAD: Array[String] = ["Head", "Cap", "Hair", "CapBrim", "Shades", "ShadesFront"]

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
	&"block", &"block_hit", &"guard_break", &"recoil",
	&"grab", &"hold", &"held", &"thrown", &"pickup", &"haymaker_charge",
	&"flinch_head_front", &"flinch_head_left", &"flinch_head_right", &"flinch_gut",
	&"flinch_legs", &"stagger_back", &"stagger_left", &"stagger_right", &"stagger_forward",
	&"launched", &"knockdown_back", &"knockdown_forward", &"downed_back", &"downed_front",
	&"getup_back", &"getup_front", &"ko_back", &"ko_front",
	# Milestone 3 enemies (placeholder clips until their packages author them).
	&"taunt", &"brace", &"run_forward", &"hold_collar", &"held_collar", &"held_lift",
]

## Looping or holding animations (everything else plays once and holds its last pose).
const LOOPING: Array[StringName] = [
	&"idle", &"walk_forward", &"walk_back", &"walk_left", &"walk_right",
	&"block", &"hold", &"held", &"downed_back", &"downed_front",
	&"run_forward", &"hold_collar", &"held_collar", &"held_lift",
]

## docs/ARCHITECTURE.md moves table: [id, startup, active, recovery].
const MOVES: Array = [
	[&"jab_1", 4, 3, 10], [&"jab_2", 4, 3, 10], [&"hook", 6, 3, 14], [&"uppercut", 8, 3, 22],
	[&"body_flurry", 2, 2, 6], [&"shove", 6, 3, 18], [&"spinning_backfist", 12, 3, 20],
	[&"front_kick", 7, 3, 14],
	[&"roundhouse", 9, 3, 16], [&"spinning_heel", 12, 5, 24], [&"stomp_kick", 10, 3, 22],
	[&"push_kick", 8, 3, 20], [&"haymaker", 14, 3, 26], [&"flying_kick", 5, 8, 14],
	[&"spin_kick", 6, 10, 16], [&"back_elbow", 5, 3, 18], [&"knee", 5, 3, 12],
	[&"throw", 8, 2, 20], [&"stomp", 8, 3, 14], [&"pipe_swing_1", 7, 3, 12],
	[&"pipe_swing_2", 7, 3, 12], [&"pipe_swing_3", 9, 4, 20], [&"weapon_throw", 6, 1, 14],
	[&"impact_body_knockdown", 0, 1, 0], [&"impact_body_stagger", 0, 1, 0],
	[&"dummy_jab", 24, 3, 16],
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
		Reach.new(&"dummy_jab", [&"RightFistPoint"], -0.65, 1.35, 1.65, 0.14, &"stand", head, fist_bury),
		Reach.new(&"hook", [&"LeftFistPoint"], -0.5, 1.35, 1.65, 0.14, &"stand", head, fist_bury),
		Reach.new(&"uppercut", [&"RightFistPoint"], -0.45, 1.4, 1.8, 0.14, &"stand", head, fist_bury),
		Reach.new(&"shove", [&"LeftFistPoint", &"RightFistPoint"], -0.55, 1.1, 1.45, 0.16, &"stand", torso, fist_bury),
		Reach.new(&"spinning_backfist", [&"RightFistPoint"], -0.65, 1.35, 1.65, 0.15, &"stand", head, fist_bury),
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


func before_all() -> void:
	# First-person checks use the shipped lens offsets (Tuning defaults).
	Tuning.apply(TuningData.new())


func after_all() -> void:
	Tuning.apply(TuningData.new())


## A rig dressed like an enemy (the boxer stance and gloves), under `parent` if given.
func _rig(first_person: bool = false, height: float = 1.8, actor: Node3D = null,
		parent: Node = null) -> HumanoidRig:
	var rig := HumanoidRig.new()
	rig.first_person_body = first_person
	rig.height = height
	rig.actor = actor
	_adopt(rig, parent)
	rig.build()
	return rig


## A rig dressed like the player (PlayerCharacter._configure_rig()): first-person body,
## relaxed stance, wrapped hands and the player's colors. Under `parent` if given.
func _player_rig(parent: Node = null) -> HumanoidRig:
	var rig := HumanoidRig.new()
	var dresser := PlayerCharacter.new()
	dresser._configure_rig(rig)
	dresser.free()
	assert_true(rig.first_person_body and rig.wrapped_hands and rig.stance == PlaceholderPoses.STANCE_RELAXED)
	_adopt(rig, parent)
	rig.build()
	return rig


## Add `rig` to `parent` (freed with it), or to the test (freed after it).
func _adopt(rig: HumanoidRig, parent: Node) -> void:
	if parent:
		parent.add_child(rig)
	else:
		add_child_autofree(rig)


## One rig per stance: a boxer (enemies, the default) and the player's relaxed rig. Strikes
## must reach the same envelopes in both.
func _stance_rigs() -> Array[HumanoidRig]:
	return [_rig(), _player_rig()]


## `id` with the rig's stance, for failure messages.
func _tag(rig: HumanoidRig, id: StringName) -> String:
	return "%s (%s)" % [id, rig.stance]


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


## How `rig` faces (its yaw; the rigs in these tests face -Z).
func _facing(rig: HumanoidRig) -> Basis:
	return rig.global_basis.orthonormalized()


## Where the first-person lens sits for `rig`: EyePoint dropped by `drop` (a move's camera
## drop) plus FirstPersonCamera.lens_offset() for the rig's facing, exactly as the camera
## places it (Tuning's height and forward offsets).
func _lens(rig: HumanoidRig, drop: float = 0.0) -> Vector3:
	return rig.get_point_position(&"EyePoint") + Vector3.DOWN * drop + FirstPersonCamera.lens_offset(_facing(rig))


## The first-person camera of `rig`: the lens, looking the way the rig faces, pitched by
## `pitch_deg`.
func _fp_camera(rig: HumanoidRig, pitch_deg: float = 0.0, drop: float = 0.0) -> Transform3D:
	return Transform3D(_facing(rig) * Basis.from_euler(Vector3(deg_to_rad(pitch_deg), 0.0, 0.0)), _lens(rig, drop))


## Camera-space angles (degrees: x = right of center, y = above center) of a rig point
## seen through _fp_camera(rig, pitch_deg, drop). z is the distance in front of the camera.
func _view(rig: HumanoidRig, point: StringName, pitch_deg: float = 0.0, drop: float = 0.0) -> Vector3:
	return _view_from(_fp_camera(rig, pitch_deg, drop), rig.get_point_position(point))


func _view_from(cam: Transform3D, world: Vector3) -> Vector3:
	var q := cam.basis.inverse() * (world - cam.origin)
	return Vector3(rad_to_deg(atan2(q.x, -q.z)), rad_to_deg(atan2(q.y, -q.z)), -q.z)


func _in_fp_view(view: Vector3) -> bool:
	return view.z > 0.05 and absf(view.x) < FP_HALF_H_DEG and absf(view.y) < FP_HALF_V_DEG


## True when a point given as _view() angles lies in the upper third of the view.
func _in_upper_third(view: Vector3) -> bool:
	return _in_fp_view(view) and tan(deg_to_rad(view.y)) > tan(deg_to_rad(FP_HALF_V_DEG)) / 3.0


## Angle (degrees) between the view center and a point given as _view() angles; 180 for a
## point behind the camera.
func _off_center_deg(view: Vector3) -> float:
	if view.z <= 0.0:
		return 180.0
	var off := Vector2(tan(deg_to_rad(view.x)), tan(deg_to_rad(view.y)))
	return rad_to_deg(atan(off.length()))


func _meshes_under(node: Node) -> Array[MeshInstance3D]:
	return FPView.meshes_under(node)


## What `cam` sees of `rig`'s own body (FPView.hits()).
func _fp_hits(rig: HumanoidRig, cam: Transform3D, cols: int = FP_COLS,
		skip: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	return FPView.hits(rig, cam, cols, skip)


## Share of the view (0..1) whose nearest body mesh (from _fp_hits()) passes `keep`.
func _share(hits: Array[MeshInstance3D], keep: Callable) -> float:
	return FPView.share(hits, keep)


## Share of the view any of the body covers.
func _body_share(hits: Array[MeshInstance3D]) -> float:
	return FPView.covered(hits)


## Share of the view covered by the meshes of the parts in `names`.
func _parts_share(hits: Array[MeshInstance3D], names: Array[String]) -> float:
	return _share(hits, func(m: MeshInstance3D) -> bool: return names.has(String(m.name)))


## Nearest distance from the lens of `cam` to the surface of `rig`'s drawn parts in `names`.
func _nearest_part(rig: HumanoidRig, cam: Transform3D, names: Array[String]) -> float:
	return FPView.nearest_mesh(rig, cam.origin, func(m: MeshInstance3D) -> bool: return names.has(String(m.name)))


## True when the cells of the parts in `from` connect, through cells of the parts in
## `through` (4-neighbours), to the bottom row or a side column of the view: the limb comes
## in from the edge instead of floating in mid-view.
func _reaches_edge(hits: Array[MeshInstance3D], from: Array[String], through: Array[String], cols: int = FP_COLS) -> bool:
	var rows := hits.size() / cols
	var seen := {}
	var stack: Array[int] = []
	for i: int in hits.size():
		if hits[i] and from.has(String(hits[i].name)):
			stack.append(i)
			seen[i] = true
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var col := i % cols
		var row := i / cols
		if col == 0 or col == cols - 1 or row == rows - 1:
			return true
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c := col + step.x
			var r := row + step.y
			if c < 0 or c >= cols or r < 0 or r >= rows:
				continue
			var j := r * cols + c
			if seen.has(j) or hits[j] == null or not through.has(String(hits[j].name)):
				continue
			seen[j] = true
			stack.append(j)
	return false


## Forearm and hand part names of `side` (&"Left" or &"Right").
func _arm_parts(side: String) -> Array[String]:
	var out: Array[String] = []
	for part: String in ["Forearm", "Wrap", "Fist", "Fingers", "Strap", "Hand", "KnuckleWrap", "WristWrap", "GloveBack"]:
		out.append(side + part)
	return out


## Every part of the `side` arm the first-person camera draws: the elbow end of the upper
## arm, the forearm and the hand.
func _whole_arm_parts(side: String) -> Array[String]:
	var out := _arm_parts(side)
	out.append(side + "Elbow")
	return out


## Hand part names of `side`: an enemy's glove (Fist, Fingers, Strap) or the player's
## wrapped hand.
func _hand_parts(side: String) -> Array[String]:
	var out: Array[String] = []
	for part: String in ["Fist", "Fingers", "Strap", "Hand", "KnuckleWrap", "WristWrap", "GloveBack"]:
		out.append(side + part)
	return out


func _foot_parts(side: String) -> Array[String]:
	var out: Array[String] = []
	for part: String in ["Shoe", "Sole", "ToeCap", "ToeSole"]:
		out.append(side + part)
	return out


## Names of every mesh part of `rig`.
func _part_names(rig: HumanoidRig) -> Array[String]:
	var out: Array[String] = []
	for mesh: MeshInstance3D in _meshes_under(rig):
		out.append(String(mesh.name))
	return out


## Rows (0 = top) and columns of the cells whose nearest mesh is one of `names`.
func _cells_of(hits: Array[MeshInstance3D], names: Array[String], cols: int = FP_COLS) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in hits.size():
		if hits[i] and names.has(String(hits[i].name)):
			out.append(Vector2i(i % cols, i / cols))
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


func test_the_players_trousers_stand_apart_from_its_shirt() -> void:
	# In the first-person hold the rising knee sits beside the shaded right sleeve. Trousers
	# in the shirt's navy darkened merged the two into one blue lump (M2 phase 3 review);
	# gray ones stand apart from it and from the held head's dark hair.
	var player := _player_rig()
	var enemy := _rig()
	var shirt := _paint_color(player, PlaceholderBody.Paint.BODY)
	var pants := _paint_color(player, PlaceholderBody.Paint.PANTS)
	assert_eq(pants, player.pants_color, "the player's own trousers")
	assert_eq(_paint_color(player, PlaceholderBody.Paint.BODY), player.body_color)
	assert_lte(pants.s, shirt.s * 0.3, "a neutral gray against the shirt's navy, not the navy darkened")
	# Lighter than the dark paint: the belt shows on them, and the rising knee stands apart
	# from the held enemy's dark hair beside it.
	assert_gt(pants.get_luminance(), _paint_color(player, PlaceholderBody.Paint.DARK).get_luminance() + 0.15,
			"a mid gray, well clear of the dark paint")
	# Enemies and dummies keep trousers in their shirt's color darkened.
	var enemy_pants := _paint_color(enemy, PlaceholderBody.Paint.PANTS)
	assert_eq(enemy.pants_color.a, 0.0, "no pants color of their own")
	assert_almost_eq(enemy_pants.h, enemy.body_color.h, 0.01, "the enemy's shirt hue")
	assert_lt(enemy_pants.v, enemy.body_color.v, "darkened")
	enemy.pants_color = Color(0.3, 0.2, 0.1)
	assert_eq(_paint_color(enemy, PlaceholderBody.Paint.PANTS), Color(0.3, 0.2, 0.1), "set after build, it repaints them")
	for rig: HumanoidRig in [player, enemy]:
		var colors: Array[Color] = []
		for mesh: MeshInstance3D in _meshes_under(rig):
			var color := (mesh.material_override as StandardMaterial3D).albedo_color
			if not colors.has(color):
				colors.append(color)
		assert_between(colors.size(), 4, 6, "%s: 4 to 6 flat colors (Spec §10)" % rig.stance)


## The albedo of `rig`'s parts painted `paint` (PlaceholderBody.Paint).
func _paint_color(rig: HumanoidRig, paint: int) -> Color:
	var mats: Dictionary[int, StandardMaterial3D] = rig.get(&"_materials")
	return mats[paint].albedo_color


func test_first_person_body_hides_only_head_neck_chest_and_shoulder_ends() -> void:
	var fp := _rig(true)
	var hidden := CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN)
	var default := CombatTypes.bit(CombatTypes.VIS_DEFAULT)
	var head_meshes: Array[MeshInstance3D] = []
	for bone: StringName in PlaceholderBody.FP_HIDDEN_BONES:
		head_meshes.append_array(_meshes_under(fp.get_attachment(bone)))
	for part: StringName in PlaceholderBody.FP_HIDDEN_PARTS:
		head_meshes.append(fp.find_child(String(part), true, false) as MeshInstance3D)
	assert_gt(head_meshes.size(), 6, "head, cap, shades, neck, chest, shoulder balls and shoulder ends")
	assert_false(head_meshes.has(null), "every FP_HIDDEN_PARTS part exists")
	for bone: StringName in [&"RightLowerArm", &"RightHand", &"Spine", &"Hips", &"LeftUpperLeg", &"LeftFoot"]:
		assert_true(_meshes_under(fp.get_attachment(bone)).all(
			func(m: MeshInstance3D) -> bool: return m.layers == default), "%s meshes stay visible" % bone)
	for side: String in ["Left", "Right"]:
		var elbow := fp.find_child(side + "Elbow", true, false) as MeshInstance3D
		assert_not_null(elbow, "the %s upper arm has an elbow end" % side)
		if elbow:
			assert_eq(elbow.layers, default, "the elbow end of the %s upper arm stays visible" % side)
	for mesh: MeshInstance3D in _meshes_under(fp):
		var expected := hidden if head_meshes.has(mesh) else default
		assert_eq(mesh.layers, expected, "%s render layers" % mesh.name)
	var third := _rig(false)
	for mesh: MeshInstance3D in _meshes_under(third):
		assert_eq(mesh.layers, default, "%s on layer 1 for a third-person body" % mesh.name)
	fp.first_person_body = false
	for mesh: MeshInstance3D in head_meshes:
		assert_eq(mesh.layers, default, "turning first_person_body off shows the head again")


func test_upper_arm_parts_join_into_one_limb() -> void:
	# The shoulder end and the elbow end of the upper arm are capsules of one radius on one
	# axis whose union runs from the shoulder to the elbow joint without a gap.
	var rig := _rig()
	var parts: Dictionary[String, PlaceholderBody.Part] = {}
	for part: PlaceholderBody.Part in PlaceholderBody.parts():
		parts[String(part.name)] = part
	for side: String in ["Left", "Right"]:
		var top: PlaceholderBody.Part = parts[side + "UpperArm"]
		var low: PlaceholderBody.Part = parts[side + "Elbow"]
		assert_eq(top.bone, low.bone, "%s upper arm parts share the bone" % side)
		assert_almost_eq(top.size.x, low.size.x, 1e-6, "%s upper arm parts share the radius" % side)
		var r := top.size.x
		var top_low := top.offset.y - top.size.y * 0.5
		var low_high := low.offset.y + low.size.y * 0.5
		# The shoulder end's straight part reaches past the elbow end's rounded top.
		assert_lt(top_low + r, low_high - r + 1e-6, "%s: no waist where the parts meet" % side)
		var elbow_joint := PlaceholderBody.BONE_REST[StringName(side + "LowerArm")].y
		var low_end := low.offset.y - low.size.y * 0.5
		assert_between(elbow_joint, low_end, low_end + r, "%s: the elbow end rounds off over the elbow joint" % side)
	assert_not_null(rig.find_child("LeftElbow", true, false), "the rig builds the elbow ends")


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


## Bounds of `rig`'s hand parts on `side`, in the hand bone's frame.
func _hand_bounds(rig: HumanoidRig, side: String) -> AABB:
	var bounds := AABB()
	var first := true
	for name: String in _hand_parts(side):
		var part := rig.get_attachment(StringName(side + "Hand")).get_node_or_null(name) as MeshInstance3D
		if part == null:
			continue
		var box := part.transform * part.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


## The albedo colors of `rig`'s hand parts on `side`.
func _hand_colors(rig: HumanoidRig, side: String) -> Array[Color]:
	var out: Array[Color] = []
	for name: String in _hand_parts(side):
		var part := rig.get_attachment(StringName(side + "Hand")).get_node_or_null(name) as MeshInstance3D
		if part and not out.has((part.material_override as StandardMaterial3D).albedo_color):
			out.append((part.material_override as StandardMaterial3D).albedo_color)
	return out


func test_hands_are_slightly_oversized_one_size_and_keep_the_rig_points() -> void:
	# Spec §10: slightly oversized hands; the player's are wrapped with fingerless gloves.
	# Enemies wear dark fingerless gloves of the same size. This test pinned the enemies'
	# old fist blocks (0.12 x 0.13 x 0.135 m) as the reference the player's hands were
	# 70-80% of; Game-boy's first-person playtest shrank the enemies' fists to the player's
	# hand size (their guard's gloves filled the view at sparring range), so both are now
	# held to about 70-75% of that old block (the player's glove plate adds a little), still
	# at least 0.1 m across.
	var old_block := 0.12 * 0.13 * 0.135
	var enemy := _rig()
	var player := _player_rig()
	for side: String in ["Left", "Right"]:
		var hand_bone := StringName(side + "Hand")
		var glove := enemy.get_attachment(hand_bone).get_node_or_null(side + "Fist") as MeshInstance3D
		assert_not_null(glove, "enemies wear a %s glove" % side)
		assert_null(player.get_attachment(hand_bone).get_node_or_null(side + "Fist"), "the player has no %s glove" % side)
		assert_null(enemy.find_child(side + "Wrap", true, false), "no wrap on the enemy's %s forearm" % side)
		for rig: HumanoidRig in [enemy, player]:
			var bounds := _hand_bounds(rig, side)
			var ratio := bounds.get_volume() / old_block
			assert_between(ratio, 0.7, 0.78, "%s: the %s hand is %.0f%% of the old fist block's volume" % [
					rig.stance, side, ratio * 100.0])
			assert_gte(minf(bounds.size.x, minf(bounds.size.y, bounds.size.z)), 0.1, "%s: the %s fist is still slightly oversized" % [
					rig.stance, side])
			# The strike points stay where they were: the fist point at the hand's center.
			assert_almost_eq(bounds.get_center().distance_to(PlaceholderBody.POINT_OFFSET[StringName(side + "FistPoint")]), 0.0, 0.005,
					"%s: the %s fist point is the center of the hand" % [rig.stance, side])
			var on_hand := rig.get_point_transform(hand_bone).affine_inverse() * rig.get_point_position(StringName(side + "FistPoint"))
			assert_almost_eq(on_hand, PlaceholderBody.POINT_OFFSET[StringName(side + "FistPoint")], Vector3.ONE * 1e-4)
			assert_almost_eq(rig.get_point_position(&"WeaponGrip").distance_to(rig.get_point_position(&"RightFistPoint")),
					0.0, 0.03, "%s: WeaponGrip sits in the right fist" % rig.stance)
			assert_almost_eq(rig.get_point_position(&"WeaponGrip").distance_to(rig.get_point_position(&"WeaponTip")),
					0.7, 0.01, "%s: WeaponTip is 0.7 m along the weapon" % rig.stance)
		var skin := player.get_attachment(hand_bone).get_node(side + "Hand") as MeshInstance3D
		assert_eq((glove.mesh as BoxMesh).size, (skin.mesh as BoxMesh).size, "the enemy's %s glove is the player's hand size" % side)
		assert_almost_eq(glove.position, skin.position, Vector3.ONE * 1e-6, "on the same spot of the %s hand bone" % side)
		# The player: a skin-colored hand, light wraps and a dark glove plate.
		var colors := _hand_colors(player, side)
		assert_has(colors, player.skin_color, "a skin-colored %s hand" % side)
		assert_has(colors, player.accent_color, "light %s wraps" % side)
		assert_eq(colors.size(), 3, "skin, wraps and a dark glove accent")
		assert_eq((skin.material_override as StandardMaterial3D).albedo_color, player.skin_color)
		# An enemy: a dark glove, the bare fingers and a strap in the accent color.
		colors = _hand_colors(enemy, side)
		var glove_color := (glove.material_override as StandardMaterial3D).albedo_color
		assert_lt(glove_color.get_luminance(), 0.1, "a dark %s glove" % side)
		assert_has(colors, enemy.skin_color, "bare %s fingers" % side)
		assert_has(colors, enemy.accent_color, "a %s strap in the accent color" % side)
		assert_eq(colors.size(), 3, "glove, fingers and strap")
	for rig: HumanoidRig in [enemy, player]:
		var colors: Array[Color] = []
		for mesh: MeshInstance3D in _meshes_under(rig):
			var color := (mesh.material_override as StandardMaterial3D).albedo_color
			if not colors.has(color):
				colors.append(color)
		assert_between(colors.size(), 4, 6, "%s: 4 to 6 flat colors (Spec §10)" % rig.stance)


func test_hand_boxes_never_share_a_face_plane() -> void:
	# Two boxes with faces in one plane flicker between their colors (z-fighting): each wrap,
	# strap or finger band caps the hand's face it ends at (or stops short of it), never
	# ends flush with it. The player's wrapped hands and the enemies' gloves.
	for wrapped: bool in [true, false]:
		var boxes: Array[PlaceholderBody.Part] = []
		for part: PlaceholderBody.Part in PlaceholderBody.parts(wrapped):
			if part.shape == PlaceholderBody.Shape.BOX and String(part.bone).ends_with("Hand"):
				boxes.append(part)
		assert_gte(boxes.size(), 8 if wrapped else 6, "hand and its bands on each hand")
		_assert_no_flush_faces(boxes)


func _assert_no_flush_faces(boxes: Array[PlaceholderBody.Part]) -> void:
	for i: int in boxes.size():
		var a := boxes[i]
		assert_eq(a.rot_deg, Vector3.ZERO, "%s is axis-aligned on its bone" % a.name)
		for j: int in range(i + 1, boxes.size()):
			var b := boxes[j]
			if a.bone != b.bone:
				continue
			for axis: int in 3:
				for face_a: float in [-0.5, 0.5]:
					for face_b: float in [-0.5, 0.5]:
						if absf(a.offset[axis] + face_a * a.size[axis] - b.offset[axis] - face_b * b.size[axis]) > 0.0005:
							continue
						# Flush faces only fight where they overlap.
						var overlap := true
						for other: int in 3:
							if other == axis:
								continue
							var lo := maxf(a.offset[other] - a.size[other] * 0.5, b.offset[other] - b.size[other] * 0.5)
							var hi := minf(a.offset[other] + a.size[other] * 0.5, b.offset[other] + b.size[other] * 0.5)
							overlap = overlap and hi - lo > 1e-6
						assert_false(overlap, "%s and %s share a face plane (axis %d)" % [a.name, b.name, axis])


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
	# when they come down on the other face, nor drop flat and bounce back up into the
	# fall (rolling onto the front must not dip below the pose it lands in). The head
	# never rises more than 5 cm above the lowest point it has reached so far (the
	# downed_* breathing moves it about 3.5 cm). Blend times as in CombatActor.
	var rig := _rig()
	var falls := {
		&"ko_back": 0.1, &"ko_front": 0.1, &"knockdown_back": 0.03, &"knockdown_forward": 0.03,
		&"downed_back": 0.08, &"downed_front": 0.08,
	}
	for from: StringName in [&"launched", &"thrown"]:
		for t: float in [0.0, 0.1, 0.15, 0.2, 0.25, 0.3, 0.45, 0.7]:
			for anim: StringName in falls:
				rig.play(from, 0.0)
				rig.advance(0.0)
				rig.advance(t)
				var lowest := rig.get_point_position(&"Head").y
				rig.play(anim, falls[anim])
				var rebound := 0.0
				var worst_frame := 0
				for i: int in 60:
					rig.advance(FRAME)
					var y := rig.get_point_position(&"Head").y
					if y - lowest > rebound:
						rebound = y - lowest
						worst_frame = i + 1
					lowest = minf(lowest, y)
				assert_lt(rebound, 0.05, "%s from %s at %.2f s: head rises %.3f m above its lowest (frame %d)" % [
						anim, from, t, rebound, worst_frame])
				assert_lt(rig.get_point_position(&"Head").y, 0.4, "%s from %s at %.2f s ends lying" % [
						anim, from, t])


func test_spins_turn_a_full_circle_and_back_elbow_does_not() -> void:
	for rig: HumanoidRig in _stance_rigs():
		for id: StringName in [&"spinning_heel", &"spin_kick", &"spinning_backfist", &"back_elbow"]:
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
				assert_almost_eq(absf(total), 360.0, 10.0, "%s turns the body a full circle" % _tag(rig, id))


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
	for rig: HumanoidRig in _stance_rigs():
		for row: Array in MOVES:
			var move := _move(row)
			rig.play_move(move)
			var anim := _current_animation(rig)
			assert_almost_eq(anim.length, move.total_frames() * FRAME, 1e-4, "%s length" % _tag(rig, move.id))
			assert_eq(anim.loop_mode, Animation.LOOP_NONE, "%s plays once" % _tag(rig, move.id))
			var track := _track(anim, "Skeleton3D:RightUpperArm")
			var strike_t := move.startup * FRAME
			var end_t := (move.startup + move.active) * FRAME
			assert_gte(anim.track_find_key(track, strike_t, Animation.FIND_MODE_APPROX), 0,
					"%s keys the strike pose at startup / 60 s" % _tag(rig, move.id))
			assert_gte(anim.track_find_key(track, end_t, Animation.FIND_MODE_APPROX), 0,
					"%s keys the end of the active frames" % _tag(rig, move.id))
			if move.startup > 1:
				var windup_key := false
				for k: int in anim.track_get_key_count(track):
					var t := anim.track_get_key_time(track, k)
					windup_key = windup_key or (t >= strike_t * 0.4 - 1e-4 and t <= strike_t * 0.6 + 1e-4)
				assert_true(windup_key, "%s has a wind-up key at 40-60%% of startup" % _tag(rig, move.id))
			for bone: StringName in BONES:
				if bone == &"Root":
					continue
				var t_bone := _track(anim, "Skeleton3D:%s" % bone)
				var start := anim.rotation_track_interpolate(t_bone, 0.0)
				var finish := anim.rotation_track_interpolate(t_bone, anim.length)
				# The throw starts in the hold and lands in the stance (checked in
				# test_player_moves_and_animations_start_and_end_in_the_relaxed_stance()).
				if move.id != &"throw":
					assert_lt(rad_to_deg(start.angle_to(finish)), 0.5, "%s returns %s to guard" % [_tag(rig, move.id), bone])
				if not [&"spinning_heel", &"spin_kick", &"spinning_backfist"].has(move.id):
					var a := anim.rotation_track_interpolate(t_bone, strike_t)
					var b := anim.rotation_track_interpolate(t_bone, end_t)
					assert_lt(rad_to_deg(a.angle_to(b)), 0.5, "%s holds the strike pose (%s)" % [_tag(rig, move.id), bone])


func test_player_moves_and_animations_start_and_end_in_the_relaxed_stance() -> void:
	# The player's relaxed stance is where everything starts and lands: every move (from
	# idle and, for the haymaker, released from its charge), the dodges, the landing, the
	# pickup, the hit reactions and the get-ups. Clinch moves start in the hold (the knee
	# ends there too, the throw, with nothing left to hold, in the stance), pipe moves start
	# and end in the relaxed weapon carry, and air moves in the air guard.
	var rig := _player_rig()
	rig.play(&"idle", 0.0)
	rig.advance(0.0)
	var points: Array[StringName] = [&"LeftFistPoint", &"RightFistPoint", &"LeftFootPoint", &"RightFootPoint", &"EyePoint"]
	var stance: Array[Vector3] = []
	for point: StringName in points:
		stance.append(_local(rig, point))
	var check := func(what: String) -> void:
		for i: int in points.size():
			assert_almost_eq(_local(rig, points[i]), stance[i], Vector3.ONE * 0.01, "%s: %s in the stance" % [what, points[i]])
	var other: Array[StringName] = [&"knee", &"pipe_swing_1", &"pipe_swing_2", &"pipe_swing_3",
			&"weapon_throw", &"flying_kick", &"spin_kick"]
	for row: Array in MOVES:
		var move := _move(row)
		rig.play(&"idle", 0.0)
		rig.advance(0.0)
		rig.play_move(move, 0.0)
		rig.advance(0.0)
		var start: Array[Vector3] = []
		for point: StringName in points:
			start.append(_local(rig, point))
		rig.advance(move.total_frames() * FRAME)
		if move.id == &"throw":
			check.call("throw end")
			continue
		if other.has(move.id):
			for i: int in points.size():
				assert_almost_eq(_local(rig, points[i]), start[i], Vector3.ONE * 0.01, "%s ends where it started" % move.id)
			continue
		for i: int in points.size():
			assert_almost_eq(start[i], stance[i], Vector3.ONE * 0.01, "%s starts in the stance (%s)" % [move.id, points[i]])
		check.call("%s end" % move.id)
	var haymaker := _move_by_id(&"haymaker")
	rig.play(&"haymaker_charge")
	rig.advance(0.5)
	rig.play_move(haymaker)
	rig.advance(haymaker.total_frames() * FRAME)
	check.call("haymaker released from its charge, end")
	for anim: StringName in [&"land", &"dodge_left", &"dodge_right", &"dodge_back", &"dodge_forward", &"pickup",
			&"flinch_head_front", &"flinch_head_left", &"flinch_head_right", &"flinch_gut", &"flinch_legs",
			&"stagger_back", &"stagger_left", &"stagger_right", &"stagger_forward", &"getup_back", &"getup_front"]:
		rig.play(anim, 0.0)
		rig.advance(0.0)
		rig.advance(rig.anim_player.get_animation(anim).length)
		check.call("%s end" % anim)
	for anim: StringName in [&"jump", &"grab", &"haymaker_charge"]:
		rig.play(anim, 0.0)
		rig.advance(0.0)
		check.call("%s start" % anim)
	# The walks swing the legs but keep the arms loose and low.
	for anim: StringName in [&"walk_forward", &"walk_back", &"walk_left", &"walk_right"]:
		rig.play(anim, 0.0)
		rig.advance(0.0)
		for k: int in 8:
			rig.advance(0.6 / 8.0)
			for side: String in ["Left", "Right"]:
				assert_lt(_local(rig, StringName(side + "FistPoint")).y, 1.05, "%s: the %s hand stays low" % [anim, side])


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
	for rig: HumanoidRig in _stance_rigs():
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
	for rig: HumanoidRig in _stance_rigs():
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
	for rig: HumanoidRig in _stance_rigs():
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
		# Without the charge it still winds up from the stance (the uncharged animation): it
		# passes through the cocked fist at its wind-up time.
		rig.play(&"idle", 0.0)
		rig.advance(0.5)
		var stance := _local(rig, &"RightFistPoint")
		rig.play_move(move, 0.0)
		rig.advance(PlaceholderAnims.windup_time(move))
		assert_gt(stance.distance_to(cocked), 0.15, "%s: the stance holds the fist away from the cocked spot" % rig.stance)
		assert_almost_eq(_local(rig, &"RightFistPoint"), cocked, Vector3.ONE * 0.02,
				"%s: the uncharged haymaker winds up through the cocked fist" % rig.stance)


func test_back_elbow_drives_back() -> void:
	for rig: HumanoidRig in _stance_rigs():
		var move := _move_by_id(&"back_elbow")
		_to_first_active_frame(rig, move)
		var elbow := _local(rig, &"RightElbowPoint")
		assert_gte(elbow.z, 0.3, "back_elbow elbow behind the body at %s" % _fmt(elbow))
		assert_between(elbow.y, 1.0, 1.6, "back_elbow at torso height")


func test_body_flurry_alternates_fists_at_gut_height() -> void:
	for rig: HumanoidRig in _stance_rigs():
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
	var target := _rig()
	for rig: HumanoidRig in _stance_rigs():
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


func test_the_stomp_lands_on_top_of_a_lying_body() -> void:
	# The stomp's foot went down to the floor through the lying body's torso (M2 phase 3
	# review): it comes down flat on top of the body (the target lies across the path, as in
	# the reach checks) and lifts off it again before it steps back.
	var target := _rig()
	var stomp := _move_by_id(&"stomp")
	for rig: HumanoidRig in _stance_rigs():
		_place_target(rig, target, &"downed")
		_to_first_active_frame(rig, stomp)
		var strike_sole := INF
		for f: int in stomp.active:
			if f > 0:
				rig.advance(FRAME)
			var deepest := -INF
			for sole: Vector3 in _right_sole(rig):
				deepest = maxf(deepest, _top_below(target, sole) - sole.y)
				strike_sole = minf(strike_sole, sole.y)
			assert_between(deepest, -0.05, 0.03, "%s: on active frame %d the sole rests on top of the body (%.3f m into it)" % [
					rig.stance, f, deepest])
		var highest := -INF
		for f: int in roundi(stomp.recovery * 0.5):
			rig.advance(FRAME)
			var low := INF
			for sole: Vector3 in _right_sole(rig):
				low = minf(low, sole.y)
			highest = maxf(highest, low)
		assert_gt(highest, strike_sole + 0.08, "%s: the foot lifts off the body before it steps back (to %.2f m from %.2f m)" % [
				rig.stance, highest, strike_sole])


## World positions of the right sole's heel, ball and toe tip (PlaceholderBody.SOLE_*).
func _right_sole(rig: HumanoidRig) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i: int in PlaceholderBody.SOLE_BONES.size():
		var bone := PlaceholderBody.SOLE_BONES[i]
		if String(bone).begins_with("Right"):
			out.append(rig.get_point_transform(bone) * (PlaceholderBody.SOLE_OFFSETS[i] * rig.rig_scale()))
	return out


## Height of the top of `rig`'s meshes straight below (or above) `point`, or -INF.
func _top_below(rig: HumanoidRig, point: Vector3) -> float:
	var from := Vector3(point.x, 3.0, point.z)
	var top := -INF
	for mesh: MeshInstance3D in _meshes_under(rig):
		var depth := FPView.ray_hit(mesh, from, Vector3.DOWN)
		if depth < INF:
			top = maxf(top, from.y - depth)
	return top


func test_pipe_swings_meet_the_head_without_passing_through_it() -> void:
	var target := _rig()
	var head := _hurtboxes_of(target, CombatTypes.Region.HEAD)[0]
	for rig: HumanoidRig in _stance_rigs():
		_place_target(rig, target, &"stand")
		for id: StringName in [&"pipe_swing_1", &"pipe_swing_2", &"pipe_swing_3"]:
			_to_first_active_frame(rig, _move_by_id(id))
			var grip := rig.get_point_position(&"WeaponGrip")
			var tip := rig.get_point_position(&"WeaponTip")
			var center := head.global_position
			var closest := Geometry3D.get_closest_point_to_segment(center, grip, tip)
			# 0.125 m is the head mesh radius (PlaceholderBody.parts()).
			assert_gt(closest.distance_to(center), 0.125 * 1.05,
					"%s: the pipe passes beside the head, not through it" % _tag(rig, id))
			# Nor through the neck (0.065 m mesh radius) into the chest.
			var neck := Geometry3D.get_closest_points_between_segments(grip, tip,
					target.get_point_position(&"Neck"), target.get_point_position(&"Head"))
			assert_gt(neck[0].distance_to(neck[1]), 0.09, "%s: the pipe passes beside the neck" % _tag(rig, id))
			assert_lt(tip.distance_to(center), head.radius + 0.2, "%s: the tip reaches the head" % _tag(rig, id))


## The first-person camera of `rig` holding an enemy, as FirstPersonCamera places it with
## the hold view at full weight (Tuning "Grab and weapons" > "Hold view"): the lens pulled
## back by grab_view_back_m and raised by grab_view_rise_m, the view pitched down by
## grab_view_pitch_deg, plus a move's own `pitch_deg` and `drop` (the knee's).
func _hold_fp_camera(rig: HumanoidRig, pitch_deg: float = 0.0, drop: float = 0.0) -> Transform3D:
	var lens := rig.get_point_position(&"EyePoint") + Vector3.DOWN * (drop - Tuning.data.grab_view_rise_m) \
			+ FirstPersonCamera.lens_offset(_facing(rig), Tuning.data.grab_view_back_m)
	var pitch := deg_to_rad(pitch_deg - Tuning.data.grab_view_pitch_deg)
	return Transform3D(_facing(rig) * Basis.from_euler(Vector3(pitch, 0.0, 0.0)), lens)


func test_held_victim_sits_low_in_the_holders_view() -> void:
	# Bent over in front of the holder, the victim fills the lower part of the hold view
	# (pitched down, Game-boy 2026-10-24): looking level, its shoulders and back sit below the
	# view center with the back of its head and its cap at the bottom edge (a knee's own
	# pitch brings the whole head in, test_grab_view.gd), and the upper third stays clear for
	# the fight around them.
	var rig := _player_rig()
	var victim := _rig()
	_place_target(rig, victim, &"held")
	var head := _hurtboxes_of(victim, CombatTypes.Region.HEAD)[0]
	var cam := _hold_fp_camera(rig)
	assert_gt(head.global_position.distance_to(cam.origin), 0.3, "the victim's head is not in the holder's face")
	var view := _view_from(cam, head.global_position)
	assert_between(view.y, -FP_HALF_V_DEG - 10.0, -FP_HALF_V_DEG + 5.0, "the victim's head sits at the bottom edge (angles %s)" % view)
	var seen := _fp_hits(victim, cam)
	assert_gt(_parts_share(seen, ENEMY_HEAD), 0.03, "the back of the victim's head and its cap show")
	assert_between(_body_share(seen), 0.15, 0.4, "the victim shows without filling the view (%.0f%%)" % (_body_share(seen) * 100.0))
	for cell: Vector2i in _cells_of(seen, _part_names(victim)):
		assert_gte(cell.y, FPView.rows() / 3, "the upper third of the view stays clear (cell %s)" % cell)
	# The holder's hands rest on the victim's shoulders (left fist on the victim's right).
	for pair: Array in [[&"LeftFistPoint", &"RightUpperArm"], [&"RightFistPoint", &"LeftUpperArm"]]:
		var fist := rig.get_point_position(pair[0])
		assert_lt(fist.distance_to(victim.get_point_position(pair[1])), 0.15, "%s on the victim's shoulder" % pair[0])


func test_the_held_head_shows_hair_not_a_bare_dome() -> void:
	# From the hold view the back of the held head was a bare skin dome, the biggest shape
	# in the view, with the cap's edge across it like a brow (M2 phase 3 review): dark hair
	# covers the back of the head, looking level and through the knee's own pitch.
	var rig := _player_rig()
	var victim := _rig()
	_place_target(rig, victim, &"held")
	victim.advance(0.0)
	var knee := load("res://game/combat/moves/knee.tres") as MoveData
	for view: Array in [[0.0, 0.0], [knee.camera_pitch_deg, knee.camera_drop_m]]:
		var seen := _fp_hits(victim, _hold_fp_camera(rig, view[0], view[1]))
		var head := _parts_share(seen, ENEMY_HEAD)
		var skin := _parts_share(seen, ["Head"])
		var hair := _parts_share(seen, ["Hair"])
		assert_gt(head, 0.03, "pitch %.0f: the held head shows" % view[0])
		assert_gt(hair, head * 0.6, "pitch %.0f: mostly as hair (%.1f%% of the view, the head %.1f%%)" % [
				view[0], hair * 100.0, head * 100.0])
		assert_lt(skin, head * 0.25, "pitch %.0f: little bare skin (%.1f%%)" % [view[0], skin * 100.0])


func test_eye_point_stays_steady_through_strikes() -> void:
	# The first-person camera rides EyePoint (Spec §5: steady camera). Spins orbit the eye
	# around the neck and the stomp leans over a downed body, so they are left out. Strike
	# poses are authored on the boxer guard's body, and the relaxed stance shares that body
	# (it differs in the arms), so a strike moves the eye no more from the relaxed stance
	# than from the guard: at most 3 cm further in all, and it lifts it at most 1 cm more
	# (punches at most about 2 cm in all, or what the boxer's own uppercut does).
	var travel := {}
	var rise := {}
	for rig: HumanoidRig in _stance_rigs():
		rig.play(&"idle", 0.0)
		rig.advance(0.0)
		var idle := rig.get_point_position(&"EyePoint")
		for row: Array in MOVES:
			if [&"spinning_heel", &"spin_kick", &"spinning_backfist", &"stomp"].has(row[0]):
				continue
			var move := _move(row)
			rig.play(&"idle", 0.0)
			rig.advance(0.5)
			rig.play_move(move)
			var widest := 0.0
			var highest := 0.0
			for i: int in move.total_frames():
				rig.advance(FRAME)
				var eye := rig.get_point_position(&"EyePoint")
				widest = maxf(widest, eye.distance_to(idle))
				highest = maxf(highest, eye.y - idle.y)
			assert_lt(widest, 0.22, "%s moves EyePoint at most 0.22 m" % _tag(rig, row[0]))
			travel[_tag(rig, row[0])] = widest
			rise[_tag(rig, row[0])] = highest
	var punches: Array[StringName] = [&"jab_1", &"jab_2", &"hook", &"uppercut", &"haymaker", &"body_flurry", &"shove"]
	for row: Array in MOVES:
		var boxer := "%s (%s)" % [row[0], PlaceholderPoses.STANCE_BOXER]
		var relaxed := "%s (%s)" % [row[0], PlaceholderPoses.STANCE_RELAXED]
		if not travel.has(relaxed):
			continue
		assert_lt(travel[relaxed], travel[boxer] + 0.03, "%s moves the eye %.3f m, the boxer's %.3f m" % [
				relaxed, travel[relaxed], travel[boxer]])
		assert_lt(rise[relaxed], rise[boxer] + 0.01, "%s lifts the eye %.3f m, the boxer's %.3f m" % [
				relaxed, rise[relaxed], rise[boxer]])
		if punches.has(row[0]):
			assert_lt(rise[relaxed], maxf(0.02, rise[boxer]) + 0.005, "%s lifts the eye %.3f m" % [relaxed, rise[relaxed]])


func test_punches_come_into_first_person_view() -> void:
	# Seen from the throat-height lens, a punch comes in from below or the side and reads
	# as a fist and forearm, and the body fills at most about a third of the view. The arm
	# reaches the edge of the view (the elbow end of the upper arm runs off it) instead of
	# a forearm floating in mid-view.
	var rig := _player_rig()
	# Move -> striking side(s). Straight punches show the forearm; the gut-level flurry and
	# the shove come in low, so only the fists rise into the bottom of the view.
	var punches := {
		&"jab_1": ["Left"], &"jab_2": ["Right"], &"hook": ["Left"], &"uppercut": ["Right"],
		&"haymaker": ["Right"], &"body_flurry": ["Left"], &"shove": ["Left", "Right"],
	}
	var low_blows: Array[StringName] = [&"body_flurry", &"shove"]
	var rows := FPView.rows()
	for id: StringName in punches:
		var move := _move_by_id(id)
		_to_first_active_frame(rig, move)
		for f: int in move.active:
			if f > 0:
				rig.advance(FRAME)
			var hits := _fp_hits(rig, _fp_camera(rig))
			assert_lt(_body_share(hits), 0.34, "%s frame %d: the body fills %.0f%% of the view" % [
					id, f, _body_share(hits) * 100.0])
			for side: String in punches[id]:
				assert_gt(_parts_share(hits, _hand_parts(side)), 0.004, "%s frame %d: the %s fist shows" % [id, f, side])
				assert_true(_reaches_edge(hits, _hand_parts(side), _whole_arm_parts(side)),
						"%s frame %d: the %s arm comes in from the edge of the view" % [id, f, side])
				if low_blows.has(id):
					var lowest := 0
					for cell: Vector2i in _cells_of(hits, _hand_parts(side)):
						lowest = maxi(lowest, cell.y)
					assert_gte(lowest, rows - 3, "%s: the %s fist rises in from the bottom edge" % [id, side])
					continue
				assert_gt(_parts_share(hits, [side + "Forearm"]), 0.01, "%s frame %d: the %s forearm shows" % [id, f, side])
				var fist := _view(rig, StringName(side + "FistPoint"))
				assert_true(_in_fp_view(fist), "%s: the %s fist in view (angles %s)" % [id, side, fist])
				# The arm points in from below or the side: the elbow is further off center than the fist.
				var elbow := _view(rig, StringName(side + "LowerArm"))
				assert_true(elbow.y < fist.y or absf(elbow.x) > absf(fist.x), "%s: from below or the side (elbow %s, fist %s)" % [
						id, elbow, fist])


## The first-person camera of `rig` with the view turned `yaw_deg` from the rig's facing
## (positive left), as FirstPersonCamera turns it for a spin (MoveData.camera_spin_follow)
## or the back elbow (camera_yaw_deg); pitched and dropped like _fp_camera().
func _turned_fp_camera(rig: HumanoidRig, yaw_deg: float, pitch_deg: float = 0.0, drop: float = 0.0) -> Transform3D:
	var look := Basis(Vector3.UP, deg_to_rad(yaw_deg)) * _facing(rig)
	var lens := rig.get_point_position(&"EyePoint") + Vector3.DOWN * drop + FirstPersonCamera.lens_offset(look)
	return Transform3D(look * Basis.from_euler(Vector3(deg_to_rad(pitch_deg), 0.0, 0.0)), lens)


func test_spinning_backfist_sweeps_in_from_the_right_in_first_person() -> void:
	# The view follows the eyes through the turn (camera_spin_follow 1), which face the
	# target again at contact: the right arm sweeps in from the right edge, the back of the
	# fist in view, and the body fills at most a third of the view.
	var rig := _player_rig()
	var move := _move_by_id(&"spinning_backfist")
	_to_first_active_frame(rig, move)
	for f: int in move.active:
		if f > 0:
			rig.advance(FRAME)
		var yaw := rad_to_deg(rig.eye_yaw())
		assert_lt(absf(yaw), 20.0, "frame %d: the eyes face the target again (%.0f degrees off)" % [f, yaw])
		var cam := _turned_fp_camera(rig, yaw)
		var hits := _fp_hits(rig, cam)
		assert_lt(_body_share(hits), 0.34, "frame %d: the body fills %.0f%% of the view" % [f, _body_share(hits) * 100.0])
		assert_gt(_parts_share(hits, _hand_parts("Right")), 0.004, "frame %d: the right fist shows" % f)
		assert_true(_reaches_edge(hits, _hand_parts("Right"), _whole_arm_parts("Right")),
				"frame %d: the right arm comes in from the edge of the view" % f)
		var fist := _view_from(cam, rig.get_point_position(&"RightFistPoint"))
		assert_true(_in_fp_view(fist), "frame %d: the fist in view (angles %s)" % [f, fist])
		var elbow := _view_from(cam, rig.get_point_position(&"RightLowerArm"))
		assert_gt(elbow.x, fist.x, "frame %d: from the right (elbow %s, fist %s)" % [f, elbow, fist])


func test_spins_never_fill_the_view_that_turns_with_them() -> void:
	# Through every frame of the spins, seen from the lens turned with the eyes (as the
	# first-person camera does), the body never fills more than a third of the view, and
	# the eyes turn a full circle, steadily (no frame turns them more than 40 degrees, and
	# never back the other way by more than a few degrees).
	var rig := _player_rig()
	for id: StringName in [&"spinning_heel", &"spin_kick", &"spinning_backfist"]:
		var move := load("res://game/combat/moves/%s.tres" % id) as MoveData
		rig.play(&"idle", 0.0)
		rig.advance(0.5)
		rig.play_move(move, 0.0)
		rig.advance(0.0)
		var last := rig.eye_yaw()
		var turn := 0.0
		var widest_step := 0.0
		var back := 0.0
		var fullest := 0.0
		for i: int in move.total_frames():
			rig.advance(FRAME)
			var eye := rig.eye_yaw()
			var step := rad_to_deg(wrapf(eye - last, -PI, PI))
			last = eye
			turn += step
			widest_step = maxf(widest_step, absf(step))
			back = maxf(back, step)
			var hits := _fp_hits(rig, _turned_fp_camera(rig, rad_to_deg(eye), move.camera_pitch_deg, move.camera_drop_m), 24)
			fullest = maxf(fullest, _body_share(hits))
		gut.p("%s: the eyes turn %.0f degrees, at most %.0f per frame; the body fills at most %.0f%% of the view" % [
				id, turn, widest_step, fullest * 100.0])
		assert_almost_eq(turn, -360.0, 5.0, "%s: the eyes turn a full circle to the right" % id)
		assert_lt(widest_step, 40.0, "%s: no frame turns the eyes more than 40 degrees" % id)
		assert_lt(back, 3.0, "%s: the eyes never turn back the other way" % id)
		assert_lt(fullest, 0.34, "%s: the body fills at most a third of the turning view" % id)


func test_back_elbow_turned_view_shows_the_elbow_driving_back() -> void:
	# The back elbow turns the first-person view toward the elbow (camera_yaw_deg, about 150
	# degrees right, and camera_pitch_deg a little down): on the active frames the right
	# elbow and forearm show in the view without filling it.
	var rig := _player_rig()
	var move := load("res://game/combat/moves/back_elbow.tres") as MoveData
	_to_first_active_frame(rig, move)
	for f: int in move.active:
		if f > 0:
			rig.advance(FRAME)
		var cam := _turned_fp_camera(rig, move.camera_yaw_deg, move.camera_pitch_deg)
		var hits := _fp_hits(rig, cam)
		assert_lt(_body_share(hits), 0.34, "frame %d: the body fills %.0f%% of the view" % [f, _body_share(hits) * 100.0])
		assert_gt(_parts_share(hits, _whole_arm_parts("Right")), 0.01, "frame %d: the right arm shows" % f)
		var elbow := _view_from(cam, rig.get_point_position(&"RightElbowPoint"))
		assert_true(_in_fp_view(elbow), "frame %d: the elbow's tip in view (angles %s)" % [f, elbow])


func test_pipe_swings_come_into_first_person_view() -> void:
	# A pipe swing sweeps in from the edge of the view (the side, or above for the overhead
	# smash): the grip stays further out than the tip, and the body fills at most about a
	# third of the view.
	var rig := _player_rig()
	for id: StringName in [&"pipe_swing_1", &"pipe_swing_2", &"pipe_swing_3"]:
		_to_first_active_frame(rig, _move_by_id(id))
		var hits := _fp_hits(rig, _fp_camera(rig))
		assert_lt(_body_share(hits), 0.34, "%s: the body fills %.0f%% of the view" % [id, _body_share(hits) * 100.0])
		var grip := rig.get_point_position(&"WeaponGrip")
		var tip := rig.get_point_position(&"WeaponTip")
		var shown := 0
		for k: int in 11:
			if _in_fp_view(_view_from(_fp_camera(rig), grip.lerp(tip, k / 10.0))):
				shown += 1
		assert_gte(shown, 2, "%s: the pipe's head shows in the view" % id)
		assert_true(_in_fp_view(_view(rig, &"WeaponTip")), "%s: the pipe's tip in the view" % id)
		assert_gt(_off_center_deg(_view(rig, &"WeaponGrip")), _off_center_deg(_view(rig, &"WeaponTip")),
				"%s: the pipe sweeps in from the edge" % id)

func test_kicks_come_into_first_person_view() -> void:
	# With the move's own camera offsets (pitched down and dropped during the kick), the
	# kicking foot and lower leg come into view.
	var rig := _player_rig()
	for id: StringName in [&"front_kick", &"roundhouse", &"stomp_kick", &"push_kick", &"flying_kick"]:
		var move := load("res://game/combat/moves/%s.tres" % id) as MoveData
		_to_first_active_frame(rig, move)
		for f: int in move.active:
			if f > 0:
				rig.advance(FRAME)
			var cam := _fp_camera(rig, move.camera_pitch_deg, move.camera_drop_m)
			var hits := _fp_hits(rig, cam)
			assert_gt(_parts_share(hits, _foot_parts("Right")), 0.005, "%s frame %d: the foot shows" % [id, f])
			assert_gt(_parts_share(hits, ["RightShin"]), 0.003, "%s frame %d: the lower leg shows" % [id, f])
			var view := _view_from(cam, rig.get_point_position(&"RightFootPoint"))
			assert_true(_in_fp_view(view), "%s foot in the view (angles %s)" % [id, view])
	# Straight kicks land sole first: the ankle stays (nearly) in front of a target at
	# arm's length, so the shoe is not hidden inside the target's belly.
	for id: StringName in [&"front_kick", &"stomp_kick", &"push_kick", &"flying_kick"]:
		_to_first_active_frame(rig, _move_by_id(id))
		var ankle := _local(rig, &"RightFoot")
		assert_gt(ankle.z, -0.77, "%s ankle in front of the target at %s" % [id, _fmt(ankle)])

func test_player_stands_relaxed_and_enemies_keep_the_boxer_guard() -> void:
	var boxer := _rig()
	var player := _player_rig()
	for rig: HumanoidRig in [boxer, player]:
		rig.play(&"idle", 0.0)
		rig.advance(0.0)
	var chin := _local(boxer, &"Head")
	for side: String in ["Left", "Right"]:
		var up := _local(boxer, StringName(side + "FistPoint"))
		assert_gt(up.y, 1.4, "the boxer guard holds the %s fist up (%s)" % [side, _fmt(up)])
		assert_lt(up.distance_to(chin), 0.45, "by the chin")
		# Fists up, ready to fight, from 2-10 m and side on: in front of the face, each on its
		# own side, the forearm rising to it from an elbow held low. At the chin or mouth, not
		# at eye level (the guard was lowered and pulled in for the player's throat-height
		# lens, see test_enemy_guard_leaves_the_players_view_clear()).
		var eye := _local(boxer, &"EyePoint")
		assert_lt(up.y, eye.y - 0.1, "the %s fist at the chin or mouth, not eye level (%s)" % [side, _fmt(up)])
		assert_lt(up.z, eye.z - 0.08, "the %s fist out in front of the face (%s)" % [side, _fmt(up)])
		assert_gt(up.x * (-1.0 if side == "Left" else 1.0), 0.08, "the %s fist on its own side (%s)" % [side, _fmt(up)])
		assert_lt(_local(boxer, StringName(side + "LowerArm")).y, up.y - 0.2, "the %s forearm rises from a low elbow" % side)
		var loose := _local(player, StringName(side + "FistPoint"))
		assert_lt(loose.y, 1.0, "the relaxed %s hand hangs at belt height or lower (%s)" % [side, _fmt(loose)])
	assert_lt(_local(player, &"LeftFistPoint").z, _local(player, &"RightFistPoint").z - 0.1,
			"the lead hand hangs forward of the rear hand")
	# The guard's body and footing, light on the feet: the head where the guard holds it
	# (so strikes, authored on the guard's body, move the eye no more), the lead step about
	# the guard's, the knees at least as soft, and the rear heel up.
	assert_almost_eq(_local(player, &"EyePoint"), _local(boxer, &"EyePoint"), Vector3.ONE * 0.01, "the head as in the guard")
	assert_almost_eq(_local(player, &"LeftFootPoint").z, _local(boxer, &"LeftFootPoint").z, 0.03, "the guard's lead step")
	for side: String in ["Left", "Right"]:
		var bend := func(rig: HumanoidRig) -> float:
			return rad_to_deg(rig.get_point_transform(StringName(side + "UpperLeg")).basis.y.angle_to(
					rig.get_point_transform(StringName(side + "LowerLeg")).basis.y))
		assert_gte(bend.call(player), bend.call(boxer) - 0.5, "the %s knee at least as soft as the guard's" % side)
	var heel := player.get_point_transform(&"RightFoot") * Vector3(0.0, -0.085, 0.085)
	var ball := player.get_point_transform(&"RightToes") * Vector3(0.0, -0.035, 0.0)
	assert_gt(heel.y - ball.y, 0.04, "the rear heel is raised")
	assert_lt(ball.y, 0.02, "on the ball of the rear foot")
	# The boxer keeps its fists up, above the chest, through idle and every walk.
	for anim: StringName in [&"idle", &"walk_forward", &"walk_back", &"walk_left", &"walk_right"]:
		boxer.play(anim, 0.0)
		boxer.advance(0.0)
		var step := boxer.anim_player.get_animation(anim).length / 8.0
		for k: int in 8:
			if k > 0:
				boxer.advance(step)
			for side: String in ["Left", "Right"]:
				var fist := _local(boxer, StringName(side + "FistPoint"))
				assert_gt(fist.y, _local(boxer, &"ChestPoint").y + 0.2, "%s at %d/8: the %s fist up above the chest (%s)" % [
						anim, k, side, _fmt(fist)])


func test_relaxed_arms_stay_out_of_the_level_first_person_view() -> void:
	# Looking ahead at rest or walking, the player's arms do not clutter the view: at most
	# a sliver of a hand at the very bottom edge, and nothing else of the body.
	var rig := _player_rig()
	var arms: Array[String] = _whole_arm_parts("Left")
	arms.append_array(_whole_arm_parts("Right"))
	var rows := FPView.rows()
	for anim: StringName in [&"idle", &"walk_forward", &"walk_back", &"walk_left", &"walk_right"]:
		rig.play(anim, 0.0)
		rig.advance(0.0)
		var step := rig.anim_player.get_animation(anim).length / 8.0
		for k: int in 8:
			if k > 0:
				rig.advance(step)
			var hits := _fp_hits(rig, _fp_camera(rig))
			assert_lt(_parts_share(hits, arms), 0.01, "%s at %d/8: the arms stay out of the view" % [anim, k])
			assert_almost_eq(_body_share(hits), _parts_share(hits, arms), 1e-6, "%s at %d/8: no other body part in view" % [anim, k])
			for cell: Vector2i in _cells_of(hits, arms):
				assert_gte(cell.y, rows - 2, "%s at %d/8: only a sliver at the bottom edge (cell %s)" % [anim, k, cell])


## Share of the view (from FPView.hits()) whose nearest mesh is one of `rig`'s parts in
## `names`.
func _rig_share(hits: Array[MeshInstance3D], rig: HumanoidRig, names: Array[String]) -> float:
	return _share(hits, func(m: MeshInstance3D) -> bool: return rig.is_ancestor_of(m) and names.has(String(m.name)))


## Every arm mesh of `rig` (upper arms, forearms and hands).
func _arm_meshes(rig: HumanoidRig) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in _meshes_under(rig):
		var name := String(mesh.name)
		for side: String in ["Left", "Right"]:
			if _whole_arm_parts(side).has(name) or name in [side + "UpperArm", side + "Delt"]:
				out.append(mesh)
	return out


## Stand `enemy` on the line of sight of a player rig at the origin (facing -Z),
## `distance` in front of the player's origin and facing it.
func _enemy_facing(enemy: HumanoidRig, distance: float) -> void:
	enemy.position = Vector3(0.0, 0.0, -distance)
	enemy.rotation = Vector3(0.0, PI, 0.0)


func test_enemy_guard_leaves_the_players_view_clear() -> void:
	# Game-boy's playtest: an enemy's boxer guard in front of the player's throat-height
	# lens filled most of the view with two oversized fist blocks at the lens's eye line,
	# for the whole sparring exchange. The gloves are the player's hand size now, held at
	# the chin a hand's width in front of it, the forearms angled in from low elbows. An
	# enemy in its idle guard standing 0.9 m in front of the player's lens (EyePoint +
	# FirstPersonCamera.lens_offset()) covers at most about 12% of the view with its hands
	# and forearms (the fist blocks covered 16% and hid part of the head), and its head
	# (cap, shades, face) shows whole above and between the gloves. At the sparring dummy's
	# step-in (Tuning.sparring_step_in_m between the bodies, about 0.72 m from the lens)
	# the gloves alone cover at most 8% (the fist blocks covered 20%) and the head still
	# shows whole.
	var scene := Node3D.new()
	add_child_autofree(scene)
	var player := _player_rig(scene)
	var enemy := _rig(false, 1.8, null, scene)
	player.play(&"idle", 0.0)
	player.advance(0.0)
	var cam := _fp_camera(player)
	var hands: Array[String] = _hand_parts("Left")
	hands.append_array(_hand_parts("Right"))
	var arms: Array[String] = _arm_parts("Left")
	arms.append_array(_arm_parts("Right"))
	var cases := {
		"0.9 m in front of the lens": -cam.origin.z + 0.9,
		"at the sparring step-in": Tuning.data.sparring_step_in_m,
	}
	for what: String in cases:
		_enemy_facing(enemy, cases[what])
		enemy.play(&"idle", 0.0)
		enemy.advance(0.0)
		var hits := FPView.hits(scene, cam)
		var bare := FPView.hits(scene, cam, FP_COLS, _arm_meshes(enemy))
		var arm_share := _rig_share(hits, enemy, arms)
		var glove_share := _rig_share(hits, enemy, hands)
		if what == "at the sparring step-in":
			assert_lt(glove_share, 0.08, "%s: the gloves cover %.1f%% of the view" % [what, glove_share * 100.0])
			# The forearms still bring this to ~17% (the old guard: 34%); keep it from creeping back.
			assert_lt(arm_share, 0.19, "%s: the hands and forearms cover %.1f%% of the view" % [what, arm_share * 100.0])
		else:
			assert_lt(arm_share, 0.12, "%s: the hands and forearms cover %.1f%% of the view" % [what, arm_share * 100.0])
		var head := _rig_share(hits, enemy, ENEMY_HEAD)
		var whole_head := _rig_share(bare, enemy, ENEMY_HEAD)
		assert_gt(whole_head, 0.02, "%s: the head is in the view" % what)
		assert_gt(head, whole_head * 0.97, "%s: the head shows whole (%.1f%% of the view, %.1f%% without the arms)" % [
				what, head * 100.0, whole_head * 100.0])
		assert_almost_eq(_rig_share(hits, enemy, ["Shades", "ShadesFront"]), _rig_share(bare, enemy, ["Shades", "ShadesFront"]),
				1e-6, "%s: nothing of the arms in front of the shades" % what)


func test_looking_down_shows_the_lead_leg_and_foot() -> void:
	# Mirror's Edge feel: looking down at rest shows the player's own lead hand, foot and leg,
	# and no torso mesh stands in front of them with the lens at throat height (the chest is
	# hidden from the first-person camera). Looking down 45 degrees, the bottom edge of the
	# view is 74 degrees below level, short of the feet under the body: the lead shoe comes
	# in from about 60 degrees and the lead thigh from about 65. Walking, the striding foot
	# and shin come in from 55.
	var rig := _player_rig()
	rig.play(&"idle", 0.0)
	rig.advance(0.0)
	var torso_names: Array[String] = ["Pelvis", "Belt", "Belly", "BellyTop", "Chest", "UpperChest", "LeftTrap", "RightTrap"]
	var torso: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in _meshes_under(rig):
		if torso_names.has(String(mesh.name)):
			torso.append(mesh)
	var legs: Array[String] = _foot_parts("Left")
	legs.append_array(["LeftThigh", "LeftShin"])
	for pitch: float in [-45.0, -60.0, -65.0]:
		var cam := _fp_camera(rig, pitch)
		var hits := _fp_hits(rig, cam, 96)
		assert_gt(_parts_share(hits, _hand_parts("Left")), 0.004, "%.0f deg: the lead hand shows" % pitch)
		assert_eq(_parts_share(hits, torso_names), 0.0, "%.0f deg: the torso stays out of the view" % pitch)
		var bare := _fp_hits(rig, cam, 96, torso)
		assert_almost_eq(_parts_share(bare, legs), _parts_share(hits, legs), 1e-6,
				"%.0f deg: the torso hides nothing of the lead leg" % pitch)
	assert_gt(_parts_share(_fp_hits(rig, _fp_camera(rig, -60.0), 96), _foot_parts("Left")), 0.002,
			"60 deg down: the lead shoe shows")
	assert_gt(_parts_share(_fp_hits(rig, _fp_camera(rig, -65.0), 96), ["LeftThigh", "LeftShin"]), 0.005,
			"65 deg down: the lead leg shows")
	var foot := 0.0
	var shin := 0.0
	rig.play(&"walk_forward", 0.0)
	rig.advance(0.0)
	for k: int in 8:
		rig.advance(0.6 / 8.0)
		var hits := _fp_hits(rig, _fp_camera(rig, -55.0), 96)
		foot = maxf(foot, _parts_share(hits, _foot_parts("Left")))
		shin = maxf(shin, _parts_share(hits, ["LeftShin"]))
	assert_gt(foot, 0.005, "walking, 55 deg down: the striding lead foot shows")
	assert_gt(shin, 0.0, "walking, 55 deg down: the lead shin shows")


func test_looking_straight_down_shows_a_rounded_shirt_front() -> void:
	# With the chest hidden from the first-person camera, looking steeply down would show
	# the belly box's flat top as a lid across the bottom of the view: the rounded top on
	# the belly (BellyTop) covers it, so only a sliver of the lid shows.
	var rig := _player_rig()
	rig.play(&"idle", 0.0)
	rig.advance(0.0)
	var belly := rig.find_child("Belly", true, false) as MeshInstance3D
	var half := (belly.mesh as BoxMesh).size * 0.5
	for pitch: float in [-75.0, -88.0]:
		var cam := _fp_camera(rig, pitch)
		var hits := _fp_hits(rig, cam, 96)
		assert_gt(_parts_share(hits, ["BellyTop"]), 0.02, "%.0f deg: the rounded shirt front shows" % pitch)
		var lid := 0
		var rows := FPView.rows(96)
		var tan_h := tan(deg_to_rad(FP_HALF_H_DEG))
		var tan_v := tan_h * 9.0 / 16.0
		for i: int in hits.size():
			if hits[i] != belly:
				continue
			var ray := Vector3(((i % 96 + 0.5) / 96.0 * 2.0 - 1.0) * tan_h, (1.0 - (i / 96 + 0.5) / rows * 2.0) * tan_v, -1.0)
			var dir := cam.basis * ray
			var at := belly.global_transform.affine_inverse() * (cam.origin + dir * FPView.ray_hit(belly, cam.origin, dir))
			if absf(at.y - half.y) < 1e-3:
				lid += 1
		assert_lt(lid / float(hits.size()), 0.005, "%.0f deg: the belly box's flat top shows in %d cells" % [pitch, lid])


## The held guard as the first-person lens sees it ("dukes up"): both fists up in the
## upper third of the view either side of the center, each arm rising to its fist from the
## edge of the view, no forearm or hand within 0.3 m of the lens, the arms filling under a
## third of the view and its center clear between the fists.
func _assert_guard_view(rig: HumanoidRig, what: String) -> void:
	var cam := _fp_camera(rig)
	var hits := _fp_hits(rig, cam)
	assert_lt(_body_share(hits), 0.3, "%s: the guard fills %.0f%% of the view" % [what, _body_share(hits) * 100.0])
	var near_parts := _arm_parts("Left")
	near_parts.append_array(_arm_parts("Right"))
	var near := _nearest_part(rig, cam, near_parts)
	assert_gt(near, 0.3, "%s: the nearest forearm or hand is %.2f m from the lens" % [what, near])
	for side: String in ["Left", "Right"]:
		var fist := _view(rig, StringName(side + "FistPoint"))
		assert_true(_in_upper_third(fist), "%s: the %s fist up in the upper third of the view (angles %s)" % [what, side, fist])
		assert_true(fist.x < -10.0 if side == "Left" else fist.x > 10.0, "%s: the %s fist on its own side (angles %s)" % [
				what, side, fist])
		assert_true(_reaches_edge(hits, _hand_parts(side), _whole_arm_parts(side)),
				"%s: the %s forearm rises from the edge of the view" % [what, side])
	var center := Vector2(FP_COLS, FPView.rows()) * 0.5
	for i: int in hits.size():
		var off := Vector2(i % FP_COLS, i / FP_COLS) + Vector2(0.5, 0.5) - center
		if off.length() < 8.0:
			assert_null(hits[i], "%s: the view center stays clear between the fists" % what)


func test_block_holds_the_guard_up_over_the_stance_legs() -> void:
	# &"block" holds the guard (PlaceholderPoses.block_guard()) over the stance's legs and
	# torso: the "dukes up" image, authored for the throat-height lens.
	var rig := _player_rig()
	rig.play(&"idle", 0.0)
	rig.advance(0.0)
	var stance: Array[Vector3] = []
	for point: StringName in [&"LeftFootPoint", &"RightFootPoint", &"EyePoint"]:
		stance.append(_local(rig, point))
	rig.play(&"block", 0.1)
	rig.advance(0.5)
	assert_eq(rig.current_anim(), &"block")
	_assert_guard_view(rig, "block")
	var i := 0
	for point: StringName in [&"LeftFootPoint", &"RightFootPoint", &"EyePoint"]:
		assert_almost_eq(_local(rig, point), stance[i], Vector3.ONE * 0.01, "block keeps the stance's %s" % point)
		i += 1
	for side: String in ["Left", "Right"]:
		var fist := _local(rig, StringName(side + "FistPoint"))
		assert_gt(fist.y, _local(rig, &"ChestPoint").y + 0.2, "the %s fist up by the face (%s)" % [side, _fmt(fist)])
		assert_lt(fist.z, _local(rig, &"Head").z - 0.25, "the %s fist out in front of the face (%s)" % [side, _fmt(fist)])


func test_dodges_keep_the_stance_arms_and_only_block_puts_the_guard_up() -> void:
	# Every dodge slips with the stance's arms, the backstep (B + back) and the forward step
	# included: the held block (B with no stick) is the "dukes up" image now. (The neutral
	# dodges covered up with the guard before the held block took neutral B.)
	for rig: HumanoidRig in _stance_rigs():
		rig.play(&"idle", 0.0)
		rig.advance(0.0)
		var stance: Array[Vector3] = []
		for side: String in ["Left", "Right"]:
			stance.append(rig.get_point_transform(&"UpperChest").affine_inverse() * rig.get_point_position(StringName(side + "FistPoint")))
		for anim: StringName in [&"dodge_back", &"dodge_forward", &"dodge_left", &"dodge_right"]:
			rig.play(&"idle", 0.0)
			rig.advance(0.5)
			rig.play(anim, 0.03)
			for f: int in 18:
				rig.advance(FRAME)
				var chest := rig.get_point_transform(&"UpperChest").affine_inverse()
				# dodge_left mirrors dodge_right, arms included: checked by the low hands below.
				for s: int in (0 if anim == &"dodge_left" else 2):
					var side: String = ["Left", "Right"][s]
					var fist := chest * rig.get_point_position(StringName(side + "FistPoint"))
					assert_almost_eq(fist, stance[s], Vector3.ONE * 0.02, "%s frame %d: the %s arm keeps the stance's pose" % [
							_tag(rig, anim), f + 1, side])
				if rig.stance == PlaceholderPoses.STANCE_RELAXED:
					for side: String in ["Left", "Right"]:
						assert_lt(_local(rig, StringName(side + "FistPoint")).y, 1.1, "%s frame %d: the %s hand stays low" % [
								anim, f + 1, side])
					assert_lt(_body_share(_fp_hits(rig, _fp_camera(rig))), 0.05, "%s frame %d: no guard in the view" % [anim, f + 1])
	var rig := _player_rig()
	rig.play(&"block", 0.0)
	rig.advance(0.0)
	_assert_guard_view(rig, "block")


func test_block_hit_jolts_the_guard_back_and_returns_to_it() -> void:
	# Blockstun's &"block_hit": the hips and torso rock back while the guard jams in (the
	# fists come toward the lens and the view center), then back into the guard by the end
	# (10 frames, the light blockstun). From the lens the arms keep to the first-person
	# rules: the body covers at most a third of the view, no forearm or hand comes within
	# 0.3 m of the lens, both fists stay up on their own sides and the center stays clear.
	for rig: HumanoidRig in _stance_rigs():
		rig.play(&"block", 0.0)
		rig.advance(0.5)
		var guard_hips := _local(rig, &"Hips")
		var guard_eye := _local(rig, &"EyePoint")
		var guard_fist := _view(rig, &"LeftFistPoint")
		rig.play(&"block_hit", 0.02)
		var length := rig.anim_player.get_animation(&"block_hit").length
		assert_almost_eq(length, 10.0 * FRAME, 1e-4, "authored for the light blockstun")
		var deepest := 0.0
		var widest := 0.0
		var inward := 0.0
		for f: int in 10:
			rig.advance(FRAME)
			deepest = maxf(deepest, _local(rig, &"Hips").z - guard_hips.z)
			widest = maxf(widest, _local(rig, &"EyePoint").z - guard_eye.z)
			if rig.stance != PlaceholderPoses.STANCE_RELAXED:
				continue
			var cam := _fp_camera(rig)
			var hits := _fp_hits(rig, cam)
			var tag := "block_hit frame %d" % (f + 1)
			assert_lt(_body_share(hits), 0.34, "%s: the arms fill %.0f%% of the view" % [tag, _body_share(hits) * 100.0])
			var near_parts := _arm_parts("Left")
			near_parts.append_array(_arm_parts("Right"))
			assert_gt(_nearest_part(rig, cam, near_parts), 0.3, "%s: forearms 0.3 m or more from the lens" % tag)
			for side: String in ["Left", "Right"]:
				var fist := _view(rig, StringName(side + "FistPoint"))
				assert_true(_in_fp_view(fist) and fist.y > 5.0, "%s: the %s fist up in view (angles %s)" % [tag, side, fist])
				assert_true(fist.x < -10.0 if side == "Left" else fist.x > 10.0, "%s: the %s fist on its own side" % [tag, side])
			inward = maxf(inward, absf(guard_fist.x) - absf(_view(rig, &"LeftFistPoint").x))
			var center := Vector2(FP_COLS, FPView.rows()) * 0.5
			for i: int in hits.size():
				if (Vector2(i % FP_COLS, i / FP_COLS) + Vector2(0.5, 0.5) - center).length() < 8.0:
					assert_null(hits[i], "%s: the view center stays clear" % tag)
		assert_gt(deepest, 0.03, "%s: the hips are driven back" % rig.stance)
		assert_gt(widest, 0.08, "%s: the head rocks back with the torso (side view)" % rig.stance)
		if rig.stance == PlaceholderPoses.STANCE_RELAXED:
			assert_gt(inward, 3.0, "the fists jam in toward the view center")
		assert_eq(rig.current_anim(), &"block_hit")
		for side: String in ["Left", "Right"]:
			rig.play(&"block", 0.0)
			rig.advance(0.0)
			var held := _local(rig, StringName(side + "FistPoint"))
			rig.play(&"block_hit", 0.0)
			rig.advance(0.0)
			rig.advance(length)
			assert_almost_eq(_local(rig, StringName(side + "FistPoint")), held, Vector3.ONE * 0.01,
					"%s: block_hit ends back in the guard (%s fist)" % [rig.stance, side])


func test_guard_break_knocks_the_arms_apart_into_a_stagger() -> void:
	# &"guard_break" (45 frames, Tuning.guard_break_frames): the arms are forced apart and
	# flung up and out, the head snaps back, the body reels and recovers into the stance.
	# From the lens the fists swing out toward the upper corners over a few frames instead
	# of vanishing at once, and the view is clear while the body reels.
	for rig: HumanoidRig in _stance_rigs():
		rig.play(&"idle", 0.0)
		rig.advance(0.0)
		var stance: Array[Vector3] = []
		for point: StringName in [&"LeftFistPoint", &"RightFistPoint", &"EyePoint"]:
			stance.append(_local(rig, point))
		rig.play(&"block", 0.0)
		rig.advance(0.5)
		var guard_gap := _local(rig, &"RightFistPoint").x - _local(rig, &"LeftFistPoint").x
		var guard_eye := _local(rig, &"EyePoint")
		rig.play(&"guard_break", 0.03)
		var length := rig.anim_player.get_animation(&"guard_break").length
		assert_almost_eq(length, Tuning.data.guard_break_frames * FRAME, 0.02, "lasts the guard break")
		var widest := 0.0
		var snapped := 0.0
		var in_view_frames := 0
		for f: int in roundi(length / FRAME):
			rig.advance(FRAME)
			var gap := _local(rig, &"RightFistPoint").x - _local(rig, &"LeftFistPoint").x
			widest = maxf(widest, gap)
			snapped = maxf(snapped, _local(rig, &"EyePoint").z - guard_eye.z)
			if rig.stance != PlaceholderPoses.STANCE_RELAXED:
				continue
			var hits := _fp_hits(rig, _fp_camera(rig))
			assert_lt(_body_share(hits), 0.3, "frame %d: the arms fill %.0f%% of the view" % [f + 1, _body_share(hits) * 100.0])
			if f < 8 and _in_fp_view(_view(rig, &"LeftFistPoint")) and _in_fp_view(_view(rig, &"RightFistPoint")):
				in_view_frames += 1
				assert_gt(absf(_view(rig, &"LeftFistPoint").x), 30.0, "frame %d: the fists swing outward" % [f + 1])
		assert_gt(widest, guard_gap + 0.8, "%s: the arms are knocked apart (fists %.2f m apart)" % [rig.stance, widest])
		assert_gt(snapped, 0.15, "%s: the head snaps back" % rig.stance)
		if rig.stance == PlaceholderPoses.STANCE_RELAXED:
			assert_between(in_view_frames, 2, 5, "the fists leave the view over a few frames")
		for i: int in 3:
			var point: StringName = [&"LeftFistPoint", &"RightFistPoint", &"EyePoint"][i]
			assert_almost_eq(_local(rig, point), stance[i], Vector3.ONE * 0.01, "%s: ends in the stance (%s)" % [rig.stance, point])


func test_recoil_knocks_the_striking_arm_back() -> void:
	# &"recoil" (an attack stopped by a guard, 14 frames): the striking right arm is knocked
	# back from the strike to beside the shoulder at once, held, and the body returns to the
	# stance by the end. The other arm stays in the stance's pose.
	var jab := load("res://game/combat/moves/dummy_jab.tres") as MoveData
	for rig: HumanoidRig in _stance_rigs():
		rig.play(&"idle", 0.0)
		rig.advance(0.0)
		var stance: Array[Vector3] = []
		for point: StringName in [&"LeftFistPoint", &"RightFistPoint", &"EyePoint"]:
			stance.append(_local(rig, point))
		_to_first_active_frame(rig, jab)
		var strike := _local(rig, &"RightFistPoint")
		rig.play(&"recoil", 0.03)
		var length := rig.anim_player.get_animation(&"recoil").length
		assert_almost_eq(length, 14.0 * FRAME, 1e-4, "authored for the default blocked_recoil_frames")
		for f: int in 4:
			rig.advance(FRAME)
		var knocked := _local(rig, &"RightFistPoint")
		assert_gt(knocked.z - strike.z, 0.6, "%s: the right fist knocked back (%s from %s)" % [rig.stance, _fmt(knocked), _fmt(strike)])
		assert_gt(knocked.x, 0.3, "%s: and out to the right" % rig.stance)
		assert_between(knocked.y, 1.4, 1.8, "%s: at shoulder height" % rig.stance)
		assert_lt(knocked.z, 0.1, "%s: beside the shoulder, not behind the back" % rig.stance)
		rig.advance(length)
		for i: int in 3:
			var point: StringName = [&"LeftFistPoint", &"RightFistPoint", &"EyePoint"][i]
			assert_almost_eq(_local(rig, point), stance[i], Vector3.ONE * 0.01, "%s: ends in the stance (%s)" % [rig.stance, point])
	# The boxer's lead glove holds its side of the chin while the torso twists away (turned
	# with it, it swung in front of the face for the whole punish window): seen from the
	# defender's lens with the attacker at the sparring step-in, the face shows through the
	# recoil.
	var scene := Node3D.new()
	add_child_autofree(scene)
	var player := _player_rig(scene)
	player.play(&"idle", 0.0)
	player.advance(0.0)
	var cam := _fp_camera(player)
	var boxer := _rig(false, 1.8, null, scene)
	_enemy_facing(boxer, Tuning.data.sparring_step_in_m)
	_to_first_active_frame(boxer, jab)
	boxer.play(&"recoil", 0.03)
	for f: int in 14:
		boxer.advance(FRAME)
		var lead := _local(boxer, &"LeftFistPoint")
		assert_lt(lead.x, -0.08, "recoil frame %d: the lead glove holds its side (%s)" % [f + 1, _fmt(lead)])
		var face := _rig_share(FPView.hits(scene, cam), boxer, ENEMY_HEAD)
		var whole := _rig_share(FPView.hits(scene, cam, FP_COLS, _arm_meshes(boxer)), boxer, ENEMY_HEAD)
		assert_gt(face, whole * 0.9, "recoil frame %d: the face shows (%.1f%% of the view, %.1f%% without the arms)" % [
				f + 1, face * 100.0, whole * 100.0])


func test_dummy_jab_telegraphs_its_wind_up() -> void:
	# The sparring dummy's jab (boxer stance): over its 18-frame startup the right fist
	# draws back beside the head, the shoulders turned away, by 60% of the startup, then
	# drives straight in to the jab's reach. Seen from the defender's lens with the dummy at
	# its step-in, the face shows whole through the startup (the lead fist holds its side
	# of the chin while the shoulders turn) and the cocked fist shows beside the head, on
	# the defender's left.
	var scene := Node3D.new()
	add_child_autofree(scene)
	var player := _player_rig(scene)
	player.play(&"idle", 0.0)
	player.advance(0.0)
	var cam := _fp_camera(player)
	var rig := _rig(false, 1.8, null, scene)
	_enemy_facing(rig, Tuning.data.sparring_step_in_m)
	var jab := load("res://game/combat/moves/dummy_jab.tres") as MoveData
	rig.play(&"idle", 0.0)
	rig.advance(0.5)
	var guard := _local(rig, &"RightFistPoint")
	var head := _local(rig, &"Head")
	rig.play_move(jab, 0.0)
	var cocked := roundi(jab.startup * 0.6)
	for f: int in jab.startup:
		rig.advance(FRAME)
		var hits := FPView.hits(scene, cam)
		var bare := FPView.hits(scene, cam, FP_COLS, _arm_meshes(rig))
		var face := _rig_share(hits, rig, ENEMY_HEAD)
		var whole := _rig_share(bare, rig, ENEMY_HEAD)
		assert_gt(face, whole * 0.95, "startup frame %d: the face shows (%.1f%% of the view, %.1f%% without the arms)" % [
				f + 1, face * 100.0, whole * 100.0])
		if f + 1 == cocked:
			break
	var fist := _view_from(cam, rig.get_point_position(&"RightFistPoint"))
	assert_true(_in_fp_view(fist) and fist.x < -10.0 and fist.y > 0.0,
			"the cocked fist shows up beside the head, on the defender's left (angles %s)" % fist)
	assert_gt(_rig_share(FPView.hits(scene, cam), rig, _hand_parts("Right")), 0.003, "the cocked glove is not hidden")
	var windup := _local(rig, &"RightFistPoint")
	assert_gt(windup.z - guard.z, 0.3, "the fist draws back %.2f m (%s)" % [windup.z - guard.z, _fmt(windup)])
	assert_gt(windup.z, head.z, "behind the face, beside the head")
	assert_gt(windup.x, 0.3, "out to the right")
	assert_gt(windup.y, head.y, "up by the ear")
	for f: int in jab.startup - cocked:
		rig.advance(FRAME)
	var strike := _local(rig, &"RightFistPoint")
	assert_lt(strike.z, -0.65, "then the straight right reaches out (%s)" % _fmt(strike))
	assert_lt(absf(strike.x), 0.1, "on the center line")


func test_haymaker_charge_keeps_the_view_center_clear() -> void:
	# The player holds haymaker_charge for as long as P is held. The torso twists away
	# for the swing, and the lead (left) hand reaches out to the left: it never covers the
	# center dot or the target's head. That holds through the charge and through the
	# haymaker's startup, charged or not.
	var rig := _player_rig()
	var move := _move_by_id(&"haymaker")
	var phases := {
		&"charge": func() -> void:
			rig.play(&"haymaker_charge"),
		&"release": func() -> void:
			rig.play_move(move),
		&"uncharged": func() -> void:
			rig.play(&"idle", 0.0)
			rig.advance(0.5)
			rig.play_move(move),
	}
	rig.play(&"idle", 0.0)
	rig.advance(0.5)
	for phase: StringName in phases:
		(phases[phase] as Callable).call()
		var frames := 40 if phase == &"charge" else move.startup
		for i: int in frames:
			rig.advance(FRAME)
			for point: StringName in [&"LeftFistPoint", &"LeftHand"]:
				var view := _view(rig, point)
				assert_gt(_off_center_deg(view), 12.0, "%s frame %d: %s clear of the view center (angles %s)" % [
						phase, i + 1, point, view])
		if phase == &"charge":
			assert_eq(rig.current_anim(), &"haymaker_charge")
			var lead := _view(rig, &"LeftFistPoint")
			assert_true(_in_fp_view(lead), "the cocked stance shows the lead hand (angles %s)" % lead)
			assert_lt(lead.x, -15.0, "the lead hand reaches out on the left (angles %s)" % lead)
			assert_lt(_body_share(_fp_hits(rig, _fp_camera(rig))), 0.2, "the charge keeps most of the view clear")

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
