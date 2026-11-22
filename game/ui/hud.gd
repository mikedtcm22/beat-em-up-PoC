class_name GameHud
extends CanvasLayer
## In-game HUD and debug overlays (Spec §5, §11), the root of game/ui/hud.tscn. Runs while
## paused (process_mode ALWAYS). Presentation only: it subscribes to CombatEvents,
## GameInput and the camera director, reads actors, and never writes simulation state.
##
## Layout (1920x1080 canvas): the hurt vignette (HurtOverlay, the edges, under everything), player health (and guard meter) bottom-left, boss bar
## bottom-center, combat log right-middle, camera toast and pause caption top-center, help
## left-middle, the PARRY / GUARD BREAK callout just below the center (drawn over the log
## and the help, which "GUARD BREAK!" reaches into), over-head enemy bars and the center dot
## in the 3D view, the MASH P / K! prompt (GrabPrompt) below the center while an enemy holds
## the player, and the "LB" pick-up cue (PickupCue) low in the view while a weapon is within
## LB's reach (a dropped pipe lies below the forward lens). The top-left and top-right corners stay
## clear for the rear-attack warning (Spec §8), which RearWarning draws there. The DebugDraw
## child (CombatDebugDraw, F3) draws in 3D, in group "debug_draw". The boss bar follows the
## live actor in group "boss" by itself (no room or boss calls into the HUD).
##
## All time-based parts are driven from advance(delta), which _process() calls; tests can
## turn processing off and call advance() with chosen deltas. The HUD processes after the
## cameras (HudStyle.PROCESS_PRIORITY), so the over-head bars follow this frame's view.

## Seconds the help overlay stays up after start before it hides itself (then H toggles).
## Time spent paused does not count.
@export var help_startup_seconds: float = 8.0

@onready var hurt_overlay: HurtOverlay = $HurtOverlay
@onready var player_panel: PlayerHealthPanel = $PlayerHealthPanel
@onready var boss_bar: BossHealthBar = $BossHealthBar
@onready var enemy_bars: EnemyHealthBars = $EnemyHealthBars
@onready var center_dot: CenterDot = $CenterDot
@onready var combat_log: CombatLogOverlay = $CombatLog
@onready var block_callout: BlockCallout = $BlockCallout
@onready var rear_warning: RearWarning = $RearWarning
@onready var grab_prompt: GrabPrompt = $GrabPrompt
@onready var pickup_cue: PickupCue = $PickupCue
## The "GO" arrow and "CLEAR!" of the level (Milestone 5); built in _ready(), a child like the others.
var go_cue: GoCue
## The drawn cards of the trailer look (Milestone 7, Phase 3): built in _ready(), the topmost child, off under the m6 profile.
var cut_in: CutIn
@onready var camera_toast: CameraModeToast = $CameraToast
@onready var help_overlay: HelpOverlay = $HelpOverlay
@onready var pause_overlay: PauseOverlay = $PauseOverlay
@onready var debug_draw: CombatDebugDraw = $DebugDraw

## The node in group "camera_director" (CameraDirector), or null. Typed loosely: read
## through `mode` and the `camera_changed` signal only.
var director: Node

var _help_auto_hide_left: float = 0.0
## The look the HUD last dressed for (true: the trailer profile's comic look, M7); -1 before the first time.
var _comic_seen: int = -1
## Whether the combat log was up under m6 when the HUD last dressed for the trailer look: returning to m6 puts it back as it was.
var _m6_log_visible: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = HudStyle.PROCESS_PRIORITY
	go_cue = GoCue.new()
	add_child(go_cue)
	cut_in = CutIn.new()
	add_child(cut_in)
	Tuning.changed.connect(_on_tuning_changed)
	CombatEvents.hit_landed.connect(_on_hit_landed)
	CombatEvents.attack_started.connect(combat_log.on_attack_started)
	CombatEvents.attack_whiffed.connect(combat_log.add_whiff)
	CombatEvents.health_changed.connect(_on_health_changed)
	CombatEvents.vanished.connect(_on_vanished)
	CombatEvents.perfect_blocked.connect(_on_perfect_blocked)
	CombatEvents.guard_broken.connect(_on_guard_broken)
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
	_sync_look()
	# The startup help and the over-head bars count game time: they keep their remaining
	# seconds through a pause.
	var game_delta := 0.0 if get_tree().paused else delta
	if _help_auto_hide_left > 0.0:
		_help_auto_hide_left -= game_delta
		if _help_auto_hide_left <= 0.0:
			help_overlay.visible = false
	hurt_overlay.advance(game_delta)
	player_panel.advance(delta)
	_follow_boss()
	boss_bar.advance(delta)
	enemy_bars.advance(game_delta)
	center_dot.refresh(director)
	camera_toast.advance(delta)
	block_callout.advance(game_delta)
	# The warning's pulses run on sim time: held by a pause, stretched by slow-mo and F4's 0.25x.
	rear_warning.advance(game_delta * TimeController.sim_scale())
	# The MASH prompt follows the held player's presses in real time.
	grab_prompt.advance(game_delta)
	# The "LB" cue breathes in game time, like the lettering.
	pickup_cue.advance(game_delta)
	# So does the level's "GO" arrow (and "CLEAR!").
	go_cue.advance(game_delta)
	# The drawn cards (trailer look only) count game time too, and go last: they hold the simulation while up.
	cut_in.advance(game_delta)
	_update_keep_out()


## When the look profile flips (and on the first frame) dress the parts that are not redrawn from the look every frame: under the
## trailer profile the combat log, the HUD's debug line, starts away (L brings it back; hud_m7_log_visible keeps it up) and the help
## overlay takes the caption box's hard shadow. Returning to m6 puts the log back as it was before (an L toggle or a script's choice stays).
func _sync_look() -> void:
	var comic := 1 if HudStyle.comic() else 0
	if comic == _comic_seen:
		return
	if comic == 1 and _comic_seen != 1:
		_m6_log_visible = combat_log.visible
	_comic_seen = comic
	combat_log.visible = Tuning.data.hud_m7_log_visible if comic == 1 else _m6_log_visible
	help_overlay.apply_look()
	queue_redraw_parts()


## Tell the hit words where the HUD's boxes are (HudStyle.keep_out, shares of the view): the player's panel and the boss bar, with the
## hud_m7_pop_clear_px margin. Empty under m6.
func _update_keep_out() -> void:
	HudStyle.keep_out.clear()
	if not HudStyle.comic():
		return
	var view := get_viewport().get_visible_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var margin := Vector2.ONE * Tuning.data.hud_m7_pop_clear_px
	for part: Rect2 in [player_panel.keep_out_rect(), boss_bar.keep_out_rect()]:
		if part.size == Vector2.ZERO:
			continue
		var box := part.grow_individual(margin.x, margin.y, margin.x, margin.y)
		HudStyle.keep_out.append(Rect2(box.position / view, box.size / view))


func _exit_tree() -> void:
	HudStyle.keep_out.clear()


## A live change of the log tunable shows (or puts away) the log under the trailer profile, without a flip of the profile.
func _on_tuning_changed(property: StringName) -> void:
	if (property == &"hud_m7_log_visible" or property == &"") and _comic_seen == 1:
		combat_log.visible = Tuning.data.hud_m7_log_visible


## Redraw every part that caches nothing (they draw each frame while visible; the rest are redrawn on their next event).
func queue_redraw_parts() -> void:
	for child: Node in get_children():
		var item := child as CanvasItem
		if item != null:
			item.queue_redraw()


## Show the bottom-center boss bar for `actor` (the HUD shows it by itself for the live
## actor in group "boss", see _follow_boss()).
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


## CombatEvents.vanished: a KO'd actor that blinked off loses its over-head bar, and the boss
## bar goes with the boss.
func _on_vanished(actor: Node3D) -> void:
	enemy_bars.on_vanished(actor)
	if actor == boss_bar.boss:
		boss_bar.hide_boss()


## Show the boss bar for a live actor in group "boss" that it is not already showing. It is
## not hidden by a boss's death (the bar drains to empty over the lying body) but by its
## vanishing (_on_vanished()), its freeing (BossHealthBar.advance()), or hide_boss().
func _follow_boss() -> void:
	if is_instance_valid(boss_bar.boss) and boss_bar.boss.is_inside_tree() and not boss_bar.boss.is_gone():
		return
	for node: Node in get_tree().get_nodes_in_group(&"boss"):
		var boss := node as CombatActor
		if boss != null and boss.health > 0.0 and not boss.is_gone() and boss != boss_bar.boss:
			boss_bar.show_boss(boss)
			return


func _on_hit_landed(hit: HitInfo) -> void:
	combat_log.add_hit(hit)
	enemy_bars.on_hit_landed(hit)


func _on_perfect_blocked(defender: Node3D, _hit: HitInfo) -> void:
	if is_instance_valid(defender) and defender == player_panel.player:
		block_callout.show_parry()


func _on_guard_broken(defender: Node3D, _hit: HitInfo) -> void:
	if is_instance_valid(defender) and defender == player_panel.player:
		player_panel.on_guard_broken()
		block_callout.show_guard_break()


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
