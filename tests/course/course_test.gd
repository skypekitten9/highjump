extends GdUnitTestSuite
## The Course begins with its flat start Section under a still Runner, sets the Runner's Course
## heading, keeps Sections laid ahead of the Runner and frees those well behind it, and picks
## them at random by the unlock and no-repeat rules.

const CourseScene := preload("res://course/course.tscn")
const START_SECTION := "res://course/sections/start.tscn"
const SEED := 4711
## Where these tests' Courses save the Best distance, so the Player's own is never touched.
const SAVE_PATH := "user://course_test.save"
## Where difficulty 2 and 3 unlock with the default tuning, m along the Course.
const DIFFICULTY_2_UNLOCK := 150.0
const DIFFICULTY_3_UNLOCK := 400.0


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


## How far along the Course [param point] is, m.
func _along(course: Course, point: Vector3) -> float:
	return (point - course.global_position).dot(course.heading())


## How far along the Course its last laid Section ends, m.
func _laid_end(course: Course) -> float:
	var last: Section = course.sections().back()
	return _along(course, last.global_position) + last.length


## Moves the Runner [param distance] further along the Course, keeping its height, and lets the
## Course see it.
func _move_runner_on(scene: GdUnitSceneRunner, course: Course, distance: float) -> void:
	var runner := _runner_of(course)
	runner.global_position += course.heading() * distance
	await scene.simulate_frames(2, 16)


func test_the_course_begins_with_the_runner_at_the_start_of_the_start_section() -> void:
	var course := _course()
	scene_runner(course)

	var first: Section = course.sections()[0]
	var runner := _runner_of(course)
	assert_str(first.scene_file_path).is_equal(START_SECTION)
	assert_float(first.length).is_equal_approx(30.0, 0.5)
	assert_vector(first.global_position).is_equal(Vector3.ZERO)
	assert_float(runner.global_position.z).is_between(-first.length, 0.0)


func test_the_course_sets_the_runners_course_heading() -> void:
	var course := _course()
	# A Course leading along +X.
	course.rotation_degrees.y = -90.0
	scene_runner(course)

	assert_vector(_runner_of(course).course_heading).is_equal_approx(
		Vector3.RIGHT,
		Vector3.ONE * 0.001,
	)


func test_the_course_lays_sections_well_ahead_of_the_runner_from_the_start() -> void:
	var course := _course()
	scene_runner(course)

	var runner_along := _along(course, _runner_of(course).global_position)
	assert_float(_laid_end(course)).is_greater_equal(runner_along + course.keep_ahead)
	assert_float(course.keep_ahead).is_greater_equal(200.0)


func test_the_course_lays_a_section_ahead_as_the_runner_runs() -> void:
	var course := _course()
	var scene := scene_runner(course)
	var laid_at_start := _laid_end(course)

	# Held forward runs the Runner along the Course on its own.
	await scene.simulate_frames(120, 16)

	var runner_along := _along(course, _runner_of(course).global_position)
	assert_float(runner_along).is_greater(10.0)
	assert_float(_laid_end(course)).is_greater(laid_at_start)
	assert_float(_laid_end(course)).is_greater_equal(runner_along + course.keep_ahead)


func test_the_course_frees_sections_well_behind_the_runner() -> void:
	var course := _course()
	var scene := scene_runner(course)
	var start: Section = course.sections()[0]

	await _move_runner_on(scene, course, 120.0)

	var runner_along := _along(course, _runner_of(course).global_position)
	var first: Section = course.sections()[0]
	assert_bool(is_instance_valid(start)).is_false()
	# Every Section left is no further behind than keep_behind...
	assert_float(_along(course, first.global_position) + first.length).is_greater_equal(
		runner_along - course.keep_behind
	)
	# ...and those just behind the Runner are kept, well behind it.
	assert_float(course.keep_behind).is_greater_equal(30.0)
	assert_float(_along(course, first.global_position)).is_less(runner_along - 10.0)


## A flat Section scene [param length] long, of [param difficulty], packed in code.
func _flat_section(length: float, difficulty: int) -> PackedScene:
	var section := Section.new()
	section.length = length
	section.difficulty = difficulty
	var floor_box := CSGBox3D.new()
	floor_box.size = Vector3(Section.WIDTH, 1.0, length)
	floor_box.position = Vector3(0.0, -0.5, -length / 2.0)
	floor_box.use_collision = true
	section.add_child(floor_box)
	floor_box.owner = section
	var scene := PackedScene.new()
	scene.pack(section)
	section.free()
	return scene


## A list of Sections told apart by length: two of difficulty 1, one each of 2 and 3.
func _sections_of_every_difficulty() -> SectionList:
	var list := SectionList.new()
	list.sections = [
		_flat_section(10.0, 1),
		_flat_section(11.0, 1),
		_flat_section(12.0, 2),
		_flat_section(13.0, 3),
	]
	return list


## Every Section the Course lays, after its start Section, while the Runner moves on to
## [param distance]: [start along the Course, length, difficulty] for each, in order.
func _picked_while_moving_to(course: Course, distance: float) -> Array[Array]:
	var scene := scene_runner(course)
	var seen := { }
	while _along(course, _runner_of(course).global_position) < distance:
		for section: Section in course.sections():
			seen[section.get_instance_id()] = [
				_along(course, section.global_position),
				section.length,
				section.difficulty,
			]
		await _move_runner_on(scene, course, 20.0)
	var picked: Array[Array] = []
	for entry: Array in seen.values():
		picked.append(entry)
	picked.sort_custom(
		func(a: Array, b: Array) -> bool:
			return a[0] < b[0],
	)
	picked.pop_front()
	return picked


func test_harder_sections_are_only_picked_once_unlocked() -> void:
	var course := _course()
	course.section_list = _sections_of_every_difficulty()

	var picked := await _picked_while_moving_to(course, 1000.0)

	var difficulties_seen := { }
	for entry: Array in picked:
		var start: float = entry[0]
		var difficulty: int = entry[2]
		difficulties_seen[difficulty] = true
		if difficulty >= 2:
			assert_float(start).is_greater_equal(DIFFICULTY_2_UNLOCK)
		if difficulty >= 3:
			assert_float(start).is_greater_equal(DIFFICULTY_3_UNLOCK)
	assert_array(difficulties_seen.keys()).contains_exactly_in_any_order([1, 2, 3])


func test_the_same_section_never_comes_twice_in_a_row() -> void:
	var course := _course()
	course.section_list = _sections_of_every_difficulty()

	var picked := await _picked_while_moving_to(course, 1000.0)

	assert_int(picked.size()).is_greater(50)
	for index: int in range(1, picked.size()):
		var length: float = picked[index][1]
		var previous_length: float = picked[index - 1][1]
		assert_float(length).is_not_equal(previous_length)


func test_the_same_seed_lays_the_same_course() -> void:
	var first := _course()
	first.section_list = _sections_of_every_difficulty()
	var second := _course()
	second.section_list = first.section_list

	var first_picked := await _picked_while_moving_to(first, 500.0)
	var second_picked := await _picked_while_moving_to(second, 500.0)

	assert_array(second_picked).is_equal(first_picked)


func test_harder_sections_unlock_by_the_distance_from_where_the_runner_starts() -> void:
	var course := _course()
	course.runner_start = 25.0
	var list := SectionList.new()
	# Once both are unlocked, the no-repeat rule makes them take turns.
	list.sections = [_flat_section(10.0, 1), _flat_section(10.0, 2)]
	course.section_list = list

	var picked := await _picked_while_moving_to(course, 300.0)

	var first_hard := INF
	for entry: Array in picked:
		var difficulty: int = entry[2]
		if difficulty == 2:
			first_hard = minf(first_hard, entry[0] as float)
	# Sections start every 10 m from the 30 m start Section's end: the first difficulty 2 one at
	# the first start at least 150 m of Distance on, 175 m along the Course.
	assert_float(first_hard).is_equal_approx(180.0, 0.01)
