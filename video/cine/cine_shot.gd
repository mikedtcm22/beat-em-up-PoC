class_name CineShot
extends VideoStillShot
## A shot of the cine video (P1.md, LD-STAGE): a still's staging (where the player stands, the actors, the lamps)
## plus a scripted timeline, a keyframed camera and a window of the shot clock to write. One `.tres` per moving shot in
## `res://video/shots/`. A VideoStillShot of `res://video/stills/` also plays as a shot: a one-frame window,
## the staging as it is.
## The shot clock counts physics ticks (60 a second) from the end of the staging. The frame writer keeps the 24 fps picks of
## the window [window_from_s, window_to_s].

## The look's location (`res://video/look/<location>/`). Empty: the section's (street_night, roofs_dusk, boss_fire).
@export var location: StringName = &""
## The written window, in seconds of the shot clock. `window_to_s <= window_from_s` writes one frame.
@export_range(0.0, 120.0) var window_from_s: float = 0.0
@export_range(0.0, 120.0) var window_to_s: float = 5.0
## The script the player runs: presses, holds, the stick, turns, slow-motion.
@export var beats: Array[CineBeat] = []
## A free camera's path. Empty: one still key from `cam_pos`, `cam_look_at` and `cam_fov_deg`. Ignored in first person.
@export var camera_keys: Array[CineCameraKey] = []
## Weapons lying on the floor when the shot starts.
@export var props: Array[CineProp] = []
## Flat dark foreground masses (a fire escape's rail, a roof edge), drifting or still (round 5).
@export var cards: Array[CineCard] = []
## Hide every section's own geometry (walls, floor, props and skyline blocks) so that only the world look's backdrops and the cards are drawn: a multiplane shot (t14, round 5).
@export var hide_kit: bool = false
## The game's screen shake as a share of its own (negative leaves the game's setting). A cine shot is calmer.
@export_range(-1.0, 3.0) var shake_scale: float = -1.0
## The act's number in the shot list (PLAN.md §5) and the time the edit places it at, in seconds, for the animatic's order.
@export_range(0, 40) var number: int = 0
@export_range(0.0, 60.0) var edit_start_s: float = 0.0
## The simulation's time scale the shot is cut at in the edit (0.25 for the slow-motion shots), for the cut list; the slow-motion
## itself is a SLOWMO beat, through TimeController.
@export_range(0.05, 1.0) var edit_speed: float = 1.0
## Seed of the effect and audio directors' rngs for this shot.
@export var rng_seed: int = 1

@export_group("First-person view (round 5)")
## First person, through the CineViewRig: the lens raised above the eye (m, along its own up axis; the guard fist then sits lower in the
## frame and is cropped by its bottom edge), pulled back (m, along its own back axis; room for the opponent's framing), and banked (degrees,
## about the view axis). EyePoint and the hitboxes do not move. 0 leaves the game's view.
@export_range(-0.3, 0.6, 0.005) var view_lift_m: float = 0.0
@export_range(-0.5, 0.6, 0.005) var view_back_m: float = 0.0
@export_range(-15.0, 15.0, 0.5) var view_roll_deg: float = 0.0
## First person: scale `off_hand`'s arm away in the picture unless a move strikes with it (a guard, a hold or a held weapon shows it too).
@export var hide_off_hand: bool = false
@export_enum("Left", "Right") var off_hand: String = "Right"


## The location of this shot: `location`, or the section's.
func location_name() -> StringName:
	if location != &"":
		return location
	return CineShot.section_location(section)


## The location of a level section (0 the street, 1 the roofs, 2 the boss roof).
static func section_location(section_index: int) -> StringName:
	match section_index:
		1:
			return &"roofs_dusk"
		2:
			return &"boss_fire"
	return &"street_night"


## The length of the written window in physics ticks, for a sim rate (a still is one frame).
func window_ticks(sim_fps: int) -> int:
	return maxi(0, int(roundf((window_to_s - window_from_s) * float(sim_fps))))


## The camera keys the shot uses: the path, or the still key.
func keys() -> Array[CineCameraKey]:
	if not camera_keys.is_empty():
		return camera_keys
	var key := CineCameraKey.new()
	key.position = cam_pos
	key.look_at = cam_look_at
	key.fov_deg = cam_fov_deg
	return [key]
