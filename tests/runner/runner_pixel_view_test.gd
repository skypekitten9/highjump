extends GdUnitTestSuite
## The Runner's pixelated view: the world is drawn into a low-res view 240 pixels tall, as wide as
## the window's aspect ratio allows, and scaled up over the whole window with nearest-neighbour
## filtering, seen through a camera that follows the head camera. The Course and greybox both get
## it, and the HUD and EndScreen draw sharp on top.

const RunnerScene := preload("res://runner/runner.tscn")
## Height of the pixelated view, pixels.
const VIEW_HEIGHT := 240
const COURSE := "res://course/course.tscn"
const GREYBOX := "res://levels/greybox/greybox.tscn"
## Where the Course tests here save the Best distance, so the Player's own is never touched.
const SAVE_PATH := "user://runner_pixel_view_test.save"

var _window_size: Vector2i


func before_test() -> void:
	_window_size = get_tree().root.size


func after_test() -> void:
	get_tree().root.size = _window_size
	DirAccess.remove_absolute(SAVE_PATH)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.action_release("move_forward")
	Input.action_release("crouch")
	Input.action_release("jump")


func _world_with_floor() -> Node3D:
	var world: Node3D = auto_free(Node3D.new())
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	world.add_child(floor_body)
	return world


func _add_runner(world: Node3D) -> Runner:
	var runner: Runner = RunnerScene.instantiate()
	# Stands still unless the test holds forward.
	runner.holds_forward = false
	world.add_child(runner)
	return runner


## The low-res view the Runner draws the world into.
func _pixel_view(runner: Runner) -> SubViewport:
	var views := runner.find_children("*", "SubViewport", true, false)
	assert_int(views.size()).is_equal(1)
	return views[0]


## What shows [param view] on screen.
func _screen_of(runner: Runner, view: SubViewport) -> TextureRect:
	for node: Node in runner.find_children("*", "TextureRect", true, false):
		var rect := node as TextureRect
		if rect.texture == view.get_texture():
			return rect
	return null


func test_the_world_is_drawn_240_pixels_tall_and_as_wide_as_the_window_aspect() -> void:
	get_tree().root.size = Vector2i(1920, 800)
	var runner := _add_runner(_world_with_floor())
	var scene := scene_runner(runner.get_parent())
	await scene.simulate_frames(2, 16)

	# 2.4:1, so 240 tall is 576 wide.
	assert_vector(_pixel_view(runner).size).is_equal(Vector2i(576, VIEW_HEIGHT))


func test_the_view_widens_when_the_window_does() -> void:
	get_tree().root.size = Vector2i(1600, 1200)
	var runner := _add_runner(_world_with_floor())
	var scene := scene_runner(runner.get_parent())
	await scene.simulate_frames(2, 16)
	# 4:3.
	assert_vector(_pixel_view(runner).size).is_equal(Vector2i(320, VIEW_HEIGHT))

	get_tree().root.size = Vector2i(2560, 1080)
	await scene.simulate_frames(2, 16)
	# 64:27.
	assert_vector(_pixel_view(runner).size).is_equal(Vector2i(569, VIEW_HEIGHT))


func test_the_view_is_scaled_up_over_the_whole_window_with_nearest_neighbour_filtering() -> void:
	var runner := _add_runner(_world_with_floor())
	var scene := scene_runner(runner.get_parent())
	await scene.simulate_frames(2, 16)

	var screen := _screen_of(runner, _pixel_view(runner))
	assert_object(screen).is_not_null()
	assert_bool(screen.is_visible_in_tree()).is_true()
	assert_int(screen.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	var window := runner.get_viewport().get_visible_rect()
	assert_vector(screen.get_global_rect().position).is_equal(window.position)
	assert_vector(screen.get_global_rect().size).is_equal(window.size)


func test_the_view_shows_the_runners_world() -> void:
	var runner := _add_runner(_world_with_floor())
	var scene := scene_runner(runner.get_parent())
	await scene.simulate_frames(2, 16)

	var view := _pixel_view(runner)
	assert_object(view.find_world_3d()).is_same(runner.get_world_3d())
	assert_object(view.get_camera_3d()).is_not_null()


## Asserts the pixel view's camera sees exactly what the head camera does.
func _assert_pixel_camera_matches_head(runner: Runner) -> void:
	var head := runner.get_viewport().get_camera_3d()
	var pixel := _pixel_view(runner).get_camera_3d()
	assert_bool(pixel.global_transform.is_equal_approx(head.global_transform)).is_true()
	assert_float(pixel.fov).is_equal(head.fov)


func test_the_pixel_camera_follows_the_head_camera_moving_looking_and_crouching() -> void:
	var runner := _add_runner(_world_with_floor())
	var scene := scene_runner(runner.get_parent())
	await scene.simulate_frames(10, 16)
	_assert_pixel_camera_matches_head(runner)

	Input.action_press("move_forward")
	await scene.simulate_frames(20, 16)
	assert_float(runner.position.z).is_less(-0.5)
	_assert_pixel_camera_matches_head(runner)

	runner.look(Vector2(150.0, -80.0))
	await scene.simulate_frames(1, 16)
	_assert_pixel_camera_matches_head(runner)

	# Each frame of the camera easing down.
	Input.action_press("crouch")
	for frame: int in 10:
		await scene.simulate_frames(1, 16)
		_assert_pixel_camera_matches_head(runner)


func test_the_pixel_camera_follows_the_head_camera_with_a_changed_fov() -> void:
	var tuning: RunnerTuning = (
		load("res://runner/default_runner_tuning.tres") as RunnerTuning
	).duplicate()
	tuning.fov = 100.0
	var runner: Runner = RunnerScene.instantiate()
	runner.holds_forward = false
	runner.tuning = tuning
	var world := _world_with_floor()
	world.add_child(runner)
	var scene := scene_runner(world)
	await scene.simulate_frames(2, 16)

	assert_float(_pixel_view(runner).get_camera_3d().fov).is_equal(100.0)


func test_the_pixel_camera_rolls_with_the_head_camera_during_a_wall_run() -> void:
	var world: Node3D = auto_free(Node3D.new())
	var floor_box := CSGBox3D.new()
	floor_box.size = Vector3(80.0, 1.0, 80.0)
	floor_box.position.y = -0.5
	floor_box.use_collision = true
	world.add_child(floor_box)
	var wall := CSGBox3D.new()
	wall.size = Vector3(1.0, 6.0, 60.0)
	wall.position = Vector3(2.0, 3.0, -20.0)
	wall.use_collision = true
	world.add_child(wall)
	var runner := _add_runner(world)
	# Facing 20 degrees to the right of -Z, toward the wall.
	runner.rotate_y(deg_to_rad(-20.0))
	var scene := scene_runner(world)
	await scene.simulate_frames(10, 16)
	Input.action_press("move_forward")
	await scene.simulate_frames(10, 16)
	Input.action_press("jump")
	await scene.simulate_frames(1, 16)
	Input.action_release("jump")

	var running_frames := 0
	for frame: int in 300:
		await scene.simulate_frames(1, 16)
		if runner.is_wall_running():
			running_frames += 1
			_assert_pixel_camera_matches_head(runner)
		if running_frames == 30:
			break
	assert_int(running_frames).is_equal(30)
	# Well rolled by now, so the match covers the roll.
	var roll := runner.get_viewport().get_camera_3d().global_basis.x.y
	assert_float(absf(roll)).is_greater(0.05)


## Asserts [param ui] draws at full resolution: in the window itself, not in the Runner's low-res
## view, and on top of it.
func _assert_drawn_sharp_over_the_pixel_view(ui: CanvasLayer, runner: Runner) -> void:
	assert_object(ui.get_viewport()).is_same(runner.get_viewport())
	assert_bool(_pixel_view(runner).is_ancestor_of(ui)).is_false()
	var screen := _screen_of(runner, _pixel_view(runner))
	assert_int(ui.layer).is_greater(screen.get_canvas_layer_node().layer)


func test_the_course_draws_the_world_pixelated_with_the_hud_and_end_screen_sharp_on_top() -> void:
	var course: Course = auto_free((load(COURSE) as PackedScene).instantiate())
	course.best_distance_path = SAVE_PATH
	var scene := scene_runner(course)
	await scene.simulate_frames(2, 16)

	var runner: Runner = course.get_node("Runner")
	assert_object(_pixel_view(runner).find_world_3d()).is_same(course.get_world_3d())
	assert_int(_pixel_view(runner).size.y).is_equal(VIEW_HEIGHT)
	_assert_drawn_sharp_over_the_pixel_view(course.get_node("Hud") as CanvasLayer, runner)
	_assert_drawn_sharp_over_the_pixel_view(course.get_node("EndScreen") as CanvasLayer, runner)


func test_the_greybox_draws_the_world_pixelated() -> void:
	var level: Level = auto_free((load(GREYBOX) as PackedScene).instantiate())
	var runner: Runner = level.get_node("Runner")
	runner.holds_forward = false
	var scene := scene_runner(level)
	await scene.simulate_frames(2, 16)

	assert_object(_pixel_view(runner).find_world_3d()).is_same(level.get_world_3d())
	assert_int(_pixel_view(runner).size.y).is_equal(VIEW_HEIGHT)
	_assert_pixel_camera_matches_head(runner)
