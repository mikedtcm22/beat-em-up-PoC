class_name AuditionRoom
extends Node
## The sound audition room (Milestone 6, D24): the training room's keys for hearing every bank by ear,
## which an agent building the sounds cannot do. Presentation only: it asks the AudioDirector to play and
## writes no game state (the one switch it flips is Tuning's Debug `audio_legacy_bank`).
##
## - `]` and `[` page to the next and previous bank (every pool the final or the placeholder bank has,
##   sorted); the page's name and variant count show at the bottom of the screen.
## - `1` to `9` and `0` (the tenth) play that variant of the page's bank in front of the listener, at the
##   volume Tuning gives that pool, through the director's own voices (the same ear as the fight: distance,
##   rear muffle, limiter). A sting plays 2D. A bed (`ambience_*`) becomes the level's bed.
## - `-` toggles old and new: with it on, every pool the Milestone 2 placeholders had plays from them
##   (Debug `audio_legacy_bank`), so a real punch in the training room can be heard both ways.
## - `=` plays the whole bank, one variant after the other.
## The keys are ignored while an overlay (F1, F4) holds the fight (`GameInput.menu_open`), and are
## listed in the help overlay.

## [label, keycode, key text] rows for the help overlay (HelpOverlay.KEY_ROWS lists them; the key text
## stands in for the keycode's own name, which reads "BracketRight").
const HELP_ROWS: Array[Array] = [
	["Sound room: next / previous bank", KEY_BRACKETRIGHT, "]  ["],
	["Sound room: play a take / the bank", KEY_1, "1-9, 0  ="],
	["Sound room: new / old sounds", KEY_MINUS, "-"],
]
## How far in front of the listener a one-shot is played (m), and the gap left after a variant when the
## whole bank plays (s).
const AHEAD_M := 2.0
const BANK_GAP_S := 0.35

var director: AudioDirector
## Every pool that can be heard, sorted, and the page it is on.
var pools: Array[StringName] = []
var page: int = 0

var _label: Label
## Bumped by every key, so a bank still playing out stops when the page changes.
var _run: int = 0


func _ready() -> void:
	name = &"AuditionRoom"
	director = get_tree().get_first_node_in_group(&"audio_director") as AudioDirector
	var canvas := CanvasLayer.new()
	canvas.layer = 60
	add_child(canvas)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_label.add_theme_constant_override("outline_size", 4)
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_label.position += Vector2(16.0, -34.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_label)
	refresh_pools()
	_update_label()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or GameInput.menu_open:
		return
	if handle_key(key.physical_keycode):
		get_viewport().set_input_as_handled()


## Every pool of the final bank and of the placeholders, sorted; the page keeps its pool when it can.
func refresh_pools() -> void:
	var keep: StringName = pools[page] if page < pools.size() else &""
	var seen: Dictionary[StringName, bool] = {}
	if director != null:
		for pool: StringName in director.bank.pools:
			seen[pool] = true
		var legacy := SfxBank.new(AudioDirector.LEGACY_DIR)
		for pool: StringName in legacy.pools:
			seen[pool] = true
	pools.assign(seen.keys())
	pools.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	page = maxi(pools.find(keep), 0)


## Acts on one key (a physical keycode); true when it was one of the room's.
func handle_key(keycode: Key) -> bool:
	if director == null:
		return false
	match keycode:
		KEY_BRACKETRIGHT:
			turn_page(1)
		KEY_BRACKETLEFT:
			turn_page(-1)
		KEY_MINUS:
			toggle_legacy()
		KEY_EQUAL:
			play_bank()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			play_variant(int(keycode) - int(KEY_1))
		KEY_0:
			play_variant(9)
		KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9:
			play_variant(int(keycode) - int(KEY_KP_1))
		KEY_KP_0:
			play_variant(9)
		_:
			return false
	return true


## The current page's pool (empty when there are none).
func current_pool() -> StringName:
	return pools[page] if page < pools.size() else &""


func turn_page(by: int) -> void:
	_run += 1
	if pools.is_empty():
		return
	page = posmod(page + by, pools.size())
	_update_label()


## Old and new (Debug `audio_legacy_bank`).
func toggle_legacy() -> void:
	_run += 1
	Tuning.data.audio_legacy_bank = not Tuning.data.audio_legacy_bank
	_update_label()


## The page's bank, as the director would play it now (the placeholders while old is on and they have it).
func streams() -> Array:
	var pool := current_pool()
	if pool == &"" or director == null:
		return []
	return director.bank_for(pool).pools.get(pool, [])


## Plays variant `index` (0-based) of the page's bank; true when there was one.
func play_variant(index: int) -> bool:
	_run += 1
	var pool := current_pool()
	var list := streams()
	if pool == &"" or index < 0 or index >= list.size():
		return false
	_play(pool, list[index] as AudioStream)
	return true


## Plays every variant of the page's bank in order, each after the last has ended; a key stops it.
func play_bank() -> void:
	_run += 1
	var run := _run
	var pool := current_pool()
	var list := streams()
	for stream: AudioStream in list:
		if run != _run or not is_inside_tree():
			return
		_play(pool, stream)
		if str(pool).begins_with("ambience"):
			return
		await get_tree().create_timer(stream.get_length() + BANK_GAP_S).timeout


func _play(pool: StringName, stream: AudioStream) -> void:
	var name_ := str(pool)
	if name_.begins_with("ambience"):
		director.set_ambience(pool)
	elif name_.begins_with("sting"):
		director.play_stream_2d(pool, stream, AudioDirector.pool_db(pool))
	else:
		var view := director.listener_transform()
		var ahead := -view.basis.z
		ahead.y = 0.0
		ahead = ahead.normalized() if ahead.length_squared() > 0.0001 else Vector3.FORWARD
		director.play_stream(pool, stream, view.origin + ahead * AHEAD_M, AudioDirector.pool_db(pool))
	_update_label()


func _update_label() -> void:
	if _label == null:
		return
	var pool := current_pool()
	var legacy: bool = Tuning.data.audio_legacy_bank
	_label.text = "SOUND ROOM  %s  (%d/%d, %d variants)  %s    ] [ bank   1-9 variant   - old/new   = all" % [
		str(pool) if pool != &"" else "no sounds", page + 1 if pool != &"" else 0, pools.size(), streams().size(),
		"OLD placeholders" if legacy else "new"]
