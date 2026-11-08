class_name CineSmears
extends Node3D
## Anime smears on fast limbs (PLAN.md Plan A part 7; docs/video/P1.md LD-INK 3). From CombatEvents: when a
## character starts an attack, its fists and its right foot are watched for `watch_ticks` simulation ticks;
## while one moves faster than `min_speed` (m/s) a streak is drawn along its last `samples` positions, a
## camera-facing ribbon that tapers to its tail and fades. Presentation only: it reads the rig's bone
## positions and never writes the game. The ribbons are one ImmediateMesh each, rebuilt every frame.

const POINTS: Array[StringName] = [&"RightFistPoint", &"LeftFistPoint", &"RightFootPoint"]

var enabled: bool = true
var min_speed: float = 5.0
var samples: int = 7
var width_m: float = 0.16
var alpha: float = 0.85
var color: Color = Color(1.0, 0.93, 0.8)
var watch_ticks: int = 20

var _watch: Dictionary[int, Dictionary] = {}
var _material: StandardMaterial3D
var _meshes: Dictionary[String, MeshInstance3D] = {}


func _init() -> void:
	process_priority = 92
	top_level = true


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.no_depth_test = false
	_material.disable_fog = true
	CombatEvents.attack_started.connect(_on_attack_started)


func _exit_tree() -> void:
	if CombatEvents.attack_started.is_connected(_on_attack_started):
		CombatEvents.attack_started.disconnect(_on_attack_started)


func _on_attack_started(attacker: Node, _move: Resource, _chain: int, _timing: StringName) -> void:
	if not enabled or attacker == null:
		return
	var rig: HumanoidRig = attacker.get(&"rig")
	if rig == null:
		return
	_watch[attacker.get_instance_id()] = {rig = rig, left = watch_ticks, trails = {}}


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var view := camera.global_position if camera != null else Vector3.ZERO
	var done: Array[int] = []
	var used := {}
	for id in _watch:
		var entry: Dictionary = _watch[id]
		var rig: HumanoidRig = entry.rig
		if not is_instance_valid(rig) or not rig.is_inside_tree():
			done.append(id)
			continue
		for point in POINTS:
			var trails: Dictionary = entry.trails
			var trail: Array = trails.get(point, [])
			var here := rig.get_point_position(point)
			var speed := 0.0
			if not trail.is_empty():
				speed = (here - (trail[trail.size() - 1] as Vector3)).length() * Engine.physics_ticks_per_second
			if trail.is_empty() or here != trail[trail.size() - 1]:
				trail.append(here)
				while trail.size() > samples:
					trail.remove_at(0)
			trails[point] = trail
			var key := "%d/%s" % [id, point]
			used[key] = true
			_draw(key, trail, speed >= min_speed * 0.6 or _fast_trail(trail), view)
	for key in _meshes.keys():
		if not used.has(key):
			_meshes[key].queue_free()
			_meshes.erase(key)
	# The watch runs in simulation ticks: count down by one tick per physics frame.
	for id in _watch.keys():
		var entry: Dictionary = _watch[id]
		entry.left -= maxi(Engine.get_physics_frames() - int(entry.get("frame", Engine.get_physics_frames())), 0)
		entry.frame = Engine.get_physics_frames()
		if entry.left <= 0:
			done.append(id)
	for id in done:
		_watch.erase(id)


## How many ribbons are drawn right now (for acts and tests).
func drawing_count() -> int:
	var count := 0
	for key in _meshes:
		var mesh := (_meshes[key] as MeshInstance3D).mesh as ImmediateMesh
		if mesh != null and mesh.get_surface_count() > 0:
			count += 1
	return count


## A trail is fast when its whole length per sample interval beats the speed threshold.
func _fast_trail(trail: Array) -> bool:
	if trail.size() < 3:
		return false
	var length := 0.0
	for i in trail.size() - 1:
		length += ((trail[i + 1] as Vector3) - (trail[i] as Vector3)).length()
	var seconds := float(trail.size() - 1) / float(Engine.physics_ticks_per_second)
	return length / maxf(seconds, 0.0001) >= min_speed


func _draw(key: String, trail: Array, fast: bool, view: Vector3) -> void:
	var mesh_node: MeshInstance3D = _meshes.get(key)
	if mesh_node == null:
		mesh_node = MeshInstance3D.new()
		mesh_node.mesh = ImmediateMesh.new()
		mesh_node.material_override = _material
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_node.extra_cull_margin = 100.0
		add_child(mesh_node)
		_meshes[key] = mesh_node
	var immediate := mesh_node.mesh as ImmediateMesh
	immediate.clear_surfaces()
	if not enabled or not fast or trail.size() < 3:
		return
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	var count := trail.size()
	for i in count:
		var p: Vector3 = trail[i]
		var tangent: Vector3 = (trail[mini(i + 1, count - 1)] as Vector3) - (trail[maxi(i - 1, 0)] as Vector3)
		var side := tangent.cross(view - p)
		if side.length() < 0.00001:
			continue
		side = side.normalized()
		# Newest sample (the end of the list) is the fist: full width and alpha; the tail tapers to nothing.
		var t := float(i) / float(count - 1)
		var half := width_m * 0.5 * t * near_fade_w(view, p)
		# A smear this close to the lens would fill the frame: it fades in with the distance.
		var near_fade := smoothstep(0.5, 1.5, view.distance_to(p))
		var c := Color(color.r, color.g, color.b, alpha * t * t * near_fade)
		points.append(p + side * half)
		colors.append(c)
		points.append(p - side * half)
		colors.append(c)
	if points.size() < 4:
		return
	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in points.size():
		immediate.surface_set_color(colors[i])
		immediate.surface_add_vertex(points[i])
	immediate.surface_end()


## The ribbon's width shrinks too inside 1.5 m so it never covers the frame.
func near_fade_w(view: Vector3, p: Vector3) -> float:
	return clampf(view.distance_to(p) / 1.5, 0.15, 1.0)
