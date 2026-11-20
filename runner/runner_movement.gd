class_name RunnerMovement
extends RefCounted
## Turns what the Player asks for and the Runner's body state into the Runner's next velocity.
## Never touches nodes, so it can be stepped frame by frame without a scene. It continues from
## whatever velocity it is given, so other mechanics can hand speed to it (see docs/adr/0004).

## Speed away from the floor plane above which a floor contact is ignored (leaving it), m/s.
const LEAVE_FLOOR_SPEED := 0.5
## Floor normals flatter than this (y component) are too steep to stand on or project onto.
const MIN_FLOOR_NORMAL_Y := 0.1

## Time left in which a jump still fires after leaving the floor, s.
var _coyote_timer := 0.0
## Time left in which a jump press is still waiting to fire, s.
var _jump_buffer_timer := 0.0
## Normal of the floor the Runner stayed on last frame; zero if it was airborne or jumped.
var _last_floor_normal := Vector3.ZERO


## Returns the Runner's velocity for this physics frame.
## [param wish]: world-space horizontal move direction, length 0..1.
## [param jump_pressed]: true only on the frame the jump was pressed, not while it is held.
## [param floor_normal]: the floor's normal; ignored when [param on_floor] is false.
func step(
	wish: Vector3,
	jump_pressed: bool,
	velocity: Vector3,
	on_floor: bool,
	floor_normal: Vector3,
	tuning: RunnerTuning,
	delta: float,
) -> Vector3:
	var grounded := _is_grounded(velocity, on_floor, floor_normal)
	_update_jump_timers(jump_pressed, grounded, tuning, delta)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var vertical: float
	if grounded:
		horizontal = _ground_horizontal(horizontal, wish, tuning, delta)
		# Keep velocity in the floor plane (v . n = 0) without changing horizontal speed.
		vertical = (
			-(horizontal.x * floor_normal.x + horizontal.z * floor_normal.z) / floor_normal.y
		)
	else:
		horizontal = _air_horizontal(horizontal, wish, tuning, delta)
		vertical = velocity.y - tuning.gravity * delta
	if _jump_buffer_timer > 0.0 and (grounded or _coyote_timer > 0.0):
		vertical = maxf(vertical, sqrt(2.0 * tuning.gravity * tuning.jump_height))
		clear_jump_timers()
		grounded = false
	_last_floor_normal = floor_normal if grounded else Vector3.ZERO
	return Vector3(horizontal.x, vertical, horizontal.z)


## True if the last step kept the Runner on the floor (it neither was airborne nor jumped),
## so the body should be held down onto the floor even while climbing a slope.
func is_on_ground() -> bool:
	return not _last_floor_normal.is_zero_approx()


## Forgets any waiting jump press and any coyote time. For mechanics that hand control back
## (the Vault), so a stale press doesn't fire afterwards.
func clear_jump_timers() -> void:
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0


func _update_jump_timers(
	jump_pressed: bool,
	grounded: bool,
	tuning: RunnerTuning,
	delta: float,
) -> void:
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	if jump_pressed:
		_jump_buffer_timer = tuning.jump_buffer_time
	if grounded:
		_coyote_timer = tuning.coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)


## On the floor and not already leaving it, so the take-off frame isn't snapped back down.
## Leaving is measured against the floor the Runner stood on last frame, if any: running up a
## ramp onto flat ground still climbs at the ramp's angle, but it is not leaving the floor.
## Only velocity pointing up can leave: the engine's movement step zeroes vertical velocity
## going down a slope, which would otherwise read as moving away from the floor.
func _is_grounded(velocity: Vector3, on_floor: bool, floor_normal: Vector3) -> bool:
	var leaving_plane := floor_normal if _last_floor_normal.is_zero_approx() else _last_floor_normal
	var leaving := velocity.y > 0.0 and velocity.dot(leaving_plane) > LEAVE_FLOOR_SPEED
	return on_floor and floor_normal.y > MIN_FLOOR_NORMAL_Y and not leaving


func _ground_horizontal(
	horizontal: Vector3,
	wish: Vector3,
	tuning: RunnerTuning,
	delta: float,
) -> Vector3:
	if wish.is_zero_approx():
		return horizontal.move_toward(Vector3.ZERO, tuning.ground_friction * delta)
	# Speed above Run speed fades gradually; the allowed speed never drops below Run speed.
	var limit := maxf(tuning.run_speed, horizontal.length() - tuning.overspeed_decay * delta)
	var result := horizontal.move_toward(wish * limit, tuning.ground_accel * delta)
	return result.limit_length(limit)


## No drag in the air. Steering can turn speed above Run speed but never add to it.
func _air_horizontal(
	horizontal: Vector3,
	wish: Vector3,
	tuning: RunnerTuning,
	delta: float,
) -> Vector3:
	if wish.is_zero_approx():
		return horizontal
	var limit := maxf(tuning.run_speed, horizontal.length())
	return (horizontal + wish * tuning.air_accel * delta).limit_length(limit)
