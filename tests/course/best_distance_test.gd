extends GdUnitTestSuite
## The Best distance is the greatest Distance of any Attempt, saved between sessions. The end
## screen shows the Attempt's Distance and the Best distance, and marks a new best.

const CourseScene := preload("res://course/course.tscn")
const SEED := 4711
## Where the Runner starts along the Course with the default tuning, m.
const RUNNER_START := 2.0
## How far below floor height 0 the feet must be for a fall, with the default tuning, m.
const FALL_DEPTH := 10.0

var _save_path := ""


func before_test() -> void:
	_save_path = "user://best_distance_test_%d.save" % randi()


func after_test() -> void:
	DirAccess.remove_absolute(_save_path)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## A fresh, seeded Course saving its Best distance to the test's own file.
func _course() -> Course:
	var course: Course = auto_free(CourseScene.instantiate())
	course.course_seed = SEED
	course.best_distance_path = _save_path
	return course


func _save(text: String) -> void:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Ends the Attempt with a fall once the Runner has got [param distance] m along the Course.
func _end_at(scene: GdUnitSceneRunner, course: Course, distance: int) -> void:
	var runner: Runner = course.get_node("Runner")
	runner.process_mode = Node.PROCESS_MODE_DISABLED
	runner.global_position = Vector3(0.0, 0.0, -(RUNNER_START + distance + 0.5))
	await scene.simulate_frames(1, 16)
	runner.global_position.y = -FALL_DEPTH - 1.0
	await scene.simulate_frames(1, 16)
	assert_bool(course.is_attempt_over()).is_true()
	assert_int(course.distance()).is_equal(distance)


func _line(course: Course, name: String) -> Label:
	return course.get_node("EndScreen/Centre/Lines/" + name)


func test_with_no_save_the_best_distance_is_zero() -> void:
	var course := _course()
	scene_runner(course)

	assert_int(course.best_distance()).is_equal(0)


func test_a_corrupt_save_counts_as_zero() -> void:
	_save("not a distance")
	var course := _course()
	scene_runner(course)

	assert_int(course.best_distance()).is_equal(0)


func test_a_negative_save_counts_as_zero() -> void:
	_save("-12")
	var course := _course()
	scene_runner(course)

	assert_int(course.best_distance()).is_equal(0)


func test_the_best_distance_is_read_from_the_save_at_start() -> void:
	_save("73")
	var course := _course()
	scene_runner(course)

	assert_int(course.best_distance()).is_equal(73)


func test_a_new_best_distance_is_kept_for_the_next_session() -> void:
	_save("20")
	var course := _course()
	var scene := scene_runner(course)

	await _end_at(scene, course, 35)

	assert_int(course.best_distance()).is_equal(35)
	var next_session := _course()
	scene_runner(next_session)
	assert_int(next_session.best_distance()).is_equal(35)


func test_an_attempt_short_of_the_best_distance_leaves_it() -> void:
	_save("50")
	var course := _course()
	var scene := scene_runner(course)

	await _end_at(scene, course, 35)

	assert_int(course.best_distance()).is_equal(50)
	var next_session := _course()
	scene_runner(next_session)
	assert_int(next_session.best_distance()).is_equal(50)


func test_the_end_screen_shows_the_distance_and_the_best_distance() -> void:
	_save("50")
	var course := _course()
	var scene := scene_runner(course)

	await _end_at(scene, course, 35)

	assert_str(_line(course, "Distance").text).is_equal("Distance: 35 m")
	assert_str(_line(course, "Best").text).is_equal("Best: 50 m")
	assert_bool(_line(course, "NewBest").is_visible_in_tree()).is_false()


func test_the_end_screen_marks_a_new_best() -> void:
	_save("20")
	var course := _course()
	var scene := scene_runner(course)

	await _end_at(scene, course, 35)

	assert_str(_line(course, "Distance").text).is_equal("Distance: 35 m")
	assert_str(_line(course, "Best").text).is_equal("Best: 35 m")
	assert_bool(_line(course, "NewBest").is_visible_in_tree()).is_true()


func test_equalling_the_best_distance_is_not_a_new_best() -> void:
	_save("35")
	var course := _course()
	var scene := scene_runner(course)

	await _end_at(scene, course, 35)

	assert_bool(_line(course, "NewBest").is_visible_in_tree()).is_false()


func test_a_new_best_is_measured_against_earlier_attempts_in_the_same_session() -> void:
	var course := _course()
	var scene := scene_runner(course)
	await _end_at(scene, course, 40)
	scene.simulate_action_pressed("jump")
	await scene.simulate_frames(1, 16)

	await _end_at(scene, course, 25)

	assert_str(_line(course, "Best").text).is_equal("Best: 40 m")
	assert_bool(_line(course, "NewBest").is_visible_in_tree()).is_false()
