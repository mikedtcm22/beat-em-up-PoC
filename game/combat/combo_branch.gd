class_name ComboBranch
extends Resource
## An edge in the combo tree: "pressing `input` with `timing` after the owning move starts `move`".

## One of CombatTypes.IN_* (&"P", &"K", &"P_HOLD", &"RB").
@export var input: StringName = &"P"
@export var timing: CombatTypes.BranchTiming = CombatTypes.BranchTiming.NORMAL
@export var move: MoveData
## Optional condition key (CombatTypes.COND_*) that must be true in the context the
## owner passes to ComboParser.select(). Empty = always allowed.
@export var require: StringName = &""
