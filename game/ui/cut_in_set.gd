class_name CutInSet
extends Resource
## Which drawn card goes with which event, for one mission (Milestone 7, Phase 3; game/ui/cut_ins/mission1.tres).
## CutIn reads it; it holds data only.

## The card on the mission's first frame of play.
@export var title: CutInEntry
## One per enemy archetype: shown the first time that type appears in the mission (Ox at the boss intro).
@export var entrances: Array[CutInEntry] = []
## One per enemy archetype: the knockout panels an arena's clear picks from, by the last enemy knocked out.
@export var ko_panels: Array[CutInEntry] = []
## The card on the level's clear, held until a button.
@export var mission_end: CutInEntry
## The small line under the end card's lettering once it takes a button.
@export var end_prompt: String = "PRESS A BUTTON"


## The entrance entry of `archetype`, or null.
func entrance_for(archetype: StringName) -> CutInEntry:
	return _find(entrances, archetype)


## The knockout entry of `archetype`, or null.
func ko_for(archetype: StringName) -> CutInEntry:
	return _find(ko_panels, archetype)


func _find(entries: Array[CutInEntry], archetype: StringName) -> CutInEntry:
	for entry in entries:
		if entry != null and entry.key == archetype:
			return entry
	return null
