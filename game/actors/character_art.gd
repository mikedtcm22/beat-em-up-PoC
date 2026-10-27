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
