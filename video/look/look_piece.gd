class_name VideoLookPiece
extends Resource
## One piece of the video's cine look (docs/video/PLAN.md §4, Plan A; docs/video/P1.md): the
## world's light and paint, the characters' paint and ink, or the upgraded character art. The shot
## applies its pieces in order (art, then world, then ink) after the level is built. A piece is
## data (its values live in its .tres) plus apply(); work it must do every frame goes in a helper
## Node it adds under the level. Video only: nothing here is used by the game.


## Apply this piece to `level` (a LevelRoot after its _ready). Safe to call once per level.
func apply(level: Node) -> void:
	pass
