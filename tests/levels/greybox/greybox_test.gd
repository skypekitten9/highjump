extends GdUnitTestSuite
## The greybox level owns mouse capture: captured when play starts, freed on release_mouse,
## captured again on a click. The headless display server ignores mouse modes, so these read
## the level's own record of whether it has the mouse captured.

const GREYBOX := "res://levels/greybox/greybox.tscn"


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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
