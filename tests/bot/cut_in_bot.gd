extends Node
## Milestone 7, Phase 3 (C5): the drawn cards in play. Mission 1's street under the trailer profile with the cards on, waves off
## and the AI frozen: the mission title on the first frame, a Punk's entrance (skipped by a punch), a Thug's (no art yet: silent),
## a knockout panel at each of the first two arena clears, Ox (no art yet: silent) and the mission end, held until a kick.
## It writes `C5-BOT` lines (each card at its frame, the simulation's scale while it is up, PASS / FAIL checks) and quits.
## Record it with tools/capture_bot.sh (docs/milestones/M7-calls/c5.md has the command and the stills):
##   tools/capture_bot.sh res://tests/bot/cut_in_bot.tscn captures/m7-comic/c5 "" 3
## `--profile=m6` runs the same script with the cards off (no card should appear); `--tune=<property>=<number>` is as in the other bots;
## `--full-entrance` lets the Punk's entrance card hold its full time instead of skipping it with a punch.

const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
## A frame count that outlasts any card's hold at the default tunables (the title holds longest, 1.5 s = 90 frames).
const LONG_WAIT := 140
const SETTLE := 30

var _level: LevelRoot
var _cut_in: CutIn
var _cards: Array = []
var _fails: int = 0
var _profile: int = 1
## `--full-entrance`: let the Punk's entrance card run its whole hold instead of punching through it (for recordings).
var _full_entrance: bool = false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			_profile = 0 if arg.ends_with("m6") else 1
		elif arg == "--full-entrance":
			_full_entrance = true
		elif arg.begins_with("--tune="):
			var pair := arg.trim_prefix("--tune=").split("=")
			if pair.size() == 2:
				Tuning.set_value(StringName(pair[0]), float(pair[1]))
	Tuning.set_value(&"waves_enabled", false)
	Tuning.set_value(&"god_mode", true)
	Tuning.set_value(&"ai_frozen", true)
	Tuning.set_value(&"look_profile", _profile)
	_level = (load(LEVEL_PATH) as PackedScene).instantiate() as LevelRoot
	_level.waves_enabled_on_start = false
	add_child(_level)
	_cut_in = _level.find_children("*", "GameHud", true, false)[0].cut_in
	# The title went up in the HUD's own _ready, before this connect: count it from the history.
	for card in _cut_in.history:
		_on_started(card.kind, card.key)
	_cut_in.card_started.connect(_on_started)
	_cut_in.card_ended.connect(_on_ended)
	_run()


func _on_started(kind: int, key: StringName) -> void:
	var name_of: String = CutIn.Kind.keys()[kind]
	_cards.append("%s:%s" % [name_of, key])
	print("C5-BOT f%d card_started %s %s sim_scale=%.1f" % [Engine.get_physics_frames(), name_of, key, TimeController.sim_scale()])


func _on_ended(kind: int, key: StringName, skipped: bool) -> void:
	print("C5-BOT f%d card_ended %s %s skipped=%s" % [Engine.get_physics_frames(), CutIn.Kind.keys()[kind], key, skipped])


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	print("C5-BOT %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


func _spawn(id: StringName, at: Vector3) -> EnemyActor:
	var street := _level.sections[0]
	return _level.spawner.spawn_enemy(id, street.to_global(at), PI)


func _knock_out(enemy: EnemyActor) -> void:
	var hit := HitInfo.new()
	hit.attacker = _level.player
	hit.victim = enemy
	hit.damage = 9999.0
	hit.tier = CombatTypes.HitTier.HEAVY
	hit.reaction = CombatTypes.Reaction.LAUNCH
	hit.direction = Vector3.FORWARD
	hit.knockback = Vector3.FORWARD * 3.0 + Vector3.UP * 3.0
	hit.contact_point = enemy.global_position + Vector3.UP
	enemy.receive_hit(hit)


func _run() -> void:
	var on := _profile == 1
	await _ticks(2)
	_check(on == _cut_in.is_showing() and (not on or _cut_in.current_kind() == CutIn.Kind.TITLE), "the title is up on the first frame (cards %s)" % ("on" if on else "off"))
	var held := TimeController.sim_scale() == 0.0
	_check(held == on, "the simulation holds while a card is up (sim_scale %.1f)" % TimeController.sim_scale())
	await _ticks(LONG_WAIT)
	_check(not _cut_in.is_showing(), "the title went down by itself after its hold")
	_check(TimeController.sim_scale() == 1.0, "and the simulation runs again")

	# Entrances: the first Punk, skipped by a punch; the second brings none; the Thug has no art yet.
	var punk := _spawn(&"punk", Vector3(0.0, 0.0, -4.0))
	await _ticks(SETTLE)
	_check(_cut_in.is_showing() == on, "the first Punk's entrance card is up")
	if _full_entrance:
		await _ticks(LONG_WAIT)
		_check(not _cut_in.is_showing(), "it went down by itself after its hold")
	else:
		_press(&"punch")
		await _ticks(4)
		_check(not _cut_in.is_showing(), "a punch skips it")
	var second := _spawn(&"punk", Vector3(1.5, 0.0, -6.0))
	var thug := _spawn(&"thug", Vector3(-1.5, 0.0, -7.0))
	await _ticks(SETTLE)
	_check(not _cut_in.is_showing(), "a second Punk and a Thug (no art yet) bring no card")

	# Knockout panels at the first two arena clears.
	var arenas := _level.arenas()
	_knock_out(punk)
	await _ticks(SETTLE)
	arenas[0].clear()
	await _ticks(SETTLE)
	_check(_cut_in.is_showing() == on, "the first arena's clear shows a knockout panel")
	await _ticks(SETTLE)
	_check(not _cut_in.is_showing(), "which holds 0.5 s and goes down")
	_knock_out(second)
	await _ticks(SETTLE)
	arenas[1].clear()
	await _ticks(SETTLE)
	_check(_cut_in.is_showing() == on, "the second arena's clear shows the next panel")
	await _ticks(SETTLE * 2)

	# Ox: no art assigned yet, so no card.
	var ox := _spawn(&"boss", Vector3(0.0, 0.0, -9.0))
	await _ticks(SETTLE)
	_check(not _cut_in.is_showing(), "Ox's name card waits for its art (skipped silently)")
	if is_instance_valid(ox):
		EncounterSpawner.remove_enemy(ox)
	if is_instance_valid(thug):
		EncounterSpawner.remove_enemy(thug)

	# The mission end holds until a button.
	CombatEvents.level_cleared.emit(_level)
	await _ticks(LONG_WAIT * 2)
	_check(_cut_in.is_showing() == on, "the mission end card is still up long after its event")
	_press(&"kick")
	await _ticks(4)
	_check(not _cut_in.is_showing(), "a kick takes it down")
	_check(TimeController.sim_scale() == 1.0, "the simulation runs again")
	await _ticks(SETTLE)

	var expected: Array = ["TITLE:title", "ENTRANCE:punk", "KO:punk", "KO:punk", "END:mission_end"] if on else []
	_check(_cards == expected, "each card fired once at its event: %s" % [_cards])
	print("C5-BOT done profile=%s fails=%d" % [LookProfile.profile_name(), _fails])
	get_tree().quit(1 if _fails > 0 else 0)
