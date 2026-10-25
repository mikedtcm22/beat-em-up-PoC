class_name HitInfo
extends RefCounted
## Everything known about one landed hit. Built by the simulation, broadcast through
## CombatEvents.hit_landed, read by presentation (VFX, audio, HUD, combat log).

var attacker: Node3D
var victim: Node3D
var move: MoveData
var damage: float = 0.0
var tier: CombatTypes.HitTier = CombatTypes.HitTier.LIGHT
var reaction: CombatTypes.Reaction = CombatTypes.Reaction.FLINCH
var region: CombatTypes.Region = CombatTypes.Region.TORSO
## World-space contact point.
var contact_point: Vector3 = Vector3.ZERO
## Unit horizontal direction the victim is pushed (attacker -> victim).
var direction: Vector3 = Vector3.FORWARD
## World-space knockback velocity applied to the victim (m/s).
var knockback: Vector3 = Vector3.ZERO
## The victim was hit in the back (more than 90 degrees from its facing).
var from_behind: bool = false
## Caused by a flying/staggering body or thrown object rather than a limb.
var is_body_impact: bool = false
## The victim's armor absorbed the reaction (Milestone 3).
var armor_absorbed: bool = false
## This hit reduced the victim to 0 health.
var killed: bool = false
## Engine.get_physics_frames() when the hit landed.
var physics_frame: int = 0
## Attacker's 0-based frame within the move when the hit landed.
var move_frame: int = 0
## 1-based position of this move in the attacker's current chain.
var chain_step: int = 1
## How the move was selected: &"root", &"chain", &"pause", &"repeat", &"auto", &"context".
var input_timing: StringName = &"root"
## The defender's guard stopped this hit (damage is then only the chip).
var blocked: bool = false
## Blocked within the perfect-block window: no chip or guard drain; the attacker staggers.
var perfect_block: bool = false
## This blocked hit emptied the guard meter and broke the guard.
var guard_broken: bool = false


func describe() -> String:
	var move_name: String = move.display_name if move else "body"
	return "%s -> %s  %s  %.0f dmg  %s/%s%s" % [
		str(attacker.name) if attacker else "?",
		str(victim.name) if victim else "?",
		move_name,
		damage,
		CombatTypes.tier_name(tier),
		CombatTypes.reaction_name(reaction),
		" ARMOR" if armor_absorbed else "",
	]
