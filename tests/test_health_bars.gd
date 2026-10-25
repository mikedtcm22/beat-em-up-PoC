extends GutTest
## Over-head enemy health bars on bodies that are not standing up straight (M2 phase 3
## review, ragdoll-03): EnemyHealthBars.anchor_of() keeps the bar above the body as it is
## drawn, in the side view too, whether its head bends toward the camera in a stagger, it
## flies, it is held bent over or it lies. Standing, the bar is over the top of its head as
## before. (A KO'd body's bar: tests/test_ko_blink.gd.)

const ROOM := preload("res://game/level/test_room.tscn")
const FAR := Vector3(30.0, 0.0, -30.0)
## The drawn body's points the bar must stay above.
const BODY_POINTS: Array[StringName] = [
	&"HeadTopPoint", &"EyePoint", &"ChestPoint", &"Hips", &"LeftFistPoint", &"RightFistPoint",
	&"LeftElbowPoint", &"RightElbowPoint", &"LeftKneePoint", &"RightKneePoint",
	&"LeftFootPoint", &"RightFootPoint",
]

var room: Node3D
var player: PlayerCharacter
var dummies: Array[TrainingDummy] = []
## A side-view camera: level with the dummy's chest, 4 m to its side.
var camera: Camera3D


func before_each() -> void:
	TimeController.clear()
	TimeController.debug_scale = 1.0
	Tuning.apply(TuningData.new())
	Tuning.data.dummy_health = 500.0


func after_each() -> void:
	TimeController.clear()


# --- Harness ------------------------------------------------------------------------


## The room (no presentation) with dummy 0 `ahead` meters in front of the player, the rest
## far away, and the side camera on dummy 0.
func _setup(ahead: float = 1.6) -> void:
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
		var pos := player.global_position + player.get_forward() * ahead if i == 0 else FAR + Vector3(i * 3.0, 0.0, 0.0)
		var to_player := player.global_position - pos
		dummies[i].sparring = false
		dummies[i].set_post(pos, atan2(-to_player.x, -to_player.z), true)
	camera = Camera3D.new()
	room.add_child(camera)
	var side := player.get_forward().cross(Vector3.UP)
	var at := dummies[0].global_position + Vector3.UP * 1.2
	camera.look_at_from_position(at + side * 4.0, at)
	camera.make_current()
	await _ticks(3)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## A synthetic hit from the player on `victim`.
func _hit(victim: CombatActor, reaction: CombatTypes.Reaction, knockback: Vector3,
		region: CombatTypes.Region = CombatTypes.Region.HEAD) -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = player
	hit.victim = victim
	hit.damage = 1.0
	hit.tier = CombatTypes.HitTier.HEAVY
	hit.reaction = reaction
	hit.region = region
	hit.direction = Vector3(knockback.x, 0.0, knockback.z).normalized() if Vector2(knockback.x, knockback.z).length() > 0.01 else player.get_forward()
	hit.knockback = knockback
	var point := &"Head" if region == CombatTypes.Region.HEAD else &"ChestPoint"
	hit.contact_point = victim.rig.get_point_position(point) - hit.direction * 0.15
	hit.physics_frame = Engine.get_physics_frames()
	return hit


## Watch `d` for `ticks` ticks: how far its drawn body ever reached above the bar's anchor,
## in the world (meters, anchor_of()) and on the side camera's screen (pixels, positive = the
## bar on the body; screen_anchor_of()), and how high the anchor floated above the drawn body
## at most.
func _watch(d: CombatActor, ticks: int) -> Dictionary:
	var above_m := -INF
	var above_px := -INF
	var float_m := -INF
	for i in ticks:
		await get_tree().physics_frame
		var anchor := EnemyHealthBars.anchor_of(d)
		var anchor_px := EnemyHealthBars.screen_anchor_of(d, camera).y
		var top := -INF
		for point: StringName in BODY_POINTS:
			var p := d.rig.get_visual_point_transform(point).origin
			top = maxf(top, p.y)
			above_px = maxf(above_px, anchor_px - camera.unproject_position(p).y)
		above_m = maxf(above_m, top - anchor.y)
		float_m = maxf(float_m, anchor.y - top)
	return {"above_m": above_m, "above_px": above_px, "float_m": float_m}


func _report(label: String, seen: Dictionary) -> void:
	gut.p("%s: the drawn body reached %.2f m / %.0f px above the anchor at most; the anchor floated %.2f m above it at most" % [
		label, seen.above_m, seen.above_px, seen.float_m])
	assert_lte(seen.above_m, 0.0, "%s: the bar stays above the drawn body" % label)
	assert_lte(seen.above_px, 0.0, "%s: and above it on the side view's screen" % label)


# --- Tests --------------------------------------------------------------------------


func test_a_standing_body_has_its_bar_over_its_head() -> void:
	await _setup()
	var dummy := dummies[0]
	assert_eq(EnemyHealthBars.anchor_of(dummy), dummy.get_head_top_position(), "over the top of its head, as before")
	_report("standing", await _watch(dummy, 10))


func test_a_head_bent_toward_the_camera_keeps_the_bar_above_it() -> void:
	await _setup()
	var dummy := dummies[0]
	# A hook from the side the camera is on bends the head toward it.
	var toward := camera.global_position - dummy.global_position
	toward.y = 0.0
	assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.STAGGER, toward.normalized() * 2.0)))
	_report("stagger", await _watch(dummy, 40))


func test_a_flying_body_keeps_the_bar_above_it() -> void:
	await _setup()
	var dummy := dummies[0]
	var away := player.get_forward()
	assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.LAUNCH, away * 3.0 + Vector3.UP * 4.0)))
	_report("uppercut launch", await _watch(dummy, 50))
	await _setup()
	dummy = dummies[0]
	assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.KNOCKDOWN, away * 6.0 + Vector3.UP * 2.0, CombatTypes.Region.TORSO)))
	_report("haymaker knockdown", await _watch(dummy, 50))


func test_a_lying_body_keeps_the_bar_above_it() -> void:
	await _setup()
	var dummy := dummies[0]
	assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.KNOCKDOWN, player.get_forward() * 2.0, CombatTypes.Region.TORSO)))
	for i in 120:
		if dummy.is_downed():
			break
		await get_tree().physics_frame
	assert_true(dummy.is_downed(), "lying")
	_report("lying", await _watch(dummy, 40))


func test_a_held_body_keeps_the_bar_above_it() -> void:
	await _setup(0.9)
	var dummy := dummies[0]
	player.input.push_press(&"GRAB", 2)
	for i in 30:
		if dummy.holder == player:
			break
		await get_tree().physics_frame
	assert_eq(dummy.holder, player, "held")
	_report("held", await _watch(dummy, 40))


func test_a_kod_enemys_bar_fades_once_its_last_chunk_has_drained() -> void:
	# Review ragdoll-04: an empty bar over a lying body adds nothing, and it would hang,
	# steady, over the body blinking off. (The latest it goes, the blink: test_ko_blink.gd.)
	await _setup()
	var dummy := dummies[0]
	var bars := EnemyHealthBars.new()
	bars.show_seconds = 30.0
	add_child_autofree(bars)
	dummy.health = 2.0
	CombatEvents.health_changed.emit(dummy, dummy.health, dummy.max_health)
	bars.on_health_changed(dummy, dummy.health, dummy.max_health)
	for i in 120:
		bars.advance(1.0 / 60.0)
	assert_true(bars.has_bar(dummy), "a bar for the low health, its chunk drained")
	var hit := _hit(dummy, CombatTypes.Reaction.KNOCKDOWN, player.get_forward() * 2.0, CombatTypes.Region.TORSO)
	hit.damage = 10.0
	assert_true(dummy.receive_hit(hit))
	assert_true(hit.killed, "the killing hit")
	bars.on_hit_landed(hit)
	var ko_at := -1
	var gone_at := -1
	for i in 240:
		await get_tree().physics_frame
		bars.advance(1.0 / 60.0)
		if ko_at < 0 and dummy.is_ko():
			ko_at = i
		if gone_at < 0 and not bars.has_bar(dummy):
			gone_at = i
			break
	gut.p("KO'd at tick %d, its bar gone at tick %d" % [ko_at, gone_at])
	assert_gte(ko_at, 0, "KO'd")
	assert_gt(gone_at, ko_at, "the bar stays through the fall")
	# It fades out once KO'd and the killing hit's small chunk has drained (from the hit).
	var gauge := HealthGauge.new()
	var drained_at := roundi((gauge.ghost_delay_s + 2.0 / dummy.max_health / gauge.ghost_drain_per_s) * 60.0)
	assert_lte(gone_at, maxi(ko_at, drained_at) + roundi(bars.fade_seconds * 60.0) + 2, "and fades out once KO'd and drained")
