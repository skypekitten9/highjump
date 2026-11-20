extends GdUnitTestSuite
## An Attempt ends when the Runner falls or Stalls: the Runner stops responding and the end screen
## appears. Jump or a click then starts a new Attempt on a fresh Course, from the start Section.

const CourseScene := preload("res://course/course.tscn")
const START_SECTION := "res://course/sections/start.tscn"
const SEED := 4711
## How far below floor height 0 the feet must be for a fall, with the default tuning, m.
const FALL_DEPTH := 10.0
## Comfortably more than a Stall takes to be seen once the Runner is held still: physics frames.
const STALL_FRAMES := 90


func after_test() -> void:
	Input.action_release("jump")
	Input.action_release("crouch")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## A fresh, seeded Course, not yet in the tree.
func _course() -> Course:
	var course: Course = auto_free(CourseScene.instantiate())
	course.course_seed = SEED
	return course


func _runner_of(course: Course) -> Runner:
	return course.get_node("Runner")


func _end_screen_of(course: Course) -> CanvasLayer:
	return course.get_node("EndScreen")


## A Block across the whole width of the Course, too tall to jump or Mantle, whose near face is
## [param ahead] m along the Course.
func _add_wall_across(course: Course, ahead: float) -> void:
	var block := CSGBox3D.new()
	block.size = Vector3(Section.WIDTH, 6.0, 1.0)
	block.position = Vector3(0.0, 3.0, -ahead - 0.5)
	block.use_collision = true
	course.add_child(block)


## Simulates physics frames until the Attempt ends, at most [param most] of them.
func _until_ended(scene: GdUnitSceneRunner, course: Course, most: int) -> void:
	for _frame: int in most:
		if course.is_attempt_over():
			return
		await scene.simulate_frames(1, 16)


func test_falling_off_the_course_ends_the_attempt_as_a_fall() -> void:
	var course := _course()
	var scene := scene_runner(course)
	var runner := _runner_of(course)
	assert_bool(course.is_attempt_over()).is_false()
	assert_bool(_end_screen_of(course).visible).is_false()

	# Off the side of the Course, with nothing below.
	runner.global_position.x = Section.WIDTH * 2.0
	await _until_ended(scene, course, 120)

	assert_bool(course.is_attempt_over()).is_true()
	assert_int(course.ending()).is_equal(Course.Ending.FALL)
	assert_bool(_end_screen_of(course).visible).is_true()
	# It ended as the feet went below the fall depth, not long before or after.
	assert_float(runner.global_position.y).is_between(-FALL_DEPTH - 1.0, -FALL_DEPTH)


func test_once_the_attempt_ends_the_runner_stops_responding() -> void:
	var course := _course()
	var scene := scene_runner(course)
	var runner := _runner_of(course)
	runner.global_position.x = Section.WIDTH * 2.0
	await _until_ended(scene, course, 120)
	var stopped_at := runner.global_position

	Input.action_press("crouch")
	await scene.simulate_frames(30, 16)

	assert_vector(runner.global_position).is_equal(stopped_at)


func test_being_held_against_a_block_across_the_course_ends_the_attempt_as_a_stall() -> void:
	var course := _course()
	_add_wall_across(course, 6.0)
	var scene := scene_runner(course)

	await _until_ended(scene, course, 60 + STALL_FRAMES)

	assert_int(course.ending()).is_equal(Course.Ending.STALL)
	assert_bool(_end_screen_of(course).visible).is_true()
	# Held against the Block, not short of it.
	assert_float(course.runner_along()).is_greater(5.0)


## Ends the Attempt with a fall, after running a little way along the Course.
func _fall(scene: GdUnitSceneRunner, course: Course) -> void:
	await scene.simulate_frames(30, 16)
	_runner_of(course).global_position.x = Section.WIDTH * 2.0
	await _until_ended(scene, course, 120)
	assert_bool(course.is_attempt_over()).is_true()


## Checks [param course] is at the start of a new Attempt: the end screen gone, a fresh start
## Section under the Runner, standing at its start, and every one of [param old_sections] freed.
func _assert_new_attempt(course: Course, old_sections: Array[Section]) -> void:
	assert_bool(course.is_attempt_over()).is_false()
	assert_int(course.ending()).is_equal(Course.Ending.NONE)
	assert_bool(_end_screen_of(course).visible).is_false()
	var first: Section = course.sections()[0]
	assert_str(first.scene_file_path).is_equal(START_SECTION)
	assert_vector(first.global_position).is_equal(Vector3.ZERO)
	assert_float(course.runner_along()).is_between(0.0, 3.0)
	assert_float(_runner_of(course).global_position.y).is_between(-0.01, 0.5)
	for old: Section in old_sections:
		assert_bool(is_instance_valid(old)).is_false()


func test_jump_after_the_attempt_ends_starts_a_new_attempt_from_the_start() -> void:
	var course := _course()
	var scene := scene_runner(course)
	await _fall(scene, course)
	var old_sections := course.sections()

	scene.simulate_action_pressed("jump")
	await scene.simulate_frames(1, 16)

	_assert_new_attempt(course, old_sections)


func test_a_click_after_the_attempt_ends_starts_a_new_attempt() -> void:
	var course := _course()
	var scene := scene_runner(course)
	await _fall(scene, course)
	var old_sections := course.sections()

	scene.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await scene.simulate_frames(1, 16)

	_assert_new_attempt(course, old_sections)


func test_the_new_attempt_runs_and_can_end_again() -> void:
	var course := _course()
	var scene := scene_runner(course)
	await _fall(scene, course)
	scene.simulate_action_pressed("jump")
	await scene.simulate_frames(60, 16)

	assert_bool(course.is_attempt_over()).is_false()
	assert_float(course.runner_along()).is_greater(5.0)
	assert_vector(_runner_of(course).course_heading).is_equal_approx(
		course.heading(),
		Vector3.ONE * 0.001,
	)

	await _fall(scene, course)
	assert_int(course.ending()).is_equal(Course.Ending.FALL)


func test_jump_while_the_attempt_runs_does_not_start_a_new_one() -> void:
	var course := _course()
	var scene := scene_runner(course)
	await scene.simulate_frames(30, 16)
	var first: Section = course.sections()[0]
	var along := course.runner_along()

	scene.simulate_action_pressed("jump")
	await scene.simulate_frames(2, 16)

	assert_bool(course.sections().has(first)).is_true()
	assert_float(course.runner_along()).is_greater(along)


func test_running_along_the_course_never_stalls() -> void:
	var course := _course()
	var scene := scene_runner(course)

	await scene.simulate_frames(180, 16)

	assert_bool(course.is_attempt_over()).is_false()


func test_sliding_along_the_course_never_stalls() -> void:
	var course := _course()
	var scene := scene_runner(course)
	await scene.simulate_frames(30, 16)

	# Slides, and keeps crouching once the Slide has slowed to a Crouch.
	Input.action_press("crouch")
	await scene.simulate_frames(240, 16)

	assert_bool(course.is_attempt_over()).is_false()
