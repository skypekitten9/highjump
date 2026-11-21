extends GdUnitTestSuite
## Every obstacle in the Sections the Course picks from can be cleared with the default tuning:
## its sizes, measured with rays as the Runner's body would meet them, are within the Runner's
## limits. Obstacles are found by their class, never by node name.

const CourseScene := preload("res://course/course.tscn")
## How far apart, across, the Sections are laid for probing, so none is found under another, m.
const SPACING := 20.0
## How far above and below floor height 0, and along a Gap, the probes reach, m.
const PROBE_REACH := 30.0
## How many walls a Wall-jump gap has, so that crossing it takes three Wall-jumps.
const WALL_JUMP_GAP_WALLS := 4
## Height of the Runner's standing body, m.
const STANDING_HEIGHT := 1.8
## Radius of the Runner's body, m.
const RUNNER_RADIUS := 0.35
## How finely a Gap is probed along its length, m.
const GAP_PROBE_STEP := 0.05
## How finely a Slope is probed along its length, m.
const SLOPE_PROBE_STEP := 0.1
## How much the floor must rise over a Slope probe step to count as still part of the Slope, m.
const SLOPE_RISE_MIN := 0.001
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


## How far a jump from the floor carries at [param speed] before landing [param drop] m below
## its take-off, with the default tuning, m.
func _jump_distance(speed: float, drop := 0.0) -> float:
	var launch := sqrt(2.0 * _tuning.gravity * _tuning.jump_height)
	var fall := sqrt(launch * launch + 2.0 * _tuning.gravity * drop)
	return speed * (launch + fall) / _tuning.gravity


## How wide a Gap a jump from the floor at [param speed] lands across, at the same height, with
## the default tuning, m: the jump carries the body's middle [method _jump_distance], and the
## body adds its own size, leaving the floor with its middle a body radius past the near edge
## and landing with it a body radius short of the far one.
func _landed_jump_distance(speed: float) -> float:
	return _jump_distance(speed) + 2.0 * RUNNER_RADIUS


## The Gaps of [param size] in [param sections].
func _gaps_of_size(sections: Array[Section], size: Gap.Size) -> Array[Node3D]:
	return _obstacles(sections, Gap).filter(
		func(gap: Node3D) -> bool:
			return (gap as Gap).size == size,
	)


## What the floor at [param point] is part of, or null if there is none.
func _floor_under(node: Node3D, point: Vector3) -> Object:
	var top := Vector3(point.x, PROBE_REACH, point.z)
	var hit := _cast(node, top, Vector3(point.x, -PROBE_REACH, point.z))
	return hit.get("collider") as Object


## The speed a Slide reaches at [param gap]'s near edge, begun at Run speed, with its Slide
## boost, at the top of the floor rising back from the edge, and held all the way down, with the
## default tuning, m/s. Down each probe step the floor's slope adds speed and slide friction
## takes it away, as they do to a Slide along the ground.
func _slide_speed_down_slope(gap: Node3D) -> float:
	var behind := gap.global_basis.z
	var heights: Array[float] = [
		_floor_height(gap, gap.global_position + behind * SLOPE_PROBE_STEP)
	]
	while true:
		var along := SLOPE_PROBE_STEP * (heights.size() + 1)
		var height := _floor_height(gap, gap.global_position + behind * along)
		if not height > heights[heights.size() - 1] + SLOPE_RISE_MIN:
			break
		heights.append(height)
	heights.reverse()
	var speed := _slide_speed()
	for i: int in range(1, heights.size()):
		var angle := atan2(heights[i - 1] - heights[i], SLOPE_PROBE_STEP)
		var gain := _tuning.gravity * _tuning.slope_gain * sin(angle) * cos(angle)
		var friction := _tuning.slide_friction
		if speed < _tuning.run_speed:
			friction = _tuning.slow_slide_friction
		var squared := speed * speed + 2.0 * (gain - friction) * SLOPE_PROBE_STEP
		speed = minf(sqrt(maxf(squared, 0.0)), _tuning.top_slide_speed)
	return speed


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
## edge, [param rise] m above the take-off, with the default tuning, m: the jump carries until it
## falls out of Mantle reach of the far edge, and the body adds its own size, leaving with its
## middle a body radius past the near edge and finding the far face a body radius and the ledge
## probe ahead of its middle. 0 if the far edge is beyond Mantle reach of the jump's peak.
func _jump_to_mantle_distance(speed: float, rise := 0.0) -> float:
	var launch := sqrt(2.0 * _tuning.gravity * _tuning.jump_height)
	var room := launch * launch + 2.0 * _tuning.gravity * (_tuning.mantle_reach - rise)
	if room < 0.0:
		return 0.0
	var fall := sqrt(room)
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
	var blocks := _obstacles(await _lay_all(), Block).filter(
		func(block: Node3D) -> bool:
			return not (block as Block).from_wall_run,
	)
	assert_int(blocks.size()).is_greater_equal(1)
	for block: Node3D in blocks:
		var top := _top(block)
		var low := "%s is not above jump height" % _named(block)
		assert_float(top).override_failure_message(low).is_greater(_jump_height())
		var high := "%s is beyond Mantle reach of jump height" % _named(block)
		var reach := _jump_height() + _tuning.mantle_reach
		assert_float(top).override_failure_message(high).is_less_equal(reach)


func test_each_block_reached_from_a_wall_run_is_beyond_mantle_reach_of_jump_height() -> void:
	var blocks := _obstacles(await _lay_all(), Block).filter(
		func(block: Node3D) -> bool:
			return (block as Block).from_wall_run,
	)
	assert_int(blocks.size()).is_greater_equal(1)
	for block: Node3D in blocks:
		var message := "%s is within Mantle reach of jump height" % _named(block)
		var reach := _jump_height() + _tuning.mantle_reach
		assert_float(_top(block)).override_failure_message(message).is_greater(reach)


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


func test_each_gap_has_floor_up_to_both_edges_landing_no_higher_than_it_takes_off() -> void:
	var sections := await _lay_all()
	var gaps := _obstacles(sections, Gap)
	gaps.append_array(_obstacles(sections, WallJumpGap))
	assert_int(gaps.size()).is_greater_equal(1)
	for gap: Node3D in gaps:
		var length := _gap_length(gap)
		var open := "%s has floor at its marker" % _named(gap)
		assert_float(length).override_failure_message(open).is_greater(GAP_PROBE_STEP * 1.5)
		var take_off := gap.global_position.y
		var before := gap.global_position + gap.global_basis.z * GAP_PROBE_STEP
		# A Slope running down to the edge rises at most a probe step over a probe step.
		var not_near := "%s has no floor at its marker's height before it" % _named(gap)
		assert_float(_floor_height(gap, before)).override_failure_message(not_near).is_equal_approx(
			take_off,
			GAP_PROBE_STEP,
		)
		var far := _floor_height(gap, gap.global_position - gap.global_basis.z * length)
		var higher := "%s lands higher than it takes off" % _named(gap)
		assert_float(far).override_failure_message(higher).is_less_equal(take_off + 0.001)


func test_each_short_gap_is_within_a_jump_at_run_speed() -> void:
	for gap: Node3D in _gaps_of_size(await _lay_all(), Gap.Size.SHORT):
		var message := "%s is beyond a jump at Run speed" % _named(gap)
		var reach := _jump_distance(_tuning.run_speed)
		assert_float(_gap_length(gap)).override_failure_message(message).is_less_equal(reach)


func test_each_long_gap_is_beyond_a_jump_at_run_speed_but_within_one_at_slide_speed() -> void:
	var longs := _gaps_of_size(await _lay_all(), Gap.Size.LONG)
	assert_int(longs.size()).is_greater_equal(1)
	for gap: Node3D in longs:
		var length := _gap_length(gap)
		var drop := -_rise_beyond(gap)
		var short := "%s is within a jump at Run speed" % _named(gap)
		var run_reach := _jump_distance(_tuning.run_speed, drop)
		assert_float(length).override_failure_message(short).is_greater(run_reach)
		var far := "%s is beyond a jump at the speed a Slide reaches" % _named(gap)
		var slide_reach := _jump_distance(_slide_speed(), drop)
		assert_float(length).override_failure_message(far).is_less_equal(slide_reach)


func test_some_long_gap_takes_off_higher_than_it_lands() -> void:
	var dropping := _gaps_of_size(await _lay_all(), Gap.Size.LONG).filter(
		func(gap: Node3D) -> bool:
			return _rise_beyond(gap) < -GAP_PROBE_STEP,
	)
	assert_int(dropping.size()).is_greater_equal(1)


func test_each_wide_gap_has_a_slope_running_right_to_its_near_edge_at_floor_height_0() -> void:
	var wides := _gaps_of_size(await _lay_all(), Gap.Size.WIDE)
	assert_int(wides.size()).is_greater_equal(1)
	for gap: Node3D in wides:
		var edge := "%s is not at floor height 0" % _named(gap)
		assert_float(gap.global_position.y).override_failure_message(edge).is_equal_approx(
			0.0,
			0.001,
		)
		var before := gap.global_position + gap.global_basis.z * GAP_PROBE_STEP
		var slope := "%s has no Slope running down to its near edge" % _named(gap)
		assert_bool(_floor_under(gap, before) is Slope).override_failure_message(slope).is_true()
		assert_float(_floor_height(gap, before)).override_failure_message(slope).is_greater(0.0)


func test_each_wide_gap_is_beyond_a_jump_at_the_speed_a_slide_begins_with() -> void:
	var wides := _gaps_of_size(await _lay_all(), Gap.Size.WIDE)
	assert_int(wides.size()).is_greater_equal(1)
	for gap: Node3D in wides:
		var message := "%s is within a jump at the speed a Slide begins with" % _named(gap)
		var reach := _landed_jump_distance(_slide_speed())
		assert_float(_gap_length(gap)).override_failure_message(message).is_greater(reach)


func test_each_wide_gap_is_within_a_jump_at_the_speed_a_slide_reaches_down_its_slope() -> void:
	var wides := _gaps_of_size(await _lay_all(), Gap.Size.WIDE)
	assert_int(wides.size()).is_greater_equal(1)
	for gap: Node3D in wides:
		var message := "%s is beyond a jump at the speed a Slide reaches down its Slope" % [
			_named(gap),
		]
		var reach := _landed_jump_distance(_slide_speed_down_slope(gap))
		assert_float(_gap_length(gap)).override_failure_message(message).is_less(reach)


func test_the_floor_beyond_each_wide_gap_reaches_a_jump_at_top_slide_speed() -> void:
	var wides := _gaps_of_size(await _lay_all(), Gap.Size.WIDE)
	assert_int(wides.size()).is_greater_equal(1)
	for gap: Node3D in wides:
		var ahead := -gap.global_basis.z
		var along := _gap_length(gap)
		while along <= _jump_distance(_tuning.top_slide_speed):
			var message := "%s has no floor beyond it %.1f m along" % [_named(gap), along]
			var height := _floor_height(gap, gap.global_position + ahead * along)
			assert_bool(is_nan(height)).override_failure_message(message).is_false()
			along += SLOPE_PROBE_STEP


func test_each_wall_run_gap_is_beyond_a_jump_at_run_speed_even_one_ending_in_a_mantle() -> void:
	var gaps := _obstacles(await _lay_all(), WallRunGap)
	assert_int(gaps.size()).is_greater_equal(2)
	var jump := _jump_distance(_tuning.run_speed)
	for gap: Node3D in gaps:
		var length := _gap_length(gap)
		var jump_to_mantle := _jump_to_mantle_distance(_tuning.run_speed, _rise_beyond(gap))
		var short := "%s is within a jump at Run speed" % _named(gap)
		assert_float(length).override_failure_message(short).is_greater(jump)
		var mantled := "%s is within a jump at Run speed that ends in a Mantle" % _named(gap)
		assert_float(length).override_failure_message(mantled).is_greater(jump_to_mantle)


func test_each_wall_run_gap_has_a_wall_to_wall_run_across_it_at_wall_run_entry_speed() -> void:
	for gap: Node3D in _obstacles(await _lay_all(), WallRunGap):
		var trouble := _wall_run_across(gap)
		var message := "%s: %s" % [_named(gap), trouble]
		assert_str(trouble).override_failure_message(message).is_empty()


func test_each_wall_jump_gap_has_four_walls_on_alternating_sides_overlapping_along_it() -> void:
	var gaps := _obstacles(await _lay_all(), WallJumpGap)
	assert_int(gaps.size()).is_greater_equal(1)
	for gap: Node3D in gaps:
		var walls := _walls_along(gap)
		var count := "%s has %d walls" % [_named(gap), walls.size()]
		assert_int(walls.size()).override_failure_message(count).is_equal(WALL_JUMP_GAP_WALLS)
		for i: int in range(1, walls.size()):
			var same := "%s has walls %d and %d on the same side" % [_named(gap), i, i + 1]
			assert_float(walls[i].x).override_failure_message(same).is_not_equal(walls[i - 1].x)
			var apart := "%s has wall %d start after wall %d ends" % [_named(gap), i + 1, i]
			assert_float(walls[i].y).override_failure_message(apart).is_less(walls[i - 1].z)


func test_no_wall_of_a_wall_jump_gap_is_long_enough_to_cross_it_on_one_wall_run() -> void:
	for gap: Node3D in _obstacles(await _lay_all(), WallJumpGap):
		var length := _gap_length(gap)
		var jump := _jump_distance(_tuning.run_speed)
		var walls := _walls_along(gap)
		for i: int in walls.size():
			var message := "%s: wall %d and a jump at Run speed off its end span the Gap" % [
				_named(gap),
				i + 1,
			]
			var reach := walls[i].z - walls[i].y + jump
			assert_float(reach).override_failure_message(message).is_less(length)


func test_each_chimney_has_floor_into_it_then_a_gap_under_it_up_to_its_platform() -> void:
	var chimneys := _obstacles(await _lay_all(), Chimney)
	assert_int(chimneys.size()).is_greater_equal(1)
	for chimney: Node3D in chimneys:
		var shape := _chimney_shape(chimney)
		var no_floor := "%s has no floor running into it" % _named(chimney)
		assert_float(shape.x).override_failure_message(no_floor).is_greater(GAP_PROBE_STEP * 1.5)
		var no_gap := "%s has no Gap under it beyond its floor" % _named(chimney)
		assert_float(shape.y - shape.x).override_failure_message(no_gap).is_greater(
			GAP_PROBE_STEP * 1.5,
		)
		var no_platform := "%s has no platform at its end" % _named(chimney)
		assert_bool(is_finite(shape.y)).override_failure_message(no_platform).is_true()


func test_each_chimney_ends_at_a_platform_beyond_mantle_reach_of_jump_height() -> void:
	var chimneys := _obstacles(await _lay_all(), Chimney)
	assert_int(chimneys.size()).is_greater_equal(1)
	for chimney: Node3D in chimneys:
		var message := "%s ends at a platform within Mantle reach of jump height" % _named(chimney)
		var reach := _jump_height() + _tuning.mantle_reach
		assert_float(_chimney_shape(chimney).z).override_failure_message(message).is_greater(reach)


func test_each_chimney_is_narrow_enough_that_a_wall_jump_reaches_the_far_wall_rising() -> void:
	var chimneys := _obstacles(await _lay_all(), Chimney)
	assert_int(chimneys.size()).is_greater_equal(1)
	var launch := sqrt(2.0 * _tuning.gravity * _tuning.jump_height)
	for chimney: Node3D in chimneys:
		var width := _chimney_width(chimney)
		var crossing := (width - 2.0 * RUNNER_RADIUS) / _tuning.wall_jump_push
		var message := "%s is %.2f m wide: a Wall-jump reaches the far wall falling" % [
			_named(chimney),
			width,
		]
		var rising := launch - _tuning.gravity * crossing
		assert_float(rising).override_failure_message(message).is_greater(0.0)


## The shape of [param chimney] down its middle from its marker, m: how far its floor runs into
## it, where the floor resumes at its platform (INF if it never does), and how high the platform
## is above the marker.
func _chimney_shape(chimney: Node3D) -> Vector3:
	var ahead := -chimney.global_basis.z
	var along := 0.0
	while not is_nan(_floor_height(chimney, chimney.global_position + ahead * along)):
		along += GAP_PROBE_STEP
		if along >= PROBE_REACH:
			return Vector3(along, INF, NAN)
	var floor_end := along
	while along < PROBE_REACH:
		var height := _floor_height(chimney, chimney.global_position + ahead * along)
		if not is_nan(height):
			return Vector3(floor_end, along, height - chimney.global_position.y)
		along += GAP_PROBE_STEP
	return Vector3(floor_end, INF, NAN)


## The widest [param chimney] gets between its two walls, probed across its middle from just past
## its marker to its platform, from the Runner's middle height up to the platform's top, m. INF
## where a wall is missing on either side.
func _chimney_width(chimney: Node3D) -> float:
	var shape := _chimney_shape(chimney)
	if not is_finite(shape.y):
		return INF
	var ahead := -chimney.global_basis.z
	var across := chimney.global_basis.x
	var widest := 0.0
	var along := SLOPE_PROBE_STEP
	while along < shape.y:
		var height := STANDING_HEIGHT / 2.0
		while height <= shape.z:
			var middle := chimney.global_position + ahead * along + Vector3.UP * height
			var width := 0.0
			for look: float in [-1.0, 1.0]:
				var hit := _cast(chimney, middle, middle + across * look * Section.WIDTH / 2.0)
				if hit.is_empty():
					return INF
				width += middle.distance_to(hit["position"] as Vector3)
			widest = maxf(widest, width)
			height += STANDING_HEIGHT / 2.0
		along += SLOPE_PROBE_STEP
	return widest


## The walls alongside [param gap], probed at the height of the Runner's middle down the middle of
## the Gap, in order along it: for each, the side it is on (-1 left, 1 right), and where along
## the Gap it starts and ends, m.
func _walls_along(gap: Node3D) -> Array[Vector3]:
	var walls: Array[Vector3] = []
	var ahead := -gap.global_basis.z
	var length := _gap_length(gap)
	for side: float in [-1.0, 1.0]:
		var start := NAN
		var along := 0.0
		while along <= length:
			var middle := gap.global_position + ahead * along + Vector3.UP * STANDING_HEIGHT / 2.0
			var found := _wall_side(gap, middle, side) != 0.0
			if found and is_nan(start):
				start = along
			elif not found and not is_nan(start):
				walls.append(Vector3(side, start, along))
				start = NAN
			along += GAP_PROBE_STEP
		if not is_nan(start):
			walls.append(Vector3(side, start, length))
	walls.sort_custom(
		func(a: Vector3, b: Vector3) -> bool:
			return a.y < b.y,
	)
	return walls


## Follows a Wall-run across [param gap] at the Wall-run entry speed, begun by a jump at its near
## edge: the Runner's body follows the Wall-run's arc and slowdown with the default tuning. It
## must keep a near-vertical wall on the same side, from its feet to its head, until it is over
## the floor beyond, without slowing enough to end the Wall-run, and get there with the floor's
## edge within Mantle reach, however high it is. Returns what went wrong, or an empty String.
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
	if feet < _rise_beyond(gap) - _tuning.mantle_reach:
		return "the floor beyond is out of Mantle reach"
	return ""


## How far the floor beyond [param gap] is above the floor at its marker, m.
func _rise_beyond(gap: Node3D) -> float:
	var beyond := gap.global_position - gap.global_basis.z * _gap_length(gap)
	return _floor_height(gap, beyond) - gap.global_position.y
