class_name RunnerTuning
extends Resource
## Every value that tunes how the Runner feels. Swap presets to change the feel without code.
## Defaults are the play-tested "Momentum (tight)" values (see docs/adr/0004).

## The fastest the Runner moves from the Player's input alone, m/s.
@export var run_speed: float = 7.0
## Ground acceleration toward the input direction, m/s^2.
@export var ground_accel: float = 140.0
## Ground deceleration with no input, at any speed, m/s^2.
@export var ground_friction: float = 120.0
## How fast speed above Run speed fades on the ground while input is held, m/s^2.
@export var overspeed_decay: float = 10.0
## Gravity, one value for both rising and falling, m/s^2.
@export var gravity: float = 20.0

@export_group("View")
## Mouse look, radians per pixel of mouse movement.
@export var mouse_sensitivity: float = 0.0025
## Camera field of view, degrees (vertical).
@export var fov: float = 90.0
