extends GutTest
## The player's KO seen from outside the body (Game-boy, 2026-10-25; M2 phase 3 round 2,
## gap-02): the player is animated through the knockdown and the get-up (no ragdoll), and
## from the eyes the lens lay 7 cm over the floor behind the own belly (41% of the view),
## then rose through the torso on the get-up. Now, from the killing blow, the first-person
## camera eases out of the eyes to a point beside and above the lying body, which shows
## whole, holds there while the player is KO'd and eases back into the eyes through the
## get-up (Tuning "Camera" > "KO view"). Judged through the real FirstPersonCamera in the
## real test room: the view leaves and returns without a pop, the whole body is in frame
## and unclipped while out, nothing is within 0.25 m of the lens, the hide list is as it was
## after the get-up, and a KO while holding ends the hold view into the KO view.

const ROOM := preload("res://game/level/test_room.tscn")
const FPView := preload("res://tests/fp_view.gd")
const FAR := Vector3(30.0, 0.0, -30.0)
const FRAME := 1.0 / 60.0
## The most the lens may move (meters) or turn (degrees) in one tick on its way out or in:
## its whole path is about 2.3 m and 90 degrees, over at least 0.5 s, at the ease's peak
## 1.5 times the average rate (measured: 0.10 m and 3 degrees).
const MAX_STEP_M := 0.15
const MAX_TURN_DEG := 6.0

var room: Node3D
var player: PlayerCharacter
var dummies: Array[TrainingDummy] = []


func before_each() -> void:
	TimeController.clear()
	TimeController.debug_scale = 1.0
	Tuning.apply(TuningData.new())
	Tuning.data.dummy_health = 500.0


func after_each() -> void:
	TimeController.clear()


func after_all() -> void:
	Tuning.apply(TuningData.new())


# --- Harness ------------------------------------------------------------------------


## The test room with dummies at `posts` (player frame: x right, -z ahead); the rest far
## away. No dummy spars.
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
		_post(dummies[i], pos)
	await _ticks(3)


## Put `dummy` at `pos` facing the player, not sparring.
func _post(dummy: TrainingDummy, pos: Vector3) -> void:
	var to_player := player.global_position - pos
	dummy.sparring = false
	dummy.set_post(pos, atan2(-to_player.x, -to_player.z), true)


## Put the player at `pos` facing `yaw_deg` (0 faces -Z, -90 faces +X).
func _place_player(pos: Vector3, yaw_deg: float) -> void:
	player.global_position = pos
	player.look_yaw = deg_to_rad(yaw_deg)
	player.rotation.y = player.look_yaw
	player.sim_velocity = Vector3.ZERO
	await _ticks(2)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_until(condition: Callable, max_ticks: int = 400) -> bool:
	for i in max_ticks:
		if condition.call():
			return true
		await get_tree().physics_frame
	return false


## A first-person camera riding the player as the camera director makes it, updated only by
## the tests' own update_camera() calls (one per tick).
func _camera() -> FirstPersonCamera:
	var cam := FirstPersonCamera.new()
	add_child_autofree(cam)
	cam.set_process(false)
	cam.player = player
	cam.update_camera(FRAME)
	return cam


## The player at 3 health and `jabber` throws its jab: the jab kills.
func _jab_to_kill(jabber: TrainingDummy) -> void:
	player.health = 3.0
	jabber.start_jab()


## Record the camera for `ticks` physics ticks, updating it after each: per tick its
## weight, view (before punch and shake), whether it hides the head layer, the player's state,
## whether the player is in hitstop, and the lens's world position on the floor plane. `each`
## (if valid) runs after each update with the record.
func _record(cam: FirstPersonCamera, ticks: int, each: Callable = Callable()) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for i in ticks:
		await _ticks(1)
		cam.update_camera(FRAME)
		var record := {
			w = cam.ko_view_weight(),
			view = cam.view_transform(),
			hides = not cam.get_cull_mask_value(CombatTypes.VIS_FP_HIDDEN),
			state = player.state,
			hitstop = TimeController.is_in_hitstop(player),
			health = player.health,
		}
		records.append(record)
		if each.is_valid():
			each.call(record)
	return records


## Layers of every mesh of the player's rig, by mesh.
func _layers() -> Dictionary:
	var layers := {}
	for mesh: MeshInstance3D in FPView.meshes_under(player.rig):
		layers[mesh] = mesh.layers
	return layers


## The player's rig meshes the first-person camera normally hides (the head layer).
func _head_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in FPView.meshes_under(player.rig):
		if mesh.layers & CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN):
			meshes.append(mesh)
	return meshes


## Share of the view `view` shows of the head layer's meshes, cast as the camera draws them
## with the head layer lifted (the rig's layers are put back).
func _head_share(view: Transform3D, head: Array[MeshInstance3D]) -> float:
	player.rig.first_person_body = false
	var cells := FPView.hits(room, view, 32)
	player.rig.first_person_body = true
	return FPView.share(cells, func(m: MeshInstance3D) -> bool: return head.has(m))


## Share of the view the player's own body covers, cast as the camera draws it: the head
## layer lifted unless the camera `hides` it.
func _own_share(view: Transform3D, hides: bool) -> float:
	if not hides:
		player.rig.first_person_body = false
	var cells := FPView.hits(room, view, 32)
	player.rig.first_person_body = true
	return FPView.share(cells, func(m: MeshInstance3D) -> bool: return player.rig.is_ancestor_of(m))


## Nearest distance from `point` to any mesh of `rig`, whatever its layer.
func _nearest_any_layer(rig: Node, point: Vector3) -> float:
	var nearest := INF
	for mesh: MeshInstance3D in FPView.meshes_under(rig):
		if mesh.is_visible_in_tree():
			nearest = minf(nearest, FPView.mesh_distance(mesh, point))
	return nearest


## True when the world (walls, crates, the curb) lies between `from` and `to`.
func _world_between(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, CombatTypes.bit(CombatTypes.LAYER_WORLD))
	return not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Degrees between two views' looks.
func _turn_deg(a: Transform3D, b: Transform3D) -> float:
	return rad_to_deg(a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion()))


## The view while out, the player lying, KO'd, and the eased weight all the way out: wait
## for it. Returns false if it never gets there.
func _wait_out(cam: FirstPersonCamera, max_ticks: int = 300) -> bool:
	for i in max_ticks:
		await _ticks(1)
		cam.update_camera(FRAME)
		if cam.ko_view_weight() >= 1.0 and player.is_ko():
			return true
	return false


# --- The view leaves and returns ---------------------------------------------------------


func test_the_lens_leaves_the_eyes_for_the_lying_body_and_returns_without_a_pop() -> void:
	await _setup([Vector3(0.0, 0.0, -0.95)])
	var data := Tuning.data
	var cam := _camera()
	await _ticks(5)
	cam.update_camera(FRAME)
	assert_eq(cam.ko_view_weight(), 0.0, "standing, the lens is in the eyes")
	assert_false(cam.get_cull_mask_value(CombatTypes.VIS_FP_HIDDEN), "standing, the head layer is hidden from the lens")
	var layers_before := _layers()
	var head := _head_meshes()
	assert_gt(head.size(), 6, "the player has head-layer meshes to hide")
	# Judged every tick the view is out: the head layer's share of the view where it is lifted
	# or hidden again (a pop), and the own body's share (all of it, as drawn).
	var stats := {pops = [], own_worst = 0.0, lifted_at = [], previous_hides = true}
	var each := func(r: Dictionary) -> void:
		var view: Transform3D = r.view
		if r.w > 0.0:
			stats.own_worst = maxf(stats.own_worst, _own_share(view, r.hides))
		# The tick the head layer is lifted (and the one it is hidden again): nothing of it
		# shows then, so the change pops nothing into or out of the view.
		if r.hides != stats.previous_hides:
			stats.pops.append(_head_share(view, head))
			stats.lifted_at.append(r.w)
		stats.previous_hides = r.hides
	_jab_to_kill(dummies[0])
	# Through the KO and the get-up: 2.5 s down, the get-up (0.5 s), the ease back in and a
	# second of standing.
	var ticks := roundi((data.player_revive_s + 3.0) * 60.0)
	var records := await _record(cam, ticks, each)
	var pops: Array = stats.pops
	var own_worst: float = stats.own_worst
	assert_eq(player.state, CombatTypes.ActorState.FREE, "the player is back on his feet")
	# The weight goes out once, holds while KO'd, and comes back once.
	var first_full := -1
	var last_full := -1
	for i in records.size():
		if records[i].w >= 1.0:
			if first_full < 0:
				first_full = i
			last_full = i
	assert_gte(first_full, 0, "the view gets all the way out")
	for i in range(1, first_full + 1):
		assert_gte(records[i].w, records[i - 1].w - 1e-6, "tick %d: the view only eases out on the way out" % i)
	for i in range(first_full, last_full + 1):
		assert_true(records[i].state == CombatTypes.ActorState.KO or records[i].state == CombatTypes.ActorState.LAUNCHED \
				or records[i].health <= 0.0, "tick %d: held out while the player is down" % i)
	for i in range(last_full + 1, records.size()):
		assert_lte(records[i].w, records[i - 1].w + 1e-6, "tick %d: the view only eases in on the way back" % i)
	assert_eq(records[records.size() - 1].w, 0.0, "back in the eyes")
	# It starts leaving at the killing blow (health 0), before the body has even landed, and is
	# all the way out by the time the body lies.
	var dead_at := -1
	for i in records.size():
		if records[i].health <= 0.0:
			dead_at = i
			break
	assert_gte(dead_at, 0, "the jab kills")
	assert_lte(records[maxi(dead_at - 1, 0)].w, 0.0, "the view is in the eyes until the blow")
	assert_gt(records[dead_at + 12].w, 0.0, "the view has begun to leave within 12 ticks of the blow")
	# No pop: the lens and look never move more than the ease's own pace, both ways.
	var worst_step := 0.0
	var worst_turn := 0.0
	for i in range(1, records.size()):
		var a: Transform3D = records[i - 1].view
		var b: Transform3D = records[i].view
		worst_step = maxf(worst_step, a.origin.distance_to(b.origin))
		worst_turn = maxf(worst_turn, _turn_deg(a, b))
	gut.p("KO view, worst tick: %.3f m, %.2f degrees; own body at most %.0f%% of the view; head layer popping %s at weights %s" % [
			worst_step, worst_turn, own_worst * 100.0, pops, stats.lifted_at])
	assert_lte(worst_step, MAX_STEP_M, "the lens moves at most %.2f m a tick through the KO (%.3f)" % [MAX_STEP_M, worst_step])
	assert_lte(worst_turn, MAX_TURN_DEG, "the look turns at most %.0f degrees a tick through the KO (%.2f)" % [MAX_TURN_DEG, worst_turn])
	# The head layer is hidden from the lens while it is in the eyes, lifted once for the whole
	# time the view is out (as soon as the lens is clear of the head), and hidden again the tick
	# the lens is back: exactly two changes.
	var changes := 0
	for i in records.size():
		if records[i].w <= 0.0:
			assert_true(records[i].hides, "tick %d: in the eyes, the head layer is hidden" % i)
		if i > 0 and records[i].hides != records[i - 1].hides:
			changes += 1
			if records[i].hides:
				assert_eq(records[i].w, 0.0, "tick %d: the head layer is hidden again exactly when the lens is back" % i)
	assert_eq(changes, 2, "the head layer is lifted once and hidden once")
	assert_false(records[last_full].hides, "while the view is out, the whole body shows")
	assert_eq(pops.size(), 2, "both changes were judged")
	for share: float in pops:
		assert_lte(share, 0.02, "lifting or hiding the head layer pops no head, neck or shoulder into view (%.1f%%)" % (share * 100.0))
	# The player's own body never fills the view (a third at most; it covered 41% from the
	# floor and 77% on the way up).
	assert_lte(own_worst, 1.0 / 3.0, "the own body covers at most a third of the view (%.0f%%)" % (own_worst * 100.0))
	# After the get-up the hide list is what it was, and the view is the eyes' own.
	var layers_after := _layers()
	for mesh: MeshInstance3D in layers_before:
		assert_eq(layers_after[mesh], layers_before[mesh], "%s keeps its render layers" % mesh.name)
	assert_false(cam.get_cull_mask_value(CombatTypes.VIS_FP_HIDDEN), "the lens hides the head layer again")
	var fresh := _camera()
	fresh.snap()
	fresh.update_camera(FRAME)
	assert_almost_eq(cam.view_transform().origin, fresh.view_transform().origin, Vector3.ONE * 0.002, "the lens is back on the eyes")
	assert_lt(_turn_deg(cam.view_transform(), fresh.view_transform()), 0.1, "and looks where the player looks")


func test_the_view_out_of_the_body_shows_the_whole_body_clear_of_everything() -> void:
	# From the front (face up), from behind (face down) and with a building front close at the
	# player's side (the lens takes the side with room): the lens beside the lying body, the
	# whole body in frame with room to spare, no wall between the lens and the body, and
	# nothing within 0.25 m of the lens (the own body, the dummies, the world).
	var data := Tuning.data
	for scenario: String in ["front", "behind", "building"]:
		await _setup([Vector3(0.0, 0.0, -0.95 if scenario != "behind" else 0.95)])
		var jabber := dummies[0]
		if scenario == "building":
			# At z = -6.1 facing +X, the building fronts (z = -7) 0.9 m to one side: the lens
			# on that side would sit inside them.
			await _place_player(Vector3(0.0, 0.0, -6.1), -90.0)
			_post(jabber, player.global_position + Vector3(-0.95, 0.0, 0.0))
			await _ticks(10)
		var cam := _camera()
		await _ticks(5)
		_jab_to_kill(jabber)
		assert_true(await _wait_until(func() -> bool: return player.is_ko(), 150), "%s: KO'd" % scenario)
		assert_true(await _wait_out(cam), "%s: the view gets all the way out" % scenario)
		var view := cam.view_transform()
		var root := player.global_position
		var flat := Vector3(view.origin.x - root.x, 0.0, view.origin.z - root.z)
		var body := player.rig.global_basis
		assert_lte(absf(flat.normalized().dot(body * Vector3.FORWARD)), 0.05, "%s: the lens sits across the body, not along it" % scenario)
		var forward := view.basis * Vector3.FORWARD
		forward.y = 0.0
		assert_gt(forward.normalized().dot(-flat.normalized()), 0.99, "%s: looking at the body" % scenario)
		assert_almost_eq(rad_to_deg(view.basis.get_euler().x), -data.ko_view_pitch_deg, 0.2, "%s: looking down by ko_view_pitch_deg" % scenario)
		assert_gt(view.origin.y, 0.5, "%s: above the floor" % scenario)
		var outside := FPView.outside_view(player.rig, view, 0.95)
		assert_eq(outside.size(), 0, "%s: the whole body is in frame, with a margin (outside: %s)" % [scenario, outside.map(func(m: MeshInstance3D) -> StringName: return m.name)])
		assert_false(_world_between(player.rig.get_point_position(&"Hips"), view.origin), "%s: no wall between the lens and the body" % scenario)
		if scenario == "building":
			assert_gt(view.origin.z, root.z, "%s: the lens took the side with the street, not the building" % scenario)
		else:
			assert_almost_eq(flat.length(), data.ko_view_distance_m, 0.02, "%s: ko_view_distance_m out" % scenario)
			assert_almost_eq(view.origin.y, data.ko_view_height_m, 0.02, "%s: ko_view_height_m up" % scenario)
		assert_gte(_nearest_any_layer(player.rig, view.origin), 0.25, "%s: nothing of the own body within 0.25 m of the lens" % scenario)
		for dummy: TrainingDummy in dummies:
			assert_gte(_nearest_any_layer(dummy.rig, view.origin), 0.25, "%s: %s stays 0.25 m or more from the lens" % [scenario, dummy.name])
		assert_lte(_own_share(view, false), 1.0 / 3.0, "%s: the own body covers at most a third of the view" % scenario)


func test_the_ko_view_is_held_still_through_the_killing_blows_hitstop() -> void:
	# The view's progress runs in the player's sim time, like its get-up: the killing blow's
	# hitstop holds the lens where it is.
	await _setup([Vector3(0.0, 0.0, -0.95)])
	var cam := _camera()
	await _ticks(5)
	_jab_to_kill(dummies[0])
	var frozen := 0
	var records := await _record(cam, 150)
	for i in range(1, records.size()):
		if records[i].hitstop and records[i - 1].hitstop:
			frozen += 1
			assert_eq(records[i].w, records[i - 1].w, "tick %d: no progress in hitstop" % i)
	assert_gt(frozen, 0, "the killing blow has a hitstop")
	assert_gt(records[records.size() - 1].w, 0.0, "and the view goes on after it")


func test_the_ko_view_follows_its_tunables_live() -> void:
	await _setup([Vector3(0.0, 0.0, -0.95)])
	var cam := _camera()
	await _ticks(5)
	_jab_to_kill(dummies[0])
	assert_true(await _wait_until(func() -> bool: return player.is_ko(), 150), "KO'd")
	assert_true(await _wait_out(cam), "out")
	Tuning.set_value(&"ko_view_height_m", 2.4)
	Tuning.set_value(&"ko_view_distance_m", 2.6)
	Tuning.set_value(&"ko_view_pitch_deg", 50.0)
	for i in 30:
		cam.update_camera(FRAME)
	var view := cam.view_transform()
	assert_almost_eq(view.origin.y, 2.4, 0.02, "the lens rises to the new height")
	assert_almost_eq(rad_to_deg(view.basis.get_euler().x), -50.0, 0.2, "and pitches to the new angle")
	assert_almost_eq(Vector2(view.origin.x - player.global_position.x, view.origin.z - player.global_position.z).length(), 2.6, 0.02, "and sits at the new distance")


func test_without_an_ease_the_view_cuts_both_ways() -> void:
	# ko_view_out_s and ko_view_in_s at 0 cut straight to the view and back (no division by
	# zero, no NaN).
	Tuning.data.ko_view_out_s = 0.0
	Tuning.data.ko_view_in_s = 0.0
	await _setup([Vector3(0.0, 0.0, -0.95)])
	var cam := _camera()
	await _ticks(5)
	_jab_to_kill(dummies[0])
	var records := await _record(cam, 400)
	var out_seen := false
	for r: Dictionary in records:
		assert_true((r.view as Transform3D).origin.is_finite(), "the lens stays finite")
		assert_true(r.w == 0.0 or r.w == 1.0, "the weight is 0 or 1 (%f)" % r.w)
		out_seen = out_seen or r.w == 1.0
	assert_true(out_seen, "the view still goes out")
	assert_eq(records[records.size() - 1].w, 0.0, "and back in")


# --- A KO while holding -------------------------------------------------------------------


func test_a_ko_while_holding_ends_the_hold_view_into_the_ko_view() -> void:
	# A second dummy jabs the player while he holds the first. The hit kills: the hold breaks,
	# the victim staggers away, and the hold view (pitched down, raised and pulled back) eases
	# out while the lens eases out of the eyes: one path with no pop, the released victim
	# never within 0.25 m of the lens, and the whole body in frame at the end.
	await _setup([Vector3(0.0, 0.0, -1.1), Vector3(0.85, 0.0, -0.2)])
	var victim := dummies[0]
	var jabber := dummies[1]
	player.input.push_press(&"GRAB", 2)
	assert_true(await _wait_until(func() -> bool: return player.holding_enemy() != null and player.state == CombatTypes.ActorState.GRABBING, 30), "grabbed")
	assert_true(await _wait_until(func() -> bool: return player.get_hold_view_weight() >= 1.0, 60), "the hold view is all the way in")
	var cam := _camera()
	await _ticks(20)
	cam.update_camera(FRAME)
	assert_eq(cam.ko_view_weight(), 0.0, "holding, the lens is in the eyes (the hold view)")
	var stats := {victim_near = INF, jabber_near = INF, own_worst = 0.0}
	var each := func(r: Dictionary) -> void:
		var origin: Vector3 = (r.view as Transform3D).origin
		# From the blow's contact on (the jab's fist touches the face through its hitstop and the
		# frame after, and the victim sits at the hold's 0.25 m before it, as always): the
		# weight is past half a percent once the contact pose is over.
		if r.w >= 0.005 and not r.hitstop:
			stats.victim_near = minf(stats.victim_near, _nearest_any_layer(victim.rig, origin))
			stats.jabber_near = minf(stats.jabber_near, _nearest_any_layer(jabber.rig, origin))
		if r.w > 0.0:
			stats.own_worst = maxf(stats.own_worst, _own_share(r.view, r.hides))
	_jab_to_kill(jabber)
	var records := await _record(cam, 150, each)
	var victim_near: float = stats.victim_near
	var jabber_near: float = stats.jabber_near
	var own_worst: float = stats.own_worst
	assert_null(player.holding_enemy(), "the hold is broken")
	assert_true(player.health <= 0.0, "the jab killed")
	var first_full := -1
	for i in records.size():
		if records[i].w >= 1.0:
			first_full = i
			break
	assert_gte(first_full, 0, "the view gets all the way out")
	for i in range(1, first_full + 1):
		assert_gte(records[i].w, records[i - 1].w - 1e-6, "tick %d: only easing out" % i)
	var worst_step := 0.0
	var worst_turn := 0.0
	for i in range(1, records.size()):
		var a: Transform3D = records[i - 1].view
		var b: Transform3D = records[i].view
		worst_step = maxf(worst_step, a.origin.distance_to(b.origin))
		worst_turn = maxf(worst_turn, _turn_deg(a, b))
	gut.p("KO while holding: worst tick %.3f m, %.2f degrees; victim nearest %.3f m, jabber nearest %.3f m, own body at most %.0f%%" % [
			worst_step, worst_turn, victim_near, jabber_near, own_worst * 100.0])
	assert_lte(worst_step, MAX_STEP_M, "the lens moves at most %.2f m a tick (%.3f)" % [MAX_STEP_M, worst_step])
	assert_lte(worst_turn, MAX_TURN_DEG, "the look turns at most %.0f degrees a tick (%.2f)" % [MAX_TURN_DEG, worst_turn])
	assert_gte(victim_near, 0.25, "after the blow the released victim stays 0.25 m or more from the lens (nearest %.3f m)" % victim_near)
	assert_gte(jabber_near, 0.25, "after the blow the jabber stays 0.25 m or more from the lens (nearest %.3f m)" % jabber_near)
	assert_lte(own_worst, 1.0 / 3.0, "the own body covers at most a third of the view (%.0f%%)" % (own_worst * 100.0))
	assert_true(await _wait_out(cam), "and holds out while KO'd")
	var view := cam.view_transform()
	assert_eq(FPView.outside_view(player.rig, view, 0.95).size(), 0, "the whole body is in frame")
	assert_gte(_nearest_any_layer(victim.rig, view.origin), 0.25, "the victim is clear of the lens at the end")
	assert_gte(_nearest_any_layer(jabber.rig, view.origin), 0.25, "the jabber is clear of the lens at the end")
	assert_gte(_nearest_any_layer(player.rig, view.origin), 0.25, "the own body is clear of the lens at the end")
	# The lens takes the side away from the jabber, who stands at the player's right.
	var to_lens := view.origin - player.global_position
	var to_jabber := jabber.global_position - player.global_position
	assert_lt(to_lens.dot(to_jabber), 0.0, "the lens sits on the side away from the second fighter")


# --- The other cameras ---------------------------------------------------------------------


func test_a_ko_leaves_the_side_view_and_free_fly_alone_and_f2_still_cycles() -> void:
	await _setup([Vector3(0.0, 0.0, -0.95)])
	var director := CameraDirector.new()
	add_child_autofree(director)
	await _ticks(3)
	assert_eq(director.mode, CameraDirector.MODE_FIRST_PERSON, "starts in first person")
	director.set_mode(CameraDirector.MODE_SIDE_VIEW)
	await _ticks(3)
	var street_view := director.side_view_camera.global_transform
	_jab_to_kill(dummies[0])
	assert_true(await _wait_until(func() -> bool: return player.is_ko(), 150), "KO'd")
	await _ticks(60)
	var side := director.side_view_camera
	assert_true(side.get_cull_mask_value(CombatTypes.VIS_FP_HIDDEN), "side view still draws the whole player")
	assert_almost_eq(side.global_position.y, street_view.origin.y, 0.1, "the side view keeps its height")
	assert_almost_eq(side.global_position.z, street_view.origin.z, 0.1, "and its distance")
	assert_gt(director.first_person_camera.ko_view_weight(), 0.0, "the first-person camera is still out of the body behind it")
	director.cycle()
	await _ticks(2)
	assert_eq(director.mode, CameraDirector.MODE_FREE_FLY, "F2 goes on to free fly")
	assert_almost_eq(director.free_fly_camera.global_position, side.global_position, Vector3.ONE * 0.01, "free fly starts where side view was")
	director.cycle()
	await _ticks(2)
	assert_eq(director.mode, CameraDirector.MODE_FIRST_PERSON, "and back to first person")
	assert_gt(director.first_person_camera.ko_view_weight(), 0.0, "the first-person view is still the KO view")
