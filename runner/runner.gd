class_name Runner
extends CharacterBody3D
## The body the Player controls, seen from its own eyes. Reads input and does mouse look;
## everything velocity-related is decided by RunnerMovement once per physics frame.

const PITCH_LIMIT := deg_to_rad(89.0)

## The feel values for this Runner.
@export var tuning: RunnerTuning = preload("res://runner/default_runner_tuning.tres")

var _movement := RunnerMovement.new()

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera


func _ready() -> void:
	_camera.fov = tuning.fov
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
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
	var jump_pressed := Input.is_action_just_pressed("jump")
	velocity = _movement.step(wish, jump_pressed, velocity, on_floor, floor_normal, tuning, delta)
	move_and_slide()


func _look(relative: Vector2) -> void:
	rotate_y(-relative.x * tuning.mouse_sensitivity)
	_head.rotation.x = clampf(
		_head.rotation.x - relative.y * tuning.mouse_sensitivity,
		-PITCH_LIMIT,
		PITCH_LIMIT,
	)
