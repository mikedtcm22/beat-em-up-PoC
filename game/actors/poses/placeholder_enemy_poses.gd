class_name PlaceholderEnemyPoses
extends RefCounted
## Dispatcher for the Milestone 3 enemy move recipes (docs/ARCHITECTURE.md "Enemy AI and the
## rear warning"): PlaceholderPoses._recipe() ends by asking recipe() for an id it does not
## know, which tries each archetype's pose file in turn. Every file has `MOVE_IDS` (the move
## ids it authors) and `static func recipe(id, g, wg) -> PlaceholderPoses.MovePoses` (null for
## an id that is not its own), so parallel builders own disjoint files:
##   EnemyPosesPunk, EnemyPosesKicker, EnemyPosesThug, GrabPoses (the Bruiser's and the boss's
##   grabs), EnemyPosesBruiser, EnemyPosesBoss; the shared named animation `taunt` is
##   EnemyNamedPoses'.
## The shared helpers for those files live here: the held telegraph timing (held()), a small
## tremble for the held key (tremble()) and the stance-holding stub clip (stance_named()).
##
## Authoring rules the move checks enforce (tests/enemy_move_checks.gd): a wind-up key at
## 0.4-0.6 of the startup, a held key near 0.8 (MovePoses.windup_hold_at), upper-arm raises
## within the ragdoll's limits (about 140 degrees forward: a stagger starts a partial ragdoll
## from the pose on screen), explicit HIPS_POS or HIPS_NUDGE on crouched or kicking poses
## (auto-planting puts the lowest sole on the floor). Numbers here are art data.

## Where a held telegraph is cocked, and until where it is held, as shares of the startup.
const WINDUP_AT := 0.5
const WINDUP_HOLD_AT := 0.8
## The small delta a held key adds to the cocked pose so the hold reads as alive (a few
## degrees of shoulder turn), see tremble().
const TREMBLE: Dictionary[StringName, Vector3] = {
	&"Spine": Vector3(-1.5, 2.0, 0.0),
	&"Chest": Vector3(-1.0, 2.5, 0.0),
}


## The key poses of enemy move `id` built on the boxer guard `g` (and the weapon guard `wg`),
## or null when no enemy file authors it.
static func recipe(id: StringName, g: Dictionary[StringName, Vector3],
		wg: Dictionary[StringName, Vector3]) -> PlaceholderPoses.MovePoses:
	if EnemyPosesPunk.MOVE_IDS.has(id):
		return EnemyPosesPunk.recipe(id, g, wg)
	if EnemyPosesKicker.MOVE_IDS.has(id):
		return EnemyPosesKicker.recipe(id, g, wg)
	if EnemyPosesThug.MOVE_IDS.has(id):
		return EnemyPosesThug.recipe(id, g, wg)
	if GrabPoses.MOVE_IDS.has(id):
		return GrabPoses.recipe(id, g, wg)
	if EnemyPosesBruiser.MOVE_IDS.has(id):
		return EnemyPosesBruiser.recipe(id, g, wg)
	if EnemyPosesBoss.MOVE_IDS.has(id):
		return EnemyPosesBoss.recipe(id, g, wg)
	return null


## True when an enemy file authors a recipe for move `id` (HumanoidRig.has_anim()).
static func has_recipe(id: StringName) -> bool:
	return EnemyPosesPunk.MOVE_IDS.has(id) or EnemyPosesKicker.MOVE_IDS.has(id) \
			or EnemyPosesThug.MOVE_IDS.has(id) or GrabPoses.MOVE_IDS.has(id) \
			or EnemyPosesBruiser.MOVE_IDS.has(id) or EnemyPosesBoss.MOVE_IDS.has(id)


## `m` timed as a held telegraph: the wind-up pose is cocked by `windup_at` of the startup
## and held (with `hold_delta` added to it, see tremble()) from `hold_at` until the strike
## drives in over the last of the startup. Returns `m`.
static func held(m: PlaceholderPoses.MovePoses, windup_at: float = WINDUP_AT,
		hold_at: float = WINDUP_HOLD_AT,
		hold_delta: Dictionary[StringName, Vector3] = {}) -> PlaceholderPoses.MovePoses:
	m.windup_at = windup_at
	m.windup_hold_at = hold_at
	m.windup_hold = hold_delta
	return m


## The small delta a held key adds to the cocked pose (TREMBLE).
static func tremble() -> Dictionary[StringName, Vector3]:
	return TREMBLE.duplicate()


## A named-animation result that holds the stance `g` for `length` seconds: what the stubs
## return until their package authors the clip. `{length: float, keys: Array[PoseKey]}`.
static func stance_named(g: Dictionary[StringName, Vector3], length: float) -> Dictionary:
	var keys: Array[PlaceholderAnims.PoseKey] = [
		PlaceholderAnims.PoseKey.new(0.0, g),
		PlaceholderAnims.PoseKey.new(length, g),
	]
	return {length = length, keys = keys}
