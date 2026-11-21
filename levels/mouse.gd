class_name Mouse
extends RefCounted
## The real mouse mode: whether the mouse is captured. Read it here rather than trusting a record
## of what was last asked for: in a browser a capture can be refused (pointer lock needs a click
## first) and Esc drops it without telling the game.
##
## The headless display server ignores mouse modes (setting one reads back as visible), so there
## this keeps the mode itself and behaves as a display that grants every capture. Tests drop the
## capture with [method set_captured], as a browser does on Esc.

var _headless := DisplayServer.get_name() == "headless"
var _headless_captured := false


## True while the mouse is captured.
func is_captured() -> bool:
	if _headless:
		return _headless_captured
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


## Captures the mouse if [param captured], frees it if not.
func set_captured(captured: bool) -> void:
	_headless_captured = captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
