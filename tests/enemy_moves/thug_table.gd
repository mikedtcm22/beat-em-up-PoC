extends RefCounted
## The Pipe Thug moves as design-fixed data (thug_pipe_1..3; its unarmed attacks are the Punk's, by
## move id), for tests/test_move_data.gd and the archetype's own move tests
## (tests/test_enemy_moves_thug.gd).
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
## The swings two and three are the links of the combo: they start with no wind-up of their own,
## and only if the swing before landed or was blocked, so their startup is a chain link's
## (min_startup is their own startup), not a wind-up. The first swing is the telegraph, floored
## at 18 frames. The third staggers, so the whole combo (3 x 10) holds no knockdown: the 15% rule.
## The pipe's guard drain is the player's own pipe's (PIPE_GUARD_MULT, 1.5).

const FLINCH := CombatTypes.Reaction.FLINCH
const STAGGER := CombatTypes.Reaction.STAGGER
const LIGHT := CombatTypes.HitTier.LIGHT

const MOVES := {
	&"thug_pipe_1": {damage = 10.0, tier = LIGHT, reaction = FLINCH, hitbox = &"sphere:WeaponTip",
			guard_mult = 1.5, recoil = 20, reach_m = 1.3, min_startup = 18},
	&"thug_pipe_2": {damage = 10.0, tier = LIGHT, reaction = FLINCH, hitbox = &"sphere:WeaponTip",
			guard_mult = 1.5, recoil = 14, reach_m = 1.3, min_startup = 12},
	&"thug_pipe_3": {damage = 10.0, tier = LIGHT, reaction = STAGGER, hitbox = &"sphere:WeaponTip",
			guard_mult = 1.5, recoil = 14, reach_m = 1.3, min_startup = 14},
}

## The pipe combo, and (after the pipe is dropped) the Punk's two attacks, by move id.
const ATTACKS := [
	{name = "pipe combo", moves = [&"thug_pipe_1", &"thug_pipe_2", &"thug_pipe_3"], boss = false},
	{name = "two-hit punch", moves = [&"punk_jab", &"punk_cross"], boss = false},
	{name = "shove", moves = [&"punk_shove"], boss = false},
]
