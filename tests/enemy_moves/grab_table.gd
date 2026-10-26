extends RefCounted
## The enemy grabs on the player moves as design-fixed data (bruiser_grab, bruiser_headbutt, boss_grab, boss_slam), for tests/test_move_data.gd and
## the archetype's own move tests (tests/test_enemy_moves_grab.gd).
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

## A grab is a pair of moves, one attack: the grab (a hitbox-less telegraph that connects by code at
## its strike frame, or whiffs) and the follow-up, whose startup runs while the player is held (the
## mash window) and whose hit is applied by code at its strike frame. So all four have no hitbox, are
## unblockable and never recoil. The follow-ups' reach_m is the pin distance (Tuning.
## grabbed_pin_distance_m); the grabs' is where they connect (Tuning.enemy_grab_range_m scaled by
## the holder's height over 1.8 m).
##
## The 15% rule: the Bruiser's chain is 0 + 15 = 15, a knockdown at the limit. The boss's is exempt
## (SPEC §4); its slam is HEAVY and THROWN, never FINISHER.

const NONE := CombatTypes.Reaction.NONE
const KNOCKDOWN := CombatTypes.Reaction.KNOCKDOWN
const THROWN := CombatTypes.Reaction.THROWN
const LIGHT := CombatTypes.HitTier.LIGHT
const HEAVY := CombatTypes.HitTier.HEAVY

const MOVES := {
	&"bruiser_grab": {damage = 0.0, tier = LIGHT, reaction = NONE, hitbox = &"none", unblockable = true,
			recoil = 0, reach_m = 1.15, min_startup = 30},
	&"bruiser_headbutt": {damage = 15.0, tier = HEAVY, reaction = KNOCKDOWN, hitbox = &"none", unblockable = true,
			recoil = 0, reach_m = 0.75, min_startup = 30},
	&"boss_grab": {damage = 0.0, tier = LIGHT, reaction = NONE, hitbox = &"none", unblockable = true,
			recoil = 0, reach_m = 1.3, min_startup = 30},
	&"boss_slam": {damage = 25.0, tier = HEAVY, reaction = THROWN, hitbox = &"none", unblockable = true,
			recoil = 0, reach_m = 0.75, min_startup = 30},
}

const ATTACKS := [
	{name = "grab and headbutt", moves = [&"bruiser_grab", &"bruiser_headbutt"], boss = false},
	{name = "grab and slam", moves = [&"boss_grab", &"boss_slam"], boss = true},
]
