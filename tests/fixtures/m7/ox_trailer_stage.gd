extends "res://tests/fixtures/m7/trailer_stage.gd"
## Milestone 7 (e-ox): the recording stage for Ox, the boss: the generic trailer stage with his art and head height as the defaults (not a test).
##   godot --path . --write-movie out.avi --fixed-fps 60 --resolution 1600x900 --quit-after 150 res://tests/fixtures/m7/ox_trailer_stage.tscn
## `--profile=m6` shows the same stage under the m6 look (the side-by-side); `--art=` and `--head=` still override.
const OX_ART := "res://game/actors/art/boss_art.tres"
## The head's height in m, from the 8-step turnaround (his hood sits higher than the Punk's cap).
const OX_HEAD := 1.55


func _arg(key: String, fallback: String) -> String:
	var given := super._arg(key, "")
	if given != "":
		return given
	match key:
		"--art":
			return OX_ART
		"--head":
			return str(OX_HEAD)
	return fallback
