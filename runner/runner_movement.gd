class_name RunnerMovement
extends RefCounted
## Turns what the Player asks for and the Runner's body state into the Runner's next velocity.
## Never touches nodes, so it can be stepped frame by frame without a scene. It continues from
## whatever velocity it is given, so other mechanics can hand speed to it (see docs/adr/0004).

## Speed away from the floor plane above which a floor contact is ignored (leaving it), m/s.
const LEAVE_FLOOR_SPEED := 0.5
## Floor normals flatter than this (y component) are too steep to stand on or project onto.
const MIN_FLOOR_NORMAL_Y := 0.1


## Returns the Runner's velocity for this physics frame.
## [param wish]: world-space horizontal move direction, length 0..1.
## [param floor_normal]: the floor's normal; ignored when [param on_floor] is false.
func step(
	wish: Vector3,
	velocity: Vector3,
	on_floor: bool,
	floor_normal: Vector3,
	tuning: RunnerTuning,
	delta: float,
) -> Vector3:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if not _is_grounded(velocity, on_floor, floor_normal):
		return Vector3(horizontal.x, velocity.y - tuning.gravity * delta, horizontal.z)
	horizontal = _ground_horizontal(horizontal, wish, tuning, delta)
	# Keep velocity in the floor plane (v . n = 0) without changing horizontal speed.
	var n := floor_normal
	var vertical := -(horizontal.x * n.x + horizontal.z * n.z) / n.y
	return Vector3(horizontal.x, vertical, horizontal.z)


## On the floor and not already leaving it, so the take-off frame isn't snapped back down.
func _is_grounded(velocity: Vector3, on_floor: bool, floor_normal: Vector3) -> bool:
	return (
		on_floor and floor_normal.y > MIN_FLOOR_NORMAL_Y
		and velocity.dot(floor_normal) <= LEAVE_FLOOR_SPEED
	)


func _ground_horizontal(
	horizontal: Vector3,
	wish: Vector3,
	tuning: RunnerTuning,
	delta: float,
) -> Vector3:
	if wish.is_zero_approx():
		return horizontal.move_toward(Vector3.ZERO, tuning.ground_friction * delta)
	# Speed above Run speed fades gradually; the allowed speed never drops below Run speed.
	var limit := maxf(tuning.run_speed, horizontal.length() - tuning.overspeed_decay * delta)
	var result := horizontal.move_toward(wish * limit, tuning.ground_accel * delta)
	return result.limit_length(limit)
