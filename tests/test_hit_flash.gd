extends GutTest
## The localized white hit flash (Spec §6, Game-boy's departure of 2026-10-24; README "Where
## M2 departs from the spec"): a clean hit, a guard break and a blocked hit flash the
## victim's body around the contact point through its rig's overlay (HumanoidRig.flash_at(),
## game/fx/hit_flash.gdshader) for exactly Tuning.hit_flash_frames rendered frames, whichever
## actor runs first in the tick; the cyan parry flash stays whole-body; idle rigs draw no
## extra pass; a large radius whites the whole body. The flash lands on the struck part as it
## is drawn: contacts off the body (a thrown pipe, a flying body) and bodies drawn away from
## their hurtboxes (a stagger's partial ragdoll, a full ragdoll) flash at full strength there.

const ROOM := preload("res://game/level/test_room.tscn")
const FPView := preload("res://tests/fp_view.gd")
## The bones whose meshes draw each hurtbox region (HumanoidRig names its followers
## "Bone<name>").
const REGION_BONES: Dictionary[int, Array] = {
	CombatTypes.Region.HEAD: [&"Head", &"Neck"],
	CombatTypes.Region.TORSO: [&"Hips", &"Spine", &"Chest", &"UpperChest"],
	CombatTypes.Region.LEGS: [&"LeftUpperLeg", &"LeftLowerLeg", &"LeftFoot", &"LeftToes",
			&"RightUpperLeg", &"RightLowerLeg", &"RightFoot", &"RightToes"],
}

var room: Node3D
var player: PlayerCharacter
var dummies: Array[TrainingDummy] = []
var hits: Array[HitInfo] = []
## The victim's overlay point as each hit landed (CombatEvents.hit_landed follows
## receive_hit()), or NAN when it had no overlay.
var points_at_hit: Array[Vector3] = []
## How far that point lay from the struck region's meshes, and from the whole body, as they
## were drawn then (INF with no overlay; see _drawn_gap()).
var gaps_at_hit: Array[float] = []
var body_gaps_at_hit: Array[float] = []


func before_each() -> void:
	TimeController.clear()
	TimeController.debug_scale = 1.0
	Tuning.apply(TuningData.new())
	Tuning.data.dummy_health = 500.0
	_clear_hits()
	CombatEvents.hit_landed.connect(_on_hit)


func after_each() -> void:
	CombatEvents.hit_landed.disconnect(_on_hit)
	TimeController.clear()
	Tuning.apply(TuningData.new())


func _clear_hits() -> void:
	hits.clear()
	points_at_hit.clear()
	gaps_at_hit.clear()
	body_gaps_at_hit.clear()


func _on_hit(hit: HitInfo) -> void:
	hits.append(hit)
	var victim := hit.victim as CombatActor
	var overlay := victim.rig.flash_overlay() if victim else null
	points_at_hit.append(overlay.get_shader_parameter(&"flash_point") if overlay else Vector3(NAN, NAN, NAN))
	gaps_at_hit.append(_drawn_gap(victim, points_at_hit.back(), REGION_BONES[hit.region]) if overlay else INF)
	body_gaps_at_hit.append(_drawn_gap(victim, points_at_hit.back()) if overlay else INF)


# --- Harness ------------------------------------------------------------------------


## The test room (no presentation) with the first dummy `dist` ahead of the player, facing
## it, and the others far away. Sparring off.
func _setup(dist: float = 1.2) -> void:
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
		var pos := player.global_position + player.global_basis * Vector3(0, 0, -dist) if i == 0 \
				else Vector3(30.0 + i * 3.0, 0.0, -30.0)
		var to_player := player.global_position - pos
		dummies[i].sparring = false
		dummies[i].set_post(pos, atan2(-to_player.x, -to_player.z), true)
	await _ticks(3)
	_clear_hits()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_until(condition: Callable, max_ticks: int = 120) -> bool:
	for i in max_ticks:
		if condition.call():
			return true
		await get_tree().physics_frame
	return false


## The player jabs; returns the first hit on `victim` (null if none landed). Returns at the
## start of the tick after the hit's, before any actor runs: the state just rendered.
func _player_jab(victim: CombatActor) -> HitInfo:
	player.input.push_press(&"P", 2)
	if not await _wait_until(func() -> bool: return _hits_on(victim).size() > 0):
		return null
	return _hits_on(victim)[0]


## The overlay point `hit` set as it landed.
func _point_at(hit: HitInfo) -> Vector3:
	var i := hits.find(hit)
	return points_at_hit[i] if i >= 0 else Vector3(NAN, NAN, NAN)


## How far `point` lies from `victim`'s body as it is drawn: from the meshes on `bones` when
## given, from every mesh otherwise.
func _drawn_gap(victim: CombatActor, point: Vector3, bones: Array = []) -> float:
	return FPView.nearest_mesh(victim.rig, point, func(mesh: MeshInstance3D) -> bool:
		return bones.is_empty() or bones.has(StringName(String(mesh.get_parent().name).trim_prefix("Bone"))))


## The distance from its point inside which the contact flash is at full strength.
func _core_m() -> float:
	return Tuning.data.hit_flash_radius_m * Tuning.data.hit_flash_core


func _hits_on(victim: CombatActor) -> Array[HitInfo]:
	var out: Array[HitInfo] = []
	for hit in hits:
		if hit.victim == victim:
			out.append(hit)
	return out


## Every material of `rig` (one per paint).
func _materials(rig: HumanoidRig) -> Array[StandardMaterial3D]:
	var out: Array[StandardMaterial3D] = []
	var mats: Dictionary[int, StandardMaterial3D] = rig.get(&"_materials")
	for paint: int in mats:
		out.append(mats[paint])
	return out


## Whether `rig` draws its contact-flash overlay: on every material, and only then.
func _overlay_on(rig: HumanoidRig) -> bool:
	var overlay := rig.flash_overlay()
	for mat in _materials(rig):
		assert_eq(mat.next_pass, overlay, "%s: the overlay is on every material or none" % rig.get_parent().name)
	return overlay != null


## From the frame the first hit on `victim` lands on, whether each rendered frame showed its
## contact flash (sampled at the start of each idle frame, after that frame's physics tick).
func _flash_frames_shown(victim: CombatActor, attack: Callable, frames_after: int = 8) -> Array[bool]:
	var shown: Array[bool] = []
	attack.call()
	for i in 240:
		await get_tree().process_frame
		if not _hits_on(victim).is_empty():
			shown.append(_overlay_on(victim.rig))
			if shown.size() > frames_after:
				break
	return shown


# --- Tests ----------------------------------------------------------------------------


func test_a_clean_hit_flashes_around_its_contact_point() -> void:
	await _setup()
	var dummy := dummies[0]
	Tuning.data.hit_flash_radius_m = 0.3
	Tuning.data.hit_flash_core = 0.4
	Tuning.data.hit_flash_strength = 0.8
	dummy.rig.set_damage_look(DamageLook.Level.BLOODIED)
	var hit := await _player_jab(dummy)
	assert_not_null(hit, "the jab lands")
	if hit == null:
		return
	assert_false(hit.blocked)
	var overlay := dummy.rig.flash_overlay()
	assert_not_null(overlay, "the victim flashes")
	if overlay == null:
		return
	assert_true(_overlay_on(dummy.rig), "as every material's next pass")
	assert_eq(overlay.shader, preload("res://game/fx/hit_flash.gdshader"))
	assert_almost_eq(_point_at(hit).distance_to(hit.contact_point), 0.0, 1e-4, "at the contact point")
	# The point rides the nearest bone: the struck part snaps into its flinch on the hit.
	var point: Vector3 = overlay.get_shader_parameter(&"flash_point")
	assert_lt(point.distance_to(hit.contact_point), 0.1, "still on the struck part a tick later")
	assert_almost_eq(float(overlay.get_shader_parameter(&"flash_radius")), 0.3, 1e-6, "radius from Tuning")
	assert_almost_eq(float(overlay.get_shader_parameter(&"flash_core")), 0.4, 1e-6, "core from Tuning")
	assert_almost_eq(float(overlay.get_shader_parameter(&"flash_strength")), 0.8, 1e-6, "strength from Tuning")
	assert_eq(Color(overlay.get_shader_parameter(&"flash_color")), Color.WHITE, "white")
	assert_eq(overlay.render_priority, Material.RENDER_PRIORITY_MIN, "under the comic effects")
	for mat in _materials(dummy.rig):
		assert_eq(mat.emission_energy_multiplier, 0.0, "no whole-body emission")
	var mats: Dictionary[int, StandardMaterial3D] = dummy.rig.get(&"_materials")
	assert_true(mats[PlaceholderBody.Paint.SKIN].detail_enabled, "the damage look stays under it")
	assert_false(_overlay_on(player.rig), "only the victim flashes")
	assert_false(_overlay_on(dummies[1].rig))


func test_the_flash_shows_for_exactly_hit_flash_frames_rendered_frames() -> void:
	# The player runs before the dummies in the tick, so the dummy it strikes used to count
	# the hit's own tick and show one white frame instead of two; the dummy's jab on the
	# player (the attacker runs after its victim) showed two.
	for frames: int in [2, 1, 3]:
		await _setup()
		Tuning.data.hit_flash_frames = frames
		var expected: Array[bool] = []
		for i in 9:
			expected.append(i < frames)
		var dummy := dummies[0]
		var on_dummy := await _flash_frames_shown(dummy, func() -> void: player.input.push_press(&"P", 2))
		assert_eq(on_dummy, expected, "player's jab, hit_flash_frames %d: shown on that many frames from the hit's" % frames)
		await _ticks(40)
		dummy.set_post(player.global_position + player.global_basis * Vector3(0, 0, -0.95),
				dummy.rotation.y, true)
		await _ticks(3)
		_clear_hits()
		var on_player := await _flash_frames_shown(player, func() -> void: dummy.start_jab())
		assert_eq(on_player, expected, "dummy's jab, hit_flash_frames %d" % frames)


func test_blocked_hits_and_guard_breaks_flash_at_the_contact() -> void:
	await _setup()
	var dummy := dummies[0]
	# Raised by a held button: an ordinary block, never a parry.
	dummy.start_block(false)
	await _ticks(Tuning.data.block_raise_frames + 2)
	var hit := await _player_jab(dummy)
	assert_not_null(hit, "the jab lands")
	if hit == null:
		return
	assert_true(hit.blocked and not hit.perfect_block and not hit.guard_broken, "blocked")
	var overlay := dummy.rig.flash_overlay()
	assert_not_null(overlay, "a blocked hit flashes at the contact")
	if overlay:
		assert_almost_eq(float(overlay.get_shader_parameter(&"flash_strength")),
				CombatActor.BLOCK_FLASH_AMOUNT * Tuning.data.hit_flash_strength, 1e-6, "at the block's share")
		assert_almost_eq(_point_at(hit).distance_to(hit.contact_point), 0.0, 1e-4, "at the contact")
	await _ticks(40)
	# One more blocked jab empties the guard: a guard break flashes at full strength.
	_clear_hits()
	dummy.guard = 0.01
	var broken := await _player_jab(dummy)
	assert_not_null(broken)
	if broken == null:
		return
	assert_true(broken.guard_broken, "the guard breaks")
	overlay = dummy.rig.flash_overlay()
	assert_not_null(overlay)
	if overlay:
		assert_almost_eq(float(overlay.get_shader_parameter(&"flash_strength")), Tuning.data.hit_flash_strength, 1e-6)
		assert_almost_eq(_point_at(broken).distance_to(broken.contact_point), 0.0, 1e-4, "at the contact")


func test_the_parry_flash_stays_whole_body() -> void:
	await _setup()
	var dummy := dummies[0]
	dummy.start_block(true)
	await _ticks(Tuning.data.block_raise_frames)
	var hit := await _player_jab(dummy)
	assert_not_null(hit)
	if hit == null:
		return
	assert_true(hit.perfect_block, "a fresh guard parries the jab")
	assert_false(_overlay_on(dummy.rig), "no contact overlay")
	for mat in _materials(dummy.rig):
		assert_eq(mat.emission, CombatActor.PARRY_FLASH_COLOR, "cyan")
		assert_almost_eq(mat.emission_energy_multiplier, 1.0, 1e-6, "over the whole body")
	await _ticks(Tuning.data.parry_flash_frames + 1)
	for mat in _materials(dummy.rig):
		assert_eq(mat.emission_energy_multiplier, 0.0, "cleared after parry_flash_frames")


func test_idle_rigs_draw_no_overlay_pass() -> void:
	await _setup()
	var actors: Array[CombatActor] = [player]
	actors.append_array(dummies)
	for actor in actors:
		assert_false(_overlay_on(actor.rig), "%s: no next pass" % actor.name)
		assert_null(actor.rig.get(&"_flash_overlay"), "%s: no overlay made before its first flash" % actor.name)
	var dummy := dummies[0]
	assert_not_null(await _player_jab(dummy))
	assert_true(_overlay_on(dummy.rig))
	await _ticks(Tuning.data.hit_flash_frames + 1)
	assert_false(_overlay_on(dummy.rig), "the overlay comes off once the flash ends")
	for mat in _materials(dummy.rig):
		assert_null(mat.next_pass)
		assert_eq(mat.emission_energy_multiplier, 0.0)
	# A reset mid-flash clears it too.
	_clear_hits()
	await _ticks(30)
	assert_not_null(await _player_jab(dummy))
	assert_true(_overlay_on(dummy.rig))
	dummy.reset_state()
	assert_false(_overlay_on(dummy.rig), "reset_state() clears the flash")


func test_a_large_radius_whites_the_whole_body() -> void:
	await _setup()
	var dummy := dummies[0]
	var core := Tuning.data.hit_flash_core
	Tuning.data.hit_flash_radius_m = 4.0
	var hit := await _player_jab(dummy)
	assert_not_null(hit)
	if hit == null:
		return
	var overlay := dummy.rig.flash_overlay()
	assert_not_null(overlay)
	if overlay == null:
		return
	var point: Vector3 = overlay.get_shader_parameter(&"flash_point")
	var radius := float(overlay.get_shader_parameter(&"flash_radius"))
	assert_almost_eq(float(overlay.get_shader_parameter(&"flash_strength")), 1.0, 1e-6)
	var meshes := dummy.rig.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 10)
	var lowest := 1.0
	for node: Node in meshes:
		var mesh := node as MeshInstance3D
		var box := mesh.global_transform * mesh.get_aabb()
		for i in 8:
			lowest = minf(lowest, HumanoidRig.flash_falloff(box.get_endpoint(i).distance_to(point), radius, core))
	assert_eq(lowest, 1.0, "4 m: every part of the body at full white, as before the change")
	# The default radius keeps it local: the feet stay dark on a jab to the head or chest.
	var foot := dummy.rig.get_point_position(&"LeftFootPoint")
	assert_eq(HumanoidRig.flash_falloff(foot.distance_to(point), TuningData.new().hit_flash_radius_m, core), 0.0,
			"0.25 m: nothing at the feet")


func test_falloff_is_full_in_the_core_and_fades_smoothly_to_the_radius() -> void:
	assert_eq(HumanoidRig.flash_falloff(0.0, 0.25, 0.5), 1.0, "full at the contact")
	assert_eq(HumanoidRig.flash_falloff(0.125, 0.25, 0.5), 1.0, "full out to core x radius")
	assert_almost_eq(HumanoidRig.flash_falloff(0.1875, 0.25, 0.5), 0.5, 1e-6, "half way through the fade")
	assert_eq(HumanoidRig.flash_falloff(0.25, 0.25, 0.5), 0.0, "nothing at the radius")
	assert_eq(HumanoidRig.flash_falloff(0.4, 0.25, 0.5), 0.0, "or beyond")
	assert_gt(HumanoidRig.flash_falloff(0.14, 0.25, 0.5), HumanoidRig.flash_falloff(0.2, 0.25, 0.5), "falls with distance")
	assert_eq(HumanoidRig.flash_falloff(0.2, 0.25, 1.0), 1.0, "core 1: a hard edge")
	assert_eq(HumanoidRig.flash_falloff(0.3, 0.25, 1.0), 0.0)
	assert_lt(HumanoidRig.flash_falloff(0.01, 0.25, 0.0), 1.0, "core 0: fades from the contact")


func test_the_flash_rides_the_body_it_struck() -> void:
	var rig := HumanoidRig.new()
	rig.build_hurtboxes = false
	add_child_autofree(rig)
	rig.build()
	var point := rig.get_point_position(&"ChestPoint") + Vector3(0.0, 0.0, -0.15)
	rig.flash_at(point, 1.0, 0.25, 0.5)
	assert_not_null(rig.flash_overlay())
	rig.global_position += Vector3(0.5, 0.0, 0.2)
	rig.advance(0.0)
	rig.follow_flash()
	var moved: Vector3 = rig.flash_overlay().get_shader_parameter(&"flash_point")
	assert_almost_eq(moved.distance_to(point + Vector3(0.5, 0.0, 0.2)), 0.0, 1e-4, "the point moves with the body")
	# A whole-body flash ends the contact flash, and 0 clears everything.
	rig.set_flash(1.0, CombatActor.PARRY_FLASH_COLOR)
	assert_null(rig.flash_overlay())
	rig.flash_at(point, 0.0, 0.25, 0.5)
	assert_null(rig.flash_overlay(), "zero strength: no overlay")
	assert_eq(_materials(rig)[0].emission_energy_multiplier, 0.0, "and the whole-body flash ended")
	rig.flash_at(point, 1.0, 0.25, 0.5)
	rig.set_flash(0.0)
	assert_null(rig.flash_overlay())
	for mat in _materials(rig):
		assert_null(mat.next_pass)


func test_a_thrown_pipe_and_a_flying_body_flash_the_struck_body_at_full_strength() -> void:
	# Neither contact comes from a hitbox: the pipe's meets the body's capsule, short of the
	# body, and a body impact's lies between the two bodies. Both used to flash the air in
	# front of the struck body (0.29 m and 0.18 m from it: none, and 61%).
	await _setup(3.0)
	var dummy := dummies[0]
	var pipe := get_tree().get_first_node_in_group(&"weapon") as Weapon
	pipe.global_position = player.global_position + player.global_basis * Vector3(0.0, 0.1, -0.4)
	pipe.linear_velocity = Vector3.ZERO
	await _ticks(10)
	player.input.push_press(&"GRAB", 2)
	assert_true(await _wait_until(func() -> bool: return player.holding_weapon(), 30), "picks the pipe up")
	await _ticks(30)
	_clear_hits()
	player.input.push_press(&"GRAB", 2)
	assert_true(await _wait_until(func() -> bool: return not _hits_on(dummy).is_empty(), 90), "the thrown pipe hits")
	if _hits_on(dummy).is_empty():
		return
	var thrown := _hits_on(dummy)[0]
	assert_eq(thrown.move.id, &"weapon_throw")
	assert_lte(body_gaps_at_hit[hits.find(thrown)], _core_m(), "the pipe: full strength on the struck body")
	assert_lte(_drawn_gap(dummy, thrown.contact_point), _core_m(), "its contact (the comic effects, the sound) on the body too")
	# A push kick sends the first dummy flying into the second.
	await _setup(1.5)
	var second := dummies[1]
	var spot := player.global_position + player.global_basis * Vector3(0.15, 0.0, -3.6)
	var to_player := player.global_position - spot
	second.set_post(spot, atan2(-to_player.x, -to_player.z), true)
	await _ticks(3)
	_clear_hits()
	for button: StringName in [&"P", &"P", &"K"]:
		player.input.push_press(button, 2)
		player.input.push_wait(8)
	assert_true(await _wait_until(func() -> bool: return not _hits_on(second).is_empty(), 150), "the flying body hits the second dummy")
	if _hits_on(second).is_empty():
		return
	var impact := _hits_on(second)[0]
	assert_true(impact.is_body_impact, "a body impact")
	assert_lte(body_gaps_at_hit[hits.find(impact)], _core_m(), "the impact: full strength on the struck body")


func test_a_hit_on_a_staggering_body_flashes_the_struck_part_as_drawn() -> void:
	# The stagger's partial ragdoll (ragdoll_partial_influence 0.9) draws the head away from
	# its hurtbox, where the next hit's contact lands; the flash used to stay at that contact,
	# beyond its radius from the head as drawn (none on it).
	await _setup(1.6)
	var dummy := dummies[0]
	var hit := _synthetic_hit(dummy, CombatTypes.Reaction.STAGGER, CombatTypes.Region.TORSO)
	hit.contact_point = dummy.rig.get_point_position(&"ChestPoint") + dummy.get_forward() * 0.15
	assert_true(dummy.receive_hit(hit), "the first hit staggers")
	# The re-hit's contact on the head's hurtbox (the animation pose), facing the player, as
	# the player's hitbox finds it: wait until it lies beyond the flash radius from the head
	# as drawn.
	var head_bones: Array = REGION_BONES[CombatTypes.Region.HEAD]
	var contact := func() -> Vector3:
		return dummy.rig.get_point_position(&"Head") + Vector3.UP * 0.11 + dummy.get_forward() * 0.13
	var off := func() -> float: return _drawn_gap(dummy, contact.call(), head_bones)
	assert_true(await _wait_until(func() -> bool: return off.call() > Tuning.data.hit_flash_radius_m, 40),
			"the drawn head leaves its hurtbox (%.2f m)" % off.call())
	assert_true(dummy.rig.is_ragdolling(), "in the partial ragdoll")
	var again := _synthetic_hit(dummy, CombatTypes.Reaction.FLINCH, CombatTypes.Region.HEAD)
	again.contact_point = contact.call()
	assert_true(dummy.receive_hit(again), "the re-hit lands")
	var overlay := dummy.rig.flash_overlay()
	assert_not_null(overlay)
	if overlay == null:
		return
	assert_lte(_drawn_gap(dummy, overlay.get_shader_parameter(&"flash_point"), head_bones), _core_m(),
			"full strength on the drawn head")
	for i in Tuning.data.hit_flash_frames - 1:
		await get_tree().process_frame
		overlay = dummy.rig.flash_overlay()
		if overlay:
			assert_lte(_drawn_gap(dummy, overlay.get_shader_parameter(&"flash_point"), head_bones), _core_m(),
					"and it stays on it while the body moves")


func test_p_p_p_p_flashes_each_struck_part_as_drawn() -> void:
	# Jab, jab, hook (a stagger: the partial ragdoll), then, once the hooked head swings
	# away, the uppercut on the staggering body (a launch: the full ragdoll). The uppercut
	# used to flash beside the drawn head it struck (0.26 m from it).
	await _setup(1.4)
	var dummy := dummies[0]
	for i in 4:
		player.input.push_press(&"P", 2)
		player.input.push_wait(24 if i == 2 else 8)
	assert_true(await _wait_until(func() -> bool: return _hits_on(dummy).size() >= 4, 200), "four hits land")
	var on_dummy := _hits_on(dummy)
	var ids: Array[StringName] = []
	for hit in on_dummy:
		ids.append(hit.move.id)
		assert_lte(gaps_at_hit[hits.find(hit)], _core_m(),
				"%s: full strength on the drawn %s" % [hit.move.id, CombatTypes.Region.keys()[hit.region]])
	assert_eq(ids.slice(0, 4), [&"jab_1", &"jab_2", &"hook", &"uppercut"] as Array[StringName])
	if on_dummy.size() >= 4:
		assert_eq(on_dummy[2].reaction, CombatTypes.Reaction.STAGGER, "the hook staggers, so the uppercut re-hits a staggering body")
		assert_eq(on_dummy[3].region, CombatTypes.Region.HEAD, "on the head")


## A hit on `victim` from the player, pushing it straight back (contact point unset).
func _synthetic_hit(victim: CombatActor, reaction: CombatTypes.Reaction, region: CombatTypes.Region) -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = player
	hit.victim = victim
	hit.damage = 1.0
	hit.tier = CombatTypes.HitTier.HEAVY
	hit.reaction = reaction
	hit.region = region
	hit.direction = -victim.get_forward()
	hit.knockback = hit.direction * 4.0
	hit.physics_frame = Engine.get_physics_frames()
	return hit
