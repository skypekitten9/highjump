extends GdUnitTestSuite
## The greybox level's playtest course has every area, labelled, and each feels as intended.

const GREYBOX := "res://levels/greybox/greybox.tscn"
## Collision layer the Runner is moved to, so a ray can find its body and nothing else.
const RUNNER_LAYER := 2

var _tuning: RunnerTuning


func before_test() -> void:
	_tuning = load("res://runner/default_runner_tuning.tres")


func after_test() -> void:
	Input.action_release("move_forward")
	Input.action_release("move_right")
	Input.action_release("crouch")
	Input.action_release("jump")


## A fresh greybox level, not yet in the tree.
func _greybox() -> Level:
	return auto_free((load(GREYBOX) as PackedScene).instantiate())


## Runs [param level] with its Runner moved to [param start] (a node path in the level), facing
## the way it faces. Returns the scene runner.
func _run_with_runner_at(level: Level, start: String) -> GdUnitSceneRunner:
	var scene := scene_runner(level)
	var runner := _runner_of(level)
	runner.global_transform = (level.get_node(start) as Node3D).global_transform
	runner.collision_layer = RUNNER_LAYER
	return scene


func _runner_of(level: Level) -> Runner:
	return level.get_node("Runner")


func _horizontal_speed(runner: Runner) -> float:
	return Vector2(runner.velocity.x, runner.velocity.z).length()


func _on_flat_floor(runner: Runner) -> bool:
	return runner.is_on_floor() and runner.get_floor_normal().y > 0.999


func test_a_held_slide_down_the_long_steep_slope_hits_top_slide_speed_before_the_bottom() -> void:
	var level := _greybox()
	var scene := _run_with_runner_at(level, "PlaytestCourse/LongSteepSlope/SlideStart")
	var runner := _runner_of(level)
	await scene.simulate_frames(10, 16)

	# Run at the crest, crouch into a Slide on the flat top, and hold it down the slope.
	Input.action_press("move_forward")
	await scene.simulate_frames(5, 16)
	Input.action_press("crouch")
	var on_slope := false
	var fastest_on_slope := 0.0
	for frame: int in 600:
		await scene.simulate_frames(1, 16)
		if _on_flat_floor(runner):
			if on_slope:
				break
			continue
		on_slope = true
		fastest_on_slope = maxf(fastest_on_slope, _horizontal_speed(runner))

	assert_bool(on_slope).is_true()
	# Reached the run-out at the bottom, still sliding.
	assert_bool(_on_flat_floor(runner)).is_true()
	assert_float(fastest_on_slope).is_equal_approx(_tuning.top_slide_speed, 0.01)


func test_every_playtest_area_has_a_visible_label() -> void:
	var level := _greybox()
	var labels: Array[String] = []
	for node: Node in level.find_children("*", "Label3D"):
		var label := node as Label3D
		if label.is_visible_in_tree():
			labels.append(label.text)
	assert_array(labels).contains(
		[
			"Gentle slope",
			"Long steep slope",
			"Long uphill",
			"Valley",
			"Side-tilted slope",
			"Crouch tunnel",
			"Wall-run",
			"Round tower",
			"Sharp corner",
			"Inside corner",
		]
	)


## Height of the top of the Runner's body above its feet, measured by a ray down onto it.
func _body_top(runner: Runner) -> float:
	var above := runner.global_position + Vector3.UP * 10.0
	var ray := PhysicsRayQueryParameters3D.create(above, runner.global_position, RUNNER_LAYER)
	var hit := runner.get_world_3d().direct_space_state.intersect_ray(ray)
	assert_bool(hit.is_empty()).is_false()
	return (hit["position"] as Vector3).y - runner.global_position.y


## True if the level is within 3 m straight above the Runner's feet.
func _ceiling_overhead(runner: Runner) -> bool:
	var feet := runner.global_position + Vector3.UP * 0.1
	var ray := PhysicsRayQueryParameters3D.create(feet, feet + Vector3.UP * 3.0)
	ray.exclude = [runner.get_rid()]
	return not runner.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _is_low(runner: Runner) -> bool:
	return _body_top(runner) < _tuning.crouch_height + 0.05


func test_the_runner_cannot_stand_in_the_crouch_tunnel_and_stands_once_out() -> void:
	var level := _greybox()
	var scene := _run_with_runner_at(level, "PlaytestCourse/CrouchTunnel/Approach")
	var runner := _runner_of(level)
	await scene.simulate_frames(10, 16)

	# Crouch in, then let go of crouch once well inside.
	Input.action_press("crouch")
	Input.action_press("move_forward")
	var frames_inside := 0
	for frame: int in 300:
		await scene.simulate_frames(1, 16)
		if _ceiling_overhead(runner):
			frames_inside += 1
		if frames_inside > 30:
			break
	Input.action_release("crouch")
	assert_bool(_ceiling_overhead(runner)).is_true()

	# Still low everywhere under the ceiling, and standing again once clear of it.
	var stood_up := false
	for frame: int in 600:
		await scene.simulate_frames(1, 16)
		if _ceiling_overhead(runner):
			assert_bool(_is_low(runner)).is_true()
		elif not _is_low(runner):
			stood_up = true
			break
	assert_bool(stood_up).is_true()
	assert_bool(_ceiling_overhead(runner)).is_false()


func test_wall_jumps_holding_forward_zig_zag_across_the_wall_run_gap_gaining_speed() -> void:
	var level := _greybox()
	var scene := _run_with_runner_at(level, "PlaytestCourse/WallRun/SlideStart")
	var runner := _runner_of(level)
	var area := level.get_node("PlaytestCourse/WallRun") as Node3D
	# On the floor midway between the walls, just before they begin, facing along them.
	runner.global_position = area.to_global(Vector3(20.0, 0.0, 0.0))
	await scene.simulate_frames(10, 16)

	# Run up to speed, then jump toward the right-hand wall.
	Input.action_press("move_forward")
	await scene.simulate_frames(6, 16)
	Input.action_press("move_right")
	Input.action_press("jump")
	await scene.simulate_frames(1, 16)
	Input.action_release("jump")

	# Wall-jump two frames into every Wall-run, holding forward only.
	var speeds: Array[float] = []
	var sides: Array[float] = []
	var running := false
	for frame: int in 300:
		await scene.simulate_frames(1, 16)
		if runner.is_wall_running() and not running:
			Input.action_release("move_right")
			speeds.append(_horizontal_speed(runner))
			sides.append(signf(area.to_local(runner.global_position).z))
			await scene.simulate_frames(2, 16)
			Input.action_press("jump")
			await scene.simulate_frames(1, 16)
			Input.action_release("jump")
		running = runner.is_wall_running()
		if runner.is_on_floor() and not speeds.is_empty():
			break

	# The first wall and at least three crossings, each to the other wall and faster.
	assert_int(speeds.size()).is_greater_equal(4)
	for index: int in range(1, speeds.size()):
		assert_float(sides[index]).is_equal(-sides[index - 1])
		assert_float(speeds[index]).is_greater(speeds[index - 1])


## Runs from [param start] (a node path in the level) holding forward, jumps once up to speed and
## flies on holding forward. Returns the scene runner, once the jump has been pressed.
func _jump_from(level: Level, start: String) -> GdUnitSceneRunner:
	var scene := _run_with_runner_at(level, start)
	await scene.simulate_frames(10, 16)
	Input.action_press("move_forward")
	await scene.simulate_frames(6, 16)
	Input.action_press("jump")
	await scene.simulate_frames(1, 16)
	Input.action_release("jump")
	return scene


## Horizontal unit direction of the Runner's velocity.
func _heading(runner: Runner) -> Vector3:
	return Vector3(runner.velocity.x, 0.0, runner.velocity.z).normalized()


func test_a_wall_run_goes_partway_around_the_round_tower() -> void:
	var level := _greybox()
	var scene: GdUnitSceneRunner = await _jump_from(level, "PlaytestCourse/WallRun/Tower/Start")
	var runner := _runner_of(level)

	var runs := 0
	var start_heading := Vector3.ZERO
	var turned := 0.0
	for frame: int in 300:
		await scene.simulate_frames(1, 16)
		if runner.is_wall_running():
			if start_heading == Vector3.ZERO:
				runs += 1
				start_heading = _heading(runner)
			turned = maxf(turned, start_heading.angle_to(_heading(runner)))
			# Never slower than a Wall-run goes.
			assert_float(_horizontal_speed(runner)).is_greater_equal(_tuning.wall_run_end_speed)
		elif start_heading != Vector3.ZERO:
			break

	# One run that turned well past an eighth of the way round.
	assert_int(runs).is_equal(1)
	assert_float(rad_to_deg(turned)).is_greater(60.0)


func test_a_wall_run_ends_at_the_sharp_corner_and_flies_on_past_it() -> void:
	var level := _greybox()
	var start := "PlaytestCourse/WallRun/SharpCorner/Start"
	var scene: GdUnitSceneRunner = await _jump_from(level, start)
	var runner := _runner_of(level)
	var corner := level.get_node("PlaytestCourse/WallRun/SharpCorner/Corner") as Node3D

	var ran := false
	for frame: int in 300:
		await scene.simulate_frames(1, 16)
		if runner.is_wall_running():
			ran = true
		elif ran:
			break

	assert_bool(ran).is_true()
	# The run ended in the air at the corner, heading on along the wall it ran.
	var at_end := corner.to_local(runner.global_position)
	assert_float(at_end.x).is_between(-0.5, 0.5)
	assert_bool(runner.is_on_floor()).is_false()
	var heading := corner.global_basis.inverse() * _heading(runner)
	assert_float(heading.x).is_greater(0.99)
	# Flying past the corner, never wrapping round it.
	await scene.simulate_frames(20, 16)
	assert_float(corner.to_local(runner.global_position).x).is_greater(1.0)
	assert_bool(runner.is_wall_running()).is_false()


func test_a_wall_run_carries_on_around_the_inside_corner() -> void:
	var level := _greybox()
	var start := "PlaytestCourse/WallRun/InsideCorner/Start"
	var scene: GdUnitSceneRunner = await _jump_from(level, start)
	var runner := _runner_of(level)
	var next_wall := level.get_node("PlaytestCourse/WallRun/InsideCorner/NextWall") as Node3D
	var along_next := next_wall.global_basis.x.normalized()

	var started := false
	var turned := false
	var speed_before := 0.0
	for frame: int in 300:
		await scene.simulate_frames(1, 16)
		if not runner.is_wall_running():
			# The run must not end before it turns onto the next wall.
			assert_bool(started).is_false()
			continue
		started = true
		if _heading(runner).dot(along_next) > 0.999:
			turned = true
			break
		speed_before = _horizontal_speed(runner)

	assert_bool(turned).is_true()
	# Still the same run a few frames on, along the next wall, with its speed back: the
	# engine's collision took some of it on the frame the corner was met.
	await scene.simulate_frames(5, 16)
	assert_bool(runner.is_wall_running()).is_true()
	assert_float(_heading(runner).dot(along_next)).is_greater(0.999)
	assert_float(_horizontal_speed(runner)).is_greater(speed_before - 0.2)
