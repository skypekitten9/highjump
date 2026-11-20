class_name Runner
extends CharacterBody3D
## The body the Player controls, seen from its own eyes. Reads input and does mouse look;
## velocity and whether the body is low are decided by RunnerMovement once per physics frame.
## Reports whether there is headroom to stand, sizes the body as RunnerMovement says, and eases
## the camera's height after it.

const PITCH_LIMIT := deg_to_rad(89.0)

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
	_movement = RunnerMovement.new(tuning)
	# Own copy, so resizing it never touches the scene's shared sub-resource.
	_capsule = (_body.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	_body.shape = _capsule
	_standing_height = _capsule.height
	_eye_below_top = _standing_height - _head.position.y
	_camera.fov = tuning.fov
	floor_snap_length = tuning.floor_snap_length
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		var click := event as InputEventMouseButton
		if click and click.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	var motion := event as InputEventMouseMotion
	if motion:
		_look(motion.relative)


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
	var contact := RunnerMovement.Contact.new(on_floor, floor_normal, _has_headroom())
	velocity = _movement.step(intent, contact, velocity, delta)
	_set_body_low(_movement.is_low())
	move_and_slide()
	# The engine never snaps while velocity points up, which would lift the Runner off the
	# floor every other frame up a ramp and launch it over the crest.
	if _movement.is_on_ground():
		apply_floor_snap()
	_ease_camera(delta)


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
func _ease_camera(delta: float) -> void:
	var target := _capsule.height - _eye_below_top
	var weight := 1.0 - exp(-tuning.camera_smoothing * delta)
	var eased := lerpf(_head.position.y, target, weight)
	_head.position.y = minf(eased, _ceiling_eye_limit())


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


func _look(relative: Vector2) -> void:
	rotate_y(-relative.x * tuning.mouse_sensitivity)
	_head.rotation.x = clampf(
		_head.rotation.x - relative.y * tuning.mouse_sensitivity,
		-PITCH_LIMIT,
		PITCH_LIMIT,
	)
