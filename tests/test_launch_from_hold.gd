extends GutTest
## A body launched out of the hold (M2 phase 3 review, grab-01 and ragdoll-01): the throw,
## and a knee that KOs the held body. It leaves the hold as a release does
## (CombatActor._leave_hold_under_hips()): from where it is drawn, its origin moved under its
## bent-over hips, unbending around them over the release blend while it flies away. It
## never snaps upright inside the holder: through the hit's hitstop and the flight's first
## frames the first-person lens stays clear of it and, side on, its chest never comes closer
## to the holder's than in the hold. With the ragdoll and without (the animated reactions).
## Bounds, not exact lens positions: the hold view may start easing out within the
## hitstop. Judged through the real view (FirstPersonCamera.view_from_eye()) in the real
## test room, as tests/test_grab_view.gd judges the hold.

const ROOM := preload("res://game/level/test_room.tscn")
const FPView := preload("res://tests/fp_view.gd")
const FAR := Vector3(30.0, 0.0, -30.0)
## Ticks watched after the launch's hitstop: the release blend and the first of the flight.
const AFTER_HITSTOP := 24

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


# --- Harness (as tests/test_grab_view.gd) ---------------------------------------------


## The test room with the player looking level and dummies at `posts` (player frame: x
## right, -z ahead); the rest far away. No dummy spars.
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
	player.look_pitch = 0.0
	dummies.assign(room.get(&"dummies"))
	for i in dummies.size():
		var pos := player.global_position + player.global_basis * posts[i] if i < posts.size() else FAR + Vector3(i * 3.0, 0.0, 0.0)
		var to_player := player.global_position - pos
		dummies[i].sparring = false
		dummies[i].set_post(pos, atan2(-to_player.x, -to_player.z), true)
	await _ticks(3)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_until(condition: Callable, max_ticks: int = 400) -> bool:
	for i in max_ticks:
		if condition.call():
			return true
		await get_tree().physics_frame
	return false


func _holding() -> bool:
	return player.holding_enemy() != null and player.state == CombatTypes.ActorState.GRABBING


## Grab the dummy in front and wait until the hold view is at full weight.
func _grab() -> void:
	player.input.push_press(&"GRAB", 2)
	assert_true(await _wait_until(_holding, 30), "grabbed")
	assert_true(await _wait_until(func() -> bool: return player.get_hold_view_weight() >= 1.0, 60), "the hold view eases all the way in")


# --- What the view and the side show ----------------------------------------------------


## What the real first-person view shows of `victim` this tick: its nearest drawn part to
## the lens (m) and the share of the view it covers (in front of the player's own body).
func _lens(victim: CombatActor) -> Vector2:
	var cam := FirstPersonCamera.view_from_eye(player, player.get_eye_transform().origin)
	var skip := FPView.meshes_under(room).filter(func(m: MeshInstance3D) -> bool:
		return not (player.rig.is_ancestor_of(m) or victim.rig.is_ancestor_of(m)))
	var cells := FPView.hits(room, cam, 32, skip)
	var share := FPView.share(cells, func(m: MeshInstance3D) -> bool: return victim.rig.is_ancestor_of(m))
	return Vector2(FPView.nearest_mesh(victim.rig, cam.origin), share)


## Side on: how far `victim`'s drawn chest is from the holder's, along the floor (m).
func _chest_gap(victim: CombatActor) -> float:
	var gap := victim.rig.get_visual_point_transform(&"ChestPoint").origin - player.rig.get_point_position(&"ChestPoint")
	return Vector2(gap.x, gap.z).length()


## Hold the dummy in front, then press `button` (a knee that KOs it, or the throw) and watch
## from the press through the launch's hitstop and AFTER_HITSTOP ticks more: the nearest the
## victim comes to the lens, the most of the view it covers, the least chest gap side on
## (and the hold's), the most its drawn head moves in a tick around its drawn hips while it
## flies (the landing jolts it), and the state it was launched into (FREE if it was not).
func _launch_out_of_the_hold(button: StringName, ko: bool) -> Dictionary:
	await _setup([Vector3(0, 0, -1.1)])
	var victim := dummies[0]
	await _grab()
	await _ticks(10)
	var held_gap := _chest_gap(victim)
	if ko:
		# The knee (6 damage) KOs it.
		victim.health = 1.0
	player.input.push_press(button, 2)
	var out := {near = INF, share = 0.0, gap = INF, held_gap = held_gap, head_step = 0.0, launched = CombatTypes.ActorState.FREE, hitstop = 0}
	var head := _head_on_hips(victim)
	var after := -1
	for i in 120:
		await _ticks(1)
		if out.launched == CombatTypes.ActorState.FREE:
			if not victim.is_flying():
				head = _head_on_hips(victim)
				continue
			out.launched = victim.state
		if TimeController.is_in_hitstop(victim):
			out.hitstop += 1
		elif out.hitstop > 0 and after < 0:
			after = 0
		var seen := _lens(victim)
		out.near = minf(out.near, seen.x)
		out.share = maxf(out.share, seen.y)
		out.gap = minf(out.gap, _chest_gap(victim))
		var now := _head_on_hips(victim)
		if victim.is_flying():
			out.head_step = maxf(out.head_step, now.distance_to(head))
		head = now
		if after >= 0:
			after += 1
			if after >= AFTER_HITSTOP:
				break
	return out


## Where `victim`'s drawn head is from its drawn hips (world m).
func _head_on_hips(victim: CombatActor) -> Vector3:
	return victim.rig.get_visual_point_transform(&"Head").origin - victim.rig.get_visual_point_transform(&"Hips").origin


func _assert_clear(out: Dictionary, what: String) -> void:
	gut.p("%s: %s" % [what, out])
	assert_ne(out.launched, CombatTypes.ActorState.FREE, "%s: launched out of the hold" % what)
	assert_gt(out.hitstop, 0, "%s: watched through its hitstop" % what)
	assert_gte(out.near, 0.25, "%s: the victim stays 0.25 m or more from the lens (nearest %.3f m)" % [what, out.near])
	assert_lte(out.share, 0.5, "%s: the victim covers at most half the view (%.0f%%)" % [what, out.share * 100.0])
	assert_gte(out.gap, out.held_gap - 0.03,
			"%s: side on, its chest never comes closer to the holder's than in the hold (%.3f m, held %.3f m)" % [what, out.gap, out.held_gap])
	# Snapping upright out of the bend moved it 0.26 m (the knee) to 0.55 m (the throw) in a tick.
	assert_lt(out.head_step, 0.15, "%s: it unbends, no snap: its head moves at most 0.15 m a tick around its hips (%.3f m)" % [what, out.head_step])


# --- Tests ------------------------------------------------------------------------------


func test_a_knee_that_kos_the_held_body_leaves_the_lens_and_the_holder_clear() -> void:
	for ragdoll: bool in [true, false]:
		Tuning.data.ragdoll_enabled = ragdoll
		var out := await _launch_out_of_the_hold(&"P", true)
		_assert_clear(out, "knee KO, ragdoll %s" % ragdoll)
		assert_eq(out.launched, CombatTypes.ActorState.LAUNCHED, "knocked off its feet")
		assert_true(dummies[0].is_ko() or dummies[0].is_flying(), "the knee KO'd it")
		if ragdoll:
			assert_eq(dummies[0].rig.ragdoll_mode(), Ragdoll.Mode.FULL, "the full ragdoll, as every body knocked off its feet")


func test_the_throw_leaves_the_lens_and_the_holder_clear() -> void:
	for ragdoll: bool in [true, false]:
		Tuning.data.ragdoll_enabled = ragdoll
		var out := await _launch_out_of_the_hold(&"K", false)
		_assert_clear(out, "throw, ragdoll %s" % ragdoll)
		assert_eq(out.launched, CombatTypes.ActorState.THROWN, "thrown")
		if ragdoll:
			assert_eq(dummies[0].rig.ragdoll_mode(), Ragdoll.Mode.FULL, "the full ragdoll")
