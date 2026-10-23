extends "res://tests/bot/combo_bot.gd"
## Comic-VFX acts (Milestone 2 WP2) for review captures, built on the combo bot's harness:
## every tier's burst and lettering, blood, spit and tooth, speed lines and the impact frame,
## the damage looks stepping from clean to bruised to bloodied, the block sparks, and the
## lunge lines, in first person and side view. Record it with Movie Maker:
##   godot --path . --write-movie captures/vfx.avi --fixed-fps 60 --resolution 1280x720 \
##     res://tests/bot/vfx_bot.tscn [-- --act=<title text>]
## The effects' random generator is seeded, so a capture is repeatable.

var vfx: VfxDirector


func _run() -> void:
	await _ticks(3)
	player = room.get(&"player")
	player.input.scripted = true
	dummies.assign(room.get(&"dummies"))
	director = get_tree().get_first_node_in_group(&"camera_director")
	vfx = get_tree().get_first_node_in_group(VfxDirector.GROUP) as VfxDirector
	for child in room.get_children():
		if child.has_method(&"set_help_visible"):
			child.call(&"set_help_visible", false)
	var acts: Array[Dictionary] = [
		{title = "VFX: P P P P, light to finisher", cam = &"first_person", fn = _act_pppp},
		{title = "VFX: P P P P (side view)", cam = &"side_view", fn = _act_pppp},
		{title = "VFX: K K K, spinning heel finisher (side view)", cam = &"side_view", fn = _act_kkk},
		{title = "VFX: haymaker to the head: spit and tooth", cam = &"first_person", fn = _act_haymaker},
		{title = "VFX: haymaker (side view)", cam = &"side_view", fn = _act_haymaker},
		{title = "VFX: damage looks, clean to bruised to bloodied", cam = &"first_person", fn = _act_damage_looks},
		{title = "VFX: damage looks (side view)", cam = &"side_view", fn = _act_damage_looks},
		{title = "VFX: block spark", cam = &"first_person", fn = _act_block},
		{title = "VFX: parry spark", cam = &"first_person", fn = _act_perfect_block},
		{title = "VFX: guard break burst", cam = &"first_person", fn = _act_guard_break},
		{title = "VFX: guard break burst (side view)", cam = &"side_view", fn = _act_guard_break},
		{title = "VFX: flying kick, lunge lines", cam = &"first_person", fn = _act_flying_kick},
		{title = "VFX: P P P P, impact frame off", cam = &"first_person", fn = _act_impact_frame_off},
	]
	for act in acts:
		var title: String = act.title
		if act_filter != "" and not title.to_lower().contains(act_filter.to_lower()):
			continue
		await _reset(act.cam)
		caption.text = title
		print("=== ", title)
		var fn: Callable = act.fn
		await fn.call()
		await _wait_idle()
		await _ticks(45)
	caption.text = "done"
	await _ticks(10)
	print("\n".join(log_lines))
	get_tree().quit()


func _reset(cam: StringName) -> void:
	await super._reset(cam)
	if vfx:
		vfx.clear()
		vfx.rng.seed = 7


## The front dummy at its real health: single jabs with pauses, so its look steps from
## clean to bruised (at 66%) to bloodied (at 33%), then a held look at it.
func _act_damage_looks() -> void:
	await _stage([Vector3(0, 0, -1.4)])
	var dummy := dummies[0]
	dummy.max_health = 30.0
	dummy.reset_state()
	await _look_to(-4.0, 6)
	for i in 4:
		await _press(&"P", 2)
		await _wait_idle()
		await _ticks(40)
	await _ticks(60)


func _act_impact_frame_off() -> void:
	Tuning.data.impact_frame_enabled = false
	await _act_pppp()
	await _wait_idle()
	Tuning.data.impact_frame_enabled = true
