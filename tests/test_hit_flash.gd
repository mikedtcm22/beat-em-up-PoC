extends GutTest
## The localized white hit flash (Spec §6, Game-boy's departure of 2026-10-24; README "Where
## M2 departs from the spec"): a clean hit, a guard break and a blocked hit flash the
## victim's body around the contact point through its rig's overlay (HumanoidRig.flash_at(),
## game/fx/hit_flash.gdshader) for exactly Tuning.hit_flash_frames rendered frames, whichever
## actor runs first in the tick; the cyan parry flash stays whole-body; idle rigs draw no
## extra pass; a large radius whites the whole body. The flash lands on the struck part as it
## is drawn: contacts off the body (a thrown pipe, a flying body) and bodies drawn away from
## their hurtboxes (a stagger's partial ragdoll, a full ragdoll) flash at full strength there.
## A clean finisher's flash waits out the impact frame, then shows its hit_flash_frames.

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


## Every material of `rig` (one per paint). (M4, P1-toon: the toon ShaderMaterials; the
## whole-body flash is their `flash_color` times `flash_amount`, was `emission` times
## `emission_energy_multiplier`.)
func _materials(rig: HumanoidRig) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	var mats: Dictionary[int, ShaderMaterial] = rig.get(&"_materials")
	for paint: int in mats:
		out.append(mats[paint])
	return out


## The whole-body flash share on `mat` (was emission_energy_multiplier).
func _flash_amount(mat: ShaderMaterial) -> float:
	return float(mat.get_shader_parameter(&"flash_amount"))


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
		assert_eq(_flash_amount(mat), 0.0, "no whole-body flash")
	var mats: Dictionary[int, ShaderMaterial] = dummy.rig.get(&"_materials")
	# Was detail_enabled: the skin still takes marks (and a flash adds none of its own).
	assert_gt(float(mats[PlaceholderBody.Paint.SKIN].get_shader_parameter(&"marks")), 0.5, "the damage look stays under it")
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
		assert_eq(mat.get_shader_parameter(&"flash_color"), CombatActor.PARRY_FLASH_COLOR, "cyan")
		assert_almost_eq(_flash_amount(mat), 1.0, 1e-6, "over the whole body")
	await _ticks(Tuning.data.parry_flash_frames + 1)
	for mat in _materials(dummy.rig):
		assert_eq(_flash_amount(mat), 0.0, "cleared after parry_flash_frames")


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
		assert_eq(_flash_amount(mat), 0.0)
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
	assert_eq(_flash_amount(_materials(rig)[0]), 0.0, "and the whole-body flash ended")
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
	# used to flash beside the drawn head it struck (0.26 m from it). Its flash waits out the
	# impact frame (impact_frame_ticks()), so it is measured on the first frame it shows,
	# with the body already launched.
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
		var gap := gaps_at_hit[hits.find(hit)]
		if CombatActor.impact_frame_ticks(hit) > 0:
			assert_eq(gap, INF, "%s: no flash under the impact frame" % hit.move.id)
			assert_true(await _wait_until(func() -> bool: return dummy.rig.flash_overlay() != null, 10), "then it flashes")
			var overlay := dummy.rig.flash_overlay()
			gap = _drawn_gap(dummy, overlay.get_shader_parameter(&"flash_point"), REGION_BONES[hit.region]) if overlay else INF
		assert_lte(gap, _core_m(),
				"%s: full strength on the drawn %s" % [hit.move.id, CombatTypes.Region.keys()[hit.region]])
	assert_eq(ids.slice(0, 4), [&"jab_1", &"jab_2", &"hook", &"uppercut"] as Array[StringName])
	if on_dummy.size() >= 4:
		assert_eq(on_dummy[2].reaction, CombatTypes.Reaction.STAGGER, "the hook staggers, so the uppercut re-hits a staggering body")
		assert_eq(on_dummy[3].region, CombatTypes.Region.HEAD, "on the head")
		assert_gt(CombatActor.impact_frame_ticks(on_dummy[3]), 0, "the uppercut's flash waits")


func test_a_finisher_flashes_right_after_its_impact_frame() -> void:
	# The impact frame (VfxDirector, the whole screen in ink) starts on a clean finisher's tick
	# for vfx_impact_frame_frames, and the contact flash used to start with it for as many
	# frames: it was spent under the impact frame, so no finisher ever showed one (hit-04).
	# [impact_frame_enabled, vfx_impact_frame_frames, hit_flash_frames]
	for case: Array in [[true, 2, 2], [true, 1, 3], [true, 0, 2], [false, 2, 2]]:
		await _setup(1.4)
		var vfx := _add_vfx()
		var on: bool = case[0]
		var impact: int = case[1] if on else 0
		var frames: int = case[2]
		Tuning.data.impact_frame_enabled = on
		Tuning.data.vfx_impact_frame_frames = case[1]
		Tuning.data.hit_flash_frames = frames
		var label := "impact frame %s, %d frame(s), flash %d" % ["on" if on else "off", case[1], frames]
		var dummy := dummies[0]
		for i in 4:
			player.input.push_press(&"P", 2)
			player.input.push_wait(24 if i == 2 else 8)
		var recorded := await _record(dummy, vfx, 4, 10)
		var on_dummy := _hits_on(dummy)
		assert_eq(on_dummy.size(), 4, "%s: four hits land" % label)
		if on_dummy.size() < 4:
			continue
		var tiers: Array[int] = [CombatTypes.HitTier.LIGHT, CombatTypes.HitTier.LIGHT, CombatTypes.HitTier.HEAVY,
				CombatTypes.HitTier.FINISHER]
		for n in 4:
			assert_eq(on_dummy[n].tier, tiers[n], "%s: %s's tier" % [label, on_dummy[n].move.id])
		# The jabs and the hook: no impact frame, the flash from the hit's frame as before.
		for n in 3:
			var seen := _window(recorded, n, 8)
			assert_gt(seen.size(), frames, "%s: %s is recorded past its flash" % [label, on_dummy[n].move.id])
			assert_eq(seen, _expected(seen.size(), 0, 0, frames), "%s: %s" % [label, on_dummy[n].move.id])
		# The uppercut: its flash on exactly hit_flash_frames frames, right after the impact frame.
		assert_eq(_window(recorded, 3, 8), _expected(8, impact, impact, frames), "%s: the uppercut" % label)


func test_a_finisher_s_late_flash_lands_on_the_struck_part_and_a_ko_still_flashes() -> void:
	await _setup(1.6)
	var vfx := _add_vfx()
	var dummy := dummies[0]
	var head_bones: Array = REGION_BONES[CombatTypes.Region.HEAD]
	# A finisher that KOs and launches: the body is in the full ragdoll by the time its flash
	# shows, which must still be on the head it struck, as drawn.
	await get_tree().physics_frame
	var hit := _synthetic_hit(dummy, CombatTypes.Reaction.LAUNCH, CombatTypes.Region.HEAD)
	hit.tier = CombatTypes.HitTier.FINISHER
	hit.damage = dummy.health + 1.0
	hit.knockback = hit.direction * 6.0 + Vector3.UP * 5.0
	hit.contact_point = dummy.rig.get_point_position(&"Head") + dummy.get_forward() * 0.1
	assert_true(dummy.receive_hit(hit), "the finisher lands")
	CombatEvents.hit_landed.emit(hit)
	assert_true(hit.killed, "and KOs")
	assert_null(dummy.rig.flash_overlay(), "no flash under the impact frame")
	var seen: Array[String] = []
	var gaps: Array[float] = []
	for i in 6:
		await get_tree().physics_frame
		seen.append(_shown(vfx, dummy))
		var overlay := dummy.rig.flash_overlay()
		if overlay:
			gaps.append(_drawn_gap(dummy, overlay.get_shader_parameter(&"flash_point"), head_bones))
	assert_eq(seen, _expected(6, 2, 2, 2), "the KO's flash right after its impact frame")
	assert_true(dummy.rig.is_ragdolling(), "launched into the ragdoll")
	assert_eq(gaps.size(), 2)
	for gap in gaps:
		assert_lte(gap, _core_m(), "full strength on the drawn head")
	# A reset while the flash waits (a revive, the bots' resets) cancels it.
	dummy.reset_state()
	await _ticks(5)
	await get_tree().physics_frame
	var again := _synthetic_hit(dummy, CombatTypes.Reaction.KNOCKDOWN, CombatTypes.Region.TORSO)
	again.tier = CombatTypes.HitTier.FINISHER
	again.contact_point = dummy.rig.get_point_position(&"ChestPoint") + dummy.get_forward() * 0.15
	assert_true(dummy.receive_hit(again))
	dummy.reset_state()
	for i in 5:
		await get_tree().physics_frame
		assert_false(_overlay_on(dummy.rig), "frame %d: a reset cancels the waiting flash" % i)


## Add a VfxDirector (the impact frame), and a camera for its effects, to the test room.
func _add_vfx() -> VfxDirector:
	var camera := Camera3D.new()
	room.add_child(camera)
	camera.global_position = player.global_position + Vector3.UP * 1.6
	camera.make_current()
	var vfx := VfxDirector.new()
	room.add_child(vfx)
	return vfx


## What the frame just drawn showed: the impact frame "I", `victim`'s contact flash "F",
## both "IF", or neither "-". Read as a tick starts, before any actor runs.
func _shown(vfx: VfxDirector, victim: CombatActor) -> String:
	var shown := ("I" if vfx.impact_frame.is_flashing() else "") + ("F" if _overlay_on(victim.rig) else "")
	return shown if shown != "" else "-"


## Each rendered frame until `after` frames past the `hits_wanted`-th hit on `victim` (240 at
## most): [the hits on `victim` landed by then, _shown()].
func _record(victim: CombatActor, vfx: VfxDirector, hits_wanted: int, after: int) -> Array[Array]:
	var out: Array[Array] = []
	var past := 0
	for i in 240:
		await get_tree().physics_frame
		var landed := _hits_on(victim).size()
		out.append([landed, _shown(vfx, victim)])
		if landed >= hits_wanted:
			past += 1
			if past >= after:
				break
	return out


## The frames of `recorded` (_record()) from the one hit `nth` (from 0) landed in: `count`
## of them at most, and none from the next hit's on.
func _window(recorded: Array[Array], nth: int, count: int) -> Array[String]:
	var out: Array[String] = []
	for row: Array in recorded:
		var landed: int = row[0]
		if landed > nth + 1 or out.size() >= count:
			break
		if landed == nth + 1:
			out.append(row[1])
	return out


## `count` frames from a hit's: the impact frame on the first `impact`, the contact flash on
## `flash` frames from frame `delay`.
func _expected(count: int, impact: int, delay: int, flash: int) -> Array[String]:
	var out: Array[String] = []
	for i in count:
		var shown := ("I" if i < impact else "") + ("F" if i >= delay and i < delay + flash else "")
		out.append(shown if shown != "" else "-")
	return out


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
