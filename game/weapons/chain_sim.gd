class_name ChainSim
extends Node3D
## The bike chain's look in motion (Milestone 6, D5; docs/ARCHITECTURE.md "The catalog, the second weapon and the glint"): a
## presentation-only Verlet sim that replaces StaticArt's straight repeats of the `Link` with a chain that trails and whips.
##
## Points: `weapon_chain_points` of them, the first pinned at the end of the `Grip` mesh, each pulled back toward the straight line
## along the weapon's axis at `weapon_chain_follow_rate` (so the padlock stays under the strike's hitbox at rest and lags a few
## frames behind it in a swing: it lands last), with gravity, damping and fixed segment lengths. They step in world space, by the
## game-time delta (TimeController: hitstop freezes it with the holder, slow-mo slows it), from the weapon's own transform: held,
## that is the holder's WeaponGrip, thrown, the spinning body. It draws the links as one MultiMesh (the art's own `Link`, turned
## 90 degrees on each) along the points, and carries the `Lock` mesh to the last point.
## It reads transforms and never writes a hit, a body or any game state: the hit is the rig's WeaponTip, as for the pipe.

const GRIP_MESH := &"Grip"
const LOCK_MESH := &"Lock"
const LINK_MESH := &"Link"
## The tunable that sets the link pitch: its @export_range's minimum sizes the MultiMesh (min_pitch_m()), so lowering the range
## in tuning_data.gd can never truncate the links.
const PITCH_PROPERTY := &"weapon_chain_link_pitch_m"

var _weapon: Weapon
var _art: StaticArt
var _link: MeshInstance3D
var _lock: MeshInstance3D
var _lock_rest: Transform3D = Transform3D.IDENTITY
## The nominal chain in the weapon's frame: from the end of the grip to the shackle of the padlock, along +Y.
var _start_local: Vector3 = Vector3.ZERO
var _end_local: Vector3 = Vector3.ZERO
var _lock_attach: Vector3 = Vector3.ZERO
var _rest_length: float = 0.0
var _points: PackedVector3Array = PackedVector3Array()
var _previous: PackedVector3Array = PackedVector3Array()
var _multi: MultiMeshInstance3D
var _links_drawn: int = 0
var _primed: bool = false


## Bind to `weapon` and its art (Weapon calls this once, after adding the art). Does nothing if the art lacks the three meshes.
func setup(weapon: Weapon, art: StaticArt) -> void:
	_weapon = weapon
	_art = art
	var grip := _instance(GRIP_MESH)
	_lock = _instance(LOCK_MESH)
	_link = _instance(LINK_MESH)
	if grip == null or _lock == null or _link == null or art.material == null:
		return
	var grip_box := grip.transform * grip.mesh.get_aabb()
	_lock_rest = _lock.transform
	var lock_box := _lock_rest * _lock.mesh.get_aabb()
	_start_local = Vector3(0.0, grip_box.end.y, 0.0)
	_end_local = Vector3(0.0, lock_box.position.y, 0.0)
	_lock_attach = Vector3(lock_box.get_center().x, lock_box.position.y, lock_box.get_center().z)
	_rest_length = _end_local.y - _start_local.y
	_multi = MultiMeshInstance3D.new()
	_multi.name = "Links"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _link.mesh
	multimesh.instance_count = int(ceil(_rest_length / min_pitch_m())) + 1
	multimesh.visible_instance_count = 0
	_multi.multimesh = multimesh
	_multi.material_override = art.material
	_multi.material_overlay = _link.material_overlay
	_multi.cast_shadow = _link.cast_shadow
	add_child(_multi)
	_apply_visibility()
	if Tuning.data.weapon_chain_sim:
		_reset()
		_draw()


## Whether the sim has what it needs (the three meshes, found).
func is_ready_to_draw() -> bool:
	return _multi != null


func _process(delta: float) -> void:
	if _multi == null or _weapon == null or not _weapon.is_inside_tree():
		return
	_apply_visibility()
	if not Tuning.data.weapon_chain_sim or not _weapon.is_visible_in_tree():
		return
	step(delta * _time_scale())


## The scale of game time for this weapon: its holder's (zero in his hitstop), the world's when nobody holds it.
func _time_scale() -> float:
	if is_instance_valid(_weapon.holder):
		return TimeController.scale_for(_weapon.holder)
	return TimeController.sim_scale()


## The repeats StaticArt drew stay while the sim is off (the A/B), and give way to the MultiMesh while it is on.
func _apply_visibility() -> void:
	var simulated: bool = Tuning.data.weapon_chain_sim
	_multi.visible = simulated
	if not simulated and _primed:
		_primed = false
		_lock.transform = _lock_rest
	for node: MeshInstance3D in _art.instances():
		var named := String(node.name)
		if named == String(LINK_MESH) or named.begins_with("%sRep" % LINK_MESH):
			node.visible = not simulated


## The smallest link pitch the tunable allows (m): the minimum of weapon_chain_link_pitch_m's @export_range, read from the
## property list so the one number lives in tuning_data.gd. The live value stands in when the range cannot be read.
static func min_pitch_m() -> float:
	for prop: Dictionary in TuningData.new().get_property_list():
		if prop.name == PITCH_PROPERTY:
			var parts := String(prop.hint_string).split(",")
			if parts.size() >= 2 and String(parts[0]).is_valid_float():
				return maxf(float(parts[0]), 0.001)
	return maxf(Tuning.data.weapon_chain_link_pitch_m, 0.001)


## Advance the chain by `dt` seconds of game time and redraw it. Public so a test can step it by hand.
func step(dt: float) -> void:
	if _multi == null or dt <= 0.0:
		if _multi != null and not _primed:
			_reset()
			_draw()
		return
	dt = minf(dt, Tuning.data.weapon_chain_max_dt_s)
	var count := _count()
	var world := _weapon.global_transform
	var grip := world * _start_local
	if not _primed or _points.size() != count or _points[0].distance_to(grip) > Tuning.data.weapon_chain_snap_m:
		_reset()
	var axis := world.basis.y.normalized()
	var segment := _rest_length / float(count - 1)
	var pull := 1.0 - exp(-Tuning.data.weapon_chain_follow_rate * dt)
	var keep := 1.0 - Tuning.data.weapon_chain_damping
	var fall := Vector3.DOWN * Tuning.data.weapon_chain_gravity * dt * dt
	_points[0] = grip
	_previous[0] = grip
	for i: int in range(1, count):
		var here := _points[i]
		var next := here + (here - _previous[i]) * keep + fall
		_previous[i] = here
		_points[i] = next.lerp(grip + axis * segment * float(i), pull)
	for pass_i: int in Tuning.data.weapon_chain_iterations:
		for i: int in range(1, count):
			var gap := _points[i] - _points[i - 1]
			var length := gap.length()
			if length < 0.00001:
				continue
			var fix := gap * ((length - segment) / length)
			if i == 1:
				_points[i] -= fix
			else:
				_points[i] -= fix * 0.5
				_points[i - 1] += fix * 0.5
	_draw()


## The chain's points in the weapon's frame (a copy), first the grip's end, last the padlock's shackle.
func points_local() -> PackedVector3Array:
	var inverse := _weapon.global_transform.affine_inverse()
	var out := PackedVector3Array()
	for point: Vector3 in _points:
		out.append(inverse * point)
	return out


## How many links are drawn this frame.
func links_drawn() -> int:
	return _links_drawn


## The length of the free chain (m): the grip's end to the shackle.
func rest_length() -> float:
	return _rest_length


func _count() -> int:
	return maxi(Tuning.data.weapon_chain_points, 3)


## The straight chain along the weapon's axis, at rest.
func _reset() -> void:
	var count := _count()
	var world := _weapon.global_transform
	_points.resize(count)
	_previous.resize(count)
	for i: int in count:
		var point := world * (_start_local + (_end_local - _start_local) * (float(i) / float(count - 1)))
		_points[i] = point
		_previous[i] = point
	_primed = true


func _draw() -> void:
	var count := _points.size()
	if count < 2:
		return
	var local := points_local()
	var multimesh := _multi.multimesh
	var pitch := Tuning.data.weapon_chain_link_pitch_m
	var total := 0.0
	for i: int in range(1, count):
		total += local[i].distance_to(local[i - 1])
	var links := mini(int(floor(total / pitch)), multimesh.instance_count)
	var link_rest := _link.transform
	var segment_i := 1
	var segment_start := 0.0
	var segment_len := local[1].distance_to(local[0])
	for k: int in links:
		var along := (float(k) + 0.5) * pitch
		while along > segment_start + segment_len and segment_i < count - 1:
			segment_start += segment_len
			segment_i += 1
			segment_len = local[segment_i].distance_to(local[segment_i - 1])
		var a := local[segment_i - 1]
		var b := local[segment_i]
		var tangent := (b - a).normalized() if segment_len > 0.00001 else Vector3.UP
		var t := clampf((along - segment_start) / maxf(segment_len, 0.00001), 0.0, 1.0)
		multimesh.set_instance_transform(k, Transform3D(_link_basis(tangent, k), a.lerp(b, t)) * link_rest)
	multimesh.visible_instance_count = links
	_links_drawn = links
	var end_tangent := (local[count - 1] - local[count - 2]).normalized()
	var turn := Basis(Quaternion(Vector3.UP, end_tangent))
	_lock.transform = Transform3D(turn, local[count - 1] - turn * _lock_attach) * _lock_rest


## One link's frame: its long side (Z in the art) along the chain, its flat side turned a quarter more than the link before's
## (the weapon's X axis, projected square to the chain, keeps the first from flipping).
static func _link_basis(tangent: Vector3, index: int) -> Basis:
	var normal := Vector3.RIGHT - tangent * Vector3.RIGHT.dot(tangent)
	if normal.length_squared() < 0.0001:
		normal = Vector3.BACK - tangent * Vector3.BACK.dot(tangent)
	normal = normal.normalized()
	if index % 2 == 1:
		normal = tangent.cross(normal)
	return Basis(normal.cross(tangent), normal, tangent)


func _instance(mesh_name: StringName) -> MeshInstance3D:
	for node: MeshInstance3D in _art.instances():
		if node.name == mesh_name:
			return node
	return null
