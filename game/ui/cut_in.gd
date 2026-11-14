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
## At most this many cards wait behind the one showing; further ones (never the end card) are dropped.
const MAX_WAITING := 3

## Font sizes (pixels at 1920 x 1080, before cutin_lettering_size) of the big line and the small one.
@export var label_font_size: int = 120
@export var sub_font_size: int = 52
## Panel look: the shear, the ink border and the drop shadow, as the GO cue's.
@export var slant: float = 0.14
@export var border: float = 6.0
@export var shadow_px: float = 8.0

## The set in use (loaded from DEFAULT_SET when none is assigned).
var cards: CutInSet
## Every card that went up, in order: {kind, key}. For bots and tests.
var history: Array[Dictionary] = []

var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _age: float = 0.0
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
	if cards == null and ResourceLoader.exists(DEFAULT_SET):
		cards = load(DEFAULT_SET) as CutInSet
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


## Step `delta` seconds of game time: the title waits for the first frame, the card up counts its hold down.
func advance(delta: float) -> void:
	if _title_pending:
		_title_pending = false
		if is_enabled() and cards != null:
			_enqueue(Kind.TITLE, &"title", cards.title, cards.title.pick() if cards.title else null)
	if is_showing() and not is_enabled():
		_queue.clear()
		_finish(false)
		return
	if not is_showing():
		return
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
	if enemy.archetype == &"" or cards == null or not is_enabled():
		return
	if _seen.has(enemy.archetype):
		return
	_seen[enemy.archetype] = true
	var entry := cards.entrance_for(enemy.archetype)
	if entry != null:
		_enqueue(Kind.ENTRANCE, enemy.archetype, entry, entry.pick())


func _on_ko(victim: Node3D, _hit: HitInfo) -> void:
	var enemy := victim as EnemyActor
	if enemy != null and enemy.archetype != &"":
		_last_ko = enemy.archetype


func _on_arena_cleared(arena: Node3D) -> void:
	if cards == null or not is_enabled() or arena == null:
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
	if cards == null or not is_enabled() or cards.mission_end == null:
		return
	_enqueue(Kind.END, &"mission_end", cards.mission_end, cards.mission_end.pick())


## Queue a card (unless it has no texture, or a knockout panel would pile up) and start it when none is up.
func _enqueue(kind: int, key: StringName, entry: CutInEntry, texture: Texture2D) -> void:
	if entry == null or texture == null:
		return
	if kind == Kind.KO and (is_showing() or not _queue.is_empty()):
		return
	if kind != Kind.END and _queue.size() >= MAX_WAITING:
		return
	_queue.append({kind = kind, key = key, entry = entry, texture = texture, hold = _hold_for(kind)})
	if not is_showing():
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
	var scale_by: float = Tuning.data.cutin_lettering_size
	var big := roundi(label_font_size * scale_by)
	var small := roundi(sub_font_size * scale_by)
	var font := HudStyle.bold_font()
	var big_size := font.get_string_size(entry.label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, big)
	var sub_text := entry.sub_label
	if kind == Kind.END and _age >= Tuning.data.cutin_end_lock_s:
		sub_text = cards.end_prompt if cards else ""
	var sub_size := font.get_string_size(sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, small) if sub_text != "" else Vector2.ZERO
	var pad := Vector2(48.0, 28.0) * scale_by
	var panel_size := Vector2(maxf(big_size.x, sub_size.x), big_size.y + sub_size.y) + pad * 2.0
	# The title sits low left (the art's subject is up and right), an entrance low centre, the end card centred.
	var centre := Vector2(size.x * 0.5, size.y * 0.5)
	match kind:
		Kind.TITLE:
			centre = Vector2(panel_size.x * 0.5 + size.x * 0.06, size.y * 0.78)
		Kind.ENTRANCE:
			centre = Vector2(size.x * 0.5, size.y * 0.82)
	var panel := Rect2(centre - panel_size * 0.5, panel_size)
	HudStyle.draw_panel(self, panel, slant, HudStyle.PAPER, border, Vector2.ONE * shadow_px, alpha)
	var ink := HudStyle.with_alpha(HudStyle.INK, alpha)
	var x := panel.position.x + pad.x
	var y := panel.position.y + pad.y + (big_size.y + font.get_ascent(big) - font.get_descent(big)) * 0.5
	HudStyle.draw_text(self, Vector2(x, y), entry.label, big, ink)
	if sub_text != "":
		var sub_y := panel.position.y + pad.y + big_size.y + (sub_size.y + font.get_ascent(small) - font.get_descent(small)) * 0.5
		HudStyle.draw_text(self, Vector2(x, sub_y), sub_text, small, HudStyle.with_alpha(HudStyle.TROUGH, alpha))
