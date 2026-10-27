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
## the same pose (the attachment nodes show a running ragdoll's instead, see "Ragdoll").
## play() and play_move() only choose the animation; the pose changes on the next
## advance(), whose dt is the first slice of the new animation.
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
##
## Art (Milestone 4): with `art` set, the primitives above are still built (names, followers,
## layers, materials) but hidden, as the view proxies the first-person tests and camera keep
## measuring, and SkinnedArt draws the character's skinned meshes on the skeleton instead.
## Everything that paints the body (materials, flash, damage look) is RigPaint's.

@export var height: float = 1.8
@export var body_color: Color = Color(0.22, 0.42, 0.78):
	set(value):
		body_color = value
		paint.apply_colors()
@export var accent_color: Color = Color(0.92, 0.9, 0.85):
	set(value):
		accent_color = value
		paint.apply_colors()
@export var skin_color: Color = Color(0.86, 0.66, 0.5):
	set(value):
		skin_color = value
		paint.apply_colors()
## The trousers' color. Fully transparent (the default) paints them body_color darkened, as
## on the enemies and dummies; the player's are a color of their own (_configure_rig()).
@export var pants_color: Color = Color.TRANSPARENT:
	set(value):
		pants_color = value
		paint.apply_colors()
## How the body stands, walks, and starts and ends every move (PlaceholderPoses.STANCE_*):
## &"boxer" keeps the fists up at the chin (enemies, dummies); &"relaxed" lets the arms
## hang loose until a strike (the player, so the first-person view stays clear). Strike
## poses reach the same spots in both. Other values mean &"boxer". Set before build().
@export var stance: StringName = PlaceholderPoses.STANCE_BOXER
## Player only (Spec §10): skin-colored hands with light wraps and a dark fingerless-glove
## plate instead of the enemies' dark fingerless gloves (the same size). Set before build().
@export var wrapped_hands: bool = false
## The skinned art this rig wears, or null for the placeholder primitives alone (exactly the
## 41 meshes, 45 with wrapped_hands). Set before build(), by CombatActor._configure_art().
@export var art: CharacterArt
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
## Everything that paints this body: materials, flashes, the damage look and the outline.
var paint: RigPaint

## Group of the primitive meshes of a rig with art (every one of them, hidden while the art
## shows): the view proxies, which the first-person tests and camera keep measuring.
const VIEW_PROXY_GROUP := &"view_proxy"
## Group of the skinned art's meshes (SkinnedArt.attach()).
const ART_GROUP := &"rig_art"
## Library name for the move animations built by play_move().
const _MOVE_LIBRARY := &"moves"
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
## The step of a Fibonacci hash (the golden ratio's fraction): consecutive hashes land evenly
## spread round a loop (see _idle_phase()).
const _IDLE_PHASE_STEP := 0.6180339887

## The named animation libraries built so far, per stance and scale (see _named_library()).
static var _named_libraries: Dictionary[String, AnimationLibrary] = {}
## What the Motion tunables and move_speed read when the cached libraries were built, and how
## many times a change to them has dropped the cache (see _on_motion_tuning_changed()): a rig
## whose own count is behind takes the rebuilt library at its next advance().
static var _library_signature: Array = []
static var _library_revision: int = 0

var _built: bool = false
## The _library_revision this rig's named library was taken at.
var _library_seen: int = 0
## Where in its loop the idle starts (see _own_idle_share()).
var _idle_share: float = 0.0
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
## Paint (PlaceholderBody.Paint) -> material. One set per rig so flashes stay per actor. The
## dictionary RigPaint fills (paint.materials).
var _materials: Dictionary[int, ShaderMaterial] = {}
## The contact flash's overlay (flash_at()), made on first use: every material's next_pass
## while it runs, nobody's otherwise. Its point, in the frame of the bone node nearest it.
var _flash_overlay: ShaderMaterial
var _flash_on: bool = false
## A contact flash is aimed (flash_at()), drawn or held back for show_flash().
var _flash_aimed: bool = false
var _flash_anchor: Node3D
var _flash_local: Vector3 = Vector3.ZERO
## The aimed flash's radius was widened for a finisher (hit_flash_finisher_radius_mult): once per flash.
var _flash_widened: bool = false
## Whether the one static listener for finishers' hits (_watch_finishers()) is connected.
static var _finishers_watched: bool = false
var _head_meshes: Array[MeshInstance3D] = []
var _body_meshes: Array[MeshInstance3D] = []
## The skinned art's meshes, once SkinnedArt.attach() has added them.
var _art_meshes: Array[MeshInstance3D] = []
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


func _init() -> void:
	paint = RigPaint.new(self)
	_materials = paint.materials


## Create skeleton, meshes, hurtboxes, rig points and the animation library. Idempotent:
## a second call does nothing. Starts in idle, already posed.
func build() -> void:
	if _built:
		return
	_built = true
	_scale = maxf(height, 0.1) / PlaceholderBody.REF_HEIGHT
	_build_skeleton()
	paint.build()
	paint.warm_up(self)
	_build_meshes()
	_build_points()
	if build_hurtboxes:
		_build_hurtboxes()
	_build_animation()
	_idle_share = _own_idle_share()
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
	if _library_seen != _library_revision:
		_refresh_library()
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
## recipe (move animations are built on demand by play_move()), the enemy moves' included.
func has_anim(anim: StringName) -> bool:
	return PlaceholderAnims.ANIM_IDS.has(anim) or PlaceholderAnims.MOVE_IDS.has(anim) \
			or PlaceholderEnemyPoses.has_recipe(anim)


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


## Show or hide the whole body: a KO's blink-off and a comeback's blink-in, both timed by
## the owner (CombatActor). Nothing else changes: the pose, the hurtboxes and a running
## ragdoll carry on as they were.
func set_shown(shown: bool) -> void:
	visible = shown


## True when skinned art is on this rig (SkinnedArt.attach() added meshes). A rig whose art
## failed to attach keeps drawing its primitives and counts as having none.
func has_art() -> bool:
	return not _art_meshes.is_empty()


## The skinned art's meshes (read only); empty on a rig without art.
func art_meshes() -> Array[MeshInstance3D]:
	return _art_meshes


## Show the skinned art (`shown` true) or the primitives it stands in for (false), live: the
## A/B behind Tuning's look_show_art. The hidden set stays built either way, as the view
## proxies. A rig without art meshes keeps its primitives visible.
func set_art_shown(shown: bool) -> void:
	if _art_meshes.is_empty():
		return
	for mesh_instance: MeshInstance3D in _art_meshes:
		mesh_instance.visible = shown
	for mesh_instance: MeshInstance3D in _head_meshes:
		mesh_instance.visible = not shown
	for mesh_instance: MeshInstance3D in _body_meshes:
		mesh_instance.visible = not shown


## Whole-body flash, 0..1, as emission on every material: the cyan parry flash (a perfect
## block flashes the defender). Ends a contact flash (flash_at()); 0 clears both.
func set_flash(amount: float, color: Color = Color.WHITE) -> void:
	_show_flash_overlay(false)
	_flash_aimed = false
	paint.set_flash(amount, color)


## Contact flash (Spec §6, localized by Game-boy on 2026-10-24): the body mixes toward
## `color` around `point` (world space, the hit's contact point), at `strength` (0..1) out
## to `core` (0..1) of `radius` meters, fading smoothly to nothing at `radius`. A radius
## that covers the body (about 4 m) whites it all, the flash before the departure. Drawn by this
## rig's overlay (game/fx/hit_flash.gdshader) as every material's next_pass, set only while
## the flash runs; the base materials (DamageLook's marks) stay as they are.
## The point goes on the struck part as it is drawn: `point` is clamped onto the nearest
## hurtbox (hurt_point(); a thrown weapon's or a flying body's contact lies off the body),
## taken into the animation frame of the bone along that hurtbox nearest it, and placed on
## that bone's drawn follower, which it then rides (follow_flash()). A body that is not
## ragdolling is drawn in its animation pose, so a contact inside a hurtbox stays where it
## is; a ragdolling or staggering body (drawn away from its hurtboxes) flashes on the
## struck part where it is shown. Ends a whole-body flash; set_flash(0.0) clears it.
## With `shown` false the flash is aimed on the struck part but drawn only from show_flash()
## (a finisher's waits out the impact frame).
## First-person feel (Look > FP feel, both off by default): the overlay is told Tuning's
## hit_flash_fp_max_share, the cap the shader puts on the flash's on-screen share of the view, and a
## clean finisher's radius is widened by hit_flash_finisher_radius_mult when its hit lands
## (CombatEvents.hit_landed, _on_hit_landed_widen()). The radius, core, strength and the point that
## the struck actor passes in are used as they come.
func flash_at(point: Vector3, strength: float, radius: float, core: float,
		color: Color = Color.WHITE, shown: bool = true) -> void:
	set_flash(0.0)
	if not _built or strength <= 0.0 or radius <= 0.0:
		return
	RigPaint.end_warm_up()
	if _flash_overlay == null:
		_flash_overlay = ShaderMaterial.new()
		_flash_overlay.shader = RigPaint.FLASH_SHADER
		# First among the transparent passes, so the comic effects draw over it.
		_flash_overlay.render_priority = Material.RENDER_PRIORITY_MIN
	_flash_anchor = self
	_flash_local = point
	if is_inside_tree():
		var local := global_transform.affine_inverse() * point
		var spec := _nearest_hurt(local)
		local = _onto_hurt(spec, local)
		var bone := _carrier_bone(spec, local)
		_flash_anchor = _bone_nodes[bone]
		_flash_local = _bone_globals[_bone_index[bone]].affine_inverse() * local
		point = _flash_anchor.to_global(_flash_local)
	_flash_overlay.set_shader_parameter(&"flash_point", point)
	_flash_overlay.set_shader_parameter(&"flash_radius", radius)
	_flash_overlay.set_shader_parameter(&"flash_core", clampf(core, 0.0, 1.0))
	_flash_overlay.set_shader_parameter(&"flash_strength", clampf(strength, 0.0, 1.0))
	_flash_overlay.set_shader_parameter(&"flash_color", color)
	# First-person feel (M4, P3-flash): the cap on the flash's on-screen share (0 = off), and the
	# finisher's widening (the hit's tier arrives with CombatEvents.hit_landed, _widen_finisher_flash()).
	_flash_overlay.set_shader_parameter(&"flash_max_share", Tuning.data.hit_flash_fp_max_share)
	_flash_widened = false
	_watch_finishers()
	_flash_aimed = true
	if shown:
		_show_flash_overlay(true)


## Draw the contact flash flash_at() aimed with `shown` false, on the struck part as it is
## drawn now. Nothing once set_flash() has cleared it.
func show_flash() -> void:
	if _flash_aimed:
		_show_flash_overlay(true)
		follow_flash()


## Keep a running contact flash on the spot it struck after the body moved (its owner calls
## this each tick while the flash runs, after advance(); show_visual_pose() calls it as a
## ragdoll moves the body).
func follow_flash() -> void:
	if _flash_on and _flash_anchor != null and _flash_anchor.is_inside_tree():
		_flash_overlay.set_shader_parameter(&"flash_point", _flash_anchor.to_global(_flash_local))


## The contact flash's overlay while one runs (shader parameters flash_point, flash_radius,
## flash_core, flash_strength, flash_color, flash_max_share), else null.
func flash_overlay() -> ShaderMaterial:
	return _flash_overlay if _flash_on else null


## The point on the body nearest `point` (world space) as the hurtboxes see it, in the
## animation pose like every hit: `point` itself inside a hurtbox, otherwise the nearest
## point on the surface of the nearest hurtbox. For contacts that are not on the body, such
## as a thrown weapon's (Weapon) or a flying body's.
func hurt_point(point: Vector3) -> Vector3:
	if not _built:
		return point
	var to_world := global_transform if is_inside_tree() else transform
	var local := to_world.affine_inverse() * point
	return to_world * _onto_hurt(_nearest_hurt(local), local)


## The contact flash's strength share at `dist` meters from its point, as the overlay shader
## computes it: 1 out to `core` of `radius`, then a smoothstep down to 0 at `radius`.
static func flash_falloff(dist: float, radius: float, core: float) -> float:
	var inner := radius * clampf(core, 0.0, 1.0)
	var span := radius - inner
	if span <= 0.0:
		return 1.0 if dist <= radius else 0.0
	return 1.0 - smoothstep(0.0, 1.0, clampf((dist - inner) / span, 0.0, 1.0))


## The reach (m) of a contact flash of `radius` on a surface `depth` m in front of the lens, with
## the first-person cap (Tuning hit_flash_fp_max_share = `max_share`, 0 = no cap), as the overlay
## shader's capped_radius() computes it: the radius whose disc covers `max_share` of the view at
## that depth (`proj11` is the camera's projection[1][1], 1 / tan(fov / 2); `aspect` the
## viewport's width over its height), or `radius` when that is smaller. The core shrinks with it.
static func flash_capped_radius(radius: float, depth: float, proj11: float, aspect: float,
		max_share: float) -> float:
	if max_share <= 0.0:
		return radius
	var half_heights := sqrt(4.0 * aspect * max_share / PI)
	return minf(radius, half_heights * maxf(depth, 0.0) / maxf(proj11, 0.0001))


## The share (0..1) of the view a flash disc of `radius` covers on a surface `depth` m in front
## of the lens: the inverse of flash_capped_radius()'s cap.
static func flash_view_share(radius: float, depth: float, proj11: float, aspect: float) -> float:
	var half_heights := radius * proj11 / maxf(depth, 0.0001)
	return minf(PI * half_heights * half_heights / (4.0 * aspect), 1.0)


## Listen, once, for the hits that land: a clean finisher's flash is widened (r3look-05). The flash
## itself is aimed by the struck actor inside receive_hit(), which knows nothing of a hit's tier
## here, and CombatEvents.hit_landed follows it in the same tick, so the radius is scaled then.
static func _watch_finishers() -> void:
	if not _finishers_watched:
		_finishers_watched = true
		CombatEvents.hit_landed.connect(_on_hit_landed_widen)


## CombatEvents.hit_landed: the struck rig's flash of a clean finisher, wider by Tuning's
## hit_flash_finisher_radius_mult. A blocked finisher (and a guard break) keeps the ordinary size.
static func _on_hit_landed_widen(hit: HitInfo) -> void:
	if hit.tier != CombatTypes.HitTier.FINISHER or hit.blocked or not is_instance_valid(hit.victim):
		return
	var struck := hit.victim.get(&"rig") as HumanoidRig
	if struck != null:
		struck._widen_flash(Tuning.data.hit_flash_finisher_radius_mult)


## Scale the aimed contact flash's radius by `mult`, once per flash (a hit that lands twice in a
## tick, or the finisher's second target, widens it once). The flash's point and core stay.
func _widen_flash(mult: float) -> void:
	if not _flash_aimed or _flash_widened or _flash_overlay == null or mult <= 1.0:
		return
	_flash_widened = true
	_flash_overlay.set_shader_parameter(&"flash_radius", float(_flash_overlay.get_shader_parameter(&"flash_radius")) * mult)


func _show_flash_overlay(on: bool) -> void:
	if on == _flash_on:
		return
	_flash_on = on
	paint.show_flash_overlay(on, _flash_overlay)


## Damage look (Spec §6, "Damage you can see"): DamageLook.Level CLEAN, BRUISED or BLOODIED
## (game/fx/damage_look.gd). Materials only: bruises, then blood, on the skin and clothes,
## as a swap of the detail texture (never of the shader variant).
## Set by presentation (VfxDirector) from the health; re-applying a level re-reads its tuning.
func set_damage_look(level: int) -> void:
	damage_look = level
	paint.set_damage_look(level)


# --- Ragdoll (see the class docs and game/actors/ragdoll.gd) ---------------------------


## Start a ragdoll from the pose on screen: `full` for a body knocked off its feet (every
## bone), otherwise the stagger's partial ragdoll of the upper body, which fades back to the
## animation within `partial_length_s` sim seconds. The hit's kick is `push` (world m/s, the
## knockback) at `contact` (world), on the `part` body (Ragdoll.Part): its strike body,
## whatever the ragdoll's history (Ragdoll.STRIKE_BONES); every
## simulated body starts with `body_velocity` (the actor's new sim velocity) on top of its
## bone's velocity in the animation. A full ragdoll already running only takes the new
## kick. A full one started `at_once` shows alone from the start, from the pose on screen,
## instead of rising in from the animation's snap: a body launched out of a hold, one the
## world stops right away (a wall, a crate, the curb behind it) and one launched from behind
## (Ragdoll.start()); out of a running stagger the head and arms do not jump either.
## Builds the ragdoll on first use.
func ragdoll_start(full: bool, contact: Vector3, push: Vector3, body_velocity: Vector3,
		part: Ragdoll.Part = Ragdoll.Part.ANY, partial_length_s: float = INF, at_once: bool = false) -> void:
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
	_ragdoll.start(mode, contact, push, body_velocity, bone_velocity, part, partial_length_s, at_once)


## An extra hit on a running ragdoll (a stomp on a downed body): `push` (world m/s) at
## `contact` (world), on the `part` body nearest to it; with `strike`, on the part's strike
## body (Ragdoll.STRIKE_BONES) as ragdoll_start()'s kick lands (a stagger's lean).
func ragdoll_hit(contact: Vector3, push: Vector3, part: Ragdoll.Part = Ragdoll.Part.ANY,
		strike: bool = false) -> void:
	if is_ragdolling():
		_ragdoll.hit(contact, push, part, strike)


## A running full ragdoll flies to a landing in `lying_anim` (a face-down one): it turns
## toward that animation's hips in the air (Ragdoll.aim_landing()).
func ragdoll_aim_landing(lying_anim: StringName) -> void:
	if not is_ragdolling() or not anim_player.has_animation(lying_anim):
		return
	var animation := anim_player.get_animation(lying_anim)
	var track := animation.find_track(^"Skeleton3D:Hips", Animation.TYPE_ROTATION_3D)
	if track >= 0:
		# Root is never animated: the Hips' local rotation is their rig-space one.
		_ragdoll.aim_landing(animation.rotation_track_interpolate(track, 0.0))


## A full ragdoll still rising in from the animation's snap shows alone from now on, taken
## over from the pose on screen (Ragdoll.take_over()). Nothing without one.
func ragdoll_take_over() -> void:
	if is_ragdolling():
		_ragdoll.take_over()


## The owner's capsule is stopped by the world (a wall, a crate, the curb) while a full
## ragdoll flies: it takes over from the pose on screen and its hips are pulled to the
## capsule less until it lands (Ragdoll.set_blocked()). Nothing without a flying one.
func ragdoll_set_blocked(blocked: bool) -> void:
	if is_ragdolling():
		_ragdoll.set_blocked(blocked)


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
		# The pose on screen, in the rig's frame now (the owner may have moved it since, a
		# get-up moving it under the ragdoll's hips).
		var to_rig := (global_transform if is_inside_tree() else transform).affine_inverse() \
				* _ragdoll.visual_rig_transform
		var hips := _bone_index[&"Hips"]
		for i: int in skeleton.get_bone_count():
			var shown := to_rig * _ragdoll.visual_pose(i)
			var parent := skeleton.get_bone_parent(i)
			var local := shown if parent < 0 else (to_rig * _ragdoll.visual_pose(parent)).affine_inverse() * shown
			_fade_rot[i] = local.basis.get_rotation_quaternion()
			if i == hips:
				# The fade places the Hips on its parent (Root, a root bone) as the fade starts
				# it: Root's faded rotation at its animation position in the rig's frame now.
				# Taken from the old frame instead, the body would jump by the owner's move.
				var root_start := Transform3D(Basis(_fade_rot[parent]), skeleton.get_bone_pose_position(parent))
				_fade_hips = (root_start.affine_inverse() * shown).origin
		_fade_s = blend_s
		_fade_t = 0.0
		_fade_rolls = false
	_ragdoll.stop()


## True while a ragdoll (partial or full) runs on this rig.
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
## post-modifier skeleton-space pose of every bone. A running contact flash moves with them
## (it would otherwise trail the drawn body by the tick until the owner's follow_flash()).
func show_visual_pose(globals: Array[Transform3D]) -> void:
	for bone: StringName in _bone_nodes:
		_bone_nodes[bone].transform = globals[_bone_index[bone]]
	follow_flash()


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


func _build_meshes() -> void:
	for part: PlaceholderBody.Part in PlaceholderBody.parts(wrapped_hands):
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = part.name
		mesh_instance.mesh = _make_mesh(part)
		mesh_instance.material_override = _materials[part.paint]
		mesh_instance.material_overlay = paint.outline_material_for(part)
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh_instance.position = part.offset * _scale
		mesh_instance.rotation_degrees = part.rot_deg
		_bone_nodes[part.bone].add_child(mesh_instance)
		if art != null:
			mesh_instance.add_to_group(VIEW_PROXY_GROUP)
		if PlaceholderBody.is_fp_hidden(part):
			_head_meshes.append(mesh_instance)
		else:
			_body_meshes.append(mesh_instance)
	_apply_layers()
	if art != null:
		_art_meshes = SkinnedArt.attach(self, art)
		_apply_layers()
		set_art_shown(Tuning.data.look_show_art)
		if has_art():
			Tuning.changed.connect(_on_tuning_changed)


## Tuning's look_show_art (the live A/B of the art and the primitives) reaches every rig
## that has art.
func _on_tuning_changed(property: StringName) -> void:
	if property == &"look_show_art" or property == &"":
		set_art_shown(Tuning.data.look_show_art)


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
	anim_player.add_animation_library(&"", _named_library(_scale, stance))
	anim_player.add_animation_library(_MOVE_LIBRARY, AnimationLibrary.new())
	_library_seen = _library_revision


## The named library of rigs of `rig_scale` standing in `stance_id`: built once (about 8 ms of the
## 9 to 15 a rig costs to build, a visible hitch for each enemy of a wave) and shared by every rig
## of that size and stance. Its clips depend on those two alone and nothing alters them after the
## build (the rig only reads them: lengths, track samples, head curves), so one library serves any
## number of AnimationPlayers. The per-move "moves" library stays per rig: the clips of a move
## are built the first time that rig plays it. The Motion tunables and move_speed are read when it
## is built, so a change to one of them drops the cache (_on_motion_tuning_changed()) and the next
## call builds the library again.
static func _named_library(rig_scale: float, stance_id: StringName) -> AnimationLibrary:
	_watch_motion_tuning()
	var key := "%s@%d" % [stance_id, roundi(rig_scale * 10000.0)]
	if not _named_libraries.has(key):
		_library_signature = _motion_signature()
		_named_libraries[key] = PlaceholderAnims.build_library(rig_scale, stance_id)
	return _named_libraries[key]


## Listen, once, for the tunables the named clips are built from.
static func _watch_motion_tuning() -> void:
	if not Tuning.changed.is_connected(_on_motion_tuning_changed):
		Tuning.changed.connect(_on_motion_tuning_changed)


## Every value the named clips are built from, in the order PlaceholderAnims.Life declares them
## (read through its script variables, so a value added there is watched without a change here).
static func _motion_signature() -> Array:
	var life := PlaceholderAnims.Life.from_tuning()
	var values: Array = []
	for info: Dictionary in life.get_property_list():
		if int(info.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			values.append(life.get(info.name))
	return values


## Tuning.changed: a Motion tunable, move_speed or Debug's look_motion_polish (or a whole-set
## change: a preset, a reset) that changes what the named clips are built from drops the cached
## libraries, so the F1 sliders are live. A change that leaves every value as it was (a reset
## to the values already in use) does nothing: no rig takes a new library.
static func _on_motion_tuning_changed(property: StringName) -> void:
	if property != &"" and property != &"move_speed" and not String(property).begins_with("look_motion_"):
		return
	if _motion_signature() == _library_signature:
		return
	_named_libraries.clear()
	_library_revision += 1


## Take the library the cache holds now (built if it has to be) in place of the one this rig
## was built with. A named clip that is playing goes on from the same share of its length on the
## new clip (a stride or a breath may have changed length), faded in from the pose on screen
## over locomotion_blend_s as every start is, so nothing pops; a move's clip (the "moves"
## library is per rig and never rebuilt) and a rig with nothing playing are left as they are.
func _refresh_library() -> void:
	_library_seen = _library_revision
	var fresh := _named_library(_scale, stance)
	var old := anim_player.get_animation_library(&"")
	if fresh == old:
		return
	var playing := anim_player.assigned_animation
	var carry := playing != &"" and old.has_animation(playing)
	var share := 0.0
	if carry and anim_player.current_animation_length > 0.0:
		share = anim_player.current_animation_position / anim_player.current_animation_length
	var speed := anim_player.speed_scale
	anim_player.remove_animation_library(&"")
	anim_player.add_animation_library(&"", fresh)
	if carry and fresh.has_animation(playing):
		_start(playing, _current, locomotion_blend_s, speed)
		anim_player.seek(share * fresh.get_animation(playing).length)


## Where in its loop this rig's idle starts, as a share of the clip's length: a body of the crowd
## (its actor is in the group "ai_enemy": EnemyActor joins it before it builds its body) takes it
## from its actor's name, a Fibonacci hash, so the Punks of one wave, named Punk1 to Punk6, do not
## breathe and bounce in step. Nothing random: the same name gives the same phase in every run.
## Every other body, the player's, a training dummy's and a scratch rig's, starts at the first key as
## it always did (the player's lens rides his head, and the dummies are tuning targets that stand
## alone). Read once, when the rig is built, so an actor that leaves its groups (a KO'd body, a
## scripted showcase) keeps the phase its idle was started at.
func _own_idle_share() -> float:
	if actor == null or not actor.is_in_group(&"ai_enemy"):
		return 0.0
	return fposmod(float(String(actor.name).hash()) * _IDLE_PHASE_STEP, 1.0)


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
	if id == &"idle" and full_name == &"idle" and _idle_share > 0.0:
		anim_player.seek(_idle_share * anim_player.get_animation(full_name).length)
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


## The hurtbox layout the contact flash and hurt_point() map onto: the hurtboxes', or the
## layout's when this rig builds none.
func _hurt_layout() -> Array[PlaceholderBody.HurtSpec]:
	return _hurt_specs if not _hurt_specs.is_empty() else PlaceholderBody.hurt_specs()


## The ends of `spec`'s axis in rig space in the animation pose (both the center for a
## sphere).
func _hurt_ends(spec: PlaceholderBody.HurtSpec) -> PackedVector3Array:
	var a := _bone_globals[_bone_index[spec.bone_a]] * (spec.offset_a * _scale)
	var b := _bone_globals[_bone_index[spec.bone_b]] * (spec.offset_b * _scale) if spec.is_capsule() else a
	return PackedVector3Array([a, b])


## The hurtbox nearest `p` (rig space): the least distance to its surface (negative inside).
func _nearest_hurt(p: Vector3) -> PlaceholderBody.HurtSpec:
	var best: PlaceholderBody.HurtSpec = null
	var best_gap := INF
	for spec: PlaceholderBody.HurtSpec in _hurt_layout():
		var ends := _hurt_ends(spec)
		var gap := p.distance_to(Geometry3D.get_closest_point_to_segment(p, ends[0], ends[1])) \
				- spec.radius * _scale
		if gap < best_gap:
			best_gap = gap
			best = spec
	return best


## `p` (rig space) moved onto `spec`'s hurtbox: unchanged inside it, else onto its surface.
func _onto_hurt(spec: PlaceholderBody.HurtSpec, p: Vector3) -> Vector3:
	var ends := _hurt_ends(spec)
	var axis := Geometry3D.get_closest_point_to_segment(p, ends[0], ends[1])
	return axis + (p - axis).limit_length(spec.radius * _scale)


## The bone along `spec`'s hurtbox (from bone_a down to bone_b) whose stretch of the axis
## in the animation pose lies nearest `p` (rig space): the bone whose drawn follower carries
## that part of the body (a chest hit rides the upper chest, a shin hit the lower leg).
func _carrier_bone(spec: PlaceholderBody.HurtSpec, p: Vector3) -> StringName:
	if not spec.is_capsule():
		return spec.bone_a
	var chain: Array[StringName] = [spec.bone_b]
	while chain[0] != spec.bone_a and PlaceholderBody.BONE_PARENT.has(chain[0]):
		chain.push_front(PlaceholderBody.BONE_PARENT[chain[0]])
	var ends := _hurt_ends(spec)
	var bone := spec.bone_a
	var best := INF
	for i: int in chain.size():
		var from := ends[0] if i == 0 else _bone_globals[_bone_index[chain[i]]].origin
		var to := ends[1] if i == chain.size() - 1 else _bone_globals[_bone_index[chain[i + 1]]].origin
		var dist := p.distance_squared_to(Geometry3D.get_closest_point_to_segment(p, from, to))
		if dist < best:
			best = dist
			bone = chain[i]
	return bone


func _apply_layers() -> void:
	var default_layer := CombatTypes.bit(CombatTypes.VIS_DEFAULT)
	var head_layer := CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN) if first_person_body else default_layer
	for mesh_instance: MeshInstance3D in _head_meshes:
		mesh_instance.layers = head_layer
	for mesh_instance: MeshInstance3D in _body_meshes:
		mesh_instance.layers = default_layer
	# The art's FP-hidden mesh (a GLB mesh named *__fp_hidden) goes with the head meshes.
	for mesh_instance: MeshInstance3D in _art_meshes:
		mesh_instance.layers = head_layer if mesh_instance.get_meta(SkinnedArt.FP_HIDDEN_META, false) else default_layer
