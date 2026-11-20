extends GdUnitTestSuite
## Ground and air movement of the Runner, stepped frame by frame at 60 Hz with the default tuning.

const DELTA := 1.0 / 60.0
const RUN_SPEED := 7.0
const FORWARD := Vector3.FORWARD

var _tuning: RunnerTuning
var _movement: RunnerMovement


func before_test() -> void:
	_tuning = load("res://runner/default_runner_tuning.tres")
	_movement = RunnerMovement.new()


func _ground_step(velocity: Vector3, wish: Vector3, normal := Vector3.UP, jump := false) -> Vector3:
	return _movement.step(wish, jump, velocity, true, normal, _tuning, DELTA)


func _air_step(velocity: Vector3, wish := Vector3.ZERO, jump := false) -> Vector3:
	return _movement.step(wish, jump, velocity, false, Vector3.UP, _tuning, DELTA)


func _horizontal_speed(velocity: Vector3) -> float:
	return Vector2(velocity.x, velocity.z).length()


func test_holding_forward_from_rest_reaches_run_speed_quickly_and_never_exceeds_it() -> void:
	var velocity := Vector3.ZERO
	var frames_to_run_speed := -1
	for frame: int in 60:
		velocity = _ground_step(velocity, FORWARD)
		var speed := _horizontal_speed(velocity)
		assert_float(speed).is_less_equal(RUN_SPEED + 0.001)
		if frames_to_run_speed < 0 and is_equal_approx(speed, RUN_SPEED):
			frames_to_run_speed = frame + 1
	assert_int(frames_to_run_speed).is_between(1, 6)


func test_releasing_input_at_run_speed_stops_quickly() -> void:
	var velocity := FORWARD * RUN_SPEED
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
		assert_float(_horizontal_speed(velocity)).is_less_equal(RUN_SPEED + 0.001)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(RUN_SPEED, 0.001)


func test_ground_velocity_lies_in_a_45_degree_floor_plane() -> void:
	var normal := Vector3(0.0, 1.0, 1.0).normalized()
	for wish: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT]:
		var velocity := Vector3.ZERO
		for frame: int in 30:
			velocity = _ground_step(velocity, wish, normal)
			assert_float(velocity.dot(normal)).is_equal_approx(0.0, 0.001)
		assert_float(_horizontal_speed(velocity)).is_equal_approx(RUN_SPEED, 0.001)


func test_in_the_air_gravity_pulls_down_and_horizontal_velocity_is_kept() -> void:
	var velocity := Vector3(3.0, 0.0, -4.0)
	for frame: int in 30:
		velocity = _air_step(velocity)
	# 0.5 s at 20 m/s^2.
	assert_float(velocity.y).is_equal_approx(-10.0, 0.001)
	assert_vector(Vector3(velocity.x, 0.0, velocity.z)).is_equal_approx(
		Vector3(3.0, 0.0, -4.0),
		Vector3.ONE * 0.001,
	)


func test_a_floor_contact_while_moving_away_from_the_floor_does_not_ground_the_runner() -> void:
	var velocity := Vector3(0.0, 5.0, -RUN_SPEED)
	velocity = _ground_step(velocity, FORWARD)
	# Not snapped onto the floor plane: gravity applied to the upward speed instead.
	assert_float(velocity.y).is_equal_approx(5.0 - 20.0 * DELTA, 0.001)


func test_in_the_air_below_run_speed_steering_speeds_up_to_run_speed_and_no_further() -> void:
	var velocity := Vector3.ZERO
	for frame: int in 60:
		velocity = _air_step(velocity, FORWARD)
		assert_float(_horizontal_speed(velocity)).is_less_equal(RUN_SPEED + 0.001)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(RUN_SPEED, 0.001)


func test_in_the_air_at_12_steering_sideways_keeps_speed_and_turns() -> void:
	var velocity := FORWARD * 12.0
	for frame: int in 60:
		velocity = _air_step(velocity, Vector3.RIGHT)
		assert_float(_horizontal_speed(velocity)).is_less_equal(12.0 + 0.001)
	assert_float(_horizontal_speed(velocity)).is_equal_approx(12.0, 0.01)
	# Heading has swung well toward the right.
	assert_float(velocity.x).is_greater(6.0)


func test_landing_at_12_with_forward_held_fades_to_run_speed() -> void:
	var velocity := FORWARD * 12.0
	for frame: int in 12:
		velocity = _ground_step(velocity, FORWARD)
	assert_float(_horizontal_speed(velocity)).is_greater(RUN_SPEED + 1.0)
	for frame: int in 18:
		velocity = _ground_step(velocity, FORWARD)
	# 5 m/s of excess at 10 m/s^2 fades in about 0.5 s.
	assert_float(_horizontal_speed(velocity)).is_equal_approx(RUN_SPEED, 0.2)


func test_holding_back_on_the_ground_brakes_faster_than_overspeed_decay() -> void:
	var velocity := FORWARD * 12.0
	for frame: int in 6:
		velocity = _ground_step(velocity, Vector3.BACK)
	# Overspeed decay alone would only take 1 m/s off in 0.1 s.
	assert_float(_horizontal_speed(velocity)).is_less(12.0 - 1.0 - 3.0)


func test_jump_launches_at_the_speed_for_the_jump_height_and_peaks_near_it() -> void:
	# sqrt(2 * 20 * 1.2)
	var launch_speed := 6.9282
	var velocity := _ground_step(Vector3.ZERO, Vector3.ZERO, Vector3.UP, true)
	assert_float(velocity.y).is_equal_approx(launch_speed, 0.001)
	var height := 0.0
	var peak := 0.0
	for frame: int in 120:
		# The body moves with this frame's velocity before the next step applies gravity.
		height += velocity.y * DELTA
		peak = maxf(peak, height)
		velocity = _air_step(velocity)
	assert_float(peak).is_between(1.2, 1.3)


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


func test_a_jump_pressed_0_08_s_before_landing_fires_on_landing() -> void:
	assert_float(_land_after_early_press(5).y).is_greater(6.0)


func test_a_jump_pressed_0_15_s_before_landing_does_not_fire() -> void:
	assert_float(_land_after_early_press(9).y).is_equal_approx(0.0, 0.001)


func test_a_jump_pressed_0_08_s_after_leaving_the_floor_fires() -> void:
	assert_float(_press_after_leaving_floor(5).y).is_greater(6.0)


func test_a_jump_pressed_0_15_s_after_leaving_the_floor_does_not_fire() -> void:
	assert_float(_press_after_leaving_floor(9).y).is_less(0.0)


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
