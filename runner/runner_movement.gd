class_name RunnerMovement
extends RefCounted
## Turns what the Player asks for and the Runner's body state into the Runner's next velocity,
## and decides whether the body is low. Never touches nodes, so it can be stepped frame by frame
## without a scene. It continues from whatever velocity it is given, so other mechanics can hand
## speed to it (see docs/adr/0004).

## What the Runner is doing. A Slide and a Crouch are low; Run, Air, a Wall-run and a Mantle
## stand where there is room.
enum State {
	RUN,
	AIR,
	SLIDE,
	CROUCH,
	WALL_RUN,
	MANTLE,
}

## Speed away from the floor plane above which a floor contact is ignored (leaving it), m/s.
const LEAVE_FLOOR_SPEED := 0.5
## Floor normals flatter than this (y component) are too steep to stand on or project onto.
const MIN_FLOOR_NORMAL_Y := 0.1
## A Mantle that has neither landed nor fallen back below its top after this long ends in the
## air, so the Runner is never stuck in one, s.
const MANTLE_TIME_LIMIT := 1.0

var _tuning: RunnerTuning
## Height of the Runner's standing body, m. A ledge with less clear height on top has room only
## to crouch.
var _standing_height: float
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
## The velocity the last step returned, before the engine's collision changed it.
var _last_velocity := Vector3.ZERO
## Horizontal unit normal of the wall being run; meaningful only in a Wall-run.
var _wall_normal := Vector3.ZERO
## Horizontal unit direction the Wall-run runs in, along the wall.
var _wall_direction := Vector3.ZERO
## Horizontal unit normal of the wall the coyote time came from, or zero if it came from the
## floor: a jump in that coyote time is a Wall-jump off that wall.
var _coyote_wall_normal := Vector3.ZERO
## True while the wall last run can't be run again: from the run's start until the Runner lands.
var _wall_locked := false
## Identity of the wall last run; meaningful only while [member _wall_locked].
var _locked_wall_id := 0
## Speed along the wall the last Wall-jump kept, until the next Wall-run starts or the Runner
## lands; INF if there was none. The next Wall-run may be faster only up to the Top wall-run
## speed, unless this was already faster.
var _wall_jump_speed := INF
## Horizontal velocity a Mantle's leap holds; meaningful only in a Mantle.
var _mantle_horizontal := Vector3.ZERO
## Height of the Mantle's top above the feet, m: followed as the leap moves, so it knows when the
## Runner falls back below the top. Meaningful only in a Mantle.
var _mantle_top_above_feet := 0.0
## Time since the Mantle began, s.
var _mantle_time := 0.0
## True if the Mantle's top has room only for the crouched body, so the body stays low through
## the leap. Meaningful only in a Mantle.
var _mantle_low := false
## True while no Mantle can start: from a Mantle's start until the Runner lands. A Mantle that
## ends in the air so never starts again straight away on the same ledge.
var _mantle_locked := false


## [param standing_height] is the height of the Runner's standing body, m.
func _init(tuning: RunnerTuning, standing_height: float) -> void:
	_tuning = tuning
	_standing_height = standing_height


## Returns the Runner's velocity for this physics frame.
func step(intent: Intent, contact: Contact, velocity: Vector3, delta: float) -> Vector3:
	_elapsed += delta
	var grounded := _is_grounded(velocity, contact.on_floor, contact.floor_normal)
	_update_jump_timers(intent.jump_pressed, grounded, delta)
	if _state == State.MANTLE:
		return _step_mantle(intent, contact, velocity, grounded, delta)
	if _state == State.WALL_RUN:
		return _step_wall_run(intent, contact, velocity, grounded, delta)
	if _starts_mantle(intent, contact, grounded):
		return _finish(_start_mantle(contact, velocity), false, contact)
	if _starts_wall_run(intent, contact, velocity, grounded):
		return _finish(_start_wall_run(contact, velocity), false, contact)
	return _step_off_wall(intent, contact, velocity, grounded, delta)


## True if the last step kept the Runner on the floor (it neither was airborne nor jumped),
## so the body should be held down onto the floor even while climbing a slope.
func is_on_ground() -> bool:
	return not _last_floor_normal.is_zero_approx()


## What the Runner was doing in the last step.
func state() -> State:
	return _state


## Horizontal unit normal of the wall being run, or zero when not in a Wall-run.
func wall_normal() -> Vector3:
	return _wall_normal if _state == State.WALL_RUN else Vector3.ZERO


## True if a surface with [param normal] is near enough vertical to be a wall.
func is_wall(normal: Vector3) -> bool:
	if Vector2(normal.x, normal.z).is_zero_approx():
		return false
	return absf(normal.normalized().y) <= sin(deg_to_rad(_tuning.wall_max_tilt))


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


## A step in a Wall-run: a waiting jump is a Wall-jump; steering into the wall with its top
## within reach Mantles onto it; otherwise the run goes on along the wall, or ends keeping its
## velocity and the Runner moves as it would off the wall, so a landing goes on through the
## ground states.
func _step_wall_run(
	intent: Intent,
	contact: Contact,
	velocity: Vector3,
	grounded: bool,
	delta: float,
) -> Vector3:
	if _jump_buffer_timer > 0.0 and not grounded:
		var jump := _wall_jump(Vector3(velocity.x, 0.0, velocity.z), _wall_normal)
		return _finish(jump, false, contact)
	if _starts_mantle(intent, contact, grounded):
		return _finish(_start_mantle(contact, velocity), false, contact)
	var next_normal := _next_wall_normal(grounded, contact, velocity)
	if not next_normal.is_zero_approx():
		_locked_wall_id = contact.wall.id
		return _finish(_wall_run(velocity, next_normal, delta), false, contact)
	# Leaving the wall in the air starts a coyote time for a Wall-jump off it.
	if not grounded:
		_coyote_timer = _tuning.coyote_time
		_coyote_wall_normal = _wall_normal
	_go_airborne()
	return _step_off_wall(intent, contact, velocity, grounded, delta)


## A step on the ground or in the air, jumping if a jump is waiting and allowed.
func _step_off_wall(
	intent: Intent,
	contact: Contact,
	velocity: Vector3,
	grounded: bool,
	delta: float,
) -> Vector3:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var vertical: float
	if grounded:
		horizontal = _update_ground_state(horizontal, intent.crouch_held, contact.headroom)
		match _state:
			State.SLIDE:
				horizontal = _slide_horizontal(
					horizontal,
					intent.move_direction,
					contact.floor_normal,
					delta,
				)
				_end_slide_if_slow(horizontal.length(), contact.headroom)
			State.CROUCH:
				horizontal = _ground_horizontal(
					horizontal,
					intent.move_direction,
					_tuning.crouch_speed,
					delta,
				)
			_:
				horizontal = _ground_horizontal(
					horizontal,
					intent.move_direction,
					_tuning.run_speed,
					delta,
				)
		vertical = _along_floor(horizontal, contact.floor_normal)
	else:
		_go_airborne()
		horizontal = _air_horizontal(horizontal, intent.move_direction, delta)
		vertical = velocity.y - _tuning.gravity * delta
	if _jump_buffer_timer > 0.0 and (grounded or _coyote_timer > 0.0):
		if not _coyote_wall_normal.is_zero_approx():
			var jump := _wall_jump(horizontal, _coyote_wall_normal)
			return _finish(jump, false, contact)
		vertical = maxf(vertical, _launch_speed())
		clear_jump_timers()
		grounded = false
		_go_airborne()
	return _finish(Vector3(horizontal.x, vertical, horizontal.z), grounded, contact)


## Records what this step decided and returns [param velocity].
func _finish(velocity: Vector3, grounded: bool, contact: Contact) -> Vector3:
	_last_floor_normal = contact.floor_normal if grounded else Vector3.ZERO
	# A Slide, a Crouch and a Mantle onto a top with room only to crouch are low. Otherwise a body
	# already low stays low until there is room to stand, even in the air, so it never stands up
	# into a ceiling.
	_low = (
		_state == State.SLIDE or _state == State.CROUCH
		or (_state == State.MANTLE and _mantle_low) or (_low and not contact.headroom)
	)
	_last_velocity = velocity
	return velocity


func _update_jump_timers(jump_pressed: bool, grounded: bool, delta: float) -> void:
	# A jump waiting during a Mantle waits for its landing, however long it lasts.
	if _state != State.MANTLE:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	if jump_pressed:
		_jump_buffer_timer = _tuning.jump_buffer_time
	if grounded:
		_coyote_timer = _tuning.coyote_time
		_coyote_wall_normal = Vector3.ZERO
		_wall_locked = false
		_mantle_locked = false
		_wall_jump_speed = INF
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
	move_direction: Vector3,
	floor_normal: Vector3,
	delta: float,
) -> Vector3:
	var speed_before := horizontal.length()
	horizontal = _steer_slide(horizontal, move_direction, delta)
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


## Turns toward the sideways part of [param move_direction] at up to the slide turn rate, scaled
## by how far sideways the input points. Speed is unchanged.
func _steer_slide(horizontal: Vector3, move_direction: Vector3, delta: float) -> Vector3:
	if horizontal.is_zero_approx():
		return horizontal
	var heading := horizontal.normalized()
	# Positive when the input points left of the heading (a turn about +Y).
	var sideways := heading.cross(move_direction).y
	return horizontal.rotated(Vector3.UP, sideways * _tuning.slide_turn_rate * delta)


## A Slide too slow to go on becomes a Crouch. A released Slide down to Run speed becomes a Run
## once there is room to stand.
func _end_slide_if_slow(speed: float, headroom: bool) -> void:
	if speed < _tuning.slide_to_crouch_speed:
		_state = State.CROUCH
	elif _slide_released and speed <= _tuning.run_speed and headroom:
		_state = State.RUN


## Vertical speed that keeps velocity in the floor plane (v . n = 0) without changing
## horizontal speed.
func _along_floor(horizontal: Vector3, floor_normal: Vector3) -> float:
	return -(horizontal.x * floor_normal.x + horizontal.z * floor_normal.z) / floor_normal.y


## True if the Runner is in the air touching a surface near enough vertical to be a wall.
func _touches_wall_in_air(contact: Contact, grounded: bool) -> bool:
	return not grounded and contact.wall != null and is_wall(contact.wall.normal)


## How head-on [param direction] meets a wall with horizontal unit [param normal], rad: 0 along
## it or away from it, PI / 2 straight into it.
func _head_on_angle(direction: Vector3, normal: Vector3) -> float:
	return asin(clampf(-direction.normalized().dot(normal), 0.0, 1.0))


## True if the Runner, in the air, has a ledge ahead it can Mantle onto: its face is near enough
## vertical to be a wall, the Player holds a direction within the Mantle input angle of straight
## into it, its top is above the feet and within Mantle reach, and at least the crouched body
## fits on it. No Mantle starts again until the Runner has landed since the last one began.
func _starts_mantle(intent: Intent, contact: Contact, grounded: bool) -> bool:
	var ledge := contact.ledge
	if grounded or _mantle_locked or ledge == null or not is_wall(ledge.normal):
		return false
	if intent.move_direction.is_zero_approx():
		return false
	var into := -intent.move_direction.normalized().dot(_horizontal_unit(ledge.normal))
	if into < cos(deg_to_rad(_tuning.mantle_input_angle)):
		return false
	if ledge.top_height <= 0.0 or ledge.top_height > _tuning.mantle_reach:
		return false
	return ledge.clear_height >= _tuning.crouch_height


## Starts a Mantle's leap: upward speed is lifted, never lowered, to just enough for the arc to
## peak the Mantle clearance above the top under the leap gravity. Horizontal velocity is fixed
## for the leap: the speed along the face, plus a part into it of at least the Mantle inward
## speed, at all the speed there was before the face took any, and at least Run speed (see
## docs/adr/0007). A top with room only to crouch takes the body low for the whole leap. Any
## coyote time is forgotten, so a jump waiting for the landing never fires in mid-air if the
## Mantle falls back.
func _start_mantle(contact: Contact, velocity: Vector3) -> Vector3:
	_state = State.MANTLE
	_mantle_locked = true
	_coyote_timer = 0.0
	_mantle_low = contact.ledge.clear_height < _standing_height
	_slide_released = false
	_mantle_time = 0.0
	_mantle_top_above_feet = contact.ledge.top_height
	var normal := _horizontal_unit(contact.ledge.normal)
	var horizontal := _before_wall_collision(velocity, normal)
	var into := maxf(-horizontal.dot(normal), _tuning.mantle_inward_speed)
	var heading := (_along_wall(horizontal, normal) - normal * into).normalized()
	if heading.is_zero_approx():
		heading = -normal
	_mantle_horizontal = heading * maxf(horizontal.length(), _tuning.run_speed)
	var peak := contact.ledge.top_height + _tuning.mantle_clearance
	var vertical := maxf(velocity.y, sqrt(2.0 * _leap_gravity() * peak))
	return _mantle_horizontal + Vector3.UP * vertical


## A step in a Mantle: the leap arcs on under the leap gravity, its horizontal velocity fixed and
## steering ignored. Touching the floor ends it as an ordinary landing. Falling back below the
## top, or lasting [constant MANTLE_TIME_LIMIT], ends it in the air keeping its velocity. Either
## way the Runner then moves as it would off a wall.
func _step_mantle(
	intent: Intent,
	contact: Contact,
	velocity: Vector3,
	grounded: bool,
	delta: float,
) -> Vector3:
	_mantle_time += delta
	# How far the feet rose in the move the engine just made.
	_mantle_top_above_feet -= velocity.y * delta
	var fell_back := velocity.y < 0.0 and _mantle_top_above_feet > 0.0
	if grounded or fell_back or _mantle_time >= MANTLE_TIME_LIMIT:
		_go_airborne()
		return _step_off_wall(intent, contact, velocity, grounded, delta)
	var vertical := velocity.y - _leap_gravity() * delta
	return _finish(_mantle_horizontal + Vector3.UP * vertical, false, contact)


## Gravity during a Mantle's leap, m/s^2.
func _leap_gravity() -> float:
	return _tuning.gravity * _tuning.mantle_leap_gravity_scale


## True if the Runner meets a wall in the air that it can run: fast enough, at a glancing enough
## angle, while the Player holds a direction into or along it, and it isn't the wall last run
## since the Runner landed. Speed is measured before the collision took away the speed going
## into the wall.
func _starts_wall_run(intent: Intent, contact: Contact, velocity: Vector3, grounded: bool) -> bool:
	if not _touches_wall_in_air(contact, grounded):
		return false
	if _wall_locked and contact.wall.id == _locked_wall_id:
		return false
	var normal := _horizontal_unit(contact.wall.normal)
	var horizontal := _before_wall_collision(velocity, normal)
	var speed := horizontal.length()
	if speed < _tuning.wall_run_entry_speed or is_zero_approx(speed):
		return false
	if _head_on_angle(horizontal, normal) > deg_to_rad(_tuning.wall_run_max_entry_angle):
		return false
	if _along_wall(horizontal, normal).is_zero_approx():
		return false
	if intent.move_direction.is_zero_approx():
		return false
	var away := intent.move_direction.normalized().dot(normal)
	return away <= sin(deg_to_rad(_tuning.wall_run_input_angle))


## Starts a Wall-run: all horizontal speed turns along the wall, falling speed is capped and
## upward speed is kept (see docs/adr/0006). Speed a Wall-jump's push adds stops at the Top
## wall-run speed. A jump pressed before meeting the wall is forgotten, so the run isn't cut
## short by a Wall-jump as it starts.
func _start_wall_run(contact: Contact, velocity: Vector3) -> Vector3:
	var normal := _horizontal_unit(contact.wall.normal)
	var horizontal := _before_wall_collision(velocity, normal)
	clear_jump_timers()
	_wall_locked = true
	_locked_wall_id = contact.wall.id
	_state = State.WALL_RUN
	_slide_released = false
	_wall_normal = normal
	_wall_direction = _along_wall(horizontal, normal).normalized()
	# The push of a Wall-jump that brought the Runner here gains speed only up to the cap.
	var speed := minf(horizontal.length(), maxf(_wall_jump_speed, _tuning.top_wall_run_speed))
	_wall_jump_speed = INF
	var vertical := maxf(velocity.y, -_tuning.wall_run_max_entry_fall)
	return _wall_direction * speed + Vector3.UP * vertical


## Horizontal unit normal of the wall a Wall-run goes on along, or zero if the run ends. It goes
## on while the Runner is in the air, touching a wall, and fast enough along it. That wall's
## normal may turn by up to the follow angle from the one being run (a curve). A sharper turn
## goes on only onto a wall blocking the run within the maximum entry angle (an inside corner);
## a sharper turn away is an outside corner.
func _next_wall_normal(grounded: bool, contact: Contact, velocity: Vector3) -> Vector3:
	if not _touches_wall_in_air(contact, grounded):
		return Vector3.ZERO
	var normal := _horizontal_unit(contact.wall.normal)
	var speed := _before_wall_collision(velocity, normal).dot(_wall_direction)
	if speed < _tuning.wall_run_end_speed:
		return Vector3.ZERO
	if _wall_normal.angle_to(normal) <= deg_to_rad(_tuning.wall_run_follow_angle):
		return normal
	var head_on := _head_on_angle(_wall_direction, normal)
	if head_on > 0.0 and head_on <= deg_to_rad(_tuning.wall_run_max_entry_angle):
		return normal
	return Vector3.ZERO


## A Wall-run arcs under reduced gravity and slows gently along the wall with horizontal unit
## [param normal], turning with it if it has turned. Input plays no part.
func _wall_run(velocity: Vector3, normal: Vector3, delta: float) -> Vector3:
	var along := _before_wall_collision(velocity, normal).dot(_wall_direction)
	var speed := maxf(along - _tuning.wall_run_slowdown * delta, 0.0)
	_wall_normal = normal
	_wall_direction = _along_wall(_wall_direction, normal).normalized()
	var vertical := velocity.y - _tuning.gravity * _tuning.wall_run_gravity_scale * delta
	return _wall_direction * speed + Vector3.UP * vertical


## Jumps off the wall with horizontal unit [param normal]: speed along it is kept, the Wall-jump
## push is added straight away from it, and upward speed is the jump's launch speed.
func _wall_jump(horizontal: Vector3, normal: Vector3) -> Vector3:
	var along := _along_wall(horizontal, normal)
	_wall_jump_speed = along.length()
	clear_jump_timers()
	_go_airborne()
	return along + normal * _tuning.wall_jump_push + Vector3.UP * _launch_speed()


## Upward speed of a jump, m/s.
func _launch_speed() -> float:
	return sqrt(2.0 * _tuning.gravity * _tuning.jump_height)


## Horizontal velocity as it was before the engine's collision with the wall of [param normal]
## took away the speed going into it: the speed toward the wall is whichever of [param velocity]
## and the last step's velocity goes into it more. Speed away from a wall that curves away is
## kept.
func _before_wall_collision(velocity: Vector3, normal: Vector3) -> Vector3:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var toward := minf(horizontal.dot(normal), _last_velocity.dot(normal))
	return _along_wall(horizontal, normal) + normal * toward


## The part of [param horizontal] along a wall with horizontal unit [param normal].
func _along_wall(horizontal: Vector3, normal: Vector3) -> Vector3:
	return horizontal - normal * horizontal.dot(normal)


func _horizontal_unit(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z).normalized()


func _go_airborne() -> void:
	_state = State.AIR
	_slide_released = false


func _ground_horizontal(
	horizontal: Vector3,
	move_direction: Vector3,
	max_speed: float,
	delta: float,
) -> Vector3:
	if move_direction.is_zero_approx():
		return horizontal.move_toward(Vector3.ZERO, _tuning.ground_friction * delta)
	# Speed above the state's top speed (Run or Crouch) fades gradually; the allowed speed
	# never drops below it.
	var limit := maxf(max_speed, horizontal.length() - _tuning.overspeed_decay * delta)
	var result := horizontal.move_toward(move_direction * limit, _tuning.ground_accel * delta)
	return result.limit_length(limit)


## No drag in the air. Steering can turn speed above Run speed but never add to it.
func _air_horizontal(horizontal: Vector3, move_direction: Vector3, delta: float) -> Vector3:
	if move_direction.is_zero_approx():
		return horizontal
	var limit := maxf(_tuning.run_speed, horizontal.length())
	return (horizontal + move_direction * _tuning.air_accel * delta).limit_length(limit)


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
	## The standing body fits where the Runner is: always true while it stands; while it is low,
	## whether it could stand up here.
	var headroom: bool
	## The surface that may be a wall the body touches, or null if it touches none.
	var wall: WallContact
	## The ledge ahead in the held direction, or null if there is none.
	var ledge: LedgeContact


	func _init(
		p_on_floor: bool,
		p_floor_normal := Vector3.UP,
		p_headroom := true,
		p_wall: WallContact = null,
		p_ledge: LedgeContact = null,
	) -> void:
		on_floor = p_on_floor
		floor_normal = p_floor_normal
		headroom = p_headroom
		wall = p_wall
		ledge = p_ledge


## A surface the Runner's body touches that may be a wall; RunnerMovement decides whether it is
## near enough vertical to run.
class WallContact:
	## The surface's normal.
	var normal: Vector3
	## Tells walls apart: the same wall always has the same identity.
	var id: int


	func _init(p_normal: Vector3, p_id: int) -> void:
		normal = p_normal
		id = p_id


## A ledge ahead of the Runner: a face that may be a wall, with a top the Runner could Mantle
## onto. RunnerMovement decides whether it can.
class LedgeContact:
	## The face's normal.
	var normal: Vector3
	## Height of the top above the Runner's feet, m.
	var top_height: float
	## How much room there is above the top, m; INF if nothing is near overhead.
	var clear_height: float


	func _init(p_normal: Vector3, p_top_height: float, p_clear_height: float) -> void:
		normal = p_normal
		top_height = p_top_height
		clear_height = p_clear_height
