extends RefCounted
## M4's row L5 (M4-plan Part B, slice-gate gap 1): the readability metrics R4 and R8 measured with the art
## drawn, beside the proxies' figures, in the same fight and on the same frames. The readability probe
## (readability_probe.gd) measures the primitives that stand in for the art (the view proxies,
## M4-plan A4) and every first-person test is written against them; this measures what the lens draws:
## the skinned triangles of every art rig, each in the pose the render server draws
## (SkinnedView.drawn_pose(): the ragdoll's visual pose while one runs), against the rest of the view.
## One sampler is one fight: the owner calls tick() once per physics tick and report() at the end.
##
## R8, the share of the lens whose nearest surface is an enemy's, is sampled on the probe's cadence on a
## `cols` x rows grid, both ways:
## - proxies: FPView.hits(), the probe's own measure;
## - art: the same grid with the view proxies of every rig whose art is shown taken out, and the
##   nearest of what is left and of SkinnedView.hits() (the triangles) taken in each cell.
## R4, the wind-ups whose chest another enemy hid for over half of its samples, is sampled likewise on
## the probe's cadence from the same wind-ups, both ways: another enemy's meshes as FPView counts them
## (the proxies), and as drawn (its skinned triangles by a native TriangleMesh ray, its primitives, if it
## has no art, as before).
## A wind-up is an enemy of the group in state WINDUP: the state the probe's event is raised from.
##   LOOK-L5 <label> ...   the lines report() returns, for a bot's log

const FPView := preload("res://tests/fp_view.gd")
const SkinnedView := preload("res://tests/skinned_view.gd")

## The node whose subtree the lens is cast against (the room or the bot), the player whose eye is
## the lens, the label of the fight, and the enemies' group.
var root: Node
var player: Node3D
var label: String
var group: StringName = &"ai_enemy"
## The cadence and the grid (the probe's lens_cols, lens_every, occlusion_every, occlusion_margin_m).
var cols: int = 32
var lens_every: int = 10
var occlusion_every: int = 3
var margin_m: float = 0.05

## R8 per sample: the share of the lens the proxies' enemy meshes cover, and the drawn art's; and the
## share of the cells on which the two disagree about "an enemy's".
var proxy_share := PackedFloat32Array()
var art_share := PackedFloat32Array()
var disagree := PackedFloat32Array()
## R4: wind-ups seen, those mostly in the lens, of those the ones another enemy hid (proxies, art),
## and wind-ups that were never sampled.
var windups: int = 0
var in_view: int = 0
var occluded_proxies: int = 0
var occluded_art: int = 0
var unsampled: int = 0
## Ticks seen, and the dearest sample (microseconds): the art sample is the costly part.
var ticks: int = 0
var worst_usec: int = 0

var _records: Dictionary[int, Dictionary] = {}


func _init(p_root: Node, p_player: Node3D, p_label: String) -> void:
	root = p_root
	player = p_player
	label = p_label


## One physics tick: wind-ups begin and end, and R8 and R4 are sampled on their cadence (counted from
## the first tick, so two fights sample the same ticks).
func tick() -> void:
	ticks += 1
	var started := Time.get_ticks_usec()
	var live := _live_enemies()
	_poll_windups(live)
	if lens_every > 0 and ticks % lens_every == 0:
		sample_lens(live)
	if occlusion_every > 0 and ticks % occlusion_every == 0 and not _records.is_empty():
		sample_occlusion(live)
	worst_usec = maxi(worst_usec, Time.get_ticks_usec() - started)


## Every wind-up still open is closed: call it when the fight is over, before report().
func finish() -> void:
	for id: int in _records.keys():
		_close(id)


# --- R8 ------------------------------------------------------------------------------------------------


## R8 now, both ways (see the file's docs).
func sample_lens(live: Array[CombatActor] = []) -> void:
	if live.is_empty():
		live = _live_enemies()
	var cam := lens()
	var hidden_proxies: Array[MeshInstance3D] = []
	for enemy: CombatActor in live:
		for mesh: MeshInstance3D in FPView.meshes_under(enemy):
			if mesh.is_in_group(HumanoidRig.VIEW_PROXY_GROUP) and not mesh.is_visible_in_tree():
				hidden_proxies.append(mesh)
	var proxy_cells := FPView.hits(root, cam, cols)
	var rest_cells := FPView.hits(root, cam, cols, hidden_proxies)
	var rest_depth := FPView.depths(root, cam, cols, hidden_proxies)
	var art_cells := SkinnedView.hits(root, cam, cols)
	var cache: Dictionary[int, bool] = {}
	var covered_proxies := 0
	var covered_art := 0
	var differing := 0
	for i: int in proxy_cells.size():
		var by_proxy := proxy_cells[i] != null and _is_enemy_mesh(proxy_cells[i], cache)
		var by_art := false
		var hit: Dictionary = art_cells[i]
		if not hit.is_empty() and float(hit.depth) < rest_depth[i]:
			by_art = _is_enemy_mesh(hit.mesh, cache)
		elif rest_cells[i] != null:
			by_art = _is_enemy_mesh(rest_cells[i], cache)
		covered_proxies += int(by_proxy)
		covered_art += int(by_art)
		differing += int(by_proxy != by_art)
	proxy_share.append(float(covered_proxies) / float(proxy_cells.size()))
	art_share.append(float(covered_art) / float(proxy_cells.size()))
	disagree.append(float(differing) / float(proxy_cells.size()))


# --- R4 ------------------------------------------------------------------------------------------------


## R4 now, both ways, for every wind-up in progress: is its chest in the lens, and is another enemy's
## body in front of it?
func sample_occlusion(live: Array[CombatActor] = []) -> void:
	if live.is_empty():
		live = _live_enemies()
	var cam := lens()
	var inverse := cam.affine_inverse()
	var forward := -cam.basis.z
	var tan_h := tan(deg_to_rad(FPView.HALF_H_DEG))
	var tan_v := tan_h * 9.0 / 16.0
	for id: int in _records.keys():
		var record: Dictionary = _records[id]
		var attacker := record.attacker as CombatActor
		if not is_instance_valid(attacker):
			continue
		record.total += 1
		var chest := attacker.get_chest_position()
		var local := inverse * chest
		if local.z >= -FPView.NEAR:
			continue
		var depth := -local.z
		if absf(local.x) / depth > tan_h or absf(local.y) / depth > tan_v:
			continue
		record.in_view += 1
		var to_chest := chest - cam.origin
		var dist := to_chest.length()
		var dir := to_chest / dist
		var by_proxy := false
		var by_art := false
		for other: CombatActor in live:
			if other == attacker:
				continue
			for mesh: MeshInstance3D in FPView.meshes_under(other):
				if mesh.layers & CombatTypes.bit(CombatTypes.VIS_FP_HIDDEN):
					continue
				# The proxies' way: the primitives FPView counts (a rig's view proxies, hidden while its
				# art shows, stand in for it).
				if not by_proxy and FPView.is_drawn(mesh) and FPView.ray_hit(mesh, cam.origin, dir) < dist - margin_m:
					by_proxy = true
				# The drawn way: what is visible. A view proxy hidden by its rig's art is not; the art
				# is, by a native triangle ray at its drawn pose.
				if by_art or not mesh.is_visible_in_tree():
					continue
				if mesh.is_in_group(HumanoidRig.ART_GROUP):
					var soup: Variant = SkinnedView._soup(mesh, other.rig, cam)
					var hit: Dictionary = SkinnedView._ray(soup, cam.origin, dir, forward)
					if not hit.is_empty() and float(hit.depth) / dir.dot(forward) < dist - margin_m:
						by_art = true
				elif FPView.ray_hit(mesh, cam.origin, dir) < dist - margin_m:
					by_art = true
			if by_proxy and by_art:
				break
		record.proxies += int(by_proxy)
		record.art += int(by_art)


# --- Wind-ups ------------------------------------------------------------------------------------------


## Wind-ups open and close with the enemies' state.
func _poll_windups(live: Array[CombatActor]) -> void:
	for enemy: CombatActor in live:
		var id := enemy.get_instance_id()
		if enemy.state == CombatTypes.ActorState.WINDUP and not _records.has(id):
			_records[id] = {attacker = enemy, total = 0, in_view = 0, proxies = 0, art = 0}
			windups += 1
	for id: int in _records.keys():
		var attacker: Variant = _records[id].attacker
		if not is_instance_valid(attacker) or (attacker as CombatActor).state != CombatTypes.ActorState.WINDUP:
			_close(id)


## A wind-up is over: it was in the lens if it was for over half its samples, and then hidden if the
## chest was for over half of them.
func _close(id: int) -> void:
	var record: Dictionary = _records.get(id, {})
	_records.erase(id)
	if record.is_empty():
		return
	if int(record.total) == 0:
		unsampled += 1
	elif int(record.in_view) * 2 > int(record.total):
		in_view += 1
		occluded_proxies += int(int(record.proxies) * 2 > int(record.total))
		occluded_art += int(int(record.art) * 2 > int(record.total))


# --- The lens and the report ---------------------------------------------------------------------------


## The first-person lens as the camera places it (FPView.camera()).
func lens() -> Transform3D:
	var eye: Transform3D = player.call(&"get_eye_transform")
	var look: Basis = player.call(&"get_look_basis")
	return FPView.camera(eye.origin, look)


## The figures: R8's p50, p95 and the share of samples over the probe's p50 bar, for the proxies and
## for the art, the mean of the cells that disagree, R4's counts.
func summary() -> Dictionary:
	return {
		label = label,
		ticks = ticks,
		samples = proxy_share.size(),
		r8_proxies_p50 = _percentile(proxy_share, 0.5), r8_proxies_p95 = _percentile(proxy_share, 0.95),
		r8_art_p50 = _percentile(art_share, 0.5), r8_art_p95 = _percentile(art_share, 0.95),
		r8_proxies_max = _max_of(proxy_share), r8_art_max = _max_of(art_share),
		cells_disagree = _mean(disagree), cells_disagree_max = _max_of(disagree),
		windups = windups, windups_in_view = in_view,
		r4_proxies = occluded_proxies, r4_art = occluded_art, unsampled = unsampled,
		worst_ms = float(worst_usec) / 1000.0,
	}


## The LOOK-L5 lines of the fight (one for R8, one for R4), percentages with one decimal.
func lines() -> PackedStringArray:
	var m := summary()
	var out := PackedStringArray()
	out.append("LOOK-L5 %s R8 (%d samples of the lens, %d ticks): proxies p50 %.1f%% p95 %.1f%% max %.1f%% | art drawn p50 %.1f%% p95 %.1f%% max %.1f%% | difference p50 %+.1f pp p95 %+.1f pp | cells that differ: mean %.1f%% worst %.1f%%" % [
			label, m.samples, m.ticks,
			m.r8_proxies_p50 * 100.0, m.r8_proxies_p95 * 100.0, m.r8_proxies_max * 100.0,
			m.r8_art_p50 * 100.0, m.r8_art_p95 * 100.0, m.r8_art_max * 100.0,
			(m.r8_art_p50 - m.r8_proxies_p50) * 100.0, (m.r8_art_p95 - m.r8_proxies_p95) * 100.0,
			m.cells_disagree * 100.0, m.cells_disagree_max * 100.0])
	out.append("LOOK-L5 %s R4 (%d wind-ups, %d in the lens, %d never sampled): hidden by another enemy: proxies %d of %d | art drawn %d of %d | worst sample %.1f ms" % [
			label, m.windups, m.windups_in_view, m.unsampled, m.r4_proxies, m.windups_in_view,
			m.r4_art, m.windups_in_view, m.worst_ms])
	return out


## `mesh` belongs to an enemy of the group (some node above it, below the root, is in it).
func _is_enemy_mesh(mesh: MeshInstance3D, cache: Dictionary[int, bool]) -> bool:
	var id := mesh.get_instance_id()
	if cache.has(id):
		return cache[id]
	var node: Node = mesh
	var found := false
	while node and node != root:
		if node.is_in_group(group):
			found = true
			break
		node = node.get_parent()
	cache[id] = found
	return found


## Standing-or-fighting enemies of the group: alive, not blinked off (the probe's list).
func _live_enemies() -> Array[CombatActor]:
	var out: Array[CombatActor] = []
	if root == null or not root.is_inside_tree():
		return out
	for node: Node in root.get_tree().get_nodes_in_group(group):
		var enemy := node as CombatActor
		if enemy == null or enemy.is_queued_for_deletion() or enemy.health <= 0.0 or enemy.is_gone():
			continue
		out.append(enemy)
	return out


## The `q` quantile (0 to 1) of `values`, the nearest rank (the probe's).
static func _percentile(values: PackedFloat32Array, q: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(roundi(q * (sorted.size() - 1)), 0, sorted.size() - 1)]


static func _max_of(values: PackedFloat32Array) -> float:
	var out := 0.0
	for value: float in values:
		out = maxf(out, value)
	return out


static func _mean(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for value: float in values:
		sum += value
	return sum / float(values.size())
