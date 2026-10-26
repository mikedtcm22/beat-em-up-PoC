class_name PickupCue
extends Control
## The "LB" pick-up cue (Milestone 3, P4-int): a small comic panel low in the view that shows while
## LB would pick a weapon up (PlayerCharacter.pickup_target()). The Pipe Thug's dropped pipe lies
## below the forward lens, so a player who does not look down would never see it. It swells and
## settles (pickup_cue_pulse_s) so the eye catches it, and sits clear of the corners the rear
## warning owns and of the MASH prompt (which shows only while the player is held, when no pick-up
## is possible). Presentation only: it reads the player and the tunables and writes nothing.
## Driven by GameHud.advance() with game time (held by a pause).

## Horizontal shear of the panel (pixels of shift per pixel of height) and the ink border.
@export var slant: float = 0.18
@export var border: float = 5.0
## Font sizes (pixels at 1920 x 1080, before pickup_cue_size) of the button name and its caption.
@export var button_font_size: int = 56
@export var caption_font_size: int = 26
## How far the panel swells at the top of a breath (a share of its size).
@export var pulse_swell: float = 0.06

## The text of the two lines.
const BUTTON_TEXT := "LB"
const CAPTION_TEXT := "PICK UP"

## The player it reads (found by group on first use).
var player: PlayerCharacter
var _age: float = 0.0
var _was_shown: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## True while the cue should show: the option is on and the player could pick a weapon up now.
func should_show() -> bool:
	if not Tuning.data.pickup_cue_enabled:
		return false
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	return player != null and player.pickup_target() != null


## Step `delta` seconds of game time: show or hide with the player's reach, breathe.
func advance(delta: float) -> void:
	var shown := should_show()
	if shown != _was_shown:
		_was_shown = shown
		_age = 0.0
	visible = shown
	if not shown:
		return
	_age += delta
	queue_redraw()


## The swell of the breath at `age` seconds (0 at rest, `pulse_swell` at the top), a smooth beat
## of pickup_cue_pulse_s; steady (0) when the pulse is off.
func swell_at(age: float) -> float:
	var period: float = Tuning.data.pickup_cue_pulse_s
	if period <= 0.0:
		return 0.0
	return pulse_swell * (0.5 - 0.5 * cos(TAU * age / period))


func _draw() -> void:
	var scale_by: float = Tuning.data.pickup_cue_size * (1.0 + swell_at(_age))
	var alpha: float = Tuning.data.pickup_cue_opacity
	var panel_size := Vector2(size.x * 0.7, size.y * 0.82) * scale_by
	var panel := Rect2((size - panel_size) * 0.5, panel_size)
	HudStyle.draw_panel(self, panel, slant, HudStyle.PAPER, border, Vector2(5.0, 5.0), alpha)
	var big := roundi(button_font_size * scale_by)
	var small := roundi(caption_font_size * scale_by)
	var font := HudStyle.bold_font()
	var big_h := font.get_ascent(big) - font.get_descent(big)
	var small_h := font.get_ascent(small) - font.get_descent(small)
	var gap := 6.0 * scale_by
	var top := panel.position.y + (panel.size.y - (big_h + gap + small_h)) * 0.5
	HudStyle.draw_text(self, Vector2(panel.position.x, top + big_h), BUTTON_TEXT, big,
			HudStyle.with_alpha(HudStyle.INK, alpha), 0, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	HudStyle.draw_text(self, Vector2(panel.position.x, top + big_h + gap + small_h), CAPTION_TEXT, small,
			HudStyle.with_alpha(HudStyle.INK, alpha), 0, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
