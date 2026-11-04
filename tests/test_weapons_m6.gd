extends GutTest
## Milestone 6 WEAPONS: the catalog (WeaponDef, WeaponCatalog), both weapons end to end in the real test room (pick-up, the
## three-hit chain of 10, the break after 8 hits, the throw of 15, the guard drain, durability by def), `weapon_landed` once
## per landing, the floor glint (D28) and the bike chain's presentation sim (ChainSim).

const ROOM := preload("res://game/level/test_room.tscn")
const FAR := Vector3(30.0, 0.0, -30.0)
const IDS: Array[StringName] = [&"pipe", &"bike_chain"]
## The eye height the glint is judged from (m): the player's standing eye, SPEC section 5.
const EYE_HEIGHT_M := 1.6
const GLINT_DISTANCE_M := 10.0

var room: Node3D
var player: PlayerCharacter
var dummies: Array[TrainingDummy] = []
var hits: Array[HitInfo] = []
var landed: Array[Node3D] = []
var broke: Array[Node3D] = []


func before_each() -> void:
	TimeController.clear()
	TimeController.debug_scale = 1.0
	Tuning.apply(TuningData.new())
	Tuning.data.dummy_health = 500.0
	hits.clear()
	landed.clear()
	broke.clear()
	CombatEvents.hit_landed.connect(_on_hit)
	CombatEvents.weapon_landed.connect(_on_landed)
	CombatEvents.weapon_broke.connect(_on_broke)


func after_each() -> void:
	CombatEvents.hit_landed.disconnect(_on_hit)
	CombatEvents.weapon_landed.disconnect(_on_landed)
	CombatEvents.weapon_broke.disconnect(_on_broke)
	TimeController.clear()


func _on_hit(hit: HitInfo) -> void:
	hits.append(hit)


func _on_landed(weapon: Node3D) -> void:
	landed.append(weapon)


func _on_broke(_actor: Node3D, weapon: Node3D) -> void:
	broke.append(weapon)


# --- Harness ------------------------------------------------------------------------------


func _setup(posts: Array[Vector3]) -> void:
	if is_instance_valid(room):
		room.queue_free()
		await _ticks(2)
	room = ROOM.instantiate()
	room.set(&"with_presentation", false)
	add_child_autofree(room)
	await _ticks(2)
	player = room.get(&"player")
	player.input.scripted = true
	dummies.assign(room.get(&"dummies"))
	for i in dummies.size():
		var pos := player.global_position + player.global_basis * posts[i] if i < posts.size() else FAR + Vector3(i * 3.0, 0.0, 0.0)
		var to_player := player.global_position - pos
		dummies[i].sparring = false
		dummies[i].set_post(pos, atan2(-to_player.x, -to_player.z), true)
	await _ticks(3)
	hits.clear()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _press(button: StringName, hold: int = 2, gap: int = 0) -> void:
	player.input.push_press(button, hold)
	player.input.push_wait(gap)
	await _drain()


func _drain() -> void:
	var guard := 0
	while player.input.queued() > 0 and guard < 2000:
		guard += 1
		await get_tree().physics_frame


func _wait_until(condition: Callable, max_ticks: int = 400) -> bool:
	for i in max_ticks:
		if condition.call():
			return true
		await get_tree().physics_frame
	return false


func _wait_idle() -> bool:
	return await _wait_until(func() -> bool:
		return (player.input.queued() == 0 and player.current_move == null
				and player.state in [CombatTypes.ActorState.FREE, CombatTypes.ActorState.GRABBING]
				and not TimeController.is_in_hitstop(player)), 600)


## The room's weapon of kind `id`.
func _weapon_of(id: StringName) -> Weapon:
	for node: Node in get_tree().get_nodes_in_group(&"weapon"):
		var weapon := node as Weapon
		if weapon != null and weapon.def_id == id:
			return weapon
	return null


## Put the weapon `id` at the player's feet and pick it up with LB.
func _take(id: StringName) -> Weapon:
	var weapon := _weapon_of(id)
	weapon.global_position = player.global_position + player.global_basis * Vector3(0, 0.1, -0.6)
	weapon.linear_velocity = Vector3.ZERO
	await _ticks(5)
	await _press(&"GRAB", 2, 14)
	return weapon


func _weapon_hits(def: WeaponDef) -> Array[StringName]:
	var out: Array[StringName] = []
	for hit in hits:
		if hit.attacker == player and hit.move != null and def.owns_swing(hit.move.id):
			out.append(hit.move.id)
	return out


## The dummy back 1.6 m ahead (a finisher knocks it down and away).
func _restage() -> void:
	var pos := player.global_position + player.global_basis * Vector3(0, 0, -1.6)
	var to_player := player.global_position - pos
	dummies[0].set_post(pos, atan2(-to_player.x, -to_player.z), true)


func _swing_chain(times: int) -> void:
	for i in times:
		player.input.push_press(&"P", 2)
		player.input.push_wait(9)
	await _drain()
	await _wait_idle()


# --- The catalog --------------------------------------------------------------------------


func test_the_catalog_has_both_weapons_and_each_def_is_complete() -> void:
	WeaponCatalog.clear()
	assert_eq(WeaponCatalog.all().size(), 2, "the pipe and the bike chain")
	for id in IDS:
		var def := WeaponCatalog.get_def(id)
		assert_not_null(def, "%s has a def" % id)
		assert_eq(def.id, id)
		assert_ne(def.display_name, "", "%s has a name" % id)
		assert_not_null(def.scene, "%s has a scene" % id)
		assert_not_null(def.move_set, "%s has a move set" % id)
		assert_not_null(def.throw_move, "%s has a throw" % id)
		assert_eq(def.swing_ids.size(), 3, "%s: a three-hit chain" % id)
		assert_eq(def.impact_sfx, id, "%s: its impact layer is its own" % id)
		var weapon := def.scene.instantiate() as Weapon
		assert_not_null(weapon, "%s's scene is a Weapon" % id)
		assert_eq(weapon.def_id, id, "and names its def")
		assert_same(weapon.def, def, "which is the catalog's")
		assert_not_null(weapon.art_scene, "%s draws art, not a cylinder" % id)
		weapon.free()
	assert_eq(WeaponCatalog.get_def(&"bike_chain").scene.resource_path, "res://game/weapons/bike_chain.tscn")
	assert_eq(WeaponCatalog.get_def(&"pipe").scene.resource_path, "res://game/weapons/pipe.tscn", "the pipe's path is kept")
	assert_true(WeaponCatalog.is_swing(&"chain_swing_2") and WeaponCatalog.is_swing(&"pipe_swing_3"))
	assert_false(WeaponCatalog.is_swing(&"jab_1"))
	assert_true(WeaponCatalog.is_throw(&"chain_throw") and WeaponCatalog.is_throw(&"weapon_throw"))
	assert_false(WeaponCatalog.is_throw(&"throw"), "the grab throw is no weapon throw")


func test_every_weapon_move_names_its_impact_sfx_and_fists_name_none() -> void:
	for id in IDS:
		var def := WeaponCatalog.get_def(id)
		var moves: Array[MoveData] = [def.throw_move]
		for swing in def.swing_ids:
			moves.append(load("res://game/combat/moves/%s.tres" % swing) as MoveData)
		for move in moves:
			assert_eq(move.impact_sfx, def.impact_sfx, "%s: %s" % [id, move.id])
			assert_eq(AudioDirector.weapon_hit_pool(move.impact_sfx), StringName("weapon_%s_hit" % id), "the director's pool for it")
	for thug_move in [&"thug_pipe_1", &"thug_pipe_2", &"thug_pipe_3"]:
		assert_eq((load("res://game/combat/moves/%s.tres" % thug_move) as MoveData).impact_sfx, &"pipe", "the Thug's pipe sounds like the pipe")
	for fist in [&"jab_1", &"hook", &"front_kick", &"back_elbow", &"stomp"]:
		assert_eq((load("res://game/combat/moves/%s.tres" % fist) as MoveData).impact_sfx, &"", "%s keeps the tier's hit stack" % fist)


func test_the_chain_keeps_the_specs_numbers() -> void:
	for id in IDS:
		var def := WeaponCatalog.get_def(id)
		var tiers: Array = [CombatTypes.HitTier.LIGHT, CombatTypes.HitTier.HEAVY, CombatTypes.HitTier.FINISHER]
		for i in 3:
			var move := load("res://game/combat/moves/%s.tres" % def.swing_ids[i]) as MoveData
			assert_eq(move.damage, 10.0, "%s: 10 a swing" % move.id)
			assert_eq(move.tier, tiers[i], "%s: tier" % move.id)
			assert_almost_eq(move.guard_damage_mult, 1.5, 0.0001, "%s drains the guard 1.5x" % move.id)
			assert_eq(move.hitboxes.size(), 1)
			assert_eq(move.hitboxes[0].point, &"WeaponTip", "%s strikes from the tip, as every weapon move does" % move.id)
			if i < 2:
				assert_eq(move.branches.size(), 1, "%s chains on" % move.id)
				assert_eq(move.branches[0].move.id, def.swing_ids[i + 1])
			else:
				assert_eq(move.branches.size(), 0, "the third ends the chain")
		assert_eq(def.throw_move.damage, 15.0, "%s: a throw does 15" % id)
		assert_eq(def.throw_move.reaction, CombatTypes.Reaction.KNOCKDOWN)
		var roots: Array[StringName] = []
		for branch in def.move_set.root_branches:
			roots.append(branch.move.id)
		assert_eq(roots[0], def.swing_ids[0], "%s: P is the first swing" % id)
	assert_eq(Tuning.data.weapon_durability, 8, "it breaks after 8 hits (the one tunable both read)")
	var chain := WeaponCatalog.get_def(&"bike_chain")
	var pipe := WeaponCatalog.get_def(&"pipe")
	var lash := load("res://game/combat/moves/chain_swing_1.tres") as MoveData
	var pipe_swing := load("res://game/combat/moves/pipe_swing_1.tres") as MoveData
	assert_ne(lash.startup, pipe_swing.startup, "the chain's own timing")
	assert_ne(lash.hitboxes[0].radius, pipe_swing.hitboxes[0].radius, "and its own sphere")
	assert_ne(chain.move_set, pipe.move_set)
	var smash := load("res://game/combat/moves/chain_swing_3.tres") as MoveData
	assert_lt(smash.hitboxes[0].offset.z, lash.hitboxes[0].offset.z, "the padlock lands last: the finisher's sphere is out past the lashes'")


# --- Both weapons in the room -------------------------------------------------------------


func test_both_weapons_are_picked_up_and_swing_the_chain_of_three_at_ten() -> void:
	for id in IDS:
		var def := WeaponCatalog.get_def(id)
		await _setup([Vector3(0, 0, -1.6), Vector3(0, 0, -6.0)])
		var weapon := await _take(id)
		assert_true(player.holding_weapon(), "%s: picked up" % id)
		assert_eq(weapon.holder, player)
		assert_eq(player.parser.move_set, def.move_set, "%s: the player swapped to its move set" % id)
		assert_eq(player.weapon_durability_left(), Tuning.data.weapon_durability)
		await _swing_chain(3)
		assert_eq(_weapon_hits(def), def.swing_ids, "%s: P P P is its three swings" % id)
		for hit in hits:
			if hit.attacker == player:
				assert_eq(hit.damage, 10.0, "%s: ten a swing" % id)
		assert_eq(player.weapon_durability_left(), Tuning.data.weapon_durability - 3, "%s: one point a hit" % id)
		assert_true(AudioDirector.weapon_hit_pool(def.impact_sfx) != &"")


func test_each_weapon_breaks_after_eight_hits() -> void:
	for id in IDS:
		var def := WeaponCatalog.get_def(id)
		broke.clear()
		await _setup([Vector3(0, 0, -1.6)])
		await _take(id)
		assert_eq(player.weapon_durability_left(), 8)
		await _swing_chain(3)
		_restage()
		await _ticks(30)
		await _swing_chain(3)
		_restage()
		await _ticks(30)
		assert_eq(player.weapon_durability_left(), 2, "%s: six hits in" % id)
		await _swing_chain(3)
		assert_eq(_weapon_hits(def).size(), 8, "%s: the eighth hit breaks it, and no ninth swing follows" % id)
		assert_false(player.holding_weapon(), "%s: gone from his hands" % id)
		assert_eq(broke.size(), 1, "%s: one weapon_broke" % id)
		assert_true(player.parser.move_set != def.move_set, "back on the ground set")


func test_the_throw_hits_for_fifteen_and_the_swings_stop_when_it_is_gone() -> void:
	for id in IDS:
		var def := WeaponCatalog.get_def(id)
		await _setup([Vector3(0, 0, -1.6), Vector3(0, 0, -6.0)])
		var weapon := await _take(id)
		dummies[0].set_post(FAR)
		await _ticks(2)
		var thrown: Array[Node3D] = []
		var on_thrown := func(_a: Node3D, w: Node3D) -> void: thrown.append(w)
		CombatEvents.weapon_thrown.connect(on_thrown)
		await _press(&"GRAB", 2)
		assert_true(await _wait_until(func() -> bool: return not player.holding_weapon()))
		CombatEvents.weapon_thrown.disconnect(on_thrown)
		assert_eq(thrown, [weapon] as Array[Node3D], "%s: weapon_thrown carries the weapon node" % id)
		assert_true(await _wait_until(func() -> bool:
				return hits.any(func(h: HitInfo) -> bool: return h.move != null and h.move.id == def.throw_move.id), 120), "%s: the throw hits" % id)
		var hit: HitInfo = hits.filter(func(h: HitInfo) -> bool: return h.move != null and h.move.id == def.throw_move.id)[0]
		assert_eq(hit.damage, 15.0, "%s: a throw does 15" % id)
		assert_eq(hit.move.impact_sfx, def.impact_sfx)
		await _press(&"P", 2)
		await _wait_idle()
		assert_true(_weapon_hits(def).is_empty(), "%s: no swing without the weapon" % id)


func test_a_held_weapon_drains_a_raised_guard_one_and_a_half_times() -> void:
	for id in IDS:
		var def := WeaponCatalog.get_def(id)
		await _setup([Vector3(0, 0, -0.9)])
		var dummy := dummies[0]
		player.input.scripted_move = Vector2.ZERO
		player.input.push_down(&"DODGE")
		await _drain()
		await _ticks(24)
		for move: MoveData in [load("res://game/combat/moves/%s.tres" % def.swing_ids[0]) as MoveData, def.throw_move]:
			player.guard = Tuning.data.guard_max
			var hit := HitInfo.new()
			hit.attacker = dummy
			hit.victim = player
			hit.move = move
			hit.damage = move.damage
			hit.tier = move.tier
			hit.reaction = move.reaction
			hit.direction = (player.global_position - dummy.global_position).normalized()
			hit.is_body_impact = move == def.throw_move
			hit.input_timing = &"thrown" if hit.is_body_impact else &"root"
			assert_true(player.receive_hit(hit))
			assert_true(hit.blocked, "%s from the front is blocked" % move.id)
			assert_almost_eq(Tuning.data.guard_max - player.guard, 4.0 * move.damage * (1.5 if move == def.throw_move else move.guard_damage_mult) / (1.5 if move == def.throw_move else 1.0), 0.001, "%s drains" % move.id)
			player.reset_state()
			player.input.push_down(&"DODGE")
			await _drain()
			await _ticks(24)


func test_durability_is_one_tunable_for_both_defs() -> void:
	Tuning.data.weapon_durability = 3
	for id in IDS:
		var weapon := WeaponCatalog.get_def(id).scene.instantiate() as Weapon
		add_child_autofree(weapon)
		assert_eq(weapon.durability, 3, "%s reads weapon_durability" % id)


# --- weapon_landed ------------------------------------------------------------------------


func test_a_dropped_weapon_announces_its_landing_once() -> void:
	for id in IDS:
		landed.clear()
		await _setup([Vector3(0, 0, -6.0)])
		var weapon := _weapon_of(id)
		weapon.global_position = player.global_position + player.global_basis * Vector3(0, 0.3, -1.0)
		await _ticks(40)
		assert_true(landed.is_empty(), "%s: a weapon set down by the level never lands (no throw, no drop)" % id)
		weapon.attach_to(player)
		await _ticks(4)
		weapon.drop(Vector3(0.0, 1.0, 1.0), 4.0)
		weapon.global_position += Vector3.UP * 1.0
		assert_true(await _wait_until(func() -> bool: return not landed.is_empty(), 180), "%s: it lands" % id)
		await _ticks(120)
		assert_eq(landed, [weapon] as Array[Node3D], "%s: once, though it bounces and rolls" % id)
		weapon.attach_to(player)
		await _ticks(4)
		weapon.drop(Vector3.ZERO, 0.0)
		weapon.global_position += Vector3.UP * 0.5
		assert_true(await _wait_until(func() -> bool: return landed.size() == 2, 180), "%s: a second drop is a second landing" % id)
		await _ticks(60)
		assert_eq(landed.size(), 2)


func test_a_thrown_weapon_announces_its_landing_once_at_the_first_contact() -> void:
	for id in IDS:
		landed.clear()
		await _setup([Vector3(0, 0, -2.0)])
		var weapon := await _take(id)
		dummies[0].set_post(FAR)
		await _press(&"GRAB", 2)
		assert_true(await _wait_until(func() -> bool: return not landed.is_empty(), 240), "%s: a throw ends in a landing" % id)
		await _ticks(120)
		assert_eq(landed.size(), 1, "%s: one landing per throw" % id)
		assert_eq(landed[0], weapon)


# --- The glint (D28) ----------------------------------------------------------------------


func test_a_weapon_lying_on_the_floor_has_the_glint_and_one_in_a_hand_or_the_air_does_not() -> void:
	await _setup([])
	for id in IDS:
		var weapon := _weapon_of(id)
		var glint := weapon.find_child("Glint", false, false) as WeaponGlint
		assert_not_null(glint, "%s carries a glint" % id)
		await _ticks(90)
		assert_true(glint.visible, "%s: lying, it glints" % id)
		assert_almost_eq(glint.global_position.y, weapon.global_position.y + Tuning.data.weapon_glint_height_m, 0.02, "above it")
		assert_eq(weapon.find_children("*", "CylinderMesh", true, false).size(), 0)
		weapon.attach_to(player)
		assert_false(glint.visible, "%s: held, it does not" % id)
		weapon.drop(Vector3.ZERO, 0.0)
		assert_true(glint.visible, "%s: dropped, it does again" % id)
		Tuning.set_value(&"weapon_floor_amber", true)
		weapon.refresh_look()
		await _ticks(2)
		assert_false(glint.visible, "%s: with weapon_floor_amber on, M5's look and no glint" % id)
		Tuning.set_value(&"weapon_floor_amber", false)
		weapon.refresh_look()
		await _ticks(2)


func test_the_glint_is_visible_from_ten_metres_at_eye_height() -> void:
	await _setup([])
	var space := player.get_world_3d().direct_space_state
	for id in IDS:
		var weapon := _weapon_of(id)
		weapon.freeze = true
		var spot := Vector3(0.0, 0.1, 0.0)
		weapon.global_position = spot
		await _ticks(3)
		var glint_at := WeaponGlint.position_above(weapon)
		# From 10 m away along the street, at eye height: nothing of the world stands between the lens and the glint.
		var eye := Vector3(spot.x + GLINT_DISTANCE_M, EYE_HEIGHT_M, spot.z)
		var query := PhysicsRayQueryParameters3D.create(eye, glint_at, CombatTypes.bit(CombatTypes.LAYER_WORLD))
		var seen := space.intersect_ray(query)
		assert_true(seen.is_empty(), "%s: the ray from the eye at 10 m to the glint is clear (hit %s)" % [id, seen.get("collider")])
		var distance := eye.distance_to(glint_at)
		assert_gte(WeaponGlint.angular_size_deg(distance), Tuning.data.weapon_glint_min_angle_deg - 0.001, "%s: it covers at least the floor angle" % id)
		assert_gte(WeaponGlint.drawn_size_m(distance), Tuning.data.weapon_glint_size_m, "never smaller than near")
		assert_gt(WeaponGlint.drawn_size_m(40.0), Tuning.data.weapon_glint_size_m, "far off it is drawn larger, so it does not shrink away")
		assert_gt(WeaponGlint.drawn_size_m(40.0), 40.0 * tan(deg_to_rad(Tuning.data.weapon_glint_min_angle_deg)) - 0.001)
		# The glint is above the weapon, so a low obstacle (a curb, a crate's top edge) at the weapon does not hide it from the lens.
		assert_gt(glint_at.y, spot.y + 0.3, "%s: it floats clear of the floor" % id)
	assert_true(Tuning.data.weapon_glint_min_angle_deg >= 1.0, "no less than a degree on screen from any distance")


func test_the_glint_shader_faces_the_lens_and_is_additive() -> void:
	var shader := load("res://game/weapons/glint.gdshader") as Shader
	assert_not_null(shader)
	assert_true(shader.code.contains("blend_add"), "it only adds light")
	assert_true(shader.code.contains("INV_VIEW_MATRIX"), "it faces the lens")
	assert_true(shader.code.contains("min_angle_tan"), "with an angular floor")


# --- The bike chain's sim -----------------------------------------------------------------


func _chain_sim(weapon: Weapon) -> ChainSim:
	return weapon.find_child("ChainSim", false, false) as ChainSim


func test_the_chain_sim_replaces_the_straight_links_with_a_multimesh() -> void:
	await _setup([])
	var weapon := _weapon_of(&"bike_chain")
	var sim := _chain_sim(weapon)
	assert_not_null(sim)
	assert_true(sim.is_ready_to_draw())
	assert_null(_chain_sim(_weapon_of(&"pipe")), "the pipe has no sim")
	await _ticks(5)
	var expected := int(floor(sim.rest_length() / Tuning.data.weapon_chain_link_pitch_m))
	assert_almost_eq(float(sim.links_drawn()), float(expected), 1.0, "the free length over the pitch")
	var art := weapon.find_child("BikeChainArt", false, false) as StaticArt
	for node in art.instances():
		if String(node.name).begins_with("Link"):
			assert_false(node.visible, "%s: the straight repeat gives way" % node.name)
	var multi := sim.find_child("Links", false, false) as MultiMeshInstance3D
	assert_true(multi.visible)
	assert_eq(multi.material_override, art.material, "one atlas material, as the art")
	Tuning.set_value(&"weapon_chain_sim", false)
	await _ticks(3)
	assert_false(multi.visible, "the Debug switch off: the straight repeats are back")
	for node in art.instances():
		if String(node.name).begins_with("Link"):
			assert_true(node.visible)
	Tuning.set_value(&"weapon_chain_sim", true)


func test_a_chain_at_rest_lies_straight_and_a_whip_trails_then_settles() -> void:
	await _setup([])
	var weapon := _weapon_of(&"bike_chain")
	var sim := _chain_sim(weapon)
	weapon.freeze = true
	weapon.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0))
	sim.step(1.0 / 60.0)
	for i in 30:
		sim.step(1.0 / 60.0)
	var rest := sim.points_local()
	var length := sim.rest_length()
	var straight := rest[0].distance_to(rest[rest.size() - 1])
	assert_gt(straight, length * 0.85, "at rest it hangs (almost) straight along the weapon's axis")
	assert_almost_eq(rest[rest.size() - 1].x, 0.0, 0.05)
	# A fast sideways swing of the weapon: the padlock trails behind the nominal tip.
	var worst := 0.0
	for i in 12:
		weapon.global_position += Vector3(0.16, 0.0, 0.0)
		sim.step(1.0 / 60.0)
		var tip := sim.points_local()[rest.size() - 1]
		worst = maxf(worst, absf(tip.x))
	assert_gt(worst, 0.02, "the chain lags the grip in a swing (%.3f m)" % worst)
	for i in 90:
		sim.step(1.0 / 60.0)
	var after := sim.points_local()
	assert_lt(absf(after[after.size() - 1].x), 0.03, "and settles back under the grip")
	# The segments never stretch.
	var segment := length / float(rest.size() - 1)
	for i in range(1, after.size()):
		assert_almost_eq(after[i].distance_to(after[i - 1]), segment, segment * 0.25, "segment %d keeps its length" % i)


func test_the_chain_sim_never_touches_the_weapon_a_hit_or_the_holder() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	var weapon := await _take(&"bike_chain")
	var sim := _chain_sim(weapon)
	var before := weapon.transform
	var layer := weapon.collision_layer
	var health := dummies[0].health
	for i in 20:
		sim.step(1.0 / 60.0)
	assert_eq(weapon.transform, before, "stepping moves nothing but the drawn links")
	assert_eq(weapon.collision_layer, layer)
	assert_eq(dummies[0].health, health)
	assert_eq(weapon.get_script().resource_path, "res://game/weapons/weapon.gd")


func test_the_chain_sim_follows_game_time_and_freezes_with_the_holders_hitstop() -> void:
	await _setup([Vector3(0, 0, -1.6)])
	var weapon := await _take(&"bike_chain")
	var sim := _chain_sim(weapon)
	assert_almost_eq(sim._time_scale(), 1.0, 0.0001)
	TimeController.hitstop([player], 0.5)
	await _ticks(2)
	assert_almost_eq(sim._time_scale(), 0.0, 0.0001, "in the holder's hitstop the chain stands still")
	TimeController.clear()
	TimeController.slowmo(0.25, 1.0)
	await _ticks(3)
	assert_almost_eq(sim._time_scale(), 0.25, 0.0001, "slow-mo slows it")


func test_a_chain_that_jumps_snaps_straight_instead_of_whipping() -> void:
	await _setup([])
	var weapon := _weapon_of(&"bike_chain")
	var sim := _chain_sim(weapon)
	weapon.freeze = true
	for i in 5:
		sim.step(1.0 / 60.0)
	weapon.global_position += Vector3(0.0, 0.0, -4.0)
	sim.step(1.0 / 60.0)
	var points := sim.points_local()
	var length := sim.rest_length()
	assert_gt(points[0].distance_to(points[points.size() - 1]), length * 0.95, "straight at the new place: no streak of links across the room")
