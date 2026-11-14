class_name CutInEntry
extends Resource
## One drawn card's data (Milestone 7, Phase 3): the key it is looked up by (an enemy archetype for an entrance or a
## knockout panel), the lettering the game draws over the art, and the art itself, 1600x900 with no HUD and no lettering
## in the image. An entry with no texture assigned is a card that is not drawn yet; CutIn skips it silently.

## What the card is looked up by: an enemy archetype (&"punk", &"thug", &"bruiser", &"kicker", &"boss") for entrances and
## knockout panels, anything for the title and the end card.
@export var key: StringName = &""
## The big lettering drawn over the art (the mission's name, the enemy's name).
@export var label: String = ""
## The smaller line under it (may be empty).
@export var sub_label: String = ""
## The art. A knockout panel may list several (picked in turn); the others use the first.
@export var textures: Array[Texture2D] = []


## The art of the `index`th showing (wraps), or null when no texture is assigned.
func pick(index: int = 0) -> Texture2D:
	var count := 0
	for texture in textures:
		if texture != null:
			count += 1
	if count == 0:
		return null
	var wanted := posmod(index, count)
	for texture in textures:
		if texture == null:
			continue
		if wanted == 0:
			return texture
		wanted -= 1
	return null
