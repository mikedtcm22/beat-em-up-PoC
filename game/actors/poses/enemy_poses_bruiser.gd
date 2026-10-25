class_name EnemyPosesBruiser
extends RefCounted
## The Bruiser's move recipes (bruiser_smash) and its named `brace` clip (armor shrugging off
## a light hit). Filled by P3-bruiser. A stub until then: no recipes, and `brace` holds the
## stance.

## The move ids this file authors (PlaceholderEnemyPoses.recipe() asks before calling recipe()).
const MOVE_IDS: Array[StringName] = []


## The key poses of move `id` on the boxer guard `g` (the weapon guard `wg`), or null.
static func recipe(_id: StringName, _g: Dictionary[StringName, Vector3],
		_wg: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	return null


## The named animation `id` (brace) on the stance `g`:
## `{length: float, keys: Array[PlaceholderAnims.PoseKey]}`.
static func named(_id: StringName, g: Dictionary[StringName, Vector3]) -> Dictionary:
	return PlaceholderEnemyPoses.stance_named(g, 0.3)
