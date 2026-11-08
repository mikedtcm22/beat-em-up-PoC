class_name VideoArtLook
extends VideoLookPiece
## The upgraded cast (Phase 1, LD-ASSET; docs/video/P1.md): the art piece of a location's look, applied first. For each character
## named in `characters` it swaps in the video meshes (the game's GLB with the face's normals transferred from an ellipsoid proxy,
## tools/video/blender_asset.py) and sets the video textures on the character's material: `paint_tex`, the painted albedo, and
## `ink_tex`, the ink mask of the creases, the material borders and the drawn features (tools/video/art_paint.py), both in the UV2
## layout, which is what LD-INK's video/shaders/cine_toon.gdshader reads them with once the swap below is in. The files are
## `<art_dir>/<id>/<id>_video.glb`, `<id>_paint.png` and `<id>_ink.png`. Video only: nothing here is used by the game.

@export_group("Characters")
## The CharacterArt ids that get the video art, and where their files are.
@export var characters: PackedStringArray = PackedStringArray(["punk", "boss", "player"])
@export_dir var art_dir: String = "res://assets/video/characters"

@export_group("Switches")
## The three parts of the upgrade, each on its own for an A/B: the meshes (the face's clean shading), the painted albedo, the ink mask.
@export var swap_meshes: bool = true
@export var paint: bool = true
@export var ink: bool = true
## The ink mask's strength on the paint (1 = the mask's own weight).
@export_range(0.0, 1.0) var ink_strength: float = 1.0
## Make cine_toon.gdshader read paint_tex and ink_tex with UV2 (the UV1 of the art is the palette's swatches, the UV2 is the layout the
## textures are made in). A runtime edit of the loaded shader's source, until the shader itself does it (docs/video/calls/ld-asset.md).
@export var layout_uv: bool = true


## Add the art rig under `level` (once) and start it.
func apply(level: Node) -> void:
	if level == null or level.get_node_or_null(^"CineArtRig") != null:
		return
	var rig := CineArtRig.new()
	rig.name = "CineArtRig"
	rig.look = self
	level.add_child(rig)
	rig.setup(level)
