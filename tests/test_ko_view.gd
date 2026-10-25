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
## after the get-up, and a KO while holding ends the hold view into the KO view. Round 3
## (r3look-01 and 02): the return goes into the eyes the body has whatever the look did while
## down, hides the head layer again before the lens dives into it, and the lens finds room in
## a corner and between fighters (along the body or over it), never inside the world.

const ROOM := preload("res://game/level/test_room.tscn")
const FPView := preload("res://tests/fp_view.gd")
const FAR := Vector3(30.0, 0.0, -30.0)
const FRAME := 1.0 / 60.0
## The most the lens may move (meters) or turn (degrees) in one tick on its way out or in:
## its whole path is about 2.3 m and up to 120 degrees (over the body: 85 down and across),
## over at least 0.5 s, at the ease's peak 1.5 times the average rate and the look's lead on
## the way back (measured: 0.10 m and 7 degrees).
const MAX_STEP_M := 0.15
const MAX_TURN_DEG := 8.0
## Where the end wall and the building front meet (the street's far corner, x = 20 and z = -7).
const CORNER := Vector3(19.3, 0.0, -6.3)

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


## True when the world (walls, crates, the curb) or a fighter on his feet lies within `radius`
## of `point`: the lens is in them, or too near. A ball query, as the camera tests its own.
func _geometry_within(point: Vector3, radius: float) -> bool:
	var ball := SphereShape3D.new()
	ball.radius = maxf(radius, 0.001)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = CombatTypes.bit(CombatTypes.LAYER_WORLD) | CombatTypes.bit(CombatTypes.LAYER_ENEMY_BODY)
	return not player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## Record `ticks` ticks of the camera (_record()) and judge each one the way the reviewers do:
## the own body's share of the view (all of it as drawn), the nearest mesh of anyone's body to
## the lens while the head layer is lifted (the drawn head, neck and chest the lens must not
## dive into) and while the lens is out (0.02 and up), the share of the view the head layer
## takes where it is lifted or hidden (a pop: `lifts` and `hides`, one share per change), the
## lens's worst step and turn in a tick, and the lens inside the world or a fighter (a ball of
## 0 m, so any tick). `extra` (if valid) runs after each tick with the record. Returns
## {records, own_worst, own_ticks (ticks over a third), near_lifted, near_other, lifts, hides,
## step, turn, inside}.
func _judge(cam: FirstPersonCamera, ticks: int, extra: Callable = Callable()) -> Dictionary:
	var head := _head_meshes()
	var stats := {own_worst = 0.0, own_ticks = 0, near_lifted = INF, near_other = INF, lifts = [], hides = [],
			step = 0.0, turn = 0.0, inside = 0, last = null, previous_hides = not cam.get_cull_mask_value(CombatTypes.VIS_FP_HIDDEN)}
	var each := func(r: Dictionary) -> void:
		var view: Transform3D = r.view
		if r.w > 0.0:
			var own := _own_share(view, r.hides)
			stats.own_worst = maxf(stats.own_worst, own)
			if own > 1.0 / 3.0:
				stats.own_ticks += 1
			if not r.hides:
				stats.near_lifted = minf(stats.near_lifted, _nearest_any_layer(player.rig, view.origin))
			if r.w >= 0.02 and not r.hitstop:
				for dummy: TrainingDummy in dummies:
					stats.near_other = minf(stats.near_other, _nearest_any_layer(dummy.rig, view.origin))
			if _geometry_within(view.origin, 0.0):
				stats.inside += 1
		if r.hides != stats.previous_hides:
			(stats.hides if r.hides else stats.lifts).append(_head_share(view, head))
		stats.previous_hides = r.hides
		if stats.last != null:
			stats.step = maxf(stats.step, (stats.last as Transform3D).origin.distance_to(view.origin))
			stats.turn = maxf(stats.turn, _turn_deg(stats.last, view))
		stats.last = view
		if extra.is_valid():
			extra.call(r)
	stats["records"] = await _record(cam, ticks, each)
	return stats


## What `_judge()` found must hold for any KO: the own body at most a third of the view, nothing
## drawn within 0.25 m of the lens while the head layer is lifted (and nobody else's near it
## while out), the head layer lifted once and hidden once, nothing popping at the hide (the
## head leaves the view before the lens is near it) and at most a head's edge at the lift (a
## body falling face down shows 6% of the view when the lens clears the head, 0% face up), the
## lens inside nothing and its pace the ease's.
func _assert_return_judged(stats: Dictionary, label: String) -> void:
	assert_eq(stats.own_ticks, 0, "%s: the own body never covers over a third of the view (%.0f%% at most)" % [label, stats.own_worst * 100.0])
	assert_gte(stats.near_lifted, 0.25, "%s: with the head layer lifted nothing of the body comes within 0.25 m of the lens (%.3f m)" % [label, stats.near_lifted])
	assert_gte(stats.near_other, 0.25, "%s: no fighter comes within 0.25 m of the lens while it is out (%.3f m)" % [label, stats.near_other])
	assert_eq(stats.lifts.size(), 1, "%s: the head layer is lifted once (%s)" % [label, stats.lifts])
	assert_eq(stats.hides.size(), 1, "%s: and hidden once (%s)" % [label, stats.hides])
	for share: float in stats.hides:
		assert_lte(share, 0.02, "%s: hiding the head layer again pops no head, neck or shoulder out of view (%.1f%%)" % [label, share * 100.0])
	for share: float in stats.lifts:
		assert_lte(share, 0.08, "%s: lifting the head layer pops at most a head's edge into view (%.1f%%)" % [label, share * 100.0])
	assert_eq(stats.inside, 0, "%s: the lens is never inside the world or a fighter" % label)
	assert_lte(stats.step, MAX_STEP_M, "%s: the lens moves at most %.2f m a tick (%.3f)" % [label, MAX_STEP_M, stats.step])
	assert_lte(stats.turn, MAX_TURN_DEG, "%s: the look turns at most %.0f degrees a tick (%.2f)" % [label, MAX_TURN_DEG, stats.turn])


## The view as it is held out, the player KO'd: the whole body in frame with a margin (unlike a
## body squeezed in), the lens clear of the world and every fighter by ko_view_clearance_m and
## of the own body by 0.25 m, no wall between the lens and the body, and the own body at most a
## third of the view.
func _check_held(view: Transform3D, label: String) -> void:
	var outside := FPView.outside_view(player.rig, view, 0.95)
	assert_eq(outside.size(), 0, "%s: the whole body is in frame, with a margin (outside: %s)" % [label, outside.map(func(m: MeshInstance3D) -> StringName: return m.name)])
	assert_false(_geometry_within(view.origin, Tuning.data.ko_view_clearance_m), "%s: the lens is clear of every wall and fighter by ko_view_clearance_m" % label)
	assert_false(_world_between(player.rig.get_point_position(&"Hips"), view.origin), "%s: no wall between the lens and the body" % label)
	assert_gte(_nearest_any_layer(player.rig, view.origin), 0.25, "%s: nothing of the own body within 0.25 m of the lens" % label)
	for dummy: TrainingDummy in dummies:
		assert_gte(_nearest_any_layer(dummy.rig, view.origin), 0.25, "%s: %s stays 0.25 m or more from the lens" % [label, dummy.name])
	assert_lte(_own_share(view, false), 1.0 / 3.0, "%s: the own body covers at most a third of the view" % label)


## The whole KO from the killing blow (the jab is thrown already): the camera updated every
## tick through the KO, the get-up and 3 s of standing, judged (_judge()) with the held view
## checked (_check_held()) 30 ticks after the lens is all the way out. `extra` (if valid)
## runs after each tick with the record. Returns _judge()'s stats plus `held` (the first held
## view, a Transform3D, or null).
func _judge_ko(cam: FirstPersonCamera, label: String, extra: Callable = Callable()) -> Dictionary:
	var held := {ticks = 0, view = null}
	var each := func(r: Dictionary) -> void:
		if r.w >= 1.0 and player.is_ko():
			held.ticks += 1
			if held.ticks == 30:
				held.view = r.view
				_check_held(r.view, label)
		if extra.is_valid():
			extra.call(r)
	var stats := await _judge(cam, roundi((Tuning.data.player_revive_s + 3.0) * 60.0), each)
	assert_not_null(held.view, "%s: the view got all the way out and held" % label)
	stats["held"] = held.view
	return stats


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
	# time the view is out (as soon as the lens is clear of the head), and hidden again on the
	# way back as soon as the lens comes within ko_view_clearance_m of it (r3look-01: hidden only
	# at the eyes, the lens dived through the drawn head and chest): exactly two changes.
	var changes := 0
	for i in records.size():
		if records[i].w <= 0.0:
			assert_true(records[i].hides, "tick %d: in the eyes, the head layer is hidden" % i)
		if i > 0 and records[i].hides != records[i - 1].hides:
			changes += 1
			if records[i].hides:
				assert_gt(records[i].w, 0.0, "tick %d: the head layer is hidden again before the lens is back" % i)
				assert_lt(records[i].w, 0.5, "tick %d: but not before the lens is on its way in" % i)
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


func test_with_a_wall_each_side_the_lens_comes_in_but_not_past_it() -> void:
	# A building front 0.9 m to one side and a fighter 0.9 m to the other: neither side leaves
	# the room the whole body needs, so the lens takes another pose instead of one squeezed
	# against a wall (r3look-02: reach 0.4 put the lens inside the wall). Never past the first
	# thing its line meets, in any pose.
	await _setup([Vector3(0.0, 0.0, -0.95), Vector3(0.9, 0.0, 0.0)])
	await _place_player(Vector3(0.0, 0.0, -6.1), -90.0)
	_post(dummies[0], player.global_position + Vector3(-0.95, 0.0, 0.0))
	# Facing +X, the player's right is +Z: the other fighter stands there, the building at -Z.
	_post(dummies[1], player.global_position + Vector3(0.0, 0.0, 0.9))
	await _ticks(10)
	var cam := _camera()
	await _ticks(5)
	_jab_to_kill(dummies[0])
	var stats := await _judge_ko(cam, "wall and fighter")
	_assert_return_judged(stats, "wall and fighter")
	var view: Transform3D = stats.held
	var flat := Vector2(view.origin.x - player.global_position.x, view.origin.z - player.global_position.z)
	assert_lt(flat.length(), Tuning.data.ko_view_distance_m * Tuning.data.ko_view_min_reach, "the lens did not take either side (%.2f m out)" % flat.length())


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


# --- The return into the eyes the body has (r3look-01) -------------------------------------


func test_the_return_goes_into_the_eyes_the_body_has_whatever_the_look_did_while_down() -> void:
	# A mouse moved while the player lies KO'd turned the look but not the body (a KO'd body is
	# not steered), so the lens came back to eyes the body did not have, through its own face
	# and chest (up to 75% of the view, then a 66% pop), and the body snapped round at the
	# get-up. The look is written directly (scripted input skips PlayerCharacter._process()),
	# from 40 ticks into the KO, over a second: no turn, +-45 and +120 degrees, and a pitch.
	for turn: Vector2 in [Vector2(0.0, 0.0), Vector2(45.0, 0.0), Vector2(-45.0, 0.0), Vector2(120.0, 0.0), Vector2(-30.0, -20.0)]:
		var label := "look turned %d degrees and pitched %d while down" % [turn.x, turn.y]
		await _setup([Vector3(0.0, 0.0, -0.95)])
		var cam := _camera()
		await _ticks(5)
		var yaw_before := player.rotation.y
		_jab_to_kill(dummies[0])
		var seen := {ko_ticks = 0, yaw_from = NAN, pitch_from = NAN, yaw_at_getup = NAN}
		var extra := func(r: Dictionary) -> void:
			if r.state == CombatTypes.ActorState.KO:
				seen.ko_ticks += 1
			if seen.ko_ticks == 40 and is_nan(seen.yaw_from):
				seen.yaw_from = player.look_yaw
				seen.pitch_from = player.look_pitch
			if seen.ko_ticks > 40 and r.state == CombatTypes.ActorState.KO and not is_nan(seen.yaw_from):
				var k := minf(float(seen.ko_ticks - 40) / 60.0, 1.0)
				player.look_yaw = wrapf(seen.yaw_from + deg_to_rad(turn.x) * k, -PI, PI)
				player.look_pitch = seen.pitch_from + deg_to_rad(turn.y) * k
			if r.state == CombatTypes.ActorState.GETUP and is_nan(seen.yaw_at_getup):
				seen.yaw_at_getup = player.rotation.y
		var stats := await _judge_ko(cam, label, extra)
		assert_eq(player.state, CombatTypes.ActorState.FREE, "%s: back on his feet" % label)
		assert_almost_eq(player.rotation.y, yaw_before, 0.001, "%s: the body is as it faced at the killing blow (no snap round at the get-up)" % label)
		assert_almost_eq(player.rotation.y, seen.yaw_at_getup, 0.001, "%s: and did not turn at FREE" % label)
		assert_almost_eq(player.look_yaw, player.rotation.y, 0.001, "%s: the look is on the body" % label)
		_assert_return_judged(stats, label)
		var fresh := _camera()
		fresh.snap()
		fresh.update_camera(FRAME)
		assert_almost_eq(cam.view_transform().origin, fresh.view_transform().origin, Vector3.ONE * 0.002, "%s: the lens is back on the eyes" % label)
		assert_lt(_turn_deg(cam.view_transform(), fresh.view_transform()), 0.1, "%s: looking where the body looks" % label)


func test_a_revive_before_the_lens_is_out_comes_back_without_a_jump() -> void:
	# Revived 0.5 s into the KO with a slow ease out (2 s), the lens is still near the eyes when
	# the return starts: the look must not jump from where it is to the lead the return
	# otherwise has (it jumped 13 degrees at weight 0.3).
	Tuning.data.player_revive_s = 0.5
	Tuning.data.ko_view_out_s = 2.0
	await _setup([Vector3(0.0, 0.0, -0.95)])
	var cam := _camera()
	await _ticks(5)
	_jab_to_kill(dummies[0])
	var turn_back := {first_w = -1.0}
	var extra := func(r: Dictionary) -> void:
		if player.health > 0.0 and turn_back.first_w < 0.0 and r.w > 0.0:
			turn_back.first_w = r.w
	var stats := await _judge(cam, 400, extra)
	assert_lt(turn_back.first_w, 0.5, "the lens was still near the eyes at the revive (%.2f)" % turn_back.first_w)
	assert_eq(stats.records[stats.records.size() - 1].w, 0.0, "back in the eyes")
	assert_lte(stats.step, MAX_STEP_M, "the lens moves at most %.2f m a tick (%.3f)" % [MAX_STEP_M, stats.step])
	assert_lte(stats.turn, MAX_TURN_DEG, "the look turns at most %.0f degrees a tick (%.2f)" % [MAX_TURN_DEG, stats.turn])
	assert_eq(stats.own_ticks, 0, "the own body never covers over a third of the view (%.0f%%)" % (stats.own_worst * 100.0))


func test_mouse_look_is_dropped_from_the_killing_blow_through_the_get_up() -> void:
	# PlayerCharacter._process(): from health 0 through the KO and the get-up after it the
	# look does not turn (the body does not follow it, and the view comes back into the body's
	# eyes), and the mouse motion is used up, not kept for later. Free before and after, and
	# in an ordinary knockdown's get-up (a view for those is waiting on Game-boy).
	await _setup([Vector3(0.0, 0.0, -0.95)])
	var turn_with_mouse := func() -> float:
		var before := player.look_yaw
		GameInput.consume_mouse_delta()
		GameInput._mouse_delta = Vector2(400.0, 0.0)
		player.input.scripted = false
		player._process(FRAME)
		player.input.scripted = true
		assert_eq(GameInput.consume_mouse_delta(), Vector2.ZERO, "the mouse motion is used up")
		return absf(wrapf(player.look_yaw - before, -PI, PI))
	assert_gt(turn_with_mouse.call(), 0.1, "standing, the mouse turns the look")
	player._enter_state(CombatTypes.ActorState.GETUP, 30)
	assert_gt(turn_with_mouse.call(), 0.1, "in an ordinary knockdown's get-up the mouse still turns the look")
	player._enter_state(CombatTypes.ActorState.FREE)
	_jab_to_kill(dummies[0])
	var dying := {turned = INF}
	assert_true(await _wait_until(func() -> bool:
		if player.health <= 0.0 and dying.turned == INF:
			dying.turned = turn_with_mouse.call()
		return player.is_ko(), 150), "KO'd")
	assert_eq(dying.turned, 0.0, "from the killing blow on the mouse does not turn the look")
	assert_eq(turn_with_mouse.call(), 0.0, "KO'd, the mouse does not turn the look")
	player.look_yaw = 1.0
	player._revive()
	assert_eq(player.look_yaw, player.rotation.y, "the revive puts the look on the body")
	assert_eq(player.state, CombatTypes.ActorState.GETUP, "the revive starts the get-up")
	assert_eq(turn_with_mouse.call(), 0.0, "in the get-up after a KO the mouse does not turn the look")
	assert_true(await _wait_until(func() -> bool: return player.state == CombatTypes.ActorState.FREE, 100), "on his feet")
	assert_gt(turn_with_mouse.call(), 0.1, "free again, the mouse turns the look")


# --- Room in a corner and between fighters (r3look-02) ------------------------------------


func test_in_the_corner_the_lens_takes_the_pose_over_the_body() -> void:
	# The player lies in the corner of the end wall and the building front (x = 20, z = -7),
	# 0.35 m from each, the jabber at his feet: the lens across the body on either side was
	# inside the building (0.13 m in) with the own shirt over 52-68% of the view all through
	# the KO. Now no side has the room and the jabber is in the way along the body, so the lens
	# takes the pose straight over the hips, outside everything.
	await _setup([Vector3(0.0, 0.0, -0.95)])
	await _place_player(CORNER, 135.0)
	_post(dummies[0], player.global_position + player.global_basis * Vector3(0.0, 0.0, -0.95))
	await _ticks(10)
	var cam := _camera()
	await _ticks(5)
	_jab_to_kill(dummies[0])
	var stats := await _judge_ko(cam, "corner")
	assert_gt(player.global_position.x, 19.5, "the body lay in the corner")
	var view: Transform3D = stats.held
	var flat := Vector2(view.origin.x - player.global_position.x, view.origin.z - player.global_position.z)
	assert_lt(flat.length(), 0.05, "the lens is straight over the body (%.2f m off)" % flat.length())
	assert_almost_eq(view.origin.y, Tuning.data.ko_view_steep_height_m, 0.02, "ko_view_steep_height_m up")
	assert_almost_eq(rad_to_deg(view.basis.get_euler().x), -Tuning.data.ko_view_steep_pitch_deg, 0.2, "looking down by ko_view_steep_pitch_deg")
	_assert_return_judged(stats, "corner")


func test_with_a_fighter_each_side_the_lens_finds_room_over_the_body() -> void:
	# Fighters 1.3 m off both sides of the body, one 0.4 m behind where the player stood and
	# one 0.4 m ahead (the reviewers' KO9), the jabber ahead: the lens hovered 0.32 m over
	# one fighter's head with the body clipped at the edge of the view.
	await _setup([Vector3(0.0, 0.0, -0.95), Vector3(1.3, 0.0, 0.4), Vector3(-1.3, 0.0, -0.4)])
	var cam := _camera()
	await _ticks(5)
	_jab_to_kill(dummies[0])
	var stats := await _judge_ko(cam, "fighter each side")
	_assert_return_judged(stats, "fighter each side")


func test_a_side_with_a_wall_too_near_is_passed_over_for_the_other() -> void:
	# Across the body the lens takes the side with the room; a side with under
	# ko_view_min_reach of it is passed over (a lens at reach 0.4 sat 0.68 m out and 0.64 m up:
	# inside any wall nearer than that). With the building front 0.9 m off the player's left,
	# the right is taken, all of ko_view_distance_m out.
	await _setup([Vector3(0.0, 0.0, -0.95)])
	await _place_player(Vector3(0.0, 0.0, -6.1), -90.0)
	_post(dummies[0], player.global_position + Vector3(-0.95, 0.0, 0.0))
	await _ticks(10)
	var cam := _camera()
	await _ticks(5)
	_jab_to_kill(dummies[0])
	var stats := await _judge_ko(cam, "building on the left")
	_assert_return_judged(stats, "building on the left")
	var view: Transform3D = stats.held
	assert_gt(view.origin.z, player.global_position.z, "the lens took the street side")
	assert_almost_eq(Vector2(view.origin.x - player.global_position.x, view.origin.z - player.global_position.z).length(), Tuning.data.ko_view_distance_m, 0.02, "all of ko_view_distance_m out: nothing brought it in")


func test_along_the_body_past_the_feet_when_both_sides_are_blocked_and_the_feet_are_free() -> void:
	# No killing blow needed to choose the pose: at health 0 with fighters 1.0 m off both sides
	# and nobody ahead, the room across the body is under ko_view_min_reach each way and the
	# way past the feet is free: the lens takes that pose, ko_view_distance_m out ahead of him.
	await _setup([Vector3(1.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0)])
	var cam := _camera()
	await _ticks(5)
	cam.update_camera(FRAME)
	player.health = 0.0
	var forward := player.global_basis * Vector3.FORWARD
	var ticks := 0
	while cam.ko_view_weight() < 1.0 and ticks < 200:
		cam.update_camera(FRAME)
		await _ticks(1)
		ticks += 1
	assert_almost_eq(cam.ko_view_weight(), 1.0, 0.0001, "the view got all the way out")
	var view := cam.view_transform()
	var flat := Vector3(view.origin.x - player.global_position.x, 0.0, view.origin.z - player.global_position.z)
	assert_almost_eq(flat.length(), Tuning.data.ko_view_distance_m, 0.02, "ko_view_distance_m out")
	assert_almost_eq(absf(flat.normalized().dot(forward)), 1.0, 0.01, "along the body (the way he faces), not across it")
	assert_almost_eq(view.origin.y, Tuning.data.ko_view_height_m, 0.02, "ko_view_height_m up")
	assert_almost_eq(rad_to_deg(view.basis.get_euler().x), -Tuning.data.ko_view_pitch_deg, 0.2, "looking down by ko_view_pitch_deg")
	assert_false(_geometry_within(view.origin, Tuning.data.ko_view_clearance_m), "the lens is clear of the fighters")
	player.health = player.max_health


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
