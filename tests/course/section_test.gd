extends GdUnitTestSuite
## Every Section the Course can lay, the start Section among them, is 8 m wide with open edges,
## starts and ends at floor height 0, and declares its length and a difficulty from 1 to 5.

const CourseScene := preload("res://course/course.tscn")
## Half the width every Section has, m.
const HALF_WIDTH := 4.0
## How far inside or outside an edge the floor is probed, m.
const EDGE_PROBE := 0.1
## How far above and below floor height 0 the probes reach, m.
const PROBE_REACH := 20.0
## How far apart, across, the Sections are laid for probing, so none is found under another, m.
const SPACING := 20.0


## Every Section scene the Course knows: its start Section, then those it picks from.
func _all_section_scenes() -> Array[PackedScene]:
	var course: Course = auto_free(CourseScene.instantiate())
	var scenes: Array[PackedScene] = [course.start_section]
	scenes.append_array(course.section_list.sections)
	return scenes


## Every Section the Course knows, laid side by side in one world, ready to probe.
func _lay_all() -> Array[Section]:
	var world: Node3D = auto_free(Node3D.new())
	var sections: Array[Section] = []
	for scene: PackedScene in _all_section_scenes():
		var section: Section = scene.instantiate()
		section.position.x = SPACING * sections.size()
		world.add_child(section)
		sections.append(section)
	await scene_runner(world).simulate_frames(2, 16)
	return sections


## Height of the floor [param across] the Section from its middle and [param along] it from its
## start, or NAN if there is none.
func _floor_height(section: Section, across: float, along: float) -> float:
	var point := section.global_position + Vector3(across, 0.0, -along)
	var top := point + Vector3.UP * PROBE_REACH
	var ray := PhysicsRayQueryParameters3D.create(top, point + Vector3.DOWN * PROBE_REACH)
	var hit := section.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return NAN
	return (hit["position"] as Vector3).y


func _assert_floor_at_0(section: Section, across: float, along: float) -> void:
	var height := _floor_height(section, across, along)
	var message := "%s has no floor at height 0" % _where(section, across, along)
	assert_float(height).override_failure_message(message).is_equal_approx(0.0, 0.001)


func _assert_nothing_at(section: Section, across: float, along: float) -> void:
	var empty := is_nan(_floor_height(section, across, along))
	var message := "%s has something there" % _where(section, across, along)
	assert_bool(empty).override_failure_message(message).is_true()


func _where(section: Section, across: float, along: float) -> String:
	return "%s, %.1f m across, %.1f m along," % [section.scene_file_path, across, along]


func test_the_course_knows_a_start_section_and_sections_to_pick() -> void:
	assert_int(_all_section_scenes().size()).is_greater_equal(2)


func test_the_course_picks_four_sections_each_of_difficulty_1_and_4_three_each_of_2_and_3() -> void:
	var course: Course = auto_free(CourseScene.instantiate())
	var counts: Dictionary[int, int] = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 }
	for scene: PackedScene in course.section_list.sections:
		var section: Section = auto_free(scene.instantiate())
		counts[section.difficulty] += 1
	assert_dict(counts).is_equal({ 1: 4, 2: 3, 3: 3, 4: 4, 5: 0 })


func test_every_section_declares_a_length_and_a_difficulty_from_1_to_5() -> void:
	for scene: PackedScene in _all_section_scenes():
		var section: Section = auto_free(scene.instantiate())
		assert_float(section.length).is_greater(0.0)
		assert_int(section.difficulty).is_between(1, 5)


func test_a_section_can_be_of_any_difficulty_from_1_to_5_and_no_other() -> void:
	var section: Section = auto_free(Section.new())
	for difficulty: int in range(1, 6):
		section.difficulty = difficulty
		assert_int(section.difficulty).is_equal(difficulty)
	section.difficulty = 6
	assert_int(section.difficulty).is_equal(5)
	section.difficulty = 0
	assert_int(section.difficulty).is_equal(1)


func test_every_section_starts_and_ends_at_floor_height_0() -> void:
	var sections: Array[Section] = await _lay_all()
	for section: Section in sections:
		_assert_floor_at_0(section, 0.0, EDGE_PROBE)
		_assert_floor_at_0(section, 0.0, section.length - EDGE_PROBE)


func test_every_section_ends_at_its_length() -> void:
	var sections: Array[Section] = await _lay_all()
	for section: Section in sections:
		_assert_nothing_at(section, 0.0, -EDGE_PROBE)
		_assert_nothing_at(section, 0.0, section.length + EDGE_PROBE)


func test_every_section_is_8_m_wide_with_open_edges() -> void:
	var sections: Array[Section] = await _lay_all()
	for section: Section in sections:
		for side: float in [-1.0, 1.0]:
			# Near each end, since obstacles and Gaps fill the middle.
			for along: float in [EDGE_PROBE, section.length - EDGE_PROBE]:
				_assert_floor_at_0(section, side * (HALF_WIDTH - EDGE_PROBE), along)
			var outside := side * (HALF_WIDTH + EDGE_PROBE)
			for along: float in [EDGE_PROBE, section.length / 2.0, section.length - EDGE_PROBE]:
				_assert_nothing_at(section, outside, along)
