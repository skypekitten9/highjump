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


func _ground_step(velocity: Vector3, wish: Vector3, normal := Vector3.UP) -> Vector3:
	return _movement.step(wish, velocity, true, normal, _tuning, DELTA)


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
		velocity = _movement.step(Vector3.ZERO, velocity, false, Vector3.UP, _tuning, DELTA)
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
