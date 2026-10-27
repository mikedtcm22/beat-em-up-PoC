class_name RoomKit
extends RefCounted
## Building blocks for the code-built rooms: the crowd street (Milestone 3) and, from Milestone 4,
## the training room too, so one look serves both. Static helpers only, so a room reads as a list
## of boxes: the sky and sun, solid boxes on the world layer (the physics bodies the navmesh bakes
## from), visual-only boxes, flat materials, the player with its avoidance obstacle, and the
## presentation layer (cameras, HUD, tuning overlay, VFX, audio, rumble, the look's post pass) as
## direct children of the room. Layout numbers live in the room's exports, never here.

const PLAYER_SCENE := "res://game/player/player.tscn"
const CAMERA_DIRECTOR_SCENE := "res://game/camera/camera_director.tscn"
const CAMERA_DIRECTOR_SCRIPT := "res://game/camera/camera_director.gd"
const HUD_SCENE := "res://game/ui/hud.tscn"
const DEBUG_DRAW_SCENE := "res://game/ui/debug_draw.tscn"
const TUNING_OVERLAY_SCENE := "res://game/ui/tuning_overlay.tscn"
## The art the load-time warm-up draws (warm_up_art()): the Street Punk's, the room's commonest actor.
const WARM_ART := "res://game/actors/art/punk_art.tres"


## The player's avoidance obstacle (RVO): without it enemies walk straight through the player's
## position (godot-navigation codemap section 6.3). A child of the player, so it follows him;
## its radius is Tuning.data.player_avoid_radius_m, live.
class PlayerObstacle:
	extends NavigationObstacle3D

	func _init() -> void:
		name = "AvoidanceObstacle"

	func _ready() -> void:
		avoidance_enabled = true
		_apply()
		Tuning.changed.connect(_on_tuning_changed)

	func _exit_tree() -> void:
		if Tuning.changed.is_connected(_on_tuning_changed):
			Tuning.changed.disconnect(_on_tuning_changed)

	func _on_tuning_changed(property: StringName) -> void:
		if property == &"" or property == &"player_avoid_radius_m":
			_apply()

	func _apply() -> void:
		radius = Tuning.data.player_avoid_radius_m
		var actor := get_parent() as CombatActor
		if actor:
			height = actor.body_height


## The sky, a low sun with shadows and a light fog (the training room builds it here too).
static func build_environment(room: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.42, 0.56)
	sky_mat.sky_horizon_color = Color(0.72, 0.62, 0.55)
	sky_mat.ground_horizon_color = Color(0.4, 0.37, 0.38)
	sky_mat.ground_bottom_color = Color(0.2, 0.2, 0.22)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = LookPost.tonemap_mode(Tuning.data.look_tonemap)
	env.fog_enabled = true
	env.fog_light_color = Color(0.6, 0.56, 0.55)
	env.fog_density = 0.008
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	room.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	apply_sun(sun)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	room.add_child(sun)


## Put `sun` where Tuning's Look > Toon says: its height above the horizon, the direction it comes
## from and its energy (LookPost calls this again when one changes).
static func apply_sun(sun: DirectionalLight3D) -> void:
	sun.rotation_degrees = Vector3(-Tuning.data.look_sun_elevation_deg, Tuning.data.look_sun_yaw_deg, 0.0)
	sun.light_energy = Tuning.data.look_sun_energy
	sun.shadow_blur = Tuning.data.look_sun_shadow_blur


## A solid box centred at `pos` (world layer, no mask), with a mesh when `material` is given,
## added to `parent`. Parent it under the room's geometry node: that node is what the navmesh
## bakes from. `overlay` goes on the mesh's `material_overlay` (a prop's hull).
static func add_box(parent: Node, pos: Vector3, size: Vector3, material: Material = null,
		overlay: Material = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	if material:
		body.add_child(box_mesh(size, material, overlay))
	parent.add_child(body)
	return body


## A box that is only drawn (paint, the far skyline): no collision, and the navmesh ignores it.
static func add_visual_box(parent: Node, pos: Vector3, size: Vector3, material: Material,
		overlay: Material = null) -> MeshInstance3D:
	var mesh := box_mesh(size, material, overlay)
	mesh.position = pos
	parent.add_child(mesh)
	return mesh


static func box_mesh(size: Vector3, material: Material, overlay: Material = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	mesh.material_overlay = overlay
	return mesh


## A flat-colored surface (ToonMaterials.environment()).
static func flat_material(color: Color) -> Material:
	return ToonMaterials.environment(color)


## A prop box's material (a crate, the dumpster, the car): flat like flat_material(), and it wears
## the inverted hull (ToonMaterials.environment(color, true)), so a prop is inked like a
## character (M4-plan A7). Walls, the street and paint take flat_material() and get no hull.
static func prop_material(color: Color) -> Material:
	return ToonMaterials.environment(color, true)


## The grey-box floor grid (the training room's), or a flat grey if the shader is missing
## (ToonMaterials.grid()).
static func grid_material() -> Material:
	return ToonMaterials.grid()


## The player at `pos` facing `yaw_deg`, added to `room`: it gets back up after a KO
## (auto_revive) and carries a PlayerObstacle so enemies steer around him.
static func spawn_player(room: Node3D, pos: Vector3, yaw_deg: float) -> PlayerCharacter:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerCharacter
	player.position = pos
	player.rotation.y = deg_to_rad(yaw_deg)
	player.auto_revive = true
	player.add_child(PlayerObstacle.new())
	room.add_child(player)
	return player


## Cameras, HUD, debug draw (if the HUD did not bring one), the F1/F4 TuningOverlay, the VFX,
## audio and rumble directors and the LookPost (the edge pass, the grade, the AA mode), all
## direct children of `room` (bots and tests find them there). Build the room's environment
## first: the grade goes on its WorldEnvironment.
static func build_presentation(room: Node3D) -> void:
	if ResourceLoader.exists(CAMERA_DIRECTOR_SCENE):
		room.add_child((load(CAMERA_DIRECTOR_SCENE) as PackedScene).instantiate())
	elif ResourceLoader.exists(CAMERA_DIRECTOR_SCRIPT):
		var director: Node3D = (load(CAMERA_DIRECTOR_SCRIPT) as GDScript).new()
		director.name = "CameraDirector"
		room.add_child(director)
	if ResourceLoader.exists(HUD_SCENE):
		room.add_child((load(HUD_SCENE) as PackedScene).instantiate())
	if ResourceLoader.exists(DEBUG_DRAW_SCENE) and room.get_tree().get_first_node_in_group(&"debug_draw") == null:
		room.add_child((load(DEBUG_DRAW_SCENE) as PackedScene).instantiate())
	if ResourceLoader.exists(TUNING_OVERLAY_SCENE):
		room.add_child((load(TUNING_OVERLAY_SCENE) as PackedScene).instantiate())
	room.add_child(VfxDirector.new())
	room.add_child(AudioDirector.new())
	room.add_child(RumbleDirector.new())
	room.add_child(LookPost.new())
	warm_up_art(room)


## Windowed only: draw the skinned art's toon variant (the art's vertex format, the skin, the
## hull) once at the room's load, so the first Punk of a wave does not compile it on its
## frame. A throwaway rig wears the Punk's art; ToonMaterials.warm_up() draws a copy of its
## skeleton for two frames, in the lens once the room's camera has been placed (the second frame
## of the room, not the first: the camera has not updated before that), and the rig is freed at
## once. Headless: nothing.
static func warm_up_art(room: Node3D) -> void:
	if DisplayServer.get_name() == "headless" or not ResourceLoader.exists(WARM_ART):
		return
	var rig := HumanoidRig.new()
	rig.name = "WarmUpRig"
	rig.build_hurtboxes = false
	rig.art = load(WARM_ART) as CharacterArt
	room.add_child(rig)
	rig.build()
	ToonMaterials.warm_up(room, rig.skeleton)
	rig.queue_free()
