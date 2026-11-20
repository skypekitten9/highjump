extends GdUnitTestSuite
## Ground and air movement of the Runner, stepped frame by frame at 60 Hz with the default tuning.
## Expected values come from that tuning, so retuning the preset doesn't break these tests.

const DELTA := 1.0 / 60.0
const FORWARD := Vector3.FORWARD
## How far above Run speed the "faster than Run speed" cases start, m/s.
const OVERSPEED := 5.0

var _tuning: RunnerTuning
var _movement: RunnerMovement


func before_test() -> void:
	_tuning = load("res://runner/default_runner_tuning.tres")
	_movement = RunnerMovement.new()


func _ground_step(velocity: Vector3, wish: Vector3, normal := Vector3.UP, jump := false) -> Vector3:
	return _movement.step(wish, jump, false, true, velocity, true, normal, _tuning, DELTA)


func _air_step(velocity: Vector3, wish := Vector3.ZERO, jump := false) -> Vector3:
	return _movement.step(wish, jump, false, true, velocity, false, Vector3.UP, _tuning, DELTA)


## A step on flat ground with crouch held or not, and room to stand above the Runner or not.
func _crouch_step(
	velocity: Vector3,
	wish: Vector3,
	crouch_held: bool,
	can_stand := true,
) -> Vector3:
	return _movement.step(
		wish,
		false,
		crouch_held,
		can_stand,
		velocity,
		true,
		Vector3.UP,
		_tuning,
		DELTA,
	)


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
		velocity = _ground_step(velocity, FORWARD)
		var speed := _horizontal_speed(velocity)
		assert_float(speed).is_less_equal(_run_speed() + 0.001)
		if frames_to_run_speed < 0 and is_equal_approx(speed, _run_speed()):
			frames_to_run_speed = frame + 1
	assert_int(frames_to_run_speed).is_between(1, 6)


func test_releasing_input_at_run_speed_stops_quickly() -> void:
	var velocity := FORWARD * _run_speed()
	var frames_to_stop := -1
	for frame: int in 60:
		velocity = _ground_step(velocity, Vector3.ZERO)
		if frames_to_stop < 0 and velocity.is_zero_approx():
			frames_to_stop = frame + 1
	assert_int(frames_to_stop).is_between(1, 6)


func test_diagonal_input_is_capped_at_run_speed() -> void:
	var diagonal := Vector2(1.0, -1.0).limit_length(1.0)
	var wish := Vector3(diagonal.x, 0.0, diagonal.y)
	var velocity := Vector3.ZERO
	for frame: int in 60:
		velocity = _ground_step(velocity, wish)
		assert_float(_horizontal_speed(velocity)).is_less_equal(_run_speed() + 0.001)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(_run_speed(), 0.001)


func test_ground_velocity_lies_in_a_45_degree_floor_plane() -> void:
	var normal := Vector3(0.0, 1.0, 1.0).normalized()
	for wish: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT]:
		var velocity := Vector3.ZERO
		for frame: int in 30:
			velocity = _ground_step(velocity, wish, normal)
			assert_float(velocity.dot(normal)).is_equal_approx(0.0, 0.001)
		assert_float(_horizontal_speed(velocity)).is_equal_approx(_run_speed(), 0.001)


func test_in_the_air_gravity_pulls_down_and_horizontal_velocity_is_kept() -> void:
	var velocity := Vector3(3.0, 0.0, -4.0)
	for frame: int in 30:
		velocity = _air_step(velocity)
	# 0.5 s of gravity.
	assert_float(velocity.y).is_equal_approx(-_tuning.gravity * 0.5, 0.001)
	assert_vector(Vector3(velocity.x, 0.0, velocity.z)).is_equal_approx(
		Vector3(3.0, 0.0, -4.0),
		Vector3.ONE * 0.001,
	)


func test_a_floor_contact_while_moving_away_from_the_floor_does_not_ground_the_runner() -> void:
	var velocity := Vector3(0.0, 5.0, -_run_speed())
	velocity = _ground_step(velocity, FORWARD)
	# Not snapped onto the floor plane: gravity applied to the upward speed instead.
	assert_float(velocity.y).is_equal_approx(5.0 - _tuning.gravity * DELTA, 0.001)


func test_running_down_a_45_degree_ramp_stays_on_the_ground() -> void:
	# The ramp descends toward +Z, so running back is running downhill.
	var ramp := Vector3(0.0, 1.0, 1.0).normalized()
	var velocity := Vector3.BACK * _run_speed()
	for frame: int in 30:
		# The engine's movement step zeroes vertical velocity going down a slope.
		velocity.y = 0.0
		velocity = _ground_step(velocity, Vector3.BACK, ramp)
		# Grounded: velocity follows the ramp down instead of falling under gravity.
		assert_float(velocity.dot(ramp)).is_equal_approx(0.0, 0.001)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(_run_speed(), 0.001)


func test_a_jump_off_a_downhill_ramp_is_not_grounded_on_the_next_floor_contact() -> void:
	var ramp := Vector3(0.0, 1.0, 1.0).normalized()
	var velocity := _ground_step(Vector3.BACK * _run_speed(), Vector3.BACK, ramp, true)
	var take_off := velocity.y
	assert_float(take_off).is_greater(0.0)
	velocity = _ground_step(velocity, Vector3.BACK, ramp)
	# Not snapped onto the ramp: gravity applied to the take-off speed instead.
	assert_float(velocity.y).is_equal_approx(take_off - _tuning.gravity * DELTA, 0.001)


func test_running_up_a_45_degree_ramp_onto_flat_ground_stays_on_the_ground() -> void:
	var ramp := Vector3(0.0, 1.0, 1.0).normalized()
	var velocity := Vector3.ZERO
	for frame: int in 30:
		velocity = _ground_step(velocity, FORWARD, ramp)
	assert_float(velocity.y).is_greater(_run_speed() - 0.001)
	# Over the crest: the floor turns flat while the velocity still climbs at 45 degrees.
	velocity = _ground_step(velocity, FORWARD, Vector3.UP)
	assert_float(velocity.y).is_equal_approx(0.0, 0.001)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(_run_speed(), 0.001)


func test_in_the_air_below_run_speed_steering_speeds_up_to_run_speed_and_no_further() -> void:
	var velocity := Vector3.ZERO
	for frame: int in 60:
		velocity = _air_step(velocity, FORWARD)
		assert_float(_horizontal_speed(velocity)).is_less_equal(_run_speed() + 0.001)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(_run_speed(), 0.001)


func test_in_the_air_above_run_speed_steering_sideways_keeps_speed_and_turns() -> void:
	var speed := _run_speed() + OVERSPEED
	var velocity := FORWARD * speed
	for frame: int in 60:
		velocity = _air_step(velocity, Vector3.RIGHT)
		assert_float(_horizontal_speed(velocity)).is_less_equal(speed + 0.001)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(speed, 0.01)
	# Heading has swung well toward the right.
	assert_float(velocity.x).is_greater(speed * 0.5)


func test_landing_above_run_speed_with_forward_held_fades_to_run_speed() -> void:
	var velocity := FORWARD * (_run_speed() + OVERSPEED)
	var fade_frames := ceili(OVERSPEED / _tuning.overspeed_decay / DELTA)
	var half := floori(fade_frames / 2.0)
	for frame: int in half:
		velocity = _ground_step(velocity, FORWARD)
	# Halfway through the fade, about half the excess is left.
	assert_float(_horizontal_speed(velocity)).is_greater(_run_speed() + OVERSPEED * 0.25)
	for frame: int in fade_frames - half:
		velocity = _ground_step(velocity, FORWARD)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(_run_speed(), 0.2)


func test_holding_back_on_the_ground_brakes_faster_than_overspeed_decay() -> void:
	var speed := _run_speed() + OVERSPEED
	var velocity := FORWARD * speed
	for frame: int in 6:
		velocity = _ground_step(velocity, Vector3.BACK)
	var decay_alone := _tuning.overspeed_decay * 6 * DELTA
	assert_float(_horizontal_speed(velocity)).is_less(speed - decay_alone - 3.0)


func test_jump_launches_at_the_speed_for_the_jump_height_and_peaks_near_it() -> void:
	var velocity := _ground_step(Vector3.ZERO, Vector3.ZERO, Vector3.UP, true)
	assert_float(velocity.y).is_equal_approx(_launch_speed(), 0.001)
	var height := 0.0
	var peak := 0.0
	for frame: int in 120:
		# The body moves with this frame's velocity before the next step applies gravity.
		height += velocity.y * DELTA
		peak = maxf(peak, height)
		velocity = _air_step(velocity)
	assert_float(peak).is_between(_tuning.jump_height, _tuning.jump_height + 0.1)


## Falls, pressing jump [param frames_before] frames before the landing frame, then lands.
## Returns the velocity on the landing frame.
func _land_after_early_press(frames_before: int) -> Vector3:
	var falling := Vector3(0.0, -5.0, 0.0)
	_air_step(falling, Vector3.ZERO, true)
	for frame: int in frames_before - 1:
		_air_step(falling)
	return _ground_step(falling, Vector3.ZERO)


## Stands, walks off the floor, and presses jump on the [param frames_after]th airborne frame.
## Returns the velocity on that frame.
func _press_after_leaving_floor(frames_after: int) -> Vector3:
	for frame: int in 10:
		_ground_step(Vector3.ZERO, FORWARD)
	var falling := Vector3(0.0, -1.0, 0.0)
	for frame: int in frames_after - 1:
		_air_step(falling)
	return _air_step(falling, Vector3.ZERO, true)


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
	var velocity := _ground_step(Vector3.ZERO, Vector3.ZERO, Vector3.UP, true)
	var height := 0.0
	var launches := 1
	# Jump held for the rest of the run: only the first frame counts as a press.
	for frame: int in 180:
		height += velocity.y * DELTA
		var was_rising := velocity.y > 1.0
		if height <= 0.0:
			height = 0.0
			velocity = _ground_step(velocity, Vector3.ZERO)
		else:
			velocity = _air_step(velocity)
		if velocity.y > 1.0 and not was_rising:
			launches += 1
	assert_int(launches).is_equal(1)


func test_after_the_jump_timers_are_cleared_a_buffered_press_does_not_fire() -> void:
	var falling := Vector3(0.0, -5.0, 0.0)
	_air_step(falling, Vector3.ZERO, true)
	_movement.clear_jump_timers()
	assert_float(_ground_step(falling, Vector3.ZERO).y).is_equal_approx(0.0, 0.001)


func test_after_the_jump_timers_are_cleared_coyote_time_is_gone() -> void:
	for frame: int in 10:
		_ground_step(Vector3.ZERO, FORWARD)
	_movement.clear_jump_timers()
	assert_float(_air_step(Vector3(0.0, -1.0, 0.0), Vector3.ZERO, true).y).is_less(0.0)


func test_crouching_from_rest_moves_low_and_at_most_at_crouch_speed() -> void:
	var velocity := Vector3.ZERO
	for frame: int in 60:
		velocity = _crouch_step(velocity, FORWARD, true)
		assert_float(_horizontal_speed(velocity)).is_less_equal(_tuning.crouch_speed + 0.001)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(_tuning.crouch_speed, 0.001)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.CROUCH)
	assert_bool(_movement.is_low()).is_true()


func test_releasing_crouch_with_room_to_stand_returns_to_run() -> void:
	var velocity := Vector3.ZERO
	for frame: int in 30:
		velocity = _crouch_step(velocity, FORWARD, true)
	velocity = _crouch_step(velocity, FORWARD, false)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.RUN)
	assert_bool(_movement.is_low()).is_false()
	for frame: int in 30:
		velocity = _crouch_step(velocity, FORWARD, false)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(_run_speed(), 0.001)


func test_releasing_crouch_without_room_to_stand_stays_a_crouch_until_there_is_room() -> void:
	var velocity := Vector3.ZERO
	for frame: int in 30:
		velocity = _crouch_step(velocity, FORWARD, true)
	for frame: int in 60:
		velocity = _crouch_step(velocity, FORWARD, false, false)
		assert_int(_movement.state()).is_equal(RunnerMovement.State.CROUCH)
		assert_bool(_movement.is_low()).is_true()
		assert_float(_horizontal_speed(velocity)).is_less_equal(_tuning.crouch_speed + 0.001)
	_crouch_step(velocity, FORWARD, false)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.RUN)


func test_landing_without_room_to_stand_is_a_crouch() -> void:
	var falling := Vector3(0.0, -5.0, 0.0)
	_air_step(falling)
	assert_bool(_movement.is_low()).is_false()
	_crouch_step(falling, FORWARD, false, false)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.CROUCH)


func test_default_run_speed_is_9_metres_per_second() -> void:
	assert_float(_run_speed()).is_equal(9.0)


## Runs on flat ground at Run speed long enough that no Slide began recently.
func _run_past_the_boost_cooldown() -> Vector3:
	var velocity := FORWARD * _run_speed()
	for frame: int in _frames_past(_tuning.slide_boost_cooldown):
		velocity = _crouch_step(velocity, FORWARD, false)
	return velocity


func test_crouching_at_slide_entry_speed_starts_a_slide_with_the_full_boost() -> void:
	_run_past_the_boost_cooldown()
	var velocity := _crouch_step(FORWARD * _tuning.slide_entry_speed, FORWARD, true)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.SLIDE)
	assert_bool(_movement.is_low()).is_true()
	# One frame of slide friction already applied after the boost.
	var boosted := _tuning.slide_entry_speed + _tuning.slide_boost
	assert_float(_horizontal_speed(velocity)).is_equal_approx(boosted, 0.1)
