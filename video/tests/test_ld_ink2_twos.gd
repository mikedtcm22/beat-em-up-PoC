extends GutTest
## LD-INK2: characters on twos hold the drawing the picked tick showed. The old test stepped one process frame per output frame, so it could not see
## that a draw frame spans two or three 60 Hz ticks and the store ran on every one of them (a held frame then repeated the LAST tick's pose, two ticks
## after the drawing). This one steps 60 Hz ticks through CineFrameWriter's own mapping, as the frame writer does.

const SIM_FPS := 60
const OUT_FPS := 24


## A rig stand-in whose output frame is set from the tick, the way the writer's `current_output_index` does it.
class TickSource extends Node:
	var tick: int = 0


	func output_frame() -> int:
		return CineFrameWriter.output_index(tick, 60, 24)


func _rig() -> Dictionary:
	var skeleton := Skeleton3D.new()
	skeleton.add_bone("Root")
	skeleton.add_bone("Arm")
	skeleton.set_bone_parent(1, 0)
	add_child_autofree(skeleton)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	skeleton.add_child(mesh)
	mesh.add_to_group(HumanoidRig.ART_GROUP)
	var source := TickSource.new()
	add_child_autofree(source)
	var twos := CineTwos.new()
	twos.rig = source
	twos.hold = 2
	add_child_autofree(twos)
	twos.set_process(false)
	return {skeleton = skeleton, source = source, twos = twos}


## Step ticks 0..last: the simulation sets the arm's x to the tick number, then the twos node runs, then the frame is "rendered" on a pick.
## Returns {output frame: the arm's x the render saw}.
func _render(last: int) -> Dictionary[int, float]:
	var scene := _rig()
	var skeleton: Skeleton3D = scene.skeleton
	var source: TickSource = scene.source
	var twos: CineTwos = scene.twos
	var seen: Dictionary[int, float] = {}
	for tick in range(0, last + 1):
		source.tick = tick
		skeleton.set_bone_pose_position(1, Vector3(float(tick), 0.0, 0.0))
		twos._process(0.0)
		if CineFrameWriter.is_pick(tick, 0, SIM_FPS, OUT_FPS):
			seen[CineFrameWriter.output_index(tick, SIM_FPS, OUT_FPS)] = skeleton.get_bone_pose_position(1).x
	return seen


func test_a_held_frame_repeats_the_drawing_of_the_picked_tick() -> void:
	var seen := _render(120)
	for frame in range(1, 40, 2):
		assert_eq(seen[frame], seen[frame - 1], "output frame %d is a hold: it shows frame %d's drawing" % [frame, frame - 1])


func test_a_draw_frame_shows_the_pose_of_its_first_tick() -> void:
	var seen := _render(120)
	var picks := CineFrameWriter.picks(0, 120, SIM_FPS, OUT_FPS)
	for frame in range(0, 40, 2):
		assert_eq(seen[frame], float(picks[frame]), "draw frame %d shows the pose of its pick tick %d, not a later tick's" % [frame, picks[frame]])


func test_the_drawings_change_every_two_frames() -> void:
	var seen := _render(120)
	for frame in range(2, 40, 2):
		assert_gt(seen[frame], seen[frame - 2], "draw frame %d is a new drawing" % frame)
