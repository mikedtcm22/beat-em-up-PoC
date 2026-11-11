class_name CharacterArt
extends Resource
## One character's skinned art: a GLB exported by tools/pipeline to the project's rest
## skeleton (docs/ARCHITECTURE.md "Art pipeline and look (Milestone 4)", the asset contract).
## A CombatActor carries one in `art` (game/actors/art/<id>_art.tres); null keeps the
## placeholder primitives. SkinnedArt turns it into meshes on the rig (SkinnedArt.attach()).

## What the art is of: &"punk", &"player".
@export var id: StringName
## The exported GLB, res://assets/export/characters/<id>/<id>.glb. SkinnedArt reads its
## meshes and bind names; its own Skeleton3D is never put under the rig.
@export var scene: PackedScene
## The shared palette atlas, res://assets/export/palette/palette_atlas.png: every face's UV
## sits on one swatch of it.
@export var palette: Texture2D
## Player only (Spec §10 "1k detail mask"): a second UV set's ink lines. Null for the
## enemies, which use the shared atlas alone.
@export var detail_mask: Texture2D
## Spec §10: 15000 triangles for an enemy, 30000 for the player. SkinnedArt.check() fails
## a mesh above it.
@export var triangle_budget: int = 0
## M7: the art this character wears under the trailer look profile, or null (it keeps this art
## under every profile). Kept as metadata (`metadata/trailer` in the .tres, like `detail_sharp`), so
## the M4 contract's pinned fields stay as they were. A CharacterArt of its own: its own GLB (a
## different mesh, even a new UV2, bound to the same 23 bones), palette, detail mask and triangle
## budget, so its material is its own. Its own variant is never read. A rig swaps between the two
## live (HumanoidRig.swap_art(), driven by ArtLook), keeping its pose, damage look and outline.
## M7 T13: an art with `metadata/trailer_b` (the Punk's arm B) wears it instead when Tuning `trailer_punk_arm` is 1.
func trailer_art() -> CharacterArt:
	if has_meta(&"trailer_b") and Tuning.data.trailer_punk_arm == 1:
		return get_meta(&"trailer_b") as CharacterArt
	return get_meta(&"trailer") as CharacterArt if has_meta(&"trailer") else null


## The art to wear under the look profile named `profile` (&"m6" or &"trailer"): the trailer variant
## for &"trailer" when it has one, else this art.
func variant(profile: StringName) -> CharacterArt:
	var other := trailer_art()
	return other if profile == &"trailer" and other != null else self
