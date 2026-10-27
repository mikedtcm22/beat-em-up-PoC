class_name SkinnedArt
extends RefCounted
## Turns a CharacterArt into skinned meshes on a HumanoidRig's skeleton (Milestone 4). S0
## (the contract scaffold) lands the two entry points as stubs that keep today's behaviour;
## P1-skin implements them (docs/ARCHITECTURE.md "Art pipeline and look (Milestone 4)").


## Add `art`'s meshes to `rig`, skinned to its skeleton (a child of rig.skeleton, named
## Art<Mesh>, in group HumanoidRig.ART_GROUP, with rig.paint's art material and outline).
## Returns the meshes added; empty when there is nothing to draw, in which case the rig keeps
## its primitives visible. Called by HumanoidRig._build_meshes() after the primitives are
## built. The stub adds nothing.
static func attach(_rig: HumanoidRig, _art: CharacterArt) -> Array[MeshInstance3D]:
	return []


## The contract violations of `art` (a bind name outside PlaceholderBody.BONE_NAMES, a joint
## off the table, more triangles than the budget, ...); empty = ok. The stub reports itself.
static func check(_art: CharacterArt) -> PackedStringArray:
	return PackedStringArray(["not implemented"])
