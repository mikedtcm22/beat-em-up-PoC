extends RefCounted
## The Kicker moves as design-fixed data (kicker_jump_kick, kicker_sweep), for tests/test_move_data.gd and
## the archetype's own move tests (tests/test_enemy_moves_kicker.gd).
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
## The jump kick's reach_m includes its leap (free_lunge 1.6 m, applied over the active frames):
## the strike touches a standing body about 1.1 m from where the strike pose stands, so the rear
## warning still fires from 4 m behind (M3-plan A5.2). The sweep is an arc over the legs only
## (height 0 to 0.5 m): a jumping player's legs are above it. Both are telegraphs, floored at 18.

const FLINCH := CombatTypes.Reaction.FLINCH
const KNOCKDOWN := CombatTypes.Reaction.KNOCKDOWN
const LIGHT := CombatTypes.HitTier.LIGHT

const MOVES := {
	&"kicker_jump_kick": {damage = 8.0, tier = LIGHT, reaction = FLINCH, hitbox = &"sphere:RightFootPoint",
			recoil = 20, reach_m = 2.75, min_startup = 18},
	&"kicker_sweep": {damage = 8.0, tier = LIGHT, reaction = KNOCKDOWN, hitbox = &"arc",
			recoil = 14, reach_m = 1.45, min_startup = 18},
}

const ATTACKS := [
	{name = "jump kick", moves = [&"kicker_jump_kick"], boss = false},
	{name = "sweep", moves = [&"kicker_sweep"], boss = false},
]
