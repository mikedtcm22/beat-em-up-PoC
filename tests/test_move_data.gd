extends GutTest
## Checks the move resources against docs/ARCHITECTURE.md ("Moves (Spec §4) and their
## data", "Move sets", "Branches") and the Spec §4 combo tables.
##
## Loads the .tres files and walks the branch graph directly (no ComboParser), so these
## tests pin the data, not the cadence logic. Only design-fixed values are pinned: damage,
## tiers, reactions, the exact branch graph, rig points, arc angles and camera ranges.
## Frame data, knockback and radii are tuning values and only get sanity checks.
##
## Knockback uses the radial hit frame HitDetector builds: z points along the horizontal
## direction from attacker to victim (positive pushes the victim away), x is its right,
## y is up. ARCHITECTURE.md still describes the attacker-facing frame and lists the back
## elbow as 0,2,-4; under the radial frame that would pull a victim behind the attacker
## forward through them, so the data uses +4 (see tools/gen_moves.gd).

const MOVES_DIR := "res://game/combat/moves/"
const SETS_DIR := "res://game/combat/movesets/"
const SET_IDS := [&"ground", &"air", &"hold", &"weapon"]
## Combo notation separator for a pause branch, as written in Spec §4 ("K · K").
const PAUSE_MARK := "·"

const LIGHT := CombatTypes.HitTier.LIGHT
const HEAVY := CombatTypes.HitTier.HEAVY
const FINISHER := CombatTypes.HitTier.FINISHER
const FLINCH := CombatTypes.Reaction.FLINCH
const STAGGER := CombatTypes.Reaction.STAGGER
const KNOCKDOWN := CombatTypes.Reaction.KNOCKDOWN
const LAUNCH := CombatTypes.Reaction.LAUNCH
const GROUND := CombatTypes.Reaction.GROUND
const THROWN := CombatTypes.Reaction.THROWN

## Every move id in the ARCHITECTURE table: [damage, tier, reaction].
const TABLE := {
	&"jab_1": [6.0, LIGHT, FLINCH],
	&"jab_2": [6.0, LIGHT, FLINCH],
	&"hook": [8.0, HEAVY, STAGGER],
	&"uppercut": [12.0, FINISHER, LAUNCH],
	&"body_flurry": [2.0, LIGHT, FLINCH],
	&"shove": [6.0, FINISHER, STAGGER],
	&"front_kick": [8.0, LIGHT, FLINCH],
	&"roundhouse": [10.0, HEAVY, STAGGER],
	&"spinning_heel": [14.0, FINISHER, KNOCKDOWN],
	&"stomp_kick": [16.0, FINISHER, LAUNCH],
	&"push_kick": [10.0, FINISHER, KNOCKDOWN],
	&"haymaker": [18.0, FINISHER, LAUNCH],
	&"flying_kick": [12.0, HEAVY, KNOCKDOWN],
	&"spin_kick": [10.0, HEAVY, KNOCKDOWN],
	&"back_elbow": [12.0, HEAVY, KNOCKDOWN],
	&"knee": [6.0, LIGHT, FLINCH],
	&"throw": [15.0, HEAVY, THROWN],
	&"stomp": [8.0, LIGHT, GROUND],
	&"pipe_swing_1": [10.0, LIGHT, FLINCH],
	&"pipe_swing_2": [10.0, HEAVY, STAGGER],
	&"pipe_swing_3": [10.0, FINISHER, KNOCKDOWN],
	&"weapon_throw": [15.0, HEAVY, KNOCKDOWN],
	&"impact_body_knockdown": [5.0, HEAVY, KNOCKDOWN],
	&"impact_body_stagger": [0.0, LIGHT, STAGGER],
}

## POINT_SPHERE moves: the rig point of each hitbox, in order.
const SPHERE_POINTS := {
	&"jab_1": [&"LeftFistPoint"],
	&"jab_2": [&"RightFistPoint"],
	&"hook": [&"LeftFistPoint"],
	&"uppercut": [&"RightFistPoint"],
	&"body_flurry": [&"LeftFistPoint", &"RightFistPoint"],
	&"shove": [&"LeftFistPoint", &"RightFistPoint"],
	&"front_kick": [&"RightFootPoint"],
	&"roundhouse": [&"RightFootPoint"],
	&"stomp_kick": [&"RightFootPoint"],
	&"push_kick": [&"RightFootPoint"],
	&"haymaker": [&"RightFistPoint"],
	&"flying_kick": [&"RightFootPoint"],
	&"knee": [&"RightKneePoint"],
	&"stomp": [&"RightFootPoint"],
	&"pipe_swing_1": [&"WeaponTip"],
	&"pipe_swing_2": [&"WeaponTip"],
	&"pipe_swing_3": [&"WeaponTip"],
}

## ARC moves: [half_angle_deg, center_yaw_deg], plus the height band where the table lists one.
const ARCS := {
	&"spinning_heel": [75.0, 0.0, Vector2(0.3, 1.8)],
	&"spin_kick": [180.0, 0.0],
	&"back_elbow": [50.0, 180.0],
}

## Moves with no hitbox: their hit is applied by code (held victim, projectile, body impact).
const NO_HITBOX := [&"throw", &"weapon_throw", &"impact_body_knockdown", &"impact_body_stagger"]

## Moves that do not use target magnetism; every other move does.
const NO_MAGNETISM := [
	&"knee", &"spinning_heel", &"spin_kick", &"back_elbow", &"throw", &"weapon_throw",
	&"impact_body_knockdown", &"impact_body_stagger",
]

## Kicks that pitch the first-person camera down (Spec §5: 8-12 degrees, 5 cm drop).
const KICKS := [&"front_kick", &"roundhouse", &"spinning_heel", &"stomp_kick", &"push_kick", &"flying_kick"]

const INPUTS := [CombatTypes.IN_PUNCH, CombatTypes.IN_KICK, CombatTypes.IN_PUNCH_HOLD, CombatTypes.IN_BACK]
const CONDITIONS := [&"", CombatTypes.COND_DOWNED_TARGET_NEAR, CombatTypes.COND_AT_APEX]

const P := CombatTypes.IN_PUNCH
const K := CombatTypes.IN_KICK
const P_HOLD := CombatTypes.IN_PUNCH_HOLD
const RB := CombatTypes.IN_BACK
const NORMAL := CombatTypes.BranchTiming.NORMAL
const PAUSE := CombatTypes.BranchTiming.PAUSE
const DOWNED_NEAR := CombatTypes.COND_DOWNED_TARGET_NEAR
const AT_APEX := CombatTypes.COND_AT_APEX

## ARCHITECTURE "Move sets": each set's root branches, in order, as
## [input, timing, require, target move id].
const EXPECTED_ROOTS := {
	&"ground": [
		[K, NORMAL, DOWNED_NEAR, &"stomp"],
		[K, NORMAL, &"", &"front_kick"],
		[P, NORMAL, &"", &"jab_1"],
		[P_HOLD, NORMAL, &"", &"haymaker"],
		[RB, NORMAL, &"", &"back_elbow"],
	],
	&"air": [
		[K, NORMAL, AT_APEX, &"spin_kick"],
		[K, NORMAL, &"", &"flying_kick"],
	],
	&"hold": [
		[P, NORMAL, &"", &"knee"],
		[K, NORMAL, &"", &"throw"],
	],
	&"weapon": [
		[P, NORMAL, &"", &"pipe_swing_1"],
		[K, NORMAL, DOWNED_NEAR, &"stomp"],
		[K, NORMAL, &"", &"front_kick"],
		[RB, NORMAL, &"", &"back_elbow"],
	],
}

## ARCHITECTURE "Move sets": each set's interrupt branches, same form. Air and hold have none.
const EXPECTED_INTERRUPTS := {
	&"ground": [[RB, NORMAL, &"", &"back_elbow"]],
	&"air": [],
	&"hold": [],
	&"weapon": [[RB, NORMAL, &"", &"back_elbow"]],
}

## ARCHITECTURE "Branches": every move's own branches, in order, same form.
const EXPECTED_BRANCHES := {
	&"jab_1": [[P, NORMAL, &"", &"jab_2"]],
	&"jab_2": [
		[P, NORMAL, &"", &"hook"],
		[K, NORMAL, &"", &"push_kick"],
		[P, PAUSE, &"", &"body_flurry"],
	],
	&"hook": [[P, NORMAL, &"", &"uppercut"]],
	&"uppercut": [],
	&"body_flurry": [],
	&"shove": [],
	&"front_kick": [
		[K, NORMAL, &"", &"roundhouse"],
		[K, PAUSE, &"", &"stomp_kick"],
	],
	&"roundhouse": [[K, NORMAL, &"", &"spinning_heel"]],
	&"spinning_heel": [],
	&"stomp_kick": [],
	&"push_kick": [],
	&"haymaker": [],
	&"flying_kick": [],
	&"spin_kick": [],
	&"back_elbow": [],
	&"knee": [],
	&"throw": [],
	&"stomp": [],
	&"pipe_swing_1": [[P, NORMAL, &"", &"pipe_swing_2"]],
	&"pipe_swing_2": [[P, NORMAL, &"", &"pipe_swing_3"]],
	&"pipe_swing_3": [],
	&"weapon_throw": [],
	&"impact_body_knockdown": [],
	&"impact_body_stagger": [],
}

## ARCHITECTURE "Branches": moves that repeat or chain automatically, as
## [repeat_input, repeat_max, auto_next id]. Every other move has none of these.
const EXPECTED_REPEATS := {
	&"body_flurry": [P, 6, &"shove"],
}


# --- Helpers ----------------------------------------------------------------------------

func _load_move(id: StringName) -> MoveData:
	return load(MOVES_DIR + String(id) + ".tres") as MoveData


func _load_set(id: StringName) -> MoveSet:
	return load(SETS_DIR + String(id) + ".tres") as MoveSet


## Presses `combo` (Spec notation, e.g. "P P · P", where "·" means pause before the next
## press) from `move_set`'s roots and follows the first matching branch each time. Root
## branches ignore timing; later presses only match branches of the same timing. Stops at
## the first press that nothing matches, so the result is then shorter than the combo.
func _walk(move_set: MoveSet, combo: String, conditions: Dictionary = {}) -> Array[MoveData]:
	var moves: Array[MoveData] = []
	var timing := CombatTypes.BranchTiming.NORMAL
	for token: String in combo.split(" ", false):
		if token == PAUSE_MARK:
			timing = CombatTypes.BranchTiming.PAUSE
			continue
		var branch: ComboBranch
		if moves.is_empty():
			branch = _first_match(move_set.root_branches, StringName(token), -1, conditions)
		else:
			branch = _first_match(moves[-1].branches, StringName(token), timing, conditions)
		if branch == null or branch.move == null:
			break
		moves.append(branch.move)
		timing = CombatTypes.BranchTiming.NORMAL
	return moves


## First branch for `input` whose timing matches (any when `timing` < 0) and whose
## `require` condition, if any, is true in `conditions`.
func _first_match(branches: Array[ComboBranch], input: StringName, timing: int,
		conditions: Dictionary) -> ComboBranch:
	for branch: ComboBranch in branches:
		if branch == null or branch.input != input:
			continue
		if timing >= 0 and branch.timing != timing:
			continue
		if branch.require != &"" and not conditions.get(branch.require, false):
			continue
		return branch
	return null


func _ids(moves: Array[MoveData]) -> PackedStringArray:
	var ids := PackedStringArray()
	for move: MoveData in moves:
		ids.append(String(move.id))
	return ids


func _damages(moves: Array[MoveData]) -> PackedFloat64Array:
	var damages := PackedFloat64Array()
	for move: MoveData in moves:
		damages.append(move.damage)
	return damages


## Moves that can follow `move` in a chain: branch targets, then auto_next.
func _next_moves(move: MoveData) -> Array[MoveData]:
	var next: Array[MoveData] = []
	for branch: ComboBranch in move.branches:
		if branch != null and branch.move != null:
			next.append(branch.move)
	if move.auto_next != null:
		next.append(move.auto_next)
	return next


## Index of the first root branch of `move_set` that starts `move_id`, or -1.
func _root_index(move_set: MoveSet, move_id: StringName) -> int:
	for i: int in move_set.root_branches.size():
		var branch := move_set.root_branches[i]
		if branch != null and branch.move != null and branch.move.id == move_id:
			return i
	return -1


## One branch in ARCHITECTURE notation, e.g. "K [downed_target_near] -> stomp" or
## "P (PAUSE) -> body_flurry", so whole lists compare and diff readably.
func _branch_text(input: StringName, timing: int, require: StringName, target: String) -> String:
	var text := String(input)
	if timing != NORMAL:
		text += " (%s)" % CombatTypes.BranchTiming.find_key(timing)
	if require != &"":
		text += " [%s]" % require
	return "%s -> %s" % [text, target]


## The actual branches, in order, in the same notation as `_expected_texts()`.
func _branch_texts(branches: Array[ComboBranch]) -> PackedStringArray:
	var texts := PackedStringArray()
	for branch: ComboBranch in branches:
		if branch == null:
			texts.append("<null branch>")
			continue
		var target := String(branch.move.id) if branch.move != null else "<null move>"
		texts.append(_branch_text(branch.input, branch.timing, branch.require, target))
	return texts


## Expected [input, timing, require, target id] entries in `_branch_texts()` notation.
func _expected_texts(entries: Array) -> PackedStringArray:
	var texts := PackedStringArray()
	for entry: Array in entries:
		texts.append(_branch_text(entry[0], entry[1], entry[2], String(entry[3])))
	return texts


func _resource_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for file: String in DirAccess.get_files_at(MOVES_DIR):
		if file.get_extension() == "tres":
			paths.append(MOVES_DIR + file)
	for set_id: StringName in SET_IDS:
		paths.append(SETS_DIR + String(set_id) + ".tres")
	return paths


# --- Files and table values -------------------------------------------------------------

func test_every_table_move_has_a_matching_file() -> void:
	for id: StringName in TABLE:
		var path := MOVES_DIR + String(id) + ".tres"
		assert_true(ResourceLoader.exists(path), "exists: %s" % path)
		var move := _load_move(id)
		assert_not_null(move, "loads as MoveData: %s" % path)
		if move == null:
			continue
		var row: Array = TABLE[id]
		assert_eq(move.id, id, "id matches the file name: %s" % path)
		assert_eq(move.get_anim(), id, "%s: animation id equals the move id" % id)
		assert_ne(move.display_name, "", "%s: has a display name for the combat log" % id)
		assert_eq(move.damage, row[0], "%s: damage" % id)
		assert_eq(move.tier, row[1], "%s: tier %s" % [id, CombatTypes.tier_name(row[1])])
		assert_eq(move.reaction, row[2], "%s: reaction %s" % [id, CombatTypes.reaction_name(row[2])])
		assert_gte(move.startup, 0, "%s: startup >= 0" % id)
		assert_gte(move.active, 1, "%s: active >= 1" % id)
		assert_gte(move.recovery, 0, "%s: recovery >= 0" % id)
		assert_lte(move.cancel_start, move.recovery, "%s: cancel_start within recovery" % id)


func test_moves_folder_holds_only_table_moves() -> void:
	var files := DirAccess.get_files_at(MOVES_DIR)
	var count := 0
	for file: String in files:
		if file.get_extension() != "tres":
			continue
		count += 1
		assert_true(TABLE.has(StringName(file.get_basename())), "%s is a move id from the table" % file)
	assert_eq(count, TABLE.size(), "one .tres per move id")


func test_move_sets_exist_with_matching_ids() -> void:
	for set_id: StringName in SET_IDS:
		var move_set := _load_set(set_id)
		assert_not_null(move_set, "loads as MoveSet: %s" % set_id)
		if move_set:
			assert_eq(move_set.id, set_id, "move set id matches the file name")
			assert_gt(move_set.root_branches.size(), 0, "%s has roots" % set_id)


func test_flurry_uses_listed_hitstun() -> void:
	assert_eq(_load_move(&"body_flurry").hitstun, 10, "body flurry: FLINCH with hitstun 10")


# --- Spec §4 combos ---------------------------------------------------------------------

func test_combo_punch_chain() -> void:
	var moves := _walk(_load_set(&"ground"), "P P P P")
	assert_eq(_ids(moves), PackedStringArray(["jab_1", "jab_2", "hook", "uppercut"]), "P P P P")
	assert_eq(_damages(moves), PackedFloat64Array([6, 6, 8, 12]), "P P P P damage")


func test_combo_pause_flurry_ends_in_shove() -> void:
	var moves := _walk(_load_set(&"ground"), "P P · P")
	assert_eq(_ids(moves), PackedStringArray(["jab_1", "jab_2", "body_flurry"]), "P P · P")
	assert_eq(_damages(moves), PackedFloat64Array([6, 6, 2]), "P P · P damage")
	var flurry := _load_move(&"body_flurry")
	assert_eq(flurry.repeat_input, CombatTypes.IN_PUNCH, "the flurry repeats on P")
	assert_eq(flurry.repeat_max, 6, "up to 6 repeats")
	assert_eq(flurry.branches.size(), 0, "repeats use repeat_input, never a branch")
	assert_not_null(flurry.auto_next, "the flurry ends in an automatic move")
	if flurry.auto_next:
		assert_eq(flurry.auto_next.id, &"shove", "the flurry's auto_next is the shove")
		assert_eq(flurry.auto_next.damage, 6.0, "shove damage")


func test_combo_kick_chain() -> void:
	var moves := _walk(_load_set(&"ground"), "K K K")
	assert_eq(_ids(moves), PackedStringArray(["front_kick", "roundhouse", "spinning_heel"]), "K K K")
	assert_eq(_damages(moves), PackedFloat64Array([8, 10, 14]), "K K K damage")


func test_combo_pause_stomp_kick() -> void:
	var moves := _walk(_load_set(&"ground"), "K · K")
	assert_eq(_ids(moves), PackedStringArray(["front_kick", "stomp_kick"]), "K · K")
	assert_eq(_damages(moves), PackedFloat64Array([8, 16]), "K · K damage")


func test_combo_push_kick() -> void:
	var moves := _walk(_load_set(&"ground"), "P P K")
	assert_eq(_ids(moves), PackedStringArray(["jab_1", "jab_2", "push_kick"]), "P P K")
	assert_eq(_damages(moves), PackedFloat64Array([6, 6, 10]), "P P K damage")


func test_combo_haymaker() -> void:
	var moves := _walk(_load_set(&"ground"), "P_HOLD")
	assert_eq(_ids(moves), PackedStringArray(["haymaker"]), "P_HOLD")
	assert_eq(_damages(moves), PackedFloat64Array([18]), "haymaker damage")
	assert_true(_load_move(&"haymaker").breaks_armor, "the haymaker breaks armor")


func test_every_chain_ends_in_a_finisher() -> void:
	for combo: String in ["P P P P", "P P · P", "K K K", "K · K", "P P K", "P_HOLD"]:
		var moves := _walk(_load_set(&"ground"), combo)
		assert_gt(moves.size(), 0, "%s resolves" % combo)
		if moves.is_empty():
			continue
		# Follow auto_next to the real end of the chain (flurry -> shove).
		while moves[-1].auto_next != null and moves.size() < 16:
			moves.append(moves[-1].auto_next)
		assert_eq(moves[-1].tier, FINISHER, "%s ends in a finisher (%s)" % [combo, moves[-1].id])
		for i: int in moves.size() - 1:
			assert_ne(moves[i].tier, FINISHER, "%s: %s is not the last hit, so not a finisher" % [combo, moves[i].id])
	var pipe := _walk(_load_set(&"weapon"), "P P P")
	assert_eq(pipe.size(), 3, "the weapon chain resolves")
	if pipe.size() == 3:
		assert_eq(pipe[2].tier, FINISHER, "the weapon chain ends in a finisher")
		assert_ne(pipe[0].tier, FINISHER, "the first weapon swing is not a finisher")
		assert_ne(pipe[1].tier, FINISHER, "the second weapon swing is not a finisher")


func test_finisher_tier_matches_branch_graph() -> void:
	# A move that can continue (branches or auto_next) is never a finisher, and a move that
	# is reached by a branch or auto_next and cannot continue always is.
	var followers: Dictionary[StringName, bool] = {}
	for id: StringName in TABLE:
		for next: MoveData in _next_moves(_load_move(id)):
			followers[next.id] = true
	for id: StringName in TABLE:
		var move := _load_move(id)
		if not _next_moves(move).is_empty():
			assert_ne(move.tier, FINISHER, "%s continues the chain, so it is not a finisher" % id)
		elif followers.has(id):
			assert_eq(move.tier, FINISHER, "%s ends a chain, so it is a finisher" % id)


# --- Exact branch graph -----------------------------------------------------------------

func test_move_sets_match_architecture_exactly() -> void:
	# Whole ordered lists, so an extra, missing or reordered branch (e.g. a spurious
	# conditional root ahead of P -> jab_1) fails even when the combo walks still resolve.
	assert_eq(EXPECTED_ROOTS.size(), SET_IDS.size(), "every move set has expected roots")
	assert_eq(EXPECTED_INTERRUPTS.size(), SET_IDS.size(), "every move set has expected interrupts")
	for set_id: StringName in SET_IDS:
		var move_set := _load_set(set_id)
		assert_not_null(move_set, "loads: %s" % set_id)
		if move_set == null:
			continue
		assert_eq(_branch_texts(move_set.root_branches), _expected_texts(EXPECTED_ROOTS[set_id]),
				"%s: root branches, in order" % set_id)
		assert_eq(_branch_texts(move_set.interrupt_branches), _expected_texts(EXPECTED_INTERRUPTS[set_id]),
				"%s: interrupt branches, in order" % set_id)


func test_move_branches_match_architecture_exactly() -> void:
	for id: StringName in TABLE:
		assert_true(EXPECTED_BRANCHES.has(id), "%s: expected branches are listed" % id)
	assert_eq(EXPECTED_BRANCHES.size(), TABLE.size(), "expected branches cover only table moves")
	for id: StringName in EXPECTED_BRANCHES:
		var move := _load_move(id)
		assert_not_null(move, "loads: %s" % id)
		if move == null:
			continue
		assert_eq(_branch_texts(move.branches), _expected_texts(EXPECTED_BRANCHES[id]),
				"%s: branches, in order" % id)


func test_repeats_and_auto_next_match_architecture_exactly() -> void:
	for id: StringName in TABLE:
		var move := _load_move(id)
		var expected: Array = EXPECTED_REPEATS.get(id, [&"", 0, &""])
		assert_eq(move.repeat_input, expected[0], "%s: repeat_input" % id)
		assert_eq(move.repeat_max, expected[1], "%s: repeat_max" % id)
		var auto_next: StringName = move.auto_next.id if move.auto_next != null else &""
		assert_eq(auto_next, expected[2], "%s: auto_next" % id)


# --- Move sets ----------------------------------------------------------------------------

func test_ground_set_roots() -> void:
	var ground := _load_set(&"ground")
	var downed := {CombatTypes.COND_DOWNED_TARGET_NEAR: true}
	assert_eq(_ids(_walk(ground, "K", downed)), PackedStringArray(["stomp"]), "K near a downed enemy")
	assert_eq(_ids(_walk(ground, "K")), PackedStringArray(["front_kick"]), "plain K")
	assert_eq(_ids(_walk(ground, "P")), PackedStringArray(["jab_1"]), "P")
	assert_eq(_ids(_walk(ground, "RB")), PackedStringArray(["back_elbow"]), "RB")
	var stomp_at := _root_index(ground, &"stomp")
	assert_gte(stomp_at, 0, "ground has a stomp root")
	assert_lt(stomp_at, _root_index(ground, &"front_kick"), "the conditional stomp root comes first")
	if stomp_at >= 0:
		assert_eq(ground.root_branches[stomp_at].require, CombatTypes.COND_DOWNED_TARGET_NEAR,
				"the stomp needs a downed target near")


func test_ground_and_weapon_interrupt_back_elbow() -> void:
	for set_id: StringName in [&"ground", &"weapon"]:
		var move_set := _load_set(set_id)
		var branch := _first_match(move_set.interrupt_branches, CombatTypes.IN_BACK, -1, {})
		assert_not_null(branch, "%s: RB interrupt" % set_id)
		if branch and branch.move:
			assert_eq(branch.move.id, &"back_elbow", "%s: RB interrupt is the back elbow" % set_id)


func test_air_set() -> void:
	var air := _load_set(&"air")
	var apex := {CombatTypes.COND_AT_APEX: true}
	assert_eq(_ids(_walk(air, "K", apex)), PackedStringArray(["spin_kick"]), "K at the apex")
	assert_eq(_ids(_walk(air, "K")), PackedStringArray(["flying_kick"]), "plain K in the air")
	assert_eq(_root_index(air, &"spin_kick"), 0, "the conditional spin kick root comes first")
	assert_eq(air.root_branches[0].require, CombatTypes.COND_AT_APEX, "the spin kick needs the apex")


func test_hold_set() -> void:
	var hold := _load_set(&"hold")
	assert_eq(_ids(_walk(hold, "P")), PackedStringArray(["knee"]), "P while holding")
	assert_eq(_ids(_walk(hold, "K")), PackedStringArray(["throw"]), "K while holding")


func test_weapon_set() -> void:
	var weapon := _load_set(&"weapon")
	var moves := _walk(weapon, "P P P")
	assert_eq(_ids(moves), PackedStringArray(["pipe_swing_1", "pipe_swing_2", "pipe_swing_3"]), "P P P with a weapon")
	assert_eq(_damages(moves), PackedFloat64Array([10, 10, 10]), "weapon swing damage")
	var downed := {CombatTypes.COND_DOWNED_TARGET_NEAR: true}
	assert_eq(_ids(_walk(weapon, "K", downed)), PackedStringArray(["stomp"]), "K near a downed enemy")
	assert_eq(_ids(_walk(weapon, "K")), PackedStringArray(["front_kick"]), "plain K")
	assert_eq(_ids(_walk(weapon, "RB")), PackedStringArray(["back_elbow"]), "RB")
	assert_lt(_root_index(weapon, &"stomp"), _root_index(weapon, &"front_kick"),
			"the conditional stomp root comes first")


# --- Per-move flags -----------------------------------------------------------------------

func test_kick_camera_offsets() -> void:
	for id: StringName in KICKS:
		var move := _load_move(id)
		assert_between(move.camera_pitch_deg, -12.0, -8.0, "%s: camera pitches down 8-12 degrees" % id)
		assert_almost_eq(move.camera_drop_m, 0.05, 0.0001, "%s: camera drops 5 cm" % id)
	var stomp := _load_move(&"stomp")
	assert_almost_eq(stomp.camera_pitch_deg, -25.0, 0.0001, "stomp: camera pitch")
	assert_almost_eq(stomp.camera_drop_m, 0.05, 0.0001, "stomp: camera drop")
	for id: StringName in TABLE:
		if id in KICKS or id == &"stomp" or id == &"spin_kick":
			continue
		var move := _load_move(id)
		assert_eq(move.camera_pitch_deg, 0.0, "%s: no camera pitch" % id)
		assert_eq(move.camera_drop_m, 0.0, "%s: no camera drop" % id)


func test_only_stomp_hits_downed_and_only_haymaker_breaks_armor() -> void:
	for id: StringName in TABLE:
		var move := _load_move(id)
		assert_eq(move.hits_downed, id == &"stomp", "%s: hits_downed" % id)
		assert_eq(move.breaks_armor, id == &"haymaker", "%s: breaks_armor" % id)


func test_magnetism_and_lunge() -> void:
	for id: StringName in TABLE:
		assert_eq(_load_move(id).magnetism, not (id in NO_MAGNETISM), "%s: magnetism" % id)
	var flying := _load_move(&"flying_kick")
	assert_almost_eq(flying.lunge, 2.0, 0.0001, "flying kick lunges up to 2 m")
	assert_almost_eq(flying.free_lunge, 2.0, 0.0001, "flying kick lunges 2 m with no target")


func test_back_elbow_pushes_victim_away() -> void:
	# Radial frame: +z pushes the victim away from the attacker. The back elbow hits
	# victims behind, so +z pushes them further behind; a negative z would throw them
	# forward through the attacker.
	assert_gt(_load_move(&"back_elbow").knockback.z, 0.0,
			"back elbow: positive knockback z pushes the victim away from the attacker")


func test_no_move_pulls_its_victim_toward_the_attacker() -> void:
	for id: StringName in TABLE:
		assert_gte(_load_move(id).knockback.z, 0.0,
				"%s: knockback z >= 0 (radial frame: negative z pulls the victim in)" % id)


func test_hitboxes() -> void:
	for id: StringName in TABLE:
		var kinds := int(SPHERE_POINTS.has(id)) + int(ARCS.has(id)) + int(id in NO_HITBOX)
		assert_eq(kinds, 1, "%s: listed in exactly one hitbox table" % id)
	for id: StringName in SPHERE_POINTS:
		var move := _load_move(id)
		var points: Array = SPHERE_POINTS[id]
		assert_eq(move.hitboxes.size(), points.size(), "%s: hitbox count" % id)
		for i: int in mini(points.size(), move.hitboxes.size()):
			var spec := move.hitboxes[i]
			assert_not_null(spec, "%s: hitbox %d" % [id, i])
			if spec == null:
				continue
			assert_eq(spec.kind, HitboxSpec.Kind.POINT_SPHERE, "%s: hitbox %d is a point sphere" % [id, i])
			assert_eq(spec.point, points[i], "%s: hitbox %d rig point" % [id, i])
			assert_gt(spec.radius, 0.0, "%s: hitbox %d radius" % [id, i])
	for id: StringName in ARCS:
		var move := _load_move(id)
		var arc: Array = ARCS[id]
		assert_eq(move.hitboxes.size(), 1, "%s: one arc hitbox" % id)
		if move.hitboxes.is_empty() or move.hitboxes[0] == null:
			continue
		var spec := move.hitboxes[0]
		assert_eq(spec.kind, HitboxSpec.Kind.ARC, "%s: arc hitbox" % id)
		assert_eq(spec.arc_half_angle_deg, arc[0], "%s: arc half-angle" % id)
		assert_eq(spec.arc_center_yaw_deg, arc[1], "%s: arc center yaw" % id)
		assert_gt(spec.arc_radius, 0.0, "%s: arc radius" % id)
		assert_lt(spec.arc_height.x, spec.arc_height.y, "%s: arc height band is (min, max)" % id)
		if arc.size() > 2:
			assert_eq(spec.arc_height, arc[2], "%s: arc height band" % id)
	for id: StringName in NO_HITBOX:
		assert_eq(_load_move(id).hitboxes.size(), 0, "%s: no hitbox" % id)


# --- Graph and files --------------------------------------------------------------------

func test_branches_reference_move_files() -> void:
	var sources: Dictionary[String, Array] = {}
	for id: StringName in TABLE:
		var move := _load_move(id)
		sources[String(id)] = move.branches
		if move.auto_next != null:
			assert_eq(move.auto_next.resource_path, MOVES_DIR + String(move.auto_next.id) + ".tres",
					"%s: auto_next is the shared move file, not an embedded copy" % id)
			assert_ne(move.auto_next.id, id, "%s: auto_next is not itself" % id)
	for set_id: StringName in SET_IDS:
		var move_set := _load_set(set_id)
		sources["%s roots" % set_id] = move_set.root_branches
		sources["%s interrupts" % set_id] = move_set.interrupt_branches
	for source: String in sources:
		for branch: ComboBranch in sources[source]:
			assert_not_null(branch, "%s: branch is set" % source)
			if branch == null:
				continue
			assert_not_null(branch.move, "%s: branch %s has a move" % [source, branch.input])
			assert_true(branch.input in INPUTS, "%s: branch input %s is a CombatTypes.IN_* id" % [source, branch.input])
			assert_true(branch.require in CONDITIONS, "%s: branch require '%s' is known" % [source, branch.require])
			if branch.move == null:
				continue
			assert_ne(String(branch.move.id), source, "%s: does not branch to itself" % source)
			assert_eq(branch.move.resource_path, MOVES_DIR + String(branch.move.id) + ".tres",
					"%s -> %s: shared move file, not an embedded copy" % [source, branch.move.id])


func test_branch_graph_has_no_cycles() -> void:
	var state: Dictionary[StringName, int] = {}
	for id: StringName in TABLE:
		var path: Array[StringName] = []
		assert_eq(_find_cycle(_load_move(id), state, path), "", "no cycle reachable from %s" % id)


## Depth-first search over branches and auto_next. `state`: 1 = on the current path,
## 2 = fully explored. Returns the first cycle found as "a -> b -> a", or "".
func _find_cycle(move: MoveData, state: Dictionary[StringName, int], path: Array[StringName]) -> String:
	var mark: int = state.get(move.id, 0)
	if mark == 2:
		return ""
	path.append(move.id)
	if mark == 1:
		return " -> ".join(PackedStringArray(path))
	state[move.id] = 1
	for next: MoveData in _next_moves(move):
		var cycle := _find_cycle(next, state, path)
		if cycle != "":
			return cycle
	path.pop_back()
	state[move.id] = 2
	return ""


func test_files_load_without_errors() -> void:
	var paths := _resource_paths()
	assert_eq(paths.size(), TABLE.size() + SET_IDS.size(), "every move and move set file")
	for path: String in paths:
		var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		assert_not_null(res, "loads: %s" % path)
	# GUT records every engine error and warning printed during the test (UID mismatches,
	# missing ext_resources, bad property values...).
	var printed := get_errors()
	for error: GutTrackedError in printed:
		gut.p("printed while loading: %s %s" % [error.code, error.rationale])
	assert_eq(printed.size(), 0, "loading the move files prints no errors or warnings")
