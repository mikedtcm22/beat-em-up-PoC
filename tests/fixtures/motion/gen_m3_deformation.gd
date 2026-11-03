extends Node
## Writes tests/fixtures/motion/m3_deformation.json: the deformation of the M3 clips (the polish off) on the Punk's art, the
## frozen side of test_motion_m4's comparison "the polish does not make a clip's deformation worse". The M3 clips never change
## (A20: tests/fixtures/motion/move_clip_hashes.json holds them), so the figures change only with the art's vertices and
## weights, which the file's `art` hash names: a stale file is measured live by the test (and said so), never trusted.
##
## A scene (the clips read autoloads): `godot --headless res://tests/fixtures/motion/gen_m3_deformation.tscn --quit-after 5`.
## Run it after punk.glb's geometry or weights change (about 10 s), and commit the file.

const MotionProbe := preload("res://tests/fixtures/motion/motion_probe.gd")
const SkinnedView := preload("res://tests/skinned_view.gd")
const ClipHash := preload("res://tests/fixtures/motion/clip_hash.gd")
const TABLE_PATH := "res://tests/fixtures/motion/m3_deformation.json"
const PUNK_ART := "res://game/actors/art/punk_art.tres"
const STANCES: Array[StringName] = [PlaceholderPoses.STANCE_BOXER, PlaceholderPoses.STANCE_RELAXED]


func _ready() -> void:
	var rig := HumanoidRig.new()
	rig.height = 1.8
	rig.stance = PlaceholderPoses.STANCE_BOXER
	rig.build_hurtboxes = false
	rig.art = load(PUNK_ART) as CharacterArt
	add_child(rig)
	rig.build()
	var mi := rig.art_meshes()[0]
	var rest := SkinnedView.skin_vertices(mi, rig, MotionProbe.rest_globals(rig))
	var figures := {}
	for stance: StringName in STANCES:
		for id: StringName in PlaceholderAnims.POLISHED_IDS:
			figures["%s|%s" % [stance, id]] = MotionProbe.clip_strain(mi, rig, rest, ClipHash.named_clip(id, 1.0, stance))
	var file := FileAccess.open(TABLE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("cannot write %s" % TABLE_PATH)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify({art = MotionProbe.art_hash(mi), figures = figures}, "\t", true) + "\n")
	file.close()
	print("wrote %d clips' M3 deformation to %s" % [figures.size(), TABLE_PATH])
	get_tree().quit(0)
