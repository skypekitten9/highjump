extends GdUnitTestSuite
## The Runner, holding forward as in an Attempt, clears each obstacle Section when the Player
## presses the right moves at the right places, and doesn't get through with nothing pressed.
## Each Section is laid after a flat run-up and before a flat run-off, both at floor height 0.

## How far before the Section's start the Runner starts, standing still, m.
const RUN_UP := 10.0
## How far beyond the Section's end the Runner must get, standing on the floor, to clear it, m.
const BEYOND := 2.0
## The most frames an Attempt at a Section may take, at 60 Hz.
const MAX_FRAMES := 900
## Feet this far below floor height 0 have fallen, m.
const FALLEN := -2.0
## Frames with almost no progress along the Section that count as stuck.
const STUCK_FRAMES := 60
## Progress along the Section over [constant STUCK_FRAMES] frames below which the Runner is stuck,
## m.
const STUCK_PROGRESS := 0.5

## The Runner put through each Section.
const RUNNER_SCENE := preload("res://runner/runner.tscn")
## Every input action a [Step] may press, all released after each test.
const ACTIONS: Array[StringName] = [&"jump", &"crouch", &"move_left", &"move_right"]
## How long after turning toward the next wall the Wall-jump to it is pressed, m along.
const JUMP_AFTER_TURN := 0.1

## The Hurdle Section.
const HURDLE := "res://course/sections/hurdle.tscn"
## The Block Section.
const BLOCK := "res://course/sections/block.tscn"
## The Overhead bar Section.
const OVERHEAD_BAR := "res://course/sections/overhead_bar.tscn"
## The Short gap Section.
const SHORT_GAP := "res://course/sections/short_gap.tscn"
## The Wall-run gap Section.
const WALL_RUN_GAP := "res://course/sections/wall_run_gap.tscn"
## A Hurdle, then an Overhead bar.
const HURDLE_THEN_OVERHEAD_BAR := "res://course/sections/hurdle_then_overhead_bar.tscn"
## A Block, a Long gap, then a Wall-run gap.
const BLOCK_LONG_GAP_WALL_RUN_GAP := "res://course/sections/block_long_gap_wall_run_gap.tscn"
## A Hurdle, a Short gap, then an Overhead bar.
const HURDLE_SHORT_GAP_OVERHEAD_BAR := "res://course/sections/hurdle_short_gap_overhead_bar.tscn"
## A Long gap, then an Overhead bar.
const LONG_GAP_OVERHEAD_BAR := "res://course/sections/long_gap_overhead_bar.tscn"
## Where a Runner that landed standing beyond the Long gap, before the Overhead bar, crouches to
## Slide under it, m along: once it has surely landed, with time to spare before the bar.
const LONG_GAP_OVERHEAD_BAR_LANDED := 21.5
## A Block, then a Wall-run gap jumped from its top.
const BLOCK_WALL_RUN_GAP := "res://course/sections/block_wall_run_gap.tscn"
## The Wall-jump gap Section.
const WALL_JUMP_GAP := "res://course/sections/wall_jump_gap.tscn"
## A Long gap, then a Wall-jump gap.
const LONG_GAP_WALL_JUMP_GAP := "res://course/sections/long_gap_wall_jump_gap.tscn"
## A Wall-run gap ending in a Mantle onto a tall Block.
const WALL_RUN_TO_MANTLE := "res://course/sections/wall_run_to_mantle.tscn"
## A Block, a Slope, a Long gap, a lower Slope, then a Wide gap.
const SLIDE_HOP_CHAIN := "res://course/sections/slide_hop_chain.tscn"
## A Chimney up to its ledge, a Slope down from it, then a Wide gap.
const CHIMNEY_SLOPE_WIDE_GAP := "res://course/sections/chimney_slope_wide_gap.tscn"

## Where the moves across the Wall-jump gap fall, m from its near edge: the turn toward the first
## wall, on the left, and the jump onto it.
const WALL_JUMP_GAP_TURN_IN := -0.6
const WALL_JUMP_GAP_TAKE_OFF := -0.1
## The turns toward each next wall across the Wall-jump gap, m from its near edge.
const WALL_JUMP_GAP_TURNS: Array[float] = [1.4, 5.3, 10.6]
## Where the turn toward the last wall of the Wall-jump gap is let go, m from its near edge.
const WALL_JUMP_GAP_LET_GO := 22.0
## How far along the Wall-jump gap Section its near edge is, m.
const WALL_JUMP_GAP_EDGE := 8.0
## How far along the Long gap then Wall-jump gap Section the Wall-jump gap's near edge is, m.
const LONG_GAP_WALL_JUMP_GAP_EDGE := 24.0
## How fast a fast Runner arrives at the Wall-jump gap, m/s: the speed a Slide begins with.
const WALL_JUMP_GAP_FAST_ENTRY := 11.0
## The turns toward each next wall across the Wall-jump gap for a fast Runner, m from its near
## edge: it reaches each wall further along.
const WALL_JUMP_GAP_FAST_TURNS: Array[float] = [1.6, 6.1, 11.1]

## Where the moves up the Chimney fall, m along the Chimney Section: the turn toward its wall on
## the left, early enough that the Runner has always finished turning, and the jump onto it.
const CHIMNEY_TURN_IN := 7.5
const CHIMNEY_TAKE_OFF := 9.3
## The turns toward each next wall up the Chimney, m along the Chimney Section.
const CHIMNEY_TURNS: Array[float] = [10.2, 12.5, 15.5, 19.7]
## Where the turn toward the last wall of the Chimney is let go, m along the Chimney Section,
## before its ledge.
const CHIMNEY_LET_GO := 28.0
## How fast a fast Runner arrives at the Chimney, m/s: faster than a Slide begins with, as after
## Sliding down a Slope.
const CHIMNEY_FAST_ENTRY := 13.0
## The turns toward each next wall up the Chimney for a fast Runner, m along the Chimney Section:
## it reaches each wall further along.
const CHIMNEY_FAST_TURNS: Array[float] = [10.4, 14.9, 19.4]
## Where the Chimney Section's Wide gap's near edge is, m along it.
const CHIMNEY_WIDE_GAP := 44.83

## Where the moves through the Slide-hop chain fall, m along it: the jump at its Block, which ends
## in a Mantle, and the crouch on the Block's top that starts the Slide down the Slope.
const SLIDE_HOP_CHAIN_BLOCK_JUMP := 6.5
const SLIDE_HOP_CHAIN_CROUCH := 9.0
## Where the Slide-hop chain's Long gap's and Wide gap's near edges are, m along it.
const SLIDE_HOP_CHAIN_LONG_GAP := 12.25
const SLIDE_HOP_CHAIN_WIDE_GAP := 24.05
## The latest the Runner lands on the Slide-hop chain's lower Slope, m along it.
const SLIDE_HOP_CHAIN_LANDING := 22.7
## How long after landing standing on the lower Slope a Runner crouches to Slide, in the moves
## that must still fall into the Wide gap, m along: a few frames after, up to just before the
## earliest jump at the Wide gap.
const LATE_CROUCHES: Array[float] = [0.5, 0.8, 1.0]
## When the Runner jumps a Gap, m from its near edge: early, at the edge, and late, off the edge
## in coyote time.
const GAP_JUMPS: Array[float] = [-0.3, 0.0, 0.3]
## How far before a Gap's near edge the Runner jumps it when the moment needn't vary, m.
const JUMP_BEFORE_EDGE := 0.15
## How far beyond a Wide gap's near edge crouch is let go, the Runner long since in the air, m.
const LET_GO_BEYOND_WIDE_GAP := 3.0


func after_test() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)


## A Player input: at [param along] m along the Section, the Runner's position measured from the
## Section's start, [param action] is pressed, or released if not [param press]. A jump is
## tapped: pressed for one frame.
class Step:
	var along: float
	var action: StringName
	var press: bool


	func _init(at: float, what: StringName, down := true) -> void:
		along = at
		action = what
		press = down


func _floor(world: Node3D, from_along: float, to_along: float) -> void:
	var box := CSGBox3D.new()
	box.size = Vector3(Section.WIDTH, 1.0, to_along - from_along)
	box.position = Vector3(0.0, -0.5, -(from_along + to_along) / 2.0)
	box.use_collision = true
	world.add_child(box)


## Runs the Runner through the Section at [param path], pressing [param steps] in order. True if
## it gets [constant BEYOND] past the Section's end standing on the floor; false if it falls, gets
## stuck or runs out of time. A fast Runner, as after a Slide-hop or down a Slope, is made by
## giving it [param entry_speed] m/s across the ground, in the direction it moves, once it is
## [param entry_at] m along; 0 leaves its speed alone.
func _attempt(path: String, steps: Array[Step], entry_at := 0.0, entry_speed := 0.0) -> bool:
	var world: Node3D = auto_free(Node3D.new())
	var section: Section = (load(path) as PackedScene).instantiate()
	world.add_child(section)
	_floor(world, -RUN_UP - 1.0, 0.0)
	_floor(world, section.length, section.length + BEYOND + 20.0)
	var runner: Runner = RUNNER_SCENE.instantiate()
	runner.position = Vector3(0.0, 0.0, RUN_UP)
	world.add_child(runner)
	var scene := scene_runner(world)
	var pending := steps.duplicate()
	var progress: Array[float] = []
	for frame: int in MAX_FRAMES:
		var along := -runner.global_position.z
		Input.action_release(&"jump")
		while not pending.is_empty() and along >= (pending[0] as Step).along:
			var step: Step = pending.pop_front()
			if step.press:
				Input.action_press(step.action)
			else:
				Input.action_release(step.action)
		if entry_speed > 0.0 and along >= entry_at:
			var across := Vector3(runner.velocity.x, 0.0, runner.velocity.z).normalized()
			runner.velocity = across * entry_speed + Vector3.UP * runner.velocity.y
			entry_speed = 0.0
		await scene.simulate_frames(1, 16)
		if runner.global_position.y < FALLEN:
			return false
		if along > section.length + BEYOND and runner.is_on_floor():
			return true
		progress.append(along)
		if progress.size() > STUCK_FRAMES:
			if along - progress[progress.size() - 1 - STUCK_FRAMES] < STUCK_PROGRESS:
				return false
	return false


## The moves that climb from wall to wall, m along the Section from [param origin]: turn toward
## the wall on the left at [param turn_in] and jump onto it at [param take_off], then at each of
## [param turns] turn toward the other wall and Wall-jump to it [constant JUMP_AFTER_TURN] later,
## and let go of the last turn at [param let_go].
func _wall_jumps(
	origin: float,
	turn_in: float,
	take_off: float,
	turns: Array[float],
	let_go: float,
) -> Array[Step]:
	var steps: Array[Step] = [
		Step.new(origin + turn_in, &"move_left"),
		Step.new(origin + take_off, &"jump"),
	]
	var toward := &"move_right"
	var away := &"move_left"
	for turn: float in turns:
		steps.append_array(
			[
				Step.new(origin + turn, away, false),
				Step.new(origin + turn, toward),
				Step.new(origin + turn + JUMP_AFTER_TURN, &"jump"),
			],
		)
		var turned := toward
		toward = away
		away = turned
	steps.append(Step.new(origin + let_go, away, false))
	return steps


## The moves across a Wall-jump gap whose near edge is [param edge] m along the Section, jumping
## from wall to wall three times.
func _wall_jumps_across(edge: float) -> Array[Step]:
	return _wall_jumps(
		edge,
		WALL_JUMP_GAP_TURN_IN,
		WALL_JUMP_GAP_TAKE_OFF,
		WALL_JUMP_GAP_TURNS,
		WALL_JUMP_GAP_LET_GO,
	)


func test_holding_forward_alone_does_not_get_over_a_hurdle() -> void:
	assert_bool(await _attempt(HURDLE, [])).is_false()


func test_jumping_before_the_hurdle_clears_it() -> void:
	var steps: Array[Step] = [Step.new(5.5, &"jump")]
	assert_bool(await _attempt(HURDLE, steps)).is_true()


func test_holding_forward_alone_does_not_get_onto_a_block() -> void:
	assert_bool(await _attempt(BLOCK, [])).is_false()


func test_jumping_at_the_block_mantles_onto_it_and_clears_it() -> void:
	var steps: Array[Step] = [Step.new(6.5, &"jump")]
	assert_bool(await _attempt(BLOCK, steps)).is_true()


func test_holding_forward_alone_does_not_get_under_an_overhead_bar() -> void:
	assert_bool(await _attempt(OVERHEAD_BAR, [])).is_false()


func test_sliding_under_the_overhead_bar_clears_it() -> void:
	var steps: Array[Step] = [Step.new(6.0, &"crouch"), Step.new(11.5, &"crouch", false)]
	assert_bool(await _attempt(OVERHEAD_BAR, steps)).is_true()


func test_holding_forward_alone_falls_into_a_short_gap() -> void:
	assert_bool(await _attempt(SHORT_GAP, [])).is_false()


func test_jumping_at_the_edge_of_the_short_gap_clears_it() -> void:
	var steps: Array[Step] = [Step.new(7.4, &"jump")]
	assert_bool(await _attempt(SHORT_GAP, steps)).is_true()


func test_holding_forward_alone_trips_on_the_hurdle_before_the_overhead_bar() -> void:
	assert_bool(await _attempt(HURDLE_THEN_OVERHEAD_BAR, [])).is_false()


func test_jumping_the_hurdle_alone_does_not_get_under_the_overhead_bar() -> void:
	var steps: Array[Step] = [Step.new(5.5, &"jump")]
	assert_bool(await _attempt(HURDLE_THEN_OVERHEAD_BAR, steps)).is_false()


func test_jumping_the_hurdle_then_sliding_under_the_overhead_bar_clears_them() -> void:
	var steps: Array[Step] = [
		Step.new(5.5, &"jump"),
		Step.new(15.0, &"crouch"),
		Step.new(20.5, &"crouch", false),
	]
	assert_bool(await _attempt(HURDLE_THEN_OVERHEAD_BAR, steps)).is_true()


func test_jumping_a_wall_run_gap_without_the_wall_falls_short() -> void:
	var steps: Array[Step] = [Step.new(9.5, &"jump")]
	assert_bool(await _attempt(WALL_RUN_GAP, steps)).is_false()


func test_wall_running_along_the_wall_clears_the_wall_run_gap() -> void:
	var steps: Array[Step] = [
		Step.new(5.0, &"move_left"),
		Step.new(8.5, &"jump"),
		Step.new(20.0, &"move_left", false),
	]
	assert_bool(await _attempt(WALL_RUN_GAP, steps)).is_true()


func test_holding_forward_alone_does_not_get_onto_the_first_block_of_the_hardest_section() -> void:
	assert_bool(await _attempt(BLOCK_LONG_GAP_WALL_RUN_GAP, [])).is_false()


func test_mantling_slide_jumping_then_wall_running_clears_the_hardest_section() -> void:
	var steps: Array[Step] = [
		Step.new(6.5, &"jump"),
		Step.new(21.0, &"crouch"),
		Step.new(25.6, &"jump"),
		Step.new(27.0, &"crouch", false),
		Step.new(39.0, &"move_right"),
		Step.new(43.5, &"jump"),
		Step.new(55.0, &"move_right", false),
	]
	assert_bool(await _attempt(BLOCK_LONG_GAP_WALL_RUN_GAP, steps)).is_true()


func test_holding_forward_alone_trips_on_the_hurdle_before_the_short_gap() -> void:
	assert_bool(await _attempt(HURDLE_SHORT_GAP_OVERHEAD_BAR, [])).is_false()


func test_jumping_the_hurdle_and_the_short_gap_alone_does_not_get_under_the_bar() -> void:
	var steps: Array[Step] = [Step.new(5.5, &"jump"), Step.new(13.9, &"jump")]
	assert_bool(await _attempt(HURDLE_SHORT_GAP_OVERHEAD_BAR, steps)).is_false()


func test_jumping_the_hurdle_and_the_short_gap_then_sliding_under_the_bar_clears_them() -> void:
	var steps: Array[Step] = [
		Step.new(5.5, &"jump"),
		Step.new(13.9, &"jump"),
		Step.new(21.0, &"crouch"),
		Step.new(26.5, &"crouch", false),
	]
	assert_bool(await _attempt(HURDLE_SHORT_GAP_OVERHEAD_BAR, steps)).is_true()


func test_holding_forward_alone_falls_into_the_long_gap_before_the_overhead_bar() -> void:
	assert_bool(await _attempt(LONG_GAP_OVERHEAD_BAR, [])).is_false()


func test_slide_jumping_the_long_gap_and_landing_standing_does_not_get_under_the_bar() -> void:
	var steps: Array[Step] = [
		Step.new(7.0, &"crouch"),
		Step.new(11.6, &"jump"),
		Step.new(13.0, &"crouch", false),
	]
	assert_bool(await _attempt(LONG_GAP_OVERHEAD_BAR, steps)).is_false()


func test_slide_jumping_the_long_gap_and_slide_hopping_under_the_bar_clears_them() -> void:
	var steps: Array[Step] = [
		Step.new(7.0, &"crouch"),
		Step.new(11.6, &"jump"),
		Step.new(29.0, &"crouch", false),
	]
	assert_bool(await _attempt(LONG_GAP_OVERHEAD_BAR, steps)).is_true()


func test_landing_standing_beyond_the_long_gap_then_sliding_under_the_bar_clears_them() -> void:
	var steps: Array[Step] = [
		Step.new(7.0, &"crouch"),
		Step.new(11.6, &"jump"),
		Step.new(13.0, &"crouch", false),
		Step.new(LONG_GAP_OVERHEAD_BAR_LANDED, &"crouch"),
		Step.new(29.0, &"crouch", false),
	]
	assert_bool(await _attempt(LONG_GAP_OVERHEAD_BAR, steps)).is_true()


func test_holding_forward_alone_does_not_get_onto_the_block_before_the_wall_run_gap() -> void:
	assert_bool(await _attempt(BLOCK_WALL_RUN_GAP, [])).is_false()


func test_mantling_then_jumping_off_the_block_without_wall_running_falls_short() -> void:
	var steps: Array[Step] = [Step.new(6.5, &"jump"), Step.new(13.5, &"jump")]
	assert_bool(await _attempt(BLOCK_WALL_RUN_GAP, steps)).is_false()


func test_mantling_then_wall_running_off_the_block_clears_the_wall_run_gap() -> void:
	var steps: Array[Step] = [
		Step.new(6.5, &"jump"),
		Step.new(9.5, &"move_left"),
		Step.new(13.5, &"jump"),
		Step.new(24.0, &"move_left", false),
	]
	assert_bool(await _attempt(BLOCK_WALL_RUN_GAP, steps)).is_true()


func test_wall_running_one_wall_of_the_wall_jump_gap_falls_short() -> void:
	var steps: Array[Step] = [
		Step.new(7.4, &"move_left"),
		Step.new(7.9, &"jump"),
		Step.new(10.0, &"move_left", false),
	]
	assert_bool(await _attempt(WALL_JUMP_GAP, steps)).is_false()


func test_wall_jumping_from_wall_to_wall_clears_the_wall_jump_gap() -> void:
	assert_bool(await _attempt(WALL_JUMP_GAP, _wall_jumps_across(WALL_JUMP_GAP_EDGE))).is_true()


func test_slide_jumping_the_long_gap_then_one_wall_run_falls_into_the_wall_jump_gap() -> void:
	var steps: Array[Step] = [
		Step.new(10.4, &"crouch"),
		Step.new(11.6, &"jump"),
		Step.new(13.0, &"crouch", false),
		Step.new(23.4, &"move_left"),
		Step.new(23.9, &"jump"),
		Step.new(26.0, &"move_left", false),
	]
	assert_bool(await _attempt(LONG_GAP_WALL_JUMP_GAP, steps)).is_false()


func test_slide_jumping_the_long_gap_then_wall_jumping_clears_the_wall_jump_gap() -> void:
	var steps: Array[Step] = [
		Step.new(10.4, &"crouch"),
		Step.new(11.6, &"jump"),
		Step.new(13.0, &"crouch", false),
	]
	steps.append_array(_wall_jumps_across(LONG_GAP_WALL_JUMP_GAP_EDGE))
	assert_bool(await _attempt(LONG_GAP_WALL_JUMP_GAP, steps)).is_true()


func test_jumping_at_the_tall_block_from_the_floor_falls_into_the_gap_before_it() -> void:
	var steps: Array[Step] = [Step.new(9.5, &"jump")]
	assert_bool(await _attempt(WALL_RUN_TO_MANTLE, steps)).is_false()


func test_mantling_out_of_a_wall_run_onto_the_tall_block_clears_it() -> void:
	var steps: Array[Step] = [
		Step.new(5.0, &"move_left"),
		Step.new(9.5, &"jump"),
		Step.new(19.0, &"move_left", false),
	]
	assert_bool(await _attempt(WALL_RUN_TO_MANTLE, steps)).is_true()


func test_holding_forward_alone_does_not_get_onto_the_block_before_the_slopes() -> void:
	assert_bool(await _attempt(SLIDE_HOP_CHAIN, [])).is_false()


func test_sliding_down_both_slopes_with_a_slide_hop_between_them_clears_the_wide_gap() -> void:
	for jump: float in GAP_JUMPS:
		var steps := _through_the_slide_hop_chain(jump)
		var message := "jumping the Wide gap %.2f m from its edge falls into it" % jump
		var cleared := await _attempt(SLIDE_HOP_CHAIN, steps)
		assert_bool(cleared).override_failure_message(message).is_true()


func test_landing_standing_on_the_lower_slope_then_sliding_falls_into_the_wide_gap() -> void:
	for late: float in LATE_CROUCHES:
		for jump: float in GAP_JUMPS:
			var steps := _through_the_slide_hop_chain(jump, SLIDE_HOP_CHAIN_LANDING + late)
			var message := "crouching %.1f m after landing, jumping %.2f m from the edge clears" % [
				late,
				jump,
			]
			var cleared := await _attempt(SLIDE_HOP_CHAIN, steps)
			assert_bool(cleared).override_failure_message(message).is_false()


func test_running_down_the_slopes_instead_of_sliding_falls_into_the_wide_gap() -> void:
	for jump: float in GAP_JUMPS:
		var steps: Array[Step] = [
			Step.new(SLIDE_HOP_CHAIN_BLOCK_JUMP, &"jump"),
			Step.new(SLIDE_HOP_CHAIN_LONG_GAP - JUMP_BEFORE_EDGE, &"jump"),
			Step.new(SLIDE_HOP_CHAIN_WIDE_GAP + jump, &"jump"),
		]
		var message := "jumping the Wide gap %.2f m from its edge clears it" % jump
		var cleared := await _attempt(SLIDE_HOP_CHAIN, steps)
		assert_bool(cleared).override_failure_message(message).is_false()


func test_wall_running_one_wall_of_the_chimney_falls_into_the_gap_under_it() -> void:
	assert_bool(await _attempt(CHIMNEY_SLOPE_WIDE_GAP, _one_wall_of_the_chimney())).is_false()


func test_wall_running_one_wall_of_the_chimney_arriving_fast_falls_into_the_gap_under_it() -> void:
	var steps := _one_wall_of_the_chimney()
	var fast := CHIMNEY_FAST_ENTRY
	var cleared := await _attempt(CHIMNEY_SLOPE_WIDE_GAP, steps, CHIMNEY_TAKE_OFF, fast)
	assert_bool(cleared).is_false()


func test_wall_jumping_up_the_chimney_then_sliding_down_the_slope_clears_the_wide_gap() -> void:
	var steps := _up_the_chimney(CHIMNEY_TURNS)
	steps.append_array(_slide_and_jump_the_chimney_wide_gap())
	assert_bool(await _attempt(CHIMNEY_SLOPE_WIDE_GAP, steps)).is_true()


func test_wall_jumping_up_the_chimney_arriving_fast_then_sliding_clears_the_wide_gap() -> void:
	var steps := _up_the_chimney(CHIMNEY_FAST_TURNS)
	steps.append_array(_slide_and_jump_the_chimney_wide_gap())
	var fast := CHIMNEY_FAST_ENTRY
	var cleared := await _attempt(CHIMNEY_SLOPE_WIDE_GAP, steps, CHIMNEY_TAKE_OFF, fast)
	assert_bool(cleared).is_true()


func test_wall_jumping_up_the_chimney_then_running_down_the_slope_falls_into_the_wide_gap() -> void:
	var steps := _up_the_chimney(CHIMNEY_TURNS)
	steps.append(Step.new(CHIMNEY_WIDE_GAP - JUMP_BEFORE_EDGE, &"jump"))
	assert_bool(await _attempt(CHIMNEY_SLOPE_WIDE_GAP, steps)).is_false()


func test_wall_jumping_across_the_wall_jump_gap_arriving_fast_clears_it() -> void:
	var steps := _wall_jumps(
		WALL_JUMP_GAP_EDGE,
		WALL_JUMP_GAP_TURN_IN,
		WALL_JUMP_GAP_TAKE_OFF,
		WALL_JUMP_GAP_FAST_TURNS,
		WALL_JUMP_GAP_LET_GO,
	)
	var entry_at := WALL_JUMP_GAP_EDGE + WALL_JUMP_GAP_TAKE_OFF
	var cleared := await _attempt(WALL_JUMP_GAP, steps, entry_at, WALL_JUMP_GAP_FAST_ENTRY)
	assert_bool(cleared).is_true()


## The moves through the Slide-hop chain: jump at its Block to Mantle onto it, crouch on top to
## Slide down the Slope, jump the Long gap from its edge, then jump the Wide gap [param wide_jump]
## m from its edge. With crouch held across the Long gap the Runner Slide-hops onto the lower
## Slope. If [param crouch_at] is a number, crouch is let go in the air instead, so the Runner
## lands standing, and pressed again at [param crouch_at] m along to Slide.
func _through_the_slide_hop_chain(wide_jump: float, crouch_at := NAN) -> Array[Step]:
	var long_gap_jump := SLIDE_HOP_CHAIN_LONG_GAP - JUMP_BEFORE_EDGE
	var steps: Array[Step] = [
		Step.new(SLIDE_HOP_CHAIN_BLOCK_JUMP, &"jump"),
		Step.new(SLIDE_HOP_CHAIN_CROUCH, &"crouch"),
		Step.new(long_gap_jump, &"jump"),
	]
	if not is_nan(crouch_at):
		var let_go := Step.new(long_gap_jump + 1.0, &"crouch", false)
		steps.append_array([let_go, Step.new(crouch_at, &"crouch")])
	steps.append_array(
		[
			Step.new(SLIDE_HOP_CHAIN_WIDE_GAP + wide_jump, &"jump"),
			Step.new(SLIDE_HOP_CHAIN_WIDE_GAP + LET_GO_BEYOND_WIDE_GAP, &"crouch", false),
		],
	)
	return steps


## The moves that run in along the Chimney's wall on the left and jump onto it, then Wall-jump to
## the other wall at each of [param turns], m along the Chimney Section, up to its ledge.
func _up_the_chimney(turns: Array[float]) -> Array[Step]:
	return _wall_jumps(0.0, CHIMNEY_TURN_IN, CHIMNEY_TAKE_OFF, turns, CHIMNEY_LET_GO)


## The moves that run in along the Chimney's wall on the left and Wall-run it, with no Wall-jump.
func _one_wall_of_the_chimney() -> Array[Step]:
	return [
		Step.new(CHIMNEY_TURN_IN, &"move_left"),
		Step.new(CHIMNEY_TAKE_OFF, &"jump"),
		Step.new(CHIMNEY_LET_GO, &"move_left", false),
	]


## The moves down from the Chimney's ledge: crouch to Slide down the Slope, and jump the Wide gap
## from its edge.
func _slide_and_jump_the_chimney_wide_gap() -> Array[Step]:
	return [
		Step.new(CHIMNEY_LET_GO, &"crouch"),
		Step.new(CHIMNEY_WIDE_GAP - JUMP_BEFORE_EDGE, &"jump"),
		Step.new(CHIMNEY_WIDE_GAP + LET_GO_BEYOND_WIDE_GAP, &"crouch", false),
	]
