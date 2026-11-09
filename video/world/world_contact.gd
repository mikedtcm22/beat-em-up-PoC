class_name VideoWorldContact
extends Node3D
## Painted contact shadows (LD-WORLD3; P1.md, "Light shapes"): a dark, hand-uneven shape on the ground under every character, so none floats.
## A flat plane per character at its feet, placed in WORLD space each frame from the character's position (never from a shadow map), each with
## its own seed so no two shapes match, stretched away from the nearest lamp (or the sun's direction when no lamp is near). First-person's own body
## (a character at the camera) gets none. Presentation only: it reads the actors and writes nothing of the game's.

const SHADER := preload("res://video/shaders/contact_shadow.gdshader")
const PLANE_M := 1.6

var look: VideoWorldLook
var rig: VideoWorldRig
## One slot a character: character node -> the plane that stands under it.
var _planes: Dictionary = {}
var _scan_at: int = 0
var _targets: Array[Node3D] = []


func _init() -> void:
	name = "ContactShadows"
	process_priority = 101


func _process(_delta: float) -> void:
	if look == null or look.contact_opacity <= 0.0:
		return
	var frame := Engine.get_physics_frames()
	if frame >= _scan_at:
		_scan_at = frame + 20
		_scan()
	var camera := get_viewport().get_camera_3d()
	var camera_at := camera.global_position if camera != null else Vector3(1.0e6, 0.0, 0.0)
	for target in _planes.keys():
		var plane: MeshInstance3D = _planes[target]
		if not is_instance_valid(target) or not is_instance_valid(plane):
			_planes.erase(target)
			if is_instance_valid(plane):
				plane.queue_free()
			continue
		var feet := (target as Node3D).global_position
		var flat := Vector2(feet.x - camera_at.x, feet.z - camera_at.z).length()
		var shown := (target as Node3D).is_visible_in_tree() and not (flat < look.contact_skip_m and absf(feet.y - camera_at.y) < 3.0 and _is_player(target))
		plane.visible = shown
		if not shown:
			continue
		plane.global_position = Vector3(feet.x, feet.y + look.contact_lift_m, feet.z)
		var away := _away_from_key(feet)
		(plane.material_override as ShaderMaterial).set_shader_parameter(&"dir", away)


## The characters: every CombatActor of the level (the player and the enemies) and every humanoid rig not already under one.
func _scan() -> void:
	_targets.clear()
	for node in get_tree().get_nodes_in_group(&"actor"):
		var n3 := node as Node3D
		if n3 != null and rig.level.is_ancestor_of(n3):
			_targets.append(n3)
	for node in rig.level.find_children("*", "HumanoidRig", true, false):
		var n3 := node as Node3D
		if n3 != null and not _under_any(n3):
			_targets.append(n3)
	var index := 0
	for target in _targets:
		index += 1
		if _planes.has(target):
			continue
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter(&"shade_color", look.contact_color)
		material.set_shader_parameter(&"opacity", look.contact_opacity)
		material.set_shader_parameter(&"seed", float(index) * 1.93 + 0.7)
		material.set_shader_parameter(&"stretch", look.contact_stretch)
		material.set_shader_parameter(&"broken", look.contact_broken)
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(PLANE_M, PLANE_M)
		var plane := MeshInstance3D.new()
		plane.name = "Contact%d" % index
		plane.mesh = mesh
		plane.scale = Vector3.ONE * (look.contact_radius_m / 0.5)
		plane.material_override = material
		plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(plane)
		_planes[target] = plane


func _under_any(node: Node3D) -> bool:
	for other in _targets:
		if other != node and other.is_ancestor_of(node):
			return true
	return false


func _is_player(node: Node) -> bool:
	return node.is_in_group(&"player")


## The ground direction the shadow stretches along: away from the nearest practical in range, else the sun's.
func _away_from_key(feet: Vector3) -> Vector2:
	var best := 1.0e9
	var best_dir := Vector2.ZERO
	for node in rig.practicals:
		if not is_instance_valid(node) or not node.has_meta(&"head"):
			continue
		var head: Vector3 = node.get_meta(&"head")
		var flat := Vector2(feet.x - head.x, feet.z - head.z)
		var d := flat.length()
		if d < best and d < 9.0:
			best = d
			best_dir = flat
	if best_dir == Vector2.ZERO:
		var toward := rig.sun_toward()
		best_dir = Vector2(-toward.x, -toward.z)
	if best_dir.length() < 0.05:
		best_dir = Vector2(0.0, 1.0)
	return best_dir.normalized()
