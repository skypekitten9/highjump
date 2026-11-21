extends GdUnitTestSuite
## An Attempt ends when the Runner falls or Stalls: the Runner stops responding and the end screen
## appears. Jump or a click then starts a new Attempt on a fresh Course, from the start Section.

const CourseScene := preload("res://course/course.tscn")
const START_SECTION := "res://course/sections/start.tscn"
const SEED := 4711
## Where these tests' Courses save the Best distance, so the Player's own is never touched.
const SAVE_PATH := "user://attempt_test.save"
## How far below floor height 0 the feet must be for a fall, with the default tuning, m.
const FALL_DEPTH := 10.0
## Comfortably more than a Stall takes to be seen once the Runner is held still: physics frames.
const STALL_FRAMES := 90
## The start Section's length, m: the first picked Section starts this far along the Course.
const START_LENGTH := 30.0


func after_test() -> void:
	DirAccess.remove_absolute(SAVE_PATH)
	Input.action_release("jump")
	Input.action_release("crouch")
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## A fresh, seeded Course, not yet in the tree.
func _course() -> Course:
	var course: Course = auto_free(CourseScene.instantiate())
	course.course_seed = SEED
	course.best_distance_path = SAVE_PATH
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


## A Player input: once the Runner is [param along] m along the Course, [param action] is pressed,
## or released if not [param press]. A jump is tapped: pressed for one frame.
class Step:
	var along: float
	var action: StringName
	var press: bool


	func _init(at: float, what: StringName, down := true) -> void:
		along = at
		action = what
		press = down


## A Course that lays only the Section at [param path] after its start Section, whatever its
## difficulty.
func _course_of(path: String) -> Course:
	var course := _course()
	course.difficulty_2_unlock = 0.0
	course.difficulty_3_unlock = 0.0
	var list := SectionList.new()
	list.sections = [load(path) as PackedScene]
	course.section_list = list
	return course


## What the Runner did in a run by [method _run_with].
class Seen:
	var wall_ran := false
	var mantled := false


## Runs [param course]'s Runner until it is [param to] m along the Course or the Attempt ends,
## pressing [param steps] in order, and returns what the Runner did on the way.
func _run_with(course: Course, steps: Array[Step], to: float) -> Seen:
	var scene := scene_runner(course)
	var runner := _runner_of(course)
	var pending := steps.duplicate()
	var seen := Seen.new()
	for _frame: int in 900:
		var along := course.runner_along()
		if along >= to or course.is_attempt_over():
			break
		Input.action_release(&"jump")
		while not pending.is_empty() and along >= (pending[0] as Step).along:
			var step: Step = pending.pop_front()
			if step.press:
				Input.action_press(step.action)
			else:
				Input.action_release(step.action)
		await scene.simulate_frames(1, 16)
		seen.wall_ran = seen.wall_ran or runner.is_wall_running()
		seen.mantled = seen.mantled or runner.is_mantling()
	return seen


func test_wall_running_along_the_course_never_stalls() -> void:
	var course := _course_of("res://course/sections/wall_run_gap.tscn")
	var steps: Array[Step] = [
		Step.new(START_LENGTH + 5.0, &"move_left"),
		Step.new(START_LENGTH + 8.5, &"jump"),
		Step.new(START_LENGTH + 20.0, &"move_left", false),
	]

	var seen := await _run_with(course, steps, START_LENGTH + 30.0)

	assert_bool(seen.wall_ran).is_true()
	assert_bool(course.is_attempt_over()).is_false()
	assert_float(course.runner_along()).is_greater_equal(START_LENGTH + 30.0)


func test_mantling_onto_a_block_never_stalls() -> void:
	var course := _course_of("res://course/sections/block.tscn")
	var steps: Array[Step] = [Step.new(START_LENGTH + 6.5, &"jump")]

	var seen := await _run_with(course, steps, START_LENGTH + 26.0)

	assert_bool(seen.mantled).is_true()
	assert_bool(course.is_attempt_over()).is_false()
	assert_float(course.runner_along()).is_greater_equal(START_LENGTH + 26.0)


func test_mantling_from_a_wall_run_never_stalls() -> void:
	var course := _course_of("res://course/sections/block_long_gap_wall_run_gap.tscn")
	var steps: Array[Step] = [
		Step.new(START_LENGTH + 6.5, &"jump"),
		Step.new(START_LENGTH + 21.0, &"crouch"),
		Step.new(START_LENGTH + 25.6, &"jump"),
		Step.new(START_LENGTH + 27.0, &"crouch", false),
		Step.new(START_LENGTH + 39.0, &"move_right"),
		Step.new(START_LENGTH + 43.5, &"jump"),
		Step.new(START_LENGTH + 55.0, &"move_right", false),
	]

	var seen := await _run_with(course, steps, START_LENGTH + 60.0)

	assert_bool(seen.wall_ran).is_true()
	assert_bool(seen.mantled).is_true()
	assert_bool(course.is_attempt_over()).is_false()
	assert_float(course.runner_along()).is_greater_equal(START_LENGTH + 60.0)
