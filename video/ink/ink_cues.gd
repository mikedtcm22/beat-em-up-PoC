class_name CineCues
extends Node
## Impact flash frames and speed lines, redone inside the 3D render (PLAN.md Plan A part 5; docs/video/P1.md
## LD-INK 3), and the game's comic words and starbursts hidden. The game's flash and lines are CanvasLayers
## of the main viewport and never reach the 2560x1440 SubViewport, so this adds one full-screen quad in the
## 3D scene (video/shaders/cine_cue_screen.gdshader) that the render sees. On a finisher hit (and a heavy one
## with `flash_on_heavy`) it holds a flash frame for `flash_ticks` simulation ticks and the speed lines for
## `lines_ticks`, centred on the contact point's screen position. The lines are re-seeded 12 times a second
## from the output frame. Presentation only: it subscribes to CombatEvents and writes nothing to the game.

const SHADER := preload("res://video/shaders/cine_cue_screen.gdshader")
const PRIORITY := Material.RENDER_PRIORITY_MIN + 3

var look: VideoInkLook
var rig: Node

var _quad: MeshInstance3D
var _material: ShaderMaterial
var _flash_until: int = -1
var _lines_until: int = -1
var _center: Vector2 = Vector2(0.5, 0.5)
var _vfx: Node
## The rear warning's state (RearWarning's `corner_state`, read only); found in the tree when null, or set by a test.
var warning_source: Object


func _init() -> void:
	process_priority = 96


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.render_priority = PRIORITY
	_material.set_shader_parameter(&"paper", look.flash_paper)
	_material.set_shader_parameter(&"ink", look.ink_color)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	_quad = MeshInstance3D.new()
	_quad.name = "CineCueQuad"
	_quad.mesh = mesh
	_quad.extra_cull_margin = 16384.0
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.material_override = _material
	_quad.visible = false
	add_child(_quad)
	CombatEvents.hit_landed.connect(_on_hit_landed)


func _exit_tree() -> void:
	if CombatEvents.hit_landed.is_connected(_on_hit_landed):
		CombatEvents.hit_landed.disconnect(_on_hit_landed)


## Trigger a flash and speed lines at world point `at` as a finisher would (for acts and tests).
func trigger(at: Vector3) -> void:
	var now := Engine.get_physics_frames()
	_flash_until = now + look.flash_ticks
	_lines_until = now + look.lines_ticks
	var camera := get_viewport().get_camera_3d()
	if camera != null and not camera.is_position_behind(at):
		var size := get_viewport().get_visible_rect().size
		var screen := camera.unproject_position(at)
		_center = Vector2(clampf(screen.x / size.x, 0.0, 1.0), clampf(screen.y / size.y, 0.0, 1.0))
	else:
		_center = Vector2(0.5, 0.5)


func _on_hit_landed(hit: HitInfo) -> void:
	if hit == null or hit.blocked:
		return
	var big := hit.tier == CombatTypes.HitTier.FINISHER or (look.flash_on_heavy and hit.tier == CombatTypes.HitTier.HEAVY)
	if big:
		trigger(hit.contact_point)


func _process(_delta: float) -> void:
	_hide_comic_fx()
	var now := Engine.get_physics_frames()
	var flash := look.flash_alpha if (look.flash_frames and now < _flash_until) else 0.0
	var lines := look.lines_alpha if (look.speed_lines and now < _lines_until) else 0.0
	var warn_left := _warning(&"left")
	var warn_right := _warning(&"right")
	_quad.visible = flash > 0.0 or lines > 0.0 or warn_left.w > 0.0 or warn_right.w > 0.0
	if not _quad.visible:
		return
	_material.set_shader_parameter(&"warn_left", warn_left)
	_material.set_shader_parameter(&"warn_right", warn_right)
	var seed_frame: int = int(floorf(float(rig.output_frame()) * look.boil_fps / look.output_fps))
	_material.set_shader_parameter(&"flash", flash)
	_material.set_shader_parameter(&"lines", lines)
	_material.set_shader_parameter(&"center", _center)
	_material.set_shader_parameter(&"seed", float(seed_frame % 1000))


## The rear warning's burst on `side`, as the cue shader draws it: (centre x, centre y, half height) in screen uv and the alpha, or zero when
## the corner is dark or the warning is off. The HUD's own burst (a comic sprite on a CanvasLayer) never reaches the render, so the cue
## pass draws its own from `RearWarning.corner_state()`, which only reads. The pulse's beat is in its alpha; the size is its rect's.
func _warning(side: StringName) -> Vector4:
	if not look.rear_warning:
		return Vector4.ZERO
	if warning_source == null or not is_instance_valid(warning_source):
		var found := get_tree().root.find_children("*", "RearWarning", true, false)
		warning_source = found[0] if not found.is_empty() else null
	if warning_source == null:
		return Vector4.ZERO
	var state: Dictionary = warning_source.call(&"corner_state", side)
	if not state.get(&"active", false):
		return Vector4.ZERO
	var rect: Rect2 = state.rect
	var control_size: Vector2 = warning_source.get(&"size")
	if control_size.x <= 0.0 or control_size.y <= 0.0:
		return Vector4.ZERO
	var centre := (rect.position + rect.size * 0.5) / control_size
	return Vector4(centre.x, centre.y, rect.size.y * 0.5 / control_size.y * look.warning_scale, clampf(float(state.alpha), 0.0, 1.0))


## The game's comic sprites are children of the VfxDirector: hidden, they never draw (its 2D layers are
## the main viewport's and never reach the render anyway).
func _hide_comic_fx() -> void:
	if not look.hide_comic_fx:
		return
	if _vfx == null or not is_instance_valid(_vfx):
		_vfx = get_tree().get_first_node_in_group(&"vfx_director")
	if _vfx != null:
		_vfx.set(&"visible", false)
