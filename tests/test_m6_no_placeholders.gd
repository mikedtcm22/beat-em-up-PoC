extends GutTest
## Milestone 6's definition of done, counted: no placeholder asset remains (plan section 2, "The placeholder
## inventory"). The test builds Mission 1 (mission1.tscn), the crowd street and the training room headless and counts,
## per scene, five kinds of stand-in; `tests/fixtures/m6/placeholder_ratchet.json` holds the most each may be. A
## package that replaces a stand-in lowers its numbers in the same commit (a ratchet only moves down); the lead sets
## the ratchet at every merge and to zero at the end.
##
##   primitive_bodies  every enemy id the scene can put in play (encounter tables, the crowd waves, the boss's adds, the
##                     training room's dummies and the F4 catalog), built with its variant and counted when its rig has no
##                     skinned art, plus the player. Enemies spawn at runtime, so the built scene alone would read 0.
##   tints             a shipped variant with a tint, a dummy colour multiply (test_room.gd's dummy_colors), the amber a
##                     weapon takes on the floor.
##   boxes             a visible BoxMesh or other PrimitiveMesh in the built scene: blocks, barrier parts, steps, crates,
##                     the skyline, prop fallbacks.
##   cylinder_weapons  every weapon the scene places or an enemy carries that draws with a CylinderMesh.
##   second_weapon     1 while a PickupSpot holds the pipe (A6's, until WEAPONS gives it the bike chain).
## and, once, under "global" (they do not belong to a scene):
##   generated_sfx     a shipped pool whose manifest source is gen_sfx, or that has no row (no manifest yet: every pool).
##   empty_slots       a manifest slot with fewer files than its min_variants (0 until AUDIO's manifest lands).
## Allowed, by name: the music loop (D25), F3's debug draws, the hidden proxies and hidden-layer meshes, EdgeGuard, the
## LookPost EdgeQuad, the warm-up meshes and the audition room's legacy bank (D24).
##
## Measure afresh (writes the ratchet; the lead does this at merges): M6_WRITE_RATCHET=1 tools/run_tests.sh
## -gselect=test_m6_no_placeholders.gd. Every run prints one `PLACEHOLDERS <scene> <category> <n>` line each.

const LookProfileHelper := preload("res://tests/look_profile_helper.gd")
const RATCHET_PATH := "res://tests/fixtures/m6/placeholder_ratchet.json"
const LEVEL_PATH := "res://game/level/mission1/mission1.tscn"
const CROWD_PATH := "res://game/level/crowd_room.tscn"
const TRAINING_PATH := "res://game/level/test_room.tscn"
const PLAYER_PATH := "res://game/player/player.tscn"
const ENCOUNTERS_DIR := "res://game/level/mission1/encounters"
const SFX_DIR := "res://assets/export/sfx"
const MANIFEST_PATH := "res://assets/source/sfx/manifest.json"
## The enemy the boss calls in (boss.gd, _spawn_one_add).
const BOSS_ADD_ID := &"punk"
const BOSS_ID := &"boss"
const ALLOWED_POOLS: Array[String] = ["music_loop"]
const SCENES: Array[String] = ["mission1", "crowd_room", "test_room", "global"]
const SCENE_CATEGORIES: Array[String] = ["primitive_bodies", "tints", "boxes", "cylinder_weapons", "second_weapon"]
const GLOBAL_CATEGORIES: Array[String] = ["generated_sfx", "empty_slots"]
## Nodes the count never enters: the warm-up holder (headless it is never built), the flash warm-up, the edge pass's quad.
const ALLOWED_NODE_NAMES: Array[String] = ["ToonWarmUp", "FlashWarmUp", "EdgeQuad"]

## id -> {armed: bool (a rig with art), tint: bool, weapons: int (cylinder weapons it carries)}
var _enemy_facts: Dictionary = {}
var _player_has_art: bool = false


func before_each() -> void:
	LookProfileHelper.use_m6()


func after_each() -> void:
	LookProfileHelper.restore()


func test_the_inventory_is_at_or_under_the_ratchet() -> void:
	var measured := await _measure()
	for scene: String in SCENES:
		for category: String in _categories(scene):
			print("PLACEHOLDERS %s %s %d" % [scene, category, measured[scene][category]])
	if OS.get_environment("M6_WRITE_RATCHET") == "1":
		var file := FileAccess.open(RATCHET_PATH, FileAccess.WRITE)
		file.store_string(JSON.stringify(measured, "\t", false) + "\n")
		file.close()
		pass_test("ratchet written to %s" % RATCHET_PATH)
		return
	var ratchet := _ratchet()
	for scene: String in SCENES:
		for category: String in _categories(scene):
			var cap := int((ratchet.get(scene, {}) as Dictionary).get(category, -1))
			assert_gte(cap, 0, "%s %s has a ratchet" % [scene, category])
			assert_lte(measured[scene][category], cap, "%s %s: %d placeholders, the ratchet allows %d (lower the ratchet in the commit that removes one, never raise it)"
					% [scene, category, measured[scene][category], cap])


func test_the_ratchet_names_every_scene_and_category_and_only_those() -> void:
	var ratchet := _ratchet()
	assert_eq(ratchet.keys().size(), SCENES.size(), "one block per scene")
	for scene: String in SCENES:
		assert_true(ratchet.has(scene), "%s is in the ratchet" % scene)
		var block: Dictionary = ratchet.get(scene, {})
		assert_eq(block.keys().size(), _categories(scene).size(), "%s: one number per category" % scene)
		for category: String in _categories(scene):
			assert_true(block.has(category), "%s %s is in the ratchet" % [scene, category])
			assert_gte(int(block.get(category, -1)), 0, "%s %s is a count" % [scene, category])


func test_no_shipped_variant_uses_a_tint() -> void:
	for entry: Dictionary in EnemyCatalog.ENTRIES:
		var variant := EnemyCatalog.variant(entry.id)
		if variant != null:
			assert_eq(variant.tint.a, 0.0, "%s: the palette swap retired the tint (D4)" % entry.id)


# --- Measuring ----------------------------------------------------------------------------------


func _categories(scene: String) -> Array[String]:
	return GLOBAL_CATEGORIES if scene == "global" else SCENE_CATEGORIES


func _ratchet() -> Dictionary:
	if not FileAccess.file_exists(RATCHET_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RATCHET_PATH))
	return parsed if parsed is Dictionary else {}


func _measure() -> Dictionary:
	await _probe_actors()
	var out := {}
	out["mission1"] = await _measure_scene(LEVEL_PATH, _level_ids())
	out["crowd_room"] = await _measure_scene(CROWD_PATH, _crowd_ids())
	out["test_room"] = await _measure_scene(TRAINING_PATH, _training_ids())
	out["global"] = _measure_audio()
	return out


## The enemy ids Mission 1 can put in play: every wave of every arena's table, and the boss's adds.
func _level_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	var dir := DirAccess.open(ENCOUNTERS_DIR)
	for file: String in dir.get_files():
		if file.ends_with(".tres"):
			_add_table_ids(ids, load("%s/%s" % [ENCOUNTERS_DIR, file]) as EncounterTable)
	return ids


## The crowd street's: its table's waves, the boss wave and the adds.
func _crowd_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	_add_table_ids(ids, load(EncounterSpawner.TABLE_PATH) as EncounterTable)
	return ids


## The training room's: its dummies, then everything the F4 menu can spawn.
func _training_ids() -> Array[StringName]:
	var ids: Array[StringName] = [&"dummy"]
	for entry: Dictionary in EnemyCatalog.available():
		if not ids.has(entry.id):
			ids.append(entry.id)
	return ids


func _add_table_ids(ids: Array[StringName], table: EncounterTable) -> void:
	if table == null:
		return
	var waves: Array[PackedStringArray] = table.waves.duplicate()
	if table.loop:
		waves.append(table.boss_wave)
	for wave: PackedStringArray in waves:
		for id: String in wave:
			if not ids.has(StringName(id)):
				ids.append(StringName(id))
	if ids.has(BOSS_ID) and not ids.has(BOSS_ADD_ID):
		ids.append(BOSS_ADD_ID)


## Build every enemy id of the catalog once (with its variant, in the tree long enough for its rig) and the player, and
## note what each is: armed with art or not, tinted, carrying cylinder weapons.
func _probe_actors() -> void:
	if not _enemy_facts.is_empty():
		return
	var holder := Node3D.new()
	add_child(holder)
	var made: Dictionary = {}
	for id: StringName in _training_ids():
		var scene := EnemyCatalog.scene(id)
		if scene == null:
			_enemy_facts[id] = {armed = false, tint = false, weapons = 0}
			continue
		var node := scene.instantiate() as CombatActor
		var enemy := node as EnemyActor
		if enemy != null:
			EnemyCatalog.apply_variant(enemy, id)
		holder.add_child(node)
		made[id] = node
	var player := (load(PLAYER_PATH) as PackedScene).instantiate() as PlayerCharacter
	holder.add_child(player)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for id: StringName in made:
		var actor := made[id] as CombatActor
		var variant := EnemyCatalog.variant(id)
		var tinted: bool = variant != null and variant.tint.a > 0.0 and Color(variant.tint, 1.0) != Color.WHITE
		_enemy_facts[id] = {armed = actor.rig != null and actor.rig.has_art(), tint = tinted, weapons = _cylinder_weapons(actor)}
	_player_has_art = player.rig != null and player.rig.has_art()
	holder.queue_free()
	await get_tree().process_frame


func _measure_scene(path: String, ids: Array[StringName]) -> Dictionary:
	var packed := load(path) as PackedScene
	var root := packed.instantiate()
	if "with_presentation" in root:
		root.set(&"with_presentation", false)
	if "waves_enabled_on_start" in root:
		root.set(&"waves_enabled_on_start", false)
	add_child(root)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var bodies := 0 if _player_has_art else 1
	var tints := 0
	var weapons := 0
	for id: StringName in ids:
		var facts: Dictionary = _enemy_facts.get(id, {armed = false, tint = false, weapons = 0})
		if not facts.armed:
			bodies += 1
		if facts.tint:
			tints += 1
		weapons += int(facts.weapons)
	# A dummy colour multiply: the room paints each dummy its own colour.
	if "dummy_colors" in root and not (root.get(&"dummy_colors") as Array).is_empty():
		tints += (root.get(&"dummies") as Array).size()
	# The scene's own weapons (a pickup spot's, the training room's pipe) and the amber each takes on the floor.
	var lying := 0
	for weapon: Node in root.find_children("*", "Weapon", true, false):
		weapons += _cylinder_weapons(weapon)
		if (weapon as Weapon).is_available():
			lying += 1
	if lying > 0 and _floor_amber():
		tints += 1
	var second := 0
	for spot: Node in root.find_children("*", "PickupSpot", true, false):
		var scene := (spot as PickupSpot).weapon_scene
		if scene != null and scene.resource_path == "res://game/weapons/pipe.tscn":
			second = 1
	var result := {primitive_bodies = bodies, tints = tints, boxes = _count_boxes(root), cylinder_weapons = weapons, second_weapon = second}
	root.queue_free()
	await get_tree().process_frame
	return result


## Whether a weapon on the floor still turns amber (WEAPONS' Debug switch `weapon_floor_amber`, once it exists, decides).
func _floor_amber() -> bool:
	if "weapon_floor_amber" in Tuning.data:
		return bool(Tuning.data.get(&"weapon_floor_amber"))
	return true


## 1 for a weapon (or each weapon under an actor) whose drawn mesh is a CylinderMesh, as `node` itself or below it.
## A hidden cylinder (the proxy a weapon with `art_scene` keeps) does not draw, so it does not count.
func _cylinder_weapons(node: Node) -> int:
	var n := 0
	var weapons: Array[Node] = node.find_children("*", "Weapon", true, false)
	if node is Weapon:
		weapons.append(node)
	for weapon: Node in weapons:
		for mesh_instance: Node in weapon.find_children("*", "MeshInstance3D", true, false):
			if (mesh_instance as MeshInstance3D).mesh is CylinderMesh and (mesh_instance as MeshInstance3D).visible:
				n += 1
				break
	return n


## Visible primitive meshes in the built scene, outside the actors and weapons (counted above), the allowed nodes and anything hidden.
func _count_boxes(root: Node) -> int:
	var n := 0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if not (mesh_instance.mesh is PrimitiveMesh) or not mesh_instance.is_visible_in_tree():
			continue
		if (mesh_instance.layers & (1 << (CombatTypes.VIS_DEFAULT - 1))) == 0:
			continue  # on the hidden or the debug layer
		if _allowed(mesh_instance, root):
			continue
		n += 1
	return n


func _allowed(node: Node, root: Node) -> bool:
	var cursor: Node = node
	while cursor != null and cursor != root:
		if cursor is CombatActor or cursor is Weapon or cursor is EdgeGuard or ALLOWED_NODE_NAMES.has(String(cursor.name)):
			return true
		cursor = cursor.get_parent()
	return false


## The audio rows: pools by their files' names (`<pool>_<nn>.wav`) against the manifest (AUDIO), when there is one.
func _measure_audio() -> Dictionary:
	var pools: Dictionary = {}
	var dir := DirAccess.open(SFX_DIR)
	for file: String in dir.get_files():
		if not file.ends_with(".wav"):
			continue
		var pool := file.get_basename().rstrip("0123456789").rstrip("_")
		if ALLOWED_POOLS.has(pool):
			continue
		if not pools.has(pool):
			pools[pool] = []
		(pools[pool] as Array).append(file)
	var generated := 0
	var empty := 0
	if not FileAccess.file_exists(MANIFEST_PATH):
		generated = pools.size()
	else:
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		var rows: Dictionary = {}
		for row: Dictionary in manifest.get("files", []):
			rows[String(row.file)] = String(row.get("source", "gen_sfx"))
		for pool: String in pools:
			for file: String in pools[pool]:
				if not rows.has(file) or rows[file] == "gen_sfx":
					generated += 1
					break
		var slots: Dictionary = manifest.get("slots", {})
		for pool: String in slots:
			if ALLOWED_POOLS.has(pool):
				continue
			var have := (pools[pool] as Array).size() if pools.has(pool) else 0
			if have < int((slots[pool] as Dictionary).get("min_variants", 0)):
				empty += 1
	return {generated_sfx = generated, empty_slots = empty}
