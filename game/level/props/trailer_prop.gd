class_name TrailerProp
extends Node
## A street prop's trailer-profile paint (M7 e-street): a child of a prop scene's StaticArt root. While the look profile is the
## trailer it lifts the prop's flat fill (the night's blue light left the cars, the dumpster and the crates near black, so the
## shade edge and the hull line had nothing to read against): the art material's `albedo` becomes `tint` times Tuning's
## `trailer_prop_lift`. Under M6's profile the albedo is white, exactly as StaticArt made it. Presentation only.

## The prop's own flat fill tint under the trailer profile (white: the palette as it is; the scene sets it per prop).
@export var tint: Color = Color.WHITE
## A model painted in many small swatches (the dumpster's, a lumpy mesh) is drawn in this one flat colour instead under the trailer profile
## (alpha 0: the model's own swatches). It is lifted by `trailer_prop_lift` like the tint.
@export var flat_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## A multiple of Tuning's `trailer_prop_lift` for this prop (a car's chrome bumper takes the blue key so bright at the full lift that it glows).
@export_range(0.3, 1.5, 0.05) var lift_scale: float = 1.0

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
	var lift := Tuning.data.trailer_prop_lift * lift_scale
	return Color(tint.r * lift, tint.g * lift, tint.b * lift, 1.0)


func _on_tuning_changed(property: StringName) -> void:
	if property == &"" or property == &"look_profile" or property == &"trailer_prop_lift" or property == &"trailer_prop_mid_level" or property == &"trailer_prop_shadow_level":
		_apply()


func _apply() -> void:
	if _art == null or _art.material == null:
		return
	_art.material.set_shader_parameter(&"albedo", albedo())
	# M7 x-street: the prop's model is a lumpy mesh, so three light bands and a glint cut it into painted-looking patches. Under the trailer
	# profile it is two flat tones (lit, shade: one edge, as the room surfaces have) and no glint; under m6 the material is its M6 self.
	ToonMaterials.apply_look(_art.material)
	_art.material.set_shader_parameter(&"use_albedo_tex", _art.palette != null)
	if LookProfile.current() == LookProfile.Id.TRAILER:
		var t := Tuning.data
		_art.material.set_shader_parameter(&"mid_level", t.trailer_prop_mid_level)
		_art.material.set_shader_parameter(&"shadow_level", t.trailer_prop_shadow_level)
		var flat := flat_color.a > 0.0
		_art.material.set_shader_parameter(&"use_albedo_tex", not flat)
		if flat:
			var lift := t.trailer_prop_lift * lift_scale
			_art.material.set_shader_parameter(&"albedo", Color(flat_color.r * lift, flat_color.g * lift, flat_color.b * lift, 1.0))
		_art.material.set_shader_parameter(&"spec_strength", 0.0)
		_art.material.set_shader_parameter(&"glint_strength", 0.0)
