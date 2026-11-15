class_name CutIn
extends Control
## The drawn cards (Milestone 7, Phase 3; docs/milestones/M7-comic-3d.md, "The drawn cards"): full-screen stills over the
## game at a few fixed moments, with the lettering drawn here, never baked into the art.
##
## | Card           | Fires on                                                             | Holds                |
## | Mission title  | the mission's first frame of play (a LevelRoot is in the scene)      | cutin_title_hold_s   |
## | Enemy entrance | the first time each enemy archetype enters the tree (Ox: the boss)   | cutin_entrance_hold_s|
## | Knockout panel | CombatEvents.arena_cleared, one per arena, from the last enemy KO'd  | cutin_ko_hold_s      |
## | Mission end    | CombatEvents.level_cleared                                           | until a button       |
##
## Cards only fire inside a mission (a LevelRoot in the scene); the crowd room and the training room show none. The mission title and
## each entrance show once per run of the game unless cutin_replay_on_restart is on. When the level's clear is announced before the last
## arena's (it is), the knockout panel still goes first and the end card follows.
## Cards show only under the trailer look profile with cutins_enabled on, and a card with no texture is skipped
## silently, so the m6 profile, the bots and the tests never see one. A punch, kick, back attack, grab or confirm press skips
## the card up (the end card takes none for cutin_end_lock_s). Cards queue (a knockout panel is dropped when another card
## is up or waiting: it is a beat, not news). While one is up the simulation holds through TimeController.hold_sim(), the one
## allowed write from presentation. Everything else is read-only: it subscribes to CombatEvents and the tree and writes no
## game state. Driven by GameHud.advance() with game time (a pause holds the hold); `advance()` is public for tests.

## A card went up: its kind (Kind) and key (archetype, or &"title" / &"mission_end").
signal card_started(kind: int, key: StringName)
## A card went down; `skipped` is true when a button ended it.
signal card_ended(kind: int, key: StringName, skipped: bool)

enum Kind { TITLE, ENTRANCE, KO, END }

const DEFAULT_SET := "res://game/ui/cut_ins/mission1.tres"
## The inputs that skip a card.
const SKIP_ACTIONS: Array[StringName] = [&"punch", &"kick", &"back_attack", &"grab", &"ui_accept"]
## The caption box's look (sizes, padding, shear, border, shadow, place) and the queue length are the "Cut-ins (M7)" tunables.

## Cards only cost anything under the trailer profile, so the set (about 25 MB of PNGs) is loaded then: threaded, the first time it is
## wanted, and kept for the run of the game (a restart or F6 finds it ready). Never loaded under m6.
static var _held_set: CutInSet
static var _set_requested: bool = false
## What this run of the game has shown already (the title as &"title", enemy archetypes): a restart does not replay them
## unless cutin_replay_on_restart is on.
static var _run_seen: Dictionary[StringName, bool] = {}

## The set in use (the shipped one, DEFAULT_SET, when none is assigned: it loads when the trailer profile first runs).
var cards: CutInSet
## Every card that went up, in order: {kind, key}. For bots and tests.
var history: Array[Dictionary] = []

var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _age: float = 0.0
var _stepped: bool = false
var _title_pending: bool = false
var _seen: Dictionary[StringName, bool] = {}
var _cleared: Dictionary[int, bool] = {}
var _ko_counts: Dictionary[StringName, int] = {}
var _last_ko: StringName = &""


func _init() -> void:
	name = "CutIn"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	CombatEvents.ko.connect(_on_ko)
	CombatEvents.arena_cleared.connect(_on_arena_cleared)
	CombatEvents.level_cleared.connect(_on_level_cleared)
	get_tree().node_added.connect(_on_node_added)
	_title_pending = get_tree().get_first_node_in_group(LevelRoot.GROUP) != null


func _exit_tree() -> void:
	TimeController.hold_sim(self, false)
	if CombatEvents.ko.is_connected(_on_ko):
		CombatEvents.ko.disconnect(_on_ko)
	if CombatEvents.arena_cleared.is_connected(_on_arena_cleared):
		CombatEvents.arena_cleared.disconnect(_on_arena_cleared)
	if CombatEvents.level_cleared.is_connected(_on_level_cleared):
		CombatEvents.level_cleared.disconnect(_on_level_cleared)
	if is_inside_tree() and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


## Forget what this run of the game has shown (the title and the entrances), as a fresh start of the game would.
static func forget_run() -> void:
	_run_seen.clear()


## True when cards may show: the trailer look profile and the cutins_enabled tunable.
static func is_enabled() -> bool:
	return Tuning.data.cutins_enabled and LookProfile.current() == LookProfile.Id.TRAILER


## True while a card is up.
func is_showing() -> bool:
	return not _current.is_empty()


## The kind (Kind) of the card up, -1 when none.
func current_kind() -> int:
	return int(_current.get("kind", -1))


## The key of the card up, &"" when none.
func current_key() -> StringName:
	return _current.get("key", &"")


## Cards waiting behind the one up.
func waiting() -> int:
	return _queue.size()


## Seconds the card up has been showing.
func age() -> float:
	return _age


## Put the card up now away, as a button does (the next waiting card starts).
func skip() -> void:
	if is_showing():
		_finish(true)


## Step `delta` seconds of game time: the title waits for the first frame (and for the set to be loaded), the card up counts its hold down.
## The first step a card gets counts at most cutin_first_step_cap_s: that frame also carries the load of the level.
func advance(delta: float) -> void:
	_ensure_cards()
	if _title_pending and cards == null and is_enabled() and ResourceLoader.exists(DEFAULT_SET):
		# The set is still loading: the street waits for the title (nothing happens behind it), as it will for the card.
		TimeController.hold_sim(self, true)
	elif _title_pending:
		_title_pending = false
		TimeController.hold_sim(self, false)
		if is_enabled() and cards != null and not _was_seen(&"title"):
			_mark_seen(&"title")
			_enqueue(Kind.TITLE, &"title", cards.title, cards.title.pick() if cards.title else null)
	if is_showing() and not is_enabled():
		_queue.clear()
		_finish(false)
		return
	if not is_showing():
		return
	var cap: float = Tuning.data.cutin_first_step_cap_s
	if not _stepped and cap > 0.0 and delta > 0.0:
		delta = minf(delta, cap)
	if delta > 0.0:
		_stepped = true
	_age += delta
	var hold: float = _current.hold
	if hold > 0.0 and _age >= hold:
		_finish(false)
	else:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_showing():
		return
	for action in SKIP_ACTIONS:
		if event.is_action_pressed(action):
			if current_kind() == Kind.END and _age < Tuning.data.cutin_end_lock_s:
				return
			get_viewport().set_input_as_handled()
			skip()
			return


## Take the set when it is wanted (the trailer profile is on): the held one, else the threaded load of DEFAULT_SET (polled each step).
func _ensure_cards() -> void:
	if cards != null or not is_enabled():
		return
	if _held_set == null:
		if not ResourceLoader.exists(DEFAULT_SET):
			return
		if not _set_requested:
			_set_requested = true
			ResourceLoader.load_threaded_request(DEFAULT_SET)
		match ResourceLoader.load_threaded_get_status(DEFAULT_SET):
			ResourceLoader.THREAD_LOAD_LOADED, ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_held_set = ResourceLoader.load_threaded_get(DEFAULT_SET) as CutInSet
				if _held_set == null:
					# The threaded load did not give it: load it here, once.
					_held_set = load(DEFAULT_SET) as CutInSet
			_:
				return
	cards = _held_set


## True inside a mission (a LevelRoot is in the scene): the rooms show no cards.
func _in_mission() -> bool:
	return get_tree() != null and get_tree().get_first_node_in_group(LevelRoot.GROUP) != null


func _was_seen(key: StringName) -> bool:
	return _seen.has(key) or (not Tuning.data.cutin_replay_on_restart and _run_seen.has(key))


func _mark_seen(key: StringName) -> void:
	_seen[key] = true
	_run_seen[key] = true


func _on_node_added(node: Node) -> void:
	var enemy := node as EnemyActor
	if enemy == null:
		return
	# An archetype names itself in _ready() (the Punk) or _init() (the boss): look once it is ready.
	if enemy.is_node_ready():
		_on_enemy_ready(enemy)
	else:
		enemy.ready.connect(_on_enemy_ready.bind(enemy), CONNECT_ONE_SHOT)


func _on_enemy_ready(enemy: EnemyActor) -> void:
	if enemy.archetype == &"" or cards == null or not is_enabled() or not _in_mission():
		return
	if _was_seen(enemy.archetype):
		return
	_mark_seen(enemy.archetype)
	var entry := cards.entrance_for(enemy.archetype)
	if entry != null:
		_enqueue(Kind.ENTRANCE, enemy.archetype, entry, entry.pick())


func _on_ko(victim: Node3D, _hit: HitInfo) -> void:
	var enemy := victim as EnemyActor
	if enemy != null and enemy.archetype != &"":
		_last_ko = enemy.archetype


func _on_arena_cleared(arena: Node3D) -> void:
	if cards == null or not is_enabled() or arena == null or not _in_mission():
		return
	var id := arena.get_instance_id()
	if _cleared.has(id):
		return
	_cleared[id] = true
	var entry := cards.ko_for(_last_ko)
	if entry == null:
		return
	var index: int = _ko_counts.get(_last_ko, 0)
	_ko_counts[_last_ko] = index + 1
	_enqueue(Kind.KO, _last_ko, entry, entry.pick(index))


func _on_level_cleared(_level: Node3D) -> void:
	if cards == null or not is_enabled() or cards.mission_end == null or not _in_mission():
		return
	_enqueue(Kind.END, &"mission_end", cards.mission_end, cards.mission_end.pick())


## Queue a card (unless it has no texture, or a knockout panel would pile up) and start it when none is up.
func _enqueue(kind: int, key: StringName, entry: CutInEntry, texture: Texture2D) -> void:
	if entry == null or texture == null:
		return
	if kind == Kind.KO:
		if _end_just_started():
			# The last arena of the level: the level's clear (the end card) was announced before the arena's. The panel is first.
			_queue.push_front({kind = kind, key = key, entry = entry, texture = texture, hold = _hold_for(kind)})
			_take_back_end()
			return
		if is_showing() or not _queue.is_empty():
			return
	if kind != Kind.END and _queue.size() >= Tuning.data.cutin_max_waiting:
		return
	_queue.append({kind = kind, key = key, entry = entry, texture = texture, hold = _hold_for(kind)})
	if not is_showing():
		_start_next()


## True when the end card went up this very step and has not been drawn yet.
func _end_just_started() -> bool:
	return current_kind() == Kind.END and _age == 0.0 and _queue.is_empty()


## Put the end card, just started, back at the front of the queue (it was never drawn), and start the card that was put ahead of it.
func _take_back_end() -> void:
	var end := _current
	_current = {}
	history.pop_back()
	card_ended.emit(end.kind, end.key, false)
	_queue.insert(1, end)
	_start_next()


func _hold_for(kind: int) -> float:
	match kind:
		Kind.TITLE:
			return Tuning.data.cutin_title_hold_s
		Kind.ENTRANCE:
			return Tuning.data.cutin_entrance_hold_s
		Kind.KO:
			return Tuning.data.cutin_ko_hold_s
	return 0.0


func _start_next() -> void:
	if _queue.is_empty():
		_current = {}
		visible = false
		TimeController.hold_sim(self, false)
		return
	_current = _queue.pop_front()
	_age = 0.0
	_stepped = false
	visible = true
	TimeController.hold_sim(self, true)
	history.append({kind = _current.kind, key = _current.key})
	card_started.emit(_current.kind, _current.key)
	queue_redraw()


func _finish(skipped: bool) -> void:
	var kind: int = _current.kind
	var key: StringName = _current.key
	_current = {}
	card_ended.emit(kind, key, skipped)
	_start_next()


## The card's opacity: it fades in and, with a hold, out (cutin_fade_s).
func alpha_at(age_s: float, hold_s: float) -> float:
	var fade: float = Tuning.data.cutin_fade_s
	if fade <= 0.0:
		return 1.0
	var a := clampf(age_s / fade, 0.0, 1.0)
	if hold_s > 0.0:
		a = minf(a, clampf((hold_s - age_s) / fade, 0.0, 1.0))
	return a


func _draw() -> void:
	if not is_showing():
		return
	var hold: float = _current.hold
	var alpha := alpha_at(_age, hold)
	draw_texture_rect(_current.texture, Rect2(Vector2.ZERO, size), false, Color(1.0, 1.0, 1.0, alpha))
	var entry: CutInEntry = _current.entry
	var kind: int = _current.kind
	if kind == Kind.KO or entry.label == "":
		return
	var d := Tuning.data
	var scale_by: float = d.cutin_lettering_size
	var big := roundi(d.cutin_label_px * scale_by)
	var small := roundi(d.cutin_sub_px * scale_by)
	var font := HudStyle.bold_font()
	var big_size := font.get_string_size(entry.label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, big)
	var sub_text := entry.sub_label
	if kind == Kind.END and _age >= d.cutin_end_lock_s:
		sub_text = cards.end_prompt if cards else ""
	var sub_size := font.get_string_size(sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, small) if sub_text != "" else Vector2.ZERO
	var pad := Vector2(d.cutin_pad_x_px, d.cutin_pad_y_px) * scale_by
	var panel_size := Vector2(maxf(big_size.x, sub_size.x), big_size.y + sub_size.y) + pad * 2.0
	# Every caption is tucked into the bottom-left corner, the shadow and the border inside the frame, clear of the subject.
	var corner := Vector2(size.x * d.cutin_margin_x + d.cutin_border_px, size.y * (1.0 - d.cutin_margin_y) - d.cutin_shadow_px - d.cutin_border_px)
	var panel := Rect2(Vector2(corner.x, corner.y - panel_size.y), panel_size)
	HudStyle.draw_panel(self, panel, d.cutin_slant, HudStyle.PAPER, d.cutin_border_px, Vector2.ONE * d.cutin_shadow_px, alpha)
	var ink := HudStyle.with_alpha(HudStyle.INK, alpha)
	var x := panel.position.x + pad.x
	var y := panel.position.y + pad.y + (big_size.y + font.get_ascent(big) - font.get_descent(big)) * 0.5
	HudStyle.draw_text(self, Vector2(x, y), entry.label, big, ink)
	if sub_text != "":
		var sub_y := panel.position.y + pad.y + big_size.y + (sub_size.y + font.get_ascent(small) - font.get_descent(small)) * 0.5
		HudStyle.draw_text(self, Vector2(x, sub_y), sub_text, small, HudStyle.with_alpha(HudStyle.TROUGH, alpha))
