class_name RearWarning
extends Control
## The rear-attack warning (Spec §8; M3-plan Part B §B1): a comic burst (VfxArt "rear_warning")
## in the top-left and top-right corners of the HUD that lights when an enemy starts winding up
## an attack the player cannot see coming. Child of the HUD, driven by GameHud.advance().
## Presentation only: it subscribes to CombatEvents and reads the actors and the player's look,
## and writes no game state.
##
## **Trigger**, on CombatEvents.windup_started(attacker, move) (so on the wind-up's first frame):
## the rule is ViewGeometry.warning_corner() with the flat bearing from the player's look
## (look_yaw, never a camera) to the attacker, its flat distance, its reach (the attacker's
## warning_reach_m(move) if it has that method, else move.reach_m) and the "Rear warning"
## tunables: more than rear_warning_angle_deg off the look and within reach plus
## rear_warning_range_margin_m. Behind-left lights the top-left corner, behind-right the
## top-right, and within rear_warning_behind_deg of directly behind both. The side is fixed
## when the wind-up starts (rear_warning_follow_turn re-runs the rule every frame instead, so
## the warning goes while the player faces the attacker and returns if they turn away).
##
## **End**, on the first of: hit_landed with that attacker (blocked hits included),
## attack_whiffed, windup_ended(attacker, true), grabbed (the attacker holding), ko, vanished;
## and, polled in advance(), the attacker freed, out of WINDUP and ATTACK, or running another
## move. Never on windup_ended(attacker, false): that is the strike coming out, and the warning
## stays until it lands.
##
## **Several attackers**: one burst per corner, brightness 1 + rear_warning_brightness_step x
## (n - 1) for the n live wind-ups on that side (a "both" one counts on both), and it pulses
## again when n rises. A heavy attacker (its `heavy` property, read duck-typed) makes that
## corner's burst rear_warning_heavy_scale times larger (SPEC §8's "larger for the Bruiser and
## boss", at every size setting: the normal burst is held to the corner over that scale, so the
## heavy one fits it). The burst pops in, beats rear_warning_pulses times, then holds; it always
## lies inside the reserved top corner (Spec §5, 20% of the width and of the height), whatever
## rear_warning_size says.
## Hidden while the player's health is 0 (the KO view) with rear_warning_hide_in_ko.

## A corner lit, or one more attacker joined it: its side (&"left" or &"right"), how many
## wind-ups it now stands for, and whether one of them is heavy. Bots print it as W+.
signal shown(side: StringName, count: int, heavy: bool)
## A corner went dark. Bots print it as W-. (Not `hidden`: CanvasItem already has a signal of
## that name, which a script cannot redefine, and a bot connecting `hidden` would get that one.)
signal cleared(side: StringName)

## The two corners.
const SIDES: Array[StringName] = [&"left", &"right"]
## Spec §5 keeps the top 20% x 20% of each side corner clear for the warning.
const CORNER_SHARE := 0.2

## One live wind-up the warning stands for.
class Entry:
	extends RefCounted
	var attacker: Node3D
	var move_id: StringName
	var reach_m: float = 0.0
	var heavy: bool = false
	## &"left", &"right", &"both", or &"" (follow-turn only: the rule says no, for now).
	var side: StringName = &""

var _texture: Texture2D
## Attacker instance id -> its live wind-up.
var _entries: Dictionary[int, Entry] = {}
var _player: PlayerCharacter
## Per side: wind-ups standing for it, whether one is heavy, seconds since it last (re)pulsed.
var _counts: Dictionary[StringName, int] = {&"left": 0, &"right": 0}
var _heavy: Dictionary[StringName, bool] = {&"left": false, &"right": false}
var _age: Dictionary[StringName, float] = {&"left": 0.0, &"right": 0.0}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A 512 px texture drawn at a fraction of that shimmers without mipmaps; loading it here
	# keeps the first warning from reading the file.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_texture = VfxArt.texture(&"rear_warning")
	visible = false


func _enter_tree() -> void:
	for pair: Array in _subscriptions():
		var event: Signal = pair[0]
		var handler: Callable = pair[1]
		if not event.is_connected(handler):
			event.connect(handler)


func _exit_tree() -> void:
	for pair: Array in _subscriptions():
		var event: Signal = pair[0]
		var handler: Callable = pair[1]
		if event.is_connected(handler):
			event.disconnect(handler)


func _subscriptions() -> Array[Array]:
	return [
		[CombatEvents.windup_started, _on_windup_started], [CombatEvents.windup_ended, _on_windup_ended],
		[CombatEvents.hit_landed, _on_hit_landed], [CombatEvents.attack_whiffed, _on_attack_whiffed],
		[CombatEvents.grabbed, _on_grabbed], [CombatEvents.ko, _on_ko],
		[CombatEvents.vanished, _on_vanished],
	]


## Step the warning by `delta` seconds of game time (the HUD passes its game_delta times
## TimeController.sim_scale(), so a pause holds the pulses and slow-mo stretches them): drop
## wind-ups that are over, follow the player's turn if asked, and age the pulses.
func advance(delta: float) -> void:
	for id: int in _entries.keys():
		var entry := _entries[id]
		if not _is_live(entry):
			_entries.erase(id)
		elif Tuning.data.rear_warning_follow_turn:
			entry.side = _corner_of(entry.attacker, entry.reach_m)
	for side: StringName in SIDES:
		_age[side] += maxf(delta, 0.0)
	_refresh()


## How `side` (&"left" or &"right") looks now: {active, count, heavy, alpha, brightness,
## size_px, scale, rect}. `alpha` and `scale` are what is drawn this frame (the pulse
## included), `size_px` the steady size (the size tunable and, for a heavy burst, the heavy
## scale applied, inside the corner: _steady_size()) and `rect` the drawn rectangle in this
## control's coordinates, always inside the reserved corner. An unlit side is
## {active = false, count = 0, ...} with zero alpha.
func corner_state(side: StringName) -> Dictionary:
	var count: int = _counts.get(side, 0)
	if count <= 0:
		return {active = false, count = 0, heavy = false, alpha = 0.0, brightness = 0.0, size_px = 0.0,
				scale = 1.0, rect = Rect2()}
	var tuning := Tuning.data
	var heavy: bool = _heavy[side]
	var brightness := 1.0 + tuning.rear_warning_brightness_step * float(count - 1)
	var steady_alpha := clampf(tuning.rear_warning_opacity * brightness, 0.0, 1.0)
	var pulse := _pulse(side)
	var beat: float = pulse.beat
	var fade: float = pulse.fade
	var pulse_scale := 1.0 + tuning.rear_warning_pulse_grow * beat * fade
	return {
		active = true,
		count = count,
		heavy = heavy,
		alpha = steady_alpha * lerpf(tuning.rear_warning_min_alpha, 1.0, beat),
		brightness = brightness,
		size_px = _steady_size(heavy),
		scale = pulse_scale,
		rect = burst_rect(side, heavy, pulse_scale),
	}


## The rectangle (this control's coordinates) a burst on `side` is drawn in: centred
## rear_warning_inset_px in from the top corner of the screen, _steady_size() wide
## (rear_warning_base_px x rear_warning_size, x the heavy scale for a heavy one) x `pulse_scale`,
## and pushed in and shrunk as far as it takes to lie inside the reserved corner (20% of the
## width, 20% of the height). The pop is clipped there like the rest, so a heavy burst is never
## smaller than a normal one's, at rest or at the pop's peak.
func burst_rect(side: StringName, heavy: bool = false, pulse_scale: float = 1.0) -> Rect2:
	var corner := _corner_size()
	var edge := minf(corner.x, corner.y)
	var half := minf(_steady_size(heavy) * pulse_scale, edge) * 0.5
	var inset := Tuning.data.rear_warning_inset_px
	var centre := Vector2(clampf(inset, half, corner.x - half), clampf(inset, half, corner.y - half))
	var x := centre.x - half if side == &"left" else size.x - centre.x - half
	return Rect2(Vector2(x, centre.y - half), Vector2.ONE * half * 2.0)


## Wind-ups the warning stands for right now (all sides, a "both" one counted once).
func live_count() -> int:
	return _entries.size()


## True while `attacker` has a live wind-up in the warning, whichever side it lights.
func is_tracking(attacker: Node3D) -> bool:
	return is_instance_valid(attacker) and _entries.has(attacker.get_instance_id())


# --- CombatEvents ------------------------------------------------------------------------


func _on_windup_started(attacker: Node3D, move: MoveData) -> void:
	var actor := attacker as CombatActor
	if actor == null or move == null or actor.team == 0:
		return
	var id := actor.get_instance_id()
	var player := _find_player()
	if player == null or (Tuning.data.rear_warning_hide_in_ko and player.health <= 0.0):
		_forget(id)
		return
	var reach := _reach_of(actor, move)
	var side := _corner_of(actor, reach)
	if side == &"" and not Tuning.data.rear_warning_follow_turn:
		_forget(id)
		return
	# (Following the player's turn, a wind-up the rule does not warn about yet is still tracked:
	# the player may turn away from it.)
	var entry := Entry.new()
	entry.attacker = actor
	entry.move_id = move.id
	entry.reach_m = reach
	entry.heavy = actor.get(&"heavy") == true
	entry.side = side
	_entries[id] = entry
	_refresh()


func _on_windup_ended(attacker: Node3D, interrupted: bool) -> void:
	# Not the strike coming out (interrupted false): the warning holds until it lands.
	if interrupted:
		_end(attacker)


func _on_hit_landed(hit: HitInfo) -> void:
	if hit != null:
		_end(hit.attacker)


func _on_attack_whiffed(attacker: Node3D, _move: MoveData) -> void:
	_end(attacker)


func _on_grabbed(holder: Node3D, _victim: Node3D) -> void:
	_end(holder)


func _on_ko(victim: Node3D, _hit: HitInfo) -> void:
	_end(victim)


func _on_vanished(actor: Node3D) -> void:
	_end(actor)


# --- Entries ----------------------------------------------------------------------------


func _end(attacker: Node3D) -> void:
	if is_instance_valid(attacker):
		_forget(attacker.get_instance_id())


## Drop the wind-up of instance `id` and update the corners at once (the end shows on the
## frame of the event).
func _forget(id: int) -> void:
	if _entries.erase(id):
		_refresh()


## True while the attacker is still in the wind-up or the strike of the move the warning is for.
func _is_live(entry: Entry) -> bool:
	if not is_instance_valid(entry.attacker) or not entry.attacker.is_inside_tree():
		return false
	var actor := entry.attacker as CombatActor
	if actor == null:
		return false
	if actor.state != CombatTypes.ActorState.WINDUP and actor.state != CombatTypes.ActorState.ATTACK:
		return false
	return actor.current_move != null and actor.current_move.id == entry.move_id


## The attacker's reach: its own warning_reach_m(move) if it has one, else the move's reach_m.
func _reach_of(actor: Node3D, move: MoveData) -> float:
	if actor.has_method(&"warning_reach_m"):
		return float(actor.call(&"warning_reach_m", move))
	return move.reach_m


## The rule's verdict for `attacker` seen from the player's look now (ViewGeometry).
func _corner_of(attacker: Node3D, reach_m: float) -> StringName:
	var player := _find_player()
	if player == null or not is_instance_valid(attacker):
		return &""
	var at := attacker.global_position
	var flat := Vector2(at.x - player.global_position.x, at.z - player.global_position.z).length()
	var tuning := Tuning.data
	return ViewGeometry.warning_corner(player.look_bearing_deg(at), flat, reach_m,
			tuning.rear_warning_angle_deg, tuning.rear_warning_behind_deg, tuning.rear_warning_range_margin_m)


func _find_player() -> PlayerCharacter:
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	return _player


## True while the KO view hides the warning (the player's health is 0).
func _suppressed() -> bool:
	if not Tuning.data.rear_warning_hide_in_ko:
		return false
	var player := _find_player()
	return player != null and player.health <= 0.0


## Recount each corner from the live wind-ups, emit shown (a corner lit, or one more joined:
## it pulses again) and cleared, and redraw.
func _refresh() -> void:
	var suppressed := _suppressed()
	for side: StringName in SIDES:
		var count := 0
		var heavy := false
		if not suppressed:
			for entry: Entry in _entries.values():
				if entry.side == side or entry.side == &"both":
					count += 1
					heavy = heavy or entry.heavy
		var before: int = _counts[side]
		_counts[side] = count
		_heavy[side] = heavy
		if count > before:
			_age[side] = 0.0
			shown.emit(side, count, heavy)
		elif count == 0 and before > 0:
			cleared.emit(side)
	var was_visible := visible
	visible = _counts[&"left"] > 0 or _counts[&"right"] > 0
	if visible or was_visible:
		queue_redraw()


# --- Look -------------------------------------------------------------------------------


## The steady size (pixels) of a burst: base x size, held to the corner's short side over the
## heavy scale, then x the heavy scale for a heavy attacker. So a heavy burst is always the
## heavy scale times the normal one and never over the corner (clamping the two apart made them
## meet at the corner's edge: a size above about 1.04 left a heavy burst no bigger than a normal
## one). Past the size where the normal burst reaches that hold, the size setting does nothing:
## the reserved corner (Spec §5) is the limit.
func _steady_size(heavy: bool) -> float:
	var tuning := Tuning.data
	var corner := _corner_size()
	var heavy_scale := maxf(tuning.rear_warning_heavy_scale, 1.0)
	var px := minf(tuning.rear_warning_base_px * tuning.rear_warning_size, minf(corner.x, corner.y) / heavy_scale)
	return px * heavy_scale if heavy else px


func _corner_size() -> Vector2:
	return size * CORNER_SHARE


## Where `side`'s burst is in its pulses: `beat` is 1 at the pop and at each pulse's
## boundary and 0 mid-pulse (1 once they are over), `fade` is 1 at the pop and 0 when the
## last pulse ends.
func _pulse(side: StringName) -> Dictionary:
	var tuning := Tuning.data
	var total := float(tuning.rear_warning_pulses) * tuning.rear_warning_pulse_s
	var age: float = _age[side]
	if total <= 0.0 or age >= total:
		return {beat = 1.0, fade = 0.0}
	var done := age / total
	return {
		beat = 0.5 + 0.5 * cos(TAU * float(tuning.rear_warning_pulses) * done),
		fade = 1.0 - done,
	}


func _draw() -> void:
	if _texture == null:
		return
	for side: StringName in SIDES:
		var state := corner_state(side)
		if not state.active:
			continue
		var brightness: float = state.brightness
		draw_texture_rect(_texture, state.rect, false, Color(brightness, brightness, brightness, state.alpha))
