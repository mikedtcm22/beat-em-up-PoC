class_name CenterDot
extends Control
## Small aim dot at the screen center (Spec §5). Shown when Tuning.data.show_center_dot is
## on and the camera director is in first person (or there is no director).
## Driven by GameHud.advance().

@export var radius: float = 3.0
@export var color: Color = Color(1.0, 1.0, 1.0, 0.9)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Re-evaluate visibility. `director` is the node in group "camera_director", or null.
func refresh(director: Node) -> void:
	visible = CenterDot.should_show(Tuning.data.show_center_dot, director)


## The visibility rule: the option is on, and the director (if any) is in first person.
static func should_show(enabled: bool, director: Node) -> bool:
	if not enabled:
		return false
	if director == null or not is_instance_valid(director):
		return true
	return str(director.get(&"mode")) == "first_person"


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, radius + 1.5, Color(HudStyle.INK, 0.8 * color.a))
	draw_circle(center, radius, color)
