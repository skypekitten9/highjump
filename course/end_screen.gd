class_name EndScreen
extends CanvasLayer
## What the Player sees when an Attempt ends: how it ended, and how to start the next.

@onready var _title: Label = $Centre/Lines/Title


## Shows the screen for an Attempt that ended by [param ending].
func show_ending(ending: Course.Ending) -> void:
	_title.text = "You stalled" if ending == Course.Ending.STALL else "You fell"
	visible = true
