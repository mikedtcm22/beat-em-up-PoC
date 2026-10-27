extends GutTest
## The long take and the F4 Showcase Punk (P3-early): ShowcaseScript is the take as data, ShowcaseRunner
## plays it on a Punk's rig by hand, and the cheat menu's "Showcase Punk at 1 m" is a frozen Punk 1 m
## ahead looping it. The look act "Look: Punk at 1 m, the long take" plays the same script (its
## tests are in test_look_acts.gd). The showcase must leave the game exactly as it was when it is
## switched off, in both rooms.

const CROWD_PATH := "res://game/level/crowd_room.tscn"
const TRAINING_PATH := "res://game/level/test_room.tscn"
const FRAME := 1.0 / 60.0
## The beats the final judgement asks for, in their order (names of steps of the take).
const BEATS: Array[StringName] = [
	&"idle", &"turntable", &"walk_in", &"taunt", &"jab", &"cross", &"takes_jab", &"stagger", &"knockdown",
	&"lying", &"get_up", &"falls_forward", &"lying_face_down", &"get_up_face_down", &"ko",
]


func before_each() -> void:
	Tuning.reset_to_default()
	Tuning.set_value(&"waves_enabled", false)
	Tuning.set_value(&"god_mode", false)
	TimeController.clear()
	GameInput.menu_open = false


func after_each() -> void:
	GameInput.menu_open = false
	Tuning.reset_to_default()
	TimeController.clear()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## A Street Punk of the catalog in the tree, off its own tick and out of the enemy groups, at the origin
## facing -Z (the way the cheat menu leaves it), with a runner playing the take.
func _punk(loop: bool = true) -> ShowcaseRunner:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var punk := EnemyCatalog.scene(&"punk").instantiate() as EnemyActor
	punk.name = "ShowcasePunk"
	holder.add_child(punk)
	ShowcaseRunner.unplug(punk)
	var runner := ShowcaseRunner.new()
	runner.auto_advance = false
	punk.add_child(runner)
	runner.setup(punk, Transform3D.IDENTITY, loop)
	return runner


func _crowd() -> CrowdRoom:
	var room := (load(CROWD_PATH) as PackedScene).instantiate() as CrowdRoom
	room.with_presentation = false
	room.waves_enabled_on_start = false
	add_child_autofree(room)
	await _ticks(5)
	room.player.input.scripted = true
	return room


func _training() -> Node3D:
	var room := (load(TRAINING_PATH) as PackedScene).instantiate() as Node3D
	room.set(&"with_presentation", false)
	add_child_autofree(room)
	await _ticks(2)
	var player: PlayerCharacter = room.get(&"player")
	player.input.scripted = true
	var dummies: Array[TrainingDummy] = []
	dummies.assign(room.get(&"dummies"))
	for i in dummies.size():
		dummies[i].sparring = false
		dummies[i].set_post(Vector3(30.0 + float(i) * 3.0, 0.0, -30.0), 0.0, true)
	await _ticks(2)
	return room


func _menu(room: Node3D) -> CheatMenu:
	var menu := CheatMenu.new()
	menu.world = room
	add_child_autofree(menu)
	return menu


## What a room looks like to the systems the showcase must not disturb.
func _snapshot(room: Node3D) -> Dictionary:
	var out := {
		ai_frozen = Tuning.data.ai_frozen,
		waves = Tuning.data.waves_enabled,
		enemies = get_tree().get_nodes_in_group(&"enemy").size(),
		ai_enemies = get_tree().get_nodes_in_group(&"ai_enemy").size(),
		actors = get_tree().get_nodes_in_group(&"actor").size(),
		bosses = get_tree().get_nodes_in_group(&"boss").size(),
		children = room.get_child_count(),
		god = Tuning.data.god_mode,
	}
	var director := room.get(&"director") as EnemyDirector
	if director:
		out.holders = director.debug_token_holders().size()
		out.waiting = director.debug_waiting().size()
	var spawner := room.get(&"spawner") as EncounterSpawner
	if spawner:
		out.alive = spawner.alive_count()
	return out


# --- The script ---------------------------------------------------------------------------------------


func test_the_take_has_every_beat_of_the_judgement_in_order() -> void:
	var names: Array[StringName] = []
	for step: Dictionary in ShowcaseScript.steps():
		names.append(step.name)
	var last := -1
	for beat: StringName in BEATS:
		var at := names.find(beat)
		assert_gt(at, last, "%s comes after the beat before it" % beat)
		last = at
	var unique := {}
	for name: StringName in names:
		assert_false(unique.has(name), "%s is the name of one step" % name)
		unique[name] = true


func test_every_step_is_playable_and_the_take_is_about_forty_seconds() -> void:
	var runner := _punk()
	var rig := runner.actor.rig
	var total := 0.0
	for i: int in runner.step_count():
		var step: Dictionary = ShowcaseScript.STEPS[i]
		var seconds := runner.seconds_of_step(i)
		assert_gt(seconds, 0.0, "%s lasts" % step.name)
		total += seconds
		assert_has([&"stand", &"walk", &"clip", &"move"], step.kind, "%s has a kind the runner plays" % step.name)
		if step.kind == &"clip":
			assert_true(rig.anim_player.has_animation(step.anim), "%s: the clip %s exists" % [step.name, step.anim])
		if step.kind == &"move":
			assert_not_null(ShowcaseScript.move_of(step), "%s: the move loads" % step.name)
		if step.kind == &"walk":
			assert_gt(ShowcaseScript.pace_of(step), 0.0, "%s: a pace from Tuning" % step.name)
		if step.has("hit_point"):
			assert_true(PlaceholderBody.POINT_BONE.has(step.hit_point), "%s: a rig point" % step.name)
	assert_almost_eq(total, runner.take_seconds(), 0.001, "the runner's length is the sum")
	assert_almost_eq(total, ShowcaseScript.TAKE_SECONDS, ShowcaseScript.TAKE_TOLERANCE_S, "the take is about %.0f s (%.1f)" % [ShowcaseScript.TAKE_SECONDS, total])
	print("SHOWCASE the take is %.2f s in %d steps" % [total, runner.step_count()])


func test_the_table_cannot_be_changed_through_steps() -> void:
	var steps := ShowcaseScript.steps()
	steps[0].seconds = 99.0
	assert_ne(float(ShowcaseScript.STEPS[0].seconds), 99.0)


# --- The runner ---------------------------------------------------------------------------------------


func test_the_runner_plays_every_step_in_order_and_loops() -> void:
	var runner := _punk()
	var started: Array[int] = []
	var finished := [0]
	runner.step_started.connect(func(i: int, _name: StringName) -> void: started.append(i))
	runner.take_finished.connect(func() -> void: finished[0] += 1)
	var ticks := ceili(runner.take_seconds() * 2.0 / FRAME) + 120
	for i: int in ticks:
		runner.advance(FRAME)
	var expected: Array[int] = []
	for i: int in runner.step_count():
		expected.append(i)
	assert_eq(started.slice(0, runner.step_count()), expected, "the steps begin in order")
	assert_eq(finished[0], 2, "two takes in two takes' time")
	assert_eq(runner.takes, 2)
	assert_gt(started.size(), runner.step_count() * 2, "and the third begins")


func test_a_take_that_does_not_loop_ends_and_stays() -> void:
	var runner := _punk(false)
	var ticks := ceili(runner.take_seconds() / FRAME) + 30
	for i: int in ticks:
		runner.advance(FRAME)
	assert_true(runner.is_finished())
	assert_eq(runner.takes, 1)
	assert_eq(runner.index, -1)
	var at := runner.actor.global_position
	runner.advance(FRAME)
	assert_eq(runner.actor.global_position, at, "nothing moves once it has ended")


func test_the_turntable_turns_the_punk_once_round_and_a_walk_goes_the_distance() -> void:
	var runner := _punk()
	var actor := runner.actor
	var start_yaw := actor.global_rotation.y
	var yaws: Array[float] = []
	var steps := {}
	runner.step_started.connect(func(i: int, _name: StringName) -> void: steps[i] = actor.global_position)
	var by_name: Dictionary[StringName, int] = {}
	for i: int in runner.step_count():
		by_name[ShowcaseScript.STEPS[i].name] = i
	var turn_ticks := ceili(runner.seconds_of_step(by_name[&"turntable"]) / FRAME)
	# Idle through, then the turntable.
	for i: int in ceili(runner.seconds_of_step(by_name[&"idle"]) / FRAME) + 1:
		runner.advance(FRAME)
	assert_eq(runner.current_step().name, &"turntable")
	var travelled := 0.0
	var last := actor.global_rotation.y
	for i: int in turn_ticks - 2:
		runner.advance(FRAME)
		travelled += wrapf(actor.global_rotation.y - last, -PI, PI)
		last = actor.global_rotation.y
	assert_almost_eq(rad_to_deg(travelled), 360.0, 12.0, "once round (%.0f degrees)" % rad_to_deg(travelled))
	assert_almost_eq(actor.global_position, Vector3.ZERO, Vector3.ONE * 0.001, "on the spot while it turns")
	# The back-off and the walk-in: 1.2 m away along its facing and back.
	var furthest := 0.0
	for i: int in ceili((runner.seconds_of_step(by_name[&"back_off"]) + runner.seconds_of_step(by_name[&"walk_in"])) / FRAME) + 6:
		runner.advance(FRAME)
		furthest = maxf(furthest, actor.global_position.distance_to(Vector3.ZERO))
	assert_almost_eq(furthest, 1.2, 0.05, "it backs off 1.2 m (%.2f)" % furthest)
	assert_lt(actor.global_position.distance_to(Vector3.ZERO), 0.1, "and walks back in to its spot")
	assert_almost_eq(wrapf(actor.global_rotation.y - start_yaw, -PI, PI), 0.0, 0.02, "facing as it did")
	yaws.clear()


func test_the_lying_bodies_lie_where_the_lens_sees_them() -> void:
	# A lying Punk is a metre long each way of where it falls (the clips' ends: head 1 m behind the
	# hips, feet 1 m before them): the knockdowns slide it, so it lies 1 m or more from the lens
	# wherever it falls. The player stands 1 m ahead of the Punk's spot (-Z, the way it faces).
	var runner := _punk()
	var actor := runner.actor
	var player := Vector3(0.0, 0.0, -1.0)
	var away := {}
	runner.step_started.connect(func(_i: int, name: StringName) -> void: away[name] = actor.global_position.distance_to(player))
	for i: int in ceili(runner.take_seconds() / FRAME) - 4:
		runner.advance(FRAME)
	assert_almost_eq(float(away[&"idle"]), 1.0, 0.01, "the Punk stands 1 m from the player for the idle")
	assert_almost_eq(float(away[&"jab"]), 1.0, 0.05, "and for its punches")
	assert_almost_eq(float(away[&"takes_jab"]), 1.0, 0.05, "and when it takes the jab")
	assert_gt(float(away[&"lying"]), 2.3, "the first knockdown carries it back (%.2f m)" % away[&"lying"])
	assert_almost_eq(float(away[&"walk_in_again"]), float(away[&"lying"]), 0.1, "it gets up where it lay")
	assert_almost_eq(float(away[&"guard_third"]), 1.0, 0.1, "and walks back in to 1 m")
	assert_gt(float(away[&"lying_face_down"]), 1.9, "the face-down fall goes away from the lens (%.2f m)" % away[&"lying_face_down"])
	assert_gt(float(away[&"ko"]), 1.9, "and the KO falls where the whole body is in view (%.2f m)" % away[&"ko"])


func test_the_take_is_the_same_every_run() -> void:
	var a := _punk()
	var b := _punk()
	var worst := 0.0
	for i: int in ceili(a.take_seconds() / FRAME):
		a.advance(FRAME)
		b.advance(FRAME)
		for point: StringName in [&"EyePoint", &"LeftFistPoint", &"RightFistPoint", &"LeftFootPoint", &"ChestPoint"]:
			worst = maxf(worst, a.actor.rig.get_point_position(point).distance_to(b.actor.rig.get_point_position(point)))
	assert_lt(worst, 1e-5, "two Punks of one name play identical frames (%.6f m)" % worst)


func test_the_contact_flash_shows_for_a_hits_frames_and_the_damage_look_steps() -> void:
	var runner := _punk()
	var rig := runner.actor.rig
	var by_name: Dictionary[StringName, int] = {}
	for i: int in runner.step_count():
		by_name[ShowcaseScript.STEPS[i].name] = i
	var flash_frames := 0
	var looks := {}
	runner.step_started.connect(func(_i: int, name: StringName) -> void: looks[name] = rig.damage_look)
	for i: int in ceili(runner.take_seconds() / FRAME) - 4:
		runner.advance(FRAME)
		if runner.current_step().get("name", &"") == &"takes_jab" and rig.paint.base_materials()[0].next_pass != null:
			flash_frames += 1
	assert_eq(flash_frames, Tuning.data.hit_flash_frames, "the flash shows for hit_flash_frames rendered frames")
	assert_eq(looks[&"idle"], DamageLook.Level.CLEAN, "clean to begin with")
	assert_eq(looks[&"jab"], DamageLook.Level.CLEAN, "and through its own punches")
	assert_eq(looks[&"takes_jab"], DamageLook.Level.BRUISED, "bruised from the jab")
	assert_eq(looks[&"stagger"], DamageLook.Level.BRUISED)
	assert_eq(looks[&"get_up"], DamageLook.Level.BLOODIED, "bloodied once it is down")
	assert_eq(looks[&"ko"], DamageLook.Level.BLOODIED, "and it is bloodied at the KO")


func test_a_new_take_starts_whole() -> void:
	var runner := _punk()
	for i: int in ceili(runner.take_seconds() / FRAME) + 20:
		runner.advance(FRAME)
	assert_gte(runner.takes, 1)
	assert_eq(runner.actor.rig.damage_look, DamageLook.Level.CLEAN, "clean again at the loop")
	assert_true(runner.actor.rig.visible)
	assert_eq(runner.current_step().name, &"idle", "back to the idle")
	assert_lt(runner.actor.global_position.distance_to(Vector3.ZERO), 0.01, "on its spot")


func test_the_runner_follows_the_time_scale_and_stops_when_time_does() -> void:
	var runner := _punk()
	runner.auto_advance = true
	await _ticks(6)
	var played := runner.elapsed
	assert_gt(played, 0.0, "it runs on the physics tick")
	TimeController.debug_scale = 0.25
	var before := runner.elapsed
	await _ticks(40)
	var slow := runner.elapsed - before
	assert_almost_eq(slow, 40.0 * FRAME * 0.25, 0.03, "a quarter of the speed at F4's 0.25x (%.3f s)" % slow)
	TimeController.debug_scale = 0.0
	before = runner.elapsed
	await _ticks(10)
	assert_eq(runner.elapsed, before, "stopped at 0")
	TimeController.debug_scale = 1.0


# --- The cheat ----------------------------------------------------------------------------------------


func test_the_showcase_stands_a_metre_ahead_and_faces_the_player_in_the_training_room() -> void:
	var room := await _training()
	var menu := _menu(room)
	var player: PlayerCharacter = room.get(&"player")
	player.look_pitch = 0.0
	menu.set_showcase(true)
	assert_true(menu.is_showcase_on())
	var punk := menu.showcase.actor
	var ahead := punk.global_position - player.global_position
	ahead.y = 0.0
	assert_almost_eq(ahead.length(), 1.0, 0.05, "1 m from the player")
	assert_gt(ahead.normalized().dot(-player.get_look_basis().z), 0.99, "straight ahead of his look")
	assert_gt(punk.get_forward().dot(-ahead.normalized()), 0.99, "facing him")
	assert_almost_eq(punk.global_position.y, 0.0, 0.02, "on the floor")
	assert_eq(menu.showcase_toggle.button_pressed, true, "the toggle shows it")
	assert_true(menu.showcase_toggle.text.begins_with("Showcase Punk at 1 m"))
	assert_true(menu.showcase_toggle.text.ends_with("ON"))
	await _ticks(90)
	assert_gt(menu.showcase.index, -1, "it plays the take")
	assert_gt(menu.showcase.elapsed + menu.showcase.index, 0.0)
	menu.set_showcase(false)
	await _ticks(2)


func test_the_showcase_is_not_an_enemy_to_anything_and_is_gone_when_it_is_switched_off() -> void:
	for crowd: bool in [false, true]:
		var room: Node3D = await _crowd() if crowd else await _training()
		var menu := _menu(room)
		(room.get(&"player") as PlayerCharacter).look_pitch = 0.0
		if crowd:
			# Real wave Punks stand in the street while it shows: nothing about them changes.
			room.spawner.scene_override = {}
			menu.spawn_enemy(&"punk")
			await _ticks(4)
		var before := _snapshot(room)
		menu.set_showcase(true)
		var punk := menu.showcase.actor
		var during := _snapshot(room)
		assert_true(is_instance_valid(punk))
		assert_eq(during.enemies, before.enemies, "no enemy added (%s)" % ("crowd" if crowd else "training"))
		assert_eq(during.ai_enemies, before.ai_enemies, "no AI enemy added")
		assert_eq(during.bosses, before.bosses)
		assert_eq(during.actors, before.actors + 1, "a body for the camera and the spawn clearance")
		assert_true(punk.is_in_group(&"actor"))
		for group: StringName in [&"enemy", &"ai_enemy", &"boss"]:
			assert_false(punk.is_in_group(group), "not in %s" % group)
		assert_false(punk.is_physics_processing(), "off its own tick")
		assert_true(Tuning.data.ai_frozen, "Freeze AI while it shows")
		if during.has("holders"):
			assert_eq(during.holders, before.holders, "the director gave it no token")
			assert_eq(during.waiting, before.waiting, "and has it in no queue")
			assert_eq(during.alive, before.alive, "the spawner does not count it")
		for hurtbox: Hurtbox in punk.rig.get_hurtboxes():
			assert_false(hurtbox.monitorable, "%s cannot be hit" % hurtbox.name)
		for agent: Node in punk.find_children("*", "NavigationAgent3D", false, false):
			assert_false((agent as NavigationAgent3D).avoidance_enabled, "the others do not steer round it")
		await _ticks(30)
		menu.set_showcase(false)
		assert_false(menu.is_showcase_on())
		await _ticks(3)
		assert_false(is_instance_valid(punk), "the Punk is freed")
		var after := _snapshot(room)
		for key: String in before:
			assert_eq(after[key], before[key], "%s as before (%s)" % [key, "crowd" if crowd else "training"])
		assert_false(menu.showcase_toggle.button_pressed)
		assert_true(menu.showcase_toggle.text.ends_with("off"))
		room.queue_free()
		menu.queue_free()
		await _ticks(3)


func test_freeze_ai_goes_back_to_what_it_was_unless_the_player_changed_it_meanwhile() -> void:
	var room := await _training()
	var menu := _menu(room)
	(room.get(&"player") as PlayerCharacter).look_pitch = 0.0
	# Off before: on during, off after.
	menu.set_showcase(true)
	assert_true(Tuning.data.ai_frozen)
	menu.set_showcase(false)
	assert_false(Tuning.data.ai_frozen)
	# On before: stays on.
	Tuning.set_value(&"ai_frozen", true)
	menu.set_showcase(true)
	menu.set_showcase(false)
	assert_true(Tuning.data.ai_frozen, "it was on: it stays on")
	# The player turns Freeze AI off while the Punk shows: the showcase leaves it alone.
	Tuning.set_value(&"ai_frozen", false)
	menu.set_showcase(true)
	assert_true(Tuning.data.ai_frozen)
	menu.set_ai_frozen(false)
	menu.set_showcase(false)
	assert_false(Tuning.data.ai_frozen, "the player's choice stands")
	await _ticks(3)


func test_a_second_switch_on_does_nothing_and_a_room_switch_puts_the_game_back() -> void:
	var room := await _training()
	var menu := _menu(room)
	(room.get(&"player") as PlayerCharacter).look_pitch = 0.0
	menu.set_showcase(true)
	var runner := menu.showcase
	var actors := get_tree().get_nodes_in_group(&"actor").size()
	menu.set_showcase(true)
	assert_same(menu.showcase, runner, "still the same Punk")
	assert_eq(get_tree().get_nodes_in_group(&"actor").size(), actors, "and no second one")
	# The menu leaves the tree (the room is switched with F6 while the Punk stands).
	var punk := runner.actor
	menu.get_parent().remove_child(menu)
	await _ticks(2)
	assert_false(Tuning.data.ai_frozen, "Freeze AI is back")
	assert_true(not is_instance_valid(punk) or punk.is_queued_for_deletion(), "the Punk is freed")
	menu.free()


func test_the_showcase_does_nothing_where_there_is_no_player_to_stand_before() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var menu := CheatMenu.new()
	menu.world = world
	add_child_autofree(menu)
	assert_eq(menu.showcase_point(), {}, "no player, no spot")
	var frozen := Tuning.data.ai_frozen
	menu.set_showcase(true)
	assert_false(menu.is_showcase_on(), "no Punk")
	assert_eq(Tuning.data.ai_frozen, frozen, "and nothing else changed")
	assert_eq(world.get_child_count(), 0)
	menu.set_showcase(false)
