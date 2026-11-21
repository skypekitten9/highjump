class_name Runner
extends CharacterBody3D
## The body the Player controls, seen from its own eyes. Reads input, holding forward for the
## Player, and does mouse look within the Look limit either side of the Course heading;
## velocity and whether the body is low are decided by RunnerMovement once per physics frame.
## Reports whether there is headroom to stand, which wall the body touches and the ledge ahead,
## sizes the body as RunnerMovement says, and eases the camera's height after it, its roll
## during a Wall-run and its dip during a Mantle.

const PITCH_LIMIT := deg_to_rad(89.0)
## The ledge probe only finds tops at least this far above the feet, so it never takes the floor
## under the Runner for a top, m.
const LEDGE_MIN_TOP := 0.05
## How many rays round the edge of the body's footprint measure the room on a ledge's top, besides
## one up its middle.
const ROOM_RAYS_AROUND := 8
## Greatest spacing of the ledge probe's rays up a face, m. They are spaced evenly from
## [constant LEDGE_MIN_TOP] above the feet to as far below Mantle reach, so a face is found
## however near its top is to the reach.
const LEDGE_PROBE_SPACING := 0.2

## The feel values for this Runner.
@export var tuning: RunnerTuning = preload("res://runner/default_runner_tuning.tres")
## Whether the Runner builds its intent as if forward were always held (docs/adr/0008). Off only
## where something else drives forward, such as a test that needs the Runner to stand still.
@export var holds_forward := true

## The Course heading: the fixed direction in the world the Course leads in. The Look limit keeps
## the body's yaw within [member RunnerTuning.look_limit] either side of it. Set from outside;
## until then it is the way the Runner faces when it enters the tree. Only its horizontal part
## counts. Setting it turns the body back within the limit if it is outside.
var course_heading := Vector3.ZERO:
	set(value):
		course_heading = Vector3(value.x, 0.0, value.z).normalized()
		if is_inside_tree():
			_turn(0.0)

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
	if course_heading.is_zero_approx():
		course_heading = -global_basis.z


## Turns the camera only while the mouse is captured. Never captures or frees it: whatever
## holds the Runner (a level, later a menu) owns that.
func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var motion := event as InputEventMouseMotion
	if motion:
		look(motion.relative)


func _physics_process(delta: float) -> void:
	# Back does nothing (docs/adr/0008).
	var forward: float = 1.0 if holds_forward else Input.get_action_strength("move_forward")
	var move := Vector2(Input.get_axis("move_left", "move_right"), -forward).limit_length(1.0)
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
## measures the room above the top with rays across the body's footprint there, and finds
## nothing if the body, as it is now, can't rise straight up until its feet are level with the
## top (a shape overlap query misses CSG and trimesh ceilings).
func find_ledge(direction: Vector3) -> RunnerMovement.LedgeContact:
	var heading := Vector3(direction.x, 0.0, direction.z)
	if heading.is_zero_approx():
		return null
	var face := _ledge_face(heading.normalized())
	if face == null:
		return null
	# Where the body's middle would stand on the top: a body radius in from the face.
	var over_top := face.position - _horizontal_unit(face.normal) * _capsule.radius
	var feet: float = global_position.y
	var top_hit := _cast(
		Vector3(over_top.x, feet + face.opening, over_top.z),
		Vector3(over_top.x, feet + LEDGE_MIN_TOP, over_top.z),
	)
	if top_hit.is_empty() or (top_hit["normal"] as Vector3).y < cos(floor_max_angle):
		return null
	var top: Vector3 = top_hit["position"]
	if test_move(global_transform, Vector3.UP * (top.y - feet)):
		return null
	var room_on_top := _room_above(top)
	return RunnerMovement.LedgeContact.new(face.normal, top.y - feet, room_on_top)


## The room above a ledge's top for a body standing with its middle at [param middle], on the
## top: the lowest a ray straight up finds anything, from the middle and from points round the
## edge of the body's footprint, m; INF if none finds anything within standing height.
func _room_above(middle: Vector3) -> float:
	var room := INF
	for index: int in ROOM_RAYS_AROUND + 1:
		var from: Vector3 = middle
		if index > 0:
			var angle := TAU * index / ROOM_RAYS_AROUND
			from += Vector3.FORWARD.rotated(Vector3.UP, angle) * _capsule.radius
		var above := _cast(from, from + Vector3.UP * _standing_height)
		if not above.is_empty():
			room = minf(room, (above["position"] as Vector3).y - middle.y)
	return room


## Turns the body and pitches the head by [param relative] pixels of mouse movement. The turn
## stops hard at the Look limit either side of the Course heading. Leaves the camera's Wall-run
## roll alone.
func look(relative: Vector2) -> void:
	_turn(-relative.x * tuning.mouse_sensitivity)
	_head.rotation.x = clampf(
		_head.rotation.x - relative.y * tuning.mouse_sensitivity,
		-PITCH_LIMIT,
		PITCH_LIMIT,
	)


## Turns the body by [param turn] rad, left positive, stopping hard at the Look limit either side
## of the Course heading. A body outside the limit is turned back within it. A limit of 180
## degrees or more lets it turn freely.
func _turn(turn: float) -> void:
	var limit := deg_to_rad(tuning.look_limit)
	if limit >= PI:
		global_rotation.y += turn
		return
	var heading_yaw := atan2(-course_heading.x, -course_heading.z)
	var offset := angle_difference(heading_yaw, global_rotation.y)
	global_rotation.y = heading_yaw + clampf(offset + turn, -limit, limit)


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


## The lowest place rays cast along [param heading] from the body's axis, spaced evenly from
## just above the feet to just below Mantle reach, hit a face near enough vertical to be a wall;
## null if none do.
func _ledge_face(heading: Vector3) -> LedgeFace:
	var lowest := LEDGE_MIN_TOP
	var highest := maxf(tuning.mantle_reach - LEDGE_MIN_TOP, lowest)
	var gaps := ceili((highest - lowest) / LEDGE_PROBE_SPACING)
	var face: LedgeFace = null
	for index: int in gaps + 1:
		var height := lerpf(lowest, highest, float(index) / gaps) if gaps > 0 else lowest
		var from := global_position + Vector3.UP * height
		var hit := _cast(from, from + heading * (_capsule.radius + tuning.ledge_probe_ahead))
		if face == null:
			if not hit.is_empty() and _movement.is_wall(hit["normal"] as Vector3):
				var hit_position: Vector3 = hit["position"]
				var hit_normal: Vector3 = hit["normal"]
				face = LedgeFace.new(hit_position, hit_normal, tuning.mantle_reach)
		elif hit.is_empty():
			face.opening = height
			return face
	return face


func _horizontal_unit(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z).normalized()


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
## Eases the camera's roll toward the Wall-run tilt, and its pitch toward the Mantle dip, at the
## same rate, so neither snaps when a run or a Mantle ends. The dip pitches the camera within
## the Head, leaving the mouse pitch alone.
func _ease_camera(delta: float) -> void:
	var target := _capsule.height - _eye_below_top
	var weight := 1.0 - exp(-tuning.camera_smoothing * delta)
	var eased := lerpf(_head.position.y, target, weight)
	_head.position.y = minf(eased, _ceiling_eye_limit())
	_camera.rotation.z = lerpf(_camera.rotation.z, _wall_run_roll(), weight)
	var dip := -deg_to_rad(tuning.mantle_camera_dip) if is_mantling() else 0.0
	_camera.rotation.x = lerpf(_camera.rotation.x, dip, weight)


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


## Where the ledge probe found a ledge's face.
class LedgeFace:
	## Where the lowest ray hit the face.
	var position: Vector3
	## The face's normal there.
	var normal: Vector3
	## Height above the feet of the first ray above that hit to find nothing, or Mantle reach if
	## none did: the face's top is below it, m.
	var opening: float


	func _init(p_position: Vector3, p_normal: Vector3, p_opening: float) -> void:
		position = p_position
		normal = p_normal
		opening = p_opening
