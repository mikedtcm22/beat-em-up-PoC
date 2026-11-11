class_name StreetFx
extends Node3D
## The trailer street's 2D effects (M7 T16a, docs/milestones/M7-look-target.md, "Effects"): outlined cartoon steam, soft grey
## wisps, burn barrels (BurnBarrel) with a sprite flame and drifting embers, placed in the first stretch of Mission 1's street.
## VfxDirector owns one. The effects exist only under look profile "trailer" (and only where the profile has a StreetFxSet,
## game/fx/look_profiles/<profile>_street_fx.tres, and the level has the section it names): under m6 there are no nodes at all, so
## nothing is drawn and nothing is paid. A profile flip (Tuning `look_profile`) or a `tfx_` tunable rebuilds them.
## The cards are one-instance MultiMeshInstance3Ds (BurnBarrel.one_mesh()), not MeshInstance3Ds, so M7's profile-flip test, which
## walks the room's MeshInstance3Ds, still sees only what the profile changes.
## Presentation only: no colliders, no navigation, nothing the simulation reads. Every effect redraws on twos:
## `advance()` counts effect time (TimeController.sim_scale() of real time) and writes the drawing number `slot`
## (floor(time x tfx_twos_hz)) to the shaders only when it changes.

const SET_SUFFIX := "_street_fx.tres"
const BARREL_SCENE := "res://game/level/props/burn_barrel.tscn"
const STEAM_SHADER := "res://game/fx/street_steam.gdshader"
## Every effect shader the street draws (with a drum's ink hull, a StandardMaterial3D, besides): the first flip to the trailer would
## compile each on its first drawn frame, so a window draws each once, tiny, at load (see `_show_warm()`).
const WARM_SHADERS: Array[String] = [
	"res://game/fx/street_steam.gdshader", "res://game/fx/street_flame.gdshader", "res://game/fx/street_ember.gdshader",
	"res://game/fx/street_pool.gdshader", "res://game/fx/street_barrel.gdshader",
]
## The warm-up stand-ins sit this far ahead of the camera and are this big (m): in the view, so they are drawn, but under a pixel.
## Technical values, not feel (as VfxDirector's).
const WARM_DISTANCE_M := 1.0
const WARM_SIZE_M := 0.0005

var _clock: float = 0.0
var _slot: int = 0
var _steam_mats: Array[ShaderMaterial] = []
var _barrels: Array[BurnBarrel] = []
var _built: bool = false
var _warm_pending: bool = false
var _warm_nodes: Array[Node] = []


func _init() -> void:
	name = &"StreetFx"


func _enter_tree() -> void:
	if not Tuning.changed.is_connected(_on_tuning_changed):
		Tuning.changed.connect(_on_tuning_changed)


func _exit_tree() -> void:
	if Tuning.changed.is_connected(_on_tuning_changed):
		Tuning.changed.disconnect(_on_tuning_changed)


func _ready() -> void:
	refresh()
	begin_warm_up()


func _process(delta: float) -> void:
	advance(delta)
	_step_warm_up()


## Schedule the first-use warm-up, once the viewport has a camera and `windowed` (a window is open: headless has no renderer to warm,
## so the tests' frames stay as they are; `_ready()` calls this itself). Godot builds a shader's pipeline the first time a surface with
## it is drawn, which put a hitch on the first F7 flip to the trailer, when the street's five effect shaders first appeared. So, once and
## for one rendered frame, a tiny stand-in of each (the same mesh kind and instancing as the real one) is drawn in front of the camera,
## then freed. Nothing is visible and nothing stays in the tree under m6 (the stand-ins hang on the camera, not on this node).
## Returns `windowed`.
func begin_warm_up(windowed: bool = DisplayServer.get_name() != "headless") -> bool:
	_warm_pending = windowed
	return windowed


## Whether the warm-up stand-ins are on screen now (tests).
func warming() -> bool:
	return not _warm_nodes.is_empty()


func _step_warm_up() -> void:
	for node: Node in _warm_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_warm_nodes.clear()
	if not _warm_pending or not is_inside_tree():
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		_warm_pending = false
		_show_warm(camera)


## One tiny stand-in per effect material kind, hung on `camera` straight ahead of it.
func _show_warm(camera: Camera3D) -> void:
	var at := Vector3(0.0, 0.0, -WARM_DISTANCE_M)
	var quad := QuadMesh.new()
	quad.size = Vector2(WARM_SIZE_M, WARM_SIZE_M)
	for path in WARM_SHADERS:
		var mat := ShaderMaterial.new()
		mat.shader = load(path) as Shader
		var node: Node3D
		if path == STEAM_SHADER or path.ends_with("street_flame.gdshader"):
			node = BurnBarrel.one_mesh(quad, mat)
		elif path.ends_with("street_ember.gdshader"):
			node = _warm_embers(mat, quad)
		elif path.ends_with("street_pool.gdshader"):
			var pool := QuadMesh.new()
			pool.size = Vector2(WARM_SIZE_M, WARM_SIZE_M)
			pool.orientation = PlaneMesh.FACE_Y
			node = BurnBarrel.one_mesh(pool, mat)
		else:
			var drum := CylinderMesh.new()
			drum.top_radius = WARM_SIZE_M
			drum.bottom_radius = WARM_SIZE_M
			drum.height = WARM_SIZE_M
			node = BurnBarrel.one_mesh(drum, mat)
		_hang(camera, node, at)
	# The drum's ink hull is a StandardMaterial3D, front faces culled.
	var hull_mat := StandardMaterial3D.new()
	hull_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hull_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	var hull := CylinderMesh.new()
	hull.top_radius = WARM_SIZE_M
	hull.bottom_radius = WARM_SIZE_M
	hull.height = WARM_SIZE_M
	_hang(camera, BurnBarrel.one_mesh(hull, hull_mat), at)


func _warm_embers(mat: ShaderMaterial, quad: QuadMesh) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = quad
	multi.instance_count = 1
	multi.set_instance_transform(0, Transform3D.IDENTITY)
	multi.set_instance_custom_data(0, Color(0.0, 0.0, 0.0, 0.0))
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _hang(camera: Camera3D, node: Node3D, at: Vector3) -> void:
	camera.add_child(node)
	node.position = at
	_warm_nodes.append(node)


## Whether the effects are built now.
func is_built() -> bool:
	return _built


## How many steam and wisp planes and barrels are built (tests).
func counts() -> Dictionary:
	return {"cards": _steam_mats.size(), "barrels": _barrels.size()}


## Every material the effects draw with (tests, the cost probe).
func materials() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = _steam_mats.duplicate()
	for barrel: BurnBarrel in _barrels:
		out.append_array(barrel.materials())
	return out


## Build or free the effects to match the running profile and level.
func refresh() -> void:
	_clear()
	if LookProfile.current() != LookProfile.Id.TRAILER or not is_inside_tree():
		return
	var path := LookProfile.DIR + String(LookProfile.profile_name()) + SET_SUFFIX
	var set := load(path) as StreetFxSet if ResourceLoader.exists(path) else null
	var section := _find_section(set.section_path) if set != null else null
	if section == null:
		return
	var origin := section.global_transform
	var t := Tuning.data
	var seed_no := 0
	for point: Vector3 in set.steam:
		seed_no += 1
		_add_card(origin * point, Vector2(t.tfx_steam_card_w_m, t.tfx_steam_card_h_m), _steam_material(false, seed_no))
	for point: Vector3 in set.wisps:
		seed_no += 1
		_add_card(origin * point, Vector2(t.tfx_wisp_card_w_m, t.tfx_wisp_card_h_m), _steam_material(true, seed_no))
	for point: Vector3 in set.barrels:
		var barrel := (load(BARREL_SCENE) as PackedScene).instantiate() as BurnBarrel
		add_child(barrel)
		barrel.global_position = origin * point
		_barrels.append(barrel)
	_built = true
	_write_slot()


## Step the effects' clock by `real_dt` real seconds; the shaders get a new drawing number only when it changes.
func advance(real_dt: float) -> void:
	if not _built:
		return
	_clock += real_dt * TimeController.sim_scale()
	var slot := floori(_clock * Tuning.data.tfx_twos_hz)
	if slot != _slot:
		_slot = slot
		_write_slot()


## The drawing the effects show now.
func slot() -> int:
	return _slot


func _write_slot() -> void:
	for mat: ShaderMaterial in _steam_mats:
		mat.set_shader_parameter(&"slot", float(_slot))
	for barrel: BurnBarrel in _barrels:
		barrel.set_slot(_slot)


func _clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_steam_mats.clear()
	_barrels.clear()
	_built = false


func _find_section(section_path: String) -> LevelSection:
	if section_path == "":
		return null
	for node: Node in get_tree().get_nodes_in_group(LevelRoot.GROUP):
		var root := node as LevelRoot
		if root == null:
			continue
		for section: LevelSection in root.sections:
			if section.scene_file_path == section_path:
				return section
	return null


## A steam plume (white, two tones, ink line round the edge) or a wisp (grey, one soft tone, no line).
func _steam_material(wisp: bool, seed_no: int) -> ShaderMaterial:
	var t := Tuning.data
	var mat := ShaderMaterial.new()
	mat.shader = load(STEAM_SHADER) as Shader
	mat.set_shader_parameter(&"seed", float(seed_no))
	mat.set_shader_parameter(&"rate", t.tfx_steam_rate)
	mat.set_shader_parameter(&"card_m", Vector2(t.tfx_wisp_card_w_m, t.tfx_wisp_card_h_m) if wisp else Vector2(t.tfx_steam_card_w_m, t.tfx_steam_card_h_m))
	if wisp:
		mat.set_shader_parameter(&"light_color", Color(0.62, 0.64, 0.7))
		mat.set_shader_parameter(&"dark_color", Color(0.46, 0.48, 0.56))
		mat.set_shader_parameter(&"light_alpha", t.tfx_wisp_alpha)
		mat.set_shader_parameter(&"dark_alpha", t.tfx_wisp_alpha)
		mat.set_shader_parameter(&"line_share", 0.0)
		mat.set_shader_parameter(&"min_line_px", 0.0)
		mat.set_shader_parameter(&"line_m", 0.005)
		mat.set_shader_parameter(&"lobes", 4)
		mat.set_shader_parameter(&"lobe_r_m", 0.5)
		mat.set_shader_parameter(&"rate", t.tfx_steam_rate * 0.6)
	else:
		mat.set_shader_parameter(&"light_alpha", t.tfx_steam_alpha)
		mat.set_shader_parameter(&"dark_alpha", t.tfx_steam_alpha)
		mat.set_shader_parameter(&"line_share", 1.0)
		mat.set_shader_parameter(&"min_line_px", t.tfx_line_min_px)
	_steam_mats.append(mat)
	return mat


func _add_card(at: Vector3, size: Vector2, mat: ShaderMaterial) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	var node := BurnBarrel.one_mesh(quad, mat)
	node.extra_cull_margin = size.y
	add_child(node)
	node.global_position = at


func _on_tuning_changed(property: StringName) -> void:
	if property == &"" or property == &"look_profile" or String(property).begins_with("tfx_"):
		refresh()
