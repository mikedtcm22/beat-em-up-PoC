extends "res://tests/bot/level_bot.gd"
## The Phase 0 spike's bot (P0-SPIKE): the level bot with ONE act, "Spike: street punk", and none of the base
## run's heavy instruments (no readability probe, no autopilot walking). The act stands the player in the
## street at night, a Street Punk in his guard at about 2 m facing him, then renders the A/B strip at 2560x1440
## through its own SubViewport: (a) the game's plain look, (b) + light, (c) + flat paint, (d) + ink, (e) + LUT.
## See video/spike/spike_look.gd for what each stage changes.
##
##   tools: video/spike/run_spike.sh <out dir> [stages]
##   godot --path <worktree> --fixed-fps 60 --resolution 1280x720 res://video/spike/spike_bot.tscn -- \
##       --level=res://game/level/mission1/mission1.tscn --out=<dir> --stages=abcde
##
## Arguments after `--` (besides the level bot's): `--out=<dir>` (where the PNGs go), `--stages=<letters>`
## (default abcde), `--check=1` (also save the main window's frame beside the stills, for the SubViewport check),
## `--set=<property>=<value>` (override one CineSpikeLookData value for this run; repeatable).

const TourActs := preload("res://tests/bot/level_acts/tour_acts.gd")
const ACT_TITLE := "Spike: street punk"
## Fixed seeds for the comic and audio random generators (they randomise themselves at their own _ready).
const VFX_SEED := 20261108
const AUDIO_SEED := 20261109

@export_group("Output")
## Where the PNGs go (`--out=`), the stages to render in order (`--stages=`), and the window check (`--check=1`).
@export var out_dir: String = "res://captures/video/p0-spike"
@export var stages: String = "abcde"
@export var window_check: bool = false

@onready var look: CineSpikeLook = $Look
@onready var capture: CineSpikeCapture = $Capture


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--stages="):
			stages = arg.trim_prefix("--stages=")
		elif arg.begins_with("--check="):
			window_check = int(arg.trim_prefix("--check=")) != 0
		elif arg.begins_with("--set="):
			# `--set=<CineSpikeLookData property>=<value as GDScript text>`: a one-off override for a look-dev run.
			var pair := arg.trim_prefix("--set=").split("=", true, 1)
			if pair.size() == 2 and pair[0] in look.data:
				look.data.set(pair[0], str_to_var(pair[1]))
	super._ready()
	capture.setup(look.data.capture_size)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))


## Only the spike's act, not the level bot's.
func _collect_acts() -> Array[Dictionary]:
	return [{title = ACT_TITLE, cam = &"first_person", fn = _act_street_punk}]


## The base run without the probe and the pilot's work: the acts, then a clean quit.
func _run() -> void:
	await _ticks(8)
	player = room.get(&"player")
	player.input.scripted = true
	spawner = room.get(&"spawner")
	director = get_tree().get_first_node_in_group(&"camera_director")
	for child in room.get_children():
		if child.has_method(&"set_help_visible"):
			child.call(&"set_help_visible", false)
		if child.has_method(&"set_combat_log_visible"):
			child.call(&"set_combat_log_visible", false)
	_connect_logs()
	set_waves(false)
	pilot = Pilot.new()
	pilot.enabled = false
	pilot.enemy_group = &"ai_enemy"
	pilot.attach(self, player)
	for knob: StringName in PILOT_KNOBS:
		_pilot_defaults[knob] = pilot.get(knob)
	for act in _collect_acts():
		if act_filter != "" and not _matches(act.title):
			continue
		await _reset(act.cam)
		print("=== %s  (f%d)" % [act.title, Engine.get_physics_frames()])
		var fn: Callable = act.fn
		await fn.call()
	await _ticks(10)
	await _quit()


func _act_street_punk() -> void:
	var d := look.data
	# Determinism: fixed seeds, no shake, no hurt feel, nobody attacking.
	var vfx := get_tree().get_first_node_in_group(&"vfx_director")
	if vfx != null:
		vfx.rng.seed = VFX_SEED
	var audio := get_tree().get_first_node_in_group(&"audio_director")
	if audio != null:
		audio.rng.seed = AUDIO_SEED
	tune(&"screen_shake_intensity", 0.0)
	tune(&"hurt_feel_enabled", false)
	tune(&"show_center_dot", false)
	god(true)
	freeze_ai(true)
	var hud := level.get_node_or_null("Hud")
	if hud != null:
		hud.set(&"visible", false)
	caption.get_parent().visible = false
	# The player on the street at the start, looking down it; wait out the section light.
	var section: Node3D = level.sections[0]
	var at := section.global_position + d.player_at
	var yaw := deg_to_rad(d.player_yaw_deg)
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw
	player.look_yaw = yaw
	player.look_pitch = deg_to_rad(d.player_pitch_deg)
	await TourActs.settle_light(self, section, at)
	# The Punk, in his guard (the boxer idle), facing the player.
	var punk := spawn(&"punk", d.punk_rel)
	await _ticks(d.punk_settle_ticks)
	freeze_ai(true)
	look.set_punk_feet(punk.global_position)
	log_line("SPIKE punk at %s player at %s dist %.2f" % [punk.global_position, player.global_position, punk.global_position.distance_to(player.global_position)])
	if d.player_guard_ticks > 0:
		player.input.push_down(&"DODGE")
		await _ticks(d.player_guard_ticks)
	# Hold the world still so every stage is the same instant.
	TimeController.debug_scale = 0.0
	await _ticks(4)
	look.setup(level, func() -> Camera3D: return get_viewport().get_camera_3d())
	look.set_punk_feet(punk.global_position)
	for letter in stages:
		var which := StringName(letter)
		look.apply_stage(which)
		await _ticks(d.stage_settle_ticks)
		var path := out_dir.path_join("%s.png" % letter)
		var err := await capture.shoot(ProjectSettings.globalize_path(path))
		var sun := level.get_node_or_null("Sun") as DirectionalLight3D
		if sun != null:
			log_line("SPIKE sun e=%.2f c=%s rot=%s" % [sun.light_energy, sun.light_color, sun.rotation_degrees])
		log_line("SPIKE stage %s -> %s (%s) f%d" % [letter, path, error_string(err), Engine.get_physics_frames()])
		if window_check and (letter == "a" or letter == "e"):
			await capture.shoot_window(ProjectSettings.globalize_path(out_dir.path_join("window_%s.png" % letter)))
	TimeController.debug_scale = 1.0
