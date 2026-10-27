extends RefCounted
## The boss moves as design-fixed data (boss_charge, boss_pound; its grab attack is in grab_table.gd), for
## tests/test_move_data.gd and the archetype's own move tests (tests/test_enemy_moves_boss.gd).
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

## The boss is exempt from the 15% rule (SPEC §4: "except from the boss"): its charge costs 20, its
## pound 15 and its slam (the grab table's) 25, every one a knockdown or a throw. The charge's reach
## includes its dash (A6.2): the arc in front of the shoulder meets a standing body a little past a
## metre, and the 4 m dash carries it on. The pound's is the ring's edge plus the hurtbox. Neither
## recoils when blocked (the boss's rule), and the pound goes through a guard.

const KNOCKDOWN := CombatTypes.Reaction.KNOCKDOWN
const HEAVY := CombatTypes.HitTier.HEAVY

const MOVES := {
	&"boss_charge": {damage = 20.0, tier = HEAVY, reaction = KNOCKDOWN, hitbox = &"arc",
			recoil = 0, reach_m = 5.3, min_startup = 30},
	&"boss_pound": {damage = 15.0, tier = HEAVY, reaction = KNOCKDOWN, hitbox = &"arc", unblockable = true,
			recoil = 0, reach_m = 2.6, min_startup = 30},
}

## Its third attack, the grab and slam, is in grab_table.gd (boss_grab, boss_slam).
const ATTACKS := [
	{name = "shoulder charge", moves = [&"boss_charge"], boss = true},
	{name = "ground pound", moves = [&"boss_pound"], boss = true},
]
