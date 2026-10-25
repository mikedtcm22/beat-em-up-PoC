class_name EnemyPosesPunk
extends RefCounted
## The Street Punk's move recipes (punk_jab, punk_cross, punk_shove). Filled by P1-ai.
## A stub until then: no ids, so PlaceholderEnemyPoses falls through to the next file.

## The move ids this file authors (PlaceholderEnemyPoses.recipe() asks before calling recipe()).
const MOVE_IDS: Array[StringName] = []


## The key poses of move `id` on the boxer guard `g` (the weapon guard `wg`), or null.
static func recipe(_id: StringName, _g: Dictionary[StringName, Vector3],
		_wg: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	return null
