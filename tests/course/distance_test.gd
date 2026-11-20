extends GdUnitTestSuite
## The Distance is how far along the Course heading the Runner has got in the Attempt, from where
## it started, in whole metres, and never goes down. It is shown on screen while the Attempt runs.

const CourseScene := preload("res://course/course.tscn")
const SEED := 4711
## Where the Runner starts along the Course with the default tuning, m.
const RUNNER_START := 2.0

var _save_path := ""


func before_test() -> void:
	_save_path = "user://distance_test_%d.save" % randi()


func after_test() -> void:
	DirAccess.remove_absolute(_save_path)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## A fresh, seeded Course saving its Best distance to a file of the test's own.
func _course() -> Course:
	var course: Course = auto_free(CourseScene.instantiate())
	course.course_seed = SEED
	course.best_distance_path = _save_path
	return course


func _runner_of(course: Course) -> Runner:
	return course.get_node("Runner")


## Moves the Runner to [param along] m along the Course, [param aside] m to its right, and holds
## it there.
func _place(course: Course, along: float, aside: float = 0.0) -> void:
	var runner := _runner_of(course)
	runner.process_mode = Node.PROCESS_MODE_DISABLED
	runner.global_position = Vector3(aside, 0.0, -along)


func test_the_distance_is_zero_at_the_start_of_an_attempt() -> void:
	var course := _course()
	var scene := scene_runner(course)
	await scene.simulate_frames(1, 16)

	assert_int(course.distance()).is_equal(0)


func test_the_distance_counts_whole_metres_along_the_course_from_the_start() -> void:
	var course := _course()
	var scene := scene_runner(course)
	_place(course, RUNNER_START + 10.5)
	await scene.simulate_frames(1, 16)

	assert_int(course.distance()).is_equal(10)


func test_moving_sideways_does_not_add_to_the_distance() -> void:
	var course := _course()
	var scene := scene_runner(course)
	_place(course, RUNNER_START + 10.5)
	await scene.simulate_frames(1, 16)

	_place(course, RUNNER_START + 10.5, 3.5)
	await scene.simulate_frames(1, 16)

	assert_int(course.distance()).is_equal(10)


func test_the_distance_never_goes_down() -> void:
	var course := _course()
	var scene := scene_runner(course)
	_place(course, RUNNER_START + 20.5)
	await scene.simulate_frames(1, 16)

	_place(course, RUNNER_START + 5.5)
	await scene.simulate_frames(1, 16)

	assert_int(course.distance()).is_equal(20)


func test_running_along_the_course_adds_to_the_distance() -> void:
	var course := _course()
	var scene := scene_runner(course)

	await scene.simulate_frames(120, 16)
	# The Course notes the Distance before the Runner moves in a frame, so hold the Runner still
	# for one more frame to let the Distance catch up.
	_runner_of(course).process_mode = Node.PROCESS_MODE_DISABLED
	await scene.simulate_frames(1, 16)

	assert_int(course.distance()).is_equal(floori(course.runner_along() - RUNNER_START))
	assert_int(course.distance()).is_greater(5)


func test_the_distance_is_shown_on_screen() -> void:
	var course := _course()
	var scene := scene_runner(course)
	_place(course, RUNNER_START + 42.5)
	await scene.simulate_frames(1, 16)

	var shown: Label = course.get_node("Hud/Distance")
	assert_bool(shown.is_visible_in_tree()).is_true()
	assert_str(shown.text).is_equal("42 m")


func test_a_new_attempt_starts_the_distance_from_zero() -> void:
	var course := _course()
	var scene := scene_runner(course)
	_place(course, RUNNER_START + 30.5)
	await scene.simulate_frames(1, 16)
	_place(course, RUNNER_START + 30.5, Section.WIDTH * 2.0)
	_runner_of(course).process_mode = Node.PROCESS_MODE_INHERIT
	for _frame: int in 120:
		if course.is_attempt_over():
			break
		await scene.simulate_frames(1, 16)

	scene.simulate_action_pressed("jump")
	await scene.simulate_frames(1, 16)

	assert_bool(course.is_attempt_over()).is_false()
	assert_int(course.distance()).is_equal(0)
	assert_str((course.get_node("Hud/Distance") as Label).text).is_equal("0 m")
