extends StreetPunk
## A Street Punk wearing the procedural probe art (tests/fixtures/skinned_probe_art.gd): what
## the skin acts (tests/bot/acts/skin_acts.gd) spawn in the crowd room to watch the art follow
## the rig. `authored` and `smooth` choose the probe's variant before the first one is made.

const Fixture := preload("res://tests/fixtures/skinned_probe_art.gd")

## The probe's authoring pose (Fixture.Authored) and weighting, for the next Punk made.
static var authored: int = Fixture.Authored.A_POSE
static var smooth: bool = true
static var _art: CharacterArt
static var _made: String = ""


func _configure_art(r: HumanoidRig) -> void:
	var key := "%d/%s" % [authored, smooth]
	if _art == null or _made != key:
		_art = Fixture.make(authored, false, smooth)
		_made = key
	r.art = _art
