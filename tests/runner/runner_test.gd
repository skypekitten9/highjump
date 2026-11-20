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
