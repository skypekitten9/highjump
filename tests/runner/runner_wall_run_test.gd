extends GdUnitTestSuite
## Wall-runs of the Runner, stepped frame by frame at 60 Hz with the default tuning. The wall is
## straight, on the Runner's right, and runs along -Z. Expected values come from that tuning.

const DELTA := 1.0 / 60.0
const FORWARD := Vector3.FORWARD
## The wall's normal: it faces the Runner, which has the wall on its right.
const WALL_NORMAL := Vector3.LEFT
const WALL_ID := 1234
## The facing wall across the gap: its normal points back toward the first wall.
const OPPOSITE_NORMAL := Vector3.RIGHT
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
	return RunnerMovement.Contact.new(on_floor, Vector3.UP, true, _wall(WALL_NORMAL, WALL_ID))


## A surface with [param normal] and identity [param id] that may be a wall.
func _wall(normal: Vector3, id: int) -> RunnerMovement.WallContact:
	return RunnerMovement.WallContact.new(normal, id)


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


## Frames from a moment to just inside a window of [param seconds] after it.
func _frames_inside(seconds: float) -> int:
	return roundi(seconds / DELTA) - 1


## Frames from a moment to clearly past a window of [param seconds] after it.
func _frames_past(seconds: float) -> int:
	return roundi(seconds / DELTA) + 3


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
	var contact := RunnerMovement.Contact.new(false, Vector3.UP, true, _wall(leaning, WALL_ID))
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


func test_landing_on_a_slope_during_a_wall_run_ends_it_running_up_the_slope() -> void:
	# Rising 20 degrees ahead, along the wall.
	var slope := Vector3.UP.rotated(Vector3.RIGHT, deg_to_rad(20.0))
	var on_slope := RunnerMovement.Contact.new(true, slope, true, _wall(WALL_NORMAL, WALL_ID))
	var velocity := _meet_wall(_toward_wall(FAST, GLANCING))
	velocity = _movement.step(_moving(FORWARD), _on_wall(), velocity, DELTA)
	velocity = _movement.step(_moving(FORWARD), on_slope, velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.RUN)
	assert_bool(_movement.is_on_ground()).is_true()
	# Along the slope, up it: neither into it nor off it.
	assert_float(velocity.dot(slope)).is_equal_approx(0.0, 0.0001)
	assert_float(velocity.y).is_greater(0.0)


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
	# Within a tenth: a slowdown or end speed off by more is not this tuning.
	assert_float(float(frames)).is_equal_approx(expected_frames, expected_frames * 0.1)
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
	var frames := _frames_past(_tuning.slide_boost_cooldown)
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


## The Player pressing jump this frame while holding [param direction].
func _jumping(direction := FORWARD) -> RunnerMovement.Intent:
	return RunnerMovement.Intent.new(direction, true)


## Upward speed of a jump off the floor, m/s.
func _launch_speed() -> float:
	return sqrt(2.0 * _tuning.gravity * _tuning.jump_height)


func test_a_wall_jump_keeps_the_speed_along_the_wall_adds_the_push_and_launches_up() -> void:
	var velocity := _meet_wall(_toward_wall(FAST, GLANCING))
	velocity = _movement.step(_moving(FORWARD), _on_wall(), velocity, DELTA)
	var along := velocity.dot(FORWARD)
	velocity = _movement.step(_jumping(), _on_wall(), velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.AIR)
	assert_float(velocity.dot(FORWARD)).is_equal_approx(along, 0.0001)
	assert_float(velocity.dot(WALL_NORMAL)).is_equal_approx(_tuning.wall_jump_push, 0.0001)
	assert_float(velocity.y).is_equal_approx(_launch_speed(), 0.0001)


func test_holding_forward_after_a_wall_jump_does_not_cancel_its_push() -> void:
	var velocity := _meet_wall(_toward_wall(FAST, GLANCING))
	velocity = _movement.step(_jumping(), _on_wall(), velocity, DELTA)
	# A quarter of a second: about the time the push takes to carry the body across the
	# greybox's 2 m gap to the opposite wall.
	for frame: int in roundi(0.25 / DELTA):
		velocity = _movement.step(_moving(FORWARD), _in_air(), velocity, DELTA)
	# Steering turns some of the push forward, but more than half of it is left.
	assert_float(velocity.dot(WALL_NORMAL)).is_greater(_tuning.wall_jump_push * 0.5)


func test_a_jump_pressed_just_before_meeting_a_wall_does_not_wall_jump_as_the_run_starts() -> void:
	var approach := _toward_wall(FAST, GLANCING)
	approach = _movement.step(_jumping(), _in_air(), approach, DELTA)
	var velocity := _meet_wall(approach)
	var frames := ceili(_tuning.jump_buffer_time / DELTA) + 1
	for frame: int in frames:
		velocity = _movement.step(_moving(FORWARD), _on_wall(), velocity, DELTA)
		assert_bool(_is_wall_running()).is_true()


## Wall-runs until the wall runs out, then presses jump on the [param frames_after]th frame
## after the run ended. Returns the velocity on that frame.
func _press_after_wall_runs_out(frames_after: int) -> Vector3:
	var velocity := _meet_wall(_toward_wall(FAST, GLANCING))
	velocity = _movement.step(_moving(FORWARD), _in_air(), velocity, DELTA)
	for frame: int in frames_after - 1:
		velocity = _movement.step(_moving(FORWARD), _in_air(), velocity, DELTA)
	return _movement.step(_jumping(), _in_air(), velocity, DELTA)


func test_a_jump_pressed_just_inside_coyote_time_after_a_wall_run_wall_jumps() -> void:
	var velocity := _press_after_wall_runs_out(_frames_inside(_tuning.coyote_time))
	assert_float(velocity.dot(WALL_NORMAL)).is_equal_approx(_tuning.wall_jump_push, 0.0001)
	assert_float(velocity.y).is_equal_approx(_launch_speed(), 0.0001)


func test_a_jump_pressed_past_coyote_time_after_a_wall_run_does_not_jump() -> void:
	var velocity := _press_after_wall_runs_out(_frames_past(_tuning.coyote_time))
	assert_float(velocity.dot(WALL_NORMAL)).is_equal_approx(0.0, 0.0001)
	assert_float(velocity.y).is_less(0.0)


## Touching a wall with [param id] and [param normal] in the air.
func _on_other_wall(id: int, normal := WALL_NORMAL) -> RunnerMovement.Contact:
	return RunnerMovement.Contact.new(false, Vector3.UP, true, _wall(normal, id))


## Wall-runs the wall until it runs out, then flies on a frame. Returns the velocity.
func _run_off_the_wall() -> Vector3:
	var velocity := _meet_wall(_toward_wall(FAST, GLANCING))
	return _movement.step(_moving(FORWARD), _in_air(), velocity, DELTA)


func test_the_same_wall_is_refused_again_until_the_runner_lands() -> void:
	_run_off_the_wall()
	_meet_wall(_toward_wall(FAST, GLANCING))
	assert_bool(_is_wall_running()).is_false()
	_movement.step(_moving(FORWARD), _on_floor(), FORWARD * FAST, DELTA)
	_meet_wall(_toward_wall(FAST, GLANCING))
	assert_bool(_is_wall_running()).is_true()


func test_a_different_wall_is_accepted_and_frees_the_first_again() -> void:
	_run_off_the_wall()
	_meet_wall(_toward_wall(FAST, GLANCING), _moving(FORWARD), _on_other_wall(WALL_ID + 1))
	assert_bool(_is_wall_running()).is_true()
	_movement.step(_moving(FORWARD), _in_air(), FORWARD * FAST, DELTA)
	_meet_wall(_toward_wall(FAST, GLANCING))
	assert_bool(_is_wall_running()).is_true()


## Wall-runs the wall at [param speed], Wall-jumps, flies a frame holding forward and meets the
## opposite wall, its into-wall speed removed by the collision. Returns the velocity of the frame
## the opposite wall is met.
func _wall_jump_across(speed: float) -> Vector3:
	var velocity := _meet_wall(_toward_wall(speed, GLANCING))
	velocity = _movement.step(_jumping(), _on_wall(), velocity, DELTA)
	velocity = _movement.step(_moving(FORWARD), _in_air(), velocity, DELTA)
	velocity -= OPPOSITE_NORMAL * minf(velocity.dot(OPPOSITE_NORMAL), 0.0)
	var opposite := _on_other_wall(WALL_ID + 1, OPPOSITE_NORMAL)
	return _movement.step(_moving(FORWARD), opposite, velocity, DELTA)


func test_a_wall_jump_to_the_opposite_wall_turns_the_push_into_speed_along_it() -> void:
	var velocity := _wall_jump_across(FAST)
	assert_bool(_is_wall_running()).is_true()
	# All of it: the speed along the first wall and the push.
	var speed := Vector2(FAST, _tuning.wall_jump_push).length()
	assert_float(_horizontal(velocity).length()).is_equal_approx(speed, 0.001)
	assert_float(_horizontal(velocity).normalized().dot(FORWARD)).is_equal_approx(1.0, 0.0001)


func test_speed_gained_from_wall_to_wall_stops_at_the_top_wall_run_speed() -> void:
	var velocity := _wall_jump_across(_tuning.top_wall_run_speed - 0.5)
	assert_bool(_is_wall_running()).is_true()
	var speed := _horizontal(velocity).length()
	assert_float(speed).is_equal_approx(_tuning.top_wall_run_speed, 0.001)


func test_a_runner_faster_than_the_top_wall_run_speed_keeps_its_speed_from_wall_to_wall() -> void:
	var fast := _tuning.top_wall_run_speed + 6.0
	var velocity := _wall_jump_across(fast)
	assert_bool(_is_wall_running()).is_true()
	assert_float(_horizontal(velocity).length()).is_equal_approx(fast, 0.001)


func test_a_wall_jump_with_no_forward_speed_meets_the_opposite_wall_too_head_on_to_run_it() -> void:
	var velocity := _meet_wall(_toward_wall(FAST, GLANCING))
	# Something ahead stops the run dead; the wall runs on beside the Runner.
	velocity = _movement.step(_moving(), _on_wall(), Vector3.UP * velocity.y, DELTA)
	velocity = _movement.step(_jumping(-OPPOSITE_NORMAL), _in_air(), velocity, DELTA)
	assert_float(_horizontal(velocity).dot(FORWARD)).is_equal_approx(0.0, 0.0001)
	assert_float(_horizontal(velocity).length()).is_greater_equal(_tuning.wall_run_entry_speed)
	# Holding straight toward the opposite wall, so the angle alone refuses the run.
	velocity = _movement.step(_moving(-OPPOSITE_NORMAL), _in_air(), velocity, DELTA)
	velocity -= OPPOSITE_NORMAL * minf(velocity.dot(OPPOSITE_NORMAL), 0.0)
	var opposite := _on_other_wall(WALL_ID + 1, OPPOSITE_NORMAL)
	_movement.step(_moving(-OPPOSITE_NORMAL), opposite, velocity, DELTA)
	assert_bool(_is_wall_running()).is_false()


## The wall's normal turned by [param degrees] about UP: positive turns it toward FORWARD, so
## the wall bends away from the Runner (the outside of a curve or corner); negative turns it
## toward BACK, so the wall bends into the Runner's path.
func _turned_normal(degrees: float) -> Vector3:
	return WALL_NORMAL.rotated(Vector3.UP, deg_to_rad(-degrees))


func test_a_wall_curving_away_gently_frame_by_frame_is_followed_with_speed_unchanged() -> void:
	var velocity := _meet_wall(_toward_wall(FAST, 0.0))
	var step := _tuning.wall_run_follow_angle / 10.0
	var frames := 30
	var normal := WALL_NORMAL
	for frame: int in frames:
		normal = _turned_normal(step * (frame + 1))
		var contact := _on_other_wall(WALL_ID, normal)
		velocity = _movement.step(_moving(FORWARD), contact, velocity, DELTA)
		assert_bool(_is_wall_running()).is_true()
	assert_bool(_movement.wall_normal().is_equal_approx(normal)).is_true()
	var direction := _turned_normal(step * frames).cross(Vector3.UP)
	assert_float(_horizontal(velocity).normalized().dot(direction)).is_equal_approx(1.0, 0.0001)
	var speed := FAST - _tuning.wall_run_slowdown * frames * DELTA
	assert_float(_horizontal(velocity).length()).is_equal_approx(speed, 0.001)


func test_a_wall_turning_away_beyond_the_follow_angle_ends_the_run_at_the_outside_corner() -> void:
	var on_wall := _meet_wall(_toward_wall(FAST, GLANCING))
	var corner := _on_other_wall(WALL_ID, _turned_normal(_tuning.wall_run_follow_angle + 5.0))
	var velocity := _movement.step(_moving(FORWARD), corner, on_wall, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.AIR)
	# It flies off the corner with its velocity.
	assert_bool(_horizontal(velocity).is_equal_approx(_horizontal(on_wall))).is_true()


## Wall-runs the wall, then meets another wall turned [param degrees] into the Runner's path (an
## inside corner), its speed into that wall removed by the collision. Returns the velocity of the
## frame the other wall is met; [param on_wall] gets the velocity of the frame before.
func _meet_inside_corner(degrees: float, on_wall: Array[Vector3]) -> Vector3:
	var velocity := _meet_wall(_toward_wall(FAST, GLANCING))
	on_wall.append(velocity)
	var normal := _turned_normal(-degrees)
	velocity -= normal * minf(velocity.dot(normal), 0.0)
	return _movement.step(_moving(FORWARD), _on_other_wall(WALL_ID + 1, normal), velocity, DELTA)


func test_a_wall_blocking_the_run_within_the_maximum_entry_angle_carries_it_on_at_speed() -> void:
	var degrees := 40.0
	var before: Array[Vector3] = []
	var velocity := _meet_inside_corner(degrees, before)
	assert_bool(_is_wall_running()).is_true()
	var speed := _horizontal(before[0]).length() - _tuning.wall_run_slowdown * DELTA
	assert_float(_horizontal(velocity).length()).is_equal_approx(speed, 0.001)
	var along := _turned_normal(-degrees).cross(Vector3.UP)
	assert_float(_horizontal(velocity).normalized().dot(along)).is_equal_approx(1.0, 0.0001)


func test_the_wall_turned_onto_at_an_inside_corner_is_refused_again_until_landing() -> void:
	var degrees := 40.0
	var velocity := _meet_inside_corner(degrees, [] as Array[Vector3])
	velocity = _movement.step(_moving(FORWARD), _in_air(), velocity, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.AIR)
	var normal := _turned_normal(-degrees)
	var glancing := _toward_wall(FAST, GLANCING).rotated(Vector3.UP, deg_to_rad(degrees))
	_movement.step(_moving(FORWARD), _in_air(), glancing, DELTA)
	glancing -= normal * minf(glancing.dot(normal), 0.0)
	_movement.step(_moving(FORWARD), _on_other_wall(WALL_ID + 1, normal), glancing, DELTA)
	assert_bool(_is_wall_running()).is_false()


func test_a_wall_blocking_the_run_beyond_the_maximum_entry_angle_ends_the_run() -> void:
	# Fast, so the speed left along the old wall after the collision would still run on.
	var degrees := _tuning.wall_run_max_entry_angle + 5.0
	var velocity := _meet_wall(_toward_wall(60.0, GLANCING))
	var normal := _turned_normal(-degrees)
	var collided := velocity - normal * minf(velocity.dot(normal), 0.0)
	assert_float(collided.dot(FORWARD)).is_greater(_tuning.wall_run_end_speed)
	velocity = _movement.step(_moving(), _on_other_wall(WALL_ID + 1, normal), collided, DELTA)
	assert_int(_movement.state()).is_equal(RunnerMovement.State.AIR)
	# It collides normally: the collision's velocity carries on, in the air.
	assert_bool(_horizontal(velocity).is_equal_approx(_horizontal(collided))).is_true()
