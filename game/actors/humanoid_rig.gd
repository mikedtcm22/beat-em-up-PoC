class_name HumanoidRig
extends Node3D
## Placeholder humanoid body shared by the player, dummies and enemies until real art
## arrives (Milestone 4). Builds, in code:
##   - a Skeleton3D using Godot humanoid-profile bone names (see docs/ARCHITECTURE.md),
##   - primitive meshes per bone (chunky proportions, slightly oversized hands and feet),
##   - region hurtboxes (Hurtbox areas) kept in sync with the bones,
##   - named rig points (strike markers, EyePoint, WeaponGrip/Tip, HeadTopPoint, ChestPoint),
##   - a procedural animation library played through an AnimationPlayer in MANUAL mode.
## The character faces -Z; the rig origin is at the feet.
##
## Time: the owner calls advance(dt) once per physics tick with its SIM delta (0 during
## hitstop, scaled during slow-mo). Nothing here advances on its own.
##
## Determinism: advance() computes every bone's pose from the AnimationPlayer's output
## itself (it does not wait for Skeleton3D's deferred update), then moves the bone
## followers, rig points and hurtboxes. When advance() returns, get_point_transform(),
## the attachment nodes and the hurtbox transforms (scene and physics server) all show
## the same pose. play() and play_move() only choose the animation; the pose changes on
## the next advance(), whose dt is the first slice of the new animation.
## Hurtboxes are written straight to the physics server, so a shape query run right after
## advance() sees this tick's pose. If the owner moves its body after advance() in the same
## tick, call advance(0.0) again to re-sync (it re-applies the pose without moving time).
##
## Grabs: the held animation is authored for a victim whose origin stands on the floor
## directly below the holder's HoldPoint, facing the holder (&"hold" on the holder,
## &"held" on the victim). The victim's head then sits low in the holder's first-person
## view and the knee and throw poses reach it.
##
## Layout and art data live in PlaceholderBody (bones, rig points, meshes, hurtboxes),
## PlaceholderPoses (pose library) and PlaceholderAnims (animation builders).

@export var height: float = 1.8
@export var body_color: Color = Color(0.22, 0.42, 0.78):
	set(value):
		body_color = value
		_apply_colors()
@export var accent_color: Color = Color(0.92, 0.9, 0.85):
	set(value):
		accent_color = value
		_apply_colors()
@export var skin_color: Color = Color(0.86, 0.66, 0.5):
	set(value):
		skin_color = value
		_apply_colors()
## Player only: put head and neck meshes on CombatTypes.VIS_FP_HIDDEN.
@export var first_person_body: bool = false:
	set(value):
		first_person_body = value
		_apply_layers()
@export var build_hurtboxes: bool = true
## Cross-fade time when play_locomotion() switches between idle and the walks (seconds).
@export_range(0.0, 0.5, 0.01) var locomotion_blend_s: float = 0.15

## The CombatActor that owns this rig. Set before build(); copied into each Hurtbox.actor
## (setting it later updates the hurtboxes too).
var actor: Node3D:
	set(value):
		actor = value
		for hurtbox: Hurtbox in _hurtboxes:
			hurtbox.actor = value
var skeleton: Skeleton3D
var anim_player: AnimationPlayer

## Library name for the move animations built by play_move().
const _MOVE_LIBRARY := &"moves"
## Shades, belt and soles.
const _DARK_COLOR := Color(0.07, 0.07, 0.08)
## Trousers are body_color darkened by this much.
const _PANTS_DARKEN := 0.45
## A KO that starts while the body is already lying skips to this many seconds before
## the end of the ko_* slump, so the body does not stand back up first.
const _KO_FROM_LYING_S := 0.28
const _LYING_ANIMS: Array[StringName] = [
	&"downed_back", &"downed_front", &"knockdown_back", &"knockdown_forward",
	&"ko_back", &"ko_front",
]

var _built: bool = false
## Rig lengths are PlaceholderBody lengths times this.
var _scale: float = 1.0
var _bone_index: Dictionary[StringName, int] = {}
## Skeleton-space (= rig-space) pose of every bone after the latest advance().
var _bone_globals: Array[Transform3D] = []
var _bone_nodes: Dictionary[StringName, Node3D] = {}
var _point_nodes: Dictionary[StringName, Marker3D] = {}
var _hurtboxes: Array[Hurtbox] = []
var _hurt_shapes: Array[CollisionShape3D] = []
var _hurt_specs: Array[PlaceholderBody.HurtSpec] = []
## Paint (PlaceholderBody.Paint) -> material. One set per rig so flashes stay per actor.
var _materials: Dictionary[int, StandardMaterial3D] = {}
var _head_meshes: Array[MeshInstance3D] = []
var _body_meshes: Array[MeshInstance3D] = []
var _current: StringName = &""
## The body flurry alternates its leading fist on consecutive plays.
var _flurry_mirrored: bool = false


## Create skeleton, meshes, hurtboxes, rig points and the animation library. Idempotent:
## a second call does nothing. Starts in idle, already posed.
func build() -> void:
	if _built:
		return
	_built = true
	_scale = maxf(height, 0.1) / PlaceholderBody.REF_HEIGHT
	_build_skeleton()
	_build_materials()
	_build_meshes()
	_build_points()
	if build_hurtboxes:
		_build_hurtboxes()
	_build_animation()
	_start(&"idle", &"idle", 0.0, 1.0)
	advance(0.0)


## Play a named (non-move) animation such as &"idle", &"flinch_gut" or &"getup_back".
## `speed` scales playback. Restarts it if it is already playing. Non-looping animations
## hold their last pose when they end (current_anim() keeps returning them).
func play(anim: StringName, blend_s: float = 0.08, speed: float = 1.0) -> void:
	if not _built:
		push_warning("HumanoidRig.play('%s') before build()" % anim)
		return
	if not anim_player.has_animation(anim):
		push_warning("HumanoidRig: unknown animation '%s'" % anim)
		return
	var was_lying := _LYING_ANIMS.has(_current)
	_flurry_mirrored = false
	_start(anim, anim, blend_s, speed)
	if was_lying and String(anim).begins_with("ko_"):
		var length := anim_player.get_animation(anim).length
		anim_player.seek(maxf(length - _KO_FROM_LYING_S, 0.0))


## Play the animation for `move`, built (and cached) so its length is exactly
## move.total_frames() / 60 s, it reaches the strike pose at move.startup / 60 s, holds it
## through the active frames, and returns to guard by the end of recovery.
## The blend is capped at 75% of the startup so the strike pose is reached unblended.
## Consecutive body_flurry plays alternate the leading fist.
func play_move(move: MoveData, blend_s: float = 0.04) -> void:
	if move == null:
		push_warning("HumanoidRig.play_move(null)")
		return
	if not _built:
		push_warning("HumanoidRig.play_move('%s') before build()" % move.get_anim())
		return
	var mirrored := false
	if move.get_anim() == &"body_flurry":
		mirrored = _flurry_mirrored
		_flurry_mirrored = not _flurry_mirrored
	else:
		_flurry_mirrored = false
	var key := StringName("%s__%d_%d_%d%s" % [move.get_anim(), move.startup, move.active,
			move.recovery, "_m" if mirrored else ""])
	var full := StringName("%s/%s" % [_MOVE_LIBRARY, key])
	if not anim_player.has_animation(full):
		anim_player.get_animation_library(_MOVE_LIBRARY).add_animation(key,
				PlaceholderAnims.build_move(move, _scale, mirrored))
	var blend := minf(maxf(blend_s, 0.0), 0.75 * move.startup * PlaceholderAnims.FRAME_S)
	_start(full, move.get_anim(), blend, 1.0)


## Locomotion while FREE: idle or walk_forward/back/left/right, picked from the local move
## direction (x = right, y = forward) and played at `speed_ratio` (1 = full walk speed).
## Idle below a speed ratio of 0.1. Keeps the current cycle running (only its speed
## changes) when the choice does not change.
func play_locomotion(local_move: Vector2, speed_ratio: float) -> void:
	if not _built:
		return
	var anim := &"idle"
	var speed := 1.0
	if speed_ratio >= 0.1 and local_move.length_squared() > 1e-6:
		speed = speed_ratio
		if absf(local_move.y) >= absf(local_move.x):
			anim = &"walk_forward" if local_move.y > 0.0 else &"walk_back"
		else:
			anim = &"walk_right" if local_move.x > 0.0 else &"walk_left"
	if anim == _current and anim_player.assigned_animation == anim:
		anim_player.speed_scale = speed
		return
	_flurry_mirrored = false
	_start(anim, anim, locomotion_blend_s, speed)


## Advance animation by `dt` sim seconds, update the skeleton pose, sync hurtboxes.
## advance(0) applies the current animation time without moving it.
func advance(dt: float) -> void:
	if not _built:
		return
	var step := maxf(dt, 0.0)
	anim_player.advance(step)
	skeleton.advance(step)
	_refresh_pose()


## The animation id last started: a named animation, or the move's anim id for play_move().
func current_anim() -> StringName:
	return _current


## True for every id in docs/ARCHITECTURE.md "Animation ids" and every move id with a
## recipe (move animations are built on demand by play_move()).
func has_anim(anim: StringName) -> bool:
	return PlaceholderAnims.ANIM_IDS.has(anim) or PlaceholderAnims.MOVE_IDS.has(anim)


## World transform of a bone (by humanoid name) or rig point (e.g. &"RightFistPoint").
## Reflects the pose after the latest advance() and the rig's current world transform.
## Rig points take their bone's rotation; WeaponGrip's -Z axis points along the weapon.
func get_point_transform(point: StringName) -> Transform3D:
	var to_world := global_transform if is_inside_tree() else transform
	if not _built:
		return to_world
	if PlaceholderBody.POINT_BONE.has(point):
		var bone_pose := _bone_globals[_bone_index[PlaceholderBody.POINT_BONE[point]]]
		return to_world * bone_pose * Transform3D(Basis.IDENTITY, PlaceholderBody.POINT_OFFSET[point] * _scale)
	if _bone_index.has(point):
		return to_world * _bone_globals[_bone_index[point]]
	push_warning("HumanoidRig: unknown rig point '%s'" % point)
	return to_world


func get_point_position(point: StringName) -> Vector3:
	return get_point_transform(point).origin


## Node that follows a bone or rig point, for attaching visuals (held weapon at WeaponGrip).
## Children added to it follow the pose after every advance(). For the weapon, parent it
## to WeaponGrip with its handle at the origin and its length along -Z.
func get_attachment(point: StringName) -> Node3D:
	if _point_nodes.has(point):
		return _point_nodes[point]
	if _bone_nodes.has(point):
		return _bone_nodes[point]
	if _built:
		push_warning("HumanoidRig: unknown attachment point '%s'" % point)
	return self


func get_hurtboxes() -> Array[Hurtbox]:
	return _hurtboxes.duplicate()


## Toggles each hurtbox's `monitorable` and its shape's `disabled` flag. Call it from
## physics or idle code, not from inside an area/body signal callback.
func set_hurtboxes_enabled(enabled: bool) -> void:
	for i: int in _hurtboxes.size():
		_hurtboxes[i].monitorable = enabled
		_hurt_shapes[i].disabled = not enabled


## White hit flash, 0..1 (Spec §6: 2 frames on contact).
func set_flash(amount: float) -> void:
	var energy := clampf(amount, 0.0, 1.0)
	for mat: StandardMaterial3D in _materials.values():
		mat.emission_energy_multiplier = energy


# --- Building --------------------------------------------------------------------------


func _build_skeleton() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	add_child(skeleton)
	for bone: StringName in PlaceholderBody.BONE_NAMES:
		var idx := skeleton.add_bone(bone)
		_bone_index[bone] = idx
		if PlaceholderBody.BONE_PARENT.has(bone):
			skeleton.set_bone_parent(idx, _bone_index[PlaceholderBody.BONE_PARENT[bone]])
		skeleton.set_bone_rest(idx, Transform3D(Basis.IDENTITY, PlaceholderBody.BONE_REST[bone] * _scale))
		var follower := Node3D.new()
		follower.name = "Bone%s" % bone
		skeleton.add_child(follower)
		_bone_nodes[bone] = follower
	skeleton.reset_bone_poses()
	_bone_globals.resize(skeleton.get_bone_count())


func _build_materials() -> void:
	for paint: int in PlaceholderBody.Paint.values():
		var mat := StandardMaterial3D.new()
		mat.roughness = 1.0
		mat.metallic_specular = 0.2
		# Emission stays enabled (black-energy) so set_flash() never switches shader variants.
		mat.emission_enabled = true
		mat.emission = Color.WHITE
		mat.emission_energy_multiplier = 0.0
		_materials[paint] = mat
	_apply_colors()


func _build_meshes() -> void:
	for part: PlaceholderBody.Part in PlaceholderBody.parts():
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = part.name
		mesh_instance.mesh = _make_mesh(part)
		mesh_instance.material_override = _materials[part.paint]
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh_instance.position = part.offset * _scale
		mesh_instance.rotation_degrees = part.rot_deg
		_bone_nodes[part.bone].add_child(mesh_instance)
		if PlaceholderBody.FP_HIDDEN_BONES.has(part.bone):
			_head_meshes.append(mesh_instance)
		else:
			_body_meshes.append(mesh_instance)
	_apply_layers()


func _make_mesh(part: PlaceholderBody.Part) -> Mesh:
	var size := part.size * _scale
	match part.shape:
		PlaceholderBody.Shape.BOX:
			var box := BoxMesh.new()
			box.size = size
			return box
		PlaceholderBody.Shape.CAPSULE:
			var capsule := CapsuleMesh.new()
			capsule.radius = size.x
			capsule.height = maxf(size.y, size.x * 2.0)
			capsule.radial_segments = 16
			capsule.rings = 4
			return capsule
		PlaceholderBody.Shape.CYLINDER:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = size.x
			cylinder.bottom_radius = size.x
			cylinder.height = size.y
			cylinder.radial_segments = 16
			cylinder.rings = 1
			return cylinder
	var sphere := SphereMesh.new()
	sphere.radius = size.x
	sphere.height = size.y
	sphere.radial_segments = 16
	sphere.rings = 8
	sphere.is_hemisphere = part.shape == PlaceholderBody.Shape.DOME
	return sphere


func _build_points() -> void:
	for point: StringName in PlaceholderBody.POINT_BONE:
		var marker := Marker3D.new()
		marker.name = point
		marker.position = PlaceholderBody.POINT_OFFSET[point] * _scale
		_bone_nodes[PlaceholderBody.POINT_BONE[point]].add_child(marker)
		_point_nodes[point] = marker


func _build_hurtboxes() -> void:
	var holder := Node3D.new()
	holder.name = "Hurtboxes"
	add_child(holder)
	var rest := PlaceholderBody.pose_globals({}, Vector3.ZERO, _scale)
	for spec: PlaceholderBody.HurtSpec in PlaceholderBody.hurt_specs():
		var hurtbox := Hurtbox.new()
		hurtbox.name = spec.name
		hurtbox.region = spec.region
		hurtbox.radius = spec.radius * _scale
		hurtbox.actor = actor
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		if spec.is_capsule():
			var a: Vector3 = rest[spec.bone_a] * (spec.offset_a * _scale)
			var b: Vector3 = rest[spec.bone_b] * (spec.offset_b * _scale)
			var capsule := CapsuleShape3D.new()
			capsule.radius = hurtbox.radius
			capsule.height = a.distance_to(b) + 2.0 * hurtbox.radius
			shape.shape = capsule
		else:
			var sphere := SphereShape3D.new()
			sphere.radius = hurtbox.radius
			shape.shape = sphere
		hurtbox.add_child(shape)
		holder.add_child(hurtbox)
		_hurtboxes.append(hurtbox)
		_hurt_shapes.append(shape)
		_hurt_specs.append(spec)


func _build_animation() -> void:
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	add_child(anim_player)
	anim_player.root_node = NodePath("..")
	anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# Every animation keys every animated bone (PlaceholderAnims.make), so nothing is left
	# stale. Deterministic mixing would blend cross-fades toward the rest pose (arms
	# dropping mid-blend), so cross-fades use normalized weights instead.
	anim_player.deterministic = false
	anim_player.add_animation_library(&"", PlaceholderAnims.build_library(_scale))
	anim_player.add_animation_library(_MOVE_LIBRARY, AnimationLibrary.new())


# --- Runtime ---------------------------------------------------------------------------


func _start(full_name: StringName, id: StringName, blend_s: float, speed: float) -> void:
	var restart := anim_player.assigned_animation == full_name
	anim_player.speed_scale = maxf(speed, 0.0)
	anim_player.play(full_name, maxf(blend_s, 0.0))
	if restart:
		anim_player.seek(0.0)
	_current = id


## Recompute bone poses from the skeleton's local poses, then move bone followers and
## hurtboxes. Pure parent-before-child FK, so it never depends on deferred updates.
func _refresh_pose() -> void:
	for i: int in skeleton.get_bone_count():
		var local := skeleton.get_bone_pose(i)
		var parent := skeleton.get_bone_parent(i)
		_bone_globals[i] = local if parent < 0 else _bone_globals[parent] * local
	for bone: StringName in _bone_nodes:
		_bone_nodes[bone].transform = _bone_globals[_bone_index[bone]]
	for i: int in _hurtboxes.size():
		var hurtbox := _hurtboxes[i]
		hurtbox.transform = _hurtbox_transform(_hurt_specs[i])
		if hurtbox.is_inside_tree():
			PhysicsServer3D.area_set_transform(hurtbox.get_rid(), hurtbox.global_transform)


func _hurtbox_transform(spec: PlaceholderBody.HurtSpec) -> Transform3D:
	var pose_a := _bone_globals[_bone_index[spec.bone_a]]
	var a := pose_a * (spec.offset_a * _scale)
	if not spec.is_capsule():
		return Transform3D(pose_a.basis.orthonormalized(), a)
	var b := _bone_globals[_bone_index[spec.bone_b]] * (spec.offset_b * _scale)
	var axis := b - a
	if axis.length_squared() < 1e-8:
		return Transform3D(pose_a.basis.orthonormalized(), a)
	axis = axis.normalized()
	# Capsule axis (local Y) along a -> b; roll taken from bone a's X axis.
	var side := pose_a.basis.x
	side -= axis * side.dot(axis)
	if side.length_squared() < 1e-6:
		side = pose_a.basis.z - axis * pose_a.basis.z.dot(axis)
	side = side.normalized()
	return Transform3D(Basis(side, axis, side.cross(axis)), (a + b) * 0.5)


func _apply_colors() -> void:
	if _materials.is_empty():
		return
	_materials[PlaceholderBody.Paint.BODY].albedo_color = body_color
	_materials[PlaceholderBody.Paint.PANTS].albedo_color = body_color.darkened(_PANTS_DARKEN)
	_materials[PlaceholderBody.Paint.ACCENT].albedo_color = accent_color
	_materials[PlaceholderBody.Paint.SKIN].albedo_color = skin_color
	_materials[PlaceholderBody.Paint.DARK].albedo_color = _DARK_COLOR


func _apply_layers() -> void:
	var default_layer := CombatTypes.bit(CombatTypes.VIS_DEFAULT)
	var head_layer := CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN) if first_person_body else default_layer
	for mesh_instance: MeshInstance3D in _head_meshes:
		mesh_instance.layers = head_layer
	for mesh_instance: MeshInstance3D in _body_meshes:
		mesh_instance.layers = default_layer
