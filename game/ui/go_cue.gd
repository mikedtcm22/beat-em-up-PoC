class_name GoCue
extends Control
## The "GO" cue and "CLEAR!" (Milestone 5, SPEC §9): when an arena is cleared and its barrier opens a
## comic panel shows "GO" and an arrow toward the next arena, relative to where the player looks
## (straight up: ahead, right: to his right, down: behind); when the level's last arena clears it
## says "CLEAR!" and stays. It breathes (go_cue_pulse_s), sizes with go_cue_size and lasts go_cue_s.
## Presentation only: it subscribes to CombatEvents, reads the player and the level and writes
## nothing. Driven by GameHud.advance() with game time (held by a pause), like PickupCue.

## Horizontal shear of the panel (pixels of shift per pixel of height) and the ink border.
@export var slant: float = 0.14
@export var border: float = 6.0
## Font sizes (pixels at 1920 x 1080, before go_cue_size) of "GO" and "CLEAR!".
@export var go_font_size: int = 88
@export var clear_font_size: int = 104
## How far the panel swells at the top of a breath (a share of its size).
@export var pulse_swell: float = 0.07
## The arrow's size (pixels at 1920 x 1080, before go_cue_size): its length and its head width.
@export var arrow_length: float = 92.0
@export var arrow_head_width: float = 78.0
@export var arrow_shaft_width: float = 34.0

const GO_TEXT := "GO"
const CLEAR_TEXT := "CLEAR!"

## The player it reads (found by group on first use).
var player: PlayerCharacter

var _target: Vector3 = Vector3.INF
var _left: float = 0.0
var _age: float = 0.0
var _clear: bool = false


func _init() -> void:
	name = "GoCue"
	# Centred, above the crosshair: clear of the corners the rear warning owns and of the pick-up cue.
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -300.0
	offset_top = -380.0
	offset_right = 300.0
	offset_bottom = -200.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	CombatEvents.arena_cleared.connect(_on_arena_cleared)
	CombatEvents.level_cleared.connect(_on_level_cleared)


func _exit_tree() -> void:
	if CombatEvents.arena_cleared.is_connected(_on_arena_cleared):
		CombatEvents.arena_cleared.disconnect(_on_arena_cleared)
	if CombatEvents.level_cleared.is_connected(_on_level_cleared):
		CombatEvents.level_cleared.disconnect(_on_level_cleared)


## Show "GO" with its arrow toward `target` (a world point) for go_cue_s.
func show_go(target: Vector3) -> void:
	_clear = false
	_target = target
	_left = Tuning.data.go_cue_s
	_age = 0.0
	visible = true
	queue_redraw()


## Show "CLEAR!" and keep it.
func show_clear() -> void:
	_clear = true
	_target = Vector3.INF
	_left = 0.0
	_age = 0.0
	visible = true
	queue_redraw()


## Hide whatever shows (a restart).
func reset() -> void:
	_clear = false
	_left = 0.0
	visible = false


## True while "GO" or "CLEAR!" is up.
func is_showing() -> bool:
	return visible


## True while the panel says "CLEAR!".
func is_clear() -> bool:
	return _clear


## Step `delta` seconds of game time: count the cue down, breathe.
func advance(delta: float) -> void:
	if not visible:
		return
	_age += delta
	if not _clear:
		_left -= delta
		if _left <= 0.0:
			visible = false
			return
	queue_redraw()


## The arrow's turn on screen in degrees: 0 points up (the target is straight ahead), positive
## turns clockwise (the target is to the player's right), +-180 points down (behind him). 0 with no
## target or no player.
func arrow_degrees() -> float:
	if not _target.is_finite():
		return 0.0
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	if player == null:
		return 0.0
	return -player.look_bearing_deg(_target)


## The swell of the breath at `age` seconds (0 at rest, `pulse_swell` at the top), a smooth beat of
## go_cue_pulse_s; steady (0) when the pulse is off.
func swell_at(age: float) -> float:
	var period: float = Tuning.data.go_cue_pulse_s
	if period <= 0.0:
		return 0.0
	return pulse_swell * (0.5 - 0.5 * cos(TAU * age / period))


func _on_arena_cleared(arena: Node3D) -> void:
	var level := get_tree().get_first_node_in_group(&"level_root") as LevelRoot
	if level == null:
		return
	var target := level.next_target(arena as Arena)
	if target.is_finite():
		show_go(target)


func _on_level_cleared(_level: Node3D) -> void:
	show_clear()


func _draw() -> void:
	var scale_by: float = Tuning.data.go_cue_size * (1.0 + swell_at(_age))
	var font := HudStyle.bold_font()
	var text := CLEAR_TEXT if _clear else GO_TEXT
	var font_size := roundi((clear_font_size if _clear else go_font_size) * scale_by)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var arrow := Vector2.ZERO if _clear else Vector2(arrow_length, arrow_length) * scale_by
	var gap := 0.0 if _clear else 26.0 * scale_by
	var pad := Vector2(34.0, 18.0) * scale_by
	var panel_size := Vector2(text_size.x + gap + arrow.x, maxf(text_size.y, arrow.y)) + pad * 2.0
	var panel := Rect2((size - panel_size) * 0.5, panel_size)
	HudStyle.draw_panel(self, panel, slant, HudStyle.PAPER, border * scale_by, Vector2(6.0, 6.0))
	var ink := HudStyle.INK
	var baseline := panel.position.y + (panel_size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	HudStyle.draw_text(self, Vector2(panel.position.x + pad.x, baseline), text, font_size, ink)
	if _clear:
		return
	var centre := Vector2(panel.position.x + pad.x + text_size.x + gap + arrow.x * 0.5, panel.get_center().y)
	_draw_arrow(centre, deg_to_rad(arrow_degrees()), arrow.x, scale_by)


## A block arrow of `length` centred on `centre`, pointing up when `angle` is 0 and turned clockwise
## by it: an ink outline, a yellow fill. Drawn as triangles (see `arrow_triangles`): one polygon
## through the engine's triangulation failed at a few turns (`Invalid polygon data`).
func _draw_arrow(centre: Vector2, angle: float, length: float, scale_by: float) -> void:
	for pass_index in 2:
		var outline := border * 0.6 * scale_by if pass_index == 0 else 0.0
		var color := HudStyle.INK if pass_index == 0 else HudStyle.HEALTH
		var tris := arrow_triangles(angle, length, scale_by, outline)
		for i in range(0, tris.size(), 3):
			draw_primitive(
					PackedVector2Array([centre + tris[i], centre + tris[i + 1], centre + tris[i + 2]]),
					PackedColorArray([color, color, color]), PackedVector2Array())


## The arrow's triangles (three points each, relative to its centre): the head and the shaft, grown
## by `grow` pixels for the outline, turned clockwise by `angle` (radians; 0 when it is not finite).
## No sliver: every triangle has an area at every angle.
func arrow_triangles(angle: float, length: float, scale_by: float, grow: float = 0.0) -> PackedVector2Array:
	if not is_finite(angle):
		angle = 0.0
	var half := length * 0.5
	var head := maxf(arrow_head_width * scale_by * 0.5, arrow_shaft_width * scale_by * 0.5 + 1.0)
	var shaft := arrow_shaft_width * scale_by * 0.5
	var neck := -half + length * 0.46
	# The shaft starts inside the head, so the two never leave a seam between them.
	var overlap := length * 0.1
	var tip := Vector2(0.0, -half - grow * 1.4)
	var points := PackedVector2Array([
		tip, Vector2(head + grow, neck), Vector2(-head - grow, neck),
		Vector2(shaft + grow * 0.5, neck - overlap), Vector2(shaft + grow * 0.5, half + grow), Vector2(-shaft - grow * 0.5, half + grow),
		Vector2(shaft + grow * 0.5, neck - overlap), Vector2(-shaft - grow * 0.5, half + grow), Vector2(-shaft - grow * 0.5, neck - overlap),
	])
	for i in points.size():
		points[i] = points[i].rotated(angle)
	return points
