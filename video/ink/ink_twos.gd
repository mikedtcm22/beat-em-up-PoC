class_name CineTwos
extends Node
## Characters on twos (PLAN.md Plan A part 7; docs/video/P1.md LD-INK 3): a character's pose holds for
## `hold` output frames at 24 fps (12 drawings a second) while the camera and the effects move every frame.
## The rig animation runs in the simulation as always; this node only changes what is drawn. On a "draw"
## frame it stores every bone pose of every character skeleton, on a "hold" frame it writes the stored
## poses back, after the animation has run and before the render (process priority above the rigs'). Physics
## is never touched: a character's body still travels every frame, only his drawing is held.
## The output frame comes from the CineInkRig (the frame writer's own counter when it sets one).

var enabled: bool = true
var hold: int = 2
## The player's own first-person body is held too (his hands are in most shots).
var include_player: bool = true

var rig: Node
var _poses: Dictionary[int, Array] = {}
var _last_drawn: int = -1000


func _init() -> void:
	process_priority = 90


func _process(_delta: float) -> void:
	if not enabled or rig == null:
		return
	var frame: int = rig.output_frame()
	var draw := frame % maxi(hold, 1) == 0
	var skeletons := _skeletons()
	if draw or not _have_poses(skeletons):
		_last_drawn = frame
		for skeleton in skeletons:
			_store(skeleton)
	else:
		for skeleton in skeletons:
			_restore(skeleton)


## True when `frame` is a hold frame (the pose of an earlier frame is drawn).
func is_hold_frame(frame: int) -> bool:
	return enabled and frame % maxi(hold, 1) != 0


func _skeletons() -> Array[Skeleton3D]:
	var out: Array[Skeleton3D] = []
	var player := get_tree().get_first_node_in_group(&"player")
	for node in get_tree().get_nodes_in_group(HumanoidRig.ART_GROUP):
		var mesh := node as MeshInstance3D
		if mesh == null or not mesh.is_inside_tree():
			continue
		var skeleton := mesh.get_parent() as Skeleton3D
		if skeleton == null or out.has(skeleton):
			continue
		if not include_player and player != null and player.is_ancestor_of(skeleton):
			continue
		out.append(skeleton)
	return out


func _have_poses(skeletons: Array[Skeleton3D]) -> bool:
	for skeleton in skeletons:
		if not _poses.has(skeleton.get_instance_id()):
			return false
	return true


func _store(skeleton: Skeleton3D) -> void:
	var count := skeleton.get_bone_count()
	var list: Array = []
	list.resize(count)
	for bone in count:
		list[bone] = [skeleton.get_bone_pose_position(bone), skeleton.get_bone_pose_rotation(bone), skeleton.get_bone_pose_scale(bone)]
	_poses[skeleton.get_instance_id()] = list


func _restore(skeleton: Skeleton3D) -> void:
	var list: Array = _poses.get(skeleton.get_instance_id(), [])
	var count := mini(list.size(), skeleton.get_bone_count())
	for bone in count:
		var entry: Array = list[bone]
		skeleton.set_bone_pose_position(bone, entry[0])
		skeleton.set_bone_pose_rotation(bone, entry[1])
		skeleton.set_bone_pose_scale(bone, entry[2])
