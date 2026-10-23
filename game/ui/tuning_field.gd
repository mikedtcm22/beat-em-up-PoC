class_name TuningField
extends HBoxContainer
## One row of the tuning panel (TuningPanel): a property's name and an editor that fits its
## property-list entry, so any exported value gets a control without UI code:
## - a number with a range hint: a slider and a number field (the slider takes gamepad
##   focus; the field is for the mouse and keyboard and allows the hint's or_greater/or_less);
## - a number without one: a number field; a bool: a toggle; an enum: a drop-down;
## - a Vector2 or Vector3: a number field per axis; a Color: a color button;
## - a String or StringName: a text field; anything else: the value, read-only.
## The name turns yellow and "reset" lights up while the value differs from `default_value`.
## `edited` reports the user's changes; show_value() never emits it.

signal edited(property: StringName, value: Variant)

## Number fields for values without a range hint reach this far either way (and beyond).
const OPEN_RANGE := 10000.0
## Step for float fields without a hint (and vector axes).
const OPEN_STEP := 0.01
const AXIS_NAMES: PackedStringArray = ["x", "y", "z"]

var property: StringName = &""
var type: int = TYPE_NIL
## The value "reset" restores, and what the changed marker compares against.
var default_value: Variant
## The editor a gamepad focuses (slider, toggle, drop-down, color, text), or null: number
## fields take the mouse and keyboard only, since a gamepad's up/down would step them
## instead of moving to the next row.
var focus_control: Control
## Which editor the row has: &"range", &"number", &"bool", &"enum", &"vector", &"color",
## &"text" or &"none".
var kind: StringName = &"none"

var name_label: Label
var slider: HSlider
var spin: SpinBox
var check: CheckButton
var option: OptionButton
var axes: Array[SpinBox] = []
var color_button: ColorPickerButton
var line: LineEdit
var value_label: Label
var reset_button: Button

var _value: Variant


## Build the row for the property-list entry `info` (name, type, hint, hint_string).
## `doc` (the property's doc comment) goes in the tooltip; widths are in canvas pixels.
func setup(info: Dictionary, default: Variant, doc: String, name_width: float,
		slider_width: float, field_width: float) -> void:
	property = StringName(info.name)
	type = int(info.type)
	default_value = default
	add_theme_constant_override(&"separation", 8)
	name_label = Label.new()
	name_label.text = String(property)
	name_label.custom_minimum_size.x = name_width
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(name_label)
	var hint: int = info.get("hint", PROPERTY_HINT_NONE)
	var hint_string: String = info.get("hint_string", "")
	if type == TYPE_BOOL:
		_build_bool()
	elif type == TYPE_INT and hint == PROPERTY_HINT_ENUM:
		_build_enum(hint_string)
	elif type == TYPE_INT or type == TYPE_FLOAT:
		_build_number(hint == PROPERTY_HINT_RANGE, hint_string, slider_width, field_width)
	elif type == TYPE_VECTOR2 or type == TYPE_VECTOR3:
		_build_vector(3 if type == TYPE_VECTOR3 else 2, slider_width + field_width)
	elif type == TYPE_COLOR:
		_build_color(slider_width + field_width)
	elif type == TYPE_STRING or type == TYPE_STRING_NAME:
		_build_text(slider_width + field_width)
	else:
		kind = &"none"
		value_label = Label.new()
		value_label.custom_minimum_size.x = slider_width + field_width
		add_child(value_label)
	reset_button = Button.new()
	reset_button.text = "reset"
	reset_button.flat = true
	reset_button.focus_mode = Control.FOCUS_CLICK
	reset_button.tooltip_text = "Back to the default"
	reset_button.pressed.connect(func() -> void: _commit(default_value))
	reset_button.visible = kind != &"none"
	add_child(reset_button)
	var tip := doc.strip_edges()
	tip += ("\n" if tip != "" else "") + "Default: %s" % _text(default_value)
	if hint == PROPERTY_HINT_RANGE:
		var parts := hint_string.split(",")
		if parts.size() >= 2:
			tip += "   Range: %s to %s" % [parts[0], parts[1]]
	tooltip_text = tip
	name_label.tooltip_text = tip


## Show `value` without emitting `edited`.
func show_value(value: Variant) -> void:
	_value = value
	match kind:
		&"range", &"number":
			spin.set_value_no_signal(float(value))
			if slider:
				slider.set_value_no_signal(float(value))
		&"bool":
			check.set_pressed_no_signal(bool(value))
		&"enum":
			var index := option.get_item_index(int(value))
			option.select(index)
		&"vector":
			for i in axes.size():
				var component: float = value[i]
				axes[i].set_value_no_signal(component)
		&"color":
			color_button.color = value
		&"text":
			line.text = str(value)
		_:
			value_label.text = _text(value)
	_update_marker()


## The value shown.
func current_value() -> Variant:
	return _value


## True while the value differs from `default_value`.
func is_changed() -> bool:
	return not Tuning.values_equal(_value, default_value)


## A new default (the moves page swaps it with the selected move); refreshes the marker.
func set_default(new_default: Variant) -> void:
	default_value = new_default
	_update_marker()


func _commit(new_value: Variant) -> void:
	show_value(new_value)
	edited.emit(property, new_value)


func _update_marker() -> void:
	var changed := kind != &"none" and is_changed()
	name_label.add_theme_color_override(&"font_color", HudStyle.HEALTH if changed else HudStyle.PAPER)
	if reset_button:
		reset_button.disabled = not changed


func _build_bool() -> void:
	kind = &"bool"
	check = CheckButton.new()
	check.toggled.connect(func(on: bool) -> void: _commit(on))
	add_child(check)
	focus_control = check


func _build_enum(hint_string: String) -> void:
	kind = &"enum"
	option = OptionButton.new()
	var next := 0
	for entry: String in hint_string.split(","):
		var parts := entry.split(":")
		var id := int(parts[1]) if parts.size() > 1 else next
		option.add_item(parts[0].strip_edges(), id)
		next = id + 1
	option.item_selected.connect(func(index: int) -> void: _commit(option.get_item_id(index)))
	add_child(option)
	focus_control = option


func _build_number(ranged: bool, hint_string: String, slider_width: float, field_width: float) -> void:
	var parts := hint_string.split(",")
	var is_int := type == TYPE_INT
	spin = SpinBox.new()
	spin.custom_minimum_size.x = field_width
	spin.select_all_on_focus = true
	spin.rounded = is_int
	spin.focus_mode = Control.FOCUS_CLICK
	spin.get_line_edit().focus_mode = Control.FOCUS_CLICK
	if ranged and parts.size() >= 2:
		kind = &"range"
		var step := float(parts[2]) if parts.size() >= 3 and parts[2].is_valid_float() else (1.0 if is_int else 0.001)
		slider = HSlider.new()
		slider.custom_minimum_size.x = slider_width
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.scrollable = false
		for range_control: Range in [slider, spin]:
			range_control.min_value = float(parts[0])
			range_control.max_value = float(parts[1])
			range_control.step = step
		spin.allow_greater = parts.has("or_greater")
		spin.allow_lesser = parts.has("or_less")
		slider.value_changed.connect(_on_number.bind(slider))
		add_child(slider)
		focus_control = slider
	else:
		kind = &"number"
		spin.custom_minimum_size.x = slider_width + field_width
		_open_range(spin, 1.0 if is_int else OPEN_STEP)
	spin.value_changed.connect(_on_number.bind(spin))
	add_child(spin)


func _build_vector(count: int, width: float) -> void:
	kind = &"vector"
	for i in count:
		var axis := SpinBox.new()
		axis.custom_minimum_size.x = (width - 8.0 * (count - 1)) / count
		axis.select_all_on_focus = true
		axis.prefix = AXIS_NAMES[i]
		axis.focus_mode = Control.FOCUS_CLICK
		axis.get_line_edit().focus_mode = Control.FOCUS_CLICK
		_open_range(axis, OPEN_STEP)
		axis.value_changed.connect(_on_axis)
		axes.append(axis)
		add_child(axis)


func _build_color(width: float) -> void:
	kind = &"color"
	color_button = ColorPickerButton.new()
	color_button.custom_minimum_size = Vector2(width, 28.0)
	color_button.color_changed.connect(func(c: Color) -> void: _commit(c))
	add_child(color_button)
	focus_control = color_button


func _build_text(width: float) -> void:
	kind = &"text"
	line = LineEdit.new()
	line.custom_minimum_size.x = width
	line.text_submitted.connect(func(_t: String) -> void: _commit_text())
	line.focus_exited.connect(_commit_text)
	add_child(line)
	focus_control = line


func _open_range(box: SpinBox, step: float) -> void:
	box.min_value = -OPEN_RANGE
	box.max_value = OPEN_RANGE
	box.allow_greater = true
	box.allow_lesser = true
	box.step = step


func _on_number(number: float, source: Range) -> void:
	if source == slider:
		spin.set_value_no_signal(number)
	elif slider:
		slider.set_value_no_signal(number)
	_commit(roundi(number) if type == TYPE_INT else number)


func _on_axis(_number: float) -> void:
	if type == TYPE_VECTOR3:
		_commit(Vector3(axes[0].value, axes[1].value, axes[2].value))
	else:
		_commit(Vector2(axes[0].value, axes[1].value))


func _commit_text() -> void:
	var text := line.text
	if str(_value) == text:
		return
	_commit(StringName(text) if type == TYPE_STRING_NAME else text)


static func _text(value: Variant) -> String:
	if value is float:
		return String.num(value, 4).trim_suffix(".0") if absf(value) < 1e6 else str(value)
	return str(value)
