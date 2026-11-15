class_name BossroofFx
extends Node3D
## The boss roof's far dressing under the trailer look profile (Milestone 7, e-bossroof): the fire wall (BossroofWall.Kind.FIRE: a flat
## stepped cloud, bossroof_fire.gdshader, with the street's flame cards, street_flame.gdshader, standing in front of it), the skyline as
## flat silhouettes (bossroof_plate.gdshader: far plates, and a flat face over each of the kit's skyline blocks) and a few hard-edged
## drifting embers (the street's street_ember.gdshader over one MultiMesh). It hangs in `boss_roof.tscn`, under the section, and builds
## nothing unless the running look profile is the trailer and has a BossroofLook for the section's `look_location`: under m6 there
## are no nodes at all, so nothing is drawn and nothing is paid. A profile flip or a `bossroof_` tunable rebuilds it.
## The street's effect shaders are used as they are, through material instances of this file's own. The drawing is held on twos:
## `advance()` counts effect time (TimeController.sim_scale() of real time) and writes the drawing number `slot`
## (floor(time x bossroof_twos_hz)) to the shaders only when it changes. Presentation only: no collider, nothing the simulation reads.

const FIRE_SHADER := preload("res://game/fx/bossroof_fire.gdshader")
const PLATE_SHADER := preload("res://game/fx/bossroof_plate.gdshader")
const FLAME_SHADER := preload("res://game/fx/street_flame.gdshader")
const EMBER_SHADER := preload("res://game/fx/street_ember.gdshader")
## The embers' random spread is seeded, so every run draws the same ones.
const EMBER_SEED := 7
## A kit skyline face's card lies this far in front of the face (m).
const FACE_LIFT_M := 0.12

var _section: LevelSection
var _look: BossroofLook
var _clock: float = 0.0
var _slot: int = 0
var _built: bool = false
var _fire_mats: Array[ShaderMaterial] = []
var _flame_mats: Array[ShaderMaterial] = []
var _ember_mat: ShaderMaterial
var _plate_count: int = 0
var _face_count: int = 0
var _ember_count: int = 0
## The fire's lamps, pools and the like (NightStreet, built from the look's lamps): TrailerLook leaves this section's to this node.
var _street: NightStreet
## The street's far matte cards (NightStreet's `Matte<n>`, under the other sections): the street's plate hangs at street-local z -92, which is
## inside this arena, so they are hidden while the player is on the boss roof (and shown again after).
var _mattes: Array[Node3D] = []
var _matte_hidden: bool = false
var _matte_retry: int = 0


func _init() -> void:
	name = &"BossroofFx"


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
	_tick_mattes()


func _physics_process(_delta: float) -> void:
	if _street != null:
		_street.flicker(Engine.get_physics_frames())


## The fire's lamp dressing, or null (tests).
func street() -> NightStreet:
	return _street


## Whether the dressing is built now.
func is_built() -> bool:
	return _built


## What is built: fire walls, flame cards, plates, block faces, embers (tests).
func counts() -> Dictionary:
	return {"fire": _fire_mats.size(), "flames": _flame_mats.size(), "plates": _plate_count, "faces": _face_count, "embers": _ember_count}


## The drawing the effects show now.
func slot() -> int:
	return _slot


## Every material the dressing draws with (tests, the cost probe).
func materials() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = _fire_mats.duplicate()
	out.append_array(_flame_mats)
	if _ember_mat != null:
		out.append(_ember_mat)
	return out


## Build or free the dressing to match the running profile and the section.
func refresh() -> void:
	_clear()
	_section = get_parent() as LevelSection
	if _section == null or not is_inside_tree() or LookProfile.current() != LookProfile.Id.TRAILER:
		return
	_look = NightLook.for_location(_section.look_location) as BossroofLook
	if _look == null:
		return
	for i in _look.walls.size():
		var wall := _look.walls[i]
		if wall == null:
			continue
		if wall.kind == BossroofWall.Kind.FIRE:
			_build_fire(wall, i)
		else:
			_build_plate(wall, i)
	_street = NightStreet.new()
	add_child(_street)
	_street.build(_section, _look)
	if _look.cover_blocks:
		_build_faces()
	_build_embers()
	_built = true
	set_physics_process(true)
	_write_slot()


## Step the effects' clock by `real_dt` real seconds; the shaders get a new drawing number only when it changes.
func advance(real_dt: float) -> void:
	if not _built:
		return
	_clock += real_dt * TimeController.sim_scale()
	var slot := floori(_clock * Tuning.data.bossroof_twos_hz)
	if slot != _slot:
		_slot = slot
		_write_slot()


## Hide the street's matte cards while the player is on this section, show them otherwise. The cards are found (by name, under the
## level's other sections) the first time they exist; a search that finds none is retried twice a second.
func _tick_mattes() -> void:
	if not _built:
		return
	var level := _section.get_parent().get_parent() as LevelRoot if _section.get_parent() != null else null
	if level == null:
		return
	var here := level.current_section() == _section
	if _mattes.is_empty():
		_matte_retry -= 1
		if _matte_retry > 0:
			return
		_matte_retry = 30
		for other: LevelSection in level.sections:
			if other != _section:
				for node: Node in other.find_children("Matte*", "MeshInstance3D", true, false):
					_mattes.append(node as Node3D)
		_matte_hidden = false
	if here == _matte_hidden:
		return
	_matte_hidden = here
	for card in _mattes:
		if is_instance_valid(card):
			card.visible = not here


func _write_slot() -> void:
	for mat: ShaderMaterial in _fire_mats:
		mat.set_shader_parameter(&"slot", float(_slot))
	for mat: ShaderMaterial in _flame_mats:
		mat.set_shader_parameter(&"slot", float(_slot))
	if _ember_mat != null:
		_ember_mat.set_shader_parameter(&"slot", float(_slot))


func _clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_fire_mats.clear()
	_flame_mats.clear()
	_ember_mat = null
	_look = null
	_street = null
	for card in _mattes:
		if is_instance_valid(card):
			card.visible = true
	_mattes.clear()
	_matte_hidden = false
	_matte_retry = 0
	_plate_count = 0
	_face_count = 0
	_ember_count = 0
	_built = false
	set_physics_process(false)


func _on_tuning_changed(property: StringName) -> void:
	if property == &"" or property == &"look_profile" or String(property).begins_with("bossroof_"):
		refresh()
	elif _street != null and String(property).begins_with("night_"):
		_street.apply_scales()


# --- The cards -----------------------------------------------------------------------------------


func _build_fire(wall: BossroofWall, index: int) -> void:
	var t := Tuning.data
	var mat := ShaderMaterial.new()
	mat.shader = FIRE_SHADER
	mat.set_shader_parameter(&"smoke_color", _look.smoke_color)
	mat.set_shader_parameter(&"smoke_inner_color", _look.smoke_inner_color)
	mat.set_shader_parameter(&"outer_color", _look.fire_outer_color)
	mat.set_shader_parameter(&"red_color", _look.fire_red_color)
	mat.set_shader_parameter(&"orange_color", _look.fire_orange_color)
	mat.set_shader_parameter(&"core_color", _look.fire_core_color)
	mat.set_shader_parameter(&"line_color", _look.fire_line_color)
	mat.set_shader_parameter(&"seed", wall.seed)
	mat.set_shader_parameter(&"card_m", wall.size_m)
	mat.set_shader_parameter(&"depth_shares", _look.fire_depth_shares)
	mat.set_shader_parameter(&"energy", t.bossroof_fire_energy)
	mat.set_shader_parameter(&"core_energy", t.bossroof_core_energy)
	mat.set_shader_parameter(&"reach", t.bossroof_fire_reach)
	mat.set_shader_parameter(&"min_line_px", t.bossroof_line_px)
	_fire_mats.append(mat)
	var quad := QuadMesh.new()
	quad.size = wall.size_m
	var node := BurnBarrel.one_mesh(quad, mat)
	node.name = "Fire%d" % index
	node.extra_cull_margin = wall.size_m.x
	add_child(node)
	node.position = wall.position
	# The street's flame cards along the foot of the wall, in front of the cloud.
	for i in wall.flames:
		var flame_mat := ShaderMaterial.new()
		flame_mat.shader = FLAME_SHADER
		flame_mat.set_shader_parameter(&"energy", t.bossroof_flame_energy)
		flame_mat.set_shader_parameter(&"seed", wall.seed * 7.0 + float(i) * 3.0)
		flame_mat.set_shader_parameter(&"min_line_px", t.bossroof_line_px)
		_flame_mats.append(flame_mat)
		var card := QuadMesh.new()
		card.size = wall.flame_size_m
		card.center_offset = Vector3(0.0, wall.flame_size_m.y * 0.5, 0.0)
		var flame := BurnBarrel.one_mesh(card, flame_mat)
		flame.name = "Flame%d_%d" % [index, i]
		flame.extra_cull_margin = wall.flame_size_m.y
		add_child(flame)
		var across := (float(i) + 0.5) / float(wall.flames) - 0.5
		var along := Basis(Vector3.UP, deg_to_rad(wall.yaw_deg)) * Vector3.RIGHT
		flame.position = wall.position + along * across * wall.size_m.x * 0.9


func _plate_material(card_m: Vector2, mode: int, seed_no: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PLATE_SHADER
	mat.set_shader_parameter(&"body_color", _look.plate_body_color)
	mat.set_shader_parameter(&"window_color", _look.plate_window_color)
	mat.set_shader_parameter(&"lit_color", _look.plate_lit_color)
	mat.set_shader_parameter(&"edge_color", _look.plate_edge_color)
	mat.set_shader_parameter(&"lit_share", _look.plate_lit_share)
	mat.set_shader_parameter(&"mode", mode)
	mat.set_shader_parameter(&"card_m", card_m)
	mat.set_shader_parameter(&"seed", seed_no)
	return mat


func _build_plate(wall: BossroofWall, index: int) -> void:
	var mat := _plate_material(wall.size_m, 0, wall.seed)
	mat.set_shader_parameter(&"cell_m", wall.cell_m)
	mat.set_shader_parameter(&"roof_m", wall.roof_m)
	var quad := QuadMesh.new()
	quad.size = wall.size_m
	quad.center_offset = Vector3(0.0, wall.size_m.y * 0.5, 0.0)
	var node := BurnBarrel.one_mesh(quad, mat)
	node.name = "Plate%d" % index
	add_child(node)
	node.position = wall.position
	node.rotation.y = deg_to_rad(wall.yaw_deg)
	_plate_count += 1


## A flat silhouette face over each of the section's kit skyline blocks, on the side that looks toward the roof.
func _build_faces() -> void:
	var blocks := _section.blocks()
	var count := 0
	for block: LevelBlock in blocks:
		if block.module != &"skyline":
			continue
		var centre := _section.to_local(block.global_position)
		var size := block.size
		# The face toward the roof's middle (x 0, z -10).
		var to_roof := Vector2(-centre.x, -10.0 - centre.z)
		var x_face := absf(to_roof.x) - size.x * 0.5 >= absf(to_roof.y) - size.z * 0.5
		var card_m := Vector2(size.z, size.y) if x_face else Vector2(size.x, size.y)
		var mat := _plate_material(card_m, 1, float(count) + 41.0)
		var quad := QuadMesh.new()
		quad.size = card_m
		var node := BurnBarrel.one_mesh(quad, mat)
		node.name = "Face%d" % count
		add_child(node)
		if x_face:
			var toward := signf(to_roof.x)
			node.position = centre + Vector3(toward * (size.x * 0.5 + FACE_LIFT_M), 0.0, 0.0)
			node.rotation.y = PI * 0.5 * toward
		else:
			var toward_z := signf(to_roof.y)
			node.position = centre + Vector3(0.0, 0.0, toward_z * (size.z * 0.5 + FACE_LIFT_M))
			node.rotation.y = 0.0 if toward_z > 0.0 else PI
		count += 1
	_face_count = count


func _build_embers() -> void:
	var t := Tuning.data
	var n := maxi(t.bossroof_embers, 0)
	if n == 0:
		return
	_ember_mat = ShaderMaterial.new()
	_ember_mat.shader = EMBER_SHADER
	_ember_mat.set_shader_parameter(&"young_color", _look.ember_young_color)
	_ember_mat.set_shader_parameter(&"old_color", _look.ember_old_color)
	_ember_mat.set_shader_parameter(&"life_slots", t.bossroof_ember_life_s * t.bossroof_twos_hz)
	_ember_mat.set_shader_parameter(&"rise_m", t.bossroof_ember_rise_m)
	_ember_mat.set_shader_parameter(&"sway_m", t.bossroof_ember_sway_m)
	_ember_mat.set_shader_parameter(&"size_m", t.bossroof_ember_size_m)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multi.mesh = quad
	multi.instance_count = n
	var rng := RandomNumberGenerator.new()
	rng.seed = EMBER_SEED
	var half := _look.ember_box_size * 0.5
	for i in n:
		var at := _look.ember_box_center + Vector3(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y), rng.randf_range(-half.z, half.z))
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
		multi.set_instance_custom_data(i, Color(float(i) / float(n), 0.0, 0.0, 0.0))
	var reach := t.bossroof_ember_rise_m + 2.0
	multi.custom_aabb = AABB(_look.ember_box_center - half - Vector3(4.0, 4.0, 4.0), _look.ember_box_size + Vector3(8.0, reach + 8.0, 8.0))
	var node := MultiMeshInstance3D.new()
	node.name = &"Embers"
	node.multimesh = multi
	node.material_override = _ember_mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_ember_count = n
