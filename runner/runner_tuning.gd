class_name RunnerTuning
extends Resource
## Every value that tunes how the Runner feels. Swap presets to change the feel without code.
## Defaults are the play-tested "Momentum (tight)" values (see docs/adr/0004), with the Slide
## and Crouch from the "Long glide" preset and Run speed raised to suit them (see docs/adr/0005).

## The fastest the Runner moves from the Player's input alone, m/s.
@export var run_speed: float = 9.0
## Ground acceleration toward the input direction, m/s^2.
@export var ground_accel: float = 140.0
## Ground deceleration with no input, at any speed, m/s^2.
@export var ground_friction: float = 120.0
## How fast speed above Run speed fades on the ground while input is held, m/s^2.
@export var overspeed_decay: float = 10.0
## Air steering acceleration, m/s^2. Steering never raises speed above max(Run speed, current).
@export var air_accel: float = 45.0
## Gravity, one value for both rising and falling, m/s^2.
@export var gravity: float = 20.0
## Height of the jump's peak above take-off, m. Launch speed is sqrt(2 * gravity * height).
@export var jump_height: float = 1.2
## A jump still fires this long after leaving the floor, s.
@export var coyote_time: float = 0.1
## A jump pressed this long before landing fires on landing, s.
@export var jump_buffer_time: float = 0.1
## How far below the Runner the floor still holds it down, m. Keeps it on the ground over a
## ramp's crest and down slopes and steps instead of briefly leaving it.
@export var floor_snap_length: float = 0.25

@export_group("Crouch")
## The fastest the Runner moves from the Player's input while crouched, m/s.
@export var crouch_speed: float = 3.0
## Height of the Runner's body while low, m. Standing height is the body's height in the scene.
@export var crouch_height: float = 0.9

@export_group("Slide")
## Crouching on the ground at or above this speed starts a Slide instead of a Crouch, m/s.
@export var slide_entry_speed: float = 7.0
## Speed a Slide gains as it begins, if no Slide began within the cooldown, m/s. Never takes the
## Runner past Run speed + this (or the top slide speed), and never slows it.
@export var slide_boost: float = 2.0
## Time after a Slide begins until the next Slide boost is full again; it grows linearly to full
## over this time, s.
@export var slide_boost_cooldown: float = 1.5
## Highest speed a Slide can gain; a faster entry keeps its speed, m/s.
@export var top_slide_speed: float = 24.0
## How fast a Slide above Run speed loses speed, m/s^2.
@export var slide_friction: float = 1.5
## How fast a Slide below Run speed loses speed while crouch is held, m/s^2.
@export var slow_slide_friction: float = 14.0
## How fast a Slide loses speed after crouch is released, m/s^2.
@export var released_slide_decel: float = 4.0
## A Slide with crouch held that drops below this speed becomes a Crouch, m/s.
@export var slide_to_crouch_speed: float = 4.5
## Fastest a Slide turns toward sideways input, rad/s.
@export var slide_turn_rate: float = 0.6

@export_group("View")
## Mouse look, radians per pixel of mouse movement.
@export var mouse_sensitivity: float = 0.0025
## Camera field of view, degrees (vertical).
@export var fov: float = 90.0
## How quickly the camera eases between standing and low eye height, 1/s. Higher is snappier;
## about 3 / this is the time to get most of the way there, s.
@export var camera_smoothing: float = 14.0
