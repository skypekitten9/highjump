class_name Runner
extends CharacterBody3D
## The body the Player controls, seen from its own eyes. Reads input and does mouse look;
## velocity and whether the body is low are decided by RunnerMovement once per physics frame.
## Reports whether there is headroom to stand, which wall the body touches and the ledge ahead,
## sizes the body as RunnerMovement says, and eases the camera's height after it and its roll
## during a Wall-run.

const PITCH_LIMIT := deg_to_rad(89.0)
## How far beyond the body the ledge probe looks for a ledge's face, m.
const LEDGE_PROBE_AHEAD := 0.3
## The ledge probe only finds tops at least this far above the feet, so it never takes the floor
## under the Runner for a top, m.
const LEDGE_MIN_TOP := 0.05
## Spacing of the ledge probe's rays up a face, from just above the feet to Mantle reach, m.
const LEDGE_PROBE_SPACING := 0.2

## The feel values for this Runner.
@export var tuning: RunnerTuning = preload("res://runner/default_runner_tuning.tres")

var _movement: RunnerMovement
var _capsule: CapsuleShape3D
var _standing_height := 0.0
## How far the eyes sit below the top of the body, standing or low, m.
var _eye_below_top := 0.0
var _body_low := false

@onready var _body: CollisionShape3D = $Body
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera


func _ready() -> void:
	# Own copy, so resizing it never touches the scene's shared sub-resource.
	_capsule = (_body.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	_body.shape = _capsule
	_standing_height = _capsule.height
	_movement = RunnerMovement.new(tuning, _standing_height)
	_eye_below_top = _standing_height - _head.position.y
	_camera.fov = tuning.fov
	floor_snap_length = tuning.floor_snap_length


## Turns the camera only while the mouse is captured. Never captures or frees it: whatever
## holds the Runner (a level, later a menu) owns that.
func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var motion := event as InputEventMouseMotion
	if motion:
		look(motion.relative)


func _physics_process(delta: float) -> void:
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := global_basis * Vector3(move.x, 0.0, move.y)
	wish.y = 0.0
	var on_floor := is_on_floor()
	var floor_normal := get_floor_normal() if on_floor else Vector3.UP
	var intent := RunnerMovement.Intent.new(
		wish,
		Input.is_action_just_pressed("jump"),
		Input.is_action_pressed("crouch"),
	)
	var contact := RunnerMovement.Contact.new(
		on_floor,
		floor_normal,
		_has_headroom(),
		_touched_wall(),
		null if on_floor else find_ledge(wish),
	)
	velocity = _movement.step(intent, contact, velocity, delta)
	_set_body_low(_movement.is_low())
	move_and_slide()
	# The engine never snaps while velocity points up, which would lift the Runner off the
	# floor every other frame up a ramp and launch it over the crest.
	if _movement.is_on_ground():
		apply_floor_snap()
	_ease_camera(delta)


## True if the Runner is in a Wall-run.
func is_wall_running() -> bool:
	return _movement.state() == RunnerMovement.State.WALL_RUN


## True if the Runner is in a Mantle.
func is_mantling() -> bool:
	return _movement.state() == RunnerMovement.State.MANTLE


## The ledge ahead in [param direction]: a face near enough vertical to be a wall, just ahead
## of the body, whose top is above the feet and within Mantle reach. Null if there is none, or
## no direction. Looks down onto the top a body radius inside the edge, from the first height up
## the face where the way ahead is open, so a ceiling over the top isn't taken for the top. Then
## measures the room above the top with a ray, and finds nothing if the body, as it is now,
## can't rise straight up until its feet are level with the top (a shape overlap query misses
## CSG and trimesh ceilings).
func find_ledge(direction: Vector3) -> RunnerMovement.LedgeContact:
	var heading := Vector3(direction.x, 0.0, direction.z)
	if heading.is_zero_approx():
		return null
	var face := _ledge_face(heading.normalized())
	if face.is_empty():
		return null
	var normal: Vector3 = face["normal"]
	var face_point: Vector3 = face["position"]
	var inside := face_point - Vector3(normal.x, 0.0, normal.z).normalized() * _capsule.radius
	var feet := global_position.y
	var opening: float = face["opening"]
	var top_hit := _cast(
		Vector3(inside.x, feet + opening, inside.z),
		Vector3(inside.x, feet + LEDGE_MIN_TOP, inside.z),
	)
	if top_hit.is_empty() or (top_hit["normal"] as Vector3).y < cos(floor_max_angle):
		return null
	var top: Vector3 = top_hit["position"]
	if test_move(global_transform, Vector3.UP * (top.y - feet)):
		return null
	var above := _cast(top, top + Vector3.UP * _standing_height)
	var clear := INF if above.is_empty() else (above["position"] as Vector3).y - top.y
	return RunnerMovement.LedgeContact.new(normal, top.y - feet, clear)


## Turns the body and pitches the head by [param relative] pixels of mouse movement. Leaves the
## camera's Wall-run roll alone.
func look(relative: Vector2) -> void:
	rotate_y(-relative.x * tuning.mouse_sensitivity)
	_head.rotation.x = clampf(
		_head.rotation.x - relative.y * tuning.mouse_sensitivity,
		-PITCH_LIMIT,
		PITCH_LIMIT,
	)


## The wall the body touches: the most nearly vertical wall the last move collided with, or else,
## during a Wall-run, the wall found by a short probe toward the wall being run; null if none.
## Floors and ceilings the move hit are left out, so bumping one doesn't end a Wall-run.
func _touched_wall() -> RunnerMovement.WallContact:
	var steepest: KinematicCollision3D = null
	for index: int in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if not _movement.is_wall(collision.get_normal()):
			continue
		if steepest == null or absf(collision.get_normal().y) < absf(steepest.get_normal().y):
			steepest = collision
	if steepest != null:
		return RunnerMovement.WallContact.new(steepest.get_normal(), steepest.get_collider_id())
	var wall_normal := _movement.wall_normal()
	if wall_normal.is_zero_approx():
		return null
	var from := global_position + Vector3.UP * (_capsule.height / 2.0)
	var to := from - wall_normal * (_capsule.radius + tuning.wall_probe_reach)
	var ray := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return null
	var normal: Vector3 = hit["normal"]
	var id: int = hit["collider_id"]
	return RunnerMovement.WallContact.new(normal, id)


## The lowest hit of rays cast along [param heading] from the body's axis, from just above the
## feet up to Mantle reach, on a face near enough vertical to be a wall; empty if none. Its
## "opening" is the height above the feet of the first ray above that hit that finds nothing,
## capped at Mantle reach: the face's top is below it.
func _ledge_face(heading: Vector3) -> Dictionary:
	var face := { }
	var height := LEDGE_PROBE_SPACING / 2.0
	while height <= tuning.mantle_reach:
		var from := global_position + Vector3.UP * height
		var hit := _cast(from, from + heading * (_capsule.radius + LEDGE_PROBE_AHEAD))
		if face.is_empty():
			if not hit.is_empty() and _movement.is_wall(hit["normal"] as Vector3):
				face = hit
		elif hit.is_empty():
			face["opening"] = height
			return face
		height += LEDGE_PROBE_SPACING
	if not face.is_empty():
		face["opening"] = tuning.mantle_reach
	return face


## The first thing a ray from [param from] to [param to] hits, other than the Runner; empty if
## none.
func _cast(from: Vector3, to: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	# Starting inside a box out of reach, the ray must not find the box's underside.
	ray.hit_back_faces = false
	return get_world_3d().direct_space_state.intersect_ray(ray)


## Shrinks or grows the body from the top, so the feet stay put.
func _set_body_low(low: bool) -> void:
	_body_low = low
	_capsule.height = tuning.crouch_height if low else _standing_height
	_body.position.y = _capsule.height / 2.0


## True if there is room for the standing body here: a standing body already fills it, and a
## low one could move straight up by the height standing adds. Uses the body's own movement
## collision: a shape overlap query misses CSG and trimesh ceilings.
func _has_headroom() -> bool:
	if not _body_low:
		return true
	return not test_move(global_transform, Vector3.UP * (_standing_height - tuning.crouch_height))


## Eases the eyes toward the body's eye height, but never above a ceiling overhead (going
## under one quickly would otherwise drag the camera through it before the ease catches up).
## Eases the camera's roll toward the Wall-run tilt at the same rate.
func _ease_camera(delta: float) -> void:
	var target := _capsule.height - _eye_below_top
	var weight := 1.0 - exp(-tuning.camera_smoothing * delta)
	var eased := lerpf(_head.position.y, target, weight)
	_head.position.y = minf(eased, _ceiling_eye_limit())
	_camera.rotation.z = lerpf(_camera.rotation.z, _wall_run_roll(), weight)


## The camera's roll during a Wall-run: away from the wall's side of the view, so a wall on the
## right rolls it left. Level outside a run, rad.
func _wall_run_roll() -> float:
	var wall_normal := _movement.wall_normal()
	if wall_normal.is_zero_approx():
		return 0.0
	var tilt := deg_to_rad(tuning.wall_run_camera_tilt)
	# The wall's normal points away from it: toward the left of the view for a wall on the right.
	var wall_on_right := wall_normal.dot(global_basis.x) < 0.0
	return tilt if wall_on_right else -tilt


## Highest eye height that stays below whatever is directly above the low eyes.
func _ceiling_eye_limit() -> float:
	var low_eye := tuning.crouch_height - _eye_below_top
	var from := global_position + Vector3.UP * low_eye
	var to := global_position + Vector3.UP * (_standing_height + tuning.camera_ceiling_gap)
	var ray := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return INF
	var ceiling := (hit["position"] as Vector3).y - global_position.y
	return maxf(ceiling - tuning.camera_ceiling_gap, low_eye)
