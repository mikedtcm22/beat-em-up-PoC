class_name PlayerHealthPanel
extends Control
## Bottom-left comic panel with the player's health (Spec §5): bold "HP" lettering, a
## slanted yellow bar with a damage ghost, the numbers, a row of weapon durability pips
## while the player holds a weapon, and the guard meter (the held block) while the player
## blocks or the guard is below full; it flashes when the guard breaks. Reads the player in
## group "player"; never writes. Driven by GameHud.advance().

## Horizontal shear of the panel (pixels of shift per pixel of height).
@export var slant: float = 0.16
## Ink border width of the panel.
@export var border: float = 6.0
## Below this health fraction the bar pulses.
@export var low_health_ratio: float = 0.25
## Seconds the guard meter flashes after a guard break.
@export var guard_break_flash_s: float = 0.8

var player: PlayerCharacter
var gauge := HealthGauge.new()
var health: float = 0.0
var max_health: float = 0.0
## Durability pips: filled = hits left on the held weapon, total = row length; 0 = no weapon.
var pips_filled: int = 0
var pips_total: int = 0
## Displayed guard meter, 0..1 of the player's max guard.
var guard_gauge := HealthGauge.new()
## The guard meter shows while the player blocks, the guard is below full, or it flashes.
var guard_shown: bool = false
## Seconds left of the guard-break flash.
var guard_flash_left: float = 0.0

var _time: float = 0.0
## Seconds left of the jolt a hit taken gives the panel (Tuning hurt_panel_jolt_s), and its size in pixels.
var _jolt_left: float = 0.0
var _jolt_px: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Track `node` as the player. With null, advance() looks in group "player" again.
func set_player(node: PlayerCharacter) -> void:
	player = node
	if player != null:
		gauge.reset(HealthGauge.ratio_of(player))
		guard_gauge.reset(PlayerHealthPanel.guard_ratio_of(player))


## CombatEvents.guard_broken for the player: flash the guard meter.
func on_guard_broken() -> void:
	guard_flash_left = guard_break_flash_s
	queue_redraw()


## Guard fraction of `actor`, safe for a zero max.
static func guard_ratio_of(actor: CombatActor) -> float:
	var top := actor.max_guard()
	return clampf(actor.guard / top, 0.0, 1.0) if top > 0.0 else 0.0


## CombatEvents.health_changed for the player: react on the same frame (flash, ghost).
func on_health_changed(new_health: float, new_max: float) -> void:
	if Tuning.data.hurt_feel_enabled and new_health < health:
		# Damage taken: the panel jolts in proportion (health still holds the previous value here).
		_jolt_px = minf((health - new_health) * Tuning.data.hurt_panel_jolt_px_per_hp, Tuning.data.hurt_panel_jolt_max_px)
		_jolt_left = Tuning.data.hurt_panel_jolt_s
	health = new_health
	max_health = new_max
	gauge.set_target(new_health / new_max if new_max > 0.0 else 0.0)
	queue_redraw()


## Find the player if needed, then read its health and weapon for this frame. Hidden
## while there is no player.
func advance(delta: float) -> void:
	_time += delta
	_jolt_left = maxf(_jolt_left - delta, 0.0)
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
	guard_gauge.set_target(PlayerHealthPanel.guard_ratio_of(player))
	guard_gauge.advance(delta)
	guard_flash_left = maxf(guard_flash_left - delta, 0.0)
	guard_shown = player.is_guarding() or guard_gauge.value < 0.999 or guard_flash_left > 0.0
	queue_redraw()


## The panel's offset now (pixels): a fast rattle that dies away over hurt_panel_jolt_s.
func jolt_offset() -> Vector2:
	if _jolt_left <= 0.0:
		return Vector2.ZERO
	var fade := _jolt_left / maxf(Tuning.data.hurt_panel_jolt_s, 0.01)
	return Vector2(sin(_time * Tuning.data.hurt_panel_jolt_rate_x), cos(_time * Tuning.data.hurt_panel_jolt_rate_y)) * _jolt_px * fade


func _draw() -> void:
	draw_set_transform(jolt_offset())
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

	if guard_shown:
		_draw_guard(Rect2(Vector2(bar.position.x - 10.0, bar.end.y + 40.0), Vector2(bar.size.x * 0.62, 14.0)),
				body.position.x + 24.0)


## The guard meter under the health bar: "GUARD" lettering at `label_x` and a thin slanted
## bar in `area`. During a guard-break flash the trough pulses red-orange.
func _draw_guard(area: Rect2, label_x: float) -> void:
	var flash := 0.0
	if guard_flash_left > 0.0:
		flash = 0.5 + 0.5 * sin(_time * TAU * 6.0)
	var label_color := HudStyle.INK.lerp(HudStyle.FINISHER_ACCENT, flash)
	HudStyle.draw_text(self, Vector2(label_x, area.end.y + 1.0), "GUARD", 17, label_color)
	var trough := HudStyle.TROUGH.lerp(HudStyle.FINISHER_ACCENT, flash)
	draw_colored_polygon(HudStyle.slanted_quad(area.grow(3.0), slant), HudStyle.INK)
	draw_colored_polygon(HudStyle.slanted_quad(area, slant), trough)
	var shift := minf(slant * area.size.y, area.size.x * 0.5)
	var length := guard_gauge.value * (area.size.x - shift)
	if length >= 0.5:
		draw_colored_polygon(PackedVector2Array([
			Vector2(area.position.x + shift, area.position.y),
			Vector2(area.position.x + shift + length, area.position.y),
			Vector2(area.position.x + length, area.end.y),
			Vector2(area.position.x, area.end.y),
		]), HudStyle.GUARD.lerp(Color.WHITE, guard_gauge.flash * 0.6))


## One slanted pip per weapon hit left (filled) or used (empty), fitted into `area`.
func _draw_pips(area: Rect2) -> void:
	var gap := 5.0
	var pip_w := minf(22.0, (area.size.x - gap * float(pips_total - 1)) / float(pips_total))
	for i: int in pips_total:
		var pip := Rect2(area.position + Vector2(float(i) * (pip_w + gap), 0.0), Vector2(pip_w, area.size.y))
		var color := HudStyle.DURABILITY if i < pips_filled else HudStyle.TROUGH
		draw_colored_polygon(HudStyle.slanted_quad(pip.grow(2.0), 0.3), HudStyle.INK)
		draw_colored_polygon(HudStyle.slanted_quad(pip, 0.3), color)
