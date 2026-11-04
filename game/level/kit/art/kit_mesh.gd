class_name KitMesh
extends RefCounted
## The environment kit's modules (Milestone 6, KIT; plan D2): procedural meshes on the one trim sheet,
## built from a `kind` and a `size`, so a wall of any length or height fits (the street's run 1 to 17.5 m).
## `KitMesh.build(kind, size)` returns one `ArrayMesh`, cached per (kind, size), with ONE surface whose
## material is `ToonMaterials.trim()` (the shared one). Every kind is centred on the box `size` it fills
## (the node's origin is that box's centre), with its front along +Z where a kind has one, and is at
## most MAX_TRIANGLES triangles (SPEC §10's 5k module).
##
## The faces' UVs are in METRES (u along the face left to right as seen from outside, v up it from the
## module's own bottom, a top face's v running toward -Z), and the vertex colour carries the strip
## (alpha = the row / 255) and a tint (rgb). The shader (game/fx/trim.gdshader) turns that into the
## sheet's repeats, so nothing is ever stretched. A solid module's collider is its block's box: the
## mesh only draws (D1), and a module may draw only what shows.
##
## Kinds: `wall` (brick, a concrete plinth), `floor` (asphalt), `slab` (concrete), `slab_dark` (the
## doorways' interior), `deck` (roof tar), `curb`, `crate`, `skyline` (facade windows), `rail`, `post`,
## `housing` (a shutter's roll housing), `shutter`, `chainlink`, `gate`, `door_frame` (size = the outer
## box, the frame round a dark opening), `window`, `cornice`, `stair_flight` (size = width, rise, run;
## its foot at the front edge, climbing toward -Z). `&"box"` and `&""` are not kinds: M5's plain box.

## The triangle budget of a module (SPEC §10).
const MAX_TRIANGLES := 5000
const KINDS: Array[StringName] = [
	&"wall", &"floor", &"slab", &"slab_dark", &"deck", &"curb", &"door_frame", &"window", &"shutter",
	&"housing", &"rail", &"post", &"stair_flight", &"cornice", &"chainlink", &"gate", &"crate", &"skyline",
]
## No tint: the strip as painted.
const WHITE := Color(1.0, 1.0, 1.0)
## The face proportions of the shaped kinds (metres): a frame's board, a plinth's height and standoff,
## a window's recess, the steps of a flight (the climb LevelStairs' default, so a flight drawn from a
## size alone matches its collider steps).
const FRAME_M := 0.18
const PLINTH_M := 0.6
const STANDOFF_M := 0.05
const RECESS_M := 0.06
const STEP_RISE_M := 0.18
## A plinth is drawn on a face at least this wide and a wall at least this tall (m).
const PLINTH_MIN_WIDTH_M := 1.0
const PLINTH_MIN_HEIGHT_M := 3.0

static var _cache: Dictionary = {}


## The mesh of `kind` at `size`, or null for `&"box"`, `&""` and a kind that does not exist.
static func build(kind: StringName, size: Vector3) -> ArrayMesh:
	if not KINDS.has(kind):
		return null
	size = size.max(Vector3(0.001, 0.001, 0.001))
	var key := "%s|%.3f|%.3f|%.3f" % [kind, size.x, size.y, size.z]
	var cached: ArrayMesh = _cache.get(key)
	if cached != null:
		return cached
	var b := Builder.new()
	match kind:
		&"wall":
			_wall(b, size)
		&"floor":
			b.box(Vector3.ZERO, size, {top = &"asphalt", sides = &"concrete", bottom = &"concrete"})
		&"slab":
			b.box(Vector3.ZERO, size, {all = &"concrete"})
		&"slab_dark":
			b.box(Vector3.ZERO, size, {all = &"dark"})
		&"deck":
			b.box(Vector3.ZERO, size, {top = &"roof_tar", sides = &"concrete", bottom = &"concrete"})
		&"curb":
			b.box(Vector3.ZERO, size, {top = &"concrete", sides = &"kerb", bottom = &"concrete"})
		&"crate":
			_crate(b, size)
		&"skyline":
			_skyline(b, size)
		&"rail":
			b.box(Vector3.ZERO, size, {all = &"metal"})
		&"post":
			_post(b, size)
		&"housing":
			_housing(b, size)
		&"shutter":
			_shutter(b, size)
		&"chainlink":
			_chainlink(b, size)
		&"gate":
			_gate(b, size)
		&"door_frame":
			_door_frame(b, size)
		&"window":
			_window(b, size)
		&"cornice":
			_cornice(b, size)
		&"stair_flight":
			_stairs(b, size, maxi(ceili(size.y / STEP_RISE_M - 0.0001), 1))
	var mesh := b.finish()
	_cache[key] = mesh
	return mesh


## A stair flight of exactly `count` steps (LevelStairs' own count, so the drawn treads are the
## collider steps): `size` is (width, rise, run), the mesh centred on that box.
static func build_stairs(width: float, rise: float, run: float, count: int) -> ArrayMesh:
	var key := "stairs|%.3f|%.3f|%.3f|%d" % [width, rise, run, count]
	var cached: ArrayMesh = _cache.get(key)
	if cached != null:
		return cached
	var b := Builder.new()
	_stairs(b, Vector3(width, rise, run), maxi(count, 1))
	var mesh := b.finish()
	_cache[key] = mesh
	return mesh


## The triangles of a mesh.
static func triangle_count(mesh: ArrayMesh) -> int:
	var total := 0
	for surface in mesh.get_surface_count():
		var indices: PackedInt32Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
		total += indices.size() / 3 if not indices.is_empty() else (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


## Forget every cached mesh (a test of a changed sheet).
static func clear_cache() -> void:
	_cache.clear()


# --- Kinds ------------------------------------------------------------------------------------


static func _wall(b: Builder, size: Vector3) -> void:
	b.box(Vector3.ZERO, size, {sides = &"brick", top = &"concrete", bottom = &"concrete"})
	if size.y < PLINTH_MIN_HEIGHT_M:
		return
	# A concrete plinth on each face wide enough to show one: a board standing off the brick.
	var y := -size.y * 0.5 + PLINTH_M * 0.5
	var s := STANDOFF_M
	if size.x >= PLINTH_MIN_WIDTH_M:
		for side in [-1.0, 1.0]:
			b.box(Vector3(0.0, y, float(side) * (size.z * 0.5 + s * 0.5)), Vector3(size.x, PLINTH_M, s), {all = &"concrete"})
	if size.z >= PLINTH_MIN_WIDTH_M:
		for side in [-1.0, 1.0]:
			b.box(Vector3(float(side) * (size.x * 0.5 + s * 0.5), y, 0.0), Vector3(s, PLINTH_M, size.z), {all = &"concrete"})


static func _crate(b: Builder, size: Vector3) -> void:
	b.box(Vector3.ZERO, size, {all = &"crate"})
	# Corner battens: four uprights a little proud of the planks.
	var batten := minf(0.12, minf(size.x, size.z) * 0.2)
	var s := STANDOFF_M * 0.6
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(Vector3(float(sx) * (size.x * 0.5 - batten * 0.5), 0.0, float(sz) * (size.z * 0.5 + s * 0.5)),
					Vector3(batten, size.y, s), {all = &"trim"})
			b.box(Vector3(float(sx) * (size.x * 0.5 + s * 0.5), 0.0, float(sz) * (size.z * 0.5 - batten * 0.5)),
					Vector3(s, size.y, batten), {all = &"trim"})


static func _skyline(b: Builder, size: Vector3) -> void:
	b.box(Vector3.ZERO, size, {sides = &"facade", top = &"concrete", bottom = &"concrete"})
	var cap := 0.5
	b.box(Vector3(0.0, size.y * 0.5 + cap * 0.5, 0.0), Vector3(size.x + 0.4, cap, size.z + 0.4), {all = &"trim"})


static func _post(b: Builder, size: Vector3) -> void:
	b.box(Vector3.ZERO, size, {all = &"metal"})
	var cap := Vector3(size.x * 1.5, size.x * 0.8, size.z * 1.5)
	b.box(Vector3(0.0, size.y * 0.5 + cap.y * 0.5, 0.0), cap, {all = &"trim"})


static func _housing(b: Builder, size: Vector3) -> void:
	b.box(Vector3.ZERO, size, {all = &"metal"})
	# A lip along the bottom edge, the roll's cover.
	var lip := Vector3(size.x, 0.08, size.z + 0.08)
	b.box(Vector3(0.0, -size.y * 0.5 + lip.y * 0.5, 0.0), lip, {all = &"trim"})


static func _shutter(b: Builder, size: Vector3) -> void:
	# The slats on both faces; the end rails and the bottom bar in metal.
	b.box(Vector3.ZERO, size, {front = &"shutter", back = &"shutter", sides = &"metal", top = &"metal", bottom = &"metal"})
	var rail := 0.12
	var bar := Vector3(size.x, 0.14, size.z + 0.06)
	b.box(Vector3(0.0, -size.y * 0.5 + bar.y * 0.5, 0.0), bar, {all = &"metal"})
	for side in [-1.0, 1.0]:
		b.box(Vector3(float(side) * (size.x * 0.5 - rail * 0.5), 0.0, 0.0), Vector3(rail, size.y, size.z + 0.04), {all = &"metal"})


static func _chainlink(b: Builder, size: Vector3) -> void:
	# The wire is a flat panel seen from both sides; the frame is the posts and the top rail.
	var t := minf(0.1, maxf(size.z, 0.04))
	b.face(Vector3(-size.x * 0.5, -size.y * 0.5, 0.0), Vector3.RIGHT, Vector3.UP, size.x, size.y, &"chainlink", Vector2.ZERO, WHITE)
	b.face(Vector3(size.x * 0.5, -size.y * 0.5, 0.0), Vector3.LEFT, Vector3.UP, size.x, size.y, &"chainlink", Vector2.ZERO, WHITE)
	for side in [-1.0, 1.0]:
		b.box(Vector3(float(side) * (size.x * 0.5 - t * 0.5), 0.0, 0.0), Vector3(t, size.y, t), {all = &"metal"})
	b.box(Vector3(0.0, size.y * 0.5 - t * 0.5, 0.0), Vector3(size.x, t, t), {all = &"metal"})


static func _gate(b: Builder, size: Vector3) -> void:
	# A frame of posts and rails with the wire in it: a sliding chain-link gate.
	var t := 0.14
	var inner_w := size.x - 2.0 * t
	var inner_h := size.y - 2.0 * t
	b.face(Vector3(-inner_w * 0.5, -inner_h * 0.5, 0.0), Vector3.RIGHT, Vector3.UP, inner_w, inner_h, &"chainlink", Vector2.ZERO, WHITE)
	b.face(Vector3(inner_w * 0.5, -inner_h * 0.5, 0.0), Vector3.LEFT, Vector3.UP, inner_w, inner_h, &"chainlink", Vector2.ZERO, WHITE)
	for side in [-1.0, 1.0]:
		b.box(Vector3(float(side) * (size.x * 0.5 - t * 0.5), 0.0, 0.0), Vector3(t, size.y, t), {all = &"metal"})
		b.box(Vector3(0.0, float(side) * (size.y * 0.5 - t * 0.5), 0.0), Vector3(size.x, t, t), {all = &"metal"})
	b.box(Vector3.ZERO, Vector3(t, size.y, t), {all = &"metal"})
	b.box(Vector3.ZERO, Vector3(size.x, t, t), {all = &"metal"})


static func _door_frame(b: Builder, size: Vector3) -> void:
	# The frame round an opening, as a surround of boards standing proud of the wall: two jambs and a
	# lintel in trim, a drip cap above. The opening itself is left empty (the dark recess shows).
	var t := minf(FRAME_M, size.x * 0.12)
	var cap := 0.08
	var d := size.z
	var top := size.y * 0.5
	var bottom := -size.y * 0.5
	var lintel_y := top - cap - t * 0.5
	for side in [-1.0, 1.0]:
		b.box(Vector3(float(side) * (size.x * 0.5 - t * 0.5), (bottom + lintel_y - t * 0.5) * 0.5, 0.0),
				Vector3(t, lintel_y - t * 0.5 - bottom, d), {all = &"trim"})
	b.box(Vector3(0.0, lintel_y, 0.0), Vector3(size.x, t, d), {all = &"trim"})
	b.box(Vector3(0.0, top - cap * 0.5, 0.0), Vector3(size.x + 0.12, cap, d + 0.08), {all = &"concrete"})


static func _window(b: Builder, size: Vector3) -> void:
	# A frame, a pane set back from its front, a mullion cross and a sill below.
	var t := minf(FRAME_M * 0.7, size.x * 0.15)
	var d := size.z
	var sill_h := 0.08
	var body_h := size.y - sill_h
	var body_y := size.y * 0.5 - body_h * 0.5
	var z_front := d * 0.5
	var pane_z := z_front - RECESS_M
	for side in [-1.0, 1.0]:
		b.box(Vector3(float(side) * (size.x * 0.5 - t * 0.5), body_y, 0.0), Vector3(t, body_h, d), {all = &"trim"})
		b.box(Vector3(0.0, body_y + float(side) * (body_h * 0.5 - t * 0.5), 0.0), Vector3(size.x - 2.0 * t, t, d), {all = &"trim"})
	var inner_w := size.x - 2.0 * t
	var inner_h := body_h - 2.0 * t
	b.face(Vector3(-inner_w * 0.5, body_y - inner_h * 0.5, pane_z), Vector3.RIGHT, Vector3.UP, inner_w, inner_h, &"glass", Vector2.ZERO, WHITE)
	var mullion := t * 0.5
	b.box(Vector3(0.0, body_y, pane_z + (z_front - pane_z) * 0.5), Vector3(mullion, inner_h, z_front - pane_z), {all = &"trim"})
	b.box(Vector3(0.0, body_y, pane_z + (z_front - pane_z) * 0.5), Vector3(inner_w, mullion, z_front - pane_z), {all = &"trim"})
	b.box(Vector3(0.0, -size.y * 0.5 + sill_h * 0.5, 0.0), Vector3(size.x + 0.16, sill_h, d + 0.1), {all = &"concrete"})


static func _cornice(b: Builder, size: Vector3) -> void:
	# A stepped moulding: three boards, each standing out further than the one below.
	var h := size.y / 3.0
	for i in 3:
		var out := size.z * (float(i) + 1.0) / 3.0
		b.box(Vector3(0.0, -size.y * 0.5 + h * (float(i) + 0.5), -size.z * 0.5 + out * 0.5), Vector3(size.x, h, out), {front = &"trim", sides = &"trim", top = &"concrete", bottom = &"concrete", back = &"concrete"})


static func _stairs(b: Builder, size: Vector3, count: int) -> void:
	# Treads, risers and the stepped sides of a flight whose foot is the box's front edge (+Z) and that
	# climbs toward -Z. Drawn only: the steps stay LevelStairs' colliders.
	var rise := size.y / float(count)
	var depth := size.z / float(count)
	var x0 := -size.x * 0.5
	var y0 := -size.y * 0.5
	var z0 := size.z * 0.5
	for i in count:
		var z_front := z0 - depth * float(i)
		var top := rise * float(i + 1)
		# The riser, facing +Z, from the previous tread up to this one.
		b.face(Vector3(x0, y0 + rise * float(i), z_front), Vector3.RIGHT, Vector3.UP, size.x, rise, &"concrete", Vector2(0.0, rise * float(i)), WHITE)
		# The tread, from the riser back one step's depth.
		b.face(Vector3(x0, y0 + top, z_front), Vector3.RIGHT, Vector3.FORWARD, size.x, depth, &"concrete", Vector2.ZERO, WHITE)
		# The two sides, from the floor up to the tread.
		b.face(Vector3(x0, y0, z_front - depth), Vector3.BACK, Vector3.UP, depth, top, &"concrete", Vector2.ZERO, WHITE)
		b.face(Vector3(-x0, y0, z_front), Vector3.FORWARD, Vector3.UP, depth, top, &"concrete", Vector2.ZERO, WHITE)


# --- The builder ------------------------------------------------------------------------------


## Accumulates one surface of quads: positions, normals, UVs in metres, the vertex colour (tint and
## strip) and the triangles in Godot's clockwise front-face order.
class Builder:
	var _verts := PackedVector3Array()
	var _normals := PackedVector3Array()
	var _uvs := PackedVector2Array()
	var _colors := PackedColorArray()
	var _indices := PackedInt32Array()

	## A quad whose bottom-left corner is `origin`, running `width` along `right` and `height` along
	## `up` (unit vectors; the face looks along right x up), with its UV at the corner `uv0` and one
	## metre of UV per metre of face.
	func face(origin: Vector3, right: Vector3, up: Vector3, width: float, height: float, strip: StringName, uv0: Vector2, tint: Color) -> void:
		if width <= 0.0 or height <= 0.0:
			return
		var normal := right.cross(up)
		var color := Color(tint.r, tint.g, tint.b, float(TrimSheet.index(strip)) / 255.0)
		var base := _verts.size()
		_verts.append(origin)
		_verts.append(origin + right * width)
		_verts.append(origin + right * width + up * height)
		_verts.append(origin + up * height)
		_uvs.append(uv0)
		_uvs.append(uv0 + Vector2(width, 0.0))
		_uvs.append(uv0 + Vector2(width, height))
		_uvs.append(uv0 + Vector2(0.0, height))
		for i in 4:
			_normals.append(normal)
			_colors.append(color)
		# Counter-clockwise seen from outside is (0, 1, 2), so the clockwise front face is (0, 2, 1).
		_indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))

	## A box of `size` centred at `center`, each face on the strip `faces` names for it: `top`, `bottom`,
	## `front` (+Z), `back` (-Z), `sides` (the four of them), or `all`; the more specific wins.
	func box(center: Vector3, size: Vector3, faces: Dictionary, tint: Color = WHITE) -> void:
		var all: StringName = faces.get("all", &"concrete")
		var sides: StringName = faces.get("sides", all)
		var top: StringName = faces.get("top", all)
		var bottom: StringName = faces.get("bottom", all)
		var front: StringName = faces.get("front", sides)
		var back: StringName = faces.get("back", sides)
		var h := size * 0.5
		var lo := center - h
		var hi := center + h
		face(Vector3(lo.x, lo.y, hi.z), Vector3.RIGHT, Vector3.UP, size.x, size.y, front, Vector2.ZERO, tint)
		face(Vector3(hi.x, lo.y, lo.z), Vector3.LEFT, Vector3.UP, size.x, size.y, back, Vector2.ZERO, tint)
		face(Vector3(hi.x, lo.y, hi.z), Vector3.FORWARD, Vector3.UP, size.z, size.y, sides, Vector2.ZERO, tint)
		face(Vector3(lo.x, lo.y, lo.z), Vector3.BACK, Vector3.UP, size.z, size.y, sides, Vector2.ZERO, tint)
		face(Vector3(lo.x, hi.y, hi.z), Vector3.RIGHT, Vector3.FORWARD, size.x, size.z, top, Vector2.ZERO, tint)
		face(Vector3(lo.x, lo.y, lo.z), Vector3.RIGHT, Vector3.BACK, size.x, size.z, bottom, Vector2.ZERO, tint)

	func finish() -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _verts
		arrays[Mesh.ARRAY_NORMAL] = _normals
		arrays[Mesh.ARRAY_TEX_UV] = _uvs
		arrays[Mesh.ARRAY_COLOR] = _colors
		arrays[Mesh.ARRAY_INDEX] = _indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, ToonMaterials.trim())
		return mesh
