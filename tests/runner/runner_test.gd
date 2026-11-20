extends GdUnitTestSuite
## The Runner scene in a physics world: it falls under gravity and lands on a floor.

const RunnerScene := preload("res://runner/runner.tscn")
## Collision layer the Runner is moved to, so a ray can find its body and nothing else.
const RUNNER_LAYER := 2
## Underside of the ceiling in the crouch tests: too low to stand, high enough to crouch, m.
const CEILING_BOTTOM := 1.3
## The ceiling spans z from 0 to this, m.
const CEILING_FAR_EDGE := -4.0

var _tuning: RunnerTuning


func before_test() -> void:
	_tuning = load("res://runner/default_runner_tuning.tres")


func after_test() -> void:
	Input.action_release("move_forward")
	Input.action_release("crouch")


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


func test_runner_placed_above_the_floor_falls_and_lands() -> void:
	var world := _world_with_floor()
	var runner: Runner = RunnerScene.instantiate()
	runner.position.y = 2.0
	world.add_child(runner)
	var scene := scene_runner(world)

	await scene.simulate_frames(10, 16)
	assert_float(runner.position.y).is_less(2.0)

	await scene.simulate_frames(90, 16)
	assert_bool(runner.is_on_floor()).is_true()
	assert_float(runner.velocity.y).is_equal_approx(0.0, 0.01)
	assert_float(runner.position.y).is_equal_approx(0.0, 0.05)


## A 45 degree ramp rising 2 m toward -Z from z = 0, with a flat 2 m high top beyond it.
func _world_with_45_degree_ramp() -> Node3D:
	var world := _world_with_floor()
	var ramp := StaticBody3D.new()
	var ramp_shape := CollisionShape3D.new()
	var wedge := ConvexPolygonShape3D.new()
	wedge.points = PackedVector3Array(
		[
			Vector3(-1.5, 0.0, 0.0),
			Vector3(1.5, 0.0, 0.0),
			Vector3(-1.5, 0.0, -2.0),
			Vector3(1.5, 0.0, -2.0),
			Vector3(-1.5, 2.0, -2.0),
			Vector3(1.5, 2.0, -2.0),
		]
	)
	ramp_shape.shape = wedge
	ramp.add_child(ramp_shape)
	world.add_child(ramp)
	var top := StaticBody3D.new()
	var top_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 2.0, 8.0)
	top_shape.shape = box
	top_shape.position = Vector3(0.0, 1.0, -6.0)
	top.add_child(top_shape)
	world.add_child(top)
	return world


func test_running_up_a_45_degree_ramp_onto_its_flat_top_stays_on_the_ground() -> void:
	var world := _world_with_45_degree_ramp()
	var runner: Runner = RunnerScene.instantiate()
	runner.position.z = 3.0
	world.add_child(runner)
	var scene := scene_runner(world)
	await scene.simulate_frames(10, 16)

	Input.action_press("move_forward")
	var highest := 0.0
	for frame: int in 80:
		await scene.simulate_frames(1, 16)
		highest = maxf(highest, runner.position.y)
		# Well onto the top, short of its far edge whatever the Run speed.
		if runner.position.z < -5.0:
			break
	Input.action_release("move_forward")

	assert_float(runner.position.z).is_less(-3.0)
	# On the 2 m top, with no launch over the crest.
	assert_float(highest).is_less(2.05)
	assert_bool(runner.is_on_floor()).is_true()


## Letting go of the move input stops the Runner quickly only on the ground; in the air it keeps
## its speed. So stopping partway down the ramp shows it was on the ground there.
func test_letting_go_partway_down_a_45_degree_ramp_stops_the_runner_on_the_ramp() -> void:
	var world := _world_with_45_degree_ramp()
	var runner: Runner = RunnerScene.instantiate()
	# On the flat top, facing -Z, so running back runs down the ramp toward +Z.
	runner.position = Vector3(0.0, 2.0, -4.0)
	world.add_child(runner)
	var scene := scene_runner(world)
	await scene.simulate_frames(10, 16)

	Input.action_press("move_back")
	for frame: int in 60:
		await scene.simulate_frames(1, 16)
		if runner.position.z > -1.6:
			break
	Input.action_release("move_back")
	await scene.simulate_frames(30, 16)

	# Stopped on the ramp, short of its foot at z = 0.
	assert_float(runner.position.z).is_less(-0.5)
	assert_float(runner.position.y).is_greater(0.5)
	assert_float(runner.velocity.length()).is_equal_approx(0.0, 0.01)
	assert_bool(runner.is_on_floor()).is_true()


## A floor with a ceiling slab over it from z = 0 to the far edge, its underside at
## [param bottom]. The slab is a box body, or a CSG box when [param csg] is true.
func _world_with_ceiling(bottom: float, csg: bool) -> Node3D:
	var world := _world_with_floor()
	var size := Vector3(6.0, 0.5, -CEILING_FAR_EDGE)
	var center := Vector3(0.0, bottom + size.y / 2.0, CEILING_FAR_EDGE / 2.0)
	if csg:
		var slab := CSGBox3D.new()
		slab.size = size
		slab.position = center
		slab.use_collision = true
		world.add_child(slab)
		return world
	var ceiling := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	ceiling.add_child(shape)
	world.add_child(ceiling)
	return world


## A Runner on the floor at z = [param z], facing -Z, its body findable by [method _body_top].
func _add_runner(world: Node3D, z: float) -> Runner:
	var runner: Runner = RunnerScene.instantiate()
	runner.position.z = z
	runner.collision_layer = RUNNER_LAYER
	world.add_child(runner)
	return runner


## Height of the top of the Runner's body above its feet, measured by a ray down onto it.
func _body_top(runner: Runner) -> float:
	var above := runner.global_position + Vector3.UP * 10.0
	var ray := PhysicsRayQueryParameters3D.create(above, runner.global_position, RUNNER_LAYER)
	var hit := runner.get_world_3d().direct_space_state.intersect_ray(ray)
	assert_bool(hit.is_empty()).is_false()
	return (hit["position"] as Vector3).y - runner.global_position.y


func _eye_height(runner: Runner) -> float:
	return runner.get_viewport().get_camera_3d().global_position.y - runner.global_position.y


func test_the_body_is_low_while_crouching() -> void:
	var world := _world_with_floor()
	var runner := _add_runner(world, 0.0)
	var scene := scene_runner(world)
	await scene.simulate_frames(10, 16)
	assert_float(_body_top(runner)).is_greater(CEILING_BOTTOM)

	Input.action_press("crouch")
	await scene.simulate_frames(2, 16)
	assert_float(_body_top(runner)).is_equal_approx(_tuning.crouch_height, 0.02)
	# Feet stay on the floor.
	assert_float(runner.position.y).is_equal_approx(0.0, 0.05)

	Input.action_release("crouch")
	await scene.simulate_frames(2, 16)
	assert_float(_body_top(runner)).is_greater(CEILING_BOTTOM)


## Crouches under the ceiling, lets go of crouch there, then walks out past its far edge.
func _crouch_under_ceiling_then_walk_clear(csg: bool) -> void:
	var world := _world_with_ceiling(CEILING_BOTTOM, csg)
	var runner := _add_runner(world, 1.5)
	var scene := scene_runner(world)
	await scene.simulate_frames(10, 16)

	Input.action_press("crouch")
	Input.action_press("move_forward")
	for frame: int in 120:
		await scene.simulate_frames(1, 16)
		if runner.position.z < CEILING_FAR_EDGE / 2.0:
			break
	Input.action_release("move_forward")
	Input.action_release("crouch")
	await scene.simulate_frames(30, 16)
	# Got under, and stays low there with crouch released.
	assert_float(runner.position.z).is_less(-1.0)
	assert_float(_body_top(runner)).is_less(CEILING_BOTTOM)
	assert_float(runner.position.y).is_equal_approx(0.0, 0.05)

	Input.action_press("move_forward")
	for frame: int in 180:
		await scene.simulate_frames(1, 16)
		if runner.position.z < CEILING_FAR_EDGE - 1.0:
			break
	Input.action_release("move_forward")
	await scene.simulate_frames(5, 16)
	# Clear of the ceiling: standing again.
	assert_float(runner.position.z).is_less(CEILING_FAR_EDGE - 1.0)
	assert_float(_body_top(runner)).is_greater(CEILING_BOTTOM)


func test_under_a_box_ceiling_the_runner_stays_low_until_it_moves_clear() -> void:
	await _crouch_under_ceiling_then_walk_clear(false)


func test_under_a_csg_ceiling_the_runner_stays_low_until_it_moves_clear() -> void:
	await _crouch_under_ceiling_then_walk_clear(true)


func test_the_camera_eases_down_and_up_rather_than_snapping() -> void:
	var world := _world_with_floor()
	var runner := _add_runner(world, 0.0)
	var scene := scene_runner(world)
	await scene.simulate_frames(10, 16)
	var standing_eye := _eye_height(runner)
	# The eyes keep their distance below the top of the body.
	var low_eye := standing_eye - (_body_top(runner) - _tuning.crouch_height)
	var drop := standing_eye - low_eye

	Input.action_press("crouch")
	await scene.simulate_frames(1, 16)
	var eye := _eye_height(runner)
	# On its way down, but well short of the low eye height after a single frame.
	assert_float(eye).is_less(standing_eye - 0.01)
	assert_float(eye).is_greater(low_eye + drop * 0.5)
	for frame: int in 60:
		await scene.simulate_frames(1, 16)
		assert_float(_eye_height(runner)).is_less_equal(eye)
		eye = _eye_height(runner)
	assert_float(eye).is_equal_approx(low_eye, 0.01)

	Input.action_release("crouch")
	await scene.simulate_frames(1, 16)
	eye = _eye_height(runner)
	assert_float(eye).is_greater(low_eye + 0.01)
	assert_float(eye).is_less(standing_eye - drop * 0.5)
	await scene.simulate_frames(60, 16)
	assert_float(_eye_height(runner)).is_equal_approx(standing_eye, 0.01)


func test_the_camera_is_never_above_a_ceiling_overhead() -> void:
	# Just above the low body, so the eased camera would be dragged through it at Run speed.
	var bottom := _tuning.crouch_height + 0.1
	var world := _world_with_ceiling(bottom, false)
	var runner := _add_runner(world, 6.0)
	var scene := scene_runner(world)
	await scene.simulate_frames(10, 16)

	Input.action_press("move_forward")
	var under_frames := 0
	for frame: int in 120:
		await scene.simulate_frames(1, 16)
		# Crouch at the last moment before the body would hit the ceiling's edge.
		if runner.position.z < 0.6:
			Input.action_press("crouch")
		var camera := runner.get_viewport().get_camera_3d().global_position
		if camera.z < 0.0 and camera.z > CEILING_FAR_EDGE:
			under_frames += 1
			assert_float(camera.y).is_less(bottom)
		if runner.position.z < CEILING_FAR_EDGE / 2.0:
			break
	assert_int(under_frames).is_greater(0)
