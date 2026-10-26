class_name VfxDirector
extends Node3D
## Comic VFX and damage looks (Spec §6: "Comic effects", "Damage you can see" and the VFX
## row of the tier table; Milestone 2 WP2). Presentation only: it subscribes to
## CombatEvents, reads actors, the active camera and the world's static geometry (where
## droplets land), and never writes game state. The damage look changes rig materials only.
##
## Each clean hit, by tier (every size, time and chance is in the Tuning group "VFX"):
##   light     a small burst; a small word at vfx_word_chance_light (0: the spec's table
##             gives light hits a burst only);
##   heavy     a medium burst, a medium word, blood: a splash at the contact and droplets
##             that leave splats where they land;
##   finisher  a large burst, a large word, blood, radial speed lines, the impact frame,
##             and on the head spit and (by chance) a tooth.
## A blocked hit gets a block spark, a parry spark (perfect block) or a guard-break burst
## instead. A hit that armor absorbed (hit.armor_absorbed: a light hit on the Bruiser or the boss)
## gets a grey spark (the block spark's art, tinted) instead of the tier's burst, with no word and
## no blood: it registered and did nothing. Words are picked at random from their tier's pool, never the same word twice
## in a row. The player's real lunges (a move with its own lunge, such as the flying kick,
## carrying the player Tuning.vfx_lunge_lines_min_m; not the magnetism step-in of jabs and
## chain hits) get light speed lines (first person only).
##
## Damage looks: an enemy's materials step from clean to bruised to bloodied as its health
## falls to Tuning.vfx_bruised_at and vfx_bloodied_at (HumanoidRig.set_damage_look()).
##
## World effects are pooled ComicSprites that face the active camera, capped in size so a
## hit a meter from the first-person lens never fills the view; each kind's tiers keep
## their size ratios. A hit's burst, splash, spark and word sit at the contact, pulled
## inside the view when the contact is just outside it (Tuning.vfx_clamp_reach_side_deg
## and _low_deg: a knee or a stomp under the first-person view); a hit behind the camera or farther
## out shows nothing on screen. Hits on the player land at the lens and always show.
## Time: they run on sim time (TimeController.sim_scale(): slow-mo and the debug time
## scale stretch them, hitstop does not freeze them, so a word pops during the freeze); the
## impact frame and the speed lines' flicker count real frames. advance() drives
## everything; _process() calls it, after the cameras have placed this frame's view
## (process_priority), and tests may call it directly. Every effect texture is loaded when
## the director is created (VfxArt.preload_all()), never in a hit's frame, and in a window
## the director draws each effect material once at load too (begin_warm_up()): the first
## comic sprite and the first finisher's impact frame otherwise build their materials and
## compile their pipelines on the hit's frame (8-16 ms, a dropped frame).

const GROUP := &"vfx_director"
## Canvas layers: the speed lines draw under the HUD (layer 10), the impact frame over it.
const LINES_LAYER := 5
const FLASH_LAYER := 20
## Draw order of the world effects (Sprite3D.render_priority): the blood splash behind the
## burst (its droplets ring it), then sparks and particles, then words on top.
const PRIORITY_SPRAY := 0
const PRIORITY_BURST := 1
const PRIORITY_SPLASH := 2
const PRIORITY_WORD := 3
## The warm-up sprites (begin_warm_up()) sit this far ahead of the camera, this wide and
## this opaque: in the view, so they are drawn, but under a pixel and faint enough that
## nothing shows. Technical values, not feel.
const WARM_DISTANCE_M := 1.0
const WARM_SIZE_M := 0.001
const WARM_ALPHA := 0.02

## Word pools per tier. Every word has a lettering PNG (VfxArt.word_texture()).
@export var light_words: PackedStringArray = PackedStringArray(["POW", "BAM", "SMAK"])
@export var heavy_words: PackedStringArray = PackedStringArray(["WHAM", "THUD", "BOFF", "SMAK", "BAM"])
@export var finisher_words: PackedStringArray = PackedStringArray(["KRAK", "CRUNCH", "WHUMP", "KAPOW"])

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var speed_lines: SpeedLines
var impact_frame: ImpactFrame
## The last word shown; the next is never the same.
var last_word: String = ""

var _live: Array[ComicSprite] = []
var _pool: Array[ComicSprite] = []
## The warm-up (begin_warm_up()): the sprites still to be shown and the ones on screen for
## their frame, and whether the impact frame's pixel is still to be drawn.
var _warm_sprites_pending: bool = false
var _warm_sprites: Array[ComicSprite] = []
var _warm_impact_pending: bool = false
## The player attack being watched for a lunge (first person), where it started, and
## whether it already showed its lines.
var _lunge_actor: CombatActor
var _lunge_move: MoveData
var _lunge_from: Vector3 = Vector3.ZERO
var _lunge_shown: bool = false
var _ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()


func _init() -> void:
	name = &"VfxDirector"
	add_to_group(GROUP)
	# After the cameras, so effects are placed against the view being rendered this frame.
	process_priority = CameraDirector.PROCESS_PRIORITY + 1
	VfxArt.preload_all()
	rng.randomize()
	_ray.collision_mask = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	_ray.collide_with_areas = false
	var lines_layer := CanvasLayer.new()
	lines_layer.name = &"SpeedLinesLayer"
	lines_layer.layer = LINES_LAYER
	speed_lines = SpeedLines.new()
	speed_lines.name = &"SpeedLines"
	speed_lines.rng = rng
	lines_layer.add_child(speed_lines)
	add_child(lines_layer)
	var flash_layer := CanvasLayer.new()
	flash_layer.name = &"ImpactFrameLayer"
	flash_layer.layer = FLASH_LAYER
	impact_frame = ImpactFrame.new()
	impact_frame.name = &"ImpactFrame"
	flash_layer.add_child(impact_frame)
	add_child(flash_layer)


func _ready() -> void:
	begin_warm_up()


func _enter_tree() -> void:
	_connect(CombatEvents.hit_landed, _on_hit_landed)
	_connect(CombatEvents.attack_started, _on_attack_started)
	_connect(CombatEvents.health_changed, _on_health_changed)
	_connect(Tuning.changed, _on_tuning_changed)


func _exit_tree() -> void:
	for pair: Array in [[CombatEvents.hit_landed, _on_hit_landed], [CombatEvents.attack_started, _on_attack_started],
			[CombatEvents.health_changed, _on_health_changed], [Tuning.changed, _on_tuning_changed]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


func _process(delta: float) -> void:
	advance(delta)


## Step every effect by `real_dt` real seconds (effects take TimeController.sim_scale() of it).
func advance(real_dt: float) -> void:
	var dt := real_dt * TimeController.sim_scale()
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	for i: int in range(_live.size() - 1, -1, -1):
		var sprite := _live[i]
		var from := sprite.anchor
		if not sprite.step(dt):
			_retire(i)
			continue
		if sprite.motion == ComicSprite.Motion.THROWN and sprite.velocity != Vector3.ZERO and not _land(sprite, from):
			_retire(i)
			continue
		sprite.place(camera)
	_watch_lunge(camera)
	speed_lines.keep_clear = _effect_rects(camera) if speed_lines.is_active() else ([] as Array[Rect2])
	speed_lines.advance(dt, real_dt)
	impact_frame.advance(real_dt)
	_step_warm_up(camera)


## Schedule the first-use warm-up, once the director has an active camera and `windowed`
## (a window is open: not headless, which has no renderer to warm, so the tests' frames stay
## as they are; the director calls this itself in _ready()). Godot builds a comic sprite's
## material and compiles its pipeline the first time one is drawn, and so for the impact
## frame's canvas material, which cost the first hit 8-16 ms and the first finisher 1-3 ms
## more. So, once and for one rendered frame:
##   - one ComicSprite of each material variant the effects use (a popping effect: no depth
##     test; a thrown droplet: the plain one; a splat lying on a surface: shaded) is shown
##     tiny and faint in front of the camera, then goes to the pool (a first hit also finds
##     sprites built);
##   - the impact frame draws its material on one pixel (ImpactFrame.warm()), only while the
##     photosensitivity toggle (Tuning.impact_frame_enabled) is on: with it off no ink is
##     ever drawn, and the pixel waits for the toggle to go on.
## Nothing is visible at load. Returns `windowed`.
func begin_warm_up(windowed: bool = DisplayServer.get_name() != "headless") -> bool:
	_warm_sprites_pending = windowed
	_warm_impact_pending = windowed
	return windowed


# --- Spawning (public for tests and bots) ------------------------------------------------


## Pop effect `kind` (a VfxArt texture, or `tex`) at `point`: `size_m` wide, living
## `seconds`. Returns it, or null when it would be invisible.
func spawn_pop(kind: StringName, point: Vector3, size_m: float, seconds: float, priority: int,
		tex: Texture2D = null) -> ComicSprite:
	var art := tex if tex else VfxArt.texture(kind)
	if art == null or size_m <= 0.0 or seconds <= 0.0:
		return null
	var sprite := _acquire(kind, art, ComicSprite.Motion.POP)
	sprite.anchor = point
	sprite.size_m = size_m
	sprite.life = seconds
	sprite.render_priority = priority
	sprite.no_depth_test = true
	sprite.roll = rng.randf_range(0.0, TAU)
	sprite.fade_share = Tuning.data.vfx_burst_fade_share
	return sprite


## The grey spark of a hit that armor absorbed, at its contact: the block spark's art, tinted
## armor_spark_grey, armor_spark_m wide, living as long as a block's effects. Returns it.
func spawn_armor_spark(hit: HitInfo) -> ComicSprite:
	var t := Tuning.data
	var pop := spawn_pop(&"block_spark", hit.contact_point, t.armor_spark_m * t.vfx_scale, t.vfx_block_fx_s, PRIORITY_SPLASH)
	if pop == null:
		return null
	var grey := t.armor_spark_grey
	pop.modulate = Color(grey, grey, grey, 1.0)
	_set_kind_sizes(pop, [t.armor_spark_m])
	_frame(pop, _on_player(hit))
	return pop


## A comic word for `tier` at `point`: lifted above the contact and to a side on screen,
## tilted, drifting up as it fades. `on_player`: the hit landed on the first-person player.
func spawn_word(tier: CombatTypes.HitTier, point: Vector3, on_player: bool = false) -> ComicSprite:
	var word := pick_word(tier)
	if word == "":
		return null
	# One word at a time: a new beat ends the last word.
	for old: ComicSprite in live_effects(&"word"):
		old.age = old.life
	var t := Tuning.data
	var sizes: Array[float] = [t.vfx_word_small_m, t.vfx_word_medium_m, t.vfx_word_large_m]
	var width: float = sizes[tier] * t.vfx_scale
	var sprite := spawn_pop(&"word", point, width, t.vfx_word_s, PRIORITY_WORD, VfxArt.word_texture(word))
	if sprite == null:
		return null
	_set_kind_sizes(sprite, sizes)
	_frame(sprite, on_player)
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	sprite.screen_offset = Vector2(side * t.vfx_word_side * width, t.vfx_word_lift * width)
	sprite.rise_m = t.vfx_word_rise_m
	sprite.roll = -side * deg_to_rad(rng.randf_range(minf(t.vfx_word_tilt_min_deg, t.vfx_word_tilt_deg), t.vfx_word_tilt_deg))
	sprite.fade_share = t.vfx_word_fade_share
	sprite.set_meta(&"word", word)
	return sprite


## A random word from `tier`'s pool that is not the last word shown ("" if the pool is empty).
func pick_word(tier: CombatTypes.HitTier) -> String:
	var pool: PackedStringArray = [light_words, heavy_words, finisher_words][tier]
	var choices := PackedStringArray()
	for word: String in pool:
		if word != last_word:
			choices.append(word)
	if choices.is_empty():
		choices = pool
	if choices.is_empty():
		return ""
	last_word = choices[rng.randi() % choices.size()]
	return last_word


## Blood for a clean hit: a splash at the contact and droplets thrown along the hit and up
## that leave splats where they land.
func spawn_blood(hit: HitInfo) -> void:
	var t := Tuning.data
	var finisher := hit.tier == CombatTypes.HitTier.FINISHER
	var splash := spawn_pop(&"blood_spray", hit.contact_point, t.vfx_blood_spray_m * t.vfx_scale, t.vfx_blood_spray_s,
			PRIORITY_SPRAY)
	if splash:
		_frame(splash, _on_player(hit))
	var count := t.vfx_blood_drops_finisher if finisher else t.vfx_blood_drops_heavy
	for i in count:
		var drop := _throw(&"blood_drop", hit, t.vfx_blood_drop_m, t.vfx_blood_speed, t.vfx_particle_s)
		if drop:
			drop.trail = true
			drop.leaves_splat = true


## Head finishers: spit drops and, by chance, a tooth that lies where it lands.
func spawn_spit_and_tooth(hit: HitInfo) -> void:
	var t := Tuning.data
	for i in t.vfx_spit_drops:
		var spit := _throw(&"spit", hit, t.vfx_spit_drop_m, t.vfx_blood_speed, t.vfx_spit_s)
		if spit:
			spit.trail = true
	if _chance(t.vfx_tooth_chance):
		var tooth := _throw(&"tooth", hit, t.vfx_tooth_m, t.vfx_blood_speed, t.vfx_particle_s)
		if tooth:
			tooth.spin = rng.randf_range(-1.0, 1.0) * TAU * t.vfx_tooth_spin
			tooth.lies_on_landing = true


## A blood splat lying on a surface at `point` with `normal`.
func spawn_splat(point: Vector3, normal: Vector3) -> ComicSprite:
	var t := Tuning.data
	if t.vfx_blood_splat_max <= 0 or t.vfx_blood_splat_s <= 0.0:
		return null
	# The oldest splats give way (retired on the next advance()).
	var lying := live_effects(&"", ComicSprite.Motion.LYING).filter(
			func(s: ComicSprite) -> bool: return s.age < s.life)
	while lying.size() >= t.vfx_blood_splat_max:
		var oldest: ComicSprite = lying.pop_front()
		oldest.age = oldest.life
		oldest.visible = false
	var kind := VfxArt.BLOOD_SPLATS[rng.randi() % VfxArt.BLOOD_SPLATS.size()]
	var sprite := _acquire(kind, VfxArt.texture(kind), ComicSprite.Motion.LYING)
	sprite.normal = normal
	sprite.anchor = point + normal * (0.004 + 0.0004 * (lying.size() % 8))
	sprite.size_m = t.vfx_blood_splat_m * t.vfx_scale * _jitter(t.vfx_particle_size_jitter)
	sprite.life = t.vfx_blood_splat_s
	sprite.roll = rng.randf_range(0.0, TAU)
	sprite.fade_share = t.vfx_burst_fade_share
	sprite.pops = false
	sprite.shaded = true
	sprite.render_priority = 0
	return sprite


## Live effects, optionally only of `kind` and/or `motion` (-1 = any). Oldest first.
func live_effects(kind: StringName = &"", motion: int = -1) -> Array[ComicSprite]:
	var out: Array[ComicSprite] = []
	for sprite: ComicSprite in _live:
		if (kind == &"" or sprite.kind == kind) and (motion < 0 or sprite.motion == motion):
			out.append(sprite)
	return out


## Remove every effect at once (tests, bots between acts).
func clear() -> void:
	for i: int in range(_live.size() - 1, -1, -1):
		_retire(i)
	speed_lines.time_left = 0.0
	speed_lines.visible = false
	impact_frame.visible = false


## Width over height of `camera`'s view.
static func view_aspect(camera: Camera3D) -> float:
	var vp := camera.get_viewport()
	var rect := vp.get_visible_rect().size if vp else Vector2(16.0, 9.0)
	return rect.x / maxf(rect.y, 1.0)


## Width in meters the view of `camera` spans at `depth` meters in front of it.
static func view_width_at(camera: Camera3D, depth: float) -> float:
	var aspect := view_aspect(camera)
	var span := camera.size if camera.projection == Camera3D.PROJECTION_ORTHOGONAL \
		else 2.0 * depth * tan(deg_to_rad(camera.fov) * 0.5)
	return span if camera.keep_aspect == Camera3D.KEEP_WIDTH else span * aspect


# --- Events ----------------------------------------------------------------------------


func _on_hit_landed(hit: HitInfo) -> void:
	if hit == null:
		return
	var t := Tuning.data
	var point := hit.contact_point
	# Hits on the player land at or above the first-person lens: keep their effects in view.
	var on_player := _on_player(hit)
	var pop: ComicSprite
	if hit.blocked:
		var sparks: Array[float] = [t.vfx_block_spark_m, t.vfx_parry_spark_m, t.vfx_guard_break_m]
		if hit.perfect_block:
			pop = spawn_pop(&"parry_spark", point, sparks[1] * t.vfx_scale, t.vfx_block_fx_s, PRIORITY_SPLASH)
		elif hit.guard_broken:
			pop = spawn_pop(&"guard_break", point, sparks[2] * t.vfx_scale, t.vfx_block_fx_s, PRIORITY_SPLASH)
		else:
			pop = spawn_pop(&"block_spark", point, sparks[0] * t.vfx_scale, t.vfx_block_fx_s, PRIORITY_SPLASH)
		if pop:
			_set_kind_sizes(pop, sparks)
			_frame(pop, on_player)
		return
	if hit.armor_absorbed:
		spawn_armor_spark(hit)
		return
	var tier := hit.tier
	var bursts: Array[float] = [t.vfx_burst_small_m, t.vfx_burst_medium_m, t.vfx_burst_large_m]
	pop = spawn_pop(VfxArt.BURSTS[tier], point, bursts[tier] * t.vfx_scale, t.vfx_burst_s, PRIORITY_BURST)
	if pop:
		_set_kind_sizes(pop, bursts)
		_frame(pop, on_player)
	if _chance([t.vfx_word_chance_light, t.vfx_word_chance_heavy, t.vfx_word_chance_finisher][tier]):
		spawn_word(tier, point, on_player)
	if tier != CombatTypes.HitTier.LIGHT:
		if _chance(t.vfx_blood_chance_finisher if tier == CombatTypes.HitTier.FINISHER else t.vfx_blood_chance_heavy):
			spawn_blood(hit)
	if tier == CombatTypes.HitTier.FINISHER:
		if hit.region == CombatTypes.Region.HEAD:
			spawn_spit_and_tooth(hit)
		speed_lines.start(finisher_lines_focus(point), t.vfx_speed_lines_s, t.vfx_speed_lines_opacity)
		if t.impact_frame_enabled and t.vfx_impact_frame_frames > 0:
			impact_frame.flash(t.vfx_impact_frame_frames / 60.0)


func _on_attack_started(attacker: Node3D, move: MoveData, _chain_step: int, _input_timing: StringName) -> void:
	if attacker == null or not attacker.is_in_group(&"player") or not is_inside_tree():
		return
	_lunge_actor = null
	# Only a move with its own lunge: the magnetism step-in of jabs and chain hits is no lunge.
	if move == null or maxf(move.lunge, move.free_lunge) <= 0.0 or not (get_viewport().get_camera_3d() is FirstPersonCamera):
		return
	_lunge_actor = attacker as CombatActor
	_lunge_move = move
	_lunge_from = attacker.global_position
	_lunge_shown = false


func _on_health_changed(actor: Node3D, health: float, max_health: float) -> void:
	_update_damage_look(actor as CombatActor, health, max_health, false)


func _on_tuning_changed(property: StringName) -> void:
	if property != &"" and not DamageLook.TUNABLES.has(property):
		return
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		var actor := node as CombatActor
		if actor:
			_update_damage_look(actor, actor.health, actor.max_health, true)


# --- Internals -------------------------------------------------------------------------


## The warm-up's per-frame step (begin_warm_up()): last frame's sprites go to the pool, then
## the sprites and the impact frame's pixel go up once the camera and the toggle allow.
func _step_warm_up(camera: Camera3D) -> void:
	for sprite: ComicSprite in _warm_sprites:
		sprite.visible = false
		_pool.append(sprite)
	_warm_sprites.clear()
	if _warm_sprites_pending and camera != null:
		_warm_sprites_pending = false
		_show_warm_sprites(camera)
	if _warm_impact_pending and Tuning.data.impact_frame_enabled:
		_warm_impact_pending = false
		impact_frame.warm()


## One sprite per material variant, tiny and faint straight ahead of `camera` (in its view).
func _show_warm_sprites(camera: Camera3D) -> void:
	var cam := camera.global_transform.orthonormalized()
	var placed := Transform3D(cam.basis * Basis.from_scale(Vector3.ONE * WARM_SIZE_M),
			cam.origin - cam.basis.z * WARM_DISTANCE_M)
	for motion: ComicSprite.Motion in [ComicSprite.Motion.POP, ComicSprite.Motion.THROWN, ComicSprite.Motion.LYING]:
		var sprite := _make_sprite()
		sprite.motion = motion
		sprite.no_depth_test = motion == ComicSprite.Motion.POP
		sprite.shaded = motion == ComicSprite.Motion.LYING
		sprite.set_art(VfxArt.texture(&"burst_small"))
		sprite.modulate = Color(1.0, 1.0, 1.0, WARM_ALPHA)
		sprite.global_transform = placed
		sprite.visible = true
		_warm_sprites.append(sprite)


## Enemies only. `force` re-applies the look even when the level is unchanged.
func _update_damage_look(actor: CombatActor, health: float, max_health: float, force: bool) -> void:
	if not is_instance_valid(actor) or not actor.is_in_group(&"enemy") or actor.rig == null:
		return
	var level := DamageLook.level_for(health / max_health if max_health > 0.0 else 1.0)
	if force or actor.rig.damage_look != level:
		actor.rig.set_damage_look(level)


## The player's lunging attack has carried it Tuning.vfx_lunge_lines_min_m since it
## started: light speed lines on the view center, once per attack.
func _watch_lunge(camera: Camera3D) -> void:
	if _lunge_actor == null:
		return
	if not is_instance_valid(_lunge_actor) or _lunge_actor.current_move != _lunge_move or not (camera is FirstPersonCamera):
		_lunge_actor = null
		return
	if _lunge_shown:
		return
	var travel := _lunge_actor.global_position - _lunge_from
	travel.y = 0.0
	if travel.length() >= Tuning.data.vfx_lunge_lines_min_m:
		_lunge_shown = true
		speed_lines.start(speed_lines.size * 0.5, Tuning.data.vfx_lunge_lines_s, Tuning.data.vfx_lunge_lines_opacity)


## Throw a particle of `kind` from the hit's contact, along the hit (spread) and up.
func _throw(kind: StringName, hit: HitInfo, size_m: float, speed: float, seconds: float) -> ComicSprite:
	var art := VfxArt.texture(kind)
	if art == null or size_m <= 0.0 or seconds <= 0.0:
		return null
	var dir := hit.direction
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = Vector3.FORWARD
	var t := Tuning.data
	var spread := deg_to_rad(t.vfx_blood_spread_deg)
	dir = dir.normalized().rotated(Vector3.UP, rng.randf_range(-spread, spread))
	# Out along the hit, launched up at an angle between the two tunables.
	var up := deg_to_rad(rng.randf_range(minf(t.vfx_blood_launch_min_deg, t.vfx_blood_launch_max_deg), t.vfx_blood_launch_max_deg))
	var launch := dir * cos(up) + Vector3.UP * sin(up)
	var sprite := _acquire(kind, art, ComicSprite.Motion.THROWN)
	sprite.anchor = hit.contact_point
	sprite.velocity = launch * speed * _jitter(t.vfx_particle_speed_jitter)
	sprite.gravity = t.vfx_gravity
	sprite.size_m = size_m * t.vfx_scale * _jitter(t.vfx_particle_size_jitter)
	sprite.life = seconds
	sprite.pops = false
	sprite.fade_share = t.vfx_burst_fade_share
	sprite.render_priority = PRIORITY_SPLASH
	return sprite


## A thrown particle that moved from `from` this step: when it crossed the world it leaves
## a splat, lies there (a tooth), or vanishes. Returns false when it is gone.
func _land(sprite: ComicSprite, from: Vector3) -> bool:
	if not is_inside_tree():
		return true
	_ray.from = from
	_ray.to = sprite.anchor
	var result := get_world_3d().direct_space_state.intersect_ray(_ray)
	if result.is_empty():
		return true
	var point: Vector3 = result.position
	var normal: Vector3 = result.normal
	if sprite.leaves_splat:
		spawn_splat(point, normal)
		return false
	if sprite.lies_on_landing:
		sprite.anchor = point + normal * sprite.size_m * 0.4
		sprite.velocity = Vector3.ZERO
		sprite.gravity = 0.0
		sprite.spin = 0.0
		sprite.life = sprite.age + Tuning.data.vfx_blood_splat_s
		return true
	return false


## Where a finisher's speed lines converge for a hit at `point`: from the view center
## toward the contact on screen by Tuning.vfx_speed_lines_focus_follow, so a contact near
## an edge still leaves the middle of the view clear. The center when it is behind the view.
func finisher_lines_focus(point: Vector3) -> Vector2:
	var center := speed_lines.size * 0.5
	if not is_inside_tree():
		return center
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(point):
		return center
	var contact := camera.unproject_position(point).clamp(Vector2.ZERO, speed_lines.size)
	return center.lerp(contact, clampf(Tuning.data.vfx_speed_lines_focus_follow, 0.0, 1.0))


## Screen rects (speed-line coordinates) of the visible popping effects (bursts, words,
## sparks, splashes), which the speed lines keep clear of.
func _effect_rects(camera: Camera3D) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if camera == null:
		return out
	for sprite: ComicSprite in _live:
		if sprite.motion != ComicSprite.Motion.POP or not sprite.visible or sprite.texture == null:
			continue
		var half := Vector2(sprite.texture.get_width(), sprite.texture.get_height()) * sprite.pixel_size * 0.5
		var rect := Rect2()
		var behind := false
		for k in 4:
			var corner := sprite.global_transform * Vector3(half.x * (1 - 2 * (k & 1)), half.y * (1 - (k & 2)), 0.0)
			if camera.is_position_behind(corner):
				behind = true
				break
			var p := camera.unproject_position(corner)
			rect = Rect2(p, Vector2.ZERO) if k == 0 else rect.expand(p)
		if not behind:
			out.append(rect)
	return out


## Effects of `hit` show at the lens when it landed on the player.
static func _on_player(hit: HitInfo) -> bool:
	return is_instance_valid(hit.victim) and hit.victim.is_in_group(&"player")


## Keep `sprite`, an effect of a hit, in view (see the class doc).
static func _frame(sprite: ComicSprite, on_player: bool) -> void:
	sprite.keep_in_view = true
	sprite.at_lens = on_player
	sprite.clamp_reach_deg = Vector2(Tuning.data.vfx_clamp_reach_side_deg, Tuning.data.vfx_clamp_reach_low_deg)


## `sprite` is one of a kind sized `sizes` (meters before vfx_scale): its tiers share one
## view-share factor (ComicSprite).
static func _set_kind_sizes(sprite: ComicSprite, sizes: Array[float]) -> void:
	var smallest := INF
	var largest := 0.0
	for size: float in sizes:
		if size > 0.0:
			smallest = minf(smallest, size)
			largest = maxf(largest, size)
	if largest > 0.0:
		sprite.kind_min_m = smallest * Tuning.data.vfx_scale
		sprite.kind_max_m = largest * Tuning.data.vfx_scale


## A random factor within `share` of 1 (0.3: 0.7 to 1.3).
func _jitter(share: float) -> float:
	return 1.0 + rng.randf_range(-share, share)


func _chance(p: float) -> bool:
	return p >= 1.0 or (p > 0.0 and rng.randf() < p)


func _make_sprite() -> ComicSprite:
	var sprite := ComicSprite.new()
	add_child(sprite)
	return sprite


func _acquire(kind: StringName, art: Texture2D, motion: ComicSprite.Motion) -> ComicSprite:
	var sprite: ComicSprite = _pool.pop_back() if not _pool.is_empty() else null
	if sprite == null:
		sprite = _make_sprite()
	sprite.kind = kind
	sprite.motion = motion
	sprite.set_art(art)
	sprite.age = 0.0
	sprite.screen_offset = Vector2.ZERO
	sprite.rise_m = 0.0
	sprite.roll = 0.0
	sprite.spin = 0.0
	sprite.velocity = Vector3.ZERO
	sprite.gravity = 0.0
	sprite.trail = false
	sprite.pops = motion == ComicSprite.Motion.POP
	sprite.leaves_splat = false
	sprite.lies_on_landing = false
	sprite.shaded = false
	sprite.no_depth_test = false
	sprite.keep_in_view = false
	sprite.at_lens = false
	sprite.clamp_reach_deg = Vector2.ZERO
	sprite.kind_min_m = 0.0
	sprite.kind_max_m = 0.0
	sprite.modulate = Color.WHITE
	sprite.drawn_width = 0.0
	if sprite.has_meta(&"word"):
		sprite.remove_meta(&"word")
	_live.append(sprite)
	return sprite


func _retire(index: int) -> void:
	var sprite := _live[index]
	_live.remove_at(index)
	sprite.visible = false
	_pool.append(sprite)


static func _connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)
