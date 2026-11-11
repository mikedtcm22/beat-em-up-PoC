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

var _clock: float = 0.0
var _slot: int = 0
var _steam_mats: Array[ShaderMaterial] = []
var _barrels: Array[BurnBarrel] = []
var _built: bool = false


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


func _process(delta: float) -> void:
	advance(delta)


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
		mat.set_shader_parameter(&"line_m", 0.005)
		mat.set_shader_parameter(&"lobes", 4)
		mat.set_shader_parameter(&"lobe_r_m", 0.5)
		mat.set_shader_parameter(&"rate", t.tfx_steam_rate * 0.6)
	else:
		mat.set_shader_parameter(&"light_alpha", t.tfx_steam_alpha)
		mat.set_shader_parameter(&"dark_alpha", t.tfx_steam_alpha)
		mat.set_shader_parameter(&"line_share", 1.0)
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
