extends GutTest
## The contact flash in first person (Milestone 4, P3-flash: feel questions 1 and 2 of M4-plan Part C
## section 8, and F-motion's warm-up request), each alternative behind a toggle that defaults to
## today's behavior.
##
## Question 1 (grab-05, hit-01): Tuning's hit_flash_fp_max_share (Look > FP feel, 0 = off) caps how much
## of the view the flash may cover on screen. The overlay shader computes it from the camera that draws
## it (game/fx/hit_flash.gdshader, cap_scale() and cap_distance()); HumanoidRig.flash_cap_scale() and
## flash_cap_distance() mirror it for these tests, as ToonMaterials.outline_width_m() mirrors the hull's
## width, and the rig hands the share to the shader as the uniform flash_max_share. Question 2 (r3look-05): hit_flash_finisher_radius_mult
## (1 = off) widens a clean finisher's flash, and only that. The warm-up: RoomKit.warm_up_libraries()
## builds the Bruiser's and the boss's named animation libraries before their first spawn.
## The shader itself cannot run headless: tests/bot/acts/flash_fp_acts.gd measures it in a window
## (M4-calls/P3-flash.md has the figures).

const ROOM := preload("res://game/level/test_room.tscn")
const FlashActs := preload("res://tests/bot/acts/flash_fp_acts.gd")
const SHADER := preload("res://game/fx/hit_flash.gdshader")
## The view the game is played in: 16:9 (the first-person camera's field of view is Tuning's fov_deg,
## vertical, so its projection[1][1] is 1 / tan(fov / 2)).
const ASPECT := 16.0 / 9.0
const FAR := Vector3(30.0, 0.0, -30.0)
## The test's own tolerances for floating point comparisons.
const EPS := 0.0001

var room: Node3D
var player: PlayerCharacter
var dummies: Array[TrainingDummy] = []
var hits: Array[HitInfo] = []
## The overlay's radius as each hit's flash stands once the hit's event is through (deferred: the rig
## widens a finisher's flash in its own hit_landed listener).
var radii_after_hit: Array[float] = []


func before_each() -> void:
	TimeController.clear()
	TimeController.debug_scale = 1.0
	Tuning.apply(TuningData.new())
	Tuning.data.dummy_health = 500.0
	hits.clear()
	radii_after_hit.clear()
	CombatEvents.hit_landed.connect(_on_hit, CONNECT_DEFERRED)


func after_each() -> void:
	CombatEvents.hit_landed.disconnect(_on_hit)
	TimeController.clear()
	Tuning.apply(TuningData.new())


func _on_hit(hit: HitInfo) -> void:
	# Deferred: a hit emitted at a test's end arrives after the room (and its victim) is gone.
	if not is_instance_valid(hit.victim):
		return
	hits.append(hit)
	var overlay := _overlay_of((hit.victim as CombatActor).rig)
	radii_after_hit.append(float(overlay.get_shader_parameter(&"flash_radius")) if overlay else NAN)


# --- Harness ------------------------------------------------------------------------------


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_until(condition: Callable, max_ticks: int = 240) -> bool:
	for i in max_ticks:
		if condition.call():
			return true
		await get_tree().physics_frame
	return false


## The test room (no presentation) with the first dummy `dist` ahead of the player, facing him.
func _setup(dist: float = 1.4) -> void:
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
				else FAR + Vector3(i * 3.0, 0.0, 0.0)
		var to_player := player.global_position - pos
		dummies[i].sparring = false
		dummies[i].set_post(pos, atan2(-to_player.x, -to_player.z), true)
	await _ticks(3)
	hits.clear()
	radii_after_hit.clear()


## The rig's overlay whether it is drawn or held back (a finisher's waits out the impact frame).
func _overlay_of(rig: HumanoidRig) -> ShaderMaterial:
	return rig.get(&"_flash_overlay") as ShaderMaterial


func _radius_of(rig: HumanoidRig) -> float:
	return float(_overlay_of(rig).get_shader_parameter(&"flash_radius"))


func _share_of(rig: HumanoidRig) -> float:
	return float(_overlay_of(rig).get_shader_parameter(&"flash_max_share"))


## A rig on its own in the tree, built: the flash needs nothing but its body.
func _rig() -> HumanoidRig:
	var rig := HumanoidRig.new()
	add_child_autofree(rig)
	rig.build()
	return rig


## A hit on `victim` as the detector reports it: `tier`, blocked or not.
func _hit_on(victim: CombatActor, tier: CombatTypes.HitTier, blocked: bool = false) -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = player
	hit.victim = victim
	hit.tier = tier
	hit.blocked = blocked
	hit.damage = 1.0
	return hit


# --- Both default to today's behavior -----------------------------------------------------------


func test_both_alternatives_default_to_today_and_sit_in_fp_feel() -> void:
	var data := TuningData.new()
	assert_eq(data.hit_flash_fp_max_share, 0.0, "no cap on the flash's on-screen share by default")
	assert_eq(data.hit_flash_finisher_radius_mult, 1.0, "a finisher's flash is the ordinary size by default")
	for name: StringName in [&"hit_flash_fp_max_share", &"hit_flash_finisher_radius_mult"]:
		var info := Tuning._property_info(Tuning.tuning_properties(), name)
		assert_eq(info.group, "Look", "%s: in the Look group" % name)
		assert_eq(info.subgroup, "FP feel", "%s: in the FP feel subgroup, beside the other three alternatives" % name)
		assert_eq(info.type, TYPE_FLOAT, "%s: a slider" % name)
		assert_true(Tuning.is_preset_property(name), "%s: a preset holds it" % name)
		assert_true(FileAccess.get_file_as_string("res://tuning/default.json").contains(name), "%s: tuning/default.json lists it" % name)


func test_the_shader_takes_the_cap_as_a_uniform_that_is_off_by_default() -> void:
	var names: Array[String] = []
	for info: Dictionary in SHADER.get_shader_uniform_list():
		names.append(String(info.name))
	for uniform: String in ["flash_point", "flash_radius", "flash_core", "flash_strength", "flash_color", "flash_max_share"]:
		assert_has(names, uniform, "the shader keeps %s" % uniform)
	var declaration := RegEx.create_from_string("uniform\\s+float\\s+flash_max_share[^;]*=\\s*([0-9.]+)\\s*;").search(SHADER.code)
	assert_not_null(declaration, "flash_max_share is declared with a default")
	if declaration != null:
		assert_eq(float(declaration.get_string(1)), 0.0, "flash_max_share is 0 (no cap) until the rig sets it")
	assert_true(SHADER.code.contains("cap_distance(VERTEX, point"), "the cap measures the fragment's view-space distance")
	assert_true(SHADER.code.contains("abs(PROJECTION_MATRIX[1][1])"),
			"from the camera that draws it (its Y scale is negative in a flipped target: the abs)")
	assert_true(SHADER.code.contains("if (flash_max_share > 0.0)"), "and only with the cap on: off, the distance is today's")


func test_the_defaults_leave_todays_flash_as_it_was() -> void:
	# A flash with the defaults: the uniforms are what the struck actor passed in, and the cap is off.
	var rig := _rig()
	rig.flash_at(Vector3(0.1, 1.2, 0.0), 1.0, Tuning.data.hit_flash_radius_m, Tuning.data.hit_flash_core)
	var overlay := rig.flash_overlay()
	assert_not_null(overlay, "the flash is drawn")
	assert_almost_eq(float(overlay.get_shader_parameter(&"flash_radius")), 0.25, EPS, "hit_flash_radius_m as it is")
	assert_almost_eq(float(overlay.get_shader_parameter(&"flash_core")), 0.5, EPS, "the core as it is")
	assert_almost_eq(float(overlay.get_shader_parameter(&"flash_strength")), 1.0, EPS, "the strength as it is")
	assert_eq(float(overlay.get_shader_parameter(&"flash_max_share")), 0.0, "no cap")
	# And the mirror: with no cap the distance is the plain distance, at any depth.
	for depth: float in [0.0, 0.05, 0.3, 1.0, 10.0]:
		assert_eq(HumanoidRig.flash_cap_scale(0.25, depth, 1.3, ASPECT, 0.0), 1.0, "no cap at %.2f m" % depth)
		var fragment := Vector3(0.1, 0.05, -depth - 0.1)
		var point := Vector3(0.0, 0.0, -depth)
		assert_eq(HumanoidRig.flash_cap_distance(fragment, point, 0.25, 1.3, ASPECT, 0.0), (fragment - point).length(),
				"the plain distance at %.2f m" % depth)
	# A finisher with the multiple at 1: the same radius.
	rig.flash_at(Vector3(0.1, 1.2, 0.0), 1.0, 0.25, 0.5)
	rig._widen_flash(Tuning.data.hit_flash_finisher_radius_mult)
	assert_almost_eq(_radius_of(rig), 0.25, EPS, "a finisher's flash is as it was")


# --- Question 1: the cap on the flash's share of the view ---------------------------------------


func test_the_cap_scale_is_the_shrink_that_fits_the_disc_to_the_share() -> void:
	var proj11 := 1.3
	for share: float in [0.02, 0.06, 0.1, 0.25]:
		for depth: float in [0.2, 0.5, 1.0, 3.0]:
			var scale := HumanoidRig.flash_cap_scale(0.25, depth, proj11, ASPECT, share)
			assert_between(scale, 0.0, 1.0, "a shrink, never a growth")
			if scale < 1.0:
				assert_almost_eq(HumanoidRig.flash_view_share(0.25 * scale, depth, proj11, ASPECT), share, EPS,
						"the shrunk disc covers exactly %.2f of the view at %.1f m" % [share, depth])
			else:
				assert_lte(HumanoidRig.flash_view_share(0.25, depth, proj11, ASPECT), share + EPS,
						"a flash that is not shrunk already fits (%.2f at %.1f m)" % [share, depth])


func test_the_cap_scale_grows_with_the_distance_and_is_one_far_away() -> void:
	var proj11 := 1.3
	var last := 0.0
	for depth: float in [0.05, 0.1, 0.2, 0.4, 0.8, 1.6, 3.2]:
		var scale := HumanoidRig.flash_cap_scale(0.25, depth, proj11, ASPECT, 0.06)
		assert_gte(scale, last, "farther away the flash is shrunk less (%.2f m)" % depth)
		last = scale
	assert_eq(HumanoidRig.flash_cap_scale(0.25, 3.2, proj11, ASPECT, 0.06), 1.0, "far away the flash is as it was")
	assert_lt(HumanoidRig.flash_cap_scale(0.25, 0.3, proj11, ASPECT, 0.06), 1.0, "a few centimeters from the lens it shrinks")
	assert_eq(HumanoidRig.flash_cap_scale(0.25, 0.0, proj11, ASPECT, 0.06), 0.0, "at the lens there is no room for a flash")
	# A wider view (the same share of more pixels) shrinks the same flash less; a longer lens more.
	assert_gt(HumanoidRig.flash_cap_scale(0.25, 0.3, proj11, 2.4, 0.06), HumanoidRig.flash_cap_scale(0.25, 0.3, proj11, 1.0, 0.06))
	assert_gt(HumanoidRig.flash_cap_scale(0.25, 0.3, 0.9, ASPECT, 0.06), HumanoidRig.flash_cap_scale(0.25, 0.3, 2.0, ASPECT, 0.06))


## The grid the footprint tests walk: the fragments' spacing on the surface (m).
const GRID_M := 0.005
const GRID_N := 240


## The flash's footprint on a flat surface `depth` m in front of the lens, perpendicular to the view axis
## (view space, z negative ahead), around a point at `point`: the fragments of a grid it reaches
## (cap_distance inside `radius`), as screen positions in half-heights of the view.
func _footprint(point: Vector3, depth: float, radius: float, proj11: float, share: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for ix in range(-GRID_N, GRID_N + 1):
		for iy in range(-GRID_N, GRID_N + 1):
			var fragment := Vector3(ix * GRID_M, iy * GRID_M, -depth)
			if HumanoidRig.flash_cap_distance(fragment, point, radius, proj11, ASPECT, share) < radius:
				out.append(Vector2(fragment.x, fragment.y) * proj11 / depth)
	return out


func test_the_flash_stays_inside_a_disc_of_the_share_around_its_screen_position() -> void:
	# The stretch is across the line of sight to the point, so the disc is exact on the view axis and
	# at most 1 / cos(angle of the point off the axis) wider off it (the line of sight is not square to
	# the surface): the bound is that, plus the grid's own step.
	var proj11 := 1.0 / tan(deg_to_rad(Tuning.data.fov_deg) * 0.5) * ASPECT
	for share: float in [0.03, 0.06, 0.12]:
		var limit := sqrt(4.0 * ASPECT * share / PI)
		# The surface at 0.4 m; the point on it, in front of it (nearer the lens), and behind it.
		for point_depth: float in [0.4, 0.3, 0.55]:
			var point := Vector3(0.12, -0.05, -point_depth)
			var anchor := Vector2(point.x, point.y) * proj11 / point_depth
			var reached := _footprint(point, 0.4, 0.25, proj11, share)
			var farthest := 0.0
			for spot: Vector2 in reached:
				farthest = maxf(farthest, spot.distance_to(anchor))
			var secant := point.length() / point_depth
			var bound := limit * secant + GRID_M * proj11 / 0.4 * 2.0
			assert_lte(farthest, bound, "share %.2f, point at %.2f m: the flash reaches %.3f half-heights from its place (limit %.3f x %.2f)" % [share, point_depth, farthest, limit, secant])
			var area := float(reached.size()) * pow(GRID_M * proj11 / 0.4, 2.0)
			assert_lte(area / (4.0 * ASPECT), share * secant * secant * 1.1, "share %.2f, point at %.2f m: the footprint is %.3f of the view" % [share, point_depth, area / (4.0 * ASPECT)])
		# On the view axis the disc is the share: the footprint is at the share, within the grid's step.
		var centred := _footprint(Vector3(0.0, 0.0, -0.4), 0.4, 0.25, proj11, share)
		assert_almost_eq(float(centred.size()) * pow(GRID_M * proj11 / 0.4, 2.0) / (4.0 * ASPECT), share, share * 0.1,
				"share %.2f: on the axis the flash covers the share" % share)


func test_the_capped_flash_is_inside_the_uncapped_one_and_keeps_its_place() -> void:
	var proj11 := 1.0 / tan(deg_to_rad(Tuning.data.fov_deg) * 0.5) * ASPECT
	var point := Vector3(0.0, 0.0, -0.4)
	for share: float in [0.0, 0.03, 0.12]:
		var count := _footprint(point, 0.4, 0.25, proj11, share).size()
		if share == 0.0:
			assert_gt(count, 0, "the uncapped flash covers the surface")
			continue
		var plain := _footprint(point, 0.4, 0.25, proj11, 0.0).size()
		assert_lt(count, plain, "share %.2f shrinks the footprint" % share)
		assert_gt(count, 0, "share %.2f leaves a flash" % share)
		# Every fragment the cap reaches, the plain distance reaches: a stretch never reaches farther.
		for ix in range(-12, 13):
			var fragment := Vector3(ix * 0.02, 0.01, -0.4)
			assert_gte(HumanoidRig.flash_cap_distance(fragment, point, 0.25, proj11, ASPECT, share) + EPS,
					(fragment - point).length(), "the capped distance is never less than the plain one")


func test_a_flash_that_fits_the_share_is_not_touched_even_where_its_disc_does_not() -> void:
	# A point 0.24 m behind the surface the lens sees: the flash (0.25 m) reaches only 0.07 m across the
	# surface, a patch of 0.31 half-heights at 0.4 m, inside the 6% limit (0.369) though the whole disc
	# of 0.25 m there would be 54% of the view. The cap leaves it alone, fragment for fragment.
	var proj11 := 1.0 / tan(deg_to_rad(Tuning.data.fov_deg) * 0.5) * ASPECT
	var point := Vector3(0.0, 0.0, -0.64)
	for ix in range(-12, 13):
		for iy in range(-12, 13):
			var fragment := Vector3(ix * 0.01, iy * 0.01, -0.4)
			assert_eq(HumanoidRig.flash_cap_distance(fragment, point, 0.25, proj11, ASPECT, 0.06),
					(fragment - point).length(), "the plain distance at (%d, %d)" % [ix, iy])
	# The same flash 0.1 m behind the surface reaches 0.23 m across: past the limit, so it is shrunk.
	var near := Vector3(0.0, 0.0, -0.5)
	var fragment := Vector3(0.1, 0.0, -0.4)
	assert_gt(HumanoidRig.flash_cap_distance(fragment, near, 0.25, proj11, ASPECT, 0.06), (fragment - near).length())


func test_a_point_behind_the_near_surface_still_flashes_what_is_in_front_of_it() -> void:
	# The knee's contact lies under a cap's brim: the point is 0.15 m behind the surface the lens sees.
	var proj11 := 1.0 / tan(deg_to_rad(Tuning.data.fov_deg) * 0.5) * ASPECT
	var point := Vector3(0.0, 0.0, -0.55)
	var on_the_sight_line := Vector3(0.0, 0.0, -0.4)
	var capped := HumanoidRig.flash_cap_distance(on_the_sight_line, point, 0.25, proj11, ASPECT, 0.06)
	assert_almost_eq(capped, 0.15, EPS, "straight in front of the point the distance is the depth between them")
	assert_lt(capped, 0.25, "so the surface there is flashed, whatever the cap")
	# A fragment off the sight line by what would be a screen radius over the limit is not.
	var limit := sqrt(4.0 * ASPECT * 0.06 / PI)
	var lateral := limit * 0.4 / proj11 * 1.5
	var off := Vector3(lateral, 0.0, -0.4)
	assert_gt(HumanoidRig.flash_cap_distance(off, point, 0.25, proj11, ASPECT, 0.06), 0.25, "but one 1.5 limits off the sight line is not")
	assert_lt(HumanoidRig.flash_cap_distance(off, point, 0.25, proj11, ASPECT, 0.0), 0.25, "though today's flash would have reached it")


func test_a_knee_at_the_lens_is_capped_where_a_jab_at_one_meter_is_not() -> void:
	# The disc of Tuning's radius (0.25 m): a jab's contact 0.9 m from the lens and a knee's 0.4 m.
	var proj11 := 1.0 / tan(deg_to_rad(Tuning.data.fov_deg) * 0.5) * ASPECT
	var jab := HumanoidRig.flash_view_share(0.25, 0.9, proj11, ASPECT)
	var knee := HumanoidRig.flash_view_share(0.25, 0.4, proj11, ASPECT)
	assert_gt(knee, 2.0 * jab, "a knee's flash disc is several times a jab's (%.3f against %.3f)" % [knee, jab])
	var share := (jab + knee) * 0.5
	assert_eq(HumanoidRig.flash_cap_scale(0.25, 0.9, proj11, ASPECT, share), 1.0, "a cap between them leaves the jab as it was")
	assert_lt(HumanoidRig.flash_cap_scale(0.25, 0.4, proj11, ASPECT, share), 1.0, "and shrinks the knee")


func test_the_rig_hands_the_overlay_the_cap_on_every_flash() -> void:
	var rig := _rig()
	Tuning.data.hit_flash_fp_max_share = 0.06
	rig.flash_at(Vector3(0.0, 1.2, 0.0), 1.0, 0.25, 0.5)
	assert_almost_eq(float(rig.flash_overlay().get_shader_parameter(&"flash_max_share")), 0.06, EPS, "the cap is the tunable's")
	assert_almost_eq(_radius_of(rig), 0.25, EPS, "the radius the actor passed is untouched: the shader does the capping")
	Tuning.data.hit_flash_fp_max_share = 0.0
	rig.flash_at(Vector3(0.0, 1.2, 0.0), 1.0, 0.25, 0.5)
	assert_eq(float(rig.flash_overlay().get_shader_parameter(&"flash_max_share")), 0.0, "and the next flash takes the new value")


func test_the_simulation_does_not_depend_on_either_tunable() -> void:
	# The same hit with and without them: the same damage, reaction and knockback (the flash is paint).
	var outcomes: Array[Array] = []
	for on in [false, true]:
		Tuning.apply(TuningData.new())
		Tuning.data.dummy_health = 500.0
		Tuning.data.hit_flash_fp_max_share = 0.06 if on else 0.0
		Tuning.data.hit_flash_finisher_radius_mult = 3.0 if on else 1.0
		await _setup(1.0)
		var landed := await _punch_and_wait()
		assert_not_null(landed, "the hit lands")
		if landed != null:
			outcomes.append([landed.damage, landed.reaction, landed.knockback, landed.tier])
	assert_eq(outcomes.size(), 2)
	if outcomes.size() == 2:
		assert_eq(outcomes[0], outcomes[1], "damage, reaction, knockback and tier do not change")


func _punch_and_wait() -> HitInfo:
	player.input.push_press(&"P", 2)
	if not await _wait_until(func() -> bool: return not hits.is_empty()):
		return null
	return hits[0]


# --- Question 2: the finisher's radius ----------------------------------------------------------


func test_a_clean_finisher_s_flash_is_widened_and_no_other_tier_is() -> void:
	await _setup(1.4)
	var dummy := dummies[0]
	Tuning.data.hit_flash_finisher_radius_mult = 2.0
	Tuning.data.hit_flash_fp_max_share = 0.05
	var base := Tuning.data.hit_flash_radius_m
	for case: Array in [
			[CombatTypes.HitTier.FINISHER, false, 2.0], [CombatTypes.HitTier.HEAVY, false, 1.0],
			[CombatTypes.HitTier.LIGHT, false, 1.0], [CombatTypes.HitTier.FINISHER, true, 1.0]]:
		dummy.rig.flash_at(dummy.global_position + Vector3.UP, 1.0, base, Tuning.data.hit_flash_core)
		CombatEvents.hit_landed.emit(_hit_on(dummy, case[0], case[1]))
		await _ticks(1)
		var label := "%s%s" % [CombatTypes.tier_name(case[0]), " blocked" if case[1] else ""]
		assert_almost_eq(_radius_of(dummy.rig), base * float(case[2]), EPS, "%s: radius x%.1f" % [label, case[2]])
		assert_almost_eq(_share_of(dummy.rig), minf(0.05 * float(case[2]) * float(case[2]), 1.0), EPS,
				"%s: the cap's share of the view grows with the radius (x%.1f squared)" % [label, case[2]])


func test_a_finisher_widens_its_flash_once_and_the_next_flash_starts_from_the_tunable() -> void:
	await _setup(1.4)
	var dummy := dummies[0]
	Tuning.data.hit_flash_finisher_radius_mult = 2.0
	var base := Tuning.data.hit_flash_radius_m
	dummy.rig.flash_at(dummy.global_position + Vector3.UP, 1.0, base, 0.5)
	for i in 3:
		CombatEvents.hit_landed.emit(_hit_on(dummy, CombatTypes.HitTier.FINISHER))
	await _ticks(1)
	assert_almost_eq(_radius_of(dummy.rig), base * 2.0, EPS, "three events for one flash widen it once, not x8")
	assert_eq(_share_of(dummy.rig), 0.0, "the cap, off, stays off: nothing to grow")
	dummy.rig.flash_at(dummy.global_position + Vector3.UP, 1.0, base, 0.5)
	assert_almost_eq(_radius_of(dummy.rig), base, EPS, "a later flash is aimed at the radius it is given")
	CombatEvents.hit_landed.emit(_hit_on(dummy, CombatTypes.HitTier.LIGHT))
	assert_almost_eq(_radius_of(dummy.rig), base, EPS, "a light hit's event does not carry the finisher's widening over")


func test_a_finisher_with_no_flash_widens_nothing() -> void:
	await _setup(1.4)
	var dummy := dummies[0]
	Tuning.data.hit_flash_finisher_radius_mult = 3.0
	Tuning.data.hit_flash_frames = 0
	dummy.rig.set_flash(0.0)
	var before := _overlay_of(dummy.rig)
	CombatEvents.hit_landed.emit(_hit_on(dummy, CombatTypes.HitTier.FINISHER))
	assert_eq(_overlay_of(dummy.rig), before, "no overlay is made for it")
	assert_null(dummy.rig.flash_overlay(), "and none is drawn")
	if before != null:
		assert_false(before.get_shader_parameter(&"flash_radius") == null)


func test_a_real_p_p_p_p_widens_the_uppercut_s_flash_alone() -> void:
	# jab, jab, hook, uppercut: the last is the finisher. The overlay's radius once each hit's event has
	# run (deferred) is the widened one only for it. The VFX director is absent (no impact frame to wait).
	for mult: float in [1.0, 2.5]:
		await _setup(1.4)
		Tuning.data.hit_flash_finisher_radius_mult = mult
		var base := Tuning.data.hit_flash_radius_m
		for i in 4:
			player.input.push_press(&"P", 2)
			player.input.push_wait(24 if i == 2 else 8)
		await _wait_until(func() -> bool: return hits.size() >= 4, 400)
		await _ticks(2)
		var on_dummy: Array[HitInfo] = []
		var radii: Array[float] = []
		for i in hits.size():
			if hits[i].victim == dummies[0]:
				on_dummy.append(hits[i])
				radii.append(radii_after_hit[i])
		assert_eq(on_dummy.size(), 4, "x%.1f: four hits land on the dummy" % mult)
		if on_dummy.size() < 4:
			continue
		for n in 3:
			assert_ne(on_dummy[n].tier, CombatTypes.HitTier.FINISHER, "x%.1f: hit %d is not the finisher" % [mult, n + 1])
			assert_almost_eq(radii[n], base, EPS, "x%.1f: %s's flash is the ordinary size" % [mult, on_dummy[n].move.id])
		assert_eq(on_dummy[3].tier, CombatTypes.HitTier.FINISHER, "x%.1f: the fourth is the finisher" % mult)
		assert_almost_eq(radii[3], base * mult, EPS, "x%.1f: the uppercut's flash is %.2f m" % [mult, base * mult])


func test_the_widened_flash_still_shows_for_exactly_hit_flash_frames() -> void:
	# The widening is paint: the flash lasts as long as it did.
	await _setup(1.4)
	var dummy := dummies[0]
	Tuning.data.hit_flash_finisher_radius_mult = 3.0
	Tuning.data.impact_frame_enabled = false
	for i in 4:
		player.input.push_press(&"P", 2)
		player.input.push_wait(24 if i == 2 else 8)
	var shown := 0
	var seen_finisher := false
	for i in 400:
		await get_tree().process_frame
		var finisher := false
		for hit in hits:
			if hit.victim == dummy and hit.tier == CombatTypes.HitTier.FINISHER:
				finisher = true
		if finisher:
			seen_finisher = true
			if dummy.rig.flash_overlay() != null:
				shown += 1
			elif shown > 0:
				break
	assert_true(seen_finisher, "the finisher landed")
	assert_eq(shown, Tuning.data.hit_flash_frames, "its flash is drawn for exactly hit_flash_frames frames")


# --- Both together ------------------------------------------------------------------------------


func test_a_finisher_under_the_cap_is_mult_times_an_ordinary_flash_on_screen() -> void:
	# The widened radius grows the cap's share with it (_widen_flash()), so at the same distance from the
	# lens a finisher's flash is `mult` times an ordinary one's across, not shrunk back to its size.
	var proj11 := 1.0 / tan(deg_to_rad(Tuning.data.fov_deg) * 0.5) * ASPECT
	var ordinary := Tuning.data.hit_flash_radius_m
	var mult := 2.0
	var share := 0.04
	for depth: float in [0.3, 0.5, 0.8]:
		var plain := ordinary * HumanoidRig.flash_cap_scale(ordinary, depth, proj11, ASPECT, share)
		var finisher := ordinary * mult * HumanoidRig.flash_cap_scale(ordinary * mult, depth, proj11, ASPECT, share * mult * mult)
		assert_almost_eq(finisher, plain * mult, EPS, "at %.1f m the finisher's capped reach is x%.1f an ordinary one's" % [depth, mult])
	# Far enough that neither is shrunk, the finisher is the widened radius.
	assert_eq(HumanoidRig.flash_cap_scale(ordinary * mult, 8.0, proj11, ASPECT, share * mult * mult), 1.0)


# --- The warm-up --------------------------------------------------------------------------------


## The cache key a rig of body height `height_m` gets (HumanoidRig._named_library()'s).
func _library_key(height_m: float) -> String:
	return "%s@%d" % [PlaceholderPoses.STANCE_BOXER, roundi(height_m / PlaceholderBody.REF_HEIGHT * 10000.0)]


func test_the_warm_up_builds_the_bruisers_and_the_bosses_libraries_before_they_spawn() -> void:
	HumanoidRig._named_libraries.clear()
	RoomKit.warm_up_libraries()
	var libraries: Dictionary[String, AnimationLibrary] = HumanoidRig._named_libraries
	var keys: Array[String] = []
	for id: StringName in RoomKit.WARM_LIBRARY_ENEMIES:
		var key := _library_key(EnemyCatalog.body_size(id).y)
		keys.append(key)
		assert_true(libraries.has(key), "%s: its size's library (%s) is in the cache" % [id, key])
	assert_ne(keys[0], keys[1], "the Bruiser and the boss are two sizes")
	# A real Bruiser and a real boss, spawned after, take those libraries and build no other.
	var before := libraries.keys()
	for id: StringName in RoomKit.WARM_LIBRARY_ENEMIES:
		var key := _library_key(EnemyCatalog.body_size(id).y)
		var warmed := libraries[key]
		# On a stage of its own: an enemy adds an EnemyDirector beside itself, and the stage frees both.
		var stage := Node3D.new()
		add_child_autofree(stage)
		var actor := EnemyCatalog.scene(id).instantiate() as CombatActor
		stage.add_child(actor)
		await _ticks(1)
		assert_eq(actor.rig.anim_player.get_animation_library(&""), warmed, "%s takes the warmed library" % id)
		assert_eq(libraries.keys(), before, "%s's spawn builds no library of its own" % id)


func test_the_warm_up_is_cheap_to_repeat_and_changes_no_library() -> void:
	HumanoidRig._named_libraries.clear()
	RoomKit.warm_up_libraries()
	var first: Dictionary[String, AnimationLibrary] = HumanoidRig._named_libraries.duplicate()
	RoomKit.warm_up_libraries()
	assert_eq(HumanoidRig._named_libraries.size(), first.size(), "a second call builds nothing new")
	for key: String in first:
		assert_eq(HumanoidRig._named_libraries[key], first[key], "%s: the same library object" % key)


func test_the_room_load_warm_up_does_nothing_headless() -> void:
	# warm_up_art() is windowed work: headless it builds no library and adds no node.
	HumanoidRig._named_libraries.clear()
	var holder := Node3D.new()
	add_child_autofree(holder)
	RoomKit.warm_up_art(holder)
	assert_eq(holder.get_child_count(), 0, "no throwaway rig")
	assert_true(HumanoidRig._named_libraries.is_empty(), "and no library")


# --- The instruments ----------------------------------------------------------------------------


func test_the_measuring_acts_are_in_the_file_with_titles_nothing_else_holds() -> void:
	var acts := FlashActs.acts(null)
	var slugs: Array[StringName] = []
	for act: Dictionary in acts:
		slugs.append(act.slug)
		assert_true(String(act.title).begins_with("Look: flash share"), "%s starts as a look act" % act.title)
		assert_eq(act.cam, &"first_person", "%s is recorded in first person" % act.title)
	assert_eq(slugs, [&"ff1", &"ff2", &"ff3"] as Array[StringName], "the slugs")
	for a: Dictionary in acts:
		for b: Dictionary in acts:
			assert_true(a == b or not String(a.title).contains(String(b.title)), "%s holds %s" % [a.title, b.title])
	# Every act of every file: no title holds another's (the bots filter by a part of a title).
	var others: Array[String] = []
	var dir := DirAccess.open("res://tests/bot/acts")
	for file: String in dir.get_files():
		if file.ends_with("_acts.gd") and file != "flash_fp_acts.gd":
			for title: String in _titles_in(file):
				others.append(title)
	for act: Dictionary in acts:
		for other: String in others:
			assert_false(other.contains(String(act.title)) or String(act.title).contains(other),
					"'%s' and '%s' do not hold each other" % [act.title, other])


## The titles written in an acts file (a `title = "..."` per act), read from its source.
func _titles_in(file: String) -> Array[String]:
	var out: Array[String] = []
	var regex := RegEx.new()
	regex.compile("title = \"([^\"]+)\"")
	for found in regex.search_all(FileAccess.get_file_as_string("res://tests/bot/acts/".path_join(file))):
		out.append(found.get_string(1))
	return out


func test_every_setting_list_starts_with_todays_values() -> void:
	for settings: Array[Dictionary] in [FlashActs.JAB_SETTINGS, FlashActs.FLURRY_SETTINGS, FlashActs.HOLD_SETTINGS,
			FlashActs.FINISHER_SETTINGS]:
		assert_eq(settings[0].share, TuningData.new().hit_flash_fp_max_share, "the first pass has the cap's default")
		assert_eq(settings[0].mult, TuningData.new().hit_flash_finisher_radius_mult, "and the multiple's")
