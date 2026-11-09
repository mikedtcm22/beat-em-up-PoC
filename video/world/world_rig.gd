class_name VideoWorldRig
extends Node3D
## The helper node a VideoWorldLook leaves under the level (LD-WORLD): it holds what the look built, and does the per-frame work.
## The per-frame work is small and is never time-driven: it re-asserts the sun (the level and LookPost write it on a section change
## or a look_* change, and the world look's values must stand), and re-rolls the fire's flicker from the PHYSICS FRAME NUMBER,
## at the look's flicker rate, so a frame is the same on every run.
## It also publishes the key for LD-INK's rim lights: `hook()`.

var look: VideoWorldLook
var level: Node
var sun: DirectionalLight3D
var env: Environment
var sky_material: ShaderMaterial
var haze_material: ShaderMaterial
## The practicals built (VideoWorldPractical roots), each a Node3D with a `light` child and meta `flicker`/`base_energy`.
var practicals: Array[Node3D] = []
## The matte cards' materials (the rig writes the drifting smoke's phase) and the flame cards' (their 12 fps slot).
var matte_materials: Array[ShaderMaterial] = []
## The physics frame the look began on: every animation here counts from it, so a shot looks the same whenever it is shot.
var _born_frame: int = 0


func _init() -> void:
	# After the level and the game's cameras: the look's values are the last word each frame.
	process_priority = 100


## Called by the look once everything is built: the animation's frame zero is now.
func start() -> void:
	_born_frame = Engine.get_physics_frames()
	_update_focus()


func _process(_delta: float) -> void:
	assert_sun()
	_flicker()
	_update_focus()
	_animate()


## The frames since the look was applied (the shot's own count: never the absolute physics frame, which depends on how long the process ran).
func shot_frame() -> int:
	return maxi(0, Engine.get_physics_frames() - _born_frame)


## The focus: the look's point (section space), or the spot `focus_follow_m` metres ahead of the camera, written on every paint material.
func _update_focus() -> void:
	if look == null:
		return
	var at := section_origin() + look.focus_point
	if look.focus_follow_m > 0.0:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			at = camera.global_position - camera.global_basis.z * look.focus_follow_m
	var value := Vector4(at.x, at.y, at.z, look.focus_radius_m)
	for material in look.live_materials:
		if material != null:
			material.set_shader_parameter(&"focus", value)


## Painted flames re-roll at the flicker rate, the smoke sways: both from the shot's frame.
func _animate() -> void:
	var slot := float(shot_frame() * look.flicker_fps / 60)
	for node in practicals:
		if not is_instance_valid(node):
			continue
		for child in node.get_children():
			if child.has_meta(&"flame_material"):
				(child.get_meta(&"flame_material") as ShaderMaterial).set_shader_parameter(&"slot", slot)
	for material in matte_materials:
		material.set_shader_parameter(&"phase", float(shot_frame()))


## The level's section: the origin of the look's section-space positions.
func section_origin() -> Vector3:
	var root := level as LevelRoot
	if root != null and look.section < root.sections.size():
		return root.sections[look.section].global_position
	return Vector3.ZERO


## The direction TOWARD the sun (its basis' +Z), world space.
func sun_toward() -> Vector3:
	if sun != null:
		return sun.global_basis.z
	return VideoWorldRig.toward_from_angles(look.sun_elevation_deg, look.sun_yaw_deg)


## The direction toward a sun with these angles (the level's convention: rotation (-elevation, yaw, 0)).
static func toward_from_angles(elevation_deg: float, yaw_deg: float) -> Vector3:
	var e := deg_to_rad(elevation_deg)
	var y := deg_to_rad(yaw_deg)
	return Vector3(sin(y) * cos(e), sin(e), cos(y) * cos(e))


## Put the look's sun values on the level's Sun (a no-op when they already stand).
func assert_sun() -> void:
	if sun == null or look == null:
		return
	var rotation_want := Vector3(-look.sun_elevation_deg, look.sun_yaw_deg, 0.0)
	if not sun.rotation_degrees.is_equal_approx(rotation_want):
		sun.rotation_degrees = rotation_want
	sun.light_color = look.sun_color
	sun.light_energy = look.sun_energy
	sun.shadow_enabled = look.sun_shadow and not _a_light_casts()
	# The larger of this look's blur and whatever another piece (LD-INK's floor) has raised it to: the last writer never lowers it.
	sun.shadow_blur = maxf(sun.shadow_blur, look.sun_shadow_blur)
	sun.directional_shadow_max_distance = look.sun_shadow_max_m
	sun.light_specular = 0.0


func _a_light_casts() -> bool:
	for spec in look.lights:
		if spec.shadow:
			return true
	return false


## How many lights cast a shadow in this look (the sun counts when it does): one a shot.
func shadow_caster_count() -> int:
	var n := 0
	for spec in look.lights:
		if spec.shadow:
			n += 1
	if look.sun_shadow and n == 0:
		n = 1
	return n


func _flicker() -> void:
	var slot := int(shot_frame() * look.flicker_fps / 60)
	for node in practicals:
		if not is_instance_valid(node) or not node.has_meta(&"flicker"):
			continue
		var amount: float = node.get_meta(&"flicker")
		var light: Light3D = node.get_meta(&"light")
		var base_energy: float = node.get_meta(&"base_energy")
		var roll := fposmod(sin(float(slot) * 12.9898 + float(practicals.find(node)) * 78.233) * 43758.5453, 1.0)
		light.light_energy = base_energy * (1.0 + (roll - 0.5) * 2.0 * amount)


## The key for LD-INK's rim lights, a Dictionary: `color` (the key's), `toward` (the direction toward the key: the sun's when the look's
## hook_from_sun, else straight up), `sun_color`, `sun_toward`, and per practical, in order: `heads` (world positions), `ranges` (m)
## and `colors`.
func hook() -> Dictionary:
	var heads := PackedVector3Array()
	var ranges := PackedFloat32Array()
	var colors := PackedColorArray()
	for node in practicals:
		if is_instance_valid(node) and node.has_meta(&"head"):
			heads.append(node.get_meta(&"head"))
			var light: Light3D = node.get_meta(&"light")
			ranges.append(light.spot_range if light is SpotLight3D else (light as OmniLight3D).omni_range)
			colors.append(light.light_color)
	return {
		&"color": look.hook_color,
		&"toward": sun_toward() if look.hook_from_sun else Vector3.UP,
		&"sun_color": look.sun_color,
		&"sun_toward": sun_toward(),
		&"heads": heads,
		&"ranges": ranges,
		&"colors": colors,
	}


## Leave the hook on the level as meta `video_world_hook` (a Dictionary), for a piece that runs after this one.
func publish_hook() -> void:
	level.set_meta(&"video_world_hook", hook())
