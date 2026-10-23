class_name TuningPanel
extends PanelContainer
## The tuning panel (Spec §11, F1 / View): every TuningData value and every move's frame
## data, damage, knockback, hitstun, blocking and camera fields, editable live while the game
## runs, plus named presets. TuningOverlay hosts it, opens and closes it and keeps gameplay
## input out while it is up.
##
## Built from the data, not by hand: one category per TuningData @export_group (in
## declaration order) with a TuningField per exported property (Tuning.tuning_properties()),
## so new tunables show up with no UI code. "Moves" picks a move (Tuning.move_ids(), every
## .tres in game/combat/moves/) and edits its Tuning.move_properties() fields on the loaded
## resource, so a change applies on the move's next use. Every edit goes through Tuning
## (set_value(), set_move_value()), which emits `Tuning.changed`; the panel listens to it as
## well, so changes made elsewhere (the cheat menu, a preset load) show at once. Changed
## values are yellow; categories and moves holding one are marked " *". Doc comments in the
## scripts become tooltips when the script source is available.
##
## Presets: Save writes user://tuning/<name>.json, Export res://tuning/<name>.json (to
## commit; works when running from the project folder), Load reads the picked preset (the
## user's first, then the shipped ones), Reset to default restores every value and move.

const MOVES_CATEGORY := "Moves"
## Category for TuningData properties declared before any @export_group.
const GENERAL_CATEGORY := "General"
const CHANGED_MARK := " *"

@export var category_width: float = 190.0
@export var name_width: float = 236.0
@export var slider_width: float = 170.0
@export var field_width: float = 104.0
@export var font_size: int = 16
@export var title_size: int = 22

## The category shown: a TuningData group, GENERAL_CATEGORY or MOVES_CATEGORY.
var category: String = ""
## The move the Moves category edits.
var move_id: StringName = &""
## The result of the last preset action, for the player to read.
var status_label: Label
var preset_name_edit: LineEdit
var preset_picker: OptionButton
var move_picker: OptionButton

var _fields: Dictionary[StringName, TuningField] = {}
var _field_category: Dictionary[StringName, String] = {}
var _move_fields: Dictionary[StringName, TuningField] = {}
var _pages: Dictionary[String, Control] = {}
var _category_buttons: Dictionary[String, Button] = {}
var _category_order: PackedStringArray = []
var _presets: Array[Dictionary] = []
var _content: ScrollContainer


func _ready() -> void:
	_build()
	Tuning.changed.connect(_on_tuning_changed)
	refresh_presets()
	refresh_all()
	var first := "Hit feel" if _pages.has("Hit feel") else (_category_order[0] if not _category_order.is_empty() else "")
	show_category(first)


func _exit_tree() -> void:
	if Tuning.changed.is_connected(_on_tuning_changed):
		Tuning.changed.disconnect(_on_tuning_changed)


## The row of TuningData property `property`, or null.
func field(property: StringName) -> TuningField:
	return _fields.get(property)


## The Moves row of MoveData field `move_field_name`, or null.
func move_field(move_field_name: StringName) -> TuningField:
	return _move_fields.get(move_field_name)


## Category names in the order shown.
func categories() -> PackedStringArray:
	return _category_order


## Show one category's page.
func show_category(category_name: String) -> void:
	if not _pages.has(category_name):
		return
	category = category_name
	for page_name: String in _pages:
		_pages[page_name].visible = page_name == category_name
	var button: Button = _category_buttons[category_name]
	button.set_pressed_no_signal(true)
	_content.scroll_vertical = 0


## Edit move `id` on the Moves page.
func select_move(id: StringName) -> void:
	if Tuning.get_move(id) == null:
		return
	move_id = id
	for i in move_picker.item_count:
		if move_picker.get_item_metadata(i) == id:
			move_picker.select(i)
	_refresh_moves()


## Put gamepad focus on the shown category's button, so the D-pad can walk the panel.
func focus_first() -> void:
	if _category_buttons.has(category):
		_category_buttons[category].grab_focus()


## Re-read every value shown (after a preset load or reset).
func refresh_all() -> void:
	for property: StringName in _fields:
		_fields[property].show_value(Tuning.data.get(property))
	_refresh_moves()
	_refresh_markers()


## Re-list the presets in the picker (user presets, then the shipped ones).
func refresh_presets() -> void:
	var picked := preset_picker.get_item_text(preset_picker.selected) if preset_picker.selected >= 0 else ""
	_presets = Tuning.list_presets()
	preset_picker.clear()
	for preset: Dictionary in _presets:
		var label := str(preset.name) + ("  (shipped)" if preset.shipped else "")
		preset_picker.add_item(label)
		if label == picked:
			preset_picker.select(preset_picker.item_count - 1)
	preset_picker.disabled = _presets.is_empty()


## Save the current values as preset `preset_name` (user://tuning/). Reports in the status line.
func save_preset(preset_name: String) -> Error:
	var clean := Tuning.sanitize_preset_name(preset_name)
	if clean.is_empty():
		_status("Type a preset name first.")
		return ERR_INVALID_PARAMETER
	var err := Tuning.save_preset(clean)
	if err == OK:
		preset_name_edit.text = clean
		refresh_presets()
		_select_preset(clean, false)
		_status("Saved %s to %s" % [clean, ProjectSettings.globalize_path(Tuning.USER_DIR.path_join(clean + ".json"))])
	else:
		_status("Could not save %s: %s" % [clean, error_string(err)])
	return err


## Export the current values to res://tuning/<preset_name>.json. Reports in the status line.
func export_preset(preset_name: String) -> Error:
	var clean := Tuning.sanitize_preset_name(preset_name)
	if clean.is_empty():
		_status("Type a preset name first.")
		return ERR_INVALID_PARAMETER
	var err := Tuning.export_preset(clean)
	if err == OK:
		preset_name_edit.text = clean
		refresh_presets()
		_select_preset(clean, true)
		_status("Exported res://tuning/%s.json (commit it to ship it)." % clean)
	elif err == ERR_INVALID_PARAMETER:
		_status("default.json must hold the shipped defaults: export under another name.")
	else:
		_status("Could not export %s: %s (res:// is only writable from the project folder)." % [clean, error_string(err)])
	return err


## Load the preset picked in the list. Reports in the status line.
func load_picked_preset() -> Error:
	if preset_picker.selected < 0 or preset_picker.selected >= _presets.size():
		_status("No preset picked.")
		return ERR_DOES_NOT_EXIST
	var preset: Dictionary = _presets[preset_picker.selected]
	var err := Tuning.load_preset_file(str(preset.path))
	if err == OK:
		preset_name_edit.text = str(preset.name)
		var note := ""
		if not Tuning.last_warnings.is_empty():
			note = " (skipped: %s)" % ", ".join(Tuning.last_warnings)
		_status("Loaded %s%s." % [preset.name, note])
	else:
		_status("Could not load %s: %s" % [preset.name, error_string(err)])
	return err


## Every value and move back to the shipped defaults.
func reset_to_default() -> void:
	Tuning.reset_to_default()
	_status("Every value and move is back to the shipped defaults.")


## Doc comments (##) of a script's member variables by name, from its source; empty when
## the source isn't available (an exported build).
static func doc_comments(script: Script) -> Dictionary[StringName, String]:
	var out: Dictionary[StringName, String] = {}
	var pending: PackedStringArray = []
	for raw: String in script.source_code.split("\n"):
		var text := raw.strip_edges()
		if text.begins_with("##"):
			pending.append(text.trim_prefix("##").strip_edges())
			continue
		if text.contains("var ") and not raw.begins_with("\t"):
			var member := text.get_slice("var ", 1).get_slice(":", 0).get_slice("=", 0).strip_edges()
			if not pending.is_empty() and member.is_valid_ascii_identifier():
				out[StringName(member)] = " ".join(pending)
		pending.clear()
	return out


# --- Building ---------------------------------------------------------------------------


func _build() -> void:
	var font_theme := Theme.new()
	font_theme.default_font_size = font_size
	theme = font_theme
	var style := StyleBoxFlat.new()
	style.bg_color = Color(HudStyle.INK, 0.92)
	style.border_color = HudStyle.PAPER
	style.set_border_width_all(3)
	style.set_content_margin_all(14.0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_offset = Vector2(6.0, 6.0)
	style.shadow_size = 1
	add_theme_stylebox_override(&"panel", style)

	var root := VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 8)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	header.add_child(_label("TUNING", title_size, HudStyle.HEALTH, true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(_label("F1 / View or Esc closes  ·  the game keeps running", font_size - 2, HudStyle.MUTED))

	_build_presets(root)
	root.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 12)
	root.add_child(body)
	var category_scroll := ScrollContainer.new()
	category_scroll.custom_minimum_size.x = category_width
	category_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	category_scroll.follow_focus = true
	body.add_child(category_scroll)
	var category_list := VBoxContainer.new()
	category_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_scroll.add_child(category_list)
	_content = ScrollContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.follow_focus = true
	body.add_child(_content)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(pages)

	var docs := TuningPanel.doc_comments(TuningData)
	for info: Dictionary in Tuning.tuning_properties():
		var group := str(info.group) if str(info.group) != "" else GENERAL_CATEGORY
		if not _pages.has(group):
			_add_page(group, pages)
		var row := _make_field(info, Tuning.defaults().get(info.name), docs.get(StringName(info.name), ""))
		row.edited.connect(_on_field_edited)
		_pages[group].add_child(row)
		_fields[row.property] = row
		_field_category[row.property] = group
	_build_moves_page(pages)

	var buttons := ButtonGroup.new()
	for category_name: String in _category_order:
		var button := Button.new()
		button.text = category_name
		button.toggle_mode = true
		button.button_group = buttons
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.add_theme_color_override(&"font_pressed_color", HudStyle.HEALTH)
		button.add_theme_color_override(&"font_hover_pressed_color", HudStyle.HEALTH)
		button.pressed.connect(show_category.bind(category_name))
		category_list.add_child(button)
		_category_buttons[category_name] = button

	status_label = _label("", font_size - 2, HudStyle.MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.x = 200.0
	root.add_child(status_label)


func _build_presets(root: VBoxContainer) -> void:
	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override(&"separation", 8)
	root.add_child(save_row)
	preset_name_edit = LineEdit.new()
	preset_name_edit.placeholder_text = "preset name"
	preset_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_name_edit.text_submitted.connect(func(text: String) -> void: save_preset(text))
	save_row.add_child(preset_name_edit)
	save_row.add_child(_button("Save", "Save as user://tuning/<name>.json",
			func() -> void: save_preset(preset_name_edit.text)))
	save_row.add_child(_button("Export", "Write res://tuning/<name>.json, a preset to commit",
			func() -> void: export_preset(preset_name_edit.text)))

	var load_row := HBoxContainer.new()
	load_row.add_theme_constant_override(&"separation", 8)
	root.add_child(load_row)
	preset_picker = OptionButton.new()
	preset_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_picker.clip_text = true
	load_row.add_child(preset_picker)
	load_row.add_child(_button("Load", "Load the picked preset", func() -> void: load_picked_preset()))
	load_row.add_child(_button("Reset to default", "Every value and move back to the shipped defaults",
			reset_to_default))


func _build_moves_page(pages: VBoxContainer) -> void:
	var page := _add_page(MOVES_CATEGORY, pages)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 8)
	page.add_child(top)
	move_picker = OptionButton.new()
	move_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: StringName in Tuning.move_ids():
		move_picker.add_item(String(id))
		move_picker.set_item_metadata(move_picker.item_count - 1, id)
	move_picker.item_selected.connect(func(index: int) -> void: select_move(move_picker.get_item_metadata(index)))
	top.add_child(move_picker)
	top.add_child(_button("Reset move", "This move's fields back to its shipped .tres",
			func() -> void: Tuning.reset_move(move_id)))
	page.add_child(_label("Edits apply on the move's next use.", font_size - 2, HudStyle.MUTED))
	var docs := TuningPanel.doc_comments(MoveData)
	var group := ""
	for info: Dictionary in Tuning.move_properties():
		if str(info.group) != group:
			group = str(info.group)
			page.add_child(_label(group.to_upper(), font_size - 1, HudStyle.DURABILITY, true))
		var row := _make_field(info, null, docs.get(StringName(info.name), ""))
		row.edited.connect(_on_move_field_edited)
		page.add_child(row)
		_move_fields[row.property] = row
	if move_picker.item_count > 0:
		var first: StringName = move_picker.get_item_metadata(0)
		select_move(&"jab_1" if Tuning.get_move(&"jab_1") else first)


func _add_page(category_name: String, pages: VBoxContainer) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override(&"separation", 4)
	page.visible = false
	pages.add_child(page)
	if category_name != MOVES_CATEGORY:
		page.add_child(_label(category_name.to_upper(), font_size - 1, HudStyle.DURABILITY, true))
	_pages[category_name] = page
	_category_order.append(category_name)
	return page


func _make_field(info: Dictionary, default: Variant, doc: String) -> TuningField:
	var row := TuningField.new()
	row.setup(info, default, doc, name_width, slider_width, field_width)
	return row


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.label_settings = HudStyle.label_settings(size, color, bold)
	return label


func _button(text: String, tip: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.pressed.connect(action)
	return button


# --- Updates ----------------------------------------------------------------------------


func _on_field_edited(property: StringName, value: Variant) -> void:
	Tuning.set_value(property, value)


func _on_move_field_edited(property: StringName, value: Variant) -> void:
	Tuning.set_move_value(move_id, property, value)


func _on_tuning_changed(property: StringName) -> void:
	if property == &"":
		refresh_all()
	elif String(property).begins_with(Tuning.MOVE_PREFIX):
		var parts := String(property).trim_prefix(Tuning.MOVE_PREFIX).split("/")
		if parts.size() == 2 and StringName(parts[0]) == move_id and _move_fields.has(StringName(parts[1])):
			var move := Tuning.get_move(move_id)
			_move_fields[StringName(parts[1])].show_value(move.get(parts[1]))
		_refresh_markers()
	elif _fields.has(property):
		_fields[property].show_value(Tuning.data.get(property))
		_refresh_markers()


func _refresh_moves() -> void:
	var move := Tuning.get_move(move_id)
	if move == null:
		return
	for field_name: StringName in _move_fields:
		var row: TuningField = _move_fields[field_name]
		row.set_default(Tuning.shipped_move_value(move_id, field_name))
		row.show_value(move.get(field_name))


func _refresh_markers() -> void:
	var touched: Dictionary[String, bool] = {}
	for property: StringName in _fields:
		if _fields[property].is_changed():
			touched[_field_category[property]] = true
	var overrides := Tuning.move_overrides()
	if not overrides.is_empty():
		touched[MOVES_CATEGORY] = true
	for category_name: String in _category_buttons:
		_category_buttons[category_name].text = category_name + (CHANGED_MARK if touched.has(category_name) else "")
	for i in move_picker.item_count:
		var id: StringName = move_picker.get_item_metadata(i)
		move_picker.set_item_text(i, String(id) + (CHANGED_MARK if overrides.has(id) else ""))


func _select_preset(preset_name: String, shipped: bool) -> void:
	for i in _presets.size():
		if str(_presets[i].name) == preset_name and bool(_presets[i].shipped) == shipped:
			preset_picker.select(i)


func _status(text: String) -> void:
	status_label.text = text
