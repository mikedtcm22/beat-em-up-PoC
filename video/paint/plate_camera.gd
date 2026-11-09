class_name VideoPlateCamera
extends RefCounted
## A plate's camera (round 5, R5-PAINT): where a plate was captured from, as the JSON the capture wrote next to the picture
## (`assets/video/plates/<shot key>/plate_<n>.json`): the world transform, the horizontal FOV (the cine cameras keep the width), the size, the clip planes
## and the metres the depth picture spans. The projection here is the one the shader (plate_project.gdshader) does, so the tests and the capture agree.

var origin: Vector3 = Vector3.ZERO
var basis: Basis = Basis.IDENTITY
var fov_deg: float = 75.0
var size: Vector2i = Vector2i(2560, 1440)
var near: float = 0.05
var far: float = 4000.0
var depth_far_m: float = 200.0


## The camera of a Camera3D's pose, a horizontal FOV and a size.
static func from_pose(xform: Transform3D, p_fov_deg: float, p_size: Vector2i, p_near: float = 0.05, p_far: float = 4000.0, p_depth_far_m: float = 200.0) -> VideoPlateCamera:
	var cam := VideoPlateCamera.new()
	cam.origin = xform.origin
	cam.basis = xform.basis.orthonormalized()
	cam.fov_deg = p_fov_deg
	cam.size = p_size
	cam.near = p_near
	cam.far = p_far
	cam.depth_far_m = p_depth_far_m
	return cam


## The camera of the JSON `text` (a plate_<n>.json), or null when it does not parse.
static func from_json(text: String) -> VideoPlateCamera:
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		return null
	var d: Dictionary = data
	for needed in ["origin", "basis", "fov_deg", "size"]:
		if not d.has(needed):
			return null
	var cam := VideoPlateCamera.new()
	var o: Array = d["origin"]
	cam.origin = Vector3(o[0], o[1], o[2])
	var b: Array = d["basis"]
	cam.basis = Basis(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), Vector3(b[6], b[7], b[8]))
	cam.fov_deg = float(d["fov_deg"])
	var s: Array = d["size"]
	cam.size = Vector2i(int(s[0]), int(s[1]))
	cam.near = float(d.get("near", cam.near))
	cam.far = float(d.get("far", cam.far))
	cam.depth_far_m = float(d.get("depth_far_m", cam.depth_far_m))
	return cam


## The JSON of this camera (the capture writes it; `from_json` reads it back). `extra` is merged in (the shot, the frame, ...).
func to_json(extra: Dictionary = {}) -> String:
	var d := {
		"origin": [origin.x, origin.y, origin.z],
		"basis": [basis.x.x, basis.x.y, basis.x.z, basis.y.x, basis.y.y, basis.y.z, basis.z.x, basis.z.y, basis.z.z],
		"fov_deg": fov_deg,
		"keep_aspect": "width",
		"size": [size.x, size.y],
		"near": near,
		"far": far,
		"depth_far_m": depth_far_m,
	}
	d.merge(extra, true)
	return JSON.stringify(d, "\t")


## The world to view matrix, as a Projection (a mat4 the shader takes).
func view_projection() -> Projection:
	return Projection(Transform3D(basis, origin).affine_inverse())


## The tangent of the half angles: x from the horizontal FOV, y from the frame's shape.
func tan_half() -> Vector2:
	var tx := tan(deg_to_rad(fov_deg) * 0.5)
	return Vector2(tx, tx * float(size.y) / float(size.x))


## The uv (0..1, y down) a world point lands on in this camera's picture, and whether it is in front of the camera. Not clamped.
func project(world: Vector3) -> Vector3:
	var v := Transform3D(basis, origin).affine_inverse() * world
	if v.z >= -0.001:
		return Vector3(0.0, 0.0, 0.0)
	var t := tan_half()
	return Vector3(v.x / (-v.z) / t.x * 0.5 + 0.5, 0.5 - v.y / (-v.z) / t.y * 0.5, -v.z)


## True when the uv is inside the picture.
static func uv_inside(uv: Vector2) -> bool:
	return uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0


## The view-depth number (0..65535) the depth picture holds for `z` metres, and back. 65535 is the sky.
static func encode_depth(z: float, p_depth_far_m: float) -> int:
	return int(floorf(clampf(z / p_depth_far_m, 0.0, 1.0) * 65534.0 + 0.5))


static func decode_depth(value: int, p_depth_far_m: float) -> float:
	return INF if value >= 65535 else float(value) / 65534.0 * p_depth_far_m
