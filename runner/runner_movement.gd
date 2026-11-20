class_name RunnerMovement
extends RefCounted
## Turns what the Player asks for and the Runner's body state into the Runner's next velocity,
## and decides whether the body is low. Never touches nodes, so it can be stepped frame by frame
## without a scene. It continues from whatever velocity it is given, so other mechanics can hand
## speed to it (see docs/adr/0004).

## What the Runner is doing. A Slide and a Crouch are low; Run and Air stand where there is room.
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

var _tuning: RunnerTuning
var _state := State.RUN
## True if the body is low after the last step.
var _low := false
## True while a Slide carries on after crouch was released, winding down toward a Run.
var _slide_released := false
## Time left in which a jump still fires after leaving the floor, s.
var _coyote_timer := 0.0
## Time left in which a jump press is still waiting to fire, s.
var _jump_buffer_timer := 0.0
## Normal of the floor the Runner stayed on last frame; zero if it was airborne or jumped.
var _last_floor_normal := Vector3.ZERO
## Time since this stepper was created, s. Measures the Slide boost cooldown.
var _elapsed := 0.0
## [member _elapsed] when the last Slide began; far in the past if none has.
var _last_slide_start := -INF


func _init(tuning: RunnerTuning) -> void:
	_tuning = tuning


## Returns the Runner's velocity for this physics frame.
func step(intent: Intent, contact: Contact, velocity: Vector3, delta: float) -> Vector3:
	_elapsed += delta
	var wish := intent.move_direction
	var crouch_held := intent.crouch_held
	var headroom := contact.headroom
	var floor_normal := contact.floor_normal
	var grounded := _is_grounded(velocity, contact.on_floor, floor_normal)
	_update_jump_timers(intent.jump_pressed, grounded, delta)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var vertical: float
	if grounded:
		horizontal = _update_ground_state(horizontal, crouch_held, headroom)
		match _state:
			State.SLIDE:
				horizontal = _slide_horizontal(horizontal, wish, floor_normal, delta)
				_end_slide_if_slow(horizontal.length(), headroom)
			State.CROUCH:
				horizontal = _ground_horizontal(horizontal, wish, _tuning.crouch_speed, delta)
			_:
				horizontal = _ground_horizontal(horizontal, wish, _tuning.run_speed, delta)
		# Keep velocity in the floor plane (v . n = 0) without changing horizontal speed.
		vertical = (
			-(horizontal.x * floor_normal.x + horizontal.z * floor_normal.z) / floor_normal.y
		)
	else:
		_go_airborne()
		horizontal = _air_horizontal(horizontal, wish, delta)
		vertical = velocity.y - _tuning.gravity * delta
	if _jump_buffer_timer > 0.0 and (grounded or _coyote_timer > 0.0):
		vertical = maxf(vertical, sqrt(2.0 * _tuning.gravity * _tuning.jump_height))
		clear_jump_timers()
		grounded = false
		_go_airborne()
	_last_floor_normal = floor_normal if grounded else Vector3.ZERO
	# A Slide or a Crouch is low. Otherwise a body already low stays low until there is room to
	# stand, even in the air, so it never stands up into a ceiling.
	_low = _state == State.SLIDE or _state == State.CROUCH or (_low and not headroom)
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


## True if the body should be low after the last step: in a Slide or a Crouch, or still low
## from one with no room to stand yet, airborne included.
func is_low() -> bool:
	return _low


## Forgets any waiting jump press and any coyote time. For mechanics that hand control back
## (the Vault), so a stale press doesn't fire afterwards.
func clear_jump_timers() -> void:
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0


func _update_jump_timers(jump_pressed: bool, grounded: bool, delta: float) -> void:
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	if jump_pressed:
		_jump_buffer_timer = _tuning.jump_buffer_time
	if grounded:
		_coyote_timer = _tuning.coyote_time
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
func _update_ground_state(horizontal: Vector3, crouch_held: bool, headroom: bool) -> Vector3:
	match _state:
		State.RUN:
			if _wants_slide(horizontal, crouch_held):
				return _start_slide(horizontal)
			if _must_stay_low(crouch_held, headroom):
				_state = State.CROUCH
		State.SLIDE:
			# Releasing crouch lets the Slide wind down; pressing it again continues the same
			# Slide, with no new boost.
			_slide_released = not crouch_held
		State.AIR when _wants_slide(horizontal, crouch_held):
			# A slide-hop: land straight into a Slide, keeping all speed.
			return _start_slide(horizontal)
		_:
			# Crouch, or landing: crouch while crouch is held, and stand back up to Run only
			# once crouch is released and there is room.
			_state = State.CROUCH if _must_stay_low(crouch_held, headroom) else State.RUN
	return horizontal


## True if crouch is held fast enough to begin a Slide.
func _wants_slide(horizontal: Vector3, crouch_held: bool) -> bool:
	return crouch_held and horizontal.length() >= _tuning.slide_entry_speed


## True if the body has to be low: crouch is held, or there is no room to stand.
func _must_stay_low(crouch_held: bool, headroom: bool) -> bool:
	return crouch_held or not headroom


## Starts a Slide with a boost scaled by how long ago the last Slide began: none just after it,
## full once the cooldown has passed.
func _start_slide(horizontal: Vector3) -> Vector3:
	var since_last := _elapsed - _last_slide_start
	var boost_fraction := clampf(since_last / _tuning.slide_boost_cooldown, 0.0, 1.0)
	_state = State.SLIDE
	_slide_released = false
	_last_slide_start = _elapsed
	var speed := horizontal.length()
	# Capped, so landing into Slides again and again can't stack boosts; only slopes take a
	# Slide faster. A Slide already past the cap is never slowed.
	var cap := minf(_tuning.run_speed + _tuning.slide_boost, _tuning.top_slide_speed)
	var boosted := maxf(speed, minf(speed + _tuning.slide_boost * boost_fraction, cap))
	return horizontal.normalized() * boosted


## A Slide glides on its momentum: slide friction above Run speed, and slow-slide friction below
## it so a slow Slide dies quickly; once released, it winds down at the released-slide
## deceleration instead. Input only steers it, and only its sideways part: holding a
## direction never adds or removes speed. Slopes add speed downhill and remove it uphill, but
## never take it past the top slide speed; a Slide already faster than that keeps its speed
## (see docs/adr/0004).
func _slide_horizontal(
	horizontal: Vector3,
	wish: Vector3,
	floor_normal: Vector3,
	delta: float,
) -> Vector3:
	var speed_before := horizontal.length()
	horizontal = _steer_slide(horizontal, wish, delta)
	horizontal = _slope_slide(horizontal, floor_normal, delta)
	if _slide_released:
		# Holding crouch is the deliberate choice to keep gaining; released, slopes only slow it.
		horizontal = horizontal.limit_length(speed_before)
	var friction := _tuning.slide_friction
	if _slide_released:
		friction = _tuning.released_slide_decel
	elif speed_before < _tuning.run_speed:
		friction = _tuning.slow_slide_friction
	horizontal = horizontal.move_toward(Vector3.ZERO, friction * delta)
	return horizontal.limit_length(maxf(speed_before, _tuning.top_slide_speed))


## Adds the horizontal part of gravity along the floor, times the slope gain: speed downhill,
## less speed uphill.
func _slope_slide(horizontal: Vector3, floor_normal: Vector3, delta: float) -> Vector3:
	var downhill := Vector3(floor_normal.x, 0.0, floor_normal.z) * floor_normal.y
	return horizontal + downhill * _tuning.gravity * _tuning.slope_gain * delta


## Turns toward the sideways part of [param wish] at up to the slide turn rate, scaled by how
## far sideways the input points. Speed is unchanged.
func _steer_slide(horizontal: Vector3, wish: Vector3, delta: float) -> Vector3:
	if horizontal.is_zero_approx():
		return horizontal
	var heading := horizontal.normalized()
	# Positive when the input points left of the heading (a turn about +Y).
	var sideways := heading.cross(wish).y
	return horizontal.rotated(Vector3.UP, sideways * _tuning.slide_turn_rate * delta)


## A Slide too slow to go on becomes a Crouch. A released Slide down to Run speed becomes a Run
## once there is room to stand.
func _end_slide_if_slow(speed: float, headroom: bool) -> void:
	if speed < _tuning.slide_to_crouch_speed:
		_state = State.CROUCH
	elif _slide_released and speed <= _tuning.run_speed and headroom:
		_state = State.RUN


func _go_airborne() -> void:
	_state = State.AIR
	_slide_released = false


func _ground_horizontal(
	horizontal: Vector3,
	wish: Vector3,
	max_speed: float,
	delta: float,
) -> Vector3:
	if wish.is_zero_approx():
		return horizontal.move_toward(Vector3.ZERO, _tuning.ground_friction * delta)
	# Speed above the state's top speed (Run or Crouch) fades gradually; the allowed speed
	# never drops below it.
	var limit := maxf(max_speed, horizontal.length() - _tuning.overspeed_decay * delta)
	var result := horizontal.move_toward(wish * limit, _tuning.ground_accel * delta)
	return result.limit_length(limit)


## No drag in the air. Steering can turn speed above Run speed but never add to it.
func _air_horizontal(horizontal: Vector3, wish: Vector3, delta: float) -> Vector3:
	if wish.is_zero_approx():
		return horizontal
	var limit := maxf(_tuning.run_speed, horizontal.length())
	return (horizontal + wish * _tuning.air_accel * delta).limit_length(limit)


## What the Player asks the Runner to do this physics frame.
class Intent:
	## World-space horizontal move direction, length 0..1.
	var move_direction: Vector3
	## True only on the frame the jump was pressed, not while it is held.
	var jump_pressed: bool
	## The crouch input is held this frame.
	var crouch_held: bool


	func _init(
		p_move_direction := Vector3.ZERO,
		p_jump_pressed := false,
		p_crouch_held := false,
	) -> void:
		move_direction = p_move_direction
		jump_pressed = p_jump_pressed
		crouch_held = p_crouch_held


## How the Runner's body touches the world this physics frame.
class Contact:
	## The body touches a floor.
	var on_floor: bool
	## The floor's normal; ignored when [member on_floor] is false.
	var floor_normal: Vector3
	## There is room for the standing body where the Runner is, whatever its posture now.
	var headroom: bool


	func _init(p_on_floor: bool, p_floor_normal := Vector3.UP, p_headroom := true) -> void:
		on_floor = p_on_floor
		floor_normal = p_floor_normal
		headroom = p_headroom
