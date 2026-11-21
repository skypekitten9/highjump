class_name Level
extends Node3D
## A place the Player plays in. Owns mouse capture while play runs: captures the mouse when
## play starts, frees it on release_mouse and captures it again on a click.

## The real mouse mode, which this level sets and reads.
var mouse := Mouse.new()
## Whether this level has the mouse captured. The Runner turns the camera only while it is.
var mouse_captured := false:
	set(value):
		mouse_captured = value
		mouse.set_captured(value)


func _ready() -> void:
	mouse_captured = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		mouse_captured = false
		return
	# Checks the real mouse mode, not mouse_captured: in a browser the capture at play start is
	# refused (pointer lock needs a click first) and Esc drops it without telling the level.
	var click := event as InputEventMouseButton
	if click and click.pressed and not mouse.is_captured():
		mouse_captured = true
