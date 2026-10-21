class_name PlayerHealthPanel
extends Control
## Bottom-left comic panel with the player's health (Spec §5): bold "HP" lettering, a
## slanted yellow bar with a damage ghost, the numbers, and a row of weapon durability
## pips while the player holds a weapon. Reads the player in group "player"; never writes.
## Driven by GameHud.advance().

## Horizontal shear of the panel (pixels of shift per pixel of height).
@export var slant: float = 0.16
## Ink border width of the panel.
@export var border: float = 6.0
## Below this health fraction the bar pulses.
@export var low_health_ratio: float = 0.25

var player: PlayerCharacter
var gauge := HealthGauge.new()
var health: float = 0.0
var max_health: float = 0.0
## Durability pips: filled = hits left on the held weapon, total = row length; 0 = no weapon.
var pips_filled: int = 0
var pips_total: int = 0

var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Track `node` as the player. With null, advance() looks in group "player" again.
func set_player(node: PlayerCharacter) -> void:
	player = node
	if player != null:
		gauge.reset(HealthGauge.ratio_of(player))


## CombatEvents.health_changed for the player: react on the same frame (flash, ghost).
func on_health_changed(new_health: float, new_max: float) -> void:
	health = new_health
	max_health = new_max
	gauge.set_target(new_health / new_max if new_max > 0.0 else 0.0)
	queue_redraw()


## Find the player if needed, then read its health and weapon for this frame. Hidden
## while there is no player.
func advance(delta: float) -> void:
	_time += delta
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		player = null
		var found := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
		if found != null:
			set_player(found)
	visible = player != null
	if player == null:
		return
	health = player.health
	max_health = player.max_health
	gauge.set_target(HealthGauge.ratio_of(player))
	gauge.advance(delta)
	if player.holding_weapon():
		pips_filled = maxi(player.weapon_durability_left(), 0)
		pips_total = maxi(Tuning.data.weapon_durability, pips_filled)
	else:
		pips_filled = 0
		pips_total = 0
	queue_redraw()


func _draw() -> void:
	# Leave room for the border and the drop shadow inside our rect.
	var body := Rect2(Vector2(border + 2.0, border + 2.0), size - Vector2(border * 2.0 + 12.0, border * 2.0 + 12.0))
	HudStyle.draw_panel(self, body, slant, HudStyle.PAPER, border)

	HudStyle.draw_text(self, body.position + Vector2(24.0, 62.0), "HP", 46, HudStyle.INK)

	var bar := Rect2(body.position + Vector2(104.0, 16.0), Vector2(body.size.x - 128.0, 34.0))
	var fill := HudStyle.HEALTH
	if gauge.value <= low_health_ratio:
		fill = fill.lerp(Color.WHITE, 0.35 + 0.35 * sin(_time * TAU * 2.0))
	HudStyle.draw_gauge(self, bar, slant, gauge, fill, 4.0)

	var numbers := "%d / %d" % [ceili(health), roundi(max_health)]
	HudStyle.draw_text(self, Vector2(bar.position.x, bar.end.y + 30.0), numbers, 22, HudStyle.INK,
			0, HORIZONTAL_ALIGNMENT_RIGHT, bar.size.x - 8.0)

	if pips_total > 0:
		_draw_pips(Rect2(Vector2(bar.position.x - 6.0, bar.end.y + 14.0), Vector2(bar.size.x * 0.62, 18.0)))


## One slanted pip per weapon hit left (filled) or used (empty), fitted into `area`.
func _draw_pips(area: Rect2) -> void:
	var gap := 5.0
	var pip_w := minf(22.0, (area.size.x - gap * float(pips_total - 1)) / float(pips_total))
	for i: int in pips_total:
		var pip := Rect2(area.position + Vector2(float(i) * (pip_w + gap), 0.0), Vector2(pip_w, area.size.y))
		var color := HudStyle.DURABILITY if i < pips_filled else HudStyle.TROUGH
		draw_colored_polygon(HudStyle.slanted_quad(pip.grow(2.0), 0.3), HudStyle.INK)
		draw_colored_polygon(HudStyle.slanted_quad(pip, 0.3), color)
