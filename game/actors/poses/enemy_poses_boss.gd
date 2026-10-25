class_name EnemyPosesBoss
extends RefCounted
## The boss's move recipes (boss_charge, boss_pound) and its named `run_forward` loop (the
## charge's approach). Filled by P3-boss. A stub until then: no recipes, and `run_forward` holds
## the stance.

## The move ids this file authors (PlaceholderEnemyPoses.recipe() asks before calling recipe()).
const MOVE_IDS: Array[StringName] = []


## The key poses of move `id` on the boxer guard `g` (the weapon guard `wg`), or null.
static func recipe(_id: StringName, _g: Dictionary[StringName, Vector3],
		_wg: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	return null


## The named animation `id` (run_forward) on the stance `g`:
## `{length: float, keys: Array[PlaceholderAnims.PoseKey]}`.
static func named(_id: StringName, g: Dictionary[StringName, Vector3]) -> Dictionary:
	return PlaceholderEnemyPoses.stance_named(g, 0.6)
