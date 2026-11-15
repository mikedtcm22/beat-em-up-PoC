class_name BossHealthBar
extends Control
## Bottom-center comic health bar for a boss (Spec §5), hidden until show_boss() is called
## (Milestone 5). Reads the boss's health every frame; hides itself if the boss is freed.
## Driven by GameHud.advance().

## Horizontal shear of the bar (pixels of shift per pixel of height).
@export var slant: float = 0.22
@export var border: float = 5.0

var boss: CombatActor
var gauge := HealthGauge.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Show the bar for `actor`, starting from its current health (null hides the bar).
func show_boss(actor: CombatActor) -> void:
	boss = actor
	visible = actor != null
	if actor != null:
		gauge.reset(HealthGauge.ratio_of(actor))
	queue_redraw()


## Hide the bar and forget the boss.
func hide_boss() -> void:
	boss = null
	visible = false


## Follow the boss's health for `delta` seconds; hides the bar once the boss is freed.
func advance(delta: float) -> void:
	if not visible:
		return
	if boss == null or not is_instance_valid(boss):
		hide_boss()
		return
	gauge.set_target(HealthGauge.ratio_of(boss))
	gauge.advance(delta)
	queue_redraw()


func _draw() -> void:
	if boss == null or not is_instance_valid(boss):
		return
	draw_set_transform(HudStyle.corner_offset(size, Vector2(0.5, 1.0)), 0.0, HudStyle.corner_scale())
	var name_text := boss.display_name if boss.display_name != "" else String(boss.name)
	HudStyle.draw_text(self, Vector2(18.0, 28.0), name_text.to_upper(), 28, HudStyle.PAPER, 8)
	var bar := Rect2(Vector2(border + 2.0, 42.0), Vector2(size.x - border * 2.0 - 12.0, size.y - 42.0 - border - 8.0))
	HudStyle.draw_panel(self, bar, slant, HudStyle.empty_tone(), border)
	HudStyle.draw_gauge(self, bar, slant, gauge, HudStyle.BOSS, 0.0)
