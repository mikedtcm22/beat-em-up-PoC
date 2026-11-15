extends "res://tests/fixtures/m7/trailer_stage.gd"
## Milestone 7 (e-thug): the Thug's recording stage (not a test): the generic trailer stage with the Thug's art and head height as its defaults.
## godot --path . --write-movie out.avi --fixed-fps 60 --resolution 1600x900 --quit-after 400 res://tests/fixtures/m7/thug_trailer_stage.tscn
## (--profile=m6 shows the same stage under the m6 look.)
const THUG_ART := "res://game/actors/art/thug_art.tres"
const THUG_HEAD := "1.72"


func _arg(key: String, fallback: String) -> String:
	if key == "--art":
		return super._arg(key, THUG_ART)
	if key == "--head":
		return super._arg(key, THUG_HEAD)
	return super._arg(key, fallback)
