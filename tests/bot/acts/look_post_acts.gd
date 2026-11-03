extends RefCounted
## The post pass's acts (P1-post, M4-plan Part A A8) for the crowd bot (tests/bot/crowd_bot.gd):
## the edge pass, the grade and the AA mode, seen and measured in the street, and the character
## mask on scratch spheres. Titles start "Look:", the slugs are e1 and e2 (look_sheets.sh cuts a
## still at every mark). Record one act per process:
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/e1 "Look: edge pass and grade" 6
##   tools/capture_bot.sh res://tests/bot/crowd_bot.tscn captures/e2 "Look: edge mask probe" 6
## The measurements land in look.json beside the recording (tests/bot/look_probe.gd) and in the log
## as `LOOK-METRIC <slug> <key> <value>`; a headless run draws nothing, so it only logs the marks.
##
## | Act | Title | Shows |
## | E1 | Look: edge pass and grade | the street and a Punk: everything on, edges off, grade off, both off, FXAA, MSAA off, depth-only edges, then the parked car (muted since A13) |
## | E2 | Look: edge mask probe | three glowing spheres wearing a tag 0 (a character): an unshaded hull, a lit hull, none; the mask on and off, and the debug views |
##
## The spheres stand in for P1-toon's characters (a toon material writes ROUGHNESS 0 on a character,
## and its hull is an unshaded `cull_front` overlay or the lit variant of A8's fallback 1): the act
## keeps working after the real ones land, and shows what the mask does to each kind of hull.

const LookRect := preload("res://tests/bot/look_rect.gd")
const LookProbe := preload("res://tests/bot/look_probe.gd")

## The comic effects' random seed (the VFX bot's, as look_acts.gd).
const VFX_SEED := 7
## Ticks to settle a spawn, and to let a changed tunable reach a drawn frame.
const SETTLE_TICKS := 30
const SHOW_TICKS := 4
## E1's last shot turns the view to the parked car, aiming this high above its foot (m), over this
## many ticks.
const CAR_AIM_M := 0.9
const TURN_TICKS := 20
## E1's Punk: where it stands (x right, y ahead, m).
const PUNK_AT := Vector2(0.0, 2.0)
## The region of the frame E1 measures the edge lines in, and the HUD plate it checks stays
## untouched, as fractions of the frame (x, y, width, height).
const LINES_REGION := Rect2(0.3, 0.1, 0.65, 0.5)
const HUD_REGION := Rect2(0.05, 0.85, 0.2, 0.09)
## The grade is measured over the whole frame; these step the pixels read (a frame is 1.4 Mpx).
const MEASURE_STEP := 4
const LINE_ROW_STEP := 3
## E2's spheres: radius and eye height (m), the distance ahead and the gap between two (m), the
## scan across a sphere's left edge (in sphere radii from its centre) and how the hull's width is
## picked: the last dark run, the one at the sphere's body.
const SPHERE_RADIUS_M := 0.45
const SPHERE_HEIGHT_M := 1.45
const SPHERE_AHEAD_M := 3.2
const SPHERE_GAP_M := 1.7
const SCAN_OUTER_RADII := 1.5
const SCAN_INNER_RADII := 0.6
const GLOW := Color(0.9, 0.85, 0.5)
## The debug views E2 shows (the tunable look_edge_debug_view) and their names.
const DEBUG_VIEWS: Array[Dictionary] = [
	{view = 1, label = "view_roughness"}, {view = 4, label = "view_mask"},
	{view = 5, label = "view_depth_lines"}, {view = 6, label = "view_creases"},
]

const SPHERE_SHADER := "
shader_type spatial;
render_mode ambient_light_disabled;
uniform vec3 glow : source_color = vec3(0.9, 0.85, 0.5);
void fragment() { ALBEDO = vec3(0.0); EMISSION = glow; ROUGHNESS = 0.0; SPECULAR = 0.0; }
"
const UNSHADED_HULL_SHADER := "
shader_type spatial;
render_mode unshaded, cull_front;
uniform vec3 ink : source_color = vec3(0.07, 0.06, 0.09);
uniform float width_m = 0.012;
void vertex() { VERTEX += NORMAL * width_m; }
void fragment() { ALBEDO = ink; }
"
const LIT_HULL_SHADER := "
shader_type spatial;
render_mode cull_front, ambient_light_disabled;
uniform vec3 ink : source_color = vec3(0.07, 0.06, 0.09);
uniform float width_m = 0.012;
void vertex() { VERTEX += NORMAL * width_m; }
void fragment() { ALBEDO = vec3(0.0); EMISSION = ink; ROUGHNESS = 0.0; SPECULAR = 0.0; METALLIC = 0.0; }
"


static func acts(bot: Node) -> Array[Dictionary]:
	return [
		{title = "Look: edge pass and grade", cam = &"first_person", slug = &"e1", fn = func() -> void: await _edges_and_grade(bot)},
		{title = "Look: edge mask probe", cam = &"first_person", slug = &"e2", fn = func() -> void: await _mask_probe(bot)},
	]


# --- The shared steps -------------------------------------------------------------------------


static func _begin(bot: Node) -> void:
	bot.caption.visible = false
	bot.god()
	bot.freeze_ai(true)
	var vfx := bot.get_tree().get_first_node_in_group(VfxDirector.GROUP) as VfxDirector
	if vfx:
		vfx.clear()
		vfx.rng.seed = VFX_SEED


static func _end(bot: Node, slug: String) -> void:
	LookRect.mark(bot, slug, "end")
	bot.caption.visible = true


## Let a changed tunable reach a drawn frame, then take it (null when headless: nothing is drawn,
## and RenderingServer.frame_post_draw never comes).
static func _shot(bot: Node, slug: String, label: String) -> Image:
	await bot._ticks(SHOW_TICKS)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	LookRect.mark(bot, slug, label)
	return LookProbe.grab(bot.get_viewport())


static func _metric(bot: Node, slug: String, values: Dictionary) -> void:
	for key: String in values:
		bot.log_line("LOOK-METRIC %s %s %s" % [slug, key, values[key]])
	LookProbe.record(slug, values)


static func _region(image: Image, fractions: Rect2) -> Rect2i:
	var size := Vector2(image.get_size())
	return Rect2i(Vector2i(fractions.position * size), Vector2i(fractions.size * size))


# --- E1: the edge pass and the grade ----------------------------------------------------------


static func _edges_and_grade(bot: Node) -> void:
	_begin(bot)
	bot.spawn(&"punk", PUNK_AT)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "e1", "start")
	var on := await _shot(bot, "e1", "all_on")
	bot.tune(&"look_edges_enabled", false)
	var edges_off := await _shot(bot, "e1", "edges_off")
	bot.tune(&"look_grade_enabled", false)
	var both_off := await _shot(bot, "e1", "both_off")
	bot.tune(&"look_edges_enabled", true)
	var grade_off := await _shot(bot, "e1", "grade_off")
	bot.tune(&"look_grade_enabled", true)
	bot.tune(&"look_aa_mode", LookPost.AaMode.FXAA)
	var fxaa := await _shot(bot, "e1", "fxaa")
	bot.tune(&"look_aa_mode", LookPost.AaMode.OFF)
	var no_aa := await _shot(bot, "e1", "aa_off")
	bot.tune(&"look_aa_mode", LookPost.AaMode.MSAA_4X)
	bot.tune(&"look_edge_depth_only", true)
	var depth_only := await _shot(bot, "e1", "depth_only")
	bot.tune(&"look_edge_depth_only", false)
	# The parked car: turn to it (it was red before A13; the street's colors are muted now).
	var car: Vector3 = bot.room.get(&"car_position") + Vector3.UP * CAR_AIM_M
	await bot._turn_by(bot.player.look_bearing_deg(car), TURN_TICKS)
	await _shot(bot, "e1", "car")
	if on != null and edges_off != null:
		var lines := _region(on, LINES_REGION)
		_metric(bot, "e1", {
			"edge_line_px_1080": snappedf(LookProbe.line_width_px(on, edges_off, lines, LINE_ROW_STEP), 0.01),
			"edge_changed_share": snappedf(LookProbe.changed_share(on, edges_off, Rect2i(), MEASURE_STEP), 0.0001),
			"edge_changed_share_depth_only": snappedf(LookProbe.changed_share(on, depth_only, Rect2i(), MEASURE_STEP), 0.0001),
			"hud_changed_share_edges": snappedf(LookProbe.changed_share(on, edges_off, _region(on, HUD_REGION)), 0.0001),
			"grade_mean_delta_e": snappedf(LookProbe.mean_delta_e(on, grade_off, Rect2i(), MEASURE_STEP), 0.01),
			"grade_mean_delta_e_no_edges": snappedf(LookProbe.mean_delta_e(edges_off, both_off, Rect2i(), MEASURE_STEP), 0.01),
			"fxaa_changed_share": snappedf(LookProbe.changed_share(on, fxaa, Rect2i(), MEASURE_STEP), 0.0001),
			"aa_off_changed_share": snappedf(LookProbe.changed_share(on, no_aa, Rect2i(), MEASURE_STEP), 0.0001),
		})
	_end(bot, "e1")


# --- E2: the character mask on scratch spheres --------------------------------------------------


static func _mask_probe(bot: Node) -> void:
	_begin(bot)
	await bot._look_to(0.0, 6)
	var camera: Camera3D = bot.get_viewport().get_camera_3d()
	var spheres := _spawn_spheres(bot, camera)
	await bot._ticks(SETTLE_TICKS)
	LookRect.mark(bot, "e2", "start")
	var hull_only: Image = null
	bot.tune(&"look_edges_enabled", false)
	hull_only = await _shot(bot, "e2", "edges_off")
	bot.tune(&"look_edges_enabled", true)
	var mask_on := await _shot(bot, "e2", "mask_on")
	bot.tune(&"look_edge_character_mask", false)
	var mask_off := await _shot(bot, "e2", "mask_off")
	bot.tune(&"look_edge_character_mask", true)
	for entry: Dictionary in DEBUG_VIEWS:
		bot.tune(&"look_edge_debug_view", entry.view)
		await _shot(bot, "e2", entry.label)
	bot.tune(&"look_edge_debug_view", 0)
	if mask_on != null:
		var values := {}
		for sphere: Dictionary in spheres:
			var key: String = sphere.name
			values["%s_px_edges_off" % key] = _hull_run_1080(hull_only, camera, sphere)
			values["%s_px_mask_on" % key] = _hull_run_1080(mask_on, camera, sphere)
			values["%s_px_mask_off" % key] = _hull_run_1080(mask_off, camera, sphere)
		_metric(bot, "e2", values)
	for sphere: Dictionary in spheres:
		(sphere.node as Node).queue_free()
	_end(bot, "e2")


## The three scratch spheres, left to right: an unshaded hull, a lit hull, none. Returns
## [{name, node, centre}].
static func _spawn_spheres(bot: Node, camera: Camera3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var player: Node3D = bot.player
	var proj_y := camera.get_camera_projection().y.y
	var kinds: Array[Dictionary] = [
		{name = "unshaded_hull", hull = UNSHADED_HULL_SHADER},
		{name = "lit_hull", hull = LIT_HULL_SHADER},
		{name = "no_hull", hull = ""},
	]
	for i in kinds.size():
		var local := Vector3((float(i) - 1.0) * SPHERE_GAP_M, SPHERE_HEIGHT_M, -SPHERE_AHEAD_M)
		var centre := player.global_position + player.global_basis * local
		var mesh := SphereMesh.new()
		mesh.radius = SPHERE_RADIUS_M
		mesh.height = SPHERE_RADIUS_M * 2.0
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = _shader_material(SPHERE_SHADER)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if kinds[i].hull != "":
			var hull := _shader_material(kinds[i].hull)
			# The hull's width in metres at the sphere's distance: the outline tunable in 1080p pixels.
			var metres_per_px := 2.0 * SPHERE_AHEAD_M / proj_y / LookProbe.REFERENCE_HEIGHT
			hull.set_shader_parameter(&"width_m", Tuning.data.look_outline_px * metres_per_px)
			instance.material_overlay = hull
		bot.room.add_child(instance)
		instance.global_position = centre
		out.append({name = kinds[i].name, node = instance, centre = centre})
	return out


static func _shader_material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


## The width, at 1080p, of the dark run at the foot of the scan across the left edge of `sphere`: the
## run that ends at its bright body, so a hull (and whatever line the edge pass drew beside it) and
## not a building's line further out; 0 when there is none.
static func _hull_run_1080(image: Image, camera: Camera3D, sphere: Dictionary) -> float:
	var scale_to_image := float(image.get_width()) / camera.get_viewport().get_visible_rect().size.x
	var centre := camera.unproject_position(sphere.centre) * scale_to_image
	var edge := camera.unproject_position(sphere.centre + camera.global_basis.x * SPHERE_RADIUS_M) * scale_to_image
	var radius_px := absf(edge.x - centre.x)
	var row := roundi(centre.y)
	var from := Vector2i(roundi(centre.x - radius_px * SCAN_OUTER_RADII), row)
	var to := Vector2i(roundi(centre.x - radius_px * SCAN_INNER_RADII), row)
	var runs := LookProbe.dark_runs(image, from, to)
	if runs.is_empty():
		return 0.0
	return snappedf(float(runs[runs.size() - 1]) * LookProbe.to_1080p(image.get_height()), 0.01)
