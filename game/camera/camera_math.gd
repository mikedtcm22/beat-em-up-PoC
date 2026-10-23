class_name CameraMath
extends RefCounted
## Small math helpers shared by the cameras.


## Lerp weight that moves a value toward its target by exponential damping with time
## constant `time_constant` over `delta` seconds. Frame-rate independent: n steps of
## delta / n land where one step of delta does. A time constant of 0 or less snaps.
static func damp_weight(delta: float, time_constant: float) -> float:
	if time_constant <= 0.0:
		return 1.0
	return 1.0 - exp(-delta / time_constant)
