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

const ACTIONS: Array[StringName] = [&"jump", &"crouch", &"move_left", &"move_right"]


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
## stuck or runs out of time.
func _attempt(path: String, steps: Array[Step]) -> bool:
	var world: Node3D = auto_free(Node3D.new())
	var section: Section = (load(path) as PackedScene).instantiate()
	world.add_child(section)
	_floor(world, -RUN_UP - 1.0, 0.0)
	_floor(world, section.length, section.length + BEYOND + 20.0)
	var runner: Runner = (load("res://runner/runner.tscn") as PackedScene).instantiate()
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


func test_holding_forward_alone_does_not_get_over_a_hurdle() -> void:
	assert_bool(await _attempt("res://course/sections/hurdle.tscn", [])).is_false()


func test_jumping_before_the_hurdle_clears_it() -> void:
	var steps: Array[Step] = [Step.new(5.5, &"jump")]
	assert_bool(await _attempt("res://course/sections/hurdle.tscn", steps)).is_true()


func test_holding_forward_alone_does_not_get_onto_a_block() -> void:
	assert_bool(await _attempt("res://course/sections/block.tscn", [])).is_false()


func test_jumping_at_the_block_mantles_onto_it_and_clears_it() -> void:
	var steps: Array[Step] = [Step.new(6.5, &"jump")]
	assert_bool(await _attempt("res://course/sections/block.tscn", steps)).is_true()


func test_holding_forward_alone_does_not_get_under_an_overhead_bar() -> void:
	assert_bool(await _attempt("res://course/sections/overhead_bar.tscn", [])).is_false()


func test_sliding_under_the_overhead_bar_clears_it() -> void:
	var steps: Array[Step] = [Step.new(6.0, &"crouch"), Step.new(11.5, &"crouch", false)]
	assert_bool(await _attempt("res://course/sections/overhead_bar.tscn", steps)).is_true()


func test_holding_forward_alone_falls_into_a_short_gap() -> void:
	assert_bool(await _attempt("res://course/sections/short_gap.tscn", [])).is_false()


func test_jumping_at_the_edge_of_the_short_gap_clears_it() -> void:
	var steps: Array[Step] = [Step.new(7.4, &"jump")]
	assert_bool(await _attempt("res://course/sections/short_gap.tscn", steps)).is_true()


func test_holding_forward_alone_trips_on_the_hurdle_before_the_overhead_bar() -> void:
	var path := "res://course/sections/hurdle_then_overhead_bar.tscn"
	assert_bool(await _attempt(path, [])).is_false()


func test_jumping_the_hurdle_alone_does_not_get_under_the_overhead_bar() -> void:
	var path := "res://course/sections/hurdle_then_overhead_bar.tscn"
	var steps: Array[Step] = [Step.new(5.5, &"jump")]
	assert_bool(await _attempt(path, steps)).is_false()


func test_jumping_the_hurdle_then_sliding_under_the_overhead_bar_clears_them() -> void:
	var path := "res://course/sections/hurdle_then_overhead_bar.tscn"
	var steps: Array[Step] = [
		Step.new(5.5, &"jump"),
		Step.new(15.0, &"crouch"),
		Step.new(20.5, &"crouch", false),
	]
	assert_bool(await _attempt(path, steps)).is_true()


func test_jumping_a_wall_run_gap_without_the_wall_falls_short() -> void:
	var steps: Array[Step] = [Step.new(9.5, &"jump")]
	assert_bool(await _attempt("res://course/sections/wall_run_gap.tscn", steps)).is_false()


func test_wall_running_along_the_wall_clears_the_wall_run_gap() -> void:
	var steps: Array[Step] = [
		Step.new(5.0, &"move_left"),
		Step.new(8.5, &"jump"),
		Step.new(20.0, &"move_left", false),
	]
	assert_bool(await _attempt("res://course/sections/wall_run_gap.tscn", steps)).is_true()


func test_holding_forward_alone_does_not_get_onto_the_first_block_of_the_hardest_section() -> void:
	var path := "res://course/sections/block_long_gap_wall_run_gap.tscn"
	assert_bool(await _attempt(path, [])).is_false()


func test_mantling_slide_jumping_then_wall_running_clears_the_hardest_section() -> void:
	var path := "res://course/sections/block_long_gap_wall_run_gap.tscn"
	var steps: Array[Step] = [
		Step.new(6.5, &"jump"),
		Step.new(21.0, &"crouch"),
		Step.new(25.6, &"jump"),
		Step.new(27.0, &"crouch", false),
		Step.new(39.0, &"move_right"),
		Step.new(43.5, &"jump"),
		Step.new(55.0, &"move_right", false),
	]
	assert_bool(await _attempt(path, steps)).is_true()
