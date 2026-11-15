class_name DuskDeck
extends Node3D
## The lit things of Mission 1's roofs under the trailer look profile (Milestone 7, x-roofs): the dusk's key light and practicals. Built from
## the DuskLook's `practicals` (DuskLamp): bulkhead lamps over the doors (an emissive head, a stepped halo, a stepped glow on the wall and
## a stepped pool on the deck), skylights in the deck, a lit sign, and the long flat shadow shapes the low sun lays across the deck. It
## hangs in `roofs.tscn` under the section and builds nothing unless the running profile is the trailer and the section's `look_location`
## has a DuskLook: under m6 there are no nodes at all. Painted cards only: no real light, no shadow caster, no collider, nothing the
## simulation reads. A profile flip or a `dusk_` tunable rebuilds it.

const HALO_SHADER := preload("res://game/fx/haze_halo.gdshader")
const POOL_SHADER := preload("res://game/fx/light_pool.gdshader")
const WINDOW_SHADER := preload("res://game/fx/window_glow.gdshader")
const SHADE_SHADER := preload("res://game/fx/dusk_shade.gdshader")
## The head slab of a bulkhead lamp (x across the wall, y, z out from it), m; it stands this far off the wall.
const HEAD_SIZE := Vector3(0.55, 0.22, 0.3)
## A card on a wall lies this far in front of it (m), a card on the deck this far above it.
const WALL_LIFT_M := 0.04
const DECK_LIFT_M := 0.035
## A far window card lies this far in front of its block's face (m: clear of the wash at 0.15).
const FAR_LIFT_M := 0.22

var _section: LevelSection
var _look: DuskLook
var _built: bool = false
var _count: int = 0
var _far_window_count: int = 0


func _init() -> void:
	name = &"DuskDeck"


func _enter_tree() -> void:
	if not Tuning.changed.is_connected(_on_tuning_changed):
		Tuning.changed.connect(_on_tuning_changed)


func _exit_tree() -> void:
	if Tuning.changed.is_connected(_on_tuning_changed):
		Tuning.changed.disconnect(_on_tuning_changed)


func _ready() -> void:
	refresh()


## Whether the dressing is built now.
func is_built() -> bool:
	return _built


## How many practicals are built (tests).
func count() -> int:
	return _count


## How many far window cards are built (tests).
func far_window_count() -> int:
	return _far_window_count


## Build or free the dressing to match the running profile and the section.
func refresh() -> void:
	_clear()
	_section = get_parent() as LevelSection
	if _section == null or not is_inside_tree() or LookProfile.current() != LookProfile.Id.TRAILER:
		return
	_look = NightLook.for_location(_section.look_location) as DuskLook
	if _look == null:
		return
	_build_far_windows()
	for i in _look.practicals.size():
		var lamp := _look.practicals[i]
		if lamp == null:
			continue
		match lamp.kind:
			DuskLamp.Kind.BULKHEAD:
				_build_bulkhead(lamp, i)
			DuskLamp.Kind.SKYLIGHT:
				_build_skylight(lamp, i)
			DuskLamp.Kind.SIGN:
				_build_sign(lamp, i)
			DuskLamp.Kind.SHADE:
				_build_shade(lamp, i)
			DuskLamp.Kind.WINDOWS:
				_build_wall_windows(lamp)
		_count += 1
	_built = true


func _clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_look = null
	_count = 0
	_far_window_count = 0
	_built = false


func _on_tuning_changed(property: StringName) -> void:
	if property == &"" or property == &"look_profile" or String(property).begins_with("dusk_practical") or String(property).begins_with("dusk_deck") or property == &"dusk_window_energy":
		refresh()


# --- The practicals ------------------------------------------------------------------------------


func _card(parent_name: String, mesh: Mesh, mat: Material, at: Vector3, yaw: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = parent_name
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	node.rotation.y = yaw
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _pool_material(lamp: DuskLamp, rim_alpha: float, core_alpha: float, seed_no: float) -> ShaderMaterial:
	var t := Tuning.data
	var mat := ShaderMaterial.new()
	mat.shader = POOL_SHADER
	mat.set_shader_parameter(&"rim_color", lamp.color * 0.55)
	mat.set_shader_parameter(&"core_color", lamp.color.lerp(Color(1.0, 0.9, 0.7), 0.25))
	mat.set_shader_parameter(&"rim_alpha", rim_alpha)
	mat.set_shader_parameter(&"core_alpha", core_alpha)
	mat.set_shader_parameter(&"opacity", t.dusk_practical_pool_opacity)
	mat.set_shader_parameter(&"soft", 0.04)
	mat.set_shader_parameter(&"seed", seed_no)
	return mat


func _halo(lamp: DuskLamp, name_tag: String, at: Vector3) -> void:
	if lamp.halo_m <= 0.0:
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(lamp.halo_m, lamp.halo_m)
	var mat := ShaderMaterial.new()
	mat.shader = HALO_SHADER
	mat.set_shader_parameter(&"core_color", _look.halo_core_color)
	mat.set_shader_parameter(&"ring_color", lamp.color)
	mat.set_shader_parameter(&"rings", 2.0)
	mat.set_shader_parameter(&"wobble", 0.1)
	mat.set_shader_parameter(&"seed", lamp.seed)
	mat.set_shader_parameter(&"soft", 0.04)
	mat.set_shader_parameter(&"ring_strength", 1.0)
	mat.set_shader_parameter(&"energy", lamp.halo_energy * Tuning.data.dusk_practical_energy)
	_card("Halo" + name_tag, quad, mat, at)


## A stepped pool lying on the deck, `out` metres from the wall along the lamp's facing.
func _deck_pool(lamp: DuskLamp, name_tag: String, centre: Vector3, rim_alpha: float, core_alpha: float, seed_no: float) -> void:
	if lamp.pool_m <= 0.0:
		return
	var plane := PlaneMesh.new()
	plane.size = Vector2(lamp.pool_m, lamp.pool_m)
	_card("Pool" + name_tag, plane, _pool_material(lamp, rim_alpha, core_alpha, seed_no), Vector3(centre.x, lamp.floor_y + DECK_LIFT_M, centre.z))


func _build_bulkhead(lamp: DuskLamp, index: int) -> void:
	var t := Tuning.data
	var tag := str(index)
	var out := lamp.facing()
	var yaw := deg_to_rad(lamp.yaw_deg)
	# The slab: black albedo, only its emission shows (HDR, so it blooms).
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color.BLACK
	glow.emission_enabled = true
	glow.emission = lamp.color.lerp(_look.halo_core_color, 0.4)
	glow.emission_energy_multiplier = lamp.glow * t.dusk_practical_energy
	glow.disable_fog = true
	var slab := BoxMesh.new()
	slab.size = HEAD_SIZE
	_card("Head" + tag, slab, glow, lamp.position, yaw)
	# The dark hood over the head: a thin cap, so the lamp reads as a fitting and not a bare glow.
	var cap := BoxMesh.new()
	cap.size = Vector3(HEAD_SIZE.x + 0.12, 0.07, HEAD_SIZE.z + 0.1)
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.07, 0.04, 0.1)
	cap_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_card("Hood" + tag, cap, cap_mat, lamp.position + Vector3(0.0, HEAD_SIZE.y * 0.5 + 0.035, 0.0), yaw)
	_halo(lamp, tag, lamp.position + out * (HEAD_SIZE.z * 0.5 + 0.05))
	# The wall glow: a stepped pool on the wall the lamp hangs on, centred a little below the head.
	if lamp.wall_glow_m > 0.0:
		var plane := PlaneMesh.new()
		plane.size = Vector2(lamp.wall_glow_m, lamp.wall_glow_m)
		plane.orientation = PlaneMesh.FACE_Z
		var at := lamp.position - out * (HEAD_SIZE.z * 0.5 - WALL_LIFT_M) + Vector3(0.0, -0.35, 0.0)
		_card("WallGlow" + tag, plane, _pool_material(lamp, 0.16, 0.26, lamp.seed + 11.0), at, yaw)
	_deck_pool(lamp, tag, lamp.position + out * lamp.pool_out_m, 0.26, 0.36, lamp.seed)


func _build_skylight(lamp: DuskLamp, index: int) -> void:
	var tag := str(index)
	# A raised curb round a lit pane: the pane is the window card lying flat, its mullions the frame.
	var mat := ShaderMaterial.new()
	mat.shader = WINDOW_SHADER
	mat.set_shader_parameter(&"glow_color", lamp.color.lerp(Color(1.0, 0.92, 0.7), 0.3))
	mat.set_shader_parameter(&"deep_color", lamp.color)
	mat.set_shader_parameter(&"mullion_color", Color(0.1, 0.05, 0.1))
	mat.set_shader_parameter(&"energy", lamp.glow * Tuning.data.dusk_practical_energy)
	mat.set_shader_parameter(&"grid", Vector2(3.0, 2.0))
	mat.set_shader_parameter(&"mullion", 0.08)
	mat.set_shader_parameter(&"margin", 0.0)
	mat.set_shader_parameter(&"uneven", 0.03)
	mat.set_shader_parameter(&"frame", 0.07)
	mat.set_shader_parameter(&"seed", lamp.seed)
	mat.set_shader_parameter(&"lit_share", 1.0)
	var quad := QuadMesh.new()
	quad.size = lamp.size_m
	var pane := _card("Skylight" + tag, quad, mat, Vector3(lamp.position.x, lamp.floor_y + 0.12, lamp.position.z), deg_to_rad(lamp.yaw_deg))
	pane.rotation.x = -PI * 0.5
	var curb := BoxMesh.new()
	curb.size = Vector3(lamp.size_m.x + 0.3, 0.1, lamp.size_m.y + 0.3)
	var curb_mat := StandardMaterial3D.new()
	curb_mat.albedo_color = Color(0.09, 0.05, 0.12)
	curb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_card("Curb" + tag, curb, curb_mat, Vector3(lamp.position.x, lamp.floor_y + 0.05, lamp.position.z), deg_to_rad(lamp.yaw_deg))
	_deck_pool(lamp, tag, lamp.position, 0.3, 0.42, lamp.seed)


func _build_sign(lamp: DuskLamp, index: int) -> void:
	var tag := str(index)
	var out := lamp.facing()
	var yaw := deg_to_rad(lamp.yaw_deg)
	var mat := ShaderMaterial.new()
	mat.shader = WINDOW_SHADER
	mat.set_shader_parameter(&"glow_color", lamp.color)
	mat.set_shader_parameter(&"deep_color", lamp.color * 0.7)
	mat.set_shader_parameter(&"mullion_color", Color(0.1, 0.04, 0.12))
	mat.set_shader_parameter(&"energy", lamp.glow * Tuning.data.dusk_practical_energy)
	mat.set_shader_parameter(&"grid", Vector2(1.0, 3.0))
	mat.set_shader_parameter(&"mullion", 0.1)
	mat.set_shader_parameter(&"margin", 0.0)
	mat.set_shader_parameter(&"uneven", 0.02)
	mat.set_shader_parameter(&"frame", 0.08)
	mat.set_shader_parameter(&"seed", lamp.seed)
	mat.set_shader_parameter(&"lit_share", 0.8)
	var quad := QuadMesh.new()
	quad.size = lamp.size_m
	_card("Sign" + tag, quad, mat, lamp.position + out * WALL_LIFT_M, yaw)
	_halo(lamp, tag, lamp.position + out * 0.1)
	if lamp.wall_glow_m > 0.0:
		var plane := PlaneMesh.new()
		plane.size = Vector2(lamp.wall_glow_m, lamp.wall_glow_m)
		plane.orientation = PlaneMesh.FACE_Z
		_card("SignGlow" + tag, plane, _pool_material(lamp, 0.16, 0.26, lamp.seed + 5.0), lamp.position + out * (WALL_LIFT_M * 0.5), yaw)
	_deck_pool(lamp, tag, lamp.position + out * lamp.pool_out_m, 0.3, 0.4, lamp.seed + 2.0)


func _build_shade(lamp: DuskLamp, index: int) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADE_SHADER
	mat.set_shader_parameter(&"shade_color", _look.shade_color)
	mat.set_shader_parameter(&"edge_color", _look.shade_edge_color)
	mat.set_shader_parameter(&"card_m", lamp.size_m)
	mat.set_shader_parameter(&"seed", lamp.seed)
	mat.set_shader_parameter(&"opacity", Tuning.data.dusk_deck_shade_opacity)
	var plane := PlaneMesh.new()
	plane.size = Vector2(lamp.size_m.x, lamp.size_m.y)
	_card("Shade%d" % index, plane, mat, Vector3(lamp.position.x, lamp.floor_y + DECK_LIFT_M * 0.5, lamp.position.z), deg_to_rad(lamp.yaw_deg))


## Rows of windows on the face of each far skyline block that looks toward the roofs: lit, dark, or none, each card with its own size, offset
## and tilt (a seeded draw), so the rows are broken. Cards lie in front of the wash that paints out part of the block's own rows.
func _build_far_windows() -> void:
	var look := _look
	var rng := RandomNumberGenerator.new()
	rng.seed = look.far_window_seed
	for block: LevelBlock in _section.blocks():
		if block.module != &"skyline":
			continue
		var centre := _section.to_local(block.global_position)
		var size := block.size
		var to_roof := Vector2(look.deck_centre.x - centre.x, look.deck_centre.y - centre.z)
		var x_face := absf(to_roof.x) - size.x * 0.5 >= absf(to_roof.y) - size.z * 0.5
		var width := size.z if x_face else size.x
		var toward := signf(to_roof.x) if x_face else signf(to_roof.y)
		var base := Basis(Vector3.UP, PI * 0.5 * toward) if x_face else (Basis.IDENTITY if toward > 0.0 else Basis(Vector3.UP, PI))
		var face_at := centre + (Vector3(toward * (size.x * 0.5 + FAR_LIFT_M), 0.0, 0.0) if x_face else Vector3(0.0, 0.0, toward * (size.z * 0.5 + FAR_LIFT_M)))
		_window_grid(rng, face_at + Vector3(0.0, -size.y * 0.5 + look.far_window_first_row_m, 0.0), base, width, size.y - look.far_window_first_row_m)


## A grid of windows on a face: `at` is the middle of the face's bottom edge, `base` turns the card's +z to the face's outward normal, the
## grid fills `width` x `height` metres in cells of the look's size. A cell is lit, dark or empty by the look's shares.
func _window_grid(rng: RandomNumberGenerator, at: Vector3, base: Basis, width: float, height: float) -> void:
	var look := _look
	var cols := maxi(int(floor(width / look.far_window_cell_m.x)), 1)
	var rows := int(floor(height / look.far_window_cell_m.y))
	for r in rows:
		for c in cols:
			var roll := rng.randf()
			var jitter := Vector4(rng.randf(), rng.randf(), rng.randf(), rng.randf())
			var seed_no := rng.randf() * 90.0
			if roll >= look.far_window_lit_share + look.far_window_dark_share:
				continue
			var along := (float(c) + 0.5) / float(cols) - 0.5
			var local := Vector3(along * width + (jitter.x - 0.5) * 0.5, (float(r) + 0.5) * look.far_window_cell_m.y + (jitter.y - 0.5) * 0.4, 0.0)
			_add_window(at + base * local, base, roll < look.far_window_lit_share, jitter, seed_no)


func _add_window(at: Vector3, base: Basis, lit: bool, jitter: Vector4, seed_no: float) -> void:
	var look := _look
	var quad := QuadMesh.new()
	quad.size = Vector2(look.far_window_size_m.x * (1.0 + (jitter.z - 0.5) * 0.4), look.far_window_size_m.y * (1.0 + (jitter.w - 0.5) * 0.3))
	var mat := ShaderMaterial.new()
	mat.shader = WINDOW_SHADER
	mat.set_shader_parameter(&"glow_color", look.window_color)
	mat.set_shader_parameter(&"deep_color", look.window_deep_color)
	mat.set_shader_parameter(&"mullion_color", look.window_mullion_color)
	mat.set_shader_parameter(&"energy", look.window_energy * Tuning.data.dusk_window_energy)
	mat.set_shader_parameter(&"grid", Vector2(2.0, 2.0) if jitter.x < 0.6 else Vector2(1.0, 3.0))
	mat.set_shader_parameter(&"mullion", look.window_mullion)
	mat.set_shader_parameter(&"margin", 0.0)
	mat.set_shader_parameter(&"uneven", look.window_uneven)
	mat.set_shader_parameter(&"seed", seed_no)
	mat.set_shader_parameter(&"lit_share", 0.9 if lit else 0.0)
	var card := MeshInstance3D.new()
	card.name = "FarWindow%d" % _far_window_count
	card.mesh = quad
	card.material_override = mat
	card.transform = Transform3D(base * Basis(Vector3.BACK, deg_to_rad((jitter.z - 0.5) * 2.0 * look.window_tilt_deg)), at)
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(card)
	_far_window_count += 1


## Window rows on a wall of the roofs themselves: `position` is the middle of the area's bottom edge on the wall, `size_m` its width and height.
func _build_wall_windows(lamp: DuskLamp) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(lamp.seed) + _look.far_window_seed
	var base := Basis(Vector3.UP, deg_to_rad(lamp.yaw_deg))
	_window_grid(rng, lamp.position + lamp.facing() * WALL_LIFT_M, base, lamp.size_m.x, lamp.size_m.y)
