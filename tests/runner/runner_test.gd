extends GdUnitTestSuite
## The Runner scene in a physics world: it falls under gravity and lands on a floor.

const RunnerScene := preload("res://runner/runner.tscn")


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
	Input.action_release("move_forward")

	assert_float(runner.position.z).is_less(-3.0)
	# On the 2 m top, with no launch over the crest.
	assert_float(highest).is_less(2.05)
	assert_bool(runner.is_on_floor()).is_true()
