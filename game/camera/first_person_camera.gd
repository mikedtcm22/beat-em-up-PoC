class_name FirstPersonCamera
extends Camera3D
## The player's view (Spec §5 and §6). It rides the player's EyePoint, takes its rotation
## only from the player's look plus the running move's camera offset (never from the head
## bone), and adds the hit-feel camera punch and trauma screen shake on top.
## Presentation only: it reads the player once per frame in _process and never writes
## simulation state. CameraDirector creates it and assigns `player`.
##
## Smoothing: the camera follows the player's origin rigidly and damps only the eye's
## offset from that origin, with time constant Tuning.data.cam_smoothing_s. Head-bone
## jitter from the animation is steadied, while walking, lunges, dodges and knockback
## never leave the view trailing behind the head.
##
## Even motion at frame rates other than 60 fps needs project physics interpolation
## (physics/common/physics_interpolation = true). The origin is read with
## get_global_transform_interpolated(), which then lies between the last two physics
## ticks, so the view moves evenly at any frame rate and in step with the interpolated
## body. With interpolation off that call returns the latest tick, and the view moves in
## 60 Hz steps (as do the body and every other actor), which judders on faster displays.
## The camera does not smooth those steps on its own: the full body renders in first
## person (Spec §5) and would then jitter against the view instead.
##
## Floor under the lens: the lens rides EyePoint less a fixed drop, which is right for an
## upright body and puts it inside the street for one lying face-down (EyePoint 0.15 m up, the
## lens at -0.04 m, the floor culled from below). So the lens y is never lower than the floor
## under the player plus Tuning "Camera" > cam_floor_clearance_m (_view_with(), before the KO
## view's mix): a max against a floor that moves only with the player's own height, so it adds
## no jump of its own, and a body lying face-up (the lens 0.12 m up) moves a centimeter or so.
##
## KO view (Game-boy, 2026-10-25): the one time the camera leaves the player's eyes. From
## the killing blow (health 0) the lens eases out of the eyes to a point above and beside
## the lying body, which then shows whole (the head, neck, chest and shoulders too, which
## the lens is normally inside of), holds there while the player is KO'd, and eases back
## into the eyes once the player is back up (Tuning "Camera" > "KO view"). The view is
## mixed with the eye's by a weight of its own, so it leaves and returns without a pop. The
## lens takes the pose with the most room around the body (_choose_ko_pose()): across it on
## either side, else along it past its feet, else steeper over its hips, and it never sits
## in a wall, crate or fighter.
##
## Knockdown view (feel question 3, Tuning "Look" > "FP feel" > fp_knockdown_hide_torso, off =
## today): a player knocked down without being killed lies on the camera for a second or two, and
## the lens, riding his eyes, sees the inside of his own belly as one slab (up to 74% of the view in
## M3, over half of it for 45 frames face down). With the switch on, the torso (the belly, belt and
## pelvis primitives, or the skinned art's Body__fp_torso mesh: its whole visible body when it has
## none) goes on the head layer this lens never
## draws from the first frame of the knockdown to the get-up's end, and comes back to the layers it
## had. Only while this camera is the one drawing (a side view or free fly shows the whole body),
## and never in the KO view, which shows it whole.

## Seconds a camera punch takes to snap out and spring back to rest.
@export_range(0.03, 0.5, 0.01) var punch_duration_s: float = 0.12
## Share of punch_duration_s spent snapping out to the peak; the rest eases back.
@export_range(0.05, 0.9, 0.05) var punch_attack_share: float = 0.25
## Trauma removed per real-time second.
@export_range(0.1, 10.0, 0.1) var trauma_decay_per_s: float = 1.5
## Shake rotation (pitch, yaw and roll, each) at trauma 1 and intensity 1, in degrees.
@export_range(0.0, 10.0, 0.1) var shake_max_deg: float = 3.0
## Shake offset (each axis) at trauma 1 and intensity 1, in meters.
@export_range(0.0, 0.2, 0.005) var shake_max_offset_m: float = 0.04
## How fast the shake noise is sampled; higher rattles faster.
@export_range(1.0, 60.0, 1.0) var shake_frequency_hz: float = 15.0
## Shake and punch of a hit the guard stopped (hit.blocked), relative to a clean hit.
@export_range(0.0, 1.0, 0.05) var blocked_feel_scale: float = 0.5

## The poses the KO view's lens can take around the lying body, as the direction it sits in
## (ko_view_direction()): across the body's length on its right or its left, or along it past
## its feet. NONE until chosen.
enum KoPose { NONE = -1, RIGHT, LEFT, FEET }
## The bones whose primitives are the torso the knockdown view hides (_find_torso_meshes()).
const TORSO_BONES: Array[StringName] = [&"Hips", &"Spine"]
## The name ending of the skinned art's torso mesh (the GLB's Body__fp_torso, attached as ArtBody__fp_torso).
const FP_TORSO_SUFFIX := "__fp_torso"
## How many times _ko_room() halves the reach to find the lens's place clear of everything.
const KO_ROOM_STEPS := 6
## How far below EyePoint lens_floor_y() looks for the floor of a player off the ground: the lens
## is only ever within a few centimeters of it when it matters, so this is just a ray long enough.
const FLOOR_RAY_M := 4.0
## Total pitch is clamped to this, so a downward move offset on top of looking straight
## down never flips the view over.
const PITCH_LIMIT_RAD := PI * 89.0 / 180.0
## A punch whose contact point is this close to screen center (radians) dips the view
## instead, since "toward the contact" has no direction there.
const PUNCH_CENTER_RAD := PI / 180.0

## The player this camera rides. Null (or freed) holds the last view.
var player: PlayerCharacter:
	set = set_player
## Screen-shake trauma, 0 to 1. Shake strength is trauma squared.
var trauma: float = 0.0

## Eye position relative to the player's origin, smoothed.
var _eye_offset: Vector3 = Vector3.ZERO
## The hold view's rise and pull-back (PlayerCharacter.get_hold_view_shift()), smoothed with
## the eye: they follow the same bend, so smoothed apart the lens bobbed past its ends.
var _hold_shift: Vector2 = Vector2.ZERO
var _has_eye: bool = false
## The KO view's progress, 0 (in the eyes) to 1 (out of the body), linear in the player's
## sim seconds (_ko_view_mix()); ko_view_weight() eases it.
var _ko_view: float = 0.0
## Where the KO view's lens sits around the body (a KoPose, NONE = in the eyes), chosen where
## the body has the most room when the view starts to leave; whether it sits steeper over the
## hips instead (_choose_ko_pose()); which way the head lies, +1 toward the body's back and
## -1 toward its front, as read then (the way the blow throws it); and how much of Tuning's
## distance and height the room allows (smoothed).
var _ko_pose: int = KoPose.NONE
var _ko_steep: bool = false
var _ko_head_sign: float = 1.0
var _ko_reach: float = 1.0
## The lens got all the way out this time (a revive before that has the look turn back with the
## lens, so it does not jump from where it is).
var _ko_was_out: bool = false
## The ball _ko_room() tests the lens's place with.
var _ko_ball: SphereShape3D = SphereShape3D.new()
## The player's meshes on the head layer, found when the KO view first needs them.
var _head_meshes: Array[MeshInstance3D] = []
## The player's torso meshes (found when a knockdown first needs them) and the layers each had
## while it is hidden from this lens (_update_torso(); empty when none is).
var _torso_meshes: Array[MeshInstance3D] = []
var _torso_layers: Dictionary[MeshInstance3D, int] = {}
## The view before punch and shake: where the player is looking.
var _view: Transform3D = Transform3D.IDENTITY
## Live punches: x = pitch kick and y = yaw kick at the peak (radians), z = age (seconds).
var _punches: Array[Vector3] = []
var _shake_time: float = 0.0
var _noise: FastNoiseLite = FastNoiseLite.new()


func _init() -> void:
	top_level = true
	keep_aspect = Camera3D.KEEP_WIDTH
	near = 0.05
	# Also set in _init, so a camera that takes over this view before it enters the tree
	# (free fly picked early) copies the right field of view.
	fov = Tuning.data.fov_deg
	set_cull_mask_value(CombatTypes.VIS_FP_HIDDEN, false)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	_noise.frequency = 1.0


func _enter_tree() -> void:
	if not CombatEvents.hit_landed.is_connected(_on_hit_landed):
		CombatEvents.hit_landed.connect(_on_hit_landed)


func _exit_tree() -> void:
	_restore_torso()
	if CombatEvents.hit_landed.is_connected(_on_hit_landed):
		CombatEvents.hit_landed.disconnect(_on_hit_landed)


func _ready() -> void:
	fov = Tuning.data.fov_deg


func _process(delta: float) -> void:
	update_camera(delta)


## Ride `value` from now on, jumping straight to its eye on the next update.
func set_player(value: PlayerCharacter) -> void:
	_restore_torso()
	player = value
	_ko_view = 0.0
	_ko_pose = KoPose.NONE
	_ko_was_out = false
	_head_meshes.clear()
	_torso_meshes.clear()
	set_cull_mask_value(CombatTypes.VIS_FP_HIDDEN, false)
	snap()


## Jump straight to the eye point on the next update instead of easing toward it.
func snap() -> void:
	_has_eye = false


## Advance one presentation frame of `delta` real seconds: follow the player, age the punch
## and shake, and place the camera. _process calls this; tests may call it directly.
func update_camera(delta: float) -> void:
	fov = Tuning.data.fov_deg
	if _player_ok():
		_view = _ko_view_mix(delta, _follow(delta))
		_update_torso()
	_advance_effects(delta)
	global_transform = _view * _effects_transform()


## The view without punch and shake: the player's eye and look direction (the KO view's
## while it is out, or on its way).
func view_transform() -> Transform3D:
	return _view


## How far the lens is out of the player's eyes in the KO view: 0 in the eyes (the head,
## neck, chest and shoulders hidden from this camera as always), 1 out of the body. Eased,
## so it moves smoothly both ways.
func ko_view_weight() -> float:
	return smoothstep(0.0, 1.0, _ko_view)


## Add screen-shake trauma (clamped to 0..1). Hits involving the player add
## Tuning.data.shake(tier) on their own.
func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Start a camera punch that peaks at `kick_deg` (x = pitch, positive looks up; y = yaw,
## positive turns left) and springs back over punch_duration_s. A punch that arrives while
## another is still snapping out (one strike hitting several victims) joins it: one punch
## toward their combined direction, as strong as the stronger of the two. Later punches
## overlap, but the total never exceeds the strongest live punch.
func add_punch(kick_deg: Vector2) -> void:
	if kick_deg.is_zero_approx():
		return
	var kick := Vector2(deg_to_rad(kick_deg.x), deg_to_rad(kick_deg.y))
	var attack_s := punch_duration_s * punch_attack_share
	for i: int in _punches.size():
		var live := _punches[i]
		if live.z >= attack_s:
			continue
		var peak := Vector2(live.x, live.y)
		var strength := maxf(peak.length(), kick.length())
		var combined := peak + kick
		if combined.is_zero_approx():
			# Opposite kicks cancel: keep the stronger one's direction.
			combined = peak if peak.length() >= kick.length() else kick
		combined = combined.normalized() * strength
		_punches[i] = Vector3(combined.x, combined.y, live.z)
		return
	_punches.append(Vector3(kick.x, kick.y, 0.0))


## Current punch rotation in degrees (x = pitch, y = yaw).
func get_punch_deg() -> Vector2:
	var punch := _punch_rad()
	return Vector2(rad_to_deg(punch.x), rad_to_deg(punch.y))


## True when no punch is running and trauma is zero.
func is_settled() -> bool:
	return trauma <= 0.0 and _punches.is_empty()


func _player_ok() -> bool:
	return is_instance_valid(player) and player.is_inside_tree()


func _follow(delta: float) -> Transform3D:
	var origin := player.global_position
	var eye := player.get_eye_transform().origin - origin
	if player.is_walking():
		# Steady view while walking: the eye may bob only this far from its idle height.
		# Walking with a held enemy shows the hold pose (no walk cycle), whose bent-over eye
		# sits well under the standing height: the clamp lets go of it as the hold view comes
		# in and takes it back as the view eases out, so a release while walking never pops.
		var bob := Tuning.data.cam_bob_clamp_m
		var idle := player.standing_eye_height
		eye.y = lerpf(clampf(eye.y, idle - bob, idle + bob), eye.y, player.get_hold_view_weight())
	var shift := player.get_hold_view_shift()
	if _has_eye:
		var weight := CameraMath.damp_weight(delta, Tuning.data.cam_smoothing_s)
		_eye_offset = _eye_offset.lerp(eye, weight)
		_hold_shift = _hold_shift.lerp(shift, weight)
	else:
		_eye_offset = eye
		_hold_shift = shift
		_has_eye = true
	var root := player.get_global_transform_interpolated().origin
	return _view_with(player, root + _eye_offset, _hold_shift, Engine.get_physics_interpolation_fraction())


## The first-person view (before punch and shake) of `player` with its eye at world `eye`:
## the running move's and the hold view's drop and extra pitch
## (PlayerCharacter.get_camera_move_offset()), the view turn (interpolated by `fraction`
## between physics ticks), and the lens offset less the hold view's pull-back, the lens then
## kept cam_floor_clearance_m above the floor (lens_floor_y()). _follow() passes the smoothed
## eye (with the hold view's rise and pull-back smoothed alike); tests pass EyePoint itself to
## judge the real view.
static func view_from_eye(player: PlayerCharacter, eye: Vector3, fraction: float = 1.0) -> Transform3D:
	return _view_with(player, eye, player.get_hold_view_shift(), fraction)


## view_from_eye() with the hold view's rise (x) and pull-back (y) given as `hold_shift`.
static func _view_with(player: PlayerCharacter, eye: Vector3, hold_shift: Vector2, fraction: float) -> Transform3D:
	# x = extra pitch in degrees, y = drop in meters along world -Y (negative rises). Already
	# eased. The hold view's own rise in it is swapped for hold_shift's.
	var move_offset := player.get_camera_move_offset()
	var drop := move_offset.y + player.get_hold_view_shift().x - hold_shift.x
	var eye_position := eye + Vector3.DOWN * drop
	# A spinning move's body turn and the back elbow's turn over the shoulder, interpolated
	# between physics ticks so a spin turns smoothly at any frame rate.
	var view_yaw := deg_to_rad(player.get_camera_view_yaw(fraction))
	var look_basis := Basis(Vector3.UP, view_yaw) * player.get_look_basis()
	# While an enemy is held the lens also moves back (the hold view).
	eye_position += lens_offset(look_basis, hold_shift.y)
	# Never into the floor: a body lying face-down has its eye a hand above the street.
	eye_position.y = maxf(eye_position.y, lens_floor_y(player, eye) + Tuning.data.cam_floor_clearance_m)
	var look := _add_pitch(look_basis, deg_to_rad(move_offset.x))
	return Transform3D(look, eye_position)


## The y of the floor under `player` that the lens keeps clear of, or -INF when there is none to
## find (the player is out of the tree, or in the air with nothing below its eye). On the floor
## it is the player's own height (interpolated, as the view's origin is): a plain read, and the
## floor the capsule is standing on whatever the pose does to the eye. In the air (a launch, a
## throw) it is the world's first surface straight down from `eye` (EyePoint: never from the
## lens, which may already be inside the floor and would then see nothing).
static func lens_floor_y(player: PlayerCharacter, eye: Vector3) -> float:
	if not player.is_inside_tree():
		return -INF
	if player.is_on_floor():
		return player.get_global_transform_interpolated().origin.y
	var world := player.get_world_3d()
	if world == null:
		return -INF
	var query := PhysicsRayQueryParameters3D.create(eye, eye + Vector3.DOWN * FLOOR_RAY_M, CombatTypes.bit(CombatTypes.LAYER_WORLD))
	var hit := world.direct_space_state.intersect_ray(query)
	return (hit.position as Vector3).y if not hit.is_empty() else -INF


## Where the first-person lens sits relative to EyePoint, for a look basis: lowered by
## Tuning.cam_height_offset_m and moved ahead along the flat look by
## Tuning.cam_forward_offset_m, less `back` meters (the hold view's pull-back,
## PlayerCharacter.get_camera_pull_back()). Rig tests use it to judge poses from the real
## viewpoint.
static func lens_offset(look_basis: Basis, back: float = 0.0) -> Vector3:
	var offset := Vector3.UP * Tuning.data.cam_height_offset_m
	var ahead := look_basis * Vector3.FORWARD
	ahead.y = 0.0
	if ahead.length_squared() > 0.0001:
		offset += ahead.normalized() * (Tuning.data.cam_forward_offset_m - back)
	return offset


## The KO view mixed into `live`, the view from the eyes: the player's progress toward the
## KO view moves with its sim time (hitstop holds it, slow-mo stretches it, like the
## get-up's own animation), out over Tuning.ko_view_out_s from the killing blow (health
## 0; the player goes on to KO) and back over ko_view_in_s once it is back up. The lens
## and look blend from the eyes' to the KO pose by the eased weight, so they leave and
## return with the eye's own motion under them and no pop. The body shows whole from the
## first frame the lens is clear of the head layer (_head_clear_of(): the head, neck, chest
## and shoulders pass right by a lens still in the eyes, a cap's brim among them) until the
## lens comes within reach of it again on the way back (it hides the layer then, before the
## head is near enough to fill the view; the rig's own layers never change). On the way back
## `live` looks where the body faces: the player's look is not turned while down
## (PlayerCharacter._process(), _revive()).
func _ko_view_mix(delta: float, live: Transform3D) -> Transform3D:
	var tuning := Tuning.data
	var dying := player.health <= 0.0
	if not dying and _ko_view <= 0.0:
		# The usual case, every frame: in the eyes, the head layer hidden.
		_ko_pose = KoPose.NONE
		_ko_was_out = false
		if get_cull_mask_value(CombatTypes.VIS_FP_HIDDEN):
			set_cull_mask_value(CombatTypes.VIS_FP_HIDDEN, false)
		return live
	var seconds := tuning.ko_view_out_s if dying else tuning.ko_view_in_s
	var sim_delta := delta * TimeController.scale_for(player)
	var step := 0.0
	if sim_delta > 0.0:
		step = 1.0 if seconds <= 0.0 else sim_delta / seconds
	if dying:
		if _ko_pose == KoPose.NONE:
			_choose_ko_pose()
		_ko_view = minf(_ko_view + step, 1.0)
		_ko_was_out = _ko_was_out or _ko_view >= 1.0
	else:
		_ko_view = maxf(_ko_view - step, 0.0)
	var weight := ko_view_weight()
	if weight <= 0.0:
		# Back in the eyes (or the blow's hitstop, before the view has started): hide the head
		# layer again.
		if get_cull_mask_value(CombatTypes.VIS_FP_HIDDEN):
			set_cull_mask_value(CombatTypes.VIS_FP_HIDDEN, false)
		return live
	var root := player.get_global_transform_interpolated().origin
	var body := player.rig.global_basis
	var direction := ko_view_direction(body, _ko_pose, _ko_head_sign)
	var room := _ko_room(player.rig.get_point_position(&"Hips"), root, direction, _ko_steep)
	# Nearer at once when something comes into the lens's way (never a lens inside it), farther
	# again at the eye's own pace.
	_ko_reach = minf(lerpf(_ko_reach, room, CameraMath.damp_weight(delta, tuning.cam_smoothing_s)), room)
	var out := ko_view_pose(root, direction, _ko_reach, _ko_steep)
	# The look comes back to the eyes' ahead of the lens (ko_view_look_lead), so the body the
	# lens flies in over has left the view before the head layer hides (and nothing pops).
	var look_weight := pow(weight, tuning.ko_view_look_lead) if _ko_was_out and not dying else weight
	var turn := live.basis.get_rotation_quaternion().slerp(out.basis.get_rotation_quaternion(), look_weight)
	var mixed := Transform3D(Basis(turn), live.origin.lerp(out.origin, weight))
	var shown := get_cull_mask_value(CombatTypes.VIS_FP_HIDDEN)
	var clear := _head_clear_of(mixed.origin)
	if dying:
		# Out: the layer shows from the first frame the lens is clear of it.
		if clear and not shown:
			set_cull_mask_value(CombatTypes.VIS_FP_HIDDEN, true)
	elif shown and not clear:
		# Back in: it hides again from the first frame the lens is near it (the mirror of the
		# lift), not at the eyes: the head, neck and chest the lens dives into were all drawn.
		set_cull_mask_value(CombatTypes.VIS_FP_HIDDEN, false)
	return mixed


## The non-KO knockdown view is on: the player is flying, lying or getting up, alive, with the lens
## in his eyes (the KO view, which shows the body whole, is not on its way out or in).
func _knockdown_view() -> bool:
	if player.health <= 0.0 or _ko_view > 0.0:
		return false
	var state := player.state
	return state == CombatTypes.ActorState.LAUNCHED or state == CombatTypes.ActorState.DOWNED \
			or state == CombatTypes.ActorState.GETUP


## Hide the torso from this lens for the knockdown view (fp_knockdown_hide_torso), or put its
## layers back. The meshes move to the head layer, which the first-person lens never draws (they
## still cast shadows, and every other camera, being on the default mask, still draws them); it is
## done while this camera is current, so the side view and free fly keep the whole body. Checked
## every update while hidden, so a rig that resets its layers meanwhile is hidden again.
func _update_torso() -> void:
	if not (current and Tuning.data.fp_knockdown_hide_torso and _knockdown_view()):
		_restore_torso()
		return
	if _torso_meshes.is_empty():
		_torso_meshes = _find_torso_meshes()
	var hidden := CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN)
	for mesh: MeshInstance3D in _torso_meshes:
		if not is_instance_valid(mesh):
			continue
		if not _torso_layers.has(mesh):
			_torso_layers[mesh] = mesh.layers
		mesh.layers = hidden


## Give every torso mesh the layers it had before _update_torso() hid it.
func _restore_torso() -> void:
	for mesh: MeshInstance3D in _torso_layers:
		if is_instance_valid(mesh):
			mesh.layers = _torso_layers[mesh]
	_torso_layers.clear()


## The player's torso meshes: the primitives on the Hips and Spine bones (the pelvis, belt, belly and
## belly top; the chest and above are on the head layer already), and on skinned art the mesh named
## `*__fp_torso` (the belly and belt: Spine and Hips; the legs and forearms are the art's other
## visible meshes and stay). Art without one (the probe body, an older GLB) has no part of its own
## for them, so its whole visible body goes (the hidden upper body is on the head layer). A mesh on
## the head layer is left out.
func _find_torso_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var art_visible: Array[MeshInstance3D] = []
	var art_torso: Array[MeshInstance3D] = []
	var default_layer := CombatTypes.bit(CombatTypes.VIS_DEFAULT)
	for node: Node in player.rig.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.layers != default_layer:
			continue
		if mesh.is_in_group(HumanoidRig.ART_GROUP):
			if not mesh.get_meta(SkinnedArt.FP_HIDDEN_META, false):
				art_visible.append(mesh)
				if String(mesh.name).ends_with(FP_TORSO_SUFFIX):
					art_torso.append(mesh)
			continue
		var parent := mesh.get_parent()
		if parent != null and TORSO_BONES.any(func(bone: StringName) -> bool: return parent.name == StringName("Bone%s" % bone)):
			out.append(mesh)
	out.append_array(art_torso if not art_torso.is_empty() else art_visible)
	return out


## True when no mesh of the player's head layer (the ones this camera hides, found once per
## player; the skinned art's are left out, the primitives that stand in for them are read) lies within Tuning.ko_view_clearance_m of `lens`, by its bounding box.
func _head_clear_of(lens: Vector3) -> bool:
	if _head_meshes.is_empty():
		var hidden := CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN)
		for node: Node in player.rig.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			# The skinned art's head mesh is skipped: its bounding box is the bind pose's, not
			# the body's. The hidden primitives (the view proxies) follow the pose and are read.
			if mesh.layers & hidden and not mesh.is_in_group(HumanoidRig.ART_GROUP):
				_head_meshes.append(mesh)
	for mesh: MeshInstance3D in _head_meshes:
		if (mesh.global_transform * mesh.get_aabb()).grow(Tuning.data.ko_view_clearance_m).has_point(lens):
			return false
	return true


## The flat unit direction from a body lying at `root` to the KO view's lens for `pose` (a
## KoPose), given the rig's facing `body`: across its length (the rig's right axis, negated
## for the left), or along it (the rig's back axis) past its feet when the head lies toward
## the back (`head_sign` +1) or the front (-1).
static func ko_view_direction(body: Basis, pose: int, head_sign: float = 1.0) -> Vector3:
	var across := _flat_axis(body.x, Vector3.RIGHT)
	match pose:
		KoPose.LEFT:
			return -across
		KoPose.FEET:
			return -_flat_axis(body.z, Vector3.BACK) * signf(head_sign)
	return across


## `axis` flat and unit, or `fallback` when it points straight up or down.
static func _flat_axis(axis: Vector3, fallback: Vector3) -> Vector3:
	axis.y = 0.0
	return axis.normalized() if axis.length_squared() > 0.0001 else fallback


## The KO view's pose at full weight: the lens by a body lying at `root` (the rig's origin,
## which the lying pose puts the hips over), in the flat unit `direction` from it
## (ko_view_direction()), Tuning's ko_view_distance_m out along the floor and
## ko_view_height_m up, scaled by `reach` (1 = all of it; something nearer brings the lens in
## along the line to the body, which keeps the body where it sits on screen), looking toward
## the body and down by ko_view_pitch_deg. `steep`: the lens straight over the hips instead,
## ko_view_steep_height_m up and looking along `direction` down by ko_view_steep_pitch_deg,
## the pose with room in a corner, among fighters or between a wall and a fighter.
static func ko_view_pose(root: Vector3, direction: Vector3, reach: float = 1.0, steep: bool = false) -> Transform3D:
	var tuning := Tuning.data
	var out := Vector3.UP * (tuning.ko_view_steep_height_m if steep else tuning.ko_view_height_m)
	if not steep:
		out += direction * tuning.ko_view_distance_m
	var pitch := tuning.ko_view_steep_pitch_deg if steep else tuning.ko_view_pitch_deg
	var look := Basis.from_euler(Vector3(-deg_to_rad(pitch), atan2(direction.x, direction.z), 0.0))
	return Transform3D(look, root + out * reach)


## Pick the KO view's pose (_ko_pose and _ko_steep) where the body has the most room, and
## start its reach there. Each pose scores its room (_ko_room()) times how far the nearest
## other actor on its feet stands from the lens there, up to the lens's own distance from the
## body (_ko_crowding()), so the lens does not end up beside a second fighter filling the
## view. A pose needs Tuning.ko_view_min_reach of the room to show the whole body:
## 1. across the body, its right unless the left clearly scores better (the usual case);
## 2. else along it, past its feet (the way the blow throws the head says which end they are:
##    past the head, the return dives over the chest, 30 to 50% of the view);
## 3. else steeper over its hips, looking across it from the better side: nothing blocks it.
func _choose_ko_pose() -> void:
	var root := player.get_global_transform_interpolated().origin
	var body := player.rig.global_basis
	var hips := player.rig.get_point_position(&"Hips")
	# The body still stands or flies at the killing blow: its head ends up the way the blow
	# throws it (a body struck from the front lies on its back, head to the back, and one
	# struck from behind face down, head to the front).
	var thrown := player.sim_velocity.dot(body.z)
	_ko_head_sign = -1.0 if thrown < 0.0 else 1.0
	var rooms: Array[float] = []
	var scores: Array[float] = []
	for pose: int in [KoPose.RIGHT, KoPose.LEFT, KoPose.FEET]:
		var direction := ko_view_direction(body, pose, _ko_head_sign)
		rooms.append(_ko_room(hips, root, direction, false))
		scores.append(rooms[pose] * _ko_crowding(ko_view_pose(root, direction).origin, root))
	var across := KoPose.LEFT if scores[KoPose.LEFT] > scores[KoPose.RIGHT] + 0.01 else KoPose.RIGHT
	_ko_steep = false
	if rooms[across] >= Tuning.data.ko_view_min_reach:
		_ko_pose = across
	elif rooms[KoPose.FEET] >= Tuning.data.ko_view_min_reach:
		_ko_pose = KoPose.FEET
	else:
		_ko_pose = across
		_ko_steep = true
	var direction := ko_view_direction(body, _ko_pose, _ko_head_sign)
	_ko_reach = _ko_room(hips, root, direction, _ko_steep)


## 0..1: how far from `lens` the nearest other actor on its feet stands (flat), as a share
## of the lens's distance from the body at `root`; 1 when none is nearer than the body.
func _ko_crowding(lens: Vector3, root: Vector3) -> float:
	var length := maxf(lens.distance_to(root), 0.0001)
	var nearest := length
	for node: Node in get_tree().get_nodes_in_group(&"actor"):
		var actor := node as CombatActor
		if actor == null or actor == player or actor.is_ko() or actor.is_downed() or actor.is_gone():
			continue
		var flat := actor.global_position - lens
		flat.y = 0.0
		nearest = minf(nearest, flat.length())
	return nearest / length


## How much of the KO view's distance and height the world allows in `direction` from a body
## at `root` (`steep`: the pose over the hips): 1 when the line from the body's middle
## (`middle`, its hips) to the lens is free, less when a wall, crate, the curb or a standing
## actor (world and enemy body layers) is in the way, and 0 when there is no room: never a
## lens past the first thing the line meets, less Tuning.ko_view_clearance_m. The lens itself
## is then tested with a ball of that radius (the line is thin, and meets a wall slantwise),
## and brought in along the line until the ball is clear. Not floored: the choice
## (_choose_ko_pose()) tries other poses when this falls short of ko_view_min_reach.
func _ko_room(middle: Vector3, root: Vector3, direction: Vector3, steep: bool) -> float:
	if not is_inside_tree():
		return 1.0
	var to := ko_view_pose(root, direction, 1.0, steep).origin
	var length := middle.distance_to(to)
	if length < 0.0001:
		return 1.0
	var mask := CombatTypes.bit(CombatTypes.LAYER_WORLD) | CombatTypes.bit(CombatTypes.LAYER_ENEMY_BODY)
	var space := get_world_3d().direct_space_state
	var reach := 1.0
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(middle, to, mask))
	if not hit.is_empty():
		reach = maxf(middle.distance_to(hit.position as Vector3) - Tuning.data.ko_view_clearance_m, 0.0) / length
	if not _ko_blocked(ko_view_pose(root, direction, reach, steep).origin, space, mask):
		return reach
	var clear := 0.0
	var blocked := reach
	for i: int in KO_ROOM_STEPS:
		var between := (clear + blocked) * 0.5
		if _ko_blocked(ko_view_pose(root, direction, between, steep).origin, space, mask):
			blocked = between
		else:
			clear = between
	return clear


## True when a ball of Tuning.ko_view_clearance_m around `lens` touches anything on `mask`.
func _ko_blocked(lens: Vector3, space: PhysicsDirectSpaceState3D, mask: int) -> bool:
	_ko_ball.radius = Tuning.data.ko_view_clearance_m
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _ko_ball
	query.transform = Transform3D(Basis.IDENTITY, lens)
	query.collision_mask = mask
	return not space.intersect_shape(query, 1).is_empty()


func _advance_effects(delta: float) -> void:
	_shake_time += delta
	trauma = maxf(0.0, trauma - trauma_decay_per_s * delta)
	for i: int in range(_punches.size() - 1, -1, -1):
		var punch := _punches[i]
		punch.z += delta
		if punch.z >= punch_duration_s:
			_punches.remove_at(i)
		else:
			_punches[i] = punch


## Punch and shake as a transform in the view's local space.
func _effects_transform() -> Transform3D:
	var punch := _punch_rad()
	var rotation_rad := Vector3(punch.x, punch.y, 0.0)
	var offset := Vector3.ZERO
	var amount := trauma * trauma * Tuning.data.screen_shake_intensity
	if amount > 0.0:
		var max_rad := deg_to_rad(shake_max_deg) * amount
		var max_m := shake_max_offset_m * amount
		rotation_rad += Vector3(_shake_noise(0), _shake_noise(1), _shake_noise(2)) * max_rad
		offset = Vector3(_shake_noise(3), _shake_noise(4), _shake_noise(5)) * max_m
	if rotation_rad == Vector3.ZERO and offset == Vector3.ZERO:
		return Transform3D.IDENTITY
	return Transform3D(Basis.from_euler(rotation_rad), offset)


## Sum of the live punches in radians (x = pitch, y = yaw), no longer than the strongest
## live punch's peak, so overlapping hits never punch harder than their tier.
func _punch_rad() -> Vector2:
	var total := Vector2.ZERO
	var strongest := 0.0
	for punch: Vector3 in _punches:
		var peak := Vector2(punch.x, punch.y)
		total += peak * _punch_envelope(punch.z / punch_duration_s)
		strongest = maxf(strongest, peak.length())
	return total.limit_length(strongest)


## Smooth noise in -1..1, one independent channel per shake axis.
func _shake_noise(channel: int) -> float:
	var sample := _noise.get_noise_2d(_shake_time * shake_frequency_hz, float(channel) * 37.0)
	return clampf(sample, -1.0, 1.0)


## Quick snap out (ease-out sine) then a smooth ease back to rest; u is age / duration.
func _punch_envelope(u: float) -> float:
	if u <= 0.0 or u >= 1.0:
		return 0.0
	if u < punch_attack_share:
		return sin(u / punch_attack_share * PI * 0.5)
	return 0.5 + 0.5 * cos((u - punch_attack_share) / (1.0 - punch_attack_share) * PI)


func _on_hit_landed(hit: HitInfo) -> void:
	if hit == null or not _player_ok():
		return
	var is_attacker := hit.attacker == player
	if not is_attacker and hit.victim != player:
		return
	var feel := blocked_feel_scale if hit.blocked else 1.0
	add_trauma(Tuning.data.shake(hit.tier) * feel)
	var direction := _toward(hit.contact_point) if is_attacker else _away(hit)
	add_punch(direction * Tuning.data.cam_punch_deg(hit.tier) * feel)


## Unit kick (x = pitch up, y = yaw left) that turns the view toward `point`. A contact at
## screen center dips the view, as if leaning into the blow.
func _toward(point: Vector3) -> Vector2:
	var local := _view.basis.inverse() * (point - _view.origin)
	var horizontal := Vector2(local.x, local.z).length()
	var angles := Vector2(atan2(local.y, horizontal), atan2(-local.x, -local.z))
	if angles.length() < PUNCH_CENTER_RAD:
		return Vector2(-1.0, 0.0)
	return angles.normalized()


## Unit kick (x = pitch up, y = yaw left) that jolts the view the way the hit pushes the
## player: pushed back tips the head up, pushed sideways turns it with the push.
func _away(hit: HitInfo) -> Vector2:
	var push := hit.direction
	if push.is_zero_approx():
		push = _view.origin - hit.contact_point
	var local := _view.basis.inverse() * push
	var kick := Vector2(local.z, -local.x)
	if kick.is_zero_approx():
		return Vector2(1.0, 0.0)
	return kick.normalized()


## `look` with `extra_pitch` radians more pitch, the total clamped short of straight up/down.
static func _add_pitch(look: Basis, extra_pitch: float) -> Basis:
	var euler := look.get_euler()
	euler.x = clampf(euler.x + extra_pitch, -PITCH_LIMIT_RAD, PITCH_LIMIT_RAD)
	return Basis.from_euler(euler)
