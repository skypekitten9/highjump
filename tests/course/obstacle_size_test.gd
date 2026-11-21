extends GdUnitTestSuite
## Every obstacle in the Sections the Course picks from can be cleared with the default tuning:
## its sizes, measured with rays as the Runner's body would meet them, are within the Runner's
## limits. Obstacles are found by their class, never by node name.

const CourseScene := preload("res://course/course.tscn")
## How far apart, across, the Sections are laid for probing, so none is found under another, m.
const SPACING := 20.0
## How far above and below floor height 0 the probes reach, m.
const PROBE_REACH := 20.0
## Height of the Runner's standing body, m.
const STANDING_HEIGHT := 1.8
## Radius of the Runner's body, m.
const RUNNER_RADIUS := 0.35
## How finely a Gap is probed along its length, m.
const GAP_PROBE_STEP := 0.05
## How far inside the Runner's feet and head a Wall-run's wall is looked for, m.
const WALL_PROBE_INSET := 0.1
## One physics frame at 60 Hz, s.
const DELTA := 1.0 / 60.0

var _tuning: RunnerTuning


func before_test() -> void:
	_tuning = load("res://runner/default_runner_tuning.tres")


## Every Section the Course picks from, laid side by side in one world, ready to probe.
func _lay_all() -> Array[Section]:
	var course: Course = auto_free(CourseScene.instantiate())
	var world: Node3D = auto_free(Node3D.new())
	var sections: Array[Section] = []
	for scene: PackedScene in course.section_list.sections:
		var section: Section = scene.instantiate()
		section.position.x = SPACING * sections.size()
		world.add_child(section)
		sections.append(section)
	await scene_runner(world).simulate_frames(2, 16)
	return sections


## Every obstacle of [param type] in [param sections].
func _obstacles(sections: Array[Section], type: Script) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for section: Section in sections:
		for node: Node in section.find_children("*", "", true, false):
			if is_instance_of(node, type):
				found.append(node as Node3D)
	return found


## The first hit of a ray from [param from] to [param to], or an empty Dictionary.
func _cast(node: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(from, to)
	return node.get_world_3d().direct_space_state.intersect_ray(ray)


## Height of the top of [param obstacle], probed straight down through its middle, m.
func _top(obstacle: Node3D) -> float:
	var middle := obstacle.global_position
	var hit := _cast(obstacle, middle + Vector3.UP * PROBE_REACH, middle + Vector3.DOWN * 0.01)
	assert_bool(hit.is_empty()).override_failure_message("%s has no top" % obstacle).is_false()
	return (hit.get("position", Vector3.ZERO) as Vector3).y


## Height of the underside of [param obstacle], probed straight up through its middle from the
## floor, m.
func _bottom(obstacle: Node3D) -> float:
	var under := Vector3(obstacle.global_position.x, 0.01, obstacle.global_position.z)
	var hit := _cast(obstacle, under, under + Vector3.UP * PROBE_REACH)
	var message := "%s has no underside" % obstacle
	assert_bool(hit.is_empty()).override_failure_message(message).is_false()
	return (hit.get("position", Vector3.ZERO) as Vector3).y


## Height of the floor at [param point], or NAN if there is none, m.
func _floor_height(node: Node3D, point: Vector3) -> float:
	var top := Vector3(point.x, PROBE_REACH, point.z)
	var hit := _cast(node, top, Vector3(point.x, -PROBE_REACH, point.z))
	if hit.is_empty():
		return NAN
	return (hit["position"] as Vector3).y


## How far [param gap] runs with no floor, from its marker at its near edge along the Course to
## the first floor beyond, probed down the middle, m. Never short, and at
## most a probe step long; a probe step if there is floor straight after the marker.
func _gap_length(gap: Node3D) -> float:
	var ahead := -gap.global_basis.z
	var along := GAP_PROBE_STEP
	while along < PROBE_REACH:
		if not is_nan(_floor_height(gap, gap.global_position + ahead * along)):
			return along
		along += GAP_PROBE_STEP
	return INF


## How far a jump from the floor carries at [param speed] before landing back at the same height,
## with the default tuning, m.
func _jump_distance(speed: float) -> float:
	var launch := sqrt(2.0 * _tuning.gravity * _tuning.jump_height)
	return speed * 2.0 * launch / _tuning.gravity


## Which side of [param point] a near-vertical wall is within the Section's half width: -1 to the
## left, 1 to the right, 0 if none. Looks only on [param side] if it isn't 0.
func _wall_side(node: Node3D, point: Vector3, side: float) -> float:
	var across := node.global_basis.x
	for look: float in [-1.0, 1.0]:
		if side != 0.0 and look != side:
			continue
		var hit := _cast(node, point, point + across * look * Section.WIDTH / 2.0)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit["normal"]
		if absf(normal.y) <= sin(deg_to_rad(_tuning.wall_max_tilt)):
			return look
	return 0.0


## The speed a Slide begun at Run speed reaches, with its Slide boost, m/s.
func _slide_speed() -> float:
	return minf(_tuning.run_speed + _tuning.slide_boost, _tuning.top_slide_speed)


## How wide a Gap a jump from the floor at [param speed] can still end in a Mantle onto the far
## edge, with the default tuning, m: the jump carries until it falls out of Mantle reach of the
## take-off height, and the body adds its own size, leaving with its middle a body radius past
## the near edge and finding the far face a body radius and the ledge probe ahead of its middle.
func _jump_to_mantle_distance(speed: float) -> float:
	var launch := sqrt(2.0 * _tuning.gravity * _tuning.jump_height)
	var fall := sqrt(launch * launch + 2.0 * _tuning.gravity * _tuning.mantle_reach)
	var body := 2.0 * RUNNER_RADIUS + _tuning.ledge_probe_ahead
	return speed * (launch + fall) / _tuning.gravity + body


## The jump's peak above take-off with the default tuning, m.
func _jump_height() -> float:
	return _tuning.jump_height


func _named(obstacle: Node3D) -> String:
	return "%s in %s" % [obstacle.name, obstacle.owner.scene_file_path]


func test_each_hurdle_is_below_jump_height() -> void:
	var hurdles := _obstacles(await _lay_all(), Hurdle)
	assert_int(hurdles.size()).is_greater_equal(1)
	for hurdle: Node3D in hurdles:
		var message := "%s is not below jump height" % _named(hurdle)
		assert_float(_top(hurdle)).override_failure_message(message).is_less(_jump_height())


func test_each_block_is_above_jump_height_and_within_mantle_reach_of_it() -> void:
	var blocks := _obstacles(await _lay_all(), Block)
	assert_int(blocks.size()).is_greater_equal(1)
	for block: Node3D in blocks:
		var top := _top(block)
		var low := "%s is not above jump height" % _named(block)
		assert_float(top).override_failure_message(low).is_greater(_jump_height())
		var high := "%s is beyond Mantle reach of jump height" % _named(block)
		var reach := _jump_height() + _tuning.mantle_reach
		assert_float(top).override_failure_message(high).is_less_equal(reach)


func test_each_overhead_bar_is_above_crouch_height_and_below_standing_height() -> void:
	var bars := _obstacles(await _lay_all(), OverheadBar)
	assert_int(bars.size()).is_greater_equal(1)
	for bar: Node3D in bars:
		var bottom := _bottom(bar)
		var low := "%s is not above Crouch height" % _named(bar)
		assert_float(bottom).override_failure_message(low).is_greater(_tuning.crouch_height)
		var high := "%s is not below standing height" % _named(bar)
		assert_float(bottom).override_failure_message(high).is_less(STANDING_HEIGHT)


func test_no_overhead_bar_can_be_mantled_over_instead() -> void:
	var bars := _obstacles(await _lay_all(), OverheadBar)
	for bar: Node3D in bars:
		var message := "%s is within Mantle reach of jump height" % _named(bar)
		var reach := _jump_height() + _tuning.mantle_reach
		assert_float(_top(bar)).override_failure_message(message).is_greater(reach)


func test_each_gap_has_floor_at_0_right_up_to_both_of_its_edges() -> void:
	var gaps := _obstacles(await _lay_all(), Gap)
	assert_int(gaps.size()).is_greater_equal(1)
	for gap: Node3D in gaps:
		var length := _gap_length(gap)
		var open := "%s has floor at its marker" % _named(gap)
		assert_float(length).override_failure_message(open).is_greater(GAP_PROBE_STEP * 1.5)
		var ahead := -gap.global_basis.z
		for along: float in [-GAP_PROBE_STEP, length]:
			var height := _floor_height(gap, gap.global_position + ahead * along)
			var message := "%s has no floor at 0, %.2f m along it" % [_named(gap), along]
			assert_float(height).override_failure_message(message).is_equal_approx(0.0, 0.001)


func test_each_short_gap_is_within_a_jump_at_run_speed() -> void:
	for gap: Node3D in _obstacles(await _lay_all(), Gap):
		if (gap as Gap).size != Gap.Size.SHORT:
			continue
		var message := "%s is beyond a jump at Run speed" % _named(gap)
		var reach := _jump_distance(_tuning.run_speed)
		assert_float(_gap_length(gap)).override_failure_message(message).is_less_equal(reach)


func test_each_long_gap_is_beyond_a_jump_at_run_speed_but_within_one_at_slide_speed() -> void:
	var longs: Array[Node3D] = []
	for gap: Node3D in _obstacles(await _lay_all(), Gap):
		if (gap as Gap).size == Gap.Size.LONG:
			longs.append(gap)
	assert_int(longs.size()).is_greater_equal(1)
	for gap: Node3D in longs:
		var length := _gap_length(gap)
		var short := "%s is within a jump at Run speed" % _named(gap)
		var run_reach := _jump_distance(_tuning.run_speed)
		assert_float(length).override_failure_message(short).is_greater(run_reach)
		var far := "%s is beyond a jump at the speed a Slide reaches" % _named(gap)
		var slide_reach := _jump_distance(_slide_speed())
		assert_float(length).override_failure_message(far).is_less_equal(slide_reach)


func test_each_wall_run_gap_is_beyond_a_jump_at_run_speed_even_one_ending_in_a_mantle() -> void:
	var gaps := _obstacles(await _lay_all(), WallRunGap)
	assert_int(gaps.size()).is_greater_equal(2)
	var jump := _jump_distance(_tuning.run_speed)
	var jump_to_mantle := _jump_to_mantle_distance(_tuning.run_speed)
	for gap: Node3D in gaps:
		var length := _gap_length(gap)
		var short := "%s is within a jump at Run speed" % _named(gap)
		assert_float(length).override_failure_message(short).is_greater(jump)
		var mantled := "%s is within a jump at Run speed that ends in a Mantle" % _named(gap)
		assert_float(length).override_failure_message(mantled).is_greater(jump_to_mantle)


func test_each_wall_run_gap_has_a_wall_to_wall_run_across_it_at_wall_run_entry_speed() -> void:
	for gap: Node3D in _obstacles(await _lay_all(), WallRunGap):
		var trouble := _wall_run_across(gap)
		var message := "%s: %s" % [_named(gap), trouble]
		assert_str(trouble).override_failure_message(message).is_empty()


## Follows a Wall-run across [param gap] at the Wall-run entry speed, begun by a jump at its near
## edge: the Runner's body follows the Wall-run's arc and slowdown with the default tuning. It
## must keep a near-vertical wall on the same side, from its feet to its head, until it is over
## the floor beyond, without slowing enough to end the Wall-run, and get there with the floor's
## edge within Mantle reach. Returns what went wrong, or an empty String.
func _wall_run_across(gap: Node3D) -> String:
	var length := _gap_length(gap)
	var ahead := -gap.global_basis.z
	var wall_gravity := _tuning.gravity * _tuning.wall_run_gravity_scale
	var speed := _tuning.wall_run_entry_speed
	var rise := sqrt(2.0 * _tuning.gravity * _tuning.jump_height)
	var along := 0.0
	var feet := 0.0
	var side := 0.0
	while along < length:
		var middle := gap.global_position + ahead * along
		var body: Array[float] = [WALL_PROBE_INSET, STANDING_HEIGHT - WALL_PROBE_INSET]
		for height: float in body:
			side = _wall_side(gap, middle + Vector3.UP * (feet + height), side)
			if side == 0.0:
				return "no wall %.1f m along at %.1f m up" % [along, feet + height]
		speed -= _tuning.wall_run_slowdown * DELTA
		if speed < _tuning.wall_run_end_speed:
			return "the Wall-run slows to its end %.1f m along" % along
		rise -= wall_gravity * DELTA
		feet += rise * DELTA
		along += speed * DELTA
	if feet < -_tuning.mantle_reach:
		return "the floor beyond is out of Mantle reach"
	return ""
