extends GutTest
## Over-head enemy health bars on bodies that are not standing up straight (M2 phase 3
## review, ragdoll-03): EnemyHealthBars.screen_anchor_of() keeps the bar above the body as it is
## drawn, in the side view too, whether its head bends toward the camera in a stagger, it
## flies, it is held bent over or it lies. Standing, the bar is over the top of its head as
## before. (A KO'd body's bar: tests/test_ko_blink.gd.)

const ROOM := preload("res://game/level/test_room.tscn")
const FAR := Vector3(30.0, 0.0, -30.0)
## How far the bar's bottom may reach into the drawn body on the side camera's screen
## (rounding, and a part's vertices that stick out between two joints).
const ON_BODY_PX := 3.0
## How much higher above the drawn body than above a standing one the bar may float (pixels).
const FLOAT_MORE_PX := 12.0

var room: Node3D
var player: PlayerCharacter
var dummies: Array[TrainingDummy] = []
## A side-view camera: level with the dummy's chest, 4 m to its side.
var camera: Camera3D
var bars: EnemyHealthBars
## Mesh -> its vertices (the parts' meshes are built once).
var _vertices: Dictionary = {}


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
	bars = EnemyHealthBars.new()
	add_child_autofree(bars)
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


## The drawn body on the camera's screen: the extremes of every visible body part's mesh
## vertices, projected: {top, left, right} in canvas pixels.
func _silhouette(d: CombatActor) -> Dictionary:
	var top := INF
	var left := INF
	var right := -INF
	for node: Node in d.rig.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		if not _vertices.has(mesh.mesh):
			_vertices[mesh.mesh] = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var to_world := mesh.global_transform
		for v: Vector3 in _vertices[mesh.mesh]:
			var p := camera.unproject_position(to_world * v)
			top = minf(top, p.y)
			left = minf(left, p.x)
			right = maxf(right, p.x)
	return {"top": top, "left": left, "right": right}


## Watch `d` for `ticks` ticks through the side camera: how far the bar's bottom ever reached
## below the top of the drawn body (pixels, positive = on the body), how far above it it
## floated at most, and whether it stayed over the body across.
func _watch(d: CombatActor, ticks: int) -> Dictionary:
	var on_px := -INF
	var float_px := -INF
	var across := true
	for i in ticks:
		await get_tree().physics_frame
		var anchor := bars.screen_anchor_of(d, camera)
		var bottom := anchor.y - bars.lift_px
		var body := _silhouette(d)
		on_px = maxf(on_px, bottom - body.top)
		float_px = maxf(float_px, body.top - bottom)
		across = across and anchor.x >= body.left and anchor.x <= body.right
	return {"on_px": on_px, "float_px": float_px, "across": across}


## The bar over `d` standing, as a reference: how far it floats above the body (pixels).
func _standing_float(d: CombatActor) -> float:
	return (await _watch(d, 1)).float_px


func _report(label: String, seen: Dictionary, standing_float: float) -> void:
	gut.p("%s: the bar's bottom reached %.0f px into the drawn body at most, floated %.0f px above it at most (standing: %.0f px)" % [
		label, seen.on_px, seen.float_px, standing_float])
	assert_lte(seen.on_px, ON_BODY_PX, "%s: the bar stays above the drawn body" % label)
	assert_lte(seen.float_px, standing_float + FLOAT_MORE_PX, "%s: and close above it, as over a standing body" % label)
	assert_true(seen.across, "%s: over it across" % label)


# --- Tests --------------------------------------------------------------------------


func test_a_standing_body_has_its_bar_over_its_head() -> void:
	await _setup()
	var dummy := dummies[0]
	# Over the top of its head as before (across, over its hips: a few centimeters off the
	# head in the stance).
	var head := camera.unproject_position(dummy.get_head_top_position())
	var anchor := bars.screen_anchor_of(dummy, camera)
	assert_almost_eq(anchor.y, head.y, 0.5, "at the top of its head")
	assert_almost_eq(anchor.x, head.x, 15.0, "over it")
	var standing := await _standing_float(dummy)
	_report("standing", await _watch(dummy, 10), standing)


func test_a_head_bent_toward_the_camera_keeps_the_bar_above_it() -> void:
	await _setup()
	var dummy := dummies[0]
	# A hook from the side the camera is on bends the head toward it.
	var toward := camera.global_position - dummy.global_position
	toward.y = 0.0
	var standing := await _standing_float(dummy)
	assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.STAGGER, toward.normalized() * 2.0)))
	_report("stagger", await _watch(dummy, 40), standing)


func test_a_flying_body_keeps_the_bar_above_it() -> void:
	await _setup()
	var dummy := dummies[0]
	var away := player.get_forward()
	var standing := await _standing_float(dummy)
	assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.LAUNCH, away * 3.0 + Vector3.UP * 4.0)))
	_report("uppercut launch", await _watch(dummy, 50), standing)
	await _setup()
	dummy = dummies[0]
	assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.KNOCKDOWN, away * 6.0 + Vector3.UP * 2.0, CombatTypes.Region.TORSO)))
	_report("haymaker knockdown", await _watch(dummy, 50), standing)


func test_a_lying_body_keeps_the_bar_above_it() -> void:
	await _setup()
	var dummy := dummies[0]
	var standing := await _standing_float(dummy)
	assert_true(dummy.receive_hit(_hit(dummy, CombatTypes.Reaction.KNOCKDOWN, player.get_forward() * 2.0, CombatTypes.Region.TORSO)))
	for i in 120:
		if dummy.is_downed():
			break
		await get_tree().physics_frame
	assert_true(dummy.is_downed(), "lying")
	_report("lying", await _watch(dummy, 40), standing)


func test_a_held_body_keeps_the_bar_above_it() -> void:
	await _setup(0.9)
	var dummy := dummies[0]
	var standing := await _standing_float(dummy)
	player.input.push_press(&"GRAB", 2)
	for i in 30:
		if dummy.holder == player:
			break
		await get_tree().physics_frame
	assert_eq(dummy.holder, player, "held")
	_report("held", await _watch(dummy, 40), standing)
	# Its head at the holder's waist, the bar is over its far side, off the holder's head.
	var head_mesh := player.rig.find_child("BoneHead", true, false)
	var head := Rect2()
	var first := true
	for node: Node in head_mesh.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for v: Vector3 in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var p := camera.unproject_position(mesh.global_transform * v)
			head = Rect2(p, Vector2.ZERO) if first else head.expand(p)
			first = false
	var anchor := bars.screen_anchor_of(dummy, camera)
	var bar := Rect2(anchor - Vector2(bars.bar_size.x * 0.5, bars.bar_size.y + bars.lift_px), bars.bar_size)
	gut.p("held: the bar %s, the holder's head %s" % [bar, head])
	assert_false(bar.intersects(head), "the bar is off the holder's head")


func test_a_kod_enemys_bar_fades_once_its_last_chunk_has_drained() -> void:
	# Review ragdoll-04: an empty bar over a lying body adds nothing, and it would hang,
	# steady, over the body blinking off. (The latest it goes, the blink: test_ko_blink.gd.)
	await _setup()
	var dummy := dummies[0]
	bars.show_seconds = 30.0
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


func test_a_bar_projected_far_off_the_canvas_is_not_drawn() -> void:
	# A head just in front of the camera plane (a body at the lens) projects millions of
	# pixels away. There, float precision collapses the bar's thin fill and drawing it logged
	# "Invalid polygon data, triangulation failed" (Game-boy's M4 playtest, hud_style.gd).
	var canvas := EnemyHealthBars.new()
	canvas.size = Vector2(1280.0, 720.0)
	add_child_autofree(canvas)
	var bar := EnemyHealthBars.Bar.new()
	bar.on_screen = true
	bar.screen_position = Vector2(640.0, 300.0)
	assert_true(canvas.is_drawn(bar), "a bar over a body on the canvas is drawn")
	bar.screen_position = Vector2(-1.0e6, 1.0e6)
	assert_false(canvas.is_drawn(bar), "a bar a million pixels off the canvas is not drawn")
	var shift := canvas.slant * canvas.bar_size.y
	var top_left := bar.screen_position - Vector2(canvas.bar_size.x * 0.5, canvas.bar_size.y + canvas.lift_px)
	var length := 0.6 * (canvas.bar_size.x - shift)
	var fill := PackedVector2Array([
		top_left + Vector2(shift, 0.0), top_left + Vector2(shift + length, 0.0),
		top_left + Vector2(length, canvas.bar_size.y), top_left + Vector2(0.0, canvas.bar_size.y),
	])
	assert_true(Geometry2D.triangulate_polygon(fill).is_empty(), "there, the fill could not be triangulated (why the bar is skipped)")
	bar.screen_position = Vector2(-30.0, 300.0)
	assert_true(canvas.is_drawn(bar), "a bar half over the canvas's edge is still drawn")
	bar.on_screen = false
	bar.screen_position = Vector2(640.0, 300.0)
	assert_false(canvas.is_drawn(bar), "a bar off screen (head behind the camera) is not drawn")
