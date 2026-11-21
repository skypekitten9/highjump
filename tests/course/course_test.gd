extends GdUnitTestSuite
## The Course begins with its flat start Section under a still Runner, sets the Runner's Course
## heading, keeps Sections laid ahead of the Runner and frees those well behind it, and picks
## them at random, a difficulty first, by the unlock and no-repeat rules.

const CourseScene := preload("res://course/course.tscn")
const START_SECTION := "res://course/sections/start.tscn"
const SEED := 4711
## Where these tests' Courses save the Best distance, so the Player's own is never touched.
const SAVE_PATH := "user://course_test.save"
## The Distance each difficulty unlocks at with the default tuning, m.
const DIFFICULTY_UNLOCKS: Dictionary[int, float] = { 2: 50.0, 3: 120.0, 4: 200.0, 5: 300.0 }


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


## A list of Sections told apart by length: two of difficulty 1, one each of 2 to 5.
func _sections_of_every_difficulty() -> SectionList:
	var list := SectionList.new()
	list.sections = [
		_flat_section(10.0, 1),
		_flat_section(11.0, 1),
		_flat_section(12.0, 2),
		_flat_section(13.0, 3),
		_flat_section(14.0, 4),
		_flat_section(15.0, 5),
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
			assert_float(start).is_greater_equal(DIFFICULTY_UNLOCKS[difficulty])
	assert_array(difficulties_seen.keys()).contains_exactly_in_any_order([1, 2, 3, 4, 5])


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


## Where the first Section of [param difficulty] starts along [param course], m, when it picks
## from two 10 m Sections, one of difficulty 1 and one of [param difficulty]: INF if none comes.
## Once both are unlocked, the no-repeat rule makes them take turns, so the first comes at the
## first start where it is unlocked.
func _first_start_of(course: Course, difficulty: int, distance: float) -> float:
	var list := SectionList.new()
	list.sections = [_flat_section(10.0, 1), _flat_section(10.0, difficulty)]
	course.section_list = list
	var first := INF
	for entry: Array in await _picked_while_moving_to(course, distance):
		if entry[2] == difficulty:
			first = minf(first, entry[0] as float)
	return first


func test_harder_sections_unlock_by_the_distance_from_where_the_runner_starts() -> void:
	# Sections start every 10 m from the 30 m start Section's end, and the Distance starts 25 m
	# along the Course: each difficulty comes first at the first start at least its unlock on.
	var expected: Dictionary[int, float] = { 2: 80.0, 3: 150.0, 4: 230.0, 5: 330.0 }
	for difficulty: int in expected:
		var course := _course()
		course.runner_start = 25.0
		var first := await _first_start_of(course, difficulty, expected[difficulty] + 20.0)
		var message := "difficulty %d first came at %.1f m" % [difficulty, first]
		var want := expected[difficulty]
		assert_float(first).override_failure_message(message).is_equal_approx(want, 0.01)


func test_each_difficulty_unlocks_at_the_distance_set_on_the_course() -> void:
	var expected: Dictionary[int, float] = { 2: 120.0, 3: 100.0, 4: 60.0, 5: 40.0 }
	for difficulty: int in expected:
		var course := _course()
		course.runner_start = 25.0
		course.difficulty_2_unlock = 90.0
		course.difficulty_3_unlock = 70.0
		course.difficulty_4_unlock = 30.0
		course.difficulty_5_unlock = 10.0
		var first := await _first_start_of(course, difficulty, 150.0)
		var message := "difficulty %d first came at %.1f m" % [difficulty, first]
		var want := expected[difficulty]
		assert_float(first).override_failure_message(message).is_equal_approx(want, 0.01)


## A Course with every difficulty unlocked from the start, picking from [param sections].
func _course_unlocked_from_the_start(sections: Array[PackedScene]) -> Course:
	var course := _course()
	course.difficulty_2_unlock = 0.0
	course.difficulty_3_unlock = 0.0
	course.difficulty_4_unlock = 0.0
	course.difficulty_5_unlock = 0.0
	var list := SectionList.new()
	list.sections = sections
	course.section_list = list
	return course


## The share of [param picked] that is of [param difficulty], from 0 to 1.
func _share_of(picked: Array[Array], difficulty: int) -> float:
	var count := 0
	for entry: Array in picked:
		if entry[2] == difficulty:
			count += 1
	return float(count) / picked.size()


func test_each_unlocked_difficulty_is_picked_equally_often_whatever_its_section_count() -> void:
	# Four Sections of difficulty 1, only two of difficulty 2: picking among the Sections would
	# give difficulty 2 about a third of the picks.
	var course := _course_unlocked_from_the_start(
		[
			_flat_section(10.0, 1),
			_flat_section(10.0, 1),
			_flat_section(10.0, 1),
			_flat_section(10.0, 1),
			_flat_section(10.0, 2),
			_flat_section(10.0, 2),
		]
	)

	var picked := await _picked_while_moving_to(course, 2000.0)

	assert_int(picked.size()).is_greater(150)
	assert_float(_share_of(picked, 2)).is_between(0.42, 0.58)


func test_a_difficulty_with_no_sections_is_never_picked_and_leaves_no_hole() -> void:
	# Nothing of difficulty 2, 4 or 5: difficulties 1 and 3 share the picks between them.
	var course := _course_unlocked_from_the_start(
		[
			_flat_section(10.0, 1),
			_flat_section(10.0, 1),
			_flat_section(10.0, 3),
			_flat_section(10.0, 3),
		]
	)

	var picked := await _picked_while_moving_to(course, 2000.0)

	assert_int(picked.size()).is_greater(150)
	assert_float(_share_of(picked, 3)).is_between(0.42, 0.58)
	for index: int in range(1, picked.size()):
		var start: float = picked[index][0]
		var previous_end: float = picked[index - 1][0] + picked[index - 1][1]
		assert_float(start).is_equal_approx(previous_end, 0.01)
