extends GdUnitTestSuite
## The Runner scene always runs forward, relative to the view, and the Look limit stops the view
## turning too far either side of the Course heading (docs/adr/0008).

const RunnerScene := preload("res://runner/runner.tscn")
## Far more mouse movement than any Look limit allows, px.
const HUGE_TURN := 100000.0

var _tuning: RunnerTuning


func before_test() -> void:
	_tuning = load("res://runner/default_runner_tuning.tres")


func after_test() -> void:
	Input.action_release("move_right")
	Input.action_release("move_back")


func _world_with_floor() -> Node3D:
	var world: Node3D = auto_free(Node3D.new())
	var floor_box := CSGBox3D.new()
	floor_box.size = Vector3(200.0, 1.0, 200.0)
	floor_box.position.y = -0.5
	floor_box.use_collision = true
	world.add_child(floor_box)
	return world


## A Runner on the floor at the origin, turned [param turn] degrees left of -Z.
func _add_runner(world: Node3D, turn := 0.0) -> Runner:
	var runner: Runner = RunnerScene.instantiate()
	runner.rotation.y = deg_to_rad(turn)
	world.add_child(runner)
	return runner


## Which way the camera looks: degrees left of -Z.
func _view_yaw(runner: Runner) -> float:
	var forward := -runner.get_viewport().get_camera_3d().global_basis.z
	return rad_to_deg(atan2(-forward.x, -forward.z))


func _horizontal_speed(runner: Runner) -> float:
	return Vector2(runner.velocity.x, runner.velocity.z).length()


func test_with_no_input_held_the_runner_runs_forward_at_run_speed() -> void:
	var world := _world_with_floor()
	var runner := _add_runner(world)
	var scene := scene_runner(world)

	await scene.simulate_frames(40, 16)

	assert_float(runner.position.z).is_less(-2.0)
	assert_float(runner.position.x).is_equal_approx(0.0, 0.01)
	assert_float(_horizontal_speed(runner)).is_equal_approx(_tuning.run_speed, 0.1)


func test_the_runner_runs_where_it_looks() -> void:
	var world := _world_with_floor()
	# Facing +X.
	var runner := _add_runner(world, -90.0)
	var scene := scene_runner(world)

	await scene.simulate_frames(40, 16)

	assert_float(runner.position.x).is_greater(2.0)
	assert_float(runner.position.z).is_equal_approx(0.0, 0.01)


func test_holding_back_does_nothing() -> void:
	var world := _world_with_floor()
	var runner := _add_runner(world)
	var scene := scene_runner(world)

	Input.action_press("move_back")
	await scene.simulate_frames(40, 16)

	assert_float(runner.position.z).is_less(-2.0)
	assert_float(_horizontal_speed(runner)).is_equal_approx(_tuning.run_speed, 0.1)


func test_holding_right_still_steers_right() -> void:
	var world := _world_with_floor()
	var runner := _add_runner(world)
	var scene := scene_runner(world)

	Input.action_press("move_right")
	await scene.simulate_frames(40, 16)

	assert_float(runner.position.x).is_greater(1.0)
	assert_float(runner.position.z).is_less(-1.0)


func test_mouse_look_stops_at_the_look_limit_to_the_left() -> void:
	var world := _world_with_floor()
	var runner := _add_runner(world)
	await scene_runner(world).simulate_frames(1, 16)

	runner.look(Vector2(-HUGE_TURN, 0.0))

	assert_float(_view_yaw(runner)).is_equal_approx(80.0, 0.01)


func test_mouse_look_stops_at_the_look_limit_to_the_right() -> void:
	var world := _world_with_floor()
	var runner := _add_runner(world)
	await scene_runner(world).simulate_frames(1, 16)

	runner.look(Vector2(HUGE_TURN, 0.0))

	assert_float(_view_yaw(runner)).is_equal_approx(-80.0, 0.01)


func test_mouse_look_turns_freely_within_the_look_limit_and_back() -> void:
	var world := _world_with_floor()
	var runner := _add_runner(world)
	await scene_runner(world).simulate_frames(1, 16)
	runner.look(Vector2(HUGE_TURN, 0.0))

	# Back left by 30 degrees from the right-hand stop.
	runner.look(Vector2(-deg_to_rad(30.0) / _tuning.mouse_sensitivity, 0.0))

	assert_float(_view_yaw(runner)).is_equal_approx(-50.0, 0.01)


func test_the_look_limit_leaves_pitch_alone() -> void:
	var world := _world_with_floor()
	var runner := _add_runner(world)
	await scene_runner(world).simulate_frames(1, 16)

	runner.look(Vector2(HUGE_TURN, -deg_to_rad(45.0) / _tuning.mouse_sensitivity))

	var forward := -runner.get_viewport().get_camera_3d().global_basis.z
	assert_float(rad_to_deg(asin(forward.y))).is_equal_approx(45.0, 0.01)


func test_the_course_heading_defaults_to_the_starting_facing() -> void:
	var world := _world_with_floor()
	var runner := _add_runner(world, 30.0)
	await scene_runner(world).simulate_frames(1, 16)

	runner.look(Vector2(HUGE_TURN, 0.0))

	assert_float(_view_yaw(runner)).is_equal_approx(-50.0, 0.01)


func test_the_look_limit_is_either_side_of_a_course_heading_set_from_outside() -> void:
	var world := _world_with_floor()
	var runner := _add_runner(world)
	await scene_runner(world).simulate_frames(1, 16)

	# Along +X: 90 degrees right of -Z.
	runner.course_heading = Vector3.RIGHT
	runner.look(Vector2(-HUGE_TURN, 0.0))

	assert_float(_view_yaw(runner)).is_equal_approx(-10.0, 0.01)


func test_the_look_limit_follows_the_tuning() -> void:
	var world := _world_with_floor()
	var tuning: RunnerTuning = _tuning.duplicate()
	tuning.look_limit = 45.0
	var runner: Runner = RunnerScene.instantiate()
	runner.tuning = tuning
	world.add_child(runner)
	await scene_runner(world).simulate_frames(1, 16)

	runner.look(Vector2(-HUGE_TURN, 0.0))

	assert_float(_view_yaw(runner)).is_equal_approx(45.0, 0.01)
