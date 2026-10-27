class_name ToonMaterials
extends RefCounted
## The one place a surface's material is made (Milestone 4): characters, the skinned art,
## props, the room's boxes and floor grid, and the inverted-hull outlines. S0 (the contract
## scaffold) lands every call site on these factories as stubs that keep today's look:
## `prop()`, `environment()` and `grid()` return the StandardMaterial3D and grid-shader
## recipes the weapon and RoomKit used before, and the rest return null. P1-toon replaces
## them with the toon shader's materials, P1-post calls `environment()` and `grid()` first
## (docs/ARCHITECTURE.md "Art pipeline and look (Milestone 4)").

const GRID_SHADER := "res://game/level/grid.gdshader"


## A character's flat-colored toon material. Null until P1-toon: RigPaint keeps its own
## StandardMaterial3D per paint.
static func character(_color: Color) -> Material:
	return null


## The skinned art's material: the palette `atlas` (and the player's `detail` mask). Null
## until P1-toon: RigPaint.art_material() makes a plain textured one meanwhile.
static func art(_atlas: Texture2D, _detail: Texture2D = null) -> Material:
	return null


## The inverted-hull outline pass, for a character's `material_overlay`. Null: no outline yet.
static func outline() -> Material:
	return null


## A prop's material (the pipe): `color`, rough and half metal.
static func prop(color: Color) -> Material:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.5
	material.metallic = 0.4
	return material


## The hull for a prop's `material_overlay`. Null: no outline yet.
static func outline_for_prop() -> Material:
	return null


## A flat-colored surface of the room (a wall, a crate, the street): `color`, nearly matte.
static func environment(color: Color) -> Material:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


## The grey-box floor grid (the training room's), or a flat grey if the shader is missing.
static func grid() -> Material:
	if ResourceLoader.exists(GRID_SHADER):
		var material := ShaderMaterial.new()
		material.shader = load(GRID_SHADER)
		return material
	return environment(Color(0.3, 0.3, 0.32))


## Draw every toon variant once under `parent` at load, so the renderer compiles its
## pipelines before the first hit (`skinned`: an art instance to warm the skinned variant
## with). A no-op until P1-toon has variants.
static func warm_up(_parent: Node, _skinned: Node3D = null) -> void:
	pass
