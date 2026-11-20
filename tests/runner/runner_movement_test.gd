extends GdUnitTestSuite
## Ground and air movement of the Runner, stepped frame by frame at 60 Hz with the default tuning.
## Expected values come from that tuning, so retuning the preset doesn't break these tests.

const DELTA := 1.0 / 60.0
const FORWARD := Vector3.FORWARD
## How far above Run speed the "faster than Run speed" cases start, m/s.
const OVERSPEED := 5.0
## Height of the Runner's standing body, m.
const STANDING_HEIGHT := 1.8

var _tuning: RunnerTuning
var _movement: RunnerMovement


func before_test() -> void:
	_tuning = load("res://runner/default_runner_tuning.tres")
	_movement = RunnerMovement.new(_tuning, STANDING_HEIGHT)


## The Player holding [param direction], or no move input.
func _moving(direction := Vector3.ZERO) -> RunnerMovement.Intent:
	return RunnerMovement.Intent.new(direction)


## The Player pressing jump this frame while holding [param direction].
func _jumping(direction := Vector3.ZERO) -> RunnerMovement.Intent:
	return RunnerMovement.Intent.new(direction, true)


## The Player holding crouch and [param direction].
func _crouching(direction := Vector3.ZERO) -> RunnerMovement.Intent:
	return RunnerMovement.Intent.new(direction, false, true)


## Standing on a floor with [param normal], room to stand overhead.
func _on_floor(normal := Vector3.UP) -> RunnerMovement.Contact:
	return RunnerMovement.Contact.new(true, normal)


## Touching no floor, room to stand overhead.
func _in_air() -> RunnerMovement.Contact:
	return RunnerMovement.Contact.new(false)


## On flat ground under a ceiling too low for the standing body.
func _under_ceiling() -> RunnerMovement.Contact:
	return RunnerMovement.Contact.new(true, Vector3.UP, false)


func _horizontal_speed(velocity: Vector3) -> float:
	return Vector2(velocity.x, velocity.z).length()


func _run_speed() -> float:
	return _tuning.run_speed


## Upward speed of a jump that peaks at the tuned jump height.
func _launch_speed() -> float:
	return sqrt(2.0 * _tuning.gravity * _tuning.jump_height)


## Frames from a moment to just inside a window of [param seconds] after it.
func _frames_inside(seconds: float) -> int:
	return roundi(seconds / DELTA) - 1


## Frames from a moment to clearly past a window of [param seconds] after it.
func _frames_past(seconds: float) -> int:
	return roundi(seconds / DELTA) + 3


func test_holding_forward_from_rest_reaches_run_speed_quickly_and_never_exceeds_it() -> void:
	var velocity := Vector3.ZERO
	var frames_to_run_speed := -1
	for frame: int in 60:
		velocity = _movement.step(_moving(FORWARD), _on_floor(), velocity, DELTA)
		var speed := _horizontal_speed(velocity)
		assert_float(speed).is_less_equal(_run_speed() + 0.001)
		if frames_to_run_speed < 0 and is_equal_approx(speed, _run_speed()):
			frames_to_run_speed = frame + 1
	assert_int(frames_to_run_speed).is_between(1, 6)


func test_releasing_input_at_run_speed_stops_quickly() -> void:
	var velocity := FORWARD * _run_speed()
	var frames_to_stop := -1
	for frame: int in 60:
		velocity = _movement.step(_moving(), _on_floor(), velocity, DELTA)
		if frames_to_stop < 0 and velocity.is_zero_approx():
			frames_to_stop = frame + 1
	assert_int(frames_to_stop).is_between(1, 6)


func test_diagonal_input_is_capped_at_run_speed() -> void:
	var diagonal := Vector2(1.0, -1.0).limit_length(1.0)
	var wish := Vector3(diagonal.x, 0.0, diagonal.y)
	var velocity := Vector3.ZERO
	for frame: int in 60:
		velocity = _movement.step(_moving(wish), _on_floor(), velocity, DELTA)
		assert_float(_horizontal_speed(velocity)).is_less_equal(_run_speed() + 0.001)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(_run_speed(), 0.001)


func test_ground_velocity_lies_in_a_45_degree_floor_plane() -> void:
	var normal := Vector3(0.0, 1.0, 1.0).normalized()
	for wish: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT]:
		var velocity := Vector3.ZERO
		for frame: int in 30:
			velocity = _movement.step(_moving(wish), _on_floor(normal), velocity, DELTA)
			assert_float(velocity.dot(normal)).is_equal_approx(0.0, 0.001)
		assert_float(_horizontal_speed(velocity)).is_equal_approx(_run_speed(), 0.001)


func test_in_the_air_gravity_pulls_down_and_horizontal_velocity_is_kept() -> void:
	var velocity := Vector3(3.0, 0.0, -4.0)
	for frame: int in 30:
		velocity = _movement.step(_moving(), _in_air(), velocity, DELTA)
	# 0.5 s of gravity.
	assert_float(velocity.y).is_equal_approx(-_tuning.gravity * 0.5, 0.001)
	assert_vector(Vector3(velocity.x, 0.0, velocity.z)).is_equal_approx(
		Vector3(3.0, 0.0, -4.0),
		Vector3.ONE * 0.001,
	)


func test_a_floor_contact_while_moving_away_from_the_floor_does_not_ground_the_runner() -> void:
	var velocity := Vector3(0.0, 5.0, -_run_speed())
	velocity = _movement.step(_moving(FORWARD), _on_floor(), velocity, DELTA)
	# Not snapped onto the floor plane: gravity applied to the upward speed instead.
	assert_float(velocity.y).is_equal_approx(5.0 - _tuning.gravity * DELTA, 0.001)


func test_running_down_a_45_degree_ramp_stays_on_the_ground() -> void:
	# The ramp descends toward +Z, so running back is running downhill.
	var ramp := Vector3(0.0, 1.0, 1.0).normalized()
	var velocity := Vector3.BACK * _run_speed()
	for frame: int in 30:
		# The engine's movement step zeroes vertical velocity going down a slope.
		velocity.y = 0.0
		velocity = _movement.step(_moving(Vector3.BACK), _on_floor(ramp), velocity, DELTA)
		# Grounded: velocity follows the ramp down instead of falling under gravity.
		assert_float(velocity.dot(ramp)).is_equal_approx(0.0, 0.001)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(_run_speed(), 0.001)


func test_a_jump_off_a_downhill_ramp_is_not_grounded_on_the_next_floor_contact() -> void:
	var ramp := Vector3(0.0, 1.0, 1.0).normalized()
	var velocity := _movement.step(
		_jumping(Vector3.BACK),
		_on_floor(ramp),
		Vector3.BACK * _run_speed(),
		DELTA,
	)
	var take_off := velocity.y
	assert_float(take_off).is_greater(0.0)
	velocity = _movement.step(_moving(Vector3.BACK), _on_floor(ramp), velocity, DELTA)
	# Not snapped onto the ramp: gravity applied to the take-off speed instead.
	assert_float(velocity.y).is_equal_approx(take_off - _tuning.gravity * DELTA, 0.001)


func test_running_up_a_45_degree_ramp_onto_flat_ground_stays_on_the_ground() -> void:
	var ramp := Vector3(0.0, 1.0, 1.0).normalized()
	var velocity := Vector3.ZERO
	for frame: int in 30:
		velocity = _movement.step(_moving(FORWARD), _on_floor(ramp), velocity, DELTA)
	assert_float(velocity.y).is_greater(_run_speed() - 0.001)
	# Over the crest: the floor turns flat while the velocity still climbs at 45 degrees.
	velocity = _movement.step(_moving(FORWARD), _on_floor(), velocity, DELTA)
	assert_float(velocity.y).is_equal_approx(0.0, 0.001)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(_run_speed(), 0.001)


func test_in_the_air_below_run_speed_steering_speeds_up_to_run_speed_and_no_further() -> void:
	var velocity := Vector3.ZERO
	for frame: int in 60:
		velocity = _movement.step(_moving(FORWARD), _in_air(), velocity, DELTA)
		assert_float(_horizontal_speed(velocity)).is_less_equal(_run_speed() + 0.001)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(_run_speed(), 0.001)


func test_in_the_air_above_run_speed_steering_sideways_keeps_speed_and_turns() -> void:
	var speed := _run_speed() + OVERSPEED
	var velocity := FORWARD * speed
	for frame: int in 60:
		velocity = _movement.step(_moving(Vector3.RIGHT), _in_air(), velocity, DELTA)
		assert_float(_horizontal_speed(velocity)).is_less_equal(speed + 0.001)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(speed, 0.01)
	# Heading has swung well toward the right.
	assert_float(velocity.x).is_greater(speed * 0.5)


func test_landing_above_run_speed_with_forward_held_fades_to_run_speed() -> void:
	var velocity := FORWARD * (_run_speed() + OVERSPEED)
	var fade_frames := ceili(OVERSPEED / _tuning.overspeed_decay / DELTA)
	var half := floori(fade_frames / 2.0)
	for frame: int in half:
		velocity = _movement.step(_moving(FORWARD), _on_floor(), velocity, DELTA)
	# Halfway through the fade, about half the excess is left.
	assert_float(_horizontal_speed(velocity)).is_greater(_run_speed() + OVERSPEED * 0.25)
	for frame: int in fade_frames - half:
		velocity = _movement.step(_moving(FORWARD), _on_floor(), velocity, DELTA)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(_run_speed(), 0.2)


func test_holding_back_on_the_ground_brakes_faster_than_overspeed_decay() -> void:
	var speed := _run_speed() + OVERSPEED
	var velocity := FORWARD * speed
	for frame: int in 6:
		velocity = _movement.step(_moving(Vector3.BACK), _on_floor(), velocity, DELTA)
	var decay_alone := _tuning.overspeed_decay * 6 * DELTA
	assert_float(_horizontal_speed(velocity)).is_less(speed - decay_alone - 3.0)


func test_jump_launches_at_the_speed_for_the_jump_height_and_peaks_near_it() -> void:
	var velocity := _movement.step(_jumping(), _on_floor(), Vector3.ZERO, DELTA)
	assert_float(velocity.y).is_equal_approx(_launch_speed(), 0.001)
	var height := 0.0
	var peak := 0.0
	for frame: int in 120:
		# The body moves with this frame's velocity before the next step applies gravity.
		height += velocity.y * DELTA
		peak = maxf(peak, height)
		velocity = _movement.step(_moving(), _in_air(), velocity, DELTA)
	assert_float(peak).is_between(_tuning.jump_height, _tuning.jump_height + 0.1)


## Falls, pressing jump [param frames_before] frames before the landing frame, then lands.
## Returns the velocity on the landing frame.
func _land_after_early_press(frames_before: int) -> Vector3:
	var falling := Vector3(0.0, -5.0, 0.0)
	_movement.step(_jumping(), _in_air(), falling, DELTA)
	for frame: int in frames_before - 1:
		_movement.step(_moving(), _in_air(), falling, DELTA)
	return _movement.step(_moving(), _on_floor(), falling, DELTA)


## Stands, walks off the floor, and presses jump on the [param frames_after]th airborne frame.
## Returns the velocity on that frame.
func _press_after_leaving_floor(frames_after: int) -> Vector3:
	for frame: int in 10:
		_movement.step(_moving(FORWARD), _on_floor(), Vector3.ZERO, DELTA)
	var falling := Vector3(0.0, -1.0, 0.0)
	for frame: int in frames_after - 1:
		_movement.step(_moving(), _in_air(), falling, DELTA)
	return _movement.step(_jumping(), _in_air(), falling, DELTA)


func test_a_jump_pressed_just_inside_the_jump_buffer_before_landing_fires_on_landing() -> void:
	var frames := _frames_inside(_tuning.jump_buffer_time)
	assert_float(_land_after_early_press(frames).y).is_equal_approx(_launch_speed(), 0.001)


func test_a_jump_pressed_past_the_jump_buffer_before_landing_does_not_fire() -> void:
	var frames := _frames_past(_tuning.jump_buffer_time)
	assert_float(_land_after_early_press(frames).y).is_equal_approx(0.0, 0.001)


func test_a_jump_pressed_just_inside_coyote_time_after_leaving_the_floor_fires() -> void:
	var frames := _frames_inside(_tuning.coyote_time)
	assert_float(_press_after_leaving_floor(frames).y).is_equal_approx(_launch_speed(), 0.001)


func test_a_jump_pressed_past_coyote_time_after_leaving_the_floor_does_not_fire() -> void:
	var frames := _frames_past(_tuning.coyote_time)
	assert_float(_press_after_leaving_floor(frames).y).is_less(0.0)


func test_one_press_gives_one_jump() -> void:
	var velocity := _movement.step(_jumping(), _on_floor(), Vector3.ZERO, DELTA)
	var height := 0.0
	var launches := 1
	# Jump held for the rest of the run: only the first frame counts as a press.
	for frame: int in 180:
		height += velocity.y * DELTA
		var was_rising := velocity.y > 1.0
		if height <= 0.0:
			height = 0.0
			velocity = _movement.step(_moving(), _on_floor(), velocity, DELTA)
		else:
			velocity = _movement.step(_moving(), _in_air(), velocity, DELTA)
		if velocity.y > 1.0 and not was_rising:
			launches += 1
	assert_int(launches).is_equal(1)


func test_after_the_jump_timers_are_cleared_a_buffered_press_does_not_fire() -> void:
	var falling := Vector3(0.0, -5.0, 0.0)
	_movement.step(_jumping(), _in_air(), falling, DELTA)
	_movement.clear_jump_timers()
	assert_float(_movement.step(_moving(), _on_floor(), falling, DELTA).y).is_equal_approx(
		0.0,
		0.001,
	)


func test_after_the_jump_timers_are_cleared_coyote_time_is_gone() -> void:
	for frame: int in 10:
		_movement.step(_moving(FORWARD), _on_floor(), Vector3.ZERO, DELTA)
	_movement.clear_jump_timers()
	assert_float(_movement.step(_jumping(), _in_air(), Vector3(0.0, -1.0, 0.0), DELTA).y).is_less(
		0.0
	)


func test_crouching_from_rest_moves_low_and_at_most_at_crouch_speed() -> void:
	var velocity := Vector3.ZERO
	for frame: int in 60:
		velocity = _movement.step(_crouching(FORWARD), _on_floor(), velocity, DELTA)
		assert_float(_horizontal_speed(velocity)).is_less_equal(_tuning.crouch_speed + 0.001)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(_tuning.crouch_speed, 0.001)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.CROUCH)
	assert_bool(_movement.is_low()).is_true()


func test_releasing_crouch_with_room_to_stand_returns_to_run() -> void:
	var velocity := Vector3.ZERO
	for frame: int in 30:
		velocity = _movement.step(_crouching(FORWARD), _on_floor(), velocity, DELTA)
	velocity = _movement.step(_moving(FORWARD), _on_floor(), velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.RUN)
	assert_bool(_movement.is_low()).is_false()
	for frame: int in 30:
		velocity = _movement.step(_moving(FORWARD), _on_floor(), velocity, DELTA)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(_run_speed(), 0.001)


func test_releasing_crouch_without_room_to_stand_stays_a_crouch_until_there_is_room() -> void:
	var velocity := Vector3.ZERO
	for frame: int in 30:
		velocity = _movement.step(_crouching(FORWARD), _on_floor(), velocity, DELTA)
	for frame: int in 60:
		velocity = _movement.step(_moving(FORWARD), _under_ceiling(), velocity, DELTA)
		assert_int(_movement.state()).is_equal(RunnerMovement.State.CROUCH)
		assert_bool(_movement.is_low()).is_true()
		assert_float(_horizontal_speed(velocity)).is_less_equal(_tuning.crouch_speed + 0.001)
	_movement.step(_moving(FORWARD), _on_floor(), velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.RUN)


func test_landing_without_room_to_stand_is_a_crouch() -> void:
	var falling := Vector3(0.0, -5.0, 0.0)
	_movement.step(_moving(), _in_air(), falling, DELTA)
	assert_bool(_movement.is_low()).is_false()
	_movement.step(_moving(FORWARD), _under_ceiling(), falling, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.CROUCH)


## Touching no floor, under a ceiling too low for the standing body.
func _in_air_under_ceiling() -> RunnerMovement.Contact:
	return RunnerMovement.Contact.new(false, Vector3.UP, false)


func test_leaving_the_ground_low_without_room_to_stand_stays_low_until_there_is_room() -> void:
	var velocity := Vector3.ZERO
	for frame: int in 30:
		velocity = _movement.step(_crouching(FORWARD), _on_floor(), velocity, DELTA)
	# Released crouch under a ceiling, then dropped off a ledge still beneath it.
	velocity = _movement.step(_moving(FORWARD), _under_ceiling(), velocity, DELTA)
	for frame: int in 10:
		velocity = _movement.step(_moving(FORWARD), _in_air_under_ceiling(), velocity, DELTA)
		assert_int(_movement.state()).is_equal(RunnerMovement.State.AIR)
		assert_bool(_movement.is_low()).is_true()
	_movement.step(_moving(FORWARD), _in_air(), velocity, DELTA)
	assert_bool(_movement.is_low()).is_false()


func test_default_run_speed_is_9_metres_per_second() -> void:
	assert_float(_run_speed()).is_equal(9.0)


## Runs on flat ground at Run speed long enough that no Slide began recently.
func _run_past_the_boost_cooldown() -> Vector3:
	var velocity := FORWARD * _run_speed()
	for frame: int in _frames_past(_tuning.slide_boost_cooldown):
		velocity = _movement.step(_moving(FORWARD), _on_floor(), velocity, DELTA)
	return velocity


func test_crouching_at_slide_entry_speed_starts_a_slide_with_the_full_boost() -> void:
	_run_past_the_boost_cooldown()
	var velocity := _movement.step(
		_crouching(FORWARD),
		_on_floor(),
		FORWARD * _tuning.slide_entry_speed,
		DELTA,
	)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.SLIDE)
	assert_bool(_movement.is_low()).is_true()
	# One frame of slide friction already applied after the boost.
	var boosted := _tuning.slide_entry_speed + _tuning.slide_boost
	assert_float(_horizontal_speed(velocity)).is_equal_approx(boosted, 0.1)


func test_crouching_below_slide_entry_speed_gives_a_crouch() -> void:
	_run_past_the_boost_cooldown()
	_movement.step(
		_crouching(FORWARD),
		_on_floor(),
		FORWARD * (_tuning.slide_entry_speed - 0.1),
		DELTA,
	)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.CROUCH)


func test_a_slide_soon_after_the_last_one_began_gets_a_proportionally_smaller_boost() -> void:
	_run_past_the_boost_cooldown()
	var entry := FORWARD * _tuning.slide_entry_speed
	_movement.step(_crouching(FORWARD), _on_floor(), entry, DELTA)
	# Hop out of the Slide and land, half the cooldown after it began.
	var frames := roundi(_tuning.slide_boost_cooldown / 2.0 / DELTA)
	for frame: int in frames - 2:
		_movement.step(_moving(), _in_air(), entry, DELTA)
	_movement.step(_moving(FORWARD), _on_floor(), entry, DELTA)
	var velocity := _movement.step(_crouching(FORWARD), _on_floor(), entry, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.SLIDE)
	var half_boost := _tuning.slide_entry_speed + _tuning.slide_boost / 2.0
	# Below Run speed, so one frame of slow-slide friction already applied after the boost.
	var expected := half_boost - _tuning.slow_slide_friction * DELTA
	assert_float(_horizontal_speed(velocity)).is_equal_approx(expected, 0.05)


func test_the_slide_boost_never_takes_speed_past_run_speed_plus_the_boost() -> void:
	_run_past_the_boost_cooldown()
	var cap := _run_speed() + _tuning.slide_boost
	var velocity := _movement.step(
		_crouching(FORWARD),
		_on_floor(),
		FORWARD * (cap - _tuning.slide_boost / 2.0),
		DELTA,
	)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.SLIDE)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(cap, 0.1)


func test_the_slide_boost_never_slows_a_slide_entered_faster_than_its_cap() -> void:
	_run_past_the_boost_cooldown()
	var speed := _run_speed() + _tuning.slide_boost + OVERSPEED
	var velocity := _movement.step(_crouching(FORWARD), _on_floor(), FORWARD * speed, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.SLIDE)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(speed, 0.1)


## Starts a Slide at [param speed] with crouch held, the boost fully recharged.
func _start_slide(speed: float) -> Vector3:
	_run_past_the_boost_cooldown()
	var velocity := _movement.step(_crouching(FORWARD), _on_floor(), FORWARD * speed, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.SLIDE)
	return velocity


func test_a_flat_slide_above_run_speed_fades_at_slide_friction() -> void:
	var velocity := _start_slide(_run_speed() + _tuning.slide_boost + OVERSPEED)
	var start := _horizontal_speed(velocity)
	for frame: int in 60:
		velocity = _movement.step(_crouching(), _on_floor(), velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.SLIDE)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(start - _tuning.slide_friction, 0.01)


func test_a_flat_slide_below_run_speed_fades_at_slow_slide_friction_then_becomes_a_crouch() -> void:
	var velocity := _start_slide(_tuning.slide_entry_speed)
	var frames := 0
	while _horizontal_speed(velocity) >= _run_speed() and frames < 600:
		velocity = _movement.step(_crouching(), _on_floor(), velocity, DELTA)
		frames += 1
	var below_run := _horizontal_speed(velocity)
	for frame: int in 6:
		velocity = _movement.step(_crouching(), _on_floor(), velocity, DELTA)
	var expected := below_run - _tuning.slow_slide_friction * 6 * DELTA
	assert_float(_horizontal_speed(velocity)).is_equal_approx(expected, 0.01)
	while _movement.state() == RunnerMovement.State.SLIDE and frames < 600:
		assert_float(_horizontal_speed(velocity)).is_greater_equal(_tuning.slide_to_crouch_speed)
		velocity = _movement.step(_crouching(), _on_floor(), velocity, DELTA)
		frames += 1
	assert_int(_movement.state()).is_equal(RunnerMovement.State.CROUCH)
	assert_float(_horizontal_speed(velocity)).is_less(_tuning.slide_to_crouch_speed + 0.001)


## Slides fast for a second holding [param wish] and returns the final velocity.
func _slide_for_a_second(wish: Vector3) -> Vector3:
	var velocity := _start_slide(_run_speed() + _tuning.slide_boost + OVERSPEED)
	for frame: int in 60:
		velocity = _movement.step(_crouching(wish), _on_floor(), velocity, DELTA)
	return velocity


func test_sideways_input_turns_a_slide_by_at_most_the_turn_rate_without_changing_speed() -> void:
	var straight := _slide_for_a_second(Vector3.ZERO)
	_movement = RunnerMovement.new(_tuning, STANDING_HEIGHT)
	var velocity := _start_slide(_run_speed() + _tuning.slide_boost + OVERSPEED)
	var max_turn := _tuning.slide_turn_rate * DELTA
	for frame: int in 60:
		var before := Vector3(velocity.x, 0.0, velocity.z)
		velocity = _movement.step(_crouching(Vector3.RIGHT), _on_floor(), velocity, DELTA)
		var turn := before.angle_to(Vector3(velocity.x, 0.0, velocity.z))
		assert_float(turn).is_less_equal(max_turn + 0.0001)
		# Input straight across the heading turns it at the full turn rate.
		if frame == 0:
			assert_float(turn).is_equal_approx(max_turn, 0.0001)
	# Turned right, and by a good share of a second's turning.
	assert_float(velocity.x).is_greater(0.0)
	var angle := FORWARD.angle_to(Vector3(velocity.x, 0.0, velocity.z))
	assert_float(angle).is_greater(_tuning.slide_turn_rate * 0.8)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(_horizontal_speed(straight), 0.001)


func test_forward_and_back_input_do_nothing_to_a_slide() -> void:
	var straight := _slide_for_a_second(Vector3.ZERO)
	for wish: Vector3 in [FORWARD, Vector3.BACK]:
		_movement = RunnerMovement.new(_tuning, STANDING_HEIGHT)
		var velocity := _slide_for_a_second(wish)
		assert_vector(velocity).is_equal_approx(straight, Vector3.ONE * 0.001)


func test_a_released_slide_winds_down_low_then_becomes_a_run_at_run_speed() -> void:
	var velocity := _start_slide(_run_speed() + _tuning.slide_boost + OVERSPEED)
	var start := _horizontal_speed(velocity)
	for frame: int in 30:
		velocity = _movement.step(_moving(FORWARD), _on_floor(), velocity, DELTA)
		assert_int(_movement.state()).is_equal(RunnerMovement.State.SLIDE)
		assert_bool(_movement.is_slide_released()).is_true()
		assert_bool(_movement.is_low()).is_true()
	var expected := start - _tuning.released_slide_decel * 0.5
	assert_float(_horizontal_speed(velocity)).is_equal_approx(expected, 0.01)
	var frames := 0
	while _movement.state() == RunnerMovement.State.SLIDE and frames < 600:
		velocity = _movement.step(_moving(FORWARD), _on_floor(), velocity, DELTA)
		frames += 1
	assert_int(_movement.state()).is_equal(RunnerMovement.State.RUN)
	assert_bool(_movement.is_low()).is_false()
	var last_frame := _tuning.released_slide_decel * DELTA
	assert_float(_horizontal_speed(velocity)).is_between(_run_speed() - last_frame, _run_speed())


func test_pressing_crouch_again_in_a_released_slide_continues_it_with_no_boost() -> void:
	# Fast enough to stay above Run speed throughout.
	var velocity := _start_slide(_run_speed() + _tuning.slide_boost + OVERSPEED * 2.0)
	# Released for longer than the boost cooldown, so a new Slide would get the full boost.
	for frame: int in _frames_past(_tuning.slide_boost_cooldown):
		velocity = _movement.step(_moving(FORWARD), _on_floor(), velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.SLIDE)
	var released := _horizontal_speed(velocity)
	for frame: int in 60:
		velocity = _movement.step(_crouching(FORWARD), _on_floor(), velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.SLIDE)
	assert_bool(_movement.is_slide_released()).is_false()
	# Back to slide friction, with no boost on top.
	var expected := released - _tuning.slide_friction
	assert_float(_horizontal_speed(velocity)).is_equal_approx(expected, 0.01)


func test_a_released_slide_without_room_to_stand_stays_low_until_there_is_room() -> void:
	var velocity := _start_slide(_run_speed() + _tuning.slide_boost)
	for frame: int in 300:
		velocity = _movement.step(_moving(FORWARD), _under_ceiling(), velocity, DELTA)
		assert_bool(_movement.is_low()).is_true()
	assert_float(_horizontal_speed(velocity)).is_less(_run_speed())
	_movement.step(_moving(FORWARD), _on_floor(), velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.RUN)
	assert_bool(_movement.is_low()).is_false()


func test_jumping_from_a_slide_keeps_its_horizontal_speed() -> void:
	var velocity := _start_slide(_run_speed() + _tuning.slide_boost + OVERSPEED)
	var sliding := _horizontal_speed(velocity)
	var jump_crouched := RunnerMovement.Intent.new(FORWARD, true, true)
	velocity = _movement.step(jump_crouched, _on_floor(), velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.AIR)
	assert_float(velocity.y).is_equal_approx(_launch_speed(), 0.001)
	for frame: int in 30:
		velocity = _movement.step(_moving(FORWARD), _in_air(), velocity, DELTA)
	# At most the jump frame's slide friction lost.
	var tolerance := _tuning.slide_friction * DELTA + 0.001
	assert_float(_horizontal_speed(velocity)).is_equal_approx(sliding, tolerance)


func test_sliding_off_an_edge_keeps_horizontal_speed() -> void:
	var velocity := _start_slide(_run_speed() + _tuning.slide_boost + OVERSPEED)
	var sliding := _horizontal_speed(velocity)
	for frame: int in 30:
		velocity = _movement.step(_moving(FORWARD), _in_air(), velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.AIR)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(sliding, 0.001)


func test_starting_a_slide_from_a_crouch_takes_releasing_crouch_and_pressing_it_again() -> void:
	# Landing fast with no room to stand gives a Crouch above slide entry speed.
	var velocity := FORWARD * (_run_speed() + OVERSPEED)
	_movement.step(_moving(), _in_air(), velocity, DELTA)
	velocity = _movement.step(_moving(FORWARD), _under_ceiling(), velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.CROUCH)
	velocity = _movement.step(_crouching(FORWARD), _on_floor(), velocity, DELTA)
	assert_float(_horizontal_speed(velocity)).is_greater(_tuning.slide_entry_speed)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.CROUCH)
	velocity = _movement.step(_moving(FORWARD), _on_floor(), velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.RUN)
	velocity = _movement.step(_crouching(FORWARD), _on_floor(), velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.SLIDE)


## A floor sloping down toward -Z (the Slide's heading) by [param degrees]; negative slopes up.
func _downhill(degrees: float) -> Vector3:
	return Vector3.UP.rotated(Vector3.RIGHT, -deg_to_rad(degrees))


func test_default_slope_gain_is_1_point_3() -> void:
	assert_float(_tuning.slope_gain).is_equal_approx(1.3, 0.0001)


func test_a_held_slide_down_a_steep_slope_gains_speed() -> void:
	var velocity := _start_slide(_run_speed() + _tuning.slide_boost)
	var start := _horizontal_speed(velocity)
	for frame: int in 60:
		velocity = _movement.step(_crouching(), _on_floor(_downhill(30.0)), velocity, DELTA)
		assert_int(_movement.state()).is_equal(RunnerMovement.State.SLIDE)
	# Well past what slide friction alone would leave, and past where it started.
	assert_float(_horizontal_speed(velocity)).is_greater(start + 5.0)


func test_a_held_slide_down_a_slope_too_gentle_to_beat_slide_friction_loses_speed() -> void:
	var velocity := _start_slide(_run_speed() + _tuning.slide_boost + OVERSPEED)
	var start := _horizontal_speed(velocity)
	for frame: int in 60:
		velocity = _movement.step(_crouching(), _on_floor(_downhill(1.0)), velocity, DELTA)
	assert_float(_horizontal_speed(velocity)).is_less(start)
	# But less than on flat ground.
	assert_float(_horizontal_speed(velocity)).is_greater(start - _tuning.slide_friction)


func test_a_held_slide_up_a_slope_loses_speed_faster_than_on_flat_ground() -> void:
	var velocity := _start_slide(_run_speed() + _tuning.slide_boost + OVERSPEED)
	var start := _horizontal_speed(velocity)
	for frame: int in 30:
		velocity = _movement.step(_crouching(), _on_floor(_downhill(-15.0)), velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.SLIDE)
	# Half a second of slide friction would leave it 0.75 m/s slower; the slope takes far more.
	assert_float(_horizontal_speed(velocity)).is_less(start - _tuning.slide_friction * 0.5 - 1.0)


func test_a_held_slide_down_a_long_steep_slope_tops_out_at_the_top_slide_speed() -> void:
	var velocity := _start_slide(_run_speed() + _tuning.slide_boost)
	for frame: int in 600:
		velocity = _movement.step(_crouching(), _on_floor(_downhill(30.0)), velocity, DELTA)
		assert_float(_horizontal_speed(velocity)).is_less_equal(_tuning.top_slide_speed + 0.001)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(_tuning.top_slide_speed, 0.1)


func test_a_slide_entered_faster_than_the_top_slide_speed_keeps_its_speed_downhill() -> void:
	var velocity := _start_slide(_tuning.top_slide_speed + OVERSPEED)
	var start := _horizontal_speed(velocity)
	for frame: int in 60:
		velocity = _movement.step(_crouching(), _on_floor(_downhill(30.0)), velocity, DELTA)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(start, 0.01)


func test_a_released_slide_down_a_steep_slope_never_gains_speed() -> void:
	var velocity := _start_slide(_run_speed() + _tuning.slide_boost + OVERSPEED)
	for frame: int in 60:
		var before := _horizontal_speed(velocity)
		velocity = _movement.step(_moving(), _on_floor(_downhill(30.0)), velocity, DELTA)
		assert_bool(_movement.is_slide_released()).is_true()
		assert_float(_horizontal_speed(velocity)).is_less(before)


func test_running_down_a_steep_slope_keeps_run_speed_and_gains_nothing() -> void:
	var velocity := FORWARD * _run_speed()
	for frame: int in 120:
		velocity = _movement.step(_moving(FORWARD), _on_floor(_downhill(30.0)), velocity, DELTA)
		assert_int(_movement.state()).is_equal(RunnerMovement.State.RUN)
		assert_float(_horizontal_speed(velocity)).is_less_equal(_run_speed() + 0.001)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(_run_speed(), 0.001)


## Lands on flat ground at [param speed] with crouch held, after a moment in the air.
func _land_crouching(speed: float) -> Vector3:
	var velocity := FORWARD * speed + Vector3.DOWN * 5.0
	_movement.step(_moving(FORWARD), _in_air(), velocity, DELTA)
	return _movement.step(_crouching(FORWARD), _on_floor(), velocity, DELTA)


func test_landing_crouched_at_slide_entry_speed_or_faster_slides_losing_no_speed() -> void:
	for speed: float in [_tuning.slide_entry_speed, _run_speed() + _tuning.slide_boost + OVERSPEED]:
		_movement = RunnerMovement.new(_tuning, STANDING_HEIGHT)
		var velocity := _land_crouching(speed)
		assert_int(_movement.state()).is_equal(RunnerMovement.State.SLIDE)
		# At most one frame of slide friction (the faster of the two tiers) after landing.
		var floor_speed := speed - _tuning.slow_slide_friction * DELTA - 0.001
		assert_float(_horizontal_speed(velocity)).is_greater_equal(floor_speed)


func test_landing_crouched_below_slide_entry_speed_gives_a_crouch() -> void:
	_land_crouching(_tuning.slide_entry_speed - 0.1)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.CROUCH)


func test_a_landing_slide_soon_after_the_last_one_began_gets_a_smaller_boost() -> void:
	_start_slide(_tuning.slide_entry_speed)
	# Jump out of the Slide and land with crouch held, half the cooldown after it began.
	var entry := FORWARD * _tuning.slide_entry_speed
	var frames := roundi(_tuning.slide_boost_cooldown / 2.0 / DELTA)
	for frame: int in frames - 1:
		_movement.step(_moving(), _in_air(), entry, DELTA)
	var velocity := _movement.step(_crouching(FORWARD), _on_floor(), entry, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.SLIDE)
	var half_boost := _tuning.slide_entry_speed + _tuning.slide_boost / 2.0
	# Below Run speed, so one frame of slow-slide friction already applied after the boost.
	var expected := half_boost - _tuning.slow_slide_friction * DELTA
	assert_float(_horizontal_speed(velocity)).is_equal_approx(expected, 0.05)


func test_slide_hopping_on_flat_ground_never_exceeds_run_speed_plus_the_slide_boost() -> void:
	var velocity := _run_past_the_boost_cooldown()
	var height := 0.0
	var landings := 0
	var cap := _run_speed() + _tuning.slide_boost
	for frame: int in roundi(6.0 / DELTA):
		var on_floor := height <= 0.0
		# Jump pressed on every landing, crouch held throughout.
		var intent := RunnerMovement.Intent.new(FORWARD, on_floor, true)
		var contact := _on_floor() if on_floor else _in_air()
		velocity = _movement.step(intent, contact, velocity, DELTA)
		if on_floor:
			landings += 1
		height += velocity.y * DELTA
		assert_float(_horizontal_speed(velocity)).is_less_equal(cap + 0.001)
	# Several hops, each landing straight into a Slide.
	assert_int(landings).is_greater(3)
