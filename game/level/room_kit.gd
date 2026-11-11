class_name RoomKit
extends RefCounted
## Building blocks for the code-built rooms: the crowd street (Milestone 3) and, from Milestone 4,
## the training room too, so one look serves both. Static helpers only, so a room reads as a list
## of boxes: the sky and sun, solid boxes on the world layer (the physics bodies the navmesh bakes
## from), visual-only boxes, flat materials, the player with its avoidance obstacle, and the
## presentation layer (cameras, HUD, tuning overlay, VFX, audio, rumble, the look's post pass) as
## direct children of the room. Layout numbers live in the room's exports, never here.

const PLAYER_SCENE := "res://game/player/player.tscn"
const CAMERA_DIRECTOR_SCENE := "res://game/camera/camera_director.tscn"
const CAMERA_DIRECTOR_SCRIPT := "res://game/camera/camera_director.gd"
const HUD_SCENE := "res://game/ui/hud.tscn"
const DEBUG_DRAW_SCENE := "res://game/ui/debug_draw.tscn"
const TUNING_OVERLAY_SCENE := "res://game/ui/tuning_overlay.tscn"
## The art the load-time warm-up draws (warm_up_art()): the Street Punk's, the room's commonest actor.
const WARM_ART := "res://game/actors/art/punk_art.tres"
## The enemies whose named animation library (HumanoidRig._named_library()) the warm-up builds besides
## the Punk's, which the throwaway rig builds: the Bruiser's and the boss's bodies are other sizes, so
## their first spawn would build one (26 to 31 ms with the Motion polish, about 17 ms more than M3).
const WARM_LIBRARY_ENEMIES: Array[StringName] = [&"bruiser", &"boss"]
## The rooms' default sky and fog (build_environment()), which a level section with no light of its own keeps
## (LevelRoot.default_light(), M6 D12).
const DEFAULT_SKY_TOP := Color(0.36, 0.42, 0.56)
const DEFAULT_SKY_HORIZON := Color(0.72, 0.62, 0.55)
const DEFAULT_FOG_COLOR := Color(0.6, 0.56, 0.55)
const DEFAULT_FOG_DENSITY := 0.008

## The warm-up's CharacterArt (warm_art()), held for the run. SkinnedArt's cache holds an art only
## weakly (an Entry dies with its CharacterArt), and the throwaway rig is the only thing that
## held this one: freed, it took the read of punk.glb with it, and the first Punk of every wave
## (the street empty again) read the GLB on its spawn frame, about 19 ms against 2. Like
## PlayerCharacter's hero art. Not a hold on the cache: a Punk's art still drops out of it when
## nothing wears it.
static var _warm_art: CharacterArt
## The art of every enemy in EnemyCatalog, held for the run by warm_catalog_arts() (M6 D27).
static var _catalog_arts: Array[CharacterArt] = []


## The player's avoidance obstacle (RVO): without it enemies walk straight through the player's
## position (godot-navigation codemap section 6.3). A child of the player, so it follows him;
## its radius is Tuning.data.player_avoid_radius_m, live.
class PlayerObstacle:
	extends NavigationObstacle3D

	func _init() -> void:
		name = "AvoidanceObstacle"

	func _ready() -> void:
		avoidance_enabled = true
		_apply()
		Tuning.changed.connect(_on_tuning_changed)

	func _exit_tree() -> void:
		if Tuning.changed.is_connected(_on_tuning_changed):
			Tuning.changed.disconnect(_on_tuning_changed)

	func _on_tuning_changed(property: StringName) -> void:
		if property == &"" or property == &"player_avoid_radius_m":
			_apply()

	func _apply() -> void:
		radius = Tuning.data.player_avoid_radius_m
		var actor := get_parent() as CombatActor
		if actor:
			height = actor.body_height


## The sky, a low sun with shadows and a light fog (the training room builds it here too).
static func build_environment(room: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = DEFAULT_SKY_TOP
	sky_mat.sky_horizon_color = DEFAULT_SKY_HORIZON
	sky_mat.ground_horizon_color = Color(0.4, 0.37, 0.38)
	sky_mat.ground_bottom_color = Color(0.2, 0.2, 0.22)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = LookPost.tonemap_mode(Tuning.data.look_tonemap)
	env.fog_enabled = true
	env.fog_light_color = DEFAULT_FOG_COLOR
	env.fog_density = DEFAULT_FOG_DENSITY
	env.fog_sky_affect = Tuning.data.section_fog_sky_affect
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	room.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	apply_sun(sun)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	room.add_child(sun)


## The light of a room with no level sections (the crowd street, the training room), in LevelSection.light()'s
## keys but for the sun's direction and energy, which are Tuning's (apply_sun()): what build_environment()
## builds. LookPost puts it on the room, with the running look profile's overrides (LookProfile.resolve_light()).
static func default_room_light() -> Dictionary:
	return {
		sun_color = Color.WHITE, fog_color = DEFAULT_FOG_COLOR, fog_density = DEFAULT_FOG_DENSITY,
		sky_top = DEFAULT_SKY_TOP, sky_horizon = DEFAULT_SKY_HORIZON,
	}


## Put the sky, fog and sun colour of `light` (default_room_light()'s keys) on `room`'s WorldEnvironment and "Sun", where
## the room has them and a value differs.
static func apply_room_light(room: Node, light: Dictionary) -> void:
	var sun := room.get_node_or_null("Sun") as DirectionalLight3D
	if sun != null and sun.light_color != light.sun_color:
		sun.light_color = light.sun_color
	var world := room.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world == null or world.environment == null:
		return
	var env := world.environment
	if env.fog_light_color != light.fog_color:
		env.fog_light_color = light.fog_color
	if not is_equal_approx(env.fog_density, float(light.fog_density)):
		env.fog_density = float(light.fog_density)
	var sky := env.sky.sky_material as ProceduralSkyMaterial if env.sky != null else null
	if sky != null:
		if sky.sky_top_color != light.sky_top:
			sky.sky_top_color = light.sky_top
		if sky.sky_horizon_color != light.sky_horizon:
			sky.sky_horizon_color = light.sky_horizon


## Put `sun` where Tuning's Look > Toon says: its height above the horizon, the direction it comes
## from and its energy (LookPost calls this again when one changes).
static func apply_sun(sun: DirectionalLight3D) -> void:
	sun.rotation_degrees = Vector3(-Tuning.data.look_sun_elevation_deg, Tuning.data.look_sun_yaw_deg, 0.0)
	sun.light_energy = Tuning.data.look_sun_energy
	sun.shadow_blur = Tuning.data.look_sun_shadow_blur


## A solid box centred at `pos` (world layer, no mask), with a mesh when `material` is given (or
## `art` is a kit kind), added to `parent`. Parent it under the room's geometry node: that node is
## what the navmesh bakes from. `overlay` goes on the mesh's `material_overlay` (a prop's hull).
## `art` (Milestone 6, KIT; D9): the KitMesh kind drawn instead of the plain box, on the trim
## material, over the same collider. `&""` and `&"box"` are M5's look, and so is every kind while
## Tuning's `kit_draw_graybox` is on.
static func add_box(parent: Node, pos: Vector3, size: Vector3, material: Material = null,
		overlay: Material = null, art: StringName = &"") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = CombatTypes.bit(CombatTypes.LAYER_WORLD)
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	if material or kit_art(art):
		body.add_child(box_mesh(size, material, overlay, art))
	parent.add_child(body)
	return body


## The meta key under which a box of a code-built room keeps what it does not draw: {MeshClip.key(axis, side): Array[Rect2]}, world
## space, in the plane's (u, v) coordinates (tests/m6_coplanar_scan.gd reads it).
const CLIPPED_META := &"clipped_rects"


## Makes no two drawn faces of the solid boxes under `geometry` (the ones `add_box` made) share a plane (Milestone 6 playtest
## verification, VFIX-WORLD; the level's blocks do it with `yields_to`, a room builds its boxes in loops, so it is decided here,
## once the room's boxes are all in): where two boxes' faces look the same way in one plane, the smaller box (then the later
## one) does not draw its face over the overlap (MeshClip), so there is only the other's, with no fight and no step. The colliders
## and the navmesh never change. A box with no kit mesh (the graybox switch) is left as it is.
static func resolve_coplanar(geometry: Node) -> void:
	var boxes: Array[Dictionary] = []
	for child in geometry.get_children():
		var body := child as StaticBody3D
		if body == null or body.collision_layer != CombatTypes.bit(CombatTypes.LAYER_WORLD):
			continue
		var shape := body.get_child(0) as CollisionShape3D if body.get_child_count() > 0 else null
		var mesh := body.get_child(1) as MeshInstance3D if body.get_child_count() > 1 else null
		if shape == null or mesh == null or not (shape.shape is BoxShape3D) or not (mesh.mesh is ArrayMesh):
			continue
		var size := (shape.shape as BoxShape3D).size
		boxes.append({body = body, mesh = mesh, size = size, box = AABB(body.position - size * 0.5, size), clips = {}})
	var coplanar: float = Tuning.data.kit_coplanar_m
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var found := MeshClip.overlaps(boxes[i].box, boxes[j].box, coplanar)
			if found.is_empty():
				continue
			var i_wins := _wins(boxes[i], boxes[j])
			var loser: Dictionary = boxes[j] if i_wins else boxes[i]
			var winner: Dictionary = boxes[i] if i_wins else boxes[j]
			var overlaps := MeshClip.overlaps(loser.box, winner.box, coplanar)
			for face_key: String in overlaps:
				var rects: Array = (loser.clips as Dictionary).get(face_key, [])
				rects.append(overlaps[face_key])
				(loser.clips as Dictionary)[face_key] = rects
	for entry in boxes:
		var clips: Dictionary = entry.clips
		if clips.is_empty():
			continue
		var local := {}
		var world := {}
		var body: StaticBody3D = entry.body
		for face_key: String in clips:
			var axis := int(face_key.substr(0, 1))
			var u := (axis + 1) % 3
			var v := (axis + 2) % 3
			var shifts: Array[Rect2] = []
			var shifted: Array[Rect2] = []
			for rect: Rect2 in clips[face_key]:
				shifted.append(rect)
				shifts.append(Rect2(rect.position - Vector2(body.position[u], body.position[v]), rect.size))
			world[face_key] = shifted
			local[face_key] = shifts
		var mesh: MeshInstance3D = entry.mesh
		mesh.mesh = MeshClip.clip_box(mesh.mesh, entry.size, local, Tuning.data.kit_clip_standoff_m, coplanar)
		body.set_meta(CLIPPED_META, world)


## Whether box `a` of resolve_coplanar wins a shared plane against `b`: the bigger one, then the earlier.
static func _wins(a: Dictionary, b: Dictionary) -> bool:
	var volume_a: float = (a.box as AABB).get_volume()
	var volume_b: float = (b.box as AABB).get_volume()
	return volume_a >= volume_b


## A box that is only drawn (paint, the far skyline): no collision, and the navmesh ignores it.
static func add_visual_box(parent: Node, pos: Vector3, size: Vector3, material: Material,
		overlay: Material = null, art: StringName = &"") -> MeshInstance3D:
	var mesh := box_mesh(size, material, overlay, art)
	mesh.position = pos
	parent.add_child(mesh)
	return mesh


## Whether `art` names a kit module that is drawn now: a KitMesh kind, with the graybox switch off.
static func kit_art(art: StringName) -> bool:
	return art != &"" and art != &"box" and KitMesh.KINDS.has(art) and not Tuning.data.kit_draw_graybox


## A box mesh of `size` in `material`; with a kit `art` kind (see add_box) the module's mesh on the
## shared trim material instead, `material` unused.
static func box_mesh(size: Vector3, material: Material, overlay: Material = null,
		art: StringName = &"") -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	if kit_art(art):
		mesh.mesh = KitMesh.build(art, size)
		mesh.material_overlay = overlay
		return mesh
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	mesh.material_overlay = overlay
	return mesh


## A flat-colored surface (ToonMaterials.environment()).
static func flat_material(color: Color) -> Material:
	return ToonMaterials.environment(color)


## A prop box's material (a crate, the dumpster, the car): flat like flat_material(), and it wears
## the inverted hull (ToonMaterials.environment(color, true)), so a prop is inked like a
## character (M4-plan A7). Walls, the street and paint take flat_material() and get no hull.
static func prop_material(color: Color) -> Material:
	return ToonMaterials.environment(color, true)


## The grey-box floor grid (the training room's), or a flat grey if the shader is missing
## (ToonMaterials.grid()).
static func grid_material() -> Material:
	return ToonMaterials.grid()


## The player at `pos` facing `yaw_deg`, added to `room`: it gets back up after a KO
## (auto_revive) and carries a PlayerObstacle so enemies steer around him.
static func spawn_player(room: Node3D, pos: Vector3, yaw_deg: float) -> PlayerCharacter:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerCharacter
	player.position = pos
	player.rotation.y = deg_to_rad(yaw_deg)
	player.auto_revive = true
	player.add_child(PlayerObstacle.new())
	room.add_child(player)
	return player


## Cameras, HUD, debug draw (if the HUD did not bring one), the F1/F4 TuningOverlay, the VFX,
## audio and rumble directors and the LookPost (the edge pass, the grade, the AA mode), all
## direct children of `room` (bots and tests find them there). Build the room's environment
## first: the grade goes on its WorldEnvironment.
static func build_presentation(room: Node3D) -> void:
	if ResourceLoader.exists(CAMERA_DIRECTOR_SCENE):
		room.add_child((load(CAMERA_DIRECTOR_SCENE) as PackedScene).instantiate())
	elif ResourceLoader.exists(CAMERA_DIRECTOR_SCRIPT):
		var director: Node3D = (load(CAMERA_DIRECTOR_SCRIPT) as GDScript).new()
		director.name = "CameraDirector"
		room.add_child(director)
	if ResourceLoader.exists(HUD_SCENE):
		room.add_child((load(HUD_SCENE) as PackedScene).instantiate())
	if ResourceLoader.exists(DEBUG_DRAW_SCENE) and room.get_tree().get_first_node_in_group(&"debug_draw") == null:
		room.add_child((load(DEBUG_DRAW_SCENE) as PackedScene).instantiate())
	if ResourceLoader.exists(TUNING_OVERLAY_SCENE):
		room.add_child((load(TUNING_OVERLAY_SCENE) as PackedScene).instantiate())
	room.add_child(VfxDirector.new())
	room.add_child(AudioDirector.new())
	room.add_child(RumbleDirector.new())
	room.add_child(LookPost.new())
	warm_up_art(room)


## Windowed only: draw the skinned art's toon variant (the art's vertex format, the skin, the
## hull) once at the room's load, so the first Punk of a wave does not compile it on its
## frame. A throwaway rig wears the Punk's art (build_warm_rig()); ToonMaterials.warm_up() draws a
## copy of its skeleton for two frames, in the lens once the room's camera has been placed (the
## second frame of the room, not the first: the camera has not updated before that), and the rig is
## freed at once, but its art is held (warm_art()), so the read of the GLB that building it made stays
## in SkinnedArt's cache for every Punk that spawns later. It also builds the Bruiser's and the
## boss's named libraries (warm_up_libraries()), whose sizes the Punk's rig does not cover.
## Headless: nothing.
static func warm_up_art(room: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	warm_up_libraries()
	warm_catalog_arts()
	var rigs := build_warm_rigs(room)
	if rigs.is_empty():
		return
	var variants: Array[Node3D] = []
	for extra: HumanoidRig in rigs.slice(1):
		variants.append(extra.skeleton)
	ToonMaterials.warm_up(room, rigs[0].skeleton, variants)
	for rig: HumanoidRig in rigs:
		rig.queue_free()


## The art the warm-up wears (WARM_ART), loaded once and held for the run, so that the cache entry
## its read makes (SkinnedArt) outlives the throwaway rig, and so that a Street Punk's scene,
## which loads the same resource by path, gets this CharacterArt and that entry. Null when the art
## does not exist.
static func warm_art() -> CharacterArt:
	if _warm_art == null and ResourceLoader.exists(WARM_ART):
		_warm_art = load(WARM_ART) as CharacterArt
	return _warm_art


## The CharacterArt of every enemy scene in EnemyCatalog.available(), read from the scene's root `art` (a scene with no art, the
## primitives, adds none), once each. The catalog is the one list of what can spawn, so a new character's art is warmed by adding
## its scene there and nothing else (M6 D27).
static func catalog_arts() -> Array[CharacterArt]:
	var out: Array[CharacterArt] = []
	for entry: Dictionary in EnemyCatalog.available():
		var packed := load(entry.scene) as PackedScene
		if packed == null:
			continue
		var state := packed.get_state()
		for i: int in state.get_node_property_count(0):
			if state.get_node_property_name(0, i) != &"art":
				continue
			var art := state.get_node_property_value(0, i) as CharacterArt
			if art != null and not out.has(art):
				out.append(art)
	return out


## The trailer variants (CharacterArt.trailer, M7) of `arts`, each once: the art the other look profile
## draws, which the warm-up draws and holds too so a profile flip compiles and reads nothing mid-fight.
static func variant_arts_of(arts: Array[CharacterArt]) -> Array[CharacterArt]:
	var out: Array[CharacterArt] = []
	for art: CharacterArt in arts:
		if art != null and art.trailer != null and not out.has(art.trailer) and not arts.has(art.trailer):
			out.append(art.trailer)
	return out


## Read and hold the art of every catalog enemy (catalog_arts()): SkinnedArt's entry for each is made now, off the spawn frame, and
## held by this class's reference to the CharacterArt (the cache holds an art only weakly, see _warm_art). A cold GLB read costs
## 17 to 19 ms against 1 to 4 warm (fix-final-punk-spawn-cache C3), which is a dropped frame at the first Kicker or Bruiser of a
## run. Callable headless: it reads and draws nothing. Returns the arts held.
static func warm_catalog_arts() -> Array[CharacterArt]:
	_catalog_arts = catalog_arts()
	_catalog_arts.append_array(variant_arts_of(_catalog_arts))
	for art: CharacterArt in _catalog_arts:
		SkinnedArt.entry_of(art)
	return _catalog_arts


## The arts warm_catalog_arts() holds (empty before its first call).
static func held_catalog_arts() -> Array[CharacterArt]:
	return _catalog_arts


## Let go of the catalog's arts, as release_warm_art() does the Punk's. For tests that count the cache's reads.
static func release_catalog_arts() -> void:
	_catalog_arts = []


## Whether the warm-up's art is loaded and held (warm_art() has run). For the look act that checks
## the windowed warm-up (W1).
static func warm_art_held() -> bool:
	return _warm_art != null


## Let go of the held art (warm_art()): the next call loads it afresh. For tests that count the
## cache's reads.
static func release_warm_art() -> void:
	_warm_art = null


## The throwaway rig of warm_up_art(), built under `room`: a HumanoidRig with no hurtboxes wearing
## warm_art(), the art read and its meshes attached. The caller frees it. Null without the art.
## No window needed (a test drives it headless); warm_up_art() is the windowed caller.
## `art` (null: warm_art()) is worn exactly, whatever the look profile.
static func build_warm_rig(room: Node3D, art: CharacterArt = null) -> HumanoidRig:
	var worn := art if art != null else warm_art()
	if worn == null:
		return null
	var rig := HumanoidRig.new()
	rig.name = "WarmUpRig"
	rig.build_hurtboxes = false
	rig.art_follows_look = false
	rig.art = worn
	room.add_child(rig)
	rig.build()
	return rig


## The throwaway rigs of the windowed warm-up, built under `room`: the first wears `base` (null: the
## warm-up's Punk art) and one more per trailer variant (variant_arts_of()) of it and of every catalog
## art (when `base` is null), each in its own art whatever the look profile, so both profiles' meshes and
## materials are drawn. Empty without the art. The caller frees them. No window needed.
static func build_warm_rigs(room: Node3D, base: CharacterArt = null) -> Array[HumanoidRig]:
	var out: Array[HumanoidRig] = []
	var first := build_warm_rig(room, base)
	if first == null:
		return out
	out.append(first)
	var arts: Array[CharacterArt] = [first.art]
	if base == null:
		for art: CharacterArt in catalog_arts():
			if not arts.has(art):
				arts.append(art)
	for variant: CharacterArt in variant_arts_of(arts):
		var rig := build_warm_rig(room, variant)
		if rig != null:
			out.append(rig)
	return out


## Build the boxer named animation library of each WARM_LIBRARY_ENEMIES body's size now
## (HumanoidRig._named_library(), cached per size and stance: a rig of that size takes it from the
## cache), so the first Bruiser or boss of a run does not build it on its spawn frame (F-motion's
## request, M4-calls/F-motion.md). The size is the enemy's own body height over the rig's reference
## height, as its rig takes it (CombatActor._ensure_body() sets rig.height = body_height). Called
## by warm_up_art() in a window; callable headless, where it is the same build without a draw.
static func warm_up_libraries() -> void:
	for id: StringName in WARM_LIBRARY_ENEMIES:
		var body_height := EnemyCatalog.body_size(id).y
		HumanoidRig._named_library(body_height / PlaceholderBody.REF_HEIGHT, PlaceholderPoses.STANCE_BOXER)
