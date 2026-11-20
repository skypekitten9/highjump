class_name RunnerMovement
extends RefCounted
## Turns what the Player asks for and the Runner's body state into the Runner's next velocity.
## Never touches nodes, so it can be stepped frame by frame without a scene. It continues from
## whatever velocity it is given, so other mechanics can hand speed to it (see docs/adr/0004).

## What the Runner is doing. A Slide and a Crouch are low; Run and Air are standing.
enum State {
	RUN,
	AIR,
	SLIDE,
	CROUCH,
}

## Speed away from the floor plane above which a floor contact is ignored (leaving it), m/s.
const LEAVE_FLOOR_SPEED := 0.5
## Floor normals flatter than this (y component) are too steep to stand on or project onto.
const MIN_FLOOR_NORMAL_Y := 0.1

var _state := State.RUN
## True while a Slide carries on after crouch was released, winding down toward a Run.
var _slide_released := false
## Time left in which a jump still fires after leaving the floor, s.
var _coyote_timer := 0.0
## Time left in which a jump press is still waiting to fire, s.
var _jump_buffer_timer := 0.0
## Normal of the floor the Runner stayed on last frame; zero if it was airborne or jumped.
var _last_floor_normal := Vector3.ZERO
## Time since this stepper was created, s. Measures the Slide boost cooldown.
var _time := 0.0
## [member _time] when the last Slide began; far in the past if none has.
var _last_slide_start := -INF


## Returns the Runner's velocity for this physics frame.
## [param wish]: world-space horizontal move direction, length 0..1.
## [param jump_pressed]: true only on the frame the jump was pressed, not while it is held.
## [param crouch_held]: the crouch input is held this frame.
## [param can_stand]: there is room for the standing body (true while it is already standing).
## [param floor_normal]: the floor's normal; ignored when [param on_floor] is false.
func step(
	wish: Vector3,
	jump_pressed: bool,
	crouch_held: bool,
	can_stand: bool,
	velocity: Vector3,
	on_floor: bool,
	floor_normal: Vector3,
	tuning: RunnerTuning,
	delta: float,
) -> Vector3:
	_time += delta
	var grounded := _is_grounded(velocity, on_floor, floor_normal)
	_update_jump_timers(jump_pressed, grounded, tuning, delta)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var vertical: float
	if grounded:
		horizontal = _update_ground_state(horizontal, crouch_held, can_stand, tuning)
		match _state:
			State.SLIDE:
				horizontal = _slide_horizontal(horizontal, wish, tuning, delta)
				_end_slide_if_slow(horizontal.length(), can_stand, tuning)
			State.CROUCH:
				horizontal = _ground_horizontal(
					horizontal,
					wish,
					tuning.crouch_speed,
					tuning,
					delta,
				)
			_:
				horizontal = _ground_horizontal(horizontal, wish, tuning.run_speed, tuning, delta)
		# Keep velocity in the floor plane (v . n = 0) without changing horizontal speed.
		vertical = (
			-(horizontal.x * floor_normal.x + horizontal.z * floor_normal.z) / floor_normal.y
		)
	else:
		_go_airborne()
		horizontal = _air_horizontal(horizontal, wish, tuning, delta)
		vertical = velocity.y - tuning.gravity * delta
	if _jump_buffer_timer > 0.0 and (grounded or _coyote_timer > 0.0):
		vertical = maxf(vertical, sqrt(2.0 * tuning.gravity * tuning.jump_height))
		clear_jump_timers()
		grounded = false
		_go_airborne()
	_last_floor_normal = floor_normal if grounded else Vector3.ZERO
	return Vector3(horizontal.x, vertical, horizontal.z)


## True if the last step kept the Runner on the floor (it neither was airborne nor jumped),
## so the body should be held down onto the floor even while climbing a slope.
func is_on_ground() -> bool:
	return not _last_floor_normal.is_zero_approx()


## What the Runner was doing in the last step.
func state() -> State:
	return _state


## True if the last step was a Slide that carries on after crouch was released.
func is_slide_released() -> bool:
	return _state == State.SLIDE and _slide_released


## True if the body should be low after the last step.
func is_low() -> bool:
	return _state == State.SLIDE or _state == State.CROUCH


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


## Ground state changes before this frame's movement. Returns the horizontal velocity, boosted
## if a Slide begins.
func _update_ground_state(
	horizontal: Vector3,
	crouch_held: bool,
	can_stand: bool,
	tuning: RunnerTuning,
) -> Vector3:
	match _state:
		State.RUN:
			if crouch_held and horizontal.length() >= tuning.slide_entry_speed:
				return _start_slide(horizontal, tuning)
			if crouch_held or not can_stand:
				_state = State.CROUCH
		State.SLIDE:
			# Releasing crouch lets the Slide wind down; pressing it again continues the same
			# Slide, with no new boost.
			_slide_released = not crouch_held
		_:
			# Crouch, or landing: crouch while crouch is held, and stand back up to Run only
			# once crouch is released and there is room.
			_state = State.CROUCH if crouch_held or not can_stand else State.RUN
	return horizontal


## Starts a Slide with a boost scaled by how long ago the last Slide began: none just after it,
## full once the cooldown has passed.
func _start_slide(horizontal: Vector3, tuning: RunnerTuning) -> Vector3:
	var since_last := _time - _last_slide_start
	var share := clampf(since_last / maxf(tuning.slide_boost_cooldown, 0.001), 0.0, 1.0)
	_state = State.SLIDE
	_slide_released = false
	_last_slide_start = _time
	var speed := horizontal.length()
	# Capped, so landing into Slides again and again can't stack boosts; only slopes take a
	# Slide faster. A Slide already past the cap is never slowed.
	var cap := minf(tuning.run_speed + tuning.slide_boost, tuning.top_slide_speed)
	var boosted := maxf(speed, minf(speed + tuning.slide_boost * share, cap))
	return horizontal.normalized() * boosted


## A Slide glides on its momentum: slide friction above Run speed, and slow-slide friction below
## it so a slow Slide dies quickly; once released, it winds down at the released-slide
## deceleration instead. Input only steers it, and only its sideways part: holding a
## direction never adds or removes speed.
func _slide_horizontal(
	horizontal: Vector3,
	wish: Vector3,
	tuning: RunnerTuning,
	delta: float,
) -> Vector3:
	horizontal = _steer_slide(horizontal, wish, tuning, delta)
	var friction := tuning.slide_friction
	if _slide_released:
		friction = tuning.released_slide_decel
	elif horizontal.length() < tuning.run_speed:
		friction = tuning.slow_slide_friction
	return horizontal.move_toward(Vector3.ZERO, friction * delta)


## Turns toward the sideways part of [param wish] at up to the slide turn rate, scaled by how
## far sideways the input points. Speed is unchanged.
func _steer_slide(
	horizontal: Vector3,
	wish: Vector3,
	tuning: RunnerTuning,
	delta: float,
) -> Vector3:
	if horizontal.is_zero_approx():
		return horizontal
	var heading := horizontal.normalized()
	# Positive when the input points left of the heading (a turn about +Y).
	var sideways := heading.cross(wish).y
	return horizontal.rotated(Vector3.UP, sideways * tuning.slide_turn_rate * delta)


## A Slide too slow to go on becomes a Crouch. A released Slide down to Run speed becomes a Run
## once there is room to stand.
func _end_slide_if_slow(speed: float, can_stand: bool, tuning: RunnerTuning) -> void:
	if speed < tuning.slide_to_crouch_speed:
		_state = State.CROUCH
	elif _slide_released and speed <= tuning.run_speed and can_stand:
		_state = State.RUN


func _go_airborne() -> void:
	_state = State.AIR
	_slide_released = false


func _ground_horizontal(
	horizontal: Vector3,
	wish: Vector3,
	max_speed: float,
	tuning: RunnerTuning,
	delta: float,
) -> Vector3:
	if wish.is_zero_approx():
		return horizontal.move_toward(Vector3.ZERO, tuning.ground_friction * delta)
	# Speed above the state's top speed (Run or Crouch) fades gradually; the allowed speed
	# never drops below it.
	var limit := maxf(max_speed, horizontal.length() - tuning.overspeed_decay * delta)
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
