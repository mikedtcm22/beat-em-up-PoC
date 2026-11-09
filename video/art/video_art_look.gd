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

## The triangle budget of a video art (CharacterArt.triangle_budget, the game's 30,000 for the game's frame time): the player's arms are subdivided.
@export var triangle_budget: int = 250000

@export_group("Switches")
## The three parts of the upgrade, each on its own for an A/B: the meshes (the face's clean shading), the painted albedo, the ink mask.
@export var swap_meshes: bool = true
@export var paint: bool = true
@export var ink: bool = true
## The ink mask's strength on the paint (1 = the mask's own weight).
@export_range(0.0, 1.0) var ink_strength: float = 1.0
@export_group("Round 2 (LD-ART2)")
## The face zone's fill: a share of the albedo added unlit where the ink map's B says face (0 = off), in `face_fill_color`: a face under a cap
## or a hood is never lost in the shadow band, and the drawn lines (in the albedo) stay dark on it. Set per location in the art.tres.
@export_range(0.0, 1.5) var face_fill: float = 0.5
@export var face_fill_color: Color = Color(1.0, 0.84, 0.68)
## The fill of one art id instead of `face_fill` (id -> fill): the player's first-person arm carries part of the face zone (its warm skin), and at
## night the faces' fill made it the brightest thing in the frame (the lead's call after LD-INK2, round 3). Ids not listed take `face_fill`.
@export var face_fill_by_id: Dictionary = {}
## The catchlights and the lens glints (the ink map's A), drawn unlit.
@export_range(0.0, 2.0) var catch_strength: float = 1.0
@export var catch_color: Color = Color(1.0, 0.96, 0.86)
## The soft highlight's share (0 = none: no plastic sheen on a cap, a glove, a mask; the glints of the metal are separate).
@export_range(0.0, 1.0) var plastic_spec: float = 0.0
## The game's damage decals (the blood and scuff textures, triplanar) read as stickers on a painted figure: 0 = off for the video.
@export_range(0.0, 1.0) var damage_marks: float = 0.0
## The game's detail mask (its UV2 layout: creases, glint streaks, a texel swatch) is off on a character that has the video paint and ink: the
## video's UV2 is a new layout, and the ink map draws its own creases.
@export var game_detail_off: bool = true
## Make cine_toon.gdshader read paint_tex and ink_tex with UV2 (the UV1 of the art is the palette's swatches, the UV2 is the layout the
## textures are made in). A runtime edit of the loaded shader's source, until the shader itself does it (docs/video/calls/ld-asset.md).
@export var layout_uv: bool = true

@export_group("Round 4 (R4-ART)")
## The shade map (`<id>_shade.png`: R = the designed shadow hint, G and B = the hatch strokes that follow the form, tools/video/art_shade.py).
@export var shade_map: bool = true
## The hint's weight on the light term (0 = off): how far the designed shape (under the brow and cheekbone, under the chin, the underside of a
## forearm) pulls the light term down before the bands. One art id can differ: `hint_gain_by_id`.
@export_range(0.0, 1.0) var hint_gain: float = 0.4
@export var hint_gain_by_id: Dictionary = {}
## The hatching's gain on the ink piece's `hatch_on` (its close-up fade; 0 = no hatching, 1 = as the ink piece says). The strokes are in the
## shade map and only draw inside the shadow band, never on a lit face.
@export_range(0.0, 2.0) var hatch_gain: float = 1.0
## A floor under the ink piece's `hatch_on` per art id (id -> 0..1): the first-person arm is always close, whatever the nearest figure's distance
## says, so its hatching stays on. `hatch_near_m` and `hatch_far_m`: the strokes also fade with the pixel's distance to the lens.
@export var hatch_floor_by_id: Dictionary = {}
@export_range(0.2, 10.0) var hatch_near_m: float = 1.4
@export_range(0.5, 20.0) var hatch_far_m: float = 3.0
## A value multiplier on the albedo of one art id (id -> multiplier): the first-person arm is a foreground form, darker than the subject.
@export var value_by_id: Dictionary = {}
## A multiplier on the key-tinted rim of one art id (id -> multiplier): the arm's warm rim from the lamp.
@export var rim_gain_by_id: Dictionary = {}


## The face zone's fill of art `id`: its entry in `face_fill_by_id`, else `face_fill`.
func face_fill_of(id: StringName) -> float:
	return float(face_fill_by_id.get(String(id), face_fill))


## The hint's weight for art `id`.
func hint_gain_of(id: StringName) -> float:
	return float(hint_gain_by_id.get(String(id), hint_gain))


## Add the art rig under `level` (once) and start it.
func apply(level: Node) -> void:
	if level == null or level.get_node_or_null(^"CineArtRig") != null:
		return
	var rig := CineArtRig.new()
	rig.name = "CineArtRig"
	rig.look = self
	level.add_child(rig)
	rig.setup(level)
