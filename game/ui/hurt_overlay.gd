class_name HurtOverlay
extends Control
## The edge vignette of a hit the player takes (M6 playtest, Game-boy's ruling: he lost half his health
## without noticing anything happen). Child of the HUD, the first one, so the panels draw over it; driven
## by GameHud.advance(). Presentation only: it subscribes to CombatEvents.hit_landed, reads the view's
## transform, and writes no game state.
##
## Each hit with the player as its victim pulses a dark vignette in from the screen's edges, strongest on
## the side the blow came from (the attacker's position against the view: ahead, left, right, or behind, which
## lights the bottom edge) and with `hurt_overlay_even_share` on every edge, with comic impact strokes
## (spikes pointing in) along the struck edge. Its depth and strength grow with the damage
## (`hurt_overlay_full_damage`) and it fades over `hurt_overlay_fade_s`. Its colour is the ink, not red
## (SPEC §10 keeps red for blood, the rear warning and finisher accents): `hurt_overlay_color` and
## `hurt_overlay_stroke_color` are one change away from red. A blocked hit shows a weaker vignette
## (`hurt_overlay_blocked_scale`) and no strokes. Each stroke has an ink rim (`hurt_overlay_outline_width`) so
## it reads on any ground, and a clean hit's bottom edge, the one he cannot see, is inked heavier in proportion to
## how far behind him the blow stood (`hurt_overlay_bottom_ink_gain`, drawn only: the stored strengths stay at 1 or
## below, so no state compounds) and its strokes are never shorter than the health panel's rise
## (`hurt_overlay_bottom_stroke_floor`). All of it is off with Debug's hurt_feel_enabled.

## The four edges, as indices into edge_strength().
enum Edge { LEFT, RIGHT, TOP, BOTTOM }

## Per edge: how strong the vignette is now (0..1, fading).
var _edges: Array[float] = [0.0, 0.0, 0.0, 0.0]
## Per edge: how strong its impact strokes are now (0..1, fading).
var _strokes: Array[float] = [0.0, 0.0, 0.0, 0.0]
## The extra ink the bottom edge takes from a clean blow from behind, fading with the edges: the struck share
## of the edge times (hurt_overlay_bottom_ink_gain - 1). It lives apart from `_edges`, which stay at 1 or
## below, so nothing that reads the edges as a share (the depth's) can grow past 1.
var _bottom_extra: float = 0.0
## The vignette's depth, as a share of the screen height, at the deepest recent hit.
var _depth: float = 0.0
## Picks the strokes' places and lengths (one per hit, so successive hits do not repeat them).
var _seed: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _enter_tree() -> void:
	if not CombatEvents.hit_landed.is_connected(_on_hit_landed):
		CombatEvents.hit_landed.connect(_on_hit_landed)


func _exit_tree() -> void:
	if CombatEvents.hit_landed.is_connected(_on_hit_landed):
		CombatEvents.hit_landed.disconnect(_on_hit_landed)


## Fade the pulses by `delta` seconds of game time and redraw while any is live.
func advance(delta: float) -> void:
	if not is_live():
		return
	var step := maxf(delta, 0.0) / maxf(Tuning.data.hurt_overlay_fade_s, 0.01)
	for i: int in 4:
		_edges[i] = maxf(_edges[i] - step, 0.0)
		_strokes[i] = maxf(_strokes[i] - step, 0.0)
	_bottom_extra = maxf(_bottom_extra - step, 0.0)
	queue_redraw()


## True while any edge still shows something.
func is_live() -> bool:
	for i: int in 4:
		if _edges[i] > 0.0 or _strokes[i] > 0.0:
			return true
	return _bottom_extra > 0.0


## How strong the vignette is on `edge` (an Edge) now, 0..1.
func edge_strength(edge: int) -> float:
	return _edges[edge]


## How strong the vignette on `edge` is drawn now: `edge_strength()`, and on the bottom edge the extra ink of a
## blow from behind (it may exceed 1; the draw clamps the alpha).
func drawn_strength(edge: int) -> float:
	return _edges[edge] + (_bottom_extra if edge == Edge.BOTTOM else 0.0)


## How strong the impact strokes on `edge` (an Edge) are now, 0..1.
func stroke_strength(edge: int) -> float:
	return _strokes[edge]


## The vignette's depth now, as a share of the screen's height.
func depth_share() -> float:
	return _depth


## A hit's strength from its damage: hurt_overlay_min_strength for none, 1 at hurt_overlay_full_damage.
static func strength_for(damage: float) -> float:
	var tuning := Tuning.data
	var share := clampf(damage / maxf(tuning.hurt_overlay_full_damage, 0.01), 0.0, 1.0)
	return lerpf(tuning.hurt_overlay_min_strength, 1.0, share)


## The weights, in Edge order, of one vignette for a blow from `bearing` radians off the view's forward
## (0 ahead, +PI/2 right, PI behind): hurt_overlay_even_share on every edge, the rest on the side.
static func edge_weights(bearing: float) -> Array[float]:
	var even := Tuning.data.hurt_overlay_even_share
	var side := [maxf(-sin(bearing), 0.0), maxf(sin(bearing), 0.0), 0.0, maxf(-cos(bearing), 0.0)]
	var weights: Array[float] = []
	for i: int in 4:
		weights.append(clampf(even + (1.0 - even) * float(side[i]), 0.0, 1.0))
	return weights


## Light up the vignette for `hit` on the player, seen from `view` (the camera's transform).
func on_player_hit(hit: HitInfo, view: Transform3D) -> void:
	var tuning := Tuning.data
	if hit == null or not tuning.hurt_feel_enabled:
		return
	var feel := tuning.hurt_overlay_blocked_scale if hit.blocked else 1.0
	if feel <= 0.0:
		return
	var strength := strength_for(hit.damage) * feel
	var bearing := FirstPersonCamera.hit_bearing(view, hit)
	var weights := edge_weights(bearing)
	for i: int in 4:
		_edges[i] = maxf(_edges[i], weights[i] * strength)
	if not hit.blocked:
		# The bottom edge of a clean hit is inked heavier by the struck share alone (what is past the even
		# share): the blows from behind are the ones he cannot see, and the more behind, the heavier.
		var struck := (weights[Edge.BOTTOM] - tuning.hurt_overlay_even_share) * strength
		_bottom_extra = maxf(_bottom_extra, maxf(struck, 0.0) * (tuning.hurt_overlay_bottom_ink_gain - 1.0))
	if not hit.blocked:
		# Strokes: on the side it came from, and the top edge for a blow from dead ahead.
		var top := tuning.hurt_overlay_top_threshold
		var strokes: Array[float] = [maxf(-sin(bearing), 0.0), maxf(sin(bearing), 0.0),
				maxf(cos(bearing) - top, 0.0) / maxf(1.0 - top, 0.05), maxf(-cos(bearing), 0.0)]
		for i: int in 4:
			_strokes[i] = maxf(_strokes[i], strokes[i] * strength)
	var damage_share := clampf(hit.damage / maxf(tuning.hurt_overlay_full_damage, 0.01), 0.0, 1.0)
	_depth = minf(maxf(_depth * _alive_share(), lerpf(tuning.hurt_overlay_depth_min, tuning.hurt_overlay_depth_max,
			damage_share) * minf(feel * tuning.hurt_overlay_blocked_depth_gain, 1.0)), tuning.hurt_overlay_depth_max)
	_seed += 1
	queue_redraw()


## A hit landed: the player's own, seen from the viewport's camera.
func _on_hit_landed(hit: HitInfo) -> void:
	if hit == null or not is_instance_valid(hit.victim) or not hit.victim.is_in_group(&"player"):
		return
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	# The view without the last hit's kick and roll (the live transform carries them), when the camera has one.
	var view := (hit.victim as Node3D).global_transform
	if camera is FirstPersonCamera:
		view = (camera as FirstPersonCamera).view_transform()
	elif camera != null:
		view = camera.global_transform
	on_player_hit(hit, view)


## What share of the strongest edge is left, at most 1 (the depth fades with it, so an old hit's depth does not
## linger behind a lighter new one, and never grows).
func _alive_share() -> float:
	return minf(maxf(_edges.max(), _strokes.max()), 1.0)


func _draw() -> void:
	if not is_live():
		return
	var tuning := Tuning.data
	var depth_px := _depth * size.y
	for edge: int in 4:
		var strength := drawn_strength(edge)
		if strength > 0.0:
			_draw_vignette(edge, depth_px, tuning.hurt_overlay_color, strength)
		var stroke := _strokes[edge]
		if stroke > 0.0 and tuning.hurt_overlay_strokes > 0:
			_draw_strokes(edge, depth_px, tuning.hurt_overlay_stroke_color, stroke)


## The unit vector pointing into the screen from `edge`, and the one along the edge.
func _axes(edge: int) -> Array[Vector2]:
	match edge:
		Edge.LEFT:
			return [Vector2.RIGHT, Vector2.DOWN]
		Edge.RIGHT:
			return [Vector2.LEFT, Vector2.DOWN]
		Edge.TOP:
			return [Vector2.DOWN, Vector2.RIGHT]
	return [Vector2.UP, Vector2.RIGHT]


## The point on `edge` at `along` (0..1 of its length), moved `inward` pixels into the screen.
func _edge_point(edge: int, along: float, inward: float) -> Vector2:
	var axes := _axes(edge)
	var origin := Vector2.ZERO
	match edge:
		Edge.RIGHT:
			origin = Vector2(size.x, 0.0)
		Edge.BOTTOM:
			origin = Vector2(0.0, size.y)
	var length := size.y if edge == Edge.LEFT or edge == Edge.RIGHT else size.x
	return origin + axes[1] * length * along + axes[0] * inward


## A gradient band along `edge`: the colour's alpha x `strength` at the edge, hurt_overlay_mid_alpha of it
## at hurt_overlay_mid_stop of the depth, nothing at the depth.
func _draw_vignette(edge: int, depth_px: float, color: Color, strength: float) -> void:
	var tuning := Tuning.data
	var stop := tuning.hurt_overlay_mid_stop
	var solid := Color(color.r, color.g, color.b, clampf(color.a * strength, 0.0, 1.0))
	var middle := Color(color.r, color.g, color.b, clampf(color.a * strength * tuning.hurt_overlay_mid_alpha, 0.0, 1.0))
	var clear := Color(color.r, color.g, color.b, 0.0)
	draw_polygon(PackedVector2Array([
		_edge_point(edge, 0.0, 0.0), _edge_point(edge, 1.0, 0.0),
		_edge_point(edge, 1.0, depth_px * stop), _edge_point(edge, 0.0, depth_px * stop),
	]), PackedColorArray([solid, solid, middle, middle]))
	draw_polygon(PackedVector2Array([
		_edge_point(edge, 0.0, depth_px * stop), _edge_point(edge, 1.0, depth_px * stop),
		_edge_point(edge, 1.0, depth_px), _edge_point(edge, 0.0, depth_px),
	]), PackedColorArray([middle, middle, clear, clear]))


## The teeth `edge`'s strokes draw now, in pixels, one entry each: where along the edge it stands (0..1), its
## half-width (a share of the edge), its lean and its length. Set by this hit's seed, none shorter than `floor_px`.
func _stroke_shapes(edge: int, depth_px: float, strength: float, floor_px: float) -> Array[Dictionary]:
	var tuning := Tuning.data
	var count := tuning.hurt_overlay_strokes
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_seed * 4 + edge)
	var shapes: Array[Dictionary] = []
	for i: int in count:
		var along := (float(i) + 0.5 + rng.randf_range(-tuning.hurt_overlay_stroke_jitter, tuning.hurt_overlay_stroke_jitter)) / float(count)
		var half_width := tuning.hurt_overlay_stroke_width / float(count)
		var length := maxf(depth_px * (tuning.hurt_overlay_stroke_len_min + rng.randf() * tuning.hurt_overlay_stroke_len_range) \
				* clampf(strength + tuning.hurt_overlay_stroke_len_floor, 0.0, 1.0), floor_px)
		var lean := rng.randf_range(-tuning.hurt_overlay_stroke_lean, tuning.hurt_overlay_stroke_lean) * half_width
		shapes.append({along = along, half_width = half_width, length = length, lean = lean})
	return shapes


## The lengths in pixels of the teeth `edge` draws now (the draw's own, at the control's size).
func stroke_lengths_px(edge: int) -> Array[float]:
	var lengths: Array[float] = []
	for shape: Dictionary in _stroke_shapes(edge, _depth * size.y, _strokes[edge], _stroke_floor_px(edge)):
		lengths.append(shape.length)
	return lengths


## The shortest tooth of `edge`, in pixels: the bottom's clear the health panel (hurt_overlay_bottom_stroke_floor).
func _stroke_floor_px(edge: int) -> float:
	return Tuning.data.hurt_overlay_bottom_stroke_floor * size.y if edge == Edge.BOTTOM else 0.0


## Comic impact strokes: spikes pointing in from `edge`.
func _draw_strokes(edge: int, depth_px: float, color: Color, strength: float) -> void:
	var tuning := Tuning.data
	var tint := Color(color.r, color.g, color.b, color.a * clampf(strength * tuning.hurt_overlay_stroke_gain, 0.0, 1.0))
	var rim_px := tuning.hurt_overlay_outline_width * size.y
	var rim_color := tuning.hurt_overlay_outline_color
	# The rim fades with the tooth: its alpha is the colour's own times the tooth's share of its colour's alpha.
	# The 0.01 only guards the division by a stroke colour with no alpha (a numerical guard, not a feel number).
	var rim := Color(rim_color.r, rim_color.g, rim_color.b, rim_color.a * tint.a / maxf(color.a, 0.01))
	for shape: Dictionary in _stroke_shapes(edge, depth_px, strength, _stroke_floor_px(edge)):
		var along: float = shape.along
		var half_width: float = shape.half_width
		var tooth := PackedVector2Array([
			_edge_point(edge, along - half_width, 0.0),
			_edge_point(edge, along + half_width, 0.0),
			_edge_point(edge, along + float(shape.lean), float(shape.length)),
		])
		draw_colored_polygon(tooth, tint)
		if rim_px > 0.0:
			# The ink rim along the tooth's two slanted sides (the base is on the screen's edge).
			draw_polyline(PackedVector2Array([tooth[0], tooth[2], tooth[1]]), rim, rim_px, true)
