class_name EnemyNamedPoses
extends RefCounted
## The named (non-move) animations every enemy archetype shares: `taunt` (a posture gesture of
## about 1.1 s, guard to an open-handed beckon and back; never a cocked fist, so it can't be
## mistaken for a wind-up). Filled by P1-ai. A stub until then: it holds the stance.


## The named animation `id` (taunt) on the stance `g`:
## `{length: float, keys: Array[PlaceholderAnims.PoseKey]}`.
static func named(_id: StringName, g: Dictionary[StringName, Vector3]) -> Dictionary:
	return PlaceholderEnemyPoses.stance_named(g, 1.1)
