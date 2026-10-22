class_name BlockCallout
extends Control
## Comic lettering just below the view center when the player's guard does something
## special: "PARRY!" on a perfect block, "GUARD BREAK!" when the guard breaks. It pops in
## a little oversized, settles, then fades. Placeholder for the Milestone 2 comic VFX.
## Fed by GameHud from CombatEvents.perfect_blocked and guard_broken (the player only);
## driven by GameHud.advance().

@export var show_seconds: float = 0.55
@export var fade_seconds: float = 0.2
## Seconds the pop-in takes to settle from pop_scale to full size.
@export var pop_seconds: float = 0.08
@export var pop_scale: float = 1.35
@export var font_size: int = 54

## Lettering shown, e.g. "PARRY!".
var text: String = ""
var color: Color = HudStyle.PARRY
var time_left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Pop "PARRY!" in the parry color.
func show_parry() -> void:
	_show("PARRY!", HudStyle.PARRY)


## Pop "GUARD BREAK!" in the finisher accent.
func show_guard_break() -> void:
	_show("GUARD BREAK!", HudStyle.FINISHER_ACCENT)


## Count down `delta` seconds, fading out over the last fade_seconds.
func advance(delta: float) -> void:
	if time_left <= 0.0:
		return
	time_left -= delta
	modulate.a = clampf(time_left / fade_seconds, 0.0, 1.0) if fade_seconds > 0.0 else 1.0
	if time_left <= 0.0:
		visible = false
	queue_redraw()


func _show(value: String, tint: Color) -> void:
	text = value
	color = tint
	time_left = show_seconds
	modulate.a = 1.0
	visible = true
	queue_redraw()


func _draw() -> void:
	var age := show_seconds - time_left
	var grow := lerpf(pop_scale, 1.0, clampf(age / maxf(pop_seconds, 0.001), 0.0, 1.0))
	var font := HudStyle.bold_font()
	var size_px := roundi(font_size * grow)
	var baseline := (size.y + font.get_ascent(size_px) - font.get_descent(size_px)) * 0.5
	HudStyle.draw_text(self, Vector2(0.0, baseline), text, size_px, color, 12,
			HORIZONTAL_ALIGNMENT_CENTER, size.x)
