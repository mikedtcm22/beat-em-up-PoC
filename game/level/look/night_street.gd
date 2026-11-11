class_name NightStreet
extends Node3D
## The dressing of one section in the trailer's night look (Milestone 7, T10): what `NightLook` authors, built as nodes under the
## section so its numbers are the section's own space. Lamp poles with a hot head, the real light each throws, its painted halo,
## its ground pool and (for a key lamp) a shaft; burn barrels; warm lit windows over some of the kit's window pieces; the
## skyline cards; and a painted contact shadow under every solid prop. TrailerLook builds and frees it with the look profile and
## ticks it (flicker, the live multipliers); nothing here writes game state.

const HALO_SHADER := preload("res://game/fx/haze_halo.gdshader")
const SHAFT_SHADER := preload("res://game/fx/light_shaft.gdshader")
const POOL_SHADER := preload("res://game/fx/light_pool.gdshader")
const WINDOW_SHADER := preload("res://game/fx/window_glow.gdshader")
const MATTE_SHADER := preload("res://game/fx/matte_card.gdshader")
const CONTACT_SHADER := preload("res://game/fx/contact_shadow.gdshader")
## The contact shadow's own plane, in metres (the shader reads its extent as 0.8 either side of the centre).
const CONTACT_PLANE_M := 1.6
## Pole and arm section, the head slab (x along the arm, y, z) and a barrel (radius, height), in metres.
const POLE_M := 0.14
const ARM_M := 0.1
const HEAD_SIZE := Vector3(0.7, 0.12, 0.38)
const BARREL_R_M := 0.3
const BARREL_H_M := 1.0
const POLE_COLOR := Color(0.07, 0.07, 0.12)
const BARREL_COLOR := Color(0.1, 0.09, 0.12)
const SIDE_WALL_X := 6.0

var section: LevelSection
var look: NightLook

## One entry per lamp: {lamp, light, halo (ShaderMaterial or null), pool, shaft, base_energy}.
var _rigs: Array[Dictionary] = []
var _contacts: Array[Dictionary] = []
var _prop_contacts: Array[ShaderMaterial] = []
var _prop_contact_alpha: float = 1.0


## Builds the dressing of `for_section` from `for_look`.
func build(for_section: LevelSection, for_look: NightLook) -> void:
	name = "NightStreet"
	section = for_section
	look = for_look
	for i in look.lamps.size():
		_build_lamp(look.lamps[i], i)
	_build_windows()
	_build_mattes()
	_build_prop_shadows()
	apply_scales()


## The lamps' rigs (tests read them).
func rigs() -> Array[Dictionary]:
	return _rigs


## The lamp lights, in the data's order.
func lights() -> Array[OmniLight3D]:
	var out: Array[OmniLight3D] = []
	for rig in _rigs:
		out.append(rig.light)
	return out


## The multipliers of Tuning's "Night street (T10)" group on the lamps, halos, pools and the props' shadows.
func apply_scales() -> void:
	var t := Tuning.data
	for rig in _rigs:
		var lamp: NightLamp = rig.lamp
		rig.base_energy = lamp.energy * t.night_lamp_energy
		(rig.light as OmniLight3D).light_energy = rig.base_energy
		if rig.halo != null:
			(rig.halo as ShaderMaterial).set_shader_parameter(&"energy", lamp.halo_energy * t.night_halo_energy)
		if rig.pool != null:
			(rig.pool as ShaderMaterial).set_shader_parameter(&"opacity", t.night_pool_opacity)
		if rig.wall != null:
			(rig.wall as ShaderMaterial).set_shader_parameter(&"opacity", t.night_pool_opacity)
	for material in _prop_contacts:
		material.set_shader_parameter(&"opacity", look.contact_opacity * t.night_contact_opacity)


## The barrels' fire: the energy wavers, held on twos of the 60 Hz tick so it reads as drawn.
func flicker(tick: int) -> void:
	for rig in _rigs:
		var lamp: NightLamp = rig.lamp
		if lamp.flicker <= 0.0:
			continue
		var slot := tick >> 1
		var wave := fmod(absf(sin(float(slot) * 12.9898 + float(rig.index) * 78.233) * 43758.5453), 1.0)
		(rig.light as OmniLight3D).light_energy = float(rig.base_energy) * (1.0 + lamp.flicker * (wave * 2.0 - 1.0))


# --- Lamps ---------------------------------------------------------------------------------


func _build_lamp(lamp: NightLamp, index: int) -> void:
	var rig := {lamp = lamp, index = index, halo = null, pool = null, wall = null, shaft = null, base_energy = lamp.energy}
	var head := lamp.head_position()
	if lamp.kind == NightLamp.Kind.LAMP:
		_build_pole(lamp, head)
	else:
		_build_barrel(lamp)
	var light := OmniLight3D.new()
	light.name = "LampLight%d" % index
	light.position = head - Vector3(0.0, 0.15, 0.0)
	light.light_color = lamp.color
	light.light_energy = lamp.energy
	light.omni_range = lamp.range_m
	light.omni_attenuation = lamp.falloff
	light.shadow_enabled = false
	add_child(light)
	rig.light = light
	if lamp.halo_m > 0.0:
		var halo := MeshInstance3D.new()
		halo.name = "LampHalo%d" % index
		var quad := QuadMesh.new()
		quad.size = Vector2(lamp.halo_m, lamp.halo_m)
		halo.mesh = quad
		halo.position = head
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = HALO_SHADER
		material.set_shader_parameter(&"core_color", look.halo_core_color)
		material.set_shader_parameter(&"ring_color", lamp.color)
		material.set_shader_parameter(&"rings", lamp.halo_rings)
		material.set_shader_parameter(&"wobble", lamp.halo_wobble)
		material.set_shader_parameter(&"seed", float(index) + 1.0)
		halo.material_override = material
		add_child(halo)
		rig.halo = material
	if lamp.pool_m > 0.0:
		var pool := MeshInstance3D.new()
		pool.name = "LampPool%d" % index
		var plane := PlaneMesh.new()
		plane.size = Vector2(lamp.pool_m, lamp.pool_m)
		pool.mesh = plane
		pool.position = Vector3(head.x, look.pool_lift_m, head.z)
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = POOL_SHADER
		var toward_middle := -signf(head.x) if absf(head.x) > 0.01 else 0.0
		material.set_shader_parameter(&"push", Vector2(toward_middle * lamp.pool_push, 0.0))
		material.set_shader_parameter(&"rim_color", look.pool_rim_color)
		material.set_shader_parameter(&"core_color", look.pool_core_color)
		material.set_shader_parameter(&"rim_alpha", look.pool_rim_alpha)
		material.set_shader_parameter(&"core_alpha", look.pool_core_alpha)
		material.set_shader_parameter(&"seed", float(index) + 1.0)
		pool.material_override = material
		add_child(pool)
		rig.pool = material
	if lamp.wall_glow_m > 0.0 and lamp.kind == NightLamp.Kind.LAMP:
		_build_wall_glow(lamp, index, rig)
	if lamp.shaft:
		var shaft := MeshInstance3D.new()
		shaft.name = "LampShaft%d" % index
		var quad := QuadMesh.new()
		quad.size = Vector2(lamp.shaft_w_m, lamp.shaft_len_m)
		quad.center_offset = Vector3(0.0, -lamp.shaft_len_m * 0.5, 0.0)
		shaft.mesh = quad
		shaft.position = head
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shaft.extra_cull_margin = lamp.shaft_len_m
		var material := ShaderMaterial.new()
		material.shader = SHAFT_SHADER
		material.set_shader_parameter(&"shaft_color", lamp.color)
		material.set_shader_parameter(&"energy", lamp.shaft_energy)
		material.set_shader_parameter(&"seed", float(index) + 1.0)
		shaft.material_override = material
		add_child(shaft)
		rig.shaft = material
	_rigs.append(rig)


## The painted warm glow on the wall the lamp's pole stands against: a vertical pool card facing the street.
func _build_wall_glow(lamp: NightLamp, index: int, rig: Dictionary) -> void:
	var side := signf(lamp.position.x)
	var glow := MeshInstance3D.new()
	glow.name = "LampWallGlow%d" % index
	var plane := PlaneMesh.new()
	plane.size = Vector2(lamp.wall_glow_m, lamp.wall_glow_m)
	plane.orientation = PlaneMesh.FACE_X
	glow.mesh = plane
	glow.position = Vector3(side * (SIDE_WALL_X - look.wall_lift_m), lamp.height_m + lamp.wall_glow_rise_m, lamp.position.z)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = POOL_SHADER
	material.set_shader_parameter(&"rim_color", look.pool_rim_color)
	material.set_shader_parameter(&"core_color", look.pool_core_color)
	material.set_shader_parameter(&"rim_alpha", look.wall_glow_alpha.x)
	material.set_shader_parameter(&"core_alpha", look.wall_glow_alpha.y)
	material.set_shader_parameter(&"seed", float(index) + 11.0)
	glow.material_override = material
	add_child(glow)
	rig.wall = material


func _build_pole(lamp: NightLamp, head: Vector3) -> void:
	var material := RoomKit.prop_material(POLE_COLOR)
	var pole := RoomKit.box_mesh(Vector3(POLE_M, lamp.height_m, POLE_M), material)
	pole.name = "LampPole"
	pole.position = lamp.position + Vector3(0.0, lamp.height_m * 0.5, 0.0)
	add_child(pole)
	var reach := absf(head.x - lamp.position.x)
	var arm := RoomKit.box_mesh(Vector3(reach + POLE_M, ARM_M, ARM_M), material)
	arm.name = "LampArm"
	arm.position = Vector3((head.x + lamp.position.x) * 0.5, lamp.height_m, lamp.position.z)
	add_child(arm)
	var lamp_head := MeshInstance3D.new()
	lamp_head.name = "LampHead"
	var slab := BoxMesh.new()
	slab.size = HEAD_SIZE
	lamp_head.mesh = slab
	lamp_head.position = Vector3(head.x, lamp.height_m - ARM_M, head.z)
	lamp_head.material_override = _glow_material(lamp)
	lamp_head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lamp_head)


func _build_barrel(lamp: NightLamp) -> void:
	var body := RoomKit.box_mesh(Vector3(BARREL_R_M * 2.0, BARREL_H_M, BARREL_R_M * 2.0), RoomKit.prop_material(BARREL_COLOR))
	body.name = "Barrel"
	body.position = lamp.position + Vector3(0.0, BARREL_H_M * 0.5, 0.0)
	add_child(body)
	var coals := MeshInstance3D.new()
	coals.name = "BarrelCoals"
	var disc := CylinderMesh.new()
	disc.top_radius = BARREL_R_M * 0.85
	disc.bottom_radius = BARREL_R_M * 0.85
	disc.height = 0.02
	coals.mesh = disc
	coals.position = lamp.position + Vector3(0.0, BARREL_H_M + 0.01, 0.0)
	coals.material_override = _glow_material(lamp)
	coals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(coals)


## A hot emissive surface in the lamp's colour: black albedo, so only the emission shows, and HDR so it blooms.
func _glow_material(lamp: NightLamp) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.BLACK
	material.emission_enabled = true
	material.emission = lamp.color.lerp(look.halo_core_color, 0.35)
	material.emission_energy_multiplier = lamp.head_glow
	material.disable_fog = true
	return material


# --- Windows, cards, props -----------------------------------------------------------------


## A warm glow card in the pane of a share of the section's kit windows (a seeded pick, so the same ones every run).
func _build_windows() -> void:
	if look.window_lit_share <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = look.window_seed
	var inverse := section.global_transform.affine_inverse()
	var count := 0
	for node: Node in section.find_children("*", "MeshInstance3D", true, false):
		var piece := node as KitPiece
		if piece == null or piece.kind != &"window":
			continue
		if rng.randf() >= look.window_lit_share:
			continue
		var card := MeshInstance3D.new()
		card.name = "WindowGlow%d" % count
		var quad := QuadMesh.new()
		quad.size = Vector2(piece.size.x * look.window_card_share.x, piece.size.y * look.window_card_share.y)
		card.mesh = quad
		var front := Vector3(0.0, 0.0, piece.size.z * 0.5 - look.window_inset_m)
		card.transform = inverse * piece.global_transform * Transform3D(Basis.IDENTITY, front)
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = WINDOW_SHADER
		material.set_shader_parameter(&"glow_color", look.window_color)
		material.set_shader_parameter(&"deep_color", look.window_deep_color)
		material.set_shader_parameter(&"energy", look.window_energy)
		material.set_shader_parameter(&"grid", Vector2.ONE)
		material.set_shader_parameter(&"mullion", 0.0)
		material.set_shader_parameter(&"margin", 0.0)
		material.set_shader_parameter(&"seed", float(count))
		material.set_shader_parameter(&"lit_share", 1.0)
		card.material_override = material
		add_child(card)
		count += 1


func _build_mattes() -> void:
	for i in look.mattes.size():
		var matte := look.mattes[i]
		if matte.texture == null:
			continue
		var card := MeshInstance3D.new()
		card.name = "Matte%d" % i
		var quad := QuadMesh.new()
		quad.size = matte.size_m
		card.mesh = quad
		card.position = matte.position
		card.rotation.y = deg_to_rad(matte.yaw_deg)
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = MATTE_SHADER
		material.set_shader_parameter(&"matte", matte.texture)
		material.set_shader_parameter(&"tint", matte.tint)
		material.set_shader_parameter(&"haze_color", matte.haze_color)
		material.set_shader_parameter(&"fade", matte.fade)
		material.set_shader_parameter(&"energy", matte.energy)
		material.set_shader_parameter(&"card_size_m", matte.size_m)
		material.set_shader_parameter(&"feather", matte.feather)
		card.material_override = material
		add_child(card)


## One painted contact shadow under every solid prop block of the section (the crates, the van, the barricades).
func _build_prop_shadows() -> void:
	var inverse := section.global_transform.affine_inverse()
	var count := 0
	for block in section.blocks():
		if block.look != &"prop" or not block.solid:
			continue
		var centre: Vector3 = inverse * block.global_position
		var size := block.size
		var card := MeshInstance3D.new()
		card.name = "PropShadow%d" % count
		var plane := PlaneMesh.new()
		plane.size = Vector2(CONTACT_PLANE_M, CONTACT_PLANE_M)
		card.mesh = plane
		var floor_y := centre.y - size.y * 0.5
		card.position = Vector3(centre.x, floor_y + look.pool_lift_m, centre.z)
		card.scale = Vector3(size.x * look.contact_prop_share / CONTACT_PLANE_M, 1.0, size.z * look.contact_prop_share / CONTACT_PLANE_M)
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := contact_material(look, float(count) + 31.0, Vector2(0.0, 1.0))
		card.material_override = material
		add_child(card)
		_prop_contacts.append(material)
		count += 1


## A contact shadow card's material: the look's colour and stretch, a seed of its own, the direction it stretches along.
static func contact_material(for_look: NightLook, seed_value: float, direction: Vector2) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CONTACT_SHADER
	material.set_shader_parameter(&"shade_color", for_look.contact_color)
	material.set_shader_parameter(&"opacity", for_look.contact_opacity)
	material.set_shader_parameter(&"stretch", for_look.contact_stretch)
	material.set_shader_parameter(&"seed", seed_value)
	material.set_shader_parameter(&"dir", direction)
	return material
