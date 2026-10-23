class_name CameraDirector
extends Node3D
## Owns the three cameras and switches between them on camera_cycle (F2, Spec §11): the
## first-person view, the side-view belt-scroller shot and the free-fly camera. Gameplay
## keeps running whichever is active. It finds the player through the "player" group,
## also when the player appears after this node or is freed and replaced, and hands it to
## the cameras. Presentation only: nothing here writes player or simulation state, and
## while the tree is paused the cameras hold still.

## Emitted after the active camera changes.
signal camera_changed(mode: StringName)

const MODE_FIRST_PERSON := &"first_person"
const MODE_SIDE_VIEW := &"side_view"
const MODE_FREE_FLY := &"free_fly"
## cycle() order.
const MODES: Array[StringName] = [MODE_FIRST_PERSON, MODE_SIDE_VIEW, MODE_FREE_FLY]
## The director and its cameras process after default-priority nodes, so a player that
## applies look input in its own _process is up to date when the view is placed.
const PROCESS_PRIORITY := 50

## Active camera mode, one of MODES. Assigning it switches cameras (see set_mode()).
var mode: StringName = MODE_FIRST_PERSON:
	set = set_mode
## The player the cameras follow, or null while there is none.
var player: PlayerCharacter = null
var first_person_camera: FirstPersonCamera = FirstPersonCamera.new()
var side_view_camera: SideViewCamera = SideViewCamera.new()
var free_fly_camera: FreeFlyCamera = FreeFlyCamera.new()


func _init() -> void:
	add_to_group(&"camera_director")
	# Pausable even under an always-processing parent, so the cameras hold still on pause.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_priority = PROCESS_PRIORITY
	first_person_camera.name = &"FirstPersonCamera"
	side_view_camera.name = &"SideViewCamera"
	free_fly_camera.name = &"FreeFlyCamera"
	for camera: Camera3D in [first_person_camera, side_view_camera, free_fly_camera]:
		camera.process_priority = PROCESS_PRIORITY
		add_child(camera)


func _ready() -> void:
	refresh_player()
	active_camera().make_current()


func _process(_delta: float) -> void:
	refresh_player()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"camera_cycle"):
		cycle()
		get_viewport().set_input_as_handled()


## Switch to the next camera: first person, then side view, then free fly, then back.
func cycle() -> void:
	set_mode(MODES[(MODES.find(mode) + 1) % MODES.size()])


## Make `new_mode` (one of MODES) the active camera and emit camera_changed. Free fly
## starts where the previously active camera was. Setting the current mode does nothing.
func set_mode(new_mode: StringName) -> void:
	if not MODES.has(new_mode):
		push_error("CameraDirector: unknown camera mode '%s'" % new_mode)
		return
	if new_mode == mode:
		return
	var previous := active_camera()
	mode = new_mode
	if mode == MODE_FREE_FLY:
		free_fly_camera.activate_from(previous)
	if is_inside_tree():
		active_camera().make_current()
	camera_changed.emit(mode)


## The camera for the current mode.
func active_camera() -> Camera3D:
	match mode:
		MODE_SIDE_VIEW:
			return side_view_camera
		MODE_FREE_FLY:
			return free_fly_camera
	return first_person_camera


## Add screen-shake trauma to the first-person camera (see FirstPersonCamera.add_trauma()).
func add_trauma(amount: float) -> void:
	first_person_camera.add_trauma(amount)


## Look the player up again if the one we have is gone (freed or out of the tree). Runs
## every frame; it costs nothing while the player is alive.
func refresh_player() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(player) and player.is_inside_tree():
		return
	var found: PlayerCharacter = null
	for node: Node in get_tree().get_nodes_in_group(&"player"):
		if node is PlayerCharacter and node.is_inside_tree():
			found = node as PlayerCharacter
			break
	player = found
	first_person_camera.player = found
	side_view_camera.player = found
