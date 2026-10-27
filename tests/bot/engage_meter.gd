extends Node
## The engage meter (P1-engage): how long an enemy that holds an attack token waits at the
## player's nose, and what covers the lens when more than half of it is covered. Test tooling,
## read-only (it reads enemies, the player and the lens and writes nothing); thresholds of the
## package are asserted in tests/test_slice_crowd.gd, this prints the numbers the gate file quotes.
##
## One hold = the span an enemy has_token. Per hold it counts the frames spent
##  - `nose`: in ENGAGE within NOSE_RANGE_M of the player (the step-in's last stretch included),
##  - `still_nose`: ... and standing still there (waiting for the director's go), and
##  - `ring_wait`: in ENGAGE beyond NOSE_RANGE_M and standing still (squared up at its slot,
##    the commit pause and any wait for its go).
## `report()` prints one METER line: holds, how many wound up, the nose seconds per hold (mean,
## p50, p95, max), the nose seconds in all, the share of the act with a holder at the nose, and
## the lens samples over half covered by enemies, by what the most covering enemy was doing.

const FPView := preload("res://tests/fp_view.gd")

## Within this many metres of the player's origin an enemy is "at the nose" (a Punk strikes at
## about 0.9-1.0 m; the lens is a quarter covered by one at 1.3 m).
const NOSE_RANGE_M := 1.3
## Slower than this (m/s) is "standing still".
const STILL_MPS := 0.3
## The lens is sampled every this many physics frames, on a grid this wide (the probe's is 10, 32).
const LENS_EVERY := 5
const LENS_COLS := 32
## More than this share of the lens covered by enemies is a miss of the readability metric R8.
const OVER_HALF := 0.5

var player: Node3D
## Sample the lens (a test that only needs the waits leaves it off: the ray casts cost about 7 ms a sample).
var lens_enabled: bool = true
## Print the director's ETA for every holder standing still at the nose or squared up for over 2.5 s.
var debug: bool = false
## The node whose subtree the lens looks at.
var root: Node
var _frames: int = 0
## enemy instance id -> the hold in progress {frames, nose, still_nose, ring_wait, wound_up}.
var _live_holds: Dictionary = {}
var _done: Array[Dictionary] = []
var _nose_any_frames: int = 0
var _lens_samples: int = 0
var _lens_over: int = 0
var _lens_cover: PackedFloat32Array = PackedFloat32Array()
var _over_by_cause: Dictionary = {}


func attach(host: Node, p_player: Node3D) -> void:
	player = p_player
	root = host
	process_physics_priority = 1000
	host.add_child(self)


func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_frames += 1
	var any_at_nose := false
	var seen: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"ai_enemy"):
		var enemy := node as EnemyActor
		if enemy == null or enemy.health <= 0.0 or enemy.is_queued_for_deletion():
			continue
		var id := enemy.get_instance_id()
		if enemy.has_token:
			seen[id] = true
			var hold: Dictionary = _live_holds.get(id, {})
			if hold.is_empty():
				hold = {frames = 0, nose = 0, still_nose = 0, ring_wait = 0, wound_up = false}
				_live_holds[id] = hold
			hold.frames += 1
			if enemy.state == CombatTypes.ActorState.WINDUP or enemy.state == CombatTypes.ActorState.ATTACK:
				hold.wound_up = true
			elif enemy.ai_state == EnemyActor.AiState.ENGAGE:
				var still := Vector2(enemy.sim_velocity.x, enemy.sim_velocity.z).length() < STILL_MPS
				if _flat_distance(enemy) <= NOSE_RANGE_M:
					hold.nose += 1
					any_at_nose = true
					if still:
						hold.still_nose += 1
						if debug and _frames % 6 == 0:
							var director := EnemyDirector.find(get_tree())
							print("NOSEWAIT f%d %s d=%.2f eta=%.2f gap_ok=%s pstate=%s inv=%s" % [Engine.get_physics_frames(), enemy.name, _flat_distance(enemy), director.call(&"windup_eta_s", enemy), "-", (player as CombatActor).state, (player as CombatActor).is_invulnerable()])
				elif still:
					hold.ring_wait += 1
					if debug and hold.ring_wait > 150 and hold.ring_wait % 30 == 0:
						var director2 := EnemyDirector.find(get_tree())
						var others := ""
						for h in director2.debug_token_holders():
							others += " %s:%s/mv=%s/ls=%.2f/eta=%.2f" % [h.name, h.ai_state_name(), h.current_move.id if h.current_move else "-", h.call(&"last_strike_eta_s"), director2.call(&"windup_eta_s", h)]
						print("RINGWAIT f%d %s waited=%.1fs eta=%.2f pstate=%s holders:%s" % [Engine.get_physics_frames(), enemy.name, hold.ring_wait / 60.0, director2.call(&"windup_eta_s", enemy), (player as CombatActor).state, others])
	if any_at_nose:
		_nose_any_frames += 1
	for id: int in _live_holds.keys():
		if not seen.has(id):
			_done.append(_live_holds[id])
			_live_holds.erase(id)
	if lens_enabled and _frames % LENS_EVERY == 0:
		_sample_lens()


func _flat_distance(node: Node3D) -> float:
	var d := node.global_position - player.global_position
	return Vector2(d.x, d.z).length()


## What the most covering enemy was doing when the lens was over half covered.
func _sample_lens() -> void:
	if not (player.has_method(&"get_eye_transform") and player.has_method(&"get_look_basis")):
		return
	var eye: Transform3D = player.call(&"get_eye_transform")
	var look: Basis = player.call(&"get_look_basis")
	var cells := FPView.hits(root, FPView.camera(eye.origin, look), LENS_COLS)
	if cells.is_empty():
		return
	var per_enemy: Dictionary = {}
	var covered := 0
	for mesh in cells:
		if mesh == null:
			continue
		var enemy := _enemy_of(mesh)
		if enemy:
			covered += 1
			per_enemy[enemy] = int(per_enemy.get(enemy, 0)) + 1
	var share := float(covered) / cells.size()
	_lens_samples += 1
	_lens_cover.append(share)
	if share <= OVER_HALF:
		return
	_lens_over += 1
	var top: EnemyActor
	var top_cells := -1
	for enemy: EnemyActor in per_enemy:
		if int(per_enemy[enemy]) > top_cells:
			top_cells = int(per_enemy[enemy])
			top = enemy
	var cause := _cause(top)
	_over_by_cause[cause] = int(_over_by_cause.get(cause, 0)) + 1


func _enemy_of(mesh: Node) -> EnemyActor:
	var node: Node = mesh
	while node and node != root:
		if node is EnemyActor:
			return node as EnemyActor
		node = node.get_parent()
	return null


func _cause(enemy: EnemyActor) -> String:
	var near := _flat_distance(enemy) <= NOSE_RANGE_M
	match enemy.ai_state:
		EnemyActor.AiState.WINDUP, EnemyActor.AiState.ATTACK:
			return "WINDUP_ATTACK"
		EnemyActor.AiState.ENGAGE:
			if not near:
				return "ENGAGE_far"
			return "ENGAGE_wait" if Vector2(enemy.sim_velocity.x, enemy.sim_velocity.z).length() < STILL_MPS else "ENGAGE_step"
		_:
			return String(enemy.ai_state_name())


## One METER line (and the lens by cause), over everything seen since attach().
func report(title: String) -> String:
	var all: Array[Dictionary] = _done.duplicate()
	for hold: Dictionary in _live_holds.values():
		all.append(hold)
	var hz := float(Engine.physics_ticks_per_second)
	var nose := PackedFloat32Array()
	var still := PackedFloat32Array()
	var ring := PackedFloat32Array()
	var wound := 0
	var nose_total := 0
	var still_total := 0
	for hold: Dictionary in all:
		nose.append(float(hold.nose) / hz)
		still.append(float(hold.still_nose) / hz)
		ring.append(float(hold.ring_wait) / hz)
		nose_total += int(hold.nose)
		still_total += int(hold.still_nose)
		if hold.wound_up:
			wound += 1
	var line := "METER %s: %d holds, %d wound up; at the nose (<= %.1f m, ENGAGE) per hold mean %.2f s p50 %.2f p95 %.2f max %.2f, in all %.1f s (standing still %.1f s); a holder at the nose %.0f%% of %.1f s; squared up beyond it per hold mean %.2f s max %.2f; lens over half %d of %d samples (%.1f%%, p50 %.0f%% p95 %.0f%%) by cause %s" % [
			title, all.size(), wound, NOSE_RANGE_M, _mean(nose), _percentile(nose, 0.5), _percentile(nose, 0.95), _max(nose),
			float(nose_total) / hz, float(still_total) / hz, 100.0 * float(_nose_any_frames) / maxf(float(_frames), 1.0),
			float(_frames) / hz, _mean(ring), _max(ring), _lens_over, _lens_samples,
			100.0 * float(_lens_over) / maxf(float(_lens_samples), 1.0), 100.0 * _percentile(_lens_cover, 0.5),
			100.0 * _percentile(_lens_cover, 0.95), JSON.stringify(_over_by_cause)]
	print(line)
	return line


## The numbers as a dictionary, for a test.
func result() -> Dictionary:
	var hz := float(Engine.physics_ticks_per_second)
	var all: Array[Dictionary] = _done.duplicate()
	for hold: Dictionary in _live_holds.values():
		all.append(hold)
	var nose := PackedFloat32Array()
	var still := PackedFloat32Array()
	var wound := 0
	for hold: Dictionary in all:
		nose.append(float(hold.nose) / hz)
		still.append(float(hold.still_nose) / hz)
		if hold.wound_up:
			wound += 1
	return {
		holds = all.size(), wound_up = wound,
		nose_max_s = _max(nose), nose_mean_s = _mean(nose), nose_p95_s = _percentile(nose, 0.95),
		still_nose_max_s = _max(still), still_nose_mean_s = _mean(still),
		nose_any_share = float(_nose_any_frames) / maxf(float(_frames), 1.0),
		lens_over_share = float(_lens_over) / maxf(float(_lens_samples), 1.0), lens_samples = _lens_samples,
	}


static func _mean(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for value in values:
		sum += value
	return sum / values.size()


static func _max(values: PackedFloat32Array) -> float:
	var best := 0.0
	for value in values:
		best = maxf(best, value)
	return best


static func _percentile(values: PackedFloat32Array, share: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(ceil(share * sorted.size())) - 1, 0, sorted.size() - 1)]
