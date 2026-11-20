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
## Radius of the Runner's body in its scene, m.
const RUNNER_RADIUS := 0.35
## Height of the Runner's standing body in its scene, m.
const RUNNER_HEIGHT := 1.8

var _tuning: RunnerTuning


func before_test() -> void:
	_tuning = load("res://runner/default_runner_tuning.tres")


func after_test() -> void:
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


## A Runner on the floor at z = [param z], facing -Z, its body findable by [method _body_top].
## Uses [param tuning] if given, otherwise the default tuning.
func _add_runner(world: Node3D, z: float, tuning: RunnerTuning = null) -> Runner:
	var runner: Runner = RunnerScene.instantiate()
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
