class_name EncounterTable
extends Resource
## The crowd room's wave list (Milestone 3): each wave is the enemy ids it spawns, in order
## (EnemyCatalog ids: "punk", "kicker", "thug", "bruiser", "boss"). The spawner plays the list in
## turn and starts over after the last wave, forever. Every boss_wave_every-th wave
## (Tuning "Waves") is followed by the boss wave: the table's boss_wave, played on its own.

## The waves in play order; at most Tuning.data.wave_max_alive of one wave are alive at once
## (the rest spawn as the first ones fall).
@export var waves: Array[PackedStringArray] = []
## The boss wave that comes in after every boss_wave_every regular waves.
@export var boss_wave: PackedStringArray = PackedStringArray(["boss"])


## The ids of the wave to start after `started` waves have already started (0 = the first), with
## a boss wave every `boss_every` waves (0 = never): waves 1..boss_every of the table, the boss
## wave, the next boss_every waves, the boss wave, and so on, wrapping at the table's end. Empty
## when the table has no waves.
func wave_at(started: int, boss_every: int) -> PackedStringArray:
	if waves.is_empty():
		return PackedStringArray()
	if boss_every <= 0:
		return waves[started % waves.size()]
	var block := boss_every + 1
	if started % block == boss_every:
		return boss_wave
	var regular := (started / block) * boss_every + started % block
	return waves[regular % waves.size()]
