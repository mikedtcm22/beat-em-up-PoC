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
## Cross-fades: the rig blends by itself instead of stacking AnimationPlayer blends (Godot
## keeps every earlier blend running with its own time, so an old pose would still weigh
## on a strike that started mid-fade). Starting an animation snapshots the pose on screen
## (local bone rotations and the Hips position) and plays the new animation at full
## weight; advance() then slerps from the snapshot to the animation's pose over the blend
## time. Each new animation fades from exactly what was shown, and nothing older survives
## its fade.
##
## Ragdoll (Spec §6; Milestone 2, game/actors/ragdoll.gd): advance() computes the FK itself
## from the skeleton's local (animation) poses; hurtboxes, rig points and
## get_point_transform() always use that pure-animation FK, so hits stay deterministic and
## independent of the ragdoll. The ragdoll is a pair of SkeletonModifier3Ds under the
## skeleton (a PhysicalBoneSimulator3D, then the Ragdoll), built on the first
## ragdoll_start() and inactive otherwise. While one runs, the skeleton's update (deferred by
## skeleton.advance() to the end of the physics frame) runs the modifiers and the Ragdoll
## moves the visual followers (meshes and attachment nodes) to the post-modifier pose
## (show_visual_pose(); get_visual_point_transform() reads it). With no ragdoll running the
## followers take the animation FK in advance(), exactly as before. Stopping a ragdoll
## (ragdoll_stop()) cross-fades from the last visual pose, like any animation start.
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
## How the body stands, walks, and starts and ends every move (PlaceholderPoses.STANCE_*):
## &"boxer" keeps the fists up at the chin (enemies, dummies); &"relaxed" lets the arms
## hang loose until a strike (the player, so the first-person view stays clear). Strike
## poses reach the same spots in both. Other values mean &"boxer". Set before build().
@export var stance: StringName = PlaceholderPoses.STANCE_BOXER
## Player only (Spec §10): skin-colored hands with light wraps and a dark fingerless-glove
## plate instead of the enemies' dark fingerless gloves (the same size). Set before build().
@export var wrapped_hands: bool = false
## Player only: put the meshes PlaceholderBody.is_fp_hidden() names (head, neck, chest,
## shoulder balls and the shoulder end of each upper arm) on CombatTypes.VIS_FP_HIDDEN.
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
## The damage look shown (DamageLook.Level), set through set_damage_look().
var damage_look: int = 0

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
## Animations whose body is already off its feet (flying through the air).
const _OFF_FEET_ANIMS: Array[StringName] = [&"launched", &"thrown"]
## A fall (PlaceholderAnims.FALL_JOIN_S) played from an off-feet animation may raise the
## head this much (meters at PlaceholderBody.REF_HEIGHT) above where it already is.
const _FALL_HEAD_SLACK := 0.02
## A fade out of an off-feet animation rolls over a side (_plan_roll()) only when a
## straight fade would point the spine this much higher (y of its unit up axis) than it
## points at either end.
const _ROLL_MIN_GAIN := 0.1

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
## Rig-side cross-fade (see the class docs): the local bone rotations and Hips position on
## screen when the current animation started, the fade length (0 = no fade running) and
## the sim time faded so far.
var _fade_rot: Array[Quaternion] = []
var _fade_hips: Vector3 = Vector3.ZERO
var _fade_s: float = 0.0
var _fade_t: float = 0.0
## When set, the Hips rotation fades by rolling over a side (the spine turns about the
## vertical through _fade_side, see _roll_path()) instead of slerping straight, so a body
## flying face up rolls onto its front without swinging up through upright (see
## _plan_roll()).
var _fade_rolls: bool = false
var _fade_side: Vector3 = Vector3.RIGHT
## Animation name -> Head height (rig space) sampled every 1/60 s, for _fall_join_time().
var _head_curves: Dictionary[StringName, PackedFloat32Array] = {}
## The visual ragdoll, built on the first ragdoll_start().
var _ragdoll: Ragdoll
## Each bone's world position after the latest advance() that moved time, and its velocity
## then (sim m/s), for a ragdoll's start velocities.
var _last_world: PackedVector3Array = PackedVector3Array()
var _bone_velocity: Array[Vector3] = []
var _motion_valid: bool = false


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
## A body that is already down or flying does not stand back up first: ko_* from a lying
## animation skips to the end of the slump, and ko_* or knockdown_* from launched or
## thrown skips the buckle and joins the fall where the head is no higher than it is now.
func play(anim: StringName, blend_s: float = 0.08, speed: float = 1.0) -> void:
	if not _built:
		push_warning("HumanoidRig.play('%s') before build()" % anim)
		return
	if not anim_player.has_animation(anim):
		push_warning("HumanoidRig: unknown animation '%s'" % anim)
		return
	var was_lying := _LYING_ANIMS.has(_current)
	var was_off_feet := _OFF_FEET_ANIMS.has(_current)
	# Rig space, as shown now (before the new animation's first advance()).
	var head_y := _bone_globals[_bone_index[&"Head"]].origin.y
	_flurry_mirrored = false
	_start(anim, anim, blend_s, speed)
	if was_lying and String(anim).begins_with("ko_"):
		var length := anim_player.get_animation(anim).length
		anim_player.seek(maxf(length - _KO_FROM_LYING_S, 0.0))
	elif was_off_feet:
		var start := 0.0
		if PlaceholderAnims.FALL_JOIN_S.has(anim):
			start = _fall_join_time(anim, head_y)
			anim_player.seek(start)
		_plan_roll(anim, start)


## Play the animation for `move`, built (and cached) so its length is exactly
## move.total_frames() / 60 s, it reaches the strike pose at move.startup / 60 s, holds it
## through the active frames, and returns to the stance by the end of recovery.
## The blend is capped at 75% of the startup so the strike pose is reached unblended.
## Consecutive body_flurry plays alternate the leading fist.
## Started while the move's charge animation (PlaceholderAnims.CHARGE_ANIMS, e.g.
## &"haymaker_charge") is the current one, it plays a variant that starts from the cocked
## charge pose and holds it until the wind-up time, so the release drives straight into
## the strike instead of winding up a second time. That fade lasts at least until the
## wind-up time, easing a partly reached charge into the cocked pose.
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
	var charge: StringName = PlaceholderAnims.CHARGE_ANIMS.get(move.get_anim(), &"")
	var from_charge := charge != &"" and charge == _current
	var key := StringName("%s__%d_%d_%d%s%s" % [move.get_anim(), move.startup, move.active,
			move.recovery, "_m" if mirrored else "", "_c" if from_charge else ""])
	var full := StringName("%s/%s" % [_MOVE_LIBRARY, key])
	if not anim_player.has_animation(full):
		anim_player.get_animation_library(_MOVE_LIBRARY).add_animation(key,
				PlaceholderAnims.build_move(move, _scale, mirrored, from_charge, stance))
	var blend := maxf(blend_s, 0.0)
	if from_charge:
		blend = maxf(blend, PlaceholderAnims.windup_time(move))
	blend = minf(blend, 0.75 * move.startup * PlaceholderAnims.FRAME_S)
	_start(full, move.get_anim(), blend, 1.0)


## The owner just moved this rig by `offset` (world meters) after starting an animation:
## the running cross-fade keeps starting from where the body was on screen (its Hips start
## moves back by `offset`), so the move does not show and the new animation takes the body
## from there. Without a fade running it does nothing. Call advance(0.0) after it to show
## the result in the same tick.
func carry_fade(offset: Vector3) -> void:
	if not _built or _fade_s <= 0.0:
		return
	var to_local := (global_transform if is_inside_tree() else transform).basis.inverse()
	_fade_hips -= to_local * offset


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


## Advance animation (and any cross-fade) by `dt` sim seconds, update the skeleton pose,
## sync hurtboxes. advance(0) applies the current animation time without moving it.
func advance(dt: float) -> void:
	if not _built:
		return
	var step := maxf(dt, 0.0)
	anim_player.advance(step)
	_apply_fade(step)
	skeleton.advance(step)
	_refresh_pose()
	_track_motion(step)
	if _ragdoll and _ragdoll.is_running():
		_ragdoll.sim_scale = TimeController.scale_for(actor) if actor else TimeController.sim_scale()


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


## Yaw in radians (positive turns left, -PI..PI) of the eyes' facing (EyePoint's -Z, flat)
## relative to the rig's forward, after the latest advance(). The first-person camera
## turns with it through spinning moves (MoveData.camera_spin_follow).
func eye_yaw() -> float:
	var to_world := global_transform if is_inside_tree() else transform
	var forward := to_world.basis.inverse() * (get_point_transform(&"EyePoint").basis * Vector3.FORWARD)
	return atan2(-forward.x, -forward.z)


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


## Hit flash, 0..1 (Spec §6: white for 2 frames on contact). `color` tints it (a perfect
## block flashes the defender cyan).
func set_flash(amount: float, color: Color = Color.WHITE) -> void:
	var energy := clampf(amount, 0.0, 1.0)
	for mat: StandardMaterial3D in _materials.values():
		mat.emission = color
		mat.emission_energy_multiplier = energy


## Damage look (Spec §6, "Damage you can see"): DamageLook.Level CLEAN, BRUISED or BLOODIED
## (game/fx/damage_look.gd). Materials only: bruises, then blood, on the skin and clothes.
## Set by presentation (VfxDirector) from the health; re-applying a level re-reads its tuning.
func set_damage_look(level: int) -> void:
	damage_look = level
	for paint: int in _materials:
		DamageLook.apply(_materials[paint], paint, level)


# --- Ragdoll (see the class docs and game/actors/ragdoll.gd) ---------------------------


## Start a ragdoll from the pose on screen: `full` for a body knocked off its feet (every
## bone), otherwise the stagger's partial ragdoll of the upper body, which fades back to the
## animation within `partial_length_s` sim seconds. The hit's kick is `push` (world m/s, the
## knockback) at `contact` (world), on the `part` body (Ragdoll.Part) nearest to it; every
## simulated body starts with `body_velocity` (the actor's new sim velocity) on top of its
## bone's velocity in the animation. A full ragdoll already running only takes the new
## kick. Builds the ragdoll on first use.
func ragdoll_start(full: bool, contact: Vector3, push: Vector3, body_velocity: Vector3,
		part: Ragdoll.Part = Ragdoll.Part.ANY, partial_length_s: float = INF) -> void:
	if not _built:
		return
	if _ragdoll == null:
		_ragdoll = Ragdoll.new()
		_ragdoll.setup(self)
	_ragdoll.sim_scale = TimeController.scale_for(actor) if actor else TimeController.sim_scale()
	var mode := Ragdoll.Mode.FULL if full else Ragdoll.Mode.PARTIAL
	var bone_velocity: Array[Vector3] = []
	if _motion_valid:
		bone_velocity = _bone_velocity
	_ragdoll.start(mode, contact, push, body_velocity, bone_velocity, part, partial_length_s)


## An extra hit on a running ragdoll (a stomp on a downed body): `push` (world m/s) at
## `contact` (world), on the `part` body nearest to it.
func ragdoll_hit(contact: Vector3, push: Vector3, part: Ragdoll.Part = Ragdoll.Part.ANY) -> void:
	if is_ragdolling():
		_ragdoll.hit(contact, push, part)


## The pose springs of a running ragdoll: Ragdoll.Phase.DOWN once it lies, LIMP for a KO.
func ragdoll_set_phase(phase: Ragdoll.Phase) -> void:
	if is_ragdolling():
		_ragdoll.set_phase(phase)


## Stop a running ragdoll. The animation takes over again, fading from the pose the ragdoll
## shows over `blend_s` sim seconds (0 = at once); call it after play() to fade into that
## animation from the ragdoll's pose (the get-up) instead of from the animation's.
func ragdoll_stop(blend_s: float = 0.0) -> void:
	if not is_ragdolling():
		return
	if blend_s > 0.0:
		# The pose on screen, in the rig's frame now (the owner may have moved it since).
		var to_rig := (global_transform if is_inside_tree() else transform).affine_inverse() \
				* _ragdoll.visual_rig_transform
		var hips := _bone_index[&"Hips"]
		for i: int in skeleton.get_bone_count():
			var shown := to_rig * _ragdoll.visual_pose(i)
			var parent := skeleton.get_bone_parent(i)
			var local := shown if parent < 0 else (to_rig * _ragdoll.visual_pose(parent)).affine_inverse() * shown
			_fade_rot[i] = local.basis.get_rotation_quaternion()
			if i == hips:
				_fade_hips = local.origin
		_fade_s = blend_s
		_fade_t = 0.0
		_fade_rolls = false
	_ragdoll.stop()


func is_ragdolling() -> bool:
	return _ragdoll != null and _ragdoll.is_running()


## Ragdoll.Mode.NONE, PARTIAL or FULL.
func ragdoll_mode() -> Ragdoll.Mode:
	return _ragdoll.mode if _ragdoll else Ragdoll.Mode.NONE


## The ragdoll (null until the first ragdoll_start()).
func get_ragdoll() -> Ragdoll:
	return _ragdoll


## Where a running ragdoll's hips lie relative to the animation's hips: the world offset
## along the floor (y = 0). Zero without a ragdoll.
func ragdoll_hips_offset() -> Vector3:
	if not is_ragdolling():
		return Vector3.ZERO
	var hips := _bone_index[&"Hips"]
	var to_world := global_transform if is_inside_tree() else transform
	var shown := (_ragdoll.visual_rig_transform * _ragdoll.visual_pose(hips)).origin
	var animated := (to_world * _bone_globals[hips]).origin
	return Vector3(shown.x - animated.x, 0.0, shown.z - animated.z)


## World transform of a bone or rig point as it is shown: the ragdoll's pose while one
## runs, otherwise get_point_transform() (the animation).
func get_visual_point_transform(point: StringName) -> Transform3D:
	if not is_ragdolling():
		return get_point_transform(point)
	var bone := point
	var offset := Vector3.ZERO
	if PlaceholderBody.POINT_BONE.has(point):
		bone = PlaceholderBody.POINT_BONE[point]
		offset = PlaceholderBody.POINT_OFFSET[point] * _scale
	if not _bone_index.has(bone):
		return get_point_transform(point)
	return _ragdoll.visual_rig_transform * _ragdoll.visual_pose(_bone_index[bone]) \
			* Transform3D(Basis.IDENTITY, offset)


## Rig lengths are PlaceholderBody lengths times this (height / REF_HEIGHT).
func rig_scale() -> float:
	return _scale


## Skeleton-space pose of skeleton bone `bone` in the animation (the FK hurtboxes and
## get_point_transform() use), after the latest advance().
func animation_pose(bone: int) -> Transform3D:
	return _bone_globals[bone]


## Ragdoll only: move the bone followers (meshes, attachments) to `globals`, the
## post-modifier skeleton-space pose of every bone.
func show_visual_pose(globals: Array[Transform3D]) -> void:
	for bone: StringName in _bone_nodes:
		_bone_nodes[bone].transform = globals[_bone_index[bone]]


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
	_fade_rot.resize(skeleton.get_bone_count())
	_last_world.resize(skeleton.get_bone_count())
	_bone_velocity.resize(skeleton.get_bone_count())


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
	for part: PlaceholderBody.Part in PlaceholderBody.parts(wrapped_hands):
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = part.name
		mesh_instance.mesh = _make_mesh(part)
		mesh_instance.material_override = _materials[part.paint]
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh_instance.position = part.offset * _scale
		mesh_instance.rotation_degrees = part.rot_deg
		_bone_nodes[part.bone].add_child(mesh_instance)
		if PlaceholderBody.is_fp_hidden(part):
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
	# The rig cross-fades by itself (_start(), _apply_fade()), so the player only ever runs
	# one animation at full weight. Every animation keys every animated bone
	# (PlaceholderAnims.make), so nothing is left stale.
	anim_player.deterministic = false
	anim_player.add_animation_library(&"", PlaceholderAnims.build_library(_scale, stance))
	anim_player.add_animation_library(_MOVE_LIBRARY, AnimationLibrary.new())


# --- Runtime ---------------------------------------------------------------------------


## Start `full_name` at full weight and fade into it from the pose on screen over
## `blend_s` sim seconds (see the class docs).
func _start(full_name: StringName, id: StringName, blend_s: float, speed: float) -> void:
	var restart := anim_player.assigned_animation == full_name
	_fade_s = maxf(blend_s, 0.0)
	_fade_t = 0.0
	_fade_rolls = false
	if _fade_s > 0.0:
		for i: int in skeleton.get_bone_count():
			_fade_rot[i] = skeleton.get_bone_pose_rotation(i)
		_fade_hips = skeleton.get_bone_pose_position(_bone_index[&"Hips"])
	anim_player.speed_scale = maxf(speed, 0.0)
	# Blend 0 clears Godot's own blend list: no earlier cross-fade keeps weighting its pose.
	anim_player.play(full_name, 0.0)
	if restart:
		anim_player.seek(0.0)
	_current = id


## Blend the animation's pose (just applied to the skeleton) with the snapshot taken by
## _start(). Ends exactly `_fade_s` after the start; advance(0) re-applies the same weight.
func _apply_fade(step: float) -> void:
	if _fade_s <= 0.0:
		return
	_fade_t += step
	var w := _fade_t / _fade_s
	if w >= 1.0 - 1e-6:
		_fade_s = 0.0
		return
	var hips := _bone_index[&"Hips"]
	for i: int in skeleton.get_bone_count():
		var to := skeleton.get_bone_pose_rotation(i)
		if _fade_rolls and i == hips:
			skeleton.set_bone_pose_rotation(i, _roll_path(_fade_rot[i], to, _fade_side, w))
		else:
			skeleton.set_bone_pose_rotation(i, _fade_rot[i].slerp(to, w))
	skeleton.set_bone_pose_position(hips, _fade_hips.lerp(skeleton.get_bone_pose_position(hips), w))


## Hips rotation `w` of the way from `from` to `to` rolling over a side: the spine (the
## Hips' up axis) turns about the vertical through the horizontal `side` while its height
## (y of the unit axis) moves straight from its start to its end value, so it always
## stays between the two: it never swings up past upright, nor drops flat below an end
## pose that is tilted up (the head would bounce back up into it); the twist about the
## spine is slerped on its own.
static func _roll_path(from: Quaternion, to: Quaternion, side: Vector3, w: float) -> Quaternion:
	var spine_from := from * Vector3.UP
	var spine_to := to * Vector3.UP
	var flat_from := _heading(spine_from, side)
	var turn := flat_from.signed_angle_to(side, Vector3.UP) \
			+ side.signed_angle_to(_heading(spine_to, side), Vector3.UP)
	var y := lerpf(spine_from.y, spine_to.y, w)
	var spine := flat_from.rotated(Vector3.UP, turn * w) * sqrt(maxf(1.0 - y * y, 0.0)) + Vector3.UP * y
	return Quaternion(Vector3.UP, spine.normalized()) * _twist(from).slerp(_twist(to), w)


## Horizontal unit direction of `axis`, or `fallback` when `axis` is (nearly) vertical.
static func _heading(axis: Vector3, fallback: Vector3) -> Vector3:
	var flat := Vector3(axis.x, 0.0, axis.z)
	return flat.normalized() if flat.length_squared() > 1e-6 else fallback


## The part of `q` that turns about its own up axis (q = swing * twist).
static func _twist(q: Quaternion) -> Quaternion:
	return Quaternion(Vector3.UP, q * Vector3.UP).inverse() * q


## For a fade out of an off-feet animation into `anim` (from `start` seconds): roll the
## Hips over a side (_roll_path()) when a straight slerp would swing the spine up through
## upright. A body launched face up (arched back) that lands face down would otherwise
## raise its head on the way down.
func _plan_roll(anim: StringName, start: float) -> void:
	if _fade_s <= 0.0:
		return
	var animation := anim_player.get_animation(anim)
	var track := animation.find_track(^"Skeleton3D:Hips", Animation.TYPE_ROTATION_3D)
	if track < 0:
		return
	var from := _fade_rot[_bone_index[&"Hips"]]
	var to := animation.rotation_track_interpolate(track, start)
	var spine_from := from * Vector3.UP
	var spine_to := to * Vector3.UP
	var straight_peak := -1.0
	for s: int in range(1, 16):
		straight_peak = maxf(straight_peak, (from.slerp(to, s / 16.0) * Vector3.UP).y)
	if straight_peak - maxf(spine_from.y, spine_to.y) < _ROLL_MIN_GAIN:
		return
	# The sides lie across the plane a straight fade swings the spine through; take the
	# one the spine reaches with the shorter swing.
	var side := spine_from.cross(spine_to)
	side.y = 0.0
	side = side.normalized() if side.length_squared() > 1e-4 else Vector3.RIGHT
	var swing := spine_from.angle_to(side) + side.angle_to(spine_to)
	if spine_from.angle_to(-side) + (-side).angle_to(spine_to) < swing:
		side = -side
	_fade_side = side
	_fade_rolls = true


## Where a fall (PlaceholderAnims.FALL_JOIN_S) starts when the body is already off its
## feet with the head at `head_y`: after the buckle, and late enough that the head never
## rises more than _FALL_HEAD_SLACK above `head_y` for the rest of the animation.
func _fall_join_time(anim: StringName, head_y: float) -> float:
	var curve := _head_curve(anim)
	var limit := head_y + _FALL_HEAD_SLACK * _scale
	var first := curve.size() - 1
	# Walk back from the end while the rest of the animation stays under the limit.
	while first > 0 and curve[first - 1] <= limit:
		first -= 1
	var length := anim_player.get_animation(anim).length
	var join: float = PlaceholderAnims.FALL_JOIN_S[anim]
	return minf(maxf(join, first * PlaceholderAnims.FRAME_S), length)


## Head height (rig space) of `anim` sampled every 1/60 s, end included. Pure FK over the
## Head's parent chain from the animation tracks; cached per animation.
func _head_curve(anim: StringName) -> PackedFloat32Array:
	if _head_curves.has(anim):
		return _head_curves[anim]
	var animation := anim_player.get_animation(anim)
	var chain: Array[int] = []
	var bone := _bone_index[&"Head"]
	while bone >= 0:
		chain.push_front(bone)
		bone = skeleton.get_bone_parent(bone)
	var tracks: Array[int] = []
	for idx: int in chain:
		tracks.append(animation.find_track(NodePath("Skeleton3D:%s" % skeleton.get_bone_name(idx)),
				Animation.TYPE_ROTATION_3D))
	var hips_track := animation.find_track(^"Skeleton3D:Hips", Animation.TYPE_POSITION_3D)
	var curve := PackedFloat32Array()
	var samples := ceili(animation.length / PlaceholderAnims.FRAME_S - 1e-4)
	for s: int in samples + 1:
		var t := minf(s * PlaceholderAnims.FRAME_S, animation.length)
		var xf := Transform3D.IDENTITY
		for c: int in chain.size():
			var idx := chain[c]
			var origin := skeleton.get_bone_rest(idx).origin
			if idx == _bone_index[&"Hips"] and hips_track >= 0:
				origin = animation.position_track_interpolate(hips_track, t)
			var rot := Quaternion.IDENTITY
			if tracks[c] >= 0:
				rot = animation.rotation_track_interpolate(tracks[c], t)
			xf = xf * Transform3D(Basis(rot), origin)
		curve.append(xf.origin.y)
	_head_curves[anim] = curve
	return curve


## Recompute bone poses from the skeleton's local poses, then move bone followers and
## hurtboxes. Pure parent-before-child FK, so it never depends on deferred updates.
func _refresh_pose() -> void:
	for i: int in skeleton.get_bone_count():
		var local := skeleton.get_bone_pose(i)
		var parent := skeleton.get_bone_parent(i)
		_bone_globals[i] = local if parent < 0 else _bone_globals[parent] * local
	# A running ragdoll moves the followers itself (show_visual_pose()).
	if not is_ragdolling():
		for bone: StringName in _bone_nodes:
			_bone_nodes[bone].transform = _bone_globals[_bone_index[bone]]
	for i: int in _hurtboxes.size():
		var hurtbox := _hurtboxes[i]
		hurtbox.transform = _hurtbox_transform(_hurt_specs[i])
		if hurtbox.is_inside_tree():
			PhysicsServer3D.area_set_transform(hurtbox.get_rid(), hurtbox.global_transform)


## After an advance() that moved time by `step` sim seconds: each bone's world velocity
## (sim m/s) since the last such advance(), for a ragdoll's start (ragdoll_start()).
func _track_motion(step: float) -> void:
	if step <= 0.0:
		return
	var to_world := global_transform if is_inside_tree() else transform
	for i: int in _bone_globals.size():
		var p := (to_world * _bone_globals[i]).origin
		if _motion_valid:
			_bone_velocity[i] = (p - _last_world[i]) / step
		_last_world[i] = p
	_motion_valid = true


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
