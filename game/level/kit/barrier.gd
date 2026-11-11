class_name Barrier
extends Node3D
## An arena barrier (Milestone 5, SPEC §9): a rolling shutter that drops, a chain-link gate that
## slides, or a parked car that rolls across. Closed it is a world-layer collider the size of its
## opening (the navmesh bakes with every barrier closed, so each arena is its own island); open it
## is none. The panel it draws moves between its open and closed place over the tunables
## `barrier_close_s` and `barrier_open_s`.
##
## Local frame: the opening spans local X (`width_m`, centred) and rises `height_m` from local y 0;
## local -Z is the way the player walks through it (an arena measures "past it" along that). A
## barrier in a wall that runs the other way is rotated 180 degrees about Y, nothing else. The
## collider is `thickness_m` deep and centred on local z 0.
##
## `close()` and `open()` are logical at once (the collider goes with the call) and the panel
## follows; `CombatEvents.barrier_moving` fires when a call changes the state (Milestone 6, the
## barrier sounds) and `moved(closed)` when the panel has arrived. `snap()` jumps (the level's start
## and the bake) and fires neither. Every number is an export or a tunable.
##
## Art (Milestone 6, KIT; D13): the `Panel` holds the kit's pieces, a `KitMesh` `shutter` slab and its
## `housing` (which stays), a `gate` of posts, rails and wire, or one `PropSpot` car per
## `car_length_m` of the opening (the parked-car rule below), all visual: the collider is the
## `Collider` body and the panel's position is the same animated offset. Tuning's `kit_draw_graybox`
## builds M5's boxes instead.

## The panel has finished closing (`closed` true) or opening (false).
signal moved(closed: bool)

enum Kind { SHUTTER, GATE, CAR }

const GROUP := &"barrier"

@export var kind: Kind = Kind.SHUTTER
@export_range(0.5, 40.0, 0.1) var width_m: float = 6.0
@export_range(0.5, 8.0, 0.1) var height_m: float = 3.5
## Depth of the collider and of the drawn panel (a car is as deep as a car).
@export_range(0.05, 4.0, 0.05) var thickness_m: float = 0.3
## Closed when the level starts (an arena's ahead barrier); behind barriers start open.
@export var start_closed: bool = false
## Gate and car: which way it slides open along local X (+1 or -1); it needs that room beside the
## opening (a wall for the gate to run along, an alley mouth for the car).
@export_range(-1, 1, 2) var open_side: int = 1
## Car: the length of one parked car (m); the barrier is as many as fill the opening.
@export_range(2.0, 7.0, 0.1) var car_length_m: float = 4.2

var _closed: bool = false
## 0 = open, 1 = closed (the panel's place).
var _progress: float = 0.0
var _target: float = 0.0
var _panel: Node3D
var _collider: StaticBody3D
var _shape: CollisionShape3D


func _ready() -> void:
	add_to_group(GROUP)
	_build()
	snap(start_closed)


## Start closing: the collider is there now, the panel arrives within `barrier_close_s`.
func close() -> void:
	if not _closed:
		CombatEvents.barrier_moving.emit(self, true)
	_closed = true
	_target = 1.0
	_apply_collider()
	if _progress >= 1.0:
		moved.emit(true)


## Start opening: the collider is gone now, the panel is out of the way within `barrier_open_s`.
func open() -> void:
	if _closed:
		CombatEvents.barrier_moving.emit(self, false)
	_closed = false
	_target = 0.0
	_apply_collider()
	if _progress <= 0.0:
		moved.emit(false)


## Closed or open at once, with no animation and no `moved`.
func snap(closed: bool) -> void:
	_closed = closed
	_target = 1.0 if closed else 0.0
	_progress = _target
	_apply_collider()
	_place_panel()


## True from `close()` until `open()` (the collider is there); not whether the panel has arrived.
func is_closed() -> bool:
	return _closed


## True while the panel is still travelling.
func is_moving() -> bool:
	return not is_equal_approx(_progress, _target)


## The panel's place: 0 open, 1 closed.
func progress() -> float:
	return _progress


## The way through the barrier in world space (flat unit vector, local -Z).
func walk_direction() -> Vector3:
	var forward := -global_basis.z
	forward.y = 0.0
	return forward.normalized()


## How far past the barrier `point` is along the walk (negative: before it), in metres.
func past(point: Vector3) -> float:
	return (point - global_position).dot(walk_direction())


func _physics_process(delta: float) -> void:
	if not is_moving():
		return
	var tuning := Tuning.data
	var seconds: float = tuning.barrier_close_s if _target > _progress else tuning.barrier_open_s
	_progress = move_toward(_progress, _target, delta / maxf(seconds, 0.01))
	_place_panel()
	if is_equal_approx(_progress, _target):
		_progress = _target
		_place_panel()
		moved.emit(_closed)


func _apply_collider() -> void:
	if _collider == null:
		return
	_collider.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD) if _closed else 0
	_shape.disabled = not _closed


func _place_panel() -> void:
	if _panel == null:
		return
	# Eased: a shutter drops fast and settles, a gate or a car starts slowly.
	var t := _progress
	t = 1.0 - pow(1.0 - t, 2.0) if kind == Kind.SHUTTER else t * t * (3.0 - 2.0 * t)
	_panel.position = _open_offset() * (1.0 - t)


## Where the panel stands when open, relative to where it stands closed.
func _open_offset() -> Vector3:
	match kind:
		Kind.SHUTTER:
			return Vector3(0.0, height_m, 0.0)
	return Vector3(float(open_side) * (width_m + 0.2), 0.0, 0.0)


func _build() -> void:
	_collider = StaticBody3D.new()
	_collider.name = "Collider"
	_collider.collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width_m, height_m, thickness_m)
	_shape.shape = box
	_shape.position = Vector3(0.0, height_m * 0.5, 0.0)
	_collider.add_child(_shape)
	add_child(_collider)
	_panel = Node3D.new()
	_panel.name = "Panel"
	add_child(_panel)
	var kit := RoomKit.kit_art(&"shutter")
	match kind:
		Kind.SHUTTER:
			if kit:
				_build_shutter_art()
			else:
				_build_shutter()
		Kind.GATE:
			if kit:
				_build_gate_art()
			else:
				_build_gate()
		Kind.CAR:
			if kit:
				_build_cars_art()
			else:
				_build_cars()


## The kit's roller shutter: the slats on the panel, the roll housing above the opening (it stays).
func _build_shutter_art() -> void:
	_piece(_panel, &"shutter", Vector3(0.0, height_m * 0.5, 0.0), Vector3(width_m, height_m, thickness_m * 0.6))
	_piece(self, &"housing", Vector3(0.0, height_m + 0.25, 0.0), Vector3(width_m + 0.4, 0.5, thickness_m + 0.3))


## The kit's chain-link gate: posts, rails and the wire, as one piece on the panel.
func _build_gate_art() -> void:
	_piece(_panel, &"gate", Vector3(0.0, height_m * 0.5, 0.0), Vector3(width_m, height_m, thickness_m))


## Parked cars across the opening, one `PropSpot` car per `car_length_m` (as many as fill it), each
## fitted to its share of the opening and to the barrier's height, so the closed panel is as tall as
## the collider (the Tripo car, when PROPS's scene exists, is stretched to it).
func _build_cars_art() -> void:
	var count := maxi(ceili(width_m / car_length_m - 0.05), 1)
	var length := width_m / float(count)
	for i in count:
		var spot := PropSpot.new()
		spot.name = "Car%d" % (i + 1)
		spot.prop_id = &"car"
		spot.size = Vector3(length - 0.25, height_m, thickness_m)
		spot.position = Vector3(-width_m * 0.5 + length * (float(i) + 0.5), 0.0, 0.0)
		_panel.add_child(spot)


static func _piece(parent: Node3D, art: StringName, pos: Vector3, size: Vector3) -> KitPiece:
	var piece := KitPiece.new()
	piece.kind = art
	piece.size = size
	piece.position = pos
	parent.add_child(piece)
	return piece


## A corrugated roller shutter: a slab with a rib every quarter metre, and the roll housing above
## the opening, which stays where it is.
func _build_shutter() -> void:
	var slab := RoomKit.flat_material(Color(0.36, 0.38, 0.43))
	var rib := RoomKit.flat_material(Color(0.24, 0.25, 0.3))
	_box(_panel, Vector3(0.0, height_m * 0.5, 0.0), Vector3(width_m, height_m, thickness_m * 0.6), slab)
	var y := 0.2
	while y < height_m - 0.1:
		_box(_panel, Vector3(0.0, y, 0.0), Vector3(width_m, 0.07, thickness_m), rib)
		y += 0.25
	_box(self, Vector3(0.0, height_m + 0.25, 0.0), Vector3(width_m + 0.4, 0.5, thickness_m + 0.3), rib)


## A chain-link gate: a frame of posts and rails with a lattice of thin bars (seen through).
func _build_gate() -> void:
	var frame := RoomKit.flat_material(Color(0.46, 0.47, 0.5))
	var wire := RoomKit.flat_material(Color(0.3, 0.31, 0.35))
	var post := 0.14
	for x: float in [-width_m * 0.5 + post * 0.5, 0.0, width_m * 0.5 - post * 0.5]:
		_box(_panel, Vector3(x, height_m * 0.5, 0.0), Vector3(post, height_m, post), frame)
	for y: float in [post * 0.5, height_m * 0.5, height_m - post * 0.5]:
		_box(_panel, Vector3(0.0, y, 0.0), Vector3(width_m, post, post), frame)
	var step := 0.4
	var x := -width_m * 0.5 + step
	while x < width_m * 0.5 - 0.1:
		_box(_panel, Vector3(x, height_m * 0.5, 0.0), Vector3(0.03, height_m, 0.03), wire)
		x += step
	var y := step
	while y < height_m - 0.1:
		_box(_panel, Vector3(0.0, y, 0.0), Vector3(width_m, 0.03, 0.03), wire)
		y += step


## Parked cars side by side, nose to tail across the opening: a body, a cabin and four wheels each.
func _build_cars() -> void:
	var count := maxi(ceili(width_m / car_length_m - 0.05), 1)
	var length := width_m / float(count)
	var colours: Array[Color] = [Color(0.34, 0.38, 0.45), Color(0.45, 0.4, 0.33), Color(0.3, 0.4, 0.36)]
	var wheel := RoomKit.flat_material(Color(0.1, 0.1, 0.12))
	var glass := RoomKit.flat_material(Color(0.2, 0.22, 0.28))
	var body_h := height_m * 0.62
	for i in count:
		var x := -width_m * 0.5 + length * (float(i) + 0.5)
		var paint := RoomKit.prop_material(colours[i % colours.size()])
		_box(_panel, Vector3(x, body_h * 0.5 + 0.2, 0.0), Vector3(length - 0.25, body_h - 0.2, thickness_m), paint)
		_box(_panel, Vector3(x, body_h + (height_m - body_h) * 0.5, 0.0),
				Vector3((length - 0.25) * 0.55, height_m - body_h, thickness_m * 0.86), glass)
		for wx: float in [-0.32, 0.32]:
			for wz: float in [-1.0, 1.0]:
				_box(_panel, Vector3(x + wx * length, 0.28, wz * thickness_m * 0.5),
						Vector3(0.7, 0.56, 0.12), wheel)


static func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
	var mesh := RoomKit.add_visual_box(parent, pos, size, material)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
