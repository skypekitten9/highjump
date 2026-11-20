extends GdUnitTestSuite
## The Runner scene in a physics world: it falls under gravity and lands on a floor.

const RunnerScene := preload("res://runner/runner.tscn")
## Collision layer the Runner is moved to, so a ray can find its body and nothing else.
const RUNNER_LAYER := 2
## Underside of the ceiling in the crouch tests: too low to stand, high enough to crouch, m.
const CEILING_BOTTOM := 1.3
## The ceiling spans z from 0 to this, m.
const CEILING_FAR_EDGE := -4.0
## Slope of the long downhill ramp, degrees: steep enough for a Slide to gain speed.
const LONG_RAMP_SLOPE := 15.0
## The wall in the Wall-run test has its face at this x, m.
const WALL_FACE_X := 1.5
## The box in the Mantle tests has its face at this z, ahead of a Runner at the origin, m.
const BOX_FACE_Z := -0.6
## Radius of the Runner's body in its scene, m.
const RUNNER_RADIUS := 0.35
## Height of the Runner's standing body in its scene, m.
const RUNNER_HEIGHT := 1.8

var _tuning: RunnerTuning


func before_test() -> void:
	_tuning = load("res://runner/default_runner_tuning.tres")


func after_test() -> void:
	Input.action_release("move_forward")
	Input.action_release("move_right")
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


func test_moving_the_free_mouse_does_not_turn_the_camera() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world := _world_with_floor()
	var runner := _add_runner(world, 0.0)
	var scene := scene_runner(world)
	await scene.simulate_frames(1, 16)
	var facing := runner.get_viewport().get_camera_3d().global_basis

	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(200.0, 150.0)
	Input.parse_input_event(motion)
	await scene.simulate_frames(2, 16)

	var camera := runner.get_viewport().get_camera_3d().global_basis
	assert_bool(camera.is_equal_approx(facing)).is_true()


## Creating a Runner leaves the mouse mode as it was: whatever holds the Runner owns capture. The
## headless display server ignores mouse modes (setting one reads back as visible), so this
## checks that the Runner script never assigns one.
func test_the_runner_never_sets_the_mouse_mode() -> void:
	var source := (load("res://runner/runner.gd") as GDScript).source_code
	var assigns_mouse_mode := RegEx.create_from_string(r"mouse_mode\s*=[^=]")

	assert_object(assigns_mouse_mode.search(source)).is_null()


func test_runner_placed_above_the_floor_falls_and_lands() -> void:
	var world := _world_with_floor()
	var runner: Runner = RunnerScene.instantiate()
	# Stands still unless the test holds forward.
	runner.holds_forward = false
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
	# Stands still unless the test holds forward.
	runner.holds_forward = false
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
	# Stands still unless the test holds forward.
	runner.holds_forward = false
	# On the flat top, facing +Z, so running forward runs down the ramp toward +Z.
	runner.position = Vector3(0.0, 2.0, -4.0)
	runner.rotation.y = PI
	world.add_child(runner)
	var scene := scene_runner(world)
	await scene.simulate_frames(10, 16)

	Input.action_press("move_forward")
	for frame: int in 60:
		await scene.simulate_frames(1, 16)
		if runner.position.z > -1.6:
			break
	Input.action_release("move_forward")
	await scene.simulate_frames(30, 16)

	# Stopped on the ramp, short of its foot at z = 0.
	assert_float(runner.position.z).is_less(-0.5)
	assert_float(runner.position.y).is_greater(0.5)
	assert_float(runner.velocity.length()).is_equal_approx(0.0, 0.01)
	assert_bool(runner.is_on_floor()).is_true()


## A long ramp sloping down toward -Z by [constant LONG_RAMP_SLOPE], about 29 m long, its middle
## at the origin. No floor around it.
func _world_with_long_downhill_ramp() -> Node3D:
	var world: Node3D = auto_free(Node3D.new())
	var ramp := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 1.0, 30.0)
	shape.shape = box
	ramp.add_child(shape)
	ramp.rotation.x = -deg_to_rad(LONG_RAMP_SLOPE)
	world.add_child(ramp)
	return world


## Height of the long ramp's surface at [param z], m.
func _long_ramp_height(z: float) -> float:
	var slope := deg_to_rad(LONG_RAMP_SLOPE)
	return 0.5 / cos(slope) + z * tan(slope)


func test_a_slide_down_a_ramp_stays_on_the_ground_and_ends_faster_than_it_started() -> void:
	var world := _world_with_long_downhill_ramp()
	var runner := _add_runner(world, 12.0)
	runner.position.y = _long_ramp_height(12.0) + 0.05
	var scene := scene_runner(world)
	await scene.simulate_frames(10, 16)

	# Run downhill up to Run speed, then crouch into a Slide.
	Input.action_press("move_forward")
	await scene.simulate_frames(10, 16)
	Input.action_press("crouch")
	await scene.simulate_frames(2, 16)
	var start := Vector2(runner.velocity.x, runner.velocity.z).length()
	assert_float(start).is_greater_equal(_tuning.slide_entry_speed)
	var frames := 0
	while runner.position.z > -8.0 and frames < 180:
		await scene.simulate_frames(1, 16)
		frames += 1
		assert_bool(runner.is_on_floor()).is_true()
	Input.action_release("move_forward")

	assert_float(runner.position.z).is_less_equal(-8.0)
	# Still sliding: low, and faster than when the Slide began.
	assert_float(_body_top(runner)).is_equal_approx(_tuning.crouch_height, 0.02)
	assert_float(Vector2(runner.velocity.x, runner.velocity.z).length()).is_greater(start + 2.0)


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


## A Runner on the floor at z = [param z], facing -Z and not holding forward, its body findable
## by [method _body_top]. Uses [param tuning] if given, otherwise the default tuning.
func _add_runner(world: Node3D, z: float, tuning: RunnerTuning = null) -> Runner:
	var runner: Runner = RunnerScene.instantiate()
	# Stands still unless the test holds forward.
	runner.holds_forward = false
	if tuning != null:
		runner.tuning = tuning
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
	Input.action_release("move_right")
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


## A wide floor with a straight wall 6 m tall along -Z, its face at x = [param face_x]: to the
## right of a Runner at x = 0 facing -Z, or to its left if negative.
func _world_with_wall(face_x := WALL_FACE_X) -> Node3D:
	var world: Node3D = auto_free(Node3D.new())
	var floor_box := CSGBox3D.new()
	floor_box.size = Vector3(80.0, 1.0, 80.0)
	floor_box.position.y = -0.5
	floor_box.use_collision = true
	world.add_child(floor_box)
	var wall := CSGBox3D.new()
	wall.size = Vector3(1.0, 6.0, 60.0)
	wall.position = Vector3(face_x + signf(face_x) * 0.5, 3.0, -20.0)
	wall.use_collision = true
	world.add_child(wall)
	return world


## Jumps at the wall in [param world], turned [param turn] degrees toward it (negative turns
## right), and Wall-runs along it, holding forward. Returns the scene runner once the jump has
## been pressed.
func _jump_at_wall(world: Node3D, runner: Runner, turn := -20.0) -> GdUnitSceneRunner:
	runner.rotate_y(deg_to_rad(turn))
	var scene := scene_runner(world)
	await scene.simulate_frames(10, 16)
	Input.action_press("move_forward")
	await scene.simulate_frames(10, 16)
	Input.action_press("jump")
	await scene.simulate_frames(1, 16)
	Input.action_release("jump")
	return scene


func test_jumping_at_a_wall_at_an_angle_wall_runs_along_it_then_lands() -> void:
	var world := _world_with_wall()
	var runner := _add_runner(world, 0.0)
	# Facing 20 degrees to the right of -Z, toward the wall.
	var scene: GdUnitSceneRunner = await _jump_at_wall(world, runner, -20.0)

	var run_start := Vector3.INF
	var run_end := Vector3.INF
	for frame: int in 300:
		await scene.simulate_frames(1, 16)
		if runner.is_wall_running():
			if run_start == Vector3.INF:
				run_start = runner.global_position
			run_end = runner.global_position
			# Running along the wall, fast, and never into or away from it.
			assert_float(absf(runner.velocity.x)).is_less(0.01)
			assert_float(-runner.velocity.z).is_greater_equal(_tuning.wall_run_end_speed)
		elif run_start != Vector3.INF and runner.is_on_floor():
			break

	assert_bool(run_start == Vector3.INF).is_false()
	# Ran several metres along the wall, touching it, before landing.
	assert_float(run_start.z - run_end.z).is_greater(5.0)
	assert_float(run_end.x).is_equal_approx(WALL_FACE_X - RUNNER_RADIUS, 0.05)
	assert_bool(runner.is_on_floor()).is_true()
	assert_bool(runner.is_wall_running()).is_false()


func test_a_wall_run_keeps_to_the_wall_on_frames_the_body_does_not_touch_it() -> void:
	var world := _world_with_wall()
	var runner := _add_runner(world, 0.0)
	var scene: GdUnitSceneRunner = await _jump_at_wall(world, runner)

	# Running straight along the wall, the body's move mostly doesn't collide with it; the Runner
	# finds the wall by looking for it instead.
	var running_frames := 0
	var untouched_frames := 0
	for frame: int in 300:
		await scene.simulate_frames(1, 16)
		if not runner.is_wall_running():
			if running_frames > 0:
				break
			continue
		running_frames += 1
		if runner.get_slide_collision_count() == 0:
			untouched_frames += 1

	assert_int(running_frames).is_greater(30)
	assert_int(untouched_frames).is_greater(running_frames / 2)


func test_landing_on_a_ramp_during_a_wall_run_ends_it_on_the_ramp() -> void:
	var world := _world_with_wall()
	# Rising 20 degrees along the wall from z = -6, under where the run comes down.
	var slope := deg_to_rad(20.0)
	var ramp := CSGBox3D.new()
	ramp.size = Vector3(4.0, 1.0, 20.0)
	ramp.rotation.x = slope
	var surface_normal := Vector3(0.0, cos(slope), sin(slope))
	var uphill := Vector3(0.0, sin(slope), -cos(slope))
	var foot := Vector3(WALL_FACE_X - 2.0, 0.0, -6.0)
	ramp.position = foot - surface_normal * ramp.size.y / 2.0 + uphill * ramp.size.z / 2.0
	ramp.use_collision = true
	world.add_child(ramp)
	var runner := _add_runner(world, 0.0)
	var scene: GdUnitSceneRunner = await _jump_at_wall(world, runner)

	var ran := false
	for frame: int in 300:
		await scene.simulate_frames(1, 16)
		if runner.is_wall_running():
			ran = true
		elif ran:
			break

	assert_bool(ran).is_true()
	assert_bool(runner.is_wall_running()).is_false()
	# Ended as the run came down onto the ramp (about 1.6 m up it), not further up it, with the
	# feet on it, and then runs on up it.
	var ramp_height := (foot.z - runner.global_position.z) * tan(slope)
	assert_float(ramp_height).is_between(0.3, 2.5)
	assert_float(runner.global_position.y).is_equal_approx(ramp_height, 0.1)
	await scene.simulate_frames(2, 16)
	assert_bool(runner.is_on_floor()).is_true()
	assert_float(runner.get_floor_normal().angle_to(surface_normal)).is_less(0.01)


func test_bumping_a_ceiling_during_a_wall_run_does_not_end_it() -> void:
	var world := _world_with_wall()
	# Low enough over the middle of the run for the top of the body to hit it.
	var ceiling := CSGBox3D.new()
	ceiling.size = Vector3(4.0, 0.5, 17.5)
	ceiling.position = Vector3(WALL_FACE_X - 2.0, 3.55, -11.25)
	ceiling.use_collision = true
	world.add_child(ceiling)
	var highest_feet := ceiling.position.y - ceiling.size.y / 2.0 - RUNNER_HEIGHT
	var runner := _add_runner(world, 0.0)
	var scene: GdUnitSceneRunner = await _jump_at_wall(world, runner)

	# A frame may hold more than one physics step, so the step that touches the ceiling can go
	# unseen; the body stays up against it for several steps, so its height is what is checked.
	var ran := false
	var peak := -INF
	for frame: int in 300:
		await scene.simulate_frames(1, 16)
		if runner.is_wall_running():
			ran = true
			peak = maxf(peak, runner.global_position.y)
		elif ran:
			break

	# Rose until the top of the body met the ceiling.
	assert_float(peak).is_equal_approx(highest_feet, 0.05)
	# The run went on until it landed: it ended with the feet on the floor.
	assert_bool(runner.is_wall_running()).is_false()
	assert_float(runner.global_position.y).is_equal_approx(0.0, 0.05)


## How far the camera is rolled to the left of level, degrees (negative is to the right).
func _camera_roll(runner: Runner) -> float:
	var camera_right := runner.get_viewport().get_camera_3d().global_basis.x
	return rad_to_deg(asin(clampf(camera_right.y, -1.0, 1.0)))


## Wall-runs [param runner] along the wall in [param world], turned [param turn] degrees toward
## it, until it lands. Returns the camera's roll on each frame of the run under "during", and on
## each of the 60 frames after it under "after".
func _camera_roll_through_wall_run(world: Node3D, runner: Runner, turn: float) -> Dictionary:
	var scene: GdUnitSceneRunner = await _jump_at_wall(world, runner, turn)
	var during: Array[float] = []
	var after: Array[float] = []
	for frame: int in 300:
		await scene.simulate_frames(1, 16)
		if runner.is_wall_running():
			during.append(_camera_roll(runner))
		elif not during.is_empty():
			after.append(_camera_roll(runner))
			if after.size() == 60:
				break
	return { "during": during, "after": after }


func test_a_wall_on_the_right_rolls_the_camera_left_easing_in_and_back_out() -> void:
	var world := _world_with_wall()
	var runner := _add_runner(world, 0.0)
	var roll: Dictionary = await _camera_roll_through_wall_run(world, runner, -20.0)
	var during: Array[float] = roll["during"]
	var after: Array[float] = roll["after"]
	var tilt := _tuning.wall_run_camera_tilt

	# A run long enough for the tilt to settle, and a landing to ease back from.
	assert_int(during.size()).is_greater(30)
	assert_int(after.size()).is_equal(60)
	# Eases in: rolls left a little on the first frame, and further on each frame after.
	assert_float(during[0]).is_greater(0.0)
	assert_float(during[0]).is_less(tilt * 0.5)
	for frame: int in range(1, during.size()):
		assert_float(during[frame]).is_greater_equal(during[frame - 1] - 0.01)
	assert_float(during[-1]).is_equal_approx(tilt, tilt * 0.05)
	# Eases out: still well rolled the frame after the run, then back to level.
	assert_float(after[0]).is_greater(tilt * 0.5)
	assert_float(after[0]).is_less(during[-1])
	assert_float(after[-1]).is_equal_approx(0.0, 0.05)


func test_the_camera_rolls_back_to_level_after_a_wall_jump() -> void:
	var world := _world_with_wall()
	var runner := _add_runner(world, 0.0)
	var scene: GdUnitSceneRunner = await _jump_at_wall(world, runner)
	var tilt := _tuning.wall_run_camera_tilt
	# Wall-run until the camera is well rolled, then Wall-jump off the wall.
	var running_frames := 0
	for frame: int in 300:
		await scene.simulate_frames(1, 16)
		if runner.is_wall_running():
			running_frames += 1
		if running_frames == 20:
			break
	assert_int(running_frames).is_equal(20)
	assert_float(_camera_roll(runner)).is_greater(tilt * 0.5)

	Input.action_press("jump")
	await scene.simulate_frames(1, 16)
	Input.action_release("jump")
	assert_bool(runner.is_wall_running()).is_false()
	# Eases back to level, never rolling further.
	var roll := _camera_roll(runner)
	for frame: int in 60:
		await scene.simulate_frames(1, 16)
		assert_float(_camera_roll(runner)).is_less_equal(roll + 0.01)
		roll = _camera_roll(runner)
	assert_float(roll).is_equal_approx(0.0, 0.05)


func test_a_wall_on_the_left_rolls_the_camera_right() -> void:
	var world := _world_with_wall(-WALL_FACE_X)
	var runner := _add_runner(world, 0.0)
	var roll: Dictionary = await _camera_roll_through_wall_run(world, runner, 20.0)
	var during: Array[float] = roll["during"]
	var tilt := _tuning.wall_run_camera_tilt

	assert_int(during.size()).is_greater(30)
	for frame_roll: float in during:
		assert_float(frame_roll).is_less(0.0)
	assert_float(during[-1]).is_equal_approx(-tilt, tilt * 0.05)


func test_with_the_tilt_at_zero_the_camera_never_rolls() -> void:
	var world := _world_with_wall()
	var no_tilt: RunnerTuning = _tuning.duplicate()
	no_tilt.wall_run_camera_tilt = 0.0
	var runner := _add_runner(world, 0.0, no_tilt)
	var roll: Dictionary = await _camera_roll_through_wall_run(world, runner, -20.0)
	var during: Array[float] = roll["during"]
	var after: Array[float] = roll["after"]

	assert_int(during.size()).is_greater(30)
	for frame_roll: float in during + after:
		assert_float(frame_roll).is_equal_approx(0.0, 0.001)


## Where the camera looks: yaw (left of -Z) and pitch (up from level), degrees.
func _camera_aim(runner: Runner) -> Vector2:
	var forward := -runner.get_viewport().get_camera_3d().global_basis.z
	var yaw := rad_to_deg(atan2(-forward.x, -forward.z))
	var pitch := rad_to_deg(asin(clampf(forward.y, -1.0, 1.0)))
	return Vector2(yaw, pitch)


func test_mouse_look_turns_and_pitches_the_camera_during_a_wall_run() -> void:
	var world := _world_with_wall()
	var runner := _add_runner(world, 0.0)
	var scene: GdUnitSceneRunner = await _jump_at_wall(world, runner)
	for frame: int in 60:
		await scene.simulate_frames(1, 16)
		if runner.is_wall_running():
			break
	# Well into the run, so the camera is rolled.
	await scene.simulate_frames(10, 16)
	assert_bool(runner.is_wall_running()).is_true()
	var before := _camera_aim(runner)

	# Left and up, by a known amount; small enough to keep the wall on the right.
	var relative := Vector2(-100.0, -80.0)
	runner.look(relative)

	var turned := -relative * rad_to_deg(_tuning.mouse_sensitivity)
	assert_vector(_camera_aim(runner) - before).is_equal_approx(turned, Vector2(0.5, 0.5))
	await scene.simulate_frames(1, 16)
	assert_bool(runner.is_wall_running()).is_true()
	assert_float(_camera_roll(runner)).is_greater(_tuning.wall_run_camera_tilt * 0.5)


## A wide floor with a box ahead of a Runner at the origin facing -Z: its face at z =
## [param face_z], its top [param top] above the floor.
func _world_with_box(top: float, face_z := BOX_FACE_Z) -> Node3D:
	var world := _world_with_floor()
	var box := CSGBox3D.new()
	box.size = Vector3(4.0, top, 4.0)
	box.position = Vector3(0.0, top / 2.0, face_z - 2.0)
	box.use_collision = true
	world.add_child(box)
	return world


func test_the_ledge_probe_finds_a_box_within_mantle_reach() -> void:
	var world := _world_with_box(1.0)
	var runner := _add_runner(world, 0.0)
	await scene_runner(world).simulate_frames(5, 16)

	var ledge := runner.find_ledge(Vector3.FORWARD)

	assert_object(ledge).is_not_null()
	assert_vector(ledge.normal).is_equal_approx(Vector3.BACK, Vector3.ONE * 0.01)
	assert_float(ledge.top_height).is_equal_approx(1.0, 0.02)
	assert_float(ledge.clear_height).is_greater_equal(RUNNER_HEIGHT)


func test_the_ledge_probe_finds_nothing_beyond_mantle_reach() -> void:
	var world := _world_with_box(_tuning.mantle_reach + 0.2)
	var runner := _add_runner(world, 0.0)
	await scene_runner(world).simulate_frames(5, 16)

	assert_object(runner.find_ledge(Vector3.FORWARD)).is_null()


func test_jumping_into_a_box_too_high_to_jump_onto_mantles_onto_it() -> void:
	# Higher than the jump alone reaches, within it plus Mantle reach.
	var top := _tuning.jump_height + 0.8
	var world := _world_with_box(top)
	var runner := _add_runner(world, 0.0)
	var scene := scene_runner(world)
	await scene.simulate_frames(5, 16)
	Input.action_press("move_forward")
	Input.action_press("jump")
	await scene.simulate_frames(1, 16)
	Input.action_release("jump")

	for frame: int in 120:
		await scene.simulate_frames(1, 16)
		# Wholly on top, or back on the floor in front of the box.
		var on_top := runner.position.z < BOX_FACE_Z - RUNNER_RADIUS
		if runner.is_on_floor() and (on_top or runner.position.y < 0.1):
			break
	Input.action_release("move_forward")

	assert_bool(runner.is_on_floor()).is_true()
	assert_float(runner.position.y).is_equal_approx(top, 0.05)
	assert_float(runner.position.z).is_less(BOX_FACE_Z - RUNNER_RADIUS)


## Adds a CSG box with collision of [param size], centered at [param center], to [param world].
func _add_csg_box(world: Node3D, size: Vector3, center: Vector3) -> void:
	var box := CSGBox3D.new()
	box.size = size
	box.position = center
	box.use_collision = true
	world.add_child(box)


## The box of [method _world_with_box] with a CSG slab over its whole top, its underside
## [param room] above the top. The slab's front is flush with the box's face.
func _world_with_ceiling_over_box(top: float, room: float) -> Node3D:
	var world := _world_with_box(top)
	var thickness := 0.3
	_add_csg_box(
		world,
		Vector3(4.0, thickness, 4.0),
		Vector3(0.0, top + room + thickness / 2.0, BOX_FACE_Z - 2.0),
	)
	return world


func test_the_ledge_probe_measures_the_room_under_a_ceiling_over_the_top() -> void:
	# The slab's own top is within Mantle reach: the probe must not take it for the ledge's top.
	var world := _world_with_ceiling_over_box(0.5, 0.7)
	var runner := _add_runner(world, 0.0)
	await scene_runner(world).simulate_frames(5, 16)

	var ledge := runner.find_ledge(Vector3.FORWARD)

	assert_object(ledge).is_not_null()
	assert_float(ledge.top_height).is_equal_approx(0.5, 0.02)
	assert_float(ledge.clear_height).is_equal_approx(0.7, 0.02)


func test_the_ledge_probe_finds_nothing_on_a_top_too_thin_to_stand_on() -> void:
	var world := _world_with_floor()
	var thin := RUNNER_RADIUS * 0.6
	_add_csg_box(world, Vector3(4.0, 1.0, thin), Vector3(0.0, 0.5, BOX_FACE_Z - thin / 2.0))
	var runner := _add_runner(world, 0.0)
	await scene_runner(world).simulate_frames(5, 16)

	assert_object(runner.find_ledge(Vector3.FORWARD)).is_null()


## The box of [method _world_with_box], its top 1 m up, with a CSG slab over the Runner's head
## that stops at the box's face: the way up to the top is blocked.
func _world_with_slab_over_runner() -> Node3D:
	var world := _world_with_box(1.0)
	var bottom := RUNNER_HEIGHT + 0.3
	var size := Vector3(4.0, 0.3, 3.0)
	_add_csg_box(world, size, Vector3(0.0, bottom + size.y / 2.0, BOX_FACE_Z + size.z / 2.0))
	return world


func test_the_ledge_probe_finds_nothing_when_something_overhead_blocks_the_way_up() -> void:
	var world := _world_with_slab_over_runner()
	var runner := _add_runner(world, 0.0)
	await scene_runner(world).simulate_frames(5, 16)

	assert_object(runner.find_ledge(Vector3.FORWARD)).is_null()


func test_jumping_into_a_box_with_room_only_to_crouch_on_top_mantles_into_a_crouch() -> void:
	var top := 1.0
	var room := (_tuning.crouch_height + RUNNER_HEIGHT) / 2.0
	var world := _world_with_ceiling_over_box(top, room)
	var runner := _add_runner(world, 0.0)
	var scene := scene_runner(world)
	await scene.simulate_frames(5, 16)
	Input.action_press("move_forward")
	Input.action_press("jump")
	await scene.simulate_frames(1, 16)
	Input.action_release("jump")

	for frame: int in 120:
		await scene.simulate_frames(1, 16)
		var on_top := runner.position.z < BOX_FACE_Z - RUNNER_RADIUS
		if runner.is_on_floor() and (on_top or runner.position.y < 0.1):
			break
	Input.action_release("move_forward")
	await scene.simulate_frames(5, 16)

	assert_bool(runner.is_on_floor()).is_true()
	assert_float(runner.position.y).is_equal_approx(top, 0.05)
	assert_float(runner.position.z).is_less(BOX_FACE_Z - RUNNER_RADIUS)
	assert_float(_body_top(runner)).is_equal_approx(_tuning.crouch_height, 0.02)


func test_steering_into_a_low_wall_during_a_wall_run_mantles_onto_its_top() -> void:
	# Tall enough to run along from a jump, its top within Mantle reach during the run.
	var top := 2.2
	var world := _world_with_floor()
	var thickness := 3.0
	_add_csg_box(
		world,
		Vector3(thickness, top, 60.0),
		Vector3(WALL_FACE_X + thickness / 2.0, top / 2.0, -20.0),
	)
	var runner := _add_runner(world, 0.0)
	var scene: GdUnitSceneRunner = await _jump_at_wall(world, runner)

	# Only a couple of frames in: once the middle of the body rises past the top, the run loses
	# the wall, and a frame may hold two physics steps.
	var running_frames := 0
	for frame: int in 60:
		await scene.simulate_frames(1, 16)
		if runner.is_wall_running():
			running_frames += 1
			if running_frames == 2:
				break
	assert_int(running_frames).is_equal(2)
	var speed_along := -runner.velocity.z
	# Steer into the wall, on the Runner's right: the run turns straight into a Mantle.
	Input.action_press("move_right")
	await scene.simulate_frames(1, 16)
	assert_bool(runner.is_mantling()).is_true()
	for frame: int in 120:
		await scene.simulate_frames(1, 16)
		if runner.is_on_floor():
			break
	Input.action_release("move_right")

	assert_bool(runner.is_on_floor()).is_true()
	assert_float(runner.position.y).is_equal_approx(top, 0.05)
	assert_float(runner.position.x).is_greater(WALL_FACE_X + RUNNER_RADIUS)
	# Still heading on along the wall, fast.
	assert_float(-runner.velocity.z).is_greater(speed_along * 0.5)


## Looks up by [param look_up] pixels of mouse movement, then jumps [param runner] into the box
## ahead, holding forward, until it lands after a Mantle. Calls [param on_mantle] once, on the
## Mantle's first frame, if given. Returns the camera's pitch relative to the mouse pitch on each
## frame of the Mantle under "during", and on each of the 60 frames after it under "after",
## degrees (negative is down).
func _camera_dip_through_mantle(
	world: Node3D,
	runner: Runner,
	look_up := 0.0,
	on_mantle := Callable(),
) -> Dictionary:
	var scene := scene_runner(world)
	await scene.simulate_frames(5, 16)
	runner.look(Vector2(0.0, -look_up))
	var head_pitch := look_up * rad_to_deg(_tuning.mouse_sensitivity)
	Input.action_press("move_forward")
	Input.action_press("jump")
	await scene.simulate_frames(1, 16)
	Input.action_release("jump")
	var during: Array[float] = []
	var after: Array[float] = []
	for frame: int in 300:
		await scene.simulate_frames(1, 16)
		if runner.is_mantling():
			if during.is_empty() and on_mantle.is_valid():
				on_mantle.call()
			during.append(_camera_aim(runner).y - head_pitch)
		elif not during.is_empty():
			after.append(_camera_aim(runner).y - head_pitch)
			if after.size() == 60:
				break
	Input.action_release("move_forward")
	return { "during": during, "after": after }


## Largest change from one pitch to the next in [param pitches], starting from [param start].
## A frame may hold two physics steps, so an eased change can be up to two steps' worth.
func _largest_step(start: float, pitches: Array[float]) -> float:
	var largest := 0.0
	var previous := start
	for pitch: float in pitches:
		largest = maxf(largest, absf(pitch - previous))
		previous = pitch
	return largest


func test_the_camera_dips_during_a_mantle_and_eases_back_to_the_mouse_pitch() -> void:
	var world := _world_with_box(_tuning.jump_height + 0.8)
	var runner := _add_runner(world, 0.0)
	# Looking up a little, by mouse pitch alone.
	var dip: Dictionary = await _camera_dip_through_mantle(world, runner, 40.0)
	var during: Array[float] = dip["during"]
	var after: Array[float] = dip["after"]
	var full := _tuning.mantle_camera_dip

	assert_int(during.size()).is_greater(5)
	assert_int(after.size()).is_equal(60)
	# Dips most of the way to the full dip, never past it, and eases back to the mouse pitch.
	assert_float(during.min()).is_less(-full * 0.5)
	assert_float(during.min()).is_greater_equal(-full - 0.01)
	assert_float(_largest_step(0.0, during + after)).is_less(full * 0.5)
	assert_float(after[-1]).is_equal_approx(0.0, 0.05)


func test_a_mantle_that_ends_early_eases_the_camera_back_to_level_without_a_jump() -> void:
	var world := _world_with_box(_tuning.jump_height + 0.8)
	var box: Node3D = world.get_child(world.get_child_count() - 1)
	var runner := _add_runner(world, 0.0)
	# The box drops away as the Mantle begins, so the leap falls back past its top in mid-air.
	var drop_box := func() -> void:
		box.position.y -= 50.0
	var dip: Dictionary = await _camera_dip_through_mantle(world, runner, 0.0, drop_box)
	var during: Array[float] = dip["during"]
	var after: Array[float] = dip["after"]
	var full := _tuning.mantle_camera_dip

	assert_int(after.size()).is_equal(60)
	assert_float(during[-1]).is_less(-full * 0.5)
	assert_float(_largest_step(during[-1], after)).is_less(full * 0.5)
	assert_float(after[-1]).is_equal_approx(0.0, 0.05)


func test_with_the_mantle_dip_at_zero_the_camera_stays_level() -> void:
	var world := _world_with_box(_tuning.jump_height + 0.8)
	var no_dip: RunnerTuning = _tuning.duplicate()
	no_dip.mantle_camera_dip = 0.0
	var runner := _add_runner(world, 0.0, no_dip)
	var dip: Dictionary = await _camera_dip_through_mantle(world, runner, 0.0)
	var during: Array[float] = dip["during"]
	var after: Array[float] = dip["after"]

	assert_int(during.size()).is_greater(5)
	for pitch: float in during + after:
		assert_float(pitch).is_equal_approx(0.0, 0.001)


## Asserts the ledge probe finds the box of [method _world_with_box] with its top
## [param top] above the floor.
func _assert_probe_finds_top(top: float) -> void:
	var world := _world_with_box(top)
	var runner := _add_runner(world, 0.0)
	await scene_runner(world).simulate_frames(5, 16)

	var ledge := runner.find_ledge(Vector3.FORWARD)

	assert_object(ledge).is_not_null()
	if ledge != null:
		assert_float(ledge.top_height).is_equal_approx(top, 0.02)


func test_the_ledge_probe_finds_a_top_just_under_mantle_reach() -> void:
	await _assert_probe_finds_top(_tuning.mantle_reach - 0.01)


## A thin CSG slab floating ahead of the Runner at the origin, its front face at
## [constant BOX_FACE_Z], its top [param top] above the floor: a lip with no face below it.
func _world_with_thin_lip(top: float, thickness: float) -> Node3D:
	var world := _world_with_floor()
	_add_csg_box(
		world,
		Vector3(4.0, thickness, 4.0),
		Vector3(0.0, top - thickness / 2.0, BOX_FACE_Z - 2.0),
	)
	return world


func test_the_ledge_probe_finds_a_thin_lip_just_under_mantle_reach() -> void:
	var top := _tuning.mantle_reach - 0.02
	var world := _world_with_thin_lip(top, 0.06)
	var runner := _add_runner(world, 0.0)
	await scene_runner(world).simulate_frames(5, 16)

	var ledge := runner.find_ledge(Vector3.FORWARD)

	assert_object(ledge).is_not_null()
	if ledge != null:
		assert_float(ledge.top_height).is_equal_approx(top, 0.02)


func test_the_ledge_probe_measures_the_room_under_a_ceiling_over_part_of_the_body() -> void:
	# A slab 0.7 m over the 0.5 m top, starting a little beyond where the body's middle would
	# stand on it: it is over the far part of the body only.
	var top := 0.5
	var room := 0.7
	var world := _world_with_box(top)
	var front := BOX_FACE_Z - RUNNER_RADIUS - 0.15
	var size := Vector3(4.0, 0.3, 3.0)
	_add_csg_box(world, size, Vector3(0.0, top + room + size.y / 2.0, front - size.z / 2.0))
	var runner := _add_runner(world, 0.0)
	await scene_runner(world).simulate_frames(5, 16)

	var ledge := runner.find_ledge(Vector3.FORWARD)

	assert_object(ledge).is_not_null()
	if ledge != null:
		assert_float(ledge.clear_height).is_equal_approx(room, 0.02)
