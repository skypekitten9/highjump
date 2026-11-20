extends GdUnitTestSuite
## Mantles from a Wall-run, stepped frame by frame at 60 Hz with the default tuning. The wall is
## straight, on the Runner's right, and runs along -Z; its top is within Mantle reach. Expected
## values come from that tuning.

const DELTA := 1.0 / 60.0
const FORWARD := Vector3.FORWARD
## The wall's normal: it faces the Runner, which has the wall on its right.
const WALL_NORMAL := Vector3.LEFT
## Straight into the wall.
const INTO_WALL := Vector3.RIGHT
const WALL_ID := 1234
## Height of the Runner's standing body, m.
const STANDING_HEIGHT := 1.8
## The wall's top above the feet, comfortably within Mantle reach, m.
const TOP := 1.0
## A speed comfortably above the Wall-run entry speed, m/s.
const FAST := 12.0
## A glancing approach, degrees from parallel to the wall.
const GLANCING := 20.0

var _tuning: RunnerTuning
var _movement: RunnerMovement


func before_test() -> void:
	_tuning = load("res://runner/default_runner_tuning.tres")
	_movement = RunnerMovement.new(_tuning, STANDING_HEIGHT)


## The Player holding [param direction], or no move input.
func _moving(direction := Vector3.ZERO) -> RunnerMovement.Intent:
	return RunnerMovement.Intent.new(direction)


## Touching nothing, room to stand overhead.
func _in_air() -> RunnerMovement.Contact:
	return RunnerMovement.Contact.new(false)


## Touching the wall in the air. With [param ledge], the wall's top is ahead in the held
## direction, [constant TOP] above the feet, with room to stand on it.
func _on_wall(ledge := false) -> RunnerMovement.Contact:
	var wall := RunnerMovement.WallContact.new(WALL_NORMAL, WALL_ID)
	var top: RunnerMovement.LedgeContact = null
	if ledge:
		top = RunnerMovement.LedgeContact.new(WALL_NORMAL, TOP, INF)
	return RunnerMovement.Contact.new(false, Vector3.UP, true, wall, top)


## Horizontal velocity heading toward the wall at [param degrees] from parallel to it.
func _toward_wall(speed: float, degrees: float) -> Vector3:
	var angle := deg_to_rad(degrees)
	return Vector3(sin(angle), 0.0, -cos(angle)) * speed


func _horizontal(velocity: Vector3) -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


## Flies at [param approach] for a frame, then meets the wall holding [param direction], the way
## the Runner's body does: the engine's collision removes the speed going into the wall before
## the next step. With [param ledge], the wall's top is within reach. Returns the velocity of the
## frame the wall is met.
func _meet_wall(approach: Vector3, direction := FORWARD, ledge := false) -> Vector3:
	var planned := _movement.step(_moving(), _in_air(), approach, DELTA)
	var after_collision := planned - WALL_NORMAL * minf(planned.dot(WALL_NORMAL), 0.0)
	return _movement.step(_moving(direction), _on_wall(ledge), after_collision, DELTA)


## Starts a Wall-run at [param speed] holding along the wall, and runs it for a few frames.
## Returns the run's last velocity.
func _wall_run(speed := FAST) -> Vector3:
	var velocity := _meet_wall(_toward_wall(speed, GLANCING))
	for frame: int in 5:
		velocity = _movement.step(_moving(FORWARD), _on_wall(), velocity, DELTA)
	assert_bool(_is_wall_running()).is_true()
	return velocity


func _is_wall_running() -> bool:
	return _movement.state() == RunnerMovement.State.WALL_RUN


func _is_mantling() -> bool:
	return _movement.state() == RunnerMovement.State.MANTLE


func test_steering_into_the_wall_during_a_wall_run_mantles_onto_its_top() -> void:
	var velocity := _wall_run()
	_movement.step(_moving(INTO_WALL), _on_wall(true), velocity, DELTA)
	assert_bool(_is_mantling()).is_true()


## Holding along the wall and into it at once: both a Wall-run and a Mantle accept it.
func _along_and_into() -> Vector3:
	return (FORWARD + INTO_WALL).normalized()


func test_a_wall_run_mantle_keeps_all_its_speed_turning_part_of_it_into_the_wall() -> void:
	_wall_run()
	var running := FORWARD * 12.0
	var velocity := _movement.step(_moving(INTO_WALL), _on_wall(true), running, DELTA)
	# 12 m/s along the wall plus 3 m/s into it, all 12 m/s pointing that way: 11.64 m/s along
	# and 2.91 m/s into it.
	assert_float(_horizontal(velocity).length()).is_equal_approx(12.0, 0.0001)
	assert_float(velocity.dot(INTO_WALL)).is_equal_approx(2.9104, 0.001)
	assert_float(velocity.dot(FORWARD)).is_equal_approx(11.6417, 0.001)


func test_a_slow_wall_run_mantle_comes_off_at_run_speed() -> void:
	_wall_run(_tuning.wall_run_entry_speed + 0.5)
	var running := FORWARD * 6.0
	var velocity := _movement.step(_moving(INTO_WALL), _on_wall(true), running, DELTA)
	assert_float(_horizontal(velocity).length()).is_equal_approx(9.0, 0.0001)
	# 6 m/s along the wall plus 3 m/s into it, at 9 m/s: 8.05 m/s along and 4.02 m/s into it.
	assert_float(velocity.dot(INTO_WALL)).is_equal_approx(4.0249, 0.001)


func test_holding_along_the_wall_under_a_reachable_top_keeps_the_wall_run_going() -> void:
	var velocity := _wall_run()
	for frame: int in 10:
		velocity = _movement.step(_moving(FORWARD), _on_wall(true), velocity, DELTA)
		assert_bool(_is_wall_running()).is_true()


func test_holding_nothing_under_a_reachable_top_keeps_the_wall_run_going() -> void:
	var velocity := _wall_run()
	velocity = _movement.step(_moving(), _on_wall(true), velocity, DELTA)
	assert_bool(_is_wall_running()).is_true()


func test_meeting_a_wall_that_could_start_a_wall_run_mantles_if_its_top_is_within_reach() -> void:
	_meet_wall(_toward_wall(FAST, GLANCING), _along_and_into(), true)
	assert_bool(_is_mantling()).is_true()


func test_meeting_a_wall_holding_along_and_into_it_with_no_top_in_reach_wall_runs() -> void:
	_meet_wall(_toward_wall(FAST, GLANCING), _along_and_into())
	assert_bool(_is_wall_running()).is_true()


func test_a_wall_run_mantle_lands_on_top_and_clears_the_wall_run_lock() -> void:
	var velocity := _wall_run()
	velocity = _movement.step(_moving(INTO_WALL), _on_wall(true), velocity, DELTA)
	for frame: int in 5:
		velocity = _movement.step(_moving(INTO_WALL), _in_air(), velocity, DELTA)
	velocity.y = 0.0
	_movement.step(_moving(FORWARD), RunnerMovement.Contact.new(true), velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.RUN)

	# Off the top and back onto the same wall: it can be run again.
	_meet_wall(_toward_wall(FAST, GLANCING))
	assert_bool(_is_wall_running()).is_true()
