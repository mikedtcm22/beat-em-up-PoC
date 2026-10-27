extends RefCounted
## The log lines of the Milestone 4 look acts (tests/bot/acts/look_acts.gd, M4-plan Part A A12):
## where a character is on the screen, and which frame is worth a still. tools/look_sheets.sh reads
## them from the bot's log to cut full-resolution stills and 2x crops out of a recording.
##
##   LOOK-MARK <slug> f<frame> <label>              a frame worth a still (a label of `start` or
##                                                   `end` only delimits the act: no still)
##   LOOK-RECT <slug> f<frame> <head|hands|body> x y w h
##                                                   a rectangle, in 1600x900 pixels (the
##                                                   recording's size), top-left corner and size
##
## The rectangles are made from the rig's drawn points (HumanoidRig.get_visual_point_transform():
## the ragdoll's pose while one runs, the animation otherwise) through the camera that is current,
## so they follow the body that is on the screen. They are bounds of spheres round those points,
## grown by PAD_PX and clipped to the frame; a region that is wholly outside the frame, or behind
## the lens, prints no line. A region sphere that reaches the lens fills the frame.
##
## Frames are Engine.get_physics_frames() read as a bot resumes from a `physics_frame` await: before
## any node ticks, so the poses and the camera are what the frame before it drew. Movie Maker writes
## one video frame per physics tick (--fixed-fps 60 at 60 Hz), so the video frame of a line is its
## `f<frame>` plus look_sheets.sh's FRAME_OFFSET (calibrated there).

## The size every rectangle is reported in: the recording's (project.godot's window override).
const FRAME_SIZE := Vector2(1600.0, 900.0)
const HEAD := &"head"
const HANDS := &"hands"
const BODY := &"body"
const ALL_REGIONS: Array[StringName] = [HEAD, HANDS, BODY]
## What the regions are made of, at the rig's own scale: the head is its hurtbox (the cap's brim and
## the hair are inside this much more), a hand is a sphere round its FistPoint, the body is a sphere
## round every bone (the head and the hands are in it too).
const HEAD_PAD_M := 0.04
const HAND_RADIUS_M := 0.1
const BODY_RADIUS_M := 0.12
## Every rectangle is grown by this many pixels of FRAME_SIZE (a crop with a little air round it).
const PAD_PX := 12.0
## A sphere that is nearer to the lens than this (m, past its own radius) fills the frame.
const NEAR_M := 0.05


## `LOOK-MARK` for `slug` at this frame; with `subject` (a CombatActor), the `regions` rectangles of
## its rig at the same frame. Logged through the bot's log_line(), so it also lands in its summary.
static func mark(bot: Node, slug: String, label: String, subject: CombatActor = null,
		regions: Array[StringName] = ALL_REGIONS) -> void:
	var frame := Engine.get_physics_frames()
	bot.log_line("LOOK-MARK %s f%d %s" % [slug, frame, label])
	if subject != null:
		rects(bot, slug, subject, regions)


## `LOOK-RECT` lines for `slug` at this frame: the `regions` of `subject`'s rig as the current camera
## sees them. A first-person body (the player's own) leaves out the bones hidden from its own lens.
static func rects(bot: Node, slug: String, subject: CombatActor,
		regions: Array[StringName] = ALL_REGIONS) -> void:
	var frame := Engine.get_physics_frames()
	var camera: Camera3D = bot.get_viewport().get_camera_3d()
	if camera == null or subject == null or not is_instance_valid(subject) or subject.rig == null:
		return
	var fp: bool = subject == bot.get(&"player")
	for region: StringName in regions:
		var rect := region_rect(camera, subject.rig, region, fp)
		if rect.has_area():
			bot.log_line(line(slug, frame, region, rect))


## One LOOK-RECT line.
static func line(slug: String, frame: int, region: StringName, rect: Rect2) -> String:
	return "LOOK-RECT %s f%d %s %d %d %d %d" % [slug, frame, region, roundi(rect.position.x),
			roundi(rect.position.y), roundi(rect.size.x), roundi(rect.size.y)]


## The rectangle (FRAME_SIZE pixels) of `region` of `rig` through `camera`; a Rect2 with no area when
## it is not on the screen. `fp`: the rig is a first-person body, whose Chest, UpperChest, Neck, Head
## and shoulders are hidden from its own lens (PlaceholderBody.FP_HIDDEN_BONES), so they are no part
## of its body.
static func region_rect(camera: Camera3D, rig: HumanoidRig, region: StringName, fp: bool = false) -> Rect2:
	var scale := rig.rig_scale()
	match region:
		HEAD:
			if fp:
				return Rect2()
			var spec := _head_spec()
			var centre := rig.get_visual_point_transform(spec.bone_a) * (spec.offset_a * scale)
			return bounds(camera, PackedVector3Array([centre]), (spec.radius + HEAD_PAD_M) * scale)
		HANDS:
			var fists := PackedVector3Array([
				rig.get_visual_point_transform(&"LeftFistPoint").origin,
				rig.get_visual_point_transform(&"RightFistPoint").origin,
			])
			return _union(bounds(camera, PackedVector3Array([fists[0]]), HAND_RADIUS_M * scale),
					bounds(camera, PackedVector3Array([fists[1]]), HAND_RADIUS_M * scale))
		BODY:
			var joints := PackedVector3Array()
			for bone: StringName in PlaceholderBody.BONE_NAMES:
				if bone == &"Root" or (fp and PlaceholderBody.FP_HIDDEN_BONES.has(bone)):
					continue
				joints.append(rig.get_visual_point_transform(bone).origin)
			var body := bounds(camera, joints, BODY_RADIUS_M * scale)
			if not fp:
				body = _union(body, region_rect(camera, rig, HEAD, false))
			return _union(body, region_rect(camera, rig, HANDS, fp))
	return Rect2()


## The bounding rectangle (FRAME_SIZE pixels, grown by `pad_px`, clipped to the frame) of spheres of
## `radius_m` at `centres` as `camera` sees them. A sphere wholly behind the lens is skipped; one
## that reaches the lens fills the frame. A Rect2 with no area when nothing is on the screen.
static func bounds(camera: Camera3D, centres: PackedVector3Array, radius_m: float,
		pad_px: float = PAD_PX) -> Rect2:
	var to_frame := FRAME_SIZE / camera.get_viewport().get_visible_rect().size
	var cam := camera.global_transform
	var frame := Rect2(Vector2.ZERO, FRAME_SIZE)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for centre: Vector3 in centres:
		var depth := -(cam.affine_inverse() * centre).z
		if depth < -radius_m:
			continue
		if depth < radius_m + NEAR_M:
			return frame
		for offset: Vector3 in [Vector3.ZERO, cam.basis.x * radius_m, -cam.basis.x * radius_m,
				cam.basis.y * radius_m, -cam.basis.y * radius_m]:
			var at := camera.unproject_position(centre + offset) * to_frame
			lo = lo.min(at)
			hi = hi.max(at)
	if lo.x == INF:
		return Rect2()
	var rect := Rect2(lo - Vector2(pad_px, pad_px), hi - lo + Vector2(pad_px, pad_px) * 2.0)
	return rect.intersection(frame)


static func _head_spec() -> PlaceholderBody.HurtSpec:
	for spec: PlaceholderBody.HurtSpec in PlaceholderBody.hurt_specs():
		if spec.region == CombatTypes.Region.HEAD:
			return spec
	return null


## The rectangle that holds both; an empty one counts for nothing.
static func _union(a: Rect2, b: Rect2) -> Rect2:
	if not a.has_area():
		return b
	if not b.has_area():
		return a
	return a.merge(b)
