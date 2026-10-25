class_name HelpOverlay
extends PanelContainer
## Help overlay (H): the Spec §4 controls table for gamepad and keyboard + mouse, the debug
## keys and the combo inputs. Key and button names come from GameInput.BINDINGS, so the
## table follows the real input map. GameHud shows it for the first seconds after start,
## then H toggles it.

const GameInputScript := preload("res://game/autoload/game_input.gd")

## [label, actions] in the order of the Spec §4 controls table. An optional third entry is
## the keyboard + mouse text for actions with no key binding (mouse look).
const CONTROL_ROWS: Array[Array] = [
	["Move", [&"move_forward", &"move_left", &"move_back", &"move_right"]],
	["Look", [&"look_left", &"look_right", &"look_up", &"look_down"], "Mouse"],
	["Punch", [&"punch"]],
	["Kick", [&"kick"]],
	["Jump", [&"jump"]],
	["Block (hold, no direction)", [&"dodge"]],
	["Dodge (with a direction)", [&"dodge"]],
	["Back attack", [&"back_attack"]],
	["Grab / pick up / throw weapon", [&"grab"]],
	["Quick turn (180°)", [&"quick_turn"]],
	["Pause", [&"pause"]],
	["Tuning panel", [&"tuning_panel"]],
]

## [label, action] debug keys (keyboard).
const DEBUG_ROWS: Array[Array] = [
	["Tuning panel", &"tuning_panel"],
	["Cycle camera", &"camera_cycle"],
	["Debug draw", &"debug_draw"],
	["Cheats", &"cheats"],
	["Sparring dummies on / off", &"sparring"],
	["Switch room: crowd street / training", &"switch_room"],
	["Help", &"help"],
	["Pause", &"pause"],
	["Restart (while paused)", &"restart"],
]

## [inputs, result] (Spec §4 combos). "·" is the pause branch.
const COMBO_ROWS: Array[Array] = [
	["P P P P", "Jab, jab, hook, uppercut"],
	["P P · P (mash P)", "Jab, jab, body-blow flurry, shove"],
	["K K K", "Front kick, roundhouse, spin heel"],
	["K · K", "Front kick, stomp kick"],
	["P P K", "Jab, jab, push kick"],
	["Hold P, release", "Haymaker"],
	["Jump, K", "Flying kick"],
	["Jump, K at peak", "Spin kick (all around)"],
	["Grab, then P / K", "Knee (x3) / throw"],
	["Block just in time", "Parry: the attacker staggers, grab it"],
]

const PAD_BUTTONS: Dictionary[int, String] = {
	0: "A", 1: "B", 2: "X", 3: "Y", 4: "View", 6: "Menu", 7: "L-stick click",
	8: "R-stick click", 9: "LB", 10: "RB", 11: "D-pad up", 12: "D-pad down",
	13: "D-pad left", 14: "D-pad right",
}
const MOUSE_BUTTONS: Dictionary[int, String] = {1: "Left mouse", 2: "Right mouse", 3: "Middle mouse"}

@export var title_size: int = 21
@export var row_size: int = 15


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


## Show or hide the overlay. GameHud.toggle_help() also cancels the startup auto-hide.
func toggle() -> void:
	visible = not visible


## Display names of every binding of `actions` for one device, without duplicates.
static func binding_names(actions: Array, gamepad: bool) -> PackedStringArray:
	var names := PackedStringArray()
	for action: StringName in actions:
		var bindings: Array = GameInputScript.BINDINGS.get(action, [])
		for binding: Variant in bindings:
			var label := HelpOverlay._binding_label(binding, gamepad)
			if label != "" and not names.has(label):
				names.append(label)
	return names


## Text for one table cell, e.g. "W A S D", "Left mouse", "Right stick"; "-" if unbound.
static func binding_text(actions: Array, gamepad: bool) -> String:
	var names := HelpOverlay.binding_names(actions, gamepad)
	if names.is_empty():
		return "-"
	var all_single := true
	for label: String in names:
		if label.length() > 1:
			all_single = false
	return " ".join(names) if all_single else " / ".join(names)


static func _binding_label(binding: Variant, gamepad: bool) -> String:
	if binding is int:
		if gamepad:
			return ""
		var keycode: int = binding
		return "Esc" if keycode == KEY_ESCAPE else OS.get_keycode_string(keycode as Key)
	var parts := str(binding).split(":")
	match parts[0]:
		"mb":
			return "" if gamepad else str(MOUSE_BUTTONS.get(int(parts[1]), "Mouse " + parts[1]))
		"jb":
			return str(PAD_BUTTONS.get(int(parts[1]), "Button " + parts[1])) if gamepad else ""
		"ja":
			if not gamepad:
				return ""
			var axis := int(parts[1])
			if axis <= 1:
				return "Left stick"
			if axis <= 3:
				return "Right stick"
			return "LT" if axis == 4 else "RT"
	return ""


func _build() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(HudStyle.INK, 0.88)
	style.border_color = HudStyle.PAPER
	style.set_border_width_all(4)
	style.skew = Vector2(0.03, 0.0)
	style.set_content_margin_all(20.0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_offset = Vector2(8.0, 8.0)
	style.shadow_size = 1
	add_theme_stylebox_override(&"panel", style)

	var title := HudStyle.label_settings(title_size, HudStyle.HEALTH, true, 6)
	var header := HudStyle.label_settings(row_size - 2, HudStyle.MUTED, true)
	var key := HudStyle.label_settings(row_size, HudStyle.PAPER, true)
	var body := HudStyle.label_settings(row_size, Color(0.88, 0.88, 0.9))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 32)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(columns)

	var left := _column(columns)
	left.add_child(_label("CONTROLS", title))
	var controls := _grid(left, 3)
	for text: String in ["", "GAMEPAD", "KEYBOARD + MOUSE"]:
		controls.add_child(_label(text, header))
	for row: Array in CONTROL_ROWS:
		var actions: Array = row[1]
		controls.add_child(_label(str(row[0]), key))
		var keyboard := HelpOverlay.binding_text(actions, false)
		if row.size() > 2 and keyboard == "-":
			keyboard = str(row[2])
		controls.add_child(_label(HelpOverlay.binding_text(actions, true), body))
		controls.add_child(_label(keyboard, body))
	left.add_child(_label("H shows or hides this help", header))

	var right := _column(columns)
	right.add_child(_label("DEBUG KEYS", title))
	var debug_keys := _grid(right, 2)
	for row: Array in DEBUG_ROWS:
		debug_keys.add_child(_label(HelpOverlay.binding_text([row[1]], false), key))
		debug_keys.add_child(_label(str(row[0]), body))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 14.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(spacer)
	right.add_child(_label("COMBOS   (· = short pause)", title))
	var combos := _grid(right, 2)
	for row: Array in COMBO_ROWS:
		combos.add_child(_label(str(row[0]), key))
		combos.add_child(_label(str(row[1]), body))


func _column(parent: Control) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(column)
	return column


func _grid(parent: Control, column_count: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = column_count
	grid.add_theme_constant_override(&"h_separation", 16)
	grid.add_theme_constant_override(&"v_separation", 3)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(grid)
	return grid


func _label(text: String, settings: LabelSettings) -> Label:
	var label := Label.new()
	label.text = text
	label.label_settings = settings
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
