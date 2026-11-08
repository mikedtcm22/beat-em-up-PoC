extends RefCounted
## LD-WORLD2's stills (round 2: drawn detail, no glare): the six Phase 0 shots with the round 2 world look of their location over the
## game's toon characters. "World2: <key>" applies `res://video/look/<location>/world.tres`, then shoots the shot through the stills stage with
## the stage's own lamp posts left out (the look places its own from data). Unlike round 1 the game's edge pass stays on by default
## (the drawn detail wants the geometry's outlines; the LD-INK pass replaces it in a finished shot): `--world-no-edges` hides it.
## "World2Motion: <key>" writes 12 consecutive frames while the camera moves (the swimming and flicker check).
## Arguments after `--`: `--world-look=<location>` forces a location's look for every shot.

const StillsActs := preload("res://video/acts/stills_acts.gd")
const WorldActs := preload("res://video/acts/ld_world_acts.gd")


static func acts(bot: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for shot in StillsActs.shots():
		out.append({
			title = "World2: %s" % shot.key,
			cam = &"first_person" if shot.first_person else &"free_fly",
			fn = func() -> void: await _shoot(bot, shot),
		})
	for shot in StillsActs.shots():
		if not shot.first_person:
			out.append({
				title = "World2Motion: %s" % shot.key,
				cam = &"free_fly",
				fn = func() -> void: await _motion(bot, shot),
			})
	out.append({title = "World2Dump", cam = &"free_fly", fn = func() -> void: await _dump(bot)})
	return out


## Prints every mesh of the level whose material is not the trim's (the props the paint has to find): path, shader, colour.
static func _dump(bot: Node) -> void:
	var level: Node = bot.get(&"level")
	var seen := {}
	for node in level.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var mats: Array[Material] = []
		if mesh.material_override != null:
			mats.append(mesh.material_override)
		for i in mesh.get_surface_override_material_count():
			var m := mesh.get_surface_override_material(i)
			if m != null:
				mats.append(m)
		if mesh.mesh != null:
			for i in mesh.mesh.get_surface_count():
				var m2 := mesh.mesh.surface_get_material(i)
				if m2 != null:
					mats.append(m2)
		for m in mats:
			var sm := m as ShaderMaterial
			var shader_path := sm.shader.resource_path if sm != null and sm.shader != null else m.get_class()
			var key := "%s|%s" % [mesh.get_parent().name if mesh.get_parent() else "", shader_path]
			if seen.has(key):
				continue
			seen[key] = true
			print("DUMP %s | %s | %s | owner=%s | groups=%s | meta=%s" % [level.get_path_to(mesh), shader_path, m.resource_name, mesh.get_parent().get_class(), mesh.get_groups(), mesh.get_meta_list()])


static func _shoot(bot: Node, shot: VideoStillShot) -> void:
	var forced := ""
	var hide_edges := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--world-look="):
			forced = arg.trim_prefix("--world-look=")
		elif arg == "--world-no-edges":
			hide_edges = true
	var location: StringName = StringName(forced) if forced != "" else WorldActs.LOCATIONS[shot.section]
	var look := WorldActs.look_for(location)
	var level: Node = bot.get(&"level")
	look.apply(level)
	if hide_edges:
		for post in level.find_children("*", "LookPost", true, false):
			(post as LookPost).edge_quad().visible = false
	var own := shot.duplicate() as VideoStillShot
	own.lamp_posts = PackedVector3Array()
	await bot.shoot(own)


static func _motion(bot: Node, shot: VideoStillShot) -> void:
	await _shoot(bot, shot)
	var step := Vector3(0.0, 0.0, -WorldActs.MOTION_STEP_M)
	for frame in WorldActs.MOTION_FRAMES:
		var xf: Transform3D = bot.get(&"_free_xf")
		xf.basis = xf.basis.rotated(Vector3.UP, deg_to_rad(WorldActs.MOTION_TURN_DEG))
		xf.origin += xf.basis * step
		bot.set(&"_free_xf", xf)
		await bot.call(&"_ticks", 1)
		var path := "%s/%s_m%02d.png" % [bot.get(&"out_dir"), shot.key, frame]
		await (bot.get(&"grab") as VideoStillGrab).capture(path)
