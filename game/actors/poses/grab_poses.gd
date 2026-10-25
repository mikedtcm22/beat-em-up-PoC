class_name GrabPoses
extends RefCounted
## The enemy grab poses (Milestone 3): the recipes of bruiser_grab, bruiser_headbutt, boss_grab
## and boss_slam, and the named holds: `hold_collar` (the holder upright, both fists at the
## victim's collar at HoldPoint distance), `held_collar` (the victim upright, leaning a little
## toward the holder: a struggle loop) and `held_lift` (held_collar with HIPS_POS raised: the
## slam's wind-up). Filled by P2-grab. A stub until then: no recipes, and the named clips hold
## the stance.

## The move ids this file authors (PlaceholderEnemyPoses.recipe() asks before calling recipe()).
const MOVE_IDS: Array[StringName] = []


## The key poses of move `id` on the boxer guard `g` (the weapon guard `wg`), or null.
static func recipe(_id: StringName, _g: Dictionary[StringName, Vector3],
		_wg: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	return null


## The named hold animation `id` (hold_collar, held_collar, held_lift) on the stance `g`:
## `{length: float, keys: Array[PlaceholderAnims.PoseKey]}`.
static func named(_id: StringName, g: Dictionary[StringName, Vector3]) -> Dictionary:
	return PlaceholderEnemyPoses.stance_named(g, 1.0)
