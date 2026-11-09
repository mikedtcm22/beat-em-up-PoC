class_name CineCard
extends Resource
## A flat dark foreground mass of a cine shot (P1.md, R5-SHOTS): a silhouette polygon standing in a vertical plane (a fire escape's rail, a
## building corner, a roof edge with its chimneys), drawn as one unlit colour. It is the "dark foreground shape" of the references' wides and the
## foreground layer of a multiplane shot (t14), and it may drift at its own speed (m/s along the world axes, on the shot clock, never `TIME`).
## Video staging only: the game has none. The plate capture keeps it: its name starts with `NAME_PREFIX`, which the plate look does not hide.

const NAME_PREFIX := "CineCard"

## The outline in the card's plane, in metres: x to the right as the camera sees it, y up. At least three points; any simple polygon.
@export var points: PackedVector2Array = PackedVector2Array([Vector2(-1, 0), Vector2(1, 0), Vector2(1, 2), Vector2(-1, 2)])
## Where the plane's origin stands (section space), and the plane's yaw in degrees: 0 faces +Z (a camera looking along -Z sees its front).
@export var position: Vector3 = Vector3.ZERO
@export_range(-180.0, 180.0) var yaw_deg: float = 0.0
## The fill (unlit): a deep colour near the scene's darks, never black.
@export var color: Color = Color(0.03, 0.03, 0.06, 1.0)
## The drift on the shot clock (m/s, world axes).
@export var drift: Vector3 = Vector3.ZERO


## The card's mesh, in the plane's own space (a two-sided triangulation of `points`), or null for a degenerate outline.
static func make_mesh(p_points: PackedVector2Array) -> ArrayMesh:
	var indices := Geometry2D.triangulate_polygon(p_points)
	if indices.is_empty():
		return null
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for point in p_points:
		vertices.append(Vector3(point.x, point.y, 0.0))
		normals.append(Vector3.BACK)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The node for this card under a section at world `origin`, at clock time `clock_s`.
func build(origin: Vector3, index: int, clock_s: float = 0.0) -> MeshInstance3D:
	var mesh := make_mesh(points)
	if mesh == null:
		return null
	var item := MeshInstance3D.new()
	item.name = "%s%d" % [NAME_PREFIX, index]
	item.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	item.material_override = material
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	place(item, origin, clock_s)
	return item


## Put `item` where the card is at `clock_s` (a child of the level, which stands at the world's origin; `origin` is the section's world position).
func place(item: Node3D, origin: Vector3, clock_s: float) -> void:
	item.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), origin + position + drift * clock_s)
