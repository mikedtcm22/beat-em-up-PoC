class_name GrabPrompt
extends Control
## The "MASH P / K!" comic panel (Milestone 3, SPEC §7: a held player breaks an enemy's grab by
## mashing): below the view center, clear of the top corners the rear warning owns, with a fill bar
## that follows PlayerCharacter.grab_break_progress() and a pop of the lettering on every press.
## Shown only while the player is GRABBED (by an enemy). Presentation only: it reads the player
## and writes nothing. Driven by GameHud.advance().

## Horizontal shear of the panel and its bar (pixels of shift per pixel of height).
@export var slant: float = 0.18
@export var border: float = 6.0
@export var font_size: int = 72
## The lettering pops to this many times its size on a press and settles back over pop_seconds.
@export var pop_scale: float = 1.18
@export var pop_seconds: float = 0.12

var gauge := HealthGauge.new()
## The player it reads (found by group on first use), and the progress last frame.
var player: PlayerCharacter
var _last_progress: float = 0.0
var _pop_left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Step `delta` real seconds: show or hide with the player's hold, follow the mash.
func advance(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	var held := player != null and player.state == CombatTypes.ActorState.GRABBED
	if not held:
		if visible:
			visible = false
			_last_progress = 0.0
			_pop_left = 0.0
			gauge.reset(0.0)
		return
	if not visible:
		visible = true
		gauge.reset(0.0)
	var progress := player.grab_break_progress()
	if progress > _last_progress + 0.0001:
		_pop_left = pop_seconds
	_last_progress = progress
	gauge.set_target(progress)
	gauge.advance(delta)
	_pop_left = maxf(_pop_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var panel := Rect2(Vector2(border + 4.0, border + 4.0), size - Vector2(border + 4.0, border + 4.0) * 2.0 - Vector2(12.0, 12.0))
	HudStyle.draw_panel(self, panel, slant, HudStyle.PAPER, border)
	var grow := lerpf(1.0, pop_scale, clampf(_pop_left / maxf(pop_seconds, 0.001), 0.0, 1.0))
	var font := HudStyle.bold_font()
	var size_px := roundi(font_size * grow)
	var text_h := font.get_ascent(size_px) - font.get_descent(size_px)
	var baseline := panel.position.y + panel.size.y * 0.5 - 18.0 + text_h * 0.5
	HudStyle.draw_text(self, Vector2(panel.position.x, baseline), "MASH P / K!", size_px, HudStyle.INK, 0,
			HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	var bar := Rect2(Vector2(panel.position.x + 36.0, panel.end.y - 40.0), Vector2(panel.size.x - 72.0, 22.0))
	HudStyle.draw_gauge(self, bar, slant, gauge, HudStyle.HEALTH, 4.0)
