class_name Hud
extends CanvasLayer
## What the Player sees while an Attempt runs: the Distance, and a note to click while it is
## paused.

@onready var _distance: Label = $Distance
@onready var _paused: Label = $Paused


## Shows [param metres] as the Distance.
func show_distance(metres: int) -> void:
	_distance.text = "%d m" % metres


## Shows the note to click to continue if [param paused], hides it if not.
func show_paused(paused: bool) -> void:
	_paused.visible = paused
