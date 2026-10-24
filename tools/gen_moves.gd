extends SceneTree
## Generates the Milestone 1 move resources with ResourceSaver:
##   game/combat/moves/<id>.tres     one MoveData per move id
##   game/combat/movesets/<id>.tres  ground, air, hold, weapon
## from docs/ARCHITECTURE.md ("Moves (Spec §4) and their data", "Move sets", "Branches").
##
## Usage, from the project root:
##     godot --headless --import --quit     (build the class cache; required on a fresh clone)
##     godot --headless -s tools/gen_moves.gd
##     godot --headless --import --quit     (refresh the editor's file and UID caches)
##     tools/run_tests.sh -gselect=test_move_data
## tools/ has a .gdignore, so the editor never imports this script, but -s loads it by
## path. It uses the contract class_names (MoveData, MoveSet, ComboBranch, CombatTypes),
## which only resolve once .godot/ holds the global class cache; that is why the first
## import step is needed. Without it the script fails to parse ("Could not find type
## MoveData"), writes nothing, and Godot STILL exits 0.
## Success is the "gen_moves: wrote N moves and M move sets" line. When the script runs,
## any failed save or check prints "gen_moves: FAILED" and exits 1, but a parse error
## exits 0, so check for that line rather than trusting the exit code alone.
##
## The .tres files are the runtime source of truth. Re-running this script OVERWRITES
## every move and move set with the starting values below, so once tuning starts either
## edit the values here first, or edit the .tres files in the editor and stop running it.
## Output is deterministic: existing UIDs are kept and ext/sub-resource ids are fixed, so
## a re-run with unchanged values leaves git clean.
##
## Like the editor, ResourceSaver leaves out properties equal to the script's default, so
## a .tres only lists values that differ from move_data.gd / hitbox_spec.gd defaults (the
## jabs list almost nothing). Changing those defaults therefore changes the moves.
##
## Saving order matters: a branch target must already have its final resource_path when
## the move that branches to it is saved, otherwise ResourceSaver embeds a copy of the
## target as a sub_resource. Every MoveData takes over its path right after creation and
## moves are saved depth-first (targets before the moves that reference them).

const MOVES_DIR := "res://game/combat/moves/"
const SETS_DIR := "res://game/combat/movesets/"

const P := CombatTypes.IN_PUNCH
const K := CombatTypes.IN_KICK
const P_HOLD := CombatTypes.IN_PUNCH_HOLD
const RB := CombatTypes.IN_BACK
const DOWNED_NEAR := CombatTypes.COND_DOWNED_TARGET_NEAR
const AT_APEX := CombatTypes.COND_AT_APEX

const NORMAL := CombatTypes.BranchTiming.NORMAL
const PAUSE := CombatTypes.BranchTiming.PAUSE

const LIGHT := CombatTypes.HitTier.LIGHT
const HEAVY := CombatTypes.HitTier.HEAVY
const FINISHER := CombatTypes.HitTier.FINISHER

const FLINCH := CombatTypes.Reaction.FLINCH
const STAGGER := CombatTypes.Reaction.STAGGER
const KNOCKDOWN := CombatTypes.Reaction.KNOCKDOWN
const LAUNCH := CombatTypes.Reaction.LAUNCH
const GROUND := CombatTypes.Reaction.GROUND
const THROWN := CombatTypes.Reaction.THROWN

## Camera offsets from Spec §5 / ARCHITECTURE: kicks pitch down and drop the eye a little.
const KICK_PITCH_DEG := -10.0
const KICK_DROP_M := 0.05
const STOMP_PITCH_DEG := -25.0
## Spinning moves turn the first-person view with the body (Game-boy's second playtest).
const SPIN_FOLLOW := 1.0
## The back elbow turns the view this far toward the elbow (right is negative) and a little
## down, so the player sees it connect, and holds it this many recovery frames before
## turning back. Game-boy asked for about 100-120 degrees, but the elbow drives straight
## back behind the spine: at the 90-degree FOV a 120-degree turn shows neither it nor a body
## straight behind (from about 121 that body's edge, from about 140 the elbow's tip). 150
## puts both in the right half of the view.
const BACK_ELBOW_VIEW_YAW_DEG := -150.0
const BACK_ELBOW_VIEW_PITCH_DEG := -10.0
const BACK_ELBOW_VIEW_HOLD := 6
## The knee tips the view a little further down than the hold already has it
## (Tuning.grab_view_pitch_deg) and drops it like a kick, so the knee shows rising into the
## held body from the bottom of the view (Game-boy, 2026-10-24).
const KNEE_PITCH_DEG := -12.0
const KNEE_DROP_M := 0.05
## Weapons hit a guard harder (the held block): pipe swings drain it 1.5 times as fast.
const PIPE_GUARD_MULT := 1.5

## Fixed ext_resource ids for the contract scripts (keeps re-runs diff-free).
const SCRIPT_IDS: Dictionary[String, String] = {
	"res://game/combat/move_data.gd": "move_data_gd",
	"res://game/combat/move_set.gd": "move_set_gd",
	"res://game/combat/combo_branch.gd": "combo_branch_gd",
	"res://game/combat/hitbox_spec.gd": "hitbox_spec_gd",
}

## Every move, by id, in table order.
var _moves: Dictionary[StringName, MoveData] = {}
## Ids already written to disk.
var _saved: Dictionary[StringName, bool] = {}
## Every file written, mapped to its UID (kept from the previous file when there was one).
var _uids: Dictionary[String, int] = {}
var _failed: bool = false


func _init() -> void:
	_make_dir(MOVES_DIR)
	_make_dir(SETS_DIR)
	_build_moves()
	_build_branches()
	for id: StringName in _moves:
		_save_move_deep(_moves[id], [])
	var sets: Array[MoveSet] = _build_sets()
	for move_set: MoveSet in sets:
		_save(move_set, SETS_DIR + String(move_set.id) + ".tres")
	_add_uids()
	_verify_files()
	if _failed:
		printerr("gen_moves: FAILED")
	else:
		print("gen_moves: wrote %d moves and %d move sets" % [_moves.size(), sets.size()])
	quit(1 if _failed else 0)


# --- Data -------------------------------------------------------------------------------

## The move table (docs/ARCHITECTURE.md). Frame data, knockback and radii are starting
## values for tuning; damage values are fixed by Spec §4.
##
## Knockback is in the radial hit frame used by HitDetector: z points along the horizontal
## direction from attacker to victim (positive pushes the victim away), x is that
## direction's right, y is up. ARCHITECTURE.md and the move_data.gd comment still describe
## the attacker-facing frame, which cannot work for the 360-degree spin kick or the
## rear-facing back elbow (one of them would pull its victims through the attacker).
func _build_moves() -> void:
	# Punch chain: P P P P, P · P (flurry), P P · P (spinning backfist), P P K, and the
	# held-P haymaker.
	_add(&"jab_1", "Jab", Vector3i(4, 3, 10), 6.0, LIGHT, FLINCH, Vector3(0.0, 0.0, 1.5),
			[_sphere(&"LeftFistPoint", 0.12)])
	_add(&"jab_2", "Jab", Vector3i(4, 3, 10), 6.0, LIGHT, FLINCH, Vector3(0.0, 0.0, 1.5),
			[_sphere(&"RightFistPoint", 0.12)])
	_add(&"hook", "Hook", Vector3i(6, 3, 14), 8.0, HEAVY, STAGGER, Vector3(-2.2, 0.0, 0.6),
			[_sphere(&"LeftFistPoint", 0.14)])
	_add(&"uppercut", "Uppercut", Vector3i(8, 3, 22), 12.0, FINISHER, LAUNCH, Vector3(0.0, 6.0, 3.0),
			[_sphere(&"RightFistPoint", 0.14)])
	var flurry := _add(&"body_flurry", "Body Blow", Vector3i(2, 2, 6), 2.0, LIGHT, FLINCH,
			Vector3(0.0, 0.0, 0.3), [_sphere(&"LeftFistPoint", 0.12), _sphere(&"RightFistPoint", 0.12)])
	flurry.hitstun = 10
	_add(&"shove", "Shove", Vector3i(6, 3, 18), 6.0, FINISHER, STAGGER, Vector3(0.0, 0.0, 7.0),
			[_sphere(&"LeftFistPoint", 0.16), _sphere(&"RightFistPoint", 0.16)])
	# A full turn to the right, the back of the right fist whipping in at head height from
	# the right; the victim is knocked down and to the attacker's left, the way the fist sweeps.
	var backfist := _add(&"spinning_backfist", "Spinning Backfist", Vector3i(12, 3, 20), 14.0,
			FINISHER, KNOCKDOWN, Vector3(-1.5, 3.0, 6.0), [_sphere(&"RightFistPoint", 0.15)])
	backfist.camera_spin_follow = SPIN_FOLLOW
	var haymaker := _add(&"haymaker", "Haymaker", Vector3i(14, 3, 26), 18.0, FINISHER, LAUNCH,
			Vector3(0.0, 4.0, 8.0), [_sphere(&"RightFistPoint", 0.16)])
	haymaker.breaks_armor = true

	# Kick chain: K K K, K · K, and the P P K finisher.
	_kick(_add(&"front_kick", "Front Kick", Vector3i(7, 3, 14), 8.0, LIGHT, FLINCH,
			Vector3(0.0, 0.0, 2.0), [_sphere(&"RightFootPoint", 0.15)]))
	_kick(_add(&"roundhouse", "Roundhouse Kick", Vector3i(9, 3, 16), 10.0, HEAVY, STAGGER,
			Vector3(2.0, 0.0, 1.0), [_sphere(&"RightFootPoint", 0.16)]))
	var heel := _add(&"spinning_heel", "Spinning Heel Kick", Vector3i(12, 5, 24), 14.0, FINISHER,
			KNOCKDOWN, Vector3(0.0, 3.0, 6.0), [_arc(1.9, 75.0, 0.0, Vector2(0.3, 1.8))])
	_kick(heel)
	heel.magnetism = false
	heel.camera_spin_follow = SPIN_FOLLOW
	_kick(_add(&"stomp_kick", "Stomp Kick", Vector3i(10, 3, 22), 16.0, FINISHER, LAUNCH,
			Vector3(0.0, 2.0, 10.0), [_sphere(&"RightFootPoint", 0.16)]))
	_kick(_add(&"push_kick", "Push Kick", Vector3i(8, 3, 20), 10.0, FINISHER, KNOCKDOWN,
			Vector3(0.0, 1.5, 9.0), [_sphere(&"RightFootPoint", 0.16)]))

	# Air moves. The spin kick's height band is not in the table: the attacker is up to
	# about 1 m off the ground, so the band reaches below its feet to catch standing torsos.
	var flying := _add(&"flying_kick", "Flying Kick", Vector3i(5, 8, 14), 12.0, HEAVY, KNOCKDOWN,
			Vector3(0.0, 2.0, 5.0), [_sphere(&"RightFootPoint", 0.24)])
	_kick(flying)
	# A diving kick: the camera looks further down so the foot driving at the target shows.
	flying.camera_pitch_deg = -25.0
	flying.lunge = 2.0
	flying.free_lunge = 2.0
	var spin := _add(&"spin_kick", "Spin Kick", Vector3i(6, 10, 16), 10.0, HEAVY, KNOCKDOWN,
			Vector3(0.0, 2.0, 4.0), [_arc(1.8, 180.0, 0.0, Vector2(-0.6, 1.8))])
	spin.magnetism = false
	spin.camera_spin_follow = SPIN_FOLLOW

	# Back elbow: arc centered behind. Height band not in the table: torso and head height.
	# The table lists knockback 0,2,-4 ("pushes back", written for the attacker-facing
	# frame). In the radial frame the victim behind is pushed further behind by +z, so the
	# sign flips here; -4 would throw the victim forward through the attacker.
	var elbow := _add(&"back_elbow", "Back Elbow", Vector3i(5, 3, 18), 12.0, HEAVY, KNOCKDOWN,
			Vector3(0.0, 2.0, 4.0), [_arc(1.4, 50.0, 180.0, Vector2(0.6, 1.8))])
	elbow.magnetism = false
	elbow.camera_yaw_deg = BACK_ELBOW_VIEW_YAW_DEG
	elbow.camera_pitch_deg = BACK_ELBOW_VIEW_PITCH_DEG
	elbow.camera_hold_frames = BACK_ELBOW_VIEW_HOLD

	# Holding an enemy.
	var knee := _add(&"knee", "Knee", Vector3i(5, 3, 12), 6.0, LIGHT, FLINCH, Vector3.ZERO,
			[_sphere(&"RightKneePoint", 0.18)])
	knee.magnetism = false
	knee.camera_pitch_deg = KNEE_PITCH_DEG
	knee.camera_drop_m = KNEE_DROP_M
	var throw := _add(&"throw", "Throw", Vector3i(8, 2, 20), 15.0, HEAVY, THROWN,
			Vector3(0.0, 3.0, 9.0), [])
	throw.magnetism = false

	# Ground hit on a downed enemy.
	var stomp := _add(&"stomp", "Stomp", Vector3i(8, 3, 14), 8.0, LIGHT, GROUND, Vector3.ZERO,
			[_sphere(&"RightFootPoint", 0.22)])
	stomp.hits_downed = true
	stomp.camera_pitch_deg = STOMP_PITCH_DEG
	stomp.camera_drop_m = KICK_DROP_M

	# Weapon (pipe) chain and weapon throw.
	var pipe_1 := _add(&"pipe_swing_1", "Pipe Swing", Vector3i(7, 3, 12), 10.0, LIGHT, FLINCH,
			Vector3(0.0, 0.0, 2.0), [_sphere(&"WeaponTip", 0.18)])
	var pipe_2 := _add(&"pipe_swing_2", "Pipe Backswing", Vector3i(7, 3, 12), 10.0, HEAVY, STAGGER,
			Vector3(1.0, 0.0, 2.0), [_sphere(&"WeaponTip", 0.18)])
	var pipe_3 := _add(&"pipe_swing_3", "Pipe Smash", Vector3i(9, 4, 20), 10.0, FINISHER, KNOCKDOWN,
			Vector3(0.0, 2.0, 6.0), [_sphere(&"WeaponTip", 0.2)])
	for pipe: MoveData in [pipe_1, pipe_2, pipe_3]:
		pipe.guard_damage_mult = PIPE_GUARD_MULT
	var weapon_throw := _add(&"weapon_throw", "Weapon Throw", Vector3i(6, 1, 14), 15.0, HEAVY,
			KNOCKDOWN, Vector3(0.0, 2.0, 6.0), [])
	weapon_throw.magnetism = false

	# Body impacts: applied by code when a flying or shoved body hits someone.
	var fly_body := _add(&"impact_body_knockdown", "Flying Body", Vector3i(0, 1, 0), 5.0, HEAVY,
			KNOCKDOWN, Vector3(0.0, 2.0, 3.0), [])
	fly_body.magnetism = false
	var shoved_body := _add(&"impact_body_stagger", "Stumbling Body", Vector3i(0, 1, 0), 0.0, LIGHT,
			STAGGER, Vector3(0.0, 0.0, 2.0), [])
	shoved_body.magnetism = false

	# Sparring training dummy (the held block's practice partner): a telegraphed right jab.
	# Its startup is the wind-up the dummy shows (ActorState.WINDUP), 24 frames (0.4 s) since
	# Game-boy's second playtest, so a guard raised on reaction parries; no tracking, so
	# turning away or stepping aside makes it miss. Blocked, it recoils for 20 frames: the
	# player's fastest punish (blockstun 10 + cancel 2 + jab startup 4 = 16 frames) must land
	# while it is still recoiling, or blocking opens no punish window.
	var dummy_jab := _add(&"dummy_jab", "Sparring Jab", Vector3i(24, 3, 16), 6.0, LIGHT, FLINCH,
			Vector3(0.0, 0.0, 1.5), [_sphere(&"RightFistPoint", 0.14)])
	dummy_jab.magnetism = false
	dummy_jab.blocked_recoil_frames = 20


## Combo branches (docs/ARCHITECTURE.md "Branches").
func _build_branches() -> void:
	_set_branches(&"jab_1", [
		_branch(P, &"jab_2"),
		_branch(P, &"body_flurry", PAUSE),
	])
	_set_branches(&"jab_2", [
		_branch(P, &"hook"),
		_branch(K, &"push_kick"),
		_branch(P, &"spinning_backfist", PAUSE),
	])
	_set_branches(&"hook", [_branch(P, &"uppercut")])
	var flurry: MoveData = _moves[&"body_flurry"]
	flurry.repeat_input = P
	flurry.repeat_max = 6
	flurry.auto_next = _moves[&"shove"]
	_set_branches(&"front_kick", [
		_branch(K, &"roundhouse"),
		_branch(K, &"stomp_kick", PAUSE),
	])
	_set_branches(&"roundhouse", [_branch(K, &"spinning_heel")])
	_set_branches(&"pipe_swing_1", [_branch(P, &"pipe_swing_2")])
	_set_branches(&"pipe_swing_2", [_branch(P, &"pipe_swing_3")])


## Move sets (docs/ARCHITECTURE.md "Move sets"). Conditional roots go before plain ones.
func _build_sets() -> Array[MoveSet]:
	var sets: Array[MoveSet] = []
	sets.append(_move_set(&"ground", [
		_branch(K, &"stomp", NORMAL, DOWNED_NEAR),
		_branch(K, &"front_kick"),
		_branch(P, &"jab_1"),
		_branch(P_HOLD, &"haymaker"),
		_branch(RB, &"back_elbow"),
	], [_branch(RB, &"back_elbow")]))
	sets.append(_move_set(&"air", [
		_branch(K, &"spin_kick", NORMAL, AT_APEX),
		_branch(K, &"flying_kick"),
	], []))
	sets.append(_move_set(&"hold", [
		_branch(P, &"knee"),
		_branch(K, &"throw"),
	], []))
	sets.append(_move_set(&"weapon", [
		_branch(P, &"pipe_swing_1"),
		_branch(K, &"stomp", NORMAL, DOWNED_NEAR),
		_branch(K, &"front_kick"),
		_branch(RB, &"back_elbow"),
	], [_branch(RB, &"back_elbow")]))
	return sets


# --- Builders ---------------------------------------------------------------------------

## Creates a move, gives it its final resource path and registers it.
func _add(id: StringName, display_name: String, frames: Vector3i, damage: float,
		tier: CombatTypes.HitTier, reaction: CombatTypes.Reaction, knockback: Vector3,
		hitboxes: Array[HitboxSpec]) -> MoveData:
	var move := MoveData.new()
	move.id = id
	move.display_name = display_name
	move.startup = frames.x
	move.active = frames.y
	move.recovery = frames.z
	move.damage = damage
	move.tier = tier
	move.reaction = reaction
	move.knockback = knockback
	for i in hitboxes.size():
		hitboxes[i].resource_scene_unique_id = "hitbox_%d" % i
	move.hitboxes = hitboxes
	move.take_over_path(MOVES_DIR + String(id) + ".tres")
	_moves[id] = move
	return move


func _kick(move: MoveData) -> void:
	move.camera_pitch_deg = KICK_PITCH_DEG
	move.camera_drop_m = KICK_DROP_M


func _sphere(point: StringName, radius: float) -> HitboxSpec:
	var spec := HitboxSpec.new()
	spec.kind = HitboxSpec.Kind.POINT_SPHERE
	spec.point = point
	spec.radius = radius
	return spec


func _arc(radius: float, half_angle_deg: float, center_yaw_deg: float, height: Vector2) -> HitboxSpec:
	var spec := HitboxSpec.new()
	spec.kind = HitboxSpec.Kind.ARC
	spec.arc_radius = radius
	spec.arc_half_angle_deg = half_angle_deg
	spec.arc_center_yaw_deg = center_yaw_deg
	spec.arc_height = height
	return spec


func _branch(input: StringName, target: StringName,
		timing: CombatTypes.BranchTiming = NORMAL, require: StringName = &"") -> ComboBranch:
	if not _moves.has(target):
		_fail("unknown branch target '%s'" % target)
		return null
	var branch := ComboBranch.new()
	branch.input = input
	branch.timing = timing
	branch.move = _moves[target]
	branch.require = require
	return branch


func _set_branches(id: StringName, branches: Array[ComboBranch]) -> void:
	_name_sub_resources(branches, "branch")
	(_moves[id] as MoveData).branches = branches


func _move_set(id: StringName, roots: Array[ComboBranch], interrupts: Array[ComboBranch]) -> MoveSet:
	_name_sub_resources(roots, "root")
	_name_sub_resources(interrupts, "interrupt")
	var move_set := MoveSet.new()
	move_set.id = id
	move_set.root_branches = roots
	move_set.interrupt_branches = interrupts
	return move_set


## Fixed sub_resource ids, so re-saving produces identical files.
func _name_sub_resources(branches: Array[ComboBranch], prefix: String) -> void:
	for i in branches.size():
		if branches[i] != null:
			branches[i].resource_scene_unique_id = "%s_%d" % [prefix, i]


# --- Saving -----------------------------------------------------------------------------

## Saves `move` after everything it references, so references become ext_resources.
func _save_move_deep(move: MoveData, stack: Array[StringName]) -> void:
	if _saved.has(move.id):
		return
	if move.id in stack:
		_fail("branch cycle: %s -> %s" % [" -> ".join(stack), move.id])
		return
	stack.append(move.id)
	for branch: ComboBranch in move.branches:
		_save_move_deep(branch.move, stack)
	if move.auto_next != null:
		_save_move_deep(move.auto_next, stack)
	stack.pop_back()
	_save(move, move.resource_path)
	_saved[move.id] = true


func _save(res: Resource, path: String) -> void:
	# Keep the UID of the file being overwritten, so re-runs do not change it.
	var uid := _read_header_uid(path)
	_uids[path] = uid if uid != ResourceUID.INVALID_ID else ResourceUID.create_id()
	_fix_ext_ids(res, path)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		_fail("could not save %s: %s" % [path, error_string(err)])


## The uid="..." in a resource file's header, or INVALID_ID. Read from the file itself:
## outside the editor, ResourceLoader.get_resource_uid() only knows files that the last
## editor scan (`godot --import`) saw.
func _read_header_uid(path: String) -> int:
	if not FileAccess.file_exists(path):
		return ResourceUID.INVALID_ID
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ResourceUID.INVALID_ID
	var found := RegEx.create_from_string('uid="(uid://[a-z0-9]+)"').search(file.get_line())
	return ResourceUID.text_to_id(found.get_string(1)) if found != null else ResourceUID.INVALID_ID


## ResourceSaver only writes UIDs when the editor is running (it asks the editor's file
## system for them), so outside the editor the files come out path-only. Put the UIDs in
## the way the editor would: one in each file's header, and one on every [ext_resource]
## line (generated files from _uids, scripts from their .uid files).
func _add_uids() -> void:
	for path: String in _uids:
		var err := ResourceSaver.set_uid(path, _uids[path])
		if err != OK:
			_fail("could not set the UID of %s: %s" % [path, error_string(err)])
	var ext_line := RegEx.create_from_string('^\\[ext_resource type="[^"]+" path="([^"]+)"')
	for path: String in _uids:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var found := ext_line.search(lines[i])
			if found == null:
				continue
			var target := found.get_string(1)
			var target_uid: int = _uids.get(target, ResourceLoader.get_resource_uid(target))
			if target_uid == ResourceUID.INVALID_ID:
				_fail("%s: no UID for %s" % [path, target])
				continue
			lines[i] = lines[i].replace(' path="', ' uid="%s" path="' % ResourceUID.id_to_text(target_uid))
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			_fail("could not rewrite %s: %s" % [path, error_string(FileAccess.get_open_error())])
			continue
		file.store_string("\n".join(lines))
		file.close()


## Gives every resource `res` may reference from `path` a stable ext_resource id.
func _fix_ext_ids(res: Resource, path: String) -> void:
	for script_path: String in SCRIPT_IDS:
		(load(script_path) as Script).set_id_for_path(path, SCRIPT_IDS[script_path])
	for id: StringName in _moves:
		var move: MoveData = _moves[id]
		if move != res:
			move.set_id_for_path(path, String(id))


func _make_dir(path: String) -> void:
	var err := DirAccess.make_dir_recursive_absolute(path)
	if err != OK:
		_fail("could not create %s: %s" % [path, error_string(err)])


# --- Checks -----------------------------------------------------------------------------

## Re-reads every written file as text: each move must reference other moves only as
## [ext_resource] (never an embedded copy) and never itself.
func _verify_files() -> void:
	var move_script_line := 'script = ExtResource("%s")' % SCRIPT_IDS["res://game/combat/move_data.gd"]
	for id: StringName in _moves:
		var path := MOVES_DIR + String(id) + ".tres"
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			_fail("%s is empty or unreadable" % path)
			continue
		if text.count(move_script_line) != 1:
			_fail("%s embeds a MoveData sub_resource" % path)
		if text.contains('path="%s"' % path):
			_fail("%s references itself" % path)
	for set_id: String in ["ground", "air", "hold", "weapon"]:
		var path := SETS_DIR + set_id + ".tres"
		var text := FileAccess.get_file_as_string(path)
		if text.contains('script = ExtResource("%s")' % SCRIPT_IDS["res://game/combat/move_data.gd"]):
			_fail("%s embeds a MoveData sub_resource" % path)


func _fail(message: String) -> void:
	printerr("gen_moves: " + message)
	_failed = true
