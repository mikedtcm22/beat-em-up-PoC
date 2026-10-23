class_name CameraModeToast
extends Control
## Top-center caption naming the camera mode for a moment after CameraDirector.camera_changed
## (F2 cycles first-person, side-view and free-fly). Driven by GameHud.advance().

@export var show_seconds: float = 1.5
@export var fade_seconds: float = 0.3
@export var slant: float = 0.2

## Caption text, e.g. "CAMERA: SIDE VIEW".
var text: String = ""
var time_left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Show "CAMERA: <MODE>" for show_seconds, restarting the timer if already up.
func show_mode(mode: StringName) -> void:
	text = "CAMERA: %s" % CameraModeToast.mode_label(mode)
	time_left = show_seconds
	modulate.a = 1.0
	visible = true
	queue_redraw()


## &"first_person" -> "FIRST PERSON".
static func mode_label(mode: StringName) -> String:
	return String(mode).replace("_", " ").to_upper()


## Count down `delta` seconds, fading out over the last fade_seconds.
func advance(delta: float) -> void:
	if time_left <= 0.0:
		return
	time_left -= delta
	modulate.a = clampf(time_left / fade_seconds, 0.0, 1.0) if fade_seconds > 0.0 else 1.0
	if time_left <= 0.0:
		visible = false


func _draw() -> void:
	var body := Rect2(Vector2(6.0, 6.0), size - Vector2(18.0, 18.0))
	HudStyle.draw_panel(self, body, slant, HudStyle.PAPER, 4.0, Vector2(5.0, 5.0))
	var font := HudStyle.bold_font()
	var font_size := 28
	var baseline := body.position.y + (body.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	HudStyle.draw_text(self, Vector2(body.position.x, baseline), text, font_size, HudStyle.INK,
			0, HORIZONTAL_ALIGNMENT_CENTER, body.size.x)
