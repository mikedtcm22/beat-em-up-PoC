extends Node
## Milestone 6 playtest verification, VFIX-WORLD: which block of each pair that shares a plane yields it. Run on the level with every
## `yields_to` empty:
##   godot --headless res://tools/solve_insets.tscn --quit-after 900 -- [--min=0.0001] [--scene=res://...]
## It prints `YIELD <section>|<node path under the section>|<path from it to the winner>` for each block that must not draw its
## face where the winner draws the same plane, and `UNSOLVED ...` for a pair of two things that cannot yield (two kit pieces).
## tools/apply_yields.py writes the lines into the section scenes (`yields_to`).
##
## The rule, one total order so no two blocks yield to each other (across two sections the later one yields instead: a block can
## only find a partner that is already in the tree when it builds): a kit piece (it cannot yield) wins over a block, then the bigger
## box over the smaller, then the path. The loser takes the overlap out of its face (InsetBlock, MeshClip).

const Scan := preload("res://tests/m6_coplanar_scan.gd")
const Snapshot := preload("res://tests/m6_collider_snapshot.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var min_area := 0.0001
	var scene := Snapshot.LEVEL
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--min="):
			min_area = float(arg.substr(6))
		if arg.begins_with("--scene="):
			scene = arg.substr(8)
	var holder := Node.new()
	add_child(holder)
	var level := Snapshot.instantiate(scene, holder)
	for i in 3:
		await get_tree().physics_frame
	var pairs := Scan.pairs(level, min_area)
	print("SOLVE ", pairs.size(), " coplanar pairs of ", Scan.drawn_boxes(level).size(), " boxes")
	var wins := {}
	var unsolved := 0
	for pair in pairs:
		var a_owner: Node = pair.a.owner
		var b_owner: Node = pair.b.owner
		if a_owner == b_owner:
			continue
		var winner := a_owner if _beats(pair.a, pair.b) else b_owner
		var loser := b_owner if winner == a_owner else a_owner
		# A block can only find a partner that is already in the tree when it builds, so across sections the later one yields.
		if _section_index(loser, level) < _section_index(winner, level) and winner is LevelBlock:
			var swap := winner
			winner = loser
			loser = swap
		if not loser is LevelBlock:
			print("UNSOLVED %s and %s: %s" % [Scan._name(pair.a), Scan._name(pair.b), pair.text])
			unsolved += 1
			continue
		var key := _section_path(loser, level)
		if not wins.has(key):
			wins[key] = {}
		(wins[key] as Dictionary)[String(loser.get_path_to(winner))] = true
	var yields := 0
	var keys := wins.keys()
	keys.sort()
	for key: String in keys:
		var targets := (wins[key] as Dictionary).keys()
		targets.sort()
		for target: String in targets:
			print("YIELD %s|%s" % [key, target])
			yields += 1
	print("SOLVE done: ", yields, " yields, ", unsolved, " unsolved")
	get_tree().quit()


## Whether `a`'s box wins a shared plane against `b`'s.
func _beats(a: Dictionary, b: Dictionary) -> bool:
	var a_piece := not a.owner is LevelBlock
	var b_piece := not b.owner is LevelBlock
	if a_piece != b_piece:
		return a_piece
	var volume_a: float = (a.box as AABB).get_volume()
	var volume_b: float = (b.box as AABB).get_volume()
	if not is_equal_approx(volume_a, volume_b):
		return volume_a > volume_b
	return String(a.owner.get_path()) < String(b.owner.get_path())


func _section_index(block: Node, level: Node) -> int:
	var up := block
	while up != null and up.get_parent() != null and up.name != &"Geometry":
		up = up.get_parent()
	if up == null or up.get_parent() == null:
		return -1
	return up.get_parent().get_index()


func _section_path(block: Node, level: Node) -> String:
	var up := block
	while up != null and up.get_parent() != null and up.name != &"Geometry":
		up = up.get_parent()
	if up == null or up.get_parent() == null:
		return String(level.get_path_to(block))
	var section := up.get_parent()
	return "%s|%s" % [section.name, String(section.get_path_to(block))]
