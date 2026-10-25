extends "res://tests/bot/combo_bot.gd"
## Comic-VFX acts (Milestone 2 WP2) for review captures, built on the combo bot's harness:
## every tier's burst and lettering, blood, spit and tooth, speed lines and the impact frame,
## the damage looks stepping from clean to bruised to bloodied, the block sparks, and the
## lunge lines (and a plain jab step-in that must show none), the tier sizes side by side,
## knees and a stomp under the first-person view, and words of hits outside the view, in
## first person and side view. Record it with Movie Maker:
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
	# The help overlay and the combat log would cover the effects (the bot logs the hits).
	for child in room.get_children():
		if child.has_method(&"set_help_visible"):
			child.call(&"set_help_visible", false)
		if child.has_method(&"set_combat_log_visible"):
			child.call(&"set_combat_log_visible", false)
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
		{title = "VFX: jab step-in, no lunge lines", cam = &"first_person", fn = _act_jab_step},
		{title = "VFX: damage looks held at 1 m", cam = &"first_person", fn = _act_damage_held},
		{title = "VFX: damage looks held (side view)", cam = &"side_view", fn = _act_damage_held},
		{title = "VFX: tier sizes side by side (first person)", cam = &"first_person", fn = _act_tier_sizes},
		{title = "VFX: tier sizes side by side (side view)", cam = &"side_view", fn = _act_tier_sizes},
		{title = "VFX: knees under the view", cam = &"first_person", fn = _act_grab},
		{title = "VFX: stomp under the view", cam = &"first_person", fn = _act_stomp},
		{title = "VFX: back elbow, word stays behind", cam = &"first_person", fn = _act_back_elbow},
		{title = "VFX: spin kick, three dummies", cam = &"first_person", fn = _act_spin_kick},
	]
	for act in acts:
		var title: String = act.title
		if act_filter != "" and not _matches(title):
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


## One jab from 1.6 m: the magnetism step-in carries the player about 0.75 m, which is no
## lunge (no lunge lines; the flying kick's lunge has them).
func _act_jab_step() -> void:
	await _stage([Vector3(0, 0, -1.6)])
	await _ticks(10)
	await _press(&"P", 2)
	await _wait_idle()
	await _ticks(30)


## The front dummy 1 m away, standing, shown clean, bruised (65% health) and bloodied (30%)
## for a second each, then a jab on the bloodied look (the hit flash covers it).
func _act_damage_held() -> void:
	await _stage([Vector3(0, 0, -1.0)])
	var dummy := dummies[0]
	dummy.max_health = 30.0
	dummy.reset_state()
	await _look_to(-8.0, 6)
	for share: float in [1.0, 0.65, 0.3]:
		dummy.health = dummy.max_health * share
		CombatEvents.health_changed.emit(dummy, dummy.health, dummy.max_health)
		await _ticks(60)
	await _press(&"P", 2)
	await _wait_idle()
	await _ticks(20)


## Three dummies side by side, hit at once by a light, a heavy and a finisher hit
## (synthetic HitInfo at each chest, no damage): the three burst sizes next to each other.
## In first person they stand 3 m ahead, then 1.4 m; in the side view one behind the other
## along the street, 1.6 m apart.
func _act_tier_sizes() -> void:
	var side: bool = director != null and director.get(&"mode") == &"side_view"
	for depth: float in ([1.6] if side else [3.0, 1.4]):
		if side:
			await _stage([Vector3(0, 0, -depth), Vector3(0, 0, -depth * 2.0), Vector3(0, 0, -depth * 3.0)])
		else:
			await _stage([Vector3(-1.1, 0, -depth), Vector3(0, 0, -depth), Vector3(1.1, 0, -depth)])
		await _ticks(10)
		for i in 3:
			var hit := HitInfo.new()
			hit.attacker = player
			hit.victim = dummies[i]
			hit.tier = i as CombatTypes.HitTier
			hit.region = CombatTypes.Region.TORSO
			hit.contact_point = dummies[i].get_chest_position()
			hit.direction = (dummies[i].global_position - player.global_position).normalized()
			CombatEvents.hit_landed.emit(hit)
		await _ticks(50)


func _act_impact_frame_off() -> void:
	Tuning.data.impact_frame_enabled = false
	await _act_pppp()
	await _wait_idle()
	Tuning.data.impact_frame_enabled = true
