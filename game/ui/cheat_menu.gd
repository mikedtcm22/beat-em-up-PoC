class_name CheatMenu
extends PanelContainer
## The F4 cheat menu (Spec §11): god mode, one-hit KOs, a training dummy spawned at the
## crosshair, time scale 0.25x or 1x, and reset dummies (plus removing the spawned ones).
## "Skip to arena N" waits for the arenas (Milestone 5) and shows disabled. TuningOverlay
## hosts it. A debug tool: unlike the HUD it writes game state (Tuning's "Debug" group,
## TimeController.debug_scale, the dummies). Each action is a public method, so tests and
## bots can use them without the buttons.

const DUMMY_SCENE := "res://game/enemies/dummy/training_dummy.tscn"

## The time scale buttons, in order (TimeController.debug_scale).
@export var time_scales: PackedFloat64Array = [0.25, 1.0]
## Spawning: the crosshair ray looks this far for a wall or the floor...
@export_range(1.0, 30.0, 0.5) var spawn_max_distance_m: float = 6.0
## ...and a ray that meets nothing spawns this far along it, dropped to the floor.
@export_range(0.5, 10.0, 0.1) var spawn_open_distance_m: float = 3.0
## A dummy never spawns closer than this to the player (looking at one's own feet)...
@export_range(0.5, 3.0, 0.1) var spawn_min_distance_m: float = 1.0
## ...and stays this far off a wall the ray meets.
@export_range(0.0, 2.0, 0.05) var spawn_wall_clearance_m: float = 0.5
## A spot closer than this to another actor steps back toward the player (half this a step)
## until it is clear, so a dummy never spawns inside another body.
@export_range(0.0, 2.0, 0.05) var spawn_actor_clearance_m: float = 0.7
@export var spawn_colors: Array[Color] = [
	Color(0.2, 0.62, 0.66), Color(0.72, 0.62, 0.18), Color(0.56, 0.4, 0.3), Color(0.36, 0.5, 0.78),
]
@export var font_size: int = 16
@export var title_size: int = 22

## The node spawned dummies are added to (the test room). Defaults to the current scene.
var world: Node3D
var god_mode_toggle: CheckButton
var one_hit_toggle: CheckButton
var time_scale_buttons: Array[Button] = []
var skip_arena_button: Button
## Dummies this menu spawned, oldest first.
var spawned: Array[TrainingDummy] = []

## Instance id -> Vector4(post x, y, z, yaw) of each dummy seen (record_posts()).
var _posts: Dictionary[int, Vector4] = {}
var _status: Label


func _ready() -> void:
	_build()
	Tuning.changed.connect(_on_tuning_changed)
	record_posts()
	refresh()


func _exit_tree() -> void:
	if Tuning.changed.is_connected(_on_tuning_changed):
		Tuning.changed.disconnect(_on_tuning_changed)


## Show the current cheat states (Tuning and TimeController may change elsewhere).
func refresh() -> void:
	for toggle: CheckButton in [god_mode_toggle, one_hit_toggle]:
		var on: bool = Tuning.data.god_mode if toggle == god_mode_toggle else Tuning.data.one_hit_ko
		toggle.set_pressed_no_signal(on)
		# The state spelled out: the default theme's "off" switch is hard to see here.
		toggle.text = "%s: %s" % [toggle.get_meta(&"label"), "ON" if on else "off"]
		var color := HudStyle.HEALTH if on else HudStyle.PAPER
		for slot: StringName in [&"font_color", &"font_pressed_color", &"font_hover_color", &"font_hover_pressed_color", &"font_focus_color"]:
			toggle.add_theme_color_override(slot, color)
	for i in time_scale_buttons.size():
		time_scale_buttons[i].set_pressed_no_signal(is_equal_approx(TimeController.debug_scale, time_scales[i]))


## Gamepad focus on the first cheat.
func focus_first() -> void:
	god_mode_toggle.grab_focus()


func set_god_mode(on: bool) -> void:
	Tuning.set_value(&"god_mode", on)


func set_one_hit_ko(on: bool) -> void:
	Tuning.set_value(&"one_hit_ko", on)


## The whole simulation's debug time scale (TimeController.debug_scale).
func set_time_scale(scale: float) -> void:
	TimeController.debug_scale = scale
	refresh()


## Remember where every training dummy stands now, as the post "reset dummies" returns it
## to (dummies already recorded keep theirs).
func record_posts() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		var dummy := node as TrainingDummy
		if dummy and not _posts.has(dummy.get_instance_id()):
			_posts[dummy.get_instance_id()] = _post_of(dummy.global_position, dummy.rotation.y)


## Where a dummy spawned now would stand and face: {position: Vector3, yaw: float}. The
## crosshair is the center of the view: the ray from the active camera (the player's eye
## and look without one) meets the floor or a wall (kept spawn_wall_clearance_m off it)
## within spawn_max_distance_m, or else ends spawn_open_distance_m out; the spot drops to
## the floor, stays spawn_min_distance_m from the player, steps back toward the player while
## another actor stands within spawn_actor_clearance_m, and faces the player.
func spawn_point() -> Dictionary:
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	var camera := get_tree().root.get_camera_3d()
	var origin: Vector3
	var dir: Vector3
	if camera:
		origin = camera.global_position
		dir = -camera.global_basis.z
	elif player:
		origin = player.get_eye_transform().origin
		dir = -player.get_look_basis().z
	else:
		return {}
	var space := _space()
	if space == null:
		return {}
	var mask := CombatTypes.bit(CombatTypes.LAYER_WORLD)
	var flat := Vector3(dir.x, 0.0, dir.z).normalized() if Vector2(dir.x, dir.z).length() > 0.001 else Vector3.FORWARD
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + dir * spawn_max_distance_m, mask))
	var spot := origin + dir * spawn_open_distance_m
	if not hit.is_empty():
		var normal: Vector3 = hit.normal
		spot = hit.position
		if normal.y < 0.7:  # a wall, not the floor
			spot -= flat * spawn_wall_clearance_m
	if player:
		var away := spot - player.global_position
		away.y = 0.0
		if away.length() < spawn_min_distance_m:
			spot = player.global_position + flat * spawn_min_distance_m
		var step := maxf(spawn_actor_clearance_m * 0.5, 0.05)
		var candidate := spot
		var reach := spot - player.global_position
		var room_left := Vector2(reach.x, reach.z).length() - spawn_min_distance_m
		while not _clear_of_actors(candidate) and room_left >= step:
			candidate -= flat * step
			room_left -= step
		if _clear_of_actors(candidate):
			spot = candidate
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			spot + Vector3.UP * 2.0, spot + Vector3.DOWN * 20.0, mask))
	if not floor_hit.is_empty():
		spot.y = (floor_hit.position as Vector3).y
	elif player:
		spot.y = player.global_position.y
	var yaw := 0.0
	if player:
		var to_player := player.global_position - spot
		yaw = atan2(-to_player.x, -to_player.z)
	return {position = spot, yaw = yaw}


## Spawn a training dummy at the crosshair (spawn_point()). Returns it, or null.
func spawn_dummy() -> TrainingDummy:
	var point := spawn_point()
	var host := _world()
	if point.is_empty() or host == null or not ResourceLoader.exists(DUMMY_SCENE):
		_say("Nothing to spawn on.")
		return null
	var dummy := (load(DUMMY_SCENE) as PackedScene).instantiate() as TrainingDummy
	var number := get_tree().get_nodes_in_group(&"enemy").size() + 1
	dummy.name = "SpawnedDummy%d" % (spawned.size() + 1)
	dummy.display_name = "Dummy %d" % number
	dummy.color = spawn_colors[spawned.size() % spawn_colors.size()] if not spawn_colors.is_empty() else dummy.color
	dummy.position = host.to_local(point.position)
	dummy.rotation.y = float(point.yaw) - host.global_rotation.y
	host.add_child(dummy)
	spawned.append(dummy)
	_posts[dummy.get_instance_id()] = _post_of(dummy.global_position, dummy.rotation.y)
	_say("Spawned %s." % dummy.display_name)
	return dummy


## Every training dummy back on its post, standing, at full health (Tuning.dummy_health).
## Returns how many were reset.
func reset_dummies() -> int:
	var count := 0
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		var dummy := node as TrainingDummy
		if dummy == null or dummy.is_queued_for_deletion():
			continue
		var post: Vector4 = _posts.get(dummy.get_instance_id(), _post_of(dummy.global_position, dummy.rotation.y))
		dummy.max_health = Tuning.data.dummy_health
		dummy.set_post(Vector3(post.x, post.y, post.z), post.w, true)
		count += 1
	_say("Reset %d dummies." % count)
	return count


## Remove the dummies this menu spawned. Returns how many.
func remove_spawned_dummies() -> int:
	var count := 0
	for dummy: TrainingDummy in spawned:
		if is_instance_valid(dummy):
			_posts.erase(dummy.get_instance_id())
			dummy.remove_from_group(&"enemy")
			dummy.remove_from_group(&"actor")
			dummy.queue_free()
			count += 1
	spawned.clear()
	_say("Removed %d spawned dummies." % count)
	return count


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

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(_label("CHEATS", title_size, HudStyle.HEALTH, true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(_label("F4 or Esc closes", font_size - 2, HudStyle.MUTED))

	god_mode_toggle = CheckButton.new()
	god_mode_toggle.set_meta(&"label", "God mode (the player takes no damage)")
	god_mode_toggle.toggled.connect(set_god_mode)
	box.add_child(god_mode_toggle)
	one_hit_toggle = CheckButton.new()
	one_hit_toggle.set_meta(&"label", "One-hit KOs (enemies)")
	one_hit_toggle.toggled.connect(set_one_hit_ko)
	box.add_child(one_hit_toggle)

	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override(&"separation", 8)
	box.add_child(time_row)
	time_row.add_child(_label("Time scale", font_size, HudStyle.PAPER))
	var group := ButtonGroup.new()
	for scale: float in time_scales:
		var button := Button.new()
		button.text = "%s×" % String.num(scale, 2)
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size.x = 72.0
		button.add_theme_color_override(&"font_pressed_color", HudStyle.HEALTH)
		button.add_theme_color_override(&"font_hover_pressed_color", HudStyle.HEALTH)
		button.pressed.connect(set_time_scale.bind(scale))
		time_row.add_child(button)
		time_scale_buttons.append(button)

	box.add_child(_button("Spawn training dummy at crosshair", func() -> void: spawn_dummy()))
	box.add_child(_button("Reset dummies (posts, full health)", func() -> void: reset_dummies()))
	box.add_child(_button("Remove spawned dummies", func() -> void: remove_spawned_dummies()))

	var arena_row := HBoxContainer.new()
	arena_row.add_theme_constant_override(&"separation", 8)
	box.add_child(arena_row)
	skip_arena_button = Button.new()
	skip_arena_button.text = "Skip to arena N"
	skip_arena_button.disabled = true
	skip_arena_button.tooltip_text = "Arenas arrive in Milestone 5."
	arena_row.add_child(skip_arena_button)
	arena_row.add_child(_label("(Milestone 5)", font_size - 2, HudStyle.MUTED))

	_status = _label("", font_size - 2, HudStyle.MUTED)
	box.add_child(_status)


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.label_settings = HudStyle.label_settings(size, color, bold)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(action)
	return button


func _on_tuning_changed(property: StringName) -> void:
	if property in [&"", &"god_mode", &"one_hit_ko"]:
		refresh()


## No actor stands within spawn_actor_clearance_m of `spot` (on the ground plane).
func _clear_of_actors(spot: Vector3) -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"actor"):
		var actor := node as Node3D
		if actor == null or actor.is_queued_for_deletion():
			continue
		var gap := actor.global_position - spot
		gap.y = 0.0
		if gap.length() < spawn_actor_clearance_m:
			return false
	return true


func _say(text: String) -> void:
	if _status:
		_status.text = text


func _world() -> Node3D:
	if is_instance_valid(world):
		return world
	return get_tree().current_scene as Node3D


func _space() -> PhysicsDirectSpaceState3D:
	var host := _world()
	if host and host.get_world_3d():
		return host.get_world_3d().direct_space_state
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	return player.get_world_3d().direct_space_state if player else null


static func _post_of(pos: Vector3, yaw: float) -> Vector4:
	return Vector4(pos.x, pos.y, pos.z, yaw)
