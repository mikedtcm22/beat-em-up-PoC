extends RefCounted
## The Bruiser's move as design-fixed data (bruiser_smash; its grab attack, bruiser_grab and
## bruiser_headbutt, is in grab_table.gd), for tests/test_move_data.gd and the archetype's own move
## tests (tests/test_enemy_moves_bruiser.gd).
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

## The overhead smash: 15, HEAVY, a knockdown (the 15% rule's limit, alone in its chain), both fists as
## spheres, blockable (a block drains 60 guard) but with no recoil: a heavy never gives a punish
## window (SPEC §7). Its wind-up is the heavy floor of 30 frames or more.

const KNOCKDOWN := CombatTypes.Reaction.KNOCKDOWN
const HEAVY := CombatTypes.HitTier.HEAVY

const MOVES := {
	&"bruiser_smash": {damage = 15.0, tier = HEAVY, reaction = KNOCKDOWN,
			hitbox = &"sphere:LeftFistPoint,RightFistPoint", recoil = 0, reach_m = 1.3, min_startup = 30},
}

const ATTACKS := [
	{name = "overhead smash", moves = [&"bruiser_smash"], boss = false},
]
