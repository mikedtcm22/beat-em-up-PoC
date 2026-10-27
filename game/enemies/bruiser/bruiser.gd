class_name Bruiser
extends EnemyActor
## The Bruiser (Milestone 3, SPEC §7): the armored heavy. 80 HP, 2.05 m tall (radius 0.45), a deep
## purple jacket with steel-grey accents (SPEC §10 keeps red for blood, the rear warning and the
## finisher's accents). The wind-up floor is the heavy one (30 frames) and its rear-warning burst the
## larger one (heavy = true), and it is slow (bruiser_speed_mult).
##
## Armor (EnemyActor's flags, set here): a LIGHT hit lands its damage but is absorbed (no flinch, the
## wind-up or strike runs on; presentation shows a grey spark, a low clank and ARMOR in the combat
## log), a HEAVY hit (the hook) or a FINISHER (the uppercut) staggers it, which cancels whatever it
## was doing, and the haymaker (MoveData.breaks_armor) knocks it down and turns the armor off: once
## it is back on its feet, for bruiser_armor_break_s every hit does its ordinary reaction to it (a jab
## flinches it). A killing hit is never softened.
##
## It can be grabbed (the player's LB, then a throw) only while staggered or with its armor off: a
## heavy hit, then LB. A perfect block still staggers it (CombatActor's default, kept on purpose).
##
## Two attacks, picked by bruiser_grab_chance: the grab and headbutt (P2-grab's EnemyHold: a grab
## that connects holds the player until he mashes free, or the headbutt knocks him down for 15) and the
## overhead smash (both fists raised and held, then driven down in front of its chest, a 15-damage
## knockdown; a block drains 60 of the guard and it never recoils). Everything else is EnemyActor's;
## this file is the Bruiser's data, the armor break and a brace when a light hit bounces off.

## The jacket and the accents (cap, wraps, shoes): purple and steel, told from the Punk's teal, the
## Kicker's lime, the Thug's olive and the training dummy's orange.
@export var color: Color = Color(0.34, 0.1, 0.5)
@export var accent: Color = Color(0.74, 0.76, 0.82)

## Whether the haymaker has broken its armor, and the sim frames of it left once it is on its feet.
var _armor_broken: bool = false
var _armor_frames: int = 0
## Sim frames the brace clip still has to play: locomotion keeps its hands off the rig meanwhile.
var _brace_frames: int = 0


func _ready() -> void:
	archetype = &"bruiser"
	heavy = true
	armor_light = true
	armor_heavy_to_stagger = true
	armor_finisher_to_stagger = true
	super._ready()


func _configure_rig(r: HumanoidRig) -> void:
	r.body_color = color
	r.accent_color = accent


## The overhead smash, and the grab and its headbutt (a grab attack: EnemyHold runs it).
func _build_attacks() -> Array[EnemyAttack]:
	return [
		EnemyAttack.of(&"overhead smash", [&"bruiser_smash"], &"", true),
		EnemyAttack.of(&"grab and headbutt", [&"bruiser_grab", &"bruiser_headbutt"], &"bruiser_grab_chance", true, &"grab"),
	]


func _health_tunable() -> StringName:
	return &"bruiser_health"


func _speed_tunable() -> StringName:
	return &"bruiser_speed_mult"


func _cooldown_tunable() -> StringName:
	return &"bruiser_attack_cooldown_s"


# --- Armor ---------------------------------------------------------------------------------------


## True while the haymaker's break is on (it ends bruiser_armor_break_s after the Bruiser is back on
## its feet).
func armor_is_broken() -> bool:
	return _armor_broken


## Sim seconds of broken armor left (counting from the get-up on); 0 when the armor is on.
func armor_break_left_s() -> float:
	return float(_armor_frames) / float(Engine.physics_ticks_per_second) if _armor_broken else 0.0


## The base rule while the armor is on; with it off every hit does what it would do to anyone. A hit
## from a move that breaks armor (the haymaker) keeps its own reaction (a knockdown), and starts the
## break; a killing hit never does.
func _apply_armor(hit: HitInfo) -> void:
	var breaks := hit.move != null and hit.move.breaks_armor and not hit.killed
	if not _armor_broken:
		super._apply_armor(hit)
	if breaks:
		_break_armor()


func _break_armor() -> void:
	_armor_broken = true
	_armor_frames = _frames(Tuning.data.bruiser_armor_break_s)


## Staggered (a heavy hit, a parry) or with its armor off. Otherwise nothing can pick it up.
func can_be_grabbed() -> bool:
	if not super.can_be_grabbed():
		return false
	return state == CombatTypes.ActorState.STAGGER or _armor_broken


## A perfect block staggers the Bruiser that was blocked, as it does any attacker (the base's rule,
## kept on purpose): the parry is the player's answer to the smash, which a plain block only drains.
func _parry_staggers() -> bool:
	return true


## A light hit bounced off: damage landed, no flinch, the move runs on. While it stands with no
## move running the chest pushes out for a moment (the brace clip).
func _on_armor_absorbed(_hit: HitInfo) -> void:
	if state == CombatTypes.ActorState.FREE and _taunt_frames <= 0 and rig.anim_player.has_animation(&"brace"):
		_brace_frames = _frames(rig.anim_player.get_animation(&"brace").length)
		rig.play(&"brace", Tuning.data.reaction_snap_blend_s)


# --- Held by the player ----------------------------------------------------------------------------


## Where it stands while the player holds it: the base's spot (below his HoldPoint) pushed
## bruiser_held_pin_extra_m further out. Bent over in the held pose, a 2.05 m body's head and
## shoulders fill the lens at the 1.8 m body's distance (0.08 m from it, over 80% of the view).
func _pin_spot() -> Vector3:
	var spot := super._pin_spot()
	var away := _flat(spot - holder.global_position)
	if away.length_squared() < 0.0001:
		return spot
	return spot + away.normalized() * Tuning.data.bruiser_held_pin_extra_m


# --- The sim tick ----------------------------------------------------------------------------------


## The armor break and the brace count sim frames (hitstop and slow-mo stretch them), then the
## AI as ever.
func _tick_control() -> void:
	if _armor_broken and not _off_its_feet():
		_armor_frames -= 1
		if _armor_frames <= 0:
			_armor_broken = false
			_armor_frames = 0
	if _brace_frames > 0:
		_brace_frames -= 1
	super._tick_control()


## Down, flying, getting up or dead: the armor break waits.
func _off_its_feet() -> bool:
	return is_downed() or is_flying() or is_ko() or state == CombatTypes.ActorState.GETUP


## While the brace plays the legs and the stop leave the rig alone (the base calls the locomotion
## every tick, which would end the clip at once); the body's own stop is the base's.
func _stop() -> void:
	if _brace_frames > 0:
		sim_velocity.x = 0.0
		sim_velocity.z = 0.0
		_reset_avoidance()
		return
	super._stop()


func _animate_legs() -> void:
	if _brace_frames > 0:
		return
	super._animate_legs()


## A hit that is not absorbed ends the brace (the reaction clip takes over), and the base's.
func _on_hit_received(hit: HitInfo) -> void:
	_brace_frames = 0
	super._on_hit_received(hit)


## A fresh standing state (bots, debug tools): the armor is on and no brace is playing.
func reset_state() -> void:
	_armor_broken = false
	_armor_frames = 0
	_brace_frames = 0
	super.reset_state()


## F3: the base text plus a mark while its armor is off.
func debug_state_text() -> String:
	var text := super.debug_state_text()
	if _armor_broken:
		text += "  ARMOR OFF %.1f" % armor_break_left_s()
	return text
