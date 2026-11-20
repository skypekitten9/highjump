class_name RunnerTuning
extends Resource
## Every value that tunes how the Runner feels. Swap presets to change the feel without code.
## Defaults are the play-tested "Momentum (tight)" values (see docs/adr/0004), with the Slide
## and Crouch from the "Long glide" preset and Run speed raised to suit them (see docs/adr/0005).

## The shortest Slide boost cooldown allowed, s.
const MIN_SLIDE_BOOST_COOLDOWN := 0.01

## The fastest the Runner moves from the Player's input alone, m/s.
@export_range(0.1, 30.0, 0.1, "or_greater", "suffix:m/s") var run_speed: float = 9.0
## Ground acceleration toward the input direction, m/s^2.
@export_range(0.0, 300.0, 1.0, "or_greater", "suffix:m/s²") var ground_accel: float = 140.0
## Ground deceleration with no input, at any speed, m/s^2.
@export_range(0.0, 300.0, 1.0, "or_greater", "suffix:m/s²") var ground_friction: float = 120.0
## How fast speed above Run speed fades on the ground while input is held, m/s^2.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m/s²") var overspeed_decay: float = 10.0
## Air steering acceleration, m/s^2. Steering never raises speed above max(Run speed, current).
@export_range(0.0, 200.0, 1.0, "or_greater", "suffix:m/s²") var air_accel: float = 20.0
## Gravity, one value for both rising and falling, m/s^2.
@export_range(0.0, 60.0, 0.1, "or_greater", "suffix:m/s²") var gravity: float = 20.0
## Height of the jump's peak above take-off, m. Launch speed is sqrt(2 * gravity * height).
@export_range(0.0, 5.0, 0.05, "or_greater", "suffix:m") var jump_height: float = 1.2
## A jump still fires this long after leaving the floor, s.
@export_range(0.0, 0.5, 0.01, "or_greater", "suffix:s") var coyote_time: float = 0.1
## A jump pressed this long before landing fires on landing, s.
@export_range(0.0, 0.5, 0.01, "or_greater", "suffix:s") var jump_buffer_time: float = 0.1
## How far below the Runner the floor still holds it down, m. Keeps it on the ground over a
## ramp's crest and down slopes and steps instead of briefly leaving it.
@export_range(0.0, 1.0, 0.01, "or_greater", "suffix:m") var floor_snap_length: float = 0.25

@export_group("Crouch")
## The fastest the Runner moves from the Player's input while crouched, m/s.
@export_range(0.0, 15.0, 0.1, "or_greater", "suffix:m/s") var crouch_speed: float = 3.0
## Height of the Runner's body while low, m. Standing height is the body's height in the scene.
@export_range(0.1, 2.0, 0.05, "or_greater", "suffix:m") var crouch_height: float = 0.9

@export_group("Slide")
## Crouching on the ground at or above this speed starts a Slide instead of a Crouch, m/s.
@export_range(0.0, 30.0, 0.1, "or_greater", "suffix:m/s") var slide_entry_speed: float = 7.0
## Speed a Slide gains as it begins, if no Slide began within the cooldown, m/s. Never takes the
## Runner past Run speed + this (or the top slide speed), and never slows it.
@export_range(0.0, 10.0, 0.1, "or_greater", "suffix:m/s") var slide_boost: float = 2.0
## Time after a Slide begins until the next Slide boost is full again; it grows linearly to full
## over this time, s. Never below [constant MIN_SLIDE_BOOST_COOLDOWN], however it is set, since
## RunnerMovement divides by it.
@export_range(0.01, 5.0, 0.01, "or_greater", "suffix:s") var slide_boost_cooldown: float = 1.5:
	set(value):
		slide_boost_cooldown = maxf(value, MIN_SLIDE_BOOST_COOLDOWN)
## Scales gravity along the floor in a Slide, as a multiple: speed gained downhill with crouch
## held, and lost uphill (see docs/adr/0005).
@export_range(0.0, 3.0, 0.05, "or_greater", "suffix:×") var slope_gain: float = 1.3
## Highest speed a Slide can gain; a faster entry keeps its speed, m/s.
@export_range(0.0, 60.0, 0.5, "or_greater", "suffix:m/s") var top_slide_speed: float = 24.0
## How fast a Slide above Run speed loses speed, m/s^2.
@export_range(0.0, 50.0, 0.1, "or_greater", "suffix:m/s²") var slide_friction: float = 4.0
## How fast a Slide below Run speed loses speed while crouch is held, m/s^2.
@export_range(0.0, 50.0, 0.1, "or_greater", "suffix:m/s²") var slow_slide_friction: float = 14.0
## How fast a Slide loses speed after crouch is released, m/s^2.
@export_range(0.0, 50.0, 0.1, "or_greater", "suffix:m/s²") var released_slide_decel: float = 4.0
## A Slide with crouch held that drops below this speed becomes a Crouch, m/s.
@export_range(0.0, 30.0, 0.1, "or_greater", "suffix:m/s") var slide_to_crouch_speed: float = 4.5
## Fastest a Slide turns toward sideways input, rad/s.
@export_range(0.0, 10.0, 0.05, "or_greater", "suffix:rad/s") var slide_turn_rate: float = 0.6

@export_group("Wall-run")
## Meeting a wall in the air at or above this horizontal speed can start a Wall-run, m/s.
@export_range(0.0, 30.0, 0.1, "or_greater", "suffix:m/s") var wall_run_entry_speed: float = 6.0
## A Wall-run that slows below this speed ends, m/s.
@export_range(0.0, 30.0, 0.1, "or_greater", "suffix:m/s") var wall_run_end_speed: float = 4.0
## A wall met more head-on than this, measured from parallel to it, starts no Wall-run, degrees.
@export_range(0.0, 90.0, 1.0, "suffix:°") var wall_run_max_entry_angle: float = 60.0
## The held direction may point away from the wall by up to this, measured from parallel to it,
## and still start a Wall-run, degrees.
@export_range(0.0, 90.0, 0.5, "suffix:°") var wall_run_input_angle: float = 17.5
## A Wall-run follows a wall whose normal turns by up to this from one frame to the next (a
## curve); a sharper turn away is an outside corner and ends the run, degrees.
@export_range(0.0, 90.0, 0.5, "suffix:°") var wall_run_follow_angle: float = 30.0
## A surface whose normal is within this of horizontal is a wall that can be run, degrees.
@export_range(0.0, 45.0, 0.5, "suffix:°") var wall_max_tilt: float = 14.5
## Gravity during a Wall-run, as a multiple of gravity.
@export_range(0.0, 1.0, 0.01, "or_greater", "suffix:×") var wall_run_gravity_scale: float = 0.35
## How fast a Wall-run loses speed, m/s^2.
@export_range(0.0, 20.0, 0.1, "or_greater", "suffix:m/s²") var wall_run_slowdown: float = 1.0
## Falling speed is capped at this as a Wall-run starts; upward speed is kept, m/s.
@export_range(0.0, 20.0, 0.1, "or_greater", "suffix:m/s") var wall_run_max_entry_fall: float = 2.0
## A Wall-jump adds this speed straight away from the wall, m/s.
@export_range(0.0, 30.0, 0.1, "or_greater", "suffix:m/s") var wall_jump_push: float = 6.0
## Highest speed jumping from wall to wall can reach; a Runner already faster keeps its speed,
## m/s.
@export_range(0.0, 60.0, 0.5, "or_greater", "suffix:m/s") var top_wall_run_speed: float = 24.0
## How far beyond the body a Wall-run still finds the wall being run, m. Keeps contact with a wall
## the body runs along without pressing into it.
@export_range(0.0, 2.0, 0.01, "or_greater", "suffix:m") var wall_probe_reach: float = 0.35

@export_group("View")
## Mouse look, radians per pixel of mouse movement.
@export_range(
	0.0001,
	0.02,
	0.0001,
	"or_greater",
	"suffix:rad/px",
) var mouse_sensitivity: float = 0.0025
## Camera field of view, degrees (vertical).
@export_range(1.0, 179.0, 1.0, "suffix:°") var fov: float = 90.0
## How quickly the camera eases between standing and low eye height, 1/s. Higher is snappier;
## about 3 / this is the time to get most of the way there, s.
@export_range(0.1, 50.0, 0.1, "or_greater", "suffix:1/s") var camera_smoothing: float = 14.0
## How far the camera rolls away from the wall during a Wall-run, easing in and out at the
## camera smoothing rate. 0 turns the tilt off, degrees.
@export_range(0.0, 45.0, 0.5, "suffix:°") var wall_run_camera_tilt: float = 10.0
## The camera stays at least this far below a ceiling directly overhead, m.
@export_range(0.0, 0.5, 0.01, "or_greater", "suffix:m") var camera_ceiling_gap: float = 0.12
