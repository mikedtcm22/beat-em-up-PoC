class_name CombatDebugDraw
extends Node3D
## Debug draw (Spec §11, F3 / action "debug_draw"). Every frame while enabled it rebuilds
## one ImmediateMesh of lines on render layer CombatTypes.VIS_DEBUG, with an unshaded,
## no-depth-test material so it shows through bodies:
##   - active hitboxes in red, from each actor's debug_hitbox_volumes
##     (spheres as three great circles, arcs as their outline at h_min and h_max),
##   - hurtboxes in green, from rig.get_hurtboxes() (each Hurtbox's CollisionShape3D
##     children: SphereShape3D or CapsuleShape3D at their global transform),
##   - the player's magnetism cone in yellow, with a line and marker on its target,
##   - each actor's debug_state_text() as a billboard Label3D above its head.
## Hurtboxes and labels hugging the active camera are skipped, so the player's own head
## does not wrap the first-person view. Actors come from group "actor". Reads only; never
## writes simulation state.
##
## The node joins group "debug_draw", so a scene that also wants debug draw on its own
## (game/ui/debug_draw.tscn) can check for an existing one, such as the HUD's, first.

## Segments in a full circle, and in the half circles over capsule caps.
const CIRCLE_SEGMENTS := 24
const HALF_CIRCLE_SEGMENTS := 12

@export var enabled: bool = false:
	set(value):
		enabled = value
		if is_node_ready():
			_apply_enabled()
@export var hitbox_color: Color = Color(1.0, 0.16, 0.12)
@export var hurtbox_color: Color = Color(0.25, 1.0, 0.4)
@export var cone_color: Color = Color(1.0, 0.88, 0.1)
@export var target_color: Color = Color(1.0, 1.0, 0.65)
## Height of the state label's bottom edge above get_head_top_position(), in meters.
@export var label_lift: float = 0.2
## State label size in meters per font pixel (Label3D pixel_size). Labels are sized in the
## world, not on screen, so the far side-view and free-fly cameras shrink them like the
## actors instead of piling them up; at first-person range a line is about 40 px tall.
@export var label_pixel_size: float = 0.0035
## Hurtboxes whose surface is within this distance of the active camera are not drawn.
@export var camera_clearance: float = 0.15
## State labels closer than this to the active camera are hidden.
@export var label_hide_distance: float = 1.0

## Lines in the mesh after the last rebuild().
var line_count: int = 0

var _mesh := ImmediateMesh.new()
var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _labels: Dictionary[int, Label3D] = {}
var _verts := PackedVector3Array()
var _colors := PackedColorArray()
var _has_camera: bool = false
var _camera_position: Vector3 = Vector3.ZERO


func _init() -> void:
	add_to_group(&"debug_draw")


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = true
	_material.disable_fog = true
	_material.render_priority = Material.RENDER_PRIORITY_MAX

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "Lines"
	_mesh_instance.mesh = _mesh
	_mesh_instance.top_level = true
	_mesh_instance.layers = CombatTypes.bit(CombatTypes.VIS_DEBUG)
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)
	_apply_enabled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_draw"):
		enabled = not enabled
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	rebuild()


## Same as setting `enabled`: show and rebuild every frame, or clear and stop.
func set_enabled(value: bool) -> void:
	enabled = value


## The line mesh, rebuilt by rebuild() (for tests and tools).
func get_mesh() -> ImmediateMesh:
	return _mesh


## State labels alive, one per actor drawn in the last rebuild().
func get_label_count() -> int:
	return _labels.size()


## The state label of `actor`, or null.
func get_label(actor: CombatActor) -> Label3D:
	return _labels.get(actor.get_instance_id(), null)


## Rebuild all lines and labels from the current actors.
func rebuild() -> void:
	_verts.clear()
	_colors.clear()
	var seen: Dictionary[int, bool] = {}
	_has_camera = false
	if enabled and is_inside_tree():
		var camera := get_viewport().get_camera_3d()
		_has_camera = camera != null and camera.is_inside_tree()
		if _has_camera:
			_camera_position = camera.global_position
		for node: Node in get_tree().get_nodes_in_group(&"actor"):
			var actor := node as CombatActor
			if actor == null or not actor.is_inside_tree():
				continue
			_add_actor(actor)
			_update_label(actor)
			seen[actor.get_instance_id()] = true
	for id: int in _labels.keys():
		if not seen.has(id):
			var label := _labels[id]
			if is_instance_valid(label):
				label.queue_free()
			_labels.erase(id)
	_flush()


func _apply_enabled() -> void:
	set_process(enabled)
	_mesh_instance.visible = enabled
	rebuild()


func _add_actor(actor: CombatActor) -> void:
	for volume: Dictionary in actor.debug_hitbox_volumes:
		var kind: StringName = volume.get("kind", &"")
		if kind == &"sphere":
			var center: Vector3 = volume.get("center", Vector3.ZERO)
			var radius: float = volume.get("radius", 0.0)
			_add_sphere(Transform3D(Basis(), center), radius, hitbox_color)
		elif kind == &"arc":
			_add_arc_volume(volume)
	if actor.rig != null and is_instance_valid(actor.rig):
		for hurtbox: Hurtbox in actor.rig.get_hurtboxes():
			if is_instance_valid(hurtbox) and hurtbox.is_inside_tree():
				_add_hurtbox(hurtbox)
	var player := actor as PlayerCharacter
	if player != null:
		_add_magnetism_cone(player.get_magnetism_cone())


## A hurtbox's sphere and capsule shapes, dimmed while it cannot be hit (KO, grabbed).
func _add_hurtbox(hurtbox: Hurtbox) -> void:
	for child: Node in hurtbox.get_children():
		var collision := child as CollisionShape3D
		if collision == null or collision.shape == null:
			continue
		var live := hurtbox.monitorable and not collision.disabled
		var color := hurtbox_color if live else Color(hurtbox_color, 0.35)
		var xform := collision.global_transform
		var sphere := collision.shape as SphereShape3D
		var capsule := collision.shape as CapsuleShape3D
		if sphere != null:
			if not _hugs_camera(xform.origin, xform.origin, sphere.radius):
				_add_sphere(xform, sphere.radius, color)
		elif capsule != null:
			var reach := maxf(capsule.height * 0.5 - capsule.radius, 0.0)
			var top := xform * Vector3(0.0, reach, 0.0)
			var bottom := xform * Vector3(0.0, -reach, 0.0)
			if not _hugs_camera(top, bottom, capsule.radius):
				_add_capsule(xform, capsule.radius, capsule.height, color)


## True if the camera is within `radius` + camera_clearance of the segment a-b (a sphere
## when a == b). Ignores the volume's scale, which hurtboxes do not use.
func _hugs_camera(a: Vector3, b: Vector3, radius: float) -> bool:
	if not _has_camera:
		return false
	var closest := Geometry3D.get_closest_point_to_segment(_camera_position, a, b)
	return closest.distance_to(_camera_position) < radius + camera_clearance


## {kind = &"arc", origin, forward, radius, half_angle_deg, h_min, h_max}: the arc at both
## heights (meters above origin), radial edges to its ends, and verticals joining them.
func _add_arc_volume(volume: Dictionary) -> void:
	var origin: Vector3 = volume.get("origin", Vector3.ZERO)
	var forward: Vector3 = volume.get("forward", Vector3.FORWARD)
	var radius: float = volume.get("radius", 0.0)
	var half_angle_deg: float = volume.get("half_angle_deg", 180.0)
	var h_min: float = volume.get("h_min", 0.0)
	var h_max: float = volume.get("h_max", 0.0)
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.000001 else Vector3.FORWARD
	var right := forward.cross(Vector3.UP)
	var half := deg_to_rad(clampf(half_angle_deg, 0.0, 180.0))
	var full := half >= PI - 0.001
	var segments := maxi(2, ceili(CIRCLE_SEGMENTS * half / PI))
	var xform := Transform3D(Basis(right, Vector3.UP, -forward), origin)
	# In this frame: x = right, y = up, -z = forward. Angle a from forward toward right.
	for h: float in [h_min, h_max]:
		var center := Vector3(0.0, h, 0.0)
		_add_circle(xform, center, Vector3.FORWARD, Vector3.RIGHT, radius, hitbox_color, -half, half, segments)
		if not full:
			_add_line(xform * center, xform * (center + _arc_point(-half, radius)), hitbox_color)
			_add_line(xform * center, xform * (center + _arc_point(half, radius)), hitbox_color)
	var posts: Array[float] = [-half, 0.0, half]
	if full:
		posts = [0.0, PI * 0.5, PI, PI * 1.5]
	for angle: float in posts:
		var edge := _arc_point(angle, radius)
		_add_line(xform * (edge + Vector3.UP * h_min), xform * (edge + Vector3.UP * h_max), hitbox_color)


## {origin, forward, half_angle_deg, range, target}: generator lines and the far ring, plus a
## line to the target's chest and a marker on it.
func _add_magnetism_cone(cone: Dictionary) -> void:
	if cone.is_empty():
		return
	var origin: Vector3 = cone.get("origin", Vector3.ZERO)
	var forward: Vector3 = cone.get("forward", Vector3.FORWARD)
	var half_angle_deg: float = cone.get("half_angle_deg", 0.0)
	var reach: float = cone.get("range", 0.0)
	if reach <= 0.0 or forward.length_squared() < 0.000001:
		return
	forward = forward.normalized()
	var half := deg_to_rad(clampf(half_angle_deg, 0.0, 89.0))
	var side := forward.cross(Vector3.UP)
	if side.length_squared() < 0.000001:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(forward).normalized()
	var ring_center := origin + forward * reach * cos(half)
	var ring_radius := reach * sin(half)
	var ring := Transform3D(Basis(), ring_center)
	_add_circle(ring, Vector3.ZERO, side, up, ring_radius, cone_color, 0.0, TAU, CIRCLE_SEGMENTS)
	for i: int in 8:
		var angle := TAU * float(i) / 8.0
		_add_line(origin, ring_center + (side * cos(angle) + up * sin(angle)) * ring_radius, cone_color)

	var target: Variant = cone.get("target")
	if not is_instance_valid(target) or not (target is Node3D):
		return
	var target_node: Node3D = target
	if not target_node.is_inside_tree():
		return
	var target_actor := target_node as CombatActor
	var point := target_actor.get_chest_position() if target_actor != null else target_node.global_position
	_add_line(origin, point, target_color)
	_add_sphere(Transform3D(Basis(), point), 0.22, target_color)
	for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		_add_line(point - axis * 0.35, point + axis * 0.35, target_color)


func _update_label(actor: CombatActor) -> void:
	var id := actor.get_instance_id()
	var label: Label3D = _labels.get(id, null)
	if label == null or not is_instance_valid(label):
		label = Label3D.new()
		label.name = "State_%d" % id
		label.top_level = true
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.pixel_size = label_pixel_size
		label.font_size = 32
		label.outline_size = 10
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.modulate = Color(1.0, 1.0, 1.0)
		label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
		label.render_priority = Material.RENDER_PRIORITY_MAX
		label.layers = CombatTypes.bit(CombatTypes.VIS_DEBUG)
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(label)
		_labels[id] = label
	label.text = actor.debug_state_text()
	label.global_position = actor.get_head_top_position() + Vector3.UP * label_lift
	label.visible = not _has_camera or label.global_position.distance_to(_camera_position) >= label_hide_distance


## Three great circles in `xform`'s local XY, XZ and YZ planes.
func _add_sphere(xform: Transform3D, radius: float, color: Color) -> void:
	if radius <= 0.0:
		return
	_add_circle(xform, Vector3.ZERO, Vector3.RIGHT, Vector3.UP, radius, color, 0.0, TAU, CIRCLE_SEGMENTS)
	_add_circle(xform, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, radius, color, 0.0, TAU, CIRCLE_SEGMENTS)
	_add_circle(xform, Vector3.ZERO, Vector3.UP, Vector3.BACK, radius, color, 0.0, TAU, CIRCLE_SEGMENTS)


## Godot capsule along local Y: `height` includes both caps. Rings at the cap centers,
## four side lines and half circles over each cap.
func _add_capsule(xform: Transform3D, radius: float, height: float, color: Color) -> void:
	if radius <= 0.0:
		return
	var reach := maxf(height * 0.5 - radius, 0.0)
	var top := Vector3(0.0, reach, 0.0)
	var bottom := Vector3(0.0, -reach, 0.0)
	_add_circle(xform, top, Vector3.RIGHT, Vector3.BACK, radius, color, 0.0, TAU, CIRCLE_SEGMENTS)
	_add_circle(xform, bottom, Vector3.RIGHT, Vector3.BACK, radius, color, 0.0, TAU, CIRCLE_SEGMENTS)
	for side: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		_add_line(xform * (top + side * radius), xform * (bottom + side * radius), color)
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		_add_circle(xform, top, axis, Vector3.UP, radius, color, 0.0, PI, HALF_CIRCLE_SEGMENTS)
		_add_circle(xform, bottom, axis, Vector3.UP, radius, color, PI, TAU, HALF_CIRCLE_SEGMENTS)


## Polyline of `segments` lines along the circle center + (a cos t + b sin t) * radius,
## t from `from_angle` to `to_angle`, in `xform`'s local space.
func _add_circle(xform: Transform3D, center: Vector3, axis_a: Vector3, axis_b: Vector3, radius: float,
		color: Color, from_angle: float, to_angle: float, segments: int) -> void:
	var previous := xform * (center + (axis_a * cos(from_angle) + axis_b * sin(from_angle)) * radius)
	for i: int in range(1, segments + 1):
		var t := lerpf(from_angle, to_angle, float(i) / float(segments))
		var point := xform * (center + (axis_a * cos(t) + axis_b * sin(t)) * radius)
		_add_line(previous, point, color)
		previous = point


## Point on a horizontal arc of `radius`, `angle` radians from forward (-Z) toward right (+X).
static func _arc_point(angle: float, radius: float) -> Vector3:
	return Vector3(sin(angle), 0.0, -cos(angle)) * radius


func _add_line(from: Vector3, to: Vector3, color: Color) -> void:
	_verts.append(from)
	_verts.append(to)
	_colors.append(color)
	_colors.append(color)


func _flush() -> void:
	_mesh.clear_surfaces()
	line_count = int(_verts.size() / 2.0)
	if _verts.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _material)
	for i: int in _verts.size():
		_mesh.surface_set_color(_colors[i])
		_mesh.surface_add_vertex(_verts[i])
	_mesh.surface_end()
