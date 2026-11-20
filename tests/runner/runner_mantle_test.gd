extends GdUnitTestSuite
## Mantles of the Runner, stepped frame by frame at 60 Hz with the default tuning. The ledge is
## straight ahead along -Z, its face toward the Runner. Expected values come from that tuning.

const DELTA := 1.0 / 60.0
const FORWARD := Vector3.FORWARD
## The ledge's face normal: it faces the Runner, which heads along -Z.
const FACE_NORMAL := Vector3.BACK
## Height of the Runner's standing body, m.
const STANDING_HEIGHT := 1.8
## A top comfortably within Mantle reach above the feet, m.
const TOP := 1.0

var _tuning: RunnerTuning
var _movement: RunnerMovement


func before_test() -> void:
	_tuning = load("res://runner/default_runner_tuning.tres")
	_movement = RunnerMovement.new(_tuning, STANDING_HEIGHT)


## The Player holding [param direction], or no move input.
func _moving(direction := Vector3.ZERO) -> RunnerMovement.Intent:
	return RunnerMovement.Intent.new(direction)


## In the air with a ledge ahead whose top is [param top] above the feet, with room to stand on
## it, or on the floor too if [param on_floor].
func _at_ledge(top := TOP, on_floor := false, normal := FACE_NORMAL) -> RunnerMovement.Contact:
	var ledge := RunnerMovement.LedgeContact.new(normal, top, INF)
	return RunnerMovement.Contact.new(on_floor, Vector3.UP, true, null, ledge)


## Touching nothing, room to stand overhead.
func _in_air() -> RunnerMovement.Contact:
	return RunnerMovement.Contact.new(false)


func _horizontal(velocity: Vector3) -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


## Horizontal velocity heading at the ledge at [param degrees] from straight into it, turned to
## the right.
func _toward_ledge(speed: float, degrees: float) -> Vector3:
	return FORWARD.rotated(Vector3.UP, -deg_to_rad(degrees)) * speed


## Flies at [param approach] for a frame, then meets the ledge's face holding straight into it,
## the way the Runner's body does: the engine's collision removes the speed going into the face
## before the next step. Returns the velocity of the frame the ledge is met.
func _meet_ledge(approach: Vector3) -> Vector3:
	var planned := _movement.step(_moving(), _in_air(), approach, DELTA)
	var after_collision := planned - FACE_NORMAL * minf(planned.dot(FACE_NORMAL), 0.0)
	return _movement.step(_moving(FORWARD), _at_ledge(), after_collision, DELTA)


func _is_mantling() -> bool:
	return _movement.state() == RunnerMovement.State.MANTLE


func test_holding_into_a_ledge_within_reach_in_the_air_starts_a_mantle() -> void:
	_movement.step(_moving(FORWARD), _at_ledge(), Vector3.ZERO, DELTA)
	assert_bool(_is_mantling()).is_true()


func test_no_mantle_starts_on_the_ground() -> void:
	_movement.step(_moving(FORWARD), _at_ledge(TOP, true), Vector3.ZERO, DELTA)
	assert_bool(_is_mantling()).is_false()


func test_no_mantle_starts_with_no_direction_held() -> void:
	_movement.step(_moving(), _at_ledge(), Vector3.ZERO, DELTA)
	assert_bool(_is_mantling()).is_false()


func test_holding_within_the_input_angle_of_straight_in_starts_a_mantle() -> void:
	var angle := deg_to_rad(_tuning.mantle_input_angle - 1.0)
	_movement.step(_moving(FORWARD.rotated(Vector3.UP, angle)), _at_ledge(), Vector3.ZERO, DELTA)
	assert_bool(_is_mantling()).is_true()


func test_holding_outside_the_input_angle_of_straight_in_starts_no_mantle() -> void:
	var angle := deg_to_rad(_tuning.mantle_input_angle + 1.0)
	_movement.step(_moving(FORWARD.rotated(Vector3.UP, angle)), _at_ledge(), Vector3.ZERO, DELTA)
	assert_bool(_is_mantling()).is_false()


func test_a_top_at_the_reach_starts_a_mantle() -> void:
	_movement.step(_moving(FORWARD), _at_ledge(_tuning.mantle_reach), Vector3.ZERO, DELTA)
	assert_bool(_is_mantling()).is_true()


func test_a_top_beyond_the_reach_starts_no_mantle() -> void:
	_movement.step(_moving(FORWARD), _at_ledge(_tuning.mantle_reach + 0.05), Vector3.ZERO, DELTA)
	assert_bool(_is_mantling()).is_false()


func test_a_top_below_the_feet_starts_no_mantle() -> void:
	_movement.step(_moving(FORWARD), _at_ledge(-0.1), Vector3.ZERO, DELTA)
	assert_bool(_is_mantling()).is_false()


func test_a_face_too_far_from_vertical_starts_no_mantle() -> void:
	var tilt := deg_to_rad(_tuning.wall_max_tilt + 5.0)
	var leaning := FACE_NORMAL.rotated(Vector3.RIGHT, tilt)
	_movement.step(_moving(FORWARD), _at_ledge(TOP, false, leaning), Vector3.ZERO, DELTA)
	assert_bool(_is_mantling()).is_false()


func test_a_top_without_room_to_stand_starts_no_mantle() -> void:
	var ledge := RunnerMovement.LedgeContact.new(FACE_NORMAL, TOP, STANDING_HEIGHT - 0.1)
	var contact := RunnerMovement.Contact.new(false, Vector3.UP, true, null, ledge)
	_movement.step(_moving(FORWARD), contact, Vector3.ZERO, DELTA)
	assert_bool(_is_mantling()).is_false()


func test_a_mantle_from_a_standstill_lifts_the_leap_just_enough_to_clear_the_top() -> void:
	# Peaking 1.25 m up (the top plus the clearance) under 40 m/s² takes 10 m/s.
	var velocity := _movement.step(_moving(FORWARD), _at_ledge(), Vector3.ZERO, DELTA)
	assert_float(velocity.y).is_equal_approx(10.0, 0.0001)


func test_a_mantle_falling_fast_still_lifts_the_leap_to_clear_the_top() -> void:
	var velocity := _movement.step(_moving(FORWARD), _at_ledge(), Vector3.DOWN * 8.0, DELTA)
	assert_float(velocity.y).is_equal_approx(10.0, 0.0001)


func test_a_mantle_never_lowers_upward_speed() -> void:
	var velocity := _movement.step(_moving(FORWARD), _at_ledge(), Vector3.UP * 12.0, DELTA)
	assert_float(velocity.y).is_equal_approx(12.0, 0.0001)


func test_the_leap_falls_under_leap_gravity() -> void:
	var velocity := _movement.step(_moving(FORWARD), _at_ledge(), Vector3.ZERO, DELTA)
	for frame: int in 10:
		velocity = _movement.step(_moving(FORWARD), _in_air(), velocity, DELTA)
	assert_bool(_is_mantling()).is_true()
	# Twice the 20 m/s² gravity, for 10 frames.
	assert_float(velocity.y).is_equal_approx(10.0 - 40.0 * 10.0 / 60.0, 0.0001)


func test_a_fast_head_on_mantle_keeps_all_its_speed_over_the_top() -> void:
	var velocity := _meet_ledge(_toward_ledge(12.0, 0.0))
	assert_bool(_is_mantling()).is_true()
	assert_vector(_horizontal(velocity)).is_equal_approx(FORWARD * 12.0, Vector3.ONE * 0.0001)


func test_a_mantle_at_an_angle_keeps_all_its_speed_and_heading() -> void:
	var approach := _toward_ledge(12.0, 45.0)
	var velocity := _meet_ledge(approach)
	assert_vector(_horizontal(velocity)).is_equal_approx(approach, Vector3.ONE * 0.0001)


func test_a_glancing_mantle_turns_over_the_top_at_least_at_the_inward_speed() -> void:
	# 12 m/s at 80 degrees from straight in: 11.82 m/s along the face and only 2.08 m/s into it.
	# The part into it is raised to the 3 m/s inward speed, then all 12 m/s points that way.
	var velocity := _meet_ledge(_toward_ledge(12.0, 80.0))
	assert_float(_horizontal(velocity).length()).is_equal_approx(12.0, 0.0001)
	assert_float(_horizontal(velocity).dot(FORWARD)).is_equal_approx(2.9526, 0.001)


func test_a_slow_mantle_comes_off_at_run_speed() -> void:
	var velocity := _meet_ledge(_toward_ledge(2.0, 0.0))
	assert_vector(_horizontal(velocity)).is_equal_approx(FORWARD * 9.0, Vector3.ONE * 0.0001)


func test_a_mantle_from_a_standstill_comes_off_at_run_speed_straight_in() -> void:
	var velocity := _movement.step(_moving(FORWARD), _at_ledge(), Vector3.ZERO, DELTA)
	assert_vector(_horizontal(velocity)).is_equal_approx(FORWARD * 9.0, Vector3.ONE * 0.0001)


func test_steering_changes_nothing_during_the_leap() -> void:
	var start := _meet_ledge(_toward_ledge(12.0, 0.0))
	var velocity := start
	for direction: Vector3 in [Vector3.BACK, Vector3.LEFT, Vector3.RIGHT, Vector3.ZERO]:
		for frame: int in 3:
			velocity = _movement.step(_moving(direction), _in_air(), velocity, DELTA)
			assert_bool(_is_mantling()).is_true()
			assert_vector(_horizontal(velocity)).is_equal_approx(
				_horizontal(start),
				Vector3.ONE * 0.0001,
			)


func test_touching_the_floor_ends_the_mantle_as_a_landing() -> void:
	var velocity := _meet_ledge(_toward_ledge(12.0, 0.0))
	for frame: int in 5:
		velocity = _movement.step(_moving(FORWARD), _in_air(), velocity, DELTA)
	velocity.y = 0.0
	var on_top := RunnerMovement.Contact.new(true)
	velocity = _movement.step(_moving(FORWARD), on_top, velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.RUN)
	assert_bool(_movement.is_on_ground()).is_true()
	assert_float(velocity.y).is_equal_approx(0.0, 0.0001)


func test_falling_back_below_the_top_ends_the_mantle_in_the_air_keeping_its_velocity() -> void:
	# The 10 m/s leap under 40 m/s² peaks after 0.25 s and falls back below the 1 m top after
	# about 0.36 s (22 frames).
	var start := _movement.step(_moving(FORWARD), _at_ledge(), Vector3.ZERO, DELTA)
	var velocity := start
	for frame: int in 18:
		velocity = _movement.step(_moving(), _in_air(), velocity, DELTA)
	assert_bool(_is_mantling()).is_true()
	for frame: int in 8:
		velocity = _movement.step(_moving(), _in_air(), velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.AIR)
	assert_vector(_horizontal(velocity)).is_equal_approx(_horizontal(start), Vector3.ONE * 0.0001)


func test_a_mantle_that_never_lands_or_falls_back_ends_in_the_air() -> void:
	# Held up against something, the leap never rises or falls.
	var start := _movement.step(_moving(FORWARD), _at_ledge(), Vector3.ZERO, DELTA)
	var stuck := _horizontal(start)
	for frame: int in roundi(RunnerMovement.MANTLE_TIME_LIMIT / DELTA) - 2:
		_movement.step(_moving(), _in_air(), stuck, DELTA)
	assert_bool(_is_mantling()).is_true()
	for frame: int in 4:
		_movement.step(_moving(), _in_air(), stuck, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.AIR)


func test_a_top_with_room_to_stand_starts_a_mantle() -> void:
	var ledge := RunnerMovement.LedgeContact.new(FACE_NORMAL, TOP, STANDING_HEIGHT)
	var contact := RunnerMovement.Contact.new(false, Vector3.UP, true, null, ledge)
	_movement.step(_moving(FORWARD), contact, Vector3.ZERO, DELTA)
	assert_bool(_is_mantling()).is_true()
