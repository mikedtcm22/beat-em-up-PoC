class_name TrailerProp
extends Node
## A street prop's trailer-profile paint (M7 e-street): a child of a prop scene's StaticArt root. While the look profile is the
## trailer it lifts the prop's flat fill (the night's blue light left the cars, the dumpster and the crates near black, so the
## shade edge and the hull line had nothing to read against): the art material's `albedo` becomes `tint` times Tuning's
## `trailer_prop_lift`. Under M6's profile the albedo is white, exactly as StaticArt made it. Presentation only.

## The prop's own flat fill tint under the trailer profile (white: the palette as it is; the scene sets it per prop).
@export var tint: Color = Color.WHITE

var _art: StaticArt


func _ready() -> void:
	_art = get_parent() as StaticArt
	Tuning.changed.connect(_on_tuning_changed)
	# The parent's _ready (which makes the art material) runs after this child's.
	_apply.call_deferred()


func _exit_tree() -> void:
	if Tuning.changed.is_connected(_on_tuning_changed):
		Tuning.changed.disconnect(_on_tuning_changed)


## The albedo the art wears now: the lifted tint under the trailer profile, white under M6's.
func albedo() -> Color:
	if LookProfile.current() != LookProfile.Id.TRAILER:
		return Color.WHITE
	var lift := Tuning.data.trailer_prop_lift
	return Color(tint.r * lift, tint.g * lift, tint.b * lift, 1.0)


func _on_tuning_changed(property: StringName) -> void:
	if property == &"" or property == &"look_profile" or property == &"trailer_prop_lift":
		_apply()


func _apply() -> void:
	if _art == null or _art.material == null:
		return
	_art.material.set_shader_parameter(&"albedo", albedo())
