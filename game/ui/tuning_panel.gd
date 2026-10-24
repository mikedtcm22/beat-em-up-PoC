class_name TuningPanel
extends PanelContainer
## The tuning panel (Spec §11, F1 / View): every TuningData value and every move's frame
## data, damage, knockback, hitstun, blocking and camera fields, editable live while the game
## runs, plus named presets. TuningOverlay hosts it, opens and closes it and keeps gameplay
## input out while it is up.
##
## Built from the data, not by hand: one category per TuningData @export_group (in
## declaration order) with a TuningField per exported property (Tuning.tuning_properties()),
## under a heading per @export_subgroup, so new tunables show up with no UI code. "Moves"
## picks a move (Tuning.move_ids(), every .tres in game/combat/moves/; the picker stays above
## the scrolling rows) and edits its Tuning.move_properties() fields on the loaded resource,
## so a change applies on the move's next use. Every edit goes through Tuning (set_value(),
## set_move_value()), which emits `Tuning.changed`; the panel listens to it as well, so
## changes made elsewhere (the cheat menu, a preset load) show at once. Changed values are
## yellow; categories and moves holding one are marked " *". Doc comments in the scripts
## become tooltips when the script source is available.
##
## Gamepad: focusing a category button shows its page; D-pad right enters the page's first
## row, up and down walk its rows (sliders, toggles, drop-downs), left (from anything but a
## slider, where left steps) goes back to the category. LB / RB switch category from
## anywhere in the panel. A presses (TuningOverlay maps it to ui_accept).
##
## Presets: Save writes user://tuning/<name>.json, Export res://tuning/<name>.json (to
## commit; works when running from the project folder), Load reads the picked preset (the
## user's first, then the shipped ones), Reset to default restores every value and move. A
## Load or Reset first keeps unsaved values as the user preset "_backup"
## (Tuning.backup_unsaved()), so loading that undoes it.

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
var _field_category: Dictionary[String, String] = {}
var _category_fields: Dictionary[String, Array] = {}
var _move_fields: Dictionary[StringName, TuningField] = {}
var _pages: Dictionary[String, Control] = {}
## Category -> the gamepad-focusable controls of its page, top to bottom.
var _page_focus: Dictionary[String, Array] = {}
## Category -> the subgroup headings on its page, in order.
var _headings: Dictionary[String, PackedStringArray] = {}
var _category_buttons: Dictionary[String, Button] = {}
var _category_order: PackedStringArray = []
## Move ids with fields away from their shipped .tres (the " *" on the picker and "Moves").
var _overridden: Dictionary[StringName, bool] = {}
var _presets: Array[Dictionary] = []
var _content: ScrollContainer
## The Moves page's picker row, above the scrolling rows (shown only for Moves).
var _moves_header: Control
var _reset_move_button: Button
var _load_button: Button
var _reset_button: Button


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


## Show one category's page (its button pressed, the others released).
func show_category(category_name: String) -> void:
	if not _pages.has(category_name):
		return
	if category_name != category:
		_content.scroll_vertical = 0
	category = category_name
	for page_name: String in _pages:
		_pages[page_name].visible = page_name == category_name
	_moves_header.visible = category_name == MOVES_CATEGORY
	var button: Button = _category_buttons[category_name]
	if not button.button_pressed:
		# Through the ButtonGroup (unlike set_pressed_no_signal()), so the last one is released.
		button.button_pressed = true
	# Down from the preset rows: the picker to the category list, Load and Reset into the page.
	_link(preset_picker, SIDE_BOTTOM, button)
	var first := first_focus(category_name)
	for preset_button: Button in [_load_button, _reset_button]:
		_link(preset_button, SIDE_BOTTOM, first if first else button)


## Show the category `offset` places from the shown one (wrapping), and focus its first row
## if a row had focus, else its button (LB / RB on the gamepad).
func cycle_category(offset: int) -> void:
	if _category_order.is_empty():
		return
	var index := (_category_order.find(category) + offset + _category_order.size()) % _category_order.size()
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var in_page := focused != null and (_content.is_ancestor_of(focused) or _moves_header.is_ancestor_of(focused))
	show_category(_category_order[index])
	var target: Control = first_focus(category) if in_page else null
	(target if target else _category_buttons[category]).grab_focus()


## The first gamepad-focusable control on a category's page (D-pad right from its button),
## or null.
func first_focus(category_name: String) -> Control:
	var controls: Array = _page_focus.get(category_name, [])
	return controls[0] if not controls.is_empty() else null


## The gamepad-focusable controls of a category's page, top to bottom (what the D-pad walks).
func focus_chain(category_name: String) -> Array[Control]:
	var out: Array[Control] = []
	out.assign(_page_focus.get(category_name, []))
	return out


## The @export_subgroup headings shown on a category's page, in order.
func headings(category_name: String) -> PackedStringArray:
	return _headings.get(category_name, PackedStringArray())


## The category list's button for `category_name`, or null.
func category_button(category_name: String) -> Button:
	return _category_buttons.get(category_name)


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
		_status("Saved %s to %s" % [clean, ProjectSettings.globalize_path(Tuning.user_dir.path_join(clean + ".json"))])
	elif err == ERR_ALREADY_IN_USE:
		_status("\"%s\" is reserved (the shipped defaults or the automatic backup): pick another name." % clean)
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


## Load the preset picked in the list, after keeping unsaved values as "_backup". Reports in
## the status line.
func load_picked_preset() -> Error:
	if preset_picker.selected < 0 or preset_picker.selected >= _presets.size():
		_status("No preset picked.")
		return ERR_DOES_NOT_EXIST
	var preset: Dictionary = _presets[preset_picker.selected]
	# Read before the backup is written: the picked preset may be the backup itself.
	var contents := Tuning.read_preset_file(str(preset.path))
	if contents.is_empty():
		_status("Could not read %s." % preset.name)
		return ERR_PARSE_ERROR
	var kept := Tuning.backup_unsaved()
	var err := Tuning.apply_preset(contents)
	if err == OK:
		preset_name_edit.text = "" if str(preset.name) == Tuning.BACKUP_PRESET else str(preset.name)
		var note := ""
		if not Tuning.last_warnings.is_empty():
			note = " (%s)" % ", ".join(Tuning.last_warnings)
		_status("Loaded %s%s.%s" % [preset.name, note, _backup_note(kept)])
	else:
		_status("Could not load %s: %s" % [preset.name, error_string(err)])
	refresh_presets()
	return err


## Every value and move back to the shipped defaults (the cheats stay), after keeping unsaved
## values as "_backup".
func reset_to_default() -> void:
	var kept := Tuning.backup_unsaved()
	Tuning.reset_to_default()
	refresh_presets()
	_status("Every value and move is back to the shipped defaults.%s" % _backup_note(kept))


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
	style.bg_color = Color(HudStyle.INK, 0.95)
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
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 6)
	body.add_child(right)
	_moves_header = VBoxContainer.new()
	_moves_header.visible = false
	right.add_child(_moves_header)
	_content = ScrollContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.follow_focus = true
	right.add_child(_content)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(pages)

	var docs := TuningPanel.doc_comments(TuningData)
	var subgroups: Dictionary[String, String] = {}
	for info: Dictionary in Tuning.tuning_properties():
		var group := str(info.group) if str(info.group) != "" else GENERAL_CATEGORY
		if not _pages.has(group):
			_add_page(group, pages)
		var subgroup := str(info.get("subgroup", ""))
		if subgroup != subgroups.get(group, ""):
			subgroups[group] = subgroup
			if subgroup != "":
				_pages[group].add_child(_heading(subgroup))
				_headings[group].append(subgroup)
		var row := _make_field(info, Tuning.defaults().get(info.name), docs.get(StringName(info.name), ""))
		row.edited.connect(_on_field_edited)
		_pages[group].add_child(row)
		_fields[row.property] = row
		_field_category[String(row.property)] = group
		_category_fields[group].append(row.property)
		if row.focus_control:
			_page_focus[group].append(row.focus_control)
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
		# The D-pad browsing the list shows each page as it passes.
		button.focus_entered.connect(show_category.bind(category_name))
		category_list.add_child(button)
		_category_buttons[category_name] = button
	_link_focus()

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
	_load_button = _button("Load", "Load the picked preset (unsaved values are kept as _backup)",
			func() -> void: load_picked_preset())
	load_row.add_child(_load_button)
	_reset_button = _button("Reset to default",
			"Every value and move back to the shipped defaults (unsaved values are kept as _backup)", reset_to_default)
	load_row.add_child(_reset_button)


func _build_moves_page(pages: VBoxContainer) -> void:
	var page := _add_page(MOVES_CATEGORY, pages)
	# The picker row sits above the scrolling rows, so it stays in view.
	_moves_header.add_child(_label(MOVES_CATEGORY.to_upper(), font_size - 1, HudStyle.DURABILITY, true))
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 8)
	_moves_header.add_child(top)
	move_picker = OptionButton.new()
	move_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: StringName in Tuning.move_ids():
		move_picker.add_item(String(id))
		move_picker.set_item_metadata(move_picker.item_count - 1, id)
	move_picker.item_selected.connect(func(index: int) -> void: select_move(move_picker.get_item_metadata(index)))
	top.add_child(move_picker)
	_reset_move_button = _button("Reset move", "This move's fields back to its shipped .tres",
			func() -> void: Tuning.reset_move(move_id))
	top.add_child(_reset_move_button)
	_moves_header.add_child(_label("Edits apply on the move's next use.", font_size - 2, HudStyle.MUTED))
	_page_focus[MOVES_CATEGORY].append(move_picker)
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
		if row.focus_control:
			_page_focus[MOVES_CATEGORY].append(row.focus_control)
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
	_category_fields[category_name] = []
	_page_focus[category_name] = []
	_headings[category_name] = PackedStringArray()
	return page


## An @export_subgroup heading inside a page.
func _heading(text: String) -> Control:
	var box := MarginContainer.new()
	box.add_theme_constant_override(&"margin_top", 6)
	box.add_child(_label("— %s" % text, font_size - 1, HudStyle.PAPER, true))
	return box


## Explicit gamepad focus links, so the D-pad never depends on where rows happen to line up:
## the category buttons chain up and down (the first up to the preset list) and go right to
## their page's first row; a page's rows chain up and down (the first up to Load, the last
## staying put) and go left to their category button.
func _link_focus() -> void:
	for i in _category_order.size():
		var button := _category_buttons[_category_order[i]]
		_link(button, SIDE_TOP, _category_buttons[_category_order[i - 1]] if i > 0 else preset_picker)
		_link(button, SIDE_BOTTOM, _category_buttons[_category_order[i + 1]] if i + 1 < _category_order.size() else button)
		_link(button, SIDE_LEFT, button)
	for category_name: String in _category_order:
		var button := _category_buttons[category_name]
		var controls: Array = _page_focus[category_name]
		if controls.is_empty():
			_link(button, SIDE_RIGHT, button)
			continue
		_link(button, SIDE_RIGHT, controls[0])
		for i in controls.size():
			var control: Control = controls[i]
			_link(control, SIDE_LEFT, button)
			_link(control, SIDE_TOP, controls[i - 1] if i > 0 else _load_button)
			_link(control, SIDE_BOTTOM, controls[i + 1] if i + 1 < controls.size() else control)
	# The Moves header: Reset move sits right of the picker.
	_link(move_picker, SIDE_RIGHT, _reset_move_button)
	_link(_reset_move_button, SIDE_LEFT, move_picker)
	_link(_reset_move_button, SIDE_TOP, _load_button)
	var moves: Array = _page_focus[MOVES_CATEGORY]
	_link(_reset_move_button, SIDE_BOTTOM, moves[1] if moves.size() > 1 else move_picker)


static func _link(from: Control, side: Side, to: Control) -> void:
	if from and to:
		from.set_focus_neighbor(side, from.get_path_to(to))

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


func _backup_note(kept: bool) -> String:
	return "  Unsaved values kept as %s." % Tuning.BACKUP_PRESET if kept else ""


# --- Updates ----------------------------------------------------------------------------


func _on_field_edited(property: StringName, value: Variant) -> void:
	Tuning.set_value(property, value)


func _on_move_field_edited(property: StringName, value: Variant) -> void:
	Tuning.set_move_value(move_id, property, value)


func _unhandled_input(event: InputEvent) -> void:
	# LB / RB switch category while the focus is in the panel (key and button events go to
	# the focused control only, so the panel sees them once that control has passed).
	var button := event as InputEventJoypadButton
	if button == null or not button.pressed or not is_visible_in_tree():
		return
	var offset := -1 if button.button_index == JOY_BUTTON_LEFT_SHOULDER else (1 if button.button_index == JOY_BUTTON_RIGHT_SHOULDER else 0)
	var focused := get_viewport().gui_get_focus_owner()
	if offset != 0 and focused and is_ancestor_of(focused):
		cycle_category(offset)
		get_viewport().set_input_as_handled()


func _on_tuning_changed(property: StringName) -> void:
	if property == &"":
		refresh_all()
	elif String(property).begins_with(Tuning.MOVE_PREFIX):
		var parts := String(property).trim_prefix(Tuning.MOVE_PREFIX).split("/")
		if parts.size() == 2 and StringName(parts[0]) == move_id and _move_fields.has(StringName(parts[1])):
			var move := Tuning.get_move(move_id)
			_move_fields[StringName(parts[1])].show_value(move.get(parts[1]))
		if parts.size() >= 1:
			_refresh_move_marker(StringName(parts[0]))
			_refresh_category_marker(MOVES_CATEGORY)
	elif _fields.has(property):
		_fields[property].show_value(Tuning.data.get(property))
		_refresh_category_marker(_field_category[String(property)])


func _refresh_moves() -> void:
	var move := Tuning.get_move(move_id)
	if move == null:
		return
	for field_name: StringName in _move_fields:
		var row: TuningField = _move_fields[field_name]
		row.set_default(Tuning.shipped_move_value(move_id, field_name))
		row.show_value(move.get(field_name))


## Every marker: each category's " *" and each move's in the picker.
func _refresh_markers() -> void:
	for i in move_picker.item_count:
		_refresh_move_marker(move_picker.get_item_metadata(i))
	for category_name: String in _category_order:
		_refresh_category_marker(category_name)


## The " *" of one category: a row of it away from its default (for Moves, any move override).
func _refresh_category_marker(category_name: String) -> void:
	var button: Button = _category_buttons.get(category_name)
	if button == null:
		return
	var touched := not _overridden.is_empty() if category_name == MOVES_CATEGORY else false
	for property: StringName in _category_fields.get(category_name, []):
		if _fields[property].is_changed():
			touched = true
			break
	var text := category_name + (CHANGED_MARK if touched else "")
	if button.text != text:
		button.text = text


## The " *" of one move in the picker (Tuning.move_override()).
func _refresh_move_marker(id: StringName) -> void:
	if Tuning.move_override(id).is_empty():
		_overridden.erase(id)
	else:
		_overridden[id] = true
	for i in move_picker.item_count:
		if move_picker.get_item_metadata(i) == id:
			var text := String(id) + (CHANGED_MARK if _overridden.has(id) else "")
			if move_picker.get_item_text(i) != text:
				move_picker.set_item_text(i, text)


func _select_preset(preset_name: String, shipped: bool) -> void:
	for i in _presets.size():
		if str(_presets[i].name) == preset_name and bool(_presets[i].shipped) == shipped:
			preset_picker.select(i)


func _status(text: String) -> void:
	status_label.text = text
