class_name CheatMenu
extends PanelContainer
## The F4 cheat menu (Spec §11): god mode, one-hit KOs, any enemy of the EnemyCatalog (the
## training dummy, the Punk, the Kicker...) spawned at the crosshair, time scale 0.25x or 1x, and
## reset dummies (plus removing the spawned ones or every enemy), waves on or off (in a room with
## an EncounterSpawner), a frozen AI and, from Milestone 4, the Showcase Punk: a frozen Street Punk
## 1 m ahead that loops the long take (ShowcaseScript), so the player can walk round it. "Skip to
## arena N" waits for the arenas (Milestone 5) and shows disabled. TuningOverlay hosts it. A debug tool: unlike the HUD it writes game state
## (Tuning's "Debug" group, TimeController.debug_scale, the enemies, the waves). Each action is a
## public method, so tests and bots can use them without the buttons.

const DUMMY_SCENE := "res://game/enemies/dummy/training_dummy.tscn"

## The time scale buttons, in order (TimeController.debug_scale).
@export var time_scales: PackedFloat64Array = [0.25, 1.0]
## Spawning: the crosshair ray looks this far for a wall, the floor or a body...
@export_range(1.0, 30.0, 0.5) var spawn_max_distance_m: float = 6.0
## ...and a ray that meets nothing spawns this far along it, dropped to the floor.
@export_range(0.5, 10.0, 0.1) var spawn_open_distance_m: float = 3.0
## A dummy never spawns closer than this to the player (looking at one's own feet)...
@export_range(0.5, 3.0, 0.1) var spawn_min_distance_m: float = 1.0
## ...and stands this far off a wall the ray meets, along the wall's normal.
@export_range(0.0, 2.0, 0.05) var spawn_wall_clearance_m: float = 0.5
## No other actor stands closer than this to a spawn, center to center.
@export_range(0.0, 2.0, 0.05) var spawn_actor_clearance_m: float = 0.7
## A body the crosshair is on gets the new dummy this far to its side (whichever side is
## clear), so it stands beside that body in view instead of hidden behind it.
@export_range(0.5, 3.0, 0.05) var spawn_beside_m: float = 1.0
## A blocked spot (a wall, a crate, a body) looks this far around it for a clear one, in
## rings spawn_search_step_m apart; with none, nothing spawns.
@export_range(0.0, 5.0, 0.1) var spawn_search_radius_m: float = 2.0
@export_range(0.1, 1.0, 0.05) var spawn_search_step_m: float = 0.35
## The body test (a capsule the dummy's size against the world) starts this far above the
## floor, so the floor it stands on is not an obstacle.
@export_range(0.0, 0.5, 0.01) var spawn_floor_gap_m: float = 0.1
## A spot whose floor is more than this above or below the player's is skipped (a crate top,
## the curb).
@export_range(0.0, 2.0, 0.05) var spawn_max_rise_m: float = 0.3
## The Showcase Punk stands this far ahead of the player's feet (the 1 m of the final judgement),
## on the floor, nearer the player than the walls, crates and bodies allow only by the search above.
@export_range(0.5, 3.0, 0.1) var showcase_distance_m: float = 1.0
@export var spawn_colors: Array[Color] = [
	Color(0.2, 0.62, 0.66), Color(0.72, 0.62, 0.18), Color(0.56, 0.4, 0.3), Color(0.36, 0.5, 0.78),
]
@export var font_size: int = 16
@export var title_size: int = 22

## The node spawned enemies are added to (the room). Defaults to the current scene.
var world: Node3D
var god_mode_toggle: CheckButton
var one_hit_toggle: CheckButton
var time_scale_buttons: Array[Button] = []
var skip_arena_button: Button
## The enemy picked in the list (EnemyCatalog.available(): item metadata = the id) and the buttons
## and toggles of the enemy cheats.
var enemy_option: OptionButton
var waves_button: Button
var freeze_toggle: CheckButton
var showcase_toggle: CheckButton
## The Showcase Punk's runner while the showcase is on (null = off); the Punk is its parent.
var showcase: ShowcaseRunner
## Enemies (dummies and AI enemies) this menu spawned, oldest first.
var spawned: Array[CombatActor] = []
## Tests: enemy id -> the PackedScene to spawn instead of the catalog's, in a room with no
## EncounterSpawner (a room with one spawns through it, and its own scene_override).
var scene_override: Dictionary = {}

## Freeze AI as it was when the showcase went on (it goes back to this when the showcase goes off,
## unless the player changed it since).
var _showcase_saved_frozen: bool = false
## Instance id -> Vector4(post x, y, z, yaw) of each dummy seen (record_posts()).
var _posts: Dictionary[int, Vector4] = {}
var _status: Label
## AI enemies spawned by this menu without a spawner: archetype label -> count (names).
var _serials: Dictionary = {}


func _ready() -> void:
	_build()
	Tuning.changed.connect(_on_tuning_changed)
	record_posts()
	refresh()


func _exit_tree() -> void:
	if Tuning.changed.is_connected(_on_tuning_changed):
		Tuning.changed.disconnect(_on_tuning_changed)
	# A room switched with the showcase on: the Punk goes with its room, Freeze AI goes back.
	if is_showcase_on():
		_stop_showcase()


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
	if freeze_toggle:
		freeze_toggle.set_pressed_no_signal(Tuning.data.ai_frozen)
		freeze_toggle.text = "Freeze AI (enemies stand still): %s" % ("ON" if Tuning.data.ai_frozen else "off")
	if showcase_toggle:
		showcase_toggle.set_pressed_no_signal(is_showcase_on())
		showcase_toggle.text = "Showcase Punk at 1 m (walk round it): %s" % ("ON" if is_showcase_on() else "off")
	if waves_button:
		var has_spawner := _spawner() != null
		waves_button.disabled = not has_spawner
		waves_button.text = "Waves: %s (click to toggle)" % ("ON" if Tuning.data.waves_enabled else "off") if has_spawner \
				else "Waves: this room has none"


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


## Where a dummy spawned now would stand and face: {position: Vector3, yaw: float}, or {}
## when there is no clear spot. The crosshair is the center of the first-person view: the
## ray from the first-person camera (from the player's eye and look in the other camera
## modes, or with no camera; the side view has no crosshair) meets, within
## spawn_max_distance_m:
## - a body: the spot is spawn_beside_m to its side;
## - a wall: the spot is spawn_wall_clearance_m off it, along its normal;
## - the floor: the spot is there;
## - nothing: the spot is spawn_open_distance_m along the ray.
## The spot drops to the floor and stays spawn_min_distance_m from the player. If a capsule
## the dummy's size would overlap the world there, another actor stands within
## spawn_actor_clearance_m, or the player can't see the spot, the nearest clear spot within
## spawn_search_radius_m is used (beside the spot before toward the player, before behind
## it). The enemy faces the player. `id` is the EnemyCatalog id of what will spawn (its body's
## size decides what "clear" means); the training dummy by default.
func spawn_point(id: StringName = &"dummy") -> Dictionary:
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	var camera := get_tree().root.get_camera_3d()
	var origin: Vector3
	var dir: Vector3
	if camera and (camera is FirstPersonCamera or player == null):
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
	var body_size := EnemyCatalog.body_size(id)
	var world_mask := CombatTypes.bit(CombatTypes.LAYER_WORLD)
	var body_mask := CombatTypes.bit(CombatTypes.LAYER_PLAYER_BODY) | CombatTypes.bit(CombatTypes.LAYER_ENEMY_BODY) \
			| CombatTypes.bit(CombatTypes.LAYER_DOWNED_BODY)
	var flat := _flat(dir, Vector3.FORWARD)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * spawn_max_distance_m, world_mask | body_mask)
	if player:
		query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	var spot := origin + dir * spawn_open_distance_m
	# Which way "beside" and "toward the player" point: across and back along the view.
	var back := -flat
	if not hit.is_empty():
		var normal: Vector3 = hit.normal
		var body := hit.collider as Node3D
		if body is CombatActor:
			# Beside the body, on its right unless only its left is clear.
			var side := flat.cross(Vector3.UP).normalized()
			spot = _on_floor(space, body.global_position + side * spawn_beside_m, player)
			var left := _on_floor(space, body.global_position - side * spawn_beside_m, player)
			if not _spot_clear(space, spot, player, body_size) and _spot_clear(space, left, player, body_size):
				spot = left
		elif normal.y < 0.7:  # a wall, not the floor
			spot = hit.position + _flat(normal, back) * spawn_wall_clearance_m
		else:
			spot = hit.position
	spot = _on_floor(space, spot, player)
	if player:
		var away := spot - player.global_position
		away.y = 0.0
		if away.length() < spawn_min_distance_m:
			spot = _on_floor(space, player.global_position + flat * spawn_min_distance_m, player)
		var to_player := player.global_position - spot
		if Vector2(to_player.x, to_player.z).length() > 0.001:
			back = _flat(to_player, back)
	var clear := _clear_spot_near(space, spot, back, player, body_size)
	if clear.is_empty():
		return {}
	spot = clear.position
	var yaw := 0.0
	if player:
		var facing := player.global_position - spot
		yaw = atan2(-facing.x, -facing.z)
	return {position = spot, yaw = yaw}


## Spawn enemy `id` (an EnemyCatalog id) at the crosshair (spawn_point(id)) and return it, or null.
## The training dummy is as spawn_dummy() makes it. An AI enemy is named and counted per
## archetype ("Punk3"), starts in ENTER from where it stands and is added through the room's
## EncounterSpawner when it has one (else straight to the room).
func spawn_enemy(id: StringName) -> CombatActor:
	if id == &"dummy":
		return spawn_dummy()
	var point := spawn_point(id)
	var host := _world()
	if point.is_empty() or host == null:
		_say("No room to spawn there.")
		return null
	var enemy: EnemyActor
	var spawner := _spawner()
	if spawner:
		enemy = spawner.spawn_enemy(id, point.position, point.yaw)
	else:
		var scene := scene_override.get(id) as PackedScene
		if scene == null:
			scene = EnemyCatalog.scene(id)
		if scene:
			enemy = EncounterSpawner.make_enemy(scene, id, _serials)
		if enemy:
			enemy.position = host.to_local(point.position)
			enemy.rotation.y = float(point.yaw) - host.global_rotation.y
			host.add_child(enemy)
			enemy.enter_from(point.position, point.position)
	if enemy == null:
		_say("Could not spawn %s." % id)
		return null
	spawned.append(enemy)
	_say("Spawned %s." % enemy.display_name)
	return enemy


## Spawn the enemy picked in the list at the crosshair.
func spawn_selected() -> CombatActor:
	if enemy_option == null or enemy_option.selected < 0:
		return null
	return spawn_enemy(StringName(enemy_option.get_item_metadata(enemy_option.selected)))


## Spawn a training dummy at the crosshair (spawn_point()). Returns it, or null.
func spawn_dummy() -> TrainingDummy:
	var point := spawn_point(&"dummy")
	var host := _world()
	if point.is_empty() or host == null or not ResourceLoader.exists(DUMMY_SCENE):
		_say("No room to spawn a dummy there.")
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


## Remove the enemies this menu spawned (dummies and AI enemies). Returns how many.
func remove_spawned_dummies() -> int:
	var count := 0
	for actor in spawned:
		if is_instance_valid(actor):
			_posts.erase(actor.get_instance_id())
			for group: StringName in [&"enemy", &"ai_enemy", &"actor", &"boss"]:
				if actor.is_in_group(group):
					actor.remove_from_group(group)
			actor.queue_free()
			count += 1
	spawned.clear()
	_say("Removed %d spawned enemies." % count)
	return count


## Remove every enemy in the room, the training dummies and the AI enemies (they leave their
## groups first, so the same frame no longer finds them). Returns how many.
func remove_all_enemies() -> int:
	var count := EncounterSpawner.remove_enemies(get_tree(), false)
	spawned.clear()
	_posts.clear()
	_say("Removed %d enemies." % count)
	return count


## Waves on or off in a room with an EncounterSpawner (the tunable waves_enabled); does
## nothing without one.
func set_waves(on: bool) -> void:
	var spawner := _spawner()
	if spawner:
		spawner.set_waves_enabled(on)
	refresh()


## Freeze the AI: enemies stand still and ask for nothing (the Debug tunable ai_frozen).
func set_ai_frozen(on: bool) -> void:
	Tuning.set_value(&"ai_frozen", on)


## The Showcase Punk: a Street Punk `showcase_distance_m` ahead of the player, facing him, frozen
## where it stands and playing the long take (ShowcaseScript) over and over; off, it is freed. It is
## a real EnemyActor of the catalog (so it wears whatever the Punk wears) taken off its own tick, out
## of the enemy groups the director, the spawner and the probes read, off the navigation avoidance
## and with its hurtboxes off: nothing hits it and nothing reads it, and the player can walk round
## it. While it shows, Freeze AI is on (the crowd stands, so nothing attacks the player walking
## round); off, the Punk is freed and Freeze AI goes back to what it was, unless the player changed
## it meanwhile. It works in both rooms: it needs no spawner and no navmesh.
func set_showcase(on: bool) -> void:
	if on == is_showcase_on():
		refresh()
		return
	if on:
		_start_showcase()
	else:
		_stop_showcase()
	refresh()


## True while the Showcase Punk stands.
func is_showcase_on() -> bool:
	return is_instance_valid(showcase)


## Where the Showcase Punk would stand and face: {position: Vector3, yaw: float}, or {} when there
## is no clear spot: showcase_distance_m ahead of the player's feet along his look, on the floor,
## the nearest clear spot (_clear_spot_near()) when a wall, a crate or a body is there.
func showcase_point() -> Dictionary:
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	var space := _space()
	if player == null or space == null:
		return {}
	var flat := _flat(-player.get_look_basis().z, Vector3.FORWARD)
	var spot := _on_floor(space, player.global_position + flat * showcase_distance_m, player)
	var clear := _clear_spot_near(space, spot, -flat, player, EnemyCatalog.body_size(&"punk"))
	if clear.is_empty():
		return {}
	spot = clear.position
	var facing := player.global_position - spot
	return {position = spot, yaw = atan2(-facing.x, -facing.z)}


func _start_showcase() -> void:
	var point := showcase_point()
	var host := _world()
	var scene := EnemyCatalog.scene(&"punk")
	if point.is_empty() or host == null or scene == null:
		_say("No room for the Showcase Punk there.")
		return
	var punk := scene.instantiate() as EnemyActor
	if punk == null:
		_say("Could not make the Showcase Punk.")
		return
	punk.name = "ShowcasePunk"
	punk.display_name = "Showcase Punk"
	punk.position = host.to_local(point.position)
	punk.rotation.y = float(point.yaw) - host.global_rotation.y
	host.add_child(punk)
	ShowcaseRunner.unplug(punk)
	var runner := ShowcaseRunner.new()
	runner.name = "ShowcaseRunner"
	punk.add_child(runner)
	runner.setup(punk, Transform3D(Basis(Vector3.UP, float(point.yaw)), point.position))
	showcase = runner
	_showcase_saved_frozen = Tuning.data.ai_frozen
	set_ai_frozen(true)
	_say("Showcase Punk: the long take, %.0f s, on a loop." % runner.take_seconds())


func _stop_showcase() -> void:
	var punk: CombatActor = showcase.actor if is_instance_valid(showcase) else null
	showcase = null
	if is_instance_valid(punk):
		for group: StringName in [&"actor", &"enemy", &"ai_enemy"]:
			if punk.is_in_group(group):
				punk.remove_from_group(group)
		punk.queue_free()
	# Freeze AI back to what it was, unless the player changed it while the showcase stood.
	if Tuning.data.ai_frozen:
		set_ai_frozen(_showcase_saved_frozen)
	_say("Showcase Punk removed.")


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

	var spawn_row := HBoxContainer.new()
	spawn_row.add_theme_constant_override(&"separation", 8)
	box.add_child(spawn_row)
	enemy_option = OptionButton.new()
	enemy_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry: Dictionary in EnemyCatalog.available():
		enemy_option.add_item(String(entry.label))
		enemy_option.set_item_metadata(enemy_option.item_count - 1, entry.id)
	spawn_row.add_child(enemy_option)
	spawn_row.add_child(_button("Spawn at crosshair", func() -> void: spawn_selected()))
	box.add_child(_button("Reset dummies (posts, full health)", func() -> void: reset_dummies()))
	box.add_child(_button("Remove spawned enemies", func() -> void: remove_spawned_dummies()))
	box.add_child(_button("Remove all enemies", func() -> void: remove_all_enemies()))
	waves_button = _button("Waves", func() -> void: set_waves(not Tuning.data.waves_enabled))
	box.add_child(waves_button)
	freeze_toggle = CheckButton.new()
	freeze_toggle.toggled.connect(set_ai_frozen)
	box.add_child(freeze_toggle)
	showcase_toggle = CheckButton.new()
	showcase_toggle.toggled.connect(set_showcase)
	box.add_child(showcase_toggle)

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
	if property in [&"", &"god_mode", &"one_hit_ko", &"ai_frozen", &"waves_enabled"]:
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


## The first clear spot (_spot_clear()) on the floor around `spot`: the spot itself, then
## rings spawn_search_step_m apart out to spawn_search_radius_m, each trying beside the spot
## first, then toward `back` (the player), then away. {position} or {} when none is clear.
func _clear_spot_near(space: PhysicsDirectSpaceState3D, spot: Vector3, back: Vector3, player: Node3D,
		body: Vector2) -> Dictionary:
	if _spot_clear(space, spot, player, body):
		return {position = spot}
	var side := back.cross(Vector3.UP).normalized()
	var directions: Array[Vector3] = [
		side, -side, back, (back + side).normalized(), (back - side).normalized(),
		(side - back).normalized(), (-side - back).normalized(), -back,
	]
	var rings := floori(spawn_search_radius_m / spawn_search_step_m)
	for ring in range(1, rings + 1):
		for direction: Vector3 in directions:
			var candidate := _on_floor(space, spot + direction * spawn_search_step_m * ring, player)
			if _spot_clear(space, candidate, player, body):
				return {position = candidate}
	return {}


## An enemy with a `body` (Vector2: radius, height) can stand at `spot` (on the floor):
## spawn_min_distance_m from the player and within spawn_max_rise_m of their floor, no other
## actor within spawn_actor_clearance_m, a capsule its size overlapping no world geometry, and
## the player able to see it (no wall between their chests).
func _spot_clear(space: PhysicsDirectSpaceState3D, spot: Vector3, player: Node3D, body: Vector2) -> bool:
	if player:
		var away := spot - player.global_position
		if absf(away.y) > spawn_max_rise_m:
			return false
		away.y = 0.0
		if away.length() < spawn_min_distance_m - 0.001:
			return false
	if not _clear_of_actors(spot):
		return false
	var capsule := CapsuleShape3D.new()
	capsule.radius = body.x
	capsule.height = maxf(body.y - spawn_floor_gap_m, body.x * 2.0)
	var shape := PhysicsShapeQueryParameters3D.new()
	shape.shape = capsule
	shape.collision_mask = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	shape.transform = Transform3D(Basis.IDENTITY, spot + Vector3.UP * (spawn_floor_gap_m + capsule.height * 0.5))
	if not space.intersect_shape(shape, 1).is_empty():
		return false
	if player:
		var chest := Vector3.UP * body.y * 0.5
		var sight := PhysicsRayQueryParameters3D.create(player.global_position + chest, spot + chest,
				CombatTypes.bit(CombatTypes.LAYER_WORLD))
		if not space.intersect_ray(sight).is_empty():
			return false
	return true


## `spot` dropped (or raised) onto the floor below it; the player's height if there is none.
func _on_floor(space: PhysicsDirectSpaceState3D, spot: Vector3, player: Node3D) -> Vector3:
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			spot + Vector3.UP * 2.0, spot + Vector3.DOWN * 20.0, CombatTypes.bit(CombatTypes.LAYER_WORLD)))
	if not floor_hit.is_empty():
		spot.y = (floor_hit.position as Vector3).y
	elif player:
		spot.y = player.global_position.y
	return spot


## The room's EncounterSpawner, or null (the training room has none).
func _spawner() -> EncounterSpawner:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(EncounterSpawner.GROUP) as EncounterSpawner


## `v` flattened onto the ground plane and normalized; `fallback` when it is (nearly) vertical.
static func _flat(v: Vector3, fallback: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized() if Vector2(v.x, v.z).length() > 0.001 else fallback


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
