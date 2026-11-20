extends GdUnitTestSuite
## Wall-runs of the Runner, stepped frame by frame at 60 Hz with the default tuning. The wall is
## straight, on the Runner's right, and runs along -Z. Expected values come from that tuning.

const DELTA := 1.0 / 60.0
const FORWARD := Vector3.FORWARD
## The wall's normal: it faces the Runner, which has the wall on its right.
const WALL_NORMAL := Vector3.LEFT
const WALL_ID := 1234
## A speed comfortably above the Wall-run entry speed, m/s.
const FAST := 10.0
## A glancing approach, degrees from parallel to the wall.
const GLANCING := 20.0

var _tuning: RunnerTuning
var _movement: RunnerMovement


func before_test() -> void:
	_tuning = load("res://runner/default_runner_tuning.tres")
	_movement = RunnerMovement.new(_tuning)


## The Player holding [param direction], or no move input.
func _moving(direction := Vector3.ZERO) -> RunnerMovement.Intent:
	return RunnerMovement.Intent.new(direction)


## The Player holding crouch and [param direction].
func _crouching(direction := Vector3.ZERO) -> RunnerMovement.Intent:
	return RunnerMovement.Intent.new(direction, false, true)


## Touching nothing, room to stand overhead.
func _in_air() -> RunnerMovement.Contact:
	return RunnerMovement.Contact.new(false)


## Touching the wall in the air, or on the floor too if [param on_floor].
func _on_wall(on_floor := false) -> RunnerMovement.Contact:
	return RunnerMovement.Contact.new(on_floor, Vector3.UP, true, true, WALL_NORMAL, WALL_ID)


## Standing on flat floor, room to stand overhead.
func _on_floor() -> RunnerMovement.Contact:
	return RunnerMovement.Contact.new(true)


## Horizontal velocity heading toward the wall at [param degrees] from parallel to it.
func _toward_wall(speed: float, degrees: float) -> Vector3:
	var angle := deg_to_rad(degrees)
	return Vector3(sin(angle), 0.0, -cos(angle)) * speed


func _horizontal(velocity: Vector3) -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


## Flies at [param approach] for a frame, then meets the wall with [param intent] held, the way
## the Runner's body does: the engine's collision removes the speed going into the wall before
## the next step. Returns the velocity of the frame the wall is met.
func _meet_wall(approach: Vector3, intent := _moving(FORWARD), contact := _on_wall()) -> Vector3:
	var planned := _movement.step(_moving(), _in_air(), approach, DELTA)
	var after_collision := planned - WALL_NORMAL * minf(planned.dot(WALL_NORMAL), 0.0)
	return _movement.step(intent, contact, after_collision, DELTA)


func _is_wall_running() -> bool:
	return _movement.state() == RunnerMovement.State.WALL_RUN


func test_meeting_a_wall_fast_glancing_and_holding_along_it_starts_a_wall_run() -> void:
	_meet_wall(_toward_wall(_tuning.wall_run_entry_speed, GLANCING))
	assert_bool(_is_wall_running()).is_true()


func test_meeting_a_wall_below_the_entry_speed_starts_no_wall_run() -> void:
	_meet_wall(_toward_wall(_tuning.wall_run_entry_speed - 0.1, GLANCING))
	assert_bool(_is_wall_running()).is_false()


func test_entry_speed_counts_the_speed_going_into_the_wall() -> void:
	# Only the part along the wall is below the entry speed; all of it is above.
	var steepest := _tuning.wall_run_max_entry_angle - 1.0
	var approach := _toward_wall(_tuning.wall_run_entry_speed + 0.1, steepest)
	assert_float(approach.dot(FORWARD)).is_less(_tuning.wall_run_entry_speed)
	_meet_wall(approach)
	assert_bool(_is_wall_running()).is_true()


func test_meeting_a_wall_more_head_on_than_the_maximum_entry_angle_starts_no_wall_run() -> void:
	_meet_wall(_toward_wall(FAST, _tuning.wall_run_max_entry_angle + 5.0))
	assert_bool(_is_wall_running()).is_false()


func test_meeting_a_wall_with_no_direction_held_starts_no_wall_run() -> void:
	_meet_wall(_toward_wall(FAST, GLANCING), _moving())
	assert_bool(_is_wall_running()).is_false()


func test_meeting_a_wall_holding_away_from_it_starts_no_wall_run() -> void:
	_meet_wall(_toward_wall(FAST, GLANCING), _moving(WALL_NORMAL))
	assert_bool(_is_wall_running()).is_false()


func test_meeting_a_wall_holding_into_it_starts_a_wall_run() -> void:
	_meet_wall(_toward_wall(FAST, GLANCING), _moving(-WALL_NORMAL))
	assert_bool(_is_wall_running()).is_true()


func test_meeting_a_wall_on_the_floor_starts_no_wall_run() -> void:
	_meet_wall(_toward_wall(FAST, GLANCING), _moving(FORWARD), _on_wall(true))
	assert_bool(_is_wall_running()).is_false()


func test_a_surface_too_far_from_vertical_is_not_a_wall() -> void:
	var tilt := deg_to_rad(_tuning.wall_max_tilt + 5.0)
	var leaning := WALL_NORMAL.rotated(Vector3.FORWARD, tilt)
	var contact := RunnerMovement.Contact.new(false, Vector3.UP, true, true, leaning, WALL_ID)
	_meet_wall(_toward_wall(FAST, GLANCING), _moving(FORWARD), contact)
	assert_bool(_is_wall_running()).is_false()


func test_entry_at_an_angle_keeps_all_horizontal_speed_now_along_the_wall() -> void:
	var velocity := _meet_wall(_toward_wall(FAST, 45.0))
	var horizontal := _horizontal(velocity)
	assert_float(horizontal.length()).is_equal_approx(FAST, 0.001)
	assert_float(horizontal.normalized().dot(FORWARD)).is_equal_approx(1.0, 0.0001)


func test_falling_speed_is_capped_on_entry() -> void:
	var falling := _toward_wall(FAST, GLANCING) + Vector3.DOWN * 8.0
	var velocity := _meet_wall(falling)
	assert_float(velocity.y).is_equal_approx(-_tuning.wall_run_max_entry_fall, 0.0001)


func test_upward_speed_is_kept_on_entry() -> void:
	var rising := _toward_wall(FAST, GLANCING) + Vector3.UP * 5.0
	var velocity := _meet_wall(rising)
	# Only the frame in the air before meeting the wall took full gravity off it.
	assert_float(velocity.y).is_equal_approx(5.0 - _tuning.gravity * DELTA, 0.0001)


func test_a_wall_run_arcs_under_reduced_gravity_and_slows_only_by_the_slowdown() -> void:
	var rising := _toward_wall(FAST, GLANCING) + Vector3.UP * 5.0
	var entry := _meet_wall(rising)
	var velocity := entry
	var frames := 60
	for frame: int in frames:
		velocity = _movement.step(_moving(FORWARD), _on_wall(), velocity, DELTA)
	assert_bool(_is_wall_running()).is_true()
	var seconds := frames * DELTA
	var gravity := _tuning.gravity * _tuning.wall_run_gravity_scale
	assert_float(velocity.y).is_equal_approx(entry.y - gravity * seconds, 0.001)
	var speed := FAST - _tuning.wall_run_slowdown * seconds
	assert_float(_horizontal(velocity).length()).is_equal_approx(speed, 0.001)
	assert_float(_horizontal(velocity).normalized().dot(FORWARD)).is_equal_approx(1.0, 0.0001)


func test_steering_and_crouch_change_nothing_during_a_wall_run() -> void:
	# Two Runners meet the wall the same way; one is then steered every way and crouched.
	var held := _movement
	var held_velocity := _meet_wall(_toward_wall(FAST, GLANCING))
	var steered := RunnerMovement.new(_tuning)
	_movement = steered
	var steered_velocity := _meet_wall(_toward_wall(FAST, GLANCING))
	for direction: Vector3 in [Vector3.BACK, WALL_NORMAL, Vector3.RIGHT, Vector3.ZERO]:
		for frame: int in 10:
			held_velocity = held.step(_moving(FORWARD), _on_wall(), held_velocity, DELTA)
			steered_velocity = steered.step(
				_crouching(direction),
				_on_wall(),
				steered_velocity,
				DELTA,
			)
			assert_bool(steered_velocity.is_equal_approx(held_velocity)).is_true()
	assert_int(steered.state()).is_equal(RunnerMovement.State.WALL_RUN)
	assert_bool(steered.is_low()).is_false()


func test_a_wall_run_ends_on_the_floor() -> void:
	var velocity := _meet_wall(_toward_wall(_tuning.run_speed, GLANCING))
	velocity = _movement.step(_moving(FORWARD), _on_wall(), velocity, DELTA)
	var on_wall := _horizontal(velocity)
	velocity = _movement.step(_moving(FORWARD), _on_wall(true), velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.RUN)
	# Still running on along the wall, at least as fast.
	assert_float(_horizontal(velocity).normalized().dot(FORWARD)).is_equal_approx(1.0, 0.0001)
	assert_float(_horizontal(velocity).length()).is_greater_equal(on_wall.length())


func test_landing_from_a_wall_run_with_crouch_held_slide_hops() -> void:
	var velocity := _meet_wall(_toward_wall(FAST, GLANCING))
	_movement.step(_crouching(FORWARD), _on_floor(), velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.SLIDE)


func test_a_wall_run_ends_below_the_end_speed_keeping_its_velocity() -> void:
	var speed := _tuning.wall_run_entry_speed
	var velocity := _meet_wall(_toward_wall(speed, GLANCING))
	var expected_frames := (speed - _tuning.wall_run_end_speed) / _tuning.wall_run_slowdown / DELTA
	var frames := 0
	var on_wall := velocity
	while _is_wall_running() and frames < 1000:
		on_wall = velocity
		velocity = _movement.step(_moving(), _on_wall(), velocity, DELTA)
		frames += 1
	assert_float(float(frames)).is_equal_approx(expected_frames, 2.0)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.AIR)
	assert_bool(_horizontal(velocity).is_equal_approx(_horizontal(on_wall))).is_true()
	assert_float(velocity.y).is_equal_approx(on_wall.y - _tuning.gravity * DELTA, 0.0001)


func test_a_wall_run_ends_when_the_wall_runs_out_keeping_its_velocity() -> void:
	var on_wall := _meet_wall(_toward_wall(FAST, GLANCING))
	var velocity := _movement.step(_moving(), _in_air(), on_wall, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.AIR)
	assert_bool(_horizontal(velocity).is_equal_approx(_horizontal(on_wall))).is_true()
	assert_float(velocity.y).is_equal_approx(on_wall.y - _tuning.gravity * DELTA, 0.0001)


func test_a_wall_run_is_not_on_the_ground() -> void:
	_meet_wall(_toward_wall(FAST, GLANCING))
	assert_bool(_movement.is_on_ground()).is_false()


func test_the_slide_boost_cooldown_keeps_counting_during_a_wall_run() -> void:
	# A Slide uses up the boost, then the Runner hops straight onto a wall.
	var slide := _movement.step(_crouching(FORWARD), _on_floor(), FORWARD * FAST, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.SLIDE)
	var velocity := _meet_wall(_toward_wall(_horizontal(slide).length(), GLANCING))
	var frames := roundi(_tuning.slide_boost_cooldown / DELTA) + 3
	for frame: int in frames:
		velocity = _movement.step(_moving(FORWARD), _on_wall(), velocity, DELTA)
	assert_bool(_is_wall_running()).is_true()
	# Landing crouched after the cooldown has passed gets the full boost again.
	var landing := _horizontal(velocity).length()
	velocity = _movement.step(_crouching(FORWARD), _on_floor(), velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.SLIDE)
	var cap := _tuning.run_speed + _tuning.slide_boost
	var boosted := minf(landing + _tuning.slide_boost, cap)
	# One frame of slide friction already applied after the boost: slow-slide friction if the
	# landing was below Run speed.
	var friction := _tuning.slide_friction
	if landing < _tuning.run_speed:
		friction = _tuning.slow_slide_friction
	assert_float(_horizontal(velocity).length()).is_equal_approx(boosted - friction * DELTA, 0.05)
