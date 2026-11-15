extends Node
## Milestone 7 (e-hud): stills of every HUD element in Mission 1's street (a look-dev stage, not a test). The level with the waves off
## and the AI frozen, the HUD on; each station sets one element up through the HUD's own API (never its state) and saves the
## viewport. Run it once per profile, windowed, with Movie Maker for the fixed step:
##   godot --path . --write-movie /tmp/hud.avi --fixed-fps 60 --resolution 1600x900 res://tests/fixtures/m7/hud_stage.tscn -- --out=<dir> [--profile=m6]
## Stills land as <dir>/<profile>_NN_<name>.png.
const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const PLAYER_AT := Vector3(-2.0, 0.0, -25.0)

var _out: String = "res://captures/m7-comic/e-hud/stills"
var _profile: int = 1
var _level: LevelRoot
var _hud: GameHud
var _shots: int = 0
var _punk: CombatActor
var _boss: CombatActor


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a == "--profile=m6":
			_profile = 0
	Tuning.set_value(&"waves_enabled", false)
	Tuning.set_value(&"god_mode", true)
	Tuning.set_value(&"ai_frozen", true)
	Tuning.set_value(&"look_profile", _profile)
	Tuning.set_value(&"cutins_enabled", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out)
	_level = (load(LEVEL_PATH) as PackedScene).instantiate() as LevelRoot
	_level.waves_enabled_on_start = false
	add_child(_level)
	_run()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_shots += 1
	var name := "%s_%02d_%s.png" % ["trailer" if _profile == 1 else "m6", _shots, label]
	get_viewport().get_texture().get_image().save_png(_out.path_join(name))
	print("HUD-STAGE ", name)


func _run() -> void:
	await _frames(20)
	_hud = _level.find_children("*", "GameHud", true, false)[0] as GameHud
	var player := _level.player
	var street := _level.sections[0]
	player.reset_state()
	player.global_position = street.to_global(PLAYER_AT)
	player.rotation.y = 0.0
	player.look_yaw = 0.0
	player.look_pitch = deg_to_rad(4.0)
	_hud.set_help_visible(false)
	_punk = _level.spawner.spawn_enemy(&"punk", street.to_global(PLAYER_AT + Vector3(0.0, 0.0, -2.6)), PI)
	await _frames(40)
	await _shot("full_health")

	# Half health, mid-hit: the chunk hangs where the lost health was, then drops away.
	player.health = 50.0
	CombatEvents.health_changed.emit(player, 50.0, player.max_health)
	await _frames(8)
	await _shot("half_health_chunk_hangs")
	await _frames(24)
	await _shot("half_health_chunk_falls")
	await _frames(30)
	await _shot("half_health_settled")

	# The pick-up cue, then the durability pips, then the guard meter.
	var pipe := PipeThug.PIPE_SCENE.instantiate() as Weapon
	_level.add_child(pipe)
	pipe.global_position = player.global_position + Vector3(0.0, 0.1, -0.7)
	await _frames(45)
	await _shot("pickup_cue")
	player.call(&"_pick_up", pipe)
	pipe.durability = 5
	player.guard = player.max_guard() * 0.4
	await _frames(20)
	await _shot("pips_and_guard")

	# The enemy's over-head bar.
	_punk.health = _punk.max_health * 0.55
	CombatEvents.health_changed.emit(_punk, _punk.health, _punk.max_health)
	await _frames(6)
	await _shot("enemy_bar_chunk")

	# The boss bar, with a chunk.
	_boss = _level.spawner.spawn_enemy(&"boss", street.to_global(PLAYER_AT + Vector3(2.0, 0.0, -6.0)), PI)
	await _frames(30)
	_boss.health = _boss.max_health * 0.62
	CombatEvents.health_changed.emit(_boss, _boss.health, _boss.max_health)
	await _frames(8)
	await _shot("boss_bar")
	await _frames(40)
	await _shot("boss_bar_settled")
	EncounterSpawner.remove_enemy(_boss)
	_hud.hide_boss()
	player.guard = player.max_guard()

	# The level's cues and callouts.
	_hud.go_cue.show_go(player.global_position + Vector3(0.0, 0.0, -12.0))
	await _frames(12)
	await _shot("go_cue")
	_hud.go_cue.show_clear()
	await _frames(12)
	await _shot("clear")
	_hud.go_cue.visible = false
	_hud.block_callout.show_parry()
	await _frames(8)
	await _shot("parry_callout")
	_hud.block_callout.show_guard_break()
	await _frames(8)
	await _shot("guard_break_callout")
	_hud.block_callout.visible = false
	_hud.camera_toast.show_mode(&"first_person")
	await _frames(4)
	await _shot("camera_toast")
	_hud.camera_toast.visible = false
	# The HUD stops stepping so the prompt (which only follows a held player) stays up for the still.
	_hud.set_process(false)
	_hud.grab_prompt.visible = true
	_hud.grab_prompt.gauge.reset(0.0)
	_hud.grab_prompt.gauge.set_target(0.6)
	_hud.grab_prompt.queue_redraw()
	await _frames(3)
	await _shot("grab_prompt")
	_hud.grab_prompt.visible = false
	_hud.set_process(true)
	_hud.pause_overlay.set_paused(true)
	await _frames(3)
	await _shot("pause_caption")
	_hud.pause_overlay.set_paused(false)
	_hud.set_help_visible(true)
	await _frames(3)
	await _shot("help_overlay")
	_hud.set_help_visible(false)
	_hud.set_combat_log_visible(true)
	await _frames(3)
	await _shot("combat_log_key_l")
	print("HUD-STAGE done")
	get_tree().quit()
