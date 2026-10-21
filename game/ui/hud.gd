class_name GameHud
extends CanvasLayer
## In-game HUD and debug overlays (Spec §5, §11), the root of game/ui/hud.tscn. Runs while
## paused (process_mode ALWAYS). Presentation only: it subscribes to CombatEvents,
## GameInput and the camera director, reads actors, and never writes simulation state.
##
## Layout (1920x1080 canvas): player health bottom-left, boss bar bottom-center, combat log
## right-middle, camera toast and pause caption top-center, help left-middle, over-head
## enemy bars and the center dot in the 3D view. The top-left and top-right corners stay
## clear for the rear-attack warning (Spec §8). The DebugDraw child (CombatDebugDraw, F3)
## draws in 3D, in group "debug_draw".
##
## All time-based parts are driven from advance(delta), which _process() calls; tests can
## turn processing off and call advance() with chosen deltas.

## Seconds the help overlay stays up after start before it hides itself (then H toggles).
@export var help_startup_seconds: float = 8.0

@onready var player_panel: PlayerHealthPanel = $PlayerHealthPanel
@onready var boss_bar: BossHealthBar = $BossHealthBar
@onready var enemy_bars: EnemyHealthBars = $EnemyHealthBars
@onready var center_dot: CenterDot = $CenterDot
@onready var combat_log: CombatLogOverlay = $CombatLog
@onready var camera_toast: CameraModeToast = $CameraToast
@onready var help_overlay: HelpOverlay = $HelpOverlay
@onready var pause_overlay: PauseOverlay = $PauseOverlay
@onready var debug_draw: CombatDebugDraw = $DebugDraw

## The node in group "camera_director" (CameraDirector), or null. Typed loosely: read
## through `mode` and the `camera_changed` signal only.
var director: Node

var _help_auto_hide_left: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	CombatEvents.hit_landed.connect(_on_hit_landed)
	CombatEvents.attack_started.connect(combat_log.on_attack_started)
	CombatEvents.attack_whiffed.connect(combat_log.add_whiff)
	CombatEvents.health_changed.connect(_on_health_changed)
	GameInput.paused_changed.connect(pause_overlay.set_paused)
	pause_overlay.set_paused(GameInput.paused)
	boss_bar.hide_boss()
	set_help_visible(true)
	_help_auto_hide_left = help_startup_seconds
	advance(0.0)


func _process(delta: float) -> void:
	advance(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"help"):
		toggle_help()
		get_viewport().set_input_as_handled()


## Step every time-based part of the HUD by `delta` real seconds.
func advance(delta: float) -> void:
	_refresh_director()
	if _help_auto_hide_left > 0.0:
		_help_auto_hide_left -= delta
		if _help_auto_hide_left <= 0.0:
			help_overlay.visible = false
	player_panel.advance(delta)
	boss_bar.advance(delta)
	# Over-head bars count game time: they keep their remaining seconds through a pause.
	enemy_bars.advance(0.0 if get_tree().paused else delta)
	center_dot.refresh(director)
	camera_toast.advance(delta)


## Show the bottom-center boss bar for `actor` (Milestone 5).
func show_boss(actor: CombatActor) -> void:
	boss_bar.show_boss(actor)


## Hide the boss bar.
func hide_boss() -> void:
	boss_bar.hide_boss()


## Show or hide the combat log overlay. It keeps recording while hidden.
func set_combat_log_visible(shown: bool) -> void:
	combat_log.visible = shown


## True while the combat log overlay is shown (the default).
func is_combat_log_visible() -> bool:
	return combat_log.visible


## Toggle help (the H key). Cancels the startup auto-hide.
func toggle_help() -> void:
	set_help_visible(not help_overlay.visible)


## Show or hide the help overlay. Cancels the startup auto-hide.
func set_help_visible(shown: bool) -> void:
	_help_auto_hide_left = 0.0
	help_overlay.visible = shown


## Turn debug draw on or off, as F3 does.
func set_debug_draw_enabled(on: bool) -> void:
	debug_draw.enabled = on


func _on_hit_landed(hit: HitInfo) -> void:
	combat_log.add_hit(hit)
	enemy_bars.on_hit_landed(hit)


func _on_health_changed(actor: Node3D, health: float, max_health: float) -> void:
	if not is_instance_valid(actor):
		return
	if actor == player_panel.player:
		player_panel.on_health_changed(health, max_health)
	enemy_bars.on_health_changed(actor, health, max_health)


## Find the camera director (it may enter the tree after the HUD, or be replaced) and
## listen to its camera_changed signal.
func _refresh_director() -> void:
	if is_instance_valid(director):
		return
	director = get_tree().get_first_node_in_group(&"camera_director")
	if director == null:
		return
	if director.has_signal(&"camera_changed") and not director.is_connected(&"camera_changed", _on_camera_changed):
		director.connect(&"camera_changed", _on_camera_changed)


func _on_camera_changed(mode: StringName) -> void:
	camera_toast.show_mode(mode)
	center_dot.refresh(director)
