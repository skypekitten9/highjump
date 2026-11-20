extends GdUnitTestSuite
## The greybox level. It owns mouse capture: captured when play starts, freed on release_mouse,
## captured again on a click. The headless display server ignores mouse modes, so those tests
## read the level's own record of whether it has the mouse captured. Its playtest course has
## every area, labelled, and each feels as intended.

const GREYBOX := "res://levels/greybox/greybox.tscn"
## Collision layer the Runner is moved to, so a ray can find its body and nothing else.
const RUNNER_LAYER := 2

var _tuning: RunnerTuning


func before_test() -> void:
	_tuning = load("res://runner/default_runner_tuning.tres")


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.action_release("move_forward")
	Input.action_release("crouch")


func test_the_mouse_is_captured_when_play_starts() -> void:
	var scene := scene_runner(GREYBOX)
	await scene.simulate_frames(1)

	assert_bool((scene.scene() as Level).mouse_captured).is_true()


func test_release_mouse_frees_the_mouse() -> void:
	var scene := scene_runner(GREYBOX)
	await scene.simulate_frames(1)

	scene.simulate_action_pressed("release_mouse")
	await scene.await_input_processed()

	assert_bool((scene.scene() as Level).mouse_captured).is_false()


func test_a_click_captures_the_freed_mouse_again() -> void:
	var scene := scene_runner(GREYBOX)
	await scene.simulate_frames(1)
	scene.simulate_action_pressed("release_mouse")
	await scene.await_input_processed()

	scene.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await scene.await_input_processed()

	assert_bool((scene.scene() as Level).mouse_captured).is_true()


## Runs the greybox level with its Runner moved to [param start] (a node path in the level),
## facing the way it faces. Returns the scene runner.
func _greybox_with_runner_at(runner: Runner, start: String) -> GdUnitSceneRunner:
	var level: Node3D = runner.get_parent()
	var scene := scene_runner(level)
	runner.global_transform = (level.get_node(start) as Node3D).global_transform
	runner.collision_layer = RUNNER_LAYER
	return scene


## The Runner of a fresh greybox level, not yet in the tree.
func _greybox_runner() -> Runner:
	var level: Node3D = auto_free((load(GREYBOX) as PackedScene).instantiate())
	return level.get_node("Runner")


func _horizontal_speed(runner: Runner) -> float:
	return Vector2(runner.velocity.x, runner.velocity.z).length()


func _on_flat_floor(runner: Runner) -> bool:
	return runner.is_on_floor() and runner.get_floor_normal().y > 0.999


func test_a_held_slide_down_the_long_steep_slope_hits_top_slide_speed_before_the_bottom() -> void:
	var runner := _greybox_runner()
	var scene := _greybox_with_runner_at(runner, "PlaytestCourse/LongSteepSlope/SlideStart")
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
	var level: Node3D = auto_free((load(GREYBOX) as PackedScene).instantiate())
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
	var runner := _greybox_runner()
	var scene := _greybox_with_runner_at(runner, "PlaytestCourse/CrouchTunnel/Approach")
	await scene.simulate_frames(10, 16)

	# Crouch-walk in, then let go of crouch once well inside.
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
