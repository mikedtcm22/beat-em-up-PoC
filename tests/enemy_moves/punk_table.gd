extends RefCounted
## The Street Punk moves as design-fixed data (punk_jab, punk_cross, punk_shove), for tests/test_move_data.gd and
## the archetype's own move tests (tests/test_enemy_moves_punk.gd).
##
## MOVES maps a move id to its row:
##   damage, tier (CombatTypes.HitTier), reaction (CombatTypes.Reaction),
##   hitbox     &"sphere:<RigPoint>[,<RigPoint>...]" (point spheres, in order), &"arc" or &"none"
##              (applied by code: grabs' follow-up hits),
##   unblockable (default false), guard_mult (default 1.0), recoil (blocked_recoil_frames),
##   reach_m    the move's MoveData.reach_m (travel included),
##   min_startup the archetype's wind-up floor (18 for grunts, 30 for heavies).
## ATTACKS lists what one attack token buys: {name, moves: [ids in order], boss: bool}.
## test_move_data.gd checks every file against its row and the enemy rules (own id per move,
## no magnetism, no branches or auto_next, startup at least min_startup, a reach, no FINISHER
## tier) and the 15% rule over ATTACKS: a chain with a knockdown, launch or throw costs at most
## 15 damage unless `boss` is true.
##
## The cross is the second link of the two-hit punch: it starts with no wind-up of its own, and
## only if the jab landed or was blocked, so its startup is a chain link's (min_startup 8 is its
## own startup), not a wind-up. The jab and the shove are the telegraphs, floored at 18 frames.

const FLINCH := CombatTypes.Reaction.FLINCH
const STAGGER := CombatTypes.Reaction.STAGGER
const LIGHT := CombatTypes.HitTier.LIGHT

const MOVES := {
	&"punk_jab": {damage = 6.0, tier = LIGHT, reaction = FLINCH, hitbox = &"sphere:RightFistPoint",
			recoil = 20, reach_m = 1.05, min_startup = 18},
	&"punk_cross": {damage = 6.0, tier = LIGHT, reaction = FLINCH, hitbox = &"sphere:LeftFistPoint",
			recoil = 14, reach_m = 1.21, min_startup = 8},
	&"punk_shove": {damage = 6.0, tier = LIGHT, reaction = STAGGER, hitbox = &"sphere:LeftFistPoint,RightFistPoint",
			recoil = 14, reach_m = 0.97, min_startup = 18},
}

const ATTACKS := [
	{name = "two-hit punch", moves = [&"punk_jab", &"punk_cross"], boss = false},
	{name = "shove", moves = [&"punk_shove"], boss = false},
]
