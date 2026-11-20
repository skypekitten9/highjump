extends GdUnitTestSuite
## A Level owns mouse capture: captured when play starts, freed on release_mouse, captured again
## on a click. The headless display server ignores mouse modes, so these tests read the level's
## own record of whether it has the mouse captured.


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Runs a fresh, empty Level for one frame. Returns the scene runner.
func _run_level() -> GdUnitSceneRunner:
	var scene := scene_runner(auto_free(Level.new()))
	await scene.simulate_frames(1)
	return scene


func _mouse_captured(scene: GdUnitSceneRunner) -> bool:
	return (scene.scene() as Level).mouse_captured


func test_the_mouse_is_captured_when_play_starts() -> void:
	var scene := await _run_level()

	assert_bool(_mouse_captured(scene)).is_true()


func test_release_mouse_frees_the_mouse() -> void:
	var scene := await _run_level()

	scene.simulate_action_pressed("release_mouse")
	await scene.await_input_processed()

	assert_bool(_mouse_captured(scene)).is_false()


func test_a_click_captures_the_freed_mouse_again() -> void:
	var scene := await _run_level()
	scene.simulate_action_pressed("release_mouse")
	await scene.await_input_processed()

	scene.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await scene.await_input_processed()

	assert_bool(_mouse_captured(scene)).is_true()
