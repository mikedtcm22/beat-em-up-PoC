class_name CombatLogOverlay
extends Control
## Combat log overlay (Spec §11): the last `max_entries` hits and whiffs as compact text on
## a semi-transparent backing, oldest at the top. Each line reads
##   f<physics frame> +<frames since the previous entry>  attacker > victim  move #<chain step>
##   <input timing>  <damage> dmg <tier> <reaction> <region>  mf<move frame> [flags]
## so combo-timing problems can be reported precisely. A hit the guard stopped shows its chip
## ("<chip> chip" instead of "<damage> dmg") and the flag BLOCKED, PERFECT or GUARD BREAK. A hit
## armor absorbed (the Bruiser's, the boss's) carries the flag ARMOR and is drawn grey.
## Fed by GameHud from CombatEvents.hit_landed, attack_started and attack_whiffed.
##
## First person (Milestone 4, grab-03): the log sits over the knee in a hold, so TOGGLE_KEY puts it
## away and brings it back (it keeps recording while hidden), and Tuning's
## combat_log_hide_while_holding (FP feel, off) hides it for as long as the player holds an enemy.

## The key that shows or hides the log, listed in the help overlay (HelpOverlay.KEY_ROWS).
const TOGGLE_KEY := KEY_L

@export var max_entries: int = 10
@export var font_size: int = 14
## A line wider than the panel is drawn smaller, down to this size, rather than clipped.
@export var min_font_size: int = 10
@export var line_height: float = 19.0
@export var padding: float = 10.0

## Oldest first. Each entry: {text: String, color: Color, frame: int, kind: StringName}.
var entries: Array[Dictionary] = []

var _last_frame: int = -1
## The log is held back while the player holds an enemy (Tuning's combat_log_hide_while_holding): it
## still records, and draws nothing.
var _held_back: bool = false
# attacker instance id -> {move: MoveData, chain_step: int, input_timing: StringName}
var _attacks: Dictionary[int, Dictionary] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(_delta: float) -> void:
	set_held_back(Tuning.data.combat_log_hide_while_holding and _player_holds())


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == TOGGLE_KEY:
		visible = not visible
		get_viewport().set_input_as_handled()


## True while the log is drawn: shown, and not held back by a hold.
func is_showing() -> bool:
	return visible and not _held_back


## True while a hold keeps the log from drawing (see the class docs).
func is_held_back() -> bool:
	return _held_back


## Hold the log back (it draws nothing and keeps recording) or let it draw again. _process() calls
## it from the tunable and the player's hold; tests call it directly.
func set_held_back(held_back: bool) -> void:
	if held_back == _held_back:
		return
	_held_back = held_back
	queue_redraw()


## CombatEvents.attack_started: remember chain step and timing for a later whiff line.
func on_attack_started(attacker: Node3D, move: MoveData, chain_step: int, input_timing: StringName) -> void:
	if not is_instance_valid(attacker):
		return
	if _attacks.size() > 32:
		for id: int in _attacks.keys():
			if not is_instance_id_valid(id):
				_attacks.erase(id)
	_attacks[attacker.get_instance_id()] = {
		move = move, chain_step = chain_step, input_timing = input_timing,
	}


## CombatEvents.hit_landed.
func add_hit(hit: HitInfo) -> void:
	if hit == null:
		return
	var frame := hit.physics_frame if hit.physics_frame > 0 else Engine.get_physics_frames()
	var flags := ""
	if hit.perfect_block:
		flags += " PERFECT"
	elif hit.guard_broken:
		flags += " BLOCKED GUARD BREAK"
	elif hit.blocked:
		flags += " BLOCKED"
	if hit.from_behind:
		flags += " BEHIND"
	if hit.is_body_impact:
		flags += " BODY"
	if hit.armor_absorbed:
		flags += " ARMOR"
	if hit.killed:
		flags += " KO"
	var text := "f%d %s  %s > %s  %s #%d %s  %s %s %s %s %s  mf%d%s" % [
		frame, _gap_text(frame),
		_actor_name(hit.attacker), _actor_name(hit.victim),
		_move_name(hit.move), hit.chain_step, hit.input_timing,
		_number_text(hit.damage), "chip" if hit.blocked else "dmg",
		CombatTypes.tier_name(hit.tier), CombatTypes.reaction_name(hit.reaction),
		CombatTypes.Region.keys()[hit.region],
		hit.move_frame, flags,
	]
	_push(text, _hit_color(hit), frame, &"hit")


## CombatEvents.attack_whiffed: chain step and timing come from the matching attack_started.
func add_whiff(attacker: Node3D, move: MoveData) -> void:
	var frame := Engine.get_physics_frames()
	var chain_text := "#? ?"
	var move_frame_text := "mf?"
	if is_instance_valid(attacker):
		var started: Dictionary = _attacks.get(attacker.get_instance_id(), {})
		if not started.is_empty() and started.get("move") == move:
			chain_text = "#%d %s" % [started.get("chain_step", 0), started.get("input_timing", &"")]
		var actor := attacker as CombatActor
		if actor != null:
			move_frame_text = "mf%d" % actor.move_frame
	var text := "f%d %s  %s  %s %s  WHIFF  %s" % [
		frame, _gap_text(frame), _actor_name(attacker), _move_name(move), chain_text, move_frame_text,
	]
	_push(text, HudStyle.MUTED, frame, &"whiff")


## Drop every entry and the remembered attacks.
func clear() -> void:
	entries.clear()
	_attacks.clear()
	_last_frame = -1
	queue_redraw()


## Entries currently shown (at most max_entries).
func entry_count() -> int:
	return entries.size()


## Entry texts, oldest first.
func get_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for entry: Dictionary in entries:
		var text: String = entry.get("text", "")
		lines.append(text)
	return lines


func _push(text: String, color: Color, frame: int, kind: StringName) -> void:
	entries.append({text = text, color = color, frame = frame, kind = kind})
	while entries.size() > maxi(max_entries, 1):
		entries.remove_at(0)
	_last_frame = frame
	queue_redraw()


func _gap_text(frame: int) -> String:
	return "+--" if _last_frame < 0 else "+%d" % (frame - _last_frame)


func _hit_color(hit: HitInfo) -> Color:
	if hit.perfect_block:
		return HudStyle.PARRY
	if hit.guard_broken:
		return HudStyle.FINISHER_ACCENT
	if hit.blocked:
		return HudStyle.GUARD
	if hit.armor_absorbed:
		return HudStyle.MUTED
	return _tier_color(hit.tier)


## The player holds an enemy right now (a grab, or a knee that has not let go): read from the
## player, never written.
func _player_holds() -> bool:
	if not is_inside_tree():
		return false
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	if player == null:
		return false
	var held := player.holding_enemy()
	return held != null and player.is_holding(held)


func _tier_color(tier: CombatTypes.HitTier) -> Color:
	match tier:
		CombatTypes.HitTier.HEAVY:
			return HudStyle.HEALTH
		CombatTypes.HitTier.FINISHER:
			return HudStyle.FINISHER_ACCENT
	return Color(0.93, 0.93, 0.93)


static func _actor_name(node: Node3D) -> String:
	if not is_instance_valid(node):
		return "?"
	var actor := node as CombatActor
	if actor != null and actor.display_name != "":
		return actor.display_name
	return String(node.name)


## 6.0 -> "6", 2.5 -> "2.5".
static func _number_text(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % roundi(value)
	return String.num(value, 1)


static func _move_name(move: MoveData) -> String:
	if move == null:
		return "body"
	if move.display_name != "":
		return move.display_name
	return String(move.id)


func _draw() -> void:
	if _held_back:
		return
	var font := HudStyle.regular_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(HudStyle.INK, 0.62))
	draw_rect(Rect2(Vector2.ZERO, size), Color(HudStyle.PAPER, 0.25), false, 2.0)
	var ascent := font.get_ascent(font_size)
	var y := padding
	HudStyle.draw_text(self, Vector2(padding, y + ascent), "COMBAT LOG", font_size, HudStyle.HEALTH)
	draw_string(font, Vector2(padding + 110.0, y + ascent),
			"f = physics frame   +gap   #chain step + input timing   mf = move frame",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size - 3, HudStyle.MUTED)
	y += line_height + 4.0
	for i: int in entries.size():
		var entry := entries[i]
		if i == entries.size() - 1:
			draw_rect(Rect2(Vector2(padding * 0.5, y), Vector2(size.x - padding, line_height)), Color(HudStyle.PAPER, 0.12))
		var color: Color = entry.get("color", Color.WHITE)
		var text: String = entry.get("text", "")
		var line_size := fit_font_size(font, text, size.x - padding * 2.0)
		draw_string(font, Vector2(padding, y + ascent + 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, line_size, color)
		y += line_height


## The largest font size from font_size down to min_font_size at which `text` fits `width`.
func fit_font_size(font: Font, text: String, width: float) -> int:
	var fitted := font_size
	while fitted > min_font_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted).x > width:
		fitted -= 1
	return fitted
