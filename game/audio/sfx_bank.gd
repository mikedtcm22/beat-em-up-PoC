class_name SfxBank
extends RefCounted
## The placeholder sound effects made by tools/gen_sfx.gd: pools of variants named
## `<pool>_<nn>.wav` in assets/export/sfx/ (`whoosh_01.wav` is a variant of &"whoosh").
## pick() chooses a pool's variant at random but never the one it chose last (Spec §6:
## never the same sample twice in a row).

const DIR := "res://assets/export/sfx/"

## Pool name -> its streams, in file-name order.
var pools: Dictionary[StringName, Array] = {}

## Pool name -> index of the variant pick() returned last.
var _last: Dictionary[StringName, int] = {}


func _init(dir: String = DIR) -> void:
	var files := ResourceLoader.list_directory(dir)
	files.sort()
	for file in files:
		if file.get_extension() != "wav":
			continue
		var base := file.get_basename()
		var cut := base.rfind("_")
		if cut <= 0:
			continue
		var stream := load(dir.path_join(file)) as AudioStream
		if stream == null:
			continue
		var pool := StringName(base.substr(0, cut))
		if not pools.has(pool):
			pools[pool] = []
		pools[pool].append(stream)


func count(pool: StringName) -> int:
	return pools.get(pool, []).size()


## A random variant of `pool` other than the one returned last time (null for an unknown
## or empty pool; a pool of one always gives that one).
func pick(pool: StringName, rng: RandomNumberGenerator) -> AudioStream:
	var streams: Array = pools.get(pool, [])
	if streams.is_empty():
		return null
	var last: int = _last.get(pool, -1)
	var index := 0
	if streams.size() > 1:
		if last < 0 or last >= streams.size():
			index = rng.randi_range(0, streams.size() - 1)
		else:
			# Choose among the others: skip over the last one.
			index = rng.randi_range(0, streams.size() - 2)
			if index >= last:
				index += 1
	_last[pool] = index
	return streams[index]
