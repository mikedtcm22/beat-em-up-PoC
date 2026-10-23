extends Node
## Live tuning values (autoload "Tuning"). Read values as `Tuning.data.<name>`; they may
## change at any time, so read them when needed rather than caching them.

signal changed(property: StringName)

var data: TuningData = TuningData.new()


func set_value(property: StringName, value: Variant) -> void:
	data.set(property, value)
	changed.emit(property)


## Replace all values at once (preset load). Emits `changed` with an empty name.
func apply(new_data: TuningData) -> void:
	data = new_data
	changed.emit(&"")
