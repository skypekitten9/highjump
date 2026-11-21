extends GdUnitTestSuite
## While the mouse isn't captured the Attempt pauses: the Runner, the Course and the Stall clock
## stand still, and a note asks for a click. The click that captures the mouse again resumes the
## Attempt, and does nothing else. The headless display server ignores mouse modes, so the Course's
## own Mouse keeps the mode there, and these tests drop the capture through it as a browser does.

const CourseScene := preload("res://course/course.tscn")
const SEED := 4711
## Where these tests' Courses save the Best distance, so the Player's own is never touched.
const SAVE_PATH := "user://pause_test.save"
## Far longer than a Stall takes to be seen with the default tuning: physics frames.
const LONG_PAUSE_FRAMES := 300


func after_test() -> void:
	DirAccess.remove_absolute(SAVE_PATH)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## A fresh, seeded Course, not yet in the tree.
func _course() -> Course:
	var course: Course = auto_free(CourseScene.instantiate())
	course.course_seed = SEED
	course.best_distance_path = SAVE_PATH
	return course


func _runner_of(course: Course) -> Runner:
	return course.get_node("Runner")


## Starts [param course] and lets the Runner run a little way along it.
func _run_a_little(course: Course) -> GdUnitSceneRunner:
	var scene := scene_runner(course)
	await scene.simulate_frames(30, 16)
	return scene


func test_release_mouse_pauses_the_runner_where_it_is() -> void:
	var course := _course()
	var scene := await _run_a_little(course)

	scene.simulate_action_pressed("release_mouse")
	await scene.simulate_frames(1, 16)
	var paused_at := _runner_of(course).global_position
	await scene.simulate_frames(60, 16)

	assert_vector(_runner_of(course).global_position).is_equal(paused_at)
	assert_bool(course.is_paused()).is_true()


func test_the_attempt_pauses_when_the_capture_is_dropped_without_an_input() -> void:
	var course := _course()
	var scene := await _run_a_little(course)

	# As a browser does on Esc: the pointer lock goes, and the game gets no input for it.
	course.mouse.set_captured(false)
	await scene.simulate_frames(1, 16)
	var paused_at := _runner_of(course).global_position
	await scene.simulate_frames(60, 16)

	assert_bool(course.is_paused()).is_true()
	assert_vector(_runner_of(course).global_position).is_equal(paused_at)


func test_a_long_pause_never_stalls_the_attempt() -> void:
	var course := _course()
	var scene := await _run_a_little(course)

	scene.simulate_action_pressed("release_mouse")
	await scene.simulate_frames(LONG_PAUSE_FRAMES, 16)
	scene.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await scene.simulate_frames(30, 16)

	assert_bool(course.is_attempt_over()).is_false()


func test_the_course_and_the_distance_stand_still_while_paused() -> void:
	var course := _course()
	var scene := await _run_a_little(course)
	scene.simulate_action_pressed("release_mouse")
	await scene.simulate_frames(1, 16)
	var sections := course.sections()
	var distance := course.distance()

	await scene.simulate_frames(60, 16)

	assert_array(course.sections()).is_equal(sections)
	assert_int(course.distance()).is_equal(distance)


func test_the_capturing_click_resumes_the_attempt() -> void:
	var course := _course()
	var scene := await _run_a_little(course)
	scene.simulate_action_pressed("release_mouse")
	await scene.simulate_frames(10, 16)
	var along := course.runner_along()

	scene.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await scene.simulate_frames(30, 16)

	assert_bool(course.is_paused()).is_false()
	assert_float(course.runner_along()).is_greater(along + 2.0)


## Ends the Attempt with a fall, after running a little way along the Course.
func _fall(scene: GdUnitSceneRunner, course: Course) -> void:
	_runner_of(course).global_position.x = Section.WIDTH * 2.0
	for _frame: int in 120:
		if course.is_attempt_over():
			return
		await scene.simulate_frames(1, 16)


func test_the_capturing_click_on_the_end_screen_does_not_start_a_new_attempt() -> void:
	var course := _course()
	var scene := await _run_a_little(course)
	await _fall(scene, course)
	scene.simulate_action_pressed("release_mouse")
	await scene.simulate_frames(1, 16)

	scene.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await scene.simulate_frames(1, 16)

	assert_bool(course.is_paused()).is_false()
	assert_bool(course.is_attempt_over()).is_true()
	assert_int(course.ending()).is_equal(Course.Ending.FALL)


func test_jump_while_paused_on_the_end_screen_does_not_start_a_new_attempt() -> void:
	var course := _course()
	var scene := await _run_a_little(course)
	await _fall(scene, course)
	scene.simulate_action_pressed("release_mouse")
	await scene.simulate_frames(1, 16)

	scene.simulate_action_pressed("jump")
	await scene.simulate_frames(1, 16)

	assert_bool(course.is_attempt_over()).is_true()


func test_resuming_after_the_attempt_ends_leaves_the_runner_stopped() -> void:
	var course := _course()
	var scene := await _run_a_little(course)
	await _fall(scene, course)
	scene.simulate_action_pressed("release_mouse")
	await scene.simulate_frames(1, 16)
	scene.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await scene.simulate_frames(1, 16)
	var stopped_at := _runner_of(course).global_position

	await scene.simulate_frames(30, 16)

	assert_vector(_runner_of(course).global_position).is_equal(stopped_at)


func test_a_click_to_continue_note_shows_only_while_paused() -> void:
	var course := _course()
	var scene := await _run_a_little(course)
	var note: Label = course.get_node("Hud/Paused")
	assert_bool(note.visible).is_false()

	scene.simulate_action_pressed("release_mouse")
	await scene.simulate_frames(1, 16)
	assert_bool(note.visible).is_true()
	assert_str(note.text.to_lower()).contains("click to continue")

	scene.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await scene.simulate_frames(1, 16)
	assert_bool(note.visible).is_false()
