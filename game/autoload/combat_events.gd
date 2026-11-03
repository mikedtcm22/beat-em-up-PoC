extends Node
## Global combat event bus (autoload "CombatEvents"). The simulation emits; presentation
## (camera, VFX, audio, HUD, rumble, debug) subscribes and never writes game state.

signal attack_started(attacker: Node3D, move: MoveData, chain_step: int, input_timing: StringName)
signal attack_whiffed(attacker: Node3D, move: MoveData)
signal hit_landed(hit: HitInfo)
signal windup_started(attacker: Node3D, move: MoveData)
signal windup_ended(attacker: Node3D, interrupted: bool)
signal knocked_down(victim: Node3D, hit: HitInfo)
signal got_up(actor: Node3D)
signal ko(victim: Node3D, hit: HitInfo)
## A KO'd body blinked off for good (CombatActor.is_gone()): its health bar and anything
## else drawn on it goes.
signal vanished(actor: Node3D)
## Back from a KO: the player getting up, a dummy blinking back in at its post.
signal revived(actor: Node3D)
signal health_changed(actor: Node3D, health: float, max_health: float)
signal actor_state_changed(actor: Node3D, old_state: int, new_state: int)
signal grabbed(holder: Node3D, victim: Node3D)
signal released(holder: Node3D, victim: Node3D)
## A held victim broke free by mashing (CombatActor.break_free(), Milestone 3).
signal grab_escaped(victim: Node3D, holder: Node3D)
signal thrown(holder: Node3D, victim: Node3D)
signal weapon_picked_up(actor: Node3D, weapon: Node3D)
signal weapon_thrown(actor: Node3D, weapon: Node3D)
signal weapon_broke(actor: Node3D, weapon: Node3D)
signal dodged(actor: Node3D, direction: Vector3)
signal jumped(actor: Node3D)
signal landed(actor: Node3D)
signal quick_turned(actor: Node3D)
signal block_started(actor: Node3D)
signal block_ended(actor: Node3D)
## A hit stopped by a guard (also emitted as hit_landed with hit.blocked = true).
signal blocked(defender: Node3D, hit: HitInfo)
signal perfect_blocked(defender: Node3D, hit: HitInfo)
signal guard_broken(defender: Node3D, hit: HitInfo)
signal guard_changed(actor: Node3D, guard: float, max_guard: float)
## A boss entered a new phase (Milestone 3): 1 at spawn is implicit, so this fires on entering
## phase 2.
signal boss_phase_changed(boss: Node3D, phase: int)
## An arena's lock has closed (Milestone 5, game/level/kit/arena.gd): its table starts.
signal arena_locked(arena: Node3D)
## An arena's table has finished and its ahead barrier is opening: the GO cue shows.
signal arena_cleared(arena: Node3D)
## The level's last arena is cleared (LevelRoot): "CLEAR!".
signal level_cleared(level: Node3D)
## An enemy entered a HazardVolume and was KO'd at once.
signal hazard_ko(actor: Node3D, hazard: Node3D)
