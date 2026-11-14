extends "res://tests/fixtures/m7/trailer_stage.gd"
## The generic trailer stage (trailer_stage.gd) with the Kicker as its default: the 8-step turnaround, the face at three damage levels and the torso. Record with
##   godot --path . --write-movie out.avi --fixed-fps 60 --resolution 1600x900 --quit-after 400 res://tests/fixtures/m7/kicker_trailer_stage.tscn
## `--art=`, `--head=` and `--profile=m6` still work as on the generic stage.

const KICKER_ART := "res://game/actors/art/kicker_art.tres"
const KICKER_HEAD := 1.7


func _arg(key: String, fallback: String) -> String:
	if key == "--art":
		return super(key, KICKER_ART)
	if key == "--head":
		return super(key, str(KICKER_HEAD))
	return super(key, fallback)
