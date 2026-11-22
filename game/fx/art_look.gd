class_name ArtLook
extends RefCounted
## Which art a rig wears under the running look profile (Milestone 7, T05b): the bridge between the
## actors' rigs, which never read the profile, and LookProfile. A rig asks worn() when it builds and
## whenever is_profile_change() says the profile flipped; CharacterArt.trailer holds the variant.
## Presentation only (docs/ARCHITECTURE.md "Look profiles (M7)", "Per-profile character art").


## The art `art` shows under the running profile: its trailer variant under the trailer profile
## when it has one, else `art` itself. Null for null.
static func worn(art: CharacterArt) -> CharacterArt:
	if art == null:
		return null
	return art.variant(LookProfile.profile_name())


## Whether Tuning's `changed(property)` is a profile flip (or a whole-set change, which may have
## flipped it): the rigs re-pick their art then.
static func is_profile_change(property: StringName) -> bool:
	return property == &"" or property == &"look_profile"


## The shadow-map setting a figure's art meshes take under the running profile: off under the trailer profile (the figure's ground contact is the
## soft blob, so no map shadow anywhere, M7 D1), on under m6 as always.
static func shadow_setting() -> GeometryInstance3D.ShadowCastingSetting:
	if LookProfile.current() == LookProfile.Id.TRAILER:
		return GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return GeometryInstance3D.SHADOW_CASTING_SETTING_ON
