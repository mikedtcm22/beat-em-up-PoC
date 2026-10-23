class_name PauseOverlay
extends Control
## Full-screen dim plus a comic caption while the game is paused (GameInput.paused_changed).
## Esc/Menu resumes and R restarts; GameInput handles both keys.

@export var caption: String = "PAUSED: Esc/Menu to resume, R to restart"
@export var dim: Color = Color(0.0, 0.0, 0.0, 0.45)
@export var slant: float = 0.12
## Caption box center, as a fraction of the screen (kept out of the top corners).
@export var caption_center: Vector2 = Vector2(0.5, 0.17)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## GameInput.paused_changed: show the overlay while paused.
func set_paused(paused: bool) -> void:
	visible = paused
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), dim)
	var font := HudStyle.bold_font()
	var font_size := 34
	var text_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var box_size := Vector2(text_size.x + 96.0, 76.0)
	var box := Rect2(size * caption_center - box_size * 0.5, box_size)
	HudStyle.draw_panel(self, box, slant, HudStyle.PAPER, 6.0)
	var baseline := box.position.y + (box.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	HudStyle.draw_text(self, Vector2(box.position.x, baseline), caption, font_size, HudStyle.INK,
			0, HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
