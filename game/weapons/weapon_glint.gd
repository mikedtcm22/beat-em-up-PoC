class_name WeaponGlint
extends Node3D
## The floor glint (Milestone 6, D28; docs/ARCHITECTURE.md "The catalog, the second weapon and the glint"): what shows a weapon
## on the floor now that the amber is retired. A four-point sparkle floating `weapon_glint_height_m` above the weapon, drawn
## facing the lens by glint.gdshader and never smaller than `weapon_glint_min_angle_deg` on screen, so it reads from across a
## street. Shown only while the weapon is available (lying: nobody holds it, it is not flying) and with the Debug switch
## `weapon_floor_amber` off. Presentation only: it reads the weapon's state and writes nothing.

const SHADER := preload("res://game/weapons/glint.gdshader")

var _weapon: Weapon
var _mesh: MeshInstance3D
var _material: ShaderMaterial


func _ready() -> void:
	_weapon = get_parent() as Weapon
	top_level = true
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_mesh = MeshInstance3D.new()
	_mesh.name = "Sparkle"
	_mesh.mesh = quad
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	refresh()


func _process(_delta: float) -> void:
	refresh()


## Show or hide the glint as the weapon's state says, and when shown put it above the weapon and push the tunables.
func refresh() -> void:
	if _weapon == null or _material == null:
		return
	var shown := wanted(_weapon)
	visible = shown
	if not shown:
		return
	global_position = _weapon.global_position + Vector3.UP * Tuning.data.weapon_glint_height_m
	_material.set_shader_parameter(&"glint_color", Tuning.data.weapon_glint_color)
	_material.set_shader_parameter(&"intensity", Tuning.data.weapon_glint_intensity)
	_material.set_shader_parameter(&"size_m", Tuning.data.weapon_glint_size_m)
	_material.set_shader_parameter(&"min_angle_tan", tan(deg_to_rad(Tuning.data.weapon_glint_min_angle_deg)))
	_material.set_shader_parameter(&"pulse_hz", Tuning.data.weapon_glint_pulse_hz)
	_material.set_shader_parameter(&"pulse_depth", Tuning.data.weapon_glint_pulse_depth)
	_material.set_shader_parameter(&"spin_rps", Tuning.data.weapon_glint_spin_dps / 360.0)


## Whether `weapon` shows its glint: lying on the floor, and M5's amber look is not asked for.
static func wanted(weapon: Weapon) -> bool:
	return weapon.is_available() and not Tuning.data.weapon_floor_amber


## The glint's drawn width (m) seen from `distance_m`: its near size, or the angular floor, whichever is larger.
static func drawn_size_m(distance_m: float) -> float:
	return maxf(Tuning.data.weapon_glint_size_m, distance_m * tan(deg_to_rad(Tuning.data.weapon_glint_min_angle_deg)))


## The angle (degrees) the glint covers seen from `distance_m`.
static func angular_size_deg(distance_m: float) -> float:
	return rad_to_deg(atan2(drawn_size_m(distance_m), distance_m))


## The glint's world position above `weapon`.
static func position_above(weapon: Node3D) -> Vector3:
	return weapon.global_position + Vector3.UP * Tuning.data.weapon_glint_height_m
