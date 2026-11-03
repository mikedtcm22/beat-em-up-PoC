class_name CombatTypes
extends RefCounted
## Shared enums, input ids and physics layers for the combat simulation.

## Impact stack tier (Spec §6). Picked per move.
enum HitTier { LIGHT, HEAVY, FINISHER }

## How a victim reacts to a hit.
enum Reaction {
	NONE,       ## Damage only (e.g. knees on a held enemy still flinch the held pose).
	FLINCH,     ## Short hitstun, small push, interrupts grunt wind-ups.
	STAGGER,    ## Longer stun, directional stumble; the victim can be grabbed.
	KNOCKDOWN,  ## Falls to the ground, then gets up after Tuning.downed_frames.
	LAUNCH,     ## Finisher launch: airborne flying body that knocks down anyone it hits.
	GROUND,     ## Ground hit on an already-downed victim (stomp). Victim stays down.
	THROWN,     ## Thrown by a grab; flies like LAUNCH.
}

## Body region a hurtbox covers.
enum Region { HEAD, TORSO, LEGS }

## Combo branch timing (Spec §4 cadence rules).
enum BranchTiming {
	NORMAL,  ## Press during recovery, or within the grace frames after it.
	PAUSE,   ## Wait Tuning.pause_min_frames..pause_max_frames after recovery ends, then press.
}

## Coarse actor state. Sub-phases (startup/active/recovery) come from the running move.
enum ActorState {
	FREE,       ## Standing or walking; can act.
	ATTACK,     ## Running a MoveData (ground or air).
	AIRBORNE,   ## Jumping or falling under own control.
	DODGE,      ## Sidestep / backstep.
	HITSTUN,    ## Flinch.
	STAGGER,    ## Stumbling; grabbable.
	LAUNCHED,   ## Knocked into the air (knockdown or launch); a flying body.
	DOWNED,     ## Lying on the ground.
	GETUP,      ## Getting up; briefly invulnerable.
	GRABBING,   ## Holding a grabbed enemy.
	GRABBED,    ## Being held.
	THROWN,     ## Flying after a throw; a flying body.
	KO,         ## Knocked out; limp and inert.
	WINDUP,     ## Enemy telegraph before an attack (Milestone 3).
	BLOCK,      ## Holding a guard: frontal hits are blocked (Game-boy-approved addition to Spec §4).
	BLOCKSTUN,  ## Pushed back by a blocked hit; still guarding, can't act.
}

## Input ids fed to ComboParser. P_HOLD is synthesized when P is released after
## being held for Tuning.hold_frames.
const IN_PUNCH := &"P"
const IN_KICK := &"K"
const IN_PUNCH_HOLD := &"P_HOLD"
const IN_BACK := &"RB"

## Branch condition keys (ComboBranch.require).
const COND_DOWNED_TARGET_NEAR := &"downed_target_near"
const COND_AT_APEX := &"at_apex"

## 3D physics layers (1-based layer numbers; see project.godot layer names).
const LAYER_WORLD := 1
const LAYER_PLAYER_BODY := 2
const LAYER_ENEMY_BODY := 3
const LAYER_HURTBOX := 4
const LAYER_PICKUP := 5
const LAYER_DOWNED_BODY := 6
const LAYER_PROJECTILE := 7
## Ragdoll bodies (game/actors/ragdoll.gd): a visual layer that collides with the world
## (and, with Tuning.ragdoll_collide_ragdolls, other ragdolls) only. No actor body, hurtbox
## or hit query ever sees it.
const LAYER_RAGDOLL := 8
## The invisible guard along a level's open edges (Milestone 5, game/level/kit/edge_guard.gd): in the
## player's mask in every state and in a standing enemy's, in no ghost enemy's, so a knocked-down,
## launched or thrown enemy crosses it and a HazardVolume past the lip KOs it. The navmesh bake
## parses it too, so the mesh stops an agent radius short of it.
const LAYER_EDGE_GUARD := 9

## Visual layers (1-based). Head and neck meshes of the player go on FP_HIDDEN,
## which the first-person camera's cull mask excludes; they still cast shadows.
const VIS_DEFAULT := 1
const VIS_FP_HIDDEN := 2
const VIS_DEBUG := 3


## Bit mask for a 1-based layer number.
static func bit(layer: int) -> int:
	return 1 << (layer - 1)


static func tier_name(tier: int) -> String:
	return HitTier.keys()[tier]


static func reaction_name(reaction: int) -> String:
	return Reaction.keys()[reaction]


static func state_name(state: int) -> String:
	return ActorState.keys()[state]
