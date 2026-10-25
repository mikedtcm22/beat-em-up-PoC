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
##   - the block arc in cyan while an actor guards (CombatActor.get_block_arc()): the
##     covered angle at chest height, dimmed while the guard is rising or dropping,
##   - each actor's debug_state_text() as a billboard Label3D above its head; labels of
##     actors side by side that would print over each other are stacked (_stack_labels()),
##   - the enemy AI (Milestone 3), only while an EnemyDirector and AI enemies (group
##     "ai_enemy") are in the scene, read from the director's debug API and never written:
##     a magenta ring at the feet of each attack-token holder and a line from its chest to the
##     player's, a small orange circle at each posturing enemy's slot with a dim line to it,
##     the posture ring around the player (grey-blue, at the ankles), the player's view
##     boundary (pale blue floor lines at rear_warning_angle_deg off the look) and the "both
##     corners" sector directly behind (pink lines at rear_warning_behind_deg), so blind-spot
##     priority and the rear warning can be judged from the side view and free fly, and each
##     enemy's current navigation path (violet).
## Hurtboxes and labels hugging the active camera are skipped, so the player's own head
## does not wrap the first-person view. Actors come from group "actor". Reads only; never
## writes simulation state. Processes after the cameras (HudStyle.PROCESS_PRIORITY), so
## those camera checks use this frame's view.
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
@export var block_color: Color = Color(0.15, 0.95, 1.0)
## The enemy AI layer (see above). Each color is its own, since the tests count lines by color.
@export var token_color: Color = Color(1.0, 0.2, 0.9)
@export var slot_color: Color = Color(1.0, 0.6, 0.15)
@export var ring_color: Color = Color(0.55, 0.62, 0.78)
@export var view_color: Color = Color(0.7, 0.8, 1.0)
@export var behind_color: Color = Color(1.0, 0.5, 0.65)
@export var path_color: Color = Color(0.72, 0.5, 1.0)
## Alpha of the line from a posturing enemy to its slot.
@export var slot_line_alpha: float = 0.4
## Radius (meters) of a slot's circle, and how far past a token holder's body its ring is.
@export var slot_radius: float = 0.3
@export var token_ring_margin: float = 0.25
## Length (meters) of the view-boundary and behind-sector lines on the floor.
@export var view_line_length: float = 6.0
## Height above the floor the AI layer's floor marks are drawn at (meters), so they clear it.
@export var floor_lift: float = 0.05
## Radius (meters) the block arc is drawn at around a guarding actor, and its height band
## above the feet.
@export var block_arc_radius: float = 1.1
@export var block_arc_heights: Vector2 = Vector2(0.9, 1.6)
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
## Labels of actors closer than this to each other (meters, on the ground) whose text would
## overlap from the active camera are stacked: the later actor's label rises above the
## earlier one's (at sparring range the player's "guard 100" printed over the dummy's
## "WINDUP ...").
@export var label_stack_distance: float = 2.0
## Gap between stacked labels (meters).
@export var label_stack_gap: float = 0.03

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
## The active camera's horizontal right axis (screen x of the billboard labels).
var _camera_right: Vector3 = Vector3.RIGHT


func _init() -> void:
	add_to_group(&"debug_draw")


func _ready() -> void:
	# Its own node (debug_draw.tscn), so it does not inherit the HUD's priority.
	process_priority = HudStyle.PROCESS_PRIORITY
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	# The line colors are sRGB like every Color in the project; convert them to linear.
	_material.vertex_color_is_srgb = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = true
	_material.disable_fog = true
	# Over the scene's other transparent geometry, under the state labels (outline, text).
	_material.render_priority = Material.RENDER_PRIORITY_MAX - 2

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


## The color of each line in the last rebuild(), in mesh order (for tests and tools).
func get_line_colors() -> PackedColorArray:
	var colors := PackedColorArray()
	colors.resize(line_count)
	for i: int in line_count:
		colors[i] = _colors[i * 2]
	return colors


## Lines of exactly `color` in the last rebuild().
func count_lines_of_color(color: Color) -> int:
	return get_line_colors().count(color)


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
			_camera_right = camera.global_basis.x
		var order: Array[CombatActor] = []
		for node: Node in get_tree().get_nodes_in_group(&"actor"):
			var actor := node as CombatActor
			# A KO'd body that blinked off shows nothing.
			if actor == null or not actor.is_inside_tree() or actor.is_gone():
				continue
			_add_actor(actor)
			_update_label(actor)
			seen[actor.get_instance_id()] = true
			order.append(actor)
		_stack_labels(order)
		_add_ai_layer()
	for id: int in _labels.keys():
		if not seen.has(id):
			var label := _labels[id]
			if is_instance_valid(label):
				label.queue_free()
			_labels.erase(id)
	_flush()


## The enemy AI layer: token holders, posture slots, the posture ring, the view boundary and
## the behind sector, and navigation paths. Nothing without a director and AI enemies, so a
## room without them draws what it always did.
func _add_ai_layer() -> void:
	var director := EnemyDirector.find(get_tree())
	var enemies := get_tree().get_nodes_in_group(&"ai_enemy")
	if director == null or enemies.is_empty():
		return
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	if player != null and player.is_inside_tree():
		_add_player_marks(player, director.debug_ring())
	for holder: EnemyActor in director.debug_token_holders():
		if is_instance_valid(holder) and holder.is_inside_tree() and not holder.is_gone():
			_add_token_mark(holder, player)
	for node: Node in enemies:
		var enemy := node as EnemyActor
		if enemy == null or not enemy.is_inside_tree() or enemy.is_gone():
			continue
		var slot := director.debug_slot_of(enemy)
		if slot.is_finite():
			var lifted := Vector3.UP * floor_lift
			_add_circle(Transform3D(Basis(), slot + lifted), Vector3.ZERO, Vector3.RIGHT, Vector3.BACK,
					slot_radius, slot_color, 0.0, TAU, CIRCLE_SEGMENTS)
			_add_line(enemy.global_position + lifted, slot + lifted, Color(slot_color, slot_line_alpha))
		_add_nav_path(enemy)


## The posture ring (`ring` = nearest and furthest, meters) at the player's feet, the view
## boundary (rear_warning_angle_deg off the look, both ways) and the behind sector (within
## rear_warning_behind_deg of directly behind), as floor lines from the player.
func _add_player_marks(player: PlayerCharacter, ring: Vector2) -> void:
	var feet := player.global_position + Vector3.UP * floor_lift
	var xform := Transform3D(Basis(), feet)
	for radius: float in [ring.x, ring.y]:
		if radius > 0.0:
			_add_circle(xform, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, radius, ring_color, 0.0, TAU,
					CIRCLE_SEGMENTS)
	var tuning := Tuning.data
	var edge := deg_to_rad(tuning.rear_warning_angle_deg)
	var behind := deg_to_rad(tuning.rear_warning_behind_deg)
	for offset: float in [edge, -edge]:
		_add_line(feet, feet + ViewGeometry.forward(player.look_yaw + offset) * view_line_length, view_color)
	for offset: float in [PI - behind, PI + behind]:
		_add_line(feet, feet + ViewGeometry.forward(player.look_yaw + offset) * view_line_length, behind_color)


## A ring at a token holder's feet, and a line from its chest to the player's.
func _add_token_mark(holder: EnemyActor, player: PlayerCharacter) -> void:
	var feet := Transform3D(Basis(), holder.global_position + Vector3.UP * floor_lift)
	_add_circle(feet, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, holder.body_radius + token_ring_margin,
			token_color, 0.0, TAU, CIRCLE_SEGMENTS)
	if player != null and player.is_inside_tree():
		_add_line(holder.get_chest_position(), player.get_chest_position(), token_color)


## The enemy's current navigation path as a polyline (nothing without an agent or a path).
func _add_nav_path(enemy: EnemyActor) -> void:
	for node: Node in enemy.find_children("*", "NavigationAgent3D", false, false):
		var path := (node as NavigationAgent3D).get_current_navigation_path()
		for i: int in range(1, path.size()):
			_add_line(path[i - 1] + Vector3.UP * floor_lift, path[i] + Vector3.UP * floor_lift, path_color)
		return


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
			_add_arc_volume(volume, hitbox_color)
	if actor.rig != null and is_instance_valid(actor.rig):
		for hurtbox: Hurtbox in actor.rig.get_hurtboxes():
			if is_instance_valid(hurtbox) and hurtbox.is_inside_tree():
				_add_hurtbox(hurtbox)
	var player := actor as PlayerCharacter
	if player != null:
		_add_magnetism_cone(player.get_magnetism_cone())
	var block := actor.get_block_arc()
	if not block.is_empty():
		var color := block_color if block.get("effective", false) else Color(block_color, 0.35)
		_add_arc_volume({
			origin = block.get("origin", actor.global_position),
			forward = block.get("forward", Vector3.FORWARD),
			radius = block_arc_radius,
			half_angle_deg = block.get("half_angle_deg", 0.0),
			h_min = block_arc_heights.x,
			h_max = block_arc_heights.y,
		}, color)


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
## heights (meters above origin), radial edges to its ends, and verticals joining them, in
## `color`.
func _add_arc_volume(volume: Dictionary, color: Color) -> void:
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
		_add_circle(xform, center, Vector3.FORWARD, Vector3.RIGHT, radius, color, -half, half, segments)
		if not full:
			_add_line(xform * center, xform * (center + _arc_point(-half, radius)), color)
			_add_line(xform * center, xform * (center + _arc_point(half, radius)), color)
	var posts: Array[float] = [-half, 0.0, half]
	if full:
		posts = [0.0, PI * 0.5, PI, PI * 1.5]
	for angle: float in posts:
		var edge := _arc_point(angle, radius)
		_add_line(xform * (edge + Vector3.UP * h_min), xform * (edge + Vector3.UP * h_max), color)


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
		label.outline_render_priority = Material.RENDER_PRIORITY_MAX - 1
		label.layers = CombatTypes.bit(CombatTypes.VIS_DEBUG)
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(label)
		_labels[id] = label
	label.text = actor.debug_state_text()
	label.global_position = actor.get_head_top_position() + Vector3.UP * label_lift
	label.visible = not _has_camera or label.global_position.distance_to(_camera_position) >= label_hide_distance


## Lift the labels of `actors` (in order) that would print over an earlier one's: actors
## within label_stack_distance whose label boxes, seen from the camera (across its right
## axis, and up from each label's bottom edge), overlap. A lifted label sits
## label_stack_gap above the top of the one it cleared.
func _stack_labels(actors: Array[CombatActor]) -> void:
	var right := Vector3(_camera_right.x, 0.0, _camera_right.z)
	right = right.normalized() if right.length_squared() > 0.0001 else Vector3.RIGHT
	var anchors: Array[Vector3] = []
	var boxes: Array[Rect2] = []
	for actor: CombatActor in actors:
		var label := get_label(actor)
		if label == null or not label.visible:
			continue
		var anchor := label.global_position
		var size := label_size(label)
		var box := Rect2(anchor.dot(right) - size.x * 0.5, anchor.y, size.x, size.y)
		var lifted := true
		while lifted:
			lifted = false
			for i: int in boxes.size():
				var apart := Vector2(anchor.x - anchors[i].x, anchor.z - anchors[i].z).length()
				if apart <= label_stack_distance and box.intersects(boxes[i]):
					box.position.y = boxes[i].end.y + label_stack_gap
					lifted = true
		label.global_position.y = box.position.y
		anchors.append(anchor)
		boxes.append(box)


## A state label's size in the world (meters): its widest line by its lines' height.
static func label_size(label: Label3D) -> Vector2:
	var font := label.font if label.font else ThemeDB.fallback_font
	var lines := label.text.split("\n")
	var width := 0.0
	for line: String in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x)
	var line_height := font.get_height(label.font_size) + label.line_spacing
	return Vector2(width + label.outline_size, line_height * lines.size()) * label.pixel_size


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
