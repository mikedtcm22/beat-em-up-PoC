class_name ComicSprite
extends Sprite3D
## One world-space comic effect, pooled and driven by VfxDirector.advance() (it never
## processes by itself). Three motions:
##   POP     a burst, a word, a spark or a splash: pops in at a point (a little small, past
##           full size, back), holds and fades, always facing the active camera;
##   THROWN  a blood droplet, a spit drop or a tooth: flies under gravity from the contact,
##           facing the camera, a droplet's tail trailing its flight on screen;
##   LYING   a blood splat on the ground (or a wall), flat along the surface, lit.
## Sizes are widths in meters. Facing effects are capped to Tuning.vfx_max_view_share of
## the view's width at their depth and kept Tuning.vfx_min_camera_dist_m off the lens, so
## a hit a meter from the first-person lens never fills the screen; popping effects are at
## least Tuning.vfx_min_view_share of it, so hits seen from afar stay readable. Effects of
## one kind (the three bursts, the three word sizes, the block sparks) share one factor for
## that, set by the smallest (the floor) and the largest (the cap) of the kind, so the
## light, heavy and finisher sizes keep their ratios at every distance; the cap wins.

enum Motion { POP, THROWN, LYING }

## Effect name (a VfxArt texture name, or &"word" for lettering).
var kind: StringName = &""
var motion: Motion = Motion.POP
## Seconds since the effect started, and how long it lives.
var age: float = 0.0
var life: float = 0.2
## Full width in meters (before the view cap and the pop).
var size_m: float = 0.3
## World point the effect sits at (POP, LYING) or the droplet's current position (THROWN).
var anchor: Vector3 = Vector3.ZERO
## Offset in the view plane, meters (x right, y up), and how far it drifts up over its life.
var screen_offset: Vector2 = Vector2.ZERO
var rise_m: float = 0.0
## Roll in the view plane (radians) and its rate (radians per second).
var roll: float = 0.0
var spin: float = 0.0
## POP: whether it pops in; the share of its life spent fading at the end.
var pops: bool = true
var fade_share: float = 0.3
## THROWN: velocity (m/s) and gravity (m/s²). With `trail`, the texture's top (a droplet's
## tail) turns away from the flight on screen.
var velocity: Vector3 = Vector3.ZERO
var gravity: float = 0.0
var trail: bool = false
## The smallest and largest size of this effect's kind (meters; 0: its own size), which
## set the shared floor and cap factor (see the class doc).
var kind_min_m: float = 0.0
var kind_max_m: float = 0.0
## POP: kept whole inside the view, Tuning.vfx_word_view_margin from its edges, while its
## contact (the anchor) is in front of the camera and at most `clamp_reach_deg` outside the
## view: degrees beyond its side edges (x) and its top or bottom edge (y). Farther out, or
## behind the camera, it stays at its contact.
var keep_in_view: bool = false
var clamp_reach_deg: Vector2 = Vector2.ZERO
## POP: the hit landed at or behind the lens (on the first-person player): the effect is
## brought out ahead to the minimum distance and always kept in view.
var at_lens: bool = false
## THROWN: leaves a blood splat where it lands (droplets); otherwise it lies where it lands
## (a tooth) or vanishes (spit).
var leaves_splat: bool = false
var lies_on_landing: bool = false
## LYING: the surface normal it lies along.
var normal: Vector3 = Vector3.UP
## The width drawn on the last place(), after the cap and the pop (tests).
var drawn_width: float = 0.0


func _init() -> void:
	top_level = true
	double_sided = true
	visible = false


## Set the texture and size the sprite so the texture's long side is 1 m at scale 1.
func set_art(tex: Texture2D) -> void:
	texture = tex
	if tex:
		pixel_size = 1.0 / maxf(1.0, maxf(tex.get_width(), tex.get_height()))


## Advance `dt` seconds of effect time. Returns false once the effect is over.
func step(dt: float) -> bool:
	age += dt
	if age >= life:
		return false
	if motion == Motion.THROWN:
		velocity.y -= gravity * dt
		anchor += velocity * dt
		roll += spin * dt
	return true


## Place, turn, size and fade for `camera` (the active camera, or null to hide).
func place(camera: Camera3D) -> void:
	if motion == Motion.LYING:
		_place_lying()
		return
	if camera == null:
		visible = false
		return
	var cam := camera.global_transform.orthonormalized()
	var right := cam.basis.x
	var up := cam.basis.y
	var t := clampf(age / maxf(life, 0.001), 0.0, 1.0)
	var pos := anchor + right * screen_offset.x + up * (screen_offset.y + rise_m * t)
	var to := pos - cam.origin
	var depth := -cam.basis.z.dot(to)
	var min_depth := Tuning.data.vfx_min_camera_dist_m
	if at_lens:
		# A hit on the first-person player lands at the lens, even a little behind it: bring
		# it out to the minimum distance straight ahead, keeping its offset across the view.
		if depth < min_depth:
			pos += -cam.basis.z * (min_depth - depth)
			depth = min_depth
	elif depth < 0.02:
		visible = false
		return
	elif depth < min_depth:
		to *= min_depth / depth
		pos = cam.origin + to
		depth = min_depth
	var view_w := VfxDirector.view_width_at(camera, depth)
	drawn_width = size_m * size_factor(view_w) * pop_factor()
	if keep_in_view and (at_lens or contact_near_view(camera)):
		pos = _inside_view(cam, pos, depth, view_w, VfxDirector.view_aspect(camera))
	var angle := roll
	if trail and velocity.length_squared() > 0.0001:
		var v := cam.basis.inverse() * velocity
		angle = atan2(-v.y, -v.x) - PI * 0.5
	var basis := cam.basis * Basis(Vector3.BACK, angle)
	global_transform = Transform3D(Basis(basis.x * drawn_width, basis.y * drawn_width, basis.z * drawn_width), pos)
	modulate.a = fade_alpha()
	visible = drawn_width > 0.0


## The factor on size_m that keeps this effect's kind between the view-share floor and cap,
## for a view `view_w` meters wide at its depth (1 when the kind fits as it is).
func size_factor(view_w: float) -> float:
	var smallest := kind_min_m if kind_min_m > 0.0 else size_m
	var largest := maxf(kind_max_m if kind_max_m > 0.0 else size_m, size_m)
	if smallest <= 0.0 or largest <= 0.0:
		return 1.0
	var factor := 1.0
	if motion == Motion.POP:
		factor = maxf(factor, Tuning.data.vfx_min_view_share * view_w / smallest)
	return minf(factor, Tuning.data.vfx_max_view_share * view_w / largest)


## True when the contact (the anchor) is in front of `camera` and no farther outside its
## view than clamp_reach_deg.
func contact_near_view(camera: Camera3D) -> bool:
	var cam := camera.global_transform.orthonormalized()
	var local := cam.basis.inverse() * (anchor - cam.origin)
	var depth := -local.z
	if depth < 0.02:
		return false
	var view_w := VfxDirector.view_width_at(camera, depth)
	var half := Vector2(view_w, view_w / maxf(VfxDirector.view_aspect(camera), 0.01)) * 0.5
	var beyond_x := rad_to_deg(atan2(absf(local.x), depth) - atan2(half.x, depth))
	var beyond_y := rad_to_deg(atan2(absf(local.y), depth) - atan2(half.y, depth))
	return beyond_x <= clamp_reach_deg.x and beyond_y <= clamp_reach_deg.y


## Size multiplier of the pop-in: from Tuning.vfx_pop_start up to vfx_pop_peak over the
## first half of vfx_pop_s, back to 1 over the second half. 1 when it doesn't pop.
func pop_factor() -> float:
	var pop_s := Tuning.data.vfx_pop_s
	if not pops or pop_s <= 0.0 or age >= pop_s:
		return 1.0
	var u := age / pop_s
	if u < 0.5:
		return lerpf(Tuning.data.vfx_pop_start, Tuning.data.vfx_pop_peak, ease(u * 2.0, 0.5))
	return lerpf(Tuning.data.vfx_pop_peak, 1.0, ease((u - 0.5) * 2.0, 2.0))


## Opacity: full, then fading over the last `fade_share` of the life.
func fade_alpha() -> float:
	if fade_share <= 0.0:
		return 1.0
	var left := 1.0 - age / maxf(life, 0.001)
	return clampf(left / fade_share, 0.0, 1.0)


## `pos` (at `depth`) moved so the whole sprite sits inside the view, `view_w` wide at that
## depth with screen aspect `aspect`.
func _inside_view(cam: Transform3D, pos: Vector3, depth: float, view_w: float, aspect: float) -> Vector3:
	var local := cam.basis.inverse() * (pos - cam.origin)
	var margin := Tuning.data.vfx_word_view_margin * view_w
	var half := Vector2(view_w, view_w / maxf(aspect, 0.01)) * 0.5
	var tex_aspect := 1.0
	if texture:
		tex_aspect = float(texture.get_height()) / maxf(1.0, texture.get_width())
	var extent := Vector2(drawn_width, drawn_width * tex_aspect) * 0.5 + Vector2(margin, margin)
	var limit := (half - extent).max(Vector2.ZERO)
	local.x = clampf(local.x, -limit.x, limit.x)
	local.y = clampf(local.y, -limit.y, limit.y)
	local.z = -depth
	return cam.origin + cam.basis * local


func _place_lying() -> void:
	var n := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	var side := n.cross(Vector3.FORWARD if absf(n.y) > 0.9 else Vector3.UP).normalized()
	var basis := Basis(side, n.cross(side), n) * Basis(Vector3.BACK, roll)
	drawn_width = size_m
	global_transform = Transform3D(Basis(basis.x * size_m, basis.y * size_m, basis.z * size_m), anchor)
	modulate.a = fade_alpha()
	visible = size_m > 0.0
