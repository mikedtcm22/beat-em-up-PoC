class_name TuningOverlay
extends Node
## Hosts the F1 tuning panel (TuningPanel) and the F4 cheat menu (CheatMenu) in one
## full-screen, transparent, embedded Window over the game (Spec §11). Nothing pauses while
## either is open, but gameplay input stays out:
## - The window takes the mouse and keyboard. An embedded window's input never reaches the
##   game's _input / _unhandled_input handlers, so a click on the panel can't recapture the
##   mouse (GameInput) and keys typed into a field don't reach the debug keys.
## - The game's own bindings (GameInput.BINDINGS, all but F1 / View and F4) are lifted out of
##   the InputMap while open and put back on closing, so code that polls the Input singleton
##   (the free-fly camera's arrow and Page keys) doesn't move while the panel uses those keys.
## - The player stands still: its live PlayerInput is switched to scripted (idle frames, no
##   look) and back UNFREEZE_TICKS physics ticks after closing, so the key or button that
##   closed it (gamepad B is also the dodge) never reaches the player. A scripted player (the
##   combo bot, tests) is left alone.
## - The mouse is released, and captured again on closing unless the game is paused.
## F1 / View toggles the panel and F4 the cheat menu, from the game or from the window; Esc
## (ui_cancel, also gamepad B) closes both. Gamepad: the D-pad walks the controls (focus
## navigation), A presses (ui_accept), LB / RB switch the panel's category. Godot's default
## ui_accept and ui_cancel have no joypad buttons, so the overlay adds A and B to them.
## The test room adds one (TestRoom._build_presentation()).

## Physics ticks after closing before the player takes input again.
const UNFREEZE_TICKS := 2
## GameInput actions that keep their bindings while open: the overlay's own toggles.
const KEPT_ACTIONS: Array[StringName] = [&"tuning_panel", &"cheats"]
## Joypad buttons the overlay adds to Godot's UI actions (absent from its defaults).
const GAMEPAD_UI := {&"ui_accept": JOY_BUTTON_A, &"ui_cancel": JOY_BUTTON_B}

## Canvas pixels between the menus and the screen edges.
@export var margin: float = 24.0
@export var panel_width: float = 790.0
## The tuning panel stops this far above the bottom, clear of the player's health panel.
@export var panel_bottom_margin: float = 190.0
@export var cheat_width: float = 470.0

var window: Window
var panel: TuningPanel
var cheats: CheatMenu

## The live player input switched to scripted while open (null = none).
var _frozen_input: PlayerInput
var _unfreeze_left: int = 0
## Action -> its InputMap events, lifted out while open (empty while closed).
var _lifted: Dictionary[StringName, Array] = {}


## Hands the window's unused key and button presses to the overlay.
class _Relay:
	extends Node
	var overlay: TuningOverlay

	func _unhandled_input(event: InputEvent) -> void:
		if overlay.handle_toggle_event(event):
			get_viewport().set_input_as_handled()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_gamepad_ui_events()
	window = Window.new()
	window.name = "TuningWindow"
	window.visible = false
	window.borderless = true
	window.transparent = true
	window.transparent_bg = true
	window.unresizable = true
	add_child(window)
	panel = TuningPanel.new()
	panel.name = "TuningPanel"
	panel.visible = false
	panel.anchor_bottom = 1.0
	panel.offset_left = margin
	panel.offset_top = margin
	panel.offset_right = margin + panel_width
	panel.offset_bottom = -panel_bottom_margin
	window.add_child(panel)
	cheats = CheatMenu.new()
	cheats.name = "CheatMenu"
	cheats.visible = false
	cheats.world = get_parent() as Node3D
	cheats.anchor_left = 1.0
	cheats.anchor_right = 1.0
	cheats.offset_left = -margin - cheat_width
	cheats.offset_right = -margin
	cheats.offset_top = margin
	cheats.offset_bottom = margin
	window.add_child(cheats)
	var relay := _Relay.new()
	relay.overlay = self
	window.add_child(relay)
	get_tree().root.size_changed.connect(_fit_window)
	_fit_window()


func _exit_tree() -> void:
	if get_tree().root.size_changed.is_connected(_fit_window):
		get_tree().root.size_changed.disconnect(_fit_window)
	_unfreeze_player(true)
	_restore_bindings()
	GameInput.menu_open = false


## Add gamepad A to ui_accept and B to ui_cancel where they are missing (GAMEPAD_UI), so the
## pad can press buttons, flip toggles, open drop-downs and close the menus.
static func add_gamepad_ui_events() -> void:
	for action: StringName in GAMEPAD_UI:
		if not InputMap.has_action(action):
			continue
		var event := InputEventJoypadButton.new()
		event.button_index = GAMEPAD_UI[action]
		event.device = -1  # every pad, like Godot's own ui_* joypad events
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if handle_toggle_event(event):
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if _unfreeze_left > 0:
		_unfreeze_left -= 1
		if _unfreeze_left == 0:
			_unfreeze_player()


## F1 / View toggles the panel, F4 the cheats; while open, Esc / ui_cancel closes both.
## True if `event` was one of them.
func handle_toggle_event(event: InputEvent) -> bool:
	if event.is_action_pressed(&"tuning_panel"):
		toggle_panel()
	elif event.is_action_pressed(&"cheats"):
		toggle_cheats()
	elif is_open() and event.is_action_pressed(&"ui_cancel"):
		close_all()
	else:
		return false
	return true


func toggle_panel() -> void:
	set_panel_open(not panel.visible)


func toggle_cheats() -> void:
	set_cheats_open(not cheats.visible)


func set_panel_open(open: bool) -> void:
	if open == panel.visible:
		return
	panel.visible = open
	if open:
		panel.refresh_presets()
		panel.refresh_all()
		# The HUD's startup help sits where the panel docks; H brings it back.
		for hud: Node in get_tree().root.find_children("*", "GameHud", true, false):
			(hud as GameHud).set_help_visible(false)
	_update(panel if open else null)


func set_cheats_open(open: bool) -> void:
	if open == cheats.visible:
		return
	cheats.visible = open
	if open:
		cheats.record_posts()
		cheats.refresh()
	_update(cheats if open else null)


func close_all() -> void:
	panel.visible = false
	cheats.visible = false
	_update(null)


## True while the panel or the cheat menu is up.
func is_open() -> bool:
	return panel.visible or cheats.visible


## True while the player is held still by the overlay.
func is_player_frozen() -> bool:
	return _frozen_input != null


func _update(opened: Control) -> void:
	GameInput.menu_open = is_open()
	if not is_open():
		window.hide()
		_unfreeze_left = UNFREEZE_TICKS
		_restore_bindings()
		_set_mouse_free(false)
		return
	_unfreeze_left = 0
	if not window.visible:
		_fit_window()
		window.show()
	window.grab_focus()
	_freeze_player()
	_lift_bindings()
	_set_mouse_free(true)
	var focused := window.gui_get_focus_owner()
	if opened == null and focused != null and focused.is_visible_in_tree():
		return
	if opened == cheats or not panel.visible:
		cheats.focus_first()
	else:
		panel.focus_first()


func _fit_window() -> void:
	window.position = Vector2i.ZERO
	window.size = Vector2i(get_tree().root.get_visible_rect().size)


func _freeze_player() -> void:
	if _frozen_input != null:
		return
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	if player and not player.input.scripted:
		_frozen_input = player.input
		_frozen_input.scripted = true


## Give the frozen input back to the player (if the overlay is closed, or `force`).
func _unfreeze_player(force: bool = false) -> void:
	_unfreeze_left = 0
	if _frozen_input != null and (force or not is_open()):
		_frozen_input.clear_queue()
		_frozen_input.scripted = false
		_frozen_input = null


## Take the game's bindings out of the InputMap (all of GameInput.BINDINGS but KEPT_ACTIONS)
## and release those actions, so nothing that polls Input reacts to the keys the menus use.
func _lift_bindings() -> void:
	if not _lifted.is_empty():
		return
	for action: StringName in GameInput.BINDINGS:
		if KEPT_ACTIONS.has(action) or not InputMap.has_action(action):
			continue
		_lifted[action] = InputMap.action_get_events(action)
		InputMap.action_erase_events(action)
		Input.action_release(action)


## Put the lifted bindings back.
func _restore_bindings() -> void:
	for action: StringName in _lifted:
		if not InputMap.has_action(action):
			continue
		for event: InputEvent in _lifted[action]:
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)
		Input.action_release(action)
	_lifted.clear()


func _set_mouse_free(free: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if free:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not GameInput.paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
